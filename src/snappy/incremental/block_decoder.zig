const std = @import("std");
const block_decode = @import("../block_decode.zig");
const match_copy = @import("../match_copy.zig");

pub const Error = block_decode.Error || std.mem.Allocator.Error;
pub const Plan = struct { decoded_len: usize, body_offset: usize, max_offset: usize };
pub const Result = struct { output_written: usize, done: bool };

/// The complete token pass runs before output or history allocation.
pub fn plan(block: []const u8) Error!Plan {
    const header = try block_decode.readHeader(block);
    const body = try block_decode.analyzeBody(block, header);
    return .{ .decoded_len = header.decoded_len, .body_offset = header.index, .max_offset = body.max_offset };
}

/// Numeric replay cursor for an immutable, caller-retained raw Snappy block.
/// History is owned, but allocator contexts and compressed slices are supplied
/// anew on every call, allowing active value moves without pointer rebinding.
pub const Cursor = struct {
    block_plan: Plan = .{ .decoded_len = 0, .body_offset = 0, .max_offset = 0 },
    input_offset: usize = 0,
    decoded_written: usize = 0,
    literal_remaining: usize = 0,
    copy_remaining: usize = 0,
    copy_offset: usize = 0,
    history: std.ArrayList(u8) = .empty,
    history_start: usize = 0,
    history_len: usize = 0,
    history_ready: bool = false,
    stage: enum { token, literal, copy, done } = .token,

    pub fn init(block_plan: Plan) Cursor {
        return .{ .block_plan = block_plan, .input_offset = block_plan.body_offset };
    }
    /// Logical ring spans max_offset; retained capacity is a reusable highwater
    /// allocation and remains charged to the supplied allocator's owner.
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
        return self.history_len;
    }

    pub fn step(self: *Cursor, allocator: std.mem.Allocator, block: []const u8, output: []u8) Error!Result {
        if (self.stage == .done) return .{ .output_written = 0, .done = true };
        if (self.input_offset > block.len) return error.TruncatedFrame;
        if (output.len == 0 and self.decoded_written != self.block_plan.decoded_len) return .{ .output_written = 0, .done = false };
        if (!self.history_ready) {
            try self.history.ensureTotalCapacityPrecise(allocator, self.block_plan.max_offset);
            self.history.items.len = self.block_plan.max_offset;
            self.history_ready = true;
        }
        var written: usize = 0;
        while (true) switch (self.stage) {
            .token => {
                if (self.input_offset == block.len) {
                    if (self.decoded_written != self.block_plan.decoded_len) return error.TruncatedFrame;
                    self.stage = .done;
                    return .{ .output_written = written, .done = true };
                }
                if (self.decoded_written == self.block_plan.decoded_len) return error.TrailingData;
                const tag = block[self.input_offset];
                self.input_offset += 1;
                if (tag & 3 == 0) {
                    self.literal_remaining = try block_decode.readLiteralLen(tag, block, &self.input_offset);
                    if (self.literal_remaining > self.block_plan.decoded_len - self.decoded_written) return error.SizeMismatch;
                    if (self.literal_remaining > block.len - self.input_offset) return error.TruncatedFrame;
                    self.stage = .literal;
                } else {
                    const count: usize = switch (tag & 3) {
                        1 => 1,
                        2 => 2,
                        3 => 4,
                        else => unreachable,
                    };
                    if (count > block.len - self.input_offset) return error.TruncatedFrame;
                    self.copy_offset = switch (tag & 3) {
                        1 => (@as(usize, tag & 0xe0) << 3) | block[self.input_offset],
                        2 => std.mem.readInt(u16, block[self.input_offset..][0..2], .little),
                        3 => std.mem.readInt(u32, block[self.input_offset..][0..4], .little),
                        else => unreachable,
                    };
                    self.input_offset += count;
                    self.copy_remaining = if (tag & 3 == 1) 4 + ((tag >> 2) & 7) else 1 + (tag >> 2);
                    if (self.copy_offset == 0 or self.copy_offset > self.history_len) return error.InvalidMatch;
                    if (self.copy_remaining > self.block_plan.decoded_len - self.decoded_written) return error.SizeMismatch;
                    self.stage = .copy;
                }
            },
            .literal => {
                const n = @min(self.literal_remaining, output.len - written);
                const bytes = block[self.input_offset..][0..n];
                @memcpy(output[written..][0..n], bytes);
                self.remember(bytes);
                self.input_offset += n;
                self.literal_remaining -= n;
                self.decoded_written += n;
                written += n;
                if (self.literal_remaining != 0) return .{ .output_written = written, .done = false };
                self.stage = .token;
            },
            .copy => {
                const n = @min(self.copy_remaining, output.len - written);
                const seed = if (self.copy_offset > written) @min(n, self.copy_offset - written) else 0;
                for (output[written..][0..seed], 0..) |*byte, i| {
                    const index = ringIndex(self.history.items.len, self.history_start, self.history_len - self.copy_offset + i);
                    byte.* = self.history.items[index];
                }
                if (n > seed) try match_copy.copy(output, written + seed, self.copy_offset, n - seed);
                self.remember(output[written..][0..n]);
                self.copy_remaining -= n;
                self.decoded_written += n;
                written += n;
                if (self.copy_remaining != 0) return .{ .output_written = written, .done = false };
                self.stage = .token;
            },
            .done => return .{ .output_written = written, .done = true },
        };
    }

    fn remember(self: *Cursor, bytes: []const u8) void {
        const capacity = self.history.items.len;
        if (capacity == 0 or bytes.len == 0) return;
        if (bytes.len >= capacity) {
            @memcpy(self.history.items, bytes[bytes.len - capacity ..]);
            self.history_start = 0;
            self.history_len = capacity;
            return;
        }
        for (bytes) |byte| {
            if (self.history_len != capacity) {
                self.history.items[self.history_len] = byte;
                self.history_len += 1;
            } else {
                self.history.items[self.history_start] = byte;
                self.history_start = (self.history_start + 1) % capacity;
            }
        }
    }

    pub fn ringIndex(capacity: usize, start: usize, displacement: usize) usize {
        std.debug.assert(capacity != 0 and start < capacity and displacement < capacity);
        const tail = capacity - start;
        return if (displacement >= tail) displacement - tail else start + displacement;
    }
};
