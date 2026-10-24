const std = @import("std");
const builtin = @import("builtin");
const total = @import("../requested_heap_budget.zig");
const allocator = std.testing.allocator;

test "requested heap budget default zero and control allocation semantics" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var disabled = try total.Lease.init(failing.allocator(), null, null, 0);
    defer disabled.deinit();
    try std.testing.expect(disabled.allocator().ptr == failing.allocator().ptr);
    try std.testing.expect(disabled.allocator().vtable == failing.allocator().vtable);
    try std.testing.expect(!disabled.snapshot().available);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, total.Lease.init(failing.allocator(), 0, null, 0));
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    var profile: total.EncodeMemoryProfile = .{};
    try std.testing.expectError(error.OutOfMemory, total.Lease.init(failing.allocator(), null, &profile, 0));
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(@as(usize, 0), profile.peak_requested_bytes);
    try std.testing.expectError(error.IntegerOverflow, total.Lease.init(allocator, null, &profile, std.math.maxInt(usize)));
}

test "requested heap budget exact cap and profile only count actual requested bytes" {
    var profile: total.EncodeMemoryProfile = .{};
    var lease = try total.Lease.init(allocator, total.control_bytes + 32, &profile, 0);
    const a = lease.allocator();
    const bytes = try a.alloc(u8, 32);
    try std.testing.expectEqual(total.control_bytes + 32, lease.snapshot().live_requested_bytes);
    try std.testing.expectError(error.OutOfMemory, a.alloc(u8, 1));
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, lease.translateError(error.OutOfMemory));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, lease.configure(total.control_bytes + 31, null));
    try std.testing.expectEqual(@as(?usize, total.control_bytes + 32), lease.snapshot().limit);
    try std.testing.expectError(error.IntegerOverflow, lease.seedExisting(std.math.maxInt(usize)));
    a.free(bytes);
    lease.deinit();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectEqual(total.control_bytes + 32, profile.peak_requested_bytes);

    profile.reset();
    var unlimited = try total.Lease.init(allocator, null, &profile, 0);
    const large = try unlimited.allocator().alloc(u8, 4096);
    try std.testing.expectEqual(@as(?usize, null), unlimited.snapshot().limit);
    try std.testing.expectEqual(total.control_bytes + 4096, profile.peak_requested_bytes);
    unlimited.allocator().free(large);
    unlimited.deinit();
}

test "requested heap budget borrowed policy and operation classification cannot change owner" {
    var profile: total.EncodeMemoryProfile = .{};
    var replacement: total.EncodeMemoryProfile = .{};
    var owner = try total.Lease.init(allocator, total.control_bytes + 32, &profile, 0);
    defer owner.deinit();
    var child = try total.Lease.init(owner.allocator(), null, null, 0);
    defer child.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, total.Lease.init(owner.allocator(), null, &replacement, 0));
    try std.testing.expectError(error.InvalidBlockPlan, total.Lease.init(owner.allocator(), null, null, 1));
    try std.testing.expectError(error.OutOfMemory, child.allocator().alloc(u8, 33));
    child.beginOperation();
    try child.configure(null, null);
    try std.testing.expectError(error.InvalidBlockPlan, child.setLimit(null));
    try std.testing.expectError(error.InvalidBlockPlan, child.setProfile(null));
    try std.testing.expectError(error.InvalidBlockPlan, child.configure(null, &replacement));
    try std.testing.expect(owner.snapshot().hit_limit);
    try std.testing.expect(owner.snapshot().last_failure_was_limit);
    try std.testing.expectEqual(@as(?usize, total.control_bytes + 32), owner.snapshot().limit);
    const success = try child.allocator().alloc(u8, 16);
    child.allocator().free(success);
    try std.testing.expect(owner.snapshot().last_failure_was_limit);
    try std.testing.expectEqual(total.EncodeMemoryProfile{}, replacement);
    owner.beginOperation();
    try std.testing.expect(!owner.snapshot().hit_limit);
    try std.testing.expect(!owner.snapshot().last_failure_was_limit);
}

