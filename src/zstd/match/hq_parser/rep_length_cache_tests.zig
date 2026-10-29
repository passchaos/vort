const std = @import("std");

pub fn contracts(comptime C: type) !void {
    var cache: C.Cache = .{};
    cache.beginPosition();
    const first = cache.lookup(7);
    try std.testing.expectEqual(@as(?u32, null), first.length);
    cache.store(first, 7, 19);
    try std.testing.expectEqual(@as(?u32, 19), cache.lookup(7).length);
    for (1..49) |value| {
        if (value == 7) continue;
        const probe = cache.lookup(@intCast(value));
        cache.store(probe, @intCast(value), value * 2);
    }
    for (1..49) |value| {
        const expected: u32 = if (value == 7) 19 else @intCast(value * 2);
        try std.testing.expectEqual(@as(?u32, expected), cache.lookup(@intCast(value)).length);
    }
    cache.beginPosition();
    try std.testing.expectEqual(@as(?u32, null), cache.lookup(7).length);
    cache.generation = std.math.maxInt(u32);
    cache.beginPosition();
    try std.testing.expectEqual(@as(u32, 1), cache.generation);
    for (cache.entries) |entry| try std.testing.expectEqual(@as(u32, 0), entry.generation);
}
