const std = @import("std");
const memory = @import("stored_memory_owner.zig");
const total = @import("total_budget.zig");
const allocator = std.testing.allocator;
const Options = struct {
    max_total_working_memory: ?usize = null,
    memory_profile: ?*total.EncodeMemoryProfile = null,
};

test "Brotli stored memory owner disabled operations retain no authority or control" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var owner: memory.Owner = .{};
    defer owner.deinit();
    var scope = try memory.begin(&owner, failing.allocator(), Options{}, std.math.maxInt(usize));
    defer scope.deinit();
    try std.testing.expect(!total.isTracked(scope.allocator()));
    try std.testing.expectEqual(@as(usize, 0), owner.ownedControlBytes());
    scope.commit();
    try std.testing.expect(owner.lease == null);
    try std.testing.expect(!owner.inherited);
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
}

test "Brotli stored memory owner failed activation rolls back exact retained capacity" {
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    const backing = failing.allocator();
    const old = try backing.alloc(u8, 48);
    @memset(old, 0x79);
    var owner: memory.Owner = .{};
    var profile: total.EncodeMemoryProfile = .{};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, memory.begin(&owner, backing, Options{
        .max_total_working_memory = total.control_bytes + old.len - 1,
    }, old.len));
    try std.testing.expect(owner.lease == null);
    var scope = try memory.begin(&owner, backing, Options{
        .max_total_working_memory = total.control_bytes + old.len + 16,
        .memory_profile = &profile,
    }, old.len);
    try std.testing.expect(owner.lease == null);
    try std.testing.expectEqual(total.control_bytes + old.len, scope.lease.snapshot().live_requested_bytes);
    const temporary = try scope.allocator().alloc(u8, 16);
    try std.testing.expectError(error.OutOfMemory, scope.allocator().alloc(u8, 1));
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, scope.mapError(error.OutOfMemory));
    scope.allocator().free(temporary);
    scope.deinit();
    try std.testing.expect(owner.lease == null);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    for (old) |byte| try std.testing.expectEqual(@as(u8, 0x79), byte);
    backing.free(old);
    owner.deinit();
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

test "Brotli stored memory owner committed adoption moves safely and detaches call profile" {
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    const backing = failing.allocator();
    const old = try backing.alloc(u8, 64);
    var original: memory.Owner = .{};
    var profile: total.EncodeMemoryProfile = .{};
    var scope = try memory.begin(&original, backing, Options{ .memory_profile = &profile }, old.len);
    const replacement = try scope.allocator().alloc(u8, 24);
    @memset(replacement, 0xa5);
    scope.allocator().free(old);
    scope.commit();
    scope.deinit();
    try std.testing.expectEqual(total.control_bytes, original.ownedControlBytes());
    try std.testing.expectEqual(total.control_bytes + replacement.len, profile.live_requested_bytes);
    const profile_after_call = profile;
    var moved = original;
    original = undefined;
    const current = moved.current(backing);
    const later = try current.alloc(u8, 3);
    current.free(later);
    try std.testing.expectEqualDeep(profile_after_call, profile);
    for (replacement) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    current.free(replacement);
    moved.deinit();
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

test "Brotli stored memory owner existing failure restores cap and existing success keeps cap" {
    var owner: memory.Owner = .{};
    const old = try allocator.alloc(u8, 32);
    const initial_limit = total.control_bytes + 128;
    var first = try memory.begin(&owner, allocator, Options{ .max_total_working_memory = initial_limit }, old.len);
    first.commit();
    first.deinit();
    var profile: total.EncodeMemoryProfile = .{};
    var failed = try memory.begin(&owner, allocator, Options{
        .max_total_working_memory = total.control_bytes + 48,
        .memory_profile = &profile,
    }, old.len);
    const temporary = try failed.allocator().alloc(u8, 16);
    try std.testing.expectError(error.OutOfMemory, failed.allocator().alloc(u8, 1));
    failed.allocator().free(temporary);
    failed.deinit();
    try std.testing.expectEqual(@as(?usize, initial_limit), owner.lease.?.snapshot().limit);
    const profile_after_call = profile;
    var successful = try memory.begin(&owner, allocator, Options{
        .max_total_working_memory = total.control_bytes + old.len,
    }, old.len);
    successful.commit();
    successful.deinit();
    try std.testing.expectEqual(@as(?usize, total.control_bytes + old.len), owner.lease.?.snapshot().limit);
    try std.testing.expectEqualDeep(profile_after_call, profile);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, memory.begin(&owner, allocator, Options{
        .max_total_working_memory = total.control_bytes + old.len - 1,
    }, old.len));
    try std.testing.expectEqual(@as(?usize, total.control_bytes + old.len), owner.lease.?.snapshot().limit);
    owner.current(allocator).free(old);
    owner.deinit();
}

