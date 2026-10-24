//! Publish a complete meta-block without changing its shared tail on failure.
const std = @import("std");

pub fn appendCandidate(allocator: std.mem.Allocator, output: *std.ArrayList(u8), starting_bit_index: u3, bytes: []const u8) error{ OutOfMemory, InvalidBlockPlan }!void {
    const shared: usize = @intFromBool(starting_bit_index != 0);
    if (shared != 0 and (output.items.len == 0 or bytes.len == 0)) return error.InvalidBlockPlan;
    try output.ensureUnusedCapacity(allocator, bytes.len - shared);
    if (shared != 0) output.items[output.items.len - 1] = bytes[0];
    output.appendSliceAssumeCapacity(bytes[shared..]);
}

test "Brotli HQ meta-block publication preserves the mutable tail on allocation failure" {
    const allocator = std.testing.allocator;
    var output: std.ArrayList(u8) = .{ .items = try allocator.dupe(u8, &.{0x1d}), .capacity = 1 };
    defer output.deinit(allocator);
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, appendCandidate(failing.allocator(), &output, 5, &.{ 0xbd, 0x37 }));
    try std.testing.expectEqualSlices(u8, &.{0x1d}, output.items);
    try appendCandidate(allocator, &output, 5, &.{ 0xbd, 0x37 });
    try std.testing.expectEqualSlices(u8, &.{ 0xbd, 0x37 }, output.items);
}

test "Brotli HQ meta-block publication handles aligned output and rejects missing shared tails" {
    const allocator = std.testing.allocator;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try std.testing.expectError(error.InvalidBlockPlan, appendCandidate(allocator, &output, 1, &.{0x01}));
    try appendCandidate(allocator, &output, 0, &.{ 0x12, 0x34 });
    try std.testing.expectError(error.InvalidBlockPlan, appendCandidate(allocator, &output, 1, &.{}));
    try std.testing.expectEqualSlices(u8, &.{ 0x12, 0x34 }, output.items);
}
