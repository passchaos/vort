//! Byte-only accepted-frame history. Workers receive immutable prefix copies,
//! never this mutable rolling buffer or a shared mutable match index.
const std = @import("std");
const core = @import("../../core.zig");
const count = core.stream_count;

pub const Rolling = struct {
    bytes: std.ArrayList(u8) = .empty,
    end: core.StreamCount = 0,

    pub fn prepare(self: *Rolling, allocator: std.mem.Allocator, additional: usize, window: usize) !void {
        _ = try count.addLocal(self.end, additional);
        const needed = if (additional >= window) window else additional + @min(self.bytes.items.len, window - additional);
        try self.bytes.ensureTotalCapacityPrecise(allocator, needed);
    }

    pub fn appendPrepared(self: *Rolling, bytes: []const u8, window: usize) void {
        self.end = count.addLocal(self.end, bytes.len) catch unreachable;
        if (bytes.len >= window) {
            self.bytes.clearRetainingCapacity();
            self.bytes.appendSliceAssumeCapacity(bytes[bytes.len - window ..]);
            return;
        }
        const keep = @min(self.bytes.items.len, window - bytes.len);
        if (keep != self.bytes.items.len)
            std.mem.copyForwards(u8, self.bytes.items[0..keep], self.bytes.items[self.bytes.items.len - keep ..]);
        self.bytes.items.len = keep;
        self.bytes.appendSliceAssumeCapacity(bytes);
    }

    pub fn clear(self: *Rolling) void {
        self.bytes.clearRetainingCapacity();
        self.end = 0;
    }

    pub fn deinit(self: *Rolling, allocator: std.mem.Allocator) void {
        self.bytes.deinit(allocator);
        self.* = .{};
    }
};
