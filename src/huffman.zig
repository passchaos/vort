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

        pub fn init(lengths: []const u4) Error!Self {
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
                table.entries[table.len] = .{
                    .symbol = @intCast(symbol),
                    .code = reverseBits(canonical, bits),
                    .bits = bits,
                };
                table.len += 1;
            }
            return table;
        }

        pub fn decode(self: Self, reader: *bitstream.BitReader) Error!Symbol {
            var code: u16 = 0;
            var bits: u4 = 1;
            while (bits <= max_code_bits) : (bits += 1) {
                const bit = try reader.readBits(u16, 1);
                code |= bit << @intCast(bits - 1);
                for (self.entries[0..self.len]) |entry| {
                    if (entry.bits == bits and entry.code == code) {
                        return .{ .value = entry.symbol, .bits = bits };
                    }
                }
            }
            return error.InvalidHuffmanCode;
        }
    };
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
