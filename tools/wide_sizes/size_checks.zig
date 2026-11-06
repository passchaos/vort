const std = @import("std");
const codec = @import("codec");
const br = codec.br;
const zstd = codec.zstd;
const h = @import("common.zig");
pub const Receipt = struct {
    decoded_count: u64,
    count_bits: usize,
    successful_apis: usize = 0,
    output_limit_refusals: usize = 0,
    chunks_checked: bool = false,
    metadata_bytes: u64 = 0,
    static_dictionary_copies: u64 = 0,
    checksum_frames: u64 = 0,
    checksum_count_only: bool = false,
    footer_truncation_refusals: usize = 0,
};
fn count(receipt: *Receipt, value: anytype, expected: u64) !void {
    try h.require(value == expected and @bitSizeOf(@TypeOf(value)) == 64);
    receipt.successful_apis += 1;
}

pub fn brotli(a: std.mem.Allocator, wire: []const u8, expected: u64) !Receipt {
    var receipt: Receipt = .{ .decoded_count = expected, .count_bits = @bitSizeOf(@FieldType(br.StreamSummary, "decoded_bytes")) };
    try count(&receipt, try br.decodedStreamSize(wire), expected);
    try count(&receipt, try br.decodedStreamSizeLimited(wire, expected), expected);
    try count(&receipt, try br.decodedStreamSizeWithOptions(wire, .{}), expected);
    if (br.decodedStreamSizeLimited(wire, expected - 1)) |_| return error.ExpectedBrotliOutputLimit else |err| try h.require(err == error.OutputLimitExceeded);
    receipt.output_limit_refusals += 1;
    var diagnostics: br.StreamSummaryDiagnostics = .{};
    const summary = try br.summarizeStreamAllocLimitedWithOptionsAndDiagnostics(a, wire, expected, .{}, &diagnostics);
    try count(&receipt, summary.decoded_bytes, expected);
    try h.require(summary.input_bytes == wire.len and summary.metadata_bytes == h.metadata.len and summary.uses_metadata);
    var history: [65536]u8 = undefined;
    const caller = try br.summarizeStreamLimitedWithHistoryAndOptionsAndDiagnostics(wire, &history, expected, .{}, &diagnostics);
    try count(&receipt, caller.decoded_bytes, expected);
    try h.require(caller.command_count == summary.command_count and caller.metadata_bytes == summary.metadata_bytes);
    const chunks = [_][]const u8{ wire[0..@min(7, wire.len)], wire[@min(7, wire.len)..] };
    const scratch = try a.alloc(u8, wire.len);
    defer a.free(scratch);
    try count(&receipt, try br.decodedStreamChunksSize(&chunks, scratch), expected);
    const chunked = try br.summarizeStreamChunksLimited(&chunks, scratch, expected);
    try count(&receipt, chunked.decoded_bytes, expected);
    receipt.chunks_checked = true;
    receipt.metadata_bytes = summary.metadata_bytes;
    receipt.static_dictionary_copies = summary.static_dictionary_copy_count;
    return receipt;
}

pub fn zstandard(a: std.mem.Allocator, wire: []const u8, expected: u64) !Receipt {
    var receipt: Receipt = .{ .decoded_count = expected, .count_bits = @bitSizeOf(codec.StreamCount) };
    try count(&receipt, try zstd.decodedFrameSize(wire), expected);
    try count(&receipt, try zstd.decodedFrameSizeLimited(wire, expected), expected);
    try count(&receipt, try zstd.decodedFrameSizeWithOptions(wire, .{ .max_output_len = expected }), expected);
    if (zstd.decodedFrameSizeLimited(wire, expected - 1)) |_| return error.ExpectedZstdOutputLimit else |err| try h.require(err == error.OutputLimitExceeded);
    receipt.output_limit_refusals += 1;
    var reusable = zstd.NativeFrameDecoder.init(a);
    defer reusable.deinit();
    try count(&receipt, try reusable.decodedSize(wire), expected);
    try count(&receipt, try reusable.decodedSizeLimited(wire, expected), expected);
    try count(&receipt, try reusable.decodedConcatenatedSize(wire), expected);
    const summary = try zstd.summarizeNativeStream(wire);
    try h.require(summary.declared_content_bytes == expected and summary.checksum_frame_count == 1 and summary.frame_count == 1);
    receipt.checksum_frames = @intCast(summary.checksum_frame_count);
    const chunks = [_][]const u8{ wire[0..@min(7, wire.len)], wire[@min(7, wire.len)..] };
    const scratch = try a.alloc(u8, wire.len);
    defer a.free(scratch);
    try count(&receipt, try zstd.decodedFrameChunksSize(&chunks, scratch), expected);
    receipt.chunks_checked = true;
    // Counting has always required a complete checksum footer without
    // materializing content to compare its hash. Keep that public distinction.
    const corrupt = try a.dupe(u8, wire);
    defer a.free(corrupt);
    corrupt[corrupt.len - 1] ^= 1;
    try count(&receipt, try zstd.decodedFrameSize(corrupt), expected);
    receipt.checksum_count_only = true;
    if (zstd.decodedFrameSize(wire[0 .. wire.len - 1])) |_| return error.ExpectedFooterTruncation else |err| try h.require(err == error.TruncatedFrame);
    receipt.footer_truncation_refusals += 1;
    return receipt;
}
