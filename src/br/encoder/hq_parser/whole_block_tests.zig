const std = @import("std");
const parser = @import("../hq_parser.zig");
const options = @import("../hq_options.zig");
const distance = @import("../distance.zig");
const state = @import("state.zig");
const Ledger = @import("test_allocator_ledger.zig").Ledger;

test "BrHQ whole block known 4098 oracle reaches cheaper later copy and preserves bounded result" {
    var input: [4098]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x4098);
    random.random().bytes(input[0..4094]);
    @memcpy(input[4094..], input[0..4]);
    const source = try parser.Source.init("", &input, 24, 0);
    var model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    model.command_prices = @splat(parser.prices.maximum_symbol_price);
    model.distance_prices = @splat(parser.prices.maximum_symbol_price);
    model.command_prices[488] = parser.prices.scale;
    model.command_prices[490] = parser.prices.maximum_symbol_price;
    model.command_prices[16] = parser.prices.scale;
    model.distance_prices[36] = 0;
    const bounded = try parser.planAlloc(std.testing.allocator, source, .{}, &model, null);
    defer bounded.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u64, 32793 * parser.prices.scale), bounded.estimated_cost);
    var parameters: parser.Parameters = .{};
    parameters.resolved.parse_mode = .whole_block;
    var profile: options.HqProfile = .{};
    parameters.profile = &profile;
    const whole = try parser.planAlloc(std.testing.allocator, source, parameters, &model, null);
    defer whole.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u64, 32792 * parser.prices.scale), whole.estimated_cost);
    try std.testing.expectEqual(@as(usize, 1), whole.commands.len);
    try std.testing.expectEqual(@as(usize, 4096), whole.commands[0].insert_len);
    try std.testing.expectEqual(@as(usize, 2), whole.commands[0].copy_len);
    try std.testing.expectEqual(@as(u64, 1), profile.whole_block_passes);
    try std.testing.expectEqual(@as(u64, 0), profile.bounded_passes);
    try std.testing.expectEqual(input.len, profile.max_parse_positions);
}

test "BrHQ whole block dense budget exact below and large metadata refuse before allocation" {
    const source = try parser.Source.init("abcd", "abcdabcd", 24, 4);
    const model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    var parameters: parser.Parameters = .{};
    parameters.resolved.parse_mode = .whole_block;
    const required = try parser.requiredWorkingMemory(source, parameters, &model, null);
    var meter: Ledger = .{ .backing = std.testing.allocator, .forbid_remap = true };
    const baseline = try parser.planAlloc(meter.allocator(), source, parameters, &model, null);
    const measured = meter.peak;
    try std.testing.expectEqual(measured, baseline.peak_working_memory);
    try std.testing.expect(required < measured);
    baseline.deinit(meter.allocator());
    try std.testing.expectEqual(@as(usize, 0), meter.live);
    meter.peak = 0;
    parameters.resolved.max_working_memory = measured;
    const plan = try parser.planAlloc(meter.allocator(), source, parameters, &model, null);
    try std.testing.expectEqual(measured, meter.peak);
    try std.testing.expectEqual(plan.commands.len, plan.command_storage.len);
    plan.deinit(meter.allocator());
    try std.testing.expectEqual(@as(usize, 0), meter.live);
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    parameters.resolved.max_working_memory = required - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, parser.planAlloc(failing.allocator(), source, parameters, &model, null));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    meter.peak = 0;
    parameters.resolved.max_working_memory = measured - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, parser.planAlloc(meter.allocator(), source, parameters, &model, null));
    try std.testing.expectEqual(@as(usize, 0), meter.live);
    for ([_]usize{ 8 * 1024 * 1024, 16 * 1024 * 1024 }) |length| {
        const synthetic = @as([*]const u8, @ptrFromInt(4096))[0..length];
        const large = try parser.Source.init("", synthetic, 24, 0);
        parameters.resolved.block_len = length;
        parameters.resolved.max_working_memory = 0;
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, parser.planAlloc(failing.allocator(), large, parameters, &model, null));
        try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
        if (@bitSizeOf(usize) >= 64) {
            const node_bytes = (length + 1) * parameters.resolved.beam_width * @sizeOf(state.Node);
            try std.testing.expect(try parser.requiredWorkingMemory(large, parameters, &model, null) >= node_bytes);
        }
    }
}

