const std = @import("std");
const storage = @import("command_storage.zig");
const tracking = @import("../../../tests/br_total_memory_helpers.zig");
const working = @import("../../../io/working_allocator.zig");
const total = @import("../total_budget.zig");

test "Brotli HQ command storage empty ownership is allocation free" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var builder = storage.Builder.init(failing.allocator());
    defer builder.deinit();
    builder.reverseSuffix(0);
    try std.testing.expectEqual(@as(usize, 0), builder.items().len);
    try std.testing.expectEqual(@as(usize, 0), builder.allocatedBytes());
    const owned = try builder.finishOwned();
    defer failing.allocator().free(owned);
    try std.testing.expectEqual(@as(usize, 0), owned.len);
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
}

test "Brotli HQ command storage tiny final allocation is exact and preserves traceback order" {
    var ledger = tracking.TrackingAllocator.init(std.testing.allocator);
    // Force finalization through the allocate-copy-free path, so the old and
    // exact buffers' simultaneously live requested bytes are independently seen.
    ledger.fail_remap_after = 0;
    var builder = storage.Builder.init(ledger.allocator());
    defer builder.deinit();
    try builder.append(command(0));
    try builder.append(command(2));
    try builder.append(command(1));
    try std.testing.expectEqual(storage.initial_capacity, builder.capacity());
    try std.testing.expectEqual(@as(usize, 3), builder.items().len);
    builder.reverseSuffix(1);
    builder.items()[2].insert_len = 77;
    const original = builder.items().ptr;
    const owned = try builder.finishOwned();
    try std.testing.expect(original != owned.ptr);
    try std.testing.expectEqual(@as(usize, 3), owned.len);
    try std.testing.expectEqual(@as(usize, 0), builder.capacity());
    try std.testing.expectEqual(@as(usize, 0), builder.items().len);
    try std.testing.expectEqual(@as(usize, 0), owned[0].insert_start);
    try std.testing.expectEqual(@as(usize, 1), owned[1].insert_start);
    try std.testing.expectEqual(@as(usize, 2), owned[2].insert_start);
    try std.testing.expectEqual(@as(usize, 77), owned[2].insert_len);
    try std.testing.expectEqual(3 * @sizeOf(storage.Command), ledger.live);
    try std.testing.expectEqual((storage.initial_capacity + 3) * @sizeOf(storage.Command), ledger.peak);
    ledger.allocator().free(owned);
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    // Transferring ownership does not consume or disable the movable builder.
    try builder.append(command(9));
    try std.testing.expectEqual(@as(usize, 9), builder.items()[0].insert_start);
}

test "Brotli HQ command storage geometric growth keeps 8192 commands and returns its full allocation" {
    var ledger = tracking.TrackingAllocator.init(std.testing.allocator);
    ledger.force_moving_growth = true;
    var builder = storage.Builder.init(ledger.allocator());
    defer builder.deinit();
    const count: usize = 8192;
    for (0..count) |index| try builder.append(command(index));
    try std.testing.expectEqual(count, builder.capacity());
    try std.testing.expectEqual(count, builder.items().len);
    try std.testing.expectEqual(count * @sizeOf(storage.Command), ledger.live);
    try std.testing.expectEqual((count + count / 2) * @sizeOf(storage.Command), ledger.peak);
    const original = builder.items().ptr;
    var moved = builder;
    builder = storage.Builder.init(ledger.allocator());
    defer moved.deinit();
    const owned = try moved.finishOwned();
    try std.testing.expect(owned.ptr == original);
    for (owned, 0..) |actual, index| try std.testing.expectEqual(command(index), actual);
    ledger.allocator().free(owned);
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    try std.testing.expectEqual(ledger.allocated_bytes, ledger.freed_bytes);
}

test "Brotli HQ command storage successful shrinking remap transfers exact live bytes" {
    var memory: [4096]u8 align(@alignOf(storage.Command)) = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&memory);
    var ledger = tracking.TrackingAllocator.init(fixed.allocator());
    var builder = storage.Builder.init(ledger.allocator());
    defer builder.deinit();
    for (0..3) |index| try builder.append(command(index));
    const pointer = builder.items().ptr;
    const owned = try builder.finishOwned();
    try std.testing.expect(owned.ptr == pointer);
    try std.testing.expectEqual(3 * @sizeOf(storage.Command), ledger.live);
    try std.testing.expectEqual(storage.initial_capacity * @sizeOf(storage.Command), ledger.peak);
    try std.testing.expectEqual(@as(usize, 1), ledger.alloc_attempts);
    for (owned, 0..) |actual, index| try std.testing.expectEqual(command(index), actual);
    ledger.allocator().free(owned);
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
}

test "Brotli HQ command storage every allocation failure preserves all accepted commands" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, everyAllocation, .{});
}

