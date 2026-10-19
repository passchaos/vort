const std = @import("std");
const serialized_dictionary = @import("../serialized_dictionary.zig");

pub const max_indexed_candidates: usize = 1 << 20;
const target_bucket_load: usize = 4;
const min_bucket_bits: u5 = 8;
const max_bucket_bits: u5 = 16;

const Entry = struct {
    dictionary_id: u8,
    word_len: u8,
    word_index: u16,
    transform_index: u8,
    output_len: u16,
};

/// Reusable complete index for a parsed serialized shared dictionary.
///
/// Candidate bytes remain borrowed through `dictionary`; only compact source
/// coordinates are retained. Descriptors whose theoretical candidate count is
/// above `max_indexed_candidates` keep exact behavior through the exhaustive
/// oracle instead of accepting an incomplete index.
pub const Matcher = struct {
    allocator: std.mem.Allocator,
    dictionary: ?*const serialized_dictionary.Dictionary = null,
    encoded_ptr: ?[*]const u8 = null,
    encoded_len: usize = 0,
    heads: []u32 = &.{},
    entries: []Entry = &.{},
    bucket_bits: u5 = 0,
    indexed: bool = false,
    prepared: bool = false,
    capacity_prefix: [32][serialized_dictionary.max_contexts + 1]usize =
        @splat(@splat(0)),

    pub fn init(allocator: std.mem.Allocator) Matcher {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Matcher) void {
        if (self.heads.len != 0) self.allocator.free(self.heads);
        if (self.entries.len != 0) self.allocator.free(self.entries);
        self.* = undefined;
    }

    pub fn reset(self: *Matcher) void {
        self.dictionary = null;
        self.encoded_ptr = null;
        self.encoded_len = 0;
        self.indexed = false;
        self.prepared = false;
    }

    pub fn retainedCapacity(self: *const Matcher) usize {
        return self.heads.len * @sizeOf(u32) +
            self.entries.len * @sizeOf(Entry);
    }

    pub fn indexedCandidateCount(self: *const Matcher) usize {
        return if (self.indexed) self.entries.len else 0;
    }

    pub fn usesIndex(self: *const Matcher) bool {
        return self.prepared and self.indexed;
    }

    /// Prepare atomically. Allocation or transform failure leaves the previous
    /// descriptor and index usable.
    pub fn prepare(
        self: *Matcher,
        dictionary: *const serialized_dictionary.Dictionary,
    ) (serialized_dictionary.Error || std.mem.Allocator.Error)!void {
        if (self.sameDescriptor(dictionary)) return;

        var capacity_prefix: [32][serialized_dictionary.max_contexts + 1]usize =
            @splat(@splat(0));
        var theoretical_count: usize = 0;
        for (serialized_dictionary.min_word_len..serialized_dictionary.max_word_len + 1) |word_len| {
            for (0..dictionary.dictionary_count) |dictionary_id| {
                const shape = dictionary.candidateShape(
                    dictionary_id,
                    word_len,
                ).?;
                const capacity = try shape.capacity();
                theoretical_count = std.math.add(
                    usize,
                    theoretical_count,
                    capacity,
                ) catch return error.IntegerOverflow;
                capacity_prefix[word_len][dictionary_id + 1] = std.math.add(
                    usize,
                    capacity_prefix[word_len][dictionary_id],
                    capacity,
                ) catch return error.IntegerOverflow;
            }
        }

        if (theoretical_count > max_indexed_candidates) {
            self.commit(
                dictionary,
                &.{},
                &.{},
                0,
                false,
                capacity_prefix,
            );
            return;
        }

        const bucket_bits = chooseBucketBits(theoretical_count);
        const bucket_count = @as(usize, 1) << bucket_bits;
        const heads = try self.allocator.alloc(u32, bucket_count + 1);
        errdefer self.allocator.free(heads);
        @memset(heads, 0);
        const eligible_count = try scanCandidates(
            dictionary,
            bucket_bits,
            heads,
            null,
            null,
        );
        var running: u32 = 0;
        for (0..bucket_count) |bucket| {
            const count = heads[bucket + 1];
            heads[bucket] = running;
            running = std.math.add(u32, running, count) catch
                return error.IntegerOverflow;
        }
        heads[bucket_count] = running;
        std.debug.assert(running == eligible_count);

        const entries = try self.allocator.alloc(Entry, eligible_count);
        errdefer self.allocator.free(entries);
        const cursors = try self.allocator.dupe(u32, heads[0..bucket_count]);
        defer self.allocator.free(cursors);
        const filled = try scanCandidates(
            dictionary,
            bucket_bits,
            null,
            entries,
            cursors,
        );
        std.debug.assert(filled == eligible_count);
        self.commit(
            dictionary,
            heads,
            entries,
            bucket_bits,
            true,
            capacity_prefix,
        );
    }

    pub fn findLongest(
        self: *const Matcher,
        context: usize,
        input: []const u8,
        transformed_scratch: []u8,
    ) serialized_dictionary.Error!?serialized_dictionary.Match {
        const dictionary = self.dictionary orelse return null;
        if (!self.indexed)
            return dictionary.findLongest(context, input, transformed_scratch);
        if (input.len < serialized_dictionary.min_word_len) return null;
        const preferred: usize = try dictionary.dictionaryForContext(context);
        const bucket = hashAnchor(input[0..4], self.bucket_bits);
        var best: ?serialized_dictionary.Match = null;
        for (self.entries[self.heads[bucket]..self.heads[bucket + 1]]) |entry| {
            if (entry.output_len > input.len) continue;
            const transformed = try dictionary.materializeCandidate(
                entry.dictionary_id,
                entry.word_len,
                entry.word_index,
                entry.transform_index,
                transformed_scratch,
            );
            std.debug.assert(transformed.len == entry.output_len);
            if (!std.mem.eql(u8, transformed, input[0..transformed.len]))
                continue;
            const word_len: usize = entry.word_len;
            const dictionary_id: usize = entry.dictionary_id;
            const shape = dictionary.candidateShape(
                dictionary_id,
                word_len,
            ).?;
            const local_address = std.math.add(
                usize,
                std.math.mul(
                    usize,
                    entry.transform_index,
                    shape.word_count,
                ) catch return error.IntegerOverflow,
                entry.word_index,
            ) catch return error.IntegerOverflow;
            const prefix = self.capacity_prefix[word_len];
            const preferred_capacity = prefix[preferred + 1] - prefix[preferred];
            const address_base = if (dictionary_id == preferred)
                0
            else
                std.math.add(
                    usize,
                    prefix[dictionary_id],
                    if (preferred < dictionary_id) 0 else preferred_capacity,
                ) catch return error.IntegerOverflow;
            const address = std.math.add(
                usize,
                address_base,
                local_address,
            ) catch return error.IntegerOverflow;
            if (best == null or transformed.len > best.?.output_len or
                (transformed.len == best.?.output_len and
                    (address < best.?.address or
                        (address == best.?.address and
                            word_len < best.?.copy_len))))
            {
                best = .{
                    .output_len = @intCast(transformed.len),
                    .copy_len = @intCast(word_len),
                    .address = address,
                    .dictionary_id = @intCast(dictionary_id),
                };
            }
        }
        return best;
    }

    fn sameDescriptor(
        self: *const Matcher,
        dictionary: *const serialized_dictionary.Dictionary,
    ) bool {
        return self.prepared and self.dictionary == dictionary and
            self.encoded_ptr == dictionary.encoded.ptr and
            self.encoded_len == dictionary.encoded.len;
    }

    fn commit(
        self: *Matcher,
        dictionary: *const serialized_dictionary.Dictionary,
        heads: []u32,
        entries: []Entry,
        bucket_bits: u5,
        indexed: bool,
        capacity_prefix: [32][serialized_dictionary.max_contexts + 1]usize,
    ) void {
        const old_heads = self.heads;
        const old_entries = self.entries;
        self.dictionary = dictionary;
        self.encoded_ptr = dictionary.encoded.ptr;
        self.encoded_len = dictionary.encoded.len;
        self.heads = heads;
        self.entries = entries;
        self.bucket_bits = bucket_bits;
        self.indexed = indexed;
        self.prepared = true;
        self.capacity_prefix = capacity_prefix;
        if (old_heads.len != 0) self.allocator.free(old_heads);
        if (old_entries.len != 0) self.allocator.free(old_entries);
    }
};

