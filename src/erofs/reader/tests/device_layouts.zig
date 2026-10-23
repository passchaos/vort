const std = @import("std");
const writer = @import("../../writer.zig");
const archive_module = @import("../../archive.zig");
const source_archive = @import("../../source_archive.zig");
const source_module = @import("../../../io/source.zig");
const sink_module = @import("../../../io/sink.zig");
const helpers = @import("helpers.zig");
const fixture = @import("device_helpers.zig");
const partial = @import("partial_helpers.zig");

fn verify(owner: *const fixture.Owner, inode: archive_module.Inode, expected: []const u8) !void {
    const allocator = std.testing.allocator;
    const slice = try archive_module.Archive.initWithDevices(owner.image, &.{owner.blob});
    const data = try slice.readFlatAllocLimited(allocator, inode, expected.len);
    defer allocator.free(data);
    try std.testing.expectEqualSlices(u8, expected, data);
    var primary = helpers.Input{ .bytes = owner.image };
    var device = helpers.Input{ .bytes = owner.blob };
    const sources = [_]source_module.Source{device.source()};
    var archive = try source_archive.SourceArchive.initWithDevices(allocator, primary.source(), &sources, .{ .max_working_memory = 2 * 1024 * 1024 });
    defer archive.deinit();
    var reader = try archive.initExtractor(inode, .{ .max_output_len = expected.len });
    defer reader.deinit();
    var output: [31]u8 = undefined;
    var position: usize = 0;
    while (true) {
        const progress = try reader.read(&output);
        try std.testing.expectEqualSlices(u8, expected[position..][0..progress.output_written], output[0..progress.output_written]);
        position += progress.output_written;
        if (progress.status == .done) break;
    }
    try std.testing.expectEqual(expected.len, position);
    for ([_]usize{ 0, expected.len / 2, expected.len - 1 }) |start| {
        const size = @min(11, expected.len - start);
        var sink = sink_module.BufferSink.init(allocator);
        defer sink.deinit();
        _ = try archive.readRangeToSink(inode, start, size, sink.sink(), .{ .max_output_len = size });
        try std.testing.expectEqualSlices(u8, expected[start..][0..size], sink.bytes.items);
    }
    try std.testing.expect(primary.max_request <= 31 and device.max_request <= 31);
}

test "EROFS modern external extents map byte offsets across all record sizes and codecs" {
    const allocator = std.testing.allocator;
    for (partial.algorithms, 0..) |_, index| {
        const full = try partial.fullPrefixAlloc(allocator, index);
        defer allocator.free(full);
        for ([_]u8{ 4, 8, 16, 32 }) |size| {
            for ([_]usize{ 0, 3, 4093 }) |within| {
                var owner = try fixture.modern(allocator, index, size, within);
                defer owner.deinit(allocator);
                const base = try archive_module.Archive.init(owner.image);
                const inode = try base.inode(96);
                try verify(&owner, inode, full[0..17]);
                try std.testing.expectError(error.ErofsMissingDevice, base.readFlatAllocLimited(allocator, inode, 17));
            }
        }
    }
}

test "EROFS flat full-index packed and metabox data use the same external device core" {
    const allocator = std.testing.allocator;
    const data = "external device common reading payload\n" ** 600;
    for ([_]writer.Compression{ .stored, .lz4, .lzma, .deflate, .zstandard }) |compression| {
        for ([_]u8{ 0, 1, 2, 3 }) |variant| {
            if (compression == .stored and (variant == 1 or variant == 3)) continue;
            const options = writer.Options{
                .compression = compression,
                .compression_extent_size = if (compression == .stored) 4096 else 32768,
                .tail_packing = if (variant == 1) .fragments else .none,
                .metabox = variant == 2,
                .compress_directories = variant == 3,
            };
            const image = try writer.encodeAlloc(allocator, &.{.{ .path = "file", .data = data }}, options);
            defer allocator.free(image);
            const base = try archive_module.Archive.init(image);
            const value = if (variant == 2) try base.inode(base.superblock.metabox_nid) else if (variant == 3) try base.rootInode() else try base.lookup(allocator, "file", data.len, 4096);
            var owner = try fixture.offload(allocator, image, value, 0);
            defer owner.deinit(allocator);
            if (variant == 2 or variant == 3) {
                var primary = helpers.Input{ .bytes = owner.image };
                var device = helpers.Input{ .bytes = owner.blob };
                const sources = [_]source_module.Source{device.source()};
                var archive = try source_archive.SourceArchive.initWithDevices(allocator, primary.source(), &sources, .{});
                defer archive.deinit();
                const decoded = try archive.extractByPathAllocLimited(allocator, "file", data.len, 4096);
                defer allocator.free(decoded);
                try std.testing.expectEqualStrings(data, decoded);
                try std.testing.expect(device.calls != 0);
                const slice_base = try archive_module.Archive.initWithDevices(owner.image, &.{owner.blob});
                var loaded = if (variant == 2) try slice_base.loadMetaboxAllocLimited(allocator, 1024 * 1024, 1024 * 1024) else null;
                defer if (loaded) |*owned| owned.deinit();
                const slice = if (loaded) |owned| owned.archive else slice_base;
                const result = try slice.extractByPathAllocLimited(allocator, "file", data.len, 4096);
                defer allocator.free(result);
                try std.testing.expectEqualStrings(data, result);
            } else {
                const mapped = try archive_module.Archive.initWithDevices(owner.image, &.{owner.blob});
                try verify(&owner, try mapped.lookup(allocator, "file", data.len, 4096), data);
            }
        }
    }
}
