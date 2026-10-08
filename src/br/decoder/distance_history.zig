const std = @import("std");
const core = @import("../../core.zig");

/// Write the decoded short distance separately from the error result. This
/// avoids a wider error-union return in each inlined decoder caller.
pub noinline fn resolveShortInto(
    symbol: u16,
    last_distances: *const [4]usize,
    distance: *usize,
) core.Error!void {
    if (symbol >= 16) return error.InvalidHuffmanCode;
    if (symbol <= 3) {
        distance.* = last_distances[3 - symbol];
        return;
    }

    const newest = symbol < 10;
    const delta_index = symbol - @as(u16, if (newest) 4 else 10);
    const packed_deltas: u24 = 0x605142;
    const encoded_delta: u4 = @truncate(packed_deltas >> @intCast(delta_index * 4));
    const delta: i8 = @as(i8, @intCast(encoded_delta)) - 3;
    distance.* = try withDelta(last_distances[if (newest) 3 else 2], delta);
}

pub fn withDelta(base: usize, delta: i8) core.Error!usize {
    if (delta < 0) {
        const magnitude: usize = @intCast(-delta);
        if (base <= magnitude) return error.InvalidMatch;
        return base - magnitude;
    }
    return std.math.add(usize, base, @intCast(delta)) catch return error.IntegerOverflow;
}

pub inline fn push(last_distances: *[4]usize, distance: usize) void {
    last_distances[0] = last_distances[1];
    last_distances[1] = last_distances[2];
    last_distances[2] = last_distances[3];
    last_distances[3] = distance;
}

test "Brotli distance history resolves short symbols and pushes recent values" {
    const initial = [_]usize{ 16, 15, 11, 4 };
    const expected = [_]usize{ 4, 11, 15, 16, 3, 5, 2, 6, 1, 7, 10, 12, 9, 13, 8, 14 };
    for (expected, 0..) |want, symbol| {
        var actual: usize = undefined;
        try resolveShortInto(@intCast(symbol), &initial, &actual);
        try std.testing.expectEqual(want, actual);
    }

    var recent = initial;
    push(&recent, 3);
    try std.testing.expectEqualSlices(usize, &.{ 15, 11, 4, 3 }, &recent);

    var invalid: usize = undefined;
    try std.testing.expectError(error.InvalidHuffmanCode, resolveShortInto(16, &initial, &invalid));
    try std.testing.expectError(error.InvalidMatch, withDelta(1, -1));
    try std.testing.expectError(error.IntegerOverflow, withDelta(std.math.maxInt(usize), 1));
}
