const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const allocator = std.testing.allocator;

test "WDF1 and WDF2 sparse writers round trip chunks holes and splits" {
    const block = 64 * 1024;
    const input = try allocator.alloc(u8, 3 * block + 137);
    defer allocator.free(input);
    @memset(input, 0);
    for (input[0..block], 0..) |*byte, index|
        byte.* = @truncate(index * 17 + index / 31);
    for (input[2 * block .. 3 * block], 0..) |*byte, index|
        byte.* = "WDF sparse data\n"[index % 16];
    for (input[3 * block ..], 0..) |*byte, index|
        byte.* = @truncate(index * 29 + 3);

    inline for (.{ format.Version.v1, format.Version.v2 }) |version| {
        const encoded = try writer.encodeAlloc(allocator, input, .{
            .version = version,
        });
        defer allocator.free(encoded);
        var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
        defer archive.deinit();
        try std.testing.expectEqual(version, archive.header.version);
        try std.testing.expectEqual(@as(usize, 2), archive.chunks.len);
        const decoded = try archive.decodeAllocLimited(allocator, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);

        const range_offset = block - 37;
        const range_length = 2 * block + 91;
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

        const first_split = 73;
        const second_split = encoded.len - 41;
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
}

test "WDF writer handles all-zero and non-sparse inputs" {
    const input = [_]u8{0} ** 4099;
    const sparse = try writer.encodeAlloc(allocator, &input, .{});
    defer allocator.free(sparse);
    var sparse_archive = try archive_mod.Archive.initAlloc(
        allocator,
        sparse,
        .{},
    );
    defer sparse_archive.deinit();
    try std.testing.expectEqual(@as(usize, 1), sparse_archive.chunks.len);
    try std.testing.expectEqual(@as(u64, 0), sparse_archive.chunks[0].data_size);
    const sparse_decoded = try sparse_archive.decodeAllocLimited(
        allocator,
        input.len,
    );
    defer allocator.free(sparse_decoded);
    try std.testing.expectEqualSlices(u8, &input, sparse_decoded);

    const full = try writer.encodeAlloc(allocator, &input, .{
        .sparse_zeroes = false,
    });
    defer allocator.free(full);
    var full_archive = try archive_mod.Archive.initAlloc(allocator, full, .{});
    defer full_archive.deinit();
    try std.testing.expectEqual(@as(usize, 1), full_archive.chunks.len);
    try std.testing.expectEqual(@as(u64, 4100), full_archive.chunks[0].data_size);
}

test "WDF rejects malformed headers tables and limits" {
    const input = "WDF malformed regression payload\n" ** 128;
    const encoded = try writer.encodeAlloc(allocator, input, .{});
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        writer.encodeAlloc(allocator, input, .{
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
    format.writeU32Be(corrupt, 8, 3);
    try std.testing.expectError(
        error.UnsupportedVersion,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    @memcpy(corrupt, encoded);
    const table_offset: usize = @intCast(format.readU64Be(corrupt, 48));
    corrupt[table_offset] ^= 1;
    try std.testing.expectError(
        error.InvalidWdf,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );

    const trailing = try allocator.alloc(u8, encoded.len + 1);
    defer allocator.free(trailing);
    @memcpy(trailing[0..encoded.len], encoded);
    trailing[encoded.len] = 0;
    try std.testing.expectError(
        error.TrailingData,
        archive_mod.Archive.initAlloc(allocator, trailing, .{}),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive_mod.Archive.initAlloc(
            allocator,
            encoded,
            .{ .max_chunks = 0 },
        ),
    );

    const v1 = try writer.encodeAlloc(allocator, input, .{ .version = .v1 });
    defer allocator.free(v1);
    const old_v1 = try allocator.dupe(u8, v1);
    defer allocator.free(old_v1);
    format.writeU32Be(old_v1, 12, 0x1234_5678);
    var old_archive = try archive_mod.Archive.initAlloc(allocator, old_v1, .{});
    defer old_archive.deinit();
    try std.testing.expectEqual(@as(u32, format.header_size), old_archive.header.head_size);
    try std.testing.expectEqual(@as(u32, 0), old_archive.header.align_factor);
}
