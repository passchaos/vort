const std = @import("std");
const source_mod = @import("../controlled_source.zig");
const state = @import("state.zig");
const rep = @import("rep.zig");
const resources = @import("resources.zig");
const dp = @import("dp.zig");
const edges = @import("search_edges.zig");
const extension = @import("extension.zig");
const frontier_cache = @import("match_frontier_cache.zig");
const rep_length_cache = @import("rep_length_cache.zig");
const row_tags = @import("row_tags.zig");
const tree = @import("../hq_tree.zig");
const PriceBudget = @import("price_budget.zig").PriceBudget;

pub fn Scratch(comptime Matcher: type) type {
    return struct {
        nodes: []state.Node = &.{},
        whole_nodes: []state.WholeNode = &.{},
        literal_prefix: []u64 = &.{},
        tag_rows: []row_tags.Tags = &.{},
        spill: ?*edges.Spill = null,
        matcher: Matcher = .{},

        const Self = @This();

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.matcher.deinit(allocator);
            if (self.spill) |pointer| allocator.destroy(pointer);
            allocator.free(self.tag_rows);
            allocator.free(self.literal_prefix);
            allocator.free(self.whole_nodes);
            allocator.free(self.nodes);
            self.* = .{};
        }

        fn nodeSlice(self: *Self, comptime whole: bool, allocator: std.mem.Allocator, len: usize) ![]state.NodeFor(whole) {
            const storage = if (whole) &self.whole_nodes else &self.nodes;
            try ensureExact(state.NodeFor(whole), storage, allocator, len);
            return storage.*[0..len];
        }

        fn prefixSlice(self: *Self, allocator: std.mem.Allocator, len: usize) ![]u64 {
            try ensureExact(u64, &self.literal_prefix, allocator, len);
            return self.literal_prefix[0..len];
        }

        fn tagSlice(self: *Self, allocator: std.mem.Allocator, len: usize) ![]row_tags.Tags {
            try ensureExact(row_tags.Tags, &self.tag_rows, allocator, len);
            return self.tag_rows[0..len];
        }

        fn spillPointer(self: *Self, allocator: std.mem.Allocator) !*edges.Spill {
            if (self.spill == null) self.spill = try allocator.create(edges.Spill);
            return self.spill.?;
        }
    };
}

pub const FrontierMode = union(enum) {
    search,
    record: *frontier_cache.Cache,
    replay: *const frontier_cache.Cache,
};

fn ensureExact(comptime T: type, storage: *[]T, allocator: std.mem.Allocator, len: usize) !void {
    if (storage.len >= len) return;
    const replacement = try allocator.alloc(T, len);
    allocator.free(storage.*);
    storage.* = replacement;
}

/// Whole mode gives every position in this format block a DP row. Bounded
/// complete length search prices all endpoints but retains only one best
/// cross-horizon continuation. Both modes still have a finite state beam and
/// the matcher's bounded candidate frontier; they are not global optima.
pub fn planReuse(comptime Matcher: type, scratch: *Scratch(Matcher), allocator: std.mem.Allocator, budget: *resources.WorkingAllocator, source: source_mod.Source, parameters: state.Parameters, frontier: FrontierMode) !state.Plan {
    if (parameters.hq_options.parse_mode == .whole_block) {
        return if (parameters.hq_options.match_lengths == .complete)
            planMode(true, true, Matcher, scratch, allocator, budget, source, parameters, frontier)
        else
            planMode(true, false, Matcher, scratch, allocator, budget, source, parameters, frontier);
    }
    return if (parameters.hq_options.match_lengths == .complete)
        planMode(false, true, Matcher, scratch, allocator, budget, source, parameters, frontier)
    else
        planMode(false, false, Matcher, scratch, allocator, budget, source, parameters, frontier);
}

