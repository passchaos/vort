const std = @import("std");
const total = @import("../total_budget.zig");
const allocator = std.testing.allocator;

test "Brotli total budget defaults and zero cap allocate no extra control" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var disabled = try total.Lease.init(failing.allocator(), null, null, 0);
    defer disabled.deinit();
    try std.testing.expect(!disabled.snapshot().available);
    try std.testing.expect(!total.isTracked(disabled.allocator()));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, total.Lease.init(failing.allocator(), 0, null, 0));
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    var profile: total.EncodeMemoryProfile = .{};
    try std.testing.expectError(error.InvalidBlockPlan, disabled.setProfile(&profile));
    try std.testing.expectError(error.OutOfMemory, total.Lease.init(failing.allocator(), null, &profile, 0));
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectError(error.IntegerOverflow, total.Lease.init(allocator, null, &profile, std.math.maxInt(usize)));
}

test "Brotli total budget counts control exact limits and pure reconfiguration" {
    var profile: total.EncodeMemoryProfile = .{};
    var lease = try total.Lease.init(allocator, total.control_bytes + 32, &profile, 0);
    defer lease.deinit();
    const a = lease.allocator();
    const bytes = try a.alloc(u8, 32);
    defer a.free(bytes);
    @memset(bytes, 0xa5);
    try std.testing.expectEqual(total.control_bytes + 32, lease.snapshot().live_requested_bytes);
    try std.testing.expectError(error.OutOfMemory, a.alloc(u8, 1));
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, lease.translateError(error.OutOfMemory));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, lease.setLimit(total.control_bytes + 31));
    try std.testing.expectEqual(@as(?usize, total.control_bytes + 32), lease.snapshot().limit);
    try std.testing.expectError(error.IntegerOverflow, lease.seedExisting(std.math.maxInt(usize)));
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectEqual(total.control_bytes + 32, profile.peak_requested_bytes);
}

