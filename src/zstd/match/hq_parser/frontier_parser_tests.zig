const std = @import("std");
const parser = @import("frontier_parser.zig");
const state = @import("state.zig");
const resources = @import("resources.zig");
const prices = @import("prices.zig");
const rep = @import("rep.zig");
const tree = @import("../hq_tree.zig");
const a = std.testing.allocator;

fn run(source: tree.Source, parameters: state.Parameters) !state.Plan {
    var budget = resources.WorkingAllocator.init(a, parameters.hq_options.max_working_memory);
    const result = try parser.plan(budget.allocator(), &budget, source, parameters, tree.Matcher);
    try std.testing.expectEqual(result.record_storage.len * @sizeOf(state.Record) + result.offset_storage.len * @sizeOf(u32), budget.live);
    return result;
}

fn checkBytes(source: tree.Source, result: state.Plan) !void {
    const output = try a.alloc(u8, source.block.len);
    defer a.free(output);
    var position: usize = 0;
    var repeats = rep.initial_repeats;
    for (result.records, result.offset_values) |record, offset| {
        @memcpy(output[position..][0..record.literal_len], source.block[position..][0..record.literal_len]);
        position += record.literal_len;
        const choice = try rep.resolve(record.literal_len, offset, repeats);
        try std.testing.expectEqual(choice.distance, record.distance);
        repeats = choice.repeats;
        try std.testing.expect(record.distance <= source.prefixLen() + position);
        for (0..record.match_len) |_| {
            const absolute = source.prefixLen() + position - record.distance;
            output[position] = if (absolute < source.prefixLen()) source.byteAt(absolute) else output[absolute - source.prefixLen()];
            position += 1;
        }
        try std.testing.expectEqual(position, record.match_end);
    }
    @memcpy(output[position..], source.block[position..]);
    try std.testing.expectEqualSlices(u8, source.block, output);
    try std.testing.expectEqualDeep(repeats, result.final_repeated_offsets);
    try std.testing.expectEqual(@as(u32, @intCast(source.block.len)), result.statistics.literal_count + @as(u32, @intCast(matchedBytes(result))));
}

fn matchedBytes(result: state.Plan) usize {
    var count: usize = 0;
    for (result.records) |record| count += record.match_len;
    return count;
}

fn samePlan(left: state.Plan, right: state.Plan) !void {
    try std.testing.expectEqualDeep(left.records, right.records);
    try std.testing.expectEqualSlices(u32, left.offset_values, right.offset_values);
    try std.testing.expectEqualDeep(left.final_repeated_offsets, right.final_repeated_offsets);
    try std.testing.expectEqualDeep(left.statistics, right.statistics);
    try std.testing.expectEqual(left.estimated_cost, right.estimated_cost);
}

test "Zstd HQ frontier deterministic plans reconstruct tiny random repetitive mixed and prefixes" {
    var random: [257]u8 = undefined;
    var seed: u32 = 0x77abc129;
    for (&random) |*byte| {
        seed = seed *% 1664525 +% 1013904223;
        byte.* = @truncate(seed >> 17);
    }
    const inputs = [_][]const u8{ "", "a", "ab", "abc", &random, "abcd" ** 32, ("structured:abcdef\n" ** 8) ++ ("ZZ0123" ** 8) ++ "end" };
    for (inputs) |input| for ([_][]const u8{ "", "abcdabcdabcdef" }) |prefix| for ([_]u8{ 3, 4 }) |minimum| {
        const source = tree.Source.init(prefix, "", input, 4096);
        const parameters: state.Parameters = .{ .strategy = .btultra, .hq_options = .{ .min_match = minimum, .nice_len = 32, .search_depth = 16 } };
        const first = try run(source, parameters);
        defer first.deinit(a);
        const second = try run(source, parameters);
        defer second.deinit(a);
        try samePlan(first, second);
        try checkBytes(source, first);
    };
}

