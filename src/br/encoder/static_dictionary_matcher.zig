const std = @import("std");
const static_dictionary = @import("../static_dictionary.zig");

const bucket_bits = 15;
const bucket_count = 1 << bucket_bits;
const no_entry = std.math.maxInt(u16);
const word_index_bits = 11;
const word_index_mask = (@as(u32, 1) << word_index_bits) - 1;
const BaseWord = struct { word_index: usize, copy_len: usize };
const PrefixGroup = struct {
    transforms: [static_dictionary.transform_count]u8 = @splat(std.math.maxInt(u8)),
    len: u8 = 0,
};

const transforms_by_prefix = blk: {
    // findLongest probes the only prefix widths present in RFC 7932. Grouping
    // once at compile time avoids running transforms whose prefix can never
    // match the current input position.
    var result: [6]PrefixGroup = @splat(.{});
    for (0..static_dictionary.transform_count) |transform_index| {
        const prefix_len = static_dictionary.transformPrefixLength(transform_index).?;
        result[prefix_len].transforms[result[prefix_len].len] = transform_index;
        result[prefix_len].len += 1;
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
        // The RFC dictionary is immutable, so one process-wide index avoids a
        // 146 KiB rebuild on every short ratio encode. Initialization remains
        // serialized; the lock also makes publication safe, and matching after
        // return only reads the index.
        while (!shared_lock.tryLock()) std.atomic.spinLoopHint();
        defer shared_lock.unlock();
        if (shared == null) shared = try Index.init(std.heap.smp_allocator);
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
        var scratch: [64]u8 = undefined;
        var entry = self.heads[hashPrefix(input[prefix_len..])];
        while (entry != no_entry) : (entry = self.next[entry]) {
            const base = unpackBaseWord(self.words[entry]);
            const bits = static_dictionary.sizeBits(base.copy_len).?;
            const word = static_dictionary.baseWord(base.copy_len, base.word_index).?;
            const group = &transforms_by_prefix[prefix_len];
            for (group.transforms[0..group.len]) |transform_index| {
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
                const transformed = static_dictionary.transformWord(transform_index, word, &scratch) orelse continue;
                // RFC transforms may omit the complete base word. Those zero-
                // length results cannot advance the planner and would otherwise
                // create an infinite sequence of dictionary commands.
                if (transformed.len < 4) continue;
                if (transformed.len > input.len or !std.mem.eql(u8, transformed, input[0..transformed.len])) continue;
                if (best.* == null or transformed.len > best.*.?.output_len or
                    (transformed.len == best.*.?.output_len and address < best.*.?.address))
                {
                    best.* = .{ .output_len = @intCast(transformed.len), .copy_len = @intCast(base.copy_len), .address = address };
                }
            }
        }
    }

    pub fn entryCount(self: *const Index) usize {
        return self.words.len;
    }
};

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
