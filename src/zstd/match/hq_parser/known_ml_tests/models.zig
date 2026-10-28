const std = @import("std");
pub const prices = @import("../prices.zig");
pub const Old = @import("../prices_known_ml_reference.zig");

pub fn fixtures() [7]prices.EntropyModel {
    var result: [7]prices.EntropyModel = @splat(.{});
    result[1].origin = .dictionary;
    result[1].initialized = true;
    result[2].origin = .previous_block;
    result[2].initialized = true;
    result[3].origin = .refined;
    result[3].initialized = true;
    result[4].penalize_long_offsets = true;
    result[5].ll_prices = @splat(0);
    result[5].ml_prices = @splat(0);
    result[5].of_prices = @splat(0);
    result[6].ll_prices = @splat(prices.maximum_symbol_price);
    result[6].ml_prices = @splat(prices.maximum_symbol_price);
    result[6].of_prices = @splat(prices.maximum_symbol_price);
    result[6].penalize_long_offsets = true;
    for (result[1..5], 1..) |*model, seed| {
        for (&model.ll_prices, 0..) |*price, index| price.* = @intCast((index * 53 + seed * 257) % 16385);
        for (&model.ml_prices, 0..) |*price, index| price.* = @intCast((index * 97 + seed * 131) % 16385);
        for (&model.of_prices, 0..) |*price, index| price.* = @intCast((index * 31 + seed * 19) % 16385);
    }
    return result;
}
pub fn freeze(model: prices.EntropyModel) Old.EntropyModel {
    var old: Old.EntropyModel = .{};
    inline for (comptime std.meta.fieldNames(prices.EntropyModel)) |field| {
        if (comptime std.mem.eql(u8, field, "origin")) {
            old.origin = @enumFromInt(@intFromEnum(model.origin));
        } else @field(old, field) = @field(model, field);
    }
    return old;
}
