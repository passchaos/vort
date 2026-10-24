const std = @import("std");
const total = @import("../total_budget.zig");
const allocator = std.testing.allocator;

const Options = struct {
    max_total_working_memory: ?usize = null,
    memory_profile: ?*total.EncodeMemoryProfile = null,
    preserved: u8 = 7,
};

const Owner = struct {
    bytes: []u8,
    calls: usize = 0,
    fn retained(self: *@This()) total.Error!usize {
        self.calls += 1;
        return self.bytes.len;
    }
};

test "Zstd total budget entry forwards defaults and returns exact owned allocation" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var plain = try total.Entry.init(failing.allocator(), Options{});
    defer plain.deinit();
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    try std.testing.expect(plain.allocator().vtable == failing.allocator().vtable);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, total.Entry.init(failing.allocator(), Options{ .max_total_working_memory = 0 }));

    var profile: total.EncodeMemoryProfile = .{};
    var entry = try total.Entry.init(allocator, Options{ .memory_profile = &profile });
    const nested = entry.forward(Options{ .memory_profile = &profile, .max_total_working_memory = 50, .preserved = 42 });
    try std.testing.expectEqual(@as(?usize, null), nested.max_total_working_memory);
    try std.testing.expectEqual(@as(?*total.EncodeMemoryProfile, null), nested.memory_profile);
    try std.testing.expectEqual(@as(u8, 42), nested.preserved);
    const bytes = try entry.allocator().alloc(u8, 24);
    try entry.releaseOwned(bytes.len);
    try std.testing.expectEqual(total.control_bytes, entry.snapshot().live_requested_bytes);
    entry.deinit();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    allocator.free(bytes);
}

test "Zstd total budget reusable adopts exact capacity once and detaches per call profile" {
    var owner: Owner = .{ .bytes = try allocator.alloc(u8, 37) };
    var reusable = try total.Reusable.init(allocator);
    _ = try reusable.begin(Options{}, &owner, Owner.retained);
    try std.testing.expectEqual(@as(usize, 0), owner.calls);
    try std.testing.expect(!reusable.snapshot().available);
    var profile: total.EncodeMemoryProfile = .{};
    const a = try reusable.begin(Options{ .memory_profile = &profile }, &owner, Owner.retained);
    try std.testing.expectEqual(@as(usize, 1), owner.calls);
    try std.testing.expectEqual(total.control_bytes + 37, reusable.snapshot().live_requested_bytes);
    const scratch = try a.alloc(u8, 23);
    try std.testing.expectEqual(total.control_bytes + 60, profile.live_requested_bytes);
    reusable.end();
    const detached = profile;
    a.free(scratch);
    try std.testing.expectEqualDeep(detached, profile);
    var next_profile: total.EncodeMemoryProfile = .{};
    _ = try reusable.begin(Options{ .memory_profile = &next_profile }, &owner, Owner.retained);
    try std.testing.expectEqual(@as(usize, 1), owner.calls);
    try std.testing.expectEqual(total.control_bytes + 37, next_profile.live_requested_bytes);
    a.free(owner.bytes);
    reusable.end();
    reusable.deinit();
}

test "Zstd total budget reusable inherited scope does not reset or detach outer profile" {
    var profile: total.EncodeMemoryProfile = .{};
    var entry = try total.Entry.init(allocator, Options{ .max_total_working_memory = total.control_bytes + 24, .memory_profile = &profile });
    var reusable = try total.Reusable.init(entry.allocator());
    var owner: Owner = .{ .bytes = &.{} };
    const a = try reusable.begin(Options{}, &owner, Owner.retained);
    try std.testing.expectEqual(@as(usize, 0), owner.calls);
    try std.testing.expectError(error.OutOfMemory, a.alloc(u8, 25));
    _ = try reusable.begin(Options{}, &owner, Owner.retained);
    try std.testing.expect(entry.snapshot().last_failure_was_limit);
    reusable.end();
    const scratch = try a.alloc(u8, 24);
    try std.testing.expectEqual(total.control_bytes + 24, profile.live_requested_bytes);
    a.free(scratch);
    reusable.deinit();
    entry.deinit();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

test "Zstd total budget reusable cross allocator returned copy shares exact quota" {
    var owner: Owner = .{ .bytes = try allocator.alloc(u8, 16) };
    @memset(owner.bytes, 0x39);
    var reusable = try total.Reusable.init(allocator);
    var profile: total.EncodeMemoryProfile = .{};
    const a = try reusable.begin(Options{ .max_total_working_memory = total.control_bytes + 32, .memory_profile = &profile }, &owner, Owner.retained);
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, reusable.duplicateOwned(failing.allocator(), owner.bytes));
    try std.testing.expectEqual(total.control_bytes + 16, profile.peak_requested_bytes);
    var storage: [64]u8 = undefined;
    var target = std.heap.FixedBufferAllocator.init(&storage);
    const wire = try reusable.duplicateOwned(target.allocator(), owner.bytes);
    try std.testing.expectEqualSlices(u8, owner.bytes, wire);
    try std.testing.expectEqual(total.control_bytes + 32, profile.peak_requested_bytes);
    try std.testing.expectEqual(total.control_bytes + 16, profile.live_requested_bytes);
    target.allocator().free(wire);
    const local = try reusable.duplicateOwned(allocator, owner.bytes);
    try std.testing.expectEqual(total.control_bytes + 16, profile.live_requested_bytes);
    allocator.free(local);
    a.free(owner.bytes);
    reusable.end();
    reusable.deinit();
}
