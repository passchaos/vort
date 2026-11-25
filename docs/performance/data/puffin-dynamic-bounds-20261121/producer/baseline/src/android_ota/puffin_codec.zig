const std = @import("std");
const deflate_mod = @import("../deflate.zig");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

const permutations = [_]u8{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };
const length_bases = [_]u16{ 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 };
const length_extra = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 };
const distance_bases = [_]u16{ 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 };
const distance_extra = [_]u8{ 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 };
const max_puff_metadata = 1 + 3 + 286 + 30 + 19;
const max_literal_run = (1 << 16) + 127;

const Huffman = struct {
    lengths: [288]u8 = @splat(0),
    codes: [288]u16 = @splat(0),
    symbol_count: usize = 0,
    max_bits: u8 = 0,

    fn init(lengths: []const u8) Error!Huffman {
        if (lengths.len > 288) return error.InvalidPuffinStream;
        var result = Huffman{ .symbol_count = lengths.len };
        @memcpy(result.lengths[0..lengths.len], lengths);
        var counts: [16]u16 = @splat(0);
        for (lengths) |length| {
            if (length > 15) return error.InvalidPuffinStream;
            counts[length] += 1;
            result.max_bits = @max(result.max_bits, length);
        }
        if (result.max_bits == 0) return error.InvalidPuffinStream;
        var next: [16]u16 = @splat(0);
        var code: u32 = 0;
        counts[0] = 0;
        for (1..16) |bits| {
            code = (code + counts[bits - 1]) << 1;
            if (code + counts[bits] > @as(u32, 1) << @intCast(bits))
                return error.InvalidPuffinStream;
            next[bits] = @intCast(code);
        }
        for (lengths, 0..) |length, symbol| {
            if (length == 0) continue;
            result.codes[symbol] = reverseBits(next[length], length);
            next[length] += 1;
        }
        return result;
    }

    fn decode(self: Huffman, reader: *BitReader) Error!u16 {
        var code: u16 = 0;
        var length: u8 = 1;
        while (length <= self.max_bits) : (length += 1) {
            code |= @as(u16, @intCast(try reader.readBits(1))) << @intCast(length - 1);
            for (self.lengths[0..self.symbol_count], 0..) |candidate, symbol|
                if (candidate == length and self.codes[symbol] == code)
                    return @intCast(symbol);
        }
        return error.InvalidPuffinStream;
    }

    fn encode(self: Huffman, writer: *BitWriter, symbol: usize) Error!void {
        if (symbol >= self.symbol_count or self.lengths[symbol] == 0)
            return error.InvalidPuffinStream;
        try writer.writeBits(@intCast(self.lengths[symbol]), self.codes[symbol]);
    }
};

const Tables = struct {
    literal_length: Huffman,
    distance: Huffman,
};

const BitReader = struct {
    bytes: []const u8,
    bit_pos: u64,
    bit_end: u64,

    fn init(bytes: []const u8, bit_start: u64, bit_length: u64) Error!BitReader {
        const bit_end = std.math.add(u64, bit_start, bit_length) catch
            return error.IntegerOverflow;
        if (bit_end > @as(u64, bytes.len) * 8) return error.TruncatedFrame;
        return .{ .bytes = bytes, .bit_pos = bit_start, .bit_end = bit_end };
    }

    fn readBits(self: *BitReader, count: u6) Error!u32 {
        if (count > 32 or count > self.bit_end -| self.bit_pos)
            return error.TruncatedFrame;
        var value: u32 = 0;
        for (0..count) |index| {
            const byte = self.bytes[@intCast(self.bit_pos / 8)];
            value |= @as(u32, (byte >> @intCast(self.bit_pos % 8)) & 1) << @intCast(index);
            self.bit_pos += 1;
        }
        return value;
    }

    fn alignByte(self: *BitReader) Error!u8 {
        const count: u6 = @intCast((8 - self.bit_pos % 8) % 8);
        return @intCast(try self.readBits(count));
    }
};

