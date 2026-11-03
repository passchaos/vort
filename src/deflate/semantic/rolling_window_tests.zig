const std = @import("std");
const rolling = @import("rolling_window.zig");
const reference = @import("rolling_window_tests/reference.zig");
const capacity = rolling.capacity;
const lookback = rolling.window;
const Window = rolling.Window;

const Guarded = struct {
    before: [17]u8 = @splat(0xa5),
    storage: [capacity]u8 = undefined,
    after: [19]u8 = @splat(0x5a),

    fn check(self: *const Guarded) !void {
        try std.testing.expectEqualSlices(u8, &@as([17]u8, @splat(0xa5)), &self.before);
        try std.testing.expectEqualSlices(u8, &@as([19]u8, @splat(0x5a)), &self.after);
    }
};

const bases = [_]usize{
    0,     1,     3,     16,    257,   258,   32509, 32510,
    32766, 32767, 32768, 32769, 65277, 65278, 65533, 65534,
    65535,
};

fn view(storage: []u8, base: usize, prefix_len: usize, output_limit: usize) Window {
    return .{
        .storage = storage,
        .base = base,
        .prefix_len = prefix_len,
        .output_limit = output_limit,
    };
}

fn compareStorage(expected: *const reference.Linear, actual: *const Guarded, base: usize) !void {
    var physical_expected: [capacity]u8 = undefined;
    expected.scatter(&physical_expected, base);
    try std.testing.expectEqualSlices(u8, &physical_expected, &actual.storage);
    try actual.check();
}

fn matchCase(base: usize, prefix_len: usize, out_pos: usize, length: usize, distance: usize) !void {
    var expected = reference.Linear.init(prefix_len, prefix_len + lookback);
    var actual: Guarded = .{};
    expected.scatter(&actual.storage, base);
    const window = view(&actual.storage, base, prefix_len, expected.output_limit);
    if (expected.copyMatch(out_pos, length, distance)) {
        try window.copyMatch(out_pos, length, distance);
    } else |err| {
        try std.testing.expectError(err, window.copyMatch(out_pos, length, distance));
    }
    // Entire physical storage includes immutable history and unused output.
    try compareStorage(&expected, &actual, base);
}

test "rolling window metadata bounds are pure and permit a full logical cycle" {
    var storage: [capacity + 7]u8 = @splat(0xbc);
    var window = view(&storage, 65535, lookback, capacity);
    try std.testing.expect(window.valid());
    try std.testing.expectEqual(@as(usize, 65535), window.physical(capacity));
    window.storage = storage[0 .. capacity - 1];
    try std.testing.expect(!window.valid());
    window.storage = &storage;
    window.base = capacity;
    try std.testing.expect(!window.valid());
    window.base = 0;
    window.prefix_len = lookback + 1;
    try std.testing.expect(!window.valid());
    window.prefix_len = 1;
    window.output_limit = 0;
    try std.testing.expect(!window.valid());
    window.output_limit = capacity + 1;
    try std.testing.expect(!window.valid());
    window.output_limit = lookback + 2;
    try std.testing.expect(!window.valid());
    window.output_limit = lookback + 1;
    try std.testing.expect(window.valid());
    window.putLiteral(1, 0x3a);
    try window.copyMatch(2, 258, 1);
    try std.testing.expectEqualSlices(u8, &@as([7]u8, @splat(0xbc)), storage[capacity..]);
}

test "rolling window every physical base supports literal pair overlapping match and exact drain" {
    var actual: Guarded = .{};
    for (&actual.storage, 0..) |*byte, position| byte.* = @truncate(position *% 11 ^ position >> 8);
    var base: usize = 0;
    while (base < capacity) : (base += 1) {
        const window = view(&actual.storage, base, 0, lookback);
        for ([_]usize{ 0, 1, 32767, 32768 }) |logical| {
            try std.testing.expectEqual(reference.physical(base, logical), window.physical(logical));
            if (logical != lookback) {
                try std.testing.expectEqual(actual.storage[reference.physical(base, logical)], window.read(logical));
            }
        }
        const first_pos = reference.physical(base, 0);
        const second_pos = reference.physical(base, 1);
        var original: [9]u8 = undefined;
        for (&original, 0..) |*byte, logical| byte.* = actual.storage[reference.physical(base, logical)];
        window.putPair(0, 0x17, 0x93);
        try std.testing.expectEqual(@as(u8, 0x17), actual.storage[first_pos]);
        try std.testing.expectEqual(@as(u8, 0x93), actual.storage[second_pos]);
        var output = [_]u8{ 0xa1, 0, 0, 0xb2 };
        window.drain(0, output[1..3]);
        try std.testing.expectEqualSlices(u8, &.{ 0xa1, 0x17, 0x93, 0xb2 }, &output);
        window.drain(lookback, output[2..2]);
        window.putLiteral(2, 0xe7);
        try window.copyMatch(3, 6, 3);
        var repeated: [11]u8 = @splat(0xca);
        window.drain(0, repeated[1..10]);
        try std.testing.expectEqualSlices(u8, &.{ 0xca, 0x17, 0x93, 0xe7, 0x17, 0x93, 0xe7, 0x17, 0x93, 0xe7, 0xca }, &repeated);
        for (original, 0..) |byte, logical| actual.storage[reference.physical(base, logical)] = byte;
        const last_pos = reference.physical(base, lookback - 1);
        const last_old = actual.storage[last_pos];
        window.putLiteral(lookback - 1, 0x6b);
        try std.testing.expectEqual(@as(u8, 0x6b), window.read(lookback - 1));
        actual.storage[last_pos] = last_old;
    }
    try actual.check();
}

