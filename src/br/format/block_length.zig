//! RFC 7932 block-length code geometry shared by decode and split encoders.
const std = @import("std");
pub const Spec = @import("../length.zig").Spec;
pub const max_encoder_length: usize = 1 << 24;

pub const Encoding = struct {
    symbol: u5,
    extra: usize,
    extra_bits: u5,
};

pub const specs = [_]Spec{
    .{ .base = 1, .extra_bits = 2 },
    .{ .base = 5, .extra_bits = 2 },
    .{ .base = 9, .extra_bits = 2 },
    .{ .base = 13, .extra_bits = 2 },
    .{ .base = 17, .extra_bits = 3 },
    .{ .base = 25, .extra_bits = 3 },
    .{ .base = 33, .extra_bits = 3 },
    .{ .base = 41, .extra_bits = 3 },
    .{ .base = 49, .extra_bits = 4 },
    .{ .base = 65, .extra_bits = 4 },
    .{ .base = 81, .extra_bits = 4 },
    .{ .base = 97, .extra_bits = 4 },
    .{ .base = 113, .extra_bits = 5 },
    .{ .base = 145, .extra_bits = 5 },
    .{ .base = 177, .extra_bits = 5 },
    .{ .base = 209, .extra_bits = 5 },
    .{ .base = 241, .extra_bits = 6 },
    .{ .base = 305, .extra_bits = 6 },
    .{ .base = 369, .extra_bits = 7 },
    .{ .base = 497, .extra_bits = 8 },
    .{ .base = 753, .extra_bits = 9 },
    .{ .base = 1265, .extra_bits = 10 },
    .{ .base = 2289, .extra_bits = 11 },
    .{ .base = 4337, .extra_bits = 12 },
    .{ .base = 8433, .extra_bits = 13 },
    .{ .base = 16625, .extra_bits = 24 },
};

pub fn encode(len: usize) ?Encoding {
    if (len == 0 or len > max_encoder_length) return null;
    for (specs, 0..) |spec, symbol| {
        const capacity = @as(usize, 1) << @intCast(spec.extra_bits);
        if (len < spec.base or len - spec.base >= capacity) continue;
        return .{ .symbol = @intCast(symbol), .extra = len - spec.base, .extra_bits = spec.extra_bits };
    }
    return null;
}

test "fixed split length format preserves RFC code endpoints and encoder limits" {
    const bases = [_]usize{ 1, 5, 9, 13, 17, 25, 33, 41, 49, 65, 81, 97, 113, 145, 177, 209, 241, 305, 369, 497, 753, 1265, 2289, 4337, 8433, 16625 };
    const extras = [_]u5{ 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 7, 8, 9, 10, 11, 12, 13, 24 };
    for (bases, extras, 0..) |base, width, symbol| {
        try std.testing.expectEqual(Spec{ .base = base, .extra_bits = width }, specs[symbol]);
        const upper = if (symbol + 1 < bases.len) bases[symbol + 1] - 1 else max_encoder_length;
        try std.testing.expectEqual(Encoding{ .symbol = @intCast(symbol), .extra = 0, .extra_bits = width }, encode(base).?);
        try std.testing.expectEqual(Encoding{ .symbol = @intCast(symbol), .extra = upper - base, .extra_bits = width }, encode(upper).?);
    }
    try std.testing.expectEqual(@as(?Encoding, null), encode(0));
    try std.testing.expectEqual(@as(?Encoding, null), encode(max_encoder_length + 1));
    // The decoder's final symbol can advertise more remaining symbols than
    // this meta-block. Its complete wire range stays separate from encoding.
    try std.testing.expect(specs[25].base + ((@as(usize, 1) << 24) - 1) > max_encoder_length);
}
