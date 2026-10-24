const std = @import("std");
const tree = @import("../hq_tree.zig");
const types = @import("../hq_types.zig");
const options = @import("../hq_options.zig");
const command_plan = @import("../command_plan.zig");
const dictionary = @import("../hq_dictionary.zig");
const length = @import("../../length.zig");
const state = @import("state.zig");
const prices = @import("prices.zig");
const rep = @import("rep.zig");
const resources = @import("resources.zig");
const extension = @import("extension.zig");
const command_storage = @import("command_storage.zig");
const PriceBudget = @import("price_budget.zig").PriceBudget;

pub fn run(allocator: std.mem.Allocator, budget: *state.Budget, source: types.Source, parameters: state.Parameters, model: *const prices.Model, provider: ?*const dictionary.Provider) !state.Plan {
    var price_budget: PriceBudget = .{ .limit = parameters.resolved.max_price_evaluations };
    defer if (parameters.profile) |profile| profile.recordMaxPlanPrice(price_budget.admitted);
    var builder = command_storage.Builder.init(allocator);
    defer builder.deinit();
    var result = try resources.allocatePlan(allocator, source, parameters, provider != null);
    errdefer result.deinit(allocator);
    if (source.input.len == 0) {
        try resources.finish(&result, source, parameters, model, provider);
        result.peak_working_memory = budget.peak;
        return result;
    }
    if (parameters.profile) |profile| profile.add("passes", 1);
    const literal_prefix = try allocator.alloc(u64, source.input.len + 1);
    defer allocator.free(literal_prefix);
    literal_prefix[0] = 0;
    for (source.input, 0..) |_, position|
        literal_prefix[position + 1] = std.math.add(u64, literal_prefix[position], model.literalPrice(source, position, parameters.previous)) catch return error.IntegerOverflow;
    const width: usize = parameters.resolved.beam_width;
    const window = state.horizonFor(source.input.len, parameters.resolved.parse_mode);
    const node_count = try resources.multiply(try resources.add(window, 1), width);
    const nodes = try allocator.alloc(state.Node, node_count);
    defer allocator.free(nodes);
    if (parameters.profile) |profile| {
        profile.recordParseMode(parameters.resolved.parse_mode, window);
        profile.recordCopyLengthPolicy(parameters.resolved.copy_lengths, window);
    }
    const spill = try allocator.create(state.Spill);
    defer allocator.destroy(spill);
    const memos = try allocator.alloc(state.MatchMemo, width * 16);
    defer allocator.free(memos);
    var owned_matcher: ?tree.Matcher = null;
    defer if (owned_matcher) |*matcher| matcher.deinit(allocator);
    const matcher = parameters.matcher orelse blk: {
        var config = parameters.resolved;
        config.max_working_memory = budget.limit - @min(budget.live, budget.limit);
        owned_matcher = try tree.Matcher.init(allocator, source, config, parameters.profile);
        break :blk &owned_matcher.?;
    };
    if (matcher.position() != 0) return error.InvalidBlockPlan;
    var dictionary_candidates: std.ArrayList(dictionary.Candidate) = .empty;
    defer dictionary_candidates.deinit(allocator);
    var base: usize = 0;
    var pending: usize = 0;
    var recent = parameters.initial_recent_distances orelse source.recent;
    while (base < source.input.len) {
        const goal = @min(window, source.input.len - base);
        @memset(nodes[0 .. (goal + 1) * width], .{});
        spill.* = .{};
        nodes[0] = .{ .cost = 0, .recent = recent, .pending_insert = pending };
        var edge_context: EdgeContext = .{ .nodes = nodes, .width = width, .base = base, .goal = goal, .source = source, .parameters = parameters, .model = model, .literal_prefix = literal_prefix, .spill = spill, .price_budget = &price_budget };
        for (0..goal) |position| {
            const global = base + position;
            try matcher.advanceTo(global);
            const matches = try matcher.getMatches();
            dictionary_candidates.clearRetainingCapacity();
            if (provider) |active| try active.appendCandidates(source.input, global, model.context(source, global, parameters.previous), source.input.len - global, &dictionary_candidates);
            const row = nodes[position * width ..][0..width];
            var memo_count: usize = 0;
            for (row, 0..) |node, slot| {
                if (node.cost == std.math.maxInt(u64)) break;
                if (parameters.profile) |profile| profile.add("states", 1);
                state.insert(nodes[(position + 1) * width ..][0..width], .{
                    .cost = try plus(node.cost, literal_prefix[global + 1] - literal_prefix[global]),
                    .recent = node.recent,
                    .pending_insert = node.pending_insert + 1,
                    .previous_position = @intCast(position),
                    .previous_slot = @intCast(slot),
                });
                for (matches.slice()) |candidate| {
                    if (candidate.distance == 0 or candidate.distance > source.history.len + global or candidate.distance > source.window_len) return error.InvalidBlockPlan;
                    try ordinaryEdges(&edge_context, position, slot, node, candidate.length, candidate.distance);
                }
                // Match equal physical aliases once, but evaluate every exact
                // short selector through rep.choices, preserving cache effects.
                var probed: [16]usize = undefined;
                var probed_count: usize = 0;
                for (0..16) |code| {
                    const backward = rep.resolve(code, node.recent) catch continue;
                    var duplicate = false;
                    for (probed[0..probed_count]) |distance| duplicate = duplicate or distance == backward;
                    if (duplicate) continue;
                    probed[probed_count] = backward;
                    probed_count += 1;
                    for (matches.slice()) |candidate| duplicate = duplicate or (candidate.distance == backward and candidate.length >= source.input.len - global);
                    if (duplicate) continue;
                    var cached_length: ?usize = null;
                    for (memos[0..memo_count]) |memo| if (memo.distance == backward) {
                        cached_length = memo.length;
                        break;
                    };
                    const matched = cached_length orelse blk: {
                        if (parameters.profile) |profile| profile.add("match_probes", 1);
                        const matched = resources.matchLength(source, global, backward, source.input.len - global, parameters.profile);
                        memos[memo_count] = .{ .distance = backward, .length = matched };
                        memo_count += 1;
                        break :blk matched;
                    };
                    try ordinaryEdges(&edge_context, position, slot, node, matched, backward);
                }
                for (dictionary_candidates.items) |candidate| {
                    if (candidate.output_len == 0 or candidate.output_len > source.input.len - global) return error.InvalidBlockPlan;
                    const backward = try provider.?.wireDistance(candidate, source, global);
                    const choices = try rep.choicesWithFormat(node.recent, backward, parameters.resolved.distance_parameters, parameters.resolved.format, candidate.source == .static);
                    if (candidate.source == .static) {
                        // An atomic transform may cross this artificial window.
                        // Its exact command and predecessor live in spill.
                        for (choices.slice()) |choice|
                            try emitEdge(&edge_context, position, slot, node, candidate.copy_len, candidate.output_len, candidate.source, candidate.address, choice);
                    } else if (candidate.source == .compound) {
                        try lengthEdges(&edge_context, position, slot, node, candidate.output_len, candidate.source, candidate.address, &choices);
                    } else return error.InvalidBlockPlan;
                }
            }
        }
        var final_slot: usize = 0;
        var best: u64 = std.math.maxInt(u64);
        for (nodes[goal * width ..][0..width], 0..) |node, slot| {
            if (node.cost == std.math.maxInt(u64)) break;
            const tail = source.input.len - base - goal;
            var cost = try plus(node.cost, literal_prefix[source.input.len] - literal_prefix[base + goal]);
            if (node.pending_insert + tail != 0) cost = try plus(cost, (try model.terminal(node.pending_insert + tail)).cost);
            if (cost < best) {
                best = cost;
                final_slot = slot;
            }
        }
        const use_spill = parameters.resolved.parse_mode == .bounded and spill.continuation_cost < best;
        const final = if (use_spill) spill.node else nodes[goal * width + final_slot];
        if (final.cost == std.math.maxInt(u64)) return error.InvalidBlockPlan;
        const commands_start = result.commands.len;
        var position: usize = if (use_spill) final.previous_position else goal;
        var slot: usize = if (use_spill) final.previous_slot else final_slot;
        if (use_spill) try appendNode(&result, &builder, nodes, width, base, final);
        while (position != 0) {
            const node = nodes[position * width + slot];
            if (node.output_len != 0) {
                try appendNode(&result, &builder, nodes, width, base, node);
            }
            position = node.previous_position;
            slot = node.previous_slot;
        }
        builder.reverseSuffix(commands_start);
        result.commands = builder.items();
        recent = final.recent;
        pending = final.pending_insert;
        base += if (use_spill) spill.end_position else goal;
        if (parameters.resolved.parse_mode == .bounded and pending == 0 and result.commands.len != commands_start) {
            const last = &result.commands[result.commands.len - 1];
            const copy_start = last.insert_start + last.insert_len;
            var full = last.outputLen();
            if (last.isLz77()) {
                full = resources.matchLength(source, copy_start, last.distance, source.input.len - copy_start, parameters.profile);
            } else if (last.isCompound()) {
                dictionary_candidates.clearRetainingCapacity();
                try provider.?.appendCandidates(source.input, copy_start, model.context(source, copy_start, parameters.previous), source.input.len - copy_start, &dictionary_candidates);
                for (dictionary_candidates.items) |candidate| {
                    if (candidate.source == .compound and candidate.address == last.dictionary_address) full = @max(full, candidate.output_len);
                }
            }
            const chosen = try extension.choose(last.*, full, source, model, literal_prefix);
            if (chosen.length > last.outputLen()) {
                base += chosen.length - last.outputLen();
                last.copy_len = chosen.length;
                last.hq_encoding = chosen.encoding;
            }
        }
        try matcher.advanceTo(base);
    }
    if (pending != 0) {
        const terminal = try model.terminal(pending);
        try resources.append(&result, &builder, .{ .insert_start = source.input.len - pending, .insert_len = pending, .copy_len = terminal.copy_len, .hq_encoding = terminal.encoding });
    }
    result.final_recent_distances = recent;
    try resources.finish(&result, source, parameters, model, provider);
    result.command_storage = try builder.finishOwned();
    result.commands = result.command_storage;
    result.peak_working_memory = budget.peak;
    return result;
}

