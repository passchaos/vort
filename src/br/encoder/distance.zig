const std = @import("std");
const large_distance = @import("large_distance.zig");

pub const Format = enum { standard, large_window };
pub const safe_max_distance = large_distance.safe_max_distance;

pub const Encoding = struct {
    symbol: u16,
    extra: u32 = 0,
    extra_bits: u5 = 0,
};

/// One of RFC 7932's 64 legal distance-alphabet shapes. The four-bit wire field
/// stores `ndirect_high`; the actual number of direct codes is that value
/// shifted by `npostfix`.
pub const Parameters = struct {
    npostfix: u2,
    ndirect_high: u4,

    pub fn init(npostfix: u2, ndirect_high: u4) Parameters {
        return .{ .npostfix = npostfix, .ndirect_high = ndirect_high };
    }

    pub fn ndirect(self: Parameters) u7 {
        return @as(u7, self.ndirect_high) << self.npostfix;
    }

    pub fn alphabetSize(self: Parameters) usize {
        return 16 + @as(usize, self.ndirect()) + (@as(usize, 48) << self.npostfix);
    }

    pub fn wireAlphabetSize(self: Parameters, format: Format) usize {
        const bits: usize = if (format == .standard) 24 else large_distance.wire_distance_bits;
        return 16 + @as(usize, self.ndirect()) + ((bits * 2) << self.npostfix);
    }
    pub fn activeAlphabetSize(self: Parameters, format: Format) usize {
        return if (format == .standard) self.alphabetSize() else large_distance.calculateLimit(self.npostfix, self.ndirect()).alphabet_size;
    }
    pub fn maximumDistanceForFormat(self: Parameters, format: Format) usize {
        return if (format == .standard) self.maximumDistance() else large_distance.calculateLimit(self.npostfix, self.ndirect()).max_distance;
    }

    pub fn maximumDistance(self: Parameters) usize {
        const Shift = std.math.Log2Int(usize);
        const shift: Shift = 26 + @as(Shift, self.npostfix);
        const adjustment: Shift = 2 + @as(Shift, self.npostfix);
        return @as(usize, self.ndirect()) + (@as(usize, 1) << shift) - (@as(usize, 1) << adjustment);
    }
};

/// Compatibility entry point for the encoder's established NPOSTFIX=0 calls.
/// New parameter-search code should use `encodeWithParameters`.
pub fn encode(distance: usize, ndirect: u16) ?Encoding {
    if (distance == 0 or ndirect > 120) return null;
    if (distance <= ndirect) return .{ .symbol = @intCast(15 + distance) };

    return encodeRegular(distance, 0, ndirect);
}

/// Invert RFC 7932's regular-distance formula for any legal parameter shape.
/// Distances up to NDIRECT use the direct alphabet; larger values select a
/// postfix-aware regular bucket and carry the remaining high bits as `extra`.
pub fn encodeWithParameters(distance: usize, parameters: Parameters) ?Encoding {
    if (distance == 0) return null;
    const ndirect = parameters.ndirect();
    if (distance <= ndirect) return .{ .symbol = @intCast(15 + distance) };

    const encoding = encodeRegular(distance, parameters.npostfix, ndirect) orelse return null;
    if (encoding.symbol >= parameters.alphabetSize()) return null;
    return encoding;
}

pub fn encodeWithFormat(distance: usize, parameters: Parameters, format: Format) ?Encoding {
    if (format == .standard) return encodeWithParameters(distance, parameters);
    if (distance == 0 or distance > parameters.maximumDistanceForFormat(format)) return null;
    if (distance <= parameters.ndirect()) return .{ .symbol = @intCast(15 + distance) };
    const encoded = encodeRegularWithBits(distance, parameters.npostfix, parameters.ndirect(), 29) orelse return null;
    if (encoded.symbol >= parameters.activeAlphabetSize(format)) return null;
    return encoded;
}

fn encodeRegular(distance: usize, npostfix: u2, ndirect: u16) ?Encoding {
    return encodeRegularWithBits(distance, npostfix, ndirect, 24);
}

