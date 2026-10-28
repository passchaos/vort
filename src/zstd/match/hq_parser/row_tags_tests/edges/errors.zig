const std = @import("std");
const h = @import("helpers.zig");

fn check(comptime Codec: type, comptime whole: bool, width: usize, case: h.Case, failure: ?anyerror, admitted: u64) !void {
    const result = try h.compare(Codec, whole, false, width, case);
    try std.testing.expectEqual(failure, result.failure);
    try std.testing.expectEqual(admitted, result.admitted);
}

pub fn contracts(comptime Codec: type) !void {
    inline for (.{ false, true }) |whole| {
        for ([_]usize{ 1, 8, 16 }) |width| {
            // maximum < minimum returns before rep validation or admission.
            try check(Codec, whole, width, .{
                .maximum = 2,
                .literal_len = std.math.maxInt(u32),
                .repeats = .{ 0, 0, 0 },
                .distance = 0,
                .limit = 0,
            }, null, 0);
            for ([_]usize{ 0, @as(usize, std.math.maxInt(u32)) - 2, std.math.maxInt(usize) }) |distance|
                try check(Codec, whole, width, .{ .maximum = 3, .distance = distance, .limit = 0 }, error.InvalidBlockPlan, 0);
            for (0..3) |word| {
                var case: h.Case = .{ .maximum = 3, .limit = 0 };
                case.repeats[word] = 0;
                try check(Codec, whole, width, case, error.InvalidBlockPlan, 0);
            }
            // A valid repeat selection reaches admission before entropy checks.
            for ([_]u32{ 131072, std.math.maxInt(u32) }) |literal_len| {
                try check(Codec, whole, width, .{ .maximum = 3, .literal_len = literal_len, .limit = 0 }, error.SearchLimitExceeded, 0);
                try check(Codec, whole, width, .{ .maximum = 3, .literal_len = literal_len, .limit = 1 }, error.InvalidBlockPlan, 1);
            }
            try check(Codec, whole, width, .{ .minimum = 2, .maximum = 2, .limit = 0 }, error.SearchLimitExceeded, 0);
            try check(Codec, whole, width, .{ .minimum = 2, .maximum = 2, .limit = 1 }, error.InvalidBlockPlan, 1);
            // Invalid longest endpoint is attempted first; it is not skipped
            // in favor of valid sampled interior lengths.
            if (width == 1) {
                try check(Codec, whole, width, .{ .maximum = 131075, .limit = 0 }, error.SearchLimitExceeded, 0);
                try check(Codec, whole, width, .{ .maximum = 131075, .limit = 1 }, error.InvalidBlockPlan, 1);
            }
            try check(Codec, whole, width, .{ .maximum = 100, .cost = std.math.maxInt(u64), .limit = 0 }, error.SearchLimitExceeded, 0);
            try check(Codec, whole, width, .{ .maximum = 100, .cost = std.math.maxInt(u64), .limit = 1 }, error.IntegerOverflow, 1);
            // The checked u64 addition must also distinguish exact fit from
            // overflow by one, independently of the node sentinel value.
            const model: h.prices.EntropyModel = .{};
            const cost: u64 = try model.sequencePrice(1, 3, 10);
            try check(Codec, whole, width, .{
                .maximum = 3,
                .pricing = .predefined,
                .seed_rows = false,
                .cost = std.math.maxInt(u64) - cost,
            }, null, 1);
            try check(Codec, whole, width, .{
                .maximum = 3,
                .pricing = .predefined,
                .cost = std.math.maxInt(u64) - cost + 1,
            }, error.IntegerOverflow, 1);
            // A zero-price repeat can precede a positive-price duplicate. Its
            // admission and possible sentinel node survive the later overflow.
            try check(Codec, whole, width, .{
                .maximum = 3,
                .literal_len = 0,
                .repeats = .{ 2, 1, 4 },
                .distance = 1,
                .pricing = .zero,
                .cost = std.math.maxInt(u64),
                .seed_rows = false,
            }, error.IntegerOverflow, 2);
            try check(Codec, whole, width, .{ .maximum = 3, .admitted = std.math.maxInt(u64) }, error.SearchLimitExceeded, std.math.maxInt(u64));
            _ = try h.compare(Codec, whole, false, width, .{ .maximum = 100, .instrument = false });
            _ = try h.compare(Codec, whole, false, width, .{
                .maximum = 100,
                .limit = 1,
                .profile = .{ .price_evaluations = std.math.maxInt(u64), .optimal_transitions = std.math.maxInt(u64), .price_limit_refusals = std.math.maxInt(u64) },
            });
        }
    }
}
