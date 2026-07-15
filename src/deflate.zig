const std = @import("std");
const checksum = @import("checksum.zig");
const bitstream = @import("bitstream.zig");
const huffman = @import("huffman.zig");
const lz77 = @import("lz77.zig");
const core = @import("core.zig");

pub const Error = core.Error;
pub const max_stored_block_len: usize = std.math.maxInt(u16);

pub const DecodeResult = struct {
    input_read: usize,
    output_written: usize,
};

pub const ParserMode = enum { hash, greedy, lazy, optimal };
pub const CompressionStrategy = enum { default, filtered, huffman_only, rle };

pub const BlockSelection = enum { stored_fixed, stored_fixed_dynamic };

pub const CompressionOptions = struct {
    parser: ParserMode = .greedy,
    strategy: CompressionStrategy = .default,
    lz77_options: lz77.GreedyOptions = .{},
    block_selection: BlockSelection = .stored_fixed_dynamic,
    split_options: AdaptiveSplitOptions = .{},
};

pub const CompressionLevel = enum { fastest, fast, default, best };

pub const GzipHeaderOptions = struct {
    /// Set the advisory FTEXT flag. Decoders must not rely on this bit for
    /// correctness, but exposing it keeps Vort able to reproduce metadata-rich
    /// gzip streams emitted by legacy tools.
    text: bool = false,
    /// Modification time in Unix seconds, serialized little-endian per RFC
    /// 1952. The default stays zero so existing encoders remain deterministic.
    mtime: u32 = 0,
    /// Extra flags byte. Existing Vort gzip encoders used 4, matching the
    /// "fastest algorithm" hint often emitted for level-0/fast streams.
    xfl: u8 = 0x04,
    /// Operating-system identifier. The default 3 preserves the historical
    /// Unix-compatible header used by this project.
    os: u8 = 0x03,
    /// Optional FEXTRA payload. A non-null empty slice intentionally emits an
    /// XLEN=0 field; null omits FEXTRA entirely.
    extra: ?[]const u8 = null,
    /// Optional zero-terminated original file name. Embedded NUL bytes are
    /// rejected because they would truncate the field for standard decoders.
    filename: ?[]const u8 = null,
    /// Optional zero-terminated comment. Embedded NUL bytes are rejected for
    /// the same reason as filename.
    comment: ?[]const u8 = null,
    /// Emit FHCRC over the gzip header bytes before the CRC field. The value is
    /// the low 16 bits of the standard gzip CRC-32, which lets the existing
    /// parser validate generated metadata without a separate checksum path.
    header_crc: bool = false,
};

pub fn optionsForLevel(level: CompressionLevel) CompressionOptions {
    return switch (level) {
        .fastest => .{ .parser = .hash, .lz77_options = .{ .window_len = 8 * 1024, .max_chain = 4, .nice_len = 8, .max_candidates = 1, .lazy_min_gain = 3, .min_match = 4, .max_match = 64, .min_savings_bits = 8 }, .block_selection = .stored_fixed, .split_options = .{ .min_block_len = 32 * 1024, .max_block_len = max_stored_block_len, .sample_len = 1024, .search_step = 32 * 1024 } },
        .fast => .{ .parser = .hash, .lz77_options = .{ .window_len = 16 * 1024, .max_chain = 32, .nice_len = 16, .max_candidates = 2, .lazy_min_gain = 3, .min_match = 4, .max_match = 128, .min_savings_bits = 4 }, .block_selection = .stored_fixed, .split_options = .{ .min_block_len = 16 * 1024, .max_block_len = max_stored_block_len, .sample_len = 2048, .search_step = 16 * 1024 } },
        .default => .{ .parser = .lazy, .lz77_options = .{ .window_len = lz77.default_window_len, .max_chain = 128, .nice_len = 64, .max_candidates = 4, .lazy_min_gain = 1, .min_match = 3, .max_match = lz77.max_match_len, .min_savings_bits = 1 }, .split_options = .{ .min_block_len = 8 * 1024, .max_block_len = max_stored_block_len, .sample_len = 4096, .search_step = 8 * 1024 } },
        .best => .{ .parser = .optimal, .lz77_options = .{ .window_len = lz77.default_window_len, .max_chain = 512, .nice_len = 128, .max_candidates = lz77.max_optimal_candidates, .lazy_min_gain = 1, .min_match = 3, .max_match = lz77.max_match_len, .min_savings_bits = 0 }, .split_options = .{ .min_block_len = 4 * 1024, .max_block_len = max_stored_block_len, .sample_len = 8192, .search_step = 4 * 1024 } },
    };
}

pub const OwnedDecodeResult = struct {
    bytes: []u8,
    input_read: usize,

    pub fn deinit(self: OwnedDecodeResult, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

pub fn normalizeOptionsForStrategy(options: CompressionOptions) CompressionOptions {
    var normalized = options;
    switch (normalized.strategy) {
        .default => {},
        .filtered => {
            normalized.lz77_options.min_match = @max(normalized.lz77_options.min_match, 5);
            normalized.lz77_options.min_savings_bits = @max(normalized.lz77_options.min_savings_bits, 8);
            normalized.lz77_options.max_candidates = @min(normalized.lz77_options.max_candidates, 2);
        },
        .huffman_only => {
            normalized.lz77_options.max_chain = 0;
            normalized.lz77_options.max_candidates = 0;
            normalized.lz77_options.min_savings_bits = std.math.maxInt(usize);
        },
        .rle => {
            normalized.lz77_options.window_len = 1;
            normalized.lz77_options.max_candidates = 1;
            normalized.lz77_options.min_match = @max(normalized.lz77_options.min_match, 3);
        },
    }
    return normalized;
}

fn planTokensAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) !lz77.GreedyPlan {
    const normalized = normalizeOptionsForStrategy(options);
    return switch (normalized.strategy) {
        .default => switch (normalized.parser) {
            .hash => if (useSmallInputScanPlan(input, normalized))
                try lz77.greedyPlanAlloc(allocator, input, normalized.lz77_options)
            else if (useTinyHashPlan(input, normalized))
                try lz77.hashGreedyPlanTinyAlloc(allocator, input, normalized.lz77_options)
            else
                try lz77.hashGreedyPlanAlloc(allocator, input, normalized.lz77_options),
            .greedy => try lz77.greedyPlanAlloc(allocator, input, normalized.lz77_options),
            .lazy => try lz77.lazyGreedyPlanAlloc(allocator, input, normalized.lz77_options),
            .optimal => try lz77.optimalPlanAlloc(allocator, input, normalized.lz77_options),
        },
        .filtered => try lz77.filteredPlanAlloc(allocator, input, normalized.lz77_options),
        .huffman_only => try lz77.literalPlanAlloc(allocator, input),
        .rle => try lz77.runLengthPlanAlloc(allocator, input, normalized.lz77_options),
    };
}

fn useSmallInputScanPlan(input: []const u8, options: CompressionOptions) bool {
    // The greedy scan is fastest for truly tiny inputs because it avoids even a
    // small hash-table clear. It still sees the entire bounded search space at
    // these sizes, so it preserves the practical parsing behavior for the
    // small CLI/API payloads where fixed parser overhead dominates.
    return options.parser == .hash and
        options.strategy == .default and
        input.len <= 256 and
        options.lz77_options.window_len <= 16 * 1024;
}

fn useTinyHashPlan(input: []const u8, options: CompressionOptions) bool {
    // Hash parser setup allocates and clears tens of KiB of tables. For tiny
    // and small one-shot payloads this fixed cost dominates compression time.
    // A stack-resident 4 Ki slot table preserves hash-parser behavior while
    // avoiding the full 32 Ki table clear. Keep the threshold below most normal
    // split blocks so large inputs retain the production table size.
    return options.parser == .hash and
        options.strategy == .default and
        input.len > 256 and
        (input.len <= 24 * 1024 or (input.len <= 32 * 1024 and uniqueByteCount(input[0..@min(input.len, 1024)]) <= 8)) and
        options.lz77_options.window_len <= 16 * 1024;
}

fn planTokensWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: CompressionOptions) !lz77.GreedyPlan {
    const normalized = normalizeOptionsForStrategy(options);
    if (dictionary.len == 0) return planTokensAlloc(allocator, input, normalized);
    return switch (normalized.strategy) {
        .default => switch (normalized.parser) {
            .hash, .greedy => try lz77.hashGreedyPlanAllocWithDictionary(allocator, input, dictionary, normalized.lz77_options),
            .lazy, .optimal => try lz77.lazyGreedyPlanAllocWithDictionary(allocator, input, dictionary, normalized.lz77_options),
        },
        .filtered => try lz77.lazyGreedyPlanAllocWithDictionary(allocator, input, dictionary, normalized.lz77_options),
        .huffman_only => try lz77.literalPlanAlloc(allocator, input),
        .rle => try lz77.runLengthPlanAlloc(allocator, input, normalized.lz77_options),
    };
}

pub fn encodeRawBestAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    if (usesStoredFastPath(input, options)) return encodeRawStoredAlloc(allocator, input);
    const plan = try planTokensAlloc(allocator, input, options);
    defer plan.deinit(allocator);
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    try writeBestTokensBlock(allocator, &writer, input, plan.tokens, true, options);
    return writer.toOwnedSlice(allocator);
}

pub fn usesStoredFastPath(input: []const u8, options: CompressionOptions) bool {
    if (input.len < 8 * 1024) return false;
    const normalized = normalizeOptionsForStrategy(options);
    if (normalized.strategy != .default) return false;
    if (normalized.parser != .hash and normalized.parser != .lazy) return false;
    if (normalized.parser == .lazy and normalized.block_selection != .stored_fixed_dynamic) return false;
    if (normalized.parser == .hash and normalized.block_selection != .stored_fixed) return false;
    return looksIncompressible(input);
}

fn looksIncompressible(input: []const u8) bool {
    const sample_len = @min(input.len, 1024);
    if (uniqueByteCount(input[0..sample_len]) < 240) return false;
    const word_count = sample_len -| 3;
    if (word_count < 2) return false;
    var words: [1024]u32 = undefined;
    for (words[0..word_count], 0..) |*word, i| {
        word.* = std.mem.readInt(u32, input[i..][0..4], .little);
    }
    std.mem.sort(u32, words[0..word_count], {}, std.sort.asc(u32));
    var repeats: usize = 0;
    for (words[1..word_count], 1..) |word, i| {
        if (word == words[i - 1]) {
            repeats += 1;
            if (repeats >= 4) return false;
        }
    }
    return true;
}

pub fn encodeRawBestWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: CompressionOptions) ![]u8 {
    if (usesStoredFastPath(input, options)) return encodeRawStoredAlloc(allocator, input);
    const plan = try planTokensWithDictionaryAlloc(allocator, input, dictionary, options);
    defer plan.deinit(allocator);
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    try writeBestTokensBlock(allocator, &writer, input, plan.tokens, true, options);
    return writer.toOwnedSlice(allocator);
}

pub const DynamicPlanStats = struct {
    input_bytes: usize,
    token_count: usize,
    literal_tokens: usize,
    match_tokens: usize,
    matched_bytes: usize,
    match_distance_sum: usize,
    short_match_tokens: usize,
    far_match_tokens: usize,
    avg_match_len_x100: usize,
    avg_match_distance: usize,
    stored_bytes: usize,
    fixed_bits: usize,
    fixed_bytes: usize,
    dynamic_header_bits: usize,
    dynamic_literal_bits: usize,
    dynamic_length_bits: usize,
    dynamic_distance_bits: usize,
    dynamic_length_extra_bits: usize,
    dynamic_distance_extra_bits: usize,
    dynamic_extra_bits: usize,
    length_symbol_hist: [length_table.len]usize,
    distance_symbol_hist: [distance_table.len]usize,
    length_extra_hist: [6]usize,
    distance_extra_hist: [14]usize,
    dynamic_bits: usize,
    dynamic_bytes: usize,
    hlit: usize,
    hdist: usize,
    hclen: usize,
    code_length_ops: usize,
};

pub fn dynamicPlanStatsAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) !DynamicPlanStats {
    const plan = try planTokensAlloc(allocator, input, options);
    defer plan.deinit(allocator);
    const dynamic_plan = try DynamicCodingPlan.init(plan.tokens);
    const fixed_bits = lz77.fixedBitCost(plan.tokens);
    const dynamic_bits = dynamic_plan.bitCost(plan.tokens);
    var dynamic_literal_bits: usize = 0;
    var dynamic_length_bits: usize = 0;
    var dynamic_distance_bits: usize = 0;
    var dynamic_length_extra_bits: usize = 0;
    var dynamic_distance_extra_bits: usize = 0;
    var length_symbol_hist: [length_table.len]usize = @splat(0);
    var distance_symbol_hist: [distance_table.len]usize = @splat(0);
    var length_extra_hist: [6]usize = @splat(0);
    var distance_extra_hist: [14]usize = @splat(0);
    var match_distance_sum: usize = 0;
    var short_match_tokens: usize = 0;
    var far_match_tokens: usize = 0;
    for (plan.tokens) |token| switch (token) {
        .literal => |byte| dynamic_literal_bits += dynamic_plan.lit_lengths_full[byte],
        .match => |m| {
            const len_code = lengthCode(m.length);
            const dist_code = distanceCode(m.distance);
            dynamic_length_bits += dynamic_plan.lit_lengths_full[len_code.symbol];
            dynamic_distance_bits += dynamic_plan.dist_lengths_full[dist_code.symbol];
            dynamic_length_extra_bits += len_code.extra_bits;
            dynamic_distance_extra_bits += dist_code.extra_bits;
            length_symbol_hist[len_code.symbol - 257] += 1;
            distance_symbol_hist[dist_code.symbol] += 1;
            length_extra_hist[len_code.extra_bits] += 1;
            distance_extra_hist[dist_code.extra_bits] += 1;
            match_distance_sum += m.distance;
            if (m.length <= 8) short_match_tokens += 1;
            if (m.distance > 8 * 1024) far_match_tokens += 1;
        },
    };
    dynamic_literal_bits += dynamic_plan.lit_lengths_full[256];
    const dynamic_extra_bits = dynamic_length_extra_bits + dynamic_distance_extra_bits;
    const dynamic_payload_bits = dynamic_literal_bits + dynamic_length_bits + dynamic_distance_bits + dynamic_extra_bits;
    return .{
        .input_bytes = input.len,
        .token_count = plan.stats.tokenCount(),
        .literal_tokens = plan.stats.literals,
        .match_tokens = plan.stats.matches,
        .matched_bytes = plan.stats.matched_bytes,
        .match_distance_sum = match_distance_sum,
        .short_match_tokens = short_match_tokens,
        .far_match_tokens = far_match_tokens,
        .avg_match_len_x100 = if (plan.stats.matches == 0) 0 else (plan.stats.matched_bytes * 100) / plan.stats.matches,
        .avg_match_distance = if (plan.stats.matches == 0) 0 else match_distance_sum / plan.stats.matches,
        .stored_bytes = try rawStoredEncodedSize(input.len),
        .fixed_bits = fixed_bits,
        .fixed_bytes = (fixed_bits + 7) / 8,
        .dynamic_header_bits = dynamic_bits - dynamic_payload_bits,
        .dynamic_literal_bits = dynamic_literal_bits,
        .dynamic_length_bits = dynamic_length_bits,
        .dynamic_distance_bits = dynamic_distance_bits,
        .dynamic_length_extra_bits = dynamic_length_extra_bits,
        .dynamic_distance_extra_bits = dynamic_distance_extra_bits,
        .dynamic_extra_bits = dynamic_extra_bits,
        .length_symbol_hist = length_symbol_hist,
        .distance_symbol_hist = distance_symbol_hist,
        .length_extra_hist = length_extra_hist,
        .distance_extra_hist = distance_extra_hist,
        .dynamic_bits = dynamic_bits,
        .dynamic_bytes = (dynamic_bits + 7) / 8,
        .hlit = dynamic_plan.hlit,
        .hdist = dynamic_plan.hdist,
        .hclen = dynamic_plan.hclen,
        .code_length_ops = dynamic_plan.code_len_ops.len,
    };
}

pub fn encodeRawBestSplitAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
    if (block_len == 0) return error.InvalidBlockPlan;
    if (usesStoredFastPath(input, options)) return encodeRawStoredSplitAlloc(allocator, input, block_len);
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    try writeBestSplitBlocks(allocator, &writer, input, null, block_len, options);
    return writer.toOwnedSlice(allocator);
}

pub fn encodeRawBestSplitWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
    if (block_len == 0) return error.InvalidBlockPlan;
    if (usesStoredFastPath(input, options)) return encodeRawStoredSplitAlloc(allocator, input, block_len);
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    try writeBestSplitBlocks(allocator, &writer, input, dictionary, block_len, options);
    return writer.toOwnedSlice(allocator);
}

fn writeBestSplitBlocks(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, input: []const u8, dictionary: ?[]const u8, block_len: usize, options: CompressionOptions) !void {
    if (block_len == 0) return error.InvalidBlockPlan;
    const effective_block_len = @min(block_len, max_stored_block_len);
    if (input.len == 0) {
        const plan = if (dictionary) |dict|
            try planTokensWithDictionaryAlloc(allocator, "", dict, options)
        else
            try planTokensAlloc(allocator, "", options);
        defer plan.deinit(allocator);
        return writeBestTokensBlock(allocator, writer, "", plan.tokens, true, options);
    }
    var offset: usize = 0;
    while (offset < input.len) {
        const n = @min(effective_block_len, input.len - offset);
        const chunk = input[offset..][0..n];
        const final = offset + n == input.len;
        const plan = if (dictionary) |dict|
            if (offset == 0)
                try planTokensWithDictionaryAlloc(allocator, chunk, dict, options)
            else
                try planTokensAlloc(allocator, chunk, options)
        else
            try planTokensAlloc(allocator, chunk, options);
        defer plan.deinit(allocator);
        try writeBestTokensBlock(allocator, writer, chunk, plan.tokens, final, options);
        offset += n;
    }
}

pub const AdaptiveSplitOptions = struct {
    min_block_len: usize = 16 * 1024,
    max_block_len: usize = max_stored_block_len,
    sample_len: usize = 4096,
    search_step: usize = 4096,
};

pub fn encodeRawBestAdaptiveSplitAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) ![]u8 {
    if (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len) return error.InvalidBlockPlan;
    if (usesStoredFastPath(input, options)) return encodeRawStoredAlloc(allocator, input);
    const one_shot = try encodeRawBestAlloc(allocator, input, options);
    errdefer allocator.free(one_shot);
    if (shouldSkipAdaptiveSplitSearch(input.len, split_options)) return one_shot;
    var writer = bitstream.BitWriter{};
    defer writer.deinit(allocator);
    try writeBestAdaptiveSplitBlocks(allocator, &writer, input, null, options, split_options);
    return smallerAdaptiveOrOneShot(allocator, &writer, one_shot);
}

pub fn encodeRawBestAdaptiveSplitWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) ![]u8 {
    if (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len) return error.InvalidBlockPlan;
    if (usesStoredFastPath(input, options)) return encodeRawStoredAlloc(allocator, input);
    const one_shot = try encodeRawBestWithDictionaryAlloc(allocator, input, dictionary, options);
    errdefer allocator.free(one_shot);
    if (shouldSkipAdaptiveSplitSearch(input.len, split_options)) return one_shot;
    var writer = bitstream.BitWriter{};
    defer writer.deinit(allocator);
    try writeBestAdaptiveSplitBlocks(allocator, &writer, input, dictionary, options, split_options);
    return smallerAdaptiveOrOneShot(allocator, &writer, one_shot);
}

fn writeBestAdaptiveSplitBlocks(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, input: []const u8, dictionary: ?[]const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) !void {
    if (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len) return error.InvalidBlockPlan;
    const max_block_len = @min(split_options.max_block_len, max_stored_block_len);
    const min_block_len = @min(split_options.min_block_len, max_block_len);
    if (input.len == 0) {
        const plan = if (dictionary) |dict|
            try planTokensWithDictionaryAlloc(allocator, "", dict, options)
        else
            try planTokensAlloc(allocator, "", options);
        defer plan.deinit(allocator);
        return writeBestTokensBlock(allocator, writer, "", plan.tokens, true, options);
    }
    var offset: usize = 0;
    while (offset < input.len) {
        const remaining = input.len - offset;
        const n = try chooseCostedAdaptiveBlockLen(allocator, input[offset..], min_block_len, max_block_len, split_options.sample_len, split_options.search_step, options);
        const chunk_len = @min(n, remaining);
        const chunk = input[offset..][0..chunk_len];
        const final = offset + chunk_len == input.len;
        const plan = if (dictionary) |dict|
            if (offset == 0)
                try planTokensWithDictionaryAlloc(allocator, chunk, dict, options)
            else
                try planTokensAlloc(allocator, chunk, options)
        else
            try planTokensAlloc(allocator, chunk, options);
        defer plan.deinit(allocator);
        try writeBestTokensBlock(allocator, writer, chunk, plan.tokens, final, options);
        offset += chunk_len;
    }
}

fn smallerAdaptiveOrOneShot(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, one_shot: []u8) ![]u8 {
    const adaptive = try writer.toOwnedSlice(allocator);
    errdefer allocator.free(adaptive);
    if (adaptive.len < one_shot.len) {
        allocator.free(one_shot);
        return adaptive;
    }
    allocator.free(adaptive);
    return one_shot;
}

fn shouldSkipAdaptiveSplitSearch(input_len: usize, split_options: AdaptiveSplitOptions) bool {
    // The production split presets use a full stored-block-sized max block.
    // For one- or two-block inputs the adaptive search mostly redoes the
    // already-computed one-shot plan several times before falling back to that
    // one-shot frame. Keep small custom split experiments intact by only
    // short-circuiting full-window policies.
    return split_options.max_block_len >= max_stored_block_len and
        input_len <= max_stored_block_len * 2;
}

fn chooseCostedAdaptiveBlockLen(allocator: std.mem.Allocator, input: []const u8, min_block_len: usize, max_block_len: usize, sample_len: usize, search_step: usize, options: CompressionOptions) !usize {
    const heuristic = chooseAdaptiveBlockLen(input, min_block_len, max_block_len, sample_len);
    if (input.len <= min_block_len) return heuristic;
    const limit = @min(input.len, max_block_len);
    const step = @max(search_step, 1);
    var best_len = heuristic;
    var best_score = try scoreSplitCandidate(allocator, input, best_len, options);
    var candidate = min_block_len;
    while (candidate <= limit) : (candidate += step) {
        const score = try scoreSplitCandidate(allocator, input, candidate, options);
        if (score < best_score) {
            best_score = score;
            best_len = candidate;
        }
        if (limit - candidate < step) break;
    }
    if (best_len != limit) {
        const score = try scoreSplitCandidate(allocator, input, limit, options);
        if (score < best_score) best_len = limit;
    }
    return best_len;
}

fn scoreSplitCandidate(allocator: std.mem.Allocator, input: []const u8, candidate_len: usize, options: CompressionOptions) !usize {
    const len = @min(candidate_len, input.len);
    const plan = try planTokensAlloc(allocator, input[0..len], options);
    defer plan.deinit(allocator);
    const stored = len + 5;
    const fixed = (lz77.fixedBitCost(plan.tokens) + 7) / 8;
    if (options.block_selection == .stored_fixed) return @min(stored, fixed);
    const dynamic = (try dynamicTokenBitCost(plan.tokens) + 7) / 8;
    return @min(@min(stored, fixed), dynamic);
}

fn chooseAdaptiveBlockLen(input: []const u8, min_block_len: usize, max_block_len: usize, sample_len: usize) usize {
    if (input.len <= min_block_len) return input.len;
    const sample = input[0..@min(input.len, @max(sample_len, 1))];
    const unique = uniqueByteCount(sample);
    if (unique <= 4 and input.len >= min_block_len) return min_block_len;
    if (unique <= 32) return @min(input.len, @max(min_block_len, max_block_len / 2));
    return @min(input.len, max_block_len);
}

fn uniqueByteCount(input: []const u8) usize {
    var seen: [256]bool = @splat(false);
    var count: usize = 0;
    for (input) |byte| {
        if (!seen[byte]) {
            seen[byte] = true;
            count += 1;
        }
    }
    return count;
}

fn writeBestTokensBlock(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, plain: []const u8, tokens: []const lz77.Token, final: bool, options: CompressionOptions) !void {
    const stored_len = storedBlocksEncodedSizeFromState(writer.*, plain.len);
    const fixed_len = encodedBytesForBitsFromState(writer.*, lz77.fixedBitCost(tokens));

    if (options.block_selection == .stored_fixed) {
        if (stored_len <= fixed_len) {
            return writeStoredBlocks(allocator, writer, plain, final);
        }
        try writer.bytes.ensureTotalCapacity(allocator, writer.bytes.items.len + fixed_len);
        return writeFixedTokens(allocator, writer, tokens, final);
    }

    const dynamic_plan = try DynamicCodingPlan.init(tokens);
    const dynamic_len = encodedBytesForBitsFromState(writer.*, dynamic_plan.bitCost(tokens));
    if (stored_len <= fixed_len and stored_len <= dynamic_len) {
        return writeStoredBlocks(allocator, writer, plain, final);
    }
    if (fixed_len <= dynamic_len) {
        try writer.bytes.ensureTotalCapacity(allocator, writer.bytes.items.len + fixed_len);
        return writeFixedTokens(allocator, writer, tokens, final);
    }
    try writer.bytes.ensureTotalCapacity(allocator, writer.bytes.items.len + dynamic_len);
    return dynamic_plan.write(allocator, writer, tokens, final);
}

fn encodedBytesForBitsFromState(writer: bitstream.BitWriter, bit_count: usize) usize {
    return (@as(usize, writer.bit_index) + bit_count + 7) / 8;
}

fn storedBlockEncodedSizeFromState(writer: bitstream.BitWriter, input_len: usize) usize {
    const header_bytes: usize = (@as(usize, writer.bit_index) + 3 + 7) / 8;
    return input_len + 4 + header_bytes;
}

fn storedBlocksEncodedSizeFromState(writer: bitstream.BitWriter, input_len: usize) usize {
    if (input_len <= max_stored_block_len) return storedBlockEncodedSizeFromState(writer, input_len);
    const blocks = ((input_len - 1) / max_stored_block_len) + 1;
    const first = storedBlockEncodedSizeFromState(writer, max_stored_block_len);
    return first + (input_len - max_stored_block_len) + (blocks - 1) * 5;
}

fn writeStoredBlocks(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, input: []const u8, final: bool) !void {
    if (input.len <= max_stored_block_len) return writeStoredBlock(allocator, writer, input, final);
    var offset: usize = 0;
    while (offset < input.len) {
        const n = @min(max_stored_block_len, input.len - offset);
        const chunk_final = final and offset + n == input.len;
        try writeStoredBlock(allocator, writer, input[offset..][0..n], chunk_final);
        offset += n;
    }
}