test "rolling window checked matches agree with an independent linear byte walker" {
    for (bases) |base| {
        for ([_]usize{ 0, 1, lookback }) |prefix_len| {
            const out_pos = prefix_len + if (prefix_len == lookback) @as(usize, 17) else 258;
            for ([_]usize{ 1, 2, 3, 4, 16, 258, lookback }) |distance| {
                for ([_]usize{ 0, 1, 2, 3, 7, 8, 16, 31, 32, 33, 257, 258, 513 }) |length| {
                    try matchCase(base, prefix_len, out_pos, length, distance);
                }
            }
        }
    }
    // A complete 32 KiB append exactly fills the logical free region.
    for ([_]usize{ 0, 1, 32767, 32768, 65535 }) |base| {
        for ([_]usize{ 1, 2, 3, 4, 16, 258, lookback }) |distance| {
            try matchCase(base, lookback, lookback, lookback, distance);
        }
    }
}

test "rolling window error priority and zero length preserve every byte" {
    var expected = reference.Linear.init(1, lookback + 1);
    var actual: Guarded = .{};
    expected.scatter(&actual.storage, 65535);
    const window = view(&actual.storage, 65535, 1, lookback + 1);
    const Case = struct { out_pos: usize, length: usize, distance: usize, err: rolling.Error };
    for ([_]Case{
        .{ .out_pos = 0, .length = 0, .distance = 0, .err = error.InvalidMatch },
        .{ .out_pos = 0, .length = 1, .distance = 1, .err = error.InvalidMatch },
        .{ .out_pos = 1, .length = 0, .distance = 2, .err = error.InvalidMatch },
        .{ .out_pos = capacity, .length = 1, .distance = lookback + 1, .err = error.InvalidMatch },
        .{ .out_pos = std.math.maxInt(usize), .length = std.math.maxInt(usize), .distance = 0, .err = error.InvalidMatch },
        .{ .out_pos = 1, .length = std.math.maxInt(usize), .distance = 1, .err = error.OutputTooSmall },
        .{ .out_pos = std.math.maxInt(usize), .length = 0, .distance = 1, .err = error.OutputTooSmall },
        .{ .out_pos = lookback + 2, .length = 0, .distance = 1, .err = error.OutputTooSmall },
        .{ .out_pos = lookback + 1, .length = 1, .distance = 1, .err = error.OutputTooSmall },
    }) |case| {
        try std.testing.expectError(case.err, window.copyMatch(case.out_pos, case.length, case.distance));
        try compareStorage(&expected, &actual, window.base);
    }
    try window.copyMatch(1, 0, 1);
    try window.copyMatch(window.output_limit, 0, lookback);
    try compareStorage(&expected, &actual, window.base);
    const with_prefix = view(&actual.storage, window.base, lookback, capacity);
    try std.testing.expectError(error.OutputTooSmall, with_prefix.copyMatch(1, 1, 1));
    try std.testing.expectError(error.OutputTooSmall, with_prefix.copyMatch(1, 0, 1));
    try compareStorage(&expected, &actual, window.base);
}

test "rolling window mixed generative token sequences never change prefix or guard" {
    for (bases) |base| {
        for ([_]usize{ 0, 1, lookback }) |prefix_len| {
            var expected = reference.Linear.init(prefix_len, prefix_len + lookback);
            var actual: Guarded = .{};
            expected.scatter(&actual.storage, base);
            const window = view(&actual.storage, base, prefix_len, expected.output_limit);
            var cursor = prefix_len;
            var random: u32 = @truncate(base + prefix_len + 1);
            var token: usize = 0;
            while (cursor < window.output_limit and token < 512) : (token += 1) {
                random = random *% 1664525 +% 1013904223;
                const remaining = window.output_limit - cursor;
                if (cursor == 0 or token % 5 == 0) {
                    const value: u8 = @truncate(random >> 7);
                    window.putLiteral(cursor, value);
                    expected.putLiteral(cursor, value);
                    cursor += 1;
                } else if (token % 7 == 0 and remaining >= 2) {
                    const first: u8 = @truncate(random);
                    const second: u8 = @truncate(random >> 16);
                    window.putPair(cursor, first, second);
                    expected.putPair(cursor, first, second);
                    cursor += 2;
                } else {
                    const distance = 1 + random % @as(u32, @intCast(@min(lookback, cursor)));
                    const length = @min(remaining, 1 + (random >> 16) % 258);
                    try window.copyMatch(cursor, length, distance);
                    try expected.copyMatch(cursor, length, distance);
                    cursor += length;
                }
            }
            try compareStorage(&expected, &actual, base);
            var output: [lookback + 2]u8 = @splat(0x6d);
            window.drain(prefix_len, output[1 .. 1 + cursor - prefix_len]);
            try std.testing.expectEqualSlices(u8, expected.bytes[prefix_len..cursor], output[1 .. 1 + cursor - prefix_len]);
            try std.testing.expectEqual(@as(u8, 0x6d), output[0]);
            try std.testing.expectEqual(@as(u8, 0x6d), output[1 + cursor - prefix_len]);
        }
    }
}

