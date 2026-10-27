//! Exact initial reservation for known complete DP geometry.
const std = @import("std");

pub fn resizeFresh(list: anytype, allocator: std.mem.Allocator, length: usize) !void {
    // New one-shot owners know the full length. Reused owners keep their
    // existing capacity and geometric growth for later, larger inputs.
    if (list.capacity == 0) try list.ensureTotalCapacityPrecise(allocator, length);
    try list.resize(allocator, length);
}

test "optimal storage reserves exact fresh geometry and retains reused capacity" {
    var values: std.ArrayList(usize) = .empty;
    defer values.deinit(std.testing.allocator);
    try resizeFresh(&values, std.testing.allocator, 4097);
    try std.testing.expectEqual(@as(usize, 4097), values.capacity);
    const pointer = values.items.ptr;
    try resizeFresh(&values, std.testing.allocator, 100);
    try std.testing.expectEqual(pointer, values.items.ptr);
    try std.testing.expectEqual(@as(usize, 4097), values.capacity);
    try resizeFresh(&values, std.testing.allocator, 4097);
    try std.testing.expectEqual(pointer, values.items.ptr);
}
