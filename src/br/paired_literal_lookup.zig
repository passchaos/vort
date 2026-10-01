const std = @import("std");
const huffman = @import("../huffman.zig");
const builtin = @import("builtin");
const core = @import("../core.zig");

pub const Root = huffman.PackedLookup(9);
const Table = huffman.HuffmanTable(256);
const pair_flag: u16 = 0x8000;
pub const text_section = switch (builtin.object_format) {
    .elf => ".vort_br_paired_literal",
    .macho => "__TEXT,__vort_br_pair",
    .coff => ".text$vort_br_paired_literal",
    else => ".text",
};

/// Short literal roots remain a power-of-two plane. Complete ten-bit sibling
/// pairs use two symbol bytes in a cold plane. Two presence bits in the root
/// distinguish missing siblings and preserve the original fallback/error cursor.
pub const Lookups = struct {
    roots: [256]Root,
    pairs: [256][128]u16,

    pub fn prepareSingle(self: *Lookups, tree_index: usize, symbol: u16) linksection(text_section) core.Error!void {
        if (symbol > 255) return error.InvalidHuffmanCode;
        self.roots[tree_index] = try Root.initSingle(symbol);
    }

    pub fn prepare(self: *Lookups, tree_index: usize, table: *const Table) linksection(text_section) core.Error!void {
        const root = &self.roots[tree_index];
        root.* = .{};
        for (table.entries[0..table.len]) |entry| {
            if (entry.symbol > 255) return error.InvalidHuffmanCode;
            if (entry.bits > 9) continue;
            const value: u16 = (entry.symbol + 1) << 4 | entry.bits;
            const fill = @as(usize, 1) << @intCast(9 - entry.bits);
            for (0..fill) |index| root.slots[entry.code | (index << entry.bits)] = value;
        }
        const first: usize = table.first_by_bits[10];
        const end = first + table.count_by_bits[10];
        var pair_count: usize = 0;
        for (table.entries[first..end]) |entry| {
            const prefix = entry.code & 511;
            const root_slot = &self.roots[tree_index].slots[prefix];
            const pair_index: usize = if (root_slot.* & pair_flag != 0)
                (root_slot.* >> 4) & 127
            else blk: {
                if (root_slot.* != 0 or pair_count >= 128) return error.InvalidHuffmanCode;
                const index = pair_count;
                pair_count += 1;
                self.pairs[tree_index][index] = 0;
                root_slot.* = pair_flag | (@as(u16, @intCast(index)) << 4) | 10;
                break :blk index;
            };
            const branch: u4 = @intCast(entry.code >> 9);
            root_slot.* |= @as(u16, 1) << (11 + branch);
            self.pairs[tree_index][pair_index] |= entry.symbol << (branch * 8);
        }
    }

    pub inline fn decodeFast(self: *const Lookups, tree_index: usize, reader: anytype) core.Error!?u16 {
        const entry = self.roots[tree_index].slots[reader.peekBits9Padded()];
        if (entry == 0) {
            @branchHint(.unlikely);
            return null;
        }
        if (entry & pair_flag != 0) {
            const prefix = reader.peekBits10Padded();
            const branch: u4 = @intCast(prefix >> 9);
            if (entry & (@as(u16, 1) << (11 + branch)) == 0) return null;
            if (!reader.hasStagedBits(10)) return error.TruncatedFrame;
            reader.advanceBitsStagedAssumeAvailable(10);
            const pair = self.pairs[tree_index][(entry >> 4) & 127];
            return @as(u8, @truncate(pair >> (branch * 8)));
        }
        const bits: u4 = @truncate(entry);
        if (!reader.hasStagedBits(bits)) return error.TruncatedFrame;
        reader.advanceBitsStagedAssumeAvailable(bits);
        return (entry >> 4) - 1;
    }
};

test "paired literal roots match ten-bit roots at every truncated symbol" {
    const bitstream = @import("../bitstream.zig");
    const FastReader = @import("fast_bit_reader.zig").Reader;
    const lookups = try std.testing.allocator.create(Lookups);
    defer std.testing.allocator.destroy(lookups);
    try std.testing.expectEqual(@as(usize, 320 * 1024), @sizeOf(Lookups));
    inline for (0..4) |shape| {
        var lengths = [_]u4{0} ** 256;
        for (0..9) |index| lengths[index] = @intCast(index + 1);
        if (shape == 2) {
            lengths = @splat(10);
        } else if (shape == 3) {
            for (0..14) |index| lengths[index] = @intCast(index + 1);
            lengths[254] = 15;
            lengths[255] = 15;
        } else if (shape == 1) {
            lengths[253] = 10;
            lengths[254] = 11;
            lengths[255] = 11;
        } else {
            lengths[254] = 10;
            lengths[255] = 10;
        }
        const table = try Table.init(&lengths);
        const encoder = try Table.Encoder.init(&lengths);
        const reference = try huffman.PackedLookup(10).init(&table);
        try lookups.prepare(255, &table);
        for (lengths, 0..) |bits, symbol| {
            if (bits == 0) continue;
            var writer: bitstream.BitWriter = .{};
            defer writer.deinit(std.testing.allocator);
            try encoder.writeSymbol(&writer, std.testing.allocator, @intCast(symbol));
            const encoded = try writer.toOwnedSlice(std.testing.allocator);
            defer std.testing.allocator.free(encoded);
            for (0..@as(usize, bits) + 1) |available| {
                inline for (.{ false, true }) |scalar_fallback| {
                    var old_reader = FastReader.initFrom(bitstream.BitReader.initBitLength(encoded, available));
                    var new_reader = old_reader;
                    const expected = blk: {
                        const value = reference.decodeValueFast10(&old_reader) catch |err| break :blk @as(core.Error!u16, err);
                        if (value) |v| break :blk @as(core.Error!u16, v);
                        break :blk if (scalar_fallback) table.decodeValue(&old_reader) else reference.decodeValueLong(&table, &old_reader);
                    };
                    const actual = blk: {
                        const value = lookups.decodeFast(255, &new_reader) catch |err| break :blk @as(core.Error!u16, err);
                        if (value) |v| break :blk @as(core.Error!u16, v);
                        break :blk if (scalar_fallback) table.decodeValue(&new_reader) else lookups.roots[255].decodeValueLong(&table, &new_reader);
                    };
                    if (expected) |value| {
                        try std.testing.expectEqual(value, try actual);
                    } else |err| try std.testing.expectError(err, actual);
                    try std.testing.expectEqual(old_reader.bitPosition(), new_reader.bitPosition());
                }
            }
        }
    }
    try lookups.prepareSingle(0, 255);
    var empty = FastReader.initFrom(bitstream.BitReader.init(&.{}));
    try std.testing.expectEqual(@as(?u16, 255), try lookups.decodeFast(0, &empty));
    try std.testing.expectEqual(@as(usize, 0), empty.bitPosition());
    try std.testing.expectError(error.InvalidHuffmanCode, lookups.prepareSingle(0, 256));
    var invalid_table = try Table.init(&([_]u4{ 1, 1 } ++ [_]u4{0} ** 254));
    invalid_table.entries[1].symbol = 256;
    try std.testing.expectError(error.InvalidHuffmanCode, lookups.prepare(0, &invalid_table));
}
