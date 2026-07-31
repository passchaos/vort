const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var checked: usize = 0;
    try checkDirectHuffmanBoundaries(init.gpa);
    checked += 1;
    try checkHighByteFallback(init.gpa);
    checked += 1;
    checked += try checkHandcraftedFrameValidation(init.gpa);
    checked += try checkHandcraftedHeaderAndSkippableValidation(init.gpa);

    try stdout.print("zstd_native_frame_probe_ok cases={d}\n", .{checked});
    try stdout.flush();
}

fn checkDirectHuffmanBoundaries(allocator: std.mem.Allocator) !void {
    var payload: [129 * 64]u8 = undefined;
    for (payload[0..129], 0..) |*byte, i| byte.* = @intCast(i);
    var state: u32 = 0x1290_0f5e;
    for (payload[129..]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast((state >> 16) % 129);
    }

    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, &payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer allocator.free(encoded.frame);
    try expect(encoded.mode == .literal_only);
    try expect((try vort.zstdDecodedNativeFrameSize(encoded.frame)) == payload.len);

    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
    try expect(first_block.block_type == .compressed);
    const summary = try vort.zstdSummarizeNativeFrameBlocks(encoded.frame);
    try expect(summary.compressed_block_count == 1);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, encoded.frame);
    defer allocator.free(decoded);
    try expectEqualSlices(&payload, decoded);

    var into: [payload.len]u8 = undefined;
    const written = try vort.zstdDecodeNativeFrameInto(encoded.frame, &into);
    try expect(written == payload.len);
    try expectEqualSlices(&payload, &into);
}

fn checkHighByteFallback(allocator: std.mem.Allocator) !void {
    var payload: [2048]u8 = undefined;
    var state: u32 = 0xfeed_beef;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast(129 + ((state >> 16) % 127));
    }

    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, &payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer allocator.free(encoded.frame);
    try expect(encoded.mode == .literal_only);
    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
    // Current native Huffman writer intentionally falls back to a raw block for
    // binary literals above the direct-tree limit. This gate protects safe
    // behavior until FSE-compressed Huffman weights support can replace it.
    try expect(first_block.block_type == .raw);
    try expect(vort.zstdNativeMaxDirectHuffmanSymbol == 128);

    const decoded = try vort.zstdDecodeNativeFrameAlloc(allocator, encoded.frame);
    defer allocator.free(decoded);
    try expectEqualSlices(&payload, decoded);
}

fn checkHandcraftedFrameValidation(allocator: std.mem.Allocator) !usize {
    var checked: usize = 0;

    const checksum_payload = "zstd-checksum";
    var wrong_checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &wrong_checksum, @as(u32, @truncate(std.hash.XxHash64.hash(0, checksum_payload))) ^ 0x01, .little);
    const checksum_mismatch = try handcraftedRawFrame(allocator, checksum_payload.len, checksum_payload, &wrong_checksum, true);
    defer allocator.free(checksum_mismatch);
    try expect((try vort.zstdDecodedNativeFrameSize(checksum_mismatch)) == checksum_payload.len);
    var checksum_out: [checksum_payload.len]u8 = undefined;
    try expectError(error.ChecksumMismatch, vort.zstdDecodeNativeFrameInto(checksum_mismatch, &checksum_out));
    try expectAllocError(allocator, error.ChecksumMismatch, vort.zstdDecodeNativeFrameAlloc(allocator, checksum_mismatch));
    const checksum_summary = try vort.zstdSummarizeNativeStream(checksum_mismatch);
    try expect(checksum_summary.frame_count == 1);
    try expect(checksum_summary.raw_block_count == 1);
    checked += 1;

    const truncated_checksum = try handcraftedRawFrame(allocator, checksum_payload.len, checksum_payload, "\x00\x00", true);
    defer allocator.free(truncated_checksum);
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSize(truncated_checksum));
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(truncated_checksum, &checksum_out));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAlloc(allocator, truncated_checksum));
    try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeStream(truncated_checksum));
    try expectStreamIteratorError(truncated_checksum, error.TruncatedFrame);
    checked += 1;

    const truncated_payload = try handcraftedRawFrame(allocator, 4, "ab", "", false);
    defer allocator.free(truncated_payload);
    _ = try vort.zstdInspectNativeFrameHeader(truncated_payload);
    try expectError(error.TruncatedFrame, vort.zstdDecodedNativeFrameSize(truncated_payload));
    var payload_out: [4]u8 = undefined;
    try expectError(error.TruncatedFrame, vort.zstdDecodeNativeFrameInto(truncated_payload, &payload_out));
    try expectAllocError(allocator, error.TruncatedFrame, vort.zstdDecodeNativeFrameAlloc(allocator, truncated_payload));
    try expectError(error.TruncatedFrame, vort.zstdSummarizeNativeStream(truncated_payload));
    try expectStreamIteratorError(truncated_payload, error.TruncatedFrame);
    checked += 1;

    return checked;
}

