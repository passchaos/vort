pub fn update(initial: u16, bytes: []const u8) u16 {
    var crc = initial;
    for (bytes) |byte| {
        crc ^= byte;
        for (0..8) |_| crc = if (crc & 1 != 0) (crc >> 1) ^ 0xa001 else crc >> 1;
    }
    return crc;
}

pub fn compute(bytes: []const u8) u16 {
    return update(0, bytes);
}

test "LHA CRC-16 matches the standard check vector" {
    const std = @import("std");
    try std.testing.expectEqual(@as(u16, 0xbb3d), compute("123456789"));
}
