//! Public consumers of optional XZ Block Header size declarations.
const std = @import("std");
const a = std.testing.allocator;
const block_size: usize = 1024;
const input = (("abcdefg|" ** 512) ++ "end").*;

pub fn contracts(comptime V: type) !void {
    try publicApis(V);
    try zipConsumers(V);
    try tarConsumer(V);
    try cpioConsumer(V);
    try atomicFailures(V);
}

fn options(comptime V: type) V.XzEncodeOptions {
    return .{ .include_block_sizes = true, .block_size = block_size, .chunk_size = block_size, .dictionary_size = 4096, .check = .crc64 };
}

fn parallel(comptime V: type) V.XzParallelOptions {
    return .{ .io = std.testing.io, .worker_count = 2, .max_inflight_blocks = 2, .max_inflight_bytes = 2 * block_size, .max_working_memory = 64 * 1024 * 1024 };
}

fn vli(bytes: []const u8, cursor: *usize) !usize {
    var value: u64 = 0;
    for (0..9) |group| {
        try std.testing.expect(cursor.* < bytes.len);
        const byte = bytes[cursor.*];
        cursor.* += 1;
        try std.testing.expect(group == 0 or byte != 0);
        value |= @as(u64, byte & 0x7f) << @intCast(group * 7);
        if (byte & 0x80 == 0) return std.math.cast(usize, value) orelse error.InvalidVli;
    }
    return error.InvalidVli;
}

