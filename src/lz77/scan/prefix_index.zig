//! Prefix chains with first-byte ordinals preserve the original scan budget.
const std = @import("std");
const history_len = @import("byte_index.zig").history_len;
const absent = std.math.maxInt(usize);
const bucket_count = 4096;

pub const Index = struct {
    heads: [bucket_count]usize = @splat(absent),
    previous: [history_len]u16 = undefined,
    // Modulo counts are unambiguous inside a <=32768-byte physical window.
    ranks: [history_len]u16 = undefined,
    counts: [256]u16 = @splat(0),
    position: usize = 0,

    pub fn advance(self: *Index, input: []const u8, end: usize) void {
        std.debug.assert(self.position <= end and end <= input.len);
        while (self.position < end) {
            const slot = self.position & (history_len - 1);
            const byte = input[self.position];
            if (self.batch(input, end, byte, slot)) continue;
            self.counts[byte] +%= 1;
            self.ranks[slot] = self.counts[byte];
            self.previous[slot] = 0;
            if (input.len - self.position >= 3) {
                const hash = bucket(input[self.position..][0..3]);
                const last = self.heads[hash];
                if (last != absent and self.position - last <= history_len)
                    self.previous[slot] = @intCast(self.position - last);
                self.heads[hash] = self.position;
            }
            self.position += 1;
        }
    }

    fn batch(self: *Index, input: []const u8, end: usize, byte: u8, slot: usize) bool {
        // Sixteen anchors require eighteen equal source bytes because each
        // prefix may include two future bytes. Never cross a ring or end cut.
        if (end - self.position < 16 or input.len - self.position < 18 or slot > history_len - 16) return false;
        if (input[self.position + 1] != byte) return false;
        const bytes: @Vector(16, u8) = @bitCast(input[self.position + 2 ..][0..16].*);
        if (!@reduce(.And, bytes == @as(@Vector(16, u8), @splat(byte)))) return false;
        const hash = bucket(input[self.position..][0..3]);
        const last = self.heads[hash];
        self.previous[slot..][0..16].* = @splat(1);
        self.previous[slot] = if (last != absent and self.position - last <= history_len)
            @intCast(self.position - last)
        else
            0;
        const progression: @Vector(16, u16) = .{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
        const ranks: [16]u16 = @as(@Vector(16, u16), @splat(self.counts[byte])) +% progression;
        self.ranks[slot..][0..16].* = ranks;
        self.counts[byte] +%= 16;
        self.heads[hash] = self.position + 15;
        self.position += 16;
        return true;
    }

    pub fn candidates(self: *const Index, input: []const u8, pos: usize, window: usize) Iterator {
        std.debug.assert(pos == self.position and input.len - pos >= 3);
        const last = self.heads[bucket(input[pos..][0..3])];
        const start = pos -| @min(window, history_len);
        return .{ .index = self, .start = start, .candidate = if (last != absent and last >= start) last else null };
    }

    /// Caller first verifies that candidate and query share their first byte.
    /// This includes every newer same-byte anchor, even absent prefix matches.
    pub fn consumed(self: *const Index, needle: u8, candidate: usize) usize {
        std.debug.assert(candidate < self.position and self.position - candidate <= history_len);
        return @as(usize, self.counts[needle] -% self.ranks[candidate & (history_len - 1)]) + 1;
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

pub fn bucket(bytes: *const [3]u8) usize {
    const value = @as(u32, bytes[0]) | (@as(u32, bytes[1]) << 8) | (@as(u32, bytes[2]) << 16);
    return (value *% 2654435761) >> 20;
}

test {
    _ = @import("tests/prefix_index.zig");
}
