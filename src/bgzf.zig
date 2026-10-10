const std = @import("std");
const checksum = @import("checksum.zig");
const core = @import("core.zig");
const deflate = @import("deflate.zig");

pub const Error = core.Error || deflate.Error || std.mem.Allocator.Error || error{
    InvalidBgzfStream,
    InvalidBgzfBlock,
    InvalidBgzfVirtualOffset,
};

pub const max_block_size: usize = 64 * 1024;
pub const safe_uncompressed_block_size: usize = 65_280;
pub const eof_marker = [_]u8{
    0x1f, 0x8b, 0x08, 0x04, 0x00, 0x00, 0x00, 0x00,
    0x00, 0xff, 0x06, 0x00, 0x42, 0x43, 0x02, 0x00,
    0x1b, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
};

pub const Block = struct {
    offset: usize,
    total_size: usize,
    data_offset: usize,
    compressed_size: usize,
    uncompressed_size: usize,
    crc32: u32,
    next_offset: usize,
    is_eof: bool,
};

pub const Archive = struct {
    bytes: []const u8,
    block_count: usize,
    decoded_size: usize,
    has_eof: bool,

    pub fn iterator(self: Archive) Iterator {
        return .{ .archive = self };
    }
};

pub const Iterator = struct {
    archive: Archive,
    offset: usize = 0,

    pub fn next(self: *Iterator) Error!?Block {
        if (self.offset == self.archive.bytes.len) return null;
        const block = try parseBlock(self.archive.bytes, self.offset);
        self.offset = block.next_offset;
        return block;
    }
};

pub const VirtualOffset = struct {
    compressed_offset: u64,
    uncompressed_offset: u16,

    pub fn pack(self: VirtualOffset) Error!u64 {
        if (self.compressed_offset > 0x0000_ffff_ffff_ffff)
            return error.InvalidBgzfVirtualOffset;
        return (self.compressed_offset << 16) | self.uncompressed_offset;
    }

    pub fn unpack(value: u64) VirtualOffset {
        return .{
            .compressed_offset = value >> 16,
            .uncompressed_offset = @truncate(value),
        };
    }
};

pub const EncodeOptions = struct {
    block_size: usize = max_block_size,
    compression_options: deflate.CompressionOptions = deflate.optionsForLevel(.default),
    eof: bool = true,
};

pub fn parse(input: []const u8) Error!Archive {
    if (input.len == 0) return error.InvalidMagic;
    var offset: usize = 0;
    var block_count: usize = 0;
    var decoded_size: usize = 0;
    var has_eof = false;
    while (offset < input.len) {
        const block = try parseBlock(input, offset);
        if (has_eof) return error.TrailingData;
        if (block.is_eof) {
            has_eof = true;
        } else {
            block_count = std.math.add(usize, block_count, 1) catch
                return error.IntegerOverflow;
            decoded_size = std.math.add(usize, decoded_size, block.uncompressed_size) catch
                return error.IntegerOverflow;
        }
        offset = block.next_offset;
    }
    return .{
        .bytes = input,
        .block_count = block_count,
        .decoded_size = decoded_size,
        .has_eof = has_eof,
    };
}

