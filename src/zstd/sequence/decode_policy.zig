const std = @import("std");

pub const small_literal_limit = 4 * 1024;
pub const split_sequence_min = 1024;
pub const split_literal_min = 32 * 1024;
pub const generic_split_literal_min = 4 * 1024;
pub const raw_all_fse_sequence_min = 32;
pub const raw_all_fse_literal_min = split_literal_min;

/// The small executor specializes long matches. More than 4,096 sequences in
/// a <=128-KiB block implies less than 32 output bytes per sequence, so use the
/// grouped reader and short-match executor even when literals are sparse.
pub inline fn preferSmall(literal_bytes: usize, sequence_count: usize) bool {
    return literal_bytes <= small_literal_limit and
        sequence_count <= std.compress.zstd.block_size_max / 32;
}

/// Bulk-decode four Huffman streams when either sequence pressure or literal
/// volume is high enough to amortize the bounded split scratch.
pub inline fn preferSplit(literal_bytes: usize, sequence_count: usize) bool {
    return sequence_count >= split_sequence_min or
        literal_bytes >= split_literal_min;
}

pub inline fn preferGenericSplit(literal_bytes: usize, sequence_count: usize) bool {
    return sequence_count >= split_sequence_min or
        literal_bytes >= generic_split_literal_min;
}

/// Raw literals need no temporary decode buffer, so the packed all-FSE
/// executor amortizes at a much smaller block than the Huffman split paths.
pub inline fn preferRawAllFse(literal_bytes: usize, sequence_count: usize) bool {
    return sequence_count >= raw_all_fse_sequence_min or
        literal_bytes >= raw_all_fse_literal_min;
}

test "small sequence executor excludes dense sparse-literal blocks" {
    try std.testing.expect(preferSmall(4096, 4096));
    try std.testing.expect(preferSmall(2083, 1834));
    try std.testing.expect(!preferSmall(4096, 4097));
    try std.testing.expect(!preferSmall(0, 4097));
    try std.testing.expect(!preferSmall(2101, 6016));
    try std.testing.expect(!preferSmall(4097, 1024));
}

test "split Huffman executor covers sequence-dense and literal-dense blocks" {
    try std.testing.expect(preferSplit(0, split_sequence_min));
    try std.testing.expect(preferSplit(split_literal_min, 1));
    try std.testing.expect(!preferSplit(split_literal_min - 1, split_sequence_min - 1));
    try std.testing.expect(preferGenericSplit(generic_split_literal_min, 1));
    try std.testing.expect(!preferGenericSplit(generic_split_literal_min - 1, split_sequence_min - 1));
    try std.testing.expect(preferRawAllFse(0, raw_all_fse_sequence_min));
    try std.testing.expect(preferRawAllFse(raw_all_fse_literal_min, 1));
    try std.testing.expect(!preferRawAllFse(raw_all_fse_literal_min - 1, raw_all_fse_sequence_min - 1));
}
