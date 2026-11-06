//! ZIP64 source contracts keep logical sizes apart from physical caller slices.
const std = @import("std");
const core = @import("../../core.zig");
const checksum = @import("../../checksum.zig");
const crypto = @import("vail_archive_crypto").zipcrypto;
const h = @import("wide_counts_fixture.zig");
const Count = core.StreamCount;
const a = std.testing.allocator;

pub fn contracts(comptime Codec: type) !void {
    try @import("wide_split_tests.zig").contracts(Codec);
    try types(Codec);
    try smallPrefixProof(Codec);
    try sourceOffsets(Codec);
    try knownWideSource(Codec);
    try scannedWideSource(Codec);
    try rawWideEntry(Codec);
    try rawWideSource(Codec);
    try encryptionAtWideOffset(Codec);
}

fn types(comptime Codec: type) !void {
    try std.testing.expect(@FieldType(Codec.Entry, "uncompressed_size") == Count);
    inline for (.{ "compressed_size", "local_header_offset", "central_header_offset" }) |name|
        try std.testing.expect(@FieldType(Codec.Entry, name) == usize);
    inline for (.{ "input_read", "output_written", "expected_input_len", "expected_output_len" }) |name|
        try std.testing.expect(@FieldType(Codec.IncrementalEntryDecoder.Snapshot, name) == Count);
    inline for (.{ "input_read", "output_written", "completed_entries", "central_entries" }) |name|
        try std.testing.expect(@FieldType(Codec.IncrementalReader.Snapshot, name) == Count);
    inline for (.{ "central_offset", "central_size" }) |name|
        try std.testing.expect(@FieldType(Codec.IncrementalReader.Snapshot, name) == ?Count);
    inline for (.{ "compressed_size", "uncompressed_size" }) |name|
        try std.testing.expect(@FieldType(Codec.IncrementalReaderEntryInfo, name) == ?Count);
    try std.testing.expect(@FieldType(Codec.IncrementalReaderEntryInfo, "local_header_offset") == Count);
    inline for (.{ "initial_offset", "max_entry_output_len", "max_total_output_len", "max_central_directory_size" }) |name|
        try std.testing.expect(@FieldType(Codec.IncrementalReaderOptions, name) == Count);
    try std.testing.expect(@FieldType(Codec.IncrementalReaderOptions, "max_control_record_size") == usize);
}

fn entry(comptime Codec: type, blocks: Count) Codec.Entry {
    return .{
        .name = h.name,
        .method = .deflate,
        .flags = 0,
        .crc32 = h.repeatedCrc(blocks * h.raw_prefix_output + 258),
        .compressed_size = @intCast(blocks * h.raw_prefix.len + h.raw_final_copy.len),
        .uncompressed_size = blocks * h.raw_prefix_output + 258,
        .local_header_offset = 0,
        .central_header_offset = 0,
        .zip64 = true,
    };
}

fn firstRepeat(decoder: anytype) !void {
    var output: [h.raw_prefix_output]u8 = undefined;
    var read: usize = 0;
    var written: usize = 0;
    var calls: usize = 0;
    while (read != h.raw_prefix.len or !decoder.raw.?.atBlockBoundary()) : (calls += 1) {
        try std.testing.expect(calls < 12);
        const result = try decoder.step(h.raw_prefix[read..], output[written..]);
        read += result.progress.input_read;
        written += result.progress.output_written;
    }
    try std.testing.expectEqual(output.len, written);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 'x'), byte);
    try std.testing.expectEqual(@as(u6, 0), decoder.raw.?.bit_count);
}

fn liftEntry(decoder: anytype, blocks: Count) !void {
    try firstRepeat(decoder);
    h.applyRawRepeat(&decoder.raw.?, blocks);
    decoder.total_input = blocks * h.raw_prefix.len;
    decoder.total_output = blocks * h.raw_prefix_output;
    decoder.crc.value = ~h.repeatedCrc(decoder.total_output);
}

