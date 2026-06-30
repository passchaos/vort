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

pub const OwnedDecodeResult = struct {
    bytes: []u8,
    input_read: usize,

    pub fn deinit(self: OwnedDecodeResult, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

pub fn encodeRawFixedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const plan = try lz77.greedyPlanAlloc(allocator, input, .{});
    defer plan.deinit(allocator);
    return encodeRawFixedTokensAlloc(allocator, plan.tokens);
}

pub fn encodeRawFixedTokensAlloc(allocator: std.mem.Allocator, tokens: []const lz77.Token) ![]u8 {
    const lit_lengths = huffman.fixedLiteralLengths();
    const lit_encoder = try huffman.FixedLiteralTable.Encoder.init(&lit_lengths);
    const dist_lengths = huffman.fixedDistanceLengths();
    const dist_encoder = try huffman.FixedDistanceTable.Encoder.init(&dist_lengths);

    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    try writer.writeBits(allocator, 0b1, 1); // final block
    try writer.writeBits(allocator, 0b01, 2); // fixed Huffman block

    for (tokens) |token| {
        switch (token) {
            .literal => |byte| try lit_encoder.writeSymbol(&writer, allocator, byte),
            .match => |m| {
                const len_code = lengthCode(m.length);
                try lit_encoder.writeSymbol(&writer, allocator, len_code.symbol);
                if (len_code.extra_bits != 0) try writer.writeBits(allocator, len_code.extra_value, len_code.extra_bits);

                const dist_code = distanceCode(m.distance);
                try dist_encoder.writeSymbol(&writer, allocator, dist_code.symbol);
                if (dist_code.extra_bits != 0) try writer.writeBits(allocator, dist_code.extra_value, dist_code.extra_bits);
            },
        }
    }
    try lit_encoder.writeSymbol(&writer, allocator, 256);
    return writer.toOwnedSlice(allocator);
}

const CodeExtra = struct {
    symbol: u16,
    extra_bits: u6,
    extra_value: u16,
};

fn lengthCode(length: u16) CodeExtra {
    for (length_table, 0..) |entry, i| {
        const span: u16 = if (entry.extra_bits == 0) 1 else @as(u16, 1) << @intCast(entry.extra_bits);
        if (length >= entry.base and length < entry.base + span) {
            return .{ .symbol = @intCast(257 + i), .extra_bits = entry.extra_bits, .extra_value = length - entry.base };
        }
    }
    unreachable;
}

fn distanceCode(distance: u16) CodeExtra {
    for (distance_table, 0..) |entry, i| {
        const span: u16 = if (entry.extra_bits == 0) 1 else @as(u16, 1) << @intCast(entry.extra_bits);
        if (distance >= entry.base and distance < entry.base + span) {
            return .{ .symbol = @intCast(i), .extra_bits = entry.extra_bits, .extra_value = distance - entry.base };
        }
    }
    unreachable;
}

pub fn decodeRawFixed(input: []const u8, output: []u8) Error!DecodeResult {
    var reader = bitstream.BitReader.init(input);
    const final = try reader.readBits(u1, 1);
    const block_type = try reader.readBits(u2, 2);
    if (block_type != 0b01) return error.InvalidDeflateBlockType;

    const lit_table = try huffman.fixedLiteralTable();
    const dist_table = try huffman.fixedDistanceTable();
    var out_offset: usize = 0;
    while (true) {
        const symbol = (try lit_table.decode(&reader)).value;
        if (symbol < 256) {
            if (out_offset == output.len) return error.OutputTooSmall;
            output[out_offset] = @intCast(symbol);
            out_offset += 1;
        } else if (symbol == 256) {
            _ = final;
            return .{ .input_read = reader.byteOffset(), .output_written = out_offset };
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, &reader);
            const distance_symbol = (try dist_table.decode(&reader)).value;
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

    var reader = bitstream.BitReader.init(input);
    const final = try reader.readBits(u1, 1);
    const block_type = try reader.readBits(u2, 2);
    if (block_type != 0b01) return error.InvalidDeflateBlockType;

    const lit_table = try huffman.fixedLiteralTable();
    const dist_table = try huffman.fixedDistanceTable();
    while (true) {
        const symbol = (try lit_table.decode(&reader)).value;
        if (symbol < 256) {
            try out.append(allocator, @intCast(symbol));
        } else if (symbol == 256) {
            _ = final;
            return .{ .bytes = try out.toOwnedSlice(allocator), .input_read = reader.byteOffset() };
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, &reader);
            const distance_symbol = (try dist_table.decode(&reader)).value;
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

    var reader = bitstream.BitReader.init(input);
    const parsed = try huffman.parseDynamicLengths(&reader);
    const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
    const dist_table = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);

    while (true) {
        const symbol = (try lit_table.decode(&reader)).value;
        if (symbol < 256) {
            try out.append(allocator, @intCast(symbol));
        } else if (symbol == 256) {
            return .{ .bytes = try out.toOwnedSlice(allocator), .input_read = reader.byteOffset() };
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, &reader);
            const distance_symbol = (try dist_table.decode(&reader)).value;
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

pub fn decodeRawAutoAllocPartial(allocator: std.mem.Allocator, input: []const u8) !OwnedDecodeResult {
    if (input.len == 0) return error.TruncatedFrame;
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var reader = bitstream.BitReader.init(input);
    while (true) {
        const final = (try reader.readBits(u1, 1)) != 0;
        const block_type = try reader.readBits(u2, 2);
        switch (block_type) {
            0 => try decodeStoredBlockFromReader(allocator, &reader, &out),
            1 => try decodeCompressedBlockFromReader(allocator, &reader, &out, try huffman.fixedLiteralTable(), try huffman.fixedDistanceTable()),
            2 => {
                const parsed = try huffman.parseDynamicLengthsAfterHeader(final, &reader);
                const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
                const dist_table = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
                try decodeCompressedBlockFromReader(allocator, &reader, &out, lit_table, dist_table);
            },
            else => return error.InvalidDeflateBlockType,
        }
        if (final) return .{ .bytes = try out.toOwnedSlice(allocator), .input_read = reader.byteOffset() };
    }
}

pub fn decodeRawAutoAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const result = try decodeRawAutoAllocPartial(allocator, input);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
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

pub fn decodeRawStored(input: []const u8, output: []u8) Error!DecodeResult {
    var in_offset: usize = 0;
    var out_offset: usize = 0;

    while (true) {
        if (input.len - in_offset < 5) return error.TruncatedFrame;
        const header = input[in_offset];
        if (((header >> 1) & 0b11) != 0) return error.InvalidDeflateBlockType;
        if ((header & 0b1111_1000) != 0) return error.CorruptFrame;
        const final = (header & 1) != 0;
        in_offset += 1;

        const len = std.mem.readInt(u16, input[in_offset..][0..2], .little);
        const nlen = std.mem.readInt(u16, input[in_offset + 2 ..][0..2], .little);
        in_offset += 4;
        if (nlen != ~len) return error.StoredLengthMismatch;

        const chunk_len: usize = len;
        if (input.len - in_offset < chunk_len) return error.TruncatedFrame;
        if (output.len - out_offset < chunk_len) return error.OutputTooSmall;
        @memcpy(output[out_offset..][0..chunk_len], input[in_offset..][0..chunk_len]);
        in_offset += chunk_len;
        out_offset += chunk_len;

        if (final) return .{ .input_read = in_offset, .output_written = out_offset };
    }
}

pub fn decodeRawStoredAllocPartial(allocator: std.mem.Allocator, input: []const u8) !OwnedDecodeResult {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var in_offset: usize = 0;
    while (true) {
        if (input.len - in_offset < 5) return error.TruncatedFrame;
        const header = input[in_offset];
        if (((header >> 1) & 0b11) != 0) return error.InvalidDeflateBlockType;
        if ((header & 0b1111_1000) != 0) return error.CorruptFrame;
        const final = (header & 1) != 0;
        in_offset += 1;

        const len = std.mem.readInt(u16, input[in_offset..][0..2], .little);
        const nlen = std.mem.readInt(u16, input[in_offset + 2 ..][0..2], .little);
        in_offset += 4;
        if (nlen != ~len) return error.StoredLengthMismatch;

        const chunk_len: usize = len;
        if (input.len - in_offset < chunk_len) return error.TruncatedFrame;
        try out.appendSlice(allocator, input[in_offset..][0..chunk_len]);
        in_offset += chunk_len;

        if (final) {
            return .{ .bytes = try out.toOwnedSlice(allocator), .input_read = in_offset };
        }
    }
}

pub fn decodeRawStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const result = try decodeRawStoredAllocPartial(allocator, input);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

fn decodeStoredBlockFromReader(allocator: std.mem.Allocator, reader: *bitstream.BitReader, out: *std.ArrayList(u8)) !void {
    reader.alignToByte();
    const offset = reader.byte_index;
    if (reader.input.len - offset < 4) return error.TruncatedFrame;
    const len = std.mem.readInt(u16, reader.input[offset..][0..2], .little);
    const nlen = std.mem.readInt(u16, reader.input[offset + 2 ..][0..2], .little);
    if (nlen != ~len) return error.StoredLengthMismatch;
    const chunk_len: usize = len;
    if (reader.input.len - offset - 4 < chunk_len) return error.TruncatedFrame;
    try out.appendSlice(allocator, reader.input[offset + 4 ..][0..chunk_len]);
    reader.byte_index = offset + 4 + chunk_len;
    reader.bit_index = 0;
}

fn decodeCompressedBlockFromReader(
    allocator: std.mem.Allocator,
    reader: *bitstream.BitReader,
    out: *std.ArrayList(u8),
    lit_table: anytype,
    dist_table: anytype,
) !void {
    while (true) {
        const symbol = (try lit_table.decode(reader)).value;
        if (symbol < 256) {
            try out.append(allocator, @intCast(symbol));
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = (try dist_table.decode(reader)).value;
            const distance = try decodeDistance(distance_symbol, reader);
            try appendMatch(allocator, out, length, distance);
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
    var i: usize = 0;
    while (i < length) : (i += 1) {
        const absolute = history.len + i - distance;
        dest[i] = if (absolute < history.len) history[absolute] else dest[absolute - history.len];
    }
}

fn appendMatch(allocator: std.mem.Allocator, out: *std.ArrayList(u8), length: usize, distance: usize) !void {
    if (distance == 0 or distance > out.items.len) return error.InvalidMatch;
    try out.ensureUnusedCapacity(allocator, length);
    var i: usize = 0;
    while (i < length) : (i += 1) {
        const index = out.items.len - distance;
        out.appendAssumeCapacity(out.items[index]);
    }
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

pub fn encodeZlibStored(input: []const u8, output: []u8) Error!usize {
    const required = try zlibStoredEncodedSize(input.len);
    if (output.len < required) return error.OutputTooSmall;

    output[0] = 0x78; // deflate, 32 KiB window
    output[1] = 0x01; // fastest/no compression, valid FCHECK
    const raw_written = try encodeRawStored(input, output[2 .. required - 4]);
    const footer_offset = 2 + raw_written;
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

pub fn encodeZlibFixedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const raw = try encodeRawFixedAlloc(allocator, input);
    defer allocator.free(raw);
    const out = try allocator.alloc(u8, 2 + raw.len + 4);
    errdefer allocator.free(out);
    out[0] = 0x78;
    out[1] = 0x01;
    @memcpy(out[2..][0..raw.len], raw);
    std.mem.writeInt(u32, out[2 + raw.len ..][0..4], checksum.adler32(input), .big);
    return out;
}

pub fn decodeZlibStored(input: []const u8, output: []u8) Error!usize {
    if (input.len < 2) return error.TruncatedFrame;
    try validateZlibHeader(input[0], input[1]);

    const raw = try decodeRawStored(input[2..], output);
    const footer_offset = 2 + raw.input_read;
    if (input.len - footer_offset < 4) return error.TruncatedFrame;
    const expected = std.mem.readInt(u32, input[footer_offset..][0..4], .big);
    if (checksum.adler32(output[0..raw.output_written]) != expected) return error.ChecksumMismatch;
    if (footer_offset + 4 != input.len) return error.TrailingData;
    return raw.output_written;
}

pub fn decodeZlibStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const scratch = try allocator.alloc(u8, input.len);
    defer allocator.free(scratch);
    const written = try decodeZlibStored(input, scratch);
    const out = try allocator.alloc(u8, written);
    errdefer allocator.free(out);
    @memcpy(out, scratch[0..written]);
    return out;
}

pub fn decodeZlibAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len < 2) return error.TruncatedFrame;
    try validateZlibHeader(input[0], input[1]);

    const raw = try decodeRawAutoAllocPartial(allocator, input[2..]);
    errdefer raw.deinit(allocator);
    const footer_offset = 2 + raw.input_read;
    if (input.len - footer_offset < 4) return error.TruncatedFrame;
    const expected = std.mem.readInt(u32, input[footer_offset..][0..4], .big);
    if (checksum.adler32(raw.bytes) != expected) return error.ChecksumMismatch;
    if (footer_offset + 4 != input.len) return error.TrailingData;
    return raw.bytes;
}

pub fn gzipStoredEncodedSize(input_len: usize) Error!usize {
    const raw_len = try rawStoredEncodedSize(input_len);
    const with_header = std.math.add(usize, 10, raw_len) catch return error.IntegerOverflow;
    return std.math.add(usize, with_header, 8) catch error.IntegerOverflow;
}

pub fn encodeGzipStored(input: []const u8, output: []u8) Error!usize {
    const required = try gzipStoredEncodedSize(input.len);
    if (output.len < required) return error.OutputTooSmall;

    @memcpy(output[0..10], &gzip_header);
    const raw_written = try encodeRawStored(input, output[10 .. required - 8]);
    const footer_offset = 10 + raw_written;
    std.mem.writeInt(u32, output[footer_offset..][0..4], checksum.crc32(input), .little);
    std.mem.writeInt(u32, output[footer_offset + 4 ..][0..4], @truncate(input.len), .little);
    return footer_offset + 8;
}

pub fn encodeGzipStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const required = try gzipStoredEncodedSize(input.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    const written = try encodeGzipStored(input, out);
    std.debug.assert(written == out.len);
    return out;
}

pub fn encodeGzipFixedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const raw = try encodeRawFixedAlloc(allocator, input);
    defer allocator.free(raw);
    const out = try allocator.alloc(u8, gzip_header.len + raw.len + 8);
    errdefer allocator.free(out);
    @memcpy(out[0..gzip_header.len], &gzip_header);
    @memcpy(out[gzip_header.len..][0..raw.len], raw);
    const footer = gzip_header.len + raw.len;
    std.mem.writeInt(u32, out[footer..][0..4], checksum.crc32(input), .little);
    std.mem.writeInt(u32, out[footer + 4 ..][0..4], @truncate(input.len), .little);
    return out;
}

pub fn decodeGzipStored(input: []const u8, output: []u8) Error!usize {
    const data_offset = try parseGzipHeader(input);

    const raw = try decodeRawStored(input[data_offset..], output);
    const footer_offset = data_offset + raw.input_read;
    if (input.len - footer_offset < 8) return error.TruncatedFrame;
    const expected_crc = std.mem.readInt(u32, input[footer_offset..][0..4], .little);
    const expected_size = std.mem.readInt(u32, input[footer_offset + 4 ..][0..4], .little);
    const payload = output[0..raw.output_written];
    if (checksum.crc32(payload) != expected_crc) return error.ChecksumMismatch;
    if (@as(u32, @truncate(raw.output_written)) != expected_size) return error.SizeMismatch;
    if (footer_offset + 8 != input.len) return error.TrailingData;
    return raw.output_written;
}

pub fn decodeGzipStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const scratch = try allocator.alloc(u8, input.len);
    defer allocator.free(scratch);
    const written = try decodeGzipStored(input, scratch);
    const out = try allocator.alloc(u8, written);
    errdefer allocator.free(out);
    @memcpy(out, scratch[0..written]);
    return out;
}

pub fn decodeGzipAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const data_offset = try parseGzipHeader(input);

    const raw = try decodeRawAutoAllocPartial(allocator, input[data_offset..]);
    errdefer raw.deinit(allocator);
    const footer_offset = data_offset + raw.input_read;
    if (input.len - footer_offset < 8) return error.TruncatedFrame;
    const expected_crc = std.mem.readInt(u32, input[footer_offset..][0..4], .little);
    const expected_size = std.mem.readInt(u32, input[footer_offset + 4 ..][0..4], .little);
    if (checksum.crc32(raw.bytes) != expected_crc) return error.ChecksumMismatch;
    if (@as(u32, @truncate(raw.bytes.len)) != expected_size) return error.SizeMismatch;
    if (footer_offset + 8 != input.len) return error.TrailingData;
    return raw.bytes;
}

fn validateZlibHeader(cmf: u8, flg: u8) Error!void {
    if ((cmf & 0x0f) != 8) return error.BadZlibHeader;
    if ((cmf >> 4) > 7) return error.BadZlibHeader;
    const combined: u16 = (@as(u16, cmf) << 8) | flg;
    if (combined % 31 != 0) return error.BadZlibHeader;
    if ((flg & 0x20) != 0) return error.BadZlibHeader;
}

const gzip_header = [_]u8{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03 };

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
}

