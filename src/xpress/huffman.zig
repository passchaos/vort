const std = @import("std");
const core = @import("../core.zig");
const huffman = @import("../huffman.zig");

pub const Error = core.Error || huffman.Error || std.mem.Allocator.Error ||
    error{InvalidXpress};

pub const EncodeOptions = struct {};

pub const Summary = struct {
    encoded_size: usize,
    decoded_size: usize,
    literals: usize,
    matches: usize,
    matched_bytes: usize,
};

pub const max_block_size: usize = 65_536;
const symbol_count: usize = 512;
const table_size: usize = symbol_count / 2;
const eof_symbol: usize = 256;
const min_match: usize = 3;
const max_match: usize = 65_538;
const max_offset: usize = 65_535;
const hash_table_len: usize = 8192;
const max_chain: usize = 256;
const no_position = std.math.maxInt(usize);

const HuffmanTable = huffman.HuffmanTable(symbol_count);

pub fn encodedBound(input_len: usize) Error!usize {
    if (input_len > max_block_size) return error.InvalidBlockPlan;
    const symbols = std.math.add(usize, input_len, 1) catch return error.IntegerOverflow;
    const bits = std.math.mul(usize, symbols, 15) catch return error.IntegerOverflow;
    const coding_units = (std.math.add(usize, bits, 15) catch
        return error.IntegerOverflow) / 16 + 1;
    const payload_bound = std.math.mul(usize, coding_units, 2) catch
        return error.IntegerOverflow;
    return std.math.add(usize, table_size, payload_bound) catch
        return error.IntegerOverflow;
}

pub fn summarize(input: []const u8, expected_size: usize) Error!Summary {
    return decodeBlock(input, null, expected_size);
}

pub fn decodeInto(input: []const u8, output: []u8) Error!usize {
    _ = try decodeBlock(input, output, output.len);
    return output.len;
}

