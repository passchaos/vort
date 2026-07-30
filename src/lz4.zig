const std = @import("std");
const core = @import("core.zig");

pub const Error = core.Error || std.mem.Allocator.Error;

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
const max_chain_depth = 8;
const good_match_len = 64;
const lazy_extra_gain = 1;

const Lz4FrameInfo = extern struct {
    blockSizeID: c_int = 7, // LZ4F_max4MB
    blockMode: c_int = 0, // LZ4F_blockLinked; better ratio than independent blocks.
    contentChecksumFlag: c_int = 1,
    frameType: c_int = 0,
    contentSize: c_ulonglong = 0,
    dictID: c_uint = 0,
    blockChecksumFlag: c_int = 0,
};

const Lz4Preferences = extern struct {
    frameInfo: Lz4FrameInfo = .{},
    compressionLevel: c_int = default_compression_level,
    autoFlush: c_uint = 0,
    favorDecSpeed: c_uint = 0,
    reserved: [3]c_uint = .{ 0, 0, 0 },
};

pub const LibFrameOptions = struct {
    include_content_size: bool = true,
    content_checksum: bool = true,
    block_checksum: bool = false,
    block_size_id: BlockSizeId = .max4mb,
    block_mode: BlockMode = .linked,
};

extern fn LZ4F_compressFrameBound(srcSize: usize, preferencesPtr: ?*const Lz4Preferences) usize;
extern fn LZ4F_compressFrame(dstBuffer: *anyopaque, dstCapacity: usize, srcBuffer: *const anyopaque, srcSize: usize, preferencesPtr: ?*const Lz4Preferences) usize;
extern fn LZ4F_isError(code: usize) c_uint;
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
};

pub const NativeDictionary = struct {
    id: u32,
    content: []const u8,

    pub fn init(id: u32, content: []const u8) NativeDictionary {
        return .{ .id = id, .content = content };
    }
};

/// Caller-supplied preset dictionary catalog used when decoding concatenated
/// native streams whose frames can reference different Dictionary_ID values.
pub const NativeDictionarySet = struct {
    dictionaries: []const NativeDictionary,

    pub fn init(dictionaries: []const NativeDictionary) NativeDictionarySet {
        return .{ .dictionaries = dictionaries };
    }

    pub fn find(self: NativeDictionarySet, id: u32) ?NativeDictionary {
        for (self.dictionaries) |dictionary| {
            if (dictionary.id == id) return dictionary;
        }
        return null;
    }
};

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

/// Encode a complete interoperable LZ4 frame using liblz4's high-compression
/// frame encoder. The default level starts at LZ4HC_CLEVEL_OPT_MIN (10)
/// because it closes the C++ reference ratio gap on MCAP chunk workloads while
/// retaining competitive write time. Vort owns this dependency so downstream
/// formats such as MCAP can use tuned LZ4 without carrying compression code
/// themselves.
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
    var preferences = Lz4Preferences{
        .frameInfo = .{
            .blockSizeID = @intFromEnum(options.block_size_id),
            .blockMode = switch (options.block_mode) {
                .linked => 0,
                .independent => 1,
            },
            .contentChecksumFlag = if (options.content_checksum) 1 else 0,
            .contentSize = if (options.include_content_size) try checkedUsizeToU64(input.len) else 0,
            .blockChecksumFlag = if (options.block_checksum) 1 else 0,
        },
        .compressionLevel = level,
    };
    const bound = LZ4F_compressFrameBound(input.len, &preferences);
    if (LZ4F_isError(bound) != 0) return error.CorruptFrame;
    var out = try allocator.alloc(u8, bound);
    errdefer allocator.free(out);
    const written = LZ4F_compressFrame(@ptrCast(out.ptr), out.len, @ptrCast(input.ptr), input.len, &preferences);
    if (LZ4F_isError(written) != 0) return error.CorruptFrame;
    if (allocator.remap(out, written)) |shrunk| return shrunk;
    const exact = try allocator.dupe(u8, out[0..written]);
    allocator.free(out);
    return exact;
}

