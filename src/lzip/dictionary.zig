const std = @import("std");

pub const min_size: u32 = 4 * 1024;
pub const max_size: u32 = 512 * 1024 * 1024;

pub const Encoding = struct {
    code: u8,
    size: u32,
};

/// Decode lzip's one-byte dictionary-size representation.
pub fn decode(code: u8) ?u32 {
    const base_bits: u5 = @intCast(code & 0x1f);
    if (base_bits < 12 or base_bits > 29) return null;
    const base_size = @as(u32, 1) << base_bits;
    const fraction = if (base_size > min_size)
        (base_size / 16) * @as(u32, code >> 5)
    else
        0;
    const size = base_size - fraction;
    if (size < min_size or size > max_size) return null;
    return size;
}

/// Return the smallest canonical lzip dictionary representation that is at
/// least `requested_size` bytes.
pub fn encodeCeiling(requested_size: u32) ?Encoding {
    if (requested_size < min_size or requested_size > max_size) return null;

    var base_bits: u5 = 12;
    while ((@as(u32, 1) << base_bits) < requested_size) : (base_bits += 1) {}
    const base_size = @as(u32, 1) << base_bits;
    if (base_bits == 12) return .{ .code = 12, .size = min_size };

    const fraction = base_size / 16;
    var numerator: u8 = 7;
    while (numerator != 0) : (numerator -= 1) {
        const size = base_size - fraction * numerator;
        if (size >= requested_size) {
            return .{
                .code = @as(u8, base_bits) | (numerator << 5),
                .size = size,
            };
        }
    }
    return .{ .code = @as(u8, base_bits), .size = base_size };
}

test "lzip dictionary property decodes canonical and fractional sizes" {
    try std.testing.expectEqual(@as(?u32, min_size), decode(0x0c));
    try std.testing.expectEqual(@as(?u32, 320 * 1024), decode(0xd3));
    try std.testing.expectEqual(@as(?u32, max_size), decode(0x1d));
    try std.testing.expectEqual(@as(?u32, null), decode(0x0b));
    try std.testing.expectEqual(@as(?u32, null), decode(0x1e));
}

test "lzip dictionary property rounds requests upward canonically" {
    try std.testing.expectEqual(Encoding{ .code = 0x0c, .size = 4096 }, encodeCeiling(4096).?);
    try std.testing.expectEqual(Encoding{ .code = 0xed, .size = 4608 }, encodeCeiling(4097).?);
    try std.testing.expectEqual(Encoding{ .code = 0xd3, .size = 320 * 1024 }, encodeCeiling(300 * 1024).?);
    try std.testing.expectEqual(Encoding{ .code = 0xd3, .size = 320 * 1024 }, encodeCeiling(320 * 1024).?);
    try std.testing.expectEqual(Encoding{ .code = 0x1d, .size = max_size }, encodeCeiling(max_size).?);
    try std.testing.expectEqual(@as(?Encoding, null), encodeCeiling(min_size - 1));
    try std.testing.expectEqual(@as(?Encoding, null), encodeCeiling(max_size + 1));
}