fn writeStoredBlock(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, input: []const u8, final: bool) !void {
    if (input.len > max_stored_block_len) return error.InvalidBlockPlan;
    try writer.writeBits(allocator, @intFromBool(final), 1);
    try writer.writeBits(allocator, 0b00, 2);
    try writer.alignToByte(allocator);
    var lengths: [4]u8 = undefined;
    const len: u16 = @intCast(input.len);
    std.mem.writeInt(u16, lengths[0..2], len, .little);
    std.mem.writeInt(u16, lengths[2..4], ~len, .little);
    try writer.bytes.appendSlice(allocator, &lengths);
    try writer.bytes.appendSlice(allocator, input);
}

pub fn encodeRawFixedSplitAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
    if (block_len == 0) return error.InvalidBlockPlan;
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    var offset: usize = 0;
    if (input.len == 0) {
        const plan = try lz77.hashGreedyPlanAlloc(allocator, "", options.lz77_options);
        defer plan.deinit(allocator);
        try writeFixedTokens(allocator, &writer, plan.tokens, true);
        return writer.toOwnedSlice(allocator);
    }
    while (offset < input.len) {
        const n = @min(block_len, input.len - offset);
        const final = offset + n == input.len;
        const plan = try planTokensAlloc(allocator, input[offset..][0..n], options);
        defer plan.deinit(allocator);
        try writeFixedTokens(allocator, &writer, plan.tokens, final);
        offset += n;
    }
    return writer.toOwnedSlice(allocator);
}

pub fn encodeRawDynamicLiteralAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const plan = try lz77.literalPlanAlloc(allocator, input);
    defer plan.deinit(allocator);
    return encodeRawDynamicTokensAlloc(allocator, plan.tokens);
}

pub fn encodeRawDynamicWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    const plan = try planTokensAlloc(allocator, input, options);
    defer plan.deinit(allocator);
    return encodeRawDynamicTokensAlloc(allocator, plan.tokens);
}

pub fn encodeRawDynamicWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: CompressionOptions) ![]u8 {
    const plan = try planTokensWithDictionaryAlloc(allocator, input, dictionary, options);
    defer plan.deinit(allocator);
    return encodeRawDynamicTokensAlloc(allocator, plan.tokens);
}

const CodeLengthOp = struct {
    symbol: u8,
    extra_bits: u6 = 0,
    extra_value: u8 = 0,
};

const max_dynamic_code_length_ops = 286 + 30;

const CodeLengthOpBuffer = struct {
    items: [max_dynamic_code_length_ops]CodeLengthOp = undefined,
    len: usize = 0,

    fn append(self: *CodeLengthOpBuffer, op: CodeLengthOp) !void {
        // Dynamic DEFLATE headers describe at most HLIT + HDIST code lengths
        // (286 + 30). The repeat opcodes 16/17/18 always replace multiple raw
        // lengths with a single op, so RLE can never need more ops than the
        // uncompressed length sequence. Keep the check as a defensive guard
        // against future changes to the header encoder.
        if (self.len >= self.items.len) return error.InvalidBlockPlan;
        self.items[self.len] = op;
        self.len += 1;
    }

    fn slice(self: *const CodeLengthOpBuffer) []const CodeLengthOp {
        return self.items[0..self.len];
    }
};

const DynamicCodingPlan = struct {
    lit_lengths_full: [286]u4,
    dist_lengths_full: [30]u4,
    code_len_lengths: [19]u4,
    code_len_ops: CodeLengthOpBuffer,
    hlit: usize,
    hdist: usize,
    hclen: usize,

    fn init(tokens: []const lz77.Token) !DynamicCodingPlan {
        var lit_freqs: [286]u32 = @splat(0);
        var dist_freqs: [30]u32 = @splat(0);
        for (tokens) |token| switch (token) {
            .literal => |byte| lit_freqs[byte] += 1,
            .match => |m| {
                const len_code = lengthCode(m.length);
                const dist_code = distanceCode(m.distance);
                lit_freqs[len_code.symbol] += 1;
                dist_freqs[dist_code.symbol] += 1;
            },
        };
        lit_freqs[256] = 1;
        completeLiteralFrequencySet(&lit_freqs);
        completeDistanceFrequencySet(&dist_freqs);

        var lit_lengths_full = huffman.treeCodeLengths(286, &lit_freqs, 15);
        var dist_lengths_full = huffman.treeCodeLengths(30, &dist_freqs, 15);
        const hlit = trimmedLiteralCodeCount(&lit_lengths_full);
        const hdist = trimmedDistanceCodeCount(&dist_lengths_full);

        const code_len_ops = try buildCodeLengthOps(lit_lengths_full[0..hlit], dist_lengths_full[0..hdist]);
        var code_len_freqs: [19]u32 = @splat(0);
        for (code_len_ops.slice()) |op| code_len_freqs[op.symbol] += 1;
        completeCodeLengthFrequencySet(&code_len_freqs);
        const code_len_lengths = huffman.treeCodeLengths(19, &code_len_freqs, 7);
        const hclen = trimmedCodeLengthAlphabetCount(&code_len_lengths);

        return .{
            .lit_lengths_full = lit_lengths_full,
            .dist_lengths_full = dist_lengths_full,
            .code_len_lengths = code_len_lengths,
            .code_len_ops = code_len_ops,
            .hlit = hlit,
            .hdist = hdist,
            .hclen = hclen,
        };
    }

    fn bitCost(self: *const DynamicCodingPlan, tokens: []const lz77.Token) usize {
        var bits: usize = 3 + 5 + 5 + 4 + self.hclen * 3;
        for (self.code_len_ops.slice()) |op| {
            bits += self.code_len_lengths[op.symbol] + op.extra_bits;
        }
        for (tokens) |token| switch (token) {
            .literal => |byte| bits += self.lit_lengths_full[byte],
            .match => |m| {
                const len_code = lengthCode(m.length);
                const dist_code = distanceCode(m.distance);
                bits += self.lit_lengths_full[len_code.symbol] + len_code.extra_bits;
                bits += self.dist_lengths_full[dist_code.symbol] + dist_code.extra_bits;
            },
        };
        bits += self.lit_lengths_full[256];
        return bits;
    }

    fn write(self: *const DynamicCodingPlan, allocator: std.mem.Allocator, writer: *bitstream.BitWriter, tokens: []const lz77.Token, final: bool) !void {
        const lit_encoder = try huffman.HuffmanTable(286).Encoder.init(self.lit_lengths_full[0..self.hlit]);
        const dist_encoder = try huffman.HuffmanTable(30).Encoder.init(self.dist_lengths_full[0..self.hdist]);
        const code_len_encoder = try huffman.CodeLengthTable.Encoder.init(&self.code_len_lengths);

        try writer.writeBits(allocator, @intFromBool(final), 1);
        try writer.writeBits(allocator, 0b10, 2);
        try writer.writeBits(allocator, @intCast(self.hlit - 257), 5);
        try writer.writeBits(allocator, @intCast(self.hdist - 1), 5);
        try writer.writeBits(allocator, @intCast(self.hclen - 4), 4);
        for (huffman.code_length_order[0..self.hclen]) |symbol| try writer.writeBits(allocator, self.code_len_lengths[symbol], 3);
        for (self.code_len_ops.slice()) |op| {
            try code_len_encoder.writeSymbol(writer, allocator, op.symbol);
            if (op.extra_bits != 0) try writer.writeBits(allocator, op.extra_value, op.extra_bits);
        }
        for (tokens) |token| switch (token) {
            .literal => |byte| try lit_encoder.writeSymbol(writer, allocator, byte),
            .match => |m| {
                const len_code = lengthCode(m.length);
                try lit_encoder.writeSymbol(writer, allocator, len_code.symbol);
                if (len_code.extra_bits != 0) try writer.writeBits(allocator, len_code.extra_value, len_code.extra_bits);
                const dist_code = distanceCode(m.distance);
                try dist_encoder.writeSymbol(writer, allocator, dist_code.symbol);
                if (dist_code.extra_bits != 0) try writer.writeBits(allocator, dist_code.extra_value, dist_code.extra_bits);
            },
        };
        try lit_encoder.writeSymbol(writer, allocator, 256);
    }
};

fn buildCodeLengthOps(lit_lengths: []const u4, dist_lengths: []const u4) !CodeLengthOpBuffer {
    var ops = CodeLengthOpBuffer{};
    try appendCodeLengthOps(&ops, lit_lengths);
    try appendCodeLengthOps(&ops, dist_lengths);
    return ops;
}

fn appendCodeLengthOps(ops: *CodeLengthOpBuffer, lengths: []const u4) !void {
    var i: usize = 0;
    while (i < lengths.len) {
        const value = lengths[i];
        var run: usize = 1;
        while (i + run < lengths.len and lengths[i + run] == value) run += 1;
        if (value == 0) {
            var remaining = run;
            while (remaining >= 11) {
                const count = @min(remaining, 138);
                try ops.append(.{ .symbol = 18, .extra_bits = 7, .extra_value = @intCast(count - 11) });
                remaining -= count;
            }
            if (remaining >= 3) {
                try ops.append(.{ .symbol = 17, .extra_bits = 3, .extra_value = @intCast(remaining - 3) });
                remaining = 0;
            }
            while (remaining > 0) : (remaining -= 1) try ops.append(.{ .symbol = 0 });
        } else {
            try ops.append(.{ .symbol = value });
            var remaining = run - 1;
            while (remaining >= 3) {
                const count = @min(remaining, 6);
                try ops.append(.{ .symbol = 16, .extra_bits = 2, .extra_value = @intCast(count - 3) });
                remaining -= count;
            }
            while (remaining > 0) : (remaining -= 1) try ops.append(.{ .symbol = value });
        }
        i += run;
    }
}

pub fn encodeRawDynamicTokensAlloc(allocator: std.mem.Allocator, tokens: []const lz77.Token) ![]u8 {
    return encodeRawDynamicTokensFinalAlloc(allocator, tokens, true);
}

fn encodeRawDynamicTokensFinalAlloc(allocator: std.mem.Allocator, tokens: []const lz77.Token, final: bool) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    const plan = try DynamicCodingPlan.init(tokens);
    try writer.bytes.ensureTotalCapacity(allocator, (plan.bitCost(tokens) + 7) / 8);
    try plan.write(allocator, &writer, tokens, final);
    return writer.toOwnedSlice(allocator);
}

fn dynamicTokenBitCost(tokens: []const lz77.Token) !usize {
    const plan = try DynamicCodingPlan.init(tokens);
    return plan.bitCost(tokens);
}

fn writeDynamicTokens(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, tokens: []const lz77.Token, final: bool) !void {
    const plan = try DynamicCodingPlan.init(tokens);
    try plan.write(allocator, writer, tokens, final);
}

pub fn encodeRawDynamicSplitAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
    if (block_len == 0) return error.InvalidBlockPlan;
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    var offset: usize = 0;
    if (input.len == 0) {
        const plan = try lz77.hashGreedyPlanAlloc(allocator, "", options.lz77_options);
        defer plan.deinit(allocator);
        try writeDynamicTokens(allocator, &writer, plan.tokens, true);
        return writer.toOwnedSlice(allocator);
    }
    while (offset < input.len) {
        const n = @min(block_len, input.len - offset);
        const final = offset + n == input.len;
        const plan = try planTokensAlloc(allocator, input[offset..][0..n], options);
        defer plan.deinit(allocator);
        try writeDynamicTokens(allocator, &writer, plan.tokens, final);
        offset += n;
    }
    return writer.toOwnedSlice(allocator);
}

fn trimmedCodeLengthAlphabetCount(lengths: *const [19]u4) usize {
    var hclen: usize = 4;
    for (huffman.code_length_order, 0..) |symbol, i| {
        if (lengths[symbol] != 0) hclen = @max(hclen, i + 1);
    }
    return hclen;
}

fn trimmedLiteralCodeCount(lengths: *[286]u4) usize {
    return trimCodeLengthCount(286, 257, lengths);
}

fn trimmedDistanceCodeCount(lengths: *[30]u4) usize {
    return trimCodeLengthCount(30, 1, lengths);
}

fn trimCodeLengthCount(comptime n: usize, minimum: usize, lengths: *[n]u4) usize {
    var count = n;
    while (count > minimum and lengths[count - 1] == 0) count -= 1;
    return count;
}

fn completeLiteralFrequencySet(freqs: *[286]u32) void {
    var active: usize = 0;
    for (freqs.*) |freq| {
        if (freq != 0) active += 1;
    }
    // Only need 2 symbols for a valid Huffman tree (EOB is always preset).
    if (active < 2) {
        var sym: usize = 0;
        while (sym < freqs.len) : (sym += 1) {
            if (freqs[sym] == 0) {
                freqs[sym] = 1;
                active += 1;
                if (active >= 2) break;
            }
        }
    }
}

fn completeDistanceFrequencySet(freqs: *[30]u32) void {
    var active: usize = 0;
    for (freqs.*) |freq| {
        if (freq != 0) active += 1;
    }
    // Only need 2 symbols for a valid Huffman tree.
    if (active < 2) {
        var sym: usize = 0;
        while (sym < freqs.len) : (sym += 1) {
            if (freqs[sym] == 0) {
                freqs[sym] = 1;
                active += 1;
                if (active >= 2) break;
            }
        }
    }
}

fn completeCodeLengthFrequencySet(freqs: *[19]u32) void {
    var active: usize = 0;
    for (freqs.*) |freq| {
        if (freq != 0) active += 1;
    }
    // Only need 2 symbols for a valid Huffman tree.
    if (active < 2) {
        var sym: usize = 0;
        while (sym < freqs.len) : (sym += 1) {
            if (freqs[sym] == 0) {
                freqs[sym] = 1;
                active += 1;
                if (active >= 2) break;
            }
        }
    }
}

pub fn encodeRawFixedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return encodeRawFixedWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeRawFixedWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    const plan = try planTokensAlloc(allocator, input, options);
    defer plan.deinit(allocator);
    return encodeRawFixedTokensAlloc(allocator, plan.tokens);
}

pub fn encodeRawFixedWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: CompressionOptions) ![]u8 {
    const plan = try planTokensWithDictionaryAlloc(allocator, input, dictionary, options);
    defer plan.deinit(allocator);
    return encodeRawFixedTokensAlloc(allocator, plan.tokens);
}

fn writeFixedTokens(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, tokens: []const lz77.Token, final: bool) !void {
    const lit_encoder = huffman.fixed_literal_encoder;
    const dist_encoder = huffman.fixed_distance_encoder;
    try writer.writeBits(allocator, @intFromBool(final), 1);
    try writer.writeBits(allocator, 0b01, 2);
    for (tokens) |token| {
        switch (token) {
            .literal => |byte| try lit_encoder.writeSymbol(writer, allocator, byte),
            .match => |m| {
                const len_code = lengthCode(m.length);
                try lit_encoder.writeSymbol(writer, allocator, len_code.symbol);
                if (len_code.extra_bits != 0) try writer.writeBits(allocator, len_code.extra_value, len_code.extra_bits);
                const dist_code = distanceCode(m.distance);
                try dist_encoder.writeSymbol(writer, allocator, dist_code.symbol);
                if (dist_code.extra_bits != 0) try writer.writeBits(allocator, dist_code.extra_value, dist_code.extra_bits);
            },
        }
    }
    try lit_encoder.writeSymbol(writer, allocator, 256);
}

pub fn encodeRawFixedTokensAlloc(allocator: std.mem.Allocator, tokens: []const lz77.Token) ![]u8 {
    return encodeRawFixedTokensFinalAlloc(allocator, tokens, true);
}

fn encodeRawFixedTokensFinalAlloc(allocator: std.mem.Allocator, tokens: []const lz77.Token, final: bool) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    try writeFixedTokens(allocator, &writer, tokens, final);
    return writer.toOwnedSlice(allocator);
}

const CodeExtra = struct {
    symbol: u16,
    extra_bits: u6,
    extra_value: u16,
};

fn lengthCode(length: u16) CodeExtra {
    std.debug.assert(length >= lz77.min_match_len and length <= lz77.max_match_len);
    if (length <= 10) return .{ .symbol = length + 254, .extra_bits = 0, .extra_value = 0 };
    if (length == 258) return .{ .symbol = 285, .extra_bits = 0, .extra_value = 0 };

    const extra_bits: u6 = @intCast(std.math.log2_int(u16, length - 3) - 2);
    const span: u16 = @as(u16, 1) << @intCast(extra_bits);
    const group_base: u16 = (@as(u16, 1) << @intCast(extra_bits + 2)) + 3;
    const offset = length - group_base;
    const slot = offset / span;
    return .{
        .symbol = 261 + @as(u16, extra_bits) * 4 + slot,
        .extra_bits = extra_bits,
        .extra_value = offset & (span - 1),
    };
}

fn distanceCode(distance: u16) CodeExtra {
    std.debug.assert(distance >= 1 and distance <= lz77.default_window_len);
    if (distance <= 4) return .{ .symbol = distance - 1, .extra_bits = 0, .extra_value = 0 };

    const extra_bits: u6 = @intCast(std.math.log2_int(u16, distance - 1) - 1);
    const span: u16 = @as(u16, 1) << @intCast(extra_bits);
    const group_base: u16 = (@as(u16, 1) << @intCast(extra_bits + 1)) + 1;
    const offset = distance - group_base;
    const slot = offset / span;
    return .{
        .symbol = 2 + @as(u16, extra_bits) * 2 + slot,
        .extra_bits = extra_bits,
        .extra_value = offset & (span - 1),
    };
}

test "fast length and distance code selection matches RFC tables" {
    for (length_table, 0..) |entry, i| {
        const first = lengthCode(entry.base);
        try std.testing.expectEqual(@as(u16, @intCast(257 + i)), first.symbol);
        try std.testing.expectEqual(entry.extra_bits, first.extra_bits);
        try std.testing.expectEqual(@as(u16, 0), first.extra_value);

        if (entry.extra_bits != 0 and entry.base != 227) {
            const last_len = entry.base + (@as(u16, 1) << @intCast(entry.extra_bits)) - 1;
            const last = lengthCode(last_len);
            try std.testing.expectEqual(@as(u16, @intCast(257 + i)), last.symbol);
            try std.testing.expectEqual(entry.extra_bits, last.extra_bits);
            try std.testing.expectEqual(last_len - entry.base, last.extra_value);
        }
    }
    for (distance_table, 0..) |entry, i| {
        const first = distanceCode(entry.base);
        try std.testing.expectEqual(@as(u16, @intCast(i)), first.symbol);
        try std.testing.expectEqual(entry.extra_bits, first.extra_bits);
        try std.testing.expectEqual(@as(u16, 0), first.extra_value);

        if (entry.extra_bits != 0) {
            const last_dist = entry.base + (@as(u16, 1) << @intCast(entry.extra_bits)) - 1;
            const last = distanceCode(last_dist);
            try std.testing.expectEqual(@as(u16, @intCast(i)), last.symbol);
            try std.testing.expectEqual(entry.extra_bits, last.extra_bits);
            try std.testing.expectEqual(last_dist - entry.base, last.extra_value);
        }
    }

    const max_length = lengthCode(258);
    try std.testing.expectEqual(@as(u16, 285), max_length.symbol);
    try std.testing.expectEqual(@as(u6, 0), max_length.extra_bits);
    try std.testing.expectEqual(@as(u16, 0), max_length.extra_value);
}

