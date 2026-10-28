const std = @import("std");
const E = @import("../search_edges.zig");
const Old = @import("../search_edges_known_ml_reference.zig");
const h = @import("../row_tags_tests/edges/helpers.zig");
const m = @import("models.zig");

fn Adapter(comptime tagged: bool) type {
    return struct {
        pub const Context = E.Context;
        pub const Spill = E.Spill;
        pub const Reference = Old;
        pub const force_tags = tagged;
    };
}
pub fn contracts() !void {
    const Tagged = Adapter(true);
    try @import("../row_tags_tests/edges/boundaries.zig").contracts(Tagged);
    try @import("../row_tags_tests/edges/quotas.zig").contracts(Tagged);
    try @import("../row_tags_tests/edges/errors.zig").contracts(Tagged);
    try @import("../row_tags_tests/edges/smoke.zig").contracts(Tagged);
    const models = m.fixtures();
    inline for (.{ false, true }) |whole| {
        inline for (.{ false, true }) |complete| {
            inline for (.{ false, true }) |tagged| {
                for ([_]usize{ 1, 8, 16 }) |width| {
                    for (&models) |*model| {
                        const options: h.Case = .{
                            .strategy = .btultra,
                            .minimum = 7,
                            .maximum = 67,
                            .literal_len = 0,
                            .repeats = .{ 9, 8, 8 },
                            .distance = 8,
                            .entropy = model,
                            .alias_origin = true,
                        };
                        const full = try h.compare(Adapter(tagged), whole, complete, width, options);
                        try std.testing.expectEqual(@as(?anyerror, null), full.failure);
                        for ([_]u64{ 0, 1, full.admitted / 2, full.admitted - 1, full.admitted }) |quota| {
                            var limited = options;
                            limited.limit = quota;
                            const result = try h.compare(Adapter(tagged), whole, complete, width, limited);
                            const want: ?anyerror = if (quota < full.admitted) error.SearchLimitExceeded else null;
                            try std.testing.expectEqual(want, result.failure);
                        }
                    }
                }
            }
        }
    }
    inline for (.{ false, true }) |whole| {
        for ([_]usize{ 1, 8, 16 }) |width| {
            const original = try h.compare(Tagged, whole, false, width, .{
                .strategy = .btultra,
                .minimum = 131,
                .maximum = 259,
                .seed_rows = false,
            });
            try std.testing.expectEqual(@as(?u32, 66), original.lowest_written_match);
        }
    }
}
