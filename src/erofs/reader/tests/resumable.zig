const std = @import("std");
const writer = @import("../../writer.zig");
const source_archive = @import("../../source_archive.zig");
const helpers = @import("helpers.zig");
const format = @import("../../format.zig");
const archive_module = @import("../../archive.zig");

fn checkSchedule(archive: *source_archive.SourceArchive, path: []const u8, expected: []const u8) !void {
    const allocator = std.testing.allocator;
    var extractor = try archive.initPathExtractor(path, .{ .max_output_len = 1024 * 1024 }, 4096);
    defer extractor.deinit();
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(allocator);
    var buffer: [137]u8 = undefined;
    const initial = try extractor.read(buffer[0..0]);
    try std.testing.expectEqual(@as(usize, 0), initial.output_written);
    var step: usize = 0;
    while (true) {
        const capacity = ([_]usize{ 1, 7, 0, 31, 137, 3 })[step % 6];
        const progress = try extractor.read(buffer[0..capacity]);
        try std.testing.expect(progress.output_written <= capacity);
        try result.appendSlice(allocator, buffer[0..progress.output_written]);
        try std.testing.expectEqual(result.items.len, progress.position);
        try std.testing.expectEqual(result.items.len, extractor.position());
        if (progress.status == .done) break;
        if (capacity != 0) try std.testing.expect(progress.output_written != 0);
        step += 1;
    }
    try std.testing.expectEqualSlices(u8, expected, result.items);
    try std.testing.expectEqual(@as(usize, 0), (try extractor.read(&buffer)).output_written);
}

test "EROFS resumable extraction matches decoded files across codecs and layouts" {
    const allocator = std.testing.allocator;
    const data = "resumable metadata and payload 0123456789\n" ** 450;
    const entries = [_]writer.Entry{
        .{ .path = "dir/data", .data = data },
        .{ .path = "tiny", .data = "T" },
        .{ .path = "empty" },
        .{ .path = "link", .kind = .symlink, .target = "dir/data" },
    };
    for ([_]writer.Compression{ .stored, .lz4, .lzma, .deflate, .zstandard }) |compression| {
        for ([_]writer.Options{
            .{},
            .{ .compression_extent_size = 32768, .max_pcluster_size = 8192 },
            .{ .tail_packing = .fragments },
            .{ .tail_packing = .compressed_inline },
            .{ .metabox = true, .compress_directories = true },
        }, 0..) |variant, index| {
            if (compression == .stored and index != 0) continue;
            var options = variant;
            options.compression = compression;
            options.force_48bit = true;
            const image = try writer.encodeAlloc(allocator, &entries, options);
            defer allocator.free(image);
            var input = helpers.Input{ .bytes = image };
            var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{});
            defer archive.deinit();
            for (entries) |entry| {
                const expected = if (entry.kind == .symlink) entry.target else entry.data;
                try checkSchedule(&archive, entry.path, expected);
            }
        }
    }
}

test "EROFS resumable extraction maps chunk holes external devices and partial ranges" {
    const allocator = std.testing.allocator;
    const data = "chunk reader resumable byte sequence\n" ** 600;
    const entries = [_]writer.Entry{
        .{ .path = "data", .data = data },
        .{ .path = "hole", .data = &([_]u8{0} ** 8192) },
    };
    var encoded = try writer.encodeExternalChunksAlloc(allocator, &entries, .{ .chunk_size = 4096, .force_48bit = true });
    defer encoded.deinit(allocator);
    var input = helpers.Input{ .bytes = encoded.image };
    var device = helpers.Input{ .bytes = encoded.device };
    const devices = [_]@import("../../../io/source.zig").Source{device.source()};
    var archive = try source_archive.SourceArchive.initWithDevices(allocator, input.source(), &devices, .{});
    defer archive.deinit();
    for (entries) |entry| try checkSchedule(&archive, entry.path, entry.data);
    const inode = try archive.lookup("data", data.len, 4096);
    var extractor = try archive.initRangeExtractor(inode, 4093, 4100, .{ .max_output_len = 4100 });
    defer extractor.deinit();
    var actual: [4100]u8 = undefined;
    var position: usize = 0;
    while (true) {
        const progress = try extractor.read(actual[position..@min(actual.len, position + 11)]);
        position += progress.output_written;
        if (progress.status == .done) break;
    }
    try std.testing.expectEqualSlices(u8, data[4093..8193], &actual);
}

test "EROFS resumable extraction caches one extent and releases it on cancellation" {
    const allocator = std.testing.allocator;
    const data = "cached decoded extent bytes 0123456789\n" ** 1400;
    const image = try writer.encodeAlloc(allocator, &.{.{ .path = "data", .data = data }}, .{ .compression = .lz4, .compression_extent_size = 65536 });
    defer allocator.free(image);
    var input = helpers.Input{ .bytes = image };
    var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{});
    defer archive.deinit();
    var extractor = try archive.initPathExtractor("data", .{ .max_output_len = data.len }, 4096);
    const before = input.calls;
    const peak = archive.peakWorkingBytes();
    var buffer: [17]u8 = @splat(0xaa);
    try std.testing.expectEqual(@as(usize, 0), (try extractor.read(buffer[0..0])).output_written);
    try std.testing.expectEqual(before, input.calls);
    try std.testing.expectEqual(peak, archive.peakWorkingBytes());
    try std.testing.expectEqual(@as(usize, 1), (try extractor.read(buffer[0..1])).output_written);
    const calls = input.calls;
    const live = archive.working.live;
    try std.testing.expect(live >= data.len);
    try std.testing.expectEqual(@as(usize, 17), (try extractor.read(&buffer)).output_written);
    try std.testing.expectEqualSlices(u8, data[1..18], &buffer);
    try std.testing.expectEqual(calls, input.calls);
    try std.testing.expectEqual(live, archive.working.live);
    try std.testing.expectEqual(@as(usize, 1), archive.active_extractors);
    extractor.deinit();
    try std.testing.expectEqual(@as(usize, 0), archive.working.live);
    try std.testing.expectEqual(@as(usize, 0), archive.active_extractors);
}

