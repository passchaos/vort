const std = @import("std");
const checksum = @import("checksum.zig");

pub const cover = @import("dictionary/cover.zig");
pub const cover_optimize = @import("dictionary/cover_optimize.zig");
pub const CoverTrainOptions = cover.TrainOptions;
pub const CoverOptimizeOptions = cover_optimize.OptimizeOptions;
pub const CoverOptimizeScore = cover_optimize.Score;
pub const OwnedOptimizedCoverDictionary = cover_optimize.OwnedResult;

test {
    _ = cover;
    _ = cover_optimize;
}

const patch_magic = [_]u8{ 'V', 'D', 'C', 'T' };
const patch_version: u8 = 0;
const patch_header_len: usize = 17;
const op_literal: u8 = 0;
const op_match: u8 = 1;
const metadata_magic = [_]u8{ 'V', 'D', 'M', 'T' };
const metadata_version: u8 = 0;
const metadata_header_len: usize = 32;
const metadata_catalog_magic = [_]u8{ 'V', 'D', 'M', 'C' };
const metadata_catalog_version: u8 = 0;
const metadata_catalog_header_len: usize = 16;

pub const metadata_encoded_len: usize = metadata_header_len;
pub const metadata_catalog_header_encoded_len: usize = metadata_catalog_header_len;

pub const DictionaryId = packed struct(u64) {
    crc32: u32,
    length: u32,

    pub fn fromBytes(bytes: []const u8) DictionaryId {
        return .{ .crc32 = checksum.crc32(bytes), .length = @truncate(bytes.len) };
    }

    pub fn asInt(self: DictionaryId) u64 {
        return @bitCast(self);
    }
};

pub const Metadata = struct {
    id: DictionaryId,
    content_len: usize,
    window_len: usize,

    pub fn fromBytes(bytes: []const u8, window_len: usize) Metadata {
        return .{ .id = .fromBytes(bytes), .content_len = bytes.len, .window_len = window_len };
    }

    /// Check whether this catalog entry describes the provided dictionary bytes
    /// for a codec-specific history window.
    pub fn matchesBytes(self: Metadata, bytes: []const u8, window_len: usize) bool {
        const actual = fromBytes(bytes, window_len);
        return self.id.asInt() == actual.id.asInt() and
            self.content_len == actual.content_len and
            self.window_len == actual.window_len;
    }

    pub fn validateBytes(self: Metadata, bytes: []const u8, window_len: usize) !void {
        if (!self.matchesBytes(bytes, window_len)) return error.InvalidDictionaryMetadata;
    }

    /// Stable fixed-size record for persisting dictionary catalog metadata.
    ///
    /// The record intentionally contains metadata only: callers still own and
    /// distribute the dictionary bytes separately. Keeping the wire form small,
    /// versioned, and endian-stable lets containers advertise dictionary
    /// requirements before constructing codec-specific borrowed dictionaries.
    pub fn encodeInto(self: Metadata, output: []u8) !usize {
        if (output.len < metadata_encoded_len) return error.OutputTooSmall;
        @memcpy(output[0..4], &metadata_magic);
        output[4] = metadata_version;
        output[5] = 0;
        output[6] = 0;
        output[7] = 0;
        std.mem.writeInt(u32, output[8..12], self.id.crc32, .little);
        std.mem.writeInt(u32, output[12..16], self.id.length, .little);
        std.mem.writeInt(u64, output[16..24], std.math.cast(u64, self.content_len) orelse return error.IntegerOverflow, .little);
        std.mem.writeInt(u64, output[24..32], std.math.cast(u64, self.window_len) orelse return error.IntegerOverflow, .little);
        return metadata_encoded_len;
    }

    pub fn encodeAlloc(self: Metadata, allocator: std.mem.Allocator) ![]u8 {
        const encoded = try allocator.alloc(u8, metadata_encoded_len);
        errdefer allocator.free(encoded);
        _ = try self.encodeInto(encoded);
        return encoded;
    }

    pub fn decode(bytes: []const u8) !Metadata {
        const result = try decodePrefix(bytes);
        if (bytes.len != result.bytes_read) return error.TrailingData;
        return result.metadata;
    }

    pub fn decodePrefix(bytes: []const u8) !MetadataDecodeResult {
        if (bytes.len < metadata_encoded_len) return error.TruncatedFrame;
        if (!std.mem.eql(u8, bytes[0..4], &metadata_magic)) return error.InvalidMagic;
        if (bytes[4] != metadata_version) return error.UnsupportedVersion;
        if (bytes[5] != 0 or bytes[6] != 0 or bytes[7] != 0) return error.CorruptFrame;
        return .{
            .metadata = .{
                .id = .{
                    .crc32 = std.mem.readInt(u32, bytes[8..12], .little),
                    .length = std.mem.readInt(u32, bytes[12..16], .little),
                },
                .content_len = std.math.cast(usize, std.mem.readInt(u64, bytes[16..24], .little)) orelse return error.IntegerOverflow,
                .window_len = std.math.cast(usize, std.mem.readInt(u64, bytes[24..32], .little)) orelse return error.IntegerOverflow,
            },
            .bytes_read = metadata_encoded_len,
        };
    }
};

pub const MetadataDecodeResult = struct {
    metadata: Metadata,
    bytes_read: usize,
};

pub const MetadataCatalogDecodeResult = struct {
    count: usize,
    bytes_read: usize,
};

pub const MetadataCatalogAllocDecodeResult = struct {
    metadata: []Metadata,
    bytes_read: usize,

    pub fn deinit(self: MetadataCatalogAllocDecodeResult, allocator: std.mem.Allocator) void {
        allocator.free(self.metadata);
    }
};

pub fn encodeMetadataInto(metadata: Metadata, output: []u8) !usize {
    return metadata.encodeInto(output);
}

pub fn encodeMetadataAlloc(allocator: std.mem.Allocator, metadata: Metadata) ![]u8 {
    return metadata.encodeAlloc(allocator);
}

pub fn decodeMetadata(bytes: []const u8) !Metadata {
    return Metadata.decode(bytes);
}

pub fn decodeMetadataPrefix(bytes: []const u8) !MetadataDecodeResult {
    return Metadata.decodePrefix(bytes);
}

pub fn encodedMetadataCatalogLen(count: usize) !usize {
    const body = std.math.mul(usize, count, metadata_encoded_len) catch return error.IntegerOverflow;
    return std.math.add(usize, metadata_catalog_header_encoded_len, body) catch return error.IntegerOverflow;
}

pub fn encodeMetadataCatalogInto(metadata: []const Metadata, output: []u8) !usize {
    const required = try encodedMetadataCatalogLen(metadata.len);
    if (output.len < required) return error.OutputTooSmall;
    @memcpy(output[0..4], &metadata_catalog_magic);
    output[4] = metadata_catalog_version;
    output[5] = 0;
    output[6] = 0;
    output[7] = 0;
    std.mem.writeInt(u64, output[8..16], std.math.cast(u64, metadata.len) orelse return error.IntegerOverflow, .little);
    var offset: usize = metadata_catalog_header_encoded_len;
    for (metadata) |entry| {
        offset += try entry.encodeInto(output[offset..][0..metadata_encoded_len]);
    }
    return required;
}

pub fn encodeMetadataCatalogAlloc(allocator: std.mem.Allocator, metadata: []const Metadata) ![]u8 {
    const encoded = try allocator.alloc(u8, try encodedMetadataCatalogLen(metadata.len));
    errdefer allocator.free(encoded);
    _ = try encodeMetadataCatalogInto(metadata, encoded);
    return encoded;
}

pub fn decodedMetadataCatalogCount(bytes: []const u8) !usize {
    if (bytes.len < metadata_catalog_header_encoded_len) return error.TruncatedFrame;
    if (!std.mem.eql(u8, bytes[0..4], &metadata_catalog_magic)) return error.InvalidMagic;
    if (bytes[4] != metadata_catalog_version) return error.UnsupportedVersion;
    if (bytes[5] != 0 or bytes[6] != 0 or bytes[7] != 0) return error.CorruptFrame;
    return std.math.cast(usize, std.mem.readInt(u64, bytes[8..16], .little)) orelse return error.IntegerOverflow;
}

pub fn decodeMetadataCatalogInto(bytes: []const u8, output: []Metadata) !usize {
    const result = try decodeMetadataCatalogPrefixInto(bytes, output);
    if (bytes.len != result.bytes_read) return error.TrailingData;
    return result.count;
}

pub fn decodeMetadataCatalogPrefixInto(bytes: []const u8, output: []Metadata) !MetadataCatalogDecodeResult {
    const count = try decodedMetadataCatalogCount(bytes);
    if (output.len < count) return error.OutputTooSmall;
    const required = try encodedMetadataCatalogLen(count);
    if (bytes.len < required) return error.TruncatedFrame;
    var offset: usize = metadata_catalog_header_encoded_len;
    for (output[0..count]) |*entry| {
        const result = try Metadata.decodePrefix(bytes[offset..]);
        entry.* = result.metadata;
        offset += result.bytes_read;
    }
    return .{ .count = count, .bytes_read = required };
}

pub fn decodeMetadataCatalogAlloc(allocator: std.mem.Allocator, bytes: []const u8) ![]Metadata {
    const count = try decodedMetadataCatalogCount(bytes);
    const decoded = try allocator.alloc(Metadata, count);
    errdefer allocator.free(decoded);
    _ = try decodeMetadataCatalogInto(bytes, decoded);
    return decoded;
}

pub fn decodeMetadataCatalogPrefixAlloc(allocator: std.mem.Allocator, bytes: []const u8) !MetadataCatalogAllocDecodeResult {
    const count = try decodedMetadataCatalogCount(bytes);
    const decoded = try allocator.alloc(Metadata, count);
    errdefer allocator.free(decoded);
    const result = try decodeMetadataCatalogPrefixInto(bytes, decoded);
    return .{ .metadata = decoded, .bytes_read = result.bytes_read };
}

pub const TrainOptions = struct {
    target_size: usize,
    min_phrase_len: usize = 4,
    max_phrase_len: usize = 16,
    max_phrases: usize = 256,
};

/// Train caller-owned history with the deterministic, sample-boundary-safe
/// COVER-class selector. This exposes the COVER selection model without
/// claiming byte-identical output with libzstd's COVER or FastCover trainers.
pub fn trainCoverAlloc(
    allocator: std.mem.Allocator,
    samples: []const []const u8,
    options: CoverTrainOptions,
) ![]u8 {
    return cover.trainAlloc(allocator, samples, options);
}

