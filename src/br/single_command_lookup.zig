const std = @import("std");
const core = @import("../core.zig");
const command_lut = @import("command_lut.zig");

pub const Entry = packed struct(u32) {
    value: u16 = 0,
    copy_extra_bits: u5 = 0,
    huffman_bits: u4 = 0,
    distance_symbol_zero: bool = false,
    zero_insert: bool = false,
    valid: bool = false,
    padding: u4 = 0,
};

pub const Lookup = struct {
    const lookup_bits: u4 = 10;
    slots: [1 << lookup_bits]Entry = @splat(.{}),

    pub fn init(table: anytype) core.Error!Lookup {
        var lookup: Lookup = .{};
        for (table.entries[0..table.len]) |tree_entry| {
            if (tree_entry.bits > lookup_bits) continue;
            const entry = try preparedEntry(tree_entry.symbol, tree_entry.bits);
            const fill = @as(usize, 1) << @intCast(lookup_bits - tree_entry.bits);
            var index: usize = 0;
            while (index < fill) : (index += 1)
                lookup.slots[tree_entry.code | (index << tree_entry.bits)] = entry;
        }
        return lookup;
    }

    pub fn initSingle(symbol: u16) core.Error!Lookup {
        return .{ .slots = @splat(try preparedEntry(symbol, 0)) };
    }

    pub inline fn decodeFast(self: *const Lookup, reader: anytype) core.Error!?Entry {
        const entry = self.slots[reader.peekBits10Padded()];
        if (!entry.valid) {
            @branchHint(.unlikely);
            return null;
        }
        if (!reader.hasStagedBits(entry.huffman_bits)) {
            @branchHint(.unlikely);
            return error.TruncatedFrame;
        }
        reader.advanceBitsStagedAssumeAvailable(entry.huffman_bits);
        return entry;
    }
};

fn preparedEntry(symbol: u16, huffman_bits: u4) core.Error!Entry {
    if (symbol >= command_lut.compact_entries.len) return error.InvalidHuffmanCode;
    const command = command_lut.compact_entries[symbol];
    if (command.insert_base == 0 and command.insert_extra_bits == 0) {
        return .{
            .value = command.copy_base,
            .copy_extra_bits = command.copy_extra_bits,
            .huffman_bits = huffman_bits,
            .distance_symbol_zero = command.distance_code == 0,
            .zero_insert = true,
            .valid = true,
        };
    }
    return .{ .value = symbol, .huffman_bits = huffman_bits, .valid = true };
}

test "single-tree command lookup embeds zero-insert metadata" {
    const huffman = @import("../huffman.zig");
    const bitstream = @import("../bitstream.zig");
    const FastReader = @import("fast_bit_reader.zig").Reader;
    const lengths = [_]u4{ 1, 1 } ++ [_]u4{0} ** 702;
    const table = try huffman.HuffmanTable(704).init(&lengths);
    const lookup = try Lookup.init(&table);
    const encoder = try huffman.HuffmanTable(704).Encoder.init(&lengths);
    var writer: bitstream.BitWriter = .{};
    defer writer.deinit(std.testing.allocator);
    try encoder.writeSymbol(&writer, std.testing.allocator, 0);
    try encoder.writeSymbol(&writer, std.testing.allocator, 1);
    const encoded = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(encoded);
    var reader = FastReader.initFrom(bitstream.BitReader.init(encoded));

    const first = (try lookup.decodeFast(&reader)).?;
    try std.testing.expect(first.zero_insert);
    try std.testing.expectEqual(@as(u16, 2), first.value);
    try std.testing.expect(first.distance_symbol_zero);
    const second = (try lookup.decodeFast(&reader)).?;
    try std.testing.expect(second.zero_insert);
    try std.testing.expectEqual(@as(u16, 3), second.value);
}
