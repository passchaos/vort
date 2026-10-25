//! RFC 7932 metadata header geometry shared by wire emission and exact bounds.
//! A single block carries at most 2^24 bytes. Options validation needs only the
//! slice length, so oversized borrowed bodies are never read or allocated.
const std = @import("std");
const bit_count = @import("../../io/bit_count.zig");

pub const max_metadata_meta_block_len: usize = 1 << 24;
pub const BitCount = bit_count.BitCount;
pub const Error = bit_count.Error || error{InvalidBlockPlan};

pub const Plan = struct {
    mskipbytes: u2,
    length_bits: u5,
    len_minus_one: u24,

    /// Emit one non-final metadata header with zero reserved/padding bits.
    /// The caller writes its admitted body afterwards, through the same writer.
    pub fn write(self: Plan, allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.writeBits(allocator, 0, 1); // ISLAST = false.
        try writer.writeBits(allocator, 0b11, 2); // MNIBBLES = metadata.
        try writer.writeBits(allocator, 0, 1); // reserved.
        try writer.writeBits(allocator, self.mskipbytes, 2);
        if (self.mskipbytes != 0) try writer.writeBits(allocator, self.len_minus_one, self.length_bits);
        writer.alignToByte();
    }
};

pub fn plan(metadata_len: usize) error{InvalidBlockPlan}!Plan {
    if (metadata_len > max_metadata_meta_block_len) return error.InvalidBlockPlan;
    if (metadata_len == 0) return .{ .mskipbytes = 0, .length_bits = 0, .len_minus_one = 0 };
    const len_minus_one = metadata_len - 1;
    const bytes: u2 = if (len_minus_one <= 0xff) 1 else if (len_minus_one <= 0xffff) 2 else 3;
    return .{ .mskipbytes = bytes, .length_bits = @as(u5, bytes) * 8, .len_minus_one = @intCast(len_minus_one) };
}

pub fn addBits(start: BitCount, metadata_len: usize) Error!BitCount {
    const header = try plan(metadata_len);
    const after_header = std.math.add(BitCount, start, 6 + @as(BitCount, header.length_bits)) catch return error.IntegerOverflow;
    const payload_start = std.math.add(BitCount, after_header, (8 - after_header % 8) % 8) catch return error.IntegerOverflow;
    return std.math.add(BitCount, payload_start, try bit_count.fromBytes(metadata_len)) catch error.IntegerOverflow;
}

test "Brotli metadata header complete RFC length and byte-alignment geometry" {
    const lengths = [_]usize{ 0, 1, 255, 256, 257, 65535, 65536, 65537, max_metadata_meta_block_len };
    const widths = [_]u2{ 0, 1, 1, 1, 2, 2, 2, 3, 3 };
    for (lengths, widths) |length, bytes| {
        const header = try plan(length);
        try std.testing.expectEqual(bytes, header.mskipbytes);
        try std.testing.expectEqual(@as(u5, bytes) * 8, header.length_bits);
        try std.testing.expectEqual(@as(u24, @intCast(length -| 1)), header.len_minus_one);
        for (0..8) |q| {
            const raw = q + 6 + @as(usize, bytes) * 8;
            const expected = (raw / 8 + @intFromBool(raw % 8 != 0)) * 8 + length * 8;
            try std.testing.expectEqual(@as(BitCount, expected), try addBits(q, length));
        }
    }
    try std.testing.expectError(error.InvalidBlockPlan, plan(max_metadata_meta_block_len + 1));
    try std.testing.expectError(error.InvalidBlockPlan, addBits(std.math.maxInt(BitCount), max_metadata_meta_block_len + 1));
    try std.testing.expectError(error.IntegerOverflow, addBits(std.math.maxInt(BitCount), 0));
    try std.testing.expectError(error.IntegerOverflow, addBits(std.math.maxInt(BitCount) - 20, 65537));
}

test "Brotli metadata header writer preserves exact fields at every starting offset" {
    const Writer = struct {
        bytes: [8]u8 = @splat(0),
        position: usize,

        pub fn writeBits(self: *@This(), _: std.mem.Allocator, value: u64, count: u6) error{InvalidBlockPlan}!void {
            for (0..count) |bit| {
                const one: u8 = @intCast((value >> @intCast(bit)) & 1);
                self.bytes[self.position / 8] |= one << @as(u3, @intCast(self.position % 8));
                self.position += 1;
            }
        }
        pub fn alignToByte(self: *@This()) void {
            self.position += (8 - self.position % 8) % 8;
        }
    };
    for ([_]usize{ 0, 1, 256, 257, 65536, 65537, max_metadata_meta_block_len }) |length| {
        const header = try plan(length);
        for (0..8) |q| {
            var writer: Writer = .{ .position = q };
            const prefix: u64 = (@as(u64, 1) << @intCast(q)) - 1;
            writer.bytes[0] = @intCast(prefix);
            try header.write(std.testing.allocator, &writer);
            const fields: u64 = 0b110 | (@as(u64, header.mskipbytes) << 4) |
                (@as(u64, header.len_minus_one) << 6);
            const expected = prefix | (fields << @intCast(q));
            var bytes: [8]u8 = undefined;
            std.mem.writeInt(u64, &bytes, expected, .little);
            try std.testing.expectEqualDeep(bytes, writer.bytes);
            try std.testing.expectEqual((q + 6 + @as(usize, header.length_bits) + 7) / 8 * 8, writer.position);
        }
    }
}