/// Select `(d, k, hash_log)` on held-out samples using the shared greedy
/// dictionary match-cost model. Equal scores preserve caller enumeration order.
pub fn trainOptimizedCoverAlloc(
    allocator: std.mem.Allocator,
    training_samples: []const []const u8,
    validation_samples: []const []const u8,
    options: CoverOptimizeOptions,
) !OwnedOptimizedCoverDictionary {
    const ScoreAdapter = struct {
        fn score(dictionary: []const u8, samples: []const []const u8, min_match_len: usize) !cover_optimize.Score {
            const value = try validationScore(dictionary, samples, min_match_len);
            return .{
                .estimated_bits = value.estimated_bits,
                .covered_bytes = value.covered_bytes,
                .matches = value.matches,
                .distance_bits = value.distance_bits,
            };
        }
    };
    return cover_optimize.trainAllocWithScorer(
        allocator,
        training_samples,
        validation_samples,
        options,
        ScoreAdapter.score,
    );
}

const Phrase = struct {
    bytes: []const u8,
    score: usize,
    sample_count: usize = 1,
    last_sample: usize = 0,
};

const phrase_hash_threshold = 128;
const phrase_index_load_numerator = 3;
const phrase_index_load_denominator = 4;

const PhraseIndex = struct {
    const Entry = struct {
        hash: u64 = 0,
        index_plus_one: usize = 0,
    };

    slots: std.ArrayList(Entry) = .empty,
    count: usize = 0,

    fn deinit(self: *PhraseIndex, allocator: std.mem.Allocator) void {
        self.slots.deinit(allocator);
        self.* = .{};
    }

    fn ensureUnusedCapacity(self: *PhraseIndex, allocator: std.mem.Allocator, additional: usize) !void {
        const needed = std.math.add(usize, self.count, additional) catch return error.OutOfMemory;
        if (self.slots.items.len != 0 and needed <= self.slots.items.len / phrase_index_load_denominator * phrase_index_load_numerator) return;
        var capacity: usize = if (self.slots.items.len == 0) 256 else self.slots.items.len;
        while (needed > capacity / phrase_index_load_denominator * phrase_index_load_numerator) {
            capacity = std.math.mul(usize, capacity, 2) catch return error.OutOfMemory;
        }

        var replacement: std.ArrayList(Entry) = .empty;
        errdefer replacement.deinit(allocator);
        try replacement.resize(allocator, capacity);
        @memset(replacement.items, .{});
        for (self.slots.items) |entry| {
            if (entry.index_plus_one != 0) putPhraseIndexAssumeCapacity(replacement.items, entry.hash, entry.index_plus_one - 1);
        }
        self.slots.deinit(allocator);
        self.slots = replacement;
    }

    fn get(self: *const PhraseIndex, phrases: []const Phrase, bytes: []const u8) ?usize {
        return self.getWithHash(phrases, bytes, std.hash_map.hashString(bytes));
    }

    fn getWithHash(self: *const PhraseIndex, phrases: []const Phrase, bytes: []const u8, hash: u64) ?usize {
        if (self.slots.items.len == 0) return null;
        const mask = self.slots.items.len - 1;
        var slot = @as(usize, @truncate(hash)) & mask;
        var remaining = self.slots.items.len;
        while (remaining != 0) : (remaining -= 1) {
            const entry = self.slots.items[slot];
            if (entry.index_plus_one == 0) return null;
            const phrase_index = entry.index_plus_one - 1;
            if (entry.hash == hash and std.mem.eql(u8, phrases[phrase_index].bytes, bytes)) return phrase_index;
            slot = (slot + 1) & mask;
        }
        return null;
    }

    fn put(self: *PhraseIndex, allocator: std.mem.Allocator, bytes: []const u8, phrase_index: usize) !void {
        try self.ensureUnusedCapacity(allocator, 1);
        putPhraseIndexAssumeCapacity(self.slots.items, std.hash_map.hashString(bytes), phrase_index);
        self.count += 1;
    }

    fn remove(self: *PhraseIndex, bytes: []const u8, phrase_index: usize) void {
        const hash = std.hash_map.hashString(bytes);
        self.removeWithHash(hash, phrase_index);
    }

    fn removeWithHash(self: *PhraseIndex, hash: u64, phrase_index: usize) void {
        if (self.slots.items.len == 0) return;
        const mask = self.slots.items.len - 1;
        var slot = @as(usize, @truncate(hash)) & mask;
        while (self.slots.items[slot].index_plus_one != 0) : (slot = (slot + 1) & mask) {
            const entry = self.slots.items[slot];
            if (entry.hash != hash or entry.index_plus_one - 1 != phrase_index) continue;
            var hole = slot;
            var next = (slot + 1) & mask;
            while (self.slots.items[next].index_plus_one != 0) : (next = (next + 1) & mask) {
                const home = @as(usize, @truncate(self.slots.items[next].hash)) & mask;
                if (((hole -% home) & mask) >= ((next -% home) & mask)) continue;
                self.slots.items[hole] = self.slots.items[next];
                hole = next;
            }
            self.slots.items[hole] = .{};
            self.count -= 1;
            return;
        }
    }
};

fn putPhraseIndexAssumeCapacity(slots: []PhraseIndex.Entry, hash: u64, phrase_index: usize) void {
    const mask = slots.len - 1;
    var slot = @as(usize, @truncate(hash)) & mask;
    while (slots[slot].index_plus_one != 0) slot = (slot + 1) & mask;
    slots[slot] = .{ .hash = hash, .index_plus_one = phrase_index + 1 };
}

pub fn trainAlloc(allocator: std.mem.Allocator, samples: []const []const u8, options: TrainOptions) ![]u8 {
    return trainAllocWithLayout(allocator, samples, options, .ranked, .total_frequency);
}

const TrainLayout = enum { ranked, best_near_end };
const TrainRanking = enum { total_frequency, cross_sample };

fn trainAllocWithLayout(allocator: std.mem.Allocator, samples: []const []const u8, options: TrainOptions, layout: TrainLayout, ranking: TrainRanking) ![]u8 {
    if (options.target_size == 0) return allocator.alloc(u8, 0);
    if (options.min_phrase_len == 0 or options.min_phrase_len > options.max_phrase_len) return error.InvalidDictionaryTraining;

    const phrases = try collectPhrasesAlloc(allocator, samples, options);
    defer allocator.free(phrases);
    sortPhrases(phrases, ranking);
    return assembleDictionaryAlloc(allocator, phrases, options.target_size, layout);
}

fn collectPhrasesAlloc(allocator: std.mem.Allocator, samples: []const []const u8, options: TrainOptions) ![]Phrase {
    if (options.min_phrase_len == 0 or options.min_phrase_len > options.max_phrase_len) return error.InvalidDictionaryTraining;
    var phrases: std.ArrayList(Phrase) = .empty;
    errdefer phrases.deinit(allocator);
    var phrase_indexes: PhraseIndex = .{};
    defer phrase_indexes.deinit(allocator);
    // Once the bounded candidate set is full, the old implementation scanned
    // every retained phrase for every new substring. Keep an open-addressed
    // phrase index plus a min-heap of stable phrase indexes instead; the phrase
    // array is not reordered until collection is complete.
    var worst_heap: std.ArrayList(usize) = .empty;
    defer worst_heap.deinit(allocator);
    var heap_positions: std.ArrayList(usize) = .empty;
    defer heap_positions.deinit(allocator);
    var index_active = false;
    var heap_active = false;

    for (samples, 0..) |sample, sample_index| {
        if (sample.len < options.min_phrase_len) continue;
        var start: usize = 0;
        while (start + options.min_phrase_len <= sample.len) : (start += 1) {
            const max_len = @min(options.max_phrase_len, sample.len - start);
            var len = options.min_phrase_len;
            while (len <= max_len) : (len += 1) {
                const phrase = sample[start..][0..len];
                const existing = if (index_active) phrase_indexes.get(phrases.items, phrase) else findPhrase(phrases.items, phrase);
                if (existing) |idx| {
                    phrases.items[idx].score += len;
                    if (phrases.items[idx].last_sample != sample_index) {
                        phrases.items[idx].sample_count += 1;
                        phrases.items[idx].last_sample = sample_index;
                    }
                    if (heap_active) phraseHeapSiftDown(worst_heap.items, heap_positions.items, phrases.items, heap_positions.items[idx]);
                } else if (phrases.items.len < options.max_phrases) {
                    try phrases.append(allocator, .{ .bytes = phrase, .score = len, .last_sample = sample_index });
                    if (!index_active and phrases.items.len == phrase_hash_threshold and options.max_phrases > phrase_hash_threshold) {
                        try initializePhraseIndex(allocator, &phrase_indexes, phrases.items);
                        index_active = true;
                    } else if (index_active) try phrase_indexes.put(allocator, phrase, phrases.items.len - 1);
                } else if (phrases.items.len != 0) {
                    if (!heap_active) {
                        try initializePhraseHeap(allocator, &worst_heap, &heap_positions, phrases.items);
                        heap_active = true;
                    }
                    const new_phrase: Phrase = .{ .bytes = phrase, .score = len, .last_sample = sample_index };
                    if (phraseBetter({}, new_phrase, phrases.items[worst_heap.items[0]])) {
                        const index = worst_heap.items[0];
                        if (index_active) phrase_indexes.remove(phrases.items[index].bytes, index);
                        phrases.items[index] = new_phrase;
                        if (index_active) try phrase_indexes.put(allocator, phrase, index);
                        phraseHeapSiftDown(worst_heap.items, heap_positions.items, phrases.items, 0);
                    }
                }
            }
        }
    }
    return phrases.toOwnedSlice(allocator);
}

fn sortPhrases(phrases: []Phrase, ranking: TrainRanking) void {
    switch (ranking) {
        .total_frequency => std.sort.heap(Phrase, phrases, {}, phraseBetter),
        .cross_sample => std.sort.heap(Phrase, phrases, {}, phraseCrossSampleBetter),
    }
}

