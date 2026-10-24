const std = @import("std");
const core = @import("../core.zig");
const decoder = @import("decoder.zig");
const format = @import("format.zig");
const lzvn = @import("lzvn.zig");
const encoder = @import("encoder.zig");

pub const Error = core.Error || decoder.Error || format.Error || lzvn.Error ||
    std.mem.Allocator.Error || encoder.Error || error{InvalidLzfseStream};

pub const Options = encoder.Options;

pub const BlockKind = enum {
    uncompressed,
    lzvn,
    compressed_v1,
    compressed_v2,
};

pub const Block = struct {
    kind: BlockKind,
    offset: usize,
    header_size: usize,
    payload_offset: usize,
    payload_size: usize,
    raw_size: usize,
    next_offset: usize,
};

pub const BlockIterator = struct {
    input: []const u8,
    position: usize = 0,
    decoded_position: usize = 0,
    done: bool = false,

    pub fn next(self: *BlockIterator) Error!?Block {
        if (self.done) return null;
        const magic = try readMagic(self.input, self.position);
        if (magic == format.end_of_stream_magic) {
            const end = try checkedEnd(self.position, 4, self.input.len);
            if (end != self.input.len) return error.TrailingData;
            self.position = end;
            self.done = true;
            return null;
        }
        const block = try parseBlockWithHistory(self.input, self.position, self.decoded_position);
        self.position = block.next_offset;
        self.decoded_position = std.math.add(
            usize,
            self.decoded_position,
            block.raw_size,
        ) catch return error.IntegerOverflow;
        return block;
    }
};

pub const Archive = struct {
    bytes: []const u8,
    block_count: usize,
    decoded_size: usize,

    pub fn iterator(self: Archive) BlockIterator {
        return .{ .input = self.bytes };
    }
};

pub fn parse(input: []const u8) Error!Archive {
    return parseLimited(input, std.math.maxInt(usize));
}

pub fn parseLimited(input: []const u8, max_output_len: usize) Error!Archive {
    var iterator = BlockIterator{ .input = input };
    var block_count: usize = 0;
    var decoded_size: usize = 0;
    while (try iterator.next()) |block| {
        block_count = std.math.add(usize, block_count, 1) catch
            return error.IntegerOverflow;
        decoded_size = std.math.add(usize, decoded_size, block.raw_size) catch
            return error.IntegerOverflow;
        if (decoded_size > max_output_len) return error.OutputLimitExceeded;
    }
    if (!iterator.done) return error.TruncatedFrame;
    return .{
        .bytes = input,
        .block_count = block_count,
        .decoded_size = decoded_size,
    };
}

pub fn parseBlock(input: []const u8, offset: usize) Error!Block {
    return parseBlockWithHistory(input, offset, 0);
}

fn parseBlockWithHistory(input: []const u8, offset: usize, history_size: usize) Error!Block {
    const magic = try readMagic(input, offset);
    if (magic == format.uncompressed_magic) {
        const payload_offset = try checkedEnd(offset, 8, input.len);
        const raw_size: usize = readU32(input, offset + 4);
        const next_offset = try checkedEnd(payload_offset, raw_size, input.len);
        return .{
            .kind = .uncompressed,
            .offset = offset,
            .header_size = 8,
            .payload_offset = payload_offset,
            .payload_size = raw_size,
            .raw_size = raw_size,
            .next_offset = next_offset,
        };
    }
    if (magic == format.compressed_lzvn_magic) {
        const payload_offset = try checkedEnd(offset, 12, input.len);
        const raw_size: usize = readU32(input, offset + 4);
        const payload_size: usize = readU32(input, offset + 8);
        const next_offset = try checkedEnd(payload_offset, payload_size, input.len);
        const decoded_size = try lzvn.decodedSizeWithPrefixLimited(
            input[payload_offset..next_offset],
            history_size,
            raw_size,
        );
        if (decoded_size != raw_size) return error.SizeMismatch;
        return .{
            .kind = .lzvn,
            .offset = offset,
            .header_size = 12,
            .payload_offset = payload_offset,
            .payload_size = payload_size,
            .raw_size = raw_size,
            .next_offset = next_offset,
        };
    }
    if (magic == format.compressed_v1_magic or magic == format.compressed_v2_magic) {
        const header = try format.parseCompressedHeader(input[offset..]);
        const payload_offset = try checkedEnd(offset, header.header_size, input.len);
        const payload_size = try header.payloadSize();
        const next_offset = try checkedEnd(payload_offset, payload_size, input.len);
        return .{
            .kind = if (magic == format.compressed_v1_magic) .compressed_v1 else .compressed_v2,
            .offset = offset,
            .header_size = header.header_size,
            .payload_offset = payload_offset,
            .payload_size = payload_size,
            .raw_size = header.raw_size,
            .next_offset = next_offset,
        };
    }
    return error.InvalidMagic;
}

