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

fn expect(ok: bool) !void {
    if (!ok) return error.ZstdNativeFrameProbeMismatch;
}

fn expectEqualSlices(expected: []const u8, actual: []const u8) !void {
    if (!std.mem.eql(u8, expected, actual)) return error.ZstdNativeFrameProbeMismatch;
}
