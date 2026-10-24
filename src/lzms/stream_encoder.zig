const std = @import("std");
const probability = @import("probability.zig");

pub const RangeEncoder = struct {
    bytes: std.ArrayList(u8) = .empty,
    lower_bound: u64 = 0,
    range_size: u32 = std.math.maxInt(u32),
    cache: u16 = 0,
    cache_size: u32 = 1,
    started: bool = false,

    pub fn encodeBit(
        self: *RangeEncoder,
        allocator: std.mem.Allocator,
        bit: u1,
        zero_probability: u32,
    ) !void {
        if (self.range_size <= 0xffff) {
            self.range_size <<= 16;
            try self.shiftLow(allocator);
        }
        const bound = (self.range_size >> probability.bits) * zero_probability;
        if (bit == 0) {
            self.range_size = bound;
        } else {
            self.lower_bound += bound;
            self.range_size -= bound;
        }
    }

    fn shiftLow(self: *RangeEncoder, allocator: std.mem.Allocator) !void {
        const low: u32 = @truncate(self.lower_bound);
        const carry: u16 = @truncate(self.lower_bound >> 32);
        if (low < 0xffff_0000 or carry != 0) {
            var pending = self.cache_size;
            self.cache_size = 0;
            while (pending != 0) : (pending -= 1) {
                if (self.started) {
                    try appendU16(allocator, &self.bytes, self.cache +% carry);
                } else {
                    self.started = true;
                }
                self.cache = 0xffff;
            }
            self.cache = @truncate(self.lower_bound >> 16);
        }
        self.cache_size += 1;
        self.lower_bound = (self.lower_bound & 0xffff) << 16;
    }

    pub fn finish(self: *RangeEncoder, allocator: std.mem.Allocator) !void {
        for (0..4) |_|
            try self.shiftLow(allocator);
        if (self.bytes.items.len < 4 or self.bytes.items.len & 1 != 0)
            return error.InvalidLzms;
    }
};

pub const BackwardBitWriter = struct {
    allocator: std.mem.Allocator,
    words: std.ArrayList(u16) = .empty,
    bit_buffer: u64 = 0,
    bit_count: u6 = 0,

    pub fn writeBits(self: *BackwardBitWriter, value: u32, count: u6) !void {
        if (count > 30) return error.InvalidLzms;
        if (count == 0) {
            if (value != 0) return error.InvalidLzms;
            return;
        }
        if (value >> @intCast(count) != 0) return error.InvalidLzms;
        self.bit_count += count;
        self.bit_buffer = (self.bit_buffer << count) | value;
        while (self.bit_count >= 16) {
            self.bit_count -= 16;
            try self.words.append(
                self.allocator,
                @truncate(self.bit_buffer >> @intCast(self.bit_count)),
            );
        }
    }

    pub fn finish(self: *BackwardBitWriter) !void {
        if (self.bit_count == 0) return;
        try self.words.append(
            self.allocator,
            @truncate(self.bit_buffer << @intCast(16 - self.bit_count)),
        );
        self.bit_count = 0;
        self.bit_buffer = 0;
    }
};

fn appendU16(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u16,
) !void {
    try output.ensureUnusedCapacity(allocator, 2);
    appendU16AssumeCapacity(output, value);
}

pub fn appendU16AssumeCapacity(output: *std.ArrayList(u8), value: u16) void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    output.appendSliceAssumeCapacity(&bytes);
}

test "LZMS backward encoder preserves every alignment through 30-bit extra fields" {
    const allocator = std.testing.allocator;
    for (0..16) |prefix_count| for (0..31) |count| {
        const mask: u32 = (@as(u32, 1) << @intCast(count)) - 1;
        for ([_]u32{ 0, mask, 0x2534_ac91 & mask }) |value| {
            var writer = BackwardBitWriter{ .allocator = allocator };
            defer writer.words.deinit(allocator);
            const prefix: u32 = (@as(u32, 1) << @intCast(prefix_count)) - 1;
            try writer.writeBits(prefix, @intCast(prefix_count));
            try writer.writeBits(value, @intCast(count));
            try writer.finish();
            const total = prefix_count + count;
            try std.testing.expectEqual((total + 15) / 16, writer.words.items.len);
            for (0..writer.words.items.len * 16) |bit| {
                const actual = (writer.words.items[bit / 16] >> @intCast(15 - bit % 16)) & 1;
                const expected: u16 = if (bit < prefix_count) 1 else if (bit < total) @intCast((value >> @intCast(total - bit - 1)) & 1) else 0;
                try std.testing.expectEqual(expected, actual);
            }
        }
    };
}

test "LZMS backward encoder rejects unrepresentable fields before mutating state" {
    var writer = BackwardBitWriter{ .allocator = std.testing.allocator };
    defer writer.words.deinit(std.testing.allocator);
    try writer.writeBits(0x1f, 5);
    try std.testing.expectError(error.InvalidLzms, writer.writeBits(1, 0));
    try std.testing.expectError(error.InvalidLzms, writer.writeBits(0x20, 5));
    try std.testing.expectError(error.InvalidLzms, writer.writeBits(0, 31));
    try std.testing.expectError(error.InvalidLzms, writer.writeBits(0, 63));
    try std.testing.expectEqual(@as(u6, 5), writer.bit_count);
    try std.testing.expectEqual(@as(u64, 0x1f), writer.bit_buffer);
    try std.testing.expectEqual(@as(usize, 0), writer.words.items.len);
    try writer.finish();
    try std.testing.expectEqual(@as(u16, 0xf800), writer.words.items[0]);
}