test "Zstd HQ frontier measured finite allowance N and N minus one share algorithm" {
    const source = tree.Source.init("", "", "abcd" ** 64, 1024);
    var profile: @import("../../encode/controls.zig").Profile = .{};
    var parameters: state.Parameters = .{ .strategy = .btopt, .profile = &profile, .hq_options = .{ .nice_len = 32 } };
    const original = try run(source, parameters);
    defer original.deinit(a);
    const allowance = profile.max_plan_price_evaluations;
    try std.testing.expect(allowance > 0);
    parameters.hq_options.max_price_evaluations = allowance;
    profile.reset();
    const exact = try run(source, parameters);
    defer exact.deinit(a);
    try samePlan(original, exact);
    try std.testing.expectEqual(allowance, profile.max_plan_price_evaluations);
    parameters.hq_options.max_price_evaluations = allowance - 1;
    profile.reset();
    try std.testing.expectError(error.SearchLimitExceeded, run(source, parameters));
    try std.testing.expectEqual(allowance - 1, profile.max_plan_price_evaluations);
    try std.testing.expectEqual(@as(u64, 1), profile.price_limit_refusals);
    const unmatched = try run(tree.Source.init("", "", "abcdefghijkl", 1024), .{ .strategy = .btopt, .hq_options = .{ .max_price_evaluations = 0 } });
    defer unmatched.deinit(a);
    try std.testing.expectEqual(@as(usize, 0), unmatched.records.len);
}

test "Zstd HQ frontier nice strict boundary long tail and exact owned memory" {
    for ([_]u32{ 3, 4, 7, 32, 128, 512, 4096 }) |nice| for ([_]u8{ 3, 4 }) |minimum| {
        if (nice < minimum) continue;
        const source = tree.Source.init("abcdabcd", "", "abcd" ** 80, 8192);
        const parameters: state.Parameters = .{ .strategy = .btultra, .hq_options = .{ .min_match = minimum, .nice_len = nice, .search_depth = 16 } };
        const required = try resources.add(try parser.ownWorkingBytes(source, parameters), try tree.Matcher.requiredWorkingMemory(source, parameters.hq_options));
        var budget = resources.WorkingAllocator.init(a, required);
        var exact_parameters = parameters;
        exact_parameters.hq_options.max_working_memory = required;
        const result = try parser.plan(budget.allocator(), &budget, source, exact_parameters, tree.Matcher);
        defer result.deinit(budget.allocator());
        try checkBytes(source, result);
        try std.testing.expectEqual(required, result.peak_working_memory);
    };
    const long_source = tree.Source.init("a", "", "a" ** 8192, 16384);
    const long = try run(long_source, .{ .strategy = .btopt, .hq_options = .{ .nice_len = 128 } });
    defer long.deinit(a);
    try checkBytes(long_source, long);
    if (parser.adaptive_stop) {
        try std.testing.expectEqual(@as(usize, 1), long.records.len);
        try std.testing.expectEqual(@as(usize, 8192), long.records[0].match_len);
        const scripted_source = tree.Source.init("abcdwxyz", "", "abcdq", 64);
        var equal_profile: @import("../../encode/controls.zig").Profile = .{};
        var longer_profile: @import("../../encode/controls.zig").Profile = .{};
        var equal_budget = resources.WorkingAllocator.init(a, std.math.maxInt(usize));
        var longer_budget = resources.WorkingAllocator.init(a, std.math.maxInt(usize));
        const equal = try parser.plan(equal_budget.allocator(), &equal_budget, scripted_source, .{ .strategy = .btopt, .initial_repeated_offsets = .{ 100, 200, 300 }, .profile = &equal_profile, .hq_options = .{ .nice_len = 4 } }, BoundaryMatcher);
        defer equal.deinit(equal_budget.allocator());
        const longer = try parser.plan(longer_budget.allocator(), &longer_budget, scripted_source, .{ .strategy = .btopt, .initial_repeated_offsets = .{ 100, 200, 300 }, .profile = &longer_profile, .hq_options = .{ .nice_len = 3 } }, BoundaryMatcher);
        defer longer.deinit(longer_budget.allocator());
        // Equal-to-nice still enumerates both length3 and4; strictly longer
        // terminates with one tail edge before local DP initialization.
        try std.testing.expect(equal_profile.price_evaluations > longer_profile.price_evaluations);
        try std.testing.expectEqual(@as(u64, 1), longer_profile.price_evaluations);
        try std.testing.expectEqual(@as(usize, 4), longer.records[0].match_len);
    }
}

