const std = @import("std");
const allocator_dispatch = @import("../allocator_dispatch.zig");
const builtin = @import("builtin");
const static_dictionary = @import("../static_dictionary.zig");

/// Complete, caller-owned HQ candidate tuples, including spelling aliases.
/// The legacy compact and supplemental longest-match indexes remain separate.
pub const CandidateIndex = @import("static_dictionary_candidates.zig").Index;

test {
    _ = @import("dictionary_visitor_tests.zig");
}

const index_build_text_section = switch (builtin.object_format) {
    .elf => ".vort_br_dictionary_index",
    .macho => "__TEXT,__vort_br_dict",
    .coff => ".text$vort_br_dictionary_index",
    else => ".text",
};

const bucket_bits = 15;
const bucket_count = 1 << bucket_bits;
const no_entry = std.math.maxInt(u16);
const word_index_bits = 11;
const word_index_mask = (@as(u32, 1) << word_index_bits) - 1;
const BaseWord = struct { word_index: usize, copy_len: usize };
const IndexedWord = struct { word_index: usize, copy_len: usize, case_kind: static_dictionary.TransformCaseKind };
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

const canonical_case_transforms = [_]u8{ 0, 9, 44 };

comptime {
    for (canonical_case_transforms, 0..) |transform_index, case_index| {
        const metadata = static_dictionary.transformMetadata(transform_index).?;
        std.debug.assert(metadata.keeps_whole_word and metadata.prefix_len == 0 and metadata.suffix_len == 0);
        std.debug.assert(@intFromEnum(metadata.case_kind) == case_index);
    }
}

const max_indexed_word_count = static_dictionary.base_word_count * canonical_case_transforms.len;

