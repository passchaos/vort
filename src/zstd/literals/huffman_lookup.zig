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

        /// Build directly into caller storage when the canonical tree covers
        /// the complete prefix space. This avoids clearing `entries` before a
        /// valid Zstandard tree overwrites every slot.
        pub noinline fn buildComplete(self: *@This(), tree: anytype) bool {
            const tree_max_bits = tree.max_bit_count;
            if (tree_max_bits == 0 or tree_max_bits > max_bits) return false;
            const max_code_bits = @as(u5, tree_max_bits) + 1;
            var next_start: usize = 0;
            for (tree.nodes[0 .. @as(usize, tree.symbol_count_minus_one) + 1]) |node| {
                if (node.weight == 0) continue;
                if (node.weight > max_code_bits) return false;
                const bit_count: u4 = @intCast(max_code_bits - node.weight);
                if (bit_count == 0 or bit_count > max_bits) return false;
                const suffix_bits = max_bits - bit_count;
                const start = @as(usize, node.prefix) << suffix_bits;
                const count = @as(usize, 1) << suffix_bits;
                // Canonical prefixes occupy adjacent ranges in tree order.
                // Requiring the next exact start proves both non-overlap and
                // full initialization without a separate cleared bitmap.
                if (start != next_start or count > len - start) return false;
                next_start += count;
                for (self.entries[start..][0..count]) |*entry| {
                    entry.* = .{
                        .symbol = node.symbol,
                        .bit_count = bit_count,
                        .valid = true,
                    };
                }
            }
            return next_start == len;
        }

        pub inline fn lookup(self: *const @This(), bits: usize) ?Entry {
            const entry = self.entries[bits];
            return if (entry.valid) entry else null;
        }

        /// Read an entry after `buildComplete` proved that every table slot was
        /// initialized. Callers must also provide an in-range prefix. Keeping
        /// this contract separate from `lookup` preserves checked decoding for
        /// incomplete or hostile trees while removing the per-symbol validity
        /// branch from prevalidated bulk loops.
        pub inline fn lookupAssumeComplete(self: *const @This(), bits: usize) Entry {
            std.debug.assert(bits < len);
            std.debug.assert(self.entries[bits].valid);
            return self.entries[bits];
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

test "complete Huffman lookup overwrites every entry" {
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
    var table: Table(3) = undefined;
    try std.testing.expect(table.buildComplete(tree));
    try std.testing.expectEqual(@as(u8, 'a'), table.lookupAssumeComplete(0).symbol);
    try std.testing.expectEqual(@as(u8, 'b'), table.lookupAssumeComplete(7).symbol);
    for (0..4) |index|
        try std.testing.expectEqual(@as(u8, 'a'), table.lookup(index).?.symbol);
    for (4..8) |index|
        try std.testing.expectEqual(@as(u8, 'b'), table.lookup(index).?.symbol);
}

test "complete Huffman lookup accepts canonical mixed widths" {
    const Node = struct { symbol: u8, prefix: u16, weight: u4 };
    const Tree = struct {
        max_bit_count: u4,
        symbol_count_minus_one: u8,
        nodes: [3]Node,
    };
    const tree: Tree = .{
        .max_bit_count = 2,
        .symbol_count_minus_one = 2,
        .nodes = .{
            .{ .symbol = 'a', .prefix = 0, .weight = 1 },
            .{ .symbol = 'b', .prefix = 1, .weight = 1 },
            .{ .symbol = 'c', .prefix = 1, .weight = 2 },
        },
    };
    var table: Table(3) = undefined;
    try std.testing.expect(table.buildComplete(tree));
    try std.testing.expectEqual(@as(u8, 'a'), table.lookup(0).?.symbol);
    try std.testing.expectEqual(@as(u8, 'b'), table.lookup(2).?.symbol);
    try std.testing.expectEqual(@as(u8, 'c'), table.lookup(4).?.symbol);
    try std.testing.expectEqual(@as(u8, 'c'), table.lookup(7).?.symbol);
}

test "complete Huffman lookup rejects incomplete coverage" {
    const Node = struct { symbol: u8, prefix: u16, weight: u4 };
    const Tree = struct {
        max_bit_count: u4,
        symbol_count_minus_one: u8,
        nodes: [1]Node,
    };
    const tree: Tree = .{
        .max_bit_count = 2,
        .symbol_count_minus_one = 0,
        .nodes = .{.{ .symbol = 'a', .prefix = 0, .weight = 1 }},
    };
    var table: Table(3) = undefined;
    try std.testing.expect(!table.buildComplete(tree));
}

test "complete Huffman lookup rejects overlapping prefixes" {
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
            .{ .symbol = 'b', .prefix = 0, .weight = 1 },
        },
    };
    var table: Table(3) = undefined;
    try std.testing.expect(!table.buildComplete(tree));
}

test "complete Huffman lookup rejects excessive weights" {
    const Node = struct { symbol: u8, prefix: u16, weight: u4 };
    const Tree = struct {
        max_bit_count: u4,
        symbol_count_minus_one: u8,
        nodes: [1]Node,
    };
    const tree: Tree = .{
        .max_bit_count = 2,
        .symbol_count_minus_one = 0,
        .nodes = .{.{ .symbol = 'a', .prefix = 0, .weight = 4 }},
    };
    var table: Table(3) = undefined;
    try std.testing.expect(!table.buildComplete(tree));
}
