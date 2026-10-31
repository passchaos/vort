//! Exact non-overlapping copy kernel. The caller checks distance, source and
//! destination capacity. Head and tail stores may overlap one another, but
//! both source values are loaded first and every access stays within length.
const std = @import("std");

pub inline fn copy(destination: []u8, source: []const u8, length: usize) void {
    std.debug.assert(length >= 3 and length <= destination.len and length <= source.len);
    switch (length) {
        3...4 => pair(2, destination, source, length),
        5...8 => pair(4, destination, source, length),
        9...16 => pair(8, destination, source, length),
        17...32 => pair(16, destination, source, length),
        else => @memcpy(destination[0..length], source[0..length]),
    }
}

inline fn pair(comptime width: usize, destination: []u8, source: []const u8, length: usize) void {
    const tail = length - width;
    const first: [width]u8 = source[0..width].*;
    const last: [width]u8 = source[tail..][0..width].*;
    destination[0..width].* = first;
    destination[tail..][0..width].* = last;
}