fn assembleDictionaryAlloc(allocator: std.mem.Allocator, phrases: []const Phrase, target_size: usize, layout: TrainLayout) ![]u8 {
    var dict: std.ArrayList(u8) = .empty;
    errdefer dict.deinit(allocator);
    var selected: std.ArrayList([]const u8) = .empty;
    defer selected.deinit(allocator);
    for (phrases) |phrase| {
        if (dict.items.len >= target_size) break;
        if (containsSlice(dict.items, phrase.bytes)) continue;
        const remaining = target_size - dict.items.len;
        const bytes = phrase.bytes[0..@min(remaining, phrase.bytes.len)];
        try dict.appendSlice(allocator, bytes);
        if (layout == .best_near_end) try selected.append(allocator, bytes);
    }
    if (layout == .best_near_end) {
        dict.clearRetainingCapacity();
        var index = selected.items.len;
        while (index != 0) {
            index -= 1;
            try dict.appendSlice(allocator, selected.items[index]);
        }
    }
    return dict.toOwnedSlice(allocator);
}

/// Train several bounded deterministic phrase dictionaries and retain the one
/// with the greatest held-out match coverage. This is a compact validation-
/// guided selector rather than COVER/FastCover: candidate count is fixed and
/// scoring uses the same greedy dictionary matcher exposed by this module.
/// Ties preserve the baseline candidate so existing deterministic output is
/// stable unless another configuration proves strictly better coverage.
pub fn trainValidatedAlloc(
    allocator: std.mem.Allocator,
    training_samples: []const []const u8,
    validation_samples: []const []const u8,
    options: TrainOptions,
) ![]u8 {
    var trained = try trainValidatedTargetsAlloc(
        allocator,
        training_samples,
        validation_samples,
        &.{options.target_size},
        options,
    );
    const result = trained.take(0).?;
    trained.deinit(allocator);
    return result;
}

pub const OwnedValidatedDictionaries = struct {
    dictionaries: []?[]u8,

    /// Transfer one dictionary to the caller so `deinit` releases only the
    /// remaining entries. Each index may be taken at most once.
    pub fn take(self: *OwnedValidatedDictionaries, index: usize) ?[]u8 {
        if (index >= self.dictionaries.len) return null;
        const dictionary = self.dictionaries[index];
        self.dictionaries[index] = null;
        return dictionary;
    }

    pub fn deinit(self: OwnedValidatedDictionaries, allocator: std.mem.Allocator) void {
        for (self.dictionaries) |dictionary| if (dictionary) |bytes| allocator.free(bytes);
        allocator.free(self.dictionaries);
    }
};

const ValidatedBest = struct {
    bytes: ?[]u8 = null,
    covered: usize = 0,
    matches: usize = 0,
    distance_bits: usize = std.math.maxInt(usize),
};

const DictionaryMatchIndexScratch = struct {
    positions: std.ArrayList(usize) = .empty,

    fn deinit(self: *DictionaryMatchIndexScratch, allocator: std.mem.Allocator) void {
        self.positions.deinit(allocator);
        self.* = .{};
    }

    fn build(
        self: *DictionaryMatchIndexScratch,
        allocator: std.mem.Allocator,
        dict: []const u8,
        min_match_len: usize,
    ) !DictionaryMatchIndex {
        if (min_match_len == 0) return error.InvalidDictionaryTraining;
        const position_count = if (dict.len < min_match_len) 0 else dict.len - min_match_len + 1;
        try self.positions.resize(allocator, position_count);

        var counts: [256]usize = @splat(0);
        for (dict[0..position_count]) |byte| counts[byte] += 1;
        var starts: [257]usize = @splat(0);
        for (counts, 0..) |count, byte| starts[byte + 1] = starts[byte] + count;
        var cursors: [256]usize = undefined;
        @memcpy(&cursors, starts[0..256]);
        for (dict[0..position_count], 0..) |byte, position| {
            self.positions.items[cursors[byte]] = position;
            cursors[byte] += 1;
        }
        return .{
            .starts = starts,
            .positions = self.positions.items,
            .min_match_len = min_match_len,
        };
    }
};

const DictionaryMatchIndex = struct {
    starts: [257]usize,
    positions: []const usize,
    min_match_len: usize,

    fn findBest(self: DictionaryMatchIndex, dict: []const u8, sample: []const u8) DictionaryMatchCandidate {
        var best: DictionaryMatchCandidate = .{};
        if (sample.len < self.min_match_len) return best;
        const byte = sample[0];
        for (self.positions[self.starts[byte]..self.starts[@as(usize, byte) + 1]]) |offset| {
            if (self.min_match_len > 1 and !std.mem.eql(
                u8,
                dict[offset + 1 ..][0 .. self.min_match_len - 1],
                sample[1..self.min_match_len],
            )) continue;
            const max_len = @min(dict.len - offset, sample.len);
            var len = self.min_match_len;
            while (len < max_len and dict[offset + len] == sample[len]) len += 1;
            if (len > best.length) best = .{ .offset = offset, .length = len };
        }
        return best;
    }
};

/// Train the same validation-guided candidate family for several dictionary
/// sizes while collecting each phrase configuration only once. Results retain
/// the caller's target order and are byte-identical to separate
/// `trainValidatedAlloc` calls. Release them with `OwnedValidatedDictionaries.deinit`.
pub fn trainValidatedTargetsAlloc(
    allocator: std.mem.Allocator,
    training_samples: []const []const u8,
    validation_samples: []const []const u8,
    target_sizes: []const usize,
    options: TrainOptions,
) !OwnedValidatedDictionaries {
    var has_nonzero_target = false;
    for (target_sizes) |target_size| has_nonzero_target = has_nonzero_target or target_size != 0;
    if (!has_nonzero_target) {
        const dictionaries = try allocator.alloc(?[]u8, target_sizes.len);
        errdefer allocator.free(dictionaries);
        var initialized: usize = 0;
        errdefer for (dictionaries[0..initialized]) |dictionary| allocator.free(dictionary.?);
        for (dictionaries) |*dictionary| {
            dictionary.* = try allocator.alloc(u8, 0);
            initialized += 1;
        }
        return .{ .dictionaries = dictionaries };
    }
    const best = try allocator.alloc(ValidatedBest, target_sizes.len);
    defer allocator.free(best);
    @memset(best, .{});
    errdefer for (best) |entry| if (entry.bytes) |bytes| allocator.free(bytes);
    var match_index_scratch: DictionaryMatchIndexScratch = .{};
    defer match_index_scratch.deinit(allocator);

    const Candidate = struct { min_phrase_len: usize, max_phrase_len: usize, max_phrases: usize };
    const candidates = [_]Candidate{
        .{ .min_phrase_len = options.min_phrase_len, .max_phrase_len = options.max_phrase_len, .max_phrases = options.max_phrases },
        .{ .min_phrase_len = 3, .max_phrase_len = 12, .max_phrases = @max(options.max_phrases, 512) },
        .{ .min_phrase_len = 4, .max_phrase_len = 24, .max_phrases = @max(options.max_phrases, 512) },
        .{ .min_phrase_len = 6, .max_phrase_len = 32, .max_phrases = @max(options.max_phrases, 1024) },
    };

    for (candidates) |candidate| {
        const candidate_options: TrainOptions = .{
            .target_size = options.target_size,
            .min_phrase_len = candidate.min_phrase_len,
            .max_phrase_len = candidate.max_phrase_len,
            .max_phrases = candidate.max_phrases,
        };
        const collected = try collectPhrasesAlloc(allocator, training_samples, candidate_options);
        defer allocator.free(collected);
        for ([_]TrainRanking{ .total_frequency, .cross_sample }) |ranking| {
            const phrases = try allocator.dupe(Phrase, collected);
            defer allocator.free(phrases);
            sortPhrases(phrases, ranking);
            for ([_]TrainLayout{ .ranked, .best_near_end }) |layout| {
                for (target_sizes, best) |target_size, *entry| {
                    if (target_size == 0) continue;
                    const trained = try assembleDictionaryAlloc(allocator, phrases, target_size, layout);
                    errdefer allocator.free(trained);
                    try retainValidatedCandidate(allocator, &match_index_scratch, entry, trained, validation_samples, options.min_phrase_len);
                }
            }
        }
    }

    // Phrase concatenation is effective for repeated local substrings but can
    // destroy longer record structure. Keep one raw corpus-tail candidate so
    // validation can retain naturally adjacent bytes when that structure
    // generalizes better to held-out payloads.
    for (target_sizes, best) |target_size, *entry| {
        if (target_size == 0) {
            entry.bytes = try allocator.alloc(u8, 0);
            continue;
        }
        const tail = try trainSampleTailAlloc(allocator, training_samples, target_size);
        errdefer allocator.free(tail);
        try retainValidatedCandidate(allocator, &match_index_scratch, entry, tail, validation_samples, options.min_phrase_len);
    }

    const dictionaries = try allocator.alloc(?[]u8, target_sizes.len);
    var initialized: usize = 0;
    errdefer {
        for (dictionaries[0..initialized]) |dictionary| if (dictionary) |bytes| allocator.free(bytes);
        allocator.free(dictionaries);
    }
    for (best, dictionaries) |*entry, *dictionary| {
        dictionary.* = entry.bytes orelse try allocator.alloc(u8, 0);
        entry.bytes = null;
        initialized += 1;
    }
    return .{ .dictionaries = dictionaries };
}

fn retainValidatedCandidate(
    allocator: std.mem.Allocator,
    match_index_scratch: *DictionaryMatchIndexScratch,
    best: *ValidatedBest,
    candidate: []u8,
    validation_samples: []const []const u8,
    min_match_len: usize,
) !void {
    const match_index = try match_index_scratch.build(allocator, candidate, min_match_len);
    var covered: usize = 0;
    var matches: usize = 0;
    var distance_bits: usize = 0;
    for (validation_samples) |sample| {
        const summary = try summarizeMatchesIndexed(candidate, sample, match_index);
        covered = std.math.add(usize, covered, summary.covered_bytes) catch return error.InvalidDictionaryTraining;
        matches = std.math.add(usize, matches, summary.matches) catch return error.InvalidDictionaryTraining;
        distance_bits = std.math.add(usize, distance_bits, summary.distance_bits) catch return error.InvalidDictionaryTraining;
    }
    // Coverage and sequence count dominate. For exact ties, prefer the layout
    // whose matches need fewer offset bits. Candidate enumeration order remains
    // unchanged, so the original ranked layout wins complete ties.
    if (best.bytes == null or covered > best.covered or
        (covered == best.covered and matches < best.matches) or
        (covered == best.covered and matches == best.matches and distance_bits < best.distance_bits))
    {
        if (best.bytes) |bytes| allocator.free(bytes);
        best.* = .{ .bytes = candidate, .covered = covered, .matches = matches, .distance_bits = distance_bits };
    } else allocator.free(candidate);
}