test "requested heap budget sibling refusal remains sticky after concurrent successful allocation" {
    if (builtin.single_threaded) return error.SkipZigTest;
    var owner = try total.Lease.init(allocator, total.control_bytes + 32, null, 0);
    defer owner.deinit();
    var first = try owner.retain();
    defer first.deinit();
    var second = try owner.retain();
    defer second.deinit();
    const Context = struct {
        first: total.Lease,
        second: total.Lease,
        stage: std.atomic.Value(u8) = .init(0),
        refused: bool = false,
        succeeded: bool = false,
        fn refuse(self: *@This()) void {
            if (self.first.allocator().alloc(u8, 33)) |bytes| {
                self.first.allocator().free(bytes);
            } else |err| self.refused = err == error.OutOfMemory;
            self.stage.store(1, .release);
        }
        fn succeed(self: *@This()) void {
            while (self.stage.load(.acquire) == 0) std.atomic.spinLoopHint();
            self.second.beginOperation();
            if (self.second.allocator().alloc(u8, 16)) |bytes| {
                self.succeeded = true;
                self.second.allocator().free(bytes);
            } else |_| {}
        }
    };
    var context: Context = .{ .first = first, .second = second };
    const rejecting = try std.Thread.spawn(.{}, Context.refuse, .{&context});
    const successful = std.Thread.spawn(.{}, Context.succeed, .{&context}) catch |err| {
        rejecting.join();
        return err;
    };
    rejecting.join();
    successful.join();
    try std.testing.expect(context.refused and context.succeeded);
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, first.translateError(error.OutOfMemory));
    try std.testing.expect(owner.snapshot().hit_limit and owner.snapshot().last_failure_was_limit);
}

test "requested heap budget physical OOM remains OOM in a new owner operation" {
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    var owner = try total.Lease.init(failing.allocator(), total.control_bytes + 32, null, 0);
    defer owner.deinit();
    try std.testing.expectError(error.OutOfMemory, owner.allocator().alloc(u8, 33));
    owner.beginOperation();
    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, owner.allocator().alloc(u8, 16));
    try std.testing.expectEqual(error.OutOfMemory, owner.translateError(error.OutOfMemory));
    try std.testing.expect(!owner.snapshot().hit_limit);
    try std.testing.expectEqual(total.control_bytes, owner.snapshot().peak_requested_bytes);
}

test "requested heap budget concurrent admissions cannot exceed one shared cap" {
    if (builtin.single_threaded) return error.SkipZigTest;
    var owner = try total.Lease.init(allocator, total.control_bytes + 24, null, 0);
    defer owner.deinit();
    const Context = struct {
        a: std.mem.Allocator,
        arrivals: std.atomic.Value(u8) = .init(0),
        admitted: [2]bool = .{ false, false },
        fn allocate(self: *@This(), index: usize) void {
            const bytes = self.a.alloc(u8, 24) catch null;
            self.admitted[index] = bytes != null;
            _ = self.arrivals.fetchAdd(1, .acq_rel);
            while (self.arrivals.load(.acquire) < 2) std.atomic.spinLoopHint();
            if (bytes) |memory| self.a.free(memory);
        }
    };
    var context: Context = .{ .a = owner.allocator() };
    const first = try std.Thread.spawn(.{}, Context.allocate, .{ &context, 0 });
    const second = std.Thread.spawn(.{}, Context.allocate, .{ &context, 1 }) catch |err| {
        _ = context.arrivals.fetchAdd(1, .acq_rel);
        first.join();
        return err;
    };
    first.join();
    second.join();
    try std.testing.expect(context.admitted[0] != context.admitted[1]);
    try std.testing.expectEqual(total.control_bytes + 24, owner.snapshot().peak_requested_bytes);
    try std.testing.expectEqual(total.control_bytes, owner.snapshot().live_requested_bytes);
}