pub fn decodeAllocExactSize(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_size: usize,
) Error![]u8 {
    if (expected_size > max_block_size) return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, expected_size);
    errdefer allocator.free(output);
    _ = try decodeInto(input, output);
    return output;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
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
) Error!usize {
    _ = options;
    if (input.len > max_block_size) return error.InvalidBlockPlan;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try encodeBlock(allocator, &encoded, input);
    try output.ensureUnusedCapacity(allocator, encoded.items.len);
    output.appendSliceAssumeCapacity(encoded.items);
    return encoded.items.len;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: EncodeOptions,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn decodeBlock(
    input: []const u8,
    output: ?[]u8,
    expected_size: usize,
) Error!Summary {
    if (expected_size > max_block_size) return error.OutputLimitExceeded;
    if (input.len < table_size + 4) return error.TruncatedFrame;
    var lengths: [symbol_count]u4 = undefined;
    var counts: [16]u16 = @splat(0);
    for (input[0..table_size], 0..) |byte, index| {
        lengths[index * 2] = @truncate(byte & 0x0f);
        lengths[index * 2 + 1] = @truncate(byte >> 4);
        if (byte & 0x0f != 0) counts[byte & 0x0f] += 1;
        if (byte >> 4 != 0) counts[byte >> 4] += 1;
    }
    try validateCompleteTree(&counts);
    const table = try HuffmanTable.init(&lengths);
    var reader = BitReader.init(input[table_size..]);
    var summary = Summary{
        .encoded_size = input.len,
        .decoded_size = 0,
        .literals = 0,
        .matches = 0,
        .matched_bytes = 0,
    };
    while (summary.decoded_size < expected_size) {
        const symbol = try table.decodeValue(&reader);
        if (symbol < 256) {
            if (output) |bytes| bytes[summary.decoded_size] = @intCast(symbol);
            summary.decoded_size += 1;
            summary.literals += 1;
            continue;
        }

        var length: usize = symbol & 0x0f;
        const offset_bits: u4 = @intCast((symbol >> 4) & 0x0f);
        try reader.ensureBits(16);
        const distance = (@as(usize, 1) << offset_bits) |
            @as(usize, try reader.popBits(offset_bits));
        if (length == 15) {
            const byte_length = try reader.readByte();
            length += byte_length;
            if (length == 15 + 255)
                length = try reader.readU16();
        }
        length += min_match;
        if (distance > summary.decoded_size) return error.InvalidMatch;
        if (length > expected_size - summary.decoded_size) return error.InvalidXpress;
        const match_start = summary.decoded_size;
        summary.decoded_size += length;
        if (output) |bytes| {
            var position = match_start;
            while (position < summary.decoded_size) : (position += 1)
                bytes[position] = bytes[position - distance];
        }
        summary.matches += 1;
        summary.matched_bytes = std.math.add(usize, summary.matched_bytes, length) catch
            return error.IntegerOverflow;
    }

    const end_symbol = try table.decodeValue(&reader);
    if (end_symbol != eof_symbol) return error.InvalidXpress;
    if (!reader.remainingIsZero()) return error.TrailingData;
    return summary;
}

fn validateCompleteTree(counts: *const [16]u16) Error!void {
    var available: i32 = 1;
    var active: usize = 0;
    for (1..16) |bits| {
        available = (available << 1) - counts[bits];
        if (available < 0) return error.InvalidHuffmanCode;
        active += counts[bits];
    }
    if (active == 0 or available != 0) return error.InvalidHuffmanCode;
}

const BitReader = struct {
    input: []const u8,
    next: usize = 0,
    bit_buffer: u32 = 0,
    bits_left: u6 = 0,

    fn init(input: []const u8) BitReader {
        return .{ .input = input };
    }

    fn ensureBits(self: *BitReader, count: u6) core.Error!void {
        if (count > 16) return error.CorruptFrame;
        if (self.bits_left >= count) return;
        if (self.input.len -| self.next < 2) return error.TruncatedFrame;
        const word: u32 = std.mem.readInt(u16, self.input[self.next..][0..2], .little);
        self.bit_buffer |= word << @intCast(16 - self.bits_left);
        self.next += 2;
        self.bits_left += 16;
    }

    pub fn readBits(self: *BitReader, comptime T: type, count: u4) huffman.Error!T {
        return @intCast(try self.popBits(count));
    }

    fn popBits(self: *BitReader, count: u4) core.Error!u16 {
        if (count == 0) return 0;
        try self.ensureBits(count);
        const shift: u5 = @intCast(@as(u6, 32) - count);
        const value: u16 = @truncate(self.bit_buffer >> shift);
        self.bit_buffer <<= count;
        self.bits_left -= count;
        return value;
    }

    fn readByte(self: *BitReader) Error!u8 {
        if (self.next == self.input.len) return error.TruncatedFrame;
        const value = self.input[self.next];
        self.next += 1;
        return value;
    }

    fn readU16(self: *BitReader) Error!u16 {
        if (self.input.len -| self.next < 2) return error.TruncatedFrame;
        const value = std.mem.readInt(u16, self.input[self.next..][0..2], .little);
        self.next += 2;
        return value;
    }

    fn remainingIsZero(self: BitReader) bool {
        if (self.bit_buffer != 0) return false;
        for (self.input[self.next..]) |byte| if (byte != 0) return false;
        return true;
    }
};

const Token = union(enum) {
    literal: u8,
    match: struct { distance: u16, length: u32 },
};

fn encodeBlock(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!void {
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(allocator);
    var frequencies: [symbol_count]u32 = @splat(0);
    try planTokens(allocator, &tokens, &frequencies, input);
    frequencies[eof_symbol] += 1;
    var active: usize = 0;
    for (frequencies) |frequency| {
        if (frequency != 0) active += 1;
    }
    if (active == 1) frequencies[0] = 1;

    const lengths = huffman.treeCodeLengths(symbol_count, &frequencies, 15);
    const encoder = try HuffmanTable.Encoder.init(&lengths);
    for (0..table_size) |index|
        try output.append(
            allocator,
            @as(u8, lengths[index * 2]) | (@as(u8, lengths[index * 2 + 1]) << 4),
        );

    var bits = try BitWriter.init(allocator);
    defer bits.deinit(allocator);
    for (tokens.items) |token| switch (token) {
        .literal => |literal| try writeSymbol(&bits, allocator, encoder, literal),
        .match => |match| {
            const distance: u32 = match.distance;
            const offset_bits: u4 = @intCast(std.math.log2_int(u32, distance));
            const adjusted_length: u32 = @intCast(match.length - min_match);
            const length_header: u32 = @min(adjusted_length, 15);
            const symbol = 256 + (@as(usize, offset_bits) << 4) + length_header;
            try writeSymbol(&bits, allocator, encoder, symbol);
            if (adjusted_length >= 15) {
                const first: u8 = @intCast(@min(adjusted_length - 15, 255));
                try bits.writeByte(allocator, first);
                if (first == 255) try bits.writeU16(allocator, @intCast(adjusted_length));
            }
            try bits.writeBits(
                allocator,
                distance - (@as(u32, 1) << offset_bits),
                offset_bits,
            );
        },
    };
    try writeSymbol(&bits, allocator, encoder, eof_symbol);
    const payload = try bits.finish();
    try output.appendSlice(allocator, payload);
}

fn writeSymbol(
    writer: *BitWriter,
    allocator: std.mem.Allocator,
    encoder: HuffmanTable.Encoder,
    symbol: usize,
) Error!void {
    const count = encoder.bits[symbol];
    if (count == 0) return error.InvalidHuffmanCode;
    const shift: u4 = @intCast(@as(u5, 16) - count);
    const canonical = @bitReverse(encoder.codes[symbol]) >> shift;
    try writer.writeBits(allocator, canonical, count);
}

const BitWriter = struct {
    bytes: std.ArrayList(u8) = .empty,
    next_bits: usize = 0,
    next_bits2: usize = 2,
    bit_buffer: u32 = 0,
    bit_count: u6 = 0,

    fn init(allocator: std.mem.Allocator) Error!BitWriter {
        var self = BitWriter{};
        try self.bytes.appendNTimes(allocator, 0, 4);
        return self;
    }

    fn deinit(self: *BitWriter, allocator: std.mem.Allocator) void {
        self.bytes.deinit(allocator);
        self.* = undefined;
    }

    fn writeBits(
        self: *BitWriter,
        allocator: std.mem.Allocator,
        value: u32,
        count: u4,
    ) Error!void {
        if (count == 0) return;
        if (value >= @as(u32, 1) << count) return error.InvalidXpress;
        self.bit_buffer = (self.bit_buffer << count) | value;
        self.bit_count += count;
        if (self.bit_count > 16) {
            self.bit_count -= 16;
            const remaining: u5 = @intCast(self.bit_count);
            const word: u16 = @truncate(self.bit_buffer >> remaining);
            std.mem.writeInt(u16, self.bytes.items[self.next_bits..][0..2], word, .little);
            self.next_bits = self.next_bits2;
            self.next_bits2 = self.bytes.items.len;
            try self.bytes.appendNTimes(allocator, 0, 2);
            self.bit_buffer &= if (self.bit_count == 0)
                0
            else
                (@as(u32, 1) << @intCast(self.bit_count)) - 1;
        }
    }

    fn writeByte(self: *BitWriter, allocator: std.mem.Allocator, value: u8) Error!void {
        try self.bytes.append(allocator, value);
    }

    fn writeU16(self: *BitWriter, allocator: std.mem.Allocator, value: u16) Error!void {
        var bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &bytes, value, .little);
        try self.bytes.appendSlice(allocator, &bytes);
    }

    fn finish(self: *BitWriter) Error![]const u8 {
        if (self.bit_count == 0) return error.InvalidXpress;
        const word: u16 = @truncate(self.bit_buffer << @intCast(16 - self.bit_count));
        std.mem.writeInt(u16, self.bytes.items[self.next_bits..][0..2], word, .little);
        std.mem.writeInt(u16, self.bytes.items[self.next_bits2..][0..2], 0, .little);
        return self.bytes.items;
    }
};

const Match = struct { distance: usize = 0, length: usize = 0 };

const MatchIndex = struct {
    allocator: std.mem.Allocator,
    heads: []usize,
    previous: []usize,

    fn init(allocator: std.mem.Allocator, input_len: usize) Error!MatchIndex {
        const heads = try allocator.alloc(usize, hash_table_len);
        errdefer allocator.free(heads);
        const previous = try allocator.alloc(usize, @min(input_len, max_offset));
        @memset(heads, no_position);
        @memset(previous, no_position);
        return .{ .allocator = allocator, .heads = heads, .previous = previous };
    }

    fn deinit(self: *MatchIndex) void {
        self.allocator.free(self.previous);
        self.allocator.free(self.heads);
        self.* = undefined;
    }

    fn insert(self: *MatchIndex, input: []const u8, position: usize) void {
        if (input.len - position < min_match or self.previous.len == 0) return;
        const hash_value = hash(input[position..][0..3]);
        self.previous[position % self.previous.len] = self.heads[hash_value];
        self.heads[hash_value] = position;
    }

    fn find(self: MatchIndex, input: []const u8, position: usize) Match {
        if (input.len - position < min_match or position == 0 or self.previous.len == 0)
            return .{};
        const max_distance = @min(position, max_offset);
        const max_length_value = @min(input.len - position, max_match);
        var best = Match{};
        var candidate = self.heads[hash(input[position..][0..3])];
        var searched: usize = 0;
        while (candidate != no_position and searched < max_chain) : (searched += 1) {
            const distance = position - candidate;
            if (distance > max_distance) break;
            if (std.mem.eql(u8, input[candidate..][0..3], input[position..][0..3])) {
                var length: usize = min_match;
                while (length < max_length_value and
                    input[candidate + length] == input[position + length])
                    length += 1;
                if (length > best.length) {
                    best = .{ .distance = distance, .length = length };
                    if (length == max_length_value) break;
                }
            }
            candidate = self.previous[candidate % self.previous.len];
        }
        return best;
    }
};

fn planTokens(
    allocator: std.mem.Allocator,
    tokens: *std.ArrayList(Token),
    frequencies: *[symbol_count]u32,
    input: []const u8,
) Error!void {
    var index = try MatchIndex.init(allocator, input.len);
    defer index.deinit();
    var position: usize = 0;
    while (position < input.len) {
        const match = index.find(input, position);
        const consumed = if (match.length >= min_match) blk: {
            const offset_bits = std.math.log2_int(usize, match.distance);
            const length_header = @min(match.length - min_match, 15);
            const symbol = 256 + (@as(usize, offset_bits) << 4) + length_header;
            frequencies[symbol] += 1;
            try tokens.append(allocator, .{ .match = .{
                .distance = @intCast(match.distance),
                .length = @intCast(match.length),
            } });
            break :blk match.length;
        } else blk: {
            frequencies[input[position]] += 1;
            try tokens.append(allocator, .{ .literal = input[position] });
            break :blk 1;
        };
        const end = position + consumed;
        while (position < end) : (position += 1) index.insert(input, position);
    }
}

fn hash(bytes: *const [3]u8) usize {
    return (@as(usize, bytes[0]) *% 0x1e35_a7bd +%
        @as(usize, bytes[1]) *% 0x9e37_79b1 +% bytes[2]) & (hash_table_len - 1);
}

fn officialFixtureAlloc(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    const bytes = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, hex);
    return bytes;
}