pub const encodeAlloc = encoder.encodeAlloc;
pub const encodeWithSummaryAlloc = encoder.encodeWithSummaryAlloc;
pub const encodeAppend = encoder.encodeAppend;
pub const encodeInto = encoder.encodeInto;

pub fn decodeAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return decodeAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) Error![]u8 {
    const archive = try parseLimited(input, max_output_len);
    const output = try allocator.alloc(u8, archive.decoded_size);
    errdefer allocator.free(output);
    _ = try decodeIntoParsed(archive, output);
    return output;
}

pub fn decodeInto(input: []const u8, output: []u8) Error!usize {
    return decodeIntoParsed(try parse(input), output);
}

fn decodeIntoParsed(archive: Archive, output: []u8) Error!usize {
    if (output.len < archive.decoded_size) return error.OutputTooSmall;
    var iterator = archive.iterator();
    var output_offset: usize = 0;
    while (try iterator.next()) |block| {
        const block_output = output[output_offset..][0..block.raw_size];
        const payload = archive.bytes[block.payload_offset..block.next_offset];
        switch (block.kind) {
            .uncompressed => @memcpy(block_output, payload),
            .lzvn => {
                const written = try lzvn.decodeIntoWithPrefix(
                    payload,
                    output,
                    output_offset,
                    block.raw_size,
                );
                if (written != block.raw_size) return error.SizeMismatch;
            },
            .compressed_v1, .compressed_v2 => {
                const header = try format.parseCompressedHeader(archive.bytes[block.offset..]);
                const literal_end = header.literal_payload_size;
                const written = try decoder.decodePayloadInto(
                    header,
                    payload[0..literal_end],
                    payload[literal_end..],
                    output,
                    output_offset,
                );
                if (written != block.raw_size) return error.SizeMismatch;
            },
        }
        output_offset += block.raw_size;
    }
    return output_offset;
}

fn readMagic(input: []const u8, offset: usize) Error!u32 {
    _ = try checkedEnd(offset, 4, input.len);
    return readU32(input, offset);
}

fn readU32(input: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, input[offset..][0..4], .little);
}

fn checkedEnd(start: usize, size: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, size) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

test "LZFSE writer selects deterministic LZVN and stored blocks" {
    const allocator = std.testing.allocator;
    const empty = try encodeAlloc(allocator, "", .{});
    defer allocator.free(empty);
    const empty_archive = try parse(empty);
    try std.testing.expectEqual(@as(usize, 1), empty_archive.block_count);
    try std.testing.expectEqual(@as(usize, 0), empty_archive.decoded_size);

    const input = "LZFSE deterministic stored fallback\n" ** 512;
    const encoded = try encodeAlloc(allocator, input, .{ .block_size = 257 });
    defer allocator.free(encoded);
    const archive = try parse(encoded);
    try std.testing.expect(archive.block_count > 2);
    try std.testing.expectEqual(input.len, archive.decoded_size);
    var iterator = archive.iterator();
    try std.testing.expectEqual(BlockKind.lzvn, (try iterator.next()).?.kind);
    const decoded = try decodeAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);

    const stored = try encodeAlloc(allocator, input[0..1024], .{
        .block_size = 257,
        .use_lzvn = false,
    });
    defer allocator.free(stored);
    const stored_archive = try parse(stored);
    var stored_iterator = stored_archive.iterator();
    try std.testing.expectEqual(BlockKind.uncompressed, (try stored_iterator.next()).?.kind);
}

