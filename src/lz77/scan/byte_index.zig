//! Caller-owned, fixed-window chains in the exact backwards first-byte order.
const std = @import("std");

pub const history_len = 32768;
const absent = std.math.maxInt(usize);

pub const Index = struct {
    // Absolute heads distinguish stale anchors beyond a complete u16 cycle.
    heads: [256]usize = @splat(absent),
    // Positive deltas fit the window; zero ends a chain. Slots are read only
    // after insertion and before their original position expires.
    previous: [history_len]u16 = undefined,
    position: usize = 0,

    pub fn advance(self: *Index, input: []const u8, end: usize) void {
        std.debug.assert(self.position <= end and end <= input.len);
        while (self.position < end) {
            const byte = input[self.position];
            const last = self.heads[byte];
            self.previous[self.position & (history_len - 1)] =
                if (last != absent and self.position - last <= history_len)
                    @intCast(self.position - last)
                else
                    0;
            self.heads[byte] = self.position;
            self.position += 1;
        }
    }

    pub fn candidates(self: *const Index, needle: u8, window: usize) Iterator {
        const last = self.heads[needle];
        const start = self.position -| @min(window, history_len);
        return .{ .index = self, .start = start, .candidate = if (last != absent and last >= start) last else null };
    }

    pub const Iterator = struct {
        index: *const Index,
        start: usize,
        candidate: ?usize,

        pub fn next(self: *Iterator) ?usize {
            const result = self.candidate orelse return null;
            const distance = self.index.previous[result & (history_len - 1)];
            self.candidate = if (distance != 0 and result - self.start >= distance) result - distance else null;
            return result;
        }
    };
};

test {
    _ = @import("tests/byte_index.zig");
}
