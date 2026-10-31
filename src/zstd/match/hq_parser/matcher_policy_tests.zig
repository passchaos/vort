//! Public matcher routing is observed through real allocation requests and
//! actual plans. Expected routes below are explicit boundary fixtures, not a
//! second implementation of the producer's source-size predicate.
const std = @import("std");
const hq = @import("../hq_parser.zig");
const frontier = @import("frontier_parser.zig");
const resources = @import("resources.zig");
const tree = @import("../hq_tree.zig");
const adaptive = @import("../adaptive_tree.zig");
const controls = @import("../../encode/controls.zig");
const a = std.testing.allocator;

const Route = enum { adaptive, full };
const Case = struct { block_len: usize, dictionary_len: usize = 0, history_len: usize = 0, window_len: usize = 131072, route: Route };

const Meter = struct {
    live: usize = 0,
    peak: usize = 0,
    allocations: usize = 0,
    frees: usize = 0,
    requests: [32]usize = @splat(0),

    fn allocator(self: *Meter) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn changed(self: *Meter, old: usize, new: usize) void {
        std.debug.assert(old <= self.live);
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *Meter = @ptrCast(@alignCast(raw));
        const memory = a.rawAlloc(len, alignment, address) orelse return null;
        std.debug.assert(self.allocations < self.requests.len);
        self.requests[self.allocations] = len;
        self.allocations += 1;
        self.changed(0, len);
        return memory;
    }
    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) bool {
        const self: *Meter = @ptrCast(@alignCast(raw));
        if (!a.rawResize(memory, alignment, len, address)) return false;
        self.changed(memory.len, len);
        return true;
    }
    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) ?[*]u8 {
        const self: *Meter = @ptrCast(@alignCast(raw));
        const result = a.rawRemap(memory, alignment, len, address) orelse return null;
        self.changed(memory.len, len);
        return result;
    }
    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *Meter = @ptrCast(@alignCast(raw));
        a.rawFree(memory, alignment, address);
        self.changed(memory.len, 0);
        self.frees += 1;
    }
    fn countRequest(self: *const Meter, bytes: usize) usize {
        var count: usize = 0;
        for (self.requests[0..self.allocations]) |request| count += @intFromBool(request == bytes);
        return count;
    }
};

fn fill(bytes: []u8, seed: u64) void {
    var random = seed;
    for (bytes) |*byte| {
        random = random *% 6364136223846793005 +% 1442695040888963407;
        byte.* = @truncate(random >> 32);
    }
}

fn samePlan(expected: hq.Plan, actual: hq.Plan) !void {
    try std.testing.expectEqualDeep(expected.records, actual.records);
    try std.testing.expectEqualSlices(u32, expected.offset_values, actual.offset_values);
    try std.testing.expectEqualDeep(expected.final_repeated_offsets, actual.final_repeated_offsets);
    try std.testing.expectEqualDeep(expected.statistics, actual.statistics);
    try std.testing.expectEqual(expected.estimated_cost, actual.estimated_cost);
    try std.testing.expectEqual(expected.peak_working_memory, actual.peak_working_memory);
    try std.testing.expectEqual(expected.passes, actual.passes);
    try std.testing.expectEqual(expected.used_refinement, actual.used_refinement);
    try std.testing.expectEqual(expected.first_pass_cost, actual.first_pass_cost);
    try std.testing.expectEqual(expected.refined_first_pass_cost, actual.refined_first_pass_cost);
}

