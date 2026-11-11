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

/// Inline widening copy for non-overlapping matches up to the 258-byte
/// Deflate maximum. Avoids the compiler-rt `memcpy` call (generic length
/// dispatch plus register spills) by emitting fixed 16-byte vector moves with
/// one overlapping tail store. Caller guarantees source and destination do
/// not overlap and both spans stay inside their buffers.
pub inline fn copyWide(destination: []u8, source: []const u8, length: usize) void {
    std.debug.assert(length >= 3 and length <= 258 and length <= destination.len and length <= source.len);
    if (length < 16) {
        copy(destination, source, length);
        return;
    }
    copyWideAtLeast16(destination, source, length);
}

/// The validated wide-call boundary keeps the exact short-span fallback out
/// of production hot paths whose owner already proves at least one full word.
pub inline fn copyWideAtLeast16(destination: []u8, source: []const u8, length: usize) void {
    std.debug.assert(length >= 16 and length <= 258 and length <= destination.len and length <= source.len);
    var offset: usize = 0;
    while (offset + 16 <= length) : (offset += 16) {
        const head: [16]u8 = source[offset..][0..16].*;
        destination[offset..][0..16].* = head;
    }
    if (offset < length) {
        const tail = length - 16;
        const last: [16]u8 = source[tail..][0..16].*;
        destination[tail..][0..16].* = last;
    }
}
