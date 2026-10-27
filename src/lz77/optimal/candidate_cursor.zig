//! Reuse a sparse existing suffix chain with exact original candidate budgets.
const std = @import("std");
const anchors = @import("rarest_anchor.zig");
const Ordinals = @import("prefix_jumps.zig").Index;
const empty = std.math.maxInt(u32);

pub const Candidate = struct { position: usize, raw_count: usize, prefix_count: usize };

pub const Cursor = struct {
    anchor: usize = 0,
    cursor: u32 = empty,
    built_through: usize = 0,
    selected: anchors.Anchor = .{},
    initialized: bool = false,

    pub fn next(self: *Cursor, input: []const u8, prev: []const u32, ordinals: *const Ordinals, pos: usize, raw_next: usize, coverage: usize, window: usize, chain_limit: usize, candidate_limit: usize) ?Candidate {
        std.debug.assert(coverage >= 8 and raw_next < pos and pos + coverage < input.len);
        // Every longer match contains all the covered prefixes. Incrementally
        // select the chain with the farthest newest predecessor.
        if (coverage > self.built_through) {
            const from = if (self.built_through == 0) 0 else self.built_through - 1;
            self.selected = anchors.extend(prev, pos, from, coverage - 2, self.selected);
            self.built_through = coverage;
        }
        if (self.selected.gap > window) return null;
        const anchor = self.selected.offset;
        if (!self.initialized or anchor != self.anchor) {
            self.initialized = true;
            self.anchor = anchor;
            self.cursor = self.selected.predecessor;
        }
        while (self.cursor != empty) {
            const suffix: usize = self.cursor;
            if (suffix < anchor) return null;
            const jumped = suffix - anchor;
            if (jumped > raw_next) {
                self.cursor = prev[suffix];
                continue;
            }
            if (pos - jumped > window) return null;
            // Other-prefix hash collisions have incomparable ordinals.
            if (std.mem.readInt(u24, input[jumped..][0..3], .little) !=
                std.mem.readInt(u24, input[pos..][0..3], .little))
            {
                self.cursor = prev[suffix];
                continue;
            }
            const raw_count = ordinals.rawCount(pos, jumped);
            if (raw_count > chain_limit) return null;
            const prefix_count = ordinals.prefixCount(pos, jumped);
            if (prefix_count > candidate_limit) return null;
            return .{ .position = jumped, .raw_count = raw_count, .prefix_count = prefix_count };
        }
        return null;
    }
};