const BitWriter = struct {
    bytes: []u8,
    bit_pos: u64 = 0,

    fn init(bytes: []u8) BitWriter {
        @memset(bytes, 0);
        return .{ .bytes = bytes };
    }

    fn writeBits(self: *BitWriter, count: u6, value: anytype) Error!void {
        if (count > 32 or count > @as(u64, self.bytes.len) * 8 -| self.bit_pos)
            return error.OutputTooSmall;
        const bits: u32 = @intCast(value);
        for (0..count) |index| {
            if ((bits >> @intCast(index)) & 1 != 0)
                self.bytes[@intCast(self.bit_pos / 8)] |=
                    @as(u8, 1) << @intCast(self.bit_pos % 8);
            self.bit_pos += 1;
        }
    }

    fn alignByte(self: *BitWriter, value: u8) Error!void {
        const count: u6 = @intCast((8 - self.bit_pos % 8) % 8);
        try self.writeBits(count, value);
    }
};

const PuffBuilder = struct {
    allocator: std.mem.Allocator,
    output: std.ArrayList(u8) = .empty,
    literals: std.ArrayList(u8) = .empty,

    fn deinit(self: *PuffBuilder) void {
        self.output.deinit(self.allocator);
        self.literals.deinit(self.allocator);
    }

    fn addMetadata(self: *PuffBuilder, metadata: []const u8) Error!void {
        try self.flushLiterals();
        if (metadata.len == 0 or metadata.len > max_puff_metadata)
            return error.InvalidPuffinStream;
        var length: [2]u8 = undefined;
        std.mem.writeInt(u16, &length, @intCast(metadata.len - 1), .big);
        try self.output.appendSlice(self.allocator, &length);
        try self.output.appendSlice(self.allocator, metadata);
    }

    fn addLiteral(self: *PuffBuilder, value: u8) Error!void {
        try self.literals.append(self.allocator, value);
        if (self.literals.items.len == max_literal_run)
            try self.flushLiterals();
    }

    fn addLiteralSlice(self: *PuffBuilder, values: []const u8) Error!void {
        for (values) |value| try self.addLiteral(value);
    }

    fn addLengthDistance(
        self: *PuffBuilder,
        length: u16,
        distance: u16,
    ) Error!void {
        try self.flushLiterals();
        if (length < 3 or length > 258 or distance == 0 or distance > 32768)
            return error.InvalidPuffinStream;
        if (length < 130) {
            try self.output.append(self.allocator, 0x80 | @as(u8, @intCast(length - 3)));
        } else {
            try self.output.append(self.allocator, 0xff);
            try self.output.append(self.allocator, @intCast(length - 130));
        }
        var distance_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &distance_bytes, distance - 1, .big);
        try self.output.appendSlice(self.allocator, &distance_bytes);
    }

    fn addEnd(self: *PuffBuilder) Error!void {
        try self.flushLiterals();
        try self.output.appendSlice(self.allocator, &.{ 0xff, 0x81 });
    }

    fn flushLiterals(self: *PuffBuilder) Error!void {
        if (self.literals.items.len == 0) return;
        const length = self.literals.items.len;
        if (length <= 127) {
            try self.output.append(self.allocator, @intCast(length - 1));
        } else {
            try self.output.append(self.allocator, 0x7f);
            var bytes: [2]u8 = undefined;
            std.mem.writeInt(u16, &bytes, @intCast(length - 128), .big);
            try self.output.appendSlice(self.allocator, &bytes);
        }
        try self.output.appendSlice(self.allocator, self.literals.items);
        self.literals.clearRetainingCapacity();
    }
};

pub fn puffDeflateAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    bit_offset: u64,
    bit_length: u64,
    max_output_len: usize,
) Error![]u8 {
    const result = try puffDeflatePaddedAlloc(
        allocator,
        input,
        bit_offset,
        bit_length,
        max_output_len,
    );
    if (result.consumed_bits != bit_length) {
        allocator.free(result.bytes);
        return error.TrailingData;
    }
    return result.bytes;
}

pub const PuffResult = struct {
    bytes: []u8,
    consumed_bits: u64,
};

