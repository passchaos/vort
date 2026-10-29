//! Shared edge semantics for compact bounded and complete-block DP tables.
const std = @import("std");
const state = @import("state.zig");
const rep = @import("rep.zig");
const prices = @import("prices.zig");
const row_tags = @import("row_tags.zig");
const known_price = @import("sampled_price.zig");
const PriceBudget = @import("price_budget.zig").PriceBudget;

pub const Spill = struct {
    node: state.Node = .{},
    end_position: usize = 0,
    continuation_cost: u64 = std.math.maxInt(u64),
};

pub fn Context(comptime whole: bool, comptime complete: bool) type {
    return struct {
        nodes: []state.NodeFor(whole),
        width: usize,
        base: usize,
        goal: usize,
        parameters: state.Parameters,
        price_budget: *PriceBudget,
        literal_prefix: ?[]const u64 = null,
        spill: ?*Spill = null,
        tag_rows: ?[]row_tags.Tags = null,

        const Self = @This();
        const Node = state.NodeFor(whole);

        pub fn candidate(self: *Self, position: usize, slot: usize, node: Node, distance: usize, maximum: usize) !void {
            const minimum: usize = self.parameters.hq_options.min_match;
            if (maximum < minimum) return;
            const choices = try rep.choices(node.literal_len, distance, node.repeats);
            for (choices.slice()) |*choice| {
                if (complete) {
                    // Includes every interior length, every exact repeat
                    // selector and every endpoint beyond the bounded horizon.
                    for (minimum..maximum + 1) |length|
                        try self.extend(false, position, slot, &node, length, choice, 0);
                } else {
                    // Preserve the old sampling order, duplicates and ties.
                    try self.extend(false, position, slot, &node, maximum, choice, 0);
                    const exhaustive: usize = if (self.parameters.strategy == .btopt) 16 else 64;
                    var length = minimum;
                    while (length < @min(maximum, exhaustive + 1)) : (length += 1)
                        try self.extend(false, position, slot, &node, length, choice, 0);
                    for (prices.ml_bases, prices.ml_bits, 0..) |base, bits, code| {
                        const lower: usize = base;
                        // Later ML intervals also start beyond the strict bound.
                        if (lower >= maximum) break;
                        // Both endpoints belong to this ML symbol already.
                        const upper = lower + (@as(usize, 1) << @intCast(bits)) - 1;
                        if (lower > exhaustive and lower < maximum)
                            try self.extend(true, position, slot, &node, lower, choice, @intCast(code));
                        if (self.parameters.strategy != .btopt and upper > exhaustive and upper < maximum)
                            try self.extend(true, position, slot, &node, upper, choice, @intCast(code));
                    }
                }
            }
        }

        fn extend(self: *Self, comptime known_match: bool, position: usize, slot: usize, node: *const Node, length: usize, choice: *const rep.Choice, match_code: u8) !void {
            try self.price_budget.admit();
            if (self.parameters.profile) |profile| {
                profile.add("price_evaluations", 1);
                profile.add("optimal_transitions", 1);
                profile.recordMatchLengthConsidered(length);
            }
            const cost = if (known_match)
                try known_price.sequencePrice(self.parameters.entropy, node.literal_len, length, choice.offset_value, match_code)
            else
                try self.parameters.entropy.sequencePrice(node.literal_len, length, choice.offset_value);
            const next: Node = .{
                .cost = std.math.add(u64, node.cost, cost) catch return error.IntegerOverflow,
                .repeats = choice.repeats,
                .previous_position = @intCast(position),
                .previous_slot = @intCast(slot),
                .match_len = @intCast(length),
                .distance = choice.distance,
                .offset_value = choice.offset_value,
            };
            const target = position + length;
            if (whole or !complete) {
                std.debug.assert(target <= self.goal);
                if (self.tag_rows) |tags| {
                    _ = row_tags.insert(self.nodes[target * self.width ..][0..self.width], &tags[target], next);
                } else _ = state.insert(self.nodes[target * self.width ..][0..self.width], next);
            } else if (target <= self.goal) {
                if (self.tag_rows) |tags| {
                    _ = row_tags.insert(self.nodes[target * self.width ..][0..self.width], &tags[target], next);
                } else _ = state.insert(self.nodes[target * self.width ..][0..self.width], next);
            } else {
                const literal_prefix = self.literal_prefix.?;
                const remaining_literals = literal_prefix[literal_prefix.len - 1] - literal_prefix[self.base + target];
                const continuation = std.math.add(u64, next.cost, remaining_literals) catch return error.IntegerOverflow;
                const spill = self.spill.?;
                if (continuation < spill.continuation_cost) {
                    spill.* = .{ .node = next, .end_position = target, .continuation_cost = continuation };
                }
            }
        }
    };
}

test {
    _ = @import("search_edges_tests.zig");
    _ = @import("known_ml_tests.zig");
}
