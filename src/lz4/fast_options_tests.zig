const std = @import("std");
const fast = @import("fast_options.zig");

test "LZ4 fast options normalize signed domain and reject only invalid chain depth" {
    inline for (.{ @as(i32, std.math.minInt(i32)), -1, 0, 1, 2, 65537, 65538, std.math.maxInt(i32) }) |value| {
        const resolved = try (fast.BlockEncodeOptions{ .acceleration = value }).resolve();
        const expected: u32 = if (value <= 0) 1 else if (value > 65537) 65537 else @intCast(value);
        try std.testing.expectEqual(expected, resolved.acceleration);
        try std.testing.expectEqual(@as(u8, 16), resolved.chain_depth);
        try (fast.BlockEncodeOptions{ .acceleration = value, .chain_depth = 0 }).validate();
    }
    try std.testing.expectError(error.InvalidBlockPlan, (fast.BlockEncodeOptions{ .chain_depth = 17 }).resolve());
}

test "LZ4 fast options schedule resets after success and clips advances at host-size boundaries" {
    var profile: fast.FastEncodeProfile = .{};
    const options = try (fast.BlockEncodeOptions{ .acceleration = 65537, .profile = &profile }).work();
    var schedule = fast.MissSchedule.init(options.acceleration);
    const position = std.math.maxInt(usize) - 128;
    const last = std.math.maxInt(usize) - 12;
    try std.testing.expectEqual(position + 1, schedule.advance(position, last, options));
    try std.testing.expectEqual(last + 1, schedule.advance(position + 1, last, options));
    try std.testing.expectEqual(@as(usize, 116), profile.max_skip_step);
    try std.testing.expectEqual(@as(u64, 115), profile.positions_skipped);
    schedule.reset();
    try std.testing.expectEqual(@as(usize, 1), schedule.advance(0, 1000, options));
    var baseline = fast.MissSchedule.init(1);
    for (0..1000) |i| try std.testing.expectEqual(i + 1, baseline.advance(i, 1000, options));
    var precise = fast.MissSchedule.init(8);
    var at: usize = 0;
    for (0..66) |miss| {
        const next = precise.advance(at, 10000, options);
        const expected: usize = if (miss == 0) 1 else if (miss <= 64) 8 else 9;
        try std.testing.expectEqual(expected, next - at);
        at = next;
    }
}

test "LZ4 fast options profile merge saturates work and retains actual maximum stride" {
    var profile: fast.FastEncodeProfile = .{ .positions_inspected = std.math.maxInt(u64) - 2, .positions_skipped = 8, .max_skip_step = 128 };
    profile.merge(.{ .resolved_acceleration = 32, .resolved_chain_depth = 4, .positions_inspected = 9, .positions_skipped = 3, .chain_candidates = 4, .blocks_attempted = 1, .max_skip_step = 16 });
    try std.testing.expectEqual(std.math.maxInt(u64), profile.positions_inspected);
    try std.testing.expectEqual(@as(u64, 11), profile.positions_skipped);
    try std.testing.expectEqual(@as(usize, 128), profile.max_skip_step);
    try std.testing.expectEqual(@as(u32, 32), profile.resolved_acceleration);
    try std.testing.expectEqual(@as(u8, 4), profile.resolved_chain_depth);
    profile.reset();
    try std.testing.expectEqualDeep(fast.FastEncodeProfile{}, profile);
}
