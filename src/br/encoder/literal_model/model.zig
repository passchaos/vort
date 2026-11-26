//! Owned literal trees for one immutable input and command group. Command and
//! distance costs, full payload/header bits and wire geometry stay elsewhere.
const std = @import("std");
const prepared = @import("../prepared_literal.zig");
const context = @import("../literal_context_split.zig");
const bit_count = @import("../../../io/bit_count.zig");

pub const Alphabet = prepared.Alphabet;
pub const Key = prepared.Key;
pub const max_trees = context.max_trees;

pub const Model = struct {
    alphabets: []Alphabet,
    lengths: [][256]u4,
    key: Key,
    normalized_context: ?context.Candidate,
    literal_count: usize,
    literal_payload_bits: bit_count.BitCount,

    pub fn symbolCount(self: *const Model) usize {
        var total: usize = 0;
        for (self.alphabets) |*alphabet| total += alphabet.len;
        return total;
    }

    pub fn deinit(self: *Model, allocator: std.mem.Allocator) void {
        allocator.free(self.alphabets);
        allocator.free(self.lengths);
        self.alphabets = &.{};
        self.lengths = &.{};
    }
};
