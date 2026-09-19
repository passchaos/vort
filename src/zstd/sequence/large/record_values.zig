//! Validated compact-record adapter for the wide sequence encoder.
const std = @import("std");
const lz77 = @import("../../../lz77.zig");
const sequence_plan = @import("../../match/double_fast/sequence_plan.zig");

pub const Prepared = struct {
    literal_lens: []usize,
    offsets: []usize,
    match_lens: []usize,
    literal_ends: []usize,
    tail_start: usize,
};

pub fn prepare(
    values: *std.ArrayList(usize),
    allocator: std.mem.Allocator,
    records: []const sequence_plan.Record,
    input_len: usize,
    stats: lz77.PlanStats,
    minimum_match_count: usize,
) !?Prepared {
    if (records.len != stats.matches or stats.matches <= minimum_match_count) return null;
    const value_count = std.math.mul(usize, stats.matches, 4) catch return error.IntegerOverflow;
    try values.resize(allocator, value_count);
    const literal_lens = values.items[0..stats.matches];
    const offsets = values.items[stats.matches .. stats.matches * 2];
    const match_lens = values.items[stats.matches * 2 .. stats.matches * 3];
    const literal_ends = values.items[stats.matches * 3 .. stats.matches * 4];
    const summary = sequence_plan.expand(
        records,
        input_len,
        literal_lens,
        offsets,
        match_lens,
        literal_ends,
    ) orelse return null;
    if (summary.literal_bytes != stats.literals or summary.matched_bytes != stats.matched_bytes or
        summary.literal_bytes + summary.matched_bytes != input_len) return null;
    return .{
        .literal_lens = literal_lens,
        .offsets = offsets,
        .match_lens = match_lens,
        .literal_ends = literal_ends,
        .tail_start = summary.tail_start,
    };
}
