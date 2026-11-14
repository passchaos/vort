const std = @import("std");
const bitstream = @import("../bitstream.zig");
const core = @import("../core.zig");
const huffman = @import("../huffman.zig");

pub const Error = core.Error || error{InvalidDeflate64Stream};

pub const DecodeResult = struct {
    input_read: usize,
    output_written: usize,
};

const code_length_order = [_]u8{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };

const LengthEntry = struct { base: usize, extra_bits: u6 };
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
};

pub fn decodeInto(input: []const u8, output: []u8) Error!DecodeResult {
    var sink = FixedOutput{ .bytes = output };
    const input_read = try decodeBlocks(input, &sink);
    return .{ .input_read = input_read, .output_written = sink.len };
}

pub fn decodeAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) ![]u8 {
    var sink = AllocatingOutput.init(allocator, max_output_len);
    defer sink.deinit();
    const input_read = try decodeBlocks(input, &sink);
    if (input_read != input.len) return error.TrailingData;
    return sink.toOwnedSlice();
}

pub fn decodedSize(allocator: std.mem.Allocator, input: []const u8) !usize {
    return decodedSizeLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodedSizeLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) !usize {
    const decoded = try decodeAllocLimited(allocator, input, max_output_len);
    defer allocator.free(decoded);
    return decoded.len;
}

fn decodeBlocks(input: []const u8, output: anytype) !usize {
    if (input.len == 0) return error.TruncatedFrame;
    var reader = bitstream.BufferedBitReader.init(input);
    while (true) {
        const header = try reader.readBits(u3, 3);
        const final = header & 1 != 0;
        switch (header >> 1) {
            0 => try decodeStoredBlock(&reader, output),
            1 => {
                const literal_table = try huffman.fixedLiteralTable();
                const distance_table = try huffman.fixedDistanceTable();
                try decodeCompressedBlock(&reader, output, &literal_table, &distance_table);
            },
            2 => {
                const tables = try parseDynamicTables(&reader);
                try decodeCompressedBlock(&reader, output, &tables.literal, &tables.distance);
            },
            else => return error.InvalidDeflateBlockType,
        }
        if (final) return reader.byteOffset();
    }
}

fn decodeStoredBlock(reader: *bitstream.BufferedBitReader, output: anytype) !void {
    reader.alignToByte();
    const length = try reader.readAlignedInt(u16, .little);
    const complement = try reader.readAlignedInt(u16, .little);
    if (complement != ~length) return error.StoredLengthMismatch;
    for (0..length) |_| try output.appendByte(try reader.readBits(u8, 8));
}

const DynamicTables = struct {
    literal: huffman.HuffmanTable(286),
    distance: huffman.HuffmanTable(32),
};

fn parseDynamicTables(reader: *bitstream.BufferedBitReader) !DynamicTables {
    const literal_count: usize = @as(usize, try reader.readBits(u5, 5)) + 257;
    const distance_count: usize = @as(usize, try reader.readBits(u5, 5)) + 1;
    const code_length_count: usize = @as(usize, try reader.readBits(u4, 4)) + 4;
    if (literal_count > 286 or distance_count > 32 or code_length_count > code_length_order.len)
        return error.InvalidDynamicBlockHeader;

    var code_length_lengths: [19]u4 = @splat(0);
    for (code_length_order[0..code_length_count]) |symbol|
        code_length_lengths[symbol] = try reader.readBits(u4, 3);
    const code_length_table = try huffman.HuffmanTable(19).init(&code_length_lengths);

    var literal_lengths: [286]u4 = @splat(0);
    var distance_lengths: [32]u4 = @splat(0);
    const total = literal_count + distance_count;
    var position: usize = 0;
    var previous: u4 = 0;
    while (position < total) {
        const symbol = try code_length_table.decodeValue(reader);
        switch (symbol) {
            0...15 => {
                setCodeLength(&literal_lengths, &distance_lengths, literal_count, position, @intCast(symbol));
                previous = @intCast(symbol);
                position += 1;
            },
            16 => {
                if (position == 0) return error.InvalidDynamicBlockHeader;
                const count = @as(usize, try reader.readBits(u2, 2)) + 3;
                if (count > total - position) return error.InvalidDynamicBlockHeader;
                for (0..count) |index|
                    setCodeLength(&literal_lengths, &distance_lengths, literal_count, position + index, previous);
                position += count;
            },
            17 => {
                const count = @as(usize, try reader.readBits(u3, 3)) + 3;
                if (count > total - position) return error.InvalidDynamicBlockHeader;
                for (0..count) |index|
                    setCodeLength(&literal_lengths, &distance_lengths, literal_count, position + index, 0);
                previous = 0;
                position += count;
            },
            18 => {
                const count = @as(usize, try reader.readBits(u7, 7)) + 11;
                if (count > total - position) return error.InvalidDynamicBlockHeader;
                for (0..count) |index|
                    setCodeLength(&literal_lengths, &distance_lengths, literal_count, position + index, 0);
                previous = 0;
                position += count;
            },
            else => return error.InvalidDynamicBlockHeader,
        }
    }
    if (literal_lengths[256] == 0) return error.InvalidDynamicBlockHeader;
    return .{
        .literal = try huffman.HuffmanTable(286).init(literal_lengths[0..literal_count]),
        .distance = try huffman.HuffmanTable(32).init(distance_lengths[0..distance_count]),
    };
}

