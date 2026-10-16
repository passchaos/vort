const std = @import("std");
const archive = @import("archive.zig");
const reader_mod = @import("incremental_reader.zig");
const wire = @import("wire.zig");
const writer = @import("writer.zig");

const input_chunks = [_]usize{ 1, 2, 3, 5, 7, 11 };
const output_chunks = [_]usize{ 1, 2, 5, 13 };

fn driveArchive(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    expected: []const writer.EncodeEntry,
    input_seed: usize,
    output_seed: usize,
) !void {
    const reference = try archive.parse(bytes);
    var reader = reader_mod.Reader.init(allocator);
    defer reader.deinit();
    var entry_output: std.ArrayList(u8) = .empty;
    defer entry_output.deinit(allocator);
    var output_storage: [13]u8 = undefined;
    var input_offset: usize = 0;
    var input_index = input_seed;
    var output_index = output_seed;
    var entry_index: usize = 0;
    var active = false;

    while (true) {
        const input_len = input_chunks[input_index % input_chunks.len];
        input_index += 1;
        const input_end = @min(bytes.len, input_offset + input_len);
        const output_len = output_chunks[output_index % output_chunks.len];
        output_index += 1;
        const stepped = try reader.step(
            bytes[input_offset..input_end],
            output_storage[0..output_len],
        );
        input_offset += stepped.input_read;
        if (active)
            try entry_output.appendSlice(allocator, output_storage[0..stepped.output_written]);

        switch (stepped.status) {
            .entry_header => {
                if (entry_index >= expected.len or active) return error.TestUnexpectedResult;
                const info = reader.currentEntry() orelse return error.TestUnexpectedResult;
                const wanted = expected[entry_index];
                const canonical = try reference.entryAt(entry_index);
                try std.testing.expectEqualStrings(wanted.name, info.name);
                try std.testing.expectEqual(wanted.kind, info.kind);
                try std.testing.expectEqual(wanted.data.len, info.stored_size);
                try std.testing.expectEqual(archive.isSafePath(wanted.name), info.safe_path);
                try std.testing.expectEqual(canonical.format, info.format);
                try std.testing.expectEqual(canonical.mode, info.mode);
                try std.testing.expectEqual(canonical.inode, info.inode);
                try std.testing.expectEqual(canonical.uid, info.uid);
                try std.testing.expectEqual(canonical.gid, info.gid);
                try std.testing.expectEqual(canonical.link_count, info.link_count);
                try std.testing.expectEqual(canonical.mtime, info.mtime);
                try std.testing.expectEqual(canonical.device_major, info.device_major);
                try std.testing.expectEqual(canonical.device_minor, info.device_minor);
                try std.testing.expectEqual(canonical.rdevice_major, info.rdevice_major);
                try std.testing.expectEqual(canonical.rdevice_minor, info.rdevice_minor);
                try std.testing.expectEqual(canonical.checksum, info.checksum);
                try std.testing.expectEqual(@as(u64, @intCast(canonical.header_offset)), info.header_offset);
                try std.testing.expectEqual(@as(u64, @intCast(canonical.data_offset)), info.data_offset);
                try std.testing.expectEqual(info.format, reader.snapshot().format.?);
                entry_output.clearRetainingCapacity();
                active = true;
            },
            .entry_done => {
                if (!active or entry_index >= expected.len) return error.TestUnexpectedResult;
                try std.testing.expectEqualSlices(u8, expected[entry_index].data, entry_output.items);
                entry_index += 1;
                active = false;
            },
            .need_input => if (input_offset == bytes.len) {
                try reader.finish();
            },
            .need_output => {},
            .done => break,
        }
        if (stepped.input_read == 0 and stepped.output_written == 0 and
            stepped.status != .entry_header and stepped.status != .entry_done and
            !(stepped.status == .need_input and input_offset == bytes.len))
        {
            return error.TestUnexpectedResult;
        }
    }
    try std.testing.expectEqual(bytes.len, input_offset);
    try std.testing.expectEqual(expected.len, entry_index);
    try std.testing.expectEqual(expected.len, reader.snapshot().entry_count);
}

