const std = @import("std");
const core = @import("../core.zig");
const bit_reader = @import("bit_reader.zig");
const bzip2_crc = @import("crc.zig");

pub const Error = core.Error || error{
    InvalidBzip2Header,
    InvalidBzip2Stream,
    UnsupportedBzip2Feature,
};

const block_magic: u64 = 0x3141_5926_5359;
const end_magic: u64 = 0x1772_4538_5090;
const max_alpha_size: usize = 258;
const max_groups: usize = 6;
const group_size: usize = 50;
const max_code_length: usize = 20;

const Output = union(enum) {
    fixed: struct {
        bytes: []u8,
        written: usize = 0,
    },
    dynamic: struct {
        allocator: std.mem.Allocator,
        bytes: *std.ArrayList(u8),
        limit: usize,
    },
    count: struct {
        written: usize = 0,
        limit: usize,
    },

    fn len(self: Output) usize {
        return switch (self) {
            .fixed => |state| state.written,
            .dynamic => |state| state.bytes.items.len,
            .count => |state| state.written,
        };
    }

    fn appendRepeat(self: *Output, byte: u8, count: usize) !void {
        if (count == 0) return;
        switch (self.*) {
            .fixed => |*state| {
                const end = std.math.add(usize, state.written, count) catch return error.OutputTooSmall;
                if (end > state.bytes.len) return error.OutputTooSmall;
                @memset(state.bytes[state.written..end], byte);
                state.written = end;
            },
            .dynamic => |*state| {
                const end = std.math.add(usize, state.bytes.items.len, count) catch return error.OutputLimitExceeded;
                if (end > state.limit) return error.OutputLimitExceeded;
                try state.bytes.ensureUnusedCapacity(state.allocator, count);
                const start = state.bytes.items.len;
                state.bytes.items.len = end;
                @memset(state.bytes.items[start..end], byte);
            },
            .count => |*state| {
                const end = std.math.add(usize, state.written, count) catch return error.OutputLimitExceeded;
                if (end > state.limit) return error.OutputLimitExceeded;
                state.written = end;
            },
        }
    }
};

const HuffmanTable = struct {
    counts: [max_code_length + 1]u16 = @splat(0),
    first_codes: [max_code_length + 1]u32 = @splat(0),
    first_symbols: [max_code_length + 1]u16 = @splat(0),
    symbols: [max_alpha_size]u16 = @splat(0),
    max_length: u8 = 0,

    fn build(lengths: []const u8) Error!HuffmanTable {
        var table = HuffmanTable{};
        for (lengths) |length| {
            if (length == 0 or length > max_code_length) return error.InvalidHuffmanCode;
            table.counts[length] += 1;
            table.max_length = @max(table.max_length, length);
        }

        var code: u32 = 0;
        var symbol_offset: u16 = 0;
        for (1..max_code_length + 1) |length| {
            code = (code + table.counts[length - 1]) << 1;
            table.first_codes[length] = code;
            table.first_symbols[length] = symbol_offset;
            const end_code = code + table.counts[length];
            if (end_code > (@as(u32, 1) << @intCast(length))) return error.InvalidHuffmanCode;
            symbol_offset += table.counts[length];
        }

        var cursor: usize = 0;
        for (1..max_code_length + 1) |length|
            for (lengths, 0..) |candidate, symbol|
                if (candidate == length) {
                    table.symbols[cursor] = @intCast(symbol);
                    cursor += 1;
                };
        if (cursor != lengths.len) return error.InvalidHuffmanCode;
        return table;
    }

    fn decode(self: *const HuffmanTable, reader: *bit_reader.BitReader) Error!u16 {
        var code: u32 = 0;
        var length: usize = 1;
        while (length <= self.max_length) : (length += 1) {
            code = (code << 1) | try reader.readBit();
            const first = self.first_codes[length];
            const count = self.counts[length];
            if (code >= first and code - first < count) {
                const index = @as(usize, self.first_symbols[length]) + (code - first);
                return self.symbols[index];
            }
        }
        return error.InvalidHuffmanCode;
    }
};