test "LZFSE decodes Apple uncompressed and LZVN reference streams" {
    const allocator = std.testing.allocator;
    const raw_stream = "bvx-\x03\x00\x00\x00abcbvx$";
    const raw = try decodeAlloc(allocator, raw_stream);
    defer allocator.free(raw);
    try std.testing.expectEqualSlices(u8, "abc", raw);

    const lzvn_stream = [_]u8{
        'b', 'v',  'x',  'n', 48,  0,   0,    0,    17,   0,   0,
        0,   0xc8, 0x03, 'a', 'b', 'c', 0xf0, 0x18, 0xe1, 'c', 0x06,
        0,   0,    0,    0,   0,   0,   0,    'b',  'v',  'x', '$',
    };
    const expected = "abcabcabcabcabcabcabcabcabcabcabcabcabcabcabcabc";
    const decoded = try decodeAlloc(allocator, &lzvn_stream);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "LZFSE decodes Apple compressed V2 reference stream" {
    const allocator = std.testing.allocator;
    const encoded = try fixtureAlloc(
        allocator,
        @embedFile("testdata/apple-zero-100k-v2.lzfse.hex"),
    );
    defer allocator.free(encoded);
    const archive = try parse(encoded);
    try std.testing.expectEqual(@as(usize, 1), archive.block_count);
    try std.testing.expectEqual(@as(usize, 100_000), archive.decoded_size);
    var iterator = archive.iterator();
    try std.testing.expectEqual(BlockKind.compressed_v2, (try iterator.next()).?.kind);
    const decoded = try decodeAllocLimited(allocator, encoded, 100_000);
    defer allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 100_000), decoded.len);
    for (decoded) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
}

test "LZFSE decodes expanded V1 reference stream" {
    const allocator = std.testing.allocator;
    const encoded = try fixtureAlloc(
        allocator,
        @embedFile("testdata/apple-zero-100k-v1.lzfse.hex"),
    );
    defer allocator.free(encoded);
    const archive = try parse(encoded);
    var iterator = archive.iterator();
    try std.testing.expectEqual(BlockKind.compressed_v1, (try iterator.next()).?.kind);
    const decoded = try decodeAllocLimited(allocator, encoded, 100_000);
    defer allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 100_000), decoded.len);
    for (decoded) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
}

test "LZFSE stream enforces terminator bounds and trailing data" {
    const allocator = std.testing.allocator;
    const encoded = try encodeAlloc(allocator, "bounded LZFSE", .{});
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAllocLimited(allocator, encoded, "bounded LZFSE".len - 1),
    );
    var too_small: [1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodeInto(encoded, &too_small));
    try std.testing.expectError(error.TruncatedFrame, parse(encoded[0 .. encoded.len - 1]));
    var trailing = try allocator.dupe(u8, encoded);
    defer allocator.free(trailing);
    trailing[trailing.len - 1] = 0;
    try std.testing.expectError(error.InvalidMagic, parse(trailing));
}

fn fixtureAlloc(allocator: std.mem.Allocator, encoded_hex: []const u8) ![]u8 {
    var compact: std.ArrayList(u8) = .empty;
    defer compact.deinit(allocator);
    for (encoded_hex) |byte| {
        if (!std.ascii.isWhitespace(byte)) try compact.append(allocator, byte);
    }
    if (compact.items.len % 2 != 0) return error.InvalidLzfseStream;
    const bytes = try allocator.alloc(u8, compact.items.len / 2);
    errdefer allocator.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, compact.items);
    return bytes;
}
