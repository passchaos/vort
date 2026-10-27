//! Portable Brotli bit output with caller-owned storage and bounded growth.
const std = @import("std");
const bit_count = @import("../../io/bit_count.zig");
const BitCount = bit_count.BitCount;
pub const Error = std.mem.Allocator.Error || error{CorruptFrame};

pub const Writer = struct {
    out: *std.ArrayList(u8),
    bit_index: u3 = 0,
    bounded: bool = false,

    pub fn writeBits(self: *Writer, allocator: std.mem.Allocator, value: u64, count: u6) Error!void {
        if (count == 0) return;
        const total_bits = @as(u7, self.bit_index) + count;
        const bytes: u4 = @intCast((total_bits + 7) / 8);
        const partial = self.bit_index != 0;
        const added: usize = bytes - @as(u4, @intFromBool(partial));
        // Keep allocation requests and partial writes identical when the
        // existing capacity cannot fit this complete field.
        if (added > self.out.capacity - self.out.items.len)
            return self.writeBitsSlow(allocator, value, count);
        const masked = value & ((@as(u64, 1) << count) - 1);
        const shifted = masked << self.bit_index;
        const spill: u8 = if (bytes == 9)
            @truncate(masked >> @as(u6, @intCast(@as(u7, 64) - self.bit_index)))
        else
            0;
        self.writePacked(shifted, spill, bytes, added, total_bits);
    }

    inline fn writePacked(self: *Writer, shifted: u64, spill: u8, bytes: u4, added: usize, total_bits: u7) void {
        const partial = self.bit_index != 0;
        const first = self.out.items.len - @intFromBool(partial);
        const previous = if (partial) self.out.items[first] else 0;
        const merged = shifted | @as(u64, previous);
        self.out.items.len += added;
        const dest = self.out.items[first..][0..bytes];
        switch (bytes) {
            1 => dest[0] = @truncate(merged),
            2 => std.mem.writeInt(u16, dest[0..2], @truncate(merged), .little),
            3 => {
                std.mem.writeInt(u16, dest[0..2], @truncate(merged), .little);
                dest[2] = @truncate(merged >> 16);
            },
            4 => std.mem.writeInt(u32, dest[0..4], @truncate(merged), .little),
            5...7 => {
                std.mem.writeInt(u32, dest[0..4], @truncate(merged), .little);
                var tail = merged >> 32;
                for (dest[4..]) |*byte| {
                    byte.* = @truncate(tail);
                    tail >>= 8;
                }
            },
            8, 9 => {
                std.mem.writeInt(u64, dest[0..8], merged, .little);
                if (bytes == 9) dest[8] = spill;
            },
            else => unreachable,
        }
        self.bit_index = @truncate(total_bits);
    }

    fn writeBitsSlow(self: *Writer, allocator: std.mem.Allocator, value: u64, count: u6) Error!void {
        if (count > 64) return error.CorruptFrame;
        if (count == 0) return;
        var remaining: usize = count;
        var cursor = value;
        while (remaining != 0) {
            if (self.bit_index == 0) try self.appendZeroByte(allocator);
            const available: usize = 8 - @as(usize, self.bit_index);
            const take = @min(remaining, available);
            const mask = (@as(u64, 1) << @intCast(take)) - 1;
            self.out.items[self.out.items.len - 1] |= @as(u8, @intCast(cursor & mask)) << self.bit_index;
            cursor >>= @intCast(take);
            remaining -= take;
            const next = @as(usize, self.bit_index) + take;
            self.bit_index = @intCast(next & 7);
        }
    }

    /// Writes a validated, non-empty Brotli Huffman code. Huffman code widths
    /// are capped at 15 bits, so the code can touch at most three bytes. The
    /// payload encoder has already validated the tree and code width; spelling
    /// out those writes avoids the general bit writer's per-byte loop in its
    /// hottest call sites while preserving the same growth and bounded-output
    /// behavior through `appendZeroByte`.
    pub inline fn writeHuffmanBits(self: *Writer, allocator: std.mem.Allocator, value: u16, count: u4) Error!void {
        std.debug.assert(count != 0);
        std.debug.assert(value < (@as(u16, 1) << count));

        if (self.bit_index == 0) try self.appendZeroByte(allocator);
        const shifted = @as(u32, value) << self.bit_index;
        self.out.items[self.out.items.len - 1] |= @truncate(shifted);

        const total_bits = @as(u5, self.bit_index) + @as(u5, count);
        if (total_bits > 8) {
            try self.appendZeroByte(allocator);
            self.out.items[self.out.items.len - 1] = @truncate(shifted >> 8);
            if (total_bits > 16) {
                try self.appendZeroByte(allocator);
                self.out.items[self.out.items.len - 1] = @truncate(shifted >> 16);
            }
        }
        self.bit_index = @truncate(total_bits & 7);
    }

    inline fn appendZeroByte(self: *Writer, allocator: std.mem.Allocator) Error!void {
        if (self.out.items.len < self.out.capacity) {
            self.out.appendAssumeCapacity(0);
        } else if (self.bounded) {
            return error.OutOfMemory;
        } else {
            try self.out.append(allocator, 0);
        }
    }

    pub fn alignToByte(self: *Writer) void {
        self.bit_index = 0;
    }

    pub fn bitPosition(self: *const Writer) BitCount {
        return if (self.bit_index == 0) bit_count.fromBytesAssumeBounded(self.out.items.len) else bit_count.positionAssumeBounded(self.out.items.len - 1, self.bit_index);
    }

    pub fn writeAlignedBytes(self: *Writer, allocator: std.mem.Allocator, bytes: []const u8) Error!void {
        if (self.bit_index != 0) return error.CorruptFrame;
        if (self.bounded) {
            try self.out.appendSliceBounded(bytes);
        } else {
            try self.out.appendSlice(allocator, bytes);
        }
    }
};
