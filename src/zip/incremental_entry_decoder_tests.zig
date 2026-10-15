const std = @import("std");
const checksum = @import("../checksum.zig");
const deflate = @import("../deflate.zig");
const zip = @import("../zip.zig");
const incremental = @import("incremental_entry_decoder.zig");

const DecodeResult = struct {
    bytes: []u8,
    input_read: usize,
};

fn testEntry(
    name: []const u8,
    method: zip.CompressionMethod,
    compressed_size: usize,
    payload: []const u8,
) zip.Entry {
    return .{
        .name = name,
        .method = method,
        .flags = 0,
        .crc32 = checksum.Crc32Best.hash(payload),
        .compressed_size = compressed_size,
        .uncompressed_size = payload.len,
        .local_header_offset = 0,
        .central_header_offset = 0,
        .zip64 = false,
    };
}

fn decodeFragmented(
    allocator: std.mem.Allocator,
    decoder: anytype,
    input: []const u8,
    input_chunk_len: usize,
    output_chunk_len: usize,
) !DecodeResult {
    std.debug.assert(input_chunk_len != 0);
    std.debug.assert(output_chunk_len != 0 and output_chunk_len <= 31);
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(allocator);
    var input_offset: usize = 0;
    var calls: usize = 0;
    const max_calls = input.len * 8 + decoder.snapshot().expected_output_len * 2 + 1024;
    while (true) {
        calls += 1;
        if (calls > max_calls) return error.TestUnexpectedResult;
        const input_end = @min(input.len, input_offset + input_chunk_len);
        var output: [31]u8 = undefined;
        const result = try decoder.step(
            input[input_offset..input_end],
            output[0..output_chunk_len],
        );
        input_offset += result.progress.input_read;
        try decoded.appendSlice(allocator, output[0..result.progress.output_written]);
        if (result.status == .done) break;
        if (result.progress.input_read == 0 and result.progress.output_written == 0) {
            if (result.status == .need_input and input_end != input.len)
                return error.TestUnexpectedResult;
            if (result.status == .need_input and input_end == input.len)
                return error.TruncatedFrame;
            return error.TestUnexpectedResult;
        }
    }
    return .{ .bytes = try decoded.toOwnedSlice(allocator), .input_read = input_offset };
}

test "ZIP incremental entry decoder streams Stored data and leaves suffix unconsumed" {
    const allocator = std.testing.allocator;
    const payload = "stored PK\x07\x08 payload with a descriptor signature";
    const suffix = "next-local-header";
    const input = payload ++ suffix;
    const entry = testEntry("stored.bin", .stored, payload.len, payload);
    var decoder = try incremental.Decoder.init(entry, &.{});

    const blocked = try decoder.step(input, &.{});
    try std.testing.expectEqual(.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.input_read);

    const decoded = try decodeFragmented(allocator, &decoder, input, 3, 2);
    defer allocator.free(decoded.bytes);
    try std.testing.expectEqualSlices(u8, payload, decoded.bytes);
    try std.testing.expectEqual(payload.len, decoded.input_read);
    try std.testing.expectEqual(.done, decoder.snapshot().phase);
    try decoder.finish();
}

test "ZIP incremental entry decoder streams dynamic Deflate under tiny backpressure" {
    const allocator = std.testing.allocator;
    const payload = ("incremental ZIP member payload\n" ** 257) ++ ("abcdef0123456789" ** 83);
    const compressed = try deflate.encodeRawBestAlloc(allocator, payload, .{});
    defer allocator.free(compressed);
    const suffix = "central-directory";
    const input = try std.mem.concat(allocator, u8, &.{ compressed, suffix });
    defer allocator.free(input);
    const entry = testEntry("dynamic.txt", .deflate, compressed.len, payload);
    var decoder = try incremental.OwnedDecoder.init(allocator, entry);
    defer decoder.deinit();

    const blocked = try decoder.step(input, &.{});
    try std.testing.expectEqual(.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.output_written);

    const decoded = try decodeFragmented(
        allocator,
        &decoder,
        input[blocked.progress.input_read..],
        1,
        1,
    );
    defer allocator.free(decoded.bytes);
    try std.testing.expectEqualSlices(u8, payload, decoded.bytes);
    try std.testing.expectEqual(compressed.len, blocked.progress.input_read + decoded.input_read);
    const snapshot = decoder.snapshot();
    try std.testing.expectEqual(compressed.len, snapshot.input_read);
    try std.testing.expectEqual(payload.len, snapshot.output_written);
    try std.testing.expectEqual(snapshot.expected_crc32, snapshot.current_crc32);
}

