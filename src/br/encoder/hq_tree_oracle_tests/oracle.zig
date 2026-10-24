const std = @import("std");

pub const Match = struct { length: usize = 0, distance: usize = 0 };

/// Independent scalar byte view. No production Source or hash helper is used.
pub const Data = struct {
    history: []const u8,
    input: []const u8,
    window: usize,
    frame_offset: u64,

    fn byte(self: Data, at: usize) u8 {
        return if (at < self.history.len) self.history[at] else self.input[at - self.history.len];
    }

    pub fn length(self: Data, position: usize, distance: usize) usize {
        if (position >= self.input.len or distance == 0 or distance > self.window or
            @as(u64, @intCast(distance)) > self.frame_offset + position or distance > self.history.len + position) return 0;
        const candidate = self.history.len + position - distance;
        var count: usize = 0;
        while (count < self.input.len - position and self.byte(candidate + count) == self.input[position + count]) : (count += 1) {}
        return count;
    }

    pub fn best(self: Data, position: usize) Match {
        var found: Match = .{};
        const available = @min(self.history.len + position, self.window);
        for (1..available + 1) |distance| {
            const count = self.length(position, distance);
            if (count >= 2 and count > found.length) found = .{ .length = count, .distance = distance };
        }
        return found;
    }

    pub fn validateFrontier(self: Data, position: usize, matches: anytype) !void {
        var previous: usize = 1;
        for (matches) |match| {
            try std.testing.expect(match.length > previous);
            try std.testing.expect(match.distance != 0 and match.distance <= self.window);
            try std.testing.expectEqual(self.length(position, match.distance), match.length);
            previous = match.length;
        }
    }
};

pub fn random(bytes: []u8, seed: u64, alphabet: u8) void {
    var state = seed;
    for (bytes) |*byte| {
        state = state *% 6364136223846793005 +% 1442695040888963407;
        byte.* = @intCast((state >> 32) % alphabet);
    }
}

/// The first three bytes occur only at explicit prefix starts. Increasing
/// prefix lengths in reverse storage order produce a long frontier without
/// requiring a production hash collision oracle.
pub fn increasingPrefixes(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    var size = input.len;
    while (size >= 3) : (size -= 1) {
        try bytes.appendSlice(allocator, input[0..size]);
        try bytes.append(allocator, 255);
    }
    return bytes.toOwnedSlice(allocator);
}

/// Frozen public storage contract: 3 independent 65536-entry u32 heads,
/// power-of-two 16-byte generation nodes, and two-usize frontier records.
pub fn coldBytes(history_len: usize, input_len: usize, window: usize, depth: u32) usize {
    const total = history_len + input_len;
    const active = @min(total, window + 1);
    var nodes: usize = if (active >= 2) 1 else 0;
    while (nodes != 0 and nodes < active) nodes *= 2;
    const heads = @as(usize, @intFromBool(total >= 2)) + @intFromBool(total >= 3) + @intFromBool(total >= 4);
    const candidates = if (input_len >= 2) @min(input_len - 1, @as(usize, depth) * 2 + 1) else 0;
    return heads * 65536 * 4 + nodes * 16 + candidates * 2 * @sizeOf(usize);
}
