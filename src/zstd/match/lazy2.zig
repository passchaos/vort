const std = @import("std");
const source_mod = @import("controlled_source.zig");
const state = @import("hq_parser/state.zig");
const prices = @import("hq_parser/prices.zig");
const rep = @import("hq_parser/rep.zig");
const resources = @import("hq_parser/resources.zig");
const chain = @import("hq_parser/chain.zig");
pub const Parameters = state.Parameters;
pub const Plan = state.Plan;
const Cache = struct { position: usize = std.math.maxInt(usize), len: usize = 0 };
const Selection = struct {
    length: usize = 0,
    distance: usize = 0,
    offset_value: u32 = 0,
    repeats: rep.Repeats = rep.initial_repeats,
    gain: i64 = 0,
};

pub fn requiredWorkingMemory(source: source_mod.Source, parameters: Parameters) !usize {
    return requiredWithMatcher(source, parameters, chain.Matcher);
}
pub fn requiredWithMatcher(source: source_mod.Source, parameters: Parameters, comptime Matcher: type) !usize {
    try resources.validate(source, parameters);
    if (source.block.len < parameters.hq_options.min_match) return 0;
    const capacity = candidateCapacity(source, parameters);
    const candidates = try resources.multiply(try resources.multiply(capacity, 3), @sizeOf(source_mod.Match));
    const own = try resources.add(try resources.resultBytes(source, parameters.hq_options.min_match), candidates);
    return resources.add(own, try Matcher.requiredWorkingMemory(source, parameters.hq_options));
}

pub fn planAlloc(allocator: std.mem.Allocator, source: source_mod.Source, parameters: Parameters) !Plan {
    if (parameters.strategy != .lazy2) return error.InvalidBlockPlan;
    return planWithMatcher(allocator, source, parameters, chain.Matcher);
}