test "Brotli total budget lease move nested sharing and late frees preserve stable state" {
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    var original = try total.Lease.init(failing.allocator(), 4096, null, 0);
    const a = original.allocator();
    const bytes = try a.alloc(u8, 40);
    var moved = original;
    original = undefined;
    const allocated_before = failing.allocated_bytes;
    var child = try total.Lease.init(a, 4096, null, 0);
    try std.testing.expectEqual(allocated_before, failing.allocated_bytes);
    try std.testing.expect(child.isSameAllocator(a));
    try std.testing.expectError(error.InvalidBlockPlan, total.Lease.init(a, 4095, null, 0));
    try std.testing.expectError(error.InvalidBlockPlan, total.Lease.init(a, 4096, null, 1));
    var retained = (try total.Lease.fromAllocator(a)).?;
    child.deinit();
    retained.deinit();
    moved.deinit();
    // The allocator itself remains usable for freeing its outstanding bytes.
    a.free(bytes);
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

test "Brotli total budget adopts reusable storage and external releases exactly once" {
    const old = try allocator.alloc(u8, 24);
    var lease = try total.Lease.init(allocator, total.control_bytes + 64, null, 24);
    defer lease.deinit();
    try std.testing.expectEqual(total.control_bytes + 24, lease.snapshot().live_requested_bytes);
    lease.allocator().free(old);
    try std.testing.expectEqual(total.control_bytes, lease.snapshot().live_requested_bytes);
    try lease.reserveExisting(8);
    const external = allocator.alloc(u8, 8) catch |err| {
        lease.releaseExisting(8);
        return err;
    };
    allocator.free(external);
    lease.releaseExisting(8);
    try std.testing.expectEqual(total.control_bytes, lease.snapshot().live_requested_bytes);
}

test "Brotli total budget returned wire detaches only to its real backing owner" {
    var profile: total.EncodeMemoryProfile = .{};
    var lease = try total.Lease.init(allocator, null, &profile, 0);
    const a = lease.allocator();
    const wire = try a.alloc(u8, 31);
    @memset(wire, 0x79);
    try lease.releaseToCaller(a, wire.len);
    try std.testing.expectEqual(total.control_bytes + wire.len, lease.snapshot().live_requested_bytes);
    var storage: [128]u8 = undefined;
    var other = std.heap.FixedBufferAllocator.init(&storage);
    try std.testing.expectError(error.InvalidBlockPlan, lease.releaseToCaller(other.allocator(), wire.len));
    try std.testing.expectEqual(total.control_bytes + wire.len, lease.snapshot().live_requested_bytes);
    try lease.releaseToCaller(allocator, wire.len);
    lease.deinit();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    allocator.free(wire);

    // PageAllocator deliberately has an undefined ptr, so identity must use
    // its known singleton vtable without inspecting that pointer value.
    var page_lease = try total.Lease.init(std.heap.page_allocator, null, &profile, 0);
    const page_wire = try page_lease.allocator().alloc(u8, 5);
    try page_lease.releaseToCaller(std.heap.page_allocator, 5);
    page_lease.deinit();
    std.heap.page_allocator.free(page_wire);
}

test "Brotli total budget resize remap and fallback realloc charge actual live bytes" {
    var storage: [1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var lease = try total.Lease.init(fixed.allocator(), total.control_bytes + 72, null, 0);
    defer lease.deinit();
    const a = lease.allocator();
    var bytes = try a.alloc(u8, 32);
    const guard = try a.alloc(u8, 8);
    try std.testing.expectError(error.OutOfMemory, a.realloc(bytes, 64));
    try std.testing.expectEqual(total.control_bytes + 40, lease.snapshot().live_requested_bytes);
    try lease.setLimit(total.control_bytes + 104);
    bytes = try a.realloc(bytes, 64);
    try std.testing.expectEqual(total.control_bytes + 104, lease.snapshot().peak_requested_bytes);
    try std.testing.expectEqual(total.control_bytes + 72, lease.snapshot().live_requested_bytes);
    a.free(guard);
    a.free(bytes);
    var in_place = try a.alloc(u8, 16);
    try std.testing.expect(a.resize(in_place, 32));
    in_place = in_place.ptr[0..32];
    in_place = a.remap(in_place, 24).?;
    try std.testing.expectEqual(total.control_bytes + 24, lease.snapshot().live_requested_bytes);
    a.free(in_place);
}

test "Brotli total budget owner begins a fresh backing-failure classification" {
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    var lease = try total.Lease.init(failing.allocator(), total.control_bytes + 32, null, 0);
    defer lease.deinit();
    const a = lease.allocator();
    try std.testing.expectError(error.OutOfMemory, a.alloc(u8, 33));
    try std.testing.expect(lease.snapshot().last_failure_was_limit);
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, lease.translateError(error.OutOfMemory));
    lease.beginOperation();
    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, a.alloc(u8, 16));
    try std.testing.expect(!lease.snapshot().last_failure_was_limit);
    try std.testing.expectEqual(error.OutOfMemory, lease.translateError(error.OutOfMemory));
    try std.testing.expectEqual(total.control_bytes, lease.snapshot().live_requested_bytes);
}

test {
    _ = @import("sticky_tests.zig");
}

test "Brotli total budget profiles reset at current live bytes and merge ordered snapshots" {
    var profile: total.EncodeMemoryProfile = .{};
    var lease = try total.Lease.init(allocator, null, &profile, 0);
    defer lease.deinit();
    const bytes = try lease.allocator().alloc(u8, 32);
    lease.allocator().free(bytes);
    profile.reset();
    try lease.setProfile(&profile);
    try std.testing.expectEqual(total.control_bytes, profile.peak_requested_bytes);
    try std.testing.expectEqual(total.control_bytes + 32, lease.snapshot().peak_requested_bytes);
    profile.merge(.{ .available = true, .peak_requested_bytes = 500, .live_requested_bytes = 200, .limit = 600 });
    try std.testing.expectEqual(@as(usize, 500), profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 200), profile.live_requested_bytes);
    try std.testing.expectEqual(@as(?usize, 600), profile.limit);
    try lease.setProfile(null);
}

