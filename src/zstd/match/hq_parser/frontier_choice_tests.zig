//! Per-edge committed state and full synthetic-plan comparison. The production
//! context/parser is injected; the copied interval oracle uses no prepared price.
const std = @import("std");
const state = @import("state.zig");
const prices = @import("prices.zig");
const rep = @import("rep.zig");
const controls = @import("../../encode/controls.zig");
const PriceBudget = @import("price_budget.zig").PriceBudget;
const original = @import("frontier_choice_tests/interval.zig");

pub const sameProfile = @import("frontier_choice_tests/profiles.zig").same;

fn sameResult(expected: anytype, actual: @TypeOf(expected)) !void {
    if (expected) |_| try actual else |err| try std.testing.expectError(err, actual);
}

const Case = struct {
    strategy: controls.Strategy = .btultra,
    first: usize = 3,
    last: usize = 131,
    position: usize = 0,
    goal: usize = 0,
    literal_len: u32 = 0,
    distance: usize = 8,
    repeats: rep.Repeats = .{ 8, 8, 8 },
    populated: bool = false,
    bad_cost: enum { none, underflow, overflow } = .none,
    prefix_fault: bool = false,
    admitted: u64 = 0,
};
const Coverage = struct { intervals: usize = 0, committed_edges: u64 = 0, quota_prefixes: usize = 0, faults: usize = 0 };

fn compareCase(comptime Module: type, settings: Case, limit: ?u64, coverage: *Coverage) !void {
    var model: prices.EntropyModel = .{};
    for (&model.ll_prices, 0..) |*price, index| price.* = @intCast(127 + index * 13);
    for (&model.ml_prices, 0..) |*price, index| price.* = @intCast(1 + (index % 7) * 37);
    model.of_prices[0] = 256;
    model.of_prices[1] = 0; // Repeat selector 2/3 ties retain ordered histories.
    model.penalize_long_offsets = settings.strategy == .btopt;
    const model_before = model;
    var old_profile: controls.Profile = .{};
    var actual_profile: controls.Profile = .{};
    var reference_profile: controls.Profile = .{};
    var old_budget = PriceBudget.init(limit, &old_profile);
    var actual_budget = PriceBudget.init(limit, &actual_profile);
    var reference_budget = PriceBudget.init(limit, &reference_profile);
    old_budget.admitted = settings.admitted;
    actual_budget.admitted = settings.admitted;
    reference_budget.admitted = settings.admitted;
    var parameters: state.Parameters = .{ .strategy = settings.strategy, .entropy = &model, .profile = &old_profile };
    parameters.hq_options.min_match = @intCast(@min(@as(usize, 7), @max(@as(usize, 3), settings.first)));
    const safe_ll = original.literalLengthPrice(&model, @min(settings.literal_len, 131072)) catch 0;
    const node: state.Node = .{
        .cost = switch (settings.bad_cost) {
            .none => safe_ll + 900,
            .underflow => 0,
            .overflow => std.math.maxInt(u64),
        },
        .literal_len = settings.literal_len,
        .repeats = settings.repeats,
    };
    const goal = if (settings.goal != 0) settings.goal else settings.position + @max(settings.last, 9) + 1;
    const storage = try std.testing.allocator.alloc(state.Node, goal + 3);
    defer std.testing.allocator.free(storage);
    const poison: state.Node = .{ .cost = 0, .literal_len = 991, .repeats = .{ 91, 93, 95 }, .previous_position = 17 };
    @memset(storage, poison);
    if (settings.populated) {
        for (storage[1 .. goal + 2], 0..) |*row, position| {
            row.* = .{ .cost = if (position % 3 == 0) 0 else std.math.maxInt(u64), .literal_len = 77, .repeats = .{ 21, 23, 25 } };
        }
    }
    storage[1] = node;
    const actual_storage = try std.testing.allocator.dupe(state.Node, storage);
    defer std.testing.allocator.free(actual_storage);
    const reference_storage = try std.testing.allocator.dupe(state.Node, storage);
    defer std.testing.allocator.free(reference_storage);
    var old: original.Context = .{
        .nodes = storage[1 .. goal + 2],
        .goal = goal,
        .last = 0,
        .initialized_end = if (settings.populated) goal else 0,
        .parameters = parameters,
        .price_budget = &old_budget,
    };
    parameters.profile = &actual_profile;
    var actual: Module.TestContext = .{
        .nodes = actual_storage[1 .. goal + 2],
        .goal = goal,
        .last = 0,
        .initialized_end = old.initialized_end,
        .parameters = parameters,
        .price_budget = &actual_budget,
    };
    parameters.profile = &reference_profile;
    var reference: Module.ReferenceContext = .{
        .nodes = reference_storage[1 .. goal + 2],
        .goal = goal,
        .last = 0,
        .initialized_end = old.initialized_end,
        .parameters = parameters,
        .price_budget = &reference_budget,
    };
    if (settings.prefix_fault) {
        const a = old.interval(settings.position, node, settings.distance, 3, 9);
        const b = actual.interval(settings.position, node, settings.distance, 3, 9);
        const c = reference.interval(settings.position, node, settings.distance, 3, 9);
        try sameResult(a, b);
        try sameResult(a, c);
    }
    const expected = old.interval(settings.position, node, settings.distance, settings.first, settings.last);
    const observed = actual.interval(settings.position, node, settings.distance, settings.first, settings.last);
    const scalar = reference.interval(settings.position, node, settings.distance, settings.first, settings.last);
    try sameResult(expected, observed);
    try sameResult(expected, scalar);
    if (expected) |_| {} else |_| coverage.faults += 1;
    old_budget.finish();
    actual_budget.finish();
    reference_budget.finish();
    try std.testing.expectEqualSlices(state.Node, storage, actual_storage);
    try std.testing.expectEqualSlices(state.Node, storage, reference_storage);
    try std.testing.expectEqual(old.last, actual.last);
    try std.testing.expectEqual(old.last, reference.last);
    try std.testing.expectEqual(old.initialized_end, actual.initialized_end);
    try std.testing.expectEqual(old.initialized_end, reference.initialized_end);
    try std.testing.expectEqual(old_budget.admitted, actual_budget.admitted);
    try std.testing.expectEqual(old_budget.admitted, reference_budget.admitted);
    try sameProfile(old_profile, actual_profile);
    try sameProfile(old_profile, reference_profile);
    if (expected) |_| {
        try std.testing.expectEqual(old_profile.price_evaluations, actual_profile.frontier_choice_preparations + actual_profile.frontier_choice_replays + actual_profile.frontier_unprepared_edges);
        try std.testing.expectEqual(old_profile.price_evaluations, reference_profile.frontier_unprepared_edges);
    } else |_| {}
    try std.testing.expectEqualDeep(model_before, model);
    coverage.committed_edges += old_profile.price_evaluations;
    coverage.intervals += 1;
}

