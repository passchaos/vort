const std = @import("std");
const scoped = @import("scoped_static_dictionary.zig");
const matcher = @import("static_dictionary_matcher.zig");
const static = @import("../static_dictionary.zig");
const plan = @import("command_plan.zig");
const total = @import("total_budget.zig");
const allocator = std.testing.allocator;

/// Independent requested-heap ledger. Moving growth exposes every old/new
/// allocation lifetime to both this ledger and the encoder's total tracker.
const Heap = struct {
    live: usize = 0,
    peak: usize = 0,
    calls: usize = 0,

    fn allocator(self: *Heap) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *Heap = @ptrCast(@alignCast(context));
        const result = std.testing.allocator.rawAlloc(len, alignment, ret) orelse return null;
        self.live += len;
        self.peak = @max(self.peak, self.live);
        self.calls += 1;
        return result;
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(context: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *Heap = @ptrCast(@alignCast(context));
        self.live -= bytes.len;
        std.testing.allocator.rawFree(bytes, alignment, ret);
    }
};

fn scopedPeak(need_complete: bool, limit: ?usize) !usize {
    var heap: Heap = .{};
    var profile: total.EncodeMemoryProfile = .{};
    var lease = try total.Lease.init(heap.allocator(), limit, &profile, 0);
    {
        defer lease.deinit();
        var indexes = scoped.Indexes.init(lease.allocator(), need_complete) catch |err| {
            try std.testing.expectEqual(total.control_bytes, heap.live);
            try std.testing.expectEqual(heap.live, lease.snapshot().live_requested_bytes);
            return lease.translateError(err);
        };
        {
            defer indexes.deinit();
            try std.testing.expect(indexes.owned_compact != null and indexes.shared_compact == null);
            try std.testing.expect((indexes.owned_complete != null) == need_complete);
            try std.testing.expectEqual(heap.peak, lease.snapshot().peak_requested_bytes);
            try std.testing.expectEqual(heap.peak, profile.peak_requested_bytes);
            try std.testing.expectEqual(heap.live, profile.live_requested_bytes);
        }
        try std.testing.expectEqual(total.control_bytes, heap.live);
        try std.testing.expectEqual(total.control_bytes, lease.snapshot().live_requested_bytes);
    }
    try std.testing.expectEqual(@as(usize, 0), heap.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    return heap.peak;
}

test "Brotli total static dictionary tracked cold zero exact and below count all legacy index storage" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, total.Lease.init(failing.allocator(), 0, null, 0));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    // A control-only budget gives the dictionary zero bytes. Failure happens
    // inside its caller tracker even if the legacy shared index is already warm.
    failing.fail_index = 1;
    var lease = try total.Lease.init(failing.allocator(), total.control_bytes, null, 0);
    {
        defer lease.deinit();
        try std.testing.expectError(error.OutOfMemory, scoped.Indexes.init(lease.allocator(), false));
        try std.testing.expect(lease.snapshot().hit_limit);
        try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, lease.translateError(error.OutOfMemory));
        try std.testing.expectEqual(total.control_bytes, lease.snapshot().live_requested_bytes);
        try std.testing.expectEqual(@as(usize, 1), failing.alloc_index);
        try std.testing.expect(!failing.has_induced_failure);
    }
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    for ([_]bool{ false, true }) |need_complete| {
        const peak = try scopedPeak(need_complete, null);
        try std.testing.expectEqual(peak, try scopedPeak(need_complete, peak));
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, scopedPeak(need_complete, peak - 1));
    }
}

test "Brotli total static dictionary owned legacy lookup matches original indexes and survives move" {
    var compact = try matcher.Index.init(allocator);
    defer compact.deinit();
    var complete = try matcher.CompleteIndex.init(allocator);
    defer complete.deinit();
    var profile: total.EncodeMemoryProfile = .{};
    var lease = try total.Lease.init(allocator, null, &profile, 0);
    defer lease.deinit();
    var original = try scoped.Indexes.init(lease.allocator(), true);
    var moved = original;
    original = .{};
    defer moved.deinit();
    try std.testing.expect(moved.compact().words.ptr != compact.words.ptr);
    try std.testing.expect(moved.complete().words.ptr != complete.words.ptr);
    for ([_][]const u8{ " information follows", "Information", "INFORMATION", " the world of compression", "x" }) |input| {
        try std.testing.expectEqualDeep(compact.findLongest(input), moved.compact().findLongest(input));
        try std.testing.expectEqualDeep(complete.findLongest(&compact, input), moved.complete().findLongest(moved.compact(), input));
    }
}

