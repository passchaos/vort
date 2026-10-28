const std = @import("std");
const h = @import("helpers.zig");

pub fn contracts(comptime Codec: type) !void {
    for ([_]usize{ 1, 8, 16 }) |width| {
        const whole = try h.compare(Codec, true, true, width, .{
            .maximum = 19,
            .literal_len = 0,
            .repeats = .{ 9, 8, 8 },
            .distance = 8,
        });
        try std.testing.expectEqual(@as(?anyerror, null), whole.failure);
        _ = try h.compare(Codec, true, true, width, .{ .maximum = 19, .limit = 5 });
        if (width == 1) {
            const beyond = try h.compare(Codec, true, false, width, .{ .position = 70000, .maximum = 7, .seed_rows = false });
            try std.testing.expectEqual(@as(?anyerror, null), beyond.failure);
        }
        const spill = try h.compare(Codec, false, true, width, .{
            .position = 6,
            .goal = 8,
            .maximum = 10,
            .seed_rows = false,
        });
        try std.testing.expectEqual(@as(?anyerror, null), spill.failure);
        try std.testing.expect(spill.spill_end > 8);
        try std.testing.expectEqual(@as(u16, 6), spill.spill_node.previous_position);
        _ = try h.compare(Codec, false, true, width, .{
            .position = 6,
            .goal = 8,
            .maximum = 10,
            .limit = 0,
        });
        const overflow = try h.compare(Codec, false, true, width, .{
            .position = 6,
            .goal = 8,
            .maximum = 10,
            .prefix_unit = 0,
            .prefix_tail = std.math.maxInt(u64),
        });
        try std.testing.expectEqual(@as(?anyerror, error.IntegerOverflow), overflow.failure);
        try std.testing.expectEqual(@as(u64, 1), overflow.admitted);
    }
}