fn chooseBucketBits(candidate_count: usize) u5 {
    const target = @max(
        @as(usize, 1) << min_bucket_bits,
        (candidate_count + target_bucket_load - 1) / target_bucket_load,
    );
    var bits = min_bucket_bits;
    var count = @as(usize, 1) << bits;
    while (count < target and bits < max_bucket_bits) {
        bits += 1;
        count <<= 1;
    }
    return bits;
}

fn scanCandidates(
    dictionary: *const serialized_dictionary.Dictionary,
    bucket_bits: u5,
    counts: ?[]u32,
    entries: ?[]Entry,
    cursors: ?[]u32,
) serialized_dictionary.Error!u32 {
    var eligible_count: u32 = 0;
    var transformed_scratch: [serialized_dictionary.max_transformed_word_len]u8 =
        undefined;
    for (0..dictionary.dictionary_count) |dictionary_id| {
        for (serialized_dictionary.min_word_len..serialized_dictionary.max_word_len + 1) |word_len| {
            const shape = dictionary.candidateShape(dictionary_id, word_len).?;
            for (0..shape.transform_count) |transform_index| {
                for (0..shape.word_count) |word_index| {
                    const transformed = try dictionary.materializeCandidate(
                        dictionary_id,
                        word_len,
                        word_index,
                        transform_index,
                        &transformed_scratch,
                    );
                    if (transformed.len < serialized_dictionary.min_word_len)
                        continue;
                    const bucket = hashAnchor(transformed[0..4], bucket_bits);
                    if (counts) |active| {
                        active[bucket + 1] = std.math.add(
                            u32,
                            active[bucket + 1],
                            1,
                        ) catch return error.IntegerOverflow;
                    } else {
                        const active_entries = entries.?;
                        const active_cursors = cursors.?;
                        const slot = active_cursors[bucket];
                        if (slot >= active_entries.len)
                            return error.IntegerOverflow;
                        active_entries[slot] = .{
                            .dictionary_id = @intCast(dictionary_id),
                            .word_len = @intCast(word_len),
                            .word_index = @intCast(word_index),
                            .transform_index = @intCast(transform_index),
                            .output_len = @intCast(transformed.len),
                        };
                        active_cursors[bucket] = std.math.add(
                            u32,
                            slot,
                            1,
                        ) catch return error.IntegerOverflow;
                    }
                    eligible_count = std.math.add(
                        u32,
                        eligible_count,
                        1,
                    ) catch return error.IntegerOverflow;
                }
            }
        }
    }
    return eligible_count;
}

