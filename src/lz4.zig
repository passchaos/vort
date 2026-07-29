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
    try out.append(allocator, flg);
    try out.append(allocator, @intFromEnum(options.block_size_id) << 4);
    if (options.include_content_size) {
        var content_size: [8]u8 = undefined;
        std.mem.writeInt(u64, &content_size, try checkedUsizeToU64(input.len), .little);
        try out.appendSlice(allocator, &content_size);
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

pub fn encodedBlockBound(input_len: usize) Error!usize {
    return try maxCompressedLen(input_len);
}

fn emitBlockChecksum(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8) Error!void {
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, std.hash.XxHash32.hash(0, block), .little);
    try out.appendSlice(allocator, &checksum);
}

pub fn encodeSkippableFrameAlloc(allocator: std.mem.Allocator, skippable_id: u4, payload: []const u8) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var header: [8]u8 = undefined;
    std.mem.writeInt(u32, header[0..4], skippable_magic_min + @as(u32, skippable_id), .little);
    std.mem.writeInt(u32, header[4..8], try checkedUsizeToU32(payload.len), .little);
    try out.appendSlice(allocator, &header);
    try out.appendSlice(allocator, payload);
    return out.toOwnedSlice(allocator);
}

/// Decode an LZ4 frame. Independent and linked blocks are supported; external
/// dictionaries are not required for frames produced by `encodeFrameAlloc`.
pub fn decodeFrameAlloc(allocator: std.mem.Allocator, frame: []const u8) Error![]u8 {
    const header = try parseFrameHeader(frame);
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

pub fn decodedFrameSize(frame: []const u8) Error!usize {
    return try frameDecodedSizeLimited(frame, std.math.maxInt(usize));
}

pub fn decodedFrameSizeLimited(frame: []const u8, max_output_len: usize) Error!usize {
    return try frameDecodedSizeLimited(frame, max_output_len);
}

pub const decodeNativeFrameAlloc = decodeFrameAlloc;
pub const decodeNativeFrameAllocLimited = decodeFrameAllocLimited;

pub fn decodeConcatenatedFrameAlloc(allocator: std.mem.Allocator, frames: []const u8) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var offset: usize = 0;
    while (offset < frames.len) {
        try decodeNextFrameIntoList(allocator, &out, frames, &offset);
    }
    return out.toOwnedSlice(allocator);
}

pub fn decodeConcatenatedFrameAllocLimited(
    allocator: std.mem.Allocator,
    frames: []const u8,
    max_output_len: usize,
) Error![]u8 {
    const decoded_len = try concatenatedFrameDecodedSizeLimited(frames, max_output_len);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = decodeConcatenatedFrameInto(frames, out) catch |err| switch (err) {
        error.OutputTooSmall => return error.OutputLimitExceeded,
        else => return err,
    };
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodedConcatenatedFrameSize(frames: []const u8) Error!usize {
    return try concatenatedFrameDecodedSizeLimited(frames, std.math.maxInt(usize));
}

pub fn decodeConcatenatedFrameInto(frames: []const u8, output: []u8) Error!usize {
    var offset: usize = 0;
    var written: usize = 0;
    while (offset < frames.len) {
        try decodeNextFrameIntoBuffer(frames, &offset, output, &written);
    }
    return written;
}

pub const decodeNativeConcatenatedFrameAlloc = decodeConcatenatedFrameAlloc;
pub const decodeNativeConcatenatedFrameAllocLimited = decodeConcatenatedFrameAllocLimited;
pub const decodeNativeConcatenatedFrameInto = decodeConcatenatedFrameInto;

/// Decode an LZ4 frame directly into caller-owned storage. The returned length
/// is the number of bytes written. This path shares the strict frame metadata,
/// block-size, block-checksum, content-size, and content-checksum validation of
/// `decodeFrameAlloc` while avoiding heap allocation for applications that can
/// provide the output buffer up front.
pub fn decodeFrameInto(frame: []const u8, output: []u8) Error!usize {
    const header = try parseFrameHeader(frame);
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

pub const decodeNativeFrameInto = decodeFrameInto;

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

const FrameHeader = struct {
    payload_offset: usize,
    block_size_max: usize,
    block_independent: bool,
    block_checksum: bool,
    content_checksum: bool,
    expected_content_size: ?u64,
};

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
    if ((flg & 0x01) != 0) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        offset += 4;
    }
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
    };
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

    pub fn encodeIntoSlice(self: *BlockEncoder, input: []const u8, output: []u8) Error!usize {
        const encoded = try self.encodeAlloc(input);
        defer self.allocator.free(encoded);
        if (output.len < encoded.len) return error.OutputTooSmall;
        @memcpy(output[0..encoded.len], encoded);
        return encoded.len;
    }

    pub fn encodeWithPrefixIntoSlice(self: *BlockEncoder, input: []const u8, prefix: []const u8, output: []u8) Error!usize {
        const encoded = try self.encodeWithPrefixAlloc(input, prefix);
        defer self.allocator.free(encoded);
        if (output.len < encoded.len) return error.OutputTooSmall;
        @memcpy(output[0..encoded.len], encoded);
        return encoded.len;
    }
};

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
    const encoded = try encodeBlockAlloc(allocator, input);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn encodeBlockWithPrefixIntoSlice(allocator: std.mem.Allocator, input: []const u8, prefix: []const u8, output: []u8) Error!usize {
    const encoded = try encodeBlockWithPrefixAlloc(allocator, input, prefix);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
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
    const decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, repeated, decoded);

    const block_encoded = try encodeBlockAlloc(std.testing.allocator, repeated);
    defer std.testing.allocator.free(block_encoded);
    const block_bound = try encodedBlockBound(repeated.len);
    try std.testing.expect(block_encoded.len <= block_bound);
    const block_into = try std.testing.allocator.alloc(u8, block_bound);
    defer std.testing.allocator.free(block_into);
    const block_written = try encodeBlockIntoSlice(std.testing.allocator, repeated, block_into);
    try std.testing.expectEqualSlices(u8, block_encoded, block_into[0..block_written]);
    try std.testing.expectError(error.OutputTooSmall, encodeBlockIntoSlice(std.testing.allocator, repeated, block_into[0 .. block_written - 1]));

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

    const linked = try encodePureFrameWithOptionsAlloc(
        std.testing.allocator,
        repeated,
        .{ .block_mode = .linked, .content_checksum = false },
    );
    defer std.testing.allocator.free(linked);
    try std.testing.expectEqual(@as(u8, 0x48), linked[4]);
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
    appended.clearRetainingCapacity();
    const appended_plain_len = try reusable.append(&appended, "abcabcabca");
    try std.testing.expectEqual(appended.items.len, appended_plain_len);
    const reusable_plain = try reusable.encodeAlloc("abcabcabca");
    defer std.testing.allocator.free(reusable_plain);
    try std.testing.expectEqualSlices(u8, reusable_plain, appended.items);
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

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    try stream.appendSlice(std.testing.allocator, skip);
    try stream.appendSlice(std.testing.allocator, second);

    const decoded = try decodeConcatenatedFrameAlloc(std.testing.allocator, stream.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "firstsecond", decoded);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), try decodedConcatenatedFrameSize(stream.items));

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