test "Brotli total budget owned control and payload clean every allocation failure" {
    const Graph = struct {
        pub fn run(a: std.mem.Allocator) !void {
            var lease = try total.Lease.init(a, total.control_bytes + 32, null, 0);
            defer lease.deinit();
            const bytes = try lease.allocator().alloc(u8, 32);
            defer lease.allocator().free(bytes);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Graph.run, .{});
}

test "Brotli total budget nested profiles cannot escape their ownership scope" {
    var lease = try total.Lease.init(allocator, 4096, null, 0);
    defer lease.deinit();
    const Scope = struct {
        fn check(a: std.mem.Allocator) !void {
            var temporary: total.EncodeMemoryProfile = .{};
            try std.testing.expectError(error.InvalidBlockPlan, total.Lease.init(a, null, &temporary, 0));
            try std.testing.expectEqualDeep(total.EncodeMemoryProfile{}, temporary);
        }
    };
    try Scope.check(lease.allocator());
    const later = try lease.allocator().alloc(u8, 9);
    lease.allocator().free(later);
    try std.testing.expectEqual(total.control_bytes, lease.snapshot().live_requested_bytes);
    var profile: total.EncodeMemoryProfile = .{};
    try lease.setProfile(&profile);
    var inherited = try total.Lease.init(lease.allocator(), null, &profile, 0);
    inherited.deinit();
    try std.testing.expectEqual(total.control_bytes, profile.live_requested_bytes);
    try lease.setProfile(null);
}

test "Brotli total budget external reservations count actual cross-allocator heaps only" {
    var profile: total.EncodeMemoryProfile = .{};
    var lease = try total.Lease.init(allocator, total.control_bytes + 40, &profile, 0);
    defer lease.deinit();
    const body = try lease.allocator().alloc(u8, 16);
    defer lease.allocator().free(body);
    var denied = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var reservation = try lease.tryReserveExternal(24);
    try std.testing.expectEqual(total.control_bytes + 16, profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 24), lease.snapshot().reserved_bytes);
    try std.testing.expectError(error.OutOfMemory, denied.allocator().alloc(u8, 24));
    reservation.deinit();
    try std.testing.expectEqual(@as(usize, 0), lease.snapshot().reserved_bytes);
    try std.testing.expectEqual(total.control_bytes + 16, profile.peak_requested_bytes);

    var target_storage: [64]u8 = undefined;
    var target = std.heap.FixedBufferAllocator.init(&target_storage);
    var successful = try lease.tryReserveExternal(24);
    defer successful.deinit();
    try std.testing.expectError(error.OutOfMemory, lease.allocator().alloc(u8, 1));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, lease.setLimit(total.control_bytes + 39));
    const wire = try target.allocator().alloc(u8, 24);
    successful.markAllocated();
    try std.testing.expectEqual(total.control_bytes + 40, lease.snapshot().live_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), lease.snapshot().reserved_bytes);
    try std.testing.expectEqual(total.control_bytes + 40, profile.peak_requested_bytes);
    successful.handoff();
    try std.testing.expectEqual(total.control_bytes + 16, profile.live_requested_bytes);
    target.allocator().free(wire);
    lease.beginOperation();
    try std.testing.expect(lease.snapshot().hit_limit);
    try std.testing.expect(!lease.snapshot().last_failure_was_limit);
}

test "Brotli total budget rejects mismatched backing contexts with an identical vtable" {
    var first_bytes: [512]u8 = undefined;
    var second_bytes: [512]u8 = undefined;
    var first = std.heap.FixedBufferAllocator.init(&first_bytes);
    var second = std.heap.FixedBufferAllocator.init(&second_bytes);
    var lease = try total.Lease.init(first.allocator(), 512, null, 0);
    defer lease.deinit();
    const payload = try lease.allocator().alloc(u8, 8);
    defer lease.allocator().free(payload);
    try std.testing.expectError(error.InvalidBlockPlan, lease.releaseToCaller(second.allocator(), 8));
    try std.testing.expectEqual(total.control_bytes + 8, lease.snapshot().live_requested_bytes);
}
