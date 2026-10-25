//! Deflate64's complete length and distance symbols. These classifiers are
//! shared by all block representations so entropy choice cannot change tokens.
const std = @import("std");
const matching = @import("stream_match.zig");

pub const Extra = struct { symbol: u16, bits: u5, value: u16 };

pub fn lengthCode(length: usize) Extra {
    std.debug.assert(length >= 3 and length <= matching.max_match_len);
    if (length > 258) return .{ .symbol = 285, .bits = 16, .value = @intCast(length - 3) };
    if (length <= 10) return .{ .symbol = @intCast(length + 254), .bits = 0, .value = 0 };
    const bits: u5 = @intCast(std.math.log2_int(usize, length - 3) - 2);
    const span: usize = @as(usize, 1) << @intCast(bits);
    const base = (@as(usize, 1) << @intCast(@as(u8, bits) + 2)) + 3;
    const offset = length - base;
    return .{ .symbol = @intCast(261 + @as(usize, bits) * 4 + offset / span), .bits = bits, .value = @intCast(offset & (span - 1)) };
}

pub fn distanceCode(distance: usize) Extra {
    std.debug.assert(distance >= 1 and distance <= matching.window_len);
    if (distance <= 4) return .{ .symbol = @intCast(distance - 1), .bits = 0, .value = 0 };
    const bits: u5 = @intCast(std.math.log2_int(usize, distance - 1) - 1);
    const span: usize = @as(usize, 1) << @intCast(bits);
    const base = (@as(usize, 1) << @intCast(@as(u8, bits) + 1)) + 1;
    const offset = distance - base;
    return .{ .symbol = @intCast(2 + @as(usize, bits) * 2 + offset / span), .bits = bits, .value = @intCast(offset & (span - 1)) };
}