fn trainSampleTailAlloc(allocator: std.mem.Allocator, samples: []const []const u8, target_size: usize) ![]u8 {
    var available: usize = 0;
    for (samples) |sample| available = std.math.add(usize, available, sample.len) catch return error.InvalidDictionaryTraining;
    const len = @min(available, target_size);
    const dictionary = try allocator.alloc(u8, len);
    errdefer allocator.free(dictionary);
    var written = len;
    var sample_index = samples.len;
    while (written != 0 and sample_index != 0) {
        sample_index -= 1;
        const sample = samples[sample_index];
        const copy_len = @min(written, sample.len);
        written -= copy_len;
        @memcpy(dictionary[written..][0..copy_len], sample[sample.len - copy_len ..]);
    }
    return dictionary;
}

fn phraseBetter(_: void, lhs: Phrase, rhs: Phrase) bool {
    if (lhs.score != rhs.score) return lhs.score > rhs.score;
    if (lhs.bytes.len != rhs.bytes.len) return lhs.bytes.len > rhs.bytes.len;
    return std.mem.lessThan(u8, lhs.bytes, rhs.bytes);
}

fn phraseCrossSampleBetter(_: void, lhs: Phrase, rhs: Phrase) bool {
    if (lhs.sample_count != rhs.sample_count) return lhs.sample_count > rhs.sample_count;
    return phraseBetter({}, lhs, rhs);
}

fn findPhrase(phrases: []const Phrase, bytes: []const u8) ?usize {
    for (phrases, 0..) |phrase, i| {
        if (std.mem.eql(u8, phrase.bytes, bytes)) return i;
    }
    return null;
}

fn initializePhraseIndex(allocator: std.mem.Allocator, indexes: *PhraseIndex, phrases: []const Phrase) !void {
    try indexes.ensureUnusedCapacity(allocator, @intCast(phrases.len));
    for (phrases, 0..) |phrase, index| {
        putPhraseIndexAssumeCapacity(indexes.slots.items, std.hash_map.hashString(phrase.bytes), index);
        indexes.count += 1;
    }
}

test "dictionary phrase index handles collisions and backward-shift deletion" {
    const phrases = [_]Phrase{
        .{ .bytes = "alpha", .score = 1 },
        .{ .bytes = "omega", .score = 1 },
        .{ .bytes = "sigma", .score = 1 },
    };
    var index: PhraseIndex = .{};
    defer index.deinit(std.testing.allocator);
    try index.slots.resize(std.testing.allocator, 8);
    @memset(index.slots.items, .{});
    const collision_hash: u64 = 7;
    for (0..phrases.len) |phrase_index| {
        putPhraseIndexAssumeCapacity(index.slots.items, collision_hash, phrase_index);
        index.count += 1;
    }

    for (phrases, 0..) |phrase, phrase_index|
        try std.testing.expectEqual(phrase_index, index.getWithHash(&phrases, phrase.bytes, collision_hash).?);
    index.removeWithHash(collision_hash, 1);
    try std.testing.expectEqual(@as(usize, 0), index.getWithHash(&phrases, "alpha", collision_hash).?);
    try std.testing.expect(index.getWithHash(&phrases, "omega", collision_hash) == null);
    try std.testing.expectEqual(@as(usize, 2), index.getWithHash(&phrases, "sigma", collision_hash).?);
    try std.testing.expectEqual(@as(usize, 2), index.count);
}

test "dictionary phrase index growth releases every allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var storage: [600][4]u8 = undefined;
            var phrases: [storage.len]Phrase = undefined;
            var index: PhraseIndex = .{};
            defer index.deinit(allocator);
            for (&storage, &phrases, 0..) |*bytes, *phrase, i| {
                std.mem.writeInt(u32, bytes, @intCast(i + 1), .little);
                phrase.* = .{ .bytes = bytes, .score = 1 };
                try index.put(allocator, bytes, i);
            }
            try std.testing.expect(index.slots.items.len >= 1024);
            try std.testing.expectEqual(phrases.len, index.count);
            for (&storage, 0..) |*bytes, i|
                try std.testing.expectEqual(i, index.get(&phrases, bytes).?);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}

fn initializePhraseHeap(
    allocator: std.mem.Allocator,
    heap: *std.ArrayList(usize),
    positions: *std.ArrayList(usize),
    phrases: []const Phrase,
) !void {
    try heap.resize(allocator, phrases.len);
    try positions.resize(allocator, phrases.len);
    for (heap.items, positions.items, 0..) |*entry, *position, index| {
        entry.* = index;
        position.* = index;
    }
    var index = heap.items.len / 2;
    while (index != 0) {
        index -= 1;
        phraseHeapSiftDown(heap.items, positions.items, phrases, index);
    }
}

fn phraseHeapSiftUp(heap: []usize, positions: []usize, phrases: []const Phrase, start: usize) void {
    var child = start;
    while (child != 0) {
        const parent = (child - 1) / 2;
        if (!phraseHeapEntryWorse(phrases, heap[child], heap[parent])) break;
        phraseHeapSwap(heap, positions, child, parent);
        child = parent;
    }
}

fn phraseHeapSiftDown(heap: []usize, positions: []usize, phrases: []const Phrase, start: usize) void {
    var parent = start;
    while (true) {
        const left = parent * 2 + 1;
        if (left >= heap.len) return;
        const right = left + 1;
        var worst = left;
        if (right < heap.len and phraseHeapEntryWorse(phrases, heap[right], heap[left])) worst = right;
        if (!phraseHeapEntryWorse(phrases, heap[worst], heap[parent])) return;
        phraseHeapSwap(heap, positions, parent, worst);
        parent = worst;
    }
}

fn phraseHeapEntryWorse(phrases: []const Phrase, lhs: usize, rhs: usize) bool {
    if (phraseWorse(phrases[lhs], phrases[rhs])) return true;
    if (phraseWorse(phrases[rhs], phrases[lhs])) return false;
    // The reference scan retains the first (lowest-index) member of an equal
    // worst rank. Include that index in the heap order to remain byte-exact.
    return lhs < rhs;
}

fn phraseHeapSwap(heap: []usize, positions: []usize, a: usize, b: usize) void {
    std.mem.swap(usize, &heap[a], &heap[b]);
    positions[heap[a]] = a;
    positions[heap[b]] = b;
}

const PhraseReplacement = struct { index: usize, removed: []const u8 };

fn replaceWorstPhraseIfBetter(phrases: []Phrase, candidate: Phrase) ?PhraseReplacement {
    if (phrases.len == 0) return null;
    var worst_i: usize = 0;
    for (phrases[1..], 1..) |phrase, i| {
        if (phraseWorse(phrase, phrases[worst_i])) worst_i = i;
    }
    if (!phraseBetter({}, candidate, phrases[worst_i])) return null;
    const removed = phrases[worst_i].bytes;
    phrases[worst_i] = candidate;
    return .{ .index = worst_i, .removed = removed };
}

fn phraseWorse(lhs: Phrase, rhs: Phrase) bool {
    return phraseBetter({}, rhs, lhs);
}