pub fn decodeRawFixed(input: []const u8, output: []u8) Error!DecodeResult {
    var reader = bitstream.BitReader.init(input);
    const final = try reader.readBits(u1, 1);
    const block_type = try reader.readBits(u2, 2);
    if (block_type != 0b01) return error.InvalidDeflateBlockType;

    var out_offset: usize = 0;
    while (true) {
        const symbol = (try huffman.decodeFixedLiteralFast(&reader)).value;
        if (symbol < 256) {
            if (out_offset == output.len) return error.OutputTooSmall;
            output[out_offset] = @intCast(symbol);
            out_offset += 1;
        } else if (symbol == 256) {
            if (final == 0) return error.TruncatedFrame;
            return .{ .input_read = reader.byteOffset(), .output_written = out_offset };
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, &reader);
            const distance_symbol = (try huffman.decodeFixedDistanceFast(&reader)).value;
            const distance = try decodeDistance(distance_symbol, &reader);
            try copyMatch(output[0..out_offset], output[out_offset..], length, distance);
            out_offset += length;
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

pub fn decodeRawFixedAlloc(allocator: std.mem.Allocator, input: []const u8) !OwnedDecodeResult {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, @min(input.len * 4, 1 << 20));

    var reader = bitstream.BitReader.init(input);
    const final = try reader.readBits(u1, 1);
    const block_type = try reader.readBits(u2, 2);
    if (block_type != 0b01) return error.InvalidDeflateBlockType;

    while (true) {
        const symbol = (try huffman.decodeFixedLiteralFast(&reader)).value;
        if (symbol < 256) {
            try out.append(allocator, @intCast(symbol));
        } else if (symbol == 256) {
            if (final == 0) return error.TruncatedFrame;
            return .{ .bytes = try out.toOwnedSlice(allocator), .input_read = reader.byteOffset() };
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, &reader);
            const distance_symbol = (try huffman.decodeFixedDistanceFast(&reader)).value;
            const distance = try decodeDistance(distance_symbol, &reader);
            try appendMatch(allocator, &out, length, distance);
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

pub fn decodeRawFixedAllocStrict(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const result = try decodeRawFixedAlloc(allocator, input);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

pub fn decodeRawDynamicAlloc(allocator: std.mem.Allocator, input: []const u8) !OwnedDecodeResult {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try reserveInflateOutputHint(allocator, &out, input.len, null);

    var reader = bitstream.BitReader.init(input);
    const parsed = try huffman.parseDynamicLengths(&reader);
    const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
    const dist_table = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
    const lit_decoder = huffman.FastDecoder(286, 10).init(lit_table);
    const dist_decoder = makeDynamicDistanceDecoder(dist_table);

    while (true) {
        const symbol = (try lit_decoder.decode(&reader)).value;
        if (symbol < 256) {
            try out.append(allocator, @intCast(symbol));
        } else if (symbol == 256) {
            if (!parsed.header.final) return error.TruncatedFrame;
            return .{ .bytes = try out.toOwnedSlice(allocator), .input_read = reader.byteOffset() };
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, &reader);
            const distance_symbol = (try dist_decoder.decode(&reader)).value;
            const distance = try decodeDistance(distance_symbol, &reader);
            try appendMatch(allocator, &out, length, distance);
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

pub fn decodeRawDynamicAllocStrict(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const result = try decodeRawDynamicAlloc(allocator, input);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

const DynamicDistanceDecoder = huffman.FastDecoder(30, 8);

fn makeDynamicDistanceDecoder(table: huffman.HuffmanTable(30)) DynamicDistanceDecoder {
    // Dynamic distance alphabets have at most 30 symbols. A 10-bit lookup table
    // made every dynamic block pay to initialize 1024 entries even though most
    // distance codes are short and infrequent compared with literals. An 8-bit
    // table keeps the common fast path while cutting per-block setup/cache
    // pressure, which shows up in the raw decode benchmark for many small
    // dynamic frames and wrapper benchmarks.
    return DynamicDistanceDecoder.init(table);
}

pub fn decodeRawAutoAllocPartial(allocator: std.mem.Allocator, input: []const u8) !OwnedDecodeResult {
    return decodeRawAutoAllocPartialWithDictionary(allocator, input, "", null);
}

fn decodeRawAutoAllocPartialWithDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, max_output_len: ?usize) !OwnedDecodeResult {
    if (input.len == 0) return error.TruncatedFrame;
    if (try decodeRawStoredOnlyAllocMaybe(allocator, input, max_output_len)) |stored| return stored;

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try reserveInflateOutputHint(allocator, &out, input.len, max_output_len);

    var reader = bitstream.BitReader.init(input);
    while (true) {
        const final = (try reader.readBits(u1, 1)) != 0;
        const block_type = try reader.readBits(u2, 2);
        switch (block_type) {
            0 => try decodeStoredBlockFromReader(allocator, &reader, &out, max_output_len),
            1 => try decodeFixedBlockFromReader(allocator, &reader, &out, dictionary, max_output_len),
            2 => {
                const parsed = try huffman.parseDynamicLengthsAfterHeader(final, &reader);
                const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
                const dist_table = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
                const lit_decoder = huffman.FastDecoder(286, 10).init(lit_table);
                const dist_decoder = makeDynamicDistanceDecoder(dist_table);
                try decodeCompressedBlockFromReader(allocator, &reader, &out, dictionary, max_output_len, &lit_decoder, &dist_decoder);
            },
            else => return error.InvalidDeflateBlockType,
        }
        if (final) return .{ .bytes = try out.toOwnedSlice(allocator), .input_read = reader.byteOffset() };
    }
}

fn decodeRawAutoAppendPartialWithDictionary(
    allocator: std.mem.Allocator,
    input: []const u8,
    dictionary: []const u8,
    out: *std.ArrayList(u8),
    max_output_len: ?usize,
) !DecodeResult {
    if (input.len == 0) return error.TruncatedFrame;
    const start_len = out.items.len;
    if (try planRawStoredOnly(input)) |plan| {
        try appendRawStoredOnlyPlanned(allocator, input[0..plan.input_read], out, plan, max_output_len);
        return .{ .input_read = plan.input_read, .output_written = plan.output_len };
    }

    try reserveInflateAppendOutputHint(allocator, out, input.len, max_output_len);

    var reader = bitstream.BitReader.init(input);
    while (true) {
        const final = (try reader.readBits(u1, 1)) != 0;
        const block_type = try reader.readBits(u2, 2);
        switch (block_type) {
            0 => try decodeStoredBlockFromReader(allocator, &reader, out, max_output_len),
            1 => try decodeFixedBlockFromReaderFromBase(allocator, &reader, out, dictionary, start_len, max_output_len),
            2 => {
                const parsed = try huffman.parseDynamicLengthsAfterHeader(final, &reader);
                const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
                const dist_table = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
                const lit_decoder = huffman.FastDecoder(286, 10).init(lit_table);
                const dist_decoder = makeDynamicDistanceDecoder(dist_table);
                try decodeCompressedBlockFromReaderFromBase(allocator, &reader, out, dictionary, start_len, max_output_len, &lit_decoder, &dist_decoder);
            },
            else => return error.InvalidDeflateBlockType,
        }
        if (final) return .{ .input_read = reader.byteOffset(), .output_written = out.items.len - start_len };
    }
}

pub fn decodeRawAutoAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const result = try decodeRawAutoAllocPartial(allocator, input);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

pub fn decodeRawAutoAllocWithDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8) ![]u8 {
    const result = try decodeRawAutoAllocPartialWithDictionary(allocator, input, dictionary, null);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

pub fn decodeRawAutoAllocExactSize(allocator: std.mem.Allocator, input: []const u8, expected_output_len: usize) ![]u8 {
    return decodeRawAutoAllocWithDictionaryExactSize(allocator, input, "", expected_output_len);
}

pub fn decodeRawAutoAllocWithDictionaryExactSize(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, expected_output_len: usize) ![]u8 {
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const decoded = decodeRawAutoWithDictionary(input, dictionary, out) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (decoded.input_read != input.len) return error.TrailingData;
    if (decoded.output_written != expected_output_len) return error.SizeMismatch;
    return out;
}

pub fn decodeRawAutoAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    const result = try decodeRawAutoAllocPartialWithDictionary(allocator, input, "", max_output_len);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

pub fn decodeRawAutoAllocWithDictionaryLimited(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, max_output_len: usize) ![]u8 {
    const result = try decodeRawAutoAllocPartialWithDictionary(allocator, input, dictionary, max_output_len);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

pub fn decodeRawAuto(input: []const u8, output: []u8) Error!DecodeResult {
    return decodeRawAutoWithDictionary(input, "", output);
}

pub fn decodeRawAutoWithDictionary(input: []const u8, dictionary: []const u8, output: []u8) Error!DecodeResult {
    if (input.len == 0) return error.TruncatedFrame;
    if (try decodeRawStoredOnlyIntoMaybe(input, output)) |stored| return stored;

    var reader = bitstream.BitReader.init(input);
    var out_offset: usize = 0;
    while (true) {
        const final = (try reader.readBits(u1, 1)) != 0;
        const block_type = try reader.readBits(u2, 2);
        switch (block_type) {
            0 => try decodeStoredBlockIntoReader(&reader, output, &out_offset),
            1 => try decodeFixedBlockIntoReader(&reader, output, &out_offset, dictionary),
            2 => {
                const parsed = try huffman.parseDynamicLengthsAfterHeader(final, &reader);
                const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
                const dist_table = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
                const lit_decoder = huffman.FastDecoder(286, 10).init(lit_table);
                const dist_decoder = makeDynamicDistanceDecoder(dist_table);
                try decodeCompressedBlockIntoReader(&reader, output, &out_offset, dictionary, &lit_decoder, &dist_decoder);
            },
            else => return error.InvalidDeflateBlockType,
        }
        if (final) return .{ .input_read = reader.byteOffset(), .output_written = out_offset };
    }
}

pub fn rawStoredEncodedSize(input_len: usize) Error!usize {
    const blocks: usize = if (input_len == 0) 1 else ((input_len - 1) / max_stored_block_len) + 1;
    const header_bytes = std.math.mul(usize, blocks, 5) catch return error.IntegerOverflow;
    return std.math.add(usize, input_len, header_bytes) catch error.IntegerOverflow;
}

pub fn encodeRawStored(input: []const u8, output: []u8) Error!usize {
    const required = try rawStoredEncodedSize(input.len);
    if (output.len < required) return error.OutputTooSmall;

    var in_offset: usize = 0;
    var out_offset: usize = 0;
    if (input.len == 0) {
        writeStoredHeader(true, 0, output[0..5]);
        return 5;
    }

    while (in_offset < input.len) {
        const chunk_len = @min(max_stored_block_len, input.len - in_offset);
        const final = in_offset + chunk_len == input.len;
        writeStoredHeader(final, @intCast(chunk_len), output[out_offset..][0..5]);
        out_offset += 5;
        @memcpy(output[out_offset..][0..chunk_len], input[in_offset..][0..chunk_len]);
        out_offset += chunk_len;
        in_offset += chunk_len;
    }
    return out_offset;
}

pub fn encodeRawStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const required = try rawStoredEncodedSize(input.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    const written = try encodeRawStored(input, out);
    std.debug.assert(written == out.len);
    return out;
}

fn encodeRawStoredSplitAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize) ![]u8 {
    if (block_len == 0) return error.InvalidBlockPlan;
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    try writeStoredSplitBlocks(allocator, &writer, input, block_len);
    return writer.toOwnedSlice(allocator);
}

fn writeStoredSplitBlocks(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, input: []const u8, block_len: usize) !void {
    if (block_len == 0) return error.InvalidBlockPlan;
    const effective_block_len = @min(block_len, max_stored_block_len);
    if (input.len == 0) {
        try writeStoredBlock(allocator, writer, "", true);
        return;
    }
    var offset: usize = 0;
    while (offset < input.len) {
        const n = @min(effective_block_len, input.len - offset);
        const final = offset + n == input.len;
        try writeStoredBlock(allocator, writer, input[offset..][0..n], final);
        offset += n;
    }
}

pub fn decodeRawStored(input: []const u8, output: []u8) Error!DecodeResult {
    var reader = bitstream.BitReader.init(input);
    var out_offset: usize = 0;

    while (true) {
        const final = (try reader.readBits(u1, 1)) != 0;
        const block_type = try reader.readBits(u2, 2);
        if (block_type != 0) return error.InvalidDeflateBlockType;

        reader.alignToByte();
        const offset = reader.byte_index;
        if (input.len - offset < 4) return error.TruncatedFrame;
        const len = std.mem.readInt(u16, input[offset..][0..2], .little);
        const nlen = std.mem.readInt(u16, input[offset + 2 ..][0..2], .little);
        if (nlen != ~len) return error.StoredLengthMismatch;

        const chunk_len: usize = len;
        if (input.len - offset - 4 < chunk_len) return error.TruncatedFrame;
        if (output.len - out_offset < chunk_len) return error.OutputTooSmall;
        @memcpy(output[out_offset..][0..chunk_len], input[offset + 4 ..][0..chunk_len]);
        out_offset += chunk_len;
        reader.byte_index = offset + 4 + chunk_len;
        reader.bit_index = 0;

        if (final) return .{ .input_read = reader.byteOffset(), .output_written = out_offset };
    }
}

pub fn decodeRawStoredAllocPartial(allocator: std.mem.Allocator, input: []const u8) !OwnedDecodeResult {
    return decodeRawStoredAllocPartialLimitedInternal(allocator, input, null);
}

fn decodeRawStoredAllocPartialLimitedInternal(allocator: std.mem.Allocator, input: []const u8, max_output_len: ?usize) !OwnedDecodeResult {
    if (try decodeRawStoredOnlyAllocMaybe(allocator, input, max_output_len)) |stored| return stored;
    return error.InvalidDeflateBlockType;
}

const StoredOnlyPlan = struct {
    input_read: usize,
    output_len: usize,
};

const StoredOnlyHashResult = struct {
    result: OwnedDecodeResult,
    digest: u32,

    fn deinit(self: StoredOnlyHashResult, allocator: std.mem.Allocator) void {
        self.result.deinit(allocator);
    }
};

fn decodeRawStoredOnlyAllocMaybe(allocator: std.mem.Allocator, input: []const u8, max_output_len: ?usize) !?OwnedDecodeResult {
    const plan = (try planRawStoredOnly(input)) orelse return null;
    try ensureOutputLimit(0, plan.output_len, max_output_len);
    const out = try allocator.alloc(u8, plan.output_len);
    errdefer allocator.free(out);
    copyRawStoredOnly(input[0..plan.input_read], out);
    return .{ .bytes = out, .input_read = plan.input_read };
}

fn decodeRawStoredOnlyIntoMaybe(input: []const u8, output: []u8) Error!?DecodeResult {
    const plan = (try planRawStoredOnly(input)) orelse return null;
    if (output.len < plan.output_len) return error.OutputTooSmall;
    copyRawStoredOnly(input[0..plan.input_read], output[0..plan.output_len]);
    return .{ .input_read = plan.input_read, .output_written = plan.output_len };
}

fn decodeRawStoredOnlyIntoMaybeWithHash(comptime Hash: type, input: []const u8, output: []u8) Error!?struct { result: DecodeResult, digest: u32 } {
    const plan = (try planRawStoredOnly(input)) orelse return null;
    if (output.len < plan.output_len) return error.OutputTooSmall;

    var hash = Hash.init();
    copyRawStoredOnlyWithHash(Hash, input[0..plan.input_read], output[0..plan.output_len], &hash);
    return .{
        .result = .{ .input_read = plan.input_read, .output_written = plan.output_len },
        .digest = hash.digest(),
    };
}

fn decodeRawStoredOnlyAllocMaybeWithHash(comptime Hash: type, allocator: std.mem.Allocator, input: []const u8, max_output_len: ?usize) !?StoredOnlyHashResult {
    const plan = (try planRawStoredOnly(input)) orelse return null;
    try ensureOutputLimit(0, plan.output_len, max_output_len);
    const out = try allocator.alloc(u8, plan.output_len);
    errdefer allocator.free(out);

    var hash = Hash.init();
    copyRawStoredOnlyWithHash(Hash, input[0..plan.input_read], out, &hash);
    return .{
        .result = .{ .bytes = out, .input_read = plan.input_read },
        .digest = hash.digest(),
    };
}

fn planRawStoredOnly(input: []const u8) Error!?StoredOnlyPlan {
    if (input.len == 0) return error.TruncatedFrame;
    var offset: usize = 0;
    var output_len: usize = 0;
    while (true) {
        if (input.len - offset < 1) return error.TruncatedFrame;
        const header = input[offset];
        const final = (header & 0x01) != 0;
        const block_type = (header >> 1) & 0x03;
        if (block_type != 0) return null;

        // Stored-block payloads start on the next byte boundary. Bits 3..7 of
        // the header byte are padding and intentionally ignored, matching zlib
        // and the existing BitReader-based stored decoder.
        offset += 1;
        if (input.len - offset < 4) return error.TruncatedFrame;
        const len = std.mem.readInt(u16, input[offset..][0..2], .little);
        const nlen = std.mem.readInt(u16, input[offset + 2 ..][0..2], .little);
        if (nlen != ~len) return error.StoredLengthMismatch;
        offset += 4;

        const chunk_len: usize = len;
        if (input.len - offset < chunk_len) return error.TruncatedFrame;
        output_len = std.math.add(usize, output_len, chunk_len) catch return error.IntegerOverflow;
        offset += chunk_len;
        if (final) return .{ .input_read = offset, .output_len = output_len };
    }
}

fn copyRawStoredOnlyWithHash(comptime Hash: type, input: []const u8, output: []u8, hash: *Hash) void {
    var in_offset: usize = 0;
    var out_offset: usize = 0;
    while (true) {
        const final = (input[in_offset] & 0x01) != 0;
        in_offset += 1;
        const len = std.mem.readInt(u16, input[in_offset..][0..2], .little);
        const chunk_len: usize = len;
        in_offset += 4;
        const chunk = input[in_offset..][0..chunk_len];
        @memcpy(output[out_offset..][0..chunk_len], chunk);
        hash.update(chunk);
        out_offset += chunk_len;
        in_offset += chunk_len;
        if (final) {
            std.debug.assert(in_offset == input.len);
            std.debug.assert(out_offset == output.len);
            return;
        }
    }
}

fn copyRawStoredOnly(input: []const u8, output: []u8) void {
    var in_offset: usize = 0;
    var out_offset: usize = 0;
    while (true) {
        const final = (input[in_offset] & 0x01) != 0;
        in_offset += 1;
        const len = std.mem.readInt(u16, input[in_offset..][0..2], .little);
        const chunk_len: usize = len;
        in_offset += 4;
        @memcpy(output[out_offset..][0..chunk_len], input[in_offset..][0..chunk_len]);
        out_offset += chunk_len;
        in_offset += chunk_len;
        if (final) {
            std.debug.assert(in_offset == input.len);
            std.debug.assert(out_offset == output.len);
            return;
        }
    }
}

fn appendRawStoredOnlyPlanned(allocator: std.mem.Allocator, input: []const u8, out: *std.ArrayList(u8), plan: StoredOnlyPlan, max_output_len: ?usize) !void {
    try ensureOutputLimit(out.items.len, plan.output_len, max_output_len);
    try out.ensureUnusedCapacity(allocator, plan.output_len);

    var in_offset: usize = 0;
    while (true) {
        const final = (input[in_offset] & 0x01) != 0;
        in_offset += 1;
        const len = std.mem.readInt(u16, input[in_offset..][0..2], .little);
        const chunk_len: usize = len;
        in_offset += 4;
        out.appendSliceAssumeCapacity(input[in_offset..][0..chunk_len]);
        in_offset += chunk_len;
        if (final) {
            std.debug.assert(in_offset == plan.input_read);
            return;
        }
    }
}

pub fn decodeRawStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const result = try decodeRawStoredAllocPartial(allocator, input);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

pub fn decodeRawStoredAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    const result = try decodeRawStoredAllocPartialLimitedInternal(allocator, input, max_output_len);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

fn decodeStoredBlockFromReader(allocator: std.mem.Allocator, reader: *bitstream.BitReader, out: *std.ArrayList(u8), max_output_len: ?usize) !void {
    reader.alignToByte();
    const offset = reader.byte_index;
    if (reader.input.len - offset < 4) return error.TruncatedFrame;
    const len = std.mem.readInt(u16, reader.input[offset..][0..2], .little);
    const nlen = std.mem.readInt(u16, reader.input[offset + 2 ..][0..2], .little);
    if (nlen != ~len) return error.StoredLengthMismatch;
    const chunk_len: usize = len;
    if (reader.input.len - offset - 4 < chunk_len) return error.TruncatedFrame;
    try ensureOutputLimit(out.items.len, chunk_len, max_output_len);
    try out.appendSlice(allocator, reader.input[offset + 4 ..][0..chunk_len]);
    reader.byte_index = offset + 4 + chunk_len;
    reader.bit_index = 0;
}

fn decodeStoredBlockIntoReader(reader: *bitstream.BitReader, output: []u8, out_offset: *usize) Error!void {
    reader.alignToByte();
    const offset = reader.byte_index;
    if (reader.input.len - offset < 4) return error.TruncatedFrame;
    const len = std.mem.readInt(u16, reader.input[offset..][0..2], .little);
    const nlen = std.mem.readInt(u16, reader.input[offset + 2 ..][0..2], .little);
    if (nlen != ~len) return error.StoredLengthMismatch;
    const chunk_len: usize = len;
    if (reader.input.len - offset - 4 < chunk_len) return error.TruncatedFrame;
    if (output.len - out_offset.* < chunk_len) return error.OutputTooSmall;
    @memcpy(output[out_offset.*..][0..chunk_len], reader.input[offset + 4 ..][0..chunk_len]);
    out_offset.* += chunk_len;
    reader.byte_index = offset + 4 + chunk_len;
    reader.bit_index = 0;
}

fn reserveInflateOutputHint(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input_len: usize, max_output_len: ?usize) !void {
    const default_hint = inflateOutputCapacityHint(input_len);
    const capacity = if (max_output_len) |limit| @min(default_hint, limit) else default_hint;
    if (capacity != 0) try out.ensureTotalCapacity(allocator, capacity);
}

fn reserveInflateAppendOutputHint(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input_len: usize, max_output_len: ?usize) !void {
    const default_hint = inflateOutputCapacityHint(input_len);
    const capacity = if (max_output_len) |limit| blk: {
        if (out.items.len >= limit) break :blk out.items.len;
        break :blk out.items.len + @min(default_hint, limit - out.items.len);
    } else out.items.len +| default_hint;
    if (capacity != 0) try out.ensureTotalCapacity(allocator, capacity);
}

fn inflateOutputCapacityHint(input_len: usize) usize {
    // Highly compressible DEFLATE frames in the Rust baseline corpus often
    // expand by hundreds of times (for example repeated/RLE payloads). The
    // previous 4x hint made allocator-returning decode repeatedly grow the
    // output ArrayList while the caller-buffer API avoided that cost entirely.
    // A 64x hint is still capped at 1 MiB, so it improves common compressed
    // frames without over-reserving unbounded memory for hostile streams.
    return @min(input_len *| 64, 1 << 20);
}

fn decodeFixedBlockFromReader(allocator: std.mem.Allocator, reader: *bitstream.BitReader, out: *std.ArrayList(u8), dictionary: []const u8, max_output_len: ?usize) !void {
    try decodeFixedBlockFromReaderFromBase(allocator, reader, out, dictionary, 0, max_output_len);
}

fn decodeFixedBlockFromReaderFromBase(allocator: std.mem.Allocator, reader: *bitstream.BitReader, out: *std.ArrayList(u8), dictionary: []const u8, history_start: usize, max_output_len: ?usize) !void {
    while (true) {
        const symbol = (try huffman.decodeFixedLiteralFast(reader)).value;
        if (symbol < 256) {
            try ensureOutputLimit(out.items.len, 1, max_output_len);
            try out.append(allocator, @intCast(symbol));
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = (try huffman.decodeFixedDistanceFast(reader)).value;
            const distance = try decodeDistance(distance_symbol, reader);
            try appendMatchWithDictionaryFromBase(allocator, out, dictionary, history_start, length, distance, max_output_len);
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn decodeFixedBlockIntoReader(reader: *bitstream.BitReader, output: []u8, out_offset: *usize, dictionary: []const u8) Error!void {
    while (true) {
        const symbol = (try huffman.decodeFixedLiteralFast(reader)).value;
        if (symbol < 256) {
            if (out_offset.* == output.len) return error.OutputTooSmall;
            output[out_offset.*] = @intCast(symbol);
            out_offset.* += 1;
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = (try huffman.decodeFixedDistanceFast(reader)).value;
            const distance = try decodeDistance(distance_symbol, reader);
            try copyMatchWithDictionary(output[0..out_offset.*], dictionary, output[out_offset.*..], length, distance);
            out_offset.* += length;
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn decodeCompressedBlockFromReader(
    allocator: std.mem.Allocator,
    reader: *bitstream.BitReader,
    out: *std.ArrayList(u8),
    dictionary: []const u8,
    max_output_len: ?usize,
    lit_table: anytype,
    dist_table: anytype,
) !void {
    try decodeCompressedBlockFromReaderFromBase(allocator, reader, out, dictionary, 0, max_output_len, lit_table, dist_table);
}

fn decodeCompressedBlockFromReaderFromBase(
    allocator: std.mem.Allocator,
    reader: *bitstream.BitReader,
    out: *std.ArrayList(u8),
    dictionary: []const u8,
    history_start: usize,
    max_output_len: ?usize,
    lit_table: anytype,
    dist_table: anytype,
) !void {
    while (true) {
        const symbol = (try lit_table.decode(reader)).value;
        if (symbol < 256) {
            try ensureOutputLimit(out.items.len, 1, max_output_len);
            try out.append(allocator, @intCast(symbol));
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = (try dist_table.decode(reader)).value;
            const distance = try decodeDistance(distance_symbol, reader);
            try appendMatchWithDictionaryFromBase(allocator, out, dictionary, history_start, length, distance, max_output_len);
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn decodeCompressedBlockIntoReader(
    reader: *bitstream.BitReader,
    output: []u8,
    out_offset: *usize,
    dictionary: []const u8,
    lit_table: anytype,
    dist_table: anytype,
) Error!void {
    while (true) {
        const symbol = (try lit_table.decode(reader)).value;
        if (symbol < 256) {
            if (out_offset.* == output.len) return error.OutputTooSmall;
            output[out_offset.*] = @intCast(symbol);
            out_offset.* += 1;
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = (try dist_table.decode(reader)).value;
            const distance = try decodeDistance(distance_symbol, reader);
            try copyMatchWithDictionary(output[0..out_offset.*], dictionary, output[out_offset.*..], length, distance);
            out_offset.* += length;
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn decodeLength(symbol: u16, reader: *bitstream.BitReader) Error!usize {
    if (symbol < 257 or symbol > 285) return error.InvalidHuffmanCode;
    const index = symbol - 257;
    const entry = length_table[index];
    const extra = if (entry.extra_bits == 0) 0 else try reader.readBits(u16, entry.extra_bits);
    return entry.base + extra;
}

fn decodeDistance(symbol: u16, reader: *bitstream.BitReader) Error!usize {
    if (symbol >= distance_table.len) return error.InvalidHuffmanCode;
    const entry = distance_table[symbol];
    const extra = if (entry.extra_bits == 0) 0 else try reader.readBits(u16, entry.extra_bits);
    return entry.base + extra;
}

fn copyMatch(history: []const u8, dest: []u8, length: usize, distance: usize) Error!void {
    if (distance == 0 or distance > history.len) return error.InvalidMatch;
    if (dest.len < length) return error.OutputTooSmall;
    if (distance == 1 and history.len != 0) {
        @memset(dest[0..length], history[history.len - 1]);
        return;
    }
    if (distance <= 4 and history.len >= distance) {
        copySmallDistanceMatch(dest[0..length], history[history.len - distance ..], distance);
        return;
    }
    if (distance >= length) {
        const start = history.len - distance;
        @memcpy(dest[0..length], history[start..][0..length]);
        return;
    }
    var i: usize = 0;
    while (i < length) : (i += 1) {
        const absolute = history.len + i - distance;
        dest[i] = if (absolute < history.len) history[absolute] else dest[absolute - history.len];
    }
}

fn copyMatchWithDictionary(history: []const u8, dictionary: []const u8, dest: []u8, length: usize, distance: usize) Error!void {
    if (dictionary.len == 0) return copyMatch(history, dest, length, distance);
    if (distance == 0 or distance > history.len + dictionary.len) return error.InvalidMatch;
    if (dest.len < length) return error.OutputTooSmall;

    if (distance <= history.len) return copyMatch(history, dest, length, distance);

    const base_len = dictionary.len + history.len;
    if (distance >= length) {
        const absolute = base_len - distance;
        if (absolute < dictionary.len) {
            const dict_len = @min(length, dictionary.len - absolute);
            @memcpy(dest[0..dict_len], dictionary[absolute..][0..dict_len]);
            if (dict_len < length) @memcpy(dest[dict_len..length], history[0..][0 .. length - dict_len]);
        } else {
            @memcpy(dest[0..length], history[absolute - dictionary.len ..][0..length]);
        }
        return;
    }

    var i: usize = 0;
    while (i < length) : (i += 1) {
        const absolute = base_len + i - distance;
        dest[i] = if (absolute < dictionary.len)
            dictionary[absolute]
        else if (absolute < base_len)
            history[absolute - dictionary.len]
        else
            dest[absolute - base_len];
    }
}

fn copySmallDistanceMatch(dest: []u8, pattern: []const u8, distance: usize) void {
    switch (distance) {
        1 => @memset(dest, pattern[0]),
        2 => {
            const a = pattern[0];
            const b = pattern[1];
            var i: usize = 0;
            while (i + 2 <= dest.len) : (i += 2) {
                dest[i] = a;
                dest[i + 1] = b;
            }
            if (i < dest.len) dest[i] = a;
        },
        3 => {
            const a = pattern[0];
            const b = pattern[1];
            const c = pattern[2];
            var i: usize = 0;
            while (i + 3 <= dest.len) : (i += 3) {
                dest[i] = a;
                dest[i + 1] = b;
                dest[i + 2] = c;
            }
            if (i < dest.len) {
                dest[i] = a;
                i += 1;
            }
            if (i < dest.len) dest[i] = b;
        },
        4 => {
            const a = pattern[0];
            const b = pattern[1];
            const c = pattern[2];
            const d = pattern[3];
            var i: usize = 0;
            while (i + 4 <= dest.len) : (i += 4) {
                dest[i] = a;
                dest[i + 1] = b;
                dest[i + 2] = c;
                dest[i + 3] = d;
            }
            if (i < dest.len) {
                dest[i] = a;
                i += 1;
            }
            if (i < dest.len) {
                dest[i] = b;
                i += 1;
            }
            if (i < dest.len) dest[i] = c;
        },
        else => unreachable,
    }
}

fn appendMatch(allocator: std.mem.Allocator, out: *std.ArrayList(u8), length: usize, distance: usize) !void {
    try appendMatchWithDictionary(allocator, out, "", length, distance, null);
}

fn appendMatchWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), dictionary: []const u8, length: usize, distance: usize, max_output_len: ?usize) !void {
    try appendMatchWithDictionaryFromBase(allocator, out, dictionary, 0, length, distance, max_output_len);
}

fn appendMatchWithDictionaryFromBase(allocator: std.mem.Allocator, out: *std.ArrayList(u8), dictionary: []const u8, history_start: usize, length: usize, distance: usize, max_output_len: ?usize) !void {
    std.debug.assert(history_start <= out.items.len);
    const history_len = out.items.len - history_start;
    if (distance == 0 or distance > history_len + dictionary.len) return error.InvalidMatch;
    try ensureOutputLimit(out.items.len, length, max_output_len);
    try out.ensureUnusedCapacity(allocator, length);
    if (distance == 1 and history_len != 0) {
        const byte = out.items[out.items.len - 1];
        out.appendNTimesAssumeCapacity(byte, length);
        return;
    }
    if (dictionary.len == 0 and distance <= 4 and history_len >= distance) {
        appendSmallDistanceMatchAssumeCapacity(out, length, distance);
        return;
    }
    if (dictionary.len == 0 and distance >= length) {
        const start = out.items.len - distance;
        out.appendSliceAssumeCapacity(out.items[start..][0..length]);
        return;
    }
    var i: usize = 0;
    while (i < length) : (i += 1) {
        const absolute = dictionary.len + (out.items.len - history_start) - distance;
        const byte = if (absolute < dictionary.len)
            dictionary[absolute]
        else
            out.items[history_start + absolute - dictionary.len];
        out.appendAssumeCapacity(byte);
    }
}

fn appendSmallDistanceMatchAssumeCapacity(out: *std.ArrayList(u8), length: usize, distance: usize) void {
    const start = out.items.len - distance;
    switch (distance) {
        2 => {
            const a = out.items[start];
            const b = out.items[start + 1];
            var i: usize = 0;
            while (i + 2 <= length) : (i += 2) {
                out.appendAssumeCapacity(a);
                out.appendAssumeCapacity(b);
            }
            if (i < length) out.appendAssumeCapacity(a);
        },
        3 => {
            const a = out.items[start];
            const b = out.items[start + 1];
            const c = out.items[start + 2];
            var i: usize = 0;
            while (i + 3 <= length) : (i += 3) {
                out.appendAssumeCapacity(a);
                out.appendAssumeCapacity(b);
                out.appendAssumeCapacity(c);
            }
            if (i < length) {
                out.appendAssumeCapacity(a);
                i += 1;
            }
            if (i < length) out.appendAssumeCapacity(b);
        },
        4 => {
            const a = out.items[start];
            const b = out.items[start + 1];
            const c = out.items[start + 2];
            const d = out.items[start + 3];
            var i: usize = 0;
            while (i + 4 <= length) : (i += 4) {
                out.appendAssumeCapacity(a);
                out.appendAssumeCapacity(b);
                out.appendAssumeCapacity(c);
                out.appendAssumeCapacity(d);
            }
            if (i < length) {
                out.appendAssumeCapacity(a);
                i += 1;
            }
            if (i < length) {
                out.appendAssumeCapacity(b);
                i += 1;
            }
            if (i < length) out.appendAssumeCapacity(c);
        },
        else => unreachable,
    }
}

fn ensureOutputLimit(current_len: usize, additional_len: usize, max_output_len: ?usize) Error!void {
    const limit = max_output_len orelse return;
    if (additional_len > limit or current_len > limit - additional_len) return error.OutputLimitExceeded;
}

const LengthEntry = struct { base: u16, extra_bits: u6 };
const length_table = [_]LengthEntry{
    .{ .base = 3, .extra_bits = 0 },
    .{ .base = 4, .extra_bits = 0 },
    .{ .base = 5, .extra_bits = 0 },
    .{ .base = 6, .extra_bits = 0 },
    .{ .base = 7, .extra_bits = 0 },
    .{ .base = 8, .extra_bits = 0 },
    .{ .base = 9, .extra_bits = 0 },
    .{ .base = 10, .extra_bits = 0 },
    .{ .base = 11, .extra_bits = 1 },
    .{ .base = 13, .extra_bits = 1 },
    .{ .base = 15, .extra_bits = 1 },
    .{ .base = 17, .extra_bits = 1 },
    .{ .base = 19, .extra_bits = 2 },
    .{ .base = 23, .extra_bits = 2 },
    .{ .base = 27, .extra_bits = 2 },
    .{ .base = 31, .extra_bits = 2 },
    .{ .base = 35, .extra_bits = 3 },
    .{ .base = 43, .extra_bits = 3 },
    .{ .base = 51, .extra_bits = 3 },
    .{ .base = 59, .extra_bits = 3 },
    .{ .base = 67, .extra_bits = 4 },
    .{ .base = 83, .extra_bits = 4 },
    .{ .base = 99, .extra_bits = 4 },
    .{ .base = 115, .extra_bits = 4 },
    .{ .base = 131, .extra_bits = 5 },
    .{ .base = 163, .extra_bits = 5 },
    .{ .base = 195, .extra_bits = 5 },
    .{ .base = 227, .extra_bits = 5 },
    .{ .base = 258, .extra_bits = 0 },
};

const DistanceEntry = struct { base: u16, extra_bits: u6 };
const distance_table = [_]DistanceEntry{
    .{ .base = 1, .extra_bits = 0 },
    .{ .base = 2, .extra_bits = 0 },
    .{ .base = 3, .extra_bits = 0 },
    .{ .base = 4, .extra_bits = 0 },
    .{ .base = 5, .extra_bits = 1 },
    .{ .base = 7, .extra_bits = 1 },
    .{ .base = 9, .extra_bits = 2 },
    .{ .base = 13, .extra_bits = 2 },
    .{ .base = 17, .extra_bits = 3 },
    .{ .base = 25, .extra_bits = 3 },
    .{ .base = 33, .extra_bits = 4 },
    .{ .base = 49, .extra_bits = 4 },
    .{ .base = 65, .extra_bits = 5 },
    .{ .base = 97, .extra_bits = 5 },
    .{ .base = 129, .extra_bits = 6 },
    .{ .base = 193, .extra_bits = 6 },
    .{ .base = 257, .extra_bits = 7 },
    .{ .base = 385, .extra_bits = 7 },
    .{ .base = 513, .extra_bits = 8 },
    .{ .base = 769, .extra_bits = 8 },
    .{ .base = 1025, .extra_bits = 9 },
    .{ .base = 1537, .extra_bits = 9 },
    .{ .base = 2049, .extra_bits = 10 },
    .{ .base = 3073, .extra_bits = 10 },
    .{ .base = 4097, .extra_bits = 11 },
    .{ .base = 6145, .extra_bits = 11 },
    .{ .base = 8193, .extra_bits = 12 },
    .{ .base = 12289, .extra_bits = 12 },
    .{ .base = 16385, .extra_bits = 13 },
    .{ .base = 24577, .extra_bits = 13 },
};

pub fn zlibStoredEncodedSize(input_len: usize) Error!usize {
    const raw_len = try rawStoredEncodedSize(input_len);
    const with_header = std.math.add(usize, 2, raw_len) catch return error.IntegerOverflow;
    return std.math.add(usize, with_header, 4) catch error.IntegerOverflow;
}

pub fn zlibStoredWithDictionaryEncodedSize(input_len: usize) Error!usize {
    const raw_len = try rawStoredEncodedSize(input_len);
    const with_header = std.math.add(usize, 6, raw_len) catch return error.IntegerOverflow;
    return std.math.add(usize, with_header, 4) catch error.IntegerOverflow;
}

pub fn encodeZlibStored(input: []const u8, output: []u8) Error!usize {
    const required = try zlibStoredEncodedSize(input.len);
    if (output.len < required) return error.OutputTooSmall;

    writeZlibHeader(output[0..2], null);
    const raw_written = try encodeRawStored(input, output[2 .. required - 4]);
    const footer_offset = 2 + raw_written;
    std.mem.writeInt(u32, output[footer_offset..][0..4], checksum.adler32(input), .big);
    return footer_offset + 4;
}

pub fn encodeZlibStoredWithDictionary(input: []const u8, output: []u8, dictionary: []const u8) Error!usize {
    const required = try zlibStoredWithDictionaryEncodedSize(input.len);
    if (output.len < required) return error.OutputTooSmall;

    writeZlibHeader(output[0..6], dictionary);
    const raw_written = try encodeRawStored(input, output[6 .. required - 4]);
    const footer_offset = 6 + raw_written;
    std.mem.writeInt(u32, output[footer_offset..][0..4], checksum.adler32(input), .big);
    return footer_offset + 4;
}

pub fn encodeZlibStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const required = try zlibStoredEncodedSize(input.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    const written = try encodeZlibStored(input, out);
    std.debug.assert(written == out.len);
    return out;
}

pub fn encodeZlibStoredWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8) ![]u8 {
    const required = try zlibStoredWithDictionaryEncodedSize(input.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    const written = try encodeZlibStoredWithDictionary(input, out, dictionary);
    std.debug.assert(written == out.len);
    return out;
}

fn encodeZlibStoredSplitAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize) ![]u8 {
    return encodeZlibStoredSplitDirectAlloc(allocator, input, null, block_len);
}

fn encodeZlibStoredSplitWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, block_len: usize) ![]u8 {
    return encodeZlibStoredSplitDirectAlloc(allocator, input, dictionary, block_len);
}

fn encodeZlibStoredSplitDirectAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, block_len: usize) ![]u8 {
    if (block_len == 0) return error.InvalidBlockPlan;
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    const header_len = try writeWrappedDeflatePrefix(allocator, &writer, dictionary);
    try writeStoredSplitBlocks(allocator, &writer, input, block_len);
    return finishZlibFrame(allocator, &writer, input, header_len);
}

pub fn encodeZlibFixedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return encodeZlibFixedWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeZlibFixedWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    const plan = try planTokensAlloc(allocator, input, options);
    defer plan.deinit(allocator);
    return encodeZlibFixedTokensAlloc(allocator, input, null, plan.tokens);
}

pub fn encodeZlibFixedWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: CompressionOptions) ![]u8 {
    const plan = try planTokensWithDictionaryAlloc(allocator, input, dictionary, options);
    defer plan.deinit(allocator);
    return encodeZlibFixedTokensAlloc(allocator, input, dictionary, plan.tokens);
}

pub fn encodeZlibDynamicLiteralAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const plan = try lz77.literalPlanAlloc(allocator, input);
    defer plan.deinit(allocator);
    return encodeZlibDynamicTokensAlloc(allocator, input, null, plan.tokens);
}

pub fn encodeZlibDynamicWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    const plan = try planTokensAlloc(allocator, input, options);
    defer plan.deinit(allocator);
    return encodeZlibDynamicTokensAlloc(allocator, input, null, plan.tokens);
}

pub fn encodeZlibDynamicWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: CompressionOptions) ![]u8 {
    const plan = try planTokensWithDictionaryAlloc(allocator, input, dictionary, options);
    defer plan.deinit(allocator);
    return encodeZlibDynamicTokensAlloc(allocator, input, dictionary, plan.tokens);
}

pub fn encodeZlibBestAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    if (usesStoredFastPath(input, options)) return encodeZlibStoredAlloc(allocator, input);
    const plan = try planTokensAlloc(allocator, input, options);
    defer plan.deinit(allocator);
    return encodeZlibBestTokensAlloc(allocator, input, null, plan.tokens, options);
}

pub fn encodeZlibBestWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: CompressionOptions) ![]u8 {
    if (usesStoredFastPath(input, options)) return encodeZlibStoredWithDictionaryAlloc(allocator, input, dictionary);
    const plan = try planTokensWithDictionaryAlloc(allocator, input, dictionary, options);
    defer plan.deinit(allocator);
    return encodeZlibBestTokensAlloc(allocator, input, dictionary, plan.tokens, options);
}

pub fn encodeZlibBestSplitAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
    if (usesStoredFastPath(input, options)) return encodeZlibStoredSplitAlloc(allocator, input, block_len);
    return encodeZlibBestSplitDirectAlloc(allocator, input, null, block_len, options);
}

pub fn encodeZlibBestSplitWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
    if (usesStoredFastPath(input, options)) return encodeZlibStoredSplitWithDictionaryAlloc(allocator, input, dictionary, block_len);
    return encodeZlibBestSplitDirectAlloc(allocator, input, dictionary, block_len, options);
}

pub fn encodeZlibBestAdaptiveSplitAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) ![]u8 {
    if (usesStoredFastPath(input, options)) return encodeZlibStoredAlloc(allocator, input);
    const one_shot = try encodeZlibBestAlloc(allocator, input, options);
    errdefer allocator.free(one_shot);
    if (shouldSkipAdaptiveSplitSearch(input.len, split_options)) return one_shot;
    return encodeZlibBestAdaptiveSplitDirectAlloc(allocator, input, null, options, split_options, one_shot);
}

pub fn encodeZlibBestAdaptiveSplitWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) ![]u8 {
    if (usesStoredFastPath(input, options)) return encodeZlibStoredWithDictionaryAlloc(allocator, input, dictionary);
    const one_shot = try encodeZlibBestWithDictionaryAlloc(allocator, input, dictionary, options);
    errdefer allocator.free(one_shot);
    if (shouldSkipAdaptiveSplitSearch(input.len, split_options)) return one_shot;
    return encodeZlibBestAdaptiveSplitDirectAlloc(allocator, input, dictionary, options, split_options, one_shot);
}

fn encodeZlibRawAlloc(allocator: std.mem.Allocator, input: []const u8, raw: []const u8, dictionary: ?[]const u8) ![]u8 {
    const header_len: usize = if (dictionary == null) 2 else 6;
    const out = try allocator.alloc(u8, header_len + raw.len + 4);
    errdefer allocator.free(out);
    writeZlibHeader(out[0..header_len], dictionary);
    @memcpy(out[header_len..][0..raw.len], raw);
    std.mem.writeInt(u32, out[header_len + raw.len ..][0..4], checksum.adler32(input), .big);
    return out;
}

fn encodeZlibFixedTokensAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, tokens: []const lz77.Token) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    const header_len = try writeWrappedDeflatePrefix(allocator, &writer, dictionary);
    try writeFixedTokens(allocator, &writer, tokens, true);
    return finishZlibFrame(allocator, &writer, input, header_len);
}

fn encodeZlibDynamicTokensAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, tokens: []const lz77.Token) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    const header_len = try writeWrappedDeflatePrefix(allocator, &writer, dictionary);
    const plan = try DynamicCodingPlan.init(tokens);
    try writer.bytes.ensureTotalCapacity(allocator, header_len + (plan.bitCost(tokens) + 7) / 8 + 4);
    try plan.write(allocator, &writer, tokens, true);
    return finishZlibFrame(allocator, &writer, input, header_len);
}

fn encodeZlibBestTokensAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, tokens: []const lz77.Token, options: CompressionOptions) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    const header_len = try writeWrappedDeflatePrefix(allocator, &writer, dictionary);
    try writeBestTokensBlock(allocator, &writer, input, tokens, true, options);
    return finishZlibFrame(allocator, &writer, input, header_len);
}

fn encodeZlibBestSplitDirectAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, block_len: usize, options: CompressionOptions) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    const header_len = try writeWrappedDeflatePrefix(allocator, &writer, dictionary);
    try writeBestSplitBlocks(allocator, &writer, input, dictionary, block_len, options);
    return finishZlibFrame(allocator, &writer, input, header_len);
}

fn encodeZlibBestAdaptiveSplitDirectAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions, one_shot: []u8) ![]u8 {
    var writer = bitstream.BitWriter{};
    defer writer.deinit(allocator);
    const header_len = try writeWrappedDeflatePrefix(allocator, &writer, dictionary);
    try writeBestAdaptiveSplitBlocks(allocator, &writer, input, dictionary, options, split_options);
    return smallerWrappedAdaptiveOrOneShot(allocator, &writer, input, header_len, one_shot, .zlib);
}

fn writeWrappedDeflatePrefix(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, dictionary: ?[]const u8) !usize {
    const header_len: usize = if (dictionary == null) 2 else 6;
    try writer.bytes.ensureTotalCapacity(allocator, header_len);
    const header = try writer.bytes.addManyAsSlice(allocator, header_len);
    writeZlibHeader(header, dictionary);
    return header_len;
}

fn finishZlibFrame(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, input: []const u8, header_len: usize) ![]u8 {
    try writer.alignToByte(allocator);
    const footer_offset = writer.bytes.items.len;
    try writer.bytes.appendNTimes(allocator, 0, 4);
    std.mem.writeInt(u32, writer.bytes.items[footer_offset..][0..4], checksum.adler32(input), .big);
    const out = try writer.bytes.toOwnedSlice(allocator);
    std.debug.assert(out.len >= header_len + 4);
    writer.* = .{};
    return out;
}

fn writeZlibHeader(output: []u8, dictionary: ?[]const u8) void {
    output[0] = 0x78; // deflate, 32 KiB window
    if (dictionary) |dict| {
        // FDICT set, FLEVEL=0, FCHECK chosen so CMF*256+FLG is divisible by 31.
        output[1] = 0x20;
        std.mem.writeInt(u32, output[2..][0..4], checksum.adler32(dict), .big);
    } else {
        output[1] = 0x01; // fastest/no compression, valid FCHECK
    }
}

fn validateZlibFooter(input: []const u8, footer_offset: usize, actual: u32) Error!void {
    if (footer_offset > input.len or input.len - footer_offset < 4) return error.TruncatedFrame;
    const expected = std.mem.readInt(u32, input[footer_offset..][0..4], .big);
    if (actual != expected) return error.ChecksumMismatch;
    if (footer_offset + 4 != input.len) return error.TrailingData;
}

pub fn decodeZlibStored(input: []const u8, output: []u8) Error!usize {
    const header = try parseZlibHeader(input, null);
    const stored = (try decodeRawStoredOnlyIntoMaybeWithHash(checksum.Adler32, input[header.data_offset..], output)) orelse return error.InvalidDeflateBlockType;
    const footer_offset = header.data_offset + stored.result.input_read;
    try validateZlibFooter(input, footer_offset, stored.digest);
    return stored.result.output_written;
}

pub fn decodeZlibStoredWithDictionary(input: []const u8, output: []u8, dictionary: []const u8) Error!usize {
    const header = try parseZlibHeader(input, dictionary);

    // Stored deflate blocks do not reference history, so the dictionary is only
    // used to satisfy and validate the zlib DICTID before the stored payload.
    const stored = (try decodeRawStoredOnlyIntoMaybeWithHash(checksum.Adler32, input[header.data_offset..], output)) orelse return error.InvalidDeflateBlockType;
    const footer_offset = header.data_offset + stored.result.input_read;
    try validateZlibFooter(input, footer_offset, stored.digest);
    return stored.result.output_written;
}

pub fn decodeZlib(input: []const u8, output: []u8) Error!usize {
    return decodeZlibWithOptionalDictionary(input, output, null);
}

pub fn decodeZlibWithDictionary(input: []const u8, output: []u8, dictionary: []const u8) Error!usize {
    return decodeZlibWithOptionalDictionary(input, output, dictionary);
}

fn decodeZlibWithOptionalDictionary(input: []const u8, output: []u8, dictionary: ?[]const u8) Error!usize {
    const header = try parseZlibHeader(input, dictionary);
    const raw_dictionary = if (header.uses_dictionary) dictionary.? else "";

    if (try decodeRawStoredOnlyIntoMaybeWithHash(checksum.Adler32, input[header.data_offset..], output)) |stored| {
        const footer_offset = header.data_offset + stored.result.input_read;
        try validateZlibFooter(input, footer_offset, stored.digest);
        return stored.result.output_written;
    }

    const raw = try decodeRawAutoWithDictionary(input[header.data_offset..], raw_dictionary, output);
    const footer_offset = header.data_offset + raw.input_read;
    try validateZlibFooter(input, footer_offset, checksum.adler32(output[0..raw.output_written]));
    return raw.output_written;
}

pub fn decodeZlibStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeZlibStoredAllocWithOptionalDictionaryLimited(allocator, input, null, null);
}

pub fn decodeZlibStoredAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    return decodeZlibStoredAllocWithOptionalDictionaryLimited(allocator, input, null, max_output_len);
}

pub fn decodeZlibStoredAllocWithDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8) ![]u8 {
    return decodeZlibStoredAllocWithOptionalDictionaryLimited(allocator, input, dictionary, null);
}

pub fn decodeZlibStoredAllocWithDictionaryLimited(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, max_output_len: usize) ![]u8 {
    return decodeZlibStoredAllocWithOptionalDictionaryLimited(allocator, input, dictionary, max_output_len);
}

fn decodeZlibStoredAllocWithOptionalDictionaryLimited(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, max_output_len: ?usize) ![]u8 {
    const header = try parseZlibHeader(input, dictionary);
    const stored = (try decodeRawStoredOnlyAllocMaybeWithHash(checksum.Adler32, allocator, input[header.data_offset..], max_output_len)) orelse return error.InvalidDeflateBlockType;
    errdefer stored.deinit(allocator);
    const footer_offset = header.data_offset + stored.result.input_read;
    try validateZlibFooter(input, footer_offset, stored.digest);
    return stored.result.bytes;
}

pub fn decodeZlibAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeZlibAllocWithOptionalDictionary(allocator, input, null);
}

pub fn decodeZlibAllocWithDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8) ![]u8 {
    return decodeZlibAllocWithOptionalDictionary(allocator, input, dictionary);
}

pub fn decodeZlibAllocExactSize(allocator: std.mem.Allocator, input: []const u8, expected_output_len: usize) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryExactSize(allocator, input, null, expected_output_len);
}

pub fn decodeZlibAllocWithDictionaryExactSize(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, expected_output_len: usize) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryExactSize(allocator, input, dictionary, expected_output_len);
}

pub fn decodeZlibAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryLimited(allocator, input, null, max_output_len);
}

pub fn decodeZlibAllocWithDictionaryLimited(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, max_output_len: usize) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryLimited(allocator, input, dictionary, max_output_len);
}

fn decodeZlibAllocWithOptionalDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryLimited(allocator, input, dictionary, null);
}

fn decodeZlibAllocWithOptionalDictionaryLimited(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, max_output_len: ?usize) ![]u8 {
    const header = try parseZlibHeader(input, dictionary);
    const raw_dictionary = if (header.uses_dictionary) dictionary.? else "";

    if (try decodeRawStoredOnlyAllocMaybeWithHash(checksum.Adler32, allocator, input[header.data_offset..], max_output_len)) |stored| {
        errdefer stored.deinit(allocator);
        const footer_offset = header.data_offset + stored.result.input_read;
        try validateZlibFooter(input, footer_offset, stored.digest);
        return stored.result.bytes;
    }

    const raw = try decodeRawAutoAllocPartialWithDictionary(allocator, input[header.data_offset..], raw_dictionary, max_output_len);
    errdefer raw.deinit(allocator);
    const footer_offset = header.data_offset + raw.input_read;
    try validateZlibFooter(input, footer_offset, checksum.adler32(raw.bytes));
    return raw.bytes;
}

fn decodeZlibAllocWithOptionalDictionaryExactSize(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, expected_output_len: usize) ![]u8 {
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeZlibWithOptionalDictionary(input, out, dictionary) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

pub fn gzipStoredEncodedSize(input_len: usize) Error!usize {
    return gzipStoredEncodedSizeWithHeader(input_len, .{});
}

pub fn gzipStoredEncodedSizeWithHeader(input_len: usize, header_options: GzipHeaderOptions) Error!usize {
    const raw_len = try rawStoredEncodedSize(input_len);
    const header_len = try gzipHeaderEncodedSize(header_options);
    const with_header = std.math.add(usize, header_len, raw_len) catch return error.IntegerOverflow;
    return std.math.add(usize, with_header, 8) catch error.IntegerOverflow;
}

pub fn encodeGzipStored(input: []const u8, output: []u8) Error!usize {
    return encodeGzipStoredWithHeader(input, output, .{});
}

pub fn encodeGzipStoredWithHeader(input: []const u8, output: []u8, header_options: GzipHeaderOptions) Error!usize {
    const required = try gzipStoredEncodedSizeWithHeader(input.len, header_options);
    if (output.len < required) return error.OutputTooSmall;

    const header_len = try writeGzipHeader(output[0..required], header_options);
    const raw_written = try encodeRawStored(input, output[header_len .. required - 8]);
    const footer_offset = header_len + raw_written;
    std.mem.writeInt(u32, output[footer_offset..][0..4], checksum.crc32Best(input), .little);
    std.mem.writeInt(u32, output[footer_offset + 4 ..][0..4], @truncate(input.len), .little);
    return footer_offset + 8;
}

pub fn encodeGzipStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return encodeGzipStoredWithHeaderAlloc(allocator, input, .{});
}

pub fn encodeGzipStoredWithHeaderAlloc(allocator: std.mem.Allocator, input: []const u8, header_options: GzipHeaderOptions) ![]u8 {
    const required = try gzipStoredEncodedSizeWithHeader(input.len, header_options);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    const written = try encodeGzipStoredWithHeader(input, out, header_options);
    std.debug.assert(written == out.len);
    return out;
}

fn encodeGzipStoredSplitAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize) ![]u8 {
    return encodeGzipStoredSplitWithHeaderAlloc(allocator, input, block_len, .{});
}

fn encodeGzipStoredSplitWithHeaderAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, header_options: GzipHeaderOptions) ![]u8 {
    if (block_len == 0) return error.InvalidBlockPlan;
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    _ = try writeGzipPrefixWithOptions(allocator, &writer, header_options);
    try writeStoredSplitBlocks(allocator, &writer, input, block_len);
    return finishGzipFrame(allocator, &writer, input);
}

pub fn encodeGzipFixedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return encodeGzipFixedWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeGzipFixedWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    return encodeGzipFixedWithHeaderAlloc(allocator, input, options, .{});
}

pub fn encodeGzipFixedWithHeaderAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions, header_options: GzipHeaderOptions) ![]u8 {
    const plan = try planTokensAlloc(allocator, input, options);
    defer plan.deinit(allocator);
    return encodeGzipFixedTokensWithHeaderAlloc(allocator, input, plan.tokens, header_options);
}

pub fn encodeGzipDynamicLiteralAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return encodeGzipDynamicLiteralWithHeaderAlloc(allocator, input, .{});
}

pub fn encodeGzipDynamicLiteralWithHeaderAlloc(allocator: std.mem.Allocator, input: []const u8, header_options: GzipHeaderOptions) ![]u8 {
    const plan = try lz77.literalPlanAlloc(allocator, input);
    defer plan.deinit(allocator);
    return encodeGzipDynamicTokensWithHeaderAlloc(allocator, input, plan.tokens, header_options);
}

pub fn encodeGzipDynamicWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    return encodeGzipDynamicWithHeaderAlloc(allocator, input, options, .{});
}

pub fn encodeGzipDynamicWithHeaderAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions, header_options: GzipHeaderOptions) ![]u8 {
    const plan = try planTokensAlloc(allocator, input, options);
    defer plan.deinit(allocator);
    return encodeGzipDynamicTokensWithHeaderAlloc(allocator, input, plan.tokens, header_options);
}

pub fn encodeGzipBestAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    return encodeGzipBestWithHeaderAlloc(allocator, input, options, .{});
}

pub fn encodeGzipBestWithHeaderAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions, header_options: GzipHeaderOptions) ![]u8 {
    if (usesStoredFastPath(input, options)) return encodeGzipStoredWithHeaderAlloc(allocator, input, header_options);
    const plan = try planTokensAlloc(allocator, input, options);
    defer plan.deinit(allocator);
    return encodeGzipBestTokensWithHeaderAlloc(allocator, input, plan.tokens, options, header_options);
}

pub fn encodeGzipBestSplitAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
    return encodeGzipBestSplitWithHeaderAlloc(allocator, input, block_len, options, .{});
}

pub fn encodeGzipBestSplitWithHeaderAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: CompressionOptions, header_options: GzipHeaderOptions) ![]u8 {
    if (usesStoredFastPath(input, options)) return encodeGzipStoredSplitWithHeaderAlloc(allocator, input, block_len, header_options);
    return encodeGzipBestSplitDirectWithHeaderAlloc(allocator, input, block_len, options, header_options);
}

pub fn encodeGzipBestAdaptiveSplitAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) ![]u8 {
    return encodeGzipBestAdaptiveSplitWithHeaderAlloc(allocator, input, options, split_options, .{});
}

pub fn encodeGzipBestAdaptiveSplitWithHeaderAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions, header_options: GzipHeaderOptions) ![]u8 {
    if (usesStoredFastPath(input, options)) return encodeGzipStoredWithHeaderAlloc(allocator, input, header_options);
    const one_shot = try encodeGzipBestWithHeaderAlloc(allocator, input, options, header_options);
    errdefer allocator.free(one_shot);
    if (shouldSkipAdaptiveSplitSearch(input.len, split_options)) return one_shot;
    return encodeGzipBestAdaptiveSplitDirectWithHeaderAlloc(allocator, input, options, split_options, one_shot, header_options);
}