test "BrHQ whole block small model set agrees with independent exhaustive paths" {
    const oracle = @import("oracle_tests.zig");
    for ([_]distance.Format{ .standard, .large_window }) |format| {
        const source = try parser.Source.initWithFormat("abcd", "abcdab", if (format == .standard) 24 else 30, 4, format);
        for (0..2) |shape| {
            var model = parser.Model.initWithFormat(distance.Parameters.init(0, 0), 0, format);
            if (shape == 1) {
                for (&model.literal_prices, 0..) |*table, context| for (table, 0..) |*cost, byte| {
                    cost.* = @intCast(128 + (context * 31 + byte * 17) % 384);
                };
                for (&model.command_prices, 0..) |*cost, symbol| cost.* = @intCast(64 + (symbol % 11) * 32);
                for (&model.distance_prices, 0..) |*cost, symbol| cost.* = @intCast(96 + (symbol % 5) * 16);
            }
            const expected = try oracle.path(source, &model, 0, 0, source.recent);
            var parameters: parser.Parameters = .{};
            parameters.resolved.format = format;
            parameters.resolved.parse_mode = .whole_block;
            parameters.resolved.beam_width = 32;
            const plan = try parser.planAlloc(std.testing.allocator, source, parameters, &model, null);
            defer plan.deinit(std.testing.allocator);
            try std.testing.expectEqual(expected, plan.estimated_cost);
            try std.testing.expectEqual(source.input.len, plan.consumed);
            try std.testing.expectEqual(format, plan.format);
        }
    }
}

test "BrHQ whole block actual predecessor beyond sixty four KiB stays wide" {
    const copy_start = 65537;
    const input = try std.testing.allocator.alloc(u8, copy_start + 32);
    defer std.testing.allocator.free(input);
    var random = std.Random.DefaultPrng.init(0x66b0);
    random.random().bytes(input[0..copy_start]);
    @memcpy(input[copy_start..], input[0..32]);
    const source = try parser.Source.init("", input, 24, 0);
    var model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    model.command_prices = @splat(parser.prices.maximum_symbol_price);
    model.distance_prices = @splat(parser.prices.maximum_symbol_price);
    var parameters: parser.Parameters = .{};
    parameters.resolved.parse_mode = .whole_block;
    parameters.resolved.max_working_memory = 128 * 1024 * 1024;
    const plan = try parser.planAlloc(std.testing.allocator, source, parameters, &model, null);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(input.len, plan.consumed);
    try std.testing.expectEqual(@as(usize, 1), plan.commands.len);
    try std.testing.expectEqual(@as(usize, copy_start), plan.commands[0].insert_len);
    try std.testing.expectEqual(@as(usize, 32), plan.commands[0].copy_len);
    try std.testing.expectEqual(@as(usize, copy_start), plan.commands[0].distance);
    try std.testing.expectEqual(@as(usize, copy_start), plan.statistics.literal_count);
    try std.testing.expect(plan.peak_working_memory <= parameters.resolved.max_working_memory);
}

test "BrHQ whole block static commands cross small four KiB and sixty four KiB positions" {
    const provider_mod = @import("../hq_dictionary.zig");
    const serialized = @import("../../serialized_dictionary.zig");
    const bytes = try @import("dictionary_tests.zig").makeDictionary(std.testing.allocator, "", 0, true);
    defer std.testing.allocator.free(bytes);
    const dictionary = try serialized.parse(bytes);
    for ([_]usize{ 15, 4095, 65535 }) |copy_start| {
        const input = try std.testing.allocator.alloc(u8, copy_start + 5);
        defer std.testing.allocator.free(input);
        var random = std.Random.DefaultPrng.init(0x5217);
        random.random().bytes(input[0..copy_start]);
        @memcpy(input[copy_start..], "cat! ");
        var budget = parser.Budget.init(std.testing.allocator, 128 * 1024 * 1024);
        var provider = try provider_mod.Provider.init(&budget, .{ .serialized = &dictionary }, null);
        defer provider.deinit();
        const source = try parser.Source.init("", input, 24, 0);
        var model = parser.Model.init(distance.Parameters.init(0, 0), 0);
        model.command_prices = @splat(parser.prices.maximum_symbol_price);
        model.distance_prices = @splat(0);
        const physical = copy_start + 1;
        const choices = try model.commandCosts(copy_start, 4, physical + 15);
        for (choices.slice()) |choice| model.command_prices[choice.encoding.command_symbol] = parser.prices.scale;
        var parameters: parser.Parameters = .{ .budget = &budget };
        parameters.resolved.parse_mode = .whole_block;
        const plan = try parser.planAlloc(budget.allocator(), source, parameters, &model, &provider);
        defer plan.deinit(budget.allocator());
        try std.testing.expectEqual(input.len, plan.consumed);
        const last = plan.commands[plan.commands.len - 1];
        try std.testing.expect(last.isStatic());
        try std.testing.expectEqual(copy_start, last.insert_start + last.insert_len);
        try std.testing.expectEqual(@as(usize, 4), last.copy_len);
        try std.testing.expectEqual(@as(usize, 5), last.outputLen());
        try std.testing.expectEqual(@as(usize, 0), last.dictionary_address);
    }
}
