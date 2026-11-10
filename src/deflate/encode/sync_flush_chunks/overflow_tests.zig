//! Forged descriptor length must fail before pointer reads or allocation.
const std = @import("std");
const runs = @import("alias_runs.zig");
const allocator = std.testing.allocator;

pub fn contracts(comptime C: type) !void {
    const length = std.math.maxInt(usize) / @sizeOf([]const u8) + 1;
    const unreadable: [*]const []const u8 = @ptrFromInt(4096);
    const chunks = unreadable[0..length];
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var storage: [16]u8 = @splat(0xa7);
    @memcpy(storage[0..4], "pre!");
    const saved = storage;
    try std.testing.expectError(error.IntegerOverflow, runs.Prepared.init(failing.allocator(), chunks, &storage));
    inline for (.{ false, true }) |reusable| {
        inline for (.{ false, true }) |profile_only| {
            var output: std.ArrayList(u8) = .{ .items = storage[0..4], .capacity = storage.len };
            var owner = C.RawFixedSyncFlushEncoder.init(failing.allocator());
            defer owner.deinit();
            var profile: C.EncodeMemoryProfile = .{};
            const options: C.CompressionOptions = if (profile_only) .{ .memory_profile = &profile } else .{ .max_total_working_memory = 0 };
            const result = if (reusable)
                owner.encodeChunksAppend(&output, chunks, options)
            else
                C.encodeRawFixedSyncFlushChunksAppend(failing.allocator(), &output, chunks, options);
            try std.testing.expectError(error.IntegerOverflow, result);
            try std.testing.expectEqualSlices(u8, "pre!", output.items);
            try std.testing.expectEqualDeep(saved, storage);
            try std.testing.expectEqual(@as(usize, 0), owner.arena.queryCapacity());
            try std.testing.expect(!profile.available);
        }
    }
    try std.testing.expect(!failing.has_induced_failure);
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);

    // Empty descriptors preserve the old allocation-free iterator behavior.
    var empty = try runs.Prepared.init(failing.allocator(), &.{ "", "" }, &storage);
    defer empty.deinit(failing.allocator());
    try std.testing.expectEqual(@as(?[]const u8, null), empty.next());
    try std.testing.expect(!failing.has_induced_failure);
}
