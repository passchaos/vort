const std = @import("std");
const bitstream = @import("../../bitstream.zig");

pub fn run(comptime Codec: type, comptime Support: type) !void {
    for ([_]bool{ false, true }) |final| {
        const wire = try Support.encodeCompressedHelloWithFinal(std.testing.allocator, final);
        defer std.testing.allocator.free(wire);
        const prefix = try normalizedPrefix(wire, 21);
        defer std.testing.allocator.free(prefix);
        const bit_len = wire.len * 8 - 21;
        const old = try std.testing.allocator.create(Codec.ParsedHeader);
        defer std.testing.allocator.destroy(old);
        const current = try std.testing.allocator.create(Codec.Header);
        defer std.testing.allocator.destroy(current);
        var successful_headers: usize = 0;
        // Reuse the same inactive destination through every truncated retry.
        for (0..bit_len + 1) |bits| {
            if (try compareHeader(Codec, old, current, prefix, bits, 5, final, false)) successful_headers += 1;
        }
        try std.testing.expect(successful_headers > 0);
        // A failed retry after success must not leave active metadata or trees
        // stale when the complete header is parsed again.
        try std.testing.expect(!try compareHeader(Codec, old, current, prefix, 0, 5, final, false));
        try std.testing.expect(try compareHeader(Codec, old, current, prefix, bit_len, 5, final, false));
    }

    const wire = try Support.encodeLargeCompressedHeader(std.testing.allocator);
    defer std.testing.allocator.free(wire);
    const prefix = try normalizedPrefix(wire, 21);
    defer std.testing.allocator.free(prefix);
    const bit_len = wire.len * 8 - 21;
    const old = try std.testing.allocator.create(Codec.ParsedHeader);
    defer std.testing.allocator.destroy(old);
    const current = try std.testing.allocator.create(Codec.Header);
    defer std.testing.allocator.destroy(current);
    try std.testing.expect(try compareHeader(Codec, old, current, prefix, bit_len, 1, true, false));
    try std.testing.expectEqual(@as(u16, 256), current.compressed.command_block.block_type_count);
    const header_bits = old.bits_read;
    try std.testing.expect(!try compareHeader(Codec, old, current, prefix, header_bits - 1, 1, true, false));
    try std.testing.expect(try compareHeader(Codec, old, current, prefix, header_bits, 1, true, false));

    try checkWindowHeader(Codec, Support, false, 24);
    try checkWindowHeader(Codec, Support, true, 30);
}

noinline fn checkWindowHeader(comptime Codec: type, comptime Support: type, comptime large: bool, width: u5) !void {
    const commands = [_]Support.HqCommand{.{ .insert_start = 0, .insert_len = 3, .copy_len = 3, .distance = 3, .has_copy = true }};
    const wire = try Support.encodeHqCommandPlan(std.testing.allocator, "abcabc", &commands, .{ .large_window = large, .window_bits = width });
    defer std.testing.allocator.free(wire.bytes);
    // WBITS24 uses 4 bits; the Large Window30 extension uses 14 bits.
    // The final meta-block prefix contributes another 20 bits in both cases.
    const skip_bits: u6 = if (large) 34 else 24;
    const prefix = try normalizedPrefix(wire.bytes, skip_bits);
    defer std.testing.allocator.free(prefix);
    const bit_len = wire.bytes.len * 8 - skip_bits;
    const old = try std.testing.allocator.create(Codec.ParsedHeader);
    defer std.testing.allocator.destroy(old);
    const current = try std.testing.allocator.create(Codec.Header);
    defer std.testing.allocator.destroy(current);
    var successful_headers: usize = 0;
    for (0..bit_len + 1) |bits| {
        if (try compareHeader(Codec, old, current, prefix, bits, 6, true, large)) successful_headers += 1;
    }
    try std.testing.expect(successful_headers > 0);
    // Metadata remains wide even when it exceeds the native 32-bit usize.
    try std.testing.expect(try compareHeader(Codec, old, current, prefix, bit_len, (@as(u64, 1) << 32) + 17, false, large));
}

pub fn normalizedPrefix(wire: []const u8, skip_bits: u6) ![]u8 {
    var reader = bitstream.BitReader.init(wire);
    // Normalize independently of either compressed-header parser.
    try reader.skipBits(skip_bits);
    const bit_len = wire.len * 8 - @as(usize, skip_bits);
    const prefix = try std.testing.allocator.alloc(u8, (bit_len + 7) / 8);
    @memset(prefix, 0);
    for (0..bit_len) |i| {
        const bit = try reader.readBits(u1, 1);
        prefix[i / 8] |= @as(u8, bit) << @intCast(i % 8);
    }
    return prefix;
}