test "EROFS resumable raw read failures leave output unchanged and remain sticky" {
    const allocator = std.testing.allocator;
    const image = try writer.encodeAlloc(allocator, &.{.{ .path = "data", .data = "D" ** 8192 }}, .{});
    defer allocator.free(image);
    var input = helpers.Input{ .bytes = image };
    var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{});
    defer archive.deinit();
    const inode = try archive.lookup("data", 8192, 4096);
    var extractor = try archive.initExtractor(inode, .{ .max_output_len = 8192 });
    defer extractor.deinit();
    input.fail_from_offset = inode.data_block * archive.superblock.block_size + 7;
    var buffer: [128]u8 = @splat(0xaa);
    try std.testing.expectError(error.SourceReadFailed, extractor.read(&buffer));
    for (buffer) |byte| try std.testing.expectEqual(@as(u8, 0xaa), byte);
    try std.testing.expectEqual(@as(usize, 0), extractor.position());
    const calls = input.calls;
    input.fail_from_offset = null;
    try std.testing.expectError(error.SourceReadFailed, extractor.read(&buffer));
    try std.testing.expectEqual(calls, input.calls);
    try std.testing.expectEqual(@as(usize, 0), archive.working.live);
}

test "EROFS resumable budget errors preserve classification across later archive calls" {
    const allocator = std.testing.allocator;
    const data = "budgeted extent\n" ** 4000;
    const image = try writer.encodeAlloc(allocator, &.{.{ .path = "data", .data = data }}, .{ .compression = .lz4, .compression_extent_size = 65536 });
    defer allocator.free(image);
    var input = helpers.Input{ .bytes = image };
    var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 32768 });
    defer archive.deinit();
    var extractor = try archive.initPathExtractor("data", .{ .max_output_len = data.len }, 4096);
    defer extractor.deinit();
    var buffer: [8]u8 = @splat(0xbb);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, extractor.read(&buffer));
    for (buffer) |byte| try std.testing.expectEqual(@as(u8, 0xbb), byte);
    _ = try archive.lookup("data", data.len, 4096);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, extractor.read(&buffer));
    try std.testing.expectEqual(@as(usize, 0), archive.working.live);
}

test "EROFS resumable final metadata validation can fail after delivering the range" {
    const allocator = std.testing.allocator;
    const data = "D" ** 16384;
    const image = try writer.encodeAlloc(allocator, &.{.{ .path = "data", .data = data }}, .{ .compression = .lz4 });
    defer allocator.free(image);
    const reference = try archive_module.Archive.init(image);
    const inode = try reference.lookup(allocator, "data", data.len, 4096);
    const corrupt = inode.compressed_index_start + 2 * 8 + 2;
    std.mem.writeInt(u16, image[corrupt..][0..2], 4096, .little);
    std.mem.writeInt(u32, image[1028..1032], format.computeSuperblockChecksum(image[1024..reference.superblock.block_size]), .little);
    var input = helpers.Input{ .bytes = image };
    var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{});
    defer archive.deinit();
    const value = try archive.lookup("data", data.len, 4096);
    var extractor = try archive.initRangeExtractor(value, 0, 1, .{ .max_output_len = 1 });
    defer extractor.deinit();
    var buffer: [1]u8 = @splat(0);
    const first = try extractor.read(&buffer);
    try std.testing.expectEqual(@as(usize, 1), first.output_written);
    try std.testing.expectEqual(@as(u8, 'D'), buffer[0]);
    try std.testing.expectError(error.InvalidErofs, extractor.read(buffer[0..0]));
    try std.testing.expectEqual(@as(usize, 1), extractor.position());
}

test "EROFS resumable extractor releases every lookup and cached decoder allocation failure" {
    const allocator = std.testing.allocator;
    const data = "resumable allocation-failure payload\n" ** 800;
    const Test = struct {
        fn run(work: std.mem.Allocator, image: []const u8, expected: []const u8) !void {
            var input = helpers.Input{ .bytes = image };
            var archive = try source_archive.SourceArchive.init(work, input.source(), .{});
            defer archive.deinit();
            var extractor = try archive.initPathExtractor("dir/data", .{ .max_output_len = expected.len }, 4096);
            defer extractor.deinit();
            var buffer: [113]u8 = undefined;
            var position: usize = 0;
            while (true) {
                const progress = try extractor.read(&buffer);
                try std.testing.expectEqualSlices(u8, expected[position..][0..progress.output_written], buffer[0..progress.output_written]);
                position += progress.output_written;
                if (progress.status == .done) break;
            }
            try std.testing.expectEqual(expected.len, position);
        }
    };
    for ([_]writer.Options{
        .{ .compression = .lzma, .compression_extent_size = 32768, .metabox = true, .compress_directories = true },
        .{ .compression = .zstandard, .compression_extent_size = 32768 },
        .{ .chunk_size = 4096 },
    }) |options| {
        const image = try writer.encodeAlloc(allocator, &.{.{ .path = "dir/data", .data = data }}, options);
        defer allocator.free(image);
        try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ image, data });
    }
}
