const std = @import("std");
const writer = @import("../../writer.zig");
const archive_module = @import("../../archive.zig");
const sink_module = @import("../../../io/sink.zig");

test "EROFS slice streaming extraction preserves every codec layout and range" {
    const allocator = std.testing.allocator;
    const data = "slice streaming common core bytes\n" ** 600;
    for ([_]writer.Compression{ .stored, .lz4, .lzma, .deflate, .zstandard }) |compression| {
        for ([_]writer.Options{
            .{},
            .{ .tail_packing = .fragments },
            .{ .tail_packing = .compressed_inline },
            .{ .compression_extent_size = 32768, .max_pcluster_size = 8192 },
            .{ .metabox = true, .compress_directories = true },
        }, 0..) |variant, index| {
            if (compression == .stored and index != 0) continue;
            var options = variant;
            options.compression = compression;
            const image = try writer.encodeAlloc(allocator, &.{.{ .path = "dir/data", .data = data }}, options);
            defer allocator.free(image);
            const base = try archive_module.Archive.init(image);
            var loaded = if (options.metabox) try base.loadMetaboxAllocLimited(allocator, 1024 * 1024, 1024 * 1024) else null;
            defer if (loaded) |*owner| owner.deinit();
            const archive = if (loaded) |owner| owner.archive else base;
            var reader = try archive.initPathExtractor(allocator, "dir/data", .{ .max_output_len = data.len }, 4096);
            defer reader.deinit();
            var buffer: [113]u8 = undefined;
            var position: usize = 0;
            try std.testing.expectEqual(@as(usize, 0), (try reader.read(buffer[0..0])).output_written);
            while (true) {
                const progress = try reader.read(&buffer);
                try std.testing.expectEqualSlices(u8, data[position..][0..progress.output_written], buffer[0..progress.output_written]);
                position += progress.output_written;
                try std.testing.expectEqual(position, reader.position());
                if (progress.status == .done) break;
            }
            try std.testing.expectEqual(data.len, position);
            const inode = try archive.lookup(allocator, "dir/data", data.len, 4096);
            var output = sink_module.BufferSink.init(allocator);
            defer output.deinit();
            _ = try archive.readRangeToSink(allocator, inode, 4093, 2000, output.sink(), .{ .max_output_len = 2000 });
            try std.testing.expectEqualSlices(u8, data[4093..6093], output.bytes.items);
        }
    }
}

test "EROFS slice directory and extraction allocation failures release shared-core state" {
    const allocator = std.testing.allocator;
    const data = "slice allocator regression payload\n" ** 800;
    const image = try writer.encodeAlloc(allocator, &.{.{ .path = "dir/data", .data = data }}, .{ .compression = .lzma, .compression_extent_size = 32768, .compress_directories = true });
    defer allocator.free(image);
    const Test = struct {
        fn run(work: std.mem.Allocator, bytes: []const u8, expected: []const u8) !void {
            const archive = try archive_module.Archive.init(bytes);
            var listing = try archive.initDirectoryIterator(work, try archive.rootInode(), 4096);
            defer listing.deinit();
            while (try listing.next()) |_| {}
            var reader = try archive.initPathExtractor(work, "dir/data", .{ .max_output_len = expected.len }, 4096);
            defer reader.deinit();
            var buffer: [137]u8 = undefined;
            var position: usize = 0;
            while (true) {
                const progress = try reader.read(&buffer);
                try std.testing.expectEqualSlices(u8, expected[position..][0..progress.output_written], buffer[0..progress.output_written]);
                position += progress.output_written;
                if (progress.status == .done) break;
            }
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ image, data });
}