test "requested heap budget move and final lease close allow exact late frees" {
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    var original = try total.Lease.init(failing.allocator(), 4096, null, 0);
    const a = original.allocator();
    const bytes = try a.alloc(u8, 40);
    var moved = original;
    original = undefined;
    const allocated_before = failing.allocated_bytes;
    var child = (try total.Lease.fromAllocator(a)).?;
    try std.testing.expectEqual(allocated_before, failing.allocated_bytes);
    moved.deinit();
    child.deinit();
    a.free(bytes);
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

test "requested heap budget adopts exact capacity and transfers owned bytes to backing" {
    const retained = try allocator.alloc(u8, 24);
    var profile: total.EncodeMemoryProfile = .{};
    var owner = try total.Lease.init(allocator, null, &profile, retained.len);
    try std.testing.expectEqual(total.control_bytes + retained.len, owner.snapshot().live_requested_bytes);
    owner.allocator().free(retained);
    const wire = try owner.allocator().alloc(u8, 31);
    try owner.releaseToCaller(owner.allocator(), wire.len);
    try std.testing.expectEqual(total.control_bytes + 31, owner.snapshot().live_requested_bytes);
    var storage: [128]u8 = undefined;
    var other = std.heap.FixedBufferAllocator.init(&storage);
    try std.testing.expectError(error.InvalidBlockPlan, owner.releaseToCaller(other.allocator(), wire.len));
    try owner.releaseToCaller(allocator, wire.len);
    owner.deinit();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    allocator.free(wire);

    var page_owner = try total.Lease.init(std.heap.page_allocator, null, &profile, 0);
    const page_wire = try page_owner.allocator().alloc(u8, 5);
    try page_owner.releaseToCaller(std.heap.page_allocator, 5);
    page_owner.deinit();
    std.heap.page_allocator.free(page_wire);
}

test "requested heap budget cross allocator reservations count successful physical heap only" {
    var profile: total.EncodeMemoryProfile = .{};
    var owner = try total.Lease.init(allocator, total.control_bytes + 40, &profile, 0);
    defer owner.deinit();
    const body = try owner.allocator().alloc(u8, 16);
    defer owner.allocator().free(body);
    var denied = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var reservation = try owner.tryReserveExternal(24);
    try std.testing.expectEqual(total.control_bytes + 16, profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 24), owner.snapshot().reserved_bytes);
    try std.testing.expectError(error.OutOfMemory, denied.allocator().alloc(u8, 24));
    reservation.deinit();
    try std.testing.expectEqual(@as(usize, 0), owner.snapshot().reserved_bytes);
    try std.testing.expectEqual(total.control_bytes + 16, profile.peak_requested_bytes);

    var target_storage: [64]u8 = undefined;
    var target = std.heap.FixedBufferAllocator.init(&target_storage);
    var successful = try owner.tryReserveExternal(24);
    try std.testing.expectError(error.OutOfMemory, owner.allocator().alloc(u8, 1));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, owner.setLimit(total.control_bytes + 39));
    const wire = try target.allocator().alloc(u8, 24);
    successful.markAllocated();
    try std.testing.expectEqual(total.control_bytes + 40, profile.peak_requested_bytes);
    successful.handoff();
    successful.deinit();
    try std.testing.expectEqual(total.control_bytes + 16, owner.snapshot().live_requested_bytes);
    target.allocator().free(wire);
}

test "requested heap budget reservation retains control after owner move and close" {
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    var owner = try total.Lease.init(failing.allocator(), 4096, null, 0);
    var reservation = try owner.tryReserveExternal(16);
    owner.deinit();
    try std.testing.expectEqual(@as(usize, 0), failing.freed_bytes);
    reservation.deinit();
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

test "requested heap budget resize remap and fallback realloc count physical overlapping payload" {
    var storage: [1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var owner = try total.Lease.init(fixed.allocator(), total.control_bytes + 72, null, 0);
    defer owner.deinit();
    const a = owner.allocator();
    var bytes = try a.alloc(u8, 32);
    const guard = try a.alloc(u8, 8);
    try std.testing.expectError(error.OutOfMemory, a.realloc(bytes, 64));
    try std.testing.expectEqual(total.control_bytes + 40, owner.snapshot().live_requested_bytes);
    try owner.setLimit(total.control_bytes + 104);
    bytes = try a.realloc(bytes, 64);
    try std.testing.expectEqual(total.control_bytes + 104, owner.snapshot().peak_requested_bytes);
    try std.testing.expectEqual(total.control_bytes + 72, owner.snapshot().live_requested_bytes);
    a.free(guard);
    a.free(bytes);
    var in_place = try a.alloc(u8, 16);
    try std.testing.expect(a.resize(in_place, 32));
    in_place = in_place.ptr[0..32];
    in_place = a.remap(in_place, 24).?;
    try std.testing.expectEqual(total.control_bytes + 24, owner.snapshot().live_requested_bytes);
    a.free(in_place);
}

test "requested heap budget profile snapshots merge in observation order" {
    var profile: total.EncodeMemoryProfile = .{};
    var owner = try total.Lease.init(allocator, null, &profile, 0);
    defer owner.deinit();
    const bytes = try owner.allocator().alloc(u8, 32);
    owner.allocator().free(bytes);
    profile.reset();
    try owner.setProfile(&profile);
    try std.testing.expectEqual(total.control_bytes, profile.peak_requested_bytes);
    try std.testing.expectEqual(total.control_bytes + 32, owner.snapshot().peak_requested_bytes);
    profile.merge(.{ .available = true, .peak_requested_bytes = 500, .live_requested_bytes = 200, .limit = 600 });
    profile.merge(.{ .available = true, .peak_requested_bytes = 300, .live_requested_bytes = 150, .limit = null });
    try std.testing.expectEqual(@as(usize, 500), profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 150), profile.live_requested_bytes);
    try std.testing.expectEqual(@as(?usize, null), profile.limit);
    try owner.setProfile(null);
}

test "requested heap budget each control and payload failure releases all ownership" {
    const Graph = struct {
        fn run(a: std.mem.Allocator) !void {
            var owner = try total.Lease.init(a, total.control_bytes + 32, null, 0);
            defer owner.deinit();
            const bytes = try owner.allocator().alloc(u8, 32);
            defer owner.allocator().free(bytes);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Graph.run, .{});
}
