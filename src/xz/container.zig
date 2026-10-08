const std = @import("std");
const core = @import("../core.zig");
const filters = @import("filters.zig");

pub const Error = core.Error || error{
    InvalidXzHeader,
    InvalidXzStream,
    UnsupportedXzFeature,
};

pub const Check = enum(u4) {
    none = 0,
    crc32 = 1,
    crc64 = 4,
    sha256 = 10,
    _,
};

pub const StreamInfo = struct {
    check: Check,
    block_count: usize,
    compressed_size: usize,
    uncompressed_size: usize,
    max_dictionary_size: u64,
    delta_filter_blocks: usize,
    x86_filter_blocks: usize,
};

const stream_magic = [_]u8{ 0xfd, '7', 'z', 'X', 'Z', 0x00 };
const stream_footer_magic = [_]u8{ 'Y', 'Z' };

const BlockHeader = struct {
    end_offset: usize,
    header_size: usize,
    packed_size: ?u64,
    unpacked_size: ?u64,
    dictionary_size: u64,
    filters: [3]filters.Filter = undefined,
    filter_count: usize = 0,
};

const BlockRecord = struct {
    unpadded_size: u64,
    uncompressed_size: u64,
};

const Lzma2Scan = struct {
    packed_size: usize,
    unpacked_size: usize,
};

pub fn decodeInto(allocator: std.mem.Allocator, input: []const u8, output: []u8) !usize {
    const decoded = decodeAllocLimited(allocator, input, output.len) catch |err| switch (err) {
        error.OutputLimitExceeded => return error.OutputTooSmall,
        else => |decode_error| return decode_error,
    };
    defer allocator.free(decoded);
    @memcpy(output[0..decoded.len], decoded);
    return decoded.len;
}

pub fn decodeAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    const consumed = try decodeOne(allocator, input, &output, max_output_len);
    const end = try skipStreamPadding(input, consumed);
    if (end != input.len) return error.TrailingData;
    return output.toOwnedSlice(allocator);
}

pub fn decodedSize(allocator: std.mem.Allocator, input: []const u8) !usize {
    return decodedSizeLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodedSizeLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) !usize {
    const decoded = try decodeAllocLimited(allocator, input, max_output_len);
    defer allocator.free(decoded);
    return decoded.len;
}

pub fn decodeConcatenatedInto(allocator: std.mem.Allocator, input: []const u8, output: []u8) !usize {
    const decoded = decodeConcatenatedAllocLimited(allocator, input, output.len) catch |err| switch (err) {
        error.OutputLimitExceeded => return error.OutputTooSmall,
        else => |decode_error| return decode_error,
    };
    defer allocator.free(decoded);
    @memcpy(output[0..decoded.len], decoded);
    return decoded.len;
}

pub fn decodeConcatenatedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeConcatenatedAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeConcatenatedAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) ![]u8 {
    if (input.len == 0) return error.InvalidMagic;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var offset: usize = 0;
    while (offset < input.len) {
        offset = try decodeOne(allocator, input[offset..], &output, max_output_len) + offset;
        const after_padding = try skipStreamPadding(input, offset);
        if (after_padding == input.len) break;
        offset = after_padding;
    }
    return output.toOwnedSlice(allocator);
}

pub fn decodedSizeConcatenated(allocator: std.mem.Allocator, input: []const u8) !usize {
    return decodedSizeConcatenatedLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodedSizeConcatenatedLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) !usize {
    const decoded = try decodeConcatenatedAllocLimited(allocator, input, max_output_len);
    defer allocator.free(decoded);
    return decoded.len;
}

pub fn inspect(allocator: std.mem.Allocator, input: []const u8) !StreamInfo {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    const parsed = try decodeOneWithInfo(allocator, input, &output, std.math.maxInt(usize));
    const end = try skipStreamPadding(input, parsed.info.compressed_size);
    if (end != input.len) return error.TrailingData;
    return parsed.info;
}

const DecodedStream = struct { consumed: usize, info: StreamInfo };

fn decodeOne(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: *std.ArrayList(u8),
    max_output_len: usize,
) !usize {
    return (try decodeOneWithInfo(allocator, input, output, max_output_len)).consumed;
}