/// Invoke the selected concrete matcher independently of the public route.
/// This only supplies a route-specific boundary oracle; shared matcher kernel
/// equivalence has its separate existing independent full implementation tests.
fn direct(comptime Matcher: type, allocator: std.mem.Allocator, source: hq.Source, parameters: hq.Parameters) !hq.Plan {
    var budget = resources.WorkingAllocator.init(allocator, parameters.hq_options.max_working_memory);
    defer if (parameters.profile) |profile| profile.recordPeakWorkingMemory(budget.peak);
    const effective = try parameters.entropy.forStrategy(parameters.strategy);
    var pass = parameters;
    pass.entropy = &effective;
    if (parameters.profile) |profile| {
        profile.available = true;
        profile.controls_used = true;
        profile.resolved_strategy = parameters.strategy;
        profile.recordEffectiveHq(parameters.hq_options);
    }
    defer if (parameters.profile) |profile| profile.recordEffectiveHq(parameters.hq_options);
    const cold = parameters.strategy == .btultra2 and source.prefixLen() == 0 and !effective.initialized;
    if (!cold) return frontier.plan(budget.allocator(), &budget, source, pass, Matcher);
    pass.strategy = .btultra;
    var first = try frontier.plan(budget.allocator(), &budget, source, pass, Matcher);
    errdefer first.deinit(budget.allocator());
    const first_cost = first.estimated_cost;
    const refined = effective.refined(&first.statistics);
    var measure = parameters;
    measure.entropy = &refined;
    measure.profile = null;
    try resources.finish(&first, source, parameters.initial_repeated_offsets, measure);
    const refined_first_cost = first.estimated_cost;
    if (parameters.profile) |profile| profile.add("refinement_passes", 1);
    pass.entropy = &refined;
    const second = try frontier.plan(budget.allocator(), &budget, source, pass, Matcher);
    var result: hq.Plan = undefined;
    if (second.estimated_cost <= refined_first_cost) {
        first.deinit(budget.allocator());
        result = second;
    } else {
        second.deinit(budget.allocator());
        result = first;
    }
    result.passes = 2;
    result.used_refinement = true;
    result.first_pass_cost = first_cost;
    result.refined_first_pass_cost = refined_first_cost;
    result.peak_working_memory = budget.peak;
    if (parameters.profile) |profile| profile.recordPeakWorkingMemory(budget.peak);
    return result;
}

fn replay(source: hq.Source, result: hq.Plan, initial: [3]usize) !void {
    const decoded = try a.alloc(u8, source.block.len);
    defer a.free(decoded);
    var position: usize = 0;
    var repeats = initial;
    for (result.records, result.offset_values) |record, offset| {
        @memcpy(decoded[position..][0..record.literal_len], source.block[position..][0..record.literal_len]);
        position += record.literal_len;
        const choice = try hq.rep.resolve(record.literal_len, offset, repeats);
        try std.testing.expectEqual(record.distance, choice.distance);
        try std.testing.expectEqual(@as(?usize, offset), record.offset_value);
        repeats = choice.repeats;
        for (0..record.match_len) |_| {
            const at = source.prefixLen() + position - record.distance;
            decoded[position] = if (at < source.prefixLen()) source.byteAt(at) else decoded[at - source.prefixLen()];
            position += 1;
        }
        try std.testing.expectEqual(record.match_end, position);
    }
    @memcpy(decoded[position..], source.block[position..]);
    try std.testing.expectEqualSlices(u8, source.block, decoded);
    try std.testing.expectEqualDeep(result.final_repeated_offsets, repeats);
}