test "gzip stored wrapper matches level-0 vectors" {
    const empty = try encodeGzipStoredAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqualSlices(u8, &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, empty);

    const hello = try encodeGzipStoredAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(hello);
    try std.testing.expectEqualSlices(u8, &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0x01, 0x05, 0x00, 0xfa, 0xff, 'h', 'e', 'l', 'l', 'o', 0x86, 0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00 }, hello);
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

    const zlib_frame = &.{ 0x78, 0x01, 0x00, 0x02, 0x00, 0xfd, 0xff, 'h', 'i', 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x0b, 0x7c, 0x02, 0xe6 };
    const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, plain, zlib_decoded);

    const gzip_frame = &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x02, 0x00, 0xfd, 0xff, 'h', 'i', 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0xf5, 0xd2, 0xfc, 0xfa, 0x07, 0x00, 0x00, 0x00 };
    const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, plain, gzip_decoded);
}

test "gzip decoder accepts optional extra name comment and header crc fields" {
    const with_options = &.{
        0x1f, 0x8b, 0x08, 0x1e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
        0x04, 0x00, 'a',  'b',  'c',  'd',  'n',  'a',  'm',  'e',
        0x00, 'c',  'o',  'm',  'm',  'e',  'n',  't',  0x00, 0x00,
        0x00, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x86, 0xa6,
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
