const std = @import("std");
const core = @import("core.zig");
const bitstream = @import("bitstream.zig");
const huffman = @import("huffman.zig");

pub const Error = core.Error || std.mem.Allocator.Error;

pub const max_uncompressed_meta_block_len: usize = 1 << 24;

pub const default_window_bits: u5 = 16;

pub const StoredStreamOptions = struct {
    window_bits: u5 = default_window_bits,
    metadata: []const u8 = "",
};

const BitWriter = struct {
    out: *std.ArrayList(u8),
    bit_index: u3 = 0,

    fn writeBits(self: *BitWriter, allocator: std.mem.Allocator, value: u64, count: u6) Error!void {
        if (count > 64) return error.CorruptFrame;
        var remaining = count;
        var cursor = value;
        while (remaining > 0) : (remaining -= 1) {
            if (self.bit_index == 0) try self.out.append(allocator, 0);
            if ((cursor & 1) != 0) self.out.items[self.out.items.len - 1] |= @as(u8, 1) << self.bit_index;
            cursor >>= 1;
            self.bit_index +%= 1;
        }
    }

    fn alignToByte(self: *BitWriter) void {
        self.bit_index = 0;
    }

    fn writeAlignedBytes(self: *BitWriter, allocator: std.mem.Allocator, bytes: []const u8) Error!void {
        if (self.bit_index != 0) return error.CorruptFrame;
        try self.out.appendSlice(allocator, bytes);
    }
};

pub fn PrefixCode(comptime alphabet_size: usize) type {
    return struct {
        single_symbol: ?u16 = null,
        table: huffman.HuffmanTable(alphabet_size) = .{},

        const Self = @This();

        pub fn decode(self: *const Self, reader: *bitstream.BitReader) Error!u16 {
            if (self.single_symbol) |symbol| return symbol;
            return try self.table.decodeValue(reader);
        }
    };
}

const MinimalCompressedHeader = struct {
    npostfix: u2,
    ndirect: u16,
    literal_context_mode: u2,
    literal: PrefixCode(256),
    insert_copy: PrefixCode(704),
    distance: PrefixCode(max_distance_alphabet_size),
};

const max_distance_alphabet_size = 16 + 120 + (48 << 3);
const initial_last_distances = [_]usize{ 16, 15, 11, 4 };

const InsertCopyLengths = struct {
    insert_len: usize,
    copy_len: usize,
    distance_symbol_zero: bool,
};

pub fn encodeStoredStreamAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return try encodeStoredStreamWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeStoredStreamWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: StoredStreamOptions) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try encodeStoredStreamWithOptionsAppend(allocator, &out, input, options);
    return out.toOwnedSlice(allocator);
}

pub fn encodeStoredStreamAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8) Error!void {
    try encodeStoredStreamWithOptionsAppend(allocator, out, input, .{});
}

pub fn encodeStoredStreamWithOptionsAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, options: StoredStreamOptions) Error!void {
    var writer = BitWriter{ .out = out };
    try writeWindowBits(allocator, &writer, options.window_bits);
    if (options.metadata.len != 0) try writeMetadataMetaBlock(allocator, &writer, options.metadata);

    var offset: usize = 0;
    while (offset < input.len) {
        const block_len = @min(input.len - offset, max_uncompressed_meta_block_len);
        try writeUncompressedMetaBlock(allocator, &writer, input[offset..][0..block_len]);
        offset += block_len;
    }

    // End with an empty final meta-block. Brotli forbids marking an
    // uncompressed meta-block as the last one, so even non-empty stored streams
    // need this explicit terminator.
    try writer.writeBits(allocator, 1, 1); // ISLAST
    try writer.writeBits(allocator, 1, 1); // ISLASTEMPTY
}

pub fn encodeStoredStreamInto(input: []const u8, output: []u8) Error!usize {
    return try encodeStoredStreamWithOptionsInto(input, output, .{});
}

pub fn encodeStoredStreamWithOptionsInto(input: []const u8, output: []u8, options: StoredStreamOptions) Error!usize {
    var fba = std.heap.FixedBufferAllocator.init(output);
    const encoded = try encodeStoredStreamWithOptionsAlloc(fba.allocator(), input, options);
    return encoded.len;
}

fn writeUncompressedMetaBlock(allocator: std.mem.Allocator, writer: *BitWriter, block: []const u8) Error!void {
    if (block.len == 0 or block.len > max_uncompressed_meta_block_len) return error.InvalidBlockPlan;
    const len_minus_one = block.len - 1;
    const mnibbles: usize = if (len_minus_one <= 0xffff)
        4
    else if (len_minus_one <= 0xfffff)
        5
    else
        6;
    const mnibbles_code: u2 = switch (mnibbles) {
        4 => 0b00,
        5 => 0b01,
        6 => 0b10,
        else => unreachable,
    };

    try writer.writeBits(allocator, 0, 1); // ISLAST = false.
    try writer.writeBits(allocator, mnibbles_code, 2);
    try writer.writeBits(allocator, @intCast(len_minus_one), @intCast(mnibbles * 4));
    try writer.writeBits(allocator, 1, 1); // ISUNCOMPRESSED.
    writer.alignToByte();
    try writer.writeAlignedBytes(allocator, block);
}

fn writeMetadataMetaBlock(allocator: std.mem.Allocator, writer: *BitWriter, metadata: []const u8) Error!void {
    if (metadata.len > 0x1_0000) return error.InvalidBlockPlan;
    try writer.writeBits(allocator, 0, 1); // ISLAST = false.
    try writer.writeBits(allocator, 0b11, 2); // MNIBBLES = 0.
    try writer.writeBits(allocator, 0, 1); // reserved.
    if (metadata.len == 0) {
        try writer.writeBits(allocator, 0, 2); // MSKIPBYTES = 0.
    } else {
        const len_minus_one = metadata.len - 1;
        const mskipbytes: usize = if (len_minus_one <= 0xff) 1 else 2;
        try writer.writeBits(allocator, @intCast(mskipbytes), 2);
        try writer.writeBits(allocator, @intCast(len_minus_one), @intCast(mskipbytes * 8));
    }
    writer.alignToByte();
    try writer.writeAlignedBytes(allocator, metadata);
}

pub fn decodeStreamAlloc(allocator: std.mem.Allocator, stream: []const u8) Error![]u8 {
    return try decodeStreamAllocLimited(allocator, stream, std.math.maxInt(usize));
}

pub fn decodeStreamAllocLimited(allocator: std.mem.Allocator, stream: []const u8, max_output_len: usize) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    _ = try decodeStreamAppendLimited(allocator, &out, stream, max_output_len);
    return out.toOwnedSlice(allocator);
}

pub fn decodeStreamAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), stream: []const u8) Error!usize {
    return try decodeStreamAppendLimited(allocator, out, stream, std.math.maxInt(usize));
}

