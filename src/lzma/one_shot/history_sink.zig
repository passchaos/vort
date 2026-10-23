const std = @import("std");
const history = @import("../history.zig");

/// Process-local adapter. Capacity grows from actual literals/matches and is
/// capped at the active dictionary/output window; no caller output is staged.
pub const Sink = struct {
    inner: *history.CircularBuffer,
    len: usize,

    pub fn init(inner: *history.CircularBuffer) Sink {
        return .{ .inner = inner, .len = inner.len };
    }
    pub fn lastOr(self: Sink, default: u8) u8 {
        return self.inner.lastOr(default);
    }
    pub fn lastN(self: Sink, distance: usize) !u8 {
        return self.inner.lastN(distance);
    }
    pub fn appendLiteral(self: *Sink, allocator: std.mem.Allocator, byte: u8, writer: *std.Io.Writer) !void {
        if (self.inner.len >= self.inner.output_limit) return error.OutputLimitExceeded;
        try self.reserve(allocator, 1);
        try self.inner.appendLiteral(allocator, byte, writer);
    }
    pub fn appendLz(self: *Sink, allocator: std.mem.Allocator, length: usize, distance: usize, writer: *std.Io.Writer) !void {
        if (distance == 0 or distance > self.inner.dictionary_size or distance > self.inner.len) return error.CorruptInput;
        const remaining = self.inner.output_limit -| self.inner.len;
        if (!self.inner.allow_partial and length > remaining) return error.OutputLimitExceeded;
        try self.reserve(allocator, @min(length, remaining));
        try self.inner.appendLz(allocator, length, distance, writer);
    }
    fn reserve(self: *Sink, allocator: std.mem.Allocator, additional: usize) !void {
        const bytes = &self.inner.bytes;
        const needed = bytes.items.len + @min(additional, self.inner.dictionary_size - bytes.items.len);
        if (needed <= bytes.capacity) return;
        const limit = @min(self.inner.dictionary_size, self.inner.output_limit);
        const grown = std.math.add(usize, bytes.capacity, bytes.capacity / 2 + 8) catch limit;
        try bytes.ensureTotalCapacityPrecise(allocator, @min(limit, @max(needed, grown)));
    }
};
