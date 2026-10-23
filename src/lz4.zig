const std = @import("std");
const core = @import("core.zig");
const checksum_mod = @import("checksum.zig");
const dictionary_mod = @import("dictionary.zig");
const block_format = @import("lz4/block_format.zig");
const length = @import("lz4/length.zig");
const literal_copy = @import("lz4/literal_copy.zig");
const dest_size = @import("lz4/dest_size.zig");
const hc_dest_size = @import("lz4/hc_dest_size.zig");
const incremental_encoder = @import("lz4/incremental/frame_encoder.zig");
const incremental_block_decoder = @import("lz4/incremental/block_decoder.zig");
const incremental_tests = @import("lz4/incremental/tests.zig");
const incremental_decoder_tests = @import("lz4/incremental/decoder_tests.zig");

pub const Error = core.Error || std.mem.Allocator.Error;
pub const DestSizeResult = dest_size.Result;
const HcPreparedPrefix = hc_dest_size.PreparedPrefix;

pub fn encodeBlockDestSize(input: []const u8, output: []u8) Error!DestSizeResult {
    return dest_size.compress(input, output) catch |err| switch (err) {
        error.InputTooLarge => error.OutputLimitExceeded,
        error.OutputTooSmall => error.OutputTooSmall,
    };
}

pub const HcDestSizeEncoder = struct {
    inner: hc_dest_size.Encoder,
    output_scratch: std.ArrayList(u8) = .empty,

    pub fn init(allocator: std.mem.Allocator) Error!HcDestSizeEncoder {
        return .{ .inner = try hc_dest_size.Encoder.init(allocator) };
    }

    pub fn deinit(self: *HcDestSizeEncoder) void {
        self.output_scratch.deinit(self.inner.allocator);
        self.inner.deinit();
        self.* = undefined;
    }

    pub fn encode(
        self: *HcDestSizeEncoder,
        input: []const u8,
        output: []u8,
        compression_level: i32,
    ) Error!DestSizeResult {
        return self.inner.compress(input, output, compression_level) catch |err| switch (err) {
            error.InputTooLarge => error.OutputLimitExceeded,
            error.OutputTooSmall => error.OutputTooSmall,
            error.OutOfMemory => error.OutOfMemory,
        };
    }

    pub fn encodeWithPrefix(
        self: *HcDestSizeEncoder,
        prefix: []const u8,
        input: []const u8,
        output: []u8,
        compression_level: i32,
    ) Error!DestSizeResult {
        return self.inner.compressWithPrefix(prefix, input, output, compression_level) catch |err| switch (err) {
            error.InputTooLarge => error.OutputLimitExceeded,
            error.OutputTooSmall => error.OutputTooSmall,
            error.OutOfMemory => error.OutOfMemory,
        };
    }

    pub fn encodeAlloc(
        self: *HcDestSizeEncoder,
        input: []const u8,
        compression_level: i32,
    ) Error![]u8 {
        const bound = try encodedBlockBound(input.len);
        const output = try self.inner.allocator.alloc(u8, bound);
        errdefer self.inner.allocator.free(output);
        const result = try self.encode(input, output, compression_level);
        if (result.consumed != input.len) return error.SizeMismatch;
        return self.inner.allocator.realloc(output, result.written);
    }

    pub fn encodeScratch(
        self: *HcDestSizeEncoder,
        input: []const u8,
        compression_level: i32,
    ) Error![]const u8 {
        try self.output_scratch.resize(
            self.inner.allocator,
            try encodedBlockBound(input.len),
        );
        const result = self.encode(
            input,
            self.output_scratch.items,
            compression_level,
        ) catch |err| {
            self.output_scratch.clearRetainingCapacity();
            return err;
        };
        if (result.consumed != input.len) {
            self.output_scratch.clearRetainingCapacity();
            return error.SizeMismatch;
        }
        self.output_scratch.items.len = result.written;
        return self.output_scratch.items;
    }

    pub fn encodeScratchWithPrefix(
        self: *HcDestSizeEncoder,
        prefix: []const u8,
        input: []const u8,
        compression_level: i32,
    ) Error![]const u8 {
        try self.output_scratch.resize(
            self.inner.allocator,
            try encodedBlockBound(input.len),
        );
        const result = self.encodeWithPrefix(
            prefix,
            input,
            self.output_scratch.items,
            compression_level,
        ) catch |err| {
            self.output_scratch.clearRetainingCapacity();
            return err;
        };
        if (result.consumed != input.len) {
            self.output_scratch.clearRetainingCapacity();
            return error.SizeMismatch;
        }
        self.output_scratch.items.len = result.written;
        return self.output_scratch.items;
    }

    fn preparePrefixAlloc(self: *HcDestSizeEncoder, prefix: []const u8) Error!*HcPreparedPrefix {
        return self.inner.preparePrefixAlloc(prefix) catch |err| switch (err) {
            error.InputTooLarge => error.OutputLimitExceeded,
            error.OutputTooSmall => error.OutputTooSmall,
            error.OutOfMemory => error.OutOfMemory,
        };
    }

    fn freePreparedPrefix(self: *HcDestSizeEncoder, prepared: *HcPreparedPrefix) void {
        self.inner.freePreparedPrefix(prepared);
    }

    pub fn encodeScratchWithPreparedPrefix(
        self: *HcDestSizeEncoder,
        prepared: *const HcPreparedPrefix,
        input: []const u8,
        compression_level: i32,
    ) Error![]const u8 {
        try self.output_scratch.resize(self.inner.allocator, try encodedBlockBound(input.len));
        const result = self.inner.compressWithPreparedPrefix(
            prepared,
            input,
            self.output_scratch.items,
            compression_level,
        ) catch |err| {
            self.output_scratch.clearRetainingCapacity();
            return switch (err) {
                error.InputTooLarge => error.OutputLimitExceeded,
                error.OutputTooSmall => error.OutputTooSmall,
                error.OutOfMemory => error.OutOfMemory,
            };
        };
        if (result.consumed != input.len) {
            self.output_scratch.clearRetainingCapacity();
            return error.SizeMismatch;
        }
        self.output_scratch.items.len = result.written;
        return self.output_scratch.items;
    }

    pub fn append(
        self: *HcDestSizeEncoder,
        output: *std.ArrayList(u8),
        input: []const u8,
        compression_level: i32,
    ) Error!usize {
        const encoded = try self.encodeScratch(input, compression_level);
        try output.appendSlice(self.inner.allocator, encoded);
        return encoded.len;
    }

    pub fn encodeIntoSlice(
        self: *HcDestSizeEncoder,
        input: []const u8,
        output: []u8,
        compression_level: i32,
    ) Error!usize {
        const encoded = try self.encodeScratch(input, compression_level);
        if (output.len < encoded.len) return error.OutputTooSmall;
        @memcpy(output[0..encoded.len], encoded);
        return encoded.len;
    }
};

pub const BlockHcEncoder = HcDestSizeEncoder;

pub fn encodeBlockHcDestSize(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    compression_level: i32,
) Error!DestSizeResult {
    var encoder = try HcDestSizeEncoder.init(allocator);
    defer encoder.deinit();
    return encoder.encode(input, output, compression_level);
}

pub fn encodeBlockHcAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    compression_level: i32,
) Error![]u8 {
    var encoder = try BlockHcEncoder.init(allocator);
    defer encoder.deinit();
    return encoder.encodeAlloc(input, compression_level);
}

pub fn encodeBlockHcIntoSlice(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    compression_level: i32,
) Error!usize {
    var encoder = try BlockHcEncoder.init(allocator);
    defer encoder.deinit();
    return encoder.encodeIntoSlice(input, output, compression_level);
}

pub fn encodeBlockHcWithPrefixAlloc(
    allocator: std.mem.Allocator,
    prefix: []const u8,
    input: []const u8,
    compression_level: i32,
) Error![]u8 {
    var encoder = try BlockHcEncoder.init(allocator);
    defer encoder.deinit();
    const encoded = try encoder.encodeScratchWithPrefix(prefix, input, compression_level);
    return allocator.dupe(u8, encoded);
}

pub fn encodeBlockHcWithPrefixIntoSlice(
    allocator: std.mem.Allocator,
    prefix: []const u8,
    input: []const u8,
    output: []u8,
    compression_level: i32,
) Error!usize {
    var encoder = try BlockHcEncoder.init(allocator);
    defer encoder.deinit();
    const encoded = try encoder.encodeScratchWithPrefix(prefix, input, compression_level);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub const default_compression_level: c_int = 10;

const frame_magic = [_]u8{ 0x04, 0x22, 0x4d, 0x18 };
const frame_magic_u32: u32 = 0x184d2204;
const skippable_magic_min: u32 = 0x184d2a50;
const skippable_magic_max: u32 = 0x184d2a5f;
const max_frame_block_len = 4 * 1024 * 1024;
const max_block_history_len = 64 * 1024;
const max_match_offset = std.math.maxInt(u16);
const hash_table_len = max_block_history_len;
const hash_occupancy_words = hash_table_len / @bitSizeOf(u64);
const chain_table_len = max_block_history_len;
const chain_table_mask = chain_table_len - 1;
const invalid_pos = std.math.maxInt(u32);
// Keep the bootstrap parser bounded while allowing it to see past a small run
// of same-hash short candidates. Several real structured payloads place the
// long repeat just behind many shallow four-byte hash hits; depth 16 keeps the
// search cheap but avoids truncating those obvious wins.
const max_chain_depth = 16;
pub const native_max_chain_depth: u8 = max_chain_depth;
pub const native_dictionary_window_len: usize = max_block_history_len;
const good_match_len = 64;
const lazy_extra_gain = 1;

pub const FrameOptions = struct {
    include_content_size: bool = true,
    content_checksum: bool = true,
    block_checksum: bool = false,
    block_size_id: BlockSizeId = .max4mb,
    block_mode: BlockMode = .linked,
};

const Match = struct {
    start: usize = 0,
    len: usize = 0,
};

pub const NativeFrameOptions = struct {
    include_content_size: bool = true,
    content_checksum: bool = true,
    block_checksum: bool = false,
    block_size_id: BlockSizeId = .max4mb,
    block_mode: BlockMode = .independent,
    dictionary_id: ?u32 = null,
    /// Maximum hash-chain candidates to inspect per position. Lower values
    /// favor encode speed; the default keeps the deeper-ratio parser enabled.
    chain_depth: u8 = native_max_chain_depth,
};

/// Options for LZ4 frames encoded with the liblz4 1.9.3-compatible
/// high-compression parser.
pub const HcFrameOptions = struct {
    include_content_size: bool = true,
    content_checksum: bool = true,
    block_checksum: bool = false,
    block_size_id: BlockSizeId = .max4mb,
    block_mode: BlockMode = .independent,
    dictionary_id: ?u32 = null,
    compression_level: i32 = 9,
};

const IncrementalEncoderCodec = struct {
    pub const Error = lz4.Error;
    pub const Options = lz4.NativeFrameOptions;
    pub const EncoderState = lz4.BlockEncoder;
    pub fn maxBlockLen(options: Options) usize {
        return options.block_size_id.maxLen();
    }
    pub fn validate(options: Options, expected_input_len: ?usize, dictionary_id: ?u32) lz4.Error!void {
        if (options.include_content_size != (expected_input_len != null)) return error.InvalidBlockPlan;
        if (options.dictionary_id != dictionary_id) return error.InvalidBlockPlan;
        _ = try nativeChainDepth(options);
    }
    pub fn writeHeader(allocator: std.mem.Allocator, out: *std.ArrayList(u8), options: Options, expected_input_len: ?usize, dictionary_id: ?u32) lz4.Error!void {
        try out.appendSlice(allocator, &frame_magic);
        const descriptor_start = out.items.len;
        var flg: u8 = 0x40;
        if (options.block_mode == .independent) flg |= 0x20;
        if (options.block_checksum) flg |= 0x10;
        if (expected_input_len != null) flg |= 0x08;
        if (options.content_checksum) flg |= 0x04;
        if (dictionary_id != null) flg |= 0x01;
        try out.append(allocator, flg);
        try out.append(allocator, @intFromEnum(options.block_size_id) << 4);
        if (expected_input_len) |len| {
            var content_size: [8]u8 = undefined;
            std.mem.writeInt(u64, &content_size, try checkedUsizeToU64(len), .little);
            try out.appendSlice(allocator, &content_size);
        }
        if (dictionary_id) |id| {
            var bytes: [4]u8 = undefined;
            std.mem.writeInt(u32, &bytes, id, .little);
            try out.appendSlice(allocator, &bytes);
        }
        try out.append(allocator, descriptorChecksum(out.items[descriptor_start..]));
    }
    pub fn writeBlock(state: *EncoderState, out: *std.ArrayList(u8), block: []const u8, history: []const u8, options: Options) lz4.Error!void {
        const allocator = state.allocator;
        const header_start = out.items.len;
        try out.appendNTimes(allocator, 0, 4);
        const encoded_start = out.items.len;
        const chain_depth = try nativeChainDepth(options);
        const compressed_len = if (history.len == 0) try state.appendWithChainDepth(out, block, chain_depth) else try state.appendWithPrefixAndChainDepth(out, block, history, chain_depth);
        if (compressed_len < block.len) {
            std.mem.writeInt(u32, out.items[header_start..][0..4], @intCast(compressed_len), .little);
            if (options.block_checksum) try emitBlockChecksum(allocator, out, out.items[encoded_start..][0..compressed_len]);
        } else {
            out.items.len = encoded_start;
            std.mem.writeInt(u32, out.items[header_start..][0..4], 0x8000_0000 | @as(u32, @intCast(block.len)), .little);
            try out.appendSlice(allocator, block);
            if (options.block_checksum) try emitBlockChecksum(allocator, out, block);
        }
    }
    pub fn writeFooter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), options: Options, hasher: *std.hash.XxHash32) lz4.Error!void {
        try out.appendSlice(allocator, &.{ 0, 0, 0, 0 });
        if (options.content_checksum) {
            var checksum: [4]u8 = undefined;
            std.mem.writeInt(u32, &checksum, hasher.final(), .little);
            try out.appendSlice(allocator, &checksum);
        }
    }
    pub fn writeSkippable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), skippable_id: u4, payload: []const u8) lz4.Error!void {
        try encodeSkippableFrameAppend(allocator, out, skippable_id, payload);
    }
};

const lz4 = @This();
pub const NativeIncrementalFrameEncoder = incremental_encoder.Encoder(IncrementalEncoderCodec);

const IncrementalHcBlockEncoder = struct {
    encoder: BlockHcEncoder,
    prepared_prefix: ?*HcPreparedPrefix = null,

    pub fn init(allocator: std.mem.Allocator) Error!IncrementalHcBlockEncoder {
        return .{ .encoder = try BlockHcEncoder.init(allocator) };
    }

    pub fn deinit(self: *IncrementalHcBlockEncoder) void {
        if (self.prepared_prefix) |prepared| self.encoder.freePreparedPrefix(prepared);
        self.encoder.deinit();
        self.* = undefined;
    }

    fn preparePrefix(self: *IncrementalHcBlockEncoder, prefix: []const u8) Error!*HcPreparedPrefix {
        const keep = @min(prefix.len, max_match_offset);
        const retained = prefix[prefix.len - keep ..];
        if (self.prepared_prefix) |prepared| {
            if (std.mem.eql(u8, prepared.prefix.items, retained)) return prepared;
            self.encoder.freePreparedPrefix(prepared);
            self.prepared_prefix = null;
        }
        const prepared = try self.encoder.preparePrefixAlloc(retained);
        self.prepared_prefix = prepared;
        return prepared;
    }
};

const IncrementalHcEncoderCodec = struct {
    pub const Error = lz4.Error;
    pub const Options = lz4.HcFrameOptions;
    pub const EncoderState = IncrementalHcBlockEncoder;

    pub fn maxBlockLen(options: Options) usize {
        return options.block_size_id.maxLen();
    }

    pub fn validate(options: Options, expected_input_len: ?usize, dictionary_id: ?u32) lz4.Error!void {
        if (options.include_content_size != (expected_input_len != null)) return error.InvalidBlockPlan;
        if (options.dictionary_id != dictionary_id) return error.InvalidBlockPlan;
    }

    pub fn writeHeader(allocator: std.mem.Allocator, out: *std.ArrayList(u8), options: Options, expected_input_len: ?usize, dictionary_id: ?u32) lz4.Error!void {
        return IncrementalEncoderCodec.writeHeader(allocator, out, hcNativeOptions(options), expected_input_len, dictionary_id);
    }

    pub fn writeBlock(state: *EncoderState, out: *std.ArrayList(u8), block: []const u8, history: []const u8, options: Options) lz4.Error!void {
        const allocator = state.encoder.inner.allocator;
        const header_start = out.items.len;
        try out.appendNTimes(allocator, 0, 4);
        const encoded_start = out.items.len;
        const encoded = if (options.block_mode == .independent and history.len != 0) blk: {
            const prepared = try state.preparePrefix(history);
            break :blk try state.encoder.encodeScratchWithPreparedPrefix(prepared, block, options.compression_level);
        } else try state.encoder.encodeScratchWithPrefix(history, block, options.compression_level);
        if (encoded.len < block.len) {
            std.mem.writeInt(u32, out.items[header_start..][0..4], @intCast(encoded.len), .little);
            try out.appendSlice(allocator, encoded);
            if (options.block_checksum) try emitBlockChecksum(allocator, out, out.items[encoded_start..][0..encoded.len]);
        } else {
            std.mem.writeInt(u32, out.items[header_start..][0..4], 0x8000_0000 | @as(u32, @intCast(block.len)), .little);
            try out.appendSlice(allocator, block);
            if (options.block_checksum) try emitBlockChecksum(allocator, out, block);
        }
    }

    pub fn writeFooter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), options: Options, hasher: *std.hash.XxHash32) lz4.Error!void {
        return IncrementalEncoderCodec.writeFooter(allocator, out, hcNativeOptions(options), hasher);
    }

    pub fn writeSkippable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), skippable_id: u4, payload: []const u8) lz4.Error!void {
        return IncrementalEncoderCodec.writeSkippable(allocator, out, skippable_id, payload);
    }
};

fn hcNativeOptions(options: HcFrameOptions) NativeFrameOptions {
    return .{
        .include_content_size = options.include_content_size,
        .content_checksum = options.content_checksum,
        .block_checksum = options.block_checksum,
        .block_size_id = options.block_size_id,
        .block_mode = options.block_mode,
        .dictionary_id = options.dictionary_id,
    };
}

pub const HcIncrementalFrameEncoder = incremental_encoder.Encoder(IncrementalHcEncoderCodec);

test {
    _ = incremental_tests;
    _ = incremental_decoder_tests;
}

pub const NativeDictionary = struct {
    id: u32,
    content: []const u8,

    pub fn init(id: u32, content: []const u8) NativeDictionary {
        return .{ .id = id, .content = content };
    }

    /// Derive a stable 32-bit native LZ4 Dictionary_ID from dictionary bytes.
    ///
    /// The native LZ4 frame header uses a zero/absent dictionary ID to mean
    /// "no preset dictionary".  Fold the rare CRC-32 zero result to a fixed
    /// non-zero value so `initFromContent` always creates a usable frame
    /// dictionary.  Callers that need a stronger collision policy or externally
    /// assigned IDs can keep using `init`.
    pub fn derivedId(content: []const u8) u32 {
        const id = checksum_mod.crc32(content);
        return if (id == 0) 1 else id;
    }

    /// Create a dictionary whose frame Dictionary_ID is derived from `content`.
    ///
    /// This keeps encoder and decoder call sites from hand-rolling IDs while
    /// preserving the explicit ownership model: the returned dictionary borrows
    /// `content`, and callers must keep those bytes alive for the codec call.
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
    /// The returned metadata intentionally uses the shared 64-bit dictionary
    /// fingerprint (`DictionaryId`) rather than the frame's 32-bit
    /// `Dictionary_ID`, so callers can persist richer catalog metadata while
    /// still converting the owned bytes to a codec dictionary with
    /// `asDictionary`.
    pub fn metadata(self: OwnedNativeDictionary) dictionary_mod.Metadata {
        return .fromBytes(self.content, native_dictionary_window_len);
    }

    pub fn deinit(self: OwnedNativeDictionary, allocator: std.mem.Allocator) void {
        allocator.free(self.content);
    }
};

/// Train an owned native LZ4 preset dictionary from representative samples.
///
/// The trainer is intentionally shared with the wider Vort dictionary module so
/// library callers get deterministic bytes, explicit allocator ownership, and
/// the same content-derived Dictionary_ID policy used by `initFromContent`.
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
    /// unambiguously from frame metadata.  The plain `init` constructor remains
    /// available for callers that already validated a static table, while this
    /// checked form is the safer choice for dynamically trained or discovered
    /// dictionaries.
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

pub const BlockMode = enum {
    independent,
    linked,
};

pub const BlockSizeId = enum(u8) {
    max64kb = 4,
    max256kb = 5,
    max1mb = 6,
    max4mb = 7,

    fn maxLen(self: BlockSizeId) usize {
        return switch (self) {
            .max64kb => max_block_history_len,
            .max256kb => 256 * 1024,
            .max1mb => 1024 * 1024,
            .max4mb => max_frame_block_len,
        };
    }
};

pub fn encodedNativeFrameBound(input_len: usize) Error!usize {
    return try encodedNativeFrameBoundWithOptions(input_len, .{});
}

pub fn encodedNativeFrameBoundWithOptions(input_len: usize, options: NativeFrameOptions) Error!usize {
    _ = try nativeChainDepth(options);
    var bound: usize = 4 + 2 + 1; // magic + FLG/BD + descriptor checksum
    if (options.include_content_size) bound = std.math.add(usize, bound, 8) catch return error.IntegerOverflow;
    if (options.dictionary_id != null) bound = std.math.add(usize, bound, 4) catch return error.IntegerOverflow;
    if (input_len != 0) {
        const max_block_len = options.block_size_id.maxLen();
        const block_count = (input_len + max_block_len - 1) / max_block_len;
        bound = std.math.add(usize, bound, input_len) catch return error.IntegerOverflow;
        const per_block_overhead = 4 + if (options.block_checksum) @as(usize, 4) else 0;
        const block_overhead = std.math.mul(usize, block_count, per_block_overhead) catch return error.IntegerOverflow;
        bound = std.math.add(usize, bound, block_overhead) catch return error.IntegerOverflow;
    }
    bound = std.math.add(usize, bound, 4) catch return error.IntegerOverflow; // end mark
    if (options.content_checksum) bound = std.math.add(usize, bound, 4) catch return error.IntegerOverflow;
    return bound;
}

pub fn encodedHcFrameBound(
    input_len: usize,
    options: HcFrameOptions,
) Error!usize {
    return encodedNativeFrameBoundWithOptions(input_len, .{
        .include_content_size = options.include_content_size,
        .content_checksum = options.content_checksum,
        .block_checksum = options.block_checksum,
        .block_size_id = options.block_size_id,
        .block_mode = options.block_mode,
        .dictionary_id = options.dictionary_id,
    });
}

pub fn encodedHcFrameBoundWithDictionary(
    input_len: usize,
    options: HcFrameOptions,
    dictionary: NativeDictionary,
) Error!usize {
    if (dictionary.id == 0) return error.NeedDictionary;
    var with_dictionary = options;
    if (with_dictionary.dictionary_id != null and with_dictionary.dictionary_id.? != dictionary.id)
        return error.InvalidBlockPlan;
    with_dictionary.dictionary_id = dictionary.id;
    return encodedHcFrameBound(input_len, with_dictionary);
}

pub fn encodedHcFrameBoundWithDictionarySet(
    input_len: usize,
    options: HcFrameOptions,
    dictionary_set: NativeDictionarySet,
    dictionary_id: u32,
) Error!usize {
    const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
    return encodedHcFrameBoundWithDictionary(input_len, options, dictionary);
}

fn nativeChainDepth(options: NativeFrameOptions) Error!u8 {
    if (options.chain_depth > max_chain_depth) return error.InvalidBlockPlan;
    return options.chain_depth;
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

/// Encode a complete interoperable LZ4 frame through Vort's dependency-free
/// pure Zig writer.
pub fn encodeFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return try encodeFrameWithLevelAlloc(allocator, input, default_compression_level);
}

pub fn encodeFrameWithLevelAlloc(allocator: std.mem.Allocator, input: []const u8, level: c_int) Error![]u8 {
    return try encodeFrameWithLevelAndOptionsAlloc(allocator, input, level, .{});
}

pub fn encodeFrameWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: FrameOptions) Error![]u8 {
    return try encodeFrameWithLevelAndOptionsAlloc(allocator, input, default_compression_level, options);
}

pub fn encodeFrameWithLevelAndOptionsAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    level: c_int,
    options: FrameOptions,
) Error![]u8 {
    return try encodePureFrameWithOptionsAlloc(allocator, input, nativeFrameOptionsForLevel(level, options));
}

fn nativeFrameOptionsForLevel(level: c_int, options: FrameOptions) NativeFrameOptions {
    return .{
        .include_content_size = options.include_content_size,
        .content_checksum = options.content_checksum,
        .block_checksum = options.block_checksum,
        .block_size_id = options.block_size_id,
        .block_mode = options.block_mode,
        .chain_depth = nativeChainDepthForLevel(level),
    };
}

fn nativeChainDepthForLevel(level: c_int) u8 {
    if (level <= 0) return 0;
    if (level < default_compression_level) return @intCast(@min(@as(c_int, native_max_chain_depth), level));
    return native_max_chain_depth;
}

/// Dependency-free pure Zig LZ4 frame encoder. Blocks use a bounded hash-chain
/// parser with one-byte lazy matching, linked frames seed the parser from the
/// previous 64 KiB of decoded history, and all blocks fall back to uncompressed
/// storage when compression expands the input.
pub fn encodePureFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return try encodePureFrameWithOptionsAlloc(allocator, input, .{});
}

pub fn encodePureFrameWithOptionsAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try encodePureFrameAppend(allocator, &out, input, options);
    return out.toOwnedSlice(allocator);
}

pub fn encodePureFrameAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: NativeFrameOptions,
) Error!void {
    try out.appendSlice(allocator, &frame_magic);
    const descriptor_start = out.items.len;
    var flg: u8 = 0x40; // version=01
    if (options.block_mode == .independent) flg |= 0x20;
    if (options.block_checksum) flg |= 0x10;
    if (options.include_content_size) flg |= 0x08;
    if (options.content_checksum) flg |= 0x04;
    if (options.dictionary_id != null) flg |= 0x01;
    try out.append(allocator, flg);
    try out.append(allocator, @intFromEnum(options.block_size_id) << 4);
    if (options.include_content_size) {
        var content_size: [8]u8 = undefined;
        std.mem.writeInt(u64, &content_size, try checkedUsizeToU64(input.len), .little);
        try out.appendSlice(allocator, &content_size);
    }
    if (options.dictionary_id) |dictionary_id| {
        var dictionary_id_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &dictionary_id_bytes, dictionary_id, .little);
        try out.appendSlice(allocator, &dictionary_id_bytes);
    }
    const descriptor = out.items[descriptor_start..];
    try out.append(allocator, @truncate(std.hash.XxHash32.hash(0, descriptor) >> 8));

    var occupancy_bits: []u64 = &.{};
    var hash_table: []u32 = &.{};
    var chain_table: []u32 = &.{};
    if (input.len != 0) {
        const table = try allocator.alloc(u32, hash_table_len);
        const bits = allocator.alloc(u64, hash_occupancy_words) catch |err| {
            allocator.free(table);
            return err;
        };
        const chain = allocator.alloc(u32, chain_table_len) catch |err| {
            allocator.free(bits);
            allocator.free(table);
            return err;
        };
        hash_table = table;
        occupancy_bits = bits;
        chain_table = chain;
    }
    defer {
        if (chain_table.len != 0) allocator.free(chain_table);
        if (occupancy_bits.len != 0) allocator.free(occupancy_bits);
        if (hash_table.len != 0) allocator.free(hash_table);
    }

    var offset: usize = 0;
    const max_block_len = options.block_size_id.maxLen();
    const chain_depth = try nativeChainDepth(options);
    while (offset < input.len) {
        const block_len = @min(input.len - offset, max_block_len);
        var header: [4]u8 = undefined;
        const block = input[offset..][0..block_len];
        const history = if (options.block_mode == .linked)
            input[if (offset > max_match_offset) offset - max_match_offset else 0..offset]
        else
            &[_]u8{};
        const header_start = out.items.len;
        try out.appendNTimes(allocator, 0, 4);
        const encoded_start = out.items.len;
        const compressed_len = if (history.len == 0)
            try encodeBlockInto(allocator, out, block, hash_table, occupancy_bits, chain_table, chain_depth)
        else
            try encodeLinkedBlockInto(allocator, out, history, block, hash_table, occupancy_bits, chain_table, chain_depth);
        if (compressed_len < block.len) {
            std.mem.writeInt(u32, out.items[header_start..][0..4], @intCast(compressed_len), .little);
            if (options.block_checksum) try emitBlockChecksum(allocator, out, out.items[encoded_start..][0..compressed_len]);
        } else {
            out.items.len = encoded_start;
            std.mem.writeInt(u32, &header, 0x8000_0000 | @as(u32, @intCast(block_len)), .little);
            @memcpy(out.items[header_start..][0..4], &header);
            try out.appendSlice(allocator, block);
            if (options.block_checksum) try emitBlockChecksum(allocator, out, block);
        }
        offset += block_len;
    }
    try out.appendSlice(allocator, &.{ 0, 0, 0, 0 }); // end mark
    if (options.content_checksum) {
        var checksum: [4]u8 = undefined;
        std.mem.writeInt(u32, &checksum, std.hash.XxHash32.hash(0, input), .little);
        try out.appendSlice(allocator, &checksum);
    }
}

pub const encodeNativeFrameAlloc = encodePureFrameAlloc;
pub const encodeNativeFrameWithOptionsAlloc = encodePureFrameWithOptionsAlloc;
pub const encodeNativeFrameAppend = encodePureFrameAppend;

pub fn encodeNativeFrameWithDictionaryAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
    dictionary: NativeDictionary,
) Error![]u8 {
    var encoder = try NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    return try encoder.encodeWithDictionaryAlloc(input, options, dictionary);
}

pub fn encodeNativeFrameAppendWithDictionary(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: NativeFrameOptions,
    dictionary: NativeDictionary,
) Error!void {
    var encoder = try NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    return try encoder.encodeAppendWithDictionary(out, input, options, dictionary);
}

pub fn encodeNativeFrameIntoSlice(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
    output: []u8,
) Error!usize {
    var encoder = try NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    return try encoder.encodeIntoSlice(input, options, output);
}

pub fn encodeNativeFrameIntoSliceWithDictionary(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
    dictionary: NativeDictionary,
    output: []u8,
) Error!usize {
    var encoder = try NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    return try encoder.encodeIntoSliceWithDictionary(input, options, dictionary, output);
}

pub fn encodeNativeFrameWithDictionarySetAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
    dictionary_set: NativeDictionarySet,
    dictionary_id: u32,
) Error![]u8 {
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
) Error!void {
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
) Error!usize {
    const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
    return try encodeNativeFrameIntoSliceWithDictionary(allocator, input, options, dictionary, output);
}

fn dictionaryFromSet(dictionary_set: NativeDictionarySet, dictionary_id: u32) Error!NativeDictionary {
    if (dictionary_id == 0) return error.NeedDictionary;
    return dictionary_set.find(dictionary_id) orelse error.NeedDictionary;
}

pub fn encodedBlockBound(input_len: usize) Error!usize {
    return try maxCompressedLen(input_len);
}

pub fn encodedSkippableFrameBound(payload_len: usize) Error!usize {
    _ = try checkedUsizeToU32(payload_len);
    return try checkedAdd(8, payload_len);
}

fn emitBlockChecksum(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8) Error!void {
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, std.hash.XxHash32.hash(0, block), .little);
    try out.appendSlice(allocator, &checksum);
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

/// Decode an LZ4 frame. Independent and linked blocks are supported; external
/// dictionaries are not required for frames produced by `encodeFrameAlloc`.
pub fn decodeFrameAlloc(allocator: std.mem.Allocator, frame: []const u8) Error![]u8 {
    const header = try parseFrameHeader(frame);
    try rejectNativeDictionaryHeader(header);
    var offset = header.payload_offset;

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    if (header.expected_content_size) |size| try out.ensureTotalCapacity(allocator, try checkedU64ToUsize(size));
    while (true) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const block_header = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        if (block_header == 0) break;
        const uncompressed_block = (block_header & 0x8000_0000) != 0;
        const block_len: usize = @intCast(block_header & 0x7fff_ffff);
        if (block_len > header.block_size_max) return error.CorruptFrame;
        if (frame.len - offset < block_len) return error.TruncatedFrame;
        const block = frame[offset..][0..block_len];
        offset += block_len;
        if (uncompressed_block) {
            try out.appendSlice(allocator, block);
        } else {
            const history = if (header.block_independent)
                &[_]u8{}
            else if (out.items.len <= max_block_history_len)
                out.items
            else
                out.items[out.items.len - max_block_history_len ..];
            if (header.block_independent) {
                try decodeBlockInto(allocator, &out, block, null, history);
            } else {
                const decoded = try decodeBlockWithPrefixAlloc(allocator, block, null, history);
                defer allocator.free(decoded);
                try out.appendSlice(allocator, decoded);
            }
        }
        if (header.block_checksum) {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const expected = std.mem.readInt(u32, frame[offset..][0..4], .little);
            if (std.hash.XxHash32.hash(0, block) != expected) return error.ChecksumMismatch;
            offset += 4;
        }
    }
    if (header.expected_content_size) |size| {
        if (out.items.len != size) return error.SizeMismatch;
    }
    if (header.content_checksum) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const expected = std.mem.readInt(u32, frame[offset..][0..4], .little);
        if (std.hash.XxHash32.hash(0, out.items) != expected) return error.ChecksumMismatch;
        offset += 4;
    }
    if (offset != frame.len) return error.TrailingData;
    return out.toOwnedSlice(allocator);
}

pub fn decodeFrameAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8) Error!usize {
    const decoded_len = try decodedFrameSize(frame);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeFrameInto(frame, slot) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeFrameAppendExactSize(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8, expected_output_len: usize) Error!usize {
    const decoded_len = try decodedFrameSize(frame);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    try out.ensureUnusedCapacity(allocator, expected_output_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(expected_output_len);
    const written = decodeFrameInto(frame, slot) catch |err| switch (err) {
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

pub fn decodeFrameAppendLimited(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frame: []const u8,
    max_output_len: usize,
) Error!usize {
    const decoded_len = try frameDecodedSizeLimited(frame, max_output_len);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeFrameInto(frame, slot) catch |err| switch (err) {
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

pub fn decodeFrameAllocLimited(
    allocator: std.mem.Allocator,
    frame: []const u8,
    max_output_len: usize,
) Error![]u8 {
    const decoded_len = try frameDecodedSizeLimited(frame, max_output_len);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = decodeFrameInto(frame, out) catch |err| switch (err) {
        error.OutputTooSmall => return error.OutputLimitExceeded,
        else => return err,
    };
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodeFrameAllocExactSize(allocator: std.mem.Allocator, frame: []const u8, expected_output_len: usize) Error![]u8 {
    const decoded_len = try decodedFrameSize(frame);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeFrameInto(frame, out) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

pub fn decodeFrameIntoExactSize(frame: []const u8, output: []u8, expected_output_len: usize) Error!usize {
    if (output.len < expected_output_len) return error.OutputTooSmall;
    const written = decodeFrameInto(frame, output[0..expected_output_len]) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return written;
}

pub fn decodedFrameSize(frame: []const u8) Error!usize {
    return try frameDecodedSizeLimited(frame, std.math.maxInt(usize));
}

pub fn decodedFrameSizeLimited(frame: []const u8, max_output_len: usize) Error!usize {
    return try frameDecodedSizeLimited(frame, max_output_len);
}

pub fn decodeFrameAllocWithDictionary(allocator: std.mem.Allocator, frame: []const u8, dictionary: NativeDictionary) Error![]u8 {
    const decoded_len = try decodedFrameSizeWithDictionary(frame, dictionary);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = try decodeFrameIntoWithDictionary(frame, out, dictionary);
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodeFrameAllocWithDictionaryExactSize(allocator: std.mem.Allocator, frame: []const u8, dictionary: NativeDictionary, expected_output_len: usize) Error![]u8 {
    const decoded_len = try decodedFrameSizeWithDictionary(frame, dictionary);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeFrameIntoWithDictionary(frame, out, dictionary) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

pub fn decodeFrameIntoWithDictionaryExactSize(frame: []const u8, output: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
    if (output.len < expected_output_len) return error.OutputTooSmall;
    const written = decodeFrameIntoWithDictionary(frame, output[0..expected_output_len], dictionary) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return written;
}

pub fn decodeFrameAllocWithDictionarySet(allocator: std.mem.Allocator, frame: []const u8, dictionary_set: NativeDictionarySet) Error![]u8 {
    const decoded_len = try decodedFrameSizeWithDictionarySet(frame, dictionary_set);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = try decodeFrameIntoWithDictionarySet(frame, out, dictionary_set);
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodeFrameAllocWithDictionarySetExactSize(allocator: std.mem.Allocator, frame: []const u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error![]u8 {
    const decoded_len = try decodedFrameSizeWithDictionarySet(frame, dictionary_set);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeFrameIntoWithDictionarySet(frame, out, dictionary_set) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

pub fn decodeFrameIntoWithDictionarySetExactSize(frame: []const u8, output: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
    if (output.len < expected_output_len) return error.OutputTooSmall;
    const written = decodeFrameIntoWithDictionarySet(frame, output[0..expected_output_len], dictionary_set) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return written;
}

pub fn decodeFrameAllocLimitedWithDictionary(
    allocator: std.mem.Allocator,
    frame: []const u8,
    max_output_len: usize,
    dictionary: NativeDictionary,
) Error![]u8 {
    const decoded_len = try decodedFrameSizeLimitedWithDictionary(frame, max_output_len, dictionary);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = decodeFrameIntoWithDictionary(frame, out, dictionary) catch |err| switch (err) {
        error.OutputTooSmall => return error.OutputLimitExceeded,
        else => return err,
    };
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodeFrameAllocLimitedWithDictionarySet(
    allocator: std.mem.Allocator,
    frame: []const u8,
    max_output_len: usize,
    dictionary_set: NativeDictionarySet,
) Error![]u8 {
    const decoded_len = try decodedFrameSizeLimitedWithDictionarySet(frame, max_output_len, dictionary_set);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = decodeFrameIntoWithDictionarySet(frame, out, dictionary_set) catch |err| switch (err) {
        error.OutputTooSmall => return error.OutputLimitExceeded,
        else => return err,
    };
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodeFrameAppendWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8, dictionary: NativeDictionary) Error!usize {
    const decoded_len = try decodedFrameSizeWithDictionary(frame, dictionary);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeFrameIntoWithDictionary(frame, slot, dictionary) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeFrameAppendExactSizeWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
    const decoded_len = try decodedFrameSizeWithDictionary(frame, dictionary);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    try out.ensureUnusedCapacity(allocator, expected_output_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(expected_output_len);
    const written = decodeFrameIntoWithDictionary(frame, slot, dictionary) catch |err| switch (err) {
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

pub fn decodeFrameAppendWithDictionarySet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8, dictionary_set: NativeDictionarySet) Error!usize {
    const decoded_len = try decodedFrameSizeWithDictionarySet(frame, dictionary_set);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeFrameIntoWithDictionarySet(frame, slot, dictionary_set) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeFrameAppendExactSizeWithDictionarySet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
    const decoded_len = try decodedFrameSizeWithDictionarySet(frame, dictionary_set);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    try out.ensureUnusedCapacity(allocator, expected_output_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(expected_output_len);
    const written = decodeFrameIntoWithDictionarySet(frame, slot, dictionary_set) catch |err| switch (err) {
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

pub fn decodeFrameAppendLimitedWithDictionary(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frame: []const u8,
    max_output_len: usize,
    dictionary: NativeDictionary,
) Error!usize {
    const decoded_len = try decodedFrameSizeLimitedWithDictionary(frame, max_output_len, dictionary);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeFrameIntoWithDictionary(frame, slot, dictionary) catch |err| switch (err) {
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

pub fn decodeFrameAppendLimitedWithDictionarySet(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frame: []const u8,
    max_output_len: usize,
    dictionary_set: NativeDictionarySet,
) Error!usize {
    const decoded_len = try decodedFrameSizeLimitedWithDictionarySet(frame, max_output_len, dictionary_set);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeFrameIntoWithDictionarySet(frame, slot, dictionary_set) catch |err| switch (err) {
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

pub fn decodedFrameSizeWithDictionary(frame: []const u8, dictionary: NativeDictionary) Error!usize {
    return try frameDecodedSizeLimitedWithDictionary(frame, std.math.maxInt(usize), dictionary);
}

pub fn decodedFrameSizeLimitedWithDictionary(frame: []const u8, max_output_len: usize, dictionary: NativeDictionary) Error!usize {
    return try frameDecodedSizeLimitedWithDictionary(frame, max_output_len, dictionary);
}

pub fn decodedFrameSizeWithDictionarySet(frame: []const u8, dictionary_set: NativeDictionarySet) Error!usize {
    return try frameDecodedSizeLimitedWithDictionarySet(frame, std.math.maxInt(usize), dictionary_set);
}

pub fn decodedFrameSizeLimitedWithDictionarySet(frame: []const u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error!usize {
    return try frameDecodedSizeLimitedWithDictionarySet(frame, max_output_len, dictionary_set);
}

pub const decodeNativeFrameAlloc = decodeFrameAlloc;
pub const decodeNativeFrameAppend = decodeFrameAppend;
pub const decodeNativeFrameAppendExactSize = decodeFrameAppendExactSize;
pub const decodeNativeFrameAppendLimited = decodeFrameAppendLimited;
pub const decodeNativeFrameAllocLimited = decodeFrameAllocLimited;
pub const decodeNativeFrameAllocExactSize = decodeFrameAllocExactSize;
pub const decodeNativeFrameIntoExactSize = decodeFrameIntoExactSize;
pub const decodedNativeFrameSize = decodedFrameSize;
pub const decodedNativeFrameSizeLimited = decodedFrameSizeLimited;
pub const decodeNativeFrameAllocWithDictionary = decodeFrameAllocWithDictionary;
pub const decodeNativeFrameAllocWithDictionaryExactSize = decodeFrameAllocWithDictionaryExactSize;
pub const decodeNativeFrameIntoWithDictionaryExactSize = decodeFrameIntoWithDictionaryExactSize;
pub const decodeNativeFrameAppendWithDictionary = decodeFrameAppendWithDictionary;
pub const decodeNativeFrameAppendExactSizeWithDictionary = decodeFrameAppendExactSizeWithDictionary;
pub const decodeNativeFrameAppendLimitedWithDictionary = decodeFrameAppendLimitedWithDictionary;
pub const decodeNativeFrameAllocLimitedWithDictionary = decodeFrameAllocLimitedWithDictionary;
pub const decodeNativeFrameAllocWithDictionarySet = decodeFrameAllocWithDictionarySet;
pub const decodeNativeFrameAllocWithDictionarySetExactSize = decodeFrameAllocWithDictionarySetExactSize;
pub const decodeNativeFrameIntoWithDictionarySetExactSize = decodeFrameIntoWithDictionarySetExactSize;
pub const decodeNativeFrameAppendWithDictionarySet = decodeFrameAppendWithDictionarySet;
pub const decodeNativeFrameAppendExactSizeWithDictionarySet = decodeFrameAppendExactSizeWithDictionarySet;
pub const decodeNativeFrameAppendLimitedWithDictionarySet = decodeFrameAppendLimitedWithDictionarySet;
pub const decodeNativeFrameAllocLimitedWithDictionarySet = decodeFrameAllocLimitedWithDictionarySet;
pub const decodedNativeFrameSizeWithDictionary = decodedFrameSizeWithDictionary;
pub const decodedNativeFrameSizeLimitedWithDictionary = decodedFrameSizeLimitedWithDictionary;
pub const decodedNativeFrameSizeWithDictionarySet = decodedFrameSizeWithDictionarySet;
pub const decodedNativeFrameSizeLimitedWithDictionarySet = decodedFrameSizeLimitedWithDictionarySet;

/// Incremental input/output facade for native LZ4 frames.
///
/// This streaming decoder accepts compressed bytes in arbitrary input chunks
/// and emits decoded bytes through caller-provided output chunks. By default,
/// the frame header starts a block/token cursor immediately. Unchecked payloads
/// and skippable metadata stream from caller input; blocks with checksums retain
/// one encoded block until validation. Decoded history is limited to 64 KiB.
/// Whole-frame prevalidation is available through `Options.input_policy`.
pub const NativeIncrementalFrameDecoder = struct {
    allocator: std.mem.Allocator,
    dictionary: ?NativeDictionary = null,
    dictionary_set: ?NativeDictionarySet = null,
    options: Options = .{},
    phase: InternalPhase = .frame,
    frame_scratch: std.ArrayList(u8) = .empty,
    decoded_scratch: std.ArrayList(u8) = .empty,
    decoded_offset: usize = 0,
    direct_payload_offset: usize = 0,
    direct_payload_len: usize = 0,
    direct_payload_read: usize = 0,
    direct_block_compressed: bool = false,
    direct_block_independent: bool = true,
    direct_block_uses_dictionary_prefix: bool = false,
    direct_block_decoded_len: usize = 0,
    direct_block_decoded_lens: std.ArrayList(usize) = .empty,
    direct_block_index: usize = 0,
    direct_frame_output_start: usize = 0,
    direct_dictionary_history: []const u8 = &.{},
    direct_history: std.ArrayList(u8) = .empty,
    block_stream_cursor_history_start: usize = 0,
    direct_next_block_header_offset: usize = 0,
    direct_decoded_len: usize = 0,
    direct_decoded_read: usize = 0,
    direct_block_checksum: bool = false,
    direct_content_checksum: bool = false,
    direct_content_hasher: std.hash.XxHash32 = std.hash.XxHash32.init(0),
    direct_expected_content_checksum: u32 = 0,
    direct_frame_len: usize = 0,
    block_stream_input_offset: usize = 0,
    block_stream_stage: BlockStreamStage = .block_header,
    block_stream_block_len: usize = 0,
    block_stream_raw_remaining: usize = 0,
    block_stream_block_compressed: bool = false,
    block_stream_block_index: usize = 0,
    block_stream_block_size_max: usize = 0,
    block_stream_block_independent: bool = true,
    block_stream_block_checksum: bool = false,
    block_stream_block_hasher: std.hash.XxHash32 = std.hash.XxHash32.init(0),
    block_stream_compressed_cursor: ?incremental_block_decoder.Cursor = null,
    block_stream_compressed_input_cursor: ?incremental_block_decoder.StreamingCursor = null,
    block_stream_compressed_decoded_len: usize = 0,
    block_stream_compressed_checksum_buffered: usize = 0,
    streamed_compressed_block_count: usize = 0,
    block_stream_frame_expected_len: ?usize = null,
    block_stream_frame_decoded_len: usize = 0,
    block_stream_content_checksum: bool = false,
    block_stream_content_hasher: std.hash.XxHash32 = std.hash.XxHash32.init(0),
    block_stream_checksum: [4]u8 = undefined,
    block_stream_checksum_read: usize = 0,
    input_received: usize = 0,
    output_written: usize = 0,
    skippable_output: []u8 = &.{},
    skippable_written: usize = 0,
    skippable_total: usize = 0,
    skippable_events: []SkippableEvent = &.{},
    skippable_event_count: usize = 0,
    skippable_stream_id: u4 = 0,
    skippable_stream_payload_len: usize = 0,
    skippable_stream_remaining: usize = 0,
    skippable_stream_captured: usize = 0,
    last_error_name: []const u8 = "",
    last_error_phase: ?Phase = null,

    pub const Phase = enum { frame, output, direct_output, done };
    const InternalPhase = enum { frame, output, direct_output, block_stream, skippable_stream, done };
    const BlockStreamStage = enum { block_header, raw_payload, raw_checksum, raw_output, compressed_payload, compressed_input, compressed_decode, compressed_checksum, compressed_output, content_checksum, finished };

    pub const Options = struct {
        /// Start bounded block/token decoding after the header by default.
        /// `.prevalidated_frame` retains a complete frame for structural
        /// prevalidation when it fits the compressed cap, with a block-stream
        /// fallback for larger frames.
        input_policy: core.CompressedInputPolicy = .block_stream,
        /// Maximum compressed bytes retained. Unchecked blocks consume input
        /// progressively; checksummed blocks require this limit to hold one
        /// encoded payload until validation. A skippable
        /// frame retains only its eight-byte header while its payload is
        /// discarded or copied into caller-owned capture storage. Callers
        /// processing hostile streams should set this limit.
        max_compressed_buffer_len: usize = std.math.maxInt(usize),
        /// Maximum decoded bytes in one data frame, including bytes already
        /// emitted. This is a per-frame output limit, not a scratch size or a
        /// cap on cumulative output across a concatenated stream.
        max_decoded_buffer_len: usize = std.math.maxInt(usize),
        /// Optional exact decoded byte count for the whole logical incremental
        /// stream. When set, `step` reports `SizeMismatch` if decoded data would
        /// exceed this count and `finish` reports `SizeMismatch` if EOF arrives
        /// before the count is reached.
        expected_output_len: ?usize = null,
        /// Stop after the first validated data frame and retain any accepted
        /// following bytes for an outer member dispatcher. Skippable frames do
        /// not satisfy this boundary.
        stop_after_first_frame: bool = false,
        skippable_output: []u8 = &.{},
        skippable_events: []SkippableEvent = &.{},
    };
    pub const SkippableEvent = struct { id: u4, payload_len: usize };

    pub const Snapshot = struct {
        phase: Phase,
        input_received: usize,
        output_written: usize,
        decoded_len: ?usize,
        decoded_remaining: ?usize,
        skippable_written: usize,
        skippable_total: usize,
        skippable_truncated: bool,
        skippable_event_count: usize,
        skippable_events_captured: usize,
        trailing_input_bytes: usize,
        last_error_name: []const u8,
        last_error_phase: ?Phase,
    };

    pub fn init(allocator: std.mem.Allocator) NativeIncrementalFrameDecoder {
        return .{ .allocator = allocator };
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) NativeIncrementalFrameDecoder {
        return .{ .allocator = allocator, .options = options, .skippable_output = options.skippable_output, .skippable_events = options.skippable_events };
    }

    pub fn initWithDictionary(allocator: std.mem.Allocator, dictionary: NativeDictionary) NativeIncrementalFrameDecoder {
        return .{ .allocator = allocator, .dictionary = dictionary };
    }

    pub fn initWithDictionaryAndOptions(allocator: std.mem.Allocator, dictionary: NativeDictionary, options: Options) NativeIncrementalFrameDecoder {
        return .{ .allocator = allocator, .dictionary = dictionary, .options = options, .skippable_output = options.skippable_output, .skippable_events = options.skippable_events };
    }

    pub fn initWithDictionarySet(allocator: std.mem.Allocator, dictionary_set: NativeDictionarySet) NativeIncrementalFrameDecoder {
        return .{ .allocator = allocator, .dictionary_set = dictionary_set };
    }

    pub fn initWithDictionarySetAndOptions(allocator: std.mem.Allocator, dictionary_set: NativeDictionarySet, options: Options) NativeIncrementalFrameDecoder {
        return .{ .allocator = allocator, .dictionary_set = dictionary_set, .options = options, .skippable_output = options.skippable_output, .skippable_events = options.skippable_events };
    }

    pub fn deinit(self: *NativeIncrementalFrameDecoder) void {
        self.direct_history.deinit(self.allocator);
        self.direct_block_decoded_lens.deinit(self.allocator);
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
        self.resetBlockStream();
        self.input_received = 0;
        self.output_written = 0;
        self.last_error_name = "";
        self.last_error_phase = null;
        self.skippable_written = 0;
        self.skippable_total = 0;
        self.skippable_event_count = 0;
        self.streamed_compressed_block_count = 0;
        self.resetSkippableStream();
    }

    pub fn snapshot(self: *const NativeIncrementalFrameDecoder) Snapshot {
        const decoded_len: ?usize = switch (self.phase) {
            .frame => null,
            .direct_output => self.direct_decoded_len,
            .block_stream => self.block_stream_frame_expected_len,
            .skippable_stream => null,
            .output, .done => self.decoded_scratch.items.len,
        };
        const decoded_remaining: ?usize = switch (self.phase) {
            .frame => null,
            .direct_output => self.direct_decoded_len - self.direct_decoded_read,
            .block_stream => if (self.block_stream_frame_expected_len) |expected| expected - self.block_stream_frame_decoded_len else null,
            .skippable_stream => null,
            .output, .done => self.decoded_scratch.items.len - self.decoded_offset,
        };
        return .{
            .phase = publicPhase(self.phase),
            .input_received = self.input_received,
            .output_written = self.output_written,
            .decoded_len = decoded_len,
            .decoded_remaining = decoded_remaining,
            .skippable_written = self.skippable_written,
            .skippable_total = self.skippable_total,
            .skippable_truncated = self.skippable_written != self.skippable_total,
            .skippable_event_count = self.skippable_event_count,
            .skippable_events_captured = @min(self.skippable_event_count, self.skippable_events.len),
            .trailing_input_bytes = self.trailingInput().len,
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

    /// Number of compressed input bytes currently retained by the decoder.
    pub fn compressedBufferedBytes(self: *const NativeIncrementalFrameDecoder) usize {
        return self.frame_scratch.items.len;
    }

    pub fn trailingInput(self: *const NativeIncrementalFrameDecoder) []const u8 {
        if (!self.options.stop_after_first_frame or self.phase != .done) return &.{};
        return self.frame_scratch.items;
    }

    /// Allocated capacity backing retained compressed input. With a finite
    /// `max_compressed_buffer_len`, this never grows past that configured cap.
    pub fn compressedBufferCapacity(self: *const NativeIncrementalFrameDecoder) usize {
        return self.frame_scratch.capacity;
    }

    /// Number of decoded bytes retained by the whole-frame or block fallback.
    /// Direct and compressed-block cursor paths keep this at zero.
    pub fn decodedBufferedBytes(self: *const NativeIncrementalFrameDecoder) usize {
        return self.decoded_scratch.items.len - self.decoded_offset;
    }

    /// Allocated capacity backing decoded fallback output. A fresh decoder that
    /// remains on direct or cursor-based output keeps this at zero.
    pub fn decodedBufferCapacity(self: *const NativeIncrementalFrameDecoder) usize {
        return self.decoded_scratch.capacity;
    }

    /// True while input prefixes are released block-by-block instead of
    /// retaining the complete encoded frame.
    pub fn isBlockStreaming(self: *const NativeIncrementalFrameDecoder) bool {
        return self.phase == .block_stream;
    }

    /// True while a compressed block is being decoded directly into caller
    /// output across resumable `step()` calls.
    pub fn isCompressedBlockStreaming(self: *const NativeIncrementalFrameDecoder) bool {
        return self.phase == .block_stream and
            (self.block_stream_compressed_cursor != null or self.block_stream_compressed_input_cursor != null);
    }

    /// Number of compressed blocks decoded incrementally without materializing
    /// a complete decoded block in scratch storage.
    pub fn streamedCompressedBlockCount(self: *const NativeIncrementalFrameDecoder) usize {
        return self.streamed_compressed_block_count;
    }

    pub fn finish(self: *NativeIncrementalFrameDecoder) Error!void {
        if (self.phase == .done) return;
        if (self.phase == .skippable_stream) {
            self.recordError(.skippable_stream, error.TruncatedFrame);
            return error.TruncatedFrame;
        }
        if (self.phase == .block_stream) {
            const err: Error = if ((self.block_stream_stage == .raw_payload and
                self.block_stream_raw_remaining != 0 and self.blockStreamInput().len != 0) or
                (self.block_stream_stage == .raw_output and self.block_stream_raw_remaining != 0) or
                (self.block_stream_stage == .compressed_output and
                    (self.block_stream_compressed_cursor != null or
                        self.decoded_offset != self.decoded_scratch.items.len)) or
                (self.block_stream_stage == .compressed_input and
                    (self.block_stream_compressed_input_cursor.?.compressedInputComplete() or
                        self.blockStreamInput().len != 0)))
                error.OutputTooSmall
            else
                error.TruncatedFrame;
            self.recordError(.block_stream, err);
            return err;
        }
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
            // Treat fresh input after a completed frame as the next member of a
            // caller-driven concatenated stream.  Cumulative counters are kept
            // intact; `reset()` remains the explicit way to start a new logical
            // decode session with zeroed diagnostics.
            self.phase = .frame;
            self.decoded_scratch.clearRetainingCapacity();
            self.decoded_offset = 0;
            self.resetDirectOutput();
            self.resetSkippableStream();
        }

        var input_read: usize = 0;
        var output_written_step: usize = 0;
        while (true) {
            switch (self.phase) {
                .frame => {
                    if (input_read < input.len) {
                        try self.appendFrameInput(input, &input_read);
                    }

                    const skippable_started = self.beginSkippableStreamIfHeaderAvailable() catch |err| {
                        self.recordError(.frame, err);
                        return err;
                    };
                    if (skippable_started) {
                        self.phase = .skippable_stream;
                        continue;
                    }
                    if (self.options.input_policy == .block_stream and self.frame_scratch.items.len != 0) {
                        const block_stream_started = self.beginBlockStreamIfSupported() catch |err| {
                            self.recordError(.frame, err);
                            return err;
                        };
                        if (block_stream_started) {
                            self.phase = .block_stream;
                            continue;
                        }
                        if (self.frame_scratch.items.len >= self.options.max_compressed_buffer_len) {
                            self.recordError(.frame, error.OutputLimitExceeded);
                            return error.OutputLimitExceeded;
                        }
                        return .{
                            .progress = .{ .input_read = input_read, .output_written = output_written_step },
                            .status = .need_input,
                        };
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
                            const block_stream_supported = self.beginBlockStreamIfSupported() catch |err| {
                                self.recordError(.frame, err);
                                return err;
                            };
                            if (block_stream_supported) {
                                self.phase = .block_stream;
                                continue;
                            }
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
                        if (try self.finishFirstDataFrame())
                            return .{
                                .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                .status = .done,
                            };
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
                        if (try self.finishFirstDataFrame())
                            return .{
                                .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                .status = .done,
                            };
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
                            try self.switchDirectOutputToBlockStream();
                            continue;
                        }
                        const source = self.frame_scratch.items[self.direct_payload_offset..][0..self.direct_payload_len];
                        const written = if (self.direct_block_uses_dictionary_prefix) written: {
                            break :written try decodeBlockWithPrefixIntoSliceNoAlloc(
                                source,
                                output[output_written_step..][0..self.direct_block_decoded_len],
                                self.direct_block_decoded_len,
                                self.direct_dictionary_history,
                            );
                        } else if (!self.direct_block_independent) written: {
                            break :written try decodeBlockWithPrefixIntoSliceNoAlloc(
                                source,
                                output[output_written_step..][0..self.direct_block_decoded_len],
                                self.direct_block_decoded_len,
                                self.direct_history.items,
                            );
                        } else written: {
                            var written_abs = output_written_step;
                            try decodeBlockIntoBuffer(source, output, &written_abs, self.direct_block_decoded_len, output_written_step);
                            break :written written_abs - output_written_step;
                        };
                        if (written != self.direct_block_decoded_len) return error.SizeMismatch;
                        if (self.direct_content_checksum) self.direct_content_hasher.update(output[output_written_step..][0..written]);
                        if (!self.direct_block_independent) try self.rememberDirectOutput(output[output_written_step..][0..written]);
                        self.direct_payload_read = self.direct_payload_len;
                        self.direct_decoded_read += written;
                        output_written_step += written;
                        self.output_written += written;
                        continue;
                    }
                    const n = @min(self.direct_payload_len - self.direct_payload_read, output.len - output_written_step);
                    const source_offset = self.direct_payload_offset + self.direct_payload_read;
                    @memcpy(output[output_written_step..][0..n], self.frame_scratch.items[source_offset..][0..n]);
                    if (self.direct_content_checksum) self.direct_content_hasher.update(output[output_written_step..][0..n]);
                    if (!self.direct_block_independent) try self.rememberDirectOutput(output[output_written_step..][0..n]);
                    self.direct_payload_read += n;
                    self.direct_decoded_read += n;
                    output_written_step += n;
                    self.output_written += n;
                },
                .block_stream => {
                    switch (self.block_stream_stage) {
                        .block_header => {
                            if (self.blockStreamInput().len < 4 and input_read < input.len)
                                try self.appendBlockStreamInput(input, &input_read);
                            if (self.blockStreamInput().len < 4) {
                                if (self.blockStreamInput().len >= self.options.max_compressed_buffer_len) {
                                    self.recordError(.block_stream, error.OutputLimitExceeded);
                                    return error.OutputLimitExceeded;
                                }
                                return .{
                                    .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                    .status = .need_input,
                                };
                            }
                            const block_header = std.mem.readInt(u32, self.blockStreamInput()[0..4], .little);
                            self.consumeBlockStreamInput(4);
                            if (block_header == 0) {
                                self.block_stream_stage = if (self.block_stream_content_checksum) .content_checksum else .finished;
                                self.block_stream_checksum_read = 0;
                                continue;
                            }
                            const block_len: usize = @intCast(block_header & 0x7fff_ffff);
                            if (block_len > self.block_stream_block_size_max) {
                                self.recordError(.block_stream, error.CorruptFrame);
                                return error.CorruptFrame;
                            }
                            self.block_stream_block_len = block_len;
                            self.block_stream_raw_remaining = block_len;
                            self.block_stream_block_compressed = (block_header & 0x8000_0000) == 0;
                            self.block_stream_block_hasher = std.hash.XxHash32.init(0);
                            if (self.block_stream_block_compressed and
                                !self.block_stream_block_checksum and
                                (self.options.input_policy == .block_stream or block_len > self.options.max_compressed_buffer_len))
                            {
                                try self.startBlockStreamCompressedInputCursor(block_len);
                            } else {
                                self.block_stream_stage = if (self.block_stream_block_compressed or self.block_stream_block_checksum) .compressed_payload else .raw_payload;
                            }
                        },
                        .raw_payload => {
                            if (self.block_stream_raw_remaining == 0) {
                                self.block_stream_stage = .block_header;
                                self.block_stream_block_index += 1;
                                continue;
                            }
                            if (output_written_step == output.len) {
                                return .{
                                    .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                    .status = .need_output,
                                };
                            }
                            const buffered = self.blockStreamInput();
                            const source_available = if (buffered.len != 0) buffered else input[input_read..];
                            if (source_available.len == 0) {
                                return .{
                                    .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                    .status = .need_input,
                                };
                            }
                            const n = @min(self.block_stream_raw_remaining, @min(source_available.len, output.len - output_written_step));
                            try self.ensureBlockStreamOutputFits(n);
                            const source = source_available[0..n];
                            @memcpy(output[output_written_step..][0..n], source);
                            if (self.block_stream_content_checksum) self.block_stream_content_hasher.update(source);
                            if (!self.block_stream_block_independent) try self.rememberBlockStreamCursorOutput(source);
                            if (buffered.len != 0) {
                                self.consumeBlockStreamInput(n);
                            } else {
                                input_read += n;
                                self.input_received += n;
                            }
                            self.block_stream_raw_remaining -= n;
                            self.block_stream_frame_decoded_len += n;
                            self.output_written += n;
                            output_written_step += n;
                        },
                        .compressed_payload => {
                            if (self.blockStreamInput().len < self.block_stream_block_len and input_read < input.len)
                                try self.appendBlockStreamInput(input, &input_read);
                            if (self.blockStreamInput().len < self.block_stream_block_len) {
                                if (self.blockStreamInput().len >= self.options.max_compressed_buffer_len) {
                                    self.recordError(.block_stream, error.OutputLimitExceeded);
                                    return error.OutputLimitExceeded;
                                }
                                return .{
                                    .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                    .status = .need_input,
                                };
                            }
                            if (self.block_stream_block_compressed) {
                                self.block_stream_stage = .compressed_decode;
                            } else {
                                try self.ensureBlockStreamOutputFits(self.block_stream_block_len);
                                self.block_stream_block_hasher.update(self.blockStreamInput()[0..self.block_stream_block_len]);
                                self.block_stream_checksum_read = 0;
                                self.block_stream_compressed_checksum_buffered = 0;
                                self.block_stream_stage = .raw_checksum;
                            }
                        },
                        .compressed_input => {
                            const cursor = if (self.block_stream_compressed_input_cursor) |*cursor| cursor else {
                                self.recordError(.block_stream, error.CorruptFrame);
                                return error.CorruptFrame;
                            };
                            const buffered = self.blockStreamInput();
                            const source = if (buffered.len != 0) buffered else input[input_read..];
                            const output_start = output_written_step;
                            const result = cursor.step(source, .{
                                .bytes = self.direct_history.items,
                                .start = self.block_stream_cursor_history_start,
                            }, output[output_start..]) catch |err| {
                                self.recordError(.block_stream, err);
                                return err;
                            };
                            if (buffered.len != 0) {
                                self.consumeBlockStreamInput(result.input_read);
                            } else {
                                input_read += result.input_read;
                                self.input_received += result.input_read;
                            }
                            const produced = output[output_start..][0..result.output_written];
                            try self.rememberBlockStreamCursorOutput(produced);
                            if (self.block_stream_content_checksum) self.block_stream_content_hasher.update(produced);
                            self.block_stream_frame_decoded_len += produced.len;
                            self.output_written += produced.len;
                            output_written_step += produced.len;
                            switch (result.status) {
                                .need_input => {
                                    if (input_read < input.len) continue;
                                    return .{
                                        .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                        .status = .need_input,
                                    };
                                },
                                .need_output => return .{
                                    .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                    .status = .need_output,
                                },
                                .done => {
                                    self.block_stream_compressed_input_cursor = null;
                                    if (self.block_stream_block_independent) {
                                        self.direct_history.clearRetainingCapacity();
                                        self.block_stream_cursor_history_start = 0;
                                        try self.rememberDirectOutput(self.direct_dictionary_history);
                                    }
                                    self.streamed_compressed_block_count += 1;
                                    self.block_stream_block_index += 1;
                                    self.block_stream_stage = .block_header;
                                    continue;
                                },
                            }
                        },
                        .compressed_decode => {
                            self.linearizeBlockStreamCursorHistory();
                            const block = self.blockStreamInput()[0..self.block_stream_block_len];
                            const history = if (self.direct_dictionary_history.len != 0 and
                                (self.block_stream_block_independent or self.block_stream_block_index == 0))
                                self.direct_dictionary_history
                            else if (!self.block_stream_block_independent)
                                self.direct_history.items
                            else
                                &.{};
                            const remaining_limit = self.options.max_decoded_buffer_len - self.block_stream_frame_decoded_len;
                            const decoded_len = decodedBlockSizeWithPrefixLimited(block, history, remaining_limit) catch |err| {
                                self.recordError(.block_stream, err);
                                return err;
                            };
                            try self.ensureBlockStreamOutputFits(decoded_len);
                            self.block_stream_compressed_decoded_len = decoded_len;
                            if (self.block_stream_block_checksum) {
                                self.block_stream_block_hasher.update(block);
                                self.block_stream_checksum_read = 0;
                                self.block_stream_compressed_checksum_buffered = 0;
                                self.block_stream_stage = .compressed_checksum;
                            } else {
                                try self.startBlockStreamCompressedCursor();
                            }
                            continue;
                        },
                        .compressed_checksum, .raw_checksum => {
                            if (self.block_stream_checksum_read == 0) {
                                const buffered = self.blockStreamInput();
                                const buffered_after_payload = buffered.len - self.block_stream_block_len;
                                const n = @min(self.block_stream_checksum.len, buffered_after_payload);
                                @memcpy(self.block_stream_checksum[0..n], buffered[self.block_stream_block_len..][0..n]);
                                self.block_stream_checksum_read = n;
                                self.block_stream_compressed_checksum_buffered = n;
                            }
                            while (self.block_stream_checksum_read < self.block_stream_checksum.len and input_read < input.len) {
                                self.block_stream_checksum[self.block_stream_checksum_read] = input[input_read];
                                self.block_stream_checksum_read += 1;
                                input_read += 1;
                                self.input_received += 1;
                            }
                            if (self.block_stream_checksum_read != self.block_stream_checksum.len) {
                                return .{
                                    .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                    .status = .need_input,
                                };
                            }
                            const expected = std.mem.readInt(u32, &self.block_stream_checksum, .little);
                            if (self.block_stream_block_hasher.final() != expected) {
                                self.recordError(.block_stream, error.ChecksumMismatch);
                                return error.ChecksumMismatch;
                            }
                            if (self.block_stream_block_compressed) {
                                try self.startBlockStreamCompressedCursor();
                            } else {
                                self.block_stream_stage = .raw_output;
                            }
                            continue;
                        },
                        .raw_output => {
                            if (self.block_stream_raw_remaining == 0) {
                                self.consumeBlockStreamInput(self.block_stream_block_len + self.block_stream_compressed_checksum_buffered);
                                self.block_stream_block_index += 1;
                                self.block_stream_stage = .block_header;
                                continue;
                            }
                            if (output_written_step == output.len) return .{
                                .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                .status = .need_output,
                            };
                            const n = @min(self.block_stream_raw_remaining, output.len - output_written_step);
                            const offset = self.block_stream_block_len - self.block_stream_raw_remaining;
                            const source = self.blockStreamInput()[offset..][0..n];
                            @memcpy(output[output_written_step..][0..n], source);
                            if (self.block_stream_content_checksum) self.block_stream_content_hasher.update(source);
                            if (!self.block_stream_block_independent) try self.rememberBlockStreamCursorOutput(source);
                            self.block_stream_raw_remaining -= n;
                            self.block_stream_frame_decoded_len += n;
                            self.output_written += n;
                            output_written_step += n;
                        },
                        .compressed_output => {
                            const cursor = if (self.block_stream_compressed_cursor) |*cursor| cursor else {
                                self.recordError(.block_stream, error.CorruptFrame);
                                return error.CorruptFrame;
                            };
                            const output_start = output_written_step;
                            const block = self.blockStreamInput()[0..self.block_stream_block_len];
                            const result = cursor.step(block, .{
                                .bytes = self.direct_history.items,
                                .start = self.block_stream_cursor_history_start,
                            }, output[output_start..]) catch |err| {
                                self.recordError(.block_stream, err);
                                return err;
                            };
                            const produced = output[output_start..][0..result.output_written];
                            try self.rememberBlockStreamCursorOutput(produced);
                            if (self.block_stream_content_checksum) self.block_stream_content_hasher.update(produced);
                            self.block_stream_frame_decoded_len += produced.len;
                            self.output_written += produced.len;
                            output_written_step += produced.len;
                            if (!result.done) {
                                if (result.output_written != 0) continue;
                                return .{
                                    .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                    .status = .need_output,
                                };
                            }
                            self.consumeBlockStreamInput(
                                self.block_stream_block_len + self.block_stream_compressed_checksum_buffered,
                            );
                            self.block_stream_compressed_cursor = null;
                            if (self.block_stream_block_independent) {
                                self.direct_history.clearRetainingCapacity();
                                self.block_stream_cursor_history_start = 0;
                                try self.rememberDirectOutput(self.direct_dictionary_history);
                            }
                            self.streamed_compressed_block_count += 1;
                            self.block_stream_block_index += 1;
                            self.block_stream_stage = .block_header;
                            continue;
                        },
                        .content_checksum => {
                            while (self.block_stream_checksum_read < self.block_stream_checksum.len) {
                                if (self.blockStreamInput().len == 0 and input_read < input.len) try self.appendBlockStreamInput(input, &input_read);
                                if (self.blockStreamInput().len == 0) {
                                    return .{
                                        .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                        .status = .need_input,
                                    };
                                }
                                const n = @min(self.block_stream_checksum.len - self.block_stream_checksum_read, self.blockStreamInput().len);
                                @memcpy(self.block_stream_checksum[self.block_stream_checksum_read..][0..n], self.blockStreamInput()[0..n]);
                                self.block_stream_checksum_read += n;
                                self.consumeBlockStreamInput(n);
                            }
                            const expected = std.mem.readInt(u32, &self.block_stream_checksum, .little);
                            if (self.block_stream_content_hasher.final() != expected) {
                                self.recordError(.block_stream, error.ChecksumMismatch);
                                return error.ChecksumMismatch;
                            }
                            self.block_stream_stage = .finished;
                        },
                        .finished => {
                            try self.finishBlockStreamFrame();
                            if (try self.finishFirstDataFrame())
                                return .{
                                    .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                    .status = .done,
                                };
                            if (self.blockStreamInput().len != 0 or input_read < input.len) {
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
                        },
                    }
                },
                .skippable_stream => {
                    while (self.skippable_stream_remaining != 0) {
                        if (input_read == input.len) {
                            return .{
                                .progress = .{ .input_read = input_read, .output_written = output_written_step },
                                .status = .need_input,
                            };
                        }
                        const n = @min(self.skippable_stream_remaining, input.len - input_read);
                        self.captureSkippableStreamBytes(input[input_read..][0..n]);
                        input_read += n;
                        self.input_received += n;
                        self.skippable_stream_remaining -= n;
                    }
                    try self.finishSkippableStream();
                    self.phase = .frame;
                    if (self.frame_scratch.items.len != 0 or input_read < input.len) continue;
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
                },
                .done => return .{
                    .progress = .{ .input_read = input_read, .output_written = output_written_step },
                    .status = .done,
                },
            }
        }
    }

    fn resetDirectOutput(self: *NativeIncrementalFrameDecoder) void {
        self.direct_payload_offset = 0;
        self.direct_payload_len = 0;
        self.direct_payload_read = 0;
        self.direct_block_compressed = false;
        self.direct_block_independent = true;
        self.direct_block_uses_dictionary_prefix = false;
        self.direct_block_decoded_len = 0;
        self.direct_block_decoded_lens.clearRetainingCapacity();
        self.direct_block_index = 0;
        self.direct_frame_output_start = 0;
        self.direct_dictionary_history = &.{};
        self.direct_history.clearRetainingCapacity();
        self.block_stream_cursor_history_start = 0;
        self.direct_next_block_header_offset = 0;
        self.direct_decoded_len = 0;
        self.direct_decoded_read = 0;
        self.direct_block_checksum = false;
        self.direct_content_checksum = false;
        self.direct_content_hasher = std.hash.XxHash32.init(0);
        self.direct_expected_content_checksum = 0;
        self.direct_frame_len = 0;
    }

    fn resetBlockStream(self: *NativeIncrementalFrameDecoder) void {
        self.block_stream_input_offset = 0;
        self.block_stream_stage = .block_header;
        self.block_stream_block_len = 0;
        self.block_stream_raw_remaining = 0;
        self.block_stream_block_compressed = false;
        self.block_stream_block_index = 0;
        self.block_stream_block_size_max = 0;
        self.block_stream_block_independent = true;
        self.block_stream_block_checksum = false;
        self.block_stream_block_hasher = std.hash.XxHash32.init(0);
        self.block_stream_compressed_cursor = null;
        self.block_stream_compressed_input_cursor = null;
        self.block_stream_cursor_history_start = 0;
        self.block_stream_compressed_decoded_len = 0;
        self.block_stream_compressed_checksum_buffered = 0;
        self.block_stream_frame_expected_len = null;
        self.block_stream_frame_decoded_len = 0;
        self.block_stream_content_checksum = false;
        self.block_stream_content_hasher = std.hash.XxHash32.init(0);
        self.block_stream_checksum_read = 0;
    }

    fn beginBlockStreamIfSupported(self: *NativeIncrementalFrameDecoder) Error!bool {
        if (self.frame_scratch.items.len < 4) return false;
        const magic = std.mem.readInt(u32, self.frame_scratch.items[0..4], .little);
        if (magic != frame_magic_u32) {
            if (magic >= skippable_magic_min and magic <= skippable_magic_max) return false;
            return error.CorruptFrame;
        }
        const header = parseFrameHeader(self.frame_scratch.items) catch |err| switch (err) {
            error.TruncatedFrame => return false,
            else => return err,
        };
        const dictionary_history = try self.resolveDirectDictionaryHistory(header);
        const frame_expected_len: ?usize = if (header.expected_content_size) |size| try checkedU64ToUsize(size) else null;
        if (frame_expected_len) |expected| {
            if (expected > self.options.max_decoded_buffer_len) return error.OutputLimitExceeded;
            if (self.options.expected_output_len) |stream_expected| {
                if (self.output_written > stream_expected or expected > stream_expected - self.output_written)
                    return error.SizeMismatch;
            }
        }

        self.decoded_scratch.clearRetainingCapacity();
        self.decoded_offset = 0;
        self.resetBlockStream();
        self.block_stream_block_size_max = header.block_size_max;
        self.block_stream_block_independent = header.block_independent;
        self.block_stream_block_checksum = header.block_checksum;
        self.block_stream_frame_expected_len = frame_expected_len;
        self.block_stream_content_checksum = header.content_checksum;
        self.direct_dictionary_history = dictionary_history;
        self.direct_history.clearRetainingCapacity();
        if (!header.block_independent)
            try self.direct_history.ensureTotalCapacityPrecise(self.allocator, max_block_history_len);
        try self.rememberDirectOutput(dictionary_history);
        self.block_stream_input_offset = header.payload_offset;
        return true;
    }

    fn blockStreamInput(self: *const NativeIncrementalFrameDecoder) []const u8 {
        return self.frame_scratch.items[self.block_stream_input_offset..];
    }

    fn startBlockStreamCompressedCursor(self: *NativeIncrementalFrameDecoder) Error!void {
        self.linearizeBlockStreamCursorHistory();
        if (self.block_stream_block_independent) {
            self.direct_history.clearRetainingCapacity();
            self.block_stream_cursor_history_start = 0;
            try self.rememberDirectOutput(self.direct_dictionary_history);
        }
        const combined_history_len = std.math.add(
            usize,
            self.direct_history.items.len,
            self.block_stream_compressed_decoded_len,
        ) catch return error.IntegerOverflow;
        const history_capacity = @min(max_block_history_len, combined_history_len);
        try self.direct_history.ensureTotalCapacityPrecise(self.allocator, history_capacity);
        self.block_stream_compressed_cursor = incremental_block_decoder.Cursor.init(
            self.block_stream_compressed_decoded_len,
            self.direct_history.items.len,
        );
        self.decoded_scratch.clearRetainingCapacity();
        self.decoded_offset = 0;
        self.block_stream_stage = .compressed_output;
    }

    fn startBlockStreamCompressedInputCursor(self: *NativeIncrementalFrameDecoder, compressed_len: usize) Error!void {
        self.linearizeBlockStreamCursorHistory();
        if (self.block_stream_block_independent) {
            self.direct_history.clearRetainingCapacity();
            self.block_stream_cursor_history_start = 0;
            try self.rememberDirectOutput(self.direct_dictionary_history);
        }
        try self.direct_history.ensureTotalCapacityPrecise(self.allocator, max_block_history_len);
        var max_decoded_len = self.options.max_decoded_buffer_len - self.block_stream_frame_decoded_len;
        var decoded_limit_error: incremental_block_decoder.Error = error.OutputLimitExceeded;
        if (self.block_stream_frame_expected_len) |expected| {
            if (self.block_stream_frame_decoded_len > expected) return error.SizeMismatch;
            const remaining = expected - self.block_stream_frame_decoded_len;
            if (remaining < max_decoded_len) {
                max_decoded_len = remaining;
                decoded_limit_error = error.SizeMismatch;
            }
        }
        if (self.options.expected_output_len) |expected| {
            if (self.output_written > expected) return error.SizeMismatch;
            const remaining = expected - self.output_written;
            if (remaining < max_decoded_len) {
                max_decoded_len = remaining;
                decoded_limit_error = error.SizeMismatch;
            }
        }
        self.block_stream_compressed_input_cursor = incremental_block_decoder.StreamingCursor.init(
            compressed_len,
            self.direct_history.items.len,
            max_decoded_len,
            decoded_limit_error,
        );
        self.decoded_scratch.clearRetainingCapacity();
        self.decoded_offset = 0;
        self.block_stream_stage = .compressed_input;
    }

    fn rememberBlockStreamCursorOutput(self: *NativeIncrementalFrameDecoder, bytes: []const u8) Error!void {
        if (bytes.len == 0) return;
        const history = &self.direct_history;
        if (history.items.len < max_block_history_len) {
            const n = @min(bytes.len, max_block_history_len - history.items.len);
            try history.ensureTotalCapacityPrecise(self.allocator, history.items.len + n);
            history.appendSliceAssumeCapacity(bytes[0..n]);
            if (n == bytes.len) return;
            const remaining = bytes[n..];
            if (remaining.len >= max_block_history_len) {
                @memcpy(history.items, remaining[remaining.len - max_block_history_len ..]);
                self.block_stream_cursor_history_start = 0;
                return;
            }
            @memcpy(history.items[0..remaining.len], remaining);
            self.block_stream_cursor_history_start = remaining.len;
            return;
        }
        if (bytes.len >= max_block_history_len) {
            @memcpy(history.items, bytes[bytes.len - max_block_history_len ..]);
            self.block_stream_cursor_history_start = 0;
            return;
        }
        const first_len = @min(bytes.len, max_block_history_len - self.block_stream_cursor_history_start);
        @memcpy(history.items[self.block_stream_cursor_history_start..][0..first_len], bytes[0..first_len]);
        @memcpy(history.items[0 .. bytes.len - first_len], bytes[first_len..]);
        self.block_stream_cursor_history_start = (self.block_stream_cursor_history_start + bytes.len) % max_block_history_len;
    }

    fn linearizeBlockStreamCursorHistory(self: *NativeIncrementalFrameDecoder) void {
        if (self.block_stream_cursor_history_start == 0) return;
        std.mem.rotate(u8, self.direct_history.items, self.block_stream_cursor_history_start);
        self.block_stream_cursor_history_start = 0;
    }

    fn consumeBlockStreamInput(self: *NativeIncrementalFrameDecoder, n: usize) void {
        self.block_stream_input_offset += n;
        if (self.block_stream_input_offset == self.frame_scratch.items.len) {
            self.frame_scratch.clearRetainingCapacity();
            self.block_stream_input_offset = 0;
        }
    }

    fn compactBlockStreamInput(self: *NativeIncrementalFrameDecoder) void {
        if (self.block_stream_input_offset == 0) return;
        const remaining_len = self.frame_scratch.items.len - self.block_stream_input_offset;
        std.mem.copyForwards(u8, self.frame_scratch.items[0..remaining_len], self.blockStreamInput());
        self.frame_scratch.shrinkRetainingCapacity(remaining_len);
        self.block_stream_input_offset = 0;
    }

    fn appendBlockStreamInput(self: *NativeIncrementalFrameDecoder, input: []const u8, input_read: *usize) Error!void {
        if (self.blockStreamInput().len > self.options.max_compressed_buffer_len) {
            self.recordError(.block_stream, error.OutputLimitExceeded);
            return error.OutputLimitExceeded;
        }
        self.compactBlockStreamInput();
        const remaining_capacity = self.options.max_compressed_buffer_len - self.frame_scratch.items.len;
        if (remaining_capacity == 0) return;
        const target_len: usize = switch (self.block_stream_stage) {
            .compressed_payload => self.block_stream_block_len,
            .block_header => 4,
            .content_checksum => self.block_stream_checksum.len - self.block_stream_checksum_read,
            else => unreachable,
        };
        const n = @min(target_len -| self.frame_scratch.items.len, @min(remaining_capacity, input.len - input_read.*));
        const needed = std.math.add(usize, self.frame_scratch.items.len, n) catch return error.IntegerOverflow;
        try self.ensureCompressedScratchCapacity(needed);
        self.frame_scratch.appendSliceAssumeCapacity(input[input_read.*..][0..n]);
        input_read.* += n;
        self.input_received += n;
    }

    fn ensureBlockStreamOutputFits(self: *NativeIncrementalFrameDecoder, additional: usize) Error!void {
        const next_frame_len = std.math.add(usize, self.block_stream_frame_decoded_len, additional) catch {
            self.recordError(.block_stream, error.IntegerOverflow);
            return error.IntegerOverflow;
        };
        if (next_frame_len > self.options.max_decoded_buffer_len) {
            self.recordError(.block_stream, error.OutputLimitExceeded);
            return error.OutputLimitExceeded;
        }
        if (self.block_stream_frame_expected_len) |expected| {
            if (next_frame_len > expected) {
                self.recordError(.block_stream, error.SizeMismatch);
                return error.SizeMismatch;
            }
        }
        if (self.options.expected_output_len) |expected| {
            const next_total = std.math.add(usize, self.output_written, additional) catch {
                self.recordError(.block_stream, error.IntegerOverflow);
                return error.IntegerOverflow;
            };
            if (next_total > expected) {
                self.recordError(.block_stream, error.SizeMismatch);
                return error.SizeMismatch;
            }
        }
    }

    fn finishBlockStreamFrame(self: *NativeIncrementalFrameDecoder) Error!void {
        if (self.block_stream_frame_expected_len) |expected| {
            if (self.block_stream_frame_decoded_len != expected) {
                self.recordError(.block_stream, error.SizeMismatch);
                return error.SizeMismatch;
            }
        }
        self.compactBlockStreamInput();
        self.resetBlockStream();
        self.resetDirectOutput();
        self.phase = .frame;
    }

    fn finishFirstDataFrame(self: *NativeIncrementalFrameDecoder) Error!bool {
        if (!self.options.stop_after_first_frame) return false;
        if (self.options.expected_output_len) |expected|
            if (self.output_written != expected) return error.SizeMismatch;
        self.phase = .done;
        return true;
    }

    fn resetSkippableStream(self: *NativeIncrementalFrameDecoder) void {
        self.skippable_stream_id = 0;
        self.skippable_stream_payload_len = 0;
        self.skippable_stream_remaining = 0;
        self.skippable_stream_captured = 0;
    }

    fn beginSkippableStreamIfHeaderAvailable(self: *NativeIncrementalFrameDecoder) Error!bool {
        if (self.frame_scratch.items.len < 8) return false;
        const magic = std.mem.readInt(u32, self.frame_scratch.items[0..4], .little);
        if (magic < skippable_magic_min or magic > skippable_magic_max) return false;
        const payload_len: usize = @intCast(std.mem.readInt(u32, self.frame_scratch.items[4..8], .little));
        _ = std.math.add(usize, self.skippable_total, payload_len) catch return error.IntegerOverflow;
        _ = std.math.add(usize, self.skippable_event_count, 1) catch return error.IntegerOverflow;
        self.resetSkippableStream();
        self.skippable_stream_id = @intCast(magic - skippable_magic_min);
        self.skippable_stream_payload_len = payload_len;
        self.skippable_stream_remaining = payload_len;
        const buffered_payload_len = @min(payload_len, self.frame_scratch.items.len - 8);
        self.captureSkippableStreamBytes(self.frame_scratch.items[8..][0..buffered_payload_len]);
        self.skippable_stream_remaining -= buffered_payload_len;
        self.discardFrameScratchPrefix(8 + buffered_payload_len);
        return true;
    }

    fn captureSkippableStreamBytes(self: *NativeIncrementalFrameDecoder, bytes: []const u8) void {
        const capture_offset = self.skippable_written + self.skippable_stream_captured;
        const copy_len = @min(bytes.len, self.skippable_output.len -| capture_offset);
        if (copy_len != 0) @memcpy(self.skippable_output[capture_offset..][0..copy_len], bytes[0..copy_len]);
        self.skippable_stream_captured += copy_len;
    }

    fn finishSkippableStream(self: *NativeIncrementalFrameDecoder) Error!void {
        self.skippable_written = std.math.add(usize, self.skippable_written, self.skippable_stream_captured) catch return error.IntegerOverflow;
        self.skippable_total = std.math.add(usize, self.skippable_total, self.skippable_stream_payload_len) catch return error.IntegerOverflow;
        if (self.skippable_event_count < self.skippable_events.len) {
            self.skippable_events[self.skippable_event_count] = .{
                .id = self.skippable_stream_id,
                .payload_len = self.skippable_stream_payload_len,
            };
        }
        self.skippable_event_count = std.math.add(usize, self.skippable_event_count, 1) catch return error.IntegerOverflow;
        self.resetSkippableStream();
    }

    fn switchDirectOutputToBlockStream(self: *NativeIncrementalFrameDecoder) Error!void {
        const header = try parseFrameHeader(self.frame_scratch.items[0..self.direct_frame_len]);
        self.resetBlockStream();
        self.block_stream_input_offset = self.direct_payload_offset;
        self.block_stream_stage = .compressed_decode;
        self.block_stream_block_len = self.direct_payload_len;
        self.block_stream_block_compressed = true;
        self.block_stream_block_index = self.direct_block_index;
        self.block_stream_block_size_max = header.block_size_max;
        self.block_stream_block_independent = self.direct_block_independent;
        self.block_stream_block_checksum = self.direct_block_checksum;
        self.block_stream_frame_expected_len = self.direct_decoded_len;
        self.block_stream_frame_decoded_len = self.direct_decoded_read;
        self.block_stream_content_checksum = self.direct_content_checksum;
        self.block_stream_content_hasher = self.direct_content_hasher;
        self.phase = .block_stream;
    }

    fn rememberDirectOutput(self: *NativeIncrementalFrameDecoder, bytes: []const u8) Error!void {
        if (bytes.len == 0) return;
        if (bytes.len >= max_block_history_len) {
            self.direct_history.clearRetainingCapacity();
            try self.direct_history.ensureTotalCapacityPrecise(self.allocator, max_block_history_len);
            self.direct_history.appendSliceAssumeCapacity(bytes[bytes.len - max_block_history_len ..]);
            return;
        }

        const combined_len = self.direct_history.items.len + bytes.len;
        if (combined_len > max_block_history_len) {
            const drop = combined_len - max_block_history_len;
            const keep_len = self.direct_history.items.len - drop;
            std.mem.copyForwards(u8, self.direct_history.items[0..keep_len], self.direct_history.items[drop..]);
            self.direct_history.shrinkRetainingCapacity(keep_len);
        }
        try self.direct_history.ensureTotalCapacityPrecise(self.allocator, self.direct_history.items.len + bytes.len);
        self.direct_history.appendSliceAssumeCapacity(bytes);
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
        if (self.direct_content_hasher.final() != self.direct_expected_content_checksum) {
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
        const needed = std.math.add(usize, self.frame_scratch.items.len, n) catch return error.IntegerOverflow;
        try self.ensureCompressedScratchCapacity(needed);
        self.frame_scratch.appendSliceAssumeCapacity(input[input_read.*..][0..n]);
        input_read.* += n;
        self.input_received += n;
    }

    fn appendFrameInput(self: *NativeIncrementalFrameDecoder, input: []const u8, input_read: *usize) Error!void {
        if (self.frame_scratch.items.len < 4) {
            try self.appendFramePrefix(input, input_read, 4);
        }
        if (self.frame_scratch.items.len < 4 or input_read.* == input.len) return;
        const magic = std.mem.readInt(u32, self.frame_scratch.items[0..4], .little);
        if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            try self.appendFramePrefix(input, input_read, 8);
            return;
        }
        if (self.options.input_policy == .block_stream) {
            try self.appendFramePrefix(input, input_read, 6);
            if (self.frame_scratch.items.len < 6) return;
            const flg = self.frame_scratch.items[4];
            const header_len: usize = 7 + @as(usize, if ((flg & 0x08) != 0) 8 else 0) + @as(usize, if ((flg & 0x01) != 0) 4 else 0);
            try self.appendFramePrefix(input, input_read, header_len);
            return;
        }
        try self.appendInputWithinCompressedLimit(input, input_read);
    }

    fn appendFramePrefix(self: *NativeIncrementalFrameDecoder, input: []const u8, input_read: *usize, target_len: usize) Error!void {
        if (self.frame_scratch.items.len >= target_len) return;
        if (self.frame_scratch.items.len >= self.options.max_compressed_buffer_len) return;
        const remaining_capacity = self.options.max_compressed_buffer_len - self.frame_scratch.items.len;
        const n = @min(@min(target_len - self.frame_scratch.items.len, remaining_capacity), input.len - input_read.*);
        const needed = std.math.add(usize, self.frame_scratch.items.len, n) catch return error.IntegerOverflow;
        try self.ensureCompressedScratchCapacity(needed);
        self.frame_scratch.appendSliceAssumeCapacity(input[input_read.*..][0..n]);
        input_read.* += n;
        self.input_received += n;
    }

    fn ensureCompressedScratchCapacity(self: *NativeIncrementalFrameDecoder, needed: usize) std.mem.Allocator.Error!void {
        if (needed <= self.frame_scratch.capacity) return;
        const capacity_limit = if (self.options.input_policy == .block_stream and self.phase == .block_stream)
            @min(self.options.max_compressed_buffer_len, self.block_stream_block_size_max)
        else
            self.options.max_compressed_buffer_len;
        const doubled = std.math.mul(usize, @max(self.frame_scratch.capacity, 8), 2) catch capacity_limit;
        const target = @min(capacity_limit, @max(needed, doubled));
        try self.frame_scratch.ensureTotalCapacityPrecise(self.allocator, target);
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
                self.captureSkippable(magic, self.frame_scratch.items[8..total]);
                self.discardFrameScratchPrefix(total);
                continue;
            }
            break;
        }
        var end: usize = 0;
        _ = findFrameEnd(self.frame_scratch.items, &end) catch |err| switch (err) {
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
            _ = try decodeFrameAppendLimitedWithDictionarySet(self.allocator, &self.decoded_scratch, frame, self.options.max_decoded_buffer_len, dictionary_set);
        } else if (self.dictionary) |dictionary| {
            _ = try decodeFrameAppendLimitedWithDictionary(self.allocator, &self.decoded_scratch, frame, self.options.max_decoded_buffer_len, dictionary);
        } else {
            _ = try decodeFrameAppendLimited(self.allocator, &self.decoded_scratch, frame, self.options.max_decoded_buffer_len);
        }
    }

    fn captureSkippable(self: *NativeIncrementalFrameDecoder, magic: u32, payload: []const u8) void {
        const copy_len = @min(payload.len, self.skippable_output.len -| self.skippable_written);
        if (copy_len != 0)
            @memcpy(self.skippable_output[self.skippable_written..][0..copy_len], payload[0..copy_len]);
        self.skippable_written += copy_len;
        self.skippable_total += payload.len;
        if (self.skippable_event_count < self.skippable_events.len)
            self.skippable_events[self.skippable_event_count] = .{ .id = @intCast(magic - skippable_magic_min), .payload_len = payload.len };
        self.skippable_event_count += 1;
    }

    fn beginDirectOutputIfSupported(self: *NativeIncrementalFrameDecoder, frame_end: usize) Error!bool {
        const frame = self.frame_scratch.items[0..frame_end];
        const header = try parseFrameHeader(frame);
        const dictionary_history = self.resolveDirectDictionaryHistory(header) catch |err| switch (err) {
            // Keep dictionary policy and diagnostics identical to the scratch
            // decoder. Direct output is only an optimization; if the caller has
            // not provided the required preset dictionary, let the normal frame
            // path record `NeedDictionary` in the frame phase.
            error.NeedDictionary => return false,
            else => return err,
        };
        const frame_expected_len: ?usize = if (header.expected_content_size) |size| blk: {
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
        var first_block_compressed = false;
        var first_block_decoded_len: usize = 0;
        var first_next_header: usize = 0;
        var total: usize = 0;
        var block_count: usize = 0;
        var any_block_compressed = false;
        var decoded_lens: std.ArrayList(usize) = .empty;
        defer decoded_lens.deinit(self.allocator);
        var content_hasher = std.hash.XxHash32.init(0);
        while (true) {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const block_header = std.mem.readInt(u32, frame[offset..][0..4], .little);
            offset += 4;
            if (block_header == 0) break;
            const uncompressed_block = (block_header & 0x8000_0000) != 0;
            const block_len: usize = @intCast(block_header & 0x7fff_ffff);
            if (block_len > header.block_size_max) return error.CorruptFrame;
            if (frame.len - offset < block_len) return error.TruncatedFrame;
            const payload = frame[offset..][0..block_len];
            if (!uncompressed_block) any_block_compressed = true;
            const block_uses_dictionary = !uncompressed_block and dictionary_history.len != 0 and (header.block_independent or block_count == 0);
            const decoded_block_len = if (uncompressed_block)
                block_len
            else if (block_uses_dictionary)
                decodedBlockSizeWithPrefixLimited(payload, dictionary_history, direct_limit - total) catch |err| switch (err) {
                    error.OutputLimitExceeded => {
                        if (direct_limit_from_expected) {
                            self.recordError(.frame, error.SizeMismatch);
                            return error.SizeMismatch;
                        }
                        return err;
                    },
                    else => return err,
                }
            else if (header.block_independent)
                compressedBlockDecodedSizeLimited(payload, 0, direct_limit - total) catch |err| switch (err) {
                    error.OutputLimitExceeded => {
                        if (direct_limit_from_expected) {
                            self.recordError(.frame, error.SizeMismatch);
                            return error.SizeMismatch;
                        }
                        return err;
                    },
                    else => return err,
                }
            else decoded: {
                const history_start = if (total <= max_block_history_len) 0 else total - max_block_history_len;
                const decoded_total = compressedBlockDecodedSizeLimitedWithHistory(payload, total, history_start, direct_limit) catch |err| switch (err) {
                    error.OutputLimitExceeded => {
                        if (direct_limit_from_expected) {
                            self.recordError(.frame, error.SizeMismatch);
                            return error.SizeMismatch;
                        }
                        return err;
                    },
                    else => return err,
                };
                break :decoded decoded_total - total;
            };
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
            try decoded_lens.append(self.allocator, decoded_block_len);
            if (block_count == 0) {
                first_payload_offset = offset;
                first_payload_len = block_len;
                first_block_compressed = !uncompressed_block;
                first_block_decoded_len = decoded_block_len;
            }
            offset += block_len;
            if (header.content_checksum and uncompressed_block) content_hasher.update(payload);
            if (header.block_checksum) {
                if (frame.len - offset < 4) return error.TruncatedFrame;
                const expected = std.mem.readInt(u32, frame[offset..][0..4], .little);
                if (std.hash.XxHash32.hash(0, payload) != expected) {
                    self.recordError(.frame, error.ChecksumMismatch);
                    return error.ChecksumMismatch;
                }
                offset += 4;
            }
            if (block_count == 0) first_next_header = offset;
            block_count += 1;
        }
        if (block_count == 0) return false;
        var expected_content_checksum: u32 = 0;
        if (header.content_checksum) {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            expected_content_checksum = std.mem.readInt(u32, frame[offset..][0..4], .little);
            if (!any_block_compressed and content_hasher.final() != expected_content_checksum) {
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
        self.direct_block_compressed = first_block_compressed;
        self.direct_block_independent = header.block_independent;
        self.direct_block_uses_dictionary_prefix = first_block_compressed and dictionary_history.len != 0;
        self.direct_block_decoded_len = first_block_decoded_len;
        self.direct_block_decoded_lens.clearRetainingCapacity();
        try self.direct_block_decoded_lens.appendSlice(self.allocator, decoded_lens.items);
        self.direct_block_index = 0;
        self.direct_frame_output_start = self.output_written;
        self.direct_dictionary_history = dictionary_history;
        self.direct_next_block_header_offset = first_next_header;
        self.direct_decoded_len = total;
        self.direct_decoded_read = 0;
        self.direct_block_checksum = header.block_checksum;
        self.direct_content_checksum = header.content_checksum;
        self.direct_content_hasher = std.hash.XxHash32.init(0);
        self.direct_expected_content_checksum = expected_content_checksum;
        self.direct_frame_len = frame_end;
        return true;
    }

    fn resolveDirectDictionaryHistory(self: *const NativeIncrementalFrameDecoder, header: NativeFrameHeader) Error![]const u8 {
        const id = header.dictionary_id orelse return &.{};
        if (id == 0) return &.{};
        if (self.dictionary_set) |dictionary_set| {
            const dictionary = dictionary_set.find(id) orelse return error.NeedDictionary;
            return dictionary.content;
        }
        const dictionary = self.dictionary orelse return error.NeedDictionary;
        return try validateNativeDictionary(header, dictionary);
    }

    fn advanceDirectOutputBlock(self: *NativeIncrementalFrameDecoder) Error!void {
        var offset = self.direct_next_block_header_offset;
        if (self.frame_scratch.items.len - offset < 4) return error.TruncatedFrame;
        const block_header = std.mem.readInt(u32, self.frame_scratch.items[offset..][0..4], .little);
        offset += 4;
        if (block_header == 0) return error.CorruptFrame;
        const uncompressed_block = (block_header & 0x8000_0000) != 0;
        const block_len: usize = @intCast(block_header & 0x7fff_ffff);
        if (self.frame_scratch.items.len - offset < block_len) return error.TruncatedFrame;
        self.direct_payload_offset = offset;
        self.direct_payload_len = block_len;
        self.direct_payload_read = 0;
        self.direct_block_compressed = !uncompressed_block;
        self.direct_block_index += 1;
        if (self.direct_block_index >= self.direct_block_decoded_lens.items.len) return error.CorruptFrame;
        self.direct_block_decoded_len = self.direct_block_decoded_lens.items[self.direct_block_index];
        self.direct_block_uses_dictionary_prefix =
            self.direct_block_compressed and
            self.direct_dictionary_history.len != 0 and
            (self.direct_block_independent or self.direct_block_index == 0);
        offset += block_len;
        if (self.direct_block_checksum) {
            if (self.frame_scratch.items.len - offset < 4) return error.TruncatedFrame;
            offset += 4;
        }
        self.direct_next_block_header_offset = offset;
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

    fn recordError(self: *NativeIncrementalFrameDecoder, phase: InternalPhase, err: Error) void {
        self.last_error_name = @errorName(err);
        self.last_error_phase = publicPhase(phase);
    }

    fn phaseName(phase: Phase) []const u8 {
        return switch (phase) {
            .frame => "frame",
            .output => "output",
            .direct_output => "direct_output",
            .done => "done",
        };
    }

    fn publicPhase(phase: InternalPhase) Phase {
        return switch (phase) {
            .frame, .skippable_stream => .frame,
            .output => .output,
            .direct_output, .block_stream => .direct_output,
            .done => .done,
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
        return try decodeFrameAlloc(self.allocator, frame);
    }

    pub fn decodeAllocExactSize(self: *NativeFrameDecoder, frame: []const u8, expected_output_len: usize) Error![]u8 {
        return try decodeFrameAllocExactSize(self.allocator, frame, expected_output_len);
    }

    pub fn decodeAllocWithDictionary(self: *NativeFrameDecoder, frame: []const u8, dictionary: NativeDictionary) Error![]u8 {
        return try decodeFrameAllocWithDictionary(self.allocator, frame, dictionary);
    }

    pub fn decodeAllocWithDictionaryExactSize(self: *NativeFrameDecoder, frame: []const u8, dictionary: NativeDictionary, expected_output_len: usize) Error![]u8 {
        return try decodeFrameAllocWithDictionaryExactSize(self.allocator, frame, dictionary, expected_output_len);
    }

    pub fn decodeAllocWithDictionarySet(self: *NativeFrameDecoder, frame: []const u8, dictionary_set: NativeDictionarySet) Error![]u8 {
        return try decodeFrameAllocWithDictionarySet(self.allocator, frame, dictionary_set);
    }

    pub fn decodeAllocWithDictionarySetExactSize(self: *NativeFrameDecoder, frame: []const u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error![]u8 {
        return try decodeFrameAllocWithDictionarySetExactSize(self.allocator, frame, dictionary_set, expected_output_len);
    }

    pub fn decodeAllocLimited(self: *NativeFrameDecoder, frame: []const u8, max_output_len: usize) Error![]u8 {
        return try decodeFrameAllocLimited(self.allocator, frame, max_output_len);
    }

    pub fn decodeAllocLimitedWithDictionary(self: *NativeFrameDecoder, frame: []const u8, max_output_len: usize, dictionary: NativeDictionary) Error![]u8 {
        return try decodeFrameAllocLimitedWithDictionary(self.allocator, frame, max_output_len, dictionary);
    }

    pub fn decodeAllocLimitedWithDictionarySet(self: *NativeFrameDecoder, frame: []const u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error![]u8 {
        return try decodeFrameAllocLimitedWithDictionarySet(self.allocator, frame, max_output_len, dictionary_set);
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
        return try decodeFrameAppend(self.allocator, out, frame);
    }

    pub fn decodeAppendExactSize(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frame: []const u8, expected_output_len: usize) Error!usize {
        return try decodeFrameAppendExactSize(self.allocator, out, frame, expected_output_len);
    }

    pub fn decodeIntoSliceExactSize(self: *NativeFrameDecoder, frame: []const u8, output: []u8, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeFrameIntoExactSize(frame, output, expected_output_len);
    }

    pub fn decodeAppendWithDictionary(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frame: []const u8, dictionary: NativeDictionary) Error!usize {
        return try decodeFrameAppendWithDictionary(self.allocator, out, frame, dictionary);
    }

    pub fn decodeAppendExactSizeWithDictionary(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frame: []const u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
        return try decodeFrameAppendExactSizeWithDictionary(self.allocator, out, frame, dictionary, expected_output_len);
    }

    pub fn decodeIntoSliceWithDictionaryExactSize(self: *NativeFrameDecoder, frame: []const u8, output: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeFrameIntoWithDictionaryExactSize(frame, output, dictionary, expected_output_len);
    }

    pub fn decodeAppendWithDictionarySet(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frame: []const u8, dictionary_set: NativeDictionarySet) Error!usize {
        return try decodeFrameAppendWithDictionarySet(self.allocator, out, frame, dictionary_set);
    }

    pub fn decodeAppendExactSizeWithDictionarySet(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frame: []const u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
        return try decodeFrameAppendExactSizeWithDictionarySet(self.allocator, out, frame, dictionary_set, expected_output_len);
    }

    pub fn decodeIntoSliceWithDictionarySetExactSize(self: *NativeFrameDecoder, frame: []const u8, output: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeFrameIntoWithDictionarySetExactSize(frame, output, dictionary_set, expected_output_len);
    }

    pub fn decodeAppendLimited(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frame: []const u8, max_output_len: usize) Error!usize {
        return try decodeFrameAppendLimited(self.allocator, out, frame, max_output_len);
    }

    pub fn decodeAppendLimitedWithDictionary(
        self: *NativeFrameDecoder,
        out: *std.ArrayList(u8),
        frame: []const u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error!usize {
        return try decodeFrameAppendLimitedWithDictionary(self.allocator, out, frame, max_output_len, dictionary);
    }

    pub fn decodeAppendLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        out: *std.ArrayList(u8),
        frame: []const u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error!usize {
        return try decodeFrameAppendLimitedWithDictionarySet(self.allocator, out, frame, max_output_len, dictionary_set);
    }

    pub fn decodeIntoSlice(self: *NativeFrameDecoder, frame: []const u8, output: []u8) Error!usize {
        _ = self;
        return try decodeFrameInto(frame, output);
    }

    pub fn decodeIntoSliceWithDictionary(self: *NativeFrameDecoder, frame: []const u8, output: []u8, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodeFrameIntoWithDictionary(frame, output, dictionary);
    }

    pub fn decodeIntoSliceWithDictionarySet(self: *NativeFrameDecoder, frame: []const u8, output: []u8, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodeFrameIntoWithDictionarySet(frame, output, dictionary_set);
    }

    pub fn decodedSize(self: *NativeFrameDecoder, frame: []const u8) Error!usize {
        _ = self;
        return try decodedFrameSize(frame);
    }

    pub fn decodedSizeLimited(self: *NativeFrameDecoder, frame: []const u8, max_output_len: usize) Error!usize {
        _ = self;
        return try decodedFrameSizeLimited(frame, max_output_len);
    }

    pub fn decodedSizeWithDictionary(self: *NativeFrameDecoder, frame: []const u8, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodedFrameSizeWithDictionary(frame, dictionary);
    }

    pub fn decodedSizeLimitedWithDictionary(self: *NativeFrameDecoder, frame: []const u8, max_output_len: usize, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodedFrameSizeLimitedWithDictionary(frame, max_output_len, dictionary);
    }

    pub fn decodedSizeWithDictionarySet(self: *NativeFrameDecoder, frame: []const u8, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodedFrameSizeWithDictionarySet(frame, dictionary_set);
    }

    pub fn decodedSizeLimitedWithDictionarySet(self: *NativeFrameDecoder, frame: []const u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodedFrameSizeLimitedWithDictionarySet(frame, max_output_len, dictionary_set);
    }

    pub fn decodeChunksAlloc(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8) Error![]u8 {
        return try decodeFrameChunksAlloc(self.allocator, chunks, compressed_scratch);
    }

    pub fn decodeChunksAllocExactSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error![]u8 {
        return try decodeFrameChunksAllocExactSize(self.allocator, chunks, compressed_scratch, expected_output_len);
    }

    pub fn decodeChunksAllocLimited(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error![]u8 {
        return try decodeFrameChunksAllocLimited(self.allocator, chunks, compressed_scratch, max_output_len);
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
        return try decodeFrameChunksAppend(self.allocator, out, chunks, compressed_scratch);
    }

    pub fn decodeChunksAppendExactSize(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error!usize {
        return try decodeFrameChunksAppendExactSize(self.allocator, out, chunks, compressed_scratch, expected_output_len);
    }

    pub fn decodeChunksAppendLimited(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
        return try decodeFrameChunksAppendLimited(self.allocator, out, chunks, compressed_scratch, max_output_len);
    }

    pub fn decodeChunksIntoSlice(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8) Error!usize {
        _ = self;
        return try decodeFrameChunksInto(chunks, compressed_scratch, output);
    }

    pub fn decodeChunksIntoSliceExactSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeFrameChunksIntoExactSize(chunks, compressed_scratch, output, expected_output_len);
    }

    pub fn decodedChunksSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
        _ = self;
        return try decodedFrameChunksSize(chunks, compressed_scratch);
    }

    pub fn decodedChunksSizeLimited(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
        _ = self;
        return try decodedFrameChunksSizeLimited(chunks, compressed_scratch, max_output_len);
    }

    pub fn decodeChunksAllocWithDictionary(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error![]u8 {
        return try decodeFrameChunksAllocWithDictionary(self.allocator, chunks, compressed_scratch, dictionary);
    }

    pub fn decodeChunksAllocExactSizeWithDictionary(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        dictionary: NativeDictionary,
        expected_output_len: usize,
    ) Error![]u8 {
        return try decodeFrameChunksAllocWithDictionaryExactSize(self.allocator, chunks, compressed_scratch, dictionary, expected_output_len);
    }

    pub fn decodeChunksAllocLimitedWithDictionary(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error![]u8 {
        return try decodeFrameChunksAllocWithDictionaryLimited(self.allocator, chunks, compressed_scratch, dictionary, max_output_len);
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
        return try decodeFrameChunksAppendWithDictionary(self.allocator, out, chunks, compressed_scratch, dictionary);
    }

    pub fn decodeChunksAppendExactSizeWithDictionary(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
        return try decodeFrameChunksAppendExactSizeWithDictionary(self.allocator, out, chunks, compressed_scratch, dictionary, expected_output_len);
    }

    pub fn decodeChunksAppendLimitedWithDictionary(
        self: *NativeFrameDecoder,
        out: *std.ArrayList(u8),
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error!usize {
        return try decodeFrameChunksAppendLimitedWithDictionary(self.allocator, out, chunks, compressed_scratch, max_output_len, dictionary);
    }

    pub fn decodeChunksIntoSliceWithDictionary(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodeFrameChunksIntoWithDictionary(chunks, compressed_scratch, output, dictionary);
    }

    pub fn decodeChunksIntoSliceWithDictionaryExactSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeFrameChunksIntoExactSizeWithDictionary(chunks, compressed_scratch, output, dictionary, expected_output_len);
    }

    pub fn decodedChunksSizeWithDictionary(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodedFrameChunksSizeWithDictionary(chunks, compressed_scratch, dictionary);
    }

    pub fn decodedChunksSizeLimitedWithDictionary(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error!usize {
        _ = self;
        return try decodedFrameChunksSizeLimitedWithDictionary(chunks, compressed_scratch, max_output_len, dictionary);
    }

    pub fn decodeChunksAllocWithDictionarySet(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error![]u8 {
        return try decodeFrameChunksAllocWithDictionarySet(self.allocator, chunks, compressed_scratch, dictionary_set);
    }

    pub fn decodeChunksAllocExactSizeWithDictionarySet(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        dictionary_set: NativeDictionarySet,
        expected_output_len: usize,
    ) Error![]u8 {
        return try decodeFrameChunksAllocWithDictionarySetExactSize(self.allocator, chunks, compressed_scratch, dictionary_set, expected_output_len);
    }

    pub fn decodeChunksAllocLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error![]u8 {
        return try decodeFrameChunksAllocWithDictionarySetLimited(self.allocator, chunks, compressed_scratch, dictionary_set, max_output_len);
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
        return try decodeFrameChunksAppendWithDictionarySet(self.allocator, out, chunks, compressed_scratch, dictionary_set);
    }

    pub fn decodeChunksAppendExactSizeWithDictionarySet(self: *NativeFrameDecoder, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
        return try decodeFrameChunksAppendExactSizeWithDictionarySet(self.allocator, out, chunks, compressed_scratch, dictionary_set, expected_output_len);
    }

    pub fn decodeChunksAppendLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        out: *std.ArrayList(u8),
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error!usize {
        return try decodeFrameChunksAppendLimitedWithDictionarySet(self.allocator, out, chunks, compressed_scratch, max_output_len, dictionary_set);
    }

    pub fn decodeChunksIntoSliceWithDictionarySet(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodeFrameChunksIntoWithDictionarySet(chunks, compressed_scratch, output, dictionary_set);
    }

    pub fn decodeChunksIntoSliceWithDictionarySetExactSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeFrameChunksIntoExactSizeWithDictionarySet(chunks, compressed_scratch, output, dictionary_set, expected_output_len);
    }

    pub fn decodedChunksSizeWithDictionarySet(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodedFrameChunksSizeWithDictionarySet(chunks, compressed_scratch, dictionary_set);
    }

    pub fn decodedChunksSizeLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error!usize {
        _ = self;
        return try decodedFrameChunksSizeLimitedWithDictionarySet(chunks, compressed_scratch, max_output_len, dictionary_set);
    }

    pub fn decodeConcatenatedAlloc(self: *NativeFrameDecoder, frames: []const u8) Error![]u8 {
        return try decodeConcatenatedFrameAlloc(self.allocator, frames);
    }

    pub fn decodeConcatenatedAllocExactSize(self: *NativeFrameDecoder, frames: []const u8, expected_output_len: usize) Error![]u8 {
        return try decodeConcatenatedFrameAllocExactSize(self.allocator, frames, expected_output_len);
    }

    pub fn decodeConcatenatedAllocWithDictionary(self: *NativeFrameDecoder, frames: []const u8, dictionary: NativeDictionary) Error![]u8 {
        return try decodeConcatenatedFrameAllocWithDictionary(self.allocator, frames, dictionary);
    }

    pub fn decodeConcatenatedAllocWithDictionaryExactSize(self: *NativeFrameDecoder, frames: []const u8, dictionary: NativeDictionary, expected_output_len: usize) Error![]u8 {
        return try decodeConcatenatedFrameAllocWithDictionaryExactSize(self.allocator, frames, dictionary, expected_output_len);
    }

    pub fn decodeConcatenatedAllocWithDictionarySet(self: *NativeFrameDecoder, frames: []const u8, dictionary_set: NativeDictionarySet) Error![]u8 {
        return try decodeConcatenatedFrameAllocWithDictionarySet(self.allocator, frames, dictionary_set);
    }

    pub fn decodeConcatenatedAllocWithDictionarySetExactSize(self: *NativeFrameDecoder, frames: []const u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error![]u8 {
        return try decodeConcatenatedFrameAllocWithDictionarySetExactSize(self.allocator, frames, dictionary_set, expected_output_len);
    }

    pub fn decodeConcatenatedAllocLimited(self: *NativeFrameDecoder, frames: []const u8, max_output_len: usize) Error![]u8 {
        return try decodeConcatenatedFrameAllocLimited(self.allocator, frames, max_output_len);
    }

    pub fn decodeConcatenatedAllocLimitedWithDictionary(self: *NativeFrameDecoder, frames: []const u8, max_output_len: usize, dictionary: NativeDictionary) Error![]u8 {
        return try decodeConcatenatedFrameAllocLimitedWithDictionary(self.allocator, frames, max_output_len, dictionary);
    }

    pub fn decodeConcatenatedAllocLimitedWithDictionarySet(self: *NativeFrameDecoder, frames: []const u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error![]u8 {
        return try decodeConcatenatedFrameAllocLimitedWithDictionarySet(self.allocator, frames, max_output_len, dictionary_set);
    }

    pub fn decodeConcatenatedScratch(self: *NativeFrameDecoder, frames: []const u8) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeConcatenatedAppend(&self.scratch, frames);
        return self.scratch.items;
    }

    pub fn decodeConcatenatedScratchWithDictionary(self: *NativeFrameDecoder, frames: []const u8, dictionary: NativeDictionary) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeConcatenatedAppendWithDictionary(&self.scratch, frames, dictionary);
        return self.scratch.items;
    }

    pub fn decodeConcatenatedScratchWithDictionarySet(self: *NativeFrameDecoder, frames: []const u8, dictionary_set: NativeDictionarySet) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeConcatenatedAppendWithDictionarySet(&self.scratch, frames, dictionary_set);
        return self.scratch.items;
    }

    pub fn decodeConcatenatedScratchLimited(self: *NativeFrameDecoder, frames: []const u8, max_output_len: usize) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeConcatenatedAppendLimited(&self.scratch, frames, max_output_len);
        return self.scratch.items;
    }

    pub fn decodeConcatenatedScratchLimitedWithDictionary(self: *NativeFrameDecoder, frames: []const u8, max_output_len: usize, dictionary: NativeDictionary) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeConcatenatedAppendLimitedWithDictionary(&self.scratch, frames, max_output_len, dictionary);
        return self.scratch.items;
    }

    pub fn decodeConcatenatedScratchLimitedWithDictionarySet(self: *NativeFrameDecoder, frames: []const u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeConcatenatedAppendLimitedWithDictionarySet(&self.scratch, frames, max_output_len, dictionary_set);
        return self.scratch.items;
    }

    pub fn decodeConcatenatedAppend(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frames: []const u8) Error!usize {
        return try decodeConcatenatedFrameAppend(self.allocator, out, frames);
    }

    pub fn decodeConcatenatedAppendExactSize(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frames: []const u8, expected_output_len: usize) Error!usize {
        return try decodeConcatenatedFrameAppendExactSize(self.allocator, out, frames, expected_output_len);
    }

    pub fn decodeConcatenatedIntoSliceExactSize(self: *NativeFrameDecoder, frames: []const u8, output: []u8, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeConcatenatedFrameIntoExactSize(frames, output, expected_output_len);
    }

    pub fn decodeConcatenatedAppendWithDictionary(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frames: []const u8, dictionary: NativeDictionary) Error!usize {
        return try decodeConcatenatedFrameAppendWithDictionary(self.allocator, out, frames, dictionary);
    }

    pub fn decodeConcatenatedAppendExactSizeWithDictionary(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frames: []const u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
        return try decodeConcatenatedFrameAppendExactSizeWithDictionary(self.allocator, out, frames, dictionary, expected_output_len);
    }

    pub fn decodeConcatenatedIntoSliceWithDictionaryExactSize(self: *NativeFrameDecoder, frames: []const u8, output: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeConcatenatedFrameIntoWithDictionaryExactSize(frames, output, dictionary, expected_output_len);
    }

    pub fn decodeConcatenatedAppendWithDictionarySet(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frames: []const u8, dictionary_set: NativeDictionarySet) Error!usize {
        return try decodeConcatenatedFrameAppendWithDictionarySet(self.allocator, out, frames, dictionary_set);
    }

    pub fn decodeConcatenatedAppendExactSizeWithDictionarySet(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frames: []const u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
        return try decodeConcatenatedFrameAppendExactSizeWithDictionarySet(self.allocator, out, frames, dictionary_set, expected_output_len);
    }

    pub fn decodeConcatenatedIntoSliceWithDictionarySetExactSize(self: *NativeFrameDecoder, frames: []const u8, output: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeConcatenatedFrameIntoWithDictionarySetExactSize(frames, output, dictionary_set, expected_output_len);
    }

    pub fn decodeConcatenatedAppendLimited(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frames: []const u8, max_output_len: usize) Error!usize {
        return try decodeConcatenatedFrameAppendLimited(self.allocator, out, frames, max_output_len);
    }

    pub fn decodeConcatenatedAppendLimitedWithDictionary(
        self: *NativeFrameDecoder,
        out: *std.ArrayList(u8),
        frames: []const u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error!usize {
        return try decodeConcatenatedFrameAppendLimitedWithDictionary(self.allocator, out, frames, max_output_len, dictionary);
    }

    pub fn decodeConcatenatedAppendLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        out: *std.ArrayList(u8),
        frames: []const u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error!usize {
        return try decodeConcatenatedFrameAppendLimitedWithDictionarySet(self.allocator, out, frames, max_output_len, dictionary_set);
    }

    pub fn decodeConcatenatedIntoSlice(self: *NativeFrameDecoder, frames: []const u8, output: []u8) Error!usize {
        _ = self;
        return try decodeConcatenatedFrameInto(frames, output);
    }

    pub fn decodeConcatenatedIntoSliceWithDictionary(self: *NativeFrameDecoder, frames: []const u8, output: []u8, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodeConcatenatedFrameIntoWithDictionary(frames, output, dictionary);
    }

    pub fn decodeConcatenatedIntoSliceWithDictionarySet(self: *NativeFrameDecoder, frames: []const u8, output: []u8, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodeConcatenatedFrameIntoWithDictionarySet(frames, output, dictionary_set);
    }

    pub fn decodedConcatenatedSize(self: *NativeFrameDecoder, frames: []const u8) Error!usize {
        _ = self;
        return try decodedConcatenatedFrameSize(frames);
    }

    pub fn decodedConcatenatedSizeLimited(self: *NativeFrameDecoder, frames: []const u8, max_output_len: usize) Error!usize {
        _ = self;
        return try decodedConcatenatedFrameSizeLimited(frames, max_output_len);
    }

    pub fn decodedConcatenatedSizeWithDictionary(self: *NativeFrameDecoder, frames: []const u8, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodedConcatenatedFrameSizeWithDictionary(frames, dictionary);
    }

    pub fn decodedConcatenatedSizeLimitedWithDictionary(self: *NativeFrameDecoder, frames: []const u8, max_output_len: usize, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodedConcatenatedFrameSizeLimitedWithDictionary(frames, max_output_len, dictionary);
    }

    pub fn decodedConcatenatedSizeWithDictionarySet(self: *NativeFrameDecoder, frames: []const u8, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodedConcatenatedFrameSizeWithDictionarySet(frames, dictionary_set);
    }

    pub fn decodedConcatenatedSizeLimitedWithDictionarySet(self: *NativeFrameDecoder, frames: []const u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodedConcatenatedFrameSizeLimitedWithDictionarySet(frames, max_output_len, dictionary_set);
    }

    pub fn decodeConcatenatedChunksAlloc(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8) Error![]u8 {
        return try decodeConcatenatedFrameChunksAlloc(self.allocator, chunks, compressed_scratch);
    }

    pub fn decodeConcatenatedChunksAllocExactSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error![]u8 {
        return try decodeConcatenatedFrameChunksAllocExactSize(self.allocator, chunks, compressed_scratch, expected_output_len);
    }

    pub fn decodeConcatenatedChunksAllocLimited(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error![]u8 {
        return try decodeConcatenatedFrameChunksAllocLimited(self.allocator, chunks, compressed_scratch, max_output_len);
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
        return try decodeConcatenatedFrameChunksInto(chunks, compressed_scratch, output);
    }

    pub fn decodeConcatenatedChunksIntoSliceExactSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeConcatenatedFrameChunksIntoExactSize(chunks, compressed_scratch, output, expected_output_len);
    }

    pub fn decodeConcatenatedChunksAllocWithDictionary(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error![]u8 {
        return try decodeConcatenatedFrameChunksAllocWithDictionary(self.allocator, chunks, compressed_scratch, dictionary);
    }

    pub fn decodeConcatenatedChunksAllocExactSizeWithDictionary(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        dictionary: NativeDictionary,
        expected_output_len: usize,
    ) Error![]u8 {
        return try decodeConcatenatedFrameChunksAllocWithDictionaryExactSize(self.allocator, chunks, compressed_scratch, dictionary, expected_output_len);
    }

    pub fn decodeConcatenatedChunksAllocLimitedWithDictionary(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error![]u8 {
        return try decodeConcatenatedFrameChunksAllocWithDictionaryLimited(self.allocator, chunks, compressed_scratch, dictionary, max_output_len);
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
        return try decodeConcatenatedFrameChunksIntoWithDictionary(chunks, compressed_scratch, output, dictionary);
    }

    pub fn decodeConcatenatedChunksIntoSliceWithDictionaryExactSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeConcatenatedFrameChunksIntoExactSizeWithDictionary(chunks, compressed_scratch, output, dictionary, expected_output_len);
    }

    pub fn decodeConcatenatedChunksAllocWithDictionarySet(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error![]u8 {
        return try decodeConcatenatedFrameChunksAllocWithDictionarySet(self.allocator, chunks, compressed_scratch, dictionary_set);
    }

    pub fn decodeConcatenatedChunksAllocExactSizeWithDictionarySet(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        dictionary_set: NativeDictionarySet,
        expected_output_len: usize,
    ) Error![]u8 {
        return try decodeConcatenatedFrameChunksAllocWithDictionarySetExactSize(self.allocator, chunks, compressed_scratch, dictionary_set, expected_output_len);
    }

    pub fn decodeConcatenatedChunksAllocLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error![]u8 {
        return try decodeConcatenatedFrameChunksAllocWithDictionarySetLimited(self.allocator, chunks, compressed_scratch, dictionary_set, max_output_len);
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
        return try decodeConcatenatedFrameChunksIntoWithDictionarySet(chunks, compressed_scratch, output, dictionary_set);
    }

    pub fn decodeConcatenatedChunksIntoSliceWithDictionarySetExactSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
        _ = self;
        return try decodeConcatenatedFrameChunksIntoExactSizeWithDictionarySet(chunks, compressed_scratch, output, dictionary_set, expected_output_len);
    }

    pub fn decodedConcatenatedChunksSize(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
        _ = self;
        return try decodedConcatenatedFrameChunksSize(chunks, compressed_scratch);
    }

    pub fn decodedConcatenatedChunksSizeLimited(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
        _ = self;
        return try decodedConcatenatedFrameChunksSizeLimited(chunks, compressed_scratch, max_output_len);
    }

    pub fn decodedConcatenatedChunksSizeWithDictionary(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error!usize {
        _ = self;
        return try decodedConcatenatedFrameChunksSizeWithDictionary(chunks, compressed_scratch, dictionary);
    }

    pub fn decodedConcatenatedChunksSizeLimitedWithDictionary(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary: NativeDictionary,
    ) Error!usize {
        _ = self;
        return try decodedConcatenatedFrameChunksSizeLimitedWithDictionary(chunks, compressed_scratch, max_output_len, dictionary);
    }

    pub fn decodedConcatenatedChunksSizeWithDictionarySet(self: *NativeFrameDecoder, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error!usize {
        _ = self;
        return try decodedConcatenatedFrameChunksSizeWithDictionarySet(chunks, compressed_scratch, dictionary_set);
    }

    pub fn decodedConcatenatedChunksSizeLimitedWithDictionarySet(
        self: *NativeFrameDecoder,
        chunks: []const []const u8,
        compressed_scratch: []u8,
        max_output_len: usize,
        dictionary_set: NativeDictionarySet,
    ) Error!usize {
        _ = self;
        return try decodedConcatenatedFrameChunksSizeLimitedWithDictionarySet(chunks, compressed_scratch, max_output_len, dictionary_set);
    }
};

pub fn decodeConcatenatedFrameAlloc(allocator: std.mem.Allocator, frames: []const u8) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var offset: usize = 0;
    while (offset < frames.len) {
        try decodeNextFrameIntoList(allocator, &out, frames, &offset);
    }
    return out.toOwnedSlice(allocator);
}

pub fn decodeConcatenatedFrameAllocExactSize(allocator: std.mem.Allocator, frames: []const u8, expected_output_len: usize) Error![]u8 {
    const decoded_len = try decodedConcatenatedFrameSize(frames);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeConcatenatedFrameInto(frames, out) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

pub fn decodeConcatenatedFrameIntoExactSize(frames: []const u8, output: []u8, expected_output_len: usize) Error!usize {
    if (output.len < expected_output_len) return error.OutputTooSmall;
    const written = decodeConcatenatedFrameInto(frames, output[0..expected_output_len]) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return written;
}

pub fn decodeConcatenatedFrameAllocWithDictionary(allocator: std.mem.Allocator, frames: []const u8, dictionary: NativeDictionary) Error![]u8 {
    const decoded_len = try decodedConcatenatedFrameSizeWithDictionary(frames, dictionary);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = try decodeConcatenatedFrameIntoWithDictionary(frames, out, dictionary);
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodeConcatenatedFrameAllocWithDictionaryExactSize(allocator: std.mem.Allocator, frames: []const u8, dictionary: NativeDictionary, expected_output_len: usize) Error![]u8 {
    const decoded_len = try decodedConcatenatedFrameSizeWithDictionary(frames, dictionary);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeConcatenatedFrameIntoWithDictionary(frames, out, dictionary) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

pub fn decodeConcatenatedFrameIntoWithDictionaryExactSize(frames: []const u8, output: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
    if (output.len < expected_output_len) return error.OutputTooSmall;
    const written = decodeConcatenatedFrameIntoWithDictionary(frames, output[0..expected_output_len], dictionary) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return written;
}

pub fn decodeConcatenatedFrameAllocWithDictionarySet(allocator: std.mem.Allocator, frames: []const u8, dictionary_set: NativeDictionarySet) Error![]u8 {
    const decoded_len = try decodedConcatenatedFrameSizeWithDictionarySet(frames, dictionary_set);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = try decodeConcatenatedFrameIntoWithDictionarySet(frames, out, dictionary_set);
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodeConcatenatedFrameAllocWithDictionarySetExactSize(allocator: std.mem.Allocator, frames: []const u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error![]u8 {
    const decoded_len = try decodedConcatenatedFrameSizeWithDictionarySet(frames, dictionary_set);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = decodeConcatenatedFrameIntoWithDictionarySet(frames, out, dictionary_set) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

pub fn decodeConcatenatedFrameIntoWithDictionarySetExactSize(frames: []const u8, output: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
    if (output.len < expected_output_len) return error.OutputTooSmall;
    const written = decodeConcatenatedFrameIntoWithDictionarySet(frames, output[0..expected_output_len], dictionary_set) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return written;
}

pub fn decodeConcatenatedFrameAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frames: []const u8) Error!usize {
    const decoded_len = try decodedConcatenatedFrameSize(frames);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeConcatenatedFrameInto(frames, slot) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeConcatenatedFrameAppendExactSize(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frames: []const u8, expected_output_len: usize) Error!usize {
    const decoded_len = try decodedConcatenatedFrameSize(frames);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    try out.ensureUnusedCapacity(allocator, expected_output_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(expected_output_len);
    const written = decodeConcatenatedFrameInto(frames, slot) catch |err| switch (err) {
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

pub fn decodeConcatenatedFrameAppendWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frames: []const u8, dictionary: NativeDictionary) Error!usize {
    const decoded_len = try decodedConcatenatedFrameSizeWithDictionary(frames, dictionary);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeConcatenatedFrameIntoWithDictionary(frames, slot, dictionary) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeConcatenatedFrameAppendExactSizeWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frames: []const u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
    const decoded_len = try decodedConcatenatedFrameSizeWithDictionary(frames, dictionary);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    try out.ensureUnusedCapacity(allocator, expected_output_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(expected_output_len);
    const written = decodeConcatenatedFrameIntoWithDictionary(frames, slot, dictionary) catch |err| switch (err) {
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

pub fn decodeConcatenatedFrameAppendWithDictionarySet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frames: []const u8, dictionary_set: NativeDictionarySet) Error!usize {
    const decoded_len = try decodedConcatenatedFrameSizeWithDictionarySet(frames, dictionary_set);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeConcatenatedFrameIntoWithDictionarySet(frames, slot, dictionary_set) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeConcatenatedFrameAppendExactSizeWithDictionarySet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frames: []const u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
    const decoded_len = try decodedConcatenatedFrameSizeWithDictionarySet(frames, dictionary_set);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    try out.ensureUnusedCapacity(allocator, expected_output_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(expected_output_len);
    const written = decodeConcatenatedFrameIntoWithDictionarySet(frames, slot, dictionary_set) catch |err| switch (err) {
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

pub fn decodeConcatenatedFrameAppendLimited(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frames: []const u8,
    max_output_len: usize,
) Error!usize {
    const decoded_len = try decodedConcatenatedFrameSizeLimited(frames, max_output_len);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeConcatenatedFrameInto(frames, slot) catch |err| switch (err) {
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

pub fn decodeConcatenatedFrameAppendLimitedWithDictionary(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frames: []const u8,
    max_output_len: usize,
    dictionary: NativeDictionary,
) Error!usize {
    const decoded_len = try decodedConcatenatedFrameSizeLimitedWithDictionary(frames, max_output_len, dictionary);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeConcatenatedFrameIntoWithDictionary(frames, slot, dictionary) catch |err| switch (err) {
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

pub fn decodeConcatenatedFrameAppendLimitedWithDictionarySet(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frames: []const u8,
    max_output_len: usize,
    dictionary_set: NativeDictionarySet,
) Error!usize {
    const decoded_len = try decodedConcatenatedFrameSizeLimitedWithDictionarySet(frames, max_output_len, dictionary_set);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeConcatenatedFrameIntoWithDictionarySet(frames, slot, dictionary_set) catch |err| switch (err) {
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

pub fn decodeConcatenatedFrameAllocLimited(
    allocator: std.mem.Allocator,
    frames: []const u8,
    max_output_len: usize,
) Error![]u8 {
    const decoded_len = try decodedConcatenatedFrameSizeLimited(frames, max_output_len);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = decodeConcatenatedFrameInto(frames, out) catch |err| switch (err) {
        error.OutputTooSmall => return error.OutputLimitExceeded,
        else => return err,
    };
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodeConcatenatedFrameAllocLimitedWithDictionary(
    allocator: std.mem.Allocator,
    frames: []const u8,
    max_output_len: usize,
    dictionary: NativeDictionary,
) Error![]u8 {
    const decoded_len = try decodedConcatenatedFrameSizeLimitedWithDictionary(frames, max_output_len, dictionary);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = decodeConcatenatedFrameIntoWithDictionary(frames, out, dictionary) catch |err| switch (err) {
        error.OutputTooSmall => return error.OutputLimitExceeded,
        else => return err,
    };
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodeConcatenatedFrameAllocLimitedWithDictionarySet(
    allocator: std.mem.Allocator,
    frames: []const u8,
    max_output_len: usize,
    dictionary_set: NativeDictionarySet,
) Error![]u8 {
    const decoded_len = try decodedConcatenatedFrameSizeLimitedWithDictionarySet(frames, max_output_len, dictionary_set);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = decodeConcatenatedFrameIntoWithDictionarySet(frames, out, dictionary_set) catch |err| switch (err) {
        error.OutputTooSmall => return error.OutputLimitExceeded,
        else => return err,
    };
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodedConcatenatedFrameSize(frames: []const u8) Error!usize {
    return try concatenatedFrameDecodedSizeLimited(frames, std.math.maxInt(usize));
}

pub fn decodedConcatenatedFrameSizeLimited(frames: []const u8, max_output_len: usize) Error!usize {
    return try concatenatedFrameDecodedSizeLimited(frames, max_output_len);
}

pub fn decodedConcatenatedFrameSizeWithDictionary(frames: []const u8, dictionary: NativeDictionary) Error!usize {
    return try concatenatedFrameDecodedSizeLimitedWithDictionary(frames, std.math.maxInt(usize), dictionary);
}

pub fn decodedConcatenatedFrameSizeLimitedWithDictionary(frames: []const u8, max_output_len: usize, dictionary: NativeDictionary) Error!usize {
    return try concatenatedFrameDecodedSizeLimitedWithDictionary(frames, max_output_len, dictionary);
}

pub fn decodedConcatenatedFrameSizeWithDictionarySet(frames: []const u8, dictionary_set: NativeDictionarySet) Error!usize {
    return try concatenatedFrameDecodedSizeLimitedWithDictionarySet(frames, std.math.maxInt(usize), dictionary_set);
}

pub fn decodedConcatenatedFrameSizeLimitedWithDictionarySet(frames: []const u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error!usize {
    return try concatenatedFrameDecodedSizeLimitedWithDictionarySet(frames, max_output_len, dictionary_set);
}

pub fn decodeConcatenatedFrameInto(frames: []const u8, output: []u8) Error!usize {
    var offset: usize = 0;
    var written: usize = 0;
    while (offset < frames.len) {
        try decodeNextFrameIntoBuffer(frames, &offset, output, &written);
    }
    return written;
}

pub fn decodeConcatenatedFrameIntoWithDictionary(frames: []const u8, output: []u8, dictionary: NativeDictionary) Error!usize {
    var offset: usize = 0;
    var written: usize = 0;
    while (offset < frames.len) {
        try decodeNextFrameIntoBufferWithDictionary(frames, &offset, output, &written, dictionary);
    }
    return written;
}

pub fn decodeConcatenatedFrameIntoWithDictionarySet(frames: []const u8, output: []u8, dictionary_set: NativeDictionarySet) Error!usize {
    var offset: usize = 0;
    var written: usize = 0;
    while (offset < frames.len) {
        try decodeNextFrameIntoBufferWithDictionarySet(frames, &offset, output, &written, dictionary_set);
    }
    return written;
}

pub fn decodeFrameChunksAlloc(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAlloc(allocator, joined);
}

pub fn decodeFrameChunksAllocExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAllocExactSize(allocator, joined, expected_output_len);
}

pub fn decodeFrameChunksAllocLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAllocLimited(allocator, joined, max_output_len);
}

pub fn decodeFrameChunksAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAppend(allocator, out, joined);
}

pub fn decodeFrameChunksAppendExactSize(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAppendExactSize(allocator, out, joined, expected_output_len);
}

pub fn decodeFrameChunksAppendLimited(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAppendLimited(allocator, out, joined, max_output_len);
}

pub fn decodeFrameChunksInto(chunks: []const []const u8, compressed_scratch: []u8, output: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameInto(joined, output);
}

pub fn decodeFrameChunksIntoExactSize(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameIntoExactSize(joined, output, expected_output_len);
}

pub fn decodedFrameChunksSize(chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedFrameSize(joined);
}

pub fn decodedFrameChunksSizeLimited(chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedFrameSizeLimited(joined, max_output_len);
}

pub fn decodeFrameChunksAllocWithDictionary(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAllocWithDictionary(allocator, joined, dictionary);
}

pub fn decodeFrameChunksAllocWithDictionaryExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAllocWithDictionaryExactSize(allocator, joined, dictionary, expected_output_len);
}

pub fn decodeFrameChunksAllocWithDictionaryLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary, max_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAllocLimitedWithDictionary(allocator, joined, max_output_len, dictionary);
}

pub fn decodeFrameChunksAppendWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAppendWithDictionary(allocator, out, joined, dictionary);
}

pub fn decodeFrameChunksAppendExactSizeWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAppendExactSizeWithDictionary(allocator, out, joined, dictionary, expected_output_len);
}

pub fn decodeFrameChunksAppendLimitedWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAppendLimitedWithDictionary(allocator, out, joined, max_output_len, dictionary);
}

pub fn decodeFrameChunksIntoWithDictionary(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameIntoWithDictionary(joined, output, dictionary);
}

pub fn decodeFrameChunksIntoExactSizeWithDictionary(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameIntoWithDictionaryExactSize(joined, output, dictionary, expected_output_len);
}

pub fn decodedFrameChunksSizeWithDictionary(chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedFrameSizeWithDictionary(joined, dictionary);
}

pub fn decodedFrameChunksSizeLimitedWithDictionary(chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedFrameSizeLimitedWithDictionary(joined, max_output_len, dictionary);
}

pub fn decodeFrameChunksAllocWithDictionarySet(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAllocWithDictionarySet(allocator, joined, dictionary_set);
}

pub fn decodeFrameChunksAllocWithDictionarySetExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAllocWithDictionarySetExactSize(allocator, joined, dictionary_set, expected_output_len);
}

pub fn decodeFrameChunksAllocWithDictionarySetLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet, max_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAllocLimitedWithDictionarySet(allocator, joined, max_output_len, dictionary_set);
}

pub fn decodeFrameChunksAppendWithDictionarySet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAppendWithDictionarySet(allocator, out, joined, dictionary_set);
}

pub fn decodeFrameChunksAppendExactSizeWithDictionarySet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAppendExactSizeWithDictionarySet(allocator, out, joined, dictionary_set, expected_output_len);
}

pub fn decodeFrameChunksAppendLimitedWithDictionarySet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAppendLimitedWithDictionarySet(allocator, out, joined, max_output_len, dictionary_set);
}

pub fn decodeFrameChunksIntoWithDictionarySet(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameIntoWithDictionarySet(joined, output, dictionary_set);
}

pub fn decodeFrameChunksIntoExactSizeWithDictionarySet(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameIntoWithDictionarySetExactSize(joined, output, dictionary_set, expected_output_len);
}

pub fn decodedFrameChunksSizeWithDictionarySet(chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedFrameSizeWithDictionarySet(joined, dictionary_set);
}

pub fn decodedFrameChunksSizeLimitedWithDictionarySet(chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedFrameSizeLimitedWithDictionarySet(joined, max_output_len, dictionary_set);
}

pub fn decodeConcatenatedFrameChunksAlloc(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAlloc(allocator, joined);
}

pub fn decodeConcatenatedFrameChunksAllocExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAllocExactSize(allocator, joined, expected_output_len);
}

pub fn decodeConcatenatedFrameChunksAllocLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAllocLimited(allocator, joined, max_output_len);
}

pub fn decodeConcatenatedFrameChunksAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAppend(allocator, out, joined);
}

pub fn decodeConcatenatedFrameChunksAppendExactSize(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAppendExactSize(allocator, out, joined, expected_output_len);
}

pub fn decodeConcatenatedFrameChunksAppendLimited(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAppendLimited(allocator, out, joined, max_output_len);
}

pub fn decodeConcatenatedFrameChunksInto(chunks: []const []const u8, compressed_scratch: []u8, output: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameInto(joined, output);
}

pub fn decodeConcatenatedFrameChunksIntoExactSize(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameIntoExactSize(joined, output, expected_output_len);
}

pub fn decodedConcatenatedFrameChunksSize(chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedConcatenatedFrameSize(joined);
}

pub fn decodedConcatenatedFrameChunksSizeLimited(chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedConcatenatedFrameSizeLimited(joined, max_output_len);
}

pub fn decodeConcatenatedFrameChunksAllocWithDictionary(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAllocWithDictionary(allocator, joined, dictionary);
}

pub fn decodeConcatenatedFrameChunksAllocWithDictionaryExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAllocWithDictionaryExactSize(allocator, joined, dictionary, expected_output_len);
}

pub fn decodeConcatenatedFrameChunksAllocWithDictionaryLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary, max_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAllocLimitedWithDictionary(allocator, joined, max_output_len, dictionary);
}

pub fn decodeConcatenatedFrameChunksAppendWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAppendWithDictionary(allocator, out, joined, dictionary);
}

pub fn decodeConcatenatedFrameChunksAppendExactSizeWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAppendExactSizeWithDictionary(allocator, out, joined, dictionary, expected_output_len);
}

pub fn decodeConcatenatedFrameChunksAppendLimitedWithDictionary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAppendLimitedWithDictionary(allocator, out, joined, max_output_len, dictionary);
}

pub fn decodeConcatenatedFrameChunksIntoWithDictionary(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameIntoWithDictionary(joined, output, dictionary);
}

pub fn decodeConcatenatedFrameChunksIntoExactSizeWithDictionary(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: NativeDictionary, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameIntoWithDictionaryExactSize(joined, output, dictionary, expected_output_len);
}

pub fn decodedConcatenatedFrameChunksSizeWithDictionary(chunks: []const []const u8, compressed_scratch: []u8, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedConcatenatedFrameSizeWithDictionary(joined, dictionary);
}

pub fn decodedConcatenatedFrameChunksSizeLimitedWithDictionary(chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedConcatenatedFrameSizeLimitedWithDictionary(joined, max_output_len, dictionary);
}

pub fn decodeConcatenatedFrameChunksAllocWithDictionarySet(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAllocWithDictionarySet(allocator, joined, dictionary_set);
}

pub fn decodeConcatenatedFrameChunksAllocWithDictionarySetExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAllocWithDictionarySetExactSize(allocator, joined, dictionary_set, expected_output_len);
}

pub fn decodeConcatenatedFrameChunksAllocWithDictionarySetLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet, max_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAllocLimitedWithDictionarySet(allocator, joined, max_output_len, dictionary_set);
}

pub fn decodeConcatenatedFrameChunksAppendWithDictionarySet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAppendWithDictionarySet(allocator, out, joined, dictionary_set);
}

pub fn decodeConcatenatedFrameChunksAppendExactSizeWithDictionarySet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAppendExactSizeWithDictionarySet(allocator, out, joined, dictionary_set, expected_output_len);
}

pub fn decodeConcatenatedFrameChunksAppendLimitedWithDictionarySet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameAppendLimitedWithDictionarySet(allocator, out, joined, max_output_len, dictionary_set);
}

pub fn decodeConcatenatedFrameChunksIntoWithDictionarySet(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameIntoWithDictionarySet(joined, output, dictionary_set);
}

pub fn decodeConcatenatedFrameChunksIntoExactSizeWithDictionarySet(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary_set: NativeDictionarySet, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameIntoWithDictionarySetExactSize(joined, output, dictionary_set, expected_output_len);
}

pub fn decodedConcatenatedFrameChunksSizeWithDictionarySet(chunks: []const []const u8, compressed_scratch: []u8, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedConcatenatedFrameSizeWithDictionarySet(joined, dictionary_set);
}

pub fn decodedConcatenatedFrameChunksSizeLimitedWithDictionarySet(chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedConcatenatedFrameSizeLimitedWithDictionarySet(joined, max_output_len, dictionary_set);
}

pub const decodeNativeFrameChunksAlloc = decodeFrameChunksAlloc;
pub const decodeNativeFrameChunksAllocExactSize = decodeFrameChunksAllocExactSize;
pub const decodeNativeFrameChunksAllocLimited = decodeFrameChunksAllocLimited;
pub const decodeNativeFrameChunksAppend = decodeFrameChunksAppend;
pub const decodeNativeFrameChunksAppendExactSize = decodeFrameChunksAppendExactSize;
pub const decodeNativeFrameChunksAppendLimited = decodeFrameChunksAppendLimited;
pub const decodeNativeFrameChunksInto = decodeFrameChunksInto;
pub const decodeNativeFrameChunksIntoExactSize = decodeFrameChunksIntoExactSize;
pub const decodedNativeFrameChunksSize = decodedFrameChunksSize;
pub const decodedNativeFrameChunksSizeLimited = decodedFrameChunksSizeLimited;
pub const decodeNativeFrameChunksAllocWithDictionary = decodeFrameChunksAllocWithDictionary;
pub const decodeNativeFrameChunksAllocWithDictionaryExactSize = decodeFrameChunksAllocWithDictionaryExactSize;
pub const decodeNativeFrameChunksAllocWithDictionaryLimited = decodeFrameChunksAllocWithDictionaryLimited;
pub const decodeNativeFrameChunksAppendWithDictionary = decodeFrameChunksAppendWithDictionary;
pub const decodeNativeFrameChunksAppendExactSizeWithDictionary = decodeFrameChunksAppendExactSizeWithDictionary;
pub const decodeNativeFrameChunksAppendLimitedWithDictionary = decodeFrameChunksAppendLimitedWithDictionary;
pub const decodeNativeFrameChunksIntoWithDictionary = decodeFrameChunksIntoWithDictionary;
pub const decodeNativeFrameChunksIntoExactSizeWithDictionary = decodeFrameChunksIntoExactSizeWithDictionary;
pub const decodeNativeFrameChunksIntoWithDictionaryExactSize = decodeFrameChunksIntoExactSizeWithDictionary;
pub const decodedNativeFrameChunksSizeWithDictionary = decodedFrameChunksSizeWithDictionary;
pub const decodedNativeFrameChunksSizeLimitedWithDictionary = decodedFrameChunksSizeLimitedWithDictionary;
pub const decodeNativeFrameChunksAllocWithDictionarySet = decodeFrameChunksAllocWithDictionarySet;
pub const decodeNativeFrameChunksAllocWithDictionarySetExactSize = decodeFrameChunksAllocWithDictionarySetExactSize;
pub const decodeNativeFrameChunksAllocWithDictionarySetLimited = decodeFrameChunksAllocWithDictionarySetLimited;
pub const decodeNativeFrameChunksAppendWithDictionarySet = decodeFrameChunksAppendWithDictionarySet;
pub const decodeNativeFrameChunksAppendExactSizeWithDictionarySet = decodeFrameChunksAppendExactSizeWithDictionarySet;
pub const decodeNativeFrameChunksAppendLimitedWithDictionarySet = decodeFrameChunksAppendLimitedWithDictionarySet;
pub const decodeNativeFrameChunksIntoWithDictionarySet = decodeFrameChunksIntoWithDictionarySet;
pub const decodeNativeFrameChunksIntoExactSizeWithDictionarySet = decodeFrameChunksIntoExactSizeWithDictionarySet;
pub const decodeNativeFrameChunksIntoWithDictionarySetExactSize = decodeFrameChunksIntoExactSizeWithDictionarySet;
pub const decodedNativeFrameChunksSizeWithDictionarySet = decodedFrameChunksSizeWithDictionarySet;
pub const decodedNativeFrameChunksSizeLimitedWithDictionarySet = decodedFrameChunksSizeLimitedWithDictionarySet;
pub const decodeNativeConcatenatedFrameAlloc = decodeConcatenatedFrameAlloc;
pub const decodeNativeConcatenatedFrameAllocExactSize = decodeConcatenatedFrameAllocExactSize;
pub const decodeNativeConcatenatedFrameAppend = decodeConcatenatedFrameAppend;
pub const decodeNativeConcatenatedFrameAppendExactSize = decodeConcatenatedFrameAppendExactSize;
pub const decodeNativeConcatenatedFrameAppendLimited = decodeConcatenatedFrameAppendLimited;
pub const decodeNativeConcatenatedFrameAllocLimited = decodeConcatenatedFrameAllocLimited;
pub const decodeNativeConcatenatedFrameInto = decodeConcatenatedFrameInto;
pub const decodeNativeConcatenatedFrameIntoExactSize = decodeConcatenatedFrameIntoExactSize;
pub const decodedNativeConcatenatedFrameSize = decodedConcatenatedFrameSize;
pub const decodedNativeConcatenatedFrameSizeLimited = decodedConcatenatedFrameSizeLimited;
pub const decodeNativeConcatenatedFrameAllocWithDictionary = decodeConcatenatedFrameAllocWithDictionary;
pub const decodeNativeConcatenatedFrameAllocWithDictionaryExactSize = decodeConcatenatedFrameAllocWithDictionaryExactSize;
pub const decodeNativeConcatenatedFrameIntoWithDictionaryExactSize = decodeConcatenatedFrameIntoWithDictionaryExactSize;
pub const decodeNativeConcatenatedFrameAppendWithDictionary = decodeConcatenatedFrameAppendWithDictionary;
pub const decodeNativeConcatenatedFrameAppendExactSizeWithDictionary = decodeConcatenatedFrameAppendExactSizeWithDictionary;
pub const decodeNativeConcatenatedFrameAppendLimitedWithDictionary = decodeConcatenatedFrameAppendLimitedWithDictionary;
pub const decodeNativeConcatenatedFrameAllocLimitedWithDictionary = decodeConcatenatedFrameAllocLimitedWithDictionary;
pub const decodeNativeConcatenatedFrameIntoWithDictionary = decodeConcatenatedFrameIntoWithDictionary;
pub const decodeNativeConcatenatedFrameAllocWithDictionarySet = decodeConcatenatedFrameAllocWithDictionarySet;
pub const decodeNativeConcatenatedFrameAllocWithDictionarySetExactSize = decodeConcatenatedFrameAllocWithDictionarySetExactSize;
pub const decodeNativeConcatenatedFrameIntoWithDictionarySetExactSize = decodeConcatenatedFrameIntoWithDictionarySetExactSize;
pub const decodeNativeConcatenatedFrameAppendWithDictionarySet = decodeConcatenatedFrameAppendWithDictionarySet;
pub const decodeNativeConcatenatedFrameAppendExactSizeWithDictionarySet = decodeConcatenatedFrameAppendExactSizeWithDictionarySet;
pub const decodeNativeConcatenatedFrameAppendLimitedWithDictionarySet = decodeConcatenatedFrameAppendLimitedWithDictionarySet;
pub const decodeNativeConcatenatedFrameAllocLimitedWithDictionarySet = decodeConcatenatedFrameAllocLimitedWithDictionarySet;
pub const decodeNativeConcatenatedFrameIntoWithDictionarySet = decodeConcatenatedFrameIntoWithDictionarySet;
pub const decodedNativeConcatenatedFrameSizeWithDictionary = decodedConcatenatedFrameSizeWithDictionary;
pub const decodedNativeConcatenatedFrameSizeLimitedWithDictionary = decodedConcatenatedFrameSizeLimitedWithDictionary;
pub const decodedNativeConcatenatedFrameSizeWithDictionarySet = decodedConcatenatedFrameSizeWithDictionarySet;
pub const decodedNativeConcatenatedFrameSizeLimitedWithDictionarySet = decodedConcatenatedFrameSizeLimitedWithDictionarySet;
pub const decodeNativeConcatenatedFrameChunksAlloc = decodeConcatenatedFrameChunksAlloc;
pub const decodeNativeConcatenatedFrameChunksAllocExactSize = decodeConcatenatedFrameChunksAllocExactSize;
pub const decodeNativeConcatenatedFrameChunksAllocLimited = decodeConcatenatedFrameChunksAllocLimited;
pub const decodeNativeConcatenatedFrameChunksAppend = decodeConcatenatedFrameChunksAppend;
pub const decodeNativeConcatenatedFrameChunksAppendExactSize = decodeConcatenatedFrameChunksAppendExactSize;
pub const decodeNativeConcatenatedFrameChunksAppendLimited = decodeConcatenatedFrameChunksAppendLimited;
pub const decodeNativeConcatenatedFrameChunksInto = decodeConcatenatedFrameChunksInto;
pub const decodeNativeConcatenatedFrameChunksIntoExactSize = decodeConcatenatedFrameChunksIntoExactSize;
pub const decodedNativeConcatenatedFrameChunksSize = decodedConcatenatedFrameChunksSize;
pub const decodedNativeConcatenatedFrameChunksSizeLimited = decodedConcatenatedFrameChunksSizeLimited;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionary = decodeConcatenatedFrameChunksAllocWithDictionary;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionaryExactSize = decodeConcatenatedFrameChunksAllocWithDictionaryExactSize;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionaryLimited = decodeConcatenatedFrameChunksAllocWithDictionaryLimited;
pub const decodeNativeConcatenatedFrameChunksAppendWithDictionary = decodeConcatenatedFrameChunksAppendWithDictionary;
pub const decodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionary = decodeConcatenatedFrameChunksAppendExactSizeWithDictionary;
pub const decodeNativeConcatenatedFrameChunksAppendLimitedWithDictionary = decodeConcatenatedFrameChunksAppendLimitedWithDictionary;
pub const decodeNativeConcatenatedFrameChunksIntoWithDictionary = decodeConcatenatedFrameChunksIntoWithDictionary;
pub const decodeNativeConcatenatedFrameChunksIntoExactSizeWithDictionary = decodeConcatenatedFrameChunksIntoExactSizeWithDictionary;
pub const decodeNativeConcatenatedFrameChunksIntoWithDictionaryExactSize = decodeConcatenatedFrameChunksIntoExactSizeWithDictionary;
pub const decodedNativeConcatenatedFrameChunksSizeWithDictionary = decodedConcatenatedFrameChunksSizeWithDictionary;
pub const decodedNativeConcatenatedFrameChunksSizeLimitedWithDictionary = decodedConcatenatedFrameChunksSizeLimitedWithDictionary;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionarySet = decodeConcatenatedFrameChunksAllocWithDictionarySet;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionarySetExactSize = decodeConcatenatedFrameChunksAllocWithDictionarySetExactSize;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionarySetLimited = decodeConcatenatedFrameChunksAllocWithDictionarySetLimited;
pub const decodeNativeConcatenatedFrameChunksAppendWithDictionarySet = decodeConcatenatedFrameChunksAppendWithDictionarySet;
pub const decodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet = decodeConcatenatedFrameChunksAppendExactSizeWithDictionarySet;
pub const decodeNativeConcatenatedFrameChunksAppendLimitedWithDictionarySet = decodeConcatenatedFrameChunksAppendLimitedWithDictionarySet;
pub const decodeNativeConcatenatedFrameChunksIntoWithDictionarySet = decodeConcatenatedFrameChunksIntoWithDictionarySet;
pub const decodeNativeConcatenatedFrameChunksIntoExactSizeWithDictionarySet = decodeConcatenatedFrameChunksIntoExactSizeWithDictionarySet;
pub const decodeNativeConcatenatedFrameChunksIntoWithDictionarySetExactSize = decodeConcatenatedFrameChunksIntoExactSizeWithDictionarySet;
pub const decodedNativeConcatenatedFrameChunksSizeWithDictionarySet = decodedConcatenatedFrameChunksSizeWithDictionarySet;
pub const decodedNativeConcatenatedFrameChunksSizeLimitedWithDictionarySet = decodedConcatenatedFrameChunksSizeLimitedWithDictionarySet;

fn joinChunks(chunks: []const []const u8, compressed_scratch: []u8) Error![]const u8 {
    var total: usize = 0;
    for (chunks) |chunk| total = try checkedAdd(total, chunk.len);
    if (compressed_scratch.len < total) return error.OutputTooSmall;
    var offset: usize = 0;
    for (chunks) |chunk| {
        @memcpy(compressed_scratch[offset..][0..chunk.len], chunk);
        offset += chunk.len;
    }
    return compressed_scratch[0..total];
}

/// Decode an LZ4 frame directly into caller-owned storage. The returned length
/// is the number of bytes written. This path shares the strict frame metadata,
/// block-size, block-checksum, content-size, and content-checksum validation of
/// `decodeFrameAlloc` while avoiding heap allocation for applications that can
/// provide the output buffer up front.
pub fn decodeFrameInto(frame: []const u8, output: []u8) Error!usize {
    const header = try parseFrameHeader(frame);
    try rejectNativeDictionaryHeader(header);
    var offset = header.payload_offset;
    var written: usize = 0;
    if (header.expected_content_size) |size| {
        if (output.len < try checkedU64ToUsize(size)) return error.OutputTooSmall;
    }

    while (true) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const block_header = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        if (block_header == 0) break;
        const uncompressed_block = (block_header & 0x8000_0000) != 0;
        const block_len: usize = @intCast(block_header & 0x7fff_ffff);
        if (block_len > header.block_size_max) return error.CorruptFrame;
        if (frame.len - offset < block_len) return error.TruncatedFrame;
        if (output.len - written < block_len and uncompressed_block) return error.OutputTooSmall;

        const block = frame[offset..][0..block_len];
        offset += block_len;
        if (uncompressed_block) {
            @memcpy(output[written..][0..block_len], block);
            written += block_len;
        } else {
            const block_start = written;
            const history_start = if (header.block_independent or block_start <= max_block_history_len)
                if (header.block_independent) block_start else 0
            else
                block_start - max_block_history_len;
            try decodeBlockIntoBuffer(block, output, &written, null, history_start);
        }

        if (header.block_checksum) {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const expected = std.mem.readInt(u32, frame[offset..][0..4], .little);
            if (std.hash.XxHash32.hash(0, block) != expected) return error.ChecksumMismatch;
            offset += 4;
        }
    }

    if (header.expected_content_size) |size| {
        if (written != size) return error.SizeMismatch;
    }
    if (header.content_checksum) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const expected = std.mem.readInt(u32, frame[offset..][0..4], .little);
        if (std.hash.XxHash32.hash(0, output[0..written]) != expected) return error.ChecksumMismatch;
        offset += 4;
    }
    if (offset != frame.len) return error.TrailingData;
    return written;
}

pub fn decodeFrameIntoWithDictionary(frame: []const u8, output: []u8, dictionary: NativeDictionary) Error!usize {
    const header = try parseFrameHeader(frame);
    const dictionary_history = try validateNativeDictionary(header, dictionary);
    var offset = header.payload_offset;
    var written: usize = 0;
    var block_index: usize = 0;
    if (header.expected_content_size) |size| {
        if (output.len < try checkedU64ToUsize(size)) return error.OutputTooSmall;
    }

    while (true) : (block_index += 1) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const block_header = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        if (block_header == 0) break;
        const uncompressed_block = (block_header & 0x8000_0000) != 0;
        const block_len: usize = @intCast(block_header & 0x7fff_ffff);
        if (block_len > header.block_size_max) return error.CorruptFrame;
        if (frame.len - offset < block_len) return error.TruncatedFrame;
        if (output.len - written < block_len and uncompressed_block) return error.OutputTooSmall;

        const block = frame[offset..][0..block_len];
        offset += block_len;
        if (uncompressed_block) {
            @memcpy(output[written..][0..block_len], block);
            written += block_len;
        } else if (dictionary_history.len != 0 and (header.block_independent or block_index == 0)) {
            written += try decodeBlockWithPrefixIntoSliceNoAlloc(block, output[written..], null, dictionary_history);
        } else {
            const block_start = written;
            const history_start = if (header.block_independent or block_start <= max_block_history_len)
                if (header.block_independent) block_start else 0
            else
                block_start - max_block_history_len;
            try decodeBlockIntoBuffer(block, output, &written, null, history_start);
        }

        if (header.block_checksum) {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const expected = std.mem.readInt(u32, frame[offset..][0..4], .little);
            if (std.hash.XxHash32.hash(0, block) != expected) return error.ChecksumMismatch;
            offset += 4;
        }
    }

    if (header.expected_content_size) |size| {
        if (written != size) return error.SizeMismatch;
    }
    if (header.content_checksum) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const expected = std.mem.readInt(u32, frame[offset..][0..4], .little);
        if (std.hash.XxHash32.hash(0, output[0..written]) != expected) return error.ChecksumMismatch;
        offset += 4;
    }
    if (offset != frame.len) return error.TrailingData;
    return written;
}

pub fn decodeFrameIntoWithDictionarySet(frame: []const u8, output: []u8, dictionary_set: NativeDictionarySet) Error!usize {
    const header = try parseFrameHeader(frame);
    const dictionary = try dictionaryForHeader(header, dictionary_set);
    return try decodeFrameIntoWithDictionary(frame, output, dictionary);
}

pub const decodeNativeFrameInto = decodeFrameInto;
pub const decodeNativeFrameIntoWithDictionary = decodeFrameIntoWithDictionary;
pub const decodeNativeFrameIntoWithDictionarySet = decodeFrameIntoWithDictionarySet;

fn decodeNextFrameIntoList(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frames: []const u8,
    offset: *usize,
) Error!void {
    if (frames.len - offset.* < 4) return error.TruncatedFrame;
    const magic = std.mem.readInt(u32, frames[offset.*..][0..4], .little);
    if (magic == frame_magic_u32) {
        const start = offset.*;
        const end = try findFrameEnd(frames, offset);
        const decoded = try decodeFrameAlloc(allocator, frames[start..end]);
        defer allocator.free(decoded);
        try out.appendSlice(allocator, decoded);
    } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
        try skipSkippableFrame(frames, offset);
    } else {
        return error.CorruptFrame;
    }
}

fn decodeNextFrameIntoBuffer(
    frames: []const u8,
    offset: *usize,
    output: []u8,
    written: *usize,
) Error!void {
    if (frames.len - offset.* < 4) return error.TruncatedFrame;
    const magic = std.mem.readInt(u32, frames[offset.*..][0..4], .little);
    if (magic == frame_magic_u32) {
        const start = offset.*;
        const end = try findFrameEnd(frames, offset);
        written.* += try decodeFrameInto(frames[start..end], output[written.*..]);
    } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
        try skipSkippableFrame(frames, offset);
    } else {
        return error.CorruptFrame;
    }
}

fn decodeNextFrameIntoBufferWithDictionary(
    frames: []const u8,
    offset: *usize,
    output: []u8,
    written: *usize,
    dictionary: NativeDictionary,
) Error!void {
    if (frames.len - offset.* < 4) return error.TruncatedFrame;
    const magic = std.mem.readInt(u32, frames[offset.*..][0..4], .little);
    if (magic == frame_magic_u32) {
        const start = offset.*;
        const end = try findFrameEnd(frames, offset);
        written.* += try decodeFrameIntoWithDictionary(frames[start..end], output[written.*..], dictionary);
    } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
        try skipSkippableFrame(frames, offset);
    } else {
        return error.CorruptFrame;
    }
}

fn decodeNextFrameIntoBufferWithDictionarySet(
    frames: []const u8,
    offset: *usize,
    output: []u8,
    written: *usize,
    dictionary_set: NativeDictionarySet,
) Error!void {
    if (frames.len - offset.* < 4) return error.TruncatedFrame;
    const magic = std.mem.readInt(u32, frames[offset.*..][0..4], .little);
    if (magic == frame_magic_u32) {
        const start = offset.*;
        const end = try findFrameEnd(frames, offset);
        written.* += try decodeFrameIntoWithDictionarySet(frames[start..end], output[written.*..], dictionary_set);
    } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
        try skipSkippableFrame(frames, offset);
    } else {
        return error.CorruptFrame;
    }
}

fn skipSkippableFrame(frames: []const u8, offset: *usize) Error!void {
    if (frames.len - offset.* < 8) return error.TruncatedFrame;
    const skip_len: usize = @intCast(std.mem.readInt(u32, frames[offset.* + 4 ..][0..4], .little));
    offset.* += 8;
    if (frames.len - offset.* < skip_len) return error.TruncatedFrame;
    offset.* += skip_len;
}

fn concatenatedFrameDecodedSizeLimited(frames: []const u8, max_output_len: usize) Error!usize {
    var offset: usize = 0;
    var total: usize = 0;
    while (offset < frames.len) {
        if (frames.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frames[offset..][0..4], .little);
        if (magic == frame_magic_u32) {
            const start = offset;
            const end = try findFrameEnd(frames, &offset);
            const frame_len = try frameDecodedSizeLimited(frames[start..end], max_output_len - total);
            total = try checkedAddWithinLimit(total, frame_len, max_output_len);
        } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            try skipSkippableFrame(frames, &offset);
        } else {
            return error.CorruptFrame;
        }
    }
    return total;
}

fn concatenatedFrameDecodedSizeLimitedWithDictionary(frames: []const u8, max_output_len: usize, dictionary: NativeDictionary) Error!usize {
    var offset: usize = 0;
    var total: usize = 0;
    while (offset < frames.len) {
        if (frames.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frames[offset..][0..4], .little);
        if (magic == frame_magic_u32) {
            const start = offset;
            const end = try findFrameEnd(frames, &offset);
            const frame_len = try frameDecodedSizeLimitedWithDictionary(frames[start..end], max_output_len - total, dictionary);
            total = try checkedAddWithinLimit(total, frame_len, max_output_len);
        } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            try skipSkippableFrame(frames, &offset);
        } else {
            return error.CorruptFrame;
        }
    }
    return total;
}

fn concatenatedFrameDecodedSizeLimitedWithDictionarySet(frames: []const u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error!usize {
    var offset: usize = 0;
    var total: usize = 0;
    while (offset < frames.len) {
        if (frames.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frames[offset..][0..4], .little);
        if (magic == frame_magic_u32) {
            const start = offset;
            const end = try findFrameEnd(frames, &offset);
            const frame_len = try frameDecodedSizeLimitedWithDictionarySet(frames[start..end], max_output_len - total, dictionary_set);
            total = try checkedAddWithinLimit(total, frame_len, max_output_len);
        } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            try skipSkippableFrame(frames, &offset);
        } else {
            return error.CorruptFrame;
        }
    }
    return total;
}

pub const NativeFrameHeader = struct {
    payload_offset: usize,
    block_size_max: usize,
    block_independent: bool,
    block_checksum: bool,
    content_checksum: bool,
    expected_content_size: ?u64,
    dictionary_id: ?u32 = null,
};

const FrameHeader = NativeFrameHeader;

pub const NativeFrameBlockHeader = struct {
    header_offset: usize,
    payload_offset: usize,
    payload_len: usize,
    is_compressed: bool,
    block_checksum_offset: ?usize = null,
    next_header_offset: usize,
};

pub const NativeFrameBlockSummary = struct {
    block_count: usize = 0,
    compressed_block_count: usize = 0,
    raw_block_count: usize = 0,
    payload_bytes: usize = 0,
};

pub const BlockSummary = struct {
    decoded_bytes: usize = 0,
    literal_count: usize = 0,
    literal_bytes: usize = 0,
    match_count: usize = 0,
    match_bytes: usize = 0,
};

pub const NativeSkippableFrameHeader = struct {
    skippable_id: u4,
    payload_offset: usize,
    payload_len: usize,
    next_frame_offset: usize,
};

pub const NativeStreamSummaryErrorPhase = enum {
    magic,
    frame_header,
    frame_body,
    frame_checksum,
    skippable_header,
    skippable_payload,
    stream,
    frame,
};

pub const NativeStreamSummaryErrorDiagnostics = struct {
    phase: NativeStreamSummaryErrorPhase = .stream,
    offset: usize = 0,
};

pub const NativeStreamSummary = struct {
    frame_count: usize = 0,
    skippable_frame_count: usize = 0,
    content_size_frame_count: usize = 0,
    checksum_frame_count: usize = 0,
    block_checksum_frame_count: usize = 0,
    dictionary_id_frame_count: usize = 0,
    declared_content_bytes: u64 = 0,
    block_count: usize = 0,
    compressed_block_count: usize = 0,
    raw_block_count: usize = 0,
    payload_bytes: usize = 0,
    skippable_payload_bytes: usize = 0,
};

/// Zero-allocation cursor over a single native LZ4 frame's data blocks.
/// Returned block offsets are relative to `frame`; when `next()` returns null,
/// `next_header_offset` points just after the LZ4 end mark and optional content
/// checksum. Use `NativeStreamIterator` for concatenated streams with
/// skippable frames instead of passing a whole stream here.
pub const NativeFrameBlockIterator = struct {
    frame: []const u8,
    header: NativeFrameHeader,
    next_header_offset: usize,
    end_mark_offset: ?usize = null,
    finished: bool = false,

    pub fn init(frame: []const u8) Error!NativeFrameBlockIterator {
        const header = try parseFrameHeader(frame);
        return .{
            .frame = frame,
            .header = header,
            .next_header_offset = header.payload_offset,
        };
    }

    pub fn next(self: *NativeFrameBlockIterator) Error!?NativeFrameBlockHeader {
        if (self.finished) return null;
        const header_offset = self.next_header_offset;
        const block = (try inspectNativeFrameBlockAt(self.frame, header_offset)) orelse {
            var frame_end = std.math.add(usize, header_offset, 4) catch return error.IntegerOverflow;
            if (self.header.content_checksum) {
                if (self.frame.len - frame_end < 4) return error.TruncatedFrame;
                frame_end += 4;
            }
            self.end_mark_offset = header_offset;
            self.next_header_offset = frame_end;
            self.finished = true;
            return null;
        };
        self.next_header_offset = block.next_header_offset;
        return block;
    }
};

/// One non-skippable frame discovered inside a concatenated native LZ4 stream.
pub const NativeStreamFrame = struct {
    offset: usize,
    bytes: []const u8,
    header: NativeFrameHeader,

    pub fn blockIterator(self: NativeStreamFrame) Error!NativeFrameBlockIterator {
        return try NativeFrameBlockIterator.init(self.bytes);
    }
};

/// One skippable frame discovered inside a concatenated native LZ4 stream.
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

/// Zero-allocation cursor over concatenated native LZ4 frames and skippable
/// metadata frames. It validates frame boundaries before yielding so callers can
/// safely slice `bytes`/`payload` without materializing decoded output.
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
            var end = start;
            _ = try findFrameEnd(self.frames, &end);
            const bytes = self.frames[start..end];
            const header = try parseFrameHeader(bytes);
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
            return error.CorruptFrame;
        }
    }
};

pub fn iterateNativeFrameBlocks(frame: []const u8) Error!NativeFrameBlockIterator {
    return try NativeFrameBlockIterator.init(frame);
}

pub fn iterateNativeStream(frames: []const u8) NativeStreamIterator {
    return NativeStreamIterator.init(frames);
}

fn parseFrameHeader(frame: []const u8) Error!FrameHeader {
    if (frame.len < 7) return error.TruncatedFrame;
    if (!std.mem.eql(u8, frame[0..4], &frame_magic)) return error.CorruptFrame;
    const flg = frame[4];
    const bd = frame[5];
    const version = (flg >> 6) & 0x03;
    if (version != 0x01) return error.UnsupportedVersion;
    if ((flg & 0x02) != 0) return error.CorruptFrame;

    var offset: usize = 6;
    const expected_content_size: ?u64 = if ((flg & 0x08) != 0) blk: {
        if (frame.len - offset < 8) return error.TruncatedFrame;
        const value = std.mem.readInt(u64, frame[offset..][0..8], .little);
        offset += 8;
        break :blk value;
    } else null;
    const dictionary_id: ?u32 = if ((flg & 0x01) != 0) blk: {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const value = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        break :blk value;
    } else null;
    if (offset >= frame.len) return error.TruncatedFrame;
    if (frame[offset] != descriptorChecksum(frame[4..offset])) return error.ChecksumMismatch;
    offset += 1;

    return .{
        .payload_offset = offset,
        .block_size_max = try blockSizeMaxFromDescriptor(bd),
        .block_independent = (flg & 0x20) != 0,
        .block_checksum = (flg & 0x10) != 0,
        .content_checksum = (flg & 0x04) != 0,
        .expected_content_size = expected_content_size,
        .dictionary_id = dictionary_id,
    };
}

pub fn inspectNativeFrameHeader(frame: []const u8) Error!NativeFrameHeader {
    return try parseFrameHeader(frame);
}

pub fn inspectNativeFrameBlockAt(frame: []const u8, header_offset: usize) Error!?NativeFrameBlockHeader {
    const header = try parseFrameHeader(frame);
    if (header_offset < header.payload_offset) return error.CorruptFrame;
    if (frame.len - header_offset < 4) return error.TruncatedFrame;
    const block_header = std.mem.readInt(u32, frame[header_offset..][0..4], .little);
    if (block_header == 0) return null;
    const payload_len: usize = @intCast(block_header & 0x7fff_ffff);
    if (payload_len > header.block_size_max) return error.CorruptFrame;
    const payload_offset = header_offset + 4;
    if (frame.len - payload_offset < payload_len) return error.TruncatedFrame;
    const block_checksum_offset: ?usize = if (header.block_checksum) blk: {
        const checksum_offset = payload_offset + payload_len;
        if (frame.len - checksum_offset < 4) return error.TruncatedFrame;
        break :blk checksum_offset;
    } else null;
    const next_header_offset = payload_offset + payload_len + if (header.block_checksum) @as(usize, 4) else 0;
    return .{
        .header_offset = header_offset,
        .payload_offset = payload_offset,
        .payload_len = payload_len,
        .is_compressed = (block_header & 0x8000_0000) == 0,
        .block_checksum_offset = block_checksum_offset,
        .next_header_offset = next_header_offset,
    };
}

pub fn inspectNativeFrameFirstBlock(frame: []const u8) Error!?NativeFrameBlockHeader {
    const header = try parseFrameHeader(frame);
    return try inspectNativeFrameBlockAt(frame, header.payload_offset);
}

pub fn summarizeNativeFrameBlocks(frame: []const u8) Error!NativeFrameBlockSummary {
    const header = try parseFrameHeader(frame);
    var offset = header.payload_offset;
    var summary: NativeFrameBlockSummary = .{};
    while (true) {
        const block = (try inspectNativeFrameBlockAt(frame, offset)) orelse break;
        summary.block_count += 1;
        if (block.is_compressed) {
            summary.compressed_block_count += 1;
        } else {
            summary.raw_block_count += 1;
        }
        summary.payload_bytes = std.math.add(usize, summary.payload_bytes, block.payload_len) catch return error.IntegerOverflow;
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
    var diagnostics: NativeStreamSummaryErrorDiagnostics = .{};
    return summarizeNativeStreamWithDiagnostics(frames, &diagnostics);
}

pub fn summarizeNativeStreamWithDiagnostics(frames: []const u8, diagnostics: *NativeStreamSummaryErrorDiagnostics) Error!NativeStreamSummary {
    diagnostics.* = .{};
    var offset: usize = 0;
    var summary: NativeStreamSummary = .{};
    while (offset < frames.len) {
        if (frames.len - offset < 4) {
            diagnostics.* = .{ .phase = .magic, .offset = frames.len };
            return error.TruncatedFrame;
        }
        const magic = std.mem.readInt(u32, frames[offset..][0..4], .little);
        if (magic == frame_magic_u32) {
            const start = offset;
            const end = findFrameEndWithDiagnostics(frames, &offset, diagnostics) catch |err| {
                return err;
            };
            const header = inspectNativeFrameHeader(frames[start..end]) catch |err| {
                diagnostics.* = .{ .phase = .frame_header, .offset = start };
                return err;
            };
            if (header.expected_content_size) |content_size| {
                summary.content_size_frame_count += 1;
                summary.declared_content_bytes = std.math.add(u64, summary.declared_content_bytes, content_size) catch return error.IntegerOverflow;
            }
            if (header.content_checksum) summary.checksum_frame_count += 1;
            if (header.block_checksum) summary.block_checksum_frame_count += 1;
            if (header.dictionary_id != null) summary.dictionary_id_frame_count += 1;
            const frame_summary = summarizeNativeFrameBlocks(frames[start..end]) catch |err| {
                diagnostics.* = .{ .phase = nativeSummaryFrameErrorPhase(err, frames[start..end]), .offset = frames.len };
                return err;
            };
            summary.frame_count += 1;
            summary.block_count = std.math.add(usize, summary.block_count, frame_summary.block_count) catch return error.IntegerOverflow;
            summary.compressed_block_count = std.math.add(usize, summary.compressed_block_count, frame_summary.compressed_block_count) catch return error.IntegerOverflow;
            summary.raw_block_count = std.math.add(usize, summary.raw_block_count, frame_summary.raw_block_count) catch return error.IntegerOverflow;
            summary.payload_bytes = std.math.add(usize, summary.payload_bytes, frame_summary.payload_bytes) catch return error.IntegerOverflow;
        } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            if (frames.len - offset < 8) {
                diagnostics.* = .{ .phase = .skippable_header, .offset = frames.len };
                return error.TruncatedFrame;
            }
            const skip_len: usize = @intCast(std.mem.readInt(u32, frames[offset + 4 ..][0..4], .little));
            offset += 8;
            if (frames.len - offset < skip_len) {
                diagnostics.* = .{ .phase = .skippable_payload, .offset = frames.len };
                return error.TruncatedFrame;
            }
            summary.skippable_frame_count += 1;
            summary.skippable_payload_bytes = std.math.add(usize, summary.skippable_payload_bytes, skip_len) catch return error.IntegerOverflow;
            offset += skip_len;
        } else {
            diagnostics.* = .{ .phase = .magic, .offset = offset };
            return error.CorruptFrame;
        }
    }
    return summary;
}

fn nativeSummaryFrameErrorPhase(err: anyerror, frame: []const u8) NativeStreamSummaryErrorPhase {
    if (frame.len < 7) return .frame_header;
    return switch (err) {
        error.TruncatedFrame => .frame_body,
        else => .frame,
    };
}

fn findFrameEndWithDiagnostics(frames: []const u8, offset: *usize, diagnostics: *NativeStreamSummaryErrorDiagnostics) Error!usize {
    const frame_start = offset.*;
    const header = parseFrameHeader(frames[offset.*..]) catch |err| {
        diagnostics.* = .{ .phase = .frame_header, .offset = frames.len };
        return err;
    };
    var local = header.payload_offset;
    while (true) {
        if (frames.len - offset.* - local < 4) {
            diagnostics.* = .{ .phase = .frame_body, .offset = frames.len };
            return error.TruncatedFrame;
        }
        const block_header_offset = offset.* + local;
        const block_header = std.mem.readInt(u32, frames[block_header_offset..][0..4], .little);
        local += 4;
        if (block_header == 0) break;
        const block_len: usize = @intCast(block_header & 0x7fff_ffff);
        if (block_len > header.block_size_max) {
            diagnostics.* = .{ .phase = .frame, .offset = block_header_offset };
            return error.CorruptFrame;
        }
        if (frames.len - offset.* - local < block_len) {
            diagnostics.* = .{ .phase = .frame_body, .offset = frames.len };
            return error.TruncatedFrame;
        }
        local += block_len;
        if (header.block_checksum) {
            if (frames.len - offset.* - local < 4) {
                diagnostics.* = .{ .phase = .frame_body, .offset = frames.len };
                return error.TruncatedFrame;
            }
            local += 4;
        }
    }
    if (header.content_checksum) {
        if (frames.len - offset.* - local < 4) {
            diagnostics.* = .{ .phase = .frame_checksum, .offset = frames.len };
            return error.TruncatedFrame;
        }
        local += 4;
    }
    offset.* = frame_start + local;
    return offset.*;
}

fn findFrameEnd(frames: []const u8, offset: *usize) Error!usize {
    const header = try parseFrameHeader(frames[offset.*..]);
    var local = header.payload_offset;
    while (true) {
        if (frames.len - offset.* - local < 4) return error.TruncatedFrame;
        const block_header = std.mem.readInt(u32, frames[offset.* + local ..][0..4], .little);
        local += 4;
        if (block_header == 0) break;
        const block_len: usize = @intCast(block_header & 0x7fff_ffff);
        if (block_len > header.block_size_max) return error.CorruptFrame;
        if (frames.len - offset.* - local < block_len) return error.TruncatedFrame;
        local += block_len;
        if (header.block_checksum) {
            if (frames.len - offset.* - local < 4) return error.TruncatedFrame;
            local += 4;
        }
    }
    if (header.content_checksum) {
        if (frames.len - offset.* - local < 4) return error.TruncatedFrame;
        local += 4;
    }
    offset.* += local;
    return offset.*;
}

fn frameDecodedSizeLimited(frame: []const u8, max_output_len: usize) Error!usize {
    const header = try parseFrameHeader(frame);
    try rejectNativeDictionaryHeader(header);
    var offset = header.payload_offset;
    var total: usize = 0;
    while (true) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const block_header = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        if (block_header == 0) break;
        const uncompressed_block = (block_header & 0x8000_0000) != 0;
        const block_len: usize = @intCast(block_header & 0x7fff_ffff);
        if (block_len > header.block_size_max) return error.CorruptFrame;
        if (frame.len - offset < block_len) return error.TruncatedFrame;
        const block = frame[offset..][0..block_len];
        offset += block_len;

        if (uncompressed_block) {
            total = try checkedAddWithinLimit(total, block_len, max_output_len);
        } else {
            const block_start = total;
            const history_start = if (header.block_independent or block_start <= max_block_history_len)
                if (header.block_independent) block_start else 0
            else
                block_start - max_block_history_len;
            total = try compressedBlockDecodedSizeLimitedWithHistory(block, total, history_start, max_output_len);
        }

        if (header.block_checksum) {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const expected = std.mem.readInt(u32, frame[offset..][0..4], .little);
            if (std.hash.XxHash32.hash(0, block) != expected) return error.ChecksumMismatch;
            offset += 4;
        }
    }

    if (header.expected_content_size) |size| {
        if (total != size) return error.SizeMismatch;
    }
    if (header.content_checksum) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        offset += 4;
    }
    if (offset != frame.len) return error.TrailingData;
    return total;
}

fn frameDecodedSizeLimitedWithDictionary(frame: []const u8, max_output_len: usize, dictionary: NativeDictionary) Error!usize {
    const header = try parseFrameHeader(frame);
    const dictionary_history = try validateNativeDictionary(header, dictionary);
    return try frameDecodedSizeLimitedWithHeaderAndHistory(frame, max_output_len, header, dictionary_history);
}

fn frameDecodedSizeLimitedWithDictionarySet(frame: []const u8, max_output_len: usize, dictionary_set: NativeDictionarySet) Error!usize {
    const header = try parseFrameHeader(frame);
    const dictionary = try dictionaryForHeader(header, dictionary_set);
    return try frameDecodedSizeLimitedWithDictionary(frame, max_output_len, dictionary);
}

fn frameDecodedSizeLimitedWithHeaderAndHistory(frame: []const u8, max_output_len: usize, header: NativeFrameHeader, dictionary_history: []const u8) Error!usize {
    const prefix_len = @min(dictionary_history.len, max_block_history_len);
    var offset = header.payload_offset;
    var total: usize = 0;
    var block_index: usize = 0;
    while (true) : (block_index += 1) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const block_header = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        if (block_header == 0) break;
        const uncompressed_block = (block_header & 0x8000_0000) != 0;
        const block_len: usize = @intCast(block_header & 0x7fff_ffff);
        if (block_len > header.block_size_max) return error.CorruptFrame;
        if (frame.len - offset < block_len) return error.TruncatedFrame;
        const block = frame[offset..][0..block_len];
        offset += block_len;

        if (uncompressed_block) {
            total = try checkedAddWithinLimit(total, block_len, max_output_len);
        } else if (prefix_len != 0 and (header.block_independent or block_index == 0)) {
            const remaining_limit = max_output_len - total;
            const prefixed_total = try compressedBlockDecodedSizeLimitedWithHistory(
                block,
                prefix_len,
                0,
                if (remaining_limit == std.math.maxInt(usize))
                    std.math.maxInt(usize)
                else
                    std.math.add(usize, prefix_len, remaining_limit) catch return error.IntegerOverflow,
            );
            const decoded_len = prefixed_total - prefix_len;
            total = try checkedAddWithinLimit(total, decoded_len, max_output_len);
        } else {
            const block_start = total;
            const history_start = if (header.block_independent or block_start <= max_block_history_len)
                if (header.block_independent) block_start else 0
            else
                block_start - max_block_history_len;
            total = try compressedBlockDecodedSizeLimitedWithHistory(block, total, history_start, max_output_len);
        }

        if (header.block_checksum) {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const expected = std.mem.readInt(u32, frame[offset..][0..4], .little);
            if (std.hash.XxHash32.hash(0, block) != expected) return error.ChecksumMismatch;
            offset += 4;
        }
    }

    if (header.expected_content_size) |size| {
        if (total != size) return error.SizeMismatch;
    }
    if (header.content_checksum) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        offset += 4;
    }
    if (offset != frame.len) return error.TrailingData;
    return total;
}

fn validateNativeDictionary(header: NativeFrameHeader, dictionary: NativeDictionary) Error![]const u8 {
    const id = header.dictionary_id orelse return &.{};
    if (id != dictionary.id) return error.NeedDictionary;
    return dictionary.content;
}

fn dictionaryForHeader(header: NativeFrameHeader, dictionary_set: NativeDictionarySet) Error!NativeDictionary {
    const id = header.dictionary_id orelse return NativeDictionary.init(0, &.{});
    if (id == 0) return NativeDictionary.init(0, &.{});
    return dictionary_set.find(id) orelse error.NeedDictionary;
}

fn rejectNativeDictionaryHeader(header: NativeFrameHeader) Error!void {
    if (header.dictionary_id) |id| {
        if (id != 0) return error.NeedDictionary;
    }
}

fn compressedBlockDecodedSizeLimited(block: []const u8, initial_len: usize, max_output_len: usize) Error!usize {
    return try compressedBlockDecodedSizeLimitedWithHistory(block, initial_len, initial_len, max_output_len);
}

fn compressedBlockDecodedSizeLimitedWithHistory(
    block: []const u8,
    initial_len: usize,
    history_start: usize,
    max_output_len: usize,
) Error!usize {
    if (history_start > initial_len) return error.InvalidMatch;
    var offset: usize = 0;
    var total = initial_len;
    while (offset < block.len) {
        const token = block[offset];
        offset += 1;
        var literal_len: usize = token >> 4;
        if (literal_len == 15) literal_len = try checkedAdd(literal_len, try readLengthExtension(block, &offset));
        if (block.len - offset < literal_len) return error.TruncatedFrame;
        total = try checkedAddWithinLimit(total, literal_len, max_output_len);
        offset += literal_len;
        if (offset == block.len) break;

        if (block.len - offset < 2) return error.TruncatedFrame;
        const match_offset = std.mem.readInt(u16, block[offset..][0..2], .little);
        offset += 2;
        if (match_offset == 0 or match_offset > total - history_start) return error.InvalidMatch;
        var match_len: usize = (token & 0x0f) + 4;
        if ((token & 0x0f) == 15) match_len = try checkedAdd(match_len, try readLengthExtension(block, &offset));
        total = try checkedAddWithinLimit(total, match_len, max_output_len);
    }
    return total;
}

fn summarizeBlockWithHistoryLimited(
    block: []const u8,
    initial_len: usize,
    history_start: usize,
    max_output_len: usize,
) Error!BlockSummary {
    if (history_start > initial_len) return error.InvalidMatch;
    var offset: usize = 0;
    var total = initial_len;
    var summary: BlockSummary = .{};
    while (offset < block.len) {
        const token = block[offset];
        offset += 1;
        var literal_len: usize = token >> 4;
        if (literal_len == 15) literal_len = try checkedAdd(literal_len, try readLengthExtension(block, &offset));
        if (block.len - offset < literal_len) return error.TruncatedFrame;
        total = try checkedAddWithinLimit(total, literal_len, max_output_len);
        if (literal_len != 0) {
            summary.literal_count += 1;
            summary.literal_bytes = try checkedAdd(summary.literal_bytes, literal_len);
        }
        offset += literal_len;
        if (offset == block.len) break;

        if (block.len - offset < 2) return error.TruncatedFrame;
        const match_offset = std.mem.readInt(u16, block[offset..][0..2], .little);
        offset += 2;
        if (match_offset == 0 or match_offset > total - history_start) return error.InvalidMatch;
        var match_len: usize = (token & 0x0f) + 4;
        if ((token & 0x0f) == 15) match_len = try checkedAdd(match_len, try readLengthExtension(block, &offset));
        total = try checkedAddWithinLimit(total, match_len, max_output_len);
        summary.match_count += 1;
        summary.match_bytes = try checkedAdd(summary.match_bytes, match_len);
    }
    summary.decoded_bytes = total - initial_len;
    return summary;
}

fn descriptorChecksum(descriptor: []const u8) u8 {
    return @truncate(std.hash.XxHash32.hash(0, descriptor) >> 8);
}

fn blockSizeMaxFromDescriptor(bd: u8) Error!usize {
    if ((bd & 0x8f) != 0) return error.CorruptFrame;
    return switch ((bd >> 4) & 0x07) {
        4 => max_block_history_len,
        5 => 256 * 1024,
        6 => 1024 * 1024,
        7 => max_frame_block_len,
        else => error.CorruptFrame,
    };
}

pub const BlockEncoder = struct {
    allocator: std.mem.Allocator,
    hash_table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
    output_scratch: std.ArrayList(u8) = .empty,

    pub fn init(allocator: std.mem.Allocator) Error!BlockEncoder {
        const table = try allocator.alloc(u32, hash_table_len);
        errdefer allocator.free(table);
        const bits = try allocator.alloc(u64, hash_occupancy_words);
        errdefer allocator.free(bits);
        const chain = try allocator.alloc(u32, chain_table_len);
        return .{
            .allocator = allocator,
            .hash_table = table,
            .occupancy_bits = bits,
            .chain_table = chain,
        };
    }

    pub fn deinit(self: *BlockEncoder) void {
        self.output_scratch.deinit(self.allocator);
        self.allocator.free(self.chain_table);
        self.allocator.free(self.occupancy_bits);
        self.allocator.free(self.hash_table);
        self.* = undefined;
    }

    pub fn encodeAlloc(self: *BlockEncoder, input: []const u8) Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(self.allocator);
        _ = try self.append(&out, input);
        return out.toOwnedSlice(self.allocator);
    }

    pub fn encodeWithChainDepthAlloc(self: *BlockEncoder, input: []const u8, chain_depth: u8) Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(self.allocator);
        _ = try self.appendWithChainDepth(&out, input, chain_depth);
        return out.toOwnedSlice(self.allocator);
    }

    pub fn encodeWithPrefixAlloc(self: *BlockEncoder, input: []const u8, prefix: []const u8) Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(self.allocator);
        _ = try self.appendWithPrefix(&out, input, prefix);
        return out.toOwnedSlice(self.allocator);
    }

    pub fn encodeWithPrefixAndChainDepthAlloc(self: *BlockEncoder, input: []const u8, prefix: []const u8, chain_depth: u8) Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(self.allocator);
        _ = try self.appendWithPrefixAndChainDepth(&out, input, prefix, chain_depth);
        return out.toOwnedSlice(self.allocator);
    }

    pub fn append(self: *BlockEncoder, out: *std.ArrayList(u8), input: []const u8) Error!usize {
        return try self.appendWithChainDepth(out, input, max_chain_depth);
    }

    pub fn appendWithChainDepth(self: *BlockEncoder, out: *std.ArrayList(u8), input: []const u8, chain_depth: u8) Error!usize {
        if (chain_depth > max_chain_depth) return error.InvalidBlockPlan;
        return try encodeBlockInto(self.allocator, out, input, self.hash_table, self.occupancy_bits, self.chain_table, chain_depth);
    }

    pub fn appendWithPrefix(self: *BlockEncoder, out: *std.ArrayList(u8), input: []const u8, prefix: []const u8) Error!usize {
        return try self.appendWithPrefixAndChainDepth(out, input, prefix, max_chain_depth);
    }

    pub fn appendWithPrefixAndChainDepth(self: *BlockEncoder, out: *std.ArrayList(u8), input: []const u8, prefix: []const u8, chain_depth: u8) Error!usize {
        if (chain_depth > max_chain_depth) return error.InvalidBlockPlan;
        const history = prefix[if (prefix.len > max_match_offset) prefix.len - max_match_offset else 0..];
        return try encodeLinkedBlockInto(self.allocator, out, history, input, self.hash_table, self.occupancy_bits, self.chain_table, chain_depth);
    }

    pub fn encodeScratch(self: *BlockEncoder, input: []const u8) Error![]const u8 {
        self.output_scratch.clearRetainingCapacity();
        _ = self.append(&self.output_scratch, input) catch |err| {
            self.output_scratch.clearRetainingCapacity();
            return err;
        };
        return self.output_scratch.items;
    }

    pub fn encodeScratchWithChainDepth(self: *BlockEncoder, input: []const u8, chain_depth: u8) Error![]const u8 {
        self.output_scratch.clearRetainingCapacity();
        _ = self.appendWithChainDepth(&self.output_scratch, input, chain_depth) catch |err| {
            self.output_scratch.clearRetainingCapacity();
            return err;
        };
        return self.output_scratch.items;
    }

    pub fn encodeWithPrefixScratch(self: *BlockEncoder, input: []const u8, prefix: []const u8) Error![]const u8 {
        self.output_scratch.clearRetainingCapacity();
        _ = self.appendWithPrefix(&self.output_scratch, input, prefix) catch |err| {
            self.output_scratch.clearRetainingCapacity();
            return err;
        };
        return self.output_scratch.items;
    }

    pub fn encodeWithPrefixScratchAndChainDepth(self: *BlockEncoder, input: []const u8, prefix: []const u8, chain_depth: u8) Error![]const u8 {
        self.output_scratch.clearRetainingCapacity();
        _ = self.appendWithPrefixAndChainDepth(&self.output_scratch, input, prefix, chain_depth) catch |err| {
            self.output_scratch.clearRetainingCapacity();
            return err;
        };
        return self.output_scratch.items;
    }

    pub fn encodeIntoSlice(self: *BlockEncoder, input: []const u8, output: []u8) Error!usize {
        const scratch = try self.encodeScratch(input);
        if (output.len < scratch.len) return error.OutputTooSmall;
        @memcpy(output[0..scratch.len], scratch);
        return scratch.len;
    }

    pub fn encodeIntoSliceWithChainDepth(self: *BlockEncoder, input: []const u8, output: []u8, chain_depth: u8) Error!usize {
        const scratch = try self.encodeScratchWithChainDepth(input, chain_depth);
        if (output.len < scratch.len) return error.OutputTooSmall;
        @memcpy(output[0..scratch.len], scratch);
        return scratch.len;
    }

    pub fn encodeWithPrefixIntoSlice(self: *BlockEncoder, input: []const u8, prefix: []const u8, output: []u8) Error!usize {
        const scratch = try self.encodeWithPrefixScratch(input, prefix);
        if (output.len < scratch.len) return error.OutputTooSmall;
        @memcpy(output[0..scratch.len], scratch);
        return scratch.len;
    }

    pub fn encodeWithPrefixIntoSliceAndChainDepth(self: *BlockEncoder, input: []const u8, prefix: []const u8, output: []u8, chain_depth: u8) Error!usize {
        const scratch = try self.encodeWithPrefixScratchAndChainDepth(input, prefix, chain_depth);
        if (output.len < scratch.len) return error.OutputTooSmall;
        @memcpy(output[0..scratch.len], scratch);
        return scratch.len;
    }
};

pub const NativeFrameEncoder = struct {
    block_encoder: BlockEncoder,
    output_scratch: std.ArrayList(u8) = .empty,

    pub fn init(allocator: std.mem.Allocator) Error!NativeFrameEncoder {
        return .{ .block_encoder = try BlockEncoder.init(allocator) };
    }

    pub fn deinit(self: *NativeFrameEncoder) void {
        self.output_scratch.deinit(self.block_encoder.allocator);
        self.block_encoder.deinit();
        self.* = undefined;
    }

    pub fn encodeAppend(
        self: *NativeFrameEncoder,
        out: *std.ArrayList(u8),
        input: []const u8,
        options: NativeFrameOptions,
    ) Error!void {
        return try self.encodeAppendInternal(out, input, options, null);
    }

    pub fn encodeAppendWithDictionary(
        self: *NativeFrameEncoder,
        out: *std.ArrayList(u8),
        input: []const u8,
        options: NativeFrameOptions,
        dictionary: NativeDictionary,
    ) Error!void {
        if (dictionary.id == 0) return error.NeedDictionary;
        return try self.encodeAppendInternal(out, input, options, dictionary);
    }

    pub fn encodeAppendWithDictionarySet(
        self: *NativeFrameEncoder,
        out: *std.ArrayList(u8),
        input: []const u8,
        options: NativeFrameOptions,
        dictionary_set: NativeDictionarySet,
        dictionary_id: u32,
    ) Error!void {
        const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
        return try self.encodeAppendWithDictionary(out, input, options, dictionary);
    }

    fn encodeAppendInternal(
        self: *NativeFrameEncoder,
        out: *std.ArrayList(u8),
        input: []const u8,
        options: NativeFrameOptions,
        dictionary: ?NativeDictionary,
    ) Error!void {
        const allocator = self.block_encoder.allocator;
        const frame_options = optionsWithNativeDictionary(options, dictionary);
        try out.appendSlice(allocator, &frame_magic);
        const descriptor_start = out.items.len;
        var flg: u8 = 0x40;
        if (frame_options.block_mode == .independent) flg |= 0x20;
        if (frame_options.block_checksum) flg |= 0x10;
        if (frame_options.include_content_size) flg |= 0x08;
        if (frame_options.content_checksum) flg |= 0x04;
        if (frame_options.dictionary_id != null) flg |= 0x01;
        try out.append(allocator, flg);
        try out.append(allocator, @intFromEnum(frame_options.block_size_id) << 4);
        if (frame_options.include_content_size) {
            var content_size: [8]u8 = undefined;
            std.mem.writeInt(u64, &content_size, try checkedUsizeToU64(input.len), .little);
            try out.appendSlice(allocator, &content_size);
        }
        if (frame_options.dictionary_id) |dictionary_id| {
            var dictionary_id_bytes: [4]u8 = undefined;
            std.mem.writeInt(u32, &dictionary_id_bytes, dictionary_id, .little);
            try out.appendSlice(allocator, &dictionary_id_bytes);
        }
        const descriptor = out.items[descriptor_start..];
        try out.append(allocator, @truncate(std.hash.XxHash32.hash(0, descriptor) >> 8));

        var offset: usize = 0;
        const max_block_len = frame_options.block_size_id.maxLen();
        const chain_depth = try nativeChainDepth(frame_options);
        while (offset < input.len) {
            const block_len = @min(input.len - offset, max_block_len);
            var header: [4]u8 = undefined;
            const block = input[offset..][0..block_len];
            const history = if (dictionary != null and (frame_options.block_mode == .independent or offset == 0))
                dictionary.?.content
            else if (frame_options.block_mode == .linked)
                input[if (offset > max_match_offset) offset - max_match_offset else 0..offset]
            else
                &[_]u8{};
            const header_start = out.items.len;
            try out.appendNTimes(allocator, 0, 4);
            const encoded_start = out.items.len;
            const compressed_len = if (history.len == 0)
                try self.block_encoder.appendWithChainDepth(out, block, chain_depth)
            else
                try self.block_encoder.appendWithPrefixAndChainDepth(out, block, history, chain_depth);
            if (compressed_len < block.len) {
                std.mem.writeInt(u32, out.items[header_start..][0..4], @intCast(compressed_len), .little);
                if (frame_options.block_checksum) try emitBlockChecksum(allocator, out, out.items[encoded_start..][0..compressed_len]);
            } else {
                out.items.len = encoded_start;
                std.mem.writeInt(u32, &header, 0x8000_0000 | @as(u32, @intCast(block_len)), .little);
                @memcpy(out.items[header_start..][0..4], &header);
                try out.appendSlice(allocator, block);
                if (frame_options.block_checksum) try emitBlockChecksum(allocator, out, block);
            }
            offset += block_len;
        }
        try out.appendSlice(allocator, &.{ 0, 0, 0, 0 });
        if (frame_options.content_checksum) {
            var checksum: [4]u8 = undefined;
            std.mem.writeInt(u32, &checksum, std.hash.XxHash32.hash(0, input), .little);
            try out.appendSlice(allocator, &checksum);
        }
    }

    pub fn encodeAlloc(self: *NativeFrameEncoder, input: []const u8, options: NativeFrameOptions) Error![]u8 {
        return try self.encodeWithOptionsAlloc(input, options);
    }

    pub fn encodeDefaultAlloc(self: *NativeFrameEncoder, input: []const u8) Error![]u8 {
        return try self.encodeWithOptionsAlloc(input, .{});
    }

    pub fn encodeWithOptionsAlloc(self: *NativeFrameEncoder, input: []const u8, options: NativeFrameOptions) Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(self.block_encoder.allocator);
        try self.encodeAppend(&out, input, options);
        return out.toOwnedSlice(self.block_encoder.allocator);
    }

    pub fn encodeWithDictionaryAlloc(self: *NativeFrameEncoder, input: []const u8, options: NativeFrameOptions, dictionary: NativeDictionary) Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(self.block_encoder.allocator);
        try self.encodeAppendWithDictionary(&out, input, options, dictionary);
        return out.toOwnedSlice(self.block_encoder.allocator);
    }

    pub fn encodeWithDictionarySetAlloc(self: *NativeFrameEncoder, input: []const u8, options: NativeFrameOptions, dictionary_set: NativeDictionarySet, dictionary_id: u32) Error![]u8 {
        const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
        return try self.encodeWithDictionaryAlloc(input, options, dictionary);
    }

    pub fn encodeScratch(self: *NativeFrameEncoder, input: []const u8, options: NativeFrameOptions) Error![]const u8 {
        self.output_scratch.clearRetainingCapacity();
        self.encodeAppend(&self.output_scratch, input, options) catch |err| {
            self.output_scratch.clearRetainingCapacity();
            return err;
        };
        return self.output_scratch.items;
    }

    pub fn encodeScratchWithDictionary(self: *NativeFrameEncoder, input: []const u8, options: NativeFrameOptions, dictionary: NativeDictionary) Error![]const u8 {
        self.output_scratch.clearRetainingCapacity();
        self.encodeAppendWithDictionary(&self.output_scratch, input, options, dictionary) catch |err| {
            self.output_scratch.clearRetainingCapacity();
            return err;
        };
        return self.output_scratch.items;
    }

    pub fn encodeScratchWithDictionarySet(self: *NativeFrameEncoder, input: []const u8, options: NativeFrameOptions, dictionary_set: NativeDictionarySet, dictionary_id: u32) Error![]const u8 {
        const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
        return try self.encodeScratchWithDictionary(input, options, dictionary);
    }

    pub fn encodeIntoSlice(self: *NativeFrameEncoder, input: []const u8, options: NativeFrameOptions, output: []u8) Error!usize {
        const scratch = try self.encodeScratch(input, options);
        if (output.len < scratch.len) return error.OutputTooSmall;
        @memcpy(output[0..scratch.len], scratch);
        return scratch.len;
    }

    pub fn encodeIntoSliceWithDictionary(self: *NativeFrameEncoder, input: []const u8, options: NativeFrameOptions, dictionary: NativeDictionary, output: []u8) Error!usize {
        const scratch = try self.encodeScratchWithDictionary(input, options, dictionary);
        if (output.len < scratch.len) return error.OutputTooSmall;
        @memcpy(output[0..scratch.len], scratch);
        return scratch.len;
    }

    pub fn encodeIntoSliceWithDictionarySet(self: *NativeFrameEncoder, input: []const u8, options: NativeFrameOptions, dictionary_set: NativeDictionarySet, dictionary_id: u32, output: []u8) Error!usize {
        const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
        return try self.encodeIntoSliceWithDictionary(input, options, dictionary, output);
    }
};

pub const HcFrameEncoder = struct {
    block_encoder: BlockHcEncoder,
    output_scratch: std.ArrayList(u8) = .empty,
    history: std.ArrayList(u8) = .empty,

    pub fn init(allocator: std.mem.Allocator) Error!HcFrameEncoder {
        return .{ .block_encoder = try BlockHcEncoder.init(allocator) };
    }

    pub fn deinit(self: *HcFrameEncoder) void {
        self.history.deinit(self.block_encoder.inner.allocator);
        self.output_scratch.deinit(self.block_encoder.inner.allocator);
        self.block_encoder.deinit();
        self.* = undefined;
    }

    pub fn encodeAppend(
        self: *HcFrameEncoder,
        output: *std.ArrayList(u8),
        input: []const u8,
        options: HcFrameOptions,
    ) Error!void {
        if (options.dictionary_id != null) return error.NeedDictionary;
        return self.encodeAppendWithOptionalDictionary(output, input, options, null);
    }

    pub fn encodeAppendWithDictionary(
        self: *HcFrameEncoder,
        output: *std.ArrayList(u8),
        input: []const u8,
        options: HcFrameOptions,
        dictionary: NativeDictionary,
    ) Error!void {
        if (dictionary.id == 0) return error.NeedDictionary;
        if (options.dictionary_id != null and options.dictionary_id.? != dictionary.id)
            return error.InvalidBlockPlan;
        if (options.block_mode == .independent)
            return self.encodePreparedDictionaryFrame(output, input, options, dictionary);
        return self.encodeAppendWithOptionalDictionary(output, input, options, dictionary);
    }

    fn encodeAppendWithOptionalDictionary(
        self: *HcFrameEncoder,
        output: *std.ArrayList(u8),
        input: []const u8,
        options: HcFrameOptions,
        dictionary: ?NativeDictionary,
    ) Error!void {
        const allocator = self.block_encoder.inner.allocator;
        try output.appendSlice(allocator, &frame_magic);
        const descriptor_start = output.items.len;
        var flags: u8 = 0x40;
        if (options.block_mode == .independent) flags |= 0x20;
        if (options.block_checksum) flags |= 0x10;
        if (options.include_content_size) flags |= 0x08;
        if (options.content_checksum) flags |= 0x04;
        if (dictionary != null) flags |= 0x01;
        try output.append(allocator, flags);
        try output.append(
            allocator,
            @intFromEnum(options.block_size_id) << 4,
        );
        if (options.include_content_size) {
            var content_size: [8]u8 = undefined;
            std.mem.writeInt(
                u64,
                &content_size,
                try checkedUsizeToU64(input.len),
                .little,
            );
            try output.appendSlice(allocator, &content_size);
        }
        if (dictionary) |dict| {
            var dictionary_id: [4]u8 = undefined;
            std.mem.writeInt(u32, &dictionary_id, dict.id, .little);
            try output.appendSlice(allocator, &dictionary_id);
        }
        try output.append(
            allocator,
            descriptorChecksum(output.items[descriptor_start..]),
        );

        var offset: usize = 0;
        const max_block_len = options.block_size_id.maxLen();
        self.history.clearRetainingCapacity();
        if (options.block_mode == .linked) {
            try self.history.ensureTotalCapacity(allocator, max_match_offset);
            if (dictionary) |dict| {
                const keep = @min(dict.content.len, max_match_offset);
                self.history.appendSliceAssumeCapacity(dict.content[dict.content.len - keep ..]);
            }
        }
        while (offset < input.len) {
            const block_len = @min(input.len - offset, max_block_len);
            const block = input[offset..][0..block_len];
            const prefix = if (options.block_mode == .linked)
                self.history.items
            else if (dictionary) |dict|
                dict.content
            else
                &[_]u8{};
            const encoded = try self.block_encoder.encodeScratchWithPrefix(prefix, block, options.compression_level);
            var block_header: [4]u8 = undefined;
            if (encoded.len < block.len) {
                std.mem.writeInt(u32, &block_header, @intCast(encoded.len), .little);
                try output.appendSlice(allocator, &block_header);
                try output.appendSlice(allocator, encoded);
                if (options.block_checksum) try emitBlockChecksum(allocator, output, encoded);
            } else {
                std.mem.writeInt(u32, &block_header, 0x8000_0000 | @as(u32, @intCast(block.len)), .little);
                try output.appendSlice(allocator, &block_header);
                try output.appendSlice(allocator, block);
                if (options.block_checksum) try emitBlockChecksum(allocator, output, block);
            }
            if (options.block_mode == .linked) appendHcHistory(&self.history, block);
            offset += block_len;
        }
        try output.appendSlice(allocator, &.{ 0, 0, 0, 0 });
        if (options.content_checksum) {
            var content_checksum: [4]u8 = undefined;
            std.mem.writeInt(
                u32,
                &content_checksum,
                std.hash.XxHash32.hash(0, input),
                .little,
            );
            try output.appendSlice(allocator, &content_checksum);
        }
    }

    noinline fn encodePreparedDictionaryFrame(
        self: *HcFrameEncoder,
        output: *std.ArrayList(u8),
        input: []const u8,
        options: HcFrameOptions,
        dictionary: NativeDictionary,
    ) linksection(hc_dest_size.prepared_text_section) Error!void {
        const allocator = self.block_encoder.inner.allocator;
        try output.appendSlice(allocator, &frame_magic);
        const descriptor_start = output.items.len;
        var flags: u8 = 0x40 | 0x20 | 0x01;
        if (options.block_checksum) flags |= 0x10;
        if (options.include_content_size) flags |= 0x08;
        if (options.content_checksum) flags |= 0x04;
        try output.append(allocator, flags);
        try output.append(allocator, @intFromEnum(options.block_size_id) << 4);
        if (options.include_content_size) {
            var content_size: [8]u8 = undefined;
            std.mem.writeInt(u64, &content_size, try checkedUsizeToU64(input.len), .little);
            try output.appendSlice(allocator, &content_size);
        }
        var dictionary_id: [4]u8 = undefined;
        std.mem.writeInt(u32, &dictionary_id, dictionary.id, .little);
        try output.appendSlice(allocator, &dictionary_id);
        try output.append(allocator, descriptorChecksum(output.items[descriptor_start..]));
        try self.encodePreparedDictionaryBlocks(output, input, options, dictionary);
        try output.appendSlice(allocator, &.{ 0, 0, 0, 0 });
        if (options.content_checksum) {
            var content_checksum: [4]u8 = undefined;
            std.mem.writeInt(u32, &content_checksum, std.hash.XxHash32.hash(0, input), .little);
            try output.appendSlice(allocator, &content_checksum);
        }
    }

    noinline fn encodePreparedDictionaryBlocks(
        self: *HcFrameEncoder,
        output: *std.ArrayList(u8),
        input: []const u8,
        options: HcFrameOptions,
        dictionary: NativeDictionary,
    ) linksection(hc_dest_size.prepared_text_section) Error!void {
        const allocator = self.block_encoder.inner.allocator;
        const prepared = try self.block_encoder.preparePrefixAlloc(dictionary.content);
        defer self.block_encoder.freePreparedPrefix(prepared);
        const max_block_len = options.block_size_id.maxLen();
        var offset: usize = 0;
        while (offset < input.len) {
            const block_len = @min(input.len - offset, max_block_len);
            const block = input[offset..][0..block_len];
            const encoded = try self.block_encoder.encodeScratchWithPreparedPrefix(prepared, block, options.compression_level);
            var block_header: [4]u8 = undefined;
            if (encoded.len < block.len) {
                std.mem.writeInt(u32, &block_header, @intCast(encoded.len), .little);
                try output.appendSlice(allocator, &block_header);
                try output.appendSlice(allocator, encoded);
                if (options.block_checksum) try emitBlockChecksum(allocator, output, encoded);
            } else {
                std.mem.writeInt(u32, &block_header, 0x8000_0000 | @as(u32, @intCast(block.len)), .little);
                try output.appendSlice(allocator, &block_header);
                try output.appendSlice(allocator, block);
                if (options.block_checksum) try emitBlockChecksum(allocator, output, block);
            }
            offset += block_len;
        }
    }

    pub fn encodeAlloc(
        self: *HcFrameEncoder,
        input: []const u8,
        options: HcFrameOptions,
    ) Error![]u8 {
        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(self.block_encoder.inner.allocator);
        try self.encodeAppend(&output, input, options);
        return output.toOwnedSlice(self.block_encoder.inner.allocator);
    }

    pub fn encodeAllocWithDictionary(
        self: *HcFrameEncoder,
        input: []const u8,
        options: HcFrameOptions,
        dictionary: NativeDictionary,
    ) Error![]u8 {
        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(self.block_encoder.inner.allocator);
        try self.encodeAppendWithDictionary(&output, input, options, dictionary);
        return output.toOwnedSlice(self.block_encoder.inner.allocator);
    }

    pub fn encodeScratch(
        self: *HcFrameEncoder,
        input: []const u8,
        options: HcFrameOptions,
    ) Error![]const u8 {
        self.output_scratch.clearRetainingCapacity();
        self.encodeAppend(&self.output_scratch, input, options) catch |err| {
            self.output_scratch.clearRetainingCapacity();
            return err;
        };
        return self.output_scratch.items;
    }

    pub fn encodeScratchWithDictionary(
        self: *HcFrameEncoder,
        input: []const u8,
        options: HcFrameOptions,
        dictionary: NativeDictionary,
    ) Error![]const u8 {
        self.output_scratch.clearRetainingCapacity();
        self.encodeAppendWithDictionary(&self.output_scratch, input, options, dictionary) catch |err| {
            self.output_scratch.clearRetainingCapacity();
            return err;
        };
        return self.output_scratch.items;
    }

    pub fn encodeIntoSlice(
        self: *HcFrameEncoder,
        input: []const u8,
        options: HcFrameOptions,
        output: []u8,
    ) Error!usize {
        const encoded = try self.encodeScratch(input, options);
        if (output.len < encoded.len) return error.OutputTooSmall;
        @memcpy(output[0..encoded.len], encoded);
        return encoded.len;
    }

    pub fn encodeIntoSliceWithDictionary(
        self: *HcFrameEncoder,
        input: []const u8,
        options: HcFrameOptions,
        dictionary: NativeDictionary,
        output: []u8,
    ) Error!usize {
        const encoded = try self.encodeScratchWithDictionary(input, options, dictionary);
        if (output.len < encoded.len) return error.OutputTooSmall;
        @memcpy(output[0..encoded.len], encoded);
        return encoded.len;
    }
};

fn appendHcHistory(history: *std.ArrayList(u8), block: []const u8) void {
    std.debug.assert(history.capacity >= max_match_offset);
    if (block.len >= max_match_offset) {
        history.clearRetainingCapacity();
        history.appendSliceAssumeCapacity(block[block.len - max_match_offset ..]);
        return;
    }
    const retained = @min(history.items.len, max_match_offset - block.len);
    if (retained != history.items.len)
        std.mem.copyForwards(u8, history.items[0..retained], history.items[history.items.len - retained ..]);
    history.items.len = retained;
    history.appendSliceAssumeCapacity(block);
}

pub fn encodeHcFrameAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: HcFrameOptions,
) Error![]u8 {
    var encoder = try HcFrameEncoder.init(allocator);
    defer encoder.deinit();
    return encoder.encodeAlloc(input, options);
}

pub fn encodeHcFrameAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: HcFrameOptions,
) Error!void {
    var encoder = try HcFrameEncoder.init(allocator);
    defer encoder.deinit();
    return encoder.encodeAppend(output, input, options);
}

pub fn encodeHcFrameIntoSlice(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: HcFrameOptions,
    output: []u8,
) Error!usize {
    var encoder = try HcFrameEncoder.init(allocator);
    defer encoder.deinit();
    return encoder.encodeIntoSlice(input, options, output);
}

pub fn encodeHcFrameWithDictionaryAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: HcFrameOptions,
    dictionary: NativeDictionary,
) Error![]u8 {
    var encoder = try HcFrameEncoder.init(allocator);
    defer encoder.deinit();
    return encoder.encodeAllocWithDictionary(input, options, dictionary);
}

pub fn encodeHcFrameAppendWithDictionary(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: HcFrameOptions,
    dictionary: NativeDictionary,
) Error!void {
    var encoder = try HcFrameEncoder.init(allocator);
    defer encoder.deinit();
    return encoder.encodeAppendWithDictionary(output, input, options, dictionary);
}

pub fn encodeHcFrameIntoSliceWithDictionary(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: HcFrameOptions,
    dictionary: NativeDictionary,
    output: []u8,
) Error!usize {
    var encoder = try HcFrameEncoder.init(allocator);
    defer encoder.deinit();
    return encoder.encodeIntoSliceWithDictionary(input, options, dictionary, output);
}

pub fn encodeHcFrameWithDictionarySetAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: HcFrameOptions,
    dictionary_set: NativeDictionarySet,
    dictionary_id: u32,
) Error![]u8 {
    const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
    return encodeHcFrameWithDictionaryAlloc(allocator, input, options, dictionary);
}

pub fn encodeHcFrameAppendWithDictionarySet(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: HcFrameOptions,
    dictionary_set: NativeDictionarySet,
    dictionary_id: u32,
) Error!void {
    const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
    return encodeHcFrameAppendWithDictionary(allocator, output, input, options, dictionary);
}

pub fn encodeHcFrameIntoSliceWithDictionarySet(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: HcFrameOptions,
    dictionary_set: NativeDictionarySet,
    dictionary_id: u32,
    output: []u8,
) Error!usize {
    const dictionary = try dictionaryFromSet(dictionary_set, dictionary_id);
    return encodeHcFrameIntoSliceWithDictionary(allocator, input, options, dictionary, output);
}

fn optionsWithNativeDictionary(options: NativeFrameOptions, dictionary: ?NativeDictionary) NativeFrameOptions {
    var with_dictionary = options;
    if (dictionary) |dict| with_dictionary.dictionary_id = dict.id;
    return with_dictionary;
}

pub fn encodeBlockAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return try encodeBlockWithChainDepthAlloc(allocator, input, max_chain_depth);
}

pub fn encodeBlockWithChainDepthAlloc(allocator: std.mem.Allocator, input: []const u8, chain_depth: u8) Error![]u8 {
    if (chain_depth > max_chain_depth) return error.InvalidBlockPlan;
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var occupancy_bits: []u64 = &.{};
    var hash_table: []u32 = &.{};
    var chain_table: []u32 = &.{};
    if (input.len != 0) {
        const table = try allocator.alloc(u32, hash_table_len);
        const bits = allocator.alloc(u64, hash_occupancy_words) catch |err| {
            allocator.free(table);
            return err;
        };
        const chain = allocator.alloc(u32, chain_table_len) catch |err| {
            allocator.free(bits);
            allocator.free(table);
            return err;
        };
        hash_table = table;
        occupancy_bits = bits;
        chain_table = chain;
    }
    defer {
        if (chain_table.len != 0) allocator.free(chain_table);
        if (occupancy_bits.len != 0) allocator.free(occupancy_bits);
        if (hash_table.len != 0) allocator.free(hash_table);
    }
    _ = try encodeBlockInto(allocator, &out, input, hash_table, occupancy_bits, chain_table, chain_depth);
    return out.toOwnedSlice(allocator);
}

pub fn encodeBlockWithPrefixAlloc(allocator: std.mem.Allocator, input: []const u8, prefix: []const u8) Error![]u8 {
    return try encodeBlockWithPrefixAndChainDepthAlloc(allocator, input, prefix, max_chain_depth);
}

pub fn encodeBlockWithPrefixAndChainDepthAlloc(allocator: std.mem.Allocator, input: []const u8, prefix: []const u8, chain_depth: u8) Error![]u8 {
    if (chain_depth > max_chain_depth) return error.InvalidBlockPlan;
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var occupancy_bits: []u64 = &.{};
    var hash_table: []u32 = &.{};
    var chain_table: []u32 = &.{};
    if (input.len != 0) {
        const table = try allocator.alloc(u32, hash_table_len);
        const bits = allocator.alloc(u64, hash_occupancy_words) catch |err| {
            allocator.free(table);
            return err;
        };
        const chain = allocator.alloc(u32, chain_table_len) catch |err| {
            allocator.free(bits);
            allocator.free(table);
            return err;
        };
        hash_table = table;
        occupancy_bits = bits;
        chain_table = chain;
    }
    defer {
        if (chain_table.len != 0) allocator.free(chain_table);
        if (occupancy_bits.len != 0) allocator.free(occupancy_bits);
        if (hash_table.len != 0) allocator.free(hash_table);
    }
    const history = prefix[if (prefix.len > max_match_offset) prefix.len - max_match_offset else 0..];
    _ = try encodeLinkedBlockInto(allocator, &out, history, input, hash_table, occupancy_bits, chain_table, chain_depth);
    return out.toOwnedSlice(allocator);
}

pub fn encodeBlockIntoSlice(allocator: std.mem.Allocator, input: []const u8, output: []u8) Error!usize {
    return try encodeBlockIntoSliceWithChainDepth(allocator, input, output, max_chain_depth);
}

pub fn encodeBlockIntoSliceWithChainDepth(allocator: std.mem.Allocator, input: []const u8, output: []u8, chain_depth: u8) Error!usize {
    var encoder = try BlockEncoder.init(allocator);
    defer encoder.deinit();
    return try encoder.encodeIntoSliceWithChainDepth(input, output, chain_depth);
}

pub fn encodeBlockWithPrefixIntoSlice(allocator: std.mem.Allocator, input: []const u8, prefix: []const u8, output: []u8) Error!usize {
    return try encodeBlockWithPrefixIntoSliceAndChainDepth(allocator, input, prefix, output, max_chain_depth);
}

pub fn encodeBlockWithPrefixIntoSliceAndChainDepth(allocator: std.mem.Allocator, input: []const u8, prefix: []const u8, output: []u8, chain_depth: u8) Error!usize {
    var encoder = try BlockEncoder.init(allocator);
    defer encoder.deinit();
    return try encoder.encodeWithPrefixIntoSliceAndChainDepth(input, prefix, output, chain_depth);
}

pub fn decodeBlockAlloc(allocator: std.mem.Allocator, input: []const u8, expected_size: ?usize) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try decodeBlockInto(allocator, &out, input, expected_size, &.{});
    return out.toOwnedSlice(allocator);
}

pub fn decodeBlockWithPrefixAlloc(allocator: std.mem.Allocator, input: []const u8, expected_size: ?usize, prefix: []const u8) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try decodeBlockInto(allocator, &out, input, expected_size, prefix);
    return out.toOwnedSlice(allocator);
}

pub fn decodeBlockAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, expected_size: ?usize) Error!usize {
    const decoded_len = if (expected_size) |size| size else try decodedBlockSize(input);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeBlockIntoSlice(input, slot, expected_size) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeBlockAppendLimited(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    max_output_len: usize,
) Error!usize {
    const decoded_len = try decodedBlockSizeLimited(input, max_output_len);
    return try decodeBlockAppend(allocator, out, input, decoded_len);
}

pub fn decodeBlockWithPrefixAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    expected_size: ?usize,
    prefix: []const u8,
) Error!usize {
    const decoded_len = if (expected_size) |size| size else try decodedBlockSizeWithPrefix(input, prefix);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeBlockWithPrefixIntoSliceNoAlloc(input, slot, expected_size, prefix) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeBlockWithPrefixAppendLimited(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    max_output_len: usize,
    prefix: []const u8,
) Error!usize {
    const decoded_len = try decodedBlockSizeWithPrefixLimited(input, prefix, max_output_len);
    return try decodeBlockWithPrefixAppend(allocator, out, input, decoded_len, prefix);
}

pub const BlockDecoder = struct {
    allocator: std.mem.Allocator,
    scratch: std.ArrayList(u8) = .empty,

    pub fn init(allocator: std.mem.Allocator) BlockDecoder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *BlockDecoder) void {
        self.scratch.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn decodeAlloc(self: *BlockDecoder, input: []const u8, expected_size: ?usize) Error![]u8 {
        return try decodeBlockAlloc(self.allocator, input, expected_size);
    }

    pub fn decodeWithPrefixAlloc(self: *BlockDecoder, input: []const u8, expected_size: ?usize, prefix: []const u8) Error![]u8 {
        return try decodeBlockWithPrefixAlloc(self.allocator, input, expected_size, prefix);
    }

    pub fn decodeAppend(self: *BlockDecoder, out: *std.ArrayList(u8), input: []const u8, expected_size: ?usize) Error!usize {
        return try decodeBlockAppend(self.allocator, out, input, expected_size);
    }

    pub fn decodeAppendLimited(self: *BlockDecoder, out: *std.ArrayList(u8), input: []const u8, max_output_len: usize) Error!usize {
        return try decodeBlockAppendLimited(self.allocator, out, input, max_output_len);
    }

    pub fn decodeWithPrefixAppend(self: *BlockDecoder, out: *std.ArrayList(u8), input: []const u8, expected_size: ?usize, prefix: []const u8) Error!usize {
        return try decodeBlockWithPrefixAppend(self.allocator, out, input, expected_size, prefix);
    }

    pub fn decodeWithPrefixAppendLimited(self: *BlockDecoder, out: *std.ArrayList(u8), input: []const u8, max_output_len: usize, prefix: []const u8) Error!usize {
        return try decodeBlockWithPrefixAppendLimited(self.allocator, out, input, max_output_len, prefix);
    }

    pub fn decodeScratch(self: *BlockDecoder, input: []const u8, expected_size: ?usize) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeAppend(&self.scratch, input, expected_size);
        return self.scratch.items;
    }

    pub fn decodeScratchLimited(self: *BlockDecoder, input: []const u8, max_output_len: usize) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeAppendLimited(&self.scratch, input, max_output_len);
        return self.scratch.items;
    }

    pub fn decodeWithPrefixScratch(self: *BlockDecoder, input: []const u8, expected_size: ?usize, prefix: []const u8) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeWithPrefixAppend(&self.scratch, input, expected_size, prefix);
        return self.scratch.items;
    }

    pub fn decodeWithPrefixScratchLimited(self: *BlockDecoder, input: []const u8, max_output_len: usize, prefix: []const u8) Error![]const u8 {
        self.scratch.clearRetainingCapacity();
        _ = try self.decodeWithPrefixAppendLimited(&self.scratch, input, max_output_len, prefix);
        return self.scratch.items;
    }

    pub fn decodeIntoSlice(self: *BlockDecoder, input: []const u8, output: []u8, expected_size: ?usize) Error!usize {
        _ = self;
        return try decodeBlockIntoSlice(input, output, expected_size);
    }

    pub fn decodeWithPrefixIntoSlice(self: *BlockDecoder, input: []const u8, output: []u8, expected_size: ?usize, prefix: []const u8) Error!usize {
        _ = self;
        return try decodeBlockWithPrefixIntoSliceNoAlloc(input, output, expected_size, prefix);
    }
};

pub fn decodeBlockIntoSlice(input: []const u8, output: []u8, expected_size: ?usize) Error!usize {
    var written: usize = 0;
    try decodeBlockIntoBuffer(input, output, &written, expected_size, 0);
    return written;
}

pub fn decodeBlockWithPrefixIntoSlice(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    expected_size: ?usize,
    prefix: []const u8,
) Error!usize {
    _ = allocator;
    return try decodeBlockWithPrefixIntoSliceNoAlloc(input, output, expected_size, prefix);
}

pub fn decodeBlockWithPrefixIntoSliceNoAlloc(
    input: []const u8,
    output: []u8,
    expected_size: ?usize,
    prefix: []const u8,
) Error!usize {
    const decoded_len = try decodedBlockSizeWithPrefix(input, prefix);
    if (output.len < decoded_len) return error.OutputTooSmall;
    if (expected_size) |size| {
        if (decoded_len != size) return error.SizeMismatch;
    }

    const prefix_len = @min(prefix.len, max_block_history_len);
    if (output.len - decoded_len < prefix_len) {
        // The caller buffer is large enough for the final decoded block but not
        // for the temporary history prefix needed by the current in-place
        // decoder. Fall back to an explicit byte-for-byte prefix replay instead
        // of allocating; this keeps the public decode-into contract
        // allocation-free while preserving LZ4's overlapping match semantics.
        return try decodeBlockWithExternalPrefixIntoSlice(input, output, expected_size, prefix);
    }

    @memcpy(output[0..prefix_len], prefix[prefix.len - prefix_len ..]);
    var written: usize = prefix_len;
    try decodeBlockIntoBuffer(input, output, &written, decoded_len, 0);
    std.mem.copyForwards(u8, output[0..decoded_len], output[prefix_len..][0..decoded_len]);
    return decoded_len;
}

fn decodeBlockWithExternalPrefixIntoSlice(
    input: []const u8,
    output: []u8,
    expected_size: ?usize,
    prefix: []const u8,
) Error!usize {
    var written: usize = 0;
    var offset: usize = 0;
    while (offset < input.len) {
        const token = input[offset];
        offset += 1;
        var literal_len: usize = token >> 4;
        if (literal_len == 15) literal_len = try checkedAdd(literal_len, try readLengthExtension(input, &offset));
        if (input.len - offset < literal_len) return error.TruncatedFrame;
        if (output.len - written < literal_len) return error.OutputTooSmall;
        @memcpy(output[written..][0..literal_len], input[offset..][0..literal_len]);
        written += literal_len;
        offset += literal_len;
        if (offset == input.len) break;

        if (input.len - offset < 2) return error.TruncatedFrame;
        const match_offset = std.mem.readInt(u16, input[offset..][0..2], .little);
        offset += 2;
        if (match_offset == 0 or match_offset > written + prefix.len) return error.InvalidMatch;
        var match_len: usize = (token & 0x0f) + 4;
        if ((token & 0x0f) == 15) match_len = try checkedAdd(match_len, try readLengthExtension(input, &offset));
        if (output.len - written < match_len) return error.OutputTooSmall;

        var remaining = match_len;
        if (match_offset > written) {
            const prefix_back = match_offset - written;
            const from_prefix = @min(prefix_back, remaining);
            @memcpy(output[written..][0..from_prefix], prefix[prefix.len - prefix_back ..][0..from_prefix]);
            written += from_prefix;
            remaining -= from_prefix;
            if (remaining == 0) continue;
        }

        const repeat_start = written - match_offset;
        appendMatchFromBuffer(output, &written, repeat_start, remaining);
    }
    if (expected_size) |size| {
        if (written != size) return error.SizeMismatch;
    }
    return written;
}

pub fn decodedBlockSize(input: []const u8) Error!usize {
    return try compressedBlockDecodedSizeLimited(input, 0, std.math.maxInt(usize));
}

pub fn decodedBlockSizeLimited(input: []const u8, max_output_len: usize) Error!usize {
    return try compressedBlockDecodedSizeLimited(input, 0, max_output_len);
}

pub fn summarizeBlock(input: []const u8) Error!BlockSummary {
    return try summarizeBlockLimited(input, std.math.maxInt(usize));
}

pub fn summarizeBlockLimited(input: []const u8, max_output_len: usize) Error!BlockSummary {
    return try summarizeBlockWithHistoryLimited(input, 0, 0, max_output_len);
}

pub fn decodedBlockSizeWithPrefix(input: []const u8, prefix: []const u8) Error!usize {
    return try decodedBlockSizeWithPrefixLimited(input, prefix, std.math.maxInt(usize));
}

pub fn decodedBlockSizeWithPrefixLimited(input: []const u8, prefix: []const u8, max_output_len: usize) Error!usize {
    const capped_prefix_len = @min(prefix.len, max_block_history_len);
    const total_limit = if (max_output_len == std.math.maxInt(usize))
        std.math.maxInt(usize)
    else
        std.math.add(usize, capped_prefix_len, max_output_len) catch return error.IntegerOverflow;
    const total = try compressedBlockDecodedSizeLimitedWithHistory(input, capped_prefix_len, 0, total_limit);
    return total - capped_prefix_len;
}

pub fn summarizeBlockWithPrefix(input: []const u8, prefix: []const u8) Error!BlockSummary {
    return try summarizeBlockWithPrefixLimited(input, prefix, std.math.maxInt(usize));
}

pub fn summarizeBlockWithPrefixLimited(input: []const u8, prefix: []const u8, max_output_len: usize) Error!BlockSummary {
    const capped_prefix_len = @min(prefix.len, max_block_history_len);
    const total_limit = if (max_output_len == std.math.maxInt(usize))
        std.math.maxInt(usize)
    else
        std.math.add(usize, capped_prefix_len, max_output_len) catch return error.IntegerOverflow;
    return try summarizeBlockWithHistoryLimited(input, capped_prefix_len, 0, total_limit);
}

fn decodeBlockInto(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    expected_size: ?usize,
    prefix: []const u8,
) Error!void {
    const block_start_len = out.items.len;
    if (expected_size) |size| try out.ensureUnusedCapacity(allocator, size);
    var offset: usize = 0;
    while (offset < input.len) {
        const token = input[offset];
        offset += 1;
        var literal_len: usize = token >> 4;
        if (literal_len == 15) literal_len = try checkedAdd(literal_len, try readLengthExtension(input, &offset));
        if (input.len - offset < literal_len) return error.TruncatedFrame;
        try out.appendSlice(allocator, input[offset..][0..literal_len]);
        offset += literal_len;
        if (offset == input.len) break;
        if (input.len - offset < 2) return error.TruncatedFrame;
        const match_offset = std.mem.readInt(u16, input[offset..][0..2], .little);
        offset += 2;
        if (match_offset == 0 or match_offset > (out.items.len - block_start_len) + prefix.len) return error.InvalidMatch;
        var match_len: usize = (token & 0x0f) + 4;
        if ((token & 0x0f) == 15) match_len = try checkedAdd(match_len, try readLengthExtension(input, &offset));
        try copyMatch(allocator, out, prefix, block_start_len, match_offset, match_len);
    }
    if (expected_size) |size| {
        if (out.items.len - block_start_len != size) return error.SizeMismatch;
    }
}

fn decodeBlockIntoBuffer(
    input: []const u8,
    output: []u8,
    written: *usize,
    expected_size: ?usize,
    history_start: usize,
) Error!void {
    const block_start_len = written.*;
    if (history_start > block_start_len) return error.InvalidMatch;
    if (expected_size) |size| {
        if (output.len - written.* < size) return error.OutputTooSmall;
    }

    var offset: usize = 0;
    while (offset < input.len) {
        const token = input[offset];
        offset += 1;
        var literal_len: usize = token >> 4;
        if (literal_len == 15) literal_len = try checkedAdd(literal_len, try readLengthExtension(input, &offset));
        if (input.len - offset < literal_len) return error.TruncatedFrame;
        if (output.len - written.* < literal_len) return error.OutputTooSmall;
        if (literal_len >= literal_copy.bulk_min_len and offset + literal_len == input.len) {
            literal_copy.copyBulk(output[written.*..][0..literal_len], input[offset..][0..literal_len]);
        } else {
            @memcpy(output[written.*..][0..literal_len], input[offset..][0..literal_len]);
        }
        written.* += literal_len;
        offset += literal_len;
        if (offset == input.len) break;

        if (input.len - offset < 2) return error.TruncatedFrame;
        const match_offset = std.mem.readInt(u16, input[offset..][0..2], .little);
        offset += 2;
        if (match_offset == 0 or match_offset > written.* - history_start) return error.InvalidMatch;
        var match_len: usize = (token & 0x0f) + 4;
        if ((token & 0x0f) == 15) match_len = try checkedAdd(match_len, try readLengthExtension(input, &offset));
        if (output.len - written.* < match_len) return error.OutputTooSmall;

        const repeat_start = written.* - match_offset;
        appendMatchFromBuffer(output, written, repeat_start, match_len);
    }

    if (expected_size) |size| {
        if (written.* - block_start_len != size) return error.SizeMismatch;
    }
}

fn appendMatchFromBuffer(output: []u8, written: *usize, repeat_start: usize, match_len: usize) void {
    // LZ4 matches are allowed to overlap the bytes being produced. Seed from
    // already decoded history, then repeatedly copy from the destination span
    // we just initialized. This preserves the byte-replay semantics while
    // avoiding one-byte loops for common RLE-style offsets.
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

fn copyMatch(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    prefix: []const u8,
    block_start_len: usize,
    match_offset: usize,
    match_len: usize,
) Error!void {
    try out.ensureUnusedCapacity(allocator, match_len);
    const block_len = out.items.len - block_start_len;
    if (match_offset > block_len) {
        const prefix_len = match_offset - block_len;
        const from_prefix = @min(prefix_len, match_len);
        try out.appendSlice(allocator, prefix[prefix.len - prefix_len ..][0..from_prefix]);
        const remaining = match_len - from_prefix;
        if (remaining == 0) return;
        appendMatchFromOutput(out, block_start_len, remaining);
        return;
    }

    const repeat_start = out.items.len - match_offset;
    appendMatchFromOutput(out, repeat_start, match_len);
}

fn appendMatchFromOutput(out: *std.ArrayList(u8), repeat_start: usize, match_len: usize) void {
    const initial_available = out.items.len - repeat_start;
    _ = out.addManyAsSliceAssumeCapacity(match_len);

    // LZ4 matches may overlap the destination. Instead of appending one byte at
    // a time for short periods (offset=1 run-length encodings are common), seed
    // at most one already-decoded period and then repeatedly copy from the
    // bytes we just produced. Each individual @memcpy range is non-overlapping,
    // while the copied span doubles, so long runs take O(log n) memcpy calls.
    const destination_start = out.items.len - match_len;
    var copied: usize = 0;
    while (copied < match_len) {
        const available = if (copied == 0) initial_available else copied;
        const copy_len = @min(available, match_len - copied);
        const source_start = if (copied == 0) repeat_start else destination_start;
        @memcpy(
            out.items[destination_start + copied ..][0..copy_len],
            out.items[source_start..][0..copy_len],
        );
        copied += copy_len;
    }
}

fn encodeBlockInto(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
    chain_depth: u8,
) Error!usize {
    const out_start = out.items.len;
    if (input.len == 0) return 0;
    if (table.len < hash_table_len or
        occupancy_bits.len < hash_occupancy_words or
        chain_table.len < chain_table_len or
        input.len > std.math.maxInt(u32))
    {
        return error.IntegerOverflow;
    }
    // Only clear a small occupancy bitset per block. The position table is
    // intentionally left uninitialized/reused; entries are read only when their
    // occupancy bit is set. The chain table is also initialized lazily because
    // candidates outside LZ4's 64 KiB window are never followed.
    @memset(occupancy_bits[0..hash_occupancy_words], 0);
    try out.ensureUnusedCapacity(allocator, try maxCompressedLen(input.len));

    var anchor: usize = 0;
    var index: usize = 0;
    while (block_format.hasMatchSearchRoom(index, input.len)) {
        var match_index = index;
        var best = insertAndFindBest(input, index, table, occupancy_bits, chain_table, chain_depth);
        if (best.len != 0 and index + 13 <= input.len and best.len < good_match_len) {
            const next = insertAndFindBest(input, index + 1, table, occupancy_bits, chain_table, chain_depth);
            if (next.len > best.len + lazy_extra_gain) {
                match_index = index + 1;
                best = next;
            }
        }

        if (best.len != 0) {
            var match_start = match_index;
            var candidate_start = best.start;
            var match_len = best.len;
            while (match_start > anchor and candidate_start > 0 and input[match_start - 1] == input[candidate_start - 1]) {
                match_start -= 1;
                candidate_start -= 1;
                match_len += 1;
            }
            match_len = @min(
                match_len,
                block_format.maxMatchLen(match_start, input.len),
            );
            std.debug.assert(match_len >= block_format.min_match_len);
            try emitSequence(allocator, out, input[anchor..match_start], @intCast(match_start - candidate_start), match_len);
            index = match_start + match_len;
            anchor = index;
            if (index >= input.len) break;
            const seed_start = match_start + 1;
            var seed = seed_start;
            while (seed < index and seed + 4 <= input.len) : (seed += 1) {
                _ = insertHash(input, seed, table, occupancy_bits, chain_table);
            }
        } else {
            index += 1;
        }
    }
    try emitLastLiteral(allocator, out, input[anchor..]);
    return out.items.len - out_start;
}

fn encodeLinkedBlockInto(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    history: []const u8,
    input: []const u8,
    table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
    chain_depth: u8,
) Error!usize {
    const out_start = out.items.len;
    if (input.len == 0) return 0;
    const block_start = history.len;
    const virtual_len = try checkedAdd(history.len, input.len);
    if (table.len < hash_table_len or
        occupancy_bits.len < hash_occupancy_words or
        chain_table.len < chain_table_len or
        virtual_len > std.math.maxInt(u32))
    {
        return error.IntegerOverflow;
    }

    @memset(occupancy_bits[0..hash_occupancy_words], 0);
    try out.ensureUnusedCapacity(allocator, try maxCompressedLen(input.len));

    // Linked LZ4 blocks may reference the previous 64 KiB of decoded frame
    // history. Seed that prefix into the same bounded hash-chain tables used by
    // independent blocks, then emit only sequences whose literals live in the
    // current block. Candidate positions near the history/block boundary are
    // intentionally allowed to hash across the boundary: the decoder can replay
    // such matches by copying the history bytes first and then overlapping with
    // the output it just produced.
    var seed: usize = 0;
    while (seed < block_start and seed + 4 <= virtual_len) : (seed += 1) {
        _ = insertLinkedHash(history, input, seed, table, occupancy_bits, chain_table);
    }

    var anchor: usize = block_start;
    var index: usize = block_start;
    while (block_format.hasMatchSearchRoom(index, virtual_len)) {
        var match_index = index;
        var best = insertAndFindBestLinked(history, input, index, table, occupancy_bits, chain_table, chain_depth);
        if (best.len != 0 and index + 13 <= virtual_len and best.len < good_match_len) {
            const next = insertAndFindBestLinked(history, input, index + 1, table, occupancy_bits, chain_table, chain_depth);
            if (next.len > best.len + lazy_extra_gain) {
                match_index = index + 1;
                best = next;
            }
        }

        if (best.len != 0) {
            var match_start = match_index;
            var candidate_start = best.start;
            var match_len = best.len;
            while (match_start > anchor and candidate_start > 0 and linkedByteAt(history, input, match_start - 1) == linkedByteAt(history, input, candidate_start - 1)) {
                match_start -= 1;
                candidate_start -= 1;
                match_len += 1;
            }
            match_len = @min(
                match_len,
                block_format.maxMatchLen(match_start, virtual_len),
            );
            std.debug.assert(match_len >= block_format.min_match_len);
            const literal_start = anchor - block_start;
            const literal_end = match_start - block_start;
            try emitSequence(
                allocator,
                out,
                input[literal_start..literal_end],
                @intCast(match_start - candidate_start),
                match_len,
            );
            index = match_start + match_len;
            anchor = index;
            if (index >= virtual_len) break;
            seed = match_start + 1;
            while (seed < index and seed + 4 <= virtual_len) : (seed += 1) {
                _ = insertLinkedHash(history, input, seed, table, occupancy_bits, chain_table);
            }
        } else {
            index += 1;
        }
    }

    try emitLastLiteral(allocator, out, input[anchor - block_start ..]);
    return out.items.len - out_start;
}

fn insertAndFindBest(
    input: []const u8,
    index: usize,
    table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
    chain_depth: usize,
) Match {
    const candidate_entry = insertHash(input, index, table, occupancy_bits, chain_table);

    var best: Match = .{};
    var candidate = candidate_entry;
    var depth: usize = 0;
    while (candidate != invalid_pos and depth < chain_depth) : (depth += 1) {
        const candidate_start: usize = @intCast(candidate);
        if (candidate_start >= index) break;
        if (index - candidate_start > max_match_offset) break;
        if (input[candidate_start] == input[index] and
            input[candidate_start + 1] == input[index + 1] and
            input[candidate_start + 2] == input[index + 2] and
            input[candidate_start + 3] == input[index + 3])
        {
            var match_len: usize = 4;
            while (index + match_len < input.len and input[candidate_start + match_len] == input[index + match_len]) {
                match_len += 1;
            }
            if (match_len > best.len) {
                best = .{ .start = candidate_start, .len = match_len };
                if (match_len >= good_match_len) break;
            }
        }
        candidate = chain_table[candidate_start & chain_table_mask];
    }
    return best;
}

fn insertAndFindBestLinked(
    history: []const u8,
    input: []const u8,
    index: usize,
    table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
    chain_depth: usize,
) Match {
    const virtual_len = history.len + input.len;
    const candidate_entry = insertLinkedHash(history, input, index, table, occupancy_bits, chain_table);

    var best: Match = .{};
    var candidate = candidate_entry;
    var depth: usize = 0;
    while (candidate != invalid_pos and depth < chain_depth) : (depth += 1) {
        const candidate_start: usize = @intCast(candidate);
        if (candidate_start >= index) break;
        if (index - candidate_start > max_match_offset) break;
        if (linkedByteAt(history, input, candidate_start) == linkedByteAt(history, input, index) and
            linkedByteAt(history, input, candidate_start + 1) == linkedByteAt(history, input, index + 1) and
            linkedByteAt(history, input, candidate_start + 2) == linkedByteAt(history, input, index + 2) and
            linkedByteAt(history, input, candidate_start + 3) == linkedByteAt(history, input, index + 3))
        {
            var match_len: usize = 4;
            while (index + match_len < virtual_len and linkedByteAt(history, input, candidate_start + match_len) == linkedByteAt(history, input, index + match_len)) {
                match_len += 1;
            }
            if (match_len > best.len) {
                best = .{ .start = candidate_start, .len = match_len };
                if (match_len >= good_match_len) break;
            }
        }
        candidate = chain_table[candidate_start & chain_table_mask];
    }
    return best;
}

fn insertHash(
    input: []const u8,
    index: usize,
    table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
) u32 {
    const h = hash4(input[index..][0..4]);
    const candidate_seen = hashOccupied(occupancy_bits, h);
    const candidate_entry = if (candidate_seen) table[h] else invalid_pos;
    markHashOccupied(occupancy_bits, h);

    // Lazy matching can probe index+1 before knowing whether the current match
    // wins; back-extension and seeding can later revisit the same index. Avoid
    // turning that ring slot into a self-loop that wastes bounded chain depth.
    if (candidate_entry == index) return chain_table[index & chain_table_mask];

    table[h] = @intCast(index);
    chain_table[index & chain_table_mask] = candidate_entry;
    return candidate_entry;
}

fn insertLinkedHash(
    history: []const u8,
    input: []const u8,
    index: usize,
    table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
) u32 {
    const h = hashLinked4(history, input, index);
    const candidate_seen = hashOccupied(occupancy_bits, h);
    const candidate_entry = if (candidate_seen) table[h] else invalid_pos;
    markHashOccupied(occupancy_bits, h);

    if (candidate_entry == index) return chain_table[index & chain_table_mask];

    table[h] = @intCast(index);
    chain_table[index & chain_table_mask] = candidate_entry;
    return candidate_entry;
}

fn maxCompressedLen(input_len: usize) Error!usize {
    return try checkedAdd(try checkedAdd(input_len, input_len / 255), 16);
}

fn hashOccupied(occupancy_bits: []const u64, hash: usize) bool {
    const word = hash >> 6;
    const bit: u6 = @intCast(hash & 63);
    return (occupancy_bits[word] & (@as(u64, 1) << bit)) != 0;
}

fn markHashOccupied(occupancy_bits: []u64, hash: usize) void {
    const word = hash >> 6;
    const bit: u6 = @intCast(hash & 63);
    occupancy_bits[word] |= @as(u64, 1) << bit;
}

test "LZ4HC public block APIs round trip levels and preserve caller output" {
    const allocator = std.testing.allocator;
    const payload = "public LZ4HC block API with repeated structured bytes\n" ** 256;
    var reusable = try BlockHcEncoder.init(allocator);
    defer reusable.deinit();
    inline for (.{ @as(i32, 0), 1, 3, 5, 9, 10, 11, 12, 99 }) |level| {
        const encoded = try reusable.encodeAlloc(payload, level);
        defer allocator.free(encoded);
        const decoded = try decodeBlockAlloc(allocator, encoded, payload.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
        var into: [4096]u8 = undefined;
        const written = try reusable.encodeIntoSlice(payload, &into, level);
        try std.testing.expectEqualSlices(u8, encoded, into[0..written]);
        try std.testing.expectError(
            error.OutputTooSmall,
            reusable.encodeIntoSlice(payload, into[0 .. written - 1], level),
        );
    }
}

test "LZ4HC independent frames round trip checksums blocks and caller output" {
    const allocator = std.testing.allocator;
    const payload = ("LZ4HC independent frame block boundary payload\n" ** 2048) ++
        ([_]u8{0xa5} ** 70_000);
    var encoder = try HcFrameEncoder.init(allocator);
    defer encoder.deinit();
    const options = HcFrameOptions{
        .include_content_size = true,
        .content_checksum = true,
        .block_checksum = true,
        .block_size_id = .max64kb,
        .compression_level = 12,
    };
    const encoded = try encoder.encodeAlloc(payload, options);
    defer allocator.free(encoded);
    try std.testing.expect(encoded.len <= try encodedHcFrameBound(payload.len, options));
    const header = try inspectNativeFrameHeader(encoded);
    try std.testing.expect(header.block_independent);
    try std.testing.expect(header.block_checksum);
    try std.testing.expect(header.content_checksum);
    const decoded = try decodeFrameAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    const into = try allocator.alloc(u8, try encodedHcFrameBound(payload.len, options));
    defer allocator.free(into);
    const written = try encoder.encodeIntoSlice(payload, options, into);
    try std.testing.expectEqualSlices(u8, encoded, into[0..written]);
    try std.testing.expectError(
        error.OutputTooSmall,
        encoder.encodeIntoSlice(payload, options, into[0 .. written - 1]),
    );
}

test "LZ4HC linked frames reuse the previous block window" {
    const allocator = std.testing.allocator;
    const block_len = 64 * 1024;
    const payload = try allocator.alloc(u8, block_len * 2);
    defer allocator.free(payload);
    var state: u32 = 0x243f_6a88;
    for (payload[0..block_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(payload[block_len..][0 .. block_len - 1], payload[1..block_len]);
    payload[payload.len - 1] = payload[0] ^ 0xa5;

    var encoder = try HcFrameEncoder.init(allocator);
    defer encoder.deinit();
    const linked_options = HcFrameOptions{
        .block_size_id = .max64kb,
        .block_mode = .linked,
        .compression_level = 9,
        .block_checksum = true,
    };
    const linked = try encoder.encodeAlloc(payload, linked_options);
    defer allocator.free(linked);
    const independent = try encoder.encodeAlloc(payload, .{
        .block_size_id = .max64kb,
        .compression_level = 9,
        .block_checksum = true,
    });
    defer allocator.free(independent);
    try std.testing.expect(linked.len + block_len / 2 < independent.len);

    const header = try inspectNativeFrameHeader(linked);
    try std.testing.expect(!header.block_independent);
    const summary = try summarizeNativeFrameBlocks(linked);
    try std.testing.expectEqual(@as(usize, 2), summary.block_count);
    const first = (try inspectNativeFrameFirstBlock(linked)).?;
    const second = (try inspectNativeFrameBlockAt(linked, first.next_header_offset)).?;
    try std.testing.expect(second.is_compressed);

    const decoded = try decodeNativeFrameAlloc(allocator, linked);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "LZ4HC preset dictionary frames expose ID and caller-owned output" {
    const allocator = std.testing.allocator;
    const dictionary_bytes = try allocator.alloc(u8, 64 * 1024);
    defer allocator.free(dictionary_bytes);
    var state: u32 = 0x9e37_79b9;
    for (dictionary_bytes) |*byte| {
        state = state *% 22_695_477 +% 1;
        byte.* = @truncate(state >> 22);
    }
    const payload = try allocator.alloc(u8, dictionary_bytes.len);
    defer allocator.free(payload);
    @memcpy(payload[0 .. payload.len - 1], dictionary_bytes[1..]);
    payload[payload.len - 1] = dictionary_bytes[0] ^ 0x5a;
    const dictionary = NativeDictionary.init(0x3141_5926, dictionary_bytes);
    const options = HcFrameOptions{
        .block_size_id = .max64kb,
        .block_mode = .linked,
        .compression_level = 9,
        .dictionary_id = dictionary.id,
    };

    var encoder = try HcFrameEncoder.init(allocator);
    defer encoder.deinit();
    const encoded_block = try encodeBlockHcWithPrefixAlloc(allocator, dictionary.content, payload, options.compression_level);
    defer allocator.free(encoded_block);
    const decoded_block = try decodeBlockWithPrefixAlloc(allocator, encoded_block, payload.len, dictionary.content);
    defer allocator.free(decoded_block);
    try std.testing.expectEqualSlices(u8, payload, decoded_block);

    const encoded = try encoder.encodeAllocWithDictionary(payload, options, dictionary);
    defer allocator.free(encoded);
    try std.testing.expect(encoded.len < payload.len / 2);
    const header = try inspectNativeFrameHeader(encoded);
    try std.testing.expectEqual(dictionary.id, header.dictionary_id.?);
    try std.testing.expect(!header.block_independent);
    try std.testing.expectError(error.NeedDictionary, decodeNativeFrameAlloc(allocator, encoded));

    const decoded = try decodeNativeFrameAllocWithDictionary(allocator, encoded, dictionary);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const output = try allocator.alloc(u8, try encodedHcFrameBoundWithDictionary(payload.len, options, dictionary));
    defer allocator.free(output);
    const written = try encoder.encodeIntoSliceWithDictionary(payload, options, dictionary, output);
    try std.testing.expectEqualSlices(u8, encoded, output[0..written]);
    const dictionary_set = try NativeDictionarySet.initChecked(&.{dictionary});
    try std.testing.expectEqual(
        try encodedHcFrameBoundWithDictionary(payload.len, options, dictionary),
        try encodedHcFrameBoundWithDictionarySet(payload.len, options, dictionary_set, dictionary.id),
    );
    const set_encoded = try encodeHcFrameWithDictionarySetAlloc(allocator, payload, options, dictionary_set, dictionary.id);
    defer allocator.free(set_encoded);
    try std.testing.expectEqualSlices(u8, encoded, set_encoded);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try encodeHcFrameAppendWithDictionarySet(allocator, &appended, payload, options, dictionary_set, dictionary.id);
    try std.testing.expectEqualSlices(u8, encoded, appended.items);
    const set_output = try allocator.alloc(u8, output.len);
    defer allocator.free(set_output);
    const set_written = try encodeHcFrameIntoSliceWithDictionarySet(allocator, payload, options, dictionary_set, dictionary.id, set_output);
    try std.testing.expectEqualSlices(u8, encoded, set_output[0..set_written]);
    try std.testing.expectError(error.NeedDictionary, encodeHcFrameWithDictionarySetAlloc(
        allocator,
        payload,
        options,
        dictionary_set,
        dictionary.id + 1,
    ));
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeAllocWithDictionary(
        payload,
        .{ .dictionary_id = dictionary.id + 1 },
        dictionary,
    ));
}

test "LZ4HC reusable encoders release every workspace allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const payload = "allocation-safe public LZ4HC APIs" ** 64;
            var block_encoder = try BlockHcEncoder.init(allocator);
            defer block_encoder.deinit();
            const block = try block_encoder.encodeAlloc(payload, 12);
            defer allocator.free(block);
            var frame_encoder = try HcFrameEncoder.init(allocator);
            defer frame_encoder.deinit();
            const frame = try frame_encoder.encodeAlloc(payload, .{
                .compression_level = 12,
            });
            defer allocator.free(frame);
            const dictionary = NativeDictionary.init(7, "allocation-safe HC dictionary prefix");
            const dictionary_frame = try frame_encoder.encodeAllocWithDictionary(payload, .{
                .block_mode = .linked,
                .dictionary_id = dictionary.id,
                .compression_level = 12,
            }, dictionary);
            defer allocator.free(dictionary_frame);
            const independent_dictionary_frame = try frame_encoder.encodeAllocWithDictionary(payload, .{
                .block_mode = .independent,
                .dictionary_id = dictionary.id,
                .compression_level = 12,
            }, dictionary);
            defer allocator.free(independent_dictionary_frame);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{},
    );
}

fn hash4(bytes: *const [4]u8) usize {
    const value = std.mem.readInt(u32, bytes, .little);
    return @intCast((value *% 2654435761) >> 16);
}

fn hashLinked4(history: []const u8, input: []const u8, index: usize) usize {
    var bytes: [4]u8 = undefined;
    inline for (0..4) |i| bytes[i] = linkedByteAt(history, input, index + i);
    return hash4(&bytes);
}

fn linkedByteAt(history: []const u8, input: []const u8, index: usize) u8 {
    return if (index < history.len) history[index] else input[index - history.len];
}

fn emitSequence(allocator: std.mem.Allocator, out: *std.ArrayList(u8), literal: []const u8, match_offset: u16, match_len: usize) Error!void {
    const token_index = out.items.len;
    try out.append(allocator, 0);
    var token: u8 = 0;
    if (literal.len < 15) {
        token |= @intCast(literal.len << 4);
    } else {
        token |= 15 << 4;
        try writeLengthExtension(allocator, out, literal.len - 15);
    }
    try out.appendSlice(allocator, literal);
    var offset_bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &offset_bytes, match_offset, .little);
    try out.appendSlice(allocator, &offset_bytes);

    const encoded_match_len = match_len - 4;
    if (encoded_match_len < 15) {
        token |= @intCast(encoded_match_len);
    } else {
        token |= 15;
        try writeLengthExtension(allocator, out, encoded_match_len - 15);
    }
    out.items[token_index] = token;
}

fn emitLastLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), literal: []const u8) Error!void {
    if (literal.len == 0) return;
    const token_index = out.items.len;
    try out.append(allocator, 0);
    if (literal.len < 15) {
        out.items[token_index] = @intCast(literal.len << 4);
    } else {
        out.items[token_index] = 15 << 4;
        try writeLengthExtension(allocator, out, literal.len - 15);
    }
    try out.appendSlice(allocator, literal);
}

fn writeLengthExtension(allocator: std.mem.Allocator, out: *std.ArrayList(u8), extra_len: usize) Error!void {
    var remaining = extra_len;
    while (remaining >= 255) : (remaining -= 255) try out.append(allocator, 255);
    try out.append(allocator, @intCast(remaining));
}

fn readLengthExtension(input: []const u8, offset: *usize) Error!usize {
    // Keep the common short-extension loop inline and identical to the compact
    // parser. Only cold, stored-like runs pay the out-of-line vector scanner.
    if (input.len - offset.* >= 4096 and
        std.mem.readInt(u32, input[offset.*..][0..4], .little) == std.math.maxInt(u32))
    {
        return try length.readLongExtension(input, offset);
    }
    var len: usize = 0;
    while (true) {
        if (offset.* >= input.len) return error.TruncatedFrame;
        const byte = input[offset.*];
        offset.* += 1;
        len = try checkedAdd(len, byte);
        if (byte != 255) return len;
    }
}

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch return error.IntegerOverflow;
}

fn checkedAddWithinLimit(current: usize, additional: usize, max: usize) Error!usize {
    const next = std.math.add(usize, current, additional) catch return error.IntegerOverflow;
    if (next > max) return error.OutputLimitExceeded;
    return next;
}

fn checkedU64ToUsize(value: u64) Error!usize {
    return std.math.cast(usize, value) orelse error.IntegerOverflow;
}

fn checkedUsizeToU32(value: usize) Error!u32 {
    return std.math.cast(u32, value) orelse error.IntegerOverflow;
}

fn checkedUsizeToU64(value: usize) Error!u64 {
    return std.math.cast(u64, value) orelse error.IntegerOverflow;
}

test "lz4 frame encoder round trips and compresses repetitive payloads" {
    const repeated = "payload payload payload payload payload payload payload payload";
    const encoded = try encodeFrameAlloc(std.testing.allocator, repeated);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len < repeated.len);
    const decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, repeated, decoded);
    try std.testing.expectEqual(repeated.len, try decodedFrameSize(encoded));
    const limited_decoded = try decodeFrameAllocLimited(std.testing.allocator, encoded, repeated.len);
    defer std.testing.allocator.free(limited_decoded);
    try std.testing.expectEqualSlices(u8, repeated, limited_decoded);
    try std.testing.expectError(error.OutputLimitExceeded, decodeFrameAllocLimited(std.testing.allocator, encoded, repeated.len - 1));
    var into_buffer: [repeated.len]u8 = undefined;
    const into_written = try decodeFrameInto(encoded, &into_buffer);
    try std.testing.expectEqual(repeated.len, into_written);
    try std.testing.expectEqualSlices(u8, repeated, into_buffer[0..into_written]);

    const no_content_fields = try encodeFrameWithLevelAndOptionsAlloc(
        std.testing.allocator,
        repeated,
        4,
        .{
            .include_content_size = false,
            .content_checksum = false,
            .block_size_id = .max64kb,
        },
    );
    defer std.testing.allocator.free(no_content_fields);
    const no_content_header = try inspectNativeFrameHeader(no_content_fields);
    try std.testing.expect(!no_content_header.block_independent);
    try std.testing.expect(!no_content_header.content_checksum);
    try std.testing.expectEqual(@as(?u64, null), no_content_header.expected_content_size);
    try std.testing.expectEqual(@as(usize, 64 * 1024), no_content_header.block_size_max);
    const no_content_decoded = try decodeFrameAlloc(std.testing.allocator, no_content_fields);
    defer std.testing.allocator.free(no_content_decoded);
    try std.testing.expectEqualSlices(u8, repeated, no_content_decoded);
    try std.testing.expectEqual(repeated.len, try decodedFrameSize(no_content_fields));
}

test "lz4 pure Zig facade generated corpus shapes" {
    var sequential: [5000]u8 = undefined;
    for (&sequential, 0..) |*byte, i| byte.* = @intCast(i % 251);

    var randomish: [5000]u8 = undefined;
    var rng = std.Random.DefaultPrng.init(2);
    for (&randomish) |*byte| byte.* = rng.random().int(u8);

    const json_unit = "{\"key\":\"value\",\"number\":123,\"array\":[1,2,3],\"text\":\"abcdefg\"}\n";
    const cases = [_][]const u8{
        "abcd" ** 1000,
        &sequential,
        &randomish,
        json_unit ** 200,
        ("a" ** 100 ++ "b" ** 100 ++ "c" ** 100) ** 20,
    };
    const levels = [_]c_int{ 0, 4, default_compression_level };
    const option_sets = [_]FrameOptions{
        .{},
        .{ .include_content_size = false },
        .{ .content_checksum = false, .block_checksum = true, .block_size_id = .max64kb },
        .{ .content_checksum = true, .block_checksum = true, .block_mode = .independent, .block_size_id = .max256kb },
    };

    for (cases) |payload| {
        for (levels) |level| {
            for (option_sets) |options| {
                const encoded = try encodeFrameWithLevelAndOptionsAlloc(std.testing.allocator, payload, level, options);
                defer std.testing.allocator.free(encoded);

                const decoded = try decodeFrameAllocLimited(std.testing.allocator, encoded, payload.len);
                defer std.testing.allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, payload, decoded);

                const into = try std.testing.allocator.alloc(u8, payload.len);
                defer std.testing.allocator.free(into);
                const written = try decodeFrameInto(encoded, into);
                try std.testing.expectEqual(payload.len, written);
                try std.testing.expectEqualSlices(u8, payload, into[0..written]);

                try std.testing.expectEqual(payload.len, try decodedFrameSizeLimited(encoded, payload.len));
                try std.testing.expectError(error.OutputLimitExceeded, decodedFrameSizeLimited(encoded, payload.len - 1));
            }
        }
    }
}

test "lz4 pure Zig facade maps levels to native chain depth" {
    try std.testing.expectEqual(@as(u8, 0), nativeChainDepthForLevel(0));
    try std.testing.expectEqual(@as(u8, 0), nativeChainDepthForLevel(-1));
    try std.testing.expectEqual(@as(u8, 1), nativeChainDepthForLevel(1));
    try std.testing.expectEqual(@as(u8, 4), nativeChainDepthForLevel(4));
    try std.testing.expectEqual(native_max_chain_depth, nativeChainDepthForLevel(default_compression_level));
    try std.testing.expectEqual(native_max_chain_depth, nativeChainDepthForLevel(default_compression_level + 10));

    const payload = "abcdefabcdefabcdefabcdef" ** 64;
    const fastest = try encodeFrameWithLevelAlloc(std.testing.allocator, payload, 0);
    defer std.testing.allocator.free(fastest);
    const default_encoded = try encodeFrameWithLevelAlloc(std.testing.allocator, payload, default_compression_level);
    defer std.testing.allocator.free(default_encoded);

    const fastest_summary = try summarizeNativeFrameBlocks(fastest);
    try std.testing.expectEqual(@as(usize, 0), fastest_summary.compressed_block_count);
    const default_summary = try summarizeNativeFrameBlocks(default_encoded);
    try std.testing.expect(default_summary.compressed_block_count > 0);
    try std.testing.expect(default_encoded.len < fastest.len);

    const decoded = try decodeFrameAlloc(std.testing.allocator, fastest);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "lz4 hash-chain finder reaches deeper long candidates" {
    var payload: [160]u8 = undefined;
    @memset(&payload, 'z');
    const long = "AAAABCDEFGHIJKLMNOP";
    const target_start = 120;
    @memcpy(payload[0..long.len], long);
    @memcpy(payload[target_start..][0..long.len], long);

    // All of these candidates share the same four-byte hash prefix as the
    // target, but they diverge immediately after it. The useful long match at
    // offset 0 is deliberately older than the previous depth-8 chain cap.
    for (0..12) |i| {
        const pos = 24 + i * 6;
        @memcpy(payload[pos..][0..4], "AAAA");
        payload[pos + 4] = @intCast('a' + i);
    }

    var table: [hash_table_len]u32 = undefined;
    var occupancy_bits: [hash_occupancy_words]u64 = undefined;
    var chain_table: [chain_table_len]u32 = undefined;
    @memset(&occupancy_bits, 0);

    _ = insertHash(&payload, 0, &table, &occupancy_bits, &chain_table);
    for (0..12) |i| {
        _ = insertHash(&payload, 24 + i * 6, &table, &occupancy_bits, &chain_table);
    }
    const shallow = insertAndFindBest(&payload, target_start, &table, &occupancy_bits, &chain_table, 8);
    try std.testing.expect(shallow.start != 0);
    const best = insertAndFindBest(&payload, target_start, &table, &occupancy_bits, &chain_table, max_chain_depth);
    try std.testing.expectEqual(@as(usize, 0), best.start);
    try std.testing.expect(best.len >= long.len);
}

test "lz4 linked hash-chain finder reaches deeper history candidates" {
    var history: [120]u8 = undefined;
    @memset(&history, 'h');
    const long = "AAAABCDEFGHIJKLMNOP";
    @memcpy(history[0..long.len], long);
    for (0..12) |i| {
        const pos = 24 + i * 6;
        @memcpy(history[pos..][0..4], "AAAA");
        history[pos + 4] = @intCast('a' + i);
    }

    var input: [long.len]u8 = undefined;
    @memcpy(&input, long);
    var table: [hash_table_len]u32 = undefined;
    var occupancy_bits: [hash_occupancy_words]u64 = undefined;
    var chain_table: [chain_table_len]u32 = undefined;
    @memset(&occupancy_bits, 0);

    _ = insertLinkedHash(&history, &input, 0, &table, &occupancy_bits, &chain_table);
    for (0..12) |i| {
        _ = insertLinkedHash(&history, &input, 24 + i * 6, &table, &occupancy_bits, &chain_table);
    }
    const shallow = insertAndFindBestLinked(&history, &input, history.len, &table, &occupancy_bits, &chain_table, 8);
    try std.testing.expect(shallow.start != 0);
    const best = insertAndFindBestLinked(&history, &input, history.len, &table, &occupancy_bits, &chain_table, max_chain_depth);
    try std.testing.expectEqual(@as(usize, 0), best.start);
    try std.testing.expect(best.len >= long.len);
}

test "lz4 native frame validates chain depth option" {
    var payload: [160]u8 = undefined;
    @memset(&payload, 'z');
    const long = "AAAABCDEFGHIJKLMNOP";
    const target_start = 120;
    @memcpy(payload[0..long.len], long);
    @memcpy(payload[target_start..][0..long.len], long);
    for (0..12) |i| {
        const pos = 24 + i * 6;
        @memcpy(payload[pos..][0..4], "AAAA");
        payload[pos + 4] = @intCast('a' + i);
    }

    try std.testing.expectError(error.InvalidBlockPlan, encodeNativeFrameWithOptionsAlloc(std.testing.allocator, &payload, .{
        .chain_depth = max_chain_depth + 1,
    }));

    const encoded = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, &payload, .{
        .content_checksum = false,
        .chain_depth = max_chain_depth,
    });
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
}

test "lz4 block encoder exposes chain depth helpers" {
    var payload: [160]u8 = undefined;
    @memset(&payload, 'z');
    const long = "AAAABCDEFGHIJKLMNOP";
    const target_start = 120;
    @memcpy(payload[0..long.len], long);
    @memcpy(payload[target_start..][0..long.len], long);
    for (0..12) |i| {
        const pos = 24 + i * 6;
        @memcpy(payload[pos..][0..4], "AAAA");
        payload[pos + 4] = @intCast('a' + i);
    }

    var encoder = try BlockEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    const encoded = try encoder.encodeScratchWithChainDepth(&payload, max_chain_depth);
    const decoded = try decodeBlockAlloc(std.testing.allocator, encoded, payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);

    const out = try std.testing.allocator.alloc(u8, try encodedBlockBound(payload.len));
    defer std.testing.allocator.free(out);
    const written = try encoder.encodeIntoSliceWithChainDepth(&payload, out, max_chain_depth);
    try std.testing.expectEqualSlices(u8, encoded, out[0..written]);
    try std.testing.expectError(error.OutputTooSmall, encoder.encodeIntoSliceWithChainDepth(&payload, out[0 .. written - 1], max_chain_depth));
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeScratchWithChainDepth(&payload, max_chain_depth + 1));

    var history: [120]u8 = undefined;
    @memset(&history, 'h');
    @memcpy(history[0..long.len], long);
    for (0..12) |i| {
        const pos = 24 + i * 6;
        @memcpy(history[pos..][0..4], "AAAA");
        history[pos + 4] = @intCast('a' + i);
    }
    var input: [long.len]u8 = undefined;
    @memcpy(&input, long);
    const linked = try encoder.encodeWithPrefixScratchAndChainDepth(&input, &history, max_chain_depth);
    const linked_decoded = try decodeBlockWithPrefixAlloc(std.testing.allocator, linked, input.len, &history);
    defer std.testing.allocator.free(linked_decoded);
    try std.testing.expectEqualSlices(u8, &input, linked_decoded);
    const linked_written = try encoder.encodeWithPrefixIntoSliceAndChainDepth(&input, &history, out, max_chain_depth);
    try std.testing.expectEqualSlices(u8, linked, out[0..linked_written]);
}

test "lz4 frame encoder compresses repetitive payloads and round trips" {
    const repeated = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const encoded = try encodePureFrameAlloc(std.testing.allocator, repeated);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len < repeated.len);
    try std.testing.expect(encoded.len <= try encodedNativeFrameBound(repeated.len));
    var appended_frame: std.ArrayList(u8) = .empty;
    defer appended_frame.deinit(std.testing.allocator);
    try encodeNativeFrameAppend(std.testing.allocator, &appended_frame, repeated, .{});
    try std.testing.expectEqualSlices(u8, encoded, appended_frame.items);
    var reusable_frame_encoder = try NativeFrameEncoder.init(std.testing.allocator);
    defer reusable_frame_encoder.deinit();
    var reusable_frame: std.ArrayList(u8) = .empty;
    defer reusable_frame.deinit(std.testing.allocator);
    try reusable_frame_encoder.encodeAppend(&reusable_frame, repeated, .{});
    try std.testing.expectEqualSlices(u8, encoded, reusable_frame.items);
    const reusable_owned = try reusable_frame_encoder.encodeWithOptionsAlloc(repeated, .{});
    defer std.testing.allocator.free(reusable_owned);
    try std.testing.expectEqualSlices(u8, encoded, reusable_owned);
    const reusable_encoded_scratch = try reusable_frame_encoder.encodeScratch(repeated, .{});
    try std.testing.expectEqualSlices(u8, encoded, reusable_encoded_scratch);
    const frame_bound = try encodedNativeFrameBound(repeated.len);
    const reusable_into = try std.testing.allocator.alloc(u8, frame_bound);
    defer std.testing.allocator.free(reusable_into);
    const reusable_into_written = try reusable_frame_encoder.encodeIntoSlice(repeated, .{}, reusable_into);
    try std.testing.expectEqualSlices(u8, encoded, reusable_into[0..reusable_into_written]);
    try std.testing.expectError(error.OutputTooSmall, reusable_frame_encoder.encodeIntoSlice(repeated, .{}, reusable_into[0 .. reusable_into_written - 1]));
    const encoded_into = try std.testing.allocator.alloc(u8, frame_bound);
    defer std.testing.allocator.free(encoded_into);
    const frame_written = try encodeNativeFrameIntoSlice(std.testing.allocator, repeated, .{}, encoded_into);
    try std.testing.expectEqualSlices(u8, encoded, encoded_into[0..frame_written]);
    try std.testing.expectError(error.OutputTooSmall, encodeNativeFrameIntoSlice(std.testing.allocator, repeated, .{}, encoded_into[0 .. frame_written - 1]));
    const decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, repeated, decoded);
    const exact_decoded = try decodeNativeFrameAllocExactSize(std.testing.allocator, encoded, repeated.len);
    defer std.testing.allocator.free(exact_decoded);
    try std.testing.expectEqualSlices(u8, repeated, exact_decoded);
    try std.testing.expectError(error.SizeMismatch, decodeNativeFrameAllocExactSize(std.testing.allocator, encoded, repeated.len - 1));
    try std.testing.expectError(error.SizeMismatch, decodeNativeFrameAllocExactSize(std.testing.allocator, encoded, repeated.len + 1));
    var decoded_appended: std.ArrayList(u8) = .empty;
    defer decoded_appended.deinit(std.testing.allocator);
    try decoded_appended.appendSlice(std.testing.allocator, "prefix:");
    const decoded_appended_written = try decodeNativeFrameAppend(std.testing.allocator, &decoded_appended, encoded);
    try std.testing.expectEqual(repeated.len, decoded_appended_written);
    try std.testing.expectEqualSlices(u8, "prefix:", decoded_appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, repeated, decoded_appended.items["prefix:".len..]);
    decoded_appended.clearRetainingCapacity();
    try decoded_appended.appendSlice(std.testing.allocator, "prefix:");
    const decoded_appended_limited_written = try decodeNativeFrameAppendLimited(std.testing.allocator, &decoded_appended, encoded, repeated.len);
    try std.testing.expectEqual(repeated.len, decoded_appended_limited_written);
    try std.testing.expectEqualSlices(u8, "prefix:", decoded_appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, repeated, decoded_appended.items["prefix:".len..]);
    decoded_appended.clearRetainingCapacity();
    try decoded_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectError(error.OutputLimitExceeded, decodeNativeFrameAppendLimited(std.testing.allocator, &decoded_appended, encoded, repeated.len - 1));
    try std.testing.expectEqualSlices(u8, "prefix:", decoded_appended.items);
    var reusable_frame_decoder = NativeFrameDecoder.init(std.testing.allocator);
    defer reusable_frame_decoder.deinit();
    const reusable_decoded = try reusable_frame_decoder.decodeAlloc(encoded);
    defer std.testing.allocator.free(reusable_decoded);
    try std.testing.expectEqualSlices(u8, repeated, reusable_decoded);
    const reusable_exact_decoded = try reusable_frame_decoder.decodeAllocExactSize(encoded, repeated.len);
    defer std.testing.allocator.free(reusable_exact_decoded);
    try std.testing.expectEqualSlices(u8, repeated, reusable_exact_decoded);
    const reusable_decoded_scratch = try reusable_frame_decoder.decodeScratch(encoded);
    try std.testing.expectEqualSlices(u8, repeated, reusable_decoded_scratch);
    const reusable_scratch_limited = try reusable_frame_decoder.decodeScratchLimited(encoded, repeated.len);
    try std.testing.expectEqualSlices(u8, repeated, reusable_scratch_limited);
    try std.testing.expectError(error.OutputLimitExceeded, reusable_frame_decoder.decodeScratchLimited(encoded, repeated.len - 1));
    try std.testing.expectEqual(@as(usize, 0), reusable_frame_decoder.scratch.items.len);
    decoded_appended.clearRetainingCapacity();
    try decoded_appended.appendSlice(std.testing.allocator, "prefix:");
    const reusable_append_written = try reusable_frame_decoder.decodeAppendLimited(&decoded_appended, encoded, repeated.len);
    try std.testing.expectEqual(repeated.len, reusable_append_written);
    try std.testing.expectEqualSlices(u8, repeated, decoded_appended.items["prefix:".len..]);
    var reusable_decode_into: [repeated.len]u8 = undefined;
    const reusable_decode_into_written = try reusable_frame_decoder.decodeIntoSlice(encoded, &reusable_decode_into);
    try std.testing.expectEqual(repeated.len, reusable_decode_into_written);
    try std.testing.expectEqualSlices(u8, repeated, &reusable_decode_into);

    const block_encoded = try encodeBlockAlloc(std.testing.allocator, repeated);
    defer std.testing.allocator.free(block_encoded);
    const block_bound = try encodedBlockBound(repeated.len);
    try std.testing.expect(block_encoded.len <= block_bound);
    const block_into = try std.testing.allocator.alloc(u8, block_bound);
    defer std.testing.allocator.free(block_into);
    const block_written = try encodeBlockIntoSlice(std.testing.allocator, repeated, block_into);
    try std.testing.expectEqualSlices(u8, block_encoded, block_into[0..block_written]);
    try std.testing.expectError(error.OutputTooSmall, encodeBlockIntoSlice(std.testing.allocator, repeated, block_into[0 .. block_written - 1]));
    var reusable_block_encoder = try BlockEncoder.init(std.testing.allocator);
    defer reusable_block_encoder.deinit();
    const reusable_block_scratch = try reusable_block_encoder.encodeScratch(repeated);
    try std.testing.expectEqualSlices(u8, block_encoded, reusable_block_scratch);
    const reusable_block_written = try reusable_block_encoder.encodeIntoSlice(repeated, block_into);
    try std.testing.expectEqualSlices(u8, block_encoded, block_into[0..reusable_block_written]);
    try std.testing.expectError(error.OutputTooSmall, reusable_block_encoder.encodeIntoSlice(repeated, block_into[0 .. reusable_block_written - 1]));

    const with_options = try encodePureFrameWithOptionsAlloc(
        std.testing.allocator,
        repeated,
        .{ .include_content_size = false, .content_checksum = false, .block_checksum = true },
    );
    defer std.testing.allocator.free(with_options);
    try std.testing.expectEqual(@as(u8, 0x70), with_options[4]);
    try std.testing.expect(with_options.len <= try encodedNativeFrameBoundWithOptions(repeated.len, .{
        .include_content_size = false,
        .content_checksum = false,
        .block_checksum = true,
    }));
    const with_options_decoded = try decodeNativeFrameAlloc(std.testing.allocator, with_options);
    defer std.testing.allocator.free(with_options_decoded);
    try std.testing.expectEqualSlices(u8, repeated, with_options_decoded);
    const inspected = try inspectNativeFrameHeader(with_options);
    try std.testing.expectEqual(@as(?u64, null), inspected.expected_content_size);
    try std.testing.expectEqual(true, inspected.block_independent);
    try std.testing.expectEqual(true, inspected.block_checksum);
    try std.testing.expectEqual(false, inspected.content_checksum);
    try std.testing.expectEqual(@as(?u32, null), inspected.dictionary_id);
    try std.testing.expectEqual(max_frame_block_len, inspected.block_size_max);
    const first_block = (try inspectNativeFrameFirstBlock(with_options)) orelse return error.CorruptFrame;
    try std.testing.expectEqual(inspected.payload_offset, first_block.header_offset);
    try std.testing.expectEqual(inspected.payload_offset + 4, first_block.payload_offset);
    try std.testing.expect(first_block.payload_len <= inspected.block_size_max);
    try std.testing.expectEqual(@as(?usize, first_block.payload_offset + first_block.payload_len), first_block.block_checksum_offset);
    try std.testing.expectEqual(first_block.payload_offset + first_block.payload_len + 4, first_block.next_header_offset);
    const first_block_again = (try inspectNativeFrameBlockAt(with_options, first_block.header_offset)) orelse return error.CorruptFrame;
    try std.testing.expectEqual(first_block.next_header_offset, first_block_again.next_header_offset);
    const block_summary = try summarizeNativeFrameBlocks(with_options);
    try std.testing.expect(block_summary.block_count >= 1);
    try std.testing.expectEqual(block_summary.block_count, block_summary.compressed_block_count + block_summary.raw_block_count);
    try std.testing.expect(block_summary.payload_bytes >= first_block.payload_len);
    const stream_summary = try summarizeNativeStream(with_options);
    try std.testing.expectEqual(@as(usize, 1), stream_summary.frame_count);
    try std.testing.expectEqual(@as(usize, 0), stream_summary.skippable_frame_count);
    try std.testing.expectEqual(block_summary.block_count, stream_summary.block_count);
    var block_iterator = try NativeFrameBlockIterator.init(with_options);
    var iterated_block_count: usize = 0;
    var iterated_payload_bytes: usize = 0;
    while (try block_iterator.next()) |block| {
        iterated_block_count += 1;
        iterated_payload_bytes += block.payload_len;
        try std.testing.expect(block.payload_len <= inspected.block_size_max);
    }
    try std.testing.expectEqual(block_summary.block_count, iterated_block_count);
    try std.testing.expectEqual(block_summary.payload_bytes, iterated_payload_bytes);
    try std.testing.expectEqual(@as(?usize, block_iterator.next_header_offset - 4), block_iterator.end_mark_offset);
    try std.testing.expectEqual(@as(?NativeFrameBlockHeader, null), try block_iterator.next());

    const with_dictionary_id = try encodePureFrameWithOptionsAlloc(
        std.testing.allocator,
        repeated,
        .{ .dictionary_id = 0x1234_abcd, .content_checksum = false },
    );
    defer std.testing.allocator.free(with_dictionary_id);
    const dict_header = try inspectNativeFrameHeader(with_dictionary_id);
    try std.testing.expectEqual(@as(?u32, 0x1234_abcd), dict_header.dictionary_id);
    try std.testing.expectEqual(@as(?u64, repeated.len), dict_header.expected_content_size);
    try std.testing.expectError(error.NeedDictionary, decodeNativeFrameAlloc(std.testing.allocator, with_dictionary_id));
    const reusable_with_dictionary_id = try reusable_frame_encoder.encodeScratch(repeated, .{ .dictionary_id = 0x1234_abcd, .content_checksum = false });
    const reusable_dict_header = try inspectNativeFrameHeader(reusable_with_dictionary_id);
    try std.testing.expectEqual(@as(?u32, 0x1234_abcd), reusable_dict_header.dictionary_id);
    const empty_frame = try encodePureFrameAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty_frame);
    try std.testing.expectEqual(@as(?NativeFrameBlockHeader, null), try inspectNativeFrameFirstBlock(empty_frame));
    const empty_header = try inspectNativeFrameHeader(empty_frame);
    var empty_block_iterator = try NativeFrameBlockIterator.init(empty_frame);
    try std.testing.expectEqual(@as(?NativeFrameBlockHeader, null), try empty_block_iterator.next());
    try std.testing.expectEqual(@as(?usize, empty_header.payload_offset), empty_block_iterator.end_mark_offset);

    const linked = try encodePureFrameWithOptionsAlloc(
        std.testing.allocator,
        repeated,
        .{ .block_mode = .linked, .content_checksum = false },
    );
    defer std.testing.allocator.free(linked);
    try std.testing.expectEqual(@as(u8, 0x48), linked[4]);
    reusable_frame.clearRetainingCapacity();
    try reusable_frame_encoder.encodeAppend(&reusable_frame, repeated, .{
        .block_mode = .linked,
        .content_checksum = false,
    });
    try std.testing.expectEqualSlices(u8, linked, reusable_frame.items);
    const linked_decoded = try decodeNativeFrameAlloc(std.testing.allocator, linked);
    defer std.testing.allocator.free(linked_decoded);
    try std.testing.expectEqualSlices(u8, repeated, linked_decoded);

    const block_cases = [_]struct {
        id: BlockSizeId,
        bd: u8,
        max_len: usize,
    }{
        .{ .id = .max64kb, .bd = 0x40, .max_len = max_block_history_len },
        .{ .id = .max256kb, .bd = 0x50, .max_len = 256 * 1024 },
        .{ .id = .max1mb, .bd = 0x60, .max_len = 1024 * 1024 },
        .{ .id = .max4mb, .bd = 0x70, .max_len = max_frame_block_len },
    };
    for (block_cases) |case| {
        const payload = try std.testing.allocator.alloc(u8, case.max_len + 4096);
        defer std.testing.allocator.free(payload);
        @memset(payload, 'q');
        const encoded_blocks = try encodePureFrameWithOptionsAlloc(
            std.testing.allocator,
            payload,
            .{ .block_size_id = case.id, .content_checksum = false },
        );
        defer std.testing.allocator.free(encoded_blocks);
        try std.testing.expectEqual(case.bd, encoded_blocks[5]);
        const first_block_len = std.mem.readInt(u32, encoded_blocks[7 + 8 ..][0..4], .little) & 0x7fff_ffff;
        try std.testing.expect(first_block_len <= case.max_len);
        const decoded_blocks = try decodeNativeFrameAlloc(std.testing.allocator, encoded_blocks);
        defer std.testing.allocator.free(decoded_blocks);
        try std.testing.expectEqualSlices(u8, payload, decoded_blocks);
    }

    var into_buffer: [repeated.len]u8 = undefined;
    const into_written = try decodeFrameInto(encoded, &into_buffer);
    try std.testing.expectEqual(repeated.len, into_written);
    try std.testing.expectEqualSlices(u8, repeated, into_buffer[0..into_written]);
    try std.testing.expectError(error.OutputTooSmall, decodeFrameInto(encoded, into_buffer[0 .. into_buffer.len - 1]));
}

test "lz4 linked frame encoder uses previous block history" {
    const first_block_len = max_block_history_len;
    const second_block_len = 4 * 1024;
    const payload = try std.testing.allocator.alloc(u8, first_block_len + second_block_len);
    defer std.testing.allocator.free(payload);

    var state: u32 = 0x1234_5678;
    for (payload[0..first_block_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(payload[first_block_len..], payload[first_block_len - second_block_len .. first_block_len]);

    const linked = try encodePureFrameWithOptionsAlloc(
        std.testing.allocator,
        payload,
        .{
            .block_size_id = .max64kb,
            .block_mode = .linked,
            .content_checksum = false,
        },
    );
    defer std.testing.allocator.free(linked);

    const independent = try encodePureFrameWithOptionsAlloc(
        std.testing.allocator,
        payload,
        .{
            .block_size_id = .max64kb,
            .block_mode = .independent,
            .content_checksum = false,
        },
    );
    defer std.testing.allocator.free(independent);

    // The second block is a copy of the previous block tail. Independent LZ4
    // has no history to reference, while linked mode should encode it as a
    // small match-only block rather than store another 4 KiB literal payload.
    try std.testing.expect(linked.len < independent.len);
    const header = try parseFrameHeader(linked);
    try std.testing.expect(!header.block_independent);
    var offset = header.payload_offset;
    const first_header = std.mem.readInt(u32, linked[offset..][0..4], .little);
    offset += 4 + @as(usize, @intCast(first_header & 0x7fff_ffff));
    const second_header = std.mem.readInt(u32, linked[offset..][0..4], .little);
    try std.testing.expect((second_header & 0x8000_0000) == 0);
    try std.testing.expect((second_header & 0x7fff_ffff) < second_block_len / 8);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, linked);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "lz4 native incremental decoder accepts split input and output" {
    const payload = "incremental lz4 native payload " ** 4;
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
    });
    defer std.testing.allocator.free(encoded);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .input_policy = .prevalidated_frame });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const chunks = [_][]const u8{
        encoded[0..3],
        encoded[3..11],
        encoded[11..],
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
    try std.testing.expectEqual(encoded.len, decoder.snapshot().input_received);
    try std.testing.expectEqual(payload.len, decoder.snapshot().decoded_len.?);

    var written: usize = 0;
    while (true) {
        const end = @min(output.len, written + 7);
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
    const reused = try decoder.step(encoded, &output);
    try std.testing.expectEqual(core.StepResult.Status.done, reused.status);
    try std.testing.expectEqual(encoded.len, reused.progress.input_read);
    try std.testing.expectEqual(payload.len, reused.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "lz4 native incremental decoder streams single raw block without decoded scratch" {
    var payload: [4096]u8 = undefined;
    var state: u32 = 0xaced_beef;
    for (&payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, &payload, .{
        .content_checksum = false,
        .block_checksum = false,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(!first_block.is_compressed);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(encoded.len, initial.progress.input_read);
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
    try std.testing.expectEqualSlices(u8, &payload, &output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    try decoder.finish();
}

test "lz4 native incremental decoder streams multiple raw blocks without decoded scratch" {
    const payload = try std.testing.allocator.alloc(u8, max_block_history_len + 4096);
    defer std.testing.allocator.free(payload);
    var state: u32 = 0x1357_2468;
    for (payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .block_checksum = false,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(!first_block.is_compressed);
    const second_block = (try inspectNativeFrameBlockAt(encoded, first_block.next_header_offset)) orelse return error.CorruptFrame;
    try std.testing.expect(!second_block.is_compressed);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    const initial = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(encoded.len, initial.progress.input_read);
    try std.testing.expectEqual(@as(?usize, payload.len), decoder.snapshot().decoded_len);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var written: usize = 0;
    while (true) {
        const end = @min(output.len, written + 8191);
        const result = try decoder.step("", output[written..end]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    try decoder.finish();
}

test "lz4 native incremental decoder streams linked raw blocks without decoded scratch" {
    const payload = try std.testing.allocator.alloc(u8, max_block_history_len + 2048);
    defer std.testing.allocator.free(payload);
    var state: u32 = 0x89ab_cdef;
    for (payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = true,
        .block_mode = .linked,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const header = try inspectNativeFrameHeader(encoded);
    try std.testing.expect(!header.block_independent);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(!first_block.is_compressed);
    const second_block = (try inspectNativeFrameBlockAt(encoded, first_block.next_header_offset)) orelse return error.CorruptFrame;
    try std.testing.expect(!second_block.is_compressed);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    const initial = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(?usize, payload.len), decoder.snapshot().decoded_len);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var written: usize = 0;
    while (true) {
        const end = @min(output.len, written + 4099);
        const result = try decoder.step("", output[written..end]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
}

test "lz4 native incremental decoder streams linked compressed blocks directly" {
    const first_block_len = max_block_history_len;
    const second_block_len = 4 * 1024;
    const payload = try std.testing.allocator.alloc(u8, first_block_len + second_block_len);
    defer std.testing.allocator.free(payload);
    var state: u32 = 0x3141_5926;
    for (payload[0..first_block_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(payload[first_block_len..], payload[first_block_len - second_block_len .. first_block_len]);

    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = true,
        .block_mode = .linked,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const header = try inspectNativeFrameHeader(encoded);
    try std.testing.expect(!header.block_independent);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    const second_block = (try inspectNativeFrameBlockAt(encoded, first_block.next_header_offset)) orelse return error.CorruptFrame;
    try std.testing.expect(second_block.is_compressed);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    const initial = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    const done = try decoder.step("", output);
    try std.testing.expectEqual(core.StepResult.Status.done, done.status);
    try std.testing.expectEqual(payload.len, done.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, output);
}

test "lz4 native incremental linked compressed blocks keep direct history across output chunks" {
    const first_block_len = max_block_history_len;
    const second_block_len = 4 * 1024;
    const payload = try std.testing.allocator.alloc(u8, first_block_len + second_block_len);
    defer std.testing.allocator.free(payload);
    var state: u32 = 0x2718_2818;
    for (payload[0..first_block_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(payload[first_block_len..], payload[first_block_len - second_block_len .. first_block_len]);

    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = true,
        .block_mode = .linked,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    const second_block = (try inspectNativeFrameBlockAt(encoded, first_block.next_header_offset)) orelse return error.CorruptFrame;
    try std.testing.expect(!first_block.is_compressed);
    try std.testing.expect(second_block.is_compressed);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    const initial = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var written: usize = 0;
    while (true) {
        const end = @min(output.len, written + 4097);
        const result = try decoder.step("", output[written..end]);
        written += result.progress.output_written;
        try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
}

test "lz4 native incremental decoder validates raw block checksums directly" {
    const payload = try std.testing.allocator.alloc(u8, max_block_history_len + 1024);
    defer std.testing.allocator.free(payload);
    var state: u32 = 0x2468_1357;
    for (payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(!first_block.is_compressed);
    try std.testing.expect(first_block.block_checksum_offset != null);
    const second_block = (try inspectNativeFrameBlockAt(encoded, first_block.next_header_offset)) orelse return error.CorruptFrame;
    try std.testing.expect(!second_block.is_compressed);
    try std.testing.expect(second_block.block_checksum_offset != null);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    const initial = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    var written: usize = 0;
    while (true) {
        const end = @min(output.len, written + 4097);
        const result = try decoder.step("", output[written..end]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, output);

    var corrupt = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(corrupt);
    corrupt[first_block.block_checksum_offset.?] ^= 0x01;
    var bad = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .max_decoded_buffer_len = payload.len,
    });
    defer bad.deinit();
    try std.testing.expectError(error.ChecksumMismatch, bad.step(corrupt, output[0..0]));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", bad.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", bad.diagnostics().last_error_phase_name);
}

test "lz4 native incremental decoder validates content checksum directly" {
    const payload = try std.testing.allocator.alloc(u8, max_block_history_len + 2048);
    defer std.testing.allocator.free(payload);
    var state: u32 = 0xfeed_cafe;
    for (payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = true,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(!first_block.is_compressed);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    const initial = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    var written: usize = 0;
    while (true) {
        const end = @min(output.len, written + 5003);
        const result = try decoder.step("", output[written..end]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, output);

    var corrupt = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 0x01;
    var bad = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .max_decoded_buffer_len = payload.len,
    });
    defer bad.deinit();
    try std.testing.expectError(error.ChecksumMismatch, bad.step(corrupt, output[0..0]));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", bad.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", bad.diagnostics().last_error_phase_name);
}

test "lz4 native incremental decoder streams single compressed block without decoded scratch" {
    const payload = ("0123456789abcdef" ** 8) ** 64;
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(first_block.is_compressed);
    try std.testing.expect(first_block.block_checksum_offset != null);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    const decoded = try decoder.step("", &output);
    try std.testing.expectEqual(core.StepResult.Status.done, decoded.status);
    try std.testing.expectEqual(payload.len, decoded.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var corrupt = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(corrupt);
    corrupt[first_block.block_checksum_offset.?] ^= 0x01;
    var bad = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .max_decoded_buffer_len = payload.len,
    });
    defer bad.deinit();
    try std.testing.expectError(error.ChecksumMismatch, bad.step(corrupt, output[0..0]));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", bad.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", bad.diagnostics().last_error_phase_name);
}

test "lz4 native incremental compressed block checksum fits exact payload cap" {
    const payload = ("checksum-before-output-0123456789abcdef" ** 32) ** 16;
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(block.is_compressed);
    try std.testing.expect(block.block_checksum_offset != null);
    try std.testing.expect(block.payload_len >= (try inspectNativeFrameHeader(encoded)).payload_offset);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_compressed_buffer_len = block.payload_len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const first = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, first.status);
    try std.testing.expect(decoder.isBlockStreaming());
    try std.testing.expect(decoder.isCompressedBlockStreaming());
    try std.testing.expect(first.progress.input_read >= block.block_checksum_offset.? + 4);
    try std.testing.expect(decoder.compressedBufferedBytes() <= block.payload_len);
    try std.testing.expect(decoder.compressedBufferCapacity() <= block.payload_len);
    try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
    try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());

    var input_offset = first.progress.input_read;
    var output_offset: usize = 0;
    while (true) {
        const result = try decoder.step(encoded[input_offset..], output[output_offset..]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        try std.testing.expect(decoder.compressedBufferedBytes() <= block.payload_len);
        try std.testing.expect(decoder.compressedBufferCapacity() <= block.payload_len);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
        if (result.status == .done) break;
    }
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(payload.len, output_offset);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(@as(usize, 1), decoder.streamedCompressedBlockCount());

    var corrupt = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(corrupt);
    corrupt[block.block_checksum_offset.?] ^= 1;
    @memset(&output, 0xa5);
    var bad = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_compressed_buffer_len = block.payload_len,
        .max_decoded_buffer_len = payload.len,
    });
    defer bad.deinit();
    try std.testing.expectError(error.ChecksumMismatch, bad.step(corrupt, &output));
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectEqual(@as(usize, 0), bad.snapshot().output_written);
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", bad.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", bad.diagnostics().last_error_phase_name);
}

test "lz4 native incremental first-frame stop preserves suffix across execution paths" {
    const payload = ("first-frame-stop-0123456789abcdef" ** 32) ** 8;
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = true,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse
        return error.CorruptFrame;
    const suffix = "NEXT-OUTER-MEMBER";
    const joined = try std.mem.concat(std.testing.allocator, u8, &.{ encoded, suffix });
    defer std.testing.allocator.free(joined);

    inline for (0..2) |path_index| {
        var options = NativeIncrementalFrameDecoder.Options{
            .expected_output_len = payload.len,
            .max_decoded_buffer_len = payload.len,
            .stop_after_first_frame = true,
        };
        if (path_index == 1)
            options.max_compressed_buffer_len = first_block.payload_len;
        var decoder = NativeIncrementalFrameDecoder.initWithOptions(
            std.testing.allocator,
            options,
        );
        defer decoder.deinit();
        var output: [payload.len]u8 = undefined;
        var input_offset: usize = 0;
        var output_offset: usize = 0;
        while (true) {
            const output_end = @min(output.len, output_offset + 127);
            const stepped = try decoder.step(
                joined[input_offset..],
                output[output_offset..output_end],
            );
            input_offset += stepped.progress.input_read;
            output_offset += stepped.progress.output_written;
            if (stepped.status == .done) break;
        }
        const trailing = decoder.trailingInput();
        try std.testing.expectEqual(encoded.len, input_offset - trailing.len);
        try std.testing.expectEqualSlices(u8, suffix[0..trailing.len], trailing);
        try std.testing.expectEqualSlices(u8, suffix[trailing.len..], joined[input_offset..]);
        try std.testing.expectEqualSlices(u8, payload, &output);
        try std.testing.expectEqual(trailing.len, decoder.snapshot().trailing_input_bytes);
        if (path_index == 1)
            try std.testing.expect(decoder.streamedCompressedBlockCount() != 0);
        try decoder.finish();
    }
}

test "lz4 native block stream waits for a split compressed block checksum before output" {
    const payload = ("split-checksum-before-output-0123456789abcdef" ** 16) ** 8;
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = true,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(block.is_compressed);
    const checksum_offset = block.block_checksum_offset orelse return error.CorruptFrame;
    const payload_split = block.payload_offset + block.payload_len / 2;
    const split = checksum_offset + 2;

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_compressed_buffer_len = block.payload_len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = @splat(0xa5);
    const payload_partial = try decoder.step(encoded[0..payload_split], output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_input, payload_partial.status);
    try std.testing.expectEqual(payload_split, payload_partial.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), payload_partial.progress.output_written);
    try std.testing.expect(!decoder.isCompressedBlockStreaming());
    const partial = try decoder.step(encoded[payload_split..split], output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_input, partial.status);
    try std.testing.expectEqual(split - payload_split, partial.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), partial.progress.output_written);
    try std.testing.expect(!decoder.isCompressedBlockStreaming());
    try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);

    var input_offset = split;
    var output_offset: usize = 0;
    while (true) {
        const end = @min(output.len, output_offset + 7);
        const result = try decoder.step(encoded[input_offset..], output[output_offset..end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
        if (result.status == .done) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(payload.len, output_offset);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(@as(usize, 1), decoder.streamedCompressedBlockCount());
}

test "lz4 native block stream drains compressed block through one-byte output without decoded scratch" {
    const payload = ("0123456789abcdef" ** 8) ** 64;
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = true,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(block.is_compressed);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_compressed_buffer_len = block.payload_len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const first = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, first.status);
    try std.testing.expect(decoder.isBlockStreaming());
    try std.testing.expect(decoder.isCompressedBlockStreaming());
    try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
    try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());

    var input_offset = first.progress.input_read;
    var output_offset: usize = 0;
    while (true) {
        const result = try decoder.step(encoded[input_offset..], output[output_offset .. output_offset + 1]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        try std.testing.expect(decoder.compressedBufferedBytes() <= block.payload_len);
        try std.testing.expect(decoder.compressedBufferCapacity() <= block.payload_len);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(payload.len, output_offset);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(payload.len, decoder.diagnostics().output_written);
    try std.testing.expectEqual(@as(usize, 1), decoder.streamedCompressedBlockCount());
}

test "lz4 native block stream resets compressed cursor across independent blocks" {
    const payload = try std.testing.allocator.alloc(u8, max_block_history_len + 4096);
    defer std.testing.allocator.free(payload);
    const pattern = "0123456789abcdef";
    for (payload, 0..) |*byte, index| byte.* = pattern[index % pattern.len];
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = false,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const first = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    const second = (try inspectNativeFrameBlockAt(encoded, first.next_header_offset)) orelse return error.CorruptFrame;
    try std.testing.expect(first.is_compressed);
    try std.testing.expect(second.is_compressed);
    const compressed_limit = @max(first.payload_len, second.payload_len);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_compressed_buffer_len = compressed_limit,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var saw_cursor = false;
    while (true) {
        const end = @min(output.len, output_offset + 97);
        const result = try decoder.step(encoded[input_offset..], output[output_offset..end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        saw_cursor = saw_cursor or decoder.isCompressedBlockStreaming();
        try std.testing.expect(decoder.compressedBufferedBytes() <= compressed_limit);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
        if (result.status == .done) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expect(saw_cursor);
    try std.testing.expectEqual(@as(usize, 2), decoder.streamedCompressedBlockCount());
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(payload.len, output_offset);
    try std.testing.expectEqualSlices(u8, payload, output);
}

test "lz4 native block stream drains linked compressed block without decoded scratch" {
    const first_block_len = max_block_history_len;
    const second_block_len = 4 * 1024;
    const payload = try std.testing.allocator.alloc(u8, first_block_len + second_block_len);
    defer std.testing.allocator.free(payload);
    var state: u32 = 0x1357_2468;
    for (payload[0..first_block_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(payload[first_block_len..], payload[first_block_len - second_block_len .. first_block_len]);

    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = true,
        .block_mode = .linked,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const first = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    const second = (try inspectNativeFrameBlockAt(encoded, first.next_header_offset)) orelse return error.CorruptFrame;
    try std.testing.expect(!first.is_compressed);
    try std.testing.expect(second.is_compressed);
    const compressed_limit = @max(first.payload_len, @max(second.payload_len, (try inspectNativeFrameHeader(encoded)).payload_offset));

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_compressed_buffer_len = compressed_limit,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var saw_cursor = false;
    while (true) {
        const end = @min(output.len, output_offset + 17);
        const result = try decoder.step(encoded[input_offset..], output[output_offset..end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        saw_cursor = saw_cursor or decoder.isCompressedBlockStreaming();
        try std.testing.expect(decoder.compressedBufferedBytes() <= compressed_limit);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
        if (result.status == .done) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expect(saw_cursor);
    try std.testing.expectEqual(@as(usize, 1), decoder.streamedCompressedBlockCount());
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(payload.len, output_offset);
    try std.testing.expectEqualSlices(u8, payload, output);
}

test "lz4 native block stream drains dictionary compressed block without decoded scratch" {
    const dictionary = NativeDictionary.init(0x4455_6677, "abcdefghijklmnop");
    const payload = "abcdefghijklmnop-tail";
    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = true,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    }, dictionary);
    defer std.testing.allocator.free(encoded);
    const header = try inspectNativeFrameHeader(encoded);
    const block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(block.is_compressed);
    const compressed_limit = @max(block.payload_len, header.payload_offset);

    var decoder = NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, dictionary, .{
        .expected_output_len = payload.len,
        .max_compressed_buffer_len = compressed_limit,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var saw_cursor = false;
    while (true) {
        const end = @min(output.len, output_offset + 1);
        const result = try decoder.step(encoded[input_offset..], output[output_offset..end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        saw_cursor = saw_cursor or decoder.isCompressedBlockStreaming();
        try std.testing.expect(decoder.compressedBufferedBytes() <= compressed_limit);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
        if (result.status == .done) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expect(saw_cursor);
    try std.testing.expectEqual(@as(usize, 1), decoder.streamedCompressedBlockCount());
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(payload.len, output_offset);
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "lz4 native block stream drains compressed block larger than history without decoded scratch" {
    const payload = try std.testing.allocator.alloc(u8, 128 * 1024);
    defer std.testing.allocator.free(payload);
    const pattern = "0123456789abcdef";
    for (payload, 0..) |*byte, index| byte.* = pattern[index % pattern.len];
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = false,
        .block_mode = .independent,
        .block_size_id = .max256kb,
    });
    defer std.testing.allocator.free(encoded);
    const header = try inspectNativeFrameHeader(encoded);
    const block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(block.is_compressed);
    const compressed_limit = @max(block.payload_len, header.payload_offset);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_compressed_buffer_len = compressed_limit,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var saw_cursor = false;
    while (true) {
        const end = @min(output.len, output_offset + 113);
        const result = try decoder.step(encoded[input_offset..], output[output_offset..end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        saw_cursor = saw_cursor or decoder.isCompressedBlockStreaming();
        try std.testing.expect(decoder.compressedBufferedBytes() <= compressed_limit);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
        if (result.status == .done) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expect(saw_cursor);
    try std.testing.expectEqual(@as(usize, 1), decoder.streamedCompressedBlockCount());
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(payload.len, output_offset);
    try std.testing.expectEqualSlices(u8, payload, output);
}

test "lz4 native block stream consumes unchecked compressed payload byte progressively" {
    const payload = ("stream-input-0123456789abcdef" ** 16) ** 16;
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = false,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const header = try inspectNativeFrameHeader(encoded);
    const block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(block.is_compressed);
    try std.testing.expect(block.payload_len > header.payload_offset);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_compressed_buffer_len = header.payload_offset,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var saw_cursor = false;
    while (true) {
        const input_end = @min(encoded.len, input_offset + 1);
        const output_end = @min(output.len, output_offset + 1);
        const result = try decoder.step(encoded[input_offset..input_end], output[output_offset..output_end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        saw_cursor = saw_cursor or decoder.isCompressedBlockStreaming();
        try std.testing.expect(decoder.compressedBufferedBytes() <= header.payload_offset);
        try std.testing.expect(decoder.compressedBufferCapacity() <= header.payload_offset);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
        if (result.status == .done) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expect(saw_cursor);
    try std.testing.expectEqual(@as(usize, 1), decoder.streamedCompressedBlockCount());
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(payload.len, output_offset);
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "lz4 native compressed input stream reports truncation and malformed offset" {
    const payload = ("stream-errors-0123456789abcdef" ** 16) ** 16;
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .block_checksum = false,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const header = try inspectNativeFrameHeader(encoded);
    const block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(block.is_compressed);
    try std.testing.expect(block.payload_len > header.payload_offset);

    var truncated = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .max_compressed_buffer_len = header.payload_offset,
        .max_decoded_buffer_len = payload.len,
    });
    defer truncated.deinit();
    var output: [payload.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    const truncated_end = block.payload_offset + block.payload_len - 1;
    while (input_offset < truncated_end) {
        const input_end = @min(truncated_end, input_offset + 1);
        const output_end = @min(output.len, output_offset + 3);
        const result = try truncated.step(encoded[input_offset..input_end], output[output_offset..output_end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        try std.testing.expect(result.status != .done);
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());

    const corrupt = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(corrupt);
    var match_offset = block.payload_offset + 1;
    const token = corrupt[block.payload_offset];
    var literal_len: usize = token >> 4;
    if (literal_len == 15) {
        literal_len += try readLengthExtension(corrupt, &match_offset);
    }
    match_offset += literal_len;
    try std.testing.expect(block.payload_offset + block.payload_len - match_offset >= 2);
    corrupt[match_offset] = 0;
    corrupt[match_offset + 1] = 0;

    var malformed = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .max_compressed_buffer_len = header.payload_offset,
        .max_decoded_buffer_len = payload.len,
    });
    defer malformed.deinit();
    input_offset = 0;
    output_offset = 0;
    var saw_error = false;
    while (input_offset < corrupt.len) {
        const input_end = @min(corrupt.len, input_offset + 1);
        const output_end = @min(output.len, output_offset + 3);
        const result = malformed.step(corrupt[input_offset..input_end], output[output_offset..output_end]) catch |err| {
            try std.testing.expectEqual(error.InvalidMatch, err);
            saw_error = true;
            break;
        };
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        try std.testing.expect(result.status != .done);
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expect(saw_error);
    try std.testing.expectEqualSlices(u8, "InvalidMatch", malformed.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", malformed.diagnostics().last_error_phase_name);
}

test "lz4 native compressed input stream preserves exact-size diagnostics" {
    const payload = ("stream-size-0123456789abcdef" ** 16) ** 16;
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .include_content_size = false,
        .content_checksum = false,
        .block_checksum = false,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const header = try inspectNativeFrameHeader(encoded);
    const block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(block.is_compressed);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len - 1,
        .max_compressed_buffer_len = header.payload_offset,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var saw_error = false;
    while (input_offset < encoded.len) {
        const input_end = @min(encoded.len, input_offset + 1);
        const output_end = @min(output.len, output_offset + 7);
        const result = decoder.step(encoded[input_offset..input_end], output[output_offset..output_end]) catch |err| {
            try std.testing.expectEqual(error.SizeMismatch, err);
            saw_error = true;
            break;
        };
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        try std.testing.expect(result.status != .done);
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expect(saw_error);
    try std.testing.expectEqualSlices(u8, "SizeMismatch", decoder.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", decoder.diagnostics().last_error_phase_name);
}

test "lz4 native block stream rolls history across linked compressed blocks" {
    const first_block_len = max_block_history_len;
    const second_block_len = max_block_history_len;
    const third_block_len = 4 * 1024;
    const payload = try std.testing.allocator.alloc(u8, first_block_len + second_block_len + third_block_len);
    defer std.testing.allocator.free(payload);
    var state: u32 = 0x9e37_79b9;
    for (payload[0..first_block_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const pattern = payload[first_block_len - third_block_len .. first_block_len];
    for (0..second_block_len / third_block_len) |index| {
        @memcpy(payload[first_block_len + index * third_block_len ..][0..third_block_len], pattern);
    }
    @memcpy(payload[first_block_len + second_block_len ..], pattern);

    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = false,
        .block_mode = .linked,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const header = try inspectNativeFrameHeader(encoded);
    const first = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    const second = (try inspectNativeFrameBlockAt(encoded, first.next_header_offset)) orelse return error.CorruptFrame;
    const third = (try inspectNativeFrameBlockAt(encoded, second.next_header_offset)) orelse return error.CorruptFrame;
    try std.testing.expect(!first.is_compressed);
    try std.testing.expect(second.is_compressed);
    try std.testing.expect(third.is_compressed);
    try std.testing.expect(second.payload_len > header.payload_offset);
    try std.testing.expect(third.payload_len > header.payload_offset);
    const compressed_limit = header.payload_offset;

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_compressed_buffer_len = compressed_limit,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (true) {
        const input_end = @min(encoded.len, input_offset + 37);
        const end = @min(output.len, output_offset + 113);
        const result = try decoder.step(encoded[input_offset..input_end], output[output_offset..end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        try std.testing.expect(decoder.compressedBufferedBytes() <= compressed_limit);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
        if (result.status == .done) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expectEqual(@as(usize, 2), decoder.streamedCompressedBlockCount());
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(payload.len, output_offset);
    try std.testing.expectEqualSlices(u8, payload, output);
}

test "lz4 native compressed input stream uses preset dictionary with tiny buffers" {
    const dictionary_bytes = try std.testing.allocator.alloc(u8, 32 * 1024);
    defer std.testing.allocator.free(dictionary_bytes);
    var state: u32 = 0x6c8e_9cf5;
    for (dictionary_bytes) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const dictionary = NativeDictionary.init(0x4455_7788, dictionary_bytes);
    const payload = dictionary_bytes[dictionary_bytes.len - 16 * 1024 ..];
    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = false,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    }, dictionary);
    defer std.testing.allocator.free(encoded);
    const header = try inspectNativeFrameHeader(encoded);
    const block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(block.is_compressed);
    try std.testing.expect(block.payload_len > header.payload_offset);

    var decoder = NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, dictionary, .{
        .expected_output_len = payload.len,
        .max_compressed_buffer_len = header.payload_offset,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (true) {
        const input_end = @min(encoded.len, input_offset + 3);
        const output_end = @min(output.len, output_offset + 11);
        const result = try decoder.step(encoded[input_offset..input_end], output[output_offset..output_end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        try std.testing.expect(decoder.compressedBufferedBytes() <= header.payload_offset);
        try std.testing.expect(decoder.compressedBufferCapacity() <= header.payload_offset);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
        if (result.status == .done) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expectEqual(@as(usize, 1), decoder.streamedCompressedBlockCount());
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(payload.len, output_offset);
    try std.testing.expectEqualSlices(u8, payload, output);
}

test "lz4 compressed block cursor differentially matches prefix decoder" {
    var random = std.Random.DefaultPrng.init(0x4c5a_2026);
    for (0..64) |case_index| {
        const prefix_len = random.random().intRangeAtMost(usize, 0, max_block_history_len);
        const payload_len = random.random().intRangeAtMost(usize, 32, 8192);
        const prefix = try std.testing.allocator.alloc(u8, prefix_len);
        defer std.testing.allocator.free(prefix);
        random.random().bytes(prefix);
        const payload = try std.testing.allocator.alloc(u8, payload_len);
        defer std.testing.allocator.free(payload);
        random.random().bytes(payload);
        if (prefix.len >= 16 and case_index % 2 == 0) {
            const copied = @min(payload.len, prefix.len);
            @memcpy(payload[0..copied], prefix[prefix.len - copied ..]);
        }
        if (payload.len >= 64) {
            for (32..payload.len) |index| {
                if (index % 5 != 0) payload[index] = payload[index % 32];
            }
        }

        const block = try encodeBlockWithPrefixAlloc(std.testing.allocator, payload, prefix);
        defer std.testing.allocator.free(block);
        const expected = try decodeBlockWithPrefixAlloc(std.testing.allocator, block, payload.len, prefix);
        defer std.testing.allocator.free(expected);

        var cursor = incremental_block_decoder.Cursor.init(payload.len, prefix.len);
        var history: std.ArrayList(u8) = .empty;
        defer history.deinit(std.testing.allocator);
        try history.ensureTotalCapacity(std.testing.allocator, max_block_history_len);
        try history.appendSlice(std.testing.allocator, prefix);
        var history_start: usize = 0;
        const output = try std.testing.allocator.alloc(u8, payload.len);
        defer std.testing.allocator.free(output);
        var written: usize = 0;
        const chunk_len = case_index % 127 + 1;
        while (true) {
            const end = @min(output.len, written + chunk_len);
            const result = try cursor.step(block, .{ .bytes = history.items, .start = history_start }, output[written..end]);
            if (result.output_written != 0) {
                const produced = output[written..][0..result.output_written];
                if (history.items.len < max_block_history_len) {
                    const n = @min(produced.len, max_block_history_len - history.items.len);
                    history.appendSliceAssumeCapacity(produced[0..n]);
                    if (n < produced.len) {
                        const remaining = produced[n..];
                        @memcpy(history.items[0..remaining.len], remaining);
                        history_start = remaining.len;
                    }
                } else {
                    const first_len = @min(produced.len, max_block_history_len - history_start);
                    @memcpy(history.items[history_start..][0..first_len], produced[0..first_len]);
                    @memcpy(history.items[0 .. produced.len - first_len], produced[first_len..]);
                    history_start = (history_start + produced.len) % max_block_history_len;
                }
                written += result.output_written;
            }
            if (result.done) break;
            try std.testing.expect(result.output_written != 0);
        }
        try std.testing.expectEqual(payload.len, written);
        try std.testing.expectEqualSlices(u8, expected, output);
    }
}

test "lz4 native block stream rejects malformed compressed block before output" {
    const payload = ("0123456789abcdef" ** 8) ** 64;
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .block_checksum = false,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(block.is_compressed);

    const corrupt = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(corrupt);
    var block_offset = block.payload_offset;
    const token = corrupt[block_offset];
    block_offset += 1;
    var literal_len: usize = token >> 4;
    if (literal_len == 15) literal_len += try readLengthExtension(corrupt, &block_offset);
    block_offset += literal_len;
    try std.testing.expect(block.payload_offset + block.payload_len - block_offset >= 2);
    corrupt[block_offset] = 0;
    corrupt[block_offset + 1] = 0;

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
        .max_compressed_buffer_len = block.payload_len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = @splat(0xa5);
    try std.testing.expectError(error.InvalidMatch, decoder.step(corrupt, &output));
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectEqualSlices(u8, "InvalidMatch", decoder.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", decoder.diagnostics().last_error_phase_name);
}

test "lz4 native incremental decoder streams no-size compressed frame directly" {
    const payload = ("lz4-nosize-direct" ** 8) ** 64;
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .include_content_size = false,
        .content_checksum = true,
        .block_checksum = true,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const header = try inspectNativeFrameHeader(encoded);
    try std.testing.expectEqual(@as(?u64, null), header.expected_content_size);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(first_block.is_compressed);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(?usize, payload.len), decoder.snapshot().decoded_len);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    const decoded = try decoder.step("", &output);
    try std.testing.expectEqual(core.StepResult.Status.done, decoded.status);
    try std.testing.expectEqual(payload.len, decoded.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var corrupt = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 0x01;
    var bad = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .max_decoded_buffer_len = payload.len,
    });
    defer bad.deinit();
    const bad_initial = try bad.step(corrupt, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, bad_initial.status);
    try std.testing.expectError(error.ChecksumMismatch, bad.step("", &output));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", bad.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", bad.diagnostics().last_error_phase_name);
}

test "lz4 native incremental compressed block switches to cursor for small output" {
    const payload = ("fedcba9876543210" ** 8) ** 64;
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(first_block.is_compressed);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    try std.testing.expect(!decoder.isBlockStreaming());

    var written: usize = 0;
    while (true) {
        const end = @min(output.len, written + 127);
        const result = try decoder.step("", output[written..end]);
        written += result.progress.output_written;
        try std.testing.expect(decoder.isBlockStreaming() or result.status == .done);
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
    }
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(payload.len, decoder.diagnostics().output_written);
    try std.testing.expectEqual(@as(usize, 1), decoder.streamedCompressedBlockCount());
}

test "lz4 native incremental decoder streams multiple compressed blocks directly" {
    const payload = try std.testing.allocator.alloc(u8, max_block_history_len + 4096);
    defer std.testing.allocator.free(payload);
    const pattern = "0123456789abcdef";
    for (payload, 0..) |*byte, i| byte.* = pattern[i % pattern.len];

    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(first_block.is_compressed);
    const second_block = (try inspectNativeFrameBlockAt(encoded, first_block.next_header_offset)) orelse return error.CorruptFrame;
    try std.testing.expect(second_block.is_compressed);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    const initial = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    const decoded = try decoder.step("", output);
    try std.testing.expectEqual(core.StepResult.Status.done, decoded.status);
    try std.testing.expectEqual(payload.len, decoded.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
}

test "lz4 native incremental decoder validates compressed content checksum directly" {
    const payload = try std.testing.allocator.alloc(u8, max_block_history_len + 2048);
    defer std.testing.allocator.free(payload);
    const pattern = "abcdefghijklmnop";
    for (payload, 0..) |*byte, i| byte.* = pattern[i % pattern.len];

    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = true,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(first_block.is_compressed);

    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    const initial = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    const decoded = try decoder.step("", output);
    try std.testing.expectEqual(core.StepResult.Status.done, decoded.status);
    try std.testing.expectEqual(payload.len, decoded.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var corrupt = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 0x01;
    var bad = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer bad.deinit();
    const bad_initial = try bad.step(corrupt, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, bad_initial.status);
    try std.testing.expectError(error.ChecksumMismatch, bad.step("", output));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", bad.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", bad.diagnostics().last_error_phase_name);
}

test "lz4 native incremental decoder drains concatenated streams and skippable frames" {
    const first_payload = "incremental lz4 first stream member " ** 2;
    const second_payload = "incremental lz4 second stream member " ** 3;
    const third_payload = "incremental lz4 third stream member";
    const options: NativeFrameOptions = .{ .content_checksum = false, .block_checksum = true };

    const first = try encodePureFrameWithOptionsAlloc(std.testing.allocator, first_payload, options);
    defer std.testing.allocator.free(first);
    const second = try encodePureFrameWithOptionsAlloc(std.testing.allocator, second_payload, options);
    defer std.testing.allocator.free(second);
    const third = try encodePureFrameWithOptionsAlloc(std.testing.allocator, third_payload, options);
    defer std.testing.allocator.free(third);
    const skip = try encodeSkippableFrameAlloc(std.testing.allocator, 6, "incremental metadata");
    defer std.testing.allocator.free(skip);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    try stream.appendSlice(std.testing.allocator, skip);
    try stream.appendSlice(std.testing.allocator, second);
    try stream.appendSlice(std.testing.allocator, skip);

    var captured: [8]u8 = undefined;
    var events: [2]NativeIncrementalFrameDecoder.SkippableEvent = undefined;
    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .skippable_output = &captured,
        .skippable_events = &events,
    });
    defer decoder.deinit();
    var output: [first_payload.len + second_payload.len]u8 = undefined;
    const initial = try decoder.step(stream.items, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(stream.items.len, initial.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), initial.progress.output_written);

    var written: usize = 0;
    while (true) {
        const end = @min(output.len, written + 11);
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
    const continued_result = try decoder.step(third, &continued);
    try std.testing.expectEqual(core.StepResult.Status.done, continued_result.status);
    try std.testing.expectEqual(third.len, continued_result.progress.input_read);
    try std.testing.expectEqual(third_payload.len, continued_result.progress.output_written);
    try std.testing.expectEqualSlices(u8, third_payload, &continued);
    try std.testing.expectEqual(stream.items.len + third.len, decoder.snapshot().input_received);
    try std.testing.expectEqual(output.len + third_payload.len, decoder.diagnostics().output_written);
    const snapshot = decoder.snapshot();
    try std.testing.expectEqualSlices(u8, "increment"[0..captured.len], &captured);
    try std.testing.expectEqual(@as(usize, 2 * "incremental metadata".len), snapshot.skippable_total);
    try std.testing.expect(snapshot.skippable_truncated);
    try std.testing.expectEqual(@as(usize, 2), snapshot.skippable_event_count);
    try std.testing.expectEqual(@as(u4, 6), events[0].id);
    try std.testing.expectEqual("incremental metadata".len, events[1].payload_len);
}

test "lz4 native incremental decoder streams skippable payload beyond compressed limit" {
    var metadata: [4096]u8 = undefined;
    for (&metadata, 0..) |*byte, i| byte.* = @truncate(i * 31 + 5);
    const skip = try encodeSkippableFrameAlloc(std.testing.allocator, 10, &metadata);
    defer std.testing.allocator.free(skip);
    const payload = "data after large lz4 metadata";
    const frame = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = true,
    });
    defer std.testing.allocator.free(frame);
    const compressed_limit = @max(@as(usize, 16), frame.len);
    try std.testing.expect(skip.len > compressed_limit);
    const stream = try std.mem.concat(std.testing.allocator, u8, &.{ skip, frame });
    defer std.testing.allocator.free(stream);

    var captured: [37]u8 = undefined;
    var events: [1]NativeIncrementalFrameDecoder.SkippableEvent = undefined;
    var decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_compressed_buffer_len = compressed_limit,
        .max_decoded_buffer_len = payload.len,
        .skippable_output = &captured,
        .skippable_events = &events,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(stream.len, input_offset + 13);
        const output_end = @min(output.len, output_offset + 5);
        const result = try decoder.step(stream[input_offset..input_end], output[output_offset..output_end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        try std.testing.expect(decoder.compressedBufferedBytes() <= compressed_limit);
        try std.testing.expect(decoder.compressedBufferCapacity() <= compressed_limit);
        if (result.status == .need_input) try std.testing.expect(input_offset < stream.len);
        if (result.status == .need_output) try std.testing.expect(output_offset < output.len);
    }
    try decoder.finish();
    try std.testing.expectEqual(stream.len, input_offset);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqualSlices(u8, metadata[0..captured.len], &captured);
    const snapshot = decoder.snapshot();
    try std.testing.expectEqual(metadata.len, snapshot.skippable_total);
    try std.testing.expect(snapshot.skippable_truncated);
    try std.testing.expectEqual(@as(usize, 1), snapshot.skippable_event_count);
    try std.testing.expectEqual(@as(u4, 10), events[0].id);
    try std.testing.expectEqual(metadata.len, events[0].payload_len);

    const data_then_skip = try std.mem.concat(std.testing.allocator, u8, &.{ frame, skip });
    defer std.testing.allocator.free(data_then_skip);
    var trailing_capture: [19]u8 = undefined;
    var trailing_decoder = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_compressed_buffer_len = frame.len + 8,
        .max_decoded_buffer_len = payload.len,
        .skippable_output = &trailing_capture,
    });
    defer trailing_decoder.deinit();
    var trailing_output: [payload.len]u8 = undefined;
    const trailing_done = try trailing_decoder.step(data_then_skip, &trailing_output);
    try std.testing.expectEqual(core.StepResult.Status.done, trailing_done.status);
    try std.testing.expectEqual(data_then_skip.len, trailing_done.progress.input_read);
    try std.testing.expectEqualSlices(u8, payload, &trailing_output);
    try std.testing.expectEqualSlices(u8, metadata[0..trailing_capture.len], &trailing_capture);
    try std.testing.expectEqual(metadata.len, trailing_decoder.snapshot().skippable_total);

    var truncated_capture: [metadata.len]u8 = undefined;
    var truncated = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = 0,
        .max_compressed_buffer_len = 8,
        .max_decoded_buffer_len = 0,
        .skippable_output = &truncated_capture,
    });
    defer truncated.deinit();
    const partial = try truncated.step(skip[0 .. skip.len - 1], &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_input, partial.status);
    try std.testing.expectEqual(skip.len - 1, partial.progress.input_read);
    const truncated_snapshot = truncated.snapshot();
    try std.testing.expectEqual(@as(usize, 0), truncated_snapshot.skippable_written);
    try std.testing.expectEqual(@as(usize, 0), truncated_snapshot.skippable_total);
    try std.testing.expectEqual(@as(usize, 0), truncated_snapshot.skippable_event_count);
    try std.testing.expectEqualSlices(u8, metadata[0 .. metadata.len - 1], truncated_capture[0 .. metadata.len - 1]);
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());
    try std.testing.expectEqualSlices(u8, "frame", truncated.diagnostics().last_error_phase_name);

    var header_limited = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = 0,
        .max_compressed_buffer_len = 7,
        .max_decoded_buffer_len = 0,
    });
    defer header_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, header_limited.step(skip, &.{}));
    try std.testing.expectEqual(@as(usize, 7), header_limited.snapshot().input_received);
    try std.testing.expectEqualSlices(u8, "frame", header_limited.diagnostics().last_error_phase_name);

    var dictionary_captured: [metadata.len]u8 = undefined;
    var dictionary_events: [1]NativeIncrementalFrameDecoder.SkippableEvent = undefined;
    const dictionary = NativeDictionary.init(0x4c5a_3401, "lz4-skippable-dictionary");
    var dictionary_decoder = NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, dictionary, .{
        .expected_output_len = 0,
        .max_compressed_buffer_len = 8,
        .max_decoded_buffer_len = 0,
        .skippable_output = &dictionary_captured,
        .skippable_events = &dictionary_events,
    });
    defer dictionary_decoder.deinit();
    const dictionary_done = try dictionary_decoder.step(skip, &.{});
    try std.testing.expectEqual(core.StepResult.Status.done, dictionary_done.status);
    try std.testing.expectEqualSlices(u8, &metadata, &dictionary_captured);
    try std.testing.expectEqual(@as(usize, 1), dictionary_decoder.snapshot().skippable_event_count);
    try std.testing.expectEqual(@as(u4, 10), dictionary_events[0].id);
}

test "lz4 native incremental decoder enforces buffer limits" {
    const payload = "bounded incremental lz4 payload " ** 8;
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
    });
    defer std.testing.allocator.free(encoded);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(first_block.is_compressed);
    try std.testing.expect(first_block.payload_len > 1);

    const compressed_limit = first_block.payload_len - 1;
    var compressed_limited = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .max_compressed_buffer_len = compressed_limit,
    });
    defer compressed_limited.deinit();
    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, compressed_limited.step(encoded, output[0..0]));
    try std.testing.expectEqual(first_block.payload_offset + compressed_limit, compressed_limited.snapshot().input_received);
    try std.testing.expectEqualSlices(u8, "OutputLimitExceeded", compressed_limited.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", compressed_limited.diagnostics().last_error_phase_name);

    var decoded_limited = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .max_decoded_buffer_len = payload.len - 1,
    });
    defer decoded_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, decoded_limited.step(encoded, &output));
    try std.testing.expectEqual(encoded.len, decoded_limited.snapshot().input_received);
    try std.testing.expectEqualSlices(u8, "OutputLimitExceeded", decoded_limited.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", decoded_limited.diagnostics().last_error_phase_name);
}

test "lz4 native incremental decoder enforces exact output size" {
    const payload = "exact incremental lz4 payload " ** 3;
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
    });
    defer std.testing.allocator.free(encoded);

    var exact = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
    });
    defer exact.deinit();
    var output: [payload.len]u8 = undefined;
    var written: usize = 0;
    var result = try exact.step(encoded[0 .. encoded.len / 2], output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_input, result.status);
    result = try exact.step(encoded[encoded.len / 2 ..], output[0..9]);
    written += result.progress.output_written;
    while (result.status != .done) {
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
        const end = @min(output.len, written + 9);
        result = try exact.step("", output[written..end]);
        written += result.progress.output_written;
    }
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try exact.finish();

    var too_small = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len - 1,
    });
    defer too_small.deinit();
    try std.testing.expectError(error.SizeMismatch, too_small.step(encoded, &output));
    try std.testing.expectEqualSlices(u8, "SizeMismatch", too_small.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", too_small.diagnostics().last_error_phase_name);

    var too_large = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len + 1,
    });
    defer too_large.deinit();
    _ = try too_large.step(encoded, &output);
    const pending = try too_large.step("", output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_input, pending.status);
    try std.testing.expectError(error.SizeMismatch, too_large.finish());
    try std.testing.expectEqualSlices(u8, "SizeMismatch", too_large.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "output", too_large.diagnostics().last_error_phase_name);
}

test "lz4 native incremental decoder supports dictionaries" {
    const dict = NativeDictionary.init(0x4449_4354, "abcdefghijklmnop");
    const payload = "abcdefghijklmnop-tail";
    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{ .content_checksum = false }, dict);
    defer std.testing.allocator.free(encoded);

    var output: [payload.len]u8 = undefined;
    var decoder = NativeIncrementalFrameDecoder.initWithDictionary(std.testing.allocator, dict);
    defer decoder.deinit();
    const result = try decoder.step(encoded, &output);
    try std.testing.expectEqual(core.StepResult.Status.done, result.status);
    try std.testing.expectEqualSlices(u8, payload, &output);

    var missing = NativeIncrementalFrameDecoder.init(std.testing.allocator);
    defer missing.deinit();
    try std.testing.expectError(error.NeedDictionary, missing.step(encoded, &output));
    const diagnostics = missing.diagnostics();
    try std.testing.expectEqualSlices(u8, "NeedDictionary", diagnostics.last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", diagnostics.last_error_phase_name);
}

test "lz4 native incremental decoder streams dictionary compressed blocks directly" {
    const dict = NativeDictionary.init(0x4449_4355, "abcdefghijklmnop");
    const payload = "abcdefghijklmnop-tail";
    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
        .block_checksum = true,
    }, dict);
    defer std.testing.allocator.free(encoded);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(first_block.is_compressed);

    var decoder = NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, dict, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    const decoded = try decoder.step("", &output);
    try std.testing.expectEqual(core.StepResult.Status.done, decoded.status);
    try std.testing.expectEqual(payload.len, decoded.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);

    var corrupt = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 0x01;
    var bad = NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, dict, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer bad.deinit();
    const bad_initial = try bad.step(corrupt, output[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, bad_initial.status);
    try std.testing.expectError(error.ChecksumMismatch, bad.step("", &output));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", bad.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", bad.diagnostics().last_error_phase_name);

    var missing = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .input_policy = .prevalidated_frame });
    defer missing.deinit();
    try std.testing.expectError(error.NeedDictionary, missing.step(encoded, output[0..0]));
    try std.testing.expectEqualSlices(u8, "NeedDictionary", missing.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", missing.diagnostics().last_error_phase_name);
}

test "lz4 native frame uses preset dictionary history" {
    const dict = NativeDictionary.init(0x1234_abcd, "abcdefghijklmnop");
    const payload = "abcdefghijklmnop-tail";
    const options: NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };

    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, options, dict);
    defer std.testing.allocator.free(encoded);
    const header = try inspectNativeFrameHeader(encoded);
    try std.testing.expectEqual(@as(?u32, dict.id), header.dictionary_id);
    const first_block = (try inspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    try std.testing.expect(first_block.is_compressed);
    try std.testing.expectError(error.NeedDictionary, decodeNativeFrameAlloc(std.testing.allocator, encoded));
    try std.testing.expectError(error.NeedDictionary, decodeNativeFrameAllocWithDictionary(std.testing.allocator, encoded, NativeDictionary.init(0x1111, dict.content)));

    const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, encoded, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    const exact_decoded = try decodeNativeFrameAllocWithDictionaryExactSize(std.testing.allocator, encoded, dict, payload.len);
    defer std.testing.allocator.free(exact_decoded);
    try std.testing.expectEqualSlices(u8, payload, exact_decoded);
    try std.testing.expectError(error.SizeMismatch, decodeNativeFrameAllocWithDictionaryExactSize(std.testing.allocator, encoded, dict, payload.len - 1));
    try std.testing.expectEqual(payload.len, try decodedNativeFrameSizeWithDictionary(encoded, dict));
    try std.testing.expectError(error.OutputLimitExceeded, decodedNativeFrameSizeLimitedWithDictionary(encoded, payload.len - 1, dict));

    var into: [payload.len]u8 = undefined;
    const into_written = try decodeNativeFrameIntoWithDictionary(encoded, &into, dict);
    try std.testing.expectEqual(payload.len, into_written);
    try std.testing.expectEqualSlices(u8, payload, &into);
    try std.testing.expectError(error.OutputTooSmall, decodeNativeFrameIntoWithDictionary(encoded, into[0 .. into.len - 1], dict));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeNativeFrameAppendWithDictionary(std.testing.allocator, &appended, encoded, dict));
    try std.testing.expectEqualSlices(u8, "prefix:abcdefghijklmnop-tail", appended.items);

    var encoder = try NativeFrameEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    const scratch = try encoder.encodeScratchWithDictionary(payload, options, dict);
    try std.testing.expectEqualSlices(u8, encoded, scratch);
    var decoder = NativeFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    const scratch_decoded = try decoder.decodeScratchWithDictionary(scratch, dict);
    try std.testing.expectEqualSlices(u8, payload, scratch_decoded);
    const reusable_exact_decoded = try decoder.decodeAllocWithDictionaryExactSize(scratch, dict, payload.len);
    defer std.testing.allocator.free(reusable_exact_decoded);
    try std.testing.expectEqualSlices(u8, payload, reusable_exact_decoded);

    const bound = try encodedNativeFrameBoundWithOptions(payload.len, .{
        .content_checksum = false,
        .block_checksum = true,
        .dictionary_id = dict.id,
    });
    const out = try std.testing.allocator.alloc(u8, bound);
    defer std.testing.allocator.free(out);
    const written = try encodeNativeFrameIntoSliceWithDictionary(std.testing.allocator, payload, options, dict, out);
    try std.testing.expectEqualSlices(u8, encoded, out[0..written]);
    try std.testing.expectError(error.OutputTooSmall, encodeNativeFrameIntoSliceWithDictionary(std.testing.allocator, payload, options, dict, out[0 .. written - 1]));
}

test "lz4 native dictionary can derive stable non-zero ids from content" {
    const dict = NativeDictionary.initFromContent("abcdefghijklmnop");
    try std.testing.expectEqual(checksum_mod.crc32(dict.content), dict.id);
    try std.testing.expectEqual(dict.id, NativeDictionary.derivedId(dict.content));
    try std.testing.expectEqual(dict.id, NativeDictionary.initFromContent(dict.content).id);
    try std.testing.expectEqual(@as(u32, 1), NativeDictionary.derivedId(""));
    try std.testing.expectEqual(@as(u32, 1), NativeDictionary.initFromContent("").id);
}

test "lz4 native dictionary training returns owned bytes and stable id" {
    const samples = [_][]const u8{
        "trained-lz4-prefix alpha trained-lz4-tail",
        "trained-lz4-prefix beta trained-lz4-tail",
        "trained-lz4-prefix gamma trained-lz4-tail",
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
    try std.testing.expectEqual(@as(usize, max_block_history_len), metadata.window_len);
    const metadata_dict = try NativeDictionary.initFromMetadata(metadata, dict.content);
    try std.testing.expectEqual(dict.id, metadata_dict.id);
    try std.testing.expectEqualSlices(u8, dict.content, metadata_dict.content);
    try std.testing.expectError(error.InvalidDictionaryMetadata, NativeDictionary.initFromMetadata(metadata, "wrong"));
    try std.testing.expect(dict.content.len > 0);
    try std.testing.expect(dict.content.len <= 64);

    const payload = "trained-lz4-prefix alpha trained-lz4-tail payload";
    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
    }, dict);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, encoded, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "lz4 independent blocks reuse preset dictionary" {
    const dict = NativeDictionary.init(0x2222_abcd, "abcdefghijklmnop");
    const first_block = try std.testing.allocator.alloc(u8, max_block_history_len);
    defer std.testing.allocator.free(first_block);
    @memset(first_block, 'x');
    const second_block = "abcdefghijklmnop-two";
    const payload = try std.testing.allocator.alloc(u8, first_block.len + second_block.len);
    defer std.testing.allocator.free(payload);
    @memcpy(payload[0..first_block.len], first_block);
    @memcpy(payload[first_block.len..], second_block);

    const encoded = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
        .block_size_id = .max64kb,
        .block_mode = .independent,
    }, dict);
    defer std.testing.allocator.free(encoded);

    const summary = try summarizeNativeFrameBlocks(encoded);
    try std.testing.expectEqual(@as(usize, 2), summary.block_count);
    var blocks = try iterateNativeFrameBlocks(encoded);
    _ = (try blocks.next()) orelse return error.CorruptFrame;
    const second = (try blocks.next()) orelse return error.CorruptFrame;
    try std.testing.expect(second.is_compressed);

    const decoded = try decodeNativeFrameAllocWithDictionary(std.testing.allocator, encoded, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expectEqual(payload.len, try decodedNativeFrameSizeWithDictionary(encoded, dict));
}

test "lz4 native concatenated streams use preset dictionary" {
    const dict = NativeDictionary.init(0x2222, "abcdefghijklmnop");
    const options: NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };
    const first_payload = "abcdefghijklmnop-one";
    const second_payload = "abcdefghijklmnop-two";
    const first = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, first_payload, options, dict);
    defer std.testing.allocator.free(first);
    const skip = try encodeSkippableFrameAlloc(std.testing.allocator, 2, "metadata");
    defer std.testing.allocator.free(skip);
    const second = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, second_payload, options, dict);
    defer std.testing.allocator.free(second);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    try stream.appendSlice(std.testing.allocator, skip);
    try stream.appendSlice(std.testing.allocator, second);

    const expected = first_payload ++ second_payload;
    const decoded = try decodeNativeConcatenatedFrameAllocWithDictionary(std.testing.allocator, stream.items, dict);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    try std.testing.expectEqual(expected.len, try decodedNativeConcatenatedFrameSizeWithDictionary(stream.items, dict));
    try std.testing.expectError(error.OutputLimitExceeded, decodedNativeConcatenatedFrameSizeLimitedWithDictionary(stream.items, expected.len - 1, dict));
    try std.testing.expectError(error.NeedDictionary, decodeNativeConcatenatedFrameAllocWithDictionary(std.testing.allocator, stream.items, NativeDictionary.init(0x3333, dict.content)));

    var into: [expected.len]u8 = undefined;
    const into_written = try decodeNativeConcatenatedFrameIntoWithDictionary(stream.items, &into, dict);
    try std.testing.expectEqual(expected.len, into_written);
    try std.testing.expectEqualSlices(u8, expected, &into);
    try std.testing.expectError(error.OutputTooSmall, decodeNativeConcatenatedFrameIntoWithDictionary(stream.items, into[0 .. into.len - 1], dict));
    const exact_into_written = try decodeNativeConcatenatedFrameIntoWithDictionaryExactSize(stream.items, &into, dict, expected.len);
    try std.testing.expectEqual(expected.len, exact_into_written);
    try std.testing.expectEqualSlices(u8, expected, &into);
    try std.testing.expectError(error.OutputTooSmall, decodeNativeConcatenatedFrameIntoWithDictionaryExactSize(stream.items, into[0 .. into.len - 1], dict, expected.len));
    try std.testing.expectError(error.SizeMismatch, decodeNativeConcatenatedFrameIntoWithDictionaryExactSize(stream.items, &into, dict, expected.len - 1));
    var oversized_into: [expected.len + 1]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, decodeNativeConcatenatedFrameIntoWithDictionaryExactSize(stream.items, &oversized_into, dict, expected.len + 1));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeNativeConcatenatedFrameAppendWithDictionary(std.testing.allocator, &appended, stream.items, dict));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, appended.items);

    var decoder = NativeFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeConcatenatedScratchWithDictionary(stream.items, dict);
    try std.testing.expectEqualSlices(u8, expected, scratch);
    const reusable_exact_into_written = try decoder.decodeConcatenatedIntoSliceWithDictionaryExactSize(stream.items, &into, dict, expected.len);
    try std.testing.expectEqual(expected.len, reusable_exact_into_written);
    try std.testing.expectEqualSlices(u8, expected, &into);

    const chunks = [_][]const u8{
        stream.items[0..4],
        stream.items[4 .. stream.items.len - 2],
        stream.items[stream.items.len - 2 ..],
    };
    const join = try std.testing.allocator.alloc(u8, stream.items.len);
    defer std.testing.allocator.free(join);
    @memset(&into, 0);
    const chunked_exact_written = try decodeNativeConcatenatedFrameChunksIntoWithDictionaryExactSize(&chunks, join, &into, dict, expected.len);
    try std.testing.expectEqual(expected.len, chunked_exact_written);
    try std.testing.expectEqualSlices(u8, expected, &into);
    try std.testing.expectError(error.OutputTooSmall, decodeNativeConcatenatedFrameChunksIntoWithDictionaryExactSize(&chunks, join, into[0 .. into.len - 1], dict, expected.len));
    try std.testing.expectError(error.SizeMismatch, decodeNativeConcatenatedFrameChunksIntoWithDictionaryExactSize(&chunks, join, &into, dict, expected.len - 1));
    @memset(&into, 0);
    const reusable_chunked_exact_written = try decoder.decodeConcatenatedChunksIntoSliceWithDictionaryExactSize(&chunks, join, &into, dict, expected.len);
    try std.testing.expectEqual(expected.len, reusable_chunked_exact_written);
    try std.testing.expectEqualSlices(u8, expected, &into);
}

test "lz4 native concatenated streams select dictionaries by id" {
    const first_dict = NativeDictionary.init(0x1010, "abcdefghijklmnop");
    const second_dict = NativeDictionary.init(0x2020, "qrstuvwxyz123456");
    const dictionaries = [_]NativeDictionary{ first_dict, second_dict };
    const dictionary_set = try NativeDictionarySet.initChecked(&dictionaries);
    try dictionary_set.validate();
    try std.testing.expectEqualSlices(u8, first_dict.content, (dictionary_set.find(first_dict.id) orelse return error.NeedDictionary).content);
    try std.testing.expect(dictionary_set.find(0xffff) == null);
    const duplicate_dictionaries = [_]NativeDictionary{ first_dict, NativeDictionary.init(first_dict.id, "duplicate-lz4") };
    try std.testing.expectError(error.DuplicateDictionaryId, NativeDictionarySet.initChecked(&duplicate_dictionaries));
    try std.testing.expectError(error.DuplicateDictionaryId, NativeDictionarySet.init(&duplicate_dictionaries).validate());
    const zero_id_dictionaries = [_]NativeDictionary{NativeDictionary.init(0, "zero-lz4")};
    try std.testing.expectError(error.NeedDictionary, NativeDictionarySet.initChecked(&zero_id_dictionaries));
    const metadata_first_dict = NativeDictionary.initFromContent("lz4 metadata first");
    const metadata_second_dict = NativeDictionary.initFromContent("lz4 metadata second");
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
    const bad_contents = [_][]const u8{ metadata_first_dict.content, "wrong lz4 metadata second" };
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
        .content_checksum = false,
        .block_checksum = true,
    };
    const first_payload = "abcdefghijklmnop-one";
    const second_payload = "qrstuvwxyz123456-two";
    const first = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, first_payload, options, first_dict);
    defer std.testing.allocator.free(first);
    const skip = try encodeSkippableFrameAlloc(std.testing.allocator, 4, "lz4-set");
    defer std.testing.allocator.free(skip);
    const second = try encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, second_payload, options, second_dict);
    defer std.testing.allocator.free(second);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    try stream.appendSlice(std.testing.allocator, skip);
    try stream.appendSlice(std.testing.allocator, second);

    const expected = first_payload ++ second_payload;
    try std.testing.expectError(error.NeedDictionary, decodeNativeConcatenatedFrameAlloc(std.testing.allocator, stream.items));
    try std.testing.expectError(error.NeedDictionary, decodeNativeConcatenatedFrameAllocWithDictionary(std.testing.allocator, stream.items, first_dict));

    const first_decoded = try decodeNativeFrameAllocWithDictionarySet(std.testing.allocator, first, dictionary_set);
    defer std.testing.allocator.free(first_decoded);
    try std.testing.expectEqualSlices(u8, first_payload, first_decoded);
    const first_limited = try decodeNativeFrameAllocLimitedWithDictionarySet(std.testing.allocator, first, first_payload.len, dictionary_set);
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
    const exact_into_written = try decodeNativeConcatenatedFrameIntoWithDictionarySetExactSize(stream.items, &into, dictionary_set, expected.len);
    try std.testing.expectEqual(expected.len, exact_into_written);
    try std.testing.expectEqualSlices(u8, expected, &into);
    try std.testing.expectError(error.OutputTooSmall, decodeNativeConcatenatedFrameIntoWithDictionarySetExactSize(stream.items, into[0 .. into.len - 1], dictionary_set, expected.len));
    try std.testing.expectError(error.SizeMismatch, decodeNativeConcatenatedFrameIntoWithDictionarySetExactSize(stream.items, &into, dictionary_set, expected.len - 1));
    var oversized_into: [expected.len + 1]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, decodeNativeConcatenatedFrameIntoWithDictionarySetExactSize(stream.items, &oversized_into, dictionary_set, expected.len + 1));

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
    try std.testing.expectEqual(first_payload.len, try decodeNativeFrameAppendLimitedWithDictionarySet(std.testing.allocator, &appended, first, first_payload.len, dictionary_set));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ first_payload, appended.items);

    var decoder = NativeFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeConcatenatedScratchWithDictionarySet(stream.items, dictionary_set);
    try std.testing.expectEqualSlices(u8, expected, scratch);
    const reusable_exact_decoded = try decoder.decodeConcatenatedAllocWithDictionarySetExactSize(stream.items, dictionary_set, expected.len);
    defer std.testing.allocator.free(reusable_exact_decoded);
    try std.testing.expectEqualSlices(u8, expected, reusable_exact_decoded);
    const reusable_exact_into_written = try decoder.decodeConcatenatedIntoSliceWithDictionarySetExactSize(stream.items, &into, dictionary_set, expected.len);
    try std.testing.expectEqual(expected.len, reusable_exact_into_written);
    try std.testing.expectEqualSlices(u8, expected, &into);
    const chunks = [_][]const u8{
        stream.items[0..5],
        stream.items[5 .. stream.items.len - 3],
        stream.items[stream.items.len - 3 ..],
    };
    const join = try std.testing.allocator.alloc(u8, stream.items.len);
    defer std.testing.allocator.free(join);
    @memset(&into, 0);
    const chunked_exact_written = try decodeNativeConcatenatedFrameChunksIntoWithDictionarySetExactSize(&chunks, join, &into, dictionary_set, expected.len);
    try std.testing.expectEqual(expected.len, chunked_exact_written);
    try std.testing.expectEqualSlices(u8, expected, &into);
    try std.testing.expectError(error.OutputTooSmall, decodeNativeConcatenatedFrameChunksIntoWithDictionarySetExactSize(&chunks, join, into[0 .. into.len - 1], dictionary_set, expected.len));
    try std.testing.expectError(error.SizeMismatch, decodeNativeConcatenatedFrameChunksIntoWithDictionarySetExactSize(&chunks, join, &into, dictionary_set, expected.len - 1));
    @memset(&into, 0);
    const reusable_chunked_exact_written = try decoder.decodeConcatenatedChunksIntoSliceWithDictionarySetExactSize(&chunks, join, &into, dictionary_set, expected.len);
    try std.testing.expectEqual(expected.len, reusable_chunked_exact_written);
    try std.testing.expectEqualSlices(u8, expected, &into);
    const scratch_limited = try decoder.decodeConcatenatedScratchLimitedWithDictionarySet(stream.items, expected.len, dictionary_set);
    try std.testing.expectEqualSlices(u8, expected, scratch_limited);

    var direct_incremental = NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, dictionary_set, .{
        .input_policy = .prevalidated_frame,
        .expected_output_len = expected.len,
        .max_compressed_buffer_len = stream.items.len,
        .max_decoded_buffer_len = @max(first_payload.len, second_payload.len),
    });
    defer direct_incremental.deinit();
    var direct_out: [expected.len]u8 = undefined;
    const direct_initial = try direct_incremental.step(stream.items, direct_out[0..0]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, direct_initial.status);
    try std.testing.expectEqual(stream.items.len, direct_initial.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), direct_incremental.decoded_scratch.items.len);
    const direct_done = try direct_incremental.step("", &direct_out);
    try std.testing.expectEqual(core.StepResult.Status.done, direct_done.status);
    try std.testing.expectEqual(expected.len, direct_done.progress.output_written);
    try std.testing.expectEqualSlices(u8, expected, &direct_out);
    try std.testing.expectEqual(@as(usize, 0), direct_incremental.decoded_scratch.items.len);

    var incremental = NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, dictionary_set, .{
        .input_policy = .prevalidated_frame,
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
        const end = @min(incremental_out.len, incremental_written + 5);
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

test "lz4 block encoder uses caller prefix history" {
    const prefix_len = max_block_history_len;
    const block_len = 4 * 1024;
    const prefix = try std.testing.allocator.alloc(u8, prefix_len);
    defer std.testing.allocator.free(prefix);
    const block = try std.testing.allocator.alloc(u8, block_len);
    defer std.testing.allocator.free(block);

    var state: u32 = 0x51ed_1234;
    for (prefix) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(block, prefix[prefix.len - block.len ..]);

    const encoded = try encodeBlockWithPrefixAlloc(std.testing.allocator, block, prefix);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len < block.len);
    try std.testing.expectEqual(block.len, try decodedBlockSizeWithPrefix(encoded, prefix));

    const decoded = try decodeBlockWithPrefixAlloc(std.testing.allocator, encoded, block.len, prefix);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, block, decoded);

    const bound = try encodedBlockBound(block.len);
    const into = try std.testing.allocator.alloc(u8, bound);
    defer std.testing.allocator.free(into);
    const written = try encodeBlockWithPrefixIntoSlice(std.testing.allocator, block, prefix, into);
    try std.testing.expectEqualSlices(u8, encoded, into[0..written]);
    try std.testing.expectError(
        error.OutputTooSmall,
        encodeBlockWithPrefixIntoSlice(std.testing.allocator, block, prefix, into[0 .. written - 1]),
    );

    var reusable = try BlockEncoder.init(std.testing.allocator);
    defer reusable.deinit();
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    const appended_len = try reusable.appendWithPrefix(&appended, block, prefix);
    try std.testing.expectEqual(encoded.len, appended_len);
    try std.testing.expectEqualSlices(u8, encoded, appended.items);
    const reusable_encoded = try reusable.encodeWithPrefixAlloc(block, prefix);
    defer std.testing.allocator.free(reusable_encoded);
    try std.testing.expectEqualSlices(u8, encoded, reusable_encoded);
    const reusable_prefix_scratch = try reusable.encodeWithPrefixScratch(block, prefix);
    try std.testing.expectEqualSlices(u8, encoded, reusable_prefix_scratch);
    const reusable_into_written = try reusable.encodeWithPrefixIntoSlice(block, prefix, into);
    try std.testing.expectEqualSlices(u8, encoded, into[0..reusable_into_written]);
    try std.testing.expectError(
        error.OutputTooSmall,
        reusable.encodeWithPrefixIntoSlice(block, prefix, into[0 .. reusable_into_written - 1]),
    );
    appended.clearRetainingCapacity();
    const appended_plain_len = try reusable.append(&appended, "abcabcabca");
    try std.testing.expectEqual(appended.items.len, appended_plain_len);
    const reusable_plain = try reusable.encodeAlloc("abcabcabca");
    defer std.testing.allocator.free(reusable_plain);
    try std.testing.expectEqualSlices(u8, reusable_plain, appended.items);
    const reusable_plain_scratch = try reusable.encodeScratch("abcabcabca");
    try std.testing.expectEqualSlices(u8, reusable_plain, reusable_plain_scratch);
    const reusable_plain_written = try reusable.encodeIntoSlice("abcabcabca", into);
    try std.testing.expectEqualSlices(u8, reusable_plain, into[0..reusable_plain_written]);
    const reusable_decoded = try decodeBlockAlloc(std.testing.allocator, reusable_plain, "abcabcabca".len);
    defer std.testing.allocator.free(reusable_decoded);
    try std.testing.expectEqualSlices(u8, "abcabcabca", reusable_decoded);
}

test "lz4 skippable frame writer composes with concatenated native streams" {
    const first = try encodePureFrameAlloc(std.testing.allocator, "first");
    defer std.testing.allocator.free(first);
    const skip = try encodeSkippableFrameAlloc(std.testing.allocator, 11, "metadata");
    defer std.testing.allocator.free(skip);
    const second = try encodePureFrameAlloc(std.testing.allocator, "second");
    defer std.testing.allocator.free(second);

    try std.testing.expectEqual(skippable_magic_min + 11, std.mem.readInt(u32, skip[0..4], .little));
    try std.testing.expectEqual(@as(u32, "metadata".len), std.mem.readInt(u32, skip[4..8], .little));
    try std.testing.expectEqualSlices(u8, "metadata", skip[8..]);
    const skip_header = try inspectNativeSkippableFrame(skip);
    try std.testing.expectEqual(@as(u4, 11), skip_header.skippable_id);
    try std.testing.expectEqual(@as(usize, 8), skip_header.payload_offset);
    try std.testing.expectEqual(@as(usize, "metadata".len), skip_header.payload_len);
    try std.testing.expectEqual(skip.len, skip_header.next_frame_offset);
    try std.testing.expectEqual(skip.len, try encodedSkippableFrameBound("metadata".len));
    var skip_appended: std.ArrayList(u8) = .empty;
    defer skip_appended.deinit(std.testing.allocator);
    try encodeSkippableFrameAppend(std.testing.allocator, &skip_appended, 11, "metadata");
    try std.testing.expectEqualSlices(u8, skip, skip_appended.items);
    var skip_into: [8 + "metadata".len]u8 = undefined;
    const skip_into_written = try encodeSkippableFrameIntoSlice(11, "metadata", &skip_into);
    try std.testing.expectEqual(skip.len, skip_into_written);
    try std.testing.expectEqualSlices(u8, skip, skip_into[0..skip_into_written]);
    try std.testing.expectError(error.OutputTooSmall, encodeSkippableFrameIntoSlice(11, "metadata", skip_into[0 .. skip_into.len - 1]));

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    try stream.appendSlice(std.testing.allocator, skip);
    try stream.appendSlice(std.testing.allocator, second);

    const decoded = try decodeConcatenatedFrameAlloc(std.testing.allocator, stream.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "firstsecond", decoded);
    const exact_decoded = try decodeNativeConcatenatedFrameAllocExactSize(std.testing.allocator, stream.items, "firstsecond".len);
    defer std.testing.allocator.free(exact_decoded);
    try std.testing.expectEqualSlices(u8, "firstsecond", exact_decoded);
    try std.testing.expectError(error.SizeMismatch, decodeNativeConcatenatedFrameAllocExactSize(std.testing.allocator, stream.items, "firstsecond".len - 1));
    const stream_summary = try summarizeNativeStream(stream.items);
    try std.testing.expectEqual(@as(usize, 2), stream_summary.frame_count);
    try std.testing.expectEqual(@as(usize, 1), stream_summary.skippable_frame_count);
    try std.testing.expectEqual(@as(usize, "metadata".len), stream_summary.skippable_payload_bytes);
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
            try std.testing.expectEqualSlices(u8, skip, skippable.bytes);
            try std.testing.expectEqualSlices(u8, "metadata", skippable.payload);
            try std.testing.expectEqual(@as(u4, 11), skippable.header.skippable_id);
        },
    }
    const second_element = (try stream_iterator.next()) orelse return error.CorruptFrame;
    switch (second_element) {
        .frame => |frame| {
            try std.testing.expectEqual(first.len + skip.len, frame.offset);
            try std.testing.expectEqualSlices(u8, second, frame.bytes);
        },
        .skippable => return error.CorruptFrame,
    }
    try std.testing.expect((try stream_iterator.next()) == null);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), try decodedConcatenatedFrameSize(stream.items));
    var decoded_appended: std.ArrayList(u8) = .empty;
    defer decoded_appended.deinit(std.testing.allocator);
    try decoded_appended.appendSlice(std.testing.allocator, "prefix:");
    const decoded_appended_written = try decodeNativeConcatenatedFrameAppend(std.testing.allocator, &decoded_appended, stream.items);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), decoded_appended_written);
    try std.testing.expectEqualSlices(u8, "prefix:firstsecond", decoded_appended.items);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), try decodedConcatenatedFrameSizeLimited(stream.items, "firstsecond".len));
    try std.testing.expectError(error.OutputLimitExceeded, decodedConcatenatedFrameSizeLimited(stream.items, "firstsecond".len - 1));
    decoded_appended.clearRetainingCapacity();
    try decoded_appended.appendSlice(std.testing.allocator, "prefix:");
    const decoded_appended_limited_written = try decodeNativeConcatenatedFrameAppendLimited(std.testing.allocator, &decoded_appended, stream.items, "firstsecond".len);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), decoded_appended_limited_written);
    try std.testing.expectEqualSlices(u8, "prefix:firstsecond", decoded_appended.items);
    decoded_appended.clearRetainingCapacity();
    try decoded_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectError(error.OutputLimitExceeded, decodeNativeConcatenatedFrameAppendLimited(std.testing.allocator, &decoded_appended, stream.items, "firstsecond".len - 1));
    try std.testing.expectEqualSlices(u8, "prefix:", decoded_appended.items);
    var reusable_decoder = NativeFrameDecoder.init(std.testing.allocator);
    defer reusable_decoder.deinit();
    const reusable_decoded = try reusable_decoder.decodeConcatenatedAlloc(stream.items);
    defer std.testing.allocator.free(reusable_decoded);
    try std.testing.expectEqualSlices(u8, "firstsecond", reusable_decoded);
    const reusable_scratch = try reusable_decoder.decodeConcatenatedScratch(stream.items);
    try std.testing.expectEqualSlices(u8, "firstsecond", reusable_scratch);
    const reusable_scratch_limited = try reusable_decoder.decodeConcatenatedScratchLimited(stream.items, "firstsecond".len);
    try std.testing.expectEqualSlices(u8, "firstsecond", reusable_scratch_limited);
    try std.testing.expectError(error.OutputLimitExceeded, reusable_decoder.decodeConcatenatedScratchLimited(stream.items, "firstsecond".len - 1));
    try std.testing.expectEqual(@as(usize, 0), reusable_decoder.scratch.items.len);
    decoded_appended.clearRetainingCapacity();
    try decoded_appended.appendSlice(std.testing.allocator, "prefix:");
    const reusable_append_written = try reusable_decoder.decodeConcatenatedAppendLimited(&decoded_appended, stream.items, "firstsecond".len);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), reusable_append_written);
    try std.testing.expectEqualSlices(u8, "prefix:firstsecond", decoded_appended.items);
    var reusable_into: ["firstsecond".len]u8 = undefined;
    const reusable_into_written = try reusable_decoder.decodeConcatenatedIntoSlice(stream.items, &reusable_into);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), reusable_into_written);
    try std.testing.expectEqualSlices(u8, "firstsecond", &reusable_into);
    const exact_into_written = try decodeNativeConcatenatedFrameIntoExactSize(stream.items, &reusable_into, "firstsecond".len);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), exact_into_written);
    try std.testing.expectEqualSlices(u8, "firstsecond", &reusable_into);
    try std.testing.expectError(error.OutputTooSmall, decodeNativeConcatenatedFrameIntoExactSize(stream.items, reusable_into[0 .. reusable_into.len - 1], "firstsecond".len));
    try std.testing.expectError(error.SizeMismatch, decodeNativeConcatenatedFrameIntoExactSize(stream.items, &reusable_into, "firstsecond".len - 1));
    var oversized_into: ["firstsecond".len + 1]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, decodeNativeConcatenatedFrameIntoExactSize(stream.items, &oversized_into, "firstsecond".len + 1));
    const reusable_exact_into_written = try reusable_decoder.decodeConcatenatedIntoSliceExactSize(stream.items, &reusable_into, "firstsecond".len);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), reusable_exact_into_written);

    const chunks = [_][]const u8{
        stream.items[0..3],
        stream.items[3 .. stream.items.len - 2],
        stream.items[stream.items.len - 2 ..],
        stream.items[stream.items.len..],
    };
    const join = try std.testing.allocator.alloc(u8, stream.items.len);
    defer std.testing.allocator.free(join);
    var chunked_exact_into: ["firstsecond".len]u8 = undefined;
    const chunked_exact_written = try decodeConcatenatedFrameChunksIntoExactSize(&chunks, join, &chunked_exact_into, "firstsecond".len);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), chunked_exact_written);
    try std.testing.expectEqualSlices(u8, "firstsecond", &chunked_exact_into);
    try std.testing.expectError(error.OutputTooSmall, decodeNativeConcatenatedFrameChunksIntoExactSize(&chunks, join, chunked_exact_into[0 .. chunked_exact_into.len - 1], "firstsecond".len));
    try std.testing.expectError(error.SizeMismatch, decodeNativeConcatenatedFrameChunksIntoExactSize(&chunks, join, &chunked_exact_into, "firstsecond".len - 1));
    const reusable_chunked_exact_written = try reusable_decoder.decodeConcatenatedChunksIntoSliceExactSize(&chunks, join, &chunked_exact_into, "firstsecond".len);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), reusable_chunked_exact_written);

    const limited_decoded = try decodeConcatenatedFrameAllocLimited(std.testing.allocator, stream.items, "firstsecond".len);
    defer std.testing.allocator.free(limited_decoded);
    try std.testing.expectEqualSlices(u8, "firstsecond", limited_decoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeConcatenatedFrameAllocLimited(std.testing.allocator, stream.items, "firstsecond".len - 1),
    );

    var into_buffer: ["firstsecond".len]u8 = undefined;
    const written = try decodeNativeConcatenatedFrameInto(stream.items, &into_buffer);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), written);
    try std.testing.expectEqualSlices(u8, "firstsecond", into_buffer[0..written]);
    try std.testing.expectError(error.OutputTooSmall, decodeConcatenatedFrameInto(stream.items, into_buffer[0 .. into_buffer.len - 1]));

    var truncated_skip = try std.testing.allocator.dupe(u8, skip);
    defer std.testing.allocator.free(truncated_skip);
    std.mem.writeInt(u32, truncated_skip[4..8], "metadata".len + 1, .little);
    try std.testing.expectError(error.TruncatedFrame, decodeConcatenatedFrameAlloc(std.testing.allocator, truncated_skip));
}

test "lz4 decoder handles independent frame and raw overlapping matches" {
    const plain = "hello-lz4-frame";
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try frame.appendSlice(std.testing.allocator, &frame_magic);
    try frame.appendSlice(std.testing.allocator, &.{ 0x60, 0x40 });
    try frame.append(std.testing.allocator, descriptorChecksum(frame.items[4..]));
    var block_header: [4]u8 = undefined;
    std.mem.writeInt(u32, &block_header, 0x8000_0000 | @as(u32, @intCast(plain.len)), .little);
    try frame.appendSlice(std.testing.allocator, &block_header);
    try frame.appendSlice(std.testing.allocator, plain);
    try frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0 });

    const decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, plain, decoded);

    const raw_match = [_]u8{ 0x33, 'a', 'b', 'c', 3, 0 };
    const raw_match_bound = try encodedBlockBound("abcabcabca".len);
    try std.testing.expect(raw_match.len <= raw_match_bound);
    const raw_decoded = try decodeBlockAlloc(std.testing.allocator, &raw_match, 10);
    defer std.testing.allocator.free(raw_decoded);
    try std.testing.expectEqualSlices(u8, "abcabcabca", raw_decoded);
    try std.testing.expectEqual(@as(usize, 10), try decodedBlockSize(&raw_match));
    try std.testing.expectEqual(@as(usize, 10), try decodedBlockSizeLimited(&raw_match, 10));
    try std.testing.expectError(error.OutputLimitExceeded, decodedBlockSizeLimited(&raw_match, 9));
    var raw_into: [10]u8 = undefined;
    const raw_into_written = try decodeBlockIntoSlice(&raw_match, &raw_into, 10);
    try std.testing.expectEqual(@as(usize, 10), raw_into_written);
    try std.testing.expectEqualSlices(u8, "abcabcabca", &raw_into);
    try std.testing.expectError(error.OutputTooSmall, decodeBlockIntoSlice(&raw_match, raw_into[0..9], 10));
    var reusable_block_decoder = BlockDecoder.init(std.testing.allocator);
    defer reusable_block_decoder.deinit();
    var raw_appended: std.ArrayList(u8) = .empty;
    defer raw_appended.deinit(std.testing.allocator);
    try raw_appended.appendSlice(std.testing.allocator, "prefix:");
    const raw_appended_written = try reusable_block_decoder.decodeAppendLimited(&raw_appended, &raw_match, 10);
    try std.testing.expectEqual(@as(usize, 10), raw_appended_written);
    try std.testing.expectEqualSlices(u8, "prefix:abcabcabca", raw_appended.items);
    raw_appended.clearRetainingCapacity();
    try raw_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectError(error.OutputLimitExceeded, reusable_block_decoder.decodeAppendLimited(&raw_appended, &raw_match, 9));
    try std.testing.expectEqualSlices(u8, "prefix:", raw_appended.items);
    const raw_scratch = try reusable_block_decoder.decodeScratch(&raw_match, 10);
    try std.testing.expectEqualSlices(u8, "abcabcabca", raw_scratch);
    const raw_scratch_limited = try reusable_block_decoder.decodeScratchLimited(&raw_match, 10);
    try std.testing.expectEqualSlices(u8, "abcabcabca", raw_scratch_limited);
    try std.testing.expectError(error.OutputLimitExceeded, reusable_block_decoder.decodeScratchLimited(&raw_match, 9));
    try std.testing.expectEqual(@as(usize, 0), reusable_block_decoder.scratch.items.len);

    var long_run: std.ArrayList(u8) = .empty;
    defer long_run.deinit(std.testing.allocator);
    try long_run.appendSlice(std.testing.allocator, &.{ 0x1f, 'a', 1, 0 });
    try long_run.appendNTimes(std.testing.allocator, 255, 15);
    try long_run.append(std.testing.allocator, 251);
    const long_run_decoded = try decodeBlockAlloc(std.testing.allocator, long_run.items, 4096);
    defer std.testing.allocator.free(long_run_decoded);
    for (long_run_decoded) |byte| try std.testing.expectEqual(@as(u8, 'a'), byte);

    const prefix_match = [_]u8{ 0x04, 4, 0 };
    try std.testing.expectError(error.InvalidMatch, decodedBlockSize(&prefix_match));
    try std.testing.expectEqual(@as(usize, 8), try decodedBlockSizeWithPrefix(&prefix_match, "abcdefghijklmnop"));
    try std.testing.expectEqual(@as(usize, 8), try decodedBlockSizeWithPrefixLimited(&prefix_match, "abcdefghijklmnop", 8));
    try std.testing.expectError(error.OutputLimitExceeded, decodedBlockSizeWithPrefixLimited(&prefix_match, "abcdefghijklmnop", 7));
    var prefix_into: [8]u8 = undefined;
    const prefix_into_written = try decodeBlockWithPrefixIntoSlice(std.testing.allocator, &prefix_match, &prefix_into, 8, "abcdefghijklmnop");
    try std.testing.expectEqual(@as(usize, 8), prefix_into_written);
    try std.testing.expectEqualSlices(u8, "mnopmnop", &prefix_into);
    var prefix_into_noalloc: [8 + "abcdefghijklmnop".len]u8 = undefined;
    const prefix_noalloc_written = try decodeBlockWithPrefixIntoSlice(
        std.testing.failing_allocator,
        &prefix_match,
        &prefix_into_noalloc,
        8,
        "abcdefghijklmnop",
    );
    try std.testing.expectEqual(@as(usize, 8), prefix_noalloc_written);
    try std.testing.expectEqualSlices(u8, "mnopmnop", prefix_into_noalloc[0..prefix_noalloc_written]);
    try std.testing.expectError(
        error.OutputTooSmall,
        decodeBlockWithPrefixIntoSlice(std.testing.allocator, &prefix_match, prefix_into[0..7], 8, "abcdefghijklmnop"),
    );
    const prefixed = try decodeBlockWithPrefixAlloc(std.testing.allocator, &prefix_match, 8, "abcdefghijklmnop");
    defer std.testing.allocator.free(prefixed);
    try std.testing.expectEqualSlices(u8, "mnopmnop", prefixed);

    const mixed_prefix_match = [_]u8{ 0x24, 'g', 'h', 6, 0 };
    var mixed_into: [10]u8 = undefined;
    const mixed_written = try decodeBlockWithPrefixIntoSliceNoAlloc(&mixed_prefix_match, &mixed_into, 10, "abcdef");
    try std.testing.expectEqual(@as(usize, 10), mixed_written);
    try std.testing.expectEqualSlices(u8, "ghcdefghcd", &mixed_into);
    var prefix_appended: std.ArrayList(u8) = .empty;
    defer prefix_appended.deinit(std.testing.allocator);
    try prefix_appended.appendSlice(std.testing.allocator, "prefix:");
    const prefix_appended_written = try reusable_block_decoder.decodeWithPrefixAppendLimited(&prefix_appended, &prefix_match, 8, "abcdefghijklmnop");
    try std.testing.expectEqual(@as(usize, 8), prefix_appended_written);
    try std.testing.expectEqualSlices(u8, "prefix:mnopmnop", prefix_appended.items);
    prefix_appended.clearRetainingCapacity();
    try prefix_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectError(error.OutputLimitExceeded, reusable_block_decoder.decodeWithPrefixAppendLimited(&prefix_appended, &prefix_match, 7, "abcdefghijklmnop"));
    try std.testing.expectEqualSlices(u8, "prefix:", prefix_appended.items);
    const prefix_scratch = try reusable_block_decoder.decodeWithPrefixScratch(&prefix_match, 8, "abcdefghijklmnop");
    try std.testing.expectEqualSlices(u8, "mnopmnop", prefix_scratch);
    const prefix_scratch_limited = try reusable_block_decoder.decodeWithPrefixScratchLimited(&prefix_match, 8, "abcdefghijklmnop");
    try std.testing.expectEqualSlices(u8, "mnopmnop", prefix_scratch_limited);
    try std.testing.expectError(error.OutputLimitExceeded, reusable_block_decoder.decodeWithPrefixScratchLimited(&prefix_match, 7, "abcdefghijklmnop"));
    try std.testing.expectEqual(@as(usize, 0), reusable_block_decoder.scratch.items.len);
}

test "lz4 linked frame decoder replays matches across block boundary" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try frame.appendSlice(std.testing.allocator, &frame_magic);
    try frame.appendSlice(std.testing.allocator, &.{ 0x40, 0x40 }); // version=01, linked blocks, 64 KiB max
    try frame.append(std.testing.allocator, descriptorChecksum(frame.items[4..]));

    const first_block = "abcdefghijklmnop";
    var block_header: [4]u8 = undefined;
    std.mem.writeInt(u32, &block_header, 0x8000_0000 | @as(u32, first_block.len), .little);
    try frame.appendSlice(std.testing.allocator, &block_header);
    try frame.appendSlice(std.testing.allocator, first_block);

    // The second block has no literals and one match with offset 4, so it must
    // copy `mnop` from the linked frame history supplied by the first block.
    const linked_match_block = [_]u8{ 0x04, 4, 0 };
    std.mem.writeInt(u32, &block_header, linked_match_block.len, .little);
    try frame.appendSlice(std.testing.allocator, &block_header);
    try frame.appendSlice(std.testing.allocator, &linked_match_block);
    try frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0 });

    const expected = first_block ++ "mnopmnop";
    const decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    try std.testing.expectEqual(@as(usize, expected.len), try decodedFrameSize(frame.items));

    var into_buffer: [expected.len]u8 = undefined;
    const written = try decodeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(@as(usize, expected.len), written);
    try std.testing.expectEqualSlices(u8, expected, into_buffer[0..written]);
}

test "lz4 frame decoder rejects size and checksum mismatches" {
    const input = "payload payload payload";
    const encoded = try encodeFrameAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(encoded);

    var bad_size = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_size);
    std.mem.writeInt(u64, bad_size[6..][0..8], input.len + 1, .little);
    try std.testing.expectError(error.ChecksumMismatch, decodeFrameAlloc(std.testing.allocator, bad_size));

    var bad_checksum = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_checksum);
    bad_checksum[bad_checksum.len - 1] ^= 0x01;
    try std.testing.expectError(error.ChecksumMismatch, decodeFrameAlloc(std.testing.allocator, bad_checksum));
}

test "lz4 native frame decoder validates header, block checksum, and block size" {
    const plain = "hello-lz4-native-block";
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try frame.appendSlice(std.testing.allocator, &frame_magic);
    try frame.appendSlice(std.testing.allocator, &.{ 0x70, 0x40 }); // independent blocks + block checksum, 64 KiB max
    try frame.append(std.testing.allocator, descriptorChecksum(frame.items[4..]));
    var block_header: [4]u8 = undefined;
    std.mem.writeInt(u32, &block_header, 0x8000_0000 | @as(u32, @intCast(plain.len)), .little);
    try frame.appendSlice(std.testing.allocator, &block_header);
    try frame.appendSlice(std.testing.allocator, plain);
    var block_checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &block_checksum, std.hash.XxHash32.hash(0, plain), .little);
    try frame.appendSlice(std.testing.allocator, &block_checksum);
    try frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0 });

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, plain, decoded);
    try std.testing.expectEqual(plain.len, try decodedFrameSize(frame.items));
    var into_buffer: [plain.len]u8 = undefined;
    const into_written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(plain.len, into_written);
    try std.testing.expectEqualSlices(u8, plain, into_buffer[0..into_written]);

    var bad_header = try std.testing.allocator.dupe(u8, frame.items);
    defer std.testing.allocator.free(bad_header);
    bad_header[4] ^= 0x08;
    try std.testing.expectError(error.ChecksumMismatch, decodeNativeFrameAlloc(std.testing.allocator, bad_header));

    var bad_block_checksum = try std.testing.allocator.dupe(u8, frame.items);
    defer std.testing.allocator.free(bad_block_checksum);
    bad_block_checksum[bad_block_checksum.len - 5] ^= 0x01;
    try std.testing.expectError(error.ChecksumMismatch, decodeNativeFrameAlloc(std.testing.allocator, bad_block_checksum));
    try std.testing.expectError(error.ChecksumMismatch, decodedFrameSize(bad_block_checksum));

    var bad_block_size = try std.testing.allocator.dupe(u8, frame.items);
    defer std.testing.allocator.free(bad_block_size);
    std.mem.writeInt(u32, bad_block_size[7..][0..4], 0x8000_0000 | (max_block_history_len + 1), .little);
    try std.testing.expectError(error.CorruptFrame, decodeNativeFrameAlloc(std.testing.allocator, bad_block_size));
}