/// Both lazy2 and btlazy2 compare the current match with actual matches one and
/// two bytes later under their complete literal/LL/ML/OF costs. A matcher is
/// monotonic; lookahead frontiers are copied before another find invalidates
/// the borrowed tree result. No legacy search module is changed.
pub fn planWithMatcher(allocator: std.mem.Allocator, source: source_mod.Source, parameters: Parameters, comptime Matcher: type) !Plan {
    const required = try requiredWithMatcher(source, parameters, Matcher);
    defer if (parameters.profile) |profile| profile.recordEffectiveHq(parameters.hq_options);
    if (parameters.profile) |profile| {
        profile.available = true;
        profile.controls_used = true;
        profile.resolved_strategy = parameters.strategy;
        profile.recordEffectiveHq(parameters.hq_options);
    }
    if (required > parameters.hq_options.max_working_memory) return error.WorkingMemoryLimitExceeded;
    var budget = resources.WorkingAllocator.init(allocator, parameters.hq_options.max_working_memory);
    defer if (parameters.profile) |profile| profile.recordPeakWorkingMemory(budget.peak);
    return run(budget.allocator(), &budget, source, parameters, Matcher) catch |err| {
        if (err == error.OutOfMemory and budget.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
        return err;
    };
}
fn run(allocator: std.mem.Allocator, budget: *resources.WorkingAllocator, source: source_mod.Source, parameters: Parameters, comptime Matcher: type) !Plan {
    if (source.block.len != 0) if (parameters.profile) |profile| profile.add("hq_passes", 1);
    var plan = try resources.allocatePlan(allocator, source, parameters.hq_options.min_match, parameters.initial_repeated_offsets);
    errdefer plan.deinit(allocator);
    if (source.block.len < parameters.hq_options.min_match) {
        if (source.block.len == 0) plan.passes = 0;
        try resources.finish(&plan, source, parameters.initial_repeated_offsets, parameters);
        plan.peak_working_memory = budget.peak;
        return plan;
    }
    const capacity = candidateCapacity(source, parameters);
    const candidates = try allocator.alloc(source_mod.Match, capacity * 3);
    defer allocator.free(candidates);
    var caches: [3]Cache = @splat(.{});
    var matcher_options = parameters.hq_options;
    matcher_options.max_working_memory -= budget.live;
    var matcher = try Matcher.init(allocator, source, matcher_options, parameters.profile);
    defer matcher.deinit(allocator);
    var position: usize = 0;
    var anchor: usize = 0;
    var repeats = parameters.initial_repeated_offsets;
    while (source.block.len - position >= parameters.hq_options.min_match) {
        const current = try cached(&matcher, candidates, &caches, capacity, position);
        var best = choose(source, position, position - anchor, repeats, current, parameters);
        var delay: usize = 0;
        for ([_]usize{ 1, 2 }) |lookahead| {
            if (lookahead > source.block.len - position - parameters.hq_options.min_match) break;
            const frontier = try cached(&matcher, candidates, &caches, capacity, position + lookahead);
            const next = choose(source, position + lookahead, position - anchor + lookahead, repeats, frontier, parameters);
            if (next.gain > best.gain) {
                best = next;
                delay = lookahead;
            }
        }
        if (best.length == 0 or best.gain <= 0) {
            position += 1;
            continue;
        }
        if (delay != 0) if (parameters.profile) |profile| profile.add("lazy_deferrals", delay);
        position += delay;
        const end = position + best.length;
        try resources.append(&plan, .{ .literal_len = position - anchor, .match_len = best.length, .distance = best.distance, .match_end = end }, best.offset_value);
        repeats = best.repeats;
        position = end;
        anchor = end;
        try matcher.advanceTo(position);
        caches = @splat(.{});
    }
    try matcher.advanceTo(source.block.len);
    plan.final_repeated_offsets = repeats;
    try resources.finish(&plan, source, parameters.initial_repeated_offsets, parameters);
    plan.peak_working_memory = budget.peak;
    return plan;
}
fn candidateCapacity(source: source_mod.Source, parameters: Parameters) usize {
    return @min(@as(usize, parameters.hq_options.search_depth) + 1, @max(1, source.block.len -| (parameters.hq_options.min_match - 1)));
}
fn cached(matcher: anytype, storage: []source_mod.Match, caches: *[3]Cache, capacity: usize, position: usize) ![]const source_mod.Match {
    const slot = position % 3;
    const cache = &caches[slot];
    const destination = storage[slot * capacity ..][0..capacity];
    if (cache.position != position) {
        try matcher.advanceTo(position);
        const matches = try matcher.find();
        const values = matches.slice();
        if (values.len > destination.len) return error.InvalidBlockPlan;
        for (values, 0..) |match, i| destination[i] = .{ .length = match.length, .distance = match.distance };
        cache.* = .{ .position = position, .len = values.len };
    }
    return destination[0..cache.len];
}
fn choose(source: source_mod.Source, position: usize, literal_len: usize, repeats: rep.Repeats, indexed: []const source_mod.Match, parameters: Parameters) Selection {
    var selected: Selection = .{};
    for (indexed) |match| consider(&selected, source, position, literal_len, repeats, match, parameters);
    for (rep.distances(literal_len, repeats)) |distance| {
        if (parameters.profile) |profile| profile.add("rep_probes", 1);
        const length = resources.matchLength(source, position, distance, source.block.len - position, parameters.profile);
        if (length >= parameters.hq_options.min_match)
            consider(&selected, source, position, literal_len, repeats, .{ .length = length, .distance = distance }, parameters);
    }
    return selected;
}
fn consider(selected: *Selection, source: source_mod.Source, position: usize, literal_len: usize, repeats: rep.Repeats, match: source_mod.Match, parameters: Parameters) void {
    if (match.length < parameters.hq_options.min_match) return;
    const choices = rep.choices(literal_len, match.distance, repeats) catch return;
    var literal_price: i64 = 0;
    for (source.block[position..][0..match.length]) |byte| literal_price += parameters.entropy.literal_prices[byte];
    for (choices.slice()) |choice| {
        if (parameters.profile) |profile| profile.add("price_evaluations", 1);
        const sequence_price = parameters.entropy.sequencePrice(literal_len, match.length, choice.offset_value) catch continue;
        const gain = literal_price - sequence_price;
        if (gain > selected.gain or (gain == selected.gain and gain > 0 and match.length > selected.length))
            selected.* = .{ .length = match.length, .distance = match.distance, .offset_value = choice.offset_value, .repeats = choice.repeats, .gain = gain };
    }
}

test {
    _ = @import("hq_parser/lazy2_tests.zig");
}
