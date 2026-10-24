const std = @import("std");
const source_mod = @import("../controlled_source.zig");
const state = @import("state.zig");
const rep = @import("rep.zig");
const prices = @import("prices.zig");
const resources = @import("resources.zig");

pub fn beamWidth(strategy: @import("../../encode/controls.zig").Strategy) usize {
    return if (strategy == .btopt) 8 else 16;
}
pub fn ownWorkingBytes(source: source_mod.Source, parameters: state.Parameters) !usize {
    if (source.block.len < parameters.hq_options.min_match) return 0;
    const rows = try resources.add(@min(state.horizon, source.block.len), 1);
    const nodes = try resources.multiply(rows, beamWidth(parameters.strategy));
    return resources.add(try resources.resultBytes(source, parameters.hq_options.min_match), try resources.multiply(nodes, @sizeOf(state.Node)));
}

/// Fixed-size stable windows preserve full repeat histories and pending literal
/// runs across the whole 128 KiB block. btopt uses eight states and exhaustive
/// short lengths through 16; ultra uses sixteen states, short lengths through
/// 64 and both sides of each longer ML symbol boundary.
pub fn plan(allocator: std.mem.Allocator, budget: *resources.WorkingAllocator, source: source_mod.Source, parameters: state.Parameters, comptime Matcher: type) !state.Plan {
    if (source.block.len != 0) if (parameters.profile) |profile| profile.add("hq_passes", 1);
    var result = try resources.allocatePlan(allocator, source, parameters.hq_options.min_match, parameters.initial_repeated_offsets);
    errdefer result.deinit(allocator);
    if (source.block.len < parameters.hq_options.min_match) {
        if (source.block.len == 0) result.passes = 0;
        try resources.finish(&result, source, parameters.initial_repeated_offsets, parameters);
        result.peak_working_memory = budget.peak;
        return result;
    }
    const width = beamWidth(parameters.strategy);
    const row_count = @min(state.horizon, source.block.len) + 1;
    const nodes = try allocator.alloc(state.Node, row_count * width);
    defer allocator.free(nodes);
    var matcher_options = parameters.hq_options;
    matcher_options.max_working_memory -= budget.live;
    var matcher = try Matcher.init(allocator, source, matcher_options, parameters.profile);
    defer matcher.deinit(allocator);
    var base: usize = 0;
    var pending_literals: usize = 0;
    var repeats = parameters.initial_repeated_offsets;
    while (base < source.block.len) {
        const goal = @min(state.horizon, source.block.len - base);
        @memset(nodes[0 .. (goal + 1) * width], .{});
        nodes[0] = .{ .cost = 0, .repeats = repeats, .literal_len = @intCast(pending_literals) };
        for (0..goal) |position| {
            try matcher.advanceTo(base + position);
            const matches = try matcher.find();
            const row = nodes[position * width ..][0..width];
            for (row, 0..) |node, slot| {
                if (node.cost == std.math.maxInt(u64)) break;
                _ = state.insert(nodes[(position + 1) * width ..][0..width], .{
                    .cost = std.math.add(u64, node.cost, parameters.entropy.literal_prices[source.block[base + position]]) catch return error.IntegerOverflow,
                    .repeats = node.repeats,
                    .literal_len = node.literal_len + 1,
                    .previous_position = @intCast(position),
                    .previous_slot = @intCast(slot),
                });
                for (matches.slice()) |candidate|
                    try candidateEdges(nodes, width, position, slot, node, candidate.distance, @min(candidate.length, goal - position), parameters);
                const repeated = rep.distances(node.literal_len, node.repeats);
                for (repeated, 0..) |distance, repeat_index| {
                    if (distance == 0 or distance > source.window_len or distance > source.prefixLen() + base + position) continue;
                    var redundant = false;
                    for (repeated[0..repeat_index]) |earlier| redundant = redundant or earlier == distance;
                    for (matches.slice()) |candidate|
                        redundant = redundant or (candidate.distance == distance and candidate.length >= goal - position);
                    if (redundant) continue;
                    if (parameters.profile) |profile| profile.add("rep_probes", 1);
                    const length = resources.matchLength(source, base + position, distance, goal - position, parameters.profile);
                    try candidateEdges(nodes, width, position, slot, node, distance, length, parameters);
                }
            }
        }
        const final = nodes[goal * width];
        if (final.cost == std.math.maxInt(u64)) return error.InvalidBlockPlan;
        const records_start = result.records.len;
        var position: usize = goal;
        var slot: usize = 0;
        while (position > 0) {
            const node = nodes[position * width + slot];
            if (node.match_len != 0) {
                const previous = nodes[@as(usize, node.previous_position) * width + node.previous_slot];
                try resources.append(&result, .{
                    .literal_len = previous.literal_len,
                    .match_len = node.match_len,
                    .distance = node.distance,
                    .match_end = base + position,
                }, node.offset_value);
            }
            position = node.previous_position;
            slot = node.previous_slot;
        }
        std.mem.reverse(state.Record, result.records[records_start..]);
        std.mem.reverse(u32, result.offset_values[records_start..]);
        pending_literals = final.literal_len;
        repeats = final.repeats;
        base += goal;
        // Preserve a valid continuation cost bound when crossing a window.
        // ML symbol jumps can cost more than literal bytes, so a proven longer
        // match still needs pricing under the same LL and exact offset value.
        if (pending_literals == 0 and result.records.len != records_start) {
            const last = &result.records[result.records.len - 1];
            if (last.match_end == base) {
                const start = base - last.match_len;
                const full = resources.matchLength(source, start, last.distance, source.block.len - start, parameters.profile);
                const length = try pricedExtension(source, last.*, result.offset_values[result.offset_values.len - 1], full, parameters);
                if (length > last.match_len) {
                    base += length - last.match_len;
                    last.match_len = length;
                    last.match_end = base;
                }
            }
        }
        try matcher.advanceTo(base);
    }
    result.final_repeated_offsets = repeats;
    try resources.finish(&result, source, parameters.initial_repeated_offsets, parameters);
    result.peak_working_memory = budget.peak;
    return result;
}

