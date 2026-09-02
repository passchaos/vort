const std = @import("std");

const hash_bits = 15;
const bucket_count = 1 << hash_bits;
pub const ways = 4;
const entry_count = bucket_count * ways;
pub const invalid_position = std.math.maxInt(usize);

/// Fixed-size, set-associative index over absolute stream positions. Absolute
/// positions let the rolling byte window slide without rebuilding every hash
/// bucket; queries discard candidates older than the current window start.
pub const Index = struct {
    entries: std.ArrayList(usize) = .empty,

    pub fn deinit(self: *Index, allocator: std.mem.Allocator) void {
        self.entries.deinit(allocator);
        self.* = .{};
    }

    pub fn prepare(self: *Index, allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
        if (self.entries.items.len == entry_count) return;
        try self.entries.resize(allocator, entry_count);
        @memset(self.entries.items, invalid_position);
    }

    pub fn clearRetainingCapacity(self: *Index) void {
        if (self.entries.items.len != 0) @memset(self.entries.items, invalid_position);
    }

    pub fn insertBlock(self: *Index, block: []const u8, absolute_start: usize) void {
        if (self.entries.items.len == 0 or block.len < 8) return;
        for (0..block.len - 7) |offset| {
            const position = std.math.add(usize, absolute_start, offset) catch unreachable;
            const bucket_start = hash8(block[offset..][0..8]) * ways;
            const bucket = self.entries.items[bucket_start..][0..ways];
            var i: usize = ways - 1;
            while (i > 0) : (i -= 1) bucket[i] = bucket[i - 1];
            bucket[0] = position;
        }
    }

    pub fn candidates(self: *const Index, prefix: *const [8]u8) []const usize {
        if (self.entries.items.len == 0) return &.{};
        const start = hash8(prefix) * ways;
        return self.entries.items[start..][0..ways];
    }
};

fn hash8(bytes: *const [8]u8) usize {
    const value = std.mem.readInt(u64, bytes, .little);
    return @intCast((value *% 11_400_714_819_323_198_485) >> (64 - hash_bits));
}

test "Zstd incremental history index keeps recent same-hash candidates" {
    var index: Index = .{};
    defer index.deinit(std.testing.allocator);
    try index.prepare(std.testing.allocator);
    index.insertBlock("abcdefgh-abcdefgh-abcdefgh", 100);
    const candidates = index.candidates("abcdefgh");
    try std.testing.expectEqual(@as(usize, 118), candidates[0]);
    try std.testing.expectEqual(@as(usize, 109), candidates[1]);
    try std.testing.expectEqual(@as(usize, 100), candidates[2]);
}
