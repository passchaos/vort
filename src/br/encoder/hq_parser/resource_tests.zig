const std = @import("std");
const parser = @import("../hq_parser.zig");
const distance = @import("../distance.zig");
const options = @import("../hq_options.zig");
const Ledger = @import("test_allocator_ledger.zig").Ledger;

test "BrHQ core exact below budget and all OOM sites release without model or source mutation" {
    const source = try parser.Source.init("abcd", "abcdabcd", 24, 4);
    const model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    var parameters: parser.Parameters = .{};
    const required = try parser.requiredWorkingMemory(source, parameters, &model, null);
    var baseline_ledger: Ledger = .{ .backing = std.testing.allocator, .forbid_remap = true };
    const baseline = try parser.planAlloc(baseline_ledger.allocator(), source, parameters, &model, null);
    const measured_peak = baseline_ledger.peak;
    try std.testing.expectEqual(measured_peak, baseline.peak_working_memory);
    try std.testing.expect(required < measured_peak);
    baseline.deinit(baseline_ledger.allocator());
    try std.testing.expectEqual(@as(usize, 0), baseline_ledger.live);
    var exact_ledger: Ledger = .{ .backing = std.testing.allocator, .forbid_remap = true };
    parameters.resolved.max_working_memory = measured_peak;
    const plan = try parser.planAlloc(exact_ledger.allocator(), source, parameters, &model, null);
    try std.testing.expectEqual(measured_peak, exact_ledger.peak);
    try std.testing.expectEqual(plan.commands.len, plan.command_storage.len);
    plan.deinit(exact_ledger.allocator());
    try std.testing.expectEqual(@as(usize, 0), exact_ledger.live);
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    parameters.resolved.max_working_memory = required - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, parser.planAlloc(failing.allocator(), source, parameters, &model, null));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    var below_ledger: Ledger = .{ .backing = std.testing.allocator, .forbid_remap = true };
    parameters.resolved.max_working_memory = measured_peak - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, parser.planAlloc(below_ledger.allocator(), source, parameters, &model, null));
    try std.testing.expectEqual(@as(usize, 0), below_ledger.live);
    const Test = struct {
        fn run(allocator: std.mem.Allocator, input: parser.Source, prices: *const parser.Model) !void {
            const result = try parser.planAlloc(allocator, input, .{}, prices, null);
            defer result.deinit(allocator);
            try std.testing.expectEqual(input.input.len, result.consumed);
        }
    };
    const before_model = model;
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{ source, &model });
    try std.testing.expect(std.meta.eql(before_model, model));
    try std.testing.expectEqual([4]usize{ 16, 15, 11, 4 }, source.recent);
}

test "BrHQ core refined statistics actually update all alphabets and empty input does no work" {
    const source = try parser.Source.init("", "abcabcabc", 24, 0);
    const initial = parser.Model.init(distance.Parameters.init(3, 15), 0);
    var parameters: parser.Parameters = .{};
    parameters.resolved.distance_parameters = initial.distance_parameters;
    const plan = try parser.planAlloc(std.testing.allocator, source, parameters, &initial, null);
    defer plan.deinit(std.testing.allocator);
    const refined = try initial.refined(&plan.statistics);
    try std.testing.expect(!std.meta.eql(initial.command_prices, refined.command_prices));
    try std.testing.expect(!std.meta.eql(initial.literal_prices, refined.literal_prices));
    try std.testing.expect(!std.meta.eql(initial.distance_prices, refined.distance_prices));
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var profile: options.HqProfile = .{};
    parameters.resolved.max_working_memory = 0;
    parameters.profile = &profile;
    const empty = try parser.planAlloc(failing.allocator(), try parser.Source.init("", "", 24, @as(u64, 1) << 32), parameters, &initial, null);
    defer empty.deinit(failing.allocator());
    try std.testing.expectEqual(@as(usize, 0), empty.commands.len);
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    try std.testing.expectEqual(@as(u64, 0), profile.passes);
}

test "BrHQ core full 256 KiB meta preserves wide lengths at window twenty four" {
    const input = try std.testing.allocator.alloc(u8, 256 * 1024);
    defer std.testing.allocator.free(input);
    const pattern = "abcdefg";
    for (input, 0..) |*byte, position| byte.* = pattern[position % pattern.len];
    const source = try parser.Source.init(pattern, input, 24, pattern.len);
    const model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    const plan = try parser.planAlloc(std.testing.allocator, source, .{}, &model, null);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(input.len, plan.consumed);
    try std.testing.expectEqual(@as(usize, 1), plan.commands.len);
    try std.testing.expectEqual(input.len, plan.commands[0].copy_len);
    try std.testing.expectEqual(@as(usize, 7), plan.commands[0].distance);
    try std.testing.expectEqual(@as(usize, 0), plan.commands[0].insert_len);
}

test "BrHQ core failed borrowed checkpoint parse preserves entering owner and shared budget" {
    const provider_mod = @import("../hq_dictionary.zig");
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var budget = parser.Budget.init(failing.allocator(), 64 * 1024 * 1024);
    const a = budget.allocator();
    var provider = try provider_mod.Provider.init(&budget, .{}, null);
    defer provider.deinit();
    const source = try parser.Source.init("", "time", 24, 0);
    var entering = try parser.Matcher.init(a, source, (parser.Parameters{}).resolved, null);
    defer entering.deinit(a);
    var checkpoint = try entering.fork(a, budget.limit, null);
    defer checkpoint.deinit(a);
    const model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    const live_before = budget.live;
    // The first four allocations are fixed parser workspaces. The next one
    // grows the real dictionary frontier after the checkpoint's first probe.
    failing.fail_index = failing.alloc_index + 4;
    try std.testing.expectError(error.OutOfMemory, parser.planAlloc(a, source, .{ .budget = &budget, .matcher = &checkpoint }, &model, &provider));
    try std.testing.expectEqual(@as(usize, 0), entering.position());
    try std.testing.expectEqual(@as(usize, 1), checkpoint.position());
    try std.testing.expectEqual(live_before, budget.live);
    try std.testing.expectEqual([4]usize{ 16, 15, 11, 4 }, source.recent);
}

test "BrHQ core hostile length metadata and invalid settings reject before allocation" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    try std.testing.expectError(error.IntegerOverflow, parser.Source.init("", "aa", 24, std.math.maxInt(u64) - 1));
    const synthetic: []const u8 = @as([*]const u8, @ptrFromInt(4096))[0 .. 16 * 1024 * 1024];
    const source = try parser.Source.init("", synthetic, 24, 0);
    var parameters: parser.Parameters = .{};
    parameters.resolved.block_len = 16 * 1024 * 1024;
    parameters.resolved.max_working_memory = 0;
    try std.testing.expect(try parser.requiredWorkingMemory(source, parameters, &model, null) > 128 * 1024 * 1024);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, parser.planAlloc(failing.allocator(), source, parameters, &model, null));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    parameters.resolved.quality = 9;
    try std.testing.expectError(error.InvalidBlockPlan, parser.planAlloc(failing.allocator(), source, parameters, &model, null));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
}