test "CPIO incremental reader streams every format under fragmented input and output" {
    const allocator = std.testing.allocator;
    var random: [1025]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x4350_494f_5245_4144);
    prng.random().bytes(&random);
    const entries = [_]writer.EncodeEntry{
        .{
            .name = "plain.txt",
            .data = "fragmented CPIO payload",
            .permissions = 0o640,
            .uid = 12,
            .gid = 34,
            .mtime = 0x1234_5678,
            .device_minor = 5,
        },
        .{ .name = "folder", .kind = .directory },
        .{ .name = "folder/random.bin", .data = &random, .permissions = 0o600 },
        .{ .name = "link", .kind = .symlink, .data = "folder/random.bin" },
        .{ .name = "block", .kind = .block_device, .rdevice_minor = 7 },
        .{ .name = "character", .kind = .character_device, .rdevice_minor = 8 },
        .{ .name = "fifo", .kind = .fifo },
        .{ .name = "socket", .kind = .socket },
        .{ .name = "empty" },
    };

    inline for (std.meta.tags(archive.Format), 0..) |format, format_index| {
        const encoded = try writer.encodeAlloc(
            allocator,
            &entries,
            .{ .format = format, .block_size = 512 },
        );
        defer allocator.free(encoded);
        try driveArchive(allocator, encoded, &entries, format_index, format_index + 1);
        try driveArchive(allocator, encoded, &entries, 0, 0);
    }
}

test "CPIO incremental reader applies caller-output backpressure" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = "backpressure" }};
    const encoded = try writer.encodeAlloc(allocator, &entries, .{ .block_size = 0 });
    defer allocator.free(encoded);

    var reader = reader_mod.Reader.init(allocator);
    defer reader.deinit();
    const header = try reader.step(encoded, &.{});
    try std.testing.expectEqual(reader_mod.Status.entry_header, header.status);
    try std.testing.expectEqual(@as(usize, 0), header.output_written);
    const blocked = try reader.step(encoded[header.input_read..], &.{});
    try std.testing.expectEqual(reader_mod.Status.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.input_read);
    try std.testing.expectEqual(@as(usize, 0), blocked.output_written);
    try std.testing.expectEqual(@as(usize, 0), reader.snapshot().current_data_read);

    var output: ["backpressure".len]u8 = undefined;
    const data = try reader.step(encoded[header.input_read..], &output);
    try std.testing.expectEqualSlices(u8, "backpressure", output[0..data.output_written]);
}

test "CPIO incremental reader validates CRC and GNU zero-checksum symlinks" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{
        .{ .name = "payload", .data = "CRC payload bytes" },
        .{ .name = "link", .kind = .symlink, .data = "payload" },
    };
    const encoded_const = try writer.encodeAlloc(
        allocator,
        &entries,
        .{ .format = .crc, .block_size = 0 },
    );
    defer allocator.free(encoded_const);

    var zero_symlink = try allocator.dupe(u8, encoded_const);
    defer allocator.free(zero_symlink);
    const parsed = try archive.parse(zero_symlink);
    const link = try parsed.entryAt(1);
    @memcpy(zero_symlink[link.header_offset + 102 ..][0..8], "00000000");
    try driveArchive(allocator, zero_symlink, &entries, 0, 0);

    var corrupt = try allocator.dupe(u8, encoded_const);
    defer allocator.free(corrupt);
    const payload = try (try archive.parse(corrupt)).entryAt(0);
    corrupt[payload.data_offset] ^= 1;
    var reader = reader_mod.Reader.init(allocator);
    defer reader.deinit();
    var output: [64]u8 = undefined;
    var input_offset: usize = 0;
    while (true) {
        const stepped = reader.step(corrupt[input_offset..], &output) catch |err| {
            try std.testing.expectEqual(error.ChecksumMismatch, err);
            break;
        };
        input_offset += stepped.input_read;
    }
    try std.testing.expectEqual(reader_mod.Phase.poisoned, reader.snapshot().phase);
    try std.testing.expectError(error.CpioReaderPoisoned, reader.step("", &output));
}

