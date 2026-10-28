const std = @import("std");
const h = @import("helpers.zig");

pub fn contracts(comptime Codec: type) !void {
    inline for (.{ false, true }) |whole| {
        for ([_]usize{ 1, 8, 16 }) |width| {
            for ([_]h.controls.Strategy{ .btopt, .btultra, .btultra2 }) |strategy| {
                for ([_]u8{ 3, 7, 17, 65, 131, 255 }) |minimum| {
                    for ([_]usize{ minimum - 1, minimum, @as(usize, minimum) + 1 }) |maximum| {
                        const result = try h.compare(Codec, whole, false, width, .{
                            .strategy = strategy,
                            .minimum = minimum,
                            .maximum = maximum,
                        });
                        try std.testing.expectEqual(@as(?anyerror, null), result.failure);
                    }
                }
                // Both sides of every ML interval, including the final legal
                // length and the first invalid length above that final upper.
                for (h.prices.ml_bases, h.prices.ml_bits) |base, bits| {
                    const lower: usize = base;
                    const upper = lower + (@as(usize, 1) << @intCast(bits)) - 1;
                    for ([_]usize{ lower - 1, lower, lower + 1, upper - 1, upper, upper + 1 }) |maximum| {
                        if (width != 1 and maximum > 4096) continue;
                        const result = try h.compare(Codec, whole, false, width, .{
                            .strategy = strategy,
                            .maximum = maximum,
                            .literal_len = if (bits % 2 == 0) 0 else 131071,
                            .repeats = .{ 9, 8, 8 },
                            .distance = 8,
                        });
                        const want: ?anyerror = if (maximum > 131074) error.InvalidBlockPlan else null;
                        try std.testing.expectEqual(want, result.failure);
                    }
                }
            }
            // Deliberately exercise the Context API's existing behavior when
            // min_match exceeds a sampled ML boundary. Do not filter those
            // old boundary candidates merely because minimum is now higher.
            const outside = try h.compare(Codec, whole, false, width, .{
                .minimum = 65,
                .maximum = 100,
                .seed_rows = false,
            });
            try std.testing.expectEqual(@as(?u32, 17), outside.lowest_written_match);
            const ultra = try h.compare(Codec, whole, false, width, .{
                .strategy = .btultra,
                .minimum = 131,
                .maximum = 259,
                .seed_rows = false,
            });
            try std.testing.expectEqual(@as(?u32, 66), ultra.lowest_written_match);
        }
    }
}