test "rolling window drain can copy an exact full cycle without touching guards" {
    var expected = reference.Linear.init(lookback, capacity);
    var actual: Guarded = .{};
    for (bases) |base| {
        expected.scatter(&actual.storage, base);
        const window = view(&actual.storage, base, lookback, capacity);
        var output: [capacity + 2]u8 = @splat(0xdd);
        window.drain(0, output[1 .. capacity + 1]);
        try std.testing.expectEqualSlices(u8, &expected.bytes, output[1 .. capacity + 1]);
        try std.testing.expectEqual(@as(u8, 0xdd), output[0]);
        try std.testing.expectEqual(@as(u8, 0xdd), output[capacity + 1]);
        window.drain(capacity, output[0..0]);
        try compareStorage(&expected, &actual, base);
    }
}

test "rolling window normalization preserves wrapped source and changes only compact destination" {
    var initial = reference.Linear.init(lookback, capacity);
    var actual: Guarded = .{};
    for (bases) |base| {
        for ([_]usize{ 0, 1, 2, 16, 258, lookback }) |len| {
            for ([_]usize{ 0, 1, 32767, 32768, 65535 }) |requested_start| {
                const start = @min(requested_start, capacity - len);
                initial.scatter(&actual.storage, base);
                var expected_storage = actual.storage;
                for (0..len) |offset| expected_storage[offset] = initial.bytes[start + offset];
                const window = view(&actual.storage, base, lookback, capacity);
                window.normalizeTail(start, len);
                try std.testing.expectEqualSlices(u8, &expected_storage, &actual.storage);
                try actual.check();
                try std.testing.expectEqual(base, window.base);
                try std.testing.expectEqual(lookback, window.prefix_len);
                try std.testing.expectEqual(capacity, window.output_limit);
            }
        }
    }
}

test "rolling window every physical start normalizes a tiny cyclic tail" {
    var actual: Guarded = .{};
    for (&actual.storage, 0..) |*byte, position| byte.* = @truncate(position *% 17 ^ position >> 9);
    var base: usize = 0;
    while (base < capacity) : (base += 1) {
        const window = view(&actual.storage, base, 0, lookback);
        const first = actual.storage[base];
        const second = actual.storage[if (base + 1 == capacity) 0 else base + 1];
        const old_first = actual.storage[0];
        const old_second = actual.storage[1];
        const guard = actual.storage[2];
        window.normalizeTail(0, 2);
        try std.testing.expectEqualSlices(u8, &.{ first, second }, actual.storage[0..2]);
        try std.testing.expectEqual(guard, actual.storage[2]);
        actual.storage[0] = old_first;
        actual.storage[1] = old_second;
    }
    try actual.check();
}

fn comptimeContract() bool {
    @setEvalBranchQuota(200000);
    var storage: [capacity + 1]u8 = @splat(0xcd);
    storage[65535] = 3;
    storage[0..3].* = .{ 7, 11, 13 };
    const window = view(&storage, 65535, 4, 13);
    if (!window.valid()) return false;
    if (window.copyMatch(0, 0, 0)) return false else |err| {
        if (err != error.InvalidMatch) return false;
    }
    if (window.copyMatch(4, 10, 1)) return false else |err| {
        if (err != error.OutputTooSmall) return false;
    }
    window.copyMatch(4, 0, 4) catch return false;
    window.putPair(4, 19, 23);
    window.putLiteral(6, 29);
    window.copyMatch(7, 6, 3) catch return false;
    var output: [9]u8 = undefined;
    window.drain(4, &output);
    if (!std.mem.eql(u8, &.{ 19, 23, 29, 19, 23, 29, 19, 23, 29 }, &output)) return false;
    if (storage[65535] != 3 or storage[0] != 7 or storage[1] != 11 or storage[2] != 13) return false;
    window.normalizeTail(4, 9);
    if (!std.mem.eql(u8, &output, storage[0..9]) or storage[capacity] != 0xcd) return false;
    // Low source would be destroyed if the wrapped high source moved first.
    storage[65532..capacity].* = .{ 1, 2, 3, 4 };
    storage[0..4].* = .{ 5, 6, 7, 8 };
    const wrapped = view(&storage, 65532, 0, 8);
    wrapped.normalizeTail(0, 8);
    return std.mem.eql(u8, &.{ 1, 2, 3, 4, 5, 6, 7, 8 }, storage[0..8]);
}

test "rolling window complete copy drain and wrapped normalization contract works at comptime" {
    const result = comptime comptimeContract();
    try std.testing.expect(result);
}