fn drainEntry(decoder: anytype) !void {
    var output: [258]u8 = undefined;
    const supplied = h.raw_final_copy ++ "NEXT";
    var read: usize = 0;
    var written: usize = 0;
    var calls: usize = 0;
    while (decoder.snapshot().phase != .done) : (calls += 1) {
        try std.testing.expect(calls < 300);
        const result = try decoder.step(supplied[read..@min(supplied.len, read + 1)], output[written..@min(output.len, written + 3)]);
        read += result.progress.input_read;
        written += result.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqual(h.raw_final_copy.len, read);
    try std.testing.expectEqual(output.len, written);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 'x'), byte);
}

fn smallPrefixProof(comptime Codec: type) !void {
    const bytes: [40000]u8 = @splat('x');
    for ([_]usize{ 0, 1, 2, 259, bytes.len }) |len|
        try std.testing.expectEqual(checksum.Crc32Best.hash(bytes[0..len]), h.repeatedCrc(len));
    const actual_history = try a.alloc(u8, Codec.IncrementalEntryDecoder.required_history_len);
    defer a.free(actual_history);
    const model_history = try a.alloc(u8, actual_history.len);
    defer a.free(model_history);
    for ([_]Count{ 1, 2, 129 }) |blocks| {
        const metadata = entry(Codec, blocks);
        var actual = try Codec.IncrementalEntryDecoder.init(metadata, actual_history);
        for (0..@as(usize, @intCast(blocks))) |_| try firstRepeat(&actual);
        var model = try Codec.IncrementalEntryDecoder.init(metadata, model_history);
        try liftEntry(&model, blocks);
        try std.testing.expectEqualDeep(actual.snapshot(), model.snapshot());
        try std.testing.expectEqual(actual.raw.?.phase, model.raw.?.phase);
        try std.testing.expectEqual(actual.raw.?.history_pos, model.raw.?.history_pos);
        try std.testing.expectEqual(actual.raw.?.history_len, model.raw.?.history_len);
        try std.testing.expectEqualSlices(u8, actual.history[0..actual.raw.?.history_len], model.history[0..model.raw.?.history_len]);
        try drainEntry(&actual);
        try drainEntry(&model);
        try std.testing.expectEqualDeep(actual.snapshot(), model.snapshot());
    }
}

fn drainArchive(reader: anytype, archive: h.Archive, start: usize, expected: []const u8) !void {
    var output: [258]u8 = undefined;
    var read = start;
    var written: usize = 0;
    var calls: usize = 0;
    while (reader.snapshot().phase != .done) : (calls += 1) {
        try std.testing.expect(calls < 1500);
        const result = try reader.step(archive.bytes[read..@min(archive.bytes.len, read + 1)], output[written..@min(expected.len, written + 3)]);
        read += result.progress.input_read;
        written += result.progress.output_written;
        if (result.status == .need_input and read == archive.bytes.len) return error.TestUnexpectedResult;
    }
    try reader.finish();
    try std.testing.expectEqual(archive.bytes.len, read);
    try std.testing.expectEqualSlices(u8, expected, output[0..written]);
    const snapshot = reader.snapshot();
    try std.testing.expectEqual(@as(Count, archive.bytes.len) + archive.omitted_payload, snapshot.input_read);
    try std.testing.expectEqual(@as(Count, 1), snapshot.completed_entries);
    try std.testing.expectEqual(@as(Count, 1), snapshot.central_entries);
    try std.testing.expectEqual(@as(?Count, archive.central_absolute_offset), snapshot.central_offset);
    try std.testing.expectEqual(@as(?Count, archive.zip64_end_wire_offset - archive.central_wire_offset), snapshot.central_size);
    try std.testing.expectEqualStrings(h.comment, reader.entryAt(0).?.comment.?);
    try std.testing.expectEqualStrings(h.archive_comment, reader.archiveComment());
}

