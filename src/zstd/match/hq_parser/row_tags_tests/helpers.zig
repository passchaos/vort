const std = @import("std");
pub const source_mod = @import("../../controlled_source.zig");
pub const state = @import("../state.zig");
pub const dp = @import("../dp.zig");
pub const Frozen = @import("../dp_row_tags_reference.zig");
pub const resources = @import("../resources.zig");
pub const prices = @import("../prices.zig");
pub const Profile = @import("../../../encode/controls.zig").Profile;
pub const tree = @import("../../hq_tree.zig");
const a = std.testing.allocator;

pub const Options = struct {
    strategy: @import("../../../encode/controls.zig").Strategy = .btopt,
    whole: bool = false,
    complete: bool = false,
    minimum: u8 = 3,
    depth: u32 = 8,
    nice_len: u32 = 16,
    quota: ?u64 = null,
    working_limit: usize = std.math.maxInt(usize),
    repeats: [3]usize = .{ 1, 4, 8 },
};
pub const Report = struct {
    failure: ?anyerror,
    admitted: u64,
    peak: usize,
    old_peak: usize,
    records: usize,
};

pub fn profileEqual(expected: Profile, actual: Profile) !void {
    inline for (comptime std.meta.fieldNames(Profile)) |field| {
        if (comptime std.mem.eql(u8, field, "peak_working_memory") or
            std.mem.eql(u8, field, "rep_probes") or
            std.mem.eql(u8, field, "rep_length_cache_hits") or
            std.mem.eql(u8, field, "byte_comparisons")) continue;
        try std.testing.expectEqualDeep(@field(expected, field), @field(actual, field));
    }
    try std.testing.expectEqual(expected.rep_probes, actual.rep_probes + actual.rep_length_cache_hits);
    try std.testing.expect(actual.byte_comparisons <= expected.byte_comparisons);
}

fn planEqual(expected: state.Plan, actual: state.Plan) !void {
    inline for (comptime std.meta.fieldNames(state.Plan)) |field| {
        if (comptime std.mem.eql(u8, field, "peak_working_memory")) continue;
        if (comptime std.mem.eql(u8, field, "record_storage") or std.mem.eql(u8, field, "offset_storage")) {
            // Unused allocation capacity has undefined elements. Compare its
            // ownership geometry and all used slices, not unused padding/data.
            try std.testing.expectEqual(@field(expected, field).len, @field(actual, field).len);
        } else try std.testing.expectEqualDeep(@field(expected, field), @field(actual, field));
    }
    try std.testing.expect(expected.records.ptr == expected.record_storage.ptr);
    try std.testing.expect(actual.records.ptr == actual.record_storage.ptr);
    try std.testing.expect(expected.offset_values.ptr == expected.offset_storage.ptr);
    try std.testing.expect(actual.offset_values.ptr == actual.offset_storage.ptr);
}

pub fn compare(source: source_mod.Source, options: Options) !Report {
    const raw: prices.EntropyModel = .{};
    const model = try raw.forStrategy(options.strategy);
    var expected_profile: Profile = .{};
    var actual_profile: Profile = .{};
    var expected_budget = resources.WorkingAllocator.init(a, options.working_limit);
    const extra: usize = if (source.block.len < options.minimum) 0 else @as(usize, @sizeOf(@import("../row_tags.zig").Tags)) * (1 + @as(usize, if (options.whole) source.block.len else @min(state.horizon, source.block.len)));
    const actual_limit = if (options.working_limit == std.math.maxInt(usize)) options.working_limit else options.working_limit + extra;
    var actual_budget = resources.WorkingAllocator.init(a, actual_limit);
    var parameters: state.Parameters = .{
        .strategy = options.strategy,
        .initial_repeated_offsets = options.repeats,
        .entropy = &model,
        .profile = &expected_profile,
        .hq_options = .{
            .search_depth = options.depth,
            .nice_len = options.nice_len,
            .min_match = options.minimum,
            .parse_mode = if (options.whole) .whole_block else .bounded,
            .match_lengths = if (options.complete) .complete else .sampled,
            .max_price_evaluations = options.quota,
            .max_working_memory = options.working_limit,
        },
    };
    try std.testing.expectEqual(try Frozen.ownWorkingBytes(source, parameters) + extra, try dp.ownWorkingBytes(source, parameters));
    var expected_failure: ?anyerror = null;
    var expected: ?state.Plan = null;
    if (Frozen.plan(expected_budget.allocator(), &expected_budget, source, parameters, tree.Matcher)) |plan| expected = plan else |err| expected_failure = err;
    parameters.profile = &actual_profile;
    parameters.hq_options.max_working_memory = actual_limit;
    var actual_failure: ?anyerror = null;
    var actual: ?state.Plan = null;
    if (dp.plan(actual_budget.allocator(), &actual_budget, source, parameters, tree.Matcher)) |plan| actual = plan else |err| actual_failure = err;
    defer if (expected) |plan| plan.deinit(expected_budget.allocator());
    defer if (actual) |plan| plan.deinit(actual_budget.allocator());
    try std.testing.expectEqual(expected_failure, actual_failure);
    if (expected) |plan| try planEqual(plan, actual.?);
    // A direct DP call lets Matcher.init report its remaining heap cap.
    // The public HQ wrapper restores caller options after DP returns. Account
    // exactly for tag bytes here rather than ignoring another profile field.
    if (extra != 0 and actual_limit == options.working_limit and expected_profile.effective_hq_max_working_memory != 0) {
        try std.testing.expectEqual(expected_profile.effective_hq_max_working_memory, actual_profile.effective_hq_max_working_memory + extra);
        expected_profile.effective_hq_max_working_memory -= extra;
    }
    try profileEqual(expected_profile, actual_profile);
    if (expected != null) {
        try std.testing.expectEqual(expected_budget.peak + extra, actual_budget.peak);
        try std.testing.expectEqual(expected_budget.live, actual_budget.live);
    }
    return .{
        .failure = actual_failure,
        .admitted = actual_profile.max_plan_price_evaluations,
        .peak = actual_budget.peak,
        .old_peak = expected_budget.peak,
        .records = if (actual) |plan| plan.records.len else 0,
    };
}

pub fn random(bytes: []u8) void {
    var seed: u32 = 0x871acd29;
    for (bytes) |*byte| {
        seed = seed *% 1664525 +% 1013904223;
        byte.* = @truncate(seed >> 24);
    }
}