/// Upstream-style compact index over 31,704 unique identity, uppercase-first,
/// and uppercase-all dictionary spellings. Candidate transforms are verified
/// by the independent transform implementation without materializing roughly
/// 1.6 million transformed words.
pub const Index = struct {
    allocator: std.mem.Allocator,
    heads: []u16,
    words: []u32,

    var shared: ?Index = null;
    var shared_lock: std.atomic.Mutex = .unlocked;
    var shared_ready: std.atomic.Value(bool) = .init(false);

    pub noinline fn init(allocator: std.mem.Allocator) linksection(index_build_text_section) !Index {
        const heads = try allocator.alloc(u16, bucket_count + 1);
        errdefer allocator.free(heads);
        @memset(heads, 0);
        const dedup_heads = try allocator.alloc(u16, bucket_count);
        defer allocator.free(dedup_heads);
        @memset(dedup_heads, no_entry);
        var staged: std.ArrayList(u32) = .empty;
        defer staged.deinit(allocator);
        try staged.ensureTotalCapacity(allocator, max_indexed_word_count);
        var dedup_next: std.ArrayList(u16) = .empty;
        defer dedup_next.deinit(allocator);
        try dedup_next.ensureTotalCapacity(allocator, max_indexed_word_count);
        var transformed_storage: [64]u8 = undefined;
        var duplicate_storage: [64]u8 = undefined;
        var case_counts: [3]usize = @splat(0);
        for (4..25) |copy_len| {
            const bits = static_dictionary.sizeBits(copy_len).?;
            const word_count = @as(usize, 1) << bits;
            // Upstream inserts every identity spelling before the two uppercase
            // families. Preserve that order so an uppercase spelling already
            // present as a later base word is deduplicated in favor of the
            // smaller identity address.
            for (canonical_case_transforms, 0..) |transform_index, case_index| {
                for (0..word_count) |word_index| {
                    const word = static_dictionary.baseWord(copy_len, word_index).?;
                    if (!canonicalCaseEligible(word, @enumFromInt(case_index))) continue;
                    const transformed = static_dictionary.transformWord(transform_index, word, &transformed_storage).?;
                    const bucket = hashPrefix(transformed);
                    if (case_index != 0 and containsEarlierCanonicalWord(staged.items, dedup_next.items, dedup_heads[bucket], transformed, &duplicate_storage)) continue;
                    std.debug.assert(staged.items.len < no_entry);
                    try dedup_next.append(allocator, dedup_heads[bucket]);
                    try staged.append(allocator, packIndexedWord(word_index, copy_len, @enumFromInt(case_index)));
                    dedup_heads[bucket] = @intCast(staged.items.len - 1);
                    heads[bucket + 1] += 1;
                    case_counts[case_index] += 1;
                }
            }
        }
        std.debug.assert(std.mem.eql(usize, &case_counts, &.{ 13_504, 8_168, 10_032 }));
        std.debug.assert(staged.items.len == 31_704);
        prefixSumOffsets(heads);
        const words = try allocator.alloc(u32, staged.items.len);
        errdefer allocator.free(words);
        const cursors = try allocator.dupe(u16, heads[0..bucket_count]);
        defer allocator.free(cursors);
        for (staged.items) |encoded_word| {
            const candidate = unpackIndexedWord(encoded_word);
            const word = static_dictionary.baseWord(candidate.copy_len, candidate.word_index).?;
            const transformed = static_dictionary.transformWord(canonical_case_transforms[@intFromEnum(candidate.case_kind)], word, &transformed_storage).?;
            const bucket = hashPrefix(transformed);
            const cursor = cursors[bucket];
            if (cursor >= heads[bucket + 1] or cursor >= words.len) return error.InvalidBlockPlan;
            words[cursor] = encoded_word;
            cursors[bucket] += 1;
        }
        for (cursors, heads[1..]) |cursor, expected|
            if (cursor != expected) return error.InvalidBlockPlan;
        return .{ .allocator = allocator, .heads = heads, .words = words };
    }

    pub fn deinit(self: *Index) void {
        self.allocator.free(self.heads);
        self.allocator.free(self.words);
        self.* = undefined;
    }

    pub fn sharedIndex() !*const Index {
        if (shared_ready.load(.acquire)) return &shared.?;
        // The RFC dictionary is immutable, so one process-wide index avoids a
        // roughly 192 KiB rebuild on every short ratio encode. Only the first caller
        // takes the lock; release/acquire publication makes steady-state access
        // lock-free while allowing a failed allocation to be retried.
        while (!shared_lock.tryLock()) std.atomic.spinLoopHint();
        defer shared_lock.unlock();
        if (!shared_ready.load(.monotonic)) {
            shared = try Index.init(allocator_dispatch.singleton);
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
        const bucket = hashPrefix(input[prefix_len..]);
        for (self.words[self.heads[bucket]..self.heads[bucket + 1]]) |encoded_word| {
            const candidate = unpackIndexedWord(encoded_word);
            const base = BaseWord{ .word_index = candidate.word_index, .copy_len = candidate.copy_len };
            const bits = static_dictionary.sizeBits(base.copy_len).?;
            const word = static_dictionary.baseWord(base.copy_len, base.word_index).?;
            const group = &transforms_by_prefix[prefix_len];
            const case_index = @intFromEnum(candidate.case_kind);
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

const CompleteIndexedWord = struct {
    word_index: usize,
    copy_len: usize,
    transform_index: usize,
};

/// Lazy supplemental index for transform shapes that cannot be reached from
/// the compact canonical base-word buckets: omit-first transforms and
/// transforms whose retained core contributes fewer than four hash bytes.
/// Default q0...q11 matching never constructs or queries this table.
pub const CompleteIndex = struct {
    allocator: std.mem.Allocator,
    heads: []u32,
    words: []u32,

    var shared: ?CompleteIndex = null;
    var shared_lock: std.atomic.Mutex = .unlocked;
    var shared_ready: std.atomic.Value(bool) = .init(false);

    pub noinline fn init(allocator: std.mem.Allocator) linksection(index_build_text_section) !CompleteIndex {
        const heads = try allocator.alloc(u32, bucket_count + 1);
        errdefer allocator.free(heads);
        @memset(heads, 0);
        var transformed_storage: [64]u8 = undefined;
        var entry_count: usize = 0;
        for (4..25) |copy_len| {
            const word_count = @as(usize, 1) << static_dictionary.sizeBits(copy_len).?;
            for (0..static_dictionary.transform_count) |transform_index| {
                if (!needsSupplementalTransform(transform_index, copy_len)) continue;
                for (0..word_count) |word_index| {
                    const word = static_dictionary.baseWord(copy_len, word_index).?;
                    const transformed = static_dictionary.transformWord(
                        transform_index,
                        word,
                        &transformed_storage,
                    ).?;
                    if (transformed.len < 4) continue;
                    const bucket = hashPrefix(transformed);
                    heads[bucket + 1] = std.math.add(u32, heads[bucket + 1], 1) catch
                        return error.InvalidBlockPlan;
                    entry_count = std.math.add(usize, entry_count, 1) catch
                        return error.IntegerOverflow;
                }
            }
        }
        prefixSumOffsetsU32(heads);
        const words = try allocator.alloc(u32, entry_count);
        errdefer allocator.free(words);
        const cursors = try allocator.dupe(u32, heads[0..bucket_count]);
        defer allocator.free(cursors);
        for (4..25) |copy_len| {
            const word_count = @as(usize, 1) << static_dictionary.sizeBits(copy_len).?;
            for (0..static_dictionary.transform_count) |transform_index| {
                if (!needsSupplementalTransform(transform_index, copy_len)) continue;
                for (0..word_count) |word_index| {
                    const word = static_dictionary.baseWord(copy_len, word_index).?;
                    const transformed = static_dictionary.transformWord(
                        transform_index,
                        word,
                        &transformed_storage,
                    ).?;
                    if (transformed.len < 4) continue;
                    const bucket = hashPrefix(transformed);
                    const cursor = cursors[bucket];
                    if (cursor >= heads[bucket + 1] or cursor >= words.len)
                        return error.InvalidBlockPlan;
                    words[cursor] = packCompleteIndexedWord(
                        word_index,
                        copy_len,
                        transform_index,
                    );
                    cursors[bucket] += 1;
                }
            }
        }
        for (cursors, heads[1..]) |cursor, expected|
            if (cursor != expected) return error.InvalidBlockPlan;
        return .{ .allocator = allocator, .heads = heads, .words = words };
    }

    pub fn deinit(self: *CompleteIndex) void {
        self.allocator.free(self.heads);
        self.allocator.free(self.words);
        self.* = undefined;
    }

    pub fn sharedIndex() !*const CompleteIndex {
        if (shared_ready.load(.acquire)) return &shared.?;
        while (!shared_lock.tryLock()) std.atomic.spinLoopHint();
        defer shared_lock.unlock();
        if (!shared_ready.load(.monotonic)) {
            shared = try CompleteIndex.init(allocator_dispatch.singleton);
            shared_ready.store(true, .release);
        }
        return &shared.?;
    }

    pub fn findLongest(
        self: *const CompleteIndex,
        compact: *const Index,
        input: []const u8,
    ) ?static_dictionary.Match {
        var best = compact.findLongest(input);
        if (input.len < 4) return best;
        const bucket = hashPrefix(input);
        for (self.words[self.heads[bucket]..self.heads[bucket + 1]]) |encoded_word| {
            const candidate = unpackCompleteIndexedWord(encoded_word);
            const word = static_dictionary.baseWord(
                candidate.copy_len,
                candidate.word_index,
            ).?;
            const output_len = static_dictionary.transformedWordMatches(
                candidate.transform_index,
                word,
                input,
            ) orelse continue;
            if (output_len < 4) continue;
            const bits = static_dictionary.sizeBits(candidate.copy_len).?;
            const address = (candidate.transform_index << bits) |
                candidate.word_index;
            if (best == null or output_len > best.?.output_len or
                (output_len == best.?.output_len and address < best.?.address))
            {
                best = .{
                    .output_len = @intCast(output_len),
                    .copy_len = @intCast(candidate.copy_len),
                    .address = address,
                };
            }
        }
        return best;
    }

    pub fn entryCount(self: *const CompleteIndex) usize {
        return self.words.len;
    }

    pub fn byteSize(self: *const CompleteIndex) usize {
        return self.heads.len * @sizeOf(u32) + self.words.len * @sizeOf(u32);
    }
};

pub const max_index_bytes = (bucket_count + 1) * @sizeOf(u16) + 31_704 * @sizeOf(u32);

fn containsEarlierCanonicalWord(staged: []const u32, next: []const u16, first: u16, transformed: []const u8, scratch: *[64]u8) bool {
    var entry = first;
    while (entry != no_entry) : (entry = next[entry]) {
        const encoded_word = staged[entry];
        const candidate = unpackIndexedWord(encoded_word);
        const word = static_dictionary.baseWord(candidate.copy_len, candidate.word_index).?;
        const candidate_bytes = static_dictionary.transformWord(canonical_case_transforms[@intFromEnum(candidate.case_kind)], word, scratch).?;
        if (std.mem.eql(u8, candidate_bytes, transformed)) return true;
    }
    return false;
}

fn canonicalCaseEligible(word: []const u8, case_kind: static_dictionary.TransformCaseKind) bool {
    return switch (case_kind) {
        .none => true,
        .first => word[0] >= 'a' and word[0] <= 'z',
        .all => blk: {
            for (word) |byte| if (byte >= 128) break :blk false;
            for (word[1..]) |byte| if (byte >= 'a' and byte <= 'z') break :blk true;
            break :blk false;
        },
    };
}

fn prefixSumOffsets(offsets: []u16) void {
    var index: usize = 1;
    while (index < offsets.len) : (index += 1) offsets[index] += offsets[index - 1];
}

fn prefixSumOffsetsU32(offsets: []u32) void {
    var index: usize = 1;
    while (index < offsets.len) : (index += 1)
        offsets[index] = std.math.add(u32, offsets[index], offsets[index - 1]) catch
            unreachable;
}

fn hashPrefix(bytes: []const u8) usize {
    const word = std.mem.readInt(u32, bytes[0..4], .little);
    return (word *% 0x1e35a7bd) >> (32 - bucket_bits);
}

fn packIndexedWord(word_index: usize, copy_len: usize, case_kind: static_dictionary.TransformCaseKind) u32 {
    std.debug.assert(word_index <= word_index_mask);
    return @as(u32, @intCast(word_index)) |
        (@as(u32, @intCast(copy_len - 4)) << word_index_bits) |
        (@as(u32, @intFromEnum(case_kind)) << 16);
}

fn unpackIndexedWord(encoded: u32) IndexedWord {
    return .{
        .word_index = encoded & word_index_mask,
        .copy_len = 4 + ((encoded >> word_index_bits) & 0x1f),
        .case_kind = @enumFromInt((encoded >> 16) & 0x3),
    };
}

fn needsSupplementalTransform(transform_index: usize, copy_len: usize) bool {
    const metadata = static_dictionary.transformMetadata(transform_index).?;
    const after_first = copy_len - @min(copy_len, metadata.omit_first);
    const retained = after_first -| metadata.omit_last;
    return metadata.omit_first != 0 or retained < 4;
}

fn packCompleteIndexedWord(
    word_index: usize,
    copy_len: usize,
    transform_index: usize,
) u32 {
    std.debug.assert(word_index <= word_index_mask);
    std.debug.assert(transform_index < 128);
    return @as(u32, @intCast(word_index)) |
        (@as(u32, @intCast(copy_len - 4)) << word_index_bits) |
        (@as(u32, @intCast(transform_index)) << 16);
}

fn unpackCompleteIndexedWord(encoded: u32) CompleteIndexedWord {
    return .{
        .word_index = encoded & word_index_mask,
        .copy_len = 4 + ((encoded >> word_index_bits) & 0x1f),
        .transform_index = (encoded >> 16) & 0x7f,
    };
}

test "indexed static dictionary matcher agrees with exhaustive reference" {
    var index = try Index.init(std.testing.allocator);
    defer index.deinit();
    try std.testing.expectEqual(@as(usize, 31_704), index.entryCount());

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
        "MTOPB",
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

test "indexed static dictionary matcher reaches every canonical transformed word" {
    var index = try Index.init(std.testing.allocator);
    defer index.deinit();

    var transformed_storage: [64]u8 = undefined;
    var decoded_storage: [64]u8 = undefined;
    for (4..25) |copy_len| {
        const bits = static_dictionary.sizeBits(copy_len).?;
        const word_count = @as(usize, 1) << bits;
        for (0..word_count) |word_index| {
            const word = static_dictionary.baseWord(copy_len, word_index).?;
            for (canonical_case_transforms, 0..) |transform_index, case_index| {
                if (!canonicalCaseEligible(word, @enumFromInt(case_index))) continue;
                const transformed = static_dictionary.transformWord(transform_index, word, &transformed_storage).?;
                const actual = index.findLongest(transformed) orelse {
                    std.debug.print("canonical miss: copy_len={d} transform={d} word_index={d} output={any}\n", .{ copy_len, transform_index, word_index, transformed });
                    return error.TestUnexpectedResult;
                };
                try std.testing.expectEqual(transformed.len, actual.output_len);
                const source_address = (@as(usize, transform_index) << bits) | word_index;
                try std.testing.expect(actual.address <= source_address);
                const decoded = static_dictionary.transform(actual.address, actual.copy_len, &decoded_storage) orelse return error.TestUnexpectedResult;
                try std.testing.expectEqualSlices(u8, transformed, decoded);
            }
        }
    }
}

test "complete static dictionary index matches every transform family" {
    var compact = try Index.init(std.testing.allocator);
    defer compact.deinit();
    var complete = try CompleteIndex.init(std.testing.allocator);
    defer complete.deinit();
    try std.testing.expectEqual(@as(usize, 59_904), complete.entryCount());
    try std.testing.expectEqual(@as(usize, 370_692), complete.byteSize());

    var transformed_storage: [64]u8 = undefined;
    for (0..static_dictionary.transform_count) |transform_index| {
        var covered = false;
        find_case: for (4..25) |copy_len| {
            const word_count = @as(usize, 1) << static_dictionary.sizeBits(copy_len).?;
            for (0..word_count) |word_index| {
                const word = static_dictionary.baseWord(copy_len, word_index).?;
                const transformed = static_dictionary.transformWord(
                    transform_index,
                    word,
                    &transformed_storage,
                ).?;
                if (transformed.len < 5) continue;
                const expected = static_dictionary.findLongestMatch(transformed);
                const actual = complete.findLongest(&compact, transformed);
                try std.testing.expectEqual(expected, actual);
                covered = true;
                break :find_case;
            }
        }
        try std.testing.expect(covered);
    }

    const compact_match = compact.findLongest("quot;");
    try std.testing.expect(compact_match == null or
        compact_match.?.output_len < "quot;".len);
    const complete_match = complete.findLongest(&compact, "quot;").?;
    try std.testing.expectEqual(@as(usize, "quot;".len), complete_match.output_len);
}

test "complete static dictionary index releases allocation failures" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var complete = try CompleteIndex.init(allocator);
            defer complete.deinit();
            try std.testing.expectEqual(@as(usize, 59_904), complete.entryCount());
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{},
    );
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
