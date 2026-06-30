const std = @import("std");
const bitstream = @import("bitstream.zig");
const core = @import("core.zig");

pub const Error = core.Error;

pub const max_code_bits = 15;
pub const fixed_literal_count = 288;
pub const fixed_distance_count = 32;

pub const Symbol = struct {
    value: u16,
    bits: u4,
};

pub fn HuffmanTable(comptime max_symbols: usize) type {
    return struct {
        entries: [max_symbols]Entry = undefined,
        len: usize = 0,

        const Self = @This();
        pub const Entry = struct {
            symbol: u16,
            code: u16,
            bits: u4,
        };

        pub const Encoder = struct {
            codes: [max_symbols]u16 = @splat(0),
            bits: [max_symbols]u4 = @splat(0),

            pub fn init(lengths: []const u4) Error!Encoder {
                const table = try Self.init(lengths);
                var encoder = Encoder{};
                for (table.entries[0..table.len]) |entry| {
                    encoder.codes[entry.symbol] = entry.code;
                    encoder.bits[entry.symbol] = entry.bits;
                }
                return encoder;
            }

            pub fn writeSymbol(self: Encoder, writer: *bitstream.BitWriter, allocator: std.mem.Allocator, symbol: usize) !void {
                if (symbol >= max_symbols or self.bits[symbol] == 0) return error.InvalidHuffmanCode;
                try writer.writeBits(allocator, self.codes[symbol], self.bits[symbol]);
            }
        };

        pub fn init(lengths: []const u4) Error!Self {
            @setEvalBranchQuota(200000);
            if (lengths.len > max_symbols) return error.CorruptFrame;
            var counts: [max_code_bits + 1]u16 = @splat(0);
            for (lengths) |bits| {
                if (bits > max_code_bits) return error.CorruptFrame;
                if (bits != 0) counts[bits] += 1;
            }

            var code: u16 = 0;
            var next_code: [max_code_bits + 1]u16 = @splat(0);
            for (1..max_code_bits + 1) |bits| {
                code = (code + counts[bits - 1]) << 1;
                next_code[bits] = code;
            }

            var table = Self{ .len = 0 };
            for (lengths, 0..) |bits, symbol| {
                if (bits == 0) continue;
                const canonical = next_code[bits];
                next_code[bits] += 1;
                const entry = Entry{
                    .symbol = @intCast(symbol),
                    .code = reverseBits(canonical, bits),
                    .bits = bits,
                };
                table.entries[table.len] = entry;
                table.len += 1;
            }
            return table;
        }

        pub fn decode(self: *const Self, reader: *bitstream.BitReader) Error!Symbol {
            var code: u16 = 0;
            var bits: u4 = 1;
            while (bits <= max_code_bits) {
                const bit = try reader.readBits(u16, 1);
                code |= bit << @intCast(bits - 1);
                for (self.entries[0..self.len]) |entry| {
                    if (entry.bits == bits and entry.code == code) {
                        return .{ .value = entry.symbol, .bits = bits };
                    }
                }
                if (bits == max_code_bits) break;
                bits += 1;
            }
            return error.InvalidHuffmanCode;
        }
    };
}

pub const code_length_order = [_]u8{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };
pub const CodeLengthTable = HuffmanTable(19);

pub const DynamicHeader = struct {
    final: bool,
    hlit: u16,
    hdist: u16,
    hclen: u8,
    code_length_lengths: [19]u4,
};

pub const DynamicLengths = struct {
    header: DynamicHeader,
    literal_lengths: [286]u4 = @splat(0),
    distance_lengths: [30]u4 = @splat(0),
};