fn declaredSizes(wire: []const u8, expected_plain: usize) !void {
    try std.testing.expect(wire.len >= 32);
    try std.testing.expectEqualSlices(u8, "\xfd7zXZ\x00", wire[0..6]);
    try std.testing.expectEqual(@as(u8, 4), wire[7]);
    var offset: usize = 12;
    var total: usize = 0;
    var blocks: usize = 0;
    while (wire[offset] != 0) {
        const header_len = (@as(usize, wire[offset]) + 1) * 4;
        try std.testing.expect(header_len >= 12 and offset + header_len <= wire.len);
        const header = wire[offset .. offset + header_len - 4];
        try std.testing.expectEqual(@as(u8, 0xc0), header[1]);
        var h: usize = 2;
        const packed_size = try vli(header, &h);
        const unpacked = try vli(header, &h);
        try std.testing.expectEqual(@as(usize, 0x21), try vli(header, &h));
        try std.testing.expectEqual(@as(usize, 1), try vli(header, &h));
        try std.testing.expect(h < header.len);
        try std.testing.expectEqual(@as(u8, 0), header[h]);
        for (header[h + 1 ..]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
        const start = offset + header_len;
        try std.testing.expect(packed_size > 0 and start + packed_size <= wire.len);
        const body = wire[start .. start + packed_size];
        var cursor: usize = 0;
        var plain: usize = 0;
        while (true) {
            try std.testing.expect(cursor < body.len);
            const control = body[cursor];
            cursor += 1;
            if (control == 0) break;
            try std.testing.expect(cursor + 2 <= body.len);
            const low = @as(usize, std.mem.readInt(u16, body[cursor..][0..2], .big)) + 1;
            cursor += 2;
            if (control < 0x80) {
                try std.testing.expect(control == 1 or control == 2);
                plain += low;
                cursor += low;
            } else {
                plain += (@as(usize, control & 0x1f) << 16) + low;
                try std.testing.expect(cursor + 2 <= body.len);
                const compressed = @as(usize, std.mem.readInt(u16, body[cursor..][0..2], .big)) + 1;
                cursor += 2 + @as(usize, @intFromBool(control >= 0xc0)) + compressed;
            }
            try std.testing.expect(cursor < body.len);
        }
        try std.testing.expectEqual(packed_size, cursor); // End marker counts; header, padding and Check do not.
        try std.testing.expectEqual(unpacked, plain);
        try std.testing.expect(total < expected_plain);
        try std.testing.expectEqual(@min(block_size, expected_plain - total), unpacked);
        total += unpacked;
        blocks += 1;
        const padding = (4 - packed_size % 4) % 4;
        try std.testing.expect(start + packed_size + padding + 8 < wire.len);
        for (wire[start + packed_size ..][0..padding]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
        offset = start + packed_size + padding + 8;
    }
    try std.testing.expectEqual(expected_plain, total);
    try std.testing.expectEqual((expected_plain + block_size - 1) / block_size, blocks);
}

fn publicApis(comptime V: type) !void {
    try std.testing.expect(!(@as(V.XzEncodeOptions, .{})).include_block_sizes);
    try std.testing.expect(!(@as(V.XzIncrementalEncoder.Options, .{})).include_block_sizes);
    const sized = try V.encodeXzAlloc(a, &input, options(V));
    defer a.free(sized);
    try declaredSizes(sized, input.len);
    var legacy_options = options(V);
    legacy_options.include_block_sizes = false;
    const legacy = try V.encodeXzAlloc(a, &input, legacy_options);
    defer a.free(legacy);
    try std.testing.expectEqual(@as(u8, 0), legacy[13]);
    var parallel_options = options(V);
    parallel_options.parallel = parallel(V);
    const output = try a.alloc(u8, sized.len + 7);
    defer a.free(output);
    @memset(output, 0xa5);
    const written = try V.encodeXzInto(a, &input, output, parallel_options);
    try std.testing.expectEqualSlices(u8, sized, output[0..written]);
    for (output[written..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    const decoded = try V.xz.decodeAlloc(a, sized);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
    @memset(output, 0xa5);
    try std.testing.expectError(error.OutputTooSmall, V.encodeXzInto(a, &input, output[0 .. sized.len - 1], parallel_options));
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn checkZip(comptime V: type, bytes: []const u8, entries: []const V.zip.EncodeEntry) !void {
    const archive = try V.zip.parse(bytes);
    try std.testing.expectEqual(entries.len, archive.entry_count);
    for (entries, 0..) |expected, i| {
        const entry = try archive.entryAt(i);
        try std.testing.expectEqualStrings(expected.name, entry.name);
        try std.testing.expectEqualStrings(expected.comment, entry.comment);
        try std.testing.expectEqual(expected.modified, entry.modified);
        try std.testing.expectEqual(V.zip.CompressionMethod.xz, entry.method);
        try declaredSizes(try archive.compressedData(entry), expected.data.len);
        const decoded = try archive.extractAlloc(a, entry);
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, expected.data, decoded);
    }
}

fn zipConsumers(comptime V: type) !void {
    const entries = [_]V.zip.EncodeEntry{ .{ .name = "data.bin", .data = &input, .method = .xz, .comment = "declared" }, .{ .name = "tail", .data = "end", .method = .xz } };
    var settings: V.zip.EncodeOptions = .{ .xz_options = options(V) };
    const serial = try V.zip.encodeAlloc(a, &entries, settings);
    defer a.free(serial);
    settings.xz_options.parallel = parallel(V);
    const bytes = try V.zip.encodeAlloc(a, &entries, settings);
    defer a.free(bytes);
    try std.testing.expectEqualSlices(u8, serial, bytes);
    try checkZip(V, bytes, &entries);
    const W = V.zip.incremental_writer;
    try std.testing.expect(!(@as(W.Options, .{})).xz_options.include_block_sizes);
    var writer = try W.Writer.initWithOptions(a, .{ .xz_options = .{ .include_block_sizes = true, .block_size = block_size, .chunk_size = block_size, .dictionary_size = 4096 } });
    defer writer.deinit();
    var streamed: std.ArrayList(u8) = .empty;
    defer streamed.deinit(a);
    var scratch: [137]u8 = undefined;
    for (entries, 0..) |entry, i| {
        try writer.beginEntry(.{ .name = entry.name, .comment = entry.comment, .method = .xz, .expected_size = if (i == 0) @as(u64, entry.data.len) else null });
        var consumed: usize = 0;
        while (consumed < entry.data.len) {
            const step = try writer.step(entry.data[consumed..@min(entry.data.len, consumed + 173)], &scratch);
            consumed += step.progress.input_read;
            try streamed.appendSlice(a, scratch[0..step.progress.output_written]);
            try std.testing.expect(step.progress.input_read > 0 or step.progress.output_written > 0);
        }
        try writer.finishEntry();
        while (writer.snapshot().phase != .ready) {
            const step = try writer.step("", &scratch);
            try streamed.appendSlice(a, scratch[0..step.progress.output_written]);
        }
    }
    try writer.finishArchive();
    while (true) {
        const step = try writer.step("", &scratch);
        try streamed.appendSlice(a, scratch[0..step.progress.output_written]);
        if (step.status == .done) break;
    }
    try checkZip(V, streamed.items, &entries);
}

fn tarConsumer(comptime V: type) !void {
    const entries = [_]V.tar.EncodeEntry{.{ .name = "sizes.txt", .data = &input, .mode = 0o640, .mtime = 123456789 }};
    const raw = try V.tar.encodeAlloc(a, &entries);
    defer a.free(raw);
    var settings: V.tar.CompressedEncodeOptions = .{ .compression = .xz, .xz_options = options(V) };
    const serial = try V.tar.encodeCompressedAlloc(a, &entries, settings);
    defer a.free(serial);
    settings.xz_options.parallel = parallel(V);
    const bytes = try V.tar.encodeCompressedAlloc(a, &entries, settings);
    defer a.free(bytes);
    try std.testing.expectEqualSlices(u8, serial, bytes);
    try declaredSizes(bytes, raw.len);
    const decoded = try V.tar.decodeCompressedAlloc(a, bytes, .xz, 32 * 1024);
    defer decoded.deinit(a);
    const entry = try decoded.archive.entryAt(0);
    try std.testing.expect(decoded.archive.entry_count == 1 and entry.kind == .file);
    try std.testing.expect(entry.path.eql(entries[0].name));
    try std.testing.expectEqual(entries[0].mode, entry.mode);
    try std.testing.expectEqual(entries[0].mtime, entry.mtime);
    try std.testing.expectEqualSlices(u8, &input, entry.data);
}

fn cpioConsumer(comptime V: type) !void {
    const entries = [_]V.cpio.EncodeEntry{.{ .name = "sizes.txt", .data = &input, .permissions = 0o640, .uid = 42, .gid = 43, .mtime = 123456789 }};
    const raw = try V.cpio.encodeAlloc(a, &entries, .{ .format = .crc });
    defer a.free(raw);
    var settings: V.cpio.CompressedEncodeOptions = .{ .compression = .xz, .xz_options = options(V), .archive_options = .{ .format = .crc } };
    const serial = try V.cpio.encodeCompressedAlloc(a, &entries, settings);
    defer a.free(serial);
    settings.xz_options.parallel = parallel(V);
    const bytes = try V.cpio.encodeCompressedAlloc(a, &entries, settings);
    defer a.free(bytes);
    try std.testing.expectEqualSlices(u8, serial, bytes);
    try declaredSizes(bytes, raw.len);
    const decoded = try V.cpio.decodeCompressedAlloc(a, bytes, .xz, 32 * 1024);
    defer decoded.deinit(a);
    const entry = try decoded.archive.entryAt(0);
    try std.testing.expect(decoded.archive.entry_count == 1 and entry.kind == .regular and entry.format == .crc);
    try std.testing.expectEqualStrings(entries[0].name, entry.name);
    try std.testing.expectEqual(@as(u32, 0o640), entry.mode & 0o7777);
    try std.testing.expectEqual(entries[0].uid, entry.uid);
    try std.testing.expectEqual(entries[0].gid, entry.gid);
    try std.testing.expectEqual(entries[0].mtime, entry.mtime);
    const content = try decoded.archive.extractAlloc(a, entry);
    defer a.free(content);
    try std.testing.expectEqualSlices(u8, &input, content);
}

fn atomicFailures(comptime V: type) !void {
    var limited = options(V);
    limited.parallel = parallel(V);
    limited.parallel.?.max_working_memory = 0;
    var output: [64]u8 = @splat(0xa5);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, V.encodeXzInto(a, &input, &output, limited));
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, "prefix|");
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    const zip_entries = [_]V.zip.EncodeEntry{.{ .name = "data", .data = &input, .method = .xz }};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, V.zip.encodeAppend(a, &out, &zip_entries, .{ .xz_options = limited }));
    const tar_entries = [_]V.tar.EncodeEntry{.{ .name = "data", .data = &input }};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, V.tar.encodeCompressedAppend(a, &out, &tar_entries, .{ .compression = .xz, .xz_options = limited }));
    const cpio_entries = [_]V.cpio.EncodeEntry{.{ .name = "data", .data = &input }};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, V.cpio.encodeCompressedAppend(a, &out, &cpio_entries, .{ .compression = .xz, .xz_options = limited }));
    try std.testing.expectEqualStrings("prefix|", out.items);
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(capacity, out.capacity);
}