fn containsSlice(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

pub const TrainingPlan = struct {
    target_size: usize,
    sample_count: usize,
    total_sample_bytes: usize,
};

pub const Match = struct {
    sample_offset: usize,
    dictionary_offset: usize,
    length: usize,
};

pub const MatchSummary = struct {
    matches: usize = 0,
    covered_bytes: usize = 0,
    longest: usize = 0,
    distance_bits: usize = 0,

    pub fn coverageRatio(self: MatchSummary, sample_len: usize) f64 {
        if (sample_len == 0) return 0.0;
        return @as(f64, @floatFromInt(self.covered_bytes)) / @as(f64, @floatFromInt(sample_len));
    }
};

pub const ValidationScore = struct {
    estimated_bits: usize = 0,
    covered_bytes: usize = 0,
    matches: usize = 0,
    distance_bits: usize = 0,
};

/// Estimate dictionary-coded wire cost without depending on a particular
/// codec's encoder heuristics. Each unmatched byte costs eight bits; each match
/// pays its offset width plus a conservative four-bit sequence overhead.
/// Including dictionary storage makes target-size candidates comparable rather
/// than rewarding larger histories solely for marginal extra coverage.
pub fn validationScoreAlloc(
    allocator: std.mem.Allocator,
    dict: []const u8,
    samples: []const []const u8,
    min_match_len: usize,
) !ValidationScore {
    _ = allocator;
    return validationScore(dict, samples, min_match_len);
}

/// Estimate dictionary-coded wire cost without temporary allocations.
pub fn validationScore(
    dict: []const u8,
    samples: []const []const u8,
    min_match_len: usize,
) !ValidationScore {
    var score: ValidationScore = .{ .estimated_bits = std.math.mul(usize, dict.len, 8) catch return error.InvalidDictionaryTraining };
    for (samples) |sample| {
        const summary = try summarizeMatches(dict, sample, min_match_len);
        score.covered_bytes = std.math.add(usize, score.covered_bytes, summary.covered_bytes) catch return error.InvalidDictionaryTraining;
        score.matches = std.math.add(usize, score.matches, summary.matches) catch return error.InvalidDictionaryTraining;
        score.distance_bits = std.math.add(usize, score.distance_bits, summary.distance_bits) catch return error.InvalidDictionaryTraining;
        const literal_bits = std.math.mul(usize, sample.len - summary.covered_bytes, 8) catch return error.InvalidDictionaryTraining;
        score.estimated_bits = std.math.add(usize, score.estimated_bits, literal_bits) catch return error.InvalidDictionaryTraining;
        score.estimated_bits = std.math.add(usize, score.estimated_bits, summary.distance_bits) catch return error.InvalidDictionaryTraining;
        const match_overhead = std.math.mul(usize, summary.matches, 4) catch return error.InvalidDictionaryTraining;
        score.estimated_bits = std.math.add(usize, score.estimated_bits, match_overhead) catch return error.InvalidDictionaryTraining;
    }
    return score;
}

pub fn planTraining(samples: []const []const u8, target_size: usize) TrainingPlan {
    var total: usize = 0;
    for (samples) |sample| total += sample.len;
    return .{ .target_size = target_size, .sample_count = samples.len, .total_sample_bytes = total };
}

pub fn findMatchesAlloc(allocator: std.mem.Allocator, dict: []const u8, sample: []const u8, min_match_len: usize) ![]Match {
    if (min_match_len == 0) return error.InvalidDictionaryTraining;
    var matches: std.ArrayList(Match) = .empty;
    errdefer matches.deinit(allocator);
    var i: usize = 0;
    while (i + min_match_len <= sample.len) {
        const best = findBestDictionaryMatch(dict, sample[i..], min_match_len);
        if (best.length >= min_match_len) {
            try matches.append(allocator, .{ .sample_offset = i, .dictionary_offset = best.offset, .length = best.length });
            i += best.length;
        } else {
            i += 1;
        }
    }
    return matches.toOwnedSlice(allocator);
}

pub fn summarizeMatchesAlloc(allocator: std.mem.Allocator, dict: []const u8, sample: []const u8, min_match_len: usize) !MatchSummary {
    _ = allocator;
    return summarizeMatches(dict, sample, min_match_len);
}

/// Summarize the same greedy dictionary matches as `findMatchesAlloc` without
/// materializing an intermediate match list.
pub fn summarizeMatches(dict: []const u8, sample: []const u8, min_match_len: usize) !MatchSummary {
    if (min_match_len == 0) return error.InvalidDictionaryTraining;
    var summary = MatchSummary{};
    var sample_offset: usize = 0;
    while (sample_offset + min_match_len <= sample.len) {
        const best = findBestDictionaryMatch(dict, sample[sample_offset..], min_match_len);
        if (best.length < min_match_len) {
            sample_offset += 1;
            continue;
        }
        summary.matches += 1;
        summary.covered_bytes += best.length;
        summary.longest = @max(summary.longest, best.length);
        const logical_position = std.math.add(usize, dict.len, sample_offset) catch return error.InvalidDictionaryTraining;
        const distance = logical_position - best.offset;
        summary.distance_bits += std.math.log2_int(usize, distance) + 1;
        sample_offset += best.length;
    }
    return summary;
}

fn summarizeMatchesIndexed(dict: []const u8, sample: []const u8, index: DictionaryMatchIndex) !MatchSummary {
    var summary: MatchSummary = .{};
    var sample_offset: usize = 0;
    while (sample_offset + index.min_match_len <= sample.len) {
        const best = index.findBest(dict, sample[sample_offset..]);
        if (best.length < index.min_match_len) {
            sample_offset += 1;
            continue;
        }
        summary.matches += 1;
        summary.covered_bytes += best.length;
        summary.longest = @max(summary.longest, best.length);
        const logical_position = std.math.add(usize, dict.len, sample_offset) catch return error.InvalidDictionaryTraining;
        const distance = logical_position - best.offset;
        summary.distance_bits += std.math.log2_int(usize, distance) + 1;
        sample_offset += best.length;
    }
    return summary;
}

pub fn encodePatchAlloc(allocator: std.mem.Allocator, dict: []const u8, sample: []const u8, min_match_len: usize) ![]u8 {
    if (min_match_len == 0) return error.InvalidDictionaryTraining;
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, &patch_magic);
    try out.append(allocator, patch_version);
    try appendInt(u32, allocator, &out, @intCast(min_match_len));
    try appendInt(u64, allocator, &out, @intCast(sample.len));
    var i: usize = 0;
    while (i < sample.len) {
        const best = findBestDictionaryMatch(dict, sample[i..], min_match_len);
        if (best.length >= min_match_len) {
            try out.append(allocator, op_match);
            try appendInt(u16, allocator, &out, @intCast(best.offset));
            try appendInt(u16, allocator, &out, @intCast(best.length));
            i += best.length;
        } else {
            const literal_start = i;
            i += 1;
            while (i < sample.len) : (i += 1) {
                const next = findBestDictionaryMatch(dict, sample[i..], min_match_len);
                if (next.length >= min_match_len) break;
            }
            try out.append(allocator, op_literal);
            if (i - literal_start > std.math.maxInt(u16)) return error.InvalidDictionaryTraining;
            try appendInt(u16, allocator, &out, @intCast(i - literal_start));
            try out.appendSlice(allocator, sample[literal_start..i]);
        }
    }
    return out.toOwnedSlice(allocator);
}

const PatchHeader = struct {
    min_match_len: u32,
    expected_len: usize,
};

fn parsePatchHeader(patch: []const u8) !PatchHeader {
    if (patch.len < patch_header_len) return error.TruncatedFrame;
    if (!std.mem.eql(u8, patch[0..4], &patch_magic)) return error.InvalidMagic;
    if (patch[4] != patch_version) return error.UnsupportedVersion;
    const min_match_len = std.mem.readInt(u32, patch[5..9], .little);
    if (min_match_len == 0) return error.InvalidDictionaryTraining;
    const expected_len = std.mem.readInt(u64, patch[9..17], .little);
    const expected_usize = std.math.cast(usize, expected_len) orelse return error.IntegerOverflow;
    return .{ .min_match_len = min_match_len, .expected_len = expected_usize };
}

pub fn decodedPatchSize(patch: []const u8) !usize {
    return (try parsePatchHeader(patch)).expected_len;
}

pub fn maxPatchSizeForDecodedLen(decoded_len: usize) !usize {
    // The decoder rejects zero-length literal ops below, so each accepted patch
    // operation must make forward progress. A one-byte match with min_match_len=1
    // is the densest valid opcode encoding: 1 tag byte + 2 offset bytes +
    // 2 length bytes for one decoded byte. Literals are at most 4 bytes per
    // decoded byte when split into single-byte literal ops.
    const body = std.math.mul(usize, decoded_len, 5) catch return error.IntegerOverflow;
    return std.math.add(usize, patch_header_len, body) catch return error.IntegerOverflow;
}

pub fn decodePatch(dict: []const u8, patch: []const u8, output: []u8) !usize {
    return decodePatchInto(dict, patch, output);
}

pub fn decodePatchInto(dict: []const u8, patch: []const u8, output: []u8) !usize {
    const header = try parsePatchHeader(patch);
    if (output.len < header.expected_len) return error.OutputTooSmall;
    var written: usize = 0;
    var offset: usize = patch_header_len;
    while (offset < patch.len) {
        const tag = patch[offset];
        offset += 1;
        switch (tag) {
            op_literal => {
                if (patch.len - offset < 2) return error.TruncatedFrame;
                const len: usize = std.mem.readInt(u16, patch[offset..][0..2], .little);
                offset += 2;
                if (len == 0) return error.CorruptFrame;
                if (patch.len - offset < len) return error.TruncatedFrame;
                try copyDecodedPatchBytes(output, &written, header.expected_len, patch[offset..][0..len]);
                offset += len;
            },
            op_match => {
                if (patch.len - offset < 4) return error.TruncatedFrame;
                const dict_offset: usize = std.mem.readInt(u16, patch[offset..][0..2], .little);
                const len: usize = std.mem.readInt(u16, patch[offset + 2 ..][0..2], .little);
                offset += 4;
                if (len < header.min_match_len) return error.CorruptFrame;
                if (dict_offset > dict.len or dict.len - dict_offset < len) return error.TruncatedFrame;
                try copyDecodedPatchBytes(output, &written, header.expected_len, dict[dict_offset..][0..len]);
            },
            else => return error.CorruptFrame,
        }
    }
    if (written != header.expected_len) return error.SizeMismatch;
    return written;
}

fn copyDecodedPatchBytes(output: []u8, written: *usize, expected_len: usize, source: []const u8) !void {
    // Decode-into callers often hand us a larger scratch/output buffer. The
    // patch header remains the authority for the logical result length, so
    // reject overlong opcode streams before they can write beyond that length.
    if (written.* > expected_len) return error.SizeMismatch;
    if (source.len > expected_len - written.*) return error.SizeMismatch;
    if (output.len - written.* < source.len) return error.OutputTooSmall;
    @memcpy(output[written.*..][0..source.len], source);
    written.* += source.len;
}

pub fn decodePatchAlloc(allocator: std.mem.Allocator, dict: []const u8, patch: []const u8) ![]u8 {
    const expected_usize = try decodedPatchSize(patch);
    const out = try allocator.alloc(u8, expected_usize);
    errdefer allocator.free(out);
    const written = try decodePatchInto(dict, patch, out);
    std.debug.assert(written == expected_usize);
    return out;
}

fn appendInt(comptime T: type, allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: T) !void {
    var buf: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &buf, value, .little);
    try out.appendSlice(allocator, &buf);
}

const DictionaryMatchCandidate = struct {
    offset: usize = 0,
    length: usize = 0,
};

fn findBestDictionaryMatch(dict: []const u8, sample: []const u8, min_match_len: usize) DictionaryMatchCandidate {
    var best = DictionaryMatchCandidate{};
    if (dict.len < min_match_len or sample.len < min_match_len) return best;
    var offset: usize = 0;
    while (offset + min_match_len <= dict.len) : (offset += 1) {
        if (!std.mem.eql(u8, dict[offset..][0..min_match_len], sample[0..min_match_len])) continue;
        const max_len = @min(dict.len - offset, sample.len);
        var len = min_match_len;
        while (len < max_len and dict[offset + len] == sample[len]) len += 1;
        if (len > best.length) best = .{ .offset = offset, .length = len };
    }
    return best;
}

test "dictionary IDs are stable and content sensitive" {
    const a = DictionaryId.fromBytes("dictionary contents");
    const b = DictionaryId.fromBytes("dictionary contents");
    const c = DictionaryId.fromBytes("different contents");
    try std.testing.expectEqual(a.asInt(), b.asInt());
    try std.testing.expect(a.asInt() != c.asInt());
}

test "dictionary metadata codec is fixed size and versioned" {
    const meta = Metadata.fromBytes("dictionary contents", 64 * 1024);

    var encoded: [metadata_encoded_len]u8 = undefined;
    try std.testing.expectEqual(metadata_encoded_len, try meta.encodeInto(&encoded));
    try std.testing.expectEqualSlices(u8, &metadata_magic, encoded[0..4]);
    try std.testing.expectEqual(metadata_version, encoded[4]);

    const decoded = try Metadata.decode(&encoded);
    try std.testing.expectEqual(meta.id.asInt(), decoded.id.asInt());
    try std.testing.expectEqual(meta.content_len, decoded.content_len);
    try std.testing.expectEqual(meta.window_len, decoded.window_len);

    const owned = try encodeMetadataAlloc(std.testing.allocator, meta);
    defer std.testing.allocator.free(owned);
    try std.testing.expectEqualSlices(u8, &encoded, owned);
    try std.testing.expectEqual(meta.id.asInt(), (try decodeMetadata(owned)).id.asInt());

    var prefixed = std.ArrayList(u8).empty;
    defer prefixed.deinit(std.testing.allocator);
    try prefixed.appendSlice(std.testing.allocator, &encoded);
    try prefixed.append(std.testing.allocator, 0xff);
    const prefix = try decodeMetadataPrefix(prefixed.items);
    try std.testing.expectEqual(meta.id.asInt(), prefix.metadata.id.asInt());
    try std.testing.expectEqual(metadata_encoded_len, prefix.bytes_read);
    try std.testing.expectError(error.TrailingData, decodeMetadata(prefixed.items));
}

