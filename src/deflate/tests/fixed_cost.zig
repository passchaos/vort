const std = @import("std");
const BitWriter = @import("../../bitstream.zig").BitWriter;

const representative_distances = [_]usize{ 1, 4, 5, 32 * 1024 };

// First and last distance in every RFC 1951 distance-code range. Keeping this
// oracle independent of the production distance table catches cost-tier and
// extra-bit boundary mistakes; separate table tests cover symbol identities.
const distance_boundaries = [_]usize{
    1,    2,     3,     4,     5,     6,     7,     8,
    9,    12,    13,    16,    17,    24,    25,    32,
    33,   48,    49,    64,    65,    96,    97,    128,
    129,  192,   193,   256,   257,   384,   385,   512,
    513,  768,   769,   1024,  1025,  1536,  1537,  2048,
    2049, 3072,  3073,  4096,  4097,  6144,  6145,  8192,
    8193, 12288, 12289, 16384, 16385, 24576, 24577, 32768,
};

const representative_lengths = [_]usize{
    3, 10, 11, 66, 67, 114, 115, 130, 131, 257, 258,
};

pub fn verify(
    comptime Token: type,
    comptime fixedCost: anytype,
    comptime writeFixed: anytype,
) !void {
    const empty = [_]Token{};
    const low_literal = [_]Token{.{ .literal = 143 }};
    const high_literal = [_]Token{.{ .literal = 144 }};
    for (0..8) |prefix_bits| {
        try verifyTokens(Token, fixedCost, writeFixed, &empty, prefix_bits, false);
        try verifyTokens(Token, fixedCost, writeFixed, &empty, prefix_bits, true);
        try verifyTokens(Token, fixedCost, writeFixed, &low_literal, prefix_bits, true);
        try verifyTokens(Token, fixedCost, writeFixed, &high_literal, prefix_bits, true);
    }

    // Exhaust every legal length while crossing short, extra-bit and maximum
    // distance classes. The direct writer is authoritative for wire costs.
    for (3..259) |length| {
        for (representative_distances) |distance| {
            for (0..8) |prefix_bits| {
                try verifyCase(Token, fixedCost, writeFixed, length, distance, prefix_bits);
            }
        }
    }

    // Independently cross every distance-code boundary at the length-symbol
    // transitions most likely to expose a fixed-code width error.
    for (representative_lengths) |length| {
        for (distance_boundaries) |distance| {
            for (0..8) |prefix_bits| {
                try verifyCase(Token, fixedCost, writeFixed, length, distance, prefix_bits);
            }
        }
    }
}

fn verifyCase(
    comptime Token: type,
    comptime fixedCost: anytype,
    comptime writeFixed: anytype,
    length: usize,
    distance: usize,
    prefix_bits: usize,
) !void {
    // History validity belongs to decoder round trips; this test directly
    // measures symbol emission and deliberately needs no matching plain input.
    const tokens = [_]Token{.{ .match = .{
        .length = @intCast(length),
        .distance = @intCast(distance),
    } }};
    try verifyTokens(
        Token,
        fixedCost,
        writeFixed,
        &tokens,
        prefix_bits,
        (length + distance + prefix_bits) & 1 == 0,
    );
}

fn verifyTokens(
    comptime Token: type,
    comptime fixedCost: anytype,
    comptime writeFixed: anytype,
    tokens: []const Token,
    prefix_bits: usize,
    final: bool,
) !void {
    var writer: BitWriter = .{};
    defer writer.deinit(std.testing.allocator);
    try writer.writeBits(
        std.testing.allocator,
        0b1010_1101,
        @intCast(prefix_bits),
    );
    const before = bitPosition(writer);
    try writeFixed(std.testing.allocator, &writer, tokens, final);
    const emitted = bitPosition(writer) - before;
    try std.testing.expectEqual(
        emitted,
        fixedCost(tokens),
    );
}

fn bitPosition(writer: BitWriter) usize {
    return writer.bytes.items.len * 8 + @as(usize, writer.bit_index);
}
