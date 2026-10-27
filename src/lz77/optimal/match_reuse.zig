//! Reuse an exact suffix comparison at the adjacent reverse position.
const std = @import("std");
const match_length = @import("../match/length.zig");

/// Local to one immutable-input reverse parse. A cached capped comparison
/// validates only its prefix; an uncapped comparison also proves the next
/// mismatch. Neither case changes candidate order or the caller's maximum.
pub const Cache = struct {
    position: usize = std.math.maxInt(usize),
    distance: usize = 0,
    length: usize = 0,
    complete: bool = false,

    pub fn find(self: *Cache, input: []const u8, candidate: usize, position: usize, maximum: usize) usize {
        std.debug.assert(candidate < position and position < input.len and maximum <= input.len - position);
        const distance = position - candidate;
        const length = result: {
            if (self.position != position + 1 or self.distance != distance)
                break :result match_length.find(input, candidate, position, maximum);
            if (maximum == 0 or input[candidate] != input[position]) break :result 0;
            const known = self.length + 1;
            if (self.complete or known >= maximum) break :result @min(known, maximum);
            break :result known + match_length.find(input, candidate + known, position + known, maximum - known);
        };
        self.* = .{ .position = position, .distance = distance, .length = length, .complete = length < maximum };
        return length;
    }
};

fn scalar(input: []const u8, candidate: usize, position: usize, maximum: usize) usize {
    var length: usize = 0;
    while (length < maximum and input[candidate + length] == input[position + length]) length += 1;
    return length;
}

test "reverse match reuse preserves overlaps, every capped tail and changed maxima" {
    var input: [800]u8 = undefined;
    var state: u32 = 0x345bae31;
    for (0..4) |kind| {
        for (&input, 0..) |*byte, pos| {
            state = state *% 1664525 +% 1013904223;
            byte.* = switch (kind) {
                0 => 0,
                1 => @intCast(pos % 7),
                2 => if (pos % 97 < 89) 0 else @truncate(state >> 24),
                else => @truncate(state >> 24),
            };
        }
        for ([_]usize{ 1, 2, 7, 8, 16, 32, 129, 258 }) |distance| {
            for ([_]usize{ 0, 1, 3, 7, 8, 9, 31, 32, 39, 40, 257, 258, 321 }) |limit| {
                var cache = Cache{};
                var position = input.len;
                while (position > distance) {
                    position -= 1;
                    const maximum = @min(limit, input.len - position);
                    try std.testing.expectEqual(scalar(&input, position - distance, position, maximum), cache.find(&input, position - distance, position, maximum));
                }
            }
            var cache = Cache{};
            var position = input.len;
            while (position > distance) {
                position -= 1;
                const maximum = @min((position * 37) % 322, input.len - position);
                try std.testing.expectEqual(scalar(&input, position - distance, position, maximum), cache.find(&input, position - distance, position, maximum));
            }
        }
    }
}

test "reverse match reuse preserves first mismatches and unrelated query misses" {
    var input: [800]u8 = @splat(7);
    for (0..322) |mismatch| {
        input[400 + mismatch] = 9;
        for ([_]usize{ 0, 3, 7, 8, 39, 40, 257, 258, 321 }) |limit| {
            var cache = Cache{};
            _ = cache.find(&input, 1, 401, limit);
            try std.testing.expectEqual(scalar(&input, 0, 400, 321), cache.find(&input, 0, 400, 321));
            try std.testing.expectEqual(scalar(&input, 1, 400, 321), cache.find(&input, 1, 400, 321));
            try std.testing.expectEqual(scalar(&input, 0, 398, 321), cache.find(&input, 0, 398, 321));
        }
        input[400 + mismatch] = 7;
    }
}
