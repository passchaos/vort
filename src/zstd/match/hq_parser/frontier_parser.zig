//! Single-path local parsing. Scores include the unfinished literal-length field.
const std = @import("std");
const source_mod = @import("../controlled_source.zig");
const state = @import("state.zig");
const rep = @import("rep.zig");
const prices = @import("prices.zig");
const resources = @import("resources.zig");
const PriceBudget = @import("price_budget.zig").PriceBudget;

pub const use_frontier = true;
pub const adaptive_stop = true;
const Node = state.Node;
const Match = struct { length: usize, distance: usize };
const RepeatMatches = struct {
    items: [3]Match = undefined,
    len: usize = 0,
    fn slice(self: *const RepeatMatches) []const Match {
        return self.items[0..self.len];
    }
};
const Tail = struct { node: Node, end: usize };

pub fn ownWorkingBytes(source: source_mod.Source, parameters: state.Parameters) !usize {
    try validate(source, parameters);
    if (source.block.len < parameters.hq_options.min_match) return 0;
    const layout = try resources.nodeLayout(source.block.len, 1, false);
    return resources.add(try resources.resultBytes(source, parameters.hq_options.min_match), layout.bytes);
}

fn validate(source: source_mod.Source, parameters: state.Parameters) !void {
    try resources.validate(source, parameters);
    if (parameters.hq_options.effectiveParserEngine() != .local_optimal or parameters.hq_options.parse_mode != .bounded or parameters.hq_options.match_lengths != .sampled or
        (parameters.strategy != .btopt and parameters.strategy != .btultra and parameters.strategy != .btultra2)) return error.InvalidBlockPlan;
}

/// The virtual LL at an all-literal block end is never used for a real sequence.
fn literalLengthPrice(model: *const prices.EntropyModel, length: usize) !u32 {
    if (length > 128 * 1024) return error.InvalidBlockPlan;
    const symbol = try prices.literalSymbol(@min(length, 131071));
    return model.ll_prices[symbol.code] + @as(u32, symbol.extra_bits) * prices.scale;
}

fn literalNode(model: *const prices.EntropyModel, node: Node, position: usize, byte: u8) !Node {
    const length = std.math.add(u32, node.literal_len, 1) catch return error.IntegerOverflow;
    const old_ll = try literalLengthPrice(model, node.literal_len);
    const new_ll = try literalLengthPrice(model, length);
    const closed_cost = std.math.sub(u64, node.cost, old_ll) catch return error.IntegerOverflow;
    const with_literal = std.math.add(u64, closed_cost, model.literal_prices[byte]) catch return error.IntegerOverflow;
    return .{ .cost = std.math.add(u64, with_literal, new_ll) catch return error.IntegerOverflow, .literal_len = length, .repeats = node.repeats, .previous_position = @intCast(position) };
}

fn pricedNode(parameters: state.Parameters, budget: *PriceBudget, node: Node, position: usize, length: usize, choice: rep.Choice) !Node {
    try budget.admit();
    if (parameters.profile) |profile| {
        profile.add("price_evaluations", 1);
        profile.add("optimal_transitions", 1);
        profile.recordMatchLengthConsidered(length);
    }
    // sequencePrice gets the real LL without the virtual trailing-literal clamp.
    const sequence = try parameters.entropy.sequencePrice(node.literal_len, length, choice.offset_value);
    const old_ll = try literalLengthPrice(parameters.entropy, node.literal_len);
    const closed_cost = std.math.sub(u64, node.cost, old_ll) catch return error.IntegerOverflow;
    const sequence_cost = std.math.add(u64, closed_cost, sequence) catch return error.IntegerOverflow;
    return .{ .cost = std.math.add(u64, sequence_cost, try literalLengthPrice(parameters.entropy, 0)) catch return error.IntegerOverflow, .repeats = choice.repeats, .match_len = @intCast(length), .distance = choice.distance, .offset_value = choice.offset_value, .previous_position = @intCast(position) };
}

fn probeRepeats(source: source_mod.Source, parameters: state.Parameters, global: usize, node: Node) RepeatMatches {
    var result: RepeatMatches = .{};
    for ([_]u32{ 1, 2, 3 }) |offset| {
        const choice = rep.resolve(node.literal_len, offset, node.repeats) catch continue;
        if (choice.distance > source.window_len or choice.distance > source.prefixLen() + global) continue;
        var duplicate = false;
        for (result.slice()) |old| if (old.distance == choice.distance) {
            duplicate = true;
        };
        if (duplicate) continue;
        if (parameters.profile) |profile| profile.add("rep_probes", 1);
        const length = resources.matchLength(source, global, choice.distance, source.block.len - global, parameters.profile);
        if (length < parameters.hq_options.min_match) continue;
        result.items[result.len] = .{ .length = length, .distance = choice.distance };
        result.len += 1;
    }
    return result;
}