pub fn parseDynamicHeader(reader: *bitstream.BitReader) Error!DynamicHeader {
    const final = (try reader.readBits(u1, 1)) != 0;
    const block_type = try reader.readBits(u2, 2);
    if (block_type != 0b10) return error.InvalidDeflateBlockType;

    const hlit: u16 = @as(u16, try reader.readBits(u5, 5)) + 257;
    const hdist: u16 = @as(u16, try reader.readBits(u5, 5)) + 1;
    const hclen: u8 = @as(u8, try reader.readBits(u4, 4)) + 4;
    if (hlit > 286 or hdist > 30 or hclen > code_length_order.len) return error.InvalidDynamicBlockHeader;

    var lengths: [19]u4 = @splat(0);
    for (code_length_order[0..hclen]) |symbol| {
        lengths[symbol] = try reader.readBits(u4, 3);
    }

    return .{
        .final = final,
        .hlit = hlit,
        .hdist = hdist,
        .hclen = hclen,
        .code_length_lengths = lengths,
    };
}

pub fn parseDynamicLengths(reader: *bitstream.BitReader) Error!DynamicLengths {
    return parseDynamicLengthsBody(try parseDynamicHeader(reader), reader);
}

pub fn parseDynamicLengthsAfterHeader(final: bool, reader: *bitstream.BitReader) Error!DynamicLengths {
    const hlit: u16 = @as(u16, try reader.readBits(u5, 5)) + 257;
    const hdist: u16 = @as(u16, try reader.readBits(u5, 5)) + 1;
    const hclen: u8 = @as(u8, try reader.readBits(u4, 4)) + 4;
    if (hlit > 286 or hdist > 30 or hclen > code_length_order.len) return error.InvalidDynamicBlockHeader;

    var lengths: [19]u4 = @splat(0);
    for (code_length_order[0..hclen]) |symbol| {
        lengths[symbol] = try reader.readBits(u4, 3);
    }

    return parseDynamicLengthsBody(.{
        .final = final,
        .hlit = hlit,
        .hdist = hdist,
        .hclen = hclen,
        .code_length_lengths = lengths,
    }, reader);
}

fn parseDynamicLengthsBody(header: DynamicHeader, reader: *bitstream.BitReader) Error!DynamicLengths {
    const code_lengths = try CodeLengthTable.init(&header.code_length_lengths);
    var combined: [286 + 30]u4 = @splat(0);
    const total = header.hlit + header.hdist;
    var pos: usize = 0;
    while (pos < total) {
        const symbol = (try code_lengths.decode(reader)).value;
        switch (symbol) {
            0...15 => {
                combined[pos] = @intCast(symbol);
                pos += 1;
            },
            16 => {
                if (pos == 0) return error.InvalidDynamicBlockHeader;
                const count: usize = @as(usize, try reader.readBits(u2, 2)) + 3;
                if (pos + count > total) return error.InvalidDynamicBlockHeader;
                @memset(combined[pos..][0..count], combined[pos - 1]);
                pos += count;
            },
            17 => {
                const count: usize = @as(usize, try reader.readBits(u3, 3)) + 3;
                if (pos + count > total) return error.InvalidDynamicBlockHeader;
                @memset(combined[pos..][0..count], 0);
                pos += count;
            },
            18 => {
                const count: usize = @as(usize, try reader.readBits(u7, 7)) + 11;
                if (pos + count > total) return error.InvalidDynamicBlockHeader;
                @memset(combined[pos..][0..count], 0);
                pos += count;
            },
            else => return error.InvalidDynamicBlockHeader,
        }
    }

    var parsed = DynamicLengths{ .header = header };
    @memcpy(parsed.literal_lengths[0..header.hlit], combined[0..header.hlit]);
    @memcpy(parsed.distance_lengths[0..header.hdist], combined[header.hlit..][0..header.hdist]);
    return parsed;
}

pub fn simpleCodeLengths(comptime n: usize, freqs: *const [n]u32, max_bits: u4) [n]u4 {
    var lengths: [n]u4 = @splat(0);
    var active: usize = 0;
    for (freqs) |freq| {
        if (freq != 0) active += 1;
    }
    if (active == 0) return lengths;
    var bits: u4 = 1;
    var capacity: usize = 2;
    while (capacity < active and bits < max_bits) : (bits += 1) capacity <<= 1;
    for (freqs, 0..) |freq, i| {
        if (freq != 0) lengths[i] = bits;
    }
    return lengths;
}