pub fn decodeStreamAppendLimited(allocator: std.mem.Allocator, out: *std.ArrayList(u8), stream: []const u8, max_output_len: usize) Error!usize {
    const decoded_len = try decodedStreamSizeLimited(stream, max_output_len);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeStreamInto(stream, slot) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeStreamInto(stream: []const u8, output: []u8) Error!usize {
    var reader = bitstream.BitReader.init(stream);
    try readWindowBits(&reader);
    var written: usize = 0;
    var last_distances = initial_last_distances;
    while (true) {
        const is_last = try reader.readBits(u1, 1) == 1;
        if (is_last) {
            const is_last_empty = try reader.readBits(u1, 1) == 1;
            if (is_last_empty) {
                try ensureZeroPaddingAndEnd(reader);
                return written;
            }
        }

        const mnibbles_code = try reader.readBits(u2, 2);
        const mnibbles: usize = switch (mnibbles_code) {
            0b00 => 4,
            0b01 => 5,
            0b10 => 6,
            0b11 => 0,
        };
        if (mnibbles == 0) {
            try skipMetadataMetaBlock(&reader);
            continue;
        }
        const len_minus_one = try reader.readBits(u32, @intCast(mnibbles * 4));
        if (mnibbles > 4 and ((len_minus_one >> @intCast((mnibbles - 1) * 4)) & 0xf) == 0) return error.CorruptFrame;
        const meta_block_len = std.math.add(usize, len_minus_one, 1) catch return error.IntegerOverflow;
        if (is_last) {
            try processMinimalCompressedMetaBlock(&reader, output, &written, meta_block_len, &last_distances);
            try ensureZeroPaddingAndEnd(reader);
            return written;
        }
        const is_uncompressed = try reader.readBits(u1, 1) == 1;
        if (!is_uncompressed) {
            try processMinimalCompressedMetaBlock(&reader, output, &written, meta_block_len, &last_distances);
            continue;
        }
        try consumeZeroPaddingToByte(&reader);
        if (output.len - written < meta_block_len) return error.OutputTooSmall;
        try reader.readAlignedBytes(output[written..][0..meta_block_len]);
        written += meta_block_len;
    }
}

pub fn decodedStreamSize(stream: []const u8) Error!usize {
    return try decodedStreamSizeLimited(stream, std.math.maxInt(usize));
}

pub fn decodedStreamSizeLimited(stream: []const u8, max_output_len: usize) Error!usize {
    var reader = bitstream.BitReader.init(stream);
    try readWindowBits(&reader);
    var total: usize = 0;
    var last_distances = initial_last_distances;
    while (true) {
        const is_last = try reader.readBits(u1, 1) == 1;
        if (is_last) {
            const is_last_empty = try reader.readBits(u1, 1) == 1;
            if (is_last_empty) {
                try ensureZeroPaddingAndEnd(reader);
                return total;
            }
        }

        const mnibbles_code = try reader.readBits(u2, 2);
        const mnibbles: usize = switch (mnibbles_code) {
            0b00 => 4,
            0b01 => 5,
            0b10 => 6,
            0b11 => 0,
        };
        if (mnibbles == 0) {
            try skipMetadataMetaBlock(&reader);
            continue;
        }
        const len_minus_one = try reader.readBits(u32, @intCast(mnibbles * 4));
        if (mnibbles > 4 and ((len_minus_one >> @intCast((mnibbles - 1) * 4)) & 0xf) == 0) return error.CorruptFrame;
        const meta_block_len = std.math.add(usize, len_minus_one, 1) catch return error.IntegerOverflow;
        const meta_block_start = total;
        total = std.math.add(usize, total, meta_block_len) catch return error.IntegerOverflow;
        if (total > max_output_len) return error.OutputLimitExceeded;
        if (is_last) {
            try skipMinimalCompressedMetaBlock(&reader, meta_block_start, meta_block_len, &last_distances);
            try ensureZeroPaddingAndEnd(reader);
            return total;
        }
        const is_uncompressed = try reader.readBits(u1, 1) == 1;
        if (!is_uncompressed) {
            try skipMinimalCompressedMetaBlock(&reader, meta_block_start, meta_block_len, &last_distances);
            continue;
        }
        try consumeZeroPaddingToByte(&reader);
        if (reader.byte_index > stream.len or stream.len - reader.byte_index < meta_block_len) return error.TruncatedFrame;
        reader.byte_index += meta_block_len;
    }
}

fn readWindowBits(reader: *bitstream.BitReader) Error!void {
    _ = try readWindowBitsValue(reader);
}

fn readBlockTypeCount(reader: *bitstream.BitReader) Error!u16 {
    const first = try reader.readBits(u1, 1);
    if (first == 0) return 1;

    const selector = try reader.readBits(u3, 3);
    if (selector == 0) return 2;

    const extra = try reader.readBits(u16, selector);
    return (@as(u16, 1) << selector) + 1 + extra;
}

fn readMinimalCompressedHeader(reader: *bitstream.BitReader) Error!MinimalCompressedHeader {
    const nbltypes_l = try readBlockTypeCount(reader);
    if (nbltypes_l != 1) return error.UnsupportedBrotliFeature;
    const nbltypes_i = try readBlockTypeCount(reader);
    if (nbltypes_i != 1) return error.UnsupportedBrotliFeature;
    const nbltypes_d = try readBlockTypeCount(reader);
    if (nbltypes_d != 1) return error.UnsupportedBrotliFeature;

    const npostfix = try reader.readBits(u2, 2);
    const ndirect_high = try reader.readBits(u4, 4);
    const ndirect: u16 = @as(u16, ndirect_high) << npostfix;
    if (ndirect > 120) return error.CorruptFrame;
    const distance_alphabet_size: usize = 16 + @as(usize, ndirect) + (@as(usize, 48) << npostfix);

    const literal_context_mode = try reader.readBits(u2, 2);

    const ntrees_l = try readBlockTypeCount(reader);
    if (ntrees_l != 1) return error.UnsupportedBrotliFeature;
    const ntrees_d = try readBlockTypeCount(reader);
    if (ntrees_d != 1) return error.UnsupportedBrotliFeature;

    return .{
        .npostfix = npostfix,
        .ndirect = ndirect,
        .literal_context_mode = literal_context_mode,
        .literal = try readPrefixCode(256, reader),
        .insert_copy = try readPrefixCode(704, reader),
        .distance = try readPrefixCodeRuntime(max_distance_alphabet_size, distance_alphabet_size, reader),
    };
}

fn readInsertCopyLengths(symbol: u16, reader: *bitstream.BitReader) Error!InsertCopyLengths {
    if (symbol >= 704) return error.InvalidHuffmanCode;
    const ranges = insertCopyCodeRanges(symbol);
    const insert_code = ranges.insert_base + ((symbol >> 3) & 0x7);
    const copy_code = ranges.copy_base + (symbol & 0x7);
    const insert = try readInsertLength(insert_code, reader);
    const copy = try readCopyLength(copy_code, reader);
    return .{
        .insert_len = insert,
        .copy_len = copy,
        .distance_symbol_zero = symbol < 128,
    };
}

fn processMinimalCompressedMetaBlock(
    reader: *bitstream.BitReader,
    output: []u8,
    written: *usize,
    meta_block_len: usize,
    last_distances: *[4]usize,
) Error!void {
    const meta_block_end = std.math.add(usize, written.*, meta_block_len) catch return error.IntegerOverflow;
    if (meta_block_end > output.len) return error.OutputTooSmall;
    const header = try readMinimalCompressedHeader(reader);
    while (written.* < meta_block_end) {
        const command_symbol = try header.insert_copy.decode(reader);
        const lengths = try readInsertCopyLengths(command_symbol, reader);
        if (lengths.insert_len > meta_block_end - written.*) return error.CorruptFrame;
        var i: usize = 0;
        while (i < lengths.insert_len) : (i += 1) {
            const literal = try header.literal.decode(reader);
            if (literal > 0xff) return error.InvalidHuffmanCode;
            output[written.*] = @intCast(literal);
            written.* += 1;
        }
        if (written.* == meta_block_end) {
            return;
        }
        const distance = try readMinimalDistance(&header, reader, lengths, last_distances);
        if (distance == 0 or distance > written.*) return error.InvalidMatch;
        if (lengths.copy_len > meta_block_end - written.*) return error.CorruptFrame;
        var copy_index: usize = 0;
        while (copy_index < lengths.copy_len) : (copy_index += 1) {
            output[written.*] = output[written.* - distance];
            written.* += 1;
        }
    }
}

fn skipMinimalCompressedMetaBlock(
    reader: *bitstream.BitReader,
    start_written: usize,
    meta_block_len: usize,
    last_distances: *[4]usize,
) Error!void {
    const meta_block_end = std.math.add(usize, start_written, meta_block_len) catch return error.IntegerOverflow;
    const header = try readMinimalCompressedHeader(reader);
    var written = start_written;
    while (written < meta_block_end) {
        const command_symbol = try header.insert_copy.decode(reader);
        const lengths = try readInsertCopyLengths(command_symbol, reader);
        if (lengths.insert_len > meta_block_end - written) return error.CorruptFrame;
        var i: usize = 0;
        while (i < lengths.insert_len) : (i += 1) {
            _ = try header.literal.decode(reader);
            written += 1;
        }
        if (written == meta_block_end) {
            return;
        }
        const distance = try readMinimalDistance(&header, reader, lengths, last_distances);
        if (distance == 0 or distance > written) return error.InvalidMatch;
        if (lengths.copy_len > meta_block_end - written) return error.CorruptFrame;
        written += lengths.copy_len;
    }
}

fn readMinimalDistance(
    header: *const MinimalCompressedHeader,
    reader: *bitstream.BitReader,
    lengths: InsertCopyLengths,
    last_distances: *[4]usize,
) Error!usize {
    const symbol = if (lengths.distance_symbol_zero) 0 else try header.distance.decode(reader);
    if (symbol < 16) {
        const distance = try resolveShortDistance(symbol, last_distances);
        if (symbol != 0) pushLastDistance(last_distances, distance);
        return distance;
    }
    const direct_index = symbol - 16;
    const distance = if (direct_index < header.ndirect)
        @as(usize, direct_index) + 1
    else
        try readRegularDistance(header, reader, symbol);
    pushLastDistance(last_distances, distance);
    return distance;
}

fn readRegularDistance(header: *const MinimalCompressedHeader, reader: *bitstream.BitReader, symbol: u16) Error!usize {
    const xcode = @as(usize, symbol) - @as(usize, header.ndirect) - 16;
    const npostfix: usize = header.npostfix;
    const ndistbits_value = 1 + (xcode >> @intCast(npostfix + 1));
    if (ndistbits_value > 24) return error.CorruptFrame;
    const ndistbits: u5 = @intCast(ndistbits_value);
    const dextra = if (ndistbits == 0) 0 else try reader.readBits(u32, ndistbits);
    return try resolveRegularDistance(header.npostfix, header.ndirect, symbol, dextra);
}

fn resolveRegularDistance(npostfix: u2, ndirect: u16, symbol: u16, dextra: usize) Error!usize {
    if (symbol < 16 + @as(usize, ndirect)) return error.InvalidHuffmanCode;
    const xcode = @as(usize, symbol) - @as(usize, ndirect) - 16;
    const npostfix_usize: usize = npostfix;
    const ndistbits = 1 + (xcode >> @intCast(npostfix_usize + 1));
    if (ndistbits > 24) return error.CorruptFrame;

    const hcode = xcode >> @intCast(npostfix_usize);
    const postfix_mask = (@as(usize, 1) << @intCast(npostfix_usize)) - 1;
    const lcode = xcode & postfix_mask;
    const offset = ((@as(usize, 2) + (hcode & 1)) << @intCast(ndistbits)) - 4;
    const base_with_extra = std.math.add(usize, offset, dextra) catch return error.IntegerOverflow;
    const shifted = base_with_extra << @intCast(npostfix_usize);
    const with_postfix = std.math.add(usize, shifted, lcode) catch return error.IntegerOverflow;
    const with_direct = std.math.add(usize, with_postfix, ndirect) catch return error.IntegerOverflow;
    return std.math.add(usize, with_direct, 1) catch return error.IntegerOverflow;
}

fn resolveShortDistance(symbol: u16, last_distances: *const [4]usize) Error!usize {
    return switch (symbol) {
        0 => last_distances[3],
        1 => last_distances[2],
        2 => last_distances[1],
        3 => last_distances[0],
        4 => try distanceWithDelta(last_distances[3], -1),
        5 => try distanceWithDelta(last_distances[3], 1),
        6 => try distanceWithDelta(last_distances[3], -2),
        7 => try distanceWithDelta(last_distances[3], 2),
        8 => try distanceWithDelta(last_distances[3], -3),
        9 => try distanceWithDelta(last_distances[3], 3),
        10 => try distanceWithDelta(last_distances[2], -1),
        11 => try distanceWithDelta(last_distances[2], 1),
        12 => try distanceWithDelta(last_distances[2], -2),
        13 => try distanceWithDelta(last_distances[2], 2),
        14 => try distanceWithDelta(last_distances[2], -3),
        15 => try distanceWithDelta(last_distances[2], 3),
        else => error.InvalidHuffmanCode,
    };
}

fn distanceWithDelta(base: usize, delta: i8) Error!usize {
    if (delta < 0) {
        const magnitude: usize = @intCast(-delta);
        if (base <= magnitude) return error.InvalidMatch;
        return base - magnitude;
    }
    return std.math.add(usize, base, @intCast(delta)) catch return error.IntegerOverflow;
}

fn pushLastDistance(last_distances: *[4]usize, distance: usize) void {
    last_distances[0] = last_distances[1];
    last_distances[1] = last_distances[2];
    last_distances[2] = last_distances[3];
    last_distances[3] = distance;
}

const InsertCopyCodeRanges = struct {
    insert_base: u16,
    copy_base: u16,
};

fn insertCopyCodeRanges(symbol: u16) InsertCopyCodeRanges {
    if (symbol < 64) return .{ .insert_base = 0, .copy_base = 0 };
    if (symbol < 128) return .{ .insert_base = 0, .copy_base = 8 };
    if (symbol < 192) return .{ .insert_base = 0, .copy_base = 0 };
    if (symbol < 256) return .{ .insert_base = 0, .copy_base = 8 };
    if (symbol < 320) return .{ .insert_base = 8, .copy_base = 0 };
    if (symbol < 384) return .{ .insert_base = 8, .copy_base = 8 };
    if (symbol < 448) return .{ .insert_base = 0, .copy_base = 16 };
    if (symbol < 512) return .{ .insert_base = 16, .copy_base = 0 };
    if (symbol < 576) return .{ .insert_base = 8, .copy_base = 16 };
    if (symbol < 640) return .{ .insert_base = 16, .copy_base = 8 };
    return .{ .insert_base = 16, .copy_base = 16 };
}

const LengthSpec = struct {
    base: usize,
    extra_bits: u5,
};

fn readInsertLength(code: u16, reader: *bitstream.BitReader) Error!usize {
    const spec = insertLengthSpec(code);
    const extra = if (spec.extra_bits == 0) 0 else try reader.readBits(u32, spec.extra_bits);
    return spec.base + extra;
}

fn readCopyLength(code: u16, reader: *bitstream.BitReader) Error!usize {
    const spec = copyLengthSpec(code);
    const extra = if (spec.extra_bits == 0) 0 else try reader.readBits(u32, spec.extra_bits);
    return spec.base + extra;
}

fn insertLengthSpec(code: u16) LengthSpec {
    return switch (code) {
        0...5 => .{ .base = code, .extra_bits = 0 },
        6...7 => .{ .base = 6 + (@as(usize, code - 6) << 1), .extra_bits = 1 },
        8...9 => .{ .base = 10 + (@as(usize, code - 8) << 2), .extra_bits = 2 },
        10...11 => .{ .base = 18 + (@as(usize, code - 10) << 3), .extra_bits = 3 },
        12...13 => .{ .base = 34 + (@as(usize, code - 12) << 4), .extra_bits = 4 },
        14...15 => .{ .base = 66 + (@as(usize, code - 14) << 5), .extra_bits = 5 },
        16 => .{ .base = 130, .extra_bits = 6 },
        17 => .{ .base = 194, .extra_bits = 7 },
        18 => .{ .base = 322, .extra_bits = 8 },
        19 => .{ .base = 578, .extra_bits = 9 },
        20 => .{ .base = 1090, .extra_bits = 10 },
        21 => .{ .base = 2114, .extra_bits = 12 },
        22 => .{ .base = 6210, .extra_bits = 14 },
        23 => .{ .base = 22594, .extra_bits = 24 },
        else => unreachable,
    };
}

fn copyLengthSpec(code: u16) LengthSpec {
    return switch (code) {
        0...7 => .{ .base = 2 + code, .extra_bits = 0 },
        8...9 => .{ .base = 10 + (@as(usize, code - 8) << 1), .extra_bits = 1 },
        10...11 => .{ .base = 14 + (@as(usize, code - 10) << 2), .extra_bits = 2 },
        12...13 => .{ .base = 22 + (@as(usize, code - 12) << 3), .extra_bits = 3 },
        14...15 => .{ .base = 38 + (@as(usize, code - 14) << 4), .extra_bits = 4 },
        16 => .{ .base = 70, .extra_bits = 5 },
        17 => .{ .base = 102, .extra_bits = 5 },
        18 => .{ .base = 134, .extra_bits = 6 },
        19 => .{ .base = 198, .extra_bits = 7 },
        20 => .{ .base = 326, .extra_bits = 8 },
        21 => .{ .base = 582, .extra_bits = 9 },
        22 => .{ .base = 1094, .extra_bits = 10 },
        23 => .{ .base = 2118, .extra_bits = 24 },
        else => unreachable,
    };
}

fn readPrefixCode(comptime alphabet_size: usize, reader: *bitstream.BitReader) Error!PrefixCode(alphabet_size) {
    return try readPrefixCodeRuntime(alphabet_size, alphabet_size, reader);
}

fn readPrefixCodeRuntime(comptime max_alphabet_size: usize, alphabet_size: usize, reader: *bitstream.BitReader) Error!PrefixCode(max_alphabet_size) {
    if (alphabet_size == 0 or alphabet_size > max_alphabet_size) return error.CorruptFrame;
    const kind = try reader.readBits(u2, 2);
    if (kind != 1) return try readComplexPrefixCodeRuntime(max_alphabet_size, alphabet_size, reader, kind);

    const nsym = @as(usize, try reader.readBits(u2, 2)) + 1;
    const alphabet_bits = alphabetBitsRuntime(alphabet_size);
    var symbols: [4]u16 = undefined;
    for (0..nsym) |i| {
        const symbol = try reader.readBits(u16, alphabet_bits);
        if (symbol >= alphabet_size) return error.InvalidHuffmanCode;
        for (symbols[0..i]) |previous| {
            if (previous == symbol) return error.InvalidHuffmanCode;
        }
        symbols[i] = symbol;
    }

    var lengths: [max_alphabet_size]u4 = @splat(0);
    switch (nsym) {
        1 => return .{ .single_symbol = symbols[0] },
        2 => {
            lengths[symbols[0]] = 1;
            lengths[symbols[1]] = 1;
        },
        3 => {
            lengths[symbols[0]] = 1;
            lengths[symbols[1]] = 2;
            lengths[symbols[2]] = 2;
        },
        4 => {
            const tree_select = try reader.readBits(u1, 1);
            if (tree_select == 0) {
                for (symbols) |symbol| lengths[symbol] = 2;
            } else {
                lengths[symbols[0]] = 1;
                lengths[symbols[1]] = 2;
                lengths[symbols[2]] = 3;
                lengths[symbols[3]] = 3;
            }
        },
        else => unreachable,
    }

    return .{ .table = try huffman.HuffmanTable(max_alphabet_size).init(&lengths) };
}

const code_length_alphabet_size = 18;
const code_length_order = [_]u5{ 1, 2, 3, 4, 0, 5, 17, 6, 16, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

fn readComplexPrefixCodeRuntime(comptime max_alphabet_size: usize, alphabet_size: usize, reader: *bitstream.BitReader, hskip: u2) Error!PrefixCode(max_alphabet_size) {
    if (hskip == 1) return error.CorruptFrame;

    var code_length_lengths: [code_length_alphabet_size]u4 = @splat(0);
    var code_length_space: i32 = 32;
    var code_length_nonzero: usize = 0;
    var code_length_index: usize = if (hskip == 0) 0 else hskip;
    while (code_length_index < code_length_order.len) : (code_length_index += 1) {
        const length = try readCodeLengthCodeLength(reader);
        const symbol = code_length_order[code_length_index];
        code_length_lengths[symbol] = length;
        if (length != 0) {
            code_length_nonzero += 1;
            code_length_space -= @intCast(@as(u32, 32) >> length);
            if (code_length_space < 0) return error.InvalidHuffmanCode;
            if (code_length_space == 0) {
                if (code_length_nonzero < 2) return error.InvalidHuffmanCode;
                break;
            }
        }
    }
    if (code_length_nonzero == 0) return error.InvalidHuffmanCode;
    if (code_length_space != 0 and code_length_index == code_length_order.len) {
        if (code_length_nonzero != 1) return error.InvalidHuffmanCode;
    } else if (code_length_space != 0) {
        return error.InvalidHuffmanCode;
    }

    const code_length_prefix = if (code_length_nonzero == 1)
        singleSymbolPrefixCode(code_length_alphabet_size, &code_length_lengths)
    else
        PrefixCode(code_length_alphabet_size){ .table = try huffman.HuffmanTable(code_length_alphabet_size).init(&code_length_lengths) };

    var lengths: [max_alphabet_size]u4 = @splat(0);
    var index: usize = 0;
    var space: i32 = 32768;
    var last_nonzero_length: u4 = 8;
    var previous_repeat_symbol: ?u16 = null;
    var pending_repeat_count: usize = 0;
    var pending_repeat_length: u4 = 0;
    var last_symbol: ?u16 = null;
    while (index < alphabet_size and space > 0) {
        const symbol = try code_length_prefix.decode(reader);
        switch (symbol) {
            0 => {
                try flushPendingRepeat(alphabet_size, max_alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
                lengths[index] = 0;
                index += 1;
            },
            1...15 => {
                try flushPendingRepeat(alphabet_size, max_alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
                const length: u4 = @intCast(symbol);
                lengths[index] = length;
                index += 1;
                last_nonzero_length = length;
                space -= @intCast(@as(u32, 32768) >> length);
                if (space < 0) return error.InvalidHuffmanCode;
            },
            16 => {
                const repeat = @as(usize, try reader.readBits(u2, 2)) + 3;
                if (previous_repeat_symbol == 16) {
                    pending_repeat_count = 4 * (pending_repeat_count - 2) + repeat;
                } else {
                    try flushPendingRepeat(alphabet_size, max_alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
                    pending_repeat_count = repeat;
                    pending_repeat_length = last_nonzero_length;
                }
                previous_repeat_symbol = 16;
                try validatePendingRepeat(alphabet_size, index, pending_repeat_length, pending_repeat_count, space);
                if (pendingRepeatCompletesSpace(pending_repeat_length, pending_repeat_count, space)) {
                    try flushPendingRepeat(alphabet_size, max_alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
                }
            },
            17 => {
                const repeat = @as(usize, try reader.readBits(u3, 3)) + 3;
                if (previous_repeat_symbol == 17) {
                    pending_repeat_count = 8 * (pending_repeat_count - 2) + repeat;
                } else {
                    try flushPendingRepeat(alphabet_size, max_alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
                    pending_repeat_count = repeat;
                    pending_repeat_length = 0;
                }
                previous_repeat_symbol = 17;
                try validatePendingRepeat(alphabet_size, index, pending_repeat_length, pending_repeat_count, space);
            },
            else => return error.InvalidHuffmanCode,
        }
        last_symbol = symbol;
    }
    try flushPendingRepeat(alphabet_size, max_alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
    if (space != 0) return error.InvalidHuffmanCode;
    if (last_symbol == null or last_symbol.? == 0 or last_symbol.? == 17) return error.InvalidHuffmanCode;

    var active: usize = 0;
    for (lengths[0..alphabet_size]) |length| {
        if (length != 0) active += 1;
    }
    if (active < 2) return error.InvalidHuffmanCode;
    return .{ .table = try huffman.HuffmanTable(max_alphabet_size).init(&lengths) };
}

fn readCodeLengthCodeLength(reader: *bitstream.BitReader) Error!u4 {
    const first = try reader.readBits(u1, 1);
    const second = try reader.readBits(u1, 1);
    if (first == 0) return if (second == 0) 0 else 3;
    if (second == 0) return 4;
    const third = try reader.readBits(u1, 1);
    if (third == 0) return 2;
    const fourth = try reader.readBits(u1, 1);
    return if (fourth == 0) 1 else 5;
}

fn singleSymbolPrefixCode(comptime alphabet_size: usize, lengths: *const [alphabet_size]u4) PrefixCode(alphabet_size) {
    for (lengths, 0..) |length, symbol| {
        if (length != 0) return .{ .single_symbol = @intCast(symbol) };
    }
    unreachable;
}

fn repeatCodeLength(
    alphabet_size: usize,
    comptime max_alphabet_size: usize,
    lengths: *[max_alphabet_size]u4,
    index: *usize,
    length: u4,
    repeat: usize,
    space: *i32,
) Error!void {
    if (index.* > alphabet_size or alphabet_size - index.* < repeat) return error.InvalidHuffmanCode;
    var i: usize = 0;
    while (i < repeat) : (i += 1) {
        lengths[index.*] = length;
        index.* += 1;
        if (length != 0) {
            space.* -= @intCast(@as(u32, 32768) >> length);
            if (space.* < 0) return error.InvalidHuffmanCode;
        }
    }
}

fn flushPendingRepeat(
    alphabet_size: usize,
    comptime max_alphabet_size: usize,
    lengths: *[max_alphabet_size]u4,
    index: *usize,
    previous_repeat_symbol: *?u16,
    pending_repeat_count: *usize,
    pending_repeat_length: *u4,
    space: *i32,
) Error!void {
    if (previous_repeat_symbol.* == null) return;
    try repeatCodeLength(alphabet_size, max_alphabet_size, lengths, index, pending_repeat_length.*, pending_repeat_count.*, space);
    previous_repeat_symbol.* = null;
    pending_repeat_count.* = 0;
    pending_repeat_length.* = 0;
}

fn validatePendingRepeat(alphabet_size: usize, index: usize, length: u4, count: usize, space: i32) Error!void {
    if (index > alphabet_size or alphabet_size - index < count) return error.InvalidHuffmanCode;
    if (length != 0) {
        const contribution: i32 = @intCast(count * (@as(usize, 32768) >> length));
        if (contribution > space) return error.InvalidHuffmanCode;
    }
}

fn pendingRepeatCompletesSpace(length: u4, count: usize, space: i32) bool {
    if (length == 0) return false;
    const contribution: i32 = @intCast(count * (@as(usize, 32768) >> length));
    return contribution == space;
}

fn alphabetBits(comptime alphabet_size: usize) u6 {
    return alphabetBitsRuntime(alphabet_size);
}

fn alphabetBitsRuntime(alphabet_size: usize) u6 {
    if (alphabet_size <= 1) return 0;
    var bits: u6 = 0;
    var value: usize = alphabet_size - 1;
    while (value != 0) : (value >>= 1) bits += 1;
    return bits;
}

fn readWindowBitsValue(reader: *bitstream.BitReader) Error!u5 {
    const first = try reader.readBits(u1, 1);
    if (first == 0) return 16;
    const low3 = try reader.readBits(u3, 3);
    if (low3 != 0) return @as(u5, low3) + 17;

    const tail = try reader.readBits(u3, 3);
    return switch (tail) {
        0 => 17,
        1 => error.CorruptFrame,
        else => @as(u5, tail) + 8,
    };
}

fn writeWindowBits(allocator: std.mem.Allocator, writer: *BitWriter, window_bits: u5) Error!void {
    switch (window_bits) {
        16 => try writer.writeBits(allocator, 0, 1),
        18...24 => {
            try writer.writeBits(allocator, 1, 1);
            try writer.writeBits(allocator, @as(u64, window_bits - 17), 3);
        },
        17 => {
            try writer.writeBits(allocator, 1, 1);
            try writer.writeBits(allocator, 0, 3);
            try writer.writeBits(allocator, 0, 3);
        },
        10...15 => {
            try writer.writeBits(allocator, 1, 1);
            try writer.writeBits(allocator, 0, 3);
            try writer.writeBits(allocator, @as(u64, window_bits - 8), 3);
        },
        else => return error.InvalidBlockPlan,
    }
}

fn consumeZeroPaddingToByte(reader: *bitstream.BitReader) Error!void {
    if (reader.bit_index == 0) return;
    const pad_bits: u6 = 8 - @as(u6, reader.bit_index);
    const padding = try reader.readBits(u8, pad_bits);
    if (padding != 0) return error.CorruptFrame;
}

fn skipMetadataMetaBlock(reader: *bitstream.BitReader) Error!void {
    const reserved = try reader.readBits(u1, 1);
    if (reserved != 0) return error.CorruptFrame;
    const mskipbytes = try reader.readBits(u2, 2);
    var metadata_len: usize = 0;
    if (mskipbytes != 0) {
        const len_minus_one = try reader.readBits(u32, @intCast(@as(usize, mskipbytes) * 8));
        if (mskipbytes > 1 and ((len_minus_one >> @intCast((@as(usize, mskipbytes) - 1) * 8)) & 0xff) == 0) return error.CorruptFrame;
        metadata_len = std.math.add(usize, len_minus_one, 1) catch return error.IntegerOverflow;
    }
    try consumeZeroPaddingToByte(reader);
    if (reader.byte_index > reader.input.len or reader.input.len - reader.byte_index < metadata_len) return error.TruncatedFrame;
    reader.byte_index += metadata_len;
}

fn ensureZeroPaddingAndEnd(reader: bitstream.BitReader) Error!void {
    var copy = reader;
    try consumeZeroPaddingToByte(&copy);
    if (copy.byte_index != copy.input.len) return error.TrailingData;
}

test "br stored stream encodes RFC-valid empty stream" {
    const encoded = try encodeStoredStreamAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x06}, encoded);
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "", decoded);
}

test "br stored stream round trips hello with known bytes" {
    const encoded = try encodeStoredStreamAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x40, 0x00, 0x10, 'h', 'e', 'l', 'l', 'o', 0x03 }, encoded);
    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, encoded, 5);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello", decoded);
    try std.testing.expectError(error.OutputLimitExceeded, decodedStreamSizeLimited(encoded, 4));
    var out: [5]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 5), try decodeStreamInto(encoded, &out));
    try std.testing.expectEqualSlices(u8, "hello", &out);
}

