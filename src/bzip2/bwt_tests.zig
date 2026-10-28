const std = @import("std");
const full = @import("test_support/bwt_full_doubling.zig");
const bwt = @import("bwt.zig");
const a = std.testing.allocator;

fn inverse(input: []const u8, transformed: anytype) !void {
    try std.testing.expectEqual(input.len, transformed.bytes.len);
    try std.testing.expect(transformed.original_pointer < input.len);
    var frequencies: [256]usize = @splat(0);
    for (transformed.bytes) |byte| frequencies[byte] += 1;
    var starts: [256]usize = undefined;
    var total: usize = 0;
    for (&starts, frequencies) |*start, count| {
        start.* = total;
        total += count;
    }
    var occurrences: [256]usize = @splat(0);
    const last_to_first = try a.alloc(usize, input.len);
    defer a.free(last_to_first);
    for (transformed.bytes, 0..) |byte, row| {
        last_to_first[row] = starts[byte] + occurrences[byte];
        occurrences[byte] += 1;
    }
    // Independent LF inverse: recover bytes backwards using occurrence ranks.
    var row: usize = transformed.original_pointer;
    var remaining = input.len;
    while (remaining > 0) {
        remaining -= 1;
        try std.testing.expectEqual(input[remaining], transformed.bytes[row]);
        row = last_to_first[row];
    }
}

fn rotationLess(input: []const u8, left: usize, right: usize) bool {
    for (0..input.len) |offset| {
        const l = input[(left + offset) % input.len];
        const r = input[(right + offset) % input.len];
        if (l != r) return l < r;
    }
    // Independent stable index tie-break; the production algorithm has its own
    // exact periodic tie order, which the frozen doubling oracle checks.
    return left < right;
}

fn naive(input: []const u8, transformed: anytype) !void {
    const order = try a.alloc(usize, input.len);
    defer a.free(order);
    for (order, 0..) |*start, index| start.* = index;
    for (1..order.len) |index| {
        const candidate = order[index];
        var slot = index;
        while (slot > 0 and rotationLess(input, candidate, order[slot - 1])) : (slot -= 1)
            order[slot] = order[slot - 1];
        order[slot] = candidate;
    }
    var unique = true;
    var original: usize = 0;
    for (order, 0..) |start, row| {
        try std.testing.expectEqual(input[(start + input.len - 1) % input.len], transformed.bytes[row]);
        if (start == 0) original = row;
        if (row == 0) continue;
        var same = true;
        for (0..input.len) |offset| {
            if (input[(start + offset) % input.len] != input[(order[row - 1] + offset) % input.len]) {
                same = false;
                break;
            }
        }
        if (same) unique = false;
    }
    if (unique) try std.testing.expectEqual(original, @as(usize, transformed.original_pointer));
    const selected = order[transformed.original_pointer];
    for (0..input.len) |offset|
        try std.testing.expectEqual(input[offset], input[(selected + offset) % input.len]);
}

fn check(comptime Codec: type, input: []const u8, use_naive: bool) !void {
    const expected = try full.transformAlloc(a, input);
    defer expected.deinit(a);
    const actual = try Codec.transformAlloc(a, input);
    defer actual.deinit(a);
    try std.testing.expectEqualSlices(u8, expected.bytes, actual.bytes);
    try std.testing.expectEqual(expected.original_pointer, actual.original_pointer);
    try inverse(input, actual);
    if (use_naive) try naive(input, actual);
}

fn exhaustive(comptime Codec: type) !void {
    var input: [7]u8 = undefined;
    for (1..8) |length| {
        var combinations: usize = 1;
        for (0..length) |_| combinations *= 3;
        for (0..combinations) |value| {
            var digits = value;
            for (input[0..length]) |*byte| {
                byte.* = @intCast('a' + digits % 3);
                digits /= 3;
            }
            try check(Codec, input[0..length], true);
        }
    }
}

