//! Optional model-independent HQ match frontier retained across price passes.
const std = @import("std");
const tree = @import("../hq_tree.zig");

// Real bounded frontiers average below 1.2 retained matches per position on
// the locked 4/16 KiB corpus. Two slots per position preserve those replays;
// denser inputs invalidate the optional cache and perform the original search.
pub const matches_per_position: usize = 2;

pub const Cache = struct {
    offsets: []u32 = &.{},
    matches: []tree.Match = &.{},
    positions: usize = 0,
    next_position: usize = 0,
    matches_len: usize = 0,
    complete: bool = false,

    pub fn estimatedBytes(positions: usize) !usize {
        const offset_count = std.math.add(usize, positions, 1) catch return error.WorkingMemoryLimitExceeded;
        const match_count = std.math.mul(usize, positions, matches_per_position) catch return error.WorkingMemoryLimitExceeded;
        const offset_bytes = std.math.mul(usize, offset_count, @sizeOf(u32)) catch return error.WorkingMemoryLimitExceeded;
        const match_bytes = std.math.mul(usize, match_count, @sizeOf(tree.Match)) catch return error.WorkingMemoryLimitExceeded;
        return std.math.add(usize, offset_bytes, match_bytes) catch return error.WorkingMemoryLimitExceeded;
    }

    pub fn init(allocator: std.mem.Allocator, positions: usize) !Cache {
        var result: Cache = .{ .positions = positions };
        errdefer result.deinit(allocator);
        const offset_count = std.math.add(usize, positions, 1) catch return error.WorkingMemoryLimitExceeded;
        const match_count = std.math.mul(usize, positions, matches_per_position) catch return error.WorkingMemoryLimitExceeded;
        result.offsets = try allocator.alloc(u32, offset_count);
        result.matches = try allocator.alloc(tree.Match, match_count);
        result.offsets[0] = 0;
        return result;
    }

    pub fn deinit(self: *Cache, allocator: std.mem.Allocator) void {
        allocator.free(self.matches);
        allocator.free(self.offsets);
        self.* = .{};
    }

    pub fn record(self: *Cache, position: usize, found: tree.Matches) void {
        if (self.offsets.len == 0 or self.complete or position != self.next_position) return self.invalidate();
        const next_len = std.math.add(usize, self.matches_len, found.items.len) catch return self.invalidate();
        if (next_len > self.matches.len) return self.invalidate();
        @memcpy(self.matches[self.matches_len..next_len], found.items);
        self.matches_len = next_len;
        self.next_position += 1;
        self.offsets[self.next_position] = @intCast(self.matches_len);
    }

    pub fn finish(self: *Cache) bool {
        self.complete = self.offsets.len != 0 and self.next_position == self.positions;
        return self.complete;
    }

    pub fn at(self: *const Cache, position: usize) tree.Matches {
        std.debug.assert(self.complete and position < self.positions);
        const start: usize = self.offsets[position];
        const end: usize = self.offsets[position + 1];
        return .{ .items = self.matches[start..end] };
    }

    pub fn entryCount(self: *const Cache) usize {
        return if (self.complete) self.matches_len else 0;
    }

    fn invalidate(self: *Cache) void {
        self.next_position = 0;
        self.matches_len = 0;
        self.complete = false;
    }
};

test "Zstd HQ match frontier cache preserves ordered positions and bounds" {
    try @import("match_frontier_cache_tests.zig").contracts(@This());
}
