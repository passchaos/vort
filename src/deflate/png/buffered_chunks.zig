//! Whole-input PNG bit reservoir with one physical chunk cursor. Unlike the
//! public resumable chunk reader, advancing staged bits needs no byte cursor
//! synchronization; consumed bits supply the complete zlib/footer accounting.
const std = @import("std");
const reference = @import("../../bitstream.zig");
const Error = @import("../../core.zig").Error;

pub const Reader = struct {
    chunks: []const []const u8,
    chunk_index: usize = 0,
    input: []const u8 = &.{},
    index: usize = 0,
    total_len: usize,
    consumed_bits: usize,
    bit_buffer: u64 = 0,
    bit_count: usize = 0,

    pub fn initAt(chunks: []const []const u8, offset: usize) Error!Reader {
        var total: usize = 0;
        for (chunks) |chunk| total = std.math.add(usize, total, chunk.len) catch return error.IntegerOverflow;
        _ = std.math.mul(usize, total, 8) catch return error.IntegerOverflow;
        if (offset > total) return error.TruncatedFrame;
        var self = Reader{ .chunks = chunks, .total_len = total, .consumed_bits = offset * 8 };
        var remaining = offset;
        while (self.chunk_index < chunks.len) : (self.chunk_index += 1) {
            if (remaining < chunks[self.chunk_index].len) {
                self.input = chunks[self.chunk_index];
                self.index = remaining;
                return self;
            }
            remaining -= chunks[self.chunk_index].len;
        }
        return self;
    }

    pub fn bitPosition(self: Reader) usize {
        return self.consumed_bits;
    }
    pub fn byteOffset(self: Reader) usize {
        return (self.consumed_bits + 7) / 8;
    }
    pub fn hasBits(self: Reader, count: u6) bool {
        return self.consumed_bits <= self.total_len * 8 and count <= self.total_len * 8 - self.consumed_bits;
    }
    pub inline fn hasStagedBits(self: Reader, count: u6) bool {
        return self.bit_count >= count;
    }
    pub inline fn advanceBitsStagedAssumeAvailable(self: *Reader, count: u6) void {
        std.debug.assert(self.bit_count >= count);
        self.bit_buffer >>= @intCast(count);
        self.bit_count -= count;
        self.consumed_bits += count;
    }
    pub fn readBits(self: *Reader, comptime T: type, count: u6) Error!T {
        if (count > @bitSizeOf(T)) return error.CorruptFrame;
        if (!self.hasBits(count)) return error.TruncatedFrame;
        const value = self.peekBitsPadded(T, count);
        self.advanceBitsStagedAssumeAvailable(count);
        return value;
    }
    pub fn peekBits(self: *Reader, comptime T: type, count: u6) Error!T {
        if (count > @bitSizeOf(T)) return error.CorruptFrame;
        if (!self.hasBits(count)) return error.TruncatedFrame;
        return self.peekBitsPadded(T, count);
    }
    pub fn skipBits(self: *Reader, count: u6) Error!void {
        _ = try self.readBits(u64, count);
    }
    pub inline fn peekBitsPadded(self: *Reader, comptime T: type, count: u6) T {
        std.debug.assert(count <= @bitSizeOf(T));
        if (count == 0) return 0;
        self.fill(count);
        return @intCast(self.bit_buffer & ((@as(u64, 1) << @intCast(count)) - 1));
    }
    inline fn nextChunk(self: *Reader) bool {
        while (self.chunk_index + 1 < self.chunks.len) {
            self.chunk_index += 1;
            self.input = self.chunks[self.chunk_index];
            self.index = 0;
            if (self.input.len != 0) return true;
        }
        return false;
    }
    inline fn fill(self: *Reader, required: usize) void {
        if (self.bit_count >= required) return;
        while (self.bit_count < required) {
            if (self.index == self.input.len and !self.nextChunk()) return;
            if (self.input.len - self.index >= 8 and self.bit_count <= 55) {
                const count = (63 - self.bit_count) / 8;
                self.bit_buffer |= std.mem.readInt(u64, self.input[self.index..][0..8], .little) << @intCast(self.bit_count);
                self.bit_count += count * 8;
                self.index += count;
            } else {
                self.bit_buffer |= @as(u64, self.input[self.index]) << @intCast(self.bit_count);
                self.bit_count += 8;
                self.index += 1;
            }
        }
    }
    pub fn alignToByte(self: *Reader) void {
        const padding = (8 - self.consumed_bits % 8) % 8;
        const staged = @min(padding, self.bit_count);
        self.bit_buffer >>= @intCast(staged);
        self.bit_count -= staged;
        self.consumed_bits += padding;
    }
    pub fn readAlignedBytes(self: *Reader, output: []u8) Error!void {
        if (self.consumed_bits % 8 != 0) return error.CorruptFrame;
        const offset = self.byteOffset();
        if (offset > self.total_len or output.len > self.total_len - offset) return error.TruncatedFrame;
        var done: usize = 0;
        while (done < output.len and self.bit_count >= 8) : (done += 1) {
            output[done] = @truncate(self.bit_buffer);
            self.advanceBitsStagedAssumeAvailable(8);
        }
        if (done < output.len) {
            // An unaligned word fill loads a speculative high byte that is not
            // part of bit_count. Bulk aligned input skips beyond that byte,
            // so it must not be ORed into a later refill after the bulk copy.
            self.bit_buffer = 0;
            self.bit_count = 0;
        }
        while (done < output.len) {
            if (self.index == self.input.len and !self.nextChunk()) unreachable;
            const count = @min(output.len - done, self.input.len - self.index);
            @memcpy(output[done..][0..count], self.input[self.index..][0..count]);
            done += count;
            self.index += count;
            self.consumed_bits += count * 8;
        }
    }
    pub fn readAlignedInt(self: *Reader, comptime T: type, endian: std.builtin.Endian) Error!T {
        var bytes: [@sizeOf(T)]u8 = undefined;
        try self.readAlignedBytes(&bytes);
        return std.mem.readInt(T, &bytes, endian);
    }
};

