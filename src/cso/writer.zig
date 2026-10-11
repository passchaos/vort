const std = @import("std");
const deflate = @import("../deflate.zig");
const lz4 = @import("../lz4.zig");
const format = @import("format.zig");

pub const Error = format.Error || deflate.Error || lz4.Error ||
    std.mem.Allocator.Error;

pub const Compression = enum {
    raw,
    deflate,
    lz4,
    auto,
};

pub const EncodeOptions = struct {
    format: format.Format = .cso1,
    compression: Compression = .auto,
    block_size: u32 = 2048,
    compression_level: u8 = 6,
    index_shift: ?u8 = null,
};

const Candidate = struct {
    bytes: []const u8,
    codec: format.Codec,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    try validateOptions(options);
    const block_count = std.math.divCeil(
        usize,
        input.len,
        options.block_size,
    ) catch return error.IntegerOverflow;
    const index_entries = std.math.add(usize, block_count, 1) catch
        return error.IntegerOverflow;
    const index_bytes = std.math.mul(usize, index_entries, 4) catch
        return error.IntegerOverflow;
    const data_start = std.math.add(usize, format.header_size, index_bytes) catch
        return error.IntegerOverflow;
    const index_shift = if (options.index_shift) |shift|
        shift
    else
        try chooseIndexShift(data_start, block_count, options.block_size);
    if (index_shift > 32 or
        (@as(u64, 1) << @intCast(index_shift)) > options.block_size)
        return error.InvalidCso;
    const alignment: usize = @as(usize, 1) << @intCast(index_shift);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(allocator, 0, data_start);
    try appendAlignment(allocator, &output, alignment);

    const padded_block = try allocator.alloc(u8, options.block_size);
    defer allocator.free(padded_block);
    var lz4_encoder: ?lz4.BlockEncoder = if (usesLz4(options))
        try lz4.BlockEncoder.init(allocator)
    else
        null;
    defer if (lz4_encoder) |*encoder| encoder.deinit();

    for (0..block_count) |block_index| {
        const index_offset = format.header_size + block_index * 4;
        const stored_offset = output.items.len;
        var raw_index = try encodeIndexOffset(stored_offset, index_shift);
        const source_start = block_index * @as(usize, options.block_size);
        const source_len = @min(
            input.len - source_start,
            @as(usize, options.block_size),
        );
        @memset(padded_block, 0);
        @memcpy(padded_block[0..source_len], input[source_start..][0..source_len]);

        const deflated = if (usesDeflate(options))
            try deflate.encodeRawLevelAlloc(
                allocator,
                padded_block,
                @intCast(options.compression_level),
            )
        else
            null;
        defer if (deflated) |bytes| allocator.free(bytes);
        const lz4_bytes = if (lz4_encoder) |*encoder|
            try encoder.encodeAlloc(padded_block)
        else
            null;
        defer if (lz4_bytes) |bytes| allocator.free(bytes);
        const candidate = try chooseCandidate(
            options,
            padded_block,
            deflated,
            lz4_bytes,
            stored_offset,
            alignment,
        );
        raw_index |= indexFlag(options.format, candidate.codec);
        format.writeU32Le(output.items, index_offset, raw_index);
        try output.appendSlice(allocator, candidate.bytes);
        try appendAlignment(allocator, &output, alignment);
    }
    const final_index = try encodeIndexOffset(output.items.len, index_shift);
    format.writeU32Le(
        output.items,
        format.header_size + block_count * 4,
        final_index,
    );
    writeHeader(output.items[0..format.header_size], input.len, options, index_shift);
    return output.toOwnedSlice(allocator);
}

fn validateOptions(options: EncodeOptions) Error!void {
    if (options.block_size < format.minimum_block_size or
        options.block_size > format.maximum_block_size or
        !std.math.isPowerOfTwo(options.block_size) or
        options.compression_level == 0 or options.compression_level > 9)
        return error.InvalidCso;
    switch (options.format) {
        .cso1 => if (options.compression == .lz4)
            return error.UnsupportedCsoCodec,
        .zso => if (options.compression == .deflate)
            return error.UnsupportedCsoCodec,
        .cso2 => {},
    }
}

fn usesDeflate(options: EncodeOptions) bool {
    return switch (options.format) {
        .cso1 => options.compression != .raw,
        .zso => false,
        .cso2 => options.compression == .deflate or options.compression == .auto,
    };
}

