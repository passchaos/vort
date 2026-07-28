const std = @import("std");
const core = @import("core.zig");

pub const Error = core.Error || std.mem.Allocator.Error;

pub const default_compression_level: c_int = 1;

const frame_magic = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd };
const frame_magic_u32: u32 = 0xfd2fb528;
const skippable_magic_min: u32 = 0x184d2a50;
const skippable_magic_max: u32 = 0x184d2a5f;
const min_rle_split_len = 12;

extern fn ZSTD_compressBound(srcSize: usize) usize;
extern fn ZSTD_compress(dst: *anyopaque, dstCapacity: usize, src: *const anyopaque, srcSize: usize, compressionLevel: c_int) usize;
extern fn ZSTD_getFrameContentSize(src: *const anyopaque, srcSize: usize) c_ulonglong;
extern fn ZSTD_decompress(dst: *anyopaque, dstCapacity: usize, src: *const anyopaque, compressedSize: usize) usize;
extern fn ZSTD_isError(code: usize) c_uint;

const zstd_content_size_unknown = std.math.maxInt(c_ulonglong);
const zstd_content_size_error = std.math.maxInt(c_ulonglong) - 1;

pub const NativeFrameSelection = enum {
    auto,
    raw_or_rle,
    literal_only,
};

pub const NativeFrameOptions = struct {
    content_checksum: bool = true,
    include_content_size: bool = true,
    selection: NativeFrameSelection = .auto,
};

pub const NativeFrameMode = enum {
    raw_or_rle,
    literal_only,
};

pub const NativeFrameEncodeResult = struct {
    frame: []u8,
    mode: NativeFrameMode,
};

/// Decode a Zstandard frame. Prefer libzstd's one-shot decoder when the
/// content size is present, because MCAP chunks always advertise their decoded
/// size and the one-shot path avoids streaming allocator overhead. Frames with
/// unknown content size still fall back to Zig std's streaming decoder.
pub fn decodeFrameAlloc(allocator: std.mem.Allocator, frame: []const u8) Error![]u8 {
    const content_size = ZSTD_getFrameContentSize(@ptrCast(frame.ptr), frame.len);
    if (content_size == zstd_content_size_error) return error.CorruptFrame;
    if (content_size != zstd_content_size_unknown) {
        const decoded_len = try checkedU64ToUsize(content_size);
        const out = try allocator.alloc(u8, decoded_len);
        errdefer allocator.free(out);
        const written = ZSTD_decompress(@ptrCast(out.ptr), out.len, @ptrCast(frame.ptr), frame.len);
        if (ZSTD_isError(written) != 0) return error.CorruptFrame;
        if (written != decoded_len) return error.SizeMismatch;
        return out;
    }

    var input: std.Io.Reader = .fixed(frame);
    var zstd_stream: std.compress.zstd.Decompress = .init(&input, &.{}, .{});
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    _ = zstd_stream.reader.streamRemaining(&output.writer) catch return error.CorruptFrame;
    if (zstd_stream.err) |_| return error.CorruptFrame;
    return output.toOwnedSlice() catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
    };
}