fn longest(repeated: *const RepeatMatches, ordinary: anytype) Match {
    var best: Match = .{ .length = 0, .distance = 0 };
    for (repeated.slice()) |match| if (match.length > best.length) {
        best = match;
    };
    for (ordinary) |match| if (match.length > best.length) {
        best = .{ .length = match.length, .distance = match.distance };
    };
    return best;
}

fn stops(parameters: state.Parameters, position: usize, maximum: usize, goal: usize) bool {
    return adaptive_stop and maximum >= parameters.hq_options.min_match and
        (maximum > parameters.hq_options.nice_len or position + maximum >= goal);
}

/// A tail is priced once. Choose its cheapest legal encoding from the OF terms.
fn tailChoice(parameters: state.Parameters, node: Node, distance: usize) !rep.Choice {
    const choices = try rep.choices(node.literal_len, distance, node.repeats);
    var best = choices.items[0];
    var best_cost: u32 = std.math.maxInt(u32);
    for (choices.slice()) |choice| {
        const symbol = try prices.offsetSymbol(choice.offset_value);
        const penalty: u32 = if (parameters.entropy.penalize_long_offsets and symbol.code >= 20) (@as(u32, symbol.code) - 19) * 2 * prices.scale else 0;
        const cost = parameters.entropy.of_prices[symbol.code] + @as(u32, symbol.extra_bits) * prices.scale + penalty;
        if (cost < best_cost) {
            best = choice;
            best_cost = cost;
        }
    }
    return best;
}

const Context = struct {
    nodes: []Node,
    goal: usize,
    last: usize,
    initialized_end: usize = 0,
    parameters: state.Parameters,
    price_budget: *PriceBudget,

    fn initUntil(self: *Context, target: usize) void {
        if (target <= self.initialized_end) return;
        @memset(self.nodes[self.initialized_end + 1 .. target + 1], .{});
        self.initialized_end = target;
    }

    fn literal(self: *Context, position: usize, node: Node, byte: u8) !void {
        const next = try literalNode(self.parameters.entropy, node, position, byte);
        self.initUntil(position + 1);
        if (next.cost <= self.nodes[position + 1].cost) self.nodes[position + 1] = next;
    }

    fn edge(self: *Context, position: usize, node: Node, length: usize, choice: rep.Choice) !void {
        const next = try pricedNode(self.parameters, self.price_budget, node, position, length, choice);
        const target = position + length;
        std.debug.assert(target <= self.goal);
        self.initUntil(target);
        if (next.cost < self.nodes[target].cost) self.nodes[target] = next;
        self.last = @max(self.last, target);
    }

    fn interval(self: *Context, position: usize, node: Node, distance: usize, first: usize, last: usize) !void {
        if (last < first) return;
        const choices = try rep.choices(node.literal_len, distance, node.repeats);
        for (choices.slice()) |choice| {
            // Retain sampled length selection inside this match's new interval.
            try self.edge(position, node, last, choice);
            const exhaustive: usize = if (self.parameters.strategy == .btopt) 16 else 64;
            for (first..@max(first, @min(last, exhaustive + 1))) |length|
                try self.edge(position, node, length, choice);
            for (prices.ml_bases, prices.ml_bits) |base, bits| {
                if (base >= last) break;
                const upper = @as(usize, base) + (@as(usize, 1) << @intCast(bits)) - 1;
                if (base > exhaustive and base >= first) try self.edge(position, node, base, choice);
                if (self.parameters.strategy != .btopt and upper > exhaustive and upper >= first and upper < last)
                    try self.edge(position, node, upper, choice);
            }
        }
    }

    fn matches(self: *Context, position: usize, node: Node, repeated: *const RepeatMatches, ordinary: anytype) !void {
        const minimum: usize = self.parameters.hq_options.min_match;
        // Rep histories compete independently for their shorter lengths.
        for (repeated.slice()) |match| try self.interval(position, node, match.distance, minimum, @min(match.length, self.goal - position));
        var previous = minimum - 1;
        for (ordinary) |match| {
            const last = @min(match.length, self.goal - position);
            const first = if (use_frontier) @max(minimum, previous + 1) else minimum;
            try self.interval(position, node, match.distance, first, last);
            previous = @max(previous, last);
        }
    }
};

fn appendMatch(result: *state.Plan, base: usize, end: usize, node: Node, literal_len: usize) !void {
    try resources.append(result, .{ .literal_len = literal_len, .match_len = node.match_len, .distance = node.distance, .match_end = base + end }, node.offset_value);
}