test "CPIO incremental reader requires one consistent format and a trailer" {
    const allocator = std.testing.allocator;
    const entry = [_]writer.EncodeEntry{.{ .name = "payload", .data = "mixed format" }};
    const newc = try writer.encodeAlloc(
        allocator,
        &entry,
        .{ .format = .newc, .block_size = 0 },
    );
    defer allocator.free(newc);
    const odc_empty = try writer.encodeAlloc(
        allocator,
        &.{},
        .{ .format = .odc, .block_size = 0 },
    );
    defer allocator.free(odc_empty);
    const first = try (try archive.parse(newc)).entryAt(0);
    var mixed: std.ArrayList(u8) = .empty;
    defer mixed.deinit(allocator);
    try mixed.appendSlice(allocator, newc[0..first.next_offset]);
    try mixed.appendSlice(allocator, odc_empty);

    var mixed_reader = reader_mod.Reader.init(allocator);
    defer mixed_reader.deinit();
    var output: [64]u8 = undefined;
    var mixed_offset: usize = 0;
    while (true) {
        const stepped = mixed_reader.step(mixed.items[mixed_offset..], &output) catch |err| {
            try std.testing.expectEqual(error.InvalidCpioArchive, err);
            break;
        };
        mixed_offset += stepped.input_read;
    }

    const parsed = try archive.parse(newc);
    for (0..newc.len + 1) |cut| {
        var reader = reader_mod.Reader.init(allocator);
        defer reader.deinit();
        var input_offset: usize = 0;
        while (input_offset != cut) {
            const stepped = try reader.step(newc[input_offset..cut], &output);
            input_offset += stepped.input_read;
            if (stepped.input_read == 0 and stepped.output_written == 0 and
                stepped.status != .entry_header and stepped.status != .entry_done)
            {
                return error.TestUnexpectedResult;
            }
        }
        if (cut < parsed.archive_end) {
            try std.testing.expectError(error.TruncatedFrame, reader.finish());
        } else {
            try reader.finish();
            try std.testing.expectEqual(reader_mod.Status.done, (try reader.step("", &output)).status);
        }
    }
}

test "CPIO incremental reader enforces limits and validates zero padding" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{
        .name = "long-name-payload",
        .data = "bounded payload",
    }};
    const encoded = try writer.encodeAlloc(allocator, &entries, .{ .block_size = 512 });
    defer allocator.free(encoded);

    const Cases = struct {
        fn expectLimit(bytes: []const u8, options: reader_mod.Options) !void {
            var reader = reader_mod.Reader.initWithOptions(std.testing.allocator, options);
            defer reader.deinit();
            var output: [64]u8 = undefined;
            var input_offset: usize = 0;
            while (true) {
                const stepped = reader.step(bytes[input_offset..], &output) catch |err| {
                    try std.testing.expectEqual(error.OutputLimitExceeded, err);
                    return;
                };
                input_offset += stepped.input_read;
                if (stepped.status == .done) return error.TestUnexpectedResult;
            }
        }
    };
    try Cases.expectLimit(encoded, .{ .max_entries = 0 });
    try Cases.expectLimit(encoded, .{ .max_control_record_size = 1 });
    try Cases.expectLimit(encoded, .{ .max_name_size = 3 });
    try Cases.expectLimit(encoded, .{ .max_entry_size = 3 });
    try Cases.expectLimit(encoded, .{ .max_total_output_size = 3 });
    try Cases.expectLimit(encoded, .{ .max_archive_size = 3 });

    var bad_padding = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_padding);
    const parsed = try archive.parse(bad_padding);
    const first = try parsed.entryAt(0);
    bad_padding[first.next_offset - 1] = 1;
    var padding_reader = reader_mod.Reader.init(allocator);
    defer padding_reader.deinit();
    var output: [64]u8 = undefined;
    var input_offset: usize = 0;
    while (true) {
        const stepped = padding_reader.step(bad_padding[input_offset..], &output) catch |err| {
            try std.testing.expectEqual(error.InvalidCpioArchive, err);
            break;
        };
        input_offset += stepped.input_read;
    }

    const name_padded_const = try writer.encodeAlloc(
        allocator,
        &.{.{ .name = "ab", .data = "x" }},
        .{ .format = .newc, .block_size = 0 },
    );
    defer allocator.free(name_padded_const);
    var bad_name_padding = try allocator.dupe(u8, name_padded_const);
    defer allocator.free(bad_name_padding);
    const name_entry = try (try archive.parse(bad_name_padding)).entryAt(0);
    bad_name_padding[name_entry.data_offset - 1] = 1;
    var name_padding_reader = reader_mod.Reader.init(allocator);
    defer name_padding_reader.deinit();
    input_offset = 0;
    while (true) {
        const stepped = name_padding_reader.step(
            bad_name_padding[input_offset..],
            &output,
        ) catch |err| {
            try std.testing.expectEqual(error.InvalidCpioArchive, err);
            break;
        };
        input_offset += stepped.input_read;
    }

    var bad_trailing = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_trailing);
    bad_trailing[bad_trailing.len - 1] = 1;
    var trailing_reader = reader_mod.Reader.init(allocator);
    defer trailing_reader.deinit();
    input_offset = 0;
    while (true) {
        const stepped = trailing_reader.step(bad_trailing[input_offset..], &output) catch |err| {
            try std.testing.expectEqual(error.InvalidCpioArchive, err);
            break;
        };
        input_offset += stepped.input_read;
    }
}