fn hashAnchor(bytes: *const [4]u8, bucket_bits: u5) usize {
    const word = std.mem.readInt(u32, bytes, .little);
    const shift: u5 = @intCast(32 - @as(u6, bucket_bits));
    return @as(usize, (word *% 0x1e35_a7bd) >> shift);
}

test "serialized index matches exhaustive contextual addresses" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try encoded.appendSlice(std.testing.allocator, &.{ 0x91, 0, 0, 2 });
    var bits: [28]u8 = @splat(0);
    bits[0] = 1;
    try encoded.appendSlice(std.testing.allocator, &bits);
    try encoded.appendSlice(std.testing.allocator, "red!xxxx");
    try encoded.appendSlice(std.testing.allocator, &bits);
    try encoded.appendSlice(std.testing.allocator, "bluezzzz");
    try encoded.appendSlice(std.testing.allocator, &.{
        1, 1, 0, 0, // one transform list and one empty stringlet
        12, // transform kinds 0...11
    });
    for (0..12) |kind|
        try encoded.appendSlice(std.testing.allocator, &.{
            0, @intCast(kind), 0,
        });
    try encoded.appendSlice(std.testing.allocator, &.{
        2, 0, 0, 1, 0, // two dictionary choices
        1, // context map enabled
    });
    var context_map: [64]u8 = @splat(0);
    context_map[33] = 1;
    try encoded.appendSlice(std.testing.allocator, &context_map);
    const dictionary = try serialized_dictionary.parse(encoded.items);
    var matcher = Matcher.init(std.testing.allocator);
    defer matcher.deinit();
    try matcher.prepare(&dictionary);
    try std.testing.expect(matcher.usesIndex());
    try std.testing.expect(matcher.indexedCandidateCount() != 0);

    var indexed_scratch: [serialized_dictionary.max_transformed_word_len]u8 =
        undefined;
    var exhaustive_scratch: [serialized_dictionary.max_transformed_word_len]u8 =
        undefined;
    for (0..64) |context| {
        for ([_][]const u8{ "red!", "blue", "xxxx", "zzzz", "none" }) |input| {
            const indexed = try matcher.findLongest(
                context,
                input,
                &indexed_scratch,
            );
            const exhaustive = try dictionary.findLongest(
                context,
                input,
                &exhaustive_scratch,
            );
            try std.testing.expectEqual(exhaustive, indexed);
        }
    }
    var target_scratch: [serialized_dictionary.max_transformed_word_len]u8 =
        undefined;
    for (0..dictionary.dictionary_count) |dictionary_id| {
        const shape = dictionary.candidateShape(dictionary_id, 4).?;
        for (0..shape.transform_count) |transform_index| {
            for (0..shape.word_count) |word_index| {
                const target = try dictionary.materializeCandidate(
                    dictionary_id,
                    4,
                    word_index,
                    transform_index,
                    &target_scratch,
                );
                if (target.len < serialized_dictionary.min_word_len) continue;
                for ([_]usize{ 0, 33 }) |context| {
                    const indexed = try matcher.findLongest(
                        context,
                        target,
                        &indexed_scratch,
                    );
                    const exhaustive = try dictionary.findLongest(
                        context,
                        target,
                        &exhaustive_scratch,
                    );
                    try std.testing.expectEqual(exhaustive, indexed);
                }
            }
        }
    }
}

