const std = @import("std");
const oracle = @import("sequence_costs_tests/oracle.zig");

fn compare(comptime Prices: type, model: *const Prices.EntropyModel, literals: usize, match: usize, offset: u32) !void {
    const before = model.*;
    const old = oracle.freeze(Prices, model.*);
    const expected = old.sequencePrice(literals, match, offset);
    const actual = model.sequenceCosts(literals, match, offset);
    if (expected) |total| {
        const costs = try actual;
        const ll = try oracle.Old.literalSymbol(literals);
        const ml = try oracle.Old.matchSymbol(match);
        const of = try oracle.Old.offsetSymbol(offset);
        const literal = old.ll_prices[ll.code] + @as(u32, ll.extra_bits) * oracle.Old.scale;
        const matched = old.ml_prices[ml.code] + @as(u32, ml.extra_bits) * oracle.Old.scale;
        const penalty: u32 = if (old.penalize_long_offsets and of.code >= 20) (@as(u32, of.code) - 19) * 2 * oracle.Old.scale else 0;
        const remaining = old.of_prices[of.code] + @as(u32, of.extra_bits) * oracle.Old.scale + penalty;
        try std.testing.expectEqual(total, costs.total);
        try std.testing.expectEqual(total, try model.sequencePrice(literals, match, offset));
        try std.testing.expectEqual(literal, costs.literal);
        try std.testing.expectEqual(matched, costs.match);
        try std.testing.expectEqual(remaining, costs.total - costs.literal - costs.match);
    } else |err| {
        try std.testing.expectError(err, actual);
        try std.testing.expectError(err, model.sequencePrice(literals, match, offset));
    }
    try std.testing.expectEqualDeep(before, model.*);
}

fn boundaries(comptime Prices: type, model: *const Prices.EntropyModel) !usize {
    var count: usize = 0;
    for (oracle.Old.ll_bases, oracle.Old.ll_bits, 0..) |base, bits, code| {
        const upper: usize = @as(usize, base) + (@as(usize, 1) << @intCast(bits)) - 1;
        for ([_]usize{ base -| 1, base, base + 1, upper -| 1, upper, upper + 1 }) |literal| {
            try compare(Prices, model, literal, 3 + code % 32, if (code & 1 == 0) 1 else std.math.maxInt(u32));
            count += 1;
        }
    }
    for (oracle.Old.ml_bases, oracle.Old.ml_bits, 0..) |base, bits, code| {
        const upper: usize = @as(usize, base) + (@as(usize, 1) << @intCast(bits)) - 1;
        for ([_]usize{ base - 1, base, base + 1, upper - 1, upper, upper + 1 }) |match| {
            try compare(Prices, model, if (code & 1 == 0) 0 else 131071, match, if (code & 1 == 0) 7 else @as(u32, 1) << 20);
            count += 1;
        }
    }
    for (0..32) |bit| {
        const value = @as(u32, 1) << @intCast(bit);
        for ([_]u32{ value - 1, value, value + 1 }) |offset| {
            try compare(Prices, model, bit, 3 + bit, offset);
            count += 1;
        }
    }
    for ([_]usize{ 0, 131071, 131072 }) |literal| {
        for ([_]usize{ 3, 131074, 131075 }) |match| {
            for ([_]u32{ 0, 1, std.math.maxInt(u32) }) |offset| {
                try compare(Prices, model, literal, match, offset);
                count += 1;
            }
        }
    }
    try std.testing.expectEqual(@as(usize, 657), count);
    return count;
}

pub fn check(comptime Prices: type) !void {
    var models: [3]Prices.EntropyModel = @splat(.{});
    models[1].literal_prices = @splat(0);
    models[1].ll_prices = @splat(0);
    models[1].ml_prices = @splat(0);
    models[1].of_prices = @splat(0);
    models[1].origin = .dictionary;
    models[1].initialized = true;
    models[2].literal_prices = @splat(Prices.maximum_symbol_price);
    models[2].ll_prices = @splat(Prices.maximum_symbol_price);
    models[2].ml_prices = @splat(Prices.maximum_symbol_price);
    models[2].of_prices = @splat(Prices.maximum_symbol_price);
    models[2].penalize_long_offsets = true;
    models[2].origin = .refined;
    models[2].initialized = true;
    var count: usize = 0;
    for (&models) |*model| {
        try model.validate();
        try oracle.verifyMapping(Prices, model.*);
        count += try boundaries(Prices, model);
    }
    var fractional: Prices.EntropyModel = .{};
    fractional.literal_prices = @splat(257);
    fractional.ll_prices = @splat(257);
    fractional.ml_prices = @splat(257);
    fractional.of_prices = @splat(257);
    const before = fractional;
    const integer = try fractional.forStrategy(.btopt);
    const ultra = try fractional.forStrategy(.btultra);
    try std.testing.expectEqualDeep(before, fractional);
    try std.testing.expectEqual(@as(u32, 512), integer.ll_prices[0]);
    try std.testing.expectEqual(@as(u32, 257), ultra.ll_prices[0]);
    for ([_]u5{ 19, 20, 31 }) |bit| {
        const offset = @as(u32, 1) << bit;
        for ([_]usize{ 0, 131071 }) |literal| {
            try compare(Prices, &integer, literal, 131074, offset);
            try compare(Prices, &ultra, literal, 131074, offset);
            count += 2;
        }
    }
    const costs = comptime blk: {
        @setEvalBranchQuota(40_000);
        const model: Prices.EntropyModel = .{};
        break :blk model.sequenceCosts(0, 3, 1) catch @compileError("sequenceCosts must remain a pure allocator-free operation");
    };
    try std.testing.expect(costs.total >= costs.literal + costs.match);
    std.debug.print("sequence costs independent oracle: models=3, boundaries_per_model=657, comparisons={d}\n", .{count});
}
