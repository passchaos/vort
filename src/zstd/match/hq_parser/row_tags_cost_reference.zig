//! Exact row insertion with a compact rejection-only key index.
const std = @import("std");
const state = @import("state.zig");
pub const Tags = [state.max_beam]u8;

/// A tag only rejects unequal keys. Every tag match still compares all four
/// key fields; collisions never identify a node or change insertion order.
pub fn key(node: anytype) u8 {
    const mixed = node.repeats[0] ^ std.math.rotl(usize, node.repeats[1], 11) ^
        std.math.rotl(usize, node.repeats[2], 23) ^ @as(usize, node.literal_len);
    const product = mixed *% @as(usize, @truncate(@as(u64, 0x9e3779b185ebca87)));
    return @truncate(product >> (@bitSizeOf(usize) - 8));
}
pub fn init(row: anytype) Tags {
    std.debug.assert(row.len > 0 and row.len <= state.max_beam);
    var result: Tags = @splat(0);
    for (row, 0..) |node, index| result[index] = key(node);
    return result;
}
pub fn insert(row: anytype, tags: *Tags, candidate: @TypeOf(row[0])) bool {
    std.debug.assert(row.len > 0 and row.len <= state.max_beam);
    const tag = key(candidate);
    const old_tags: @Vector(state.max_beam, u8) = tags.*;
    const equality = old_tags == @as(@Vector(state.max_beam, u8), @splat(tag));
    var matches: u16 = @bitCast(equality);
    matches &= @as(u16, 0xffff) >> @intCast(state.max_beam - row.len);
    var replace = row.len - 1;
    while (matches != 0) {
        const slot: usize = @ctz(matches);
        matches &= matches - 1;
        const old = row[slot];
        if (old.cost != std.math.maxInt(u64) and old.literal_len == candidate.literal_len and
            old.repeats[0] == candidate.repeats[0] and old.repeats[1] == candidate.repeats[1] and
            old.repeats[2] == candidate.repeats[2])
        {
            if (!state.less(candidate, old)) return false;
            replace = slot;
            break;
        }
    }
    if (!state.less(candidate, row[replace])) return false;
    while (replace > 0 and state.less(candidate, row[replace - 1])) : (replace -= 1) {
        row[replace] = row[replace - 1];
        tags[replace] = tags[replace - 1];
    }
    row[replace] = candidate;
    tags[replace] = tag;
    return true;
}

test {
    _ = @import("row_tags_tests.zig");
}
