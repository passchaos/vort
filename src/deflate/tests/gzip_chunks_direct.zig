const std = @import("std");

const allocator = std.testing.allocator;

pub fn contracts(comptime D: type) !void {
    try blockKindsAndIndependentFixture(D);
    try optionalHeaderBoundaries(D);
    try footerAndOutputErrors(D);
    try reusableDecoder(D);
    try largeCrossChunkHistory(D);
}

fn blockKindsAndIndependentFixture(comptime D: type) !void {
    const plain = "gzip direct chunks preserve stored fixed and dynamic payloads\n" ** 4;

    const stored = try D.encodeGzipStoredAlloc(allocator, plain);
    defer allocator.free(stored);
    try checkByteChunks(D, stored, plain);

    const fixed = try D.encodeGzipFixedAlloc(allocator, plain);
    defer allocator.free(fixed);
    try checkByteChunks(D, fixed, plain);

    const dynamic = try D.encodeGzipDynamicWithOptionsAlloc(allocator, plain, D.optionsForLevel(.default));
    defer allocator.free(dynamic);
    try checkByteChunks(D, dynamic, plain);

    // Frozen zlib/gzip output for "hello", independent of Vort's encoder.
    const known = [_]u8{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x86, 0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00 };
    try checkByteChunks(D, &known, "hello");

    const empty = try D.encodeGzipFixedAlloc(allocator, "");
    defer allocator.free(empty);
    const empty_chunks = try interleavedByteChunks(empty);
    defer allocator.free(empty_chunks);
    var no_output: [0]u8 = .{};
    try std.testing.expectEqual(@as(usize, 0), try D.decodeGzipChunksInto(empty_chunks, &no_output));
    const only_empty = [_][]const u8{ "", "", "" };
    try std.testing.expectError(error.TruncatedFrame, D.decodeGzipChunksInto(&only_empty, &no_output));
}

fn optionalHeaderBoundaries(comptime D: type) !void {
    const plain = "optional gzip header fields cross every chunk boundary" ** 3;
    const frame = try D.encodeGzipFixedWithHeaderAlloc(allocator, plain, D.optionsForLevel(.default), .{
        .text = true,
        .mtime = 0x1234_5678,
        .xfl = 2,
        .os = 255,
        .extra = "extra-field",
        .filename = "chunked-name.bin",
        .comment = "chunked-comment",
        .header_crc = true,
    });
    defer allocator.free(frame);
    try checkByteChunks(D, frame, plain);

    const info = try D.parseGzipHeaderInfo(frame);
    var output: [plain.len]u8 = undefined;
    for (0..info.data_offset) |cut| {
        const truncated = [_][]const u8{frame[0..cut]};
        try std.testing.expectError(error.TruncatedFrame, D.decodeGzipChunksInto(&truncated, &output));
    }

    const bad_fhcrc = try allocator.dupe(u8, frame);
    defer allocator.free(bad_fhcrc);
    bad_fhcrc[info.data_offset - 2] ^= 0x01;
    const bad_fhcrc_chunks = try interleavedByteChunks(bad_fhcrc);
    defer allocator.free(bad_fhcrc_chunks);
    try std.testing.expectError(error.BadGzipHeader, D.decodeGzipChunksInto(bad_fhcrc_chunks, &output));
    try std.testing.expectError(error.BadGzipHeader, D.decodeGzipChunksIntoWithOptions(bad_fhcrc_chunks, &output, .{ .ignore_crc32 = true }));

    const bad_magic = try allocator.dupe(u8, frame);
    defer allocator.free(bad_magic);
    bad_magic[0] = 0;
    const bad_magic_chunks = [_][]const u8{ bad_magic[0..1], "", bad_magic[1..] };
    try std.testing.expectError(error.BadGzipHeader, D.decodeGzipChunksInto(&bad_magic_chunks, &output));

    const bad_flags = try allocator.dupe(u8, frame);
    defer allocator.free(bad_flags);
    bad_flags[3] |= 0x20;
    const bad_flags_chunks = [_][]const u8{ bad_flags[0..3], bad_flags[3..4], bad_flags[4..] };
    try std.testing.expectError(error.BadGzipHeader, D.decodeGzipChunksInto(&bad_flags_chunks, &output));
}

fn footerAndOutputErrors(comptime D: type) !void {
    const plain = "gzip direct footer ordering" ** 8;
    const frame = try D.encodeGzipFixedAlloc(allocator, plain);
    defer allocator.free(frame);
    var output: [plain.len]u8 = undefined;

    for (frame.len - 8..frame.len) |cut| {
        const truncated = [_][]const u8{ frame[0..10], "", frame[10..cut] };
        try std.testing.expectError(error.TruncatedFrame, D.decodeGzipChunksInto(&truncated, &output));
        try std.testing.expectError(error.TruncatedFrame, D.decodeGzipChunksIntoWithOptions(&truncated, &output, .{ .ignore_crc32 = true, .ignore_isize = true }));
    }

    const bad = try allocator.dupe(u8, frame);
    defer allocator.free(bad);
    bad[bad.len - 8] ^= 0x80;
    bad[bad.len - 4] ^= 0x40;
    const bad_chunks = [_][]const u8{ bad[0..7], "", bad[7 .. bad.len - 6], bad[bad.len - 6 .. bad.len - 2], bad[bad.len - 2 ..] };
    try std.testing.expectError(error.ChecksumMismatch, D.decodeGzipChunksInto(&bad_chunks, &output));
    try std.testing.expectError(error.SizeMismatch, D.decodeGzipChunksIntoWithOptions(&bad_chunks, &output, .{ .ignore_crc32 = true }));
    try std.testing.expectEqual(plain.len, try D.decodeGzipChunksIntoWithOptions(&bad_chunks, &output, .{ .ignore_crc32 = true, .ignore_isize = true }));
    try std.testing.expectEqualSlices(u8, plain, &output);

    var short: [plain.len - 1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, D.decodeGzipChunksInto(&bad_chunks, &short));

    const trailing = try allocator.alloc(u8, frame.len + 3);
    defer allocator.free(trailing);
    @memcpy(trailing[0..frame.len], frame);
    @memcpy(trailing[frame.len..], "xyz");
    const trailing_chunks = [_][]const u8{ trailing[0..1], "", trailing[1 .. frame.len - 3], trailing[frame.len - 3 .. frame.len + 1], "", trailing[frame.len + 1 ..] };
    try std.testing.expectError(error.TrailingData, D.decodeGzipChunksInto(&trailing_chunks, &output));
    try std.testing.expectEqual(plain.len, try D.decodeGzipChunksIntoWithOptions(&trailing_chunks, &output, .{ .allow_trailing_data = true }));
}

