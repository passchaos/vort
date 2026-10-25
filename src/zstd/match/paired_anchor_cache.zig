//! Borrowed anchor hashes and lazy adjacent-occurrence lengths for one block.
//! The original scanner still owns suffix order, pending parity and winners.
//! Storage is caller-owned, normally aligned, and never allocated here.
const std = @import("std");

pub const max_block_len: usize = 128 * 1024;
pub const anchor_len: usize = 8;
pub const unknown_length: u32 = std.math.maxInt(u32);
const hash_limit: usize = 1 << 15;

pub const Error = error{
    InvalidBlock,
    InsufficientStorage,
    OverlappingStorage,
    IntegerOverflow,
};

pub const Work = struct {
    build_hashes: u64 = 0,
    query_hashes: u64 = 0,
    /// Actual Extender invocations on cache misses, including short matches.
    extension_calls: u64 = 0,
    extension_hits: u64 = 0,
    /// Used hash/length payload; excludes unused capacity and this metadata.
    workspace_bytes: u64 = 0,
};

/// Every pair supplied by the scanner must consist of adjacent occurrences
/// of the same canonical 15-bit hash in the complete immutable block. When a
/// suffix restarts pending=false, parity changes which positions are seconds,
/// but the first for any given second remains its global adjacent predecessor.
/// Thus an exact length can be cached by second alone, including 0..7 lengths
/// from hash collisions. This is not a cache for arbitrary predecessor search.
///
/// The input and backing storage stay borrowed for this Cache's lifetime.
/// Do not mutate the input or hashes, or share mutable lengths between workers.
/// Re-init rebuilds and resets every used entry; it invalidates older Cache
/// views over the same storage even when the input pointer and length match.
pub const Cache = struct {
    block: []const u8,
    hashes: []const u16,
    lengths: []u32,
    work: Work = .{},

    const Self = @This();

    /// Hasher is the scanner's deterministic fn(*const [8]u8) usize. It cannot
    /// fail and must return a canonical value below 32768. All returned errors
    /// occur before any storage write or Hasher call; an invalid callback is a
    /// caller contract violation, not a recoverable initialization error.
    ///
    /// Admission checks the complete supplied storage slices for range
    /// overflow and overlap, then borrows only M=max(0,N-7) used entries.
    /// Their payload is 6*M bytes, at most 786390 for a 128KiB block.
    pub fn init(block: []const u8, hashes: []u16, lengths: []u32, comptime Hasher: anytype) Error!Self {
        if (block.len > max_block_len) return error.InvalidBlock;
        const count = if (block.len < anchor_len) 0 else block.len - (anchor_len - 1);
        if (hashes.len < count or lengths.len < count) return error.InsufficientStorage;

        const input_region = try byteRegion(u8, block);
        const hash_region = try byteRegion(u16, hashes);
        const length_region = try byteRegion(u32, lengths);
        if (overlaps(hash_region, length_region) or overlaps(input_region, hash_region) or overlaps(input_region, length_region))
            return error.OverlappingStorage;
        const workspace_bytes = std.math.mul(u64, @intCast(count), @sizeOf(u16) + @sizeOf(u32)) catch return error.IntegerOverflow;

        var self: Self = .{
            .block = block,
            .hashes = hashes[0..count],
            .lengths = lengths[0..count],
            .work = .{ .workspace_bytes = workspace_bytes },
        };
        for (0..count) |position| {
            const value: usize = Hasher(block[position..][0..anchor_len]);
            std.debug.assert(value < hash_limit);
            hashes[position] = @intCast(value);
            lengths[position] = unknown_length;
            self.work.build_hashes +|= 1;
        }
        return self;
    }

    pub fn hash(self: *Self, position: usize) usize {
        std.debug.assert(position < self.hashes.len);
        self.work.query_hashes +|= 1;
        return self.hashes[position];
    }

    /// Extender is the same deterministic fn([]const u8, usize, usize) usize
    /// for all calls on this Cache. It returns the unmodified exact match
    /// length, no larger than block.len-second. The scanner supplies the global
    /// adjacent-occurrence pair and performs its original guards before here;
    /// local asserts check ranges/order/hash, not adjacency by rescanning.
    pub fn cachedLength(self: *Self, first: usize, second: usize, comptime Extender: anytype) usize {
        std.debug.assert(first < second and second < self.hashes.len);
        std.debug.assert(self.hashes[first] == self.hashes[second]);
        const cached = self.lengths[second];
        if (cached != unknown_length) {
            self.work.extension_hits +|= 1;
            return cached;
        }

        self.work.extension_calls +|= 1;
        const length: usize = Extender(self.block, first, second);
        std.debug.assert(length <= self.block.len - second);
        self.lengths[second] = @intCast(length);
        return length;
    }
};

const Region = struct { start: usize, end: usize };

fn byteRegion(comptime Element: type, values: []const Element) Error!Region {
    const bytes = std.math.mul(usize, values.len, @sizeOf(Element)) catch return error.IntegerOverflow;
    const start = @intFromPtr(values.ptr);
    const end = std.math.add(usize, start, bytes) catch return error.IntegerOverflow;
    return .{ .start = start, .end = end };
}

fn overlaps(first: Region, second: Region) bool {
    if (first.start == first.end or second.start == second.end) return false;
    return first.start < second.end and second.start < first.end;
}

test "zstd paired anchor cache complete borrowed storage contracts" {
    try @import("paired_anchor_cache_tests.zig").contracts(@This());
}
