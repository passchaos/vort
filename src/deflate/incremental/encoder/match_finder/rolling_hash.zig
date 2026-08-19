const std = @import("std");
const lz77 = @import("../../../../lz77.zig");

const hash_bits: usize = 15;
const hash_size: usize = 1 << hash_bits;
const invalid_position = std.math.maxInt(usize);

/// Persistent 32 KiB hash-chain parser for incremental DEFLATE blocks.
///
/// Positions are absolute within the logical input stream. `prev` is a bounded
/// ring, while each head carries an epoch so reset is O(1) and stale entries
/// cannot be followed. The caller still owns the rolling history bytes; this
/// type retains only the match index and parser progress.
pub const Matcher = struct {
    head: std.ArrayList(usize) = .empty,
    head_epoch: std.ArrayList(u32) = .empty,
    prev: std.ArrayList(usize) = .empty,
    epoch: u32 = 1,
    absolute_position: usize = 0,
    indexed_positions: usize = 0,
    initialized: bool = false,
    anchor_len: u3 = 0,
    lazy_mode: bool = false,

    pub const Snapshot = struct {
        initialized: bool,
        absolute_position: usize,
        indexed_positions: usize,
        table_entries: usize,
    };

    pub fn deinit(self: *Matcher, allocator: std.mem.Allocator) void {
        self.head.deinit(allocator);
        self.head_epoch.deinit(allocator);
        self.prev.deinit(allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Matcher) void {
        self.absolute_position = 0;
        self.invalidateIndex();
    }

    /// Record bytes emitted by a parser that does not use this index. The next
    /// rolling parse will reseed from caller history at the correct logical
    /// stream position rather than following stale chains across skipped data.
    pub fn observeUnindexedBlock(self: *Matcher, block_len: usize, history_len: usize) !void {
        self.invalidateIndex();
        const base = @max(self.absolute_position, history_len);
        self.absolute_position = std.math.add(usize, base, block_len) catch return error.IntegerOverflow;
    }

    fn invalidateIndex(self: *Matcher) void {
        self.indexed_positions = 0;
        self.initialized = false;
        self.anchor_len = 0;
        self.lazy_mode = false;
        self.epoch +%= 1;
        if (self.epoch == 0) {
            @memset(self.head_epoch.items, 0);
            self.epoch = 1;
        }
    }

    pub fn snapshot(self: *const Matcher) Snapshot {
        return .{
            .initialized = self.initialized,
            .absolute_position = self.absolute_position,
            .indexed_positions = self.indexed_positions,
            .table_entries = self.head.items.len + self.head_epoch.items.len + self.prev.items.len,
        };
    }

    pub fn planAlloc(
        self: *Matcher,
        allocator: std.mem.Allocator,
        block: []const u8,
        history: []const u8,
        options: lz77.GreedyOptions,
        lazy: bool,
    ) !lz77.GreedyPlan {
        if (options.window_len == 0 or options.window_len > lz77.default_window_len or
            options.min_match < 3 or options.min_match > 4) return error.InvalidMatch;
        try self.ensureTables(allocator);
        const anchor_len: usize = if (options.min_match >= 4) 4 else 3;
        // Options are intentionally public on the encoder. If a caller changes
        // between three- and four-byte hash anchors between blocks, invalidate
        // the old bucket interpretation and reseed from current history.
        if (self.initialized and (self.anchor_len != anchor_len or self.lazy_mode != lazy)) self.invalidateIndex();
        if (!self.initialized) {
            self.seedHistory(history, block, anchor_len, lazy);
        } else {
            self.seedBoundary(history, block, anchor_len);
        }

        var tokens = try std.ArrayList(lz77.Token).initCapacity(allocator, @min(block.len, 4096));
        errdefer tokens.deinit(allocator);
        var stats: lz77.PlanStats = .{};

        var pos: usize = 0;
        while (pos < block.len) {
            const best = self.findBest(history, block, pos, options, anchor_len);
            if (!acceptMatch(block, pos, best.length, best.distance, options)) {
                try tokens.append(allocator, .{ .literal = block[pos] });
                stats.literals += 1;
                self.insertBlockPosition(history, block, pos, anchor_len);
                pos += 1;
                continue;
            }

            var current_inserted = false;
            if (lazy and pos + 1 < block.len) {
                // Insert before the one-byte probe so distance-1 matches are
                // available at the next position, matching the existing lazy
                // planner's ordering and deterministic tie behavior.
                self.insertBlockPosition(history, block, pos, anchor_len);
                current_inserted = true;
                const next = self.findBest(history, block, pos + 1, options, anchor_len);
                if (next.length >= best.length + options.lazy_min_gain and
                    acceptMatch(block, pos + 1, next.length, next.distance, options))
                {
                    try tokens.append(allocator, .{ .literal = block[pos] });
                    stats.literals += 1;
                    pos += 1;
                    continue;
                }
            }

            try tokens.append(allocator, .{ .match = .{
                .length = @intCast(best.length),
                .distance = @intCast(best.distance),
            } });
            stats.matches += 1;
            stats.matched_bytes += best.length;
            const end = @min(block.len, pos + best.length);
            if (lazy) {
                if (!current_inserted) self.insertBlockPosition(history, block, pos, anchor_len);
                // Long matches are already represented by the current anchor.
                // Seed their tail like the fast parser instead of writing every
                // skipped position; lazy quality comes from the one-byte probe,
                // while dense insertion mostly adds memory traffic on runs.
                const tail_start = if (end > pos + 4) end - 4 else pos + 1;
                var insert_pos = @max(pos + 1, tail_start);
                while (insert_pos < end) : (insert_pos += 1)
                    self.insertBlockPosition(history, block, insert_pos, anchor_len);
                pos = end;
            } else {
                self.insertBlockPosition(history, block, pos, anchor_len);
                // Fast and lazy parsing both keep a sparse tail for long
                // matches; lazy additionally inserts before its one-byte probe.
                const tail_start = if (end > pos + 4) end - 4 else pos + 1;
                pos += 1;
                if (pos < tail_start) pos = tail_start;
                while (pos < end) : (pos += 1)
                    self.insertBlockPosition(history, block, pos, anchor_len);
            }
        }
        self.absolute_position = std.math.add(usize, self.absolute_position, block.len) catch return error.IntegerOverflow;
        return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
    }

    fn ensureTables(self: *Matcher, allocator: std.mem.Allocator) !void {
        if (self.head.items.len != 0) return;
        try self.head.resize(allocator, hash_size);
        errdefer self.head.clearAndFree(allocator);
        try self.head_epoch.resize(allocator, hash_size);
        errdefer self.head_epoch.clearAndFree(allocator);
        try self.prev.resize(allocator, lz77.default_window_len);
        @memset(self.head_epoch.items, 0);
    }

    fn seedHistory(self: *Matcher, history: []const u8, block: []const u8, anchor_len: usize, lazy: bool) void {
        self.absolute_position = @max(self.absolute_position, history.len);
        const history_start = self.absolute_position - history.len;
        var absolute = history_start;
        while (absolute + anchor_len <= self.absolute_position + block.len and absolute < self.absolute_position) : (absolute += 1)
            self.insertAbsolute(history, block, absolute, anchor_len);
        self.initialized = true;
        self.anchor_len = @intCast(anchor_len);
        self.lazy_mode = lazy;
    }

    fn seedBoundary(self: *Matcher, history: []const u8, block: []const u8, anchor_len: usize) void {
        if (history.len == 0 or block.len == 0) return;
        const history_start = self.absolute_position - history.len;
        var absolute = @max(history_start, self.absolute_position -| (anchor_len - 1));
        while (absolute < self.absolute_position) : (absolute += 1)
            self.insertAbsolute(history, block, absolute, anchor_len);
    }

    const Candidate = struct { length: usize = 0, distance: usize = 0 };

    fn findBest(self: *const Matcher, history: []const u8, block: []const u8, pos: usize, options: lz77.GreedyOptions, anchor_len: usize) Candidate {
        if (pos + anchor_len > block.len) return .{};
        const current = self.absolute_position + pos;
        const h = hashAt(history, block, self.absolute_position, current, anchor_len);
        if (self.head_epoch.items[h] != self.epoch) return .{};

        var candidate = self.head.items[h];
        var checked: usize = 0;
        var best: Candidate = .{};
        const minimum = @max(@as(usize, 3), @min(options.min_match, @max(@as(usize, 3), @min(options.max_match, lz77.max_match_len))));
        const max_walks = if (minimum <= 3 or options.max_chain > 8) options.max_chain else options.max_chain * 4;
        var walked: usize = 0;
        const maximum = @min(@max(@as(usize, 3), @min(options.max_match, lz77.max_match_len)), block.len - pos);
        while (candidate != invalid_position and checked < options.max_chain and walked < max_walks) : (walked += 1) {
            if (candidate >= current) break;
            const distance = current - candidate;
            if (distance > options.window_len) break;
            const required = @max(best.length, minimum - 1);
            if (byteAt(history, block, self.absolute_position, candidate + required) == block[pos + required]) {
                checked += 1;
                const length = matchLength(history, block, self.absolute_position, candidate, pos, maximum);
                if (length > best.length) {
                    best = .{ .length = length, .distance = distance };
                    if (length >= options.nice_len or length == maximum) break;
                }
            }
            candidate = self.prev.items[candidate & (lz77.default_window_len - 1)];
        }
        return best;
    }

    fn insertBlockPosition(self: *Matcher, history: []const u8, block: []const u8, pos: usize, anchor_len: usize) void {
        self.insertAbsolute(history, block, self.absolute_position + pos, anchor_len);
    }

    fn insertAbsolute(self: *Matcher, history: []const u8, block: []const u8, absolute: usize, anchor_len: usize) void {
        if (absolute + anchor_len > self.absolute_position + block.len) return;
        const h = hashAt(history, block, self.absolute_position, absolute, anchor_len);
        const previous = if (self.head_epoch.items[h] == self.epoch) self.head.items[h] else invalid_position;
        const slot = absolute & (lz77.default_window_len - 1);
        self.prev.items[slot] = previous;
        self.head.items[h] = absolute;
        self.head_epoch.items[h] = self.epoch;
        self.indexed_positions += 1;
    }
};

fn byteAt(history: []const u8, block: []const u8, block_absolute: usize, absolute: usize) u8 {
    const history_absolute = block_absolute - history.len;
    return if (absolute < block_absolute) history[absolute - history_absolute] else block[absolute - block_absolute];
}

fn matchLength(history: []const u8, block: []const u8, block_absolute: usize, candidate: usize, pos: usize, maximum: usize) usize {
    if (candidate >= block_absolute)
        return sliceMatchLength(block, candidate - block_absolute, pos, maximum);

    const history_absolute = block_absolute - history.len;
    const history_pos = candidate - history_absolute;
    const history_part = @min(maximum, history.len - history_pos);
    var length = crossSliceMatchLength(history, history_pos, block, pos, history_part);
    if (length != history_part or length == maximum) return length;

    // A legal DEFLATE match can overlap the bytes currently being encoded.
    // Once a source that began in history crosses the block boundary, continue
    // from block offset zero just like the decoder's forward match copy.
    length += sliceMatchLength(block, 0, pos + length, maximum - length);
    return length;
}

fn sliceMatchLength(input: []const u8, left_pos: usize, right_pos: usize, maximum: usize) usize {
    return crossSliceMatchLength(input, left_pos, input, right_pos, maximum);
}

fn crossSliceMatchLength(left: []const u8, left_pos: usize, right: []const u8, right_pos: usize, maximum: usize) usize {
    var length: usize = 0;
    while (length + 8 <= maximum) : (length += 8) {
        const a = std.mem.readInt(u64, left[left_pos + length ..][0..8], .little);
        const b = std.mem.readInt(u64, right[right_pos + length ..][0..8], .little);
        if (a != b) return length + @ctz(a ^ b) / 8;
    }
    while (length < maximum and left[left_pos + length] == right[right_pos + length]) : (length += 1) {}
    return length;
}

fn hashAt(history: []const u8, block: []const u8, block_absolute: usize, absolute: usize, anchor_len: usize) usize {
    var bytes: [4]u8 = undefined;
    for (0..anchor_len) |i| bytes[i] = byteAt(history, block, block_absolute, absolute + i);
    return hashBytes(&bytes, anchor_len);
}

fn hashBytes(bytes: *const [4]u8, anchor_len: usize) usize {
    if (anchor_len == 4) {
        const word = std.mem.readInt(u32, bytes, .little);
        return (word *% 2654435761) >> (32 - hash_bits);
    }
    const value: usize = (@as(usize, bytes[0]) << 16) | (@as(usize, bytes[1]) << 8) | bytes[2];
    return ((value *% 2654435761) >> 16) & (hash_size - 1);
}

fn acceptMatch(input: []const u8, pos: usize, length: usize, distance: usize, options: lz77.GreedyOptions) bool {
    const minimum = @max(@as(usize, 3), @min(options.min_match, @max(@as(usize, 3), @min(options.max_match, lz77.max_match_len))));
    if (length < minimum or distance == 0 or distance > lz77.default_window_len) return false;
    const literal_bits = blk: {
        var bits = length * 8;
        for (input[pos..][0..length]) |byte| bits += @intFromBool(byte > 143);
        break :blk bits;
    };
    return literal_bits >= fixedMatchBits(length, distance) + options.min_savings_bits;
}

fn fixedMatchBits(length: usize, distance: usize) usize {
    const length_bits: usize = if (length <= 10) 7 else if (length <= 18) 8 else if (length <= 34) 9 else if (length <= 66) 10 else if (length <= 130) 11 else if (length <= 257) 12 else 8;
    const distance_extra: usize = if (distance <= 4) 0 else std.math.log2_int(usize, distance - 1) - 1;
    return length_bits + 5 + distance_extra;
}
