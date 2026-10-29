const std = @import("std");
const h = @import("../row_tags_tests/edges/helpers.zig");

/// The public candidate remains a value snapshot while its private edge loop
/// borrows that snapshot and the immutable local choice array. Exercise real
/// row aliases across every slot so target-row insertion cannot make either
/// private pointer observe moved state.
pub fn contracts(comptime Codec: type) !void {
    inline for (.{ false, true }) |whole| {
        inline for (.{ false, true }) |complete| {
            inline for (.{ false, true }) |tagged| {
                for ([_]usize{ 1, 8, 16 }) |width| {
                    for (0..width) |slot| {
                        const options: h.Case = .{
                            .strategy = .btultra,
                            .minimum = 7,
                            .maximum = 67,
                            .literal_len = 0,
                            .repeats = .{ 9, 8, 8 },
                            .distance = 8,
                            .alias_origin = true,
                            .alias_slot = slot,
                            .tagged = tagged,
                        };
                        const full = try h.compare(Codec, whole, complete, width, options);
                        try std.testing.expectEqual(@as(?anyerror, null), full.failure);
                        for ([_]u64{ 0, 1, 17, full.admitted }) |quota| {
                            var limited = options;
                            limited.limit = quota;
                            const result = try h.compare(Codec, whole, complete, width, limited);
                            const failure: ?anyerror = if (quota < full.admitted)
                                error.SearchLimitExceeded
                            else
                                null;
                            try std.testing.expectEqual(failure, result.failure);
                        }
                    }

                    var overflow: h.Case = .{
                        .strategy = .btultra,
                        .minimum = 7,
                        .maximum = 67,
                        .literal_len = 0,
                        .repeats = .{ 9, 8, 8 },
                        .distance = 8,
                        .cost = std.math.maxInt(u64),
                        .alias_origin = true,
                        .alias_slot = width - 1,
                        .tagged = tagged,
                        .limit = 0,
                    };
                    const denied = try h.compare(Codec, whole, complete, width, overflow);
                    try std.testing.expectEqual(@as(?anyerror, error.SearchLimitExceeded), denied.failure);
                    overflow.limit = 1;
                    const admitted = try h.compare(Codec, whole, complete, width, overflow);
                    try std.testing.expectEqual(@as(?anyerror, error.IntegerOverflow), admitted.failure);
                }
            }
        }
    }
}