const SelectorState = struct {
    selector_index: usize = 0,
    group_remaining: usize = 0,
    table_index: usize = 0,

    fn next(
        self: *SelectorState,
        reader: *bit_reader.BitReader,
        selectors: []const u8,
        tables: []const HuffmanTable,
    ) Error!u16 {
        if (self.group_remaining == 0) {
            if (self.selector_index >= selectors.len) return error.InvalidBzip2Stream;
            self.table_index = selectors[self.selector_index];
            self.selector_index += 1;
            self.group_remaining = group_size;
        }
        self.group_remaining -= 1;
        return tables[self.table_index].decode(reader);
    }
};

pub fn decodeInto(allocator: std.mem.Allocator, input: []const u8, output: []u8) !usize {
    var sink = Output{ .fixed = .{ .bytes = output } };
    const consumed = try decodeOne(allocator, input, &sink);
    if (consumed != input.len) return error.TrailingData;
    return sink.len();
}

pub fn decodeAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var sink = Output{ .dynamic = .{ .allocator = allocator, .bytes = &output, .limit = max_output_len } };
    const consumed = try decodeOne(allocator, input, &sink);
    if (consumed != input.len) return error.TrailingData;
    return output.toOwnedSlice(allocator);
}

pub fn decodedSize(allocator: std.mem.Allocator, input: []const u8) !usize {
    return decodedSizeLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodedSizeLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) !usize {
    var sink = Output{ .count = .{ .limit = max_output_len } };
    const consumed = try decodeOne(allocator, input, &sink);
    if (consumed != input.len) return error.TrailingData;
    return sink.len();
}

pub fn decodeConcatenatedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeConcatenatedAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeConcatenatedInto(allocator: std.mem.Allocator, input: []const u8, output: []u8) !usize {
    var sink = Output{ .fixed = .{ .bytes = output } };
    try decodeConcatenated(allocator, input, &sink);
    return sink.len();
}

pub fn decodeConcatenatedAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var sink = Output{ .dynamic = .{ .allocator = allocator, .bytes = &output, .limit = max_output_len } };
    try decodeConcatenated(allocator, input, &sink);
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
    var sink = Output{ .count = .{ .limit = max_output_len } };
    try decodeConcatenated(allocator, input, &sink);
    return sink.len();
}

pub const IncrementalPart = union(enum) {
    block: struct {
        next_bit_offset: usize,
        crc32: u32,
    },
    end: struct {
        next_bit_offset: usize,
        combined_crc32: u32,
    },
};

/// Decode one block or end marker from a buffered Bzip2 member body. The bit
/// offset and returned offset are relative to `input`; transformed and decoded
/// scratch are caller-owned so retries after split input retain their capacity.
/// Decoded bytes are published in `decoded` only after the block CRC succeeds.
pub fn decodeIncrementalPart(
    allocator: std.mem.Allocator,
    input: []const u8,
    bit_offset: usize,
    block_limit: usize,
    max_decoded_block_len: usize,
    transformed: *std.ArrayList(u8),
    decoded: *std.ArrayList(u8),
) !IncrementalPart {
    const input_bits = std.math.mul(usize, input.len, 8) catch
        return error.IntegerOverflow;
    if (bit_offset > input_bits) return error.TruncatedFrame;
    transformed.clearRetainingCapacity();
    decoded.clearRetainingCapacity();
    errdefer decoded.clearRetainingCapacity();
    try transformed.ensureTotalCapacityPrecise(allocator, block_limit);

    var reader = bit_reader.BitReader.init(input);
    reader.bit_offset = bit_offset;
    const marker = try reader.readMarker();
    switch (marker) {
        block_magic => {
            const stored_crc = try reader.readBits(32);
            if (try reader.readBit() != 0) return error.UnsupportedBzip2Feature;
            const original_pointer = try reader.readBits(24);
            try decodeBlock(&reader, transformed, block_limit);
            var output = Output{ .dynamic = .{
                .allocator = allocator,
                .bytes = decoded,
                .limit = max_decoded_block_len,
            } };
            const actual_crc = try inverseBwtAndWrite(
                allocator,
                transformed.items,
                original_pointer,
                &output,
            );
            if (actual_crc != stored_crc) return error.ChecksumMismatch;
            return .{ .block = .{
                .next_bit_offset = reader.bit_offset,
                .crc32 = actual_crc,
            } };
        },
        end_magic => {
            const combined_crc32 = try reader.readBits(32);
            reader.alignToByte();
            return .{ .end = .{
                .next_bit_offset = reader.bit_offset,
                .combined_crc32 = combined_crc32,
            } };
        },
        else => return error.InvalidBzip2Stream,
    }
}

