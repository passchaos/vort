const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const allocator = std.testing.allocator;

test "WBFS sparse writer round trips ranges and split files" {
    const cluster_size = 2 * 1024 * 1024;
    const input = try allocator.alloc(u8, 3 * cluster_size + 137);
    defer allocator.free(input);
    @memset(input, 0);
    for (input[0..cluster_size], 0..) |*byte, index|
        byte.* = @truncate(index * 17 + index / 31);
    for (input[2 * cluster_size .. 3 * cluster_size], 0..) |*byte, index|
        byte.* = "WBFS sparse cluster\n"[index % 20];
    for (input[3 * cluster_size ..], 0..) |*byte, index|
        byte.* = @truncate(index * 29 + 7);

    const encoded = try writer.encodeAlloc(allocator, input, .{});
    defer allocator.free(encoded);
    try std.testing.expectEqual(@as(usize, 4 * cluster_size), encoded.len);
    var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
    defer archive.deinit();
    try std.testing.expectEqual(@as(usize, cluster_size), archive.header.wbfs_sector_size);
    try std.testing.expectEqual(@as(u16, 1), archive.wlba_table[0]);
    try std.testing.expectEqual(@as(u16, 0), archive.wlba_table[1]);
    try std.testing.expectEqual(@as(u16, 2), archive.wlba_table[2]);
    try std.testing.expectEqual(@as(u16, 3), archive.wlba_table[3]);

    const range_offset = cluster_size - 31;
    const range_length = 2 * cluster_size + 97;
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
    const tail = try archive.readRangeAllocLimited(
        allocator,
        input.len + 4096,
        4096,
        4096,
    );
    defer allocator.free(tail);
    try std.testing.expect(std.mem.allEqual(u8, tail, 0));

    const first_split = 12345;
    const second_split = 3 * cluster_size + 71;
    var split = try archive_mod.Archive.initPartsAlloc(
        allocator,
        &.{
            encoded[0..first_split],
            encoded[first_split..second_split],
            encoded[second_split..],
        },
        .{},
    );
    defer split.deinit();
    const split_range = try split.readRangeAllocLimited(
        allocator,
        range_offset,
        range_length,
        range_length,
    );
    defer allocator.free(split_range);
    try std.testing.expectEqualSlices(u8, range, split_range);
}

test "WBFS writer can retain zero clusters" {
    const cluster_size = 2 * 1024 * 1024;
    const input = try allocator.alloc(u8, 2 * cluster_size);
    defer allocator.free(input);
    @memset(input, 0);
    input[0] = 'W';
    const encoded = try writer.encodeAlloc(allocator, input, .{
        .sparse_zero_clusters = false,
    });
    defer allocator.free(encoded);
    try std.testing.expectEqual(@as(usize, 3 * cluster_size), encoded.len);
    var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
    defer archive.deinit();
    try std.testing.expectEqual(@as(u16, 1), archive.wlba_table[0]);
    try std.testing.expectEqual(@as(u16, 2), archive.wlba_table[1]);
}

test "WBFS rejects malformed headers maps and limits" {
    const input = [_]u8{0x5a} ** format.disc_header_size;
    const encoded = try writer.encodeAlloc(allocator, &input, .{});
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        writer.encodeAlloc(allocator, &input, .{ .max_output_len = encoded.len - 1 }),
    );

    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    corrupt[0] ^= 1;
    try std.testing.expectError(
        error.InvalidMagic,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    @memcpy(corrupt, encoded);
    corrupt[12] = 0;
    try std.testing.expectError(
        error.InvalidWbfs,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    @memcpy(corrupt, encoded);
    format.writeU16Be(corrupt, 512 + format.disc_header_size, 2);
    try std.testing.expectError(
        error.InvalidWbfs,
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
        archive_mod.Archive.initPartsAlloc(
            allocator,
            &.{ encoded[0..1], encoded[1..] },
            .{ .max_parts = 1 },
        ),
    );
}
