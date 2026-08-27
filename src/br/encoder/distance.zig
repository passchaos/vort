const std = @import("std");

pub const Encoding = struct {
    symbol: u16,
    extra: u32 = 0,
    extra_bits: u5 = 0,
};

/// Invert RFC 7932's regular-distance formula for NPOSTFIX=0. Distances up to
/// `ndirect` use the compact direct alphabet; larger values choose one of the
/// paired regular buckets and carry the remaining low bits as `extra`.
pub fn encode(distance: usize, ndirect: u16) ?Encoding {
    if (distance == 0 or ndirect > 120) return null;
    if (distance <= ndirect) return .{ .symbol = @intCast(15 + distance) };

    const adjusted = distance - ndirect - 1;
    var extra_bits: u5 = 1;
    while (extra_bits <= 24) : (extra_bits += 1) {
        const width = @as(usize, 1) << extra_bits;
        for (0..2) |parity| {
            const base = (@as(usize, 2) + parity) * width - 4;
            if (adjusted < base or adjusted - base >= width) continue;
            const hcode = ((@as(usize, extra_bits) - 1) << 1) | parity;
            const symbol = @as(usize, 16) + ndirect + hcode;
            if (symbol > std.math.maxInt(u16)) return null;
            return .{
                .symbol = @intCast(symbol),
                .extra = @intCast(adjusted - base),
                .extra_bits = extra_bits,
            };
        }
    }
    return null;
}

pub fn decode(encoding: Encoding, ndirect: u16) ?usize {
    if (encoding.symbol < 16) return null;
    const direct_index = encoding.symbol - 16;
    if (direct_index < ndirect) return @as(usize, direct_index) + 1;
    const xcode = @as(usize, encoding.symbol) - ndirect - 16;
    const bits: u5 = @intCast(1 + (xcode >> 1));
    if (bits != encoding.extra_bits or encoding.extra >= (@as(u32, 1) << bits)) return null;
    const base = ((@as(usize, 2) + (xcode & 1)) << bits) - 4;
    return ndirect + base + encoding.extra + 1;
}

test "regular distance inversion covers window boundaries" {
    inline for (.{ 1, 2, 15, 16, 17, 18, 31, 32, 33, 64, 127, 128, 255, 1024, 4096, 32768 }) |distance| {
        const encoded = encode(distance, 15) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(distance, decode(encoded, 15));
    }
}

test "planned ndirect alphabet covers the complete Brotli meta-block" {
    const max_meta_block_distance = (@as(usize, 1) << 24) - 1;
    const encoding = encode(max_meta_block_distance, 15) orelse return error.TestUnexpectedResult;
    try std.testing.expect(encoding.symbol < 16 + 15 + 48);
    try std.testing.expectEqual(max_meta_block_distance, decode(encoding, 15));
}
