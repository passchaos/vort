const std = @import("std");
const serialized_dictionary = @import("serialized_dictionary.zig");

pub const max_steps: u8 = 4;
pub const max_candidates_per_step =
    serialized_dictionary.max_word_len - serialized_dictionary.min_word_len + 1;

pub const NeighborSet = struct {
    items: [max_candidates_per_step][32]u16 = undefined,
    len: usize = 0,
};

pub fn initialCaps(
    min_word_len: u5,
    max_word_len: u5,
    max_words_per_length: u16,
) [32]u16 {
    std.debug.assert(min_word_len >= serialized_dictionary.min_word_len);
    std.debug.assert(max_word_len <= serialized_dictionary.max_word_len);
    std.debug.assert(min_word_len <= max_word_len);
    std.debug.assert(max_words_per_length >= 2);
    const cap = floorPowerOfTwo(max_words_per_length);
    var result: [32]u16 = @splat(0);
    for (min_word_len..max_word_len + 1) |word_len|
        result[word_len] = cap;
    return result;
}

pub fn neighbors(
    current: *const [32]u16,
    min_word_len: u5,
    max_word_len: u5,
) NeighborSet {
    var result: NeighborSet = .{};
    for (min_word_len..max_word_len + 1) |word_len| {
        if (current[word_len] <= 2) continue;
        result.items[result.len] = current.*;
        result.items[result.len][word_len] /= 2;
        result.len += 1;
    }
    return result;
}

fn floorPowerOfTwo(value: u16) u16 {
    return @as(u16, 1) << @intCast(std.math.log2_int(u16, value));
}

test "serialized dictionary word pruner generates deterministic iterative neighbors" {
    const initial = initialCaps(4, 6, 8);
    try std.testing.expectEqual(@as(u16, 8), initial[4]);
    try std.testing.expectEqual(@as(u16, 8), initial[5]);
    try std.testing.expectEqual(@as(u16, 8), initial[6]);

    const first = neighbors(&initial, 4, 6);
    try std.testing.expectEqual(@as(usize, 3), first.len);
    try std.testing.expectEqual(@as(u16, 4), first.items[0][4]);
    try std.testing.expectEqual(@as(u16, 8), first.items[0][5]);
    try std.testing.expectEqual(@as(u16, 4), first.items[1][5]);
    try std.testing.expectEqual(@as(u16, 8), first.items[1][6]);

    const second = neighbors(&first.items[1], 4, 6);
    try std.testing.expectEqual(@as(usize, 3), second.len);
    try std.testing.expectEqual(@as(u16, 4), second.items[0][4]);
    try std.testing.expectEqual(@as(u16, 4), second.items[0][5]);
    try std.testing.expectEqual(@as(u16, 2), second.items[1][5]);
    try std.testing.expectEqual(@as(u16, 4), second.items[2][5]);
    try std.testing.expectEqual(@as(u16, 4), second.items[2][6]);

    const rounded = initialCaps(4, 4, 7);
    try std.testing.expectEqual(@as(u16, 4), rounded[4]);
}
