const std = @import("std");
const br = @import("../br.zig");
const parser = @import("../br/encoder/hq_parser.zig");
const h = @import("br_complete_lengths_helpers.zig");
const a = std.testing.allocator;

test "Brotli complete lengths default sampled controls preserve the independently frozen small wires" {
    const chunks = [_][]const u8{ h.plain[0..17], h.plain[17..31], h.plain[31..] };
    for (h.frozen_wires) |sample| {
        const expected = try h.frozenAlloc(a, sample);
        defer a.free(expected);
        const one = h.options(br.PlannedEncodeOptions, sample.setting);
        const stream = h.options(br.PlannedStreamChunksOptions, sample.setting);
        const actual = switch (sample.api) {
            .one_shot => try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, one),
            .reusable => block: {
                var encoder = br.PlannedStreamEncoder.init(a);
                defer encoder.deinit();
                break :block try encoder.encodeWithOptionsAlloc(a, h.plain, one);
            },
            .chunks => try br.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, stream),
            .incremental => block: {
                var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(a, .{ .stream = stream, .block_len = 0 });
                defer encoder.deinit();
                break :block try h.drive(a, &encoder, h.plain, 31, 17);
            },
        };
        defer a.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
    }
}

test "Brotli complete lengths interior fifty sixty nine and eighty three beat sampled edges with actual wire selectors" {
    for ([_]struct { target: usize, quality: u8 }{ .{ .target = 50, .quality = 10 }, .{ .target = 69, .quality = 10 }, .{ .target = 83, .quality = 11 } }) |sample| {
        const fixture = try h.interior(a, sample.target);
        defer fixture.deinit(a);
        var model: parser.Model = .{};
        @memset(&model.command_prices, 64 * 256);
        @memset(&model.distance_prices, 64 * 256);
        model.literal_position_prices = fixture.literal_prices;
        model.command_prices[fixture.command_symbol] = 0;
        model.command_prices[296] = 0;
        const regular = h.distanceEncoding(100, 0, 0);
        model.distance_prices[regular.symbol] = 0;
        const oracle = h.interiorMinimum(fixture, &model);
        try std.testing.expectEqual(sample.target, oracle.copy);
        try std.testing.expectEqual(@as(u64, if (sample.target == 83) 19 * 256 else 18 * 256), oracle.cost);
        const source = try parser.Source.init("", fixture.input, 10, 0);
        var profile: br.HqProfile = .{};
        var parameters = try parser.Parameters.init(.{ .copy_lengths = .sampled, .parse_mode = .whole_block, .beam_width = 32, .profile = &profile }, sample.quality, br.PlannedMode.generic);
        const sampled = try parser.planAlloc(a, source, parameters, &model, null);
        defer sampled.deinit(a);
        try std.testing.expect(sampled.estimated_cost > oracle.cost);
        profile.reset();
        parameters.resolved.copy_lengths = .complete;
        const complete = try parser.planAlloc(a, source, parameters, &model, null);
        defer complete.deinit(a);
        try std.testing.expectEqual(oracle.cost, complete.estimated_cost);
        try std.testing.expectEqual(@as(usize, 2), complete.commands.len);
        const command = complete.commands[0];
        try std.testing.expectEqual(@as(usize, 100), command.insert_len);
        try std.testing.expectEqual(sample.target, command.copy_len);
        try std.testing.expectEqual(@as(usize, 100), command.distance);
        try std.testing.expectEqual(fixture.command_symbol, command.hq_encoding.?.command_symbol);
        try std.testing.expectEqual(@as(usize, 115), command.hq_encoding.?.distance_code);
        try std.testing.expect(profile.complete_length_passes > 0);
        try std.testing.expectEqual(@as(u64, 0), profile.sampled_length_passes);
        try std.testing.expectEqual(@as(usize, 100), profile.max_copy_length_considered);
        try h.replayWithHistory(a, "", fixture.input, .{ 4, 11, 15, 16 }, complete);
        const wire = try br.IncrementalTestSupport.encodeHqCommandPlan(a, fixture.input, complete.commands, .{ .window_bits = 10 });
        defer a.free(wire.bytes);
        const physical = try h.singleCommandWire(wire.bytes, .{ 4, 11, 15, 16 });
        try std.testing.expectEqual(@as(usize, fixture.command_symbol), physical.command_symbol);
        try std.testing.expectEqual(sample.target, physical.raw_copy_len);
        try std.testing.expectEqual(@as(usize, 100), physical.distance);
        const decoded = try br.decodeStreamAlloc(a, wire.bytes);
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, fixture.input, decoded);
    }
}