pub fn puffDeflatePaddedAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    bit_offset: u64,
    bit_length: u64,
    max_output_len: usize,
) Error!PuffResult {
    var reader = try BitReader.init(input, bit_offset, bit_length);
    var builder = PuffBuilder{ .allocator = allocator };
    defer builder.deinit();
    var final_seen = false;
    while (!final_seen) {
        const final = try reader.readBits(1) != 0;
        const kind = try reader.readBits(2);
        var metadata: std.ArrayList(u8) = .empty;
        defer metadata.deinit(allocator);
        try metadata.append(allocator, (@as(u8, @intFromBool(final)) << 7) |
            (@as(u8, @intCast(kind)) << 5));
        switch (kind) {
            0 => {
                metadata.items[0] |= try reader.alignByte();
                const length: u16 = @intCast(try reader.readBits(16));
                const inverse: u16 = @intCast(try reader.readBits(16));
                if (length ^ inverse != 0xffff) return error.InvalidPuffinStream;
                try builder.addMetadata(metadata.items);
                var remaining = length;
                while (remaining != 0) : (remaining -= 1)
                    try builder.addLiteral(@intCast(try reader.readBits(8)));
                try builder.addEnd();
            },
            1, 2 => {
                const tables = if (kind == 1)
                    try fixedTables()
                else
                    try parseDynamicTables(allocator, &reader, &metadata);
                try builder.addMetadata(metadata.items);
                while (true) {
                    const symbol = try tables.literal_length.decode(&reader);
                    if (symbol < 256) {
                        try builder.addLiteral(@intCast(symbol));
                    } else if (symbol == 256) {
                        try builder.addEnd();
                        break;
                    } else {
                        if (symbol > 285) return error.InvalidPuffinStream;
                        const length_index = symbol - 257;
                        const length: u16 = length_bases[length_index] +
                            @as(u16, @intCast(try reader.readBits(@intCast(length_extra[length_index]))));
                        const distance_symbol = try tables.distance.decode(&reader);
                        if (distance_symbol >= distance_bases.len)
                            return error.InvalidPuffinStream;
                        const distance: u16 = distance_bases[distance_symbol] +
                            @as(u16, @intCast(try reader.readBits(@intCast(distance_extra[distance_symbol]))));
                        try builder.addLengthDistance(length, distance);
                    }
                }
            },
            else => return error.InvalidPuffinStream,
        }
        final_seen = final;
        if (builder.output.items.len > max_output_len)
            return error.OutputLimitExceeded;
    }
    try builder.flushLiterals();
    const consumed_bits = reader.bit_pos - bit_offset;
    if (reader.bit_end - reader.bit_pos > 7)
        return error.TrailingData;
    while (reader.bit_pos < reader.bit_end)
        if (try reader.readBits(1) != 0) return error.TrailingData;
    if (builder.output.items.len > max_output_len)
        return error.OutputLimitExceeded;
    return .{
        .bytes = try builder.output.toOwnedSlice(allocator),
        .consumed_bits = consumed_bits,
    };
}