fn encodeGzipFixedTokensAlloc(allocator: std.mem.Allocator, input: []const u8, tokens: []const lz77.Token) ![]u8 {
    return encodeGzipFixedTokensWithHeaderAlloc(allocator, input, tokens, .{});
}

fn encodeGzipFixedTokensWithHeaderAlloc(allocator: std.mem.Allocator, input: []const u8, tokens: []const lz77.Token, header_options: GzipHeaderOptions) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    _ = try writeGzipPrefixWithOptions(allocator, &writer, header_options);
    try writeFixedTokens(allocator, &writer, tokens, true);
    return finishGzipFrame(allocator, &writer, input);
}

fn encodeGzipDynamicTokensAlloc(allocator: std.mem.Allocator, input: []const u8, tokens: []const lz77.Token) ![]u8 {
    return encodeGzipDynamicTokensWithHeaderAlloc(allocator, input, tokens, .{});
}

fn encodeGzipDynamicTokensWithHeaderAlloc(allocator: std.mem.Allocator, input: []const u8, tokens: []const lz77.Token, header_options: GzipHeaderOptions) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    const header_len = try writeGzipPrefixWithOptions(allocator, &writer, header_options);
    const plan = try DynamicCodingPlan.init(tokens);
    try writer.bytes.ensureTotalCapacity(allocator, header_len + (plan.bitCost(tokens) + 7) / 8 + 8);
    try plan.write(allocator, &writer, tokens, true);
    return finishGzipFrame(allocator, &writer, input);
}

fn encodeGzipBestTokensAlloc(allocator: std.mem.Allocator, input: []const u8, tokens: []const lz77.Token, options: CompressionOptions) ![]u8 {
    return encodeGzipBestTokensWithHeaderAlloc(allocator, input, tokens, options, .{});
}

fn encodeGzipBestTokensWithHeaderAlloc(allocator: std.mem.Allocator, input: []const u8, tokens: []const lz77.Token, options: CompressionOptions, header_options: GzipHeaderOptions) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    _ = try writeGzipPrefixWithOptions(allocator, &writer, header_options);
    try writeBestTokensBlock(allocator, &writer, input, tokens, true, options);
    return finishGzipFrame(allocator, &writer, input);
}

fn encodeGzipBestSplitDirectAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
    return encodeGzipBestSplitDirectWithHeaderAlloc(allocator, input, block_len, options, .{});
}

fn encodeGzipBestSplitDirectWithHeaderAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: CompressionOptions, header_options: GzipHeaderOptions) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    _ = try writeGzipPrefixWithOptions(allocator, &writer, header_options);
    try writeBestSplitBlocks(allocator, &writer, input, null, block_len, options);
    return finishGzipFrame(allocator, &writer, input);
}

fn encodeGzipBestAdaptiveSplitDirectAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions, one_shot: []u8) ![]u8 {
    return encodeGzipBestAdaptiveSplitDirectWithHeaderAlloc(allocator, input, options, split_options, one_shot, .{});
}

fn encodeGzipBestAdaptiveSplitDirectWithHeaderAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions, one_shot: []u8, header_options: GzipHeaderOptions) ![]u8 {
    var writer = bitstream.BitWriter{};
    defer writer.deinit(allocator);
    _ = try writeGzipPrefixWithOptions(allocator, &writer, header_options);
    try writeBestAdaptiveSplitBlocks(allocator, &writer, input, null, options, split_options);
    return smallerWrappedAdaptiveOrOneShot(allocator, &writer, input, try gzipHeaderEncodedSize(header_options), one_shot, .gzip);
}

fn writeGzipPrefix(allocator: std.mem.Allocator, writer: *bitstream.BitWriter) !void {
    _ = try writeGzipPrefixWithOptions(allocator, writer, .{});
}

fn writeGzipPrefixWithOptions(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, header_options: GzipHeaderOptions) !usize {
    const header_len = try gzipHeaderEncodedSize(header_options);
    try writer.bytes.ensureTotalCapacity(allocator, writer.bytes.items.len + header_len);
    const header = try writer.bytes.addManyAsSlice(allocator, header_len);
    const written = try writeGzipHeader(header, header_options);
    std.debug.assert(written == header_len);
    return header_len;
}

fn finishGzipFrame(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, input: []const u8) ![]u8 {
    try writer.alignToByte(allocator);
    const footer = writer.bytes.items.len;
    try writer.bytes.appendNTimes(allocator, 0, 8);
    std.mem.writeInt(u32, writer.bytes.items[footer..][0..4], checksum.crc32Best(input), .little);
    std.mem.writeInt(u32, writer.bytes.items[footer + 4 ..][0..4], @truncate(input.len), .little);
    const out = try writer.bytes.toOwnedSlice(allocator);
    writer.* = .{};
    return out;
}

const WrapperKind = enum { zlib, gzip };

fn smallerWrappedAdaptiveOrOneShot(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, input: []const u8, prefix_len: usize, one_shot: []u8, comptime kind: WrapperKind) ![]u8 {
    const adaptive = switch (kind) {
        .zlib => try finishZlibFrame(allocator, writer, input, prefix_len),
        .gzip => try finishGzipFrame(allocator, writer, input),
    };
    errdefer allocator.free(adaptive);
    if (adaptive.len < one_shot.len) {
        allocator.free(one_shot);
        return adaptive;
    }
    allocator.free(adaptive);
    return one_shot;
}

fn validateGzipFooterPartial(input: []const u8, footer_offset: usize, actual_crc: u32, output_len: usize) Error!void {
    if (footer_offset > input.len or input.len - footer_offset < 8) return error.TruncatedFrame;
    const expected_crc = std.mem.readInt(u32, input[footer_offset..][0..4], .little);
    const expected_size = std.mem.readInt(u32, input[footer_offset + 4 ..][0..4], .little);
    if (actual_crc != expected_crc) return error.ChecksumMismatch;
    if (@as(u32, @truncate(output_len)) != expected_size) return error.SizeMismatch;
}

fn validateGzipFooter(input: []const u8, footer_offset: usize, actual_crc: u32, output_len: usize) Error!void {
    try validateGzipFooterPartial(input, footer_offset, actual_crc, output_len);
    if (footer_offset + 8 != input.len) return error.TrailingData;
}

pub fn decodeGzipStored(input: []const u8, output: []u8) Error!usize {
    const data_offset = try parseGzipHeader(input);
    const stored = (try decodeRawStoredOnlyIntoMaybeWithHash(checksum.Crc32Slice16, input[data_offset..], output)) orelse return error.InvalidDeflateBlockType;
    const footer_offset = data_offset + stored.result.input_read;
    try validateGzipFooter(input, footer_offset, stored.digest, stored.result.output_written);
    return stored.result.output_written;
}

pub fn decodeGzip(input: []const u8, output: []u8) Error!usize {
    const data_offset = try parseGzipHeader(input);

    if (try decodeRawStoredOnlyIntoMaybeWithHash(checksum.Crc32Slice16, input[data_offset..], output)) |stored| {
        const footer_offset = data_offset + stored.result.input_read;
        try validateGzipFooter(input, footer_offset, stored.digest, stored.result.output_written);
        return stored.result.output_written;
    }

    const raw = try decodeRawAuto(input[data_offset..], output);
    const footer_offset = data_offset + raw.input_read;
    const payload = output[0..raw.output_written];
    try validateGzipFooter(input, footer_offset, checksum.crc32Best(payload), raw.output_written);
    return raw.output_written;
}

pub fn decodeGzipStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeGzipStoredAllocLimitedInternal(allocator, input, null);
}

pub fn decodeGzipStoredAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    return decodeGzipStoredAllocLimitedInternal(allocator, input, max_output_len);
}

fn decodeGzipStoredAllocLimitedInternal(allocator: std.mem.Allocator, input: []const u8, max_output_len: ?usize) ![]u8 {
    const data_offset = try parseGzipHeader(input);
    const stored = (try decodeRawStoredOnlyAllocMaybeWithHash(checksum.Crc32Slice16, allocator, input[data_offset..], max_output_len)) orelse return error.InvalidDeflateBlockType;
    errdefer stored.deinit(allocator);
    const footer_offset = data_offset + stored.result.input_read;
    try validateGzipFooter(input, footer_offset, stored.digest, stored.result.bytes.len);
    return stored.result.bytes;
}

pub fn decodeGzipConcatenatedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeGzipConcatenatedAllocLimitedInternal(allocator, input, null);
}

pub fn decodeGzipConcatenatedAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    return decodeGzipConcatenatedAllocLimitedInternal(allocator, input, max_output_len);
}

pub fn decodeGzipConcatenatedAllocExactSize(allocator: std.mem.Allocator, input: []const u8, expected_output_len: usize) ![]u8 {
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeGzipConcatenated(input, out) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

pub fn decodeGzipConcatenated(input: []const u8, output: []u8) Error!usize {
    var offset: usize = 0;
    var out_offset: usize = 0;
    while (offset < input.len) {
        const data_offset = try parseGzipHeader(input[offset..]);
        const before_member = out_offset;
        const raw = try decodeRawAuto(input[offset + data_offset ..], output[out_offset..]);
        out_offset += raw.output_written;
        const footer_offset = offset + data_offset + raw.input_read;
        const member_payload = output[before_member..out_offset];
        try validateGzipFooterPartial(input, footer_offset, checksum.crc32Best(member_payload), member_payload.len);
        offset = footer_offset + 8;
    }
    return out_offset;
}

fn decodeGzipConcatenatedAllocLimitedInternal(allocator: std.mem.Allocator, input: []const u8, max_output_len: ?usize) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var offset: usize = 0;
    while (offset < input.len) {
        const data_offset = try parseGzipHeader(input[offset..]);
        const before_member = out.items.len;
        const raw = try decodeRawAutoAppendPartialWithDictionary(allocator, input[offset + data_offset ..], "", &out, max_output_len);
        const footer_offset = offset + data_offset + raw.input_read;
        const member_payload = out.items[before_member..];
        try validateGzipFooterPartial(input, footer_offset, checksum.crc32Best(member_payload), member_payload.len);
        offset = footer_offset + 8;
    }
    return out.toOwnedSlice(allocator);
}

pub fn decodeGzipAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeGzipAllocLimitedInternal(allocator, input, null);
}

pub fn decodeGzipAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    return decodeGzipAllocLimitedInternal(allocator, input, max_output_len);
}

pub fn decodeGzipAllocExactSize(allocator: std.mem.Allocator, input: []const u8, expected_output_len: usize) ![]u8 {
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeGzip(input, out) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

fn decodeGzipAllocLimitedInternal(allocator: std.mem.Allocator, input: []const u8, max_output_len: ?usize) ![]u8 {
    if (try decodeGzipAllocFooterSize(allocator, input, max_output_len)) |decoded| return decoded;

    const data_offset = try parseGzipHeader(input);

    if (try decodeRawStoredOnlyAllocMaybeWithHash(checksum.Crc32Slice16, allocator, input[data_offset..], max_output_len)) |stored| {
        errdefer stored.deinit(allocator);
        const footer_offset = data_offset + stored.result.input_read;
        try validateGzipFooter(input, footer_offset, stored.digest, stored.result.bytes.len);
        return stored.result.bytes;
    }

    const raw = try decodeRawAutoAllocPartialWithDictionary(allocator, input[data_offset..], "", max_output_len);
    errdefer raw.deinit(allocator);
    const footer_offset = data_offset + raw.input_read;
    try validateGzipFooter(input, footer_offset, checksum.crc32Best(raw.bytes), raw.bytes.len);
    return raw.bytes;
}

fn decodeGzipAllocFooterSize(allocator: std.mem.Allocator, input: []const u8, max_output_len: ?usize) !?[]u8 {
    if (input.len < gzip_header.len + 8) return null;
    const expected_size: usize = std.mem.readInt(u32, input[input.len - 4 ..][0..4], .little);
    try ensureOutputLimit(0, expected_size, max_output_len);
    const out = try allocator.alloc(u8, expected_size);
    errdefer allocator.free(out);
    const written = decodeGzip(input, out) catch |err| switch (err) {
        error.OutputTooSmall => return null,
        else => return err,
    };
    if (written != expected_size) return error.SizeMismatch;
    return out;
}

const ZlibHeader = struct {
    data_offset: usize,
    uses_dictionary: bool,
};

fn parseZlibHeader(input: []const u8, dictionary: ?[]const u8) Error!ZlibHeader {
    if (input.len < 2) return error.TruncatedFrame;
    const cmf = input[0];
    const flg = input[1];
    if ((cmf & 0x0f) != 8) return error.BadZlibHeader;
    if ((cmf >> 4) > 7) return error.BadZlibHeader;
    const combined: u16 = (@as(u16, cmf) << 8) | flg;
    if (combined % 31 != 0) return error.BadZlibHeader;
    if ((flg & 0x20) == 0) return .{ .data_offset = 2, .uses_dictionary = false };

    if (input.len < 6) return error.TruncatedFrame;
    const expected_dict_id = std.mem.readInt(u32, input[2..][0..4], .big);
    const actual_dictionary = dictionary orelse return error.NeedDictionary;
    if (checksum.adler32(actual_dictionary) != expected_dict_id) return error.ChecksumMismatch;
    return .{ .data_offset = 6, .uses_dictionary = true };
}

const gzip_header = [_]u8{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03 };

fn gzipHeaderEncodedSize(header_options: GzipHeaderOptions) Error!usize {
    try validateGzipZeroTerminatedField(header_options.filename);
    try validateGzipZeroTerminatedField(header_options.comment);

    var len: usize = gzip_header.len;
    if (header_options.extra) |extra| {
        if (extra.len > std.math.maxInt(u16)) return error.IntegerOverflow;
        len = std.math.add(usize, len, 2) catch return error.IntegerOverflow;
        len = std.math.add(usize, len, extra.len) catch return error.IntegerOverflow;
    }
    if (header_options.filename) |filename| {
        len = std.math.add(usize, len, filename.len) catch return error.IntegerOverflow;
        len = std.math.add(usize, len, 1) catch return error.IntegerOverflow;
    }
    if (header_options.comment) |comment| {
        len = std.math.add(usize, len, comment.len) catch return error.IntegerOverflow;
        len = std.math.add(usize, len, 1) catch return error.IntegerOverflow;
    }
    if (header_options.header_crc) {
        len = std.math.add(usize, len, 2) catch return error.IntegerOverflow;
    }
    return len;
}

fn validateGzipZeroTerminatedField(field: ?[]const u8) Error!void {
    if (field) |bytes| {
        // FNAME and FCOMMENT are serialized as NUL-terminated byte strings.
        // Reject embedded NULs rather than silently truncating metadata for
        // downstream gzip tools or breaking our own FHCRC reproduction.
        if (std.mem.indexOfScalar(u8, bytes, 0) != null) return error.BadGzipHeader;
    }
}

fn writeGzipHeader(output: []u8, header_options: GzipHeaderOptions) Error!usize {
    const required = try gzipHeaderEncodedSize(header_options);
    if (output.len < required) return error.OutputTooSmall;

    output[0] = 0x1f;
    output[1] = 0x8b;
    output[2] = 0x08;
    output[3] = (@as(u8, @intFromBool(header_options.text)) << 0) |
        (@as(u8, @intFromBool(header_options.header_crc)) << 1) |
        (@as(u8, @intFromBool(header_options.extra != null)) << 2) |
        (@as(u8, @intFromBool(header_options.filename != null)) << 3) |
        (@as(u8, @intFromBool(header_options.comment != null)) << 4);
    std.mem.writeInt(u32, output[4..8], header_options.mtime, .little);
    output[8] = header_options.xfl;
    output[9] = header_options.os;

    var offset: usize = gzip_header.len;
    if (header_options.extra) |extra| {
        std.mem.writeInt(u16, output[offset..][0..2], @intCast(extra.len), .little);
        offset += 2;
        @memcpy(output[offset..][0..extra.len], extra);
        offset += extra.len;
    }
    if (header_options.filename) |filename| {
        @memcpy(output[offset..][0..filename.len], filename);
        offset += filename.len;
        output[offset] = 0;
        offset += 1;
    }
    if (header_options.comment) |comment| {
        @memcpy(output[offset..][0..comment.len], comment);
        offset += comment.len;
        output[offset] = 0;
        offset += 1;
    }
    if (header_options.header_crc) {
        const actual: u16 = @truncate(checksum.crc32Best(output[0..offset]));
        std.mem.writeInt(u16, output[offset..][0..2], actual, .little);
        offset += 2;
    }
    std.debug.assert(offset == required);
    return offset;
}

fn parseGzipHeader(input: []const u8) Error!usize {
    if (input.len < 10) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..2], &.{ 0x1f, 0x8b })) return error.BadGzipHeader;
    if (input[2] != 8) return error.BadGzipHeader;
    const flags = input[3];
    if ((flags & 0xe0) != 0) return error.BadGzipHeader;

    var offset: usize = 10;
    if ((flags & 0x04) != 0) {
        if (input.len - offset < 2) return error.TruncatedFrame;
        const xlen: usize = std.mem.readInt(u16, input[offset..][0..2], .little);
        offset += 2;
        if (input.len - offset < xlen) return error.TruncatedFrame;
        offset += xlen;
    }
    if ((flags & 0x08) != 0) offset = try skipGzipZeroTerminated(input, offset);
    if ((flags & 0x10) != 0) offset = try skipGzipZeroTerminated(input, offset);
    if ((flags & 0x02) != 0) {
        if (input.len - offset < 2) return error.TruncatedFrame;
        const expected = std.mem.readInt(u16, input[offset..][0..2], .little);
        const actual: u16 = @truncate(checksum.crc32Best(input[0..offset]));
        if (actual != expected) return error.BadGzipHeader;
        offset += 2;
    }
    return offset;
}

fn skipGzipZeroTerminated(input: []const u8, offset: usize) Error!usize {
    var index = offset;
    while (index < input.len) : (index += 1) {
        if (input[index] == 0) return index + 1;
    }
    return error.TruncatedFrame;
}

fn writeStoredHeader(final: bool, len: u16, output: []u8) void {
    std.debug.assert(output.len >= 5);
    output[0] = @intFromBool(final);
    std.mem.writeInt(u16, output[1..3], len, .little);
    std.mem.writeInt(u16, output[3..5], ~len, .little);
}

fn expectGzipRoundTripWithPrefix(encoded: []const u8, expected_prefix: []const u8, plain: []const u8) !void {
    try std.testing.expect(encoded.len >= expected_prefix.len);
    try std.testing.expectEqualSlices(u8, expected_prefix, encoded[0..expected_prefix.len]);
    const decoded = try decodeGzipAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, plain, decoded);
}

test "raw stored deflate matches zlib level-0 vectors" {
    const empty = try encodeRawStoredAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqualSlices(u8, &.{ 0x01, 0x00, 0x00, 0xff, 0xff }, empty);

    const one = try encodeRawStoredAlloc(std.testing.allocator, "a");
    defer std.testing.allocator.free(one);
    try std.testing.expectEqualSlices(u8, &.{ 0x01, 0x01, 0x00, 0xfe, 0xff, 'a' }, one);

    const hello = try encodeRawStoredAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(hello);
    try std.testing.expectEqualSlices(u8, &.{ 0x01, 0x05, 0x00, 0xfa, 0xff, 'h', 'e', 'l', 'l', 'o' }, hello);
}

test "raw stored deflate round trips across block boundary" {
    var input: [max_stored_block_len + 3]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @truncate((i * 17 + 91) & 0xff);

    const encoded = try encodeRawStoredAlloc(std.testing.allocator, &input);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeRawStoredAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "raw stored deflate reports malformed blocks" {
    var invalid_type = [_]u8{ 0x03, 0x00, 0x00, 0xff, 0xff };
    var out: [8]u8 = undefined;
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeRawStored(&invalid_type, &out));

    var bad_nlen = [_]u8{ 0x01, 0x01, 0x00, 0xff, 0xff, 'x' };
    try std.testing.expectError(error.StoredLengthMismatch, decodeRawStored(&bad_nlen, &out));

    const valid = [_]u8{ 0x01, 0x04, 0x00, 0xfb, 0xff, 't', 'e', 's', 't' };
    try std.testing.expectError(error.OutputTooSmall, decodeRawStored(&valid, out[0..2]));
}

test "stored deflate decoders ignore byte-alignment padding bits" {
    // RFC 1951 only assigns meaning to the first three stored-block header
    // bits. The remaining bits before the LEN/NLEN byte boundary are padding
    // and may be non-zero; zlib accepts such streams, so Vort must not treat
    // them as frame corruption.
    const raw = &.{ 0x09, 0x00, 0x00, 0xff, 0xff };
    var out: [1]u8 = undefined;
    const decoded = try decodeRawStored(raw, &out);
    try std.testing.expectEqual(@as(usize, 0), decoded.output_written);
    try std.testing.expectEqual(raw.len, decoded.input_read);

    const stored_alloc = try decodeRawStoredAlloc(std.testing.allocator, raw);
    defer std.testing.allocator.free(stored_alloc);
    try std.testing.expectEqualSlices(u8, "", stored_alloc);

    const auto_alloc = try decodeRawAutoAlloc(std.testing.allocator, raw);
    defer std.testing.allocator.free(auto_alloc);
    try std.testing.expectEqualSlices(u8, "", auto_alloc);

    const zlib_frame = &.{ 0x78, 0x01, 0x09, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x01 };
    const zlib_stored = try decodeZlibStoredAlloc(std.testing.allocator, zlib_frame);
    defer std.testing.allocator.free(zlib_stored);
    try std.testing.expectEqualSlices(u8, "", zlib_stored);
    const zlib_auto = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
    defer std.testing.allocator.free(zlib_auto);
    try std.testing.expectEqualSlices(u8, "", zlib_auto);

    const gzip_frame = &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0x09, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    const gzip_stored = try decodeGzipStoredAlloc(std.testing.allocator, gzip_frame);
    defer std.testing.allocator.free(gzip_stored);
    try std.testing.expectEqualSlices(u8, "", gzip_stored);
    const gzip_auto = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
    defer std.testing.allocator.free(gzip_auto);
    try std.testing.expectEqualSlices(u8, "", gzip_auto);
}

test "stored deflate alloc decoders enforce output limits" {
    const raw = try encodeRawStoredAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(raw);
    try std.testing.expectError(error.OutputLimitExceeded, decodeRawStoredAllocLimited(std.testing.allocator, raw, 4));
    const raw_ok = try decodeRawStoredAllocLimited(std.testing.allocator, raw, 5);
    defer std.testing.allocator.free(raw_ok);
    try std.testing.expectEqualSlices(u8, "hello", raw_ok);

    const zlib_frame = try encodeZlibStoredAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(zlib_frame);
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibStoredAllocLimited(std.testing.allocator, zlib_frame, 4));
    const zlib_ok = try decodeZlibStoredAllocLimited(std.testing.allocator, zlib_frame, 5);
    defer std.testing.allocator.free(zlib_ok);
    try std.testing.expectEqualSlices(u8, "hello", zlib_ok);

    const gzip_frame = try encodeGzipStoredAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(gzip_frame);
    try std.testing.expectError(error.OutputLimitExceeded, decodeGzipStoredAllocLimited(std.testing.allocator, gzip_frame, 4));
    const gzip_ok = try decodeGzipStoredAllocLimited(std.testing.allocator, gzip_frame, 5);
    defer std.testing.allocator.free(gzip_ok);
    try std.testing.expectEqualSlices(u8, "hello", gzip_ok);
}

test "zlib stored wrapper matches level-0 vectors" {
    const empty = try encodeZlibStoredAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqualSlices(u8, &.{ 0x78, 0x01, 0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x01 }, empty);

    const hello = try encodeZlibStoredAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(hello);
    try std.testing.expectEqualSlices(u8, &.{ 0x78, 0x01, 0x01, 0x05, 0x00, 0xfa, 0xff, 'h', 'e', 'l', 'l', 'o', 0x06, 0x2c, 0x02, 0x15 }, hello);
}

test "zlib stored wrapper validates checksum header and trailing data" {
    const encoded = try encodeZlibStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeZlibStoredAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "payload", decoded);

    var bad_header = try encodeZlibStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(bad_header);
    bad_header[1] ^= 1;
    var out: [32]u8 = undefined;
    try std.testing.expectError(error.BadZlibHeader, decodeZlibStored(bad_header, &out));

    var bad_checksum = try encodeZlibStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(bad_checksum);
    bad_checksum[bad_checksum.len - 1] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibStored(bad_checksum, &out));

    var with_trailing: [64]u8 = undefined;
    @memcpy(with_trailing[0..encoded.len], encoded);
    with_trailing[encoded.len] = 0;
    try std.testing.expectError(error.TrailingData, decodeZlibStored(with_trailing[0 .. encoded.len + 1], &out));
    try std.testing.expectError(error.TrailingData, decodeZlibStoredAlloc(std.testing.allocator, with_trailing[0 .. encoded.len + 1]));
}

test "gzip stored wrapper matches level-0 vectors" {
    const empty = try encodeGzipStoredAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqualSlices(u8, &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, empty);

    const hello = try encodeGzipStoredAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(hello);
    try std.testing.expectEqualSlices(u8, &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0x01, 0x05, 0x00, 0xfa, 0xff, 'h', 'e', 'l', 'l', 'o', 0x86, 0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00 }, hello);
}

test "gzip encoders can emit metadata-rich headers with FHCRC" {
    const payload = "metadata payload metadata payload";
    const extra = [_]u8{ 0x55, 0xaa, 0x00, 0xff };
    const header_options = GzipHeaderOptions{
        .text = true,
        .mtime = 0x12345678,
        .xfl = 0x02,
        .os = 0xff,
        .extra = &extra,
        .filename = "sample.txt",
        .comment = "generated by vort",
        .header_crc = true,
    };
    const expected_prefix = &.{
        0x1f, 0x8b, 0x08, 0x1f, 0x78, 0x56, 0x34, 0x12, 0x02, 0xff,
        0x04, 0x00, 0x55, 0xaa, 0x00, 0xff, 's',  'a',  'm',  'p',
        'l',  'e',  '.',  't',  'x',  't',  0x00, 'g',  'e',  'n',
        'e',  'r',  'a',  't',  'e',  'd',  ' ',  'b',  'y',  ' ',
        'v',  'o',  'r',  't',  0x00, 0x05, 0x5d,
    };

    try std.testing.expectEqual(
        try gzipStoredEncodedSizeWithHeader(payload.len, header_options),
        (try rawStoredEncodedSize(payload.len)) + expected_prefix.len + 8,
    );

    const stored = try encodeGzipStoredWithHeaderAlloc(std.testing.allocator, payload, header_options);
    defer std.testing.allocator.free(stored);
    try expectGzipRoundTripWithPrefix(stored, expected_prefix, payload);

    const fixed = try encodeGzipFixedWithHeaderAlloc(std.testing.allocator, payload, .{}, header_options);
    defer std.testing.allocator.free(fixed);
    try expectGzipRoundTripWithPrefix(fixed, expected_prefix, payload);

    const dynamic = try encodeGzipDynamicWithHeaderAlloc(std.testing.allocator, payload, optionsForLevel(.default), header_options);
    defer std.testing.allocator.free(dynamic);
    try expectGzipRoundTripWithPrefix(dynamic, expected_prefix, payload);

    const best = try encodeGzipBestWithHeaderAlloc(std.testing.allocator, payload, optionsForLevel(.default), header_options);
    defer std.testing.allocator.free(best);
    try expectGzipRoundTripWithPrefix(best, expected_prefix, payload);

    const split = try encodeGzipBestSplitWithHeaderAlloc(std.testing.allocator, payload, 7, optionsForLevel(.default), header_options);
    defer std.testing.allocator.free(split);
    try expectGzipRoundTripWithPrefix(split, expected_prefix, payload);

    const level_options = optionsForLevel(.default);
    const adaptive = try encodeGzipBestAdaptiveSplitWithHeaderAlloc(std.testing.allocator, payload, level_options, level_options.split_options, header_options);
    defer std.testing.allocator.free(adaptive);
    try expectGzipRoundTripWithPrefix(adaptive, expected_prefix, payload);
}

