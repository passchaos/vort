const std = @import("std");
const state = @import("../state.zig");
const rep = @import("../rep.zig");
const prices = @import("../prices.zig");
const Profile = @import("../../../encode/controls.zig").Profile;
const models = @import("../known_ml_tests/models.zig");
const oracle = @import("oracle.zig");
const compare = @import("compare.zig");

fn node(model: prices.EntropyModel, literal_len: u32) !state.Node {
    const old = models.freeze(model);
    const ll = if (literal_len <= 131072) try oracle.literalLengthPrice(&old, literal_len) else 0;
    return .{ .cost = @as(u64, ll) + 100_003, .literal_len = literal_len, .repeats = .{ 5, 9, 17 }, .previous_position = 99, .previous_slot = 11, .match_len = 77, .distance = 1234, .offset_value = 9 };
}

fn choice(literals: u32, offset: u32, repeats: rep.Repeats) !rep.Choice {
    return if (offset == 0) .{ .offset_value = 0, .distance = 1, .repeats = repeats } else try rep.resolve(literals, offset, repeats);
}

fn boundaries(comptime Helper: type, metrics: *compare.Metrics) !void {
    const all_models = models.fixtures();
    for (all_models, 0..) |model, seed| {
        for (prices.ll_bases, prices.ll_bits, 0..) |base, bits, code| {
            const upper = @as(u32, base) + (@as(u32, 1) << @intCast(bits)) - 1;
            for ([_]u32{ base -| 1, base, base + 1, upper -| 1, upper, upper + 1 }) |literal_len| {
                const origin = try node(model, literal_len);
                const offsets = [_]u32{ 1, 3, 7, std.math.maxInt(u32) };
                const selected = try choice(literal_len, offsets[(code + seed) % offsets.len], origin.repeats);
                try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &.{ 3, 34, 35, 66, 131074, 2 } }, metrics);
            }
        }
        const literals = [_]u32{ 0, 1, 131071 };
        const literal_len = literals[seed % literals.len];
        const origin = try node(model, literal_len);
        for (prices.ml_bases, prices.ml_bits, 0..) |base, bits, code| {
            const upper = @as(usize, base) + (@as(usize, 1) << @intCast(bits)) - 1;
            const selected = try choice(literal_len, if (code & 1 == 0) 1 else std.math.maxInt(u32), origin.repeats);
            const lengths = [_]usize{ base - 1, base, base + 1, upper - 1, upper, upper + 1 };
            try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &lengths, .position = 65535 }, metrics);
        }
        for (0..32) |bit| {
            const value = @as(u32, 1) << @intCast(bit);
            for ([_]u32{ value - 1, value, value + 1 }) |offset| {
                const selected = try choice(literal_len, offset, origin.repeats);
                try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &.{ 3, 35, 131074, 2 }, .instrument = bit & 1 == 0 }, metrics);
            }
        }
        const zero = try node(model, 0);
        for ([_]u32{ 131072, 131073, std.math.maxInt(u32) }) |bad_ll| {
            var invalid = zero;
            invalid.literal_len = bad_ll;
            try compare.run(Helper, .{ .model = model, .node = invalid, .choice = try choice(bad_ll, 1, invalid.repeats), .lengths = &.{ 2, 3, 131074 } }, metrics);
        }
        const old = models.freeze(model);
        try std.testing.expectEqual(try oracle.literalLengthPrice(&old, 131071), try oracle.literalLengthPrice(&old, 131072));
        try std.testing.expectError(error.InvalidBlockPlan, oracle.literalLengthPrice(&old, 131073));
    }
}

fn aliases(comptime Helper: type, metrics: *compare.Metrics) !void {
    for (models.fixtures()) |model| {
        for ([_]u32{ 0, 1, 16, 131071 }) |literal_len| {
            for ([_]rep.Repeats{ .{ 8, 8, 16 }, .{ 9, 8, 8 } }) |repeats| {
                var origin = try node(model, literal_len);
                origin.repeats = repeats;
                const choices = try rep.choices(literal_len, 8, repeats);
                // Each offset alias starts a new preparation, even when it
                // has the same physical distance as its neighboring alias.
                for (choices.slice()) |selected| try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &.{ 3, 4, 4, 34, 35, 36, 131074 } }, metrics);
            }
        }
    }
}

