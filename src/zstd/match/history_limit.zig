//! The encoder's compact coordinates reserve u32.max as an invalid position.
//! Keep a complete maximum-size block beyond every accepted prefix. A frame's
//! larger advertised window remains a wire-format property, not a promise of
//! matching beyond these local coordinates.
const std = @import("std");

pub const max_block_len: usize = std.compress.zstd.block_size_max;
pub const max_coordinate: usize = @intCast(@min(std.math.maxInt(usize), std.math.maxInt(u32) - 1));
pub const max_history_len: usize = max_coordinate - max_block_len;
pub const Error = error{ InvalidBlockPlan, IntegerOverflow };

pub fn validate(window_len: usize, prefix_len: usize, block_len: usize) Error!usize {
    if (window_len == 0 or window_len > max_history_len or prefix_len > window_len or block_len > max_block_len)
        return error.InvalidBlockPlan;
    const total = std.math.add(usize, prefix_len, block_len) catch return error.IntegerOverflow;
    if (total > max_coordinate) return error.InvalidBlockPlan;
    return total;
}

test "Zstd history limit reserves a full block and the compact invalid coordinate" {
    try std.testing.expectEqual(@as(usize, 4_294_836_222), max_history_len);
    try std.testing.expectEqual(max_coordinate, try validate(max_history_len, max_history_len, max_block_len));
    try std.testing.expectError(error.InvalidBlockPlan, validate(max_history_len + 1, 0, 1));
    try std.testing.expectError(error.InvalidBlockPlan, validate(1024, 1025, 1));
    try std.testing.expectError(error.InvalidBlockPlan, validate(1024, 0, max_block_len + 1));
}