fn planMode(comptime whole: bool, comptime complete: bool, comptime Matcher: type, scratch: *Scratch(Matcher), allocator: std.mem.Allocator, budget: *resources.WorkingAllocator, source: source_mod.Source, parameters: state.Parameters, frontier: FrontierMode) !state.Plan {
    const Node = state.NodeFor(whole);
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
    const width = dp.beamWidth(parameters.strategy);
    const layout = try resources.nodeLayout(source.block.len, width, whole);
    const nodes = try scratch.nodeSlice(whole, allocator, layout.node_count);
    const literal_prefix: ?[]u64 = if (!whole and complete) try scratch.prefixSlice(allocator, source.block.len + 1) else null;
    if (literal_prefix) |prefix| {
        prefix[0] = 0;
        for (source.block, 0..) |byte, position|
            prefix[position + 1] = std.math.add(u64, prefix[position], parameters.entropy.literal_prices[byte]) catch return error.IntegerOverflow;
    }
    const tag_rows = try scratch.tagSlice(allocator, layout.row_count);
    const spill: ?*edges.Spill = if (!whole and complete) try scratch.spillPointer(allocator) else null;
    const replay = switch (frontier) {
        .replay => true,
        else => false,
    };
    if (!replay) {
        var matcher_options = parameters.hq_options;
        matcher_options.max_working_memory -= budget.live - scratch.matcher.workingBytes();
        try scratch.matcher.prepare(allocator, source, matcher_options, parameters.profile);
    }
    const matcher = &scratch.matcher;
    if (parameters.profile) |profile| profile.recordHqSearch(parameters.hq_options, if (whole) source.block.len else @min(state.horizon, source.block.len));
    var base: usize = 0;
    var pending_literals: usize = 0;
    var repeats = parameters.initial_repeated_offsets;
    var repeat_lengths: rep_length_cache.Cache = .{};
    while (base < source.block.len) {
        const goal = if (whole) source.block.len else @min(state.horizon, source.block.len - base);
        @memset(nodes[0 .. (goal + 1) * width], .{});
        nodes[0] = .{ .cost = 0, .repeats = repeats, .literal_len = @intCast(pending_literals) };
        @memset(tag_rows[0 .. goal + 1], @splat(row_tags.key(@as(Node, .{}))));
        tag_rows[0] = row_tags.init(nodes[0..width]);
        if (spill) |pointer| pointer.* = .{};
        var context: edges.Context(whole, complete) = .{ .nodes = nodes, .width = width, .base = base, .goal = goal, .parameters = parameters, .price_budget = &price_budget, .literal_prefix = literal_prefix, .spill = spill, .tag_rows = tag_rows };
        for (0..goal) |position| {
            repeat_lengths.beginPosition();
            const global = base + position;
            const matches: tree.Matches = switch (frontier) {
                .replay => |cache| blk: {
                    if (parameters.profile) |profile|
                        profile.add("match_frontier_replay_positions", 1);
                    break :blk cache.at(global);
                },
                .search, .record => blk: {
                    try matcher.advanceTo(global);
                    break :blk try matcher.find();
                },
            };
            switch (frontier) {
                .record => |cache| cache.record(global, matches),
                else => {},
            }
            if (parameters.profile) |profile| profile.recordParsePositions(position + 1);
            const row = nodes[position * width ..][0..width];
            for (row, 0..) |node, slot| {
                if (node.cost == std.math.maxInt(u64)) break;
                _ = row_tags.insert(nodes[(position + 1) * width ..][0..width], &tag_rows[position + 1], .{
                    .cost = std.math.add(u64, node.cost, parameters.entropy.literal_prices[source.block[global]]) catch return error.IntegerOverflow,
                    .repeats = node.repeats,
                    .literal_len = node.literal_len + 1,
                    .previous_position = @intCast(position),
                    .previous_slot = @intCast(slot),
                });
                const maximum = if (complete) source.block.len - global else goal - position;
                for (matches.slice()) |candidate| {
                    // Matcher retained frontier entries have full actual
                    // lengths: only its final nice-stop entry needs extension,
                    // which the matcher has already performed once.
                    try context.candidate(position, slot, node, candidate.distance, @min(candidate.length, maximum));
                }
                const repeated = rep.distances(node.literal_len, node.repeats);
                for (repeated, 0..) |distance, repeat_index| {
                    if (distance == 0 or distance > source.window_len or distance > source.prefixLen() + global) continue;
                    var redundant = false;
                    for (repeated[0..repeat_index]) |earlier| redundant = redundant or earlier == distance;
                    for (matches.slice()) |candidate|
                        redundant = redundant or (candidate.distance == distance and candidate.length >= maximum);
                    if (redundant) continue;
                    const cached = repeat_lengths.lookup(@intCast(distance));
                    const length: usize = if (cached.length) |length| hit: {
                        if (parameters.profile) |profile| profile.add("rep_length_cache_hits", 1);
                        break :hit length;
                    } else miss: {
                        if (parameters.profile) |profile| profile.add("rep_probes", 1);
                        const length = resources.matchLength(source, global, distance, maximum, parameters.profile);
                        repeat_lengths.store(cached, @intCast(distance), length);
                        break :miss length;
                    };
                    try context.candidate(position, slot, node, distance, length);
                }
            }
        }
        var final = nodes[goal * width];
        var use_spill = false;
        if (spill) |pointer| {
            const prefix = literal_prefix.?;
            const continuation = std.math.add(u64, final.cost, prefix[source.block.len] - prefix[base + goal]) catch return error.IntegerOverflow;
            use_spill = pointer.continuation_cost < continuation;
            if (use_spill) final = pointer.node;
        }
        if (final.cost == std.math.maxInt(u64)) return error.InvalidBlockPlan;
        const records_start = result.records.len;
        var position: usize = if (use_spill) final.previous_position else goal;
        var slot: usize = if (use_spill) final.previous_slot else 0;
        if (!whole and complete) {
            if (use_spill) try appendNode(&result, nodes, width, base, spill.?.end_position, final);
        }
        while (position > 0) {
            const node = nodes[position * width + slot];
            if (node.match_len != 0) try appendNode(&result, nodes, width, base, position, node);
            position = node.previous_position;
            slot = node.previous_slot;
        }
        std.mem.reverse(state.Record, result.records[records_start..]);
        std.mem.reverse(u32, result.offset_values[records_start..]);
        pending_literals = final.literal_len;
        repeats = final.repeats;
        base += if (!whole and complete) (if (use_spill) spill.?.end_position else goal) else goal;
        // Whole parses have no artificial horizon to cross. The default
        // bounded extension retains its original samples and tie order.
        if (!whole and pending_literals == 0 and result.records.len != records_start) {
            const last = &result.records[result.records.len - 1];
            if (last.match_end == base) {
                const start = base - last.match_len;
                const full = resources.matchLength(source, start, last.distance, source.block.len - start, parameters.profile);
                const length = try extension.choose(complete, source, last.*, result.offset_values[result.offset_values.len - 1], full, parameters, &price_budget);
                if (length > last.match_len) {
                    base += length - last.match_len;
                    last.match_len = length;
                    last.match_end = base;
                }
            }
        }
        if (!replay) try matcher.advanceTo(base);
    }
    result.final_repeated_offsets = repeats;
    try resources.finish(&result, source, parameters.initial_repeated_offsets, parameters);
    result.peak_working_memory = budget.peak;
    return result;
}

fn appendNode(result: *state.Plan, nodes: anytype, width: usize, base: usize, position: usize, node: @TypeOf(nodes[0])) !void {
    const previous = nodes[@as(usize, node.previous_position) * width + node.previous_slot];
    try resources.append(result, .{
        .literal_len = previous.literal_len,
        .match_len = node.match_len,
        .distance = node.distance,
        .match_end = base + position,
    }, node.offset_value);
}
