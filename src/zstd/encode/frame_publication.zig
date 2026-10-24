const std = @import("std");
const total = @import("total_budget.zig");

/// Publish a completed frame without adopting the caller's original capacity.
/// A moving replacement is counted until ownership returns to the caller;
/// a caller already in this shared ledger keeps the new allocation charged.
pub fn appendFrame(entry: *const total.Entry, out: *std.ArrayList(u8), frame: []const u8) total.Error!void {
    if (frame.len <= out.capacity - out.items.len) {
        out.appendSliceAssumeCapacity(frame);
        return;
    }
    const size = std.math.add(usize, out.items.len, frame.len) catch return error.IntegerOverflow;
    const tracked = entry.allocator();
    const replacement = tracked.alloc(u8, size) catch |err| return @errorCast(entry.mapError(err));
    errdefer tracked.free(replacement);
    @memcpy(replacement[0..out.items.len], out.items);
    @memcpy(replacement[out.items.len..], frame);
    try entry.releaseOwned(replacement.len);
    entry.caller.free(out.allocatedSlice());
    out.* = .{ .items = replacement, .capacity = replacement.len };
}

const Options = struct {
    max_total_working_memory: ?usize = null,
    memory_profile: ?*total.EncodeMemoryProfile = null,
};

test "Zstd frame publication exact quota excludes borrowed caller prefix and retains shared caller ownership" {
    const allocator = std.testing.allocator;
    const prefix = "prefix:";
    const frame = "frame bytes";
    const combined = prefix.len + frame.len;
    {
        const original = try allocator.dupe(u8, prefix);
        var out: std.ArrayList(u8) = .{ .items = original, .capacity = original.len };
        defer out.deinit(allocator);
        var profile: total.EncodeMemoryProfile = .{};
        var entry = try total.Entry.init(allocator, Options{ .max_total_working_memory = total.control_bytes + frame.len + combined, .memory_profile = &profile });
        const owned_frame = try entry.allocator().dupe(u8, frame);
        try std.testing.expectEqual(total.control_bytes + frame.len, entry.snapshot().live_requested_bytes);
        try appendFrame(&entry, &out, owned_frame);
        try std.testing.expectEqualSlices(u8, prefix ++ frame, out.items);
        try std.testing.expectEqual(combined, out.capacity);
        try std.testing.expectEqual(total.control_bytes + frame.len + combined, profile.peak_requested_bytes);
        try std.testing.expectEqual(total.control_bytes + frame.len, entry.snapshot().live_requested_bytes);
        entry.allocator().free(owned_frame);
        entry.deinit();
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
    {
        var profile: total.EncodeMemoryProfile = .{};
        var parent = try total.Entry.init(allocator, Options{ .max_total_working_memory = total.control_bytes + prefix.len + combined, .memory_profile = &profile });
        const caller = parent.allocator();
        const original = try caller.dupe(u8, prefix);
        var out: std.ArrayList(u8) = .{ .items = original, .capacity = original.len };
        var nested = try total.Entry.init(caller, Options{});
        try appendFrame(&nested, &out, frame);
        try std.testing.expectEqualSlices(u8, prefix ++ frame, out.items);
        try std.testing.expectEqual(total.control_bytes + prefix.len + combined, profile.peak_requested_bytes);
        try std.testing.expectEqual(total.control_bytes + combined, parent.snapshot().live_requested_bytes);
        nested.deinit();
        out.deinit(caller);
        parent.deinit();
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
    {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try out.ensureTotalCapacityPrecise(allocator, combined);
        out.appendSliceAssumeCapacity(prefix);
        const original_pointer = out.items.ptr;
        var profile: total.EncodeMemoryProfile = .{};
        var entry = try total.Entry.init(allocator, Options{ .max_total_working_memory = total.control_bytes, .memory_profile = &profile });
        try appendFrame(&entry, &out, frame);
        try std.testing.expect(out.items.ptr == original_pointer);
        try std.testing.expectEqualSlices(u8, prefix ++ frame, out.items);
        try std.testing.expectEqual(total.control_bytes, profile.peak_requested_bytes);
        entry.deinit();
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
}

test "Zstd frame publication one below exact replacement quota preserves pointer capacity prefix and releases control" {
    const allocator = std.testing.allocator;
    const prefix = "existing caller output";
    const frame = "new frame";
    const original = try allocator.dupe(u8, prefix);
    var out: std.ArrayList(u8) = .{ .items = original, .capacity = original.len };
    defer out.deinit(allocator);
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    var profile: total.EncodeMemoryProfile = .{};
    var entry = try total.Entry.init(allocator, Options{ .max_total_working_memory = total.control_bytes + frame.len + prefix.len + frame.len - 1, .memory_profile = &profile });
    const owned_frame = try entry.allocator().dupe(u8, frame);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, appendFrame(&entry, &out, owned_frame));
    try std.testing.expect(out.items.ptr == pointer);
    try std.testing.expectEqual(capacity, out.capacity);
    try std.testing.expectEqualSlices(u8, prefix, out.items);
    try std.testing.expectEqual(total.control_bytes + frame.len, profile.peak_requested_bytes);
    try std.testing.expectEqual(total.control_bytes + frame.len, entry.snapshot().live_requested_bytes);
    entry.allocator().free(owned_frame);
    entry.deinit();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}
