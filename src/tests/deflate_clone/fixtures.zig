//! Small independent RFC 1951 producers and table-free wrapper checksums.
const std = @import("std");

pub const Fixture = struct {
    wire: []u8,
    plain: []u8,

    pub fn deinit(self: Fixture, allocator: std.mem.Allocator) void {
        allocator.free(self.wire);
        allocator.free(self.plain);
    }
};

const Bits = struct {
    allocator: std.mem.Allocator,
    bytes: std.ArrayList(u8) = .empty,
    byte: u8 = 0,
    used: u4 = 0,

    fn put(self: *Bits, value: u32, width: u6) !void {
        var remaining = width;
        var word = value;
        while (remaining != 0) : (remaining -= 1) {
            self.byte |= @as(u8, @intCast(word & 1)) << @intCast(self.used);
            self.used += 1;
            word >>= 1;
            if (self.used == 8) {
                try self.bytes.append(self.allocator, self.byte);
                self.byte = 0;
                self.used = 0;
            }
        }
    }

    fn symbol(self: *Bits, code: u32, width: u6) !void {
        var reversed: u32 = 0;
        for (0..width) |index| reversed = (reversed << 1) | ((code >> @intCast(index)) & 1);
        try self.put(reversed, width);
    }

    fn fixed(self: *Bits, value: usize) !void {
        if (value <= 143) return self.symbol(@intCast(0x30 + value), 8);
        if (value <= 255) return self.symbol(@intCast(0x190 + value - 144), 9);
        if (value <= 279) return self.symbol(@intCast(value - 256), 7);
        return self.symbol(@intCast(0xc0 + value - 280), 8);
    }

    fn finish(self: *Bits) ![]u8 {
        if (self.used != 0) try self.put(0, @intCast(8 - self.used));
        return self.bytes.toOwnedSlice(self.allocator);
    }
};

/// One literal and an overlapping length-258 / distance-one match.
pub fn fixedMatch(allocator: std.mem.Allocator) !Fixture {
    var bits: Bits = .{ .allocator = allocator };
    defer bits.bytes.deinit(allocator);
    try bits.put(3, 3);
    try bits.fixed('x');
    try bits.fixed(285);
    try bits.symbol(0, 5);
    try bits.fixed(256);
    const wire = try bits.finish();
    errdefer allocator.free(wire);
    const plain = try allocator.alloc(u8, 259);
    @memset(plain, 'x');
    return .{ .wire = wire, .plain = plain };
}

pub fn dictionaryMatch(allocator: std.mem.Allocator) !Fixture {
    var bits: Bits = .{ .allocator = allocator };
    defer bits.bytes.deinit(allocator);
    try bits.put(3, 3);
    try bits.fixed(285);
    try bits.symbol(0, 5);
    try bits.fixed(256);
    const wire = try bits.finish();
    errdefer allocator.free(wire);
    const plain = try allocator.alloc(u8, 258);
    @memset(plain, 'x');
    return .{ .wire = wire, .plain = plain };
}

/// Complete literal and distance trees force the semantic path. Output crosses
/// a 32 KiB generation and finishes with two distinct overlapping matches.
pub fn dynamicGenerations(allocator: std.mem.Allocator) !Fixture {
    var bits: Bits = .{ .allocator = allocator };
    defer bits.bytes.deinit(allocator);
    try bits.put(5, 3);
    try bits.put(29, 5);
    try bits.put(29, 5);
    try bits.put(8, 4);
    for ([_]usize{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4 }) |value|
        try bits.put(if (value == 4 or value == 5 or value == 8 or value == 9) 2 else 0, 3);
    // Code-length alphabet {4,5,8,9} has canonical two-bit codes 0..3.
    for (0..286) |value| try bits.symbol(if (value < 226) 2 else 3, 2);
    for (0..30) |value| try bits.symbol(if (value < 2) 0 else 1, 2);
    for (0..40000) |_| try bits.symbol('x', 8);
    try bits.symbol(452 + 285 - 226, 9);
    try bits.symbol(0, 4);
    try bits.symbol('y', 8);
    try bits.symbol(452 + 285 - 226, 9);
    try bits.symbol(0, 4);
    try bits.symbol(452 + 256 - 226, 9);
    const wire = try bits.finish();
    errdefer allocator.free(wire);
    const plain = try allocator.alloc(u8, 40517);
    @memset(plain[0..40258], 'x');
    @memset(plain[40258..], 'y');
    return .{ .wire = wire, .plain = plain };
}