/// Dependency-free Zstandard decoder for the raw/RLE frame subset emitted by
/// `encodeRawOrRleFrameAlloc`, plus literal-only compressed blocks. It accepts
/// concatenated supported frames and skippable frames, validates frame content
/// sizes and optional content checksums, and deliberately rejects compressed
/// sequence payloads instead of silently falling back to a partial
/// implementation.
pub fn decodeRawOrRleFrameAlloc(allocator: std.mem.Allocator, frame: []const u8) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var offset: usize = 0;
    while (offset < frame.len) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        if (magic == frame_magic_u32) {
            try decodeRawOrRleZstandardFrameInto(allocator, &out, frame, &offset);
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

pub fn decodeRawOrRleFrameAllocLimited(
    allocator: std.mem.Allocator,
    frame: []const u8,
    max_output_len: usize,
) Error![]u8 {
    const decoded_len = try rawOrRleDecodedSizeLimited(frame, max_output_len);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = decodeRawOrRleFrameInto(frame, out) catch |err| switch (err) {
        error.OutputTooSmall => return error.OutputLimitExceeded,
        else => return err,
    };
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodedRawOrRleFrameSize(frame: []const u8) Error!usize {
    return try rawOrRleDecodedSizeLimited(frame, std.math.maxInt(usize));
}

/// Decode the raw/RLE Zstandard subset directly into caller-owned storage.
/// The returned length is the number of bytes written across all concatenated
/// non-skippable frames. This mirrors the allocator-returning fallback but lets
/// embedded/streaming callers preflight capacity and stay allocation-free while
/// still receiving exact checksum, size, and unsupported-feature errors.
pub fn decodeRawOrRleFrameInto(frame: []const u8, output: []u8) Error!usize {
    var offset: usize = 0;
    var written: usize = 0;
    while (offset < frame.len) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        if (magic == frame_magic_u32) {
            try decodeRawOrRleZstandardFrameIntoBuffer(frame, &offset, output, &written);
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
pub const decodeNativeFrameAllocLimited = decodeRawOrRleFrameAllocLimited;
pub const decodeNativeFrameInto = decodeRawOrRleFrameInto;

/// Compress a complete Zstandard frame using the reference-compatible libzstd
/// encoder linked by Vort's build. Keeping this call surface in Vort centralizes
/// compression ownership for downstream formats such as MCAP while leaving room
/// to replace the backend with a pure Zig implementation ported from
/// `~/Work/zstd` internals later.
pub fn encodeFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return try encodeFrameWithLevelAlloc(allocator, input, default_compression_level);
}

pub fn encodeFrameWithLevelAlloc(allocator: std.mem.Allocator, input: []const u8, level: c_int) Error![]u8 {
    const bound = ZSTD_compressBound(input.len);
    if (ZSTD_isError(bound) != 0) return error.CorruptFrame;
    var out = try allocator.alloc(u8, bound);
    errdefer allocator.free(out);

    const written = ZSTD_compress(@ptrCast(out.ptr), out.len, @ptrCast(input.ptr), input.len, level);
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
    try emitFrameHeader(allocator, &out, try checkedUsizeToU64(input.len), options);
    if (input.len == 0) {
        try emitBlock(allocator, &out, "", true);
    } else {
        var offset: usize = 0;
        while (offset < input.len) {
            const search_end = @min(input.len, offset + std.compress.zstd.block_size_max);
            if (findRleRun(input[offset..search_end])) |run| {
                const run_start = offset + run.start;
                if (run_start > offset) try emitBlock(allocator, &out, input[offset..run_start], false);
                const run_end = run_start + run.len;
                try emitRleBlock(allocator, &out, input[run_start], run.len, run_end == input.len);
                offset = run_end;
            } else {
                try emitBlock(allocator, &out, input[offset..search_end], search_end == input.len);
                offset = search_end;
            }
        }
    }
    try emitContentChecksum(allocator, &out, input, options);
    return out.toOwnedSlice(allocator);
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
    try emitFrameHeader(allocator, &out, try checkedUsizeToU64(input.len), options);

    var offset: usize = 0;
    if (input.len == 0) {
        try emitLiteralOnlyCompressedBlock(allocator, &out, "", true);
    } else {
        while (offset < input.len) {
            const block_end = @min(input.len, offset + std.compress.zstd.block_size_max);
            try emitLiteralOnlyCompressedBlock(allocator, &out, input[offset..block_end], block_end == input.len);
            offset = block_end;
        }
    }

    try emitContentChecksum(allocator, &out, input, options);
    return out.toOwnedSlice(allocator);
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

pub fn encodeNativeFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    const result = try encodeNativeFrameWithOptionsAlloc(allocator, input, .{});
    return result.frame;
}

pub fn encodeNativeFrameWithOptionsAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
) Error!NativeFrameEncodeResult {
    switch (options.selection) {
        .raw_or_rle => return .{
            .frame = try encodeRawOrRleFrameWithOptionsAlloc(allocator, input, options),
            .mode = .raw_or_rle,
        },
        .literal_only => return .{
            .frame = try encodeLiteralOnlyFrameWithOptionsAlloc(allocator, input, options),
            .mode = .literal_only,
        },
        .auto => {},
    }

    const raw_or_rle = try encodeRawOrRleFrameWithOptionsAlloc(allocator, input, options);
    errdefer allocator.free(raw_or_rle);
    const literal_only = try encodeLiteralOnlyFrameWithOptionsAlloc(allocator, input, options);
    errdefer allocator.free(literal_only);

    // Keep this selector deliberately simple and deterministic while the native
    // Zstd implementation is still a bootstrap subset. It lets callers use one
    // native API and still benefit if a future literal-only compressed mode beats
    // raw/RLE framing, without hiding which mode was selected from tests/reports.
    if (literal_only.len < raw_or_rle.len) {
        allocator.free(raw_or_rle);
        return .{ .frame = literal_only, .mode = .literal_only };
    }

    allocator.free(literal_only);
    return .{ .frame = raw_or_rle, .mode = .raw_or_rle };
}

fn emitFrameHeader(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    content_len: u64,
    options: NativeFrameOptions,
) Error!void {
    try out.appendSlice(allocator, &frame_magic);

    if (!options.include_content_size) {
        try out.append(allocator, if (options.content_checksum) 0x04 else 0x00);
        try emitWindowDescriptor(allocator, out, content_len);
        return;
    }

    // Use the shortest single-segment Frame_Content_Size encoding permitted by
    // the Zstandard format. The previous bootstrap writer always spent eight
    // bytes here, which was easy to inspect but disproportionately expensive
    // for the tiny raw/RLE frames this dependency-free path is meant to cover.
    const checksum_flag: u8 = if (options.content_checksum) 0x04 else 0;
    if (content_len <= 255) {
        try out.append(allocator, 0x20 | checksum_flag); // fcs=1 byte, single segment
        try out.append(allocator, @intCast(content_len));
    } else if (content_len <= 256 + std.math.maxInt(u16)) {
        try out.append(allocator, 0x60 | checksum_flag); // fcs=2 bytes (+256), single segment
        var size_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &size_bytes, @intCast(content_len - 256), .little);
        try out.appendSlice(allocator, &size_bytes);
    } else if (content_len <= std.math.maxInt(u32)) {
        try out.append(allocator, 0xa0 | checksum_flag); // fcs=4 bytes, single segment
        var size_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &size_bytes, @intCast(content_len), .little);
        try out.appendSlice(allocator, &size_bytes);
    } else {
        try out.append(allocator, 0xe0 | checksum_flag); // fcs=8 bytes, single segment
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

const RawOrRleFrameHeader = struct {
    content_size: ?u64,
    has_checksum: bool,
    block_size_max: usize,
};

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

fn decodeRawOrRleZstandardFrameInto(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frame: []const u8,
    offset: *usize,
) Error!void {
    const header = try parseRawOrRleFrameHeader(frame, offset);
    const frame_out_start = out.items.len;
    if (header.content_size) |size| try out.ensureUnusedCapacity(allocator, try checkedU64ToUsize(size));

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
                try decodeLiteralOnlyCompressedBlockInto(allocator, out, frame[offset.*..][0..block_len], header.block_size_max);
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
) Error!void {
    const header = try parseRawOrRleFrameHeader(frame, offset);
    const frame_out_start = written.*;
    if (header.content_size) |size| {
        const needed = try checkedU64ToUsize(size);
        if (output.len - written.* < needed) return error.OutputTooSmall;
    }

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
                try decodeLiteralOnlyCompressedBlockIntoBuffer(frame[offset.*..][0..block_len], output, written, header.block_size_max);
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
) Error!void {
    const start = out.items.len;
    const decoded_len = try compressedLiteralOnlyBlockDecodedSize(block, block_size_max);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    var written = out.items.len;
    try decodeLiteralOnlyCompressedBlockIntoBuffer(block, out.items.ptr[0..out.capacity], &written, block_size_max);
    out.items.len = written;
    if (out.items.len - start != decoded_len) return error.SizeMismatch;
}

fn decodeLiteralOnlyCompressedBlockIntoBuffer(
    block: []const u8,
    output: []u8,
    written: *usize,
    block_size_max: usize,
) Error!void {
    const section = try parseLiteralsSection(block);
    if (section.sequence_count != 0) return error.UnsupportedZstdFeature;
    if (section.regenerated_size > block_size_max) return error.CorruptFrame;
    if (output.len - written.* < section.regenerated_size) return error.OutputTooSmall;

    switch (section.kind) {
        .raw => {
            @memcpy(output[written.*..][0..section.regenerated_size], block[section.literal_payload_offset..][0..section.regenerated_size]);
            written.* += section.regenerated_size;
        },
        .rle => {
            if (section.regenerated_size == 0) return error.CorruptFrame;
            @memset(output[written.*..][0..section.regenerated_size], block[section.literal_payload_offset]);
            written.* += section.regenerated_size;
        },
    }
}

fn compressedLiteralOnlyBlockDecodedSize(block: []const u8, block_size_max: usize) Error!usize {
    const section = try parseLiteralsSection(block);
    if (section.sequence_count != 0) return error.UnsupportedZstdFeature;
    if (section.regenerated_size > block_size_max) return error.CorruptFrame;
    return section.regenerated_size;
}

fn compressedLiteralOnlyBlockDecodedSizeLimited(
    block: []const u8,
    total: usize,
    max_output_len: usize,
    block_size_max: usize,
) Error!usize {
    const decoded_len = try compressedLiteralOnlyBlockDecodedSize(block, block_size_max);
    return checkedAddWithinLimit(total, decoded_len, max_output_len);
}

const LiteralsKind = enum { raw, rle };

const LiteralOnlySection = struct {
    kind: LiteralsKind,
    regenerated_size: usize,
    literal_payload_offset: usize,
    sequence_count: usize,
};

fn parseLiteralsSection(block: []const u8) Error!LiteralOnlySection {
    var offset: usize = 0;
    const literal_header = try parseLiteralsHeader(block, &offset);
    const literal_payload_offset = offset;
    const literal_payload_len: usize = switch (literal_header.kind) {
        .raw => literal_header.regenerated_size,
        .rle => 1,
    };
    if (block.len - offset < literal_payload_len) return error.TruncatedFrame;
    offset += literal_payload_len;
    const sequence_count = try parseSequenceCount(block, &offset);
    if (offset != block.len) return error.UnsupportedZstdFeature;
    return .{
        .kind = literal_header.kind,
        .regenerated_size = literal_header.regenerated_size,
        .literal_payload_offset = literal_payload_offset,
        .sequence_count = sequence_count,
    };
}

const LiteralsHeaderInfo = struct {
    kind: LiteralsKind,
    regenerated_size: usize,
};

fn parseLiteralsHeader(block: []const u8, offset: *usize) Error!LiteralsHeaderInfo {
    if (offset.* >= block.len) return error.TruncatedFrame;
    const byte0 = block[offset.*];
    offset.* += 1;
    const block_type = byte0 & 0x03;
    const size_format = (byte0 >> 2) & 0x03;
    const kind: LiteralsKind = switch (block_type) {
        0 => .raw,
        1 => .rle,
        else => return error.UnsupportedZstdFeature,
    };

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
    return .{ .kind = kind, .regenerated_size = regenerated_size };
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

fn rawOrRleDecodedSizeLimited(frame: []const u8, max_output_len: usize) Error!usize {
    var offset: usize = 0;
    var total: usize = 0;
    while (offset < frame.len) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        if (magic == frame_magic_u32) {
            const header = try parseRawOrRleFrameHeader(frame, &offset);
            const frame_start = total;
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
                        total = try compressedLiteralOnlyBlockDecodedSizeLimited(frame[offset..][0..block_len], total, max_output_len, header.block_size_max);
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

fn parseRawOrRleFrameHeader(frame: []const u8, offset: *usize) Error!RawOrRleFrameHeader {
    if (frame.len - offset.* < 1) return error.TruncatedFrame;
    const descriptor = frame[offset.*];
    offset.* += 1;

    if ((descriptor & 0x08) != 0) return error.CorruptFrame;
    if ((descriptor & 0x10) != 0) return error.UnsupportedZstdFeature;

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
    offset.* += dictionary_id_len;

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
        .block_size_max = block_size_max,
    };
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

fn emitLiteralOnlyCompressedBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, last: bool) Error!void {
    const literal_kind: LiteralsKind = if (rleByte(block) != null) .rle else .raw;
    const literal_payload_len: usize = switch (literal_kind) {
        .raw => block.len,
        .rle => 1,
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

fn emitLiteralsHeader(allocator: std.mem.Allocator, out: *std.ArrayList(u8), kind: LiteralsKind, regenerated_size: usize) Error!void {
    _ = try literalsHeaderLen(regenerated_size);
    const kind_bits: u8 = switch (kind) {
        .raw => 0,
        .rle => 1,
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

test "zstd lib encoder round trips and compresses repeated payloads" {
    const payload = "zstd payload zstd payload zstd payload zstd payload";
    const encoded = try encodeFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < payload.len);
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

    var into_buffer: ["firstsecond".len]u8 = undefined;
    const written = try decodeRawOrRleFrameInto(stream.items, &into_buffer);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), written);
    try std.testing.expectEqualSlices(u8, "firstsecond", into_buffer[0..written]);
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

test "zstd literal-only compressed block rejects malformed sections" {
    var non_zero_sequences: std.ArrayList(u8) = .empty;
    defer non_zero_sequences.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &non_zero_sequences, 3, .{});
    try emitBlockHeader(std.testing.allocator, &non_zero_sequences, 2, 6, true);
    try non_zero_sequences.append(std.testing.allocator, 3 << 3);
    try non_zero_sequences.appendSlice(std.testing.allocator, "abc");
    try non_zero_sequences.appendSlice(std.testing.allocator, &.{ 1, 0 }); // one sequence, predefined mode byte
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, "abc")), .little);
    try non_zero_sequences.appendSlice(std.testing.allocator, &checksum);
    try std.testing.expectError(error.UnsupportedZstdFeature, decodeNativeFrameAlloc(std.testing.allocator, non_zero_sequences.items));

    var trailing_literal_payload: std.ArrayList(u8) = .empty;
    defer trailing_literal_payload.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &trailing_literal_payload, 3, .{});
    try emitBlockHeader(std.testing.allocator, &trailing_literal_payload, 2, 6, true);
    try trailing_literal_payload.append(std.testing.allocator, 3 << 3);
    try trailing_literal_payload.appendSlice(std.testing.allocator, "abcd");
    try trailing_literal_payload.append(std.testing.allocator, 0);
    try trailing_literal_payload.appendSlice(std.testing.allocator, &checksum);
    try std.testing.expectError(error.UnsupportedZstdFeature, decodeNativeFrameAlloc(std.testing.allocator, trailing_literal_payload.items));

    var missing_literal_byte: std.ArrayList(u8) = .empty;
    defer missing_literal_byte.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &missing_literal_byte, 3, .{});
    try emitBlockHeader(std.testing.allocator, &missing_literal_byte, 2, 2, true);
    try missing_literal_byte.append(std.testing.allocator, (3 << 3) | 1); // RLE literals need one payload byte.
    try missing_literal_byte.append(std.testing.allocator, 0);
    try missing_literal_byte.appendSlice(std.testing.allocator, &checksum);
    try std.testing.expectError(error.TruncatedFrame, decodeNativeFrameAlloc(std.testing.allocator, missing_literal_byte.items));
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
    const section = try parseLiteralsSection(encoded[block_offset + 3 ..][0..block_len]);
    try std.testing.expectEqual(LiteralsKind.rle, section.kind);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(encoded, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);
}

