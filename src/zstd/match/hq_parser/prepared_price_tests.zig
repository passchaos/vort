const std = @import("std");
const Codec = @import("prepared_price.zig");
const models = @import("known_ml_tests/models.zig");
const prices = models.prices;
const edges = @import("search_edges.zig");
const h = @import("row_tags_tests/edges/helpers.zig");

const Sorted = struct {
    pub const Spill = edges.Spill;
    pub const Context = edges.SortedContext;
};

test "Zstd HQ prepared LL OF prices preserve full ML range and offset penalties" {
    for (models.fixtures()) |model| {
        try model.validate();
        const old = models.freeze(model);
        var ordinary: Codec.ForChoice = .{ .literal_len = 16, .offset_value = (1 << 20) + 3 };
        var known: Codec.ForChoice = ordinary;
        for (3..131075) |length| {
            const expected = try old.sequencePrice(16, length, ordinary.offset_value);
            const symbol = try prices.matchSymbol(length);
            try std.testing.expectEqual(expected, try ordinary.price(false, &model, length, 0));
            try std.testing.expectEqual(expected, try known.price(true, &model, length, symbol.code));
        }
        for (prices.ll_bases, prices.ll_bits) |base, bits| {
            for ([_]usize{ base, @as(usize, base) + (@as(usize, 1) << @intCast(bits)) - 1 }) |literal_len| {
                for ([_]u32{ 1, 2, 3, 10, (1 << 20) + 3, std.math.maxInt(u32) }) |offset| {
                    var memo: Codec.ForChoice = .{ .literal_len = literal_len, .offset_value = offset };
                    for (prices.ml_bases, prices.ml_bits, 0..) |ml_base, ml_bits, code| {
                        const upper = @as(usize, ml_base) + (@as(usize, 1) << @intCast(ml_bits)) - 1;
                        for ([_]usize{ ml_base, upper }) |length| {
                            const expected = try old.sequencePrice(literal_len, length, offset);
                            try std.testing.expectEqual(expected, try memo.price(false, &model, length, 0));
                            try std.testing.expectEqual(expected, try memo.price(true, &model, length, @intCast(code)));
                        }
                    }
                }
            }
        }
    }
}

test "Zstd HQ prepared LL OF prices publish only successful first prices" {
    const model = models.fixtures()[2];
    for ([_]usize{ 0, 1, 2, 131075 }) |length| {
        var memo: Codec.ForChoice = .{ .literal_len = 1, .offset_value = 10 };
        try std.testing.expectError(error.InvalidBlockPlan, memo.price(false, &model, length, 0));
        try std.testing.expectEqual(@as(?u32, null), memo.base);
        _ = try memo.price(false, &model, 3, 0);
        const base = memo.base;
        try std.testing.expectError(error.InvalidBlockPlan, memo.price(false, &model, length, 0));
        try std.testing.expectEqual(base, memo.base);
    }
    for ([_]usize{ 131072, std.math.maxInt(u32) }) |literal_len| {
        var memo: Codec.ForChoice = .{ .literal_len = literal_len, .offset_value = 10 };
        try std.testing.expectError(error.InvalidBlockPlan, memo.price(false, &model, 3, 0));
        try std.testing.expectEqual(@as(?u32, null), memo.base);
    }
    var invalid_offset: Codec.ForChoice = .{ .literal_len = 1, .offset_value = 0 };
    try std.testing.expectError(error.InvalidBlockPlan, invalid_offset.price(false, &model, 3, 0));
    try std.testing.expectEqual(@as(?u32, null), invalid_offset.base);
    const zero = models.fixtures()[5];
    var zero_base: Codec.ForChoice = .{ .literal_len = 0, .offset_value = 1 };
    try std.testing.expectEqual(@as(u32, 0), try zero_base.price(false, &zero, 3, 0));
    try std.testing.expectEqual(@as(?u32, 0), zero_base.base);
    try std.testing.expectEqual(@as(u32, 0), try zero_base.price(true, &zero, 4, 1));
}

test "Zstd HQ prepared LL OF edges preserve gate boundaries choices and quota prefixes" {
    const model = models.fixtures()[4];
    inline for (.{ false, true }) |whole| {
        inline for (.{ false, true }) |complete| {
            for ([_]usize{ 1, 8, 16 }) |width| {
                for ([_]bool{ false, true }) |tagged| {
                    for ([_]usize{ 3, 6, 7, 16, 64, 67 }) |maximum| {
                        const options: h.Case = .{
                            .maximum = maximum,
                            .literal_len = 0,
                            .repeats = .{ 4, 4, 4 },
                            .distance = 4,
                            .entropy = &model,
                            .tagged = tagged,
                            .alias_origin = true,
                            .goal = if (!whole and complete and maximum > 7) 12 else null,
                        };
                        const full = try h.compare(Sorted, whole, complete, width, options);
                        try std.testing.expectEqual(@as(?anyerror, null), full.failure);
                        // These small ranges include every failing admitted
                        // prefix, the exact successful quota and one extra.
                        if (maximum <= 16) {
                            for (0..@as(usize, @intCast(full.admitted + 2))) |limit| {
                                var limited = options;
                                limited.limit = limit;
                                const result = try h.compare(Sorted, whole, complete, width, limited);
                                const expected: ?anyerror = if (limit < full.admitted) error.SearchLimitExceeded else null;
                                try std.testing.expectEqual(expected, result.failure);
                            }
                        }
                    }
                    // In sampled mode the maximum can succeed before a later
                    // invalid short ML; the cached path must still reject it.
                    for ([_]?u64{ null, 0, 1, 2 }) |quota| {
                        _ = try h.compare(Sorted, whole, complete, width, .{
                            .minimum = 2,
                            .maximum = 16,
                            .limit = quota,
                            .tagged = tagged,
                        });
                        _ = try h.compare(Sorted, whole, complete, width, .{
                            .maximum = 16,
                            .literal_len = 131072,
                            .limit = quota,
                            .tagged = tagged,
                        });
                    }
                }
            }
        }
    }
}
