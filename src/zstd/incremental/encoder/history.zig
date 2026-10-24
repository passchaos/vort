const std = @import("std");
const core = @import("../../../core.zig");
const Count = core.StreamCount;
const count = core.stream_count;
const history_index = @import("history_index.zig");

pub const View = struct {
    bytes: []const u8,
    absolute_start: Count,
    index: *const history_index.Index,

    pub fn recentCandidates(self: View, prefix: *const [8]u8) []const Count {
        return self.index.recentCandidates(prefix);
    }

    pub fn longCandidates(self: View, prefix: *const [8]u8) []const Count {
        return self.index.longCandidates(prefix);
    }

    pub fn candidateSets(
        self: View,
        prefix: *const [8]u8,
    ) history_index.CandidateSets {
        return self.index.candidateSets(prefix);
    }

    pub fn longEnabled(self: View) bool {
        return self.index.longEnabled();
    }
};

/// Caller-owned rolling frame history used by the incremental Zstd encoder.
///
/// Only completed blocks are retained: the current block is still available to
/// its local match planner, while this buffer supplies bytes from earlier
/// blocks. Keeping exactly the advertised window makes memory usage independent
/// of total stream size and prevents the encoder from emitting an invalid
/// distance that a conforming decoder is allowed to discard.
pub const Rolling = struct {
    bytes: std.ArrayList(u8) = .empty,
    index: history_index.Index = .{},
    absolute_start: Count = 0,
    absolute_end: Count = 0,

    pub fn deinit(self: *Rolling, allocator: std.mem.Allocator) void {
        self.index.deinit(allocator);
        self.bytes.deinit(allocator);
        self.* = .{};
    }

    pub fn clearRetainingCapacity(self: *Rolling) void {
        self.bytes.clearRetainingCapacity();
        self.index.clearRetainingCapacity();
        self.absolute_start = 0;
        self.absolute_end = 0;
    }

    pub fn view(self: *const Rolling) View {
        return .{ .bytes = self.bytes.items, .absolute_start = self.absolute_start, .index = &self.index };
    }

    /// Reserve before block emission so an allocator failure cannot occur after
    /// encoded bytes have already entered the pending-output queue.
    pub fn prepareCompletedBlock(
        self: *Rolling,
        allocator: std.mem.Allocator,
        block: []const u8,
        window_len: usize,
    ) (std.mem.Allocator.Error || error{IntegerOverflow})!void {
        _ = try count.addLocal(self.absolute_end, block.len);
        if (window_len != 0) try self.index.prepare(
            allocator,
            window_len > std.compress.zstd.default_window_len,
        );
        const combined_len = std.math.add(usize, self.bytes.items.len, block.len) catch return error.IntegerOverflow;
        try self.bytes.ensureTotalCapacity(allocator, @min(window_len, combined_len));
    }

    pub fn appendCompletedBlock(self: *Rolling, block: []const u8, window_len: usize) void {
        self.index.insertBlock(block, self.absolute_end);
        self.absolute_end = count.addLocal(self.absolute_end, block.len) catch unreachable;
        if (window_len == 0) {
            self.bytes.clearRetainingCapacity();
            self.absolute_start = self.absolute_end;
            return;
        }
        if (block.len >= window_len) {
            self.bytes.clearRetainingCapacity();
            self.bytes.appendSliceAssumeCapacity(block[block.len - window_len ..]);
            self.absolute_start = self.absolute_end - count.fromLocal(self.bytes.items.len);
            return;
        }

        const retained_len = @min(self.bytes.items.len, window_len - block.len);
        if (retained_len != self.bytes.items.len) {
            const start = self.bytes.items.len - retained_len;
            std.mem.copyForwards(u8, self.bytes.items[0..retained_len], self.bytes.items[start..]);
            self.bytes.items.len = retained_len;
        }
        self.bytes.appendSliceAssumeCapacity(block);
        self.absolute_start = self.absolute_end - count.fromLocal(self.bytes.items.len);
    }
};

test "Zstd incremental rolling history retains only the newest window" {
    var history: Rolling = .{};
    defer history.deinit(std.testing.allocator);
    try history.prepareCompletedBlock(std.testing.allocator, "abcdef", 8);
    history.appendCompletedBlock("abcdef", 8);
    try history.prepareCompletedBlock(std.testing.allocator, "ghij", 8);
    history.appendCompletedBlock("ghij", 8);
    try std.testing.expectEqualSlices(u8, "cdefghij", history.view().bytes);
    try history.prepareCompletedBlock(std.testing.allocator, "0123456789", 8);
    history.appendCompletedBlock("0123456789", 8);
    try std.testing.expectEqualSlices(u8, "23456789", history.view().bytes);
    try std.testing.expectEqual(@as(Count, 12), history.view().absolute_start);
}

test "Zstd incremental encoder counters retain history across 32-bit positions" {
    var history: Rolling = .{};
    defer history.deinit(std.testing.allocator);
    const boundary: Count = @as(Count, 1) << 32;
    history.absolute_start = boundary - 3;
    history.absolute_end = boundary - 3;
    try history.prepareCompletedBlock(std.testing.allocator, "abcdefgh", 16);
    history.appendCompletedBlock("abcdefgh", 16);
    try std.testing.expectEqual(boundary + 5, history.absolute_end);
    try std.testing.expectEqual(boundary - 3, history.absolute_start);
    try std.testing.expectEqual(boundary - 3, history.view().recentCandidates("abcdefgh")[0]);
    try history.prepareCompletedBlock(std.testing.allocator, "ijklmnop", 8);
    history.appendCompletedBlock("ijklmnop", 8);
    try std.testing.expectEqual(boundary + 5, history.absolute_start);
    try std.testing.expectEqual(boundary + 13, history.absolute_end);
    try std.testing.expectEqualSlices(u8, "ijklmnop", history.view().bytes);
}

test "Zstd incremental encoder counters refuse history overflow before allocation" {
    var history: Rolling = .{};
    defer history.deinit(std.testing.allocator);
    history.absolute_start = std.math.maxInt(Count) - 2;
    history.absolute_end = history.absolute_start;
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.IntegerOverflow, history.prepareCompletedBlock(failing.allocator(), "abcdefgh", 16));
    try std.testing.expectEqual(std.math.maxInt(Count) - 2, history.absolute_end);
    try std.testing.expectEqual(@as(usize, 0), history.bytes.capacity);
    try std.testing.expectEqual(@as(usize, 0), history.index.recent_entries.capacity);
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
}