test "zstd native frame writer chooses smallest fallback mode" {
    const repeated = "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz";
    const repeated_result = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, repeated, .{});
    defer std.testing.allocator.free(repeated_result.frame);
    try std.testing.expectEqual(NativeFrameMode.raw_or_rle, repeated_result.mode);
    const repeated_decoded = try decodeNativeFrameAlloc(std.testing.allocator, repeated_result.frame);
    defer std.testing.allocator.free(repeated_decoded);
    try std.testing.expectEqualSlices(u8, repeated, repeated_decoded);

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

    const no_checksum = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, literal_payload, .{ .content_checksum = false, .selection = .literal_only });
    defer std.testing.allocator.free(no_checksum.frame);
    try std.testing.expectEqual(@as(u8, 0x20), no_checksum.frame[4]);
    const no_size = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, literal_payload, .{ .include_content_size = false, .selection = .literal_only });
    defer std.testing.allocator.free(no_size.frame);
    try std.testing.expectEqual(@as(u8, 0x04), no_size.frame[4]);
    const no_size_decoded = try decodeNativeFrameAlloc(std.testing.allocator, no_size.frame);
    defer std.testing.allocator.free(no_size_decoded);
    try std.testing.expectEqualSlices(u8, literal_payload, no_size_decoded);
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
    try std.testing.expectError(error.UnsupportedZstdFeature, decodeRawOrRleFrameAlloc(std.testing.allocator, compressed_block));

    try std.testing.expectError(error.TruncatedFrame, decodeRawOrRleFrameAlloc(std.testing.allocator, encoded[0 .. encoded.len - 1]));
    try std.testing.expectError(error.InvalidMagic, decodeRawOrRleFrameAlloc(std.testing.allocator, "not-zstd"));
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

test "zstd native raw/RLE decoder rejects general compressed frames" {
    const payload = "zstd payload zstd payload zstd payload zstd payload";
    const encoded = try encodeFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    try std.testing.expectError(error.UnsupportedZstdFeature, decodeNativeFrameAlloc(std.testing.allocator, encoded));
}