pub fn weightedCodeLengths(comptime n: usize, freqs: *const [n]u32, max_bits: u4) [n]u4 {
    var lengths: [n]u4 = @splat(0);
    var active: usize = 0;
    for (freqs) |freq| {
        if (freq != 0) active += 1;
    }
    if (active == 0) return lengths;
    if (active == 1) {
        for (freqs, 0..) |freq, i| {
            if (freq != 0) lengths[i] = 1;
        }
        return lengths;
    }

    var remaining = active;
    var current_bits: u4 = 1;
    while (remaining > 0) : (current_bits += 1) {
        var best_i: ?usize = null;
        var best_freq: u32 = 0;
        for (freqs, 0..) |freq, i| {
            if (freq == 0 or lengths[i] != 0) continue;
            if (best_i == null or freq > best_freq) {
                best_i = i;
                best_freq = freq;
            }
        }
        const i = best_i orelse break;
        lengths[i] = @min(current_bits, max_bits);
        remaining -= 1;
        if (current_bits == max_bits) {
            for (freqs, 0..) |freq, j| {
                if (freq != 0 and lengths[j] == 0) lengths[j] = max_bits;
            }
            break;
        }
    }
    return lengths;
}

pub const FixedLookupEntry = struct { symbol: u16, bits: u4 };

pub const fixed_literal_lookup = blk: {
    @setEvalBranchQuota(10000);
    const lengths = fixedLiteralLengths();
    const table = FixedLiteralTable.init(&lengths) catch unreachable;
    var lookup: [512]FixedLookupEntry = @splat(.{ .symbol = 0, .bits = 0 });
    for (table.entries[0..table.len]) |entry| {
        const fill = @as(usize, 1) << @intCast(9 - entry.bits);
        var i: usize = 0;
        while (i < fill) : (i += 1) {
            lookup[entry.code | (i << entry.bits)] = .{ .symbol = entry.symbol, .bits = entry.bits };
        }
    }
    break :blk lookup;
};

pub fn decodeFixedLiteralFast(reader: *bitstream.BitReader) Error!Symbol {
    const peek = reader.peekBitsPadded(u16, 9);
    const entry = fixed_literal_lookup[peek & 0x1ff];
    if (entry.bits == 0) return error.InvalidHuffmanCode;
    try reader.skipBits(entry.bits);
    return .{ .value = entry.symbol, .bits = entry.bits };
}

pub const fixed_distance_lookup = blk: {
    @setEvalBranchQuota(2000);
    const lengths = fixedDistanceLengths();
    const table = FixedDistanceTable.init(&lengths) catch unreachable;
    var lookup: [32]FixedLookupEntry = @splat(.{ .symbol = 0, .bits = 0 });
    for (table.entries[0..table.len]) |entry| {
        lookup[entry.code] = .{ .symbol = entry.symbol, .bits = entry.bits };
    }
    break :blk lookup;
};

pub fn decodeFixedDistanceFast(reader: *bitstream.BitReader) Error!Symbol {
    const peek = reader.peekBitsPadded(u16, 5);
    const entry = fixed_distance_lookup[peek & 0x1f];
    if (entry.bits == 0) return error.InvalidHuffmanCode;
    try reader.skipBits(entry.bits);
    return .{ .value = entry.symbol, .bits = entry.bits };
}

pub const FixedLiteralTable = HuffmanTable(fixed_literal_count);
pub const FixedDistanceTable = HuffmanTable(fixed_distance_count);

pub fn fixedLiteralLengths() [fixed_literal_count]u4 {
    var lengths: [fixed_literal_count]u4 = undefined;
    for (&lengths, 0..) |*len, i| {
        len.* = switch (i) {
            0...143 => 8,
            144...255 => 9,
            256...279 => 7,
            280...287 => 8,
            else => unreachable,
        };
    }
    return lengths;
}

pub fn fixedDistanceLengths() [fixed_distance_count]u4 {
    return [_]u4{5} ** fixed_distance_count;
}

