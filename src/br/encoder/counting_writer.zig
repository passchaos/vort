//! Allocation-free Brotli bit geometry for validated header writers.
const std = @import("std");
const bit_count = @import("../../io/bit_count.zig");
const BitCount = bit_count.BitCount;

pub const Error = bit_count.Error || error{CorruptFrame};

pub const Writer = struct {
    bits: BitCount = 0,
    bit_index: u3 = 0,
    overflowed: bool = false,

    pub fn init(position: BitCount) Writer {
        return .{ .bits = position, .bit_index = @truncate(position) };
    }

    /// Counts a general field without inspecting or validating its value. The
    /// physical writer masks values to the requested width, including zero.
    pub fn writeBits(self: *Writer, _: std.mem.Allocator, _: u64, count: u6) Error!void {
        try self.addBits(count);
    }

    pub inline fn writeHuffmanBits(self: *Writer, _: std.mem.Allocator, value: u16, count: u4) Error!void {
        std.debug.assert(count != 0);
        std.debug.assert(value < (@as(u16, 1) << count));
        try self.addBits(count);
    }

    /// Adds precomputed payload geometry without replaying payload symbols.
    /// Failure leaves the last representable position intact and latches an
    /// overflow so a later checked getter cannot report a successful size.
    pub fn addBits(self: *Writer, count: BitCount) Error!void {
        if (self.overflowed) return error.IntegerOverflow;
        const next = std.math.add(BitCount, self.bits, count) catch {
            self.overflowed = true;
            return error.IntegerOverflow;
        };
        self.bits = next;
        self.bit_index = @truncate(next);
    }

    /// Matches the physical writer's void alignment interface. Rounding at
    /// the maximum address latches overflow for the checked final-size read.
    pub fn alignToByte(self: *Writer) void {
        if (self.bit_index == 0) return;
        self.addBits(8 - @as(BitCount, self.bit_index)) catch {};
        self.bit_index = 0;
    }

    /// Header helpers use this interface only while geometry is representable.
    /// Final size decisions must use a checked getter, including after align.
    pub fn bitPosition(self: *const Writer) BitCount {
        std.debug.assert(!self.overflowed);
        return self.bits;
    }

    pub fn checkedBitPosition(self: *const Writer) Error!BitCount {
        if (self.overflowed) return error.IntegerOverflow;
        return self.bits;
    }

    pub fn checkedByteCount(self: *const Writer) Error!usize {
        return bit_count.ceilBytes(try self.checkedBitPosition());
    }

    /// Only the slice length is observed; the byte storage may be inaccessible.
    pub fn writeAlignedBytes(self: *Writer, _: std.mem.Allocator, bytes: []const u8) Error!void {
        if (self.bit_index != 0) return error.CorruptFrame;
        const count = bit_count.fromBytes(bytes.len) catch {
            self.overflowed = true;
            return error.IntegerOverflow;
        };
        try self.addBits(count);
    }
};

test "Brotli counting writer fields match independent scalar geometry" {
    try @import("counting_writer_tests.zig").fields(@This());
}

test "Brotli counting writer aligned bytes need no allocation or reads" {
    try @import("counting_writer_tests.zig").alignedBytes(@This());
}

test "Brotli counting writer checks overflow and sticky alignment" {
    try @import("counting_writer_tests.zig").overflow(@This());
}
