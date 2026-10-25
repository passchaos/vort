//! Independent RFC7932 metadata wire oracle. It does not use the encoder's
//! header plan or bounds to decode count fields, padding, or payload length.
const std = @import("std");
const header = @import("metadata_header.zig");

pub const Cursor = struct {
    input: []const u8,
    position: usize = 0,

    pub fn read(self: *Cursor, width: u6) !u32 {
        if (@as(u128, self.position) + width > @as(u128, self.input.len) * 8) return error.TruncatedFrame;
        var value: u32 = 0;
        for (0..width) |i| {
            const bit = self.position + i;
            value |= @as(u32, (self.input[bit / 8] >> @as(u3, @intCast(bit % 8))) & 1) << @as(u5, @intCast(i));
        }
        self.position += width;
        return value;
    }
    pub fn alignZero(self: *Cursor) !void {
        while (self.position % 8 != 0) if (try self.read(1) != 0) return error.NonzeroPadding;
    }
};

pub const Metadata = struct { mskipbytes: u2, length: usize, payload_offset: usize };

pub fn readWindow(reader: *Cursor) !u5 {
    if (try reader.read(1) == 0) return 16;
    const low = try reader.read(3);
    if (low != 0) return @intCast(17 + low);
    const tail = try reader.read(3);
    if (tail == 0) return 17;
    if (tail != 1) return @intCast(8 + tail);
    if (try reader.read(1) != 0) return error.InvalidWindow;
    const width = try reader.read(6);
    if (width < 10 or width > 30) return error.InvalidWindow;
    return @intCast(width);
}

pub fn readMetadata(reader: *Cursor) !Metadata {
    if (try reader.read(1) != 0 or try reader.read(2) != 3) return error.InvalidMetadataHeader;
    if (try reader.read(1) != 0) return error.NonzeroMetadataReserved;
    const count: u2 = @intCast(try reader.read(2));
    const length: usize = if (count == 0) 0 else blk: {
        const raw = try reader.read(@as(u6, count) * 8);
        if (count > 1 and raw >> (@as(u5, count - 1) * 8) == 0) return error.NonminimalMetadataLength;
        break :blk @as(usize, raw) + 1;
    };
    try reader.alignZero();
    return .{ .mskipbytes = count, .length = length, .payload_offset = reader.position / 8 };
}

pub fn prefix(input: []const u8) !Metadata {
    var reader: Cursor = .{ .input = input };
    _ = try readWindow(&reader);
    return readMetadata(&reader);
}

/// Only stored payloads need to be skipped by this small metadata transition
/// oracle; full compressed parsing remains the codec decoder's responsibility.
pub fn afterStored(input: []const u8) !Metadata {
    var reader: Cursor = .{ .input = input };
    _ = try readWindow(&reader);
    if (try reader.read(1) != 0) return error.InvalidStoredHeader;
    const nibbles = try reader.read(2);
    if (nibbles == 3) return error.InvalidStoredHeader;
    const length = @as(usize, try reader.read(@intCast((nibbles + 4) * 4))) + 1;
    if (try reader.read(1) != 1) return error.InvalidStoredHeader;
    try reader.alignZero();
    const offset = reader.position / 8;
    if (offset > input.len or length > input.len - offset) return error.TruncatedFrame;
    reader.position += length * 8;
    return readMetadata(&reader);
}

const StackWriter = struct {
    bytes: [8]u8 = @splat(0),
    position: usize = 0,
    pub fn writeBits(self: *StackWriter, _: std.mem.Allocator, value: u64, width: u6) !void {
        if (self.position + width > self.bytes.len * 8) return error.OutputTooSmall;
        for (0..width) |i| {
            self.bytes[self.position / 8] |= @as(u8, @intCast((value >> @as(u6, @intCast(i))) & 1)) << @as(u3, @intCast(self.position % 8));
            self.position += 1;
        }
    }
    pub fn alignToByte(self: *StackWriter) void {
        self.position += (8 - self.position % 8) % 8;
    }
};

test "Brotli metadata independent header parser verifies every RFC width and bit alignment" {
    const lengths = [_]usize{ 0, 1, 255, 256, 257, 65535, 65536, 65537, 16777215, 16777216 };
    const counts = [_]u2{ 0, 1, 1, 1, 2, 2, 2, 3, 3, 3 };
    for (lengths, counts) |length, count| {
        for (0..8) |q| {
            var writer: StackWriter = .{};
            const prefix_bits: u64 = (@as(u64, 1) << @as(u6, @intCast(q))) - 1;
            try writer.writeBits(std.testing.allocator, prefix_bits, @intCast(q));
            const plan = try header.plan(length);
            try plan.write(std.testing.allocator, &writer);
            var reader: Cursor = .{ .input = writer.bytes[0 .. writer.position / 8], .position = q };
            const parsed = try readMetadata(&reader);
            try std.testing.expectEqual(count, parsed.mskipbytes);
            try std.testing.expectEqual(length, parsed.length);
            const header_end = q + 6 + @as(usize, count) * 8;
            const aligned = (header_end / 8 + @intFromBool(header_end % 8 != 0)) * 8;
            try std.testing.expectEqual(aligned, writer.position);
            try std.testing.expectEqual(aligned / 8, parsed.payload_offset);
            try std.testing.expectEqual(@as(header.BitCount, aligned) + @as(header.BitCount, length) * 8, try header.addBits(q, length));
            if (q != 0) try std.testing.expectEqual(@as(u8, @intCast(prefix_bits)), writer.bytes[0] & @as(u8, @intCast(prefix_bits)));
        }
    }
    try std.testing.expectError(error.InvalidBlockPlan, header.plan(16777217));
}

test "Brotli metadata independent parser rejects reserved padding nonminimal and truncated fields" {
    var writer: StackWriter = .{};
    try (try header.plan(65537)).write(std.testing.allocator, &writer);
    const bytes = writer.bytes[0 .. writer.position / 8];
    var reserved = writer.bytes;
    reserved[0] |= 1 << 3;
    var reader: Cursor = .{ .input = reserved[0..bytes.len] };
    try std.testing.expectError(error.NonzeroMetadataReserved, readMetadata(&reader));
    for (1..bytes.len) |cut| {
        var truncated: Cursor = .{ .input = bytes[0..cut] };
        try std.testing.expectError(error.TruncatedFrame, readMetadata(&truncated));
    }
    var nonminimal: Cursor = .{ .input = &.{ 0x26, 0, 0 } }; // MSKIPBYTES2, high length byte0.
    try std.testing.expectError(error.NonminimalMetadataLength, readMetadata(&nonminimal));
    var padding: Cursor = .{ .input = &.{0xc6} }; // Empty metadata, nonzero high padding.
    try std.testing.expectError(error.NonzeroPadding, readMetadata(&padding));
}