test "Brotli complete lengths tiny finite cache paths agree with independent exhaustive command pricing" {
    var model: parser.Model = .{};
    for (&model.literal_prices) |*row| @memset(row, 8 * 256);
    @memset(&model.command_prices, 3 * 256);
    @memset(&model.distance_prices, 2 * 256);
    for ([_][]const u8{ "abcd", "abcdab", "ababab" }) |input| {
        const source = try parser.Source.init("abcd", input, 10, 4);
        const expected = h.finiteCost("abcd", input, &model, 0, 0, .{ 4, 11, 15, 16 });
        const parameters = try parser.Parameters.init(.{ .copy_lengths = .complete, .parse_mode = .whole_block, .beam_width = 32 }, 10, br.PlannedMode.generic);
        const plan = try parser.planAlloc(a, source, parameters, &model, null);
        defer plan.deinit(a);
        try std.testing.expectEqual(expected, plan.estimated_cost);
        try h.replayWithHistory(a, "abcd", input, .{ 4, 11, 15, 16 }, plan);
    }
}

test "Brotli complete lengths compound interior fifty is enumerated while static transforms stay atomic" {
    const builder = @import("../br/serialized_dictionary_builder.zig");
    const serialized = @import("../br/serialized_dictionary.zig");
    const dictionary = @import("../br/encoder/hq_dictionary.zig");
    var prefix: [100]u8 = undefined;
    for (&prefix, 0..) |*byte, index| byte.* = @intCast(index);
    var sizes: [32]u8 = @splat(0);
    sizes[4] = 1;
    const encoded_dict = try builder.serializeAlloc(a, .{
        .raw_prefix = &prefix,
        .word_lists = &.{.{ .size_bits_by_length = sizes, .data = "cat!dog!" }},
        .transform_lists = &.{.{ .prefix_suffix = &.{ 1, ' ', 0 }, .transforms = &.{ 1, 0, 0 } }},
        .dictionaries = &.{.{ .word_list_index = 0, .transform_list_index = 0 }},
    });
    defer a.free(encoded_dict);
    const parsed = try serialized.parse(encoded_dict);
    var budget = parser.Budget.init(a, 64 * 1024 * 1024);
    var provider = try dictionary.Provider.init(&budget, .{ .serialized = &parsed }, null);
    defer provider.deinit();
    var position_prices: [100]u32 = @splat(0);
    @memset(position_prices[0..50], 64 * 256);
    var model: parser.Model = .{};
    model.literal_position_prices = &position_prices;
    @memset(&model.command_prices, 64 * 256);
    @memset(&model.distance_prices, 64 * 256);
    model.command_prices[198] = 0;
    model.command_prices[296] = 0;
    model.distance_prices[h.distanceEncoding(100, 0, 0).symbol] = 0;
    var expected_cost: u64 = std.math.maxInt(u64);
    var expected_copy: usize = 0;
    for (2..101) |copy| {
        var tail: u64 = 0;
        for (position_prices[copy..]) |price| tail += price;
        const cost = h.finiteCommand(&model, 0, copy, 115, 100) + h.finiteTerminal(&model, 100 - copy) + tail;
        if (cost < expected_cost) {
            expected_cost = cost;
            expected_copy = copy;
        }
    }
    try std.testing.expectEqual(@as(usize, 50), expected_copy);
    try std.testing.expectEqual(@as(u64, 13 * 256), expected_cost);
    var parameters = try parser.Parameters.init(.{ .copy_lengths = .complete, .parse_mode = .whole_block, .beam_width = 32 }, 10, br.PlannedMode.generic);
    parameters.budget = &budget;
    const plan = try parser.planAlloc(budget.allocator(), try parser.Source.init("", &prefix, 10, 0), parameters, &model, &provider);
    defer plan.deinit(budget.allocator());
    try std.testing.expectEqual(expected_cost, plan.estimated_cost);
    try std.testing.expect(plan.commands[0].isCompound());
    try std.testing.expectEqual(@as(usize, 50), plan.commands[0].copy_len);
    try std.testing.expectEqual(@as(usize, 115), plan.commands[0].hq_encoding.?.distance_code);
    const wire = try br.IncrementalTestSupport.encodeHqCommandPlan(a, &prefix, plan.commands, .{ .window_bits = 10, .compound_dictionary_size = 100 });
    defer a.free(wire.bytes);
    const actual = try h.singleCommandWire(wire.bytes, .{ 4, 11, 15, 16 });
    try std.testing.expectEqual(@as(usize, 50), actual.raw_copy_len);
    try std.testing.expectEqual(@as(usize, 100), actual.distance);
    const decoded = try br.decodeStreamAllocWithOptions(a, wire.bytes, .{ .shared_dictionary = .{ .serialized = &parsed } });
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, &prefix, decoded);
    model.literal_position_prices = null;
    for (&model.literal_prices) |*row| @memset(row, 64 * 256);
    model.command_prices[130] = 0;
    @memset(&model.distance_prices, 0);
    const static_plan = try parser.planAlloc(budget.allocator(), try parser.Source.init("", "cat! ", 10, 0), parameters, &model, &provider);
    defer static_plan.deinit(budget.allocator());
    try std.testing.expectEqual(@as(usize, 1), static_plan.commands.len);
    try std.testing.expect(static_plan.commands[0].isStatic());
    try std.testing.expectEqual(@as(usize, 4), static_plan.commands[0].copy_len);
    try std.testing.expectEqual(@as(usize, 5), static_plan.commands[0].outputLen());
    try std.testing.expectEqual(@as(usize, 5), static_plan.consumed);
}