fn setCodeLength(
    literal_lengths: *[286]u4,
    distance_lengths: *[32]u4,
    literal_count: usize,
    position: usize,
    value: u4,
) void {
    if (position < literal_count)
        literal_lengths[position] = value
    else
        distance_lengths[position - literal_count] = value;
}

fn decodeCompressedBlock(
    reader: *bitstream.BufferedBitReader,
    output: anytype,
    literal_table: anytype,
    distance_table: anytype,
) !void {
    while (true) {
        const symbol = try literal_table.decodeValue(reader);
        if (symbol < 256) {
            try output.appendByte(@intCast(symbol));
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance = try decodeDistance(try distance_table.decodeValue(reader), reader);
            try output.appendMatch(length, distance);
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn decodeLength(symbol: u16, reader: *bitstream.BufferedBitReader) Error!usize {
    if (symbol < 257 or symbol > 285) return error.InvalidHuffmanCode;
    if (symbol <= 264) return symbol - 254;
    if (symbol == 285) return 3 + @as(usize, try reader.readBits(u16, 16));
    const entry = length_table[symbol - 257];
    return entry.base + @as(usize, try reader.readBits(u16, entry.extra_bits));
}

fn decodeDistance(symbol: u16, reader: *bitstream.BufferedBitReader) Error!usize {
    if (symbol >= 32) return error.InvalidHuffmanCode;
    if (symbol < 4) return symbol + 1;
    const extra_bits: u6 = @intCast(symbol / 2 - 1);
    const base = ((@as(usize, 2) + (symbol & 1)) << @intCast(extra_bits)) + 1;
    return base + @as(usize, try reader.readBits(u16, extra_bits));
}

const FixedOutput = struct {
    bytes: []u8,
    len: usize = 0,

    fn appendByte(self: *FixedOutput, byte: u8) Error!void {
        if (self.len == self.bytes.len) return error.OutputTooSmall;
        self.bytes[self.len] = byte;
        self.len += 1;
    }

    fn appendMatch(self: *FixedOutput, length: usize, distance: usize) Error!void {
        if (distance == 0 or distance > self.len or distance > 64 * 1024)
            return error.InvalidMatch;
        if (length > self.bytes.len -| self.len) return error.OutputTooSmall;
        for (0..length) |_| {
            self.bytes[self.len] = self.bytes[self.len - distance];
            self.len += 1;
        }
    }
};

const AllocatingOutput = struct {
    allocator: std.mem.Allocator,
    bytes: std.ArrayList(u8) = .empty,
    max_output_len: usize,

    fn init(allocator: std.mem.Allocator, max_output_len: usize) AllocatingOutput {
        return .{ .allocator = allocator, .max_output_len = max_output_len };
    }

    fn deinit(self: *AllocatingOutput) void {
        self.bytes.deinit(self.allocator);
    }

    fn toOwnedSlice(self: *AllocatingOutput) ![]u8 {
        return self.bytes.toOwnedSlice(self.allocator);
    }

    fn appendByte(self: *AllocatingOutput, byte: u8) !void {
        if (self.bytes.items.len == self.max_output_len) return error.OutputLimitExceeded;
        try self.bytes.append(self.allocator, byte);
    }

    fn appendMatch(self: *AllocatingOutput, length: usize, distance: usize) !void {
        if (distance == 0 or distance > self.bytes.items.len or distance > 64 * 1024)
            return error.InvalidMatch;
        if (length > self.max_output_len -| self.bytes.items.len)
            return error.OutputLimitExceeded;
        try self.bytes.ensureUnusedCapacity(self.allocator, length);
        for (0..length) |_| {
            const byte = self.bytes.items[self.bytes.items.len - distance];
            self.bytes.appendAssumeCapacity(byte);
        }
    }
};

test "Deflate64 fixed block decodes extended length code 285" {
    var writer: bitstream.BitWriter = .{};
    defer writer.deinit(std.testing.allocator);
    try writer.writeBits(std.testing.allocator, 0b011, 3);
    try huffman.fixed_literal_encoder.writeSymbol(&writer, std.testing.allocator, 'A');
    try huffman.fixed_literal_encoder.writeSymbol(&writer, std.testing.allocator, 285);
    try writer.writeBits(std.testing.allocator, 297, 16);
    try huffman.fixed_distance_encoder.writeSymbol(&writer, std.testing.allocator, 0);
    try huffman.fixed_literal_encoder.writeSymbol(&writer, std.testing.allocator, 256);
    const encoded = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(encoded);

    var output: [301]u8 = undefined;
    const result = try decodeInto(encoded, &output);
    try std.testing.expectEqual(encoded.len, result.input_read);
    try std.testing.expectEqual(output.len, result.output_written);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 'A'), byte);
}

test "Deflate64 fixed block reaches the 64 KiB distance boundary" {
    var writer: bitstream.BitWriter = .{};
    defer writer.deinit(std.testing.allocator);
    var prefix: [64 * 1024]u8 = undefined;
    for (&prefix, 0..) |*byte, index| byte.* = @truncate(index *% 131 +% 17);
    for (prefix[0 .. 32 * 1024], prefix[32 * 1024 ..]) |first, *second| second.* = first;
    for (0..2) |index| {
        try writer.writeBits(std.testing.allocator, 0, 3);
        try writer.alignToByte(std.testing.allocator);
        var lengths: [4]u8 = undefined;
        std.mem.writeInt(u16, lengths[0..2], 32 * 1024, .little);
        std.mem.writeInt(u16, lengths[2..4], ~@as(u16, 32 * 1024), .little);
        try writer.bytes.appendSlice(std.testing.allocator, &lengths);
        try writer.bytes.appendSlice(std.testing.allocator, prefix[index * 32 * 1024 ..][0 .. 32 * 1024]);
    }
    try writer.writeBits(std.testing.allocator, 0b011, 3);
    try huffman.fixed_literal_encoder.writeSymbol(&writer, std.testing.allocator, 257);
    try huffman.fixed_distance_encoder.writeSymbol(&writer, std.testing.allocator, 31);
    try writer.writeBits(std.testing.allocator, std.math.maxInt(u14), 14);
    try huffman.fixed_literal_encoder.writeSymbol(&writer, std.testing.allocator, 256);
    const encoded = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(encoded);

    var output: [64 * 1024 + 3]u8 = undefined;
    const result = try decodeInto(encoded, &output);
    try std.testing.expectEqual(encoded.len, result.input_read);
    try std.testing.expectEqual(output.len, result.output_written);
    try std.testing.expectEqualSlices(u8, &prefix, output[0..prefix.len]);
    try std.testing.expectEqualSlices(u8, prefix[0..3], output[prefix.len..]);
}

test "Deflate64 decoder enforces corruption and output limits" {
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeAlloc(std.testing.allocator, &.{0b0000_0111}));
    const bad_stored = [_]u8{ 0x01, 1, 0, 1, 0, 'x' };
    try std.testing.expectError(error.StoredLengthMismatch, decodeAlloc(std.testing.allocator, &bad_stored));

    var encoded: [5 + 256]u8 = undefined;
    encoded[0] = 0x01;
    std.mem.writeInt(u16, encoded[1..3], 256, .little);
    std.mem.writeInt(u16, encoded[3..5], ~@as(u16, 256), .little);
    @memset(encoded[5..], 'x');
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAllocLimited(std.testing.allocator, &encoded, 255),
    );
}