fn everyAllocation(a: std.mem.Allocator) !void {
    var ledger = tracking.TrackingAllocator.init(a);
    ledger.fail_remap_after = 0;
    var builder = storage.Builder.init(ledger.allocator());
    defer builder.deinit();
    for (0..257) |index| {
        const before_pointer = builder.items().ptr;
        const before_capacity = builder.capacity();
        const before_bytes = builder.allocatedBytes();
        builder.append(command(index)) catch |err| {
            try std.testing.expectEqual(index, builder.items().len);
            try std.testing.expectEqual(before_capacity, builder.capacity());
            try std.testing.expectEqual(before_bytes, builder.allocatedBytes());
            try std.testing.expect(builder.items().ptr == before_pointer);
            for (builder.items(), 0..) |actual, accepted| try std.testing.expectEqual(command(accepted), actual);
            return err;
        };
    }
    const before_pointer = builder.items().ptr;
    const before_capacity = builder.capacity();
    const owned = builder.finishOwned() catch |err| {
        try std.testing.expectEqual(@as(usize, 257), builder.items().len);
        try std.testing.expectEqual(before_capacity, builder.capacity());
        try std.testing.expect(builder.items().ptr == before_pointer);
        for (builder.items(), 0..) |actual, accepted| try std.testing.expectEqual(command(accepted), actual);
        return err;
    };
    ledger.allocator().free(owned);
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
}

test "Brotli HQ command storage nested budgets charge fallback growth and keep the old sequence on denial" {
    const unit = @sizeOf(storage.Command);
    const old_bytes = storage.initial_capacity * unit;
    const grown_bytes = storage.initial_capacity * 2 * unit;
    var ledger = tracking.TrackingAllocator.init(std.testing.allocator);
    ledger.force_moving_growth = true;
    var profile: total.EncodeMemoryProfile = .{};
    var lease = try total.Lease.init(ledger.allocator(), total.control_bytes + old_bytes + grown_bytes - 1, &profile, 0);
    defer lease.deinit();
    var workspace = working.WorkingAllocator.init(lease.allocator(), old_bytes + grown_bytes);
    var builder = storage.Builder.init(workspace.allocator());
    defer builder.deinit();
    for (0..storage.initial_capacity) |index| try builder.append(command(index));
    const pointer = builder.items().ptr;
    try std.testing.expectError(error.OutOfMemory, builder.append(command(storage.initial_capacity)));
    try std.testing.expect(lease.snapshot().last_failure_was_limit);
    try std.testing.expectEqual(old_bytes, workspace.live);
    try std.testing.expectEqual(total.control_bytes + old_bytes, ledger.live);
    try std.testing.expectEqual(total.control_bytes + old_bytes, profile.live_requested_bytes);
    try std.testing.expectEqual(storage.initial_capacity, builder.items().len);
    try std.testing.expect(builder.items().ptr == pointer);
    for (builder.items(), 0..) |actual, index| try std.testing.expectEqual(command(index), actual);
    try lease.setLimit(total.control_bytes + old_bytes + grown_bytes);
    try builder.append(command(storage.initial_capacity));
    try std.testing.expectEqual(old_bytes + grown_bytes, workspace.peak);
    try std.testing.expectEqual(total.control_bytes + old_bytes + grown_bytes, ledger.peak);
    try std.testing.expectEqual(ledger.peak, profile.peak_requested_bytes);
    try std.testing.expectEqual(storage.initial_capacity + 1, builder.items().len);
}

test "Brotli HQ command storage final exact fallback is budgeted and retryable" {
    const unit = @sizeOf(storage.Command);
    const old_bytes = storage.initial_capacity * unit;
    const exact_bytes = 3 * unit;
    var ledger = tracking.TrackingAllocator.init(std.testing.allocator);
    ledger.fail_remap_after = 0;
    var workspace = working.WorkingAllocator.init(ledger.allocator(), old_bytes + exact_bytes - 1);
    var builder = storage.Builder.init(workspace.allocator());
    defer builder.deinit();
    for (0..3) |index| try builder.append(command(index));
    const pointer = builder.items().ptr;
    try std.testing.expectError(error.OutOfMemory, builder.finishOwned());
    try std.testing.expect(workspace.last_failure_was_limit);
    try std.testing.expectEqual(old_bytes, ledger.live);
    try std.testing.expectEqual(@as(usize, 3), builder.items().len);
    try std.testing.expect(builder.items().ptr == pointer);
    workspace.limit += 1;
    const owned = try builder.finishOwned();
    try std.testing.expectEqual(@as(usize, 3), owned.len);
    try std.testing.expectEqual(exact_bytes, workspace.live);
    try std.testing.expectEqual(old_bytes + exact_bytes, ledger.peak);
    for (owned, 0..) |actual, index| try std.testing.expectEqual(command(index), actual);
    workspace.allocator().free(owned);
    try std.testing.expectEqual(@as(usize, 0), workspace.live);
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
}

test "Brotli HQ command storage checks byte overflow and zero budget before allocating" {
    try std.testing.expectError(error.IntegerOverflow, storage.bytesFor(std.math.maxInt(usize) / @sizeOf(storage.Command) + 1));
    var ledger = tracking.TrackingAllocator.init(std.testing.allocator);
    var workspace = working.WorkingAllocator.init(ledger.allocator(), 0);
    var builder = storage.Builder.init(workspace.allocator());
    defer builder.deinit();
    try std.testing.expectError(error.OutOfMemory, builder.append(command(0)));
    try std.testing.expectEqual(@as(usize, 0), ledger.alloc_attempts);
    try std.testing.expectEqual(@as(usize, 0), builder.items().len);
    try std.testing.expectEqual(@as(usize, 0), builder.capacity());
}

fn command(index: usize) storage.Command {
    return .{ .insert_start = index, .insert_len = index % 8, .copy_len = index % 127 + 2, .distance = index + 4, .has_copy = true };
}
