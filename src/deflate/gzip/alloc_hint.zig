//! A gzip ISIZE is an allocation hint until the deflate stream is validated.
//! Each output-producing Huffman token consumes at least one input bit and
//! produces at most 258 bytes. Stored data consumes eight bits per byte. Thus
//! raw bytes * 8 * 258 is conservative even when raw bytes include a trailer.
const std = @import("std");
const lz77 = @import("../../lz77.zig");

pub fn maximumDecodedLen(raw_bytes: usize) usize {
    return std.math.mul(usize, raw_bytes, 8 * lz77.max_match_len) catch std.math.maxInt(usize);
}

pub fn allows(raw_bytes: usize, claimed_size: u32) bool {
    return @as(usize, claimed_size) <= maximumDecodedLen(raw_bytes);
}

test "gzip allocation hint saturates the conservative token geometry on every host" {
    try std.testing.expectEqual(@as(usize, 0), maximumDecodedLen(0));
    try std.testing.expectEqual(@as(usize, 2064), maximumDecodedLen(1));
    try std.testing.expectEqual(std.math.maxInt(usize), maximumDecodedLen(std.math.maxInt(usize)));
    const last = std.math.maxInt(usize) / 2064;
    try std.testing.expectEqual(last * 2064, maximumDecodedLen(last));
    try std.testing.expectEqual(std.math.maxInt(usize), maximumDecodedLen(last + 1));
    try std.testing.expect(!allows(34, std.math.maxInt(u32)));
    try std.testing.expect(allows(34, 34 * 2064));
    try std.testing.expect(!allows(34, 34 * 2064 + 1));
}
