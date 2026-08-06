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
    distance: PrefixCode(16),
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
        if (is_last) return error.UnsupportedBrotliFeature;
        const is_uncompressed = try reader.readBits(u1, 1) == 1;
        if (!is_uncompressed) return error.UnsupportedBrotliFeature;
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
        if (is_last) return error.UnsupportedBrotliFeature;
        const is_uncompressed = try reader.readBits(u1, 1) == 1;
        if (!is_uncompressed) return error.UnsupportedBrotliFeature;
        try consumeZeroPaddingToByte(&reader);
        total = std.math.add(usize, total, meta_block_len) catch return error.IntegerOverflow;
        if (total > max_output_len) return error.OutputLimitExceeded;
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
        .distance = try readPrefixCode(16, reader),
    };
}

fn readPrefixCode(comptime alphabet_size: usize, reader: *bitstream.BitReader) Error!PrefixCode(alphabet_size) {
    const kind = try reader.readBits(u2, 2);
    if (kind != 1) return try readComplexPrefixCode(alphabet_size, reader, kind);

    const nsym = @as(usize, try reader.readBits(u2, 2)) + 1;
    const alphabet_bits = alphabetBits(alphabet_size);
    var symbols: [4]u16 = undefined;
    for (0..nsym) |i| {
        const symbol = try reader.readBits(u16, alphabet_bits);
        if (symbol >= alphabet_size) return error.InvalidHuffmanCode;
        for (symbols[0..i]) |previous| {
            if (previous == symbol) return error.InvalidHuffmanCode;
        }
        symbols[i] = symbol;
    }

    var lengths: [alphabet_size]u4 = @splat(0);
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

    return .{ .table = try huffman.HuffmanTable(alphabet_size).init(&lengths) };
}

const code_length_alphabet_size = 18;
const code_length_order = [_]u5{ 1, 2, 3, 4, 0, 5, 17, 6, 16, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

fn readComplexPrefixCode(comptime alphabet_size: usize, reader: *bitstream.BitReader, hskip: u2) Error!PrefixCode(alphabet_size) {
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

    var lengths: [alphabet_size]u4 = @splat(0);
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
                try flushPendingRepeat(alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
                lengths[index] = 0;
                index += 1;
            },
            1...15 => {
                try flushPendingRepeat(alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
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
                    try flushPendingRepeat(alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
                    pending_repeat_count = repeat;
                    pending_repeat_length = last_nonzero_length;
                }
                previous_repeat_symbol = 16;
                try validatePendingRepeat(alphabet_size, index, pending_repeat_length, pending_repeat_count, space);
                if (pendingRepeatCompletesSpace(pending_repeat_length, pending_repeat_count, space)) {
                    try flushPendingRepeat(alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
                }
            },
            17 => {
                const repeat = @as(usize, try reader.readBits(u3, 3)) + 3;
                if (previous_repeat_symbol == 17) {
                    pending_repeat_count = 8 * (pending_repeat_count - 2) + repeat;
                } else {
                    try flushPendingRepeat(alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
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
    try flushPendingRepeat(alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
    if (space != 0) return error.InvalidHuffmanCode;
    if (last_symbol == null or last_symbol.? == 0 or last_symbol.? == 17) return error.InvalidHuffmanCode;

    var active: usize = 0;
    for (lengths) |length| {
        if (length != 0) active += 1;
    }
    if (active < 2) return error.InvalidHuffmanCode;
    return .{ .table = try huffman.HuffmanTable(alphabet_size).init(&lengths) };
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
    comptime alphabet_size: usize,
    lengths: *[alphabet_size]u4,
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
    comptime alphabet_size: usize,
    lengths: *[alphabet_size]u4,
    index: *usize,
    previous_repeat_symbol: *?u16,
    pending_repeat_count: *usize,
    pending_repeat_length: *u4,
    space: *i32,
) Error!void {
    if (previous_repeat_symbol.* == null) return;
    try repeatCodeLength(alphabet_size, lengths, index, pending_repeat_length.*, pending_repeat_count.*, space);
    previous_repeat_symbol.* = null;
    pending_repeat_count.* = 0;
    pending_repeat_length.* = 0;
}

fn validatePendingRepeat(comptime alphabet_size: usize, index: usize, length: u4, count: usize, space: i32) Error!void {
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
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &writer, 16, 0);

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
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &bad_writer, 16, 0);
    var valid_reader = bitstream.BitReader.init(bad_ndirect.items);
    try std.testing.expectEqual(@as(u16, 120), (try readMinimalCompressedHeader(&valid_reader)).ndirect);
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