test "dictionary metadata codec rejects malformed records" {
    const meta = Metadata.fromBytes("dictionary contents", 64 * 1024);
    var encoded: [metadata_encoded_len]u8 = undefined;
    _ = try encodeMetadataInto(meta, &encoded);

    var short_out: [metadata_encoded_len - 1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, encodeMetadataInto(meta, &short_out));
    try std.testing.expectError(error.TruncatedFrame, decodeMetadata(encoded[0 .. metadata_encoded_len - 1]));

    var bad_magic = encoded;
    bad_magic[0] = 'x';
    try std.testing.expectError(error.InvalidMagic, decodeMetadata(&bad_magic));

    var bad_version = encoded;
    bad_version[4] = metadata_version + 1;
    try std.testing.expectError(error.UnsupportedVersion, decodeMetadata(&bad_version));

    var bad_reserved = encoded;
    bad_reserved[5] = 1;
    try std.testing.expectError(error.CorruptFrame, decodeMetadata(&bad_reserved));
}

test "dictionary metadata catalog codec round trips entries" {
    const entries = [_]Metadata{
        Metadata.fromBytes("first dictionary", 64 * 1024),
        Metadata.fromBytes("second dictionary", 8 * 1024 * 1024),
    };
    const expected_len = metadata_catalog_header_encoded_len + entries.len * metadata_encoded_len;
    try std.testing.expectEqual(expected_len, try encodedMetadataCatalogLen(entries.len));

    const encoded = try encodeMetadataCatalogAlloc(std.testing.allocator, &entries);
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqual(expected_len, encoded.len);
    try std.testing.expectEqualSlices(u8, &metadata_catalog_magic, encoded[0..4]);
    try std.testing.expectEqual(metadata_catalog_version, encoded[4]);
    try std.testing.expectEqual(entries.len, try decodedMetadataCatalogCount(encoded));

    var decoded_into: [entries.len]Metadata = undefined;
    try std.testing.expectEqual(entries.len, try decodeMetadataCatalogInto(encoded, &decoded_into));
    for (entries, decoded_into) |expected, actual| {
        try std.testing.expectEqual(expected.id.asInt(), actual.id.asInt());
        try std.testing.expectEqual(expected.content_len, actual.content_len);
        try std.testing.expectEqual(expected.window_len, actual.window_len);
    }

    const decoded = try decodeMetadataCatalogAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(entries.len, decoded.len);
    for (entries, decoded) |expected, actual| {
        try std.testing.expectEqual(expected.id.asInt(), actual.id.asInt());
        try std.testing.expectEqual(expected.content_len, actual.content_len);
        try std.testing.expectEqual(expected.window_len, actual.window_len);
    }

    const empty_encoded = try encodeMetadataCatalogAlloc(std.testing.allocator, &.{});
    defer std.testing.allocator.free(empty_encoded);
    try std.testing.expectEqual(metadata_catalog_header_encoded_len, empty_encoded.len);
    try std.testing.expectEqual(@as(usize, 0), try decodedMetadataCatalogCount(empty_encoded));
    var empty_decoded: [0]Metadata = .{};
    try std.testing.expectEqual(@as(usize, 0), try decodeMetadataCatalogInto(empty_encoded, &empty_decoded));
}

test "dictionary metadata catalog codec rejects malformed records" {
    const entries = [_]Metadata{
        Metadata.fromBytes("first dictionary", 64 * 1024),
        Metadata.fromBytes("second dictionary", 8 * 1024 * 1024),
    };
    const encoded = try encodeMetadataCatalogAlloc(std.testing.allocator, &entries);
    defer std.testing.allocator.free(encoded);

    var short_out: [metadata_catalog_header_encoded_len - 1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, encodeMetadataCatalogInto(&entries, &short_out));
    try std.testing.expectError(error.TruncatedFrame, decodedMetadataCatalogCount(encoded[0 .. metadata_catalog_header_encoded_len - 1]));

    var bad_magic = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_magic);
    bad_magic[0] = 'x';
    try std.testing.expectError(error.InvalidMagic, decodedMetadataCatalogCount(bad_magic));

    var bad_version = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_version);
    bad_version[4] = metadata_catalog_version + 1;
    try std.testing.expectError(error.UnsupportedVersion, decodedMetadataCatalogCount(bad_version));

    var bad_reserved = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_reserved);
    bad_reserved[5] = 1;
    try std.testing.expectError(error.CorruptFrame, decodedMetadataCatalogCount(bad_reserved));

    var short_entries: [entries.len - 1]Metadata = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodeMetadataCatalogInto(encoded, &short_entries));
    try std.testing.expectError(error.TruncatedFrame, decodeMetadataCatalogAlloc(std.testing.allocator, encoded[0 .. encoded.len - 1]));

    var trailing = std.ArrayList(u8).empty;
    defer trailing.deinit(std.testing.allocator);
    try trailing.appendSlice(std.testing.allocator, encoded);
    try trailing.append(std.testing.allocator, 0xff);
    try std.testing.expectEqual(entries.len, try decodedMetadataCatalogCount(trailing.items));
    var decoded: [entries.len]Metadata = undefined;
    const prefix = try decodeMetadataCatalogPrefixInto(trailing.items, &decoded);
    try std.testing.expectEqual(entries.len, prefix.count);
    try std.testing.expectEqual(encoded.len, prefix.bytes_read);
    try std.testing.expectEqual(entries[0].id.asInt(), decoded[0].id.asInt());
    const prefix_alloc = try decodeMetadataCatalogPrefixAlloc(std.testing.allocator, trailing.items);
    defer prefix_alloc.deinit(std.testing.allocator);
    try std.testing.expectEqual(encoded.len, prefix_alloc.bytes_read);
    try std.testing.expectEqual(entries.len, prefix_alloc.metadata.len);
    try std.testing.expectError(error.TrailingData, decodeMetadataCatalogInto(trailing.items, &decoded));

    var corrupt_entry = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(corrupt_entry);
    corrupt_entry[metadata_catalog_header_encoded_len] = 'x';
    try std.testing.expectError(error.InvalidMagic, decodeMetadataCatalogInto(corrupt_entry, &decoded));
}

test "dictionary metadata validates content and window" {
    const dict = "dictionary contents";
    const meta = Metadata.fromBytes(dict, 64 * 1024);

    try meta.validateBytes(dict, 64 * 1024);
    try std.testing.expect(meta.matchesBytes(dict, 64 * 1024));
    try std.testing.expect(!meta.matchesBytes("different contents", 64 * 1024));
    try std.testing.expect(!meta.matchesBytes(dict, 32 * 1024));
    try std.testing.expectError(error.InvalidDictionaryMetadata, meta.validateBytes("different contents", 64 * 1024));
    try std.testing.expectError(error.InvalidDictionaryMetadata, meta.validateBytes(dict, 32 * 1024));
}

test "training plan summarizes sample corpus" {
    const samples = [_][]const u8{ "alpha", "beta", "gamma" };
    const plan = planTraining(&samples, 1024);
    try std.testing.expectEqual(@as(usize, 1024), plan.target_size);
    try std.testing.expectEqual(@as(usize, 3), plan.sample_count);
    try std.testing.expectEqual(@as(usize, 14), plan.total_sample_bytes);
}

test "dictionary trainer is deterministic and extracts repeated phrases" {
    const samples = [_][]const u8{
        "alpha beta alpha beta alpha beta",
        "gamma alpha beta gamma alpha beta",
    };
    const dict1 = try trainAlloc(std.testing.allocator, &samples, .{ .target_size = 32, .min_phrase_len = 5, .max_phrase_len = 10 });
    defer std.testing.allocator.free(dict1);
    const dict2 = try trainAlloc(std.testing.allocator, &samples, .{ .target_size = 32, .min_phrase_len = 5, .max_phrase_len = 10 });
    defer std.testing.allocator.free(dict2);
    try std.testing.expectEqualSlices(u8, dict1, dict2);
    try std.testing.expect(std.mem.indexOf(u8, dict1, "alpha") != null);
    try std.testing.expect(dict1.len <= 32);
    const meta = Metadata.fromBytes(dict1, 32 * 1024);
    try std.testing.expectEqual(dict1.len, meta.content_len);
}

test "dictionary trainer indexed candidate set matches scan reference" {
    var storage: [8][192]u8 = undefined;
    var samples: [storage.len][]const u8 = undefined;
    for (&storage, &samples, 0..) |*sample, *view, sample_index| {
        var state: u32 = 0x9e37_79b9 +% @as(u32, @intCast(sample_index * 65537));
        for (sample, 0..) |*byte, index| {
            state = state *% 1_664_525 +% 1_013_904_223;
            byte.* = if (index % 23 < 17)
                "dictionary-indexed-reference-corpus-"[(index + sample_index) % 36]
            else
                @truncate(state >> 24);
        }
        view.* = sample;
    }
    const options = [_]TrainOptions{
        .{ .target_size = 96, .min_phrase_len = 4, .max_phrase_len = 16, .max_phrases = 64 },
        .{ .target_size = 192, .min_phrase_len = 3, .max_phrase_len = 12, .max_phrases = 256 },
        .{ .target_size = 384, .min_phrase_len = 6, .max_phrase_len = 24, .max_phrases = 1024 },
    };
    for (options) |train_options| {
        const expected = try trainReferenceAlloc(std.testing.allocator, &samples, train_options);
        defer std.testing.allocator.free(expected);
        const actual = try trainAlloc(std.testing.allocator, &samples, train_options);
        defer std.testing.allocator.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
    }
}

test "dictionary trainer benchmark corpus remains byte exact" {
    const json_pattern = "{\"kind\":\"event\",\"service\":\"vort\",\"status\":\"ok\",\"id\":12345}\n";
    var storage: [24][320]u8 = undefined;
    var samples: [24][]const u8 = undefined;
    for (&storage, &samples, 0..) |*sample, *view, sample_index| {
        for (sample, 0..) |*byte, index| {
            byte.* = json_pattern[(index + sample_index * 3) % json_pattern.len];
        }
        view.* = sample;
    }
    const options: TrainOptions = .{ .target_size = 512, .max_phrases = 1024 };
    const expected = try trainReferenceAlloc(std.testing.allocator, &samples, options);
    defer std.testing.allocator.free(expected);
    const actual = try trainAlloc(std.testing.allocator, &samples, options);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
    var byte_sum: usize = actual.len;
    for (actual) |byte| byte_sum += byte;
    try std.testing.expectEqual(@as(usize, 41_909), byte_sum);
}

