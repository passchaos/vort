const std = @import("std");
const core = @import("core.zig");
const checksum_mod = @import("checksum.zig");
const dictionary_mod = @import("dictionary.zig");
const huffman = @import("huffman.zig");

pub const Error = core.Error || std.mem.Allocator.Error;

pub const default_compression_level: c_int = 1;

const frame_magic = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd };
const frame_magic_u32: u32 = 0xfd2fb528;
const skippable_magic_min: u32 = 0x184d2a50;
const skippable_magic_max: u32 = 0x184d2a5f;
const min_rle_split_len = 12;
const initial_repeated_offsets = [3]usize{ 1, 4, 8 };
const duplicate_hash_bits = 15;
const duplicate_hash_table_len = 1 << duplicate_hash_bits;
const duplicate_hash_invalid = std.math.maxInt(u32);
const duplicate_hash_candidates = 8;
const max_bootstrap_sequence_count = 32;
const min_compressed_sequence_table_count = 12;
const max_predefined_sequence_states = 64;
const mixed_match_path_search_budget = 512;
const repeated_pattern_period_max = 64;
const repeated_pattern_start_scan = 48;
const max_direct_huffman_symbol = 128;

pub const native_max_match_search_budget: usize = mixed_match_path_search_budget;
pub const native_max_direct_huffman_symbol: u8 = max_direct_huffman_symbol;
pub const native_dictionary_window_len: usize = std.compress.zstd.default_window_len;

const ll_base = [_]usize{
    0,      1,      2,      3,       4,     5,     6,     7,
    8,      9,      10,     11,      12,    13,    14,    15,
    16,     18,     20,     22,      24,    28,    32,    40,
    48,     64,     0x80,   0x100,   0x200, 0x400, 0x800, 0x1000,
    0x2000, 0x4000, 0x8000, 0x10000,
};

const ll_bits = [_]u8{
    0,  0,  0,  0,  0, 0,  0,  0,
    0,  0,  0,  0,  0, 0,  0,  0,
    1,  1,  1,  1,  2, 2,  3,  3,
    4,  6,  7,  8,  9, 10, 11, 12,
    13, 14, 15, 16,
};

const ml_base = [_]usize{
    3,      4,      5,      6,      7,       8,     9,     10,
    11,     12,     13,     14,     15,      16,    17,    18,
    19,     20,     21,     22,     23,      24,    25,    26,
    27,     28,     29,     30,     31,      32,    33,    34,
    35,     37,     39,     41,     43,      47,    51,    59,
    67,     83,     99,     0x83,   0x103,   0x203, 0x403, 0x803,
    0x1003, 0x2003, 0x4003, 0x8003, 0x10003,
};

const ml_bits = [_]u8{
    0,  0,  0,  0,  0,  0, 0,  0,
    0,  0,  0,  0,  0,  0, 0,  0,
    0,  0,  0,  0,  0,  0, 0,  0,
    0,  0,  0,  0,  0,  0, 0,  0,
    1,  1,  1,  1,  2,  2, 3,  3,
    4,  4,  5,  7,  8,  9, 10, 11,
    12, 13, 14, 15, 16,
};

const of_base = [_]usize{
    0,        1,         1,         5,         0xD,       0x1D,       0x3D,       0x7D,
    0xFD,     0x1FD,     0x3FD,     0x7FD,     0xFFD,     0x1FFD,     0x3FFD,     0x7FFD,
    0xFFFD,   0x1FFFD,   0x3FFFD,   0x7FFFD,   0xFFFFD,   0x1FFFFD,   0x3FFFFD,   0x7FFFFD,
    0xFFFFFD, 0x1FFFFFD, 0x3FFFFFD, 0x7FFFFFD, 0xFFFFFFD, 0x1FFFFFFD, 0x3FFFFFFD, 0x7FFFFFFD,
};

const of_bits = [_]u8{
    0,  1,  2,  3,  4,  5,  6,  7,
    8,  9,  10, 11, 12, 13, 14, 15,
    16, 17, 18, 19, 20, 21, 22, 23,
    24, 25, 26, 27, 28, 29, 30, 31,
};

extern fn ZSTD_compressBound(srcSize: usize) usize;
extern fn ZSTD_compress(dst: *anyopaque, dstCapacity: usize, src: *const anyopaque, srcSize: usize, compressionLevel: c_int) usize;
extern fn ZSTD_createCCtx() ?*anyopaque;
extern fn ZSTD_freeCCtx(cctx: ?*anyopaque) usize;
extern fn ZSTD_CCtx_setParameter(cctx: *anyopaque, param: c_int, value: c_int) usize;
extern fn ZSTD_compress2(cctx: *anyopaque, dst: *anyopaque, dstCapacity: usize, src: *const anyopaque, srcSize: usize) usize;
extern fn ZSTD_getFrameContentSize(src: *const anyopaque, srcSize: usize) c_ulonglong;
extern fn ZSTD_decompressBound(src: *const anyopaque, srcSize: usize) c_ulonglong;
extern fn ZSTD_decompress(dst: *anyopaque, dstCapacity: usize, src: *const anyopaque, compressedSize: usize) usize;
extern fn ZSTD_isError(code: usize) c_uint;

const zstd_content_size_unknown = std.math.maxInt(c_ulonglong);
const zstd_content_size_error = std.math.maxInt(c_ulonglong) - 1;
const zstd_c_compression_level: c_int = 100;
const zstd_c_content_size_flag: c_int = 200;
const zstd_c_checksum_flag: c_int = 201;
const StdZstdLiteralsSection = std.compress.zstd.Decompress.LiteralsSection;
const StdZstdHuffmanTree = StdZstdLiteralsSection.HuffmanTree;

pub const LibFrameOptions = struct {
    include_content_size: bool = true,
    content_checksum: bool = false,
};

pub const NativeFrameSelection = enum {
    auto,
    raw_or_rle,
    literal_only,
};

pub const NativeFrameOptions = struct {
    content_checksum: bool = true,
    include_content_size: bool = true,
    selection: NativeFrameSelection = .auto,
    block_size_max: usize = std.compress.zstd.block_size_max,
    dictionary_id: u32 = 0,
    /// Maximum branch states visited by the bootstrap mixed-match planner.
    ///
    /// Lower values trade away ratio-seeking lookahead for predictable encode
    /// latency. A value of zero disables generic duplicate/repeated match
    /// planning and mixed dictionary/duplicate/repeated branch search; explicit
    /// dictionary-only match emitters remain available when callers provide a
    /// dictionary.
    match_search_budget: usize = mixed_match_path_search_budget,
};

pub const NativeDictionary = struct {
    id: u32,
    content: []const u8,

    pub fn init(id: u32, content: []const u8) NativeDictionary {
        return .{ .id = id, .content = content };
    }

    /// Derive a stable 32-bit native Zstd Dictionary_ID from dictionary bytes.
    ///
    /// The Zstandard frame header treats a zero Dictionary_ID as absent, so fold
    /// the rare CRC-32 zero result to a fixed non-zero value.  This makes the
    /// convenience constructor safe for dictionary-aware encode/decode helpers
    /// while leaving externally assigned or stronger-catalog IDs to `init`.
    pub fn derivedId(content: []const u8) u32 {
        const id = checksum_mod.crc32(content);
        return if (id == 0) 1 else id;
    }

    /// Create a dictionary whose frame Dictionary_ID is derived from `content`.
    ///
    /// The returned dictionary borrows `content`; callers must keep the bytes
    /// alive for any encode/decode operation that references this dictionary.
    pub fn initFromContent(content: []const u8) NativeDictionary {
        return init(derivedId(content), content);
    }

    /// Validate a persisted metadata record before constructing a borrowed
    /// dictionary view from caller-owned bytes.
    pub fn initFromMetadata(metadata: dictionary_mod.Metadata, content: []const u8) Error!NativeDictionary {
        try metadata.validateBytes(content, native_dictionary_window_len);
        return init(derivedId(content), content);
    }
};

pub const NativeDictionaryTrainOptions = dictionary_mod.TrainOptions;

pub const OwnedNativeDictionary = struct {
    id: u32,
    content: []u8,

    pub fn asDictionary(self: OwnedNativeDictionary) NativeDictionary {
        return NativeDictionary.init(self.id, self.content);
    }

    /// Summarize trained bytes for application-level dictionary catalogs.
    ///
    /// Zstd frames expose a 32-bit `Dictionary_ID`; this metadata carries the
    /// shared wider dictionary fingerprint and the decoder window used by the
    /// native Zstd facade so callers can persist enough information to validate
    /// catalogs before selecting the borrowed dictionary returned by
    /// `asDictionary`.
    pub fn metadata(self: OwnedNativeDictionary) dictionary_mod.Metadata {
        return .fromBytes(self.content, native_dictionary_window_len);
    }

    pub fn deinit(self: OwnedNativeDictionary, allocator: std.mem.Allocator) void {
        allocator.free(self.content);
    }
};

/// Train an owned native Zstd preset dictionary from representative samples.
///
/// This is a lightweight deterministic trainer rather than zstd's full cover or
/// fastCover workflow.  It still closes the library API gap for callers that
/// need allocator-owned dictionary bytes plus a stable frame Dictionary_ID
/// without routing through a CLI or inventing IDs at the call site.
pub fn trainNativeDictionaryAlloc(
    allocator: std.mem.Allocator,
    samples: []const []const u8,
    options: NativeDictionaryTrainOptions,
) Error!OwnedNativeDictionary {
    const content = try dictionary_mod.trainAlloc(allocator, samples, options);
    return .{ .id = NativeDictionary.derivedId(content), .content = content };
}

/// Caller-supplied preset dictionary catalog used when decoding concatenated
/// native streams whose frames can reference different Dictionary_ID values.
pub const NativeDictionarySet = struct {
    dictionaries: []const NativeDictionary,

    pub fn init(dictionaries: []const NativeDictionary) NativeDictionarySet {
        return .{ .dictionaries = dictionaries };
    }

    /// Build a dictionary catalog and reject IDs that cannot be resolved
    /// unambiguously from frame metadata.  Keep `init` for already-validated
    /// static tables; prefer this checked constructor for trained or otherwise
    /// caller-discovered dictionary catalogs.
    pub fn initChecked(dictionaries: []const NativeDictionary) Error!NativeDictionarySet {
        const set = init(dictionaries);
        try set.validate();
        return set;
    }

    /// Validate persisted metadata records and construct a dictionary catalog.
    ///
    /// `out` receives borrowed dictionary views of `contents`; callers retain
    /// ownership of both slices and must keep dictionary bytes alive for any
    /// subsequent encode/decode operation. Keeping this constructor allocation-
    /// free lets applications load catalog metadata from their own container
    /// format and still get the same duplicate-ID checks as `initChecked`.
    pub fn initFromMetadata(
        out: []NativeDictionary,
        metadata: []const dictionary_mod.Metadata,
        contents: []const []const u8,
    ) Error!NativeDictionarySet {
        if (metadata.len == 0) {
            if (contents.len != 0) return error.InvalidDictionaryMetadata;
            return initChecked(&.{});
        }
        if (out.len < metadata.len or contents.len != metadata.len) return error.InvalidDictionaryMetadata;
        for (metadata, contents, 0..) |entry, content, i| {
            out[i] = try NativeDictionary.initFromMetadata(entry, content);
        }
        return try initChecked(out[0..metadata.len]);
    }

    pub fn validate(self: NativeDictionarySet) Error!void {
        for (self.dictionaries, 0..) |dictionary, i| {
            if (dictionary.id == 0) return error.NeedDictionary;
            for (self.dictionaries[0..i]) |previous| {
                if (previous.id == dictionary.id) return error.DuplicateDictionaryId;
            }
        }
    }

    pub fn find(self: NativeDictionarySet, id: u32) ?NativeDictionary {
        for (self.dictionaries) |dictionary| {
            if (dictionary.id == id) return dictionary;
        }
        return null;
    }
};

pub const OwnedNativeDictionarySet = struct {
    dictionaries: []NativeDictionary,

    pub fn asDictionarySet(self: OwnedNativeDictionarySet) NativeDictionarySet {
        return NativeDictionarySet.init(self.dictionaries);
    }

    pub fn deinit(self: OwnedNativeDictionarySet, allocator: std.mem.Allocator) void {
        allocator.free(self.dictionaries);
    }
};

/// Allocate and validate a borrowed dictionary catalog from persisted metadata.
///
/// This owns only the small catalog array, not the dictionary bytes themselves.
/// It is useful for applications that decode a container's dictionary metadata
/// table and want a reusable `NativeDictionarySet` without managing a separate
/// scratch array at every call site.
pub fn nativeDictionarySetFromMetadataAlloc(
    allocator: std.mem.Allocator,
    metadata: []const dictionary_mod.Metadata,
    contents: []const []const u8,
) Error!OwnedNativeDictionarySet {
    if (contents.len != metadata.len) return error.InvalidDictionaryMetadata;
    const dictionaries = try allocator.alloc(NativeDictionary, metadata.len);
    errdefer allocator.free(dictionaries);
    _ = try NativeDictionarySet.initFromMetadata(dictionaries, metadata, contents);
    return .{ .dictionaries = dictionaries };
}

pub const NativeFrameMode = enum {
    raw_or_rle,
    literal_only,
};

pub const NativeFrameEncodeResult = struct {
    frame: []u8,
    mode: NativeFrameMode,
};

pub const NativeFrameEncodeIntoResult = struct {
    written: usize,
    mode: NativeFrameMode,
};

pub const NativeFrameEncodeScratchResult = struct {
    frame: []const u8,
    mode: NativeFrameMode,
};

pub fn encodedNativeFrameBound(input_len: usize) Error!usize {
    return try encodedNativeFrameBoundWithOptions(input_len, .{});
}

pub fn encodedNativeFrameBoundWithOptions(input_len: usize, options: NativeFrameOptions) Error!usize {
    const block_size_max = try nativeBlockSizeMax(options);
    _ = try nativeMatchSearchBudget(options);
    const dictionary_id_len = nativeDictionaryIdFieldLen(options.dictionary_id);
    const frame_header_len: usize = if (options.include_content_size)
        4 + 1 + dictionary_id_len + 8
    else
        4 + 1 + 1 + dictionary_id_len;
    const block_count = if (input_len == 0)
        1
    else
        (input_len + block_size_max - 1) / block_size_max;
    var bound = frame_header_len;
    bound = std.math.add(usize, bound, input_len) catch return error.IntegerOverflow;
    const block_header_bytes = std.math.mul(usize, block_count, 3) catch return error.IntegerOverflow;
    bound = std.math.add(usize, bound, block_header_bytes) catch return error.IntegerOverflow;
    if (options.content_checksum) bound = std.math.add(usize, bound, 4) catch return error.IntegerOverflow;
    return bound;
}

pub fn encodedNativeFrameBoundWithDictionary(input_len: usize, options: NativeFrameOptions, dictionary: NativeDictionary) Error!usize {
    if (dictionary.id == 0) return error.NeedDictionary;
    return try encodedNativeFrameBoundWithOptions(input_len, optionsWithNativeDictionary(options, dictionary));
}

pub fn encodedNativeFrameBoundWithDictionarySet(input_len: usize, options: NativeFrameOptions, dictionary_set: NativeDictionarySet, dictionary_id: u32) Error!usize {
    if (dictionary_id == 0) return error.NeedDictionary;
    const dictionary = dictionary_set.find(dictionary_id) orelse return error.NeedDictionary;
    return try encodedNativeFrameBoundWithDictionary(input_len, options, dictionary);
}

/// Decode a Zstandard frame. Prefer libzstd's one-shot decoder because MCAP and
/// similar containers often know the decoded chunk size out-of-band and because
/// the one-shot path avoids Zig streaming allocator overhead. When the frame
/// omits its content size, use libzstd's conservative decompressed bound before
/// falling back to Zig std's streaming decoder for frames that cannot be bounded
/// by the linked library.
pub fn decodeFrameAlloc(allocator: std.mem.Allocator, frame: []const u8) Error![]u8 {
    return try decodeFrameAllocWithLimit(allocator, frame, null);
}

pub fn decodeFrameAllocLimited(allocator: std.mem.Allocator, frame: []const u8, max_output_len: usize) Error![]u8 {
    return try decodeFrameAllocWithLimit(allocator, frame, max_output_len);
}

pub fn decodeFrameInto(frame: []const u8, output: []u8) Error!usize {
    const content_size = ZSTD_getFrameContentSize(@ptrCast(frame.ptr), frame.len);
    if (content_size == zstd_content_size_error) return error.CorruptFrame;
    if (content_size != zstd_content_size_unknown) {
        const decoded_len = try checkedU64ToUsize(content_size);
        if (output.len < decoded_len) return error.OutputTooSmall;
        const written = ZSTD_decompress(@ptrCast(output.ptr), output.len, @ptrCast(frame.ptr), frame.len);
        if (ZSTD_isError(written) != 0) return error.CorruptFrame;
        if (written != decoded_len) return error.SizeMismatch;
        return written;
    }

    const bound = ZSTD_decompressBound(@ptrCast(frame.ptr), frame.len);
    if (bound == zstd_content_size_error) return error.UnsupportedZstdFeature;
    const capacity = try checkedU64ToUsize(bound);
    const written = ZSTD_decompress(@ptrCast(output.ptr), output.len, @ptrCast(frame.ptr), frame.len);
    if (ZSTD_isError(written) != 0) {
        // The bound is intentionally conservative when the frame omits content
        // size. A caller buffer smaller than the bound might still be large
        // enough, so only classify an actual libzstd failure as OutputTooSmall
        // when the advertised upper bound proves the buffer was not generous.
        if (output.len < capacity) return error.OutputTooSmall;
        return error.CorruptFrame;
    }
    if (written > output.len) return error.OutputTooSmall;
    return written;
}

pub fn decodedFrameSize(frame: []const u8) Error!usize {
    return try decodedFrameSizeLimited(frame, std.math.maxInt(usize));
}

pub fn decodedFrameSizeLimited(frame: []const u8, max_output_len: usize) Error!usize {
    const content_size = ZSTD_getFrameContentSize(@ptrCast(frame.ptr), frame.len);
    if (content_size == zstd_content_size_error) return error.CorruptFrame;
    const decoded_len = if (content_size != zstd_content_size_unknown)
        try checkedU64ToUsize(content_size)
    else blk: {
        const bound = ZSTD_decompressBound(@ptrCast(frame.ptr), frame.len);
        if (bound == zstd_content_size_error) return error.UnsupportedZstdFeature;
        break :blk try checkedU64ToUsize(bound);
    };
    if (decoded_len > max_output_len) return error.OutputLimitExceeded;
    return decoded_len;
}

fn nativeBlockSizeMax(options: NativeFrameOptions) Error!usize {
    if (options.block_size_max == 0 or options.block_size_max > std.compress.zstd.block_size_max) return error.InvalidBlockPlan;
    return options.block_size_max;
}

fn nativeMatchSearchBudget(options: NativeFrameOptions) Error!usize {
    if (options.match_search_budget > mixed_match_path_search_budget) return error.InvalidBlockPlan;
    return options.match_search_budget;
}

fn nativeDictionaryIdFlag(dictionary_id: u32) u2 {
    if (dictionary_id == 0) return 0;
    if (dictionary_id <= std.math.maxInt(u8)) return 1;
    if (dictionary_id <= std.math.maxInt(u16)) return 2;
    return 3;
}

fn nativeDictionaryIdFieldLen(dictionary_id: u32) usize {
    return switch (nativeDictionaryIdFlag(dictionary_id)) {
        0 => 0,
        1 => 1,
        2 => 2,
        3 => 4,
    };
}

fn emitDictionaryId(allocator: std.mem.Allocator, out: *std.ArrayList(u8), dictionary_id: u32) Error!void {
    switch (nativeDictionaryIdFlag(dictionary_id)) {
        0 => {},
        1 => try out.append(allocator, @intCast(dictionary_id)),
        2 => {
            var bytes: [2]u8 = undefined;
            std.mem.writeInt(u16, &bytes, @intCast(dictionary_id), .little);
            try out.appendSlice(allocator, &bytes);
        },
        3 => {
            var bytes: [4]u8 = undefined;
            std.mem.writeInt(u32, &bytes, dictionary_id, .little);
            try out.appendSlice(allocator, &bytes);
        },
    }
}

fn decodeFrameAllocWithLimit(allocator: std.mem.Allocator, frame: []const u8, max_output_len: ?usize) Error![]u8 {
    const content_size = ZSTD_getFrameContentSize(@ptrCast(frame.ptr), frame.len);
    if (content_size == zstd_content_size_error) return error.CorruptFrame;
    if (content_size != zstd_content_size_unknown) {
        const decoded_len = try checkedU64ToUsize(content_size);
        if (max_output_len) |limit| {
            if (decoded_len > limit) return error.OutputLimitExceeded;
        }
        const out = try allocator.alloc(u8, decoded_len);
        errdefer allocator.free(out);
        const written = ZSTD_decompress(@ptrCast(out.ptr), out.len, @ptrCast(frame.ptr), frame.len);
        if (ZSTD_isError(written) != 0) return error.CorruptFrame;
        if (written != decoded_len) return error.SizeMismatch;
        return out;
    }

    const bound = ZSTD_decompressBound(@ptrCast(frame.ptr), frame.len);
    if (bound != zstd_content_size_error) {
        const bound_capacity = try checkedU64ToUsize(bound);
        const capacity = if (max_output_len) |limit| @min(bound_capacity, limit) else bound_capacity;
        if (max_output_len) |limit| {
            if (capacity > limit) return error.OutputLimitExceeded;
        }
        const out = try allocator.alloc(u8, capacity);
        errdefer allocator.free(out);
        const written = ZSTD_decompress(@ptrCast(out.ptr), out.len, @ptrCast(frame.ptr), frame.len);
        if (ZSTD_isError(written) != 0) {
            if (max_output_len != null and bound_capacity > capacity) return error.OutputLimitExceeded;
            return error.CorruptFrame;
        }
        if (max_output_len) |limit| {
            if (written > limit) return error.OutputLimitExceeded;
        }
        if (allocator.remap(out, written)) |shrunk| return shrunk;
        const exact = try allocator.dupe(u8, out[0..written]);
        allocator.free(out);
        return exact;
    }

    if (max_output_len) |limit| {
        const native = decodeRawOrRleFrameAllocLimited(allocator, frame, limit) catch |err| switch (err) {
            error.UnsupportedZstdFeature => null,
            else => return err,
        };
        if (native) |decoded| return decoded;
    }

    var input: std.Io.Reader = .fixed(frame);
    var zstd_stream: std.compress.zstd.Decompress = .init(&input, &.{}, .{});
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    _ = zstd_stream.reader.streamRemaining(&output.writer) catch return error.CorruptFrame;
    if (zstd_stream.err) |_| return error.CorruptFrame;
    const decoded = output.toOwnedSlice() catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
    };
    errdefer allocator.free(decoded);
    if (max_output_len) |limit| {
        if (decoded.len > limit) return error.OutputLimitExceeded;
    }
    return decoded;
}

/// Dependency-free Zstandard decoder for the raw/RLE frame subset emitted by
/// `encodeRawOrRleFrameAlloc`, plus the growing native compressed-block subset
/// used by compatibility smoke tests. It accepts concatenated supported frames
/// and skippable frames, validates frame content sizes and optional content
/// checksums, and deliberately rejects unsupported sequence/FSE payloads instead
/// of silently falling back to a partial implementation.
pub fn decodeRawOrRleFrameAlloc(allocator: std.mem.Allocator, frame: []const u8) Error![]u8 {
    return try decodeRawOrRleFrameAllocWithDictionaryInternal(allocator, frame, null);
}

pub fn decodeRawOrRleFrameAllocExactSize(allocator: std.mem.Allocator, frame: []const u8, expected_output_len: usize) Error![]u8 {
    const decoded_len = try decodedRawOrRleFrameSize(frame);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeRawOrRleFrameInto(frame, out) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

pub fn decodeRawOrRleFrameIntoExactSize(frame: []const u8, output: []u8, expected_output_len: usize) Error!usize {
    if (output.len < expected_output_len) return error.OutputTooSmall;
    const written = decodeRawOrRleFrameInto(frame, output[0..expected_output_len]) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return written;
}

pub fn decodeRawOrRleFrameAllocWithDictionary(
    allocator: std.mem.Allocator,
    frame: []const u8,
    dictionary: NativeDictionary,
) Error![]u8 {
    return try decodeRawOrRleFrameAllocWithDictionaryInternal(allocator, frame, dictionary);
}

pub fn decodeRawOrRleFrameAllocWithDictionaryExactSize(
    allocator: std.mem.Allocator,
    frame: []const u8,
    dictionary: NativeDictionary,
    expected_output_len: usize,
) Error![]u8 {
    const decoded_len = try decodedRawOrRleFrameSizeWithDictionary(frame, dictionary);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeRawOrRleFrameIntoWithDictionary(frame, out, dictionary) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

pub fn decodeRawOrRleFrameIntoWithDictionaryExactSize(
    frame: []const u8,
    output: []u8,
    dictionary: NativeDictionary,
    expected_output_len: usize,
) Error!usize {
    if (output.len < expected_output_len) return error.OutputTooSmall;
    const written = decodeRawOrRleFrameIntoWithDictionary(frame, output[0..expected_output_len], dictionary) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return written;
}

pub fn decodeRawOrRleFrameAllocWithDictionarySet(
    allocator: std.mem.Allocator,
    frame: []const u8,
    dictionary_set: NativeDictionarySet,
) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    _ = try decodeRawOrRleFrameAppendWithDictionarySet(allocator, &out, frame, dictionary_set);
    return out.toOwnedSlice(allocator);
}

pub fn decodeRawOrRleFrameAllocWithDictionarySetExactSize(
    allocator: std.mem.Allocator,
    frame: []const u8,
    dictionary_set: NativeDictionarySet,
    expected_output_len: usize,
) Error![]u8 {
    const decoded_len = try decodedRawOrRleFrameSizeWithDictionarySet(frame, dictionary_set);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeRawOrRleFrameIntoWithDictionarySet(frame, out, dictionary_set) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

pub fn decodeRawOrRleFrameIntoWithDictionarySetExactSize(
    frame: []const u8,
    output: []u8,
    dictionary_set: NativeDictionarySet,
    expected_output_len: usize,
) Error!usize {
    if (output.len < expected_output_len) return error.OutputTooSmall;
    const written = decodeRawOrRleFrameIntoWithDictionarySet(frame, output[0..expected_output_len], dictionary_set) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return written;
}

fn decodeRawOrRleFrameAllocWithDictionaryInternal(
    allocator: std.mem.Allocator,
    frame: []const u8,
    dictionary: ?NativeDictionary,
) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var offset: usize = 0;
    while (offset < frame.len) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        if (magic == frame_magic_u32) {
            try decodeRawOrRleZstandardFrameInto(allocator, &out, frame, &offset, dictionary);
        } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const skip_len: usize = @intCast(std.mem.readInt(u32, frame[offset..][0..4], .little));
            offset += 4;
            if (frame.len - offset < skip_len) return error.TruncatedFrame;
            offset += skip_len;
        } else {
            return error.InvalidMagic;
        }
    }

    return out.toOwnedSlice(allocator);
}

pub fn decodeRawOrRleFrameAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8) Error!usize {
    return try decodeRawOrRleFrameAppendWithDictionaryInternal(allocator, out, frame, null);
}

pub fn decodeRawOrRleFrameAppendExactSize(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8, expected_output_len: usize) Error!usize {
    const decoded_len = try decodedRawOrRleFrameSize(frame);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    const start = out.items.len;
    try out.ensureUnusedCapacity(allocator, expected_output_len);
    const slot = out.addManyAsSliceAssumeCapacity(expected_output_len);
    const written = decodeRawOrRleFrameInto(frame, slot) catch |err| switch (err) {
        error.OutputTooSmall => {
            out.items.len = start;
            return error.SizeMismatch;
        },
        else => {
            out.items.len = start;
            return err;
        },
    };
    if (written != expected_output_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeRawOrRleFrameAppendWithDictionary(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frame: []const u8,
    dictionary: NativeDictionary,
) Error!usize {
    return try decodeRawOrRleFrameAppendWithDictionaryInternal(allocator, out, frame, dictionary);
}

pub fn decodeRawOrRleFrameAppendExactSizeWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
    const decoded_len = try decodedRawOrRleFrameSizeWithDictionary(frame, dictionary);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    const start = out.items.len;
    try out.ensureUnusedCapacity(allocator, expected_output_len);
    const slot = out.addManyAsSliceAssumeCapacity(expected_output_len);
    const written = decodeRawOrRleFrameIntoWithDictionary(frame, slot, dictionary) catch |err| switch (err) {
        error.OutputTooSmall => {
            out.items.len = start;
            return error.SizeMismatch;
        },
        else => {
            out.items.len = start;
            return err;
        },
    };
    if (written != expected_output_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeRawOrRleFrameAppendWithDictionarySet(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frame: []const u8,
    dictionary_set: NativeDictionarySet,
) Error!usize {
    const decoded_len = try decodedRawOrRleFrameSizeWithDictionarySet(frame, dictionary_set);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeRawOrRleFrameIntoWithDictionarySet(frame, slot, dictionary_set) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeRawOrRleFrameAppendExactSizeWithDictionarySet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
    const decoded_len = try decodedRawOrRleFrameSizeWithDictionarySet(frame, dictionary_set);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    try out.ensureUnusedCapacity(allocator, expected_output_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(expected_output_len);
    const written = decodeRawOrRleFrameIntoWithDictionarySet(frame, slot, dictionary_set) catch |err| switch (err) {
        error.OutputTooSmall => {
            out.items.len = start;
            return error.SizeMismatch;
        },
        else => {
            out.items.len = start;
            return err;
        },
    };
    if (written != expected_output_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

fn decodeRawOrRleFrameAppendWithDictionaryInternal(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frame: []const u8,
    dictionary: ?NativeDictionary,
) Error!usize {
    const decoded_len = try rawOrRleDecodedSizeLimitedWithDictionary(frame, std.math.maxInt(usize), dictionary);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeRawOrRleFrameIntoWithDictionaryInternal(frame, slot, dictionary) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeRawOrRleFrameAppendLimited(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frame: []const u8,
    max_output_len: usize,
) Error!usize {
    return try decodeRawOrRleFrameAppendLimitedWithDictionaryInternal(allocator, out, frame, max_output_len, null);
}

pub fn decodeRawOrRleFrameAppendLimitedWithDictionary(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frame: []const u8,
    max_output_len: usize,
    dictionary: NativeDictionary,
) Error!usize {
    return try decodeRawOrRleFrameAppendLimitedWithDictionaryInternal(allocator, out, frame, max_output_len, dictionary);
}

pub fn decodeRawOrRleFrameAppendLimitedWithDictionarySet(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frame: []const u8,
    max_output_len: usize,
    dictionary_set: NativeDictionarySet,
) Error!usize {
    const decoded_len = try decodedRawOrRleFrameSizeLimitedWithDictionarySet(frame, max_output_len, dictionary_set);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeRawOrRleFrameIntoWithDictionarySet(frame, slot, dictionary_set) catch |err| switch (err) {
        error.OutputTooSmall => {
            out.items.len = start;
            return error.OutputLimitExceeded;
        },
        else => {
            out.items.len = start;
            return err;
        },
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

fn decodeRawOrRleFrameAppendLimitedWithDictionaryInternal(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frame: []const u8,
    max_output_len: usize,
    dictionary: ?NativeDictionary,
) Error!usize {
    const decoded_len = try rawOrRleDecodedSizeLimitedWithDictionary(frame, max_output_len, dictionary);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeRawOrRleFrameIntoWithDictionaryInternal(frame, slot, dictionary) catch |err| switch (err) {
        error.OutputTooSmall => {
            out.items.len = start;
            return error.OutputLimitExceeded;
        },
        else => {
            out.items.len = start;
            return err;
        },
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeRawOrRleFrameAllocLimited(
    allocator: std.mem.Allocator,
    frame: []const u8,
    max_output_len: usize,
) Error![]u8 {
    return try decodeRawOrRleFrameAllocLimitedWithDictionaryInternal(allocator, frame, max_output_len, null);
}

pub fn decodeRawOrRleFrameAllocLimitedWithDictionary(
    allocator: std.mem.Allocator,
    frame: []const u8,
    max_output_len: usize,
    dictionary: NativeDictionary,
) Error![]u8 {
    return try decodeRawOrRleFrameAllocLimitedWithDictionaryInternal(allocator, frame, max_output_len, dictionary);
}

pub fn decodeRawOrRleFrameAllocLimitedWithDictionarySet(
    allocator: std.mem.Allocator,
    frame: []const u8,
    max_output_len: usize,
    dictionary_set: NativeDictionarySet,
) Error![]u8 {
    const decoded_len = try decodedRawOrRleFrameSizeLimitedWithDictionarySet(frame, max_output_len, dictionary_set);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = decodeRawOrRleFrameIntoWithDictionarySet(frame, out, dictionary_set) catch |err| switch (err) {
        error.OutputTooSmall => return error.OutputLimitExceeded,
        else => return err,
    };
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

fn decodeRawOrRleFrameAllocLimitedWithDictionaryInternal(
    allocator: std.mem.Allocator,
    frame: []const u8,
    max_output_len: usize,
    dictionary: ?NativeDictionary,
) Error![]u8 {
    const decoded_len = try rawOrRleDecodedSizeLimitedWithDictionary(frame, max_output_len, dictionary);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = decodeRawOrRleFrameIntoWithDictionaryInternal(frame, out, dictionary) catch |err| switch (err) {
        error.OutputTooSmall => return error.OutputLimitExceeded,
        else => return err,
    };
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodedRawOrRleFrameSize(frame: []const u8) Error!usize {
    return try rawOrRleDecodedSizeLimitedWithDictionary(frame, std.math.maxInt(usize), null);
}

pub fn decodedRawOrRleFrameSizeWithDictionary(frame: []const u8, dictionary: NativeDictionary) Error!usize {
    return try rawOrRleDecodedSizeLimitedWithDictionary(frame, std.math.maxInt(usize), dictionary);
}

pub fn decodedRawOrRleFrameSizeLimitedWithDictionary(frame: []const u8, max_output_len: usize, dictionary: NativeDictionary) Error!usize {
    return try rawOrRleDecodedSizeLimitedWithDictionary(frame, max_output_len, dictionary);
}

pub fn decodedRawOrRleFrameSizeWithDictionarySet(frame: []const u8, dictionary_set: NativeDictionarySet) Error!usize {
    return try decodedRawOrRleFrameSizeLimitedWithDictionarySet(frame, std.math.maxInt(usize), dictionary_set);
}

pub fn decodedRawOrRleFrameSizeLimitedWithDictionarySet(frame: []const u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error!usize {
    var offset: usize = 0;
    var total: usize = 0;
    while (offset < frame.len) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frame[offset..][0..4], .little);
        if (magic == frame_magic_u32) {
            const end = try findNativeFrameEnd(frame, offset);
            const frame_bytes = frame[offset..end];
            const dictionary = try dictionaryForNativeFrame(frame_bytes, dictionary_set);
            const frame_len = if (dictionary) |dict|
                try decodedRawOrRleFrameSizeLimitedWithDictionary(frame_bytes, max_output_len - total, dict)
            else
                try decodedRawOrRleFrameSizeLimited(frame_bytes, max_output_len - total);
            total = try checkedAddWithinLimit(total, frame_len, max_output_len);
            offset = end;
        } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            offset += 4;
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const skip_len: usize = @intCast(std.mem.readInt(u32, frame[offset..][0..4], .little));
            offset += 4;
            if (frame.len - offset < skip_len) return error.TruncatedFrame;
            offset += skip_len;
        } else {
            return error.InvalidMagic;
        }
    }
    return total;
}

pub const decodedRawOrRleFrameSizeLimited = rawOrRleDecodedSizeLimited;
pub const decodedNativeFrameSize = decodedRawOrRleFrameSize;
pub const decodedNativeFrameSizeLimited = rawOrRleDecodedSizeLimited;
pub const decodedNativeFrameSizeWithDictionary = decodedRawOrRleFrameSizeWithDictionary;
pub const decodedNativeFrameSizeLimitedWithDictionary = decodedRawOrRleFrameSizeLimitedWithDictionary;
pub const decodedNativeFrameSizeWithDictionarySet = decodedRawOrRleFrameSizeWithDictionarySet;
pub const decodedNativeFrameSizeLimitedWithDictionarySet = decodedRawOrRleFrameSizeLimitedWithDictionarySet;

/// Decode the raw/RLE Zstandard subset directly into caller-owned storage.
/// The returned length is the number of bytes written across all concatenated
/// non-skippable frames. This mirrors the allocator-returning fallback but lets
/// embedded/streaming callers preflight capacity and stay allocation-free while
/// still receiving exact checksum, size, and unsupported-feature errors.
pub fn decodeRawOrRleFrameInto(frame: []const u8, output: []u8) Error!usize {
    return try decodeRawOrRleFrameIntoWithDictionaryInternal(frame, output, null);
}

pub fn decodeRawOrRleFrameIntoWithDictionary(
    frame: []const u8,
    output: []u8,
    dictionary: NativeDictionary,
) Error!usize {
    return try decodeRawOrRleFrameIntoWithDictionaryInternal(frame, output, dictionary);
}

pub fn decodeRawOrRleFrameIntoWithDictionarySet(
    frame: []const u8,
    output: []u8,
    dictionary_set: NativeDictionarySet,
) Error!usize {
    var offset: usize = 0;
    var written: usize = 0;
    while (offset < frame.len) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frame[offset..][0..4], .little);
        if (magic == frame_magic_u32) {
            const end = try findNativeFrameEnd(frame, offset);
            const frame_bytes = frame[offset..end];
            const dictionary = try dictionaryForNativeFrame(frame_bytes, dictionary_set);
            written += if (dictionary) |dict|
                try decodeRawOrRleFrameIntoWithDictionary(frame_bytes, output[written..], dict)
            else
                try decodeRawOrRleFrameInto(frame_bytes, output[written..]);
            offset = end;
        } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            offset += 4;
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const skip_len: usize = @intCast(std.mem.readInt(u32, frame[offset..][0..4], .little));
            offset += 4;
            if (frame.len - offset < skip_len) return error.TruncatedFrame;
            offset += skip_len;
        } else {
            return error.InvalidMagic;
        }
    }
    return written;
}

pub fn decodeRawOrRleFrameChunksAlloc(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAlloc(allocator, joined);
}

pub fn decodeRawOrRleFrameChunksAllocExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAllocExactSize(allocator, joined, expected_output_len);
}

pub fn decodeRawOrRleFrameChunksAllocLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAllocLimited(allocator, joined, max_output_len);
}

pub fn decodeRawOrRleFrameChunksAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAppend(allocator, out, joined);
}

pub fn decodeRawOrRleFrameChunksAppendExactSize(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAppendExactSize(allocator, out, joined, expected_output_len);
}

pub fn decodeRawOrRleFrameChunksAppendLimited(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAppendLimited(allocator, out, joined, max_output_len);
}

pub fn decodeRawOrRleFrameChunksInto(chunks: []const []const u8, compressed_scratch: []u8, output: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameInto(joined, output);
}

pub fn decodeRawOrRleFrameChunksIntoExactSize(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameIntoExactSize(joined, output, expected_output_len);
}

pub fn decodedRawOrRleFrameChunksSize(chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedRawOrRleFrameSize(joined);
}

pub fn decodedRawOrRleFrameChunksSizeLimited(chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try rawOrRleDecodedSizeLimited(joined, max_output_len);
}

pub fn decodeRawOrRleFrameChunksAllocWithDictionary(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAllocWithDictionary(allocator, joined, dictionary);
}

pub fn decodeRawOrRleFrameChunksAllocWithDictionaryExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAllocWithDictionaryExactSize(allocator, joined, dictionary, expected_output_len);
}

pub fn decodeRawOrRleFrameChunksAllocWithDictionaryLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary, max_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAllocLimitedWithDictionary(allocator, joined, max_output_len, dictionary);
}

pub fn decodeRawOrRleFrameChunksAppendWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAppendWithDictionary(allocator, out, joined, dictionary);
}

pub fn decodeRawOrRleFrameChunksAppendExactSizeWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAppendExactSizeWithDictionary(allocator, out, joined, dictionary, expected_output_len);
}

pub fn decodeRawOrRleFrameChunksAppendLimitedWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAppendLimitedWithDictionary(allocator, out, joined, max_output_len, dictionary);
}

pub fn decodeRawOrRleFrameChunksIntoWithDictionary(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameIntoWithDictionary(joined, output, dictionary);
}

pub fn decodeRawOrRleFrameChunksIntoExactSizeWithDictionary(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameIntoWithDictionaryExactSize(joined, output, dictionary, expected_output_len);
}

pub fn decodedRawOrRleFrameChunksSizeWithDictionary(chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedRawOrRleFrameSizeWithDictionary(joined, dictionary);
}

pub fn decodedRawOrRleFrameChunksSizeLimitedWithDictionary(chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedRawOrRleFrameSizeLimitedWithDictionary(joined, max_output_len, dictionary);
}

pub fn decodeRawOrRleFrameChunksAllocWithDictionarySet(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAllocWithDictionarySet(allocator, joined, dictionary_set);
}

pub fn decodeRawOrRleFrameChunksAllocWithDictionarySetExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAllocWithDictionarySetExactSize(allocator, joined, dictionary_set, expected_output_len);
}

pub fn decodeRawOrRleFrameChunksAllocWithDictionarySetLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet, max_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAllocLimitedWithDictionarySet(allocator, joined, max_output_len, dictionary_set);
}

pub fn decodeRawOrRleFrameChunksAppendWithDictionarySet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAppendWithDictionarySet(allocator, out, joined, dictionary_set);
}

pub fn decodeRawOrRleFrameChunksAppendExactSizeWithDictionarySet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAppendExactSizeWithDictionarySet(allocator, out, joined, dictionary_set, expected_output_len);
}

pub fn decodeRawOrRleFrameChunksAppendLimitedWithDictionarySet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameAppendLimitedWithDictionarySet(allocator, out, joined, max_output_len, dictionary_set);
}

pub fn decodeRawOrRleFrameChunksIntoWithDictionarySet(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameIntoWithDictionarySet(joined, output, dictionary_set);
}

pub fn decodeRawOrRleFrameChunksIntoExactSizeWithDictionarySet(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeRawOrRleFrameIntoWithDictionarySetExactSize(joined, output, dictionary_set, expected_output_len);
}

pub fn decodedRawOrRleFrameChunksSizeWithDictionarySet(chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedRawOrRleFrameSizeWithDictionarySet(joined, dictionary_set);
}

pub fn decodedRawOrRleFrameChunksSizeLimitedWithDictionarySet(chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedRawOrRleFrameSizeLimitedWithDictionarySet(joined, max_output_len, dictionary_set);
}

fn joinChunks(chunks: []const []const u8, compressed_scratch: []u8) Error![]const u8 {
    var total: usize = 0;
    for (chunks) |chunk| total = std.math.add(usize, total, chunk.len) catch return error.IntegerOverflow;
    if (compressed_scratch.len < total) return error.OutputTooSmall;
    var offset: usize = 0;
    for (chunks) |chunk| {
        @memcpy(compressed_scratch[offset..][0..chunk.len], chunk);
        offset += chunk.len;
    }
    return compressed_scratch[0..total];
}

fn decodeRawOrRleFrameIntoWithDictionaryInternal(
    frame: []const u8,
    output: []u8,
    dictionary: ?NativeDictionary,
) Error!usize {
    var offset: usize = 0;
    var written: usize = 0;
    while (offset < frame.len) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        if (magic == frame_magic_u32) {
            try decodeRawOrRleZstandardFrameIntoBuffer(frame, &offset, output, &written, dictionary);
        } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const skip_len: usize = @intCast(std.mem.readInt(u32, frame[offset..][0..4], .little));
            offset += 4;
            if (frame.len - offset < skip_len) return error.TruncatedFrame;
            offset += skip_len;
        } else {
            return error.InvalidMagic;
        }
    }
    return written;
}

pub const decodeNativeFrameAlloc = decodeRawOrRleFrameAlloc;
pub const decodeNativeFrameAllocExactSize = decodeRawOrRleFrameAllocExactSize;
pub const decodeNativeFrameAppend = decodeRawOrRleFrameAppend;
pub const decodeNativeFrameAppendExactSize = decodeRawOrRleFrameAppendExactSize;
pub const decodeNativeFrameAppendLimited = decodeRawOrRleFrameAppendLimited;
pub const decodeNativeFrameAllocLimited = decodeRawOrRleFrameAllocLimited;
pub const decodeNativeFrameInto = decodeRawOrRleFrameInto;
pub const decodeNativeFrameIntoExactSize = decodeRawOrRleFrameIntoExactSize;
pub const decodeNativeFrameAllocWithDictionary = decodeRawOrRleFrameAllocWithDictionary;
pub const decodeNativeFrameAllocWithDictionaryExactSize = decodeRawOrRleFrameAllocWithDictionaryExactSize;
pub const decodeNativeFrameIntoWithDictionaryExactSize = decodeRawOrRleFrameIntoWithDictionaryExactSize;
pub const decodeNativeFrameAppendWithDictionary = decodeRawOrRleFrameAppendWithDictionary;
pub const decodeNativeFrameAppendExactSizeWithDictionary = decodeRawOrRleFrameAppendExactSizeWithDictionary;
pub const decodeNativeFrameAppendLimitedWithDictionary = decodeRawOrRleFrameAppendLimitedWithDictionary;
pub const decodeNativeFrameAllocLimitedWithDictionary = decodeRawOrRleFrameAllocLimitedWithDictionary;
pub const decodeNativeFrameIntoWithDictionary = decodeRawOrRleFrameIntoWithDictionary;
pub const decodeNativeFrameAllocWithDictionarySet = decodeRawOrRleFrameAllocWithDictionarySet;
pub const decodeNativeFrameAllocWithDictionarySetExactSize = decodeRawOrRleFrameAllocWithDictionarySetExactSize;
pub const decodeNativeFrameIntoWithDictionarySetExactSize = decodeRawOrRleFrameIntoWithDictionarySetExactSize;
pub const decodeNativeFrameAppendWithDictionarySet = decodeRawOrRleFrameAppendWithDictionarySet;
pub const decodeNativeFrameAppendExactSizeWithDictionarySet = decodeRawOrRleFrameAppendExactSizeWithDictionarySet;
pub const decodeNativeFrameAppendLimitedWithDictionarySet = decodeRawOrRleFrameAppendLimitedWithDictionarySet;
pub const decodeNativeFrameAllocLimitedWithDictionarySet = decodeRawOrRleFrameAllocLimitedWithDictionarySet;
pub const decodeNativeFrameIntoWithDictionarySet = decodeRawOrRleFrameIntoWithDictionarySet;
pub const decodeNativeFrameChunksAlloc = decodeRawOrRleFrameChunksAlloc;
pub const decodeNativeFrameChunksAllocExactSize = decodeRawOrRleFrameChunksAllocExactSize;
pub const decodeNativeFrameChunksAllocLimited = decodeRawOrRleFrameChunksAllocLimited;
pub const decodeNativeFrameChunksAppend = decodeRawOrRleFrameChunksAppend;
pub const decodeNativeFrameChunksAppendExactSize = decodeRawOrRleFrameChunksAppendExactSize;
pub const decodeNativeFrameChunksAppendLimited = decodeRawOrRleFrameChunksAppendLimited;
pub const decodeNativeFrameChunksInto = decodeRawOrRleFrameChunksInto;
pub const decodeNativeFrameChunksIntoExactSize = decodeRawOrRleFrameChunksIntoExactSize;
pub const decodedNativeFrameChunksSize = decodedRawOrRleFrameChunksSize;
pub const decodedNativeFrameChunksSizeLimited = decodedRawOrRleFrameChunksSizeLimited;
pub const decodeNativeFrameChunksAllocWithDictionary = decodeRawOrRleFrameChunksAllocWithDictionary;
pub const decodeNativeFrameChunksAllocWithDictionaryExactSize = decodeRawOrRleFrameChunksAllocWithDictionaryExactSize;
pub const decodeNativeFrameChunksAllocWithDictionaryLimited = decodeRawOrRleFrameChunksAllocWithDictionaryLimited;
pub const decodeNativeFrameChunksAppendWithDictionary = decodeRawOrRleFrameChunksAppendWithDictionary;
pub const decodeNativeFrameChunksAppendExactSizeWithDictionary = decodeRawOrRleFrameChunksAppendExactSizeWithDictionary;
pub const decodeNativeFrameChunksAppendLimitedWithDictionary = decodeRawOrRleFrameChunksAppendLimitedWithDictionary;
pub const decodeNativeFrameChunksIntoWithDictionary = decodeRawOrRleFrameChunksIntoWithDictionary;
pub const decodeNativeFrameChunksIntoExactSizeWithDictionary = decodeRawOrRleFrameChunksIntoExactSizeWithDictionary;
pub const decodeNativeFrameChunksIntoWithDictionaryExactSize = decodeRawOrRleFrameChunksIntoExactSizeWithDictionary;
pub const decodedNativeFrameChunksSizeWithDictionary = decodedRawOrRleFrameChunksSizeWithDictionary;
pub const decodedNativeFrameChunksSizeLimitedWithDictionary = decodedRawOrRleFrameChunksSizeLimitedWithDictionary;
pub const decodeNativeFrameChunksAllocWithDictionarySet = decodeRawOrRleFrameChunksAllocWithDictionarySet;
pub const decodeNativeFrameChunksAllocWithDictionarySetExactSize = decodeRawOrRleFrameChunksAllocWithDictionarySetExactSize;
pub const decodeNativeFrameChunksAllocWithDictionarySetLimited = decodeRawOrRleFrameChunksAllocWithDictionarySetLimited;
pub const decodeNativeFrameChunksAppendWithDictionarySet = decodeRawOrRleFrameChunksAppendWithDictionarySet;
pub const decodeNativeFrameChunksAppendExactSizeWithDictionarySet = decodeRawOrRleFrameChunksAppendExactSizeWithDictionarySet;
pub const decodeNativeFrameChunksAppendLimitedWithDictionarySet = decodeRawOrRleFrameChunksAppendLimitedWithDictionarySet;
pub const decodeNativeFrameChunksIntoWithDictionarySet = decodeRawOrRleFrameChunksIntoWithDictionarySet;
pub const decodeNativeFrameChunksIntoExactSizeWithDictionarySet = decodeRawOrRleFrameChunksIntoExactSizeWithDictionarySet;
pub const decodeNativeFrameChunksIntoWithDictionarySetExactSize = decodeRawOrRleFrameChunksIntoExactSizeWithDictionarySet;
pub const decodedNativeFrameChunksSizeWithDictionarySet = decodedRawOrRleFrameChunksSizeWithDictionarySet;
pub const decodedNativeFrameChunksSizeLimitedWithDictionarySet = decodedRawOrRleFrameChunksSizeLimitedWithDictionarySet;
pub const decodeNativeConcatenatedFrameAlloc = decodeRawOrRleFrameAlloc;
pub const decodeNativeConcatenatedFrameAllocExactSize = decodeRawOrRleFrameAllocExactSize;
pub const decodeNativeConcatenatedFrameAppend = decodeRawOrRleFrameAppend;
pub const decodeNativeConcatenatedFrameAppendExactSize = decodeRawOrRleFrameAppendExactSize;
pub const decodeNativeConcatenatedFrameAppendLimited = decodeRawOrRleFrameAppendLimited;
pub const decodeNativeConcatenatedFrameAllocLimited = decodeRawOrRleFrameAllocLimited;
pub const decodeNativeConcatenatedFrameInto = decodeRawOrRleFrameInto;
pub const decodeNativeConcatenatedFrameIntoExactSize = decodeRawOrRleFrameIntoExactSize;
pub const decodeNativeConcatenatedFrameAllocWithDictionary = decodeRawOrRleFrameAllocWithDictionary;
pub const decodeNativeConcatenatedFrameAllocWithDictionaryExactSize = decodeRawOrRleFrameAllocWithDictionaryExactSize;
pub const decodeNativeConcatenatedFrameAppendWithDictionary = decodeRawOrRleFrameAppendWithDictionary;
pub const decodeNativeConcatenatedFrameAppendExactSizeWithDictionary = decodeRawOrRleFrameAppendExactSizeWithDictionary;
pub const decodeNativeConcatenatedFrameAppendLimitedWithDictionary = decodeRawOrRleFrameAppendLimitedWithDictionary;
pub const decodeNativeConcatenatedFrameAllocLimitedWithDictionary = decodeRawOrRleFrameAllocLimitedWithDictionary;
pub const decodeNativeConcatenatedFrameIntoWithDictionary = decodeRawOrRleFrameIntoWithDictionary;
pub const decodeNativeConcatenatedFrameAllocWithDictionarySet = decodeRawOrRleFrameAllocWithDictionarySet;
pub const decodeNativeConcatenatedFrameAllocWithDictionarySetExactSize = decodeRawOrRleFrameAllocWithDictionarySetExactSize;
pub const decodeNativeConcatenatedFrameAppendWithDictionarySet = decodeRawOrRleFrameAppendWithDictionarySet;
pub const decodeNativeConcatenatedFrameAppendExactSizeWithDictionarySet = decodeRawOrRleFrameAppendExactSizeWithDictionarySet;
pub const decodeNativeConcatenatedFrameAppendLimitedWithDictionarySet = decodeRawOrRleFrameAppendLimitedWithDictionarySet;
pub const decodeNativeConcatenatedFrameAllocLimitedWithDictionarySet = decodeRawOrRleFrameAllocLimitedWithDictionarySet;
pub const decodeNativeConcatenatedFrameIntoWithDictionarySet = decodeRawOrRleFrameIntoWithDictionarySet;
pub const decodedNativeConcatenatedFrameSize = decodedRawOrRleFrameSize;
pub const decodedNativeConcatenatedFrameSizeLimited = decodedRawOrRleFrameSizeLimited;
pub const decodedNativeConcatenatedFrameSizeWithDictionary = decodedRawOrRleFrameSizeWithDictionary;
pub const decodedNativeConcatenatedFrameSizeLimitedWithDictionary = decodedRawOrRleFrameSizeLimitedWithDictionary;
pub const decodedNativeConcatenatedFrameSizeWithDictionarySet = decodedRawOrRleFrameSizeWithDictionarySet;
pub const decodedNativeConcatenatedFrameSizeLimitedWithDictionarySet = decodedRawOrRleFrameSizeLimitedWithDictionarySet;
pub const decodeNativeConcatenatedFrameChunksAlloc = decodeRawOrRleFrameChunksAlloc;
pub const decodeNativeConcatenatedFrameChunksAllocExactSize = decodeRawOrRleFrameChunksAllocExactSize;
pub const decodeNativeConcatenatedFrameChunksAllocLimited = decodeRawOrRleFrameChunksAllocLimited;
pub const decodeNativeConcatenatedFrameChunksAppend = decodeRawOrRleFrameChunksAppend;
pub const decodeNativeConcatenatedFrameChunksAppendExactSize = decodeRawOrRleFrameChunksAppendExactSize;
pub const decodeNativeConcatenatedFrameChunksAppendLimited = decodeRawOrRleFrameChunksAppendLimited;
pub const decodeNativeConcatenatedFrameChunksInto = decodeRawOrRleFrameChunksInto;
pub const decodedNativeConcatenatedFrameChunksSize = decodedRawOrRleFrameChunksSize;
pub const decodedNativeConcatenatedFrameChunksSizeLimited = decodedRawOrRleFrameChunksSizeLimited;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionary = decodeRawOrRleFrameChunksAllocWithDictionary;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionaryExactSize = decodeRawOrRleFrameChunksAllocWithDictionaryExactSize;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionaryLimited = decodeRawOrRleFrameChunksAllocWithDictionaryLimited;
pub const decodeNativeConcatenatedFrameChunksAppendWithDictionary = decodeRawOrRleFrameChunksAppendWithDictionary;
pub const decodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionary = decodeRawOrRleFrameChunksAppendExactSizeWithDictionary;
pub const decodeNativeConcatenatedFrameChunksAppendLimitedWithDictionary = decodeRawOrRleFrameChunksAppendLimitedWithDictionary;
pub const decodeNativeConcatenatedFrameChunksIntoWithDictionary = decodeRawOrRleFrameChunksIntoWithDictionary;
pub const decodedNativeConcatenatedFrameChunksSizeWithDictionary = decodedRawOrRleFrameChunksSizeWithDictionary;
pub const decodedNativeConcatenatedFrameChunksSizeLimitedWithDictionary = decodedRawOrRleFrameChunksSizeLimitedWithDictionary;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionarySet = decodeRawOrRleFrameChunksAllocWithDictionarySet;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionarySetExactSize = decodeRawOrRleFrameChunksAllocWithDictionarySetExactSize;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionarySetLimited = decodeRawOrRleFrameChunksAllocWithDictionarySetLimited;
pub const decodeNativeConcatenatedFrameChunksAppendWithDictionarySet = decodeRawOrRleFrameChunksAppendWithDictionarySet;
pub const decodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet = decodeRawOrRleFrameChunksAppendExactSizeWithDictionarySet;
pub const decodeNativeConcatenatedFrameChunksAppendLimitedWithDictionarySet = decodeRawOrRleFrameChunksAppendLimitedWithDictionarySet;
pub const decodeNativeConcatenatedFrameChunksIntoWithDictionarySet = decodeRawOrRleFrameChunksIntoWithDictionarySet;
pub const decodedNativeConcatenatedFrameChunksSizeWithDictionarySet = decodedRawOrRleFrameChunksSizeWithDictionarySet;
pub const decodedNativeConcatenatedFrameChunksSizeLimitedWithDictionarySet = decodedRawOrRleFrameChunksSizeLimitedWithDictionarySet;

/// Incremental input/output facade for native Zstandard frames.
///
/// This mirrors `lz4.NativeIncrementalFrameDecoder`: callers can feed
/// compressed bytes in arbitrary chunks and drain decoded bytes through
/// caller-owned output buffers. It can walk concatenated native streams and
/// skip Zstandard skippable metadata frames while still buffering one complete
/// data frame before delegating validation/decode to the mature one-shot native
/// path, so checksum, dictionary, and unsupported-feature behavior stays
/// identical while the resumable `StepResult` contract evolves.
pub const NativeIncrementalFrameDecoder = struct {
    allocator: std.mem.Allocator,
    dictionary: ?NativeDictionary = null,
    dictionary_set: ?NativeDictionarySet = null,
    options: Options = .{},
    phase: Phase = .frame,
    frame_scratch: std.ArrayList(u8) = .empty,
    decoded_scratch: std.ArrayList(u8) = .empty,
    decoded_offset: usize = 0,
    direct_payload_offset: usize = 0,
    direct_payload_len: usize = 0,
    direct_payload_read: usize = 0,
    direct_block_rle: bool = false,
    direct_rle_byte: u8 = 0,
    direct_block_compressed: bool = false,
    direct_block_decoded_len: usize = 0,
    direct_block_size_max: usize = 0,
    direct_history_window_len: usize = 0,
    direct_frame_output_start: usize = 0,
    direct_dictionary_history: []const u8 = &.{},
    direct_history: std.ArrayList(u8) = .empty,
    direct_sequence_state: SequenceFrameState = .{},
    direct_next_block_header_offset: usize = 0,
    direct_decoded_len: usize = 0,
    direct_decoded_read: usize = 0,
    direct_content_checksum: bool = false,
    direct_content_hasher: std.hash.XxHash64 = std.hash.XxHash64.init(0),
    direct_expected_content_checksum: u32 = 0,
    direct_frame_len: usize = 0,
    input_received: usize = 0,
    output_written: usize = 0,
    last_error_name: []const u8 = "",
    last_error_phase: ?Phase = null,

    pub const Phase = enum { frame, output, direct_output, done };

    pub const Options = struct {
        /// Maximum compressed bytes retained while waiting for one complete
        /// data frame or skippable frame. Because this facade still delegates
        /// validation to the one-shot native decoder, hostile streams should be
        /// guarded by the same container/frame limit the caller would apply to
        /// a one-shot decode.
        max_compressed_buffer_len: usize = std.math.maxInt(usize),
        /// Maximum decoded bytes retained for one complete data frame before
        /// callers drain it through their output chunks. This is per-frame and
        /// does not cap cumulative output across a concatenated stream.
        max_decoded_buffer_len: usize = std.math.maxInt(usize),
        /// Optional exact decoded byte count for the whole logical incremental
        /// stream. When present, `step` rejects surplus output with
        /// `SizeMismatch`; callers use `finish` to distinguish a clean EOF from
        /// a truncated stream that decoded fewer bytes than expected.
        expected_output_len: ?usize = null,
    };

    pub const Snapshot = struct {
        phase: Phase,
        input_received: usize,
        output_written: usize,
        decoded_len: ?usize,
        decoded_remaining: ?usize,
        last_error_name: []const u8,
        last_error_phase: ?Phase,
    };

    pub fn init(allocator: std.mem.Allocator) NativeIncrementalFrameDecoder {
        return .{ .allocator = allocator };
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) NativeIncrementalFrameDecoder {
        return .{ .allocator = allocator, .options = options };
    }

    pub fn initWithDictionary(allocator: std.mem.Allocator, dictionary: NativeDictionary) NativeIncrementalFrameDecoder {
        return .{ .allocator = allocator, .dictionary = dictionary };
    }

    pub fn initWithDictionaryAndOptions(allocator: std.mem.Allocator, dictionary: NativeDictionary, options: Options) NativeIncrementalFrameDecoder {
        return .{ .allocator = allocator, .dictionary = dictionary, .options = options };
    }

    pub fn initWithDictionarySet(allocator: std.mem.Allocator, dictionary_set: NativeDictionarySet) NativeIncrementalFrameDecoder {
        return .{ .allocator = allocator, .dictionary_set = dictionary_set };
    }

    pub fn initWithDictionarySetAndOptions(allocator: std.mem.Allocator, dictionary_set: NativeDictionarySet, options: Options) NativeIncrementalFrameDecoder {
        return .{ .allocator = allocator, .dictionary_set = dictionary_set, .options = options };
    }

    pub fn deinit(self: *NativeIncrementalFrameDecoder) void {
        self.direct_history.deinit(self.allocator);
        self.decoded_scratch.deinit(self.allocator);
        self.frame_scratch.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *NativeIncrementalFrameDecoder) void {
        self.phase = .frame;
        self.frame_scratch.clearRetainingCapacity();
        self.decoded_scratch.clearRetainingCapacity();
        self.decoded_offset = 0;
        self.resetDirectOutput();
        self.input_received = 0;
        self.output_written = 0;
        self.last_error_name = "";
        self.last_error_phase = null;
    }

    pub fn snapshot(self: *const NativeIncrementalFrameDecoder) Snapshot {
        const decoded_len: ?usize = switch (self.phase) {
            .frame => null,
            .direct_output => self.direct_decoded_len,
            .output, .done => self.decoded_scratch.items.len,
        };
        const decoded_remaining: ?usize = switch (self.phase) {
            .frame => null,
            .direct_output => self.direct_decoded_len - self.direct_decoded_read,
            .output, .done => self.decoded_scratch.items.len - self.decoded_offset,
        };
        return .{
            .phase = self.phase,
            .input_received = self.input_received,
            .output_written = self.output_written,
            .decoded_len = decoded_len,
            .decoded_remaining = decoded_remaining,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
        };
    }

    pub fn diagnostics(self: *const NativeIncrementalFrameDecoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = phaseName(snap.phase),
            .frame_input_read = snap.input_received,
            .output_written = snap.output_written,
            .expected_output_len = snap.decoded_len,
            .payload_remaining = snap.decoded_remaining,
            .last_error_name = snap.last_error_name,
            .last_error_phase_name = if (snap.last_error_phase) |phase| phaseName(phase) else "",
        };
    }

    pub fn finish(self: *NativeIncrementalFrameDecoder) Error!void {
        if (self.phase == .direct_output) {
            if (self.direct_payload_read != self.direct_payload_len or self.direct_decoded_read != self.direct_decoded_len) {
                self.recordError(.direct_output, error.OutputTooSmall);
                return error.OutputTooSmall;
            }
            try self.validateDirectContentChecksum();
            const frame_len = self.direct_frame_len;
            self.resetDirectOutput();
            self.discardFrameScratchPrefix(frame_len);
            self.phase = .frame;
        }
        if (self.frame_scratch.items.len != 0) {
            self.recordError(.frame, error.TruncatedFrame);
            return error.TruncatedFrame;
        }
        if (self.phase == .output and self.decoded_offset != self.decoded_scratch.items.len) {
            self.recordError(.output, error.OutputTooSmall);
            return error.OutputTooSmall;
        }
        if (self.options.expected_output_len) |expected| {
            if (self.output_written != expected) {
                self.recordError(.output, error.SizeMismatch);
                return error.SizeMismatch;
            }
        }
        self.phase = .done;
    }

    pub fn step(self: *NativeIncrementalFrameDecoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .done) {
            if (input.len == 0) return .{ .status = .done };
            if (self.options.expected_output_len != null) {
                self.recordError(.frame, error.SizeMismatch);
                return error.SizeMismatch;
            }
            // Fresh bytes after a completed frame are interpreted as the next
            // member of the same caller-driven concatenated stream.  Keep the
            // cumulative counters intact; `reset()` starts a new logical stream.
            self.phase = .frame;
            self.decoded_scratch.clearRetainingCapacity();
            self.decoded_offset = 0;
            self.resetDirectOutput();
        }

        var input_read: usize = 0;
        var output_written_step: usize = 0;
        while (true) {
            switch (self.phase) {
                .frame => {
                    if (input_read < input.len) {
                        try self.appendInputWithinCompressedLimit(input, &input_read);
                    }

                    const frame_end = (try self.completeFrameAvailable()) orelse {
                        if (self.frame_scratch.items.len == 0 and (input_read != 0 or output_written_step != 0)) {
                            if (input_read < input.len) continue;
                            if (try self.needMoreInputForExpectedOutput()) {
                                return .{
                                    .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                    .status = .need_input,
                                };
                            }
                            self.phase = .done;
                            return .{
                                .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                .status = .done,
                            };
                        }
                        if (input_read < input.len or self.frame_scratch.items.len >= self.options.max_compressed_buffer_len) {
                            self.recordError(.frame, error.OutputLimitExceeded);
                            return error.OutputLimitExceeded;
                        }
                        return .{
                            .progress = .{ .input_read = input_read, .output_written = output_written_step },
                            .status = .need_input,
                        };
                    };

                    const direct_supported = self.beginDirectOutputIfSupported(frame_end) catch |err| {
                        self.recordError(.frame, err);
                        return err;
                    };
                    if (direct_supported) {
                        self.phase = .direct_output;
                    } else {
                        self.decodeCompleteFrame(self.frame_scratch.items[0..frame_end]) catch |err| {
                            self.recordError(.frame, err);
                            return err;
                        };
                        self.discardFrameScratchPrefix(frame_end);
                        self.phase = .output;
                    }
                },
                .output => {
                    if (self.decoded_offset == self.decoded_scratch.items.len) {
                        if (self.frame_scratch.items.len != 0) {
                            self.phase = .frame;
                            continue;
                        }
                        if (try self.needMoreInputForExpectedOutput()) {
                            self.phase = .frame;
                            return .{
                                .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                .status = .need_input,
                            };
                        }
                        self.phase = .done;
                        return .{
                            .progress = .{ .input_read = input_read, .output_written = output_written_step },
                            .status = .done,
                        };
                    }
                    if (output_written_step == output.len) {
                        return .{
                            .progress = .{ .input_read = input_read, .output_written = output_written_step },
                            .status = .need_output,
                        };
                    }
                    try self.ensureDecodedScratchFitsExpected();
                    const n = @min(self.decoded_scratch.items.len - self.decoded_offset, output.len - output_written_step);
                    @memcpy(output[output_written_step..][0..n], self.decoded_scratch.items[self.decoded_offset..][0..n]);
                    self.decoded_offset += n;
                    output_written_step += n;
                    self.output_written += n;
                },
                .direct_output => {
                    if (self.direct_payload_read == self.direct_payload_len) {
                        if (self.direct_decoded_read != self.direct_decoded_len) {
                            try self.advanceDirectOutputBlock();
                            continue;
                        }
                        try self.validateDirectContentChecksum();
                        const frame_len = self.direct_frame_len;
                        self.resetDirectOutput();
                        self.discardFrameScratchPrefix(frame_len);
                        if (self.frame_scratch.items.len != 0) {
                            self.phase = .frame;
                            continue;
                        }
                        if (try self.needMoreInputForExpectedOutput()) {
                            self.phase = .frame;
                            return .{
                                .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                .status = .need_input,
                            };
                        }
                        self.phase = .done;
                        return .{
                            .progress = .{ .input_read = input_read, .output_written = output_written_step },
                            .status = .done,
                        };
                    }
                    if (output_written_step == output.len) {
                        return .{
                            .progress = .{ .input_read = input_read, .output_written = output_written_step },
                            .status = .need_output,
                        };
                    }
                    try self.ensureDirectOutputFitsExpected();
                    if (self.direct_block_compressed) {
                        if (output.len - output_written_step < self.direct_block_decoded_len) {
                            if (output_written_step != 0) {
                                return .{
                                    .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                    .status = .need_output,
                                };
                            }
                            try self.fallbackDirectOutputToScratch();
                            continue;
                        }
                        const source = self.frame_scratch.items[self.direct_payload_offset..][0..self.direct_payload_len];
                        const written = written: {
                            var written_abs = output_written_step;
                            try decodeLiteralOnlyCompressedBlockIntoBuffer(source, output, &written_abs, self.direct_block_size_max, output_written_step, self.direct_history.items, &self.direct_sequence_state);
                            break :written written_abs - output_written_step;
                        };
                        if (written != self.direct_block_decoded_len) return error.SizeMismatch;
                        if (self.direct_content_checksum) self.direct_content_hasher.update(output[output_written_step..][0..written]);
                        try self.rememberDirectOutput(output[output_written_step..][0..written]);
                        self.direct_payload_read = self.direct_payload_len;
                        self.direct_decoded_read += written;
                        output_written_step += written;
                        self.output_written += written;
                        continue;
                    }
                    const n = @min(self.direct_payload_len - self.direct_payload_read, output.len - output_written_step);
                    if (self.direct_block_rle) {
                        @memset(output[output_written_step..][0..n], self.direct_rle_byte);
                    } else {
                        const source_offset = self.direct_payload_offset + self.direct_payload_read;
                        @memcpy(output[output_written_step..][0..n], self.frame_scratch.items[source_offset..][0..n]);
                    }
                    if (self.direct_content_checksum) self.direct_content_hasher.update(output[output_written_step..][0..n]);
                    try self.rememberDirectOutput(output[output_written_step..][0..n]);
                    self.direct_payload_read += n;
                    self.direct_decoded_read += n;
                    output_written_step += n;
                    self.output_written += n;
                },
                .done => return .{
                    .progress = .{ .input_read = input_read, .output_written = output_written_step },
                    .status = .done,
                },
            }
        }
    }

    fn needMoreInputForExpectedOutput(self: *NativeIncrementalFrameDecoder) Error!bool {
        const expected = self.options.expected_output_len orelse return false;
        if (self.output_written > expected) {
            self.recordError(.output, error.SizeMismatch);
            return error.SizeMismatch;
        }
        return self.output_written < expected;
    }

    fn ensureDecodedScratchFitsExpected(self: *NativeIncrementalFrameDecoder) Error!void {
        const expected = self.options.expected_output_len orelse return;
        if (self.output_written > expected) {
            self.recordError(.output, error.SizeMismatch);
            return error.SizeMismatch;
        }
        const remaining_expected = expected - self.output_written;
        const remaining_decoded = self.decoded_scratch.items.len - self.decoded_offset;
        if (remaining_decoded > remaining_expected) {
            self.recordError(.output, error.SizeMismatch);
            return error.SizeMismatch;
        }
    }

    fn resetDirectOutput(self: *NativeIncrementalFrameDecoder) void {
        self.direct_payload_offset = 0;
        self.direct_payload_len = 0;
        self.direct_payload_read = 0;
        self.direct_block_rle = false;
        self.direct_rle_byte = 0;
        self.direct_block_compressed = false;
        self.direct_block_decoded_len = 0;
        self.direct_block_size_max = 0;
        self.direct_history_window_len = 0;
        self.direct_frame_output_start = 0;
        self.direct_dictionary_history = &.{};
        self.direct_history.clearRetainingCapacity();
        self.direct_sequence_state = .{};
        self.direct_next_block_header_offset = 0;
        self.direct_decoded_len = 0;
        self.direct_decoded_read = 0;
        self.direct_content_checksum = false;
        self.direct_content_hasher = std.hash.XxHash64.init(0);
        self.direct_expected_content_checksum = 0;
        self.direct_frame_len = 0;
    }

    fn fallbackDirectOutputToScratch(self: *NativeIncrementalFrameDecoder) Error!void {
        const frame_len = self.direct_frame_len;
        const already_emitted = self.direct_decoded_read;
        self.decodeCompleteFrame(self.frame_scratch.items[0..frame_len]) catch |err| {
            self.recordError(.direct_output, err);
            return err;
        };
        if (already_emitted > self.decoded_scratch.items.len) {
            self.recordError(.direct_output, error.SizeMismatch);
            return error.SizeMismatch;
        }
        self.decoded_offset = already_emitted;
        self.resetDirectOutput();
        self.discardFrameScratchPrefix(frame_len);
        self.phase = .output;
    }

    fn rememberDirectOutput(self: *NativeIncrementalFrameDecoder, bytes: []const u8) Error!void {
        if (bytes.len == 0 or self.direct_history_window_len == 0) return;
        if (bytes.len >= self.direct_history_window_len) {
            self.direct_history.clearRetainingCapacity();
            try self.direct_history.appendSlice(self.allocator, bytes[bytes.len - self.direct_history_window_len ..]);
            return;
        }

        const combined_len = self.direct_history.items.len + bytes.len;
        if (combined_len > self.direct_history_window_len) {
            const drop = combined_len - self.direct_history_window_len;
            const keep_len = self.direct_history.items.len - drop;
            std.mem.copyForwards(u8, self.direct_history.items[0..keep_len], self.direct_history.items[drop..]);
            self.direct_history.shrinkRetainingCapacity(keep_len);
        }
        try self.direct_history.appendSlice(self.allocator, bytes);
    }

    fn ensureDirectOutputFitsExpected(self: *NativeIncrementalFrameDecoder) Error!void {
        const expected = self.options.expected_output_len orelse return;
        if (self.output_written > expected) {
            self.recordError(.direct_output, error.SizeMismatch);
            return error.SizeMismatch;
        }
        const remaining_expected = expected - self.output_written;
        const remaining_direct = if (self.direct_block_compressed)
            self.direct_block_decoded_len
        else
            self.direct_decoded_len - self.direct_decoded_read;
        if (remaining_direct > remaining_expected) {
            self.recordError(.direct_output, error.SizeMismatch);
            return error.SizeMismatch;
        }
    }

    fn validateDirectContentChecksum(self: *NativeIncrementalFrameDecoder) Error!void {
        if (!self.direct_content_checksum) return;
        if (@as(u32, @truncate(self.direct_content_hasher.final())) != self.direct_expected_content_checksum) {
            self.recordError(.direct_output, error.ChecksumMismatch);
            return error.ChecksumMismatch;
        }
    }

    fn appendInputWithinCompressedLimit(self: *NativeIncrementalFrameDecoder, input: []const u8, input_read: *usize) Error!void {
        if (self.frame_scratch.items.len > self.options.max_compressed_buffer_len) {
            self.recordError(.frame, error.OutputLimitExceeded);
            return error.OutputLimitExceeded;
        }
        const remaining_capacity = self.options.max_compressed_buffer_len - self.frame_scratch.items.len;
        if (remaining_capacity == 0) return;
        const n = @min(remaining_capacity, input.len - input_read.*);
        try self.frame_scratch.appendSlice(self.allocator, input[input_read.*..][0..n]);
        input_read.* += n;
        self.input_received += n;
    }

    fn completeFrameAvailable(self: *NativeIncrementalFrameDecoder) Error!?usize {
        while (true) {
            if (self.frame_scratch.items.len < 4) return null;
            const magic = std.mem.readInt(u32, self.frame_scratch.items[0..4], .little);
            if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
                if (self.frame_scratch.items.len < 8) return null;
                const skip_len: usize = @intCast(std.mem.readInt(u32, self.frame_scratch.items[4..8], .little));
                const total = checkedAdd(8, skip_len) catch |err| {
                    self.recordError(.frame, err);
                    return err;
                };
                if (self.frame_scratch.items.len < total) return null;
                self.discardFrameScratchPrefix(total);
                continue;
            }
            break;
        }
        const end = findNativeFrameEnd(self.frame_scratch.items, 0) catch |err| switch (err) {
            error.TruncatedFrame => return null,
            else => {
                self.recordError(.frame, err);
                return err;
            },
        };
        return end;
    }

    fn decodeCompleteFrame(self: *NativeIncrementalFrameDecoder, frame: []const u8) Error!void {
        self.decoded_scratch.clearRetainingCapacity();
        self.decoded_offset = 0;
        if (self.dictionary_set) |dictionary_set| {
            _ = try decodeRawOrRleFrameAppendLimitedWithDictionarySet(self.allocator, &self.decoded_scratch, frame, self.options.max_decoded_buffer_len, dictionary_set);
        } else if (self.dictionary) |dictionary| {
            _ = try decodeRawOrRleFrameAppendLimitedWithDictionary(self.allocator, &self.decoded_scratch, frame, self.options.max_decoded_buffer_len, dictionary);
        } else {
            _ = try decodeRawOrRleFrameAppendLimited(self.allocator, &self.decoded_scratch, frame, self.options.max_decoded_buffer_len);
        }
    }

    fn beginDirectOutputIfSupported(self: *NativeIncrementalFrameDecoder, frame_end: usize) Error!bool {
        const frame = self.frame_scratch.items[0..frame_end];
        const header = try inspectNativeFrameHeader(frame);
        const dictionary_history = self.resolveDirectDictionaryHistory(header) catch |err| switch (err) {
            // Preserve the existing diagnostics path for missing or mismatched
            // dictionaries: the scratch decoder records `NeedDictionary` in the
            // frame phase. Direct output is an optimization, not a different
            // dictionary policy.
            error.NeedDictionary => return false,
            else => return err,
        };
        const frame_expected_len: ?usize = if (header.content_size) |size| blk: {
            const len = try checkedU64ToUsize(size);
            if (len > self.options.max_decoded_buffer_len) {
                self.recordError(.frame, error.OutputLimitExceeded);
                return error.OutputLimitExceeded;
            }
            break :blk len;
        } else null;
        const direct_limit = if (frame_expected_len) |len|
            len
        else if (self.options.expected_output_len) |expected| blk: {
            if (self.output_written > expected) {
                self.recordError(.frame, error.SizeMismatch);
                return error.SizeMismatch;
            }
            break :blk expected - self.output_written;
        } else self.options.max_decoded_buffer_len;
        const direct_limit_from_expected = frame_expected_len == null and self.options.expected_output_len != null;

        var offset = header.payload_offset;
        var first_payload_offset: usize = 0;
        var first_payload_len: usize = 0;
        var first_block_rle = false;
        var first_rle_byte: u8 = 0;
        var first_block_compressed = false;
        var first_block_decoded_len: usize = 0;
        var first_next_header: usize = 0;
        var total: usize = 0;
        var block_count: usize = 0;
        var any_block_compressed = false;
        var preflight_state: SequenceFrameState = .{};
        var content_hasher = std.hash.XxHash64.init(0);
        while (true) {
            if (frame.len - offset < 3) return error.TruncatedFrame;
            const block_header = std.mem.readInt(u24, frame[offset..][0..3], .little);
            offset += 3;
            const last = (block_header & 0x1) != 0;
            const block_type = (block_header >> 1) & 0x3;
            const block_len: usize = @intCast(block_header >> 3);
            try validateBlockSize(header, block_type, block_len);
            if (block_type != 0 and block_type != 1 and block_type != 2) return false;
            const payload_len: usize = if (block_type == 1) 1 else block_len;
            if (frame.len - offset < payload_len) return error.TruncatedFrame;
            const payload = frame[offset..][0..payload_len];
            if (block_type == 2) any_block_compressed = true;
            const decoded_block_len = if (block_type == 2) blk: {
                const initial_history_len = std.math.add(usize, dictionary_history.len, total) catch return error.IntegerOverflow;
                break :blk try compressedLiteralOnlyBlockDecodedSize(payload, header.block_size_max, initial_history_len, &preflight_state);
            } else block_len;
            total = checkedAddWithinLimit(total, decoded_block_len, direct_limit) catch |err| switch (err) {
                error.OutputLimitExceeded => {
                    if (direct_limit_from_expected) {
                        self.recordError(.frame, error.SizeMismatch);
                        return error.SizeMismatch;
                    }
                    return err;
                },
                else => return err,
            };
            if (block_count == 0) {
                first_payload_offset = offset;
                first_payload_len = block_len;
                first_block_rle = block_type == 1;
                first_rle_byte = if (block_type == 1) payload[0] else 0;
                first_block_compressed = block_type == 2;
                first_block_decoded_len = decoded_block_len;
            }
            if (header.has_checksum) {
                if (block_type == 1) {
                    var repeated: [256]u8 = undefined;
                    @memset(&repeated, payload[0]);
                    var remaining = block_len;
                    while (remaining != 0) {
                        const n = @min(remaining, repeated.len);
                        content_hasher.update(repeated[0..n]);
                        remaining -= n;
                    }
                } else if (block_type != 2) {
                    content_hasher.update(payload);
                }
            }
            offset += payload_len;
            if (block_count == 0) first_next_header = offset;
            block_count += 1;
            if (last) break;
        }
        if (block_count == 0) return false;
        if (header.has_checksum) {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const expected = std.mem.readInt(u32, frame[offset..][0..4], .little);
            if (!any_block_compressed and @as(u32, @truncate(content_hasher.final())) != expected) {
                self.recordError(.frame, error.ChecksumMismatch);
                return error.ChecksumMismatch;
            }
            offset += 4;
        }
        if (offset != frame_end) return false;
        if (frame_expected_len) |len| {
            if (total != len) return false;
        }

        self.decoded_scratch.clearRetainingCapacity();
        self.decoded_offset = 0;
        self.direct_payload_offset = first_payload_offset;
        self.direct_payload_len = first_payload_len;
        self.direct_payload_read = 0;
        self.direct_block_rle = first_block_rle;
        self.direct_rle_byte = first_rle_byte;
        self.direct_block_compressed = first_block_compressed;
        self.direct_block_decoded_len = first_block_decoded_len;
        self.direct_block_size_max = header.block_size_max;
        const frame_history_window = @min(total, try checkedU64ToUsize(header.window_size));
        self.direct_history_window_len = std.math.add(usize, dictionary_history.len, frame_history_window) catch return error.IntegerOverflow;
        self.direct_history.clearRetainingCapacity();
        try self.rememberDirectOutput(dictionary_history);
        self.direct_frame_output_start = self.output_written;
        self.direct_dictionary_history = dictionary_history;
        self.direct_sequence_state = .{};
        self.direct_next_block_header_offset = first_next_header;
        self.direct_decoded_len = total;
        self.direct_decoded_read = 0;
        self.direct_content_checksum = header.has_checksum;
        self.direct_content_hasher = std.hash.XxHash64.init(0);
        self.direct_expected_content_checksum = if (header.has_checksum)
            std.mem.readInt(u32, frame[offset - 4 ..][0..4], .little)
        else
            0;
        self.direct_frame_len = frame_end;
        return true;
    }

    fn resolveDirectDictionaryHistory(self: *const NativeIncrementalFrameDecoder, header: NativeFrameHeader) Error![]const u8 {
        if (header.dictionary_id == 0) return &.{};
        if (self.dictionary_set) |dictionary_set| {
            const dictionary = dictionary_set.find(header.dictionary_id) orelse return error.NeedDictionary;
            return dictionary.content;
        }
        return try validateNativeDictionary(header, self.dictionary);
    }

    fn advanceDirectOutputBlock(self: *NativeIncrementalFrameDecoder) Error!void {
        var offset = self.direct_next_block_header_offset;
        if (self.frame_scratch.items.len - offset < 3) return error.TruncatedFrame;
        const block_header = std.mem.readInt(u24, self.frame_scratch.items[offset..][0..3], .little);
        offset += 3;
        const block_type = (block_header >> 1) & 0x3;
        const block_len: usize = @intCast(block_header >> 3);
        if (block_type == 2) {
            if (block_len > std.compress.zstd.block_size_max) return error.CorruptFrame;
        } else if (block_type == 0 or block_type == 1) {
            if (block_len > self.direct_block_size_max) return error.CorruptFrame;
        } else {
            return error.CorruptFrame;
        }
        const payload_len: usize = if (block_type == 1) 1 else block_len;
        if (self.frame_scratch.items.len - offset < payload_len) return error.TruncatedFrame;
        self.direct_payload_offset = offset;
        self.direct_payload_len = block_len;
        self.direct_payload_read = 0;
        self.direct_block_rle = block_type == 1;
        self.direct_rle_byte = if (block_type == 1) self.frame_scratch.items[offset] else 0;
        self.direct_block_compressed = block_type == 2;
        self.direct_block_decoded_len = if (block_type == 2) blk: {
            var preflight_state = self.direct_sequence_state;
            break :blk try compressedLiteralOnlyBlockDecodedSize(
                self.frame_scratch.items[offset..][0..block_len],
                self.direct_block_size_max,
                std.math.add(usize, self.direct_dictionary_history.len, self.direct_decoded_read) catch return error.IntegerOverflow,
                &preflight_state,
            );
        } else block_len;
        self.direct_next_block_header_offset = offset + payload_len;
    }

    fn discardFrameScratchPrefix(self: *NativeIncrementalFrameDecoder, n: usize) void {
        if (n == 0) return;
        if (n == self.frame_scratch.items.len) {
            self.frame_scratch.clearRetainingCapacity();
            return;
        }
        const remaining_len = self.frame_scratch.items.len - n;
        std.mem.copyForwards(u8, self.frame_scratch.items[0..remaining_len], self.frame_scratch.items[n..]);
        self.frame_scratch.shrinkRetainingCapacity(remaining_len);
    }

    fn recordError(self: *NativeIncrementalFrameDecoder, phase: Phase, err: Error) void {
        self.last_error_name = @errorName(err);
        self.last_error_phase = phase;
    }

    fn phaseName(phase: Phase) []const u8 {
        return switch (phase) {
            .frame => "frame",
            .output => "output",
            .direct_output => "direct_output",
            .done => "done",
        };
    }
};

pub const NativeFrameDecoder = struct {
    allocator: std.mem.Allocator,
    scratch: std.ArrayList(u8) = .empty,

    pub fn init(allocator: std.mem.Allocator) NativeFrameDecoder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *NativeFrameDecoder) void {
        self.scratch.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn decodeAlloc(self: *NativeFrameDecoder, frame: []const u8) Error![]u8 {
        return try decodeRawOrRleFrameAlloc(self.allocator, frame);
    }

    pub fn decodeAllocExactSize(self: *NativeFrameDecoder, frame: []const u8, expected_output_len: usize) Error![]u8 {
        return try decodeRawOrRleFrameAllocExactSize(self.allocator, frame, expected_output_len);
    }

    pub fn decodeAllocWithDictionary(self: *NativeFrameDecoder, frame: []const u8, dictionary: NativeDictionary) Error![]u8 {
        return try decodeRawOrRleFrameAllocWithDictionary(self.allocator, frame, dictionary);
    }

    pub fn decodeAllocWithDictionaryExactSize(self: *NativeFrameDecoder, frame: []const u8, dictionary: NativeDictionary, expected_output_len: usize) Error![]u8 {
        return try decodeRawOrRleFrameAllocWithDictionaryExactSize(self.allocator, frame, dictionary, expected_output_len);
    }

    pub fn decodeAllocWithDictionarySet(self: *NativeFrameDecoder, frame: []const u8, dictionary_set: NativeDictionarySet) Error![]u8 {
        return try decodeRawOrRleFrameAllocWithDictionarySet(self.allocator, frame, dictionary_set);
    }

    pub fn decodeAllocWithDictionarySetExactSize(self: *NativeFrameDecoder, frame: []const u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error![]u8 {
        return try decodeRawOrRleFrameAllocWithDictionarySetExactSize(self.allocator, frame, dictionary_set, expected_output_len);
    }

    pub fn decodeAllocLimited(self: *NativeFrameDecoder, frame: []const u8, max_output_len: usize) Error![]u8 {
        return try decodeRawOrRleFrameAllocLimited(self.allocator, frame, max_output_len);
    }

    pub fn decodeAllocLimitedWithDictionary(self: *NativeFrameDecoder, frame: []const u8, max_output_len: usize, dictionary: NativeDictionary) Error![]u8 {
        return try decodeRawOrRleFrameAllocLimitedWithDictionary(self.allocator, frame, max_output_len, dictionary);
    }

    pub fn decodeAllocLimitedWithDictionarySet(self: *NativeFrameDecoder, frame: []const u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error![]u8 {
        return try decodeRawOrRleFrameAllocLimitedWithDictionarySet(self.allocator, frame, max_output_len, dictionary_set);
    }

    pub fn decodeScratch(self: *NativeFrameDecoder, frame: []const u8) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeAppend(&self.scratch, frame);
        return self.scratch.items;
    }

    pub fn decodeScratchWithDictionary(self: *NativeFrameDecoder, frame: []const u8, dictionary: NativeDictionary) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeAppendWithDictionary(&self.scratch, frame, dictionary);
        return self.scratch.items;
    }

    pub fn decodeScratchWithDictionarySet(self: *NativeFrameDecoder, frame: []const u8, dictionary_set: NativeDictionarySet) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeAppendWithDictionarySet(&self.scratch, frame, dictionary_set);
        return self.scratch.items;
    }

    pub fn decodeScratchLimited(self: *NativeFrameDecoder, frame: []const u8, max_output_len: usize) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeAppendLimited(&self.scratch, frame, max_output_len);
        return self.scratch.items;
    }

    pub fn decodeScratchLimitedWithDictionary(self: *NativeFrameDecoder, frame: []const u8, max_output_len: usize, dictionary: NativeDictionary) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeAppendLimitedWithDictionary(&self.scratch, frame, max_output_len, dictionary);
        return self.scratch.items;
    }

    pub fn decodeScratchLimitedWithDictionarySet(self: *NativeFrameDecoder, frame: []const u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeAppendLimitedWithDictionarySet(&self.scratch, frame, max_output_len, dictionary_set);
        return self.scratch.items;
    }

    pub fn decodeAppend(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frame: []const u8) Error!usize {
        return try decodeRawOrRleFrameAppend(self.allocator, out, frame);
    }

    pub fn decodeAppendExactSize(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frame: []const u8, expected_output_len: usize) Error!usize {
        return try decodeRawOrRleFrameAppendExactSize(self.allocator, out, frame, expected_output_len);
    }

    pub fn decodeAppendWithDictionary(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frame: []const u8, dictionary: NativeDictionary) Error!usize {
        return try decodeRawOrRleFrameAppendWithDictionary(self.allocator, out, frame, dictionary);
    }

    pub fn decodeAppendExactSizeWithDictionary(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frame: []const u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
        return try decodeRawOrRleFrameAppendExactSizeWithDictionary(self.allocator, out, frame, dictionary, expected_output_len);
    }

    pub fn decodeAppendWithDictionarySet(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frame: []const u8, dictionary_set: NativeDictionarySet) Error!usize {
        return try decodeRawOrRleFrameAppendWithDictionarySet(self.allocator, out, frame, dictionary_set);
    }

    pub fn decodeAppendExactSizeWithDictionarySet(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frame: []const u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
        return try decodeRawOrRleFrameAppendExactSizeWithDictionarySet(self.allocator, out, frame, dictionary_set, expected_output_len);
    }

    pub fn decodeAppendLimited(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frame: []const u8, max_output_len: usize) Error!usize {
        return try decodeRawOrRleFrameAppendLimited(self.allocator, out, frame, max_output_len);
    }

    pub fn decodeAppendLimitedWithDictionary(
        self: *NativeFrameDecoder,
        out: *std.ArrayList(u8),
        frame: []const u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error!usize {
        return try decodeRawOrRleFrameAppendLimitedWithDictionary(self.allocator, out, frame, max_output_len, dictionary);
    }

    pub fn decodeAppendLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        out: *std.ArrayList(u8),
        frame: []const u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error!usize {
        return try decodeRawOrRleFrameAppendLimitedWithDictionarySet(self.allocator, out, frame, max_output_len, dictionary_set);
    }

    pub fn decodeIntoSlice(self: *NativeFrameDecoder, frame: []const u8, output: []u8) Error!usize {
        _ = self;
        return try decodeRawOrRleFrameInto(frame, output);
    }

    pub fn decodeIntoSliceExactSize(self: *NativeFrameDecoder, frame: []const u8, output: []u8, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeRawOrRleFrameIntoExactSize(frame, output, expected_output_len);
    }

    pub fn decodeIntoSliceWithDictionary(self: *NativeFrameDecoder, frame: []const u8, output: []u8, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodeRawOrRleFrameIntoWithDictionary(frame, output, dictionary);
    }

    pub fn decodeIntoSliceWithDictionaryExactSize(self: *NativeFrameDecoder, frame: []const u8, output: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeRawOrRleFrameIntoWithDictionaryExactSize(frame, output, dictionary, expected_output_len);
    }

    pub fn decodeIntoSliceWithDictionarySet(self: *NativeFrameDecoder, frame: []const u8, output: []u8, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodeRawOrRleFrameIntoWithDictionarySet(frame, output, dictionary_set);
    }

    pub fn decodeIntoSliceWithDictionarySetExactSize(self: *NativeFrameDecoder, frame: []const u8, output: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeRawOrRleFrameIntoWithDictionarySetExactSize(frame, output, dictionary_set, expected_output_len);
    }

    pub fn decodedSize(self: *NativeFrameDecoder, frame: []const u8) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameSize(frame);
    }

    pub fn decodedSizeLimited(self: *NativeFrameDecoder, frame: []const u8, max_output_len: usize) Error!usize {
        _ = self;
        return try rawOrRleDecodedSizeLimited(frame, max_output_len);
    }

    pub fn decodedSizeWithDictionary(self: *NativeFrameDecoder, frame: []const u8, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameSizeWithDictionary(frame, dictionary);
    }

    pub fn decodedSizeLimitedWithDictionary(self: *NativeFrameDecoder, frame: []const u8, max_output_len: usize, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameSizeLimitedWithDictionary(frame, max_output_len, dictionary);
    }

    pub fn decodedSizeWithDictionarySet(self: *NativeFrameDecoder, frame: []const u8, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameSizeWithDictionarySet(frame, dictionary_set);
    }

    pub fn decodedSizeLimitedWithDictionarySet(self: *NativeFrameDecoder, frame: []const u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameSizeLimitedWithDictionarySet(frame, max_output_len, dictionary_set);
    }

    pub fn decodeChunksAlloc(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8) Error![]u8 {
        return try decodeRawOrRleFrameChunksAlloc(self.allocator, chunks, compressed_scratch);
    }

    pub fn decodeChunksAllocExactSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocExactSize(self.allocator, chunks, compressed_scratch, expected_output_len);
    }

    pub fn decodeChunksAllocLimited(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocLimited(self.allocator, chunks, compressed_scratch, max_output_len);
    }

    pub fn decodeChunksScratch(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeChunksAppend(&self.scratch, chunks, compressed_scratch);
        return self.scratch.items;
    }

    pub fn decodeChunksScratchLimited(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeChunksAppendLimited(&self.scratch, chunks, compressed_scratch, max_output_len);
        return self.scratch.items;
    }

    pub fn decodeChunksAppend(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
        return try decodeRawOrRleFrameChunksAppend(self.allocator, out, chunks, compressed_scratch);
    }

    pub fn decodeChunksAppendExactSize(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error!usize {
        return try decodeRawOrRleFrameChunksAppendExactSize(self.allocator, out, chunks, compressed_scratch, expected_output_len);
    }

    pub fn decodeChunksAppendLimited(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
        return try decodeRawOrRleFrameChunksAppendLimited(self.allocator, out, chunks, compressed_scratch, max_output_len);
    }

    pub fn decodeChunksIntoSlice(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8) Error!usize {
        _ = self;
        return try decodeRawOrRleFrameChunksInto(chunks, compressed_scratch, output);
    }

    pub fn decodeChunksIntoSliceExactSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeRawOrRleFrameChunksIntoExactSize(chunks, compressed_scratch, output, expected_output_len);
    }

    pub fn decodedChunksSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameChunksSize(chunks, compressed_scratch);
    }

    pub fn decodedChunksSizeLimited(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameChunksSizeLimited(chunks, compressed_scratch, max_output_len);
    }

    pub fn decodeChunksAllocWithDictionary(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocWithDictionary(self.allocator, chunks, compressed_scratch, dictionary);
    }

    pub fn decodeChunksAllocExactSizeWithDictionary(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        dictionary: NativeDictionary,
        expected_output_len: usize,
    ) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocWithDictionaryExactSize(self.allocator, chunks, compressed_scratch, dictionary, expected_output_len);
    }

    pub fn decodeChunksAllocLimitedWithDictionary(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocWithDictionaryLimited(self.allocator, chunks, compressed_scratch, dictionary, max_output_len);
    }

    pub fn decodeChunksScratchWithDictionary(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeChunksAppendWithDictionary(&self.scratch, chunks, compressed_scratch, dictionary);
        return self.scratch.items;
    }

    pub fn decodeChunksScratchLimitedWithDictionary(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeChunksAppendLimitedWithDictionary(&self.scratch, chunks, compressed_scratch, max_output_len, dictionary);
        return self.scratch.items;
    }

    pub fn decodeChunksAppendWithDictionary(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error!usize {
        return try decodeRawOrRleFrameChunksAppendWithDictionary(self.allocator, out, chunks, compressed_scratch, dictionary);
    }

    pub fn decodeChunksAppendExactSizeWithDictionary(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
        return try decodeRawOrRleFrameChunksAppendExactSizeWithDictionary(self.allocator, out, chunks, compressed_scratch, dictionary, expected_output_len);
    }

    pub fn decodeChunksAppendLimitedWithDictionary(
        self: *NativeFrameDecoder,
        out: *std.ArrayList(u8),
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error!usize {
        return try decodeRawOrRleFrameChunksAppendLimitedWithDictionary(self.allocator, out, chunks, compressed_scratch, max_output_len, dictionary);
    }

    pub fn decodeChunksIntoSliceWithDictionary(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodeRawOrRleFrameChunksIntoWithDictionary(chunks, compressed_scratch, output, dictionary);
    }

    pub fn decodeChunksIntoSliceWithDictionaryExactSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeRawOrRleFrameChunksIntoExactSizeWithDictionary(chunks, compressed_scratch, output, dictionary, expected_output_len);
    }

    pub fn decodedChunksSizeWithDictionary(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameChunksSizeWithDictionary(chunks, compressed_scratch, dictionary);
    }

    pub fn decodedChunksSizeLimitedWithDictionary(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameChunksSizeLimitedWithDictionary(chunks, compressed_scratch, max_output_len, dictionary);
    }

    pub fn decodeChunksAllocWithDictionarySet(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocWithDictionarySet(self.allocator, chunks, compressed_scratch, dictionary_set);
    }

    pub fn decodeChunksAllocExactSizeWithDictionarySet(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        dictionary_set: NativeDictionarySet,
        expected_output_len: usize,
    ) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocWithDictionarySetExactSize(self.allocator, chunks, compressed_scratch, dictionary_set, expected_output_len);
    }

    pub fn decodeChunksAllocLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocWithDictionarySetLimited(self.allocator, chunks, compressed_scratch, dictionary_set, max_output_len);
    }

    pub fn decodeChunksScratchWithDictionarySet(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeChunksAppendWithDictionarySet(&self.scratch, chunks, compressed_scratch, dictionary_set);
        return self.scratch.items;
    }

    pub fn decodeChunksScratchLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeChunksAppendLimitedWithDictionarySet(&self.scratch, chunks, compressed_scratch, max_output_len, dictionary_set);
        return self.scratch.items;
    }

    pub fn decodeChunksAppendWithDictionarySet(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error!usize {
        return try decodeRawOrRleFrameChunksAppendWithDictionarySet(self.allocator, out, chunks, compressed_scratch, dictionary_set);
    }

    pub fn decodeChunksAppendExactSizeWithDictionarySet(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
        return try decodeRawOrRleFrameChunksAppendExactSizeWithDictionarySet(self.allocator, out, chunks, compressed_scratch, dictionary_set, expected_output_len);
    }

    pub fn decodeChunksAppendLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        out: *std.ArrayList(u8),
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error!usize {
        return try decodeRawOrRleFrameChunksAppendLimitedWithDictionarySet(self.allocator, out, chunks, compressed_scratch, max_output_len, dictionary_set);
    }

    pub fn decodeChunksIntoSliceWithDictionarySet(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodeRawOrRleFrameChunksIntoWithDictionarySet(chunks, compressed_scratch, output, dictionary_set);
    }

    pub fn decodeChunksIntoSliceWithDictionarySetExactSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeRawOrRleFrameChunksIntoExactSizeWithDictionarySet(chunks, compressed_scratch, output, dictionary_set, expected_output_len);
    }

    pub fn decodedChunksSizeWithDictionarySet(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameChunksSizeWithDictionarySet(chunks, compressed_scratch, dictionary_set);
    }

    pub fn decodedChunksSizeLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameChunksSizeLimitedWithDictionarySet(chunks, compressed_scratch, max_output_len, dictionary_set);
    }

    pub const decodeConcatenatedAlloc = decodeAlloc;
    pub const decodeConcatenatedAllocExactSize = decodeAllocExactSize;
    pub const decodeConcatenatedAllocLimited = decodeAllocLimited;
    pub const decodeConcatenatedScratch = decodeScratch;
    pub const decodeConcatenatedScratchLimited = decodeScratchLimited;
    pub const decodeConcatenatedAppend = decodeAppend;
    pub const decodeConcatenatedAppendExactSize = decodeAppendExactSize;
    pub const decodeConcatenatedAppendLimited = decodeAppendLimited;
    pub const decodeConcatenatedIntoSlice = decodeIntoSlice;
    pub const decodeConcatenatedIntoSliceExactSize = decodeIntoSliceExactSize;
    pub const decodeConcatenatedAllocWithDictionary = decodeAllocWithDictionary;
    pub const decodeConcatenatedAllocWithDictionaryExactSize = decodeAllocWithDictionaryExactSize;
    pub const decodeConcatenatedAllocLimitedWithDictionary = decodeAllocLimitedWithDictionary;
    pub const decodeConcatenatedScratchWithDictionary = decodeScratchWithDictionary;
    pub const decodeConcatenatedScratchLimitedWithDictionary = decodeScratchLimitedWithDictionary;
    pub const decodeConcatenatedAppendWithDictionary = decodeAppendWithDictionary;
    pub const decodeConcatenatedAppendExactSizeWithDictionary = decodeAppendExactSizeWithDictionary;
    pub const decodeConcatenatedAppendLimitedWithDictionary = decodeAppendLimitedWithDictionary;
    pub const decodeConcatenatedIntoSliceWithDictionary = decodeIntoSliceWithDictionary;
    pub const decodeConcatenatedAllocWithDictionarySet = decodeAllocWithDictionarySet;
    pub const decodeConcatenatedAllocWithDictionarySetExactSize = decodeAllocWithDictionarySetExactSize;
    pub const decodeConcatenatedAllocLimitedWithDictionarySet = decodeAllocLimitedWithDictionarySet;
    pub const decodeConcatenatedScratchWithDictionarySet = decodeScratchWithDictionarySet;
    pub const decodeConcatenatedScratchLimitedWithDictionarySet = decodeScratchLimitedWithDictionarySet;
    pub const decodeConcatenatedAppendWithDictionarySet = decodeAppendWithDictionarySet;
    pub const decodeConcatenatedAppendExactSizeWithDictionarySet = decodeAppendExactSizeWithDictionarySet;
    pub const decodeConcatenatedAppendLimitedWithDictionarySet = decodeAppendLimitedWithDictionarySet;
    pub const decodeConcatenatedIntoSliceWithDictionarySet = decodeIntoSliceWithDictionarySet;

    pub fn decodedConcatenatedSize(self: *NativeFrameDecoder, frames: []const u8) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameSize(frames);
    }

    pub fn decodedConcatenatedSizeLimited(self: *NativeFrameDecoder, frames: []const u8, max_output_len: usize) Error!usize {
        _ = self;
        return try rawOrRleDecodedSizeLimited(frames, max_output_len);
    }

    pub fn decodedConcatenatedSizeWithDictionary(self: *NativeFrameDecoder, frames: []const u8, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameSizeWithDictionary(frames, dictionary);
    }

    pub fn decodedConcatenatedSizeLimitedWithDictionary(self: *NativeFrameDecoder, frames: []const u8, max_output_len: usize, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameSizeLimitedWithDictionary(frames, max_output_len, dictionary);
    }

    pub fn decodedConcatenatedSizeWithDictionarySet(self: *NativeFrameDecoder, frames: []const u8, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameSizeWithDictionarySet(frames, dictionary_set);
    }

    pub fn decodedConcatenatedSizeLimitedWithDictionarySet(self: *NativeFrameDecoder, frames: []const u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameSizeLimitedWithDictionarySet(frames, max_output_len, dictionary_set);
    }

    pub fn decodeConcatenatedChunksAlloc(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8) Error![]u8 {
        return try decodeRawOrRleFrameChunksAlloc(self.allocator, chunks, compressed_scratch);
    }

    pub fn decodeConcatenatedChunksAllocExactSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocExactSize(self.allocator, chunks, compressed_scratch, expected_output_len);
    }

    pub fn decodeConcatenatedChunksAllocLimited(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocLimited(self.allocator, chunks, compressed_scratch, max_output_len);
    }

    pub fn decodeConcatenatedChunksScratch(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeConcatenatedChunksAppend(&self.scratch, chunks, compressed_scratch);
        return self.scratch.items;
    }

    pub fn decodeConcatenatedChunksScratchLimited(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeConcatenatedChunksAppendLimited(&self.scratch, chunks, compressed_scratch, max_output_len);
        return self.scratch.items;
    }

    pub fn decodeConcatenatedChunksAppend(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
        const joined = try joinChunks(chunks, compressed_scratch);
        return try self.decodeConcatenatedAppend(out, joined);
    }

    pub fn decodeConcatenatedChunksAppendExactSize(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error!usize {
        const joined = try joinChunks(chunks, compressed_scratch);
        return try self.decodeConcatenatedAppendExactSize(out, joined, expected_output_len);
    }

    pub fn decodeConcatenatedChunksAppendLimited(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
        const joined = try joinChunks(chunks, compressed_scratch);
        return try self.decodeConcatenatedAppendLimited(out, joined, max_output_len);
    }

    pub fn decodeConcatenatedChunksIntoSlice(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8) Error!usize {
        _ = self;
        return try decodeRawOrRleFrameChunksInto(chunks, compressed_scratch, output);
    }

    pub fn decodeConcatenatedChunksAllocWithDictionary(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocWithDictionary(self.allocator, chunks, compressed_scratch, dictionary);
    }

    pub fn decodeConcatenatedChunksAllocExactSizeWithDictionary(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        dictionary: NativeDictionary,
        expected_output_len: usize,
    ) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocWithDictionaryExactSize(self.allocator, chunks, compressed_scratch, dictionary, expected_output_len);
    }

    pub fn decodeConcatenatedChunksAllocLimitedWithDictionary(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocWithDictionaryLimited(self.allocator, chunks, compressed_scratch, dictionary, max_output_len);
    }

    pub fn decodeConcatenatedChunksScratchWithDictionary(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeConcatenatedChunksAppendWithDictionary(&self.scratch, chunks, compressed_scratch, dictionary);
        return self.scratch.items;
    }

    pub fn decodeConcatenatedChunksScratchLimitedWithDictionary(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeConcatenatedChunksAppendLimitedWithDictionary(&self.scratch, chunks, compressed_scratch, max_output_len, dictionary);
        return self.scratch.items;
    }

    pub fn decodeConcatenatedChunksAppendWithDictionary(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error!usize {
        const joined = try joinChunks(chunks, compressed_scratch);
        return try self.decodeConcatenatedAppendWithDictionary(out, joined, dictionary);
    }

    pub fn decodeConcatenatedChunksAppendExactSizeWithDictionary(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
        const joined = try joinChunks(chunks, compressed_scratch);
        return try self.decodeConcatenatedAppendExactSizeWithDictionary(out, joined, dictionary, expected_output_len);
    }

    pub fn decodeConcatenatedChunksAppendLimitedWithDictionary(
        self: *NativeFrameDecoder,
        out: *std.ArrayList(u8),
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error!usize {
        const joined = try joinChunks(chunks, compressed_scratch);
        return try self.decodeConcatenatedAppendLimitedWithDictionary(out, joined, max_output_len, dictionary);
    }

    pub fn decodeConcatenatedChunksIntoSliceWithDictionary(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodeRawOrRleFrameChunksIntoWithDictionary(chunks, compressed_scratch, output, dictionary);
    }

    pub fn decodeConcatenatedChunksAllocWithDictionarySet(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocWithDictionarySet(self.allocator, chunks, compressed_scratch, dictionary_set);
    }

    pub fn decodeConcatenatedChunksAllocExactSizeWithDictionarySet(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        dictionary_set: NativeDictionarySet,
        expected_output_len: usize,
    ) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocWithDictionarySetExactSize(self.allocator, chunks, compressed_scratch, dictionary_set, expected_output_len);
    }

    pub fn decodeConcatenatedChunksAllocLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error![]u8 {
        return try decodeRawOrRleFrameChunksAllocWithDictionarySetLimited(self.allocator, chunks, compressed_scratch, dictionary_set, max_output_len);
    }

    pub fn decodeConcatenatedChunksScratchWithDictionarySet(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeConcatenatedChunksAppendWithDictionarySet(&self.scratch, chunks, compressed_scratch, dictionary_set);
        return self.scratch.items;
    }

    pub fn decodeConcatenatedChunksScratchLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeConcatenatedChunksAppendLimitedWithDictionarySet(&self.scratch, chunks, compressed_scratch, max_output_len, dictionary_set);
        return self.scratch.items;
    }

    pub fn decodeConcatenatedChunksAppendWithDictionarySet(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error!usize {
        const joined = try joinChunks(chunks, compressed_scratch);
        return try self.decodeConcatenatedAppendWithDictionarySet(out, joined, dictionary_set);
    }

    pub fn decodeConcatenatedChunksAppendExactSizeWithDictionarySet(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
        const joined = try joinChunks(chunks, compressed_scratch);
        return try self.decodeConcatenatedAppendExactSizeWithDictionarySet(out, joined, dictionary_set, expected_output_len);
    }

    pub fn decodeConcatenatedChunksAppendLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        out: *std.ArrayList(u8),
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error!usize {
        const joined = try joinChunks(chunks, compressed_scratch);
        return try self.decodeConcatenatedAppendLimitedWithDictionarySet(out, joined, max_output_len, dictionary_set);
    }

    pub fn decodeConcatenatedChunksIntoSliceWithDictionarySet(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodeRawOrRleFrameChunksIntoWithDictionarySet(chunks, compressed_scratch, output, dictionary_set);
    }

    pub fn decodedConcatenatedChunksSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameChunksSize(chunks, compressed_scratch);
    }

    pub fn decodedConcatenatedChunksSizeLimited(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameChunksSizeLimited(chunks, compressed_scratch, max_output_len);
    }

    pub fn decodedConcatenatedChunksSizeWithDictionary(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameChunksSizeWithDictionary(chunks, compressed_scratch, dictionary);
    }

    pub fn decodedConcatenatedChunksSizeLimitedWithDictionary(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameChunksSizeLimitedWithDictionary(chunks, compressed_scratch, max_output_len, dictionary);
    }

    pub fn decodedConcatenatedChunksSizeWithDictionarySet(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameChunksSizeWithDictionarySet(chunks, compressed_scratch, dictionary_set);
    }

    pub fn decodedConcatenatedChunksSizeLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error!usize {
        _ = self;
        return try decodedRawOrRleFrameChunksSizeLimitedWithDictionarySet(chunks, compressed_scratch, max_output_len, dictionary_set);
    }
};

/// Compress a complete Zstandard frame using the reference-compatible libzstd
/// encoder linked by Vort's build. Keeping this call surface in Vort centralizes
/// compression ownership for downstream formats such as MCAP while leaving room
/// to replace the backend with a pure Zig implementation ported from
/// `~/Work/zstd` internals later.
pub fn encodeFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return try encodeFrameWithLevelAlloc(allocator, input, default_compression_level);
}

pub fn encodeFrameWithLevelAlloc(allocator: std.mem.Allocator, input: []const u8, level: c_int) Error![]u8 {
    return try encodeFrameWithLevelAndOptionsAlloc(allocator, input, level, .{});
}

pub fn encodeFrameWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: LibFrameOptions) Error![]u8 {
    return try encodeFrameWithLevelAndOptionsAlloc(allocator, input, default_compression_level, options);
}

pub fn encodeFrameWithLevelAndOptionsAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    level: c_int,
    options: LibFrameOptions,
) Error![]u8 {
    const bound = ZSTD_compressBound(input.len);
    if (ZSTD_isError(bound) != 0) return error.CorruptFrame;
    var out = try allocator.alloc(u8, bound);
    errdefer allocator.free(out);

    const cctx = ZSTD_createCCtx() orelse return error.OutOfMemory;
    defer _ = ZSTD_freeCCtx(cctx);

    // Use the advanced one-shot API only when callers need frame policy
    // control. The default options preserve the historical ZSTD_compress()
    // behavior while allowing downstream containers such as MCAP to avoid
    // duplicating metadata they already carry at the format layer.
    if (ZSTD_isError(ZSTD_CCtx_setParameter(cctx, zstd_c_compression_level, level)) != 0) return error.CorruptFrame;
    if (ZSTD_isError(ZSTD_CCtx_setParameter(cctx, zstd_c_content_size_flag, if (options.include_content_size) 1 else 0)) != 0) return error.CorruptFrame;
    if (ZSTD_isError(ZSTD_CCtx_setParameter(cctx, zstd_c_checksum_flag, if (options.content_checksum) 1 else 0)) != 0) return error.CorruptFrame;

    const written = ZSTD_compress2(cctx, @ptrCast(out.ptr), out.len, @ptrCast(input.ptr), input.len);
    if (ZSTD_isError(written) != 0) return error.CorruptFrame;
    if (allocator.remap(out, written)) |shrunk| return shrunk;
    const exact = try allocator.dupe(u8, out[0..written]);
    allocator.free(out);
    return exact;
}

/// Emit a valid Zstandard frame composed of raw and RLE blocks.
///
/// This dependency-free fallback remains useful for bootstrapping and for tiny
/// repeated-byte payloads. General-purpose MCAP chunk writing uses
/// `encodeFrameAlloc()` so it benefits from the full zstd entropy encoder.
pub fn encodeRawOrRleFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return try encodeRawOrRleFrameWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeRawOrRleFrameWithOptionsAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try encodeRawOrRleFrameAppend(allocator, &out, input, options);
    return out.toOwnedSlice(allocator);
}

pub fn encodeRawOrRleFrameAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: NativeFrameOptions,
) Error!void {
    _ = try nativeMatchSearchBudget(options);
    try emitFrameHeader(allocator, out, try checkedUsizeToU64(input.len), options);
    const block_size_max = try nativeBlockSizeMax(options);
    if (input.len == 0) {
        try emitBlock(allocator, out, "", true);
    } else {
        var offset: usize = 0;
        while (offset < input.len) {
            const search_end = @min(input.len, offset + block_size_max);
            if (findRleRun(input[offset..search_end])) |run| {
                const run_start = offset + run.start;
                if (run_start > offset) try emitBlock(allocator, out, input[offset..run_start], false);
                const run_end = run_start + run.len;
                try emitRleBlock(allocator, out, input[run_start], run.len, run_end == input.len);
                offset = run_end;
            } else {
                try emitBlock(allocator, out, input[offset..search_end], search_end == input.len);
                offset = search_end;
            }
        }
    }
    try emitContentChecksum(allocator, out, input, options);
}

pub fn encodeRawOrRleFrameIntoSlice(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
    output: []u8,
) Error!usize {
    var encoder = NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    const result = try encoder.encodeIntoSlice(input, forceNativeSelection(options, .raw_or_rle), output);
    return result.written;
}

pub fn encodeLiteralOnlyFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return try encodeLiteralOnlyFrameWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeLiteralOnlyFrameWithOptionsAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try encodeLiteralOnlyFrameAppend(allocator, &out, input, options);
    return out.toOwnedSlice(allocator);
}

pub fn encodeLiteralOnlyFrameAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: NativeFrameOptions,
) Error!void {
    try encodeLiteralOnlyFrameAppendWithDictionaryInternal(allocator, out, input, options, null);
}

fn encodeLiteralOnlyFrameAppendWithDictionaryInternal(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: NativeFrameOptions,
    dictionary: ?NativeDictionary,
) Error!void {
    const frame_options = optionsWithNativeDictionary(options, dictionary);
    const match_search_budget = try nativeMatchSearchBudget(frame_options);
    try emitFrameHeader(allocator, out, try checkedUsizeToU64(input.len), frame_options);

    var offset: usize = 0;
    const block_size_max = try nativeBlockSizeMax(frame_options);
    var encoder_state: LiteralOnlyEncoderState = .{};
    if (input.len == 0) {
        try emitLiteralOnlyCompressedBlockWithDictionary(allocator, out, "", true, &encoder_state, dictionary, 0, match_search_budget);
    } else {
        while (offset < input.len) {
            const block_end = @min(input.len, offset + block_size_max);
            try emitLiteralOnlyCompressedBlockWithDictionary(allocator, out, input[offset..block_end], block_end == input.len, &encoder_state, dictionary, offset, match_search_budget);
            offset = block_end;
        }
    }

    try emitContentChecksum(allocator, out, input, frame_options);
}

pub fn encodeLiteralOnlyFrameIntoSlice(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
    output: []u8,
) Error!usize {
    var encoder = NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    const result = try encoder.encodeIntoSlice(input, forceNativeSelection(options, .literal_only), output);
    return result.written;
}

pub fn encodedSkippableFrameBound(payload_len: usize) Error!usize {
    _ = try checkedUsizeToU32(payload_len);
    return std.math.add(usize, 8, payload_len) catch return error.IntegerOverflow;
}

pub fn encodeSkippableFrameAlloc(allocator: std.mem.Allocator, skippable_id: u4, payload: []const u8) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try encodeSkippableFrameAppend(allocator, &out, skippable_id, payload);
    return out.toOwnedSlice(allocator);
}

pub fn encodeSkippableFrameAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), skippable_id: u4, payload: []const u8) Error!void {
    var header: [8]u8 = undefined;
    std.mem.writeInt(u32, header[0..4], skippable_magic_min + @as(u32, skippable_id), .little);
    std.mem.writeInt(u32, header[4..8], try checkedUsizeToU32(payload.len), .little);
    try out.appendSlice(allocator, &header);
    try out.appendSlice(allocator, payload);
}

pub fn encodeSkippableFrameIntoSlice(skippable_id: u4, payload: []const u8, output: []u8) Error!usize {
    const written = try encodedSkippableFrameBound(payload.len);
    if (output.len < written) return error.OutputTooSmall;
    var header: [8]u8 = undefined;
    std.mem.writeInt(u32, header[0..4], skippable_magic_min + @as(u32, skippable_id), .little);
    std.mem.writeInt(u32, header[4..8], try checkedUsizeToU32(payload.len), .little);
    @memcpy(output[0..8], &header);
    @memcpy(output[8..][0..payload.len], payload);
    return written;
}

pub fn encodeNativeFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    var encoder = NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    return try encoder.encodeAlloc(input);
}

pub fn encodeNativeFrameWithOptionsAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
) Error!NativeFrameEncodeResult {
    var encoder = NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    return try encoder.encodeWithOptionsAlloc(input, options);
}

pub fn encodeNativeFrameWithDictionaryAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
    dictionary: NativeDictionary,
) Error!NativeFrameEncodeResult {
    var encoder = NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    return try encoder.encodeWithDictionaryAlloc(input, options, dictionary);
}

pub fn encodeNativeFrameAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: NativeFrameOptions,
) Error!NativeFrameMode {
    var encoder = NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    return try encoder.encodeAppend(out, input, options);
}

pub fn encodeNativeFrameAppendWithDictionary(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: NativeFrameOptions,
    dictionary: NativeDictionary,
) Error!NativeFrameMode {
    var encoder = NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    return try encoder.encodeAppendWithDictionary(out, input, options, dictionary);
}

pub fn encodeNativeFrameIntoSlice(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
    output: []u8,
) Error!NativeFrameEncodeIntoResult {
    var encoder = NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    return try encoder.encodeIntoSlice(input, options, output);
}

pub fn encodeNativeFrameIntoSliceWithDictionary(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
    dictionary: NativeDictionary,
    output: []u8,
) Error!NativeFrameEncodeIntoResult {
    var encoder = NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    return try encoder.encodeIntoSliceWithDictionary(input, options, dictionary, output);
}

pub fn encodeNativeFrameWithDictionarySetAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
    dictionary_set: NativeDictionarySet,
    dictionary_id: u32,
) Error!NativeFrameEncodeResult {
    const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
    return try encodeNativeFrameWithDictionaryAlloc(allocator, input, options, dictionary);
}

pub fn encodeNativeFrameAppendWithDictionarySet(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: NativeFrameOptions,
    dictionary_set: NativeDictionarySet,
    dictionary_id: u32,
) Error!NativeFrameMode {
    const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
    return try encodeNativeFrameAppendWithDictionary(allocator, out, input, options, dictionary);
}

pub fn encodeNativeFrameIntoSliceWithDictionarySet(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
    dictionary_set: NativeDictionarySet,
    dictionary_id: u32,
    output: []u8,
) Error!NativeFrameEncodeIntoResult {
    const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
    return try encodeNativeFrameIntoSliceWithDictionary(allocator, input, options, dictionary, output);
}

fn dictionaryFromSet(dictionary_set: NativeDictionarySet, dictionary_id: u32) Error!NativeDictionary {
    if (dictionary_id == 0) return error.NeedDictionary;
    return dictionary_set.find(dictionary_id) orelse error.NeedDictionary;
}

pub const NativeFrameEncoder = struct {
    allocator: std.mem.Allocator,
    raw_scratch: std.ArrayList(u8) = .empty,
    literal_scratch: std.ArrayList(u8) = .empty,
    output_scratch: std.ArrayList(u8) = .empty,

    pub fn init(allocator: std.mem.Allocator) NativeFrameEncoder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *NativeFrameEncoder) void {
        self.output_scratch.deinit(self.allocator);
        self.literal_scratch.deinit(self.allocator);
        self.raw_scratch.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn encodeAlloc(self: *NativeFrameEncoder, input: []const u8) Error![]u8 {
        const result = try self.encodeWithOptionsAlloc(input, .{});
        return result.frame;
    }

    pub fn encodeWithOptionsAlloc(
        self: *NativeFrameEncoder,
        input: []const u8,
        options: NativeFrameOptions,
    ) Error!NativeFrameEncodeResult {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(self.allocator);
        const mode = try self.encodeAppend(&out, input, options);
        return .{
            .frame = try out.toOwnedSlice(self.allocator),
            .mode = mode,
        };
    }

    pub fn encodeWithDictionaryAlloc(
        self: *NativeFrameEncoder,
        input: []const u8,
        options: NativeFrameOptions,
        dictionary: NativeDictionary,
    ) Error!NativeFrameEncodeResult {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(self.allocator);
        const mode = try self.encodeAppendWithDictionary(&out, input, options, dictionary);
        return .{
            .frame = try out.toOwnedSlice(self.allocator),
            .mode = mode,
        };
    }

    pub fn encodeWithDictionarySetAlloc(self: *NativeFrameEncoder, input: []const u8, options: NativeFrameOptions, dictionary_set: NativeDictionarySet, dictionary_id: u32) Error!NativeFrameEncodeResult {
        const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
        return try self.encodeWithDictionaryAlloc(input, options, dictionary);
    }

    pub fn encodeScratch(
        self: *NativeFrameEncoder,
        input: []const u8,
        options: NativeFrameOptions,
    ) Error!NativeFrameEncodeScratchResult {
        self.output_scratch.clearRetainingCapacity();
        const mode = self.encodeAppend(&self.output_scratch, input, options) catch |err| {
            self.output_scratch.clearRetainingCapacity();
            return err;
        };
        return .{
            .frame = self.output_scratch.items,
            .mode = mode,
        };
    }

    pub fn encodeScratchWithDictionary(
        self: *NativeFrameEncoder,
        input: []const u8,
        options: NativeFrameOptions,
        dictionary: NativeDictionary,
    ) Error!NativeFrameEncodeScratchResult {
        self.output_scratch.clearRetainingCapacity();
        const mode = self.encodeAppendWithDictionary(&self.output_scratch, input, options, dictionary) catch |err| {
            self.output_scratch.clearRetainingCapacity();
            return err;
        };
        return .{
            .frame = self.output_scratch.items,
            .mode = mode,
        };
    }

    pub fn encodeScratchWithDictionarySet(self: *NativeFrameEncoder, input: []const u8, options: NativeFrameOptions, dictionary_set: NativeDictionarySet, dictionary_id: u32) Error!NativeFrameEncodeScratchResult {
        const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
        return try self.encodeScratchWithDictionary(input, options, dictionary);
    }

    pub fn encodeIntoSlice(
        self: *NativeFrameEncoder,
        input: []const u8,
        options: NativeFrameOptions,
        output: []u8,
    ) Error!NativeFrameEncodeIntoResult {
        const result = try self.encodeScratch(input, options);
        if (output.len < result.frame.len) return error.OutputTooSmall;
        @memcpy(output[0..result.frame.len], result.frame);
        return .{
            .written = result.frame.len,
            .mode = result.mode,
        };
    }

    pub fn encodeIntoSliceWithDictionary(
        self: *NativeFrameEncoder,
        input: []const u8,
        options: NativeFrameOptions,
        dictionary: NativeDictionary,
        output: []u8,
    ) Error!NativeFrameEncodeIntoResult {
        const result = try self.encodeScratchWithDictionary(input, options, dictionary);
        if (output.len < result.frame.len) return error.OutputTooSmall;
        @memcpy(output[0..result.frame.len], result.frame);
        return .{
            .written = result.frame.len,
            .mode = result.mode,
        };
    }

    pub fn encodeIntoSliceWithDictionarySet(self: *NativeFrameEncoder, input: []const u8, options: NativeFrameOptions, dictionary_set: NativeDictionarySet, dictionary_id: u32, output: []u8) Error!NativeFrameEncodeIntoResult {
        const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
        return try self.encodeIntoSliceWithDictionary(input, options, dictionary, output);
    }

    pub fn encodeAppend(
        self: *NativeFrameEncoder,
        out: *std.ArrayList(u8),
        input: []const u8,
        options: NativeFrameOptions,
    ) Error!NativeFrameMode {
        return try self.encodeAppendInternal(out, input, options, null);
    }

    pub fn encodeAppendWithDictionary(
        self: *NativeFrameEncoder,
        out: *std.ArrayList(u8),
        input: []const u8,
        options: NativeFrameOptions,
        dictionary: NativeDictionary,
    ) Error!NativeFrameMode {
        return try self.encodeAppendInternal(out, input, options, dictionary);
    }

    pub fn encodeAppendWithDictionarySet(
        self: *NativeFrameEncoder,
        out: *std.ArrayList(u8),
        input: []const u8,
        options: NativeFrameOptions,
        dictionary_set: NativeDictionarySet,
        dictionary_id: u32,
    ) Error!NativeFrameMode {
        const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
        return try self.encodeAppendWithDictionary(out, input, options, dictionary);
    }

    fn encodeAppendInternal(
        self: *NativeFrameEncoder,
        out: *std.ArrayList(u8),
        input: []const u8,
        options: NativeFrameOptions,
        dictionary: ?NativeDictionary,
    ) Error!NativeFrameMode {
        if (dictionary) |dict| {
            if (dict.id == 0) return error.NeedDictionary;
        }
        const frame_options = optionsWithNativeDictionary(options, dictionary);
        switch (options.selection) {
            .raw_or_rle => {
                try encodeRawOrRleFrameAppend(self.allocator, out, input, frame_options);
                return .raw_or_rle;
            },
            .literal_only => {
                try encodeLiteralOnlyFrameAppendWithDictionaryInternal(self.allocator, out, input, frame_options, dictionary);
                return .literal_only;
            },
            .auto => {},
        }

        self.raw_scratch.clearRetainingCapacity();
        self.literal_scratch.clearRetainingCapacity();
        try encodeRawOrRleFrameAppend(self.allocator, &self.raw_scratch, input, frame_options);
        try encodeLiteralOnlyFrameAppendWithDictionaryInternal(self.allocator, &self.literal_scratch, input, frame_options, dictionary);

        // Keep the bootstrap selector deterministic and transparent: both
        // supported native encoders run against reusable scratch buffers, then
        // the shorter interoperable frame is appended to the caller's output.
        // This avoids the one-shot APIs allocating a complete winner frame only
        // to copy it again, while preserving the public mode report.
        if (self.literal_scratch.items.len < self.raw_scratch.items.len) {
            try out.appendSlice(self.allocator, self.literal_scratch.items);
            return .literal_only;
        }
        try out.appendSlice(self.allocator, self.raw_scratch.items);
        return .raw_or_rle;
    }
};

fn forceNativeSelection(options: NativeFrameOptions, selection: NativeFrameSelection) NativeFrameOptions {
    var forced = options;
    forced.selection = selection;
    return forced;
}

fn optionsWithNativeDictionary(options: NativeFrameOptions, dictionary: ?NativeDictionary) NativeFrameOptions {
    var with_dictionary = options;
    if (dictionary) |dict| with_dictionary.dictionary_id = dict.id;
    return with_dictionary;
}

fn emitFrameHeader(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    content_len: u64,
    options: NativeFrameOptions,
) Error!void {
    try out.appendSlice(allocator, &frame_magic);
    const checksum_flag: u8 = if (options.content_checksum) 0x04 else 0;
    const dictionary_flag: u8 = nativeDictionaryIdFlag(options.dictionary_id);

    if (!options.include_content_size) {
        try out.append(allocator, checksum_flag | dictionary_flag);
        try emitWindowDescriptor(allocator, out, content_len);
        try emitDictionaryId(allocator, out, options.dictionary_id);
        return;
    }

    // Use the shortest single-segment Frame_Content_Size encoding permitted by
    // the Zstandard format. The previous bootstrap writer always spent eight
    // bytes here, which was easy to inspect but disproportionately expensive
    // for the tiny raw/RLE frames this dependency-free path is meant to cover.
    if (content_len <= 255) {
        try out.append(allocator, 0x20 | checksum_flag | dictionary_flag); // fcs=1 byte, single segment
        try emitDictionaryId(allocator, out, options.dictionary_id);
        try out.append(allocator, @intCast(content_len));
    } else if (content_len <= 256 + std.math.maxInt(u16)) {
        try out.append(allocator, 0x60 | checksum_flag | dictionary_flag); // fcs=2 bytes (+256), single segment
        try emitDictionaryId(allocator, out, options.dictionary_id);
        var size_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &size_bytes, @intCast(content_len - 256), .little);
        try out.appendSlice(allocator, &size_bytes);
    } else if (content_len <= std.math.maxInt(u32)) {
        try out.append(allocator, 0xa0 | checksum_flag | dictionary_flag); // fcs=4 bytes, single segment
        try emitDictionaryId(allocator, out, options.dictionary_id);
        var size_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &size_bytes, @intCast(content_len), .little);
        try out.appendSlice(allocator, &size_bytes);
    } else {
        try out.append(allocator, 0xe0 | checksum_flag | dictionary_flag); // fcs=8 bytes, single segment
        try emitDictionaryId(allocator, out, options.dictionary_id);
        var size_bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &size_bytes, content_len, .little);
        try out.appendSlice(allocator, &size_bytes);
    }
}

fn emitWindowDescriptor(allocator: std.mem.Allocator, out: *std.ArrayList(u8), content_len: u64) Error!void {
    const window_size = @max(content_len, @as(u64, 1) << 10);
    var exponent: u8 = 0;
    while (exponent < 31) : (exponent += 1) {
        const base = @as(u64, 1) << @intCast(10 + exponent);
        const step = base / 8;
        if (window_size <= base + step * 7) {
            const delta = window_size - base;
            const mantissa: u8 = @intCast((delta + step - 1) / step);
            try out.append(allocator, (exponent << 3) | mantissa);
            return;
        }
    }
    return error.IntegerOverflow;
}

fn emitContentChecksum(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: NativeFrameOptions,
) Error!void {
    if (!options.content_checksum) return;
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, input)), .little);
    try out.appendSlice(allocator, &checksum);
}

pub const NativeFrameHeader = struct {
    content_size: ?u64,
    has_checksum: bool,
    window_size: u64,
    block_size_max: usize,
    dictionary_id: u32 = 0,
    payload_offset: usize,
};

pub const NativeBlockType = enum {
    raw,
    rle,
    compressed,
};

pub const NativeFrameBlockHeader = struct {
    header_offset: usize,
    payload_offset: usize,
    payload_len: usize,
    block_type: NativeBlockType,
    last: bool,
    next_header_offset: usize,
};

pub const NativeFrameBlockSummary = struct {
    block_count: usize = 0,
    raw_block_count: usize = 0,
    rle_block_count: usize = 0,
    compressed_block_count: usize = 0,
    payload_bytes: usize = 0,
};

pub const NativeLiteralsKind = enum {
    raw,
    rle,
    compressed,
    treeless,
};

pub const NativeSequenceModeSummary = struct {
    literals_kind: NativeLiteralsKind,
    regenerated_literals_size: usize,
    sequence_count: usize,
    literal_length_mode: NativeSequenceTableMode,
    offset_mode: NativeSequenceTableMode,
    match_length_mode: NativeSequenceTableMode,
};

pub const NativeSequenceTableMode = enum {
    predefined,
    rle,
    compressed,
    repeat,
};

pub const NativeSkippableFrameHeader = struct {
    skippable_id: u4,
    payload_offset: usize,
    payload_len: usize,
    next_frame_offset: usize,
};

pub const NativeStreamSummary = struct {
    frame_count: usize = 0,
    skippable_frame_count: usize = 0,
    block_count: usize = 0,
    raw_block_count: usize = 0,
    rle_block_count: usize = 0,
    compressed_block_count: usize = 0,
    payload_bytes: usize = 0,
    skippable_payload_bytes: usize = 0,
};

/// Zero-allocation cursor over a single native Zstandard frame's blocks.
/// Returned block offsets are relative to `frame`; once the last block is
/// consumed, `next_header_offset` points just past the optional content
/// checksum. Use `NativeStreamIterator` for concatenated streams with skippable
/// frames.
pub const NativeFrameBlockIterator = struct {
    frame: []const u8,
    header: NativeFrameHeader,
    next_header_offset: usize,
    finished: bool = false,

    pub fn init(frame: []const u8) Error!NativeFrameBlockIterator {
        const header = try inspectNativeFrameHeader(frame);
        return .{
            .frame = frame,
            .header = header,
            .next_header_offset = header.payload_offset,
        };
    }

    pub fn next(self: *NativeFrameBlockIterator) Error!?NativeFrameBlockHeader {
        if (self.finished) return null;
        const block = try inspectNativeFrameBlockAt(self.frame, self.next_header_offset);
        self.next_header_offset = block.next_header_offset;
        if (block.last) {
            if (self.header.has_checksum) {
                if (self.frame.len - self.next_header_offset < 4) return error.TruncatedFrame;
                self.next_header_offset += 4;
            }
            self.finished = true;
        }
        return block;
    }
};

/// One non-skippable frame discovered inside a concatenated native Zstandard
/// stream. Slices borrow from the stream passed to `iterateNativeStream`.
pub const NativeStreamFrame = struct {
    offset: usize,
    bytes: []const u8,
    header: NativeFrameHeader,

    pub fn blockIterator(self: NativeStreamFrame) Error!NativeFrameBlockIterator {
        return try NativeFrameBlockIterator.init(self.bytes);
    }
};

/// One skippable frame discovered inside a concatenated native Zstandard stream.
pub const NativeStreamSkippableFrame = struct {
    offset: usize,
    bytes: []const u8,
    payload: []const u8,
    header: NativeSkippableFrameHeader,
};

/// Stream iterator item; all slices borrow from the input passed to
/// `iterateNativeStream`.
pub const NativeStreamElement = union(enum) {
    frame: NativeStreamFrame,
    skippable: NativeStreamSkippableFrame,
};

/// Zero-allocation cursor over concatenated native Zstandard frames and
/// skippable metadata frames. It validates frame boundaries before yielding so
/// callers can inspect frame/block layout without decoded-output allocation.
pub const NativeStreamIterator = struct {
    frames: []const u8,
    next_offset: usize = 0,

    pub fn init(frames: []const u8) NativeStreamIterator {
        return .{ .frames = frames };
    }

    pub fn next(self: *NativeStreamIterator) Error!?NativeStreamElement {
        if (self.next_offset >= self.frames.len) return null;
        if (self.frames.len - self.next_offset < 4) return error.TruncatedFrame;

        const start = self.next_offset;
        const magic = std.mem.readInt(u32, self.frames[start..][0..4], .little);
        if (magic == frame_magic_u32) {
            const end = try findNativeFrameEnd(self.frames, start);
            const bytes = self.frames[start..end];
            const header = try inspectNativeFrameHeader(bytes);
            self.next_offset = end;
            return .{ .frame = .{
                .offset = start,
                .bytes = bytes,
                .header = header,
            } };
        } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            const header = try inspectNativeSkippableFrame(self.frames[start..]);
            const end = start + header.next_frame_offset;
            self.next_offset = end;
            return .{ .skippable = .{
                .offset = start,
                .bytes = self.frames[start..end],
                .payload = self.frames[start + header.payload_offset .. end],
                .header = header,
            } };
        } else {
            return error.InvalidMagic;
        }
    }
};

pub fn iterateNativeFrameBlocks(frame: []const u8) Error!NativeFrameBlockIterator {
    return try NativeFrameBlockIterator.init(frame);
}

pub fn iterateNativeStream(frames: []const u8) NativeStreamIterator {
    return NativeStreamIterator.init(frames);
}

const RawOrRleFrameHeader = NativeFrameHeader;

fn validateBlockSize(header: RawOrRleFrameHeader, block_type: u32, block_len: usize) Error!void {
    // For raw/RLE blocks the header size is the regenerated byte count and must
    // fit the frame block limit directly. For compressed blocks it is the
    // compressed payload length; the literal-only decoder validates the
    // regenerated size after parsing the literals section.
    if (block_type == 2) {
        if (block_len > std.compress.zstd.block_size_max) return error.CorruptFrame;
    } else if (block_len > header.block_size_max) {
        return error.CorruptFrame;
    }
}

fn validateNativeDictionary(header: NativeFrameHeader, dictionary: ?NativeDictionary) Error![]const u8 {
    if (header.dictionary_id == 0) return &.{};
    const dict = dictionary orelse return error.NeedDictionary;
    if (dict.id != header.dictionary_id) return error.NeedDictionary;
    // The native subset currently uses preset dictionaries as external history
    // for sequence matches. Raw/RLE/literals-only frames decode identically, but
    // this explicit validation path lets callers enforce Dictionary_ID policy
    // without hidden global state.
    return dict.content;
}

fn dictionaryForNativeFrame(frame: []const u8, dictionary_set: NativeDictionarySet) Error!?NativeDictionary {
    const header = try inspectNativeFrameHeader(frame);
    if (header.dictionary_id == 0) return null;
    return dictionary_set.find(header.dictionary_id) orelse error.NeedDictionary;
}

fn decodeRawOrRleZstandardFrameInto(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frame: []const u8,
    offset: *usize,
    dictionary: ?NativeDictionary,
) Error!void {
    const header = try parseRawOrRleFrameHeaderWithOptions(frame, offset, true);
    const dictionary_history = try validateNativeDictionary(header, dictionary);
    const frame_out_start = out.items.len;
    if (header.content_size) |size| try out.ensureUnusedCapacity(allocator, try checkedU64ToUsize(size));
    var frame_state: SequenceFrameState = .{};

    while (true) {
        if (frame.len - offset.* < 3) return error.TruncatedFrame;
        const block_header = std.mem.readInt(u24, frame[offset.*..][0..3], .little);
        offset.* += 3;
        const last = (block_header & 0x1) != 0;
        const block_type = (block_header >> 1) & 0x3;
        const block_len: usize = @intCast(block_header >> 3);
        try validateBlockSize(header, block_type, block_len);

        switch (block_type) {
            0 => {
                if (frame.len - offset.* < block_len) return error.TruncatedFrame;
                try out.appendSlice(allocator, frame[offset.*..][0..block_len]);
                offset.* += block_len;
            },
            1 => {
                if (block_len == 0) return error.CorruptFrame;
                if (frame.len - offset.* < 1) return error.TruncatedFrame;
                const byte = frame[offset.*];
                offset.* += 1;
                try out.appendNTimes(allocator, byte, block_len);
            },
            2 => {
                if (frame.len - offset.* < block_len) return error.TruncatedFrame;
                try decodeLiteralOnlyCompressedBlockInto(allocator, out, frame[offset.*..][0..block_len], header.block_size_max, frame_out_start, dictionary_history, &frame_state);
                offset.* += block_len;
            },
            else => return error.CorruptFrame,
        }

        if (last) break;
    }

    const decoded = out.items[frame_out_start..];
    if (header.content_size) |size| {
        if (try checkedUsizeToU64(decoded.len) != size) return error.SizeMismatch;
    }

    if (header.has_checksum) {
        if (frame.len - offset.* < 4) return error.TruncatedFrame;
        const expected = std.mem.readInt(u32, frame[offset.*..][0..4], .little);
        const actual: u32 = @truncate(std.hash.XxHash64.hash(0, decoded));
        if (actual != expected) return error.ChecksumMismatch;
        offset.* += 4;
    }
}

fn decodeRawOrRleZstandardFrameIntoBuffer(
    frame: []const u8,
    offset: *usize,
    output: []u8,
    written: *usize,
    dictionary: ?NativeDictionary,
) Error!void {
    const header = try parseRawOrRleFrameHeaderWithOptions(frame, offset, true);
    const dictionary_history = try validateNativeDictionary(header, dictionary);
    const frame_out_start = written.*;
    if (header.content_size) |size| {
        const needed = try checkedU64ToUsize(size);
        if (output.len - written.* < needed) return error.OutputTooSmall;
    }
    var frame_state: SequenceFrameState = .{};

    while (true) {
        if (frame.len - offset.* < 3) return error.TruncatedFrame;
        const block_header = std.mem.readInt(u24, frame[offset.*..][0..3], .little);
        offset.* += 3;
        const last = (block_header & 0x1) != 0;
        const block_type = (block_header >> 1) & 0x3;
        const block_len: usize = @intCast(block_header >> 3);
        try validateBlockSize(header, block_type, block_len);

        switch (block_type) {
            0 => {
                if (frame.len - offset.* < block_len) return error.TruncatedFrame;
                if (output.len - written.* < block_len) return error.OutputTooSmall;
                @memcpy(output[written.*..][0..block_len], frame[offset.*..][0..block_len]);
                written.* += block_len;
                offset.* += block_len;
            },
            1 => {
                if (block_len == 0) return error.CorruptFrame;
                if (frame.len - offset.* < 1) return error.TruncatedFrame;
                if (output.len - written.* < block_len) return error.OutputTooSmall;
                const byte = frame[offset.*];
                offset.* += 1;
                @memset(output[written.*..][0..block_len], byte);
                written.* += block_len;
            },
            2 => {
                if (frame.len - offset.* < block_len) return error.TruncatedFrame;
                try decodeLiteralOnlyCompressedBlockIntoBuffer(frame[offset.*..][0..block_len], output, written, header.block_size_max, frame_out_start, dictionary_history, &frame_state);
                offset.* += block_len;
            },
            else => return error.CorruptFrame,
        }

        if (last) break;
    }

    const decoded = output[frame_out_start..written.*];
    if (header.content_size) |size| {
        if (try checkedUsizeToU64(decoded.len) != size) return error.SizeMismatch;
    }

    if (header.has_checksum) {
        if (frame.len - offset.* < 4) return error.TruncatedFrame;
        const expected = std.mem.readInt(u32, frame[offset.*..][0..4], .little);
        const actual: u32 = @truncate(std.hash.XxHash64.hash(0, decoded));
        if (actual != expected) return error.ChecksumMismatch;
        offset.* += 4;
    }
}

fn decodeLiteralOnlyCompressedBlockInto(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    block_size_max: usize,
    frame_output_start: usize,
    dictionary_history: []const u8,
    frame_state: *SequenceFrameState,
) Error!void {
    const start = out.items.len;
    // Size preflight and decode both advance sequence-table and repeat-offset
    // state. Use a scratch copy for the preflight so the real state is advanced
    // exactly once by the decode path below.
    var preflight_state = frame_state.*;
    if (frame_output_start > out.items.len) return error.CorruptFrame;
    const frame_decoded_before_block = out.items.len - frame_output_start;
    const initial_history_len = std.math.add(usize, dictionary_history.len, frame_decoded_before_block) catch return error.IntegerOverflow;
    const decoded_len = try compressedLiteralOnlyBlockDecodedSize(block, block_size_max, initial_history_len, &preflight_state);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    var written = out.items.len;
    try decodeLiteralOnlyCompressedBlockIntoBuffer(block, out.items.ptr[0..out.capacity], &written, block_size_max, frame_output_start, dictionary_history, frame_state);
    out.items.len = written;
    if (out.items.len - start != decoded_len) return error.SizeMismatch;
}

fn decodeLiteralOnlyCompressedBlockIntoBuffer(
    block: []const u8,
    output: []u8,
    written: *usize,
    block_size_max: usize,
    frame_output_start: usize,
    dictionary_history: []const u8,
    frame_state: *SequenceFrameState,
) Error!void {
    const section = try parseLiteralsSection(block, frame_state);
    if (section.regenerated_size > block_size_max) return error.CorruptFrame;
    try validateSupportedLiteralSection(section);
    if (section.sequence_count != 0) return try decodeRleSequencesCompressedBlockIntoBuffer(block, section, output, written, frame_output_start, dictionary_history, frame_state);
    if (section.sequence_payload_offset != block.len) return error.UnsupportedZstdFeature;
    try copyLiteralsFromSection(block, section, 0, output, written, section.regenerated_size);
}

fn copyLiteralsFromSection(
    block: []const u8,
    section: LiteralOnlySection,
    literal_offset: usize,
    output: []u8,
    written: *usize,
    literal_len: usize,
) Error!void {
    if (literal_offset > section.regenerated_size or section.regenerated_size - literal_offset < literal_len) {
        return error.CorruptFrame;
    }
    if (literal_len == 0) {
        if ((section.kind == .compressed or section.kind == .treeless) and literal_offset == section.regenerated_size) {
            if (written.* > output.len) return error.OutputTooSmall;
            try copyHuffmanLiteralsFromSection(block, section, literal_offset, output[written.*..][0..0]);
        }
        return;
    }
    if (output.len - written.* < literal_len) return error.OutputTooSmall;
    switch (section.kind) {
        .raw => {
            @memcpy(
                output[written.*..][0..literal_len],
                block[section.literal_payload_offset + literal_offset ..][0..literal_len],
            );
        },
        .rle => {
            if (section.regenerated_size == 0) return error.CorruptFrame;
            @memset(output[written.*..][0..literal_len], block[section.literal_payload_offset]);
        },
        .compressed, .treeless => try copyHuffmanLiteralsFromSection(
            block,
            section,
            literal_offset,
            output[written.*..][0..literal_len],
        ),
    }
    written.* += literal_len;
}

fn copyHuffmanLiteralsFromSection(
    block: []const u8,
    section: LiteralOnlySection,
    literal_offset: usize,
    dest: []u8,
) Error!void {
    // Literal copies are requested in sequence order, but the current minimal
    // slice keeps no per-section cursor so preflight and decode can share the
    // same immutable `LiteralOnlySection`. Re-reading from the start is slower
    // for many small literal runs, yet it preserves exact behavior while this
    // native Zstd path is still correctness-first and sequence/FSE support is
    // incomplete.
    const huffman_tree = section.huffman_tree orelse return error.CorruptFrame;
    const end = std.math.add(usize, literal_offset, dest.len) catch return error.IntegerOverflow;
    var decoded_index: usize = 0;
    var output_index: usize = 0;
    var cursor = try initHuffmanLiteralCursor(block, section);
    while (decoded_index < end) {
        const symbol = try readHuffmanLiteralSymbolFromCursor(&cursor, huffman_tree);
        if (decoded_index >= literal_offset) dest[output_index] = symbol;
        if (decoded_index >= literal_offset) output_index += 1;
        decoded_index += 1;
    }
    if (end == section.regenerated_size) try cursor.expectEnd();
}

const HuffmanLiteralDecodeState = struct {
    cursor: HuffmanLiteralCursor,
    tree: StdZstdHuffmanTree,
    decoded: usize = 0,
};

fn initHuffmanLiteralDecodeState(block: []const u8, section: LiteralOnlySection) Error!?HuffmanLiteralDecodeState {
    if (section.kind != .compressed and section.kind != .treeless) return null;
    return .{
        .cursor = try initHuffmanLiteralCursor(block, section),
        .tree = section.huffman_tree orelse return error.CorruptFrame,
    };
}

fn copyLiteralsFromHuffmanState(
    state: *HuffmanLiteralDecodeState,
    section: LiteralOnlySection,
    literal_offset: usize,
    dest: []u8,
) Error!void {
    if (literal_offset != state.decoded) return error.CorruptFrame;
    if (literal_offset > section.regenerated_size or section.regenerated_size - literal_offset < dest.len) return error.CorruptFrame;
    for (dest) |*out| {
        out.* = try readHuffmanLiteralSymbolFromCursor(&state.cursor, state.tree);
        state.decoded += 1;
    }
    if (state.decoded == section.regenerated_size) try state.cursor.expectEnd();
}

fn validateHuffmanLiteralsConsumed(block: []const u8, section: LiteralOnlySection) Error!void {
    if (section.kind != .compressed and section.kind != .treeless) return;
    const huffman_tree = section.huffman_tree orelse return error.CorruptFrame;
    var cursor = try initHuffmanLiteralCursor(block, section);
    for (0..section.regenerated_size) |_| {
        _ = try readHuffmanLiteralSymbolFromCursor(&cursor, huffman_tree);
    }
    try cursor.expectEnd();
}

fn huffmanLiteralStreamReader(block: []const u8, section: LiteralOnlySection) Error!ReverseBitReader {
    const stream_end = std.math.add(usize, section.literal_payload_offset, section.compressed_size) catch return error.IntegerOverflow;
    if (section.huffman_stream_offset > stream_end or stream_end > block.len) return error.CorruptFrame;
    return try ReverseBitReader.init(block[section.huffman_stream_offset..stream_end]);
}

const HuffmanLiteralCursor = struct {
    streams: HuffmanLiteralStreams,
    stream_index: usize = 0,
    reader: ReverseBitReader,

    fn read(self: *HuffmanLiteralCursor, bit_count: u4) Error!usize {
        return self.reader.read(bit_count) catch |err| switch (err) {
            error.TruncatedFrame => {
                if (self.streams == .four and self.stream_index < 3) {
                    self.stream_index += 1;
                    self.reader = try ReverseBitReader.init(self.streams.four[self.stream_index]);
                    return self.reader.read(bit_count) catch |next_err| switch (next_err) {
                        error.TruncatedFrame => return error.CorruptFrame,
                        else => |e| return e,
                    };
                }
                return error.CorruptFrame;
            },
            else => |e| return e,
        };
    }

    fn expectEnd(self: *HuffmanLiteralCursor) Error!void {
        switch (self.streams) {
            .one => try self.reader.expectEnd(),
            .four => {
                if (self.stream_index != 3) return error.CorruptFrame;
                try self.reader.expectEnd();
            },
            .none => return error.CorruptFrame,
        }
    }
};

fn initHuffmanLiteralCursor(block: []const u8, section: LiteralOnlySection) Error!HuffmanLiteralCursor {
    switch (section.huffman_streams) {
        .one => return .{
            .streams = .one,
            .reader = try huffmanLiteralStreamReader(block, section),
        },
        .four => |streams| return .{
            .streams = .{ .four = streams },
            .reader = try ReverseBitReader.init(streams[0]),
        },
        .none => return error.CorruptFrame,
    }
}

fn readHuffmanLiteralSymbolFromCursor(cursor: *HuffmanLiteralCursor, huffman_tree: StdZstdHuffmanTree) Error!u8 {
    const max_bit_count = huffman_tree.max_bit_count;
    const starting_bit_count = StdZstdHuffmanTree.weightToBitCount(
        huffman_tree.nodes[huffman_tree.symbol_count_minus_one].weight,
        max_bit_count,
    );
    var bits_read: u4 = 0;
    var huffman_tree_index: usize = huffman_tree.symbol_count_minus_one;
    var bit_count_to_read = starting_bit_count;
    var prefix: u16 = 0;
    while (true) {
        const new_bits = try cursor.read(bit_count_to_read);
        prefix <<= bit_count_to_read;
        prefix |= @intCast(new_bits);
        bits_read += bit_count_to_read;
        const result = huffman_tree.query(huffman_tree_index, prefix) catch return error.CorruptFrame;

        switch (result) {
            .symbol => |symbol| return symbol,
            .index => |index| {
                huffman_tree_index = index;
                const bit_count = StdZstdHuffmanTree.weightToBitCount(
                    huffman_tree.nodes[index].weight,
                    max_bit_count,
                );
                if (bit_count <= bits_read) return error.CorruptFrame;
                bit_count_to_read = bit_count - bits_read;
            },
        }
    }
}

fn compressedLiteralOnlyBlockDecodedSize(
    block: []const u8,
    block_size_max: usize,
    initial_output_len: usize,
    frame_state: *SequenceFrameState,
) Error!usize {
    const section = try parseLiteralsSection(block, frame_state);
    if (section.regenerated_size > block_size_max) return error.CorruptFrame;
    try validateSupportedLiteralSection(section);
    if (section.sequence_count == 0) {
        if (section.sequence_payload_offset != block.len) return error.UnsupportedZstdFeature;
        try validateHuffmanLiteralsConsumed(block, section);
        return section.regenerated_size;
    }
    return try rleSequencesCompressedBlockDecodedSize(block, section, initial_output_len, frame_state);
}

fn validateSupportedLiteralSection(section: LiteralOnlySection) Error!void {
    switch (section.kind) {
        .raw, .rle => {},
        .compressed => {
            if (section.huffman_tree == null) return error.CorruptFrame;
            if (section.huffman_streams == .none) return error.CorruptFrame;
        },
        .treeless => {
            if (section.huffman_tree == null) return error.CorruptFrame;
            if (section.huffman_streams == .none) return error.CorruptFrame;
        },
    }
}

fn compressedLiteralOnlyBlockDecodedSizeLimited(
    block: []const u8,
    total: usize,
    frame_start: usize,
    max_output_len: usize,
    block_size_max: usize,
    frame_state: *SequenceFrameState,
) Error!usize {
    if (frame_start > total) return error.CorruptFrame;
    const decoded_len = try compressedLiteralOnlyBlockDecodedSize(block, block_size_max, total - frame_start, frame_state);
    return checkedAddWithinLimit(total, decoded_len, max_output_len);
}

const LiteralsKind = enum { raw, rle, compressed, treeless };

const LiteralOnlySection = struct {
    kind: LiteralsKind,
    size_format: u2,
    regenerated_size: usize,
    literal_payload_offset: usize,
    huffman_stream_offset: usize,
    huffman_streams: HuffmanLiteralStreams,
    compressed_size: usize = 0,
    sequence_count: usize,
    sequence_payload_offset: usize,
    huffman_tree: ?StdZstdHuffmanTree = null,
};

const HuffmanLiteralStreams = union(enum) {
    none,
    one,
    four: [4][]const u8,
};

fn parseLiteralsSection(block: []const u8, frame_state: *SequenceFrameState) Error!LiteralOnlySection {
    var offset: usize = 0;
    const literal_header = try parseLiteralsHeader(block, &offset);
    const literal_payload_offset = offset;
    const literal_payload_len: usize = switch (literal_header.kind) {
        .raw => literal_header.regenerated_size,
        .rle => 1,
        .compressed, .treeless => literal_header.compressed_size,
    };
    if (block.len - offset < literal_payload_len) return error.TruncatedFrame;
    offset += literal_payload_len;
    if (literal_header.kind == .treeless and frame_state.previous_huffman_tree == null) {
        return error.CorruptFrame;
    }
    var huffman_tree: ?StdZstdHuffmanTree = null;
    var huffman_stream_offset = literal_payload_offset;
    var huffman_streams: HuffmanLiteralStreams = .none;
    switch (literal_header.kind) {
        .compressed => {
            const payload = block[literal_payload_offset..][0..literal_payload_len];
            var reader: std.Io.Reader = .fixed(payload);
            var remaining: std.Io.Limit = .limited(payload.len);
            // Zig std's Zstandard Huffman table builder is public and tracks the
            // same canonical tree invariants we need here. Keep the local code
            // focused on frame integration and bitstream traversal instead of
            // carrying a forked copy of the FSE/direct tree parser.
            huffman_tree = decodeStdZstdHuffmanTree(&reader, &remaining) catch |err| switch (err) {
                error.EndOfStream => return error.TruncatedFrame,
                else => return error.CorruptFrame,
            };
            huffman_stream_offset += reader.seek;
            frame_state.previous_huffman_tree = huffman_tree;
            huffman_streams = try parseHuffmanLiteralStreams(block, literal_header.size_format, literal_payload_offset, huffman_stream_offset, literal_header.compressed_size);
        },
        .treeless => {
            huffman_tree = frame_state.previous_huffman_tree.?;
            huffman_streams = try parseHuffmanLiteralStreams(block, literal_header.size_format, literal_payload_offset, huffman_stream_offset, literal_header.compressed_size);
        },
        .raw, .rle => {},
    }
    const sequence_count = try parseSequenceCount(block, &offset);
    return .{
        .kind = literal_header.kind,
        .size_format = literal_header.size_format,
        .regenerated_size = literal_header.regenerated_size,
        .literal_payload_offset = literal_payload_offset,
        .huffman_stream_offset = huffman_stream_offset,
        .huffman_streams = huffman_streams,
        .compressed_size = literal_header.compressed_size,
        .sequence_count = sequence_count,
        .sequence_payload_offset = offset,
        .huffman_tree = huffman_tree,
    };
}

fn parseHuffmanLiteralStreams(
    block: []const u8,
    size_format: u2,
    literal_payload_offset: usize,
    huffman_stream_offset: usize,
    compressed_size: usize,
) Error!HuffmanLiteralStreams {
    const stream_data_end = std.math.add(usize, literal_payload_offset, compressed_size) catch return error.IntegerOverflow;
    if (huffman_stream_offset > stream_data_end or stream_data_end > block.len) return error.CorruptFrame;
    const stream_data = block[huffman_stream_offset..stream_data_end];
    if (size_format == 0) return .one;
    if (stream_data.len < 6) return error.CorruptFrame;
    const stream_1_length: usize = std.mem.readInt(u16, stream_data[0..2], .little);
    const stream_2_length: usize = std.mem.readInt(u16, stream_data[2..4], .little);
    const stream_3_length: usize = std.mem.readInt(u16, stream_data[4..6], .little);
    const stream_1_start: usize = 6;
    const stream_2_start = std.math.add(usize, stream_1_start, stream_1_length) catch return error.IntegerOverflow;
    const stream_3_start = std.math.add(usize, stream_2_start, stream_2_length) catch return error.IntegerOverflow;
    const stream_4_start = std.math.add(usize, stream_3_start, stream_3_length) catch return error.IntegerOverflow;
    if (stream_4_start > stream_data.len) return error.CorruptFrame;
    return .{ .four = .{
        stream_data[stream_1_start..stream_2_start],
        stream_data[stream_2_start..stream_3_start],
        stream_data[stream_3_start..stream_4_start],
        stream_data[stream_4_start..],
    } };
}

const LiteralsHeaderInfo = struct {
    kind: LiteralsKind,
    size_format: u2,
    regenerated_size: usize,
    compressed_size: usize = 0,
};

fn parseLiteralsHeader(block: []const u8, offset: *usize) Error!LiteralsHeaderInfo {
    if (offset.* >= block.len) return error.TruncatedFrame;
    const byte0 = block[offset.*];
    offset.* += 1;
    const block_type = byte0 & 0x03;
    const size_format: u2 = @intCast((byte0 >> 2) & 0x03);
    const kind: LiteralsKind = switch (block_type) {
        0 => .raw,
        1 => .rle,
        2 => .compressed,
        else => .treeless,
    };

    if (kind == .compressed or kind == .treeless) {
        return try parseHuffmanLiteralsHeader(block, offset, byte0, size_format, kind);
    }

    const regenerated_size: usize = switch (size_format) {
        0, 2 => byte0 >> 3,
        1 => blk: {
            if (block.len - offset.* < 1) return error.TruncatedFrame;
            const byte1 = block[offset.*];
            offset.* += 1;
            break :blk @as(usize, byte0 >> 4) + (@as(usize, byte1) << 4);
        },
        else => blk: {
            if (block.len - offset.* < 2) return error.TruncatedFrame;
            const byte1 = block[offset.*];
            const byte2 = block[offset.* + 1];
            offset.* += 2;
            break :blk @as(usize, byte0 >> 4) + (@as(usize, byte1) << 4) + (@as(usize, byte2) << 12);
        },
    };
    return .{ .kind = kind, .size_format = size_format, .regenerated_size = regenerated_size };
}

fn parseHuffmanLiteralsHeader(
    block: []const u8,
    offset: *usize,
    byte0: u8,
    size_format: u2,
    kind: LiteralsKind,
) Error!LiteralsHeaderInfo {
    return switch (size_format) {
        0, 1 => blk: {
            if (block.len - offset.* < 2) return error.TruncatedFrame;
            const byte1 = block[offset.*];
            const byte2 = block[offset.* + 1];
            offset.* += 2;
            const value = @as(usize, byte0 >> 4) |
                (@as(usize, byte1) << 4) |
                (@as(usize, byte2) << 12);
            const regenerated_size = value & 0x3ff;
            const compressed_size = (value >> 10) & 0x3ff;
            if (compressed_size == 0) return error.CorruptFrame;
            if (size_format == 1 and compressed_size < 10) return error.CorruptFrame;
            break :blk .{ .kind = kind, .size_format = size_format, .regenerated_size = regenerated_size, .compressed_size = compressed_size };
        },
        2 => blk: {
            if (block.len - offset.* < 3) return error.TruncatedFrame;
            const byte1 = block[offset.*];
            const byte2 = block[offset.* + 1];
            const byte3 = block[offset.* + 2];
            offset.* += 3;
            const value = @as(usize, byte0 >> 4) |
                (@as(usize, byte1) << 4) |
                (@as(usize, byte2) << 12) |
                (@as(usize, byte3) << 20);
            const regenerated_size = value & 0x3fff;
            const compressed_size = (value >> 14) & 0x3fff;
            if (compressed_size < 10) return error.CorruptFrame;
            break :blk .{ .kind = kind, .size_format = size_format, .regenerated_size = regenerated_size, .compressed_size = compressed_size };
        },
        else => blk: {
            if (block.len - offset.* < 4) return error.TruncatedFrame;
            const byte1 = block[offset.*];
            const byte2 = block[offset.* + 1];
            const byte3 = block[offset.* + 2];
            const byte4 = block[offset.* + 3];
            offset.* += 4;
            const value = @as(usize, byte0 >> 4) |
                (@as(usize, byte1) << 4) |
                (@as(usize, byte2) << 12) |
                (@as(usize, byte3) << 20) |
                (@as(usize, byte4) << 28);
            const regenerated_size = value & 0x3ffff;
            const compressed_size = (value >> 18) & 0x3ffff;
            if (compressed_size < 10) return error.CorruptFrame;
            break :blk .{ .kind = kind, .size_format = size_format, .regenerated_size = regenerated_size, .compressed_size = compressed_size };
        },
    };
}

fn decodeStdZstdHuffmanTree(
    reader: *std.Io.Reader,
    remaining: *std.Io.Limit,
) StdZstdHuffmanTree.DecodeError!StdZstdHuffmanTree {
    return try StdZstdHuffmanTree.decode(reader, remaining);
}

fn parseSequenceCount(block: []const u8, offset: *usize) Error!usize {
    if (offset.* >= block.len) return error.TruncatedFrame;
    const byte0 = block[offset.*];
    offset.* += 1;
    if (byte0 == 0) return 0;
    if (byte0 < 128) {
        return byte0;
    }
    if (byte0 < 255) {
        if (block.len - offset.* < 1) return error.TruncatedFrame;
        const count = (@as(usize, byte0 - 128) << 8) + block[offset.*];
        offset.* += 1;
        return count;
    }
    if (block.len - offset.* < 2) return error.TruncatedFrame;
    const count = @as(usize, block[offset.*]) + (@as(usize, block[offset.* + 1]) << 8) + 0x7f00;
    offset.* += 2;
    return count;
}

const SymbolMode = enum(u2) {
    predefined = 0,
    rle = 1,
    compressed = 2,
    repeat = 3,
};

const SequenceModeSpec = struct {
    ll_mode: SymbolMode,
    of_mode: SymbolMode,
    ml_mode: SymbolMode,
    literal_rle: ?SequenceSymbol,
    offset_rle: ?SequenceSymbol,
    match_rle: ?SequenceSymbol,
    literal_fse: SequenceFseTable = .{},
    offset_fse: SequenceFseTable = .{},
    match_fse: SequenceFseTable = .{},
    bitstream_offset: usize,

    fn tables(self: SequenceModeSpec) SequenceTables {
        return .{
            .ll_mode = self.ll_mode,
            .of_mode = self.of_mode,
            .ml_mode = self.ml_mode,
            .literal_rle = self.literal_rle,
            .offset_rle = self.offset_rle,
            .match_rle = self.match_rle,
            .literal_fse = self.literal_fse,
            .offset_fse = self.offset_fse,
            .match_fse = self.match_fse,
        };
    }
};

const SequenceSymbol = struct {
    base: usize,
    additional_bits: u8,
    next_state: usize,
    state_bits: u8,
};

const max_sequence_fse_table_size = 1 << 9;

const SequenceFseTable = struct {
    entries: [max_sequence_fse_table_size]SequenceSymbol = undefined,
    len: usize = 0,
    accuracy_log: u8 = 0,

    fn symbol(self: SequenceFseTable, state: usize) Error!SequenceSymbol {
        if (state >= self.len) return error.CorruptFrame;
        return self.entries[state];
    }
};

const sequence_table_accuracy_log_max = struct {
    const literal: u4 = 9;
    const match: u4 = 9;
    const offset: u4 = 8;
};

const sequence_table_symbol_count_max = struct {
    const literal = 36;
    const match = 53;
    const offset = 32;
};

const SequenceTables = struct {
    ll_mode: SymbolMode,
    of_mode: SymbolMode,
    ml_mode: SymbolMode,
    literal_rle: ?SequenceSymbol,
    offset_rle: ?SequenceSymbol,
    match_rle: ?SequenceSymbol,
    literal_fse: SequenceFseTable = .{},
    offset_fse: SequenceFseTable = .{},
    match_fse: SequenceFseTable = .{},
};

const SequenceFrameState = struct {
    // Zstandard repeats sequence tables, recent offsets, and Huffman literal
    // trees across compressed blocks in a frame. Raw/RLE blocks are
    // intentionally skipped. Keeping this small state object explicit makes the
    // native fallback decoder closer to the spec without hiding unsupported FSE
    // tables.
    previous_tables: ?SequenceTables = null,
    repeated_offsets: [3]usize = initial_repeated_offsets,
    previous_huffman_tree: ?StdZstdHuffmanTree = null,
};

const ResolvedSymbolTable = struct {
    mode: SymbolMode,
    rle: ?SequenceSymbol,
    fse: SequenceFseTable = .{},
};

const default_ll_symbols = [_]SequenceSymbol{
    .{ .base = 0, .additional_bits = 0, .next_state = 0, .state_bits = 4 },
    .{ .base = 0, .additional_bits = 0, .next_state = 16, .state_bits = 4 },
    .{ .base = 1, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 3, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 4, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 6, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 7, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 9, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 10, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 12, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 14, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 16, .additional_bits = 1, .next_state = 0, .state_bits = 5 },
    .{ .base = 20, .additional_bits = 1, .next_state = 0, .state_bits = 5 },
    .{ .base = 22, .additional_bits = 1, .next_state = 0, .state_bits = 5 },
    .{ .base = 28, .additional_bits = 2, .next_state = 0, .state_bits = 5 },
    .{ .base = 32, .additional_bits = 3, .next_state = 0, .state_bits = 5 },
    .{ .base = 48, .additional_bits = 4, .next_state = 0, .state_bits = 5 },
    .{ .base = 64, .additional_bits = 6, .next_state = 32, .state_bits = 5 },
    .{ .base = 128, .additional_bits = 7, .next_state = 0, .state_bits = 5 },
    .{ .base = 256, .additional_bits = 8, .next_state = 0, .state_bits = 6 },
    .{ .base = 1024, .additional_bits = 10, .next_state = 0, .state_bits = 6 },
    .{ .base = 4096, .additional_bits = 12, .next_state = 0, .state_bits = 6 },
    .{ .base = 0, .additional_bits = 0, .next_state = 32, .state_bits = 4 },
    .{ .base = 1, .additional_bits = 0, .next_state = 0, .state_bits = 4 },
    .{ .base = 2, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 4, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 5, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 7, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 8, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 10, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 11, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 13, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 16, .additional_bits = 1, .next_state = 32, .state_bits = 5 },
    .{ .base = 18, .additional_bits = 1, .next_state = 0, .state_bits = 5 },
    .{ .base = 22, .additional_bits = 1, .next_state = 32, .state_bits = 5 },
    .{ .base = 24, .additional_bits = 2, .next_state = 0, .state_bits = 5 },
    .{ .base = 32, .additional_bits = 3, .next_state = 32, .state_bits = 5 },
    .{ .base = 40, .additional_bits = 3, .next_state = 0, .state_bits = 5 },
    .{ .base = 64, .additional_bits = 6, .next_state = 0, .state_bits = 4 },
    .{ .base = 64, .additional_bits = 6, .next_state = 16, .state_bits = 4 },
    .{ .base = 128, .additional_bits = 7, .next_state = 32, .state_bits = 5 },
    .{ .base = 512, .additional_bits = 9, .next_state = 0, .state_bits = 6 },
    .{ .base = 2048, .additional_bits = 11, .next_state = 0, .state_bits = 6 },
    .{ .base = 0, .additional_bits = 0, .next_state = 48, .state_bits = 4 },
    .{ .base = 1, .additional_bits = 0, .next_state = 16, .state_bits = 4 },
    .{ .base = 2, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 3, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 5, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 6, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 8, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 9, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 11, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 12, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 15, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 18, .additional_bits = 1, .next_state = 32, .state_bits = 5 },
    .{ .base = 20, .additional_bits = 1, .next_state = 32, .state_bits = 5 },
    .{ .base = 24, .additional_bits = 2, .next_state = 32, .state_bits = 5 },
    .{ .base = 28, .additional_bits = 2, .next_state = 32, .state_bits = 5 },
    .{ .base = 40, .additional_bits = 3, .next_state = 32, .state_bits = 5 },
    .{ .base = 48, .additional_bits = 4, .next_state = 32, .state_bits = 5 },
    .{ .base = 65536, .additional_bits = 16, .next_state = 0, .state_bits = 6 },
    .{ .base = 32768, .additional_bits = 15, .next_state = 0, .state_bits = 6 },
    .{ .base = 16384, .additional_bits = 14, .next_state = 0, .state_bits = 6 },
    .{ .base = 8192, .additional_bits = 13, .next_state = 0, .state_bits = 6 },
};

const default_of_symbols = [_]SequenceSymbol{
    .{ .base = 0, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 61, .additional_bits = 6, .next_state = 0, .state_bits = 4 },
    .{ .base = 509, .additional_bits = 9, .next_state = 0, .state_bits = 5 },
    .{ .base = 32765, .additional_bits = 15, .next_state = 0, .state_bits = 5 },
    .{ .base = 2097149, .additional_bits = 21, .next_state = 0, .state_bits = 5 },
    .{ .base = 5, .additional_bits = 3, .next_state = 0, .state_bits = 5 },
    .{ .base = 125, .additional_bits = 7, .next_state = 0, .state_bits = 4 },
    .{ .base = 4093, .additional_bits = 12, .next_state = 0, .state_bits = 5 },
    .{ .base = 262141, .additional_bits = 18, .next_state = 0, .state_bits = 5 },
    .{ .base = 8388605, .additional_bits = 23, .next_state = 0, .state_bits = 5 },
    .{ .base = 29, .additional_bits = 5, .next_state = 0, .state_bits = 5 },
    .{ .base = 253, .additional_bits = 8, .next_state = 0, .state_bits = 4 },
    .{ .base = 16381, .additional_bits = 14, .next_state = 0, .state_bits = 5 },
    .{ .base = 1048573, .additional_bits = 20, .next_state = 0, .state_bits = 5 },
    .{ .base = 1, .additional_bits = 2, .next_state = 0, .state_bits = 5 },
    .{ .base = 125, .additional_bits = 7, .next_state = 16, .state_bits = 4 },
    .{ .base = 2045, .additional_bits = 11, .next_state = 0, .state_bits = 5 },
    .{ .base = 131069, .additional_bits = 17, .next_state = 0, .state_bits = 5 },
    .{ .base = 4194301, .additional_bits = 22, .next_state = 0, .state_bits = 5 },
    .{ .base = 13, .additional_bits = 4, .next_state = 0, .state_bits = 5 },
    .{ .base = 253, .additional_bits = 8, .next_state = 16, .state_bits = 4 },
    .{ .base = 8189, .additional_bits = 13, .next_state = 0, .state_bits = 5 },
    .{ .base = 524285, .additional_bits = 19, .next_state = 0, .state_bits = 5 },
    .{ .base = 1, .additional_bits = 1, .next_state = 0, .state_bits = 5 },
    .{ .base = 61, .additional_bits = 6, .next_state = 16, .state_bits = 4 },
    .{ .base = 1021, .additional_bits = 10, .next_state = 0, .state_bits = 5 },
    .{ .base = 65533, .additional_bits = 16, .next_state = 0, .state_bits = 5 },
    .{ .base = 268435453, .additional_bits = 28, .next_state = 0, .state_bits = 5 },
    .{ .base = 134217725, .additional_bits = 27, .next_state = 0, .state_bits = 5 },
    .{ .base = 67108861, .additional_bits = 26, .next_state = 0, .state_bits = 5 },
    .{ .base = 33554429, .additional_bits = 25, .next_state = 0, .state_bits = 5 },
    .{ .base = 16777213, .additional_bits = 24, .next_state = 0, .state_bits = 5 },
};

const default_ml_symbols = [_]SequenceSymbol{
    .{ .base = 3, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 4, .additional_bits = 0, .next_state = 0, .state_bits = 4 },
    .{ .base = 5, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 6, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 8, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 9, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 11, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 13, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 16, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 19, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 22, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 25, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 28, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 31, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 34, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 37, .additional_bits = 1, .next_state = 0, .state_bits = 6 },
    .{ .base = 41, .additional_bits = 1, .next_state = 0, .state_bits = 6 },
    .{ .base = 47, .additional_bits = 2, .next_state = 0, .state_bits = 6 },
    .{ .base = 59, .additional_bits = 3, .next_state = 0, .state_bits = 6 },
    .{ .base = 83, .additional_bits = 4, .next_state = 0, .state_bits = 6 },
    .{ .base = 131, .additional_bits = 7, .next_state = 0, .state_bits = 6 },
    .{ .base = 515, .additional_bits = 9, .next_state = 0, .state_bits = 6 },
    .{ .base = 4, .additional_bits = 0, .next_state = 16, .state_bits = 4 },
    .{ .base = 5, .additional_bits = 0, .next_state = 0, .state_bits = 4 },
    .{ .base = 6, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 7, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 9, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 10, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 12, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 15, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 18, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 21, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 24, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 27, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 30, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 33, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 35, .additional_bits = 1, .next_state = 0, .state_bits = 6 },
    .{ .base = 39, .additional_bits = 1, .next_state = 0, .state_bits = 6 },
    .{ .base = 43, .additional_bits = 2, .next_state = 0, .state_bits = 6 },
    .{ .base = 51, .additional_bits = 3, .next_state = 0, .state_bits = 6 },
    .{ .base = 67, .additional_bits = 4, .next_state = 0, .state_bits = 6 },
    .{ .base = 99, .additional_bits = 5, .next_state = 0, .state_bits = 6 },
    .{ .base = 259, .additional_bits = 8, .next_state = 0, .state_bits = 6 },
    .{ .base = 4, .additional_bits = 0, .next_state = 32, .state_bits = 4 },
    .{ .base = 4, .additional_bits = 0, .next_state = 48, .state_bits = 4 },
    .{ .base = 5, .additional_bits = 0, .next_state = 16, .state_bits = 4 },
    .{ .base = 7, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 8, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 10, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 11, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 14, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 17, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 20, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 23, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 26, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 29, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 32, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 65539, .additional_bits = 16, .next_state = 0, .state_bits = 6 },
    .{ .base = 32771, .additional_bits = 15, .next_state = 0, .state_bits = 6 },
    .{ .base = 16387, .additional_bits = 14, .next_state = 0, .state_bits = 6 },
    .{ .base = 8195, .additional_bits = 13, .next_state = 0, .state_bits = 6 },
    .{ .base = 4099, .additional_bits = 12, .next_state = 0, .state_bits = 6 },
    .{ .base = 2051, .additional_bits = 11, .next_state = 0, .state_bits = 6 },
    .{ .base = 1027, .additional_bits = 10, .next_state = 0, .state_bits = 6 },
};

fn parseSequenceModeSpec(block: []const u8, offset: *usize, sequence_count: usize) Error!SequenceModeSpec {
    if (sequence_count == 0) return error.CorruptFrame;
    if (block.len - offset.* < 1) return error.TruncatedFrame;
    const mode = block[offset.*];
    offset.* += 1;
    if ((mode & 0x03) != 0) return error.CorruptFrame;
    const ll_mode: SymbolMode = @enumFromInt(mode >> 6);
    const of_mode: SymbolMode = @enumFromInt((mode >> 4) & 0x03);
    const ml_mode: SymbolMode = @enumFromInt((mode >> 2) & 0x03);

    var literal_rle: ?SequenceSymbol = null;
    var offset_rle: ?SequenceSymbol = null;
    var match_rle: ?SequenceSymbol = null;
    var literal_fse: SequenceFseTable = .{};
    var offset_fse: SequenceFseTable = .{};
    var match_fse: SequenceFseTable = .{};

    // Sequence table payloads are serialized in LL, OF, ML order. Each table's
    // mode decides whether the next bytes are a one-byte RLE symbol or a full
    // FSE table. Reading all RLE bytes before all FSE tables corrupts mixed
    // mode blocks such as LL=FSE, OF=FSE, ML=RLE.
    switch (ll_mode) {
        .rle => literal_rle = try readRleSymbolCode(block, offset, &ll_base, &ll_bits),
        .compressed => literal_fse = try readFseSequenceTable(block, offset, &ll_base, &ll_bits, sequence_table_symbol_count_max.literal, sequence_table_accuracy_log_max.literal),
        .predefined, .repeat => {},
    }
    switch (of_mode) {
        .rle => offset_rle = try readRleSymbolCode(block, offset, &of_base, &of_bits),
        .compressed => offset_fse = try readFseSequenceTable(block, offset, &of_base, &of_bits, sequence_table_symbol_count_max.offset, sequence_table_accuracy_log_max.offset),
        .predefined, .repeat => {},
    }
    switch (ml_mode) {
        .rle => match_rle = try readRleSymbolCode(block, offset, &ml_base, &ml_bits),
        .compressed => match_fse = try readFseSequenceTable(block, offset, &ml_base, &ml_bits, sequence_table_symbol_count_max.match, sequence_table_accuracy_log_max.match),
        .predefined, .repeat => {},
    }

    const bitstream_offset = offset.*;
    if (bitstream_offset >= block.len) return error.TruncatedFrame;
    offset.* = block.len;
    return .{
        .ll_mode = ll_mode,
        .of_mode = of_mode,
        .ml_mode = ml_mode,
        .literal_rle = literal_rle,
        .offset_rle = offset_rle,
        .match_rle = match_rle,
        .literal_fse = literal_fse,
        .offset_fse = offset_fse,
        .match_fse = match_fse,
        .bitstream_offset = bitstream_offset,
    };
}

fn resolveSymbolTable(
    mode: SymbolMode,
    rle: ?SequenceSymbol,
    fse: SequenceFseTable,
    previous: ?SequenceTables,
    selector: enum { ll, of, ml },
) Error!ResolvedSymbolTable {
    return switch (mode) {
        .repeat => blk: {
            const tables = previous orelse return error.CorruptFrame;
            break :blk switch (selector) {
                .ll => .{ .mode = tables.ll_mode, .rle = tables.literal_rle, .fse = tables.literal_fse },
                .of => .{ .mode = tables.of_mode, .rle = tables.offset_rle, .fse = tables.offset_fse },
                .ml => .{ .mode = tables.ml_mode, .rle = tables.match_rle, .fse = tables.match_fse },
            };
        },
        else => .{ .mode = mode, .rle = rle, .fse = fse },
    };
}

fn resolveSequenceModeSpec(spec: SequenceModeSpec, previous: ?SequenceTables) Error!SequenceModeSpec {
    const ll = try resolveSymbolTable(spec.ll_mode, spec.literal_rle, spec.literal_fse, previous, .ll);
    const of = try resolveSymbolTable(spec.of_mode, spec.offset_rle, spec.offset_fse, previous, .of);
    const ml = try resolveSymbolTable(spec.ml_mode, spec.match_rle, spec.match_fse, previous, .ml);
    return .{
        .ll_mode = ll.mode,
        .of_mode = of.mode,
        .ml_mode = ml.mode,
        .literal_rle = ll.rle,
        .offset_rle = of.rle,
        .match_rle = ml.rle,
        .literal_fse = ll.fse,
        .offset_fse = of.fse,
        .match_fse = ml.fse,
        .bitstream_offset = spec.bitstream_offset,
    };
}

fn readRleSymbolCode(block: []const u8, offset: *usize, bases: []const usize, bits: []const u8) Error!SequenceSymbol {
    if (offset.* >= block.len) return error.TruncatedFrame;
    const code = block[offset.*];
    offset.* += 1;
    if (code >= bases.len) return error.CorruptFrame;
    return .{ .base = bases[code], .additional_bits = bits[code], .next_state = 0, .state_bits = 0 };
}

fn readFseSequenceTable(
    block: []const u8,
    offset: *usize,
    bases: []const usize,
    bits: []const u8,
    expected_symbol_count: usize,
    max_accuracy_log: u4,
) Error!SequenceFseTable {
    if (offset.* >= block.len) return error.TruncatedFrame;
    var reader: ForwardBitReader = .{ .bytes = block[offset.*..] };
    var raw_entries: [max_sequence_fse_table_size]FseTableEntry = undefined;
    const table_len = try decodeFseTable(&reader, expected_symbol_count, max_accuracy_log, &raw_entries);
    offset.* = std.math.add(usize, offset.*, reader.byteIndex()) catch return error.IntegerOverflow;
    if (offset.* > block.len) return error.TruncatedFrame;

    var table: SequenceFseTable = .{
        .len = table_len,
        .accuracy_log = @intCast(std.math.log2_int(usize, table_len)),
    };
    for (raw_entries[0..table_len], 0..) |entry, i| {
        const code = entry.symbol;
        if (code >= bases.len or code >= bits.len) return error.CorruptFrame;
        table.entries[i] = .{
            .base = bases[code],
            .additional_bits = bits[code],
            .next_state = entry.baseline,
            .state_bits = entry.bits,
        };
    }
    return table;
}

const FseTableEntry = struct {
    symbol: u8,
    baseline: usize,
    bits: u8,
};

fn decodeFseTable(
    reader: *ForwardBitReader,
    expected_symbol_count: usize,
    max_accuracy_log: u4,
    entries: *[max_sequence_fse_table_size]FseTableEntry,
) Error!usize {
    const accuracy_log_biased = try reader.readBits(u4, 4);
    if (accuracy_log_biased > max_accuracy_log -| 5) return error.CorruptFrame;
    const accuracy_log = accuracy_log_biased + 5;

    var values: [256]u16 = undefined;
    var value_count: usize = 0;

    const total_probability = @as(u16, 1) << accuracy_log;
    var accumulated_probability: u16 = 0;
    while (accumulated_probability < total_probability) {
        const max_bits = std.math.log2_int(u16, total_probability - accumulated_probability + 1) + 1;
        const small = try reader.readBits(u16, max_bits - 1);
        const cutoff = (@as(u16, 1) << @intCast(max_bits)) - 1 - (total_probability - accumulated_probability + 1);
        const value = if (small < cutoff)
            small
        else value: {
            const value_read = small + ((try reader.readBits(u16, 1)) << @intCast(max_bits - 1));
            break :value if (value_read < @as(u16, 1) << @intCast(max_bits - 1))
                value_read
            else
                value_read - cutoff;
        };

        accumulated_probability += if (value != 0) value - 1 else 1;
        values[value_count] = value;
        value_count += 1;

        if (value == 1) {
            while (true) {
                const repeat_flag: usize = try reader.readBits(u2, 2);
                if (repeat_flag + value_count > values.len) return error.CorruptFrame;
                for (0..repeat_flag) |_| {
                    values[value_count] = 1;
                    value_count += 1;
                }
                if (repeat_flag < 3) break;
            }
        }
        if (value_count == values.len) break;
    }
    reader.alignToByte();

    if (value_count < 2) return error.CorruptFrame;
    if (accumulated_probability != total_probability) return error.CorruptFrame;
    if (value_count > expected_symbol_count) return error.CorruptFrame;
    const table_len: usize = @as(usize, 1) << @intCast(accuracy_log);
    try buildFseTable(values[0..value_count], entries[0..table_len]);
    return table_len;
}

fn buildFseTable(values: []const u16, entries: []FseTableEntry) Error!void {
    const total_probability: u16 = @intCast(entries.len);
    const accuracy_log = std.math.log2_int(u16, total_probability);
    var less_than_one_count: usize = 0;
    for (values, 0..) |value, symbol| {
        if (value == 0) {
            entries[entries.len - 1 - less_than_one_count] = .{
                .symbol = @intCast(symbol),
                .baseline = 0,
                .bits = accuracy_log,
            };
            less_than_one_count += 1;
        }
    }

    var position: usize = 0;
    var temp_states: [max_sequence_fse_table_size]u16 = undefined;
    for (values, 0..) |value, symbol| {
        if (value == 0 or value == 1) continue;
        const probability = value - 1;
        const state_share_dividend = std.math.ceilPowerOfTwo(u16, probability) catch return error.CorruptFrame;
        const share_size = @divExact(total_probability, state_share_dividend);
        const double_state_count = state_share_dividend - probability;
        const single_state_count = probability - double_state_count;
        const share_size_log = std.math.log2_int(u16, share_size);

        for (0..probability) |i| {
            temp_states[i] = @intCast(position);
            position += (entries.len >> 1) + (entries.len >> 3) + 3;
            position &= entries.len - 1;
            while (position >= entries.len - less_than_one_count) {
                position += (entries.len >> 1) + (entries.len >> 3) + 3;
                position &= entries.len - 1;
            }
        }
        std.mem.sort(u16, temp_states[0..probability], {}, std.sort.asc(u16));
        for (0..probability) |i| {
            entries[temp_states[i]] = if (i < double_state_count) .{
                .symbol = @intCast(symbol),
                .bits = @intCast(share_size_log + 1),
                .baseline = single_state_count * share_size + @as(u16, @intCast(i)) * 2 * share_size,
            } else .{
                .symbol = @intCast(symbol),
                .bits = @intCast(share_size_log),
                .baseline = (@as(u16, @intCast(i)) - double_state_count) * share_size,
            };
        }
    }
}

fn defaultLiteralLengthSymbol(state: usize) Error!SequenceSymbol {
    if (state >= default_ll_symbols.len) return error.UnsupportedZstdFeature;
    return default_ll_symbols[state];
}

fn defaultOffsetSymbol(state: usize) Error!SequenceSymbol {
    if (state >= default_of_symbols.len) return error.UnsupportedZstdFeature;
    return default_of_symbols[state];
}

fn defaultMatchLengthSymbol(state: usize) Error!SequenceSymbol {
    if (state >= default_ml_symbols.len) return error.UnsupportedZstdFeature;
    return default_ml_symbols[state];
}

const ReverseBitReader = struct {
    bytes: []const u8,
    remaining_bits: usize,

    fn init(bitstream: []const u8) Error!ReverseBitReader {
        if (bitstream.len == 0) return error.TruncatedFrame;
        const last = bitstream[bitstream.len - 1];
        if (last == 0) return error.CorruptFrame;

        const marker_bit = highBitIndex(last);
        const payload_bits = (bitstream.len - 1) * 8 + marker_bit;
        return .{ .bytes = bitstream, .remaining_bits = payload_bits };
    }

    fn read(self: *ReverseBitReader, bit_count: u8) Error!usize {
        if (bit_count == 0) return 0;
        if (bit_count > @bitSizeOf(usize)) return error.UnsupportedZstdFeature;
        if (bit_count > self.remaining_bits) return error.TruncatedFrame;
        var value: usize = 0;
        var bit = self.remaining_bits;
        while (bit > self.remaining_bits - bit_count) {
            bit -= 1;
            const byte = self.bytes[bit / 8];
            const bit_index: u3 = @intCast(bit & 7);
            value = (value << 1) | @as(usize, @intCast((byte >> bit_index) & 1));
        }
        self.remaining_bits -= bit_count;
        return value;
    }

    fn expectEnd(self: ReverseBitReader) Error!void {
        if (self.remaining_bits != 0) return error.CorruptFrame;
    }
};

const low_bit_mask = [9]u8{
    0b00000000,
    0b00000001,
    0b00000011,
    0b00000111,
    0b00001111,
    0b00011111,
    0b00111111,
    0b01111111,
    0b11111111,
};

fn ReadBitsResult(comptime T: type) type {
    return struct { T, u16 };
}

const ForwardBitReader = struct {
    bytes: []const u8,
    index: usize = 0,
    bits: u8 = 0,
    count: u4 = 0,

    fn readBits(self: *ForwardBitReader, comptime T: type, num: u16) Error!T {
        const value, const read_count = try self.readBitsTuple(T, num);
        if (read_count < num) return error.TruncatedFrame;
        return value;
    }

    fn readBitsTuple(self: *ForwardBitReader, comptime T: type, num: u16) Error!ReadBitsResult(T) {
        const UT = std.meta.Int(.unsigned, @bitSizeOf(T));
        const U = if (@bitSizeOf(T) < 8) u8 else UT;

        if (num <= self.count) return initReadBitsResult(T, self.removeBits(@intCast(num)), num);

        var out_count: u16 = self.count;
        var out: U = self.removeBits(self.count);
        const full_bytes_left = (num - out_count) / 8;
        for (0..full_bytes_left) |_| {
            const byte = self.takeByte() catch return initReadBitsResult(T, out, out_count);
            out |= @as(U, byte) << @intCast(out_count);
            out_count += 8;
        }

        const bits_left = num - out_count;
        const keep = 8 - bits_left;
        if (bits_left == 0) return initReadBitsResult(T, out, out_count);

        const final_byte = self.takeByte() catch return initReadBitsResult(T, out, out_count);
        out |= @as(U, final_byte & low_bit_mask[bits_left]) << @intCast(out_count);
        self.bits = final_byte >> @intCast(bits_left);
        self.count = @intCast(keep);
        return initReadBitsResult(T, out, num);
    }

    fn takeByte(self: *ForwardBitReader) error{EndOfStream}!u8 {
        if (self.index >= self.bytes.len) return error.EndOfStream;
        const result = self.bytes[self.index];
        self.index += 1;
        return result;
    }

    fn removeBits(self: *ForwardBitReader, num: u4) u8 {
        if (num == 8) {
            self.count = 0;
            return self.bits;
        }
        const keep = self.count - num;
        const bits = self.bits & low_bit_mask[num];
        self.bits >>= @intCast(num);
        self.count = keep;
        return bits;
    }

    fn alignToByte(self: *ForwardBitReader) void {
        self.bits = 0;
        self.count = 0;
    }

    fn byteIndex(self: ForwardBitReader) usize {
        return self.index;
    }

    fn initReadBitsResult(comptime T: type, out: anytype, num: u16) ReadBitsResult(T) {
        const UT = std.meta.Int(.unsigned, @bitSizeOf(T));
        return .{ @bitCast(@as(UT, @intCast(out))), num };
    }
};

fn highBitIndex(byte: u8) usize {
    var bit: usize = 8;
    while (bit > 0) {
        bit -= 1;
        if ((byte & (@as(u8, 1) << @as(u3, @intCast(bit)))) != 0) return bit;
    }
    unreachable;
}

fn decodeRleSequencesCompressedBlockIntoBuffer(
    block: []const u8,
    section: LiteralOnlySection,
    output: []u8,
    written: *usize,
    frame_output_start: usize,
    dictionary_history: []const u8,
    frame_state: *SequenceFrameState,
) Error!void {
    if (frame_output_start > written.*) return error.CorruptFrame;
    var offset = section.sequence_payload_offset;
    const parsed_spec = try parseSequenceModeSpec(block, &offset, section.sequence_count);
    const spec = try resolveSequenceModeSpec(parsed_spec, frame_state.previous_tables);
    if (offset != block.len) return error.UnsupportedZstdFeature;
    const bit_reader = try ReverseBitReader.init(block[spec.bitstream_offset..]);

    var state = try initSequenceDecodeState(spec, section.sequence_count, bit_reader, frame_state.repeated_offsets);
    var huffman_literals = try initHuffmanLiteralDecodeState(block, section);
    var literal_offset: usize = 0;
    while (state.remaining != 0) {
        const sequence = try readModeSequence(&state);
        const literal_len = sequence.literal_len;
        if (huffman_literals) |*huffman_state| {
            if (output.len - written.* < literal_len) return error.OutputTooSmall;
            try copyLiteralsFromHuffmanState(huffman_state, section, literal_offset, output[written.*..][0..literal_len]);
            written.* += literal_len;
        } else {
            try copyLiteralsFromSection(block, section, literal_offset, output, written, literal_len);
        }
        literal_offset = std.math.add(usize, literal_offset, literal_len) catch return error.IntegerOverflow;
        try copyMatchFromHistory(output, written, frame_output_start, dictionary_history, sequence.match_offset, sequence.match_len);
    }
    if (section.regenerated_size < literal_offset) return error.CorruptFrame;
    const last_literals = section.regenerated_size - literal_offset;
    if (huffman_literals) |*huffman_state| {
        if (output.len - written.* < last_literals) return error.OutputTooSmall;
        try copyLiteralsFromHuffmanState(huffman_state, section, literal_offset, output[written.*..][0..last_literals]);
        written.* += last_literals;
    } else {
        try copyLiteralsFromSection(block, section, literal_offset, output, written, last_literals);
    }
    frame_state.previous_tables = spec.tables();
    frame_state.repeated_offsets = state.repeated_offsets;
}

fn rleSequencesCompressedBlockDecodedSize(
    block: []const u8,
    section: LiteralOnlySection,
    initial_output_len: usize,
    frame_state: *SequenceFrameState,
) Error!usize {
    var offset = section.sequence_payload_offset;
    const parsed_spec = try parseSequenceModeSpec(block, &offset, section.sequence_count);
    const spec = try resolveSequenceModeSpec(parsed_spec, frame_state.previous_tables);
    if (offset != block.len) return error.UnsupportedZstdFeature;
    const bit_reader = try ReverseBitReader.init(block[spec.bitstream_offset..]);

    var state = try initSequenceDecodeState(spec, section.sequence_count, bit_reader, frame_state.repeated_offsets);
    var literal_offset: usize = 0;
    var produced: usize = 0;
    while (state.remaining != 0) {
        const sequence = try readModeSequence(&state);
        const literal_len = sequence.literal_len;
        if (literal_offset > section.regenerated_size or section.regenerated_size - literal_offset < literal_len) {
            return error.CorruptFrame;
        }
        literal_offset = std.math.add(usize, literal_offset, literal_len) catch return error.IntegerOverflow;
        produced = std.math.add(usize, produced, literal_len) catch return error.IntegerOverflow;
        const available = std.math.add(usize, initial_output_len, produced) catch return error.IntegerOverflow;
        if (sequence.match_offset == 0 or sequence.match_offset > available) return error.InvalidMatch;
        produced = std.math.add(usize, produced, sequence.match_len) catch return error.IntegerOverflow;
    }
    if (section.regenerated_size < literal_offset) return error.CorruptFrame;
    produced = std.math.add(usize, produced, section.regenerated_size - literal_offset) catch return error.IntegerOverflow;
    try validateHuffmanLiteralsConsumed(block, section);
    frame_state.previous_tables = spec.tables();
    frame_state.repeated_offsets = state.repeated_offsets;
    return produced;
}

const SequenceDecodeState = struct {
    spec: SequenceModeSpec,
    reader: ReverseBitReader,
    ll_state: usize = 0,
    of_state: usize = 0,
    ml_state: usize = 0,
    repeated_offsets: [3]usize = initial_repeated_offsets,
    remaining: usize,
};

fn initSequenceDecodeState(
    spec: SequenceModeSpec,
    sequence_count: usize,
    reader: ReverseBitReader,
    repeated_offsets: [3]usize,
) Error!SequenceDecodeState {
    var initialized_reader = reader;
    const ll_state = try readInitialSequenceState(&initialized_reader, spec.ll_mode, spec.literal_fse.accuracy_log, 6);
    const of_state = try readInitialSequenceState(&initialized_reader, spec.of_mode, spec.offset_fse.accuracy_log, 5);
    const ml_state = try readInitialSequenceState(&initialized_reader, spec.ml_mode, spec.match_fse.accuracy_log, 6);
    return .{
        .spec = spec,
        .reader = initialized_reader,
        .ll_state = ll_state,
        .of_state = of_state,
        .ml_state = ml_state,
        .repeated_offsets = repeated_offsets,
        .remaining = sequence_count,
    };
}

fn readInitialSequenceState(reader: *ReverseBitReader, mode: SymbolMode, fse_accuracy_log: u8, predefined_accuracy_log: u8) Error!usize {
    return switch (mode) {
        .predefined => try reader.read(predefined_accuracy_log),
        .compressed => try reader.read(fse_accuracy_log),
        .rle => 0,
        .repeat => unreachable,
    };
}

fn readModeSequence(state: *SequenceDecodeState) Error!DecodedSequence {
    if (state.remaining == 0) return error.CorruptFrame;

    const ll_symbol = try currentLiteralSymbol(state.*);
    const of_symbol = try currentOffsetSymbol(state.*);
    const ml_symbol = try currentMatchSymbol(state.*);

    // Zstandard stores the offset extra bits before match/literal extra bits,
    // but repeat-offset selection depends on the *fully decoded* literal
    // length, not merely the literal-length symbol base. Keep the bit-read order
    // intact while delaying repeat-offset mutation until the literal extra bits
    // are known.
    const offset_extra = try state.reader.read(of_symbol.additional_bits);
    const match_len = std.math.add(usize, ml_symbol.base, try state.reader.read(ml_symbol.additional_bits)) catch return error.IntegerOverflow;
    const literal_len = std.math.add(usize, ll_symbol.base, try state.reader.read(ll_symbol.additional_bits)) catch return error.IntegerOverflow;
    const match_offset = try resolveSequenceOffset(of_symbol.base, of_symbol.additional_bits, offset_extra, literal_len, &state.repeated_offsets);

    state.remaining -= 1;
    if (state.remaining != 0) {
        try updateLiteralState(state, ll_symbol);
        try updateMatchState(state, ml_symbol);
        try updateOffsetState(state, of_symbol);
    } else {
        try state.reader.expectEnd();
    }

    return .{ .literal_len = literal_len, .match_len = match_len, .match_offset = match_offset };
}

fn currentLiteralSymbol(state: SequenceDecodeState) Error!SequenceSymbol {
    return switch (state.spec.ll_mode) {
        .predefined => try defaultLiteralLengthSymbol(state.ll_state),
        .rle => state.spec.literal_rle orelse error.CorruptFrame,
        .compressed => try state.spec.literal_fse.symbol(state.ll_state),
        .repeat => unreachable,
    };
}

fn currentOffsetSymbol(state: SequenceDecodeState) Error!SequenceSymbol {
    return switch (state.spec.of_mode) {
        .predefined => try defaultOffsetSymbol(state.of_state),
        .rle => state.spec.offset_rle orelse error.CorruptFrame,
        .compressed => try state.spec.offset_fse.symbol(state.of_state),
        .repeat => unreachable,
    };
}

fn currentMatchSymbol(state: SequenceDecodeState) Error!SequenceSymbol {
    return switch (state.spec.ml_mode) {
        .predefined => try defaultMatchLengthSymbol(state.ml_state),
        .rle => state.spec.match_rle orelse error.CorruptFrame,
        .compressed => try state.spec.match_fse.symbol(state.ml_state),
        .repeat => unreachable,
    };
}

fn updateLiteralState(state: *SequenceDecodeState, symbol: SequenceSymbol) Error!void {
    if (state.spec.ll_mode == .predefined or state.spec.ll_mode == .compressed) state.ll_state = try nextSequenceState(&state.reader, symbol);
}

fn updateOffsetState(state: *SequenceDecodeState, symbol: SequenceSymbol) Error!void {
    if (state.spec.of_mode == .predefined or state.spec.of_mode == .compressed) state.of_state = try nextSequenceState(&state.reader, symbol);
}

fn updateMatchState(state: *SequenceDecodeState, symbol: SequenceSymbol) Error!void {
    if (state.spec.ml_mode == .predefined or state.spec.ml_mode == .compressed) state.ml_state = try nextSequenceState(&state.reader, symbol);
}

const DecodedSequence = struct {
    literal_len: usize,
    match_len: usize,
    match_offset: usize,
};

fn nextSequenceState(reader: *ReverseBitReader, symbol: SequenceSymbol) Error!usize {
    return std.math.add(usize, symbol.next_state, try reader.read(symbol.state_bits)) catch return error.IntegerOverflow;
}

fn resolveSequenceOffset(
    offset_base: usize,
    offset_bits: u8,
    offset_extra: usize,
    literal_len: usize,
    repeated_offsets: *[3]usize,
) Error!usize {
    if (offset_bits > 1) {
        const offset = std.math.add(usize, offset_base, offset_extra) catch return error.IntegerOverflow;
        updateRepeatedOffsets(repeated_offsets, offset);
        return offset;
    }

    const literal_len_is_zero = literal_len == 0;
    if (offset_bits == 0) {
        return try useRepeatedOffset(repeated_offsets, if (literal_len_is_zero) 1 else 0);
    }

    const raw_base = std.math.add(usize, offset_base, if (literal_len_is_zero) 1 else 0) catch return error.IntegerOverflow;
    const raw_offset = std.math.add(
        usize,
        raw_base,
        offset_extra,
    ) catch return error.IntegerOverflow;
    if (raw_offset == 3) {
        if (repeated_offsets[0] == 0) return error.InvalidMatch;
        const offset = repeated_offsets[0] - 1;
        if (offset == 0) return error.InvalidMatch;
        updateRepeatedOffsets(repeated_offsets, offset);
        return offset;
    }
    if (raw_offset >= repeated_offsets.len) return error.UnsupportedZstdFeature;
    return try useRepeatedOffset(repeated_offsets, raw_offset);
}

fn updateRepeatedOffsets(repeated_offsets: *[3]usize, offset: usize) void {
    const previous_0 = repeated_offsets[0];
    const previous_1 = repeated_offsets[1];
    repeated_offsets.* = .{ offset, previous_0, previous_1 };
}

fn useRepeatedOffset(repeated_offsets: *[3]usize, index: usize) Error!usize {
    switch (index) {
        0 => {},
        1 => std.mem.swap(usize, &repeated_offsets[0], &repeated_offsets[1]),
        2 => {
            std.mem.swap(usize, &repeated_offsets[0], &repeated_offsets[2]);
            std.mem.swap(usize, &repeated_offsets[1], &repeated_offsets[2]);
        },
        else => return error.UnsupportedZstdFeature,
    }
    if (repeated_offsets[0] == 0) return error.InvalidMatch;
    return repeated_offsets[0];
}

test "zstd native repeat-offset resolver follows selector updates" {
    var offsets = initial_repeated_offsets;
    try std.testing.expectEqual(@as(usize, 1), try resolveSequenceOffset(0, 0, 0, 1, &offsets));
    try std.testing.expectEqual([3]usize{ 1, 4, 8 }, offsets);

    offsets = initial_repeated_offsets;
    try std.testing.expectEqual(@as(usize, 4), try resolveSequenceOffset(0, 0, 0, 0, &offsets));
    try std.testing.expectEqual([3]usize{ 4, 1, 8 }, offsets);

    offsets = initial_repeated_offsets;
    try std.testing.expectEqual(@as(usize, 4), try resolveSequenceOffset(1, 1, 0, 1, &offsets));
    try std.testing.expectEqual([3]usize{ 4, 1, 8 }, offsets);

    offsets = initial_repeated_offsets;
    try std.testing.expectEqual(@as(usize, 8), try resolveSequenceOffset(1, 1, 1, 1, &offsets));
    try std.testing.expectEqual([3]usize{ 8, 1, 4 }, offsets);

    offsets = initial_repeated_offsets;
    try std.testing.expectEqual(@as(usize, 8), try resolveSequenceOffset(1, 1, 0, 0, &offsets));
    try std.testing.expectEqual([3]usize{ 8, 1, 4 }, offsets);

    offsets = initial_repeated_offsets;
    try std.testing.expectError(error.InvalidMatch, resolveSequenceOffset(1, 1, 1, 0, &offsets));
    try std.testing.expectEqual(initial_repeated_offsets, offsets);

    offsets = .{ 2, 4, 8 };
    try std.testing.expectEqual(@as(usize, 1), try resolveSequenceOffset(1, 1, 1, 0, &offsets));
    try std.testing.expectEqual([3]usize{ 1, 2, 4 }, offsets);

    offsets = initial_repeated_offsets;
    try std.testing.expectEqual(@as(usize, 5), try resolveSequenceOffset(5, 2, 0, 0, &offsets));
    try std.testing.expectEqual([3]usize{ 5, 1, 4 }, offsets);

    offsets = initial_repeated_offsets;
    try std.testing.expectEqual(@as(usize, 1), try resolveSequenceOffset(0, 0, 0, 1, &offsets)); // positive-literal rep0.
    try std.testing.expectEqual([3]usize{ 1, 4, 8 }, offsets);
    try std.testing.expectEqual(@as(usize, 4), try resolveSequenceOffset(1, 1, 0, 1, &offsets)); // positive-literal rep1.
    try std.testing.expectEqual([3]usize{ 4, 1, 8 }, offsets);
    try std.testing.expectEqual(@as(usize, 8), try resolveSequenceOffset(1, 1, 1, 1, &offsets)); // positive-literal rep2.
    try std.testing.expectEqual([3]usize{ 8, 4, 1 }, offsets);
}

fn copyMatchFromOutputBuffer(
    output: []u8,
    written: *usize,
    frame_output_start: usize,
    match_offset: usize,
    match_len: usize,
) Error!void {
    return try copyMatchFromHistory(output, written, frame_output_start, &.{}, match_offset, match_len);
}

fn copyMatchFromHistory(
    output: []u8,
    written: *usize,
    frame_output_start: usize,
    dictionary_history: []const u8,
    match_offset: usize,
    match_len: usize,
) Error!void {
    if (frame_output_start > written.*) return error.CorruptFrame;
    const available_in_frame = written.* - frame_output_start;
    const available = std.math.add(usize, dictionary_history.len, available_in_frame) catch return error.IntegerOverflow;
    if (match_offset == 0 or match_offset > available) return error.InvalidMatch;
    if (output.len - written.* < match_len) return error.OutputTooSmall;
    if (match_offset <= available_in_frame) {
        const repeat_start = written.* - match_offset;
        appendRepeatedMatch(output, written, repeat_start, match_len);
        return;
    }

    const destination_start = written.*;
    for (0..match_len) |i| {
        const logical_source = available + i - match_offset;
        output[destination_start + i] = if (logical_source < dictionary_history.len)
            dictionary_history[logical_source]
        else
            output[frame_output_start + logical_source - dictionary_history.len];
    }
    written.* += match_len;
}

fn appendRepeatedMatch(output: []u8, written: *usize, repeat_start: usize, match_len: usize) void {
    const initial_available = written.* - repeat_start;
    const destination_start = written.*;
    written.* += match_len;
    var copied: usize = 0;
    while (copied < match_len) {
        const available = if (copied == 0) initial_available else copied;
        const copy_len = @min(available, match_len - copied);
        const source_start = if (copied == 0) repeat_start else destination_start;
        @memcpy(
            output[destination_start + copied ..][0..copy_len],
            output[source_start..][0..copy_len],
        );
        copied += copy_len;
    }
}

fn rawOrRleDecodedSizeLimited(frame: []const u8, max_output_len: usize) Error!usize {
    return try rawOrRleDecodedSizeLimitedWithDictionary(frame, max_output_len, null);
}

fn rawOrRleDecodedSizeLimitedWithDictionary(
    frame: []const u8,
    max_output_len: usize,
    dictionary: ?NativeDictionary,
) Error!usize {
    var offset: usize = 0;
    var total: usize = 0;
    while (offset < frame.len) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        if (magic == frame_magic_u32) {
            const header = try parseRawOrRleFrameHeaderWithOptions(frame, &offset, true);
            const dictionary_history = try validateNativeDictionary(header, dictionary);
            const frame_start = total;
            var frame_state: SequenceFrameState = .{};
            while (true) {
                if (frame.len - offset < 3) return error.TruncatedFrame;
                const block_header = std.mem.readInt(u24, frame[offset..][0..3], .little);
                offset += 3;
                const last = (block_header & 0x1) != 0;
                const block_type = (block_header >> 1) & 0x3;
                const block_len: usize = @intCast(block_header >> 3);
                try validateBlockSize(header, block_type, block_len);

                switch (block_type) {
                    0 => {
                        if (frame.len - offset < block_len) return error.TruncatedFrame;
                        offset += block_len;
                        total = try checkedAddWithinLimit(total, block_len, max_output_len);
                    },
                    1 => {
                        if (block_len == 0) return error.CorruptFrame;
                        if (frame.len - offset < 1) return error.TruncatedFrame;
                        offset += 1;
                        total = try checkedAddWithinLimit(total, block_len, max_output_len);
                    },
                    2 => {
                        if (frame.len - offset < block_len) return error.TruncatedFrame;
                        const produced_in_frame = total - frame_start;
                        const initial_history_len = std.math.add(usize, dictionary_history.len, produced_in_frame) catch return error.IntegerOverflow;
                        const decoded_len = try compressedLiteralOnlyBlockDecodedSize(frame[offset..][0..block_len], header.block_size_max, initial_history_len, &frame_state);
                        total = try checkedAddWithinLimit(total, decoded_len, max_output_len);
                        offset += block_len;
                    },
                    else => return error.CorruptFrame,
                }
                if (last) break;
            }

            const frame_decoded_len = total - frame_start;
            if (header.content_size) |size| {
                if (try checkedUsizeToU64(frame_decoded_len) != size) return error.SizeMismatch;
            }
            if (header.has_checksum) {
                if (frame.len - offset < 4) return error.TruncatedFrame;
                offset += 4;
            }
        } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const skip_len: usize = @intCast(std.mem.readInt(u32, frame[offset..][0..4], .little));
            offset += 4;
            if (frame.len - offset < skip_len) return error.TruncatedFrame;
            offset += skip_len;
        } else {
            return error.InvalidMagic;
        }
    }
    return total;
}

fn checkedAddWithinLimit(current: usize, additional: usize, max: usize) Error!usize {
    const next = std.math.add(usize, current, additional) catch return error.IntegerOverflow;
    if (next > max) return error.OutputLimitExceeded;
    return next;
}

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch return error.IntegerOverflow;
}

fn parseRawOrRleFrameHeaderWithOptions(frame: []const u8, offset: *usize, allow_nonzero_dictionary_id: bool) Error!RawOrRleFrameHeader {
    if (frame.len - offset.* < 1) return error.TruncatedFrame;
    const descriptor = frame[offset.*];
    offset.* += 1;

    if ((descriptor & 0x08) != 0) return error.CorruptFrame;
    // Bit 4 is unused by the Zstandard frame descriptor. Reference decoders
    // accept it as a don't-care bit, so native parsing must not reject otherwise
    // valid frames that set it.

    const dictionary_id_flag = descriptor & 0x03;
    const has_checksum = (descriptor & 0x04) != 0;
    const single_segment = (descriptor & 0x20) != 0;
    const content_size_flag = descriptor >> 6;

    const window_size = if (single_segment) null else blk: {
        if (frame.len - offset.* < 1) return error.TruncatedFrame;
        const window_descriptor = frame[offset.*];
        offset.* += 1;
        break :blk decodeWindowSize(window_descriptor);
    };

    const dictionary_id_len: usize = switch (dictionary_id_flag) {
        0 => 0,
        1 => 1,
        2 => 2,
        else => 4,
    };
    if (frame.len - offset.* < dictionary_id_len) return error.TruncatedFrame;
    const dictionary_id_u64 = try readU64Field(frame, offset, dictionary_id_len);
    const dictionary_id = try checkedU64ToU32(dictionary_id_u64);
    if (dictionary_id != 0 and !allow_nonzero_dictionary_id) return error.NeedDictionary;

    const content_size: ?u64 = if (single_segment or content_size_flag != 0) blk: {
        const field_size: usize = @as(usize, 1) << @intCast(content_size_flag);
        const encoded_size = try readU64Field(frame, offset, field_size);
        break :blk if (field_size == 2) encoded_size + 256 else encoded_size;
    } else null;

    const effective_window = if (single_segment) content_size.? else window_size.?;
    const block_size_max = @min(
        std.compress.zstd.block_size_max,
        try checkedU64ToUsize(effective_window),
    );

    return .{
        .content_size = content_size,
        .has_checksum = has_checksum,
        .window_size = effective_window,
        .block_size_max = block_size_max,
        .dictionary_id = dictionary_id,
        .payload_offset = offset.*,
    };
}

fn parseRawOrRleFrameHeader(frame: []const u8, offset: *usize) Error!RawOrRleFrameHeader {
    return try parseRawOrRleFrameHeaderWithOptions(frame, offset, false);
}

pub fn inspectNativeFrameHeader(frame: []const u8) Error!NativeFrameHeader {
    if (frame.len < 4) return error.TruncatedFrame;
    const magic = std.mem.readInt(u32, frame[0..4], .little);
    if (magic != frame_magic_u32) return error.InvalidMagic;
    var offset: usize = 4;
    return try parseRawOrRleFrameHeaderWithOptions(frame, &offset, true);
}

pub fn inspectNativeFrameBlockAt(frame: []const u8, header_offset: usize) Error!NativeFrameBlockHeader {
    const header = try inspectNativeFrameHeader(frame);
    if (header_offset < header.payload_offset) return error.CorruptFrame;
    if (frame.len - header_offset < 3) return error.TruncatedFrame;
    const block_header = std.mem.readInt(u24, frame[header_offset..][0..3], .little);
    const block_type_raw = (block_header >> 1) & 0x03;
    const payload_len: usize = @intCast(block_header >> 3);
    const block_type: NativeBlockType = switch (block_type_raw) {
        0 => .raw,
        1 => .rle,
        2 => .compressed,
        else => return error.CorruptFrame,
    };
    try validateBlockSize(header, block_type_raw, payload_len);
    const payload_offset = header_offset + 3;
    const required_payload_len: usize = if (block_type == .rle) 1 else payload_len;
    if (frame.len - payload_offset < required_payload_len) return error.TruncatedFrame;
    return .{
        .header_offset = header_offset,
        .payload_offset = payload_offset,
        .payload_len = payload_len,
        .block_type = block_type,
        .last = (block_header & 1) != 0,
        .next_header_offset = payload_offset + required_payload_len,
    };
}

pub fn inspectNativeFrameFirstBlock(frame: []const u8) Error!NativeFrameBlockHeader {
    const header = try inspectNativeFrameHeader(frame);
    return try inspectNativeFrameBlockAt(frame, header.payload_offset);
}

pub fn inspectNativeFrameBlockSequenceModes(frame: []const u8, block: NativeFrameBlockHeader) Error!NativeSequenceModeSummary {
    if (block.block_type != .compressed) return error.UnsupportedZstdFeature;
    if (block.payload_offset > frame.len or frame.len - block.payload_offset < block.payload_len) return error.TruncatedFrame;
    var frame_state = try replayNativeFrameBlockInspectState(frame, block.header_offset);
    return try inspectNativeFrameBlockSequenceModesWithState(frame, block, &frame_state);
}

fn replayNativeFrameBlockInspectState(frame: []const u8, target_header_offset: usize) Error!SequenceFrameState {
    const header = try inspectNativeFrameHeader(frame);
    if (target_header_offset < header.payload_offset) return error.CorruptFrame;
    var frame_state: SequenceFrameState = .{};
    var offset = header.payload_offset;
    while (offset < target_header_offset) {
        const previous_block = try inspectNativeFrameBlockAt(frame, offset);
        if (previous_block.header_offset >= target_header_offset) break;
        if (previous_block.block_type == .compressed) {
            _ = try inspectNativeFrameBlockSequenceModesWithState(frame, previous_block, &frame_state);
        }
        if (previous_block.last) return error.CorruptFrame;
        offset = previous_block.next_header_offset;
    }
    if (offset != target_header_offset) return error.CorruptFrame;
    return frame_state;
}

fn inspectNativeFrameBlockSequenceModesWithState(
    frame: []const u8,
    block: NativeFrameBlockHeader,
    frame_state: *SequenceFrameState,
) Error!NativeSequenceModeSummary {
    if (block.block_type != .compressed) return error.UnsupportedZstdFeature;
    if (block.payload_offset > frame.len or frame.len - block.payload_offset < block.payload_len) return error.TruncatedFrame;
    const payload = frame[block.payload_offset..][0..block.payload_len];
    const section = try parseLiteralsSection(payload, frame_state);
    if (section.sequence_count == 0) {
        return .{
            .literals_kind = nativeLiteralsKind(section.kind),
            .regenerated_literals_size = section.regenerated_size,
            .sequence_count = 0,
            .literal_length_mode = .predefined,
            .offset_mode = .predefined,
            .match_length_mode = .predefined,
        };
    }
    var offset = section.sequence_payload_offset;
    const spec = try parseSequenceModeSpec(payload, &offset, section.sequence_count);
    const resolved = try resolveSequenceModeSpec(spec, frame_state.previous_tables);
    frame_state.previous_tables = resolved.tables();
    return .{
        .literals_kind = nativeLiteralsKind(section.kind),
        .regenerated_literals_size = section.regenerated_size,
        .sequence_count = section.sequence_count,
        .literal_length_mode = nativeSequenceTableMode(spec.ll_mode),
        .offset_mode = nativeSequenceTableMode(spec.of_mode),
        .match_length_mode = nativeSequenceTableMode(spec.ml_mode),
    };
}

fn nativeLiteralsKind(kind: LiteralsKind) NativeLiteralsKind {
    return switch (kind) {
        .raw => .raw,
        .rle => .rle,
        .compressed => .compressed,
        .treeless => .treeless,
    };
}

fn nativeSequenceTableMode(mode: SymbolMode) NativeSequenceTableMode {
    return switch (mode) {
        .predefined => .predefined,
        .rle => .rle,
        .compressed => .compressed,
        .repeat => .repeat,
    };
}

pub fn summarizeNativeFrameBlocks(frame: []const u8) Error!NativeFrameBlockSummary {
    const header = try inspectNativeFrameHeader(frame);
    var offset = header.payload_offset;
    var summary: NativeFrameBlockSummary = .{};
    while (true) {
        const block = try inspectNativeFrameBlockAt(frame, offset);
        summary.block_count += 1;
        switch (block.block_type) {
            .raw => summary.raw_block_count += 1,
            .rle => summary.rle_block_count += 1,
            .compressed => summary.compressed_block_count += 1,
        }
        summary.payload_bytes = std.math.add(usize, summary.payload_bytes, block.payload_len) catch return error.IntegerOverflow;
        if (block.last) break;
        offset = block.next_header_offset;
    }
    return summary;
}

pub fn inspectNativeSkippableFrame(frame: []const u8) Error!NativeSkippableFrameHeader {
    if (frame.len < 8) return error.TruncatedFrame;
    const magic = std.mem.readInt(u32, frame[0..4], .little);
    if (magic < skippable_magic_min or magic > skippable_magic_max) return error.InvalidMagic;
    const payload_len: usize = @intCast(std.mem.readInt(u32, frame[4..8], .little));
    if (frame.len - 8 < payload_len) return error.TruncatedFrame;
    return .{
        .skippable_id = @intCast(magic - skippable_magic_min),
        .payload_offset = 8,
        .payload_len = payload_len,
        .next_frame_offset = 8 + payload_len,
    };
}

pub fn summarizeNativeStream(frames: []const u8) Error!NativeStreamSummary {
    var offset: usize = 0;
    var summary: NativeStreamSummary = .{};
    while (offset < frames.len) {
        if (frames.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frames[offset..][0..4], .little);
        offset += 4;
        if (magic == frame_magic_u32) {
            const frame_start = offset - 4;
            const header = try parseRawOrRleFrameHeaderWithOptions(frames, &offset, true);
            while (true) {
                const block = try inspectNativeFrameBlockAt(frames[frame_start..], offset - frame_start);
                summary.block_count += 1;
                switch (block.block_type) {
                    .raw => summary.raw_block_count += 1,
                    .rle => summary.rle_block_count += 1,
                    .compressed => summary.compressed_block_count += 1,
                }
                summary.payload_bytes = std.math.add(usize, summary.payload_bytes, block.payload_len) catch return error.IntegerOverflow;
                offset = frame_start + block.next_header_offset;
                if (block.last) break;
            }
            if (header.has_checksum) {
                if (frames.len - offset < 4) return error.TruncatedFrame;
                offset += 4;
            }
            summary.frame_count += 1;
        } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            if (frames.len - offset < 4) return error.TruncatedFrame;
            const skip_len: usize = @intCast(std.mem.readInt(u32, frames[offset..][0..4], .little));
            offset += 4;
            if (frames.len - offset < skip_len) return error.TruncatedFrame;
            summary.skippable_frame_count += 1;
            summary.skippable_payload_bytes = std.math.add(usize, summary.skippable_payload_bytes, skip_len) catch return error.IntegerOverflow;
            offset += skip_len;
        } else {
            return error.InvalidMagic;
        }
    }
    return summary;
}

fn findNativeFrameEnd(frames: []const u8, frame_start: usize) Error!usize {
    if (frame_start > frames.len) return error.TruncatedFrame;
    if (frames.len - frame_start < 4) return error.TruncatedFrame;
    if (std.mem.readInt(u32, frames[frame_start..][0..4], .little) != frame_magic_u32) return error.InvalidMagic;

    var offset = frame_start + 4;
    const header = try parseRawOrRleFrameHeaderWithOptions(frames, &offset, true);
    while (true) {
        const block = try inspectNativeFrameBlockAt(frames[frame_start..], offset - frame_start);
        offset = frame_start + block.next_header_offset;
        if (block.last) break;
    }
    if (header.has_checksum) {
        if (frames.len - offset < 4) return error.TruncatedFrame;
        offset += 4;
    }
    return offset;
}

fn decodeWindowSize(descriptor: u8) u64 {
    const exponent = (descriptor & 0b1111_1000) >> 3;
    const mantissa = descriptor & 0b0000_0111;
    const window_log = 10 + @as(u6, @intCast(exponent));
    const window_base = @as(u64, 1) << window_log;
    return window_base + (window_base / 8) * mantissa;
}

fn readU64Field(frame: []const u8, offset: *usize, field_size: usize) Error!u64 {
    if (frame.len - offset.* < field_size) return error.TruncatedFrame;
    var value: u64 = 0;
    for (frame[offset.*..][0..field_size], 0..) |byte, i| {
        value |= @as(u64, byte) << @as(u6, @intCast(i * 8));
    }
    offset.* += field_size;
    return value;
}

fn rleByte(block: []const u8) ?u8 {
    if (block.len < 2) return null;
    const first = block[0];
    for (block[1..]) |byte| {
        if (byte != first) return null;
    }
    return first;
}

const RleRun = struct {
    start: usize,
    len: usize,
};

fn findRleRun(block: []const u8) ?RleRun {
    var i: usize = 0;
    while (i < block.len) {
        const len = sameByteRunLen(block, i);
        if (len >= min_rle_split_len) return .{ .start = i, .len = len };
        i += @max(len, 1);
    }
    return null;
}

fn sameByteRunLen(block: []const u8, start: usize) usize {
    const byte = block[start];
    var end = start + 1;
    while (end < block.len and block[end] == byte) : (end += 1) {}
    return end - start;
}

fn emitBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, last: bool) Error!void {
    if (rleByte(block)) |byte| return try emitRleBlock(allocator, out, byte, block.len, last);
    return try emitRawBlock(allocator, out, block, last);
}

fn emitLiteralOnlyCompressedBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, last: bool, state: *LiteralOnlyEncoderState) Error!void {
    return try emitLiteralOnlyCompressedBlockWithDictionary(allocator, out, block, last, state, null, 0, mixed_match_path_search_budget);
}

fn emitLiteralOnlyCompressedBlockWithDictionary(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    last: bool,
    state: *LiteralOnlyEncoderState,
    dictionary: ?NativeDictionary,
    frame_offset: usize,
    match_search_budget: usize,
) Error!void {
    var dictionary_block: std.ArrayList(u8) = .empty;
    defer dictionary_block.deinit(allocator);
    const dictionary_ok = if (dictionary) |dict|
        try emitDictionaryMatchCompressedBlock(allocator, &dictionary_block, block, last, dict, frame_offset, match_search_budget)
    else
        false;

    var huffman_state = state.*;
    var huffman_block: std.ArrayList(u8) = .empty;
    defer huffman_block.deinit(allocator);
    const huffman_ok = try emitSmallHuffmanLiteralBlock(allocator, &huffman_block, block, last, &huffman_state);

    var match_block: std.ArrayList(u8) = .empty;
    defer match_block.deinit(allocator);
    const match_ok = try emitNativeMatchCompressedBlock(allocator, &match_block, block, last, match_search_budget);

    const CandidateKind = enum { dictionary, huffman, match };
    var best_kind: ?CandidateKind = null;
    var best_len: usize = std.math.maxInt(usize);
    if (dictionary_ok) {
        best_kind = .dictionary;
        best_len = dictionary_block.items.len;
    }
    if (huffman_ok and huffman_block.items.len <= best_len) {
        best_kind = .huffman;
        best_len = huffman_block.items.len;
    }
    if (match_ok and match_block.items.len < best_len) {
        best_kind = .match;
        best_len = match_block.items.len;
    }

    if (best_kind) |kind| switch (kind) {
        .dictionary => {
            state.previous_huffman_plan = null;
            try out.appendSlice(allocator, dictionary_block.items);
            return;
        },
        .huffman => {
            try out.appendSlice(allocator, huffman_block.items);
            state.* = huffman_state;
            return;
        },
        .match => {
            state.previous_huffman_plan = null;
            try out.appendSlice(allocator, match_block.items);
            return;
        },
    };

    const literal_kind: LiteralsKind = if (rleByte(block) != null) .rle else .raw;
    const literal_payload_len: usize = switch (literal_kind) {
        .raw => block.len,
        .rle => 1,
        .compressed, .treeless => unreachable,
    };
    const header_len = try literalsHeaderLen(block.len);
    const payload_prefix_len = std.math.add(usize, header_len, literal_payload_len) catch return error.IntegerOverflow;
    const payload_len = std.math.add(
        usize,
        payload_prefix_len,
        1, // sequence_count=0: the compressed block is literals-only.
    ) catch return error.IntegerOverflow;
    // The reference encoder avoids compressed blocks when entropy/literal
    // section headers erase the size win. Requiring an actual size reduction
    // also sidesteps deployed zstd CLI/lib builds that reject some
    // sequence-free compressed blocks once Block_Size exceeds the regenerated
    // block size.
    if (payload_len >= block.len) return try emitBlock(allocator, out, block, last);

    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(allocator);
    if (literal_kind == .rle) {
        try emitLiteralsHeader(allocator, &payload, .rle, block.len);
        try payload.append(allocator, block[0]);
    } else {
        try emitLiteralsHeader(allocator, &payload, .raw, block.len);
        try payload.appendSlice(allocator, block);
    }
    try payload.append(allocator, 0); // sequence_count=0: the compressed block is literals-only.
    try emitBlockHeader(allocator, out, 2, payload.items.len, last);
    try out.appendSlice(allocator, payload.items);
}

fn emitNativeMatchCompressedBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, last: bool, match_search_budget: usize) Error!bool {
    if (match_search_budget == 0) return false;

    // The bootstrap match emitters are intentionally independent heuristics.
    // Plan all successful candidates and then copy the smallest encoded block so
    // a broad mixed plan cannot hide a tighter single-family plan found later.
    var mixed_block: std.ArrayList(u8) = .empty;
    defer mixed_block.deinit(allocator);
    const mixed_ok = try emitMixedDuplicateRepeatedMatchCompressedBlock(allocator, &mixed_block, block, last, match_search_budget);

    var repeated_block: std.ArrayList(u8) = .empty;
    defer repeated_block.deinit(allocator);
    const repeated_ok = try emitRepeatedPatternCompressedBlock(allocator, &repeated_block, block, last);

    var multi_duplicate_block: std.ArrayList(u8) = .empty;
    defer multi_duplicate_block.deinit(allocator);
    const multi_duplicate_ok = try emitMultiDuplicateMatchCompressedBlock(allocator, &multi_duplicate_block, block, last);

    var single_duplicate_block: std.ArrayList(u8) = .empty;
    defer single_duplicate_block.deinit(allocator);
    const single_duplicate_ok = try emitSingleMatchCompressedBlock(allocator, &single_duplicate_block, block, last);

    var best: ?[]const u8 = null;
    var best_len: usize = std.math.maxInt(usize);
    chooseShortestPlannedBlock(mixed_ok, mixed_block.items, &best, &best_len);
    chooseShortestPlannedBlock(repeated_ok, repeated_block.items, &best, &best_len);
    chooseShortestPlannedBlock(multi_duplicate_ok, multi_duplicate_block.items, &best, &best_len);
    chooseShortestPlannedBlock(single_duplicate_ok, single_duplicate_block.items, &best, &best_len);

    const best_block = best orelse return false;
    try out.appendSlice(allocator, best_block);
    return true;
}

fn emitDictionaryMatchCompressedBlock(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    last: bool,
    dictionary: NativeDictionary,
    frame_offset: usize,
    match_search_budget: usize,
) Error!bool {
    var mixed_block: std.ArrayList(u8) = .empty;
    defer mixed_block.deinit(allocator);
    const mixed_ok = try emitMixedDictionaryDuplicateMatchCompressedBlock(allocator, &mixed_block, block, last, dictionary, frame_offset, match_search_budget);

    var multi_block: std.ArrayList(u8) = .empty;
    defer multi_block.deinit(allocator);
    const multi_ok = try emitMultiDictionaryMatchCompressedBlock(allocator, &multi_block, block, last, dictionary, frame_offset);

    var single_block: std.ArrayList(u8) = .empty;
    defer single_block.deinit(allocator);
    const single_ok = try emitSingleDictionaryMatchCompressedBlock(allocator, &single_block, block, last, dictionary, frame_offset);

    var best: ?[]const u8 = null;
    var best_len: usize = std.math.maxInt(usize);
    chooseShortestPlannedBlock(mixed_ok, mixed_block.items, &best, &best_len);
    chooseShortestPlannedBlock(multi_ok, multi_block.items, &best, &best_len);
    chooseShortestPlannedBlock(single_ok, single_block.items, &best, &best_len);

    const best_block = best orelse return false;
    try out.appendSlice(allocator, best_block);
    return true;
}

fn chooseShortestPlannedBlock(ok: bool, block: []const u8, best: *?[]const u8, best_len: *usize) void {
    if (!ok or block.len >= best_len.*) return;
    best.* = block;
    best_len.* = block.len;
}

fn emitSingleDictionaryMatchCompressedBlock(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    last: bool,
    dictionary: NativeDictionary,
    frame_offset: usize,
) Error!bool {
    const match = findDictionaryMatch(dictionary.content, block, frame_offset) orelse return false;
    const literal_len = match.block_start;
    const match_offset = try dictionaryMatchOffset(dictionary.content.len, frame_offset, match);
    const tail_start = match.block_start + match.len;
    const literal_lens = [_]usize{literal_len};
    const offsets = [_]usize{match_offset};
    const match_lens = [_]usize{match.len};
    const literal_ends = [_]usize{tail_start};
    return try emitBestSequenceCompressedBlock(allocator, out, block, last, &literal_lens, &offsets, &match_lens, &literal_ends, tail_start);
}

const MixedMatchKind = enum { dictionary, duplicate, repeated };

const MixedMatchCandidate = struct {
    literal_len: usize,
    offset: usize,
    match_len: usize,
    literal_end: usize,
    payload_len: usize,
    kind: MixedMatchKind,
};

const MixedMatchKindSet = struct {
    dictionary: bool = false,
    duplicate: bool = false,
    repeated: bool = false,

    fn contains(self: MixedMatchKindSet, kind: MixedMatchKind) bool {
        return switch (kind) {
            .dictionary => self.dictionary,
            .duplicate => self.duplicate,
            .repeated => self.repeated,
        };
    }

    fn eql(self: MixedMatchKindSet, other: MixedMatchKindSet) bool {
        return self.dictionary == other.dictionary and
            self.duplicate == other.duplicate and
            self.repeated == other.repeated;
    }
};

const MixedMatchRequirement = union(enum) {
    kind: MixedMatchKind,
    non_dictionary,
};

const MixedMatchLookaheadRequirements = struct {
    first: MixedMatchRequirement,
    second: MixedMatchRequirement,
};

fn emitMixedDictionaryDuplicateMatchCompressedBlock(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    last: bool,
    dictionary: NativeDictionary,
    frame_offset: usize,
    match_search_budget: usize,
) Error!bool {
    const plan = try bestMixedMatchLookaheadPlan(dictionary.content, block, frame_offset, .{
        .dictionary = true,
        .duplicate = true,
        .repeated = true,
    }, .{ .kind = .dictionary }, .non_dictionary, match_search_budget) orelse return false;
    return try emitBestSequenceCompressedBlockFromLookaheadPlan(
        allocator,
        out,
        block,
        last,
        plan,
    );
}

fn emitMixedDuplicateRepeatedMatchCompressedBlock(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    last: bool,
    match_search_budget: usize,
) Error!bool {
    const plan = try bestMixedMatchLookaheadPlan(&.{}, block, 0, .{
        .dictionary = false,
        .duplicate = true,
        .repeated = true,
    }, .{ .kind = .duplicate }, .{ .kind = .repeated }, match_search_budget) orelse return false;
    return try emitBestSequenceCompressedBlockFromLookaheadPlan(
        allocator,
        out,
        block,
        last,
        plan,
    );
}

fn emitBestSequenceCompressedBlockFromLookaheadPlan(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    last: bool,
    plan: MixedMatchLookaheadPlan,
) Error!bool {
    return try emitBestSequenceCompressedBlock(
        allocator,
        out,
        block,
        last,
        plan.literal_lens[0..plan.count],
        plan.offsets[0..plan.count],
        plan.match_lens[0..plan.count],
        plan.literal_ends[0..plan.count],
        plan.tail_start,
    );
}

fn dictionaryMixedMatchCandidate(
    dictionary: []const u8,
    block: []const u8,
    literal_start: usize,
    frame_offset: usize,
) Error!?MixedMatchCandidate {
    const match = findDictionaryMatchIn(dictionary, block, literal_start, frame_offset) orelse return null;
    const payload_len = dictionaryMatchPayloadLenFrom(block, match, literal_start, frame_offset, dictionary.len) orelse return null;
    return .{
        .literal_len = match.block_start - literal_start,
        .offset = try dictionaryMatchOffset(dictionary.len, frame_offset, match),
        .match_len = match.len,
        .literal_end = match.block_start + match.len,
        .payload_len = payload_len,
        .kind = .dictionary,
    };
}

fn duplicateMixedMatchCandidate(block: []const u8, literal_start: usize) Error!?MixedMatchCandidate {
    if (try findBestDuplicateMatchIn(block, literal_start)) |match| {
        const payload_len = singleMatchPayloadLenFrom(block, match, literal_start) catch return null;
        return .{
            .literal_len = match.second_start - literal_start,
            .offset = match.second_start - match.first_start,
            .match_len = match.len,
            .literal_end = match.second_start + match.len,
            .payload_len = payload_len,
            .kind = .duplicate,
        };
    }
    return null;
}

fn repeatedMixedMatchCandidate(block: []const u8, literal_start: usize) ?MixedMatchCandidate {
    if (findRepeatedPatternSegmentIn(block, literal_start, block.len)) |segment| {
        if (repeatedPatternPayloadLenFrom(block, segment, literal_start)) |payload_len| {
            const literal_len = segment.start - literal_start + segment.period;
            return .{
                .literal_len = literal_len,
                .offset = segment.period,
                .match_len = segment.match_len,
                .literal_end = segment.start + segment.period + segment.match_len,
                .payload_len = payload_len,
                .kind = .repeated,
            };
        }
    }
    return null;
}

fn mixedCandidateLookaheadPayloadLen(
    dictionary: []const u8,
    block: []const u8,
    frame_offset: usize,
    candidate: MixedMatchCandidate,
) Error!?usize {
    const plan = try bestMixedCandidateLookaheadPlanFromFirst(
        dictionary,
        block,
        frame_offset,
        .{ .dictionary = true, .duplicate = true, .repeated = true },
        null,
        candidate,
    ) orelse return null;
    return plan.payload_len;
}

const MixedMatchLookaheadPlan = struct {
    literal_lens: [max_bootstrap_sequence_count]usize = undefined,
    offsets: [max_bootstrap_sequence_count]usize = undefined,
    match_lens: [max_bootstrap_sequence_count]usize = undefined,
    literal_ends: [max_bootstrap_sequence_count]usize = undefined,
    kinds: [max_bootstrap_sequence_count]MixedMatchKind = undefined,
    count: usize = 0,
    tail_start: usize = 0,
    payload_len: usize = 0,
};

const MixedMatchCandidateCacheEntry = struct {
    literal_start: usize = 0,
    allowed: MixedMatchKindSet = .{},
    candidates: [3]MixedMatchCandidate = undefined,
    count: usize = 0,
};

const MixedMatchCandidateCache = struct {
    entries: [mixed_match_path_search_budget]MixedMatchCandidateCacheEntry = undefined,
    len: usize = 0,
    lookup_count: usize = 0,
    hit_count: usize = 0,

    fn candidatesAt(
        self: *MixedMatchCandidateCache,
        dictionary: []const u8,
        block: []const u8,
        literal_start: usize,
        frame_offset: usize,
        allowed: MixedMatchKindSet,
        out: []MixedMatchCandidate,
    ) Error!usize {
        if (out.len < 3) return error.OutputTooSmall;
        self.lookup_count += 1;
        for (self.entries[0..self.len]) |entry| {
            if (entry.literal_start == literal_start and entry.allowed.eql(allowed)) {
                self.hit_count += 1;
                @memcpy(out[0..entry.count], entry.candidates[0..entry.count]);
                return entry.count;
            }
        }

        const count = try mixedMatchCandidatesAtUncached(dictionary, block, literal_start, frame_offset, allowed, out);
        if (self.len < self.entries.len) {
            self.entries[self.len] = .{
                .literal_start = literal_start,
                .allowed = allowed,
                .count = count,
            };
            @memcpy(self.entries[self.len].candidates[0..count], out[0..count]);
            self.len += 1;
        }
        return count;
    }
};

fn bestMixedCandidateLookaheadPlan(
    dictionary: []const u8,
    block: []const u8,
    frame_offset: usize,
    first_candidate: MixedMatchCandidate,
) Error!?MixedMatchLookaheadPlan {
    return try bestMixedCandidateLookaheadPlanFromFirst(
        dictionary,
        block,
        frame_offset,
        .{ .dictionary = true, .duplicate = true, .repeated = true },
        null,
        first_candidate,
    );
}

fn bestMixedMatchLookaheadPlan(
    dictionary: []const u8,
    block: []const u8,
    frame_offset: usize,
    allowed: MixedMatchKindSet,
    required_first: MixedMatchRequirement,
    required_second: MixedMatchRequirement,
    match_search_budget: usize,
) Error!?MixedMatchLookaheadPlan {
    if (match_search_budget == 0) return null;
    var first_candidates: [3]MixedMatchCandidate = undefined;
    var candidate_cache: MixedMatchCandidateCache = .{};
    const first_count = try candidate_cache.candidatesAt(dictionary, block, 0, frame_offset, allowed, first_candidates[0..]);
    if (first_count == 0) return null;

    const requirements: MixedMatchLookaheadRequirements = .{
        .first = required_first,
        .second = required_second,
    };
    var best: ?MixedMatchLookaheadPlan = null;
    for (first_candidates[0..first_count]) |candidate| {
        const plan = try bestMixedCandidateLookaheadPlanFromFirstWithCache(
            dictionary,
            block,
            frame_offset,
            allowed,
            requirements,
            &candidate_cache,
            candidate,
            match_search_budget,
        ) orelse continue;
        if (mixedMatchLookaheadPlanBetter(plan, best)) best = plan;
    }
    return best;
}

fn bestMixedCandidateLookaheadPlanFromFirst(
    dictionary: []const u8,
    block: []const u8,
    frame_offset: usize,
    allowed: MixedMatchKindSet,
    requirements: ?MixedMatchLookaheadRequirements,
    first_candidate: MixedMatchCandidate,
) Error!?MixedMatchLookaheadPlan {
    var candidate_cache: MixedMatchCandidateCache = .{};
    return try bestMixedCandidateLookaheadPlanFromFirstWithCache(
        dictionary,
        block,
        frame_offset,
        allowed,
        requirements,
        &candidate_cache,
        first_candidate,
        mixed_match_path_search_budget,
    );
}

fn bestMixedCandidateLookaheadPlanFromFirstWithCache(
    dictionary: []const u8,
    block: []const u8,
    frame_offset: usize,
    allowed: MixedMatchKindSet,
    requirements: ?MixedMatchLookaheadRequirements,
    candidate_cache: *MixedMatchCandidateCache,
    first_candidate: MixedMatchCandidate,
    match_search_budget: usize,
) Error!?MixedMatchLookaheadPlan {
    if (match_search_budget == 0) return null;
    if (!allowed.contains(first_candidate.kind)) return null;
    var plan: MixedMatchLookaheadPlan = .{};
    var search_budget: usize = match_search_budget;
    var seen: MixedMatchKindSet = .{};
    const best = try bestMixedCandidateLookaheadPlanFrom(
        dictionary,
        block,
        frame_offset,
        allowed,
        requirements,
        candidate_cache,
        first_candidate,
        &plan,
        0,
        &search_budget,
        &seen,
    );
    if (best == null or best.?.count < 2) return null;
    return best;
}

fn bestMixedCandidateLookaheadPlanFrom(
    dictionary: []const u8,
    block: []const u8,
    frame_offset: usize,
    allowed: MixedMatchKindSet,
    requirements: ?MixedMatchLookaheadRequirements,
    candidate_cache: *MixedMatchCandidateCache,
    candidate: MixedMatchCandidate,
    plan: *MixedMatchLookaheadPlan,
    depth: usize,
    search_budget: *usize,
    seen: *MixedMatchKindSet,
) Error!?MixedMatchLookaheadPlan {
    if (search_budget.* == 0 or depth >= max_bootstrap_sequence_count) return null;
    search_budget.* -= 1;

    const previous_seen = seen.*;
    noteMixedMatchKind(seen, candidate.kind);
    plan.literal_lens[depth] = candidate.literal_len;
    plan.offsets[depth] = candidate.offset;
    plan.match_lens[depth] = candidate.match_len;
    plan.literal_ends[depth] = candidate.literal_end;
    plan.kinds[depth] = candidate.kind;
    const count = depth + 1;

    var best: ?MixedMatchLookaheadPlan = null;
    if (candidate.literal_end >= block.len or count == max_bootstrap_sequence_count) {
        best = try finalizeMixedMatchLookaheadPlan(block, plan, count, candidate.literal_end, seen.*, requirements);
    } else {
        // Treat "stop matching here and carry the remaining bytes as literals"
        // as one valid branch once there are enough sequences to form a mixed
        // block. Extra sequences are not free: their table state transitions and
        // extra bits can outweigh the literals they remove. Keeping this prefix
        // candidate also makes the bounded search degrade safely if dense
        // candidate graphs exhaust the small bootstrap budget.
        best = try finalizeMixedMatchLookaheadPlan(block, plan, count, candidate.literal_end, seen.*, requirements);
        var next_candidates: [3]MixedMatchCandidate = undefined;
        const next_count = try candidate_cache.candidatesAt(dictionary, block, candidate.literal_end, frame_offset, allowed, next_candidates[0..]);
        if (next_count == 0) {
            seen.* = previous_seen;
            return best;
        } else {
            for (next_candidates[0..next_count]) |next| {
                const branch = try bestMixedCandidateLookaheadPlanFrom(
                    dictionary,
                    block,
                    frame_offset,
                    allowed,
                    requirements,
                    candidate_cache,
                    next,
                    plan,
                    count,
                    search_budget,
                    seen,
                ) orelse continue;
                if (mixedMatchLookaheadPlanBetter(branch, best)) best = branch;
                if (search_budget.* == 0) break;
            }
        }
    }

    plan.count = depth;
    seen.* = previous_seen;
    return best;
}

fn finalizeMixedMatchLookaheadPlan(
    block: []const u8,
    plan: *MixedMatchLookaheadPlan,
    count: usize,
    tail_start: usize,
    seen: MixedMatchKindSet,
    requirements: ?MixedMatchLookaheadRequirements,
) Error!?MixedMatchLookaheadPlan {
    if (count < 2) return null;
    if (requirements) |required| {
        if (!mixedMatchRequirementMet(seen, required.first) or
            !mixedMatchRequirementMet(seen, required.second)) return null;
    }
    var finalized = plan.*;
    finalized.count = count;
    finalized.tail_start = tail_start;
    finalized.payload_len = try bestSequencePayloadLenWithLiteralEnds(
        block,
        finalized.literal_lens[0..count],
        finalized.offsets[0..count],
        finalized.match_lens[0..count],
        finalized.literal_ends[0..count],
        tail_start,
    );
    return finalized;
}

fn noteMixedMatchKind(seen: *MixedMatchKindSet, kind: MixedMatchKind) void {
    switch (kind) {
        .dictionary => seen.dictionary = true,
        .duplicate => seen.duplicate = true,
        .repeated => seen.repeated = true,
    }
}

fn mixedMatchRequirementMet(seen: MixedMatchKindSet, requirement: MixedMatchRequirement) bool {
    return switch (requirement) {
        .kind => |kind| seen.contains(kind),
        .non_dictionary => seen.duplicate or seen.repeated,
    };
}

fn mixedMatchLookaheadPlanBetter(candidate: MixedMatchLookaheadPlan, current: ?MixedMatchLookaheadPlan) bool {
    const existing = current orelse return true;
    if (candidate.payload_len != existing.payload_len) return candidate.payload_len < existing.payload_len;
    if (candidate.count != existing.count) return candidate.count > existing.count;
    const candidate_last = candidate.literal_ends[candidate.count - 1];
    const existing_last = existing.literal_ends[existing.count - 1];
    return candidate_last > existing_last;
}

fn mixedMatchCandidatesAt(
    dictionary: []const u8,
    block: []const u8,
    literal_start: usize,
    frame_offset: usize,
    allowed: MixedMatchKindSet,
    out: []MixedMatchCandidate,
) Error!usize {
    // This helper is used by tests/probes that need one deterministic candidate
    // snapshot. The recursive planner passes an explicit MixedMatchCandidateCache
    // through its call tree so repeated positions share scan results; allocating a
    // fresh full-size cache here would only add stack pressure without reuse.
    return try mixedMatchCandidatesAtUncached(dictionary, block, literal_start, frame_offset, allowed, out);
}

fn mixedMatchCandidatesAtUncached(
    dictionary: []const u8,
    block: []const u8,
    literal_start: usize,
    frame_offset: usize,
    allowed: MixedMatchKindSet,
    out: []MixedMatchCandidate,
) Error!usize {
    if (out.len < 3) return error.OutputTooSmall;
    var count: usize = 0;
    if (allowed.dictionary) {
        if (try dictionaryMixedMatchCandidate(dictionary, block, literal_start, frame_offset)) |candidate| {
            out[count] = candidate;
            count += 1;
        }
    }
    if (allowed.duplicate) {
        if (try duplicateMixedMatchCandidate(block, literal_start)) |candidate| {
            out[count] = candidate;
            count += 1;
        }
    }
    if (allowed.repeated) {
        if (repeatedMixedMatchCandidate(block, literal_start)) |candidate| {
            out[count] = candidate;
            count += 1;
        }
    }
    std.mem.sort(MixedMatchCandidate, out[0..count], {}, mixedMatchCandidateSortLessThan);
    return count;
}

fn mixedMatchCandidateSortLessThan(_: void, a: MixedMatchCandidate, b: MixedMatchCandidate) bool {
    if (a.payload_len != b.payload_len) return a.payload_len < b.payload_len;
    if (a.match_len != b.match_len) return a.match_len > b.match_len;
    if (a.literal_len != b.literal_len) return a.literal_len < b.literal_len;
    return mixedMatchKindRank(a.kind) > mixedMatchKindRank(b.kind);
}

fn mixedMatchCandidateBetter(candidate: MixedMatchCandidate, current: ?MixedMatchCandidate) bool {
    const existing = current orelse return true;
    if (candidate.payload_len != existing.payload_len) return candidate.payload_len < existing.payload_len;
    if (candidate.match_len != existing.match_len) return candidate.match_len > existing.match_len;
    if (candidate.literal_len != existing.literal_len) return candidate.literal_len < existing.literal_len;
    return mixedMatchKindRank(candidate.kind) > mixedMatchKindRank(existing.kind);
}

fn mixedMatchKindRank(kind: MixedMatchKind) u2 {
    return switch (kind) {
        .duplicate => 0,
        .dictionary => 1,
        .repeated => 2,
    };
}

fn emitMultiDictionaryMatchCompressedBlock(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    last: bool,
    dictionary: NativeDictionary,
    frame_offset: usize,
) Error!bool {
    var literal_lens: [max_bootstrap_sequence_count]usize = undefined;
    var offsets: [max_bootstrap_sequence_count]usize = undefined;
    var match_lens: [max_bootstrap_sequence_count]usize = undefined;
    var literal_ends: [max_bootstrap_sequence_count]usize = undefined;
    var count: usize = 0;
    var literal_start: usize = 0;
    while (count < max_bootstrap_sequence_count and literal_start < block.len) {
        const match = findDictionaryMatchIn(dictionary.content, block, literal_start, frame_offset) orelse break;
        literal_lens[count] = match.block_start - literal_start;
        offsets[count] = try dictionaryMatchOffset(dictionary.content.len, frame_offset, match);
        match_lens[count] = match.len;
        literal_ends[count] = match.block_start + match.len;
        literal_start = literal_ends[count];
        count += 1;
    }
    if (count < 2) return false;

    return try emitBestSequenceCompressedBlock(
        allocator,
        out,
        block,
        last,
        literal_lens[0..count],
        offsets[0..count],
        match_lens[0..count],
        literal_ends[0..count],
        literal_start,
    );
}

fn emitSingleMatchCompressedBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, last: bool) Error!bool {
    if (rleByte(block) != null) return false;
    const match = try findBestDuplicateMatch(block) orelse return false;
    const literal_len = match.second_start;
    const offset = match.second_start - match.first_start;
    const tail_start = match.second_start + match.len;
    const literal_lens = [_]usize{literal_len};
    const offsets = [_]usize{offset};
    const match_lens = [_]usize{match.len};
    const literal_ends = [_]usize{tail_start};
    return try emitBestSequenceCompressedBlock(allocator, out, block, last, &literal_lens, &offsets, &match_lens, &literal_ends, tail_start);
}

fn emitMultiDuplicateMatchCompressedBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, last: bool) Error!bool {
    if (rleByte(block) != null or block.len < 32) return false;
    var matches: [max_bootstrap_sequence_count]DuplicateMatch = undefined;
    var literal_lens: [max_bootstrap_sequence_count]usize = undefined;
    var count: usize = 0;
    var literal_start: usize = 0;
    while (count < matches.len and literal_start < block.len) {
        const match = try findBestDuplicateMatchIn(block, literal_start) orelse break;
        const literal_len = match.second_start - literal_start;
        matches[count] = match;
        literal_lens[count] = literal_len;
        count += 1;
        literal_start = match.second_start + match.len;
    }
    if (count < 2) return false;
    const tail_start = literal_start;
    var offsets: [max_bootstrap_sequence_count]usize = undefined;
    var match_lens: [max_bootstrap_sequence_count]usize = undefined;
    var literal_ends: [max_bootstrap_sequence_count]usize = undefined;
    for (matches[0..count], 0..) |match, i| {
        offsets[i] = match.second_start - match.first_start;
        match_lens[i] = match.len;
        literal_ends[i] = match.second_start + match.len;
    }
    return try emitBestSequenceCompressedBlock(
        allocator,
        out,
        block,
        last,
        literal_lens[0..count],
        offsets[0..count],
        match_lens[0..count],
        literal_ends[0..count],
        tail_start,
    );
}

fn emitMultiDuplicateMatchPredefinedCompressedBlock(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    last: bool,
    matches: []const DuplicateMatch,
    literal_lens: []const usize,
    tail_start: usize,
) Error!bool {
    if (matches.len != literal_lens.len or matches.len < 2 or matches.len > max_bootstrap_sequence_count) return false;

    var offsets: [max_bootstrap_sequence_count]usize = undefined;
    var match_lens: [max_bootstrap_sequence_count]usize = undefined;
    var literal_ends: [max_bootstrap_sequence_count]usize = undefined;
    for (matches, 0..) |match, i| {
        offsets[i] = match.second_start - match.first_start;
        match_lens[i] = match.len;
        literal_ends[i] = match.second_start + match.len;
    }
    return try emitMultiSequencePredefinedCompressedBlock(
        allocator,
        out,
        block,
        last,
        literal_lens,
        offsets[0..matches.len],
        match_lens[0..matches.len],
        literal_ends[0..matches.len],
        tail_start,
    );
}

fn emitBestSequenceCompressedBlock(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    last: bool,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
) Error!bool {
    var rle_block: std.ArrayList(u8) = .empty;
    defer rle_block.deinit(allocator);
    const rle_ok = try emitRleSequenceCompressedBlock(
        allocator,
        &rle_block,
        block,
        last,
        literal_lens,
        offsets,
        match_lens,
        literal_ends,
        tail_start,
    );

    var predefined_block: std.ArrayList(u8) = .empty;
    defer predefined_block.deinit(allocator);
    const predefined_ok = try emitMultiSequencePredefinedCompressedBlock(
        allocator,
        &predefined_block,
        block,
        last,
        literal_lens,
        offsets,
        match_lens,
        literal_ends,
        tail_start,
    );

    var table_plan_block: std.ArrayList(u8) = .empty;
    defer table_plan_block.deinit(allocator);
    const table_plan_ok = try emitTablePlanSequenceCompressedBlock(
        allocator,
        &table_plan_block,
        block,
        last,
        literal_lens,
        offsets,
        match_lens,
        literal_ends,
        tail_start,
    );

    var best: ?[]const u8 = null;
    var best_len: usize = std.math.maxInt(usize);
    chooseShortestPlannedBlock(rle_ok, rle_block.items, &best, &best_len);
    chooseShortestPlannedBlock(predefined_ok, predefined_block.items, &best, &best_len);
    chooseShortestPlannedBlock(table_plan_ok, table_plan_block.items, &best, &best_len);
    const best_block = best orelse return false;
    try out.appendSlice(allocator, best_block);
    return true;
}

fn emitRleSequenceCompressedBlock(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    last: bool,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
) Error!bool {
    if (literal_lens.len != offsets.len or literal_lens.len != match_lens.len) return false;
    if (literal_lens.len != literal_ends.len) return false;
    if (literal_lens.len == 0 or literal_lens.len > max_bootstrap_sequence_count) return false;

    const literal_code = try sequenceCodeForValue(literal_lens[0], &ll_base, &ll_bits);
    const offset_code = try sequenceCodeForValue(offsets[0], &of_base, &of_bits);
    const match_code = try sequenceCodeForValue(match_lens[0], &ml_base, &ml_bits);
    for (1..literal_lens.len) |i| {
        if (try sequenceCodeForValue(literal_lens[i], &ll_base, &ll_bits) != literal_code) return false;
        if (try sequenceCodeForValue(offsets[i], &of_base, &of_bits) != offset_code) return false;
        if (try sequenceCodeForValue(match_lens[i], &ml_base, &ml_bits) != match_code) return false;
    }

    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(allocator);
    _ = try emitSequenceLiteralsSection(allocator, &payload, block, literal_lens, literal_ends, tail_start);
    try emitSequenceCount(allocator, &payload, literal_lens.len);
    try payload.append(allocator, 0x54); // LL, OF, and ML use RLE_Mode.
    try payload.append(allocator, literal_code);
    try payload.append(allocator, offset_code);
    try payload.append(allocator, match_code);

    var fields: [max_bootstrap_sequence_count * 3]BitField = undefined;
    var field_count: usize = 0;
    var i = literal_lens.len;
    while (i > 0) {
        i -= 1;
        fields[field_count] = .{ .value = literal_lens[i] - ll_base[literal_code], .bits = ll_bits[literal_code] };
        field_count += 1;
        fields[field_count] = .{ .value = match_lens[i] - ml_base[match_code], .bits = ml_bits[match_code] };
        field_count += 1;
        fields[field_count] = .{ .value = offsets[i] - of_base[offset_code], .bits = of_bits[offset_code] };
        field_count += 1;
    }
    var sequence_bits: std.ArrayList(u8) = .empty;
    defer sequence_bits.deinit(allocator);
    try emitReverseBitstream(allocator, &sequence_bits, fields[0..field_count]);
    try payload.appendSlice(allocator, sequence_bits.items);

    const raw_block_len = std.math.add(usize, 3, block.len) catch return error.IntegerOverflow;
    if (payload.items.len + 3 >= raw_block_len) return false;
    try emitBlockHeader(allocator, out, 2, payload.items.len, last);
    try out.appendSlice(allocator, payload.items);
    return true;
}

fn emitTablePlanSequenceCompressedBlock(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    last: bool,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
) Error!bool {
    const best = (try bestTablePlanSequence(
        block,
        literal_lens,
        offsets,
        match_lens,
        literal_ends,
        tail_start,
    )) orelse return false;

    return try emitSequenceCompressedBlockWithTablePlans(
        allocator,
        out,
        block,
        last,
        literal_lens,
        offsets,
        match_lens,
        literal_ends,
        tail_start,
        best.plan,
    );
}

fn emitSequenceCompressedBlockWithTablePlans(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    last: bool,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
    plan: SequenceCombinedEmitPlan,
) Error!bool {
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(allocator);
    _ = try emitSequenceLiteralsSection(allocator, &payload, block, literal_lens, literal_ends, tail_start);
    try emitSequenceCount(allocator, &payload, literal_lens.len);
    try payload.append(allocator, sequenceModeByte(plan));
    try appendSequenceTablePayload(allocator, &payload, plan.literal);
    try appendSequenceTablePayload(allocator, &payload, plan.offset);
    try appendSequenceTablePayload(allocator, &payload, plan.match);

    var read_fields: [max_bootstrap_sequence_count * 6]BitField = undefined;
    const read_field_count = try sequenceReadFieldsWithTablePlans(
        read_fields[0..],
        literal_lens,
        offsets,
        match_lens,
        plan,
    );

    var sequence_bits: std.ArrayList(u8) = .empty;
    defer sequence_bits.deinit(allocator);
    try emitReverseBitstreamFromReadOrder(allocator, &sequence_bits, read_fields[0..read_field_count]);
    try payload.appendSlice(allocator, sequence_bits.items);

    const raw_block_len = std.math.add(usize, 3, block.len) catch return error.IntegerOverflow;
    if (payload.items.len + 3 >= raw_block_len) return false;
    try emitBlockHeader(allocator, out, 2, payload.items.len, last);
    try out.appendSlice(allocator, payload.items);
    return true;
}

fn emitMultiSequencePredefinedCompressedBlock(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    last: bool,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
) Error!bool {
    if (literal_lens.len != offsets.len or literal_lens.len != match_lens.len) return false;
    if (literal_lens.len != literal_ends.len) return false;
    if (literal_lens.len == 0 or literal_lens.len > max_bootstrap_sequence_count) return false;

    const literal_plan = (try planPredefinedSequenceValues(literal_lens, &default_ll_symbols, 0)) orelse return false;
    const offset_plan = (try planPredefinedSequenceValues(offsets, &default_of_symbols, 2)) orelse return false;
    const match_plan = (try planPredefinedSequenceValues(match_lens, &default_ml_symbols, 0)) orelse return false;

    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(allocator);
    _ = try emitSequenceLiteralsSection(allocator, &payload, block, literal_lens, literal_ends, tail_start);
    try emitSequenceCount(allocator, &payload, literal_lens.len);
    try payload.append(allocator, 0x00); // LL, OF, and ML all use Predefined_Mode.

    var read_fields: [max_bootstrap_sequence_count * 6]BitField = undefined;
    const read_field_count = try predefinedSequenceReadFields(
        read_fields[0..],
        literal_plan,
        offset_plan,
        match_plan,
    );

    var sequence_bits: std.ArrayList(u8) = .empty;
    defer sequence_bits.deinit(allocator);
    try emitReverseBitstreamFromReadOrder(allocator, &sequence_bits, read_fields[0..read_field_count]);
    try payload.appendSlice(allocator, sequence_bits.items);

    const raw_block_len = std.math.add(usize, 3, block.len) catch return error.IntegerOverflow;
    if (payload.items.len + 3 >= raw_block_len) return false;
    try emitBlockHeader(allocator, out, 2, payload.items.len, last);
    try out.appendSlice(allocator, payload.items);
    return true;
}

const SequenceLiteralsInfo = struct {
    regenerated_len: usize,
    payload_len: usize,
    rle_byte: ?u8 = null,
};

fn emitSequenceLiteralsSection(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    literal_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
) Error!SequenceLiteralsInfo {
    const info = try sequenceLiteralsInfo(block, literal_lens, literal_ends, tail_start);
    if (info.rle_byte) |byte| {
        try emitLiteralsHeader(allocator, out, .rle, info.regenerated_len);
        try out.append(allocator, byte);
        return info;
    }

    if (try emitSequenceHuffmanLiteralsSection(allocator, out, block, literal_lens, literal_ends, tail_start, info)) {
        return info;
    }

    try emitLiteralsHeader(allocator, out, .raw, info.regenerated_len);
    try appendSequenceRawLiterals(allocator, out, block, literal_lens, literal_ends, tail_start);
    return info;
}

fn emitSequenceHuffmanLiteralsSection(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    literal_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
    info: SequenceLiteralsInfo,
) Error!bool {
    if (info.regenerated_len < 64) return false;
    var literals: std.ArrayList(u8) = .empty;
    defer literals.deinit(allocator);
    try literals.ensureTotalCapacity(allocator, info.regenerated_len);
    try appendSequenceRawLiterals(allocator, &literals, block, literal_lens, literal_ends, tail_start);
    if (literals.items.len != info.regenerated_len) return error.CorruptFrame;

    const plan = smallHuffmanLiteralPlan(literals.items) orelse return false;
    var huffman_tree: std.ArrayList(u8) = .empty;
    defer huffman_tree.deinit(allocator);
    if (!try emitSmallHuffmanTree(allocator, &huffman_tree, plan)) return false;

    var compressed: std.ArrayList(u8) = .empty;
    defer compressed.deinit(allocator);
    try emitHuffmanLiteralsSectionWithPlan(allocator, &compressed, literals.items, plan, huffman_tree.items, false);

    const raw_header_len = try literalsHeaderLen(info.regenerated_len);
    const raw_len = std.math.add(usize, raw_header_len, info.payload_len) catch return error.IntegerOverflow;
    if (compressed.items.len >= raw_len) return false;
    try out.appendSlice(allocator, compressed.items);
    return true;
}

fn appendSequenceRawLiterals(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    literal_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
) Error!void {
    if (literal_lens.len != literal_ends.len) return error.CorruptFrame;
    var literal_start: usize = 0;
    for (literal_lens, 0..) |literal_len, i| {
        if (literal_start > block.len or literal_len > block.len - literal_start) return error.CorruptFrame;
        try out.appendSlice(allocator, block[literal_start..][0..literal_len]);
        if (literal_ends[i] < literal_start + literal_len or literal_ends[i] > block.len) return error.CorruptFrame;
        literal_start = literal_ends[i];
    }
    if (tail_start > block.len) return error.CorruptFrame;
    try out.appendSlice(allocator, block[tail_start..]);
}

fn sequenceLiteralsInfo(
    block: []const u8,
    literal_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
) Error!SequenceLiteralsInfo {
    if (literal_lens.len != literal_ends.len) return error.CorruptFrame;
    if (tail_start > block.len) return error.CorruptFrame;
    var info: SequenceLiteralsInfo = .{
        .regenerated_len = block.len - tail_start,
        .payload_len = block.len - tail_start,
    };
    var first_literal_byte: u8 = 0;
    var have_literal_byte = false;
    var all_same = true;

    var literal_start: usize = 0;
    for (literal_lens, 0..) |literal_len, i| {
        if (literal_start > block.len or literal_len > block.len - literal_start) return error.CorruptFrame;
        info.regenerated_len = std.math.add(usize, info.regenerated_len, literal_len) catch return error.IntegerOverflow;
        info.payload_len = info.regenerated_len;
        updateLiteralRunInfo(block[literal_start..][0..literal_len], &first_literal_byte, &have_literal_byte, &all_same);
        if (literal_ends[i] < literal_start + literal_len or literal_ends[i] > block.len) return error.CorruptFrame;
        literal_start = literal_ends[i];
    }
    updateLiteralRunInfo(block[tail_start..], &first_literal_byte, &have_literal_byte, &all_same);

    // Sequence-compressed blocks often carry only a handful of separator or
    // tail literals. When all regenerated literals are the same byte, the
    // standard RLE-literals section avoids storing those bytes repeatedly while
    // keeping the sequence table and match replay unchanged.
    if (info.regenerated_len != 0 and all_same) {
        info.rle_byte = first_literal_byte;
        info.payload_len = 1;
    }
    return info;
}

fn sequenceLiteralsPayloadSectionLen(
    block: []const u8,
    literal_lens: []const usize,
    literal_ends: ?[]const usize,
    tail_start: usize,
) Error!usize {
    const info = try sequenceLiteralsPayloadInfo(block, literal_lens, literal_ends, tail_start);
    var best = std.math.add(usize, try literalsHeaderLen(info.regenerated_len), info.payload_len) catch return error.IntegerOverflow;
    if (literal_ends) |ends| {
        if (try sequenceHuffmanLiteralsSectionLen(block, literal_lens, ends, tail_start, info)) |candidate| {
            if (candidate < best) best = candidate;
        }
    }
    return best;
}

fn sequenceHuffmanLiteralsSectionLen(
    block: []const u8,
    literal_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
    info: SequenceLiteralsInfo,
) Error!?usize {
    if (info.rle_byte != null or info.regenerated_len < 64) return null;
    const plan = smallHuffmanLiteralPlanFromSequence(block, literal_lens, literal_ends, tail_start, info.regenerated_len) orelse return null;
    if (plan.max_symbol > native_max_direct_huffman_symbol) return null;
    const tree_len = 1 + ((@as(usize, plan.max_symbol) + 1) / 2);
    const streams_len = try smallHuffmanLiteralStreamsSerializedLenFromSequence(
        block,
        literal_lens,
        literal_ends,
        tail_start,
        info.regenerated_len,
        plan,
    );
    const compressed_size = std.math.add(usize, tree_len, streams_len) catch return error.IntegerOverflow;
    const header_len = try huffmanLiteralsHeaderLen(info.regenerated_len, compressed_size);
    return std.math.add(usize, header_len, compressed_size) catch return error.IntegerOverflow;
}

fn huffmanLiteralsHeaderLen(regenerated_size: usize, compressed_size: usize) Error!usize {
    if (compressed_size == 0) return error.UnsupportedZstdFeature;
    if (regenerated_size <= 0x3ff and compressed_size <= 0x3ff) return 3;
    if (regenerated_size <= 0x3fff and compressed_size <= 0x3fff) return 4;
    if (regenerated_size <= 0x3ffff and compressed_size <= 0x3ffff) return 5;
    return error.UnsupportedZstdFeature;
}

fn smallHuffmanLiteralPlanFromSequence(
    block: []const u8,
    literal_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
    regenerated_len: usize,
) ?SmallHuffmanLiteralPlan {
    if (regenerated_len < 64 or regenerated_len > 0x3ffff) return null;
    if (literal_lens.len != literal_ends.len) return null;
    var plan: SmallHuffmanLiteralPlan = .{};
    var literal_start: usize = 0;
    for (literal_lens, 0..) |literal_len, i| {
        if (literal_start > block.len or literal_len > block.len - literal_start) return null;
        addBytesToSmallHuffmanLiteralPlan(&plan, block[literal_start..][0..literal_len]) orelse return null;
        if (literal_ends[i] < literal_start + literal_len or literal_ends[i] > block.len) return null;
        literal_start = literal_ends[i];
    }
    if (tail_start > block.len) return null;
    addBytesToSmallHuffmanLiteralPlan(&plan, block[tail_start..]) orelse return null;
    finalizeSmallHuffmanLiteralPlan(&plan) orelse return null;
    return plan;
}

fn addBytesToSmallHuffmanLiteralPlan(plan: *SmallHuffmanLiteralPlan, bytes: []const u8) ?void {
    for (bytes) |byte| {
        if (plan.frequencies[byte] == 0) {
            if (plan.len == plan.symbols.len) return null;
            plan.symbols[plan.len] = byte;
            plan.len += 1;
            plan.max_symbol = @max(plan.max_symbol, byte);
        }
        plan.frequencies[byte] += 1;
    }
}

fn finalizeSmallHuffmanLiteralPlan(plan: *SmallHuffmanLiteralPlan) ?void {
    if (plan.len < 2 or plan.len > plan.symbols.len) return null;
    plan.max_symbol = 0;
    for (plan.symbols[0..plan.len]) |symbol| plan.max_symbol = @max(plan.max_symbol, symbol);
    fillSmallHuffmanWeights(plan) orelse return null;
}

fn smallHuffmanLiteralStreamsSerializedLenFromSequence(
    block: []const u8,
    literal_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
    regenerated_len: usize,
    plan: SmallHuffmanLiteralPlan,
) Error!usize {
    var bit_counts: [4]usize = .{ 0, 0, 0, 0 };
    var literal_index: usize = 0;
    const segment_len = if (regenerated_len <= 1023) regenerated_len else (regenerated_len + 3) / 4;
    var literal_start: usize = 0;
    for (literal_lens, 0..) |literal_len, i| {
        if (literal_start > block.len or literal_len > block.len - literal_start) return error.CorruptFrame;
        try addSmallHuffmanStreamBits(block[literal_start..][0..literal_len], plan, regenerated_len, segment_len, &literal_index, &bit_counts);
        if (literal_ends[i] < literal_start + literal_len or literal_ends[i] > block.len) return error.CorruptFrame;
        literal_start = literal_ends[i];
    }
    if (tail_start > block.len) return error.CorruptFrame;
    try addSmallHuffmanStreamBits(block[tail_start..], plan, regenerated_len, segment_len, &literal_index, &bit_counts);
    if (literal_index != regenerated_len) return error.CorruptFrame;

    if (regenerated_len <= 1023) {
        return (bit_counts[0] + 1 + 7) / 8;
    }

    var len: usize = 6;
    for (bit_counts) |bits| {
        const stream_len = (bits + 1 + 7) / 8;
        if (stream_len > std.math.maxInt(u16)) return error.UnsupportedZstdFeature;
        len = std.math.add(usize, len, stream_len) catch return error.IntegerOverflow;
    }
    return len;
}

fn addSmallHuffmanStreamBits(
    bytes: []const u8,
    plan: SmallHuffmanLiteralPlan,
    regenerated_len: usize,
    segment_len: usize,
    literal_index: *usize,
    bit_counts: *[4]usize,
) Error!void {
    for (bytes) |byte| {
        if (literal_index.* >= regenerated_len) return error.CorruptFrame;
        const stream_index = if (regenerated_len <= 1023)
            0
        else
            @min(literal_index.* / segment_len, 3);
        const bits = smallHuffmanBitCount(plan, byte) orelse return error.CorruptFrame;
        bit_counts[stream_index] = std.math.add(usize, bit_counts[stream_index], bits) catch return error.IntegerOverflow;
        literal_index.* += 1;
    }
}

fn updateLiteralRunInfo(bytes: []const u8, first_literal_byte: *u8, have_literal_byte: *bool, all_same: *bool) void {
    for (bytes) |byte| {
        if (!have_literal_byte.*) {
            first_literal_byte.* = byte;
            have_literal_byte.* = true;
        } else if (byte != first_literal_byte.*) {
            all_same.* = false;
        }
    }
}

fn multiSequencePayloadLen(
    block: []const u8,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    tail_start: usize,
) Error!usize {
    return try multiSequencePayloadLenInternal(block, literal_lens, offsets, match_lens, null, tail_start);
}

fn multiSequencePayloadLenWithLiteralEnds(
    block: []const u8,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
) Error!usize {
    return try multiSequencePayloadLenInternal(block, literal_lens, offsets, match_lens, literal_ends, tail_start);
}

fn bestSequencePayloadLenWithLiteralEnds(
    block: []const u8,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
) Error!usize {
    // Match-finder scoring must use the same RLE/predefined/mixed table choice
    // as the emitter. Otherwise a candidate that encodes smaller with
    // predefined tables (notably single-sequence blocks, which avoid three RLE
    // symbol bytes) or with a mixed table-mode byte can be incorrectly
    // discarded before emitBestSequenceCompressedBlock has a chance to choose
    // the smaller wire representation.
    var best: ?usize = null;
    if (rleSequencePayloadLenForValuesWithLiteralEnds(block, literal_lens, offsets, match_lens, literal_ends, tail_start)) |len| {
        chooseShortestPayloadLen(len, &best);
    } else |err| switch (err) {
        error.CorruptFrame => {},
        else => return err,
    }

    if (multiSequencePayloadLenWithLiteralEnds(block, literal_lens, offsets, match_lens, literal_ends, tail_start)) |len| {
        chooseShortestPayloadLen(len, &best);
    } else |err| switch (err) {
        error.CorruptFrame => {},
        else => return err,
    }

    if (try bestTablePlanSequence(block, literal_lens, offsets, match_lens, literal_ends, tail_start)) |candidate| {
        chooseShortestPayloadLen(candidate.payload_len, &best);
    }

    return best orelse error.CorruptFrame;
}

fn chooseShortestPayloadLen(candidate: usize, best: *?usize) void {
    const current = best.* orelse {
        best.* = candidate;
        return;
    };
    if (candidate < current) best.* = candidate;
}

const SequenceTableKind = enum { literal, offset, match };

const SequenceTableEmitPlan = union(enum) {
    rle: u8,
    predefined: PredefinedSequencePlan,
    compressed: CompressedSequencePlan,
};

const CompressedSequencePlan = struct {
    len: usize = 0,
    accuracy_log: u8 = 0,
    codes: [max_bootstrap_sequence_count]u8 = undefined,
    initial_state: usize = 0,
    next_states: [max_bootstrap_sequence_count]usize = undefined,
    state_bits: [max_bootstrap_sequence_count]u8 = undefined,
    transition_values: [max_bootstrap_sequence_count]usize = undefined,
    transition_bits: [max_bootstrap_sequence_count]u8 = undefined,
    table_payload: [64]u8 = undefined,
    table_payload_len: usize = 0,
};

const SequenceCombinedEmitPlan = struct {
    literal: SequenceTableEmitPlan,
    offset: SequenceTableEmitPlan,
    match: SequenceTableEmitPlan,
};

const SequenceCombinedPlanCandidate = struct {
    plan: SequenceCombinedEmitPlan,
    payload_len: usize,
};

const SequenceTablePlanAlternatives = struct {
    items: [3]SequenceTableEmitPlan = undefined,
    len: usize = 0,

    fn add(self: *SequenceTablePlanAlternatives, plan: SequenceTableEmitPlan) Error!void {
        if (self.len >= self.items.len) return error.CorruptFrame;
        self.items[self.len] = plan;
        self.len += 1;
    }
};

fn bestTablePlanSequence(
    block: []const u8,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
) Error!?SequenceCombinedPlanCandidate {
    if (literal_lens.len != offsets.len or literal_lens.len != match_lens.len) return error.CorruptFrame;
    if (literal_lens.len != literal_ends.len) return error.CorruptFrame;
    if (literal_lens.len == 0 or literal_lens.len > max_bootstrap_sequence_count) return error.CorruptFrame;

    const literal_alternatives = try sequenceTablePlanAlternatives(literal_lens, .literal);
    const offset_alternatives = try offsetSequenceTablePlanAlternatives(literal_lens, offsets);
    const match_alternatives = try sequenceTablePlanAlternatives(match_lens, .match);
    if (literal_alternatives.len == 0 or offset_alternatives.len == 0 or match_alternatives.len == 0) return null;

    var best: ?SequenceCombinedPlanCandidate = null;
    // The bootstrap table families expose only a few alternatives (RLE,
    // predefined, and limited compressed FSE). Trying all combinations keeps the
    // planner exact for this subset and avoids baking in heuristics such as
    // "all-RLE" or "all-predefined" when one family is cheaper in a different
    // mode than the others.
    for (literal_alternatives.items[0..literal_alternatives.len]) |literal_plan| {
        for (offset_alternatives.items[0..offset_alternatives.len]) |offset_plan| {
            for (match_alternatives.items[0..match_alternatives.len]) |match_plan| {
                const combined: SequenceCombinedEmitPlan = .{
                    .literal = literal_plan,
                    .offset = offset_plan,
                    .match = match_plan,
                };
                if (!sequenceCombinedPlanNeedsGenericEmitter(combined)) continue;
                const payload_len = sequencePayloadLenWithTablePlans(
                    block,
                    literal_lens,
                    offsets,
                    match_lens,
                    literal_ends,
                    tail_start,
                    combined,
                ) catch |err| switch (err) {
                    error.CorruptFrame => continue,
                    else => return err,
                };
                if (best == null or payload_len < best.?.payload_len) {
                    best = .{ .plan = combined, .payload_len = payload_len };
                }
            }
        }
    }
    return best;
}

fn sequenceCombinedPlanNeedsGenericEmitter(plan: SequenceCombinedEmitPlan) bool {
    const literal_mode = sequenceTableMode(plan.literal);
    const offset_mode = sequenceTableMode(plan.offset);
    const match_mode = sequenceTableMode(plan.match);
    // All-RLE and all-predefined plans are already handled by dedicated emitters
    // that are cheaper to score directly.  All-compressed plans have no such
    // separate path, so keep them in the generic table-plan search instead of
    // accidentally discarding the only route to LL/OF/ML=FSE blocks.
    if (literal_mode == .rle and offset_mode == .rle and match_mode == .rle) return false;
    if (literal_mode == .predefined and offset_mode == .predefined and match_mode == .predefined) return false;
    return true;
}

fn sequenceTablePlanAlternatives(values: []const usize, kind: SequenceTableKind) Error!SequenceTablePlanAlternatives {
    var alternatives: SequenceTablePlanAlternatives = .{};
    const bases = sequenceTableBases(kind);
    const bits = sequenceTableBits(kind);
    if (try rleSequenceCodeForValues(values, bases, bits)) |code| {
        try alternatives.add(.{ .rle = code });
    }
    if (try planPredefinedSequenceValues(values, sequenceTablePredefinedSymbols(kind), sequenceTablePredefinedMinAdditionalBits(kind))) |plan| {
        try alternatives.add(.{ .predefined = plan });
    }
    if (try planCompressedSequenceValues(values, kind)) |plan| {
        try alternatives.add(.{ .compressed = plan });
    }
    return alternatives;
}

fn offsetSequenceTablePlanAlternatives(literal_lens: []const usize, offsets: []const usize) Error!SequenceTablePlanAlternatives {
    if (literal_lens.len != offsets.len) return error.CorruptFrame;
    var alternatives: SequenceTablePlanAlternatives = .{};
    if (try rleSequenceCodeForValues(offsets, &of_base, &of_bits)) |code| {
        try alternatives.add(.{ .rle = code });
    }
    if (try planPredefinedSequenceValues(offsets, &default_of_symbols, 2)) |plan| {
        try alternatives.add(.{ .predefined = plan });
    }
    if (try planCompressedOffsetSequenceValues(literal_lens, offsets)) |plan| {
        try alternatives.add(.{ .compressed = plan });
    }
    return alternatives;
}

fn rleSequenceCodeForValues(values: []const usize, bases: []const usize, bits: []const u8) Error!?u8 {
    if (values.len == 0) return null;
    const code = sequenceCodeForValue(values[0], bases, bits) catch |err| switch (err) {
        error.CorruptFrame => return null,
        else => return err,
    };
    for (values[1..]) |value| {
        const next_code = sequenceCodeForValue(value, bases, bits) catch |err| switch (err) {
            error.CorruptFrame => return null,
            else => return err,
        };
        if (next_code != code) return null;
    }
    return code;
}

fn planCompressedSequenceValues(values: []const usize, kind: SequenceTableKind) Error!?CompressedSequencePlan {
    if (values.len < min_compressed_sequence_table_count or values.len > max_bootstrap_sequence_count) return null;
    const bases = sequenceTableBases(kind);
    const bits = sequenceTableBits(kind);

    var codes: [max_bootstrap_sequence_count]u8 = undefined;
    for (values, 0..) |value, i| {
        const code = sequenceCodeForValue(value, bases, bits) catch |err| switch (err) {
            error.CorruptFrame => return null,
            else => return err,
        };
        if (code > max_fse_compression_symbol) return null;
        if (kind == .offset and of_bits[code] <= 1) return null;
        codes[i] = code;
    }
    return try planCompressedSequenceCodes(codes[0..values.len]);
}

fn planCompressedOffsetSequenceValues(literal_lens: []const usize, offsets: []const usize) Error!?CompressedSequencePlan {
    if (literal_lens.len != offsets.len) return error.CorruptFrame;
    if (offsets.len < min_compressed_sequence_table_count or offsets.len > max_bootstrap_sequence_count) return null;

    var codes: [max_bootstrap_sequence_count]u8 = undefined;
    var repeated_offsets = initial_repeated_offsets;
    for (offsets, 0..) |offset, i| {
        codes[i] = try chooseOffsetSequenceCode(literal_lens[i], offset, &repeated_offsets);
    }
    return try planCompressedSequenceCodes(codes[0..offsets.len]);
}

fn chooseOffsetSequenceCode(literal_len: usize, offset: usize, repeated_offsets: *[3]usize) Error!u8 {
    // Prefer the dedicated repeat-offset selectors when they describe the
    // requested match distance. Besides using fewer extra bits, this preserves
    // the same repeated-offset history that a normal zstd encoder would expose
    // to later sequences.
    for ([_]u8{ 0, 1 }) |code| {
        const symbol = try sequenceRleSymbol(.offset, code);
        var trial_offsets = repeated_offsets.*;
        _ = sequenceOffsetExtraForEncodedOffset(symbol, literal_len, offset, &trial_offsets) catch |err| switch (err) {
            error.CorruptFrame => continue,
            else => return err,
        };
        repeated_offsets.* = trial_offsets;
        return code;
    }

    const code = try absoluteOffsetSequenceCode(offset);
    var trial_offsets = repeated_offsets.*;
    _ = try sequenceOffsetExtraForEncodedOffset(try sequenceRleSymbol(.offset, code), literal_len, offset, &trial_offsets);
    repeated_offsets.* = trial_offsets;
    return code;
}

fn absoluteOffsetSequenceCode(offset: usize) Error!u8 {
    var best: ?usize = null;
    for (of_base, 0..) |base, code| {
        if (of_bits[code] <= 1) continue;
        if (offset < base) continue;
        const span = @as(usize, 1) << @intCast(of_bits[code]);
        if (offset - base >= span) continue;
        if (best == null or base >= of_base[best.?]) best = code;
    }
    return @intCast(best orelse return error.CorruptFrame);
}

fn planCompressedSequenceCodes(codes: []const u8) Error!?CompressedSequencePlan {
    if (codes.len < min_compressed_sequence_table_count or codes.len > max_bootstrap_sequence_count) return null;

    var plan: CompressedSequencePlan = .{ .len = codes.len, .accuracy_log = 5 };
    var counts: [max_fse_compression_symbol + 1]u32 = .{0} ** (max_fse_compression_symbol + 1);
    var max_code: u8 = 0;
    for (codes, 0..) |code, i| {
        if (code > max_fse_compression_symbol) return null;
        plan.codes[i] = code;
        counts[code] += 1;
        max_code = @max(max_code, code);
    }

    var max_count: u32 = 0;
    var non_zero_count: usize = 0;
    for (counts[0 .. @as(usize, max_code) + 1]) |count| {
        if (count != 0) non_zero_count += 1;
        max_count = @max(max_count, count);
    }
    if (non_zero_count < 2 or non_zero_count > (@as(usize, 1) << @intCast(plan.accuracy_log))) return null;
    // RLE and predefined modes are already cheaper for these degenerate shapes;
    // keep the compressed table candidate for cases with enough repeated code
    // distribution to amortize the normalized-count header.
    if (max_count == codes.len or max_count == 1) return null;

    var normalized: [max_fse_compression_symbol + 1]i16 = .{0} ** (max_fse_compression_symbol + 1);
    normalizeFseCounts(
        counts[0 .. @as(usize, max_code) + 1],
        codes.len,
        plan.accuracy_log,
        normalized[0 .. @as(usize, max_code) + 1],
    ) orelse return null;

    emitFseNormalizedCountFixed(
        &plan.table_payload,
        &plan.table_payload_len,
        normalized[0 .. @as(usize, max_code) + 1],
        max_code,
        plan.accuracy_log,
    ) catch |err| switch (err) {
        error.OutputTooSmall => return null,
        else => return err,
    };
    // A compressed sequence table pays an upfront normalized-count header before
    // it can save state-transition bits. For small bootstrap blocks, reject
    // candidates whose table header alone is no smaller than one byte per
    // sequence; RLE/predefined modes remain available and avoid the FSE setup
    // cost in those cases.
    if (plan.table_payload_len >= codes.len) return null;

    var entries: [max_sequence_fse_table_size]FseTableEntry = undefined;
    const table_len = try buildFseDecodeTableFromNormalized(
        normalized[0 .. @as(usize, max_code) + 1],
        plan.accuracy_log,
        &entries,
    );
    try fillCompressedSequenceTransitions(&plan, entries[0..table_len]);
    return plan;
}

fn buildFseDecodeTableFromNormalized(
    normalized: []const i16,
    table_log: u8,
    entries: *[max_sequence_fse_table_size]FseTableEntry,
) Error!usize {
    const table_len: usize = @as(usize, 1) << @intCast(table_log);
    if (table_len > entries.len) return error.UnsupportedZstdFeature;
    var values: [max_fse_compression_symbol + 1]u16 = undefined;
    if (normalized.len > values.len) return error.UnsupportedZstdFeature;
    for (normalized, 0..) |value, i| {
        if (value < -1) return error.CorruptFrame;
        values[i] = if (value == -1) 0 else @intCast(value + 1);
    }
    try buildFseTable(values[0..normalized.len], entries[0..table_len]);
    return table_len;
}

fn fillCompressedSequenceTransitions(plan: *CompressedSequencePlan, entries: []const FseTableEntry) Error!void {
    if (plan.len == 0) return error.CorruptFrame;
    const last_state = findCompressedSequenceState(entries, plan.codes[plan.len - 1], null) orelse return error.CorruptFrame;
    var next_state = last_state;
    plan.next_states[plan.len - 1] = entries[last_state].baseline;
    plan.state_bits[plan.len - 1] = entries[last_state].bits;

    var i = plan.len - 1;
    while (i > 0) {
        i -= 1;
        const state = findCompressedSequenceState(entries, plan.codes[i], next_state) orelse return error.CorruptFrame;
        const entry = entries[state];
        if (next_state < entry.baseline) return error.CorruptFrame;
        const transition = next_state - entry.baseline;
        if (transition >= (@as(usize, 1) << @intCast(entry.bits))) return error.CorruptFrame;
        plan.transition_values[i] = transition;
        plan.transition_bits[i] = entry.bits;
        plan.next_states[i] = entry.baseline;
        plan.state_bits[i] = entry.bits;
        next_state = state;
    }
    plan.initial_state = next_state;
}

fn findCompressedSequenceState(entries: []const FseTableEntry, code: u8, maybe_next_state: ?usize) ?usize {
    for (entries, 0..) |entry, state| {
        if (entry.symbol != code) continue;
        if (maybe_next_state) |next_state| {
            if (next_state < entry.baseline) continue;
            if (next_state - entry.baseline >= (@as(usize, 1) << @intCast(entry.bits))) continue;
        }
        return state;
    }
    return null;
}

fn sequencePayloadLenWithTablePlans(
    block: []const u8,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    literal_ends: ?[]const usize,
    tail_start: usize,
    plan: SequenceCombinedEmitPlan,
) Error!usize {
    if (literal_lens.len != offsets.len or literal_lens.len != match_lens.len) return error.CorruptFrame;
    if (literal_lens.len == 0 or literal_lens.len > max_bootstrap_sequence_count) return error.CorruptFrame;
    if (literal_ends) |ends| {
        if (ends.len != literal_lens.len) return error.CorruptFrame;
    }

    var len = try sequenceLiteralsPayloadSectionLen(block, literal_lens, literal_ends, tail_start);
    len = std.math.add(usize, len, try sequenceCountLen(literal_lens.len)) catch return error.IntegerOverflow;
    len = std.math.add(usize, len, 1) catch return error.IntegerOverflow; // sequence mode byte
    len = std.math.add(usize, len, sequenceTablePayloadLen(plan.literal)) catch return error.IntegerOverflow;
    len = std.math.add(usize, len, sequenceTablePayloadLen(plan.offset)) catch return error.IntegerOverflow;
    len = std.math.add(usize, len, sequenceTablePayloadLen(plan.match)) catch return error.IntegerOverflow;

    var read_fields: [max_bootstrap_sequence_count * 6]BitField = undefined;
    const read_field_count = try sequenceReadFieldsWithTablePlans(
        read_fields[0..],
        literal_lens,
        offsets,
        match_lens,
        plan,
    );
    var bit_count: usize = 1; // Reverse bitstream end marker.
    for (read_fields[0..read_field_count]) |field| {
        bit_count = std.math.add(usize, bit_count, field.bits) catch return error.IntegerOverflow;
    }
    return std.math.add(usize, len, (bit_count + 7) / 8) catch return error.IntegerOverflow;
}

fn sequenceReadFieldsWithTablePlans(
    out: []BitField,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    plan: SequenceCombinedEmitPlan,
) Error!usize {
    if (literal_lens.len != offsets.len or literal_lens.len != match_lens.len) return error.CorruptFrame;
    if (literal_lens.len == 0 or literal_lens.len > max_bootstrap_sequence_count) return error.CorruptFrame;
    try validateSequenceTablePlanLen(plan.literal, literal_lens.len);
    try validateSequenceTablePlanLen(plan.offset, offsets.len);
    try validateSequenceTablePlanLen(plan.match, match_lens.len);

    var count: usize = 0;
    try appendInitialSequenceStateField(out, &count, plan.literal, .literal);
    try appendInitialSequenceStateField(out, &count, plan.offset, .offset);
    try appendInitialSequenceStateField(out, &count, plan.match, .match);

    var repeated_offsets = initial_repeated_offsets;
    for (0..literal_lens.len) |i| {
        const literal_symbol = try sequenceTableSymbol(plan.literal, .literal, i);
        const offset_symbol = try sequenceTableSymbol(plan.offset, .offset, i);
        const match_symbol = try sequenceTableSymbol(plan.match, .match, i);

        const offset_extra = try sequenceOffsetExtraForEncodedOffset(offset_symbol, literal_lens[i], offsets[i], &repeated_offsets);
        try appendBitField(out, &count, offset_extra, offset_symbol.additional_bits);
        try appendBitField(out, &count, match_lens[i] - match_symbol.base, match_symbol.additional_bits);
        try appendBitField(out, &count, literal_lens[i] - literal_symbol.base, literal_symbol.additional_bits);

        if (i + 1 < literal_lens.len) {
            try appendSequenceTransitionField(out, &count, plan.literal, .literal, i);
            try appendSequenceTransitionField(out, &count, plan.match, .match, i);
            try appendSequenceTransitionField(out, &count, plan.offset, .offset, i);
        }
    }
    return count;
}

fn sequenceOffsetExtraForEncodedOffset(
    symbol: SequenceSymbol,
    literal_len: usize,
    offset: usize,
    repeated_offsets: *[3]usize,
) Error!usize {
    if (symbol.additional_bits > 1) {
        if (offset < symbol.base) return error.CorruptFrame;
        const extra = offset - symbol.base;
        if (extra >= (@as(usize, 1) << @intCast(symbol.additional_bits))) return error.CorruptFrame;
        updateRepeatedOffsets(repeated_offsets, offset);
        return extra;
    }

    const alternatives: usize = @as(usize, 1) << @intCast(symbol.additional_bits);
    var extra: usize = 0;
    while (extra < alternatives) : (extra += 1) {
        var trial_offsets = repeated_offsets.*;
        const resolved = resolveSequenceOffset(
            symbol.base,
            symbol.additional_bits,
            extra,
            literal_len,
            &trial_offsets,
        ) catch |err| switch (err) {
            error.InvalidMatch, error.UnsupportedZstdFeature => continue,
            else => return err,
        };
        if (resolved == offset) {
            repeated_offsets.* = trial_offsets;
            return extra;
        }
    }
    return error.CorruptFrame;
}

fn appendInitialSequenceStateField(out: []BitField, count: *usize, plan: SequenceTableEmitPlan, kind: SequenceTableKind) Error!void {
    switch (plan) {
        .rle => {},
        .predefined => |predefined| {
            if (predefined.len == 0) return error.CorruptFrame;
            try appendBitField(out, count, predefined.states[0], predefinedInitialStateBits(kind));
        },
        .compressed => |compressed| {
            if (compressed.len == 0) return error.CorruptFrame;
            try appendBitField(out, count, compressed.initial_state, compressed.accuracy_log);
        },
    }
}

fn appendSequenceTransitionField(out: []BitField, count: *usize, plan: SequenceTableEmitPlan, kind: SequenceTableKind, index: usize) Error!void {
    switch (plan) {
        .rle => {},
        .predefined => |predefined| {
            if (index + 1 >= predefined.len) return error.CorruptFrame;
            const symbol = try sequenceTableSymbol(plan, kind, index);
            if (predefined.states[index + 1] < symbol.next_state) return error.CorruptFrame;
            try appendBitField(out, count, predefined.states[index + 1] - symbol.next_state, symbol.state_bits);
        },
        .compressed => |compressed| {
            if (index + 1 >= compressed.len) return error.CorruptFrame;
            try appendBitField(out, count, compressed.transition_values[index], compressed.transition_bits[index]);
        },
    }
}

fn validateSequenceTablePlanLen(plan: SequenceTableEmitPlan, len: usize) Error!void {
    switch (plan) {
        .rle => {},
        .predefined => |predefined| if (predefined.len != len) return error.CorruptFrame,
        .compressed => |compressed| if (compressed.len != len) return error.CorruptFrame,
    }
}

fn sequenceTableSymbol(plan: SequenceTableEmitPlan, kind: SequenceTableKind, index: usize) Error!SequenceSymbol {
    return switch (plan) {
        .rle => |code| sequenceRleSymbol(kind, code),
        .predefined => |predefined| blk: {
            if (index >= predefined.len) return error.CorruptFrame;
            const state = predefined.states[index];
            const symbols = sequenceTablePredefinedSymbols(kind);
            if (state >= symbols.len) return error.CorruptFrame;
            break :blk symbols[state];
        },
        .compressed => |compressed| blk: {
            if (index >= compressed.len) return error.CorruptFrame;
            var symbol = try sequenceRleSymbol(kind, compressed.codes[index]);
            symbol.next_state = compressed.next_states[index];
            symbol.state_bits = compressed.state_bits[index];
            break :blk symbol;
        },
    };
}

fn sequenceRleSymbol(kind: SequenceTableKind, code: u8) Error!SequenceSymbol {
    const bases = sequenceTableBases(kind);
    const bits = sequenceTableBits(kind);
    if (code >= bases.len or code >= bits.len) return error.CorruptFrame;
    return .{
        .base = bases[code],
        .additional_bits = bits[code],
        .next_state = 0,
        .state_bits = 0,
    };
}

fn sequenceModeByte(plan: SequenceCombinedEmitPlan) u8 {
    return (@as(u8, @intFromEnum(sequenceTableMode(plan.literal))) << 6) |
        (@as(u8, @intFromEnum(sequenceTableMode(plan.offset))) << 4) |
        (@as(u8, @intFromEnum(sequenceTableMode(plan.match))) << 2);
}

fn sequenceTableMode(plan: SequenceTableEmitPlan) SymbolMode {
    return switch (plan) {
        .rle => .rle,
        .predefined => .predefined,
        .compressed => .compressed,
    };
}

fn appendSequenceTablePayload(allocator: std.mem.Allocator, out: *std.ArrayList(u8), plan: SequenceTableEmitPlan) Error!void {
    switch (plan) {
        .rle => |code| try out.append(allocator, code),
        .predefined => {},
        .compressed => |compressed| try out.appendSlice(allocator, compressed.table_payload[0..compressed.table_payload_len]),
    }
}

fn sequenceTablePayloadLen(plan: SequenceTableEmitPlan) usize {
    return switch (plan) {
        .rle => 1,
        .predefined => 0,
        .compressed => |compressed| compressed.table_payload_len,
    };
}

fn sequenceTableBases(kind: SequenceTableKind) []const usize {
    return switch (kind) {
        .literal => ll_base[0..],
        .offset => of_base[0..],
        .match => ml_base[0..],
    };
}

fn sequenceTableBits(kind: SequenceTableKind) []const u8 {
    return switch (kind) {
        .literal => ll_bits[0..],
        .offset => of_bits[0..],
        .match => ml_bits[0..],
    };
}

fn sequenceTablePredefinedSymbols(kind: SequenceTableKind) []const SequenceSymbol {
    return switch (kind) {
        .literal => default_ll_symbols[0..],
        .offset => default_of_symbols[0..],
        .match => default_ml_symbols[0..],
    };
}

fn sequenceTablePredefinedMinAdditionalBits(kind: SequenceTableKind) u8 {
    return switch (kind) {
        .literal, .match => 0,
        .offset => 2,
    };
}

fn predefinedInitialStateBits(kind: SequenceTableKind) u8 {
    return switch (kind) {
        .literal, .match => 6,
        .offset => 5,
    };
}

fn multiSequencePayloadLenInternal(
    block: []const u8,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    literal_ends: ?[]const usize,
    tail_start: usize,
) Error!usize {
    if (literal_lens.len != offsets.len or literal_lens.len != match_lens.len) return error.CorruptFrame;
    if (literal_lens.len == 0 or literal_lens.len > max_bootstrap_sequence_count) return error.CorruptFrame;
    if (literal_ends) |ends| {
        if (ends.len != literal_lens.len) return error.CorruptFrame;
    }
    const literal_plan = (try planPredefinedSequenceValues(literal_lens, &default_ll_symbols, 0)) orelse return error.CorruptFrame;
    const offset_plan = (try planPredefinedSequenceValues(offsets, &default_of_symbols, 2)) orelse return error.CorruptFrame;
    const match_plan = (try planPredefinedSequenceValues(match_lens, &default_ml_symbols, 0)) orelse return error.CorruptFrame;

    var len = try sequenceLiteralsPayloadSectionLen(block, literal_lens, literal_ends, tail_start);
    len = std.math.add(usize, len, try sequenceCountLen(literal_lens.len)) catch return error.IntegerOverflow;
    len = std.math.add(usize, len, 1) catch return error.IntegerOverflow; // sequence mode byte

    var read_fields: [max_bootstrap_sequence_count * 6]BitField = undefined;
    const read_field_count = try predefinedSequenceReadFields(
        read_fields[0..],
        literal_plan,
        offset_plan,
        match_plan,
    );
    var bit_count: usize = 1; // Reverse bitstream end marker.
    for (read_fields[0..read_field_count]) |field| {
        bit_count = std.math.add(usize, bit_count, field.bits) catch return error.IntegerOverflow;
    }
    const bitstream_len = (bit_count + 7) / 8;
    return std.math.add(usize, len, bitstream_len) catch return error.IntegerOverflow;
}

fn sequenceLiteralsPayloadInfo(
    block: []const u8,
    literal_lens: []const usize,
    literal_ends: ?[]const usize,
    tail_start: usize,
) Error!SequenceLiteralsInfo {
    if (literal_ends) |ends| return try sequenceLiteralsInfo(block, literal_lens, ends, tail_start);

    var regenerated_literals = block.len - tail_start;
    for (literal_lens) |literal_len| {
        regenerated_literals = std.math.add(usize, regenerated_literals, literal_len) catch return error.IntegerOverflow;
    }
    return .{
        .regenerated_len = regenerated_literals,
        .payload_len = regenerated_literals,
    };
}

fn singleRleSequencePayloadLen(
    block: []const u8,
    literal_len: usize,
    offset: usize,
    match_len: usize,
    tail_start: usize,
) Error!usize {
    const literal_lens = [_]usize{literal_len};
    const offsets = [_]usize{offset};
    const match_lens = [_]usize{match_len};
    const literal_ends = [_]usize{tail_start};
    return try rleSequencePayloadLenWithLiteralEnds(
        block,
        &literal_lens,
        &offsets,
        &match_lens,
        &literal_ends,
        tail_start,
        try sequenceCodeForValue(literal_len, &ll_base, &ll_bits),
        try sequenceCodeForValue(offset, &of_base, &of_bits),
        try sequenceCodeForValue(match_len, &ml_base, &ml_bits),
    );
}

fn singleBestSequencePayloadLen(
    block: []const u8,
    literal_len: usize,
    offset: usize,
    match_len: usize,
    tail_start: usize,
) Error!usize {
    const literal_lens = [_]usize{literal_len};
    const offsets = [_]usize{offset};
    const match_lens = [_]usize{match_len};
    const literal_ends = [_]usize{tail_start};
    return try bestSequencePayloadLenWithLiteralEnds(
        block,
        &literal_lens,
        &offsets,
        &match_lens,
        &literal_ends,
        tail_start,
    );
}

fn rleSequencePayloadLen(
    block: []const u8,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    tail_start: usize,
    literal_code: u8,
    offset_code: u8,
    match_code: u8,
) Error!usize {
    return try rleSequencePayloadLenInternal(block, literal_lens, offsets, match_lens, null, tail_start, literal_code, offset_code, match_code);
}

fn rleSequencePayloadLenForValuesWithLiteralEnds(
    block: []const u8,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
) Error!usize {
    if (literal_lens.len == 0 or literal_lens.len != offsets.len or literal_lens.len != match_lens.len) return error.CorruptFrame;
    return try rleSequencePayloadLenWithLiteralEnds(
        block,
        literal_lens,
        offsets,
        match_lens,
        literal_ends,
        tail_start,
        try sequenceCodeForValue(literal_lens[0], &ll_base, &ll_bits),
        try sequenceCodeForValue(offsets[0], &of_base, &of_bits),
        try sequenceCodeForValue(match_lens[0], &ml_base, &ml_bits),
    );
}

fn rleSequencePayloadLenWithLiteralEnds(
    block: []const u8,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    literal_ends: []const usize,
    tail_start: usize,
    literal_code: u8,
    offset_code: u8,
    match_code: u8,
) Error!usize {
    return try rleSequencePayloadLenInternal(block, literal_lens, offsets, match_lens, literal_ends, tail_start, literal_code, offset_code, match_code);
}

fn rleSequencePayloadLenInternal(
    block: []const u8,
    literal_lens: []const usize,
    offsets: []const usize,
    match_lens: []const usize,
    literal_ends: ?[]const usize,
    tail_start: usize,
    literal_code: u8,
    offset_code: u8,
    match_code: u8,
) Error!usize {
    if (literal_lens.len != offsets.len or literal_lens.len != match_lens.len) return error.CorruptFrame;
    if (literal_lens.len == 0 or literal_lens.len > max_bootstrap_sequence_count) return error.CorruptFrame;
    if (literal_ends) |ends| {
        if (ends.len != literal_lens.len) return error.CorruptFrame;
    }

    var bit_count: usize = 1; // Reverse bitstream end marker.
    for (literal_lens, 0..) |literal_len, i| {
        if (try sequenceCodeForValue(literal_len, &ll_base, &ll_bits) != literal_code) return error.CorruptFrame;
        if (try sequenceCodeForValue(offsets[i], &of_base, &of_bits) != offset_code) return error.CorruptFrame;
        if (try sequenceCodeForValue(match_lens[i], &ml_base, &ml_bits) != match_code) return error.CorruptFrame;
        bit_count = std.math.add(usize, bit_count, ll_bits[literal_code]) catch return error.IntegerOverflow;
        bit_count = std.math.add(usize, bit_count, ml_bits[match_code]) catch return error.IntegerOverflow;
        bit_count = std.math.add(usize, bit_count, of_bits[offset_code]) catch return error.IntegerOverflow;
    }

    var len = try sequenceLiteralsPayloadSectionLen(block, literal_lens, literal_ends, tail_start);
    len = std.math.add(usize, len, try sequenceCountLen(literal_lens.len)) catch return error.IntegerOverflow;
    len = std.math.add(usize, len, 1 + 3) catch return error.IntegerOverflow; // modes + three RLE symbol codes.
    return std.math.add(usize, len, (bit_count + 7) / 8) catch return error.IntegerOverflow;
}

fn sequenceCountLen(count: usize) Error!usize {
    if (count == 0) return error.CorruptFrame;
    if (count < 128) return 1;
    if (count < 0x7f00) return 2;
    return 3;
}

const SmallHuffmanLiteralPlan = struct {
    // Direct Huffman tree headers can describe symbols only through
    // `native_max_direct_huffman_symbol`; larger alphabets are serialized with
    // FSE-compressed Huffman weights. Keep the plan itself full-width so the
    // literal bitstream builder and tree re-use logic do not need separate
    // "small direct" and "high-byte FSE" code paths.
    symbols: [256]u8 = undefined,
    weights: [256]u4 = undefined,
    frequencies: [256]u32 = .{0} ** 256,
    len: usize = 0,
    max_symbol: u8 = 0,
    max_bit_count: u4 = 0,
};

fn emitSmallHuffmanLiteralBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, last: bool, state: *LiteralOnlyEncoderState) Error!bool {
    const plan = smallHuffmanLiteralPlan(block) orelse return false;
    if (findRepeatedPatternSegment(block)) |pattern| {
        if (pattern.match_len >= 16) return false;
    }

    const reuse_previous_tree = if (state.previous_huffman_plan) |previous| smallHuffmanPlansEqual(previous, plan) else false;
    var huffman_tree: std.ArrayList(u8) = .empty;
    defer huffman_tree.deinit(allocator);
    if (!reuse_previous_tree and !try emitSmallHuffmanTree(allocator, &huffman_tree, plan)) return false;

    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(allocator);
    try emitHuffmanLiteralsSectionWithPlan(allocator, &payload, block, plan, huffman_tree.items, reuse_previous_tree);
    try payload.append(allocator, 0); // sequence_count=0: this block is literals-only.

    if (payload.items.len >= block.len) return false;
    try emitBlockHeader(allocator, out, 2, payload.items.len, last);
    try out.appendSlice(allocator, payload.items);
    state.previous_huffman_plan = plan;
    return true;
}

const LiteralOnlyEncoderState = struct {
    previous_huffman_plan: ?SmallHuffmanLiteralPlan = null,
};

fn smallHuffmanPlansEqual(a: SmallHuffmanLiteralPlan, b: SmallHuffmanLiteralPlan) bool {
    if (a.len != b.len or a.max_symbol != b.max_symbol or a.max_bit_count != b.max_bit_count) return false;
    return std.mem.eql(u8, a.symbols[0..a.len], b.symbols[0..b.len]) and
        std.mem.eql(u4, a.weights[0..a.len], b.weights[0..b.len]);
}

fn smallHuffmanLiteralPlan(block: []const u8) ?SmallHuffmanLiteralPlan {
    if (block.len < 64 or block.len > 0x3ffff) return null;
    var plan: SmallHuffmanLiteralPlan = .{};
    addBytesToSmallHuffmanLiteralPlan(&plan, block) orelse return null;
    finalizeSmallHuffmanLiteralPlan(&plan) orelse return null;
    return plan;
}

fn fillSmallHuffmanWeights(plan: *SmallHuffmanLiteralPlan) ?void {
    @memset(plan.weights[0..], 0);

    const lengths = huffman.treeCodeLengths(256, &plan.frequencies, 11);
    var max_bit_count: u4 = 0;
    for (plan.symbols[0..plan.len]) |symbol| {
        const bit_count = lengths[symbol];
        if (bit_count == 0) return null;
        max_bit_count = @max(max_bit_count, bit_count);
    }
    plan.max_bit_count = max_bit_count;

    std.mem.sort(u8, plan.symbols[0..plan.len], lengths, smallHuffmanSymbolLess);
    for (plan.symbols[0..plan.len], 0..) |symbol, i| {
        plan.weights[i] = plan.max_bit_count + 1 - lengths[symbol];
    }
    validateSmallHuffmanLastWeight(plan.*) orelse return null;
}

fn smallHuffmanSymbolLess(lengths: [256]u4, lhs: u8, rhs: u8) bool {
    const lhs_bits = lengths[lhs];
    const rhs_bits = lengths[rhs];
    if (lhs_bits != rhs_bits) return lhs_bits > rhs_bits;
    return lhs < rhs;
}

fn validateSmallHuffmanLastWeight(plan: SmallHuffmanLiteralPlan) ?void {
    if (plan.len < 2) return null;
    var weight_power_sum: usize = 0;
    for (plan.symbols[0..plan.len], plan.weights[0..plan.len]) |symbol, weight| {
        if (symbol == plan.max_symbol) continue;
        weight_power_sum += (@as(usize, 1) << @intCast(weight)) >> 1;
    }
    if (weight_power_sum == 0 or weight_power_sum >= (@as(usize, 1) << @intCast(plan.max_bit_count))) return null;
    const remaining = (@as(usize, 1) << @intCast(plan.max_bit_count)) - weight_power_sum;
    if (!std.math.isPowerOfTwo(remaining)) return null;
    const reconstructed: u4 = @intCast(std.math.log2_int(usize, remaining) + 1);
    const max_symbol_index = smallHuffmanSymbolIndex(plan, plan.max_symbol) orelse return null;
    if (reconstructed != plan.weights[max_symbol_index]) return null;
}

fn emitSmallHuffmanTree(allocator: std.mem.Allocator, out: *std.ArrayList(u8), plan: SmallHuffmanLiteralPlan) Error!bool {
    if (plan.max_symbol > native_max_direct_huffman_symbol) {
        return try emitFseHuffmanTree(allocator, out, plan);
    }
    try out.append(allocator, 127 + plan.max_symbol); // direct Huffman weights for symbols 0..max_symbol-1.
    const weights_byte_count: usize = (@as(usize, plan.max_symbol) + 1) / 2;
    for (0..weights_byte_count) |i| {
        const even_symbol: u8 = @intCast(i * 2);
        const odd_symbol: u8 = @intCast(i * 2 + 1);
        const even_weight: u8 = smallHuffmanExplicitWeight(plan, even_symbol);
        const odd_weight: u8 = smallHuffmanExplicitWeight(plan, odd_symbol);
        try out.append(allocator, (even_weight << 4) | odd_weight);
    }
    return true;
}

fn emitHuffmanLiteralsSectionWithPlan(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    literals: []const u8,
    plan: SmallHuffmanLiteralPlan,
    huffman_tree: []const u8,
    reuse_previous_tree: bool,
) Error!void {
    if (literals.len <= 1023) {
        var stream: std.ArrayList(u8) = .empty;
        defer stream.deinit(allocator);
        try emitSmallHuffmanStream(allocator, &stream, literals, plan);
        const compressed_size = huffman_tree.len + stream.items.len;
        try emitHuffmanLiteralsHeader(allocator, out, literals.len, compressed_size, reuse_previous_tree);
        try out.appendSlice(allocator, huffman_tree);
        try out.appendSlice(allocator, stream.items);
    } else {
        var streams: [4]std.ArrayList(u8) = .{ .empty, .empty, .empty, .empty };
        defer for (&streams) |*stream| stream.deinit(allocator);
        // Zstandard four-stream literals split regenerated output with the first
        // three streams covering ceil(size / 4) bytes and the fourth stream
        // covering the remainder. Matching that layout lets the decoder switch
        // streams exactly when each reverse bitstream reaches its end mark,
        // including for non-4-divisible literal counts.
        const segment_len = (literals.len + 3) / 4;
        const segment_1_end = segment_len;
        const segment_2_end = segment_len * 2;
        const segment_3_end = segment_len * 3;
        const segments = [_][]const u8{
            literals[0..segment_1_end],
            literals[segment_1_end..segment_2_end],
            literals[segment_2_end..segment_3_end],
            literals[segment_3_end..],
        };
        for (&streams, segments) |*stream, segment| {
            try emitSmallHuffmanStream(allocator, stream, segment, plan);
        }
        const compressed_size = huffman_tree.len + 6 +
            streams[0].items.len + streams[1].items.len + streams[2].items.len + streams[3].items.len;
        if (streams[0].items.len > std.math.maxInt(u16) or
            streams[1].items.len > std.math.maxInt(u16) or
            streams[2].items.len > std.math.maxInt(u16)) return error.UnsupportedZstdFeature;
        try emitHuffmanLiteralsHeader(allocator, out, literals.len, compressed_size, reuse_previous_tree);
        try out.appendSlice(allocator, huffman_tree);
        var stream_lengths: [6]u8 = undefined;
        std.mem.writeInt(u16, stream_lengths[0..2], @intCast(streams[0].items.len), .little);
        std.mem.writeInt(u16, stream_lengths[2..4], @intCast(streams[1].items.len), .little);
        std.mem.writeInt(u16, stream_lengths[4..6], @intCast(streams[2].items.len), .little);
        try out.appendSlice(allocator, &stream_lengths);
        for (&streams) |*stream| try out.appendSlice(allocator, stream.items);
    }
}

const huffman_weight_fse_table_log = 6;
const huffman_weight_symbol_max = 15;
const max_fse_compression_table_log = 9;
const max_fse_compression_table_size = 1 << max_fse_compression_table_log;
const max_fse_compression_symbol = 63;

const FseCompressionTransform = struct {
    delta_find_state: i32 = 0,
    delta_nb_bits: i32 = 0,
};

const FseCompressionTable = struct {
    state_table: [max_fse_compression_table_size]u16 = undefined,
    transforms: [max_fse_compression_symbol + 1]FseCompressionTransform =
        [_]FseCompressionTransform{.{}} ** (max_fse_compression_symbol + 1),
    table_log: u8 = 0,
    table_len: usize = 0,
    max_symbol: u8 = 0,
};

const ReverseBitstreamWriter = struct {
    accumulator: usize = 0,
    bit_count: u6 = 0,

    fn addBits(self: *ReverseBitstreamWriter, allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: usize, bits: u8) Error!void {
        if (bits == 0) return;
        if (bits > @bitSizeOf(usize)) return error.UnsupportedZstdFeature;
        const mask = (@as(usize, 1) << @intCast(bits)) - 1;
        self.accumulator |= (value & mask) << self.bit_count;
        self.bit_count += @intCast(bits);
        while (self.bit_count >= 8) {
            try out.append(allocator, @truncate(self.accumulator));
            self.accumulator >>= 8;
            self.bit_count -= 8;
        }
    }

    fn finish(self: *ReverseBitstreamWriter, allocator: std.mem.Allocator, out: *std.ArrayList(u8)) Error!void {
        self.accumulator |= @as(usize, 1) << self.bit_count;
        self.bit_count += 1;
        while (self.bit_count > 0) {
            try out.append(allocator, @truncate(self.accumulator));
            if (self.bit_count <= 8) break;
            self.accumulator >>= 8;
            self.bit_count -= 8;
        }
        self.* = .{};
    }
};

fn emitFseHuffmanTree(allocator: std.mem.Allocator, out: *std.ArrayList(u8), plan: SmallHuffmanLiteralPlan) Error!bool {
    if (plan.max_symbol <= native_max_direct_huffman_symbol) return error.CorruptFrame;

    var weights: [255]u8 = undefined;
    // Zstandard does not serialize the final Huffman weight. The decoder
    // reconstructs it from the power sum so that the complete tree exactly
    // fills the next power-of-two prefix space; keeping the highest symbol as
    // that reconstructed entry mirrors the direct-header path above.
    const weight_count: usize = plan.max_symbol;
    for (weights[0..weight_count], 0..) |*weight, symbol| {
        weight.* = smallHuffmanExplicitWeight(plan, @intCast(symbol));
    }

    var compressed: std.ArrayList(u8) = .empty;
    defer compressed.deinit(allocator);
    if (!try emitFseCompressedHuffmanWeights(allocator, &compressed, weights[0..weight_count])) return false;
    if (compressed.items.len == 0 or compressed.items.len > 127) return false;

    try out.append(allocator, @intCast(compressed.items.len));
    try out.appendSlice(allocator, compressed.items);
    return true;
}

fn emitFseCompressedHuffmanWeights(allocator: std.mem.Allocator, out: *std.ArrayList(u8), weights: []const u8) Error!bool {
    if (weights.len <= 2) return false;

    var counts: [huffman_weight_symbol_max + 1]u32 = .{0} ** (huffman_weight_symbol_max + 1);
    var max_symbol: u8 = 0;
    for (weights) |weight| {
        if (weight > huffman_weight_symbol_max) return error.UnsupportedZstdFeature;
        counts[weight] += 1;
        max_symbol = @max(max_symbol, weight);
    }

    var max_count: u32 = 0;
    for (counts[0 .. @as(usize, max_symbol) + 1]) |count| max_count = @max(max_count, count);
    // Match zstd's Huffman-table writer behavior: all-one-symbol and
    // all-unique weight streams are not useful FSE payloads. For high-byte
    // direct-tree overflow we prefer a safe raw-block fallback over emitting a
    // malformed or non-beneficial Huffman tree.
    if (max_count == weights.len or max_count == 1) return false;

    var normalized: [huffman_weight_symbol_max + 1]i16 = .{0} ** (huffman_weight_symbol_max + 1);
    normalizeFseCounts(
        counts[0 .. @as(usize, max_symbol) + 1],
        weights.len,
        huffman_weight_fse_table_log,
        normalized[0 .. @as(usize, max_symbol) + 1],
    ) orelse return false;

    try emitFseNormalizedCount(
        allocator,
        out,
        normalized[0 .. @as(usize, max_symbol) + 1],
        max_symbol,
        huffman_weight_fse_table_log,
    );

    const table = try buildFseCompressionTable(
        normalized[0 .. @as(usize, max_symbol) + 1],
        max_symbol,
        huffman_weight_fse_table_log,
    );
    const bitstream_start = out.items.len;
    try emitFseCompressedSymbols(allocator, out, weights, table);
    return out.items.len > bitstream_start;
}

fn normalizeFseCounts(counts: []const u32, total: usize, table_log: u8, normalized: []i16) ?void {
    if (counts.len != normalized.len or total == 0) return null;
    const table_size: i32 = @as(i32, 1) << @intCast(table_log);

    // This intentionally simple normalizer favors validity and determinism over
    // zstd's exact probability tuning. Every present weight gets at least one
    // state, then the most common or currently-largest symbols absorb rounding
    // error so the probabilities sum exactly to the FSE table size.
    var sum: i32 = 0;
    var largest: usize = 0;
    var largest_count: u32 = 0;
    var non_zero_count: usize = 0;
    for (counts, 0..) |count, symbol| {
        if (count == 0) {
            normalized[symbol] = 0;
            continue;
        }
        non_zero_count += 1;
        if (count > largest_count) {
            largest = symbol;
            largest_count = count;
        }
        const scaled = (@as(u64, count) * @as(u64, @intCast(table_size))) / total;
        const value: i16 = @intCast(@max(@as(u64, 1), scaled));
        normalized[symbol] = value;
        sum += value;
    }
    if (non_zero_count == 0 or non_zero_count > @as(usize, @intCast(table_size))) return null;

    var diff = table_size - sum;
    if (diff > 0) {
        normalized[largest] += @intCast(diff);
    } else {
        while (diff < 0) {
            var reduce: ?usize = null;
            for (normalized, 0..) |value, symbol| {
                if (value <= 1) continue;
                if (reduce == null or value > normalized[reduce.?]) reduce = symbol;
            }
            const symbol = reduce orelse return null;
            normalized[symbol] -= 1;
            diff += 1;
        }
    }
}

fn emitFseNormalizedCount(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    normalized: []const i16,
    max_symbol: u8,
    table_log: u8,
) Error!void {
    if (table_log < 5 or table_log > max_fse_compression_table_log) return error.UnsupportedZstdFeature;
    if (normalized.len != @as(usize, max_symbol) + 1) return error.CorruptFrame;

    // FSE normalized-count headers are a small forward bitstream. This mirrors
    // the zstd wire transform (`count + 1`, threshold-dependent bit width, and
    // compact zero-run coding) so Zig's std decoder can reuse its existing
    // Table.decode path without a Vort-specific side channel.
    var bit_stream: u64 = @as(u64, table_log - 5);
    var bit_count: u8 = 4;
    var remaining: i32 = (@as(i32, 1) << @intCast(table_log)) + 1;
    var threshold: i32 = @as(i32, 1) << @intCast(table_log);
    var nb_bits: u8 = table_log + 1;
    var symbol: usize = 0;
    var previous_is_zero = false;

    while (symbol < normalized.len and remaining > 1) {
        if (previous_is_zero) {
            const start = symbol;
            while (symbol < normalized.len and normalized[symbol] == 0) : (symbol += 1) {}
            if (symbol == normalized.len) return error.CorruptFrame;
            var run_start = start;
            while (symbol >= run_start + 24) {
                run_start += 24;
                bit_stream += @as(u64, 0xffff) << @intCast(bit_count);
                bit_count += 16;
                try flushFseNormalizedCountBits(allocator, out, &bit_stream, &bit_count);
            }
            while (symbol >= run_start + 3) {
                run_start += 3;
                bit_stream += @as(u64, 3) << @intCast(bit_count);
                bit_count += 2;
            }
            bit_stream += @as(u64, @intCast(symbol - run_start)) << @intCast(bit_count);
            bit_count += 2;
            if (bit_count > 16) try flushFseNormalizedCountBits(allocator, out, &bit_stream, &bit_count);
        }

        var count: i32 = normalized[symbol];
        symbol += 1;
        const max = (2 * threshold - 1) - remaining;
        remaining -= @intCast(@abs(count));
        count += 1;
        if (count >= threshold) count += max;
        if (count < 0) return error.CorruptFrame;
        bit_stream += @as(u64, @intCast(count)) << @intCast(bit_count);
        bit_count += nb_bits;
        if (count < max) bit_count -= 1;
        previous_is_zero = count == 1;
        if (remaining < 1) return error.CorruptFrame;
        while (remaining < threshold) {
            nb_bits -= 1;
            threshold >>= 1;
        }
        if (bit_count > 16) try flushFseNormalizedCountBits(allocator, out, &bit_stream, &bit_count);
    }

    if (remaining != 1) return error.CorruptFrame;
    const byte_count = (@as(usize, bit_count) + 7) / 8;
    for (0..byte_count) |_| {
        try out.append(allocator, @truncate(bit_stream));
        bit_stream >>= 8;
    }
}

fn emitFseNormalizedCountFixed(
    out: []u8,
    written: *usize,
    normalized: []const i16,
    max_symbol: u8,
    table_log: u8,
) Error!void {
    if (table_log < 5 or table_log > max_fse_compression_table_log) return error.UnsupportedZstdFeature;
    if (normalized.len != @as(usize, max_symbol) + 1) return error.CorruptFrame;
    written.* = 0;

    var bit_stream: u64 = @as(u64, table_log - 5);
    var bit_count: u8 = 4;
    var remaining: i32 = (@as(i32, 1) << @intCast(table_log)) + 1;
    var threshold: i32 = @as(i32, 1) << @intCast(table_log);
    var nb_bits: u8 = table_log + 1;
    var symbol: usize = 0;
    var previous_is_zero = false;

    while (symbol < normalized.len and remaining > 1) {
        if (previous_is_zero) {
            const start = symbol;
            while (symbol < normalized.len and normalized[symbol] == 0) : (symbol += 1) {}
            if (symbol == normalized.len) return error.CorruptFrame;
            var run_start = start;
            while (symbol >= run_start + 24) {
                run_start += 24;
                bit_stream += @as(u64, 0xffff) << @intCast(bit_count);
                bit_count += 16;
                try flushFseNormalizedCountBitsFixed(out, written, &bit_stream, &bit_count);
            }
            while (symbol >= run_start + 3) {
                run_start += 3;
                bit_stream += @as(u64, 3) << @intCast(bit_count);
                bit_count += 2;
            }
            bit_stream += @as(u64, @intCast(symbol - run_start)) << @intCast(bit_count);
            bit_count += 2;
            if (bit_count > 16) try flushFseNormalizedCountBitsFixed(out, written, &bit_stream, &bit_count);
        }

        var count: i32 = normalized[symbol];
        symbol += 1;
        const max = (2 * threshold - 1) - remaining;
        remaining -= @intCast(@abs(count));
        count += 1;
        if (count >= threshold) count += max;
        if (count < 0) return error.CorruptFrame;
        bit_stream += @as(u64, @intCast(count)) << @intCast(bit_count);
        bit_count += nb_bits;
        if (count < max) bit_count -= 1;
        previous_is_zero = count == 1;
        if (remaining < 1) return error.CorruptFrame;
        while (remaining < threshold) {
            nb_bits -= 1;
            threshold >>= 1;
        }
        if (bit_count > 16) try flushFseNormalizedCountBitsFixed(out, written, &bit_stream, &bit_count);
    }

    if (remaining != 1) return error.CorruptFrame;
    const byte_count = (@as(usize, bit_count) + 7) / 8;
    for (0..byte_count) |_| {
        if (written.* >= out.len) return error.OutputTooSmall;
        out[written.*] = @truncate(bit_stream);
        written.* += 1;
        bit_stream >>= 8;
    }
}

fn flushFseNormalizedCountBits(allocator: std.mem.Allocator, out: *std.ArrayList(u8), bit_stream: *u64, bit_count: *u8) Error!void {
    try out.append(allocator, @truncate(bit_stream.*));
    try out.append(allocator, @truncate(bit_stream.* >> 8));
    bit_stream.* >>= 16;
    bit_count.* -= 16;
}

fn flushFseNormalizedCountBitsFixed(out: []u8, written: *usize, bit_stream: *u64, bit_count: *u8) Error!void {
    if (out.len - written.* < 2) return error.OutputTooSmall;
    out[written.*] = @truncate(bit_stream.*);
    out[written.* + 1] = @truncate(bit_stream.* >> 8);
    written.* += 2;
    bit_stream.* >>= 16;
    bit_count.* -= 16;
}

fn buildFseCompressionTable(normalized: []const i16, max_symbol: u8, table_log: u8) Error!FseCompressionTable {
    if (normalized.len != @as(usize, max_symbol) + 1) return error.CorruptFrame;
    if (table_log > max_fse_compression_table_log or max_symbol > max_fse_compression_symbol) return error.UnsupportedZstdFeature;
    const table_size: usize = @as(usize, 1) << @intCast(table_log);
    const table_mask = table_size - 1;
    const step = (table_size >> 1) + (table_size >> 3) + 3;

    var table: FseCompressionTable = .{
        .table_log = table_log,
        .table_len = table_size,
        .max_symbol = max_symbol,
    };
    var table_symbols: [max_fse_compression_table_size]u8 = undefined;
    var high_threshold: usize = table_size - 1;

    // The compressor table is the inverse of the decode table built earlier in
    // this file: spread symbols with the same step, sort each symbol's states
    // into `state_table`, then derive transforms that decide how many low bits
    // of the current state are emitted before moving to the next state.
    var cumul: [max_fse_compression_symbol + 2]u16 = .{0} ** (max_fse_compression_symbol + 2);
    for (normalized, 0..) |value, i| {
        if (value < -1) return error.CorruptFrame;
        if (value == -1) {
            cumul[i + 1] = cumul[i] + 1;
            table_symbols[high_threshold] = @intCast(i);
            high_threshold -= 1;
        } else {
            cumul[i + 1] = cumul[i] + @as(u16, @intCast(value));
        }
    }

    var position: usize = 0;
    for (normalized, 0..) |value, symbol| {
        if (value <= 0) continue;
        for (0..@as(usize, @intCast(value))) |_| {
            table_symbols[position] = @intCast(symbol);
            position = (position + step) & table_mask;
            while (position > high_threshold) {
                position = (position + step) & table_mask;
            }
        }
    }
    if (position != 0) return error.CorruptFrame;

    var next = cumul;
    for (table_symbols[0..table_size], 0..) |symbol, state| {
        const index = next[symbol];
        if (index >= table_size) return error.CorruptFrame;
        table.state_table[index] = @intCast(table_size + state);
        next[symbol] += 1;
    }

    var total: i32 = 0;
    for (normalized, 0..) |value, symbol| {
        const transform = &table.transforms[symbol];
        switch (value) {
            0 => {
                transform.delta_nb_bits = ((@as(i32, table_log) + 1) << 16) - @as(i32, @intCast(table_size));
            },
            -1, 1 => {
                transform.delta_nb_bits = (@as(i32, table_log) << 16) - @as(i32, @intCast(table_size));
                transform.delta_find_state = total - 1;
                total += 1;
            },
            else => {
                const probability: u32 = @intCast(value);
                const max_bits_out: i32 = @as(i32, table_log) - @as(i32, @intCast(std.math.log2_int(u32, probability - 1)));
                const min_state_plus: i32 = @as(i32, @intCast(probability)) << @intCast(max_bits_out);
                transform.delta_nb_bits = (max_bits_out << 16) - min_state_plus;
                transform.delta_find_state = total - @as(i32, @intCast(probability));
                total += @intCast(probability);
            },
        }
    }
    if (total != table_size) return error.CorruptFrame;
    return table;
}

fn emitFseCompressedSymbols(allocator: std.mem.Allocator, out: *std.ArrayList(u8), symbols: []const u8, table: FseCompressionTable) Error!void {
    if (symbols.len <= 2) return error.UnsupportedZstdFeature;
    var writer: ReverseBitstreamWriter = .{};
    var index = symbols.len;
    var state_1: usize = undefined;
    var state_2: usize = undefined;

    // FSE stores two interleaved states in reverse source order. The last one or
    // two symbols seed the states for free; earlier symbols emit low state bits,
    // and the final two states are flushed into the reverse bitstream so the
    // decoder can recover them before replaying symbols forward.
    if ((symbols.len & 1) != 0) {
        index -= 1;
        state_1 = try fseInitialState(table, symbols[index]);
        index -= 1;
        state_2 = try fseInitialState(table, symbols[index]);
        index -= 1;
        try fseEncodeSymbol(allocator, out, &writer, table, &state_1, symbols[index]);
    } else {
        index -= 1;
        state_2 = try fseInitialState(table, symbols[index]);
        index -= 1;
        state_1 = try fseInitialState(table, symbols[index]);
    }

    var remaining = symbols.len - 2;
    if ((symbols.len & 1) != 0) remaining -= 1;
    if ((remaining & 2) != 0) {
        index -= 1;
        try fseEncodeSymbol(allocator, out, &writer, table, &state_2, symbols[index]);
        index -= 1;
        try fseEncodeSymbol(allocator, out, &writer, table, &state_1, symbols[index]);
        remaining -= 2;
    }

    while (index > 0) {
        index -= 1;
        try fseEncodeSymbol(allocator, out, &writer, table, &state_2, symbols[index]);
        index -= 1;
        try fseEncodeSymbol(allocator, out, &writer, table, &state_1, symbols[index]);
        if (index > 0) {
            index -= 1;
            try fseEncodeSymbol(allocator, out, &writer, table, &state_2, symbols[index]);
            index -= 1;
            try fseEncodeSymbol(allocator, out, &writer, table, &state_1, symbols[index]);
        }
    }

    try writer.addBits(allocator, out, state_2, table.table_log);
    try writer.addBits(allocator, out, state_1, table.table_log);
    try writer.finish(allocator, out);
}

fn fseInitialState(table: FseCompressionTable, symbol: u8) Error!usize {
    if (symbol > table.max_symbol) return error.CorruptFrame;
    const transform = table.transforms[symbol];
    const nb_bits_out: usize = @intCast(@divTrunc(transform.delta_nb_bits + (1 << 15), 1 << 16));
    const value: usize = @intCast((@as(i32, @intCast(nb_bits_out)) << 16) - transform.delta_nb_bits);
    return try fseNextState(table, value, nb_bits_out, transform.delta_find_state);
}

fn fseEncodeSymbol(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    writer: *ReverseBitstreamWriter,
    table: FseCompressionTable,
    state: *usize,
    symbol: u8,
) Error!void {
    if (symbol > table.max_symbol) return error.CorruptFrame;
    const transform = table.transforms[symbol];
    const nb_bits_out: usize = @intCast((@as(i32, @intCast(state.*)) + transform.delta_nb_bits) >> 16);
    try writer.addBits(allocator, out, state.*, @intCast(nb_bits_out));
    state.* = try fseNextState(table, state.* >> @intCast(nb_bits_out), 0, transform.delta_find_state);
}

fn fseNextState(table: FseCompressionTable, value: usize, shift_bits: usize, delta_find_state: i32) Error!usize {
    const shifted = value >> @intCast(shift_bits);
    const signed_index = @as(i32, @intCast(shifted)) + delta_find_state;
    if (signed_index < 0) return error.CorruptFrame;
    const index: usize = @intCast(signed_index);
    if (index >= table.table_len) return error.CorruptFrame;
    return table.state_table[index];
}

fn smallHuffmanExplicitWeight(plan: SmallHuffmanLiteralPlan, symbol: u8) u4 {
    if (symbol == plan.max_symbol) return 0;
    const index = smallHuffmanSymbolIndex(plan, symbol) orelse return 0;
    return plan.weights[index];
}

fn smallHuffmanSymbolIndex(plan: SmallHuffmanLiteralPlan, symbol: u8) ?usize {
    for (plan.symbols[0..plan.len], 0..) |candidate, i| {
        if (candidate == symbol) return i;
    }
    return null;
}

fn smallHuffmanCode(plan: SmallHuffmanLiteralPlan, symbol: u8) ?usize {
    const index = smallHuffmanSymbolIndex(plan, symbol) orelse return null;
    var prefix: usize = 0;
    var previous_weight = plan.weights[0];
    for (0..index) |i| {
        const next_weight = plan.weights[i + 1];
        prefix += 1;
        if (next_weight != previous_weight) {
            prefix = ((prefix - 1) >> @intCast(next_weight - previous_weight)) + 1;
            previous_weight = next_weight;
        }
    }
    return prefix;
}

fn smallHuffmanBitCount(plan: SmallHuffmanLiteralPlan, symbol: u8) ?u8 {
    const index = smallHuffmanSymbolIndex(plan, symbol) orelse return null;
    return plan.max_bit_count + 1 - plan.weights[index];
}

fn emitSmallHuffmanStream(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, plan: SmallHuffmanLiteralPlan) Error!void {
    const lookup = try smallHuffmanLiteralLookup(plan);
    var accumulator: usize = 0;
    var bit_count: u6 = 0;
    var i = block.len;
    while (i > 0) {
        i -= 1;
        const bits = lookup.bit_counts[block[i]];
        if (bits == 0) return error.CorruptFrame;
        const code = lookup.codes[block[i]];
        accumulator |= code << bit_count;
        bit_count += @intCast(bits);
        while (bit_count >= 8) {
            try out.append(allocator, @truncate(accumulator));
            accumulator >>= 8;
            bit_count -= 8;
        }
    }
    accumulator |= @as(usize, 1) << bit_count;
    bit_count += 1;
    while (bit_count > 0) {
        try out.append(allocator, @truncate(accumulator));
        if (bit_count <= 8) break;
        accumulator >>= 8;
        bit_count -= 8;
    }
}

const SmallHuffmanLiteralLookup = struct {
    codes: [256]usize = [_]usize{0} ** 256,
    bit_counts: [256]u8 = [_]u8{0} ** 256,
};

fn smallHuffmanLiteralLookup(plan: SmallHuffmanLiteralPlan) Error!SmallHuffmanLiteralLookup {
    var lookup: SmallHuffmanLiteralLookup = .{};
    for (plan.symbols[0..plan.len]) |symbol| {
        // Encoding walks literals in reverse and consults the code for every
        // byte. Precomputing a dense byte lookup once per block avoids scanning
        // the sorted symbol list for each literal on 4-stream probe payloads.
        lookup.codes[symbol] = smallHuffmanCode(plan, symbol) orelse return error.CorruptFrame;
        lookup.bit_counts[symbol] = smallHuffmanBitCount(plan, symbol) orelse return error.CorruptFrame;
    }
    return lookup;
}

const DuplicateMatch = struct {
    first_start: usize,
    second_start: usize,
    len: usize,
};

const DictionaryMatch = struct {
    dictionary_start: usize,
    block_start: usize,
    len: usize,
};

fn findDictionaryMatch(dictionary: []const u8, block: []const u8, frame_offset: usize) ?DictionaryMatch {
    return findDictionaryMatchIn(dictionary, block, 0, frame_offset);
}

fn findDictionaryMatchIn(dictionary: []const u8, block: []const u8, start_min: usize, frame_offset: usize) ?DictionaryMatch {
    // Keep this first dictionary encoder slice deliberately small and
    // deterministic: it emits dictionary sequences in native blocks, and each
    // sequence may start after caller literals. Offset accounting uses the bytes
    // already emitted in the frame plus the preset history length, matching the
    // decoder's explicit dictionary-history model.
    if (dictionary.len == 0 or block.len < 8 or start_min + 8 > block.len) return null;
    var best: ?DictionaryMatch = null;
    var best_payload_len: usize = std.math.maxInt(usize);
    var block_start = start_min;
    while (block_start + 8 <= block.len) : (block_start += 1) {
        for (dictionary, 0..) |_, dictionary_start| {
            var len: usize = 0;
            while (dictionary_start + len < dictionary.len and
                block_start + len < block.len and
                dictionary[dictionary_start + len] == block[block_start + len]) : (len += 1)
            {}
            if (len >= 8) {
                const candidate: DictionaryMatch = .{ .dictionary_start = dictionary_start, .block_start = block_start, .len = len };
                const candidate_payload_len = dictionaryMatchPayloadLenFrom(block, candidate, start_min, frame_offset, dictionary.len) orelse continue;
                if (candidate_payload_len < best_payload_len or
                    (candidate_payload_len == best_payload_len and len > (best orelse candidate).len))
                {
                    best = candidate;
                    best_payload_len = candidate_payload_len;
                }
            }
        }
    }
    return best;
}

fn dictionaryMatchOffset(dictionary_len: usize, frame_offset: usize, match: DictionaryMatch) Error!usize {
    const dict_distance = dictionary_len - match.dictionary_start;
    const frame_distance = std.math.add(usize, frame_offset, match.block_start) catch return error.IntegerOverflow;
    return std.math.add(usize, dict_distance, frame_distance) catch return error.IntegerOverflow;
}

fn dictionaryMatchPayloadLenFrom(
    block: []const u8,
    match: DictionaryMatch,
    literal_start: usize,
    frame_offset: usize,
    dictionary_len: usize,
) ?usize {
    if (match.block_start < literal_start) return null;
    const literal_len = match.block_start - literal_start;
    const match_offset = dictionaryMatchOffset(dictionary_len, frame_offset, match) catch return null;
    const tail_len = block.len - match.block_start - match.len;
    return singleBestSequencePayloadLen(block, literal_len, match_offset, match.len, block.len - tail_len) catch null;
}

fn findBestDuplicateMatch(block: []const u8) Error!?DuplicateMatch {
    return try findBestDuplicateMatchIn(block, 0);
}

fn findBestDuplicateMatchIn(block: []const u8, start_min: usize) Error!?DuplicateMatch {
    // This intentionally tiny O(n^2) finder is a bootstrap encoder slice, not a
    // production match finder. Cap the search so unusual incompressible blocks do
    // not pay a large planning cost before falling back to raw/RLE output.
    if (block.len < 24 or start_min + 16 > block.len) return null;
    if (block.len > 4096) return try findBestDuplicateMatchHashed(block, start_min);
    var best: ?DuplicateMatch = null;
    var best_payload_len: usize = std.math.maxInt(usize);
    var second: usize = start_min + 1;
    while (second + 8 <= block.len) : (second += 1) {
        var first: usize = start_min;
        while (first < second) : (first += 1) {
            var len: usize = 0;
            while (second + len < block.len and block[first + len] == block[second + len]) : (len += 1) {}
            if (len >= 8) {
                const candidate: DuplicateMatch = .{ .first_start = first, .second_start = second, .len = len };
                if (duplicateMatchCannotBeat(candidate, best)) continue;
                const candidate_payload_len = singleMatchPayloadLenFrom(block, candidate, start_min) catch continue;
                if (candidate_payload_len < best_payload_len or (candidate_payload_len == best_payload_len and len > (best orelse candidate).len)) {
                    best = candidate;
                    best_payload_len = candidate_payload_len;
                }
            }
        }
    }
    return best;
}

fn findBestDuplicateMatchHashed(block: []const u8, start_min: usize) Error!?DuplicateMatch {
    if (block.len > std.math.maxInt(u32)) return null;

    var table: [duplicate_hash_table_len][duplicate_hash_candidates]u32 = undefined;
    for (&table) |*bucket| @memset(bucket[0..], duplicate_hash_invalid);

    var best: ?DuplicateMatch = null;
    var best_payload_len: usize = std.math.maxInt(usize);
    var index = start_min;
    while (index + 8 <= block.len) : (index += 1) {
        const hash = duplicateHash8(block[index..][0..8]);
        const bucket = &table[hash];
        defer {
            var slot: usize = duplicate_hash_candidates - 1;
            while (slot > 0) : (slot -= 1) bucket[slot] = bucket[slot - 1];
            bucket[0] = @intCast(index);
        }

        for (bucket[0..]) |candidate_index| {
            if (candidate_index == duplicate_hash_invalid) continue;
            const candidate_start: usize = @intCast(candidate_index);
            if (candidate_start < start_min or candidate_start >= index) continue;
            if (best) |current_best| {
                if (block.len - index <= current_best.len) continue;
            }

            var len: usize = 0;
            while (index + len < block.len and block[candidate_start + len] == block[index + len]) : (len += 1) {}
            if (len < 8) continue;

            const candidate: DuplicateMatch = .{ .first_start = candidate_start, .second_start = index, .len = len };
            if (duplicateMatchCannotBeat(candidate, best)) continue;
            const candidate_payload_len = singleMatchPayloadLenFrom(block, candidate, start_min) catch continue;
            if (candidate_payload_len < best_payload_len or (candidate_payload_len == best_payload_len and len > (best orelse candidate).len)) {
                best = candidate;
                best_payload_len = candidate_payload_len;
            }
        }
    }
    return best;
}

fn duplicateMatchCannotBeat(candidate: DuplicateMatch, current: ?DuplicateMatch) bool {
    const existing = current orelse return false;
    if (candidate.len < existing.len) return true;
    if (candidate.len > existing.len) return false;

    // Equal-length matches regenerate the same total literal bytes. A later
    // match with an equal-or-larger offset cannot improve the sequence payload:
    // it has a literal length that is at least as large and an offset code that
    // is no cheaper. Skipping these common hash-collision candidates keeps the
    // bootstrap large-block finder bounded on high-entropy Huffman-friendly
    // payloads while preserving closer equal-length matches.
    const candidate_offset = candidate.second_start - candidate.first_start;
    const existing_offset = existing.second_start - existing.first_start;
    return candidate.second_start >= existing.second_start and candidate_offset >= existing_offset;
}

fn duplicateHash8(bytes: *const [8]u8) usize {
    const value = std.mem.readInt(u64, bytes, .little);
    const shift: u6 = @intCast(64 - duplicate_hash_bits);
    return @intCast((value *% 11_400_714_819_323_198_485) >> shift);
}

fn singleMatchPayloadLen(block: []const u8, match: DuplicateMatch) Error!usize {
    return singleMatchPayloadLenFrom(block, match, 0);
}

fn singleMatchPayloadLenFrom(block: []const u8, match: DuplicateMatch, literal_start: usize) Error!usize {
    const literal_len = match.second_start - literal_start;
    const offset = match.second_start - match.first_start;
    return try singleBestSequencePayloadLen(block, literal_len, offset, match.len, match.second_start + match.len);
}

fn repeatedPatternPayloadLenFrom(block: []const u8, segment: RepeatedPatternSegment, literal_start: usize) ?usize {
    if (segment.start < literal_start) return null;
    const literal_len = std.math.add(usize, segment.start - literal_start, segment.period) catch return null;
    const tail_start = std.math.add(usize, segment.start + segment.period, segment.match_len) catch return null;
    return singleBestSequencePayloadLen(block, literal_len, segment.period, segment.match_len, tail_start) catch null;
}

fn emitRepeatedPatternCompressedBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, last: bool) Error!bool {
    if (rleByte(block) != null) return false;
    if (try emitMultiRepeatedPatternCompressedBlock(allocator, out, block, last)) return true;
    const pattern = findRepeatedPatternSegment(block) orelse return false;
    const literal_len = pattern.start + pattern.period;
    const match_len = pattern.match_len;
    if (match_len < 3) return false;
    const tail_start = block.len - pattern.tail_len;
    const literal_lens = [_]usize{literal_len};
    const offsets = [_]usize{pattern.period};
    const match_lens = [_]usize{match_len};
    const literal_ends = [_]usize{tail_start};
    return try emitBestSequenceCompressedBlock(allocator, out, block, last, &literal_lens, &offsets, &match_lens, &literal_ends, tail_start);
}

fn emitMultiRepeatedPatternCompressedBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, last: bool) Error!bool {
    var segments: [max_bootstrap_sequence_count]RepeatedPatternSegment = undefined;
    var literal_lens: [max_bootstrap_sequence_count]usize = undefined;
    var count: usize = 0;
    var search_start: usize = 0;
    while (count < segments.len and search_start < block.len) {
        const segment = findRepeatedPatternSegmentIn(block, search_start, block.len) orelse break;
        if (segment.start - search_start > 16) break;
        const literal_len = std.math.add(usize, segment.start - search_start, segment.period) catch return error.IntegerOverflow;
        const segment_prefix = std.math.add(usize, segment.start, segment.period) catch return error.IntegerOverflow;
        const segment_end = std.math.add(usize, segment_prefix, segment.match_len) catch return error.IntegerOverflow;
        segments[count] = segment;
        literal_lens[count] = literal_len;
        count += 1;
        search_start = segment_end;
        if (segment.tail_len == 0) break;
    }
    if (count < 2) return false;
    var offsets: [max_bootstrap_sequence_count]usize = undefined;
    var match_lens: [max_bootstrap_sequence_count]usize = undefined;
    var literal_ends: [max_bootstrap_sequence_count]usize = undefined;
    for (segments[0..count], 0..) |segment, i| {
        offsets[i] = segment.period;
        match_lens[i] = segment.match_len;
        literal_ends[i] = segment.start + segment.period + segment.match_len;
    }
    return try emitBestSequenceCompressedBlock(
        allocator,
        out,
        block,
        last,
        literal_lens[0..count],
        offsets[0..count],
        match_lens[0..count],
        literal_ends[0..count],
        search_start,
    );
}

fn emitMultiRepeatedPatternPredefinedCompressedBlock(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    last: bool,
    segments: []const RepeatedPatternSegment,
    literal_lens: []const usize,
    tail_start: usize,
) Error!bool {
    if (segments.len != literal_lens.len or segments.len < 2 or segments.len > max_bootstrap_sequence_count) return false;

    var offsets: [max_bootstrap_sequence_count]usize = undefined;
    var match_lens: [max_bootstrap_sequence_count]usize = undefined;
    var literal_ends: [max_bootstrap_sequence_count]usize = undefined;
    for (segments, 0..) |segment, i| {
        offsets[i] = segment.period;
        match_lens[i] = segment.match_len;
        literal_ends[i] = segment.start + segment.period + segment.match_len;
    }
    return try emitMultiSequencePredefinedCompressedBlock(
        allocator,
        out,
        block,
        last,
        literal_lens,
        offsets[0..segments.len],
        match_lens[0..segments.len],
        literal_ends[0..segments.len],
        tail_start,
    );
}

fn emitSequenceCount(allocator: std.mem.Allocator, out: *std.ArrayList(u8), count: usize) Error!void {
    if (count == 0) return error.CorruptFrame;
    if (count < 128) return try out.append(allocator, @intCast(count));
    if (count < 0x7f00) {
        try out.append(allocator, @intCast((count >> 8) + 128));
        try out.append(allocator, @truncate(count));
        return;
    }
    const adjusted = count - 0x7f00;
    try out.append(allocator, 255);
    try out.append(allocator, @truncate(adjusted));
    try out.append(allocator, @truncate(adjusted >> 8));
}

const RepeatedPatternSegment = struct {
    start: usize,
    period: usize,
    match_len: usize,
    tail_len: usize,
};

const BitField = struct {
    value: usize,
    bits: u8,
};

const PredefinedSequencePlan = struct {
    len: usize = 0,
    states: [max_bootstrap_sequence_count]usize = undefined,
    values: [max_bootstrap_sequence_count]usize = undefined,
};

fn planPredefinedSequenceValues(values: []const usize, symbols: []const SequenceSymbol, min_additional_bits: u8) Error!?PredefinedSequencePlan {
    if (values.len == 0 or values.len > max_bootstrap_sequence_count) return null;
    if (symbols.len > max_predefined_sequence_states) return error.UnsupportedZstdFeature;

    var next_choice: [max_bootstrap_sequence_count][max_predefined_sequence_states]usize = undefined;
    for (&next_choice) |*row| @memset(row[0..], max_predefined_sequence_states);

    var viable_next: [max_predefined_sequence_states]bool = undefined;
    @memset(viable_next[0..], false);

    var pos = values.len;
    while (pos > 0) {
        pos -= 1;
        var viable_current: [max_predefined_sequence_states]bool = undefined;
        @memset(viable_current[0..], false);

        for (symbols, 0..) |symbol, state| {
            if (!predefinedSymbolCanEncode(symbol, values[pos], min_additional_bits)) continue;
            if (pos == values.len - 1) {
                viable_current[state] = true;
                continue;
            }

            const transition_count: usize = @as(usize, 1) << @intCast(symbol.state_bits);
            var bits: usize = 0;
            while (bits < transition_count) : (bits += 1) {
                const next_state = symbol.next_state + bits;
                if (next_state >= symbols.len) continue;
                if (!viable_next[next_state]) continue;
                viable_current[state] = true;
                next_choice[pos][state] = next_state;
                break;
            }
        }

        viable_next = viable_current;
    }

    var first_state: ?usize = null;
    for (viable_next[0..symbols.len], 0..) |viable, state| {
        if (viable) {
            first_state = state;
            break;
        }
    }
    const initial_state = first_state orelse return null;

    var plan: PredefinedSequencePlan = .{ .len = values.len };
    @memcpy(plan.values[0..values.len], values);
    plan.states[0] = initial_state;
    for (0..values.len - 1) |i| {
        plan.states[i + 1] = next_choice[i][plan.states[i]];
        if (plan.states[i + 1] >= symbols.len) return null;
    }
    return plan;
}

fn predefinedSymbolCanEncode(symbol: SequenceSymbol, value: usize, min_additional_bits: u8) bool {
    if (symbol.additional_bits < min_additional_bits) return false;
    if (value < symbol.base) return false;
    const span: usize = @as(usize, 1) << @intCast(symbol.additional_bits);
    return value - symbol.base < span;
}

fn predefinedSequenceReadFields(
    out: []BitField,
    literal_plan: PredefinedSequencePlan,
    offset_plan: PredefinedSequencePlan,
    match_plan: PredefinedSequencePlan,
) Error!usize {
    if (literal_plan.len != offset_plan.len or literal_plan.len != match_plan.len) return error.CorruptFrame;
    const needed = 3 + literal_plan.len * 3 + if (literal_plan.len > 1) (literal_plan.len - 1) * 3 else 0;
    if (out.len < needed) return error.OutputTooSmall;

    var count: usize = 0;
    try appendBitField(out, &count, literal_plan.states[0], 6);
    try appendBitField(out, &count, offset_plan.states[0], 5);
    try appendBitField(out, &count, match_plan.states[0], 6);

    for (0..literal_plan.len) |i| {
        const literal_symbol = default_ll_symbols[literal_plan.states[i]];
        const offset_symbol = default_of_symbols[offset_plan.states[i]];
        const match_symbol = default_ml_symbols[match_plan.states[i]];

        try appendBitField(out, &count, offset_plan.values[i] - offset_symbol.base, offset_symbol.additional_bits);
        try appendBitField(out, &count, match_plan.values[i] - match_symbol.base, match_symbol.additional_bits);
        try appendBitField(out, &count, literal_plan.values[i] - literal_symbol.base, literal_symbol.additional_bits);

        if (i + 1 < literal_plan.len) {
            try appendBitField(out, &count, literal_plan.states[i + 1] - literal_symbol.next_state, literal_symbol.state_bits);
            try appendBitField(out, &count, match_plan.states[i + 1] - match_symbol.next_state, match_symbol.state_bits);
            try appendBitField(out, &count, offset_plan.states[i + 1] - offset_symbol.next_state, offset_symbol.state_bits);
        }
    }
    return count;
}

fn appendBitField(out: []BitField, count: *usize, value: usize, bits: u8) Error!void {
    if (count.* >= out.len) return error.OutputTooSmall;
    out[count.*] = .{ .value = value, .bits = bits };
    count.* += 1;
}

fn emitReverseBitstreamFromReadOrder(allocator: std.mem.Allocator, out: *std.ArrayList(u8), read_fields: []const BitField) Error!void {
    var reversed: [max_bootstrap_sequence_count * 6]BitField = undefined;
    if (read_fields.len > reversed.len) return error.OutputTooSmall;
    for (read_fields, 0..) |field, i| {
        reversed[read_fields.len - 1 - i] = field;
    }
    try emitReverseBitstream(allocator, out, reversed[0..read_fields.len]);
}

fn emitReverseBitstream(allocator: std.mem.Allocator, out: *std.ArrayList(u8), fields: []const BitField) Error!void {
    var accumulator: usize = 0;
    var bit_count: u6 = 0;
    for (fields) |field| {
        if (field.bits > @bitSizeOf(usize) or field.value >= (@as(usize, 1) << @intCast(field.bits))) return error.CorruptFrame;
        accumulator |= field.value << bit_count;
        bit_count += @intCast(field.bits);
        while (bit_count >= 8) {
            try out.append(allocator, @truncate(accumulator));
            accumulator >>= 8;
            bit_count -= 8;
        }
    }
    accumulator |= @as(usize, 1) << bit_count;
    bit_count += 1;
    while (bit_count > 0) {
        try out.append(allocator, @truncate(accumulator));
        if (bit_count <= 8) break;
        accumulator >>= 8;
        bit_count -= 8;
    }
}

fn findRepeatedPatternSegment(block: []const u8) ?RepeatedPatternSegment {
    return findRepeatedPatternSegmentIn(block, 0, block.len);
}

fn findRepeatedPatternSegmentIn(block: []const u8, start_min: usize, end: usize) ?RepeatedPatternSegment {
    if (block.len < 8) return null;
    if (start_min >= end or end - start_min < 8) return null;
    const max_start = @min(start_min + repeated_pattern_start_scan, end - 4);
    var best: ?RepeatedPatternSegment = null;
    for (start_min..max_start + 1) |start| {
        if (end - start < 8) break;
        for (2..@min((end - start) / 2, repeated_pattern_period_max) + 1) |period| {
            var i = start + period;
            while (i < end and block[i] == block[start + ((i - start) % period)]) : (i += 1) {}
            const repeated_len = i - start;
            const match_len = repeated_len - period;
            if (match_len < 3) continue;
            const tail_len = end - i;
            const candidate: RepeatedPatternSegment = .{ .start = start, .period = period, .match_len = match_len, .tail_len = tail_len };
            if (best == null or candidate.match_len > best.?.match_len) best = candidate;
        }
    }
    return best;
}

fn sequenceCodeForValue(value: usize, bases: []const usize, bits: []const u8) Error!u8 {
    var best: ?usize = null;
    for (bases, 0..) |base, code| {
        const bit_count = bits[code];
        if (value < base) continue;
        const span = @as(usize, 1) << @intCast(bit_count);
        if (value - base >= span) continue;
        if (best == null or base >= bases[best.?]) best = code;
    }
    return @intCast(best orelse return error.CorruptFrame);
}

fn emitLiteralsHeader(allocator: std.mem.Allocator, out: *std.ArrayList(u8), kind: LiteralsKind, regenerated_size: usize) Error!void {
    _ = try literalsHeaderLen(regenerated_size);
    const kind_bits: u8 = switch (kind) {
        .raw => 0,
        .rle => 1,
        .compressed, .treeless => return error.UnsupportedZstdFeature,
    };
    if (regenerated_size <= 31) {
        try out.append(allocator, kind_bits | @as(u8, @intCast(regenerated_size << 3)));
    } else if (regenerated_size <= 4095) {
        const low: u8 = @intCast(regenerated_size & 0x0f);
        const high: u8 = @intCast(regenerated_size >> 4);
        try out.append(allocator, kind_bits | (1 << 2) | (low << 4));
        try out.append(allocator, high);
    } else {
        const low: u8 = @intCast(regenerated_size & 0x0f);
        const mid: u8 = @intCast((regenerated_size >> 4) & 0xff);
        const high: u8 = @intCast(regenerated_size >> 12);
        try out.append(allocator, kind_bits | (3 << 2) | (low << 4));
        try out.append(allocator, mid);
        try out.append(allocator, high);
    }
}

fn literalsHeaderLen(regenerated_size: usize) Error!usize {
    if (regenerated_size > std.math.maxInt(u20)) return error.IntegerOverflow;
    if (regenerated_size <= 31) return 1;
    if (regenerated_size <= 4095) return 2;
    return 3;
}

fn emitHuffmanLiteralsHeader(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    regenerated_size: usize,
    compressed_size: usize,
    treeless: bool,
) Error!void {
    if (compressed_size == 0) return error.UnsupportedZstdFeature;
    const kind_bits: u8 = if (treeless) 0x03 else 0x02;
    if (regenerated_size <= 0x3ff and compressed_size <= 0x3ff) {
        const value = regenerated_size | (compressed_size << 10);
        try out.append(allocator, kind_bits | (@as(u8, @intCast(value & 0x0f)) << 4));
        try out.append(allocator, @truncate(value >> 4));
        try out.append(allocator, @truncate(value >> 12));
    } else if (regenerated_size <= 0x3fff and compressed_size <= 0x3fff) {
        const value = regenerated_size | (compressed_size << 14);
        try out.append(allocator, kind_bits | (2 << 2) | (@as(u8, @intCast(value & 0x0f)) << 4));
        try out.append(allocator, @truncate(value >> 4));
        try out.append(allocator, @truncate(value >> 12));
        try out.append(allocator, @truncate(value >> 20));
    } else if (regenerated_size <= 0x3ffff and compressed_size <= 0x3ffff) {
        const value = regenerated_size | (compressed_size << 18);
        try out.append(allocator, kind_bits | (3 << 2) | (@as(u8, @intCast(value & 0x0f)) << 4));
        try out.append(allocator, @truncate(value >> 4));
        try out.append(allocator, @truncate(value >> 12));
        try out.append(allocator, @truncate(value >> 20));
        try out.append(allocator, @truncate(value >> 28));
    } else {
        return error.UnsupportedZstdFeature;
    }
}

fn emitCompressedLiteralsHeader(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    regenerated_size: usize,
    compressed_size: usize,
) Error!void {
    return try emitHuffmanLiteralsHeader(allocator, out, regenerated_size, compressed_size, false);
}

fn emitRawBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, last: bool) Error!void {
    try emitBlockHeader(allocator, out, 0, block.len, last);
    try out.appendSlice(allocator, block);
}

fn emitRleBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), byte: u8, len: usize, last: bool) Error!void {
    try emitBlockHeader(allocator, out, 1, len, last);
    try out.append(allocator, byte);
}

fn emitBlockHeader(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block_type: u32, block_len: usize, last: bool) Error!void {
    if (block_len > std.compress.zstd.block_size_max) return error.IntegerOverflow;
    const header_value: u32 = (@as(u32, @intCast(block_len)) << 3) |
        (block_type << 1) |
        @as(u32, if (last) 1 else 0);
    const header: [3]u8 = .{
        @truncate(header_value),
        @truncate(header_value >> 8),
        @truncate(header_value >> 16),
    };
    try out.appendSlice(allocator, &header);
}

fn checkedUsizeToU64(value: usize) Error!u64 {
    return std.math.cast(u64, value) orelse error.IntegerOverflow;
}

fn checkedUsizeToU32(value: usize) Error!u32 {
    return std.math.cast(u32, value) orelse error.IntegerOverflow;
}

fn checkedU64ToUsize(value: u64) Error!usize {
    return std.math.cast(usize, value) orelse error.IntegerOverflow;
}

fn checkedU64ToU32(value: u64) Error!u32 {
    return std.math.cast(u32, value) orelse error.IntegerOverflow;
}

test "zstd lib encoder round trips and compresses repeated payloads" {
    const payload = "zstd payload zstd payload zstd payload zstd payload";
    const encoded = try encodeFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < payload.len);
}

test "zstd lib encoder frame options omit content size" {
    const payload = "zstd lib frame options payload" ** 8;
    const encoded = try encodeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .include_content_size = false,
        .content_checksum = true,
    });
    defer std.testing.allocator.free(encoded);

    try std.testing.expectEqual(zstd_content_size_unknown, ZSTD_getFrameContentSize(@ptrCast(encoded.ptr), encoded.len));

    const decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const default_encoded = try encodeFrameWithLevelAndOptionsAlloc(std.testing.allocator, payload, default_compression_level, .{});
    defer std.testing.allocator.free(default_encoded);
    try std.testing.expectEqual(@as(c_ulonglong, payload.len), ZSTD_getFrameContentSize(@ptrCast(default_encoded.ptr), default_encoded.len));
}

test "zstd lib decoder enforces allocation limits" {
    const payload = "zstd limited decode payload" ** 8;

    const known_size = try encodeFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(known_size);
    try std.testing.expectEqual(payload.len, try decodedFrameSize(known_size));
    try std.testing.expectEqual(payload.len, try decodedFrameSizeLimited(known_size, payload.len));
    try std.testing.expectError(error.OutputLimitExceeded, decodedFrameSizeLimited(known_size, payload.len - 1));
    const known_decoded = try decodeFrameAllocLimited(std.testing.allocator, known_size, payload.len);
    defer std.testing.allocator.free(known_decoded);
    try std.testing.expectEqualSlices(u8, payload, known_decoded);
    try std.testing.expectError(error.OutputLimitExceeded, decodeFrameAllocLimited(std.testing.allocator, known_size, payload.len - 1));
    var known_into_buffer: [payload.len]u8 = undefined;
    const known_written = try decodeFrameInto(known_size, &known_into_buffer);
    try std.testing.expectEqual(payload.len, known_written);
    try std.testing.expectEqualSlices(u8, payload, known_into_buffer[0..known_written]);
    try std.testing.expectError(error.OutputTooSmall, decodeFrameInto(known_size, known_into_buffer[0 .. known_into_buffer.len - 1]));

    const no_size = try encodeFrameWithOptionsAlloc(std.testing.allocator, payload, .{ .include_content_size = false });
    defer std.testing.allocator.free(no_size);
    const no_size_bound = try decodedFrameSize(no_size);
    try std.testing.expect(no_size_bound >= payload.len);
    try std.testing.expectEqual(no_size_bound, try decodedFrameSizeLimited(no_size, no_size_bound));
    try std.testing.expectError(error.OutputLimitExceeded, decodedFrameSizeLimited(no_size, no_size_bound - 1));
    const no_size_decoded = try decodeFrameAllocLimited(std.testing.allocator, no_size, payload.len);
    defer std.testing.allocator.free(no_size_decoded);
    try std.testing.expectEqualSlices(u8, payload, no_size_decoded);
    try std.testing.expectError(error.OutputLimitExceeded, decodeFrameAllocLimited(std.testing.allocator, no_size, payload.len - 1));
    const no_size_into_buffer = try std.testing.allocator.alloc(u8, no_size_bound);
    defer std.testing.allocator.free(no_size_into_buffer);
    const no_size_written = try decodeFrameInto(no_size, no_size_into_buffer);
    try std.testing.expectEqual(payload.len, no_size_written);
    try std.testing.expectEqualSlices(u8, payload, no_size_into_buffer[0..no_size_written]);
    try std.testing.expectError(error.OutputTooSmall, decodeFrameInto(no_size, no_size_into_buffer[0 .. payload.len - 1]));
}

test "zstd raw/RLE frame writer round trips through std decompressor" {
    const payload = "zstd raw block payload zstd raw block payload";
    const encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    const native_decoded = try decodeRawOrRleFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);
    try std.testing.expectEqual(payload.len, try decodedRawOrRleFrameSize(encoded));
    const first_block = try inspectNativeFrameFirstBlock(encoded);
    try std.testing.expectEqual(NativeBlockType.raw, first_block.block_type);
    try std.testing.expectEqual(true, first_block.last);
    try std.testing.expectEqual(payload.len, first_block.payload_len);
    try std.testing.expectEqual((try inspectNativeFrameHeader(encoded)).payload_offset, first_block.header_offset);
    try std.testing.expectEqual(first_block.payload_offset + first_block.payload_len, first_block.next_header_offset);
    const first_block_again = try inspectNativeFrameBlockAt(encoded, first_block.header_offset);
    try std.testing.expectEqual(first_block.next_header_offset, first_block_again.next_header_offset);
    const raw_summary = try summarizeNativeFrameBlocks(encoded);
    try std.testing.expectEqual(@as(usize, 1), raw_summary.block_count);
    try std.testing.expectEqual(@as(usize, 1), raw_summary.raw_block_count);
    try std.testing.expectEqual(payload.len, raw_summary.payload_bytes);
    const raw_stream_summary = try summarizeNativeStream(encoded);
    try std.testing.expectEqual(@as(usize, 1), raw_stream_summary.frame_count);
    try std.testing.expectEqual(@as(usize, 1), raw_stream_summary.block_count);
    try std.testing.expectEqual(payload.len, raw_stream_summary.payload_bytes);
    var block_iterator = try iterateNativeFrameBlocks(encoded);
    var iterated_block_count: usize = 0;
    var iterated_payload_bytes: usize = 0;
    while (try block_iterator.next()) |block| {
        iterated_block_count += 1;
        iterated_payload_bytes += block.payload_len;
        try std.testing.expectEqual(NativeBlockType.raw, block.block_type);
    }
    try std.testing.expectEqual(raw_summary.block_count, iterated_block_count);
    try std.testing.expectEqual(raw_summary.payload_bytes, iterated_payload_bytes);
    try std.testing.expectEqual(encoded.len, block_iterator.next_header_offset);
    try std.testing.expectEqual(@as(?NativeFrameBlockHeader, null), try block_iterator.next());
    var native_appended: std.ArrayList(u8) = .empty;
    defer native_appended.deinit(std.testing.allocator);
    try native_appended.appendSlice(std.testing.allocator, "prefix:");
    const native_appended_written = try decodeNativeFrameAppend(std.testing.allocator, &native_appended, encoded);
    try std.testing.expectEqual(payload.len, native_appended_written);
    try std.testing.expectEqualSlices(u8, "prefix:", native_appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, payload, native_appended.items["prefix:".len..]);
    try std.testing.expectEqual(payload.len, try decodedRawOrRleFrameSizeLimited(encoded, payload.len));
    try std.testing.expectError(error.OutputLimitExceeded, decodedRawOrRleFrameSizeLimited(encoded, payload.len - 1));
    native_appended.clearRetainingCapacity();
    try native_appended.appendSlice(std.testing.allocator, "prefix:");
    const native_appended_limited_written = try decodeNativeFrameAppendLimited(std.testing.allocator, &native_appended, encoded, payload.len);
    try std.testing.expectEqual(payload.len, native_appended_limited_written);
    try std.testing.expectEqualSlices(u8, "prefix:", native_appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, payload, native_appended.items["prefix:".len..]);
    native_appended.clearRetainingCapacity();
    try native_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectError(error.OutputLimitExceeded, decodeNativeFrameAppendLimited(std.testing.allocator, &native_appended, encoded, payload.len - 1));
    try std.testing.expectEqualSlices(u8, "prefix:", native_appended.items);
    var reusable_decoder = NativeFrameDecoder.init(std.testing.allocator);
    defer reusable_decoder.deinit();
    const reusable_decoded = try reusable_decoder.decodeAlloc(encoded);
    defer std.testing.allocator.free(reusable_decoded);
    try std.testing.expectEqualSlices(u8, payload, reusable_decoded);
    const reusable_scratch = try reusable_decoder.decodeScratch(encoded);
    try std.testing.expectEqualSlices(u8, payload, reusable_scratch);
    const reusable_scratch_limited = try reusable_decoder.decodeScratchLimited(encoded, payload.len);
    try std.testing.expectEqualSlices(u8, payload, reusable_scratch_limited);
    try std.testing.expectError(error.OutputLimitExceeded, reusable_decoder.decodeScratchLimited(encoded, payload.len - 1));
    try std.testing.expectEqual(@as(usize, 0), reusable_decoder.scratch.items.len);
    native_appended.clearRetainingCapacity();
    try native_appended.appendSlice(std.testing.allocator, "prefix:");
    const reusable_append_written = try reusable_decoder.decodeAppendLimited(&native_appended, encoded, payload.len);
    try std.testing.expectEqual(payload.len, reusable_append_written);
    try std.testing.expectEqualSlices(u8, payload, native_appended.items["prefix:".len..]);
    var reusable_decode_into: [payload.len]u8 = undefined;
    const reusable_decode_into_written = try reusable_decoder.decodeIntoSlice(encoded, &reusable_decode_into);
    try std.testing.expectEqual(payload.len, reusable_decode_into_written);
    try std.testing.expectEqualSlices(u8, payload, &reusable_decode_into);
    const no_checksum = try encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, payload, .{ .content_checksum = false });
    defer std.testing.allocator.free(no_checksum);
    try std.testing.expectEqual(@as(u8, 0x20), no_checksum[4]);
    const no_checksum_decoded = try decodeNativeFrameAlloc(std.testing.allocator, no_checksum);
    defer std.testing.allocator.free(no_checksum_decoded);
    try std.testing.expectEqualSlices(u8, payload, no_checksum_decoded);
    const no_size = try encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, payload, .{ .include_content_size = false });
    defer std.testing.allocator.free(no_size);
    try std.testing.expectEqual(@as(u8, 0x04), no_size[4]);
    const no_size_decoded = try decodeNativeFrameAlloc(std.testing.allocator, no_size);
    defer std.testing.allocator.free(no_size_decoded);
    try std.testing.expectEqualSlices(u8, payload, no_size_decoded);
    const limited_decoded = try decodeRawOrRleFrameAllocLimited(std.testing.allocator, encoded, payload.len);
    defer std.testing.allocator.free(limited_decoded);
    try std.testing.expectEqualSlices(u8, payload, limited_decoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeRawOrRleFrameAllocLimited(std.testing.allocator, encoded, payload.len - 1),
    );
    var into_buffer: [payload.len]u8 = undefined;
    const into_written = try decodeRawOrRleFrameInto(encoded, &into_buffer);
    try std.testing.expectEqual(payload.len, into_written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..into_written]);
    try std.testing.expectError(error.OutputTooSmall, decodeRawOrRleFrameInto(encoded, into_buffer[0 .. into_buffer.len - 1]));
    const raw_bound = try encodedNativeFrameBoundWithOptions(payload.len, .{ .selection = .raw_or_rle });
    const raw_into = try std.testing.allocator.alloc(u8, raw_bound);
    defer std.testing.allocator.free(raw_into);
    const raw_into_written = try encodeRawOrRleFrameIntoSlice(std.testing.allocator, payload, .{}, raw_into);
    try std.testing.expectEqualSlices(u8, encoded, raw_into[0..raw_into_written]);
    try std.testing.expectError(error.OutputTooSmall, encodeRawOrRleFrameIntoSlice(std.testing.allocator, payload, .{}, raw_into[0 .. raw_into_written - 1]));
    try std.testing.expectEqual(@as(u8, 0x24), encoded[4]);
    try std.testing.expectEqual(@as(u8, payload.len), encoded[5]);

    const repeated = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    const rle_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, repeated);
    defer std.testing.allocator.free(rle_encoded);
    try std.testing.expect(rle_encoded.len < repeated.len);
    var rle_block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(rle_encoded, &rle_block_offset);
    const first_block_header = std.mem.readInt(u24, rle_encoded[rle_block_offset..][0..3], .little);
    try std.testing.expectEqual(@as(u24, 1), (first_block_header >> 1) & 0x3);
    const rle_decoded = try decodeFrameAlloc(std.testing.allocator, rle_encoded);
    defer std.testing.allocator.free(rle_decoded);
    try std.testing.expectEqualSlices(u8, repeated, rle_decoded);
    const native_rle_decoded = try decodeRawOrRleFrameAlloc(std.testing.allocator, rle_encoded);
    defer std.testing.allocator.free(native_rle_decoded);
    try std.testing.expectEqualSlices(u8, repeated, native_rle_decoded);
    const rle_first_block = try inspectNativeFrameFirstBlock(rle_encoded);
    try std.testing.expectEqual(NativeBlockType.rle, rle_first_block.block_type);
    try std.testing.expectEqual(repeated.len, rle_first_block.payload_len);
    try std.testing.expectEqual(true, rle_first_block.last);
    try std.testing.expectEqual(rle_first_block.payload_offset + 1, rle_first_block.next_header_offset);
    const rle_summary = try summarizeNativeFrameBlocks(rle_encoded);
    try std.testing.expectEqual(@as(usize, 1), rle_summary.block_count);
    try std.testing.expectEqual(@as(usize, 1), rle_summary.rle_block_count);
    try std.testing.expectEqual(repeated.len, rle_summary.payload_bytes);
    var rle_into_buffer: [repeated.len]u8 = undefined;
    const rle_into_written = try decodeNativeFrameInto(rle_encoded, &rle_into_buffer);
    try std.testing.expectEqual(repeated.len, rle_into_written);
    try std.testing.expectEqualSlices(u8, repeated, rle_into_buffer[0..rle_into_written]);
}

test "zstd raw/RLE native decoder handles skippable and concatenated frames" {
    const first = try encodeRawOrRleFrameAlloc(std.testing.allocator, "first");
    defer std.testing.allocator.free(first);
    const second = try encodeRawOrRleFrameAlloc(std.testing.allocator, "second");
    defer std.testing.allocator.free(second);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    var skippable_header: [8]u8 = undefined;
    std.mem.writeInt(u32, skippable_header[0..4], skippable_magic_min + 3, .little);
    std.mem.writeInt(u32, skippable_header[4..8], 5, .little);
    try stream.appendSlice(std.testing.allocator, &skippable_header);
    try stream.appendSlice(std.testing.allocator, "noise");
    try stream.appendSlice(std.testing.allocator, second);

    const decoded = try decodeRawOrRleFrameAlloc(std.testing.allocator, stream.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "firstsecond", decoded);
    const stream_summary = try summarizeNativeStream(stream.items);
    try std.testing.expectEqual(@as(usize, 2), stream_summary.frame_count);
    try std.testing.expectEqual(@as(usize, 1), stream_summary.skippable_frame_count);
    try std.testing.expectEqual(@as(usize, 5), stream_summary.skippable_payload_bytes);
    var stream_iterator = iterateNativeStream(stream.items);
    const first_element = (try stream_iterator.next()) orelse return error.CorruptFrame;
    switch (first_element) {
        .frame => |frame| {
            try std.testing.expectEqual(@as(usize, 0), frame.offset);
            try std.testing.expectEqualSlices(u8, first, frame.bytes);
            var first_blocks = try frame.blockIterator();
            var first_block_count: usize = 0;
            while (try first_blocks.next()) |_| first_block_count += 1;
            try std.testing.expectEqual((try summarizeNativeFrameBlocks(first)).block_count, first_block_count);
        },
        .skippable => return error.CorruptFrame,
    }
    const skip_element = (try stream_iterator.next()) orelse return error.CorruptFrame;
    switch (skip_element) {
        .frame => return error.CorruptFrame,
        .skippable => |skippable| {
            try std.testing.expectEqual(first.len, skippable.offset);
            try std.testing.expectEqualSlices(u8, "noise", skippable.payload);
            try std.testing.expectEqual(@as(u4, 3), skippable.header.skippable_id);
        },
    }
    const second_element = (try stream_iterator.next()) orelse return error.CorruptFrame;
    switch (second_element) {
        .frame => |frame| {
            try std.testing.expectEqual(first.len + 8 + 5, frame.offset);
            try std.testing.expectEqualSlices(u8, second, frame.bytes);
        },
        .skippable => return error.CorruptFrame,
    }
    try std.testing.expect((try stream_iterator.next()) == null);
    const native_concatenated = try decodeNativeConcatenatedFrameAlloc(std.testing.allocator, stream.items);
    defer std.testing.allocator.free(native_concatenated);
    try std.testing.expectEqualSlices(u8, "firstsecond", native_concatenated);
    const native_concatenated_exact = try decodeNativeConcatenatedFrameAllocExactSize(std.testing.allocator, stream.items, "firstsecond".len);
    defer std.testing.allocator.free(native_concatenated_exact);
    try std.testing.expectEqualSlices(u8, "firstsecond", native_concatenated_exact);
    try std.testing.expectError(error.SizeMismatch, decodeNativeConcatenatedFrameAllocExactSize(std.testing.allocator, stream.items, "firstsecond".len - 1));
    try std.testing.expectEqual(@as(usize, "firstsecond".len), try decodedNativeConcatenatedFrameSize(stream.items));
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    const appended_written = try decodeRawOrRleFrameAppend(std.testing.allocator, &appended, stream.items);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), appended_written);
    try std.testing.expectEqualSlices(u8, "prefix:firstsecond", appended.items);
    appended.clearRetainingCapacity();
    try appended.appendSlice(std.testing.allocator, "prefix:");
    const appended_limited_written = try decodeRawOrRleFrameAppendLimited(std.testing.allocator, &appended, stream.items, "firstsecond".len);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), appended_limited_written);
    try std.testing.expectEqualSlices(u8, "prefix:firstsecond", appended.items);
    appended.clearRetainingCapacity();
    try appended.appendSlice(std.testing.allocator, "prefix:");
    const native_appended_limited_written = try decodeNativeConcatenatedFrameAppendLimited(std.testing.allocator, &appended, stream.items, "firstsecond".len);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), native_appended_limited_written);
    try std.testing.expectEqualSlices(u8, "prefix:firstsecond", appended.items);
    appended.clearRetainingCapacity();
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectError(error.OutputLimitExceeded, decodeRawOrRleFrameAppendLimited(std.testing.allocator, &appended, stream.items, "firstsecond".len - 1));
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items);

    var into_buffer: ["firstsecond".len]u8 = undefined;
    const written = try decodeRawOrRleFrameInto(stream.items, &into_buffer);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), written);
    try std.testing.expectEqualSlices(u8, "firstsecond", into_buffer[0..written]);
    @memset(&into_buffer, 0);
    const native_written = try decodeNativeConcatenatedFrameInto(stream.items, &into_buffer);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), native_written);
    try std.testing.expectEqualSlices(u8, "firstsecond", into_buffer[0..native_written]);
    const exact_written = try decodeNativeConcatenatedFrameIntoExactSize(stream.items, &into_buffer, "firstsecond".len);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), exact_written);
    try std.testing.expectEqualSlices(u8, "firstsecond", into_buffer[0..exact_written]);
    try std.testing.expectError(error.OutputTooSmall, decodeNativeConcatenatedFrameIntoExactSize(stream.items, into_buffer[0 .. into_buffer.len - 1], "firstsecond".len));
    try std.testing.expectError(error.SizeMismatch, decodeNativeConcatenatedFrameIntoExactSize(stream.items, &into_buffer, "firstsecond".len - 1));
    var oversized_into: ["firstsecond".len + 1]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, decodeNativeConcatenatedFrameIntoExactSize(stream.items, &oversized_into, "firstsecond".len + 1));
    var reusable = NativeFrameDecoder.init(std.testing.allocator);
    defer reusable.deinit();
    const reusable_decoded = try reusable.decodeConcatenatedScratch(stream.items);
    try std.testing.expectEqualSlices(u8, "firstsecond", reusable_decoded);
    const reusable_exact_written = try reusable.decodeConcatenatedIntoSliceExactSize(stream.items, &into_buffer, "firstsecond".len);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), reusable_exact_written);
}

test "zstd skippable frame writer composes with native streams" {
    const first = try encodeRawOrRleFrameAlloc(std.testing.allocator, "first");
    defer std.testing.allocator.free(first);
    const skip = try encodeSkippableFrameAlloc(std.testing.allocator, 9, "metadata");
    defer std.testing.allocator.free(skip);
    const second = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, "second");
    defer std.testing.allocator.free(second);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    try stream.appendSlice(std.testing.allocator, skip);
    try stream.appendSlice(std.testing.allocator, second);

    try std.testing.expectEqual(skippable_magic_min + 9, std.mem.readInt(u32, skip[0..4], .little));
    try std.testing.expectEqual(@as(u32, "metadata".len), std.mem.readInt(u32, skip[4..8], .little));
    try std.testing.expectEqualSlices(u8, "metadata", skip[8..]);
    const skip_header = try inspectNativeSkippableFrame(skip);
    try std.testing.expectEqual(@as(u4, 9), skip_header.skippable_id);
    try std.testing.expectEqual(@as(usize, 8), skip_header.payload_offset);
    try std.testing.expectEqual(@as(usize, "metadata".len), skip_header.payload_len);
    try std.testing.expectEqual(skip.len, skip_header.next_frame_offset);
    try std.testing.expectEqual(skip.len, try encodedSkippableFrameBound("metadata".len));
    var skip_appended: std.ArrayList(u8) = .empty;
    defer skip_appended.deinit(std.testing.allocator);
    try encodeSkippableFrameAppend(std.testing.allocator, &skip_appended, 9, "metadata");
    try std.testing.expectEqualSlices(u8, skip, skip_appended.items);
    var skip_into: [8 + "metadata".len]u8 = undefined;
    const skip_into_written = try encodeSkippableFrameIntoSlice(9, "metadata", &skip_into);
    try std.testing.expectEqual(skip.len, skip_into_written);
    try std.testing.expectEqualSlices(u8, skip, skip_into[0..skip_into_written]);
    try std.testing.expectError(error.OutputTooSmall, encodeSkippableFrameIntoSlice(9, "metadata", skip_into[0 .. skip_into.len - 1]));

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, stream.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "firstsecond", decoded);
}

test "zstd raw/RLE native decoder accepts no-size raw frames" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try frame.appendSlice(std.testing.allocator, &frame_magic);
    try frame.append(std.testing.allocator, 0x00); // no checksum, no content size, window descriptor follows
    try frame.append(std.testing.allocator, 0x00); // 1 KiB window, enough for the small raw block
    try emitRawBlock(std.testing.allocator, &frame, "abc", true);

    const decoded = try decodeRawOrRleFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abc", decoded);

    var into_buffer: [3]u8 = undefined;
    const written = try decodeRawOrRleFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(@as(usize, 3), written);
    try std.testing.expectEqualSlices(u8, "abc", into_buffer[0..written]);
}

test "zstd native decoder accepts descriptor unused bit" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try frame.appendSlice(std.testing.allocator, &frame_magic);
    try frame.append(std.testing.allocator, 0x10); // unused descriptor bit set; no content size, window descriptor follows.
    try frame.append(std.testing.allocator, 0x00);
    try emitRawBlock(std.testing.allocator, &frame, "abc", true);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, "abc", std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abc", decoded);

    const header = try inspectNativeFrameHeader(frame.items);
    try std.testing.expectEqual(@as(?u64, null), header.content_size);
    try std.testing.expectEqual(@as(u64, 1024), header.window_size);
}

test "zstd native no-size writer chooses valid window descriptors" {
    const cases = [_]struct {
        len: usize,
        expected_descriptor: u8,
    }{
        .{ .len = 0, .expected_descriptor = 0x00 },
        .{ .len = 1024, .expected_descriptor = 0x00 },
        .{ .len = 1025, .expected_descriptor = 0x01 },
        .{ .len = 1152, .expected_descriptor = 0x01 },
        .{ .len = 2048, .expected_descriptor = 0x08 },
        .{ .len = 4096, .expected_descriptor = 0x10 },
        .{ .len = 128 * 1024, .expected_descriptor = 0x38 },
        .{ .len = 132 * 1024, .expected_descriptor = 0x39 },
    };

    for (cases) |case| {
        const payload = try std.testing.allocator.alloc(u8, case.len);
        defer std.testing.allocator.free(payload);
        @memset(payload, 'w');

        const encoded = try encodeRawOrRleFrameWithOptionsAlloc(
            std.testing.allocator,
            payload,
            .{ .include_content_size = false, .content_checksum = false },
        );
        defer std.testing.allocator.free(encoded);
        try std.testing.expectEqual(@as(u8, 0x00), encoded[4]);
        try std.testing.expectEqual(case.expected_descriptor, encoded[5]);

        const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }

    const multi_block_payload = try std.testing.allocator.alloc(u8, std.compress.zstd.block_size_max + 4096);
    defer std.testing.allocator.free(multi_block_payload);
    @memset(multi_block_payload, 'm');
    const multi_block = try encodeRawOrRleFrameWithOptionsAlloc(
        std.testing.allocator,
        multi_block_payload,
        .{ .include_content_size = false, .content_checksum = false },
    );
    defer std.testing.allocator.free(multi_block);
    try std.testing.expectEqual(@as(u8, 0x00), multi_block[4]);
    try std.testing.expectEqual(@as(u8, 0x39), multi_block[5]);
    const first_block_header = std.mem.readInt(u24, multi_block[6..][0..3], .little);
    try std.testing.expectEqual(@as(u24, std.compress.zstd.block_size_max), first_block_header >> 3);
    try std.testing.expectEqual(false, (first_block_header & 1) != 0);
    const decoded_multi = try decodeNativeFrameAlloc(std.testing.allocator, multi_block);
    defer std.testing.allocator.free(decoded_multi);
    try std.testing.expectEqualSlices(u8, multi_block_payload, decoded_multi);

    const small_block_payload = "0123456789abcdef" ** 8;
    const small_block = try encodeRawOrRleFrameWithOptionsAlloc(
        std.testing.allocator,
        small_block_payload,
        .{ .content_checksum = false, .block_size_max = 32 },
    );
    defer std.testing.allocator.free(small_block);
    try std.testing.expect(small_block.len <= try encodedNativeFrameBoundWithOptions(small_block_payload.len, .{ .content_checksum = false, .block_size_max = 32 }));
    var small_block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(small_block, &small_block_offset);
    const small_first_header = std.mem.readInt(u24, small_block[small_block_offset..][0..3], .little);
    try std.testing.expectEqual(@as(u24, 32), small_first_header >> 3);
    try std.testing.expectEqual(false, (small_first_header & 1) != 0);
    const small_decoded = try decodeNativeFrameAlloc(std.testing.allocator, small_block);
    defer std.testing.allocator.free(small_decoded);
    try std.testing.expectEqualSlices(u8, small_block_payload, small_decoded);
    try std.testing.expectError(error.InvalidBlockPlan, encodedNativeFrameBoundWithOptions(1, .{ .block_size_max = 0 }));
    try std.testing.expectError(error.InvalidBlockPlan, encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, "x", .{ .block_size_max = std.compress.zstd.block_size_max + 1 }));
    try std.testing.expectError(error.InvalidBlockPlan, encodedNativeFrameBoundWithOptions(1, .{ .match_search_budget = mixed_match_path_search_budget + 1 }));
    try std.testing.expectError(error.InvalidBlockPlan, encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, "x", .{ .match_search_budget = mixed_match_path_search_budget + 1 }));
}

test "zstd native decoder accepts literal-only compressed blocks" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, 4, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 3, true);
    try frame.append(std.testing.allocator, (4 << 3) | 1); // RLE literals, one-byte size field, regenerated size=4
    try frame.append(std.testing.allocator, 'z');
    try frame.append(std.testing.allocator, 0); // sequence_count=0, so the block is literals-only
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, "zzzz")), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, "zzzz", std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, "zzzz", native_decoded);

    var into_buffer: [4]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(@as(usize, 4), written);
    try std.testing.expectEqualSlices(u8, "zzzz", into_buffer[0..written]);

    const limited = try decodeNativeFrameAllocLimited(std.testing.allocator, frame.items, 4);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, "zzzz", limited);
    try std.testing.expectError(error.OutputLimitExceeded, decodeNativeFrameAllocLimited(std.testing.allocator, frame.items, 3));
}

test "zstd native decoder accepts extended zero sequence counts" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, 5, .{ .content_checksum = false });
    try emitBlockHeader(std.testing.allocator, &frame, 2, 4, true);
    try frame.append(std.testing.allocator, (5 << 3) | 1); // RLE literals, regenerated size=5.
    try frame.append(std.testing.allocator, 'z');
    try frame.appendSlice(std.testing.allocator, &.{ 0x80, 0x00 }); // two-byte encoding of sequence_count=0.

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, "zzzzz", native_decoded);

    var into_buffer: [5]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(@as(usize, 5), written);
    try std.testing.expectEqualSlices(u8, "zzzzz", into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(@as(usize, 5), decoded_len);
}

test "zstd native decoder accepts RLE sequence compressed blocks" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, 14, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1); // RLE literals: one literal byte seeds the repeated match.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1); // one sequence.
    try frame.append(std.testing.allocator, 0x54); // LL, offset, and ML all use RLE_Mode.
    try frame.appendSlice(std.testing.allocator, &.{ 1, 0, 10 }); // literal_len=1, repeated offset code 0, match_len=13.
    try frame.append(std.testing.allocator, 1); // Minimal reverse bitstream end mark; RLE modes need no payload bits.
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, "aaaaaaaaaaaaaa")), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, "aaaaaaaaaaaaaa", std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, "aaaaaaaaaaaaaa", native_decoded);

    var into_buffer: [14]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(@as(usize, 14), written);
    try std.testing.expectEqualSlices(u8, "aaaaaaaaaaaaaa", into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(@as(usize, 14), decoded_len);
    try std.testing.expectError(error.OutputLimitExceeded, decodeNativeFrameAllocLimited(std.testing.allocator, frame.items, 13));
}

test "zstd native decoder reads RLE sequence additional bits" {
    const payload = "a" ** 37;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1); // RLE literals: one literal byte seeds the repeated match.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1); // one sequence.
    try frame.append(std.testing.allocator, 0x54); // LL, offset, and ML all use RLE_Mode.
    try frame.appendSlice(std.testing.allocator, &.{ 1, 0, 32 }); // ML code 32 has one additional bit over base length 35.
    try frame.append(std.testing.allocator, 0x03); // Reverse bitstream: payload bit=1 followed by the end mark.
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);
}

test "zstd native decoder repeats RLE sequence tables across compressed blocks" {
    const payload = "a" ** 8;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});

    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, false);
    try frame.append(std.testing.allocator, (1 << 3) | 1); // RLE literals: one literal byte seeds the match.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1); // one sequence.
    try frame.append(std.testing.allocator, 0x54); // LL, offset, and ML all use RLE_Mode.
    try frame.appendSlice(std.testing.allocator, &.{ 1, 0, 0 }); // literal_len=1, repeated offset code 0, match_len=3.
    try frame.append(std.testing.allocator, 1); // Minimal reverse bitstream end mark.

    try emitBlockHeader(std.testing.allocator, &frame, 2, 5, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1);
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1);
    try frame.append(std.testing.allocator, 0xfc); // Repeat_Mode for all sequence tables; no table payload follows.
    try frame.append(std.testing.allocator, 1);

    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(payload.len, decoded_len);

    var first_block_repeat: std.ArrayList(u8) = .empty;
    defer first_block_repeat.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &first_block_repeat, 4, .{ .content_checksum = false });
    try emitBlockHeader(std.testing.allocator, &first_block_repeat, 2, 5, true);
    try first_block_repeat.append(std.testing.allocator, (1 << 3) | 1);
    try first_block_repeat.append(std.testing.allocator, 'a');
    try first_block_repeat.append(std.testing.allocator, 1);
    try first_block_repeat.append(std.testing.allocator, 0xfc);
    try first_block_repeat.append(std.testing.allocator, 1);
    try std.testing.expectError(error.CorruptFrame, decodeNativeFrameAlloc(std.testing.allocator, first_block_repeat.items));
}

test "zstd native decoder reads RLE offset additional bits" {
    const payload = "a" ** 14;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1); // RLE literals: one byte of history is enough for offset=1.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1);
    try frame.append(std.testing.allocator, 0x54); // LL, offset, and ML all use RLE_Mode.
    try frame.appendSlice(std.testing.allocator, &.{ 1, 2, 10 }); // Offset code 2 consumes two additional bits.
    try frame.append(std.testing.allocator, 0x04); // Reverse bitstream: offset extra bits=0, then end mark.
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);
}

test "zstd native decoder accepts multiple RLE sequences" {
    const payload = "a" ** 8;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, true);
    try frame.append(std.testing.allocator, (2 << 3) | 1); // Two regenerated RLE literals; each sequence consumes one.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 2); // two sequences using the same RLE-coded symbol values.
    try frame.append(std.testing.allocator, 0x54); // LL, offset, and ML all use RLE_Mode.
    try frame.appendSlice(std.testing.allocator, &.{ 1, 0, 0 }); // literal_len=1, repeated offset code 0, match_len=3.
    try frame.append(std.testing.allocator, 1);
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(payload.len, decoded_len);
}

test "zstd native decoder accepts minimal predefined sequence block" {
    const payload = "a" ** 132;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1); // RLE literals: one literal byte before the match.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1); // one sequence.
    try frame.append(std.testing.allocator, 0); // LL, offset, and ML all use Predefined_Mode.
    // Reverse bitstream layout: LL state=2, OF state=0, ML state=20, then
    // seven zero ML extra bits and the end mark. This is intentionally the
    // smallest predefined-table slice Vort recognizes before full FSE support.
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x0a, 0x08, 0x01 });
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(payload.len, decoded_len);
}

test "zstd native decoder accepts multiple predefined sequences" {
    const payload = "a" ** 18;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 9, true);
    try frame.append(std.testing.allocator, (2 << 3) | 1); // RLE literals: both sequences consume one literal.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 2);
    try frame.append(std.testing.allocator, 0); // LL, offset, and ML all use Predefined_Mode.
    // Initial states decode to literal_len=1, offset=1, match_len=3. The state
    // update bits then select another literal_len=1, offset=1, and match_len=13
    // for the second sequence. This keeps the fixture small while exercising
    // predefined-table state transitions in the native decoder.
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x60, 0x07, 0x10, 0x02 });
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(payload.len, decoded_len);
}

test "zstd native sequence reader updates repeated offsets across positive selectors" {
    var sequence_bits: std.ArrayList(u8) = .empty;
    defer sequence_bits.deinit(std.testing.allocator);
    const read_fields = [_]BitField{
        .{ .value = 0, .bits = 1 }, // second sequence: OF code 1 extra bit selects positive-literal rep1.
        .{ .value = 1, .bits = 1 }, // third sequence: OF code 1 extra bit selects positive-literal rep2.
    };
    try emitReverseBitstreamFromReadOrder(std.testing.allocator, &sequence_bits, &read_fields);

    var state = try initSequenceDecodeState(.{
        .ll_mode = .rle,
        .of_mode = .rle,
        .ml_mode = .rle,
        .literal_rle = .{ .base = 1, .additional_bits = 0, .next_state = 0, .state_bits = 0 },
        .offset_rle = .{ .base = 0, .additional_bits = 0, .next_state = 0, .state_bits = 0 },
        .match_rle = .{ .base = 3, .additional_bits = 0, .next_state = 0, .state_bits = 0 },
        .bitstream_offset = 0,
    }, 3, try ReverseBitReader.init(sequence_bits.items), initial_repeated_offsets);

    const first = try readModeSequence(&state);
    try std.testing.expectEqual(@as(usize, 1), first.literal_len);
    try std.testing.expectEqual(@as(usize, 1), first.match_offset);
    try std.testing.expectEqual([3]usize{ 1, 4, 8 }, state.repeated_offsets);

    state.spec.offset_rle = .{ .base = 1, .additional_bits = 1, .next_state = 0, .state_bits = 0 };
    const second = try readModeSequence(&state);
    try std.testing.expectEqual(@as(usize, 1), second.literal_len);
    try std.testing.expectEqual(@as(usize, 4), second.match_offset);
    try std.testing.expectEqual([3]usize{ 4, 1, 8 }, state.repeated_offsets);

    const third = try readModeSequence(&state);
    try std.testing.expectEqual(@as(usize, 1), third.literal_len);
    try std.testing.expectEqual(@as(usize, 8), third.match_offset);
    try std.testing.expectEqual([3]usize{ 8, 4, 1 }, state.repeated_offsets);
}

test "zstd native sequence reader applies compressed offset selectors" {
    var sequence_bits: std.ArrayList(u8) = .empty;
    defer sequence_bits.deinit(std.testing.allocator);
    const read_fields = [_]BitField{
        .{ .value = 0, .bits = 1 }, // initial compressed-FSE offset state: entry 0.
        .{ .value = 0, .bits = 1 }, // first sequence: OF code 1 extra bit selects positive-literal rep1.
        .{ .value = 1, .bits = 1 }, // transition to the second compressed-FSE offset table entry.
        .{ .value = 1, .bits = 1 }, // second sequence: OF code 1 extra bit selects positive-literal rep2.
    };
    try emitReverseBitstreamFromReadOrder(std.testing.allocator, &sequence_bits, &read_fields);

    var offset_fse: SequenceFseTable = .{
        .len = 2,
        .accuracy_log = 1,
    };
    offset_fse.entries[0] = .{
        .base = 1,
        .additional_bits = 1,
        .next_state = 0,
        .state_bits = 1,
    };
    offset_fse.entries[1] = .{
        .base = 1,
        .additional_bits = 1,
        .next_state = 0,
        .state_bits = 0,
    };

    var state = try initSequenceDecodeState(.{
        .ll_mode = .rle,
        .of_mode = .compressed,
        .ml_mode = .rle,
        .literal_rle = .{ .base = 1, .additional_bits = 0, .next_state = 0, .state_bits = 0 },
        .offset_rle = null,
        .offset_fse = offset_fse,
        .match_rle = .{ .base = 3, .additional_bits = 0, .next_state = 0, .state_bits = 0 },
        .bitstream_offset = 0,
    }, 2, try ReverseBitReader.init(sequence_bits.items), initial_repeated_offsets);
    try std.testing.expectEqual(@as(usize, 0), state.of_state);

    const first = try readModeSequence(&state);
    try std.testing.expectEqual(@as(usize, 1), first.literal_len);
    try std.testing.expectEqual(@as(usize, 4), first.match_offset);
    try std.testing.expectEqual([3]usize{ 4, 1, 8 }, state.repeated_offsets);
    try std.testing.expectEqual(@as(usize, 1), state.of_state);

    const second = try readModeSequence(&state);
    try std.testing.expectEqual(@as(usize, 1), second.literal_len);
    try std.testing.expectEqual(@as(usize, 8), second.match_offset);
    try std.testing.expectEqual([3]usize{ 8, 4, 1 }, state.repeated_offsets);
}

test "zstd native decoder streams several predefined sequences" {
    const payload = "a" ** 30;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 14, true);
    try frame.append(std.testing.allocator, (5 << 3) | 1); // Five regenerated RLE literals feed five sequences.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 5);
    try frame.append(std.testing.allocator, 0); // LL, offset, and ML all use Predefined_Mode.
    // Repeats the small LL state cycle 2 -> 44 -> 23 -> 2 while keeping OF/ML
    // states simple. The decoder now streams sequences directly into the
    // output/preflight paths instead of materializing a scratch sequence list.
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x60, 0x00, 0x10, 0x00, 0x1c, 0x00, 0xd8, 0x01, 0x84 });
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(payload.len, decoded_len);
}

test "zstd native decoder accepts mixed RLE and predefined sequence modes" {
    const payload = "a" ** 132;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1); // RLE literals: one literal byte before the match.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1);
    try frame.append(std.testing.allocator, 0x50); // LL and offset use RLE_Mode; ML uses Predefined_Mode.
    try frame.appendSlice(std.testing.allocator, &.{ 1, 0 }); // literal_len=1, repeated offset code 0.
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x2a }); // ML predefined state 20 plus seven zero extra bits.
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(payload.len, decoded_len);
}

test "zstd native decoder repeats mixed sequence tables across compressed blocks" {
    const payload = "a" ** 264;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{ .content_checksum = false });

    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, false);
    try frame.append(std.testing.allocator, (1 << 3) | 1);
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1);
    try frame.append(std.testing.allocator, 0x50); // LL/OF are RLE tables; ML uses the default predefined table.
    try frame.appendSlice(std.testing.allocator, &.{ 1, 0 });
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x2a });

    try emitBlockHeader(std.testing.allocator, &frame, 2, 6, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1);
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1);
    try frame.append(std.testing.allocator, 0xfc); // Repeat_Mode for LL, OF, and ML.
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x2a });

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(payload.len, decoded_len);
}

test "zstd literal-only compressed block rejects malformed sections" {
    var non_zero_sequences: std.ArrayList(u8) = .empty;
    defer non_zero_sequences.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &non_zero_sequences, 3, .{});
    try emitBlockHeader(std.testing.allocator, &non_zero_sequences, 2, 6, true);
    try non_zero_sequences.append(std.testing.allocator, 3 << 3);
    try non_zero_sequences.appendSlice(std.testing.allocator, "abc");
    try non_zero_sequences.appendSlice(std.testing.allocator, &.{ 1, 0x40 }); // one sequence, unsupported mixed mode byte
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, "abc")), .little);
    try non_zero_sequences.appendSlice(std.testing.allocator, &checksum);
    try std.testing.expectError(error.TruncatedFrame, decodeNativeFrameAlloc(std.testing.allocator, non_zero_sequences.items));

    var trailing_literal_payload: std.ArrayList(u8) = .empty;
    defer trailing_literal_payload.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &trailing_literal_payload, 3, .{});
    try emitBlockHeader(std.testing.allocator, &trailing_literal_payload, 2, 6, true);
    try trailing_literal_payload.append(std.testing.allocator, 3 << 3);
    try trailing_literal_payload.appendSlice(std.testing.allocator, "abcd");
    try trailing_literal_payload.append(std.testing.allocator, 0);
    try trailing_literal_payload.appendSlice(std.testing.allocator, &checksum);
    try std.testing.expectError(error.TruncatedFrame, decodeNativeFrameAlloc(std.testing.allocator, trailing_literal_payload.items));

    var missing_literal_byte: std.ArrayList(u8) = .empty;
    defer missing_literal_byte.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &missing_literal_byte, 3, .{});
    try emitBlockHeader(std.testing.allocator, &missing_literal_byte, 2, 2, true);
    try missing_literal_byte.append(std.testing.allocator, (3 << 3) | 1); // RLE literals need one payload byte.
    try missing_literal_byte.append(std.testing.allocator, 0);
    try missing_literal_byte.appendSlice(std.testing.allocator, &checksum);
    try std.testing.expectError(error.TruncatedFrame, decodeNativeFrameAlloc(std.testing.allocator, missing_literal_byte.items));
}

test "zstd native decoder rejects malformed Huffman literals" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, 3, .{ .content_checksum = false });
    try emitBlockHeader(std.testing.allocator, &frame, 2, 4, true);
    try frame.appendSlice(std.testing.allocator, &.{ 0x32, 0x40, 0x00 }); // compressed literals: regenerated=3, compressed=1.
    try frame.append(std.testing.allocator, 1);
    try std.testing.expectError(error.TruncatedFrame, decodeNativeFrameAlloc(std.testing.allocator, frame.items));
    var output: [3]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeNativeFrameInto(frame.items, &output));
    try std.testing.expectError(error.TruncatedFrame, decodedRawOrRleFrameSize(frame.items));

    var zero_size: std.ArrayList(u8) = .empty;
    defer zero_size.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &zero_size, 3, .{ .content_checksum = false });
    try emitBlockHeader(std.testing.allocator, &zero_size, 2, 3, true);
    try zero_size.appendSlice(std.testing.allocator, &.{ 0x32, 0x00, 0x00 });
    try std.testing.expectError(error.CorruptFrame, decodeNativeFrameAlloc(std.testing.allocator, zero_size.items));

    var treeless_first: std.ArrayList(u8) = .empty;
    defer treeless_first.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &treeless_first, 3, .{ .content_checksum = false });
    try emitBlockHeader(std.testing.allocator, &treeless_first, 2, 4, true);
    try treeless_first.appendSlice(std.testing.allocator, &.{ 0x33, 0x40, 0x00 }); // treeless literals before any Huffman tree.
    try treeless_first.append(std.testing.allocator, 1);
    try std.testing.expectError(error.CorruptFrame, decodeNativeFrameAlloc(std.testing.allocator, treeless_first.items));
}

test "zstd native decoder accepts single-stream Huffman literals" {
    const unit = "{\"key\":\"value\",\"number\":123,\"array\":[1,2,3],\"text\":\"abcdefg\"}\n";
    const payload = unit ** 100;
    const frame_hex =
        "28b52ffd04680d0200e2c30d1290cf016c3325f0fdb0cddd2ce10b3339ce4e20b" ++
        "fb1a5123a279f76cdb7192d3a14f27ba43cef2102b95c08d2f8fea2efd493d" ++
        "fe58e0301007e7f411fa095c60c5d";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, &frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(&frame, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const limited = try decodeNativeFrameAllocLimited(std.testing.allocator, &frame, payload.len);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, payload, limited);
    try std.testing.expectError(error.OutputLimitExceeded, decodeNativeFrameAllocLimited(std.testing.allocator, &frame, payload.len - 1));

    const decoded_len = try decodedRawOrRleFrameSize(&frame);
    try std.testing.expectEqual(payload.len, decoded_len);
}

test "zstd native decoder accepts four-stream Huffman literals" {
    const unit = "{\"key\":\"value\",\"number\":123,\"array\":[1,2,3],\"text\":\"abcdefg\"}\n";
    const payload = unit ** 4;
    const frame_hex =
        "28b52ffd20f86d0500864f2a1290cf016c3325f0fdb0cddd2ce10b3339ce4e" ++
        "24002400240020bfb1a5123a279f76cdb7192d3a14f27ba43cef2102b95c" ++
        "08d2f8fea2efd493dfe58e0320bfb1a5123a279f76cdb7192d3a14f27b" ++
        "a43cef2102b95c08d2f8fea2efd493dfe58e0320bfb1a5123a279f76cdb" ++
        "7192d3a14f27ba43cef2102b95c08d2f8fea2efd493dfe58e0320bfb1a5" ++
        "123a279f76cdb7192d3a14f27ba43cef2102b95c08d2f8fea2efd493dfe" ++
        "58e0300";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, &frame);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, &frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(&frame, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(&frame);
    try std.testing.expectEqual(payload.len, decoded_len);
}

test "zstd native decoder parses system high-byte Huffman tree" {
    const tree_hex =
        "3710657a2b5cbc991677a0b3d956ae1aa76ac132b29a169ab2abdcef38e438a8e62e6e" ++
        "8751108babaaaaaaaaaaaaaaaaaaaaaaaaaaaa6a82";
    var tree_bytes: [tree_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&tree_bytes, tree_hex);

    var reader: std.Io.Reader = .fixed(&tree_bytes);
    var remaining: std.Io.Limit = .limited(tree_bytes.len);
    const tree = try decodeStdZstdHuffmanTree(&reader, &remaining);
    try std.testing.expectEqual(tree_bytes.len, reader.seek);
    try std.testing.expectEqual(@as(u4, 9), tree.max_bit_count);
    try std.testing.expectEqual(@as(usize, 127), @as(usize, tree.symbol_count_minus_one) + 1);
    try std.testing.expectEqual(@as(u8, 132), tree.nodes[0].symbol);
    try std.testing.expectEqual(@as(u4, 1), tree.nodes[0].weight);
    try std.testing.expectEqual(@as(u16, 0), tree.nodes[0].prefix);
    try std.testing.expectEqual(@as(u8, 238), tree.nodes[tree.symbol_count_minus_one].symbol);
    try std.testing.expectEqual(@as(u4, 4), tree.nodes[tree.symbol_count_minus_one].weight);
    try std.testing.expectEqual(@as(u16, 63), tree.nodes[tree.symbol_count_minus_one].prefix);
}

test "zstd native decoder accepts system high-byte Huffman frame" {
    const frame_hex =
        "28b52ffd0448ed1d000a40e00e3710657a2b5cbc991677a0b3d956ae1aa76ac132b29a169ab2abdcef38e438a8e62e6e" ++
        "8751108babaaaaaaaaaaaaaaaaaaaaaaaaaaaa6a82dc00e000de00011a743a1b53265298afc9b6d511eafdfb11ac9293" ++
        "d0a14a7d96cfc230b3638a7f4757b96b3ed48f2acb7273acc6da4c10cf84205edc146a7a1c1bc141241bd97a36d22568" ++
        "380c714546867cc708e570de39de1db351a366494d0f9d38f490b315c5d4a34f6c766be69968bb2c59c5abce2efb74bc" ++
        "cb27ab382acc19c65f061ec2cbe58ecc4553faade7073b6320ac17eddf5b354bc699e63d8db571afead1cb2f16c8e096" ++
        "4488f1f614d1e8066f0317df5d9bd7acfb0817a1f15a72d6be3cb2c119b23ea5ac04fe28276cee1b0b1a2cc17df71e5d" ++
        "4cb78eea4f478f955b74db1d753b45cfb08268b64e9504461ede5e7385c25b172089072e49910b621506561f489fe4f9" ++
        "0353a562c7e0e3b0d4af63e4863a34d0e114eb22782b1168692c0619d1fd651aac1db620bf1c9ef6c0f7e18b67b6f617" ++
        "6734ea0dbeb070c13361764b5fab4d8ac7bfb34840aa720c98387f4d82131a342c2ea2c8e8d68ac02874a0d3e9329225" ++
        "6c3d3b0e9e4532652c8ceec784fda47e3e045084440bd43c813675c2df2512355054a1860d651b6c14ccf3fa0c87866a" ++
        "ee3e3a731a6544894f41740e870787c027e512e0bd4179eebe236accf708f05c2c848acdce16737a237cf37cde43dcc4" ++
        "eba704bd5a68c7f581e3792a1278f5e170a9a4a149621ce618a3b494661285fded5440f63bf9e18204a68ea29bfc8db0" ++
        "414d2172ad6adbc64c4e42fa4c0b17a3d0f2243d3371ab8e150238fc9122120fe39072b35d9ade6f7bc97a616be63698" ++
        "9e6951479016ef60848f19035ad0b73717af6b7485f548c38384e9b18c6f2e512564c9bc9ad793eb133b95bb05da2fed" ++
        "c7590f1539aaa271377c878b4c4d23c0b012e31f0f70b93673d46b354e0f5e1b6cb35c3d79e232c73b9ddc82ce1ee201" ++
        "034739a9859916f7cbc7354d000814fd0d2be85e1f05a83e0f7b5494184fe522d8444d7aba093d5404f4395e5350e724" ++
        "252b6742d92e63e0031b03749b955abe8af13f96e68297ad70a0b75403c251e69fd28141a7cb427915a185fe3ebba658" ++
        "0aad3b3687ec0e0223872ab2889fc31bb119d025a8e76b75c7cb19adce204e061144d64cb1dc245d7c2aedc57c5b6fe2" ++
        "c563fcd13cb11d4384924d007e926ecf14f454bd17851fc900817e255b9257e7a829e0d15090c01ef2f156b388adcbf7" ++
        "154c79355b3c8dcd3da36c75528dc888647dc67d3161516903be3b4b04684521e840251200549941ee8e716f073d3689" ++
        "02493b020700d91e49ee";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    var payload: [1024]u8 = undefined;
    var state: u32 = 0xfeed_beef;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast(129 + ((state >> 16) % 127));
    }

    const first_block = try inspectNativeFrameFirstBlock(&frame);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    try std.testing.expectEqual(@as(usize, 957), first_block.payload_len);
    const block = frame[first_block.payload_offset..][0..first_block.payload_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(HuffmanLiteralStreams.four, std.meta.activeTag(section.huffman_streams));
    try std.testing.expectEqual(payload.len, section.regenerated_size);
    try std.testing.expectEqual(@as(usize, 952), section.compressed_size);
    try std.testing.expectEqual(@as(usize, 4), section.literal_payload_offset);
    try std.testing.expectEqual(@as(usize, 60), section.huffman_stream_offset);
    const streams = section.huffman_streams.four;
    try std.testing.expectEqual(@as(usize, 220), streams[0].len);
    try std.testing.expectEqual(@as(usize, 224), streams[1].len);
    try std.testing.expectEqual(@as(usize, 222), streams[2].len);
    try std.testing.expectEqual(@as(usize, 224), streams[3].len);
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);
    const tree = section.huffman_tree orelse return error.CorruptFrame;
    try std.testing.expectEqual(@as(u4, 9), tree.max_bit_count);
    try std.testing.expectEqual(@as(usize, 127), @as(usize, tree.symbol_count_minus_one) + 1);
    try std.testing.expectEqual(@as(u8, 132), tree.nodes[0].symbol);
    try std.testing.expectEqual(@as(u4, 1), tree.nodes[0].weight);
    try std.testing.expectEqual(@as(u16, 0), tree.nodes[0].prefix);
    try std.testing.expectEqual(@as(u8, 238), tree.nodes[tree.symbol_count_minus_one].symbol);
    try std.testing.expectEqual(@as(u4, 4), tree.nodes[tree.symbol_count_minus_one].weight);
    try std.testing.expectEqual(@as(u16, 63), tree.nodes[tree.symbol_count_minus_one].prefix);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, &frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
    try std.testing.expectEqual(payload.len, try decodedRawOrRleFrameSize(&frame));
}

test "zstd native decoder reuses Huffman tree for treeless literals" {
    const unit = "{\"key\":\"value\",\"number\":123,\"array\":[1,2,3],\"text\":\"abcdefg\"}\n";
    const payload = unit ** 200;
    const frame_hex =
        "28b52ffd00680c0200e2c30d1290cf016c3325f0fdb0cddd2ce10b3339ce4e20b" ++
        "fb1a5123a279f76cdb7192d3a14f27ba43cef2102b95c08d2f8fea2efd493d" ++
        "fe58e0301007e7f411fa0750100e3030920bfb1a5123a279f76cdb7192d3a" ++
        "14f27ba43cef2102b95c08d2f8fea2efd493dfe58e0301007e7f411fa0";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, &frame);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, &frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(&frame, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(&frame);
    try std.testing.expectEqual(payload.len, decoded_len);
}

fn appendNumberedJsonPayload(allocator: std.mem.Allocator, out: *std.ArrayList(u8), count: usize) !void {
    for (0..count) |i| {
        const line = try std.fmt.allocPrint(
            allocator,
            "{{\"k\":\"{d:0>4}\",\"n\":{d},\"txt\":\"abcdefghijklmnopqrstuvwxyz0123456789\"}}\n",
            .{ i, i },
        );
        defer allocator.free(line);
        try out.appendSlice(allocator, line);
    }
}

test "zstd native decoder accepts FSE compressed sequence tables" {
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(std.testing.allocator);
    try appendNumberedJsonPayload(std.testing.allocator, &payload, 20);

    const offset_fse_hex =
        "28b52ffd04480d05008246171b604fda9c7c0c3be3e2e30209a920082d844864" ++
        "7777ec670a42a39c2921d4cdbcab9a89786767971242ddccbbaa99887780cc13" ++
        "6a5e4d3cbb582a94896445200f47e3612c1c4502713014080341e0eaabb2de" ++
        "98faf3e6666657778e092720f0750344c9ae87b9d2732eeb11f77a982b7dce" ++
        "653de25e0f73a5e7dc65254ec31a8f60d7c330e97318eb11ec7a18263d87" ++
        "b11ec1ae0ec3a4e70833602852141ad6cc48";
    var offset_fse_frame: [offset_fse_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&offset_fse_frame, offset_fse_hex);

    const all_fse_hex =
        "28b52ffd0458bd04006286161d404fd4010c12709f71cdcb65012b8aa20c2b" ++
        "adb44686e60ccbf0189303ffffffff9fbfe75c6b8cada5544a083d20d3e71" ++
        "a5b2aa1f362a950269218813c1c8d87b1701409c4c150200c0481c2c64a6" ++
        "c93b04f9b666616d6292627a831ecebff6790734a0f1118396384ffff1d1f" ++
        "351a6514ea22a98a124d541551a887841a1aa91692544238998e4eabd5ea" ++
        "745a261a1840a4061ad6cc48";
    var all_fse_frame: [all_fse_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&all_fse_frame, all_fse_hex);

    for ([_][]const u8{ &offset_fse_frame, &all_fse_frame }) |frame| {
        const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame);
        defer std.testing.allocator.free(std_decoded);
        try std.testing.expectEqualSlices(u8, payload.items, std_decoded);

        const decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload.items, decoded);

        const into_buffer = try std.testing.allocator.alloc(u8, payload.items.len);
        defer std.testing.allocator.free(into_buffer);
        const written = try decodeNativeFrameInto(frame, into_buffer);
        try std.testing.expectEqual(payload.items.len, written);
        try std.testing.expectEqualSlices(u8, payload.items, into_buffer[0..written]);

        const decoded_len = try decodedRawOrRleFrameSize(frame);
        try std.testing.expectEqual(payload.items.len, decoded_len);
    }
}

test "zstd native decoder preserves previous offsets for direct offsets" {
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(std.testing.allocator);
    try payload.ensureTotalCapacity(std.testing.allocator, 4200);
    var rng = std.Random.DefaultPrng.init(99);
    const alphabet = "ACGTN";
    for (0..4200) |_| {
        try payload.append(std.testing.allocator, alphabet[rng.random().uintLessThan(usize, alphabet.len)]);
    }

    const encoded = try encodeFrameWithLevelAlloc(std.testing.allocator, payload.items, 3);
    defer std.testing.allocator.free(encoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload.items, decoded);

    const into_buffer = try std.testing.allocator.alloc(u8, payload.items.len);
    defer std.testing.allocator.free(into_buffer);
    const written = try decodeNativeFrameInto(encoded, into_buffer);
    try std.testing.expectEqual(payload.items.len, written);
    try std.testing.expectEqualSlices(u8, payload.items, into_buffer[0..written]);
}

test "zstd native decoder streams many Huffman literal runs without replay" {
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(std.testing.allocator);
    try payload.ensureTotalCapacity(std.testing.allocator, 80_000);
    const alphabet = "ACGTN";
    for (0..80_000) |i| {
        try payload.append(std.testing.allocator, alphabet[(i * 17 + i / 7 + i / 31) % alphabet.len]);
    }

    const encoded = try encodeFrameWithLevelAlloc(std.testing.allocator, payload.items, 1);
    defer std.testing.allocator.free(encoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload.items, decoded);
}

test "zstd native decoder reads mixed FSE tables in serialized order" {
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(std.testing.allocator);
    try payload.ensureTotalCapacity(std.testing.allocator, 200_000);
    var rng = std.Random.DefaultPrng.init(31);
    for (0..200_000) |_| {
        try payload.append(std.testing.allocator, @intCast(rng.random().uintLessThan(u8, 95) + 32));
    }

    const encoded = try encodeFrameWithLevelAlloc(std.testing.allocator, payload.items, 19);
    defer std.testing.allocator.free(encoded);

    const decoded = try decodeNativeFrameAllocLimited(std.testing.allocator, encoded, payload.items.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload.items, decoded);
}

test "zstd native decoder covers libzstd generated corpus shapes" {
    var sequential: [5000]u8 = undefined;
    for (&sequential, 0..) |*byte, i| byte.* = @intCast(i % 251);

    var randomish: [5000]u8 = undefined;
    var rng = std.Random.DefaultPrng.init(1);
    for (&randomish) |*byte| byte.* = rng.random().int(u8);

    const json_unit = "{\"key\":\"value\",\"number\":123,\"array\":[1,2,3],\"text\":\"abcdefg\"}\n";
    const cases = [_][]const u8{
        "abcd" ** 1000,
        &sequential,
        &randomish,
        json_unit ** 200,
        ("a" ** 100 ++ "b" ** 100 ++ "c" ** 100) ** 20,
    };
    const levels = [_]c_int{ 1, 3, 5, 9, 15, 19 };
    const option_sets = [_]LibFrameOptions{
        .{},
        .{ .include_content_size = false },
        .{ .content_checksum = true },
        .{ .include_content_size = false, .content_checksum = true },
    };

    for (cases) |payload| {
        for (levels) |level| {
            for (option_sets) |options| {
                const encoded = try encodeFrameWithLevelAndOptionsAlloc(std.testing.allocator, payload, level, options);
                defer std.testing.allocator.free(encoded);

                const native_decoded = try decodeNativeFrameAllocLimited(std.testing.allocator, encoded, payload.len);
                defer std.testing.allocator.free(native_decoded);
                try std.testing.expectEqualSlices(u8, payload, native_decoded);

                const into = try std.testing.allocator.alloc(u8, payload.len);
                defer std.testing.allocator.free(into);
                const written = try decodeNativeFrameInto(encoded, into);
                try std.testing.expectEqual(payload.len, written);
                try std.testing.expectEqualSlices(u8, payload, into[0..written]);

                try std.testing.expectEqual(payload.len, try decodedRawOrRleFrameSizeLimited(encoded, payload.len));
                try std.testing.expectError(error.OutputLimitExceeded, decodedRawOrRleFrameSizeLimited(encoded, payload.len - 1));
            }
        }
    }
}

test "zstd native decoder rejects malformed FSE compressed sequence tables" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, 4, .{ .content_checksum = false });
    try emitBlockHeader(std.testing.allocator, &frame, 2, 5, true);
    try frame.append(std.testing.allocator, 1 << 3); // raw literals, one literal byte.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1); // one sequence.
    try frame.append(std.testing.allocator, 0x80); // LL uses FSE_Compressed_Mode; OF/ML are predefined.
    try frame.append(std.testing.allocator, 1);

    try std.testing.expectError(error.TruncatedFrame, decodeNativeFrameAlloc(std.testing.allocator, frame.items));
    var output: [4]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeNativeFrameInto(frame.items, &output));
    try std.testing.expectError(error.TruncatedFrame, decodedRawOrRleFrameSize(frame.items));
}

test "zstd literal-only frame writer falls back when compressed literals expand" {
    const payload = "literal-only zstd payload";
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    try std.testing.expectEqual(@as(u24, 0), (block_header >> 1) & 0x3);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(encoded, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const limited = try decodeNativeFrameAllocLimited(std.testing.allocator, encoded, payload.len);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, payload, limited);

    const no_checksum = try encodeLiteralOnlyFrameWithOptionsAlloc(std.testing.allocator, payload, .{ .content_checksum = false });
    defer std.testing.allocator.free(no_checksum);
    try std.testing.expectEqual(@as(u8, 0x20), no_checksum[4]);
    const no_checksum_decoded = try decodeNativeFrameAlloc(std.testing.allocator, no_checksum);
    defer std.testing.allocator.free(no_checksum_decoded);
    try std.testing.expectEqualSlices(u8, payload, no_checksum_decoded);

    const literal_bound = try encodedNativeFrameBoundWithOptions(payload.len, .{ .selection = .literal_only });
    const literal_into = try std.testing.allocator.alloc(u8, literal_bound);
    defer std.testing.allocator.free(literal_into);
    const literal_into_written = try encodeLiteralOnlyFrameIntoSlice(std.testing.allocator, payload, .{}, literal_into);
    try std.testing.expectEqualSlices(u8, encoded, literal_into[0..literal_into_written]);
    try std.testing.expectError(error.OutputTooSmall, encodeLiteralOnlyFrameIntoSlice(std.testing.allocator, payload, .{}, literal_into[0 .. literal_into_written - 1]));
    const no_checksum_into_written = try encodeLiteralOnlyFrameIntoSlice(std.testing.allocator, payload, .{ .content_checksum = false }, literal_into);
    try std.testing.expectEqualSlices(u8, no_checksum, literal_into[0..no_checksum_into_written]);
}

test "zstd literal-only writer uses RLE literals for repeated blocks" {
    const payload = "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz";
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    try std.testing.expectEqual(@as(u24, 2), (block_header >> 1) & 0x3);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded[block_offset + 3 ..][0..block_len], &frame_state);
    try std.testing.expectEqual(LiteralsKind.rle, section.kind);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(encoded, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);
}

test "zstd literal-only writer emits repeated-pattern sequence blocks" {
    const payload = "abc" ** 24;
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    try std.testing.expectEqual(@as(u24, 2), (block_header >> 1) & 0x3);
    const compressed_first_block = try inspectNativeFrameFirstBlock(encoded);
    try std.testing.expectEqual(NativeBlockType.compressed, compressed_first_block.block_type);
    try std.testing.expectEqual(true, compressed_first_block.last);
    try std.testing.expectEqual(@as(usize, block_header >> 3), compressed_first_block.payload_len);
    try std.testing.expectEqual(compressed_first_block.payload_offset + compressed_first_block.payload_len, compressed_first_block.next_header_offset);
    const compressed_summary = try summarizeNativeFrameBlocks(encoded);
    try std.testing.expectEqual(@as(usize, 1), compressed_summary.block_count);
    try std.testing.expectEqual(@as(usize, 1), compressed_summary.compressed_block_count);
    try std.testing.expectEqual(compressed_first_block.payload_len, compressed_summary.payload_bytes);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer keeps repeated-pattern tail literals" {
    const payload = ("abcd" ** 20) ++ "xy";
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits repeated-pattern after long prefix" {
    const payload = "0123456789abcdefghijklmn" ++ ("xyz" ** 32) ++ "tail";
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(@as(usize, 1), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits repeated-pattern blocks after a prefix" {
    const payload = "header:" ++ ("xyz" ** 24) ++ "xy";
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits duplicate substring match" {
    const payload = "prefix-abcdefghijklmno-middle-abcdefghijklmno-tail";
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(@as(usize, 1), section.sequence_count);
    try std.testing.expectEqual(@as(u8, 0x00), block[section.sequence_payload_offset]);
    const estimated_payload_len = try multiSequencePayloadLenWithLiteralEnds(payload, &.{29}, &.{23}, &.{17}, &.{46}, 46);
    try std.testing.expectEqual(block_len, estimated_payload_len);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer mixes duplicate and repeated-pattern matches" {
    const phrase = "abcdefghijklmnop012345";
    const payload = "pfx-" ++ phrase ++ "-mid-" ++ phrase ++ "-repeat-" ++ ("ab" ** 80) ++ "-tail";
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    const first_block = try inspectNativeFrameFirstBlock(encoded);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    var frame_state: SequenceFrameState = .{};
    const block = encoded[first_block.payload_offset..][0..first_block.payload_len];
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expect(section.sequence_count >= 2);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd mixed match lookahead explores non-greedy continuations" {
    const payload =
        "bbeegfabcceeehaabcdfacefegahabdffgabcccfeggbcddffgah" ++
        "ccccfeggbcddffgahceegfabcceeehaabcdfacefegahabdffgab" ++
        "cccfeggbcddfechbcecececececece";
    const first_start = 22;
    const first_candidate = repeatedMixedMatchCandidate(payload, first_start) orelse return error.CorruptFrame;
    try std.testing.expectEqual(MixedMatchKind.repeated, first_candidate.kind);
    try std.testing.expectEqual(@as(usize, 31), first_candidate.literal_len);
    try std.testing.expectEqual(@as(usize, 17), first_candidate.offset);
    try std.testing.expectEqual(@as(usize, 17), first_candidate.match_len);
    try std.testing.expectEqual(@as(usize, 70), first_candidate.literal_end);

    const greedy_payload_len = try bestSequencePayloadLenWithLiteralEnds(
        payload,
        &.{ 31, 52 },
        &.{ 17, 2 },
        &.{ 17, 12 },
        &.{ 70, payload.len },
        payload.len,
    );
    const branch = (try bestMixedCandidateLookaheadPlan(&.{}, payload, 0, first_candidate)) orelse return error.CorruptFrame;
    try std.testing.expectEqual(@as(usize, 3), branch.count);
    try std.testing.expectEqualSlices(usize, &.{ 31, 32, 16 }, branch.literal_lens[0..branch.count]);
    try std.testing.expectEqualSlices(usize, &.{ 17, 28, 2 }, branch.offsets[0..branch.count]);
    try std.testing.expectEqualSlices(usize, &.{ 17, 4, 12 }, branch.match_lens[0..branch.count]);
    try std.testing.expectEqualSlices(usize, &.{ 70, 106, payload.len }, branch.literal_ends[0..branch.count]);
    try std.testing.expect(branch.payload_len < greedy_payload_len);

    const lookahead_payload_len = (try mixedCandidateLookaheadPayloadLen(&.{}, payload, 0, first_candidate)) orelse return error.CorruptFrame;
    try std.testing.expectEqual(branch.payload_len, lookahead_payload_len);

    const emitted_plan = (try bestMixedMatchLookaheadPlan(&.{}, payload, 0, .{
        .dictionary = false,
        .duplicate = true,
        .repeated = true,
    }, .{ .kind = .duplicate }, .{ .kind = .repeated }, mixed_match_path_search_budget)) orelse return error.CorruptFrame;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{ .content_checksum = false });
    try std.testing.expect(try emitMixedDuplicateRepeatedMatchCompressedBlock(std.testing.allocator, &frame, payload, true, mixed_match_path_search_budget));

    const first_block = try inspectNativeFrameFirstBlock(frame.items);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    try std.testing.expectEqual(emitted_plan.payload_len, first_block.payload_len);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(frame.items[first_block.payload_offset..][0..first_block.payload_len], &frame_state);
    try std.testing.expectEqual(emitted_plan.count, section.sequence_count);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "zstd mixed match candidate cache reuses per-position scans" {
    const payload =
        "bbeegfabcceeehaabcdfacefegahabdffgabcccfeggbcddffgah" ++
        "ccccfeggbcddffgahceegfabcceeehaabcdfacefegahabdffgab" ++
        "cccfeggbcddfechbcecececececece";
    var cache: MixedMatchCandidateCache = .{};
    var first: [3]MixedMatchCandidate = undefined;
    var second: [3]MixedMatchCandidate = undefined;
    const allowed: MixedMatchKindSet = .{
        .dictionary = false,
        .duplicate = true,
        .repeated = true,
    };
    const first_count = try cache.candidatesAt(&.{}, payload, 70, 0, allowed, first[0..]);
    const second_count = try cache.candidatesAt(&.{}, payload, 70, 0, allowed, second[0..]);
    try std.testing.expectEqual(first_count, second_count);
    try std.testing.expectEqual(@as(usize, 2), cache.lookup_count);
    try std.testing.expectEqual(@as(usize, 1), cache.hit_count);
    for (0..first_count) |i| {
        try std.testing.expectEqual(first[i].kind, second[i].kind);
        try std.testing.expectEqual(first[i].literal_len, second[i].literal_len);
        try std.testing.expectEqual(first[i].offset, second[i].offset);
        try std.testing.expectEqual(first[i].match_len, second[i].match_len);
        try std.testing.expectEqual(first[i].literal_end, second[i].literal_end);
        try std.testing.expectEqual(first[i].payload_len, second[i].payload_len);
    }
}

test "zstd mixed match candidate cache reuses dictionary scans" {
    const dict_content = "DICTMATCH1234567890";
    const unique = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}";
    const payload = "pfx-" ++ dict_content ++ "-u-" ++ unique ++ "-mid-" ++ unique ++ "-rep-" ++ ("ab" ** 16) ++ "-tail";
    var cache: MixedMatchCandidateCache = .{};
    var first: [3]MixedMatchCandidate = undefined;
    var second: [3]MixedMatchCandidate = undefined;
    const allowed: MixedMatchKindSet = .{
        .dictionary = true,
        .duplicate = true,
        .repeated = true,
    };
    const first_count = try cache.candidatesAt(dict_content, payload, 0, 0, allowed, first[0..]);
    const second_count = try cache.candidatesAt(dict_content, payload, 0, 0, allowed, second[0..]);
    try std.testing.expectEqual(first_count, second_count);
    try std.testing.expectEqual(@as(usize, 2), cache.lookup_count);
    try std.testing.expectEqual(@as(usize, 1), cache.hit_count);
    try std.testing.expect(first_count >= 2);
    var saw_dictionary = false;
    var saw_non_dictionary = false;
    for (0..first_count) |i| {
        try std.testing.expectEqual(first[i].kind, second[i].kind);
        try std.testing.expectEqual(first[i].literal_len, second[i].literal_len);
        try std.testing.expectEqual(first[i].offset, second[i].offset);
        try std.testing.expectEqual(first[i].match_len, second[i].match_len);
        try std.testing.expectEqual(first[i].literal_end, second[i].literal_end);
        try std.testing.expectEqual(first[i].payload_len, second[i].payload_len);
        saw_dictionary = saw_dictionary or first[i].kind == .dictionary;
        saw_non_dictionary = saw_non_dictionary or first[i].kind != .dictionary;
    }
    try std.testing.expect(saw_dictionary);
    try std.testing.expect(saw_non_dictionary);
}

test "zstd literal-only writer chooses shortest native match plan" {
    var payload: [160]u8 = undefined;
    var state: u32 = 0x3039;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
        // Keep filler out of the ASCII letters used for explicit repeated
        // patterns below, so this regression is driven by the intended match
        // candidates instead of accidental short-period text.
        if (byte.* >= 'a' and byte.* <= 'z') byte.* ^= 0x80;
    }
    @memcpy(payload[20..][0..16], payload[0..16]);
    const repeat_start = 60;
    @memcpy(payload[repeat_start..][0..2], "ab");
    for (2..80) |i| payload[repeat_start + i] = payload[repeat_start + (i % 2)];
    for (140..160) |i| payload[i] = @intCast('T' + (i % 7));

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(raw_encoded);

    const first_block = try inspectNativeFrameFirstBlock(encoded);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    var frame_state: SequenceFrameState = .{};
    const block = encoded[first_block.payload_offset..][0..first_block.payload_len];
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(@as(usize, 3), section.sequence_count);
    const estimated_payload_len = try bestSequencePayloadLenWithLiteralEnds(
        &payload,
        &.{ 20, 26, 7 },
        &.{ 20, 2, 7 },
        &.{ 16, 78, 13 },
        &.{ 36, 140, payload.len },
        payload.len,
    );
    try std.testing.expectEqual(estimated_payload_len, first_block.payload_len);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, &payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer chooses duplicate matches over larger Huffman literals" {
    const phrase = "abcdefghijklmno0123456789";
    const payload = "prefix-" ++ phrase ++ "-middle-" ++ phrase ++ "-suffix-" ++ ("pqrs" ** 8);
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    const first_block = try inspectNativeFrameFirstBlock(encoded);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded[first_block.payload_offset..][0..first_block.payload_len], &frame_state);
    try std.testing.expect(section.sequence_count >= 1);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits small Huffman literals" {
    var payload: [192]u8 = undefined;
    var state: u8 = 1;
    for (&payload) |*byte| {
        byte.* = if ((state & 1) == 0) 'A' else 'B';
        const feedback: u8 = ((state >> 0) ^ (state >> 2) ^ (state >> 3) ^ (state >> 4)) & 1;
        state = (state >> 1) | (feedback << 7);
    }

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(raw_encoded);

    const first_block = try inspectNativeFrameFirstBlock(encoded);
    const block = encoded[first_block.payload_offset..][0..first_block.payload_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, &payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits four-symbol Huffman literals" {
    var payload: [192]u8 = undefined;
    var state: u32 = 1;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = "ABCD"[(state >> 30) & 3];
    }

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, &payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits six-symbol Huffman literals" {
    var payload: [256]u8 = undefined;
    var state: u32 = 0x0bad_f00d;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = "ABCDEF"[(state >> 29) % 6];
    }

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, &payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits eight-symbol Huffman literals" {
    var payload: [256]u8 = undefined;
    var state: u32 = 0x1234_5678;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = "ABCDEFGH"[(state >> 29) & 7];
    }

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, &payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits sixteen-symbol Huffman literals" {
    var payload: [256]u8 = undefined;
    var state: u32 = 0x8765_4321;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = "ABCDEFGHIJKLMNOP"[(state >> 28) & 15];
    }

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, &payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits thirty-two-symbol Huffman literals" {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef";
    var payload: [384]u8 = undefined;
    var state: u32 = 0xfeed_beef;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = alphabet[(state >> 27) & 31];
    }

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, &payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits sixty-four-symbol Huffman literals" {
    var payload: [512]u8 = undefined;
    var state: u32 = 0x3141_5926;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast(32 + ((state >> 26) & 63));
    }

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, &payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits printable Huffman literals" {
    var payload: [768]u8 = undefined;
    var state: u32 = 0x2718_2818;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast(32 + ((state >> 24) % 95));
    }

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, &payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits four-stream Huffman literals" {
    var payload: [4096]u8 = undefined;
    var state: u32 = 0x1618_0339;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast(32 + ((state >> 24) % 95));
    }

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(HuffmanLiteralStreams.four, std.meta.activeTag(section.huffman_streams));
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, &payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits large four-stream Huffman literals" {
    const payload = try std.testing.allocator.alloc(u8, 64 * 1024);
    defer std.testing.allocator.free(payload);
    var state: u32 = 0x577d_f00d;
    for (payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast(32 + ((state >> 24) % 95));
    }

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(HuffmanLiteralStreams.four, std.meta.activeTag(section.huffman_streams));
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer reuses Huffman tree across blocks" {
    const payload = try std.testing.allocator.alloc(u8, std.compress.zstd.block_size_max + 4096);
    defer std.testing.allocator.free(payload);
    var state: u32 = 0x577d_f00d;
    var payload_offset: usize = 0;
    while (payload_offset < payload.len) {
        var symbols: [64]u8 = undefined;
        for (&symbols, 0..) |*symbol, i| {
            symbol.* = @intCast(32 + i);
        }
        var i = symbols.len;
        while (i > 1) {
            i -= 1;
            state = state *% 1_664_525 +% 1_013_904_223;
            const j: usize = @intCast((state >> 16) % (i + 1));
            const tmp = symbols[i];
            symbols[i] = symbols[j];
            symbols[j] = tmp;
        }
        @memcpy(payload[payload_offset..][0..symbols.len], &symbols);
        payload_offset += symbols.len;
    }

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const first_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    try std.testing.expectEqual(@as(u24, 2), (first_header >> 1) & 0x3);
    try std.testing.expectEqual(false, (first_header & 1) != 0);
    const first_block_len: usize = @intCast(first_header >> 3);
    var frame_state: SequenceFrameState = .{};
    const first_section = try parseLiteralsSection(encoded[block_offset + 3 ..][0..first_block_len], &frame_state);
    try std.testing.expectEqual(LiteralsKind.compressed, first_section.kind);
    try std.testing.expectEqual(HuffmanLiteralStreams.four, std.meta.activeTag(first_section.huffman_streams));
    try std.testing.expectEqual(@as(usize, 0), first_section.sequence_count);

    block_offset += 3 + first_block_len;
    const second_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    try std.testing.expectEqual(@as(u24, 2), (second_header >> 1) & 0x3);
    try std.testing.expectEqual(true, (second_header & 1) != 0);
    const second_block_len: usize = @intCast(second_header >> 3);
    const second_section = try parseLiteralsSection(encoded[block_offset + 3 ..][0..second_block_len], &frame_state);
    try std.testing.expectEqual(LiteralsKind.treeless, second_section.kind);
    try std.testing.expectEqual(HuffmanLiteralStreams.four, std.meta.activeTag(second_section.huffman_streams));
    try std.testing.expectEqual(@as(usize, 0), second_section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits non-divisible four-stream Huffman" {
    var payload: [5190]u8 = undefined;
    var state: u32 = 0x1618_0339;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast(32 + ((state >> 24) % 95));
    }

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(HuffmanLiteralStreams.four, std.meta.activeTag(section.huffman_streams));
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, &payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
}

test "zstd literal-only writer emits 128-symbol Huffman literals" {
    var payload: [896]u8 = undefined;
    var state: u32 = 0x1357_9bdf;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast(1 + ((state >> 24) & 127));
    }

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, &payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd Huffman literal planner favors frequent symbols" {
    var payload: [4096]u8 = undefined;
    for (payload[0..26], 0..) |*byte, i| {
        byte.* = @intCast('A' + i);
    }
    var state: u32 = 0x8bad_f00d;
    for (payload[26..]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if ((state & 0x0f) < 12)
            'A'
        else
            @intCast('B' + ((state >> 8) % 25));
    }

    const plan = smallHuffmanLiteralPlan(&payload) orelse return error.CorruptFrame;
    const hot_bits = smallHuffmanBitCount(plan, 'A') orelse return error.CorruptFrame;
    const cold_bits = smallHuffmanBitCount(plan, 'Z') orelse return error.CorruptFrame;
    try std.testing.expect(hot_bits < cold_bits);

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(raw_encoded);
    try std.testing.expect(encoded.len < raw_encoded.len);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
}

test "zstd literal-only writer emits max direct Huffman symbol set" {
    var payload: [129 * 64]u8 = undefined;
    for (payload[0..129], 0..) |*byte, i| {
        byte.* = @intCast(i);
    }
    var state: u32 = 0x1290_0f5e;
    for (payload[129..]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast((state >> 16) % 129);
    }

    const plan = smallHuffmanLiteralPlan(&payload) orelse return error.CorruptFrame;
    try std.testing.expectEqual(@as(usize, 129), plan.len);
    var direct_huffman: std.ArrayList(u8) = .empty;
    defer direct_huffman.deinit(std.testing.allocator);
    var direct_state: LiteralOnlyEncoderState = .{};
    try std.testing.expect(try emitSmallHuffmanLiteralBlock(std.testing.allocator, &direct_huffman, &payload, true, &direct_state));

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(raw_encoded);

    const first_block = try inspectNativeFrameFirstBlock(encoded);
    const block = encoded[first_block.payload_offset..][0..first_block.payload_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, &payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits FSE Huffman tree for high-byte binary literals" {
    var payload: [1024]u8 = undefined;
    var state: u32 = 0xfeed_beef;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast(129 + ((state >> 16) % 127));
    }

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(raw_encoded);
    const first_block = try inspectNativeFrameFirstBlock(encoded);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);

    const block = encoded[first_block.payload_offset..][0..first_block.payload_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);
    try std.testing.expect(block[section.literal_payload_offset] < 128);

    const tree = section.huffman_tree orelse return error.CorruptFrame;
    try std.testing.expect(tree.max_bit_count <= 11);
    try std.testing.expectEqual(@as(usize, 127), @as(usize, tree.symbol_count_minus_one) + 1);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, &payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd match planner scores single predefined sequence payloads" {
    const payload = "ab" ** 12;
    const match: DuplicateMatch = .{
        .first_start = 0,
        .second_start = 2,
        .len = payload.len - 2,
    };
    const literal_len = match.second_start;
    const offset = match.second_start - match.first_start;
    const tail_start = match.second_start + match.len;
    const rle_len = try singleRleSequencePayloadLen(payload, literal_len, offset, match.len, tail_start);
    const predefined_len = try multiSequencePayloadLenWithLiteralEnds(
        payload,
        &.{literal_len},
        &.{offset},
        &.{match.len},
        &.{tail_start},
        tail_start,
    );
    try std.testing.expect(predefined_len < rle_len);
    try std.testing.expectEqual(predefined_len, try singleMatchPayloadLen(payload, match));

    const segment = findRepeatedPatternSegment(payload) orelse return error.CorruptFrame;
    try std.testing.expectEqual(predefined_len, repeatedPatternPayloadLenFrom(payload, segment, 0) orelse return error.CorruptFrame);
}

test "zstd sequence emitter supports mixed RLE and predefined tables" {
    var payload: [409]u8 = undefined;
    var cursor: usize = 0;
    @memset(payload[cursor..][0..74], 'A');
    cursor += 74;
    @memset(payload[cursor..][0..57], 'A');
    cursor += 57;
    @memset(payload[cursor..][0..76], 'B');
    cursor += 76;
    @memset(payload[cursor..][0..202], 'B');
    cursor += 202;
    try std.testing.expectEqual(payload.len, cursor);

    const literal_lens = [_]usize{ 74, 76 };
    const offsets = [_]usize{ 72, 52 };
    const match_lens = [_]usize{ 57, 202 };
    const literal_ends = [_]usize{ 131, payload.len };
    const table_plan = (try bestTablePlanSequence(&payload, &literal_lens, &offsets, &match_lens, &literal_ends, payload.len)) orelse return error.CorruptFrame;
    try std.testing.expectEqual(SymbolMode.rle, sequenceTableMode(table_plan.plan.literal));
    try std.testing.expectEqual(SymbolMode.predefined, sequenceTableMode(table_plan.plan.offset));
    try std.testing.expectEqual(SymbolMode.predefined, sequenceTableMode(table_plan.plan.match));
    try std.testing.expect(table_plan.payload_len < try multiSequencePayloadLenWithLiteralEnds(&payload, &literal_lens, &offsets, &match_lens, &literal_ends, payload.len));
    try std.testing.expectEqual(table_plan.payload_len, try bestSequencePayloadLenWithLiteralEnds(&payload, &literal_lens, &offsets, &match_lens, &literal_ends, payload.len));

    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{ .content_checksum = false });
    try std.testing.expect(try emitBestSequenceCompressedBlock(
        std.testing.allocator,
        &frame,
        &payload,
        true,
        &literal_lens,
        &offsets,
        &match_lens,
        &literal_ends,
        payload.len,
    ));

    const first_block = try inspectNativeFrameFirstBlock(frame.items);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    try std.testing.expectEqual(table_plan.payload_len, first_block.payload_len);
    const block = frame.items[first_block.payload_offset..][0..first_block.payload_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(@as(usize, literal_lens[0] + literal_lens[1]), section.regenerated_size);
    try std.testing.expectEqual(@as(usize, 2), section.sequence_count);
    try std.testing.expectEqual(@as(u8, 0x40), block[section.sequence_payload_offset]); // LL=RLE, OF/ML=Predefined.

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, &payload, std_decoded);
}

test "zstd sequence emitter supports compressed FSE literal-length table" {
    const literal_lens = [_]usize{ 2, 3, 2, 4, 3, 2, 4, 3, 2, 3, 2, 4, 3, 2, 4, 3 };
    const offsets = [_]usize{ 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 };
    const match_lens = [_]usize{ 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8 };
    var literal_ends: [literal_lens.len]usize = undefined;

    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(std.testing.allocator);
    for (literal_lens, 0..) |literal_len, i| {
        switch (literal_len) {
            2 => try payload.appendSlice(std.testing.allocator, "ab"),
            3 => try payload.appendSlice(std.testing.allocator, "xab"),
            4 => try payload.appendSlice(std.testing.allocator, "xyab"),
            else => unreachable,
        }
        try payload.appendSlice(std.testing.allocator, "ab" ** 4);
        literal_ends[i] = payload.items.len;
    }

    const literal_plan = (try planCompressedSequenceValues(&literal_lens, .literal)) orelse return error.CorruptFrame;
    const plan: SequenceCombinedEmitPlan = .{
        .literal = .{ .compressed = literal_plan },
        .offset = .{ .rle = try sequenceCodeForValue(2, &of_base, &of_bits) },
        .match = .{ .rle = try sequenceCodeForValue(8, &ml_base, &ml_bits) },
    };
    try std.testing.expectEqual(SymbolMode.compressed, sequenceTableMode(plan.literal));
    try std.testing.expect(literal_plan.table_payload_len > 0);

    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.items.len, .{ .content_checksum = false });
    try std.testing.expect(try emitSequenceCompressedBlockWithTablePlans(
        std.testing.allocator,
        &frame,
        payload.items,
        true,
        &literal_lens,
        &offsets,
        &match_lens,
        &literal_ends,
        payload.items.len,
        plan,
    ));

    const first_block = try inspectNativeFrameFirstBlock(frame.items);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    const block = frame.items[first_block.payload_offset..][0..first_block.payload_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(literal_lens.len, section.sequence_count);
    try std.testing.expectEqual(@as(u8, 0x94), block[section.sequence_payload_offset]); // LL=FSE, OF/ML=RLE.

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload.items, decoded);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload.items, std_decoded);
}

test "zstd sequence emitter supports compressed FSE absolute-offset table" {
    const literal_lens = [_]usize{ 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    const offsets = [_]usize{ 4, 8, 4, 12, 8, 4, 12, 8, 4, 8, 4, 12, 8, 4, 12, 8 };
    const match_lens = [_]usize{ 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8 };
    var literal_ends: [literal_lens.len]usize = undefined;

    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(std.testing.allocator);
    for (offsets, 0..) |offset, i| {
        if (literal_lens[i] != 0) try payload.appendSlice(std.testing.allocator, "abcdefghijkl");
        for (0..match_lens[i]) |_| {
            try payload.append(std.testing.allocator, payload.items[payload.items.len - offset]);
        }
        literal_ends[i] = payload.items.len;
    }

    const literal_plan = (try planPredefinedSequenceValues(&literal_lens, &default_ll_symbols, 0)) orelse return error.CorruptFrame;
    const offset_plan = (try planCompressedSequenceValues(&offsets, .offset)) orelse return error.CorruptFrame;
    const plan: SequenceCombinedEmitPlan = .{
        .literal = .{ .predefined = literal_plan },
        .offset = .{ .compressed = offset_plan },
        .match = .{ .rle = try sequenceCodeForValue(8, &ml_base, &ml_bits) },
    };
    try std.testing.expectEqual(SymbolMode.compressed, sequenceTableMode(plan.offset));
    try std.testing.expect(offset_plan.table_payload_len > 0);

    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.items.len, .{ .content_checksum = false });
    try std.testing.expect(try emitSequenceCompressedBlockWithTablePlans(
        std.testing.allocator,
        &frame,
        payload.items,
        true,
        &literal_lens,
        &offsets,
        &match_lens,
        &literal_ends,
        payload.items.len,
        plan,
    ));

    const first_block = try inspectNativeFrameFirstBlock(frame.items);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    const block = frame.items[first_block.payload_offset..][0..first_block.payload_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(literal_lens.len, section.sequence_count);
    try std.testing.expectEqual(@as(u8, 0x24), block[section.sequence_payload_offset]); // LL=Predefined, OF=FSE, ML=RLE.

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload.items, decoded);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload.items, std_decoded);
}

test "zstd sequence emitter supports compressed FSE repeat-offset selectors" {
    const literal_lens = [_]usize{ 8, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 };
    const offsets = [_]usize{ 4, 4, 1, 8, 8, 4, 4, 8, 1, 1, 8, 4, 4, 8, 1, 1 };
    const expected_offset_codes = [_]u8{ 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0 };
    const match_lens = [_]usize{ 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 };
    var literal_ends: [literal_lens.len]usize = undefined;

    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(std.testing.allocator);
    for (offsets, 0..) |offset, i| {
        for (0..literal_lens[i]) |j| {
            try payload.append(std.testing.allocator, 'a' + @as(u8, @intCast((i + j) % 26)));
        }
        for (0..match_lens[i]) |_| {
            try payload.append(std.testing.allocator, payload.items[payload.items.len - offset]);
        }
        literal_ends[i] = payload.items.len;
    }

    const literal_plan = (try planPredefinedSequenceValues(&literal_lens, &default_ll_symbols, 0)) orelse return error.CorruptFrame;
    const offset_plan = (try planCompressedOffsetSequenceValues(&literal_lens, &offsets)) orelse return error.CorruptFrame;
    const plan: SequenceCombinedEmitPlan = .{
        .literal = .{ .predefined = literal_plan },
        .offset = .{ .compressed = offset_plan },
        .match = .{ .rle = try sequenceCodeForValue(4, &ml_base, &ml_bits) },
    };
    try std.testing.expectEqual(SymbolMode.compressed, sequenceTableMode(plan.offset));
    try std.testing.expectEqualSlices(u8, &expected_offset_codes, offset_plan.codes[0..offsets.len]);
    try std.testing.expect(offset_plan.table_payload_len > 0);

    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.items.len, .{ .content_checksum = false });
    try std.testing.expect(try emitSequenceCompressedBlockWithTablePlans(
        std.testing.allocator,
        &frame,
        payload.items,
        true,
        &literal_lens,
        &offsets,
        &match_lens,
        &literal_ends,
        payload.items.len,
        plan,
    ));

    const first_block = try inspectNativeFrameFirstBlock(frame.items);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    const block = frame.items[first_block.payload_offset..][0..first_block.payload_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(literal_lens.len, section.sequence_count);
    try std.testing.expectEqual(@as(u8, 0x24), block[section.sequence_payload_offset]); // LL=Predefined, OF=FSE, ML=RLE.

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(payload.items.len, decoded_len);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload.items, decoded);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload.items, std_decoded);
}

test "zstd sequence planner can choose compressed FSE for all sequence tables" {
    const literal_lens = [_]usize{
        8, 1, 2, 3, 2, 4, 3, 1,
        2, 3, 2, 4, 3, 1, 2, 3,
        2, 4, 3, 1, 2, 3, 2, 4,
        3, 1, 2, 3, 2, 4, 3, 1,
    };
    const offsets = [_]usize{
        4, 4, 1, 8, 8, 4, 4, 8,
        1, 1, 8, 4, 4, 8, 1, 1,
        8, 4, 4, 8, 1, 1, 8, 4,
        4, 8, 1, 1, 8, 4, 4, 8,
    };
    const match_lens = [_]usize{
        4, 5, 4, 6, 5, 4, 6, 5,
        4, 5, 4, 6, 5, 4, 6, 5,
        4, 5, 4, 6, 5, 4, 6, 5,
        4, 5, 4, 6, 5, 4, 6, 5,
    };
    var literal_ends: [literal_lens.len]usize = undefined;

    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(std.testing.allocator);
    for (offsets, 0..) |offset, i| {
        for (0..literal_lens[i]) |j| {
            try payload.append(std.testing.allocator, 'a' + @as(u8, @intCast((i + j) % 26)));
        }
        for (0..match_lens[i]) |_| {
            try payload.append(std.testing.allocator, payload.items[payload.items.len - offset]);
        }
        literal_ends[i] = payload.items.len;
    }

    const table_plan = (try bestTablePlanSequence(
        payload.items,
        &literal_lens,
        &offsets,
        &match_lens,
        &literal_ends,
        payload.items.len,
    )) orelse return error.CorruptFrame;
    try std.testing.expectEqual(SymbolMode.compressed, sequenceTableMode(table_plan.plan.literal));
    try std.testing.expectEqual(SymbolMode.compressed, sequenceTableMode(table_plan.plan.offset));
    try std.testing.expectEqual(SymbolMode.compressed, sequenceTableMode(table_plan.plan.match));

    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.items.len, .{ .content_checksum = false });
    try std.testing.expect(try emitBestSequenceCompressedBlock(
        std.testing.allocator,
        &frame,
        payload.items,
        true,
        &literal_lens,
        &offsets,
        &match_lens,
        &literal_ends,
        payload.items.len,
    ));

    const first_block = try inspectNativeFrameFirstBlock(frame.items);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    try std.testing.expectEqual(table_plan.payload_len, first_block.payload_len);
    const block = frame.items[first_block.payload_offset..][0..first_block.payload_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(literal_lens.len, section.sequence_count);
    try std.testing.expectEqual(@as(u8, 0xa8), block[section.sequence_payload_offset]); // LL/OF/ML all use FSE.

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload.items, decoded);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload.items, std_decoded);
}

test "zstd sequence emitter supports compressed FSE match-length table" {
    const literal_lens = [_]usize{ 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    const offsets = [_]usize{ 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 };
    const match_lens = [_]usize{ 8, 9, 8, 10, 9, 8, 10, 9, 8, 9, 8, 10, 9, 8, 10, 9 };
    var literal_ends: [literal_lens.len]usize = undefined;

    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(std.testing.allocator);
    for (offsets, 0..) |offset, i| {
        if (literal_lens[i] != 0) try payload.appendSlice(std.testing.allocator, "abcdefghijkl");
        for (0..match_lens[i]) |_| {
            try payload.append(std.testing.allocator, payload.items[payload.items.len - offset]);
        }
        literal_ends[i] = payload.items.len;
    }

    const literal_plan = (try planPredefinedSequenceValues(&literal_lens, &default_ll_symbols, 0)) orelse return error.CorruptFrame;
    const match_plan = (try planCompressedSequenceValues(&match_lens, .match)) orelse return error.CorruptFrame;
    const plan: SequenceCombinedEmitPlan = .{
        .literal = .{ .predefined = literal_plan },
        .offset = .{ .rle = try sequenceCodeForValue(4, &of_base, &of_bits) },
        .match = .{ .compressed = match_plan },
    };
    try std.testing.expectEqual(SymbolMode.compressed, sequenceTableMode(plan.match));
    try std.testing.expect(match_plan.table_payload_len > 0);

    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.items.len, .{ .content_checksum = false });
    try std.testing.expect(try emitSequenceCompressedBlockWithTablePlans(
        std.testing.allocator,
        &frame,
        payload.items,
        true,
        &literal_lens,
        &offsets,
        &match_lens,
        &literal_ends,
        payload.items.len,
        plan,
    ));

    const first_block = try inspectNativeFrameFirstBlock(frame.items);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    const block = frame.items[first_block.payload_offset..][0..first_block.payload_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(literal_lens.len, section.sequence_count);
    try std.testing.expectEqual(@as(u8, 0x18), block[section.sequence_payload_offset]); // LL=Predefined, OF=RLE, ML=FSE.

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload.items, decoded);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload.items, std_decoded);
}

test "zstd literal-only writer keeps two-symbol repeated pattern matches" {
    const payload = "ab" ** 80;
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(@as(usize, 1), section.sequence_count);
    try std.testing.expectEqual(@as(u8, 0x00), block[section.sequence_payload_offset]);
    const estimated_payload_len = try multiSequencePayloadLenWithLiteralEnds(payload, &.{2}, &.{2}, &.{payload.len - 2}, &.{payload.len}, payload.len);
    try std.testing.expectEqual(block_len, estimated_payload_len);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits long-period repeated pattern match" {
    const pattern = "abcdefghijklmnop";
    const payload = pattern ** 24;
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(@as(usize, 1), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits wider repeated pattern match" {
    const pattern = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKL";
    const payload = pattern ** 12;
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded[block_offset + 3 ..][0..block_len], &frame_state);
    try std.testing.expectEqual(@as(usize, 1), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer scans later repeated pattern starts" {
    const prefix = "0123456789abcdefghijklmnopqrstuvwxyz";
    const pattern = "abcdefghijklmnop";
    const tail = "-tail";
    const payload = prefix ++ (pattern ** 16) ++ tail;
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded[block_offset + 3 ..][0..block_len], &frame_state);
    try std.testing.expectEqual(@as(usize, 1), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits large duplicate substring match" {
    const half_len = 8 * 1024;
    const payload = try std.testing.allocator.alloc(u8, half_len * 2 + 9);
    defer std.testing.allocator.free(payload);

    var state: u32 = 0x9e37_79b9;
    for (payload[0..half_len]) |*byte| {
        state = state *% 1_103_515_245 +% 12_345;
        byte.* = @truncate((state >> 16) ^ (state >> 24));
    }
    @memcpy(payload[half_len..][0..half_len], payload[0..half_len]);
    @memcpy(payload[half_len * 2 ..], "tail-data");

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    try std.testing.expectEqual(@as(u24, 2), (block_header >> 1) & 0x3);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded[block_offset + 3 ..][0..block_len], &frame_state);
    try std.testing.expectEqual(@as(usize, 1), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer finds older large duplicate candidate" {
    const prefix_len = 8 * 1024;
    const short_len = 64;
    const tail = "tail-data";
    const payload = try std.testing.allocator.alloc(u8, prefix_len + short_len + prefix_len + tail.len);
    defer std.testing.allocator.free(payload);

    var state: u32 = 0x6a09_e667;
    for (payload[0..prefix_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(payload[prefix_len..][0..short_len], payload[0..short_len]);
    @memcpy(payload[prefix_len + short_len ..][0..prefix_len], payload[0..prefix_len]);
    @memcpy(payload[prefix_len + short_len + prefix_len ..], tail);

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    try std.testing.expectEqual(@as(u24, 2), (block_header >> 1) & 0x3);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded[block_offset + 3 ..][0..block_len], &frame_state);
    try std.testing.expectEqual(@as(usize, 1), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer keeps deeper duplicate hash candidates" {
    const base = "ABCDEFGH";
    const colliders = [_][]const u8{
        "\x28\x8b\x0012345",
        "\x19\xfb\x0012345",
        "\x39\xb0\x0112345",
        "\x2a\x20\x0212345",
        "\x59\x65\x0212345",
    };
    const gap = "0123456789abcdef" ** 64;
    const filler = "zyxwvutsrqponmlk" ** 16;
    const tail = "tail-data";
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(std.testing.allocator);
    try payload.appendSlice(std.testing.allocator, base);
    for (colliders) |collider| {
        try payload.appendSlice(std.testing.allocator, gap);
        try payload.appendSlice(std.testing.allocator, collider);
    }
    try payload.appendSlice(std.testing.allocator, filler);
    try payload.appendSlice(std.testing.allocator, base ++ ("ABCDEFGH" ** 16));
    try payload.appendSlice(std.testing.allocator, tail);

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload.items);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload.items);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    try std.testing.expectEqual(@as(u24, 2), (block_header >> 1) & 0x3);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded[block_offset + 3 ..][0..block_len], &frame_state);
    try std.testing.expect(section.sequence_count >= 1);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload.items, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits multiple large duplicate matches" {
    const segment_len = 4 * 1024;
    const tail = "tail-data";
    const payload = try std.testing.allocator.alloc(u8, segment_len * 4 + tail.len);
    defer std.testing.allocator.free(payload);

    var state: u32 = 0x243f_6a88;
    for (payload[0..segment_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(payload[segment_len..][0..segment_len], payload[0..segment_len]);

    state = 0xb7e1_5162;
    const second_literal_start = segment_len * 2;
    for (payload[second_literal_start..][0..segment_len]) |*byte| {
        state = state *% 22_695_477 +% 1;
        byte.* = @truncate(state >> 16);
    }
    @memcpy(payload[segment_len * 3 ..][0..segment_len], payload[second_literal_start..][0..segment_len]);
    @memcpy(payload[segment_len * 4 ..], tail);

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    try std.testing.expectEqual(@as(u24, 2), (block_header >> 1) & 0x3);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded[block_offset + 3 ..][0..block_len], &frame_state);
    try std.testing.expectEqual(@as(usize, 2), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits predefined multi duplicate matches" {
    const large_len = 8 * 1024;
    const small_len = 257;
    const tail = "tail-data";
    const payload = try std.testing.allocator.alloc(u8, large_len * 2 + small_len * 2 + tail.len);
    defer std.testing.allocator.free(payload);

    var state: u32 = 0x4528_21e6;
    for (payload[0..large_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(payload[large_len..][0..large_len], payload[0..large_len]);

    const small_start = large_len * 2;
    state = 0x38d0_13f7;
    for (payload[small_start..][0..small_len]) |*byte| {
        state = state *% 22_695_477 +% 1;
        byte.* = @truncate(state >> 16);
    }
    @memcpy(payload[small_start + small_len ..][0..small_len], payload[small_start..][0..small_len]);
    @memcpy(payload[small_start + small_len * 2 ..], tail);

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(@as(usize, 2), section.sequence_count);
    try std.testing.expectEqual(@as(u8, 0x00), block[section.sequence_payload_offset]); // LL/OF/ML all use Predefined_Mode.
    const estimated_payload_len = try multiSequencePayloadLen(
        payload,
        &.{ large_len, small_len },
        &.{ large_len, small_len },
        &.{ large_len, small_len },
        payload.len - tail.len,
    );
    try std.testing.expectEqual(block_len, estimated_payload_len);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits multiple duplicate matches" {
    const payload = "abcdefghijabcdefghijklmnopqrstklmnopqrst";
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(@as(usize, 2), section.sequence_count);
    try std.testing.expectEqual(@as(u8, 0x54), block[section.sequence_payload_offset]);
    const literal_lens = [_]usize{ 10, 10 };
    const offsets = [_]usize{ 10, 10 };
    const match_lens = [_]usize{ 10, 10 };
    const estimated_payload_len = try rleSequencePayloadLen(
        payload,
        &literal_lens,
        &offsets,
        &match_lens,
        payload.len,
        try sequenceCodeForValue(literal_lens[0], &ll_base, &ll_bits),
        try sequenceCodeForValue(offsets[0], &of_base, &of_bits),
        try sequenceCodeForValue(match_lens[0], &ml_base, &ml_bits),
    );
    try std.testing.expectEqual(block_len, estimated_payload_len);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer scores duplicate match extra bits" {
    const payload = "0123456789abcdef--0123456789abcdef--tail";
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits two repeated-pattern sequences" {
    const payload = ("ab" ** 12) ++ ("cd" ** 12);
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(@as(usize, 2), section.sequence_count);
    const literal_lens = [_]usize{ 2, 2 };
    const offsets = [_]usize{ 2, 2 };
    const match_lens = [_]usize{ 22, 22 };
    const estimated_payload_len = try rleSequencePayloadLen(
        payload,
        &literal_lens,
        &offsets,
        &match_lens,
        payload.len,
        try sequenceCodeForValue(literal_lens[0], &ll_base, &ll_bits),
        try sequenceCodeForValue(offsets[0], &of_base, &of_bits),
        try sequenceCodeForValue(match_lens[0], &ml_base, &ml_bits),
    );
    try std.testing.expectEqual(block_len, estimated_payload_len);
    const first_candidate = repeatedMixedMatchCandidate(payload, 0) orelse return error.CorruptFrame;
    const lookahead_payload_len = (try mixedCandidateLookaheadPayloadLen(&.{}, payload, 0, first_candidate)) orelse return error.CorruptFrame;
    try std.testing.expectEqual(estimated_payload_len, lookahead_payload_len);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd RLE sequence emitter matches payload estimate" {
    const payload = ("ab" ** 12) ++ ("cd" ** 12);
    const literal_lens = [_]usize{ 2, 2 };
    const offsets = [_]usize{ 2, 2 };
    const match_lens = [_]usize{ 22, 22 };
    const literal_ends = [_]usize{ 24, 48 };
    const literal_code = try sequenceCodeForValue(literal_lens[0], &ll_base, &ll_bits);
    const offset_code = try sequenceCodeForValue(offsets[0], &of_base, &of_bits);
    const match_code = try sequenceCodeForValue(match_lens[0], &ml_base, &ml_bits);
    const estimated_payload_len = try rleSequencePayloadLen(
        payload,
        &literal_lens,
        &offsets,
        &match_lens,
        payload.len,
        literal_code,
        offset_code,
        match_code,
    );

    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{ .content_checksum = false });
    try std.testing.expect(try emitRleSequenceCompressedBlock(
        std.testing.allocator,
        &frame,
        payload,
        true,
        &literal_lens,
        &offsets,
        &match_lens,
        &literal_ends,
        payload.len,
    ));

    const first_block = try inspectNativeFrameFirstBlock(frame.items);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    try std.testing.expectEqual(estimated_payload_len, first_block.payload_len);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(frame.items[first_block.payload_offset..][0..first_block.payload_len], &frame_state);
    try std.testing.expectEqual(@as(usize, 2), section.sequence_count);
    try std.testing.expectEqual(@as(u8, 0x54), frame.items[first_block.payload_offset + section.sequence_payload_offset]);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "zstd literal-only writer emits predefined repeated-pattern sequences" {
    const payload = ("ab" ** 12) ++ ("cdef" ** 20) ++ "tail";
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expect(section.sequence_count >= 1);
    if (section.sequence_count > 1) try std.testing.expectEqual(@as(u8, 0x00), block[section.sequence_payload_offset]);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits several repeated-pattern sequences" {
    const payload = ("ab" ** 12) ++ ("cd" ** 12) ++ ("ef" ** 12);
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    const block = encoded[block_offset + 3 ..][0..block_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(@as(usize, 3), section.sequence_count);
    const literal_lens = [_]usize{ 2, 2, 2 };
    const offsets = [_]usize{ 2, 2, 2 };
    const match_lens = [_]usize{ 22, 22, 22 };
    const expected_payload_len = try rleSequencePayloadLen(
        payload,
        &literal_lens,
        &offsets,
        &match_lens,
        payload.len,
        try sequenceCodeForValue(literal_lens[0], &ll_base, &ll_bits),
        try sequenceCodeForValue(offsets[0], &of_base, &of_bits),
        try sequenceCodeForValue(match_lens[0], &ml_base, &ml_bits),
    );
    const first_candidate = repeatedMixedMatchCandidate(payload, 0) orelse return error.CorruptFrame;
    const lookahead_payload_len = (try mixedCandidateLookaheadPayloadLen(&.{}, payload, 0, first_candidate)) orelse return error.CorruptFrame;
    try std.testing.expectEqual(expected_payload_len, lookahead_payload_len);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits many repeated-pattern sequences" {
    const payload =
        ("ab" ** 12) ++ ("cd" ** 12) ++ ("ef" ** 12) ++ ("gh" ** 12) ++
        ("ij" ** 12) ++ ("kl" ** 12) ++ ("mn" ** 12) ++ ("op" ** 12) ++
        ("qr" ** 12) ++ ("st" ** 12);
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded[block_offset + 3 ..][0..block_len], &frame_state);
    try std.testing.expectEqual(@as(usize, 10), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits more than sixteen repeated-pattern sequences" {
    const patterns = [_][]const u8{
        "ab", "cd", "ef", "gh", "ij", "kl", "mn", "op", "qr", "st",
        "uv", "wx", "yz", "AB", "CD", "EF", "GH", "IJ", "KL", "MN",
    };
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(std.testing.allocator);
    for (patterns) |pattern| {
        for (0..12) |_| try payload.appendSlice(std.testing.allocator, pattern);
    }

    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload.items);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload.items);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded[block_offset + 3 ..][0..block_len], &frame_state);
    try std.testing.expectEqual(patterns.len, section.sequence_count);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload.items, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd literal-only writer emits multi-sequence literal extra bits" {
    const payload = ("p" ** 14) ++ ("ab" ** 12) ++ ("q" ** 15) ++ ("cd" ** 12);
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded[block_offset + 3 ..][0..block_len], &frame_state);
    try std.testing.expectEqual(@as(usize, 2), section.sequence_count);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < raw_encoded.len);
}

test "zstd native frame writer chooses smallest fallback mode" {
    const repeated = "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz";
    const repeated_result = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, repeated, .{});
    defer std.testing.allocator.free(repeated_result.frame);
    try std.testing.expectEqual(NativeFrameMode.raw_or_rle, repeated_result.mode);
    const repeated_decoded = try decodeNativeFrameAlloc(std.testing.allocator, repeated_result.frame);
    defer std.testing.allocator.free(repeated_decoded);
    try std.testing.expectEqualSlices(u8, repeated, repeated_decoded);
    const repeated_exact_decoded = try decodeNativeFrameAllocExactSize(std.testing.allocator, repeated_result.frame, repeated.len);
    defer std.testing.allocator.free(repeated_exact_decoded);
    try std.testing.expectEqualSlices(u8, repeated, repeated_exact_decoded);
    try std.testing.expectError(error.SizeMismatch, decodeNativeFrameAllocExactSize(std.testing.allocator, repeated_result.frame, repeated.len - 1));
    try std.testing.expectError(error.SizeMismatch, decodeNativeFrameAllocExactSize(std.testing.allocator, repeated_result.frame, repeated.len + 1));

    const literal_payload = "literal-only zstd payload";
    const auto_result = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, literal_payload, .{});
    defer std.testing.allocator.free(auto_result.frame);
    const forced_literal = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, literal_payload, .{ .selection = .literal_only });
    defer std.testing.allocator.free(forced_literal.frame);
    try std.testing.expect(auto_result.frame.len <= forced_literal.frame.len);
    try std.testing.expectEqual(NativeFrameMode.literal_only, forced_literal.mode);
    const literal_decoded = try decodeNativeFrameAlloc(std.testing.allocator, forced_literal.frame);
    defer std.testing.allocator.free(literal_decoded);
    try std.testing.expectEqualSlices(u8, literal_payload, literal_decoded);

    const forced_raw = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, literal_payload, .{ .selection = .raw_or_rle });
    defer std.testing.allocator.free(forced_raw.frame);
    try std.testing.expectEqual(NativeFrameMode.raw_or_rle, forced_raw.mode);
    var forced_raw_append: std.ArrayList(u8) = .empty;
    defer forced_raw_append.deinit(std.testing.allocator);
    try encodeRawOrRleFrameAppend(std.testing.allocator, &forced_raw_append, literal_payload, .{ .selection = .raw_or_rle });
    try std.testing.expectEqualSlices(u8, forced_raw.frame, forced_raw_append.items);

    var forced_literal_append: std.ArrayList(u8) = .empty;
    defer forced_literal_append.deinit(std.testing.allocator);
    const forced_literal_mode = try encodeNativeFrameAppend(
        std.testing.allocator,
        &forced_literal_append,
        literal_payload,
        .{ .selection = .literal_only },
    );
    try std.testing.expectEqual(NativeFrameMode.literal_only, forced_literal_mode);
    try std.testing.expectEqualSlices(u8, forced_literal.frame, forced_literal_append.items);

    const no_checksum = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, literal_payload, .{ .content_checksum = false, .selection = .literal_only });
    defer std.testing.allocator.free(no_checksum.frame);
    try std.testing.expectEqual(@as(u8, 0x20), no_checksum.frame[4]);
    const no_size = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, literal_payload, .{ .include_content_size = false, .selection = .literal_only });
    defer std.testing.allocator.free(no_size.frame);
    try std.testing.expectEqual(@as(u8, 0x04), no_size.frame[4]);
    const no_size_decoded = try decodeNativeFrameAlloc(std.testing.allocator, no_size.frame);
    defer std.testing.allocator.free(no_size_decoded);
    try std.testing.expectEqualSlices(u8, literal_payload, no_size_decoded);

    const duplicate_payload = "prefix-abcdefghijklmno-middle-abcdefghijklmno-tail";
    const duplicate_result = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, duplicate_payload, .{});
    defer std.testing.allocator.free(duplicate_result.frame);
    try std.testing.expectEqual(NativeFrameMode.literal_only, duplicate_result.mode);
    try std.testing.expect(duplicate_result.frame.len <= try encodedNativeFrameBound(duplicate_payload.len));
    try std.testing.expect(duplicate_result.frame.len <= try encodedNativeFrameBoundWithOptions(duplicate_payload.len, .{
        .selection = .literal_only,
    }));
    const duplicate_decoded = try decodeNativeFrameAlloc(std.testing.allocator, duplicate_result.frame);
    defer std.testing.allocator.free(duplicate_decoded);
    try std.testing.expectEqualSlices(u8, duplicate_payload, duplicate_decoded);
    var reusable_encoder = NativeFrameEncoder.init(std.testing.allocator);
    defer reusable_encoder.deinit();
    const reusable_encoded = try reusable_encoder.encodeScratch(duplicate_payload, .{});
    try std.testing.expectEqual(duplicate_result.mode, reusable_encoded.mode);
    try std.testing.expectEqualSlices(u8, duplicate_result.frame, reusable_encoded.frame);
    const reusable_forced_raw = try reusable_encoder.encodeScratch(duplicate_payload, .{ .selection = .raw_or_rle });
    try std.testing.expectEqual(NativeFrameMode.raw_or_rle, reusable_forced_raw.mode);
    const reusable_forced_raw_decoded = try decodeNativeFrameAlloc(std.testing.allocator, reusable_forced_raw.frame);
    defer std.testing.allocator.free(reusable_forced_raw_decoded);
    try std.testing.expectEqualSlices(u8, duplicate_payload, reusable_forced_raw_decoded);
    var duplicate_appended: std.ArrayList(u8) = .empty;
    defer duplicate_appended.deinit(std.testing.allocator);
    try duplicate_appended.appendSlice(std.testing.allocator, "prefix:");
    const duplicate_appended_written = try decodeNativeFrameAppend(std.testing.allocator, &duplicate_appended, duplicate_result.frame);
    try std.testing.expectEqual(duplicate_payload.len, duplicate_appended_written);
    try std.testing.expectEqualSlices(u8, "prefix:", duplicate_appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, duplicate_payload, duplicate_appended.items["prefix:".len..]);
    duplicate_appended.clearRetainingCapacity();
    try duplicate_appended.appendSlice(std.testing.allocator, "prefix:");
    const duplicate_appended_limited_written = try decodeNativeFrameAppendLimited(std.testing.allocator, &duplicate_appended, duplicate_result.frame, duplicate_payload.len);
    try std.testing.expectEqual(duplicate_payload.len, duplicate_appended_limited_written);
    try std.testing.expectEqualSlices(u8, "prefix:", duplicate_appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, duplicate_payload, duplicate_appended.items["prefix:".len..]);
    duplicate_appended.clearRetainingCapacity();
    try duplicate_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectError(error.OutputLimitExceeded, decodeNativeFrameAppendLimited(std.testing.allocator, &duplicate_appended, duplicate_result.frame, duplicate_payload.len - 1));
    try std.testing.expectEqualSlices(u8, "prefix:", duplicate_appended.items);
    var reusable_decoder = NativeFrameDecoder.init(std.testing.allocator);
    defer reusable_decoder.deinit();
    const reusable_decoded = try reusable_decoder.decodeAlloc(duplicate_result.frame);
    defer std.testing.allocator.free(reusable_decoded);
    try std.testing.expectEqualSlices(u8, duplicate_payload, reusable_decoded);
    const reusable_scratch = try reusable_decoder.decodeScratch(duplicate_result.frame);
    try std.testing.expectEqualSlices(u8, duplicate_payload, reusable_scratch);
    const reusable_scratch_limited = try reusable_decoder.decodeScratchLimited(duplicate_result.frame, duplicate_payload.len);
    try std.testing.expectEqualSlices(u8, duplicate_payload, reusable_scratch_limited);
    try std.testing.expectError(error.OutputLimitExceeded, reusable_decoder.decodeScratchLimited(duplicate_result.frame, duplicate_payload.len - 1));
    try std.testing.expectEqual(@as(usize, 0), reusable_decoder.scratch.items.len);
    duplicate_appended.clearRetainingCapacity();
    try duplicate_appended.appendSlice(std.testing.allocator, "prefix:");
    const reusable_append_written = try reusable_decoder.decodeAppendLimited(&duplicate_appended, duplicate_result.frame, duplicate_payload.len);
    try std.testing.expectEqual(duplicate_payload.len, reusable_append_written);
    try std.testing.expectEqualSlices(u8, duplicate_payload, duplicate_appended.items["prefix:".len..]);
    const reusable_alloc_limited = try reusable_decoder.decodeAllocLimited(duplicate_result.frame, duplicate_payload.len);
    defer std.testing.allocator.free(reusable_alloc_limited);
    try std.testing.expectEqualSlices(u8, duplicate_payload, reusable_alloc_limited);
    const reusable_into = try std.testing.allocator.alloc(u8, duplicate_payload.len);
    defer std.testing.allocator.free(reusable_into);
    const reusable_into_written = try reusable_decoder.decodeIntoSlice(duplicate_result.frame, reusable_into);
    try std.testing.expectEqual(duplicate_payload.len, reusable_into_written);
    try std.testing.expectEqualSlices(u8, duplicate_payload, reusable_into);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    const appended_mode = try encodeNativeFrameAppend(std.testing.allocator, &appended, duplicate_payload, .{});
    try std.testing.expectEqual(duplicate_result.mode, appended_mode);
    try std.testing.expectEqualSlices(u8, duplicate_result.frame, appended.items);
    const appended_decoded = try decodeNativeFrameAlloc(std.testing.allocator, appended.items);
    defer std.testing.allocator.free(appended_decoded);
    try std.testing.expectEqualSlices(u8, duplicate_payload, appended_decoded);
    const one_shot_into = try std.testing.allocator.alloc(u8, try encodedNativeFrameBound(duplicate_payload.len));
    defer std.testing.allocator.free(one_shot_into);
    const one_shot_into_result = try encodeNativeFrameIntoSlice(std.testing.allocator, duplicate_payload, .{}, one_shot_into);
    try std.testing.expectEqual(duplicate_result.mode, one_shot_into_result.mode);
    try std.testing.expectEqualSlices(u8, duplicate_result.frame, one_shot_into[0..one_shot_into_result.written]);

    var reusable_out: std.ArrayList(u8) = .empty;
    defer reusable_out.deinit(std.testing.allocator);
    const reusable_mode = try reusable_encoder.encodeAppend(&reusable_out, duplicate_payload, .{});
    try std.testing.expectEqual(duplicate_result.mode, reusable_mode);
    try std.testing.expectEqualSlices(u8, duplicate_result.frame, reusable_out.items);
    const reusable_owned = try reusable_encoder.encodeWithOptionsAlloc(duplicate_payload, .{});
    defer std.testing.allocator.free(reusable_owned.frame);
    try std.testing.expectEqual(duplicate_result.mode, reusable_owned.mode);
    try std.testing.expectEqualSlices(u8, duplicate_result.frame, reusable_owned.frame);
    const into_buffer = try std.testing.allocator.alloc(u8, duplicate_result.frame.len);
    defer std.testing.allocator.free(into_buffer);
    const into_result = try reusable_encoder.encodeIntoSlice(duplicate_payload, .{}, into_buffer);
    try std.testing.expectEqual(duplicate_result.mode, into_result.mode);
    try std.testing.expectEqual(duplicate_result.frame.len, into_result.written);
    try std.testing.expectEqualSlices(u8, duplicate_result.frame, into_buffer[0..into_result.written]);
    try std.testing.expectError(error.OutputTooSmall, reusable_encoder.encodeIntoSlice(duplicate_payload, .{}, into_buffer[0 .. into_buffer.len - 1]));
    reusable_out.clearRetainingCapacity();
    const reusable_raw_mode = try reusable_encoder.encodeAppend(&reusable_out, repeated, .{ .selection = .raw_or_rle });
    try std.testing.expectEqual(NativeFrameMode.raw_or_rle, reusable_raw_mode);
    const reusable_raw_decoded = try decodeNativeFrameAlloc(std.testing.allocator, reusable_out.items);
    defer std.testing.allocator.free(reusable_raw_decoded);
    try std.testing.expectEqualSlices(u8, repeated, reusable_raw_decoded);
}

test "zstd native incremental decoder accepts split input and output" {
    const payload = "incremental zstd native payload " ** 4;
    const encoded = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer std.testing.allocator.free(encoded.frame);

    var decoder = NativeIncrementalFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const chunks = [_][]const u8{
        encoded.frame[0..4],
        encoded.frame[4..13],
        encoded.frame[13..],
    };

    const first = try decoder.step(chunks[0], output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_input, first.status);
    try std.testing.expectEqual(chunks[0].len, first.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), first.progress.output_written);
    try std.testing.expectEqual(NativeIncrementalFrameDecoder.Phase.frame, decoder.snapshot().phase);

    const second = try decoder.step(chunks[1], output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_input, second.status);
    try std.testing.expectEqual(chunks[1].len, second.progress.input_read);

    const third = try decoder.step(chunks[2], output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, third.status);
    try std.testing.expectEqual(chunks[2].len, third.progress.input_read);
    try std.testing.expectEqual(encoded.frame.len, decoder.snapshot().input_received);
    try std.testing.expectEqual(payload.len, decoder.snapshot().decoded_len.?);

    var written: usize = 0;
    while (true) {
        const end = @min(output.len, written + 9);
        const result = try decoder.step("", output[written..end]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(NativeIncrementalFrameDecoder.Phase.done, decoder.snapshot().phase);
    try std.testing.expectEqual(payload.len, decoder.diagnostics().output_written);
    try std.testing.expectEqual(core.StepResult.Status.done, (try decoder.step("", output[0..0])).status);

    decoder.reset();
    const reused = try decoder.step(encoded.frame, &output);
    try std.testing.expectEqual(core.StepResult.Status.done, reused.status);
    try std.testing.expectEqual(encoded.frame.len, reused.progress.input_read);
    try std.testing.expectEqual(payload.len, reused.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "zstd native incremental decoder streams raw blocks without decoded scratch" {
    const payload = try std.testing.allocator.alloc(u8, 3000);
    defer std.testing.allocator.free(payload);
    var state: u32 = 0x4567_89ab;
    for (payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }

    const encoded = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .raw_or_rle,
        .content_checksum = true,
        .block_size_max = 1024,
    });
    defer std.testing.allocator.free(encoded.frame);
    try std.testing.expectEqual(NativeFrameMode.raw_or_rle, encoded.mode);
    const first_block = try inspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(NativeBlockType.raw, first_block.block_type);
    var second_seen = false;
    var block_iter = try iterateNativeFrameBlocks(encoded.frame);
    while (try block_iter.next()) |block| {
        try std.testing.expectEqual(NativeBlockType.raw, block.block_type);
        if (block.header_offset != first_block.header_offset) second_seen = true;
    }
    try std.testing.expect(second_seen);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    const initial = try decoder.step(encoded.frame, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(?usize, payload.len), decoder.snapshot().decoded_len);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var written: usize = 0;
    while (true) {
        const end = @min(output.len, written + 333);
        const result = try decoder.step("", output[written..end]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var corrupt = try std.testing.allocator.dupe(u8, encoded.frame);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 0x01;
    var bad = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .max_decoded_buffer_len = payload.len,
    });
    defer bad.deinit();
    try std.testing.expectError(error.ChecksumMismatch, bad.step(corrupt, output[0..0]));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", bad.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", bad.diagnostics().last_error_phase_name);
}

test "zstd native incremental decoder streams RLE blocks without decoded scratch" {
    const payload = "Z" ** 4096;
    const encoded = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .raw_or_rle,
        .content_checksum = true,
        .block_size_max = 1024,
    });
    defer std.testing.allocator.free(encoded.frame);
    try std.testing.expectEqual(NativeFrameMode.raw_or_rle, encoded.mode);
    var block_iter = try iterateNativeFrameBlocks(encoded.frame);
    var block_count: usize = 0;
    while (try block_iter.next()) |block| {
        block_count += 1;
        try std.testing.expectEqual(NativeBlockType.rle, block.block_type);
    }
    try std.testing.expect(block_count > 1);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded.frame, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(?usize, payload.len), decoder.snapshot().decoded_len);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    var written: usize = 0;
    while (true) {
        const end = @min(output.len, written + 257);
        const result = try decoder.step("", output[written..end]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var corrupt = try std.testing.allocator.dupe(u8, encoded.frame);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 0x01;
    var bad = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .max_decoded_buffer_len = payload.len,
    });
    defer bad.deinit();
    try std.testing.expectError(error.ChecksumMismatch, bad.step(corrupt, output[0..0]));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", bad.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", bad.diagnostics().last_error_phase_name);
}

test "zstd native incremental decoder streams single compressed block without decoded scratch" {
    const payload = ("0123456789abcdef" ** 8) ** 64;
    const encoded = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = true,
    });
    defer std.testing.allocator.free(encoded.frame);
    try std.testing.expectEqual(NativeFrameMode.literal_only, encoded.mode);
    const first_block = try inspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    try std.testing.expect(first_block.last);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded.frame, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(?usize, payload.len), decoder.snapshot().decoded_len);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    const decoded = try decoder.step("", &output);
    try std.testing.expectEqual(core.StepResult.Status.done, decoded.status);
    try std.testing.expectEqual(payload.len, decoded.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var corrupt = try std.testing.allocator.dupe(u8, encoded.frame);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 0x01;
    var bad = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer bad.deinit();
    const bad_initial = try bad.step(corrupt, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, bad_initial.status);
    try std.testing.expectError(error.ChecksumMismatch, bad.step("", &output));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", bad.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", bad.diagnostics().last_error_phase_name);
}

test "zstd native incremental decoder streams no-size compressed frame directly" {
    const payload = ("zstd-nosize-direct" ** 8) ** 64;
    const encoded = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .include_content_size = false,
        .selection = .literal_only,
        .content_checksum = true,
    });
    defer std.testing.allocator.free(encoded.frame);
    const header = try inspectNativeFrameHeader(encoded.frame);
    try std.testing.expectEqual(@as(?u64, null), header.content_size);
    const first_block = try inspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded.frame, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(?usize, payload.len), decoder.snapshot().decoded_len);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    const decoded = try decoder.step("", &output);
    try std.testing.expectEqual(core.StepResult.Status.done, decoded.status);
    try std.testing.expectEqual(payload.len, decoded.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var corrupt = try std.testing.allocator.dupe(u8, encoded.frame);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 0x01;
    var bad = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .max_decoded_buffer_len = payload.len,
    });
    defer bad.deinit();
    const bad_initial = try bad.step(corrupt, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, bad_initial.status);
    try std.testing.expectError(error.ChecksumMismatch, bad.step("", &output));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", bad.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", bad.diagnostics().last_error_phase_name);
}

test "zstd native incremental compressed block falls back for small output" {
    const payload = ("fedcba9876543210" ** 8) ** 64;
    const encoded = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer std.testing.allocator.free(encoded.frame);
    const first_block = try inspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    try std.testing.expect(first_block.last);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded.frame, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var written: usize = 0;
    while (true) {
        const end = @min(output.len, written + 113);
        const result = try decoder.step("", output[written..end]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
        if (decoder.decoded_scratch.items.len != 0) {
            // A compressed block cannot be partially decoded directly without a
            // resumable block decoder, so small caller buffers intentionally
            // fall back to the mature whole-frame scratch path.
            try std.testing.expectEqual(payload.len, decoder.decoded_scratch.items.len);
        }
    }
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(payload.len, decoder.diagnostics().output_written);
}

test "zstd native incremental compressed checksum validates directly" {
    const payload = ("content-checksum-zstd" ** 4) ** 64;
    const encoded = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = true,
    });
    defer std.testing.allocator.free(encoded.frame);
    const header = try inspectNativeFrameHeader(encoded.frame);
    try std.testing.expect(header.has_checksum);
    const first_block = try inspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    try std.testing.expect(first_block.last);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded.frame, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    const decoded = try decoder.step("", &output);
    try std.testing.expectEqual(core.StepResult.Status.done, decoded.status);
    try std.testing.expectEqual(payload.len, decoded.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, &output);

    var corrupt = try std.testing.allocator.dupe(u8, encoded.frame);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 0x01;
    var bad = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer bad.deinit();
    const bad_initial = try bad.step(corrupt, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, bad_initial.status);
    try std.testing.expectError(error.ChecksumMismatch, bad.step("", &output));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", bad.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", bad.diagnostics().last_error_phase_name);
}

test "zstd native incremental decoder streams multiple compressed blocks directly" {
    const payload = "a" ** 264;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});

    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, false);
    try frame.append(std.testing.allocator, (1 << 3) | 1);
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1);
    try frame.append(std.testing.allocator, 0x50); // LL/OF are RLE tables; ML uses the default predefined table.
    try frame.appendSlice(std.testing.allocator, &.{ 1, 0 });
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x2a });

    try emitBlockHeader(std.testing.allocator, &frame, 2, 6, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1);
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1);
    try frame.append(std.testing.allocator, 0xfc); // Repeat_Mode for LL, OF, and ML.
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x2a });
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    var block_iter = try iterateNativeFrameBlocks(frame.items);
    const first_block = (try block_iter.next()) orelse return error.CorruptFrame;
    const second_block = (try block_iter.next()) orelse return error.CorruptFrame;
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    try std.testing.expectEqual(NativeBlockType.compressed, second_block.block_type);
    try std.testing.expect(second_block.last);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(frame.items, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(?usize, payload.len), decoder.snapshot().decoded_len);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    const decoded = try decoder.step("", &output);
    try std.testing.expectEqual(core.StepResult.Status.done, decoded.status);
    try std.testing.expectEqual(payload.len, decoded.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var corrupt = try std.testing.allocator.dupe(u8, frame.items);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 0x01;
    var bad = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer bad.deinit();
    const bad_initial = try bad.step(corrupt, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, bad_initial.status);
    try std.testing.expectError(error.ChecksumMismatch, bad.step("", &output));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", bad.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", bad.diagnostics().last_error_phase_name);
}

test "zstd native incremental multi compressed keeps direct history across output chunks" {
    const payload = "a" ** 264;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{ .content_checksum = false });

    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, false);
    try frame.append(std.testing.allocator, (1 << 3) | 1);
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1);
    try frame.append(std.testing.allocator, 0x50);
    try frame.appendSlice(std.testing.allocator, &.{ 1, 0 });
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x2a });

    try emitBlockHeader(std.testing.allocator, &frame, 2, 6, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1);
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1);
    try frame.append(std.testing.allocator, 0xfc);
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x2a });

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(frame.items, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var written: usize = 0;
    while (true) {
        const end = @min(output.len, written + 150);
        const result = try decoder.step("", output[written..end]);
        written += result.progress.output_written;
        try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
}

test "zstd native incremental decoder drains concatenated streams and skippable frames" {
    const first_payload = "incremental zstd first stream member " ** 2;
    const second_payload = "incremental zstd second stream member " ** 3;
    const third_payload = "incremental zstd third stream member";
    const options: NativeFrameOptions = .{ .selection = .literal_only, .content_checksum = false };

    const first = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, first_payload, options);
    defer std.testing.allocator.free(first.frame);
    const second = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, second_payload, options);
    defer std.testing.allocator.free(second.frame);
    const third = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, third_payload, options);
    defer std.testing.allocator.free(third.frame);
    const skip = try encodeSkippableFrameAlloc(std.testing.allocator, 7, "incremental metadata");
    defer std.testing.allocator.free(skip);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first.frame);
    try stream.appendSlice(std.testing.allocator, skip);
    try stream.appendSlice(std.testing.allocator, second.frame);
    try stream.appendSlice(std.testing.allocator, skip);

    var decoder = NativeIncrementalFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    var output: [first_payload.len + second_payload.len]u8 = undefined;
    const initial = try decoder.step(stream.items, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(stream.items.len, initial.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), initial.progress.output_written);

    var written: usize = 0;
    while (true) {
        const end = @min(output.len, written + 13);
        const result = try decoder.step("", output[written..end]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqual(output.len, written);
    try std.testing.expectEqualSlices(u8, first_payload, output[0..first_payload.len]);
    try std.testing.expectEqualSlices(u8, second_payload, output[first_payload.len..]);
    try std.testing.expectEqual(output.len, decoder.diagnostics().output_written);

    var continued: [third_payload.len]u8 = undefined;
    const continued_result = try decoder.step(third.frame, &continued);
    try std.testing.expectEqual(core.StepResult.Status.done, continued_result.status);
    try std.testing.expectEqual(third.frame.len, continued_result.progress.input_read);
    try std.testing.expectEqual(third_payload.len, continued_result.progress.output_written);
    try std.testing.expectEqualSlices(u8, third_payload, &continued);
    try std.testing.expectEqual(stream.items.len + third.frame.len, decoder.snapshot().input_received);
    try std.testing.expectEqual(output.len + third_payload.len, decoder.diagnostics().output_written);
}

test "zstd native incremental decoder enforces buffer limits" {
    const payload = "bounded incremental zstd payload " ** 8;
    const encoded = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer std.testing.allocator.free(encoded.frame);

    var compressed_limited = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .max_compressed_buffer_len = encoded.frame.len - 1,
    });
    defer compressed_limited.deinit();
    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, compressed_limited.step(encoded.frame, output[0..0]));
    try std.testing.expectEqual(encoded.frame.len - 1, compressed_limited.snapshot().input_received);
    try std.testing.expectEqualSlices(u8, "OutputLimitExceeded", compressed_limited.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", compressed_limited.diagnostics().last_error_phase_name);

    var decoded_limited = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .max_decoded_buffer_len = payload.len - 1,
    });
    defer decoded_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, decoded_limited.step(encoded.frame, &output));
    try std.testing.expectEqual(encoded.frame.len, decoded_limited.snapshot().input_received);
    try std.testing.expectEqualSlices(u8, "OutputLimitExceeded", decoded_limited.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", decoded_limited.diagnostics().last_error_phase_name);
}

test "zstd native incremental decoder enforces exact output size" {
    const payload = "exact incremental zstd payload " ** 3;
    const encoded = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer std.testing.allocator.free(encoded.frame);

    var exact = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
    });
    defer exact.deinit();
    var output: [payload.len]u8 = undefined;
    var written: usize = 0;
    var result = try exact.step(encoded.frame[0 .. encoded.frame.len / 2], output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_input, result.status);
    result = try exact.step(encoded.frame[encoded.frame.len / 2 ..], output[0..11]);
    written += result.progress.output_written;
    while (result.status != .done) {
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
        const end = @min(output.len, written + 11);
        result = try exact.step("", output[written..end]);
        written += result.progress.output_written;
    }
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try exact.finish();

    var too_small = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len - 1,
    });
    defer too_small.deinit();
    try std.testing.expectError(error.SizeMismatch, too_small.step(encoded.frame, &output));
    try std.testing.expectEqualSlices(u8, "SizeMismatch", too_small.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", too_small.diagnostics().last_error_phase_name);

    var too_large = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len + 1,
    });
    defer too_large.deinit();
    _ = try too_large.step(encoded.frame, &output);
    const pending = try too_large.step("", output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_input, pending.status);
    try std.testing.expectError(error.SizeMismatch, too_large.finish());
    try std.testing.expectEqualSlices(u8, "SizeMismatch", too_large.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "output", too_large.diagnostics().last_error_phase_name);
}

test "zstd native incremental decoder supports dictionaries" {
    const dict = NativeDictionary.init(0x555a_4449, "abcdefghijklmnop");
    const payload = "pfx-abcdefghijklmnop-tail";
    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    }, dict);
    defer std.testing.allocator.free(encoded.frame);

    var output: [payload.len]u8 = undefined;
    var decoder = NativeIncrementalFrameDecoder.initWithDictionary(std.testing.allocator, dict);
    defer decoder.deinit();
    const result = try decoder.step(encoded.frame, &output);
    try std.testing.expectEqual(core.StepResult.Status.done, result.status);
    try std.testing.expectEqualSlices(u8, payload, &output);

    var missing = NativeIncrementalFrameDecoder.init(std.testing.allocator);
    defer missing.deinit();
    try std.testing.expectError(error.NeedDictionary, missing.step(encoded.frame, &output));
    const diagnostics = missing.diagnostics();
    try std.testing.expectEqualSlices(u8, "NeedDictionary", diagnostics.last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", diagnostics.last_error_phase_name);
}

test "zstd native incremental decoder streams dictionary compressed blocks directly" {
    const dict = NativeDictionary.init(0x555a_4450, "abcdefghijklmnop");
    const payload = "pfx-abcdefghijklmnop-tail";
    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = true,
    }, dict);
    defer std.testing.allocator.free(encoded.frame);

    const first_block = try inspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded.frame[first_block.payload_offset..][0..first_block.payload_len], &frame_state);
    try std.testing.expect(section.sequence_count > 0);

    var decoder = NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, dict, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded.frame, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    const decoded = try decoder.step("", &output);
    try std.testing.expectEqual(core.StepResult.Status.done, decoded.status);
    try std.testing.expectEqual(payload.len, decoded.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var corrupt = try std.testing.allocator.dupe(u8, encoded.frame);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 0x01;
    var bad = NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, dict, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer bad.deinit();
    const bad_initial = try bad.step(corrupt, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, bad_initial.status);
    try std.testing.expectError(error.ChecksumMismatch, bad.step("", &output));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", bad.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", bad.diagnostics().last_error_phase_name);

    var missing = NativeIncrementalFrameDecoder.init(std.testing.allocator);
    defer missing.deinit();
    try std.testing.expectError(error.NeedDictionary, missing.step(encoded.frame, output[0..0]));
    try std.testing.expectEqualSlices(u8, "NeedDictionary", missing.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", missing.diagnostics().last_error_phase_name);
}

test "zstd native incremental dictionary-set streams directly" {
    const first_dict = NativeDictionary.init(0x6234, "abcdefghijklmnop");
    const second_dict = NativeDictionary.init(0x6678, "QRSTUVWXYZabcd1234");
    const dictionaries = [_]NativeDictionary{ first_dict, second_dict };
    const dictionary_set = NativeDictionarySet.init(&dictionaries);
    const options: NativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };
    const first_payload = "pfx-abcdefghijklmnop-tail";
    const second_payload = "pfx-QRSTUVWXYZabcd1234-tail";
    const first = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, first_payload, options, first_dict);
    defer std.testing.allocator.free(first.frame);
    const skip = try encodeSkippableFrameAlloc(std.testing.allocator, 11, "direct-set");
    defer std.testing.allocator.free(skip);
    const second = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, second_payload, options, second_dict);
    defer std.testing.allocator.free(second.frame);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first.frame);
    try stream.appendSlice(std.testing.allocator, skip);
    try stream.appendSlice(std.testing.allocator, second.frame);

    const expected = first_payload ++ second_payload;
    var decoder = NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, dictionary_set, .{
        .expected_output_len = expected.len,
        .max_decoded_buffer_len = @max(first_payload.len, second_payload.len),
    });
    defer decoder.deinit();
    var output: [expected.len]u8 = undefined;
    const initial = try decoder.step(stream.items, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(stream.items.len, initial.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    const done = try decoder.step("", &output);
    try std.testing.expectEqual(core.StepResult.Status.done, done.status);
    try std.testing.expectEqual(expected.len, done.progress.output_written);
    try std.testing.expectEqualSlices(u8, expected, &output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
}

test "zstd raw/RLE native decoder rejects corrupt frames" {
    const payload = "zstd raw/rle corrupt frame payload";
    const encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);

    var bad_size = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_size);
    bad_size[5] = @intCast(payload.len + 1);
    try std.testing.expectError(error.SizeMismatch, decodeRawOrRleFrameAlloc(std.testing.allocator, bad_size));

    var bad_checksum = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_checksum);
    bad_checksum[bad_checksum.len - 1] ^= 0x01;
    try std.testing.expectError(error.ChecksumMismatch, decodeRawOrRleFrameAlloc(std.testing.allocator, bad_checksum));

    var compressed_block = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(compressed_block);
    compressed_block[6] = (compressed_block[6] & ~@as(u8, 0x06)) | 0x04;
    try std.testing.expectError(error.TruncatedFrame, decodeRawOrRleFrameAlloc(std.testing.allocator, compressed_block));

    try std.testing.expectError(error.TruncatedFrame, decodeRawOrRleFrameAlloc(std.testing.allocator, encoded[0 .. encoded.len - 1]));
    try std.testing.expectError(error.InvalidMagic, decodeRawOrRleFrameAlloc(std.testing.allocator, "not-zstd"));
}

test "zstd native writer emits dictionary ids" {
    const encoded = try encodeRawOrRleFrameWithOptionsAlloc(
        std.testing.allocator,
        "abc",
        .{ .content_checksum = false, .dictionary_id = 0x1234 },
    );
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqual(@as(u8, 0x22), encoded[4]); // 2-byte Dictionary_ID, single segment, 1-byte content size.
    try std.testing.expectEqual(@as(u16, 0x1234), std.mem.readInt(u16, encoded[5..7], .little));
    try std.testing.expectEqual(@as(u8, 3), encoded[7]);
    const header = try inspectNativeFrameHeader(encoded);
    try std.testing.expectEqual(@as(u32, 0x1234), header.dictionary_id);
    try std.testing.expectEqual(@as(?u64, 3), header.content_size);
    try std.testing.expectEqual(@as(usize, 8), header.payload_offset);
    try std.testing.expect(encoded.len <= try encodedNativeFrameBoundWithOptions(3, .{ .content_checksum = false, .dictionary_id = 0x1234 }));
    try std.testing.expectError(error.NeedDictionary, decodeNativeFrameAlloc(std.testing.allocator, encoded));

    const no_size = try encodeRawOrRleFrameWithOptionsAlloc(
        std.testing.allocator,
        "abc",
        .{ .content_checksum = false, .include_content_size = false, .dictionary_id = 0x7f },
    );
    defer std.testing.allocator.free(no_size);
    try std.testing.expectEqual(@as(u8, 0x01), no_size[4]); // 1-byte Dictionary_ID, no content size.
    try std.testing.expectEqual(@as(u8, 0x00), no_size[5]); // Window descriptor for tiny payloads.
    try std.testing.expectEqual(@as(u8, 0x7f), no_size[6]);
    const no_size_header = try inspectNativeFrameHeader(no_size);
    try std.testing.expectEqual(@as(u32, 0x7f), no_size_header.dictionary_id);
    try std.testing.expectEqual(@as(?u64, null), no_size_header.content_size);
    try std.testing.expectEqual(@as(usize, 7), no_size_header.payload_offset);
    try std.testing.expectError(error.NeedDictionary, decodedRawOrRleFrameSize(no_size));
    try std.testing.expectError(error.InvalidMagic, inspectNativeFrameHeader("not-zstd"));
}

test "zstd native dictionary can derive stable non-zero ids from content" {
    const dict = NativeDictionary.initFromContent("abcdefghijklmnopQRSTUVWXYZabcd");
    try std.testing.expectEqual(checksum_mod.crc32(dict.content), dict.id);
    try std.testing.expectEqual(dict.id, NativeDictionary.derivedId(dict.content));
    try std.testing.expectEqual(dict.id, NativeDictionary.initFromContent(dict.content).id);
    try std.testing.expectEqual(@as(u32, 1), NativeDictionary.derivedId(""));
    try std.testing.expectEqual(@as(u32, 1), NativeDictionary.initFromContent("").id);
}

test "zstd native dictionary training returns owned bytes and stable id" {
    const samples = [_][]const u8{
        "trained-zstd-prefix alpha trained-zstd-tail",
        "trained-zstd-prefix beta trained-zstd-tail",
        "trained-zstd-prefix gamma trained-zstd-tail",
    };
    const trained = try trainNativeDictionaryAlloc(std.testing.allocator, &samples, .{
        .target_size = 64,
        .min_phrase_len = 4,
        .max_phrase_len = 18,
        .max_phrases = 96,
    });
    defer trained.deinit(std.testing.allocator);
    const dict = trained.asDictionary();
    const metadata = trained.metadata();
    try std.testing.expectEqual(NativeDictionary.derivedId(dict.content), dict.id);
    try std.testing.expectEqual(dictionary_mod.DictionaryId.fromBytes(dict.content).asInt(), metadata.id.asInt());
    try std.testing.expectEqual(dict.content.len, metadata.content_len);
    try std.testing.expectEqual(@as(usize, native_dictionary_window_len), metadata.window_len);
    const metadata_dict = try NativeDictionary.initFromMetadata(metadata, dict.content);
    try std.testing.expectEqual(dict.id, metadata_dict.id);
    try std.testing.expectEqualSlices(u8, dict.content, metadata_dict.content);
    try std.testing.expectError(error.InvalidDictionaryMetadata, NativeDictionary.initFromMetadata(metadata, "wrong"));
    try std.testing.expect(dict.content.len > 0);
    try std.testing.expect(dict.content.len <= 64);

    const payload = "pfx-trained-zstd-prefix alpha trained-zstd-tail payload";
    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    }, dict);
    defer std.testing.allocator.free(encoded.frame);
    const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, encoded.frame, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "zstd native decoder rejects dictionary id frames without a dictionary" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try frame.appendSlice(std.testing.allocator, &frame_magic);
    try frame.append(std.testing.allocator, 0x21); // 1-byte dictionary id, single-segment, 1-byte content size.
    try frame.append(std.testing.allocator, 7); // Dictionary_ID; callers must provide a matching NativeDictionary.
    try frame.append(std.testing.allocator, 3);
    try emitRawBlock(std.testing.allocator, &frame, "abc", true);

    try std.testing.expectError(error.NeedDictionary, decodeNativeFrameAlloc(std.testing.allocator, frame.items));

    var output: [3]u8 = undefined;
    try std.testing.expectError(error.NeedDictionary, decodeNativeFrameInto(frame.items, &output));
    try std.testing.expectError(error.NeedDictionary, decodedRawOrRleFrameSize(frame.items));
    const dict = NativeDictionary.init(7, "dictionary history");
    const wrong_dict = NativeDictionary.init(8, "dictionary history");
    try std.testing.expectError(error.NeedDictionary, decodeNativeFrameAllocWithDictionary(std.testing.allocator, frame.items, wrong_dict));
    const dict_decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, frame.items, dict);
    defer std.testing.allocator.free(dict_decoded);
    try std.testing.expectEqualSlices(u8, "abc", dict_decoded);
    try std.testing.expectEqual(@as(usize, 3), try decodedNativeFrameSizeWithDictionary(frame.items, dict));
    try std.testing.expectEqual(@as(usize, 3), try decodedNativeFrameSizeLimitedWithDictionary(frame.items, 3, dict));
    try std.testing.expectError(error.OutputLimitExceeded, decodedNativeFrameSizeLimitedWithDictionary(frame.items, 2, dict));
    var dict_into: [3]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 3), try decodeNativeFrameIntoWithDictionary(frame.items, &dict_into, dict));
    try std.testing.expectEqualSlices(u8, "abc", &dict_into);
    try std.testing.expectError(error.OutputTooSmall, decodeNativeFrameIntoWithDictionary(frame.items, dict_into[0..2], dict));
    var dict_appended: std.ArrayList(u8) = .empty;
    defer dict_appended.deinit(std.testing.allocator);
    try dict_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(@as(usize, 3), try decodeNativeFrameAppendWithDictionary(std.testing.allocator, &dict_appended, frame.items, dict));
    try std.testing.expectEqualSlices(u8, "prefix:abc", dict_appended.items);
    var reusable = NativeFrameDecoder.init(std.testing.allocator);
    defer reusable.deinit();
    const reusable_dict_decoded = try reusable.decodeScratchWithDictionary(frame.items, dict);
    try std.testing.expectEqualSlices(u8, "abc", reusable_dict_decoded);

    try std.testing.expectError(error.TruncatedFrame, decodeNativeFrameAlloc(std.testing.allocator, frame.items[0..5]));

    var zero_dict_frame: std.ArrayList(u8) = .empty;
    defer zero_dict_frame.deinit(std.testing.allocator);
    try zero_dict_frame.appendSlice(std.testing.allocator, &frame_magic);
    try zero_dict_frame.append(std.testing.allocator, 0x21); // 1-byte dictionary id field, single segment, 1-byte content size.
    try zero_dict_frame.append(std.testing.allocator, 0); // Dictionary_ID value 0 means no actual preset dictionary.
    try zero_dict_frame.append(std.testing.allocator, 3);
    try emitRawBlock(std.testing.allocator, &zero_dict_frame, "abc", true);

    const zero_dict_decoded = try decodeNativeFrameAlloc(std.testing.allocator, zero_dict_frame.items);
    defer std.testing.allocator.free(zero_dict_decoded);
    try std.testing.expectEqualSlices(u8, "abc", zero_dict_decoded);
    var zero_dict_output: [3]u8 = undefined;
    const zero_dict_written = try decodeNativeFrameInto(zero_dict_frame.items, &zero_dict_output);
    try std.testing.expectEqual(@as(usize, 3), zero_dict_written);
    try std.testing.expectEqualSlices(u8, "abc", &zero_dict_output);
    try std.testing.expectEqual(@as(usize, 3), try decodedRawOrRleFrameSize(zero_dict_frame.items));
}

test "zstd native dictionary decodes matches from preset history" {
    const dict = NativeDictionary.init(7, "wxyz");
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, 4, .{ .content_checksum = false, .dictionary_id = dict.id });
    try emitBlockHeader(std.testing.allocator, &frame, 2, 7, true);
    try frame.append(std.testing.allocator, 0); // Raw literals section with regenerated_size=0.
    try frame.append(std.testing.allocator, 1); // one sequence.
    try frame.append(std.testing.allocator, 0x54); // LL, OF, and ML use RLE_Mode.
    try frame.appendSlice(std.testing.allocator, &.{ 0, 2, 1 }); // literal_len=0, offset=4, match_len=4.
    try frame.append(std.testing.allocator, 0x07); // Offset extra bits=3 followed by the reverse-bitstream end mark.

    try std.testing.expectError(error.NeedDictionary, decodeNativeFrameAlloc(std.testing.allocator, frame.items));
    try std.testing.expectError(error.NeedDictionary, decodedNativeFrameSize(frame.items));

    const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, frame.items, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, dict.content, decoded);
    try std.testing.expectEqual(@as(usize, dict.content.len), try decodedNativeFrameSizeWithDictionary(frame.items, dict));
    const limited = try decodeNativeFrameAllocLimitedWithDictionary(std.testing.allocator, frame.items, dict.content.len, dict);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, dict.content, limited);
    try std.testing.expectError(error.OutputLimitExceeded, decodeNativeFrameAllocLimitedWithDictionary(std.testing.allocator, frame.items, dict.content.len - 1, dict));
    var into: [4]u8 = undefined;
    const written = try decodeNativeFrameIntoWithDictionary(frame.items, &into, dict);
    try std.testing.expectEqual(@as(usize, dict.content.len), written);
    try std.testing.expectEqualSlices(u8, dict.content, &into);
}

test "zstd native writer uses preset dictionary history" {
    const dict = NativeDictionary.init(0x1234, "abcdefghijklmnopQRSTUVWXYZabcd");
    const payload = "pfx-abcdefghijklmnop-mid-QRSTUVWXYZabcd-tail";
    const options: NativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, options, dict);
    defer std.testing.allocator.free(encoded.frame);
    try std.testing.expectEqual(NativeFrameMode.literal_only, encoded.mode);

    const header = try inspectNativeFrameHeader(encoded.frame);
    try std.testing.expectEqual(dict.id, header.dictionary_id);
    try std.testing.expectError(error.NeedDictionary, decodeNativeFrameAlloc(std.testing.allocator, encoded.frame));

    const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, encoded.frame, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    const exact_decoded = try decodeNativeFrameAllocWithDictionaryExactSize(std.testing.allocator, encoded.frame, dict, payload.len);
    defer std.testing.allocator.free(exact_decoded);
    try std.testing.expectEqualSlices(u8, payload, exact_decoded);
    try std.testing.expectError(error.SizeMismatch, decodeNativeFrameAllocWithDictionaryExactSize(std.testing.allocator, encoded.frame, dict, payload.len - 1));
    const raw = try encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .dictionary_id = dict.id,
    });
    defer std.testing.allocator.free(raw);
    try std.testing.expect(encoded.frame.len < raw.len);

    const first_block = try inspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded.frame[first_block.payload_offset..][0..first_block.payload_len], &frame_state);
    try std.testing.expectEqual(@as(usize, 2), section.sequence_count);
    try std.testing.expect(section.regenerated_size >= "pfx-".len + "-mid-".len + "-tail".len);

    var reusable = NativeFrameEncoder.init(std.testing.allocator);
    defer reusable.deinit();
    const scratch = try reusable.encodeScratchWithDictionary(payload, options, dict);
    try std.testing.expectEqual(NativeFrameMode.literal_only, scratch.mode);
    try std.testing.expectEqualSlices(u8, encoded.frame, scratch.frame);
    const scratch_decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, scratch.frame, dict);
    defer std.testing.allocator.free(scratch_decoded);
    try std.testing.expectEqualSlices(u8, payload, scratch_decoded);
    var reusable_decoder = NativeFrameDecoder.init(std.testing.allocator);
    defer reusable_decoder.deinit();
    const reusable_exact_decoded = try reusable_decoder.decodeAllocWithDictionaryExactSize(scratch.frame, dict, payload.len);
    defer std.testing.allocator.free(reusable_exact_decoded);
    try std.testing.expectEqualSlices(u8, payload, reusable_exact_decoded);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    const appended_mode = try encodeNativeFrameAppendWithDictionary(std.testing.allocator, &appended, payload, options, dict);
    try std.testing.expectEqual(NativeFrameMode.literal_only, appended_mode);
    try std.testing.expectEqualSlices(u8, encoded.frame, appended.items);

    const bound = try encodedNativeFrameBoundWithOptions(payload.len, .{
        .selection = .literal_only,
        .content_checksum = false,
        .dictionary_id = dict.id,
    });
    const into = try std.testing.allocator.alloc(u8, bound);
    defer std.testing.allocator.free(into);
    const into_result = try encodeNativeFrameIntoSliceWithDictionary(std.testing.allocator, payload, options, dict, into);
    try std.testing.expectEqual(NativeFrameMode.literal_only, into_result.mode);
    try std.testing.expectEqualSlices(u8, encoded.frame, into[0..into_result.written]);
    try std.testing.expectError(error.OutputTooSmall, encodeNativeFrameIntoSliceWithDictionary(std.testing.allocator, payload, options, dict, into[0 .. into_result.written - 1]));
    try std.testing.expectError(error.NeedDictionary, encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, options, NativeDictionary.init(0, dict.content)));
}

test "zstd native writer emits RLE multi dictionary matches" {
    const dict = NativeDictionary.init(
        0x2346,
        "ABCDEFGHIJKLMNOPXXXXXXXXQRSTUVWXYZabcdef0123456789ghijklmnopqrst",
    );
    const payload = "pfx" ++ "ABCDEFGHIJKLMNOP" ++ "pfx" ++ "QRSTUVWXYZabcdef";
    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    }, dict);
    defer std.testing.allocator.free(encoded.frame);

    const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, encoded.frame, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const first_block = try inspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    const block = encoded.frame[first_block.payload_offset..][0..first_block.payload_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(@as(usize, 2), section.sequence_count);
    try std.testing.expectEqual(@as(u8, 0x54), block[section.sequence_payload_offset]);

    const raw = try encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .dictionary_id = dict.id,
    });
    defer std.testing.allocator.free(raw);
    try std.testing.expect(encoded.frame.len < raw.len);
}

test "zstd native writer emits RLE literals for dictionary sequences" {
    const dict = NativeDictionary.init(
        0x2350,
        "ABCDEFGHIJKLMNOPXXXXXXXXQRSTUVWXYZabcdef0123456789ghijklmnopqrst",
    );
    const payload = "x" ++ "ABCDEFGHIJKLMNOP" ++ "x" ++ "QRSTUVWXYZabcdef" ++ "x";
    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    }, dict);
    defer std.testing.allocator.free(encoded.frame);

    const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, encoded.frame, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const first_block = try inspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    const block = encoded.frame[first_block.payload_offset..][0..first_block.payload_len];
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(block, &frame_state);
    try std.testing.expectEqual(LiteralsKind.rle, section.kind);
    try std.testing.expectEqual(@as(usize, 3), section.regenerated_size);
    try std.testing.expectEqual(@as(u8, 'x'), block[section.literal_payload_offset]);
    try std.testing.expectEqual(@as(usize, 2), section.sequence_count);
    const first_candidate = (try dictionaryMixedMatchCandidate(dict.content, payload, 0, 0)) orelse return error.CorruptFrame;
    const lookahead_payload_len = (try mixedCandidateLookaheadPayloadLen(dict.content, payload, 0, first_candidate)) orelse return error.CorruptFrame;
    try std.testing.expectEqual(first_block.payload_len, lookahead_payload_len);

    const raw = try encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .dictionary_id = dict.id,
    });
    defer std.testing.allocator.free(raw);
    try std.testing.expect(encoded.frame.len < raw.len);
}

test "zstd native concatenated streams select dictionaries by id" {
    const first_dict = NativeDictionary.init(0x1234, "abcdefghijklmnop");
    const second_dict = NativeDictionary.init(0x5678, "QRSTUVWXYZabcd1234");
    const dictionaries = [_]NativeDictionary{ first_dict, second_dict };
    const dictionary_set = try NativeDictionarySet.initChecked(&dictionaries);
    try dictionary_set.validate();
    try std.testing.expectEqualSlices(u8, first_dict.content, (dictionary_set.find(first_dict.id) orelse return error.NeedDictionary).content);
    try std.testing.expect(dictionary_set.find(0xffff) == null);
    const duplicate_dictionaries = [_]NativeDictionary{ first_dict, NativeDictionary.init(first_dict.id, "duplicate-zstd") };
    try std.testing.expectError(error.DuplicateDictionaryId, NativeDictionarySet.initChecked(&duplicate_dictionaries));
    try std.testing.expectError(error.DuplicateDictionaryId, NativeDictionarySet.init(&duplicate_dictionaries).validate());
    const zero_id_dictionaries = [_]NativeDictionary{NativeDictionary.init(0, "zero-zstd")};
    try std.testing.expectError(error.NeedDictionary, NativeDictionarySet.initChecked(&zero_id_dictionaries));
    const metadata_first_dict = NativeDictionary.initFromContent("zstd metadata first");
    const metadata_second_dict = NativeDictionary.initFromContent("zstd metadata second");
    const metadata = [_]dictionary_mod.Metadata{
        .fromBytes(metadata_first_dict.content, native_dictionary_window_len),
        .fromBytes(metadata_second_dict.content, native_dictionary_window_len),
    };
    const contents = [_][]const u8{ metadata_first_dict.content, metadata_second_dict.content };
    var metadata_dictionaries: [2]NativeDictionary = undefined;
    const metadata_set = try NativeDictionarySet.initFromMetadata(&metadata_dictionaries, &metadata, &contents);
    try std.testing.expectEqualSlices(u8, metadata_first_dict.content, (metadata_set.find(metadata_first_dict.id) orelse return error.NeedDictionary).content);
    try std.testing.expectEqualSlices(u8, metadata_second_dict.content, (metadata_set.find(metadata_second_dict.id) orelse return error.NeedDictionary).content);
    var short_metadata_dictionaries: [1]NativeDictionary = undefined;
    try std.testing.expectError(error.InvalidDictionaryMetadata, NativeDictionarySet.initFromMetadata(&short_metadata_dictionaries, &metadata, &contents));
    const bad_contents = [_][]const u8{ metadata_first_dict.content, "wrong zstd metadata second" };
    try std.testing.expectError(error.InvalidDictionaryMetadata, NativeDictionarySet.initFromMetadata(&metadata_dictionaries, &metadata, &bad_contents));
    var empty_metadata_dictionaries: [0]NativeDictionary = .{};
    const empty_metadata_set = try NativeDictionarySet.initFromMetadata(&empty_metadata_dictionaries, &.{}, &.{});
    try empty_metadata_set.validate();
    try std.testing.expect(empty_metadata_set.find(metadata_first_dict.id) == null);
    const unexpected_contents = [_][]const u8{metadata_first_dict.content};
    try std.testing.expectError(error.InvalidDictionaryMetadata, NativeDictionarySet.initFromMetadata(&empty_metadata_dictionaries, &.{}, &unexpected_contents));
    const owned_metadata_set = try nativeDictionarySetFromMetadataAlloc(std.testing.allocator, &metadata, &contents);
    defer owned_metadata_set.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, metadata_first_dict.content, (owned_metadata_set.asDictionarySet().find(metadata_first_dict.id) orelse return error.NeedDictionary).content);
    const empty_owned_set = try nativeDictionarySetFromMetadataAlloc(std.testing.allocator, &.{}, &.{});
    defer empty_owned_set.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), empty_owned_set.dictionaries.len);
    try std.testing.expectError(error.InvalidDictionaryMetadata, nativeDictionarySetFromMetadataAlloc(std.testing.allocator, &metadata, &bad_contents));
    const options: NativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };
    const first_payload = "pfx-abcdefghijklmnop-tail";
    const second_payload = "pfx-QRSTUVWXYZabcd1234-tail";
    const first = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, first_payload, options, first_dict);
    defer std.testing.allocator.free(first.frame);
    const skip = try encodeSkippableFrameAlloc(std.testing.allocator, 5, "zstd-set");
    defer std.testing.allocator.free(skip);
    const second = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, second_payload, options, second_dict);
    defer std.testing.allocator.free(second.frame);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first.frame);
    try stream.appendSlice(std.testing.allocator, skip);
    try stream.appendSlice(std.testing.allocator, second.frame);

    const expected = first_payload ++ second_payload;
    try std.testing.expectError(error.NeedDictionary, decodeNativeConcatenatedFrameAlloc(std.testing.allocator, stream.items));
    try std.testing.expectError(error.NeedDictionary, decodeNativeConcatenatedFrameAllocWithDictionary(std.testing.allocator, stream.items, first_dict));

    const first_decoded = try decodeNativeFrameAllocWithDictionarySet(std.testing.allocator, first.frame, dictionary_set);
    defer std.testing.allocator.free(first_decoded);
    try std.testing.expectEqualSlices(u8, first_payload, first_decoded);
    const first_limited = try decodeNativeFrameAllocLimitedWithDictionarySet(std.testing.allocator, first.frame, first_payload.len, dictionary_set);
    defer std.testing.allocator.free(first_limited);
    try std.testing.expectEqualSlices(u8, first_payload, first_limited);

    const decoded = try decodeNativeConcatenatedFrameAllocWithDictionarySet(std.testing.allocator, stream.items, dictionary_set);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    const exact_decoded = try decodeNativeConcatenatedFrameAllocWithDictionarySetExactSize(std.testing.allocator, stream.items, dictionary_set, expected.len);
    defer std.testing.allocator.free(exact_decoded);
    try std.testing.expectEqualSlices(u8, expected, exact_decoded);
    try std.testing.expectError(error.SizeMismatch, decodeNativeConcatenatedFrameAllocWithDictionarySetExactSize(std.testing.allocator, stream.items, dictionary_set, expected.len - 1));
    const decoded_limited = try decodeNativeConcatenatedFrameAllocLimitedWithDictionarySet(std.testing.allocator, stream.items, expected.len, dictionary_set);
    defer std.testing.allocator.free(decoded_limited);
    try std.testing.expectEqualSlices(u8, expected, decoded_limited);
    try std.testing.expectEqual(expected.len, try decodedNativeConcatenatedFrameSizeWithDictionarySet(stream.items, dictionary_set));
    try std.testing.expectEqual(expected.len, try decodedNativeConcatenatedFrameSizeLimitedWithDictionarySet(stream.items, expected.len, dictionary_set));
    try std.testing.expectError(error.OutputLimitExceeded, decodedNativeConcatenatedFrameSizeLimitedWithDictionarySet(stream.items, expected.len - 1, dictionary_set));

    var into: [expected.len]u8 = undefined;
    const into_written = try decodeNativeConcatenatedFrameIntoWithDictionarySet(stream.items, &into, dictionary_set);
    try std.testing.expectEqual(expected.len, into_written);
    try std.testing.expectEqualSlices(u8, expected, &into);
    try std.testing.expectError(error.OutputTooSmall, decodeNativeConcatenatedFrameIntoWithDictionarySet(stream.items, into[0 .. into.len - 1], dictionary_set));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeNativeConcatenatedFrameAppendWithDictionarySet(std.testing.allocator, &appended, stream.items, dictionary_set));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, appended.items);
    appended.clearRetainingCapacity();
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeNativeConcatenatedFrameAppendLimitedWithDictionarySet(std.testing.allocator, &appended, stream.items, expected.len, dictionary_set));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, appended.items);
    appended.clearRetainingCapacity();
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(first_payload.len, try decodeNativeFrameAppendLimitedWithDictionarySet(std.testing.allocator, &appended, first.frame, first_payload.len, dictionary_set));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ first_payload, appended.items);

    var decoder = NativeFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeConcatenatedScratchWithDictionarySet(stream.items, dictionary_set);
    try std.testing.expectEqualSlices(u8, expected, scratch);
    const reusable_exact_decoded = try decoder.decodeConcatenatedAllocWithDictionarySetExactSize(stream.items, dictionary_set, expected.len);
    defer std.testing.allocator.free(reusable_exact_decoded);
    try std.testing.expectEqualSlices(u8, expected, reusable_exact_decoded);
    const scratch_limited = try decoder.decodeConcatenatedScratchLimitedWithDictionarySet(stream.items, expected.len, dictionary_set);
    try std.testing.expectEqualSlices(u8, expected, scratch_limited);

    var incremental = NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, dictionary_set, .{
        .max_compressed_buffer_len = stream.items.len,
        .max_decoded_buffer_len = @max(first_payload.len, second_payload.len),
    });
    defer incremental.deinit();
    var incremental_out: [expected.len]u8 = undefined;
    const initial = try incremental.step(stream.items, incremental_out[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(stream.items.len, initial.progress.input_read);
    var incremental_written: usize = 0;
    while (true) {
        const end = @min(incremental_out.len, incremental_written + 7);
        const result = try incremental.step("", incremental_out[incremental_written..end]);
        incremental_written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqual(expected.len, incremental_written);
    try std.testing.expectEqualSlices(u8, expected, &incremental_out);

    const missing_dictionaries = [_]NativeDictionary{first_dict};
    try std.testing.expectError(error.NeedDictionary, decodeNativeConcatenatedFrameAllocWithDictionarySet(std.testing.allocator, stream.items, NativeDictionarySet.init(&missing_dictionaries)));
}

test "zstd native writer mixes dictionary and duplicate matches" {
    const dict = NativeDictionary.init(0x2468, "abcdefghijklmnop");
    const payload = "pfx-abcdefghijklmnop-mid-abcdefghijklmnop-tail";
    const options: NativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, options, dict);
    defer std.testing.allocator.free(encoded.frame);
    try std.testing.expectEqual(NativeFrameMode.literal_only, encoded.mode);

    const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, encoded.frame, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const first_block = try inspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded.frame[first_block.payload_offset..][0..first_block.payload_len], &frame_state);
    try std.testing.expectEqual(@as(usize, 2), section.sequence_count);

    const raw = try encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .dictionary_id = dict.id,
    });
    defer std.testing.allocator.free(raw);
    try std.testing.expect(encoded.frame.len < raw.len);
}

test "zstd native dictionary match planner scores offset cost" {
    var dict_bytes: std.ArrayList(u8) = .empty;
    defer dict_bytes.deinit(std.testing.allocator);
    try dict_bytes.appendSlice(std.testing.allocator, "ABCDEFGHI");
    try dict_bytes.appendNTimes(std.testing.allocator, 'x', 70 * 1024);
    try dict_bytes.appendSlice(std.testing.allocator, "ABCDEFGH");

    const dict = NativeDictionary.init(0x2345, dict_bytes.items);
    const payload = "ABCDEFGHI-tail";
    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    }, dict);
    defer std.testing.allocator.free(encoded.frame);

    const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, encoded.frame, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const first_block = try inspectNativeFrameFirstBlock(encoded.frame);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded.frame[first_block.payload_offset..][0..first_block.payload_len], &frame_state);
    try std.testing.expectEqual(@as(usize, 1), section.sequence_count);
    // A longer 9-byte match exists at the beginning of the dictionary, but it
    // needs a much larger offset. The planner should prefer the 8-byte near-tail
    // match because its cheaper offset code wins after full payload-cost scoring.
    try std.testing.expectEqual(payload.len - 8, section.regenerated_size);
}

test "zstd native writer uses preset dictionary history after first block" {
    const dict = NativeDictionary.init(0x4321, "abcdefghijklmnop");
    const first_block_payload = "0123456789!@#$%^&*()_+-=[]{}<>"; // 32 bytes with no long dictionary substring.
    const second_block_payload = "pfx-abcdefghijklmnop-tail";
    const payload = first_block_payload ++ second_block_payload;
    const options: NativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
        .block_size_max = first_block_payload.len,
    };

    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, options, dict);
    defer std.testing.allocator.free(encoded.frame);
    try std.testing.expectEqual(NativeFrameMode.literal_only, encoded.mode);
    try std.testing.expectEqual(dict.id, (try inspectNativeFrameHeader(encoded.frame)).dictionary_id);

    var iterator = try iterateNativeFrameBlocks(encoded.frame);
    _ = (try iterator.next()) orelse return error.CorruptFrame;
    const second_block = (try iterator.next()) orelse return error.CorruptFrame;
    try std.testing.expectEqual(NativeBlockType.compressed, second_block.block_type);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded.frame[second_block.payload_offset..][0..second_block.payload_len], &frame_state);
    try std.testing.expectEqual(@as(usize, 1), section.sequence_count);

    try std.testing.expectError(error.NeedDictionary, decodeNativeFrameAlloc(std.testing.allocator, encoded.frame));
    const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, encoded.frame, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const raw = try encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .dictionary_id = dict.id,
        .block_size_max = first_block_payload.len,
    });
    defer std.testing.allocator.free(raw);
    try std.testing.expect(encoded.frame.len < raw.len);
}

test "zstd native writer chooses Huffman over larger dictionary match" {
    const dict = NativeDictionary.init(0x4568, "ABABABABabcdefgh");
    var payload: [192]u8 = undefined;
    var state: u8 = 1;
    for (&payload) |*byte| {
        byte.* = if ((state & 1) == 0) 'A' else 'B';
        const feedback: u8 = ((state >> 0) ^ (state >> 2) ^ (state >> 3) ^ (state >> 4)) & 1;
        state = (state >> 1) | (feedback << 7);
    }
    @memcpy(payload[64..72], dict.content[0..8]);

    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, &payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    }, dict);
    defer std.testing.allocator.free(encoded.frame);
    try std.testing.expectEqual(NativeFrameMode.literal_only, encoded.mode);
    try std.testing.expectEqual(dict.id, (try inspectNativeFrameHeader(encoded.frame)).dictionary_id);

    const first_block = try inspectNativeFrameFirstBlock(encoded.frame);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded.frame[first_block.payload_offset..][0..first_block.payload_len], &frame_state);
    try std.testing.expectEqual(LiteralsKind.compressed, section.kind);
    try std.testing.expectEqual(@as(usize, 0), section.sequence_count);

    const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, encoded.frame, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
}

test "zstd native writer can choose repeated before dictionary" {
    const dict = NativeDictionary.init(0x4567, "abcdefghijklmnop");
    const payload = ("ab" ** 80) ++ "-mid-abcdefghijklmnop-tail";
    const options: NativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, options, dict);
    defer std.testing.allocator.free(encoded.frame);
    try std.testing.expectEqual(NativeFrameMode.literal_only, encoded.mode);

    const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, encoded.frame, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const first_block = try inspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded.frame[first_block.payload_offset..][0..first_block.payload_len], &frame_state);
    try std.testing.expectEqual(@as(usize, 2), section.sequence_count);

    const raw = try encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .dictionary_id = dict.id,
    });
    defer std.testing.allocator.free(raw);
    try std.testing.expect(encoded.frame.len < raw.len);
}

test "zstd native writer mixes dictionary and repeated-pattern matches" {
    const dictionary_payload = "abcdefghijklmnopqrstuvwxyz0123456789" ** 8;
    const dict = NativeDictionary.init(0x3456, dictionary_payload);
    const payload = "pfx-" ++ dictionary_payload ++ "-mid-0123456789xy" ++ ("ab" ** 80) ++ "-tail";
    const options: NativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, options, dict);
    defer std.testing.allocator.free(encoded.frame);
    try std.testing.expectEqual(NativeFrameMode.literal_only, encoded.mode);

    const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, encoded.frame, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const first_block = try inspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded.frame[first_block.payload_offset..][0..first_block.payload_len], &frame_state);
    try std.testing.expect(section.sequence_count >= 2);

    const raw = try encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .dictionary_id = dict.id,
    });
    defer std.testing.allocator.free(raw);
    try std.testing.expect(encoded.frame.len < raw.len);
}

test "zstd native writer emits branch-scored dictionary duplicate repeated matches" {
    const dict_content = "DICTMATCH1234567890";
    const unique = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}";
    const dict = NativeDictionary.init(0x6789, dict_content);
    const payload = "pfx-" ++ dict_content ++ "-u-" ++ unique ++ "-mid-" ++ unique ++ "-rep-" ++ ("ab" ** 16) ++ "-tail";
    const options: NativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    const plan = (try bestMixedMatchLookaheadPlan(dict.content, payload, 0, .{
        .dictionary = true,
        .duplicate = true,
        .repeated = true,
    }, .{ .kind = .dictionary }, .non_dictionary, mixed_match_path_search_budget)) orelse return error.CorruptFrame;
    try std.testing.expectEqual(@as(usize, 3), plan.count);
    try std.testing.expectEqual(MixedMatchKind.dictionary, plan.kinds[0]);
    try std.testing.expectEqual(MixedMatchKind.duplicate, plan.kinds[1]);
    try std.testing.expectEqual(MixedMatchKind.repeated, plan.kinds[2]);

    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, options, dict);
    defer std.testing.allocator.free(encoded.frame);
    try std.testing.expectEqual(NativeFrameMode.literal_only, encoded.mode);

    const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, encoded.frame, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const first_block = try inspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(NativeBlockType.compressed, first_block.block_type);
    try std.testing.expectEqual(plan.payload_len, first_block.payload_len);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded.frame[first_block.payload_offset..][0..first_block.payload_len], &frame_state);
    try std.testing.expectEqual(plan.count, section.sequence_count);

    const raw = try encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .dictionary_id = dict.id,
    });
    defer std.testing.allocator.free(raw);
    try std.testing.expect(encoded.frame.len < raw.len);
}

test "zstd native match search budget controls mixed planner" {
    const dict_content = "DICTMATCH1234567890";
    const unique = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}";
    const dict = NativeDictionary.init(0x678a, dict_content);
    const payload = "pfx-" ++ dict_content ++ "-u-" ++ unique ++ "-mid-" ++ unique ++ "-rep-" ++ ("ab" ** 16) ++ "-tail";
    const options: NativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    const full = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, options, dict);
    defer std.testing.allocator.free(full.frame);
    const disabled = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
        .match_search_budget = 0,
    }, dict);
    defer std.testing.allocator.free(disabled.frame);
    const shallow = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
        .match_search_budget = 2,
    }, dict);
    defer std.testing.allocator.free(shallow.frame);
    const enough = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
        .match_search_budget = 3,
    }, dict);
    defer std.testing.allocator.free(enough.frame);

    try std.testing.expectEqual(full.frame.len, enough.frame.len);
    try std.testing.expect(disabled.frame.len > shallow.frame.len);
    try std.testing.expect(shallow.frame.len > full.frame.len);

    inline for (.{ full.frame, disabled.frame, shallow.frame, enough.frame }) |frame| {
        const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, frame, dict);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }

    const full_block = try inspectNativeFrameFirstBlock(full.frame);
    const disabled_block = try inspectNativeFrameFirstBlock(disabled.frame);
    try std.testing.expectEqual(NativeBlockType.compressed, full_block.block_type);
    try std.testing.expectEqual(NativeBlockType.compressed, disabled_block.block_type);
    try std.testing.expect(full_block.payload_len < disabled_block.payload_len);
}

test "zstd native raw/RLE decoder handles fallback frames and skippable frames" {
    const raw = "raw block payload";
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, raw);
    defer std.testing.allocator.free(raw_encoded);
    const raw_decoded = try decodeNativeFrameAlloc(std.testing.allocator, raw_encoded);
    defer std.testing.allocator.free(raw_decoded);
    try std.testing.expectEqualSlices(u8, raw, raw_decoded);

    const repeated = "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy";
    const rle_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, repeated);
    defer std.testing.allocator.free(rle_encoded);
    const rle_decoded = try decodeNativeFrameAlloc(std.testing.allocator, rle_encoded);
    defer std.testing.allocator.free(rle_decoded);
    try std.testing.expectEqualSlices(u8, repeated, rle_decoded);

    var concatenated: std.ArrayList(u8) = .empty;
    defer concatenated.deinit(std.testing.allocator);
    try concatenated.appendSlice(std.testing.allocator, raw_encoded);
    try concatenated.appendSlice(std.testing.allocator, &.{ 0x50, 0x2a, 0x4d, 0x18 });
    var skippable_len: [4]u8 = undefined;
    std.mem.writeInt(u32, &skippable_len, 3, .little);
    try concatenated.appendSlice(std.testing.allocator, &skippable_len);
    try concatenated.appendSlice(std.testing.allocator, "pad");
    try concatenated.appendSlice(std.testing.allocator, rle_encoded);
    const concatenated_decoded = try decodeNativeFrameAlloc(std.testing.allocator, concatenated.items);
    defer std.testing.allocator.free(concatenated_decoded);
    try std.testing.expectEqualSlices(u8, raw ++ repeated, concatenated_decoded);
}

test "zstd native decoder accepts simple libzstd predefined frame" {
    const payload = "zstd payload zstd payload zstd payload zstd payload";
    const encoded = try encodeFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(encoded, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);
}