test "gzip header option validation rejects unterminated field ambiguity" {
    const bad_filename = [_]u8{ 'b', 'a', 'd', 0, 'n', 'a', 'm', 'e' };
    try std.testing.expectError(error.BadGzipHeader, gzipStoredEncodedSizeWithHeader(1, .{ .filename = &bad_filename }));
    try std.testing.expectError(error.BadGzipHeader, encodeGzipStoredWithHeaderAlloc(std.testing.allocator, "x", .{ .comment = &bad_filename }));

    const too_large_extra = try std.testing.allocator.alloc(u8, std.math.maxInt(u16) + 1);
    defer std.testing.allocator.free(too_large_extra);
    try std.testing.expectError(error.IntegerOverflow, gzipStoredEncodedSizeWithHeader(1, .{ .extra = too_large_extra }));
}

test "gzip stored wrapper validates crc size header and trailing data" {
    const encoded = try encodeGzipStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeGzipStoredAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "payload", decoded);

    var bad_header = try encodeGzipStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(bad_header);
    bad_header[0] = 0;
    var out: [32]u8 = undefined;
    try std.testing.expectError(error.BadGzipHeader, decodeGzipStored(bad_header, &out));

    var bad_crc = try encodeGzipStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(bad_crc);
    bad_crc[bad_crc.len - 8] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeGzipStored(bad_crc, &out));

    var bad_size = try encodeGzipStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(bad_size);
    bad_size[bad_size.len - 4] ^= 1;
    try std.testing.expectError(error.SizeMismatch, decodeGzipStored(bad_size, &out));

    var with_trailing: [64]u8 = undefined;
    @memcpy(with_trailing[0..encoded.len], encoded);
    with_trailing[encoded.len] = 0;
    try std.testing.expectError(error.TrailingData, decodeGzipStored(with_trailing[0 .. encoded.len + 1], &out));
    try std.testing.expectError(error.TrailingData, decodeGzipStoredAlloc(std.testing.allocator, with_trailing[0 .. encoded.len + 1]));
}

test "raw fixed Huffman literal/match inflate matches zlib fixed vectors" {
    const cases = [_]struct { compressed: []const u8, plain: []const u8 }{
        .{ .compressed = &.{ 0x03, 0x00 }, .plain = "" },
        .{ .compressed = &.{ 0x4b, 0x04, 0x00 }, .plain = "a" },
        .{ .compressed = &.{ 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 }, .plain = "hello" },
        .{ .compressed = &.{ 0x4b, 0x4c, 0x4a, 0x4e, 0x49, 0x4d, 0x03, 0x00 }, .plain = "abcdef" },
    };
    for (cases) |case| {
        var out: [64]u8 = undefined;
        const decoded = try decodeRawFixed(case.compressed, &out);
        try std.testing.expectEqualSlices(u8, case.plain, out[0..decoded.output_written]);
        const owned = try decodeRawFixedAllocStrict(std.testing.allocator, case.compressed);
        defer std.testing.allocator.free(owned);
        try std.testing.expectEqualSlices(u8, case.plain, owned);
    }
}

test "single-block fixed Huffman decoder rejects non-final blocks" {
    // This is the fixed-Huffman one-byte "a" vector with only BFINAL cleared.
    // The single-block fixed decoder must not silently accept a stream that
    // promises another block; multi-block callers should use decodeRawAutoAlloc.
    const non_final_fixed = [_]u8{ 0x4a, 0x04, 0x00 };
    var out: [8]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeRawFixed(&non_final_fixed, &out));
    try std.testing.expectError(error.TruncatedFrame, decodeRawFixedAllocStrict(std.testing.allocator, &non_final_fixed));
}

test "raw fixed Huffman inflate decodes back references and rejects wrong block types" {
    const cases = [_]struct { compressed: []const u8, plain: []const u8 }{
        .{ .compressed = &.{ 0x4b, 0x4c, 0x04, 0x01, 0x00 }, .plain = "aaaaaa" },
        .{ .compressed = &.{ 0x4b, 0x4c, 0x4a, 0x4e, 0x84, 0x21, 0x00 }, .plain = "abcabcabcabc" },
        .{ .compressed = &.{ 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x57, 0xc8, 0x40, 0x27, 0x01 }, .plain = "hello hello hello hello" },
        .{ .compressed = &.{ 0x4b, 0x4c, 0x1c, 0x05, 0xc4, 0x86, 0x00, 0x00 }, .plain = "a" ** 300 },
    };
    for (cases) |case| {
        const decoded = try decodeRawFixedAllocStrict(std.testing.allocator, case.compressed);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case.plain, decoded);
    }

    var out: [8]u8 = undefined;
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeRawFixed(&.{ 0x01, 0x00, 0x00, 0xff, 0xff }, &out));
    try std.testing.expectError(error.OutputTooSmall, decodeRawFixed(&.{ 0x4b, 0x04, 0x00 }, out[0..0]));
}

test "fixed Huffman decoder rejects reserved distance symbols" {
    const lit_lengths = huffman.fixedLiteralLengths();
    const dist_lengths = huffman.fixedDistanceLengths();
    const lit_encoder = try huffman.FixedLiteralTable.Encoder.init(&lit_lengths);
    const dist_encoder = try huffman.FixedDistanceTable.Encoder.init(&dist_lengths);

    var writer = bitstream.BitWriter{};
    defer writer.deinit(std.testing.allocator);
    try writer.writeBits(std.testing.allocator, 1, 1);
    try writer.writeBits(std.testing.allocator, 0b01, 2);
    try lit_encoder.writeSymbol(&writer, std.testing.allocator, 'a');
    try lit_encoder.writeSymbol(&writer, std.testing.allocator, 257);
    // Distance codes 30 and 31 are reserved by RFC 1951 even though the fixed
    // distance alphabet has 5-bit codes for all 32 bit patterns. Decoders must
    // reject the symbol before attempting match copy or footer validation.
    try dist_encoder.writeSymbol(&writer, std.testing.allocator, 30);
    try lit_encoder.writeSymbol(&writer, std.testing.allocator, 256);
    const encoded = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(encoded);

    var out: [16]u8 = undefined;
    try std.testing.expectError(error.InvalidHuffmanCode, decodeRawFixed(encoded, &out));
    try std.testing.expectError(error.InvalidHuffmanCode, decodeRawFixedAllocStrict(std.testing.allocator, encoded));
    try std.testing.expectError(error.InvalidHuffmanCode, decodeRawAutoAlloc(std.testing.allocator, encoded));

    var zlib_frame: std.ArrayList(u8) = .empty;
    defer zlib_frame.deinit(std.testing.allocator);
    try zlib_frame.appendSlice(std.testing.allocator, &.{ 0x78, 0x01 });
    try zlib_frame.appendSlice(std.testing.allocator, encoded);
    try zlib_frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0 });
    try std.testing.expectError(error.InvalidHuffmanCode, decodeZlibAlloc(std.testing.allocator, zlib_frame.items));

    var gzip_frame: std.ArrayList(u8) = .empty;
    defer gzip_frame.deinit(std.testing.allocator);
    try gzip_frame.appendSlice(std.testing.allocator, &gzip_header);
    try gzip_frame.appendSlice(std.testing.allocator, encoded);
    try gzip_frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0, 0, 0, 0, 0 });
    try std.testing.expectError(error.InvalidHuffmanCode, decodeGzipAlloc(std.testing.allocator, gzip_frame.items));
}

test "fixed Huffman decoder rejects reserved literal length symbols" {
    const lit_lengths = huffman.fixedLiteralLengths();
    const lit_encoder = try huffman.FixedLiteralTable.Encoder.init(&lit_lengths);

    var writer = bitstream.BitWriter{};
    defer writer.deinit(std.testing.allocator);
    try writer.writeBits(std.testing.allocator, 1, 1);
    try writer.writeBits(std.testing.allocator, 0b01, 2);
    // Literal/length symbols 286 and 287 are present in the fixed tree to fill
    // out canonical bit patterns, but RFC 1951 reserves them from compressed
    // data. They must be rejected consistently before wrapper footer checks.
    try lit_encoder.writeSymbol(&writer, std.testing.allocator, 286);
    const encoded = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(encoded);

    var out: [16]u8 = undefined;
    try std.testing.expectError(error.InvalidHuffmanCode, decodeRawFixed(encoded, &out));
    try std.testing.expectError(error.InvalidHuffmanCode, decodeRawFixedAllocStrict(std.testing.allocator, encoded));
    try std.testing.expectError(error.InvalidHuffmanCode, decodeRawAutoAlloc(std.testing.allocator, encoded));

    var zlib_frame: std.ArrayList(u8) = .empty;
    defer zlib_frame.deinit(std.testing.allocator);
    try zlib_frame.appendSlice(std.testing.allocator, &.{ 0x78, 0x01 });
    try zlib_frame.appendSlice(std.testing.allocator, encoded);
    try zlib_frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0 });
    try std.testing.expectError(error.InvalidHuffmanCode, decodeZlibAlloc(std.testing.allocator, zlib_frame.items));

    var gzip_frame: std.ArrayList(u8) = .empty;
    defer gzip_frame.deinit(std.testing.allocator);
    try gzip_frame.appendSlice(std.testing.allocator, &gzip_header);
    try gzip_frame.appendSlice(std.testing.allocator, encoded);
    try gzip_frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0, 0, 0, 0, 0 });
    try std.testing.expectError(error.InvalidHuffmanCode, decodeGzipAlloc(std.testing.allocator, gzip_frame.items));
}

test "zlib and gzip fixed Huffman wrappers decode zlib fixed vectors" {
    const zlib_cases = [_]struct { compressed: []const u8, plain: []const u8 }{
        .{ .compressed = &.{ 0x78, 0x01, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x06, 0x2c, 0x02, 0x15 }, .plain = "hello" },
        .{ .compressed = &.{ 0x78, 0x01, 0x4b, 0x4c, 0x04, 0x01, 0x00, 0x07, 0xfb, 0x02, 0x47 }, .plain = "aaaaaa" },
        .{ .compressed = &.{ 0x78, 0x01, 0x4b, 0x4c, 0x4a, 0x4e, 0x84, 0x21, 0x00, 0x1d, 0xe0, 0x04, 0x99 }, .plain = "abcabcabcabc" },
    };
    for (zlib_cases) |case| {
        const decoded = try decodeZlibAlloc(std.testing.allocator, case.compressed);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case.plain, decoded);
    }

    const gzip_cases = [_]struct { compressed: []const u8, plain: []const u8 }{
        .{ .compressed = &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x86, 0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00 }, .plain = "hello" },
        .{ .compressed = &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0x4b, 0x4c, 0x04, 0x01, 0x00, 0xf8, 0x19, 0xe4, 0x5a, 0x06, 0x00, 0x00, 0x00 }, .plain = "aaaaaa" },
        .{ .compressed = &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0x4b, 0x4c, 0x4a, 0x4e, 0x84, 0x21, 0x00, 0x34, 0x2a, 0x6e, 0x5a, 0x0c, 0x00, 0x00, 0x00 }, .plain = "abcabcabcabc" },
    };
    for (gzip_cases) |case| {
        const decoded = try decodeGzipAlloc(std.testing.allocator, case.compressed);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case.plain, decoded);
    }
}

test "auto raw decoder dispatches stored and fixed blocks" {
    const stored = try encodeRawStoredAlloc(std.testing.allocator, "stored");
    defer std.testing.allocator.free(stored);
    const stored_decoded = try decodeRawAutoAlloc(std.testing.allocator, stored);
    defer std.testing.allocator.free(stored_decoded);
    try std.testing.expectEqualSlices(u8, "stored", stored_decoded);

    const fixed = try decodeRawAutoAlloc(std.testing.allocator, &.{ 0x4b, 0x4c, 0x04, 0x01, 0x00 });
    defer std.testing.allocator.free(fixed);
    try std.testing.expectEqualSlices(u8, "aaaaaa", fixed);
}

test "auto raw decoder rejects truncated streams after non-final blocks" {
    const non_final_stored = [_]u8{ 0x00, 0x01, 0x00, 0xfe, 0xff, 'x' };
    try std.testing.expectError(error.TruncatedFrame, decodeRawAutoAlloc(std.testing.allocator, &non_final_stored));

    const non_final_fixed = [_]u8{ 0x4a, 0x04, 0x00 };
    try std.testing.expectError(error.TruncatedFrame, decodeRawAutoAlloc(std.testing.allocator, &non_final_fixed));

    const dynamic = try encodeRawDynamicLiteralAlloc(std.testing.allocator, "dynamic truncated tail");
    defer std.testing.allocator.free(dynamic);
    const non_final_dynamic = try std.testing.allocator.dupe(u8, dynamic);
    defer std.testing.allocator.free(non_final_dynamic);
    non_final_dynamic[0] &= 0xfe;
    try std.testing.expectError(error.TruncatedFrame, decodeRawAutoAlloc(std.testing.allocator, non_final_dynamic));
}

test "raw dynamic Huffman inflate decodes zlib dynamic vectors" {
    const compressed = &.{
        0x3d, 0xc6, 0x39, 0x11, 0x00, 0x00, 0x0c, 0x02,
        0x30, 0x2b, 0xb5, 0x52, 0x1e, 0xff, 0x96, 0x38,
        0x16, 0x96, 0x5c, 0x1e, 0x94, 0xcb, 0x6d, 0x01,
    };
    const plain = "ABCDEABCD ABCDEABCD";
    const decoded = try decodeRawDynamicAllocStrict(std.testing.allocator, compressed);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, plain, decoded);
    const auto_decoded = try decodeRawAutoAlloc(std.testing.allocator, compressed);
    defer std.testing.allocator.free(auto_decoded);
    try std.testing.expectEqualSlices(u8, plain, auto_decoded);
}

test "dynamic Huffman decoder rejects matches without distance codes" {
    var lit_lengths: [258]u4 = @splat(0);
    lit_lengths['a'] = 2;
    lit_lengths[256] = 2;
    lit_lengths[257] = 2;
    var code_len_lengths: [19]u4 = @splat(0);
    code_len_lengths[0] = 1;
    code_len_lengths[2] = 1;

    const code_len_encoder = try huffman.CodeLengthTable.Encoder.init(&code_len_lengths);
    const lit_encoder = try huffman.HuffmanTable(258).Encoder.init(&lit_lengths);

    var writer = bitstream.BitWriter{};
    defer writer.deinit(std.testing.allocator);
    try writer.writeBits(std.testing.allocator, 1, 1);
    try writer.writeBits(std.testing.allocator, 0b10, 2);
    try writer.writeBits(std.testing.allocator, 1, 5);
    try writer.writeBits(std.testing.allocator, 0, 5);
    try writer.writeBits(std.testing.allocator, 12, 4);
    for (huffman.code_length_order[0..16]) |symbol| {
        try writer.writeBits(std.testing.allocator, code_len_lengths[symbol], 3);
    }
    for (&lit_lengths) |len| try code_len_encoder.writeSymbol(&writer, std.testing.allocator, len);
    try code_len_encoder.writeSymbol(&writer, std.testing.allocator, 0);
    try lit_encoder.writeSymbol(&writer, std.testing.allocator, 'a');
    try lit_encoder.writeSymbol(&writer, std.testing.allocator, 257);
    // The malformed distance alphabet has no symbols. Provide enough padding
    // bits for the distance decoder to conclude InvalidHuffmanCode rather than
    // merely running out of input.
    try writer.writeBits(std.testing.allocator, 0, 15);
    const encoded = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(encoded);

    try std.testing.expectError(error.InvalidHuffmanCode, decodeRawDynamicAllocStrict(std.testing.allocator, encoded));
    try std.testing.expectError(error.InvalidHuffmanCode, decodeRawAutoAlloc(std.testing.allocator, encoded));

    var zlib_frame: std.ArrayList(u8) = .empty;
    defer zlib_frame.deinit(std.testing.allocator);
    try zlib_frame.appendSlice(std.testing.allocator, &.{ 0x78, 0x01 });
    try zlib_frame.appendSlice(std.testing.allocator, encoded);
    try zlib_frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0 });
    try std.testing.expectError(error.InvalidHuffmanCode, decodeZlibAlloc(std.testing.allocator, zlib_frame.items));

    var gzip_frame: std.ArrayList(u8) = .empty;
    defer gzip_frame.deinit(std.testing.allocator);
    try gzip_frame.appendSlice(std.testing.allocator, &gzip_header);
    try gzip_frame.appendSlice(std.testing.allocator, encoded);
    try gzip_frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0, 0, 0, 0, 0 });
    try std.testing.expectError(error.InvalidHuffmanCode, decodeGzipAlloc(std.testing.allocator, gzip_frame.items));
}

test "dynamic Huffman decoder rejects oversubscribed code-length alphabets" {
    var writer = bitstream.BitWriter{};
    defer writer.deinit(std.testing.allocator);
    try writer.writeBits(std.testing.allocator, 1, 1);
    try writer.writeBits(std.testing.allocator, 0b10, 2);
    try writer.writeBits(std.testing.allocator, 0, 5);
    try writer.writeBits(std.testing.allocator, 0, 5);
    try writer.writeBits(std.testing.allocator, 0, 4);
    try writer.writeBits(std.testing.allocator, 1, 3);
    try writer.writeBits(std.testing.allocator, 1, 3);
    try writer.writeBits(std.testing.allocator, 1, 3);
    try writer.writeBits(std.testing.allocator, 0, 3);
    const encoded = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(encoded);

    try std.testing.expectError(error.InvalidHuffmanCode, decodeRawDynamicAllocStrict(std.testing.allocator, encoded));
    try std.testing.expectError(error.InvalidHuffmanCode, decodeRawAutoAlloc(std.testing.allocator, encoded));

    var zlib_frame: std.ArrayList(u8) = .empty;
    defer zlib_frame.deinit(std.testing.allocator);
    try zlib_frame.appendSlice(std.testing.allocator, &.{ 0x78, 0x01 });
    try zlib_frame.appendSlice(std.testing.allocator, encoded);
    try zlib_frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0 });
    try std.testing.expectError(error.InvalidHuffmanCode, decodeZlibAlloc(std.testing.allocator, zlib_frame.items));

    var gzip_frame: std.ArrayList(u8) = .empty;
    defer gzip_frame.deinit(std.testing.allocator);
    try gzip_frame.appendSlice(std.testing.allocator, &gzip_header);
    try gzip_frame.appendSlice(std.testing.allocator, encoded);
    try gzip_frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0, 0, 0, 0, 0 });
    try std.testing.expectError(error.InvalidHuffmanCode, decodeGzipAlloc(std.testing.allocator, gzip_frame.items));
}

test "dynamic Huffman decoder rejects missing end-of-block codes" {
    var code_len_lengths: [19]u4 = @splat(0);
    code_len_lengths[0] = 1;
    code_len_lengths[1] = 1;
    const code_len_encoder = try huffman.CodeLengthTable.Encoder.init(&code_len_lengths);

    var writer = bitstream.BitWriter{};
    defer writer.deinit(std.testing.allocator);
    try writer.writeBits(std.testing.allocator, 1, 1);
    try writer.writeBits(std.testing.allocator, 0b10, 2);
    try writer.writeBits(std.testing.allocator, 0, 5);
    try writer.writeBits(std.testing.allocator, 0, 5);
    try writer.writeBits(std.testing.allocator, 14, 4);
    for (huffman.code_length_order[0..18]) |symbol| {
        try writer.writeBits(std.testing.allocator, code_len_lengths[symbol], 3);
    }
    for (0..257) |symbol| {
        try code_len_encoder.writeSymbol(&writer, std.testing.allocator, if (symbol == 'a') 1 else 0);
    }
    try code_len_encoder.writeSymbol(&writer, std.testing.allocator, 0);
    const encoded = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(encoded);

    try std.testing.expectError(error.InvalidDynamicBlockHeader, decodeRawDynamicAllocStrict(std.testing.allocator, encoded));
    try std.testing.expectError(error.InvalidDynamicBlockHeader, decodeRawAutoAlloc(std.testing.allocator, encoded));

    var zlib_frame: std.ArrayList(u8) = .empty;
    defer zlib_frame.deinit(std.testing.allocator);
    try zlib_frame.appendSlice(std.testing.allocator, &.{ 0x78, 0x01 });
    try zlib_frame.appendSlice(std.testing.allocator, encoded);
    try zlib_frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0 });
    try std.testing.expectError(error.InvalidDynamicBlockHeader, decodeZlibAlloc(std.testing.allocator, zlib_frame.items));

    var gzip_frame: std.ArrayList(u8) = .empty;
    defer gzip_frame.deinit(std.testing.allocator);
    try gzip_frame.appendSlice(std.testing.allocator, &gzip_header);
    try gzip_frame.appendSlice(std.testing.allocator, encoded);
    try gzip_frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0, 0, 0, 0, 0 });
    try std.testing.expectError(error.InvalidDynamicBlockHeader, decodeGzipAlloc(std.testing.allocator, gzip_frame.items));
}

test "zlib and gzip wrappers propagate malformed dynamic code-length repeats" {
    var lengths: [19]u4 = @splat(0);
    lengths[0] = 1;
    lengths[16] = 1;
    const encoder = try huffman.CodeLengthTable.Encoder.init(&lengths);

    var writer = bitstream.BitWriter{};
    defer writer.deinit(std.testing.allocator);
    try writer.writeBits(std.testing.allocator, 1, 1);
    try writer.writeBits(std.testing.allocator, 0b10, 2);
    try writer.writeBits(std.testing.allocator, 0, 5);
    try writer.writeBits(std.testing.allocator, 0, 5);
    try writer.writeBits(std.testing.allocator, 0, 4);
    try writer.writeBits(std.testing.allocator, 1, 3);
    try writer.writeBits(std.testing.allocator, 0, 3);
    try writer.writeBits(std.testing.allocator, 0, 3);
    try writer.writeBits(std.testing.allocator, 1, 3);
    try encoder.writeSymbol(&writer, std.testing.allocator, 16);
    const encoded = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(encoded);

    try std.testing.expectError(error.InvalidDynamicBlockHeader, decodeRawDynamicAllocStrict(std.testing.allocator, encoded));
    try std.testing.expectError(error.InvalidDynamicBlockHeader, decodeRawAutoAlloc(std.testing.allocator, encoded));

    var zlib_frame: std.ArrayList(u8) = .empty;
    defer zlib_frame.deinit(std.testing.allocator);
    try zlib_frame.appendSlice(std.testing.allocator, &.{ 0x78, 0x01 });
    try zlib_frame.appendSlice(std.testing.allocator, encoded);
    try zlib_frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0 });
    try std.testing.expectError(error.InvalidDynamicBlockHeader, decodeZlibAlloc(std.testing.allocator, zlib_frame.items));

    var gzip_frame: std.ArrayList(u8) = .empty;
    defer gzip_frame.deinit(std.testing.allocator);
    try gzip_frame.appendSlice(std.testing.allocator, &gzip_header);
    try gzip_frame.appendSlice(std.testing.allocator, encoded);
    try gzip_frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0, 0, 0, 0, 0 });
    try std.testing.expectError(error.InvalidDynamicBlockHeader, decodeGzipAlloc(std.testing.allocator, gzip_frame.items));
}

test "zlib and gzip dynamic Huffman wrappers decode dynamic vectors" {
    const zlib_frame = &.{
        0x78, 0x01,
        0x3d, 0xc6,
        0x39, 0x11,
        0x00, 0x00,
        0x0c, 0x02,
        0x30, 0x2b,
        0xb5, 0x52,
        0x1e, 0xff,
        0x96, 0x38,
        0x16, 0x96,
        0x5c, 0x1e,
        0x94, 0xcb,
        0x6d, 0x01,
        0x30, 0x33,
        0x04, 0xd3,
    };
    const gzip_frame = &.{
        0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
        0x3d, 0xc6, 0x39, 0x11, 0x00, 0x00, 0x0c, 0x02, 0x30, 0x2b,
        0xb5, 0x52, 0x1e, 0xff, 0x96, 0x38, 0x16, 0x96, 0x5c, 0x1e,
        0x94, 0xcb, 0x6d, 0x01, 0x17, 0x1c, 0x39, 0xb4, 0x13, 0x00,
        0x00, 0x00,
    };
    const plain = "ABCDEABCD ABCDEABCD";
    const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, plain, zlib_decoded);
    const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, plain, gzip_decoded);
}

