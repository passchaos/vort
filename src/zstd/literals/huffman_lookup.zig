const std = @import("std");

pub const Entry = packed struct {
    symbol: u8,
    bit_count: u4,
    valid: bool,
    padding: u3 = 0,
};

pub fn Table(comptime max_bits: u4) type {
    return struct {
        pub const len = @as(usize, 1) << max_bits;
        entries: [len]Entry = @splat(.{
            .symbol = 0,
            .bit_count = 0,
            .valid = false,
        }),

        pub fn build(tree: anytype) @This() {
            var table: @This() = .{};
            const tree_max_bits = tree.max_bit_count;
            if (tree_max_bits > max_bits) return table;
            for (tree.nodes[0 .. @as(usize, tree.symbol_count_minus_one) + 1]) |node| {
                if (node.weight == 0) continue;
                const bit_count: u4 = (tree_max_bits + 1) - node.weight;
                const suffix_bits = max_bits - bit_count;
                const start = @as(usize, node.prefix) << suffix_bits;
                const count = @as(usize, 1) << suffix_bits;
                for (table.entries[start..][0..count]) |*entry| {
                    entry.* = .{
                        .symbol = node.symbol,
                        .bit_count = bit_count,
                        .valid = true,
                    };
                }
            }
            return table;
        }

        pub inline fn lookup(self: *const @This(), bits: usize) ?Entry {
            const entry = self.entries[bits];
            return if (entry.valid) entry else null;
        }
    };
}

test "Huffman lookup expands short prefixes" {
    const Node = struct { symbol: u8, prefix: u16, weight: u4 };
    const Tree = struct {
        max_bit_count: u4,
        symbol_count_minus_one: u8,
        nodes: [2]Node,
    };
    const tree: Tree = .{
        .max_bit_count = 1,
        .symbol_count_minus_one = 1,
        .nodes = .{
            .{ .symbol = 'a', .prefix = 0, .weight = 1 },
            .{ .symbol = 'b', .prefix = 1, .weight = 1 },
        },
    };
    const table = Table(3).build(tree);
    try std.testing.expectEqual(@as(u8, 'a'), table.lookup(0).?.symbol);
    try std.testing.expectEqual(@as(u8, 'a'), table.lookup(3).?.symbol);
    try std.testing.expectEqual(@as(u8, 'b'), table.lookup(4).?.symbol);
    try std.testing.expectEqual(@as(u8, 'b'), table.lookup(7).?.symbol);
}
