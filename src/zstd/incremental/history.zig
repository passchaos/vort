const std = @import("std");

/// Caller-owned rolling frame history used by the incremental Zstd encoder.
///
/// Only completed blocks are retained: the current block is still available to
/// its local match planner, while this buffer supplies bytes from earlier
/// blocks. Keeping exactly the advertised window makes memory usage independent
/// of total stream size and prevents the encoder from emitting an invalid
/// distance that a conforming decoder is allowed to discard.
pub const Rolling = struct {
    bytes: std.ArrayList(u8) = .empty,

    pub fn deinit(self: *Rolling, allocator: std.mem.Allocator) void {
        self.bytes.deinit(allocator);
        self.* = .{};
    }

    pub fn clearRetainingCapacity(self: *Rolling) void {
        self.bytes.clearRetainingCapacity();
    }

    pub fn slice(self: *const Rolling) []const u8 {
        return self.bytes.items;
    }

    /// Reserve before block emission so an allocator failure cannot occur after
    /// encoded bytes have already entered the pending-output queue.
    pub fn prepareCompletedBlock(
        self: *Rolling,
        allocator: std.mem.Allocator,
        block: []const u8,
        window_len: usize,
    ) std.mem.Allocator.Error!void {
        try self.bytes.ensureTotalCapacity(allocator, @min(window_len, self.bytes.items.len + block.len));
    }

    pub fn appendCompletedBlock(self: *Rolling, block: []const u8, window_len: usize) void {
        if (window_len == 0) {
            self.bytes.clearRetainingCapacity();
            return;
        }
        if (block.len >= window_len) {
            self.bytes.clearRetainingCapacity();
            self.bytes.appendSliceAssumeCapacity(block[block.len - window_len ..]);
            return;
        }

        const retained_len = @min(self.bytes.items.len, window_len - block.len);
        if (retained_len != self.bytes.items.len) {
            const start = self.bytes.items.len - retained_len;
            std.mem.copyForwards(u8, self.bytes.items[0..retained_len], self.bytes.items[start..]);
            self.bytes.items.len = retained_len;
        }
        self.bytes.appendSliceAssumeCapacity(block);
    }
};

test "rolling Zstd history retains only the newest window" {
    var history: Rolling = .{};
    defer history.deinit(std.testing.allocator);
    try history.prepareCompletedBlock(std.testing.allocator, "abcdef", 8);
    history.appendCompletedBlock("abcdef", 8);
    try history.prepareCompletedBlock(std.testing.allocator, "ghij", 8);
    history.appendCompletedBlock("ghij", 8);
    try std.testing.expectEqualSlices(u8, "cdefghij", history.slice());
    try history.prepareCompletedBlock(std.testing.allocator, "0123456789", 8);
    history.appendCompletedBlock("0123456789", 8);
    try std.testing.expectEqualSlices(u8, "23456789", history.slice());
}