test "br stored stream supports all RFC window bits" {
    inline for (.{ 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24 }) |bits| {
        const encoded = try encodeStoredStreamWithOptionsAlloc(std.testing.allocator, "window", .{ .window_bits = bits });
        defer std.testing.allocator.free(encoded);
        try std.testing.expectEqual(@as(usize, 6), try decodedStreamSize(encoded));
        const decoded = try decodeStreamAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, "window", decoded);
    }
}

test "br stored stream skips metadata meta-blocks" {
    const encoded = try encodeStoredStreamWithOptionsAlloc(std.testing.allocator, "payload", .{ .metadata = "vort-metadata" });
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqual(@as(usize, 7), try decodedStreamSize(encoded));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "payload", decoded);
}

test "br stored stream decodes multiple uncompressed meta-blocks" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writeUncompressedMetaBlock(std.testing.allocator, &writer, "first ");
    try writeUncompressedMetaBlock(std.testing.allocator, &writer, "second");
    try writer.writeBits(std.testing.allocator, 1, 1);
    try writer.writeBits(std.testing.allocator, 1, 1);

    const payload = "first second";
    try std.testing.expectEqual(payload.len, try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "br minimal compressed stream decodes literal-only final metablock" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForHello(std.testing.allocator, &writer);
    // Insert-copy prefix is a single symbol (40), so no command bits are
    // emitted. The literal tree is canonical by sorted symbol order:
    // e=00, h=01, l=10, o=11, stored LSB-first.
    try writer.writeBits(std.testing.allocator, 2, 2); // h
    try writer.writeBits(std.testing.allocator, 0, 2); // e
    try writer.writeBits(std.testing.allocator, 1, 2); // l
    try writer.writeBits(std.testing.allocator, 1, 2); // l
    try writer.writeBits(std.testing.allocator, 3, 2); // o

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello", decoded);
}

