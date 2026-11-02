//! Visit larger literal trees first without changing tree IDs or tie order.
const std = @import("std");

pub const max_trees = 64;

/// Stable descending-total order for a bounded cluster map. Only the prefix
/// of `totals.len` entries is initialized. Equal totals retain tree-ID order.
/// The order requires 64 bytes and no allocator; exact costs still decide
/// pruning, and this estimate never rejects a candidate by itself.
pub fn byTotal(totals: []const u32) [max_trees]u8 {
    std.debug.assert(totals.len <= max_trees);
    var order: [max_trees]u8 = undefined;
    for (totals, 0..) |total, tree| {
        var index = tree;
        while (index != 0 and total > totals[order[index - 1]]) : (index -= 1)
            order[index] = order[index - 1];
        order[index] = @intCast(tree);
    }
    return order;
}
