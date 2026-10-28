const std = @import("std");
const h = @import("helpers.zig");

pub fn contracts(comptime Codec: type) !void {
    const cases = [_]h.Case{
        .{ .maximum = 67, .repeats = .{ 8, 8, 8 }, .distance = 8 },
        .{ .strategy = .btultra, .minimum = 7, .maximum = 100, .literal_len = 0, .repeats = .{ 9, 8, 8 }, .distance = 8 },
        .{ .minimum = 65, .maximum = 131, .literal_len = 0, .repeats = .{ 1, 4, 8 }, .distance = 7 },
        .{ .strategy = .btultra2, .minimum = 131, .maximum = 259, .literal_len = 131071, .distance = std.math.maxInt(u32) - 3 },
    };
    inline for (.{ false, true }) |whole| {
        for ([_]usize{ 1, 8, 16 }) |width| {
            for (cases) |case| {
                const measured = try h.compare(Codec, whole, false, width, case);
                try std.testing.expectEqual(@as(?anyerror, null), measured.failure);
                try std.testing.expect(measured.admitted > 1);
                // Every quota observes an actual prefix of the frozen public
                // candidate's ordered admissions, including repeat aliases
                // whose node insertion may be rejected as a duplicate.
                for (0..@as(usize, @intCast(measured.admitted)) + 2) |limit| {
                    var limited = case;
                    limited.limit = @intCast(limit);
                    const result = try h.compare(Codec, whole, false, width, limited);
                    try std.testing.expectEqual(@min(@as(u64, @intCast(limit)), measured.admitted), result.admitted);
                    const want: ?anyerror = if (limit < measured.admitted) error.SearchLimitExceeded else null;
                    try std.testing.expectEqual(want, result.failure);
                    try std.testing.expectEqual(case.profile.price_evaluations + result.admitted, result.profile.price_evaluations);
                    try std.testing.expectEqual(case.profile.price_limit_refusals + @intFromBool(want != null), result.profile.price_limit_refusals);
                }
                var continued = case;
                continued.admitted = 7;
                continued.limit = 7 + measured.admitted / 2;
                _ = try h.compare(Codec, whole, false, width, continued);
                var repeated = case;
                repeated.repetitions = 2;
                const twice = try h.compare(Codec, whole, false, width, repeated);
                try std.testing.expectEqual(measured.admitted * 2, twice.admitted);
            }
        }
    }
}