test "ZIP incremental entry decoder rejects corruption sizes limits and truncation" {
    const allocator = std.testing.allocator;
    const payload = "checksum and size validation" ** 32;
    const compressed = try deflate.encodeRawFixedAlloc(allocator, payload);
    defer allocator.free(compressed);
    const entry = testEntry("checks.txt", .deflate, compressed.len, payload);

    var short_history: [1024]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, incremental.Decoder.init(entry, &short_history));
    var history: [incremental.Decoder.required_history_len]u8 = undefined;
    try std.testing.expectError(
        error.OutputLimitExceeded,
        incremental.Decoder.initWithOptions(entry, &history, .{
            .max_output_len = payload.len - 1,
        }),
    );

    var encrypted = entry;
    encrypted.flags |= 1;
    try std.testing.expectError(error.EncryptedZipEntry, incremental.Decoder.init(encrypted, &history));
    var unsupported = entry;
    unsupported.method = .bzip2;
    try std.testing.expectError(error.UnsupportedZipCompressionMethod, incremental.Decoder.init(unsupported, &history));
    const invalid_stored = testEntry("bad", .stored, payload.len + 1, payload);
    try std.testing.expectError(error.InvalidZipArchive, incremental.Decoder.init(invalid_stored, &.{}));

    var bad_crc = entry;
    bad_crc.crc32 ^= 1;
    var crc_decoder = try incremental.OwnedDecoder.init(allocator, bad_crc);
    defer crc_decoder.deinit();
    try std.testing.expectError(
        error.ChecksumMismatch,
        decodeFragmented(allocator, &crc_decoder, compressed, compressed.len, 31),
    );
    try std.testing.expectEqual(.failed, crc_decoder.snapshot().phase);
    try std.testing.expectError(error.ZipEntryDecoderFailed, crc_decoder.step("", &.{}));

    var truncated = try incremental.OwnedDecoder.init(allocator, entry);
    defer truncated.deinit();
    const truncated_output = try allocator.alloc(u8, payload.len + 1);
    defer allocator.free(truncated_output);
    const short = try truncated.step(compressed[0 .. compressed.len - 1], truncated_output);
    try std.testing.expectEqual(compressed.len - 1, short.progress.input_read);
    try std.testing.expectEqual(.need_input, short.status);
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());

    var oversized_output_entry = entry;
    oversized_output_entry.uncompressed_size += 1;
    var oversized_output = try incremental.OwnedDecoder.init(allocator, oversized_output_entry);
    defer oversized_output.deinit();
    try std.testing.expectError(
        error.SizeMismatch,
        decodeFragmented(allocator, &oversized_output, compressed, compressed.len, 31),
    );

    var oversized_wire_entry = entry;
    oversized_wire_entry.compressed_size += 1;
    var oversized_wire = try incremental.OwnedDecoder.init(allocator, oversized_wire_entry);
    defer oversized_wire.deinit();
    const with_extra = try std.mem.concat(allocator, u8, &.{ compressed, "x" });
    defer allocator.free(with_extra);
    try std.testing.expectError(
        error.InvalidZipArchive,
        decodeFragmented(allocator, &oversized_wire, with_extra, with_extra.len, 31),
    );
}

test "ZIP incremental entry decoder owned state resets across Stored and Deflate members" {
    const allocator = std.testing.allocator;
    const stored_payload = "first stored member";
    const deflated_payload = "second deflated member" ** 80;
    const compressed = try deflate.encodeRawBestAlloc(allocator, deflated_payload, .{});
    defer allocator.free(compressed);
    const stored_entry = testEntry("first", .stored, stored_payload.len, stored_payload);
    const deflated_entry = testEntry("second", .deflate, compressed.len, deflated_payload);
    var decoder = try incremental.OwnedDecoder.init(allocator, stored_entry);
    defer decoder.deinit();

    const first = try decodeFragmented(allocator, &decoder, stored_payload, 2, 3);
    defer allocator.free(first.bytes);
    try std.testing.expectEqualSlices(u8, stored_payload, first.bytes);

    try decoder.reset(deflated_entry);
    const second = try decodeFragmented(allocator, &decoder, compressed, 2, 5);
    defer allocator.free(second.bytes);
    try std.testing.expectEqualSlices(u8, deflated_payload, second.bytes);

    try decoder.reset(stored_entry);
    const third = try decodeFragmented(allocator, &decoder, stored_payload, 1, 1);
    defer allocator.free(third.bytes);
    try std.testing.expectEqualSlices(u8, stored_payload, third.bytes);
}

test "ZIP incremental entry decoder uses archive-validated ZIP64 descriptor payloads" {
    const allocator = std.testing.allocator;
    const stored_payload = "ZIP64 stored payload";
    const deflated_payload = "ZIP64 descriptor-backed Deflate payload\n" ** 96;
    const entries = [_]zip.EncodeEntry{
        .{ .name = "stored.bin", .data = stored_payload, .method = .stored },
        .{ .name = "deflated.txt", .data = deflated_payload, .method = .deflate },
    };
    const archive_bytes = try zip.encodeAlloc(allocator, &entries, .{
        .data_descriptor = true,
        .zip64 = .always,
    });
    defer allocator.free(archive_bytes);
    const archive = try zip.parse(archive_bytes);
    const expected_payloads = [_][]const u8{ stored_payload, deflated_payload };

    var decoder: ?incremental.OwnedDecoder = null;
    defer if (decoder) |*active| active.deinit();
    for (expected_payloads, 0..) |expected, index| {
        const entry = try archive.entryAt(index);
        const compressed = try archive.compressedData(entry);
        var modified = entry;
        modified.crc32 ^= 1;
        try std.testing.expectError(error.InvalidZipArchive, archive.compressedData(modified));
        if (decoder) |*active|
            try active.reset(entry)
        else
            decoder = try incremental.OwnedDecoder.init(allocator, entry);
        const decoded = try decodeFragmented(allocator, &decoder.?, compressed, 5, 7);
        defer allocator.free(decoded.bytes);
        try std.testing.expectEqualSlices(u8, expected, decoded.bytes);
        try std.testing.expectEqual(compressed.len, decoded.input_read);
    }
}