fn header(reader: anytype, archive: h.Archive) !void {
    const result = try reader.step(archive.bytes[0..archive.local_len], &.{});
    try std.testing.expectEqual(.entry_header, result.status);
    try std.testing.expectEqual(archive.local_len, result.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);
    try std.testing.expect(reader.currentEntry().?.zip64_local);
}

fn sourceOffsets(comptime Codec: type) !void {
    inline for (.{ false, true }) |descriptor| {
        inline for (.{ false, true }) |signed| {
            for ([_]Count{ 0, h.boundary - 16, h.boundary + 37 }) |offset| {
                const archive = try h.create(a, .{ .compressed = 2, .uncompressed = 2, .crc32 = checksum.Crc32Best.hash("yz"), .initial_offset = offset, .descriptor = descriptor, .signed = signed }, "yz");
                defer a.free(archive.bytes);
                var reader = try Codec.IncrementalReader.initWithOptions(a, .{ .initial_offset = offset });
                defer reader.deinit();
                try drainArchive(&reader, archive, 0, "yz");
                try std.testing.expectEqual(offset, reader.entryAt(0).?.local_header_offset);
                try std.testing.expectEqual(@as(?Count, 2), reader.entryAt(0).?.uncompressed_size);
                try std.testing.expectEqual(@as(Count, 2), reader.snapshot().output_written);
                if (offset == 0) {
                    var one_shot: [2]u8 = undefined;
                    try std.testing.expectEqual(one_shot.len, try Codec.extractEntryInto(archive.bytes, 0, &one_shot));
                    try std.testing.expectEqualStrings("yz", &one_shot);
                }
                reader.reset();
                try std.testing.expectEqual(@as(Count, 0), reader.snapshot().input_read);
                try drainArchive(&reader, archive, 0, "yz");
            }
        }
    }
}

fn knownWideSource(comptime Codec: type) !void {
    const prefix = h.boundary - 1;
    const size = prefix + 2;
    const archive = try h.create(a, .{ .compressed = size, .uncompressed = size, .crc32 = h.crcWithSuffix(prefix, "yz"), .descriptor = false }, "yz");
    defer a.free(archive.bytes);
    var reader = try Codec.IncrementalReader.initWithOptions(a, .{ .max_entry_output_len = size, .max_total_output_len = size });
    defer reader.deinit();
    try header(&reader, archive);
    try std.testing.expectEqual(@as(?Count, size), reader.currentEntry().?.compressed_size);
    try std.testing.expectEqual(@as(?Count, size), reader.currentEntry().?.uncompressed_size);
    var first: [1]u8 = undefined;
    const accepted = try reader.step("x", &first);
    try std.testing.expectEqual(@as(usize, 1), accepted.progress.output_written);
    // Every complete Stored prefix byte leaves identical codec state except
    // totals and CRC; the first byte above came through the public pipeline.
    const state = &reader.current_state.?.known;
    state.total_input = prefix;
    state.total_output = prefix;
    state.crc.value = ~h.repeatedCrc(prefix);
    reader.total_input = archive.local_len + prefix;
    reader.total_output = prefix;
    try drainArchive(&reader, archive, archive.local_len, "yz");
    try std.testing.expectEqual(size, reader.snapshot().output_written);
    try std.testing.expectEqual(@as(?u32, h.crcWithSuffix(prefix, "yz")), reader.entryAt(0).?.crc32);

    try reader.resetWithOptions(.{ .max_entry_output_len = size - 1 });
    try std.testing.expectError(error.OutputLimitExceeded, reader.step(archive.bytes[0..archive.local_len], &.{}));
    try std.testing.expectEqual(@as(Count, 0), reader.snapshot().output_written);
    try std.testing.expectError(error.ZipReaderFailed, reader.step("", &.{}));
    reader.reset();
    try std.testing.expectEqual(.record_signature, reader.snapshot().phase);
}

