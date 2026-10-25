//! Whole-stream fixed Deflate64 candidate over bounded borrowed chunks.
//! Both passes borrow input and its preceding 64KiB history. Only the match
//! index owns workspace; no input clone, retained token list or per-block
//! encoded candidate is allocated. Padding is applied once at stream end.
const std = @import("std");
const core = @import("../core.zig");
const bit_count = @import("../io/bit_count.zig");
const matching = @import("stream_match.zig");
const blocks = @import("stream_blocks.zig");

pub const chunk_len: usize = 128 * 1024;
pub const Matcher = matching.Matcher;
pub const Error = core.Error || std.mem.Allocator.Error;
pub const Plan = struct {
    bit_len: bit_count.BitCount,
    encoded_len: usize,
    stats: blocks.Stats,
};

/// Size the complete fixed candidate before allocating its output. Local
/// helper arithmetic is bounded by chunk_len; cross-chunk sums are checked.
pub fn plan(allocator: std.mem.Allocator, matcher: *Matcher, input: []const u8, max_chain: usize, nice_length: u32) Error!Plan {
    if (input.len != 0) try matcher.ensure(allocator);
    var result: Plan = .{ .bit_len = 0, .encoded_len = 0, .stats = .{} };
    var offset: usize = 0;
    while (true) {
        const take = @min(chunk_len, input.len - offset);
        const end = offset + take; // take is bounded by the remaining slice.
        const history_start = offset - @min(offset, matching.window_len);
        const block = blocks.fixedPlan(matcher, input[history_start..offset], input[offset..end], max_chain, nice_length);
        result.bit_len = std.math.add(bit_count.BitCount, result.bit_len, block.bits) catch return error.IntegerOverflow;
        result.stats.match_count = std.math.add(usize, result.stats.match_count, block.stats.match_count) catch return error.IntegerOverflow;
        result.stats.max_match_length = @max(result.stats.max_match_length, block.stats.max_match_length);
        result.stats.max_match_distance = @max(result.stats.max_match_distance, block.stats.max_match_distance);
        offset = end;
        if (offset == input.len) break;
    }
    result.encoded_len = try bit_count.ceilBytes(result.bit_len);
    matcher.reset();
    return result;
}

/// Replay a successful plan into its admitted exact output allocation. The
/// same input, options and chunk boundaries produce the same match decisions.
/// Input and output must not overlap; the public encoder allocates output only
/// after plan admission, preserving Into/Append caller-buffer atomicity.
pub fn emit(matcher: *Matcher, input: []const u8, output: []u8, max_chain: usize, nice_length: u32) usize {
    var writer: blocks.Writer = .{ .state = .{}, .output = output };
    var offset: usize = 0;
    while (true) {
        const take = @min(chunk_len, input.len - offset);
        const end = offset + take;
        const history_start = offset - @min(offset, matching.window_len);
        blocks.writeFixed(&writer, matcher, input[history_start..offset], input[offset..end], max_chain, nice_length, end == input.len);
        offset = end;
        if (offset == input.len) break;
    }
    writer.alignToByte();
    matcher.reset();
    return writer.len;
}
