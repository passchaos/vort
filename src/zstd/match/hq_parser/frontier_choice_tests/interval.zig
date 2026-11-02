//! Frozen pre-preparation interval implementation, with independent row state.
const std = @import("std");
const state = @import("../state.zig");
const prices = @import("../prices.zig");
const rep = @import("../rep.zig");
const PriceBudget = @import("../price_budget.zig").PriceBudget;

pub fn literalLengthPrice(model: *const prices.EntropyModel, length: usize) !u32 {
    if (length > 128 * 1024) return error.InvalidBlockPlan;
    const symbol = try prices.literalSymbol(@min(length, 131071));
    return model.ll_prices[symbol.code] + @as(u32, symbol.extra_bits) * prices.scale;
}

pub fn pricedNode(parameters: state.Parameters, budget: *PriceBudget, node: state.Node, position: usize, length: usize, choice: rep.Choice) !state.Node {
    try budget.admit();
    if (parameters.profile) |profile| {
        profile.add("price_evaluations", 1);
        profile.add("optimal_transitions", 1);
        profile.recordMatchLengthConsidered(length);
    }
    const sequence = try parameters.entropy.sequencePrice(node.literal_len, length, choice.offset_value);
    const old_ll = try literalLengthPrice(parameters.entropy, node.literal_len);
    const closed_cost = std.math.sub(u64, node.cost, old_ll) catch return error.IntegerOverflow;
    const sequence_cost = std.math.add(u64, closed_cost, sequence) catch return error.IntegerOverflow;
    return .{
        .cost = std.math.add(u64, sequence_cost, try literalLengthPrice(parameters.entropy, 0)) catch return error.IntegerOverflow,
        .repeats = choice.repeats,
        .match_len = @intCast(length),
        .distance = choice.distance,
        .offset_value = choice.offset_value,
        .previous_position = @intCast(position),
    };
}

pub const Context = struct {
    nodes: []state.Node,
    goal: usize,
    last: usize,
    initialized_end: usize = 0,
    parameters: state.Parameters,
    price_budget: *PriceBudget,

    pub fn initUntil(self: *Context, target: usize) void {
        if (target <= self.initialized_end) return;
        @memset(self.nodes[self.initialized_end + 1 .. target + 1], .{});
        self.initialized_end = target;
    }
    pub fn edge(self: *Context, position: usize, node: state.Node, length: usize, choice: rep.Choice) !void {
        const next = try pricedNode(self.parameters, self.price_budget, node, position, length, choice);
        const target = position + length;
        std.debug.assert(target <= self.goal);
        self.initUntil(target);
        if (next.cost < self.nodes[target].cost) self.nodes[target] = next;
        self.last = @max(self.last, target);
    }
    pub fn interval(self: *Context, position: usize, node: state.Node, distance: usize, first: usize, last: usize) !void {
        if (last < first) return;
        const choices = try rep.choices(node.literal_len, distance, node.repeats);
        for (choices.slice()) |choice| {
            try self.edge(position, node, last, choice);
            const exhaustive: usize = if (self.parameters.strategy == .btopt) 16 else 64;
            for (first..@max(first, @min(last, exhaustive + 1))) |length| try self.edge(position, node, length, choice);
            for (prices.ml_bases, prices.ml_bits) |base, bits| {
                if (base >= last) break;
                const upper = @as(usize, base) + (@as(usize, 1) << @intCast(bits)) - 1;
                if (base > exhaustive and base >= first) try self.edge(position, node, base, choice);
                if (self.parameters.strategy != .btopt and upper > exhaustive and upper >= first and upper < last)
                    try self.edge(position, node, upper, choice);
            }
        }
    }
};

pub const Edge = struct { length: usize, choice: rep.Choice };
pub const Edges = struct { values: [512]Edge = undefined, len: usize = 0 };

/// Explicit original enumeration is used to check every admitted-edge prefix,
/// including the maximum-first ordering and repeated choices/length calls.
pub fn orderedEdges(parameters: state.Parameters, node: state.Node, distance: usize, first: usize, last: usize) !Edges {
    var output: Edges = .{};
    if (last < first) return output;
    const choices = try rep.choices(node.literal_len, distance, node.repeats);
    for (choices.slice()) |choice| {
        output.values[output.len] = .{ .length = last, .choice = choice };
        output.len += 1;
        const exhaustive: usize = if (parameters.strategy == .btopt) 16 else 64;
        for (first..@max(first, @min(last, exhaustive + 1))) |length| {
            output.values[output.len] = .{ .length = length, .choice = choice };
            output.len += 1;
        }
        for (prices.ml_bases, prices.ml_bits) |base, bits| {
            if (base >= last) break;
            const upper = @as(usize, base) + (@as(usize, 1) << @intCast(bits)) - 1;
            if (base > exhaustive and base >= first) {
                output.values[output.len] = .{ .length = base, .choice = choice };
                output.len += 1;
            }
            if (parameters.strategy != .btopt and upper > exhaustive and upper >= first and upper < last) {
                output.values[output.len] = .{ .length = upper, .choice = choice };
                output.len += 1;
            }
        }
    }
    return output;
}