test "CPIO incremental reader classifies unsafe names and reset retains scratch" {
    const allocator = std.testing.allocator;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    const metadata = wire.Metadata{
        .inode = 1,
        .mode = archive.mode_regular | 0o644,
        .uid = 0,
        .gid = 0,
        .link_count = 1,
        .mtime = 0,
        .device_major = 0,
        .device_minor = 0,
        .rdevice_major = 0,
        .rdevice_minor = 0,
    };
    try wire.appendEntry(allocator, &encoded, 0, "../escape", "data", metadata, .newc);
    try wire.appendEntry(allocator, &encoded, 0, archive.trailer_name, "", .{
        .inode = 0,
        .mode = 0,
        .uid = 0,
        .gid = 0,
        .link_count = 1,
        .mtime = 0,
        .device_major = 0,
        .device_minor = 0,
        .rdevice_major = 0,
        .rdevice_minor = 0,
    }, .newc);

    var reader = reader_mod.Reader.init(allocator);
    defer reader.deinit();
    var output: [16]u8 = undefined;
    var input_offset: usize = 0;
    while (true) {
        const stepped = try reader.step(encoded.items[input_offset..], &output);
        input_offset += stepped.input_read;
        if (stepped.status == .entry_header) {
            try std.testing.expect(!reader.currentEntry().?.safe_path);
        }
        if (stepped.status == .need_input and input_offset == encoded.items.len) {
            try reader.finish();
        }
        if (stepped.status == .done) break;
    }
    const retained = reader.snapshot().retained_name_capacity;
    try std.testing.expect(retained >= "../escape".len + 1);
    reader.reset();
    try std.testing.expectEqual(retained, reader.snapshot().retained_name_capacity);

    const odc = try writer.encodeAlloc(
        allocator,
        &.{.{ .name = "second", .data = "reuse" }},
        .{ .format = .odc, .block_size = 0 },
    );
    defer allocator.free(odc);
    try driveReaderInstance(&reader, odc, &output);
    try std.testing.expectEqual(archive.Format.odc, reader.snapshot().format.?);
}

test "CPIO incremental reader releases every allocation failure path" {
    const allocator = std.testing.allocator;
    const long_name = "nested/" ++ "long-component-" ** 20 ++ "payload.bin";
    const encoded = try writer.encodeAlloc(
        allocator,
        &.{.{ .name = long_name, .data = "allocation-safe payload" }},
        .{ .format = .crc },
    );
    defer allocator.free(encoded);

    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, bytes: []const u8) !void {
            var reader = reader_mod.Reader.init(failing_allocator);
            defer reader.deinit();
            var output: [31]u8 = undefined;
            try driveReaderInstance(&reader, bytes, &output);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{encoded});
}

fn driveReaderInstance(
    reader: *reader_mod.Reader,
    bytes: []const u8,
    output: []u8,
) !void {
    var input_offset: usize = 0;
    while (true) {
        const stepped = try reader.step(bytes[input_offset..], output);
        input_offset += stepped.input_read;
        if (stepped.status == .need_input and input_offset == bytes.len)
            try reader.finish();
        if (stepped.status == .done) break;
        if (stepped.input_read == 0 and stepped.output_written == 0 and
            stepped.status != .entry_header and stepped.status != .entry_done and
            !(stepped.status == .need_input and input_offset == bytes.len))
        {
            return error.TestUnexpectedResult;
        }
    }
}