test "raw zlib and gzip decoders handle multi-block streams" {
    const raw = &.{ 0x00, 0x02, 0x00, 0xfd, 0xff, 'h', 'i', 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 };
    const plain = "hihello";
    const raw_decoded = try decodeRawAutoAlloc(std.testing.allocator, raw);
    defer std.testing.allocator.free(raw_decoded);
    try std.testing.expectEqualSlices(u8, plain, raw_decoded);
    var raw_out: [plain.len]u8 = undefined;
    const raw_written = try decodeRawAuto(raw, &raw_out);
    try std.testing.expectEqual(raw.len, raw_written.input_read);
    try std.testing.expectEqual(plain.len, raw_written.output_written);
    try std.testing.expectEqualSlices(u8, plain, &raw_out);
    try std.testing.expectError(error.OutputTooSmall, decodeRawAuto(raw, raw_out[0 .. plain.len - 1]));

    const zlib_frame = &.{ 0x78, 0x01, 0x00, 0x02, 0x00, 0xfd, 0xff, 'h', 'i', 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x0b, 0x7c, 0x02, 0xe6 };
    const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, plain, zlib_decoded);
    var zlib_out: [plain.len]u8 = undefined;
    try std.testing.expectEqual(plain.len, try decodeZlib(zlib_frame, &zlib_out));
    try std.testing.expectEqualSlices(u8, plain, &zlib_out);
    try std.testing.expectError(error.OutputTooSmall, decodeZlib(zlib_frame, zlib_out[0 .. plain.len - 1]));

    const gzip_frame = &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x02, 0x00, 0xfd, 0xff, 'h', 'i', 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0xf5, 0xd2, 0xfc, 0xfa, 0x07, 0x00, 0x00, 0x00 };
    const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, plain, gzip_decoded);
    var gzip_out: [plain.len]u8 = undefined;
    try std.testing.expectEqual(plain.len, try decodeGzip(gzip_frame, &gzip_out));
    try std.testing.expectEqualSlices(u8, plain, &gzip_out);
    try std.testing.expectError(error.OutputTooSmall, decodeGzip(gzip_frame, gzip_out[0 .. plain.len - 1]));
}

test "zlib and gzip wrappers reject truncated non-final raw deflate streams" {
    const non_final_stored = [_]u8{ 0x00, 0x01, 0x00, 0xfe, 0xff, 'x' };
    const non_final_fixed = [_]u8{ 0x4a, 0x04, 0x00 };
    const dynamic = try encodeRawDynamicLiteralAlloc(std.testing.allocator, "wrapped dynamic truncated tail");
    defer std.testing.allocator.free(dynamic);
    const non_final_dynamic = try std.testing.allocator.dupe(u8, dynamic);
    defer std.testing.allocator.free(non_final_dynamic);
    non_final_dynamic[0] &= 0xfe;

    const raws = [_][]const u8{ &non_final_stored, &non_final_fixed, non_final_dynamic };
    for (raws) |raw| {
        var zlib_frame: std.ArrayList(u8) = .empty;
        defer zlib_frame.deinit(std.testing.allocator);
        try zlib_frame.appendSlice(std.testing.allocator, &.{ 0x78, 0x01 });
        try zlib_frame.appendSlice(std.testing.allocator, raw);
        try std.testing.expectError(error.TruncatedFrame, decodeZlibAlloc(std.testing.allocator, zlib_frame.items));

        var gzip_frame: std.ArrayList(u8) = .empty;
        defer gzip_frame.deinit(std.testing.allocator);
        try gzip_frame.appendSlice(std.testing.allocator, &gzip_header);
        try gzip_frame.appendSlice(std.testing.allocator, raw);
        try std.testing.expectError(error.TruncatedFrame, decodeGzipAlloc(std.testing.allocator, gzip_frame.items));
    }
}

test "gzip decoder accepts optional extra name comment and header crc fields" {
    const with_options = &.{
        0x1f, 0x8b, 0x08, 0x1e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
        0x04, 0x00, 'a',  'b',  'c',  'd',  'n',  'a',  'm',  'e',
        0x00, 'c',  'o',  'm',  'm',  'e',  'n',  't',  0x00, 0xe2,
        0x48, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x86, 0xa6,
        0x10, 0x36, 0x05, 0x00, 0x00, 0x00,
    };
    const decoded = try decodeGzipAlloc(std.testing.allocator, with_options);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello", decoded);
}

test "gzip decoder rejects truncated optional headers" {
    try std.testing.expectError(error.TruncatedFrame, decodeGzipAlloc(std.testing.allocator, &.{ 0x1f, 0x8b, 0x08, 0x04, 0, 0, 0, 0, 0, 3, 4, 0, 'a' }));
    try std.testing.expectError(error.TruncatedFrame, decodeGzipAlloc(std.testing.allocator, &.{ 0x1f, 0x8b, 0x08, 0x08, 0, 0, 0, 0, 0, 3, 'n', 'o' }));
}

test "wrapper footer validators report exact boundary errors" {
    const zlib_footer = [_]u8{ 0x00, 0x00, 0x00, 0x01 };
    try validateZlibFooter(&zlib_footer, 0, 1);
    try std.testing.expectError(error.TruncatedFrame, validateZlibFooter(&zlib_footer, 5, 1));
    try std.testing.expectError(error.TruncatedFrame, validateZlibFooter(zlib_footer[0..3], 0, 1));
    try std.testing.expectError(error.ChecksumMismatch, validateZlibFooter(&zlib_footer, 0, 2));
    try std.testing.expectError(error.TrailingData, validateZlibFooter(&.{ 0x00, 0x00, 0x00, 0x01, 0xff }, 0, 1));

    const gzip_footer = [_]u8{ 0x86, 0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00 };
    try validateGzipFooter(&gzip_footer, 0, 0x3610_a686, 5);
    try validateGzipFooterPartial(&(gzip_footer ++ .{0xff}), 0, 0x3610_a686, 5);
    try std.testing.expectError(error.TruncatedFrame, validateGzipFooter(&gzip_footer, 9, 0x3610_a686, 5));
    try std.testing.expectError(error.TruncatedFrame, validateGzipFooter(gzip_footer[0..7], 0, 0x3610_a686, 5));
    try std.testing.expectError(error.ChecksumMismatch, validateGzipFooter(&gzip_footer, 0, 0, 5));
    try std.testing.expectError(error.SizeMismatch, validateGzipFooter(&gzip_footer, 0, 0x3610_a686, 4));
    try std.testing.expectError(error.TrailingData, validateGzipFooter(&(gzip_footer ++ .{0xff}), 0, 0x3610_a686, 5));
}

test "raw fixed Huffman encoder round trips through decoder" {
    const cases = [_][]const u8{
        "",
        "hello",
        "abcabcabcabc",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    for (cases) |case| {
        const encoded = try encodeRawFixedAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(encoded);
        const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case, decoded);
    }
}

test "raw fixed Huffman encoder emits zlib-compatible hello vector" {
    const encoded = try encodeRawFixedAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &.{ 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 }, encoded);
}

test "zlib and gzip fixed encoders round trip through wrappers" {
    const cases = [_][]const u8{ "hello", "abcabcabcabc", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    for (cases) |case| {
        const zlib_frame = try encodeZlibFixedAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(zlib_frame);
        const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
        defer std.testing.allocator.free(zlib_decoded);
        try std.testing.expectEqualSlices(u8, case, zlib_decoded);

        const gzip_frame = try encodeGzipFixedAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(gzip_frame);
        const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
        defer std.testing.allocator.free(gzip_decoded);
        try std.testing.expectEqualSlices(u8, case, gzip_decoded);
    }
}

test "zlib and gzip fixed encoders emit known hello frames" {
    const zlib_frame = try encodeZlibFixedAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(zlib_frame);
    try std.testing.expectEqualSlices(u8, &.{ 0x78, 0x01, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x06, 0x2c, 0x02, 0x15 }, zlib_frame);

    const gzip_frame = try encodeGzipFixedAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(gzip_frame);
    try std.testing.expectEqualSlices(u8, &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x86, 0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00 }, gzip_frame);
}

test "zlib and gzip wrappers decode multi-block stream ending in dynamic block" {
    const plain = "hiABCDEABCD ABCDEABCD";
    const zlib_frame = &.{
        0x78, 0x01,
        0x00, 0x02,
        0x00, 0xfd,
        0xff, 'h',
        'i',  0x3d,
        0xc6, 0x39,
        0x11, 0x00,
        0x00, 0x0c,
        0x02, 0x30,
        0x2b, 0xb5,
        0x52, 0x1e,
        0xff, 0x96,
        0x38, 0x16,
        0x96, 0x5c,
        0x1e, 0x94,
        0xcb, 0x6d,
        0x01, 0x40,
        0xf1, 0x05,
        0xa4,
    };
    const gzip_frame = &.{
        0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
        0x00, 0x02, 0x00, 0xfd, 0xff, 'h',  'i',  0x3d, 0xc6, 0x39,
        0x11, 0x00, 0x00, 0x0c, 0x02, 0x30, 0x2b, 0xb5, 0x52, 0x1e,
        0xff, 0x96, 0x38, 0x16, 0x96, 0x5c, 0x1e, 0x94, 0xcb, 0x6d,
        0x01, 0x45, 0x6c, 0x56, 0xbe, 0x15, 0x00, 0x00, 0x00,
    };
    const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, plain, zlib_decoded);
    const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, plain, gzip_decoded);
}

test "gzip FHCRC is validated when present" {
    const valid = &.{
        0x1f, 0x8b, 0x08, 0x02, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03,
        0xa3, 0xb2, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x86,
        0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00,
    };
    const decoded = try decodeGzipAlloc(std.testing.allocator, valid);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello", decoded);

    var invalid: [valid.len]u8 = valid.*;
    invalid[10] ^= 1;
    try std.testing.expectError(error.BadGzipHeader, decodeGzipAlloc(std.testing.allocator, &invalid));
}

test "zlib header rejects bad method window check and dictionary flag" {
    var out: [32]u8 = undefined;
    try std.testing.expectError(error.BadZlibHeader, decodeZlibStored(&.{ 0x77, 0x85, 0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x01 }, &out));
    try std.testing.expectError(error.BadZlibHeader, decodeZlibStored(&.{ 0x88, 0x98, 0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x01 }, &out));
    // FDICT is a valid zlib header bit, but Vort does not yet accept caller
    // supplied preset dictionaries for zlib streams. Surface that as a distinct
    // capability error rather than conflating it with malformed FCHECK/CMF.
    try std.testing.expectError(error.NeedDictionary, decodeZlibStored(&.{ 0x78, 0x20, 0x00, 0x00, 0x00, 0x00 }, &out));
    try std.testing.expectError(error.NeedDictionary, decodeZlibAlloc(std.testing.allocator, &.{ 0x78, 0x20, 0x00, 0x00, 0x00, 0x00 }));
}

test "zlib preset dictionary streams decode with caller dictionary" {
    const frame = &.{
        0x78, 0xf9, 0x08, 0x61, 0x02, 0x35, 0xcb,
        0x40, 0x27, 0x01, 0x3a, 0x2e, 0x06, 0x7d,
    };
    try std.testing.expectError(error.NeedDictionary, decodeZlibAlloc(std.testing.allocator, frame));
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibAllocWithDictionary(std.testing.allocator, frame, "wrong dictionary"));

    const decoded = try decodeZlibAllocWithDictionary(std.testing.allocator, frame, "hello ");
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello hello hello", decoded);
    var out: ["hello hello hello".len]u8 = undefined;
    try std.testing.expectEqual(out.len, try decodeZlibWithDictionary(frame, &out, "hello "));
    try std.testing.expectEqualSlices(u8, "hello hello hello", &out);
}

test "zlib preset dictionary streams cover stored and dynamic blocks" {
    const stored_frame = &.{
        0x78, 0x3f, 0x08, 0x61, 0x02, 0x35, 0x01,
        0x11, 0x00, 0xee, 0xff, 'h',  'e',  'l',
        'l',  'o',  ' ',  'h',  'e',  'l',  'l',
        'o',  ' ',  'h',  'e',  'l',  'l',  'o',
        0x3a, 0x2e, 0x06, 0x7d,
    };
    const stored = try decodeZlibAllocWithDictionary(std.testing.allocator, stored_frame, "hello ");
    defer std.testing.allocator.free(stored);
    try std.testing.expectEqualSlices(u8, "hello hello hello", stored);
    try std.testing.expectError(error.NeedDictionary, decodeZlibStoredAlloc(std.testing.allocator, stored_frame));
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibStoredAllocWithDictionary(std.testing.allocator, stored_frame, "wrong dictionary"));
    const stored_specific = try decodeZlibStoredAllocWithDictionary(std.testing.allocator, stored_frame, "hello ");
    defer std.testing.allocator.free(stored_specific);
    try std.testing.expectEqualSlices(u8, "hello hello hello", stored_specific);
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibStoredAllocWithDictionaryLimited(std.testing.allocator, stored_frame, "hello ", 16));
    const stored_limited = try decodeZlibStoredAllocWithDictionaryLimited(std.testing.allocator, stored_frame, "hello ", 17);
    defer std.testing.allocator.free(stored_limited);
    try std.testing.expectEqualSlices(u8, "hello hello hello", stored_limited);

    const dynamic_frame = &.{
        0x78, 0x20, 0x08, 0x61, 0x02, 0x35, 0x25,
        0xc4, 0x21, 0x01, 0x00, 0x00, 0x00, 0x00,
        0x90, 0xff, 0xaf, 0x05, 0x82, 0x03, 0x08,
        0x61, 0x02, 0x35,
    };
    const dynamic = try decodeZlibAllocWithDictionary(std.testing.allocator, dynamic_frame, "hello ");
    defer std.testing.allocator.free(dynamic);
    try std.testing.expectEqualSlices(u8, "hello ", dynamic);
}

test "zlib preset dictionary encoders set FDICT and DICTID" {
    const dictionary = "hello ";
    const input = "hello hello hello";

    const stored = try encodeZlibStoredWithDictionaryAlloc(std.testing.allocator, input, dictionary);
    defer std.testing.allocator.free(stored);
    const fixed = try encodeZlibFixedWithDictionaryAlloc(std.testing.allocator, input, dictionary, optionsForLevel(.fast));
    defer std.testing.allocator.free(fixed);
    const dynamic = try encodeZlibDynamicWithDictionaryAlloc(std.testing.allocator, input, dictionary, optionsForLevel(.default));
    defer std.testing.allocator.free(dynamic);
    const best = try encodeZlibBestWithDictionaryAlloc(std.testing.allocator, input, dictionary, optionsForLevel(.default));
    defer std.testing.allocator.free(best);
    const split = try encodeZlibBestSplitWithDictionaryAlloc(std.testing.allocator, input, dictionary, 7, optionsForLevel(.default));
    defer std.testing.allocator.free(split);
    const adaptive = try encodeZlibBestAdaptiveSplitWithDictionaryAlloc(std.testing.allocator, input, dictionary, optionsForLevel(.default), .{ .min_block_len = 8, .max_block_len = 16, .sample_len = 8, .search_step = 8 });
    defer std.testing.allocator.free(adaptive);

    for ([_][]const u8{ stored, fixed, dynamic, best, split, adaptive }) |frame| {
        try std.testing.expectEqual(@as(u8, 0x78), frame[0]);
        try std.testing.expect(frame[1] & 0x20 != 0);
        try std.testing.expectEqual(@as(usize, 0), (@as(usize, frame[0]) * 256 + frame[1]) % 31);
        try std.testing.expectEqual(checksum.adler32(dictionary), std.mem.readInt(u32, frame[2..6], .big));
        try std.testing.expectError(error.NeedDictionary, decodeZlibAlloc(std.testing.allocator, frame));
        try std.testing.expectError(error.ChecksumMismatch, decodeZlibAllocWithDictionary(std.testing.allocator, frame, "wrong dictionary"));
        const decoded = try decodeZlibAllocWithDictionary(std.testing.allocator, frame, dictionary);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "raw preset dictionary encoders can reference preset history" {
    const dictionary = "hello ";
    const input = "hello hello hello";

    const fixed = try encodeRawFixedWithDictionaryAlloc(std.testing.allocator, input, dictionary, optionsForLevel(.fast));
    defer std.testing.allocator.free(fixed);
    const dynamic = try encodeRawDynamicWithDictionaryAlloc(std.testing.allocator, input, dictionary, optionsForLevel(.default));
    defer std.testing.allocator.free(dynamic);
    const best = try encodeRawBestWithDictionaryAlloc(std.testing.allocator, input, dictionary, optionsForLevel(.default));
    defer std.testing.allocator.free(best);

    for ([_][]const u8{ fixed, dynamic, best }) |raw| {
        const decoded = try decodeRawAutoAllocWithDictionary(std.testing.allocator, raw, dictionary);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        // These inputs begin with the preset phrase, so the dictionary-aware
        // planners should produce a back-reference into the preset history.
        try std.testing.expectError(error.InvalidMatch, decodeRawAutoAlloc(std.testing.allocator, raw));
    }
}

test "raw zlib gzip exact-size alloc decoders enforce declared output length" {
    const input = "exact size decode payload";
    const raw = try encodeRawDynamicWithOptionsAlloc(std.testing.allocator, input, optionsForLevel(.default));
    defer std.testing.allocator.free(raw);
    const raw_exact = try decodeRawAutoAllocExactSize(std.testing.allocator, raw, input.len);
    defer std.testing.allocator.free(raw_exact);
    try std.testing.expectEqualSlices(u8, input, raw_exact);
    try std.testing.expectError(error.SizeMismatch, decodeRawAutoAllocExactSize(std.testing.allocator, raw, input.len - 1));
    try std.testing.expectError(error.SizeMismatch, decodeRawAutoAllocExactSize(std.testing.allocator, raw, input.len + 1));

    const zlib_frame = try encodeZlibDynamicWithOptionsAlloc(std.testing.allocator, input, optionsForLevel(.default));
    defer std.testing.allocator.free(zlib_frame);
    const zlib_exact = try decodeZlibAllocExactSize(std.testing.allocator, zlib_frame, input.len);
    defer std.testing.allocator.free(zlib_exact);
    try std.testing.expectEqualSlices(u8, input, zlib_exact);
    try std.testing.expectError(error.SizeMismatch, decodeZlibAllocExactSize(std.testing.allocator, zlib_frame, input.len - 1));
    try std.testing.expectError(error.SizeMismatch, decodeZlibAllocExactSize(std.testing.allocator, zlib_frame, input.len + 1));

    const gzip_frame = try encodeGzipDynamicWithOptionsAlloc(std.testing.allocator, input, optionsForLevel(.default));
    defer std.testing.allocator.free(gzip_frame);
    const gzip_exact = try decodeGzipAllocExactSize(std.testing.allocator, gzip_frame, input.len);
    defer std.testing.allocator.free(gzip_exact);
    try std.testing.expectEqualSlices(u8, input, gzip_exact);
    try std.testing.expectError(error.SizeMismatch, decodeGzipAllocExactSize(std.testing.allocator, gzip_frame, input.len - 1));
    try std.testing.expectError(error.SizeMismatch, decodeGzipAllocExactSize(std.testing.allocator, gzip_frame, input.len + 1));
}

test "dictionary exact-size alloc decoders enforce declared output length" {
    const dictionary = "hello ";
    const input = "hello hello hello";
    const raw = try encodeRawBestWithDictionaryAlloc(std.testing.allocator, input, dictionary, optionsForLevel(.default));
    defer std.testing.allocator.free(raw);
    const raw_exact = try decodeRawAutoAllocWithDictionaryExactSize(std.testing.allocator, raw, dictionary, input.len);
    defer std.testing.allocator.free(raw_exact);
    try std.testing.expectEqualSlices(u8, input, raw_exact);
    try std.testing.expectError(error.SizeMismatch, decodeRawAutoAllocWithDictionaryExactSize(std.testing.allocator, raw, dictionary, input.len - 1));

    const zlib_frame = try encodeZlibBestWithDictionaryAlloc(std.testing.allocator, input, dictionary, optionsForLevel(.default));
    defer std.testing.allocator.free(zlib_frame);
    const zlib_exact = try decodeZlibAllocWithDictionaryExactSize(std.testing.allocator, zlib_frame, dictionary, input.len);
    defer std.testing.allocator.free(zlib_exact);
    try std.testing.expectEqualSlices(u8, input, zlib_exact);
    try std.testing.expectError(error.SizeMismatch, decodeZlibAllocWithDictionaryExactSize(std.testing.allocator, zlib_frame, dictionary, input.len - 1));
}

test "raw deflate preset dictionary streams decode fixed and dynamic blocks" {
    const fixed_decoded = try decodeRawAutoAllocWithDictionary(std.testing.allocator, &.{ 0xcb, 0x40, 0x27, 0x01 }, "hello ");
    defer std.testing.allocator.free(fixed_decoded);
    try std.testing.expectEqualSlices(u8, "hello hello hello", fixed_decoded);
    try std.testing.expectError(error.InvalidMatch, decodeRawAutoAlloc(std.testing.allocator, &.{ 0xcb, 0x40, 0x27, 0x01 }));

    const dynamic_decoded = try decodeRawAutoAllocWithDictionary(std.testing.allocator, &.{ 0x25, 0xc4, 0x21, 0x01, 0x00, 0x00, 0x00, 0x00, 0x90, 0xff, 0xaf, 0x05, 0x82, 0x03 }, "hello ");
    defer std.testing.allocator.free(dynamic_decoded);
    try std.testing.expectEqualSlices(u8, "hello ", dynamic_decoded);
    try std.testing.expectError(error.InvalidMatch, decodeRawAutoAlloc(std.testing.allocator, &.{ 0x25, 0xc4, 0x21, 0x01, 0x00, 0x00, 0x00, 0x00, 0x90, 0xff, 0xaf, 0x05, 0x82, 0x03 }));

    var fixed_out: ["hello hello hello".len]u8 = undefined;
    const fixed_into = try decodeRawAutoWithDictionary(&.{ 0xcb, 0x40, 0x27, 0x01 }, "hello ", &fixed_out);
    try std.testing.expectEqual(fixed_out.len, fixed_into.output_written);
    try std.testing.expectEqualSlices(u8, "hello hello hello", &fixed_out);

    var dynamic_out: ["hello ".len]u8 = undefined;
    const dynamic_into = try decodeRawAutoWithDictionary(&.{ 0x25, 0xc4, 0x21, 0x01, 0x00, 0x00, 0x00, 0x00, 0x90, 0xff, 0xaf, 0x05, 0x82, 0x03 }, "hello ", &dynamic_out);
    try std.testing.expectEqual(dynamic_out.len, dynamic_into.output_written);
    try std.testing.expectEqualSlices(u8, "hello ", &dynamic_out);
}

test "one-shot deflate wrappers enforce output limits" {
    const raw = try encodeRawFixedAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(raw);
    try std.testing.expectError(error.OutputLimitExceeded, decodeRawAutoAllocLimited(std.testing.allocator, raw, 4));
    const raw_ok = try decodeRawAutoAllocLimited(std.testing.allocator, raw, 5);
    defer std.testing.allocator.free(raw_ok);
    try std.testing.expectEqualSlices(u8, "hello", raw_ok);

    const zlib_frame = try encodeZlibFixedAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(zlib_frame);
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibAllocLimited(std.testing.allocator, zlib_frame, 4));
    const zlib_ok = try decodeZlibAllocLimited(std.testing.allocator, zlib_frame, 5);
    defer std.testing.allocator.free(zlib_ok);
    try std.testing.expectEqualSlices(u8, "hello", zlib_ok);

    const gzip_frame = try encodeGzipFixedAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(gzip_frame);
    try std.testing.expectError(error.OutputLimitExceeded, decodeGzipAllocLimited(std.testing.allocator, gzip_frame, 4));
    const gzip_ok = try decodeGzipAllocLimited(std.testing.allocator, gzip_frame, 5);
    defer std.testing.allocator.free(gzip_ok);
    try std.testing.expectEqualSlices(u8, "hello", gzip_ok);

    try std.testing.expectError(error.OutputLimitExceeded, decodeRawAutoAllocWithDictionaryLimited(std.testing.allocator, &.{ 0xcb, 0x40, 0x27, 0x01 }, "hello ", 16));
    const dict_ok = try decodeZlibAllocWithDictionaryLimited(std.testing.allocator, &.{
        0x78, 0xf9, 0x08, 0x61, 0x02, 0x35, 0xcb,
        0x40, 0x27, 0x01, 0x3a, 0x2e, 0x06, 0x7d,
    }, "hello ", 17);
    defer std.testing.allocator.free(dict_ok);
    try std.testing.expectEqualSlices(u8, "hello hello hello", dict_ok);
}

test "gzip header rejects reserved flags and bad method" {
    try std.testing.expectError(error.BadGzipHeader, decodeGzipAlloc(std.testing.allocator, &.{ 0x1f, 0x8b, 0x08, 0xe0, 0, 0, 0, 0, 0, 3 }));
    try std.testing.expectError(error.BadGzipHeader, decodeGzipAlloc(std.testing.allocator, &.{ 0x1f, 0x8b, 0x00, 0x00, 0, 0, 0, 0, 0, 3 }));
}

test "compression strategy normalization adjusts parser knobs" {
    var options = optionsForLevel(.best);
    options.strategy = .filtered;
    const filtered = normalizeOptionsForStrategy(options);
    try std.testing.expect(filtered.lz77_options.min_match >= 5);
    try std.testing.expect(filtered.lz77_options.min_savings_bits >= 8);
    try std.testing.expect(filtered.lz77_options.max_candidates <= 2);

    options.strategy = .rle;
    const rle = normalizeOptionsForStrategy(options);
    try std.testing.expectEqual(@as(usize, 1), rle.lz77_options.window_len);
    try std.testing.expectEqual(@as(usize, 1), rle.lz77_options.max_candidates);

    options.strategy = .huffman_only;
    const huffman_only = normalizeOptionsForStrategy(options);
    try std.testing.expectEqual(@as(usize, 0), huffman_only.lz77_options.max_chain);
}

test "fixed encoder supports compression strategies" {
    const input = "aaaaaaaaaaaaaaaa" ++ "abcabcabc";
    inline for (.{ CompressionStrategy.default, CompressionStrategy.filtered, CompressionStrategy.huffman_only, CompressionStrategy.rle }) |strategy| {
        const encoded = try encodeRawBestAlloc(std.testing.allocator, input, .{ .strategy = strategy });
        defer std.testing.allocator.free(encoded);
        const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }

    const filtered_plan = try planTokensAlloc(std.testing.allocator, input, .{ .strategy = .filtered });
    defer filtered_plan.deinit(std.testing.allocator);
    const default_plan = try planTokensAlloc(std.testing.allocator, input, .{});
    defer default_plan.deinit(std.testing.allocator);
    try std.testing.expect(filtered_plan.stats.matches <= default_plan.stats.matches);

    const huffman_plan = try planTokensAlloc(std.testing.allocator, input, .{ .strategy = .huffman_only });
    defer huffman_plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), huffman_plan.stats.matches);

    const rle_plan = try planTokensAlloc(std.testing.allocator, input, .{ .strategy = .rle });
    defer rle_plan.deinit(std.testing.allocator);
    try std.testing.expect(rle_plan.stats.matches > 0);
    for (rle_plan.tokens) |token| switch (token) {
        .match => |m| try std.testing.expectEqual(@as(u16, 1), m.distance),
        else => {},
    };
}

