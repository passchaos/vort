//! Window identity and bounded non-HQ matching policy are separate contracts.
//! A Large Window header never asks the fragment/LZ matcher to allocate the
//! advertised window; ratio's block-local long-distance search remains free
//! to inspect the actual input block within that advertised distance.
const std = @import("std");
const distance = @import("distance.zig");

pub const Error = error{InvalidBlockPlan};
pub const fragment_max_distance: usize = 65520;
pub const non_hq_history_limit: usize = 65535;

pub fn format(large_window: bool) distance.Format {
    return if (large_window) .large_window else .standard;
}

pub fn validate(bits: u5, large_window: bool) Error!void {
    if (bits < 10 or bits > (if (large_window) @as(u5, 30) else 24))
        return error.InvalidBlockPlan;
}

pub fn prefixBitLen(bits: u5, large_window: bool) Error!usize {
    try validate(bits, large_window);
    if (large_window) return 14;
    return switch (bits) {
        16 => 1,
        18...24 => 4,
        else => 7,
    };
}

pub fn advertisedDistance(bits: u5, large_window: bool) Error!usize {
    try validate(bits, large_window);
    return (@as(usize, 1) << bits) - 16;
}

pub fn fragmentDistance(bits: u5, large_window: bool) Error!usize {
    const advertised = try advertisedDistance(bits, large_window);
    return if (large_window) @min(advertised, fragment_max_distance) else advertised;
}

pub fn retainedHistory(bits: u5, large_window: bool) Error!usize {
    const advertised = try advertisedDistance(bits, large_window);
    return if (large_window) @min(advertised, non_hq_history_limit) else advertised;
}

pub fn write(allocator: std.mem.Allocator, writer: anytype, bits: u5, large_window: bool) !void {
    try validate(bits, large_window);
    if (large_window) {
        try writer.writeBits(allocator, 1, 1);
        try writer.writeBits(allocator, 0, 3);
        try writer.writeBits(allocator, 1, 3);
        try writer.writeBits(allocator, 0, 1);
        try writer.writeBits(allocator, bits, 6);
        return;
    }
    switch (bits) {
        16 => try writer.writeBits(allocator, 0, 1),
        18...24 => {
            try writer.writeBits(allocator, 1, 1);
            try writer.writeBits(allocator, @as(u64, bits - 17), 3);
        },
        17 => {
            try writer.writeBits(allocator, 1, 1);
            try writer.writeBits(allocator, 0, 3);
            try writer.writeBits(allocator, 0, 3);
        },
        else => {
            try writer.writeBits(allocator, 1, 1);
            try writer.writeBits(allocator, 0, 3);
            try writer.writeBits(allocator, @as(u64, bits - 8), 3);
        },
    }
}

test "Br general large window distinguishes advertised distance from bounded match history" {
    for (10..31) |width| {
        const bits: u5 = @intCast(width);
        try std.testing.expectEqual(@as(usize, 14), try prefixBitLen(bits, true));
        const advertised = (@as(usize, 1) << bits) - 16;
        try std.testing.expectEqual(@min(advertised, fragment_max_distance), try fragmentDistance(bits, true));
        try std.testing.expectEqual(@min(advertised, non_hq_history_limit), try retainedHistory(bits, true));
        if (bits <= 24) try std.testing.expectEqual(advertised, try retainedHistory(bits, false));
    }
    for ([_]u5{ 0, 9, 31 }) |bits|
        try std.testing.expectError(error.InvalidBlockPlan, prefixBitLen(bits, true));
    try std.testing.expectError(error.InvalidBlockPlan, prefixBitLen(25, false));
}