fn decodeOneWithInfo(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: *std.ArrayList(u8),
    max_output_len: usize,
) !DecodedStream {
    const output_start = output.items.len;
    errdefer output.items.len = output_start;
    if (input.len < 12) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..6], &stream_magic)) return error.InvalidMagic;
    const flags = input[6..8];
    if (flags[0] != 0 or flags[1] & 0xf0 != 0) return error.InvalidXzHeader;
    if (std.hash.Crc32.hash(flags) != try readU32(input, 8)) return error.ChecksumMismatch;
    const check: Check = @enumFromInt(flags[1] & 0x0f);
    const check_size = try checkSize(check);

    var records: std.ArrayList(BlockRecord) = .empty;
    defer records.deinit(allocator);
    var max_dictionary_size: u64 = 0;
    var delta_filter_blocks: usize = 0;
    var x86_filter_blocks: usize = 0;
    var offset: usize = 12;
    while (true) {
        if (offset >= input.len) return error.TruncatedFrame;
        if (input[offset] == 0) break;
        const header = try parseBlockHeader(input, offset);
        max_dictionary_size = @max(max_dictionary_size, header.dictionary_size);
        const scan = try scanLzma2(input[header.end_offset..], max_output_len -| output.items.len);
        if (header.packed_size) |declared|
            if (declared != scan.packed_size) return error.SizeMismatch;
        if (header.unpacked_size) |declared|
            if (declared != scan.unpacked_size) return error.SizeMismatch;

        const data_end = try checkedEnd(header.end_offset, scan.packed_size, input.len);
        const block_padding_len = (4 - ((header.header_size + scan.packed_size) % 4)) % 4;
        const padding_end = try checkedEnd(data_end, block_padding_len, input.len);
        for (input[data_end..padding_end]) |byte| if (byte != 0) return error.InvalidXzStream;
        const check_end = try checkedEnd(padding_end, check_size, input.len);

        const decoded = try decodeLzma2Alloc(allocator, input[header.end_offset..data_end], scan.unpacked_size);
        defer allocator.free(decoded);
        filters.decodeChain(decoded, header.filters[0..header.filter_count]);
        try verifyCheck(check, decoded, input[padding_end..check_end]);
        const output_end = std.math.add(usize, output.items.len, decoded.len) catch return error.OutputLimitExceeded;
        if (output_end > max_output_len) return error.OutputLimitExceeded;
        try output.appendSlice(allocator, decoded);

        const unpadded_size = std.math.add(
            u64,
            @as(u64, @intCast(header.header_size + scan.packed_size)),
            check_size,
        ) catch return error.IntegerOverflow;
        try records.append(allocator, .{
            .unpadded_size = unpadded_size,
            .uncompressed_size = scan.unpacked_size,
        });
        for (header.filters[0..header.filter_count]) |filter| switch (filter.kind) {
            .delta => delta_filter_blocks += 1,
            .x86 => x86_filter_blocks += 1,
        };
        offset = check_end;
    }

    const index_start = offset;
    offset += 1;
    const record_count = try readVli(input, &offset, input.len);
    if (record_count != records.items.len) return error.InvalidXzStream;
    for (records.items) |record| {
        if (try readVli(input, &offset, input.len) != record.unpadded_size or
            try readVli(input, &offset, input.len) != record.uncompressed_size)
            return error.InvalidXzStream;
    }
    while ((offset - index_start) % 4 != 0) {
        if (try readByte(input, &offset, input.len) != 0) return error.InvalidXzStream;
    }
    const index_crc_offset = offset;
    const stored_index_crc = try readU32(input, index_crc_offset);
    if (stored_index_crc != std.hash.Crc32.hash(input[index_start..index_crc_offset]))
        return error.ChecksumMismatch;
    offset = try checkedEnd(offset, 4, input.len);
    const index_size = offset - index_start;

    const footer_end = try checkedEnd(offset, 12, input.len);
    const footer = input[offset..footer_end];
    if (std.hash.Crc32.hash(footer[4..10]) != std.mem.readInt(u32, footer[0..4], .little))
        return error.ChecksumMismatch;
    const backward_size = (@as(u64, std.mem.readInt(u32, footer[4..8], .little)) + 1) * 4;
    if (backward_size != index_size) return error.InvalidXzStream;
    if (!std.mem.eql(u8, footer[8..10], flags)) return error.InvalidXzStream;
    if (!std.mem.eql(u8, footer[10..12], &stream_footer_magic)) return error.InvalidXzStream;

    const produced = output.items.len - output_start;
    return .{
        .consumed = footer_end,
        .info = .{
            .check = check,
            .block_count = records.items.len,
            .compressed_size = footer_end,
            .uncompressed_size = produced,
            .max_dictionary_size = max_dictionary_size,
            .delta_filter_blocks = delta_filter_blocks,
            .x86_filter_blocks = x86_filter_blocks,
        },
    };
}