pub fn fixedLiteralTable() Error!FixedLiteralTable {
    const lengths = fixedLiteralLengths();
    return FixedLiteralTable.init(&lengths);
}

pub fn fixedDistanceTable() Error!FixedDistanceTable {
    const lengths = fixedDistanceLengths();
    return FixedDistanceTable.init(&lengths);
}

fn reverseBits(code: u16, bits: u4) u16 {
    var out: u16 = 0;
    var i: u4 = 0;
    while (i < bits) : (i += 1) {
        out = (out << 1) | ((code >> @intCast(i)) & 1);
    }
    return out;
}

test "fixed Huffman tables expose expected boundary code lengths" {
    const lit_lengths = fixedLiteralLengths();
    try std.testing.expectEqual(@as(u4, 8), lit_lengths[0]);
    try std.testing.expectEqual(@as(u4, 8), lit_lengths[143]);
    try std.testing.expectEqual(@as(u4, 9), lit_lengths[144]);
    try std.testing.expectEqual(@as(u4, 9), lit_lengths[255]);
    try std.testing.expectEqual(@as(u4, 7), lit_lengths[256]);
    try std.testing.expectEqual(@as(u4, 7), lit_lengths[279]);
    try std.testing.expectEqual(@as(u4, 8), lit_lengths[280]);
    try std.testing.expectEqual(@as(u4, 8), lit_lengths[287]);

    const dist_lengths = fixedDistanceLengths();
    for (dist_lengths) |bits| try std.testing.expectEqual(@as(u4, 5), bits);
}

test "canonical Huffman decoder handles a small RFC-style tree" {
    const Table = HuffmanTable(4);
    const table = try Table.init(&.{ 2, 1, 3, 3 });
    var reader = bitstream.BitReader.init(&.{0b0001_1010});
    try std.testing.expectEqual(@as(u16, 1), (try table.decode(&reader)).value);
    try std.testing.expectEqual(@as(u16, 0), (try table.decode(&reader)).value);
    try std.testing.expectEqual(@as(u16, 2), (try table.decode(&reader)).value);
}

test "fixed literal table decodes end-of-block code" {
    const table = try fixedLiteralTable();
    // Symbol 256 has canonical code 0000000; deflate stores it LSB-first.
    var reader = bitstream.BitReader.init(&.{0});
    const sym = try table.decode(&reader);
    try std.testing.expectEqual(@as(u16, 256), sym.value);
    try std.testing.expectEqual(@as(u4, 7), sym.bits);
}

test "dynamic header parser reads RFC1951 fields" {
    // BFINAL=1, BTYPE=dynamic, HLIT raw=0, HDIST raw=0, HCLEN raw=0, then four 3-bit code-length lengths.
    var reader = bitstream.BitReader.init(&.{ 0x05, 0x00, 0x48, 0x02 });
    const header = try parseDynamicHeader(&reader);
    try std.testing.expect(header.final);
    try std.testing.expectEqual(@as(u16, 257), header.hlit);
    try std.testing.expectEqual(@as(u16, 1), header.hdist);
    try std.testing.expectEqual(@as(u8, 4), header.hclen);
    try std.testing.expectEqual(@as(u4, 4), header.code_length_lengths[16]);
    try std.testing.expectEqual(@as(u4, 4), header.code_length_lengths[17]);
    try std.testing.expectEqual(@as(u4, 4), header.code_length_lengths[18]);
    try std.testing.expectEqual(@as(u4, 0), header.code_length_lengths[0]);
}

test "dynamic length parser expands repeat symbols" {
    // Synthetic dynamic block header:
    // - final dynamic block, HLIT=257, HDIST=1, HCLEN=18
    // - code-length alphabet uses symbols 1, 3, 17, 18, all 3 bits wide
    // - length stream expands to: one literal length 3, 255 zeros, one length 1, one distance length 1.
    const bytes = [_]u8{ 0x05, 0xc0, 0x01, 0x01, 0x00, 0x00, 0x00, 0x02, 0x20, 0xfb, 0xa7, 0x06 };
    var reader = bitstream.BitReader.init(&bytes);
    const parsed = try parseDynamicLengths(&reader);
    try std.testing.expectEqual(@as(u16, 257), parsed.header.hlit);
    try std.testing.expectEqual(@as(u16, 1), parsed.header.hdist);
    try std.testing.expectEqual(@as(u4, 3), parsed.literal_lengths[0]);
    for (parsed.literal_lengths[1..256]) |bits| try std.testing.expectEqual(@as(u4, 0), bits);
    try std.testing.expectEqual(@as(u4, 1), parsed.literal_lengths[256]);
    try std.testing.expectEqual(@as(u4, 1), parsed.distance_lengths[0]);
}

