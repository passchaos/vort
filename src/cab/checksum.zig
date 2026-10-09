const std = @import("std");

/// Microsoft CAB longitudinal XOR checksum. Complete words are little-endian;
/// the final one to three bytes are reversed into the low-order word bytes.
pub fn compute(bytes: []const u8) u32 {
    var value: u32 = 0;
    var offset: usize = 0;
    while (bytes.len - offset >= 4) : (offset += 4)
        value ^= std.mem.readInt(u32, bytes[offset..][0..4], .little);

    const remainder = bytes.len - offset;
    var tail: u32 = 0;
    for (bytes[offset..], 0..) |byte, index|
        tail |= @as(u32, byte) << @intCast((remainder - 1 - index) * 8);
    return value ^ tail;
}

test "CAB checksum handles words and reversed remainder bytes" {
    try std.testing.expectEqual(@as(u32, 0x0403_0201), compute(&.{ 1, 2, 3, 4 }));
    try std.testing.expectEqual(@as(u32, 0x0001_0203), compute(&.{ 1, 2, 3 }));
    try std.testing.expectEqual(@as(u32, 0x0000_0102), compute(&.{ 1, 2 }));
    try std.testing.expectEqual(@as(u32, 1), compute(&.{1}));
}
