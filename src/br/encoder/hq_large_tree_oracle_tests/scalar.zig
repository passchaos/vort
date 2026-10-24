const std = @import("std");

pub fn fill(bytes: []u8, seed: u64) void {
    var state = seed;
    for (bytes) |*byte| {
        state = state *% 6364136223846793005 +% 1442695040888963407;
        byte.* = 64 + @as(u8, @intCast((state >> 32) % 128));
    }
}

/// Compare one declared candidate directly. This deliberately avoids a scan
/// over the complete far history and calls no production match/hash routine.
pub fn length(history: []const u8, input: []const u8, position: usize, distance: usize, window: usize) usize {
    if (position >= input.len or distance == 0 or distance > window or distance > history.len + position) return 0;
    const start = history.len + position - distance;
    var count: usize = 0;
    while (count < input.len - position) : (count += 1) {
        const at = start + count;
        const byte = if (at < history.len) history[at] else input[at - history.len];
        if (byte != input[position + count]) return count;
    }
    return count;
}

pub fn validate(history: []const u8, input: []const u8, position: usize, window: usize, matches: anytype) !void {
    var previous: usize = 1;
    for (matches) |match| {
        try std.testing.expect(match.length > previous);
        try std.testing.expect(match.distance <= window and match.distance <= history.len + position);
        try std.testing.expectEqual(length(history, input, position, match.distance, window), match.length);
        previous = match.length;
    }
}
