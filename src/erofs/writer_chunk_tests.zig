const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const Archive = archive_mod.Archive;
const Entry = writer.Entry;
const block_size: usize = 4096;

const first_data = ("A" ** 4096) ++ ("B" ** 4096);
const second_data = ("A" ** 4096) ++ ("\x00" ** 4096) ++ "tail";

test "EROFS local chunk writer deduplicates data and writes holes" {
    const allocator = std.testing.allocator;
    const entries = [_]Entry{
        .{ .path = "first", .data = first_data },
        .{
            .path = "second",
            .data = second_data,
            .xattrs = &.{.{ .name = "user.chunk", .value = "local" }},
        },
    };
    const encoded = try writer.encodeAlloc(allocator, &entries, .{ .chunk_size = block_size });
    defer allocator.free(encoded);
    const repeated = try writer.encodeAlloc(allocator, &entries, .{ .chunk_size = block_size });
    defer allocator.free(repeated);
    try std.testing.expectEqualSlices(u8, encoded, repeated);

    const archive = try Archive.init(encoded);
    try std.testing.expect(
        archive.superblock.feature_incompat & format.feature_incompat_chunked_file != 0,
    );
    try std.testing.expectEqual(@as(u16, 0), archive.superblock.extra_devices);
    const first_inode = try archive.lookup(allocator, "first", first_data.len, block_size);
    const second_inode = try archive.lookup(allocator, "second", second_data.len, block_size);
    try std.testing.expectEqual(format.Layout.chunk_based, first_inode.layout);
    try std.testing.expectEqual(@as(u8, 4), first_inode.chunk_index_size);
    try std.testing.expectEqual(
        format.readU32(encoded, first_inode.chunk_index_start),
        format.readU32(encoded, second_inode.chunk_index_start),
    );
    try std.testing.expectEqual(
        std.math.maxInt(u32),
        format.readU32(encoded, second_inode.chunk_index_start + 4),
    );
    const first = try archive.readFlatAllocLimited(allocator, first_inode, first_data.len);
    defer allocator.free(first);
    try std.testing.expectEqualSlices(u8, first_data, first);
    const second = try archive.readFlatAllocLimited(allocator, second_inode, second_data.len);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, second_data, second);
    var xattrs = try archive.readXattrsAllocLimited(allocator, second_inode, 1, 32);
    defer xattrs.deinit();
    try std.testing.expectEqualStrings("local", xattrs.find("user.chunk").?.value);
}

test "EROFS external chunk writer returns owning metadata and device" {
    const allocator = std.testing.allocator;
    const entries = [_]Entry{
        .{ .path = "first", .data = first_data },
        .{ .path = "second", .data = second_data },
    };
    var encoded = try writer.encodeExternalChunksAlloc(
        allocator,
        &entries,
        .{ .chunk_size = block_size },
    );
    defer encoded.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 3 * block_size), encoded.device.len);

    const metadata = try Archive.init(encoded.image);
    try std.testing.expectEqual(@as(u16, 1), metadata.superblock.extra_devices);
    const missing_inode = try metadata.lookup(allocator, "first", first_data.len, block_size);
    try std.testing.expectError(
        error.ErofsMissingDevice,
        metadata.readFlatAllocLimited(allocator, missing_inode, first_data.len),
    );

    const archive = try Archive.initWithDevices(encoded.image, &.{encoded.device});
    const info = try archive.deviceInfo(0);
    try std.testing.expectEqual(@as(u64, 3), info.blocks);
    try std.testing.expectEqual(archive.superblock.block_count, info.unified_start);
    const first_inode = try archive.lookup(allocator, "first", first_data.len, block_size);
    const second_inode = try archive.lookup(allocator, "second", second_data.len, block_size);
    try std.testing.expectEqual(@as(u8, 8), first_inode.chunk_index_size);
    try std.testing.expectEqual(@as(u16, 1), format.readU16(
        encoded.image,
        first_inode.chunk_index_start + 2,
    ));
    try std.testing.expectEqual(
        format.readU32(encoded.image, first_inode.chunk_index_start + 4),
        format.readU32(encoded.image, second_inode.chunk_index_start + 4),
    );
    const first = try archive.readFlatAllocLimited(allocator, first_inode, first_data.len);
    defer allocator.free(first);
    try std.testing.expectEqualSlices(u8, first_data, first);
    const second = try archive.readFlatAllocLimited(allocator, second_inode, second_data.len);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, second_data, second);
}

test "EROFS chunk writer validates options and releases allocation failures" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidErofs,
        writer.encodeAlloc(allocator, &.{.{ .path = "file", .data = "x" }}, .{
            .chunk_size = 2048,
        }),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        writer.encodeAlloc(allocator, &.{.{ .path = "file", .data = "x" }}, .{
            .compression = .lz4,
            .chunk_size = 4096,
        }),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        writer.encodeExternalChunksAlloc(allocator, &.{}, .{}),
    );
    var empty_external = try writer.encodeExternalChunksAlloc(
        allocator,
        &.{},
        .{ .chunk_size = block_size },
    );
    defer empty_external.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), empty_external.device.len);
    _ = try Archive.initWithDevices(empty_external.image, &.{empty_external.device});
    var zero_chunk: [block_size]u8 = @splat(0);
    var all_holes = try writer.encodeExternalChunksAlloc(
        allocator,
        &.{.{ .path = "hole", .data = &zero_chunk }},
        .{ .chunk_size = block_size },
    );
    defer all_holes.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), all_holes.device.len);
    const hole_archive = try Archive.initWithDevices(
        all_holes.image,
        &.{all_holes.device},
    );
    const hole = try hole_archive.extractByPathAllocLimited(
        allocator,
        "hole",
        block_size,
        block_size,
    );
    defer allocator.free(hole);
    try std.testing.expectEqualSlices(u8, &zero_chunk, hole);

    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator) !void {
            const entries = [_]Entry{
                .{ .path = "first", .data = first_data },
                .{ .path = "second", .data = second_data },
            };
            const local = try writer.encodeAlloc(
                failing_allocator,
                &entries,
                .{ .chunk_size = block_size },
            );
            defer failing_allocator.free(local);
            const local_archive = try Archive.init(local);
            const local_decoded = try local_archive.extractByPathAllocLimited(
                failing_allocator,
                "second",
                second_data.len,
                block_size,
            );
            defer failing_allocator.free(local_decoded);

            var external = try writer.encodeExternalChunksAlloc(
                failing_allocator,
                &entries,
                .{ .chunk_size = block_size },
            );
            defer external.deinit(failing_allocator);
            const external_archive = try Archive.initWithDevices(
                external.image,
                &.{external.device},
            );
            const external_decoded = try external_archive.extractByPathAllocLimited(
                failing_allocator,
                "first",
                first_data.len,
                block_size,
            );
            defer failing_allocator.free(external_decoded);
            try std.testing.expectEqualSlices(u8, first_data, external_decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}