test "br minimal compressed stream can precede stored metablocks" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLAST = false.
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writer.writeBits(std.testing.allocator, 0, 1); // ISUNCOMPRESSED = false
    try writeMinimalCompressedHeaderForHello(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 2, 2); // h
    try writer.writeBits(std.testing.allocator, 0, 2); // e
    try writer.writeBits(std.testing.allocator, 1, 2); // l
    try writer.writeBits(std.testing.allocator, 1, 2); // l
    try writer.writeBits(std.testing.allocator, 3, 2); // o

    try writeUncompressedMetaBlock(std.testing.allocator, &writer, "!");
    try writer.writeBits(std.testing.allocator, 1, 1);
    try writer.writeBits(std.testing.allocator, 1, 1);

    try std.testing.expectEqual(@as(usize, 6), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello!", decoded);
}

test "br minimal compressed stream decodes direct-distance copy" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForCopy(std.testing.allocator, &writer);
    // Insert-copy and literal prefixes are single-symbol. Command 138 inserts
    // one literal and copies four bytes; distance symbol 16 is direct distance 1.

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aaaaa", decoded);
}

test "br minimal compressed stream reuses last distance" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLastDistance(std.testing.allocator, &writer);
    // First command inserts 'a' and copies two bytes from direct distance 1.
    // Second command has symbol 0: insert 0, copy 2, implicit distance zero,
    // which reuses the last pushed distance 1.
    try writer.writeBits(std.testing.allocator, 1, 1); // command 136
    try writer.writeBits(std.testing.allocator, 0, 1); // command 0

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aaaaa", decoded);
}