/// Dependency-free pure Zig LZ4 frame encoder retained for bootstrapping and
/// differential testing. Blocks use a bounded hash-chain parser with one-byte
/// lazy matching, linked frames seed the parser from the previous 64 KiB of
/// decoded history, and all blocks fall back to uncompressed storage when
/// compression expands the input.
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
            try encodeBlockInto(allocator, out, block, hash_table, occupancy_bits, chain_table)
        else
            try encodeLinkedBlockInto(allocator, out, history, block, hash_table, occupancy_bits, chain_table);
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
pub const decodeNativeFrameAppendLimited = decodeFrameAppendLimited;
pub const decodeNativeFrameAllocLimited = decodeFrameAllocLimited;
pub const decodeNativeFrameAllocExactSize = decodeFrameAllocExactSize;
pub const decodeNativeFrameAllocWithDictionary = decodeFrameAllocWithDictionary;
pub const decodeNativeFrameAllocWithDictionaryExactSize = decodeFrameAllocWithDictionaryExactSize;
pub const decodeNativeFrameAppendWithDictionary = decodeFrameAppendWithDictionary;
pub const decodeNativeFrameAppendLimitedWithDictionary = decodeFrameAppendLimitedWithDictionary;
pub const decodeNativeFrameAllocLimitedWithDictionary = decodeFrameAllocLimitedWithDictionary;
pub const decodeNativeFrameAllocWithDictionarySet = decodeFrameAllocWithDictionarySet;
pub const decodeNativeFrameAllocWithDictionarySetExactSize = decodeFrameAllocWithDictionarySetExactSize;
pub const decodeNativeFrameAppendWithDictionarySet = decodeFrameAppendWithDictionarySet;
pub const decodeNativeFrameAppendLimitedWithDictionarySet = decodeFrameAppendLimitedWithDictionarySet;
pub const decodeNativeFrameAllocLimitedWithDictionarySet = decodeFrameAllocLimitedWithDictionarySet;
pub const decodedNativeFrameSizeWithDictionary = decodedFrameSizeWithDictionary;
pub const decodedNativeFrameSizeLimitedWithDictionary = decodedFrameSizeLimitedWithDictionary;
pub const decodedNativeFrameSizeWithDictionarySet = decodedFrameSizeWithDictionarySet;
pub const decodedNativeFrameSizeLimitedWithDictionarySet = decodedFrameSizeLimitedWithDictionarySet;