test "fixed Huffman encoder writes symbols decoded by fixed table" {
    const lengths = fixedLiteralLengths();
    const encoder = try FixedLiteralTable.Encoder.init(&lengths);
    const decoder = try fixedLiteralTable();
    var writer = bitstream.BitWriter{};
    defer writer.deinit(std.testing.allocator);
    try encoder.writeSymbol(&writer, std.testing.allocator, 'h');
    try encoder.writeSymbol(&writer, std.testing.allocator, 'i');
    try encoder.writeSymbol(&writer, std.testing.allocator, 256);
    const bytes = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(bytes);

    var reader = bitstream.BitReader.init(bytes);
    try std.testing.expectEqual(@as(u16, 'h'), (try decoder.decode(&reader)).value);
    try std.testing.expectEqual(@as(u16, 'i'), (try decoder.decode(&reader)).value);
    try std.testing.expectEqual(@as(u16, 256), (try decoder.decode(&reader)).value);
}

test "dynamic parser rejects non-dynamic block type and truncated header" {
    var stored_reader = bitstream.BitReader.init(&.{0x01});
    try std.testing.expectError(error.InvalidDeflateBlockType, parseDynamicHeader(&stored_reader));
    var truncated_reader = bitstream.BitReader.init(&.{0x05});
    try std.testing.expectError(error.TruncatedFrame, parseDynamicHeader(&truncated_reader));
}

test "simple Huffman length builder creates decodable table" {
    const freqs = [_]u32{ 5, 7, 1, 0, 3 };
    const lengths = simpleCodeLengths(freqs.len, &freqs, 7);
    try std.testing.expect(lengths[0] != 0);
    try std.testing.expect(lengths[3] == 0);
    const Table = HuffmanTable(freqs.len);
    const table = try Table.init(&lengths);
    try std.testing.expect(table.len == 4);
}

test "weighted Huffman length builder favors frequent symbols" {
    const freqs = [_]u32{ 100, 50, 25, 1 };
    const lengths = weightedCodeLengths(freqs.len, &freqs, 7);
    try std.testing.expect(lengths[0] <= lengths[1]);
    try std.testing.expect(lengths[1] <= lengths[2]);
    try std.testing.expect(lengths[2] <= lengths[3]);
    const Table = HuffmanTable(freqs.len);
    const table = try Table.init(&lengths);
    try std.testing.expectEqual(@as(usize, 4), table.len);
}

test "fixed literal fast lookup matches table decoder" {
    const bytes = [_]u8{ 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 };
    var fast = bitstream.BitReader.init(&bytes);
    _ = try fast.readBits(u1, 1);
    _ = try fast.readBits(u2, 2);
    var slow = bitstream.BitReader.init(&bytes);
    _ = try slow.readBits(u1, 1);
    _ = try slow.readBits(u2, 2);
    const table = try fixedLiteralTable();
    for (0..6) |_| {
        try std.testing.expectEqual((try table.decode(&slow)).value, (try decodeFixedLiteralFast(&fast)).value);
    }
}

test "fixed distance fast lookup decodes all symbols" {
    for (0..30) |symbol| {
        const code = @bitReverse(@as(u5, @intCast(symbol)));
        var bytes = [_]u8{@intCast(code)};
        var reader = bitstream.BitReader.init(&bytes);
        try std.testing.expectEqual(@as(u16, @intCast(symbol)), (try decodeFixedDistanceFast(&reader)).value);
    }
}
