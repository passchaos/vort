const std = @import("std");
const prices = @import("prices.zig");
const rep = @import("rep.zig");

test "Zstd HQ price symbols match independent range oracle at all format boundaries" {
    for (prices.ll_bases, prices.ll_bits, 0..) |base, bits, code| {
        const top = base + (@as(u32, 1) << @intCast(bits)) - 1;
        for ([_]u32{ base, top }) |length| {
            const symbol = try prices.literalSymbol(length);
            try std.testing.expectEqual(@as(u8, @intCast(code)), symbol.code);
            try std.testing.expectEqual(bits, symbol.extra_bits);
            try std.testing.expectEqual(length, base + symbol.extra_value);
        }
    }
    for (prices.ml_bases, prices.ml_bits, 0..) |base, bits, code| {
        const top = base + (@as(u32, 1) << @intCast(bits)) - 1;
        for ([_]u32{ base, top }) |length| {
            const symbol = try prices.matchSymbol(length);
            try std.testing.expectEqual(@as(u8, @intCast(code)), symbol.code);
            try std.testing.expectEqual(bits, symbol.extra_bits);
            try std.testing.expectEqual(length, base + symbol.extra_value);
        }
    }
    try std.testing.expectError(error.InvalidBlockPlan, prices.literalSymbol(131072));
    try std.testing.expectError(error.InvalidBlockPlan, prices.matchSymbol(2));
    for (0..32) |bits| {
        const value = @as(u32, 1) << @intCast(bits);
        const symbol = try prices.offsetSymbol(value);
        try std.testing.expectEqual(@as(u8, @intCast(bits)), symbol.code);
        try std.testing.expectEqual(@as(u8, @intCast(bits)), symbol.extra_bits);
        try std.testing.expectEqual(@as(u32, 0), symbol.extra_value);
    }
}

test "Zstd HQ repeated offsets preserve all literal zero selectors and direct choices" {
    const repeats: rep.Repeats = .{ 5, 9, 17 };
    const positive = [_]rep.Repeats{ .{ 5, 9, 17 }, .{ 9, 5, 17 }, .{ 17, 5, 9 } };
    const zero = [_]rep.Repeats{ .{ 9, 5, 17 }, .{ 17, 5, 9 }, .{ 4, 5, 9 } };
    for ([_]u32{ 1, 2, 3 }, 0..) |value, i| {
        const a = try rep.resolve(1, value, repeats);
        const b = try rep.resolve(0, value, repeats);
        try std.testing.expectEqual(positive[i], a.repeats);
        try std.testing.expectEqual(zero[i], b.repeats);
        try std.testing.expectEqual(positive[i][0], a.distance);
        try std.testing.expectEqual(zero[i][0], b.distance);
    }
    try std.testing.expectError(error.InvalidBlockPlan, rep.resolve(0, 3, .{ 1, 4, 8 }));
    const direct = try rep.resolve(0, 103, repeats);
    try std.testing.expectEqual(@as(usize, 100), direct.distance);
    try std.testing.expectEqual(rep.Repeats{ 100, 5, 9 }, direct.repeats);
    const alternatives = try rep.choices(1, 4, .{ 4, 4, 8 });
    try std.testing.expectEqual(@as(usize, 3), alternatives.len);
    try std.testing.expectEqual(@as(u32, 1), alternatives.items[0].offset_value);
    try std.testing.expectEqual(@as(u32, 2), alternatives.items[1].offset_value);
    try std.testing.expectEqual(@as(u32, 7), alternatives.items[2].offset_value);
    try std.testing.expectEqual(rep.Repeats{ 4, 4, 4 }, alternatives.items[2].repeats);
}

