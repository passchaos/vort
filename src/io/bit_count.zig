const std = @import("std");

/// Whole-input bit addresses are wider than byte indices on narrow targets.
/// Preserve the established native integer type on 64-bit targets.
pub const BitCount = if (@bitSizeOf(usize) < 64) u64 else usize;
pub const Error = error{IntegerOverflow};
pub const max_addressable_bytes: usize = @intCast(@min(
    @as(BitCount, std.math.maxInt(usize)),
    std.math.maxInt(BitCount) / 8,
));

pub fn fromBytes(bytes: usize) Error!BitCount {
    return std.math.mul(BitCount, @as(BitCount, bytes), 8) catch error.IntegerOverflow;
}

/// Constructors without an error return require representable byte geometry.
pub fn fromBytesAssumeBounded(bytes: usize) BitCount {
    std.debug.assert(bytes <= max_addressable_bytes);
    return @as(BitCount, bytes) * 8;
}

pub fn position(byte_index: usize, bit_index: u3) Error!BitCount {
    return std.math.add(BitCount, try fromBytes(byte_index), bit_index) catch error.IntegerOverflow;
}

pub fn positionAssumeBounded(byte_index: usize, bit_index: u3) BitCount {
    return fromBytesAssumeBounded(byte_index) + bit_index;
}

pub fn toLocal(bits: BitCount) Error!usize {
    return std.math.cast(usize, bits) orelse error.IntegerOverflow;
}

pub fn floorBytes(bits: BitCount) Error!usize {
    return toLocal(bits / 8);
}

/// Quotient/remainder avoids the overflow in `(bits + 7) / 8`.
pub fn ceilBytes(bits: BitCount) Error!usize {
    return toLocal(bits / 8 + @intFromBool(bits % 8 != 0));
}

/// Bound an available bit count to a local reservoir request before narrowing.
pub fn bounded(bits: BitCount, maximum: usize) usize {
    return @intCast(@min(bits, @as(BitCount, maximum)));
}

test "bit addresses cross the 32-bit bit boundary without allocating input" {
    const vectors = [_]struct { bytes: usize, bits: u64 }{
        .{ .bytes = (1 << 29) - 1, .bits = 4294967288 },
        .{ .bytes = 1 << 29, .bits = 4294967296 },
        .{ .bytes = (1 << 29) + 1, .bits = 4294967304 },
        .{ .bytes = std.math.maxInt(u32), .bits = 34359738360 },
    };
    for (vectors) |v| {
        const bits = try fromBytes(v.bytes);
        try std.testing.expectEqual(@as(BitCount, v.bits), bits);
        try std.testing.expectEqual(bits, fromBytesAssumeBounded(v.bytes));
        try std.testing.expectEqual(v.bytes, try floorBytes(bits));
        try std.testing.expectEqual(v.bytes, try ceilBytes(bits));
        try std.testing.expectEqual(bits + 7, try position(v.bytes, 7));
    }
}

test "bit address rounding and narrowing check geometry at integer boundaries" {
    try std.testing.expectEqual(@as(usize, 0), try ceilBytes(0));
    try std.testing.expectEqual(@as(usize, 1), try floorBytes(9));
    try std.testing.expectEqual(@as(usize, 2), try ceilBytes(9));
    try std.testing.expectEqual(@as(usize, 63), bounded(std.math.maxInt(BitCount), 63));
    if (@bitSizeOf(usize) < 64) {
        try std.testing.expectEqual(std.math.maxInt(usize), max_addressable_bytes);
        try std.testing.expectError(error.IntegerOverflow, toLocal(@as(BitCount, 1) << 32));
        try std.testing.expectError(error.IntegerOverflow, floorBytes(std.math.maxInt(BitCount)));
        try std.testing.expectError(error.IntegerOverflow, ceilBytes(try fromBytes(std.math.maxInt(usize)) + 1));
    } else {
        try std.testing.expectError(error.IntegerOverflow, fromBytes(max_addressable_bytes + 1));
        try std.testing.expectEqual(max_addressable_bytes, try floorBytes(std.math.maxInt(BitCount)));
        try std.testing.expectEqual(max_addressable_bytes + 1, try ceilBytes(std.math.maxInt(BitCount)));
    }
}
