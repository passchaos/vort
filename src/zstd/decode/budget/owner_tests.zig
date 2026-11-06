const std = @import("std");
const budget = @import("../budget.zig");
const Options = @import("entry_tests.zig").Options;
const allocator = std.testing.allocator;

test "Zstd decode budget owner admission counts both controls before backing allocations" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectEqual(@as(?*budget.Owner, null), try budget.Owner.create(failing.allocator(), Options{}, 91));
    var profile: budget.DecodeMemoryProfile = .{};
    const exact = budget.control_bytes + budget.owner_bytes + 91;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, budget.Owner.create(failing.allocator(), Options{ .max_total_working_memory = exact - 1, .memory_profile = &profile }, 91));
    try std.testing.expectEqual(@as(usize, 0), failing.allocations);
    try std.testing.expectEqual(@as(usize, 91), profile.peak_requested_bytes);
    try std.testing.expectError(error.OutOfMemory, budget.Owner.create(failing.allocator(), Options{ .max_total_working_memory = exact }, 91));
    try std.testing.expectError(error.IntegerOverflow, budget.Owner.create(failing.allocator(), Options{ .memory_profile = &profile }, std.math.maxInt(usize)));
}

test "Zstd decode budget owner control allocation failures preserve retained payload and detach profile" {
    for (0..2) |failure| {
        var failing = std.testing.FailingAllocator.init(allocator, .{});
        const retained = try failing.allocator().dupe(u8, "retained payload");
        failing.fail_index = failing.alloc_index + failure;
        var profile: budget.DecodeMemoryProfile = .{};
        try std.testing.expectError(error.OutOfMemory, budget.Owner.create(failing.allocator(), Options{ .memory_profile = &profile }, retained.len));
        try std.testing.expectEqualStrings("retained payload", retained);
        try std.testing.expectEqual(retained.len, failing.allocated_bytes - failing.freed_bytes);
        try std.testing.expectEqual(retained.len + if (failure == 0) @as(usize, 0) else budget.control_bytes, profile.peak_requested_bytes);
        const saved = profile;
        failing.allocator().free(retained);
        try std.testing.expectEqualDeep(saved, profile);
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
}

test "Zstd decode budget owner adopts retained once and rebinding failures preserve payload" {
    const retained = try allocator.dupe(u8, "existing");
    var first: budget.DecodeMemoryProfile = .{};
    const exact = budget.control_bytes + budget.owner_bytes + retained.len;
    const owner = (try budget.Owner.create(allocator, Options{ .max_total_working_memory = exact, .memory_profile = &first }, retained.len)).?;
    try std.testing.expectEqual(exact, owner.snapshot().live_requested_bytes);
    try std.testing.expectEqual(exact, first.peak_requested_bytes);
    try std.testing.expectError(error.OutOfMemory, owner.allocator().alloc(u8, 1));
    owner.end();
    const first_saved = first;
    var rejected: budget.DecodeMemoryProfile = .{};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, owner.begin(Options{ .max_total_working_memory = exact - 1, .memory_profile = &rejected }));
    try std.testing.expectEqual(exact, rejected.live_requested_bytes);
    try std.testing.expectEqualStrings("existing", retained);
    try std.testing.expectEqual(@as(?usize, exact), owner.snapshot().limit);
    var next: budget.DecodeMemoryProfile = .{};
    const a = try owner.begin(Options{ .max_total_working_memory = exact + 9, .memory_profile = &next });
    try std.testing.expect(!owner.snapshot().last_failure_was_limit);
    const owned = try a.alloc(u8, 9);
    try owner.releaseOwned(allocator, owned.len);
    try std.testing.expectEqual(exact, owner.snapshot().live_requested_bytes);
    allocator.free(owned);
    owner.end();
    const next_saved = next;
    const rejected_saved = rejected;
    a.free(retained);
    owner.destroy();
    try std.testing.expectEqualDeep(first_saved, first);
    try std.testing.expectEqualDeep(rejected_saved, rejected);
    try std.testing.expectEqualDeep(next_saved, next);
}

test "Zstd decode budget owner inherited policy avoids retained seed and preserves parent classification" {
    var profile: budget.DecodeMemoryProfile = .{};
    var parent = try budget.Entry.init(allocator, Options{ .max_total_working_memory = budget.control_bytes + budget.owner_bytes + 19, .memory_profile = &profile });
    defer parent.deinit();
    const retained = try parent.allocator().alloc(u8, 19);
    defer parent.allocator().free(retained);
    try std.testing.expectEqual(@as(?*budget.Owner, null), try budget.Owner.create(parent.allocator(), Options{}, retained.len));
    const owner = (try budget.Owner.create(parent.allocator(), Options{ .memory_profile = &profile }, retained.len)).?;
    defer owner.destroy();
    const exact = budget.control_bytes + budget.owner_bytes + retained.len;
    try std.testing.expectEqual(exact, parent.snapshot().live_requested_bytes);
    try std.testing.expectError(error.OutOfMemory, owner.allocator().alloc(u8, 1));
    _ = try owner.begin(Options{});
    try std.testing.expect(parent.snapshot().last_failure_was_limit);
    var replacement: budget.DecodeMemoryProfile = .{};
    try std.testing.expectError(error.InvalidBlockPlan, owner.begin(Options{ .memory_profile = &replacement }));
    try std.testing.expectEqual(budget.DecodeMemoryProfile{}, replacement);
    try owner.releaseOwned(parent.allocator(), retained.len);
    try std.testing.expectEqual(exact, parent.snapshot().live_requested_bytes);
    owner.end();
    try std.testing.expectEqual(exact, profile.live_requested_bytes);
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, owner.mapError(error.OutOfMemory));
}

test "Zstd decode budget inherited owner allocation rejection has no backing allocation" {
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    var profile: budget.DecodeMemoryProfile = .{};
    var parent = try budget.Entry.init(failing.allocator(), Options{ .max_total_working_memory = budget.control_bytes + budget.owner_bytes - 1, .memory_profile = &profile });
    defer parent.deinit();
    const before = failing.allocations;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, budget.Owner.create(parent.allocator(), Options{ .memory_profile = &profile }, 23));
    try std.testing.expectEqual(before, failing.allocations);
    try std.testing.expectEqual(budget.control_bytes, parent.snapshot().live_requested_bytes);
}
