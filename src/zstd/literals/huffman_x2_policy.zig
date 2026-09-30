const std = @import("std");

pub inline fn preferSparseHighSequence(
    regenerated_size: usize,
    sequence_count: usize,
    stream_bytes: usize,
) bool {
    return regenerated_size >= 4 * 1024 and
        sequence_count >= 1536 and
        sequence_count < 2048 and
        regenerated_size >= sequence_count * 4 and
        stream_bytes * 100 <= regenerated_size * 55;
}

test "sparse high-sequence Huffman X2 selector is bounded" {
    try std.testing.expect(preferSparseHighSequence(6 * 1024, 1536, 3379));
    try std.testing.expect(preferSparseHighSequence(8 * 1024, 2047, 4096));
    try std.testing.expect(!preferSparseHighSequence(6 * 1024, 1535, 3379));
    try std.testing.expect(!preferSparseHighSequence(8 * 1024, 2048, 4096));
    try std.testing.expect(!preferSparseHighSequence(6 * 1024 - 1, 1536, 3379));
    try std.testing.expect(!preferSparseHighSequence(6 * 1024, 1536, 3380));
}