fn trainReferenceAlloc(allocator: std.mem.Allocator, samples: []const []const u8, options: TrainOptions) ![]u8 {
    var phrases: std.ArrayList(Phrase) = .empty;
    defer phrases.deinit(allocator);
    for (samples) |sample| {
        if (sample.len < options.min_phrase_len) continue;
        var start: usize = 0;
        while (start + options.min_phrase_len <= sample.len) : (start += 1) {
            const max_len = @min(options.max_phrase_len, sample.len - start);
            var len = options.min_phrase_len;
            while (len <= max_len) : (len += 1) {
                const phrase = sample[start..][0..len];
                if (findPhrase(phrases.items, phrase)) |index|
                    phrases.items[index].score += len
                else if (phrases.items.len < options.max_phrases)
                    try phrases.append(allocator, .{ .bytes = phrase, .score = len })
                else
                    _ = replaceWorstPhraseIfBetter(phrases.items, .{ .bytes = phrase, .score = len });
            }
        }
    }
    std.sort.heap(Phrase, phrases.items, {}, phraseBetter);
    var dictionary: std.ArrayList(u8) = .empty;
    errdefer dictionary.deinit(allocator);
    for (phrases.items) |phrase| {
        if (dictionary.items.len >= options.target_size) break;
        if (containsSlice(dictionary.items, phrase.bytes)) continue;
        const remaining = options.target_size - dictionary.items.len;
        try dictionary.appendSlice(allocator, phrase.bytes[0..@min(remaining, phrase.bytes.len)]);
    }
    return dictionary.toOwnedSlice(allocator);
}

fn trainValidatedReferenceAlloc(
    allocator: std.mem.Allocator,
    training_samples: []const []const u8,
    validation_samples: []const []const u8,
    options: TrainOptions,
) ![]u8 {
    const Candidate = struct { min_phrase_len: usize, max_phrase_len: usize, max_phrases: usize };
    const candidates = [_]Candidate{
        .{ .min_phrase_len = options.min_phrase_len, .max_phrase_len = options.max_phrase_len, .max_phrases = options.max_phrases },
        .{ .min_phrase_len = 3, .max_phrase_len = 12, .max_phrases = @max(options.max_phrases, 512) },
        .{ .min_phrase_len = 4, .max_phrase_len = 24, .max_phrases = @max(options.max_phrases, 512) },
        .{ .min_phrase_len = 6, .max_phrase_len = 32, .max_phrases = @max(options.max_phrases, 1024) },
    };

    var best: ?[]u8 = null;
    errdefer if (best) |bytes| allocator.free(bytes);
    var best_covered: usize = 0;
    var best_matches: usize = 0;
    var best_distance_bits: usize = std.math.maxInt(usize);
    for (candidates) |candidate| {
        for ([_]TrainRanking{ .total_frequency, .cross_sample }) |ranking| {
            for ([_]TrainLayout{ .ranked, .best_near_end }) |layout| {
                const trained = try trainAllocWithLayout(allocator, training_samples, .{
                    .target_size = options.target_size,
                    .min_phrase_len = candidate.min_phrase_len,
                    .max_phrase_len = candidate.max_phrase_len,
                    .max_phrases = candidate.max_phrases,
                }, layout, ranking);
                errdefer allocator.free(trained);
                var covered: usize = 0;
                var matches: usize = 0;
                var distance_bits: usize = 0;
                for (validation_samples) |sample| {
                    const summary = try summarizeMatches(trained, sample, options.min_phrase_len);
                    covered += summary.covered_bytes;
                    matches += summary.matches;
                    distance_bits += summary.distance_bits;
                }
                if (best == null or covered > best_covered or
                    (covered == best_covered and matches < best_matches) or
                    (covered == best_covered and matches == best_matches and distance_bits < best_distance_bits))
                {
                    if (best) |bytes| allocator.free(bytes);
                    best = trained;
                    best_covered = covered;
                    best_matches = matches;
                    best_distance_bits = distance_bits;
                } else allocator.free(trained);
            }
        }
    }

    const tail = try trainSampleTailAlloc(allocator, training_samples, options.target_size);
    errdefer allocator.free(tail);
    var tail_covered: usize = 0;
    var tail_matches: usize = 0;
    var tail_distance_bits: usize = 0;
    for (validation_samples) |sample| {
        const summary = try summarizeMatches(tail, sample, options.min_phrase_len);
        tail_covered += summary.covered_bytes;
        tail_matches += summary.matches;
        tail_distance_bits += summary.distance_bits;
    }
    if (best == null or tail_covered > best_covered or
        (tail_covered == best_covered and tail_matches < best_matches) or
        (tail_covered == best_covered and tail_matches == best_matches and tail_distance_bits < best_distance_bits))
    {
        if (best) |bytes| allocator.free(bytes);
        best = tail;
    } else allocator.free(tail);
    return best orelse try allocator.alloc(u8, 0);
}

test "validated dictionary trainer preserves or improves held-out coverage" {
    const training = [_][]const u8{
        "service=vort region=west status=ok message=alpha alpha alpha",
        "service=vort region=east status=ok message=beta beta beta",
        "service=vort region=north status=warn message=gamma gamma",
    };
    const validation = [_][]const u8{
        "service=vort region=south status=ok message=alpha beta",
        "service=vort region=west status=warn message=gamma alpha",
    };
    const options: TrainOptions = .{ .target_size = 64 };
    const baseline = try trainAlloc(std.testing.allocator, &training, options);
    defer std.testing.allocator.free(baseline);
    const selected = try trainValidatedAlloc(std.testing.allocator, &training, &validation, options);
    defer std.testing.allocator.free(selected);
    const again = try trainValidatedAlloc(std.testing.allocator, &training, &validation, options);
    defer std.testing.allocator.free(again);

    var baseline_covered: usize = 0;
    var selected_covered: usize = 0;
    for (validation) |sample| {
        baseline_covered += (try summarizeMatches(baseline, sample, options.min_phrase_len)).covered_bytes;
        selected_covered += (try summarizeMatches(selected, sample, options.min_phrase_len)).covered_bytes;
    }
    try std.testing.expect(selected_covered >= baseline_covered);
    try std.testing.expectEqualSlices(u8, selected, again);
}

test "COVER-class optimizer selects the best enumerated held-out score" {
    const training = [_][]const u8{
        "service=vort region=west status=ok message=alpha alpha alpha",
        "service=vort region=east status=ok message=beta beta beta",
        "service=vort region=north status=warn message=gamma gamma",
        "service=vort region=south status=retry message=delta delta",
        "service=vort region=central status=ok message=alpha beta gamma",
    };
    const validation = [_][]const u8{
        "service=vort region=west status=retry message=alpha gamma",
        "service=vort region=south status=ok message=delta beta",
    };
    const options: CoverOptimizeOptions = .{
        .target_size = 48,
        .segment_sizes = &.{ 12, 24 },
        .dmer_sizes = &.{ 6, 8 },
        .hash_logs = &.{ 8, 10 },
    };
    var optimized = try trainOptimizedCoverAlloc(std.testing.allocator, &training, &validation, options);
    defer optimized.deinit(std.testing.allocator);
    var again = try trainOptimizedCoverAlloc(std.testing.allocator, &training, &validation, options);
    defer again.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 8), optimized.candidates_evaluated);
    try std.testing.expectEqual(optimized.selected_options, again.selected_options);
    try std.testing.expectEqual(optimized.validation_score, again.validation_score);
    try std.testing.expectEqualSlices(u8, optimized.bytes, again.bytes);

    for (options.dmer_sizes) |dmer_size| {
        for (options.segment_sizes) |segment_size| {
            for (options.hash_logs) |hash_log| {
                const candidate = try trainCoverAlloc(std.testing.allocator, &training, .{
                    .target_size = options.target_size,
                    .segment_size = segment_size,
                    .dmer_size = dmer_size,
                    .hash_log = hash_log,
                });
                defer std.testing.allocator.free(candidate);
                const score = try validationScore(candidate, &validation, options.min_match_len);
                try std.testing.expect(optimized.validation_score.estimated_bits <= score.estimated_bits);
            }
        }
    }
}

test "validated dictionary trainer reuses collection without changing selection" {
    var storage: [8][192]u8 = undefined;
    var samples: [8][]const u8 = undefined;
    for (&storage, &samples, 0..) |*sample, *view, sample_index| {
        var state: u32 = 0x517c_c1b7 +% @as(u32, @intCast(sample_index * 977));
        for (sample, 0..) |*byte, index| {
            state = state *% 1_664_525 +% 1_013_904_223;
            byte.* = if (index % 29 < 23)
                "validated-dictionary-shared-record-"[(index + sample_index * 3) % 35]
            else
                @truncate(state >> 24);
        }
        view.* = sample;
    }
    const training = samples[0..6];
    const validation = samples[6..];
    for ([_]TrainOptions{
        .{ .target_size = 64, .min_phrase_len = 3, .max_phrase_len = 12, .max_phrases = 96 },
        .{ .target_size = 128, .min_phrase_len = 4, .max_phrase_len = 24, .max_phrases = 512 },
    }) |options| {
        const expected = try trainValidatedReferenceAlloc(std.testing.allocator, training, validation, options);
        defer std.testing.allocator.free(expected);
        const actual = try trainValidatedAlloc(std.testing.allocator, training, validation, options);
        defer std.testing.allocator.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
    }
}