test "br minimal compressed stream decodes short-distance copy" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForShortDistance(std.testing.allocator, &writer);
    // Command 136 pushes direct distance 1 after producing "aaa". Command 128
    // then copies two bytes from short code 5: last distance + 1 => distance 2.
    try writer.writeBits(std.testing.allocator, 1, 1); // command 136
    try writer.writeBits(std.testing.allocator, 1, 1); // distance 16
    try writer.writeBits(std.testing.allocator, 0, 1); // command 128
    try writer.writeBits(std.testing.allocator, 0, 1); // distance 5

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aaaaa", decoded);
}

test "br minimal compressed stream keeps short distances across metablocks" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);

    try writer.writeBits(std.testing.allocator, 0, 1); // ISLAST = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 2, 16); // MLEN - 1
    try writer.writeBits(std.testing.allocator, 0, 1); // ISUNCOMPRESSED = false
    try writeMinimalCompressedHeaderForShortDistance(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 1, 1); // command 136
    try writer.writeBits(std.testing.allocator, 1, 1); // distance 16

    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 1, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForShortDistance(std.testing.allocator, &writer);
    // The final block uses short code 5: last distance + 1 => distance 2. If
    // the recent-distance ring were reset at the meta-block boundary, this would
    // resolve to the initial last distance + 1 and fail the history check.
    try writer.writeBits(std.testing.allocator, 0, 1); // command 128
    try writer.writeBits(std.testing.allocator, 0, 1); // distance 5

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aaaaa", decoded);
}