fn edgePrefixes(comptime Module: type, coverage: *Coverage) !void {
    // Each quota N executes exactly the old ordered prefix then refuses the
    // next edge. This checks state after every choice/length without a hook.
    for ([_]controls.Strategy{ .btopt, .btultra, .btultra2 }) |strategy| {
        for ([_]u32{ 0, 3 }) |literal_len| {
            const settings: Case = .{ .strategy = strategy, .first = 3, .last = 131, .literal_len = literal_len };
            const node: state.Node = .{ .literal_len = literal_len, .repeats = settings.repeats };
            const edges = try original.orderedEdges(.{ .strategy = strategy }, node, settings.distance, settings.first, settings.last);
            try std.testing.expect(edges.len != 0);
            try std.testing.expectEqual(settings.last, edges.values[0].length);
            for (0..edges.len + 1) |allowance| {
                try compareCase(Module, settings, allowance, coverage);
                coverage.quota_prefixes += 1;
            }
            try compareCase(Module, settings, null, coverage);
        }
    }
}

fn boundaries(comptime Module: type, coverage: *Coverage) !void {
    for ([_]controls.Strategy{ .btopt, .btultra, .btultra2 }) |strategy| {
        for ([_]usize{ 3, 4, 16, 17, 18, 19, 20, 21, 64, 65, 67, 98, 99, 130, 131, 258, 259, 514, 515, 1026, 1027, 4095, 4096 }) |last| {
            for ([_]usize{ 3, 4 }) |first| try compareCase(Module, .{
                .strategy = strategy,
                .first = first,
                .last = last,
                .position = 3,
                .literal_len = 15,
                .distance = 7,
                .repeats = .{ 8, 7, 7 },
                .populated = last & 1 == 0,
            }, null, coverage);
        }
        try compareCase(Module, .{ .strategy = strategy, .first = 17, .last = 16 }, null, coverage);
        try compareCase(Module, .{ .strategy = strategy, .last = 67, .distance = (1 << 20) + 17 }, null, coverage);
    }
    try compareCase(Module, .{ .last = 131072, .goal = 131072, .distance = 19 }, null, coverage);
    const errors = [_]Case{
        .{ .distance = 0 },                    .{ .distance = std.math.maxInt(u32) - 2 },
        .{ .repeats = .{ 0, 4, 8 } },          .{ .literal_len = 131072 },
        .{ .literal_len = 131073 },            .{ .first = 2, .last = 3, .prefix_fault = true },
        .{ .bad_cost = .underflow },           .{ .bad_cost = .overflow },
        .{ .admitted = std.math.maxInt(u64) },
    };
    for (errors) |settings| {
        try compareCase(Module, settings, null, coverage);
        try compareCase(Module, settings, 0, coverage);
    }
}

pub fn check(comptime Module: type) !void {
    var coverage: Coverage = .{};
    try edgePrefixes(Module, &coverage);
    try boundaries(Module, &coverage);
    try @import("frontier_choice_tests/plans.zig").check(Module);
    try std.testing.expect(coverage.faults != 0 and coverage.quota_prefixes != 0);
    std.debug.print("frontier_choices intervals={d} edge_prices={d} quota_prefixes={d} faults={d}\n", .{
        coverage.intervals, coverage.committed_edges, coverage.quota_prefixes, coverage.faults,
    });
}
