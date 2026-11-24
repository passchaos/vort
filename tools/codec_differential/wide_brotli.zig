//! Load-bearing coverage of standard-window copies beyond the fixed summary
//! history, using wire bytes emitted and independently decoded by libbrotli.
const std = @import("std");
const vort = @import("vort");

pub const window_bits = 22;
pub const quality = 6;
pub const encoder = "libbrotli BrotliEncoderCompress(q=6,lgwin=22,generic)";
const fixed_history = (1 << vort.brotliDefaultWindowBits) - 16;
const full_history = (1 << window_bits) - 16;
const sentinel: u8 = 0xa5;

pub const Receipt = struct {
    window_bits: u5,
    max_lz77_distance: usize,
    compressed_meta_blocks: vort.StreamCount,
    fixed_preflight: enum { ok, history_exhausted },
    peak_requested_bytes: usize,
};

/// Two identical 128 KiB spans separated by more than the old history cap.
/// The deterministic first span admits neither short-period nor text matches.
pub fn smokeInput(a: std.mem.Allocator) ![]u8 {
    const span = 128 * 1024;
    const displacement = span + 96 * 1024;
    const input = try a.alloc(u8, displacement + span + 16);
    var state: u64 = 0xfa37_e970_5e71_4b87;
    for (input[0..displacement]) |*byte| {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        byte.* = @truncate(state);
    }
    @memcpy(input[displacement..][0..span], input[0..span]);
    @memcpy(input[displacement + span ..], "end-of-wide-copy");
    return input;
}

pub fn verify(a: std.mem.Allocator, wire: []const u8, plain: []const u8) !Receipt {
    const history = try a.alloc(u8, @min(full_history, plain.len));
    defer a.free(history);
    const summary = try vort.brSummarizeStreamLimitedWithHistory(wire, history, plain.len);
    if (summary.large_window or summary.window_bits > window_bits or summary.decoded_bytes != plain.len)
        return error.UnexpectedBrotliSummary;
    if (summary.max_lz77_distance <= fixed_history) return error.MissingWideBrotliCopy;

    const fixed_preflight: @FieldType(Receipt, "fixed_preflight") = if (vort.brDecodedStreamSize(wire)) |size| result: {
        if (size != plain.len) return error.PreflightSizeMismatch;
        break :result .ok;
    } else |err| switch (err) {
        error.UnsupportedBrotliFeature => .history_exhausted,
        else => return err,
    };
    var profile: vort.BrotliDecodeMemoryProfile = .{};
    const options: vort.BrotliDecodePreflightOptions = .{
        .history = history,
        .max_output_len = plain.len,
        .expected_output_len = plain.len,
        .decode = .{ .memory_profile = &profile, .max_total_working_memory = 0 },
    };
    const guarded = try a.alloc(u8, plain.len + 2);
    defer a.free(guarded);
    const output = guarded[1 .. guarded.len - 1];
    @memset(guarded, sentinel);

    var short_limit = options;
    short_limit.max_output_len -= 1;
    try expectRefusal(vort.brDecodeStreamIntoWithPreflight(wire, output, short_limit), error.OutputLimitExceeded, guarded);
    try expectRefusal(vort.brDecodeStreamIntoWithPreflight(wire[0 .. wire.len - 1], output, options), error.TruncatedFrame, guarded);
    const joined = try std.mem.concat(a, u8, &.{ wire, "transport-tail" });
    defer a.free(joined);
    try expectRefusal(vort.brDecodeStreamIntoWithPreflight(joined, output, options), error.TrailingData, guarded);

    if (try vort.brDecodedStreamSizeWithPreflight(wire, options) != plain.len)
        return error.PreflightSizeMismatch;
    const prefix = try vort.brDecodedStreamPrefixSizeWithPreflight(joined, options);
    if (prefix.input_read != wire.len or prefix.decoded_bytes != plain.len)
        return error.PreflightSizeMismatch;
    const decoded = try vort.brDecodeStreamPrefixIntoWithPreflight(joined, output, options);
    if (decoded.input_read != wire.len or decoded.output_written != plain.len)
        return error.PreflightSizeMismatch;
    try checkOutput(guarded, plain);
    @memset(output, sentinel);
    if (try vort.brDecodeStreamIntoWithPreflight(wire, output, options) != plain.len)
        return error.PreflightSizeMismatch;
    try checkOutput(guarded, plain);
    try verifyChunks(wire, plain, guarded, joined, options);
    try verifyDirectChunks(a, wire, plain, guarded, options);
    if (!profile.available or profile.peak_requested_bytes != 0 or profile.live_requested_bytes != 0)
        return error.UnexpectedPreflightAllocation;
    return .{
        .window_bits = summary.window_bits,
        .max_lz77_distance = summary.max_lz77_distance,
        .compressed_meta_blocks = summary.compressed_meta_block_count,
        .fixed_preflight = fixed_preflight,
        .peak_requested_bytes = profile.peak_requested_bytes,
    };
}