test "br minimal compressed stream decodes regular-distance copy" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForRegularDistance(std.testing.allocator, &writer);
    // The single command inserts "ab" and copies three bytes. Distance symbol
    // 17 with NPOSTFIX=1, NDIRECT=0, and dextra=0 resolves to distance 2.
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 1); // b
    try writer.writeBits(std.testing.allocator, 0, 1); // dextra

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "ababa", decoded);
}

test "br stored stream rejects unsupported compressed blocks and trailing data" {
    try std.testing.expectError(error.TruncatedFrame, decodeStreamAlloc(std.testing.allocator, &[_]u8{ 0x00, 0x00 }));
    try std.testing.expectError(error.TrailingData, decodedStreamSize(&[_]u8{ 0x06, 0x00 }));
    try std.testing.expectError(error.TruncatedFrame, decodedStreamSize(&[_]u8{ 0x40, 0x00, 0x10, 'h' }));
}

test "br stored stream rejects malformed metadata meta-blocks" {
    var reserved_bad: std.ArrayList(u8) = .empty;
    defer reserved_bad.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &reserved_bad };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLAST = false.
    try writer.writeBits(std.testing.allocator, 0b11, 2); // MNIBBLES = 0.
    try writer.writeBits(std.testing.allocator, 1, 1); // reserved, invalid.
    try writer.writeBits(std.testing.allocator, 0, 2);
    try std.testing.expectError(error.CorruptFrame, decodedStreamSize(reserved_bad.items));

    var truncated = try encodeStoredStreamWithOptionsAlloc(std.testing.allocator, "", .{ .metadata = "metadata" });
    defer std.testing.allocator.free(truncated);
    try std.testing.expectError(error.TruncatedFrame, decodedStreamSize(truncated[0 .. truncated.len - 1]));
}

test "br simple prefix code decodes single symbol without consuming data bits" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 1, 2); // simple prefix code.
    try writer.writeBits(std.testing.allocator, 0, 2); // NSYM = 1.
    try writer.writeBits(std.testing.allocator, 5, alphabetBits(8));

    var reader = bitstream.BitReader.init(encoded.items);
    const prefix = try readPrefixCode(8, &reader);
    const before = reader.bitPosition();
    try std.testing.expectEqual(@as(u16, 5), try prefix.decode(&reader));
    try std.testing.expectEqual(before, reader.bitPosition());
}

test "br block type count reader covers RFC boundaries" {
    const cases = [_]u16{ 1, 2, 3, 4, 5, 8, 9, 16, 17, 32, 33, 64, 65, 128, 129, 256 };
    inline for (cases) |value| {
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(std.testing.allocator);
        var writer = BitWriter{ .out = &encoded };
        try writeBlockTypeCount(std.testing.allocator, &writer, value);

        var reader = bitstream.BitReader.init(encoded.items);
        try std.testing.expectEqual(@as(u16, value), try readBlockTypeCount(&reader));
    }

    var truncated = bitstream.BitReader.init(&.{});
    try std.testing.expectError(error.TruncatedFrame, readBlockTypeCount(&truncated));
}

test "br minimal compressed header parser reads single-tree shape" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeBlockTypeCount(std.testing.allocator, &writer, 1); // NBLTYPESL
    try writeBlockTypeCount(std.testing.allocator, &writer, 1); // NBLTYPESI
    try writeBlockTypeCount(std.testing.allocator, &writer, 1); // NBLTYPESD
    try writer.writeBits(std.testing.allocator, 1, 2); // NPOSTFIX
    try writer.writeBits(std.testing.allocator, 3, 4); // NDIRECT high bits -> 6
    try writer.writeBits(std.testing.allocator, 2, 2); // literal context mode
    try writeBlockTypeCount(std.testing.allocator, &writer, 1); // NTREESL
    try writeBlockTypeCount(std.testing.allocator, &writer, 1); // NTREESD
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &writer, 256, 'A');
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &writer, 704, 0);
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &writer, 118, 0);

    var reader = bitstream.BitReader.init(encoded.items);
    const header = try readMinimalCompressedHeader(&reader);
    try std.testing.expectEqual(@as(u2, 1), header.npostfix);
    try std.testing.expectEqual(@as(u16, 6), header.ndirect);
    try std.testing.expectEqual(@as(u2, 2), header.literal_context_mode);
    try std.testing.expectEqual(@as(u16, 'A'), try header.literal.decode(&reader));
    try std.testing.expectEqual(@as(u16, 0), try header.insert_copy.decode(&reader));
    try std.testing.expectEqual(@as(u16, 0), try header.distance.decode(&reader));
}

test "br minimal compressed header parser rejects unsupported maps and accepts ndirect boundary" {
    var multi_literal_tree: std.ArrayList(u8) = .empty;
    defer multi_literal_tree.deinit(std.testing.allocator);
    var multi_writer = BitWriter{ .out = &multi_literal_tree };
    try writeBlockTypeCount(std.testing.allocator, &multi_writer, 1);
    try writeBlockTypeCount(std.testing.allocator, &multi_writer, 1);
    try writeBlockTypeCount(std.testing.allocator, &multi_writer, 1);
    try multi_writer.writeBits(std.testing.allocator, 0, 2);
    try multi_writer.writeBits(std.testing.allocator, 0, 4);
    try multi_writer.writeBits(std.testing.allocator, 0, 2);
    try writeBlockTypeCount(std.testing.allocator, &multi_writer, 2); // NTREESL requires context map.
    var multi_reader = bitstream.BitReader.init(multi_literal_tree.items);
    try std.testing.expectError(error.UnsupportedBrotliFeature, readMinimalCompressedHeader(&multi_reader));

    var bad_ndirect: std.ArrayList(u8) = .empty;
    defer bad_ndirect.deinit(std.testing.allocator);
    var bad_writer = BitWriter{ .out = &bad_ndirect };
    try writeBlockTypeCount(std.testing.allocator, &bad_writer, 1);
    try writeBlockTypeCount(std.testing.allocator, &bad_writer, 1);
    try writeBlockTypeCount(std.testing.allocator, &bad_writer, 1);
    try bad_writer.writeBits(std.testing.allocator, 3, 2); // NPOSTFIX
    try bad_writer.writeBits(std.testing.allocator, 15, 4); // NDIRECT = 120 is valid.
    try bad_writer.writeBits(std.testing.allocator, 0, 2);
    try writeBlockTypeCount(std.testing.allocator, &bad_writer, 1);
    try writeBlockTypeCount(std.testing.allocator, &bad_writer, 1);
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &bad_writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &bad_writer, 704, 0);
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &bad_writer, 520, 0);
    var valid_reader = bitstream.BitReader.init(bad_ndirect.items);
    try std.testing.expectEqual(@as(u16, 120), (try readMinimalCompressedHeader(&valid_reader)).ndirect);
}

