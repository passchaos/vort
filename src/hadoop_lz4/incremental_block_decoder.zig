const std = @import("std");
const lz4 = @import("../lz4.zig");
const block_decoder = @import("../lz4/incremental/block_decoder.zig");

pub const Plan = struct { decoded_len: usize, body_offset: usize = 0, max_offset: usize };
pub const Result = struct { output_written: usize, done: bool };

/// Hadoop chunks have no LZ4 frame dictionary. Validate their complete body
/// before replaying it through the shared LZ4 cursor or allocating history.
pub fn plan(block: []const u8) lz4.Error!Plan {
    const decoded_len = try lz4.decodedBlockSize(block);
    return .{ .decoded_len = decoded_len, .max_offset = @min(decoded_len, max_history_len) };
}

const max_history_len = 64 * 1024;

/// Owns only a bounded rolling prefix. Allocator contexts and compressed bytes
/// are supplied on each call so active decoder values can move safely.
pub const Cursor = struct {
    inner: block_decoder.Cursor,
    decoded_written: usize = 0,
    input_offset: usize = 0,
    history: std.ArrayList(u8) = .empty,
    history_start: usize = 0,

    pub fn init(block_plan: Plan) Cursor {
        return .{ .inner = block_decoder.Cursor.init(block_plan.decoded_len, 0) };
    }

    pub fn reset(self: *Cursor, block_plan: Plan) void {
        var history = self.history;
        history.clearRetainingCapacity();
        self.* = init(block_plan);
        self.history = history;
    }

    pub fn deinit(self: *Cursor, allocator: std.mem.Allocator) void {
        self.history.deinit(allocator);
        self.* = undefined;
    }

    pub fn historyCapacity(self: *const Cursor) usize {
        return self.history.capacity;
    }

    pub fn activeHistoryLen(self: *const Cursor) usize {
        return self.history.items.len;
    }

    pub fn step(self: *Cursor, allocator: std.mem.Allocator, block: []const u8, output: []u8) lz4.Error!Result {
        const remaining = self.inner.expected_decoded_len - self.decoded_written;
        if (output.len == 0 and remaining != 0) return .{ .output_written = 0, .done = false };
        const available = output[0..@min(output.len, remaining)];
        const target = @min(max_history_len, self.decoded_written + available.len);
        // Reserve before output is published: remembering either a successful
        // prefix or a prefix emitted before a cursor error cannot allocate.
        try self.history.ensureTotalCapacityPrecise(allocator, target);
        const before = self.inner.decoded_len;
        const decoded = self.inner.step(block, .{ .bytes = self.history.items, .start = self.history_start }, available) catch |err| {
            self.record(before, available);
            return err;
        };
        self.record(before, available);
        return .{ .output_written = decoded.output_written, .done = decoded.done };
    }

    fn record(self: *Cursor, before: usize, output: []const u8) void {
        const emitted = self.inner.decoded_len - before;
        self.decoded_written = self.inner.decoded_len;
        self.input_offset = self.inner.input_offset;
        self.remember(output[0..emitted]);
    }

    fn remember(self: *Cursor, bytes: []const u8) void {
        if (bytes.len >= max_history_len) {
            self.history.items.len = max_history_len;
            @memcpy(self.history.items, bytes[bytes.len - max_history_len ..]);
            self.history_start = 0;
            return;
        }
        const appended = @min(bytes.len, max_history_len - self.history.items.len);
        self.history.appendSliceAssumeCapacity(bytes[0..appended]);
        const remaining = bytes[appended..];
        if (remaining.len == 0) return;
        const first = @min(remaining.len, max_history_len - self.history_start);
        @memcpy(self.history.items[self.history_start..][0..first], remaining[0..first]);
        @memcpy(self.history.items[0 .. remaining.len - first], remaining[first..]);
        self.history_start = (self.history_start + remaining.len) % max_history_len;
    }
};
