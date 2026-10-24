const std = @import("std");

/// Cumulative stream quantities are independent of one caller buffer's size.
/// Preserve the existing public integer type on 64-bit targets.
pub const Counter = if (@bitSizeOf(usize) < 64) u64 else usize;
pub const Error = error{IntegerOverflow};

pub fn fromLocal(value: usize) Counter {
    return value;
}

/// Zig does not widen the child integer inside an existing optional value.
pub fn fromOptionalLocal(value: ?usize) ?Counter {
    return if (value) |local| fromLocal(local) else null;
}

pub fn add(first: Counter, second: Counter) Error!Counter {
    return std.math.add(Counter, first, second) catch error.IntegerOverflow;
}

pub fn addLocal(current: Counter, amount: usize) Error!Counter {
    return add(current, fromLocal(amount));
}

/// A failed addition does not advance the counter.
pub fn advance(current: *Counter, amount: usize) Error!void {
    current.* = try addLocal(current.*, amount);
}

/// Use only for quantities that must fit a single physical buffer or index.
/// Cumulative stream limits and pledges must retain their Counter type.
pub fn toLocal(value: Counter) Error!usize {
    return std.math.cast(usize, value) orelse error.IntegerOverflow;
}

/// Bound a cumulative quantity by a physical window before narrowing it.
pub fn bounded(value: Counter, limit: usize) usize {
    return @intCast(@min(value, fromLocal(limit)));
}

/// Convert a logical stream position to an index in a nonempty history ring.
pub fn ringIndex(position: Counter, capacity: usize) usize {
    std.debug.assert(capacity != 0);
    return @intCast(position % fromLocal(capacity));
}

test "stream count preserves native types and crosses the 32-bit byte boundary" {
    if (@bitSizeOf(usize) < 64) {
        try std.testing.expect(Counter == u64);
    } else {
        try std.testing.expect(Counter == usize);
    }
    const boundary: Counter = @as(Counter, 1) << 32;
    try std.testing.expectEqual(boundary + 17, try addLocal(boundary - 3, 20));
    try std.testing.expectEqual(@as(usize, 17), bounded(boundary + 17, 17));
    try std.testing.expectEqual(@as(usize, @intCast((boundary + 17) % 31)), ringIndex(boundary + 17, 31));
}

test "stream count overflow refuses an advance without changing state" {
    var value: Counter = std.math.maxInt(Counter);
    try std.testing.expectError(error.IntegerOverflow, advance(&value, 1));
    try std.testing.expectEqual(std.math.maxInt(Counter), value);
    try advance(&value, 0);
    try std.testing.expectEqual(std.math.maxInt(Counter), value);
    try std.testing.expectError(error.IntegerOverflow, add(value - 2, 3));
}

test "stream count narrows only after checking a physical bound" {
    try std.testing.expectEqual(@as(usize, 23), try toLocal(23));
    try std.testing.expectEqual(@as(usize, 0), bounded(std.math.maxInt(Counter), 0));
    try std.testing.expectEqual(@as(usize, 65535), bounded(std.math.maxInt(Counter), 65535));
    if (@bitSizeOf(usize) < 64) {
        try std.testing.expectError(error.IntegerOverflow, toLocal(@as(Counter, std.math.maxInt(usize)) + 1));
    }
    try std.testing.expectEqual(@as(?Counter, null), fromOptionalLocal(null));
    try std.testing.expectEqual(@as(?Counter, 23), fromOptionalLocal(23));
}