pub fn huffDeflateAlloc(
    allocator: std.mem.Allocator,
    puff: []const u8,
    start_bit_offset: u3,
    expected_bit_length: u64,
) Error![]u8 {
    const total_bits = std.math.add(u64, start_bit_offset, expected_bit_length) catch
        return error.IntegerOverflow;
    const byte_length_u64 = (total_bits + 7) / 8;
    const byte_length = std.math.cast(usize, byte_length_u64) orelse
        return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, byte_length);
    errdefer allocator.free(output);
    var writer = BitWriter.init(output);
    try writer.writeBits(start_bit_offset, 0);
    var reader = PuffReader.init(puff);
    while (reader.remaining() != 0) {
        const metadata = try reader.readMetadata();
        const header = metadata[0];
        const final: u1 = @intCast(header >> 7);
        const kind: u2 = @intCast((header >> 5) & 3);
        const skipped = header & 0x1f;
        try writer.writeBits(1, final);
        try writer.writeBits(2, kind);
        switch (kind) {
            0 => {
                try writer.alignByte(skipped);
                const token = try reader.nextToken();
                switch (token) {
                    .literals => |literals| {
                        if (literals.len > std.math.maxInt(u16))
                            return error.InvalidPuffinStream;
                        try writer.writeBits(16, @as(u16, @intCast(literals.len)));
                        try writer.writeBits(16, ~@as(u16, @intCast(literals.len)));
                        for (literals) |value| try writer.writeBits(8, value);
                        if ((try reader.nextToken()) != .end)
                            return error.InvalidPuffinStream;
                    },
                    .end => {
                        try writer.writeBits(16, @as(u16, 0));
                        try writer.writeBits(16, @as(u16, 0xffff));
                    },
                    else => return error.InvalidPuffinStream,
                }
            },
            1, 2 => {
                const tables = if (kind == 1)
                    try fixedTables()
                else
                    try writeDynamicTables(metadata[1..], &writer);
                while (true) switch (try reader.nextToken()) {
                    .literals => |literals| for (literals) |value|
                        try tables.literal_length.encode(&writer, value),
                    .length_distance => |copy| {
                        const length_index = findBase(length_bases[0..], copy.length);
                        try tables.literal_length.encode(&writer, length_index + 257);
                        try writer.writeBits(
                            @intCast(length_extra[length_index]),
                            copy.length - length_bases[length_index],
                        );
                        const distance_index = findBase(distance_bases[0..], copy.distance);
                        try tables.distance.encode(&writer, distance_index);
                        try writer.writeBits(
                            @intCast(distance_extra[distance_index]),
                            copy.distance - distance_bases[distance_index],
                        );
                    },
                    .end => {
                        try tables.literal_length.encode(&writer, 256);
                        break;
                    },
                };
            },
            else => return error.InvalidPuffinStream,
        }
    }
    if (writer.bit_pos != total_bits) return error.SizeMismatch;
    return output;
}

const Token = union(enum) {
    literals: []const u8,
    length_distance: struct { length: u16, distance: u16 },
    end,
};

const PuffReader = struct {
    bytes: []const u8,
    offset: usize = 0,

    fn init(bytes: []const u8) PuffReader {
        return .{ .bytes = bytes };
    }

    fn remaining(self: PuffReader) usize {
        return self.bytes.len - self.offset;
    }

    fn readMetadata(self: *PuffReader) Error![]const u8 {
        if (self.remaining() < 3) return error.TruncatedFrame;
        const length = @as(usize, std.mem.readInt(u16, self.bytes[self.offset..][0..2], .big)) + 1;
        self.offset += 2;
        if (length > max_puff_metadata or length > self.remaining())
            return error.InvalidPuffinStream;
        const metadata = self.bytes[self.offset..][0..length];
        self.offset += length;
        return metadata;
    }

    fn nextToken(self: *PuffReader) Error!Token {
        if (self.remaining() == 0) return error.TruncatedFrame;
        const first = self.bytes[self.offset];
        self.offset += 1;
        if (first & 0x80 == 0) {
            var length: usize = first + 1;
            if (first == 0x7f) {
                if (self.remaining() < 2) return error.TruncatedFrame;
                length = @as(usize, std.mem.readInt(u16, self.bytes[self.offset..][0..2], .big)) + 128;
                self.offset += 2;
            }
            if (length > self.remaining()) return error.TruncatedFrame;
            const literals = self.bytes[self.offset..][0..length];
            self.offset += length;
            return .{ .literals = literals };
        }
        var length: u16 = @as(u16, first & 0x7f) + 3;
        if (first & 0x7f == 127) {
            if (self.remaining() == 0) return error.TruncatedFrame;
            length = 130 + @as(u16, self.bytes[self.offset]);
            self.offset += 1;
        }
        if (length == 259) return .end;
        if (self.remaining() < 2 or length > 258)
            return error.InvalidPuffinStream;
        const distance = std.mem.readInt(u16, self.bytes[self.offset..][0..2], .big) + 1;
        self.offset += 2;
        if (distance > 32768) return error.InvalidPuffinStream;
        return .{ .length_distance = .{ .length = length, .distance = distance } };
    }
};