fn decodeConcatenated(allocator: std.mem.Allocator, input: []const u8, sink: *Output) !void {
    if (input.len == 0) return error.InvalidMagic;
    var offset: usize = 0;
    while (offset < input.len) {
        const consumed = try decodeOne(allocator, input[offset..], sink);
        if (consumed == 0) return error.InvalidBzip2Stream;
        offset += consumed;
    }
}

fn decodeOne(allocator: std.mem.Allocator, input: []const u8, output: *Output) !usize {
    if (input.len < 4) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..3], "BZh")) return error.InvalidMagic;
    if (input[3] < '1' or input[3] > '9') return error.InvalidBzip2Header;
    const block_limit = @as(usize, input[3] - '0') * 100_000;
    var reader = bit_reader.BitReader.init(input[4..]);
    var combined_crc: u32 = 0;
    var block: std.ArrayList(u8) = .empty;
    defer block.deinit(allocator);
    try block.ensureTotalCapacity(allocator, block_limit);

    while (true) {
        const marker = try reader.readMarker();
        switch (marker) {
            block_magic => {
                block.clearRetainingCapacity();
                const stored_crc = try reader.readBits(32);
                if (try reader.readBit() != 0) return error.UnsupportedBzip2Feature;
                const original_pointer = try reader.readBits(24);
                try decodeBlock(&reader, &block, block_limit);
                const actual_crc = try inverseBwtAndWrite(allocator, block.items, original_pointer, output);
                if (actual_crc != stored_crc) return error.ChecksumMismatch;
                combined_crc = std.math.rotl(u32, combined_crc, 1) ^ actual_crc;
            },
            end_magic => {
                if (try reader.readBits(32) != combined_crc) return error.ChecksumMismatch;
                reader.alignToByte();
                return std.math.add(usize, 4, reader.consumedBytes()) catch error.IntegerOverflow;
            },
            else => return error.InvalidBzip2Stream,
        }
    }
}

fn decodeBlock(reader: *bit_reader.BitReader, block: *std.ArrayList(u8), block_limit: usize) !void {
    var group_used: [16]bool = @splat(false);
    for (&group_used) |*used| used.* = try reader.readBit() != 0;

    var sequence: [256]u8 = undefined;
    var sequence_len: usize = 0;
    for (group_used, 0..) |used, group| {
        if (!used) continue;
        for (0..16) |low| {
            if (try reader.readBit() != 0) {
                sequence[sequence_len] = @intCast(group * 16 + low);
                sequence_len += 1;
            }
        }
    }
    const alpha_size = sequence_len + 2;

    const group_count: usize = try reader.readBits(3);
    if (group_count < 2 or group_count > max_groups) return error.InvalidBzip2Stream;
    const selector_count: usize = try reader.readBits(15);
    const max_selectors = 2 + block_limit / group_size;
    if (selector_count == 0 or selector_count > max_selectors) return error.InvalidBzip2Stream;

    var selector_mtf: [2 + 900_000 / group_size]u8 = undefined;
    for (selector_mtf[0..selector_count]) |*selector| {
        var value: usize = 0;
        while (try reader.readBit() != 0) : (value += 1)
            if (value + 1 >= group_count) return error.InvalidBzip2Stream;
        selector.* = @intCast(value);
    }

    var selector_list: [max_groups]u8 = undefined;
    for (0..group_count) |index| selector_list[index] = @intCast(index);
    var selectors: [2 + 900_000 / group_size]u8 = undefined;
    for (selector_mtf[0..selector_count], selectors[0..selector_count]) |mtf_index_u8, *selector| {
        const mtf_index: usize = mtf_index_u8;
        const value = selector_list[mtf_index];
        var index = mtf_index;
        while (index > 0) : (index -= 1) selector_list[index] = selector_list[index - 1];
        selector_list[0] = value;
        selector.* = value;
    }

    var tables: [max_groups]HuffmanTable = undefined;
    for (tables[0..group_count]) |*table| {
        var current: i16 = @intCast(try reader.readBits(5));
        var lengths: [max_alpha_size]u8 = undefined;
        for (lengths[0..alpha_size]) |*length| {
            while (try reader.readBit() != 0) {
                current += if (try reader.readBit() == 0) 1 else -1;
                if (current < 1 or current > max_code_length) return error.InvalidHuffmanCode;
            }
            if (current < 1 or current > max_code_length) return error.InvalidHuffmanCode;
            length.* = @intCast(current);
        }
        table.* = try HuffmanTable.build(lengths[0..alpha_size]);
    }

    var mtf: [256]u8 = undefined;
    for (mtf[0..sequence_len], 0..) |*value, index| value.* = @intCast(index);
    const end_of_block: u16 = @intCast(sequence_len + 1);
    var selector_state = SelectorState{};
    var symbol = try selector_state.next(reader, selectors[0..selector_count], tables[0..group_count]);
    while (symbol != end_of_block) {
        if (symbol == 0 or symbol == 1) {
            if (sequence_len == 0) return error.InvalidBzip2Stream;
            var run: usize = 0;
            var weight: usize = 1;
            while (symbol == 0 or symbol == 1) {
                const multiple: usize = if (symbol == 0) 1 else 2;
                run = std.math.add(usize, run, std.math.mul(usize, multiple, weight) catch return error.InvalidBzip2Stream) catch
                    return error.InvalidBzip2Stream;
                if (run > block_limit) return error.InvalidBzip2Stream;
                weight = std.math.mul(usize, weight, 2) catch return error.InvalidBzip2Stream;
                symbol = try selector_state.next(reader, selectors[0..selector_count], tables[0..group_count]);
            }
            try appendBlockRepeat(block, sequence[mtf[0]], run, block_limit);
            if (symbol == end_of_block) break;
        }

        if (symbol < 2 or symbol - 1 >= sequence_len) return error.InvalidBzip2Stream;
        const mtf_index: usize = symbol - 1;
        const sequence_index = mtf[mtf_index];
        var index = mtf_index;
        while (index > 0) : (index -= 1) mtf[index] = mtf[index - 1];
        mtf[0] = sequence_index;
        try appendBlockRepeat(block, sequence[sequence_index], 1, block_limit);
        symbol = try selector_state.next(reader, selectors[0..selector_count], tables[0..group_count]);
    }
}