test "Zstd HQ entropy model uses actual symbol prices and selected pass statistics" {
    var model: prices.EntropyModel = .{};
    try std.testing.expectEqual(@as(u32, 2 * prices.scale), prices.probabilityPrice(2, 8));
    model.ll_prices[0] = 2 * prices.scale;
    model.ml_prices[0] = 3 * prices.scale;
    model.of_prices[0] = 7 * prices.scale;
    try std.testing.expectEqual(@as(u32, 12 * prices.scale), try model.sequencePrice(0, 3, 1));
    var statistics: prices.Statistics = .{};
    statistics.addLiterals("aaaaaaaaaaaaaaaaaaaaab");
    try statistics.addSequence(0, 3, 1);
    const refined = model.refined(&statistics);
    try std.testing.expect(refined.initialized);
    try std.testing.expect(refined.literal_prices['a'] < refined.literal_prices['b']);
    try std.testing.expect(refined.ll_prices[0] != model.ll_prices[0]);
    try std.testing.expect(refined.of_prices[0] != model.of_prices[0]);
}

test "Zstd HQ btopt effective prices round integers and penalize exact long offset symbols" {
    var model: prices.EntropyModel = .{};
    model.literal_prices = @splat(257);
    model.ll_prices = @splat(257);
    model.ml_prices = @splat(257);
    model.of_prices = @splat(257);
    const integer = try model.forStrategy(.btopt);
    const fractional = try model.forStrategy(.btultra);
    try std.testing.expectEqual(@as(u32, 512), integer.literal_prices[0]);
    try std.testing.expectEqual(@as(u32, 257), fractional.literal_prices[0]);
    for ([_]u5{ 19, 20, 31 }) |bits| {
        const value = @as(u32, 1) << bits;
        const penalty: u32 = if (bits >= 20) (@as(u32, bits) - 19) * 2 * prices.scale else 0;
        try std.testing.expectEqual(@as(u32, 3 * 512) + @as(u32, bits) * prices.scale + penalty, try integer.sequencePrice(0, 3, value));
        try std.testing.expectEqual(@as(u32, 3 * 257) + @as(u32, bits) * prices.scale, try fractional.sequencePrice(0, 3, value));
        const direct = try rep.resolve(0, value, rep.initial_repeats);
        try std.testing.expectEqual(@as(usize, value - 3), direct.distance);
    }
    model.of_prices[31] = prices.maximum_symbol_price;
    const unknown = try model.forStrategy(.btopt);
    try unknown.validate();
    try std.testing.expectEqual(prices.maximum_symbol_price, unknown.of_prices[31]);
    try std.testing.expectEqual(@as(u32, 2 * 512) + prices.maximum_symbol_price + 55 * prices.scale, try unknown.sequencePrice(0, 3, @as(u32, 1) << 31));
}

test "Zstd HQ btopt effective fractional trap changes actual parse with exact repeat value" {
    const hq = @import("../hq_parser.zig");
    const source = hq.Source.init("abc", "", "abc", 1024);
    var model: prices.EntropyModel = .{};
    model.literal_prices = @splat(prices.scale);
    model.ll_prices = @splat(prices.maximum_symbol_price);
    model.ml_prices = @splat(prices.maximum_symbol_price);
    model.of_prices = @splat(prices.maximum_symbol_price);
    model.ll_prices[0] = 257;
    model.ml_prices[0] = 257;
    model.of_prices[0] = 1;
    const initial: rep.Repeats = .{ 3, 3, 8 };
    const fractional = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = .btultra, .entropy = &model, .initial_repeated_offsets = initial });
    defer fractional.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), fractional.records.len);
    try std.testing.expectEqual(@as(u64, 515), fractional.estimated_cost);
    try std.testing.expectEqual(@as(?usize, 1), fractional.records[0].offset_value);
    const choice = try rep.resolve(0, fractional.offset_values[0], initial);
    try std.testing.expectEqual(@as(usize, 3), choice.distance);
    try std.testing.expectEqual(choice.repeats, fractional.final_repeated_offsets);
    const integer = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = .btopt, .entropy = &model, .initial_repeated_offsets = initial });
    defer integer.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), integer.records.len);
    try std.testing.expectEqual(@as(u64, 3 * prices.scale), integer.estimated_cost);
    try std.testing.expectEqual(initial, integer.final_repeated_offsets);
    const decoded = try @import("lazy2_tests.zig").replay(std.testing.allocator, source, fractional, initial);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, source.block, decoded);
}
