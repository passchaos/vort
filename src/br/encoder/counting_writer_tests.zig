const std = @import("std");
const bit_count = @import("../../io/bit_count.zig");
const BitCount = bit_count.BitCount;
const BitWriter = @import("bit_writer.zig").Writer;

/// Deliberately emits one bit at a time into fixed storage. Byte occupancy,
/// rather than a sum of field widths, supplies the independent size oracle.
const Scalar = struct {
    bytes: [32]u8 = @splat(0),
    len: usize = 0,
    bit_index: u3 = 0,

    fn write(self: *Scalar, value: u64, count: usize) void {
        for (0..count) |index| {
            if (self.bit_index == 0) self.len += 1;
            const bit: u8 = @intCast((value >> @as(u6, @intCast(index))) & 1);
            self.bytes[self.len - 1] |= bit << self.bit_index;
            self.bit_index +%= 1;
        }
    }

    fn alignToByte(self: *Scalar) void {
        if (self.bit_index != 0) self.bit_index = 0;
    }

    fn position(self: *const Scalar) BitCount {
        return if (self.bit_index == 0)
            @as(BitCount, self.len) * 8
        else
            @as(BitCount, self.len - 1) * 8 + self.bit_index;
    }
};

fn expectGeometry(comptime module: type, writer: *const module.Writer, scalar: *const Scalar) !void {
    try std.testing.expectEqual(scalar.bit_index, writer.bit_index);
    try std.testing.expectEqual(scalar.position(), writer.bitPosition());
    try std.testing.expectEqual(scalar.position(), try writer.checkedBitPosition());
    try std.testing.expectEqual(scalar.len, try writer.checkedByteCount());
}

pub fn fields(comptime module: type) !void {
    var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const allocator = heap.allocator();
    const values = [_]u64{ 0, 1, std.math.maxInt(u64), 0x1357_9bdf_2468_ace0 };
    for (0..8) |offset| {
        for (0..64) |width| {
            for (values) |value| {
                var scalar: Scalar = .{};
                scalar.write(0xa5, offset);
                var writer = module.Writer.init(offset);
                try writer.writeBits(allocator, value, @intCast(width));
                scalar.write(value, width);
                try expectGeometry(module, &writer, &scalar);

                var storage: [32]u8 = @splat(0);
                var out: std.ArrayList(u8) = .{ .items = storage[0..0], .capacity = storage.len };
                var physical = BitWriter{ .out = &out, .bounded = true };
                try physical.writeBits(allocator, 0xa5, @intCast(offset));
                try physical.writeBits(allocator, value, @intCast(width));
                try std.testing.expectEqual(writer.bitPosition(), physical.bitPosition());
                try std.testing.expectEqualSlices(u8, scalar.bytes[0..scalar.len], out.items);
            }
        }
        for (1..16) |width| {
            const mask = (@as(u16, 1) << @as(u4, @intCast(width))) - 1;
            for ([_]u16{ 0, 1, 0x5555, 0x7fff }) |value| {
                var scalar: Scalar = .{};
                scalar.write(0xa5, offset);
                var writer = module.Writer.init(offset);
                try writer.writeHuffmanBits(allocator, value & mask, @intCast(width));
                scalar.write(value & mask, width);
                try expectGeometry(module, &writer, &scalar);
            }
        }
    }
    try std.testing.expectEqual(@as(usize, 0), heap.allocated_bytes);
    try std.testing.expect(!heap.has_induced_failure);
}