test "fixed encoder supports parser strategy options" {
    const input = "abcabcabcabc xyz xyz xyz";
    inline for (.{ ParserMode.greedy, ParserMode.lazy, ParserMode.optimal }) |mode| {
        const encoded = try encodeRawFixedWithOptionsAlloc(std.testing.allocator, input, .{ .parser = mode });
        defer std.testing.allocator.free(encoded);
        const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "dynamic literal encoder round trips through raw zlib and gzip decoders" {
    const cases = [_][]const u8{ "", "hello", "dynamic literal encoder" };
    for (cases) |case| {
        const raw = try encodeRawDynamicLiteralAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(raw);
        const raw_decoded = try decodeRawAutoAlloc(std.testing.allocator, raw);
        defer std.testing.allocator.free(raw_decoded);
        try std.testing.expectEqualSlices(u8, case, raw_decoded);

        const zlib_frame = try encodeZlibDynamicLiteralAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(zlib_frame);
        const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
        defer std.testing.allocator.free(zlib_decoded);
        try std.testing.expectEqualSlices(u8, case, zlib_decoded);

        const gzip_frame = try encodeGzipDynamicLiteralAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(gzip_frame);
        const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
        defer std.testing.allocator.free(gzip_decoded);
        try std.testing.expectEqualSlices(u8, case, gzip_decoded);
    }
}

test "zlib and gzip dynamic literal wrappers preserve literal-only raw stream" {
    const input = "abcabcabcabc abcabcabcabc";
    const raw = try encodeRawDynamicLiteralAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(raw);

    const zlib_frame = try encodeZlibDynamicLiteralAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(zlib_frame);
    try std.testing.expectEqualSlices(u8, raw, zlib_frame[2 .. zlib_frame.len - 4]);

    const gzip_frame = try encodeGzipDynamicLiteralAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(gzip_frame);
    try std.testing.expectEqualSlices(u8, raw, gzip_frame[gzip_header.len .. gzip_frame.len - 8]);
}

test "single-block dynamic Huffman decoder rejects non-final blocks" {
    const raw = try encodeRawDynamicLiteralAlloc(std.testing.allocator, "dynamic non-final smoke");
    defer std.testing.allocator.free(raw);
    const non_final = try std.testing.allocator.dupe(u8, raw);
    defer std.testing.allocator.free(non_final);
    non_final[0] &= 0xfe;
    try std.testing.expectError(error.TruncatedFrame, decodeRawDynamicAllocStrict(std.testing.allocator, non_final));
}

test "dynamic code length RLE emits repeat symbols" {
    const lit_lengths = [_]u4{0} ** 20 ++ [_]u4{5} ** 7;
    const dist_lengths = [_]u4{5} ** 4;
    const ops = try buildCodeLengthOps(&lit_lengths, &dist_lengths);
    var saw_zero_repeat = false;
    var saw_prev_repeat = false;
    for (ops.slice()) |op| {
        if (op.symbol == 18 or op.symbol == 17) saw_zero_repeat = true;
        if (op.symbol == 16) saw_prev_repeat = true;
    }
    try std.testing.expect(saw_zero_repeat);
    try std.testing.expect(saw_prev_repeat);
}

test "best encoder selects a valid smallest raw block" {
    const cases = [_][]const u8{ "", "hello", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "abcabcabcabc" };
    for (cases) |case| {
        const best = try encodeRawBestAlloc(std.testing.allocator, case, .{});
        defer std.testing.allocator.free(best);
        const stored = try encodeRawStoredAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(stored);
        const fixed = try encodeRawFixedAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(fixed);
        const dynamic = try encodeRawDynamicWithOptionsAlloc(std.testing.allocator, case, .{});
        defer std.testing.allocator.free(dynamic);
        try std.testing.expect(best.len <= stored.len);
        try std.testing.expect(best.len <= fixed.len);
        try std.testing.expect(best.len <= dynamic.len);
        const decoded = try decodeRawAutoAlloc(std.testing.allocator, best);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case, decoded);
    }
}

test "best encoder skips invalid single stored block for large inputs" {
    var input: [64 * 1024]u8 = undefined;
    var state: u32 = 0x1234abcd;
    for (&input) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }

    const encoded = try encodeRawBestAlloc(std.testing.allocator, &input, optionsForLevel(.fastest));
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(usesStoredFastPath(&input, optionsForLevel(.fastest)));
    try std.testing.expect(usesStoredFastPath(&input, optionsForLevel(.default)));
    try std.testing.expect(!usesStoredFastPath(&input, optionsForLevel(.best)));
    const stored = try encodeRawStoredAlloc(std.testing.allocator, &input);
    defer std.testing.allocator.free(stored);
    try std.testing.expectEqual(stored.len, encoded.len);
    const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);

    const zlib_best = try encodeZlibBestAlloc(std.testing.allocator, &input, optionsForLevel(.fastest));
    defer std.testing.allocator.free(zlib_best);
    const zlib_stored = try encodeZlibStoredAlloc(std.testing.allocator, &input);
    defer std.testing.allocator.free(zlib_stored);
    try std.testing.expectEqual(zlib_stored.len, zlib_best.len);
    const zlib_split = try encodeZlibBestSplitAlloc(std.testing.allocator, &input, 16 * 1024, optionsForLevel(.fastest));
    defer std.testing.allocator.free(zlib_split);
    try std.testing.expectEqual(@as(usize, 2 + (input.len + 5 * 4) + 4), zlib_split.len);
    const zlib_adaptive = try encodeZlibBestAdaptiveSplitAlloc(std.testing.allocator, &input, optionsForLevel(.fastest), optionsForLevel(.fastest).split_options);
    defer std.testing.allocator.free(zlib_adaptive);
    try std.testing.expectEqual(zlib_stored.len, zlib_adaptive.len);

    const gzip_best = try encodeGzipBestAlloc(std.testing.allocator, &input, optionsForLevel(.fastest));
    defer std.testing.allocator.free(gzip_best);
    const gzip_stored = try encodeGzipStoredAlloc(std.testing.allocator, &input);
    defer std.testing.allocator.free(gzip_stored);
    try std.testing.expectEqual(gzip_stored.len, gzip_best.len);
    const gzip_split = try encodeGzipBestSplitAlloc(std.testing.allocator, &input, 16 * 1024, optionsForLevel(.fastest));
    defer std.testing.allocator.free(gzip_split);
    try std.testing.expectEqual(@as(usize, gzip_header.len + (input.len + 5 * 4) + 8), gzip_split.len);
    const gzip_adaptive = try encodeGzipBestAdaptiveSplitAlloc(std.testing.allocator, &input, optionsForLevel(.fastest), optionsForLevel(.fastest).split_options);
    defer std.testing.allocator.free(gzip_adaptive);
    try std.testing.expectEqual(gzip_stored.len, gzip_adaptive.len);

    const dictionary = "preset dictionary that should not matter for high entropy";
    const raw_dict = try encodeRawBestWithDictionaryAlloc(std.testing.allocator, &input, dictionary, optionsForLevel(.fastest));
    defer std.testing.allocator.free(raw_dict);
    try std.testing.expectEqual(stored.len, raw_dict.len);

    const split = try encodeRawBestSplitAlloc(std.testing.allocator, &input, 16 * 1024, optionsForLevel(.fastest));
    defer std.testing.allocator.free(split);
    try std.testing.expectEqual(@as(usize, input.len + 5 * 4), split.len);

    const adaptive = try encodeRawBestAdaptiveSplitAlloc(std.testing.allocator, &input, optionsForLevel(.fastest), optionsForLevel(.fastest).split_options);
    defer std.testing.allocator.free(adaptive);
    try std.testing.expectEqual(stored.len, adaptive.len);

    const default_encoded = try encodeRawBestAlloc(std.testing.allocator, &input, optionsForLevel(.default));
    defer std.testing.allocator.free(default_encoded);
    try std.testing.expectEqual(stored.len, default_encoded.len);

    const zlib_dict = try encodeZlibBestWithDictionaryAlloc(std.testing.allocator, &input, dictionary, optionsForLevel(.fastest));
    defer std.testing.allocator.free(zlib_dict);
    const zlib_stored_dict = try encodeZlibStoredWithDictionaryAlloc(std.testing.allocator, &input, dictionary);
    defer std.testing.allocator.free(zlib_stored_dict);
    try std.testing.expectEqual(zlib_stored_dict.len, zlib_dict.len);
    const zlib_dict_split = try encodeZlibBestSplitWithDictionaryAlloc(std.testing.allocator, &input, dictionary, 16 * 1024, optionsForLevel(.fastest));
    defer std.testing.allocator.free(zlib_dict_split);
    try std.testing.expectEqual(@as(usize, 6 + (input.len + 5 * 4) + 4), zlib_dict_split.len);
    const zlib_dict_adaptive = try encodeZlibBestAdaptiveSplitWithDictionaryAlloc(std.testing.allocator, &input, dictionary, optionsForLevel(.fastest), optionsForLevel(.fastest).split_options);
    defer std.testing.allocator.free(zlib_dict_adaptive);
    try std.testing.expectEqual(zlib_stored_dict.len, zlib_dict_adaptive.len);
}

test "stored fast path does not mask repeated binary structure" {
    var input: [64 * 1024]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @intCast((i * 131 + (i >> 3) * 17 + 29) & 0xff);

    const encoded = try encodeRawBestAlloc(std.testing.allocator, &input, optionsForLevel(.fastest));
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(!usesStoredFastPath(&input, optionsForLevel(.fastest)));
    try std.testing.expect(!usesStoredFastPath(&input, optionsForLevel(.default)));
    const stored = try encodeRawStoredAlloc(std.testing.allocator, &input);
    defer std.testing.allocator.free(stored);
    try std.testing.expect(encoded.len < stored.len);
}

test "compression level presets round trip" {
    const input = "abcabcabcabc abcabcabcabc";
    inline for (.{ CompressionLevel.fastest, CompressionLevel.fast, CompressionLevel.default, CompressionLevel.best }) |level| {
        const encoded = try encodeRawBestAlloc(std.testing.allocator, input, optionsForLevel(level));
        defer std.testing.allocator.free(encoded);
        const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "compression level presets configure match windows and lazy thresholds" {
    try std.testing.expectEqual(@as(usize, 8 * 1024), optionsForLevel(.fastest).lz77_options.window_len);
    try std.testing.expectEqual(@as(usize, 16 * 1024), optionsForLevel(.fast).lz77_options.window_len);
    try std.testing.expectEqual(lz77.default_window_len, optionsForLevel(.default).lz77_options.window_len);
    try std.testing.expectEqual(lz77.default_window_len, optionsForLevel(.best).lz77_options.window_len);

    // Default is the production size/speed compromise: accept one-byte better
    // lazy matches so zlib/raw default output stays competitive with the Rust
    // miniz_oxide baseline on binary and source-like smoke payloads, while the
    // fast presets keep a higher threshold for throughput-oriented use cases.
    try std.testing.expectEqual(@as(usize, 3), optionsForLevel(.fastest).lz77_options.lazy_min_gain);
    try std.testing.expectEqual(@as(usize, 3), optionsForLevel(.fast).lz77_options.lazy_min_gain);
    try std.testing.expectEqual(@as(usize, 1), optionsForLevel(.default).lz77_options.lazy_min_gain);
    try std.testing.expectEqual(@as(usize, 1), optionsForLevel(.best).lz77_options.lazy_min_gain);
}

test "best level uses production optimal parser with full strategy wrappers" {
    const input = "abcabcabcabc lorem lorem lorem " ** 8 ++ "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const best = optionsForLevel(.best);
    try std.testing.expectEqual(ParserMode.optimal, best.parser);
    try std.testing.expectEqual(lz77.max_optimal_candidates, best.lz77_options.max_candidates);
    try std.testing.expect(best.lz77_options.max_chain >= 512);

    const optimal_plan = try planTokensAlloc(std.testing.allocator, input, best);
    defer optimal_plan.deinit(std.testing.allocator);
    const lazy_plan = try planTokensAlloc(std.testing.allocator, input, optionsForLevel(.default));
    defer lazy_plan.deinit(std.testing.allocator);
    try std.testing.expect(lz77.fixedBitCost(optimal_plan.tokens) <= lz77.fixedBitCost(lazy_plan.tokens));

    inline for (.{ CompressionStrategy.default, CompressionStrategy.filtered, CompressionStrategy.huffman_only, CompressionStrategy.rle }) |strategy| {
        var options = best;
        options.strategy = strategy;
        const raw = try encodeRawBestAdaptiveSplitAlloc(std.testing.allocator, input, options, .{ .min_block_len = 16, .max_block_len = 64, .sample_len = 16, .search_step = 16 });
        defer std.testing.allocator.free(raw);
        const raw_decoded = try decodeRawAutoAlloc(std.testing.allocator, raw);
        defer std.testing.allocator.free(raw_decoded);
        try std.testing.expectEqualSlices(u8, input, raw_decoded);

        const zlib_frame = try encodeZlibBestAdaptiveSplitAlloc(std.testing.allocator, input, options, .{ .min_block_len = 16, .max_block_len = 64, .sample_len = 16, .search_step = 16 });
        defer std.testing.allocator.free(zlib_frame);
        const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
        defer std.testing.allocator.free(zlib_decoded);
        try std.testing.expectEqualSlices(u8, input, zlib_decoded);

        const gzip_frame = try encodeGzipBestAdaptiveSplitAlloc(std.testing.allocator, input, options, .{ .min_block_len = 16, .max_block_len = 64, .sample_len = 16, .search_step = 16 });
        defer std.testing.allocator.free(gzip_frame);
        const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
        defer std.testing.allocator.free(gzip_decoded);
        try std.testing.expectEqualSlices(u8, input, gzip_decoded);
    }
}

test "gzip concatenated members decode in sequence" {
    const a = try encodeGzipFixedAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(a);
    const b = try encodeGzipFixedAlloc(std.testing.allocator, "world");
    defer std.testing.allocator.free(b);
    var cat: std.ArrayList(u8) = .empty;
    defer cat.deinit(std.testing.allocator);
    try cat.appendSlice(std.testing.allocator, a);
    try cat.appendSlice(std.testing.allocator, b);
    const decoded = try decodeGzipConcatenatedAlloc(std.testing.allocator, cat.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "helloworld", decoded);
    var into: [10]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 10), try decodeGzipConcatenated(cat.items, &into));
    try std.testing.expectEqualSlices(u8, "helloworld", &into);
    try std.testing.expectError(error.OutputTooSmall, decodeGzipConcatenated(cat.items, into[0..9]));
    try std.testing.expectError(error.OutputLimitExceeded, decodeGzipConcatenatedAllocLimited(std.testing.allocator, cat.items, 9));
    const limited = try decodeGzipConcatenatedAllocLimited(std.testing.allocator, cat.items, 10);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, "helloworld", limited);

    const exact = try decodeGzipConcatenatedAllocExactSize(std.testing.allocator, cat.items, 10);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, "helloworld", exact);
    try std.testing.expectError(error.SizeMismatch, decodeGzipConcatenatedAllocExactSize(std.testing.allocator, cat.items, 9));
    try std.testing.expectError(error.SizeMismatch, decodeGzipConcatenatedAllocExactSize(std.testing.allocator, cat.items, 11));
}

test "gzip concatenated members keep match history isolated" {
    const a = try encodeGzipStoredAlloc(std.testing.allocator, "abc");
    defer std.testing.allocator.free(a);

    const invalid_raw = try encodeRawFixedTokensAlloc(std.testing.allocator, &.{.{ .match = .{ .length = 3, .distance = 3 } }});
    defer std.testing.allocator.free(invalid_raw);

    var b: std.ArrayList(u8) = .empty;
    defer b.deinit(std.testing.allocator);
    try b.appendSlice(std.testing.allocator, &gzip_header);
    try b.appendSlice(std.testing.allocator, invalid_raw);
    // If a concatenated decoder accidentally allowed member 2 to reference
    // member 1's output, this footer would make the malformed member appear
    // checksum-valid. Each gzip member owns an independent deflate stream, so
    // the first token in member 2 must still be rejected as an invalid match.
    var footer: [8]u8 = undefined;
    std.mem.writeInt(u32, footer[0..4], checksum.crc32Best("abc"), .little);
    std.mem.writeInt(u32, footer[4..8], 3, .little);
    try b.appendSlice(std.testing.allocator, &footer);

    var cat: std.ArrayList(u8) = .empty;
    defer cat.deinit(std.testing.allocator);
    try cat.appendSlice(std.testing.allocator, a);
    try cat.appendSlice(std.testing.allocator, b.items);

    try std.testing.expectError(error.InvalidMatch, decodeGzipConcatenatedAlloc(std.testing.allocator, cat.items));
    var out: [6]u8 = undefined;
    try std.testing.expectError(error.InvalidMatch, decodeGzipConcatenated(cat.items, &out));
}

test "fast level skips dynamic block candidate" {
    const input = "abcabcabcabc";
    const fast = try encodeRawBestAlloc(std.testing.allocator, input, optionsForLevel(.fast));
    defer std.testing.allocator.free(fast);
    const stored = try encodeRawStoredAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(stored);
    const fixed = try encodeRawFixedWithOptionsAlloc(std.testing.allocator, input, optionsForLevel(.fast));
    defer std.testing.allocator.free(fixed);
    try std.testing.expect(fast.len == @min(stored.len, fixed.len));
}

test "split raw fixed encoder emits multi-block deflate stream" {
    const input = "abcdefghijklmnopqrstuvwxyz";
    const encoded = try encodeRawFixedSplitAlloc(std.testing.allocator, input, 7, optionsForLevel(.fast));
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "split raw dynamic encoder emits multi-block deflate stream" {
    const input = "abcdefghijklmnopqrstuvwxyz";
    const encoded = try encodeRawDynamicSplitAlloc(std.testing.allocator, input, 7, optionsForLevel(.fast));
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "split raw best encoder selects block modes independently" {
    const input = "abcdefghijklmnopqrstuvwxyz" ++ ("abcabcabcabc" ** 8);
    const encoded = try encodeRawBestSplitAlloc(std.testing.allocator, input, 26, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);

    const fixed = try encodeRawFixedSplitAlloc(std.testing.allocator, input, 26, optionsForLevel(.default));
    defer std.testing.allocator.free(fixed);
    const dynamic = try encodeRawDynamicSplitAlloc(std.testing.allocator, input, 26, optionsForLevel(.default));
    defer std.testing.allocator.free(dynamic);
    try std.testing.expect(encoded.len <= fixed.len);
    try std.testing.expect(encoded.len <= dynamic.len);
}

test "fixed bit cost model predicts fixed token byte length" {
    const input = "abcabcabcabc xyz xyz xyz";
    const plan = try planTokensAlloc(std.testing.allocator, input, optionsForLevel(.default));
    defer plan.deinit(std.testing.allocator);
    const fixed = try encodeRawFixedTokensFinalAlloc(std.testing.allocator, plan.tokens, true);
    defer std.testing.allocator.free(fixed);
    try std.testing.expectEqual((lz77.fixedBitCost(plan.tokens) + 7) / 8, fixed.len);
}

test "dynamic bit cost model predicts dynamic token byte length" {
    const input = "abcabcabcabcabcabc";
    const plan = try planTokensAlloc(std.testing.allocator, input, optionsForLevel(.default));
    defer plan.deinit(std.testing.allocator);
    const dynamic = try encodeRawDynamicTokensFinalAlloc(std.testing.allocator, plan.tokens, true);
    defer std.testing.allocator.free(dynamic);
    try std.testing.expectEqual((try dynamicTokenBitCost(plan.tokens) + 7) / 8, dynamic.len);
}

test "inflate output capacity hint expands compressed frames but stays capped" {
    try std.testing.expectEqual(@as(usize, 0), inflateOutputCapacityHint(0));
    try std.testing.expectEqual(@as(usize, 64), inflateOutputCapacityHint(1));
    try std.testing.expectEqual(@as(usize, 2048), inflateOutputCapacityHint(32));
    try std.testing.expectEqual(@as(usize, 1 << 20), inflateOutputCapacityHint(64 * 1024));
    try std.testing.expectEqual(@as(usize, 1 << 20), inflateOutputCapacityHint(std.math.maxInt(usize)));
}

test "dynamic code-length alphabet uses weighted tree lengths" {
    var freqs: [19]u32 = @splat(0);
    freqs[0] = 80;
    freqs[16] = 20;
    freqs[17] = 10;
    freqs[18] = 5;
    completeCodeLengthFrequencySet(&freqs);
    const lengths = huffman.treeCodeLengths(19, &freqs, 7);
    try std.testing.expect(lengths[0] <= lengths[18]);
    try std.testing.expect(lengths[16] <= lengths[18]);
}

test "dynamic HCLEN trimming keeps required code-length alphabet" {
    var lengths: [19]u4 = @splat(0);
    try std.testing.expectEqual(@as(usize, 4), trimmedCodeLengthAlphabetCount(&lengths));
    lengths[huffman.code_length_order[3]] = 1;
    try std.testing.expectEqual(@as(usize, 4), trimmedCodeLengthAlphabetCount(&lengths));
    lengths[huffman.code_length_order[10]] = 1;
    try std.testing.expectEqual(@as(usize, 11), trimmedCodeLengthAlphabetCount(&lengths));
}

test "dynamic HLIT and HDIST trimming keep required minimums" {
    var lit_lengths: [286]u4 = @splat(0);
    var dist_lengths: [30]u4 = @splat(0);
    try std.testing.expectEqual(@as(usize, 257), trimmedLiteralCodeCount(&lit_lengths));
    try std.testing.expectEqual(@as(usize, 1), trimmedDistanceCodeCount(&dist_lengths));

    lit_lengths[285] = 1;
    dist_lengths[29] = 1;
    try std.testing.expectEqual(@as(usize, 286), trimmedLiteralCodeCount(&lit_lengths));
    try std.testing.expectEqual(@as(usize, 30), trimmedDistanceCodeCount(&dist_lengths));
}

test "split raw best encoder can emit stored block after compressed block" {
    const input = ("aaaaaaaaaaaaaaaa" ** 8) ++ "abcdefghijklmnopqrstuvwxyz";
    const encoded = try encodeRawBestSplitAlloc(std.testing.allocator, input, 128, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "zlib and gzip split-best wrappers round trip" {
    const input = "abcdefghijklmnopqrstuvwxyz" ++ ("abcabcabcabc" ** 8);
    const zlib_frame = try encodeZlibBestSplitAlloc(std.testing.allocator, input, 26, optionsForLevel(.default));
    defer std.testing.allocator.free(zlib_frame);
    const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, input, zlib_decoded);

    const gzip_frame = try encodeGzipBestSplitAlloc(std.testing.allocator, input, 26, optionsForLevel(.default));
    defer std.testing.allocator.free(gzip_frame);
    const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, input, gzip_decoded);
}

test "adaptive split best wrappers round trip" {
    const input = ("aaaaaaaaaaaaaaaa" ** 4) ++ "abcdefghijklmnopqrstuvwxyz" ++ ("abcabcabcabc" ** 8);
    const raw = try encodeRawBestAdaptiveSplitAlloc(std.testing.allocator, input, optionsForLevel(.default), .{ .min_block_len = 16, .max_block_len = 64, .sample_len = 8 });
    defer std.testing.allocator.free(raw);
    const raw_decoded = try decodeRawAutoAlloc(std.testing.allocator, raw);
    defer std.testing.allocator.free(raw_decoded);
    try std.testing.expectEqualSlices(u8, input, raw_decoded);

    const zlib_frame = try encodeZlibBestAdaptiveSplitAlloc(std.testing.allocator, input, optionsForLevel(.default), .{ .min_block_len = 16, .max_block_len = 64, .sample_len = 8 });
    defer std.testing.allocator.free(zlib_frame);
    const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, input, zlib_decoded);

    const gzip_frame = try encodeGzipBestAdaptiveSplitAlloc(std.testing.allocator, input, optionsForLevel(.default), .{ .min_block_len = 16, .max_block_len = 64, .sample_len = 8 });
    defer std.testing.allocator.free(gzip_frame);
    const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, input, gzip_decoded);
}

test "adaptive split search uses costed candidate lengths" {
    const input = ("aaaaaaaaaaaaaaaa" ** 4) ++ "abcdefghijklmnopqrstuvwxyz" ++ ("abcabcabcabc" ** 8);
    const chosen = try chooseCostedAdaptiveBlockLen(std.testing.allocator, input, 16, 64, 8, 16, optionsForLevel(.default));
    try std.testing.expect(chosen >= 16);
    try std.testing.expect(chosen <= 64);
    const encoded = try encodeRawBestAdaptiveSplitAlloc(std.testing.allocator, input, optionsForLevel(.default), .{ .min_block_len = 16, .max_block_len = 64, .sample_len = 8, .search_step = 16 });
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "adaptive split falls back to one-shot when smaller" {
    const input = "the quick brown fox jumps over the lazy dog\n" ** 128;
    const options = optionsForLevel(.best);
    const one_shot = try encodeRawBestAlloc(std.testing.allocator, input, options);
    defer std.testing.allocator.free(one_shot);
    const adaptive = try encodeRawBestAdaptiveSplitAlloc(std.testing.allocator, input, options, .{ .min_block_len = 16, .max_block_len = 64, .sample_len = 8, .search_step = 16 });
    defer std.testing.allocator.free(adaptive);
    try std.testing.expect(adaptive.len <= one_shot.len);
    const decoded = try decodeRawAutoAlloc(std.testing.allocator, adaptive);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "adaptive split skips full-window search for small production inputs" {
    const input = "the quick brown fox jumps over the lazy dog\n" ** 128;
    const options = optionsForLevel(.default);
    const raw_one_shot = try encodeRawBestAlloc(std.testing.allocator, input, options);
    defer std.testing.allocator.free(raw_one_shot);
    const raw_adaptive = try encodeRawBestAdaptiveSplitAlloc(std.testing.allocator, input, options, options.split_options);
    defer std.testing.allocator.free(raw_adaptive);
    try std.testing.expectEqualSlices(u8, raw_one_shot, raw_adaptive);

    const zlib_one_shot = try encodeZlibBestAlloc(std.testing.allocator, input, options);
    defer std.testing.allocator.free(zlib_one_shot);
    const zlib_adaptive = try encodeZlibBestAdaptiveSplitAlloc(std.testing.allocator, input, options, options.split_options);
    defer std.testing.allocator.free(zlib_adaptive);
    try std.testing.expectEqualSlices(u8, zlib_one_shot, zlib_adaptive);

    const gzip_one_shot = try encodeGzipBestAlloc(std.testing.allocator, input, options);
    defer std.testing.allocator.free(gzip_one_shot);
    const gzip_adaptive = try encodeGzipBestAdaptiveSplitAlloc(std.testing.allocator, input, options, options.split_options);
    defer std.testing.allocator.free(gzip_adaptive);
    try std.testing.expectEqualSlices(u8, gzip_one_shot, gzip_adaptive);
}