test "Brotli stored memory owner inherited authority preserves outer profile cap and lifetime" {
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    var profile: total.EncodeMemoryProfile = .{};
    const limit = total.control_bytes + 80;
    var outer = try total.Lease.init(failing.allocator(), limit, &profile, 0);
    const tracked = outer.allocator();
    const retained = try tracked.alloc(u8, 24);
    var owner: memory.Owner = .{};
    var first = try memory.begin(&owner, tracked, Options{}, std.math.maxInt(usize));
    first.commit();
    first.deinit();
    try std.testing.expect(owner.inherited);
    try std.testing.expectEqual(@as(usize, 0), owner.ownedControlBytes());
    try std.testing.expectEqual(total.control_bytes + retained.len, profile.live_requested_bytes);
    var forbidden: total.EncodeMemoryProfile = .{};
    try std.testing.expectError(error.InvalidBlockPlan, memory.begin(&owner, tracked, Options{
        .memory_profile = &forbidden,
    }, 0));
    try std.testing.expectEqualDeep(total.EncodeMemoryProfile{}, forbidden);
    try std.testing.expectError(error.InvalidBlockPlan, memory.begin(&owner, tracked, Options{
        .max_total_working_memory = limit - 1,
    }, 0));
    outer.deinit();
    var next = try memory.begin(&owner, tracked, Options{
        .max_total_working_memory = limit,
        .memory_profile = &profile,
    }, 0);
    const temporary = try next.allocator().alloc(u8, 8);
    next.allocator().free(temporary);
    next.deinit();
    try std.testing.expectEqual(@as(?usize, limit), owner.lease.?.snapshot().limit);
    const later = try owner.current(tracked).alloc(u8, 9);
    try std.testing.expectEqual(total.control_bytes + retained.len + later.len, profile.live_requested_bytes);
    owner.current(tracked).free(later);
    owner.current(tracked).free(retained);
    owner.deinit();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

test "Brotli stored memory owner rejected inherited activation does not detach outer profile" {
    var profile: total.EncodeMemoryProfile = .{};
    var outer = try total.Lease.init(allocator, 4096, &profile, 0);
    defer outer.deinit();
    var owner: memory.Owner = .{};
    defer owner.deinit();
    var scope = try memory.begin(&owner, outer.allocator(), Options{}, 0);
    const temporary = try scope.allocator().alloc(u8, 7);
    scope.allocator().free(temporary);
    scope.deinit();
    try std.testing.expect(owner.lease == null);
    const later = try outer.allocator().alloc(u8, 11);
    try std.testing.expectEqual(total.control_bytes + later.len, profile.live_requested_bytes);
    outer.allocator().free(later);
}

test "Brotli stored memory owner rejects changed backing and distinguishes backing allocation failure" {
    var first_backing = std.testing.FailingAllocator.init(allocator, .{});
    var other_backing = std.testing.FailingAllocator.init(allocator, .{});
    var owner: memory.Owner = .{};
    var initial = try memory.begin(&owner, first_backing.allocator(), Options{
        .max_total_working_memory = total.control_bytes + 32,
    }, 0);
    initial.commit();
    initial.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, memory.begin(&owner, other_backing.allocator(), Options{}, 0));
    var scope = try memory.begin(&owner, first_backing.allocator(), Options{
        .max_total_working_memory = total.control_bytes + 16,
    }, 0);
    try std.testing.expectError(error.OutOfMemory, scope.allocator().alloc(u8, 17));
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, scope.mapError(error.OutOfMemory));
    scope.deinit();
    var later = try memory.begin(&owner, first_backing.allocator(), Options{
        .max_total_working_memory = total.control_bytes + 16,
    }, 0);
    first_backing.fail_index = first_backing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, later.allocator().alloc(u8, 16));
    try std.testing.expectEqual(error.OutOfMemory, later.mapError(error.OutOfMemory));
    try std.testing.expectEqual(error.OutputTooSmall, later.mapError(error.OutputTooSmall));
    try std.testing.expectEqual(error.InvalidBlockPlan, later.mapError(error.UnexpectedTestError));
    later.deinit();
    owner.deinit();
    try std.testing.expectEqual(first_backing.allocated_bytes, first_backing.freed_bytes);
    try std.testing.expectEqual(@as(usize, 0), other_backing.allocated_bytes);
}

test "Brotli stored memory owner activation cleans every backing allocation failure" {
    const Graph = struct {
        fn run(backing: std.mem.Allocator) !void {
            const old = try backing.alloc(u8, 48);
            defer backing.free(old);
            var owner: memory.Owner = .{};
            defer owner.deinit();
            var scope = try memory.begin(&owner, backing, Options{
                .max_total_working_memory = total.control_bytes + 64,
            }, old.len);
            defer scope.deinit();
            const temporary = try scope.allocator().alloc(u8, 16);
            defer scope.allocator().free(temporary);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Graph.run, .{});
}