const BoundaryMatcher = struct {
    position: usize = 0,
    storage: [1]tree.Match = .{.{ .length = 4, .distance = 8 }},
    pub fn init(_: std.mem.Allocator, _: tree.Source, _: tree.HqOptions, _: ?*@import("../../encode/controls.zig").Profile) !BoundaryMatcher {
        return .{};
    }
    pub fn deinit(_: *BoundaryMatcher, _: std.mem.Allocator) void {}
    pub fn advanceTo(self: *BoundaryMatcher, position: usize) !void {
        if (position < self.position) return error.InvalidBlockPlan;
        self.position = position;
    }
    pub fn find(self: *BoundaryMatcher) !tree.Matches {
        const current = self.position;
        self.position += 1;
        return .{ .items = if (current == 0) &self.storage else &.{} };
    }
};

test "Zstd HQ frontier public cold two pass measured cap preserves records" {
    const hq = @import("../hq_parser.zig");
    const source = hq.Source.init("", "", "abc0123abc0123" ** 16, 1024);
    var profile: @import("../../encode/controls.zig").Profile = .{};
    var parameters: hq.Parameters = .{ .strategy = .btultra2, .profile = &profile };
    const free = try hq.planAlloc(a, source, parameters);
    defer free.deinit(a);
    try std.testing.expectEqual(@as(u8, 2), free.passes);
    try std.testing.expectEqual(@as(u64, 2), profile.hq_passes);
    const cap = profile.max_plan_price_evaluations;
    profile.reset();
    parameters.hq_options.max_price_evaluations = cap;
    const exact = try hq.planAlloc(a, source, parameters);
    defer exact.deinit(a);
    try samePlan(free, exact);
    parameters.hq_options.max_price_evaluations = cap - 1;
    profile.reset();
    try std.testing.expectError(error.SearchLimitExceeded, hq.planAlloc(a, source, parameters));
}

const EmptyMatcher = struct {
    position: usize = 0,
    pub fn init(_: std.mem.Allocator, _: tree.Source, _: tree.HqOptions, _: ?*@import("../../encode/controls.zig").Profile) !EmptyMatcher {
        return .{};
    }
    pub fn deinit(_: *EmptyMatcher, _: std.mem.Allocator) void {}
    pub fn advanceTo(self: *EmptyMatcher, position: usize) !void {
        self.position = position;
    }
    pub fn find(self: *EmptyMatcher) !tree.Matches {
        self.position += 1;
        return .{ .items = &.{} };
    }
};

test "Zstd HQ frontier full block literal tail and allocation failure cleanup" {
    const large = try a.alloc(u8, 128 * 1024);
    defer a.free(large);
    @memset(large, 0);
    // Repeats cannot match if their preceding symbol differs; eliminate them by
    // selecting initial distances beyond the retained window for this mock.
    const source = tree.Source.init("", "", large, 1);
    var budget = resources.WorkingAllocator.init(a, std.math.maxInt(usize));
    const result = try parser.plan(budget.allocator(), &budget, source, .{ .strategy = .btopt, .initial_repeated_offsets = .{ 2, 4, 8 } }, EmptyMatcher);
    defer result.deinit(budget.allocator());
    try std.testing.expectEqual(@as(usize, 0), result.records.len);
    try std.testing.expectEqual(@as(u32, 131072), result.statistics.literal_count);
    const Cleanup = struct {
        fn runFail(allocator: std.mem.Allocator) !void {
            var working = resources.WorkingAllocator.init(allocator, std.math.maxInt(usize));
            const plan = try parser.plan(working.allocator(), &working, tree.Source.init("", "", "abcabcabcabcabcabc", 1024), .{ .strategy = .btopt }, tree.Matcher);
            plan.deinit(working.allocator());
            try std.testing.expectEqual(@as(usize, 0), working.live);
        }
    };
    try std.testing.checkAllAllocationFailures(a, Cleanup.runFail, .{});
}