fn boundary(comptime Matcher: type, case: Case, cold: bool) !void {
    const prefix_len = case.dictionary_len + case.history_len;
    const bytes = try a.alloc(u8, prefix_len + case.block_len);
    defer a.free(bytes);
    fill(bytes, 0x73ab291c);
    const block = bytes[prefix_len..];
    // Genuine reachable matches admit sequence prices even at min_match=7.
    @memcpy(block[block.len - 96 ..], block[block.len - 256 ..][0..96]);
    if (prefix_len >= 32) @memcpy(block[0..32], bytes[prefix_len - 32 ..][0..32]);
    const immutable = try a.dupe(u8, bytes);
    defer a.free(immutable);
    const source = hq.Source.init(bytes[0..case.dictionary_len], bytes[case.dictionary_len..prefix_len], block, case.window_len);
    const model: hq.EntropyModel = .{ .initialized = !cold };
    const model_before = model;
    var actual_profile: controls.Profile = .{};
    var oracle_profile: controls.Profile = .{};
    var parameters: hq.Parameters = .{
        .strategy = if (cold) .btultra2 else .btultra,
        .entropy = &model,
        .profile = &actual_profile,
        .hq_options = .{ .min_match = 7, .nice_len = 32, .search_depth = 4 },
    };
    var meter: Meter = .{};
    defer {
        std.testing.expectEqual(@as(usize, 0), meter.live) catch @panic("public matcher policy plan leaked owned heap");
        std.testing.expectEqual(meter.allocations, meter.frees) catch @panic("public matcher policy allocation/free count mismatch");
    }
    const actual = try hq.planAlloc(meter.allocator(), source, parameters);
    defer actual.deinit(meter.allocator());
    var oracle_parameters = parameters;
    oracle_parameters.profile = &oracle_profile;
    const expected = try direct(Matcher, a, source, oracle_parameters);
    defer expected.deinit(a);
    try samePlan(expected, actual);
    try std.testing.expectEqualDeep(oracle_profile, actual_profile);
    try replay(source, actual, parameters.initial_repeated_offsets);
    const passes: usize = if (cold and prefix_len == 0) 2 else 1;
    const result_bytes = try resources.resultBytes(source, parameters.hq_options.min_match);
    const expected_required = try resources.add(try resources.add(try frontier.ownWorkingBytes(source, parameters), try Matcher.requiredWorkingMemory(source, parameters.hq_options)), if (passes == 2) result_bytes else 0);
    const required = try hq.requiredWorkingMemory(source, parameters);
    try std.testing.expectEqual(expected_required, required);
    try std.testing.expectEqual(required, actual.peak_working_memory);
    try std.testing.expectEqual(required, meter.peak);
    try std.testing.expectEqual(result_bytes, meter.live);
    // Observe actual head allocations, not just the required-memory query.
    const head_bytes: usize = if (case.route == .adaptive) 32768 * @sizeOf(u32) else 65536 * @sizeOf(u32);
    try std.testing.expectEqual(passes * 2, meter.countRequest(head_bytes));
    try std.testing.expectEqual(@as(usize, 0), meter.countRequest(if (case.route == .adaptive) 65536 * @sizeOf(u32) else 32768 * @sizeOf(u32)));
    try std.testing.expectEqual(controls.HqParserEngine.local_optimal, actual_profile.effective_hq_parser_engine.?);
    try std.testing.expectEqual(controls.HqParseMode.bounded, actual_profile.effective_hq_parse_mode.?);
    try std.testing.expectEqual(controls.HqMatchLengthPolicy.sampled, actual_profile.effective_hq_match_lengths.?);
    try std.testing.expectEqual(@as(u64, 0), actual_profile.match_frontier_replay_positions);
    try std.testing.expectEqual(@as(u64, 0), actual_profile.baseline_searches);
    try std.testing.expectEqual(@as(u64, 0), actual_profile.guarded_frames);
    try std.testing.expectEqual(@as(u64, case.dictionary_len * passes), actual_profile.dictionary_seed_positions);
    try std.testing.expectEqual(@as(u64, case.history_len * passes), actual_profile.history_seed_positions);
    const cap = actual_profile.max_plan_price_evaluations;
    try std.testing.expect(cap > 0);
    parameters.hq_options.max_price_evaluations = cap;
    parameters.hq_options.max_working_memory = required;
    actual_profile.reset();
    var exact_meter: Meter = .{};
    defer {
        std.testing.expectEqual(@as(usize, 0), exact_meter.live) catch @panic("finite matcher policy plan leaked owned heap");
        std.testing.expectEqual(exact_meter.allocations, exact_meter.frees) catch @panic("finite matcher policy allocation/free count mismatch");
    }
    const exact = try hq.planAlloc(exact_meter.allocator(), source, parameters);
    defer exact.deinit(exact_meter.allocator());
    try samePlan(actual, exact);
    try std.testing.expectEqual(required, exact_meter.peak);
    try std.testing.expectEqual(cap, actual_profile.max_plan_price_evaluations);
    try std.testing.expectEqual(controls.HqParserEngine.local_optimal, actual_profile.effective_hq_parser_engine.?);
    try std.testing.expectEqual(@as(?u64, cap), actual_profile.effective_hq_max_price_evaluations);
    try std.testing.expectEqual(@as(u64, passes), actual_profile.hq_passes);
    try std.testing.expectEqual(@as(u64, 0), actual_profile.match_frontier_replay_positions);
    for ([_]u64{ 0, cap - 1 }) |limit| {
        var refused: Meter = .{};
        parameters.hq_options.max_price_evaluations = limit;
        actual_profile.reset();
        try std.testing.expectError(error.SearchLimitExceeded, hq.planAlloc(refused.allocator(), source, parameters));
        try std.testing.expectEqual(@as(usize, 0), refused.live);
        try std.testing.expectEqual(refused.allocations, refused.frees);
        try std.testing.expect(actual_profile.max_plan_price_evaluations <= limit);
        try std.testing.expectEqual(@as(u64, 1), actual_profile.price_limit_refusals);
        try std.testing.expectEqual(@as(u64, 0), actual_profile.match_frontier_replay_positions);
    }
    parameters.hq_options.max_price_evaluations = null;
    parameters.hq_options.max_working_memory = required - 1;
    var below: Meter = .{};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, hq.planAlloc(below.allocator(), source, parameters));
    try std.testing.expectEqual(@as(usize, 0), below.allocations);
    try std.testing.expectEqual(@as(usize, 0), below.live);
    try std.testing.expectEqualDeep(model_before, model);
    try std.testing.expectEqualSlices(u8, immutable, bytes);
}