fn randomBytes(input: []u8, seed: *u64) void {
    for (input) |*byte| {
        seed.* ^= seed.* >> 12;
        seed.* ^= seed.* << 25;
        seed.* ^= seed.* >> 27;
        byte.* = @truncate((seed.* *% 0x2545f4914f6cdd1d) >> 56);
    }
}

fn distributions(comptime Codec: type) !void {
    var seed: u64 = 0x62a735819caf0241;
    var small: [128]u8 = undefined;
    for (0..96) |index| {
        const length = 1 + index % small.len;
        randomBytes(small[0..length], &seed);
        if (index % 3 == 0) for (small[0..length]) |*byte| {
            byte.* %= 4;
        };
        try check(Codec, small[0..length], true);
    }
    for ([_]usize{ 1, 2, 3, 7, 16, 31, 63, 127, 255, 256, 257, 509, 997, 1023, 1025, 4093, 4096, 4097, 16381 }) |length| {
        const input = try a.alloc(u8, length);
        defer a.free(input);
        randomBytes(input, &seed);
        try check(Codec, input, length <= 128);
        @memset(input, 0xa5);
        try check(Codec, input, length <= 128);
        for (input, 0..) |*byte, index| byte.* = "abac"[index % 4];
        try check(Codec, input, length <= 128);
        // Distinct rotations share nearly the entire prefix before one marker.
        @memset(input, 'a');
        input[length - 1] = 'b';
        try check(Codec, input, length <= 128);
    }
    for ([_]usize{ 8, 64, 256, 1024, 4096 }) |length| {
        const input = try a.alloc(u8, length);
        defer a.free(input);
        for (input, 0..) |*byte, index| byte.* = "abcabcXY"[index % 8];
        try check(Codec, input, length <= 128);
    }
    var unique: [256]u8 = undefined;
    for (&unique, 0..) |*byte, index| byte.* = @intCast((index * 73 + 19) % 256);
    try check(Codec, &unique, false);
}

fn maximumBlock(comptime Codec: type) !void {
    const input = try a.alloc(u8, 900_000);
    defer a.free(input);
    var seed: u64 = 0x6bc1247a349dba83;
    randomBytes(input, &seed);
    // One maximum-size differential and linear inverse check. Random bytes
    // exercise early uniqueness without repeating expensive periodic extremes.
    try check(Codec, input, false);
}

fn failures(comptime Codec: type) !void {
    var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidBzip2Stream, Codec.transformAlloc(failing.allocator(), ""));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    const too_large = try a.alloc(u8, 900_001);
    defer a.free(too_large);
    try std.testing.expectError(error.InvalidBzip2Stream, Codec.transformAlloc(failing.allocator(), too_large));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    var unique: [256]u8 = undefined;
    for (&unique, 0..) |*byte, index| byte.* = @intCast(index);
    const Run = struct {
        fn transform(allocator: std.mem.Allocator, bytes: []const u8) !void {
            const block = try Codec.transformAlloc(allocator, bytes);
            defer block.deinit(allocator);
        }
    };
    for ([_][]const u8{ "banana banana banana", &unique, "abcabcXY" ** 8 }) |input| {
        // Four u32 arrays, counts, and final transformed storage. Cover zero
        // doubling rounds, early uniqueness, and exact periodic full doubling.
        for (0..6) |failure_index| {
            var allocation = std.testing.FailingAllocator.init(a, .{ .fail_index = failure_index });
            try std.testing.expectError(error.OutOfMemory, Codec.transformAlloc(allocation.allocator(), input));
            try std.testing.expectEqual(allocation.allocated_bytes, allocation.freed_bytes);
        }
        try std.testing.checkAllAllocationFailures(a, Run.transform, .{input});
    }
}

test "Bzip2 BWT exhaustive ternary rotations match full doubling and naive sort" {
    try exhaustive(bwt);
}
test "Bzip2 BWT random periodic and unique inputs preserve exact full doubling" {
    try distributions(bwt);
}
test "Bzip2 BWT maximum block preserves full doubling and inverse recovery" {
    try maximumBlock(bwt);
}
test "Bzip2 BWT rejects invalid lengths and unwinds every allocation failure" {
    try failures(bwt);
}
