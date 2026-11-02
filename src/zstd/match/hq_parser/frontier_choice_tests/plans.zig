//! Small real-source matchers retain sampled/duplicate frontier ordering while
//! avoiding production matcher internals. Complete plans replay independently.
const std = @import("std");
const source_mod = @import("../../controlled_source.zig");
const state = @import("../state.zig");
const prices = @import("../prices.zig");
const rep = @import("../rep.zig");
const controls = @import("../../../encode/controls.zig");
const resources = @import("../resources.zig");
const checks = @import("profiles.zig");

const Matches = struct {
    items: []const source_mod.Match,
    pub fn slice(self: *const Matches) []const source_mod.Match {
        return self.items;
    }
};
const Matcher = struct {
    source: source_mod.Source,
    options: controls.HqOptions,
    position: usize = 0,
    storage: [8]source_mod.Match = undefined,
    len: usize = 0,

    pub fn init(_: std.mem.Allocator, source: source_mod.Source, options: controls.HqOptions, _: ?*controls.Profile) !Matcher {
        if (options.search_depth == 13) return error.SyntheticMatcherFailure;
        return .{ .source = source, .options = options };
    }
    pub fn deinit(_: *Matcher, _: std.mem.Allocator) void {}
    pub fn advanceTo(self: *Matcher, position: usize) !void {
        if (position < self.position) return error.InvalidBlockPlan;
        self.position = position;
    }
    pub fn find(self: *Matcher) !Matches {
        const position = self.position;
        self.position += 1;
        self.len = 0;
        for ([_]usize{ 4, 8, 12, 16, 20, 24, 32, 48 }) |distance| {
            if (distance > self.source.prefixLen() + position) continue;
            var match = self.source.match(position, self.source.prefixLen() + position - distance, self.options.min_match);
            match.length = @min(match.length, 7 + distance % 29);
            if (match.length < self.options.min_match) continue;
            // Stable insertion orders lengths; equal lengths intentionally
            // remain duplicated so frontier suppression is also exercised.
            var index = self.len;
            while (index != 0 and match.length < self.storage[index - 1].length) : (index -= 1)
                self.storage[index] = self.storage[index - 1];
            self.storage[index] = match;
            self.len += 1;
        }
        return .{ .items = self.storage[0..self.len] };
    }
};