fn appendPrefix(result: *state.Plan, nodes: []const Node, base: usize, end: usize) !void {
    const first = result.records.len;
    var position = end;
    while (position != 0) {
        const node = nodes[position];
        const previous: usize = node.previous_position;
        if (previous >= position) return error.InvalidBlockPlan;
        if (node.match_len != 0) try appendMatch(result, base, position, node, nodes[previous].literal_len);
        position = previous;
    }
    std.mem.reverse(state.Record, result.records[first..]);
    std.mem.reverse(u32, result.offset_values[first..]);
}

pub fn plan(allocator: std.mem.Allocator, budget: *resources.WorkingAllocator, source: source_mod.Source, parameters: state.Parameters, comptime Matcher: type) !state.Plan {
    try validate(source, parameters);
    var price_budget = PriceBudget.init(parameters.hq_options.max_price_evaluations, parameters.profile);
    defer price_budget.finish();
    if (source.block.len != 0) if (parameters.profile) |profile| profile.add("hq_passes", 1);
    var result = try resources.allocatePlan(allocator, source, parameters.hq_options.min_match, parameters.initial_repeated_offsets);
    errdefer result.deinit(allocator);
    if (source.block.len < parameters.hq_options.min_match) {
        if (source.block.len == 0) result.passes = 0;
        try resources.finish(&result, source, parameters.initial_repeated_offsets, parameters);
        result.peak_working_memory = budget.peak;
        return result;
    }
    const count = @min(source.block.len, state.horizon) + 1;
    const nodes = try allocator.alloc(Node, count);
    defer allocator.free(nodes);
    if (budget.live > parameters.hq_options.max_working_memory) return error.WorkingMemoryLimitExceeded;
    var matcher_options = parameters.hq_options;
    matcher_options.max_working_memory -= budget.live;
    var matcher = try Matcher.init(allocator, source, matcher_options, parameters.profile);
    defer matcher.deinit(allocator);
    if (parameters.profile) |profile| profile.recordHqSearch(parameters.hq_options, @min(source.block.len, state.horizon));
    var base: usize = 0;
    var pending: u32 = 0;
    var repeats = parameters.initial_repeated_offsets;
    while (base < source.block.len) {
        const goal = @min(source.block.len - base, state.horizon);
        try matcher.advanceTo(base);
        var root: Node = .{ .cost = 0, .literal_len = pending, .repeats = repeats };
        const initial_reps = probeRepeats(source, parameters, base, root);
        const rep_best = longest(&initial_reps, &.{});
        if (parameters.profile) |profile| profile.recordParsePositions(1);
        if (stops(parameters, 0, rep_best.length, goal)) {
            if (parameters.profile) |profile| profile.add("positions_tested", 1);
            root.cost = try literalLengthPrice(parameters.entropy, pending);
            const tail = try pricedNode(parameters, &price_budget, root, 0, rep_best.length, try tailChoice(parameters, root, rep_best.distance));
            try appendMatch(&result, base, rep_best.length, tail, pending);
            base += rep_best.length;
            pending = 0;
            repeats = tail.repeats;
            continue;
        }
        const first_matches = try matcher.find();
        const best = longest(&initial_reps, first_matches.slice());
        if (best.length < parameters.hq_options.min_match) {
            base += 1;
            pending += 1;
            continue;
        }
        root.cost = try literalLengthPrice(parameters.entropy, pending);
        if (stops(parameters, 0, best.length, goal)) {
            const tail = try pricedNode(parameters, &price_budget, root, 0, best.length, try tailChoice(parameters, root, best.distance));
            try appendMatch(&result, base, best.length, tail, pending);
            base += best.length;
            pending = 0;
            repeats = tail.repeats;
            continue;
        }
        if (!adaptive_stop) @memset(nodes[0 .. goal + 1], .{});
        nodes[0] = root;
        var context: Context = .{ .nodes = nodes, .goal = goal, .last = if (adaptive_stop) 0 else goal, .initialized_end = if (adaptive_stop) 0 else goal, .parameters = parameters, .price_budget = &price_budget };
        try context.literal(0, root, source.block[base]);
        try context.matches(0, root, &initial_reps, first_matches.slice());
        var tail: ?Tail = null;
        var position: usize = 1;
        while (position < context.last) : (position += 1) {
            const node = nodes[position];
            if (node.cost == std.math.maxInt(u64)) continue;
            try context.literal(position, node, source.block[base + position]);
            try matcher.advanceTo(base + position);
            const repeated = probeRepeats(source, parameters, base + position, node);
            if (parameters.profile) |profile| profile.recordParsePositions(position + 1);
            const repeated_best = longest(&repeated, &.{});
            if (stops(parameters, position, repeated_best.length, goal)) {
                if (parameters.profile) |profile| profile.add("positions_tested", 1);
                tail = .{ .node = try pricedNode(parameters, &price_budget, node, position, repeated_best.length, try tailChoice(parameters, node, repeated_best.distance)), .end = position + repeated_best.length };
                break;
            }
            const ordinary = try matcher.find();
            const next_best = longest(&repeated, ordinary.slice());
            if (stops(parameters, position, next_best.length, goal)) {
                tail = .{ .node = try pricedNode(parameters, &price_budget, node, position, next_best.length, try tailChoice(parameters, node, next_best.distance)), .end = position + next_best.length };
                break;
            }
            try context.matches(position, node, &repeated, ordinary.slice());
        }
        if (tail) |selected| {
            try appendPrefix(&result, nodes, base, selected.node.previous_position);
            try appendMatch(&result, base, selected.end, selected.node, nodes[selected.node.previous_position].literal_len);
            base += selected.end;
            pending = 0;
            repeats = selected.node.repeats;
        } else {
            const final = nodes[context.last];
            if (final.cost == std.math.maxInt(u64) or context.last == 0) return error.InvalidBlockPlan;
            try appendPrefix(&result, nodes, base, context.last);
            base += context.last;
            pending = final.literal_len;
            repeats = final.repeats;
        }
    }
    try matcher.advanceTo(base);
    result.final_repeated_offsets = repeats;
    try resources.finish(&result, source, parameters.initial_repeated_offsets, parameters);
    result.peak_working_memory = budget.peak;
    return result;
}