fn verifyChunks(wire: []const u8, plain: []const u8, guarded: []u8, scratch: []u8, options: vort.BrotliDecodePreflightOptions) !void {
    const split = wire.len / 2;
    const chunks = [_][]const u8{ wire[0..1], &.{}, wire[1..split], wire[split..], "transport-tail" };
    const stream_chunks = chunks[0 .. chunks.len - 1];
    const output = guarded[1 .. guarded.len - 1];
    if (try vort.brDecodedStreamChunksSizeWithPreflight(stream_chunks, scratch, options) != plain.len)
        return error.PreflightSizeMismatch;
    const prefix = try vort.brDecodedStreamPrefixChunksSizeWithPreflight(&chunks, scratch, options);
    if (prefix.input_read != wire.len or prefix.decoded_bytes != plain.len)
        return error.PreflightSizeMismatch;
    @memset(output, sentinel);
    try expectRefusal(vort.brDecodeStreamChunksIntoWithPreflight(&chunks, scratch, output, options), error.TrailingData, guarded);
    const decoded = try vort.brDecodeStreamPrefixChunksIntoWithPreflight(&chunks, scratch, output, options);
    if (decoded.input_read != wire.len or decoded.output_written != plain.len)
        return error.PreflightSizeMismatch;
    try checkOutput(guarded, plain);
    @memset(output, sentinel);
    if (try vort.brDecodeStreamChunksIntoWithPreflight(stream_chunks, scratch, output, options) != plain.len)
        return error.PreflightSizeMismatch;
    try checkOutput(guarded, plain);
}

fn verifyDirectChunks(a: std.mem.Allocator, wire: []const u8, plain: []const u8, guarded: []u8, preflight: vort.BrotliDecodePreflightOptions) !void {
    const stride = 257;
    const chunk_count = std.math.divCeil(usize, wire.len, stride) catch unreachable;
    const chunks = try a.alloc([]const u8, chunk_count + 2);
    defer a.free(chunks);
    chunks[0] = &.{};
    for (chunks[1..][0..chunk_count], 0..) |*chunk, i| {
        const start = i * stride;
        chunk.* = wire[start..][0..@min(stride, wire.len - start)];
    }
    chunks[chunks.len - 1] = "transport-tail";

    const workspace = try a.create(vort.BrotliDirectChunkPreflightWorkspace);
    defer a.destroy(workspace);
    const options: vort.BrotliDirectChunkPreflightWorkspace.Options = .{ .preflight = preflight };
    const output = guarded[1 .. guarded.len - 1];
    @memset(output, sentinel);
    try expectRefusal(workspace.decodeInto(chunks, output, options), error.TrailingData, guarded);
    const decoded = try workspace.decodePrefixInto(chunks, output, options);
    if (decoded.input_read != wire.len or decoded.output_written != plain.len)
        return error.PreflightSizeMismatch;
    try checkOutput(guarded, plain);
}

fn expectRefusal(result: anyerror!usize, expected: anyerror, guarded: []const u8) !void {
    if (result) |_| return error.PreflightAcceptedInvalidInput else |err| {
        if (err != expected) return err;
    }
    if (!std.mem.allEqual(u8, guarded, sentinel)) return error.PreflightModifiedFailedOutput;
}

fn checkOutput(guarded: []const u8, plain: []const u8) !void {
    if (guarded[0] != sentinel or guarded[guarded.len - 1] != sentinel)
        return error.PreflightDamagedOutputGuard;
    if (!std.mem.eql(u8, guarded[1 .. guarded.len - 1], plain))
        return error.PreflightOutputMismatch;
}
