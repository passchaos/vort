const std = @import("std");

pub const Error = std.mem.Allocator.Error || error{ InvalidMatch, HistoryLimitExceeded, IntegerOverflow };
pub const View = struct { bytes: []const u8, start: usize = 0 };

pub fn byteFromEnd(history: View, distance: usize) Error!u8 {
    if (distance == 0 or (history.bytes.len != 0 and history.start >= history.bytes.len)) return error.InvalidMatch;
    if (distance > history.bytes.len) return error.HistoryLimitExceeded;
    return history.bytes[(history.start + history.bytes.len - distance) % history.bytes.len];
}

/// Logical suffix, stored in a caller-owned ring. Reserve before publishing
/// output; recordAssumeCapacity never allocates or fails after cursor progress.
pub const Ring = struct {
    bytes: std.ArrayList(u8) = .empty,
    limit: usize,
    start: usize = 0,

    pub fn init(limit: usize) Ring {
        return .{ .limit = limit };
    }
    pub fn deinit(self: *Ring, allocator: std.mem.Allocator) void {
        self.bytes.deinit(allocator);
        self.* = undefined;
    }
    pub fn reset(self: *Ring) void {
        self.bytes.clearRetainingCapacity();
        self.start = 0;
    }
    pub fn view(self: *const Ring) View {
        return .{ .bytes = self.bytes.items, .start = self.start };
    }
    pub fn reserve(self: *Ring, allocator: std.mem.Allocator, additional: usize) Error!void {
        if (self.limit == 0) return;
        const needed = self.bytes.items.len + @min(additional, self.limit - self.bytes.items.len);
        if (needed > self.bytes.capacity) try self.bytes.ensureTotalCapacityPrecise(allocator, needed);
    }
    pub fn recordAssumeCapacity(self: *Ring, output: []const u8) void {
        if (self.limit == 0 or output.len == 0) return;
        if (output.len >= self.limit) {
            self.bytes.items.len = self.limit;
            @memcpy(self.bytes.items, output[output.len - self.limit ..]);
            self.start = 0;
            return;
        }
        for (output) |byte| {
            if (self.bytes.items.len < self.limit) self.bytes.appendAssumeCapacity(byte) else {
                self.bytes.items[self.start] = byte;
                self.start = (self.start + 1) % self.limit;
            }
        }
    }
};

test "LZFSE history retains the logical suffix through ring wrap and reset" {
    const allocator = std.testing.allocator;
    var ring = Ring.init(5);
    defer ring.deinit(allocator);
    try ring.reserve(allocator, 3);
    ring.recordAssumeCapacity("abc");
    try ring.reserve(allocator, 4);
    ring.recordAssumeCapacity("defg");
    for ("cdefg", 0..) |byte, index| try std.testing.expectEqual(byte, try byteFromEnd(ring.view(), 5 - index));
    try std.testing.expectError(error.HistoryLimitExceeded, byteFromEnd(ring.view(), 6));
    ring.recordAssumeCapacity("0123456789");
    try std.testing.expectEqualStrings("56789", ring.bytes.items);
    ring.reset();
    try std.testing.expectEqual(@as(usize, 0), ring.view().bytes.len);
}
