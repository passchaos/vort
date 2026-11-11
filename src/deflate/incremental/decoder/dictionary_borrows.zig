//! A temporary dictionary is consumed before receiver metadata is updated.
//! Protect only the actual seed writer; source/history overlap uses memmove.
const std = @import("std");
const overlaps = @import("../../decoder/output_alias.zig").overlaps;

pub fn validateSeed(receiver: []const u8, history: []u8, dictionary: []const u8) error{InvalidBlockPlan}!void {
    const keep = @min(history.len, dictionary.len);
    if (overlaps(receiver, history[0..keep])) return error.InvalidBlockPlan;
}
