const std = @import("std");

pub const bits: usize = 15;
pub const size: usize = 1 << bits;

pub inline fn block(bytes: []const u8, pos: usize, anchor_len: usize) usize {
    if (anchor_len == 4) {
        const word = std.mem.readInt(u32, bytes[pos..][0..4], .little);
        return (word *% 2654435761) >> (32 - bits);
    }
    const value: usize = (@as(usize, bytes[pos]) << 16) |
        (@as(usize, bytes[pos + 1]) << 8) | bytes[pos + 2];
    return ((value *% 2654435761) >> 16) & (size - 1);
}

pub inline fn joined(history: []const u8, current: []const u8, history_pos: usize, anchor_len: usize) usize {
    var bytes: [4]u8 = undefined;
    for (0..anchor_len) |i| {
        const index = history_pos + i;
        bytes[i] = if (index < history.len) history[index] else current[index - history.len];
    }
    return block(&bytes, 0, anchor_len);
}

test "block and joined hashes agree across boundary layouts" {
    const history = "abcde";
    const current = "fghij";
    const combined = history ++ current;
    for (0..history.len) |pos| {
        if (pos + 4 <= combined.len)
            try std.testing.expectEqual(block(combined, pos, 4), joined(history, current, pos, 4));
    }
}
