//! Whole-stream fixed/dynamic Deflate64 candidate over bounded borrowed chunks.
//! Planning and emission borrow input and its preceding 64KiB history. The match
//! index owns heap workspace; tree plans use bounded local storage. No input
//! clone, retained token list or per-block encoded candidate is allocated.
//! Padding is applied once at stream end.
const std = @import("std");
const core = @import("../core.zig");
const matching = @import("stream_match.zig");
const blocks = @import("stream_blocks.zig");
const choice = @import("block_choice.zig");

pub const chunk_len: usize = 128 * 1024;
pub const Matcher = matching.Matcher;
pub const Error = core.Error || std.mem.Allocator.Error;
pub const Plan = struct {
    bit_len: u128,
    encoded_len: u128,
    stats: blocks.Stats,
};

/// Size the complete compressed candidate before allocating its output. Local
/// helper arithmetic is bounded by chunk_len; cross-chunk sums are checked.
pub fn plan(allocator: std.mem.Allocator, matcher: *Matcher, input: []const u8, max_chain: usize, nice_length: u32) Error!Plan {
    var result: Plan = .{ .bit_len = 0, .encoded_len = 0, .stats = .{} };
    var offset: usize = 0;
    while (true) {
        const take = @min(chunk_len, input.len - offset);
        const end = offset + take; // take is bounded by the remaining slice.
        const history_start = offset - @min(offset, matching.window_len);
        if (take != 0) try matcher.ensureForSize(allocator, end - history_start);
        const block = try blocks.dynamicPlan(matcher, input[history_start..offset], input[offset..end], max_chain, nice_length);
        const bits = @min(block.fixed_bits, block.bits);
        result.bit_len = std.math.add(u128, result.bit_len, bits) catch return error.IntegerOverflow;
        result.stats.match_count = std.math.add(usize, result.stats.match_count, block.stats.match_count) catch return error.IntegerOverflow;
        result.stats.max_match_length = @max(result.stats.max_match_length, block.stats.max_match_length);
        result.stats.max_match_distance = @max(result.stats.max_match_distance, block.stats.max_match_distance);
        matcher.reset();
        offset = end;
        if (offset == input.len) break;
    }
    result.encoded_len = result.bit_len / 8 + @intFromBool(result.bit_len % 8 != 0);
    matcher.reset();
    return result;
}

/// A compressed candidate may exceed usize even though stored output still fits.
/// Compare in the wide cost domain before narrowing an actual allocation.
/// Quotient/remainder ceiling stays defined for every u128 bit count, and a
/// strict win proves the returned size is representable by the local target.
pub fn candidateSize(bit_len: u128, stored_size: usize) ?usize {
    const encoded_len = bit_len / 8 + @intFromBool(bit_len % 8 != 0);
    if (encoded_len >= @as(u128, stored_size)) return null;
    return @intCast(encoded_len);
}

/// Replay a successful plan into its admitted exact output allocation. The
/// same input, options and chunk boundaries produce the same match decisions.
/// Each block rebuilds its bounded tree plan, then replays matches for emission;
/// including preflight, this takes three match traversals for nonempty input.
/// Input and output must not overlap; the public encoder allocates output only
/// after plan admission, preserving Into/Append caller-buffer atomicity.
pub fn emit(matcher: *Matcher, input: []const u8, output: []u8, max_chain: usize, nice_length: u32) Error!usize {
    var writer: blocks.Writer = .{ .state = .{}, .output = output };
    var offset: usize = 0;
    while (true) {
        const take = @min(chunk_len, input.len - offset);
        const end = offset + take;
        const history_start = offset - @min(offset, matching.window_len);
        const history = input[history_start..offset];
        const block = input[offset..end];
        const coding = try blocks.dynamicPlan(matcher, history, block, max_chain, nice_length);
        switch (choice.compressed(coding.fixed_bits, coding.bits)) {
            .fixed => blocks.writeFixed(&writer, matcher, history, block, max_chain, nice_length, end == input.len),
            .dynamic => blocks.writeDynamic(&writer, matcher, history, block, max_chain, nice_length, end == input.len, &coding),
            .stored => unreachable,
        }
        offset = end;
        if (offset == input.len) break;
    }
    writer.alignToByte();
    matcher.reset();
    return writer.len;
}
