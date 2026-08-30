const std = @import("std");
const checksum = @import("checksum.zig");

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

const Phrase = struct {
    bytes: []const u8,
    score: usize,
};

pub fn trainAlloc(allocator: std.mem.Allocator, samples: []const []const u8, options: TrainOptions) ![]u8 {
    if (options.target_size == 0) return allocator.alloc(u8, 0);
    if (options.min_phrase_len == 0 or options.min_phrase_len > options.max_phrase_len) return error.InvalidDictionaryTraining;

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
                if (findPhrase(phrases.items, phrase)) |idx| {
                    phrases.items[idx].score += len;
                } else if (phrases.items.len < options.max_phrases) {
                    try phrases.append(allocator, .{ .bytes = phrase, .score = len });
                } else {
                    replaceWorstPhraseIfBetter(phrases.items, .{ .bytes = phrase, .score = len });
                }
            }
        }
    }

    std.sort.heap(Phrase, phrases.items, {}, phraseBetter);

    var dict: std.ArrayList(u8) = .empty;
    errdefer dict.deinit(allocator);
    for (phrases.items) |phrase| {
        if (dict.items.len >= options.target_size) break;
        if (containsSlice(dict.items, phrase.bytes)) continue;
        const remaining = options.target_size - dict.items.len;
        try dict.appendSlice(allocator, phrase.bytes[0..@min(remaining, phrase.bytes.len)]);
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
    for (candidates) |candidate| {
        const trained = try trainAlloc(allocator, training_samples, .{
            .target_size = options.target_size,
            .min_phrase_len = candidate.min_phrase_len,
            .max_phrase_len = candidate.max_phrase_len,
            .max_phrases = candidate.max_phrases,
        });
        errdefer allocator.free(trained);
        var covered: usize = 0;
        var matches: usize = 0;
        for (validation_samples) |sample| {
            const summary = try summarizeMatchesAlloc(allocator, trained, sample, options.min_phrase_len);
            covered = std.math.add(usize, covered, summary.covered_bytes) catch return error.InvalidDictionaryTraining;
            matches = std.math.add(usize, matches, summary.matches) catch return error.InvalidDictionaryTraining;
        }
        // Prefer more covered bytes, then fewer match operations (longer useful
        // phrases). The first baseline candidate wins complete ties.
        if (best == null or covered > best_covered or
            (covered == best_covered and matches < best_matches))
        {
            if (best) |bytes| allocator.free(bytes);
            best = trained;
            best_covered = covered;
            best_matches = matches;
        } else allocator.free(trained);
    }
    return best orelse try allocator.alloc(u8, 0);
}

fn findPhrase(phrases: []const Phrase, bytes: []const u8) ?usize {
    for (phrases, 0..) |phrase, i| {
        if (std.mem.eql(u8, phrase.bytes, bytes)) return i;
    }
    return null;
}

fn phraseBetter(_: void, lhs: Phrase, rhs: Phrase) bool {
    if (lhs.score != rhs.score) return lhs.score > rhs.score;
    if (lhs.bytes.len != rhs.bytes.len) return lhs.bytes.len > rhs.bytes.len;
    return std.mem.lessThan(u8, lhs.bytes, rhs.bytes);
}

fn replaceWorstPhraseIfBetter(phrases: []Phrase, candidate: Phrase) void {
    if (phrases.len == 0) return;
    var worst_i: usize = 0;
    for (phrases[1..], 1..) |phrase, i| {
        if (phraseWorse(phrase, phrases[worst_i])) worst_i = i;
    }
    if (phraseBetter({}, candidate, phrases[worst_i])) phrases[worst_i] = candidate;
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

    pub fn coverageRatio(self: MatchSummary, sample_len: usize) f64 {
        if (sample_len == 0) return 0.0;
        return @as(f64, @floatFromInt(self.covered_bytes)) / @as(f64, @floatFromInt(sample_len));
    }
};

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
    const matches = try findMatchesAlloc(allocator, dict, sample, min_match_len);
    defer allocator.free(matches);
    var summary = MatchSummary{};
    summary.matches = matches.len;
    for (matches) |match| {
        summary.covered_bytes += match.length;
        summary.longest = @max(summary.longest, match.length);
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
        baseline_covered += (try summarizeMatchesAlloc(std.testing.allocator, baseline, sample, options.min_phrase_len)).covered_bytes;
        selected_covered += (try summarizeMatchesAlloc(std.testing.allocator, selected, sample, options.min_phrase_len)).covered_bytes;
    }
    try std.testing.expect(selected_covered >= baseline_covered);
    try std.testing.expectEqualSlices(u8, selected, again);
}

test "dictionary trainer handles empty target" {
    const samples = [_][]const u8{"sample"};
    const dict = try trainAlloc(std.testing.allocator, &samples, .{ .target_size = 0 });
    defer std.testing.allocator.free(dict);
    try std.testing.expectEqual(@as(usize, 0), dict.len);
}

test "dictionary trainer replaces low-value phrase candidates" {
    var phrases = [_]Phrase{
        .{ .bytes = "low", .score = 3 },
        .{ .bytes = "mid", .score = 5 },
    };
    replaceWorstPhraseIfBetter(&phrases, .{ .bytes = "valuable", .score = 32 });
    try std.testing.expect(std.mem.eql(u8, phrases[0].bytes, "valuable") or std.mem.eql(u8, phrases[1].bytes, "valuable"));
}

test "dictionary match scanner summarizes coverage" {
    const dict = "alpha beta gamma";
    const sample = "zz alpha beta yy gamma";
    const matches = try findMatchesAlloc(std.testing.allocator, dict, sample, 5);
    defer std.testing.allocator.free(matches);
    try std.testing.expectEqual(@as(usize, 2), matches.len);
    try std.testing.expectEqual(@as(usize, 3), matches[0].sample_offset);
    try std.testing.expect(matches[0].length >= "alpha beta".len);

    const summary = try summarizeMatchesAlloc(std.testing.allocator, dict, sample, 5);
    try std.testing.expectEqual(matches.len, summary.matches);
    try std.testing.expect(summary.covered_bytes >= "alpha beta".len + "gamma".len);
    try std.testing.expect(summary.coverageRatio(sample.len) > 0.0);
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