fn encodeRegularWithBits(distance: usize, npostfix: u2, ndirect: u16, max_extra_bits: u5) ?Encoding {
    const adjusted = distance - ndirect - 1;
    const initial = std.math.add(
        usize,
        @as(usize, 1) << @intCast(@as(u3, npostfix) + 2),
        adjusted,
    ) catch return null;
    const bucket = std.math.log2_int(usize, initial) - 1;
    const postfix_mask = (@as(usize, 1) << npostfix) - 1;
    const postfix = initial & postfix_mask;
    const prefix = (initial >> bucket) & 1;
    const offset = (@as(usize, 2) + prefix) << bucket;
    const extra_bits_value = bucket - npostfix;
    if (extra_bits_value == 0 or extra_bits_value > max_extra_bits) return null;
    const hcode = (2 * (@as(usize, extra_bits_value) - 1)) + prefix;
    const symbol = @as(usize, 16) + ndirect + (hcode << npostfix) + postfix;
    if (symbol > std.math.maxInt(u16)) return null;
    return .{
        .symbol = @intCast(symbol),
        .extra = @intCast((initial - offset) >> npostfix),
        .extra_bits = @intCast(extra_bits_value),
    };
}

/// Compatibility entry point for the encoder's established NPOSTFIX=0 calls.
/// New parameter-search code should use `decodeWithParameters`.
pub fn decode(encoding: Encoding, ndirect: u16) ?usize {
    return decodeParts(encoding, 0, ndirect);
}

pub fn decodeWithParameters(encoding: Encoding, parameters: Parameters) ?usize {
    if (encoding.symbol >= parameters.alphabetSize()) return null;
    return decodeParts(encoding, parameters.npostfix, parameters.ndirect());
}

pub fn decodeWithFormat(encoding: Encoding, parameters: Parameters, format: Format) ?usize {
    return if (format == .standard) decodeWithParameters(encoding, parameters) else large_distance.decode(encoding, parameters.npostfix, parameters.ndirect());
}

fn decodeParts(encoding: Encoding, npostfix: u2, ndirect: u16) ?usize {
    if (encoding.symbol < 16) return null;
    const direct_index = encoding.symbol - 16;
    if (direct_index < ndirect) {
        if (encoding.extra_bits != 0 or encoding.extra != 0) return null;
        return @as(usize, direct_index) + 1;
    }
    const xcode = @as(usize, encoding.symbol) - ndirect - 16;
    const bits_value = 1 + (xcode >> @intCast(@as(u3, npostfix) + 1));
    if (bits_value > 24) return null;
    const bits: u5 = @intCast(bits_value);
    if (bits != encoding.extra_bits or encoding.extra >= (@as(u32, 1) << bits)) return null;
    const hcode = xcode >> npostfix;
    const postfix_mask = (@as(usize, 1) << npostfix) - 1;
    const postfix = xcode & postfix_mask;
    const base = ((@as(usize, 2) + (hcode & 1)) << bits) - 4;
    return (((base + encoding.extra) << npostfix) + postfix + ndirect + 1);
}

test {
    _ = @import("large_distance_tests.zig");
}

test "regular distance inversion covers direct-count candidates" {
    inline for (.{ 0, 3, 7, 15 }) |ndirect| {
        inline for (.{ 1, 2, 15, 16, 17, 18, 31, 32, 33, 64, 127, 128, 255, 1024, 4096, 32768 }) |distance| {
            const encoded = encode(distance, ndirect) orelse return error.TestUnexpectedResult;
            try std.testing.expectEqual(distance, decode(encoded, ndirect));
        }
    }
}

test "planned ndirect alphabet covers the complete Brotli meta-block" {
    const max_meta_block_distance = (@as(usize, 1) << 24) - 1;
    const encoding = encode(max_meta_block_distance, 15) orelse return error.TestUnexpectedResult;
    try std.testing.expect(encoding.symbol < 16 + 15 + 48);
    try std.testing.expectEqual(max_meta_block_distance, decode(encoding, 15));
}

test "distance parameters represent all legal RFC wire shapes" {
    for (0..4) |npostfix_value| {
        const npostfix: u2 = @intCast(npostfix_value);
        for (0..16) |ndirect_high_value| {
            const ndirect_high: u4 = @intCast(ndirect_high_value);
            const parameters = Parameters.init(npostfix, ndirect_high);
            try std.testing.expectEqual(
                @as(u7, ndirect_high) << npostfix,
                parameters.ndirect(),
            );
            try std.testing.expectEqual(
                16 + @as(usize, parameters.ndirect()) + (@as(usize, 48) << npostfix),
                parameters.alphabetSize(),
            );
        }
    }
}