noinline fn compareHeader(comptime Codec: type, old: *Codec.ParsedHeader, current: *Codec.Header, prefix: []const u8, bit_len: usize, decoded_len: @TypeOf(@as(Codec.Header, undefined).decoded_len), final: bool, large: bool) !bool {
    const returned = Codec.parseMetaBlockHeader(prefix, bit_len, decoded_len, final, large);
    const into = Codec.parseMetaBlockHeaderInto(prefix, bit_len, decoded_len, final, large, current);
    if (returned) |value| {
        old.* = value;
        try std.testing.expectEqual(old.bits_read, try into);
        try std.testing.expectEqual(old.header.decoded_len, current.decoded_len);
        try std.testing.expectEqual(old.header.final, current.final);
        try std.testing.expectEqual(old.header.large_window, current.large_window);
        try std.testing.expectEqual(decoded_len, current.decoded_len);
        try std.testing.expectEqual(final, current.final);
        try std.testing.expectEqual(large, current.large_window);
        try compareActiveCompressed(&old.header.compressed, &current.compressed);
        return true;
    } else |err| {
        try std.testing.expectError(err, into);
        return false;
    }
}

pub fn compareActiveCompressed(x: anytype, y: @TypeOf(x)) !void {
    try std.testing.expectEqual(x.npostfix, y.npostfix);
    try std.testing.expectEqual(x.ndirect, y.ndirect);
    try std.testing.expectEqual(x.literal_tree_count, y.literal_tree_count);
    try std.testing.expectEqual(x.distance_tree_count, y.distance_tree_count);
    inline for (.{ "literal_block", "command_block", "distance_block" }) |name| {
        const left = &@field(x, name);
        const right = &@field(y, name);
        try std.testing.expectEqual(left.block_type_count, right.block_type_count);
        try std.testing.expectEqual(left.current_type, right.current_type);
        try std.testing.expectEqual(left.previous_type, right.previous_type);
        try std.testing.expectEqual(left.remaining, right.remaining);
        if (left.block_type_count > 1) {
            try comparePrefix(&left.type_tree, &right.type_tree);
            try comparePrefix(&left.length_tree, &right.length_tree);
        }
    }
    try std.testing.expectEqualSlices(u2, x.literal_context_modes[0..x.literal_block.block_type_count], y.literal_context_modes[0..y.literal_block.block_type_count]);
    try std.testing.expectEqualSlices(u8, x.literal_context_map[0 .. @as(usize, x.literal_block.block_type_count) * 64], y.literal_context_map[0 .. @as(usize, y.literal_block.block_type_count) * 64]);
    try std.testing.expectEqualSlices(u8, x.distance_context_map[0 .. @as(usize, x.distance_block.block_type_count) * 4], y.distance_context_map[0 .. @as(usize, y.distance_block.block_type_count) * 4]);
    inline for (.{ .{ "literal_trees", "packed_literal_trees", "literal_tree_count" }, .{ "distance_trees", "packed_distance_trees", "distance_tree_count" } }) |family| {
        const inline_trees = &@field(x, family[0]);
        const other_inline_trees = &@field(y, family[0]);
        const packed_trees = &@field(x, family[1]);
        const other_packed = &@field(y, family[1]);
        for (0..@field(x, family[2])) |i| {
            if (i < inline_trees.len) try comparePrefix(&inline_trees[i], &other_inline_trees[i]) else try comparePacked(&packed_trees[i - inline_trees.len], &other_packed[i - inline_trees.len]);
        }
    }
    for (0..x.command_block.block_type_count) |i| {
        if (i < x.insert_copy_trees.len) try comparePrefix(&x.insert_copy_trees[i], &y.insert_copy_trees[i]) else try comparePacked(&x.packed_insert_copy_trees[i - x.insert_copy_trees.len], &y.packed_insert_copy_trees[i - y.insert_copy_trees.len]);
    }
    try std.testing.expectEqualSlices(u16, &x.packed_literal_cache_indices, &y.packed_literal_cache_indices);
    try std.testing.expectEqual(x.packed_literal_cache_next, y.packed_literal_cache_next);
    try std.testing.expectEqual(x.active_packed_insert_copy_tree_index, y.active_packed_insert_copy_tree_index);
    try std.testing.expectEqual(x.active_packed_distance_tree_index, y.active_packed_distance_tree_index);
}

fn comparePrefix(x: anytype, y: @TypeOf(x)) !void {
    try std.testing.expectEqual(x.single_symbol, y.single_symbol);
    if (x.single_symbol == null) {
        try std.testing.expectEqual(x.table.len, y.table.len);
        try std.testing.expectEqual(x.table.max_bits, y.table.max_bits);
        try std.testing.expectEqualSlices(@TypeOf(x.table.entries[0]), x.table.entries[0..x.table.len], y.table.entries[0..y.table.len]);
        try std.testing.expectEqualSlices(u16, &x.table.first_by_bits, &y.table.first_by_bits);
        try std.testing.expectEqualSlices(u16, &x.table.count_by_bits, &y.table.count_by_bits);
    }
}

fn comparePacked(x: anytype, y: @TypeOf(x)) !void {
    try std.testing.expectEqual(x.single_symbol_plus_one, y.single_symbol_plus_one);
    if (x.single_symbol_plus_one == 0) {
        try std.testing.expectEqual(x.active_entries, y.active_entries);
        try std.testing.expectEqualSlices(u8, &x.lengths, &y.lengths);
    }
}
