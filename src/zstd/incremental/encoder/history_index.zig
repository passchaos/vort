const std = @import("std");

const hash_bits = 15;
const bucket_count = 1 << hash_bits;
pub const ways = 4;
pub const long_ways = 4;
const long_sample_bits = 8;
const entry_count = bucket_count * ways;
const long_entry_count = bucket_count * long_ways;
pub const invalid_position = std.math.maxInt(usize);
pub const CandidateSets = struct {
    recent: []const usize,
    long: []const usize,
};

/// Fixed-size, set-associative index over absolute stream positions. Absolute
/// positions let the rolling byte window slide without rebuilding every hash
/// bucket; queries discard candidates older than the current window start.
pub const Index = struct {
    recent_entries: std.ArrayList(usize) = .empty,
    long_entries: std.ArrayList(usize) = .empty,
    long_enabled: bool = false,

    pub fn deinit(self: *Index, allocator: std.mem.Allocator) void {
        self.long_entries.deinit(allocator);
        self.recent_entries.deinit(allocator);
        self.* = .{};
    }

    pub fn prepare(
        self: *Index,
        allocator: std.mem.Allocator,
        enable_long: bool,
    ) std.mem.Allocator.Error!void {
        if (self.recent_entries.items.len != entry_count) {
            try self.recent_entries.resize(allocator, entry_count);
            @memset(self.recent_entries.items, invalid_position);
        }
        if (enable_long and self.long_entries.items.len != long_entry_count) {
            try self.long_entries.resize(allocator, long_entry_count);
            @memset(self.long_entries.items, invalid_position);
        }
        self.long_enabled = enable_long;
    }

    pub fn clearRetainingCapacity(self: *Index) void {
        if (self.recent_entries.items.len != 0)
            @memset(self.recent_entries.items, invalid_position);
        if (self.long_entries.items.len != 0)
            @memset(self.long_entries.items, invalid_position);
        self.long_enabled = false;
    }

    pub fn insertBlock(self: *Index, block: []const u8, absolute_start: usize) void {
        if (self.recent_entries.items.len == 0 or block.len < 8) return;
        for (0..block.len - 7) |offset| {
            const position = std.math.add(usize, absolute_start, offset) catch unreachable;
            const hash = hashValue8(block[offset..][0..8]);
            insert(&self.recent_entries, hashBucket(hash), ways, position);
            if (self.long_enabled and isLongSample(hash))
                insert(&self.long_entries, hashBucket(hash), long_ways, position);
        }
    }

    pub fn recentCandidates(self: *const Index, prefix: *const [8]u8) []const usize {
        if (self.recent_entries.items.len == 0) return &.{};
        const start = hashBucket(hashValue8(prefix)) * ways;
        return self.recent_entries.items[start..][0..ways];
    }

    pub fn longCandidates(self: *const Index, prefix: *const [8]u8) []const usize {
        const hash = hashValue8(prefix);
        if (!self.long_enabled or self.long_entries.items.len == 0 or
            !isLongSample(hash)) return &.{};
        const start = hashBucket(hash) * long_ways;
        return self.long_entries.items[start..][0..long_ways];
    }

    pub fn candidateSets(self: *const Index, prefix: *const [8]u8) CandidateSets {
        const hash = hashValue8(prefix);
        const bucket = hashBucket(hash);
        const recent = if (self.recent_entries.items.len == 0)
            &.{}
        else
            self.recent_entries.items[bucket * ways ..][0..ways];
        const long = if (!self.long_enabled or self.long_entries.items.len == 0 or
            !isLongSample(hash))
            &.{}
        else
            self.long_entries.items[bucket * long_ways ..][0..long_ways];
        return .{ .recent = recent, .long = long };
    }

    pub fn longEnabled(self: *const Index) bool {
        return self.long_enabled;
    }
};

fn insert(entries: *std.ArrayList(usize), bucket: usize, way_count: usize, position: usize) void {
    const start = bucket * way_count;
    const slots = entries.items[start..][0..way_count];
    var i = way_count - 1;
    while (i > 0) : (i -= 1) slots[i] = slots[i - 1];
    slots[0] = position;
}

fn hashValue8(bytes: *const [8]u8) u64 {
    const value = std.mem.readInt(u64, bytes, .little);
    return value *% 11_400_714_819_323_198_485;
}

fn hashBucket(hash: u64) usize {
    return @intCast(hash >> (64 - hash_bits));
}

fn isLongSample(hash: u64) bool {
    return @as(u8, @truncate(hash)) & ((1 << long_sample_bits) - 1) == 0;
}

test "Zstd incremental history index keeps recent same-hash candidates" {
    var index: Index = .{};
    defer index.deinit(std.testing.allocator);
    try index.prepare(std.testing.allocator, false);
    index.insertBlock("abcdefgh-abcdefgh-abcdefgh", 100);
    const candidates = index.recentCandidates("abcdefgh");
    try std.testing.expectEqual(@as(usize, 118), candidates[0]);
    try std.testing.expectEqual(@as(usize, 109), candidates[1]);
    try std.testing.expectEqual(@as(usize, 100), candidates[2]);
}

test "Zstd incremental history index isolates sparse long candidates" {
    var index: Index = .{};
    defer index.deinit(std.testing.allocator);
    try index.prepare(std.testing.allocator, true);
    var sample: [8]u8 = undefined;
    var value: u64 = 0;
    while (true) : (value += 1) {
        std.mem.writeInt(u64, &sample, value, .little);
        if (isLongSample(hashValue8(&sample))) break;
    }
    index.insertBlock(&sample, 1234);
    try std.testing.expectEqual(@as(usize, 1234), index.longCandidates(&sample)[0]);
    index.clearRetainingCapacity();
    try index.prepare(std.testing.allocator, false);
    try std.testing.expectEqual(@as(usize, 0), index.longCandidates(&sample).len);
}

test "Zstd incremental history long index releases allocation failures" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var index: Index = .{};
            defer index.deinit(allocator);
            try index.prepare(allocator, true);
            try std.testing.expectEqual(entry_count, index.recent_entries.items.len);
            try std.testing.expectEqual(long_entry_count, index.long_entries.items.len);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{},
    );
}
