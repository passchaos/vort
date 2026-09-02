const std = @import("std");
const static_dictionary = @import("../static_dictionary.zig");

const bucket_bits = 15;
const bucket_count = 1 << bucket_bits;
const no_entry = std.math.maxInt(u16);
const word_index_bits = 11;
const word_index_mask = (@as(u32, 1) << word_index_bits) - 1;
const BaseWord = struct { word_index: usize, copy_len: usize };
const PrefixGroup = struct {
    transforms: [3][static_dictionary.transform_count]u8 = @splat(@splat(std.math.maxInt(u8))),
    lengths: [3]u8 = @splat(0),
};

const transforms_by_prefix = blk: {
    // findLongest probes the only prefix widths present in RFC 7932. Grouping
    // once at compile time avoids running transforms whose prefix can never
    // match the current input position.
    var result: [6]PrefixGroup = @splat(.{});
    for (0..static_dictionary.transform_count) |transform_index| {
        const prefix_len = static_dictionary.transformPrefixLength(transform_index).?;
        const case_index = @intFromEnum(static_dictionary.transformMetadata(transform_index).?.case_kind);
        result[prefix_len].transforms[case_index][result[prefix_len].lengths[case_index]] = transform_index;
        result[prefix_len].lengths[case_index] += 1;
    }
    break :blk result;
};

/// Compact index over the 13,504 untransformed dictionary words. Matches are
/// verified by the independent transform implementation, so all 121 standard
/// transforms remain supported without materializing ~1.6 million entries.
pub const Index = struct {
    allocator: std.mem.Allocator,
    heads: []u16,
    next: []u16,
    words: []u32,

    var shared: ?Index = null;
    var shared_lock: std.atomic.Mutex = .unlocked;
    var shared_ready: std.atomic.Value(bool) = .init(false);

    pub fn init(allocator: std.mem.Allocator) !Index {
        const heads = try allocator.alloc(u16, bucket_count);
        errdefer allocator.free(heads);
        @memset(heads, no_entry);
        const next = try allocator.alloc(u16, static_dictionary.base_word_count);
        errdefer allocator.free(next);
        const words = try allocator.alloc(u32, static_dictionary.base_word_count);
        errdefer allocator.free(words);

        var entry_count: usize = 0;
        for (4..25) |copy_len| {
            const bits = static_dictionary.sizeBits(copy_len) orelse continue;
            const word_count = @as(usize, 1) << bits;
            for (0..word_count) |word_index| {
                const word = static_dictionary.baseWord(copy_len, word_index).?;
                const bucket = hashPrefix(word);
                next[entry_count] = heads[bucket];
                words[entry_count] = packBaseWord(word_index, copy_len);
                heads[bucket] = @intCast(entry_count);
                entry_count += 1;
            }
        }
        std.debug.assert(entry_count == static_dictionary.base_word_count);
        return .{ .allocator = allocator, .heads = heads, .next = next, .words = words };
    }

    pub fn deinit(self: *Index) void {
        self.allocator.free(self.heads);
        self.allocator.free(self.next);
        self.allocator.free(self.words);
        self.* = undefined;
    }

    pub fn sharedIndex() !*const Index {
        if (shared_ready.load(.acquire)) return &shared.?;
        // The RFC dictionary is immutable, so one process-wide index avoids a
        // 146 KiB rebuild on every short ratio encode. Only the first caller
        // takes the lock; release/acquire publication makes steady-state access
        // lock-free while allowing a failed allocation to be retried.
        while (!shared_lock.tryLock()) std.atomic.spinLoopHint();
        defer shared_lock.unlock();
        if (!shared_ready.load(.monotonic)) {
            shared = try Index.init(std.heap.smp_allocator);
            shared_ready.store(true, .release);
        }
        return &shared.?;
    }

    pub fn findLongest(self: *const Index, input: []const u8) ?static_dictionary.Match {
        if (input.len < 4) return null;
        var best: ?static_dictionary.Match = null;
        findCandidates(self, input, 0, &best);
        if (input[0] == ' ' or input[0] == '.') findCandidates(self, input, 1, &best);
        if (input.len >= 6 and ((input[1] == ' ' and (input[0] == 'e' or input[0] == 's' or input[0] == ',')) or
            (input[0] == 0xc2 and input[1] == 0xa0)))
            findCandidates(self, input, 2, &best);
        if (input.len >= 9 and (std.mem.startsWith(u8, input, " the ") or std.mem.startsWith(u8, input, ".com/")))
            findCandidates(self, input, 5, &best);
        return best;
    }

    fn findCandidates(self: *const Index, input: []const u8, prefix_len: usize, best: *?static_dictionary.Match) void {
        if (input.len - prefix_len < 4) return;
        self.findCandidatesForCase(input, prefix_len, .none, input[prefix_len..], best);
        var normalized: [4]u8 = input[prefix_len..][0..4].*;
        if (normalizeUppercasePrefix(&normalized, false))
            self.findCandidatesForCase(input, prefix_len, .first, &normalized, best);
        normalized = input[prefix_len..][0..4].*;
        if (normalizeUppercasePrefix(&normalized, true))
            self.findCandidatesForCase(input, prefix_len, .all, &normalized, best);
    }

    fn findCandidatesForCase(self: *const Index, input: []const u8, prefix_len: usize, case_kind: static_dictionary.TransformCaseKind, hash_bytes: []const u8, best: *?static_dictionary.Match) void {
        var entry = self.heads[hashPrefix(hash_bytes)];
        while (entry != no_entry) : (entry = self.next[entry]) {
            const base = unpackBaseWord(self.words[entry]);
            const bits = static_dictionary.sizeBits(base.copy_len).?;
            const word = static_dictionary.baseWord(base.copy_len, base.word_index).?;
            const group = &transforms_by_prefix[prefix_len];
            const case_index = @intFromEnum(case_kind);
            for (group.transforms[case_index][0..group.lengths[case_index]]) |transform_index| {
                const address = (@as(usize, transform_index) << bits) | base.word_index;
                // Most transforms differ only by suffix. When the complete
                // base word fits in the remaining input, reject an incompatible
                // first suffix byte before copying the transformed candidate.
                const metadata = static_dictionary.transformMetadata(transform_index).?;
                if (metadata.keeps_whole_word) {
                    const suffix_offset = prefix_len + base.copy_len;
                    if (suffix_offset + metadata.suffix_len > input.len) continue;
                    if (!static_dictionary.transformSuffixMatches(metadata, input[suffix_offset..])) continue;
                }
                const output_len = static_dictionary.transformedWordMatches(transform_index, word, input) orelse continue;
                // RFC transforms may omit the complete base word. Those zero-
                // length results cannot advance the planner and would otherwise
                // create an infinite sequence of dictionary commands.
                if (output_len < 4) continue;
                if (best.* == null or output_len > best.*.?.output_len or
                    (output_len == best.*.?.output_len and address < best.*.?.address))
                {
                    best.* = .{ .output_len = @intCast(output_len), .copy_len = @intCast(base.copy_len), .address = address };
                }
            }
        }
    }

    pub fn entryCount(self: *const Index) usize {
        return self.words.len;
    }
};

