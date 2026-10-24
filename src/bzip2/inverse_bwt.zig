const std = @import("std");
const core = @import("../core.zig");
pub const Error = core.Error || error{InvalidBzip2Stream};

/// Build the inverse permutation in caller-owned storage. Links use u32 because
/// Bzip2's largest transformed block contains at most 900,000 bytes.
pub fn prepare(block: []const u8, original_pointer: u32, links: []u32) Error!usize {
    if (block.len == 0 or original_pointer >= block.len or links.len != block.len or block.len > 900_000)
        return error.InvalidBzip2Stream;
    var cumulative: [257]usize = @splat(0);
    for (block) |byte| cumulative[@as(usize, byte) + 1] += 1;
    for (1..cumulative.len) |index| cumulative[index] += cumulative[index - 1];
    var positions = cumulative;
    for (block, 0..) |byte, index| {
        links[positions[byte]] = @intCast(index);
        positions[byte] += 1;
    }
    return links[original_pointer];
}

test "Bzip2 inverse BWT rejects invalid origin and storage before touching links" {
    var links: [1]u32 = .{99};
    try std.testing.expectError(error.InvalidBzip2Stream, prepare("a", 1, &links));
    try std.testing.expectEqual(@as(u32, 99), links[0]);
    try std.testing.expectError(error.InvalidBzip2Stream, prepare("ab", 0, &links));
    try std.testing.expectError(error.InvalidBzip2Stream, prepare("", 0, &.{}));
}

test "Bzip2 inverse BWT permits shorter repeated permutation cycles" {
    var links: [3]u32 = undefined;
    const position = try prepare("aaa", 1, &links);
    try std.testing.expectEqual(@as(usize, 1), position);
    try std.testing.expectEqual(@as(u32, 1), links[position]);
}