test "Deflate64 allocating decoder rejects trailing bytes after the final block" {
    // A final empty stored block: BFINAL=1/BTYPE=00, LEN=0, NLEN=0xffff.
    const block = [_]u8{ 0x01, 0x00, 0x00, 0xff, 0xff };
    // The exact block decodes cleanly through both entry points.
    {
        const decoded = try decodeAlloc(std.testing.allocator, &block);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqual(@as(usize, 0), decoded.len);
        var output: [1]u8 = undefined;
        const result = try decodeInto(&block, &output);
        try std.testing.expectEqual(block.len, result.input_read);
        try std.testing.expectEqual(@as(usize, 0), result.output_written);
    }
    // Any byte past the final block is TrailingData for the allocating
    // one-shot API, which promises to consume the whole input.
    var with_trailing: [block.len + 1]u8 = undefined;
    @memcpy(with_trailing[0..block.len], &block);
    with_trailing[block.len] = 0x5a;
    try std.testing.expectError(error.TrailingData, decodeAlloc(std.testing.allocator, &with_trailing));
    // The fixed-buffer entry point reports the consumed block length instead
    // and leaves the trailing byte untouched, so no error is raised there.
    var output: [1]u8 = undefined;
    const result = try decodeInto(&with_trailing, &output);
    try std.testing.expectEqual(block.len, result.input_read);
}