fn reusableDecoder(comptime D: type) !void {
    const plain = "reusable gzip decoder reads direct chunks" ** 4;
    const frame = try D.encodeGzipDynamicWithOptionsAlloc(allocator, plain, D.optionsForLevel(.default));
    defer allocator.free(frame);
    const chunks = try interleavedByteChunks(frame);
    defer allocator.free(chunks);
    var scratch: [plain.len]u8 = undefined;

    _ = try D.GzipDecoder.initFromChunksDirect(chunks, &scratch);
    _ = try D.GzipDecoder.initFromChunksExactSizeDirect(chunks, &scratch, plain.len);
    _ = try D.GzipDecoder.initFromChunksWithOptionsDirect(chunks, &scratch, .{});
    var decoder = try D.GzipDecoder.initFromChunksWithOptionsExactSizeDirect(chunks, &scratch, .{}, plain.len);

    var decoded: [plain.len]u8 = undefined;
    var written: usize = 0;
    while (true) {
        const result = try decoder.step(decoded[written..@min(decoded.len, written + 7)]);
        written += result.progress.output_written;
        if (result.status == .done) {
            try std.testing.expectEqual(frame.len, result.progress.input_read);
            break;
        }
        try std.testing.expectEqual(@as(@TypeOf(result.status), .need_output), result.status);
    }
    try std.testing.expectEqualSlices(u8, plain, &decoded);

    try decoder.resetFromChunksDirect(chunks, &scratch);
    try decoder.resetFromChunksExactSizeDirect(chunks, &scratch, plain.len);
    try decoder.resetFromChunksWithOptionsDirect(chunks, &scratch, .{});
    try decoder.resetFromChunksWithOptionsExactSizeDirect(chunks, &scratch, .{}, plain.len);
    try std.testing.expectError(error.SizeMismatch, decoder.resetFromChunksWithOptionsExactSizeDirect(chunks, &scratch, .{}, plain.len + 1));
    try std.testing.expectEqualStrings("SizeMismatch", decoder.snapshot().last_error_name);
}

fn largeCrossChunkHistory(comptime D: type) !void {
    const plain = try allocator.alloc(u8, 96 * 1024);
    defer allocator.free(plain);
    const pattern = "far gzip chunk history remains visible across reader spans\n";
    for (plain, 0..) |*byte, index| byte.* = pattern[index % pattern.len];

    const frame = try D.encodeGzipFixedAlloc(allocator, plain);
    defer allocator.free(frame);
    try std.testing.expect(frame.len > 24);
    const middle = frame.len / 2;
    const chunks = [_][]const u8{
        frame[0..1],
        "",
        frame[1..10],
        frame[10..middle],
        frame[middle .. frame.len - 7],
        "",
        frame[frame.len - 7 ..],
    };
    const output = try allocator.alloc(u8, plain.len);
    defer allocator.free(output);
    try std.testing.expectEqual(plain.len, try D.decodeGzipChunksInto(&chunks, output));
    try std.testing.expectEqualSlices(u8, plain, output);
}

fn checkByteChunks(comptime D: type, frame: []const u8, plain: []const u8) !void {
    const chunks = try interleavedByteChunks(frame);
    defer allocator.free(chunks);
    const output = try allocator.alloc(u8, plain.len);
    defer allocator.free(output);
    try std.testing.expectEqual(plain.len, try D.decodeGzipChunksInto(chunks, output));
    try std.testing.expectEqualSlices(u8, plain, output);
    try std.testing.expectEqual(plain.len, try D.decodeGzipChunksIntoWithOptions(chunks, output, .{}));
    if (plain.len != 0) try std.testing.expectError(error.OutputTooSmall, D.decodeGzipChunksInto(chunks, output[0 .. output.len - 1]));
}

fn interleavedByteChunks(bytes: []const u8) ![][]const u8 {
    const count = std.math.mul(usize, bytes.len, 2) catch return error.OutOfMemory;
    const chunks = try allocator.alloc([]const u8, count + 2);
    var index: usize = 0;
    chunks[index] = bytes[0..0];
    index += 1;
    for (bytes, 0..) |_, byte_index| {
        chunks[index] = bytes[byte_index .. byte_index + 1];
        chunks[index + 1] = bytes[byte_index + 1 .. byte_index + 1];
        index += 2;
    }
    chunks[index] = bytes[bytes.len..];
    return chunks;
}