pub fn alignedBytes(comptime module: type) !void {
    var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const allocator = heap.allocator();
    for (0..8) |offset| {
        for (0..17) |byte_count| {
            var writer = module.Writer.init(offset);
            var scalar: Scalar = .{};
            scalar.write(0xa5, offset);
            if (offset != 0) {
                try std.testing.expectError(error.CorruptFrame, writer.writeAlignedBytes(allocator, &.{}));
                try expectGeometry(module, &writer, &scalar);
            }
            writer.alignToByte();
            scalar.alignToByte();
            // This address must never be read, including for empty slices.
            const inaccessible = @as([*]const u8, @ptrFromInt(1))[0..byte_count];
            try writer.writeAlignedBytes(allocator, inaccessible);
            for (0..byte_count) |_| scalar.write(0, 8);
            try expectGeometry(module, &writer, &scalar);
            writer.alignToByte();
            try expectGeometry(module, &writer, &scalar);
        }
    }
    var writer: module.Writer = .{};
    const million_bytes = @as([*]const u8, @ptrFromInt(1))[0..1_000_000];
    try writer.writeAlignedBytes(allocator, million_bytes);
    try std.testing.expectEqual(@as(BitCount, 8_000_000), try writer.checkedBitPosition());
    try std.testing.expectEqual(@as(usize, 1_000_000), try writer.checkedByteCount());
    try std.testing.expectEqual(@as(usize, 0), heap.allocated_bytes);
    try std.testing.expect(!heap.has_induced_failure);
}

pub fn overflow(comptime module: type) !void {
    const allocator = std.testing.allocator;
    const maximum: BitCount = std.math.maxInt(BitCount);
    var writer = module.Writer.init(maximum - 3);
    try writer.writeBits(allocator, std.math.maxInt(u64), 3);
    try std.testing.expectEqual(maximum, try writer.checkedBitPosition());
    try std.testing.expectEqual(@as(u3, 7), writer.bit_index);
    try writer.writeBits(allocator, std.math.maxInt(u64), 0);
    try std.testing.expectError(error.IntegerOverflow, writer.writeBits(allocator, 0, 1));
    try std.testing.expectEqual(maximum, writer.bits);
    try std.testing.expectError(error.IntegerOverflow, writer.checkedBitPosition());
    try std.testing.expectError(error.IntegerOverflow, writer.checkedByteCount());
    try std.testing.expectError(error.IntegerOverflow, writer.addBits(0));

    for (1..8) |tail| {
        writer = module.Writer.init(maximum - (7 - tail));
        writer.alignToByte();
        try std.testing.expectEqual(@as(u3, 0), writer.bit_index);
        try std.testing.expectError(error.IntegerOverflow, writer.checkedBitPosition());
        try std.testing.expectError(error.IntegerOverflow, writer.checkedByteCount());
        writer.alignToByte();
        try std.testing.expectError(error.IntegerOverflow, writer.checkedBitPosition());
    }
    writer = module.Writer.init(maximum - 7);
    writer.alignToByte();
    try std.testing.expectEqual(maximum - 7, try writer.checkedBitPosition());
    const one_byte = @as([*]const u8, @ptrFromInt(1))[0..1];
    try std.testing.expectError(error.IntegerOverflow, writer.writeAlignedBytes(allocator, one_byte));
    try std.testing.expectError(error.IntegerOverflow, writer.checkedByteCount());

    writer = module.Writer.init(maximum - 15);
    try writer.writeHuffmanBits(allocator, 0x7fff, 15);
    try std.testing.expectEqual(maximum, try writer.checkedBitPosition());
    try std.testing.expectError(error.IntegerOverflow, writer.writeHuffmanBits(allocator, 0, 1));

    writer = module.Writer.init(maximum);
    if (@bitSizeOf(usize) < 64) {
        try std.testing.expectError(error.IntegerOverflow, writer.checkedByteCount());
    } else {
        try std.testing.expectEqual(bit_count.max_addressable_bytes + 1, try writer.checkedByteCount());
        writer = .{};
        const oversized = @as([*]const u8, @ptrFromInt(1))[0 .. bit_count.max_addressable_bytes + 1];
        try std.testing.expectError(error.IntegerOverflow, writer.writeAlignedBytes(allocator, oversized));
        try std.testing.expectError(error.IntegerOverflow, writer.checkedBitPosition());
    }
}
