//! Exact original hash/prefix ordinals for suffix-anchored candidate jumps.
const std = @import("std");
const access = @import("index_access.zig");
const history = 32768;
const empty = std.math.maxInt(u32);

pub fn samplePosition(input_len: usize, ordinal: usize) usize {
    const state = @as(u64, @intCast(ordinal + 1)) *% 0x9e3779b97f4a7c15;
    return 3 + @as(usize, @intCast(state % (input_len - 5)));
}

/// Index construction pays off on dense repeated prefixes, while sparse photo
/// and random blocks keep their existing compact index and heap footprint.
pub fn useful(input: []const u8, raw: anytype) bool {
    std.debug.assert(input.len == raw.len);
    if (input.len < 1024) return false;
    var nearby: usize = 0;
    // Scramble sample positions so an image row stride cannot repeatedly probe
    // the same pixel channel or leading zero residuals on every row.
    for (0..256) |ordinal| {
        const pos = samplePosition(input.len, ordinal);
        const previous = access.sample(raw, pos);
        if (previous != empty and pos - @as(usize, previous) <= 256 and
            std.mem.readInt(u24, input[previous..][0..3], .little) == std.mem.readInt(u24, input[pos..][0..3], .little)) nearby += 1;
    }
    return nearby >= 192;
}

/// Linear prefix minima win when validated candidates usually add only a
/// short tail. Long repeated matches amortize the bounded range-minimum
/// queues instead. Tiny blocks keep the lower fixed setup cost directly.
pub fn sparseLinearUseful(input: []const u8, raw: anytype) bool {
    std.debug.assert(input.len == raw.len);
    if (input.len < 8 * 1024) return true;
    var measured: usize = 0;
    var total_length: usize = 0;
    for (0..64) |ordinal| {
        const pos = samplePosition(input.len, ordinal);
        const predecessor = access.sample(raw, pos);
        if (predecessor == empty or pos - @as(usize, predecessor) > history) continue;
        const candidate: usize = predecessor;
        if (std.mem.readInt(u24, input[candidate..][0..3], .little) != std.mem.readInt(u24, input[pos..][0..3], .little)) continue;
        var length: usize = 3;
        const maximum = @min(@as(usize, 258), input.len - pos);
        while (length < maximum and input[candidate + length] == input[pos + length]) length += 1;
        measured += 1;
        total_length += length;
    }
    return measured == 0 or total_length <= measured * 16;
}

test "sparse linear policy separates short candidates from repeated tails" {
    var short: [16 * 1024]u8 = undefined;
    var state: u32 = 0x8cb36f21;
    for (&short) |*byte| {
        state = state *% 1664525 +% 1013904223;
        byte.* = @truncate(state >> 24);
    }
    var short_prev: [short.len]u32 = undefined;
    @memset(&short_prev, empty);
    try std.testing.expect(sparseLinearUseful(&short, &short_prev));

    var repeated: [16 * 1024]u8 = undefined;
    for (&repeated, 0..) |*byte, pos| byte.* = @intCast(pos % 7);
    var repeated_prev: [repeated.len]u32 = undefined;
    for (&repeated_prev, 0..) |*previous, pos| previous.* = if (pos < 7) empty else @intCast(pos - 7);
    try std.testing.expect(!sparseLinearUseful(&repeated, &repeated_prev));
    try std.testing.expect(sparseLinearUseful(repeated[0..4096], repeated_prev[0..4096]));
}

pub const Index = struct {
    raw_ranks: std.ArrayList(u16) = .empty,
    prefix_ranks: std.ArrayList(u16) = .empty,

    pub fn deinit(self: *Index, allocator: std.mem.Allocator) void {
        self.raw_ranks.deinit(allocator);
        self.prefix_ranks.deinit(allocator);
        self.* = .{};
    }

    /// The parser retains the complete unmodified raw chain. All ordinals
    /// compare within the physical window, so their u16 wraps are unambiguous.
    pub fn build(self: *Index, allocator: std.mem.Allocator, input: []const u8, raw: []const u32) !void {
        std.debug.assert(input.len == raw.len);
        try self.raw_ranks.ensureTotalCapacityPrecise(allocator, input.len);
        self.raw_ranks.items.len = input.len;
        try self.prefix_ranks.ensureTotalCapacityPrecise(allocator, input.len);
        self.prefix_ranks.items.len = input.len;
        for (0..input.len) |pos| {
            self.raw_ranks.items[pos] = 0;
            self.prefix_ranks.items[pos] = 0;
            if (input.len - pos < 3) continue;
            var last = raw[pos];
            self.raw_ranks.items[pos] = if (last == empty) 1 else self.raw_ranks.items[last] +% 1;
            const prefix = std.mem.readInt(u24, input[pos..][0..3], .little);
            while (last != empty) {
                const candidate: usize = last;
                if (pos - candidate > history) break;
                if (std.mem.readInt(u24, input[candidate..][0..3], .little) == prefix) {
                    self.prefix_ranks.items[pos] = self.prefix_ranks.items[candidate] +% 1;
                    break;
                }
                last = raw[candidate];
            }
            if (self.prefix_ranks.items[pos] == 0 and last == empty)
                self.prefix_ranks.items[pos] = 1;
            // A zero ordinal is valid after wrapping. When the nearest prefix
            // expired instead, a fresh group may restart at one.
            if (last != empty and pos - @as(usize, last) > history)
                self.prefix_ranks.items[pos] = 1;
        }
    }

    pub fn rawCount(self: *const Index, pos: usize, candidate: usize) usize {
        std.debug.assert(candidate < pos and pos - candidate <= history);
        return self.raw_ranks.items[pos] -% self.raw_ranks.items[candidate];
    }

    /// Only call after the original three-byte prefix matches. Difference is
    /// the number of valid prefix candidates through this node, inclusive.
    pub fn prefixCount(self: *const Index, pos: usize, candidate: usize) usize {
        std.debug.assert(candidate < pos and pos - candidate <= history);
        return self.prefix_ranks.items[pos] -% self.prefix_ranks.items[candidate];
    }

    pub fn bytes(self: *const Index) usize {
        return (self.raw_ranks.items.len + self.prefix_ranks.items.len) * @sizeOf(u16);
    }
};