test "br insert-copy length decoder covers basic and extra-bit ranges" {
    var empty_reader = bitstream.BitReader.init(&.{});
    const zero = try readInsertCopyLengths(0, &empty_reader);
    try std.testing.expectEqual(@as(usize, 0), zero.insert_len);
    try std.testing.expectEqual(@as(usize, 2), zero.copy_len);
    try std.testing.expect(zero.distance_symbol_zero);

    var insert_extra_reader = bitstream.BitReader.init(&.{0b0000_0001});
    const insert_extra = try readInsertCopyLengths(6 << 3, &insert_extra_reader);
    try std.testing.expectEqual(@as(usize, 7), insert_extra.insert_len);
    try std.testing.expectEqual(@as(usize, 2), insert_extra.copy_len);
    try std.testing.expect(insert_extra.distance_symbol_zero);

    var copy_extra_reader = bitstream.BitReader.init(&.{0b0000_0001});
    const copy_extra = try readInsertCopyLengths(64 + 0, &copy_extra_reader);
    try std.testing.expectEqual(@as(usize, 0), copy_extra.insert_len);
    try std.testing.expectEqual(@as(usize, 11), copy_extra.copy_len);
    try std.testing.expect(copy_extra.distance_symbol_zero);

    var explicit_distance_reader = bitstream.BitReader.init(&.{0});
    const explicit_distance = try readInsertCopyLengths(128, &explicit_distance_reader);
    try std.testing.expectEqual(@as(usize, 0), explicit_distance.insert_len);
    try std.testing.expectEqual(@as(usize, 2), explicit_distance.copy_len);
    try std.testing.expect(!explicit_distance.distance_symbol_zero);
}

test "br insert-copy length decoder handles high range extra bits" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 3, 10); // insert code 20 extra => 1093.
    try writer.writeBits(std.testing.allocator, 17, 10); // copy code 22 extra => 1111.

    var reader = bitstream.BitReader.init(encoded.items);
    const lengths = try readInsertCopyLengths(640 + (4 << 3) + 6, &reader);
    try std.testing.expectEqual(@as(usize, 1093), lengths.insert_len);
    try std.testing.expectEqual(@as(usize, 1111), lengths.copy_len);
    try std.testing.expect(!lengths.distance_symbol_zero);

    var invalid_reader = bitstream.BitReader.init(&.{});
    try std.testing.expectError(error.InvalidHuffmanCode, readInsertCopyLengths(704, &invalid_reader));
}

test "br short distance resolver covers RFC table" {
    const last_distances = [_]usize{ 16, 15, 11, 4 };
    const expected = [_]usize{ 4, 11, 15, 16, 3, 5, 2, 6, 1, 7, 10, 12, 9, 13, 8, 14 };
    for (expected, 0..) |distance, symbol| {
        try std.testing.expectEqual(distance, try resolveShortDistance(@intCast(symbol), &last_distances));
    }

    const small_last = [_]usize{ 16, 15, 2, 1 };
    try std.testing.expectError(error.InvalidMatch, resolveShortDistance(4, &small_last));
    try std.testing.expectError(error.InvalidMatch, resolveShortDistance(12, &small_last));
}

test "br regular distance resolver covers postfix and extra bits" {
    try std.testing.expectEqual(@as(usize, 2), try resolveRegularDistance(1, 0, 17, 0));
    try std.testing.expectEqual(@as(usize, 3), try resolveRegularDistance(0, 1, 17, 1));
    try std.testing.expectEqual(@as(usize, 18), try resolveRegularDistance(2, 4, 25, 1));
    try std.testing.expectError(error.InvalidHuffmanCode, resolveRegularDistance(0, 4, 19, 0));
}

test "br simple prefix code decodes three-symbol canonical tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 1, 2); // simple prefix code.
    try writer.writeBits(std.testing.allocator, 2, 2); // NSYM = 3.
    try writer.writeBits(std.testing.allocator, 5, alphabetBits(8));
    try writer.writeBits(std.testing.allocator, 2, alphabetBits(8));
    try writer.writeBits(std.testing.allocator, 7, alphabetBits(8));
    try writer.writeBits(std.testing.allocator, 0, 1); // symbol 5, length 1, canonical code 0.
    try writer.writeBits(std.testing.allocator, 1, 2); // symbol 2, length 2, canonical code 10 -> stored 01.
    try writer.writeBits(std.testing.allocator, 3, 2); // symbol 7, length 2, canonical code 11.

    var reader = bitstream.BitReader.init(encoded.items);
    const prefix = try readPrefixCode(8, &reader);
    try std.testing.expectEqual(@as(u16, 5), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 2), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 7), try prefix.decode(&reader));
}

test "br simple prefix code decodes four-symbol tree variants" {
    inline for (.{ 0, 1 }) |tree_select| {
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(std.testing.allocator);
        var writer = BitWriter{ .out = &encoded };
        try writer.writeBits(std.testing.allocator, 1, 2); // simple prefix code.
        try writer.writeBits(std.testing.allocator, 3, 2); // NSYM = 4.
        try writer.writeBits(std.testing.allocator, 1, alphabetBits(8));
        try writer.writeBits(std.testing.allocator, 2, alphabetBits(8));
        try writer.writeBits(std.testing.allocator, 3, alphabetBits(8));
        try writer.writeBits(std.testing.allocator, 4, alphabetBits(8));
        try writer.writeBits(std.testing.allocator, tree_select, 1);

        if (tree_select == 0) {
            // Four 2-bit codes assigned by sorted symbol order: 00, 01, 10, 11.
            try writer.writeBits(std.testing.allocator, 0, 2);
            try writer.writeBits(std.testing.allocator, 2, 2);
            try writer.writeBits(std.testing.allocator, 1, 2);
            try writer.writeBits(std.testing.allocator, 3, 2);
        } else {
            // Lengths in representation order are 1,2,3,3.
            try writer.writeBits(std.testing.allocator, 0, 1);
            try writer.writeBits(std.testing.allocator, 1, 2);
            try writer.writeBits(std.testing.allocator, 3, 3);
            try writer.writeBits(std.testing.allocator, 7, 3);
        }

        var reader = bitstream.BitReader.init(encoded.items);
        const prefix = try readPrefixCode(8, &reader);
        try std.testing.expectEqual(@as(u16, 1), try prefix.decode(&reader));
        try std.testing.expectEqual(@as(u16, 2), try prefix.decode(&reader));
        try std.testing.expectEqual(@as(u16, 3), try prefix.decode(&reader));
        try std.testing.expectEqual(@as(u16, 4), try prefix.decode(&reader));
    }
}

test "br simple prefix code rejects invalid symbol lists" {
    var duplicate: std.ArrayList(u8) = .empty;
    defer duplicate.deinit(std.testing.allocator);
    var duplicate_writer = BitWriter{ .out = &duplicate };
    try duplicate_writer.writeBits(std.testing.allocator, 1, 2);
    try duplicate_writer.writeBits(std.testing.allocator, 1, 2); // NSYM = 2.
    try duplicate_writer.writeBits(std.testing.allocator, 3, alphabetBits(8));
    try duplicate_writer.writeBits(std.testing.allocator, 3, alphabetBits(8));
    var duplicate_reader = bitstream.BitReader.init(duplicate.items);
    try std.testing.expectError(error.InvalidHuffmanCode, readPrefixCode(8, &duplicate_reader));

    var out_of_range: std.ArrayList(u8) = .empty;
    defer out_of_range.deinit(std.testing.allocator);
    var out_of_range_writer = BitWriter{ .out = &out_of_range };
    try out_of_range_writer.writeBits(std.testing.allocator, 1, 2);
    try out_of_range_writer.writeBits(std.testing.allocator, 0, 2); // NSYM = 1.
    try out_of_range_writer.writeBits(std.testing.allocator, 7, alphabetBits(7));
    var out_of_range_reader = bitstream.BitReader.init(out_of_range.items);
    try std.testing.expectError(error.InvalidHuffmanCode, readPrefixCode(7, &out_of_range_reader));

    var truncated_complex = bitstream.BitReader.init(&[_]u8{0});
    try std.testing.expectError(error.TruncatedFrame, readPrefixCode(8, &truncated_complex));
}