fn parseBlockHeader(input: []const u8, start: usize) Error!BlockHeader {
    const size_byte = try byteAt(input, start);
    if (size_byte == 0) return error.InvalidXzStream;
    const header_without_crc = @as(usize, size_byte) * 4;
    const crc_offset = try checkedEnd(start, header_without_crc, input.len);
    const end_offset = try checkedEnd(crc_offset, 4, input.len);
    if (std.hash.Crc32.hash(input[start..crc_offset]) != try readU32(input, crc_offset))
        return error.ChecksumMismatch;

    var cursor = start + 1;
    const flags = try readByte(input, &cursor, crc_offset);
    if (flags & 0x3c != 0) return error.InvalidXzHeader;
    const filter_count = @as(usize, flags & 0x03) + 1;
    const packed_size = if (flags & 0x40 != 0) try readVli(input, &cursor, crc_offset) else null;
    const unpacked_size = if (flags & 0x80 != 0) try readVli(input, &cursor, crc_offset) else null;
    var decoded_filters: [3]filters.Filter = undefined;
    var decoded_filter_count: usize = 0;
    var dictionary_property: ?u8 = null;
    for (0..filter_count) |filter_index| {
        const filter_id = try readVli(input, &cursor, crc_offset);
        const properties_size_u64 = try readVli(input, &cursor, crc_offset);
        const properties_size = std.math.cast(usize, properties_size_u64) orelse return error.UnsupportedXzFeature;
        const properties_end = try checkedEnd(cursor, properties_size, crc_offset);
        const properties = input[cursor..properties_end];
        cursor = properties_end;
        if (filter_index + 1 == filter_count) {
            if (filter_id != 0x21) return error.UnsupportedXzFeature;
            if (properties.len != 1 or properties[0] > 40) return error.InvalidXzHeader;
            dictionary_property = properties[0];
        } else {
            decoded_filters[decoded_filter_count] = try filters.parse(filter_id, properties);
            decoded_filter_count += 1;
        }
    }
    while (cursor < crc_offset) : (cursor += 1)
        if (input[cursor] != 0) return error.InvalidXzHeader;

    return .{
        .end_offset = end_offset,
        .header_size = header_without_crc + 4,
        .packed_size = packed_size,
        .unpacked_size = unpacked_size,
        .dictionary_size = lzma2DictionarySize(dictionary_property orelse return error.InvalidXzHeader),
        .filters = decoded_filters,
        .filter_count = decoded_filter_count,
    };
}

fn scanLzma2(input: []const u8, output_limit: usize) Error!Lzma2Scan {
    var offset: usize = 0;
    var unpacked_size: usize = 0;
    var dictionary_initialized = false;
    var properties_initialized = false;
    var state_initialized = false;
    while (true) {
        const control = try readByte(input, &offset, input.len);
        switch (control) {
            0 => return .{ .packed_size = offset, .unpacked_size = unpacked_size },
            1, 2 => {
                if (control == 1) dictionary_initialized = true else if (!dictionary_initialized) return error.InvalidXzStream;
                state_initialized = false;
                const chunk_size = @as(usize, try readU16Big(input, &offset, input.len)) + 1;
                const chunk_end = try checkedEnd(offset, chunk_size, input.len);
                unpacked_size = try addOutputSize(unpacked_size, chunk_size, output_limit);
                offset = chunk_end;
            },
            0x80...0xff => {
                const reset = (control >> 5) & 0x03;
                if (reset == 3) dictionary_initialized = true;
                if (!dictionary_initialized) return error.InvalidXzStream;
                if (reset >= 2) properties_initialized = true;
                if (!properties_initialized) return error.InvalidXzStream;
                if (reset >= 1) state_initialized = true else if (!state_initialized) return error.InvalidXzStream;

                const chunk_size = (@as(usize, control & 0x1f) << 16) |
                    @as(usize, try readU16Big(input, &offset, input.len));
                const packed_size = @as(usize, try readU16Big(input, &offset, input.len)) + 1;
                if (reset >= 2) {
                    const property = try readByte(input, &offset, input.len);
                    if (property >= 225) return error.InvalidXzStream;
                    const remainder = property / 9;
                    if (property % 9 + remainder % 5 > 4) return error.InvalidXzStream;
                }
                const packed_end = try checkedEnd(offset, packed_size, input.len);
                unpacked_size = try addOutputSize(unpacked_size, chunk_size + 1, output_limit);
                offset = packed_end;
            },
            else => return error.InvalidXzStream,
        }
    }
}

