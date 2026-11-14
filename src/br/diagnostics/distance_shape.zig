//! Header-only shape of the Brotli distance coding plane for one compressed
//! meta-block. This is diagnostic evidence, never part of production decode:
//! it records how distance block types map the four RFC 7932 contexts onto
//! inline/packed trees and whether those trees fit a fixed nine-bit lookup.
//! The header argument is generic so the diagnostics layer stays below br.zig
//! in the import graph.

const std = @import("std");

pub const max_block_types = 256;
pub const max_trees = 256;

pub const DistanceBlockShape = struct {
    meta_block_index: usize = 0,
    route_tag: u8 = 0,
    block_type_count: u16 = 0,
    tree_count: u16 = 0,
    npostfix: u2 = 0,
    ndirect: u16 = 0,

    /// One row per distance block type; each row holds the four context tree
    /// indices in wire context order (copy length 2, 3, 4, then 5+).
    context_rows: [max_block_types][4]u16 = @splat(.{ 0, 0, 0, 0 }),
    /// Per-tree property vectors, indexed by absolute distance tree index.
    tree_single_symbol: [max_trees]bool = @splat(false),
    tree_max_bits: [max_trees]u4 = @splat(0),
    tree_tail9_space_eligible: [max_trees]bool = @splat(false),

    /// Number of block-type rows whose four contexts resolve to 1..4 distinct
    /// trees. Index zero stays unused.
    distinct_tree_histogram: [5]u32 = @splat(0),
    /// Distinct trees actually referenced by any context row.
    referenced_tree_count: u16 = 0,
    referenced_inline_count: u16 = 0,
    referenced_packed_count: u16 = 0,
    referenced_single_symbol_count: u16 = 0,
    referenced_tail9_ineligible_count: u16 = 0,
    /// Context slots (across every row) that point at a packed-tier tree.
    packed_context_slots: u32 = 0,
    /// Rows whose dominant context three resolves to a packed-tier tree.
    packed_context3_rows: u32 = 0,
    /// Referenced-tree count per maximum code width (index = max bits 0..15).
    tree_max_bits_histogram: [16]u32 = @splat(0),
    /// Referenced inline trees whose own table has room for an internal
    /// nine-bit tail lookup (single-symbol trees count as eligible).
    referenced_tail9_space_eligible_count: u16 = 0,
    /// Referenced inline trees lacking table space for the nine-bit tail.
    referenced_tail9_space_ineligible_count: u16 = 0,
};

/// Capture the distance plane from a parsed `MinimalCompressedHeader`-shaped
/// value. `inline_tree_count` is the codec's inline/packed tier boundary.
pub fn capture(
    meta_block_index: usize,
    route_tag: u8,
    header: anytype,
    inline_tree_count: u16,
) DistanceBlockShape {
    var shape: DistanceBlockShape = .{
        .meta_block_index = meta_block_index,
        .route_tag = route_tag,
        .block_type_count = header.distance_block.block_type_count,
        .tree_count = header.distance_tree_count,
        .npostfix = header.npostfix,
        .ndirect = header.ndirect,
    };
    const tree_count: usize = @intCast(header.distance_tree_count);
    const inline_count: usize = @intCast(inline_tree_count);
    std.debug.assert(tree_count <= max_trees);
    for (0..tree_count) |tree_index| {
        if (tree_index < inline_count) {
            const tree = header.distance_trees[tree_index];
            shape.tree_single_symbol[tree_index] = tree.single_symbol != null;
            shape.tree_max_bits[tree_index] = tree.table.max_bits;
            shape.tree_tail9_space_eligible[tree_index] =
                tree.single_symbol != null or tree.table.canBuildTailLookup9();
        } else {
            // Packed-tier trees store nibble code lengths rather than a full
            // table; recover the single-symbol flag and maximum width.
            const packed_tree = header.packed_distance_trees[tree_index - inline_count];
            shape.tree_single_symbol[tree_index] = packed_tree.single_symbol_plus_one != 0;
            if (packed_tree.single_symbol_plus_one == 0) {
                var max_bits: u4 = 0;
                for (packed_tree.lengths) |pair| {
                    max_bits = @max(max_bits, @as(u4, @truncate(pair)));
                    max_bits = @max(max_bits, @as(u4, @truncate(pair >> 4)));
                }
                shape.tree_max_bits[tree_index] = max_bits;
            }
        }
    }

    var referenced = [_]bool{false} ** max_trees;
    const type_count: usize = @intCast(header.distance_block.block_type_count);
    std.debug.assert(type_count <= max_block_types);
    for (0..type_count) |block_type| {
        const map_start = block_type * 4;
        var distinct: [4]u16 = .{ 0xffff, 0xffff, 0xffff, 0xffff };
        var distinct_count: u32 = 0;
        for (0..4) |context| {
            const tree_index: u16 = header.distance_context_map[map_start + context];
            shape.context_rows[block_type][context] = tree_index;
            if (tree_index >= tree_count) continue;
            if (!referenced[tree_index]) {
                referenced[tree_index] = true;
                shape.referenced_tree_count += 1;
                if (tree_index < inline_tree_count) {
                    shape.referenced_inline_count += 1;
                    if (shape.tree_tail9_space_eligible[tree_index])
                        shape.referenced_tail9_space_eligible_count += 1
                    else
                        shape.referenced_tail9_space_ineligible_count += 1;
                } else {
                    shape.referenced_packed_count += 1;
                }
                if (shape.tree_single_symbol[tree_index]) shape.referenced_single_symbol_count += 1;
                if (shape.tree_max_bits[tree_index] > 9) shape.referenced_tail9_ineligible_count += 1;
                shape.tree_max_bits_histogram[shape.tree_max_bits[tree_index]] += 1;
            }
            if (tree_index >= inline_tree_count) shape.packed_context_slots += 1;
            var seen = false;
            for (distinct[0..distinct_count]) |existing| {
                if (existing == tree_index) {
                    seen = true;
                    break;
                }
            }
            if (!seen) {
                distinct[distinct_count] = tree_index;
                distinct_count += 1;
            }
        }
        shape.distinct_tree_histogram[distinct_count] += 1;
        if (shape.context_rows[block_type][3] >= inline_tree_count) shape.packed_context3_rows += 1;
    }
    return shape;
}

