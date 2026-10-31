//! Immutable23-bit match evidence in exactly three little-endian bytes.
const std = @import("std");
const lz77 = @import("../../lz77.zig");
pub const Record = [3]u8;

pub fn pack(length: u16, distance: u16) Record {
    std.debug.assert(length >= 3 and length <= 258);
    std.debug.assert(distance >= 1 and distance <= 32768);
    const word = (@as(u32, length - 3) << 15) | (distance - 1);
    return .{ @truncate(word), @truncate(word >> 8), @truncate(word >> 16) };
}

pub fn unpack(bytes: Record) lz77.Token.Match {
    const word = @as(u32, bytes[0]) | (@as(u32, bytes[1]) << 8) | (@as(u32, bytes[2]) << 16);
    return .{ .length = @intCast((word >> 15) + 3), .distance = @intCast((word & 32767) + 1) };
}
