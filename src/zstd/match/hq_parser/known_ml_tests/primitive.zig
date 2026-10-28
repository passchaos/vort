const std = @import("std");
const m = @import("models.zig");
const p = m.prices;
const rep = @import("../rep.zig");

fn equal(expected: anytype, actual: anytype) !void {
    if (expected) |value| try std.testing.expectEqual(value, try actual) else |err| try std.testing.expectError(err, actual);
}
pub fn contracts(comptime Codec: type) !void {
    const models = m.fixtures();
    for (models) |model| {
        try model.validate();
        const old = m.freeze(model);
        for (p.ml_bases, p.ml_bits, 0..) |base, bits, code| {
            const lower: usize = base;
            const upper = lower + (@as(usize, 1) << @intCast(bits)) - 1;
            for ([_]usize{ lower, upper }) |length| {
                const symbol = try m.Old.matchSymbol(length);
                try std.testing.expectEqual(@as(u8, @intCast(code)), symbol.code);
                try std.testing.expectEqual(bits, symbol.extra_bits);
                for (p.ll_bases, p.ll_bits) |ll_base, ll_bits| {
                    for ([_]usize{ ll_base, @as(usize, ll_base) + (@as(usize, 1) << @intCast(ll_bits)) - 1 }) |literal_len| {
                        for ([_]u32{ 1, 2, 3, 4, 7, 1 << 19, 1 << 20, std.math.maxInt(u32) }) |offset|
                            try equal(old.sequencePrice(literal_len, length, offset), Codec.sequencePrice(&model, literal_len, length, offset, @intCast(code)));
                    }
                }
                for ([_]usize{ 131072, std.math.maxInt(u32) }) |invalid_ll| {
                    try std.testing.expectError(error.InvalidBlockPlan, Codec.sequencePrice(&model, invalid_ll, length, 1, @intCast(code)));
                    try std.testing.expectError(error.InvalidBlockPlan, Codec.sequencePrice(&model, invalid_ll, length, 0, @intCast(code)));
                }
                try std.testing.expectError(error.InvalidBlockPlan, Codec.sequencePrice(&model, 0, length, 0, @intCast(code)));
            }
        }
        for ([_]u32{ 0, 1, 131071 }) |literal_len| {
            const choices = try rep.choices(literal_len, 8, .{ 9, 8, 8 });
            for (choices.slice()) |choice|
                try equal(old.sequencePrice(literal_len, 66, choice.offset_value), Codec.sequencePrice(&model, literal_len, 66, choice.offset_value, 39));
        }
    }
    // Maximum legal symbol prices/extras plus btopt offset penalty still fit
    // u32. This bound does not grant permission to skip model validation.
    const maximum = models[6];
    const price = try Codec.sequencePrice(&maximum, 131071, 131074, std.math.maxInt(u32), 52);
    try std.testing.expectEqual(@as(u32, 71424), price);
}