fn decodeLzma2Alloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_size: usize,
) ![]u8 {
    var source: std.Io.Reader = .fixed(input);
    var output = try std.Io.Writer.Allocating.initCapacity(allocator, expected_size);
    defer output.deinit();
    var decoder = std.compress.lzma2.Decode.init(allocator) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidXzStream,
    };
    defer decoder.deinit(allocator);
    const consumed = decoder.decompress(&source, &output) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidXzStream,
    };
    if (consumed != input.len or output.written().len != expected_size) return error.SizeMismatch;
    return output.toOwnedSlice();
}

fn verifyCheck(check: Check, decoded: []const u8, stored: []const u8) Error!void {
    switch (check) {
        .none => {},
        .crc32 => if (std.mem.readInt(u32, stored[0..4], .little) != std.hash.Crc32.hash(decoded))
            return error.ChecksumMismatch,
        .crc64 => if (std.mem.readInt(u64, stored[0..8], .little) != std.hash.crc.Crc64Xz.hash(decoded))
            return error.ChecksumMismatch,
        .sha256 => {
            var actual: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(decoded, &actual, .{});
            if (!std.mem.eql(u8, stored, &actual)) return error.ChecksumMismatch;
        },
        else => return error.UnsupportedXzFeature,
    }
}

fn checkSize(check: Check) Error!usize {
    return switch (check) {
        .none => 0,
        .crc32 => 4,
        .crc64 => 8,
        .sha256 => std.crypto.hash.sha2.Sha256.digest_length,
        else => error.UnsupportedXzFeature,
    };
}

fn lzma2DictionarySize(property: u8) u64 {
    if (property == 40) return std.math.maxInt(u32);
    return @as(u64, 2 | (property & 1)) << @intCast(property / 2 + 11);
}

fn skipStreamPadding(input: []const u8, start: usize) Error!usize {
    var offset = start;
    while (offset < input.len and input[offset] == 0) : (offset += 1) {}
    if ((offset - start) % 4 != 0) return error.InvalidXzStream;
    return offset;
}

fn addOutputSize(current: usize, additional: usize, limit: usize) Error!usize {
    const result = std.math.add(usize, current, additional) catch return error.OutputLimitExceeded;
    if (result > limit) return error.OutputLimitExceeded;
    return result;
}

fn readVli(input: []const u8, offset: *usize, limit: usize) Error!u64 {
    var value: u64 = 0;
    var shift: u6 = 0;
    for (0..9) |index| {
        const byte = try readByte(input, offset, limit);
        if (index == 8 and byte & 0x80 != 0) return error.InvalidXzStream;
        value |= @as(u64, byte & 0x7f) << shift;
        if (byte & 0x80 == 0) {
            if (index != 0 and byte == 0) return error.InvalidXzStream;
            return value;
        }
        shift += 7;
    }
    return error.InvalidXzStream;
}

fn readByte(input: []const u8, offset: *usize, limit: usize) Error!u8 {
    const value = try byteAtLimited(input, offset.*, limit);
    offset.* += 1;
    return value;
}

fn readU16Big(input: []const u8, offset: *usize, limit: usize) Error!u16 {
    const end = try checkedEnd(offset.*, 2, limit);
    const value = std.mem.readInt(u16, input[offset.*..][0..2], .big);
    offset.* = end;
    return value;
}