fn fixedTables() Error!Tables {
    var literal_lengths: [288]u8 = undefined;
    @memset(literal_lengths[0..144], 8);
    @memset(literal_lengths[144..256], 9);
    @memset(literal_lengths[256..280], 7);
    @memset(literal_lengths[280..288], 8);
    const distance_lengths = [_]u8{5} ** 30;
    return .{
        .literal_length = try Huffman.init(&literal_lengths),
        .distance = try Huffman.init(&distance_lengths),
    };
}

fn parseDynamicTables(
    allocator: std.mem.Allocator,
    reader: *BitReader,
    metadata: *std.ArrayList(u8),
) Error!Tables {
    const hlit_raw: u8 = @intCast(try reader.readBits(5));
    const hdist_raw: u8 = @intCast(try reader.readBits(5));
    const hclen_raw: u8 = @intCast(try reader.readBits(4));
    try metadata.append(allocator, hlit_raw);
    try metadata.append(allocator, hdist_raw);
    try metadata.append(allocator, hclen_raw);
    const lit_count: usize = @as(usize, hlit_raw) + 257;
    const distance_count: usize = @as(usize, hdist_raw) + 1;
    const code_count: usize = @as(usize, hclen_raw) + 4;
    var code_lengths: [19]u8 = @splat(0);
    var packed_value: u8 = 0;
    for (0..code_count) |index| {
        const length: u8 = @intCast(try reader.readBits(3));
        code_lengths[permutations[index]] = length;
        if (index % 2 == 0) {
            packed_value = length << 4;
            if (index + 1 == code_count) try metadata.append(allocator, packed_value);
        } else {
            packed_value |= length;
            try metadata.append(allocator, packed_value);
        }
    }
    const code_table = try Huffman.init(&code_lengths);
    var all_lengths: [316]u8 = @splat(0);
    var index: usize = 0;
    const total = lit_count + distance_count;
    while (index < total) {
        const symbol = try code_table.decode(reader);
        if (symbol < 16) {
            all_lengths[index] = @intCast(symbol);
            try metadata.append(allocator, @intCast(symbol));
            index += 1;
            continue;
        }
        const extra_bits: u6 = switch (symbol) {
            16 => 2,
            17 => 3,
            18 => 7,
            else => return error.InvalidPuffinStream,
        };
        const extra: u8 = @intCast(try reader.readBits(extra_bits));
        const count: usize = switch (symbol) {
            16 => 3 + extra,
            17 => 3 + extra,
            18 => 11 + extra,
            else => unreachable,
        };
        if (index + count > total or (symbol == 16 and index == 0))
            return error.InvalidPuffinStream;
        const value: u8 = if (symbol == 16) all_lengths[index - 1] else 0;
        @memset(all_lengths[index..][0..count], value);
        try metadata.append(allocator, switch (symbol) {
            16 => 16 + extra,
            17 => 20 + extra,
            18 => 28 + extra,
            else => unreachable,
        });
        index += count;
    }
    return .{
        .literal_length = try Huffman.init(all_lengths[0..lit_count]),
        .distance = try Huffman.init(all_lengths[lit_count..total]),
    };
}