fn appendBlockRepeat(block: *std.ArrayList(u8), byte: u8, count: usize, block_limit: usize) !void {
    const end = std.math.add(usize, block.items.len, count) catch return error.InvalidBzip2Stream;
    if (end > block_limit) return error.InvalidBzip2Stream;
    const start = block.items.len;
    block.items.len = end;
    @memset(block.items[start..end], byte);
}

fn inverseBwtAndWrite(
    allocator: std.mem.Allocator,
    block: []const u8,
    original_pointer_u32: u32,
    output: *Output,
) !u32 {
    if (block.len == 0 or original_pointer_u32 >= block.len) return error.InvalidBzip2Stream;
    const original_pointer: usize = original_pointer_u32;
    const next = try allocator.alloc(u32, block.len);
    defer allocator.free(next);

    var cumulative: [257]usize = @splat(0);
    for (block) |byte| cumulative[@as(usize, byte) + 1] += 1;
    for (1..cumulative.len) |index| cumulative[index] += cumulative[index - 1];
    var positions = cumulative;
    for (block, 0..) |byte, index| {
        const position = positions[byte];
        next[position] = @intCast(index);
        positions[byte] += 1;
    }

    var crc = bzip2_crc.Crc32{};
    var position: usize = next[original_pointer];
    var previous: u8 = 0;
    var run_length: u8 = 0;
    for (0..block.len) |_| {
        const byte = block[position];
        position = next[position];
        if (run_length == 4) {
            try output.appendRepeat(previous, byte);
            crc.updateRepeat(previous, byte);
            run_length = 0;
            continue;
        }

        try output.appendRepeat(byte, 1);
        crc.updateByte(byte);
        if (run_length != 0 and byte == previous) {
            run_length += 1;
        } else {
            previous = byte;
            run_length = 1;
        }
    }
    if (run_length == 4) return error.InvalidBzip2Stream;
    return crc.digest();
}

test "Bzip2 Huffman table decodes canonical MSB-first codes" {
    const table = try HuffmanTable.build(&.{ 2, 2, 2, 2 });
    var reader = bit_reader.BitReader.init(&.{0b0001_1011});
    try std.testing.expectEqual(@as(u16, 0), try table.decode(&reader));
    try std.testing.expectEqual(@as(u16, 1), try table.decode(&reader));
    try std.testing.expectEqual(@as(u16, 2), try table.decode(&reader));
    try std.testing.expectEqual(@as(u16, 3), try table.decode(&reader));
}