fn scannedWideSource(comptime Codec: type) !void {
    const released = h.boundary - 1;
    // A ZIP64 Stored scanner always retains the last 23 undecided bytes.
    const pending = "x" ** 23;
    const suffix = "yz";
    const prefix_size = released + pending.len;
    const size = prefix_size + suffix.len;
    inline for (.{ false, true }) |signed| {
        const archive = try h.create(a, .{ .compressed = size, .uncompressed = size, .crc32 = h.crcWithSuffix(prefix_size, suffix), .signed = signed }, suffix);
        defer a.free(archive.bytes);
        var reader = try Codec.IncrementalReader.initWithOptions(a, .{ .max_entry_output_len = size, .max_total_output_len = size });
        defer reader.deinit();
        try header(&reader, archive);
        var scratch: [1]u8 = undefined;
        const primed = try reader.step(pending, &scratch);
        try std.testing.expectEqual(pending.len, primed.progress.input_read);
        try std.testing.expectEqual(@as(usize, 0), primed.progress.output_written);
        const scanner = &reader.current_state.?.stored_descriptor;
        try std.testing.expectEqual(pending.len, scanner.buffer_len);
        try std.testing.expectEqualSlices(u8, pending, scanner.payload_buffer[0..scanner.buffer_len]);
        scanner.payload_size = released;
        scanner.crc.value = ~h.repeatedCrc(released);
        reader.total_input = archive.local_len + prefix_size;
        reader.total_output = released;
        try drainArchive(&reader, archive, archive.local_len, pending ++ suffix);
        try std.testing.expectEqual(size, reader.snapshot().output_written);
        try std.testing.expectEqual(@as(?Count, size), reader.entryAt(0).?.compressed_size);
    }
}

fn rawWideEntry(comptime Codec: type) !void {
    const blocks = (h.boundary - 1) / h.raw_prefix_output;
    const metadata = entry(Codec, blocks);
    const history = try a.alloc(u8, Codec.IncrementalEntryDecoder.required_history_len);
    defer a.free(history);
    var decoder = try Codec.IncrementalEntryDecoder.init(metadata, history);
    try liftEntry(&decoder, blocks);
    const before = decoder.snapshot();
    try std.testing.expectError(error.OutputLimitExceeded, decoder.resetWithOptions(metadata, .{ .max_output_len = metadata.uncompressed_size - 1 }));
    try std.testing.expectEqualDeep(before, decoder.snapshot());
    try drainEntry(&decoder);
    try std.testing.expectEqual(metadata.uncompressed_size, decoder.snapshot().output_written);
    try std.testing.expectEqual(@as(Count, metadata.compressed_size), decoder.snapshot().input_read);
    var owned = try Codec.OwnedIncrementalEntryDecoder.init(a, metadata);
    defer owned.deinit();
    var seed: [h.raw_prefix_output]u8 = undefined;
    var seed_read: usize = 0;
    var seed_written: usize = 0;
    var seed_calls: usize = 0;
    while (seed_read != h.raw_prefix.len or !owned.state.simple.raw.?.atBlockBoundary()) : (seed_calls += 1) {
        try std.testing.expect(seed_calls < 12);
        const result = try owned.step(h.raw_prefix[seed_read..], seed[seed_written..]);
        seed_read += result.progress.input_read;
        seed_written += result.progress.output_written;
    }
    try std.testing.expectEqual(seed.len, seed_written);
    h.applyRawRepeat(&owned.state.simple.raw.?, blocks);
    owned.state.simple.total_input = blocks * h.raw_prefix.len;
    owned.state.simple.total_output = blocks * h.raw_prefix_output;
    owned.state.simple.crc.value = ~h.repeatedCrc(owned.state.simple.total_output);
    owned.total_input = owned.state.simple.total_input;
    owned.codec_input = owned.state.simple.total_input;
    owned.total_output = owned.state.simple.total_output;
    try drainEntry(&owned);
    try std.testing.expectEqualDeep(decoder.snapshot(), owned.snapshot());
    var wrong = metadata;
    wrong.crc32 ^= 1;
    try decoder.reset(wrong);
    try liftEntry(&decoder, blocks);
    var output: [258]u8 = undefined;
    try std.testing.expectError(error.ChecksumMismatch, drainEntry(&decoder));
    try std.testing.expectError(error.ZipEntryDecoderFailed, decoder.finish());
    var tiny = metadata;
    tiny.method = .stored;
    tiny.compressed_size = 2;
    tiny.uncompressed_size = 2;
    tiny.crc32 = checksum.Crc32Best.hash("yz");
    try decoder.reset(tiny);
    try std.testing.expectEqual(.done, (try decoder.step("yzNEXT", &output)).status);
    try std.testing.expectEqualStrings("yz", output[0..2]);
}