test "Brotli complete lengths all sixteen aliases retain exact semantic selectors and code zero cache state" {
    const history = "a" ** 32;
    const input = "aaaa";
    const initial: [4]usize = .{ 4, 11, 15, 16 };
    for (0..16) |code| {
        var model: parser.Model = .{};
        for (&model.literal_prices) |*row| @memset(row, 64 * 256);
        @memset(&model.command_prices, 64 * 256);
        @memset(&model.distance_prices, 64 * 256);
        model.command_prices[130] = 256;
        model.distance_prices[code] = 0;
        const source = try parser.Source.init(history, input, 10, history.len);
        const parameters = try parser.Parameters.init(.{ .copy_lengths = .complete, .parse_mode = .whole_block, .beam_width = 32 }, 10, br.PlannedMode.generic);
        const plan = try parser.planAlloc(a, source, parameters, &model, null);
        defer plan.deinit(a);
        try std.testing.expectEqual(@as(usize, 1), plan.commands.len);
        try std.testing.expectEqual(code, plan.commands[0].hq_encoding.?.distance_code);
        try std.testing.expectEqual(@as(u16, 130), plan.commands[0].hq_encoding.?.command_symbol);
        try std.testing.expectEqual(@as(u64, 256), plan.estimated_cost);
        try h.replayWithHistory(a, history, input, initial, plan);
    }
}

test "Brotli complete lengths public APIs preserve format sampled wire guard and q11 ordering in both parse modes" {
    const chunks = [_][]const u8{ h.plain[0..17], h.plain[17..31], h.plain[31..] };
    for ([_]bool{ false, true }) |large| {
        for ([_]@TypeOf((br.HqOptions{}).parse_mode){ .bounded, .whole_block }) |mode| {
            var profile: br.HqProfile = .{};
            var options: br.PlannedEncodeOptions = .{ .quality = 10, .large_window = large, .window_bits = if (large) 25 else 16, .hq = .{ .copy_lengths = .complete, .parse_mode = mode, .beam_width = 2, .iterations = 1, .profile = &profile, .block_len = 128 } };
            const complete10 = try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, options);
            defer a.free(complete10);
            try std.testing.expect(profile.complete_length_passes > 0);
            try std.testing.expect(profile.max_plan_price_evaluations > 0);
            try std.testing.expect(profile.price_evaluations > profile.max_plan_price_evaluations);
            try std.testing.expectEqual(.complete, profile.effective.?.copy_lengths);
            try std.testing.expectEqual(mode, profile.effective.?.parse_mode);
            try std.testing.expectEqual(if (large) @as(u5, 25) else 16, if (large) try h.extensionWindow(complete10) else try h.ordinaryWindow(complete10));
            options.hq.?.profile = null;
            const unprofiled = try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, options);
            defer a.free(unprofiled);
            try std.testing.expectEqualSlices(u8, complete10, unprofiled);
            options.hq.?.copy_lengths = .sampled;
            const sampled10 = try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, options);
            defer a.free(sampled10);
            try std.testing.expect(complete10.len <= sampled10.len);
            options.hq.?.copy_lengths = .complete;
            options.quality = 11;
            const complete11 = try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, options);
            defer a.free(complete11);
            try std.testing.expect(complete11.len <= complete10.len);
            const stream: br.PlannedStreamChunksOptions = .{ .quality = 10, .large_window = large, .window_bits = options.window_bits.?, .hq = options.hq };
            const joined = try br.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, stream);
            defer a.free(joined);
            try std.testing.expectEqualSlices(u8, complete10, joined);
            var reusable = br.PlannedStreamEncoder.init(a);
            defer reusable.deinit();
            const reused = try reusable.encodeChunksWithOptionsAlloc(a, &chunks, stream);
            defer a.free(reused);
            try std.testing.expectEqualSlices(u8, complete10, reused);
            var incremental = br.IncrementalPlannedStreamEncoder.initWithOptions(a, .{ .stream = stream, .block_len = 0 });
            defer incremental.deinit();
            const fragmented = try h.drive(a, &incremental, h.plain, 1, 1);
            defer a.free(fragmented);
            try std.testing.expectEqualSlices(u8, complete10, fragmented);
            const decoded = try br.decodeStreamAllocWithOptions(a, complete10, .{ .allow_large_window = large });
            defer a.free(decoded);
            try std.testing.expectEqualSlices(u8, h.plain, decoded);
        }
    }
}