fn byteAt(input: []const u8, offset: usize) Error!u8 {
    return byteAtLimited(input, offset, input.len);
}

fn byteAtLimited(input: []const u8, offset: usize, limit: usize) Error!u8 {
    if (offset >= limit or offset >= input.len) return error.TruncatedFrame;
    return input[offset];
}

fn readU32(input: []const u8, offset: usize) Error!u32 {
    _ = try checkedEnd(offset, 4, input.len);
    return std.mem.readInt(u32, input[offset..][0..4], .little);
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, len) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

test "XZ decoder validates and decodes a CRC64 LZMA2 stream" {
    const encoded_hex = "fd377a585a000004e6d6b446020021010c0000008f98419ce000b300105d00341949db855c63b22e4804b99cbc0000000c15e87bd2673c5600012cb40100000021d8c0eeb1c467fb020000000004595a";
    var encoded: [encoded_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&encoded, encoded_hex);
    const expected = "hello xz\n" ** 20;

    const decoded = try decodeAlloc(std.testing.allocator, &encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    try std.testing.expectEqual(expected.len, try decodedSize(std.testing.allocator, &encoded));
    const info = try inspect(std.testing.allocator, &encoded);
    try std.testing.expectEqual(Check.crc64, info.check);
    try std.testing.expectEqual(@as(usize, 1), info.block_count);
    try std.testing.expectEqual(encoded.len, info.compressed_size);
    try std.testing.expectEqual(expected.len, info.uncompressed_size);
    try std.testing.expectEqual(@as(u64, 256 * 1024), info.max_dictionary_size);
    try std.testing.expectEqual(@as(usize, 0), info.delta_filter_blocks);
    try std.testing.expectEqual(@as(usize, 0), info.x86_filter_blocks);

    var output: [expected.len]u8 = undefined;
    try std.testing.expectEqual(expected.len, try decodeInto(std.testing.allocator, &encoded, &output));
    try std.testing.expectEqualSlices(u8, expected, &output);
    try std.testing.expectError(error.OutputTooSmall, decodeInto(std.testing.allocator, &encoded, output[0 .. output.len - 1]));
    try std.testing.expectError(error.OutputLimitExceeded, decodeAllocLimited(std.testing.allocator, &encoded, expected.len - 1));

    const header = try parseBlockHeader(&encoded, 12);
    const scan = try scanLzma2(encoded[header.end_offset..], expected.len);
    const data_end = header.end_offset + scan.packed_size;
    const padding_len = (4 - ((header.header_size + scan.packed_size) % 4)) % 4;
    var bad_block_check = encoded;
    bad_block_check[data_end + padding_len] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeAlloc(std.testing.allocator, &bad_block_check));
}

test "XZ decoder handles concatenated streams and rejects corrupt checks" {
    const encoded_hex = "fd377a585a0000016922de36020021010c0000008f98419ce000b300105d00341949db855c63b22e4804b99cbc0000007e9b26fd000128b401000000379a51753e300d8b020000000001595a";
    var encoded: [encoded_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&encoded, encoded_hex);
    const expected = "hello xz\n" ** 20;
    var concatenated: [encoded.len * 2 + 4]u8 = @splat(0);
    @memcpy(concatenated[0..encoded.len], &encoded);
    @memcpy(concatenated[encoded.len + 4 ..], &encoded);

    try std.testing.expectError(error.TrailingData, decodeAlloc(std.testing.allocator, &concatenated));
    const decoded = try decodeConcatenatedAlloc(std.testing.allocator, &concatenated);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(expected.len * 2, decoded.len);
    try std.testing.expectEqualSlices(u8, expected, decoded[0..expected.len]);
    try std.testing.expectEqualSlices(u8, expected, decoded[expected.len..]);

    var corrupt = encoded;
    corrupt[corrupt.len - 12] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeAlloc(std.testing.allocator, &corrupt));
    try std.testing.expectError(error.TruncatedFrame, decodeAlloc(std.testing.allocator, encoded[0 .. encoded.len - 1]));
    for (0..encoded.len) |truncated_len| {
        if (decodeAlloc(std.testing.allocator, encoded[0..truncated_len])) |unexpected| {
            std.testing.allocator.free(unexpected);
            return error.TestUnexpectedResult;
        } else |_| {}
    }
}
