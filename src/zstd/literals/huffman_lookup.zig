const std = @import("std");

pub const Entry = packed struct {
    symbol: u8,
    bit_count: u4,
    valid: bool,
    padding: u3 = 0,
};

comptime {
    std.debug.assert(@sizeOf(Entry) == 2);
}

pub fn Table(comptime max_bits: u4) type {
    return struct {
        pub const bit_width = max_bits;
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
                fillCompleteRange(self.entries[start..][0..count], .{
                    .symbol = node.symbol,
                    .bit_count = bit_count,
                    .valid = true,
                });
            }
            return next_start == len;
        }

        inline fn fillCompleteRange(dest: []Entry, entry: Entry) void {
            switch (dest.len) {
                1 => dest[0] = entry,
                2 => {
                    dest[0] = entry;
                    dest[1] = entry;
                },
                4 => {
                    const wide: *align(1) [4]Entry = @ptrCast(dest.ptr);
                    wide.* = @splat(entry);
                },
                else => {
                    std.debug.assert(dest.len >= 8 and dest.len % 8 == 0);
                    var index: usize = 0;
                    while (index < dest.len) : (index += 8) {
                        const wide: *align(1) [8]Entry = @ptrCast(dest[index..].ptr);
                        wide.* = @splat(entry);
                    }
                },
            }
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

        /// Fill one canonical code range while a caller constructs a complete
        /// table alongside its tree. Completion and overlap remain the
        /// caller's responsibility; this only validates the range.
        pub inline fn fillCanonical(self: *@This(), prefix: u16, bit_count: u4, symbol: u8) bool {
            if (bit_count == 0 or bit_count > max_bits) return false;
            const suffix_bits = max_bits - bit_count;
            const start = @as(usize, prefix) << suffix_bits;
            const count = @as(usize, 1) << suffix_bits;
            if (start > len or count > len - start) return false;
            fillCompleteRange(self.entries[start..][0..count], .{
                .symbol = symbol,
                .bit_count = bit_count,
                .valid = true,
            });
            return true;
        }
    };
}

/// Compact lookup for callers that require complete canonical coverage before
/// decoding. Keeping the bit count as a full byte lets the hot X1 loop consume
/// it directly after one 16-bit load; incomplete tables keep using `Table` and
/// its explicit validity tag.
pub fn CompleteTable(comptime max_bits: u4) type {
    return struct {
        pub const bit_width = max_bits;
        pub const len = @as(usize, 1) << max_bits;
        pub const CompleteEntry = packed struct(u16) {
            symbol: u8,
            bit_count: u8,
        };

        entries: [len]CompleteEntry,

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
                if (start != next_start or count > len - start) return false;
                next_start += count;
                fillCompleteRange(self.entries[start..][0..count], .{
                    .symbol = node.symbol,
                    .bit_count = bit_count,
                });
            }
            return next_start == len;
        }

        pub inline fn lookupAssumeComplete(self: *const @This(), bits: usize) CompleteEntry {
            std.debug.assert(bits < len);
            return self.entries[bits];
        }

        pub inline fn lookup(self: *const @This(), bits: usize) ?CompleteEntry {
            if (bits >= len) return null;
            return self.entries[bits];
        }

        pub inline fn fillCanonical(self: *@This(), prefix: u16, bit_count: u4, symbol: u8) bool {
            if (bit_count == 0 or bit_count > max_bits) return false;
            const suffix_bits = max_bits - bit_count;
            const start = @as(usize, prefix) << suffix_bits;
            const count = @as(usize, 1) << suffix_bits;
            if (start > len or count > len - start) return false;
            fillCompleteRange(self.entries[start..][0..count], .{
                .symbol = symbol,
                .bit_count = bit_count,
            });
            return true;
        }

        inline fn fillCompleteRange(dest: []CompleteEntry, entry: CompleteEntry) void {
            switch (dest.len) {
                1 => dest[0] = entry,
                2 => {
                    dest[0] = entry;
                    dest[1] = entry;
                },
                4 => {
                    const wide: *align(1) [4]CompleteEntry = @ptrCast(dest.ptr);
                    wide.* = @splat(entry);
                },
                else => {
                    std.debug.assert(dest.len >= 8 and dest.len % 8 == 0);
                    var index: usize = 0;
                    while (index < dest.len) : (index += 8) {
                        const wide: *align(1) [8]CompleteEntry = @ptrCast(dest[index..].ptr);
                        wide.* = @splat(entry);
                    }
                },
            }
        }
    };
}