fn budgetsAndArithmetic(comptime Helper: type, metrics: *compare.Metrics) !void {
    const model: prices.EntropyModel = .{};
    const origin = try node(model, 1);
    const selected = try choice(1, 7, origin.repeats);
    for (0..5) |limit| {
        try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &.{ 3, 4, 5, 6, 7 }, .limit = limit }, metrics);
        try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &.{ 3, 4, 5 }, .limit = limit, .admitted = limit -| 1 }, metrics);
    }
    try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &.{ 3, 4 }, .admitted = std.math.maxInt(u64) }, metrics);
    try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &.{ 3, 4 }, .admitted = std.math.maxInt(u64) - 1 }, metrics);
    var bad = origin;
    bad.literal_len = 131072;
    try compare.run(Helper, .{ .model = model, .node = bad, .choice = try choice(131072, 0, bad.repeats), .lengths = &.{ 2, 3 }, .limit = 0 }, metrics);
    // A refused replay must precede invalid ML checks and new replay counters.
    try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &.{ 3, 2, 131075 }, .limit = 1 }, metrics);
    var underflow = origin;
    underflow.cost = 0;
    try compare.run(Helper, .{ .model = model, .node = underflow, .choice = selected, .lengths = &.{ 3, 4, 5 } }, metrics);
    var zero: prices.EntropyModel = .{};
    zero.ll_prices = @splat(0);
    zero.ml_prices = @splat(0);
    zero.of_prices = @splat(0);
    var maximum: state.Node = .{ .cost = std.math.maxInt(u64), .literal_len = 1 };
    const one = try choice(1, 1, maximum.repeats);
    try compare.run(Helper, .{ .model = zero, .node = maximum, .choice = one, .lengths = &.{ 3, 3, 3 } }, metrics);
    var sequence_overflow = zero;
    sequence_overflow.ml_prices[0] = 1;
    try compare.run(Helper, .{ .model = sequence_overflow, .node = maximum, .choice = one, .lengths = &.{ 3, 3 } }, metrics);
    var final_overflow = zero;
    final_overflow.ll_prices[0] = 7;
    try compare.run(Helper, .{ .model = final_overflow, .node = maximum, .choice = one, .lengths = &.{ 3, 3 } }, metrics);
    // First succeeds at u64.max. Later ML changes cause only replay's final
    // addition to overflow, matching the old full formula's exact ordering.
    maximum.cost -= 7;
    final_overflow.ml_prices[1] = 1;
    try compare.run(Helper, .{ .model = final_overflow, .node = maximum, .choice = one, .lengths = &.{ 3, 4, 3, 4 } }, metrics);
    const saturated: Profile = .{ .price_evaluations = std.math.maxInt(u64), .optimal_transitions = std.math.maxInt(u64) - 1, .price_limit_refusals = std.math.maxInt(u64), .frontier_choice_preparations = std.math.maxInt(u64), .frontier_choice_replays = std.math.maxInt(u64) - 1 };
    try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &.{ 2, 3, 4, 5 }, .limit = 3, .profile_seed = saturated }, metrics);
}

fn shortFirstCosts(comptime Helper: type, metrics: *compare.Metrics) !void {
    const all_models = models.fixtures();
    // These short ML symbols have no extra bits. A single request and one
    // replay expose first-edge setup independently of a long replay interval.
    for (all_models, 0..) |model, seed| {
        for (prices.ll_bases, 0..) |literal_len, code| {
            const origin = try node(model, literal_len);
            const selected = try choice(literal_len, if (seed & 1 == 0) 1 else 7, origin.repeats);
            for (3..11) |last| {
                try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &.{last} }, metrics);
                try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &.{ last, 3 } }, metrics);
                // Invalid ML first must publish nothing. A subsequent valid
                // call remains a fresh first, never a replay of failed state.
                try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &.{ 2, last } }, metrics);
            }
            const last = 3 + (code + seed) % 8;
            for (0..3) |quota| {
                try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &.{last}, .limit = quota }, metrics);
                try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &.{ last, 3 }, .limit = quota }, metrics);
                try compare.run(Helper, .{ .model = model, .node = origin, .choice = selected, .lengths = &.{ 2, last }, .limit = quota }, metrics);
            }
        }
    }

    const valid: prices.EntropyModel = .{};
    var zero: prices.EntropyModel = .{};
    zero.ll_prices = @splat(0);
    zero.ml_prices = @splat(0);
    zero.of_prices = @splat(0);
    for (prices.ll_bases) |literal_len| {
        var underflow = try node(valid, literal_len);
        underflow.cost = 0;
        var overflow = underflow;
        overflow.cost = std.math.maxInt(u64);
        const selected = try choice(literal_len, 1, underflow.repeats);
        for (3..11) |last| {
            // A failed complete-node construction cannot seed the next first.
            try compare.run(Helper, .{ .model = valid, .node = underflow, .choice = selected, .lengths = &.{ last, 3 } }, metrics);
            try compare.run(Helper, .{ .model = valid, .node = overflow, .choice = selected, .lengths = &.{ last, 3 } }, metrics);
            // Even at u64.max, zero symbol prices and exact cancellation of
            // LL extra bits permit a valid first followed by one valid replay.
            try compare.run(Helper, .{ .model = zero, .node = overflow, .choice = selected, .lengths = &.{ last, 3 } }, metrics);
        }
    }
}

pub fn check(comptime Helper: type) !compare.Metrics {
    var metrics: compare.Metrics = .{};
    try boundaries(Helper, &metrics);
    try aliases(Helper, &metrics);
    try budgetsAndArithmetic(Helper, &metrics);
    try shortFirstCosts(Helper, &metrics);
    return metrics;
}
