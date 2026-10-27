const std = @import("std");
const prefix = @import("../prefix_index.zig");
const Index = prefix.Index;

fn nextPrefix(iterator: *Index.Iterator, input: []const u8, pos: usize) !?usize {
    while (iterator.next()) |candidate| {
        if (input[candidate] == input[pos] and
            (pos - candidate <= 8 or candidate == iterator.start or pos - candidate == 16384))
        {
            var count: usize = 1;
            for (input[candidate + 1 .. pos]) |byte| count += @intFromBool(byte == input[pos]);
            try std.testing.expectEqual(count, iterator.index.consumed(input[pos], candidate));
        }
        if (std.mem.eql(u8, input[candidate..][0..3], input[pos..][0..3])) return candidate;
    }
    return null;
}

fn verify(index: *const Index, input: []const u8, pos: usize, window: usize) !void {
    var iterator = index.candidates(input, pos, window);
    const start = pos -| @min(window, 32768);
    var actual = try nextPrefix(&iterator, input, pos);
    var cursor = pos;
    while (cursor > start) {
        cursor -= 1;
        if (std.mem.eql(u8, input[cursor..][0..3], input[pos..][0..3])) {
            try std.testing.expectEqual(@as(?usize, cursor), actual);
            actual = try nextPrefix(&iterator, input, pos);
        }
    }
    try std.testing.expectEqual(@as(?usize, null), actual);
}

test "prefix scan index preserves full scalar prefix order and wrapped first-byte ordinals" {
    const index = try std.testing.allocator.create(Index);
    defer std.testing.allocator.destroy(index);
    const input = try std.testing.allocator.alloc(u8, 3 * 32768 + 257);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x644d98b3;
    for (0..4) |kind| {
        for (input, 0..) |*byte, pos| {
            state = state *% 1664525 +% 1013904223;
            byte.* = switch (kind) {
                0 => 0,
                1 => @intCast(pos % 7),
                2 => if (pos % 97 < 64) 0 else @truncate(state >> 24),
                else => @truncate(state >> 24),
            };
        }
        index.* = .{};
        for (0..input.len - 2) |pos| {
            index.advance(input, pos);
            if (pos < 65 or pos == 32767 or pos == 32768 or pos == 32769 or
                pos == 65535 or pos == 65536 or pos == 65537 or pos == 98304)
            {
                for ([_]usize{ 0, 1, 31, 32, 33, 256, 32767, 32768, 65536 }) |window|
                    try verify(index, input, pos, window);
            }
        }
        index.advance(input, input.len);
        try std.testing.expectEqual(input.len, index.position);
    }
    try std.testing.expect(@sizeOf(Index) <= 161 * 1024);
}

test "prefix scan index expires absolute heads beyond a full u16 position cycle" {
    const index = try std.testing.allocator.create(Index);
    defer std.testing.allocator.destroy(index);
    index.* = .{};
    var input: [70014]u8 = @splat(0);
    input[0] = 255;
    input[70001] = 255;
    input[70010] = 255;
    index.advance(&input, 70001);
    var expired = index.candidates(&input, 70001, 32768);
    try std.testing.expectEqual(@as(?usize, null), expired.next());
    index.advance(&input, 70010);
    var fresh = index.candidates(&input, 70010, 32768);
    try std.testing.expectEqual(@as(?usize, 70001), fresh.next());
    try std.testing.expectEqual(@as(usize, 1), index.consumed(255, 70001));
    try std.testing.expectEqual(@as(?usize, null), fresh.next());
}

fn scalarAdvance(index: *Index, input: []const u8, end: usize) void {
    while (index.position < end) {
        const slot = index.position & (32768 - 1);
        const byte = input[index.position];
        index.counts[byte] +%= 1;
        index.ranks[slot] = index.counts[byte];
        index.previous[slot] = 0;
        if (input.len - index.position >= 3) {
            const hash = prefix.bucket(input[index.position..][0..3]);
            const last = index.heads[hash];
            if (last != std.math.maxInt(usize) and index.position - last <= 32768)
                index.previous[slot] = @intCast(index.position - last);
            index.heads[hash] = index.position;
        }
        index.position += 1;
    }
}

test "prefix scan homogeneous batches preserve every scalar head rank count and ring slot" {
    const index = try std.testing.allocator.create(Index);
    defer std.testing.allocator.destroy(index);
    const reference = try std.testing.allocator.create(Index);
    defer std.testing.allocator.destroy(reference);
    const input = try std.testing.allocator.alloc(u8, 3 * 32768 + 67);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x9c9537fd;
    for (0..5) |kind| {
        for (input, 0..) |*byte, pos| {
            state = state *% 1664525 +% 1013904223;
            byte.* = switch (kind) {
                0 => 0,
                1 => 255,
                2 => 7,
                3 => if (pos % 97 < 64) @intCast(pos / 97 % 256) else @truncate(state >> 24),
                else => @truncate(state >> 24),
            };
        }
        index.* = .{};
        @memset(&index.previous, 0xac95);
        @memset(&index.ranks, 0x7941);
        reference.* = index.*;
        for (0..68) |end| {
            index.advance(input, end);
            scalarAdvance(reference, input, end);
            try compareState(reference, index);
        }
        for ([_]usize{ 257, 1024, 32767, 32768, 32769, 65535, 65536, 65537, 98304, input.len }) |end| {
            index.advance(input, end);
            scalarAdvance(reference, input, end);
            try compareState(reference, index);
        }
        // Fresh source endings exercise every vector lookahead and scalar tail.
        for (0..68) |length| {
            index.* = .{};
            @memset(&index.previous, 0xac95);
            @memset(&index.ranks, 0x7941);
            reference.* = index.*;
            index.advance(input[0..length], length);
            scalarAdvance(reference, input[0..length], length);
            try compareState(reference, index);
        }
    }
}

fn compareState(reference: *const Index, index: *const Index) !void {
    try std.testing.expectEqual(reference.position, index.position);
    try std.testing.expectEqualSlices(usize, &reference.heads, &index.heads);
    try std.testing.expectEqualSlices(u16, &reference.previous, &index.previous);
    try std.testing.expectEqualSlices(u16, &reference.ranks, &index.ranks);
    try std.testing.expectEqualSlices(u16, &reference.counts, &index.counts);
}
