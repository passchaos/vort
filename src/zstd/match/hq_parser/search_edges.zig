//! Shared edge semantics for compact bounded and complete-block DP tables.
const std = @import("std");
const state = @import("state.zig");
const rep = @import("rep.zig");
const prices = @import("prices.zig");
const row_tags = @import("row_tags.zig");
const known_price = @import("sampled_price.zig");
const prepared_price = @import("prepared_price.zig");
const enumeration_count = @import("enumeration_count.zig");
const choice_dominance = @import("choice_dominance.zig");
const PriceBudget = @import("price_budget.zig").PriceBudget;

pub const Spill = struct {
    node: state.Node = .{},
    end_position: usize = 0,
    continuation_cost: u64 = std.math.maxInt(u64),
};

pub fn Context(comptime whole: bool, comptime complete: bool) type {
    return ContextMode(whole, complete, false);
}
/// Requires every target row to have nondecreasing costs. DP initializes
/// equal vacant sentinels and uses cost-ordered insertion to retain this
/// invariant. Direct callers with arbitrary rows use Context instead.
pub fn SortedContext(comptime whole: bool, comptime complete: bool) type {
    return ContextMode(whole, complete, true);
}
fn ContextMode(comptime whole: bool, comptime complete: bool, comptime sorted: bool) type {
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
        // DP may opt in only with a validated model and a real literal prefix
        // from a block of at most 128 KiB. Arbitrary contexts default off.
        choice_pruning: bool = false,

        const Self = @This();
        const Node = state.NodeFor(whole);

        pub inline fn candidate(self: *Self, position: usize, slot: usize, node: Node, distance: usize, maximum: usize) !void {
            if (maximum < self.parameters.hq_options.min_match) return;
            try self.materialize(position, slot, node, distance, maximum);
        }

        fn materialize(self: *Self, position: usize, slot: usize, node: Node, distance: usize, maximum: usize) !void {
            const minimum: usize = self.parameters.hq_options.min_match;
            var choices = try rep.choices(node.literal_len, distance, node.repeats);
            // Amortize preparation on longer ranges; the subtraction is safe
            // after the early return above. Generic contexts keep full prices.
            const use_prepared = sorted and maximum - minimum >= 4;
            // One extra u32 of node headroom also covers the maximum legal
            // block's literal continuation. Retain every synthetic error and
            // finite quota prefix, including admission-counter overflow.
            const can_prune = blk: {
                if (!sorted or !self.choice_pruning or choices.len < 2 or
                    maximum < 16 or self.price_budget.limit != null) break :blk false;
                if (minimum < 3 or maximum > 131074 or node.literal_len > 131071 or
                    node.cost > std.math.maxInt(u64) - std.math.maxInt(u32)) break :blk false;
                const maximum_edges = @as(u64, choices.len) * (@as(u64, maximum) + prices.ml_symbol_count * 2 + 1);
                if (self.price_budget.admitted > std.math.maxInt(u64) - maximum_edges) break :blk false;
                break :blk true;
            };
            if (can_prune) {
                const original_choices = choices.len;
                choice_dominance.compact(&choices, self.parameters.entropy);
                if (choices.len < original_choices) {
                    const skipped = @as(u64, original_choices - choices.len) *
                        enumeration_count.perChoice(complete, self.parameters.strategy, minimum, maximum);
                    try self.price_budget.reserveUnpriced(skipped);
                }
            }
            for (choices.slice()) |*choice| {
                var prepared: prepared_price.ForChoice = .{ .literal_len = node.literal_len, .offset_value = choice.offset_value };
                if (complete) {
                    // Includes every interior length, every exact repeat
                    // selector and every endpoint beyond the bounded horizon.
                    for (minimum..maximum + 1) |length|
                        try self.extend(false, position, slot, &node, length, choice, 0, if (use_prepared) &prepared else null);
                } else {
                    // Preserve the old sampling order, duplicates and ties.
                    try self.extend(false, position, slot, &node, maximum, choice, 0, if (use_prepared) &prepared else null);
                    const exhaustive: usize = if (self.parameters.strategy == .btopt) 16 else 64;
                    var length = minimum;
                    while (length < @min(maximum, exhaustive + 1)) : (length += 1)
                        try self.extend(false, position, slot, &node, length, choice, 0, if (use_prepared) &prepared else null);
                    for (prices.ml_bases, prices.ml_bits, 0..) |base, bits, code| {
                        const lower: usize = base;
                        // Later ML intervals also start beyond the strict bound.
                        if (lower >= maximum) break;
                        // Both endpoints belong to this ML symbol already.
                        const upper = lower + (@as(usize, 1) << @intCast(bits)) - 1;
                        if (lower > exhaustive and lower < maximum)
                            try self.extend(true, position, slot, &node, lower, choice, @intCast(code), if (use_prepared) &prepared else null);
                        if (self.parameters.strategy != .btopt and upper > exhaustive and upper < maximum)
                            try self.extend(true, position, slot, &node, upper, choice, @intCast(code), if (use_prepared) &prepared else null);
                    }
                }
            }
        }

        inline fn extend(self: *Self, comptime known_match: bool, position: usize, slot: usize, node: *const Node, length: usize, choice: *const rep.Choice, match_code: u8, prepared: ?*prepared_price.ForChoice) !void {
            try self.price_budget.admit();
            if (self.parameters.profile) |profile| {
                profile.add("price_evaluations", 1);
                profile.add("optimal_transitions", 1);
                profile.recordMatchLengthConsidered(length);
            }
            const cost = if (prepared) |memo|
                try memo.price(known_match, self.parameters.entropy, length, match_code)
            else if (known_match)
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
            // DP rows have nondecreasing costs. A strictly higher cost cannot
            // improve any duplicate or the last slot; ties keep full ordering.
            // Admission, pricing and checked node construction occur first.
            if (sorted and target <= self.goal and
                next.cost > self.nodes[(target + 1) * self.width - 1].cost) return;
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
    _ = @import("strict_cost_tests.zig");
}