pub fn parseBlock(input: []const u8, offset: usize) Error!Block {
    const base_end = try checkedEnd(offset, 12, input.len);
    const base = input[offset..base_end];
    if (base[0] != 0x1f or base[1] != 0x8b or base[2] != 8)
        return error.InvalidMagic;
    const flags = base[3];
    if (flags & 0xe0 != 0 or flags & 0x04 == 0) return error.InvalidBgzfBlock;
    const extra_len = std.mem.readInt(u16, base[10..12], .little);
    const extra_start = base_end;
    const extra_end = try checkedEnd(extra_start, extra_len, input.len);
    var extra_offset = extra_start;
    var block_size: ?usize = null;
    while (extra_offset < extra_end) {
        const sub_end = try checkedEnd(extra_offset, 4, extra_end);
        const sub_len = std.mem.readInt(u16, input[extra_offset + 2 ..][0..2], .little);
        const data_start = sub_end;
        const data_end = try checkedEnd(data_start, sub_len, extra_end);
        if (input[extra_offset] == 'B' and input[extra_offset + 1] == 'C') {
            if (sub_len != 2 or block_size != null) return error.InvalidBgzfBlock;
            block_size = @as(usize, std.mem.readInt(u16, input[data_start..][0..2], .little)) + 1;
        }
        extra_offset = data_end;
    }
    if (extra_offset != extra_end) return error.InvalidBgzfBlock;
    const total_size = block_size orelse return error.InvalidBgzfBlock;
    if (total_size > max_block_size or total_size < 26) return error.InvalidBgzfBlock;
    const block_end = try checkedEnd(offset, total_size, input.len);
    const trailer_offset = block_end - 8;
    var data_offset = extra_end;
    if (flags & 0x08 != 0) data_offset = try skipZeroTerminated(input, data_offset, trailer_offset);
    if (flags & 0x10 != 0) data_offset = try skipZeroTerminated(input, data_offset, trailer_offset);
    if (flags & 0x02 != 0) {
        const crc_end = try checkedEnd(data_offset, 2, trailer_offset);
        const expected = std.mem.readInt(u16, input[data_offset..][0..2], .little);
        if (@as(u16, @truncate(checksum.crc32(input[offset..data_offset]))) != expected)
            return error.ChecksumMismatch;
        data_offset = crc_end;
    }
    if (block_end < data_offset or block_end - data_offset < 8) return error.InvalidBgzfBlock;
    const stored_crc = std.mem.readInt(u32, input[trailer_offset..][0..4], .little);
    const uncompressed_size_u32 = std.mem.readInt(u32, input[trailer_offset + 4 ..][0..4], .little);
    if (uncompressed_size_u32 > max_block_size) return error.InvalidBgzfBlock;
    const compressed_size = trailer_offset - data_offset;
    const is_eof = uncompressed_size_u32 == 0 and stored_crc == 0 and
        compressed_size == 2 and std.mem.eql(u8, input[data_offset..trailer_offset], &.{ 3, 0 });
    return .{
        .offset = offset,
        .total_size = total_size,
        .data_offset = data_offset,
        .compressed_size = compressed_size,
        .uncompressed_size = uncompressed_size_u32,
        .crc32 = stored_crc,
        .next_offset = block_end,
        .is_eof = is_eof,
    };
}

pub fn decodedSize(input: []const u8) Error!usize {
    return decodedSizeLimited(input, std.math.maxInt(usize));
}

pub fn decodedSizeLimited(input: []const u8, max_output_len: usize) Error!usize {
    const archive = try parse(input);
    if (archive.decoded_size > max_output_len) return error.OutputLimitExceeded;
    return archive.decoded_size;
}

pub fn decodeAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) ![]u8 {
    const size = try decodedSizeLimited(input, max_output_len);
    const output = try allocator.alloc(u8, size);
    errdefer allocator.free(output);
    _ = try decodeInto(allocator, input, output);
    return output;
}

pub fn decodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
) !usize {
    const archive = try parse(input);
    if (output.len < archive.decoded_size) return error.OutputTooSmall;
    var iterator_value = archive.iterator();
    var output_offset: usize = 0;
    while (try iterator_value.next()) |block| {
        const decoded = try decodeBlockAlloc(allocator, input, block);
        defer allocator.free(decoded);
        if (!block.is_eof) {
            @memcpy(output[output_offset..][0..decoded.len], decoded);
            output_offset += decoded.len;
        }
    }
    return output_offset;
}

pub fn decodeRangeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    start_value: u64,
    end_value: u64,
    max_output_len: usize,
) ![]u8 {
    if (start_value > end_value) return error.InvalidBgzfVirtualOffset;
    const start = VirtualOffset.unpack(start_value);
    const end = VirtualOffset.unpack(end_value);
    const start_offset = std.math.cast(usize, start.compressed_offset) orelse
        return error.InvalidBgzfVirtualOffset;
    const end_offset = std.math.cast(usize, end.compressed_offset) orelse
        return error.InvalidBgzfVirtualOffset;
    var offset = start_offset;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    while (true) {
        if (offset > end_offset) return error.InvalidBgzfVirtualOffset;
        const block = try parseBlock(input, offset);
        if (block.is_eof) {
            if (offset == end_offset and end.uncompressed_offset == 0)
                return output.toOwnedSlice(allocator);
            return error.InvalidBgzfVirtualOffset;
        }
        const decoded = try decodeBlockAlloc(allocator, input, block);
        defer allocator.free(decoded);
        const from: usize = if (offset == start_offset) start.uncompressed_offset else 0;
        const to: usize = if (offset == end_offset) end.uncompressed_offset else decoded.len;
        if (from > to or to > decoded.len) return error.InvalidBgzfVirtualOffset;
        if (to - from > max_output_len -| output.items.len)
            return error.OutputLimitExceeded;
        try output.appendSlice(allocator, decoded[from..to]);
        if (offset == end_offset) return output.toOwnedSlice(allocator);
        offset = block.next_offset;
    }
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    if (options.block_size == 0 or options.block_size > max_block_size)
        return error.InvalidBgzfBlock;
    const start = output.items.len;
    errdefer output.items.len = start;
    var input_offset: usize = 0;
    while (input_offset < input.len) {
        var length = @min(options.block_size, input.len - input_offset);
        var compressed = try deflate.encodeRawBestAlloc(
            allocator,
            input[input_offset .. input_offset + length],
            options.compression_options,
        );
        if (compressed.len + 26 > max_block_size and length > safe_uncompressed_block_size) {
            allocator.free(compressed);
            length = @min(safe_uncompressed_block_size, input.len - input_offset);
            compressed = try deflate.encodeRawBestAlloc(
                allocator,
                input[input_offset .. input_offset + length],
                options.compression_options,
            );
        }
        defer allocator.free(compressed);
        if (compressed.len + 26 > max_block_size) return error.InvalidBgzfBlock;
        try appendBlock(
            allocator,
            output,
            input[input_offset .. input_offset + length],
            compressed,
        );
        input_offset += length;
    }
    if (options.eof) try output.appendSlice(allocator, &eof_marker);
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
    output: []u8,
) !usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn appendBlock(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    plain: []const u8,
    compressed: []const u8,
) !void {
    const total_size = compressed.len + 26;
    if (total_size > max_block_size) return error.InvalidBgzfBlock;
    var header = [_]u8{
        0x1f, 0x8b, 0x08, 0x04, 0,    0,    0, 0, 0, 0xff,
        0x06, 0x00, 'B',  'C',  0x02, 0x00, 0, 0,
    };
    std.mem.writeInt(u16, header[16..18], @intCast(total_size - 1), .little);
    try output.appendSlice(allocator, &header);
    try output.appendSlice(allocator, compressed);
    var trailer: [8]u8 = undefined;
    std.mem.writeInt(u32, trailer[0..4], checksum.crc32(plain), .little);
    std.mem.writeInt(u32, trailer[4..8], @intCast(plain.len), .little);
    try output.appendSlice(allocator, &trailer);
}

