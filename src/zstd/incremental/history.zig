const std = @import("std");
const history_index = @import("history_index.zig");

pub const View = struct {
    bytes: []const u8,
    absolute_start: usize,
    index: *const history_index.Index,

    pub fn candidates(self: View, prefix: *const [8]u8) []const usize {
        return self.index.candidates(prefix);
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
    absolute_start: usize = 0,
    absolute_end: usize = 0,

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
        if (window_len != 0) try self.index.prepare(allocator);
        _ = std.math.add(usize, self.absolute_end, block.len) catch return error.IntegerOverflow;
        const combined_len = std.math.add(usize, self.bytes.items.len, block.len) catch return error.IntegerOverflow;
        try self.bytes.ensureTotalCapacity(allocator, @min(window_len, combined_len));
    }

    pub fn appendCompletedBlock(self: *Rolling, block: []const u8, window_len: usize) void {
        self.index.insertBlock(block, self.absolute_end);
        self.absolute_end = std.math.add(usize, self.absolute_end, block.len) catch unreachable;
        if (window_len == 0) {
            self.bytes.clearRetainingCapacity();
            self.absolute_start = self.absolute_end;
            return;
        }
        if (block.len >= window_len) {
            self.bytes.clearRetainingCapacity();
            self.bytes.appendSliceAssumeCapacity(block[block.len - window_len ..]);
            self.absolute_start = self.absolute_end - self.bytes.items.len;
            return;
        }

        const retained_len = @min(self.bytes.items.len, window_len - block.len);
        if (retained_len != self.bytes.items.len) {
            const start = self.bytes.items.len - retained_len;
            std.mem.copyForwards(u8, self.bytes.items[0..retained_len], self.bytes.items[start..]);
            self.bytes.items.len = retained_len;
        }
        self.bytes.appendSliceAssumeCapacity(block);
        self.absolute_start = self.absolute_end - self.bytes.items.len;
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
    try std.testing.expectEqual(@as(usize, 12), history.view().absolute_start);
}