/// Build a final fixed-Huffman Deflate64 block carrying one match: length
/// symbol 257 + 14 length-extra bits (length 3 + 16383 = 65536) and distance
/// symbol 31 (the maximum 16-bit distance code). Used as the base for
/// distance-boundary corruption cases below.
fn fixedBlockMatchWire(max_distance: u16) ![]u8 {
    var writer: bitstream.BitWriter = .{};
    errdefer writer.deinit(std.testing.allocator);
    // BFINAL=1, BTYPE=01 (fixed Huffman).
    try writer.writeBits(std.testing.allocator, 0b011, 3);
    try huffman.fixed_literal_encoder.writeSymbol(&writer, std.testing.allocator, 257);
    try writer.writeBits(std.testing.allocator, max_distance, 14);
    try huffman.fixed_distance_encoder.writeSymbol(&writer, std.testing.allocator, 31);
    try huffman.fixed_literal_encoder.writeSymbol(&writer, std.testing.allocator, 256);
    return writer.toOwnedSlice(std.testing.allocator);
}

test "Deflate64 decoder rejects a match beyond the 64 KiB distance window" {
    // Distance symbol 31 decodes to 32769 + the 14-bit extra. The maximum
    // legal value is 65536 (extra = 32767); one more crosses the window.
    const wire = try fixedBlockMatchWire(32768);
    defer std.testing.allocator.free(wire);
    try std.testing.expectError(error.InvalidMatch, decodeAlloc(std.testing.allocator, wire));
}

test "Deflate64 decoder rejects a match with no history (distance on first byte)" {
    // A length-3 match referencing distance one cannot run before any literal
    // byte exists. Length symbol 257 needs no extra bits; distance symbol 0
    // encodes distance 1 directly.
    var writer: bitstream.BitWriter = .{};
    defer writer.deinit(std.testing.allocator);
    try writer.writeBits(std.testing.allocator, 0b011, 3);
    try huffman.fixed_literal_encoder.writeSymbol(&writer, std.testing.allocator, 257);
    try huffman.fixed_distance_encoder.writeSymbol(&writer, std.testing.allocator, 0);
    try huffman.fixed_literal_encoder.writeSymbol(&writer, std.testing.allocator, 256);
    const wire = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(wire);
    try std.testing.expectError(error.InvalidMatch, decodeAlloc(std.testing.allocator, wire));
}

test "Deflate64 decoder rejects a dynamic block with no end-of-block code" {
    // A dynamic literal alphabet must assign a width to symbol 256 or the
    // table cannot encode an end-of-block marker. Build the smallest such
    // header: 257 literal codes, one distance code, four code-length codes,
    // then expand every literal width to zero with repeat symbol 18.
    var writer: bitstream.BitWriter = .{};
    defer writer.deinit(std.testing.allocator);
    // BFINAL=1, BTYPE=10 (dynamic Huffman).
    try writer.writeBits(std.testing.allocator, 0b101, 3);
    try writer.writeBits(std.testing.allocator, 0, 5); // HLIT -> 257 literals
    try writer.writeBits(std.testing.allocator, 0, 5); // HDIST -> 1 distance
    try writer.writeBits(std.testing.allocator, 0, 4); // HCLEN -> 4 CL codes
    // CL order 16,17,18,0: only symbol 18 gets a 1-bit code.
    try writer.writeBits(std.testing.allocator, 0, 3); // 16
    try writer.writeBits(std.testing.allocator, 0, 3); // 17
    try writer.writeBits(std.testing.allocator, 1, 3); // 18
    try writer.writeBits(std.testing.allocator, 0, 3); // 0
    // Symbol 18 carries 7-bit counts of 11..138 zeros.
    var remaining: usize = 257;
    while (remaining > 0) {
        const run = @min(remaining, 138);
        try writer.writeBits(std.testing.allocator, 0, 1); // the single 1-bit code
        try writer.writeBits(std.testing.allocator, @as(u32, @intCast(run - 11)), 7);
        remaining -= run;
    }
    // The single distance code also expands to zero.
    try writer.writeBits(std.testing.allocator, 0, 1);
    try writer.writeBits(std.testing.allocator, 0, 7); // run of 11 zeros, one used
    const wire = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(wire);
    try std.testing.expectError(error.InvalidDynamicBlockHeader, decodeAlloc(std.testing.allocator, wire));
}

test "Deflate64 decoder rejects a truncated fixed block" {
    var writer: bitstream.BitWriter = .{};
    defer writer.deinit(std.testing.allocator);
    try writer.writeBits(std.testing.allocator, 0b011, 3);
    try huffman.fixed_literal_encoder.writeSymbol(&writer, std.testing.allocator, 'A');
    const wire = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(wire);
    // Drop every payload byte except the block header; the literal and the
    // end-of-block marker are missing.
    for (0..wire.len) |cut| {
        try std.testing.expectError(error.TruncatedFrame, decodeAlloc(std.testing.allocator, wire[0..cut]));
    }
}