test "Zstd HQ frontier LL decreasing bucket and virtual tail preserve scoring invariant" {
    var model: prices.EntropyModel = .{};
    model.ll_prices = @splat(0);
    model.ll_prices[15] = 4000;
    model.literal_prices[0] = 100;
    const original: Node = .{ .cost = 4000, .literal_len = 15 };
    const next = try literalNode(&model, original, 0, 0);
    try std.testing.expectEqual(@as(u32, 16), next.literal_len);
    try std.testing.expectEqual(@as(u64, 356), next.cost);
    try std.testing.expectEqual(try literalLengthPrice(&model, 131071), try literalLengthPrice(&model, 131072));
    try std.testing.expectError(error.InvalidBlockPlan, model.sequencePrice(131072, 3, 4));
}

test "Zstd HQ frontier local reused poisoned rows initialize only reachable targets" {
    const entropy: prices.EntropyModel = .{};
    const parameters: state.Parameters = .{ .strategy = .btultra, .entropy = &entropy };
    const poison: Node = .{ .cost = 0, .literal_len = 991, .repeats = .{ 99, 101, 103 }, .previous_position = 31 };
    var nodes: [33]Node = @splat(poison);
    var budget = PriceBudget.init(null, null);
    for ([_]u64{ 0, 50000 }) |prefix_cost| {
        const root: Node = .{ .cost = prefix_cost + try literalLengthPrice(&entropy, 0), .repeats = rep.initial_repeats };
        nodes[0] = root;
        var context: Context = .{ .nodes = &nodes, .goal = 32, .last = 0, .parameters = parameters, .price_budget = &budget };
        const choice = try rep.resolve(0, 10, root.repeats);
        // A maximum-first edge must clear its whole newly reachable interval.
        try context.edge(0, root, 8, choice);
        try std.testing.expectEqual(@as(usize, 8), context.initialized_end);
        try std.testing.expectEqual(@as(usize, 8), context.last);
        for (nodes[1..8]) |node| try std.testing.expectEqual(std.math.maxInt(u64), node.cost);
        try std.testing.expectEqual(prefix_cost + try entropy.sequencePrice(0, 8, 10) + try literalLengthPrice(&entropy, 0), nodes[8].cost);
        try context.edge(0, root, 3, choice);
        try std.testing.expectEqual(prefix_cost + try entropy.sequencePrice(0, 3, 10) + try literalLengthPrice(&entropy, 0), nodes[3].cost);
        try context.literal(0, root, 'a');
        try std.testing.expectEqual(prefix_cost + entropy.literal_prices['a'] + try literalLengthPrice(&entropy, 1), nodes[1].cost);
        // Short edges and literal competition must retain the earlier maximum.
        try std.testing.expectEqual(prefix_cost + try entropy.sequencePrice(0, 8, 10) + try literalLengthPrice(&entropy, 0), nodes[8].cost);
        try std.testing.expect(context.initialized_end >= context.last);
        for (nodes[9..]) |node| try std.testing.expectEqualDeep(poison, node);
    }
}

test {
    _ = @import("frontier_parser_tests.zig");
}