test "validated dictionary trainer shares phrase scans across target sizes" {
    var storage: [8][192]u8 = undefined;
    var samples: [8][]const u8 = undefined;
    for (&storage, &samples, 0..) |*sample, *view, sample_index| {
        var state: u32 = 0x85eb_ca6b +% @as(u32, @intCast(sample_index * 8191));
        for (sample, 0..) |*byte, index| {
            state = state *% 1_664_525 +% 1_013_904_223;
            byte.* = if (index % 31 < 25)
                "multi-target-validation-record-"[(index + sample_index * 5) % 31]
            else
                @truncate(state >> 24);
        }
        view.* = sample;
    }
    const training = samples[0..6];
    const validation = samples[6..];
    for ([_]TrainOptions{
        .{ .target_size = 128, .min_phrase_len = 3, .max_phrase_len = 12, .max_phrases = 96 },
        .{ .target_size = 128, .min_phrase_len = 4, .max_phrase_len = 24, .max_phrases = 512 },
    }) |options| {
        const targets = [_]usize{ 128, 96, 64, 32, 0, 64 };
        const actual = try trainValidatedTargetsAlloc(std.testing.allocator, training, validation, &targets, options);
        defer actual.deinit(std.testing.allocator);
        for (targets, actual.dictionaries) |target_size, maybe_dictionary| {
            var target_options = options;
            target_options.target_size = target_size;
            const expected = try trainValidatedReferenceAlloc(std.testing.allocator, training, validation, target_options);
            defer std.testing.allocator.free(expected);
            try std.testing.expectEqualSlices(u8, expected, maybe_dictionary.?);
        }
    }
}

test "validated target training releases every allocation failure path" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const training = [_][]const u8{
                "alpha shared record one",
                "alpha shared record two",
            };
            const validation = [_][]const u8{"alpha shared record three"};
            var trained = try trainValidatedTargetsAlloc(
                allocator,
                &training,
                &validation,
                &.{ 32, 16, 0 },
                .{ .target_size = 32, .max_phrases = 32 },
            );
            defer trained.deinit(allocator);
            const taken = trained.take(1) orelse return error.InvalidDictionaryTraining;
            defer allocator.free(taken);
            try std.testing.expectEqual(@as(?[]u8, null), trained.take(1));
            try std.testing.expectEqual(@as(?[]u8, null), trained.take(99));
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}

test "dictionary trainer handles empty target" {
    const samples = [_][]const u8{"sample"};
    const dict = try trainAlloc(std.testing.allocator, &samples, .{ .target_size = 0 });
    defer std.testing.allocator.free(dict);
    try std.testing.expectEqual(@as(usize, 0), dict.len);
    const validated = try trainValidatedAlloc(
        std.testing.allocator,
        &samples,
        &samples,
        .{ .target_size = 0, .min_phrase_len = 2, .max_phrase_len = 1 },
    );
    defer std.testing.allocator.free(validated);
    try std.testing.expectEqual(@as(usize, 0), validated.len);
    const empty_targets = try trainValidatedTargetsAlloc(
        std.testing.allocator,
        &samples,
        &samples,
        &.{ 0, 0 },
        .{ .target_size = 0, .min_phrase_len = 2, .max_phrase_len = 1 },
    );
    defer empty_targets.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), empty_targets.dictionaries.len);
    for (empty_targets.dictionaries) |dictionary| try std.testing.expectEqual(@as(usize, 0), dictionary.?.len);
    const no_targets = try trainValidatedTargetsAlloc(
        std.testing.allocator,
        &samples,
        &samples,
        &.{},
        .{ .target_size = 0, .min_phrase_len = 2, .max_phrase_len = 1 },
    );
    defer no_targets.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), no_targets.dictionaries.len);
}

test "dictionary trainer replaces low-value phrase candidates" {
    var phrases = [_]Phrase{
        .{ .bytes = "low", .score = 3 },
        .{ .bytes = "mid", .score = 5 },
    };
    _ = replaceWorstPhraseIfBetter(&phrases, .{ .bytes = "valuable", .score = 32 });
    try std.testing.expect(std.mem.eql(u8, phrases[0].bytes, "valuable") or std.mem.eql(u8, phrases[1].bytes, "valuable"));
}

test "cross-sample phrase ranking prefers corpus-wide phrases" {
    const local = Phrase{ .bytes = "local", .score = 100, .sample_count = 1 };
    const shared = Phrase{ .bytes = "shared", .score = 40, .sample_count = 3 };
    try std.testing.expect(phraseBetter({}, local, shared));
    try std.testing.expect(phraseCrossSampleBetter({}, shared, local));
}

test "dictionary match scanner summarizes coverage" {
    const dict = "alpha beta gamma";
    const sample = "zz alpha beta yy gamma";
    const matches = try findMatchesAlloc(std.testing.allocator, dict, sample, 5);
    defer std.testing.allocator.free(matches);
    try std.testing.expectEqual(@as(usize, 2), matches.len);
    try std.testing.expectEqual(@as(usize, 3), matches[0].sample_offset);
    try std.testing.expect(matches[0].length >= "alpha beta".len);

    const summary = try summarizeMatches(dict, sample, 5);
    try std.testing.expectEqual(matches.len, summary.matches);
    try std.testing.expect(summary.covered_bytes >= "alpha beta".len + "gamma".len);
    try std.testing.expect(summary.coverageRatio(sample.len) > 0.0);
    try std.testing.expectEqual(summary, try summarizeMatchesAlloc(std.testing.failing_allocator, dict, sample, 5));
    const samples = [_][]const u8{sample};
    try std.testing.expectEqual(
        try validationScore(dict, &samples, 5),
        try validationScoreAlloc(std.testing.failing_allocator, dict, &samples, 5),
    );
}

test "streaming dictionary match summary equals materialized oracle" {
    var dictionary: [96]u8 = undefined;
    var sample: [257]u8 = undefined;
    var state: u32 = 0x9e37_79b9;
    for (&dictionary) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    for (&sample, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 37 < 23) dictionary[(index * 7) % (dictionary.len - 24)] else @truncate(state >> 24);
    }
    for ([_]usize{ 1, 3, 4, 8, 16, 97, 300 }) |min_match_len| {
        const matches = try findMatchesAlloc(std.testing.allocator, &dictionary, &sample, min_match_len);
        defer std.testing.allocator.free(matches);
        var expected: MatchSummary = .{ .matches = matches.len };
        for (matches) |match| {
            expected.covered_bytes += match.length;
            expected.longest = @max(expected.longest, match.length);
            const distance = dictionary.len + match.sample_offset - match.dictionary_offset;
            expected.distance_bits += std.math.log2_int(usize, distance) + 1;
        }
        try std.testing.expectEqual(expected, try summarizeMatches(&dictionary, &sample, min_match_len));
    }
    try std.testing.expectError(error.InvalidDictionaryTraining, summarizeMatches(&dictionary, &sample, 0));
}

test "dictionary prefix index matches linear scan and preserves earliest ties" {
    var dictionary: [257]u8 = undefined;
    var sample: [383]u8 = undefined;
    var state: u32 = 0x243f_6a88;
    for (&dictionary) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    for (&sample, 0..) |*byte, position| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (position % 41 < 27) dictionary[(position * 11) % (dictionary.len - 32)] else @truncate(state >> 24);
    }

    var scratch: DictionaryMatchIndexScratch = .{};
    defer scratch.deinit(std.testing.allocator);
    for ([_]usize{ 1, 2, 3, 4, 8, 16, 64, 258 }) |min_match_len| {
        const index = try scratch.build(std.testing.allocator, &dictionary, min_match_len);
        for (0..sample.len + 1) |position| {
            const expected = findBestDictionaryMatch(&dictionary, sample[position..], min_match_len);
            const actual = index.findBest(&dictionary, sample[position..]);
            try std.testing.expectEqual(expected, actual);
        }
        try std.testing.expectEqual(
            try summarizeMatches(&dictionary, &sample, min_match_len),
            try summarizeMatchesIndexed(&dictionary, &sample, index),
        );
    }

    const repeated = "abcXabcY";
    const repeated_index = try scratch.build(std.testing.allocator, repeated, 3);
    try std.testing.expectEqual(
        DictionaryMatchCandidate{ .offset = 0, .length = 3 },
        repeated_index.findBest(repeated, "abcZ"),
    );
}

test "dictionary patch codec round trips matched and literal bytes" {
    const dict = "alpha beta gamma";
    const sample = "zz alpha beta yy gamma";
    const patch = try encodePatchAlloc(std.testing.allocator, dict, sample, 5);
    defer std.testing.allocator.free(patch);
    try std.testing.expectEqual(sample.len, try decodedPatchSize(patch));
    const decoded = try decodePatchAlloc(std.testing.allocator, dict, patch);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, sample, decoded);
    var out: [sample.len]u8 = undefined;
    try std.testing.expectEqual(sample.len, try decodePatchInto(dict, patch, &out));
    try std.testing.expectEqualSlices(u8, sample, &out);
    try std.testing.expect(patch.len < sample.len + patch_header_len + 16);
}

test "dictionary patch uses compact match op encoding" {
    const dict = "alpha beta gamma";
    const sample = "alpha beta";
    const patch = try encodePatchAlloc(std.testing.allocator, dict, sample, 5);
    defer std.testing.allocator.free(patch);
    try std.testing.expectEqual(@as(usize, patch_header_len + 1 + 2 + 2), patch.len);
    const decoded = try decodePatchAlloc(std.testing.allocator, dict, patch);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, sample, decoded);
}

test "dictionary patch decode into rejects short output and overlong op streams" {
    const dict = "alpha beta gamma";
    const sample = "alpha beta";
    const patch = try encodePatchAlloc(std.testing.allocator, dict, sample, 5);
    defer std.testing.allocator.free(patch);

    var short: [sample.len - 1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodePatchInto(dict, patch, &short));

    const corrupt = try std.testing.allocator.dupe(u8, patch);
    defer std.testing.allocator.free(corrupt);
    std.mem.writeInt(u16, corrupt[patch_header_len + 3 ..][0..2], @intCast(sample.len + 1), .little);
    var out: [sample.len + 1]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, decodePatchInto(dict, corrupt, &out));
}

test "dictionary patch rejects non-progress literal ops" {
    const patch = try encodePatchAlloc(std.testing.allocator, "", "", 1);
    defer std.testing.allocator.free(patch);
    try std.testing.expectEqual(patch_header_len, patch.len);
    try std.testing.expectEqual(patch_header_len, try maxPatchSizeForDecodedLen(0));
    try std.testing.expectEqual(@as(usize, patch_header_len + 5), try maxPatchSizeForDecodedLen(1));

    var corrupt = std.ArrayList(u8).empty;
    defer corrupt.deinit(std.testing.allocator);
    try corrupt.appendSlice(std.testing.allocator, patch);
    try corrupt.append(std.testing.allocator, op_literal);
    try appendInt(u16, std.testing.allocator, &corrupt, 0);
    var out: [0]u8 = .{};
    try std.testing.expectError(error.CorruptFrame, decodePatchInto("", corrupt.items, &out));
}
