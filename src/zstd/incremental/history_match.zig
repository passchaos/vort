const std = @import("std");

pub const Match = struct {
    history_start: usize,
    block_start: usize = 0,
    len: usize,

    pub fn offset(self: Match, history_len: usize) ?usize {
        if (self.history_start > history_len) return null;
        return std.math.add(usize, history_len - self.history_start, self.block_start) catch null;
    }
};

/// Find a bounded cross-block candidate without coupling rolling-history
/// ownership to Zstd sequence encoding. This first slice deliberately considers
/// the newest occurrence of the block prefix: one window scan per completed
/// block, leaving broader hash-chain search behind this module boundary.
pub fn find(history: []const u8, block: []const u8) ?Match {
    if (history.len < 8 or block.len < 8) return null;
    const history_start = std.mem.lastIndexOf(u8, history, block[0..8]) orelse return null;
    var len: usize = 8;
    while (history_start + len < history.len and
        len < block.len and
        history[history_start + len] == block[len]) : (len += 1)
    {}
    return .{ .history_start = history_start, .len = len };
}

test "Zstd incremental history match prefers newest prefix" {
    const match = find("abcdefgh--abcdefghijk", "abcdefghijk-tail").?;
    try std.testing.expectEqual(@as(usize, 10), match.history_start);
    try std.testing.expectEqual(@as(usize, 11), match.len);
    try std.testing.expectEqual(@as(?usize, 11), match.offset(21));
}
