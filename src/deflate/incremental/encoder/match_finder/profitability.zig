const std = @import("std");

pub inline fn accept(
    input: []const u8,
    pos: usize,
    length: usize,
    distance: usize,
    minimum: usize,
    maximum_distance: usize,
    min_savings_bits: usize,
) bool {
    if (length < minimum or distance == 0 or distance > maximum_distance) return false;
    const required_bits = fixedMatchBits(length, distance) + min_savings_bits;
    const literal_min_bits = length * 8;
    // Most matches are provably profitable even if every replaced fixed
    // literal uses its shorter 8-bit code. Conversely, if all 9-bit literals
    // still cannot pay the match, reject without reading their bytes.
    if (literal_min_bits >= required_bits) return true;
    if (literal_min_bits + length < required_bits) return false;
    var literal_bits = literal_min_bits;
    for (input[pos..][0..length]) |byte| literal_bits += @intFromBool(byte > 143);
    return literal_bits >= required_bits;
}

fn fixedMatchBits(length: usize, distance: usize) usize {
    const length_bits: usize = if (length <= 10) 7 else if (length <= 18) 8 else if (length <= 34) 9 else if (length <= 66) 10 else if (length <= 130) 11 else if (length <= 257) 12 else 8;
    const distance_extra: usize = if (distance <= 4) 0 else std.math.log2_int(usize, distance - 1) - 1;
    return length_bits + 5 + distance_extra;
}

test "profitability bounds equal a full literal scan" {
    var input: [258]u8 = undefined;
    const distances = [_]usize{ 1, 4, 5, 32, 257, 4096, 32768 };
    for ([_]u8{ 0, 143, 144, 255 }) |seed| {
        for (&input, 0..) |*byte, i| byte.* = if (i % 3 == 0) seed else @truncate(seed +% @as(u8, @truncate(i)));
        for (3..input.len + 1) |length| {
            for (distances) |distance| {
                for ([_]usize{ 0, 1, 8, 32 }) |savings| {
                    try std.testing.expectEqual(
                        reference(&input, length, distance, savings),
                        accept(&input, 0, length, distance, 3, 32768, savings),
                    );
                }
            }
        }
    }
}

fn reference(input: []const u8, length: usize, distance: usize, savings: usize) bool {
    if (length < 3 or distance == 0 or distance > 32768) return false;
    var literal_bits = length * 8;
    for (input[0..length]) |byte| literal_bits += @intFromBool(byte > 143);
    return literal_bits >= fixedMatchBits(length, distance) + savings;
}
