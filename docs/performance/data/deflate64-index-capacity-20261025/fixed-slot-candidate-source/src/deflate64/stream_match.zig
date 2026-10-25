//! Block-local coordinates over retained history and current input. The index
//! is rebuilt for each pass, so stream counters never enter match arithmetic.
const std = @import("std");

pub const window_len: usize = 65_536;
pub const max_match_len: usize = 65_538;
const hash_len = 1 << 15;
const invalid = std.math.maxInt(u32);

/// Small passes never wrap a ring large enough for their complete local span.
/// Larger passes retain the original full-window ring and matching semantics.
pub fn requiredPreviousLen(span: usize) usize {
    return std.math.ceilPowerOfTwoAssert(usize, @max(@as(usize, 1), @min(span, window_len)));
}

pub const Match = struct { length: usize = 0, distance: usize = 0 };
pub const Matcher = struct {
    heads: []u32 = &.{},
    previous: []u32 = &.{},
    history: []const u8 = &.{},
    block: []const u8 = &.{},

    pub fn ensure(self: *Matcher, allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
        try self.ensureForSize(allocator, window_len);
    }
    /// Prepare outside an active matching pass, then rebuild with begin().
    /// Capacity only grows. Fresh tables need no copy because begin rebuilds
    /// every reachable link; failed allocation leaves all Matcher state intact.
    /// Hash heads keep their exact 32768-entry shape for every span.
    /// Prefer backing-allocator remap to avoid owning old and new rings at once.
    /// A refused remap retains allocate-before-free fallback and its peak.
    pub fn ensureForSize(self: *Matcher, allocator: std.mem.Allocator, span: usize) std.mem.Allocator.Error!void {
        const required = requiredPreviousLen(span);
        var new_heads: []u32 = &.{};
        errdefer if (new_heads.len != 0) allocator.free(new_heads);
        if (self.heads.len == 0) new_heads = try allocator.alloc(u32, hash_len);
        const grow_previous = self.previous.len < required;
        var remapped = false;
        const new_previous = if (grow_previous) allocation: {
            if (self.previous.len != 0) {
                if (allocator.remap(self.previous, required)) |resized| {
                    // No fallible operation remains after a successful remap:
                    // the old allocation is already consumed by the allocator.
                    remapped = true;
                    break :allocation resized;
                }
            }
            break :allocation try allocator.alloc(u32, required);
        } else self.previous;

        if (new_heads.len != 0) self.heads = new_heads;
        if (grow_previous) {
            const old_previous = self.previous;
            self.previous = new_previous;
            if (old_previous.len != 0 and !remapped) allocator.free(old_previous);
        }
    }
    pub fn deinit(self: *Matcher, allocator: std.mem.Allocator) void {
        if (self.heads.len != 0) allocator.free(self.heads);
        if (self.previous.len != 0) allocator.free(self.previous);
        self.* = .{};
    }
    pub fn reset(self: *Matcher) void {
        self.history = &.{};
        self.block = &.{};
    }
    pub fn begin(self: *Matcher, history: []const u8, block: []const u8) void {
        std.debug.assert(history.len <= window_len and self.heads.len == hash_len);
        std.debug.assert(std.math.isPowerOfTwo(self.previous.len) and self.previous.len <= window_len);
        std.debug.assert(self.previous.len >= requiredPreviousLen(history.len + block.len));
        self.history = history;
        self.block = block;
        @memset(self.heads, invalid);
        if (self.previous.len == window_len) {
            for (0..history.len) |position| self.insertFor(true, position);
        } else {
            for (0..history.len) |position| self.insertFor(false, position);
        }
    }
    fn byte(self: *const Matcher, position: usize) u8 {
        return if (position < self.history.len) self.history[position] else self.block[position - self.history.len];
    }
    fn hash(self: *const Matcher, position: usize) usize {
        const value = (@as(u32, self.byte(position)) << 16) |
            (@as(u32, self.byte(position + 1)) << 8) | self.byte(position + 2);
        return @intCast((value *% 0x1e35_a7bd) >> 17);
    }
    pub fn insert(self: *Matcher, position: usize) void {
        if (self.previous.len == window_len) self.insertFor(true, position) else self.insertFor(false, position);
    }
    inline fn insertFor(self: *Matcher, comptime full_window: bool, position: usize) void {
        if (position + 3 > self.history.len + self.block.len) return;
        const key = self.hash(position);
        self.previous[slotFor(full_window, position)] = self.heads[key];
        self.heads[key] = @intCast(position);
    }
    /// Search before inserting position. This keeps the ring slot for exactly
    /// position-65536 intact until that maximum-distance candidate is visited.
    pub fn find(self: *const Matcher, position: usize, max_chain: usize, nice_length: usize) Match {
        const available = self.history.len + self.block.len - position;
        if (available < 3 or max_chain == 0) return .{};
        return if (self.previous.len == window_len)
            self.findFor(true, position, max_chain, nice_length)
        else
            self.findFor(false, position, max_chain, nice_length);
    }
    fn findFor(self: *const Matcher, comptime full_window: bool, position: usize, max_chain: usize, nice_length: usize) Match {
        const available = self.history.len + self.block.len - position;
        const limit = @min(available, max_match_len);
        var candidate = self.heads[self.hash(position)];
        var visited: usize = 0;
        var best: Match = .{};
        while (candidate != invalid and visited < max_chain) : (visited += 1) {
            const first: usize = candidate;
            if (first >= position or position - first > window_len) break;
            var length: usize = 0;
            while (length < limit and self.byte(first + length) == self.byte(position + length)) : (length += 1) {}
            if (length >= 3 and length > best.length) {
                best = .{ .length = length, .distance = position - first };
                if (length >= nice_length) break;
            }
            candidate = self.previous[slotFor(full_window, first)];
        }
        return best;
    }
};

inline fn slotFor(comptime full_window: bool, position: usize) usize {
    // begin proves small spans fit entirely in their ring, so they never wrap.
    // A reused full ring keeps the original mask even for a smaller new span.
    return if (full_window) position & (window_len - 1) else position;
}

test "Deflate64 match index bounded capacity and full-window reference contracts" {
    try @import("stream_match_tests.zig").contracts(@This());
}
