//! Complete transformed dictionary tuples for the opt-in HQ parser.
const std = @import("std");
const dictionary = @import("../static_dictionary.zig");

const bucket_bits = 15;
const bucket_count = 1 << bucket_bits;
const row_len = bucket_count + 1;
const head_count = 4 * row_len;
const word_index_bits = 11;
const word_index_mask = (@as(u32, 1) << word_index_bits) - 1;

const candidate_count = blk: {
    @setEvalBranchQuota(100_000);
    var count: usize = 0;
    for (4..25) |copy_len| {
        const words = @as(usize, 1) << dictionary.sizeBits(copy_len).?;
        for (0..dictionary.transform_count) |transform_index| {
            const metadata = dictionary.transformMetadata(transform_index).?;
            const after_first = copy_len - @min(copy_len, metadata.omit_first);
            const retained = after_first -| metadata.omit_last;
            if (metadata.prefix_len + retained + metadata.suffix_len != 0)
                count += words;
        }
    }
    break :blk count;
};

/// Each word/transform coordinate is indexed once. Equal spellings are never
/// merged: their raw copy length and wire address can have different costs.
/// Four anchor widths retain all positive one-, two-, and three-byte outputs.
pub const Index = struct {
    allocator: std.mem.Allocator,
    heads: []u32,
    words: []u32,

    /// Exact peak requested heap: retained heads/tuples plus construction
    /// cursors. Querying uses only caller-owned visitor storage and stack data.
    pub fn requiredWorkingMemory() usize {
        return 2 * head_count * @sizeOf(u32) + candidate_count * @sizeOf(u32);
    }

    pub fn init(allocator: std.mem.Allocator, max_working_memory: usize) !Index {
        if (requiredWorkingMemory() > max_working_memory)
            return error.WorkingMemoryLimitExceeded;
        const heads = try allocator.alloc(u32, head_count);
        errdefer allocator.free(heads);
        @memset(heads, 0);
        var scratch: [64]u8 = undefined;
        for (4..25) |copy_len| {
            const count = @as(usize, 1) << dictionary.sizeBits(copy_len).?;
            for (0..dictionary.transform_count) |transform_index| {
                for (0..count) |word_index| {
                    const word = dictionary.baseWord(copy_len, word_index).?;
                    const output = dictionary.transformWord(transform_index, word, &scratch).?;
                    if (output.len == 0) continue;
                    const width: usize = @min(output.len, 4);
                    heads[(width - 1) * row_len + hashAnchor(output, width) + 1] += 1;
                }
            }
        }
        var running: u32 = 0;
        for (0..4) |row| {
            const offsets = heads[row * row_len ..][0..row_len];
            for (0..bucket_count) |bucket| {
                const count = offsets[bucket + 1];
                offsets[bucket] = running;
                running += count;
            }
            offsets[bucket_count] = running;
        }
        std.debug.assert(running == candidate_count);
        const words = try allocator.alloc(u32, candidate_count);
        errdefer allocator.free(words);
        const cursors = try allocator.dupe(u32, heads);
        defer allocator.free(cursors);
        for (4..25) |copy_len| {
            const count = @as(usize, 1) << dictionary.sizeBits(copy_len).?;
            for (0..dictionary.transform_count) |transform_index| {
                for (0..count) |word_index| {
                    const word = dictionary.baseWord(copy_len, word_index).?;
                    const output = dictionary.transformWord(transform_index, word, &scratch).?;
                    if (output.len == 0) continue;
                    const width: usize = @min(output.len, 4);
                    const offset = (width - 1) * row_len + hashAnchor(output, width);
                    const slot = cursors[offset];
                    words[slot] = @as(u32, @intCast(word_index)) |
                        (@as(u32, @intCast(copy_len - 4)) << word_index_bits) |
                        (@as(u32, @intCast(transform_index)) << 16);
                    cursors[offset] += 1;
                }
            }
        }
        for (0..4) |row| {
            const base = row * row_len;
            for (cursors[base..][0..bucket_count], heads[base + 1 ..][0..bucket_count]) |actual, expected|
                std.debug.assert(actual == expected);
        }
        return .{ .allocator = allocator, .heads = heads, .words = words };
    }

    pub fn deinit(self: *Index) void {
        self.allocator.free(self.words);
        self.allocator.free(self.heads);
        self.* = undefined;
    }

    pub fn byteSize(self: *const Index) usize {
        return self.heads.len * @sizeOf(u32) + self.words.len * @sizeOf(u32);
    }

    pub fn entryCount(self: *const Index) usize {
        return self.words.len;
    }

    /// Visit every positive matching tuple in deterministic anchor-width and
    /// source-coordinate order. `visitor.visit(Match) !bool` returns false to
    /// stop; errors propagate without allocating or changing this index.
    pub fn visitMatches(self: *const Index, input: []const u8, visitor: anytype) !void {
        return self.visitMatchesAtLeast(input, 1, visitor);
    }

    pub fn visitMatchesAtLeast(self: *const Index, input: []const u8, minimum_output_len: usize, visitor: anytype) !void {
        const minimum = @max(1, minimum_output_len);
        if (input.len < minimum) return;
        const first_width: usize = @min(minimum, 4);
        for (first_width..@min(input.len, 4) + 1) |width| {
            const offsets = self.heads[(width - 1) * row_len ..][0..row_len];
            const bucket = hashAnchor(input, width);
            for (self.words[offsets[bucket]..offsets[bucket + 1]]) |encoded_word| {
                const word_index = encoded_word & word_index_mask;
                const copy_len = 4 + ((encoded_word >> word_index_bits) & 31);
                const transform_index = encoded_word >> 16;
                const word = dictionary.baseWord(copy_len, word_index).?;
                const output_len = dictionary.transformedWordMatches(transform_index, word, input) orelse continue;
                if (output_len < minimum) continue;
                const bits = dictionary.sizeBits(copy_len).?;
                const match = dictionary.Match{
                    .address = (@as(usize, transform_index) << bits) | word_index,
                    .copy_len = @intCast(copy_len),
                    .output_len = @intCast(output_len),
                };
                if (!try visitor.visit(match)) return;
            }
        }
    }
};

fn hashAnchor(bytes: []const u8, width: usize) usize {
    var anchor: [4]u8 = @splat(0);
    @memcpy(anchor[0..width], bytes[0..width]);
    const value = std.mem.readInt(u32, &anchor, .little);
    return (value *% 0x1e35_a7bd) >> (32 - bucket_bits);
}