fn usesLz4(options: EncodeOptions) bool {
    return switch (options.format) {
        .cso1 => false,
        .zso => options.compression != .raw,
        .cso2 => options.compression == .lz4 or options.compression == .auto,
    };
}

fn chooseCandidate(
    options: EncodeOptions,
    raw: []const u8,
    deflated: ?[]const u8,
    lz4_bytes: ?[]const u8,
    stored_offset: usize,
    alignment: usize,
) Error!Candidate {
    var best: Candidate = .{ .bytes = raw, .codec = .raw };
    if (deflated) |bytes| {
        if (try alignedSpan(stored_offset, bytes.len, alignment) < raw.len and
            bytes.len < best.bytes.len)
            best = .{ .bytes = bytes, .codec = .deflate };
    }
    if (lz4_bytes) |bytes| {
        if (try alignedSpan(stored_offset, bytes.len, alignment) < raw.len and
            (bytes.len < best.bytes.len or
                (bytes.len == best.bytes.len and best.codec == .deflate)))
            best = .{ .bytes = bytes, .codec = .lz4 };
    }
    if (options.compression == .raw) return .{ .bytes = raw, .codec = .raw };
    return best;
}

fn indexFlag(image_format: format.Format, codec: format.Codec) u32 {
    return switch (image_format) {
        .cso1, .zso => if (codec == .raw) format.raw_flag else 0,
        .cso2 => if (codec == .lz4) format.raw_flag else 0,
    };
}

fn writeHeader(
    output: []u8,
    input_len: usize,
    options: EncodeOptions,
    index_shift: u8,
) void {
    @memset(output, 0);
    @memcpy(output[0..4], options.format.magic());
    format.writeU32Le(output, 4, format.header_size);
    format.writeU64Le(output, 8, input_len);
    format.writeU32Le(output, 16, options.block_size);
    output[20] = options.format.version();
    output[21] = index_shift;
}

fn chooseIndexShift(
    data_start: usize,
    block_count: usize,
    block_size: u32,
) Error!u8 {
    var shift: u8 = 0;
    while (shift <= 32) : (shift += 1) {
        const alignment: u64 = @as(u64, 1) << @intCast(shift);
        if (alignment > block_size) break;
        const start = alignForwardU64(data_start, alignment) catch
            return error.IntegerOverflow;
        const per_block = std.math.add(
            u64,
            block_size,
            alignment - 1,
        ) catch return error.IntegerOverflow;
        const blocks_bytes = std.math.mul(
            u64,
            block_count,
            per_block,
        ) catch return error.IntegerOverflow;
        const worst_end = std.math.add(u64, start, blocks_bytes) catch
            return error.IntegerOverflow;
        if ((worst_end >> @intCast(shift)) <= format.offset_mask)
            return shift;
    }
    return error.OutputLimitExceeded;
}

fn encodeIndexOffset(offset: usize, shift: u8) Error!u32 {
    const alignment: usize = @as(usize, 1) << @intCast(shift);
    if (offset % alignment != 0) return error.InvalidCso;
    const shifted = offset >> @intCast(shift);
    if (shifted > format.offset_mask) return error.OutputLimitExceeded;
    return @intCast(shifted);
}

fn appendAlignment(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    alignment: usize,
) Error!void {
    const remainder = output.items.len % alignment;
    const aligned = if (remainder == 0)
        output.items.len
    else
        std.math.add(
            usize,
            output.items.len,
            alignment - remainder,
        ) catch return error.IntegerOverflow;
    try output.appendNTimes(allocator, 0, aligned - output.items.len);
}

fn alignedSpan(
    start: usize,
    length: usize,
    alignment: usize,
) Error!usize {
    const end = std.math.add(usize, start, length) catch
        return error.IntegerOverflow;
    const remainder = end % alignment;
    const aligned = if (remainder == 0)
        end
    else
        std.math.add(usize, end, alignment - remainder) catch
            return error.IntegerOverflow;
    return aligned - start;
}

fn alignForwardU64(value: usize, alignment: u64) !u64 {
    const converted: u64 = value;
    const remainder = converted % alignment;
    return if (remainder == 0)
        converted
    else
        std.math.add(u64, converted, alignment - remainder);
}