const EdgeContext = struct {
    nodes: []state.Node,
    width: usize,
    base: usize,
    goal: usize,
    source: types.Source,
    parameters: state.Parameters,
    model: *const prices.Model,
    literal_prefix: []const u64,
    spill: *state.Spill,
    price_budget: *PriceBudget,
};
fn appendNode(result: *state.Plan, builder: *command_storage.Builder, nodes: []const state.Node, width: usize, base: usize, node: state.Node) !void {
    const previous = nodes[@as(usize, node.previous_position) * width + node.previous_slot];
    const copy_start = base + node.previous_position;
    try resources.append(result, builder, .{
        .insert_start = copy_start - previous.pending_insert,
        .insert_len = previous.pending_insert,
        .copy_len = node.copy_len,
        .has_copy = true,
        .distance = if (node.source == .lz77) node.physical_distance else 0,
        .source = node.source,
        .dictionary_output_len = if (node.source == .static) node.output_len else 0,
        .dictionary_address = node.dictionary_address,
        .hq_encoding = node.encoding,
    });
}
fn ordinaryEdges(context: *EdgeContext, position: usize, slot: usize, node: state.Node, maximum: usize, backward: usize) !void {
    if (maximum < 2) return;
    const choices = try rep.choicesWithFormat(node.recent, backward, context.parameters.resolved.distance_parameters, context.parameters.resolved.format, false);
    try lengthEdges(context, position, slot, node, maximum, .lz77, 0, &choices);
}
fn lengthEdges(context: *EdgeContext, position: usize, slot: usize, node: state.Node, maximum: usize, kind: command_plan.Source, address: usize, choices: *const rep.Choices) !void {
    if (maximum < 2) return;
    for (choices.slice()) |choice| {
        if (context.parameters.resolved.copy_lengths == .complete) {
            var copy_len: usize = 2;
            while (copy_len <= maximum) : (copy_len += 1)
                try emitEdge(context, position, slot, node, copy_len, copy_len, kind, address, choice);
            continue;
        }
        try emitEdge(context, position, slot, node, maximum, maximum, kind, address, choice);
        const exhaustive: usize = if (context.parameters.resolved.quality == 10) 32 else 64;
        var copy_len: usize = 2;
        while (copy_len < @min(maximum, exhaustive + 1)) : (copy_len += 1)
            try emitEdge(context, position, slot, node, copy_len, copy_len, kind, address, choice);
        for (0..24) |code| {
            const spec = length.copySpec(@intCast(code));
            const upper = spec.base + (@as(usize, 1) << spec.extra_bits) - 1;
            if (spec.base > exhaustive and spec.base < maximum)
                try emitEdge(context, position, slot, node, spec.base, spec.base, kind, address, choice);
            if (context.parameters.resolved.quality == 11 and upper > exhaustive and upper < maximum)
                try emitEdge(context, position, slot, node, upper, upper, kind, address, choice);
        }
    }
}
fn emitEdge(context: *EdgeContext, position: usize, slot: usize, node: state.Node, copy_len: usize, output_len: usize, kind: command_plan.Source, address: usize, distance_choice: rep.Choice) !void {
    const target = std.math.add(usize, position, output_len) catch return error.IntegerOverflow;
    if (output_len == 0 or target > context.source.input.len - context.base) return error.InvalidBlockPlan;
    const encodings = try context.model.commandEncodings(node.pending_insert, copy_len, distance_choice.code);
    for (encodings.slice()) |encoding| {
        try context.price_budget.admit();
        if (context.parameters.profile) |profile| {
            profile.add("transitions", 1);
            profile.add("price_evaluations", 1);
            profile.recordCopyLengthConsidered(copy_len);
        }
        const price = try context.model.encodingPrice(encoding, true);
        const candidate: state.Node = .{
            .cost = try plus(node.cost, price),
            .recent = distance_choice.cache,
            .previous_position = @intCast(position),
            .previous_slot = @intCast(slot),
            .copy_len = copy_len,
            .output_len = output_len,
            .physical_distance = distance_choice.distance,
            .dictionary_address = address,
            .source = kind,
            .encoding = encoding,
        };
        if (target <= context.goal) {
            state.insert(context.nodes[target * context.width ..][0..context.width], candidate);
        } else {
            const end = context.base + target;
            var continuation = try plus(candidate.cost, context.literal_prefix[context.source.input.len] - context.literal_prefix[end]);
            if (end != context.source.input.len) continuation = try plus(continuation, (try context.model.terminal(context.source.input.len - end)).cost);
            if (continuation < context.spill.continuation_cost or
                (continuation == context.spill.continuation_cost and (target < context.spill.end_position or (target == context.spill.end_position and state.less(candidate, context.spill.node)))))
                context.spill.* = .{ .node = candidate, .end_position = target, .continuation_cost = continuation };
        }
    }
}
fn plus(a: u64, b: u64) !u64 {
    return std.math.add(u64, a, b) catch error.IntegerOverflow;
}
