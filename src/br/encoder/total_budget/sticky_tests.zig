const std = @import("std");
const total = @import("../total_budget.zig");
const allocator = std.testing.allocator;

test "Brotli total authority descendants preserve the owner's quota interval" {
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    var profile: total.EncodeMemoryProfile = .{};
    const limit = total.control_bytes + 32;
    var owner = try total.Lease.init(failing.allocator(), limit, &profile, 0);
    defer owner.deinit();
    const a = owner.allocator();
    owner.beginOperation();
    try std.testing.expect(owner.coordinator);
    try std.testing.expectError(error.OutOfMemory, a.alloc(u8, 33));
    const allocated_before = failing.allocated_bytes;
    var retained = try owner.retain();
    defer retained.deinit();
    var inherited = try total.Lease.init(a, null, null, 0);
    defer inherited.deinit();
    var recovered = (try total.Lease.fromAllocator(a)).?;
    defer recovered.deinit();
    for ([_]total.Lease{ retained, inherited, recovered }) |child| {
        try std.testing.expect(!child.coordinator);
        child.beginOperation();
        const bytes = try child.allocator().alloc(u8, 8);
        child.allocator().free(bytes);
        try std.testing.expect(owner.snapshot().last_failure_was_limit);
        try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, child.translateError(error.OutOfMemory));
    }
    try std.testing.expectEqual(allocated_before + 24, failing.allocated_bytes);
    try std.testing.expectEqual(total.control_bytes, profile.live_requested_bytes);
    const peak_before = owner.snapshot().peak_requested_bytes;
    owner.beginOperation();
    try std.testing.expect(!owner.snapshot().last_failure_was_limit);
    try std.testing.expect(owner.snapshot().hit_limit);
    try std.testing.expectEqual(peak_before, owner.snapshot().peak_requested_bytes);
    try std.testing.expectEqual(error.OutOfMemory, owner.translateError(error.OutOfMemory));
}

test "Brotli total authority successful allocation resize remap adoption and configuration stay sticky" {
    var storage: [1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var profile: total.EncodeMemoryProfile = .{};
    var owner = try total.Lease.init(fixed.allocator(), total.control_bytes + 128, &profile, 0);
    defer owner.deinit();
    const a = owner.allocator();
    try std.testing.expectError(error.OutOfMemory, a.alloc(u8, 129));
    var bytes = try a.alloc(u8, 16);
    defer a.free(bytes);
    try std.testing.expect(owner.snapshot().last_failure_was_limit);
    try std.testing.expect(a.resize(bytes, 24));
    bytes = bytes.ptr[0..24];
    try std.testing.expect(owner.snapshot().last_failure_was_limit);
    try std.testing.expect(a.resize(bytes, 12));
    bytes = bytes.ptr[0..12];
    try std.testing.expect(owner.snapshot().last_failure_was_limit);
    bytes = a.remap(bytes, 20).?;
    try std.testing.expect(owner.snapshot().last_failure_was_limit);
    bytes = a.remap(bytes, 10).?;
    try std.testing.expect(owner.snapshot().last_failure_was_limit);
    try owner.seedExisting(8);
    owner.releaseExisting(8);
    try owner.reserveExisting(6);
    owner.releaseExisting(6);
    try std.testing.expect(owner.snapshot().last_failure_was_limit);
    try owner.setLimit(total.control_bytes + 256);
    try owner.setProfile(&profile);
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, owner.translateError(error.OutOfMemory));
    try std.testing.expectEqual(total.control_bytes + 10, owner.snapshot().live_requested_bytes);
    try std.testing.expectEqual(total.control_bytes + 24, owner.snapshot().peak_requested_bytes);
}