pub fn adler(plain: []const u8) u32 {
    var a: u32 = 1;
    var b: u32 = 0;
    for (plain) |value| {
        a = (a + value) % 65521;
        b = (b + a) % 65521;
    }
    return (b << 16) | a;
}

pub fn crc(plain: []const u8) u32 {
    var value: u32 = 0xffffffff;
    for (plain) |byte| {
        value ^= byte;
        for (0..8) |_| value = (value >> 1) ^ (if ((value & 1) != 0) @as(u32, 0xedb88320) else 0);
    }
    return ~value;
}

pub fn repeatedAdler(count: anytype) u32 {
    const n: u128 = count;
    const a: u32 = @intCast((1 + 120 * n) % 65521);
    const b: u32 = @intCast((n + 120 * n * (n + 1) / 2) % 65521);
    return (b << 16) | a;
}

fn crcByte(initial: u32, byte: u8) u32 {
    var value = initial ^ byte;
    for (0..8) |_| value = (value >> 1) ^ (if ((value & 1) != 0) @as(u32, 0xedb88320) else 0);
    return value;
}

/// Binary exponentiation of the affine, table-free one-byte CRC recurrence.
/// It calls no implementation checksum or combine primitive.
pub fn repeatedCrc(count: anytype) u32 {
    const Transform = struct {
        columns: [32]u32,
        bias: u32,

        fn apply(self: @This(), value: u32) u32 {
            var result = self.bias;
            for (self.columns, 0..) |column, index|
                if ((value & (@as(u32, 1) << @intCast(index))) != 0) {
                    result ^= column;
                };
            return result;
        }
    };
    var power: Transform = .{ .columns = undefined, .bias = crcByte(0, 'x') };
    for (&power.columns, 0..) |*column, index|
        column.* = crcByte(@as(u32, 1) << @intCast(index), 'x') ^ power.bias;
    var remaining = count;
    var value: u32 = 0xffffffff;
    while (remaining != 0) {
        if ((remaining & 1) != 0) value = power.apply(value);
        remaining >>= 1;
        const old = power;
        for (&power.columns, old.columns) |*column, previous| column.* = old.apply(previous) ^ old.bias;
        power.bias = old.apply(old.bias);
    }
    return ~value;
}

pub fn wrap(allocator: std.mem.Allocator, fixture: Fixture, comptime gzip: bool) ![]u8 {
    const header: []const u8 = if (gzip) &.{ 0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 3 } else &.{ 0x78, 0x01 };
    const footer_len: usize = if (gzip) 8 else 4;
    const wire = try allocator.alloc(u8, header.len + fixture.wire.len + footer_len);
    @memcpy(wire[0..header.len], header);
    @memcpy(wire[header.len..][0..fixture.wire.len], fixture.wire);
    const footer = wire[header.len + fixture.wire.len ..];
    if (gzip) {
        std.mem.writeInt(u32, footer[0..4], crc(fixture.plain), .little);
        std.mem.writeInt(u32, footer[4..8], @intCast(fixture.plain.len), .little);
    } else std.mem.writeInt(u32, footer[0..4], adler(fixture.plain), .big);
    return wire;
}

pub fn wrapDictionary(allocator: std.mem.Allocator, fixture: Fixture, dictionary: []const u8) ![]u8 {
    const wire = try allocator.alloc(u8, 6 + fixture.wire.len + 4);
    @memcpy(wire[0..2], &[_]u8{ 0x78, 0x20 });
    std.mem.writeInt(u32, wire[2..6], adler(dictionary), .big);
    @memcpy(wire[6..][0..fixture.wire.len], fixture.wire);
    std.mem.writeInt(u32, wire[6 + fixture.wire.len ..][0..4], adler(fixture.plain), .big);
    return wire;
}