/// Incremental input/output facade for native LZ4 frames.
///
/// This streaming slice accepts compressed bytes in arbitrary input chunks and
/// emits decoded bytes through caller-provided output chunks. It can now walk a
/// concatenated native stream, including LZ4 skippable metadata frames, while
/// still buffering each complete data frame before delegating block/checksum
/// validation to the one-shot decoder. Keeping frame validation centralized
/// preserves behavior while the public `StepResult` contract evolves toward a
/// true block-by-block decoder.
pub const NativeIncrementalFrameDecoder = struct {
    allocator: std.mem.Allocator,
    dictionary: ?NativeDictionary = null,
    dictionary_set: ?NativeDictionarySet = null,
    options: Options = .{},
    phase: Phase = .frame,
    frame_scratch: std.ArrayList(u8) = .empty,
    decoded_scratch: std.ArrayList(u8) = .empty,
    decoded_offset: usize = 0,
    input_received: usize = 0,
    output_written: usize = 0,
    last_error_name: []const u8 = "",
    last_error_phase: ?Phase = null,

    pub const Phase = enum { frame, output, done };

    pub const Options = struct {
        /// Maximum compressed bytes retained while waiting for one complete
        /// data frame or skippable frame. The current facade still validates
        /// through the one-shot decoder, so callers that process hostile or
        /// untrusted streams should set this to their container/frame limit.
        max_compressed_buffer_len: usize = std.math.maxInt(usize),
        /// Maximum decoded bytes retained for one complete data frame before
        /// draining to caller-owned output chunks. This is a per-frame cap, not
        /// a cap on cumulative output across a concatenated stream.
        max_decoded_buffer_len: usize = std.math.maxInt(usize),
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
        self.decoded_scratch.deinit(self.allocator);
        self.frame_scratch.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *NativeIncrementalFrameDecoder) void {
        self.phase = .frame;
        self.frame_scratch.clearRetainingCapacity();
        self.decoded_scratch.clearRetainingCapacity();
        self.decoded_offset = 0;
        self.input_received = 0;
        self.output_written = 0;
        self.last_error_name = "";
        self.last_error_phase = null;
    }

    pub fn snapshot(self: *const NativeIncrementalFrameDecoder) Snapshot {
        const decoded_len: ?usize = if (self.phase == .frame) null else self.decoded_scratch.items.len;
        const decoded_remaining: ?usize = if (self.phase == .frame) null else self.decoded_scratch.items.len - self.decoded_offset;
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

    pub fn step(self: *NativeIncrementalFrameDecoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .done) {
            if (input.len == 0) return .{ .status = .done };
            // Treat fresh input after a completed frame as the next member of a
            // caller-driven concatenated stream.  Cumulative counters are kept
            // intact; `reset()` remains the explicit way to start a new logical
            // decode session with zeroed diagnostics.
            self.phase = .frame;
            self.decoded_scratch.clearRetainingCapacity();
            self.decoded_offset = 0;
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

                    self.decodeCompleteFrame(self.frame_scratch.items[0..frame_end]) catch |err| {
                        self.recordError(.frame, err);
                        return err;
                    };
                    self.discardFrameScratchPrefix(frame_end);
                    self.phase = .output;
                },
                .output => {
                    if (self.decoded_offset == self.decoded_scratch.items.len) {
                        if (self.frame_scratch.items.len != 0) {
                            self.phase = .frame;
                            continue;
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
                    const n = @min(self.decoded_scratch.items.len - self.decoded_offset, output.len - output_written_step);
                    @memcpy(output[output_written_step..][0..n], self.decoded_scratch.items[self.decoded_offset..][0..n]);
                    self.decoded_offset += n;
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

    pub fn decodeAppendWithDictionary(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frame: []const u8, dictionary: NativeDictionary) Error!usize {
        return try decodeFrameAppendWithDictionary(self.allocator, out, frame, dictionary);
    }

    pub fn decodeAppendWithDictionarySet(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frame: []const u8, dictionary_set: NativeDictionarySet) Error!usize {
        return try decodeFrameAppendWithDictionarySet(self.allocator, out, frame, dictionary_set);
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

    pub fn decodeConcatenatedAppendWithDictionary(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frames: []const u8, dictionary: NativeDictionary) Error!usize {
        return try decodeConcatenatedFrameAppendWithDictionary(self.allocator, out, frames, dictionary);
    }

    pub fn decodeConcatenatedAppendWithDictionarySet(self: *NativeFrameDecoder, out: *std.ArrayList(u8), frames: []const u8, dictionary_set: NativeDictionarySet) Error!usize {
        return try decodeConcatenatedFrameAppendWithDictionarySet(self.allocator, out, frames, dictionary_set);
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

pub fn decodeConcatenatedFrameChunksInto(chunks: []const []const u8, compressed_scratch: []u8, output: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameInto(joined, output);
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

pub fn decodeConcatenatedFrameChunksIntoWithDictionary(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary: NativeDictionary) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameIntoWithDictionary(joined, output, dictionary);
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

pub fn decodeConcatenatedFrameChunksIntoWithDictionarySet(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, dictionary_set: NativeDictionarySet) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeConcatenatedFrameIntoWithDictionarySet(joined, output, dictionary_set);
}

pub const decodeNativeConcatenatedFrameAlloc = decodeConcatenatedFrameAlloc;
pub const decodeNativeConcatenatedFrameAllocExactSize = decodeConcatenatedFrameAllocExactSize;
pub const decodeNativeConcatenatedFrameAppend = decodeConcatenatedFrameAppend;
pub const decodeNativeConcatenatedFrameAppendLimited = decodeConcatenatedFrameAppendLimited;
pub const decodeNativeConcatenatedFrameAllocLimited = decodeConcatenatedFrameAllocLimited;
pub const decodeNativeConcatenatedFrameInto = decodeConcatenatedFrameInto;
pub const decodeNativeConcatenatedFrameAllocWithDictionary = decodeConcatenatedFrameAllocWithDictionary;
pub const decodeNativeConcatenatedFrameAllocWithDictionaryExactSize = decodeConcatenatedFrameAllocWithDictionaryExactSize;
pub const decodeNativeConcatenatedFrameAppendWithDictionary = decodeConcatenatedFrameAppendWithDictionary;
pub const decodeNativeConcatenatedFrameAppendLimitedWithDictionary = decodeConcatenatedFrameAppendLimitedWithDictionary;
pub const decodeNativeConcatenatedFrameAllocLimitedWithDictionary = decodeConcatenatedFrameAllocLimitedWithDictionary;
pub const decodeNativeConcatenatedFrameIntoWithDictionary = decodeConcatenatedFrameIntoWithDictionary;
pub const decodeNativeConcatenatedFrameAllocWithDictionarySet = decodeConcatenatedFrameAllocWithDictionarySet;
pub const decodeNativeConcatenatedFrameAllocWithDictionarySetExactSize = decodeConcatenatedFrameAllocWithDictionarySetExactSize;
pub const decodeNativeConcatenatedFrameAppendWithDictionarySet = decodeConcatenatedFrameAppendWithDictionarySet;
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
pub const decodeNativeConcatenatedFrameChunksInto = decodeConcatenatedFrameChunksInto;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionary = decodeConcatenatedFrameChunksAllocWithDictionary;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionaryExactSize = decodeConcatenatedFrameChunksAllocWithDictionaryExactSize;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionaryLimited = decodeConcatenatedFrameChunksAllocWithDictionaryLimited;
pub const decodeNativeConcatenatedFrameChunksIntoWithDictionary = decodeConcatenatedFrameChunksIntoWithDictionary;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionarySet = decodeConcatenatedFrameChunksAllocWithDictionarySet;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionarySetExactSize = decodeConcatenatedFrameChunksAllocWithDictionarySetExactSize;
pub const decodeNativeConcatenatedFrameChunksAllocWithDictionarySetLimited = decodeConcatenatedFrameChunksAllocWithDictionarySetLimited;
pub const decodeNativeConcatenatedFrameChunksIntoWithDictionarySet = decodeConcatenatedFrameChunksIntoWithDictionarySet;

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
    var offset: usize = 0;
    var summary: NativeStreamSummary = .{};
    while (offset < frames.len) {
        if (frames.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frames[offset..][0..4], .little);
        if (magic == frame_magic_u32) {
            const start = offset;
            const end = try findFrameEnd(frames, &offset);
            const frame_summary = try summarizeNativeFrameBlocks(frames[start..end]);
            summary.frame_count += 1;
            summary.block_count = std.math.add(usize, summary.block_count, frame_summary.block_count) catch return error.IntegerOverflow;
            summary.compressed_block_count = std.math.add(usize, summary.compressed_block_count, frame_summary.compressed_block_count) catch return error.IntegerOverflow;
            summary.raw_block_count = std.math.add(usize, summary.raw_block_count, frame_summary.raw_block_count) catch return error.IntegerOverflow;
            summary.payload_bytes = std.math.add(usize, summary.payload_bytes, frame_summary.payload_bytes) catch return error.IntegerOverflow;
        } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            if (frames.len - offset < 8) return error.TruncatedFrame;
            const skip_len: usize = @intCast(std.mem.readInt(u32, frames[offset + 4 ..][0..4], .little));
            offset += 8;
            if (frames.len - offset < skip_len) return error.TruncatedFrame;
            summary.skippable_frame_count += 1;
            summary.skippable_payload_bytes = std.math.add(usize, summary.skippable_payload_bytes, skip_len) catch return error.IntegerOverflow;
            offset += skip_len;
        } else {
            return error.CorruptFrame;
        }
    }
    return summary;
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

    pub fn encodeWithPrefixAlloc(self: *BlockEncoder, input: []const u8, prefix: []const u8) Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(self.allocator);
        _ = try self.appendWithPrefix(&out, input, prefix);
        return out.toOwnedSlice(self.allocator);
    }

    pub fn append(self: *BlockEncoder, out: *std.ArrayList(u8), input: []const u8) Error!usize {
        return try encodeBlockInto(self.allocator, out, input, self.hash_table, self.occupancy_bits, self.chain_table);
    }

    pub fn appendWithPrefix(self: *BlockEncoder, out: *std.ArrayList(u8), input: []const u8, prefix: []const u8) Error!usize {
        const history = prefix[if (prefix.len > max_match_offset) prefix.len - max_match_offset else 0..];
        return try encodeLinkedBlockInto(self.allocator, out, history, input, self.hash_table, self.occupancy_bits, self.chain_table);
    }

    pub fn encodeScratch(self: *BlockEncoder, input: []const u8) Error![]const u8 {
        self.output_scratch.clearRetainingCapacity();
        _ = self.append(&self.output_scratch, input) catch |err| {
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

    pub fn encodeIntoSlice(self: *BlockEncoder, input: []const u8, output: []u8) Error!usize {
        const scratch = try self.encodeScratch(input);
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
                try self.block_encoder.append(out, block)
            else
                try self.block_encoder.appendWithPrefix(out, block, history);
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
};

fn optionsWithNativeDictionary(options: NativeFrameOptions, dictionary: ?NativeDictionary) NativeFrameOptions {
    var with_dictionary = options;
    if (dictionary) |dict| with_dictionary.dictionary_id = dict.id;
    return with_dictionary;
}

pub fn encodeBlockAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
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
    _ = try encodeBlockInto(allocator, &out, input, hash_table, occupancy_bits, chain_table);
    return out.toOwnedSlice(allocator);
}

pub fn encodeBlockWithPrefixAlloc(allocator: std.mem.Allocator, input: []const u8, prefix: []const u8) Error![]u8 {
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
    _ = try encodeLinkedBlockInto(allocator, &out, history, input, hash_table, occupancy_bits, chain_table);
    return out.toOwnedSlice(allocator);
}

pub fn encodeBlockIntoSlice(allocator: std.mem.Allocator, input: []const u8, output: []u8) Error!usize {
    var encoder = try BlockEncoder.init(allocator);
    defer encoder.deinit();
    return try encoder.encodeIntoSlice(input, output);
}

pub fn encodeBlockWithPrefixIntoSlice(allocator: std.mem.Allocator, input: []const u8, prefix: []const u8, output: []u8) Error!usize {
    var encoder = try BlockEncoder.init(allocator);
    defer encoder.deinit();
    return try encoder.encodeWithPrefixIntoSlice(input, prefix, output);
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
        @memcpy(output[written.*..][0..literal_len], input[offset..][0..literal_len]);
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
    while (index + 12 <= input.len) {
        var match_index = index;
        var best = insertAndFindBest(input, index, table, occupancy_bits, chain_table);
        if (best.len != 0 and index + 13 <= input.len and best.len < good_match_len) {
            const next = insertAndFindBest(input, index + 1, table, occupancy_bits, chain_table);
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
    while (index + 12 <= virtual_len) {
        var match_index = index;
        var best = insertAndFindBestLinked(history, input, index, table, occupancy_bits, chain_table);
        if (best.len != 0 and index + 13 <= virtual_len and best.len < good_match_len) {
            const next = insertAndFindBestLinked(history, input, index + 1, table, occupancy_bits, chain_table);
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
) Match {
    const candidate_entry = insertHash(input, index, table, occupancy_bits, chain_table);

    var best: Match = .{};
    var candidate = candidate_entry;
    var depth: usize = 0;
    while (candidate != invalid_pos and depth < max_chain_depth) : (depth += 1) {
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
) Match {
    const virtual_len = history.len + input.len;
    const candidate_entry = insertLinkedHash(history, input, index, table, occupancy_bits, chain_table);

    var best: Match = .{};
    var candidate = candidate_entry;
    var depth: usize = 0;
    while (candidate != invalid_pos and depth < max_chain_depth) : (depth += 1) {
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

test "lz4 lib frame encoder round trips and compresses repetitive payloads" {
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
    try std.testing.expectEqual(@as(u8, 0x60), no_content_fields[4]);
    try std.testing.expectEqual(@as(u8, 0x40), no_content_fields[5]);
    const no_content_decoded = try decodeFrameAlloc(std.testing.allocator, no_content_fields);
    defer std.testing.allocator.free(no_content_decoded);
    try std.testing.expectEqualSlices(u8, repeated, no_content_decoded);
    try std.testing.expectEqual(repeated.len, try decodedFrameSize(no_content_fields));
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

    var decoder = NativeIncrementalFrameDecoder.init(std.testing.allocator);
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

    var decoder = NativeIncrementalFrameDecoder.init(std.testing.allocator);
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
}

test "lz4 native incremental decoder enforces buffer limits" {
    const payload = "bounded incremental lz4 payload " ** 8;
    const encoded = try encodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = false,
        .block_checksum = true,
    });
    defer std.testing.allocator.free(encoded);

    var compressed_limited = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .max_compressed_buffer_len = encoded.len - 1,
    });
    defer compressed_limited.deinit();
    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, compressed_limited.step(encoded, output[0..0]));
    try std.testing.expectEqual(encoded.len - 1, compressed_limited.snapshot().input_received);
    try std.testing.expectEqualSlices(u8, "OutputLimitExceeded", compressed_limited.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", compressed_limited.diagnostics().last_error_phase_name);

    var decoded_limited = NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .max_decoded_buffer_len = payload.len - 1,
    });
    defer decoded_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, decoded_limited.step(encoded, &output));
    try std.testing.expectEqual(encoded.len, decoded_limited.snapshot().input_received);
    try std.testing.expectEqualSlices(u8, "OutputLimitExceeded", decoded_limited.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", decoded_limited.diagnostics().last_error_phase_name);
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

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeNativeConcatenatedFrameAppendWithDictionary(std.testing.allocator, &appended, stream.items, dict));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, appended.items);

    var decoder = NativeFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    const scratch = try decoder.decodeConcatenatedScratchWithDictionary(stream.items, dict);
    try std.testing.expectEqualSlices(u8, expected, scratch);
}

test "lz4 native concatenated streams select dictionaries by id" {
    const first_dict = NativeDictionary.init(0x1010, "abcdefghijklmnop");
    const second_dict = NativeDictionary.init(0x2020, "qrstuvwxyz123456");
    const dictionaries = [_]NativeDictionary{ first_dict, second_dict };
    const dictionary_set = NativeDictionarySet.init(&dictionaries);
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