test "Zstd HQ public matcher policy actual plans heap caps and 32768 intersection boundaries" {
    const cases = [_]Case{
        .{ .block_len = 32768, .route = .adaptive },
        .{ .block_len = 32769, .route = .full },
        .{ .dictionary_len = 37, .history_len = 27, .block_len = 32704, .route = .adaptive },
        .{ .dictionary_len = 37, .history_len = 27, .block_len = 32705, .route = .full },
        .{ .block_len = 65536, .window_len = 32767, .route = .adaptive },
        .{ .block_len = 65536, .window_len = 32768, .route = .full },
        .{ .dictionary_len = 37, .history_len = 27, .block_len = 65536, .window_len = 32767, .route = .adaptive },
        .{ .dictionary_len = 37, .history_len = 27, .block_len = 65536, .window_len = 32768, .route = .full },
    };
    for (cases) |case| switch (case.route) {
        .adaptive => try boundary(adaptive.Matcher, case, false),
        .full => try boundary(tree.Matcher, case, false),
    };
}

test "Zstd HQ public matcher policy cold passes repeat actual route and independent caps" {
    try boundary(adaptive.Matcher, .{ .block_len = 32768, .route = .adaptive }, true);
    try boundary(tree.Matcher, .{ .block_len = 32769, .route = .full }, true);
}

test "Zstd HQ prefix policy preserves every indexed position across a long block skip" {
    const bytes = try a.alloc(u8, 32768);
    defer a.free(bytes);
    fill(bytes, 0x32def991);
    const source = hq.Source.init(bytes[0..37], bytes[37..64], bytes[64..], 131072);
    var ap: controls.Profile = .{};
    var fp: controls.Profile = .{};
    const options: controls.HqOptions = .{ .min_match = 7, .search_depth = 4, .nice_len = 32 };
    var am = try adaptive.Matcher.init(a, source, options, &ap);
    defer am.deinit(a);
    var fm = try tree.Matcher.init(a, source, options, &fp);
    defer fm.deinit(a);
    try std.testing.expectEqual(@as(usize, 64), am.indexed_positions);
    try std.testing.expectEqual(fm.indexed_positions, am.indexed_positions);
    try am.skip(1024);
    try fm.skip(1024);
    try std.testing.expectEqual(@as(usize, 1088), am.indexed_positions);
    try std.testing.expectEqual(fm.indexed_positions, am.indexed_positions);
    try std.testing.expectEqual(@as(u64, 37), ap.dictionary_seed_positions);
    try std.testing.expectEqual(@as(u64, 27), ap.history_seed_positions);
    try std.testing.expectEqual(@as(u64, 1024), ap.skipped_positions);
    for (0..1088) |position| {
        try std.testing.expectEqual(@as(u32, @intCast(position)), am.nodes[position].position);
        try std.testing.expectEqual(fm.nodes[position].position, am.nodes[position].position);
    }
    try std.testing.expectEqual(@as(u64, 37), fp.dictionary_seed_positions);
    try std.testing.expectEqual(@as(u64, 27), fp.history_seed_positions);
    try std.testing.expectEqual(@as(u64, 1024), fp.skipped_positions);
}
