const std = @import("std");
const compact = @import("../compact_indexes.zig");
const tree = @import("../tree.zig");
const indexes = @import("../../compression_index.zig");
const archive = @import("../../archive.zig");
const format = @import("../../format.zig");

fn fixtureAlloc(text: []const u8) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const data = try std.testing.allocator.alloc(u8, decoder.calcSizeUpperBound(text.len));
    errdefer std.testing.allocator.free(data);
    return std.testing.allocator.realloc(data, try decoder.decode(data, text));
}

test "EROFS compact writer matches independent final-big index bytes" {
    const full = try fixtureAlloc(@embedFile("../../testdata/lz4-full-final-big.erofs.b64"));
    defer std.testing.allocator.free(full);
    const expected = try fixtureAlloc(@embedFile("../../testdata/lz4-compact-final-big.erofs.b64"));
    defer std.testing.allocator.free(expected);
    const parsed = try archive.Archive.init(full);
    const inode = try parsed.inode(40);
    var records: [4]tree.Node.CompressionIndex = undefined;
    for (&records, 0..) |*record, index| {
        const position = inode.compressed_index_start + index * 8;
        record.* = .{ .kind = @truncate(format.readU16(full, position)), .logical_offset = format.readU16(full, position + 2), .physical_block = format.readU32(full, position + 4) };
    }
    var data: [2048]u8 = @splat(0);
    try compact.write(&data, .{ .index_start = 1320, .cluster_bits = 12, .advise = 7, .block_size = 4096 }, &records, 1, null);
    try std.testing.expectEqualSlices(u8, expected[1320..1336], data[1320..1336]);
}

test "EROFS compact writer preserves mixed extent addresses at every pack alignment and final count" {
    for ([_]u16{ 0, 1, 6, 7 }) |advise| {
        for (0..4) |alignment| {
            for (1..71) |count| {
                var records: [70]tree.Node.CompressionIndex = undefined;
                var physical: u32 = 9;
                var logical: usize = 0;
                while (logical < count) {
                    const size = @min(@as(usize, 4), count - logical);
                    if (advise & 2 != 0 and logical / 4 % 2 != 0 and size >= 2) {
                        records[logical] = .{ .kind = 1, .physical_block = physical };
                        for (1..size) |item| {
                            const delta: u32 = if (item == 1) 0x802 else @intCast(item);
                            records[logical + item] = .{ .kind = 2, .physical_block = delta | (@as(u32, @intCast(size - item)) << 16) };
                        }
                        physical += 2;
                    } else {
                        for (0..size) |item| records[logical + item] = .{ .kind = @intCast(item % 2), .physical_block = physical + @as(u32, @intCast(item)) };
                        physical += @intCast(size);
                    }
                    logical += size;
                }
                const view = indexes.View{ .index_start = 64 + alignment * 8, .cluster_bits = 12, .advise = advise, .block_size = 4096 };
                var data: [512]u8 = @splat(0);
                try compact.write(&data, view, records[0..count], 9, null);
                for (records[0..count], 0..) |record, index| {
                    const decoded = try indexes.readCompact(&data, view, index, count);
                    try std.testing.expectEqual(record.kind, decoded.kind);
                    if (record.kind == 2) {
                        try std.testing.expectEqual(@as(?usize, if (record.physical_block & 0x800 != 0) 1 else @as(u16, @truncate(record.physical_block))), decoded.lookback);
                    } else {
                        try std.testing.expectEqual(record.physical_block, decoded.physical_block);
                    }
                }
            }
        }
    }
}

test "EROFS compact packing rejects truncated metadata invalid counts and discontinuous blocks" {
    var data: [64]u8 = @splat(0);
    const view = indexes.View{ .index_start = 8, .cluster_bits = 12, .advise = 7, .block_size = 4096 };
    var records = [_]tree.Node.CompressionIndex{ .{ .kind = 1, .physical_block = 9 }, .{ .kind = 2, .physical_block = 0x802 | (1 << 16) }, .{ .kind = 0, .physical_block = 11 } };
    try std.testing.expectError(error.InvalidErofs, compact.write(data[0..15], view, &records, 9, null));
    for ([_]u32{ 0, 0x800, 0x901 }) |bad| {
        records[1].physical_block = bad;
        try std.testing.expectError(error.InvalidErofs, compact.write(&data, view, &records, 9, null));
    }
    records[1].physical_block = 0x802 | (1 << 16);
    records[2].physical_block = 12;
    try std.testing.expectError(error.InvalidErofs, compact.write(&data, view, &records, 9, null));
    records[2].physical_block = 0;
    try compact.write(&data, view, &records, 9, 2);
    try std.testing.expectError(error.IntegerOverflow, compact.write(&data, view, &records, std.math.maxInt(u32), 0));
}