fn pricedExtension(source: source_mod.Source, record: state.Record, offset_value: u32, maximum: usize, parameters: state.Parameters) !usize {
    if (maximum <= record.match_len) return record.match_len;
    const start = record.match_end - record.match_len;
    const extension = source.block[record.match_end .. start + maximum];
    var literal_cost: u64 = 0;
    for (extension) |byte| literal_cost = std.math.add(u64, literal_cost, parameters.entropy.literal_prices[byte]) catch return error.IntegerOverflow;
    if (parameters.profile) |profile| profile.add("price_evaluations", 1);
    const original = try parameters.entropy.sequencePrice(record.literal_len, record.match_len, offset_value);
    var best_cost = std.math.add(u64, original, literal_cost) catch return error.IntegerOverflow;
    var best_length = record.match_len;
    var priced_through = record.match_len;
    var replaced_literal_cost: u64 = 0;
    // Within one ML symbol range the sequence cost is constant and literal
    // costs are nonnegative. Its longest proven endpoint dominates shorter
    // extensions. Compare all crossed ranges, retaining the original on ties.
    for (prices.ml_bases, prices.ml_bits) |base, bits| {
        if (base > maximum) break;
        const length = @min(maximum, @as(usize, base) + (@as(usize, 1) << @intCast(bits)) - 1);
        if (length <= priced_through) continue;
        for (source.block[start + priced_through .. start + length]) |byte|
            replaced_literal_cost = std.math.add(u64, replaced_literal_cost, parameters.entropy.literal_prices[byte]) catch return error.IntegerOverflow;
        priced_through = length;
        if (parameters.profile) |profile| profile.add("price_evaluations", 1);
        const sequence_cost = try parameters.entropy.sequencePrice(record.literal_len, length, offset_value);
        const cost = std.math.add(u64, sequence_cost, literal_cost - replaced_literal_cost) catch return error.IntegerOverflow;
        if (cost < best_cost) {
            best_cost = cost;
            best_length = length;
        }
    }
    return best_length;
}

fn candidateEdges(nodes: []state.Node, width: usize, position: usize, slot: usize, node: state.Node, distance: usize, maximum: usize, parameters: state.Parameters) !void {
    const minimum: usize = parameters.hq_options.min_match;
    if (maximum < minimum) return;
    const choices = try rep.choices(node.literal_len, distance, node.repeats);
    for (choices.slice()) |choice| {
        try extend(nodes, width, position, slot, node, maximum, choice, parameters);
        const exhaustive: usize = if (parameters.strategy == .btopt) 16 else 64;
        var length = minimum;
        while (length < @min(maximum, exhaustive + 1)) : (length += 1)
            try extend(nodes, width, position, slot, node, length, choice, parameters);
        for (prices.ml_bases, prices.ml_bits) |base, bits| {
            const lower: usize = base;
            const upper = lower + (@as(usize, 1) << @intCast(bits)) - 1;
            if (lower > exhaustive and lower < maximum)
                try extend(nodes, width, position, slot, node, lower, choice, parameters);
            if (parameters.strategy != .btopt and upper > exhaustive and upper < maximum)
                try extend(nodes, width, position, slot, node, upper, choice, parameters);
        }
    }
}
fn extend(nodes: []state.Node, width: usize, position: usize, slot: usize, node: state.Node, length: usize, choice: rep.Choice, parameters: state.Parameters) !void {
    if (parameters.profile) |profile| {
        profile.add("price_evaluations", 1);
        profile.add("optimal_transitions", 1);
    }
    const cost = try parameters.entropy.sequencePrice(node.literal_len, length, choice.offset_value);
    _ = state.insert(nodes[(position + length) * width ..][0..width], .{
        .cost = std.math.add(u64, node.cost, cost) catch return error.IntegerOverflow,
        .repeats = choice.repeats,
        .previous_position = @intCast(position),
        .previous_slot = @intCast(slot),
        .match_len = @intCast(length),
        .distance = choice.distance,
        .offset_value = choice.offset_value,
    });
}
