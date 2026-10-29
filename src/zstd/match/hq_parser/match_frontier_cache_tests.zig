const std = @import("std");
const tree = @import("../hq_tree.zig");

pub fn contracts(comptime C: type) !void {
    try std.testing.expectEqual(
        @as(usize, 5 * @sizeOf(u32) + 16 * @sizeOf(tree.Match)),
        try C.Cache.estimatedBytes(4),
    );

    var cache = try C.Cache.init(std.testing.allocator, 4);
    defer cache.deinit(std.testing.allocator);
    const first = [_]tree.Match{ .{ .length = 3, .distance = 1 }, .{ .length = 7, .distance = 9 } };
    const second = [_]tree.Match{.{ .length = 4, .distance = 2 }};
    cache.record(0, .{ .items = &first });
    cache.record(1, .{ .items = &second });
    cache.record(2, .{ .items = &.{} });
    cache.record(3, .{ .items = &first });
    try std.testing.expect(cache.finish());
    try std.testing.expectEqual(@as(usize, 5), cache.entryCount());
    try std.testing.expectEqualSlices(tree.Match, &first, cache.at(0).items);
    try std.testing.expectEqualSlices(tree.Match, &second, cache.at(1).items);
    try std.testing.expectEqual(@as(usize, 0), cache.at(2).items.len);
    try std.testing.expectEqualSlices(tree.Match, &first, cache.at(3).items);

    // Out-of-order records and an average frontier wider than the fixed
    // budget disable replay instead of changing search or returning an error.
    var order = try C.Cache.init(std.testing.allocator, 2);
    defer order.deinit(std.testing.allocator);
    order.record(1, .{ .items = &second });
    try std.testing.expect(!order.finish());

    var full = try C.Cache.init(std.testing.allocator, 1);
    defer full.deinit(std.testing.allocator);
    const too_many = [_]tree.Match{.{}} ** (C.matches_per_position + 1);
    full.record(0, .{ .items = &too_many });
    try std.testing.expect(!full.finish());

    try std.testing.expectError(error.WorkingMemoryLimitExceeded, C.Cache.estimatedBytes(std.math.maxInt(usize)));
}
