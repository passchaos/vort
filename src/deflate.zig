const std = @import("std");
const builtin = @import("builtin");
const checksum = @import("checksum.zig");
const bitstream = @import("bitstream.zig");
const huffman = @import("huffman.zig");
const lz77 = @import("lz77.zig");
const core = @import("core.zig");

pub const Error = core.Error;
pub const max_stored_block_len: usize = std.math.maxInt(u16);

const BlockHeader = struct {
    final: bool,
    block_type: u2,
};

const StoredLengthPair = struct {
    len: u16,
    nlen: u16,
};

fn readBlockHeader(reader: anytype) Error!BlockHeader {
    const header = try reader.readBits(u3, 3);
    return .{
        .final = (header & 0x01) != 0,
        .block_type = @intCast(header >> 1),
    };
}

fn isStoredBlockHeaderByte(header: u8) bool {
    return (header & 0x06) == 0;
}

fn rejectReservedFirstBlockBeforeAlloc(input: []const u8) Error!void {
    if (input.len == 0) return;
    // BTYPE=3 is reserved by RFC 1951 and can be detected from the first
    // byte without decoding any payload. Allocator-returning helpers use this
    // to preserve corruption errors before trusting caller- or wrapper-provided
    // size hints for heap allocation.
    if ((input[0] & 0x06) == 0x06) return error.InvalidDeflateBlockType;
}

fn readStoredLengthPairUnchecked(input: []const u8, offset: usize) Error!StoredLengthPair {
    const pair = std.mem.readInt(u32, input[offset..][0..4], .little);
    const len: u16 = @truncate(pair);
    const nlen: u16 = @truncate(pair >> 16);
    // LEN and NLEN are adjacent little-endian fields. Loading both at once
    // keeps the stored-only wrapper hot path to one bounds-checked word load
    // per block while preserving the RFC 1951 one's-complement validation.
    if ((len ^ nlen) != std.math.maxInt(u16)) return error.StoredLengthMismatch;
    return .{ .len = len, .nlen = nlen };
}

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

pub const RawDeflateBlockType = enum(u2) {
    stored = 0,
    fixed = 1,
    dynamic = 2,
};

pub const RawDeflateHeaderInfo = struct {
    /// True when BFINAL is set for the first block.
    final: bool,
    /// First block type decoded from BTYPE.
    block_type: RawDeflateBlockType,
    /// Number of header bits consumed before the block-specific payload starts.
    data_bit_offset: usize,
    /// Byte containing the block-specific payload start. For fixed/dynamic
    /// blocks this may still contain unread bits because DEFLATE is bit-packed.
    data_byte_offset: usize,
    /// Number of bits consumed by this lightweight header inspection. This is
    /// equal to data_bit_offset for fixed blocks, includes byte padding plus
    /// LEN/NLEN for stored blocks, and includes HLIT/HDIST/HCLEN plus the
    /// code-length-code lengths for dynamic blocks.
    header_bits_consumed: usize,
    /// Byte offset corresponding to header_bits_consumed, rounded up when the
    /// inspection stops in the middle of a byte.
    header_bytes_consumed: usize,
    /// Stored-block LEN when BTYPE=stored, otherwise null.
    stored_len: ?u16 = null,
    /// Stored-block NLEN when BTYPE=stored, otherwise null.
    stored_nlen: ?u16 = null,
    /// Byte offset where stored payload bytes start after byte alignment and
    /// LEN/NLEN. For compressed block types this remains null because payload
    /// starts at data_bit_offset rather than a byte-aligned LEN/NLEN section.
    stored_payload_offset: ?usize = null,
    /// Dynamic-block HLIT value after adding the RFC 1951 base of 257.
    dynamic_hlit: ?u16 = null,
    /// Dynamic-block HDIST value after adding the RFC 1951 base of 1.
    dynamic_hdist: ?u16 = null,
    /// Dynamic-block HCLEN value after adding the RFC 1951 base of 4.
    dynamic_hclen: ?u8 = null,
    /// Number of code-length-code lengths present after HCLEN expansion.
    dynamic_code_length_count: ?u8 = null,
    /// Code-length-code lengths indexed by symbol 0..18. Entries outside the
    /// HCLEN prefix order remain zero, matching RFC 1951 semantics.
    dynamic_code_length_lengths: [19]u4 = @splat(0),
    /// Number of code-length RLE symbol 16 operations (repeat previous).
    dynamic_code_length_repeat_prev: ?u16 = null,
    /// Number of code-length RLE symbol 17 operations (repeat zero 3..10).
    dynamic_code_length_repeat_zero_short: ?u16 = null,
    /// Number of code-length RLE symbol 18 operations (repeat zero 11..138).
    dynamic_code_length_repeat_zero_long: ?u16 = null,
    /// Number of non-zero literal/length code lengths in the dynamic header.
    dynamic_literal_nonzero: ?u16 = null,
    /// Number of zero literal/length code lengths in the dynamic header.
    dynamic_literal_zero: ?u16 = null,
    /// Maximum literal/length code length in bits.
    dynamic_literal_max_bits: ?u8 = null,
    /// Literal/length code-length histogram indexed by bit length 0..15.
    dynamic_literal_length_histogram: [16]u16 = @splat(0),
    /// Number of non-zero distance code lengths in the dynamic header.
    dynamic_distance_nonzero: ?u16 = null,
    /// Number of zero distance code lengths in the dynamic header.
    dynamic_distance_zero: ?u16 = null,
    /// Maximum distance code length in bits.
    dynamic_distance_max_bits: ?u8 = null,
    /// Distance code-length histogram indexed by bit length 0..15.
    dynamic_distance_length_histogram: [16]u16 = @splat(0),
    /// Whether literal/length symbol 256 (end-of-block) is present.
    dynamic_has_eob: ?bool = null,
    /// Bit position after reading the full dynamic code-length sequences.
    dynamic_lengths_bit_offset: ?usize = null,
    /// Byte offset corresponding to dynamic_lengths_bit_offset.
    dynamic_lengths_byte_offset: ?usize = null,
};

pub const DynamicDecodeProfile = struct {
    pub const length_symbol_count = length_table.len;
    pub const distance_symbol_count = distance_table.len;
    pub const match_class_count = 4;

    output_bytes: usize = 0,
    literal_symbols: usize = 0,
    length_symbols: usize = 0,
    match_bytes: usize = 0,
    distance_symbols: usize = 0,
    length_symbol_histogram: [length_symbol_count]usize = @splat(0),
    distance_symbol_histogram: [distance_symbol_count]usize = @splat(0),
    length_extra_reads: usize = 0,
    distance_extra_reads: usize = 0,
    length_extra_bits: usize = 0,
    length_code_bits: usize = 0,
    distance_extra_bits: usize = 0,
    distance_code_bits: usize = 0,
    literal_fast_hits: usize = 0,
    literal_fast_misses: usize = 0,
    distance_fast_hits: usize = 0,
    distance_fast_misses: usize = 0,
    literal_lookup_bits: u4 = 0,
    literal_lookup_covered: usize = 0,
    literal_lookup_size: usize = 0,
    distance_lookup_covered: usize = 0,
    distance_lookup_size: usize = 0,
    match_rle_count: usize = 0,
    match_rle_bytes: usize = 0,
    match_small_distance_count: usize = 0,
    match_small_distance_bytes: usize = 0,
    match_non_overlapping_count: usize = 0,
    match_non_overlapping_bytes: usize = 0,
    match_overlapping_count: usize = 0,
    match_overlapping_bytes: usize = 0,
    match_class_length_extra_reads: [match_class_count]usize = @splat(0),
    match_class_length_extra_bits: [match_class_count]usize = @splat(0),
    match_class_distance_extra_reads: [match_class_count]usize = @splat(0),
    match_class_distance_extra_bits: [match_class_count]usize = @splat(0),
    match_class_distance_code_bits: [match_class_count]usize = @splat(0),
    dynamic_blocks: usize = 0,
    dynamic_unique_table_signatures: usize = 0,
    dynamic_repeated_table_signatures: usize = 0,
    dynamic_consecutive_repeated_table_signatures: usize = 0,
    fixed_blocks: usize = 0,
    stored_blocks: usize = 0,
    mix: u64 = 0,
};

const ProfileMatchClass = enum(usize) {
    rle = 0,
    small_distance = 1,
    non_overlapping = 2,
    overlapping = 3,
};

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

pub const GzipHeaderInfo = struct {
    /// Offset where the raw deflate member payload begins. All optional header
    /// fields and FHCRC bytes are before this offset.
    data_offset: usize,
    /// Raw FLG byte after reserved-bit validation.
    flags: u8,
    text: bool,
    mtime: u32,
    xfl: u8,
    os: u8,
    /// Optional FEXTRA bytes. The slice aliases the caller's input and excludes
    /// the two-byte XLEN field.
    extra: ?[]const u8 = null,
    /// Optional FNAME bytes, excluding the terminating NUL. The slice aliases
    /// the caller's input.
    filename: ?[]const u8 = null,
    /// Optional FCOMMENT bytes, excluding the terminating NUL. The slice
    /// aliases the caller's input.
    comment: ?[]const u8 = null,
    /// Optional FHCRC value after validation against the bytes before the CRC
    /// field. The gzip spec stores only the low 16 bits of CRC-32.
    header_crc: ?u16 = null,
};

pub const GzipMemberInfo = struct {
    /// Zero-based concatenated-member index requested by the caller.
    member_index: usize,
    /// Absolute byte offset of the gzip member header within the supplied
    /// buffer. This is zero for ordinary single-member gzip frames.
    member_offset: usize,
    /// Parsed gzip header for this member. The embedded data_offset remains
    /// member-relative, while deflate_offset below provides the absolute stream
    /// offset. Any optional slices alias the caller-provided input.
    header: GzipHeaderInfo,
    /// Absolute byte offset where this member's raw DEFLATE payload starts.
    deflate_offset: usize,
    /// Exact byte length of this member's raw DEFLATE payload, excluding the
    /// gzip header and 8-byte trailer.
    deflate_bytes: usize,
    /// Exact decoded byte count for this member. The inspector materializes the
    /// member payload in caller-provided scratch allocation so it can report
    /// CRC/ISIZE diagnostics without accepting corrupt trailers as valid data.
    output_bytes: usize,
    /// Absolute byte offset of the 8-byte gzip trailer.
    footer_offset: usize,
    /// Exclusive byte offset after the selected member's trailer.
    end_offset: usize,
    /// CRC-32 value stored in the gzip trailer.
    footer_crc32: u32,
    /// CRC-32 computed from the decoded member payload.
    crc32: u32,
    /// Whether footer_crc32 matches crc32. A false value is diagnostic rather
    /// than fatal: unlike decode APIs, inspection keeps returning member
    /// metadata when the raw DEFLATE payload is decodable but the trailer is
    /// corrupt.
    crc32_matches: bool,
    /// ISIZE stored in the gzip trailer.
    footer_isize: u32,
    /// Decoded output byte count truncated to gzip's modulo-2^32 ISIZE field.
    isize: u32,
    /// Whether footer_isize matches isize.
    isize_matches: bool,
};

pub const ZlibHeaderInfo = struct {
    /// Offset where the raw deflate payload starts. This is 2 for ordinary
    /// zlib streams and 6 when FDICT/DICTID is present.
    data_offset: usize,
    cmf: u8,
    flg: u8,
    compression_method: u8,
    window_bits: u8,
    window_size: usize,
    fcheck: u8,
    uses_dictionary: bool,
    flevel: u2,
    /// Adler-32 dictionary identifier stored after CMF/FLG when FDICT is set.
    /// The slice parser only reports the ID; dictionary byte validation remains
    /// in the decode APIs that accept caller-provided preset dictionaries.
    dictionary_id: ?u32 = null,
};

pub const ZlibStreamInfo = struct {
    /// Parsed zlib wrapper header.
    header: ZlibHeaderInfo,
    /// Absolute byte offset where the raw DEFLATE payload starts.
    deflate_offset: usize,
    /// Exact byte length of the raw DEFLATE payload before the Adler-32 footer.
    deflate_bytes: usize,
    /// Exact decoded byte count for the inspected stream.
    output_bytes: usize,
    /// Absolute byte offset of the 4-byte Adler-32 footer.
    footer_offset: usize,
    /// Exclusive byte offset after the zlib stream footer. This may be smaller
    /// than the input length when callers intentionally inspect a stream prefix
    /// inside a larger buffer.
    end_offset: usize,
    /// Adler-32 value stored in the zlib footer.
    footer_adler32: u32,
    /// Adler-32 computed from the decoded stream payload.
    adler32: u32,
    /// Whether footer_adler32 matches adler32. A false value is diagnostic:
    /// unlike decode APIs, inspection keeps returning stream metadata when the
    /// raw DEFLATE payload is decodable but the footer is corrupt.
    adler32_matches: bool,
};

pub const ZlibDecodeOptions = struct {
    ignore_adler: bool = false,
    allow_trailing_data: bool = false,
};

pub const GzipDecodeOptions = struct {
    ignore_crc32: bool = false,
    ignore_isize: bool = false,
    allow_trailing_data: bool = false,
};

pub fn optionsForLevel(level: CompressionLevel) CompressionOptions {
    return switch (level) {
        .fastest => .{ .parser = .hash, .lz77_options = .{ .window_len = 16 * 1024, .max_chain = 6, .nice_len = 16, .max_candidates = 1, .lazy_min_gain = 3, .min_match = 4, .max_match = 96, .min_savings_bits = 6 }, .block_selection = .stored_fixed_dynamic, .split_options = .{ .min_block_len = 32 * 1024, .max_block_len = max_stored_block_len, .sample_len = 1024, .search_step = 32 * 1024 } },
        .fast => .{ .parser = .hash, .lz77_options = .{ .window_len = 16 * 1024, .max_chain = 32, .nice_len = 16, .max_candidates = 2, .lazy_min_gain = 3, .min_match = 4, .max_match = 128, .min_savings_bits = 4 }, .block_selection = .stored_fixed, .split_options = .{ .min_block_len = 16 * 1024, .max_block_len = max_stored_block_len, .sample_len = 2048, .search_step = 16 * 1024 } },
        .default => .{ .parser = .lazy, .lz77_options = .{ .window_len = lz77.default_window_len, .max_chain = 160, .nice_len = 80, .max_candidates = 6, .lazy_min_gain = 1, .min_match = 3, .max_match = lz77.max_match_len, .min_savings_bits = 1 }, .split_options = .{ .min_block_len = 8 * 1024, .max_block_len = max_stored_block_len, .sample_len = 4096, .search_step = 8 * 1024 } },
        .best => .{ .parser = .optimal, .lz77_options = .{ .window_len = lz77.default_window_len, .max_chain = 512, .nice_len = 128, .max_candidates = lz77.default_best_optimal_candidates, .lazy_min_gain = 1, .min_match = 3, .max_match = lz77.max_match_len, .min_savings_bits = 0 }, .split_options = .{ .min_block_len = 4 * 1024, .max_block_len = max_stored_block_len, .sample_len = 8192, .search_step = 4 * 1024 } },
    };
}

/// Map zlib-style numeric compression levels 1..9 onto Vort's current deflate
/// planning policies. Level 0 is intentionally not represented as
/// `CompressionOptions` because it is a stored/no-compression mode; use
/// `encodeZlibLevelAlloc` or `encodeZlibStored*` when callers need zlib level 0.
pub fn optionsForZlibLevel(level: u4) Error!CompressionOptions {
    return switch (level) {
        1 => optionsForLevel(.fastest),
        2 => .{ .parser = .hash, .lz77_options = .{ .window_len = 16 * 1024, .max_chain = 8, .nice_len = 16, .max_candidates = 1, .lazy_min_gain = 3, .min_match = 4, .max_match = 96, .min_savings_bits = 6 }, .block_selection = .stored_fixed, .split_options = .{ .min_block_len = 24 * 1024, .max_block_len = max_stored_block_len, .sample_len = 1536, .search_step = 24 * 1024 } },
        3 => optionsForLevel(.fast),
        4 => .{ .parser = .lazy, .lz77_options = .{ .window_len = lz77.default_window_len, .max_chain = 32, .nice_len = 32, .max_candidates = 2, .lazy_min_gain = 2, .min_match = 3, .max_match = 160, .min_savings_bits = 2 }, .split_options = .{ .min_block_len = 12 * 1024, .max_block_len = max_stored_block_len, .sample_len = 3072, .search_step = 12 * 1024 } },
        5 => .{ .parser = .lazy, .lz77_options = .{ .window_len = lz77.default_window_len, .max_chain = 64, .nice_len = 48, .max_candidates = 3, .lazy_min_gain = 1, .min_match = 3, .max_match = 224, .min_savings_bits = 1 }, .split_options = .{ .min_block_len = 10 * 1024, .max_block_len = max_stored_block_len, .sample_len = 3584, .search_step = 10 * 1024 } },
        6 => optionsForLevel(.default),
        7 => .{ .parser = .lazy, .lz77_options = .{ .window_len = lz77.default_window_len, .max_chain = 256, .nice_len = 96, .max_candidates = 6, .lazy_min_gain = 1, .min_match = 3, .max_match = lz77.max_match_len, .min_savings_bits = 0 }, .split_options = .{ .min_block_len = 6 * 1024, .max_block_len = max_stored_block_len, .sample_len = 6144, .search_step = 6 * 1024 } },
        8 => .{ .parser = .optimal, .lz77_options = .{ .window_len = lz77.default_window_len, .max_chain = 384, .nice_len = 128, .max_candidates = @max(4, lz77.max_optimal_candidates / 2), .lazy_min_gain = 1, .min_match = 3, .max_match = lz77.max_match_len, .min_savings_bits = 0 }, .split_options = .{ .min_block_len = 5 * 1024, .max_block_len = max_stored_block_len, .sample_len = 7168, .search_step = 5 * 1024 } },
        9 => optionsForLevel(.best),
        else => error.InvalidBlockPlan,
    };
}

const BestFallbackCandidates = struct {
    items: [2]CompressionOptions = undefined,
    len: usize = 0,

    fn append(self: *BestFallbackCandidates, options: CompressionOptions) void {
        self.items[self.len] = options;
        self.len += 1;
    }

    fn slice(self: *const BestFallbackCandidates) []const CompressionOptions {
        return self.items[0..self.len];
    }
};

fn bestFallbackCandidates(options: CompressionOptions) BestFallbackCandidates {
    const normalized = normalizeOptionsForStrategy(options);
    var candidates = BestFallbackCandidates{};
    if (normalized.strategy == .default and normalized.parser == .optimal) {
        candidates.append(optionsForLevel(.default));
        var filtered = options;
        filtered.strategy = .filtered;
        candidates.append(filtered);
    }
    return candidates;
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
    const encoded = try writer.toOwnedSlice(allocator);
    errdefer allocator.free(encoded);
    for (bestFallbackCandidates(options).slice()) |fallback_options| {
        const fallback = try encodeRawBestAlloc(allocator, input, fallback_options);
        errdefer allocator.free(fallback);
        if (fallback.len < encoded.len) {
            allocator.free(encoded);
            return fallback;
        }
        allocator.free(fallback);
    }
    return encoded;
}

pub fn usesStoredFastPath(input: []const u8, options: CompressionOptions) bool {
    if (input.len < 8 * 1024) return false;
    const normalized = normalizeOptionsForStrategy(options);
    if (normalized.strategy != .default) return false;
    if (normalized.parser != .hash and normalized.parser != .lazy) return false;
    if (normalized.parser == .lazy and normalized.block_selection != .stored_fixed_dynamic) return false;
    if (normalized.parser == .hash and normalized.block_selection != .stored_fixed and normalized.block_selection != .stored_fixed_dynamic) return false;
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
    const encoded = try writer.toOwnedSlice(allocator);
    errdefer allocator.free(encoded);
    for (bestFallbackCandidates(options).slice()) |fallback_options| {
        const fallback = try encodeRawBestWithDictionaryAlloc(allocator, input, dictionary, fallback_options);
        errdefer allocator.free(fallback);
        if (fallback.len < encoded.len) {
            allocator.free(encoded);
            return fallback;
        }
        allocator.free(fallback);
    }
    return encoded;
}

pub fn encodeRawLevelAlloc(allocator: std.mem.Allocator, input: []const u8, level: u4) ![]u8 {
    if (level == 0) return encodeRawStoredAlloc(allocator, input);
    return encodeRawBestAlloc(allocator, input, try optionsForZlibLevel(level));
}

pub fn encodeRawLevelWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, level: u4) ![]u8 {
    if (level == 0) return encodeRawStoredAlloc(allocator, input);
    return encodeRawBestWithDictionaryAlloc(allocator, input, dictionary, try optionsForZlibLevel(level));
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
        if (hasDistanceSymbols(&dist_freqs)) completeDistanceFrequencySet(&dist_freqs);

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
    var lengths: [286 + 30]u4 = undefined;
    @memcpy(lengths[0..lit_lengths.len], lit_lengths);
    @memcpy(lengths[lit_lengths.len..][0..dist_lengths.len], dist_lengths);
    var ops = CodeLengthOpBuffer{};
    try appendCodeLengthOps(&ops, lengths[0 .. lit_lengths.len + dist_lengths.len]);
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

fn hasDistanceSymbols(freqs: *const [30]u32) bool {
    for (freqs.*) |freq| if (freq != 0) return true;
    return false;
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
    var reader = bitstream.BufferedBitReader.init(input);
    const header = try readBlockHeader(&reader);
    if (header.block_type != 0b01) return error.InvalidDeflateBlockType;
    const final = header.final;

    var out_offset: usize = 0;
    while (true) {
        const symbol = try huffman.decodeFixedLiteralValueFast(&reader);
        if (symbol < 256) {
            if (out_offset == output.len) return error.OutputTooSmall;
            output[out_offset] = @intCast(symbol);
            out_offset += 1;
        } else if (symbol == 256) {
            if (!final) return error.TruncatedFrame;
            return .{ .input_read = reader.byteOffset(), .output_written = out_offset };
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, &reader);
            const distance_symbol = try huffman.decodeFixedDistanceValueFast(&reader);
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

    var reader = bitstream.BufferedBitReader.init(input);
    const header = try readBlockHeader(&reader);
    if (header.block_type != 0b01) return error.InvalidDeflateBlockType;
    const final = header.final;

    while (true) {
        const symbol = try huffman.decodeFixedLiteralValueFast(&reader);
        if (symbol < 256) {
            try out.append(allocator, @intCast(symbol));
        } else if (symbol == 256) {
            if (!final) return error.TruncatedFrame;
            return .{ .bytes = try out.toOwnedSlice(allocator), .input_read = reader.byteOffset() };
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, &reader);
            const distance_symbol = try huffman.decodeFixedDistanceValueFast(&reader);
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

    var reader = bitstream.BufferedBitReader.init(input);
    const parsed = try huffman.parseDynamicLengths(&reader);
    const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
    const dist_decoder = try makeDynamicDistanceDecoderFromLengths(parsed.distance_lengths[0..parsed.header.hdist]);
    const lit_lookup_bits = dynamicLiteralLookupBits(parsed);
    if (lit_lookup_bits == 9) {
        const lit_decoder = huffman.FastDecoder(286, 9).init(lit_table);
        try decodeCompressedBlockFromReader(allocator, &reader, &out, "", null, &lit_decoder, &dist_decoder);
    } else {
        const lit_decoder = huffman.FastDecoder(286, 11).init(lit_table);
        try decodeCompressedBlockFromReader(allocator, &reader, &out, "", null, &lit_decoder, &dist_decoder);
    }
    if (!parsed.header.final) return error.TruncatedFrame;
    return .{ .bytes = try out.toOwnedSlice(allocator), .input_read = reader.byteOffset() };
}

pub fn decodeRawDynamicAllocStrict(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const result = try decodeRawDynamicAlloc(allocator, input);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

const DynamicDistanceDecoder = union(enum) {
    single: huffman.HuffmanTable(30).Entry,
    fast8: huffman.FastDecoder(30, 8),

    fn init(table: huffman.HuffmanTable(30)) DynamicDistanceDecoder {
        if (table.len == 1) return .{ .single = table.entries[0] };
        return .{ .fast8 = huffman.FastDecoder(30, 8).init(table) };
    }

    inline fn decodeValue(self: *const DynamicDistanceDecoder, reader: anytype) Error!u16 {
        return switch (self.*) {
            .single => |entry| blk: {
                const bits: u6 = entry.bits;
                const code = reader.peekBitsPadded(u16, bits);
                if (!reader.hasStagedBits(entry.bits)) return error.TruncatedFrame;
                if (code != entry.code) return error.InvalidHuffmanCode;
                reader.advanceBitsStagedAssumeAvailable(bits);
                break :blk entry.symbol;
            },
            .fast8 => |*decoder| try decoder.decodeValue(reader),
        };
    }

    fn fastWouldHit(self: *const DynamicDistanceDecoder, reader: *bitstream.BufferedBitReader) bool {
        return switch (self.*) {
            .single => |entry| entry.bits <= 8 and reader.hasBits(entry.bits),
            .fast8 => |*decoder| huffmanFastWouldHit(30, 8, decoder, reader),
        };
    }

    fn lookupCoverage(self: *const DynamicDistanceDecoder) usize {
        return switch (self.*) {
            .single => 0,
            .fast8 => |*decoder| decoder.lookupCoverage(),
        };
    }

    fn lookupSize(self: *const DynamicDistanceDecoder) usize {
        return switch (self.*) {
            .single => 0,
            .fast8 => |*decoder| decoder.lookup.len,
        };
    }
};

/// PNG-oriented dynamic literal/length table for the contiguous caller-buffer
/// inflater. The generic Huffman decoder remains the scalar/reference path for
/// long codes, chunked readers, dictionaries, and output tails.
///
/// A primary entry classifies the symbol and carries all metadata needed by the
/// hot loop. Literal entries may contain two adjacent literals when both codes
/// fit in the same 12-bit lookahead. This mirrors the useful part of
/// fdeflate's table shape without changing Vort's public decoder contracts.
const FusedDynamicLiteralDecoder = struct {
    const lookup_bits: u4 = 12;
    const lookup_len = @as(usize, 1) << lookup_bits;
    const lookup_mask: u64 = lookup_len - 1;
    const bits_mask: u32 = 0x0f;
    const kind_mask: u32 = 0x30;
    const invalid: u32 = 0x00;
    const literal: u32 = 0x10;
    const length: u32 = 0x20;
    const end_of_block: u32 = 0x30;
    const double_literal: u32 = 0x40;
    const extra_bits_shift = 8;
    const value_shift = 16;
    const second_literal_shift = 24;

    table: *const huffman.HuffmanTable(286),
    lookup: [lookup_len]u32 = undefined,

    const Self = @This();

    fn init(table: *const huffman.HuffmanTable(286)) Self {
        var decoder = Self{ .table = table };
        // A complete tree whose longest code fits the primary lookup assigns
        // every slot below. Avoid clearing 16 KiB for that overwhelmingly
        // common dynamic-PNG shape; Lohengrin contains 571 unique blocks, so
        // the otherwise redundant memset is visible in end-to-end profiles.
        if (!primaryLookupIsComplete(table)) {
            @memset(&decoder.lookup, invalid);
        }

        for (table.entries[0..table.len]) |entry| {
            if (entry.bits > lookup_bits) continue;
            const semantic = semanticEntry(entry.symbol, entry.bits);
            const fill = @as(usize, 1) << @intCast(lookup_bits - entry.bits);
            var i: usize = 0;
            while (i < fill) : (i += 1) {
                const index = entry.code | (i << entry.bits);
                decoder.lookup[index] = semantic;
            }
        }

        // Rewrite from high indexes to low indexes. The second-code lookup is
        // `index >> first_bits`, which is always lower than `index` except for
        // zero itself. Descending order therefore keeps that second slot in its
        // original single-symbol form without a separate 8 KiB shadow table.
        var index: usize = decoder.lookup.len;
        while (index != 0) {
            index -= 1;
            const first = decoder.lookup[index];
            if (entryKind(first) != literal or hasSecondLiteral(first)) continue;
            const first_bits = entryBits(first);
            const second = decoder.lookup[index >> @intCast(first_bits)];
            if (entryKind(second) != literal or hasSecondLiteral(second)) continue;

            const total_bits: u8 = @as(u8, first_bits) + @as(u8, entryBits(second));
            if (total_bits > lookup_bits) continue;
            decoder.lookup[index] = literal |
                double_literal |
                @as(u32, total_bits) |
                (first & (@as(u32, 0xff) << value_shift)) |
                (@as(u32, second >> value_shift) << second_literal_shift);
        }
        return decoder;
    }

    fn primaryLookupIsComplete(table: *const huffman.HuffmanTable(286)) bool {
        if (table.max_bits > lookup_bits) return false;
        var covered: usize = 0;
        var bits: u4 = 1;
        while (bits <= table.max_bits) : (bits += 1) {
            covered += @as(usize, table.count_by_bits[bits]) << @intCast(lookup_bits - bits);
        }
        return covered == lookup_len;
    }

    inline fn semanticEntry(symbol: u16, bits: u4) u32 {
        if (symbol < 256) {
            return literal | @as(u32, bits) | (@as(u32, symbol) << value_shift);
        }
        if (symbol == 256) return end_of_block | @as(u32, bits);
        if (symbol <= 285) {
            const metadata = length_table[symbol - 257];
            return length |
                @as(u32, bits) |
                (@as(u32, metadata.extra_bits) << extra_bits_shift) |
                (@as(u32, metadata.base) << value_shift);
        }
        return invalid;
    }

    inline fn entryBits(entry: u32) u6 {
        return @truncate(entry & bits_mask);
    }

    inline fn entryKind(entry: u32) u32 {
        return entry & kind_mask;
    }

    inline fn hasSecondLiteral(entry: u32) bool {
        return (entry & double_literal) != 0;
    }

    inline fn firstLiteral(entry: u32) u8 {
        return @truncate(entry >> value_shift);
    }

    inline fn secondLiteral(entry: u32) u8 {
        return @truncate(entry >> second_literal_shift);
    }

    inline fn lengthBase(entry: u32) usize {
        return @intCast(entry >> value_shift);
    }

    inline fn lengthExtraBits(entry: u32) u6 {
        return @truncate(entry >> extra_bits_shift);
    }
};

const SemanticDynamicDecoder = struct {
    const literal_lookup_bits: u4 = 12;
    const literal_lookup_len = @as(usize, 1) << literal_lookup_bits;
    const literal_lookup_mask: u64 = literal_lookup_len - 1;
    const distance_lookup_bits: u4 = 9;
    const distance_lookup_len = @as(usize, 1) << distance_lookup_bits;
    const distance_lookup_mask: u64 = distance_lookup_len - 1;
    const literal_secondary_capacity = 4096;
    const distance_secondary_capacity = 1024;

    const literal_flag: u32 = 0x8000;
    const exceptional_flag: u32 = 0x4000;
    const secondary_flag: u32 = 0x2000;

    literal: [literal_lookup_len]u32 = undefined,
    literal_secondary: [literal_secondary_capacity]u16 = undefined,
    literal_secondary_len: usize = 0,
    distance: [distance_lookup_len]u32 = undefined,
    distance_secondary: [distance_secondary_capacity]u16 = undefined,
    distance_secondary_len: usize = 0,
    single_distance: u32 = 0,
    compact_literal: *const huffman.HuffmanTable(286) = undefined,
    compact_distance: *const huffman.HuffmanTable(30) = undefined,

    const Self = @This();

    fn init(self: *Self, literal_table: *const huffman.HuffmanTable(286), distance_table_: *const huffman.HuffmanTable(30)) bool {
        if (!treeIsComplete(286, literal_table)) return false;

        self.* = Self{
            .distance = @splat(0),
            .compact_literal = literal_table,
            .compact_distance = distance_table_,
        };
        if (!self.buildLiteralTable(literal_table)) return false;
        if (!self.buildDistanceTable(distance_table_)) return false;
        return true;
    }

    fn initSingleDistance(self: *Self, literal_table: *const huffman.HuffmanTable(286), distance_table_: *const huffman.HuffmanTable(30)) bool {
        if (!treeIsComplete(286, literal_table) or distance_table_.len != 1) return false;
        const entry = distance_table_.entries[0];
        if (entry.code != 0 or entry.symbol >= distance_table.len) return false;

        self.* = Self{
            .single_distance = semanticDistanceEntry(entry.symbol, entry.bits),
            .compact_literal = literal_table,
            .compact_distance = distance_table_,
        };
        return self.buildLiteralTable(literal_table);
    }

    fn treeIsComplete(comptime symbol_count: usize, table: *const huffman.HuffmanTable(symbol_count)) bool {
        if (table.max_bits == 0) return false;
        var used: usize = 0;
        var bits: usize = 1;
        while (bits <= table.max_bits) : (bits += 1) {
            used += @as(usize, table.count_by_bits[bits]) << @intCast(@as(usize, table.max_bits) - bits);
        }
        return used == (@as(usize, 1) << @intCast(table.max_bits));
    }

    fn buildLiteralTable(self: *Self, table: *const huffman.HuffmanTable(286)) bool {
        // Build the primary table one code width at a time. After entries for a
        // width are installed, duplicating the completed prefix table grows it
        // to the next width. This writes each primary slot only O(1) times and
        // lets double-literal pairs be inserted once at their combined width.
        self.literal[0] = 0;
        self.literal[1] = 0;
        var total_bits: usize = 1;
        while (total_bits <= literal_lookup_bits) : (total_bits += 1) {
            const first = table.first_by_bits[total_bits];
            const end = first + table.count_by_bits[total_bits];
            for (table.entries[first..end]) |entry| {
                self.literal[entry.code] = semanticLiteralEntry(entry.symbol, entry.bits);
            }

            var first_bits: usize = 1;
            while (first_bits + 1 < total_bits) : (first_bits += 1) {
                const second_bits = total_bits - first_bits;
                const first_start = table.first_by_bits[first_bits];
                const first_end = first_start + table.count_by_bits[first_bits];
                const second_start = table.first_by_bits[second_bits];
                const second_end = second_start + table.count_by_bits[second_bits];
                for (table.entries[first_start..first_end]) |first_entry| {
                    if (first_entry.symbol >= 256) continue;
                    for (table.entries[second_start..second_end]) |second_entry| {
                        if (second_entry.symbol >= 256) continue;
                        const code = @as(usize, first_entry.code) |
                            (@as(usize, second_entry.code) << @intCast(first_bits));
                        self.literal[code] = (@as(u32, @intCast(total_bits)) & 0xf) |
                            literal_flag |
                            (2 << 8) |
                            (@as(u32, first_entry.symbol) << 16) |
                            (@as(u32, second_entry.symbol) << 24);
                    }
                }
            }

            if (total_bits < literal_lookup_bits) {
                const current_len = @as(usize, 1) << @intCast(total_bits);
                @memcpy(
                    self.literal[current_len .. current_len * 2],
                    self.literal[0..current_len],
                );
            }
        }

        var prefix_max_bits: [literal_lookup_len]u4 = @splat(0);
        for (table.entries[0..table.len]) |entry| {
            if (entry.bits > literal_lookup_bits) {
                const prefix = @as(usize, entry.code) & (literal_lookup_len - 1);
                prefix_max_bits[prefix] = @max(prefix_max_bits[prefix], entry.bits);
            }
        }

        for (prefix_max_bits, 0..) |max_bits, prefix| {
            if (max_bits == 0) continue;
            const size = @as(usize, 1) << @intCast(max_bits - literal_lookup_bits);
            if (self.literal_secondary_len + size > self.literal_secondary.len or size > 256) return false;
            const start = self.literal_secondary_len;
            self.literal_secondary_len += size;
            self.literal[prefix] = (@as(u32, @intCast(start)) << 16) |
                exceptional_flag |
                secondary_flag |
                @as(u32, @intCast(size - 1));
        }

        for (table.entries[0..table.len]) |entry| {
            if (entry.bits <= literal_lookup_bits) continue;
            const prefix = @as(usize, entry.code) & (literal_lookup_len - 1);
            const primary = self.literal[prefix];
            const start: usize = @intCast(primary >> 16);
            const mask: usize = @intCast(primary & 0xff);
            const suffix_bits: u4 = entry.bits - literal_lookup_bits;
            const suffix = @as(usize, entry.code) >> literal_lookup_bits;
            const fill = (mask + 1) >> suffix_bits;
            var i: usize = 0;
            while (i < fill) : (i += 1) {
                const index = start + suffix + (i << suffix_bits);
                self.literal_secondary[index] = (@as(u16, entry.symbol) << 4) | entry.bits;
            }
        }
        return true;
    }

    fn buildDistanceTable(self: *Self, table: *const huffman.HuffmanTable(30)) bool {
        var prefix_max_bits: [distance_lookup_len]u4 = @splat(0);
        for (table.entries[0..table.len]) |entry| {
            if (entry.bits <= distance_lookup_bits) {
                fillPrimary(
                    &self.distance,
                    distance_lookup_bits,
                    entry,
                    semanticDistanceEntry(entry.symbol, entry.bits),
                );
            } else {
                const prefix = @as(usize, entry.code) & (distance_lookup_len - 1);
                prefix_max_bits[prefix] = @max(prefix_max_bits[prefix], entry.bits);
            }
        }

        for (prefix_max_bits, 0..) |max_bits, prefix| {
            if (max_bits == 0) continue;
            const size = @as(usize, 1) << @intCast(max_bits - distance_lookup_bits);
            if (self.distance_secondary_len + size > self.distance_secondary.len or size > 256) return false;
            const start = self.distance_secondary_len;
            self.distance_secondary_len += size;
            self.distance[prefix] = (@as(u32, @intCast(start)) << 16) |
                exceptional_flag |
                secondary_flag |
                @as(u32, @intCast(size - 1));
        }

        for (table.entries[0..table.len]) |entry| {
            if (entry.bits <= distance_lookup_bits) continue;
            const prefix = @as(usize, entry.code) & (distance_lookup_len - 1);
            const primary = self.distance[prefix];
            const start: usize = @intCast(primary >> 16);
            const mask: usize = @intCast(primary & 0xff);
            const suffix_bits: u4 = entry.bits - distance_lookup_bits;
            const suffix = @as(usize, entry.code) >> distance_lookup_bits;
            const fill = (mask + 1) >> suffix_bits;
            var i: usize = 0;
            while (i < fill) : (i += 1) {
                const index = start + suffix + (i << suffix_bits);
                self.distance_secondary[index] = (@as(u16, entry.symbol) << 4) | entry.bits;
            }
        }
        return true;
    }

    fn fillPrimary(
        primary: anytype,
        comptime lookup_bits: u4,
        entry: anytype,
        semantic: u32,
    ) void {
        const fill = @as(usize, 1) << @intCast(lookup_bits - entry.bits);
        var i: usize = 0;
        while (i < fill) : (i += 1) {
            primary[entry.code | (i << entry.bits)] = semantic;
        }
    }

    fn semanticLiteralEntry(symbol: u16, bits: u4) u32 {
        if (symbol < 256) {
            return (@as(u32, symbol) << 16) | literal_flag | (1 << 8) | bits;
        }
        if (symbol == 256) return exceptional_flag | bits;
        if (symbol <= 285) {
            const metadata = length_table[symbol - 257];
            return (@as(u32, metadata.base) << 16) |
                (@as(u32, metadata.extra_bits) << 8) |
                bits;
        }
        return exceptional_flag;
    }

    fn semanticDistanceEntry(symbol: u16, bits: u4) u32 {
        if (symbol >= distance_table.len) return 0;
        const metadata = distance_table[symbol];
        return (@as(u32, metadata.base) << 16) |
            (@as(u32, metadata.extra_bits) << 8) |
            literal_flag |
            bits;
    }
};

fn dynamicLiteralLookupBits(parsed: huffman.DynamicLengths) u4 {
    if (parsed.literal_max_bits <= 9) return 9;
    // A 12-bit literal table avoids a handful of cold-symbol fallback scans, but
    // real PNG/text payloads with near-full dynamic alphabets spend most time on
    // successful literal lookups. Keeping the general dynamic table at 11 bits
    // improves cache locality and cuts per-block setup cost; miss rates remain
    // visible through `DynamicDecodeProfile` so the policy can be revisited if a
    // future corpus shifts toward long-code-heavy blocks.
    return 11;
}

fn makeDynamicDistanceDecoder(table: huffman.HuffmanTable(30)) DynamicDistanceDecoder {
    // Dynamic distance alphabets have at most 30 symbols. A 10-bit lookup table
    // made every dynamic block pay to initialize 1024 entries even though most
    // distance codes are short and infrequent compared with literals. An 8-bit
    // table keeps the common fast path while cutting per-block setup/cache
    // pressure, which shows up in the raw decode benchmark for many small
    // dynamic frames and wrapper benchmarks.
    return DynamicDistanceDecoder.init(table);
}

fn makeDynamicDistanceDecoderFromLengths(lengths: []const u4) Error!DynamicDistanceDecoder {
    var single_symbol: u16 = 0;
    var single_bits: u4 = 0;
    var non_zero: usize = 0;
    for (lengths, 0..) |bits, symbol| {
        if (bits == 0) continue;
        single_symbol = @intCast(symbol);
        single_bits = bits;
        non_zero += 1;
    }
    // A single-symbol dynamic distance alphabet always has canonical code zero.
    // Real PNG corpora can contain hundreds of such blocks; detecting the shape
    // before `HuffmanTable.init` avoids constructing and indexing a 30-symbol
    // table whose only runtime job would be to validate/consume that zero code.
    if (non_zero == 1) return .{ .single = .{ .symbol = single_symbol, .code = 0, .bits = single_bits } };
    return makeDynamicDistanceDecoder(try huffman.HuffmanTable(30).init(lengths));
}

pub fn profileFirstDynamicDeflateBlock(input: []const u8) Error!DynamicDecodeProfile {
    var reader = bitstream.BufferedBitReader.init(input);
    const parsed = try huffman.parseDynamicLengths(&reader);
    const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
    const dist_table = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
    var profile = DynamicDecodeProfile{};
    var table_tracker = DynamicTableSignatureTracker{};
    table_tracker.record(parsed, &profile);
    profile.dynamic_blocks = 1;
    switch (dynamicLiteralLookupBits(parsed)) {
        9 => try profileCompressedBlockInto(&reader, lit_table, dist_table, 9, &profile),
        else => try profileCompressedBlockInto(&reader, lit_table, dist_table, 11, &profile),
    }
    return profile;
}

pub fn profileDynamicDeflateBlocks(input: []const u8) Error!DynamicDecodeProfile {
    var reader = bitstream.BufferedBitReader.init(input);
    var profile = DynamicDecodeProfile{};
    var table_tracker = DynamicTableSignatureTracker{};
    while (true) {
        const header = try readBlockHeader(&reader);
        if (header.block_type != 2) return error.InvalidDeflateBlockType;
        try profileDynamicBlockAfterHeader(&reader, header.final, &profile, &table_tracker);
        if (header.final) return profile;
    }
}

pub fn profileDeflateBlocks(input: []const u8) Error!DynamicDecodeProfile {
    var reader = bitstream.BufferedBitReader.init(input);
    var profile = DynamicDecodeProfile{};
    var table_tracker = DynamicTableSignatureTracker{};
    while (true) {
        const header = try readBlockHeader(&reader);
        switch (header.block_type) {
            0 => try profileStoredBlockAfterHeader(&reader, &profile),
            1 => try profileFixedBlockAfterHeader(&reader, &profile),
            2 => try profileDynamicBlockAfterHeader(&reader, header.final, &profile, &table_tracker),
            else => return error.InvalidDeflateBlockType,
        }
        if (header.final) return profile;
    }
}

fn profileDynamicBlockAfterHeader(reader: *bitstream.BufferedBitReader, final: bool, profile: *DynamicDecodeProfile, table_tracker: *DynamicTableSignatureTracker) Error!void {
    const parsed = try huffman.parseDynamicLengthsAfterHeader(final, reader);
    const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
    const dist_table = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
    table_tracker.record(parsed, profile);
    profile.dynamic_blocks += 1;
    switch (dynamicLiteralLookupBits(parsed)) {
        9 => try profileCompressedBlockInto(reader, lit_table, dist_table, 9, profile),
        else => try profileCompressedBlockInto(reader, lit_table, dist_table, 11, profile),
    }
}

fn dynamicTableSignature(parsed: huffman.DynamicLengths) u64 {
    var hash: u64 = 0xcbf29ce484222325;
    hash = fnv1aByte(hash, @intCast(parsed.header.hlit & 0xff));
    hash = fnv1aByte(hash, @intCast(parsed.header.hlit >> 8));
    hash = fnv1aByte(hash, @intCast(parsed.header.hdist & 0xff));
    hash = fnv1aByte(hash, @intCast(parsed.header.hdist >> 8));
    for (parsed.literal_lengths[0..parsed.header.hlit]) |bits| hash = fnv1aByte(hash, bits);
    for (parsed.distance_lengths[0..parsed.header.hdist]) |bits| hash = fnv1aByte(hash, bits);
    return hash;
}

fn fnv1aByte(hash: u64, byte: u8) u64 {
    return (hash ^ byte) *% 0x100000001b3;
}

const DynamicTableSignatureTracker = struct {
    const capacity = 1024;
    signatures: [capacity]u64 = @splat(0),
    count: usize = 0,
    last: u64 = 0,

    fn record(self: *DynamicTableSignatureTracker, parsed: huffman.DynamicLengths, profile: *DynamicDecodeProfile) void {
        const signature = dynamicTableSignature(parsed);
        var seen = false;
        for (self.signatures[0..self.count]) |existing| {
            if (existing == signature) {
                seen = true;
                break;
            }
        }
        if (seen) {
            profile.dynamic_repeated_table_signatures += 1;
        } else if (self.count < capacity) {
            self.signatures[self.count] = signature;
            self.count += 1;
        }
        profile.dynamic_unique_table_signatures = self.count;
        if (profile.dynamic_blocks != 0 and self.last == signature) {
            profile.dynamic_consecutive_repeated_table_signatures += 1;
        }
        self.last = signature;
    }
};

fn profileStoredBlockAfterHeader(reader: *bitstream.BufferedBitReader, profile: *DynamicDecodeProfile) Error!void {
    reader.alignToByte();
    const len = try reader.readAlignedInt(u16, .little);
    const nlen = try reader.readAlignedInt(u16, .little);
    if (nlen != ~len) return error.StoredLengthMismatch;
    var scratch: [256]u8 = undefined;
    var remaining: usize = len;
    while (remaining != 0) {
        const n = @min(remaining, scratch.len);
        try reader.readAlignedBytes(scratch[0..n]);
        remaining -= n;
    }
    profile.stored_blocks += 1;
    profile.output_bytes += len;
}

fn profileFixedBlockAfterHeader(reader: *bitstream.BufferedBitReader, profile: *DynamicDecodeProfile) Error!void {
    profile.fixed_blocks += 1;
    while (true) {
        const symbol = try huffman.decodeFixedLiteralValueFast(reader);
        if (symbol < 256) {
            profile.literal_symbols += 1;
            profile.output_bytes += 1;
            profile.mix +%= symbol;
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            profile.length_symbols += 1;
            profile.length_symbol_histogram[symbol - 257] += 1;
            profile.length_code_bits += fixedLiteralCodeBits(symbol);
            const length_extra_reads_before = profile.length_extra_reads;
            const length_extra_bits_before = profile.length_extra_bits;
            const length = try profileDecodeLength(symbol, reader, profile);
            const distance_symbol = try huffman.decodeFixedDistanceValueFast(reader);
            profile.distance_symbol_histogram[distance_symbol] += 1;
            const distance_code_bits: usize = 5;
            profile.distance_code_bits += distance_code_bits;
            const distance_extra_reads_before = profile.distance_extra_reads;
            const distance_extra_bits_before = profile.distance_extra_bits;
            const distance = try profileDecodeDistance(distance_symbol, reader, profile);
            profile.distance_symbols += 1;
            try profileRecordMatch(
                length,
                distance,
                profile.length_extra_reads - length_extra_reads_before,
                profile.length_extra_bits - length_extra_bits_before,
                profile.distance_extra_reads - distance_extra_reads_before,
                profile.distance_extra_bits - distance_extra_bits_before,
                distance_code_bits,
                profile,
            );
            profile.mix +%= length;
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn fixedLiteralCodeBits(symbol: u16) u4 {
    if (symbol <= 143) return 8;
    if (symbol <= 255) return 9;
    if (symbol <= 279) return 7;
    return 8;
}

fn profileCompressedBlockInto(
    reader: *bitstream.BufferedBitReader,
    lit_table: huffman.HuffmanTable(286),
    dist_table: huffman.HuffmanTable(30),
    comptime lit_lookup_bits: u4,
    profile: *DynamicDecodeProfile,
) Error!void {
    const lit_decoder = huffman.FastDecoder(286, lit_lookup_bits).init(lit_table);
    const dist_decoder = makeDynamicDistanceDecoder(dist_table);
    const lit_code_bits_by_symbol = codeBitsBySymbol(286, lit_table);
    const dist_code_bits_by_symbol = codeBitsBySymbol(30, dist_table);
    profile.literal_lookup_bits = lit_lookup_bits;
    profile.literal_lookup_covered += lit_decoder.lookupCoverage();
    profile.literal_lookup_size += lit_decoder.lookup.len;
    profile.distance_lookup_covered += dist_decoder.lookupCoverage();
    profile.distance_lookup_size += dist_decoder.lookupSize();
    while (true) {
        const lit_hit = huffmanFastWouldHit(286, lit_lookup_bits, &lit_decoder, reader);
        const symbol = try lit_decoder.decodeValue(reader);
        if (lit_hit) profile.literal_fast_hits += 1 else profile.literal_fast_misses += 1;
        if (symbol < 256) {
            profile.literal_symbols += 1;
            profile.output_bytes += 1;
            profile.mix +%= symbol;
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            profile.length_symbols += 1;
            profile.length_symbol_histogram[symbol - 257] += 1;
            profile.length_code_bits += lit_code_bits_by_symbol[symbol];
            const length_extra_reads_before = profile.length_extra_reads;
            const length_extra_bits_before = profile.length_extra_bits;
            const length = try profileDecodeLength(symbol, reader, profile);
            const dist_hit = dist_decoder.fastWouldHit(reader);
            const distance_symbol = try dist_decoder.decodeValue(reader);
            if (dist_hit) profile.distance_fast_hits += 1 else profile.distance_fast_misses += 1;
            profile.distance_symbol_histogram[distance_symbol] += 1;
            const distance_code_bits = dist_code_bits_by_symbol[distance_symbol];
            profile.distance_code_bits += distance_code_bits;
            const distance_extra_reads_before = profile.distance_extra_reads;
            const distance_extra_bits_before = profile.distance_extra_bits;
            const distance = try profileDecodeDistance(distance_symbol, reader, profile);
            profile.distance_symbols += 1;
            try profileRecordMatch(
                length,
                distance,
                profile.length_extra_reads - length_extra_reads_before,
                profile.length_extra_bits - length_extra_bits_before,
                profile.distance_extra_reads - distance_extra_reads_before,
                profile.distance_extra_bits - distance_extra_bits_before,
                distance_code_bits,
                profile,
            );
            profile.mix +%= length;
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn codeBitsBySymbol(comptime max_symbols: usize, table: huffman.HuffmanTable(max_symbols)) [max_symbols]u4 {
    var bits: [max_symbols]u4 = @splat(0);
    for (table.entries[0..table.len]) |entry| {
        bits[entry.symbol] = entry.bits;
    }
    return bits;
}

fn profileRecordMatch(
    length: usize,
    distance: usize,
    length_extra_reads: usize,
    length_extra_bits: usize,
    distance_extra_reads: usize,
    distance_extra_bits: usize,
    distance_code_bits: usize,
    profile: *DynamicDecodeProfile,
) Error!void {
    if (length == 0 or distance == 0 or distance > profile.output_bytes) return error.InvalidMatch;
    const class: ProfileMatchClass = if (distance == 1) blk: {
        profile.match_rle_count += 1;
        profile.match_rle_bytes += length;
        break :blk .rle;
    } else if (distance <= 4) blk: {
        profile.match_small_distance_count += 1;
        profile.match_small_distance_bytes += length;
        break :blk .small_distance;
    } else if (distance >= length) blk: {
        profile.match_non_overlapping_count += 1;
        profile.match_non_overlapping_bytes += length;
        break :blk .non_overlapping;
    } else blk: {
        profile.match_overlapping_count += 1;
        profile.match_overlapping_bytes += length;
        break :blk .overlapping;
    };
    const class_index = @intFromEnum(class);
    profile.match_class_length_extra_reads[class_index] += length_extra_reads;
    profile.match_class_length_extra_bits[class_index] += length_extra_bits;
    profile.match_class_distance_extra_reads[class_index] += distance_extra_reads;
    profile.match_class_distance_extra_bits[class_index] += distance_extra_bits;
    profile.match_class_distance_code_bits[class_index] += distance_code_bits;
    profile.match_bytes += length;
    profile.output_bytes += length;
}

fn profileDecodeLength(symbol: u16, reader: *bitstream.BufferedBitReader, profile: *DynamicDecodeProfile) Error!usize {
    if (symbol < 257 or symbol > 285) return error.InvalidHuffmanCode;
    if (symbol <= 264) return symbol - 254;
    if (symbol == 285) return 258;
    const entry = length_table[symbol - 257];
    if (entry.extra_bits != 0) {
        profile.length_extra_reads += 1;
        profile.length_extra_bits += entry.extra_bits;
    }
    return entry.base + try reader.readBits(u16, entry.extra_bits);
}

fn profileDecodeDistance(symbol: u16, reader: *bitstream.BufferedBitReader, profile: *DynamicDecodeProfile) Error!usize {
    if (symbol >= distance_table.len) return error.InvalidHuffmanCode;
    if (symbol < 4) return symbol + 1;
    const entry = distance_table[symbol];
    profile.distance_extra_reads += 1;
    profile.distance_extra_bits += entry.extra_bits;
    return entry.base + try reader.readBits(u16, entry.extra_bits);
}

fn huffmanFastWouldHit(
    comptime max_symbols: usize,
    comptime lookup_bits: u4,
    decoder: *const huffman.FastDecoder(max_symbols, lookup_bits),
    reader: *bitstream.BufferedBitReader,
) bool {
    const peek = reader.peekBitsPadded(u16, lookup_bits);
    const entry = decoder.lookup[peek];
    return entry.bits != 0 and reader.hasBits(entry.bits);
}

pub fn decodeRawAutoAllocPartial(allocator: std.mem.Allocator, input: []const u8) !OwnedDecodeResult {
    return decodeRawAutoAllocPartialWithDictionary(allocator, input, "", null);
}

fn decodeRawAutoAllocPartialWithDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, max_output_len: ?usize) !OwnedDecodeResult {
    if (input.len == 0) return error.TruncatedFrame;
    try rejectReservedFirstBlockBeforeAlloc(input);
    if (try decodeRawStoredOnlyAllocMaybe(allocator, input, max_output_len)) |stored| return stored;
    if (dictionary.len == 0) {
        if (try decodeRawAutoSmallIntoAlloc(allocator, input, max_output_len)) |small| return small;
    }

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try reserveInflateOutputHint(allocator, &out, input.len, max_output_len);

    var reader = bitstream.BufferedBitReader.init(input);
    while (true) {
        const header = try readBlockHeader(&reader);
        switch (header.block_type) {
            0 => try decodeStoredBlockFromReader(allocator, &reader, &out, max_output_len),
            1 => try decodeFixedBlockFromReader(allocator, &reader, &out, dictionary, max_output_len),
            2 => {
                const parsed = try huffman.parseDynamicLengthsAfterHeader(header.final, &reader);
                const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
                const dist_decoder = try makeDynamicDistanceDecoderFromLengths(parsed.distance_lengths[0..parsed.header.hdist]);
                const lit_lookup_bits = dynamicLiteralLookupBits(parsed);
                if (lit_lookup_bits == 9) {
                    const lit_decoder = huffman.FastDecoder(286, 9).init(lit_table);
                    try decodeCompressedBlockFromReader(allocator, &reader, &out, dictionary, max_output_len, &lit_decoder, &dist_decoder);
                } else {
                    const lit_decoder = huffman.FastDecoder(286, 11).init(lit_table);
                    try decodeCompressedBlockFromReader(allocator, &reader, &out, dictionary, max_output_len, &lit_decoder, &dist_decoder);
                }
            },
            else => return error.InvalidDeflateBlockType,
        }
        if (header.final) return .{ .bytes = try out.toOwnedSlice(allocator), .input_read = reader.byteOffset() };
    }
}

pub fn parseRawDeflateHeaderInfo(input: []const u8) Error!RawDeflateHeaderInfo {
    if (input.len == 0) return error.TruncatedFrame;
    var reader = bitstream.BitReader.init(input);
    const header = try readBlockHeader(&reader);
    const final = header.final;
    const block_type: RawDeflateBlockType = switch (header.block_type) {
        0 => .stored,
        1 => .fixed,
        2 => .dynamic,
        else => return error.InvalidDeflateBlockType,
    };
    const data_bit_offset = reader.bitPosition();
    const data_byte_offset = reader.byteOffset();
    var stored_len: ?u16 = null;
    var stored_nlen: ?u16 = null;
    var stored_payload_offset: ?usize = null;
    var dynamic_hlit: ?u16 = null;
    var dynamic_hdist: ?u16 = null;
    var dynamic_hclen: ?u8 = null;
    var dynamic_code_length_count: ?u8 = null;
    var dynamic_code_length_lengths: [19]u4 = @splat(0);
    var dynamic_code_length_repeat_prev: ?u16 = null;
    var dynamic_code_length_repeat_zero_short: ?u16 = null;
    var dynamic_code_length_repeat_zero_long: ?u16 = null;
    var dynamic_literal_nonzero: ?u16 = null;
    var dynamic_literal_zero: ?u16 = null;
    var dynamic_literal_max_bits: ?u8 = null;
    var dynamic_literal_length_histogram: [16]u16 = @splat(0);
    var dynamic_distance_nonzero: ?u16 = null;
    var dynamic_distance_zero: ?u16 = null;
    var dynamic_distance_max_bits: ?u8 = null;
    var dynamic_distance_length_histogram: [16]u16 = @splat(0);
    var dynamic_has_eob: ?bool = null;
    var dynamic_lengths_bit_offset: ?usize = null;
    var dynamic_lengths_byte_offset: ?usize = null;
    if (block_type == .stored) {
        reader.alignToByte();
        const offset = reader.byteOffset();
        if (input.len - offset < 4) return error.TruncatedFrame;
        const lengths = try readStoredLengthPairUnchecked(input, offset);
        try reader.skipBits(32);
        stored_len = lengths.len;
        stored_nlen = lengths.nlen;
        stored_payload_offset = offset + 4;
    } else if (block_type == .dynamic) {
        const hlit: u16 = @as(u16, try reader.readBits(u5, 5)) + 257;
        const hdist: u16 = @as(u16, try reader.readBits(u5, 5)) + 1;
        const hclen: u8 = @as(u8, try reader.readBits(u4, 4)) + 4;
        if (hlit > 286 or hdist > 30 or hclen > huffman.code_length_order.len) return error.InvalidDynamicBlockHeader;
        for (huffman.code_length_order[0..hclen]) |symbol| {
            dynamic_code_length_lengths[symbol] = try reader.readBits(u4, 3);
        }
        dynamic_hlit = hlit;
        dynamic_hdist = hdist;
        dynamic_hclen = hclen;
        dynamic_code_length_count = hclen;
        const parsed = try huffman.parseDynamicLengthsBody(.{
            .final = final,
            .hlit = hlit,
            .hdist = hdist,
            .hclen = hclen,
            .code_length_lengths = dynamic_code_length_lengths,
        }, &reader);
        dynamic_code_length_repeat_prev = parsed.code_length_symbol_histogram[16];
        dynamic_code_length_repeat_zero_short = parsed.code_length_symbol_histogram[17];
        dynamic_code_length_repeat_zero_long = parsed.code_length_symbol_histogram[18];
        var lit_nonzero: u16 = 0;
        for (parsed.literal_lengths[0..hlit]) |length| {
            dynamic_literal_length_histogram[length] += 1;
            if (length != 0) lit_nonzero += 1;
        }
        var dist_nonzero: u16 = 0;
        for (parsed.distance_lengths[0..hdist]) |length| {
            dynamic_distance_length_histogram[length] += 1;
            if (length != 0) dist_nonzero += 1;
        }
        dynamic_literal_nonzero = lit_nonzero;
        dynamic_literal_zero = hlit - lit_nonzero;
        dynamic_literal_max_bits = parsed.literal_max_bits;
        dynamic_distance_nonzero = dist_nonzero;
        dynamic_distance_zero = hdist - dist_nonzero;
        dynamic_distance_max_bits = parsed.distance_max_bits;
        dynamic_has_eob = parsed.literal_lengths[256] != 0;
        dynamic_lengths_bit_offset = reader.bitPosition();
        dynamic_lengths_byte_offset = reader.byteOffset();
    }
    const header_bits_consumed = reader.bitPosition();
    const header_bytes_consumed = reader.byteOffset();
    return .{
        .final = final,
        .block_type = block_type,
        .data_bit_offset = data_bit_offset,
        .data_byte_offset = data_byte_offset,
        .header_bits_consumed = header_bits_consumed,
        .header_bytes_consumed = header_bytes_consumed,
        .stored_len = stored_len,
        .stored_nlen = stored_nlen,
        .stored_payload_offset = stored_payload_offset,
        .dynamic_hlit = dynamic_hlit,
        .dynamic_hdist = dynamic_hdist,
        .dynamic_hclen = dynamic_hclen,
        .dynamic_code_length_count = dynamic_code_length_count,
        .dynamic_code_length_lengths = dynamic_code_length_lengths,
        .dynamic_code_length_repeat_prev = dynamic_code_length_repeat_prev,
        .dynamic_code_length_repeat_zero_short = dynamic_code_length_repeat_zero_short,
        .dynamic_code_length_repeat_zero_long = dynamic_code_length_repeat_zero_long,
        .dynamic_literal_nonzero = dynamic_literal_nonzero,
        .dynamic_literal_zero = dynamic_literal_zero,
        .dynamic_literal_max_bits = dynamic_literal_max_bits,
        .dynamic_literal_length_histogram = dynamic_literal_length_histogram,
        .dynamic_distance_nonzero = dynamic_distance_nonzero,
        .dynamic_distance_zero = dynamic_distance_zero,
        .dynamic_distance_max_bits = dynamic_distance_max_bits,
        .dynamic_distance_length_histogram = dynamic_distance_length_histogram,
        .dynamic_has_eob = dynamic_has_eob,
        .dynamic_lengths_bit_offset = dynamic_lengths_bit_offset,
        .dynamic_lengths_byte_offset = dynamic_lengths_byte_offset,
    };
}

pub fn parseRawDeflateHeaderInfoFromChunks(chunks: []const []const u8, compressed_scratch: []u8) Error!RawDeflateHeaderInfo {
    const joined = try joinChunks(chunks, compressed_scratch);
    return parseRawDeflateHeaderInfo(joined);
}

fn decodeRawAutoAppendPartialWithDictionary(
    allocator: std.mem.Allocator,
    input: []const u8,
    dictionary: []const u8,
    out: *std.ArrayList(u8),
    max_output_len: ?usize,
) !DecodeResult {
    if (input.len == 0) return error.TruncatedFrame;
    if (try planRawStoredOnly(input)) |plan| {
        try appendRawStoredOnlyPlanned(allocator, input[0..plan.input_read], out, plan, max_output_len);
        return .{ .input_read = plan.input_read, .output_written = plan.output_len };
    }

    try reserveInflateAppendOutputHint(allocator, out, input.len, max_output_len);

    var reader = bitstream.BufferedBitReader.init(input);
    return decodeRawAutoAppendPartialWithDictionaryFromReader(allocator, &reader, 0, dictionary, out, max_output_len);
}

fn decodeRawAutoAppendPartialWithDictionaryFromReader(
    allocator: std.mem.Allocator,
    reader: anytype,
    raw_base_offset: usize,
    dictionary: []const u8,
    out: *std.ArrayList(u8),
    max_output_len: ?usize,
) !DecodeResult {
    const start_len = out.items.len;
    while (true) {
        const header = try readBlockHeader(reader);
        switch (header.block_type) {
            0 => try decodeStoredBlockFromReader(allocator, reader, out, max_output_len),
            1 => try decodeFixedBlockFromReaderFromBase(allocator, reader, out, dictionary, start_len, max_output_len),
            2 => {
                const parsed = try huffman.parseDynamicLengthsAfterHeader(header.final, reader);
                const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
                const dist_decoder = try makeDynamicDistanceDecoderFromLengths(parsed.distance_lengths[0..parsed.header.hdist]);
                const lit_lookup_bits = dynamicLiteralLookupBits(parsed);
                if (lit_lookup_bits == 9) {
                    const lit_decoder = huffman.FastDecoder(286, 9).init(lit_table);
                    try decodeCompressedBlockFromReaderFromBase(allocator, reader, out, dictionary, start_len, max_output_len, &lit_decoder, &dist_decoder);
                } else {
                    const lit_decoder = huffman.FastDecoder(286, 11).init(lit_table);
                    try decodeCompressedBlockFromReaderFromBase(allocator, reader, out, dictionary, start_len, max_output_len, &lit_decoder, &dist_decoder);
                }
            },
            else => return error.InvalidDeflateBlockType,
        }
        if (header.final) return .{ .input_read = reader.byteOffset() - raw_base_offset, .output_written = out.items.len - start_len };
    }
}

const stack_inflate_alloc_max_input_len = 8 * 1024;
const stack_inflate_alloc_scratch_len = 64 * 1024;
const stack_chunked_zlib_join_tiny_input_len = 4 * 1024;
const stack_chunked_zlib_join_small_input_len = 16 * 1024;
const stack_chunked_zlib_join_max_input_len = 64 * 1024;
const stack_chunked_zlib_tiny_chunk_count = 512;

fn decodeRawAutoSmallIntoAlloc(allocator: std.mem.Allocator, input: []const u8, max_output_len: ?usize) !?OwnedDecodeResult {
    if (input.len > stack_inflate_alloc_max_input_len) return null;

    // Small and medium compressed members dominate wrapper metadata, test
    // loops, and common text/source payloads. Decoding them through the
    // caller-buffer state machine first avoids the ArrayList grow/shrink path
    // used by the general allocating decoder while preserving exact owned-slice
    // semantics for callers. The scratch limit is deliberately bounded: if a
    // compact stream expands beyond this stack buffer, we fall back to the
    // streaming ArrayList path so hostile or unusually large expansions do not
    // keep growing hidden stack usage.
    var scratch: [stack_inflate_alloc_scratch_len]u8 = undefined;
    const decode_buffer = if (max_output_len) |limit| scratch[0..@min(limit, scratch.len)] else scratch[0..];
    const decoded = decodeRawAuto(input, decode_buffer) catch |err| switch (err) {
        error.OutputTooSmall => {
            // When the caller supplied a limit that fits inside the bounded stack
            // scratch, OutputTooSmall means the DEFLATE stream exceeded that
            // public limit. Report the limit violation directly instead of
            // re-decoding through the heap-growing ArrayList path just to discover
            // the same error.
            if (max_output_len) |limit| {
                if (limit <= scratch.len) return error.OutputLimitExceeded;
            }
            return null;
        },
        else => return err,
    };
    try ensureOutputLimit(0, decoded.output_written, max_output_len);
    const owned = allocator.alloc(u8, decoded.output_written) catch return error.OutOfMemory;
    errdefer allocator.free(owned);
    @memcpy(owned, scratch[0..decoded.output_written]);
    return .{ .bytes = owned, .input_read = decoded.input_read };
}

pub fn decodeRawAutoAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    _ = try planRawStoredOnlyForFullInput(input);
    const result = try decodeRawAutoAllocPartial(allocator, input);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

pub fn decodeRawAutoAllocWithDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8) ![]u8 {
    _ = try planRawStoredOnlyForFullInput(input);
    const result = try decodeRawAutoAllocPartialWithDictionary(allocator, input, dictionary, null);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

pub fn decodeRawAutoAllocExactSize(allocator: std.mem.Allocator, input: []const u8, expected_output_len: usize) ![]u8 {
    return decodeRawAutoAllocWithDictionaryExactSize(allocator, input, "", expected_output_len);
}

pub fn decodeRawAutoAllocWithDictionaryExactSize(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, expected_output_len: usize) ![]u8 {
    if (input.len == 0) return error.TruncatedFrame;
    if (isStoredBlockHeaderByte(input[0])) {
        if (try planRawStoredOnly(input)) |stored_plan| {
            if (expected_output_len < stored_plan.output_len) return error.SizeMismatch;
            if (stored_plan.input_read != input.len) return error.TrailingData;
            if (expected_output_len != stored_plan.output_len) return error.SizeMismatch;
        }
    }
    try rejectReservedFirstBlockBeforeAlloc(input);
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
    if (try planRawStoredOnlyForFullInput(input)) |stored_plan| {
        try ensureOutputLimit(0, stored_plan.output_len, max_output_len);
    }
    const result = try decodeRawAutoAllocPartialWithDictionary(allocator, input, "", max_output_len);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

pub fn decodeRawAutoAllocWithDictionaryLimited(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, max_output_len: usize) ![]u8 {
    if (try planRawStoredOnlyForFullInput(input)) |stored_plan| {
        try ensureOutputLimit(0, stored_plan.output_len, max_output_len);
    }
    const result = try decodeRawAutoAllocPartialWithDictionary(allocator, input, dictionary, max_output_len);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

pub fn decodeRawChunksAlloc(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8) ![]u8 {
    return decodeRawChunksAllocWithOptionalDictionaryLimited(allocator, chunks, compressed_scratch, "", null);
}

pub fn decodeRawChunksAllocWithDictionary(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary: []const u8) ![]u8 {
    return decodeRawChunksAllocWithOptionalDictionaryLimited(allocator, chunks, compressed_scratch, dictionary, null);
}

pub fn decodeRawChunksAllocExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) ![]u8 {
    return decodeRawChunksAllocWithDictionaryExactSize(allocator, chunks, compressed_scratch, "", expected_output_len);
}

pub fn decodeRawChunksAllocWithDictionaryExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary: []const u8, expected_output_len: usize) ![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return decodeRawAutoAllocWithDictionaryExactSize(allocator, joined, dictionary, expected_output_len);
}

pub fn decodeRawChunksAllocLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) ![]u8 {
    return decodeRawChunksAllocWithOptionalDictionaryLimited(allocator, chunks, compressed_scratch, "", max_output_len);
}

pub fn decodeRawChunksAllocWithDictionaryLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary: []const u8, max_output_len: usize) ![]u8 {
    return decodeRawChunksAllocWithOptionalDictionaryLimited(allocator, chunks, compressed_scratch, dictionary, max_output_len);
}

fn decodeRawChunksAllocWithOptionalDictionaryLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary: []const u8, max_output_len: ?usize) ![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    if (max_output_len) |limit| return decodeRawAutoAllocWithDictionaryLimited(allocator, joined, dictionary, limit);
    return decodeRawAutoAllocWithDictionary(allocator, joined, dictionary);
}

fn planRawStoredOnlyForFullInput(input: []const u8) Error!?StoredOnlyPlan {
    if (input.len == 0 or !isStoredBlockHeaderByte(input[0])) return null;
    const stored_plan = (try planRawStoredOnly(input)) orelse return null;
    if (stored_plan.input_read != input.len) return error.TrailingData;
    return stored_plan;
}

pub fn decodeRawAuto(input: []const u8, output: []u8) Error!DecodeResult {
    return decodeRawAutoWithDictionary(input, "", output);
}

pub fn decodeRawAutoWithDictionary(input: []const u8, dictionary: []const u8, output: []u8) Error!DecodeResult {
    if (input.len == 0) return error.TruncatedFrame;
    if (try decodeRawStoredOnlyIntoMaybe(input, output)) |stored| return stored;

    var reader = bitstream.BufferedBitReader.init(input);
    return decodeRawAutoWithDictionaryFromReader(&reader, 0, dictionary, output);
}

pub fn decodeRawChunks(chunks: []const []const u8, compressed_scratch: []u8, output: []u8) Error!DecodeResult {
    return decodeRawChunksWithDictionary(chunks, compressed_scratch, output, "");
}

pub fn decodeRawChunksWithDictionary(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: []const u8) Error!DecodeResult {
    const joined = try joinChunks(chunks, compressed_scratch);
    return decodeRawAutoWithDictionary(joined, dictionary, output);
}

fn decodeRawAutoWithDictionaryFromReader(reader: anytype, raw_base_offset: usize, dictionary: []const u8, output: []u8) Error!DecodeResult {
    const Reader = switch (@typeInfo(@TypeOf(reader))) {
        .pointer => |pointer| pointer.child,
        else => @TypeOf(reader),
    };
    var out_offset: usize = 0;
    while (true) {
        const header = try readBlockHeader(reader);
        switch (header.block_type) {
            0 => try decodeStoredBlockIntoReader(reader, output, &out_offset),
            1 => try decodeFixedBlockIntoReader(reader, output, &out_offset, dictionary),
            2 => {
                const parsed = try huffman.parseDynamicLengthsAfterHeader(header.final, reader);
                const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
                const dist_decoder = try makeDynamicDistanceDecoderFromLengths(parsed.distance_lengths[0..parsed.header.hdist]);
                const lit_lookup_bits = dynamicLiteralLookupBits(parsed);
                if (lit_lookup_bits == 9) {
                    const lit_decoder = huffman.FastDecoder(286, 9).init(lit_table);
                    try decodeCompressedBlockIntoReader(reader, output, &out_offset, dictionary, &lit_decoder, &dist_decoder);
                } else if (comptime Reader == bitstream.BufferedBitReader) {
                    if (dictionary.len == 0 and !slicesOverlapForSemanticDecode(reader.input, output)) {
                        const semantic_dist_table = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
                        var semantic_decoder: SemanticDynamicDecoder = undefined;
                        if (semantic_decoder.init(&lit_table, &semantic_dist_table)) {
                            out_offset = try decodeSemanticDynamicBlockIntoBufferedReader(reader, output, out_offset, &semantic_decoder);
                        } else {
                            const lit_decoder = FusedDynamicLiteralDecoder.init(&lit_table);
                            try decodeFusedDynamicBlockIntoBufferedReader(reader, output, &out_offset, &lit_decoder, &dist_decoder);
                        }
                    } else {
                        const lit_decoder = huffman.FastDecoder(286, 11).init(lit_table);
                        try decodeCompressedBlockIntoReader(reader, output, &out_offset, dictionary, &lit_decoder, &dist_decoder);
                    }
                } else {
                    const lit_decoder = huffman.FastDecoder(286, 11).init(lit_table);
                    try decodeCompressedBlockIntoReader(reader, output, &out_offset, dictionary, &lit_decoder, &dist_decoder);
                }
            },
            else => return error.InvalidDeflateBlockType,
        }
        if (header.final) return .{ .input_read = reader.byteOffset() - raw_base_offset, .output_written = out_offset };
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
    return (try decodeRawStoredOnlyIntoMaybe(input, output)) orelse error.InvalidDeflateBlockType;
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
    return try decodeRawStoredOnlyAllocPlanned(allocator, input, plan, max_output_len);
}

fn decodeRawStoredOnlyAllocPlanned(allocator: std.mem.Allocator, input: []const u8, plan: StoredOnlyPlan, max_output_len: ?usize) !OwnedDecodeResult {
    try ensureOutputLimit(0, plan.output_len, max_output_len);
    const out = try allocator.alloc(u8, plan.output_len);
    errdefer allocator.free(out);
    copyRawStoredOnly(input[0..plan.input_read], out);
    return .{ .bytes = out, .input_read = plan.input_read };
}

fn decodeRawStoredOnlyIntoMaybe(input: []const u8, output: []u8) Error!?DecodeResult {
    if (input.len == 0) return error.TruncatedFrame;
    var in_offset: usize = 0;
    var out_offset: usize = 0;
    while (true) {
        if (input.len - in_offset < 1) return error.TruncatedFrame;
        const header = input[in_offset];
        if (!isStoredBlockHeaderByte(header)) return null;
        const final = (header & 0x01) != 0;
        in_offset += 1;

        if (input.len - in_offset < 4) return error.TruncatedFrame;
        const lengths = try readStoredLengthPairUnchecked(input, in_offset);
        in_offset += 4;

        const chunk_len: usize = lengths.len;
        if (input.len - in_offset < chunk_len) return error.TruncatedFrame;
        if (output.len - out_offset < chunk_len) return error.OutputTooSmall;
        @memcpy(output[out_offset..][0..chunk_len], input[in_offset..][0..chunk_len]);
        out_offset += chunk_len;
        in_offset += chunk_len;
        if (final) return .{ .input_read = in_offset, .output_written = out_offset };
    }
}

fn decodeRawStoredOnlyIntoMaybeWithHash(comptime Hash: type, input: []const u8, output: []u8) Error!?struct { result: DecodeResult, digest: u32 } {
    if (input.len == 0) return error.TruncatedFrame;
    var in_offset: usize = 0;
    var out_offset: usize = 0;
    var hash = Hash.init();
    while (true) {
        if (input.len - in_offset < 1) return error.TruncatedFrame;
        const header = input[in_offset];
        if (!isStoredBlockHeaderByte(header)) return null;
        const final = (header & 0x01) != 0;
        in_offset += 1;

        if (input.len - in_offset < 4) return error.TruncatedFrame;
        const lengths = try readStoredLengthPairUnchecked(input, in_offset);
        in_offset += 4;

        const chunk_len: usize = lengths.len;
        if (input.len - in_offset < chunk_len) return error.TruncatedFrame;
        if (output.len - out_offset < chunk_len) return error.OutputTooSmall;
        const source = input[in_offset..][0..chunk_len];
        @memcpy(output[out_offset..][0..chunk_len], source);
        hash.update(source);
        out_offset += chunk_len;
        in_offset += chunk_len;
        if (final) {
            return .{
                .result = .{ .input_read = in_offset, .output_written = out_offset },
                .digest = hash.digest(),
            };
        }
    }
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

fn hashRawStoredOnlyPlanned(comptime Hash: type, input: []const u8, plan: StoredOnlyPlan) u32 {
    var hash = Hash.init();
    var in_offset: usize = 0;
    while (true) {
        const final = (input[in_offset] & 0x01) != 0;
        in_offset += 1;
        const len = std.mem.readInt(u16, input[in_offset..][0..2], .little);
        const chunk_len: usize = len;
        in_offset += 4;
        const chunk = input[in_offset..][0..chunk_len];
        hash.update(chunk);
        in_offset += chunk_len;
        if (final) {
            std.debug.assert(in_offset == plan.input_read);
            return hash.digest();
        }
    }
}

fn planRawStoredOnly(input: []const u8) Error!?StoredOnlyPlan {
    if (input.len == 0) return error.TruncatedFrame;
    var offset: usize = 0;
    var output_len: usize = 0;
    while (true) {
        if (input.len - offset < 1) return error.TruncatedFrame;
        const header = input[offset];
        if (!isStoredBlockHeaderByte(header)) return null;
        const final = (header & 0x01) != 0;

        // Stored-block payloads start on the next byte boundary. Bits 3..7 of
        // the header byte are padding and intentionally ignored, matching zlib
        // and the existing BitReader-based stored decoder.
        offset += 1;
        if (input.len - offset < 4) return error.TruncatedFrame;
        const lengths = try readStoredLengthPairUnchecked(input, offset);
        offset += 4;

        const chunk_len: usize = lengths.len;
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

fn appendRawStoredOnlyPlannedWithHash(comptime Hash: type, allocator: std.mem.Allocator, input: []const u8, out: *std.ArrayList(u8), plan: StoredOnlyPlan, max_output_len: ?usize) !u32 {
    try ensureOutputLimit(out.items.len, plan.output_len, max_output_len);
    try out.ensureUnusedCapacity(allocator, plan.output_len);

    var hash = Hash.init();
    var in_offset: usize = 0;
    while (true) {
        const final = (input[in_offset] & 0x01) != 0;
        in_offset += 1;
        const len = std.mem.readInt(u16, input[in_offset..][0..2], .little);
        const chunk_len: usize = len;
        in_offset += 4;
        const chunk = input[in_offset..][0..chunk_len];
        // Concatenated zlib/gzip members validate each member independently.
        // Hashing while appending keeps stored-only members to one payload pass
        // instead of appending first and re-reading the same bytes for the
        // trailer checksum.
        out.appendSliceAssumeCapacity(chunk);
        hash.update(chunk);
        in_offset += chunk_len;
        if (final) {
            std.debug.assert(in_offset == plan.input_read);
            return hash.digest();
        }
    }
}

pub fn decodeRawStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const plan = (try planRawStoredOnly(input)) orelse return error.InvalidDeflateBlockType;
    if (plan.input_read != input.len) return error.TrailingData;
    return (try decodeRawStoredOnlyAllocPlanned(allocator, input, plan, null)).bytes;
}

pub fn decodeRawStoredAllocExactSize(allocator: std.mem.Allocator, input: []const u8, expected_output_len: usize) ![]u8 {
    const plan = (try planRawStoredOnly(input)) orelse return error.InvalidDeflateBlockType;
    if (expected_output_len < plan.output_len) return error.SizeMismatch;
    if (plan.input_read != input.len) return error.TrailingData;
    if (expected_output_len != plan.output_len) return error.SizeMismatch;
    return (try decodeRawStoredOnlyAllocPlanned(allocator, input, plan, null)).bytes;
}

pub fn decodeRawStoredAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    const plan = (try planRawStoredOnly(input)) orelse return error.InvalidDeflateBlockType;
    try ensureOutputLimit(0, plan.output_len, max_output_len);
    if (plan.input_read != input.len) return error.TrailingData;
    return (try decodeRawStoredOnlyAllocPlanned(allocator, input, plan, max_output_len)).bytes;
}

fn decodeStoredBlockFromReader(allocator: std.mem.Allocator, reader: anytype, out: *std.ArrayList(u8), max_output_len: ?usize) !void {
    reader.alignToByte();
    const len = try reader.readAlignedInt(u16, .little);
    const nlen = try reader.readAlignedInt(u16, .little);
    if (nlen != ~len) return error.StoredLengthMismatch;
    const chunk_len: usize = len;
    try ensureOutputLimit(out.items.len, chunk_len, max_output_len);
    const dest = try out.addManyAsSlice(allocator, chunk_len);
    try reader.readAlignedBytes(dest);
}

fn decodeStoredBlockIntoReader(reader: anytype, output: []u8, out_offset: *usize) Error!void {
    reader.alignToByte();
    const len = try reader.readAlignedInt(u16, .little);
    const nlen = try reader.readAlignedInt(u16, .little);
    if (nlen != ~len) return error.StoredLengthMismatch;
    const chunk_len: usize = len;
    if (output.len - out_offset.* < chunk_len) return error.OutputTooSmall;
    try reader.readAlignedBytes(output[out_offset.*..][0..chunk_len]);
    out_offset.* += chunk_len;
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
    // Tiny DEFLATE frames dominate CLI/API smoke paths and benchmark loops.
    // Reserving 64x for a 20-byte dynamic frame over-allocates and then asks
    // `toOwnedSlice` to shrink the buffer. Use a smaller floor for tiny inputs
    // while retaining the larger capped expansion hint for real compressed
    // payloads where repeated reallocations are much more expensive.
    if (input_len <= 64) return input_len *| 8;
    return @min(input_len *| 64, 1 << 20);
}

fn decodeFixedBlockFromReader(allocator: std.mem.Allocator, reader: anytype, out: *std.ArrayList(u8), dictionary: []const u8, max_output_len: ?usize) !void {
    try decodeFixedBlockFromReaderFromBase(allocator, reader, out, dictionary, 0, max_output_len);
}

fn decodeFixedBlockFromReaderFromBase(allocator: std.mem.Allocator, reader: anytype, out: *std.ArrayList(u8), dictionary: []const u8, history_start: usize, max_output_len: ?usize) !void {
    while (true) {
        const symbol = try huffman.decodeFixedLiteralValueFast(reader);
        if (symbol < 256) {
            try ensureOutputLimit(out.items.len, 1, max_output_len);
            try out.append(allocator, @intCast(symbol));
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = try huffman.decodeFixedDistanceValueFast(reader);
            const distance = try decodeDistance(distance_symbol, reader);
            try appendMatchWithDictionaryFromBase(allocator, out, dictionary, history_start, length, distance, max_output_len);
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn decodeFixedBlockIntoReader(reader: anytype, output: []u8, out_offset: *usize, dictionary: []const u8) Error!void {
    // Most caller-buffer decodes are ordinary raw/zlib/gzip streams without a
    // preset dictionary. Keep that hot path monomorphic so every match can go
    // straight through `copyMatch` instead of rechecking dictionary boundaries.
    if (dictionary.len == 0) return decodeFixedBlockIntoReaderNoDict(reader, output, out_offset);
    while (true) {
        const symbol = try huffman.decodeFixedLiteralValueFast(reader);
        if (symbol < 256) {
            if (out_offset.* == output.len) return error.OutputTooSmall;
            output[out_offset.*] = @intCast(symbol);
            out_offset.* += 1;
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = try huffman.decodeFixedDistanceValueFast(reader);
            const distance = try decodeDistance(distance_symbol, reader);
            try copyMatchWithDictionary(output[0..out_offset.*], dictionary, output[out_offset.*..], length, distance);
            out_offset.* += length;
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn decodeFixedBlockIntoReaderNoDict(reader: anytype, output: []u8, out_offset: *usize) Error!void {
    while (true) {
        const symbol = try huffman.decodeFixedLiteralValueFast(reader);
        if (symbol < 256) {
            if (out_offset.* == output.len) return error.OutputTooSmall;
            output[out_offset.*] = @intCast(symbol);
            out_offset.* += 1;
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = try huffman.decodeFixedDistanceValueFast(reader);
            const distance = try decodeDistance(distance_symbol, reader);
            try copyMatchAt(output, out_offset.*, length, distance);
            out_offset.* += length;
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn decodeCompressedBlockFromReader(
    allocator: std.mem.Allocator,
    reader: anytype,
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
    reader: anytype,
    out: *std.ArrayList(u8),
    dictionary: []const u8,
    history_start: usize,
    max_output_len: ?usize,
    lit_table: anytype,
    dist_table: anytype,
) !void {
    while (true) {
        const symbol = try lit_table.decodeValue(reader);
        if (symbol < 256) {
            try ensureOutputLimit(out.items.len, 1, max_output_len);
            try out.append(allocator, @intCast(symbol));
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = try dist_table.decodeValue(reader);
            const distance = try decodeDistance(distance_symbol, reader);
            try appendMatchWithDictionaryFromBase(allocator, out, dictionary, history_start, length, distance, max_output_len);
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn decodeCompressedBlockIntoReader(
    reader: anytype,
    output: []u8,
    out_offset: *usize,
    dictionary: []const u8,
    lit_table: anytype,
    dist_table: anytype,
) Error!void {
    // Dynamic blocks dominate real-world PNG/source/text payloads. Splitting
    // the no-dictionary case avoids a per-match dictionary branch in the tight
    // caller-buffer inflate loop while leaving preset-dictionary semantics in
    // the generic path below.
    if (dictionary.len == 0) return decodeCompressedBlockIntoReaderNoDict(reader, output, out_offset, lit_table, dist_table);
    while (true) {
        const symbol = try lit_table.decodeValue(reader);
        if (symbol < 256) {
            if (out_offset.* == output.len) return error.OutputTooSmall;
            output[out_offset.*] = @intCast(symbol);
            out_offset.* += 1;
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = try dist_table.decodeValue(reader);
            const distance = try decodeDistance(distance_symbol, reader);
            try copyMatchWithDictionary(output[0..out_offset.*], dictionary, output[out_offset.*..], length, distance);
            out_offset.* += length;
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn slicesOverlapForSemanticDecode(input: []const u8, output: []u8) bool {
    if (input.len == 0 or output.len == 0) return false;
    const input_start = @intFromPtr(input.ptr);
    const output_start = @intFromPtr(output.ptr);
    const input_end = input_start +| input.len;
    const output_end = output_start +| output.len;
    return input_start < output_end and output_start < input_end;
}

const LinearSemanticSink = struct {
    output: []u8,
    pos: usize,

    inline fn hasHeadroom(self: *const LinearSemanticSink, count: usize) bool {
        return self.pos <= self.output.len and self.output.len - self.pos >= count;
    }

    inline fn emitSemanticLiteral(self: *LinearSemanticSink, entry: u32) Error!void {
        const advance: usize = @intCast((entry >> 8) & 0xf);
        std.debug.assert(advance == 1 or advance == 2);
        std.debug.assert(self.output.len - self.pos >= 2);
        self.output[self.pos] = @truncate(entry >> 16);
        self.output[self.pos + 1] = @truncate(entry >> 24);
        self.pos += advance;
    }

    inline fn emitSemanticLiteralTriple(self: *LinearSemanticSink, first: u32, second: u32, third: u32) Error!void {
        const first_advance: usize = @intCast((first >> 8) & 0xf);
        const second_advance: usize = @intCast((second >> 8) & 0xf);
        const third_advance: usize = @intCast((third >> 8) & 0xf);
        const second_offset = first_advance;
        const third_offset = first_advance + second_advance;
        const advance = third_offset + third_advance;
        std.debug.assert(self.output.len - self.pos >= 6);

        // Store the speculative second lane of every semantic entry just as
        // the original dedicated linear loop did. Later entries overwrite
        // those lanes when an entry contains one literal; six bytes of output
        // headroom keeps all stores in bounds while retiring the three cursor
        // advances as one dependency.
        self.output[self.pos] = @truncate(first >> 16);
        self.output[self.pos + 1] = @truncate(first >> 24);
        self.output[self.pos + second_offset] = @truncate(second >> 16);
        self.output[self.pos + second_offset + 1] = @truncate(second >> 24);
        self.output[self.pos + third_offset] = @truncate(third >> 16);
        self.output[self.pos + third_offset + 1] = @truncate(third >> 24);
        self.pos += advance;
    }

    inline fn emitByte(self: *LinearSemanticSink, byte: u8) Error!void {
        if (self.pos == self.output.len) return error.OutputTooSmall;
        self.output[self.pos] = byte;
        self.pos += 1;
    }

    inline fn copyMatch(self: *LinearSemanticSink, length: usize, distance: usize) Error!void {
        try copyMatchAt(self.output, self.pos, length, distance);
        self.pos += length;
    }
};

/// DEFLATE sink for a non-interlaced PNG whose scanline filters are all None.
///
/// DEFLATE distances are expressed in the inflated stream's coordinate space,
/// which includes one filter byte before every row. The final image buffer does
/// not contain those bytes, so this sink preserves a virtual output position and
/// treats row-leading zeroes as implicit history. Common RLE, small-distance,
/// and non-overlapping matches remain batched; only uncommon overlapping spans
/// that cross a row boundary fall back to byte-wise virtual-history replay.
const PngFilter0SemanticSink = struct {
    output: []u8,
    row_len: usize,
    stride: usize,
    expected_virtual_len: usize,
    virtual_pos: usize = 0,
    output_pos: usize = 0,
    row_remaining: usize = 0,

    fn init(output: []u8, info: PngImageInfo) Error!PngFilter0SemanticSink {
        const output_len = try pngImageOutputLen(info);
        if (output.len < output_len) return error.OutputTooSmall;
        return .{
            .output = output[0..output_len],
            .row_len = info.row_len,
            .stride = std.math.add(usize, info.row_len, 1) catch return error.IntegerOverflow,
            .expected_virtual_len = info.zlib_payload_len,
        };
    }

    inline fn hasHeadroom(self: *const PngFilter0SemanticSink, count: usize) bool {
        return self.virtual_pos <= self.expected_virtual_len and
            self.expected_virtual_len - self.virtual_pos >= count;
    }

    inline fn emitSemanticLiteral(self: *PngFilter0SemanticSink, entry: u32) Error!void {
        const advance: usize = @intCast((entry >> 8) & 0xf);
        std.debug.assert(advance == 1 or advance == 2);
        const first: u8 = @truncate(entry >> 16);
        if (advance == 1) return self.emitByte(first);

        const second: u8 = @truncate(entry >> 24);
        if (self.row_remaining >= 2) {
            self.output[self.output_pos] = first;
            self.output[self.output_pos + 1] = second;
            self.output_pos += 2;
            self.virtual_pos += 2;
            self.row_remaining -= 2;
            return;
        }
        try self.emitByte(first);
        try self.emitByte(second);
    }

    inline fn emitSemanticLiteralTriple(self: *PngFilter0SemanticSink, first: u32, second: u32, third: u32) Error!void {
        if (self.row_remaining >= 6) {
            const first_advance: usize = @intCast((first >> 8) & 0xf);
            const second_advance: usize = @intCast((second >> 8) & 0xf);
            const third_advance: usize = @intCast((third >> 8) & 0xf);
            const second_offset = first_advance;
            const third_offset = first_advance + second_advance;
            const advance = third_offset + third_advance;

            // Like the linear semantic loop, each entry stores two lanes even
            // when it represents one literal. The following entry overwrites
            // that harmless speculative lane, and six bytes of row headroom
            // keeps every store inside the current scanline.
            self.output[self.output_pos] = @truncate(first >> 16);
            self.output[self.output_pos + 1] = @truncate(first >> 24);
            self.output[self.output_pos + second_offset] = @truncate(second >> 16);
            self.output[self.output_pos + second_offset + 1] = @truncate(second >> 24);
            self.output[self.output_pos + third_offset] = @truncate(third >> 16);
            self.output[self.output_pos + third_offset + 1] = @truncate(third >> 24);
            self.advanceRowData(advance);
            return;
        }

        try self.emitSemanticLiteral(first);
        try self.emitSemanticLiteral(second);
        try self.emitSemanticLiteral(third);
    }

    inline fn emitByte(self: *PngFilter0SemanticSink, byte: u8) Error!void {
        if (self.virtual_pos == self.expected_virtual_len) return error.OutputTooSmall;
        if (self.row_remaining == 0) {
            // A nonzero row filter means this specialization is not applicable.
            // The caller can restart through the general reconstruction path.
            if (byte != @intFromEnum(PngFilterMethod.none)) return error.UnsupportedDeflateFeature;
            self.row_remaining = self.row_len;
            self.virtual_pos += 1;
            return;
        }
        if (self.output_pos == self.output.len) return error.OutputTooSmall;
        self.output[self.output_pos] = byte;
        self.output_pos += 1;
        self.virtual_pos += 1;
        self.row_remaining -= 1;
    }

    fn copyMatch(self: *PngFilter0SemanticSink, length: usize, distance: usize) Error!void {
        if (length == 0 or distance == 0 or distance > self.virtual_pos) return error.InvalidMatch;
        if (length > self.expected_virtual_len - self.virtual_pos) return error.OutputTooSmall;
        if (distance == 1) return self.copyRleMatch(length);
        if (distance <= 4) return self.copySmallDistanceMatchVirtual(length, distance);
        if (distance >= length) return self.copyNonOverlappingMatch(length, distance);

        // Uncommon overlapping matches can observe both compact output bytes
        // and implicit row-filter zeroes. Replaying from the virtual coordinate
        // space is the simple reference fallback and is bounded by DEFLATE's
        // maximum match length of 258 bytes.
        var remaining = length;
        while (remaining != 0) : (remaining -= 1) {
            try self.emitByte(self.virtualByteAt(self.virtual_pos - distance));
        }
    }

    fn copyRleMatch(self: *PngFilter0SemanticSink, length: usize) Error!void {
        var byte = self.virtualByteAt(self.virtual_pos - 1);
        var remaining = length;
        while (remaining != 0) {
            if (self.row_remaining == 0) {
                try self.emitByte(byte);
                // The just-emitted virtual byte is a validated filter zero and
                // therefore becomes the distance-one source for the next byte.
                byte = 0;
                remaining -= 1;
                continue;
            }
            const count = @min(remaining, self.row_remaining);
            @memset(self.output[self.output_pos..][0..count], byte);
            self.advanceRowData(count);
            remaining -= count;
        }
    }

    fn copySmallDistanceMatchVirtual(self: *PngFilter0SemanticSink, length: usize, distance: usize) Error!void {
        var pattern: [4]u8 = undefined;
        for (0..distance) |i| {
            pattern[i] = self.virtualByteAt(self.virtual_pos - distance + i);
        }

        var remaining = length;
        var phase: usize = 0;
        while (remaining != 0) {
            if (self.row_remaining == 0) {
                try self.emitByte(pattern[phase]);
                phase = (phase + 1) % distance;
                remaining -= 1;
                continue;
            }

            const count = @min(remaining, self.row_remaining);
            var rotated: [4]u8 = undefined;
            for (0..distance) |i| rotated[i] = pattern[(phase + i) % distance];
            copySmallDistanceMatch(
                self.output[self.output_pos..][0..count],
                rotated[0..distance],
                distance,
            );
            self.advanceRowData(count);
            phase = (phase + count) % distance;
            remaining -= count;
        }
    }

    fn copyNonOverlappingMatch(self: *PngFilter0SemanticSink, length: usize, distance: usize) Error!void {
        var remaining = length;
        while (remaining != 0) {
            const source_virtual = self.virtual_pos - distance;
            const source_column = source_virtual % self.stride;

            if (self.row_remaining == 0 or source_column == 0) {
                try self.emitByte(self.virtualByteAt(source_virtual));
                remaining -= 1;
                continue;
            }

            const source_until_filter = self.stride - source_column;
            const count = @min(remaining, @min(self.row_remaining, source_until_filter));
            const source_output = self.compactIndexForData(source_virtual);
            @memcpy(
                self.output[self.output_pos..][0..count],
                self.output[source_output..][0..count],
            );
            self.advanceRowData(count);
            remaining -= count;
        }
    }

    inline fn advanceRowData(self: *PngFilter0SemanticSink, count: usize) void {
        std.debug.assert(count <= self.row_remaining);
        std.debug.assert(count <= self.output.len - self.output_pos);
        self.output_pos += count;
        self.virtual_pos += count;
        self.row_remaining -= count;
    }

    inline fn virtualByteAt(self: *const PngFilter0SemanticSink, virtual_index: usize) u8 {
        std.debug.assert(virtual_index < self.virtual_pos);
        if (virtual_index % self.stride == 0) return 0;
        return self.output[self.compactIndexForData(virtual_index)];
    }

    inline fn compactIndexForData(self: *const PngFilter0SemanticSink, virtual_index: usize) usize {
        const row = virtual_index / self.stride;
        const column = virtual_index - row * self.stride;
        std.debug.assert(column != 0);
        return row * self.row_len + column - 1;
    }

    fn finish(self: *const PngFilter0SemanticSink) Error!void {
        if (self.virtual_pos != self.expected_virtual_len or
            self.output_pos != self.output.len or
            self.row_remaining != 0)
        {
            return error.SizeMismatch;
        }
    }
};

noinline fn decodeSemanticDynamicBlockIntoBufferedReader(
    noalias reader: *bitstream.BufferedBitReader,
    noalias output: []u8,
    initial_out_offset: usize,
    noalias decoder: *const SemanticDynamicDecoder,
) Error!usize {
    return decodeSemanticDynamicBlockIntoLinearMode(
        false,
        false,
        reader,
        output,
        initial_out_offset,
        decoder,
    );
}

noinline fn decodeSemanticDynamicBlockIntoSingleDistanceBufferedReader(
    noalias reader: *bitstream.BufferedBitReader,
    noalias output: []u8,
    noalias decoder: *const SemanticDynamicDecoder,
) Error!usize {
    return decodeSemanticDynamicBlockIntoLinearMode(
        true,
        false,
        reader,
        output,
        0,
        decoder,
    );
}

noinline fn decodeSemanticDynamicBlockIntoRle1BufferedReader(
    noalias reader: *bitstream.BufferedBitReader,
    noalias output: []u8,
    noalias decoder: *const SemanticDynamicDecoder,
) Error!usize {
    return decodeSemanticDynamicBlockIntoLinearMode(
        true,
        true,
        reader,
        output,
        0,
        decoder,
    );
}

noinline fn decodeSemanticDynamicBlockIntoLinearMode(
    comptime single_distance: bool,
    comptime rle1_distance: bool,
    noalias reader: *bitstream.BufferedBitReader,
    noalias output: []u8,
    initial_out_offset: usize,
    noalias decoder: *const SemanticDynamicDecoder,
) Error!usize {
    comptime std.debug.assert(!rle1_distance or single_distance);
    const input = reader.input;
    var bit_buffer = reader.bit_buffer;
    var bit_count = reader.bit_count;
    var byte_index = reader.byte_index;
    var consumed_bits = reader.consumed_bits;
    var out_pos = initial_out_offset;

    const output_headroom: usize = 64;
    if (out_pos + output_headroom <= output.len and byte_index + 8 <= input.len) {
        refillSemanticBits(input, &byte_index, &bit_buffer, &bit_count);
    }
    var entry = decoder.literal[@intCast(bit_buffer & SemanticDynamicDecoder.literal_lookup_mask)];

    while (out_pos + output_headroom <= output.len and byte_index + 8 <= input.len) {
        var entry_bits: u6 = @truncate(entry);

        if ((entry & SemanticDynamicDecoder.literal_flag) != 0) {
            const entry2 = decoder.literal[
                @as(usize, @intCast((bit_buffer >> @intCast(entry_bits)) & SemanticDynamicDecoder.literal_lookup_mask))
            ];
            const entry2_bits: u6 = @truncate(entry2);
            const entry12_bits: u6 = entry_bits + entry2_bits;
            const entry3 = decoder.literal[
                @as(usize, @intCast((bit_buffer >> @intCast(entry12_bits)) & SemanticDynamicDecoder.literal_lookup_mask))
            ];
            const entry3_bits: u6 = @truncate(entry3);
            const entry123_bits: u6 = entry12_bits + entry3_bits;
            const entry4 = decoder.literal[
                @as(usize, @intCast((bit_buffer >> @intCast(entry123_bits)) & SemanticDynamicDecoder.literal_lookup_mask))
            ];

            const advance1: usize = @intCast((entry >> 8) & 0xf);
            output[out_pos] = @truncate(entry >> 16);
            output[out_pos + 1] = @truncate(entry >> 24);
            out_pos += advance1;

            if ((entry2 & SemanticDynamicDecoder.literal_flag) != 0) {
                const advance2: usize = @intCast((entry2 >> 8) & 0xf);
                output[out_pos] = @truncate(entry2 >> 16);
                output[out_pos + 1] = @truncate(entry2 >> 24);
                out_pos += advance2;

                if ((entry3 & SemanticDynamicDecoder.literal_flag) != 0) {
                    const advance3: usize = @intCast((entry3 >> 8) & 0xf);
                    output[out_pos] = @truncate(entry3 >> 16);
                    output[out_pos + 1] = @truncate(entry3 >> 24);
                    out_pos += advance3;

                    bit_buffer >>= @intCast(entry123_bits);
                    bit_count -= entry123_bits;
                    consumed_bits += entry123_bits;
                    entry = entry4;
                    refillSemanticBits(input, &byte_index, &bit_buffer, &bit_count);
                    continue;
                }

                bit_buffer >>= @intCast(entry12_bits);
                bit_count -= entry12_bits;
                consumed_bits += entry12_bits;
                entry = entry3;
                entry_bits = entry3_bits;
            } else {
                bit_buffer >>= @intCast(entry_bits);
                bit_count -= entry_bits;
                consumed_bits += entry_bits;
                entry = entry2;
                entry_bits = entry2_bits;
            }
        }

        var length_base: usize = undefined;
        var length_extra_bits: u6 = undefined;
        if ((entry & SemanticDynamicDecoder.exceptional_flag) == 0) {
            length_base = @intCast(entry >> 16);
            length_extra_bits = @truncate(entry >> 8);
        } else if ((entry & SemanticDynamicDecoder.secondary_flag) != 0) {
            const start: usize = @intCast(entry >> 16);
            const mask: usize = @intCast(entry & 0xff);
            const secondary_index = start +
                (@as(usize, @intCast(bit_buffer >> SemanticDynamicDecoder.literal_lookup_bits)) & mask);
            if (secondary_index >= decoder.literal_secondary_len) return error.InvalidHuffmanCode;
            const secondary = decoder.literal_secondary[secondary_index];
            const symbol: u16 = secondary >> 4;
            entry_bits = @truncate(secondary & 0x0f);
            if (symbol < 256) {
                bit_buffer >>= @intCast(entry_bits);
                bit_count -= entry_bits;
                consumed_bits += entry_bits;
                output[out_pos] = @truncate(symbol);
                out_pos += 1;
                refillSemanticBits(input, &byte_index, &bit_buffer, &bit_count);
                entry = decoder.literal[@intCast(bit_buffer & SemanticDynamicDecoder.literal_lookup_mask)];
                continue;
            }
            if (symbol == 256) {
                bit_buffer >>= @intCast(entry_bits);
                bit_count -= entry_bits;
                consumed_bits += entry_bits;
                storeFusedReaderState(reader, bit_buffer, bit_count, byte_index, consumed_bits);
                return out_pos;
            }
            if (symbol > 285) return error.InvalidHuffmanCode;
            const metadata = length_table[symbol - 257];
            length_base = metadata.base;
            length_extra_bits = metadata.extra_bits;
        } else {
            if (entry_bits == 0) return error.InvalidHuffmanCode;
            bit_buffer >>= @intCast(entry_bits);
            bit_count -= entry_bits;
            consumed_bits += entry_bits;
            storeFusedReaderState(reader, bit_buffer, bit_count, byte_index, consumed_bits);
            return out_pos;
        }

        var bits = bit_buffer >> @intCast(entry_bits);
        const length_mask = (@as(u64, 1) << @intCast(length_extra_bits)) - 1;
        const length = length_base + @as(usize, @intCast(bits & length_mask));
        bits >>= @intCast(length_extra_bits);

        if (comptime rle1_distance) {
            // The only distance symbol is zero with canonical code 0 and one
            // code bit. Decode and copy the run directly so the hottest RLE
            // loop avoids semantic-distance metadata and runtime match-class
            // dispatch entirely.
            if ((bits & 1) != 0) return error.InvalidHuffmanCode;
            const total_bits: u6 = entry_bits + length_extra_bits + 1;
            bit_buffer >>= @intCast(total_bits);
            bit_count -= total_bits;
            consumed_bits += total_bits;
            refillSemanticBits(input, &byte_index, &bit_buffer, &bit_count);
            entry = decoder.literal[@intCast(bit_buffer & SemanticDynamicDecoder.literal_lookup_mask)];

            if (out_pos == 0) return error.InvalidMatch;
            if (length > output.len - out_pos) return error.OutputTooSmall;
            const byte = output[out_pos - 1];
            fillLinearRle(output, out_pos, length, byte);
            out_pos += length;
            continue;
        }

        const distance_entry = if (single_distance)
            decoder.single_distance
        else
            decoder.distance[@as(usize, @intCast(bits & SemanticDynamicDecoder.distance_lookup_mask))];
        var distance_base: usize = undefined;
        var distance_extra_bits: u6 = undefined;
        var distance_code_bits: u6 = @truncate(distance_entry);
        if ((distance_entry & SemanticDynamicDecoder.literal_flag) != 0) {
            distance_base = @intCast(distance_entry >> 16);
            distance_extra_bits = @truncate(distance_entry >> 8);
        } else if ((distance_entry & SemanticDynamicDecoder.secondary_flag) != 0) {
            const start: usize = @intCast(distance_entry >> 16);
            const mask: usize = @intCast(distance_entry & 0xff);
            const secondary_index = start +
                (@as(usize, @intCast(bits >> SemanticDynamicDecoder.distance_lookup_bits)) & mask);
            if (secondary_index >= decoder.distance_secondary_len) return error.InvalidHuffmanCode;
            const secondary = decoder.distance_secondary[secondary_index];
            const symbol: u16 = secondary >> 4;
            if (symbol >= distance_table.len) return error.InvalidHuffmanCode;
            distance_code_bits = @truncate(secondary & 0x0f);
            const metadata = distance_table[symbol];
            distance_base = metadata.base;
            distance_extra_bits = metadata.extra_bits;
        } else {
            return error.InvalidHuffmanCode;
        }
        if (single_distance and
            (bits & ((@as(u64, 1) << @intCast(distance_code_bits)) - 1)) != 0)
        {
            return error.InvalidHuffmanCode;
        }
        bits >>= @intCast(distance_code_bits);
        const distance_mask = (@as(u64, 1) << @intCast(distance_extra_bits)) - 1;
        const distance = distance_base + @as(usize, @intCast(bits & distance_mask));
        const total_bits: u6 = entry_bits + length_extra_bits + distance_code_bits + distance_extra_bits;

        bit_buffer >>= @intCast(total_bits);
        bit_count -= total_bits;
        consumed_bits += total_bits;
        refillSemanticBits(input, &byte_index, &bit_buffer, &bit_count);
        entry = decoder.literal[@intCast(bit_buffer & SemanticDynamicDecoder.literal_lookup_mask)];
        if (distance == 1) {
            if (out_pos == 0) return error.InvalidMatch;
            if (length > output.len - out_pos) return error.OutputTooSmall;
            const byte = output[out_pos - 1];
            fillLinearRle(output, out_pos, length, byte);
        } else {
            try copyMatchAt(output, out_pos, length, distance);
        }
        out_pos += length;
    }

    storeFusedReaderState(reader, bit_buffer, bit_count, byte_index, consumed_bits);
    while (true) {
        const symbol = try decoder.compact_literal.decodeValue(reader);
        if (symbol < 256) {
            if (out_pos == output.len) return error.OutputTooSmall;
            output[out_pos] = @truncate(symbol);
            out_pos += 1;
        } else if (symbol == 256) {
            return out_pos;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = try decoder.compact_distance.decodeValue(reader);
            const distance = try decodeDistance(distance_symbol, reader);
            try copyMatchAt(output, out_pos, length, distance);
            out_pos += length;
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

inline fn fillLinearRle(output: []u8, out_pos: usize, length: usize, byte: u8) void {
    std.debug.assert(length != 0);
    std.debug.assert(out_pos <= output.len and length <= output.len - out_pos);
    const repeated: @Vector(64, u8) = @splat(byte);
    var copied: usize = 0;
    while (copied + 64 <= length) : (copied += 64) {
        output[out_pos + copied ..][0..64].* = @bitCast(repeated);
    }
    if (copied == length) return;

    const tail_pos = out_pos + copied;
    if (output.len - tail_pos >= 64) {
        // The next symbol overwrites bytes beyond the logical match. This keeps
        // long runs on fixed-width vector stores instead of paying a dynamic
        // memset call for every DEFLATE match.
        output[tail_pos..][0..64].* = @bitCast(repeated);
    } else {
        @memset(output[tail_pos..][0 .. length - copied], byte);
    }
}

noinline fn decodeSemanticDynamicBlockIntoSink(
    noalias reader: *bitstream.BufferedBitReader,
    sink: anytype,
    noalias decoder: *const SemanticDynamicDecoder,
) Error!void {
    return decodeSemanticDynamicBlockIntoSinkMode(
        false,
        reader,
        sink,
        decoder,
    );
}

noinline fn decodeSemanticDynamicBlockIntoSingleDistanceSink(
    noalias reader: *bitstream.BufferedBitReader,
    sink: anytype,
    noalias decoder: *const SemanticDynamicDecoder,
) Error!void {
    return decodeSemanticDynamicBlockIntoSinkMode(
        true,
        reader,
        sink,
        decoder,
    );
}

noinline fn decodeSemanticDynamicBlockIntoSinkMode(
    comptime single_distance: bool,
    noalias reader: *bitstream.BufferedBitReader,
    sink: anytype,
    noalias decoder: *const SemanticDynamicDecoder,
) Error!void {
    const input = reader.input;
    var bit_buffer = reader.bit_buffer;
    var bit_count = reader.bit_count;
    var byte_index = reader.byte_index;
    var consumed_bits = reader.consumed_bits;

    if (sink.hasHeadroom(8) and byte_index + 8 <= input.len) {
        refillSemanticBits(input, &byte_index, &bit_buffer, &bit_count);
    }
    var entry = decoder.literal[@intCast(bit_buffer & SemanticDynamicDecoder.literal_lookup_mask)];

    while (sink.hasHeadroom(8) and byte_index + 8 <= input.len) {
        var entry_bits: u6 = @truncate(entry);

        if ((entry & SemanticDynamicDecoder.literal_flag) != 0) {
            const entry2 = decoder.literal[
                @as(usize, @intCast((bit_buffer >> @intCast(entry_bits)) & SemanticDynamicDecoder.literal_lookup_mask))
            ];
            const entry2_bits: u6 = @truncate(entry2);
            const entry12_bits: u6 = entry_bits + entry2_bits;
            const entry3 = decoder.literal[
                @as(usize, @intCast((bit_buffer >> @intCast(entry12_bits)) & SemanticDynamicDecoder.literal_lookup_mask))
            ];
            const entry3_bits: u6 = @truncate(entry3);
            const entry123_bits: u6 = entry12_bits + entry3_bits;
            // Load the following entry before retiring the current literals.
            // The independent table load can overlap the output stores and the
            // subsequent reservoir refill instead of starting the next loop's
            // dependency chain from scratch.
            const entry4 = decoder.literal[
                @as(usize, @intCast((bit_buffer >> @intCast(entry123_bits)) & SemanticDynamicDecoder.literal_lookup_mask))
            ];

            if ((entry2 & SemanticDynamicDecoder.literal_flag) != 0) {
                if ((entry3 & SemanticDynamicDecoder.literal_flag) != 0) {
                    try sink.emitSemanticLiteralTriple(entry, entry2, entry3);

                    bit_buffer >>= @intCast(entry123_bits);
                    bit_count -= entry123_bits;
                    consumed_bits += entry123_bits;
                    entry = entry4;
                    refillSemanticBits(input, &byte_index, &bit_buffer, &bit_count);
                    continue;
                }

                try sink.emitSemanticLiteral(entry);
                try sink.emitSemanticLiteral(entry2);
                bit_buffer >>= @intCast(entry12_bits);
                bit_count -= entry12_bits;
                consumed_bits += entry12_bits;
                entry = entry3;
                entry_bits = entry3_bits;
            } else {
                try sink.emitSemanticLiteral(entry);
                bit_buffer >>= @intCast(entry_bits);
                bit_count -= entry_bits;
                consumed_bits += entry_bits;
                entry = entry2;
                entry_bits = entry2_bits;
            }
        }

        var length_base: usize = undefined;
        var length_extra_bits: u6 = undefined;
        if ((entry & SemanticDynamicDecoder.exceptional_flag) == 0) {
            length_base = @intCast(entry >> 16);
            length_extra_bits = @truncate(entry >> 8);
        } else if ((entry & SemanticDynamicDecoder.secondary_flag) != 0) {
            const start: usize = @intCast(entry >> 16);
            const mask: usize = @intCast(entry & 0xff);
            const secondary_index = start +
                (@as(usize, @intCast(bit_buffer >> SemanticDynamicDecoder.literal_lookup_bits)) & mask);
            if (secondary_index >= decoder.literal_secondary_len) return error.InvalidHuffmanCode;
            const secondary = decoder.literal_secondary[secondary_index];
            const symbol: u16 = secondary >> 4;
            entry_bits = @truncate(secondary & 0x0f);
            if (symbol < 256) {
                bit_buffer >>= @intCast(entry_bits);
                bit_count -= entry_bits;
                consumed_bits += entry_bits;
                try sink.emitByte(@truncate(symbol));
                refillSemanticBits(input, &byte_index, &bit_buffer, &bit_count);
                entry = decoder.literal[@intCast(bit_buffer & SemanticDynamicDecoder.literal_lookup_mask)];
                continue;
            }
            if (symbol == 256) {
                bit_buffer >>= @intCast(entry_bits);
                bit_count -= entry_bits;
                consumed_bits += entry_bits;
                storeFusedReaderState(reader, bit_buffer, bit_count, byte_index, consumed_bits);
                return;
            }
            if (symbol > 285) return error.InvalidHuffmanCode;
            const metadata = length_table[symbol - 257];
            length_base = metadata.base;
            length_extra_bits = metadata.extra_bits;
        } else {
            if (entry_bits == 0) return error.InvalidHuffmanCode;
            bit_buffer >>= @intCast(entry_bits);
            bit_count -= entry_bits;
            consumed_bits += entry_bits;
            storeFusedReaderState(reader, bit_buffer, bit_count, byte_index, consumed_bits);
            return;
        }

        var bits = bit_buffer >> @intCast(entry_bits);
        const length_mask = (@as(u64, 1) << @intCast(length_extra_bits)) - 1;
        const length = length_base + @as(usize, @intCast(bits & length_mask));
        bits >>= @intCast(length_extra_bits);

        const distance_entry = if (single_distance)
            decoder.single_distance
        else
            decoder.distance[@as(usize, @intCast(bits & SemanticDynamicDecoder.distance_lookup_mask))];
        var distance_base: usize = undefined;
        var distance_extra_bits: u6 = undefined;
        var distance_code_bits: u6 = @truncate(distance_entry);
        if ((distance_entry & SemanticDynamicDecoder.literal_flag) != 0) {
            distance_base = @intCast(distance_entry >> 16);
            distance_extra_bits = @truncate(distance_entry >> 8);
        } else if ((distance_entry & SemanticDynamicDecoder.secondary_flag) != 0) {
            const start: usize = @intCast(distance_entry >> 16);
            const mask: usize = @intCast(distance_entry & 0xff);
            const secondary_index = start +
                (@as(usize, @intCast(bits >> SemanticDynamicDecoder.distance_lookup_bits)) & mask);
            if (secondary_index >= decoder.distance_secondary_len) return error.InvalidHuffmanCode;
            const secondary = decoder.distance_secondary[secondary_index];
            const symbol: u16 = secondary >> 4;
            if (symbol >= distance_table.len) return error.InvalidHuffmanCode;
            distance_code_bits = @truncate(secondary & 0x0f);
            const metadata = distance_table[symbol];
            distance_base = metadata.base;
            distance_extra_bits = metadata.extra_bits;
        } else {
            return error.InvalidHuffmanCode;
        }
        if (single_distance and
            (bits & ((@as(u64, 1) << @intCast(distance_code_bits)) - 1)) != 0)
        {
            return error.InvalidHuffmanCode;
        }
        bits >>= @intCast(distance_code_bits);
        const distance_mask = (@as(u64, 1) << @intCast(distance_extra_bits)) - 1;
        const distance = distance_base + @as(usize, @intCast(bits & distance_mask));
        const total_bits: u6 = entry_bits + length_extra_bits + distance_code_bits + distance_extra_bits;

        bit_buffer >>= @intCast(total_bits);
        bit_count -= total_bits;
        consumed_bits += total_bits;
        refillSemanticBits(input, &byte_index, &bit_buffer, &bit_count);
        entry = decoder.literal[@intCast(bit_buffer & SemanticDynamicDecoder.literal_lookup_mask)];
        try sink.copyMatch(length, distance);
    }

    storeFusedReaderState(reader, bit_buffer, bit_count, byte_index, consumed_bits);
    // The semantic loop intentionally stops before boundary conditions.
    // Decode the final handful of symbols through the compact reference tables.
    while (true) {
        const symbol = try decoder.compact_literal.decodeValue(reader);
        if (symbol < 256) {
            try sink.emitByte(@truncate(symbol));
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = try decoder.compact_distance.decodeValue(reader);
            const distance = try decodeDistance(distance_symbol, reader);
            try sink.copyMatch(length, distance);
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

inline fn refillSemanticBits(input: []const u8, byte_index: *usize, bit_buffer: *u64, bit_count: *usize) void {
    if (bit_count.* >= 56) return;
    const bytes_to_stage = (63 - bit_count.*) / 8;
    bit_buffer.* |= std.mem.readInt(u64, input[byte_index.*..][0..8], .little) << @intCast(bit_count.*);
    bit_count.* += bytes_to_stage * 8;
    byte_index.* += bytes_to_stage;
}

fn decodeCompressedBlockIntoReaderNoDict(
    reader: anytype,
    output: []u8,
    out_offset: *usize,
    lit_table: anytype,
    dist_table: anytype,
) Error!void {
    while (true) {
        const symbol = try lit_table.decodeValue(reader);
        if (symbol < 256) {
            if (out_offset.* == output.len) return error.OutputTooSmall;
            output[out_offset.*] = @intCast(symbol);
            out_offset.* += 1;
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = try dist_table.decodeValue(reader);
            const distance = try decodeDistance(distance_symbol, reader);
            try copyMatchAt(output, out_offset.*, length, distance);
            out_offset.* += length;
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn decodeFusedDynamicBlockIntoBufferedReader(
    reader: *bitstream.BufferedBitReader,
    output: []u8,
    out_offset: *usize,
    lit_decoder: *const FusedDynamicLiteralDecoder,
    dist_decoder: *const DynamicDistanceDecoder,
) Error!void {
    const input = reader.input;
    var bit_buffer = reader.bit_buffer;
    var bit_count = reader.bit_count;
    var byte_index = reader.byte_index;
    var consumed_bits = reader.consumed_bits;
    var out_pos = out_offset.*;

    while (out_pos + 6 <= output.len) {
        // Three 12-bit primary entries require at most 36 staged bits and can
        // retire six literal bytes. Asking for 48 bits amortizes reservoir
        // refill while leaving room for the next length/distance metadata read.
        if (bit_count < 48 and byte_index < input.len) {
            if (bit_count <= 55 and input.len - byte_index >= 8) {
                const bytes_to_stage = (63 - bit_count) / 8;
                bit_buffer |= std.mem.readInt(u64, input[byte_index..][0..8], .little) << @intCast(bit_count);
                bit_count += bytes_to_stage * 8;
                byte_index += bytes_to_stage;
            }
            while (bit_count < 48 and byte_index < input.len and bit_count <= 56) {
                bit_buffer |= @as(u64, input[byte_index]) << @intCast(bit_count);
                bit_count += 8;
                byte_index += 1;
            }
        }
        if (bit_count < 36) break;

        const entry1 = lit_decoder.lookup[@intCast(bit_buffer & FusedDynamicLiteralDecoder.lookup_mask)];
        if (FusedDynamicLiteralDecoder.entryKind(entry1) != FusedDynamicLiteralDecoder.literal) {
            storeFusedReaderState(reader, bit_buffer, bit_count, byte_index, consumed_bits);
            out_offset.* = out_pos;
            if (try decodeFusedDynamicNonLiteral(reader, output, out_offset, lit_decoder, dist_decoder, entry1)) return;
            bit_buffer = reader.bit_buffer;
            bit_count = reader.bit_count;
            byte_index = reader.byte_index;
            consumed_bits = reader.consumed_bits;
            out_pos = out_offset.*;
            continue;
        }
        emitFusedLiteralAt(output, &out_pos, entry1);
        const bits1 = FusedDynamicLiteralDecoder.entryBits(entry1);

        const entry2 = lit_decoder.lookup[@intCast((bit_buffer >> @intCast(bits1)) & FusedDynamicLiteralDecoder.lookup_mask)];
        if (FusedDynamicLiteralDecoder.entryKind(entry2) != FusedDynamicLiteralDecoder.literal) {
            bit_buffer >>= @intCast(bits1);
            bit_count -= bits1;
            consumed_bits += bits1;
            storeFusedReaderState(reader, bit_buffer, bit_count, byte_index, consumed_bits);
            out_offset.* = out_pos;
            if (try decodeFusedDynamicNonLiteral(reader, output, out_offset, lit_decoder, dist_decoder, entry2)) return;
            bit_buffer = reader.bit_buffer;
            bit_count = reader.bit_count;
            byte_index = reader.byte_index;
            consumed_bits = reader.consumed_bits;
            out_pos = out_offset.*;
            continue;
        }
        emitFusedLiteralAt(output, &out_pos, entry2);
        const bits2 = FusedDynamicLiteralDecoder.entryBits(entry2);
        const bits12: u6 = bits1 + bits2;

        const entry3 = lit_decoder.lookup[@intCast((bit_buffer >> @intCast(bits12)) & FusedDynamicLiteralDecoder.lookup_mask)];
        if (FusedDynamicLiteralDecoder.entryKind(entry3) != FusedDynamicLiteralDecoder.literal) {
            bit_buffer >>= @intCast(bits12);
            bit_count -= bits12;
            consumed_bits += bits12;
            storeFusedReaderState(reader, bit_buffer, bit_count, byte_index, consumed_bits);
            out_offset.* = out_pos;
            if (try decodeFusedDynamicNonLiteral(reader, output, out_offset, lit_decoder, dist_decoder, entry3)) return;
            bit_buffer = reader.bit_buffer;
            bit_count = reader.bit_count;
            byte_index = reader.byte_index;
            consumed_bits = reader.consumed_bits;
            out_pos = out_offset.*;
            continue;
        }
        emitFusedLiteralAt(output, &out_pos, entry3);
        const consumed: u6 = bits12 + FusedDynamicLiteralDecoder.entryBits(entry3);
        bit_buffer >>= @intCast(consumed);
        bit_count -= consumed;
        consumed_bits += consumed;
    }

    // The fused loop deliberately requires six bytes of output headroom.
    // Preserve exact OutputTooSmall/truncation behavior at the final boundary
    // by decoding the small tail through the scalar table.
    storeFusedReaderState(reader, bit_buffer, bit_count, byte_index, consumed_bits);
    out_offset.* = out_pos;
    while (true) {
        const symbol = try lit_decoder.table.decodeValue(reader);
        if (symbol < 256) {
            if (out_offset.* == output.len) return error.OutputTooSmall;
            output[out_offset.*] = @intCast(symbol);
            out_offset.* += 1;
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = try dist_decoder.decodeValue(reader);
            const distance = try decodeDistance(distance_symbol, reader);
            try copyMatchAt(output, out_offset.*, length, distance);
            out_offset.* += length;
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

inline fn storeFusedReaderState(
    reader: *bitstream.BufferedBitReader,
    bit_buffer: u64,
    bit_count: usize,
    byte_index: usize,
    consumed_bits: usize,
) void {
    reader.bit_buffer = bit_buffer;
    reader.bit_count = bit_count;
    reader.byte_index = byte_index;
    reader.consumed_bits = consumed_bits;
}

inline fn emitFusedLiteralAt(output: []u8, out_pos: *usize, entry: u32) void {
    // The fused loop has six bytes of destination headroom. Always store both
    // lanes and advance by one or two without a data-dependent branch; a
    // single-literal entry's second byte is harmless scratch that the next
    // decoded symbol overwrites.
    output[out_pos.*] = FusedDynamicLiteralDecoder.firstLiteral(entry);
    output[out_pos.* + 1] = FusedDynamicLiteralDecoder.secondLiteral(entry);
    out_pos.* += @as(usize, 1) + @intFromBool(FusedDynamicLiteralDecoder.hasSecondLiteral(entry));
}

fn decodeFusedDynamicNonLiteral(
    reader: *bitstream.BufferedBitReader,
    output: []u8,
    out_offset: *usize,
    lit_decoder: *const FusedDynamicLiteralDecoder,
    dist_decoder: *const DynamicDistanceDecoder,
    entry: u32,
) Error!bool {
    switch (FusedDynamicLiteralDecoder.entryKind(entry)) {
        FusedDynamicLiteralDecoder.length => {
            reader.advanceBitsStagedAssumeAvailable(FusedDynamicLiteralDecoder.entryBits(entry));
            const length = FusedDynamicLiteralDecoder.lengthBase(entry) +
                try readDeflateExtraBits(reader, FusedDynamicLiteralDecoder.lengthExtraBits(entry));
            const distance_symbol = try dist_decoder.decodeValue(reader);
            const distance = try decodeDistance(distance_symbol, reader);
            try copyMatchAt(output, out_offset.*, length, distance);
            out_offset.* += length;
            return false;
        },
        FusedDynamicLiteralDecoder.end_of_block => {
            reader.advanceBitsStagedAssumeAvailable(FusedDynamicLiteralDecoder.entryBits(entry));
            return true;
        },
        else => {
            // A zero primary entry is a valid prefix only for a code longer
            // than 12 bits (or malformed input). Decode it with the compact
            // reference table from the already-synchronized reader.
            const symbol = try lit_decoder.table.decodeValue(reader);
            if (symbol < 256) {
                output[out_offset.*] = @intCast(symbol);
                out_offset.* += 1;
            } else if (symbol == 256) {
                return true;
            } else if (symbol <= 285) {
                const length = try decodeLength(symbol, reader);
                const distance_symbol = try dist_decoder.decodeValue(reader);
                const distance = try decodeDistance(distance_symbol, reader);
                try copyMatchAt(output, out_offset.*, length, distance);
                out_offset.* += length;
            } else {
                return error.InvalidHuffmanCode;
            }
            return false;
        },
    }
}

inline fn decodeLength(symbol: u16, reader: anytype) Error!usize {
    if (symbol < 257 or symbol > 285) return error.InvalidHuffmanCode;
    if (symbol <= 264) return symbol - 254;
    if (symbol == 285) return 258;
    const entry = length_table[symbol - 257];
    return entry.base + try readDeflateExtraBits(reader, entry.extra_bits);
}

inline fn decodeDistance(symbol: u16, reader: anytype) Error!usize {
    if (symbol >= distance_table.len) return error.InvalidHuffmanCode;
    if (symbol < 4) return symbol + 1;
    const entry = distance_table[symbol];
    return entry.base + try readDeflateExtraBits(reader, entry.extra_bits);
}

inline fn readDeflateExtraBits(reader: anytype, count: u6) Error!usize {
    std.debug.assert(count <= 13);
    if (count == 0) return 0;
    const extra = reader.peekBitsPadded(u16, count);
    // `peekBitsPadded` already staged every byte available for this short
    // extra-bit field. Checking that staged reservoir preserves strict
    // truncation reporting without re-running the more expensive total
    // remaining-bits calculation on every length/distance match.
    if (!reader.hasStagedBits(count)) return error.TruncatedFrame;
    reader.advanceBitsStagedAssumeAvailable(count);
    return extra;
}

fn copyMatchAt(output: []u8, out_offset: usize, length: usize, distance: usize) Error!void {
    if (distance == 0 or distance > out_offset) return error.InvalidMatch;
    if (out_offset > output.len or output.len - out_offset < length) return error.OutputTooSmall;
    const dest = output[out_offset..][0..length];
    if (distance == 1 and out_offset != 0) {
        @memset(dest, output[out_offset - 1]);
        return;
    }
    if (distance <= 4 and out_offset >= distance) {
        copySmallDistanceMatch(dest, output[out_offset - distance ..], distance);
        return;
    }
    if (distance >= length) {
        @memcpy(dest, output[out_offset - distance ..][0..length]);
        return;
    }
    copyOverlappingMatchAt(output, out_offset, length, distance);
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
    copyOverlappingMatch(history, dest[0..length], distance);
}

fn copyMatchWithDictionary(history: []const u8, dictionary: []const u8, dest: []u8, length: usize, distance: usize) Error!void {
    if (dictionary.len == 0) return copyMatch(history, dest, length, distance);
    if (distance == 0 or distance > history.len + dictionary.len) return error.InvalidMatch;
    if (dest.len < length) return error.OutputTooSmall;

    if (distance <= history.len) return copyMatch(history, dest, length, distance);

    copyDictionaryMatch(dictionary, history, dest[0..length], distance);
}

fn copyDictionaryMatch(dictionary: []const u8, history: []const u8, dest: []u8, distance: usize) void {
    std.debug.assert(distance <= dictionary.len + history.len);
    std.debug.assert(dest.len != 0);

    // A dictionary-backed match reads from the virtual history
    // `dictionary ++ history` until it reaches bytes emitted by this match. Seed
    // as much of that virtual history as the match can observe directly (the
    // full distance window for overlapping matches, or the whole destination for
    // non-overlapping dictionary-only copies). Any remaining suffix can then be
    // reproduced from the initialized destination prefix with doubling.
    const base_len = dictionary.len + history.len;
    const absolute = base_len - distance;
    std.debug.assert(absolute < dictionary.len);
    const seed_len = @min(distance, dest.len);
    const dict_seed_len = @min(seed_len, dictionary.len - absolute);
    @memcpy(dest[0..dict_seed_len], dictionary[absolute..][0..dict_seed_len]);
    if (dict_seed_len < seed_len) {
        const history_seed_len = seed_len - dict_seed_len;
        @memcpy(dest[dict_seed_len..seed_len], history[0..history_seed_len]);
    }
    var copied = seed_len;
    while (copied < dest.len) {
        const n = @min(copied, dest.len - copied);
        @memcpy(dest[copied..][0..n], dest[0..n]);
        copied += n;
    }
}

fn copySmallDistanceMatch(dest: []u8, pattern: []const u8, distance: usize) void {
    if (dest.len >= 16) return repeatSmallPatternByDoubling(dest, pattern[0..distance]);
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

fn repeatSmallPatternByDoubling(dest: []u8, pattern: []const u8) void {
    std.debug.assert(pattern.len > 0 and pattern.len <= 4);
    const seed = @min(pattern.len, dest.len);
    @memcpy(dest[0..seed], pattern[0..seed]);
    var copied = seed;
    while (copied < dest.len) {
        const n = @min(copied, dest.len - copied);
        @memcpy(dest[copied..][0..n], dest[0..n]);
        copied += n;
    }
}

fn copyOverlappingMatch(history: []const u8, dest: []u8, distance: usize) void {
    std.debug.assert(distance > 0 and distance < dest.len);
    std.debug.assert(distance <= history.len);

    // Seed exactly one distance-window from history, then repeatedly double the
    // initialized prefix. This preserves DEFLATE's overlapping-copy semantics
    // while avoiding a byte-at-a-time loop for medium/long matches with
    // distances above the specialized small-distance cases.
    const first = @min(distance, dest.len);
    @memcpy(dest[0..first], history[history.len - distance ..][0..first]);
    var copied = first;
    while (copied < dest.len) {
        const n = @min(copied, dest.len - copied);
        @memcpy(dest[copied..][0..n], dest[0..n]);
        copied += n;
    }
}

fn copyOverlappingMatchAt(output: []u8, out_offset: usize, length: usize, distance: usize) void {
    std.debug.assert(distance > 0 and distance < length);
    std.debug.assert(distance <= out_offset);
    std.debug.assert(output.len - out_offset >= length);

    const first = @min(distance, length);
    @memcpy(output[out_offset..][0..first], output[out_offset - distance ..][0..first]);
    var copied = first;
    while (copied < length) {
        const n = @min(copied, length - copied);
        @memcpy(output[out_offset + copied ..][0..n], output[out_offset..][0..n]);
        copied += n;
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
    if (distance <= history_len) {
        // Preset-dictionary streams only need byte-at-a-time fallback while a
        // match reaches back into the dictionary prefix. Once the match distance
        // is fully inside this member's decoded output, use the same bulk copy
        // paths as no-dictionary inflate. This matters for dictionary-trained
        // JSON/log payloads where the first back-reference may seed output from
        // the preset dictionary and the following matches usually replay from
        // freshly decoded history.
        if (distance <= 4) {
            appendSmallDistanceMatchAssumeCapacity(out, length, distance);
            return;
        }
        if (distance >= length) {
            const start = out.items.len - distance;
            out.appendSliceAssumeCapacity(out.items[start..][0..length]);
            return;
        }
        const out_offset = out.items.len;
        out.items.len += length;
        // Allocating decoders have already reserved the final match span, so
        // history-only overlapping matches can share the caller-buffer doubling
        // copy. This avoids appending one byte at a time on long LZ77 matches.
        copyOverlappingMatchAt(out.items, out_offset, length, distance);
        return;
    }
    const out_offset = out.items.len;
    out.items.len += length;
    copyDictionaryMatch(dictionary, out.items[history_start..out_offset], out.items[out_offset..][0..length], distance);
}

fn appendSmallDistanceMatchAssumeCapacity(out: *std.ArrayList(u8), length: usize, distance: usize) void {
    const out_offset = out.items.len;
    out.items.len += length;
    copySmallDistanceMatch(out.items[out_offset..][0..length], out.items[out_offset - distance ..], distance);
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
    const encoded = try encodeZlibBestTokensAlloc(allocator, input, null, plan.tokens, options);
    errdefer allocator.free(encoded);
    for (bestFallbackCandidates(options).slice()) |fallback_options| {
        const fallback = try encodeZlibBestAlloc(allocator, input, fallback_options);
        errdefer allocator.free(fallback);
        if (fallback.len < encoded.len) {
            allocator.free(encoded);
            return fallback;
        }
        allocator.free(fallback);
    }
    return encoded;
}

pub fn encodeZlibBestWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: CompressionOptions) ![]u8 {
    if (usesStoredFastPath(input, options)) return encodeZlibStoredWithDictionaryAlloc(allocator, input, dictionary);
    const plan = try planTokensWithDictionaryAlloc(allocator, input, dictionary, options);
    defer plan.deinit(allocator);
    const encoded = try encodeZlibBestTokensAlloc(allocator, input, dictionary, plan.tokens, options);
    errdefer allocator.free(encoded);
    for (bestFallbackCandidates(options).slice()) |fallback_options| {
        const fallback = try encodeZlibBestWithDictionaryAlloc(allocator, input, dictionary, fallback_options);
        errdefer allocator.free(fallback);
        if (fallback.len < encoded.len) {
            allocator.free(encoded);
            return fallback;
        }
        allocator.free(fallback);
    }
    return encoded;
}

pub fn encodeZlibLevelAlloc(allocator: std.mem.Allocator, input: []const u8, level: u4) ![]u8 {
    if (level == 0) return encodeZlibStoredAlloc(allocator, input);
    return encodeZlibBestAlloc(allocator, input, try optionsForZlibLevel(level));
}

pub fn encodeZlibLevelWithDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, level: u4) ![]u8 {
    if (level == 0) return encodeZlibStoredWithDictionaryAlloc(allocator, input, dictionary);
    return encodeZlibBestWithDictionaryAlloc(allocator, input, dictionary, try optionsForZlibLevel(level));
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
    try validateZlibFooterWithOptions(input, footer_offset, actual, .{});
}

fn validateZlibFooterWithOptions(input: []const u8, footer_offset: usize, actual: u32, options: ZlibDecodeOptions) Error!void {
    try validateZlibFooterPartialWithOptions(input, footer_offset, actual, options);
    if (!options.allow_trailing_data and footer_offset + 4 != input.len) return error.TrailingData;
}

fn validateZlibFooterPartial(input: []const u8, footer_offset: usize, actual: u32) Error!void {
    try validateZlibFooterPartialWithOptions(input, footer_offset, actual, .{});
}

fn validateZlibFooterPartialWithOptions(input: []const u8, footer_offset: usize, actual: u32, options: ZlibDecodeOptions) Error!void {
    if (footer_offset > input.len or input.len - footer_offset < 4) return error.TruncatedFrame;
    if (!options.ignore_adler) {
        const expected = std.mem.readInt(u32, input[footer_offset..][0..4], .big);
        if (actual != expected) return error.ChecksumMismatch;
    }
}

pub fn inspectZlibStreamAlloc(allocator: std.mem.Allocator, input: []const u8) !ZlibStreamInfo {
    return inspectZlibStreamAllocLimited(allocator, input, 128 * 1024 * 1024);
}

pub fn inspectZlibStreamAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) !ZlibStreamInfo {
    return inspectZlibStreamAllocWithOptionalDictionaryLimited(allocator, input, null, max_output_len);
}

pub fn inspectZlibStreamFromChunksAlloc(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8) !ZlibStreamInfo {
    return inspectZlibStreamFromChunksAllocLimited(allocator, chunks, compressed_scratch, 128 * 1024 * 1024);
}

pub fn inspectZlibStreamFromChunksAllocLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) !ZlibStreamInfo {
    const joined = try joinChunks(chunks, compressed_scratch);
    return inspectZlibStreamAllocLimited(allocator, joined, max_output_len);
}

pub fn inspectZlibStreamAllocWithDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8) !ZlibStreamInfo {
    return inspectZlibStreamAllocWithDictionaryLimited(allocator, input, dictionary, 128 * 1024 * 1024);
}

pub fn inspectZlibStreamFromChunksAllocWithDictionary(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary: []const u8) !ZlibStreamInfo {
    return inspectZlibStreamFromChunksAllocWithDictionaryLimited(allocator, chunks, compressed_scratch, dictionary, 128 * 1024 * 1024);
}

pub fn inspectZlibStreamFromChunksAllocWithDictionaryLimited(
    allocator: std.mem.Allocator,
    chunks: []const []const u8,
    compressed_scratch: []u8,
    dictionary: []const u8,
    max_output_len: usize,
) !ZlibStreamInfo {
    const joined = try joinChunks(chunks, compressed_scratch);
    return inspectZlibStreamAllocWithDictionaryLimited(allocator, joined, dictionary, max_output_len);
}

pub fn inspectZlibStreamAllocWithDictionaryLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    dictionary: []const u8,
    max_output_len: usize,
) !ZlibStreamInfo {
    return inspectZlibStreamAllocWithOptionalDictionaryLimited(allocator, input, dictionary, max_output_len);
}

fn inspectZlibStreamAllocWithOptionalDictionaryLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    dictionary: ?[]const u8,
    max_output_len: usize,
) !ZlibStreamInfo {
    const header = try parseZlibHeader(input, dictionary);
    const raw_dictionary = if (header.uses_dictionary) dictionary.? else "";
    const header_info = try parseZlibHeaderInfo(input);
    const raw = try decodeRawAutoAllocPartialWithDictionary(allocator, input[header.data_offset..], raw_dictionary, max_output_len);
    defer raw.deinit(allocator);
    const footer_offset = header.data_offset + raw.input_read;
    if (footer_offset > input.len or input.len - footer_offset < 4) return error.TruncatedFrame;
    const end_offset = footer_offset + 4;
    const footer_adler32 = std.mem.readInt(u32, input[footer_offset..][0..4], .big);
    const actual_adler32 = checksum.adler32(raw.bytes);
    return .{
        .header = header_info,
        .deflate_offset = header.data_offset,
        .deflate_bytes = raw.input_read,
        .output_bytes = raw.bytes.len,
        .footer_offset = footer_offset,
        .end_offset = end_offset,
        .footer_adler32 = footer_adler32,
        .adler32 = actual_adler32,
        .adler32_matches = footer_adler32 == actual_adler32,
    };
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

pub fn decodeZlibWithOptions(input: []const u8, output: []u8, options: ZlibDecodeOptions) Error!usize {
    return decodeZlibWithOptionalDictionaryAndOptions(input, output, null, options);
}

pub fn decodeZlibWithDictionaryAndOptions(input: []const u8, output: []u8, dictionary: []const u8, options: ZlibDecodeOptions) Error!usize {
    return decodeZlibWithOptionalDictionaryAndOptions(input, output, dictionary, options);
}

fn joinChunks(chunks: []const []const u8, compressed_scratch: []u8) Error![]const u8 {
    var total: usize = 0;
    var single_non_empty: ?[]const u8 = null;
    var non_empty_count: usize = 0;
    for (chunks) |chunk| {
        // Compute total length and identify the single-chunk fast path together;
        // legacy wrapper chunk joins are small but hot in tests and PNG-style
        // adapters, so avoid scanning the slice list twice before every decode.
        total = std.math.add(usize, total, chunk.len) catch return error.IntegerOverflow;
        if (chunk.len == 0) continue;
        single_non_empty = chunk;
        non_empty_count += 1;
    }
    if (non_empty_count == 1) {
        const chunk = single_non_empty.?;
        std.debug.assert(chunk.len == total);
        // Legacy chunked APIs need a caller-provided compressed scratch buffer
        // only when they must coalesce multiple spans. A single non-empty chunk
        // is already contiguous and lives for the duration of the synchronous
        // decode/reset call, so borrowing it avoids both the scratch-size
        // requirement and an otherwise redundant memcpy.
        return chunk;
    }
    if (compressed_scratch.len < total) return error.OutputTooSmall;
    var offset: usize = 0;
    for (chunks) |chunk| {
        if (chunk.len == 0) continue;
        @memcpy(compressed_scratch[offset..][0..chunk.len], chunk);
        offset += chunk.len;
    }
    return compressed_scratch[0..total];
}

pub fn decodeZlibChunks(chunks: []const []const u8, compressed_scratch: []u8, output: []u8) Error!usize {
    return decodeZlibChunksWithOptionalDictionaryAndOptions(chunks, compressed_scratch, output, null, .{});
}

pub fn decodeZlibChunksWithOptions(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, options: ZlibDecodeOptions) Error!usize {
    return decodeZlibChunksWithOptionalDictionaryAndOptions(chunks, compressed_scratch, output, null, options);
}

pub fn decodeZlibChunksWithDictionary(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: []const u8) Error!usize {
    return decodeZlibChunksWithOptionalDictionaryAndOptions(chunks, compressed_scratch, output, dictionary, .{});
}

pub fn decodeZlibChunksWithDictionaryAndOptions(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: []const u8, options: ZlibDecodeOptions) Error!usize {
    return decodeZlibChunksWithOptionalDictionaryAndOptions(chunks, compressed_scratch, output, dictionary, options);
}

pub fn decodeZlibChunksInto(chunks: []const []const u8, output: []u8) Error!usize {
    return decodeZlibChunksWithOptionalDictionaryAndOptionsDirect(chunks, output, null, .{});
}

pub fn decodeZlibChunksIntoWithOptions(chunks: []const []const u8, output: []u8, options: ZlibDecodeOptions) Error!usize {
    return decodeZlibChunksWithOptionalDictionaryAndOptionsDirect(chunks, output, null, options);
}

pub fn decodeZlibChunksIntoWithDictionary(chunks: []const []const u8, output: []u8, dictionary: []const u8) Error!usize {
    return decodeZlibChunksWithOptionalDictionaryAndOptionsDirect(chunks, output, dictionary, .{});
}

pub fn decodeZlibChunksIntoWithDictionaryAndOptions(chunks: []const []const u8, output: []u8, dictionary: []const u8, options: ZlibDecodeOptions) Error!usize {
    return decodeZlibChunksWithOptionalDictionaryAndOptionsDirect(chunks, output, dictionary, options);
}

fn decodeZlibChunksWithOptionalDictionaryAndOptions(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: ?[]const u8, options: ZlibDecodeOptions) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return decodeZlibWithOptionalDictionaryAndOptions(joined, output, dictionary, options);
}

fn chunkByteAt(chunks: []const []const u8, offset: usize) ?u8 {
    var remaining = offset;
    for (chunks) |chunk| {
        if (remaining < chunk.len) return chunk[remaining];
        remaining -= chunk.len;
    }
    return null;
}

fn readChunkedBigU32(chunks: []const []const u8, offset: usize) Error!u32 {
    var chunk_index: usize = 0;
    var local = offset;
    while (chunk_index < chunks.len and local >= chunks[chunk_index].len) {
        local -= chunks[chunk_index].len;
        chunk_index += 1;
    }

    var value: u32 = 0;
    var read: usize = 0;
    while (read < 4) : (read += 1) {
        while (chunk_index < chunks.len and local >= chunks[chunk_index].len) {
            local -= chunks[chunk_index].len;
            chunk_index += 1;
        }
        if (chunk_index >= chunks.len) return error.TruncatedFrame;
        value = (value << 8) | chunks[chunk_index][local];
        local += 1;
    }
    return value;
}

fn readChunkedTailBigU32(chunks: []const []const u8, total_len: usize) Error!u32 {
    if (total_len < 4) return error.TruncatedFrame;
    var chunk_index = chunks.len;
    var bytes: [4]u8 = undefined;
    var out_i: usize = 4;

    while (out_i != 0) {
        if (chunk_index == 0) return error.TruncatedFrame;
        chunk_index -= 1;
        const chunk = chunks[chunk_index];
        var local_end = chunk.len;
        while (local_end != 0 and out_i != 0) {
            local_end -= 1;
            out_i -= 1;
            bytes[out_i] = chunk[local_end];
        }
    }
    return std.mem.readInt(u32, &bytes, .big);
}

const ChunkCursor = struct {
    chunks: []const []const u8,
    total_len: usize,
    absolute: usize,
    chunk_index: usize = 0,
    chunk_start: usize = 0,

    fn init(chunks: []const []const u8, total_len: usize, offset: usize) Error!ChunkCursor {
        if (offset > total_len) return error.TruncatedFrame;
        var cursor = ChunkCursor{ .chunks = chunks, .total_len = total_len, .absolute = offset };
        cursor.sync();
        return cursor;
    }

    fn sync(self: *ChunkCursor) void {
        if (self.absolute >= self.total_len) {
            self.chunk_index = self.chunks.len;
            self.chunk_start = self.total_len;
            return;
        }
        if (self.chunk_index >= self.chunks.len or self.absolute < self.chunk_start) {
            self.chunk_index = 0;
            self.chunk_start = 0;
        }
        while (self.chunk_index < self.chunks.len) {
            const end = self.chunk_start + self.chunks[self.chunk_index].len;
            if (self.absolute < end) return;
            self.chunk_start = end;
            self.chunk_index += 1;
        }
    }

    fn readByte(self: *ChunkCursor) Error!u8 {
        if (self.absolute >= self.total_len) return error.TruncatedFrame;
        self.sync();
        if (self.chunk_index >= self.chunks.len) return error.TruncatedFrame;
        const chunk = self.chunks[self.chunk_index];
        const local = self.absolute - self.chunk_start;
        const byte = chunk[local];
        self.absolute += 1;
        return byte;
    }

    fn readLittleU16(self: *ChunkCursor) Error!u16 {
        const lo = try self.readByte();
        const hi = try self.readByte();
        return @as(u16, lo) | (@as(u16, hi) << 8);
    }

    fn readBigU32(self: *ChunkCursor) Error!u32 {
        var value: u32 = 0;
        for (0..4) |_| value = (value << 8) | try self.readByte();
        return value;
    }

    fn copyTo(self: *ChunkCursor, output: []u8) Error!void {
        var absolute = self.absolute;
        var chunk_index = self.chunk_index;
        var chunk_start = self.chunk_start;
        if (chunk_index >= self.chunks.len or absolute < chunk_start) {
            chunk_index = 0;
            chunk_start = 0;
        }

        var out_offset: usize = 0;
        while (out_offset < output.len) {
            if (absolute >= self.total_len) return error.TruncatedFrame;
            while (chunk_index < self.chunks.len) {
                const end = chunk_start + self.chunks[chunk_index].len;
                if (absolute < end) break;
                chunk_start = end;
                chunk_index += 1;
            }
            if (chunk_index >= self.chunks.len) return error.TruncatedFrame;
            const chunk = self.chunks[chunk_index];
            const local = absolute - chunk_start;
            const n = @min(output.len - out_offset, chunk.len - local);
            @memcpy(output[out_offset..][0..n], chunk[local..][0..n]);
            out_offset += n;
            absolute += n;
        }

        self.absolute = absolute;
        self.chunk_index = chunk_index;
        self.chunk_start = chunk_start;
        self.sync();
    }

    fn skip(self: *ChunkCursor, len: usize) Error!void {
        if (len > self.total_len - self.absolute) return error.TruncatedFrame;
        self.absolute += len;
        self.sync();
    }

    fn updateHash(self: *ChunkCursor, comptime Hash: type, hash: *Hash, len: usize) Error!void {
        var absolute = self.absolute;
        var chunk_index = self.chunk_index;
        var chunk_start = self.chunk_start;
        if (chunk_index >= self.chunks.len or absolute < chunk_start) {
            chunk_index = 0;
            chunk_start = 0;
        }

        var remaining = len;
        while (remaining != 0) {
            if (absolute >= self.total_len) return error.TruncatedFrame;
            while (chunk_index < self.chunks.len) {
                const end = chunk_start + self.chunks[chunk_index].len;
                if (absolute < end) break;
                chunk_start = end;
                chunk_index += 1;
            }
            if (chunk_index >= self.chunks.len) return error.TruncatedFrame;
            const chunk = self.chunks[chunk_index];
            const local = absolute - chunk_start;
            const n = @min(remaining, chunk.len - local);
            hash.update(chunk[local..][0..n]);
            remaining -= n;
            absolute += n;
        }

        self.absolute = absolute;
        self.chunk_index = chunk_index;
        self.chunk_start = chunk_start;
        self.sync();
    }
};

fn parseZlibHeaderFromChunks(chunks: []const []const u8, dictionary: ?[]const u8) Error!ZlibHeader {
    const cmf = chunkByteAt(chunks, 0) orelse return error.TruncatedFrame;
    const flg = chunkByteAt(chunks, 1) orelse return error.TruncatedFrame;
    if ((cmf & 0x0f) != 8) return error.BadZlibHeader;
    const cinfo = cmf >> 4;
    if (cinfo > 7) return error.BadZlibHeader;
    const combined: u16 = (@as(u16, cmf) << 8) | flg;
    if (combined % 31 != 0) return error.BadZlibHeader;

    const uses_dictionary = (flg & 0x20) != 0;
    if (!uses_dictionary) return .{ .data_offset = 2, .uses_dictionary = false };

    const dictionary_id = try readChunkedBigU32(chunks, 2);
    const actual_dictionary = dictionary orelse return error.NeedDictionary;
    if (checksum.adler32(actual_dictionary) != dictionary_id) return error.ChecksumMismatch;
    return .{ .data_offset = 6, .uses_dictionary = true };
}

fn validateZlibFooterChunksWithOptions(chunks: []const []const u8, footer_offset: usize, actual: u32, options: ZlibDecodeOptions) Error!void {
    return validateZlibFooterChunksWithKnownTotal(chunks, try chunksTotalLen(chunks), footer_offset, actual, options);
}

fn validateZlibFooterChunksWithKnownTotal(chunks: []const []const u8, total_len: usize, footer_offset: usize, actual: u32, options: ZlibDecodeOptions) Error!void {
    if (footer_offset > total_len or total_len - footer_offset < 4) return error.TruncatedFrame;
    if (!options.ignore_adler) {
        const expected = if (footer_offset + 4 == total_len)
            try readChunkedTailBigU32(chunks, total_len)
        else
            try readChunkedBigU32(chunks, footer_offset);
        if (actual != expected) return error.ChecksumMismatch;
    }
    if (!options.allow_trailing_data and footer_offset + 4 != total_len) return error.TrailingData;
}

fn decodeZlibChunksWithOptionalDictionaryAndOptionsDirect(chunks: []const []const u8, output: []u8, dictionary: ?[]const u8, options: ZlibDecodeOptions) Error!usize {
    return decodeZlibChunksWithOptionalDictionaryAndOptionsDirectKnownTotal(chunks, try chunksTotalLen(chunks), output, dictionary, options);
}

fn decodeZlibChunksWithOptionalDictionaryAndOptionsDirectKnownTotal(chunks: []const []const u8, total_len: usize, output: []u8, dictionary: ?[]const u8, options: ZlibDecodeOptions) Error!usize {
    const header = try parseZlibHeaderFromChunks(chunks, dictionary);

    if (try decodeZlibChunksViaStackJoinMaybe(chunks, total_len, header, output, dictionary, options)) |written| return written;
    if (try decodeZlibStoredChunksIntoMaybe(chunks, total_len, header.data_offset, output, options)) |stored_written| return stored_written;

    const raw_dictionary = if (header.uses_dictionary) dictionary.? else "";
    var reader = try bitstream.ChunkedSpanBitReader.initAtKnownTotal(chunks, header.data_offset, total_len);
    const raw = try decodeRawAutoWithDictionaryFromReader(&reader, header.data_offset, raw_dictionary, output);
    const footer_offset = header.data_offset + raw.input_read;
    const actual_adler = if (options.ignore_adler) 0 else checksum.adler32(output[0..raw.output_written]);
    try validateZlibFooterChunksWithKnownTotal(chunks, total_len, footer_offset, actual_adler, options);
    return raw.output_written;
}

fn decodeZlibChunksViaStackJoinMaybe(chunks: []const []const u8, total_len: usize, header: ZlibHeader, output: []u8, dictionary: ?[]const u8, options: ZlibDecodeOptions) Error!?usize {
    if (total_len > stack_chunked_zlib_join_max_input_len) return null;
    const first_deflate_byte = chunkByteAt(chunks, header.data_offset) orelse return error.TruncatedFrame;
    const block_type = (first_deflate_byte >> 1) & 0x03;
    if (block_type == 0 and chunks.len <= stack_chunked_zlib_tiny_chunk_count) return null;

    // Direct chunked decode exists to avoid caller-provided compressed scratch,
    // but many real PNG/IDAT streams are split into tiny chunks. For small
    // members, a bounded stack join lets us reuse the contiguous buffered
    // inflater and is faster than rebuilding bit windows across thousands of
    // one-byte chunks, while larger members still use the streaming chunked path.
    // Keep the stack buffer tiered: a 1 KiB tiny-IDAT stream should not pay for a
    // 64 KiB frame on every decode iteration.
    if (total_len <= stack_chunked_zlib_join_tiny_input_len) {
        return try decodeZlibChunksViaStackJoinTiny(chunks, total_len, output, dictionary, options);
    }
    if (total_len <= stack_chunked_zlib_join_small_input_len) {
        return try decodeZlibChunksViaStackJoinSmall(chunks, total_len, output, dictionary, options);
    }
    return try decodeZlibChunksViaStackJoinLarge(chunks, total_len, output, dictionary, options);
}

fn decodeZlibChunksViaStackJoinTiny(chunks: []const []const u8, total_len: usize, output: []u8, dictionary: ?[]const u8, options: ZlibDecodeOptions) Error!usize {
    var joined_buffer: [stack_chunked_zlib_join_tiny_input_len]u8 = undefined;
    return decodeZlibChunksViaStackJoinBuffer(chunks, total_len, joined_buffer[0..total_len], output, dictionary, options);
}

fn decodeZlibChunksViaStackJoinSmall(chunks: []const []const u8, total_len: usize, output: []u8, dictionary: ?[]const u8, options: ZlibDecodeOptions) Error!usize {
    var joined_buffer: [stack_chunked_zlib_join_small_input_len]u8 = undefined;
    return decodeZlibChunksViaStackJoinBuffer(chunks, total_len, joined_buffer[0..total_len], output, dictionary, options);
}

fn decodeZlibChunksViaStackJoinLarge(chunks: []const []const u8, total_len: usize, output: []u8, dictionary: ?[]const u8, options: ZlibDecodeOptions) Error!usize {
    var joined_buffer: [stack_chunked_zlib_join_max_input_len]u8 = undefined;
    return decodeZlibChunksViaStackJoinBuffer(chunks, total_len, joined_buffer[0..total_len], output, dictionary, options);
}

fn decodeZlibChunksViaStackJoinBuffer(chunks: []const []const u8, total_len: usize, joined_buffer: []u8, output: []u8, dictionary: ?[]const u8, options: ZlibDecodeOptions) Error!usize {
    const joined = try joinChunks(chunks, joined_buffer[0..total_len]);
    return try decodeZlibWithOptionalDictionaryAndOptions(joined, output, dictionary, options);
}

fn decodeZlibStoredChunksIntoMaybe(chunks: []const []const u8, total_len: usize, raw_offset: usize, output: []u8, options: ZlibDecodeOptions) Error!?usize {
    var cursor = try ChunkCursor.init(chunks, total_len, raw_offset);
    var out_offset: usize = 0;

    while (true) {
        const header = try cursor.readByte();
        if (!isStoredBlockHeaderByte(header)) return null;
        const final = (header & 0x01) != 0;

        const len = try cursor.readLittleU16();
        const nlen = try cursor.readLittleU16();
        if (nlen != ~len) return error.StoredLengthMismatch;
        const chunk_len: usize = len;
        if (output.len - out_offset < chunk_len) return error.OutputTooSmall;
        try cursor.copyTo(output[out_offset..][0..chunk_len]);
        out_offset += chunk_len;

        if (final) {
            const expected = try cursor.readBigU32();
            if (!options.ignore_adler and checksum.adler32(output[0..out_offset]) != expected) return error.ChecksumMismatch;
            if (!options.allow_trailing_data and cursor.absolute != cursor.total_len) return error.TrailingData;
            return out_offset;
        }
    }
}

fn chunksTotalLen(chunks: []const []const u8) Error!usize {
    var total: usize = 0;
    for (chunks) |chunk| {
        total = std.math.add(usize, total, chunk.len) catch return error.IntegerOverflow;
    }
    return total;
}

pub fn pngIdatChunksScratchLen(chunks: []const []const u8) Error!usize {
    return chunksTotalLen(chunks);
}

pub const PngFilterMethod = enum(u8) {
    none = 0,
    sub = 1,
    up = 2,
    average = 3,
    paeth = 4,
};

pub const PngColorType = enum(u8) {
    grayscale = 0,
    truecolor = 2,
    indexed = 3,
    grayscale_alpha = 4,
    truecolor_alpha = 6,
};

pub const PngImageInfo = struct {
    width: usize,
    height: usize,
    bit_depth: u8,
    color_type: PngColorType,
    samples_per_pixel: u8,
    bits_per_pixel: u16,
    /// Bytes in one filtered scanline after the leading PNG filter byte. This is
    /// ceil(width * samples_per_pixel * bit_depth / 8).
    row_len: usize,
    /// PNG filter predictor stride in bytes. For sub-byte formats PNG rounds
    /// this up to one byte, so callers can use the same row reconstruction
    /// surface for indexed/grayscale bit depths below 8.
    bytes_per_pixel: usize,
    /// Exact decoded zlib payload bytes for all scanlines, including one filter
    /// byte per row. Useful for exact-size zlib/IDAT decode preflight.
    zlib_payload_len: usize,
};

pub const PngZlibDecodeBufferSizes = struct {
    /// Exact decoded IDAT/zlib payload size, including one filter byte per row.
    zlib_scratch_len: usize,
    /// Scratch needed to hold one filtered row before PNG filter reconstruction.
    filtered_row_scratch_len: usize,
    /// Scratch needed to hold the previous reconstructed row for filters 2..4.
    previous_row_scratch_len: usize,
    /// Reconstructed image bytes produced by `decodePngZlibImage*`.
    image_output_len: usize,
};

pub const PngAdam7PassInfo = struct {
    pass_index: u8,
    x_start: usize,
    y_start: usize,
    x_step: usize,
    y_step: usize,
    width: usize,
    height: usize,
    row_len: usize,
    bytes_per_pixel: usize,
    zlib_payload_len: usize,
    reconstructed_len: usize,

    pub fn isEmpty(self: PngAdam7PassInfo) bool {
        return self.width == 0 or self.height == 0;
    }
};

pub const PngAdam7Info = struct {
    image: PngImageInfo,
    passes: [7]PngAdam7PassInfo,
    zlib_payload_len: usize,
    max_pass_row_len: usize,
    image_output_len: usize,
};

pub fn parsePngColorType(color_type: u8) Error!PngColorType {
    return switch (color_type) {
        0 => .grayscale,
        2 => .truecolor,
        3 => .indexed,
        4 => .grayscale_alpha,
        6 => .truecolor_alpha,
        else => error.CorruptFrame,
    };
}

fn pngSamplesPerPixelAndValidateDepth(color_type: PngColorType, bit_depth: u8) Error!u8 {
    return switch (color_type) {
        .grayscale => switch (bit_depth) {
            1, 2, 4, 8, 16 => 1,
            else => error.CorruptFrame,
        },
        .truecolor => switch (bit_depth) {
            8, 16 => 3,
            else => error.CorruptFrame,
        },
        .indexed => switch (bit_depth) {
            1, 2, 4, 8 => 1,
            else => error.CorruptFrame,
        },
        .grayscale_alpha => switch (bit_depth) {
            8, 16 => 2,
            else => error.CorruptFrame,
        },
        .truecolor_alpha => switch (bit_depth) {
            8, 16 => 4,
            else => error.CorruptFrame,
        },
    };
}

pub fn pngImageInfo(width: usize, height: usize, bit_depth: u8, color_type: PngColorType) Error!PngImageInfo {
    if (width == 0 or height == 0) return error.CorruptFrame;
    const samples_per_pixel = try pngSamplesPerPixelAndValidateDepth(color_type, bit_depth);
    const bits_per_pixel = @as(u16, samples_per_pixel) * @as(u16, bit_depth);
    const row_len = try pngPackedRowLen(width, bits_per_pixel);
    const bytes_per_pixel = @max(@as(usize, 1), (@as(usize, bits_per_pixel) + 7) / 8);
    return .{
        .width = width,
        .height = height,
        .bit_depth = bit_depth,
        .color_type = color_type,
        .samples_per_pixel = samples_per_pixel,
        .bits_per_pixel = bits_per_pixel,
        .row_len = row_len,
        .bytes_per_pixel = bytes_per_pixel,
        .zlib_payload_len = try pngScanlinePayloadLen(row_len, height),
    };
}

pub fn pngImageInfoFromColorType(width: usize, height: usize, bit_depth: u8, color_type: u8) Error!PngImageInfo {
    return pngImageInfo(width, height, bit_depth, try parsePngColorType(color_type));
}

fn pngPackedRowLen(width: usize, bits_per_pixel: usize) Error!usize {
    const total_row_bits = std.math.mul(usize, width, bits_per_pixel) catch return error.IntegerOverflow;
    const row_bits_with_rounding = std.math.add(usize, total_row_bits, 7) catch return error.IntegerOverflow;
    return row_bits_with_rounding / 8;
}

pub fn pngZlibDecodeBufferSizes(info: PngImageInfo) Error!PngZlibDecodeBufferSizes {
    return .{
        .zlib_scratch_len = info.zlib_payload_len,
        .filtered_row_scratch_len = info.row_len,
        .previous_row_scratch_len = info.row_len,
        .image_output_len = try pngImageOutputLen(info),
    };
}

const adam7_x_start = [_]usize{ 0, 4, 0, 2, 0, 1, 0 };
const adam7_y_start = [_]usize{ 0, 0, 4, 0, 2, 0, 1 };
const adam7_x_step = [_]usize{ 8, 8, 4, 4, 2, 2, 1 };
const adam7_y_step = [_]usize{ 8, 8, 8, 4, 4, 2, 2 };

pub fn pngAdam7Info(width: usize, height: usize, bit_depth: u8, color_type: PngColorType) Error!PngAdam7Info {
    const image = try pngImageInfo(width, height, bit_depth, color_type);
    var passes: [7]PngAdam7PassInfo = undefined;
    var total_payload: usize = 0;
    var max_pass_row_len: usize = 0;
    for (0..7) |i| {
        const pass_width = adam7PassDimension(width, adam7_x_start[i], adam7_x_step[i]);
        const pass_height = adam7PassDimension(height, adam7_y_start[i], adam7_y_step[i]);
        const row_len = if (pass_width == 0 or pass_height == 0) 0 else try pngPackedRowLen(pass_width, image.bits_per_pixel);
        const pass_payload = if (pass_width == 0 or pass_height == 0) 0 else try pngScanlinePayloadLen(row_len, pass_height);
        const reconstructed_len = std.math.mul(usize, row_len, pass_height) catch return error.IntegerOverflow;
        total_payload = std.math.add(usize, total_payload, pass_payload) catch return error.IntegerOverflow;
        max_pass_row_len = @max(max_pass_row_len, row_len);
        passes[i] = .{
            .pass_index = @intCast(i + 1),
            .x_start = adam7_x_start[i],
            .y_start = adam7_y_start[i],
            .x_step = adam7_x_step[i],
            .y_step = adam7_y_step[i],
            .width = pass_width,
            .height = pass_height,
            .row_len = row_len,
            .bytes_per_pixel = image.bytes_per_pixel,
            .zlib_payload_len = pass_payload,
            .reconstructed_len = reconstructed_len,
        };
    }
    return .{
        .image = image,
        .passes = passes,
        .zlib_payload_len = total_payload,
        .max_pass_row_len = max_pass_row_len,
        .image_output_len = try pngImageOutputLen(image),
    };
}

pub fn pngAdam7InfoFromColorType(width: usize, height: usize, bit_depth: u8, color_type: u8) Error!PngAdam7Info {
    return pngAdam7Info(width, height, bit_depth, try parsePngColorType(color_type));
}

pub fn pngAdam7DecodeBufferSizes(info: PngAdam7Info) PngZlibDecodeBufferSizes {
    return .{
        .zlib_scratch_len = info.zlib_payload_len,
        .filtered_row_scratch_len = info.max_pass_row_len,
        .previous_row_scratch_len = info.max_pass_row_len,
        .image_output_len = info.image_output_len,
    };
}

/// Scatter one reconstructed Adam7 pass row into the final non-interlaced image.
///
/// `row` is the reconstructed payload for one row of `pass` (filter byte already
/// removed and PNG filtering already reversed). `image` is the final packed image
/// buffer described by `info.image`. Byte-aligned formats copy whole pixels;
/// sub-byte grayscale/indexed formats copy individual packed pixels MSB-first.
pub fn placePngAdam7Row(info: PngAdam7Info, pass: PngAdam7PassInfo, pass_row_index: usize, row: []const u8, image: []u8) Error!void {
    if (pass.isEmpty()) return error.RangeOutOfBounds;
    if (pass_row_index >= pass.height) return error.RangeOutOfBounds;
    if (row.len < pass.row_len) return error.InputTooSmall;
    if (image.len < info.image_output_len) return error.OutputTooSmall;

    const dest_y = pass.y_start + pass_row_index * pass.y_step;
    if (dest_y >= info.image.height) return error.RangeOutOfBounds;
    const bits_per_pixel: usize = info.image.bits_per_pixel;
    if (bits_per_pixel >= 8) {
        if (bits_per_pixel % 8 != 0) return error.CorruptFrame;
        const pixel_bytes = bits_per_pixel / 8;
        for (0..pass.width) |pass_x| {
            const dest_x = pass.x_start + pass_x * pass.x_step;
            if (dest_x >= info.image.width) return error.RangeOutOfBounds;
            const src = row[pass_x * pixel_bytes ..][0..pixel_bytes];
            const dest_offset = dest_y * info.image.row_len + dest_x * pixel_bytes;
            @memcpy(image[dest_offset..][0..pixel_bytes], src);
        }
        return;
    }

    if (bits_per_pixel != 1 and bits_per_pixel != 2 and bits_per_pixel != 4) return error.CorruptFrame;
    for (0..pass.width) |pass_x| {
        const dest_x = pass.x_start + pass_x * pass.x_step;
        if (dest_x >= info.image.width) return error.RangeOutOfBounds;
        const value = readPngPackedPixel(row, pass_x, bits_per_pixel);
        writePngPackedPixel(image[dest_y * info.image.row_len ..][0..info.image.row_len], dest_x, bits_per_pixel, value);
    }
}

pub fn placePngAdam7Pass(info: PngAdam7Info, pass: PngAdam7PassInfo, pass_rows: []const u8, image: []u8) Error!void {
    if (pass.isEmpty()) {
        if (pass_rows.len != 0) return error.SizeMismatch;
        return;
    }
    if (pass_rows.len < pass.reconstructed_len) return error.InputTooSmall;
    for (0..pass.height) |row_index| {
        const row = pass_rows[row_index * pass.row_len ..][0..pass.row_len];
        try placePngAdam7Row(info, pass, row_index, row, image);
    }
}

fn readPngPackedPixel(row: []const u8, pixel_index: usize, bits_per_pixel: usize) u8 {
    const bit_offset = pixel_index * bits_per_pixel;
    const byte_index = bit_offset / 8;
    const bit_in_byte = bit_offset % 8;
    const shift: u3 = @intCast(8 - bits_per_pixel - bit_in_byte);
    const mask: u8 = @as(u8, @intCast((@as(u16, 1) << @intCast(bits_per_pixel)) - 1));
    return (row[byte_index] >> shift) & mask;
}

fn writePngPackedPixel(row: []u8, pixel_index: usize, bits_per_pixel: usize, value: u8) void {
    const bit_offset = pixel_index * bits_per_pixel;
    const byte_index = bit_offset / 8;
    const bit_in_byte = bit_offset % 8;
    const shift: u3 = @intCast(8 - bits_per_pixel - bit_in_byte);
    const mask: u8 = @as(u8, @intCast((@as(u16, 1) << @intCast(bits_per_pixel)) - 1));
    const shifted_mask = mask << shift;
    row[byte_index] = (row[byte_index] & ~shifted_mask) | ((value & mask) << shift);
}

fn adam7PassDimension(size: usize, start: usize, step: usize) usize {
    if (size <= start) return 0;
    return ((size - 1 - start) / step) + 1;
}

fn parsePngFilterMethod(filter: u8) Error!PngFilterMethod {
    return switch (filter) {
        0 => .none,
        1 => .sub,
        2 => .up,
        3 => .average,
        4 => .paeth,
        else => error.CorruptFrame,
    };
}

fn pngPaethPredictor(left: u8, up: u8, up_left: u8) u8 {
    if (comptime builtin.target.cpu.arch == .x86_64) {
        return pngPaethPredictorStbi(left, up, up_left);
    }
    return pngPaethPredictorReference(left, up, up_left);
}

fn pngPaethPredictorReference(left: u8, up: u8, up_left: u8) u8 {
    const a: i32 = left;
    const b: i32 = up;
    const c: i32 = up_left;
    const p = a + b - c;
    const pa = absI32(p - a);
    const pb = absI32(p - b);
    const pc = absI32(p - c);
    if (pa <= pb and pa <= pc) return left;
    if (pb <= pc) return up;
    return up_left;
}

fn pngPaethPredictorStbi(left: u8, up: u8, up_left: u8) u8 {
    return pngPaethPredictorStbiI16(left, up, up_left);
}

inline fn pngPaethPredictorStbiI16(left: i16, up: i16, up_left: i16) u8 {
    // image-png uses this stb_image formulation on x86_64 because LLVM lowers
    // it to a less branchy dependency chain than the PNG specification's three
    // absolute-distance comparisons. The threshold form is exactly equivalent,
    // including PNG's left/up/up-left tie-breaking order.
    const threshold = up_left * 3 - (left + up);
    const low = @min(left, up);
    const high = @max(left, up);
    const first = if (high <= threshold) low else up_left;
    return @intCast(if (threshold <= low) high else first);
}

fn absI32(value: i32) i32 {
    return if (value < 0) -value else value;
}

/// Reconstruct one PNG scanline payload in caller-owned output storage.
///
/// `filtered` excludes the leading PNG filter byte; pass that byte separately as
/// `filter`. `previous` is the already-reconstructed previous row, or null for
/// the first row. `bytes_per_pixel` is PNG's filter byte stride, rounded up to at
/// least one byte by the caller for sub-byte color formats. Arithmetic is
/// modulo 256 as required by the PNG filter specification.
pub fn reconstructPngScanline(filter: u8, filtered: []const u8, previous: ?[]const u8, bytes_per_pixel: usize, output: []u8) Error!usize {
    const method = try parsePngFilterMethod(filter);
    if (bytes_per_pixel == 0) return error.CorruptFrame;
    if (output.len < filtered.len) return error.OutputTooSmall;
    if (previous) |prev| {
        if (prev.len != filtered.len) return error.SizeMismatch;
    }

    const reconstructed = output[0..filtered.len];
    if (method == .none) {
        copyPossiblyAliasedBytes(reconstructed, filtered);
        return filtered.len;
    }
    if (method == .sub) {
        reconstructPngSubScanline(filtered, bytes_per_pixel, reconstructed);
        return filtered.len;
    }
    if (method == .up) {
        if (previous) |prev| {
            reconstructPngUpScanline(filtered, prev, reconstructed);
        } else {
            copyPossiblyAliasedBytes(reconstructed, filtered);
        }
        return filtered.len;
    }
    if (method == .average) {
        reconstructPngAverageScanline(filtered, previous, bytes_per_pixel, reconstructed);
        return filtered.len;
    }
    if (method == .paeth and bytes_per_pixel == 1) {
        // bpp=1 covers indexed/low-bit grayscale scanline payloads after PNG's
        // "bytes per pixel is at least one" filter rule. Splitting it from the
        // generic loop avoids the per-byte stride branches while keeping the
        // same in-place behavior used by Adam7 pass reconstruction.
        reconstructPngPaethBpp1Scanline(filtered, previous, reconstructed);
        return filtered.len;
    }
    if (method == .paeth) {
        // Wider Paeth rows still have the same prefix/no-previous reductions as
        // the PNG spec's generic predictor, but spelling them out here removes
        // two hot-path stride checks per byte for common RGB/RGBA rows.
        reconstructPngPaethScanline(filtered, previous, bytes_per_pixel, reconstructed);
        return filtered.len;
    }

    for (filtered, 0..) |raw, i| {
        const left: u8 = if (i >= bytes_per_pixel) reconstructed[i - bytes_per_pixel] else 0;
        const up: u8 = if (previous) |prev| prev[i] else 0;
        const up_left: u8 = if (i >= bytes_per_pixel) blk: {
            if (previous) |prev| break :blk prev[i - bytes_per_pixel];
            break :blk 0;
        } else 0;
        const prediction: u8 = switch (method) {
            .none => 0,
            .sub => left,
            .up => up,
            .average => @intCast((@as(u16, left) + @as(u16, up)) / 2),
            .paeth => pngPaethPredictor(left, up, up_left),
        };
        reconstructed[i] = raw +% prediction;
    }
    return filtered.len;
}

fn reconstructPngUpScanline(filtered: []const u8, previous: []const u8, output: []u8) void {
    const lanes = 32;
    var i: usize = 0;
    while (i + lanes <= filtered.len) : (i += lanes) {
        const filtered_vec: @Vector(lanes, u8) = filtered[i..][0..lanes].*;
        const previous_vec: @Vector(lanes, u8) = previous[i..][0..lanes].*;
        output[i..][0..lanes].* = filtered_vec +% previous_vec;
    }
    while (i < filtered.len) : (i += 1) output[i] = filtered[i] +% previous[i];
}

fn reconstructPngAverageScanline(filtered: []const u8, previous: ?[]const u8, bytes_per_pixel: usize, output: []u8) void {
    if (bytes_per_pixel == 3) {
        return reconstructPngAverageBpp3Scanline(filtered, previous, output);
    }
    return reconstructPngAverageScanlineReference(filtered, previous, bytes_per_pixel, output);
}

fn reconstructPngAverageScanlineReference(filtered: []const u8, previous: ?[]const u8, bytes_per_pixel: usize, output: []u8) void {
    if (previous) |prev| {
        const prefix = @min(bytes_per_pixel, filtered.len);
        var i: usize = 0;
        while (i < prefix) : (i += 1) output[i] = filtered[i] +% @as(u8, @intCast(@as(u16, prev[i]) >> 1));
        while (i < filtered.len) : (i += 1) {
            output[i] = filtered[i] +% @as(u8, @intCast((@as(u16, output[i - bytes_per_pixel]) + @as(u16, prev[i])) >> 1));
        }
    } else {
        const prefix = @min(bytes_per_pixel, filtered.len);
        copyPossiblyAliasedBytes(output[0..prefix], filtered[0..prefix]);
        var i: usize = prefix;
        while (i < filtered.len) : (i += 1) output[i] = filtered[i] +% (output[i - bytes_per_pixel] >> 1);
    }
}

fn reconstructPngAverageBpp3Scanline(filtered: []const u8, previous: ?[]const u8, output: []u8) void {
    // Match image-png's fixed-bpp Average loop: keep the reconstructed RGB
    // pixel in registers instead of loading output[i - 3] for every byte.
    // Processing complete pixels also removes modulo/stride work from the hot
    // loop while the scalar tail preserves malformed/non-pixel-aligned rows.
    var left = [_]u8{ 0, 0, 0 };
    var i: usize = 0;
    if (previous) |prev| {
        while (i + 3 <= filtered.len) : (i += 3) {
            inline for (0..3) |channel| {
                const value = filtered[i + channel] +% @as(u8, @intCast((@as(u16, left[channel]) + @as(u16, prev[i + channel])) >> 1));
                output[i + channel] = value;
                left[channel] = value;
            }
        }
        while (i < filtered.len) : (i += 1) {
            const channel = i % 3;
            const value = filtered[i] +% @as(u8, @intCast((@as(u16, left[channel]) + @as(u16, prev[i])) >> 1));
            output[i] = value;
            left[channel] = value;
        }
    } else {
        while (i + 3 <= filtered.len) : (i += 3) {
            inline for (0..3) |channel| {
                const value = filtered[i + channel] +% (left[channel] >> 1);
                output[i + channel] = value;
                left[channel] = value;
            }
        }
        while (i < filtered.len) : (i += 1) {
            const channel = i % 3;
            const value = filtered[i] +% (left[channel] >> 1);
            output[i] = value;
            left[channel] = value;
        }
    }
}

fn reconstructPngPaethBpp1Scanline(filtered: []const u8, previous: ?[]const u8, output: []u8) void {
    if (previous) |prev| {
        if (filtered.len == 0) return;
        output[0] = filtered[0] +% prev[0];
        var i: usize = 1;
        while (i < filtered.len) : (i += 1) {
            output[i] = filtered[i] +% pngPaethPredictor(output[i - 1], prev[i], prev[i - 1]);
        }
    } else {
        reconstructPngSubBpp1Scanline(filtered, output);
    }
}

fn reconstructPngPaethScanline(filtered: []const u8, previous: ?[]const u8, bytes_per_pixel: usize, output: []u8) void {
    switch (bytes_per_pixel) {
        3 => return reconstructPngPaethFixedBppScanline(3, filtered, previous, output),
        4 => return reconstructPngPaethFixedBppScanline(4, filtered, previous, output),
        6 => return reconstructPngPaethFixedBppScanline(6, filtered, previous, output),
        8 => return reconstructPngPaethFixedBppScanline(8, filtered, previous, output),
        else => {},
    }
    if (previous) |prev| {
        const prefix = @min(bytes_per_pixel, filtered.len);
        var i: usize = 0;
        while (i < prefix) : (i += 1) output[i] = filtered[i] +% prev[i];
        while (i < filtered.len) : (i += 1) {
            output[i] = filtered[i] +% pngPaethPredictor(output[i - bytes_per_pixel], prev[i], prev[i - bytes_per_pixel]);
        }
    } else {
        reconstructPngSubScanline(filtered, bytes_per_pixel, output);
    }
}

fn reconstructPngPaethFixedBppScanline(comptime bytes_per_pixel: usize, filtered: []const u8, previous: ?[]const u8, output: []u8) void {
    if (previous) |prev| {
        if (comptime builtin.target.cpu.arch == .x86_64) {
            return reconstructPngPaethFixedBppScanlineX86(bytes_per_pixel, filtered, prev, output);
        }
        const prefix = @min(bytes_per_pixel, filtered.len);
        var i: usize = 0;
        while (i < prefix) : (i += 1) output[i] = filtered[i] +% prev[i];
        while (i + bytes_per_pixel <= filtered.len) : (i += bytes_per_pixel) {
            inline for (0..bytes_per_pixel) |lane| {
                output[i + lane] = filtered[i + lane] +% pngPaethPredictor(output[i + lane - bytes_per_pixel], prev[i + lane], prev[i + lane - bytes_per_pixel]);
            }
        }
        while (i < filtered.len) : (i += 1) {
            output[i] = filtered[i] +% pngPaethPredictor(output[i - bytes_per_pixel], prev[i], prev[i - bytes_per_pixel]);
        }
    } else {
        reconstructPngSubScanline(filtered, bytes_per_pixel, output);
    }
}

fn reconstructPngPaethFixedBppScanlineX86(comptime bytes_per_pixel: usize, filtered: []const u8, previous: []const u8, output: []u8) void {
    // Keep the previous reconstructed pixel (`left`) and previous-row pixel
    // (`up_left`) in the i16 representation consumed by the x86 stb predictor.
    // This mirrors image-png's scalar x86 kernel and removes one output reload
    // plus two u8->i16 extensions per channel from the dependency-heavy loop.
    var left: [bytes_per_pixel]i16 = @splat(0);
    var up_left: [bytes_per_pixel]i16 = @splat(0);
    var i: usize = 0;
    while (i + bytes_per_pixel <= filtered.len) : (i += bytes_per_pixel) {
        inline for (0..bytes_per_pixel) |lane| {
            const up: i16 = previous[i + lane];
            const value = filtered[i + lane] +% pngPaethPredictorStbiI16(left[lane], up, up_left[lane]);
            output[i + lane] = value;
            left[lane] = value;
            up_left[lane] = up;
        }
    }
    while (i < filtered.len) : (i += 1) {
        const lane = i % bytes_per_pixel;
        const up: i16 = previous[i];
        const value = filtered[i] +% pngPaethPredictorStbiI16(left[lane], up, up_left[lane]);
        output[i] = value;
        left[lane] = value;
        up_left[lane] = up;
    }
}

fn reconstructPngSubScanline(filtered: []const u8, bytes_per_pixel: usize, output: []u8) void {
    switch (bytes_per_pixel) {
        1 => return reconstructPngSubBpp1Scanline(filtered, output),
        3 => return reconstructPngSubBpp3Scanline(filtered, output),
        4 => return reconstructPngSubFixedBppScanline(4, filtered, output),
        8 => return reconstructPngSubFixedBppScanline(8, filtered, output),
        else => {},
    }
    const prefix = @min(bytes_per_pixel, filtered.len);
    copyPossiblyAliasedBytes(output[0..prefix], filtered[0..prefix]);
    var i: usize = prefix;
    while (i < filtered.len) : (i += 1) output[i] = filtered[i] +% output[i - bytes_per_pixel];
}

fn reconstructPngSubBpp3Scanline(filtered: []const u8, output: []u8) void {
    const prefix = @min(@as(usize, 3), filtered.len);
    copyPossiblyAliasedBytes(output[0..prefix], filtered[0..prefix]);
    if (filtered.len <= 3) return;

    // A 3-lane Zig vector is widened and shuffled inefficiently by the x86
    // backend. Keep the three RGB prefix sums in independent scalar registers
    // instead: each channel remains a serial dependency, while the processor
    // can advance all three channels in parallel without reloading the prior
    // pixel from output.
    var red = output[0];
    var green = output[1];
    var blue = output[2];
    var i: usize = 3;
    while (i + 3 <= filtered.len) : (i += 3) {
        red +%= filtered[i];
        green +%= filtered[i + 1];
        blue +%= filtered[i + 2];
        output[i] = red;
        output[i + 1] = green;
        output[i + 2] = blue;
    }
    if (i < filtered.len) {
        red +%= filtered[i];
        output[i] = red;
        i += 1;
    }
    if (i < filtered.len) {
        green +%= filtered[i];
        output[i] = green;
    }
}

fn reconstructPngSubFixedBppScanline(comptime bytes_per_pixel: usize, filtered: []const u8, output: []u8) void {
    const prefix = @min(bytes_per_pixel, filtered.len);
    copyPossiblyAliasedBytes(output[0..prefix], filtered[0..prefix]);
    var i: usize = prefix;
    while (i + bytes_per_pixel <= filtered.len) : (i += bytes_per_pixel) {
        const raw: @Vector(bytes_per_pixel, u8) = filtered[i..][0..bytes_per_pixel].*;
        const left: @Vector(bytes_per_pixel, u8) = output[i - bytes_per_pixel ..][0..bytes_per_pixel].*;
        output[i..][0..bytes_per_pixel].* = raw +% left;
    }
    while (i < filtered.len) : (i += 1) output[i] = filtered[i] +% output[i - bytes_per_pixel];
}

fn reconstructPngSubBpp1Scanline(filtered: []const u8, output: []u8) void {
    if (filtered.len == 0) return;
    copyPossiblyAliasedBytes(output[0..1], filtered[0..1]);
    var i: usize = 1;
    while (i < filtered.len) : (i += 1) output[i] = filtered[i] +% output[i - 1];
}

fn copyPossiblyAliasedBytes(output: []u8, input: []const u8) void {
    if (input.ptr == output.ptr) return;
    std.mem.copyForwards(u8, output, input);
}

/// Bounded-output zlib wrapper decoder.
///
/// The compressed wrapper must be complete when `init`/`reset` is called. The
/// decoder validates the zlib header/footer and raw DEFLATE payload into
/// caller-owned scratch, then `step` drains that decoded scratch through bounded
/// caller output buffers. Legacy chunked initializers also require a compressed
/// join scratch buffer; `*Direct` chunked initializers decode from caller chunks
/// directly and only require the decoded-output scratch to outlive the drain.
pub const ZlibDecoder = struct {
    decoded: []const u8 = &.{},
    frame_len: usize = 0,
    offset: usize = 0,
    done: bool = false,
    last_error_name: []const u8 = "",
    last_recoverability_hint: RecoverabilityHint = .none,

    pub const RecoverabilityHint = enum {
        none,
        corrupt_header,
        truncated_input,
        payload_corrupt,
        retry_with_dictionary,
    };

    pub const Snapshot = struct {
        output_written: usize,
        expected_output_len: usize,
        payload_remaining: usize,
        done: bool,
        last_error_name: []const u8,
        recoverability_hint: RecoverabilityHint,
    };

    pub const PngScanlineStep = struct {
        /// PNG filter method byte for the row that was just drained. This is
        /// null only when the decoder was already complete and no row was read.
        filter: ?u8 = null,
        /// Pixel/filter-payload bytes copied into the caller row buffer. The
        /// leading filter byte is intentionally excluded because PNG filters are
        /// control metadata rather than reconstructed pixel data.
        row_bytes: usize = 0,
        /// Bytes consumed from the decoded zlib payload for this row, including
        /// the leading filter byte.
        decoded_consumed: usize = 0,
        progress: core.Progress = .{},
        status: core.StepResult.Status = .need_output,
    };

    pub fn init(input: []const u8, scratch: []u8) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.reset(input, scratch);
        return self;
    }

    pub fn initWithOptions(input: []const u8, scratch: []u8, options: ZlibDecodeOptions) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetWithOptions(input, scratch, options);
        return self;
    }

    pub fn initExactSize(input: []const u8, scratch: []u8, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetExactSize(input, scratch, expected_output_len);
        return self;
    }

    pub fn initWithOptionsExactSize(input: []const u8, scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetWithOptionsExactSize(input, scratch, options, expected_output_len);
        return self;
    }

    pub fn initFromChunks(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunks(chunks, compressed_scratch, output_scratch);
        return self;
    }

    pub fn initFromChunksWithOptions(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunksWithOptions(chunks, compressed_scratch, output_scratch, options);
        return self;
    }

    pub fn initFromChunksExactSize(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunksExactSize(chunks, compressed_scratch, output_scratch, expected_output_len);
        return self;
    }

    pub fn initFromChunksWithOptionsExactSize(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunksWithOptionsExactSize(chunks, compressed_scratch, output_scratch, options, expected_output_len);
        return self;
    }

    pub fn initFromChunksDirect(chunks: []const []const u8, output_scratch: []u8) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunksDirect(chunks, output_scratch);
        return self;
    }

    pub fn initFromChunksExactSizeDirect(chunks: []const []const u8, output_scratch: []u8, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunksExactSizeDirect(chunks, output_scratch, expected_output_len);
        return self;
    }

    pub fn initFromChunksWithOptionsDirect(chunks: []const []const u8, output_scratch: []u8, options: ZlibDecodeOptions) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunksWithOptionsDirect(chunks, output_scratch, options);
        return self;
    }

    pub fn initFromChunksWithOptionsExactSizeDirect(chunks: []const []const u8, output_scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunksWithOptionsExactSizeDirect(chunks, output_scratch, options, expected_output_len);
        return self;
    }

    pub fn initWithDictionary(input: []const u8, dictionary: []const u8, scratch: []u8) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetWithDictionary(input, dictionary, scratch);
        return self;
    }

    pub fn initWithDictionaryAndOptions(input: []const u8, dictionary: []const u8, scratch: []u8, options: ZlibDecodeOptions) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetWithDictionaryAndOptions(input, dictionary, scratch, options);
        return self;
    }

    pub fn initWithDictionaryExactSize(input: []const u8, dictionary: []const u8, scratch: []u8, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetWithDictionaryExactSize(input, dictionary, scratch, expected_output_len);
        return self;
    }

    pub fn initWithDictionaryAndOptionsExactSize(input: []const u8, dictionary: []const u8, scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetWithDictionaryAndOptionsExactSize(input, dictionary, scratch, options, expected_output_len);
        return self;
    }

    pub fn initConcatenated(input: []const u8, scratch: []u8) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenated(input, scratch);
        return self;
    }

    pub fn initConcatenatedWithOptions(input: []const u8, scratch: []u8, options: ZlibDecodeOptions) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenatedWithOptions(input, scratch, options);
        return self;
    }

    pub fn initConcatenatedExactSize(input: []const u8, scratch: []u8, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenatedExactSize(input, scratch, expected_output_len);
        return self;
    }

    pub fn initConcatenatedWithOptionsExactSize(input: []const u8, scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenatedWithOptionsExactSize(input, scratch, options, expected_output_len);
        return self;
    }

    pub fn initConcatenatedWithDictionary(input: []const u8, dictionary: []const u8, scratch: []u8) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenatedWithDictionary(input, dictionary, scratch);
        return self;
    }

    pub fn initConcatenatedWithDictionaryAndOptions(input: []const u8, dictionary: []const u8, scratch: []u8, options: ZlibDecodeOptions) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenatedWithDictionaryAndOptions(input, dictionary, scratch, options);
        return self;
    }

    pub fn initConcatenatedWithDictionaryExactSize(input: []const u8, dictionary: []const u8, scratch: []u8, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenatedWithDictionaryExactSize(input, dictionary, scratch, expected_output_len);
        return self;
    }

    pub fn initConcatenatedWithDictionaryAndOptionsExactSize(input: []const u8, dictionary: []const u8, scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenatedWithDictionaryAndOptionsExactSize(input, dictionary, scratch, options, expected_output_len);
        return self;
    }

    pub fn initConcatenatedFromChunks(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenatedFromChunks(chunks, compressed_scratch, output_scratch);
        return self;
    }

    pub fn initConcatenatedFromChunksWithOptions(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenatedFromChunksWithOptions(chunks, compressed_scratch, output_scratch, options);
        return self;
    }

    pub fn initConcatenatedFromChunksExactSize(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenatedFromChunksExactSize(chunks, compressed_scratch, output_scratch, expected_output_len);
        return self;
    }

    pub fn initConcatenatedFromChunksWithOptionsExactSize(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenatedFromChunksWithOptionsExactSize(chunks, compressed_scratch, output_scratch, options, expected_output_len);
        return self;
    }

    pub fn initConcatenatedFromChunksWithDictionary(chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenatedFromChunksWithDictionary(chunks, dictionary, compressed_scratch, output_scratch);
        return self;
    }

    pub fn initConcatenatedFromChunksWithDictionaryAndOptions(chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenatedFromChunksWithDictionaryAndOptions(chunks, dictionary, compressed_scratch, output_scratch, options);
        return self;
    }

    pub fn initConcatenatedFromChunksWithDictionaryExactSize(chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenatedFromChunksWithDictionaryExactSize(chunks, dictionary, compressed_scratch, output_scratch, expected_output_len);
        return self;
    }

    pub fn initConcatenatedFromChunksWithDictionaryAndOptionsExactSize(chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetConcatenatedFromChunksWithDictionaryAndOptionsExactSize(chunks, dictionary, compressed_scratch, output_scratch, options, expected_output_len);
        return self;
    }

    pub fn initFromChunksWithDictionary(chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunksWithDictionary(chunks, dictionary, compressed_scratch, output_scratch);
        return self;
    }

    pub fn initFromChunksWithDictionaryAndOptions(chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunksWithDictionaryAndOptions(chunks, dictionary, compressed_scratch, output_scratch, options);
        return self;
    }

    pub fn initFromChunksWithDictionaryExactSize(chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunksWithDictionaryExactSize(chunks, dictionary, compressed_scratch, output_scratch, expected_output_len);
        return self;
    }

    pub fn initFromChunksWithDictionaryAndOptionsExactSize(chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunksWithDictionaryAndOptionsExactSize(chunks, dictionary, compressed_scratch, output_scratch, options, expected_output_len);
        return self;
    }

    pub fn initFromChunksWithDictionaryDirect(chunks: []const []const u8, dictionary: []const u8, output_scratch: []u8) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunksWithDictionaryDirect(chunks, dictionary, output_scratch);
        return self;
    }

    pub fn initFromChunksWithDictionaryExactSizeDirect(chunks: []const []const u8, dictionary: []const u8, output_scratch: []u8, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunksWithDictionaryExactSizeDirect(chunks, dictionary, output_scratch, expected_output_len);
        return self;
    }

    pub fn initFromChunksWithDictionaryAndOptionsDirect(chunks: []const []const u8, dictionary: []const u8, output_scratch: []u8, options: ZlibDecodeOptions) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunksWithDictionaryAndOptionsDirect(chunks, dictionary, output_scratch, options);
        return self;
    }

    pub fn initFromChunksWithDictionaryAndOptionsExactSizeDirect(chunks: []const []const u8, dictionary: []const u8, output_scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!ZlibDecoder {
        var self = ZlibDecoder{};
        try self.resetFromChunksWithDictionaryAndOptionsExactSizeDirect(chunks, dictionary, output_scratch, options, expected_output_len);
        return self;
    }

    pub fn reset(self: *ZlibDecoder, input: []const u8, scratch: []u8) Error!void {
        return self.resetWithOptions(input, scratch, .{});
    }

    pub fn resetWithOptions(self: *ZlibDecoder, input: []const u8, scratch: []u8, options: ZlibDecodeOptions) Error!void {
        const written = decodeZlibWithOptions(input, scratch, options) catch |err| {
            self.recordError(err);
            return err;
        };
        self.* = .{
            .decoded = scratch[0..written],
            .frame_len = input.len,
        };
    }

    pub fn resetExactSize(self: *ZlibDecoder, input: []const u8, scratch: []u8, expected_output_len: usize) Error!void {
        return self.resetWithOptionsExactSize(input, scratch, .{}, expected_output_len);
    }

    pub fn resetWithOptionsExactSize(self: *ZlibDecoder, input: []const u8, scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!void {
        try self.resetWithOptions(input, scratch, options);
        if (self.decoded.len != expected_output_len) {
            self.recordError(error.SizeMismatch);
            return error.SizeMismatch;
        }
    }

    pub fn resetFromChunks(self: *ZlibDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8) Error!void {
        return self.resetFromChunksWithOptions(chunks, compressed_scratch, output_scratch, .{});
    }

    pub fn resetFromChunksWithOptions(self: *ZlibDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions) Error!void {
        const joined = try joinChunks(chunks, compressed_scratch);
        return self.resetWithOptions(joined, output_scratch, options);
    }

    pub fn resetFromChunksExactSize(self: *ZlibDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, expected_output_len: usize) Error!void {
        return self.resetFromChunksWithOptionsExactSize(chunks, compressed_scratch, output_scratch, .{}, expected_output_len);
    }

    pub fn resetFromChunksWithOptionsExactSize(self: *ZlibDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!void {
        const joined = try joinChunks(chunks, compressed_scratch);
        return self.resetWithOptionsExactSize(joined, output_scratch, options, expected_output_len);
    }

    pub fn resetFromChunksDirect(self: *ZlibDecoder, chunks: []const []const u8, output_scratch: []u8) Error!void {
        return self.resetFromChunksWithOptionsDirect(chunks, output_scratch, .{});
    }

    pub fn resetFromChunksExactSizeDirect(self: *ZlibDecoder, chunks: []const []const u8, output_scratch: []u8, expected_output_len: usize) Error!void {
        return self.resetFromChunksWithOptionsExactSizeDirect(chunks, output_scratch, .{}, expected_output_len);
    }

    pub fn resetFromChunksWithOptionsDirect(self: *ZlibDecoder, chunks: []const []const u8, output_scratch: []u8, options: ZlibDecodeOptions) Error!void {
        const frame_len = try chunksTotalLen(chunks);
        const written = decodeZlibChunksWithOptionalDictionaryAndOptionsDirectKnownTotal(chunks, frame_len, output_scratch, null, options) catch |err| {
            self.recordError(err);
            return err;
        };
        self.* = .{
            .decoded = output_scratch[0..written],
            .frame_len = frame_len,
        };
    }

    pub fn resetFromChunksWithOptionsExactSizeDirect(self: *ZlibDecoder, chunks: []const []const u8, output_scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!void {
        try self.resetFromChunksWithOptionsDirect(chunks, output_scratch, options);
        if (self.decoded.len != expected_output_len) {
            self.recordError(error.SizeMismatch);
            return error.SizeMismatch;
        }
    }

    pub fn resetFromChunksWithDictionary(self: *ZlibDecoder, chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8) Error!void {
        return self.resetFromChunksWithDictionaryAndOptions(chunks, dictionary, compressed_scratch, output_scratch, .{});
    }

    pub fn resetFromChunksWithDictionaryAndOptions(self: *ZlibDecoder, chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions) Error!void {
        const joined = try joinChunks(chunks, compressed_scratch);
        return self.resetWithDictionaryAndOptions(joined, dictionary, output_scratch, options);
    }

    pub fn resetFromChunksWithDictionaryExactSize(self: *ZlibDecoder, chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8, expected_output_len: usize) Error!void {
        return self.resetFromChunksWithDictionaryAndOptionsExactSize(chunks, dictionary, compressed_scratch, output_scratch, .{}, expected_output_len);
    }

    pub fn resetFromChunksWithDictionaryAndOptionsExactSize(self: *ZlibDecoder, chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!void {
        const joined = try joinChunks(chunks, compressed_scratch);
        return self.resetWithDictionaryAndOptionsExactSize(joined, dictionary, output_scratch, options, expected_output_len);
    }

    pub fn resetFromChunksWithDictionaryDirect(self: *ZlibDecoder, chunks: []const []const u8, dictionary: []const u8, output_scratch: []u8) Error!void {
        return self.resetFromChunksWithDictionaryAndOptionsDirect(chunks, dictionary, output_scratch, .{});
    }

    pub fn resetFromChunksWithDictionaryExactSizeDirect(self: *ZlibDecoder, chunks: []const []const u8, dictionary: []const u8, output_scratch: []u8, expected_output_len: usize) Error!void {
        return self.resetFromChunksWithDictionaryAndOptionsExactSizeDirect(chunks, dictionary, output_scratch, .{}, expected_output_len);
    }

    pub fn resetFromChunksWithDictionaryAndOptionsDirect(self: *ZlibDecoder, chunks: []const []const u8, dictionary: []const u8, output_scratch: []u8, options: ZlibDecodeOptions) Error!void {
        const frame_len = try chunksTotalLen(chunks);
        const written = decodeZlibChunksWithOptionalDictionaryAndOptionsDirectKnownTotal(chunks, frame_len, output_scratch, dictionary, options) catch |err| {
            self.recordError(err);
            return err;
        };
        self.* = .{
            .decoded = output_scratch[0..written],
            .frame_len = frame_len,
        };
    }

    pub fn resetFromChunksWithDictionaryAndOptionsExactSizeDirect(self: *ZlibDecoder, chunks: []const []const u8, dictionary: []const u8, output_scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!void {
        try self.resetFromChunksWithDictionaryAndOptionsDirect(chunks, dictionary, output_scratch, options);
        if (self.decoded.len != expected_output_len) {
            self.recordError(error.SizeMismatch);
            return error.SizeMismatch;
        }
    }

    pub fn resetWithDictionary(self: *ZlibDecoder, input: []const u8, dictionary: []const u8, scratch: []u8) Error!void {
        return self.resetWithDictionaryAndOptions(input, dictionary, scratch, .{});
    }

    pub fn resetWithDictionaryAndOptions(self: *ZlibDecoder, input: []const u8, dictionary: []const u8, scratch: []u8, options: ZlibDecodeOptions) Error!void {
        const written = decodeZlibWithDictionaryAndOptions(input, scratch, dictionary, options) catch |err| {
            self.recordError(err);
            return err;
        };
        self.* = .{
            .decoded = scratch[0..written],
            .frame_len = input.len,
        };
    }

    pub fn resetWithDictionaryExactSize(self: *ZlibDecoder, input: []const u8, dictionary: []const u8, scratch: []u8, expected_output_len: usize) Error!void {
        return self.resetWithDictionaryAndOptionsExactSize(input, dictionary, scratch, .{}, expected_output_len);
    }

    pub fn resetWithDictionaryAndOptionsExactSize(self: *ZlibDecoder, input: []const u8, dictionary: []const u8, scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!void {
        try self.resetWithDictionaryAndOptions(input, dictionary, scratch, options);
        if (self.decoded.len != expected_output_len) {
            self.recordError(error.SizeMismatch);
            return error.SizeMismatch;
        }
    }

    pub fn resetConcatenated(self: *ZlibDecoder, input: []const u8, scratch: []u8) Error!void {
        return self.resetConcatenatedWithOptions(input, scratch, .{});
    }

    pub fn resetConcatenatedWithOptions(self: *ZlibDecoder, input: []const u8, scratch: []u8, options: ZlibDecodeOptions) Error!void {
        const written = decodeZlibConcatenatedWithOptions(input, scratch, options) catch |err| {
            self.recordError(err);
            return err;
        };
        self.* = .{
            .decoded = scratch[0..written],
            .frame_len = input.len,
        };
    }

    pub fn resetConcatenatedExactSize(self: *ZlibDecoder, input: []const u8, scratch: []u8, expected_output_len: usize) Error!void {
        return self.resetConcatenatedWithOptionsExactSize(input, scratch, .{}, expected_output_len);
    }

    pub fn resetConcatenatedWithOptionsExactSize(self: *ZlibDecoder, input: []const u8, scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!void {
        try self.resetConcatenatedWithOptions(input, scratch, options);
        if (self.decoded.len != expected_output_len) {
            self.recordError(error.SizeMismatch);
            return error.SizeMismatch;
        }
    }

    pub fn resetConcatenatedWithDictionary(self: *ZlibDecoder, input: []const u8, dictionary: []const u8, scratch: []u8) Error!void {
        return self.resetConcatenatedWithDictionaryAndOptions(input, dictionary, scratch, .{});
    }

    pub fn resetConcatenatedWithDictionaryAndOptions(self: *ZlibDecoder, input: []const u8, dictionary: []const u8, scratch: []u8, options: ZlibDecodeOptions) Error!void {
        const written = decodeZlibConcatenatedWithDictionaryAndOptions(input, scratch, dictionary, options) catch |err| {
            self.recordError(err);
            return err;
        };
        self.* = .{
            .decoded = scratch[0..written],
            .frame_len = input.len,
        };
    }

    pub fn resetConcatenatedWithDictionaryExactSize(self: *ZlibDecoder, input: []const u8, dictionary: []const u8, scratch: []u8, expected_output_len: usize) Error!void {
        return self.resetConcatenatedWithDictionaryAndOptionsExactSize(input, dictionary, scratch, .{}, expected_output_len);
    }

    pub fn resetConcatenatedWithDictionaryAndOptionsExactSize(self: *ZlibDecoder, input: []const u8, dictionary: []const u8, scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!void {
        try self.resetConcatenatedWithDictionaryAndOptions(input, dictionary, scratch, options);
        if (self.decoded.len != expected_output_len) {
            self.recordError(error.SizeMismatch);
            return error.SizeMismatch;
        }
    }

    pub fn resetConcatenatedFromChunks(self: *ZlibDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8) Error!void {
        return self.resetConcatenatedFromChunksWithOptions(chunks, compressed_scratch, output_scratch, .{});
    }

    pub fn resetConcatenatedFromChunksWithOptions(self: *ZlibDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions) Error!void {
        const joined = try joinChunks(chunks, compressed_scratch);
        return self.resetConcatenatedWithOptions(joined, output_scratch, options);
    }

    pub fn resetConcatenatedFromChunksExactSize(self: *ZlibDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, expected_output_len: usize) Error!void {
        return self.resetConcatenatedFromChunksWithOptionsExactSize(chunks, compressed_scratch, output_scratch, .{}, expected_output_len);
    }

    pub fn resetConcatenatedFromChunksWithOptionsExactSize(self: *ZlibDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!void {
        const joined = try joinChunks(chunks, compressed_scratch);
        return self.resetConcatenatedWithOptionsExactSize(joined, output_scratch, options, expected_output_len);
    }

    pub fn resetConcatenatedFromChunksWithDictionary(self: *ZlibDecoder, chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8) Error!void {
        return self.resetConcatenatedFromChunksWithDictionaryAndOptions(chunks, dictionary, compressed_scratch, output_scratch, .{});
    }

    pub fn resetConcatenatedFromChunksWithDictionaryAndOptions(self: *ZlibDecoder, chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions) Error!void {
        const joined = try joinChunks(chunks, compressed_scratch);
        return self.resetConcatenatedWithDictionaryAndOptions(joined, dictionary, output_scratch, options);
    }

    pub fn resetConcatenatedFromChunksWithDictionaryExactSize(self: *ZlibDecoder, chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8, expected_output_len: usize) Error!void {
        return self.resetConcatenatedFromChunksWithDictionaryAndOptionsExactSize(chunks, dictionary, compressed_scratch, output_scratch, .{}, expected_output_len);
    }

    pub fn resetConcatenatedFromChunksWithDictionaryAndOptionsExactSize(self: *ZlibDecoder, chunks: []const []const u8, dictionary: []const u8, compressed_scratch: []u8, output_scratch: []u8, options: ZlibDecodeOptions, expected_output_len: usize) Error!void {
        const joined = try joinChunks(chunks, compressed_scratch);
        return self.resetConcatenatedWithDictionaryAndOptionsExactSize(joined, dictionary, output_scratch, options, expected_output_len);
    }

    pub fn snapshot(self: *const ZlibDecoder) Snapshot {
        return .{
            .output_written = self.offset,
            .expected_output_len = self.decoded.len,
            .payload_remaining = self.decoded.len - self.offset,
            .done = self.done,
            .last_error_name = self.last_error_name,
            .recoverability_hint = self.last_recoverability_hint,
        };
    }

    fn recordError(self: *ZlibDecoder, err: Error) void {
        self.last_error_name = @errorName(err);
        self.last_recoverability_hint = switch (err) {
            error.BadZlibHeader, error.InvalidDeflateBlockType, error.InvalidDynamicBlockHeader, error.InvalidHuffmanCode => .corrupt_header,
            error.TruncatedFrame => .truncated_input,
            error.NeedDictionary, error.InvalidDictionaryTraining => .retry_with_dictionary,
            else => .payload_corrupt,
        };
    }

    fn hintName(hint: RecoverabilityHint) []const u8 {
        return switch (hint) {
            .none => "none",
            .corrupt_header => "corrupt_header",
            .truncated_input => "truncated_input",
            .payload_corrupt => "payload_corrupt",
            .retry_with_dictionary => "retry_with_dictionary",
        };
    }

    pub fn diagnostics(self: *const ZlibDecoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = if (snap.done) "done" else "payload",
            .frame_input_read = if (snap.done) self.frame_len else null,
            .output_written = snap.output_written,
            .expected_output_len = snap.expected_output_len,
            .payload_remaining = snap.payload_remaining,
            .last_error_name = snap.last_error_name,
            .last_error_phase_name = if (snap.last_error_name.len == 0) "" else "payload",
            .recoverability_hint_name = hintName(snap.recoverability_hint),
        };
    }

    pub fn step(self: *ZlibDecoder, output: []u8) Error!core.StepResult {
        if (self.done) return .{ .status = .done };
        if (output.len == 0) return .{ .status = .need_output };
        const remaining = self.decoded[self.offset..];
        const n = @min(output.len, remaining.len);
        @memcpy(output[0..n], remaining[0..n]);
        self.offset += n;
        if (self.offset == self.decoded.len) self.done = true;
        return .{
            .progress = .{ .input_read = if (self.done) self.frame_len else 0, .output_written = n },
            .status = if (self.done) .done else .need_output,
        };
    }

    pub fn stepPngScanline(self: *ZlibDecoder, row_output: []u8) Error!PngScanlineStep {
        if (self.done) return .{ .status = .done };
        const decoded_consumed = std.math.add(usize, 1, row_output.len) catch {
            self.recordError(error.IntegerOverflow);
            return error.IntegerOverflow;
        };
        if (self.decoded.len - self.offset < decoded_consumed) {
            self.recordError(error.SizeMismatch);
            return error.SizeMismatch;
        }

        const filter = self.decoded[self.offset];
        if (filter > 4) {
            // PNG filter methods are currently defined as 0..4. Catching this
            // before copying row bytes gives image decoders an exact failing row
            // boundary rather than surfacing a later reconstruction mismatch.
            self.recordError(error.CorruptFrame);
            return error.CorruptFrame;
        }

        const row_start = self.offset + 1;
        @memcpy(row_output, self.decoded[row_start..][0..row_output.len]);
        self.offset += decoded_consumed;
        if (self.offset == self.decoded.len) self.done = true;
        return .{
            .filter = filter,
            .row_bytes = row_output.len,
            .decoded_consumed = decoded_consumed,
            .progress = .{
                .input_read = if (self.done) self.frame_len else 0,
                .output_written = row_output.len,
            },
            .status = if (self.done) .done else .need_output,
        };
    }

    pub fn stepPngScanlineReconstruct(self: *ZlibDecoder, filtered_row_scratch: []u8, previous_row: ?[]const u8, bytes_per_pixel: usize, output: []u8) Error!PngScanlineStep {
        if (self.done) return .{ .status = .done };
        if (filtered_row_scratch.len < output.len) {
            self.recordError(error.OutputTooSmall);
            return error.OutputTooSmall;
        }
        if (previous_row) |prev| {
            if (prev.len != output.len) {
                self.recordError(error.SizeMismatch);
                return error.SizeMismatch;
            }
        }
        if (bytes_per_pixel == 0) {
            self.recordError(error.CorruptFrame);
            return error.CorruptFrame;
        }

        const filtered = filtered_row_scratch[0..output.len];
        const result = try self.stepPngScanline(filtered);
        if (result.filter) |filter| {
            _ = reconstructPngScanline(filter, filtered, previous_row, bytes_per_pixel, output) catch |err| {
                self.recordError(err);
                return err;
            };
        }
        return result;
    }

    pub fn stepPngScanlineReconstructDirect(self: *ZlibDecoder, previous_row: ?[]const u8, bytes_per_pixel: usize, output: []u8) Error!PngScanlineStep {
        if (self.done) return .{ .status = .done };
        if (previous_row) |prev| {
            if (prev.len != output.len) {
                self.recordError(error.SizeMismatch);
                return error.SizeMismatch;
            }
        }
        if (bytes_per_pixel == 0) {
            self.recordError(error.CorruptFrame);
            return error.CorruptFrame;
        }
        const decoded_consumed = std.math.add(usize, 1, output.len) catch {
            self.recordError(error.IntegerOverflow);
            return error.IntegerOverflow;
        };
        if (self.decoded.len - self.offset < decoded_consumed) {
            self.recordError(error.SizeMismatch);
            return error.SizeMismatch;
        }

        const filter = self.decoded[self.offset];
        if (filter > 4) {
            self.recordError(error.CorruptFrame);
            return error.CorruptFrame;
        }

        const row_start = self.offset + 1;
        const filtered = self.decoded[row_start..][0..output.len];
        if (filter == @intFromEnum(PngFilterMethod.none)) {
            @memcpy(output, filtered);
        } else {
            _ = reconstructPngScanline(filter, filtered, previous_row, bytes_per_pixel, output) catch |err| {
                self.recordError(err);
                return err;
            };
        }
        self.offset += decoded_consumed;
        if (self.offset == self.decoded.len) self.done = true;
        return .{
            .filter = filter,
            .row_bytes = output.len,
            .decoded_consumed = decoded_consumed,
            .progress = .{
                .input_read = if (self.done) self.frame_len else 0,
                .output_written = output.len,
            },
            .status = if (self.done) .done else .need_output,
        };
    }
};

fn pngScanlinePayloadLen(row_len: usize, row_count: usize) Error!usize {
    if (row_len == 0 or row_count == 0) return error.CorruptFrame;
    const stride = std.math.add(usize, row_len, 1) catch return error.IntegerOverflow;
    return std.math.mul(usize, stride, row_count) catch return error.IntegerOverflow;
}

fn pngImageOutputLen(info: PngImageInfo) Error!usize {
    if (info.row_len == 0 or info.height == 0) return error.CorruptFrame;
    return std.math.mul(usize, info.row_len, info.height) catch return error.IntegerOverflow;
}

/// PNG-oriented zlib row pipeline built from caller-owned buffers.
///
/// This is still a full-wrapper zlib decoder internally: `init`/`reset`
/// validates and materializes the IDAT zlib payload into caller-owned
/// `zlib_scratch`. Direct chunked initializers avoid a compressed join scratch
/// and decode IDAT chunks straight into that zlib scratch. The row-facing API
/// then drains exactly one filtered PNG scanline at a time, reconstructs it with
/// filter methods 0..4, and keeps the previous reconstructed row in
/// caller-owned scratch for the next prediction.
pub const PngZlibScanlineDecoder = struct {
    zlib: ZlibDecoder = .{},
    filtered_row_scratch: []u8 = &.{},
    previous_row_scratch: []u8 = &.{},
    row_len: usize = 0,
    row_count: usize = 0,
    row_index: usize = 0,
    bytes_per_pixel: usize = 0,
    has_previous: bool = false,

    pub const Snapshot = struct {
        row_len: usize,
        row_count: usize,
        rows_done: usize,
        rows_remaining: usize,
        bytes_per_pixel: usize,
        done: bool,
        zlib: ZlibDecoder.Snapshot,
    };

    pub const Step = struct {
        filter: ?u8 = null,
        row_index: usize = 0,
        row_bytes: usize = 0,
        rows_done: usize = 0,
        progress: core.Progress = .{},
        status: core.StepResult.Status = .need_output,
    };

    pub fn init(
        input: []const u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        row_len: usize,
        row_count: usize,
        bytes_per_pixel: usize,
    ) Error!PngZlibScanlineDecoder {
        var self = PngZlibScanlineDecoder{};
        try self.reset(input, zlib_scratch, filtered_row_scratch, previous_row_scratch, row_len, row_count, bytes_per_pixel);
        return self;
    }

    pub fn initFromChunks(
        chunks: []const []const u8,
        compressed_scratch: []u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        row_len: usize,
        row_count: usize,
        bytes_per_pixel: usize,
    ) Error!PngZlibScanlineDecoder {
        var self = PngZlibScanlineDecoder{};
        try self.resetFromChunks(chunks, compressed_scratch, zlib_scratch, filtered_row_scratch, previous_row_scratch, row_len, row_count, bytes_per_pixel);
        return self;
    }

    pub fn initWithInfo(
        input: []const u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
    ) Error!PngZlibScanlineDecoder {
        return init(input, zlib_scratch, filtered_row_scratch, previous_row_scratch, info.row_len, info.height, info.bytes_per_pixel);
    }

    pub fn initWithInfoAndOptions(
        input: []const u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
        options: ZlibDecodeOptions,
    ) Error!PngZlibScanlineDecoder {
        var self = PngZlibScanlineDecoder{};
        try self.resetWithInfoAndOptions(input, zlib_scratch, filtered_row_scratch, previous_row_scratch, info, options);
        return self;
    }

    pub fn initFromChunksWithInfo(
        chunks: []const []const u8,
        compressed_scratch: []u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
    ) Error!PngZlibScanlineDecoder {
        return initFromChunks(chunks, compressed_scratch, zlib_scratch, filtered_row_scratch, previous_row_scratch, info.row_len, info.height, info.bytes_per_pixel);
    }

    pub fn initFromChunksDirect(
        chunks: []const []const u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        row_len: usize,
        row_count: usize,
        bytes_per_pixel: usize,
    ) Error!PngZlibScanlineDecoder {
        var self = PngZlibScanlineDecoder{};
        try self.resetFromChunksDirect(chunks, zlib_scratch, filtered_row_scratch, previous_row_scratch, row_len, row_count, bytes_per_pixel);
        return self;
    }

    pub fn initFromChunksWithInfoDirect(
        chunks: []const []const u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
    ) Error!PngZlibScanlineDecoder {
        return initFromChunksDirect(chunks, zlib_scratch, filtered_row_scratch, previous_row_scratch, info.row_len, info.height, info.bytes_per_pixel);
    }

    pub fn initFromChunksWithOptionsDirect(
        chunks: []const []const u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        row_len: usize,
        row_count: usize,
        bytes_per_pixel: usize,
        options: ZlibDecodeOptions,
    ) Error!PngZlibScanlineDecoder {
        var self = PngZlibScanlineDecoder{};
        try self.resetFromChunksWithOptionsDirect(chunks, zlib_scratch, filtered_row_scratch, previous_row_scratch, row_len, row_count, bytes_per_pixel, options);
        return self;
    }

    pub fn initFromChunksWithInfoAndOptionsDirect(
        chunks: []const []const u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
        options: ZlibDecodeOptions,
    ) Error!PngZlibScanlineDecoder {
        return initFromChunksWithOptionsDirect(chunks, zlib_scratch, filtered_row_scratch, previous_row_scratch, info.row_len, info.height, info.bytes_per_pixel, options);
    }

    pub fn reset(
        self: *PngZlibScanlineDecoder,
        input: []const u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        row_len: usize,
        row_count: usize,
        bytes_per_pixel: usize,
    ) Error!void {
        const expected_payload_len = try validateConfig(row_len, row_count, bytes_per_pixel, filtered_row_scratch, previous_row_scratch);
        self.* = .{
            .filtered_row_scratch = filtered_row_scratch[0..row_len],
            .previous_row_scratch = previous_row_scratch[0..row_len],
            .row_len = row_len,
            .row_count = row_count,
            .bytes_per_pixel = bytes_per_pixel,
        };
        self.zlib = try ZlibDecoder.initExactSize(input, zlib_scratch, expected_payload_len);
    }

    pub fn resetWithInfo(
        self: *PngZlibScanlineDecoder,
        input: []const u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
    ) Error!void {
        return self.reset(input, zlib_scratch, filtered_row_scratch, previous_row_scratch, info.row_len, info.height, info.bytes_per_pixel);
    }

    pub fn resetWithInfoAndOptions(
        self: *PngZlibScanlineDecoder,
        input: []const u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
        options: ZlibDecodeOptions,
    ) Error!void {
        const expected_payload_len = try validateConfig(info.row_len, info.height, info.bytes_per_pixel, filtered_row_scratch, previous_row_scratch);
        self.* = .{
            .filtered_row_scratch = filtered_row_scratch[0..info.row_len],
            .previous_row_scratch = previous_row_scratch[0..info.row_len],
            .row_len = info.row_len,
            .row_count = info.height,
            .bytes_per_pixel = info.bytes_per_pixel,
        };
        self.zlib = try ZlibDecoder.initWithOptionsExactSize(input, zlib_scratch, options, expected_payload_len);
    }

    pub fn resetFromChunks(
        self: *PngZlibScanlineDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        row_len: usize,
        row_count: usize,
        bytes_per_pixel: usize,
    ) Error!void {
        const expected_payload_len = try validateConfig(row_len, row_count, bytes_per_pixel, filtered_row_scratch, previous_row_scratch);
        self.* = .{
            .filtered_row_scratch = filtered_row_scratch[0..row_len],
            .previous_row_scratch = previous_row_scratch[0..row_len],
            .row_len = row_len,
            .row_count = row_count,
            .bytes_per_pixel = bytes_per_pixel,
        };
        self.zlib = try ZlibDecoder.initFromChunksExactSize(chunks, compressed_scratch, zlib_scratch, expected_payload_len);
    }

    pub fn resetFromChunksWithInfo(
        self: *PngZlibScanlineDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
    ) Error!void {
        return self.resetFromChunks(chunks, compressed_scratch, zlib_scratch, filtered_row_scratch, previous_row_scratch, info.row_len, info.height, info.bytes_per_pixel);
    }

    pub fn resetFromChunksDirect(
        self: *PngZlibScanlineDecoder,
        chunks: []const []const u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        row_len: usize,
        row_count: usize,
        bytes_per_pixel: usize,
    ) Error!void {
        return self.resetFromChunksWithOptionsDirect(chunks, zlib_scratch, filtered_row_scratch, previous_row_scratch, row_len, row_count, bytes_per_pixel, .{});
    }

    pub fn resetFromChunksWithInfoDirect(
        self: *PngZlibScanlineDecoder,
        chunks: []const []const u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
    ) Error!void {
        return self.resetFromChunksDirect(chunks, zlib_scratch, filtered_row_scratch, previous_row_scratch, info.row_len, info.height, info.bytes_per_pixel);
    }

    pub fn resetFromChunksWithOptionsDirect(
        self: *PngZlibScanlineDecoder,
        chunks: []const []const u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        row_len: usize,
        row_count: usize,
        bytes_per_pixel: usize,
        options: ZlibDecodeOptions,
    ) Error!void {
        const expected_payload_len = try validateConfig(row_len, row_count, bytes_per_pixel, filtered_row_scratch, previous_row_scratch);
        self.* = .{
            .filtered_row_scratch = filtered_row_scratch[0..row_len],
            .previous_row_scratch = previous_row_scratch[0..row_len],
            .row_len = row_len,
            .row_count = row_count,
            .bytes_per_pixel = bytes_per_pixel,
        };
        self.zlib = try ZlibDecoder.initFromChunksWithOptionsExactSizeDirect(chunks, zlib_scratch, options, expected_payload_len);
    }

    pub fn resetFromChunksWithInfoAndOptionsDirect(
        self: *PngZlibScanlineDecoder,
        chunks: []const []const u8,
        zlib_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
        options: ZlibDecodeOptions,
    ) Error!void {
        return self.resetFromChunksWithOptionsDirect(chunks, zlib_scratch, filtered_row_scratch, previous_row_scratch, info.row_len, info.height, info.bytes_per_pixel, options);
    }

    fn validateConfig(row_len: usize, row_count: usize, bytes_per_pixel: usize, filtered_row_scratch: []u8, previous_row_scratch: []u8) Error!usize {
        if (bytes_per_pixel == 0) return error.CorruptFrame;
        const expected_payload_len = try pngScanlinePayloadLen(row_len, row_count);
        if (filtered_row_scratch.len < row_len or previous_row_scratch.len < row_len) return error.OutputTooSmall;
        return expected_payload_len;
    }

    pub fn snapshot(self: *const PngZlibScanlineDecoder) Snapshot {
        return .{
            .row_len = self.row_len,
            .row_count = self.row_count,
            .rows_done = self.row_index,
            .rows_remaining = self.row_count - self.row_index,
            .bytes_per_pixel = self.bytes_per_pixel,
            .done = self.row_index == self.row_count,
            .zlib = self.zlib.snapshot(),
        };
    }

    pub fn diagnostics(self: *const PngZlibScanlineDecoder) core.StreamingDiagnostics {
        return self.zlib.diagnostics();
    }

    pub fn step(self: *PngZlibScanlineDecoder, output: []u8) Error!Step {
        if (self.row_index == self.row_count) return .{
            .row_index = self.row_index,
            .rows_done = self.row_index,
            .status = .done,
        };
        if (output.len < self.row_len) {
            self.zlib.recordError(error.OutputTooSmall);
            return error.OutputTooSmall;
        }

        const row_output = output[0..self.row_len];
        const previous = if (self.has_previous) self.previous_row_scratch else null;
        const result = try self.zlib.stepPngScanlineReconstruct(self.filtered_row_scratch, previous, self.bytes_per_pixel, row_output);
        @memcpy(self.previous_row_scratch, row_output);
        self.has_previous = true;

        const row_index = self.row_index;
        self.row_index += 1;
        const done = self.row_index == self.row_count;
        if (done != self.zlib.snapshot().done) {
            self.zlib.recordError(error.SizeMismatch);
            return error.SizeMismatch;
        }

        return .{
            .filter = result.filter,
            .row_index = row_index,
            .row_bytes = self.row_len,
            .rows_done = self.row_index,
            .progress = result.progress,
            .status = if (done) .done else .need_output,
        };
    }

    fn stepWithPrevious(self: *PngZlibScanlineDecoder, output: []u8, previous: ?[]const u8) Error!Step {
        if (self.row_index == self.row_count) return .{
            .row_index = self.row_index,
            .rows_done = self.row_index,
            .status = .done,
        };
        if (output.len < self.row_len) {
            self.zlib.recordError(error.OutputTooSmall);
            return error.OutputTooSmall;
        }

        const row_output = output[0..self.row_len];
        const result = try self.zlib.stepPngScanline(row_output);
        if (result.filter) |filter| {
            _ = reconstructPngScanline(filter, row_output, previous, self.bytes_per_pixel, row_output) catch |err| {
                self.zlib.recordError(err);
                return err;
            };
        }

        const row_index = self.row_index;
        self.row_index += 1;
        const done = self.row_index == self.row_count;
        if (done != self.zlib.snapshot().done) {
            self.zlib.recordError(error.SizeMismatch);
            return error.SizeMismatch;
        }

        return .{
            .filter = result.filter,
            .row_index = row_index,
            .row_bytes = self.row_len,
            .rows_done = self.row_index,
            .progress = result.progress,
            .status = if (done) .done else .need_output,
        };
    }
};

const PngStreamingDynamicLiteralDecoder = union(enum) {
    fast9: huffman.FastDecoder(286, 9),
    fast11: huffman.FastDecoder(286, 11),

    inline fn initWithBits(lookup_bits: u4, table: huffman.HuffmanTable(286)) PngStreamingDynamicLiteralDecoder {
        return switch (lookup_bits) {
            9 => .{ .fast9 = huffman.FastDecoder(286, 9).init(table) },
            else => .{ .fast11 = huffman.FastDecoder(286, 11).init(table) },
        };
    }

    inline fn decodeValue9(self: *const PngStreamingDynamicLiteralDecoder, reader: anytype) Error!u16 {
        return self.fast9.decodeValue(reader);
    }

    inline fn decodeValue11(self: *const PngStreamingDynamicLiteralDecoder, reader: anytype) Error!u16 {
        return self.fast11.decodeValue(reader);
    }
};

fn pngStreamingDynamicLiteralLookupBits(parsed: huffman.DynamicLengths) u4 {
    // Keep the PNG row-streaming policy in sync with the one-shot dynamic
    // inflater: short alphabets use the smaller 9-bit table, and all longer
    // dynamic literal alphabets currently share the cache-friendlier 11-bit
    // table. The real PNG IDAT profile tracks lookup covered/size totals so
    // this state tradeoff remains visible when the corpus shifts.
    return dynamicLiteralLookupBits(parsed);
}

inline fn readPngStreamingDynamicInflatedByte(self: anytype, comptime lit_lookup_bits: u4) Error!?u8 {
    const symbol = switch (lit_lookup_bits) {
        9 => try self.dynamic_lit.decodeValue9(&self.reader),
        else => try self.dynamic_lit.decodeValue11(&self.reader),
    };
    if (symbol < 256) return self.emitByte(@intCast(symbol));
    if (symbol == 256) {
        self.finishCurrentBlock();
        return null;
    }
    if (symbol > 285) return error.InvalidHuffmanCode;
    const length = try decodeLength(symbol, &self.reader);
    const distance_symbol = try self.dynamic_dist.decodeValue(&self.reader);
    const distance = try decodeDistance(distance_symbol, &self.reader);
    try self.startPendingMatch(length, distance);
    return null;
}

fn readPngStreamingInflatedBytes(self: anytype, output: []u8) Error!void {
    var out_i: usize = 0;
    while (out_i < output.len) {
        if (self.pending_match_remaining != 0) {
            const copied = try copyPngStreamingPendingMatch(self, output[out_i..]);
            out_i += copied;
            continue;
        }

        switch (self.block_kind) {
            .need_header => {
                try self.startNextBlock();
            },
            .stored => {
                if (self.stored_remaining == 0) {
                    self.finishCurrentBlock();
                    continue;
                }
                const count = @min(output.len - out_i, self.stored_remaining);
                const dest = output[out_i..][0..count];
                try self.reader.readAlignedBytes(dest);
                self.stored_remaining -= count;
                self.recordInflatedBytes(dest);
                out_i += count;
                if (self.stored_remaining == 0) self.finishCurrentBlock();
            },
            .fixed => {
                out_i += try readPngStreamingFixedInflatedBytes(self, output[out_i..]);
            },
            .dynamic9 => out_i += try readPngStreamingDynamicInflatedBytes(self, output[out_i..], 9),
            .dynamic11 => out_i += try readPngStreamingDynamicInflatedBytes(self, output[out_i..], 11),
            .done => return error.SizeMismatch,
        }
    }
}

fn readPngStreamingFixedInflatedBytes(self: anytype, output: []u8) Error!usize {
    var out_i: usize = 0;
    while (out_i < output.len) {
        const symbol = try huffman.decodeFixedLiteralValueFast(&self.reader);
        if (symbol < 256) {
            @branchHint(.likely);
            output[out_i] = @intCast(symbol);
            out_i += 1;
            continue;
        }

        // Literal-heavy PNG streams otherwise update Adler/history one byte at
        // a time. A length/end marker is the first point where the already
        // decoded literal run must become visible to DEFLATE history, so flush
        // the run in one batch before handling that marker.
        if (out_i != 0) self.recordInflatedBytes(output[0..out_i]);
        if (symbol == 256) {
            self.finishCurrentBlock();
            return out_i;
        }
        if (symbol > 285) return error.InvalidHuffmanCode;
        const length = try decodeLength(symbol, &self.reader);
        const distance_symbol = try huffman.decodeFixedDistanceValueFast(&self.reader);
        const distance = try decodeDistance(distance_symbol, &self.reader);
        try self.startPendingMatch(length, distance);
        out_i += try copyPngStreamingPendingMatch(self, output[out_i..]);
        return out_i;
    }
    if (out_i != 0) self.recordInflatedBytes(output[0..out_i]);
    return out_i;
}

fn readPngStreamingDynamicInflatedBytes(self: anytype, output: []u8, comptime lit_lookup_bits: u4) Error!usize {
    const lit_decoder = if (comptime lit_lookup_bits == 9)
        &self.dynamic_lit.fast9
    else
        &self.dynamic_lit.fast11;
    var out_i: usize = 0;
    while (out_i < output.len) {
        const symbol = try lit_decoder.decodeValue(&self.reader);
        if (symbol < 256) {
            @branchHint(.likely);
            output[out_i] = @intCast(symbol);
            out_i += 1;
            continue;
        }

        // Dynamic PNG IDAT blocks are often literal dominated (notably the
        // Lohengrin priority fixture). Batch the literal run into Adler/history
        // once; this keeps later match distances correct without paying the
        // per-byte `emitByte` overhead for every literal.
        if (out_i != 0) self.recordInflatedBytes(output[0..out_i]);
        if (symbol == 256) {
            self.finishCurrentBlock();
            return out_i;
        }
        if (symbol > 285) return error.InvalidHuffmanCode;
        const length = try decodeLength(symbol, &self.reader);
        const distance_symbol = try self.dynamic_dist.decodeValue(&self.reader);
        const distance = try decodeDistance(distance_symbol, &self.reader);
        try self.startPendingMatch(length, distance);
        out_i += try copyPngStreamingPendingMatch(self, output[out_i..]);
        return out_i;
    }
    if (out_i != 0) self.recordInflatedBytes(output[0..out_i]);
    return out_i;
}

fn copyPngStreamingPendingMatch(self: anytype, output: []u8) Error!usize {
    if (output.len == 0 or self.pending_match_remaining == 0) return 0;
    const count = @min(output.len, self.pending_match_remaining);
    const dest = output[0..count];
    const distance = self.pending_match_distance;
    if (distance == 0 or distance > self.history_len) return error.InvalidMatch;

    // PNG row streaming normally asks for a whole filtered scanline after the
    // filter byte. Emitting match bytes one at a time makes repetitive rows pay
    // the full per-byte Adler/history/read-state overhead. Batch the already
    // pending DEFLATE match into the caller's row buffer while updating the same
    // rolling history and deferred Adler state that `emitByte` maintains.
    if (distance == 1) {
        const byte = self.history[wrapAddPowerOfTwo(self.history_pos, self.history.len - 1, self.history.len)];
        @memset(dest, byte);
        recordPngStreamingRepeatedByte(self, byte, dest.len);
    } else if (distance <= 4) {
        const history_len = self.history.len;
        var pattern: [4]u8 = undefined;
        switch (distance) {
            2 => {
                pattern[0] = self.history[wrapAddPowerOfTwo(self.history_pos, history_len - 2, history_len)];
                pattern[1] = self.history[wrapAddPowerOfTwo(self.history_pos, history_len - 1, history_len)];
            },
            3 => {
                pattern[0] = self.history[wrapAddPowerOfTwo(self.history_pos, history_len - 3, history_len)];
                pattern[1] = self.history[wrapAddPowerOfTwo(self.history_pos, history_len - 2, history_len)];
                pattern[2] = self.history[wrapAddPowerOfTwo(self.history_pos, history_len - 1, history_len)];
            },
            4 => {
                pattern[0] = self.history[wrapAddPowerOfTwo(self.history_pos, history_len - 4, history_len)];
                pattern[1] = self.history[wrapAddPowerOfTwo(self.history_pos, history_len - 3, history_len)];
                pattern[2] = self.history[wrapAddPowerOfTwo(self.history_pos, history_len - 2, history_len)];
                pattern[3] = self.history[wrapAddPowerOfTwo(self.history_pos, history_len - 1, history_len)];
            },
            else => unreachable,
        }
        copySmallDistanceMatch(dest, pattern[0..distance], distance);
        self.recordInflatedBytes(dest);
    } else if (distance >= dest.len) {
        try copyPngStreamingHistoryBytes(self, distance, dest);
        self.recordInflatedBytes(dest);
    } else {
        try copyPngStreamingOverlappingHistoryBytes(self, distance, dest);
        self.recordInflatedBytes(dest);
    }
    self.pending_match_remaining -= count;
    return count;
}

fn recordPngStreamingRepeatedByte(self: anytype, byte: u8, count: usize) void {
    if (count == 0) return;
    updatePngStreamingAdlerRepeatedByte(self, byte, count);
    recordPngStreamingHistoryRepeatedByte(self, byte, count);
}

fn copyPngStreamingHistoryBytes(self: anytype, distance: usize, dest: []u8) Error!void {
    if (distance == 0 or distance > self.history_len) return error.InvalidMatch;
    const history_len = self.history.len;
    var src = wrapAddPowerOfTwo(self.history_pos, history_len - distance, history_len);
    var dest_i: usize = 0;
    while (dest_i < dest.len) {
        const n = @min(dest.len - dest_i, history_len - src);
        @memcpy(dest[dest_i..][0..n], self.history[src..][0..n]);
        dest_i += n;
        src = 0;
    }
}

fn copyPngStreamingOverlappingHistoryBytes(self: anytype, distance: usize, dest: []u8) Error!void {
    if (distance == 0 or distance > self.history_len or distance >= dest.len) return error.InvalidMatch;

    // The streaming PNG inflater keeps DEFLATE history in a ring buffer. For an
    // overlapping match, seed exactly one distance-sized window from that ring in
    // chronological order, then replay from the just-written destination prefix
    // with the same doubling strategy used by caller-owned inflate. Updating the
    // rolling history after the full row span is safe because the destination
    // prefix already contains the bytes that byte-at-a-time DEFLATE replay would
    // have observed.
    const history_len = self.history.len;
    var src = wrapAddPowerOfTwo(self.history_pos, history_len - distance, history_len);
    var copied: usize = 0;
    while (copied < distance) {
        const n = @min(distance - copied, history_len - src);
        @memcpy(dest[copied..][0..n], self.history[src..][0..n]);
        copied += n;
        src = 0;
    }
    while (copied < dest.len) {
        const n = @min(copied, dest.len - copied);
        @memcpy(dest[copied..][0..n], dest[0..n]);
        copied += n;
    }
}

fn updatePngStreamingAdlerRepeatedByte(self: anytype, byte: u8, count: usize) void {
    if (self.options.ignore_adler) return;
    var remaining = count;
    const value: u64 = byte;
    while (remaining != 0) {
        if (self.adler_pending == checksum.adler32_nmax) self.reduceAdler();
        const capacity = checksum.adler32_nmax - self.adler_pending;
        const take = @min(remaining, capacity);
        const a0: u64 = self.adler.a;
        const b0: u64 = self.adler.b;
        const n: u64 = @intCast(take);
        const a = a0 + n * value;
        // Fold a repeated byte run without rereading the row buffer we just
        // memset. Adler-32's `b` sum observes the prefix after each byte:
        //   b' = b + n*a + value * (1 + 2 + ... + n)
        // Chunking at NMAX preserves the same deferred-reduction bound as the
        // scalar `updateAdlerByte` path while using u64 temporaries for the
        // triangular term.
        const b = b0 + n * a0 + value * n * (n + 1) / 2;
        self.adler_pending += take;
        if (self.adler_pending == checksum.adler32_nmax) {
            self.adler.a = @intCast(a % checksum.adler32_modulus);
            self.adler.b = @intCast(b % checksum.adler32_modulus);
            self.adler_pending = 0;
        } else {
            self.adler.a = @intCast(a);
            self.adler.b = @intCast(b);
        }
        remaining -= take;
    }
}

fn recordPngStreamingHistoryRepeatedByte(self: anytype, byte: u8, count: usize) void {
    std.debug.assert(self.history.len != 0);
    const history_len = self.history.len;
    if (count >= history_len) {
        @memset(self.history, byte);
        self.history_pos = wrapAddPowerOfTwo(self.history_pos, count, history_len);
        self.history_len = history_len;
        return;
    }

    const first = @min(count, history_len - self.history_pos);
    @memset(self.history[self.history_pos..][0..first], byte);
    const second = count - first;
    if (second != 0) @memset(self.history[0..second], byte);
    self.history_pos = wrapAddPowerOfTwo(self.history_pos, count, history_len);
    self.history_len = @min(self.history_len + count, history_len);
}

fn updatePngStreamingAdlerBytes(self: anytype, bytes: []const u8) void {
    if (self.options.ignore_adler) return;
    if (bytes.len >= 64) {
        if (self.adler_pending != 0) self.reduceAdler();
        self.adler.update(bytes);
        self.adler_pending = 0;
        return;
    }
    for (bytes) |byte| self.updateAdlerByte(byte);
}

fn recordPngStreamingHistoryBytes(self: anytype, bytes: []const u8) void {
    if (bytes.len == 0) return;
    std.debug.assert(self.history.len != 0);

    const history_len = self.history.len;
    const original_len = bytes.len;
    var tail = bytes;
    if (tail.len >= history_len) {
        // Only the final 32 KiB DEFLATE history window can be referenced by a
        // later match. Wide PNG scanlines and long RLE matches may hand us more
        // than that at once; copying the prefix into the ring is pure churn
        // because the suffix overwrites it before any later symbol can observe
        // the intermediate state. Advance the cursor as if the skipped prefix
        // had been written, then materialize just the retained tail window.
        const skip = tail.len - history_len;
        self.history_pos = wrapAddPowerOfTwo(self.history_pos, skip, history_len);
        tail = tail[skip..];
    }

    var index: usize = 0;
    while (index < tail.len) {
        const first = @min(tail.len - index, history_len - self.history_pos);
        @memcpy(self.history[self.history_pos..][0..first], tail[index..][0..first]);
        self.history_pos = wrapAddPowerOfTwo(self.history_pos, first, history_len);
        index += first;
    }
    self.history_len = @min(self.history_len + original_len, history_len);
}

inline fn wrapAddPowerOfTwo(index: usize, addend: usize, modulus: usize) usize {
    std.debug.assert(modulus != 0);
    std.debug.assert(std.math.isPowerOfTwo(modulus));
    // PNG streaming inflate always slices the caller history scratch to the
    // DEFLATE 32 KiB window (and tests use smaller power-of-two windows). The
    // ring cursor sits on the per-byte literal/match hot path, so use the
    // power-of-two mask instead of a general integer remainder.
    const mask = modulus - 1;
    return (index +% (addend & mask)) & mask;
}

/// Incremental zlib/DEFLATE PNG row decoder for contiguous IDAT payloads.
///
/// `PngZlibScanlineDecoder` exposes a row API but first materializes the entire
/// inflated IDAT payload into `zlib_scratch`. This decoder removes that
/// image-sized scratch for contiguous zlib streams: it keeps only the two PNG
/// row buffers plus a caller-owned 32 KiB DEFLATE history window, then produces
/// one reconstructed scanline per `step`.
///
/// The history window is still required for fixed/dynamic Huffman blocks because
/// DEFLATE matches may reference bytes up to 32 KiB behind the current output.
/// Stored-only streams should continue to use `PngStoredZlibScanlineDecoder`,
/// which avoids even that history buffer and can batch-copy stored payloads.
pub const PngStreamingZlibScanlineDecoder = struct {
    input: []const u8 = &.{},
    options: ZlibDecodeOptions = .{},
    reader: bitstream.BufferedBitReader = bitstream.BufferedBitReader.init(""),
    raw_base_offset: usize = 0,
    block_kind: BlockKind = .need_header,
    final_block: bool = false,
    stored_remaining: usize = 0,
    pending_match_remaining: usize = 0,
    pending_match_distance: usize = 0,
    dynamic_lit: PngStreamingDynamicLiteralDecoder = undefined,
    dynamic_dist: DynamicDistanceDecoder = undefined,
    history: []u8 = &.{},
    history_pos: usize = 0,
    history_len: usize = 0,
    adler: checksum.Adler32 = .{},
    adler_pending: usize = 0,
    filtered_row_scratch: []u8 = &.{},
    previous_row_scratch: []u8 = &.{},
    row_len: usize = 0,
    row_count: usize = 0,
    row_index: usize = 0,
    bytes_per_pixel: usize = 0,
    has_previous: bool = false,
    finished: bool = false,
    finished_input_read: usize = 0,
    last_error_name: []const u8 = "",
    last_recoverability_hint: ZlibDecoder.RecoverabilityHint = .none,

    const BlockKind = enum { need_header, stored, fixed, dynamic9, dynamic11, done };

    pub const Snapshot = struct {
        row_len: usize,
        row_count: usize,
        rows_done: usize,
        rows_remaining: usize,
        bytes_per_pixel: usize,
        done: bool,
        input_read: usize,
        history_len: usize,
        last_error_name: []const u8,
        recoverability_hint: ZlibDecoder.RecoverabilityHint,
    };

    pub const Step = PngZlibScanlineDecoder.Step;
    pub const history_scratch_len = lz77.default_window_len;

    pub fn initWithInfo(
        input: []const u8,
        history_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
    ) Error!PngStreamingZlibScanlineDecoder {
        return initWithInfoAndOptions(input, history_scratch, filtered_row_scratch, previous_row_scratch, info, .{});
    }

    pub fn initWithInfoAndOptions(
        input: []const u8,
        history_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
        options: ZlibDecodeOptions,
    ) Error!PngStreamingZlibScanlineDecoder {
        var self = PngStreamingZlibScanlineDecoder{};
        try self.resetWithInfoAndOptions(input, history_scratch, filtered_row_scratch, previous_row_scratch, info, options);
        return self;
    }

    pub fn initRawWithOptions(
        input: []const u8,
        history_scratch: []u8,
        options: ZlibDecodeOptions,
    ) Error!PngStreamingZlibScanlineDecoder {
        var self = PngStreamingZlibScanlineDecoder{};
        try self.resetRawWithOptions(input, history_scratch, options);
        return self;
    }

    pub fn resetWithInfo(
        self: *PngStreamingZlibScanlineDecoder,
        input: []const u8,
        history_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
    ) Error!void {
        return self.resetWithInfoAndOptions(input, history_scratch, filtered_row_scratch, previous_row_scratch, info, .{});
    }

    pub fn resetWithInfoAndOptions(
        self: *PngStreamingZlibScanlineDecoder,
        input: []const u8,
        history_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
        options: ZlibDecodeOptions,
    ) Error!void {
        _ = try PngZlibScanlineDecoder.validateConfig(info.row_len, info.height, info.bytes_per_pixel, filtered_row_scratch, previous_row_scratch);
        if (history_scratch.len < history_scratch_len) return error.OutputTooSmall;
        const header = try parseZlibHeader(input, null);
        self.* = .{
            .input = input,
            .options = options,
            .reader = bitstream.BufferedBitReader.init(input[header.data_offset..]),
            .raw_base_offset = header.data_offset,
            .history = history_scratch[0..history_scratch_len],
            .filtered_row_scratch = filtered_row_scratch[0..info.row_len],
            .previous_row_scratch = previous_row_scratch[0..info.row_len],
            .row_len = info.row_len,
            .row_count = info.height,
            .bytes_per_pixel = info.bytes_per_pixel,
        };
    }

    pub fn resetRawWithOptions(
        self: *PngStreamingZlibScanlineDecoder,
        input: []const u8,
        history_scratch: []u8,
        options: ZlibDecodeOptions,
    ) Error!void {
        if (history_scratch.len < history_scratch_len) return error.OutputTooSmall;
        const header = try parseZlibHeader(input, null);
        self.* = .{
            .input = input,
            .options = options,
            .reader = bitstream.BufferedBitReader.init(input[header.data_offset..]),
            .raw_base_offset = header.data_offset,
            .history = history_scratch[0..history_scratch_len],
        };
    }

    pub fn snapshot(self: *const PngStreamingZlibScanlineDecoder) Snapshot {
        const input_read = if (self.finished)
            self.finished_input_read
        else
            self.raw_base_offset + self.reader.byteOffset();
        return .{
            .row_len = self.row_len,
            .row_count = self.row_count,
            .rows_done = self.row_index,
            .rows_remaining = self.row_count - self.row_index,
            .bytes_per_pixel = self.bytes_per_pixel,
            .done = self.finished,
            .input_read = input_read,
            .history_len = self.history_len,
            .last_error_name = self.last_error_name,
            .recoverability_hint = self.last_recoverability_hint,
        };
    }

    pub fn diagnostics(self: *const PngStreamingZlibScanlineDecoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = if (snap.done) "done" else "payload",
            .frame_input_read = if (snap.done) snap.input_read else null,
            .output_written = snap.rows_done *| snap.row_len,
            .expected_output_len = snap.row_count *| snap.row_len,
            .payload_remaining = snap.rows_remaining *| (snap.row_len +| 1),
            .last_error_name = snap.last_error_name,
            .last_error_phase_name = if (snap.last_error_name.len == 0) "" else "payload",
            .recoverability_hint_name = ZlibDecoder.hintName(snap.recoverability_hint),
        };
    }

    pub fn step(self: *PngStreamingZlibScanlineDecoder, output: []u8) Error!Step {
        return self.stepInternal(output) catch |err| {
            self.recordError(err);
            return err;
        };
    }

    fn stepInternal(self: *PngStreamingZlibScanlineDecoder, output: []u8) Error!Step {
        if (self.row_index == self.row_count) {
            try self.finish();
            return .{ .row_index = self.row_index, .rows_done = self.row_index, .status = .done };
        }
        if (output.len < self.row_len) return error.OutputTooSmall;

        const filter = (try self.readInflatedByteOrEnd()) orelse return error.SizeMismatch;
        if (filter > 4) return error.CorruptFrame;
        try self.readInflatedBytes(self.filtered_row_scratch);
        const previous = if (self.has_previous) self.previous_row_scratch else null;
        const row_output = output[0..self.row_len];
        _ = try reconstructPngScanline(filter, self.filtered_row_scratch, previous, self.bytes_per_pixel, row_output);
        @memcpy(self.previous_row_scratch, row_output);
        self.has_previous = true;

        const row_index = self.row_index;
        self.row_index += 1;
        const done = self.row_index == self.row_count;
        if (done) try self.finish();
        return .{
            .filter = filter,
            .row_index = row_index,
            .row_bytes = self.row_len,
            .rows_done = self.row_index,
            .progress = .{
                .input_read = if (done) self.finished_input_read else 0,
                .output_written = self.row_len,
            },
            .status = if (done) .done else .need_output,
        };
    }

    fn stepWithPrevious(self: *PngStreamingZlibScanlineDecoder, output: []u8, previous: ?[]const u8) Error!Step {
        return self.stepWithPreviousInternal(output, previous) catch |err| {
            self.recordError(err);
            return err;
        };
    }

    fn stepWithPreviousInternal(self: *PngStreamingZlibScanlineDecoder, output: []u8, previous: ?[]const u8) Error!Step {
        if (self.row_index == self.row_count) {
            try self.finish();
            return .{ .row_index = self.row_index, .rows_done = self.row_index, .status = .done };
        }
        if (output.len < self.row_len) return error.OutputTooSmall;

        const filter = (try self.readInflatedByteOrEnd()) orelse return error.SizeMismatch;
        if (filter > 4) return error.CorruptFrame;
        const row_output = output[0..self.row_len];
        // Whole-image drainers own the destination image and never need to hand
        // the filtered bytes to a caller. Inflate directly into the destination
        // row, then reverse the PNG filter in place. History and Adler state are
        // updated while the row still contains filtered bytes, before
        // reconstruction overwrites it.
        try self.readInflatedBytes(row_output);
        _ = try reconstructPngScanline(filter, row_output, previous, self.bytes_per_pixel, row_output);

        const row_index = self.row_index;
        self.row_index += 1;
        const done = self.row_index == self.row_count;
        if (done) try self.finish();
        return .{
            .filter = filter,
            .row_index = row_index,
            .row_bytes = self.row_len,
            .rows_done = self.row_index,
            .progress = .{
                .input_read = if (done) self.finished_input_read else 0,
                .output_written = self.row_len,
            },
            .status = if (done) .done else .need_output,
        };
    }

    fn readInflatedBytes(self: *PngStreamingZlibScanlineDecoder, output: []u8) Error!void {
        return readPngStreamingInflatedBytes(self, output);
    }

    fn readInflatedByteOrEnd(self: *PngStreamingZlibScanlineDecoder) Error!?u8 {
        while (true) {
            if (self.pending_match_remaining != 0) {
                const byte = try self.historyByte(self.pending_match_distance);
                self.pending_match_remaining -= 1;
                return self.emitByte(byte);
            }

            switch (self.block_kind) {
                .need_header => {
                    try self.startNextBlock();
                },
                .stored => {
                    if (self.stored_remaining == 0) {
                        self.finishCurrentBlock();
                        continue;
                    }
                    var byte: [1]u8 = undefined;
                    try self.reader.readAlignedBytes(&byte);
                    self.stored_remaining -= 1;
                    const emitted = self.emitByte(byte[0]);
                    if (self.stored_remaining == 0) self.finishCurrentBlock();
                    return emitted;
                },
                .fixed => {
                    const symbol = try huffman.decodeFixedLiteralValueFast(&self.reader);
                    if (symbol < 256) return self.emitByte(@intCast(symbol));
                    if (symbol == 256) {
                        self.finishCurrentBlock();
                        continue;
                    }
                    if (symbol > 285) return error.InvalidHuffmanCode;
                    const length = try decodeLength(symbol, &self.reader);
                    const distance_symbol = try huffman.decodeFixedDistanceValueFast(&self.reader);
                    const distance = try decodeDistance(distance_symbol, &self.reader);
                    try self.startPendingMatch(length, distance);
                },
                .dynamic9 => if (try readPngStreamingDynamicInflatedByte(self, 9)) |byte| return byte,
                .dynamic11 => if (try readPngStreamingDynamicInflatedByte(self, 11)) |byte| return byte,
                .done => return null,
            }
        }
    }

    fn startNextBlock(self: *PngStreamingZlibScanlineDecoder) Error!void {
        if (self.block_kind == .done) return;
        const header = try readBlockHeader(&self.reader);
        self.final_block = header.final;
        switch (header.block_type) {
            0 => {
                self.reader.alignToByte();
                const len = try self.reader.readAlignedInt(u16, .little);
                const nlen = try self.reader.readAlignedInt(u16, .little);
                if (nlen != ~len) return error.StoredLengthMismatch;
                self.stored_remaining = len;
                self.block_kind = .stored;
            },
            1 => self.block_kind = .fixed,
            2 => {
                const parsed = try huffman.parseDynamicLengthsAfterHeader(header.final, &self.reader);
                const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
                const lit_lookup_bits = pngStreamingDynamicLiteralLookupBits(parsed);
                self.dynamic_lit = PngStreamingDynamicLiteralDecoder.initWithBits(lit_lookup_bits, lit_table);
                self.dynamic_dist = try makeDynamicDistanceDecoderFromLengths(parsed.distance_lengths[0..parsed.header.hdist]);
                self.block_kind = switch (lit_lookup_bits) {
                    9 => .dynamic9,
                    else => .dynamic11,
                };
            },
            else => return error.InvalidDeflateBlockType,
        }
    }

    fn finishCurrentBlock(self: *PngStreamingZlibScanlineDecoder) void {
        if (self.final_block) {
            self.block_kind = .done;
        } else {
            self.block_kind = .need_header;
        }
        self.final_block = false;
        self.stored_remaining = 0;
    }

    fn startPendingMatch(self: *PngStreamingZlibScanlineDecoder, length: usize, distance: usize) Error!void {
        if (length == 0) return error.InvalidMatch;
        if (distance == 0 or distance > self.history_len) return error.InvalidMatch;
        self.pending_match_remaining = length;
        self.pending_match_distance = distance;
    }

    fn historyByte(self: *const PngStreamingZlibScanlineDecoder, distance: usize) Error!u8 {
        if (distance == 0 or distance > self.history_len) return error.InvalidMatch;
        const index = wrapAddPowerOfTwo(self.history_pos, self.history.len - distance, self.history.len);
        return self.history[index];
    }

    fn emitByte(self: *PngStreamingZlibScanlineDecoder, byte: u8) u8 {
        self.updateAdlerByte(byte);
        self.history[self.history_pos] = byte;
        self.history_pos = wrapAddPowerOfTwo(self.history_pos, 1, self.history.len);
        self.history_len = @min(self.history_len + 1, self.history.len);
        return byte;
    }

    fn recordInflatedBytes(self: *PngStreamingZlibScanlineDecoder, bytes: []const u8) void {
        self.updateAdlerForInflatedBytes(bytes);
        self.recordHistoryBytes(bytes);
    }

    fn updateAdlerForInflatedBytes(self: *PngStreamingZlibScanlineDecoder, bytes: []const u8) void {
        updatePngStreamingAdlerBytes(self, bytes);
    }

    fn updateAdlerByte(self: *PngStreamingZlibScanlineDecoder, byte: u8) void {
        if (self.options.ignore_adler) return;
        self.adler.a += byte;
        self.adler.b += self.adler.a;
        self.adler_pending += 1;
        if (self.adler_pending == checksum.adler32_nmax) self.reduceAdler();
    }

    fn recordHistoryBytes(self: *PngStreamingZlibScanlineDecoder, bytes: []const u8) void {
        recordPngStreamingHistoryBytes(self, bytes);
    }

    fn reduceAdler(self: *PngStreamingZlibScanlineDecoder) void {
        self.adler.a %= checksum.adler32_modulus;
        self.adler.b %= checksum.adler32_modulus;
        self.adler_pending = 0;
    }

    fn finish(self: *PngStreamingZlibScanlineDecoder) Error!void {
        if (self.row_index != self.row_count) return error.SizeMismatch;
        try self.finishRawPayload();
    }

    fn finishRawPayload(self: *PngStreamingZlibScanlineDecoder) Error!void {
        if (self.finished) return;
        if (try self.readInflatedByteOrEnd()) |_| return error.SizeMismatch;
        const footer_offset = self.raw_base_offset + self.reader.byteOffset();
        const actual_adler = if (self.options.ignore_adler) 0 else blk: {
            self.reduceAdler();
            break :blk self.adler.digest();
        };
        try validateZlibFooterWithOptions(self.input, footer_offset, actual_adler, self.options);
        self.finished_input_read = footer_offset + 4;
        self.finished = true;
    }

    fn recordError(self: *PngStreamingZlibScanlineDecoder, err: Error) void {
        self.last_error_name = @errorName(err);
        self.last_recoverability_hint = switch (err) {
            error.BadZlibHeader, error.InvalidDeflateBlockType, error.InvalidDynamicBlockHeader, error.InvalidHuffmanCode => .corrupt_header,
            error.TruncatedFrame => .truncated_input,
            error.NeedDictionary, error.InvalidDictionaryTraining => .retry_with_dictionary,
            else => .payload_corrupt,
        };
    }
};

pub const PngStreamingZlibChunkedScanlineDecoder = struct {
    chunks: []const []const u8 = &.{},
    total_len: usize = 0,
    options: ZlibDecodeOptions = .{},
    reader: bitstream.ChunkedSpanBitReader = undefined,
    raw_base_offset: usize = 0,
    block_kind: BlockKind = .need_header,
    final_block: bool = false,
    stored_remaining: usize = 0,
    pending_match_remaining: usize = 0,
    pending_match_distance: usize = 0,
    dynamic_lit: PngStreamingDynamicLiteralDecoder = undefined,
    dynamic_dist: DynamicDistanceDecoder = undefined,
    history: []u8 = &.{},
    history_pos: usize = 0,
    history_len: usize = 0,
    adler: checksum.Adler32 = .{},
    adler_pending: usize = 0,
    filtered_row_scratch: []u8 = &.{},
    previous_row_scratch: []u8 = &.{},
    row_len: usize = 0,
    row_count: usize = 0,
    row_index: usize = 0,
    bytes_per_pixel: usize = 0,
    has_previous: bool = false,
    finished: bool = false,
    finished_input_read: usize = 0,
    last_error_name: []const u8 = "",
    last_recoverability_hint: ZlibDecoder.RecoverabilityHint = .none,

    const BlockKind = enum { need_header, stored, fixed, dynamic9, dynamic11, done };

    pub const Snapshot = struct {
        row_len: usize,
        row_count: usize,
        rows_done: usize,
        rows_remaining: usize,
        bytes_per_pixel: usize,
        done: bool,
        input_read: usize,
        history_len: usize,
        last_error_name: []const u8,
        recoverability_hint: ZlibDecoder.RecoverabilityHint,
    };

    pub const Step = PngZlibScanlineDecoder.Step;
    pub const history_scratch_len = lz77.default_window_len;

    pub fn initWithInfo(
        chunks: []const []const u8,
        history_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
    ) Error!PngStreamingZlibChunkedScanlineDecoder {
        return initWithInfoAndOptions(chunks, history_scratch, filtered_row_scratch, previous_row_scratch, info, .{});
    }

    pub fn initWithInfoAndOptions(
        chunks: []const []const u8,
        history_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
        options: ZlibDecodeOptions,
    ) Error!PngStreamingZlibChunkedScanlineDecoder {
        var self = PngStreamingZlibChunkedScanlineDecoder{};
        try self.resetWithInfoAndOptions(chunks, history_scratch, filtered_row_scratch, previous_row_scratch, info, options);
        return self;
    }

    pub fn initRawWithOptions(
        chunks: []const []const u8,
        history_scratch: []u8,
        options: ZlibDecodeOptions,
    ) Error!PngStreamingZlibChunkedScanlineDecoder {
        var self = PngStreamingZlibChunkedScanlineDecoder{};
        try self.resetRawWithOptions(chunks, history_scratch, options);
        return self;
    }

    pub fn resetWithInfo(
        self: *PngStreamingZlibChunkedScanlineDecoder,
        chunks: []const []const u8,
        history_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
    ) Error!void {
        return self.resetWithInfoAndOptions(chunks, history_scratch, filtered_row_scratch, previous_row_scratch, info, .{});
    }

    pub fn resetWithInfoAndOptions(
        self: *PngStreamingZlibChunkedScanlineDecoder,
        chunks: []const []const u8,
        history_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
        options: ZlibDecodeOptions,
    ) Error!void {
        _ = try PngZlibScanlineDecoder.validateConfig(info.row_len, info.height, info.bytes_per_pixel, filtered_row_scratch, previous_row_scratch);
        if (history_scratch.len < history_scratch_len) return error.OutputTooSmall;
        const total_len = try chunksTotalLen(chunks);
        const header = try parseZlibHeaderFromChunks(chunks, null);
        self.* = .{
            .chunks = chunks,
            .total_len = total_len,
            .options = options,
            .reader = try bitstream.ChunkedSpanBitReader.initAtKnownTotal(chunks, header.data_offset, total_len),
            .raw_base_offset = 0,
            .history = history_scratch[0..history_scratch_len],
            .filtered_row_scratch = filtered_row_scratch[0..info.row_len],
            .previous_row_scratch = previous_row_scratch[0..info.row_len],
            .row_len = info.row_len,
            .row_count = info.height,
            .bytes_per_pixel = info.bytes_per_pixel,
        };
    }

    pub fn resetRawWithOptions(
        self: *PngStreamingZlibChunkedScanlineDecoder,
        chunks: []const []const u8,
        history_scratch: []u8,
        options: ZlibDecodeOptions,
    ) Error!void {
        if (history_scratch.len < history_scratch_len) return error.OutputTooSmall;
        const total_len = try chunksTotalLen(chunks);
        const header = try parseZlibHeaderFromChunks(chunks, null);
        self.* = .{
            .chunks = chunks,
            .total_len = total_len,
            .options = options,
            .reader = try bitstream.ChunkedSpanBitReader.initAtKnownTotal(chunks, header.data_offset, total_len),
            .raw_base_offset = 0,
            .history = history_scratch[0..history_scratch_len],
        };
    }

    pub fn snapshot(self: *const PngStreamingZlibChunkedScanlineDecoder) Snapshot {
        const input_read = if (self.finished)
            self.finished_input_read
        else
            self.raw_base_offset + self.reader.byteOffset();
        return .{
            .row_len = self.row_len,
            .row_count = self.row_count,
            .rows_done = self.row_index,
            .rows_remaining = self.row_count - self.row_index,
            .bytes_per_pixel = self.bytes_per_pixel,
            .done = self.finished,
            .input_read = input_read,
            .history_len = self.history_len,
            .last_error_name = self.last_error_name,
            .recoverability_hint = self.last_recoverability_hint,
        };
    }

    pub fn diagnostics(self: *const PngStreamingZlibChunkedScanlineDecoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = if (snap.done) "done" else "payload",
            .frame_input_read = if (snap.done) snap.input_read else null,
            .output_written = snap.rows_done *| snap.row_len,
            .expected_output_len = snap.row_count *| snap.row_len,
            .payload_remaining = snap.rows_remaining *| (snap.row_len +| 1),
            .last_error_name = snap.last_error_name,
            .last_error_phase_name = if (snap.last_error_name.len == 0) "" else "payload",
            .recoverability_hint_name = ZlibDecoder.hintName(snap.recoverability_hint),
        };
    }

    pub fn step(self: *PngStreamingZlibChunkedScanlineDecoder, output: []u8) Error!Step {
        return self.stepInternal(output) catch |err| {
            self.recordError(err);
            return err;
        };
    }

    fn stepInternal(self: *PngStreamingZlibChunkedScanlineDecoder, output: []u8) Error!Step {
        if (self.row_index == self.row_count) {
            try self.finish();
            return .{ .row_index = self.row_index, .rows_done = self.row_index, .status = .done };
        }
        if (output.len < self.row_len) return error.OutputTooSmall;

        const filter = (try self.readInflatedByteOrEnd()) orelse return error.SizeMismatch;
        if (filter > 4) return error.CorruptFrame;
        try self.readInflatedBytes(self.filtered_row_scratch);
        const previous = if (self.has_previous) self.previous_row_scratch else null;
        const row_output = output[0..self.row_len];
        _ = try reconstructPngScanline(filter, self.filtered_row_scratch, previous, self.bytes_per_pixel, row_output);
        @memcpy(self.previous_row_scratch, row_output);
        self.has_previous = true;

        const row_index = self.row_index;
        self.row_index += 1;
        const done = self.row_index == self.row_count;
        if (done) try self.finish();
        return .{
            .filter = filter,
            .row_index = row_index,
            .row_bytes = self.row_len,
            .rows_done = self.row_index,
            .progress = .{
                .input_read = if (done) self.finished_input_read else 0,
                .output_written = self.row_len,
            },
            .status = if (done) .done else .need_output,
        };
    }

    fn stepWithPrevious(self: *PngStreamingZlibChunkedScanlineDecoder, output: []u8, previous: ?[]const u8) Error!Step {
        return self.stepWithPreviousInternal(output, previous) catch |err| {
            self.recordError(err);
            return err;
        };
    }

    fn stepWithPreviousInternal(self: *PngStreamingZlibChunkedScanlineDecoder, output: []u8, previous: ?[]const u8) Error!Step {
        if (self.row_index == self.row_count) {
            try self.finish();
            return .{ .row_index = self.row_index, .rows_done = self.row_index, .status = .done };
        }
        if (output.len < self.row_len) return error.OutputTooSmall;

        const filter = (try self.readInflatedByteOrEnd()) orelse return error.SizeMismatch;
        if (filter > 4) return error.CorruptFrame;
        const row_output = output[0..self.row_len];
        // See the contiguous streaming decoder: full-image chunked drains can
        // use the destination row as temporary filtered storage because the
        // row's compressed bytes have already been accounted into zlib history
        // and checksum state before in-place reconstruction runs.
        try self.readInflatedBytes(row_output);
        _ = try reconstructPngScanline(filter, row_output, previous, self.bytes_per_pixel, row_output);

        const row_index = self.row_index;
        self.row_index += 1;
        const done = self.row_index == self.row_count;
        if (done) try self.finish();
        return .{
            .filter = filter,
            .row_index = row_index,
            .row_bytes = self.row_len,
            .rows_done = self.row_index,
            .progress = .{
                .input_read = if (done) self.finished_input_read else 0,
                .output_written = self.row_len,
            },
            .status = if (done) .done else .need_output,
        };
    }

    fn readInflatedBytes(self: *PngStreamingZlibChunkedScanlineDecoder, output: []u8) Error!void {
        return readPngStreamingInflatedBytes(self, output);
    }

    fn readInflatedByteOrEnd(self: *PngStreamingZlibChunkedScanlineDecoder) Error!?u8 {
        while (true) {
            if (self.pending_match_remaining != 0) {
                const byte = try self.historyByte(self.pending_match_distance);
                self.pending_match_remaining -= 1;
                return self.emitByte(byte);
            }

            switch (self.block_kind) {
                .need_header => {
                    try self.startNextBlock();
                },
                .stored => {
                    if (self.stored_remaining == 0) {
                        self.finishCurrentBlock();
                        continue;
                    }
                    var byte: [1]u8 = undefined;
                    try self.reader.readAlignedBytes(&byte);
                    self.stored_remaining -= 1;
                    const emitted = self.emitByte(byte[0]);
                    if (self.stored_remaining == 0) self.finishCurrentBlock();
                    return emitted;
                },
                .fixed => {
                    const symbol = try huffman.decodeFixedLiteralValueFast(&self.reader);
                    if (symbol < 256) return self.emitByte(@intCast(symbol));
                    if (symbol == 256) {
                        self.finishCurrentBlock();
                        continue;
                    }
                    if (symbol > 285) return error.InvalidHuffmanCode;
                    const length = try decodeLength(symbol, &self.reader);
                    const distance_symbol = try huffman.decodeFixedDistanceValueFast(&self.reader);
                    const distance = try decodeDistance(distance_symbol, &self.reader);
                    try self.startPendingMatch(length, distance);
                },
                .dynamic9 => if (try readPngStreamingDynamicInflatedByte(self, 9)) |byte| return byte,
                .dynamic11 => if (try readPngStreamingDynamicInflatedByte(self, 11)) |byte| return byte,
                .done => return null,
            }
        }
    }

    fn startNextBlock(self: *PngStreamingZlibChunkedScanlineDecoder) Error!void {
        if (self.block_kind == .done) return;
        const header = try readBlockHeader(&self.reader);
        self.final_block = header.final;
        switch (header.block_type) {
            0 => {
                self.reader.alignToByte();
                const len = try self.reader.readAlignedInt(u16, .little);
                const nlen = try self.reader.readAlignedInt(u16, .little);
                if (nlen != ~len) return error.StoredLengthMismatch;
                self.stored_remaining = len;
                self.block_kind = .stored;
            },
            1 => self.block_kind = .fixed,
            2 => {
                const parsed = try huffman.parseDynamicLengthsAfterHeader(header.final, &self.reader);
                const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
                const lit_lookup_bits = pngStreamingDynamicLiteralLookupBits(parsed);
                self.dynamic_lit = PngStreamingDynamicLiteralDecoder.initWithBits(lit_lookup_bits, lit_table);
                self.dynamic_dist = try makeDynamicDistanceDecoderFromLengths(parsed.distance_lengths[0..parsed.header.hdist]);
                self.block_kind = switch (lit_lookup_bits) {
                    9 => .dynamic9,
                    else => .dynamic11,
                };
            },
            else => return error.InvalidDeflateBlockType,
        }
    }

    fn finishCurrentBlock(self: *PngStreamingZlibChunkedScanlineDecoder) void {
        if (self.final_block) {
            self.block_kind = .done;
        } else {
            self.block_kind = .need_header;
        }
        self.final_block = false;
        self.stored_remaining = 0;
    }

    fn startPendingMatch(self: *PngStreamingZlibChunkedScanlineDecoder, length: usize, distance: usize) Error!void {
        if (length == 0) return error.InvalidMatch;
        if (distance == 0 or distance > self.history_len) return error.InvalidMatch;
        self.pending_match_remaining = length;
        self.pending_match_distance = distance;
    }

    fn historyByte(self: *const PngStreamingZlibChunkedScanlineDecoder, distance: usize) Error!u8 {
        if (distance == 0 or distance > self.history_len) return error.InvalidMatch;
        const index = wrapAddPowerOfTwo(self.history_pos, self.history.len - distance, self.history.len);
        return self.history[index];
    }

    fn emitByte(self: *PngStreamingZlibChunkedScanlineDecoder, byte: u8) u8 {
        self.updateAdlerByte(byte);
        self.history[self.history_pos] = byte;
        self.history_pos = wrapAddPowerOfTwo(self.history_pos, 1, self.history.len);
        self.history_len = @min(self.history_len + 1, self.history.len);
        return byte;
    }

    fn recordInflatedBytes(self: *PngStreamingZlibChunkedScanlineDecoder, bytes: []const u8) void {
        self.updateAdlerForInflatedBytes(bytes);
        self.recordHistoryBytes(bytes);
    }

    fn updateAdlerForInflatedBytes(self: *PngStreamingZlibChunkedScanlineDecoder, bytes: []const u8) void {
        updatePngStreamingAdlerBytes(self, bytes);
    }

    fn updateAdlerByte(self: *PngStreamingZlibChunkedScanlineDecoder, byte: u8) void {
        if (self.options.ignore_adler) return;
        self.adler.a += byte;
        self.adler.b += self.adler.a;
        self.adler_pending += 1;
        if (self.adler_pending == checksum.adler32_nmax) self.reduceAdler();
    }

    fn recordHistoryBytes(self: *PngStreamingZlibChunkedScanlineDecoder, bytes: []const u8) void {
        recordPngStreamingHistoryBytes(self, bytes);
    }

    fn reduceAdler(self: *PngStreamingZlibChunkedScanlineDecoder) void {
        self.adler.a %= checksum.adler32_modulus;
        self.adler.b %= checksum.adler32_modulus;
        self.adler_pending = 0;
    }

    fn finish(self: *PngStreamingZlibChunkedScanlineDecoder) Error!void {
        if (self.row_index != self.row_count) return error.SizeMismatch;
        try self.finishRawPayload();
    }

    fn finishRawPayload(self: *PngStreamingZlibChunkedScanlineDecoder) Error!void {
        if (self.finished) return;
        if (try self.readInflatedByteOrEnd()) |_| return error.SizeMismatch;
        const footer_offset = self.reader.byteOffset();
        const actual_adler = if (self.options.ignore_adler) 0 else blk: {
            self.reduceAdler();
            break :blk self.adler.digest();
        };
        try validateZlibFooterChunksWithOptions(self.chunks, footer_offset, actual_adler, self.options);
        self.finished_input_read = footer_offset + 4;
        self.finished = true;
    }

    fn recordError(self: *PngStreamingZlibChunkedScanlineDecoder, err: Error) void {
        self.last_error_name = @errorName(err);
        self.last_recoverability_hint = switch (err) {
            error.BadZlibHeader, error.InvalidDeflateBlockType, error.InvalidDynamicBlockHeader, error.InvalidHuffmanCode => .corrupt_header,
            error.TruncatedFrame => .truncated_input,
            error.NeedDictionary, error.InvalidDictionaryTraining => .retry_with_dictionary,
            else => .payload_corrupt,
        };
    }
};

/// Streaming PNG scanline decoder for zlib streams whose deflate payload uses
/// only stored blocks.
///
/// Unlike `PngZlibScanlineDecoder`, this type does not need a full decoded
/// zlib-payload scratch buffer. It reads stored-block payload bytes directly
/// from the compressed zlib frame, updates Adler-32 as bytes are consumed, and
/// reconstructs one PNG row at a time into caller-owned output. Fixed/dynamic
/// DEFLATE still require `PngZlibScanlineDecoder` until the incremental inflate
/// core can produce row bytes without materializing the whole payload.
pub const PngStoredZlibScanlineDecoder = struct {
    input: []const u8 = &.{},
    options: ZlibDecodeOptions = .{},
    pos: usize = 2,
    block_remaining: usize = 0,
    block_final: bool = false,
    final_seen: bool = false,
    finished: bool = false,
    check_adler: bool = true,
    adler: checksum.Adler32 = .{},
    filtered_row_scratch: []u8 = &.{},
    previous_row_scratch: []u8 = &.{},
    row_len: usize = 0,
    row_count: usize = 0,
    row_index: usize = 0,
    bytes_per_pixel: usize = 0,
    has_previous: bool = false,

    pub const Snapshot = struct {
        row_len: usize,
        row_count: usize,
        rows_done: usize,
        rows_remaining: usize,
        bytes_per_pixel: usize,
        done: bool,
        input_read: usize,
        block_remaining: usize,
        final_seen: bool,
        finished: bool,
    };

    pub const Step = PngZlibScanlineDecoder.Step;

    pub fn init(
        input: []const u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        row_len: usize,
        row_count: usize,
        bytes_per_pixel: usize,
    ) Error!PngStoredZlibScanlineDecoder {
        return initWithOptions(input, filtered_row_scratch, previous_row_scratch, row_len, row_count, bytes_per_pixel, .{});
    }

    pub fn initWithInfo(
        input: []const u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
    ) Error!PngStoredZlibScanlineDecoder {
        return init(input, filtered_row_scratch, previous_row_scratch, info.row_len, info.height, info.bytes_per_pixel);
    }

    pub fn initWithOptions(
        input: []const u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        row_len: usize,
        row_count: usize,
        bytes_per_pixel: usize,
        options: ZlibDecodeOptions,
    ) Error!PngStoredZlibScanlineDecoder {
        var self = PngStoredZlibScanlineDecoder{};
        try self.resetWithOptions(input, filtered_row_scratch, previous_row_scratch, row_len, row_count, bytes_per_pixel, options);
        return self;
    }

    pub fn initWithInfoAndOptions(
        input: []const u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
        options: ZlibDecodeOptions,
    ) Error!PngStoredZlibScanlineDecoder {
        return initWithOptions(input, filtered_row_scratch, previous_row_scratch, info.row_len, info.height, info.bytes_per_pixel, options);
    }

    pub fn resetWithOptions(
        self: *PngStoredZlibScanlineDecoder,
        input: []const u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        row_len: usize,
        row_count: usize,
        bytes_per_pixel: usize,
        options: ZlibDecodeOptions,
    ) Error!void {
        _ = try PngZlibScanlineDecoder.validateConfig(row_len, row_count, bytes_per_pixel, filtered_row_scratch, previous_row_scratch);
        const header = try parseZlibHeader(input, null);
        self.* = .{
            .input = input,
            .options = options,
            .pos = header.data_offset,
            .check_adler = !options.ignore_adler,
            .filtered_row_scratch = filtered_row_scratch[0..row_len],
            .previous_row_scratch = previous_row_scratch[0..row_len],
            .row_len = row_len,
            .row_count = row_count,
            .bytes_per_pixel = bytes_per_pixel,
        };
    }

    pub fn snapshot(self: *const PngStoredZlibScanlineDecoder) Snapshot {
        return .{
            .row_len = self.row_len,
            .row_count = self.row_count,
            .rows_done = self.row_index,
            .rows_remaining = self.row_count - self.row_index,
            .bytes_per_pixel = self.bytes_per_pixel,
            .done = self.finished,
            .input_read = self.pos,
            .block_remaining = self.block_remaining,
            .final_seen = self.final_seen,
            .finished = self.finished,
        };
    }

    pub fn step(self: *PngStoredZlibScanlineDecoder, output: []u8) Error!Step {
        if (self.row_index == self.row_count) {
            try self.finish();
            return .{
                .row_index = self.row_index,
                .rows_done = self.row_index,
                .status = .done,
            };
        }
        if (output.len < self.row_len) return error.OutputTooSmall;

        const before = self.pos;
        const filter = try self.readByte();
        try self.readBytes(self.filtered_row_scratch);
        const previous = if (self.has_previous) self.previous_row_scratch else null;
        const row_output = output[0..self.row_len];
        _ = try reconstructPngScanline(filter, self.filtered_row_scratch, previous, self.bytes_per_pixel, row_output);
        @memcpy(self.previous_row_scratch, row_output);
        self.has_previous = true;

        const row_index = self.row_index;
        self.row_index += 1;
        const done = self.row_index == self.row_count;
        if (done) try self.finish();

        return .{
            .filter = filter,
            .row_index = row_index,
            .row_bytes = self.row_len,
            .rows_done = self.row_index,
            .progress = .{ .input_read = self.pos - before, .output_written = self.row_len },
            .status = if (done) .done else .need_output,
        };
    }

    fn readByte(self: *PngStoredZlibScanlineDecoder) Error!u8 {
        var byte: [1]u8 = undefined;
        try self.readBytes(&byte);
        return byte[0];
    }

    fn readBytes(self: *PngStoredZlibScanlineDecoder, out: []u8) Error!void {
        var written: usize = 0;
        while (written < out.len) {
            if (self.block_remaining == 0) {
                try self.nextBlock();
            }
            const n = @min(out.len - written, self.block_remaining);
            if (self.input.len - self.pos < n) return error.TruncatedFrame;
            const part = self.input[self.pos..][0..n];
            @memcpy(out[written..][0..n], part);
            if (self.check_adler) self.adler.update(part);
            self.pos += n;
            written += n;
            self.block_remaining -= n;
            if (self.block_remaining == 0 and self.block_final) {
                self.final_seen = true;
            }
        }
    }

    fn nextBlock(self: *PngStoredZlibScanlineDecoder) Error!void {
        if (self.final_seen) return error.SizeMismatch;
        if (self.pos >= self.input.len) return error.TruncatedFrame;
        const header = self.input[self.pos];
        self.pos += 1;
        if (!isStoredBlockHeaderByte(header)) return error.InvalidDeflateBlockType;
        self.block_final = (header & 0x01) != 0;
        if (self.input.len - self.pos < 4) return error.TruncatedFrame;
        const lengths = try readStoredLengthPairUnchecked(self.input, self.pos);
        self.pos += 4;
        self.block_remaining = lengths.len;
        if (self.block_remaining == 0 and self.block_final) self.final_seen = true;
    }

    fn finish(self: *PngStoredZlibScanlineDecoder) Error!void {
        if (self.finished) return;
        if (self.row_index != self.row_count) return error.SizeMismatch;
        if (!self.final_seen or self.block_remaining != 0) return error.SizeMismatch;
        try validateZlibFooterWithOptions(self.input, self.pos, self.adler.digest(), self.options);
        self.pos += 4;
        if (!self.options.allow_trailing_data and self.pos != self.input.len) return error.TrailingData;
        self.finished = true;
    }
};

pub const PngStoredZlibChunkedScanlineDecoder = struct {
    chunks: []const []const u8 = &.{},
    cursor: ChunkCursor = .{ .chunks = &.{}, .total_len = 0, .absolute = 0 },
    total_len: usize = 0,
    options: ZlibDecodeOptions = .{},
    block_remaining: usize = 0,
    block_final: bool = false,
    final_seen: bool = false,
    finished: bool = false,
    check_adler: bool = true,
    adler: checksum.Adler32 = .{},
    filtered_row_scratch: []u8 = &.{},
    previous_row_scratch: []u8 = &.{},
    row_len: usize = 0,
    row_count: usize = 0,
    row_index: usize = 0,
    bytes_per_pixel: usize = 0,
    has_previous: bool = false,

    pub const Snapshot = struct {
        row_len: usize,
        row_count: usize,
        rows_done: usize,
        rows_remaining: usize,
        bytes_per_pixel: usize,
        done: bool,
        input_read: usize,
        block_remaining: usize,
        final_seen: bool,
        finished: bool,
    };

    pub const Step = PngZlibScanlineDecoder.Step;

    pub fn initWithInfoAndOptions(
        chunks: []const []const u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngImageInfo,
        options: ZlibDecodeOptions,
    ) Error!PngStoredZlibChunkedScanlineDecoder {
        var self = PngStoredZlibChunkedScanlineDecoder{};
        try self.resetWithOptions(chunks, filtered_row_scratch, previous_row_scratch, info.row_len, info.height, info.bytes_per_pixel, options);
        return self;
    }

    pub fn resetWithOptions(
        self: *PngStoredZlibChunkedScanlineDecoder,
        chunks: []const []const u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        row_len: usize,
        row_count: usize,
        bytes_per_pixel: usize,
        options: ZlibDecodeOptions,
    ) Error!void {
        _ = try PngZlibScanlineDecoder.validateConfig(row_len, row_count, bytes_per_pixel, filtered_row_scratch, previous_row_scratch);
        const total_len = try chunksTotalLen(chunks);
        const header = try parseZlibHeaderFromChunks(chunks, null);
        self.* = .{
            .chunks = chunks,
            .cursor = try ChunkCursor.init(chunks, total_len, header.data_offset),
            .total_len = total_len,
            .options = options,
            .check_adler = !options.ignore_adler,
            .filtered_row_scratch = filtered_row_scratch[0..row_len],
            .previous_row_scratch = previous_row_scratch[0..row_len],
            .row_len = row_len,
            .row_count = row_count,
            .bytes_per_pixel = bytes_per_pixel,
        };
    }

    pub fn snapshot(self: *const PngStoredZlibChunkedScanlineDecoder) Snapshot {
        return .{
            .row_len = self.row_len,
            .row_count = self.row_count,
            .rows_done = self.row_index,
            .rows_remaining = self.row_count - self.row_index,
            .bytes_per_pixel = self.bytes_per_pixel,
            .done = self.finished,
            .input_read = self.cursor.absolute,
            .block_remaining = self.block_remaining,
            .final_seen = self.final_seen,
            .finished = self.finished,
        };
    }

    pub fn step(self: *PngStoredZlibChunkedScanlineDecoder, output: []u8) Error!Step {
        if (self.row_index == self.row_count) {
            try self.finish();
            return .{ .row_index = self.row_index, .rows_done = self.row_index, .status = .done };
        }
        if (output.len < self.row_len) return error.OutputTooSmall;

        const before = self.cursor.absolute;
        const filter = try self.readByte();
        try self.readBytes(self.filtered_row_scratch);
        const previous = if (self.has_previous) self.previous_row_scratch else null;
        const row_output = output[0..self.row_len];
        _ = try reconstructPngScanline(filter, self.filtered_row_scratch, previous, self.bytes_per_pixel, row_output);
        @memcpy(self.previous_row_scratch, row_output);
        self.has_previous = true;

        const row_index = self.row_index;
        self.row_index += 1;
        const done = self.row_index == self.row_count;
        if (done) try self.finish();
        return .{
            .filter = filter,
            .row_index = row_index,
            .row_bytes = self.row_len,
            .rows_done = self.row_index,
            .progress = .{ .input_read = self.cursor.absolute - before, .output_written = self.row_len },
            .status = if (done) .done else .need_output,
        };
    }

    fn readByte(self: *PngStoredZlibChunkedScanlineDecoder) Error!u8 {
        var byte: [1]u8 = undefined;
        try self.readBytes(&byte);
        return byte[0];
    }

    fn readBytes(self: *PngStoredZlibChunkedScanlineDecoder, out: []u8) Error!void {
        var written: usize = 0;
        while (written < out.len) {
            if (self.block_remaining == 0) try self.nextBlock();
            const n = @min(out.len - written, self.block_remaining);
            try self.cursor.copyTo(out[written..][0..n]);
            if (self.check_adler) self.adler.update(out[written..][0..n]);
            written += n;
            self.block_remaining -= n;
            if (self.block_remaining == 0 and self.block_final) self.final_seen = true;
        }
    }

    fn nextBlock(self: *PngStoredZlibChunkedScanlineDecoder) Error!void {
        if (self.final_seen) return error.SizeMismatch;
        const header = try self.cursor.readByte();
        if (!isStoredBlockHeaderByte(header)) return error.InvalidDeflateBlockType;
        self.block_final = (header & 0x01) != 0;
        const len = try self.cursor.readLittleU16();
        const nlen = try self.cursor.readLittleU16();
        if ((len ^ nlen) != std.math.maxInt(u16)) return error.StoredLengthMismatch;
        self.block_remaining = len;
        if (self.block_remaining == 0 and self.block_final) self.final_seen = true;
    }

    fn finish(self: *PngStoredZlibChunkedScanlineDecoder) Error!void {
        if (self.finished) return;
        if (self.row_index != self.row_count) return error.SizeMismatch;
        if (!self.final_seen or self.block_remaining != 0) return error.SizeMismatch;
        try validateZlibFooterChunksWithOptions(self.chunks, self.cursor.absolute, self.adler.digest(), self.options);
        self.cursor.absolute += 4;
        self.cursor.sync();
        self.finished = true;
    }
};

pub const PngImageDecodeResult = struct {
    rows: usize,
    output_written: usize,
    zlib_input_read: usize,
};

pub const PngAdam7ImageDecodeResult = struct {
    passes: usize,
    rows: usize,
    output_written: usize,
    zlib_input_read: usize,
};

pub const PngAdam7Row = struct {
    pass: PngAdam7PassInfo,
    pass_row_index: usize,
    row: []const u8,
};

pub const PngAdam7RowsDecodeResult = struct {
    passes: usize,
    rows: usize,
    row_bytes: usize,
    zlib_input_read: usize,
};

pub const PngAdam7RowCallback = struct {
    context: *anyopaque,
    on_row: *const fn (*anyopaque, PngAdam7Row) Error!void,
};

pub fn decodePngStoredZlibImage(
    input: []const u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngImageInfo,
    output: []u8,
) Error!PngImageDecodeResult {
    return decodePngStoredZlibImageWithOptions(input, filtered_row_scratch, previous_row_scratch, info, .{}, output);
}

pub fn decodePngStoredZlibImageWithOptions(
    input: []const u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngImageInfo,
    options: ZlibDecodeOptions,
    output: []u8,
) Error!PngImageDecodeResult {
    const output_len = try pngImageOutputLen(info);
    if (output.len < output_len) return error.OutputTooSmall;
    var decoder = try PngStoredZlibScanlineDecoder.initWithInfoAndOptions(input, filtered_row_scratch, previous_row_scratch, info, options);
    return drainPngStoredZlibImage(&decoder, output[0..output_len]);
}

pub fn decodePngStoredZlibImageFromChunksDirect(
    chunks: []const []const u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngImageInfo,
    output: []u8,
) Error!PngImageDecodeResult {
    return decodePngStoredZlibImageFromChunksWithOptionsDirect(chunks, filtered_row_scratch, previous_row_scratch, info, .{}, output);
}

pub fn decodePngStoredZlibImageFromChunksWithOptionsDirect(
    chunks: []const []const u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngImageInfo,
    options: ZlibDecodeOptions,
    output: []u8,
) Error!PngImageDecodeResult {
    const output_len = try pngImageOutputLen(info);
    if (output.len < output_len) return error.OutputTooSmall;
    var decoder = try PngStoredZlibChunkedScanlineDecoder.initWithInfoAndOptions(chunks, filtered_row_scratch, previous_row_scratch, info, options);
    return drainPngStoredZlibChunksImage(&decoder, output[0..output_len]);
}

pub fn decodePngStreamingZlibImage(
    input: []const u8,
    history_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngImageInfo,
    output: []u8,
) Error!PngImageDecodeResult {
    return decodePngStreamingZlibImageWithOptions(input, history_scratch, filtered_row_scratch, previous_row_scratch, info, .{}, output);
}

pub fn decodePngStreamingZlibImageWithOptions(
    input: []const u8,
    history_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngImageInfo,
    options: ZlibDecodeOptions,
    output: []u8,
) Error!PngImageDecodeResult {
    const output_len = try pngImageOutputLen(info);
    if (output.len < output_len) return error.OutputTooSmall;
    var decoder = try PngStreamingZlibScanlineDecoder.initWithInfoAndOptions(input, history_scratch, filtered_row_scratch, previous_row_scratch, info, options);
    return drainPngStreamingZlibImage(&decoder, output[0..output_len]);
}

pub fn decodePngStreamingZlibImageFromChunksDirect(
    chunks: []const []const u8,
    history_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngImageInfo,
    output: []u8,
) Error!PngImageDecodeResult {
    return decodePngStreamingZlibImageFromChunksWithOptionsDirect(chunks, history_scratch, filtered_row_scratch, previous_row_scratch, info, .{}, output);
}

pub fn decodePngStreamingZlibImageFromChunksWithOptionsDirect(
    chunks: []const []const u8,
    history_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngImageInfo,
    options: ZlibDecodeOptions,
    output: []u8,
) Error!PngImageDecodeResult {
    const output_len = try pngImageOutputLen(info);
    if (output.len < output_len) return error.OutputTooSmall;
    var decoder = try PngStreamingZlibChunkedScanlineDecoder.initWithInfoAndOptions(chunks, history_scratch, filtered_row_scratch, previous_row_scratch, info, options);
    return drainPngStreamingZlibChunksImage(&decoder, output[0..output_len]);
}

pub fn decodePngZlibImage(
    input: []const u8,
    zlib_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngImageInfo,
    output: []u8,
) Error!PngImageDecodeResult {
    return decodePngZlibImageWithOptions(input, zlib_scratch, filtered_row_scratch, previous_row_scratch, info, .{}, output);
}

pub fn decodePngZlibImageWithOptions(
    input: []const u8,
    zlib_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngImageInfo,
    options: ZlibDecodeOptions,
    output: []u8,
) Error!PngImageDecodeResult {
    const output_len = try pngImageOutputLen(info);
    if (output.len < output_len) return error.OutputTooSmall;
    var decoder = try PngZlibScanlineDecoder.initWithInfoAndOptions(input, zlib_scratch, filtered_row_scratch, previous_row_scratch, info, options);
    return drainPngZlibImage(&decoder, output[0..output_len]);
}

const max_png_reconstruct_workers = 8;

const PngReconstructWorker = struct {
    inflated: []const u8,
    output: []u8,
    info: PngImageInfo,
    row_start: usize,
    row_end: usize,
    err: ?Error = null,

    fn run(self: *PngReconstructWorker) void {
        self.runInner() catch |err| {
            self.err = err;
        };
    }

    fn runInner(self: *PngReconstructWorker) Error!void {
        const stride = self.info.row_len + 1;
        for (self.row_start..self.row_end) |row_index| {
            const inflated_offset = row_index * stride;
            const output_offset = row_index * self.info.row_len;
            const filter = self.inflated[inflated_offset];
            const filtered = self.inflated[inflated_offset + 1 ..][0..self.info.row_len];
            const row = self.output[output_offset..][0..self.info.row_len];
            const previous = if (row_index == self.row_start)
                null
            else
                self.output[output_offset - self.info.row_len ..][0..self.info.row_len];
            _ = try reconstructPngScanline(filter, filtered, previous, self.info.bytes_per_pixel, row);
        }
    }
};

/// Inflate a PNG zlib payload once, then reconstruct independent row-dependency
/// segments in parallel.
///
/// PNG filters None and Sub do not reference the previous row, so either one
/// begins a dependency segment that can be reconstructed independently. Up,
/// Average, and Paeth rows remain serial within their segment. If the image has
/// no useful split points, or thread creation fails, this helper transparently
/// executes the same scalar reconstruction without changing the result.
pub fn decodePngZlibImageParallelWithOptions(
    input: []const u8,
    zlib_scratch: []u8,
    info: PngImageInfo,
    options: ZlibDecodeOptions,
    max_workers: usize,
    output: []u8,
) Error!PngImageDecodeResult {
    const output_len = try pngImageOutputLen(info);
    if (output.len < output_len) return error.OutputTooSmall;
    const zlib = try ZlibDecoder.initWithOptionsExactSize(input, zlib_scratch, options, info.zlib_payload_len);
    const inflated = zlib.decoded;
    const image_output = output[0..output_len];

    var requested_workers = @min(max_workers, max_png_reconstruct_workers);
    requested_workers = @min(requested_workers, std.Thread.getCpuCount() catch 1);
    requested_workers = @min(requested_workers, info.height);
    if (requested_workers == 0) requested_workers = 1;

    const stride = info.row_len + 1;
    var cuts: [max_png_reconstruct_workers + 1]usize = @splat(info.height);
    cuts[0] = 0;
    var cut_count: usize = 1;
    var split_index: usize = 1;
    while (split_index < requested_workers) : (split_index += 1) {
        const target = info.height * split_index / requested_workers;
        var row = @max(target, cuts[cut_count - 1] + 1);
        while (row < info.height) : (row += 1) {
            const filter = inflated[row * stride];
            if (filter > @intFromEnum(PngFilterMethod.paeth)) return error.CorruptFrame;
            if (filter == @intFromEnum(PngFilterMethod.none) or
                filter == @intFromEnum(PngFilterMethod.sub))
            {
                cuts[cut_count] = row;
                cut_count += 1;
                break;
            }
        }
    }
    cuts[cut_count] = info.height;

    // Validate filters not visited while searching for cuts before any worker
    // starts mutating output. This preserves deterministic corruption errors.
    for (0..info.height) |row| {
        if (inflated[row * stride] > @intFromEnum(PngFilterMethod.paeth)) return error.CorruptFrame;
    }

    var workers: [max_png_reconstruct_workers]PngReconstructWorker = undefined;
    for (0..cut_count) |worker_index| {
        workers[worker_index] = .{
            .inflated = inflated,
            .output = image_output,
            .info = info,
            .row_start = cuts[worker_index],
            .row_end = cuts[worker_index + 1],
        };
    }

    if (cut_count == 1) {
        workers[0].run();
    } else {
        var threads: [max_png_reconstruct_workers - 1]std.Thread = undefined;
        var spawned: usize = 0;
        var worker_index: usize = 1;
        while (worker_index < cut_count) : (worker_index += 1) {
            threads[spawned] = std.Thread.spawn(.{}, PngReconstructWorker.run, .{&workers[worker_index]}) catch {
                for (threads[0..spawned]) |thread| thread.join();
                // Re-running completed segments is harmless and gives resource-
                // constrained targets the same scalar result.
                for (workers[0..cut_count]) |*worker| worker.run();
                spawned = 0;
                break;
            };
            spawned += 1;
        }
        if (spawned != 0) {
            workers[0].run();
            for (threads[0..spawned]) |thread| thread.join();
        }
    }
    for (workers[0..cut_count]) |worker| if (worker.err) |err| return err;

    return .{
        .rows = info.height,
        .output_written = output_len,
        .zlib_input_read = input.len,
    };
}

/// Decode an all-filter-None, dynamic-Huffman PNG zlib stream directly into
/// compact image storage.
///
/// This is an explicitly narrow throughput specialization. It reports
/// `UnsupportedDeflateFeature` for stored/fixed blocks, incomplete semantic
/// Huffman tables, aliased input/output, or the first nonzero PNG filter byte;
/// callers must then restart through the general PNG reconstruction path.
// Typical split dynamic blocks from the PNG corpus decode to about 17--22 KiB,
// but larger filter-0/RLE-heavy blocks (notably Lohengrin-style text scans)
// still fit comfortably in L2 with a 48 KiB scratch. Keeping those blocks on
// the linear fast path avoids falling back to the virtual-history sink while
// preserving a bounded stack allocation for unusually large blocks.
const png_filter0_linear_block_scratch_len = 48 * 1024;

fn appendPngFilter0LinearBlock(
    sink: *PngFilter0SemanticSink,
    block_output: []const u8,
) Error!void {
    var src: usize = 0;
    while (src < block_output.len) {
        if (sink.row_remaining == 0) {
            if (block_output[src] != @intFromEnum(PngFilterMethod.none)) {
                return error.UnsupportedDeflateFeature;
            }
            if (sink.virtual_pos == sink.expected_virtual_len) return error.OutputTooSmall;
            sink.row_remaining = sink.row_len;
            sink.virtual_pos += 1;
            src += 1;
            continue;
        }

        const count = @min(block_output.len - src, sink.row_remaining);
        if (count > sink.output.len - sink.output_pos) return error.OutputTooSmall;
        @memcpy(
            sink.output[sink.output_pos..][0..count],
            block_output[src..][0..count],
        );
        sink.advanceRowData(count);
        src += count;
    }
}

fn tryDecodePngFilter0LinearRleBlock(
    reader: *bitstream.BufferedBitReader,
    sink: *PngFilter0SemanticSink,
    decoder: *const SemanticDynamicDecoder,
    scratch: []u8,
) Error!bool {
    const saved_reader = reader.*;
    const written = decodeSemanticDynamicBlockIntoRle1BufferedReader(
        reader,
        scratch,
        decoder,
    ) catch |err| switch (err) {
        // A block can begin with a distance-one match that refers to the
        // preceding block, or can exceed the bounded stack scratch. Restore the
        // exact reservoir and let the compact history-aware sink decode that
        // uncommon block.
        error.InvalidMatch, error.OutputTooSmall => {
            reader.* = saved_reader;
            return false;
        },
        else => return err,
    };
    try appendPngFilter0LinearBlock(sink, scratch[0..written]);
    return true;
}

pub fn decodePngFilter0DynamicZlibImageWithOptions(
    input: []const u8,
    info: PngImageInfo,
    options: ZlibDecodeOptions,
    output: []u8,
) Error!PngImageDecodeResult {
    const output_len = try pngImageOutputLen(info);
    if (output.len < output_len) return error.OutputTooSmall;
    const image_output = output[0..output_len];
    if (slicesOverlapForSemanticDecode(input, image_output)) return error.UnsupportedDeflateFeature;

    const zlib_header = try parseZlibHeader(input, null);
    var reader = bitstream.BufferedBitReader.init(input[zlib_header.data_offset..]);
    var sink = try PngFilter0SemanticSink.init(image_output, info);
    var linear_block_scratch: [png_filter0_linear_block_scratch_len]u8 = undefined;

    while (true) {
        const header = try readBlockHeader(&reader);
        if (header.block_type != 2) return error.UnsupportedDeflateFeature;

        const parsed = try huffman.parseDynamicLengthsAfterHeader(header.final, &reader);
        const literal_table_ = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
        const distance_table_ = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
        var decoder: SemanticDynamicDecoder = undefined;
        if (distance_table_.len == 1) {
            if (!decoder.initSingleDistance(&literal_table_, &distance_table_)) return error.UnsupportedDeflateFeature;
            const distance_entry = distance_table_.entries[0];
            const used_linear_block = distance_entry.symbol == 0 and
                distance_entry.bits == 1 and
                try tryDecodePngFilter0LinearRleBlock(
                    &reader,
                    &sink,
                    &decoder,
                    &linear_block_scratch,
                );
            if (!used_linear_block) {
                try decodeSemanticDynamicBlockIntoSingleDistanceSink(&reader, &sink, &decoder);
            }
        } else {
            if (!decoder.init(&literal_table_, &distance_table_)) return error.UnsupportedDeflateFeature;
            try decodeSemanticDynamicBlockIntoSink(&reader, &sink, &decoder);
        }
        if (header.final) break;
    }

    try sink.finish();
    const footer_offset = zlib_header.data_offset + reader.byteOffset();
    const actual_adler = if (options.ignore_adler) 0 else pngFilter0Adler32(image_output, info);
    try validateZlibFooterWithOptions(input, footer_offset, actual_adler, options);
    return .{
        .rows = info.height,
        .output_written = output_len,
        .zlib_input_read = footer_offset + 4,
    };
}

fn pngFilter0Adler32(output: []const u8, info: PngImageInfo) u32 {
    std.debug.assert(output.len == info.row_len * info.height);
    var adler = checksum.Adler32.init();
    for (0..info.height) |row| {
        adler.update(&.{0});
        adler.update(output[row * info.row_len ..][0..info.row_len]);
    }
    return adler.digest();
}

pub fn decodePngZlibImageFromChunks(
    chunks: []const []const u8,
    compressed_scratch: []u8,
    zlib_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngImageInfo,
    output: []u8,
) Error!PngImageDecodeResult {
    const output_len = try pngImageOutputLen(info);
    if (output.len < output_len) return error.OutputTooSmall;
    var decoder = try PngZlibScanlineDecoder.initFromChunksWithInfo(chunks, compressed_scratch, zlib_scratch, filtered_row_scratch, previous_row_scratch, info);
    return drainPngZlibImage(&decoder, output[0..output_len]);
}

pub fn decodePngZlibImageFromChunksDirect(
    chunks: []const []const u8,
    zlib_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngImageInfo,
    output: []u8,
) Error!PngImageDecodeResult {
    return decodePngZlibImageFromChunksWithOptionsDirect(chunks, zlib_scratch, filtered_row_scratch, previous_row_scratch, info, .{}, output);
}

pub fn decodePngZlibImageFromChunksWithOptionsDirect(
    chunks: []const []const u8,
    zlib_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngImageInfo,
    options: ZlibDecodeOptions,
    output: []u8,
) Error!PngImageDecodeResult {
    const output_len = try pngImageOutputLen(info);
    if (output.len < output_len) return error.OutputTooSmall;
    var decoder = try PngZlibScanlineDecoder.initFromChunksWithInfoAndOptionsDirect(chunks, zlib_scratch, filtered_row_scratch, previous_row_scratch, info, options);
    return drainPngZlibImage(&decoder, output[0..output_len]);
}

fn drainPngZlibImage(decoder: *PngZlibScanlineDecoder, output: []u8) Error!PngImageDecodeResult {
    var offset: usize = 0;
    var zlib_input_read: usize = 0;
    for (0..decoder.row_count) |_| {
        const row = output[offset..][0..decoder.row_len];
        const previous = previousPngOutputRow(output, offset, decoder.row_len);
        const step = try decoder.zlib.stepPngScanlineReconstructDirect(previous, decoder.bytes_per_pixel, row);
        offset += step.row_bytes;
        zlib_input_read += step.progress.input_read;
        decoder.row_index += 1;
    }
    if (!decoder.snapshot().done) {
        decoder.zlib.recordError(error.SizeMismatch);
        return error.SizeMismatch;
    }
    return .{
        .rows = decoder.row_count,
        .output_written = offset,
        .zlib_input_read = zlib_input_read,
    };
}

test "png filter0 dynamic direct decode matches general reconstruction and rejects fallback shapes" {
    const row_len = 257;
    const row_count = 37;
    const info = try pngImageInfo(row_len, row_count, 8, .grayscale);
    var filtered: [row_count * (row_len + 1)]u8 = undefined;
    for (0..row_count) |row| {
        const start = row * (row_len + 1);
        filtered[start] = 0;
        for (0..row_len) |column| {
            filtered[start + 1 + column] = @truncate(
                (row * 19 + column * 7 + (column / 13) * 29) ^
                    (if (column > 96) @as(usize, filtered[start + 1 + column - 97]) else 0),
            );
        }
    }

    const encoded = try encodeZlibDynamicWithOptionsAlloc(std.testing.allocator, &filtered, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);

    var expected: [row_count * row_len]u8 = undefined;
    var zlib_scratch: [filtered.len]u8 = undefined;
    var filtered_row: [row_len]u8 = undefined;
    var previous_row: [row_len]u8 = undefined;
    _ = try decodePngZlibImageWithOptions(
        encoded,
        &zlib_scratch,
        &filtered_row,
        &previous_row,
        info,
        .{},
        &expected,
    );

    var actual: [row_count * row_len]u8 = undefined;
    const result = try decodePngFilter0DynamicZlibImageWithOptions(encoded, info, .{}, &actual);
    try std.testing.expectEqual(row_count, result.rows);
    try std.testing.expectEqual(actual.len, result.output_written);
    try std.testing.expectEqual(encoded.len, result.zlib_input_read);
    try std.testing.expectEqualSlices(u8, &expected, &actual);

    var malformed = filtered;
    malformed[(row_len + 1) * 11] = 2;
    const nonzero_filter = try encodeZlibDynamicWithOptionsAlloc(std.testing.allocator, &malformed, optionsForLevel(.default));
    defer std.testing.allocator.free(nonzero_filter);
    try std.testing.expectError(
        error.UnsupportedDeflateFeature,
        decodePngFilter0DynamicZlibImageWithOptions(nonzero_filter, info, .{}, &actual),
    );

    const fixed = try encodeZlibFixedWithOptionsAlloc(std.testing.allocator, &filtered, optionsForLevel(.default));
    defer std.testing.allocator.free(fixed);
    try std.testing.expectError(
        error.UnsupportedDeflateFeature,
        decodePngFilter0DynamicZlibImageWithOptions(fixed, info, .{}, &actual),
    );
}

test "png filter0 linear RLE block matches compact fallback and restores reader" {
    const row_len = 33;
    const row_count = 1;
    const info = try pngImageInfo(row_len, row_count, 8, .grayscale);
    const tokens = [_]lz77.Token{
        .{ .literal = 0 },
        .{ .match = .{ .length = 3, .distance = 1 } },
        .{ .match = .{ .length = 4, .distance = 1 } },
        .{ .match = .{ .length = 5, .distance = 1 } },
        .{ .match = .{ .length = 6, .distance = 1 } },
        .{ .match = .{ .length = 7, .distance = 1 } },
        .{ .match = .{ .length = 8, .distance = 1 } },
    };
    const raw = try encodeRawDynamicTokensAlloc(std.testing.allocator, &tokens);
    defer std.testing.allocator.free(raw);

    var success_reader = bitstream.BufferedBitReader.init(raw);
    const success_header = try readBlockHeader(&success_reader);
    const success_parsed = try huffman.parseDynamicLengthsAfterHeader(success_header.final, &success_reader);
    const success_literal_table = try huffman.HuffmanTable(286).init(
        success_parsed.literal_lengths[0..success_parsed.header.hlit],
    );
    const single_distance_lengths = [_]u4{1};
    const success_distance_table = try huffman.HuffmanTable(30).init(&single_distance_lengths);
    try std.testing.expectEqual(@as(usize, 1), success_distance_table.len);
    try std.testing.expectEqual(@as(u16, 0), success_distance_table.entries[0].symbol);
    var success_decoder: SemanticDynamicDecoder = undefined;
    try std.testing.expect(success_decoder.initSingleDistance(
        &success_literal_table,
        &success_distance_table,
    ));

    var success_output: [row_count * row_len]u8 = undefined;
    var success_sink = try PngFilter0SemanticSink.init(&success_output, info);
    var success_scratch: [row_count * (row_len + 1)]u8 = undefined;
    try std.testing.expect(try tryDecodePngFilter0LinearRleBlock(
        &success_reader,
        &success_sink,
        &success_decoder,
        &success_scratch,
    ));
    try success_sink.finish();
    try std.testing.expectEqualSlices(u8, &([_]u8{0} ** success_output.len), &success_output);

    var fallback_reader = bitstream.BufferedBitReader.init(raw);
    const fallback_header = try readBlockHeader(&fallback_reader);
    const fallback_parsed = try huffman.parseDynamicLengthsAfterHeader(fallback_header.final, &fallback_reader);
    const fallback_literal_table = try huffman.HuffmanTable(286).init(
        fallback_parsed.literal_lengths[0..fallback_parsed.header.hlit],
    );
    const fallback_distance_table = try huffman.HuffmanTable(30).init(&single_distance_lengths);
    var fallback_decoder: SemanticDynamicDecoder = undefined;
    try std.testing.expect(fallback_decoder.initSingleDistance(
        &fallback_literal_table,
        &fallback_distance_table,
    ));

    var fallback_output: [row_count * row_len]u8 = undefined;
    var fallback_sink = try PngFilter0SemanticSink.init(&fallback_output, info);
    var too_small_scratch: [8]u8 = undefined;
    const saved_reader = fallback_reader;
    try std.testing.expect(!try tryDecodePngFilter0LinearRleBlock(
        &fallback_reader,
        &fallback_sink,
        &fallback_decoder,
        &too_small_scratch,
    ));
    try std.testing.expectEqual(saved_reader.byte_index, fallback_reader.byte_index);
    try std.testing.expectEqual(saved_reader.bit_buffer, fallback_reader.bit_buffer);
    try std.testing.expectEqual(saved_reader.bit_count, fallback_reader.bit_count);
    try std.testing.expectEqual(saved_reader.consumed_bits, fallback_reader.consumed_bits);

    try decodeSemanticDynamicBlockIntoSingleDistanceSink(
        &fallback_reader,
        &fallback_sink,
        &fallback_decoder,
    );
    try fallback_sink.finish();
    try std.testing.expectEqualSlices(u8, &success_output, &fallback_output);
}

test "png parallel reconstruction matches scalar mixed filters" {
    const row_len = 96;
    const row_count = 32;
    const bpp = 3;
    const info = try pngImageInfo(row_len / bpp, row_count, 8, .truecolor);
    var rows: [row_count][row_len]u8 = undefined;
    var filtered_payload: [row_count * (row_len + 1)]u8 = undefined;
    for (0..row_count) |row_index| {
        for (0..row_len) |column| {
            rows[row_index][column] = @truncate(row_index * 29 + column * 13 + (column / 3) * 7);
        }
        // Put independent None/Sub rows near worker boundaries while retaining
        // Up/Average/Paeth chains inside each segment.
        const filter: u8 = switch (row_index % 8) {
            0 => 0,
            4 => 1,
            else => @intCast(2 + row_index % 3),
        };
        const offset = row_index * (row_len + 1);
        filtered_payload[offset] = filter;
        filterPngScanlineForTest(
            filter,
            &rows[row_index],
            if (row_index == 0) null else &rows[row_index - 1],
            bpp,
            filtered_payload[offset + 1 ..][0..row_len],
        );
    }
    const encoded = try encodeZlibDynamicWithOptionsAlloc(std.testing.allocator, &filtered_payload, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);

    var scalar_output: [row_count * row_len]u8 = undefined;
    var scalar_scratch: [filtered_payload.len]u8 = undefined;
    var filtered_row: [row_len]u8 = undefined;
    var previous_row: [row_len]u8 = undefined;
    _ = try decodePngZlibImageWithOptions(
        encoded,
        &scalar_scratch,
        &filtered_row,
        &previous_row,
        info,
        .{},
        &scalar_output,
    );

    var parallel_output: [row_count * row_len]u8 = undefined;
    var parallel_scratch: [filtered_payload.len]u8 = undefined;
    const result = try decodePngZlibImageParallelWithOptions(
        encoded,
        &parallel_scratch,
        info,
        .{},
        4,
        &parallel_output,
    );
    try std.testing.expectEqual(row_count, result.rows);
    try std.testing.expectEqual(parallel_output.len, result.output_written);
    try std.testing.expectEqualSlices(u8, &scalar_output, &parallel_output);
}

fn drainPngStreamingZlibImage(decoder: *PngStreamingZlibScanlineDecoder, output: []u8) Error!PngImageDecodeResult {
    var offset: usize = 0;
    for (0..decoder.row_count) |_| {
        const row = output[offset..][0..decoder.row_len];
        const previous = previousPngOutputRow(output, offset, decoder.row_len);
        const step = try decoder.stepWithPrevious(row, previous);
        offset += step.row_bytes;
    }
    if (!decoder.snapshot().done) return error.SizeMismatch;
    return .{
        .rows = decoder.row_count,
        .output_written = offset,
        .zlib_input_read = decoder.snapshot().input_read,
    };
}

fn drainPngStreamingZlibChunksImage(decoder: *PngStreamingZlibChunkedScanlineDecoder, output: []u8) Error!PngImageDecodeResult {
    var offset: usize = 0;
    for (0..decoder.row_count) |_| {
        const row = output[offset..][0..decoder.row_len];
        const previous = previousPngOutputRow(output, offset, decoder.row_len);
        const step = try decoder.stepWithPrevious(row, previous);
        offset += step.row_bytes;
    }
    if (!decoder.snapshot().done) return error.SizeMismatch;
    return .{
        .rows = decoder.row_count,
        .output_written = offset,
        .zlib_input_read = decoder.snapshot().input_read,
    };
}

fn previousPngOutputRow(output: []const u8, offset: usize, row_len: usize) ?[]const u8 {
    // Whole-image PNG drainers write rows contiguously, so the previous
    // reconstructed row is already resident immediately before the destination
    // row. Passing that slice into reconstruction avoids copying every row into
    // the decoder's public row-iteration scratch. The public `step` APIs keep
    // updating their scratch because their callers may reuse a single output
    // row buffer between calls.
    return if (offset == 0) null else output[offset - row_len ..][0..row_len];
}

fn drainPngStoredZlibImage(decoder: *PngStoredZlibScanlineDecoder, output: []u8) Error!PngImageDecodeResult {
    var offset: usize = 0;
    var zlib_input_read: usize = 0;
    for (0..decoder.row_count) |_| {
        const row = output[offset..][0..decoder.row_len];
        const step = try decoder.step(row);
        offset += step.row_bytes;
        zlib_input_read += step.progress.input_read;
    }
    if (!decoder.snapshot().done) return error.SizeMismatch;
    return .{
        .rows = decoder.row_count,
        .output_written = offset,
        .zlib_input_read = zlib_input_read,
    };
}

fn drainPngStoredZlibChunksImage(decoder: *PngStoredZlibChunkedScanlineDecoder, output: []u8) Error!PngImageDecodeResult {
    var offset: usize = 0;
    var zlib_input_read: usize = 0;
    for (0..decoder.row_count) |_| {
        const row = output[offset..][0..decoder.row_len];
        const step = try decoder.step(row);
        offset += step.row_bytes;
        zlib_input_read += step.progress.input_read;
    }
    if (!decoder.snapshot().done) return error.SizeMismatch;
    return .{
        .rows = decoder.row_count,
        .output_written = offset,
        .zlib_input_read = zlib_input_read,
    };
}

pub fn decodePngAdam7ZlibImage(
    input: []const u8,
    zlib_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngAdam7Info,
    output: []u8,
) Error!PngAdam7ImageDecodeResult {
    try validatePngAdam7DecodeBuffers(info, filtered_row_scratch, previous_row_scratch, output);
    var zlib = try ZlibDecoder.initExactSize(input, zlib_scratch, info.zlib_payload_len);
    return drainPngAdam7ZlibImage(&zlib, filtered_row_scratch, previous_row_scratch, info, output[0..info.image_output_len]);
}

pub fn decodePngAdam7ZlibImageFromChunks(
    chunks: []const []const u8,
    compressed_scratch: []u8,
    zlib_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngAdam7Info,
    output: []u8,
) Error!PngAdam7ImageDecodeResult {
    try validatePngAdam7DecodeBuffers(info, filtered_row_scratch, previous_row_scratch, output);
    var zlib = try ZlibDecoder.initFromChunksExactSize(chunks, compressed_scratch, zlib_scratch, info.zlib_payload_len);
    return drainPngAdam7ZlibImage(&zlib, filtered_row_scratch, previous_row_scratch, info, output[0..info.image_output_len]);
}

pub fn decodePngAdam7ZlibImageFromChunksDirect(
    chunks: []const []const u8,
    zlib_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngAdam7Info,
    output: []u8,
) Error!PngAdam7ImageDecodeResult {
    return decodePngAdam7ZlibImageFromChunksWithOptionsDirect(chunks, zlib_scratch, filtered_row_scratch, previous_row_scratch, info, .{}, output);
}

pub fn decodePngAdam7ZlibImageFromChunksWithOptionsDirect(
    chunks: []const []const u8,
    zlib_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngAdam7Info,
    options: ZlibDecodeOptions,
    output: []u8,
) Error!PngAdam7ImageDecodeResult {
    try validatePngAdam7DecodeBuffers(info, filtered_row_scratch, previous_row_scratch, output);
    var zlib = try ZlibDecoder.initFromChunksWithOptionsExactSizeDirect(chunks, zlib_scratch, options, info.zlib_payload_len);
    return drainPngAdam7ZlibImage(&zlib, filtered_row_scratch, previous_row_scratch, info, output[0..info.image_output_len]);
}

pub fn decodePngAdam7StreamingZlibImage(
    input: []const u8,
    history_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngAdam7Info,
    output: []u8,
) Error!PngAdam7ImageDecodeResult {
    return decodePngAdam7StreamingZlibImageWithOptions(input, history_scratch, filtered_row_scratch, previous_row_scratch, info, .{}, output);
}

pub fn decodePngAdam7StreamingZlibImageWithOptions(
    input: []const u8,
    history_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngAdam7Info,
    options: ZlibDecodeOptions,
    output: []u8,
) Error!PngAdam7ImageDecodeResult {
    try validatePngAdam7StreamingDecodeBuffers(info, history_scratch, filtered_row_scratch, previous_row_scratch, output);
    @memset(output[0..info.image_output_len], 0);
    var decoder = try PngAdam7StreamingZlibRowDecoder.initWithOptions(input, history_scratch, filtered_row_scratch, previous_row_scratch, info, options);
    while (try decoder.step()) |row| try placePngAdam7Row(info, row.pass, row.pass_row_index, row.row, output);
    const snap = decoder.snapshot();
    return .{
        .passes = pngAdam7ActivePassCount(info),
        .rows = snap.rows_done,
        .output_written = info.image_output_len,
        .zlib_input_read = snap.zlib_input_read,
    };
}

pub fn streamPngAdam7ZlibRows(
    input: []const u8,
    history_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngAdam7Info,
    callback: PngAdam7RowCallback,
) Error!PngAdam7RowsDecodeResult {
    return streamPngAdam7ZlibRowsWithOptions(input, history_scratch, filtered_row_scratch, previous_row_scratch, info, .{}, callback);
}

pub fn streamPngAdam7ZlibRowsWithOptions(
    input: []const u8,
    history_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngAdam7Info,
    options: ZlibDecodeOptions,
    callback: PngAdam7RowCallback,
) Error!PngAdam7RowsDecodeResult {
    var decoder = try PngAdam7StreamingZlibRowDecoder.initWithOptions(input, history_scratch, filtered_row_scratch, previous_row_scratch, info, options);
    while (try decoder.step()) |row| try callback.on_row(callback.context, row);
    const snap = decoder.snapshot();
    return .{
        .passes = pngAdam7ActivePassCount(info),
        .rows = snap.rows_done,
        .row_bytes = snap.row_bytes,
        .zlib_input_read = snap.zlib_input_read,
    };
}

pub fn decodePngAdam7StreamingZlibImageFromChunksDirect(
    chunks: []const []const u8,
    history_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngAdam7Info,
    output: []u8,
) Error!PngAdam7ImageDecodeResult {
    return decodePngAdam7StreamingZlibImageFromChunksWithOptionsDirect(chunks, history_scratch, filtered_row_scratch, previous_row_scratch, info, .{}, output);
}

pub fn decodePngAdam7StreamingZlibImageFromChunksWithOptionsDirect(
    chunks: []const []const u8,
    history_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngAdam7Info,
    options: ZlibDecodeOptions,
    output: []u8,
) Error!PngAdam7ImageDecodeResult {
    try validatePngAdam7StreamingDecodeBuffers(info, history_scratch, filtered_row_scratch, previous_row_scratch, output);
    @memset(output[0..info.image_output_len], 0);
    var decoder = try PngAdam7StreamingZlibChunkedRowDecoder.initWithOptionsDirect(chunks, history_scratch, filtered_row_scratch, previous_row_scratch, info, options);
    while (try decoder.step()) |row| try placePngAdam7Row(info, row.pass, row.pass_row_index, row.row, output);
    const snap = decoder.snapshot();
    return .{
        .passes = pngAdam7ActivePassCount(info),
        .rows = snap.rows_done,
        .output_written = info.image_output_len,
        .zlib_input_read = snap.zlib_input_read,
    };
}

pub fn streamPngAdam7ZlibRowsFromChunksDirect(
    chunks: []const []const u8,
    history_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngAdam7Info,
    callback: PngAdam7RowCallback,
) Error!PngAdam7RowsDecodeResult {
    return streamPngAdam7ZlibRowsFromChunksWithOptionsDirect(chunks, history_scratch, filtered_row_scratch, previous_row_scratch, info, .{}, callback);
}

pub fn streamPngAdam7ZlibRowsFromChunksWithOptionsDirect(
    chunks: []const []const u8,
    history_scratch: []u8,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngAdam7Info,
    options: ZlibDecodeOptions,
    callback: PngAdam7RowCallback,
) Error!PngAdam7RowsDecodeResult {
    var decoder = try PngAdam7StreamingZlibChunkedRowDecoder.initWithOptionsDirect(chunks, history_scratch, filtered_row_scratch, previous_row_scratch, info, options);
    while (try decoder.step()) |row| try callback.on_row(callback.context, row);
    const snap = decoder.snapshot();
    return .{
        .passes = pngAdam7ActivePassCount(info),
        .rows = snap.rows_done,
        .row_bytes = snap.row_bytes,
        .zlib_input_read = snap.zlib_input_read,
    };
}

const PngAdam7StreamingRowState = struct {
    info: PngAdam7Info,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    pass_index: usize = 0,
    pass_row_index: usize = 0,
    has_previous: bool = false,
    rows_done: usize = 0,
    row_bytes: usize = 0,
    finished: bool = false,
};

pub const PngAdam7StreamingRowsSnapshot = struct {
    pass_index: usize,
    pass_row_index: usize,
    rows_done: usize,
    row_bytes: usize,
    done: bool,
    zlib_input_read: usize,
};

pub const PngAdam7StreamingZlibRowDecoder = struct {
    zlib: PngStreamingZlibScanlineDecoder = .{},
    state: PngAdam7StreamingRowState = undefined,

    pub fn init(
        input: []const u8,
        history_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngAdam7Info,
    ) Error!PngAdam7StreamingZlibRowDecoder {
        return initWithOptions(input, history_scratch, filtered_row_scratch, previous_row_scratch, info, .{});
    }

    pub fn initWithOptions(
        input: []const u8,
        history_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngAdam7Info,
        options: ZlibDecodeOptions,
    ) Error!PngAdam7StreamingZlibRowDecoder {
        try validatePngAdam7StreamingRowBuffers(info, history_scratch, filtered_row_scratch, previous_row_scratch);
        return .{
            .zlib = try PngStreamingZlibScanlineDecoder.initRawWithOptions(input, history_scratch, options),
            .state = initPngAdam7StreamingRowState(info, filtered_row_scratch, previous_row_scratch),
        };
    }

    pub fn step(self: *PngAdam7StreamingZlibRowDecoder) Error!?PngAdam7Row {
        return stepPngAdam7StreamingZlibRow(&self.zlib, &self.state);
    }

    pub fn snapshot(self: *const PngAdam7StreamingZlibRowDecoder) PngAdam7StreamingRowsSnapshot {
        return pngAdam7StreamingRowsSnapshot(self.state, self.zlib.snapshot().input_read);
    }
};

pub const PngAdam7StreamingZlibChunkedRowDecoder = struct {
    zlib: PngStreamingZlibChunkedScanlineDecoder = .{},
    state: PngAdam7StreamingRowState = undefined,

    pub fn initDirect(
        chunks: []const []const u8,
        history_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngAdam7Info,
    ) Error!PngAdam7StreamingZlibChunkedRowDecoder {
        return initWithOptionsDirect(chunks, history_scratch, filtered_row_scratch, previous_row_scratch, info, .{});
    }

    pub fn initWithOptionsDirect(
        chunks: []const []const u8,
        history_scratch: []u8,
        filtered_row_scratch: []u8,
        previous_row_scratch: []u8,
        info: PngAdam7Info,
        options: ZlibDecodeOptions,
    ) Error!PngAdam7StreamingZlibChunkedRowDecoder {
        try validatePngAdam7StreamingRowBuffers(info, history_scratch, filtered_row_scratch, previous_row_scratch);
        return .{
            .zlib = try PngStreamingZlibChunkedScanlineDecoder.initRawWithOptions(chunks, history_scratch, options),
            .state = initPngAdam7StreamingRowState(info, filtered_row_scratch, previous_row_scratch),
        };
    }

    pub fn step(self: *PngAdam7StreamingZlibChunkedRowDecoder) Error!?PngAdam7Row {
        return stepPngAdam7StreamingZlibRow(&self.zlib, &self.state);
    }

    pub fn snapshot(self: *const PngAdam7StreamingZlibChunkedRowDecoder) PngAdam7StreamingRowsSnapshot {
        return pngAdam7StreamingRowsSnapshot(self.state, self.zlib.snapshot().input_read);
    }
};

fn initPngAdam7StreamingRowState(info: PngAdam7Info, filtered_row_scratch: []u8, previous_row_scratch: []u8) PngAdam7StreamingRowState {
    return .{
        .info = info,
        .filtered_row_scratch = filtered_row_scratch[0..info.max_pass_row_len],
        .previous_row_scratch = previous_row_scratch[0..info.max_pass_row_len],
    };
}

fn pngAdam7StreamingRowsSnapshot(state: PngAdam7StreamingRowState, zlib_input_read: usize) PngAdam7StreamingRowsSnapshot {
    return .{
        .pass_index = state.pass_index,
        .pass_row_index = state.pass_row_index,
        .rows_done = state.rows_done,
        .row_bytes = state.row_bytes,
        .done = state.finished,
        .zlib_input_read = zlib_input_read,
    };
}

fn stepPngAdam7StreamingZlibRow(zlib: anytype, state: *PngAdam7StreamingRowState) Error!?PngAdam7Row {
    if (state.finished) return null;

    while (state.pass_index < state.info.passes.len) {
        const pass = state.info.passes[state.pass_index];
        if (pass.isEmpty()) {
            state.pass_index += 1;
            state.pass_row_index = 0;
            state.has_previous = false;
            continue;
        }
        if (state.pass_row_index >= pass.height) {
            state.pass_index += 1;
            state.pass_row_index = 0;
            state.has_previous = false;
            continue;
        }

        const row = state.filtered_row_scratch[0..pass.row_len];
        const filter = (try zlib.readInflatedByteOrEnd()) orelse return error.SizeMismatch;
        if (filter > 4) return error.CorruptFrame;
        try zlib.readInflatedBytes(row);
        const previous = if (state.has_previous) state.previous_row_scratch[0..pass.row_len] else null;
        _ = try reconstructPngScanline(filter, row, previous, pass.bytes_per_pixel, row);
        @memcpy(state.previous_row_scratch[0..pass.row_len], row);

        const pass_row_index = state.pass_row_index;
        state.pass_row_index += 1;
        state.has_previous = true;
        state.rows_done += 1;
        state.row_bytes = std.math.add(usize, state.row_bytes, row.len) catch return error.IntegerOverflow;
        return .{
            .pass = pass,
            .pass_row_index = pass_row_index,
            .row = row,
        };
    }

    try zlib.finishRawPayload();
    state.finished = true;
    return null;
}

fn pngAdam7ActivePassCount(info: PngAdam7Info) usize {
    var count: usize = 0;
    for (info.passes) |pass| {
        if (!pass.isEmpty()) count += 1;
    }
    return count;
}

fn validatePngAdam7DecodeBuffers(info: PngAdam7Info, filtered_row_scratch: []u8, previous_row_scratch: []u8, output: []u8) Error!void {
    if (filtered_row_scratch.len < info.max_pass_row_len or previous_row_scratch.len < info.max_pass_row_len) return error.OutputTooSmall;
    if (output.len < info.image_output_len) return error.OutputTooSmall;
}

fn validatePngAdam7StreamingRowBuffers(info: PngAdam7Info, history_scratch: []u8, filtered_row_scratch: []u8, previous_row_scratch: []u8) Error!void {
    if (filtered_row_scratch.len < info.max_pass_row_len or previous_row_scratch.len < info.max_pass_row_len) return error.OutputTooSmall;
    if (history_scratch.len < PngStreamingZlibScanlineDecoder.history_scratch_len) return error.OutputTooSmall;
}

fn validatePngAdam7StreamingDecodeBuffers(info: PngAdam7Info, history_scratch: []u8, filtered_row_scratch: []u8, previous_row_scratch: []u8, output: []u8) Error!void {
    try validatePngAdam7StreamingRowBuffers(info, history_scratch, filtered_row_scratch, previous_row_scratch);
    if (output.len < info.image_output_len) return error.OutputTooSmall;
}

fn drainPngAdam7ZlibImage(
    zlib: *ZlibDecoder,
    filtered_row_scratch: []u8,
    previous_row_scratch: []u8,
    info: PngAdam7Info,
    output: []u8,
) Error!PngAdam7ImageDecodeResult {
    @memset(output[0..info.image_output_len], 0);
    var pass_count: usize = 0;
    var row_count: usize = 0;
    var zlib_input_read: usize = 0;
    for (info.passes) |pass| {
        if (pass.isEmpty()) continue;
        pass_count += 1;
        var has_previous = false;
        for (0..pass.height) |row_index| {
            // Reconstruct in-place: filtered_row_scratch first receives the PNG
            // filtered scanline payload, then becomes the reconstructed pass row
            // consumed by Adam7 placement. This keeps the interlaced helper to
            // the same two row scratch buffers used by the non-interlaced path.
            const row = filtered_row_scratch[0..pass.row_len];
            const previous = if (has_previous) previous_row_scratch[0..pass.row_len] else null;
            const step = try zlib.stepPngScanlineReconstruct(row, previous, pass.bytes_per_pixel, row);
            try placePngAdam7Row(info, pass, row_index, row, output);
            @memcpy(previous_row_scratch[0..pass.row_len], row);
            has_previous = true;
            row_count += 1;
            zlib_input_read += step.progress.input_read;
        }
    }
    if (!zlib.snapshot().done) {
        zlib.recordError(error.SizeMismatch);
        return error.SizeMismatch;
    }
    return .{
        .passes = pass_count,
        .rows = row_count,
        .output_written = info.image_output_len,
        .zlib_input_read = zlib_input_read,
    };
}

fn decodeZlibWithOptionalDictionary(input: []const u8, output: []u8, dictionary: ?[]const u8) Error!usize {
    return decodeZlibWithOptionalDictionaryAndOptions(input, output, dictionary, .{});
}

fn decodeZlibWithOptionalDictionaryAndOptions(input: []const u8, output: []u8, dictionary: ?[]const u8, options: ZlibDecodeOptions) Error!usize {
    const header = try parseZlibHeader(input, dictionary);
    const raw_dictionary = if (header.uses_dictionary) dictionary.? else "";

    if (options.ignore_adler) {
        if (try decodeRawStoredOnlyIntoMaybe(input[header.data_offset..], output)) |stored| {
            const footer_offset = header.data_offset + stored.input_read;
            try validateZlibFooterWithOptions(input, footer_offset, 0, options);
            return stored.output_written;
        }
    } else {
        if (try decodeRawStoredOnlyIntoMaybeWithHash(checksum.Adler32, input[header.data_offset..], output)) |stored| {
            const footer_offset = header.data_offset + stored.result.input_read;
            try validateZlibFooterWithOptions(input, footer_offset, stored.digest, options);
            return stored.result.output_written;
        }
    }

    var reader = bitstream.BufferedBitReader.init(input[header.data_offset..]);
    const raw = try decodeRawAutoWithDictionaryFromReader(&reader, 0, raw_dictionary, output);
    const footer_offset = header.data_offset + raw.input_read;
    const actual_adler = if (options.ignore_adler) 0 else checksum.adler32(output[0..raw.output_written]);
    try validateZlibFooterWithOptions(input, footer_offset, actual_adler, options);
    return raw.output_written;
}

pub fn decodeZlibStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeZlibStoredAllocWithOptionalDictionaryLimited(allocator, input, null, null);
}

pub fn decodeZlibStoredAllocExactSize(allocator: std.mem.Allocator, input: []const u8, expected_output_len: usize) ![]u8 {
    return decodeZlibStoredAllocWithOptionalDictionaryExactSize(allocator, input, null, expected_output_len);
}

pub fn decodeZlibStoredAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    return decodeZlibStoredAllocWithOptionalDictionaryLimited(allocator, input, null, max_output_len);
}

pub fn decodeZlibStoredAllocWithDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8) ![]u8 {
    return decodeZlibStoredAllocWithOptionalDictionaryLimited(allocator, input, dictionary, null);
}

pub fn decodeZlibStoredAllocWithDictionaryExactSize(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, expected_output_len: usize) ![]u8 {
    return decodeZlibStoredAllocWithOptionalDictionaryExactSize(allocator, input, dictionary, expected_output_len);
}

pub fn decodeZlibStoredAllocWithDictionaryLimited(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, max_output_len: usize) ![]u8 {
    return decodeZlibStoredAllocWithOptionalDictionaryLimited(allocator, input, dictionary, max_output_len);
}

fn decodeZlibStoredAllocWithOptionalDictionaryExactSize(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, expected_output_len: usize) ![]u8 {
    const header = try parseZlibHeader(input, dictionary);
    const raw_input = input[header.data_offset..];
    const stored_plan = (try planRawStoredOnly(raw_input)) orelse return error.InvalidDeflateBlockType;
    if (stored_plan.output_len != expected_output_len) return error.SizeMismatch;
    try validateZlibStoredPlanBeforeAlloc(input, header.data_offset, stored_plan, .{});
    return (try decodeRawStoredOnlyAllocPlanned(allocator, raw_input, stored_plan, null)).bytes;
}

fn decodeZlibStoredAllocWithOptionalDictionaryLimited(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, max_output_len: ?usize) ![]u8 {
    const header = try parseZlibHeader(input, dictionary);
    const raw_input = input[header.data_offset..];
    const stored_plan = (try planRawStoredOnly(raw_input)) orelse return error.InvalidDeflateBlockType;
    try validateZlibStoredPlanBeforeAlloc(input, header.data_offset, stored_plan, .{});
    return (try decodeRawStoredOnlyAllocPlanned(allocator, raw_input, stored_plan, max_output_len)).bytes;
}

pub fn decodeZlibAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeZlibAllocWithOptionalDictionary(allocator, input, null);
}

pub fn decodeZlibAllocWithDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8) ![]u8 {
    return decodeZlibAllocWithOptionalDictionary(allocator, input, dictionary);
}

pub fn decodeZlibAllocWithOptions(allocator: std.mem.Allocator, input: []const u8, options: ZlibDecodeOptions) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryAndOptionsLimited(allocator, input, null, options, null);
}

pub fn decodeZlibAllocWithDictionaryAndOptions(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: ZlibDecodeOptions) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryAndOptionsLimited(allocator, input, dictionary, options, null);
}

pub fn decodeZlibAllocExactSize(allocator: std.mem.Allocator, input: []const u8, expected_output_len: usize) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryExactSize(allocator, input, null, expected_output_len);
}

pub fn decodeZlibAllocWithDictionaryExactSize(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, expected_output_len: usize) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryExactSize(allocator, input, dictionary, expected_output_len);
}

pub fn decodeZlibAllocWithOptionsExactSize(allocator: std.mem.Allocator, input: []const u8, options: ZlibDecodeOptions, expected_output_len: usize) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryAndOptionsExactSize(allocator, input, null, options, expected_output_len);
}

pub fn decodeZlibAllocWithDictionaryAndOptionsExactSize(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: ZlibDecodeOptions, expected_output_len: usize) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryAndOptionsExactSize(allocator, input, dictionary, options, expected_output_len);
}

pub fn decodeZlibAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryLimited(allocator, input, null, max_output_len);
}

pub fn decodeZlibAllocWithDictionaryLimited(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, max_output_len: usize) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryLimited(allocator, input, dictionary, max_output_len);
}

pub fn decodeZlibAllocWithOptionsLimited(allocator: std.mem.Allocator, input: []const u8, options: ZlibDecodeOptions, max_output_len: usize) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryAndOptionsLimited(allocator, input, null, options, max_output_len);
}

pub fn decodeZlibAllocWithDictionaryAndOptionsLimited(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: ZlibDecodeOptions, max_output_len: usize) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryAndOptionsLimited(allocator, input, dictionary, options, max_output_len);
}

pub fn decodeZlibChunksAlloc(allocator: std.mem.Allocator, chunks: []const []const u8) ![]u8 {
    return decodeZlibChunksAllocWithOptionalDictionaryAndOptionsLimited(allocator, chunks, null, .{}, null);
}

pub fn decodeZlibChunksAllocWithOptions(allocator: std.mem.Allocator, chunks: []const []const u8, options: ZlibDecodeOptions) ![]u8 {
    return decodeZlibChunksAllocWithOptionalDictionaryAndOptionsLimited(allocator, chunks, null, options, null);
}

pub fn decodeZlibChunksAllocWithDictionary(allocator: std.mem.Allocator, chunks: []const []const u8, dictionary: []const u8) ![]u8 {
    return decodeZlibChunksAllocWithOptionalDictionaryAndOptionsLimited(allocator, chunks, dictionary, .{}, null);
}

pub fn decodeZlibChunksAllocWithDictionaryAndOptions(allocator: std.mem.Allocator, chunks: []const []const u8, dictionary: []const u8, options: ZlibDecodeOptions) ![]u8 {
    return decodeZlibChunksAllocWithOptionalDictionaryAndOptionsLimited(allocator, chunks, dictionary, options, null);
}

pub fn decodeZlibChunksAllocExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, expected_output_len: usize) ![]u8 {
    return decodeZlibChunksAllocWithOptionalDictionaryAndOptionsExactSize(allocator, chunks, null, .{}, expected_output_len);
}

pub fn decodeZlibChunksAllocWithDictionaryExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, dictionary: []const u8, expected_output_len: usize) ![]u8 {
    return decodeZlibChunksAllocWithOptionalDictionaryAndOptionsExactSize(allocator, chunks, dictionary, .{}, expected_output_len);
}

pub fn decodeZlibChunksAllocWithOptionsExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, options: ZlibDecodeOptions, expected_output_len: usize) ![]u8 {
    return decodeZlibChunksAllocWithOptionalDictionaryAndOptionsExactSize(allocator, chunks, null, options, expected_output_len);
}

pub fn decodeZlibChunksAllocWithDictionaryAndOptionsExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, dictionary: []const u8, options: ZlibDecodeOptions, expected_output_len: usize) ![]u8 {
    return decodeZlibChunksAllocWithOptionalDictionaryAndOptionsExactSize(allocator, chunks, dictionary, options, expected_output_len);
}

pub fn decodeZlibChunksAllocLimited(allocator: std.mem.Allocator, chunks: []const []const u8, max_output_len: usize) ![]u8 {
    return decodeZlibChunksAllocWithOptionalDictionaryAndOptionsLimited(allocator, chunks, null, .{}, max_output_len);
}

pub fn decodeZlibChunksAllocWithDictionaryLimited(allocator: std.mem.Allocator, chunks: []const []const u8, dictionary: []const u8, max_output_len: usize) ![]u8 {
    return decodeZlibChunksAllocWithOptionalDictionaryAndOptionsLimited(allocator, chunks, dictionary, .{}, max_output_len);
}

pub fn decodeZlibChunksAllocWithOptionsLimited(allocator: std.mem.Allocator, chunks: []const []const u8, options: ZlibDecodeOptions, max_output_len: usize) ![]u8 {
    return decodeZlibChunksAllocWithOptionalDictionaryAndOptionsLimited(allocator, chunks, null, options, max_output_len);
}

pub fn decodeZlibChunksAllocWithDictionaryAndOptionsLimited(allocator: std.mem.Allocator, chunks: []const []const u8, dictionary: []const u8, options: ZlibDecodeOptions, max_output_len: usize) ![]u8 {
    return decodeZlibChunksAllocWithOptionalDictionaryAndOptionsLimited(allocator, chunks, dictionary, options, max_output_len);
}

pub fn decodeZlibConcatenated(input: []const u8, output: []u8) Error!usize {
    return decodeZlibConcatenatedWithOptionalDictionaryAndOptions(input, output, null, .{});
}

pub fn decodeZlibConcatenatedWithOptions(input: []const u8, output: []u8, options: ZlibDecodeOptions) Error!usize {
    return decodeZlibConcatenatedWithOptionalDictionaryAndOptions(input, output, null, options);
}

pub fn decodeZlibConcatenatedWithDictionary(input: []const u8, output: []u8, dictionary: []const u8) Error!usize {
    return decodeZlibConcatenatedWithOptionalDictionaryAndOptions(input, output, dictionary, .{});
}

pub fn decodeZlibConcatenatedWithDictionaryAndOptions(input: []const u8, output: []u8, dictionary: []const u8, options: ZlibDecodeOptions) Error!usize {
    return decodeZlibConcatenatedWithOptionalDictionaryAndOptions(input, output, dictionary, options);
}

fn decodeZlibConcatenatedWithOptionalDictionaryAndOptions(input: []const u8, output: []u8, dictionary: ?[]const u8, options: ZlibDecodeOptions) Error!usize {
    if (input.len == 0) return error.TruncatedFrame;

    var offset: usize = 0;
    var out_offset: usize = 0;
    while (offset < input.len) {
        const header = parseZlibHeader(input[offset..], dictionary) catch |err| {
            if (options.allow_trailing_data and offset != 0) break;
            return err;
        };
        const raw_dictionary = if (header.uses_dictionary) dictionary.? else "";
        const raw_offset = offset + header.data_offset;

        const raw_input = input[raw_offset..];
        if (options.ignore_adler) {
            if (raw_input.len != 0 and isStoredBlockHeaderByte(raw_input[0])) {
                if (try decodeRawStoredOnlyIntoMaybe(raw_input, output[out_offset..])) |stored| {
                    const footer_offset = raw_offset + stored.input_read;
                    try validateZlibFooterPartialWithOptions(input, footer_offset, 0, options);
                    out_offset += stored.output_written;
                    offset = footer_offset + 4;
                    continue;
                }
            }
        } else if (raw_input.len != 0 and isStoredBlockHeaderByte(raw_input[0])) {
            if (try decodeRawStoredOnlyIntoMaybeWithHash(checksum.Adler32, raw_input, output[out_offset..])) |stored| {
                const footer_offset = raw_offset + stored.result.input_read;
                try validateZlibFooterPartialWithOptions(input, footer_offset, stored.digest, options);
                out_offset += stored.result.output_written;
                offset = footer_offset + 4;
                continue;
            }
        }

        const before_member = out_offset;
        const raw = try decodeRawAutoWithDictionary(raw_input, raw_dictionary, output[out_offset..]);
        out_offset += raw.output_written;
        const footer_offset = raw_offset + raw.input_read;
        const actual_adler = if (options.ignore_adler) 0 else checksum.adler32(output[before_member..out_offset]);
        try validateZlibFooterPartialWithOptions(input, footer_offset, actual_adler, options);
        offset = footer_offset + 4;
    }
    return out_offset;
}

pub fn decodeZlibConcatenatedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeZlibConcatenatedAllocLimitedInternal(allocator, input, null, .{}, null);
}

pub fn decodeZlibConcatenatedAllocWithDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8) ![]u8 {
    return decodeZlibConcatenatedAllocLimitedInternal(allocator, input, dictionary, .{}, null);
}

pub fn decodeZlibConcatenatedAllocWithOptions(allocator: std.mem.Allocator, input: []const u8, options: ZlibDecodeOptions) ![]u8 {
    return decodeZlibConcatenatedAllocLimitedInternal(allocator, input, null, options, null);
}

pub fn decodeZlibConcatenatedAllocWithDictionaryAndOptions(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: ZlibDecodeOptions) ![]u8 {
    return decodeZlibConcatenatedAllocLimitedInternal(allocator, input, dictionary, options, null);
}

pub fn decodeZlibConcatenatedAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    return decodeZlibConcatenatedAllocLimitedInternal(allocator, input, null, .{}, max_output_len);
}

pub fn decodeZlibConcatenatedAllocWithDictionaryLimited(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, max_output_len: usize) ![]u8 {
    return decodeZlibConcatenatedAllocLimitedInternal(allocator, input, dictionary, .{}, max_output_len);
}

pub fn decodeZlibConcatenatedAllocWithOptionsLimited(allocator: std.mem.Allocator, input: []const u8, options: ZlibDecodeOptions, max_output_len: usize) ![]u8 {
    return decodeZlibConcatenatedAllocLimitedInternal(allocator, input, null, options, max_output_len);
}

pub fn decodeZlibConcatenatedAllocWithDictionaryAndOptionsLimited(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: ZlibDecodeOptions, max_output_len: usize) ![]u8 {
    return decodeZlibConcatenatedAllocLimitedInternal(allocator, input, dictionary, options, max_output_len);
}

pub fn decodeZlibConcatenatedAllocExactSize(allocator: std.mem.Allocator, input: []const u8, expected_output_len: usize) ![]u8 {
    return decodeZlibConcatenatedAllocWithOptionalDictionaryAndOptionsExactSize(allocator, input, null, .{}, expected_output_len);
}

pub fn decodeZlibConcatenatedAllocWithDictionaryExactSize(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, expected_output_len: usize) ![]u8 {
    return decodeZlibConcatenatedAllocWithOptionalDictionaryAndOptionsExactSize(allocator, input, dictionary, .{}, expected_output_len);
}

pub fn decodeZlibConcatenatedAllocWithOptionsExactSize(allocator: std.mem.Allocator, input: []const u8, options: ZlibDecodeOptions, expected_output_len: usize) ![]u8 {
    return decodeZlibConcatenatedAllocWithOptionalDictionaryAndOptionsExactSize(allocator, input, null, options, expected_output_len);
}

pub fn decodeZlibConcatenatedAllocWithDictionaryAndOptionsExactSize(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: ZlibDecodeOptions, expected_output_len: usize) ![]u8 {
    return decodeZlibConcatenatedAllocWithOptionalDictionaryAndOptionsExactSize(allocator, input, dictionary, options, expected_output_len);
}

fn decodeZlibConcatenatedAllocWithOptionalDictionaryAndOptionsExactSize(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, options: ZlibDecodeOptions, expected_output_len: usize) ![]u8 {
    if (input.len == 0) return error.TruncatedFrame;
    const header = try parseZlibHeader(input, dictionary);
    if (input.len == header.data_offset) return error.TruncatedFrame;
    try rejectReservedFirstBlockBeforeAlloc(input[header.data_offset..]);
    if (try precheckZlibConcatenatedStoredExact(input, dictionary, options)) |stored_output_len| {
        if (stored_output_len != expected_output_len) return error.SizeMismatch;
    }
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeZlibConcatenatedWithOptionalDictionaryAndOptions(input, out, dictionary, options) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

fn precheckZlibConcatenatedStoredExact(input: []const u8, dictionary: ?[]const u8, options: ZlibDecodeOptions) !?usize {
    var offset: usize = 0;
    var output_len: usize = 0;
    while (offset < input.len) {
        const header = parseZlibHeader(input[offset..], dictionary) catch |err| {
            if (options.allow_trailing_data and offset != 0) break;
            return err;
        };
        const raw_offset = offset + header.data_offset;
        const raw_input = input[raw_offset..];
        if (raw_input.len == 0 or !isStoredBlockHeaderByte(raw_input[0])) return null;
        const stored_plan = (try planRawStoredOnly(raw_input)) orelse return null;
        try validateZlibStoredMemberBeforeAlloc(input, raw_offset, stored_plan, options);
        output_len = std.math.add(usize, output_len, stored_plan.output_len) catch return error.IntegerOverflow;
        offset = raw_offset + stored_plan.input_read + 4;
    }
    return output_len;
}

fn validateZlibStoredMemberBeforeAlloc(input: []const u8, raw_offset: usize, plan: StoredOnlyPlan, options: ZlibDecodeOptions) Error!void {
    const footer_offset = raw_offset + plan.input_read;
    const actual = if (options.ignore_adler) 0 else hashRawStoredOnlyPlanned(checksum.Adler32, input[raw_offset..], plan);
    try validateZlibFooterPartialWithOptions(input, footer_offset, actual, options);
}

fn decodeZlibAllocWithOptionalDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryLimited(allocator, input, dictionary, null);
}

fn decodeZlibChunksAllocWithOptionalDictionaryAndOptionsLimited(allocator: std.mem.Allocator, chunks: []const []const u8, dictionary: ?[]const u8, options: ZlibDecodeOptions, max_output_len: ?usize) ![]u8 {
    const compressed_len = try chunksTotalLen(chunks);
    const header = try parseZlibHeaderFromChunks(chunks, dictionary);
    const raw_dictionary = if (header.uses_dictionary) dictionary.? else "";
    const first_deflate_byte = chunkByteAt(chunks, header.data_offset) orelse return error.TruncatedFrame;
    try rejectReservedFirstBlockBeforeAlloc(&.{first_deflate_byte});
    if (try precheckZlibStoredChunksBeforeAlloc(chunks, compressed_len, header.data_offset, options)) |stored_output_len| {
        try ensureOutputLimit(0, stored_output_len, max_output_len);
    }

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try reserveInflateAppendOutputHint(allocator, &out, compressed_len, max_output_len);

    var reader = try bitstream.ChunkedSpanBitReader.initAtKnownTotal(chunks, header.data_offset, compressed_len);
    const raw = try decodeRawAutoAppendPartialWithDictionaryFromReader(allocator, &reader, header.data_offset, raw_dictionary, &out, max_output_len);
    const footer_offset = header.data_offset + raw.input_read;
    const actual_adler = if (options.ignore_adler) 0 else checksum.adler32(out.items);
    try validateZlibFooterChunksWithKnownTotal(chunks, compressed_len, footer_offset, actual_adler, options);
    return out.toOwnedSlice(allocator);
}

fn decodeZlibChunksAllocWithOptionalDictionaryAndOptionsExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, dictionary: ?[]const u8, options: ZlibDecodeOptions, expected_output_len: usize) ![]u8 {
    const total_len = try chunksTotalLen(chunks);
    const header = try parseZlibHeaderFromChunks(chunks, dictionary);
    const first_deflate_byte = chunkByteAt(chunks, header.data_offset) orelse return error.TruncatedFrame;
    try rejectReservedFirstBlockBeforeAlloc(&.{first_deflate_byte});
    if (try precheckZlibStoredChunksBeforeAlloc(chunks, total_len, header.data_offset, options)) |stored_output_len| {
        if (stored_output_len != expected_output_len) return error.SizeMismatch;
    }
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeZlibChunksWithOptionalDictionaryAndOptionsDirect(chunks, out, dictionary, options) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

fn precheckZlibStoredChunksBeforeAlloc(chunks: []const []const u8, total_len: usize, raw_offset: usize, options: ZlibDecodeOptions) Error!?usize {
    var cursor = try ChunkCursor.init(chunks, total_len, raw_offset);
    var output_len: usize = 0;
    var adler = checksum.Adler32.init();

    while (true) {
        const header = try cursor.readByte();
        if (!isStoredBlockHeaderByte(header)) return null;
        const final = (header & 0x01) != 0;

        const len = try cursor.readLittleU16();
        const nlen = try cursor.readLittleU16();
        if (nlen != ~len) return error.StoredLengthMismatch;
        const chunk_len: usize = len;
        output_len = std.math.add(usize, output_len, chunk_len) catch return error.IntegerOverflow;
        if (options.ignore_adler) {
            try cursor.skip(chunk_len);
        } else {
            try cursor.updateHash(checksum.Adler32, &adler, chunk_len);
        }

        if (final) {
            const expected = try cursor.readBigU32();
            if (!options.ignore_adler and adler.digest() != expected) return error.ChecksumMismatch;
            if (!options.allow_trailing_data and cursor.absolute != cursor.total_len) return error.TrailingData;
            return output_len;
        }
    }
}

fn decodeZlibAllocWithOptionalDictionaryLimited(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, max_output_len: ?usize) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryAndOptionsLimited(allocator, input, dictionary, .{}, max_output_len);
}

fn decodeZlibConcatenatedAllocLimitedInternal(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, options: ZlibDecodeOptions, max_output_len: ?usize) ![]u8 {
    if (input.len == 0) return error.TruncatedFrame;
    if (try precheckZlibConcatenatedStoredExact(input, dictionary, options)) |stored_output_len| {
        try ensureOutputLimit(0, stored_output_len, max_output_len);
    }

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var offset: usize = 0;
    while (offset < input.len) {
        const header = parseZlibHeader(input[offset..], dictionary) catch |err| {
            if (options.allow_trailing_data and offset != 0) break;
            return err;
        };
        const raw_dictionary = if (header.uses_dictionary) dictionary.? else "";
        const raw_offset = offset + header.data_offset;
        const raw_input = input[raw_offset..];
        try rejectReservedFirstBlockBeforeAlloc(raw_input);

        if (raw_input.len != 0 and isStoredBlockHeaderByte(raw_input[0])) {
            if (try planRawStoredOnly(raw_input)) |plan| {
                const digest = if (options.ignore_adler) blk: {
                    try appendRawStoredOnlyPlanned(allocator, raw_input[0..plan.input_read], &out, plan, max_output_len);
                    break :blk @as(u32, 0);
                } else try appendRawStoredOnlyPlannedWithHash(checksum.Adler32, allocator, raw_input[0..plan.input_read], &out, plan, max_output_len);
                const footer_offset = raw_offset + plan.input_read;
                try validateZlibFooterPartialWithOptions(input, footer_offset, digest, options);
                offset = footer_offset + 4;
                continue;
            }
        }

        const before_member = out.items.len;
        const raw = try decodeRawAutoAppendPartialWithDictionary(allocator, raw_input, raw_dictionary, &out, max_output_len);
        const footer_offset = raw_offset + raw.input_read;
        const actual_adler = if (options.ignore_adler) 0 else checksum.adler32(out.items[before_member..]);
        try validateZlibFooterPartialWithOptions(input, footer_offset, actual_adler, options);
        offset = footer_offset + 4;
    }
    return out.toOwnedSlice(allocator);
}

fn decodeZlibAllocWithOptionalDictionaryAndOptionsLimited(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, options: ZlibDecodeOptions, max_output_len: ?usize) ![]u8 {
    const header = try parseZlibHeader(input, dictionary);
    const raw_dictionary = if (header.uses_dictionary) dictionary.? else "";
    const raw_input = input[header.data_offset..];
    if (raw_input.len != 0 and isStoredBlockHeaderByte(raw_input[0])) {
        if (try planRawStoredOnly(raw_input)) |stored_plan| {
            try validateZlibStoredPlanBeforeAlloc(input, header.data_offset, stored_plan, options);
            return (try decodeRawStoredOnlyAllocPlanned(allocator, raw_input, stored_plan, max_output_len)).bytes;
        }
    }
    try rejectReservedFirstBlockBeforeAlloc(raw_input);

    if (options.ignore_adler) {
        if (try decodeRawStoredOnlyAllocMaybe(allocator, raw_input, max_output_len)) |stored| {
            errdefer stored.deinit(allocator);
            const footer_offset = header.data_offset + stored.input_read;
            try validateZlibFooterWithOptions(input, footer_offset, 0, options);
            return stored.bytes;
        }
    } else {
        if (try decodeRawStoredOnlyAllocMaybeWithHash(checksum.Adler32, allocator, raw_input, max_output_len)) |stored| {
            errdefer stored.deinit(allocator);
            const footer_offset = header.data_offset + stored.result.input_read;
            try validateZlibFooterWithOptions(input, footer_offset, stored.digest, options);
            return stored.result.bytes;
        }
    }

    if (try decodeZlibAllocSmallIntoMaybe(allocator, input, header, raw_dictionary, options, max_output_len)) |decoded| return decoded;

    const raw = try decodeRawAutoAllocPartialWithDictionary(allocator, raw_input, raw_dictionary, max_output_len);
    errdefer raw.deinit(allocator);
    const footer_offset = header.data_offset + raw.input_read;
    const actual_adler = if (options.ignore_adler) 0 else checksum.adler32(raw.bytes);
    try validateZlibFooterWithOptions(input, footer_offset, actual_adler, options);
    return raw.bytes;
}

fn validateZlibStoredPlanBeforeAlloc(input: []const u8, data_offset: usize, plan: StoredOnlyPlan, options: ZlibDecodeOptions) Error!void {
    const footer_offset = data_offset + plan.input_read;
    if (footer_offset > input.len or input.len - footer_offset < 4) return error.TruncatedFrame;
    if (!options.allow_trailing_data and footer_offset + 4 != input.len) return error.TrailingData;
    if (!options.ignore_adler) {
        const expected = std.mem.readInt(u32, input[footer_offset..][0..4], .big);
        const actual = hashRawStoredOnlyPlanned(checksum.Adler32, input[data_offset..], plan);
        if (actual != expected) return error.ChecksumMismatch;
    }
}

fn decodeZlibAllocSmallIntoMaybe(
    allocator: std.mem.Allocator,
    input: []const u8,
    header: ZlibHeader,
    raw_dictionary: []const u8,
    options: ZlibDecodeOptions,
    max_output_len: ?usize,
) !?[]u8 {
    if (input.len > stack_inflate_alloc_max_input_len) return null;

    // zlib does not carry the uncompressed byte length, so the general
    // allocator-returning path must discover it before returning an exact owned
    // slice. For common small/medium members, decode and validate directly into
    // bounded stack scratch, then copy exactly once into the caller-owned result.
    // This reuses the caller's already-parsed zlib header, avoids constructing
    // an intermediate raw owned slice, and avoids probing the stored-only raw
    // fast path a second time for non-stored frames.
    var scratch: [stack_inflate_alloc_scratch_len]u8 = undefined;
    const decode_buffer = if (max_output_len) |limit| scratch[0..@min(limit, scratch.len)] else scratch[0..];
    var reader = bitstream.BufferedBitReader.init(input[header.data_offset..]);
    const raw = decodeRawAutoWithDictionaryFromReader(&reader, 0, raw_dictionary, decode_buffer) catch |err| switch (err) {
        error.OutputTooSmall => return null,
        else => return err,
    };
    const written = raw.output_written;
    const footer_offset = header.data_offset + raw.input_read;
    const actual_adler = if (options.ignore_adler) 0 else checksum.adler32(scratch[0..written]);
    try validateZlibFooterWithOptions(input, footer_offset, actual_adler, options);

    const owned = try allocator.alloc(u8, written);
    errdefer allocator.free(owned);
    @memcpy(owned, scratch[0..written]);
    return owned;
}

fn decodeZlibAllocWithOptionalDictionaryExactSize(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, expected_output_len: usize) ![]u8 {
    return decodeZlibAllocWithOptionalDictionaryAndOptionsExactSize(allocator, input, dictionary, .{}, expected_output_len);
}

fn decodeZlibAllocWithOptionalDictionaryAndOptionsExactSize(allocator: std.mem.Allocator, input: []const u8, dictionary: ?[]const u8, options: ZlibDecodeOptions, expected_output_len: usize) ![]u8 {
    const header = try parseZlibHeader(input, dictionary);
    const raw_input = input[header.data_offset..];
    if (raw_input.len == 0) return error.TruncatedFrame;
    if (isStoredBlockHeaderByte(raw_input[0])) {
        if (try planRawStoredOnly(raw_input)) |stored_plan| {
            if (stored_plan.output_len != expected_output_len) return error.SizeMismatch;
            try validateZlibStoredPlanBeforeAlloc(input, header.data_offset, stored_plan, options);
            return (try decodeRawStoredOnlyAllocPlanned(allocator, raw_input, stored_plan, null)).bytes;
        }
    }
    try rejectReservedFirstBlockBeforeAlloc(raw_input);
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeZlibWithOptionalDictionaryAndOptions(input, out, dictionary, options) catch |err| switch (err) {
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
    const encoded = try encodeGzipBestTokensWithHeaderAlloc(allocator, input, plan.tokens, options, header_options);
    errdefer allocator.free(encoded);
    for (bestFallbackCandidates(options).slice()) |fallback_options| {
        const fallback = try encodeGzipBestWithHeaderAlloc(allocator, input, fallback_options, header_options);
        errdefer allocator.free(fallback);
        if (fallback.len < encoded.len) {
            allocator.free(encoded);
            return fallback;
        }
        allocator.free(fallback);
    }
    return encoded;
}

pub fn encodeGzipLevelAlloc(allocator: std.mem.Allocator, input: []const u8, level: u4) ![]u8 {
    return encodeGzipLevelWithHeaderAlloc(allocator, input, level, .{});
}

pub fn encodeGzipLevelWithHeaderAlloc(allocator: std.mem.Allocator, input: []const u8, level: u4, header_options: GzipHeaderOptions) ![]u8 {
    if (level == 0) return encodeGzipStoredWithHeaderAlloc(allocator, input, header_options);
    return encodeGzipBestWithHeaderAlloc(allocator, input, try optionsForZlibLevel(level), header_options);
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
    try validateGzipFooterPartialWithOptions(input, footer_offset, actual_crc, output_len, .{});
}

fn validateGzipFooterPartialWithOptions(input: []const u8, footer_offset: usize, actual_crc: u32, output_len: usize, options: GzipDecodeOptions) Error!void {
    if (footer_offset > input.len or input.len - footer_offset < 8) return error.TruncatedFrame;
    if (!options.ignore_crc32) {
        const expected_crc = std.mem.readInt(u32, input[footer_offset..][0..4], .little);
        if (actual_crc != expected_crc) return error.ChecksumMismatch;
    }
    if (!options.ignore_isize) {
        const expected_size = std.mem.readInt(u32, input[footer_offset + 4 ..][0..4], .little);
        if (@as(u32, @truncate(output_len)) != expected_size) return error.SizeMismatch;
    }
}

fn validateGzipFooter(input: []const u8, footer_offset: usize, actual_crc: u32, output_len: usize) Error!void {
    try validateGzipFooterWithOptions(input, footer_offset, actual_crc, output_len, .{});
}

fn validateGzipFooterWithOptions(input: []const u8, footer_offset: usize, actual_crc: u32, output_len: usize, options: GzipDecodeOptions) Error!void {
    try validateGzipFooterPartialWithOptions(input, footer_offset, actual_crc, output_len, options);
    if (!options.allow_trailing_data and footer_offset + 8 != input.len) return error.TrailingData;
}

pub fn inspectGzipMemberAlloc(allocator: std.mem.Allocator, input: []const u8, member_index: usize) !GzipMemberInfo {
    return inspectGzipMemberAllocLimited(allocator, input, member_index, 128 * 1024 * 1024);
}

pub fn inspectGzipMemberAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    member_index: usize,
    max_output_len: usize,
) !GzipMemberInfo {
    var offset: usize = 0;
    var index: usize = 0;
    while (offset < input.len) : (index += 1) {
        const header = try parseGzipHeaderInfo(input[offset..]);
        const deflate_offset = offset + header.data_offset;
        const raw = try decodeRawAutoAllocPartialWithDictionary(allocator, input[deflate_offset..], "", max_output_len);
        defer raw.deinit(allocator);
        const footer_offset = deflate_offset + raw.input_read;
        if (input.len - footer_offset < 8) return error.TruncatedFrame;
        const end_offset = footer_offset + 8;
        if (index == member_index) {
            const footer_crc32 = std.mem.readInt(u32, input[footer_offset..][0..4], .little);
            const footer_isize = std.mem.readInt(u32, input[footer_offset + 4 ..][0..4], .little);
            const actual_crc32 = checksum.crc32Best(raw.bytes);
            const actual_isize: u32 = @truncate(raw.bytes.len);
            const info: GzipMemberInfo = .{
                .member_index = index,
                .member_offset = offset,
                .header = header,
                .deflate_offset = deflate_offset,
                .deflate_bytes = raw.input_read,
                .output_bytes = raw.bytes.len,
                .footer_offset = footer_offset,
                .end_offset = end_offset,
                .footer_crc32 = footer_crc32,
                .crc32 = actual_crc32,
                .crc32_matches = footer_crc32 == actual_crc32,
                .footer_isize = footer_isize,
                .isize = actual_isize,
                .isize_matches = footer_isize == actual_isize,
            };
            return info;
        }
        offset = end_offset;
    }
    return error.RangeOutOfBounds;
}

pub fn inspectGzipMemberFromChunksAlloc(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, member_index: usize) !GzipMemberInfo {
    return inspectGzipMemberFromChunksAllocLimited(allocator, chunks, compressed_scratch, member_index, 128 * 1024 * 1024);
}

pub fn inspectGzipMemberFromChunksAllocLimited(
    allocator: std.mem.Allocator,
    chunks: []const []const u8,
    compressed_scratch: []u8,
    member_index: usize,
    max_output_len: usize,
) !GzipMemberInfo {
    const joined = try joinChunks(chunks, compressed_scratch);
    return inspectGzipMemberAllocLimited(allocator, joined, member_index, max_output_len);
}

pub fn decodeGzipStored(input: []const u8, output: []u8) Error!usize {
    const data_offset = try parseGzipHeader(input);
    const stored = (try decodeRawStoredOnlyIntoMaybeWithHash(checksum.Crc32Slice32, input[data_offset..], output)) orelse return error.InvalidDeflateBlockType;
    const footer_offset = data_offset + stored.result.input_read;
    try validateGzipFooter(input, footer_offset, stored.digest, stored.result.output_written);
    return stored.result.output_written;
}

pub fn decodeGzip(input: []const u8, output: []u8) Error!usize {
    return decodeGzipWithOptions(input, output, .{});
}

pub fn decodeGzipWithOptions(input: []const u8, output: []u8, options: GzipDecodeOptions) Error!usize {
    const data_offset = try parseGzipHeader(input);

    if (options.ignore_crc32) {
        if (try decodeRawStoredOnlyIntoMaybe(input[data_offset..], output)) |stored| {
            const footer_offset = data_offset + stored.input_read;
            try validateGzipFooterWithOptions(input, footer_offset, 0, stored.output_written, options);
            return stored.output_written;
        }
    } else {
        if (try decodeRawStoredOnlyIntoMaybeWithHash(checksum.Crc32Slice32, input[data_offset..], output)) |stored| {
            const footer_offset = data_offset + stored.result.input_read;
            try validateGzipFooterWithOptions(input, footer_offset, stored.digest, stored.result.output_written, options);
            return stored.result.output_written;
        }
    }

    var reader = bitstream.BufferedBitReader.init(input[data_offset..]);
    const raw = try decodeRawAutoWithDictionaryFromReader(&reader, 0, "", output);
    const footer_offset = data_offset + raw.input_read;
    const payload = output[0..raw.output_written];
    const actual_crc = if (options.ignore_crc32) 0 else checksum.crc32Best(payload);
    try validateGzipFooterWithOptions(input, footer_offset, actual_crc, raw.output_written, options);
    return raw.output_written;
}

pub fn decodeGzipChunks(chunks: []const []const u8, compressed_scratch: []u8, output: []u8) Error!usize {
    return decodeGzipChunksWithOptions(chunks, compressed_scratch, output, .{});
}

pub fn decodeGzipChunksWithOptions(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, options: GzipDecodeOptions) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return decodeGzipWithOptions(joined, output, options);
}

pub fn decodeGzipChunksAlloc(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8) ![]u8 {
    return decodeGzipChunksAllocWithOptionsLimitedInternal(allocator, chunks, compressed_scratch, .{}, null);
}

pub fn decodeGzipChunksAllocWithOptions(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, options: GzipDecodeOptions) ![]u8 {
    return decodeGzipChunksAllocWithOptionsLimitedInternal(allocator, chunks, compressed_scratch, options, null);
}

pub fn decodeGzipChunksAllocExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) ![]u8 {
    return decodeGzipChunksAllocWithOptionsExactSize(allocator, chunks, compressed_scratch, .{}, expected_output_len);
}

pub fn decodeGzipChunksAllocWithOptionsExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, options: GzipDecodeOptions, expected_output_len: usize) ![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return decodeGzipAllocWithOptionsExactSize(allocator, joined, options, expected_output_len);
}

pub fn decodeGzipChunksAllocLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) ![]u8 {
    return decodeGzipChunksAllocWithOptionsLimitedInternal(allocator, chunks, compressed_scratch, .{}, max_output_len);
}

pub fn decodeGzipChunksAllocWithOptionsLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, options: GzipDecodeOptions, max_output_len: usize) ![]u8 {
    return decodeGzipChunksAllocWithOptionsLimitedInternal(allocator, chunks, compressed_scratch, options, max_output_len);
}

fn decodeGzipChunksAllocWithOptionsLimitedInternal(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, options: GzipDecodeOptions, max_output_len: ?usize) ![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return decodeGzipAllocWithOptionsLimitedInternal(allocator, joined, options, max_output_len);
}

/// Bounded-output gzip wrapper decoder.
///
/// This mirrors `ZlibDecoder` for gzip members: callers provide all compressed
/// input up front, the decoder validates the gzip header/footer and DEFLATE
/// payload into caller-owned decoded scratch, and `step` drains that scratch in
/// bounded output chunks. Chunked initializers only concatenate gzip bytes into
/// caller scratch before validation; they do not represent true incremental
/// parsing yet.
pub const GzipDecoder = struct {
    decoded: []const u8 = &.{},
    frame_len: usize = 0,
    offset: usize = 0,
    done: bool = false,
    last_error_name: []const u8 = "",
    last_recoverability_hint: RecoverabilityHint = .none,

    pub const RecoverabilityHint = enum {
        none,
        corrupt_header,
        truncated_input,
        payload_corrupt,
    };

    pub const Snapshot = struct {
        output_written: usize,
        expected_output_len: usize,
        payload_remaining: usize,
        done: bool,
        last_error_name: []const u8,
        recoverability_hint: RecoverabilityHint,
    };

    pub fn init(input: []const u8, scratch: []u8) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.reset(input, scratch);
        return self;
    }

    pub fn initExactSize(input: []const u8, scratch: []u8, expected_output_len: usize) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.resetExactSize(input, scratch, expected_output_len);
        return self;
    }

    pub fn initWithOptions(input: []const u8, scratch: []u8, options: GzipDecodeOptions) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.resetWithOptions(input, scratch, options);
        return self;
    }

    pub fn initWithOptionsExactSize(input: []const u8, scratch: []u8, options: GzipDecodeOptions, expected_output_len: usize) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.resetWithOptionsExactSize(input, scratch, options, expected_output_len);
        return self;
    }

    pub fn initFromChunks(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.resetFromChunks(chunks, compressed_scratch, output_scratch);
        return self;
    }

    pub fn initFromChunksExactSize(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, expected_output_len: usize) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.resetFromChunksExactSize(chunks, compressed_scratch, output_scratch, expected_output_len);
        return self;
    }

    pub fn initFromChunksWithOptions(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: GzipDecodeOptions) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.resetFromChunksWithOptions(chunks, compressed_scratch, output_scratch, options);
        return self;
    }

    pub fn initFromChunksWithOptionsExactSize(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: GzipDecodeOptions, expected_output_len: usize) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.resetFromChunksWithOptionsExactSize(chunks, compressed_scratch, output_scratch, options, expected_output_len);
        return self;
    }

    pub fn initConcatenated(input: []const u8, scratch: []u8) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.resetConcatenated(input, scratch);
        return self;
    }

    pub fn initConcatenatedExactSize(input: []const u8, scratch: []u8, expected_output_len: usize) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.resetConcatenatedExactSize(input, scratch, expected_output_len);
        return self;
    }

    pub fn initConcatenatedWithOptions(input: []const u8, scratch: []u8, options: GzipDecodeOptions) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.resetConcatenatedWithOptions(input, scratch, options);
        return self;
    }

    pub fn initConcatenatedWithOptionsExactSize(input: []const u8, scratch: []u8, options: GzipDecodeOptions, expected_output_len: usize) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.resetConcatenatedWithOptionsExactSize(input, scratch, options, expected_output_len);
        return self;
    }

    pub fn initConcatenatedFromChunks(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.resetConcatenatedFromChunks(chunks, compressed_scratch, output_scratch);
        return self;
    }

    pub fn initConcatenatedFromChunksExactSize(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, expected_output_len: usize) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.resetConcatenatedFromChunksExactSize(chunks, compressed_scratch, output_scratch, expected_output_len);
        return self;
    }

    pub fn initConcatenatedFromChunksWithOptions(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: GzipDecodeOptions) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.resetConcatenatedFromChunksWithOptions(chunks, compressed_scratch, output_scratch, options);
        return self;
    }

    pub fn initConcatenatedFromChunksWithOptionsExactSize(chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: GzipDecodeOptions, expected_output_len: usize) Error!GzipDecoder {
        var self = GzipDecoder{};
        try self.resetConcatenatedFromChunksWithOptionsExactSize(chunks, compressed_scratch, output_scratch, options, expected_output_len);
        return self;
    }

    pub fn reset(self: *GzipDecoder, input: []const u8, scratch: []u8) Error!void {
        return self.resetWithOptions(input, scratch, .{});
    }

    pub fn resetWithOptions(self: *GzipDecoder, input: []const u8, scratch: []u8, options: GzipDecodeOptions) Error!void {
        const written = decodeGzipWithOptions(input, scratch, options) catch |err| {
            self.recordError(err);
            return err;
        };
        self.installDecoded(input.len, scratch, written);
    }

    pub fn resetExactSize(self: *GzipDecoder, input: []const u8, scratch: []u8, expected_output_len: usize) Error!void {
        return self.resetWithOptionsExactSize(input, scratch, .{}, expected_output_len);
    }

    pub fn resetWithOptionsExactSize(self: *GzipDecoder, input: []const u8, scratch: []u8, options: GzipDecodeOptions, expected_output_len: usize) Error!void {
        try self.resetWithOptions(input, scratch, options);
        if (self.decoded.len != expected_output_len) {
            self.recordError(error.SizeMismatch);
            return error.SizeMismatch;
        }
    }

    pub fn resetFromChunks(self: *GzipDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8) Error!void {
        return self.resetFromChunksWithOptions(chunks, compressed_scratch, output_scratch, .{});
    }

    pub fn resetFromChunksWithOptions(self: *GzipDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: GzipDecodeOptions) Error!void {
        const joined = try joinChunks(chunks, compressed_scratch);
        return self.resetWithOptions(joined, output_scratch, options);
    }

    pub fn resetFromChunksExactSize(self: *GzipDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, expected_output_len: usize) Error!void {
        return self.resetFromChunksWithOptionsExactSize(chunks, compressed_scratch, output_scratch, .{}, expected_output_len);
    }

    pub fn resetFromChunksWithOptionsExactSize(self: *GzipDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: GzipDecodeOptions, expected_output_len: usize) Error!void {
        const joined = try joinChunks(chunks, compressed_scratch);
        return self.resetWithOptionsExactSize(joined, output_scratch, options, expected_output_len);
    }

    pub fn resetConcatenated(self: *GzipDecoder, input: []const u8, scratch: []u8) Error!void {
        return self.resetConcatenatedWithOptions(input, scratch, .{});
    }

    pub fn resetConcatenatedWithOptions(self: *GzipDecoder, input: []const u8, scratch: []u8, options: GzipDecodeOptions) Error!void {
        const written = decodeGzipConcatenatedWithOptions(input, scratch, options) catch |err| {
            self.recordError(err);
            return err;
        };
        self.installDecoded(input.len, scratch, written);
    }

    pub fn resetConcatenatedExactSize(self: *GzipDecoder, input: []const u8, scratch: []u8, expected_output_len: usize) Error!void {
        return self.resetConcatenatedWithOptionsExactSize(input, scratch, .{}, expected_output_len);
    }

    pub fn resetConcatenatedWithOptionsExactSize(self: *GzipDecoder, input: []const u8, scratch: []u8, options: GzipDecodeOptions, expected_output_len: usize) Error!void {
        try self.resetConcatenatedWithOptions(input, scratch, options);
        if (self.decoded.len != expected_output_len) {
            self.recordError(error.SizeMismatch);
            return error.SizeMismatch;
        }
    }

    pub fn resetConcatenatedFromChunks(self: *GzipDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8) Error!void {
        return self.resetConcatenatedFromChunksWithOptions(chunks, compressed_scratch, output_scratch, .{});
    }

    pub fn resetConcatenatedFromChunksWithOptions(self: *GzipDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: GzipDecodeOptions) Error!void {
        const joined = try joinChunks(chunks, compressed_scratch);
        return self.resetConcatenatedWithOptions(joined, output_scratch, options);
    }

    pub fn resetConcatenatedFromChunksExactSize(self: *GzipDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, expected_output_len: usize) Error!void {
        return self.resetConcatenatedFromChunksWithOptionsExactSize(chunks, compressed_scratch, output_scratch, .{}, expected_output_len);
    }

    pub fn resetConcatenatedFromChunksWithOptionsExactSize(self: *GzipDecoder, chunks: []const []const u8, compressed_scratch: []u8, output_scratch: []u8, options: GzipDecodeOptions, expected_output_len: usize) Error!void {
        const joined = try joinChunks(chunks, compressed_scratch);
        return self.resetConcatenatedWithOptionsExactSize(joined, output_scratch, options, expected_output_len);
    }

    fn installDecoded(self: *GzipDecoder, frame_len: usize, scratch: []u8, written: usize) void {
        self.* = .{
            .decoded = scratch[0..written],
            .frame_len = frame_len,
        };
    }

    pub fn snapshot(self: *const GzipDecoder) Snapshot {
        return .{
            .output_written = self.offset,
            .expected_output_len = self.decoded.len,
            .payload_remaining = self.decoded.len - self.offset,
            .done = self.done,
            .last_error_name = self.last_error_name,
            .recoverability_hint = self.last_recoverability_hint,
        };
    }

    fn recordError(self: *GzipDecoder, err: Error) void {
        self.last_error_name = @errorName(err);
        self.last_recoverability_hint = switch (err) {
            error.BadGzipHeader, error.InvalidDeflateBlockType, error.InvalidDynamicBlockHeader, error.InvalidHuffmanCode => .corrupt_header,
            error.TruncatedFrame => .truncated_input,
            else => .payload_corrupt,
        };
    }

    fn hintName(hint: RecoverabilityHint) []const u8 {
        return switch (hint) {
            .none => "none",
            .corrupt_header => "corrupt_header",
            .truncated_input => "truncated_input",
            .payload_corrupt => "payload_corrupt",
        };
    }

    pub fn diagnostics(self: *const GzipDecoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = if (snap.done) "done" else "payload",
            .frame_input_read = if (snap.done) self.frame_len else null,
            .output_written = snap.output_written,
            .expected_output_len = snap.expected_output_len,
            .payload_remaining = snap.payload_remaining,
            .last_error_name = snap.last_error_name,
            .last_error_phase_name = if (snap.last_error_name.len == 0) "" else "payload",
            .recoverability_hint_name = hintName(snap.recoverability_hint),
        };
    }

    pub fn step(self: *GzipDecoder, output: []u8) Error!core.StepResult {
        if (self.done) return .{ .status = .done };
        if (output.len == 0) return .{ .status = .need_output };
        const remaining = self.decoded[self.offset..];
        const n = @min(output.len, remaining.len);
        @memcpy(output[0..n], remaining[0..n]);
        self.offset += n;
        if (self.offset == self.decoded.len) self.done = true;
        return .{
            .progress = .{ .input_read = if (self.done) self.frame_len else 0, .output_written = n },
            .status = if (self.done) .done else .need_output,
        };
    }
};

pub fn decodeGzipStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeGzipStoredAllocLimitedInternal(allocator, input, null);
}

pub fn decodeGzipStoredAllocExactSize(allocator: std.mem.Allocator, input: []const u8, expected_output_len: usize) ![]u8 {
    const data_offset = try parseGzipHeader(input);
    const raw_input = input[data_offset..];
    const stored_plan = (try planRawStoredOnly(raw_input)) orelse return error.InvalidDeflateBlockType;
    if (stored_plan.output_len != expected_output_len) return error.SizeMismatch;
    try validateGzipStoredPlanBeforeAlloc(input, data_offset, stored_plan, .{});
    return (try decodeRawStoredOnlyAllocPlanned(allocator, raw_input, stored_plan, null)).bytes;
}

pub fn decodeGzipStoredAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    return decodeGzipStoredAllocLimitedInternal(allocator, input, max_output_len);
}

fn decodeGzipStoredAllocLimitedInternal(allocator: std.mem.Allocator, input: []const u8, max_output_len: ?usize) ![]u8 {
    const data_offset = try parseGzipHeader(input);
    const raw_input = input[data_offset..];
    const stored_plan = (try planRawStoredOnly(raw_input)) orelse return error.InvalidDeflateBlockType;
    try validateGzipStoredPlanBeforeAlloc(input, data_offset, stored_plan, .{});
    if (try decodeGzipStoredAllocFooterSizeMaybe(allocator, input, data_offset, stored_plan, max_output_len)) |decoded| return decoded;
    const stored = try decodeRawStoredOnlyAllocPlanned(allocator, raw_input, stored_plan, max_output_len);
    errdefer stored.deinit(allocator);
    return stored.bytes;
}

fn decodeGzipStoredAllocFooterSizeMaybe(allocator: std.mem.Allocator, input: []const u8, data_offset: usize, plan: StoredOnlyPlan, max_output_len: ?usize) !?[]u8 {
    if (input.len < data_offset + 8) return null;
    const expected_size: usize = std.mem.readInt(u32, input[input.len - 4 ..][0..4], .little);
    // The gzip trailer carries ISIZE modulo 2^32. The caller has already used
    // the stored-block plan to validate boundaries, CRC-32, and ISIZE before
    // any heap allocation. Use the trailer only when it is the exact size for
    // this ordinary (<4 GiB) member; larger valid members fall back to the
    // planned allocator path, which uses the full usize output length.
    if (expected_size != plan.output_len) return null;
    try ensureOutputLimit(0, expected_size, max_output_len);

    const out = try allocator.alloc(u8, expected_size);
    errdefer allocator.free(out);
    copyRawStoredOnly(input[data_offset..][0..plan.input_read], out);
    return out;
}

pub fn decodeGzipConcatenatedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeGzipConcatenatedAllocWithOptionsLimitedInternal(allocator, input, .{}, null);
}

pub fn decodeGzipConcatenatedAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    return decodeGzipConcatenatedAllocWithOptionsLimitedInternal(allocator, input, .{}, max_output_len);
}

pub fn decodeGzipConcatenatedAllocWithOptions(allocator: std.mem.Allocator, input: []const u8, options: GzipDecodeOptions) ![]u8 {
    return decodeGzipConcatenatedAllocWithOptionsLimitedInternal(allocator, input, options, null);
}

pub fn decodeGzipConcatenatedAllocWithOptionsLimited(allocator: std.mem.Allocator, input: []const u8, options: GzipDecodeOptions, max_output_len: usize) ![]u8 {
    return decodeGzipConcatenatedAllocWithOptionsLimitedInternal(allocator, input, options, max_output_len);
}

pub fn decodeGzipConcatenatedAllocExactSize(allocator: std.mem.Allocator, input: []const u8, expected_output_len: usize) ![]u8 {
    return decodeGzipConcatenatedAllocWithOptionsExactSize(allocator, input, .{}, expected_output_len);
}

pub fn decodeGzipConcatenatedAllocWithOptionsExactSize(allocator: std.mem.Allocator, input: []const u8, options: GzipDecodeOptions, expected_output_len: usize) ![]u8 {
    if (input.len == 0) return error.TruncatedFrame;
    const data_offset = try parseGzipHeader(input);
    if (input.len == data_offset) return error.TruncatedFrame;
    try rejectReservedFirstBlockBeforeAlloc(input[data_offset..]);
    if (try precheckGzipConcatenatedStoredExact(input, options)) |stored_output_len| {
        if (stored_output_len != expected_output_len) return error.SizeMismatch;
    }
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeGzipConcatenatedWithOptions(input, out, options) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

fn precheckGzipConcatenatedStoredExact(input: []const u8, options: GzipDecodeOptions) !?usize {
    var offset: usize = 0;
    var output_len: usize = 0;
    while (offset < input.len) {
        const data_offset = parseGzipHeader(input[offset..]) catch |err| {
            if (options.allow_trailing_data and offset != 0) break;
            return err;
        };
        const raw_offset = offset + data_offset;
        const raw_input = input[raw_offset..];
        if (raw_input.len == 0 or !isStoredBlockHeaderByte(raw_input[0])) return null;
        const stored_plan = (try planRawStoredOnly(raw_input)) orelse return null;
        try validateGzipStoredMemberBeforeAlloc(input, raw_offset, stored_plan, options);
        output_len = std.math.add(usize, output_len, stored_plan.output_len) catch return error.IntegerOverflow;
        offset = raw_offset + stored_plan.input_read + 8;
    }
    return output_len;
}

fn validateGzipStoredMemberBeforeAlloc(input: []const u8, raw_offset: usize, plan: StoredOnlyPlan, options: GzipDecodeOptions) Error!void {
    const footer_offset = raw_offset + plan.input_read;
    const actual_crc = if (options.ignore_crc32) 0 else hashRawStoredOnlyPlanned(checksum.Crc32Slice32, input[raw_offset..], plan);
    try validateGzipFooterPartialWithOptions(input, footer_offset, actual_crc, plan.output_len, options);
}

pub fn decodeGzipConcatenated(input: []const u8, output: []u8) Error!usize {
    return decodeGzipConcatenatedWithOptions(input, output, .{});
}

pub fn decodeGzipConcatenatedWithOptions(input: []const u8, output: []u8, options: GzipDecodeOptions) Error!usize {
    if (input.len == 0) return error.TruncatedFrame;

    var offset: usize = 0;
    var out_offset: usize = 0;
    while (offset < input.len) {
        const data_offset = parseGzipHeader(input[offset..]) catch |err| {
            if (options.allow_trailing_data and offset != 0) break;
            return err;
        };
        const raw_offset = offset + data_offset;

        if (options.ignore_crc32) {
            if (try decodeRawStoredOnlyIntoMaybe(input[raw_offset..], output[out_offset..])) |stored| {
                const footer_offset = raw_offset + stored.input_read;
                try validateGzipFooterPartialWithOptions(input, footer_offset, 0, stored.output_written, options);
                out_offset += stored.output_written;
                offset = footer_offset + 8;
                continue;
            }
        } else {
            if (try decodeRawStoredOnlyIntoMaybeWithHash(checksum.Crc32Slice32, input[raw_offset..], output[out_offset..])) |stored| {
                const footer_offset = raw_offset + stored.result.input_read;
                try validateGzipFooterPartialWithOptions(input, footer_offset, stored.digest, stored.result.output_written, options);
                out_offset += stored.result.output_written;
                offset = footer_offset + 8;
                continue;
            }
        }

        const before_member = out_offset;
        const raw = try decodeRawAuto(input[raw_offset..], output[out_offset..]);
        out_offset += raw.output_written;
        const footer_offset = raw_offset + raw.input_read;
        const member_payload = output[before_member..out_offset];
        const actual_crc = if (options.ignore_crc32) 0 else checksum.crc32Best(member_payload);
        try validateGzipFooterPartialWithOptions(input, footer_offset, actual_crc, member_payload.len, options);
        offset = footer_offset + 8;
    }
    return out_offset;
}

pub fn decodeGzipConcatenatedChunks(chunks: []const []const u8, compressed_scratch: []u8, output: []u8) Error!usize {
    return decodeGzipConcatenatedChunksWithOptions(chunks, compressed_scratch, output, .{});
}

pub fn decodeGzipConcatenatedChunksWithOptions(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, options: GzipDecodeOptions) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return decodeGzipConcatenatedWithOptions(joined, output, options);
}

pub fn decodeGzipConcatenatedChunksAlloc(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8) ![]u8 {
    return decodeGzipConcatenatedChunksAllocWithOptionsLimitedInternal(allocator, chunks, compressed_scratch, .{}, null);
}

pub fn decodeGzipConcatenatedChunksAllocWithOptions(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, options: GzipDecodeOptions) ![]u8 {
    return decodeGzipConcatenatedChunksAllocWithOptionsLimitedInternal(allocator, chunks, compressed_scratch, options, null);
}

pub fn decodeGzipConcatenatedChunksAllocExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) ![]u8 {
    return decodeGzipConcatenatedChunksAllocWithOptionsExactSize(allocator, chunks, compressed_scratch, .{}, expected_output_len);
}

pub fn decodeGzipConcatenatedChunksAllocWithOptionsExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, options: GzipDecodeOptions, expected_output_len: usize) ![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return decodeGzipConcatenatedAllocWithOptionsExactSize(allocator, joined, options, expected_output_len);
}

pub fn decodeGzipConcatenatedChunksAllocLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) ![]u8 {
    return decodeGzipConcatenatedChunksAllocWithOptionsLimitedInternal(allocator, chunks, compressed_scratch, .{}, max_output_len);
}

pub fn decodeGzipConcatenatedChunksAllocWithOptionsLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, options: GzipDecodeOptions, max_output_len: usize) ![]u8 {
    return decodeGzipConcatenatedChunksAllocWithOptionsLimitedInternal(allocator, chunks, compressed_scratch, options, max_output_len);
}

fn decodeGzipConcatenatedChunksAllocWithOptionsLimitedInternal(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, options: GzipDecodeOptions, max_output_len: ?usize) ![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return decodeGzipConcatenatedAllocWithOptionsLimitedInternal(allocator, joined, options, max_output_len);
}

fn decodeGzipConcatenatedAllocWithOptionsLimitedInternal(allocator: std.mem.Allocator, input: []const u8, options: GzipDecodeOptions, max_output_len: ?usize) ![]u8 {
    if (input.len == 0) return error.TruncatedFrame;
    if (try precheckGzipConcatenatedStoredExact(input, options)) |stored_output_len| {
        try ensureOutputLimit(0, stored_output_len, max_output_len);
    }

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var offset: usize = 0;
    while (offset < input.len) {
        const data_offset = parseGzipHeader(input[offset..]) catch |err| {
            if (options.allow_trailing_data and offset != 0) break;
            return err;
        };
        const raw_offset = offset + data_offset;
        const raw_input = input[raw_offset..];
        try rejectReservedFirstBlockBeforeAlloc(raw_input);
        if (try planRawStoredOnly(raw_input)) |plan| {
            const digest = if (options.ignore_crc32) blk: {
                try appendRawStoredOnlyPlanned(allocator, raw_input[0..plan.input_read], &out, plan, max_output_len);
                break :blk @as(u32, 0);
            } else try appendRawStoredOnlyPlannedWithHash(checksum.Crc32Slice32, allocator, raw_input[0..plan.input_read], &out, plan, max_output_len);
            const footer_offset = raw_offset + plan.input_read;
            try validateGzipFooterPartialWithOptions(input, footer_offset, digest, plan.output_len, options);
            offset = footer_offset + 8;
            continue;
        }

        const before_member = out.items.len;
        const raw = try decodeRawAutoAppendPartialWithDictionary(allocator, raw_input, "", &out, max_output_len);
        const footer_offset = raw_offset + raw.input_read;
        const member_payload = out.items[before_member..];
        const actual_crc = if (options.ignore_crc32) 0 else checksum.crc32Best(member_payload);
        try validateGzipFooterPartialWithOptions(input, footer_offset, actual_crc, member_payload.len, options);
        offset = footer_offset + 8;
    }
    return out.toOwnedSlice(allocator);
}

pub fn decodeGzipAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeGzipAllocWithOptionsLimitedInternal(allocator, input, .{}, null);
}

pub fn decodeGzipAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    return decodeGzipAllocWithOptionsLimitedInternal(allocator, input, .{}, max_output_len);
}

pub fn decodeGzipAllocWithOptions(allocator: std.mem.Allocator, input: []const u8, options: GzipDecodeOptions) ![]u8 {
    return decodeGzipAllocWithOptionsLimitedInternal(allocator, input, options, null);
}

pub fn decodeGzipAllocWithOptionsLimited(allocator: std.mem.Allocator, input: []const u8, options: GzipDecodeOptions, max_output_len: usize) ![]u8 {
    return decodeGzipAllocWithOptionsLimitedInternal(allocator, input, options, max_output_len);
}

pub fn decodeGzipAllocExactSize(allocator: std.mem.Allocator, input: []const u8, expected_output_len: usize) ![]u8 {
    return decodeGzipAllocWithOptionsExactSize(allocator, input, .{}, expected_output_len);
}

pub fn decodeGzipAllocWithOptionsExactSize(allocator: std.mem.Allocator, input: []const u8, options: GzipDecodeOptions, expected_output_len: usize) ![]u8 {
    const data_offset = try parseGzipHeader(input);
    const raw_input = input[data_offset..];
    if (raw_input.len == 0) return error.TruncatedFrame;
    if (isStoredBlockHeaderByte(raw_input[0])) {
        if (try planRawStoredOnly(raw_input)) |stored_plan| {
            if (stored_plan.output_len != expected_output_len) return error.SizeMismatch;
            try validateGzipStoredPlanBeforeAlloc(input, data_offset, stored_plan, options);
            return (try decodeRawStoredOnlyAllocPlanned(allocator, raw_input, stored_plan, null)).bytes;
        }
    }
    try rejectReservedFirstBlockBeforeAlloc(raw_input);
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeGzipWithOptions(input, out, options) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

fn decodeGzipAllocWithOptionsLimitedInternal(allocator: std.mem.Allocator, input: []const u8, options: GzipDecodeOptions, max_output_len: ?usize) ![]u8 {
    const data_offset = try parseGzipHeader(input);
    const raw_input = input[data_offset..];
    if (raw_input.len == 0) return error.TruncatedFrame;
    if (isStoredBlockHeaderByte(raw_input[0])) {
        if (try planRawStoredOnly(raw_input)) |stored_plan| {
            try validateGzipStoredPlanBeforeAlloc(input, data_offset, stored_plan, options);
            return (try decodeRawStoredOnlyAllocPlanned(allocator, raw_input, stored_plan, max_output_len)).bytes;
        }
    }
    try rejectReservedFirstBlockBeforeAlloc(raw_input);
    if (try decodeGzipAllocFooterSize(allocator, input, data_offset, options, max_output_len)) |decoded| return decoded;

    if (options.ignore_crc32) {
        if (try decodeRawStoredOnlyAllocMaybe(allocator, raw_input, max_output_len)) |stored| {
            errdefer stored.deinit(allocator);
            const footer_offset = data_offset + stored.input_read;
            try validateGzipFooterWithOptions(input, footer_offset, 0, stored.bytes.len, options);
            return stored.bytes;
        }
    } else {
        if (try decodeRawStoredOnlyAllocMaybeWithHash(checksum.Crc32Slice32, allocator, raw_input, max_output_len)) |stored| {
            errdefer stored.deinit(allocator);
            const footer_offset = data_offset + stored.result.input_read;
            try validateGzipFooterWithOptions(input, footer_offset, stored.digest, stored.result.bytes.len, options);
            return stored.result.bytes;
        }
    }

    const raw = try decodeRawAutoAllocPartialWithDictionary(allocator, raw_input, "", max_output_len);
    errdefer raw.deinit(allocator);
    const footer_offset = data_offset + raw.input_read;
    const actual_crc = if (options.ignore_crc32) 0 else checksum.crc32Best(raw.bytes);
    try validateGzipFooterWithOptions(input, footer_offset, actual_crc, raw.bytes.len, options);
    return raw.bytes;
}

fn validateGzipStoredPlanBeforeAlloc(input: []const u8, data_offset: usize, plan: StoredOnlyPlan, options: GzipDecodeOptions) Error!void {
    const footer_offset = data_offset + plan.input_read;
    if (footer_offset > input.len or input.len - footer_offset < 8) return error.TruncatedFrame;
    if (!options.allow_trailing_data and footer_offset + 8 != input.len) return error.TrailingData;
    if (!options.ignore_crc32) {
        const expected_crc = std.mem.readInt(u32, input[footer_offset..][0..4], .little);
        const actual_crc = hashRawStoredOnlyPlanned(checksum.Crc32Slice32, input[data_offset..], plan);
        if (actual_crc != expected_crc) return error.ChecksumMismatch;
    }
    if (!options.ignore_isize) {
        const expected_size = std.mem.readInt(u32, input[footer_offset + 4 ..][0..4], .little);
        if (@as(u32, @truncate(plan.output_len)) != expected_size) return error.SizeMismatch;
    }
}

fn decodeGzipAllocFooterSize(allocator: std.mem.Allocator, input: []const u8, data_offset: usize, options: GzipDecodeOptions, max_output_len: ?usize) !?[]u8 {
    if (input.len < data_offset + 8) return null;
    if (options.ignore_isize or options.allow_trailing_data) return null;
    const expected_size: usize = std.mem.readInt(u32, input[input.len - 4 ..][0..4], .little);
    try ensureOutputLimit(0, expected_size, max_output_len);
    const out = try allocator.alloc(u8, expected_size);
    errdefer allocator.free(out);
    const written = decodeGzipWithOptions(input, out, options) catch |err| switch (err) {
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

pub fn parseZlibHeaderInfo(input: []const u8) Error!ZlibHeaderInfo {
    if (input.len < 2) return error.TruncatedFrame;
    const cmf = input[0];
    const flg = input[1];
    if ((cmf & 0x0f) != 8) return error.BadZlibHeader;
    const cinfo = cmf >> 4;
    if (cinfo > 7) return error.BadZlibHeader;
    const combined: u16 = (@as(u16, cmf) << 8) | flg;
    if (combined % 31 != 0) return error.BadZlibHeader;

    const uses_dictionary = (flg & 0x20) != 0;
    var info = ZlibHeaderInfo{
        .data_offset = if (uses_dictionary) 6 else 2,
        .cmf = cmf,
        .flg = flg,
        .compression_method = cmf & 0x0f,
        .window_bits = cinfo + 8,
        .window_size = @as(usize, 1) << @intCast(cinfo + 8),
        .fcheck = flg & 0x1f,
        .uses_dictionary = uses_dictionary,
        .flevel = @intCast(flg >> 6),
    };

    if (!uses_dictionary) return info;

    if (input.len < 6) return error.TruncatedFrame;
    info.dictionary_id = std.mem.readInt(u32, input[2..][0..4], .big);
    return info;
}

pub fn parseZlibHeaderInfoFromChunks(chunks: []const []const u8, compressed_scratch: []u8) Error!ZlibHeaderInfo {
    const joined = try joinChunks(chunks, compressed_scratch);
    return parseZlibHeaderInfo(joined);
}

fn parseZlibHeader(input: []const u8, dictionary: ?[]const u8) Error!ZlibHeader {
    const info = try parseZlibHeaderInfo(input);
    if (!info.uses_dictionary) return .{ .data_offset = info.data_offset, .uses_dictionary = false };

    const actual_dictionary = dictionary orelse return error.NeedDictionary;
    if (checksum.adler32(actual_dictionary) != info.dictionary_id.?) return error.ChecksumMismatch;
    return .{ .data_offset = info.data_offset, .uses_dictionary = true };
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

pub fn parseGzipHeaderInfo(input: []const u8) Error!GzipHeaderInfo {
    if (input.len < 10) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..2], &.{ 0x1f, 0x8b })) return error.BadGzipHeader;
    if (input[2] != 8) return error.BadGzipHeader;
    const flags = input[3];
    if ((flags & 0xe0) != 0) return error.BadGzipHeader;

    var info = GzipHeaderInfo{
        .data_offset = 10,
        .flags = flags,
        .text = (flags & 0x01) != 0,
        .mtime = std.mem.readInt(u32, input[4..8], .little),
        .xfl = input[8],
        .os = input[9],
    };

    var offset: usize = info.data_offset;
    if ((flags & 0x04) != 0) {
        if (input.len - offset < 2) return error.TruncatedFrame;
        const xlen: usize = std.mem.readInt(u16, input[offset..][0..2], .little);
        offset += 2;
        if (input.len - offset < xlen) return error.TruncatedFrame;
        info.extra = input[offset..][0..xlen];
        offset += xlen;
    }
    if ((flags & 0x08) != 0) {
        const end = try gzipZeroTerminatedEnd(input, offset);
        info.filename = input[offset..end];
        offset = end + 1;
    }
    if ((flags & 0x10) != 0) {
        const end = try gzipZeroTerminatedEnd(input, offset);
        info.comment = input[offset..end];
        offset = end + 1;
    }
    if ((flags & 0x02) != 0) {
        if (input.len - offset < 2) return error.TruncatedFrame;
        const expected = std.mem.readInt(u16, input[offset..][0..2], .little);
        const actual: u16 = @truncate(checksum.crc32Best(input[0..offset]));
        if (actual != expected) return error.BadGzipHeader;
        info.header_crc = expected;
        offset += 2;
    }
    info.data_offset = offset;
    return info;
}

pub fn parseGzipHeaderInfoFromChunks(chunks: []const []const u8, compressed_scratch: []u8) Error!GzipHeaderInfo {
    const joined = try joinChunks(chunks, compressed_scratch);
    return parseGzipHeaderInfo(joined);
}

fn parseGzipHeader(input: []const u8) Error!usize {
    return (try parseGzipHeaderInfo(input)).data_offset;
}

fn gzipZeroTerminatedEnd(input: []const u8, offset: usize) Error!usize {
    var index = offset;
    while (index < input.len) : (index += 1) {
        if (input[index] == 0) return index;
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

test "raw deflate header parser exposes first block metadata" {
    const stored = try parseRawDeflateHeaderInfo(&.{ 0x01, 0x00, 0x00, 0xff, 0xff });
    try std.testing.expect(stored.final);
    try std.testing.expectEqual(RawDeflateBlockType.stored, stored.block_type);
    try std.testing.expectEqual(@as(usize, 3), stored.data_bit_offset);
    try std.testing.expectEqual(@as(usize, 1), stored.data_byte_offset);
    try std.testing.expectEqual(@as(usize, 40), stored.header_bits_consumed);
    try std.testing.expectEqual(@as(usize, 5), stored.header_bytes_consumed);
    try std.testing.expectEqual(@as(?u16, 0), stored.stored_len);
    try std.testing.expectEqual(@as(?u16, 0xffff), stored.stored_nlen);
    try std.testing.expectEqual(@as(?usize, 5), stored.stored_payload_offset);
    const stored_chunks = [_][]const u8{ &.{0x01}, &.{ 0x00, 0x00 }, &.{ 0xff, 0xff } };
    var compressed_scratch: [8]u8 = undefined;
    const stored_from_chunks = try parseRawDeflateHeaderInfoFromChunks(&stored_chunks, &compressed_scratch);
    try std.testing.expectEqual(stored.block_type, stored_from_chunks.block_type);
    try std.testing.expectEqual(stored.header_bits_consumed, stored_from_chunks.header_bits_consumed);
    try std.testing.expectEqual(stored.stored_len, stored_from_chunks.stored_len);
    try std.testing.expectError(error.OutputTooSmall, parseRawDeflateHeaderInfoFromChunks(&stored_chunks, compressed_scratch[0..4]));

    const fixed = try parseRawDeflateHeaderInfo(&.{ 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 });
    try std.testing.expect(fixed.final);
    try std.testing.expectEqual(RawDeflateBlockType.fixed, fixed.block_type);
    try std.testing.expectEqual(@as(usize, 3), fixed.header_bits_consumed);
    try std.testing.expectEqual(@as(usize, 1), fixed.header_bytes_consumed);
    try std.testing.expectEqual(@as(?u16, null), fixed.stored_len);

    const dynamic = try encodeRawDynamicLiteralAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(dynamic);
    const dynamic_info = try parseRawDeflateHeaderInfo(dynamic);
    try std.testing.expect(dynamic_info.final);
    try std.testing.expectEqual(RawDeflateBlockType.dynamic, dynamic_info.block_type);
    try std.testing.expect(dynamic_info.dynamic_hlit.? >= 257);
    try std.testing.expect(dynamic_info.dynamic_hdist.? >= 1);
    try std.testing.expect(dynamic_info.dynamic_hclen.? >= 4);
    try std.testing.expectEqual(dynamic_info.dynamic_hclen.?, dynamic_info.dynamic_code_length_count.?);
    try std.testing.expect(dynamic_info.dynamic_code_length_repeat_zero_long.? >= 1);
    try std.testing.expect(dynamic_info.dynamic_literal_nonzero.? >= 1);
    try std.testing.expectEqual(dynamic_info.dynamic_hlit.? - dynamic_info.dynamic_literal_nonzero.?, dynamic_info.dynamic_literal_zero.?);
    try std.testing.expect(dynamic_info.dynamic_literal_max_bits.? >= 1);
    var literal_hist_total: u16 = 0;
    for (dynamic_info.dynamic_literal_length_histogram) |count| literal_hist_total += count;
    try std.testing.expectEqual(dynamic_info.dynamic_hlit.?, literal_hist_total);
    try std.testing.expectEqual(@as(u16, 0), dynamic_info.dynamic_distance_nonzero.?);
    try std.testing.expectEqual(dynamic_info.dynamic_hdist.? - dynamic_info.dynamic_distance_nonzero.?, dynamic_info.dynamic_distance_zero.?);
    try std.testing.expectEqual(@as(u8, 0), dynamic_info.dynamic_distance_max_bits.?);
    var distance_hist_total: u16 = 0;
    for (dynamic_info.dynamic_distance_length_histogram) |count| distance_hist_total += count;
    try std.testing.expectEqual(dynamic_info.dynamic_hdist.?, distance_hist_total);
    try std.testing.expect(dynamic_info.dynamic_has_eob.?);
    try std.testing.expectEqual(dynamic_info.header_bits_consumed, dynamic_info.dynamic_lengths_bit_offset.?);
    try std.testing.expectEqual(dynamic_info.header_bytes_consumed, dynamic_info.dynamic_lengths_byte_offset.?);
    try std.testing.expect(dynamic_info.header_bits_consumed > 17 + @as(usize, dynamic_info.dynamic_hclen.?) * 3);

    try std.testing.expectError(error.TruncatedFrame, parseRawDeflateHeaderInfo(""));
    try std.testing.expectError(error.InvalidDeflateBlockType, parseRawDeflateHeaderInfo(&.{0x07}));
    try std.testing.expectError(error.TruncatedFrame, parseRawDeflateHeaderInfo(&.{0x01}));
    try std.testing.expectError(error.TruncatedFrame, parseRawDeflateHeaderInfo(&.{0x05}));
    try std.testing.expectError(error.StoredLengthMismatch, parseRawDeflateHeaderInfo(&.{ 0x01, 0x01, 0x00, 0xff, 0xff, 'x' }));
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

    const trailing = valid ++ .{0};
    var trailing_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TrailingData, decodeRawStoredAlloc(trailing_failing.allocator(), &trailing));
    try std.testing.expectEqual(@as(usize, 0), trailing_failing.allocations);
    var auto_trailing_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TrailingData, decodeRawAutoAlloc(auto_trailing_failing.allocator(), &trailing));
    try std.testing.expectEqual(@as(usize, 0), auto_trailing_failing.allocations);
}

test "raw deflate chunk helpers decode split input and dictionaries" {
    const input = "chunked raw deflate payload";
    const raw = try encodeRawBestAlloc(std.testing.allocator, input, optionsForLevel(.default));
    defer std.testing.allocator.free(raw);
    const chunks = [_][]const u8{
        raw[0..1],
        raw[1 .. raw.len - 2],
        raw[raw.len - 2 ..],
    };

    var compressed_scratch: [128]u8 = undefined;
    var output: [input.len]u8 = undefined;
    const decoded = try decodeRawChunks(&chunks, &compressed_scratch, &output);
    try std.testing.expectEqual(raw.len, decoded.input_read);
    try std.testing.expectEqual(input.len, decoded.output_written);
    try std.testing.expectEqualSlices(u8, input, &output);

    const alloc = try decodeRawChunksAlloc(std.testing.allocator, &chunks, &compressed_scratch);
    defer std.testing.allocator.free(alloc);
    try std.testing.expectEqualSlices(u8, input, alloc);
    const exact = try decodeRawChunksAllocExactSize(std.testing.allocator, &chunks, &compressed_scratch, input.len);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, input, exact);
    const limited = try decodeRawChunksAllocLimited(std.testing.allocator, &chunks, &compressed_scratch, input.len);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, input, limited);
    try std.testing.expectError(error.SizeMismatch, decodeRawChunksAllocExactSize(std.testing.allocator, &chunks, &compressed_scratch, input.len + 1));
    try std.testing.expectError(error.OutputLimitExceeded, decodeRawChunksAllocLimited(std.testing.allocator, &chunks, &compressed_scratch, input.len - 1));
    try std.testing.expectError(error.OutputTooSmall, decodeRawChunks(&chunks, compressed_scratch[0 .. raw.len - 1], &output));

    const dictionary = "chunked raw ";
    const dict_input = "chunked raw dictionary payload";
    const dict_raw = try encodeRawBestWithDictionaryAlloc(std.testing.allocator, dict_input, dictionary, optionsForLevel(.default));
    defer std.testing.allocator.free(dict_raw);
    const dict_chunks = [_][]const u8{
        dict_raw[0..1],
        dict_raw[1 .. dict_raw.len - 1],
        dict_raw[dict_raw.len - 1 ..],
    };
    var dict_output: [dict_input.len]u8 = undefined;
    const dict_decoded = try decodeRawChunksWithDictionary(&dict_chunks, &compressed_scratch, &dict_output, dictionary);
    try std.testing.expectEqual(dict_raw.len, dict_decoded.input_read);
    try std.testing.expectEqualSlices(u8, dict_input, &dict_output);
    const dict_alloc = try decodeRawChunksAllocWithDictionaryExactSize(std.testing.allocator, &dict_chunks, &compressed_scratch, dictionary, dict_input.len);
    defer std.testing.allocator.free(dict_alloc);
    try std.testing.expectEqualSlices(u8, dict_input, dict_alloc);
    try std.testing.expectError(error.OutputLimitExceeded, decodeRawChunksAllocWithDictionaryLimited(std.testing.allocator, &dict_chunks, &compressed_scratch, dictionary, dict_input.len - 1));
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
    var raw_limit_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutputLimitExceeded, decodeRawStoredAllocLimited(raw_limit_failing.allocator(), raw, 4));
    try std.testing.expectEqual(@as(usize, 0), raw_limit_failing.allocations);
    var raw_auto_limit_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutputLimitExceeded, decodeRawAutoAllocLimited(raw_auto_limit_failing.allocator(), raw, 4));
    try std.testing.expectEqual(@as(usize, 0), raw_auto_limit_failing.allocations);
    const raw_ok = try decodeRawStoredAllocLimited(std.testing.allocator, raw, 5);
    defer std.testing.allocator.free(raw_ok);
    try std.testing.expectEqualSlices(u8, "hello", raw_ok);

    const zlib_frame = try encodeZlibStoredAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(zlib_frame);
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibStoredAllocLimited(std.testing.allocator, zlib_frame, 4));
    var zlib_limit_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibStoredAllocLimited(zlib_limit_failing.allocator(), zlib_frame, 4));
    try std.testing.expectEqual(@as(usize, 0), zlib_limit_failing.allocations);
    const zlib_ok = try decodeZlibStoredAllocLimited(std.testing.allocator, zlib_frame, 5);
    defer std.testing.allocator.free(zlib_ok);
    try std.testing.expectEqualSlices(u8, "hello", zlib_ok);

    const gzip_frame = try encodeGzipStoredAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(gzip_frame);
    try std.testing.expectError(error.OutputLimitExceeded, decodeGzipStoredAllocLimited(std.testing.allocator, gzip_frame, 4));
    var gzip_limit_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutputLimitExceeded, decodeGzipStoredAllocLimited(gzip_limit_failing.allocator(), gzip_frame, 4));
    try std.testing.expectEqual(@as(usize, 0), gzip_limit_failing.allocations);
    const gzip_ok = try decodeGzipStoredAllocLimited(std.testing.allocator, gzip_frame, 5);
    defer std.testing.allocator.free(gzip_ok);
    try std.testing.expectEqualSlices(u8, "hello", gzip_ok);
}

test "stored deflate exact-size alloc decoders validate exact lengths" {
    const plain = "stored exact payload";

    const raw = try encodeRawStoredAlloc(std.testing.allocator, plain);
    defer std.testing.allocator.free(raw);
    const raw_exact = try decodeRawStoredAllocExactSize(std.testing.allocator, raw, plain.len);
    defer std.testing.allocator.free(raw_exact);
    try std.testing.expectEqualSlices(u8, plain, raw_exact);
    try std.testing.expectError(error.SizeMismatch, decodeRawStoredAllocExactSize(std.testing.allocator, raw, plain.len - 1));
    try std.testing.expectError(error.SizeMismatch, decodeRawStoredAllocExactSize(std.testing.allocator, raw, plain.len + 1));
    var raw_short_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.SizeMismatch, decodeRawStoredAllocExactSize(raw_short_failing.allocator(), raw, plain.len - 1));
    try std.testing.expectEqual(@as(usize, 0), raw_short_failing.allocations);
    var raw_long_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.SizeMismatch, decodeRawStoredAllocExactSize(raw_long_failing.allocator(), raw, plain.len + 1));
    try std.testing.expectEqual(@as(usize, 0), raw_long_failing.allocations);
    var raw_trailing = try std.testing.allocator.alloc(u8, raw.len + 1);
    defer std.testing.allocator.free(raw_trailing);
    @memcpy(raw_trailing[0..raw.len], raw);
    raw_trailing[raw.len] = 0;
    var raw_trailing_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TrailingData, decodeRawStoredAllocExactSize(raw_trailing_failing.allocator(), raw_trailing, plain.len));
    try std.testing.expectEqual(@as(usize, 0), raw_trailing_failing.allocations);
    var raw_auto_short_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.SizeMismatch, decodeRawAutoAllocExactSize(raw_auto_short_failing.allocator(), raw, plain.len - 1));
    try std.testing.expectEqual(@as(usize, 0), raw_auto_short_failing.allocations);
    var raw_auto_trailing_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TrailingData, decodeRawAutoAllocExactSize(raw_auto_trailing_failing.allocator(), raw_trailing, plain.len));
    try std.testing.expectEqual(@as(usize, 0), raw_auto_trailing_failing.allocations);
    var raw_empty_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TruncatedFrame, decodeRawAutoAllocExactSize(raw_empty_failing.allocator(), "", plain.len));
    try std.testing.expectEqual(@as(usize, 0), raw_empty_failing.allocations);
    var raw_empty_dict_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TruncatedFrame, decodeRawAutoAllocWithDictionaryExactSize(raw_empty_dict_failing.allocator(), "", "dict", plain.len));
    try std.testing.expectEqual(@as(usize, 0), raw_empty_dict_failing.allocations);
    var raw_reserved_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeRawAutoAllocExactSize(raw_reserved_failing.allocator(), &.{0x07}, plain.len));
    try std.testing.expectEqual(@as(usize, 0), raw_reserved_failing.allocations);
    var raw_reserved_dict_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeRawAutoAllocWithDictionaryExactSize(raw_reserved_dict_failing.allocator(), &.{0x07}, "dict", plain.len));
    try std.testing.expectEqual(@as(usize, 0), raw_reserved_dict_failing.allocations);

    const reserved_large = try std.testing.allocator.alloc(u8, stack_inflate_alloc_max_input_len + 1);
    defer std.testing.allocator.free(reserved_large);
    @memset(reserved_large, 0);
    reserved_large[0] = 0x07;
    var raw_reserved_large_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeRawAutoAlloc(raw_reserved_large_failing.allocator(), reserved_large));
    try std.testing.expectEqual(@as(usize, 0), raw_reserved_large_failing.allocations);
    var raw_reserved_large_dict_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeRawAutoAllocWithDictionary(raw_reserved_large_dict_failing.allocator(), reserved_large, "dict"));
    try std.testing.expectEqual(@as(usize, 0), raw_reserved_large_dict_failing.allocations);
    var raw_reserved_large_limit_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeRawAutoAllocLimited(raw_reserved_large_limit_failing.allocator(), reserved_large, plain.len));
    try std.testing.expectEqual(@as(usize, 0), raw_reserved_large_limit_failing.allocations);

    const zlib_frame = try encodeZlibStoredAlloc(std.testing.allocator, plain);
    defer std.testing.allocator.free(zlib_frame);
    const zlib_exact = try decodeZlibStoredAllocExactSize(std.testing.allocator, zlib_frame, plain.len);
    defer std.testing.allocator.free(zlib_exact);
    try std.testing.expectEqualSlices(u8, plain, zlib_exact);
    try std.testing.expectError(error.SizeMismatch, decodeZlibStoredAllocExactSize(std.testing.allocator, zlib_frame, plain.len - 1));
    try std.testing.expectError(error.SizeMismatch, decodeZlibStoredAllocExactSize(std.testing.allocator, zlib_frame, plain.len + 1));
    var zlib_short_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.SizeMismatch, decodeZlibStoredAllocExactSize(zlib_short_failing.allocator(), zlib_frame, plain.len - 1));
    try std.testing.expectEqual(@as(usize, 0), zlib_short_failing.allocations);
    var bad_zlib_header = try std.testing.allocator.dupe(u8, zlib_frame);
    defer std.testing.allocator.free(bad_zlib_header);
    bad_zlib_header[1] ^= 1;
    var zlib_header_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.BadZlibHeader, decodeZlibStoredAllocExactSize(zlib_header_failing.allocator(), bad_zlib_header, plain.len));
    try std.testing.expectEqual(@as(usize, 0), zlib_header_failing.allocations);
    var bad_zlib_checksum = try std.testing.allocator.dupe(u8, zlib_frame);
    defer std.testing.allocator.free(bad_zlib_checksum);
    bad_zlib_checksum[bad_zlib_checksum.len - 1] ^= 1;
    var zlib_checksum_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibStoredAllocExactSize(zlib_checksum_failing.allocator(), bad_zlib_checksum, plain.len));
    try std.testing.expectEqual(@as(usize, 0), zlib_checksum_failing.allocations);

    const dictionary = "stored ";
    const dict_plain = "stored exact";
    const zlib_dict = try encodeZlibStoredWithDictionaryAlloc(std.testing.allocator, dict_plain, dictionary);
    defer std.testing.allocator.free(zlib_dict);
    const zlib_dict_exact = try decodeZlibStoredAllocWithDictionaryExactSize(std.testing.allocator, zlib_dict, dictionary, dict_plain.len);
    defer std.testing.allocator.free(zlib_dict_exact);
    try std.testing.expectEqualSlices(u8, dict_plain, zlib_dict_exact);
    try std.testing.expectError(error.SizeMismatch, decodeZlibStoredAllocWithDictionaryExactSize(std.testing.allocator, zlib_dict, dictionary, dict_plain.len - 1));
    try std.testing.expectError(error.SizeMismatch, decodeZlibStoredAllocWithDictionaryExactSize(std.testing.allocator, zlib_dict, dictionary, dict_plain.len + 1));

    const gzip_frame = try encodeGzipStoredAlloc(std.testing.allocator, plain);
    defer std.testing.allocator.free(gzip_frame);
    const gzip_exact = try decodeGzipStoredAllocExactSize(std.testing.allocator, gzip_frame, plain.len);
    defer std.testing.allocator.free(gzip_exact);
    try std.testing.expectEqualSlices(u8, plain, gzip_exact);
    try std.testing.expectError(error.SizeMismatch, decodeGzipStoredAllocExactSize(std.testing.allocator, gzip_frame, plain.len - 1));
    try std.testing.expectError(error.SizeMismatch, decodeGzipStoredAllocExactSize(std.testing.allocator, gzip_frame, plain.len + 1));
    var gzip_short_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.SizeMismatch, decodeGzipStoredAllocExactSize(gzip_short_failing.allocator(), gzip_frame, plain.len - 1));
    try std.testing.expectEqual(@as(usize, 0), gzip_short_failing.allocations);
    var bad_gzip_header = try std.testing.allocator.dupe(u8, gzip_frame);
    defer std.testing.allocator.free(bad_gzip_header);
    bad_gzip_header[0] = 0;
    var gzip_header_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.BadGzipHeader, decodeGzipStoredAllocExactSize(gzip_header_failing.allocator(), bad_gzip_header, plain.len));
    try std.testing.expectEqual(@as(usize, 0), gzip_header_failing.allocations);
    var bad_gzip_crc = try std.testing.allocator.dupe(u8, gzip_frame);
    defer std.testing.allocator.free(bad_gzip_crc);
    bad_gzip_crc[bad_gzip_crc.len - 8] ^= 1;
    var gzip_crc_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.ChecksumMismatch, decodeGzipStoredAllocExactSize(gzip_crc_failing.allocator(), bad_gzip_crc, plain.len));
    try std.testing.expectEqual(@as(usize, 0), gzip_crc_failing.allocations);
}

test "zlib stored wrapper matches level-0 vectors" {
    const empty = try encodeZlibStoredAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqualSlices(u8, &.{ 0x78, 0x01, 0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x01 }, empty);

    const hello = try encodeZlibStoredAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(hello);
    try std.testing.expectEqualSlices(u8, &.{ 0x78, 0x01, 0x01, 0x05, 0x00, 0xfa, 0xff, 'h', 'e', 'l', 'l', 'o', 0x06, 0x2c, 0x02, 0x15 }, hello);
}

test "zlib header metadata parser exposes wrapper fields" {
    const plain = "hello hello hello";
    const dictionary = "hello ";
    const encoded = try encodeZlibStoredWithDictionaryAlloc(std.testing.allocator, plain, dictionary);
    defer std.testing.allocator.free(encoded);

    const info = try parseZlibHeaderInfo(encoded);
    try std.testing.expectEqual(@as(usize, 6), info.data_offset);
    try std.testing.expectEqual(@as(u8, 0x78), info.cmf);
    try std.testing.expectEqual(@as(u8, 0x20), info.flg);
    try std.testing.expectEqual(@as(u8, 8), info.compression_method);
    try std.testing.expectEqual(@as(u8, 15), info.window_bits);
    try std.testing.expectEqual(@as(usize, 32 * 1024), info.window_size);
    try std.testing.expectEqual(@as(u8, 0), info.fcheck);
    try std.testing.expect(info.uses_dictionary);
    try std.testing.expectEqual(@as(u2, 0), info.flevel);
    try std.testing.expectEqual(checksum.adler32(dictionary), info.dictionary_id.?);
    const chunks = [_][]const u8{ encoded[0..1], encoded[1..4], encoded[4..6] };
    var compressed_scratch: [8]u8 = undefined;
    const chunk_info = try parseZlibHeaderInfoFromChunks(&chunks, &compressed_scratch);
    try std.testing.expectEqual(info.data_offset, chunk_info.data_offset);
    try std.testing.expectEqual(info.dictionary_id.?, chunk_info.dictionary_id.?);
    try std.testing.expectError(error.OutputTooSmall, parseZlibHeaderInfoFromChunks(&chunks, compressed_scratch[0..5]));

    const no_dict = try parseZlibHeaderInfo(&.{ 0x78, 0x01 });
    try std.testing.expectEqual(@as(usize, 2), no_dict.data_offset);
    try std.testing.expect(!no_dict.uses_dictionary);
    try std.testing.expectEqual(@as(?u32, null), no_dict.dictionary_id);

    try std.testing.expectError(error.TruncatedFrame, parseZlibHeaderInfo(&.{0x78}));
    try std.testing.expectError(error.TruncatedFrame, parseZlibHeaderInfo(&.{ 0x78, 0x20 }));
    try std.testing.expectError(error.BadZlibHeader, parseZlibHeaderInfo(&.{ 0x78, 0x02 }));
}

test "zlib decoder accepts smaller advertised CINFO window metadata" {
    // zlib's CINFO field advertises the compressor window size, but common
    // decoders accept otherwise-valid streams after that header metadata is
    // tampered to a smaller value. Keep Vort compatible with that behavior:
    // parse/report the smaller window while validating corruption through the
    // deflate payload and Adler/trailing checks.
    var payload: [2048]u8 = undefined;
    var state: u32 = 0x1234abcd;
    for (payload[0..1024]) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    @memcpy(payload[1024..], payload[0..1024]);

    const encoded = try encodeZlibLevelAlloc(std.testing.allocator, &payload, 9);
    defer std.testing.allocator.free(encoded);
    var mutated = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(mutated);

    const cmf: u8 = 0x08; // CM=deflate, CINFO=0 => advertised 256-byte window.
    const flg_prefix = mutated[1] & 0xe0;
    var flg: u8 = flg_prefix;
    while (((@as(u16, cmf) << 8) | flg) % 31 != 0) : (flg += 1) {}
    mutated[0] = cmf;
    mutated[1] = flg;

    const info = try parseZlibHeaderInfo(mutated);
    try std.testing.expectEqual(@as(u8, 8), info.window_bits);
    try std.testing.expectEqual(@as(usize, 256), info.window_size);

    const decoded = try decodeZlibAlloc(std.testing.allocator, mutated);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
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
    var bad_checksum_stored_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibStoredAlloc(bad_checksum_stored_failing.allocator(), bad_checksum));
    try std.testing.expectEqual(@as(usize, 0), bad_checksum_stored_failing.allocations);
    var bad_checksum_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibAlloc(bad_checksum_failing.allocator(), bad_checksum));
    try std.testing.expectEqual(@as(usize, 0), bad_checksum_failing.allocations);

    var with_trailing: [64]u8 = undefined;
    @memcpy(with_trailing[0..encoded.len], encoded);
    with_trailing[encoded.len] = 0;
    try std.testing.expectError(error.TrailingData, decodeZlibStored(with_trailing[0 .. encoded.len + 1], &out));
    try std.testing.expectError(error.TrailingData, decodeZlibStoredAlloc(std.testing.allocator, with_trailing[0 .. encoded.len + 1]));
    var stored_trailing_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TrailingData, decodeZlibStoredAlloc(stored_trailing_failing.allocator(), with_trailing[0 .. encoded.len + 1]));
    try std.testing.expectEqual(@as(usize, 0), stored_trailing_failing.allocations);
    var trailing_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TrailingData, decodeZlibAlloc(trailing_failing.allocator(), with_trailing[0 .. encoded.len + 1]));
    try std.testing.expectEqual(@as(usize, 0), trailing_failing.allocations);
}

test "zlib relaxed decode options ignore Adler and trailing bytes" {
    const encoded = try encodeZlibLevelAlloc(std.testing.allocator, "payload", 6);
    defer std.testing.allocator.free(encoded);

    var bad_header = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_header);
    bad_header[1] ^= 1;
    var bad_header_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.BadZlibHeader, decodeZlibAllocExactSize(bad_header_failing.allocator(), bad_header, 7));
    try std.testing.expectEqual(@as(usize, 0), bad_header_failing.allocations);

    var reserved_block = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(reserved_block);
    reserved_block[2] = 0x07;
    var reserved_alloc_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeZlibAlloc(reserved_alloc_failing.allocator(), reserved_block));
    try std.testing.expectEqual(@as(usize, 0), reserved_alloc_failing.allocations);
    var reserved_exact_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeZlibAllocExactSize(reserved_exact_failing.allocator(), reserved_block, 7));
    try std.testing.expectEqual(@as(usize, 0), reserved_exact_failing.allocations);

    var bad_checksum = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_checksum);
    bad_checksum[bad_checksum.len - 1] ^= 1;

    var out: [32]u8 = undefined;
    try std.testing.expectError(error.ChecksumMismatch, decodeZlib(bad_checksum, &out));
    try std.testing.expectEqual(@as(usize, 7), try decodeZlibWithOptions(bad_checksum, &out, .{ .ignore_adler = true }));
    try std.testing.expectEqualSlices(u8, "payload", out[0..7]);

    var with_trailing: [64]u8 = undefined;
    @memcpy(with_trailing[0..encoded.len], encoded);
    with_trailing[encoded.len] = 0xaa;
    const trailing = with_trailing[0 .. encoded.len + 1];
    try std.testing.expectError(error.TrailingData, decodeZlib(trailing, &out));
    try std.testing.expectEqual(@as(usize, 7), try decodeZlibWithOptions(trailing, &out, .{ .allow_trailing_data = true }));

    var bad_checksum_with_trailing = try std.testing.allocator.dupe(u8, trailing);
    defer std.testing.allocator.free(bad_checksum_with_trailing);
    bad_checksum_with_trailing[encoded.len - 1] ^= 1;
    const relaxed = ZlibDecodeOptions{ .ignore_adler = true, .allow_trailing_data = true };
    try std.testing.expectEqual(@as(usize, 7), try decodeZlibWithOptions(bad_checksum_with_trailing, &out, relaxed));

    const relaxed_chunks = [_][]const u8{
        bad_checksum_with_trailing[0..3],
        bad_checksum_with_trailing[3 .. bad_checksum_with_trailing.len - 1],
        bad_checksum_with_trailing[bad_checksum_with_trailing.len - 1 ..],
    };
    var compressed_scratch: [128]u8 = undefined;
    var joined_decoder = try ZlibDecoder.initFromChunksWithOptionsExactSize(&relaxed_chunks, &compressed_scratch, &out, relaxed, 7);
    var direct_out: [7]u8 = undefined;
    const joined_step = try joined_decoder.step(&direct_out);
    try std.testing.expectEqual(core.StepResult.Status.done, joined_step.status);
    try std.testing.expectEqualSlices(u8, "payload", &direct_out);
    var direct_decoder = try ZlibDecoder.initFromChunksWithOptionsExactSizeDirect(&relaxed_chunks, &out, relaxed, 7);
    @memset(&direct_out, 0);
    const direct_step = try direct_decoder.step(&direct_out);
    try std.testing.expectEqual(core.StepResult.Status.done, direct_step.status);
    try std.testing.expectEqualSlices(u8, "payload", &direct_out);

    try std.testing.expectError(error.ChecksumMismatch, ZlibDecoder.initExactSize(bad_checksum_with_trailing, &out, 7));
    var single_decoder = try ZlibDecoder.initWithOptionsExactSize(bad_checksum_with_trailing, &out, relaxed, 7);
    @memset(&direct_out, 0);
    const single_step = try single_decoder.step(&direct_out);
    try std.testing.expectEqual(core.StepResult.Status.done, single_step.status);
    try std.testing.expectEqualSlices(u8, "payload", &direct_out);

    var reusable_decoder = ZlibDecoder{};
    try reusable_decoder.resetWithOptionsExactSize(bad_checksum_with_trailing, &out, relaxed, 7);
    @memset(&direct_out, 0);
    const reset_step = try reusable_decoder.step(&direct_out);
    try std.testing.expectEqual(core.StepResult.Status.done, reset_step.status);
    try std.testing.expectEqualSlices(u8, "payload", &direct_out);

    const alloc = try decodeZlibAllocWithOptions(std.testing.allocator, bad_checksum_with_trailing, relaxed);
    defer std.testing.allocator.free(alloc);
    try std.testing.expectEqualSlices(u8, "payload", alloc);

    const exact = try decodeZlibAllocWithOptionsExactSize(std.testing.allocator, bad_checksum_with_trailing, relaxed, 7);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, "payload", exact);

    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibAllocWithOptionsLimited(std.testing.allocator, bad_checksum_with_trailing, relaxed, 6));
    const limited = try decodeZlibAllocWithOptionsLimited(std.testing.allocator, bad_checksum_with_trailing, relaxed, 7);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, "payload", limited);

    const dictionary = "pay";
    const dict_encoded = try encodeZlibLevelWithDictionaryAlloc(std.testing.allocator, "payload", dictionary, 6);
    defer std.testing.allocator.free(dict_encoded);
    var dict_bad = try std.testing.allocator.alloc(u8, dict_encoded.len + 1);
    defer std.testing.allocator.free(dict_bad);
    @memcpy(dict_bad[0..dict_encoded.len], dict_encoded);
    dict_bad[dict_encoded.len - 1] ^= 1;
    dict_bad[dict_encoded.len] = 0xbb;
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibWithDictionary(dict_bad, &out, dictionary));
    try std.testing.expectEqual(@as(usize, 7), try decodeZlibWithDictionaryAndOptions(dict_bad, &out, dictionary, relaxed));
    const dict_chunks = [_][]const u8{
        dict_bad[0..6],
        dict_bad[6 .. dict_bad.len - 1],
        dict_bad[dict_bad.len - 1 ..],
    };
    var dict_joined_decoder = try ZlibDecoder.initFromChunksWithDictionaryAndOptionsExactSize(&dict_chunks, dictionary, &compressed_scratch, &out, relaxed, 7);
    @memset(&direct_out, 0);
    const dict_joined_step = try dict_joined_decoder.step(&direct_out);
    try std.testing.expectEqual(core.StepResult.Status.done, dict_joined_step.status);
    try std.testing.expectEqualSlices(u8, "payload", &direct_out);
    var dict_direct_decoder = try ZlibDecoder.initFromChunksWithDictionaryAndOptionsExactSizeDirect(&dict_chunks, dictionary, &out, relaxed, 7);
    @memset(&direct_out, 0);
    const dict_direct_step = try dict_direct_decoder.step(&direct_out);
    try std.testing.expectEqual(core.StepResult.Status.done, dict_direct_step.status);
    try std.testing.expectEqualSlices(u8, "payload", &direct_out);
    var dict_single_decoder = try ZlibDecoder.initWithDictionaryAndOptionsExactSize(dict_bad, dictionary, &out, relaxed, 7);
    @memset(&direct_out, 0);
    const dict_single_step = try dict_single_decoder.step(&direct_out);
    try std.testing.expectEqual(core.StepResult.Status.done, dict_single_step.status);
    try std.testing.expectEqualSlices(u8, "payload", &direct_out);
    const dict_alloc = try decodeZlibAllocWithDictionaryAndOptionsLimited(std.testing.allocator, dict_bad, dictionary, relaxed, 7);
    defer std.testing.allocator.free(dict_alloc);
    try std.testing.expectEqualSlices(u8, "payload", dict_alloc);
}

const png_like_varied_len: usize = 1020;

fn pngLikeVariedIdatFixture() [png_like_varied_len]u8 {
    const widths = [_]usize{ 1, 2, 8, 17 };
    const channels = [_]usize{ 3, 4 };
    const filters = [_]u8{ 0, 1, 2, 3, 4 };
    var out: [png_like_varied_len]u8 = undefined;
    var offset: usize = 0;
    for (filters) |filter| {
        for (channels) |channel_count| {
            for (widths) |width| {
                out[offset] = filter;
                offset += 1;
                const row_len = width * channel_count;
                for (0..row_len) |i| {
                    const value = @as(u32, filter) * 37 + @as(u32, @intCast(channel_count)) * 19 + @as(u32, @intCast(width)) * 11 + @as(u32, @intCast(i)) * 7;
                    out[offset] = @truncate(value);
                    offset += 1;
                }
            }
        }
    }
    std.debug.assert(offset == out.len);
    return out;
}

fn pngLikeIdatFixture() [150]u8 {
    return .{
        // RGB rows: filter byte + 4 pixels * 3 bytes.
        0,    0xff, 0x00, 0x00, 0xff, 0x00, 0xff, 0x00, 0x40, 0x80, 0xc0, 0x20, 0x60,
        1,    0x00, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x7f, 0x80, 0x81, 0xfe, 0xff,
        2,    0x05, 0x05, 0x05, 0x10, 0x10, 0x10, 0x20, 0x21, 0x22, 0x30, 0x31, 0x32,
        3,    0x01, 0x03, 0x06, 0x0a, 0x0f, 0x15, 0x1c, 0x24, 0x2d, 0x37, 0x42, 0x4e,
        4,    0x90, 0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x08, 0x04, 0x02,
        // RGBA rows: filter byte + 4 pixels * 4 bytes.
        0,    0x00, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x80, 0x00, 0xff, 0x00, 0x80,
        0x00, 0x00, 0xff, 0x80, 1,    0x03, 0x06, 0x09, 0x0c, 0x0f, 0x12, 0x15, 0x18,
        0x1b, 0x1e, 0x21, 0x24, 0x27, 0x2a, 0x2d, 0x30, 2,    0xf0, 0xe0, 0xd0, 0xc0,
        0xb0, 0xa0, 0x90, 0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00, 3,
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd,
        0xee, 0xff, 0x10, 4,    0x7f, 0x80, 0x81, 0x82, 0x40, 0x41, 0x42, 0x43, 0x20,
        0x21, 0x22, 0x23, 0x10, 0x11, 0x12, 0x13,
    };
}

fn pngReconstructionRow(comptime row_len: usize, row_index: usize) [row_len]u8 {
    var row: [row_len]u8 = undefined;
    for (&row, 0..) |*byte, i| {
        const value = @as(u32, @intCast(row_index)) * 29 + @as(u32, @intCast(i)) * 17 + @as(u32, @intCast(i / 3)) * 11;
        byte.* = @truncate(value);
    }
    return row;
}

fn filterPngScanlineForTest(filter: u8, row: []const u8, previous: ?[]const u8, bytes_per_pixel: usize, filtered: []u8) void {
    std.debug.assert(filtered.len == row.len);
    for (row, 0..) |pixel, i| {
        const left: u8 = if (i >= bytes_per_pixel) row[i - bytes_per_pixel] else 0;
        const up: u8 = if (previous) |prev| prev[i] else 0;
        const up_left: u8 = if (i >= bytes_per_pixel) blk: {
            if (previous) |prev| break :blk prev[i - bytes_per_pixel];
            break :blk 0;
        } else 0;
        const prediction: u8 = switch (filter) {
            0 => 0,
            1 => left,
            2 => up,
            3 => @intCast((@as(u16, left) + @as(u16, up)) / 2),
            4 => pngPaethPredictor(left, up, up_left),
            else => unreachable,
        };
        filtered[i] = pixel -% prediction;
    }
}

test "zlib decoder drains PNG-like payload from caller scratch" {
    const png_like = pngLikeIdatFixture();
    const encoded = try encodeZlibBestAlloc(std.testing.allocator, &png_like, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    var scratch: [png_like.len]u8 = undefined;
    var decoder = try ZlibDecoder.initExactSize(encoded, &scratch, png_like.len);
    try std.testing.expectEqual(png_like.len, decoder.snapshot().expected_output_len);
    try std.testing.expectEqualStrings("payload", decoder.diagnostics().phase_name);
    var out: [png_like.len]u8 = undefined;
    var written: usize = 0;
    while (true) {
        var chunk: [7]u8 = undefined;
        const step = try decoder.step(&chunk);
        @memcpy(out[written..][0..step.progress.output_written], chunk[0..step.progress.output_written]);
        written += step.progress.output_written;
        if (step.status == .done) {
            try std.testing.expectEqual(encoded.len, step.progress.input_read);
            break;
        }
        try std.testing.expectEqual(core.StepResult.Status.need_output, step.status);
    }
    try std.testing.expectEqualSlices(u8, &png_like, &out);
    try std.testing.expectEqualStrings("done", decoder.diagnostics().phase_name);

    var compressed_scratch: [256]u8 = undefined;
    const chunks = [_][]const u8{
        encoded[0..5],
        encoded[5 .. encoded.len - 3],
        encoded[encoded.len - 3 ..],
    };
    var chunk_decoder = try ZlibDecoder.initFromChunksExactSize(&chunks, &compressed_scratch, &scratch, png_like.len);
    @memset(&out, 0);
    const chunk_step = try chunk_decoder.step(&out);
    try std.testing.expectEqual(core.StepResult.Status.done, chunk_step.status);
    try std.testing.expectEqual(encoded.len, chunk_step.progress.input_read);
    try std.testing.expectEqualSlices(u8, &png_like, &out);
    try std.testing.expectError(error.OutputTooSmall, ZlibDecoder.initFromChunksExactSize(&chunks, compressed_scratch[0 .. encoded.len - 1], &scratch, png_like.len));

    var direct_chunk_decoder = try ZlibDecoder.initFromChunksExactSizeDirect(&chunks, &scratch, png_like.len);
    @memset(&out, 0);
    const direct_chunk_step = try direct_chunk_decoder.step(&out);
    try std.testing.expectEqual(core.StepResult.Status.done, direct_chunk_step.status);
    try std.testing.expectEqual(encoded.len, direct_chunk_step.progress.input_read);
    try std.testing.expectEqualSlices(u8, &png_like, &out);
    try std.testing.expectError(error.OutputTooSmall, ZlibDecoder.initFromChunksExactSizeDirect(&chunks, scratch[0 .. scratch.len - 1], png_like.len));

    try std.testing.expectError(error.OutputTooSmall, ZlibDecoder.initExactSize(encoded, scratch[0 .. scratch.len - 1], png_like.len));
    try std.testing.expectError(error.SizeMismatch, ZlibDecoder.initExactSize(encoded, &scratch, png_like.len - 1));
    try std.testing.expectError(error.SizeMismatch, ZlibDecoder.initExactSize(encoded, &scratch, png_like.len + 1));
}

test "zlib decoder drains varied PNG-like chunks from caller scratch" {
    const png_like = pngLikeVariedIdatFixture();
    const encoded = try encodeZlibBestAlloc(std.testing.allocator, &png_like, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..7],
        encoded[7 .. encoded.len / 2],
        encoded[encoded.len / 2 .. encoded.len - 5],
        encoded[encoded.len - 5 ..],
    };
    var compressed_scratch: [2048]u8 = undefined;
    var scratch: [png_like.len]u8 = undefined;
    var decoder = try ZlibDecoder.initFromChunksExactSize(&chunks, &compressed_scratch, &scratch, png_like.len);
    var direct_decoder = try ZlibDecoder.initFromChunksExactSizeDirect(&chunks, &scratch, png_like.len);
    var out: [png_like.len]u8 = undefined;
    var written: usize = 0;
    while (true) {
        var chunk: [31]u8 = undefined;
        const step = try decoder.step(&chunk);
        @memcpy(out[written..][0..step.progress.output_written], chunk[0..step.progress.output_written]);
        written += step.progress.output_written;
        if (step.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, step.status);
    }
    try std.testing.expectEqualSlices(u8, &png_like, &out);
    @memset(&out, 0);
    const direct_step = try direct_decoder.step(&out);
    try std.testing.expectEqual(core.StepResult.Status.done, direct_step.status);
    try std.testing.expectEqualSlices(u8, &png_like, &out);
}

test "zlib decoder drains PNG scanlines from chunked IDAT scratch" {
    const png_like = pngLikeVariedIdatFixture();
    const encoded = try encodeZlibBestAlloc(std.testing.allocator, &png_like, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..7],
        encoded[7 .. encoded.len / 2],
        encoded[encoded.len / 2 .. encoded.len - 5],
        encoded[encoded.len - 5 ..],
    };
    var compressed_scratch: [2048]u8 = undefined;
    var scratch: [png_like.len]u8 = undefined;
    var decoder = try ZlibDecoder.initFromChunksExactSize(&chunks, &compressed_scratch, &scratch, png_like.len);
    var direct_decoder = try ZlibDecoder.initFromChunksExactSizeDirect(&chunks, &scratch, png_like.len);
    var direct_first_row: [3]u8 = undefined;
    const direct_first_step = try direct_decoder.stepPngScanline(&direct_first_row);
    try std.testing.expectEqual(@as(u8, 0), direct_first_step.filter.?);
    try std.testing.expectEqual(core.StepResult.Status.need_output, direct_first_step.status);
    try std.testing.expectEqualSlices(u8, png_like[1..4], &direct_first_row);

    const widths = [_]usize{ 1, 2, 8, 17 };
    const channels = [_]usize{ 3, 4 };
    const filters = [_]u8{ 0, 1, 2, 3, 4 };
    var row: [17 * 4]u8 = undefined;
    var fixture_offset: usize = 0;
    var row_count: usize = 0;
    for (filters) |filter| {
        for (channels) |channel_count| {
            for (widths) |width| {
                const row_len = width * channel_count;
                const step = try decoder.stepPngScanline(row[0..row_len]);
                try std.testing.expectEqual(filter, step.filter.?);
                try std.testing.expectEqual(row_len, step.row_bytes);
                try std.testing.expectEqual(row_len + 1, step.decoded_consumed);
                try std.testing.expectEqual(row_len, step.progress.output_written);
                try std.testing.expectEqual(filter, png_like[fixture_offset]);
                try std.testing.expectEqualSlices(u8, png_like[fixture_offset + 1 ..][0..row_len], row[0..row_len]);
                fixture_offset += row_len + 1;
                row_count += 1;
                if (fixture_offset == png_like.len) {
                    try std.testing.expectEqual(core.StepResult.Status.done, step.status);
                    try std.testing.expectEqual(encoded.len, step.progress.input_read);
                } else {
                    try std.testing.expectEqual(core.StepResult.Status.need_output, step.status);
                    try std.testing.expectEqual(@as(usize, 0), step.progress.input_read);
                }
            }
        }
    }
    try std.testing.expectEqual(png_like.len, fixture_offset);
    try std.testing.expectEqual(@as(usize, 40), row_count);
    try std.testing.expectEqual(core.StepResult.Status.done, (try decoder.stepPngScanline(row[0..0])).status);

    var malformed = png_like;
    malformed[0] = 5;
    const bad_filter = try encodeZlibBestAlloc(std.testing.allocator, &malformed, optionsForLevel(.default));
    defer std.testing.allocator.free(bad_filter);
    var bad_decoder = try ZlibDecoder.initExactSize(bad_filter, &scratch, malformed.len);
    try std.testing.expectError(error.CorruptFrame, bad_decoder.stepPngScanline(row[0..3]));
    try std.testing.expectEqualStrings("CorruptFrame", bad_decoder.snapshot().last_error_name);
    try std.testing.expectEqual(ZlibDecoder.RecoverabilityHint.payload_corrupt, bad_decoder.snapshot().recoverability_hint);

    var mismatch_decoder = try ZlibDecoder.initExactSize(encoded, &scratch, png_like.len);
    try std.testing.expectError(error.SizeMismatch, mismatch_decoder.stepPngScanline(scratch[0..scratch.len]));
}

test "png scanline reconstruction filters round trip" {
    const bpp = 3;
    const row_len = 12;
    const row_count = 5;
    var rows: [row_count][row_len]u8 = undefined;
    var filtered_payload: [row_count * (row_len + 1)]u8 = undefined;

    var offset: usize = 0;
    var previous: ?[]const u8 = null;
    for (0..row_count) |row_index| {
        rows[row_index] = pngReconstructionRow(row_len, row_index);
        const filter: u8 = @intCast(row_index);
        filtered_payload[offset] = filter;
        filterPngScanlineForTest(filter, &rows[row_index], previous, bpp, filtered_payload[offset + 1 ..][0..row_len]);
        previous = &rows[row_index];
        offset += row_len + 1;
    }

    var reconstructed: [row_count][row_len]u8 = undefined;
    previous = null;
    offset = 0;
    for (0..row_count) |row_index| {
        const filter = filtered_payload[offset];
        const written = try reconstructPngScanline(filter, filtered_payload[offset + 1 ..][0..row_len], previous, bpp, &reconstructed[row_index]);
        try std.testing.expectEqual(row_len, written);
        try std.testing.expectEqualSlices(u8, &rows[row_index], &reconstructed[row_index]);
        previous = &reconstructed[row_index];
        offset += row_len + 1;
    }

    var short_output: [row_len - 1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, reconstructPngScanline(0, filtered_payload[1..][0..row_len], null, bpp, &short_output));
    try std.testing.expectError(error.CorruptFrame, reconstructPngScanline(5, filtered_payload[1..][0..row_len], null, bpp, &reconstructed[0]));
    try std.testing.expectError(error.CorruptFrame, reconstructPngScanline(0, filtered_payload[1..][0..row_len], null, 0, &reconstructed[0]));
    try std.testing.expectError(error.SizeMismatch, reconstructPngScanline(2, filtered_payload[1..][0..row_len], short_output[0..], bpp, &reconstructed[0]));
}

test "stb Paeth predictor matches PNG reference over the full byte domain" {
    var left: usize = 0;
    while (left < 256) : (left += 1) {
        var up: usize = 0;
        while (up < 256) : (up += 1) {
            var up_left: usize = 0;
            while (up_left < 256) : (up_left += 1) {
                const a: u8 = @intCast(left);
                const b: u8 = @intCast(up);
                const c: u8 = @intCast(up_left);
                try std.testing.expectEqual(
                    pngPaethPredictorReference(a, b, c),
                    pngPaethPredictorStbi(a, b, c),
                );
            }
        }
    }
}

test "png scanline reconstruction Paeth bpp1 supports in-place rows" {
    const row_len = 32;
    const previous = pngReconstructionRow(row_len, 1);
    var row = pngReconstructionRow(row_len, 2);
    var filtered: [row_len]u8 = undefined;

    filterPngScanlineForTest(4, &row, &previous, 1, &filtered);
    var in_place = filtered;
    try std.testing.expectEqual(row_len, try reconstructPngScanline(4, &in_place, &previous, 1, &in_place));
    try std.testing.expectEqualSlices(u8, &row, &in_place);

    // The first Paeth row has no `up` samples, so PNG reduces it to bpp=1 Sub
    // reconstruction. Exercise that branch with aliased input/output as well.
    row = pngReconstructionRow(row_len, 0);
    filterPngScanlineForTest(4, &row, null, 1, &filtered);
    in_place = filtered;
    try std.testing.expectEqual(row_len, try reconstructPngScanline(4, &in_place, null, 1, &in_place));
    try std.testing.expectEqualSlices(u8, &row, &in_place);
}

test "png scanline reconstruction Sub fixed bpp supports in-place rows" {
    inline for (.{ 1, 3, 4, 8 }) |bpp| {
        const row_len = 32;
        var row = pngReconstructionRow(row_len, bpp);
        var filtered: [row_len]u8 = undefined;

        filterPngScanlineForTest(1, &row, null, bpp, &filtered);
        var in_place = filtered;
        try std.testing.expectEqual(row_len, try reconstructPngScanline(1, &in_place, null, bpp, &in_place));
        try std.testing.expectEqualSlices(u8, &row, &in_place);
    }
}

test "png scanline reconstruction Sub bpp3 matches scalar reference" {
    var len: usize = 0;
    while (len <= 257) : (len += 1) {
        var filtered: [257]u8 = undefined;
        for (0..len) |i| {
            filtered[i] = @truncate(i *% 73 +% len *% 19 +% (i >> 2));
        }

        var optimized: [257]u8 = undefined;
        var reference: [257]u8 = undefined;
        for (0..len) |i| {
            const left: u8 = if (i >= 3) reference[i - 3] else 0;
            reference[i] = filtered[i] +% left;
        }
        reconstructPngSubBpp3Scanline(filtered[0..len], optimized[0..len]);
        try std.testing.expectEqualSlices(u8, reference[0..len], optimized[0..len]);

        // Direct row reconstruction permits input/output aliasing. Exercise
        // every possible modulo-three tail while retaining the scalar result.
        var in_place = filtered;
        reconstructPngSubBpp3Scanline(in_place[0..len], in_place[0..len]);
        try std.testing.expectEqualSlices(u8, reference[0..len], in_place[0..len]);
    }
}

test "png scanline reconstruction Paeth fixed bpp supports in-place rows" {
    const row_len = 32;
    inline for (.{ 3, 4, 6, 8 }) |bpp| {
        const previous = pngReconstructionRow(row_len, bpp + 1);
        var row = pngReconstructionRow(row_len, bpp + 2);
        var filtered: [row_len]u8 = undefined;

        filterPngScanlineForTest(4, &row, &previous, bpp, &filtered);
        var in_place = filtered;
        try std.testing.expectEqual(row_len, try reconstructPngScanline(4, &in_place, &previous, bpp, &in_place));
        try std.testing.expectEqualSlices(u8, &row, &in_place);

        // With no previous row, Paeth reduces to Sub using the same byte stride.
        row = pngReconstructionRow(row_len, 0);
        filterPngScanlineForTest(4, &row, null, bpp, &filtered);
        in_place = filtered;
        try std.testing.expectEqual(row_len, try reconstructPngScanline(4, &in_place, null, bpp, &in_place));
        try std.testing.expectEqualSlices(u8, &row, &in_place);
    }
}

test "png scanline reconstruction Average bpp3 supports in-place and tail rows" {
    inline for (.{ 32, 33, 34 }) |row_len| {
        const previous = pngReconstructionRow(row_len, 5);
        var row = pngReconstructionRow(row_len, 6);
        var filtered: [row_len]u8 = undefined;

        filterPngScanlineForTest(3, &row, &previous, 3, &filtered);
        var in_place = filtered;
        try std.testing.expectEqual(row_len, try reconstructPngScanline(3, &in_place, &previous, 3, &in_place));
        try std.testing.expectEqualSlices(u8, &row, &in_place);

        row = pngReconstructionRow(row_len, 0);
        filterPngScanlineForTest(3, &row, null, 3, &filtered);
        in_place = filtered;
        try std.testing.expectEqual(row_len, try reconstructPngScanline(3, &in_place, null, 3, &in_place));
        try std.testing.expectEqualSlices(u8, &row, &in_place);
    }
}

test "png scanline reconstruction Average bpp3 matches scalar reference" {
    var len: usize = 0;
    while (len <= 257) : (len += 1) {
        var filtered: [257]u8 = undefined;
        var previous: [257]u8 = undefined;
        for (0..len) |i| {
            filtered[i] = @truncate(i *% 73 +% len *% 19 +% (i >> 2));
            previous[i] = @truncate(i *% 29 +% len *% 41 +% (i << 1));
        }

        var optimized: [257]u8 = undefined;
        var reference: [257]u8 = undefined;
        reconstructPngAverageBpp3Scanline(filtered[0..len], previous[0..len], optimized[0..len]);
        reconstructPngAverageScanlineReference(filtered[0..len], previous[0..len], 3, reference[0..len]);
        try std.testing.expectEqualSlices(u8, reference[0..len], optimized[0..len]);

        reconstructPngAverageBpp3Scanline(filtered[0..len], null, optimized[0..len]);
        reconstructPngAverageScanlineReference(filtered[0..len], null, 3, reference[0..len]);
        try std.testing.expectEqualSlices(u8, reference[0..len], optimized[0..len]);
    }
}

test "png image info computes scanline metadata" {
    const rgb = try pngImageInfo(17, 5, 8, .truecolor);
    try std.testing.expectEqual(@as(u8, 3), rgb.samples_per_pixel);
    try std.testing.expectEqual(@as(u16, 24), rgb.bits_per_pixel);
    try std.testing.expectEqual(@as(usize, 51), rgb.row_len);
    try std.testing.expectEqual(@as(usize, 3), rgb.bytes_per_pixel);
    try std.testing.expectEqual(@as(usize, 260), rgb.zlib_payload_len);

    const rgba16 = try pngImageInfoFromColorType(2, 3, 16, 6);
    try std.testing.expectEqual(PngColorType.truecolor_alpha, rgba16.color_type);
    try std.testing.expectEqual(@as(u8, 4), rgba16.samples_per_pixel);
    try std.testing.expectEqual(@as(u16, 64), rgba16.bits_per_pixel);
    try std.testing.expectEqual(@as(usize, 16), rgba16.row_len);
    try std.testing.expectEqual(@as(usize, 8), rgba16.bytes_per_pixel);
    try std.testing.expectEqual(@as(usize, 51), rgba16.zlib_payload_len);

    const indexed1 = try pngImageInfo(13, 7, 1, .indexed);
    try std.testing.expectEqual(@as(usize, 2), indexed1.row_len);
    try std.testing.expectEqual(@as(usize, 1), indexed1.bytes_per_pixel);
    try std.testing.expectEqual(@as(usize, 21), indexed1.zlib_payload_len);
    const sizes = try pngZlibDecodeBufferSizes(indexed1);
    try std.testing.expectEqual(indexed1.zlib_payload_len, sizes.zlib_scratch_len);
    try std.testing.expectEqual(indexed1.row_len, sizes.filtered_row_scratch_len);
    try std.testing.expectEqual(indexed1.row_len, sizes.previous_row_scratch_len);
    try std.testing.expectEqual(@as(usize, 14), sizes.image_output_len);

    try std.testing.expectError(error.CorruptFrame, pngImageInfo(0, 1, 8, .truecolor));
    try std.testing.expectError(error.CorruptFrame, pngImageInfo(1, 0, 8, .truecolor));
    try std.testing.expectError(error.CorruptFrame, pngImageInfo(1, 1, 4, .truecolor));
    try std.testing.expectError(error.CorruptFrame, pngImageInfoFromColorType(1, 1, 8, 1));
    try std.testing.expectError(error.IntegerOverflow, pngImageInfo(std.math.maxInt(usize), 1, 16, .truecolor_alpha));
}

test "png adam7 metadata plans passes and buffers" {
    const info = try pngAdam7Info(17, 9, 8, .truecolor);
    try std.testing.expectEqual(@as(usize, 17), info.image.width);
    try std.testing.expectEqual(@as(usize, 9), info.image.height);
    try std.testing.expectEqual(@as(usize, 459), info.image_output_len);
    try std.testing.expectEqual(@as(usize, 51), info.max_pass_row_len);
    try std.testing.expectEqual(@as(usize, 478), info.zlib_payload_len);

    const expected = [_]struct { w: usize, h: usize, row: usize, payload: usize, out: usize }{
        .{ .w = 3, .h = 2, .row = 9, .payload = 20, .out = 18 },
        .{ .w = 2, .h = 2, .row = 6, .payload = 14, .out = 12 },
        .{ .w = 5, .h = 1, .row = 15, .payload = 16, .out = 15 },
        .{ .w = 4, .h = 3, .row = 12, .payload = 39, .out = 36 },
        .{ .w = 9, .h = 2, .row = 27, .payload = 56, .out = 54 },
        .{ .w = 8, .h = 5, .row = 24, .payload = 125, .out = 120 },
        .{ .w = 17, .h = 4, .row = 51, .payload = 208, .out = 204 },
    };
    for (expected, 0..) |case, i| {
        const pass = info.passes[i];
        try std.testing.expectEqual(@as(u8, @intCast(i + 1)), pass.pass_index);
        try std.testing.expectEqual(case.w, pass.width);
        try std.testing.expectEqual(case.h, pass.height);
        try std.testing.expectEqual(case.row, pass.row_len);
        try std.testing.expectEqual(case.payload, pass.zlib_payload_len);
        try std.testing.expectEqual(case.out, pass.reconstructed_len);
        try std.testing.expect(!pass.isEmpty());
    }
    const sizes = pngAdam7DecodeBufferSizes(info);
    try std.testing.expectEqual(info.zlib_payload_len, sizes.zlib_scratch_len);
    try std.testing.expectEqual(info.max_pass_row_len, sizes.filtered_row_scratch_len);
    try std.testing.expectEqual(info.max_pass_row_len, sizes.previous_row_scratch_len);
    try std.testing.expectEqual(info.image_output_len, sizes.image_output_len);

    const tiny = try pngAdam7InfoFromColorType(1, 1, 1, 3);
    try std.testing.expectEqual(@as(usize, 2), tiny.zlib_payload_len);
    try std.testing.expectEqual(@as(usize, 1), tiny.max_pass_row_len);
    try std.testing.expectEqual(@as(usize, 1), tiny.image_output_len);
    try std.testing.expectEqual(@as(usize, 1), tiny.passes[0].width);
    try std.testing.expectEqual(@as(usize, 1), tiny.passes[0].height);
    for (tiny.passes[1..]) |pass| try std.testing.expect(pass.isEmpty());

    try std.testing.expectError(error.CorruptFrame, pngAdam7InfoFromColorType(1, 1, 8, 1));
}

test "png adam7 placement scatters byte-aligned passes" {
    const info = try pngAdam7Info(5, 5, 8, .truecolor);
    var image: [5 * 5 * 3]u8 = @splat(0);
    var expected: [5 * 5 * 3]u8 = @splat(0);

    for (info.passes) |pass| {
        if (pass.isEmpty()) continue;
        var pass_rows: [32]u8 = @splat(0);
        var offset: usize = 0;
        for (0..pass.height) |row_index| {
            for (0..pass.width) |pass_x| {
                const dest_x = pass.x_start + pass_x * pass.x_step;
                const dest_y = pass.y_start + row_index * pass.y_step;
                const base: u8 = @intCast(dest_y * 16 + dest_x);
                pass_rows[offset + 0] = base;
                pass_rows[offset + 1] = base +% 1;
                pass_rows[offset + 2] = base +% 2;
                const dest = (dest_y * info.image.width + dest_x) * 3;
                expected[dest + 0] = pass_rows[offset + 0];
                expected[dest + 1] = pass_rows[offset + 1];
                expected[dest + 2] = pass_rows[offset + 2];
                offset += 3;
            }
        }
        try placePngAdam7Pass(info, pass, pass_rows[0..pass.reconstructed_len], &image);
    }

    try std.testing.expectEqualSlices(u8, &expected, &image);
    try std.testing.expectError(error.OutputTooSmall, placePngAdam7Row(info, info.passes[0], 0, image[0..info.passes[0].row_len], image[0 .. image.len - 1]));
    try std.testing.expectError(error.RangeOutOfBounds, placePngAdam7Row(info, info.passes[0], info.passes[0].height, image[0..info.passes[0].row_len], &image));
    try std.testing.expectError(error.InputTooSmall, placePngAdam7Pass(info, info.passes[0], image[0 .. info.passes[0].reconstructed_len - 1], &image));
}

const PngAdam7StreamingRowCollector = struct {
    info: PngAdam7Info,
    image: []u8,
    rows: usize = 0,
    first_pass_index: u8 = 0,
    first_row_len: usize = 0,
    first_pass_row_index: usize = 0,
};

fn collectPngAdam7StreamingRow(context: *PngAdam7StreamingRowCollector, row: PngAdam7Row) Error!void {
    if (context.rows == 0) {
        context.first_pass_index = row.pass.pass_index;
        context.first_row_len = row.row.len;
        context.first_pass_row_index = row.pass_row_index;
    }
    try placePngAdam7Row(context.info, row.pass, row.pass_row_index, row.row, context.image);
    context.rows += 1;
}

test "png adam7 placement scatters sub-byte packed pixels" {
    const info = try pngAdam7Info(5, 5, 2, .indexed);
    var image: [10]u8 = @splat(0);
    var expected_pixels: [25]u8 = @splat(0);

    for (info.passes) |pass| {
        if (pass.isEmpty()) continue;
        var pass_rows: [8]u8 = @splat(0);
        for (0..pass.height) |row_index| {
            @memset(pass_rows[row_index * pass.row_len ..][0..pass.row_len], 0);
            for (0..pass.width) |pass_x| {
                const dest_x = pass.x_start + pass_x * pass.x_step;
                const dest_y = pass.y_start + row_index * pass.y_step;
                const value: u8 = @intCast((dest_x + dest_y * 2) & 0x3);
                expected_pixels[dest_y * info.image.width + dest_x] = value;
                writePngPackedPixel(pass_rows[row_index * pass.row_len ..][0..pass.row_len], pass_x, info.image.bits_per_pixel, value);
            }
        }
        try placePngAdam7Pass(info, pass, pass_rows[0..pass.reconstructed_len], &image);
    }

    var expected_image: [10]u8 = @splat(0);
    for (0..info.image.height) |y| {
        const row = expected_image[y * info.image.row_len ..][0..info.image.row_len];
        for (0..info.image.width) |x| {
            writePngPackedPixel(row, x, info.image.bits_per_pixel, expected_pixels[y * info.image.width + x]);
        }
    }
    try std.testing.expectEqualSlices(u8, &expected_image, &image);

    const tiny = try pngAdam7Info(1, 1, 1, .indexed);
    try std.testing.expectError(error.RangeOutOfBounds, placePngAdam7Row(tiny, tiny.passes[1], 0, "", image[0..1]));
}

test "png adam7 zlib image helper reconstructs interlaced RGB chunks" {
    const info = try pngAdam7Info(5, 5, 8, .truecolor);
    const sizes = pngAdam7DecodeBufferSizes(info);
    var expected_image: [5 * 5 * 3]u8 = undefined;
    for (0..info.image.height) |y| {
        for (0..info.image.width) |x| {
            const offset = (y * info.image.width + x) * 3;
            const base: u8 = @intCast(y * 32 + x * 3);
            expected_image[offset + 0] = base;
            expected_image[offset + 1] = base +% 1;
            expected_image[offset + 2] = base +% 2;
        }
    }

    var filtered_payload: [128]u8 = undefined;
    var payload_offset: usize = 0;
    var pass_row: [64]u8 = undefined;
    var filtered_row: [64]u8 = undefined;
    var previous_row: [64]u8 = undefined;
    for (info.passes) |pass| {
        if (pass.isEmpty()) continue;
        var has_previous = false;
        for (0..pass.height) |row_index| {
            for (0..pass.width) |pass_x| {
                const dest_x = pass.x_start + pass_x * pass.x_step;
                const dest_y = pass.y_start + row_index * pass.y_step;
                const src = (dest_y * info.image.width + dest_x) * 3;
                @memcpy(pass_row[pass_x * 3 ..][0..3], expected_image[src..][0..3]);
            }
            const filter: u8 = @intCast((@as(usize, pass.pass_index) + row_index - 1) % 5);
            const previous = if (has_previous) previous_row[0..pass.row_len] else null;
            filterPngScanlineForTest(filter, pass_row[0..pass.row_len], previous, pass.bytes_per_pixel, filtered_row[0..pass.row_len]);
            filtered_payload[payload_offset] = filter;
            @memcpy(filtered_payload[payload_offset + 1 ..][0..pass.row_len], filtered_row[0..pass.row_len]);
            payload_offset += pass.row_len + 1;
            @memcpy(previous_row[0..pass.row_len], pass_row[0..pass.row_len]);
            has_previous = true;
        }
    }
    try std.testing.expectEqual(info.zlib_payload_len, payload_offset);

    const encoded = try encodeZlibBestAlloc(std.testing.allocator, filtered_payload[0..payload_offset], optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..5],
        encoded[5 .. encoded.len - 4],
        encoded[encoded.len - 4 ..],
    };
    var compressed_scratch: [256]u8 = undefined;
    var zlib_scratch: [128]u8 = undefined;
    var filtered_row_scratch: [64]u8 = undefined;
    var previous_row_scratch: [64]u8 = undefined;
    var image: [expected_image.len]u8 = undefined;
    const result = try decodePngAdam7ZlibImageFromChunks(&chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image);
    try std.testing.expectEqual(@as(usize, 7), result.passes);
    try std.testing.expectEqual(@as(usize, 11), result.rows);
    try std.testing.expectEqual(expected_image.len, result.output_written);
    try std.testing.expectEqual(encoded.len, result.zlib_input_read);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);
    @memset(&image, 0);
    const direct_result = try decodePngAdam7ZlibImageFromChunksDirect(&chunks, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image);
    try std.testing.expectEqual(@as(usize, 7), direct_result.passes);
    try std.testing.expectEqual(@as(usize, 11), direct_result.rows);
    try std.testing.expectEqual(expected_image.len, direct_result.output_written);
    try std.testing.expectEqual(encoded.len, direct_result.zlib_input_read);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);
    @memset(&image, 0);
    const direct_options_result = try decodePngAdam7ZlibImageFromChunksWithOptionsDirect(&chunks, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, .{}, &image);
    try std.testing.expectEqual(direct_result.rows, direct_options_result.rows);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);

    var single_image: [expected_image.len]u8 = undefined;
    const single = try decodePngAdam7ZlibImage(encoded, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &single_image);
    try std.testing.expectEqualSlices(u8, &expected_image, &single_image);
    try std.testing.expectEqual(encoded.len, single.zlib_input_read);

    var history_scratch: [PngStreamingZlibScanlineDecoder.history_scratch_len]u8 = undefined;
    var chunked_history_scratch: [PngStreamingZlibChunkedScanlineDecoder.history_scratch_len]u8 = undefined;
    @memset(&image, 0);
    const streaming = try decodePngAdam7StreamingZlibImage(encoded, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image);
    try std.testing.expectEqual(@as(usize, 7), streaming.passes);
    try std.testing.expectEqual(@as(usize, 11), streaming.rows);
    try std.testing.expectEqual(expected_image.len, streaming.output_written);
    try std.testing.expectEqual(encoded.len, streaming.zlib_input_read);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);
    @memset(&image, 0);
    const chunked_streaming = try decodePngAdam7StreamingZlibImageFromChunksDirect(&chunks, &chunked_history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image);
    try std.testing.expectEqual(streaming.passes, chunked_streaming.passes);
    try std.testing.expectEqual(streaming.rows, chunked_streaming.rows);
    try std.testing.expectEqual(streaming.output_written, chunked_streaming.output_written);
    try std.testing.expectEqual(encoded.len, chunked_streaming.zlib_input_read);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);

    @memset(&image, 0);
    var row_collector = PngAdam7StreamingRowCollector{ .info = info, .image = &image };
    var row_decoder = try PngAdam7StreamingZlibRowDecoder.init(encoded, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info);
    while (try row_decoder.step()) |row| try collectPngAdam7StreamingRow(&row_collector, row);
    const row_snapshot = row_decoder.snapshot();
    try std.testing.expectEqual(@as(usize, 11), row_snapshot.rows_done);
    try std.testing.expectEqual(info.zlib_payload_len - row_snapshot.rows_done, row_snapshot.row_bytes);
    try std.testing.expectEqual(encoded.len, row_snapshot.zlib_input_read);
    try std.testing.expect(row_snapshot.done);
    try std.testing.expectEqual(row_snapshot.rows_done, row_collector.rows);
    try std.testing.expectEqual(@as(u8, 1), row_collector.first_pass_index);
    try std.testing.expectEqual(@as(usize, 0), row_collector.first_pass_row_index);
    try std.testing.expectEqual(@as(usize, 3), row_collector.first_row_len);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);

    @memset(&image, 0);
    row_collector = .{ .info = info, .image = &image };
    var chunked_row_decoder = try PngAdam7StreamingZlibChunkedRowDecoder.initDirect(&chunks, &chunked_history_scratch, &filtered_row_scratch, &previous_row_scratch, info);
    while (try chunked_row_decoder.step()) |row| try collectPngAdam7StreamingRow(&row_collector, row);
    const chunked_row_snapshot = chunked_row_decoder.snapshot();
    try std.testing.expectEqual(row_snapshot.rows_done, chunked_row_snapshot.rows_done);
    try std.testing.expectEqual(row_snapshot.row_bytes, chunked_row_snapshot.row_bytes);
    try std.testing.expectEqual(encoded.len, chunked_row_snapshot.zlib_input_read);
    try std.testing.expect(chunked_row_snapshot.done);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);

    try std.testing.expectError(error.OutputTooSmall, decodePngAdam7ZlibImageFromChunks(&chunks, &compressed_scratch, &zlib_scratch, filtered_row_scratch[0 .. sizes.filtered_row_scratch_len - 1], &previous_row_scratch, info, &image));
    try std.testing.expectError(error.OutputTooSmall, decodePngAdam7ZlibImageFromChunks(&chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, image[0 .. image.len - 1]));
    var short_history: [PngStreamingZlibScanlineDecoder.history_scratch_len - 1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodePngAdam7StreamingZlibImage(encoded, &short_history, &filtered_row_scratch, &previous_row_scratch, info, &image));
    var too_wide_image: [6 * 5 * 3]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, decodePngAdam7ZlibImageFromChunks(&chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, try pngAdam7Info(6, 5, 8, .truecolor), &too_wide_image));
}

test "png adam7 zlib image helper reconstructs interlaced sub-byte chunks" {
    const info = try pngAdam7Info(5, 5, 2, .indexed);
    const sizes = pngAdam7DecodeBufferSizes(info);
    var expected_pixels: [25]u8 = @splat(0);
    for (0..info.image.height) |y| {
        for (0..info.image.width) |x| {
            expected_pixels[y * info.image.width + x] = @intCast((x + y * 2) & 0x3);
        }
    }
    var expected_image: [10]u8 = @splat(0);
    for (0..info.image.height) |y| {
        const row = expected_image[y * info.image.row_len ..][0..info.image.row_len];
        for (0..info.image.width) |x| writePngPackedPixel(row, x, info.image.bits_per_pixel, expected_pixels[y * info.image.width + x]);
    }

    var filtered_payload: [64]u8 = undefined;
    var payload_offset: usize = 0;
    var pass_row: [8]u8 = undefined;
    var filtered_row: [8]u8 = undefined;
    var previous_row: [8]u8 = undefined;
    for (info.passes) |pass| {
        if (pass.isEmpty()) continue;
        var has_previous = false;
        for (0..pass.height) |row_index| {
            @memset(pass_row[0..pass.row_len], 0);
            for (0..pass.width) |pass_x| {
                const dest_x = pass.x_start + pass_x * pass.x_step;
                const dest_y = pass.y_start + row_index * pass.y_step;
                writePngPackedPixel(pass_row[0..pass.row_len], pass_x, info.image.bits_per_pixel, expected_pixels[dest_y * info.image.width + dest_x]);
            }
            const filter: u8 = @intCast((@as(usize, pass.pass_index) + row_index - 1) % 5);
            const previous = if (has_previous) previous_row[0..pass.row_len] else null;
            filterPngScanlineForTest(filter, pass_row[0..pass.row_len], previous, pass.bytes_per_pixel, filtered_row[0..pass.row_len]);
            filtered_payload[payload_offset] = filter;
            @memcpy(filtered_payload[payload_offset + 1 ..][0..pass.row_len], filtered_row[0..pass.row_len]);
            payload_offset += pass.row_len + 1;
            @memcpy(previous_row[0..pass.row_len], pass_row[0..pass.row_len]);
            has_previous = true;
        }
    }
    try std.testing.expectEqual(info.zlib_payload_len, payload_offset);

    const encoded = try encodeZlibBestAlloc(std.testing.allocator, filtered_payload[0..payload_offset], optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..4],
        encoded[4 .. encoded.len - 2],
        encoded[encoded.len - 2 ..],
    };
    var compressed_scratch: [128]u8 = undefined;
    var zlib_scratch: [64]u8 = undefined;
    var filtered_row_scratch: [8]u8 = undefined;
    var previous_row_scratch: [8]u8 = undefined;
    var image: [expected_image.len]u8 = undefined;
    const result = try decodePngAdam7ZlibImageFromChunks(&chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image);
    try std.testing.expectEqual(sizes.image_output_len, result.output_written);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);

    var history_scratch: [PngStreamingZlibChunkedScanlineDecoder.history_scratch_len]u8 = undefined;
    @memset(&image, 0);
    const streaming = try decodePngAdam7StreamingZlibImageFromChunksDirect(&chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image);
    try std.testing.expectEqual(sizes.image_output_len, streaming.output_written);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);
}

test "png adam7 zlib image helper reconstructs interlaced RGBA16 chunks" {
    const info = try pngAdam7Info(5, 5, 16, .truecolor_alpha);
    const sizes = pngAdam7DecodeBufferSizes(info);
    try std.testing.expectEqual(@as(usize, 8), info.image.bytes_per_pixel);
    var expected_image: [5 * 5 * 8]u8 = undefined;
    for (0..info.image.height) |y| {
        for (0..info.image.width) |x| {
            const offset = (y * info.image.width + x) * 8;
            const base: u16 = @intCast(y * 257 + x * 17);
            std.mem.writeInt(u16, expected_image[offset + 0 ..][0..2], base +% 0x0101, .big);
            std.mem.writeInt(u16, expected_image[offset + 2 ..][0..2], base +% 0x0202, .big);
            std.mem.writeInt(u16, expected_image[offset + 4 ..][0..2], base +% 0x0303, .big);
            std.mem.writeInt(u16, expected_image[offset + 6 ..][0..2], 0xffff -% base, .big);
        }
    }

    var filtered_payload: [256]u8 = undefined;
    var payload_offset: usize = 0;
    var pass_row: [128]u8 = undefined;
    var filtered_row: [128]u8 = undefined;
    var previous_row: [128]u8 = undefined;
    for (info.passes) |pass| {
        if (pass.isEmpty()) continue;
        var has_previous = false;
        for (0..pass.height) |row_index| {
            for (0..pass.width) |pass_x| {
                const dest_x = pass.x_start + pass_x * pass.x_step;
                const dest_y = pass.y_start + row_index * pass.y_step;
                const src = (dest_y * info.image.width + dest_x) * 8;
                @memcpy(pass_row[pass_x * 8 ..][0..8], expected_image[src..][0..8]);
            }
            const filter: u8 = @intCast((@as(usize, pass.pass_index) + row_index - 1) % 5);
            const previous = if (has_previous) previous_row[0..pass.row_len] else null;
            filterPngScanlineForTest(filter, pass_row[0..pass.row_len], previous, pass.bytes_per_pixel, filtered_row[0..pass.row_len]);
            filtered_payload[payload_offset] = filter;
            @memcpy(filtered_payload[payload_offset + 1 ..][0..pass.row_len], filtered_row[0..pass.row_len]);
            payload_offset += pass.row_len + 1;
            @memcpy(previous_row[0..pass.row_len], pass_row[0..pass.row_len]);
            has_previous = true;
        }
    }
    try std.testing.expectEqual(info.zlib_payload_len, payload_offset);

    const encoded = try encodeZlibBestAlloc(std.testing.allocator, filtered_payload[0..payload_offset], optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..6],
        encoded[6 .. encoded.len - 5],
        encoded[encoded.len - 5 ..],
    };
    var compressed_scratch: [256]u8 = undefined;
    var zlib_scratch: [256]u8 = undefined;
    var filtered_row_scratch: [64]u8 = undefined;
    var previous_row_scratch: [64]u8 = undefined;
    var image: [expected_image.len]u8 = undefined;
    const result = try decodePngAdam7ZlibImageFromChunks(&chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image);
    try std.testing.expectEqual(sizes.image_output_len, result.output_written);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);

    var history_scratch: [PngStreamingZlibChunkedScanlineDecoder.history_scratch_len]u8 = undefined;
    @memset(&image, 0);
    const streaming = try decodePngAdam7StreamingZlibImageFromChunksDirect(&chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image);
    try std.testing.expectEqual(sizes.image_output_len, streaming.output_written);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);
}

test "png adam7 zlib image helper rejects corrupt logical payloads" {
    const info = try pngAdam7Info(1, 1, 1, .indexed);
    var compressed_scratch: [64]u8 = undefined;
    var zlib_scratch: [8]u8 = undefined;
    var filtered_row_scratch: [1]u8 = undefined;
    var previous_row_scratch: [1]u8 = undefined;
    var image: [1]u8 = undefined;

    const bad_filter_payload = [_]u8{ 5, 0 };
    const bad_filter = try encodeZlibBestAlloc(std.testing.allocator, &bad_filter_payload, optionsForLevel(.default));
    defer std.testing.allocator.free(bad_filter);
    const bad_filter_chunks = [_][]const u8{ bad_filter[0 .. bad_filter.len / 2], bad_filter[bad_filter.len / 2 ..] };
    try std.testing.expectError(error.CorruptFrame, decodePngAdam7ZlibImageFromChunks(&bad_filter_chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
    var history_scratch: [PngStreamingZlibChunkedScanlineDecoder.history_scratch_len]u8 = undefined;
    try std.testing.expectError(error.CorruptFrame, decodePngAdam7StreamingZlibImageFromChunksDirect(&bad_filter_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));

    const short_payload = [_]u8{0};
    const short = try encodeZlibBestAlloc(std.testing.allocator, &short_payload, optionsForLevel(.default));
    defer std.testing.allocator.free(short);
    const short_chunks = [_][]const u8{short};
    try std.testing.expectError(error.SizeMismatch, decodePngAdam7ZlibImageFromChunks(&short_chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
    try std.testing.expectError(error.SizeMismatch, decodePngAdam7StreamingZlibImageFromChunksDirect(&short_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));

    const trailing_payload = [_]u8{ 0, 0, 0 };
    const trailing = try encodeZlibBestAlloc(std.testing.allocator, &trailing_payload, optionsForLevel(.default));
    defer std.testing.allocator.free(trailing);
    const trailing_chunks = [_][]const u8{trailing};
    try std.testing.expectError(error.SizeMismatch, decodePngAdam7ZlibImageFromChunks(&trailing_chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
    try std.testing.expectError(error.SizeMismatch, decodePngAdam7StreamingZlibImageFromChunksDirect(&trailing_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
}

test "png image helpers reject corrupt zlib wrappers" {
    const info = try pngImageInfo(1, 1, 8, .grayscale);
    const adam7 = try pngAdam7Info(1, 1, 8, .grayscale);
    const payload = [_]u8{ 0, 0x42 };
    const encoded = try encodeZlibBestAlloc(std.testing.allocator, &payload, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);

    var compressed_scratch: [64]u8 = undefined;
    var zlib_scratch: [8]u8 = undefined;
    var filtered_row_scratch: [1]u8 = undefined;
    var previous_row_scratch: [1]u8 = undefined;
    var image: [1]u8 = undefined;

    var bad_header = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_header);
    bad_header[0] = 0;
    const bad_header_chunks = [_][]const u8{bad_header};
    try std.testing.expectError(error.BadZlibHeader, decodePngZlibImageFromChunks(&bad_header_chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
    try std.testing.expectError(error.BadZlibHeader, decodePngAdam7ZlibImageFromChunks(&bad_header_chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, adam7, &image));
    var history_scratch: [PngStreamingZlibChunkedScanlineDecoder.history_scratch_len]u8 = undefined;
    try std.testing.expectError(error.BadZlibHeader, decodePngAdam7StreamingZlibImageFromChunksDirect(&bad_header_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, adam7, &image));

    const no_payload_chunks = [_][]const u8{ &.{0x78}, &.{0x01} };
    try std.testing.expectError(error.TruncatedFrame, decodePngZlibImageFromChunks(&no_payload_chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
    try std.testing.expectError(error.TruncatedFrame, decodePngAdam7ZlibImageFromChunks(&no_payload_chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, adam7, &image));
    try std.testing.expectError(error.TruncatedFrame, decodePngZlibImageFromChunksDirect(&no_payload_chunks, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
    try std.testing.expectError(error.TruncatedFrame, decodePngAdam7ZlibImageFromChunksDirect(&no_payload_chunks, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, adam7, &image));
    try std.testing.expectError(error.TruncatedFrame, decodePngAdam7StreamingZlibImageFromChunksDirect(&no_payload_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, adam7, &image));

    const reserved_chunks = [_][]const u8{ &.{0x78}, &.{ 0x01, 0x07 } };
    try std.testing.expectError(error.InvalidDeflateBlockType, decodePngZlibImageFromChunks(&reserved_chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
    try std.testing.expectError(error.InvalidDeflateBlockType, decodePngAdam7ZlibImageFromChunks(&reserved_chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, adam7, &image));
    try std.testing.expectError(error.InvalidDeflateBlockType, decodePngZlibImageFromChunksDirect(&reserved_chunks, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
    try std.testing.expectError(error.InvalidDeflateBlockType, decodePngAdam7ZlibImageFromChunksDirect(&reserved_chunks, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, adam7, &image));
    try std.testing.expectError(error.InvalidDeflateBlockType, decodePngAdam7StreamingZlibImageFromChunksDirect(&reserved_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, adam7, &image));

    var bad_adler = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_adler);
    bad_adler[bad_adler.len - 1] ^= 1;
    const bad_adler_chunks = [_][]const u8{bad_adler};
    try std.testing.expectError(error.ChecksumMismatch, decodePngZlibImageFromChunks(&bad_adler_chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
    try std.testing.expectError(error.ChecksumMismatch, decodePngAdam7ZlibImageFromChunks(&bad_adler_chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, adam7, &image));
    try std.testing.expectError(error.ChecksumMismatch, decodePngAdam7StreamingZlibImageFromChunksDirect(&bad_adler_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, adam7, &image));
    _ = try decodePngAdam7StreamingZlibImageFromChunksWithOptionsDirect(&bad_adler_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, adam7, .{ .ignore_adler = true }, &image);

    const truncated = encoded[0 .. encoded.len - 2];
    const truncated_chunks = [_][]const u8{truncated};
    try std.testing.expectError(error.TruncatedFrame, decodePngZlibImageFromChunks(&truncated_chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
    try std.testing.expectError(error.TruncatedFrame, decodePngAdam7ZlibImageFromChunks(&truncated_chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, adam7, &image));
    try std.testing.expectError(error.TruncatedFrame, decodePngAdam7StreamingZlibImageFromChunksDirect(&truncated_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, adam7, &image));
}

test "zlib decoder reconstructs PNG scanlines from chunked IDAT scratch" {
    const bpp = 3;
    const row_len = 12;
    const row_count = 5;
    var rows: [row_count][row_len]u8 = undefined;
    var filtered_payload: [row_count * (row_len + 1)]u8 = undefined;

    var payload_offset: usize = 0;
    var previous: ?[]const u8 = null;
    for (0..row_count) |row_index| {
        rows[row_index] = pngReconstructionRow(row_len, row_index);
        const filter: u8 = @intCast(row_index);
        filtered_payload[payload_offset] = filter;
        filterPngScanlineForTest(filter, &rows[row_index], previous, bpp, filtered_payload[payload_offset + 1 ..][0..row_len]);
        previous = &rows[row_index];
        payload_offset += row_len + 1;
    }

    const encoded = try encodeZlibBestAlloc(std.testing.allocator, &filtered_payload, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..5],
        encoded[5 .. encoded.len - 4],
        encoded[encoded.len - 4 ..],
    };
    var compressed_scratch: [256]u8 = undefined;
    var decode_scratch: [filtered_payload.len]u8 = undefined;
    var decoder = try ZlibDecoder.initFromChunksExactSize(&chunks, &compressed_scratch, &decode_scratch, filtered_payload.len);

    var filtered_row: [row_len]u8 = undefined;
    var previous_row: [row_len]u8 = undefined;
    var output: [row_len]u8 = undefined;
    var previous_row_slice: ?[]const u8 = null;
    for (0..row_count) |row_index| {
        const step = try decoder.stepPngScanlineReconstruct(&filtered_row, previous_row_slice, bpp, &output);
        try std.testing.expectEqual(@as(u8, @intCast(row_index)), step.filter.?);
        try std.testing.expectEqual(row_len, step.row_bytes);
        try std.testing.expectEqualSlices(u8, &rows[row_index], &output);
        @memcpy(&previous_row, &output);
        previous_row_slice = &previous_row;
        if (row_index + 1 == row_count) {
            try std.testing.expectEqual(core.StepResult.Status.done, step.status);
            try std.testing.expectEqual(encoded.len, step.progress.input_read);
        } else {
            try std.testing.expectEqual(core.StepResult.Status.need_output, step.status);
        }
    }
    try std.testing.expectEqual(core.StepResult.Status.done, (try decoder.stepPngScanlineReconstruct(filtered_row[0..0], null, bpp, output[0..0])).status);

    var error_decoder = try ZlibDecoder.initExactSize(encoded, &decode_scratch, filtered_payload.len);
    try std.testing.expectError(error.OutputTooSmall, error_decoder.stepPngScanlineReconstruct(filtered_row[0 .. row_len - 1], null, bpp, &output));
    try std.testing.expectError(error.CorruptFrame, error_decoder.stepPngScanlineReconstruct(&filtered_row, null, 0, &output));
    try std.testing.expectError(error.SizeMismatch, error_decoder.stepPngScanlineReconstruct(&filtered_row, previous_row[0 .. row_len - 1], bpp, &output));
}

test "png zlib scanline decoder reconstructs rows from chunked IDAT scratch" {
    const bpp = 3;
    const row_len = 12;
    const row_count = 5;
    var rows: [row_count][row_len]u8 = undefined;
    var filtered_payload: [row_count * (row_len + 1)]u8 = undefined;

    var payload_offset: usize = 0;
    var previous: ?[]const u8 = null;
    for (0..row_count) |row_index| {
        rows[row_index] = pngReconstructionRow(row_len, row_index);
        const filter: u8 = @intCast(row_index);
        filtered_payload[payload_offset] = filter;
        filterPngScanlineForTest(filter, &rows[row_index], previous, bpp, filtered_payload[payload_offset + 1 ..][0..row_len]);
        previous = &rows[row_index];
        payload_offset += row_len + 1;
    }

    const encoded = try encodeZlibBestAlloc(std.testing.allocator, &filtered_payload, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..5],
        encoded[5 .. encoded.len - 4],
        encoded[encoded.len - 4 ..],
    };
    var compressed_scratch: [256]u8 = undefined;
    var zlib_scratch: [filtered_payload.len]u8 = undefined;
    var filtered_row_scratch: [row_len]u8 = undefined;
    var previous_row_scratch: [row_len]u8 = undefined;
    const info = try pngImageInfo(row_len / bpp, row_count, 8, .truecolor);
    try std.testing.expectEqual(row_len, info.row_len);
    try std.testing.expectEqual(bpp, info.bytes_per_pixel);
    try std.testing.expectEqual(filtered_payload.len, info.zlib_payload_len);
    var decoder = try PngZlibScanlineDecoder.initFromChunksWithInfo(&chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info);

    var output: [row_len]u8 = undefined;
    for (0..row_count) |row_index| {
        const step = try decoder.step(&output);
        try std.testing.expectEqual(@as(u8, @intCast(row_index)), step.filter.?);
        try std.testing.expectEqual(row_index, step.row_index);
        try std.testing.expectEqual(row_len, step.row_bytes);
        try std.testing.expectEqual(row_index + 1, step.rows_done);
        try std.testing.expectEqualSlices(u8, &rows[row_index], &output);
        if (row_index + 1 == row_count) {
            try std.testing.expectEqual(core.StepResult.Status.done, step.status);
            try std.testing.expectEqual(encoded.len, step.progress.input_read);
        } else {
            try std.testing.expectEqual(core.StepResult.Status.need_output, step.status);
            try std.testing.expectEqual(@as(usize, 0), step.progress.input_read);
        }
    }
    try std.testing.expect(decoder.snapshot().done);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().rows_remaining);
    try std.testing.expectEqual(core.StepResult.Status.done, (try decoder.step(output[0..0])).status);

    try std.testing.expectError(error.OutputTooSmall, PngZlibScanlineDecoder.initFromChunksWithInfo(&chunks, &compressed_scratch, &zlib_scratch, filtered_row_scratch[0 .. row_len - 1], &previous_row_scratch, info));
    try std.testing.expectError(error.SizeMismatch, PngZlibScanlineDecoder.initFromChunksWithInfo(&chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, try pngImageInfo(row_len / bpp, row_count + 1, 8, .truecolor)));

    var step_decoder = try PngZlibScanlineDecoder.initFromChunksWithInfo(&chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info);
    try std.testing.expectError(error.OutputTooSmall, step_decoder.step(output[0 .. row_len - 1]));
    try std.testing.expectEqualStrings("OutputTooSmall", step_decoder.diagnostics().last_error_name);
}

test "png stored zlib scanline decoder streams without zlib scratch" {
    const bpp = 3;
    const row_len = 12;
    const row_count = 5;
    var rows: [row_count][row_len]u8 = undefined;
    var expected_image: [row_count * row_len]u8 = undefined;
    var filtered_payload: [row_count * (row_len + 1)]u8 = undefined;

    var payload_offset: usize = 0;
    var image_offset: usize = 0;
    var previous: ?[]const u8 = null;
    for (0..row_count) |row_index| {
        rows[row_index] = pngReconstructionRow(row_len, row_index);
        @memcpy(expected_image[image_offset..][0..row_len], &rows[row_index]);
        image_offset += row_len;
        const filter: u8 = @intCast(row_index);
        filtered_payload[payload_offset] = filter;
        filterPngScanlineForTest(filter, &rows[row_index], previous, bpp, filtered_payload[payload_offset + 1 ..][0..row_len]);
        previous = &rows[row_index];
        payload_offset += row_len + 1;
    }

    const encoded = try encodeZlibStoredSplitAlloc(std.testing.allocator, &filtered_payload, 7);
    defer std.testing.allocator.free(encoded);
    var filtered_row_scratch: [row_len]u8 = undefined;
    var previous_row_scratch: [row_len]u8 = undefined;
    const info = try pngImageInfo(row_len / bpp, row_count, 8, .truecolor);

    var image: [expected_image.len]u8 = undefined;
    const result = try decodePngStoredZlibImage(encoded, &filtered_row_scratch, &previous_row_scratch, info, &image);
    try std.testing.expectEqual(row_count, result.rows);
    try std.testing.expectEqual(expected_image.len, result.output_written);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);

    const chunks = [_][]const u8{
        encoded[0..1],
        encoded[1..1],
        encoded[1..5],
        encoded[5..5],
        encoded[5 .. encoded.len - 4],
        encoded[encoded.len - 4 ..],
        encoded[encoded.len..],
    };
    @memset(&image, 0);
    const chunked_result = try decodePngStoredZlibImageFromChunksDirect(&chunks, &filtered_row_scratch, &previous_row_scratch, info, &image);
    try std.testing.expectEqual(row_count, chunked_result.rows);
    try std.testing.expectEqual(expected_image.len, chunked_result.output_written);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);

    var decoder = try PngStoredZlibScanlineDecoder.initWithInfo(encoded, &filtered_row_scratch, &previous_row_scratch, info);
    var row: [row_len]u8 = undefined;
    for (0..row_count) |row_index| {
        const step = try decoder.step(&row);
        try std.testing.expectEqual(@as(u8, @intCast(row_index)), step.filter.?);
        try std.testing.expectEqual(row_index, step.row_index);
        try std.testing.expectEqual(row_len, step.row_bytes);
        try std.testing.expectEqualSlices(u8, &rows[row_index], &row);
    }
    try std.testing.expect(decoder.snapshot().done);
    try std.testing.expectEqual(core.StepResult.Status.done, (try decoder.step(row[0..0])).status);

    var chunked_decoder = try PngStoredZlibChunkedScanlineDecoder.initWithInfoAndOptions(&chunks, &filtered_row_scratch, &previous_row_scratch, info, .{});
    for (0..row_count) |row_index| {
        const step = try chunked_decoder.step(&row);
        try std.testing.expectEqual(@as(u8, @intCast(row_index)), step.filter.?);
        try std.testing.expectEqual(row_index, step.row_index);
        try std.testing.expectEqualSlices(u8, &rows[row_index], &row);
    }
    try std.testing.expect(chunked_decoder.snapshot().done);

    try std.testing.expectError(error.OutputTooSmall, PngStoredZlibScanlineDecoder.initWithInfo(encoded, filtered_row_scratch[0 .. row_len - 1], &previous_row_scratch, info));
    var too_tall_image: [(row_count + 1) * row_len]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, decodePngStoredZlibImage(encoded, &filtered_row_scratch, &previous_row_scratch, try pngImageInfo(row_len / bpp, row_count + 1, 8, .truecolor), &too_tall_image));

    var bad_adler = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_adler);
    bad_adler[bad_adler.len - 1] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodePngStoredZlibImage(bad_adler, &filtered_row_scratch, &previous_row_scratch, info, &image));
    _ = try decodePngStoredZlibImageWithOptions(bad_adler, &filtered_row_scratch, &previous_row_scratch, info, .{ .ignore_adler = true }, &image);
    const bad_adler_chunks = [_][]const u8{ bad_adler[0..2], bad_adler[2..] };
    try std.testing.expectError(error.ChecksumMismatch, decodePngStoredZlibImageFromChunksDirect(&bad_adler_chunks, &filtered_row_scratch, &previous_row_scratch, info, &image));
    _ = try decodePngStoredZlibImageFromChunksWithOptionsDirect(&bad_adler_chunks, &filtered_row_scratch, &previous_row_scratch, info, .{ .ignore_adler = true }, &image);

    const dynamic = try encodeZlibBestAlloc(std.testing.allocator, &filtered_payload, optionsForLevel(.default));
    defer std.testing.allocator.free(dynamic);
    try std.testing.expectError(error.InvalidDeflateBlockType, decodePngStoredZlibImage(dynamic, &filtered_row_scratch, &previous_row_scratch, info, &image));
    const dynamic_chunks = [_][]const u8{ dynamic[0..3], dynamic[3..] };
    try std.testing.expectError(error.InvalidDeflateBlockType, decodePngStoredZlibImageFromChunksDirect(&dynamic_chunks, &filtered_row_scratch, &previous_row_scratch, info, &image));
}

test "png streaming zlib scanline decoder reconstructs fixed and dynamic rows without zlib scratch" {
    const bpp = 3;
    const row_len = 12;
    const row_count = 5;
    var rows: [row_count][row_len]u8 = undefined;
    var expected_image: [row_count * row_len]u8 = undefined;
    var filtered_payload: [row_count * (row_len + 1)]u8 = undefined;

    var payload_offset: usize = 0;
    var image_offset: usize = 0;
    var previous: ?[]const u8 = null;
    for (0..row_count) |row_index| {
        rows[row_index] = pngReconstructionRow(row_len, row_index);
        @memcpy(expected_image[image_offset..][0..row_len], &rows[row_index]);
        image_offset += row_len;
        const filter: u8 = @intCast(row_index);
        filtered_payload[payload_offset] = filter;
        filterPngScanlineForTest(filter, &rows[row_index], previous, bpp, filtered_payload[payload_offset + 1 ..][0..row_len]);
        previous = &rows[row_index];
        payload_offset += row_len + 1;
    }

    const fixed = try encodeZlibFixedWithOptionsAlloc(std.testing.allocator, &filtered_payload, optionsForLevel(.default));
    defer std.testing.allocator.free(fixed);
    const dynamic = try encodeZlibDynamicWithOptionsAlloc(std.testing.allocator, &filtered_payload, optionsForLevel(.default));
    defer std.testing.allocator.free(dynamic);
    const info = try pngImageInfo(row_len / bpp, row_count, 8, .truecolor);

    const cases = [_][]const u8{ fixed, dynamic };
    for (cases) |encoded| {
        const chunks = [_][]const u8{
            encoded[0..1],
            encoded[1..2],
            encoded[2 .. encoded.len - 5],
            encoded[encoded.len - 5 .. encoded.len - 1],
            encoded[encoded.len - 1 ..],
        };
        var history_scratch: [PngStreamingZlibScanlineDecoder.history_scratch_len]u8 = undefined;
        var chunked_history_scratch: [PngStreamingZlibChunkedScanlineDecoder.history_scratch_len]u8 = undefined;
        var filtered_row_scratch: [row_len]u8 = undefined;
        var previous_row_scratch: [row_len]u8 = undefined;
        var output: [row_len]u8 = undefined;
        var decoder = try PngStreamingZlibScanlineDecoder.initWithInfo(encoded, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info);
        for (0..row_count) |row_index| {
            const step = try decoder.step(&output);
            try std.testing.expectEqual(@as(u8, @intCast(row_index)), step.filter.?);
            try std.testing.expectEqual(row_index, step.row_index);
            try std.testing.expectEqual(row_len, step.row_bytes);
            try std.testing.expectEqual(row_index + 1, step.rows_done);
            try std.testing.expectEqualSlices(u8, &rows[row_index], &output);
            if (row_index + 1 == row_count) {
                try std.testing.expectEqual(core.StepResult.Status.done, step.status);
                try std.testing.expectEqual(encoded.len, step.progress.input_read);
            } else {
                try std.testing.expectEqual(core.StepResult.Status.need_output, step.status);
                try std.testing.expectEqual(@as(usize, 0), step.progress.input_read);
            }
        }
        try std.testing.expect(decoder.snapshot().done);
        try std.testing.expectEqual(encoded.len, decoder.snapshot().input_read);
        try std.testing.expectEqual(filtered_payload.len, decoder.snapshot().history_len);
        try std.testing.expectEqual(core.StepResult.Status.done, (try decoder.step(output[0..0])).status);

        var chunked_filtered_row_scratch: [row_len]u8 = undefined;
        var chunked_previous_row_scratch: [row_len]u8 = undefined;
        var chunked_decoder = try PngStreamingZlibChunkedScanlineDecoder.initWithInfo(&chunks, &chunked_history_scratch, &chunked_filtered_row_scratch, &chunked_previous_row_scratch, info);
        for (0..row_count) |row_index| {
            const step = try chunked_decoder.step(&output);
            try std.testing.expectEqual(@as(u8, @intCast(row_index)), step.filter.?);
            try std.testing.expectEqual(row_index, step.row_index);
            try std.testing.expectEqual(row_len, step.row_bytes);
            try std.testing.expectEqualSlices(u8, &rows[row_index], &output);
            if (row_index + 1 == row_count) {
                try std.testing.expectEqual(core.StepResult.Status.done, step.status);
                try std.testing.expectEqual(encoded.len, step.progress.input_read);
            } else {
                try std.testing.expectEqual(core.StepResult.Status.need_output, step.status);
                try std.testing.expectEqual(@as(usize, 0), step.progress.input_read);
            }
        }
        try std.testing.expect(chunked_decoder.snapshot().done);
        try std.testing.expectEqual(encoded.len, chunked_decoder.snapshot().input_read);
        try std.testing.expectEqual(filtered_payload.len, chunked_decoder.snapshot().history_len);
        try std.testing.expectEqual(core.StepResult.Status.done, (try chunked_decoder.step(output[0..0])).status);

        var image: [expected_image.len]u8 = undefined;
        const result = try decodePngStreamingZlibImage(encoded, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image);
        try std.testing.expectEqual(row_count, result.rows);
        try std.testing.expectEqual(expected_image.len, result.output_written);
        try std.testing.expectEqual(encoded.len, result.zlib_input_read);
        try std.testing.expectEqualSlices(u8, &expected_image, &image);

        var no_copy_filtered_row_scratch: [row_len]u8 = @splat(0xa5);
        var no_copy_previous_row_scratch: [row_len]u8 = @splat(0x5a);
        var no_copy_image: [expected_image.len]u8 = undefined;
        _ = try decodePngStreamingZlibImage(encoded, &history_scratch, &no_copy_filtered_row_scratch, &no_copy_previous_row_scratch, info, &no_copy_image);
        try std.testing.expectEqualSlices(u8, &expected_image, &no_copy_image);
        try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** row_len), &no_copy_filtered_row_scratch);
        try std.testing.expectEqualSlices(u8, &([_]u8{0x5a} ** row_len), &no_copy_previous_row_scratch);

        @memset(&image, 0);
        const chunked_result = try decodePngStreamingZlibImageFromChunksDirect(&chunks, &chunked_history_scratch, &chunked_filtered_row_scratch, &chunked_previous_row_scratch, info, &image);
        try std.testing.expectEqual(result.rows, chunked_result.rows);
        try std.testing.expectEqual(result.output_written, chunked_result.output_written);
        try std.testing.expectEqual(encoded.len, chunked_result.zlib_input_read);
        try std.testing.expectEqualSlices(u8, &expected_image, &image);

        var no_copy_chunked_filtered_row_scratch: [row_len]u8 = @splat(0xc3);
        var no_copy_chunked_previous_row_scratch: [row_len]u8 = @splat(0x3c);
        @memset(&no_copy_image, 0);
        _ = try decodePngStreamingZlibImageFromChunksDirect(&chunks, &chunked_history_scratch, &no_copy_chunked_filtered_row_scratch, &no_copy_chunked_previous_row_scratch, info, &no_copy_image);
        try std.testing.expectEqualSlices(u8, &expected_image, &no_copy_image);
        try std.testing.expectEqualSlices(u8, &([_]u8{0xc3} ** row_len), &no_copy_chunked_filtered_row_scratch);
        try std.testing.expectEqualSlices(u8, &([_]u8{0x3c} ** row_len), &no_copy_chunked_previous_row_scratch);

        var zlib_scratch: [filtered_payload.len]u8 = undefined;
        var classic_image: [expected_image.len]u8 = undefined;
        const classic = try decodePngZlibImage(encoded, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &classic_image);
        try std.testing.expectEqual(classic.output_written, result.output_written);
        try std.testing.expectEqualSlices(u8, &classic_image, &image);

        var no_copy_classic_filtered_row_scratch: [row_len]u8 = @splat(0x96);
        var no_copy_classic_previous_row_scratch: [row_len]u8 = @splat(0x69);
        _ = try decodePngZlibImage(encoded, &zlib_scratch, &no_copy_classic_filtered_row_scratch, &no_copy_classic_previous_row_scratch, info, &no_copy_image);
        try std.testing.expectEqualSlices(u8, &expected_image, &no_copy_image);
        try std.testing.expectEqualSlices(u8, &([_]u8{0x96} ** row_len), &no_copy_classic_filtered_row_scratch);
        try std.testing.expectEqualSlices(u8, &([_]u8{0x69} ** row_len), &no_copy_classic_previous_row_scratch);
    }

    const match_row_len = 64;
    const match_row_count = 12;
    var match_payload: [match_row_count * (match_row_len + 1)]u8 = @splat(0);
    const match_info = try pngImageInfo(match_row_len, match_row_count, 8, .grayscale);
    const match_cases = [_][]const u8{
        try encodeZlibFixedWithOptionsAlloc(std.testing.allocator, &match_payload, optionsForLevel(.default)),
        try encodeZlibDynamicWithOptionsAlloc(std.testing.allocator, &match_payload, optionsForLevel(.default)),
    };
    defer {
        for (match_cases) |encoded| std.testing.allocator.free(encoded);
    }
    for (match_cases) |encoded| {
        try std.testing.expect(encoded.len < match_payload.len);
        const chunks = [_][]const u8{
            encoded[0..3],
            encoded[3 .. encoded.len - 4],
            encoded[encoded.len - 4 ..],
        };
        var history_scratch: [PngStreamingZlibScanlineDecoder.history_scratch_len]u8 = undefined;
        var chunked_history_scratch: [PngStreamingZlibChunkedScanlineDecoder.history_scratch_len]u8 = undefined;
        var match_filtered_row_scratch: [match_row_len]u8 = undefined;
        var match_previous_row_scratch: [match_row_len]u8 = undefined;
        var match_image: [match_row_count * match_row_len]u8 = undefined;
        const result = try decodePngStreamingZlibImage(encoded, &history_scratch, &match_filtered_row_scratch, &match_previous_row_scratch, match_info, &match_image);
        try std.testing.expectEqual(match_image.len, result.output_written);
        try std.testing.expectEqualSlices(u8, &([_]u8{0} ** match_image.len), &match_image);
        @memset(&match_image, 0xff);
        const chunked_result = try decodePngStreamingZlibImageFromChunksDirect(&chunks, &chunked_history_scratch, &match_filtered_row_scratch, &match_previous_row_scratch, match_info, &match_image);
        try std.testing.expectEqual(result.output_written, chunked_result.output_written);
        try std.testing.expectEqualSlices(u8, &([_]u8{0} ** match_image.len), &match_image);
    }

    var short_history: [PngStreamingZlibScanlineDecoder.history_scratch_len - 1]u8 = undefined;
    var short_chunked_history: [PngStreamingZlibChunkedScanlineDecoder.history_scratch_len - 1]u8 = undefined;
    var filtered_row_scratch: [row_len]u8 = undefined;
    var previous_row_scratch: [row_len]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, PngStreamingZlibScanlineDecoder.initWithInfo(dynamic, &short_history, &filtered_row_scratch, &previous_row_scratch, info));
    const dynamic_chunks = [_][]const u8{ dynamic[0..3], dynamic[3..] };
    try std.testing.expectError(error.OutputTooSmall, PngStreamingZlibChunkedScanlineDecoder.initWithInfo(&dynamic_chunks, &short_chunked_history, &filtered_row_scratch, &previous_row_scratch, info));

    var small_step_history: [PngStreamingZlibScanlineDecoder.history_scratch_len]u8 = undefined;
    var small_step_decoder = try PngStreamingZlibScanlineDecoder.initWithInfo(dynamic, &small_step_history, &filtered_row_scratch, &previous_row_scratch, info);
    var short_output: [row_len - 1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, small_step_decoder.step(&short_output));
    try std.testing.expectEqualStrings("OutputTooSmall", small_step_decoder.diagnostics().last_error_name);
}

test "png streaming zlib decoder batches pending matches into row buffers" {
    const Case = struct {
        name: []const u8,
        history: []const u8,
        distance: usize,
        pending: usize,
        output_len: usize,
        expected: []const u8,
    };
    const cases = [_]Case{
        .{ .name = "rle", .history = "Z", .distance = 1, .pending = 10, .output_len = 6, .expected = "ZZZZZZ" },
        .{ .name = "small-distance", .history = "AB", .distance = 2, .pending = 7, .output_len = 7, .expected = "ABABABA" },
        .{ .name = "history-copy", .history = "abcdef", .distance = 5, .pending = 3, .output_len = 3, .expected = "bcd" },
        .{ .name = "overlap", .history = "abcde", .distance = 5, .pending = 8, .output_len = 8, .expected = "abcdeabc" },
        .{ .name = "ring-wrap-overlap", .history = "abcde", .distance = 5, .pending = 11, .output_len = 11, .expected = "abcdeabcdea" },
    };

    for (cases) |case| {
        var history_scratch: [32]u8 = @splat(0);
        const history_pos = if (std.mem.eql(u8, case.name, "ring-wrap-overlap")) history_scratch.len - 2 else case.history.len;
        for (case.history, 0..) |byte, i| {
            history_scratch[(history_pos + history_scratch.len - case.history.len + i) % history_scratch.len] = byte;
        }
        var decoder = PngStreamingZlibScanlineDecoder{
            .history = &history_scratch,
            .history_pos = history_pos,
            .history_len = case.history.len,
            .pending_match_remaining = case.pending,
            .pending_match_distance = case.distance,
        };
        var output: [16]u8 = @splat(0);
        try decoder.readInflatedBytes(output[0..case.output_len]);
        try std.testing.expectEqualSlices(u8, case.expected, output[0..case.output_len]);
        try std.testing.expectEqual(case.pending - case.output_len, decoder.pending_match_remaining);

        var expected_adler = checksum.Adler32.init();
        expected_adler.update(case.expected);
        try std.testing.expectEqual(expected_adler.digest(), decoder.adler.digest());
        try std.testing.expect(decoder.history_len >= case.history.len);
        try std.testing.expect(decoder.history_pos < decoder.history.len);
    }
}

test "png streaming repeated byte recording matches Adler and retained history" {
    var history_scratch: [8]u8 = @splat(0);
    var decoder = PngStreamingZlibScanlineDecoder{
        .history = &history_scratch,
        .history_pos = 3,
        .history_len = 1,
    };

    var expected_bytes: [6000]u8 = @splat('Q');
    recordPngStreamingRepeatedByte(&decoder, 'Q', expected_bytes.len);

    var expected_adler = checksum.Adler32.init();
    expected_adler.update(&expected_bytes);
    decoder.reduceAdler();
    try std.testing.expectEqual(expected_adler.digest(), decoder.adler.digest());
    try std.testing.expectEqual(@as(usize, history_scratch.len), decoder.history_len);
    try std.testing.expectEqual(@as(usize, (3 + expected_bytes.len) % history_scratch.len), decoder.history_pos);
    for (history_scratch) |byte| try std.testing.expectEqual(@as(u8, 'Q'), byte);
}

test "png streaming history recording keeps only retained tail window" {
    var history_scratch: [8]u8 = @splat(0);
    var decoder = PngStreamingZlibScanlineDecoder{
        .history = &history_scratch,
        .history_pos = 3,
        .history_len = 2,
    };
    decoder.recordHistoryBytes("0123456789abcdef");

    try std.testing.expectEqual(@as(usize, history_scratch.len), decoder.history_len);
    try std.testing.expectEqual(@as(usize, (3 + 16) % history_scratch.len), decoder.history_pos);
    const tail = "89abcdef";
    for (tail, 0..) |expected, i| {
        const distance = tail.len - i;
        try std.testing.expectEqual(expected, try decoder.historyByte(distance));
    }

    var chunked_history_scratch: [8]u8 = @splat(0);
    var chunked = PngStreamingZlibChunkedScanlineDecoder{
        .history = &chunked_history_scratch,
        .history_pos = 5,
        .history_len = 1,
    };
    chunked.recordHistoryBytes("abcdefghijkl");

    try std.testing.expectEqual(@as(usize, chunked_history_scratch.len), chunked.history_len);
    try std.testing.expectEqual(@as(usize, (5 + 12) % chunked_history_scratch.len), chunked.history_pos);
    const chunked_tail = "efghijkl";
    for (chunked_tail, 0..) |expected, i| {
        const distance = chunked_tail.len - i;
        try std.testing.expectEqual(expected, try chunked.historyByte(distance));
    }
}

test "png streaming zlib scanline decoder reports wrapper and logical errors" {
    const info = try pngImageInfo(1, 1, 8, .grayscale);
    var history_scratch: [PngStreamingZlibScanlineDecoder.history_scratch_len]u8 = undefined;
    var filtered_row_scratch: [1]u8 = undefined;
    var previous_row_scratch: [1]u8 = undefined;
    var image: [1]u8 = undefined;

    const payload = [_]u8{ 0, 0x42 };
    const encoded = try encodeZlibDynamicWithOptionsAlloc(std.testing.allocator, &payload, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);

    var bad_adler = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_adler);
    bad_adler[bad_adler.len - 1] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodePngStreamingZlibImage(bad_adler, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
    _ = try decodePngStreamingZlibImageWithOptions(bad_adler, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, .{ .ignore_adler = true }, &image);

    var trailing = try std.testing.allocator.alloc(u8, encoded.len + 1);
    defer std.testing.allocator.free(trailing);
    @memcpy(trailing[0..encoded.len], encoded);
    trailing[encoded.len] = 0;
    try std.testing.expectError(error.TrailingData, decodePngStreamingZlibImage(trailing, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
    _ = try decodePngStreamingZlibImageWithOptions(trailing, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, .{ .allow_trailing_data = true }, &image);

    try std.testing.expectError(error.TruncatedFrame, decodePngStreamingZlibImage(encoded[0 .. encoded.len - 2], &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));

    const bad_filter_payload = [_]u8{ 5, 0x42 };
    const bad_filter = try encodeZlibDynamicWithOptionsAlloc(std.testing.allocator, &bad_filter_payload, optionsForLevel(.default));
    defer std.testing.allocator.free(bad_filter);
    try std.testing.expectError(error.CorruptFrame, decodePngStreamingZlibImage(bad_filter, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));

    var bad_header = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_header);
    bad_header[0] = 0;
    try std.testing.expectError(error.BadZlibHeader, PngStreamingZlibScanlineDecoder.initWithInfo(bad_header, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info));
    const bad_header_chunks = [_][]const u8{ bad_header[0..1], bad_header[1..] };
    try std.testing.expectError(error.BadZlibHeader, PngStreamingZlibChunkedScanlineDecoder.initWithInfo(&bad_header_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info));

    const chunks = [_][]const u8{
        encoded[0..1],
        encoded[1..3],
        encoded[3 .. encoded.len - 4],
        encoded[encoded.len - 4 ..],
    };
    const bad_adler_chunks = [_][]const u8{ bad_adler[0..2], bad_adler[2..] };
    try std.testing.expectError(error.ChecksumMismatch, decodePngStreamingZlibImageFromChunksDirect(&bad_adler_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
    _ = try decodePngStreamingZlibImageFromChunksWithOptionsDirect(&bad_adler_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, .{ .ignore_adler = true }, &image);
    const trailing_chunks = [_][]const u8{ trailing[0..2], trailing[2 .. trailing.len - 1], trailing[trailing.len - 1 ..] };
    try std.testing.expectError(error.TrailingData, decodePngStreamingZlibImageFromChunksDirect(&trailing_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
    _ = try decodePngStreamingZlibImageFromChunksWithOptionsDirect(&trailing_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, .{ .allow_trailing_data = true }, &image);
    const truncated_chunks = [_][]const u8{encoded[0 .. encoded.len - 2]};
    try std.testing.expectError(error.TruncatedFrame, decodePngStreamingZlibImageFromChunksDirect(&truncated_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));
    const bad_filter_chunks = [_][]const u8{ bad_filter[0 .. bad_filter.len / 2], bad_filter[bad_filter.len / 2 ..] };
    try std.testing.expectError(error.CorruptFrame, decodePngStreamingZlibImageFromChunksDirect(&bad_filter_chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image));

    var chunked_decoder = try PngStreamingZlibChunkedScanlineDecoder.initWithInfo(&chunks, &history_scratch, &filtered_row_scratch, &previous_row_scratch, info);
    var short_output: [0]u8 = .{};
    try std.testing.expectError(error.OutputTooSmall, chunked_decoder.step(&short_output));
    try std.testing.expectEqualStrings("OutputTooSmall", chunked_decoder.diagnostics().last_error_name);
}

test "png zlib image helper reconstructs full image from IDAT chunks" {
    const bpp = 3;
    const row_len = 12;
    const row_count = 5;
    var rows: [row_count][row_len]u8 = undefined;
    var expected_image: [row_count * row_len]u8 = undefined;
    var filtered_payload: [row_count * (row_len + 1)]u8 = undefined;

    var payload_offset: usize = 0;
    var image_offset: usize = 0;
    var previous: ?[]const u8 = null;
    for (0..row_count) |row_index| {
        rows[row_index] = pngReconstructionRow(row_len, row_index);
        @memcpy(expected_image[image_offset..][0..row_len], &rows[row_index]);
        image_offset += row_len;
        const filter: u8 = @intCast(row_index);
        filtered_payload[payload_offset] = filter;
        filterPngScanlineForTest(filter, &rows[row_index], previous, bpp, filtered_payload[payload_offset + 1 ..][0..row_len]);
        previous = &rows[row_index];
        payload_offset += row_len + 1;
    }

    const encoded = try encodeZlibBestAlloc(std.testing.allocator, &filtered_payload, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..5],
        encoded[5 .. encoded.len - 4],
        encoded[encoded.len - 4 ..],
    };
    var compressed_scratch: [256]u8 = undefined;
    var zlib_scratch: [filtered_payload.len]u8 = undefined;
    var filtered_row_scratch: [row_len]u8 = undefined;
    var previous_row_scratch: [row_len]u8 = undefined;
    const info = try pngImageInfo(row_len / bpp, row_count, 8, .truecolor);
    var image: [expected_image.len]u8 = undefined;
    const result = try decodePngZlibImageFromChunks(&chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image);
    try std.testing.expectEqual(row_count, result.rows);
    try std.testing.expectEqual(expected_image.len, result.output_written);
    try std.testing.expectEqual(encoded.len, result.zlib_input_read);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);
    @memset(&image, 0);
    const direct_result = try decodePngZlibImageFromChunksDirect(&chunks, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image);
    try std.testing.expectEqual(row_count, direct_result.rows);
    try std.testing.expectEqual(expected_image.len, direct_result.output_written);
    try std.testing.expectEqual(encoded.len, direct_result.zlib_input_read);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);
    @memset(&image, 0);
    const direct_options_result = try decodePngZlibImageFromChunksWithOptionsDirect(&chunks, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, .{}, &image);
    try std.testing.expectEqual(direct_result.rows, direct_options_result.rows);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);

    var single_image: [expected_image.len]u8 = undefined;
    const single = try decodePngZlibImage(encoded, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &single_image);
    try std.testing.expectEqualSlices(u8, &expected_image, &single_image);
    try std.testing.expectEqual(encoded.len, single.zlib_input_read);
    @memset(&single_image, 0);
    const single_options = try decodePngZlibImageWithOptions(encoded, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, .{}, &single_image);
    try std.testing.expectEqual(single.rows, single_options.rows);
    try std.testing.expectEqualSlices(u8, &expected_image, &single_image);

    var bad_adler = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_adler);
    bad_adler[bad_adler.len - 1] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodePngZlibImage(bad_adler, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &single_image));
    _ = try decodePngZlibImageWithOptions(bad_adler, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, .{ .ignore_adler = true }, &single_image);

    try std.testing.expectError(error.OutputTooSmall, decodePngZlibImageFromChunks(&chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, image[0 .. image.len - 1]));
    var too_tall_image: [(row_count + 1) * row_len]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, decodePngZlibImageFromChunks(&chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, try pngImageInfo(row_len / bpp, row_count + 1, 8, .truecolor), &too_tall_image));
}

test "png zlib image helper covers sub-byte indexed rows" {
    const info = try pngImageInfo(13, 3, 1, .indexed);
    const sizes = try pngZlibDecodeBufferSizes(info);
    try std.testing.expectEqual(@as(usize, 2), info.row_len);
    try std.testing.expectEqual(@as(usize, 1), info.bytes_per_pixel);
    try std.testing.expectEqual(@as(usize, 9), info.zlib_payload_len);
    try std.testing.expectEqual(@as(usize, 6), sizes.image_output_len);

    const filtered_payload = [_]u8{
        0, 0b1010_1010, 0b1000_0000,
        1, 0b0000_1111, 0b1111_0000,
        2, 0b0011_0011, 0b0101_0101,
    };
    const expected_image = [_]u8{
        0b1010_1010, 0b1000_0000,
        0b0000_1111, 0b1111_1111,
        0b0100_0010, 0b0101_0100,
    };
    const encoded = try encodeZlibBestAlloc(std.testing.allocator, &filtered_payload, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..4],
        encoded[4 .. encoded.len - 2],
        encoded[encoded.len - 2 ..],
    };
    try std.testing.expectEqual(encoded.len, try pngIdatChunksScratchLen(&chunks));

    var compressed_scratch: [128]u8 = undefined;
    var zlib_scratch: [filtered_payload.len]u8 = undefined;
    var filtered_row_scratch: [2]u8 = undefined;
    var previous_row_scratch: [2]u8 = undefined;
    var image: [expected_image.len]u8 = undefined;
    const result = try decodePngZlibImageFromChunks(&chunks, &compressed_scratch, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image);
    try std.testing.expectEqual(@as(usize, 3), result.rows);
    try std.testing.expectEqual(expected_image.len, result.output_written);
    try std.testing.expectEqual(encoded.len, result.zlib_input_read);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);
    @memset(&image, 0);
    const direct_result = try decodePngZlibImageFromChunksDirect(&chunks, &zlib_scratch, &filtered_row_scratch, &previous_row_scratch, info, &image);
    try std.testing.expectEqual(@as(usize, 3), direct_result.rows);
    try std.testing.expectEqualSlices(u8, &expected_image, &image);
}

test "zlib decoder supports preset dictionary streams" {
    const dict = "hello ";
    const input = "hello hello hello";
    const encoded = try encodeZlibBestWithDictionaryAlloc(std.testing.allocator, input, dict, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    var scratch: [input.len]u8 = undefined;
    var decoder = try ZlibDecoder.initWithDictionaryExactSize(encoded, dict, &scratch, input.len);
    var out: [input.len]u8 = undefined;
    const step = try decoder.step(&out);
    try std.testing.expectEqual(core.StepResult.Status.done, step.status);
    try std.testing.expectEqualSlices(u8, input, &out);

    var compressed_scratch: [256]u8 = undefined;
    const chunks = [_][]const u8{
        encoded[0..6],
        encoded[6 .. encoded.len - 2],
        encoded[encoded.len - 2 ..],
    };
    var chunk_decoder = try ZlibDecoder.initFromChunksWithDictionaryExactSize(&chunks, dict, &compressed_scratch, &scratch, input.len);
    @memset(&out, 0);
    const chunk_step = try chunk_decoder.step(&out);
    try std.testing.expectEqual(core.StepResult.Status.done, chunk_step.status);
    try std.testing.expectEqual(encoded.len, chunk_step.progress.input_read);
    try std.testing.expectEqualSlices(u8, input, &out);
    try std.testing.expectError(error.OutputTooSmall, ZlibDecoder.initFromChunksWithDictionaryExactSize(&chunks, dict, compressed_scratch[0 .. encoded.len - 1], &scratch, input.len));

    var direct_chunk_decoder = try ZlibDecoder.initFromChunksWithDictionaryExactSizeDirect(&chunks, dict, &scratch, input.len);
    @memset(&out, 0);
    const direct_chunk_step = try direct_chunk_decoder.step(&out);
    try std.testing.expectEqual(core.StepResult.Status.done, direct_chunk_step.status);
    try std.testing.expectEqual(encoded.len, direct_chunk_step.progress.input_read);
    try std.testing.expectEqualSlices(u8, input, &out);

    const header_only_chunks = [_][]const u8{ encoded[0..3], encoded[3..6] };
    try std.testing.expectError(error.TruncatedFrame, ZlibDecoder.initFromChunksWithDictionaryExactSizeDirect(&header_only_chunks, dict, &scratch, input.len));
    var reserved_frame: [7]u8 = undefined;
    @memcpy(reserved_frame[0..6], encoded[0..6]);
    reserved_frame[6] = 0x07;
    const reserved_chunks = [_][]const u8{ reserved_frame[0..3], reserved_frame[3..] };
    try std.testing.expectError(error.InvalidDeflateBlockType, ZlibDecoder.initFromChunksWithDictionaryExactSizeDirect(&reserved_chunks, dict, &scratch, input.len));

    try std.testing.expectError(error.SizeMismatch, ZlibDecoder.initWithDictionaryExactSize(encoded, dict, &scratch, input.len - 1));
    try std.testing.expectError(error.NeedDictionary, ZlibDecoder.init(encoded, &scratch));
}

test "zlib chunked one-shot helpers cover relaxed and dictionary paths" {
    const input = "chunked zlib payload";
    const encoded = try encodeZlibLevelAlloc(std.testing.allocator, input, 6);
    defer std.testing.allocator.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..2],
        encoded[2 .. encoded.len - 4],
        encoded[encoded.len - 4 ..],
    };
    const footer_split_chunks = [_][]const u8{
        encoded[0..2],
        encoded[2 .. encoded.len - 4],
        encoded[encoded.len - 4 .. encoded.len - 2],
        encoded[encoded.len - 2 .. encoded.len - 2],
        encoded[encoded.len - 2 .. encoded.len - 1],
        encoded[encoded.len - 1 ..],
    };
    const empty_chunks = [_][]const u8{
        encoded[0..0],
        encoded[0..1],
        encoded[1..1],
        encoded[1..2],
        encoded[2..2],
        encoded[2 .. encoded.len - 4],
        encoded[encoded.len - 4 .. encoded.len - 4],
        encoded[encoded.len - 4 ..],
        encoded[encoded.len..encoded.len],
    };
    var compressed_scratch: [128]u8 = undefined;
    var output: [input.len]u8 = undefined;
    try std.testing.expectEqual(input.len, try decodeZlibChunks(&chunks, &compressed_scratch, &output));
    try std.testing.expectEqualSlices(u8, input, &output);
    const single_chunk = [_][]const u8{
        encoded[0..0],
        encoded,
        encoded[encoded.len..],
    };
    var no_compressed_scratch: [0]u8 = .{};
    @memset(&output, 0);
    try std.testing.expectEqual(input.len, try decodeZlibChunks(&single_chunk, &no_compressed_scratch, &output));
    try std.testing.expectEqualSlices(u8, input, &output);
    @memset(&output, 0);
    try std.testing.expectEqual(input.len, try decodeZlibChunksInto(&chunks, &output));
    try std.testing.expectEqualSlices(u8, input, &output);
    @memset(&output, 0);
    try std.testing.expectEqual(input.len, try decodeZlibChunksInto(&footer_split_chunks, &output));
    try std.testing.expectEqualSlices(u8, input, &output);
    @memset(&output, 0);
    try std.testing.expectEqual(input.len, try decodeZlibChunks(&empty_chunks, &compressed_scratch, &output));
    try std.testing.expectEqualSlices(u8, input, &output);
    @memset(&output, 0);
    try std.testing.expectEqual(input.len, try decodeZlibChunksInto(&empty_chunks, &output));
    try std.testing.expectEqualSlices(u8, input, &output);
    var short_output: [input.len - 1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodeZlibChunksInto(&chunks, &short_output));

    const alloc = try decodeZlibChunksAlloc(std.testing.allocator, &chunks);
    defer std.testing.allocator.free(alloc);
    try std.testing.expectEqualSlices(u8, input, alloc);
    const footer_split_alloc = try decodeZlibChunksAlloc(std.testing.allocator, &footer_split_chunks);
    defer std.testing.allocator.free(footer_split_alloc);
    try std.testing.expectEqualSlices(u8, input, footer_split_alloc);

    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 2 });
    const direct_alloc = try decodeZlibChunksAlloc(failing.allocator(), &chunks);
    defer failing.allocator().free(direct_alloc);
    try std.testing.expectEqualSlices(u8, input, direct_alloc);
    // Unknown-size allocation still grows/shrinks the output buffer, but the
    // chunked path must not spend an additional heap allocation joining the
    // compressed zlib chunks before inflate.
    try std.testing.expectEqual(@as(usize, 2), failing.allocations);

    const exact = try decodeZlibChunksAllocExactSize(std.testing.allocator, &chunks, input.len);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, input, exact);

    var bad_chunk_header = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_chunk_header);
    bad_chunk_header[1] ^= 1;
    const bad_header_chunks = [_][]const u8{
        bad_chunk_header[0..1],
        bad_chunk_header[1..],
    };
    var bad_header_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.BadZlibHeader, decodeZlibChunksAllocExactSize(bad_header_failing.allocator(), &bad_header_chunks, input.len));
    try std.testing.expectEqual(@as(usize, 0), bad_header_failing.allocations);

    const direct_header_only_chunks = [_][]const u8{ &.{0x78}, &.{0x01} };
    try std.testing.expectError(error.TruncatedFrame, ZlibDecoder.initFromChunksExactSizeDirect(&direct_header_only_chunks, &output, input.len));
    const direct_reserved_chunks = [_][]const u8{ &.{0x78}, &.{ 0x01, 0x07 } };
    try std.testing.expectError(error.InvalidDeflateBlockType, ZlibDecoder.initFromChunksExactSizeDirect(&direct_reserved_chunks, &output, input.len));

    const header_only_chunks = [_][]const u8{ &.{0x78}, &.{0x01} };
    var header_only_alloc_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TruncatedFrame, decodeZlibChunksAlloc(header_only_alloc_failing.allocator(), &header_only_chunks));
    try std.testing.expectEqual(@as(usize, 0), header_only_alloc_failing.allocations);
    var header_only_limited_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TruncatedFrame, decodeZlibChunksAllocLimited(header_only_limited_failing.allocator(), &header_only_chunks, input.len));
    try std.testing.expectEqual(@as(usize, 0), header_only_limited_failing.allocations);
    var header_only_exact_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TruncatedFrame, decodeZlibChunksAllocExactSize(header_only_exact_failing.allocator(), &header_only_chunks, input.len));
    try std.testing.expectEqual(@as(usize, 0), header_only_exact_failing.allocations);

    const reserved_chunks = [_][]const u8{ &.{0x78}, &.{ 0x01, 0x07 } };
    var reserved_alloc_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeZlibChunksAlloc(reserved_alloc_failing.allocator(), &reserved_chunks));
    try std.testing.expectEqual(@as(usize, 0), reserved_alloc_failing.allocations);
    var reserved_limited_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeZlibChunksAllocLimited(reserved_limited_failing.allocator(), &reserved_chunks, input.len));
    try std.testing.expectEqual(@as(usize, 0), reserved_limited_failing.allocations);
    var reserved_exact_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeZlibChunksAllocExactSize(reserved_exact_failing.allocator(), &reserved_chunks, input.len));
    try std.testing.expectEqual(@as(usize, 0), reserved_exact_failing.allocations);

    var exact_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    const direct_exact = try decodeZlibChunksAllocExactSize(exact_failing.allocator(), &chunks, input.len);
    defer exact_failing.allocator().free(direct_exact);
    try std.testing.expectEqualSlices(u8, input, direct_exact);
    try std.testing.expectEqual(@as(usize, 1), exact_failing.allocations);

    const limited = try decodeZlibChunksAllocLimited(std.testing.allocator, &chunks, input.len);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, input, limited);
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibChunksAllocLimited(std.testing.allocator, &chunks, input.len - 1));

    const stored = try encodeZlibStoredAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(stored);
    const stored_chunks = [_][]const u8{
        stored[0..3],
        stored[3 .. stored.len - 2],
        stored[stored.len - 2 ..],
    };
    const stored_single_chunk = [_][]const u8{
        stored[0..0],
        stored,
        stored[stored.len..],
    };
    var stored_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    const stored_direct = try decodeZlibChunksAllocExactSize(stored_failing.allocator(), &stored_chunks, input.len);
    defer stored_failing.allocator().free(stored_direct);
    try std.testing.expectEqualSlices(u8, input, stored_direct);
    try std.testing.expectEqual(@as(usize, 1), stored_failing.allocations);
    var stored_short_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.SizeMismatch, decodeZlibChunksAllocExactSize(stored_short_failing.allocator(), &stored_single_chunk, input.len - 1));
    try std.testing.expectEqual(@as(usize, 0), stored_short_failing.allocations);
    var bad_stored_adler = try std.testing.allocator.dupe(u8, stored);
    defer std.testing.allocator.free(bad_stored_adler);
    bad_stored_adler[bad_stored_adler.len - 1] ^= 1;
    const bad_stored_single_chunk = [_][]const u8{
        bad_stored_adler[0..0],
        bad_stored_adler,
        bad_stored_adler[bad_stored_adler.len..],
    };
    var stored_adler_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibChunksAllocExactSize(stored_adler_failing.allocator(), &bad_stored_single_chunk, input.len));
    try std.testing.expectEqual(@as(usize, 0), stored_adler_failing.allocations);
    var stored_adler_alloc_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibChunksAlloc(stored_adler_alloc_failing.allocator(), &bad_stored_single_chunk));
    try std.testing.expectEqual(@as(usize, 0), stored_adler_alloc_failing.allocations);
    var stored_limit_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibChunksAllocLimited(stored_limit_failing.allocator(), &stored_single_chunk, input.len - 1));
    try std.testing.expectEqual(@as(usize, 0), stored_limit_failing.allocations);
    var stored_chunked_limit_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibChunksAllocLimited(stored_chunked_limit_failing.allocator(), &stored_chunks, input.len - 1));
    try std.testing.expectEqual(@as(usize, 0), stored_chunked_limit_failing.allocations);
    const bad_stored_chunks = [_][]const u8{
        bad_stored_adler[0..3],
        bad_stored_adler[3 .. bad_stored_adler.len - 2],
        bad_stored_adler[bad_stored_adler.len - 2 ..],
    };
    var stored_chunked_adler_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibChunksAlloc(stored_chunked_adler_failing.allocator(), &bad_stored_chunks));
    try std.testing.expectEqual(@as(usize, 0), stored_chunked_adler_failing.allocations);

    @memset(&output, 0);
    try std.testing.expectEqual(input.len, try decodeZlibChunksInto(&stored_chunks, &output));
    try std.testing.expectEqualSlices(u8, input, &output);

    var relaxed_frame = try std.testing.allocator.alloc(u8, encoded.len + 1);
    defer std.testing.allocator.free(relaxed_frame);
    @memcpy(relaxed_frame[0..encoded.len], encoded);
    relaxed_frame[encoded.len - 1] ^= 1;
    relaxed_frame[encoded.len] = 0xaa;
    const relaxed_chunks = [_][]const u8{
        relaxed_frame[0..3],
        relaxed_frame[3 .. relaxed_frame.len - 1],
        relaxed_frame[relaxed_frame.len - 1 ..],
    };
    const relaxed = ZlibDecodeOptions{ .ignore_adler = true, .allow_trailing_data = true };
    try std.testing.expectEqual(input.len, try decodeZlibChunksWithOptions(&relaxed_chunks, &compressed_scratch, &output, relaxed));
    try std.testing.expectEqualSlices(u8, input, &output);
    @memset(&output, 0);
    try std.testing.expectEqual(input.len, try decodeZlibChunksIntoWithOptions(&relaxed_chunks, &output, relaxed));
    try std.testing.expectEqualSlices(u8, input, &output);
    const relaxed_alloc = try decodeZlibChunksAllocWithOptionsLimited(std.testing.allocator, &relaxed_chunks, relaxed, input.len);
    defer std.testing.allocator.free(relaxed_alloc);
    try std.testing.expectEqualSlices(u8, input, relaxed_alloc);

    var large_input: [70 * 1024]u8 = undefined;
    var state: u32 = 0x9e37_79b9;
    for (&large_input) |*byte| {
        state = state *% 1664525 +% 1013904223;
        byte.* = @truncate(state >> 24);
    }
    const large_frame = try encodeZlibFixedAlloc(std.testing.allocator, &large_input);
    defer std.testing.allocator.free(large_frame);
    try std.testing.expect(large_frame.len > stack_chunked_zlib_join_max_input_len);
    try std.testing.expectEqual(RawDeflateBlockType.fixed, (try parseRawDeflateHeaderInfo(large_frame[2..])).block_type);

    var large_bad_adler = try std.testing.allocator.dupe(u8, large_frame);
    defer std.testing.allocator.free(large_bad_adler);
    large_bad_adler[large_bad_adler.len - 1] ^= 0x80;
    const large_chunks = [_][]const u8{
        large_bad_adler[0..2],
        large_bad_adler[2..32771],
        large_bad_adler[32771 .. large_bad_adler.len - 4],
        large_bad_adler[large_bad_adler.len - 4 ..],
    };
    var large_output: [large_input.len]u8 = undefined;
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibChunksInto(&large_chunks, &large_output));
    @memset(&large_output, 0);
    // Keep this above the stack-join threshold so the direct chunked span reader,
    // not the contiguous stack buffer fallback, proves that relaxed callers avoid
    // the full-output Adler pass.
    try std.testing.expectEqual(large_input.len, try decodeZlibChunksIntoWithOptions(&large_chunks, &large_output, .{ .ignore_adler = true }));
    try std.testing.expectEqualSlices(u8, &large_input, &large_output);

    const dict = "chunked ";
    const dict_frame = try encodeZlibLevelWithDictionaryAlloc(std.testing.allocator, input, dict, 6);
    defer std.testing.allocator.free(dict_frame);
    const dict_chunks = [_][]const u8{
        dict_frame[0..6],
        dict_frame[6 .. dict_frame.len - 3],
        dict_frame[dict_frame.len - 3 ..],
    };
    const dict_header_only_chunks = [_][]const u8{ dict_frame[0..3], dict_frame[3..6] };
    var dict_header_only_alloc_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TruncatedFrame, decodeZlibChunksAllocWithDictionary(dict_header_only_alloc_failing.allocator(), &dict_header_only_chunks, dict));
    try std.testing.expectEqual(@as(usize, 0), dict_header_only_alloc_failing.allocations);
    var dict_header_only_exact_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TruncatedFrame, decodeZlibChunksAllocWithDictionaryExactSize(dict_header_only_exact_failing.allocator(), &dict_header_only_chunks, dict, input.len));
    try std.testing.expectEqual(@as(usize, 0), dict_header_only_exact_failing.allocations);

    var dict_reserved = try std.testing.allocator.alloc(u8, 7);
    defer std.testing.allocator.free(dict_reserved);
    @memcpy(dict_reserved[0..6], dict_frame[0..6]);
    dict_reserved[6] = 0x07;
    const dict_reserved_chunks = [_][]const u8{ dict_reserved[0..3], dict_reserved[3..] };
    var dict_reserved_alloc_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeZlibChunksAllocWithDictionary(dict_reserved_alloc_failing.allocator(), &dict_reserved_chunks, dict));
    try std.testing.expectEqual(@as(usize, 0), dict_reserved_alloc_failing.allocations);
    var dict_reserved_exact_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeZlibChunksAllocWithDictionaryExactSize(dict_reserved_exact_failing.allocator(), &dict_reserved_chunks, dict, input.len));
    try std.testing.expectEqual(@as(usize, 0), dict_reserved_exact_failing.allocations);

    try std.testing.expectEqual(input.len, try decodeZlibChunksWithDictionary(&dict_chunks, &compressed_scratch, &output, dict));
    try std.testing.expectEqualSlices(u8, input, &output);
    @memset(&output, 0);
    try std.testing.expectEqual(input.len, try decodeZlibChunksIntoWithDictionary(&dict_chunks, &output, dict));
    try std.testing.expectEqualSlices(u8, input, &output);
    try std.testing.expectEqual(input.len, try decodeZlibChunksIntoWithDictionaryAndOptions(&dict_chunks, &output, dict, .{}));
    const dict_exact = try decodeZlibChunksAllocWithDictionaryExactSize(std.testing.allocator, &dict_chunks, dict, input.len);
    defer std.testing.allocator.free(dict_exact);
    try std.testing.expectEqualSlices(u8, input, dict_exact);
    try std.testing.expectError(error.NeedDictionary, decodeZlibChunksAlloc(std.testing.allocator, &dict_chunks));
    try std.testing.expectError(error.OutputTooSmall, decodeZlibChunks(&chunks, compressed_scratch[0 .. encoded.len - 1], &output));
}

test "zlib decoder diagnostics cover wrapper errors" {
    var scratch: [32]u8 = undefined;
    var decoder = ZlibDecoder{};
    try std.testing.expectError(error.BadZlibHeader, decoder.reset(&.{ 0x78, 0x02 }, &scratch));
    try std.testing.expectEqualStrings("BadZlibHeader", decoder.snapshot().last_error_name);
    try std.testing.expectEqual(ZlibDecoder.RecoverabilityHint.corrupt_header, decoder.snapshot().recoverability_hint);
    try std.testing.expectEqualStrings("corrupt_header", decoder.diagnostics().recoverability_hint_name);

    const encoded = try encodeZlibFixedAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(encoded);
    try std.testing.expectError(error.TruncatedFrame, decoder.reset(encoded[0 .. encoded.len - 2], &scratch));
    try std.testing.expectEqualStrings("TruncatedFrame", decoder.snapshot().last_error_name);
    try std.testing.expectEqual(ZlibDecoder.RecoverabilityHint.truncated_input, decoder.snapshot().recoverability_hint);

    const corrupt = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decoder.reset(corrupt, &scratch));
    try std.testing.expectEqualStrings("ChecksumMismatch", decoder.snapshot().last_error_name);
    try std.testing.expectEqual(ZlibDecoder.RecoverabilityHint.payload_corrupt, decoder.snapshot().recoverability_hint);

    const dict = "hello ";
    const with_dict = try encodeZlibFixedWithDictionaryAlloc(std.testing.allocator, "hello hello", dict, optionsForLevel(.default));
    defer std.testing.allocator.free(with_dict);
    try std.testing.expectError(error.NeedDictionary, decoder.reset(with_dict, &scratch));
    try std.testing.expectEqualStrings("NeedDictionary", decoder.snapshot().last_error_name);
    try std.testing.expectEqual(ZlibDecoder.RecoverabilityHint.retry_with_dictionary, decoder.snapshot().recoverability_hint);
}

test "zlib concatenated streams decode in sequence" {
    const a = try encodeZlibFixedAlloc(std.testing.allocator, "hello ");
    defer std.testing.allocator.free(a);
    const b = try encodeZlibDynamicWithOptionsAlloc(std.testing.allocator, "world", .{});
    defer std.testing.allocator.free(b);

    var cat: std.ArrayList(u8) = .empty;
    defer cat.deinit(std.testing.allocator);
    try cat.appendSlice(std.testing.allocator, a);
    try cat.appendSlice(std.testing.allocator, b);

    try std.testing.expectError(error.TrailingData, decodeZlibAlloc(std.testing.allocator, cat.items));

    const decoded = try decodeZlibConcatenatedAlloc(std.testing.allocator, cat.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello world", decoded);

    var into: [11]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 11), try decodeZlibConcatenated(cat.items, &into));
    try std.testing.expectEqualSlices(u8, "hello world", &into);
    var concat_decoder = try ZlibDecoder.initConcatenatedExactSize(cat.items, &into, into.len);
    var drained: [11]u8 = undefined;
    const concat_step = try concat_decoder.step(&drained);
    try std.testing.expectEqual(core.StepResult.Status.done, concat_step.status);
    try std.testing.expectEqualSlices(u8, "hello world", &drained);
    const cat_chunks = [_][]const u8{ cat.items[0..5], cat.items[5 .. cat.items.len - 3], cat.items[cat.items.len - 3 ..] };
    var compressed_scratch: [128]u8 = undefined;
    var chunk_decoder = try ZlibDecoder.initConcatenatedFromChunksExactSize(&cat_chunks, &compressed_scratch, &into, into.len);
    @memset(&drained, 0);
    const chunk_step = try chunk_decoder.step(&drained);
    try std.testing.expectEqual(core.StepResult.Status.done, chunk_step.status);
    try std.testing.expectEqualSlices(u8, "hello world", &drained);
    try std.testing.expectError(error.OutputTooSmall, ZlibDecoder.initConcatenatedFromChunksExactSize(&cat_chunks, compressed_scratch[0 .. cat.items.len - 1], &into, into.len));
    try std.testing.expectError(error.SizeMismatch, ZlibDecoder.initConcatenatedExactSize(cat.items, &into, into.len + 1));
    try std.testing.expectError(error.OutputTooSmall, decodeZlibConcatenated(cat.items, into[0..10]));
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibConcatenatedAllocLimited(std.testing.allocator, cat.items, 10));

    const limited = try decodeZlibConcatenatedAllocLimited(std.testing.allocator, cat.items, 11);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, "hello world", limited);

    const exact = try decodeZlibConcatenatedAllocExactSize(std.testing.allocator, cat.items, 11);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, "hello world", exact);
    try std.testing.expectError(error.SizeMismatch, decodeZlibConcatenatedAllocExactSize(std.testing.allocator, cat.items, 10));
    try std.testing.expectError(error.SizeMismatch, decodeZlibConcatenatedAllocExactSize(std.testing.allocator, cat.items, 12));

    var header_only_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TruncatedFrame, decodeZlibConcatenatedAllocExactSize(header_only_failing.allocator(), &.{ 0x78, 0x01 }, 11));
    try std.testing.expectEqual(@as(usize, 0), header_only_failing.allocations);
    var reserved_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeZlibConcatenatedAllocExactSize(reserved_failing.allocator(), &.{ 0x78, 0x01, 0x07 }, 11));
    try std.testing.expectEqual(@as(usize, 0), reserved_failing.allocations);
    var reserved_alloc_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeZlibConcatenatedAlloc(reserved_alloc_failing.allocator(), &.{ 0x78, 0x01, 0x07 }));
    try std.testing.expectEqual(@as(usize, 0), reserved_alloc_failing.allocations);
    var reserved_limited_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeZlibConcatenatedAllocLimited(reserved_limited_failing.allocator(), &.{ 0x78, 0x01, 0x07 }, 11));
    try std.testing.expectEqual(@as(usize, 0), reserved_limited_failing.allocations);
}

test "zlib concatenated decode options ignore adler and allow trailing data" {
    const a = try encodeZlibFixedAlloc(std.testing.allocator, "hello ");
    defer std.testing.allocator.free(a);
    const b = try encodeZlibDynamicWithOptionsAlloc(std.testing.allocator, "world", .{});
    defer std.testing.allocator.free(b);

    var cat: std.ArrayList(u8) = .empty;
    defer cat.deinit(std.testing.allocator);
    try cat.appendSlice(std.testing.allocator, a);
    try cat.appendSlice(std.testing.allocator, b);
    cat.items[cat.items.len - 1] ^= 1;
    try cat.appendSlice(std.testing.allocator, "not-a-zlib-member");

    var into: ["hello world".len]u8 = undefined;
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibConcatenated(cat.items, &into));

    const options = ZlibDecodeOptions{ .ignore_adler = true, .allow_trailing_data = true };
    try std.testing.expectEqual(@as(usize, into.len), try decodeZlibConcatenatedWithOptions(cat.items, &into, options));
    try std.testing.expectEqualSlices(u8, "hello world", &into);
    var concat_decoder = try ZlibDecoder.initConcatenatedWithOptionsExactSize(cat.items, &into, options, into.len);
    var drained: ["hello world".len]u8 = undefined;
    const concat_step = try concat_decoder.step(&drained);
    try std.testing.expectEqual(core.StepResult.Status.done, concat_step.status);
    try std.testing.expectEqualSlices(u8, "hello world", &drained);
    try concat_decoder.resetConcatenatedWithOptionsExactSize(cat.items, &into, options, into.len);
    @memset(&drained, 0);
    const reset_step = try concat_decoder.step(&drained);
    try std.testing.expectEqual(core.StepResult.Status.done, reset_step.status);
    try std.testing.expectEqualSlices(u8, "hello world", &drained);
    const cat_chunks = [_][]const u8{ cat.items[0..4], cat.items[4 .. cat.items.len - 7], cat.items[cat.items.len - 7 ..] };
    var compressed_scratch: [128]u8 = undefined;
    var chunk_decoder = try ZlibDecoder.initConcatenatedFromChunksWithOptionsExactSize(&cat_chunks, &compressed_scratch, &into, options, into.len);
    @memset(&drained, 0);
    const chunk_step = try chunk_decoder.step(&drained);
    try std.testing.expectEqual(core.StepResult.Status.done, chunk_step.status);
    try std.testing.expectEqualSlices(u8, "hello world", &drained);

    const decoded = try decodeZlibConcatenatedAllocWithOptions(std.testing.allocator, cat.items, options);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &into, decoded);

    const limited = try decodeZlibConcatenatedAllocWithOptionsLimited(std.testing.allocator, cat.items, options, into.len);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, &into, limited);
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibConcatenatedAllocWithOptionsLimited(std.testing.allocator, cat.items, options, into.len - 1));

    const exact = try decodeZlibConcatenatedAllocWithOptionsExactSize(std.testing.allocator, cat.items, options, into.len);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, &into, exact);
    try std.testing.expectError(error.SizeMismatch, decodeZlibConcatenatedAllocWithOptionsExactSize(std.testing.allocator, cat.items, options, into.len - 1));
}

test "zlib concatenated stored streams decode and validate per-member trailers" {
    const first = try encodeZlibStoredAlloc(std.testing.allocator, "stored ");
    defer std.testing.allocator.free(first);
    const second = try encodeZlibStoredAlloc(std.testing.allocator, "member");
    defer std.testing.allocator.free(second);

    var cat: std.ArrayList(u8) = .empty;
    defer cat.deinit(std.testing.allocator);
    try cat.appendSlice(std.testing.allocator, first);
    try cat.appendSlice(std.testing.allocator, second);

    const decoded = try decodeZlibConcatenatedAlloc(std.testing.allocator, cat.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "stored member", decoded);

    var into: ["stored member".len]u8 = undefined;
    try std.testing.expectEqual(@as(usize, into.len), try decodeZlibConcatenated(cat.items, &into));
    try std.testing.expectEqualSlices(u8, "stored member", &into);

    const exact = try decodeZlibConcatenatedAllocExactSize(std.testing.allocator, cat.items, into.len);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, &into, exact);
    var exact_short_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.SizeMismatch, decodeZlibConcatenatedAllocExactSize(exact_short_failing.allocator(), cat.items, into.len - 1));
    try std.testing.expectEqual(@as(usize, 0), exact_short_failing.allocations);
    var limited_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibConcatenatedAllocLimited(limited_failing.allocator(), cat.items, into.len - 1));
    try std.testing.expectEqual(@as(usize, 0), limited_failing.allocations);
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibConcatenatedAllocLimited(std.testing.allocator, cat.items, into.len - 1));

    var bad_second_adler = try std.testing.allocator.dupe(u8, cat.items);
    defer std.testing.allocator.free(bad_second_adler);
    bad_second_adler[bad_second_adler.len - 1] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibConcatenatedAlloc(std.testing.allocator, bad_second_adler));
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibConcatenated(bad_second_adler, &into));
    var bad_second_alloc_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibConcatenatedAlloc(bad_second_alloc_failing.allocator(), bad_second_adler));
    try std.testing.expectEqual(@as(usize, 0), bad_second_alloc_failing.allocations);
    var bad_second_exact_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibConcatenatedAllocExactSize(bad_second_exact_failing.allocator(), bad_second_adler, into.len));
    try std.testing.expectEqual(@as(usize, 0), bad_second_exact_failing.allocations);
}

test "zlib concatenated stored decode options preflight relaxed failures before allocation" {
    const first = try encodeZlibStoredAlloc(std.testing.allocator, "stored ");
    defer std.testing.allocator.free(first);
    const second = try encodeZlibStoredAlloc(std.testing.allocator, "member");
    defer std.testing.allocator.free(second);

    var cat: std.ArrayList(u8) = .empty;
    defer cat.deinit(std.testing.allocator);
    try cat.appendSlice(std.testing.allocator, first);
    try cat.appendSlice(std.testing.allocator, second);
    cat.items[cat.items.len - 1] ^= 1;
    try cat.append(std.testing.allocator, 0);

    const options = ZlibDecodeOptions{ .ignore_adler = true, .allow_trailing_data = true };
    var into: ["stored member".len]u8 = undefined;
    try std.testing.expectEqual(into.len, try decodeZlibConcatenatedWithOptions(cat.items, &into, options));
    try std.testing.expectEqualSlices(u8, "stored member", &into);

    var limited_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibConcatenatedAllocWithOptionsLimited(limited_failing.allocator(), cat.items, options, into.len - 1));
    try std.testing.expectEqual(@as(usize, 0), limited_failing.allocations);

    var exact_short_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.SizeMismatch, decodeZlibConcatenatedAllocWithOptionsExactSize(exact_short_failing.allocator(), cat.items, options, into.len - 1));
    try std.testing.expectEqual(@as(usize, 0), exact_short_failing.allocations);

    const decoded = try decodeZlibConcatenatedAllocWithOptions(std.testing.allocator, cat.items, options);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &into, decoded);
}

test "zlib concatenated streams reject empty and corrupt later members" {
    var out: [1]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeZlibConcatenated("", &out));
    try std.testing.expectError(error.TruncatedFrame, decodeZlibConcatenatedAlloc(std.testing.allocator, ""));
    try std.testing.expectError(error.TruncatedFrame, decodeZlibConcatenatedAllocLimited(std.testing.allocator, "", 1));
    try std.testing.expectError(error.TruncatedFrame, decodeZlibConcatenatedAllocExactSize(std.testing.allocator, "", 0));

    const a = try encodeZlibFixedAlloc(std.testing.allocator, "hello ");
    defer std.testing.allocator.free(a);
    const b = try encodeZlibFixedAlloc(std.testing.allocator, "world");
    defer std.testing.allocator.free(b);

    var bad_first_header = try std.testing.allocator.dupe(u8, a);
    defer std.testing.allocator.free(bad_first_header);
    bad_first_header[1] ^= 1;
    var bad_first_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.BadZlibHeader, decodeZlibConcatenatedAllocExactSize(bad_first_failing.allocator(), bad_first_header, 6));
    try std.testing.expectEqual(@as(usize, 0), bad_first_failing.allocations);

    var cat: std.ArrayList(u8) = .empty;
    defer cat.deinit(std.testing.allocator);
    try cat.appendSlice(std.testing.allocator, a);
    try cat.appendSlice(std.testing.allocator, b);

    try std.testing.expectError(error.TruncatedFrame, decodeZlibConcatenatedAlloc(std.testing.allocator, cat.items[0 .. cat.items.len - 4]));

    var bad_adler = try std.testing.allocator.dupe(u8, cat.items);
    defer std.testing.allocator.free(bad_adler);
    bad_adler[bad_adler.len - 1] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibConcatenatedAlloc(std.testing.allocator, bad_adler));
}

test "zlib concatenated streams decode preset dictionary members" {
    const dictionary = "hello ";
    const first_payload = "hello hello ";
    const second_payload = "hello world";
    const first = try encodeZlibFixedWithDictionaryAlloc(std.testing.allocator, first_payload, dictionary, optionsForLevel(.default));
    defer std.testing.allocator.free(first);
    const second = try encodeZlibDynamicWithDictionaryAlloc(std.testing.allocator, second_payload, dictionary, optionsForLevel(.default));
    defer std.testing.allocator.free(second);

    var cat: std.ArrayList(u8) = .empty;
    defer cat.deinit(std.testing.allocator);
    try cat.appendSlice(std.testing.allocator, first);
    try cat.appendSlice(std.testing.allocator, second);

    try std.testing.expectError(error.NeedDictionary, decodeZlibConcatenatedAlloc(std.testing.allocator, cat.items));
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibConcatenatedAllocWithDictionary(std.testing.allocator, cat.items, "wrong dictionary"));

    const decoded = try decodeZlibConcatenatedAllocWithDictionary(std.testing.allocator, cat.items, dictionary);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first_payload ++ second_payload, decoded);

    var into: [first_payload.len + second_payload.len]u8 = undefined;
    try std.testing.expectEqual(into.len, try decodeZlibConcatenatedWithDictionary(cat.items, &into, dictionary));
    try std.testing.expectEqualSlices(u8, first_payload ++ second_payload, &into);
    var decoder = try ZlibDecoder.initConcatenatedWithDictionaryExactSize(cat.items, dictionary, &into, into.len);
    var drained: [first_payload.len + second_payload.len]u8 = undefined;
    const step = try decoder.step(&drained);
    try std.testing.expectEqual(core.StepResult.Status.done, step.status);
    try std.testing.expectEqualSlices(u8, first_payload ++ second_payload, &drained);
    const cat_chunks = [_][]const u8{ cat.items[0..6], cat.items[6 .. cat.items.len - 4], cat.items[cat.items.len - 4 ..] };
    var compressed_scratch: [256]u8 = undefined;
    var chunk_decoder = try ZlibDecoder.initConcatenatedFromChunksWithDictionaryExactSize(&cat_chunks, dictionary, &compressed_scratch, &into, into.len);
    @memset(&drained, 0);
    const chunk_step = try chunk_decoder.step(&drained);
    try std.testing.expectEqual(core.StepResult.Status.done, chunk_step.status);
    try std.testing.expectEqualSlices(u8, first_payload ++ second_payload, &drained);

    const limited = try decodeZlibConcatenatedAllocWithDictionaryLimited(std.testing.allocator, cat.items, dictionary, into.len);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, &into, limited);
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibConcatenatedAllocWithDictionaryLimited(std.testing.allocator, cat.items, dictionary, into.len - 1));

    const exact = try decodeZlibConcatenatedAllocWithDictionaryExactSize(std.testing.allocator, cat.items, dictionary, into.len);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, &into, exact);
    try std.testing.expectError(error.SizeMismatch, decodeZlibConcatenatedAllocWithDictionaryExactSize(std.testing.allocator, cat.items, dictionary, into.len - 1));
}

test "zlib concatenated stored streams honor preset dictionary headers" {
    const dictionary = "stored ";
    const first_payload = "stored stored ";
    const second_payload = "stored member";
    const first = try encodeZlibStoredWithDictionaryAlloc(std.testing.allocator, first_payload, dictionary);
    defer std.testing.allocator.free(first);
    const second = try encodeZlibStoredWithDictionaryAlloc(std.testing.allocator, second_payload, dictionary);
    defer std.testing.allocator.free(second);

    var cat: std.ArrayList(u8) = .empty;
    defer cat.deinit(std.testing.allocator);
    try cat.appendSlice(std.testing.allocator, first);
    try cat.appendSlice(std.testing.allocator, second);

    try std.testing.expectError(error.NeedDictionary, decodeZlibConcatenatedAlloc(std.testing.allocator, cat.items));
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibConcatenatedAllocWithDictionary(std.testing.allocator, cat.items, "wrong dictionary"));

    const decoded = try decodeZlibConcatenatedAllocWithDictionary(std.testing.allocator, cat.items, dictionary);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first_payload ++ second_payload, decoded);

    var into: [first_payload.len + second_payload.len]u8 = undefined;
    try std.testing.expectEqual(into.len, try decodeZlibConcatenatedWithDictionary(cat.items, &into, dictionary));
    try std.testing.expectEqualSlices(u8, first_payload ++ second_payload, &into);
}

test "zlib stream inspector reports deflate length and adler diagnostics" {
    const encoded = try encodeZlibFixedAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(encoded);
    const info = try inspectZlibStreamAlloc(std.testing.allocator, encoded);
    try std.testing.expectEqual(@as(usize, 2), info.deflate_offset);
    try std.testing.expectEqual(encoded.len - 2 - 4, info.deflate_bytes);
    try std.testing.expectEqual(@as(usize, 7), info.output_bytes);
    try std.testing.expectEqual(info.deflate_offset + info.deflate_bytes, info.footer_offset);
    try std.testing.expectEqual(info.footer_offset + 4, info.end_offset);
    try std.testing.expectEqual(encoded.len, info.end_offset);
    try std.testing.expectEqual(checksum.adler32("payload"), info.footer_adler32);
    try std.testing.expectEqual(info.footer_adler32, info.adler32);
    try std.testing.expect(info.adler32_matches);

    var bad_adler = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_adler);
    bad_adler[bad_adler.len - 1] ^= 1;
    const bad_info = try inspectZlibStreamAlloc(std.testing.allocator, bad_adler);
    try std.testing.expectEqual(checksum.adler32("payload"), bad_info.adler32);
    try std.testing.expect(bad_info.footer_adler32 != bad_info.adler32);
    try std.testing.expect(!bad_info.adler32_matches);

    var with_trailing: [128]u8 = undefined;
    @memcpy(with_trailing[0..encoded.len], encoded);
    with_trailing[encoded.len] = 0;
    const prefix_info = try inspectZlibStreamAlloc(std.testing.allocator, with_trailing[0 .. encoded.len + 1]);
    try std.testing.expectEqual(encoded.len, prefix_info.end_offset);
    try std.testing.expectEqual(@as(usize, encoded.len + 1), with_trailing[0 .. encoded.len + 1].len);
    try std.testing.expectError(error.OutputLimitExceeded, inspectZlibStreamAllocLimited(std.testing.allocator, encoded, 6));

    const chunks = [_][]const u8{
        encoded[0..2],
        encoded[2 .. encoded.len - 4],
        encoded[encoded.len - 4 ..],
    };
    var compressed_scratch: [128]u8 = undefined;
    const chunk_info = try inspectZlibStreamFromChunksAlloc(std.testing.allocator, &chunks, &compressed_scratch);
    try std.testing.expectEqual(info.deflate_offset, chunk_info.deflate_offset);
    try std.testing.expectEqual(info.deflate_bytes, chunk_info.deflate_bytes);
    try std.testing.expectEqual(info.output_bytes, chunk_info.output_bytes);
    try std.testing.expectEqual(info.footer_offset, chunk_info.footer_offset);
    try std.testing.expectEqual(info.end_offset, chunk_info.end_offset);
    try std.testing.expect(chunk_info.adler32_matches);
    try std.testing.expectError(error.OutputTooSmall, inspectZlibStreamFromChunksAlloc(std.testing.allocator, &chunks, compressed_scratch[0 .. encoded.len - 1]));
}

test "zlib stream inspector validates preset dictionary IDs" {
    const dictionary = "hello ";
    const payload = "hello hello hello";
    const encoded = try encodeZlibFixedWithDictionaryAlloc(std.testing.allocator, payload, dictionary, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    const info = try inspectZlibStreamAllocWithDictionary(std.testing.allocator, encoded, dictionary);
    try std.testing.expect(info.header.uses_dictionary);
    try std.testing.expectEqual(checksum.adler32(dictionary), info.header.dictionary_id.?);
    try std.testing.expectEqual(checksum.adler32(payload), info.adler32);
    try std.testing.expect(info.adler32_matches);
    try std.testing.expectError(error.NeedDictionary, inspectZlibStreamAlloc(std.testing.allocator, encoded));
    try std.testing.expectError(error.ChecksumMismatch, inspectZlibStreamAllocWithDictionary(std.testing.allocator, encoded, "wrong"));

    const chunks = [_][]const u8{
        encoded[0..6],
        encoded[6 .. encoded.len - 4],
        encoded[encoded.len - 4 ..],
    };
    var compressed_scratch: [128]u8 = undefined;
    const chunk_info = try inspectZlibStreamFromChunksAllocWithDictionary(std.testing.allocator, &chunks, &compressed_scratch, dictionary);
    try std.testing.expectEqual(info.header.dictionary_id.?, chunk_info.header.dictionary_id.?);
    try std.testing.expectEqual(info.deflate_bytes, chunk_info.deflate_bytes);
    try std.testing.expectEqual(info.output_bytes, chunk_info.output_bytes);
    try std.testing.expect(chunk_info.adler32_matches);
    try std.testing.expectError(error.ChecksumMismatch, inspectZlibStreamFromChunksAllocWithDictionary(std.testing.allocator, &chunks, &compressed_scratch, "wrong"));
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

    const parsed = try parseGzipHeaderInfo(stored);
    try std.testing.expectEqual(expected_prefix.len, parsed.data_offset);
    try std.testing.expectEqual(@as(u8, 0x1f), parsed.flags);
    try std.testing.expect(parsed.text);
    try std.testing.expectEqual(@as(u32, 0x12345678), parsed.mtime);
    try std.testing.expectEqual(@as(u8, 0x02), parsed.xfl);
    try std.testing.expectEqual(@as(u8, 0xff), parsed.os);
    try std.testing.expectEqualSlices(u8, &extra, parsed.extra.?);
    try std.testing.expectEqualSlices(u8, "sample.txt", parsed.filename.?);
    try std.testing.expectEqualSlices(u8, "generated by vort", parsed.comment.?);
    try std.testing.expectEqual(@as(u16, 0x5d05), parsed.header_crc.?);
    const header_chunks = [_][]const u8{
        stored[0..3],
        stored[3 .. expected_prefix.len - 2],
        stored[expected_prefix.len - 2 .. expected_prefix.len],
    };
    var compressed_scratch: [128]u8 = undefined;
    const chunk_parsed = try parseGzipHeaderInfoFromChunks(&header_chunks, &compressed_scratch);
    try std.testing.expectEqual(parsed.data_offset, chunk_parsed.data_offset);
    try std.testing.expectEqualSlices(u8, parsed.extra.?, chunk_parsed.extra.?);
    try std.testing.expectEqualSlices(u8, parsed.filename.?, chunk_parsed.filename.?);
    try std.testing.expectEqualSlices(u8, parsed.comment.?, chunk_parsed.comment.?);
    try std.testing.expectEqual(parsed.header_crc.?, chunk_parsed.header_crc.?);
    try std.testing.expectError(error.OutputTooSmall, parseGzipHeaderInfoFromChunks(&header_chunks, compressed_scratch[0 .. expected_prefix.len - 1]));

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

    var exact_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    const exact_stored = try decodeGzipStoredAlloc(exact_failing.allocator(), encoded);
    defer exact_failing.allocator().free(exact_stored);
    try std.testing.expectEqualSlices(u8, "payload", exact_stored);
    try std.testing.expectEqual(@as(usize, 1), exact_failing.allocations);

    var bad_header = try encodeGzipStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(bad_header);
    bad_header[0] = 0;
    var out: [32]u8 = undefined;
    try std.testing.expectError(error.BadGzipHeader, decodeGzipStored(bad_header, &out));

    var bad_crc = try encodeGzipStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(bad_crc);
    bad_crc[bad_crc.len - 8] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeGzipStored(bad_crc, &out));
    var bad_crc_stored_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.ChecksumMismatch, decodeGzipStoredAlloc(bad_crc_stored_failing.allocator(), bad_crc));
    try std.testing.expectEqual(@as(usize, 0), bad_crc_stored_failing.allocations);
    var bad_crc_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.ChecksumMismatch, decodeGzipAlloc(bad_crc_failing.allocator(), bad_crc));
    try std.testing.expectEqual(@as(usize, 0), bad_crc_failing.allocations);

    var bad_size = try encodeGzipStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(bad_size);
    bad_size[bad_size.len - 4] ^= 1;
    try std.testing.expectError(error.SizeMismatch, decodeGzipStored(bad_size, &out));
    var bad_size_stored_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.SizeMismatch, decodeGzipStoredAlloc(bad_size_stored_failing.allocator(), bad_size));
    try std.testing.expectEqual(@as(usize, 0), bad_size_stored_failing.allocations);
    var bad_size_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.SizeMismatch, decodeGzipAlloc(bad_size_failing.allocator(), bad_size));
    try std.testing.expectEqual(@as(usize, 0), bad_size_failing.allocations);

    var with_trailing: [64]u8 = undefined;
    @memcpy(with_trailing[0..encoded.len], encoded);
    with_trailing[encoded.len] = 0;
    try std.testing.expectError(error.TrailingData, decodeGzipStored(with_trailing[0 .. encoded.len + 1], &out));
    try std.testing.expectError(error.TrailingData, decodeGzipStoredAlloc(std.testing.allocator, with_trailing[0 .. encoded.len + 1]));
    var stored_trailing_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TrailingData, decodeGzipStoredAlloc(stored_trailing_failing.allocator(), with_trailing[0 .. encoded.len + 1]));
    try std.testing.expectEqual(@as(usize, 0), stored_trailing_failing.allocations);
    var trailing_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TrailingData, decodeGzipAlloc(trailing_failing.allocator(), with_trailing[0 .. encoded.len + 1]));
    try std.testing.expectEqual(@as(usize, 0), trailing_failing.allocations);
}

test "gzip decoder drains bounded output from caller scratch" {
    const input = "gzip bounded decoder payload";
    const encoded = try encodeGzipBestAlloc(std.testing.allocator, input, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    var scratch: [input.len]u8 = undefined;
    var decoder = try GzipDecoder.initExactSize(encoded, &scratch, input.len);
    var out: [input.len]u8 = undefined;
    var written: usize = 0;
    while (true) {
        var chunk: [6]u8 = undefined;
        const step = try decoder.step(&chunk);
        @memcpy(out[written..][0..step.progress.output_written], chunk[0..step.progress.output_written]);
        written += step.progress.output_written;
        if (step.status == .done) {
            try std.testing.expectEqual(encoded.len, step.progress.input_read);
            break;
        }
        try std.testing.expectEqual(core.StepResult.Status.need_output, step.status);
    }
    try std.testing.expectEqualSlices(u8, input, &out);
    try std.testing.expectEqualStrings("done", decoder.diagnostics().phase_name);

    var compressed_scratch: [128]u8 = undefined;
    const chunks = [_][]const u8{
        encoded[0..4],
        encoded[4 .. encoded.len - 8],
        encoded[encoded.len - 8 ..],
    };
    @memset(&out, 0);
    try std.testing.expectEqual(input.len, try decodeGzipChunks(&chunks, &compressed_scratch, &out));
    try std.testing.expectEqualSlices(u8, input, &out);
    const chunk_alloc = try decodeGzipChunksAlloc(std.testing.allocator, &chunks, &compressed_scratch);
    defer std.testing.allocator.free(chunk_alloc);
    try std.testing.expectEqualSlices(u8, input, chunk_alloc);
    const chunk_exact = try decodeGzipChunksAllocExactSize(std.testing.allocator, &chunks, &compressed_scratch, input.len);
    defer std.testing.allocator.free(chunk_exact);
    try std.testing.expectEqualSlices(u8, input, chunk_exact);
    const chunk_limited = try decodeGzipChunksAllocLimited(std.testing.allocator, &chunks, &compressed_scratch, input.len);
    defer std.testing.allocator.free(chunk_limited);
    try std.testing.expectEqualSlices(u8, input, chunk_limited);
    try std.testing.expectError(error.SizeMismatch, decodeGzipChunksAllocExactSize(std.testing.allocator, &chunks, &compressed_scratch, input.len + 1));
    try std.testing.expectError(error.OutputLimitExceeded, decodeGzipChunksAllocLimited(std.testing.allocator, &chunks, &compressed_scratch, input.len - 1));
    var chunk_decoder = try GzipDecoder.initFromChunksExactSize(&chunks, &compressed_scratch, &scratch, input.len);
    @memset(&out, 0);
    const chunk_step = try chunk_decoder.step(&out);
    try std.testing.expectEqual(core.StepResult.Status.done, chunk_step.status);
    try std.testing.expectEqual(encoded.len, chunk_step.progress.input_read);
    try std.testing.expectEqualSlices(u8, input, &out);
    try std.testing.expectError(error.OutputTooSmall, decodeGzipChunks(&chunks, compressed_scratch[0 .. encoded.len - 1], &out));
    try std.testing.expectError(error.OutputTooSmall, GzipDecoder.initFromChunksExactSize(&chunks, compressed_scratch[0 .. encoded.len - 1], &scratch, input.len));

    const single_chunk = [_][]const u8{
        encoded[0..0],
        encoded,
        encoded[encoded.len..],
    };
    var no_compressed_scratch: [0]u8 = .{};
    @memset(&out, 0);
    try std.testing.expectEqual(input.len, try decodeGzipChunks(&single_chunk, &no_compressed_scratch, &out));
    try std.testing.expectEqualSlices(u8, input, &out);
    var single_chunk_decoder = try GzipDecoder.initFromChunksExactSize(&single_chunk, &no_compressed_scratch, &scratch, input.len);
    @memset(&out, 0);
    const single_chunk_step = try single_chunk_decoder.step(&out);
    try std.testing.expectEqual(core.StepResult.Status.done, single_chunk_step.status);
    try std.testing.expectEqual(encoded.len, single_chunk_step.progress.input_read);
    try std.testing.expectEqualSlices(u8, input, &out);

    var bad_chunk_crc = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_chunk_crc);
    bad_chunk_crc[bad_chunk_crc.len - 8] ^= 1;
    const bad_chunks = [_][]const u8{
        bad_chunk_crc[0..4],
        bad_chunk_crc[4 .. bad_chunk_crc.len - 8],
        bad_chunk_crc[bad_chunk_crc.len - 8 ..],
    };
    try std.testing.expectError(error.ChecksumMismatch, decodeGzipChunks(&bad_chunks, &compressed_scratch, &out));
    @memset(&out, 0);
    try std.testing.expectEqual(input.len, try decodeGzipChunksWithOptions(&bad_chunks, &compressed_scratch, &out, .{ .ignore_crc32 = true }));
    try std.testing.expectEqualSlices(u8, input, &out);
    const relaxed_alloc = try decodeGzipChunksAllocWithOptionsExactSize(std.testing.allocator, &bad_chunks, &compressed_scratch, .{ .ignore_crc32 = true }, input.len);
    defer std.testing.allocator.free(relaxed_alloc);
    try std.testing.expectEqualSlices(u8, input, relaxed_alloc);
    const relaxed_limited = try decodeGzipChunksAllocWithOptionsLimited(std.testing.allocator, &bad_chunks, &compressed_scratch, .{ .ignore_crc32 = true }, input.len);
    defer std.testing.allocator.free(relaxed_limited);
    try std.testing.expectEqualSlices(u8, input, relaxed_limited);
    try std.testing.expectError(error.ChecksumMismatch, GzipDecoder.initFromChunksExactSize(&bad_chunks, &compressed_scratch, &scratch, input.len));
    var relaxed_chunk_decoder = try GzipDecoder.initFromChunksWithOptionsExactSize(&bad_chunks, &compressed_scratch, &scratch, .{ .ignore_crc32 = true }, input.len);
    @memset(&out, 0);
    const relaxed_chunk_step = try relaxed_chunk_decoder.step(&out);
    try std.testing.expectEqual(core.StepResult.Status.done, relaxed_chunk_step.status);
    try std.testing.expectEqual(bad_chunk_crc.len, relaxed_chunk_step.progress.input_read);
    try std.testing.expectEqualSlices(u8, input, &out);

    try std.testing.expectError(error.OutputTooSmall, GzipDecoder.initExactSize(encoded, scratch[0 .. scratch.len - 1], input.len));
    try std.testing.expectError(error.SizeMismatch, GzipDecoder.initExactSize(encoded, &scratch, input.len + 1));
}

test "gzip decoder drains concatenated members from caller scratch" {
    const first = try encodeGzipFixedAlloc(std.testing.allocator, "hello ");
    defer std.testing.allocator.free(first);
    const empty = try encodeGzipFixedAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    const third = try encodeGzipFixedAlloc(std.testing.allocator, "world");
    defer std.testing.allocator.free(third);

    var cat: [256]u8 = undefined;
    var cat_len: usize = 0;
    @memcpy(cat[cat_len..][0..first.len], first);
    cat_len += first.len;
    @memcpy(cat[cat_len..][0..empty.len], empty);
    cat_len += empty.len;
    @memcpy(cat[cat_len..][0..third.len], third);
    cat_len += third.len;
    const input = cat[0..cat_len];

    var scratch: ["hello world".len]u8 = undefined;
    var decoder = try GzipDecoder.initConcatenatedExactSize(input, &scratch, "hello world".len);
    var out: ["hello world".len]u8 = undefined;
    var written: usize = 0;
    while (true) {
        var chunk: [4]u8 = undefined;
        const step = try decoder.step(&chunk);
        @memcpy(out[written..][0..step.progress.output_written], chunk[0..step.progress.output_written]);
        written += step.progress.output_written;
        if (step.status == .done) {
            try std.testing.expectEqual(input.len, step.progress.input_read);
            break;
        }
        try std.testing.expectEqual(core.StepResult.Status.need_output, step.status);
    }
    try std.testing.expectEqualSlices(u8, "hello world", &out);

    var compressed_scratch: [256]u8 = undefined;
    const chunks = [_][]const u8{
        input[0 .. first.len - 1],
        input[first.len - 1 .. first.len + empty.len + 2],
        input[first.len + empty.len + 2 ..],
    };
    @memset(&out, 0);
    try std.testing.expectEqual(out.len, try decodeGzipConcatenatedChunks(&chunks, &compressed_scratch, &out));
    try std.testing.expectEqualSlices(u8, "hello world", &out);
    const chunk_alloc = try decodeGzipConcatenatedChunksAlloc(std.testing.allocator, &chunks, &compressed_scratch);
    defer std.testing.allocator.free(chunk_alloc);
    try std.testing.expectEqualSlices(u8, "hello world", chunk_alloc);
    const chunk_exact = try decodeGzipConcatenatedChunksAllocExactSize(std.testing.allocator, &chunks, &compressed_scratch, out.len);
    defer std.testing.allocator.free(chunk_exact);
    try std.testing.expectEqualSlices(u8, "hello world", chunk_exact);
    const chunk_limited = try decodeGzipConcatenatedChunksAllocLimited(std.testing.allocator, &chunks, &compressed_scratch, out.len);
    defer std.testing.allocator.free(chunk_limited);
    try std.testing.expectEqualSlices(u8, "hello world", chunk_limited);
    try std.testing.expectError(error.SizeMismatch, decodeGzipConcatenatedChunksAllocExactSize(std.testing.allocator, &chunks, &compressed_scratch, out.len + 1));
    try std.testing.expectError(error.OutputLimitExceeded, decodeGzipConcatenatedChunksAllocLimited(std.testing.allocator, &chunks, &compressed_scratch, out.len - 1));
    var chunk_decoder = try GzipDecoder.initConcatenatedFromChunksExactSize(&chunks, &compressed_scratch, &scratch, "hello world".len);
    @memset(&out, 0);
    const chunk_step = try chunk_decoder.step(&out);
    try std.testing.expectEqual(core.StepResult.Status.done, chunk_step.status);
    try std.testing.expectEqual(input.len, chunk_step.progress.input_read);
    try std.testing.expectEqualSlices(u8, "hello world", &out);
    try std.testing.expectError(error.OutputTooSmall, GzipDecoder.initConcatenatedFromChunksExactSize(&chunks, compressed_scratch[0 .. input.len - 1], &scratch, "hello world".len));

    var bad_cat = try std.testing.allocator.dupe(u8, input);
    defer std.testing.allocator.free(bad_cat);
    bad_cat[bad_cat.len - 8] ^= 1;
    const bad_chunks = [_][]const u8{
        bad_cat[0 .. first.len - 1],
        bad_cat[first.len - 1 .. first.len + empty.len + 2],
        bad_cat[first.len + empty.len + 2 ..],
    };
    try std.testing.expectError(error.ChecksumMismatch, decodeGzipConcatenatedChunks(&bad_chunks, &compressed_scratch, &out));
    @memset(&out, 0);
    try std.testing.expectEqual(out.len, try decodeGzipConcatenatedChunksWithOptions(&bad_chunks, &compressed_scratch, &out, .{ .ignore_crc32 = true }));
    try std.testing.expectEqualSlices(u8, "hello world", &out);
    const relaxed_exact = try decodeGzipConcatenatedChunksAllocWithOptionsExactSize(std.testing.allocator, &bad_chunks, &compressed_scratch, .{ .ignore_crc32 = true }, out.len);
    defer std.testing.allocator.free(relaxed_exact);
    try std.testing.expectEqualSlices(u8, "hello world", relaxed_exact);
    const relaxed_limited = try decodeGzipConcatenatedChunksAllocWithOptionsLimited(std.testing.allocator, &bad_chunks, &compressed_scratch, .{ .ignore_crc32 = true }, out.len);
    defer std.testing.allocator.free(relaxed_limited);
    try std.testing.expectEqualSlices(u8, "hello world", relaxed_limited);
    try std.testing.expectError(error.ChecksumMismatch, GzipDecoder.initConcatenatedFromChunksExactSize(&bad_chunks, &compressed_scratch, &scratch, "hello world".len));
    var relaxed_chunk_decoder = try GzipDecoder.initConcatenatedFromChunksWithOptionsExactSize(&bad_chunks, &compressed_scratch, &scratch, .{ .ignore_crc32 = true }, "hello world".len);
    @memset(&out, 0);
    const relaxed_chunk_step = try relaxed_chunk_decoder.step(&out);
    try std.testing.expectEqual(core.StepResult.Status.done, relaxed_chunk_step.status);
    try std.testing.expectEqual(input.len, relaxed_chunk_step.progress.input_read);
    try std.testing.expectEqualSlices(u8, "hello world", &out);

    try std.testing.expectError(error.OutputTooSmall, GzipDecoder.initConcatenatedExactSize(input, scratch[0 .. scratch.len - 1], "hello world".len));
    try std.testing.expectError(error.SizeMismatch, GzipDecoder.initConcatenatedExactSize(input, &scratch, "hello world".len + 1));
    try std.testing.expectError(error.TruncatedFrame, GzipDecoder.initConcatenated("", &scratch));
}

test "gzip decoder diagnostics cover wrapper errors" {
    var scratch: [32]u8 = undefined;
    var decoder = GzipDecoder{};
    try std.testing.expectError(error.BadGzipHeader, decoder.reset(&.{ 0x1f, 0x8b, 0x00, 0, 0, 0, 0, 0, 0, 3 }, &scratch));
    try std.testing.expectEqualStrings("BadGzipHeader", decoder.snapshot().last_error_name);
    try std.testing.expectEqual(GzipDecoder.RecoverabilityHint.corrupt_header, decoder.snapshot().recoverability_hint);

    const encoded = try encodeGzipBestAlloc(std.testing.allocator, "payload", optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    try std.testing.expectError(error.TruncatedFrame, decoder.reset(encoded[0 .. encoded.len - 4], &scratch));
    try std.testing.expectEqual(GzipDecoder.RecoverabilityHint.truncated_input, decoder.snapshot().recoverability_hint);

    const corrupt = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 8] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decoder.reset(corrupt, &scratch));
    try std.testing.expectEqualStrings("ChecksumMismatch", decoder.snapshot().last_error_name);
    try std.testing.expectEqual(GzipDecoder.RecoverabilityHint.payload_corrupt, decoder.snapshot().recoverability_hint);

    const bad_size = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_size);
    bad_size[bad_size.len - 4] ^= 1;
    try std.testing.expectError(error.SizeMismatch, decoder.reset(bad_size, &scratch));
    try std.testing.expectEqualStrings("SizeMismatch", decoder.snapshot().last_error_name);
    try std.testing.expectEqual(GzipDecoder.RecoverabilityHint.payload_corrupt, decoder.snapshot().recoverability_hint);
}

test "dynamic literal lookup policy separates tiny and complex alphabets" {
    const tiny = huffman.DynamicLengths{
        .header = .{ .final = true, .hlit = 257, .hdist = 1, .hclen = 4, .code_length_lengths = @splat(0) },
        .literal_max_bits = 4,
    };
    try std.testing.expectEqual(@as(u4, 9), dynamicLiteralLookupBits(tiny));

    var medium = tiny;
    medium.header.hlit = 279;
    medium.literal_max_bits = 9;
    try std.testing.expectEqual(@as(u4, 9), dynamicLiteralLookupBits(medium));

    var ten_bit = tiny;
    ten_bit.header.hlit = 279;
    ten_bit.literal_max_bits = 10;
    try std.testing.expectEqual(@as(u4, 11), dynamicLiteralLookupBits(ten_bit));

    var ordinary = tiny;
    ordinary.header.hlit = 279;
    ordinary.literal_max_bits = 12;
    try std.testing.expectEqual(@as(u4, 11), dynamicLiteralLookupBits(ordinary));

    var complex = tiny;
    complex.header.hlit = 280;
    complex.literal_max_bits = 12;
    try std.testing.expectEqual(@as(u4, 11), dynamicLiteralLookupBits(complex));

    try std.testing.expectEqual(@as(u4, 9), pngStreamingDynamicLiteralLookupBits(tiny));
    try std.testing.expectEqual(@as(u4, 9), pngStreamingDynamicLiteralLookupBits(medium));
    try std.testing.expectEqual(@as(u4, 11), pngStreamingDynamicLiteralLookupBits(ten_bit));
    try std.testing.expectEqual(@as(u4, 11), pngStreamingDynamicLiteralLookupBits(complex));
}

test "dynamic decode profile counts literals and matches" {
    const input = "literal-heavy dynamic huffman decode stage\n" ** 16;
    const raw = try encodeRawDynamicWithOptionsAlloc(std.testing.allocator, input, optionsForLevel(.default));
    defer std.testing.allocator.free(raw);

    const profile = try profileFirstDynamicDeflateBlock(raw);
    try std.testing.expectEqual(input.len, profile.output_bytes);
    try std.testing.expect(profile.literal_symbols > 0);
    try std.testing.expect(profile.literal_fast_hits + profile.literal_fast_misses >= profile.literal_symbols + profile.length_symbols);
    try std.testing.expectEqual(profile.length_symbols, profile.distance_symbols);
    var length_hist_total: usize = 0;
    for (profile.length_symbol_histogram) |count| length_hist_total += count;
    try std.testing.expectEqual(profile.length_symbols, length_hist_total);
    var distance_hist_total: usize = 0;
    for (profile.distance_symbol_histogram) |count| distance_hist_total += count;
    try std.testing.expectEqual(profile.distance_symbols, distance_hist_total);
    try std.testing.expect(profile.length_extra_bits + profile.distance_extra_bits >= profile.length_extra_reads + profile.distance_extra_reads);
    try std.testing.expect(profile.literal_lookup_bits == 9 or profile.literal_lookup_bits == 11 or profile.literal_lookup_bits == 12);
    try std.testing.expect(profile.literal_lookup_covered <= profile.literal_lookup_size);
    try std.testing.expect(profile.distance_lookup_covered <= profile.distance_lookup_size);
    try std.testing.expectEqual(@as(usize, 1), profile.dynamic_unique_table_signatures);
    try std.testing.expectEqual(@as(usize, 0), profile.dynamic_repeated_table_signatures);

    const match_class_count = profile.match_rle_count + profile.match_small_distance_count + profile.match_non_overlapping_count + profile.match_overlapping_count;
    const match_class_bytes = profile.match_rle_bytes + profile.match_small_distance_bytes + profile.match_non_overlapping_bytes + profile.match_overlapping_bytes;
    try std.testing.expectEqual(profile.distance_symbols, match_class_count);
    try std.testing.expectEqual(profile.match_bytes, match_class_bytes);
    try std.testing.expectEqual(profile.length_extra_reads, sumProfileCounters(&profile.match_class_length_extra_reads));
    try std.testing.expectEqual(profile.length_extra_bits, sumProfileCounters(&profile.match_class_length_extra_bits));
    try std.testing.expectEqual(profile.distance_extra_reads, sumProfileCounters(&profile.match_class_distance_extra_reads));
    try std.testing.expectEqual(profile.distance_extra_bits, sumProfileCounters(&profile.match_class_distance_extra_bits));
}

test "deflate profile walks stored fixed and dynamic blocks" {
    const stored_payload = "stored-profile-block";
    const fixed_payload = "fixed fixed fixed profile";
    const dynamic_payload = "dynamic profile payload " ** 32;
    const stored = try encodeRawStoredAlloc(std.testing.allocator, stored_payload);
    defer std.testing.allocator.free(stored);
    const fixed = try encodeRawFixedWithOptionsAlloc(std.testing.allocator, fixed_payload, optionsForLevel(.default));
    defer std.testing.allocator.free(fixed);
    const dynamic = try encodeRawDynamicWithOptionsAlloc(std.testing.allocator, dynamic_payload, optionsForLevel(.default));
    defer std.testing.allocator.free(dynamic);

    var raw = std.ArrayList(u8).empty;
    defer raw.deinit(std.testing.allocator);
    try raw.appendSlice(std.testing.allocator, stored);
    try raw.appendSlice(std.testing.allocator, fixed);
    raw.items[0] &= 0xfe;

    const mixed_profile = try profileDeflateBlocks(raw.items);
    try std.testing.expectEqual(@as(usize, 1), mixed_profile.stored_blocks);
    try std.testing.expectEqual(@as(usize, 1), mixed_profile.fixed_blocks);
    try std.testing.expectEqual(@as(usize, 0), mixed_profile.dynamic_blocks);
    try std.testing.expectEqual(stored_payload.len + fixed_payload.len, mixed_profile.output_bytes);
    try std.testing.expect(mixed_profile.literal_symbols > 0);
    try std.testing.expectEqual(mixed_profile.length_symbols, mixed_profile.distance_symbols);

    const dynamic_profile = try profileDeflateBlocks(dynamic);
    try std.testing.expectEqual(@as(usize, 1), dynamic_profile.dynamic_blocks);
    try std.testing.expectEqual(dynamic_payload.len, dynamic_profile.output_bytes);
    try std.testing.expect(dynamic_profile.literal_symbols > 0);
    try std.testing.expectEqual(dynamic_profile.length_symbols, dynamic_profile.distance_symbols);
}

fn sumProfileCounters(values: []const usize) usize {
    var total: usize = 0;
    for (values) |value| total += value;
    return total;
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

test "overlapping match copy doubles initialized output window" {
    var history = [_]u8{ 'a', 'b', 'c', 'd', 'e' };
    var output: [32]u8 = undefined;
    try copyMatch(&history, &output, output.len, history.len);
    try std.testing.expectEqualSlices(u8, ("abcde" ** 6) ++ "ab", &output);
}

test "preset dictionary overlapping match copy doubles seeded dictionary window" {
    const dictionary = "prefix:";
    const expected = dictionary ** 5;

    var caller_output: [expected.len]u8 = undefined;
    try copyMatchWithDictionary("", dictionary, &caller_output, caller_output.len, dictionary.len);
    try std.testing.expectEqualSlices(u8, expected, &caller_output);

    var allocated_output: std.ArrayList(u8) = .empty;
    defer allocated_output.deinit(std.testing.allocator);
    try appendMatchWithDictionary(std.testing.allocator, &allocated_output, dictionary, expected.len, dictionary.len, null);
    try std.testing.expectEqualSlices(u8, expected, allocated_output.items);
}

test "allocating fixed inflate reuses doubled copy for overlapping append matches" {
    const tokens = [_]lz77.Token{
        .{ .literal = 'a' },
        .{ .literal = 'b' },
        .{ .literal = 'c' },
        .{ .literal = 'd' },
        .{ .literal = 'e' },
        .{ .match = .{ .length = 32, .distance = 5 } },
    };
    const encoded = try encodeRawFixedTokensAlloc(std.testing.allocator, &tokens);
    defer std.testing.allocator.free(encoded);

    const expected = ("abcde" ** 7) ++ "ab";
    const allocated = try decodeRawFixedAllocStrict(std.testing.allocator, encoded);
    defer std.testing.allocator.free(allocated);
    try std.testing.expectEqualSlices(u8, expected, allocated);

    var output: [expected.len]u8 = undefined;
    const decoded = try decodeRawFixed(encoded, &output);
    try std.testing.expectEqual(expected.len, decoded.output_written);
    try std.testing.expectEqualSlices(u8, expected, &output);
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

test "small raw allocating decode uses exact owned output" {
    const raw = [_]u8{
        0x3d, 0xc6, 0x39, 0x11, 0x00, 0x00, 0x0c, 0x02, 0x30, 0x2b, 0xb5, 0x52,
        0x1e, 0xff, 0x96, 0x38, 0x16, 0x96, 0x5c, 0x1e, 0x94, 0xcb, 0x6d, 0x01,
    };
    const plain = "ABCDEABCD ABCDEABCD";
    const decoded = try decodeRawAutoAlloc(std.testing.allocator, &raw);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(plain.len, decoded.len);
    try std.testing.expectEqualSlices(u8, plain, decoded);

    var trailing = [_]u8{0} ** (raw.len + 1);
    @memcpy(trailing[0..raw.len], &raw);
    try std.testing.expectError(error.TrailingData, decodeRawAutoAlloc(std.testing.allocator, &trailing));
}

test "small raw allocating decode uses stack fast path for source-sized frames" {
    var input: [4096]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @intCast(i % 251);
    const encoded = try encodeRawStoredAlloc(std.testing.allocator, &input);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len <= stack_inflate_alloc_max_input_len);

    const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "small raw allocating decode falls back when scratch is too small" {
    var input: [stack_inflate_alloc_scratch_len + 1]u8 = undefined;
    @memset(&input, 'a');
    const encoded = try encodeRawFixedAlloc(std.testing.allocator, &input);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len <= stack_inflate_alloc_max_input_len);

    const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
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

test "gzip relaxed decode options ignore trailer checks and trailing bytes" {
    const encoded = try encodeGzipFixedAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(encoded);

    var out: [32]u8 = undefined;
    var bad_header = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_header);
    bad_header[0] = 0;
    var bad_header_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.BadGzipHeader, decodeGzipAllocExactSize(bad_header_failing.allocator(), bad_header, 7));
    try std.testing.expectEqual(@as(usize, 0), bad_header_failing.allocations);

    var reserved_block = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(reserved_block);
    const data_offset = try parseGzipHeader(reserved_block);
    reserved_block[data_offset] = 0x07;
    std.mem.writeInt(u32, reserved_block[reserved_block.len - 4 ..][0..4], 7, .little);
    var reserved_alloc_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeGzipAlloc(reserved_alloc_failing.allocator(), reserved_block));
    try std.testing.expectEqual(@as(usize, 0), reserved_alloc_failing.allocations);
    var reserved_exact_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeGzipAllocExactSize(reserved_exact_failing.allocator(), reserved_block, 7));
    try std.testing.expectEqual(@as(usize, 0), reserved_exact_failing.allocations);

    var bad_crc = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_crc);
    bad_crc[bad_crc.len - 8] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeGzip(bad_crc, &out));
    try std.testing.expectEqual(@as(usize, 7), try decodeGzipWithOptions(bad_crc, &out, .{ .ignore_crc32 = true }));
    try std.testing.expectEqualSlices(u8, "payload", out[0..7]);

    var bad_isize = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_isize);
    bad_isize[bad_isize.len - 4] ^= 1;
    try std.testing.expectError(error.SizeMismatch, decodeGzip(bad_isize, &out));
    try std.testing.expectEqual(@as(usize, 7), try decodeGzipWithOptions(bad_isize, &out, .{ .ignore_isize = true }));

    var with_trailing: [64]u8 = undefined;
    @memcpy(with_trailing[0..encoded.len], encoded);
    with_trailing[encoded.len] = 0xaa;
    const trailing = with_trailing[0 .. encoded.len + 1];
    try std.testing.expectError(error.TrailingData, decodeGzip(trailing, &out));
    try std.testing.expectEqual(@as(usize, 7), try decodeGzipWithOptions(trailing, &out, .{ .allow_trailing_data = true }));

    const trailing_alloc = try decodeGzipAllocWithOptions(std.testing.allocator, trailing, .{ .allow_trailing_data = true });
    defer std.testing.allocator.free(trailing_alloc);
    try std.testing.expectEqualSlices(u8, "payload", trailing_alloc);

    var trailing_limited_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    const trailing_limited = try decodeGzipAllocWithOptionsLimited(trailing_limited_failing.allocator(), trailing, .{ .allow_trailing_data = true }, 7);
    defer trailing_limited_failing.allocator().free(trailing_limited);
    try std.testing.expectEqualSlices(u8, "payload", trailing_limited);
    try std.testing.expectEqual(@as(usize, 1), trailing_limited_failing.allocations);

    var fully_relaxed = try std.testing.allocator.dupe(u8, trailing);
    defer std.testing.allocator.free(fully_relaxed);
    fully_relaxed[encoded.len - 8] ^= 1;
    fully_relaxed[encoded.len - 4] ^= 1;
    const relaxed = GzipDecodeOptions{ .ignore_crc32 = true, .ignore_isize = true, .allow_trailing_data = true };
    try std.testing.expectEqual(@as(usize, 7), try decodeGzipWithOptions(fully_relaxed, &out, relaxed));

    const relaxed_alloc = try decodeGzipAllocWithOptions(std.testing.allocator, fully_relaxed, relaxed);
    defer std.testing.allocator.free(relaxed_alloc);
    try std.testing.expectEqualSlices(u8, "payload", relaxed_alloc);

    const relaxed_exact = try decodeGzipAllocWithOptionsExactSize(std.testing.allocator, fully_relaxed, relaxed, 7);
    defer std.testing.allocator.free(relaxed_exact);
    try std.testing.expectEqualSlices(u8, "payload", relaxed_exact);

    try std.testing.expectError(error.OutputLimitExceeded, decodeGzipAllocWithOptionsLimited(std.testing.allocator, fully_relaxed, relaxed, 6));
    const relaxed_limited = try decodeGzipAllocWithOptionsLimited(std.testing.allocator, fully_relaxed, relaxed, 7);
    defer std.testing.allocator.free(relaxed_limited);
    try std.testing.expectEqualSlices(u8, "payload", relaxed_limited);
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

test "gzip allocation validates header before footer-size allocation" {
    var invalid = [_]u8{
        0x00, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03,
        0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x7f,
    };
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.BadGzipHeader, decodeGzipAlloc(failing.allocator(), &invalid));
    try std.testing.expectEqual(@as(usize, 0), failing.allocations);
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

test "allocating preset dictionary decode bulk-copies history-only matches" {
    const dictionary = "prefix:";
    const expected = "prefix:prefix:prefix:";
    const tokens = [_]lz77.Token{
        // Seed the output from the preset dictionary. This match still needs the
        // generic dictionary-aware path because the history is empty.
        .{ .match = .{ .length = 7, .distance = 7 } },
        // The second match is fully inside the just-decoded output history even
        // though a dictionary is still attached to the stream. It should use the
        // same bulk overlapping-copy path as no-dictionary allocating inflate
        // rather than byte-at-a-time dictionary fallback.
        .{ .match = .{ .length = 14, .distance = 7 } },
    };
    const fixed = try encodeRawFixedTokensAlloc(std.testing.allocator, &tokens);
    defer std.testing.allocator.free(fixed);
    const dynamic = try encodeRawDynamicTokensAlloc(std.testing.allocator, &tokens);
    defer std.testing.allocator.free(dynamic);

    for ([_][]const u8{ fixed, dynamic }) |raw| {
        const decoded = try decodeRawAutoAllocWithDictionary(std.testing.allocator, raw, dictionary);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, expected, decoded);

        var exact: [expected.len]u8 = undefined;
        const written = try decodeRawAutoWithDictionary(raw, dictionary, &exact);
        try std.testing.expectEqual(@as(usize, expected.len), written.output_written);
        try std.testing.expectEqualSlices(u8, expected, &exact);

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

    const zlib_header_only = &.{ 0x78, 0x01 };
    var zlib_empty_payload_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TruncatedFrame, decodeZlibAllocExactSize(zlib_empty_payload_failing.allocator(), zlib_header_only, input.len));
    try std.testing.expectEqual(@as(usize, 0), zlib_empty_payload_failing.allocations);

    const zlib_frame = try encodeZlibDynamicWithOptionsAlloc(std.testing.allocator, input, optionsForLevel(.default));
    defer std.testing.allocator.free(zlib_frame);
    const zlib_exact = try decodeZlibAllocExactSize(std.testing.allocator, zlib_frame, input.len);
    defer std.testing.allocator.free(zlib_exact);
    try std.testing.expectEqualSlices(u8, input, zlib_exact);
    try std.testing.expectError(error.SizeMismatch, decodeZlibAllocExactSize(std.testing.allocator, zlib_frame, input.len - 1));
    try std.testing.expectError(error.SizeMismatch, decodeZlibAllocExactSize(std.testing.allocator, zlib_frame, input.len + 1));

    var gzip_empty_payload_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TruncatedFrame, decodeGzipAllocExactSize(gzip_empty_payload_failing.allocator(), &gzip_header, input.len));
    try std.testing.expectEqual(@as(usize, 0), gzip_empty_payload_failing.allocations);

    const gzip_frame = try encodeGzipDynamicWithOptionsAlloc(std.testing.allocator, input, optionsForLevel(.default));
    defer std.testing.allocator.free(gzip_frame);
    const gzip_exact = try decodeGzipAllocExactSize(std.testing.allocator, gzip_frame, input.len);
    defer std.testing.allocator.free(gzip_exact);
    try std.testing.expectEqualSlices(u8, input, gzip_exact);
    try std.testing.expectError(error.SizeMismatch, decodeGzipAllocExactSize(std.testing.allocator, gzip_frame, input.len - 1));
    try std.testing.expectError(error.SizeMismatch, decodeGzipAllocExactSize(std.testing.allocator, gzip_frame, input.len + 1));

    const zlib_stored_frame = try encodeZlibStoredAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(zlib_stored_frame);
    var zlib_stored_short_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.SizeMismatch, decodeZlibAllocExactSize(zlib_stored_short_failing.allocator(), zlib_stored_frame, input.len - 1));
    try std.testing.expectEqual(@as(usize, 0), zlib_stored_short_failing.allocations);
    var bad_zlib_stored_adler = try std.testing.allocator.dupe(u8, zlib_stored_frame);
    defer std.testing.allocator.free(bad_zlib_stored_adler);
    bad_zlib_stored_adler[bad_zlib_stored_adler.len - 1] ^= 1;
    var zlib_stored_adler_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibAllocExactSize(zlib_stored_adler_failing.allocator(), bad_zlib_stored_adler, input.len));
    try std.testing.expectEqual(@as(usize, 0), zlib_stored_adler_failing.allocations);

    const gzip_stored_frame = try encodeGzipStoredAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(gzip_stored_frame);
    var gzip_stored_short_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.SizeMismatch, decodeGzipAllocExactSize(gzip_stored_short_failing.allocator(), gzip_stored_frame, input.len - 1));
    try std.testing.expectEqual(@as(usize, 0), gzip_stored_short_failing.allocations);
    var bad_gzip_stored_crc = try std.testing.allocator.dupe(u8, gzip_stored_frame);
    defer std.testing.allocator.free(bad_gzip_stored_crc);
    bad_gzip_stored_crc[bad_gzip_stored_crc.len - 8] ^= 1;
    var gzip_stored_crc_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.ChecksumMismatch, decodeGzipAllocExactSize(gzip_stored_crc_failing.allocator(), bad_gzip_stored_crc, input.len));
    try std.testing.expectEqual(@as(usize, 0), gzip_stored_crc_failing.allocations);
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

    const raw_stored = try encodeRawStoredAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(raw_stored);
    var raw_stored_short_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.SizeMismatch, decodeRawAutoAllocWithDictionaryExactSize(raw_stored_short_failing.allocator(), raw_stored, dictionary, input.len - 1));
    try std.testing.expectEqual(@as(usize, 0), raw_stored_short_failing.allocations);
    var raw_stored_trailing = try std.testing.allocator.alloc(u8, raw_stored.len + 1);
    defer std.testing.allocator.free(raw_stored_trailing);
    @memcpy(raw_stored_trailing[0..raw_stored.len], raw_stored);
    raw_stored_trailing[raw_stored.len] = 0;
    var raw_stored_trailing_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TrailingData, decodeRawAutoAllocWithDictionaryExactSize(raw_stored_trailing_failing.allocator(), raw_stored_trailing, dictionary, input.len));
    try std.testing.expectEqual(@as(usize, 0), raw_stored_trailing_failing.allocations);

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

    var raw_limit_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutputLimitExceeded, decodeRawAutoAllocLimited(raw_limit_failing.allocator(), raw, 4));
    try std.testing.expectEqual(@as(usize, 0), raw_limit_failing.allocations);

    var raw_exact_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    const raw_direct = try decodeRawAutoAllocLimited(raw_exact_failing.allocator(), raw, 5);
    defer raw_exact_failing.allocator().free(raw_direct);
    try std.testing.expectEqualSlices(u8, "hello", raw_direct);
    try std.testing.expectEqual(@as(usize, 1), raw_exact_failing.allocations);

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

test "dynamic literal encoder omits unused distance alphabet" {
    const input = "literal-only dynamic blocks should not need distance codes";
    const raw = try encodeRawDynamicLiteralAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(raw);

    const info = try parseRawDeflateHeaderInfo(raw);
    try std.testing.expectEqual(RawDeflateBlockType.dynamic, info.block_type);
    try std.testing.expectEqual(@as(u16, 1), info.dynamic_hdist.?);
    try std.testing.expectEqual(@as(u16, 0), info.dynamic_distance_nonzero.?);
    try std.testing.expectEqual(info.dynamic_hdist.?, info.dynamic_distance_zero.?);
    try std.testing.expectEqual(@as(u8, 0), info.dynamic_distance_max_bits.?);

    const decoded = try decodeRawDynamicAllocStrict(std.testing.allocator, raw);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
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

test "dynamic code length RLE preserves literal distance boundary runs" {
    const lit_lengths = [_]u4{5} ++ [_]u4{0} ** 20;
    const dist_lengths = [_]u4{0} ** 4;
    const ops = try buildCodeLengthOps(&lit_lengths, &dist_lengths);

    // HLIT and HDIST are serialized as one contiguous code-length sequence in
    // RFC 1951. Keeping that boundary visible to the RLE planner lets a trailing
    // literal zero run merge with leading distance zeros, avoiding a redundant
    // repeat opcode in sparse dynamic blocks.
    try std.testing.expectEqual(@as(usize, 2), ops.len);
    try std.testing.expectEqual(@as(u8, 5), ops.items[0].symbol);
    try std.testing.expectEqual(@as(u8, 18), ops.items[1].symbol);
    try std.testing.expectEqual(@as(u8, 24 - 11), ops.items[1].extra_value);
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
    try std.testing.expectEqual(@as(usize, 16 * 1024), optionsForLevel(.fastest).lz77_options.window_len);
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

    try std.testing.expectEqual(BlockSelection.stored_fixed_dynamic, optionsForLevel(.fastest).block_selection);
    try std.testing.expectEqual(BlockSelection.stored_fixed, optionsForLevel(.fast).block_selection);
    try std.testing.expectEqual(BlockSelection.stored_fixed_dynamic, optionsForLevel(.default).block_selection);
    try std.testing.expectEqual(BlockSelection.stored_fixed_dynamic, optionsForLevel(.best).block_selection);

    try std.testing.expectEqual(@as(usize, 4), optionsForLevel(.fastest).lz77_options.min_match);
    try std.testing.expectEqual(@as(usize, 4), optionsForLevel(.fast).lz77_options.min_match);
    try std.testing.expectEqual(@as(usize, 3), optionsForLevel(.default).lz77_options.min_match);
    try std.testing.expectEqual(@as(usize, 3), optionsForLevel(.best).lz77_options.min_match);

    try std.testing.expectEqual(@as(usize, 6), optionsForLevel(.fastest).lz77_options.max_chain);
    try std.testing.expectEqual(@as(usize, 32), optionsForLevel(.fast).lz77_options.max_chain);
    try std.testing.expectEqual(@as(usize, 96), optionsForLevel(.fastest).lz77_options.max_match);
    try std.testing.expectEqual(@as(usize, 128), optionsForLevel(.fast).lz77_options.max_match);
}

test "fastest preset can choose dynamic blocks for source-like payloads" {
    const input =
        \\const std = @import("std");
        \\pub fn checksum(bytes: []const u8) u32 {
        \\    var value: u32 = 0;
        \\    for (bytes) |byte| value = value *% 33 + byte;
        \\    return value;
        \\}
        \\
    ** 16;
    var legacy = optionsForLevel(.fastest);
    legacy.block_selection = .stored_fixed;

    const tuned = try encodeRawBestAlloc(std.testing.allocator, input, optionsForLevel(.fastest));
    defer std.testing.allocator.free(tuned);
    const legacy_encoded = try encodeRawBestAlloc(std.testing.allocator, input, legacy);
    defer std.testing.allocator.free(legacy_encoded);

    const decoded = try decodeRawAutoAlloc(std.testing.allocator, tuned);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    try std.testing.expect(tuned.len < legacy_encoded.len);
}

fn fillBestFallbackRegressionInput(out: []u8) void {
    var seed: u32 = 0x1234567 + 30 * 977;
    for (out, 0..) |*byte, i| {
        seed = seed *% 1664525 +% 1013904223;
        const noise: u8 = @truncate(seed >> 24);
        byte.* = if (i % 5 == 0) noise else "0123456789abcdef"[(i + (i / 257)) % 16];
    }
}

fn fillBestFilteredFallbackRegressionInput(out: []u8) void {
    var seed: u32 = 0x7654321;
    for (out, 0..) |*byte, i| {
        seed = seed *% 1103515245 +% 12345;
        const noise: u8 = @truncate(seed >> 24);
        byte.* = if (i % 11 < 7) "abcdefghijklmnop"[(i + (i / 31)) % 16] else noise;
    }
}

test "best preset can keep filtered parser output when it is smaller" {
    var input: [4096]u8 = undefined;
    fillBestFilteredFallbackRegressionInput(&input);

    var filtered_best_options = optionsForLevel(.best);
    filtered_best_options.strategy = .filtered;

    const filtered = try encodeRawBestAlloc(std.testing.allocator, &input, filtered_best_options);
    defer std.testing.allocator.free(filtered);
    const best = try encodeRawBestAlloc(std.testing.allocator, &input, optionsForLevel(.best));
    defer std.testing.allocator.free(best);
    try std.testing.expect(best.len <= filtered.len);
    const decoded = try decodeRawAutoAlloc(std.testing.allocator, best);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "best preset falls back when default parser writes smaller frames" {
    var input: [512]u8 = undefined;
    fillBestFallbackRegressionInput(&input);

    const default_options = optionsForLevel(.default);
    const best_options = optionsForLevel(.best);

    const raw_default = try encodeRawBestAlloc(std.testing.allocator, &input, default_options);
    defer std.testing.allocator.free(raw_default);
    const raw_best = try encodeRawBestAlloc(std.testing.allocator, &input, best_options);
    defer std.testing.allocator.free(raw_best);
    try std.testing.expect(raw_best.len <= raw_default.len);
    const raw_decoded = try decodeRawAutoAlloc(std.testing.allocator, raw_best);
    defer std.testing.allocator.free(raw_decoded);
    try std.testing.expectEqualSlices(u8, &input, raw_decoded);

    const zlib_default = try encodeZlibBestAlloc(std.testing.allocator, &input, default_options);
    defer std.testing.allocator.free(zlib_default);
    const zlib_best = try encodeZlibBestAlloc(std.testing.allocator, &input, best_options);
    defer std.testing.allocator.free(zlib_best);
    try std.testing.expect(zlib_best.len <= zlib_default.len);
    const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_best);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, &input, zlib_decoded);

    const gzip_default = try encodeGzipBestAlloc(std.testing.allocator, &input, default_options);
    defer std.testing.allocator.free(gzip_default);
    const gzip_best = try encodeGzipBestAlloc(std.testing.allocator, &input, best_options);
    defer std.testing.allocator.free(gzip_best);
    try std.testing.expect(gzip_best.len <= gzip_default.len);
    const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_best);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, &input, gzip_decoded);
}

test "zlib numeric compression levels map to stable Vort presets" {
    try std.testing.expectError(error.InvalidBlockPlan, optionsForZlibLevel(0));
    try std.testing.expectEqual(optionsForLevel(.fastest).parser, (try optionsForZlibLevel(1)).parser);
    try std.testing.expectEqual(optionsForLevel(.fast).parser, (try optionsForZlibLevel(3)).parser);
    try std.testing.expectEqual(optionsForLevel(.default).parser, (try optionsForZlibLevel(6)).parser);
    try std.testing.expectEqual(optionsForLevel(.best).parser, (try optionsForZlibLevel(9)).parser);
    try std.testing.expectEqual(optionsForLevel(.fastest).lz77_options.max_chain, (try optionsForZlibLevel(1)).lz77_options.max_chain);
    try std.testing.expect((try optionsForZlibLevel(2)).lz77_options.max_chain > (try optionsForZlibLevel(1)).lz77_options.max_chain);
    try std.testing.expectEqual(ParserMode.lazy, (try optionsForZlibLevel(4)).parser);
    try std.testing.expect((try optionsForZlibLevel(5)).lz77_options.max_chain > (try optionsForZlibLevel(4)).lz77_options.max_chain);
    try std.testing.expect((try optionsForZlibLevel(7)).lz77_options.max_chain > (try optionsForZlibLevel(6)).lz77_options.max_chain);
    try std.testing.expectEqual(ParserMode.optimal, (try optionsForZlibLevel(8)).parser);
    try std.testing.expect((try optionsForZlibLevel(8)).lz77_options.max_chain < (try optionsForZlibLevel(9)).lz77_options.max_chain);
    try std.testing.expectError(error.InvalidBlockPlan, optionsForZlibLevel(10));
}

test "zlib numeric level encoders round trip raw zlib and gzip wrappers" {
    const input = "png rows and common zlib payloads want numeric levels" ** 4;
    const dictionary = "png rows and common ";
    inline for (0..10) |level_usize| {
        const level: u4 = @intCast(level_usize);

        const raw = try encodeRawLevelAlloc(std.testing.allocator, input, level);
        defer std.testing.allocator.free(raw);
        const raw_decoded = try decodeRawAutoAlloc(std.testing.allocator, raw);
        defer std.testing.allocator.free(raw_decoded);
        try std.testing.expectEqualSlices(u8, input, raw_decoded);
        if (level == 0) {
            const stored = try encodeRawStoredAlloc(std.testing.allocator, input);
            defer std.testing.allocator.free(stored);
            try std.testing.expectEqualSlices(u8, stored, raw);
        }

        const zlib_frame = try encodeZlibLevelAlloc(std.testing.allocator, input, level);
        defer std.testing.allocator.free(zlib_frame);
        const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
        defer std.testing.allocator.free(zlib_decoded);
        try std.testing.expectEqualSlices(u8, input, zlib_decoded);

        const gzip_frame = try encodeGzipLevelAlloc(std.testing.allocator, input, level);
        defer std.testing.allocator.free(gzip_frame);
        const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
        defer std.testing.allocator.free(gzip_decoded);
        try std.testing.expectEqualSlices(u8, input, gzip_decoded);

        const raw_dict = try encodeRawLevelWithDictionaryAlloc(std.testing.allocator, input, dictionary, level);
        defer std.testing.allocator.free(raw_dict);
        const raw_dict_decoded = try decodeRawAutoAllocWithDictionary(std.testing.allocator, raw_dict, dictionary);
        defer std.testing.allocator.free(raw_dict_decoded);
        try std.testing.expectEqualSlices(u8, input, raw_dict_decoded);

        const zlib_dict = try encodeZlibLevelWithDictionaryAlloc(std.testing.allocator, input, dictionary, level);
        defer std.testing.allocator.free(zlib_dict);
        const zlib_dict_decoded = try decodeZlibAllocWithDictionary(std.testing.allocator, zlib_dict, dictionary);
        defer std.testing.allocator.free(zlib_dict_decoded);
        try std.testing.expectEqualSlices(u8, input, zlib_dict_decoded);

        if (level == 0) {
            const zlib_stored = try encodeZlibStoredAlloc(std.testing.allocator, input);
            defer std.testing.allocator.free(zlib_stored);
            try std.testing.expectEqualSlices(u8, zlib_stored, zlib_frame);

            const zlib_stored_dict = try encodeZlibStoredWithDictionaryAlloc(std.testing.allocator, input, dictionary);
            defer std.testing.allocator.free(zlib_stored_dict);
            try std.testing.expectEqualSlices(u8, zlib_stored_dict, zlib_dict);
        }
    }
    try std.testing.expectError(error.InvalidBlockPlan, encodeRawLevelAlloc(std.testing.allocator, input, 10));
    try std.testing.expectError(error.InvalidBlockPlan, encodeRawLevelWithDictionaryAlloc(std.testing.allocator, input, dictionary, 10));
    try std.testing.expectError(error.InvalidBlockPlan, encodeZlibLevelAlloc(std.testing.allocator, input, 10));
    try std.testing.expectError(error.InvalidBlockPlan, encodeZlibLevelWithDictionaryAlloc(std.testing.allocator, input, dictionary, 10));
    try std.testing.expectError(error.InvalidBlockPlan, encodeGzipLevelAlloc(std.testing.allocator, input, 10));
}

test "best level uses production optimal parser with full strategy wrappers" {
    const input = "abcabcabcabc lorem lorem lorem " ** 8 ++ "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const best = optionsForLevel(.best);
    try std.testing.expectEqual(ParserMode.optimal, best.parser);
    try std.testing.expectEqual(lz77.default_best_optimal_candidates, best.lz77_options.max_candidates);
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

test "gzip concatenated stored members decode and validate per-member trailers" {
    const first = try encodeGzipStoredAlloc(std.testing.allocator, "stored ");
    defer std.testing.allocator.free(first);
    const second = try encodeGzipStoredAlloc(std.testing.allocator, "member");
    defer std.testing.allocator.free(second);

    var cat: std.ArrayList(u8) = .empty;
    defer cat.deinit(std.testing.allocator);
    try cat.appendSlice(std.testing.allocator, first);
    try cat.appendSlice(std.testing.allocator, second);

    const decoded = try decodeGzipConcatenatedAlloc(std.testing.allocator, cat.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "stored member", decoded);

    var into: ["stored member".len]u8 = undefined;
    try std.testing.expectEqual(@as(usize, into.len), try decodeGzipConcatenated(cat.items, &into));
    try std.testing.expectEqualSlices(u8, "stored member", &into);

    const exact = try decodeGzipConcatenatedAllocExactSize(std.testing.allocator, cat.items, into.len);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, &into, exact);
    var exact_short_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.SizeMismatch, decodeGzipConcatenatedAllocExactSize(exact_short_failing.allocator(), cat.items, into.len - 1));
    try std.testing.expectEqual(@as(usize, 0), exact_short_failing.allocations);
    var limited_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutputLimitExceeded, decodeGzipConcatenatedAllocLimited(limited_failing.allocator(), cat.items, into.len - 1));
    try std.testing.expectEqual(@as(usize, 0), limited_failing.allocations);
    try std.testing.expectError(error.OutputLimitExceeded, decodeGzipConcatenatedAllocLimited(std.testing.allocator, cat.items, into.len - 1));

    var bad_second_crc = try std.testing.allocator.dupe(u8, cat.items);
    defer std.testing.allocator.free(bad_second_crc);
    bad_second_crc[bad_second_crc.len - 8] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeGzipConcatenatedAlloc(std.testing.allocator, bad_second_crc));
    try std.testing.expectError(error.ChecksumMismatch, decodeGzipConcatenated(bad_second_crc, &into));
    var bad_second_alloc_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.ChecksumMismatch, decodeGzipConcatenatedAlloc(bad_second_alloc_failing.allocator(), bad_second_crc));
    try std.testing.expectEqual(@as(usize, 0), bad_second_alloc_failing.allocations);
    var bad_second_exact_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.ChecksumMismatch, decodeGzipConcatenatedAllocExactSize(bad_second_exact_failing.allocator(), bad_second_crc, into.len));
    try std.testing.expectEqual(@as(usize, 0), bad_second_exact_failing.allocations);

    const relaxed = GzipDecodeOptions{ .ignore_crc32 = true };
    const relaxed_alloc = try decodeGzipConcatenatedAllocWithOptions(std.testing.allocator, bad_second_crc, relaxed);
    defer std.testing.allocator.free(relaxed_alloc);
    try std.testing.expectEqualSlices(u8, &into, relaxed_alloc);

    var relaxed_into: ["stored member".len]u8 = undefined;
    try std.testing.expectEqual(@as(usize, relaxed_into.len), try decodeGzipConcatenatedWithOptions(bad_second_crc, &relaxed_into, relaxed));
    try std.testing.expectEqualSlices(u8, &into, &relaxed_into);

    const relaxed_exact = try decodeGzipConcatenatedAllocWithOptionsExactSize(std.testing.allocator, bad_second_crc, relaxed, into.len);
    defer std.testing.allocator.free(relaxed_exact);
    try std.testing.expectEqualSlices(u8, &into, relaxed_exact);
    try std.testing.expectError(error.OutputLimitExceeded, decodeGzipConcatenatedAllocWithOptionsLimited(std.testing.allocator, bad_second_crc, relaxed, into.len - 1));
}

test "gzip concatenated decoders preserve later members after an empty member" {
    const first = try encodeGzipFixedAlloc(std.testing.allocator, "hello ");
    defer std.testing.allocator.free(first);
    const empty = try encodeGzipFixedAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    const third = try encodeGzipFixedAlloc(std.testing.allocator, "world");
    defer std.testing.allocator.free(third);

    var cat: std.ArrayList(u8) = .empty;
    defer cat.deinit(std.testing.allocator);
    try cat.appendSlice(std.testing.allocator, first);
    try cat.appendSlice(std.testing.allocator, empty);
    try cat.appendSlice(std.testing.allocator, third);

    const decoded = try decodeGzipConcatenatedAlloc(std.testing.allocator, cat.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello world", decoded);

    var into: [11]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 11), try decodeGzipConcatenated(cat.items, &into));
    try std.testing.expectEqualSlices(u8, "hello world", &into);
}

test "gzip concatenated decoders reject corrupt third member after empty middle member" {
    const first = try encodeGzipFixedAlloc(std.testing.allocator, "hello ");
    defer std.testing.allocator.free(first);
    const empty = try encodeGzipFixedAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    const third = try encodeGzipFixedAlloc(std.testing.allocator, "world");
    defer std.testing.allocator.free(third);

    var cat: std.ArrayList(u8) = .empty;
    defer cat.deinit(std.testing.allocator);
    try cat.appendSlice(std.testing.allocator, first);
    try cat.appendSlice(std.testing.allocator, empty);
    try cat.appendSlice(std.testing.allocator, third);

    try std.testing.expectError(error.TruncatedFrame, decodeGzipConcatenatedAlloc(std.testing.allocator, cat.items[0 .. cat.items.len - 8]));

    var bad_crc = try std.testing.allocator.dupe(u8, cat.items);
    defer std.testing.allocator.free(bad_crc);
    bad_crc[bad_crc.len - 8] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeGzipConcatenatedAlloc(std.testing.allocator, bad_crc));

    var bad_isize = try std.testing.allocator.dupe(u8, cat.items);
    defer std.testing.allocator.free(bad_isize);
    bad_isize[bad_isize.len - 4] ^= 1;
    try std.testing.expectError(error.SizeMismatch, decodeGzipConcatenatedAlloc(std.testing.allocator, bad_isize));
}

test "gzip concatenated decoders reject empty input" {
    var out: [1]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeGzipConcatenated("", &out));
    try std.testing.expectError(error.TruncatedFrame, decodeGzipConcatenatedAlloc(std.testing.allocator, ""));
    try std.testing.expectError(error.TruncatedFrame, decodeGzipConcatenatedAllocLimited(std.testing.allocator, "", 1));
    try std.testing.expectError(error.TruncatedFrame, decodeGzipConcatenatedAllocExactSize(std.testing.allocator, "", 0));

    const valid = try encodeGzipFixedAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(valid);
    var bad_first_header = try std.testing.allocator.dupe(u8, valid);
    defer std.testing.allocator.free(bad_first_header);
    bad_first_header[0] = 0;
    var bad_first_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.BadGzipHeader, decodeGzipConcatenatedAllocExactSize(bad_first_failing.allocator(), bad_first_header, 5));
    try std.testing.expectEqual(@as(usize, 0), bad_first_failing.allocations);
    var header_only_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.TruncatedFrame, decodeGzipConcatenatedAllocExactSize(header_only_failing.allocator(), &gzip_header, 5));
    try std.testing.expectEqual(@as(usize, 0), header_only_failing.allocations);
    var reserved_first = gzip_header ++ [_]u8{0x07};
    var reserved_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeGzipConcatenatedAllocExactSize(reserved_failing.allocator(), &reserved_first, 5));
    try std.testing.expectEqual(@as(usize, 0), reserved_failing.allocations);
    var reserved_alloc_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeGzipConcatenatedAlloc(reserved_alloc_failing.allocator(), &reserved_first));
    try std.testing.expectEqual(@as(usize, 0), reserved_alloc_failing.allocations);
    var reserved_limited_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeGzipConcatenatedAllocLimited(reserved_limited_failing.allocator(), &reserved_first, 5));
    try std.testing.expectEqual(@as(usize, 0), reserved_limited_failing.allocations);
}

test "gzip member inspector reports concatenated offsets and trailer diagnostics" {
    const a = try encodeGzipFixedAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(a);
    const b = try encodeGzipFixedAlloc(std.testing.allocator, "world");
    defer std.testing.allocator.free(b);
    var cat: std.ArrayList(u8) = .empty;
    defer cat.deinit(std.testing.allocator);
    try cat.appendSlice(std.testing.allocator, a);
    try cat.appendSlice(std.testing.allocator, b);

    const first = try inspectGzipMemberAlloc(std.testing.allocator, cat.items, 0);
    try std.testing.expectEqual(@as(usize, 0), first.member_index);
    try std.testing.expectEqual(@as(usize, 0), first.member_offset);
    try std.testing.expectEqual(@as(usize, gzip_header.len), first.deflate_offset);
    try std.testing.expectEqual(a.len - gzip_header.len - 8, first.deflate_bytes);
    try std.testing.expectEqual(@as(usize, 5), first.output_bytes);
    try std.testing.expectEqual(first.deflate_offset + first.deflate_bytes, first.footer_offset);
    try std.testing.expectEqual(first.footer_offset + 8, first.end_offset);
    try std.testing.expectEqual(a.len, first.end_offset);
    try std.testing.expectEqual(checksum.crc32Best("hello"), first.footer_crc32);
    try std.testing.expectEqual(first.footer_crc32, first.crc32);
    try std.testing.expect(first.crc32_matches);
    try std.testing.expectEqual(@as(u32, 5), first.footer_isize);
    try std.testing.expectEqual(first.footer_isize, first.isize);
    try std.testing.expect(first.isize_matches);

    const second = try inspectGzipMemberAlloc(std.testing.allocator, cat.items, 1);
    try std.testing.expectEqual(@as(usize, 1), second.member_index);
    try std.testing.expectEqual(a.len, second.member_offset);
    try std.testing.expectEqual(a.len + gzip_header.len, second.deflate_offset);
    try std.testing.expectEqual(b.len - gzip_header.len - 8, second.deflate_bytes);
    try std.testing.expectEqual(@as(usize, 5), second.output_bytes);
    try std.testing.expectEqual(cat.items.len, second.end_offset);
    try std.testing.expectEqual(checksum.crc32Best("world"), second.footer_crc32);
    try std.testing.expectEqual(second.footer_crc32, second.crc32);
    try std.testing.expect(second.crc32_matches);
    try std.testing.expectEqual(@as(u32, 5), second.footer_isize);
    try std.testing.expectEqual(second.footer_isize, second.isize);
    try std.testing.expect(second.isize_matches);
    try std.testing.expectError(error.RangeOutOfBounds, inspectGzipMemberAlloc(std.testing.allocator, cat.items, 2));

    const chunks = [_][]const u8{
        cat.items[0 .. a.len - 1],
        cat.items[a.len - 1 .. a.len + 2],
        cat.items[a.len + 2 ..],
    };
    var compressed_scratch: [128]u8 = undefined;
    const chunk_second = try inspectGzipMemberFromChunksAlloc(std.testing.allocator, &chunks, &compressed_scratch, 1);
    try std.testing.expectEqual(second.member_index, chunk_second.member_index);
    try std.testing.expectEqual(second.member_offset, chunk_second.member_offset);
    try std.testing.expectEqual(second.deflate_offset, chunk_second.deflate_offset);
    try std.testing.expectEqual(second.deflate_bytes, chunk_second.deflate_bytes);
    try std.testing.expectEqual(second.output_bytes, chunk_second.output_bytes);
    try std.testing.expectEqual(second.footer_offset, chunk_second.footer_offset);
    try std.testing.expectEqual(second.end_offset, chunk_second.end_offset);
    try std.testing.expect(chunk_second.crc32_matches);
    try std.testing.expect(chunk_second.isize_matches);
    try std.testing.expectError(error.OutputTooSmall, inspectGzipMemberFromChunksAlloc(std.testing.allocator, &chunks, compressed_scratch[0 .. cat.items.len - 1], 1));
}

test "gzip member inspector reports trailer mismatches without rejecting payload" {
    const gzip_frame = try encodeGzipFixedAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(gzip_frame);

    var bad_crc = try std.testing.allocator.dupe(u8, gzip_frame);
    defer std.testing.allocator.free(bad_crc);
    bad_crc[bad_crc.len - 8] ^= 1;
    const crc_info = try inspectGzipMemberAlloc(std.testing.allocator, bad_crc, 0);
    try std.testing.expectEqual(checksum.crc32Best("hello"), crc_info.crc32);
    try std.testing.expect(crc_info.footer_crc32 != crc_info.crc32);
    try std.testing.expect(!crc_info.crc32_matches);
    try std.testing.expect(crc_info.isize_matches);

    var bad_isize = try std.testing.allocator.dupe(u8, gzip_frame);
    defer std.testing.allocator.free(bad_isize);
    bad_isize[bad_isize.len - 4] ^= 1;
    const isize_info = try inspectGzipMemberAlloc(std.testing.allocator, bad_isize, 0);
    try std.testing.expect(isize_info.crc32_matches);
    try std.testing.expect(isize_info.footer_isize != isize_info.isize);
    try std.testing.expect(!isize_info.isize_matches);

    try std.testing.expectError(error.OutputLimitExceeded, inspectGzipMemberAllocLimited(std.testing.allocator, gzip_frame, 0, 4));
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
    try std.testing.expectEqual(@as(usize, 8), inflateOutputCapacityHint(1));
    try std.testing.expectEqual(@as(usize, 256), inflateOutputCapacityHint(32));
    try std.testing.expectEqual(@as(usize, 512), inflateOutputCapacityHint(64));
    try std.testing.expectEqual(@as(usize, 4160), inflateOutputCapacityHint(65));
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