test "general distance inversion covers every RFC bucket boundary" {
    for (0..4) |npostfix_value| {
        const npostfix: u2 = @intCast(npostfix_value);
        for (0..16) |ndirect_high_value| {
            const parameters = Parameters.init(npostfix, @intCast(ndirect_high_value));
            const ndirect = parameters.ndirect();

            if (ndirect != 0) {
                for ([_]usize{ 1, ndirect }) |distance| {
                    const encoding = encodeWithParameters(distance, parameters) orelse return error.TestUnexpectedResult;
                    try std.testing.expectEqual(@as(u16, @intCast(15 + distance)), encoding.symbol);
                    try std.testing.expectEqual(@as(u5, 0), encoding.extra_bits);
                    try std.testing.expectEqual(distance, decodeOracle(encoding, parameters));
                    try std.testing.expectEqual(distance, decodeWithParameters(encoding, parameters));
                    try std.testing.expect(encoding.symbol < parameters.alphabetSize());
                }
            }

            const regular_start = 16 + @as(usize, ndirect);
            for (regular_start..parameters.alphabetSize()) |symbol_value| {
                const xcode = symbol_value - regular_start;
                const extra_bits: u5 = @intCast(1 + (xcode >> @intCast(@as(u3, npostfix) + 1)));
                const maximum_extra = (@as(u32, 1) << extra_bits) - 1;
                for ([_]u32{ 0, maximum_extra }) |extra| {
                    const expected_encoding = Encoding{
                        .symbol = @intCast(symbol_value),
                        .extra = extra,
                        .extra_bits = extra_bits,
                    };
                    const distance = decodeOracle(expected_encoding, parameters) orelse return error.TestUnexpectedResult;
                    const actual = encodeWithParameters(distance, parameters) orelse return error.TestUnexpectedResult;
                    try std.testing.expectEqual(expected_encoding, actual);
                    try std.testing.expectEqual(distance, decodeWithParameters(actual, parameters));
                    try std.testing.expect(actual.symbol < parameters.alphabetSize());
                }
            }
        }
    }
}

test "general distance inversion covers meta-block and alphabet maxima" {
    const max_meta_block_distance = (@as(usize, 1) << 24) - 1;
    for (0..4) |npostfix_value| {
        const npostfix: u2 = @intCast(npostfix_value);
        for (0..16) |ndirect_high_value| {
            const parameters = Parameters.init(npostfix, @intCast(ndirect_high_value));
            const meta_block_encoding = encodeWithParameters(max_meta_block_distance, parameters) orelse return error.TestUnexpectedResult;
            try std.testing.expect(meta_block_encoding.symbol < parameters.alphabetSize());
            try std.testing.expectEqual(max_meta_block_distance, decodeOracle(meta_block_encoding, parameters));

            const maximum_distance = parameters.maximumDistance();
            const maximum_encoding = encodeWithParameters(maximum_distance, parameters) orelse return error.TestUnexpectedResult;
            try std.testing.expectEqual(@as(u16, @intCast(parameters.alphabetSize() - 1)), maximum_encoding.symbol);
            try std.testing.expectEqual(@as(u5, 24), maximum_encoding.extra_bits);
            try std.testing.expectEqual((@as(u32, 1) << 24) - 1, maximum_encoding.extra);
            try std.testing.expectEqual(maximum_distance, decodeOracle(maximum_encoding, parameters));
            try std.testing.expect(encodeWithParameters(maximum_distance + 1, parameters) == null);
        }
    }
}

/// Test-only decoder written directly from RFC 7932's forward formula. Keeping
/// this separate from `decodeParts` catches errors in the encoder's logarithmic
/// bucket inversion rather than merely proving that two shared helpers agree.
fn decodeOracle(encoding: Encoding, parameters: Parameters) ?usize {
    if (encoding.symbol < 16 or encoding.symbol >= parameters.alphabetSize()) return null;
    const ndirect = parameters.ndirect();
    const direct_index = encoding.symbol - 16;
    if (direct_index < ndirect) {
        if (encoding.extra_bits != 0 or encoding.extra != 0) return null;
        return @as(usize, direct_index) + 1;
    }

    const xcode = @as(usize, encoding.symbol) - ndirect - 16;
    const hcode = xcode >> parameters.npostfix;
    const lcode = xcode & ((@as(usize, 1) << parameters.npostfix) - 1);
    const extra_bits_value = 1 + (xcode >> @intCast(@as(u3, parameters.npostfix) + 1));
    if (extra_bits_value > 24 or encoding.extra_bits != extra_bits_value) return null;
    if (encoding.extra >= (@as(u32, 1) << @intCast(extra_bits_value))) return null;
    const offset = ((@as(usize, 2) + (hcode & 1)) << @intCast(extra_bits_value)) - 4;
    return ((offset + encoding.extra) << parameters.npostfix) + lcode + ndirect + 1;
}
