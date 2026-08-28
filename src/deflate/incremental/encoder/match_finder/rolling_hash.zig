const std = @import("std");
const lz77 = @import("../../../../lz77.zig");
const hash = @import("hash.zig");
const profitability = @import("profitability.zig");
const dynamic_stats = @import("dynamic_stats.zig");

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
    // The returned plan borrows this histogram until the next plan/reset.
    // Keeping it with the matcher avoids copying its 316 counters through the
    // encoder call chain for every block.
    dynamic_stats: dynamic_stats.Stats = .{},
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
        self.dynamic_stats.reset();
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

    pub fn plan(
        self: *Matcher,
        allocator: std.mem.Allocator,
        tokens: *std.ArrayList(lz77.Token),
        block: []const u8,
        history: []const u8,
        options: lz77.GreedyOptions,
        lazy: bool,
    ) !struct { tokens: []const lz77.Token, stats: lz77.PlanStats, dynamic: *const dynamic_stats.Stats } {
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

        tokens.clearRetainingCapacity();
        try tokens.ensureTotalCapacity(allocator, @min(block.len, 4096));
        var stats: lz77.PlanStats = .{};
        self.dynamic_stats.reset();
        // These bounds depend only on the block's options. Hoist their nested
        // clamps out of both the current-position and lazy-probe searches; on
        // source-like input those searches run for nearly every token.
        const minimum = @max(@as(usize, 3), @min(options.min_match, @max(@as(usize, 3), @min(options.max_match, lz77.max_match_len))));
        const maximum_match = @max(@as(usize, 3), @min(options.max_match, lz77.max_match_len));
        const max_walks = if (minimum <= 3 or options.max_chain > 8) options.max_chain else options.max_chain * 4;

        var pos: usize = 0;
        while (pos < block.len) {
            const best = self.findBest(history, block, pos, options, anchor_len, minimum, maximum_match, max_walks);
            if (!acceptMatch(block, pos, best.length, best.distance, options, minimum)) {
                try appendToken(tokens, allocator, .{ .literal = block[pos] });
                stats.literals += 1;
                self.dynamic_stats.recordLiteral(block[pos]);
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
                const next = self.findBest(history, block, pos + 1, options, anchor_len, minimum, maximum_match, max_walks);
                if (next.length >= best.length + options.lazy_min_gain and
                    acceptMatch(block, pos + 1, next.length, next.distance, options, minimum))
                {
                    try appendToken(tokens, allocator, .{ .literal = block[pos] });
                    stats.literals += 1;
                    self.dynamic_stats.recordLiteral(block[pos]);
                    pos += 1;
                    continue;
                }
            }

            try appendToken(tokens, allocator, .{ .match = .{
                .length = @intCast(best.length),
                .distance = @intCast(best.distance),
            } });
            stats.matches += 1;
            stats.matched_bytes += best.length;
            self.dynamic_stats.recordMatch(.{ .length = @intCast(best.length), .distance = @intCast(best.distance) });
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
        return .{ .tokens = tokens.items, .stats = stats, .dynamic = &self.dynamic_stats };
    }

    fn ensureTables(self: *Matcher, allocator: std.mem.Allocator) !void {
        if (self.head.items.len != 0) return;
        try self.head.resize(allocator, hash.size);
        errdefer self.head.clearAndFree(allocator);
        try self.head_epoch.resize(allocator, hash.size);
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

    fn findBest(
        self: *const Matcher,
        history: []const u8,
        block: []const u8,
        pos: usize,
        options: lz77.GreedyOptions,
        anchor_len: usize,
        minimum: usize,
        maximum_match: usize,
        max_walks: usize,
    ) Candidate {
        if (pos + anchor_len > block.len) return .{};
        const current = self.absolute_position + pos;
        const h = hash.block(block, pos, anchor_len);
        if (self.head_epoch.items[h] != self.epoch) return .{};

        var candidate = self.head.items[h];
        const history_chain = candidate < self.absolute_position;
        var checked: usize = 0;
        var best: Candidate = .{};
        var walked: usize = 0;
        const maximum = @min(maximum_match, block.len - pos);
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
            const next_candidate = self.prev.items[candidate & (lz77.default_window_len - 1)];
            if (history_chain and next_candidate != invalid_position and next_candidate < self.absolute_position) {
                const history_pos = next_candidate - (self.absolute_position - history.len);
                @prefetch(history.ptr + history_pos, .{ .locality = 1 });
            }
            candidate = next_candidate;
        }
        return best;
    }

    fn insertBlockPosition(self: *Matcher, history: []const u8, block: []const u8, pos: usize, anchor_len: usize) void {
        _ = history;
        if (pos + anchor_len > block.len) return;
        self.insertKnown(self.absolute_position + pos, hash.block(block, pos, anchor_len));
    }

    fn insertAbsolute(self: *Matcher, history: []const u8, block: []const u8, absolute: usize, anchor_len: usize) void {
        if (absolute + anchor_len > self.absolute_position + block.len) return;
        const h = hashAt(history, block, self.absolute_position, absolute, anchor_len);
        self.insertKnown(absolute, h);
    }

    fn insertKnown(self: *Matcher, absolute: usize, h: usize) void {
        const previous = if (self.head_epoch.items[h] == self.epoch) self.head.items[h] else invalid_position;
        const slot = absolute & (lz77.default_window_len - 1);
        self.prev.items[slot] = previous;
        self.head.items[h] = absolute;
        self.head_epoch.items[h] = self.epoch;
        self.indexed_positions += 1;
    }
};