test "PNG general windowed helper reservoir matches chunk reference at every alignment" {
    var bytes: [65]u8 = undefined;
    for (&bytes, 0..) |*value, index| value.* = @truncate(index * 137 + 51);
    for ([_]usize{ 1, 2, 7, 13, 64 }) |size| {
        var chunks: [67][]const u8 = @splat(&.{});
        const count = try std.math.divCeil(usize, bytes.len, size);
        for (chunks[1 .. count + 1], 0..) |*chunk, index| chunk.* = bytes[index * size .. @min(bytes.len, (index + 1) * size)];
        for (0..8) |alignment| {
            var candidate = try Reader.initAt(chunks[0 .. count + 2], 0);
            var oracle = try reference.ChunkedBitReader.init(chunks[0 .. count + 2]);
            try candidate.skipBits(@intCast(alignment));
            try oracle.skipBits(@intCast(alignment));
            for ([_]u6{ 1, 5, 9, 15, 31, 7, 12 }) |bits| {
                try std.testing.expectEqual(oracle.peekBitsPadded(u32, bits), candidate.peekBitsPadded(u32, bits));
                try std.testing.expectEqual(try oracle.readBits(u32, bits), try candidate.readBits(u32, bits));
                try std.testing.expectEqual(oracle.bitPosition(), candidate.bitPosition());
            }
            candidate.alignToByte();
            oracle.alignToByte();
            var got: [32]u8 = undefined;
            var want: [32]u8 = undefined;
            try candidate.readAlignedBytes(&got);
            try oracle.readAlignedBytes(&want);
            try std.testing.expectEqualSlices(u8, &want, &got);
            try std.testing.expectEqual(oracle.byteOffset(), candidate.byteOffset());
            try std.testing.expectEqual(try oracle.readBits(u32, 12), try candidate.readBits(u32, 12));
        }
    }
}

test "PNG general windowed helper reservoir rejects invalid reads without cursor progress" {
    const chunks = [_][]const u8{ &.{}, &.{ 0x55, 0xaa }, &.{} };
    var reader = try Reader.initAt(&chunks, 1);
    const before = reader;
    try std.testing.expectError(error.CorruptFrame, reader.peekBits(u8, 9));
    try std.testing.expectError(error.TruncatedFrame, reader.readBits(u16, 9));
    try std.testing.expectEqualDeep(before, reader);
    try std.testing.expectError(error.TruncatedFrame, Reader.initAt(&chunks, 3));
}