fn normalizeUppercasePrefix(bytes: *[4]u8, all: bool) bool {
    var changed = false;
    for (bytes, 0..) |*byte, index| {
        if (byte.* >= 'A' and byte.* <= 'Z') {
            byte.* |= 32;
            changed = true;
        }
        if (!all and index == 0) break;
    }
    return changed;
}

pub const max_index_bytes = bucket_count * @sizeOf(u16) +
    static_dictionary.base_word_count * (@sizeOf(u16) + @sizeOf(u32));

fn hashPrefix(bytes: []const u8) usize {
    const word = std.mem.readInt(u32, bytes[0..4], .little);
    return (word *% 0x1e35a7bd) >> (32 - bucket_bits);
}

fn packBaseWord(word_index: usize, copy_len: usize) u32 {
    std.debug.assert(word_index <= word_index_mask);
    return @as(u32, @intCast(word_index)) | (@as(u32, @intCast(copy_len - 4)) << word_index_bits);
}

fn unpackBaseWord(encoded: u32) BaseWord {
    return .{ .word_index = encoded & word_index_mask, .copy_len = 4 + (encoded >> word_index_bits) };
}

test "indexed static dictionary matcher agrees with exhaustive reference" {
    var index = try Index.init(std.testing.allocator);
    defer index.deinit();
    try std.testing.expectEqual(static_dictionary.base_word_count, index.entryCount());

    const cases = [_][]const u8{
        " information follows",
        "Dictionary entry",
        "english. next",
        " the world of compression",
        "not-a-dictionary-candidate",
    };
    for (cases) |input| {
        const expected = static_dictionary.findLongestMatch(input);
        const actual = index.findLongest(input);
        try std.testing.expectEqual(expected, actual);
    }
}

test "indexed static dictionary matcher ignores non-advancing omit transforms" {
    var index = try Index.init(std.testing.allocator);
    defer index.deinit();

    const match = index.findLongest("on\",");
    try std.testing.expect(match == null or match.?.output_len >= 4);
}

test "indexed static dictionary matcher finds uppercase transforms without a second index" {
    var index = try Index.init(std.testing.allocator);
    defer index.deinit();
    const cases = [_][]const u8{
        "Information",
        "INFORMATION",
        " DICTIONARY",
        "COMPRESSION",
    };
    for (cases) |input| {
        const expected = static_dictionary.findLongestMatch(input);
        const actual = index.findLongest(input);
        try std.testing.expectEqual(expected, actual);
        try std.testing.expect(actual != null);
    }
}

test "shared static dictionary index is safe under concurrent first access" {
    const Worker = struct {
        ok: bool = false,

        fn run(self: *@This()) void {
            const index = Index.sharedIndex() catch return;
            const match = index.findLongest("Information") orelse return;
            self.ok = match.output_len == "Information".len;
        }
    };
    var workers: [8]Worker = @splat(.{});
    var threads: [workers.len]std.Thread = undefined;
    for (&threads, &workers) |*thread, *worker|
        thread.* = try std.Thread.spawn(.{}, Worker.run, .{worker});
    for (threads) |thread| thread.join();
    for (workers) |worker| try std.testing.expect(worker.ok);
}