test "XPRESS Huffman decodes the MS-XCA literal and match examples" {
    const allocator = std.testing.allocator;
    const literal_hex = "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050555555555555555555554544040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d8523ed794115be9195ff9d67cdf8d0400000000";
    const literal_fixture = try officialFixtureAlloc(allocator, literal_hex);
    defer allocator.free(literal_fixture);
    const literal_decoded = try decodeAllocExactSize(allocator, literal_fixture, 26);
    defer allocator.free(literal_decoded);
    try std.testing.expectEqualStrings("abcdefghijklmnopqrstuvwxyz", literal_decoded);

    const match_hex = "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a8dc0000ff2601";
    const match_fixture = try officialFixtureAlloc(allocator, match_hex);
    defer allocator.free(match_fixture);
    const match_decoded = try decodeAllocExactSize(allocator, match_fixture, 300);
    defer allocator.free(match_decoded);
    try std.testing.expectEqualSlices(u8, "abc" ** 100, match_decoded);
}

test "XPRESS Huffman round trips literals matches and boundaries" {
    const allocator = std.testing.allocator;
    var random: [8192]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x5850_4855_4646);
    prng.random().bytes(&random);
    const repeated = "XPRESS Huffman repeated payload 0123456789\n" ** 500;
    const cases = [_][]const u8{ "", "tiny", &random, repeated, "a" ** 18, "b" ** 273, "c" ** 65_536 };
    for (cases) |input| {
        const encoded = try encodeAlloc(allocator, input, .{});
        defer allocator.free(encoded);
        try std.testing.expect(encoded.len <= try encodedBound(input.len));
        const summary = try summarize(encoded, input.len);
        try std.testing.expectEqual(input.len, summary.decoded_size);
        const decoded = try decodeAllocExactSize(allocator, encoded, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }

    const bound = try encodedBound(repeated.len);
    const into = try allocator.alloc(u8, bound);
    defer allocator.free(into);
    const written = try encodeInto(allocator, repeated, into, .{});
    const decoded = try decodeAllocExactSize(allocator, into[0..written], repeated.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, repeated, decoded);
}

test "XPRESS Huffman rejects malformed tables matches and sizes" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.TruncatedFrame, decodeAllocExactSize(allocator, &.{}, 0));
    var empty_table: [table_size + 4]u8 = @splat(0);
    try std.testing.expectError(
        error.InvalidHuffmanCode,
        decodeAllocExactSize(allocator, &empty_table, 0),
    );
    const encoded = try encodeAlloc(allocator, "bounded", .{});
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAllocExactSize(allocator, encoded, max_block_size + 1),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        encodeAlloc(allocator, "x" ** (max_block_size + 1), .{}),
    );
    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    corrupt[corrupt.len - 1] = 1;
    try std.testing.expectError(
        error.TrailingData,
        decodeAllocExactSize(allocator, corrupt, "bounded".len),
    );
}