fn rawWideSource(comptime Codec: type) !void {
    const blocks = (h.boundary - 1) / h.raw_prefix_output;
    const prefix_output = blocks * h.raw_prefix_output;
    const compressed = blocks * h.raw_prefix.len + h.raw_final_copy.len;
    const size = prefix_output + 258;
    const expected = "x" ** 258;
    const archive = try h.create(a, .{ .compressed = compressed, .uncompressed = size, .crc32 = h.repeatedCrc(size), .method = 8, .initial_offset = h.boundary + 7 }, &h.raw_final_copy);
    defer a.free(archive.bytes);
    var reader = try Codec.IncrementalReader.initWithOptions(a, .{ .initial_offset = h.boundary + 7 });
    defer reader.deinit();
    try header(&reader, archive);
    const state = &reader.current_state.?.deflate_descriptor;
    var output: [h.raw_prefix_output]u8 = undefined;
    var read: usize = 0;
    var written: usize = 0;
    var calls: usize = 0;
    while (read != h.raw_prefix.len or !state.decoder.atBlockBoundary()) : (calls += 1) {
        try std.testing.expect(calls < 12);
        const result = try reader.step(h.raw_prefix[read..], output[written..]);
        read += result.progress.input_read;
        written += result.progress.output_written;
    }
    try std.testing.expectEqual(output.len, written);
    h.applyRawRepeat(&state.decoder, blocks);
    state.compressed_size = blocks * h.raw_prefix.len;
    state.uncompressed_size = prefix_output;
    state.crc.value = ~h.repeatedCrc(prefix_output);
    reader.total_input = archive.local_len + state.compressed_size;
    reader.total_output = prefix_output;
    try drainArchive(&reader, archive, archive.local_len, expected);
    try std.testing.expectEqual(@as(?Count, size), reader.entryAt(0).?.uncompressed_size);
    try std.testing.expectEqual(size, reader.snapshot().output_written);
}

fn encryptionAtWideOffset(comptime Codec: type) !void {
    const payload = "encrypted tiny suffix";
    const encrypted = try crypto.encryptAlloc(a, payload, .{ .password = "wide password", .header_random = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 } }, 0);
    defer a.free(encrypted);
    const offset = h.boundary + 91;
    const archive = try h.create(a, .{ .compressed = encrypted.len, .uncompressed = payload.len, .crc32 = checksum.Crc32Best.hash(payload), .initial_offset = offset, .encrypted = true }, encrypted);
    defer a.free(archive.bytes);
    var reader = try Codec.IncrementalReader.initWithOptions(a, .{ .initial_offset = offset, .password = "wide password" });
    defer reader.deinit();
    try drainArchive(&reader, archive, 0, payload);
    try std.testing.expectEqual(@as(?u32, checksum.Crc32Best.hash(payload)), reader.entryAt(0).?.crc32);
    try reader.resetWithOptions(.{ .initial_offset = offset });
    try std.testing.expectError(error.PasswordRequired, reader.step(archive.bytes, &.{}));
    try std.testing.expectEqual(@as(Count, 0), reader.snapshot().output_written);
}