/// Decode a contiguous literal run while borrowing the already parsed tree.
/// The caller owns stream transitions and cold canonical fallback through the
/// supplied callbacks; this helper only keeps the complete-table hot path
/// compact and avoids embedding another tree copy in a decoder state object.
pub inline fn copyBorrowed(
    comptime ErrorSet: type,
    cursor: anytype,
    tree: anytype,
    lookup: anytype,
    decoded: *usize,
    regenerated_size: usize,
    literal_offset: usize,
    dest: []u8,
    comptime read_cold: anytype,
    comptime expect_end: anytype,
) ErrorSet!void {
    if (literal_offset != decoded.* or literal_offset > regenerated_size or
        regenerated_size - literal_offset < dest.len) return error.CorruptFrame;
    for (dest) |*out| {
        if (tree.max_bit_count != 0 and cursor.reader.available() >= tree.max_bit_count) {
            const width = tree.max_bit_count;
            const prefix = cursor.reader.peekBulkHuffman(width);
            if (lookup.lookup(prefix << @intCast(@TypeOf(lookup.*).bit_width - width))) |entry| {
                cursor.reader.skipBulkHuffman(entry.bit_count);
                out.* = entry.symbol;
                decoded.* += 1;
                continue;
            }
        }
        out.* = try read_cold(cursor, tree);
        decoded.* += 1;
    }
    if (decoded.* == regenerated_size) try expect_end(cursor);
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
    var compact: CompleteTable(3) = undefined;
    try std.testing.expect(!table.buildComplete(tree));
    try std.testing.expect(!compact.buildComplete(tree));
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
    var compact: CompleteTable(3) = undefined;
    try std.testing.expect(!table.buildComplete(tree));
    try std.testing.expect(!compact.buildComplete(tree));
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
    var compact: CompleteTable(3) = undefined;
    try std.testing.expect(!table.buildComplete(tree));
    try std.testing.expect(!compact.buildComplete(tree));
}

test "complete Huffman lookup matches reference fill for randomized canonical trees" {
    const Node = struct { symbol: u8, prefix: u16, weight: u4 };
    const Tree = struct {
        max_bit_count: u4,
        symbol_count_minus_one: u8,
        nodes: [64]Node,
    };
    const Leaf = struct { prefix: u16, depth: u4 };

    var prng = std.Random.DefaultPrng.init(0x4855_4646_4d41_4e31);
    const random = prng.random();
    for (0..256) |_| {
        var leaves: [64]Leaf = undefined;
        leaves[0] = .{ .prefix = 0, .depth = 0 };
        var leaf_count: usize = 1;
        const target_count = random.intRangeAtMost(usize, 2, leaves.len);
        while (leaf_count < target_count) {
            var splittable: [64]usize = undefined;
            var splittable_count: usize = 0;
            for (leaves[0..leaf_count], 0..) |leaf, index| {
                if (leaf.depth < 11) {
                    splittable[splittable_count] = index;
                    splittable_count += 1;
                }
            }
            if (splittable_count == 0) break;
            const split_index = splittable[random.uintLessThan(usize, splittable_count)];
            const split = leaves[split_index];
            std.mem.copyBackwards(
                Leaf,
                leaves[split_index + 2 .. leaf_count + 1],
                leaves[split_index + 1 .. leaf_count],
            );
            leaves[split_index] = .{
                .prefix = split.prefix << 1,
                .depth = split.depth + 1,
            };
            leaves[split_index + 1] = .{
                .prefix = (split.prefix << 1) | 1,
                .depth = split.depth + 1,
            };
            leaf_count += 1;
        }

        var max_depth: u4 = 0;
        for (leaves[0..leaf_count]) |leaf| max_depth = @max(max_depth, leaf.depth);
        var tree: Tree = undefined;
        tree.max_bit_count = max_depth;
        tree.symbol_count_minus_one = @intCast(leaf_count - 1);
        for (leaves[0..leaf_count], 0..) |leaf, index| {
            tree.nodes[index] = .{
                .symbol = @intCast(index),
                .prefix = leaf.prefix,
                .weight = max_depth + 1 - leaf.depth,
            };
        }

        const reference = Table(11).build(&tree);
        var actual: Table(11) = undefined;
        var compact: CompleteTable(11) = undefined;
        try std.testing.expect(actual.buildComplete(&tree));
        try std.testing.expect(compact.buildComplete(&tree));
        try std.testing.expectEqualSlices(
            u8,
            std.mem.asBytes(&reference.entries),
            std.mem.asBytes(&actual.entries),
        );
        const suffix_bits: u4 = Table(11).bit_width - max_depth;
        for (actual.entries, 0..) |entry, prefix| {
            try std.testing.expectEqual(entry.symbol, compact.entries[prefix].symbol);
            try std.testing.expectEqual(@as(u8, entry.bit_count), compact.entries[prefix].bit_count);
            const tree_width_index = (prefix >> suffix_bits) << suffix_bits;
            try std.testing.expectEqual(
                actual.entries[tree_width_index],
                entry,
            );
        }
        if (max_depth <= Table(7).bit_width) {
            var narrow: Table(7) = undefined;
            try std.testing.expect(narrow.buildComplete(&tree));
            for (narrow.entries, 0..) |entry, prefix|
                try std.testing.expectEqual(entry, actual.entries[prefix << 4]);
        }
    }
}

test "complete Huffman lookup supports checked incremental fills" {
    var table: CompleteTable(7) = undefined;
    try std.testing.expect(table.fillCanonical(0, 1, 'a'));
    try std.testing.expect(table.fillCanonical(1, 1, 'b'));
    try std.testing.expectEqual(@as(u8, 'a'), table.lookup(0).?.symbol);
    try std.testing.expectEqual(@as(u8, 'a'), table.lookup(63).?.symbol);
    try std.testing.expectEqual(@as(u8, 'b'), table.lookup(64).?.symbol);
    try std.testing.expectEqual(@as(u8, 'b'), table.lookup(127).?.symbol);
    try std.testing.expect(table.lookup(128) == null);
    try std.testing.expect(!table.fillCanonical(0, 0, 'x'));
    try std.testing.expect(!table.fillCanonical(0, 8, 'x'));
    try std.testing.expect(!table.fillCanonical(2, 1, 'x'));
}