test "Brotli distance shape captures tier and distinct context structure" {
    const FakeTable = struct {
        max_bits: u4 = 0,
        tail9_space: bool = true,
        pub fn canBuildTailLookup9(self: *const @This()) bool {
            return self.tail9_space;
        }
    };
    const FakeTree = struct {
        single_symbol: ?u16 = null,
        table: FakeTable = .{},
    };
    const FakePacked = struct {
        single_symbol_plus_one: u16 = 0,
        lengths: [1]u8 = .{0},
    };
    const FakeHeader = struct {
        distance_block: struct { block_type_count: u16 },
        distance_tree_count: u16,
        npostfix: u2,
        ndirect: u16,
        distance_context_map: [8]u8,
        distance_trees: [4]FakeTree,
        packed_distance_trees: [1]FakePacked,
    };
    var header = FakeHeader{
        .distance_block = .{ .block_type_count = 2 },
        .distance_tree_count = 4,
        .npostfix = 3,
        .ndirect = 16,
        // Row 0 collapses to one inline tree; row 1 spans inline and packed.
        .distance_context_map = .{ 1, 1, 1, 1, 2, 2, 3, 3 },
        .distance_trees = .{
            .{ .single_symbol = 0 },
            .{ .table = .{ .max_bits = 8, .tail9_space = false } },
            .{ .table = .{ .max_bits = 10 } },
            undefined,
        },
        .packed_distance_trees = .{.{ .single_symbol_plus_one = 8 }},
    };
    const shape = capture(3, 9, &header, 3);
    try std.testing.expectEqual(@as(usize, 3), shape.meta_block_index);
    try std.testing.expectEqual(@as(u16, 2), shape.block_type_count);
    try std.testing.expectEqual(@as(u32, 1), shape.distinct_tree_histogram[1]);
    try std.testing.expectEqual(@as(u32, 1), shape.distinct_tree_histogram[2]);
    try std.testing.expectEqual(@as(u16, 3), shape.referenced_tree_count);
    try std.testing.expectEqual(@as(u16, 2), shape.referenced_inline_count);
    try std.testing.expectEqual(@as(u16, 1), shape.referenced_packed_count);
    try std.testing.expectEqual(@as(u16, 1), shape.referenced_single_symbol_count);
    try std.testing.expectEqual(@as(u16, 1), shape.referenced_tail9_ineligible_count);
    // Tree 0 is a single symbol (space always available); tree 1 reports no
    // tail-nine table space despite short codes. The packed tree at index 3
    // is excluded from inline-space counts, so the two counts sum to the two
    // referenced inline trees rather than all three referenced trees.
    try std.testing.expectEqual(@as(u16, 1), shape.referenced_tail9_space_eligible_count);
    try std.testing.expectEqual(@as(u16, 1), shape.referenced_tail9_space_ineligible_count);
    try std.testing.expectEqual(
        shape.referenced_inline_count,
        shape.referenced_tail9_space_eligible_count + shape.referenced_tail9_space_ineligible_count,
    );
    try std.testing.expectEqual(@as(u32, 2), shape.packed_context_slots);
    try std.testing.expectEqual(@as(u32, 1), shape.packed_context3_rows);
    try std.testing.expectEqual(@as(u16, 1), shape.context_rows[0][0]);
    try std.testing.expectEqual(@as(u16, 3), shape.context_rows[1][3]);
}
