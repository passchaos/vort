const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const allocator = std.testing.allocator;

test "WUX writer deduplicates sectors and round trips ranges" {
    const sector_size = 4096;
    const input = try allocator.alloc(u8, 3 * sector_size + 137);
    defer allocator.free(input);
    @memset(input, 0);
    for (input[0..sector_size], 0..) |*byte, index|
        byte.* = @truncate(index * 17 + index / 31);
    @memcpy(input[2 * sector_size .. 3 * sector_size], input[0..sector_size]);
    for (input[3 * sector_size ..], 0..) |*byte, index|
        byte.* = @truncate(index * 29 + 7);

    const encoded = try writer.encodeAlloc(allocator, input, .{
        .sector_size = sector_size,
    });
    defer allocator.free(encoded);
    try std.testing.expectEqual(@as(usize, 4 * sector_size), encoded.len);
    var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
    defer archive.deinit();
    try std.testing.expectEqual(@as(usize, 4), archive.header.sector_count);
    try std.testing.expectEqual(@as(usize, 3), archive.header.unique_sector_count);
    try std.testing.expectEqual(@as(u32, 0), archive.index_table[0]);
    try std.testing.expectEqual(@as(u32, 1), archive.index_table[1]);
    try std.testing.expectEqual(@as(u32, 0), archive.index_table[2]);
    try std.testing.expectEqual(@as(u32, 2), archive.index_table[3]);
    const decoded = try archive.decodeAllocLimited(allocator, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);

    const range_offset = sector_size - 37;
    const range_length = 2 * sector_size + 91;
    const range = try archive.readRangeAllocLimited(
        allocator,
        range_offset,
        range_length,
        range_length,
    );
    defer allocator.free(range);
    try std.testing.expectEqualSlices(
        u8,
        input[range_offset..][0..range_length],
        range,
    );
}

test "WUX writer supports non-deduplicated and empty images" {
    const sector_size = 4096;
    const input = [_]u8{0} ** (2 * sector_size);
    const full = try writer.encodeAlloc(allocator, &input, .{
        .sector_size = sector_size,
        .deduplicate = false,
    });
    defer allocator.free(full);
    try std.testing.expectEqual(@as(usize, 3 * sector_size), full.len);
    var full_archive = try archive_mod.Archive.initAlloc(allocator, full, .{});
    defer full_archive.deinit();
    try std.testing.expectEqual(@as(usize, 2), full_archive.header.unique_sector_count);

    const empty = try writer.encodeAlloc(allocator, "", .{
        .sector_size = sector_size,
    });
    defer allocator.free(empty);
    try std.testing.expectEqual(@as(usize, sector_size), empty.len);
    var empty_archive = try archive_mod.Archive.initAlloc(allocator, empty, .{});
    defer empty_archive.deinit();
    try std.testing.expectEqual(@as(u64, 0), empty_archive.header.logical_size);
    try std.testing.expectEqual(@as(usize, 0), empty_archive.index_table.len);
}

test "WUX rejects malformed headers tables and limits" {
    const input = "WUX malformed regression payload\n" ** 256;
    const encoded = try writer.encodeAlloc(allocator, input, .{
        .sector_size = 4096,
    });
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        writer.encodeAlloc(allocator, input, .{
            .sector_size = 4096,
            .max_output_len = encoded.len - 1,
        }),
    );

    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    corrupt[0] ^= 1;
    try std.testing.expectError(
        error.InvalidMagic,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    @memcpy(corrupt, encoded);
    format.writeU32Le(corrupt, 24, 1);
    try std.testing.expectError(
        error.UnsupportedWuxFeature,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    @memcpy(corrupt, encoded);
    format.writeU32Le(corrupt, format.header_size, 99);
    try std.testing.expectError(
        error.InvalidWux,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    try std.testing.expectError(
        error.SizeMismatch,
        archive_mod.Archive.initAlloc(
            allocator,
            encoded[0 .. encoded.len - 1],
            .{},
        ),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive_mod.Archive.initAlloc(
            allocator,
            encoded,
            .{ .max_sectors = 0 },
        ),
    );
}