test "Brotli total authority external success and backing OOM preserve quota until owner begins again" {
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    var profile: total.EncodeMemoryProfile = .{};
    var owner = try total.Lease.init(failing.allocator(), total.control_bytes + 32, &profile, 0);
    defer owner.deinit();
    const a = owner.allocator();
    try std.testing.expectError(error.OutOfMemory, a.alloc(u8, 33));
    var reservation = try owner.tryReserveExternal(8);
    defer reservation.deinit();
    const external = try allocator.alloc(u8, 8);
    reservation.markAllocated();
    try std.testing.expect(owner.snapshot().last_failure_was_limit);
    try std.testing.expectEqual(total.control_bytes + 8, owner.snapshot().live_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), owner.snapshot().reserved_bytes);
    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, a.alloc(u8, 16));
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, owner.translateError(error.OutOfMemory));
    allocator.free(external);
    reservation.handoff();
    try std.testing.expect(owner.snapshot().last_failure_was_limit);
    try std.testing.expectEqual(total.control_bytes, profile.live_requested_bytes);
    owner.beginOperation();
    try std.testing.expectError(error.OutOfMemory, a.alloc(u8, 16));
    try std.testing.expectEqual(error.OutOfMemory, owner.translateError(error.OutOfMemory));
    try std.testing.expect(!owner.snapshot().last_failure_was_limit);
    try std.testing.expect(owner.snapshot().hit_limit);
    try std.testing.expectEqual(total.control_bytes, owner.snapshot().live_requested_bytes);
    try std.testing.expectEqual(total.control_bytes + 8, profile.peak_requested_bytes);
}

test "Brotli total authority child configuration checks reject before shared state mutation" {
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    var profile: total.EncodeMemoryProfile = .{};
    var other_profile: total.EncodeMemoryProfile = .{};
    const limit = total.control_bytes + 64;
    var owner = try total.Lease.init(failing.allocator(), limit, &profile, 0);
    defer owner.deinit();
    var child = try owner.retain();
    try std.testing.expectError(error.OutOfMemory, owner.allocator().alloc(u8, 65));
    const before = owner.snapshot();
    const profile_before = profile;
    const allocations_before = failing.alloc_index;
    try std.testing.expectError(error.InvalidBlockPlan, child.setLimit(null));
    try std.testing.expectError(error.InvalidBlockPlan, child.setLimit(limit - 1));
    try std.testing.expectError(error.InvalidBlockPlan, child.setLimit(limit + 1));
    try std.testing.expectError(error.InvalidBlockPlan, child.setProfile(null));
    try std.testing.expectError(error.InvalidBlockPlan, child.setProfile(&other_profile));
    try std.testing.expectError(error.InvalidBlockPlan, total.Lease.init(child.allocator(), limit + 1, &profile, 0));
    try std.testing.expectError(error.InvalidBlockPlan, total.Lease.init(child.allocator(), limit, &other_profile, 0));
    try std.testing.expectError(error.InvalidBlockPlan, total.Lease.init(child.allocator(), limit, &profile, 1));
    try std.testing.expectEqualDeep(before, owner.snapshot());
    try std.testing.expectEqualDeep(profile_before, profile);
    try std.testing.expectEqualDeep(total.EncodeMemoryProfile{}, other_profile);
    try std.testing.expectEqual(allocations_before, failing.alloc_index);
    profile.reset();
    try child.setLimit(limit);
    try child.setProfile(&profile);
    try std.testing.expectEqualDeep(total.EncodeMemoryProfile{}, profile);
    var inherited = try total.Lease.init(child.allocator(), null, null, 0);
    inherited.deinit();
    child.deinit();
    const bytes = try owner.allocator().alloc(u8, 8);
    owner.allocator().free(bytes);
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(total.control_bytes, profile.live_requested_bytes);
    try std.testing.expectEqual(@as(?usize, limit), profile.limit);
    try std.testing.expect(owner.snapshot().last_failure_was_limit);
}

test "Brotli total authority closed leases cannot revive outstanding allocator state" {
    var storage: [1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var profile: total.EncodeMemoryProfile = .{};
    var owner = try total.Lease.init(fixed.allocator(), 512, &profile, 0);
    const a = owner.allocator();
    var wire = try a.alloc(u8, 32);
    @memset(wire, 0x79);
    const borrowed = owner;
    owner.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, borrowed.retain());
    try std.testing.expectError(error.InvalidBlockPlan, total.Lease.fromAllocator(a));
    try std.testing.expectError(error.InvalidBlockPlan, total.Lease.init(a, null, null, 0));
    try std.testing.expectError(error.OutOfMemory, a.alloc(u8, 1));
    try std.testing.expect(!a.resize(wire, 40));
    try std.testing.expect(a.remap(wire, 40) == null);
    profile.reset();
    try std.testing.expect(a.resize(wire, 24));
    wire = wire.ptr[0..24];
    wire = a.remap(wire, 16).?;
    for (wire) |byte| try std.testing.expectEqual(@as(u8, 0x79), byte);
    a.free(wire);
    try std.testing.expectEqualDeep(total.EncodeMemoryProfile{}, profile);
    try std.testing.expectEqual(@as(usize, 0), fixed.end_index);
}
