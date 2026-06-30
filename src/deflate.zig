const std = @import("std");
const checksum = @import("checksum.zig");
const bitstream = @import("bitstream.zig");
const huffman = @import("huffman.zig");
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
            if (final == 0) return error.UnsupportedDeflateFeature;
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
            if (final == 0) return error.UnsupportedDeflateFeature;
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

pub fn decodeGzipStored(input: []const u8, output: []u8) Error!usize {
    if (input.len < 10) return error.TruncatedFrame;
    try validateGzipHeader(input[0..10]);

    const raw = try decodeRawStored(input[10..], output);
    const footer_offset = 10 + raw.input_read;
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

fn validateZlibHeader(cmf: u8, flg: u8) Error!void {
    if ((cmf & 0x0f) != 8) return error.BadZlibHeader;
    if ((cmf >> 4) > 7) return error.BadZlibHeader;
    const combined: u16 = (@as(u16, cmf) << 8) | flg;
    if (combined % 31 != 0) return error.BadZlibHeader;
    if ((flg & 0x20) != 0) return error.BadZlibHeader;
}

const gzip_header = [_]u8{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03 };

fn validateGzipHeader(header: []const u8) Error!void {
    if (header.len < 10) return error.TruncatedFrame;
    if (!std.mem.eql(u8, header[0..2], &.{ 0x1f, 0x8b })) return error.BadGzipHeader;
    if (header[2] != 8) return error.BadGzipHeader;
    if (header[3] != 0) return error.BadGzipHeader;
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