inline fn appendToken(tokens: *std.ArrayList(lz77.Token), allocator: std.mem.Allocator, token: lz77.Token) !void {
    if (tokens.items.len < tokens.capacity) {
        tokens.appendAssumeCapacity(token);
    } else {
        try tokens.append(allocator, token);
    }
}

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
    // Long source/history matches dominate the persistent parser. Compare four
    // words at once, then use the lane mask to retain the exact first-mismatch
    // result before falling through to the existing word and byte tails.
    while (length + 32 <= maximum) : (length += 32) {
        const a: @Vector(32, u8) = left[left_pos + length ..][0..32].*;
        const b: @Vector(32, u8) = right[right_pos + length ..][0..32].*;
        const differing: u32 = ~@as(u32, @bitCast(a == b));
        if (differing != 0) return length + @ctz(differing);
    }
    while (length + 8 <= maximum) : (length += 8) {
        const a = std.mem.readInt(u64, left[left_pos + length ..][0..8], .little);
        const b = std.mem.readInt(u64, right[right_pos + length ..][0..8], .little);
        if (a != b) return length + @ctz(a ^ b) / 8;
    }
    while (length < maximum and left[left_pos + length] == right[right_pos + length]) : (length += 1) {}
    return length;
}

test "rolling match length vector path matches byte reference" {
    var left: [337]u8 = undefined;
    var right: [345]u8 = undefined;
    for (&left, 0..) |*byte, i| byte.* = @truncate(i * 37 + i / 11);
    for (&right, 0..) |*byte, i| byte.* = @truncate((i -| 8) * 37 + (i -| 8) / 11);
    const maximum: usize = 321;
    for (0..maximum) |mismatch| {
        right[8 + mismatch] +%= 1;
        try std.testing.expectEqual(mismatch, crossSliceMatchLength(&left, 0, &right, 8, maximum));
        right[8 + mismatch] = left[mismatch];
    }
    // Exercise every boundary around both the vector and scalar tail widths.
    for (0..maximum + 1) |limit|
        try std.testing.expectEqual(limit, crossSliceMatchLength(&left, 0, &right, 8, limit));
}

test "rolling matcher reuses and resets borrowed dynamic stats" {
    var matcher: Matcher = .{};
    defer matcher.deinit(std.testing.allocator);
    var tokens: std.ArrayList(lz77.Token) = .empty;
    defer tokens.deinit(std.testing.allocator);

    const first = try matcher.plan(std.testing.allocator, &tokens, "abcdef", "", .{}, true);
    const stats_address = first.dynamic;
    var first_literals: u32 = 0;
    for (first.dynamic.literal_frequencies) |frequency| first_literals += frequency;
    try std.testing.expectEqual(@as(u32, 6), first_literals);

    matcher.reset();
    try std.testing.expectEqual(@as(usize, 0), matcher.dynamic_stats.literalActiveCount());
    try std.testing.expectEqual(@as(usize, 0), matcher.dynamic_stats.distanceActiveCount());
    const second = try matcher.plan(std.testing.allocator, &tokens, "x", "", .{}, true);
    try std.testing.expectEqual(stats_address, second.dynamic);
    var second_literals: u32 = 0;
    for (second.dynamic.literal_frequencies) |frequency| second_literals += frequency;
    try std.testing.expectEqual(@as(u32, 1), second_literals);
    try std.testing.expectEqual(@as(u32, 1), second.dynamic.literal_frequencies['x']);
}

fn hashAt(history: []const u8, block: []const u8, block_absolute: usize, absolute: usize, anchor_len: usize) usize {
    if (absolute >= block_absolute) return hash.block(block, absolute - block_absolute, anchor_len);
    const history_absolute = block_absolute - history.len;
    return hash.joined(history, block, absolute - history_absolute, anchor_len);
}

fn acceptMatch(input: []const u8, pos: usize, length: usize, distance: usize, options: lz77.GreedyOptions, minimum: usize) bool {
    return profitability.accept(input, pos, length, distance, minimum, lz77.default_window_len, options.min_savings_bits);
}