fn samePlan(expected: state.Plan, actual: state.Plan) !void {
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

fn replay(source: source_mod.Source, result: state.Plan, initial: rep.Repeats) !void {
    const output = try std.testing.allocator.alloc(u8, source.block.len);
    defer std.testing.allocator.free(output);
    var position: usize = 0;
    var repeats = initial;
    for (result.records, result.offset_values) |record, offset| {
        @memcpy(output[position..][0..record.literal_len], source.block[position..][0..record.literal_len]);
        position += record.literal_len;
        const selected = try rep.resolve(record.literal_len, offset, repeats);
        try std.testing.expectEqual(record.distance, selected.distance);
        repeats = selected.repeats;
        try std.testing.expect(record.distance <= source.prefixLen() + position);
        for (0..record.match_len) |_| {
            const absolute = source.prefixLen() + position - record.distance;
            output[position] = if (absolute < source.prefixLen()) source.byteAt(absolute) else output[absolute - source.prefixLen()];
            position += 1;
        }
        try std.testing.expectEqual(record.match_end, position);
    }
    @memcpy(output[position..], source.block[position..]);
    try std.testing.expectEqualSlices(u8, source.block, output);
    try std.testing.expectEqualDeep(repeats, result.final_repeated_offsets);
}

fn run(comptime Module: type, source: source_mod.Source, parameters: state.Parameters, required_error: ?anyerror) !controls.Profile {
    const before = try std.testing.allocator.dupe(u8, source.block);
    defer std.testing.allocator.free(before);
    const model_before = parameters.entropy.*;
    var old_profile: controls.Profile = .{};
    var actual_profile: controls.Profile = .{};
    var old_parameters = parameters;
    var actual_parameters = parameters;
    old_parameters.profile = &old_profile;
    actual_parameters.profile = &actual_profile;
    var old_budget = resources.WorkingAllocator.init(std.testing.allocator, std.math.maxInt(usize));
    var actual_budget = resources.WorkingAllocator.init(std.testing.allocator, std.math.maxInt(usize));
    const original = Module.planReference(old_budget.allocator(), &old_budget, source, old_parameters, Matcher);
    const current = Module.plan(actual_budget.allocator(), &actual_budget, source, actual_parameters, Matcher);
    if (original) |expected| {
        defer expected.deinit(old_budget.allocator());
        const result = try current;
        defer result.deinit(actual_budget.allocator());
        try std.testing.expect(required_error == null);
        try samePlan(expected, result);
        try replay(source, result, parameters.initial_repeated_offsets);
    } else |err| {
        const required = required_error orelse return err;
        try std.testing.expectEqual(required, err);
        if (current) |unwanted| {
            unwanted.deinit(actual_budget.allocator());
            return error.TestExpectedError;
        } else |actual_error| try std.testing.expectEqual(err, actual_error);
    }
    try std.testing.expectEqual(@as(usize, 0), old_budget.live);
    try std.testing.expectEqual(@as(usize, 0), actual_budget.live);
    try checks.same(old_profile, actual_profile);
    try std.testing.expectEqualSlices(u8, before, source.block);
    try std.testing.expectEqualDeep(model_before, parameters.entropy.*);
    return old_profile;
}

pub fn check(comptime Module: type) !void {
    const entropy: prices.EntropyModel = .{};
    const inputs = [_][]const u8{
        "",                                          "ab",                                                     "abcdefghi", "abcd" ** 32,
        ("abcdq0123456abcdx0123456" ** 8) ++ "tail", ("longer structured repeat:0123456789\n" ** 32) ++ "end",
    };
    var cases: usize = 0;
    for ([_]controls.Strategy{ .btopt, .btultra, .btultra2 }) |strategy| {
        for (inputs) |input| {
            for ([_]u8{ 3, 4 }) |minimum| {
                const source = source_mod.Source.init("abcdq0123456abcdx0123456", "", input, 4096);
                const parameters: state.Parameters = .{ .strategy = strategy, .entropy = &entropy, .initial_repeated_offsets = .{ 101, 103, 107 }, .hq_options = .{ .min_match = minimum, .nice_len = 64, .search_depth = 8 } };
                const observed = try run(Module, source, parameters, null);
                if (observed.max_plan_price_evaluations != 0) {
                    var exact = parameters;
                    exact.hq_options.max_price_evaluations = observed.max_plan_price_evaluations;
                    _ = try run(Module, source, exact, null);
                    exact.hq_options.max_price_evaluations = observed.max_plan_price_evaluations - 1;
                    const limited = try run(Module, source, exact, error.SearchLimitExceeded);
                    try std.testing.expectEqual(@as(u64, 1), limited.price_limit_refusals);
                }
                cases += 1;
            }
        }
    }
    const source = source_mod.Source.init("", "", "abcd" ** 32, 1024);
    var parameters: state.Parameters = .{ .strategy = .btultra, .entropy = &entropy };
    parameters.hq_options.search_depth = 13;
    _ = try run(Module, source, parameters, error.SyntheticMatcherFailure); // After result/node allocation.
    parameters.hq_options.search_depth = 8;
    parameters.hq_options.max_working_memory = 0;
    _ = try run(Module, source, parameters, error.WorkingMemoryLimitExceeded);
    parameters.hq_options.max_working_memory = std.math.maxInt(usize);
    parameters.hq_options.max_price_evaluations = 0;
    _ = try run(Module, source, parameters, error.SearchLimitExceeded);
    std.debug.print("frontier_choices synthetic_plan_cases={d} failure_prefixes=3\n", .{cases});
}
