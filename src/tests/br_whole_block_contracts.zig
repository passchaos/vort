const std = @import("std");
const br = @import("../br.zig");
const parser = @import("../br/encoder/hq_parser.zig");
const h = @import("br_whole_block_helpers.zig");
const a = std.testing.allocator;

test "Brotli whole block default bounded policy preserves archived small complete wires for all quality controls" {
    const chunks = [_][]const u8{ h.plain[0..17], h.plain[17..31], h.plain[31..] };
    for (h.frozen_wires) |sample| {
        const expected = try h.frozenAlloc(a, sample);
        defer a.free(expected);
        var one = h.options(br.PlannedEncodeOptions, sample.setting);
        var stream = h.options(br.PlannedStreamChunksOptions, sample.setting);
        if (one.hq) |*hq| hq.parse_mode = .bounded;
        if (stream.hq) |*hq| hq.parse_mode = .bounded;
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

test "Brotli whole block 4098 independent cost witness reaches 32792 and retains exact selector in actual wire" {
    const input = try h.boundaryInput(a);
    defer a.free(input);
    var model: parser.Model = .{};
    for (&model.literal_prices) |*row| @memset(row, 8 * 256);
    @memset(&model.command_prices, 64 * 256);
    model.command_prices[488] = 256;
    model.command_prices[144] = 256;
    @memset(&model.distance_prices, 64 * 256);
    model.distance_prices[36] = 0;
    const source = try parser.Source.init("", input, 13, 0);
    var profile: br.HqProfile = .{};
    const bounded_parameters = try parser.Parameters.init(.{ .profile = &profile }, 10, br.PlannedMode.generic);
    const bounded = try parser.planAlloc(a, source, bounded_parameters, &model, null);
    defer bounded.deinit(a);
    try std.testing.expectEqual(@as(u64, 32792 * 256), h.boundaryMinimumCost(input) * 256);
    try std.testing.expectEqual(@as(u64, 32793 * 256), bounded.estimated_cost);
    try h.replayLzPlan(a, input, bounded);
    profile.reset();
    const full_parameters = try parser.Parameters.init(.{ .parse_mode = .whole_block, .profile = &profile }, 10, br.PlannedMode.generic);
    const whole = try parser.planAlloc(a, source, full_parameters, &model, null);
    defer whole.deinit(a);
    try std.testing.expectEqual(@as(u64, 32792 * 256), whole.estimated_cost);
    try std.testing.expectEqual(input.len, whole.consumed);
    try std.testing.expectEqual(@as(u64, 1), profile.whole_block_passes);
    try std.testing.expectEqual(@as(u64, 0), profile.bounded_passes);
    try std.testing.expectEqual(input.len, profile.max_parse_positions);
    try h.replayLzPlan(a, input, whole);
    try std.testing.expectEqual(@as(usize, 1), whole.commands.len);
    const selected = whole.commands[0].hq_encoding orelse return error.TestUnexpectedResult;
    const wire = try br.IncrementalTestSupport.encodeHqCommandPlan(a, input, whole.commands, .{ .window_bits = 13 });
    defer a.free(wire.bytes);
    const actual = try h.singleCommandWire(wire.bytes, .{ 4, 11, 15, 16 });
    try std.testing.expectEqual(@as(usize, selected.command_symbol), actual.command_symbol);
    try std.testing.expectEqual(@as(usize, 36), actual.distance_symbol.?);
    try std.testing.expectEqual(whole.commands[0].insert_len, actual.insert_len);
    try std.testing.expectEqual(whole.commands[0].distance, actual.distance);
    const decoded = try br.decodeStreamAlloc(a, wire.bytes);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Brotli whole block finite exhaustive tiny paths match with sufficient beam without global beam claims" {
    var model: parser.Model = .{};
    for (&model.literal_prices) |*row| @memset(row, 8 * 256);
    @memset(&model.command_prices, 3 * 256);
    @memset(&model.distance_prices, 2 * 256);
    for ([_][]const u8{ "", "x", "xy", "abcd", "abcdab", "ababab" }) |input| {
        const history = "abcd";
        const source = try parser.Source.init(history, input, 10, history.len);
        const expected = h.finiteCost(history, input, &model, 0, 0, .{ 4, 11, 15, 16 });
        const parameters = try parser.Parameters.init(.{ .parse_mode = .whole_block, .beam_width = 32 }, 10, br.PlannedMode.generic);
        const plan = try parser.planAlloc(a, source, parameters, &model, null);
        defer plan.deinit(a);
        try std.testing.expectEqual(expected, plan.estimated_cost);
        try h.replayWithHistory(a, history, input, .{ 4, 11, 15, 16 }, plan);
    }
}

test "Brotli whole block all sixteen independently priced aliases retain semantic zero and cache order" {
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
        const parameters = try parser.Parameters.init(.{ .parse_mode = .whole_block, .beam_width = 32 }, 10, br.PlannedMode.generic);
        const source = try parser.Source.init(history, input, 10, history.len);
        const plan = try parser.planAlloc(a, source, parameters, &model, null);
        defer plan.deinit(a);
        try std.testing.expectEqual(@as(usize, 1), plan.commands.len);
        try std.testing.expectEqual(@as(u64, 256), plan.estimated_cost);
        try std.testing.expectEqual(code, plan.commands[0].hq_encoding.?.distance_code);
        try std.testing.expectEqual(@as(u16, 130), plan.commands[0].hq_encoding.?.command_symbol);
        try std.testing.expectEqual(h.shortDistance(initial, @intCast(code)).?, plan.commands[0].distance);
        try h.replayWithHistory(a, history, input, initial, plan);
    }
}

test "Brotli whole block public mode reaches complete span in standard large and reusable fragmented APIs" {
    const input = try h.boundaryInput(a);
    defer a.free(input);
    const chunks = [_][]const u8{ input[0..17], input[17..4097], input[4097..] };
    for ([_]bool{ false, true }) |large| {
        var profile: br.HqProfile = .{};
        const options: br.PlannedStreamChunksOptions = .{
            .quality = 10,
            .large_window = large,
            .window_bits = if (large) 25 else 13,
            .hq = .{ .parse_mode = .whole_block, .beam_width = 2, .iterations = 1, .block_len = input.len, .profile = &profile },
        };
        const expected = try br.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, options);
        defer a.free(expected);
        try std.testing.expect(profile.whole_block_passes > 0);
        try std.testing.expect(profile.bounded_passes > 0);
        try std.testing.expectEqual(input.len, profile.max_parse_positions);
        try std.testing.expectEqual(.whole_block, profile.effective.?.parse_mode);
        try std.testing.expectEqual(if (large) @as(u5, 25) else 13, if (large) try h.extensionWindow(expected) else try h.ordinaryWindow(expected));
        var unprofiled = options;
        unprofiled.hq.?.profile = null;
        const plain = try br.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, unprofiled);
        defer a.free(plain);
        try std.testing.expectEqualSlices(u8, expected, plain);
        const one = try br.encodePlannedStreamWithOptionsAlloc(a, input, .{
            .quality = 10,
            .large_window = large,
            .window_bits = options.window_bits,
            .hq = unprofiled.hq,
        });
        defer a.free(one);
        try std.testing.expectEqualSlices(u8, expected, one);
        var reusable = br.PlannedStreamEncoder.init(a);
        defer reusable.deinit();
        const owned = try reusable.encodeChunksWithOptionsAlloc(a, &chunks, unprofiled);
        defer a.free(owned);
        try std.testing.expectEqualSlices(u8, expected, owned);
        var incremental = br.IncrementalPlannedStreamEncoder.initWithOptions(a, .{ .stream = unprofiled, .block_len = 0 });
        defer incremental.deinit();
        const fragmented = try h.drive(a, &incremental, input, 1, 1);
        defer a.free(fragmented);
        try std.testing.expectEqualSlices(u8, expected, fragmented);
        const decoded = try br.decodeStreamAllocWithOptions(a, expected, .{ .allow_large_window = large });
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "Brotli whole block public complete wire preserves bounded guard and q11 q10 ordering" {
    const input = "whole search abcdefghabcdefghXabcdefgh dictionary tail\n" ** 4;
    for ([_]bool{ false, true }) |large| {
        var options: br.PlannedEncodeOptions = .{ .quality = 10, .large_window = large, .window_bits = if (large) 25 else 16, .hq = .{ .beam_width = 2, .iterations = 1 } };
        const bounded10 = try br.encodePlannedStreamWithOptionsAlloc(a, input, options);
        defer a.free(bounded10);
        options.hq.?.parse_mode = .whole_block;
        const whole10 = try br.encodePlannedStreamWithOptionsAlloc(a, input, options);
        defer a.free(whole10);
        try std.testing.expect(whole10.len <= bounded10.len);
        options.quality = 11;
        const whole11 = try br.encodePlannedStreamWithOptionsAlloc(a, input, options);
        defer a.free(whole11);
        try std.testing.expect(whole11.len <= whole10.len);
        options.hq.?.parse_mode = .bounded;
        const bounded11 = try br.encodePlannedStreamWithOptionsAlloc(a, input, options);
        defer a.free(bounded11);
        try std.testing.expect(whole11.len <= bounded11.len);
    }
}