fn writeDynamicTables(metadata: []const u8, writer: *BitWriter) Error!Tables {
    if (metadata.len < 3) return error.InvalidPuffinStream;
    var index: usize = 0;
    const hlit_raw = metadata[index];
    index += 1;
    const hdist_raw = metadata[index];
    index += 1;
    const hclen_raw = metadata[index];
    index += 1;
    if (hlit_raw > 29 or hdist_raw > 29 or hclen_raw > 15)
        return error.InvalidPuffinStream;
    try writer.writeBits(5, hlit_raw);
    try writer.writeBits(5, hdist_raw);
    try writer.writeBits(4, hclen_raw);
    const lit_count: usize = @as(usize, hlit_raw) + 257;
    const distance_count: usize = @as(usize, hdist_raw) + 1;
    const code_count: usize = @as(usize, hclen_raw) + 4;
    const packed_count = (code_count + 1) / 2;
    if (packed_count > metadata.len - index) return error.TruncatedFrame;
    var code_lengths: [19]u8 = @splat(0);
    for (0..code_count) |code_index| {
        const packed_value = metadata[index + code_index / 2];
        const length = if (code_index % 2 == 0) packed_value >> 4 else packed_value & 0xf;
        if (length > 7) return error.InvalidPuffinStream;
        code_lengths[permutations[code_index]] = length;
        try writer.writeBits(3, length);
    }
    index += packed_count;
    const code_table = try Huffman.init(&code_lengths);
    var all_lengths: [316]u8 = @splat(0);
    var length_index: usize = 0;
    const total = lit_count + distance_count;
    while (length_index < total) {
        if (index >= metadata.len) return error.TruncatedFrame;
        const pcode = metadata[index];
        index += 1;
        if (pcode > 155) return error.InvalidPuffinStream;
        const symbol: usize = if (pcode < 16) pcode else if (pcode < 20) 16 else if (pcode < 28) 17 else 18;
        try code_table.encode(writer, symbol);
        if (symbol < 16) {
            all_lengths[length_index] = @intCast(symbol);
            length_index += 1;
            continue;
        }
        const extra: u8 = switch (symbol) {
            16 => pcode - 16,
            17 => pcode - 20,
            18 => pcode - 28,
            else => unreachable,
        };
        const count: usize = switch (symbol) {
            16, 17 => 3 + extra,
            18 => 11 + extra,
            else => unreachable,
        };
        if (length_index + count > total or (symbol == 16 and length_index == 0))
            return error.InvalidPuffinStream;
        try writer.writeBits(switch (symbol) {
            16 => 2,
            17 => 3,
            18 => 7,
            else => unreachable,
        }, extra);
        const value: u8 = if (symbol == 16) all_lengths[length_index - 1] else 0;
        @memset(all_lengths[length_index..][0..count], value);
        length_index += count;
    }
    if (index != metadata.len) return error.TrailingData;
    return .{
        .literal_length = try Huffman.init(all_lengths[0..lit_count]),
        .distance = try Huffman.init(all_lengths[lit_count..total]),
    };
}

fn reverseBits(value: u16, length: u8) u16 {
    var input = value;
    var output: u16 = 0;
    for (0..length) |_| {
        output = (output << 1) | (input & 1);
        input >>= 1;
    }
    return output;
}

fn findBase(bases: []const u16, value: u16) usize {
    var index: usize = 0;
    while (index + 1 < bases.len and bases[index + 1] <= value) : (index += 1) {}
    return index;
}

test "Android OTA Puffin fixed and stored deflates round trip byte exactly" {
    const allocator = std.testing.allocator;
    const cases = [_][]const u8{
        &.{ 0x63, 0x64, 0x62, 0x66, 0x61, 0x05, 0x00 },
        &.{ 0x01, 0x05, 0x00, 0xfa, 0xff, 1, 2, 3, 4, 5 },
        &.{ 0x03, 0x00 },
    };
    for (cases) |deflate| {
        const puff_result = try puffDeflatePaddedAlloc(
            allocator,
            deflate,
            0,
            deflate.len * 8,
            1024,
        );
        defer allocator.free(puff_result.bytes);
        const restored = try huffDeflateAlloc(
            allocator,
            puff_result.bytes,
            0,
            puff_result.consumed_bits,
        );
        defer allocator.free(restored);
        try std.testing.expectEqualSlices(u8, deflate, restored);
    }
}

test "Android OTA Puffin dynamic Huffman deflate round trips byte exactly" {
    const allocator = std.testing.allocator;
    const input = ("dynamic Puffin codec payload with repeated words and punctuation.\n" ** 32) ++
        "a short structured tail";
    const encoded = try deflate_mod.encodeRawDynamicWithOptionsAlloc(
        allocator,
        input,
        .{},
    );
    defer allocator.free(encoded);
    try std.testing.expectEqual(@as(u2, 2), @as(u2, @truncate(encoded[0] >> 1)));
    const puff_result = try puffDeflatePaddedAlloc(
        allocator,
        encoded,
        0,
        encoded.len * 8,
        1 << 20,
    );
    defer allocator.free(puff_result.bytes);
    const restored = try huffDeflateAlloc(
        allocator,
        puff_result.bytes,
        0,
        puff_result.consumed_bits,
    );
    defer allocator.free(restored);
    try std.testing.expectEqualSlices(u8, encoded, restored);
}
