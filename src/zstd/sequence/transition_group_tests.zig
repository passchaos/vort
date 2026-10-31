const std = @import("std");
const T = @import("transition_group.zig");

pub fn check() !void {
    var random: u64 = 0x743af893627ab10d;
    for (0..10) |ll| for (0..10) |ml| for (0..10) |of| {
        const total = ll + ml + of;
        for (0..57 - total) |consumed| for (0..4) |_| {
            random = random *% 6364136223846793005 +% 1442695040888963407;
            var combined: @import("field_group.zig").Group = .{ .bits = random, .consumed = @intCast(consumed) };
            var original = combined;
            const expected = [3]usize{ original.read(@intCast(ll)), original.read(@intCast(ml)), original.read(@intCast(of)) };
            const actual = T.read(&combined, @intCast(ll), @intCast(ml), @intCast(of));
            try std.testing.expectEqual(expected, actual);
            try std.testing.expectEqual(original.bits, combined.bits);
            try std.testing.expectEqual(original.consumed, combined.consumed);
            const bases = [3]usize{ 0, 255, 511 };
            inline for (0..3) |i| try std.testing.expectEqual(bases[i] + expected[i], bases[i] + actual[i]);
        };
    };
}
