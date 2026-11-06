const std = @import("std");
const budget = @import("../budget.zig");
const Options = @import("entry_tests.zig").Options;
const allocator = std.testing.allocator;

test "Zstd decode budget charged append scope admits existing capacity before control and staging" {
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    const caller = failing.allocator();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(caller);
    try output.ensureTotalCapacityPrecise(caller, 31);
    output.appendSliceAssumeCapacity("old");
    const before = failing.allocations;
    var profile: budget.DecodeMemoryProfile = .{};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, budget.Entry.initExisting(caller, Options{ .max_total_working_memory = budget.control_bytes + 30, .memory_profile = &profile }, output.capacity));
    try std.testing.expectEqual(before, failing.allocations);
    try std.testing.expectEqual(@as(usize, 31), profile.peak_requested_bytes);
    profile.reset();
    var entry = try budget.Entry.initExisting(caller, Options{ .max_total_working_memory = budget.control_bytes + 33, .memory_profile = &profile }, output.capacity);
    var scope = try budget.AppendScope.initCharged(entry.lease, caller, &output);
    try std.testing.expectEqual(budget.control_bytes + 31, profile.live_requested_bytes);
    const decoded = try entry.allocator().dupe(u8, "ok");
    try scope.append(decoded);
    entry.allocator().free(decoded);
    try std.testing.expectEqual(budget.control_bytes + 33, profile.peak_requested_bytes);
    try std.testing.expectEqual(budget.control_bytes + 31, profile.live_requested_bytes);
    scope.deinit();
    scope.deinit();
    try std.testing.expectEqual(budget.control_bytes, profile.live_requested_bytes);
    entry.deinit();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectEqualStrings("oldok", output.items);
}

test "Zstd decode budget append scope returns caller capacity after staging rejection" {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.ensureTotalCapacityPrecise(allocator, 31);
    output.appendSliceAssumeCapacity("old");
    const original_ptr = output.items.ptr;
    var profile: budget.DecodeMemoryProfile = .{};
    var entry = try budget.Entry.initExisting(allocator, Options{ .max_total_working_memory = budget.control_bytes + 32, .memory_profile = &profile }, output.capacity);
    var scope = try budget.AppendScope.initCharged(entry.lease, allocator, &output);
    try std.testing.expectError(error.OutOfMemory, entry.allocator().alloc(u8, 2));
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, entry.mapError(error.OutOfMemory));
    scope.deinit();
    entry.deinit();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectEqual(budget.control_bytes + 31, profile.peak_requested_bytes);
    try std.testing.expect(output.items.ptr == original_ptr);
    try std.testing.expectEqual(@as(usize, 31), output.capacity);
    try std.testing.expectEqualStrings("old", output.items);
}

test "Zstd decode budget append scope precharged owner output does not duplicate adoption" {
    const scratch = try allocator.alloc(u8, 7);
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.ensureTotalCapacityPrecise(allocator, 31);
    output.appendSliceAssumeCapacity("old");
    var profile: budget.DecodeMemoryProfile = .{};
    const baseline = budget.control_bytes + budget.owner_bytes + scratch.len;
    const exact = baseline + output.capacity + 2;
    const owner = (try budget.Owner.create(allocator, Options{ .max_total_working_memory = exact, .memory_profile = &profile }, scratch.len + output.capacity)).?;
    var scope = try budget.AppendScope.initCharged(owner.lease, allocator, &output);
    const decoded = try owner.allocator().dupe(u8, "ok");
    try scope.append(decoded);
    owner.allocator().free(decoded);
    try std.testing.expectEqual(exact, profile.peak_requested_bytes);
    scope.deinit();
    try std.testing.expectEqual(baseline, owner.snapshot().live_requested_bytes);
    owner.allocator().free(scratch);
    owner.destroy();
    try std.testing.expectEqualStrings("oldok", output.items);
}

test "Zstd decode budget initial existing entry inherits parent without duplicate seed" {
    var parent = try budget.Entry.init(allocator, Options{ .max_total_working_memory = budget.control_bytes + 33 });
    defer parent.deinit();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(parent.allocator());
    try output.ensureTotalCapacityPrecise(parent.allocator(), 31);
    output.appendSliceAssumeCapacity("old");
    var child = try budget.Entry.initExisting(parent.allocator(), Options{}, output.capacity);
    defer child.deinit();
    var scope = try budget.AppendScope.initCharged(child.lease, parent.allocator(), &output);
    const decoded = try child.allocator().dupe(u8, "ok");
    defer child.allocator().free(decoded);
    try scope.append(decoded);
    scope.deinit();
    try std.testing.expectEqual(budget.control_bytes + 33, parent.snapshot().live_requested_bytes);
}

test "Zstd decode budget append existing spare capacity exact quota and atomic rejection" {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.ensureTotalCapacityPrecise(allocator, 31);
    output.appendSliceAssumeCapacity("old");
    const original_ptr = output.items.ptr;
    var profile: budget.DecodeMemoryProfile = .{};
    var entry = try budget.Entry.init(allocator, Options{ .max_total_working_memory = budget.control_bytes + 31 + 2 - 1, .memory_profile = &profile });
    defer entry.deinit();
    const decoded = try entry.allocator().dupe(u8, "ok");
    defer entry.allocator().free(decoded);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, budget.append(entry.lease, allocator, &output, decoded));
    try std.testing.expect(output.items.ptr == original_ptr);
    try std.testing.expectEqual(@as(usize, 31), output.capacity);
    try std.testing.expectEqualStrings("old", output.items);
    try std.testing.expectEqual(budget.control_bytes + 2, entry.snapshot().live_requested_bytes);
    try entry.lease.setLimit(budget.control_bytes + 31 + 2);
    try budget.append(entry.lease, allocator, &output, decoded);
    try std.testing.expectEqualStrings("oldok", output.items);
    try std.testing.expect(output.items.ptr == original_ptr);
    try std.testing.expectEqual(budget.control_bytes + 33, profile.peak_requested_bytes);
    try std.testing.expectEqual(budget.control_bytes + 2, profile.live_requested_bytes);
}

