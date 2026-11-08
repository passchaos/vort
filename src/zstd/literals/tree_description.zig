//! Self-delimiting Huffman-tree description geometry.
pub const max_len: usize = 128;

pub fn encodedLenFromFirst(first: u8) usize {
    const body_len: usize = if (first < 128)
        first
    else
        (@as(usize, first - 127) + 1) / 2;
    return 1 + body_len;
}

pub fn completeLen(payload: []const u8) ?usize {
    if (payload.len == 0) return null;
    const len = encodedLenFromFirst(payload[0]);
    if (len > max_len or len > payload.len) return null;
    return len;
}

test "Zstd tree description lengths cover FSE and direct weights" {
    try @import("std").testing.expectEqual(@as(usize, 1), encodedLenFromFirst(0));
    try @import("std").testing.expectEqual(@as(usize, 128), encodedLenFromFirst(127));
    try @import("std").testing.expectEqual(@as(usize, 2), encodedLenFromFirst(128));
    try @import("std").testing.expectEqual(@as(usize, 65), encodedLenFromFirst(255));
}
