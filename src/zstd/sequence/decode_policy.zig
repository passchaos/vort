const std = @import("std");

pub const small_literal_limit = 4 * 1024;

/// The small executor specializes long matches. More than 4,096 sequences in
/// a <=128-KiB block implies less than 32 output bytes per sequence, so use the
/// grouped reader and short-match executor even when literals are sparse.
pub inline fn preferSmall(literal_bytes: usize, sequence_count: usize) bool {
    return literal_bytes <= small_literal_limit and
        sequence_count <= std.compress.zstd.block_size_max / 32;
}

test "small sequence executor excludes dense sparse-literal blocks" {
    try std.testing.expect(preferSmall(4096, 4096));
    try std.testing.expect(preferSmall(2083, 1834));
    try std.testing.expect(!preferSmall(4096, 4097));
    try std.testing.expect(!preferSmall(0, 4097));
    try std.testing.expect(!preferSmall(2101, 6016));
    try std.testing.expect(!preferSmall(4097, 1024));
}