test "Zstd decode budget append growth tracks complete target capacity then returns it" {
    var storage: [4096]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    const caller = fixed.allocator();
    var entry = try budget.Entry.init(caller, Options{ .memory_profile = null, .max_total_working_memory = 4096 });
    defer entry.deinit();
    const decoded = try entry.allocator().dupe(u8, "decoded staging");
    defer entry.allocator().free(decoded);
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(caller);
    try output.ensureTotalCapacityPrecise(caller, 4);
    output.appendSliceAssumeCapacity("old");
    const original_ptr = output.items.ptr;
    const target = std.ArrayList(u8).growCapacity(output.items.len + decoded.len);
    const exact = budget.control_bytes + decoded.len + target;
    try entry.lease.setLimit(exact - 1);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, budget.append(entry.lease, caller, &output, decoded));
    try std.testing.expect(output.items.ptr == original_ptr);
    try std.testing.expectEqual(@as(usize, 4), output.capacity);
    try std.testing.expectEqualStrings("old", output.items);
    try entry.lease.setLimit(exact);
    try budget.append(entry.lease, caller, &output, decoded);
    try std.testing.expectEqualStrings("olddecoded staging", output.items);
    try std.testing.expectEqual(target, output.capacity);
    try std.testing.expectEqual(exact, entry.snapshot().peak_requested_bytes);
    try std.testing.expectEqual(budget.control_bytes + decoded.len, entry.snapshot().live_requested_bytes);
}

test "Zstd decode budget append backing OOM keeps output and releases adopted capacity" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .resize_fail_index = 0 });
    const caller = failing.allocator();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(caller);
    try output.ensureTotalCapacityPrecise(caller, 4);
    output.appendSliceAssumeCapacity("old");
    const original_ptr = output.items.ptr;
    var profile: budget.DecodeMemoryProfile = .{};
    var entry = try budget.Entry.init(caller, Options{ .memory_profile = &profile });
    defer entry.deinit();
    const decoded = try entry.allocator().dupe(u8, "new data");
    defer entry.allocator().free(decoded);
    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, budget.append(entry.lease, caller, &output, decoded));
    try std.testing.expect(output.items.ptr == original_ptr);
    try std.testing.expectEqual(@as(usize, 4), output.capacity);
    try std.testing.expectEqualStrings("old", output.items);
    try std.testing.expectEqual(budget.control_bytes + decoded.len, entry.snapshot().live_requested_bytes);
    try std.testing.expectEqual(budget.control_bytes + decoded.len + 4, profile.peak_requested_bytes);
    try std.testing.expect(!entry.snapshot().last_failure_was_limit);
}

test "Zstd decode budget append inherited output stays charged without duplicate seed" {
    var parent = try budget.Entry.init(allocator, Options{ .max_total_working_memory = budget.control_bytes + 31 + 2 });
    defer parent.deinit();
    var child = try budget.Entry.init(parent.allocator(), Options{});
    defer child.deinit();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(parent.allocator());
    try output.ensureTotalCapacityPrecise(parent.allocator(), 31);
    output.appendSliceAssumeCapacity("old");
    const decoded = try child.allocator().dupe(u8, "ok");
    defer child.allocator().free(decoded);
    try std.testing.expectError(error.OutOfMemory, parent.allocator().alloc(u8, 1));
    try budget.append(child.lease, parent.allocator(), &output, decoded);
    try std.testing.expectEqualStrings("oldok", output.items);
    try std.testing.expectEqual(budget.control_bytes + 33, parent.snapshot().live_requested_bytes);
    try std.testing.expect(parent.snapshot().last_failure_was_limit);
}

test "Zstd decode budget append fallback counts overlapping old and new allocations" {
    var storage: [4096]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    const caller = fixed.allocator();
    var entry = try budget.Entry.init(caller, Options{ .max_total_working_memory = 4096 });
    defer entry.deinit();
    const decoded = try entry.allocator().dupe(u8, "new staging");
    defer entry.allocator().free(decoded);
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(caller);
    try output.ensureTotalCapacityPrecise(caller, 4);
    output.appendSliceAssumeCapacity("old");
    const guard = try entry.allocator().alloc(u8, 3);
    defer entry.allocator().free(guard);
    const target = std.ArrayList(u8).growCapacity(3 + decoded.len);
    const exact = budget.control_bytes + decoded.len + guard.len + 4 + target;
    try entry.lease.setLimit(exact - 1);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, budget.append(entry.lease, caller, &output, decoded));
    try std.testing.expectEqualStrings("old", output.items);
    try entry.lease.setLimit(exact);
    try budget.append(entry.lease, caller, &output, decoded);
    try std.testing.expectEqualStrings("oldnew staging", output.items);
    try std.testing.expectEqual(exact, entry.snapshot().peak_requested_bytes);
    try std.testing.expectEqual(budget.control_bytes + decoded.len + guard.len, entry.snapshot().live_requested_bytes);
}
