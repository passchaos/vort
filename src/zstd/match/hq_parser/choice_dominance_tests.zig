const std = @import("std");
const Codec = @import("choice_dominance.zig");
const rep = @import("rep.zig");
const models = @import("known_ml_tests/models.zig");
const edges = @import("search_edges.zig");
const h = @import("row_tags_tests/edges/helpers.zig");

fn same(left: rep.Repeats, right: rep.Repeats) bool {
    return std.mem.eql(usize, &left, &right);
}

test "Zstd HQ choice dominance preserves complete prices successor histories and first ties" {
    const values = [_]usize{ 1, 2, 4, 7, 257, 65536, (1 << 20) + 4 };
    for (models.fixtures()) |model| {
        const reference = models.freeze(model);
        for (values) |first| for (values) |second| for (values) |third| {
            for ([_]usize{ 0, 1, 16, 131071 }) |literals| {
                for (values) |distance| {
                    const choices = try rep.choices(literals, distance, .{ first, second, third });
                    const mask = Codec.materializeMask(&choices, &model);
                    try std.testing.expect(mask != 0);
                    for (choices.slice(), 0..) |choice, slot| {
                        if (mask & (@as(u8, 1) << @intCast(slot)) != 0) continue;
                        var found = false;
                        for (choices.slice(), 0..) |winner, winner_slot| {
                            if (mask & (@as(u8, 1) << @intCast(winner_slot)) == 0 or !same(choice.repeats, winner.repeats)) continue;
                            for ([_]usize{ 3, 17, 66, 131, 131074 }) |length| {
                                const old = try reference.sequencePrice(literals, length, choice.offset_value);
                                const current = try reference.sequencePrice(literals, length, winner.offset_value);
                                try std.testing.expect(current <= old);
                                if (current == old) try std.testing.expect(winner.offset_value < choice.offset_value);
                            }
                            found = true;
                            break;
                        }
                        try std.testing.expect(found);
                    }
                    if (comptime @hasDecl(Codec, "compact")) {
                        var compacted = choices;
                        Codec.compact(&compacted, &model);
                        var kept: usize = 0;
                        for (choices.slice(), 0..) |choice, slot| {
                            if (mask & (@as(u8, 1) << @intCast(slot)) == 0) continue;
                            try std.testing.expectEqualDeep(choice, compacted.items[kept]);
                            kept += 1;
                        }
                        try std.testing.expectEqual(kept, compacted.len);
                    }
                }
            }
        };
    }
}

const Sorted = struct {
    pub const Context = edges.SortedContext;
    pub const Spill = edges.Spill;
    pub const choice_pruning = true;
    pub const allow_price_reduction = true;
};
const Legacy = struct {
    pub const Context = edges.SortedContext;
    pub const Spill = edges.Spill;
};

test "Zstd HQ choice dominance preserves nodes tags spills and every finite quota prefix" {
    var model = models.fixtures()[1];
    // A cheaper direct encoding is visited last in the original alias group.
    model.of_prices = @splat(models.prices.maximum_symbol_price);
    model.of_prices[2] = 0;
    inline for (.{ false, true }) |whole| inline for (.{ false, true }) |complete| {
        for ([_]usize{ 1, 8, 16 }) |width| for ([_]bool{ false, true }) |tagged| {
            for ([_]usize{ 3, 14, 15, 16, 17, 67 }) |maximum| {
                const options: h.Case = .{ .maximum = maximum, .literal_len = 0, .repeats = .{ 4, 4, 4 }, .distance = 4, .entropy = &model, .prefix_unit = model.literal_prices[0], .tagged = tagged, .goal = if (!whole and complete and maximum > 15) 12 else null };
                const old = try h.compare(Legacy, whole, complete, width, options);
                const current = try h.compare(Sorted, whole, complete, width, options);
                if (maximum >= 16) try std.testing.expect(current.profile.price_evaluations < old.profile.price_evaluations);
                if (maximum == 16) for (0..@as(usize, @intCast(old.admitted + 2))) |quota| {
                    var limited = options;
                    limited.limit = quota;
                    const actual = try h.compare(Sorted, whole, complete, width, limited);
                    const expected: ?anyerror = if (quota < old.admitted) error.SearchLimitExceeded else null;
                    try std.testing.expectEqual(expected, actual.failure);
                };
            }
        };
    };
}

test "Zstd HQ choice dominance leaves generic contexts and error guards unchanged" {
    const Generic = struct {
        pub const Context = edges.Context;
        pub const Spill = edges.Spill;
        pub const choice_pruning = true;
    };
    inline for (.{ false, true }) |whole| inline for (.{ false, true }) |complete| {
        _ = try h.compare(Generic, whole, complete, 8, .{ .repeats = .{ 4, 4, 4 }, .distance = 4, .maximum = 67 });
        for ([_]h.Case{
            .{ .minimum = 2, .maximum = 16 },
            .{ .literal_len = 131072, .maximum = 16 },
            .{ .maximum = 131075, .limit = 1 },
            .{ .cost = std.math.maxInt(u64), .maximum = 16 },
            .{ .admitted = std.math.maxInt(u64), .maximum = 16 },
        }) |case| _ = try h.compare(Sorted, whole, complete, 1, case);
        // A custom prefix never receives the validated-DP opt-in. Preserve
        // its original later-alias overflow even when the cheapest edge fits.
        if (!whole and complete) _ = try h.compare(Legacy, whole, complete, 1, .{ .maximum = 16, .goal = 8, .prefix_tail = std.math.maxInt(u64), .cost = std.math.maxInt(u64) - 20000 });
    };
}

test "Zstd HQ choice dominance legacy beam measured allowance preserves exact finite quota" {
    const parser = @import("../hq_parser.zig");
    const source = parser.Source.init("", "", "abcd" ** 64, 1024);
    var profile: @import("../../encode/controls.zig").Profile = .{};
    var parameters: parser.Parameters = .{ .strategy = .btopt, .profile = &profile, .hq_options = .{ .parser_engine = .beam } };
    const a = std.testing.allocator;
    const original = try parser.planAlloc(a, source, parameters);
    defer original.deinit(a);
    const cap = profile.max_plan_price_evaluations;
    try std.testing.expect(profile.price_evaluations < cap);
    parameters.hq_options.max_price_evaluations = cap;
    profile.reset();
    const exact = try parser.planAlloc(a, source, parameters);
    defer exact.deinit(a);
    try std.testing.expectEqualDeep(original.records, exact.records);
    try std.testing.expectEqualDeep(original.offset_values, exact.offset_values);
    try std.testing.expectEqual(original.estimated_cost, exact.estimated_cost);
    try std.testing.expectEqual(cap, profile.max_plan_price_evaluations);
    parameters.hq_options.max_price_evaluations = cap - 1;
    try std.testing.expectError(error.SearchLimitExceeded, parser.planAlloc(a, source, parameters));
}