test "serialized index preparation is atomic and descriptor-identical reuse allocates nothing" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try encoded.appendSlice(std.testing.allocator, &.{ 0x91, 0, 0, 1 });
    var bits: [28]u8 = @splat(0);
    bits[0] = 1;
    try encoded.appendSlice(std.testing.allocator, &bits);
    try encoded.appendSlice(std.testing.allocator, "wordtest");
    try encoded.appendSlice(std.testing.allocator, &.{
        1, 1, 0, 0, 1, 0, 0, 0, // identity transform list
        1, 0, 0, // one custom/custom dictionary choice
        0, // context map disabled
    });
    const dictionary = try serialized_dictionary.parse(encoded.items);
    var failing = std.testing.FailingAllocator.init(
        std.testing.allocator,
        .{ .fail_index = 0 },
    );
    var matcher = Matcher.init(failing.allocator());
    try std.testing.expectError(error.OutOfMemory, matcher.prepare(&dictionary));
    try std.testing.expect(failing.has_induced_failure);
    try std.testing.expectEqual(@as(usize, 0), matcher.retainedCapacity());

    failing.fail_index = std.math.maxInt(usize);
    try matcher.prepare(&dictionary);
    const retained = matcher.retainedCapacity();
    const allocations = failing.alloc_index;
    failing.fail_index = allocations;
    try matcher.prepare(&dictionary);
    try std.testing.expectEqual(allocations, failing.alloc_index);
    try std.testing.expectEqual(retained, matcher.retainedCapacity());

    const encoded_second = try std.testing.allocator.dupe(u8, encoded.items);
    defer std.testing.allocator.free(encoded_second);
    encoded_second[4 + 28] = 'b';
    const second = try serialized_dictionary.parse(encoded_second);
    failing.has_induced_failure = false;
    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, matcher.prepare(&second));
    try std.testing.expect(failing.has_induced_failure);
    var scratch: [serialized_dictionary.max_transformed_word_len]u8 = undefined;
    const retained_match = (try matcher.findLongest(0, "word", &scratch)).?;
    try std.testing.expectEqual(@as(u16, 4), retained_match.output_len);
    try std.testing.expectEqual(retained, matcher.retainedCapacity());
    matcher.deinit();
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

test "oversized serialized candidate spaces retain exhaustive fallback" {
    const dictionary = try serialized_dictionary.parse(&.{ 0x91, 0, 0, 0, 0 });
    var matcher = Matcher.init(std.testing.allocator);
    defer matcher.deinit();
    try matcher.prepare(&dictionary);
    try std.testing.expect(!matcher.usesIndex());
    try std.testing.expectEqual(@as(usize, 0), matcher.retainedCapacity());
    var scratch: [serialized_dictionary.max_transformed_word_len]u8 = undefined;
    try std.testing.expectEqual(
        @as(?serialized_dictionary.Match, null),
        try matcher.findLongest(0, "abc", &scratch),
    );
}