test "Bzip2 decoder matches Python single-block and empty streams" {
    const payload = "hello hello hello\n" ** 20;
    const encoded_hex = "425a6831314159265359e2c777e0000054d100001040000244a00030c002950c9a55855e13c4c2ad157c5dc914e142438b1ddf80";
    var encoded: [encoded_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&encoded, encoded_hex);
    const decoded = try decodeAlloc(std.testing.allocator, &encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expectEqual(payload.len, try decodedSize(std.testing.allocator, &encoded));

    const empty_hex = "425a683117724538509000000000";
    var empty: [empty_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&empty, empty_hex);
    const decoded_empty = try decodeAlloc(std.testing.allocator, &empty);
    defer std.testing.allocator.free(decoded_empty);
    try std.testing.expectEqual(@as(usize, 0), decoded_empty.len);

    var output: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try decodeInto(std.testing.allocator, &encoded, &output));
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectError(error.OutputTooSmall, decodeInto(std.testing.allocator, &encoded, output[0 .. output.len - 1]));
    try std.testing.expectError(error.OutputLimitExceeded, decodedSizeLimited(std.testing.allocator, &encoded, payload.len - 1));

    var concatenated: [encoded.len * 2]u8 = undefined;
    @memcpy(concatenated[0..encoded.len], &encoded);
    @memcpy(concatenated[encoded.len..], &encoded);
    try std.testing.expectError(error.TrailingData, decodeAlloc(std.testing.allocator, &concatenated));
    const decoded_concatenated = try decodeConcatenatedAlloc(std.testing.allocator, &concatenated);
    defer std.testing.allocator.free(decoded_concatenated);
    try std.testing.expectEqual(payload.len * 2, decoded_concatenated.len);
    try std.testing.expectEqualSlices(u8, payload, decoded_concatenated[0..payload.len]);
    try std.testing.expectEqualSlices(u8, payload, decoded_concatenated[payload.len..]);
    try std.testing.expectEqual(
        payload.len * 2,
        try decodedSizeConcatenated(std.testing.allocator, &concatenated),
    );
    var concatenated_output: [payload.len * 2]u8 = undefined;
    try std.testing.expectEqual(
        concatenated_output.len,
        try decodeConcatenatedInto(std.testing.allocator, &concatenated, &concatenated_output),
    );
    try std.testing.expectEqualSlices(u8, payload, concatenated_output[0..payload.len]);
    try std.testing.expectEqualSlices(u8, payload, concatenated_output[payload.len..]);
}

test "Bzip2 decoder expands first-stage run-length encoding" {
    const encoded_hex = "425a68313141592653594126ba950000018401a00000800008200020aa6d4198ba83c5dc914e14241049aea540";
    var encoded: [encoded_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&encoded, encoded_hex);
    const decoded = try decodeAlloc(std.testing.allocator, &encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 1000), decoded.len);
    for (decoded) |byte| try std.testing.expectEqual(@as(u8, 'A'), byte);
}

test "Bzip2 decoder rejects malformed headers truncation randomization and CRC" {
    const encoded_hex = "425a6831314159265359e2c777e0000054d100001040000244a00030c002950c9a55855e13c4c2ad157c5dc914e142438b1ddf80";
    var encoded: [encoded_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&encoded, encoded_hex);

    try std.testing.expectError(error.InvalidMagic, decodeAlloc(std.testing.allocator, "not bzip2"));
    var bad_level = encoded;
    bad_level[3] = '0';
    try std.testing.expectError(error.InvalidBzip2Header, decodeAlloc(std.testing.allocator, &bad_level));
    try std.testing.expectError(error.TruncatedFrame, decodeAlloc(std.testing.allocator, encoded[0 .. encoded.len - 1]));

    var randomized = encoded;
    randomized[14] |= 0x80;
    try std.testing.expectError(error.UnsupportedBzip2Feature, decodeAlloc(std.testing.allocator, &randomized));

    var bad_crc = encoded;
    bad_crc[10] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeAlloc(std.testing.allocator, &bad_crc));

    for (0..encoded.len) |truncated_len|
        try std.testing.expectError(
            error.TruncatedFrame,
            decodeAlloc(std.testing.allocator, encoded[0..truncated_len]),
        );
}