fn checkHandcraftedHeaderAndSkippableValidation(allocator: std.mem.Allocator) !usize {
    var checked: usize = 0;

    // Descriptor advertises a 2-byte Dictionary_ID field but only one byte is
    // present. Keep the window descriptor valid so this specifically covers
    // field-length accounting, not earlier frame-header parsing.
    const truncated_dictionary_id = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x02, // Dictionary_ID flag = 2 bytes, no checksum/content-size.
        0x00, // 1 KiB window descriptor.
        0x34,
    };
    try expectNativeHeaderAndStreamError(allocator, &truncated_dictionary_id, error.TruncatedFrame);
    checked += 1;

    // Content_Size flag 1 requires a 2-byte size field for a non-single-segment
    // frame. Supplying one byte makes the header invalid before block parsing.
    const truncated_content_size = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd,
        0x40, // Content_Size flag = 1; window descriptor still follows.
        0x00,
        0x03,
    };
    try expectNativeHeaderAndStreamError(allocator, &truncated_content_size, error.TruncatedFrame);
    checked += 1;

    const truncated_skippable = try handcraftedSkippableFrame(allocator, 6, "abc");
    defer allocator.free(truncated_skippable);
    try expectError(error.TruncatedFrame, vort.zstdInspectNativeSkippableFrame(truncated_skippable));
    try expectNativeStreamOnlyError(allocator, truncated_skippable, error.TruncatedFrame);
    checked += 1;

    return checked;
}

fn handcraftedRawFrame(
    allocator: std.mem.Allocator,
    claimed_len: usize,
    payload: []const u8,
    trailing: []const u8,
    content_checksum: bool,
) ![]u8 {
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(allocator);
    try frame.appendSlice(allocator, &.{ 0x28, 0xb5, 0x2f, 0xfd });
    try frame.append(allocator, if (content_checksum) 0x04 else 0x00);
    try frame.append(allocator, 0x00); // 1 KiB window descriptor for no-content-size frames.
    if (claimed_len > std.compress.zstd.block_size_max) return error.ZstdNativeFrameProbeMismatch;
    const block_header_value: u32 = (@as(u32, @intCast(claimed_len)) << 3) | 1;
    try frame.append(allocator, @truncate(block_header_value));
    try frame.append(allocator, @truncate(block_header_value >> 8));
    try frame.append(allocator, @truncate(block_header_value >> 16));
    try frame.appendSlice(allocator, payload);
    try frame.appendSlice(allocator, trailing);
    return try frame.toOwnedSlice(allocator);
}

fn handcraftedSkippableFrame(allocator: std.mem.Allocator, claimed_len: u32, payload: []const u8) ![]u8 {
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(allocator);
    var header: [8]u8 = undefined;
    std.mem.writeInt(u32, header[0..4], 0x184d2a50, .little);
    std.mem.writeInt(u32, header[4..8], claimed_len, .little);
    try frame.appendSlice(allocator, &header);
    try frame.appendSlice(allocator, payload);
    return try frame.toOwnedSlice(allocator);
}

fn expect(ok: bool) !void {
    if (!ok) return error.ZstdNativeFrameProbeMismatch;
}

fn expectEqualSlices(expected: []const u8, actual: []const u8) !void {
    if (!std.mem.eql(u8, expected, actual)) return error.ZstdNativeFrameProbeMismatch;
}

fn expectError(expected: anyerror, result: anytype) !void {
    if (result) |_| {
        return error.ZstdNativeFrameProbeExpectedError;
    } else |err| {
        if (err != expected) return err;
    }
}

fn expectAllocError(allocator: std.mem.Allocator, expected: anyerror, result: anytype) !void {
    if (result) |decoded| {
        allocator.free(decoded);
        return error.ZstdNativeFrameProbeExpectedError;
    } else |err| {
        if (err != expected) return err;
    }
}

fn expectStreamIteratorError(frame: []const u8, expected: anyerror) !void {
    var iterator = vort.zstdIterateNativeStream(frame);
    if (iterator.next()) |_| {
        return error.ZstdNativeFrameProbeExpectedError;
    } else |err| {
        if (err != expected) return err;
    }
}

fn expectNativeHeaderAndStreamError(allocator: std.mem.Allocator, frame: []const u8, expected: anyerror) !void {
    try expectError(expected, vort.zstdInspectNativeFrameHeader(frame));
    try expectNativeStreamOnlyError(allocator, frame, expected);
}

fn expectNativeStreamOnlyError(allocator: std.mem.Allocator, frame: []const u8, expected: anyerror) !void {
    try expectError(expected, vort.zstdDecodedNativeFrameSize(frame));

    var output: [1]u8 = undefined;
    try expectError(expected, vort.zstdDecodeNativeFrameInto(frame, &output));
    try expectAllocError(allocator, expected, vort.zstdDecodeNativeFrameAlloc(allocator, frame));
    try expectError(expected, vort.zstdSummarizeNativeStream(frame));
    try expectStreamIteratorError(frame, expected);
}
