//! Wire decoding for Number_of_Sequences.
const core = @import("../../core.zig");

pub const Error = core.Error;
pub const max_encoded_len: usize = 3;

pub fn encodedLen(first: u8) usize {
    return if (first < 128) 1 else if (first < 255) 2 else 3;
}

pub fn parse(bytes: []const u8) Error!usize {
    if (bytes.len == 0) return error.TruncatedFrame;
    const required = encodedLen(bytes[0]);
    if (bytes.len < required) return error.TruncatedFrame;
    const byte0 = bytes[0];
    if (byte0 == 0) return 0;
    if (byte0 < 128) return byte0;
    if (byte0 < 255)
        return (@as(usize, byte0 - 128) << 8) + bytes[1];
    return @as(usize, bytes[1]) + (@as(usize, bytes[2]) << 8) + 0x7f00;
}

test "Zstd sequence count preserves all three wire tiers" {
    const std = @import("std");
    try std.testing.expectEqual(@as(usize, 0), try parse(&.{0}));
    try std.testing.expectEqual(@as(usize, 127), try parse(&.{127}));
    try std.testing.expectEqual(@as(usize, 256), try parse(&.{ 129, 0 }));
    try std.testing.expectEqual(@as(usize, 0x7f00), try parse(&.{ 255, 0, 0 }));
}
