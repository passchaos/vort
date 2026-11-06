const std = @import("std");
const budget = @import("../budget.zig");
const working = @import("../../../io/working_allocator.zig");
const allocator = std.testing.allocator;

pub const Options = struct {
    max_total_working_memory: ?usize = null,
    memory_profile: ?*budget.DecodeMemoryProfile = null,
    preserved: u8 = 17,
};

test "Zstd decode budget default entry and append preserve inner working allocator policy" {
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    const limit = std.ArrayList(u8).growCapacity(2) + 16;
    var inner = working.WorkingAllocator.init(failing.allocator(), limit);
    var entry = try budget.Entry.init(inner.allocator(), Options{});
    defer entry.deinit();
    try std.testing.expect(!entry.snapshot().available);
    try std.testing.expectEqual(@as(usize, 0), failing.allocations);
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(inner.allocator());
    try budget.append(entry.lease, inner.allocator(), &output, "ok");
    try std.testing.expectEqual(output.capacity, inner.live);
    try std.testing.expectEqual(output.capacity, inner.peak);
    try std.testing.expectError(error.OutOfMemory, inner.allocator().alloc(u8, limit + 1));
    try std.testing.expect(inner.last_failure_was_limit);
    // Default append forwards directly and leaves the earlier classification.
    try budget.append(entry.lease, inner.allocator(), &output, "!");
    try std.testing.expect(inner.last_failure_was_limit);
    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, inner.allocator().alloc(u8, 1));
    try std.testing.expect(!inner.last_failure_was_limit);
    try std.testing.expectEqual(error.OutOfMemory, entry.mapError(error.OutOfMemory));
}

test "Zstd decode budget entry exact cap forwarding and owned transfer" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, budget.Entry.init(failing.allocator(), Options{ .max_total_working_memory = budget.control_bytes - 1 }));
    try std.testing.expectEqual(@as(usize, 0), failing.allocations);
    var profile: budget.DecodeMemoryProfile = .{};
    var entry = try budget.Entry.init(allocator, Options{ .max_total_working_memory = budget.control_bytes + 24, .memory_profile = &profile });
    const forwarded = entry.forward(Options{ .max_total_working_memory = 1, .memory_profile = &profile, .preserved = 42 });
    try std.testing.expectEqual(Options{ .preserved = 42 }, forwarded);
    const bytes = try entry.allocator().alloc(u8, 24);
    try std.testing.expectError(error.OutOfMemory, entry.allocator().alloc(u8, 1));
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, entry.mapError(error.OutOfMemory));
    try entry.releaseOwned(bytes.len);
    try std.testing.expectEqual(budget.control_bytes, entry.snapshot().live_requested_bytes);
    entry.deinit();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectEqual(budget.control_bytes + 24, profile.peak_requested_bytes);
    allocator.free(bytes);
}