test "Brotli total static dictionary profile only preserves compact complete mixed and cached command plans" {
    const input = "abcdefghabcdefgh information follows abcdefghabcdefgh";
    const baseline = [_]plan.Command{
        .{ .insert_start = 0, .insert_len = 8, .copy_len = 8, .distance = 8, .has_copy = true },
        .{ .insert_start = 16, .insert_len = 21, .copy_len = 16, .distance = 37, .has_copy = true },
    };
    const old_compact = try plan.buildStaticDictionaryAlloc(allocator, input);
    defer old_compact.deinit(allocator);
    const old_complete = try plan.buildStaticDictionaryCompleteAlloc(allocator, input);
    defer old_complete.deinit(allocator);
    const old_mixed = try plan.mixStaticDictionaryAlloc(allocator, input, &baseline);
    defer old_mixed.deinit(allocator);
    var profile: total.EncodeMemoryProfile = .{};
    var lease = try total.Lease.init(allocator, null, &profile, 0);
    defer lease.deinit();
    const tracked = lease.allocator();
    var matches: [input.len]static.Match = undefined;
    var known: [input.len]bool = undefined;
    var cache = plan.StaticDictionaryMatchCache.init(&matches, &known);
    const compact = try plan.buildStaticDictionaryWithCacheAlloc(tracked, input, &cache);
    defer compact.deinit(tracked);
    const complete = try plan.buildStaticDictionaryCompleteAlloc(tracked, input);
    defer complete.deinit(tracked);
    const mixed = try plan.mixStaticDictionaryWithCacheAlloc(tracked, input, &baseline, &cache);
    defer mixed.deinit(tracked);
    try std.testing.expectEqualDeep(old_compact.commands, compact.commands);
    try std.testing.expectEqualDeep(old_complete.commands, complete.commands);
    try std.testing.expectEqualDeep(old_mixed.commands, mixed.commands);
    try std.testing.expectEqual(old_mixed.match_count, mixed.match_count);
    try std.testing.expect(profile.available and profile.peak_requested_bytes > matcher.max_index_bytes);
}

const AllocationGraph = struct {
    fn run(backing: std.mem.Allocator) !void {
        var profile: total.EncodeMemoryProfile = .{};
        var lease = try total.Lease.init(backing, null, &profile, 0);
        defer lease.deinit();
        var indexes = scoped.Indexes.init(lease.allocator(), true) catch |err| {
            try std.testing.expectEqual(total.control_bytes, lease.snapshot().live_requested_bytes);
            try std.testing.expect(!lease.snapshot().last_failure_was_limit);
            return err;
        };
        defer indexes.deinit();
        try std.testing.expect(indexes.complete().findLongest(indexes.compact(), " information follows") != null);
    }
};

test "Brotli total static dictionary tracked backing OOM frees each legacy construction allocation" {
    try std.testing.checkAllAllocationFailures(allocator, AllocationGraph.run, .{});
}

test "Brotli total static dictionary profile only retains independently frozen complete wire" {
    const br = @import("../../br.zig");
    const input = "information information follows";
    // Captured before this scoped-owner change using the public static encoder.
    const frozen = [_]u8{ 0xc2, 0x03, 0x00, 0x3c, 0x04, 0x40, 0x05, 0x53, 0x48, 0xad, 0x5e, 0x29, 0x26, 0x6a, 0x34 };
    var heap: Heap = .{};
    var profile: total.EncodeMemoryProfile = .{};
    var lease = try total.Lease.init(heap.allocator(), null, &profile, 0);
    {
        defer lease.deinit();
        const tracked = lease.allocator();
        const wire = try br.encodePlannedStreamStaticDictionaryAlloc(tracked, input);
        {
            defer tracked.free(wire);
            try std.testing.expectEqualSlices(u8, &frozen, wire);
            try std.testing.expectEqual(heap.peak, profile.peak_requested_bytes);
            try std.testing.expect(profile.peak_requested_bytes > matcher.max_index_bytes);
        }
        try std.testing.expectEqual(total.control_bytes, heap.live);
    }
    try std.testing.expectEqual(@as(usize, 0), heap.live);
    const untracked = try br.encodePlannedStreamStaticDictionaryAlloc(allocator, input);
    defer allocator.free(untracked);
    try std.testing.expectEqualSlices(u8, &frozen, untracked);
}