fn decodeBlockAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    block: Block,
) ![]u8 {
    const payload = input[block.data_offset..][0..block.compressed_size];
    const decoded = try deflate.decodeRawAutoAllocExactSize(
        allocator,
        payload,
        block.uncompressed_size,
    );
    errdefer allocator.free(decoded);
    if (checksum.crc32(decoded) != block.crc32) return error.ChecksumMismatch;
    return decoded;
}

fn skipZeroTerminated(input: []const u8, start: usize, block_end: usize) Error!usize {
    if (start >= block_end) return error.InvalidBgzfBlock;
    const relative = std.mem.indexOfScalar(u8, input[start..block_end], 0) orelse
        return error.InvalidBgzfBlock;
    return start + relative + 1;
}

fn checkedEnd(start: usize, size: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, size) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

test "BGZF writer round trips multi-block random and repetitive data" {
    const allocator = std.testing.allocator;
    const input = try allocator.alloc(u8, 180_000);
    defer allocator.free(input);
    var random = std.Random.DefaultPrng.init(0x42475a465f746573);
    random.fill(input[0..90_000]);
    for (input[90_000..], 0..) |*byte, index| byte.* = @truncate(index % 17);
    const encoded = try encodeAlloc(allocator, input, .{});
    defer allocator.free(encoded);
    const archive = try parse(encoded);
    try std.testing.expect(archive.block_count >= 3);
    try std.testing.expect(archive.has_eof);
    const decoded = try decodeAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "BGZF virtual range crosses block boundaries" {
    const allocator = std.testing.allocator;
    const input = "BGZF virtual offset payload\n" ** 4096;
    const encoded = try encodeAlloc(allocator, input, .{ .block_size = 4096 });
    defer allocator.free(encoded);
    const first = try parseBlock(encoded, 0);
    const second = try parseBlock(encoded, first.next_offset);
    const start = try (VirtualOffset{
        .compressed_offset = 0,
        .uncompressed_offset = @intCast(first.uncompressed_size - 10),
    }).pack();
    const end = try (VirtualOffset{
        .compressed_offset = second.offset,
        .uncompressed_offset = 20,
    }).pack();
    const range = try decodeRangeAlloc(allocator, encoded, start, end, 30);
    defer allocator.free(range);
    try std.testing.expectEqualSlices(
        u8,
        input[first.uncompressed_size - 10 .. first.uncompressed_size + 20],
        range,
    );
}

test "BGZF parser validates EOF CRC and truncation" {
    const allocator = std.testing.allocator;
    const empty = try encodeAlloc(allocator, "", .{});
    defer allocator.free(empty);
    const archive = try parse(empty);
    try std.testing.expectEqual(@as(usize, 0), archive.block_count);
    try std.testing.expect(archive.has_eof);
    try std.testing.expectError(error.TruncatedFrame, parse(empty[0 .. empty.len - 1]));
    const corrupt = try allocator.dupe(u8, empty);
    defer allocator.free(corrupt);
    corrupt[16] = 0;
    try std.testing.expectError(error.InvalidBgzfBlock, parse(corrupt));
}
