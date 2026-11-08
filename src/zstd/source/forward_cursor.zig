//! Transactional forward metadata access over a checked source range.
//!
//! Self-delimiting FSE descriptions end immediately before reverse payloads,
//! so the correctness path deliberately fetches one logical byte at a time.
//! This prevents a cache refill from speculatively touching the reverse range.
const std = @import("std");
const core = @import("../../core.zig");
const source_input = @import("input.zig");

pub const Error = core.Error || source_input.Error;
pub const minimum_scratch_len: usize = 1;

pub const Snapshot = struct {
    relative_offset: u64,
    read_calls: u64,
    bytes_loaded: u64,
    scratch_capacity: usize,
    max_request: usize,
};

pub const Cursor = struct {
    range: source_input.Range,
    position: u64 = 0,
    scratch: []u8,
    read_calls: u64 = 0,
    bytes_loaded: u64 = 0,
    max_request: usize = 0,

    pub fn init(range: source_input.Range, scratch: []u8) Error!Cursor {
        if (scratch.len < minimum_scratch_len) return error.OutputTooSmall;
        return .{ .range = range, .scratch = scratch };
    }

    pub fn relativeOffset(self: Cursor) u64 {
        return self.position;
    }

    pub fn absoluteOffset(self: Cursor) Error!u64 {
        return std.math.add(u64, self.range.offset, self.position) catch
            return error.IntegerOverflow;
    }

    pub fn remaining(self: Cursor) u64 {
        return self.range.len - self.position;
    }

    pub fn byte(self: *Cursor) Error!u8 {
        if (self.position >= self.range.len) return error.TruncatedFrame;
        const next_position = std.math.add(u64, self.position, 1) catch
            return error.IntegerOverflow;
        const next_calls = std.math.add(u64, self.read_calls, 1) catch
            return error.IntegerOverflow;
        const next_bytes = std.math.add(u64, self.bytes_loaded, 1) catch
            return error.IntegerOverflow;
        try self.range.readExact(self.position, self.scratch[0..1]);
        const value = self.scratch[0];
        self.position = next_position;
        self.read_calls = next_calls;
        self.bytes_loaded = next_bytes;
        self.max_request = @max(self.max_request, 1);
        return value;
    }

    pub fn skip(self: *Cursor, len: u64) Error!void {
        const next = std.math.add(u64, self.position, len) catch
            return error.IntegerOverflow;
        if (next > self.range.len) return error.TruncatedFrame;
        self.position = next;
    }

    pub fn remainingRange(self: Cursor) Error!source_input.Range {
        return self.range.subrange(self.position, self.remaining());
    }

    pub fn snapshot(self: Cursor) Snapshot {
        return .{
            .relative_offset = self.position,
            .read_calls = self.read_calls,
            .bytes_loaded = self.bytes_loaded,
            .scratch_capacity = self.scratch.len,
            .max_request = self.max_request,
        };
    }
};

pub const BitReader = struct {
    cursor: *Cursor,
    reservoir: u16 = 0,
    available_bits: u5 = 0,

    pub fn read(self: *BitReader, count: u4) Error!u16 {
        std.debug.assert(count != 0 and count <= 9);
        while (self.available_bits < count) {
            self.reservoir |= @as(u16, try self.cursor.byte()) << @intCast(self.available_bits);
            self.available_bits += 8;
        }
        const value = self.reservoir & ((@as(u16, 1) << count) - 1);
        self.reservoir >>= count;
        self.available_bits -= count;
        return value;
    }

    pub fn alignToByte(self: *BitReader) void {
        self.* = .{ .cursor = self.cursor };
    }
};

test "Zstd source forward cursor does not prefetch its remaining range" {
    const byte_source = @import("../../io/source.zig");
    var slice = byte_source.SliceSource{ .bytes = "metadata-reverse" };
    const range = try source_input.Range.init(slice.source(), 0, slice.bytes.len);
    var scratch: [7]u8 = @splat(0xa5);
    var cursor = try Cursor.init(range, &scratch);
    try std.testing.expectEqual(@as(u8, 'm'), try cursor.byte());
    try std.testing.expectEqual(@as(u64, 1), cursor.snapshot().bytes_loaded);
    try std.testing.expectEqual(@as(usize, 1), cursor.snapshot().max_request);
    for (scratch[1..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}