test "br complex prefix code decodes direct length sequence" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 0, 2); // HSKIP = 0, complex code.

    var cl_lengths: [code_length_alphabet_size]u4 = @splat(0);
    cl_lengths[0] = 2;
    cl_lengths[1] = 2;
    cl_lengths[2] = 2;
    cl_lengths[3] = 2;
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 2); // symbol 1
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 2); // symbol 2
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 2); // symbol 3
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 4
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 2); // symbol 0

    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 1);
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 2);
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 3);
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 3);
    try writer.writeBits(std.testing.allocator, 0, 1); // symbol 0, code 0
    try writer.writeBits(std.testing.allocator, 1, 2); // symbol 1, code 10 -> stored 01
    try writer.writeBits(std.testing.allocator, 3, 3); // symbol 2, code 110 -> stored 011
    try writer.writeBits(std.testing.allocator, 7, 3); // symbol 3, code 111

    var reader = bitstream.BitReader.init(encoded.items);
    const prefix = try readPrefixCode(4, &reader);
    try std.testing.expectEqual(@as(u16, 0), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 1), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 2), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 3), try prefix.decode(&reader));
}

test "br complex prefix code supports zero repeats" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 0, 2); // HSKIP = 0, complex code.

    var cl_lengths: [code_length_alphabet_size]u4 = @splat(0);
    cl_lengths[1] = 1;
    cl_lengths[17] = 1;
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 1
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 2
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 3
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 4
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 0
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 5
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 17

    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 17);
    try writer.writeBits(std.testing.allocator, 1, 3); // repeat 4 zeros.
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 1);
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 1);
    try writer.writeBits(std.testing.allocator, 0, 1);
    try writer.writeBits(std.testing.allocator, 1, 1);

    var reader = bitstream.BitReader.init(encoded.items);
    const prefix = try readPrefixCode(6, &reader);
    try std.testing.expectEqual(@as(u16, 4), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 5), try prefix.decode(&reader));
}

test "br complex prefix code supports repeat previous length" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 0, 2); // HSKIP = 0, complex code.

    var cl_lengths: [code_length_alphabet_size]u4 = @splat(0);
    cl_lengths[2] = 1;
    cl_lengths[16] = 1;
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 1
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 2
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 3
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 4
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 0
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 5
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 17
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 6
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 16

    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 2);
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 16);
    try writer.writeBits(std.testing.allocator, 0, 2); // repeat previous length 3 times.
    try writer.writeBits(std.testing.allocator, 0, 2);
    try writer.writeBits(std.testing.allocator, 2, 2);
    try writer.writeBits(std.testing.allocator, 1, 2);
    try writer.writeBits(std.testing.allocator, 3, 2);

    var reader = bitstream.BitReader.init(encoded.items);
    const prefix = try readPrefixCode(4, &reader);
    try std.testing.expectEqual(@as(u16, 0), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 1), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 2), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 3), try prefix.decode(&reader));
}

test "br complex prefix code supports chained zero repeats" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 0, 2); // HSKIP = 0, complex code.

    var cl_lengths: [code_length_alphabet_size]u4 = @splat(0);
    cl_lengths[1] = 1;
    cl_lengths[17] = 1;
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 1
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 2
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 3
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 4
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 0
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 5
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 17

    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 17);
    try writer.writeBits(std.testing.allocator, 0, 3); // repeat 3 zeros.
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 17);
    try writer.writeBits(std.testing.allocator, 1, 3); // chained repeat: 8*(3-2)+4 = 12 zeros.
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 1);
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 1);
    try writer.writeBits(std.testing.allocator, 0, 1);
    try writer.writeBits(std.testing.allocator, 1, 1);

    var reader = bitstream.BitReader.init(encoded.items);
    const prefix = try readPrefixCode(17, &reader);
    try std.testing.expectEqual(@as(u16, 12), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 13), try prefix.decode(&reader));
}

test "br complex prefix code supports chained previous-length repeats" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 0, 2); // HSKIP = 0, complex code.

    var cl_lengths: [code_length_alphabet_size]u4 = @splat(0);
    cl_lengths[4] = 1;
    cl_lengths[16] = 1;
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 1
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 2
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 3
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 4
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 0
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 5
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 17
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 6
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 16

    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 4);
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 16);
    try writer.writeBits(std.testing.allocator, 2, 2); // repeat previous length 5 times.
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 16);
    try writer.writeBits(std.testing.allocator, 0, 2); // chained repeat: 4*(5-2)+3 = 15 repeats.
    try writer.writeBits(std.testing.allocator, 0, 4);
    try writer.writeBits(std.testing.allocator, 8, 4);
    try writer.writeBits(std.testing.allocator, 4, 4);
    try writer.writeBits(std.testing.allocator, 12, 4);

    var reader = bitstream.BitReader.init(encoded.items);
    const prefix = try readPrefixCode(16, &reader);
    try std.testing.expectEqual(@as(u16, 0), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 1), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 2), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 3), try prefix.decode(&reader));
}

fn writeCodeLengthCodeLength(allocator: std.mem.Allocator, writer: *BitWriter, length: u4) Error!void {
    switch (length) {
        0 => try writer.writeBits(allocator, 0b00, 2),
        1 => try writer.writeBits(allocator, 0b0111, 4),
        2 => try writer.writeBits(allocator, 0b011, 3),
        3 => try writer.writeBits(allocator, 0b10, 2),
        4 => try writer.writeBits(allocator, 0b01, 2),
        5 => try writer.writeBits(allocator, 0b1111, 4),
        else => return error.InvalidHuffmanCode,
    }
}

fn writeMinimalCompressedHeaderForHello(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 3, 2); // NSYM = 4
    try writer.writeBits(allocator, 'h', alphabetBits(256));
    try writer.writeBits(allocator, 'e', alphabetBits(256));
    try writer.writeBits(allocator, 'l', alphabetBits(256));
    try writer.writeBits(allocator, 'o', alphabetBits(256));
    try writer.writeBits(allocator, 0, 1); // tree-select

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 40);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForCopy(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 1, 4); // NDIRECT = 1
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 138);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 65, 16);
}

fn writeMinimalCompressedHeaderForLastDistance(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 1, 4); // NDIRECT = 1
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');

    try writer.writeBits(allocator, 1, 2); // simple insert-copy prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 136, alphabetBits(704));
    try writer.writeBits(allocator, 0, alphabetBits(704));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 65, 16);
}

fn writeMinimalCompressedHeaderForShortDistance(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 1, 4); // NDIRECT = 1
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');

    try writer.writeBits(allocator, 1, 2); // simple insert-copy prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 136, alphabetBits(704));
    try writer.writeBits(allocator, 128, alphabetBits(704));

    try writer.writeBits(allocator, 1, 2); // simple distance prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 16, alphabetBits(65));
    try writer.writeBits(allocator, 5, alphabetBits(65));
}

fn writeMinimalCompressedHeaderForRegularDistance(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 1, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));

    try writer.writeBits(allocator, 1, 2); // simple insert-copy prefix
    try writer.writeBits(allocator, 0, 2); // NSYM = 1
    try writer.writeBits(allocator, 145, alphabetBits(704));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 112, 17);
}

fn writeBlockTypeCount(allocator: std.mem.Allocator, writer: *BitWriter, value: u16) Error!void {
    if (value == 0 or value > 256) return error.InvalidBlockPlan;
    if (value == 1) return try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, 1, 1);
    if (value == 2) return try writer.writeBits(allocator, 0, 3);
    var selector: u4 = 1;
    while (selector < 8) : (selector += 1) {
        const min = (@as(u16, 1) << selector) + 1;
        const max = min + ((@as(u16, 1) << selector) - 1);
        if (value >= min and value <= max) {
            try writer.writeBits(allocator, selector, 3);
            try writer.writeBits(allocator, value - min, selector);
            return;
        }
    }
    return error.InvalidBlockPlan;
}

fn writeSimpleSingleSymbolPrefix(
    allocator: std.mem.Allocator,
    writer: *BitWriter,
    comptime alphabet_size: usize,
    symbol: usize,
) Error!void {
    if (symbol >= alphabet_size) return error.InvalidHuffmanCode;
    try writer.writeBits(allocator, 1, 2); // simple prefix code
    try writer.writeBits(allocator, 0, 2); // NSYM = 1
    try writer.writeBits(allocator, symbol, alphabetBits(alphabet_size));
}

fn writeCodeLengthSymbol(
    allocator: std.mem.Allocator,
    writer: *BitWriter,
    lengths: *const [code_length_alphabet_size]u4,
    symbol: usize,
) Error!void {
    const encoder = try huffman.HuffmanTable(code_length_alphabet_size).Encoder.init(lengths);
    try writer.writeBits(allocator, encoder.codes[symbol], encoder.bits[symbol]);
}
