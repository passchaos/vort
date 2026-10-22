const std = @import("std");
const writer = @import("../../writer.zig");
const reference = @import("../reference.zig");
const sink_module = @import("../../../io/sink.zig");
const source_module = @import("../../../io/source.zig");

fn collect(encoder: *writer.Encoder, image: *sink_module.BufferSink, device: *sink_module.BufferSink) !void {
    var buffer: [137]u8 = undefined;
    var step: usize = 0;
    while (true) {
        const size = ([_]usize{ 0, 1, 7, 137, 13, 31 })[step % 6];
        const progress = try encoder.read(buffer[0..size]);
        try std.testing.expect(progress.output_written <= size);
        if (progress.output_written != 0) {
            const output = if (progress.target == .image) image.sink() else device.sink();
            try output.writeExact(progress.offset, buffer[0..progress.output_written]);
        }
        if (progress.status == .done) break;
        if (size != 0) try std.testing.expect(progress.output_written != 0);
        step += 1;
    }
    const result = encoder.result().?;
    try image.sink().finish(result.image_size);
    try device.sink().finish(result.device_size);
    const again = try encoder.read(&buffer);
    try std.testing.expectEqual(@as(usize, 0), again.output_written);
    try std.testing.expect(again.status == .done);
}

test "EROFS resumable encoder preserves image bytes across codec and metadata layouts" {
    const allocator = std.testing.allocator;
    var data: [16384 + 619]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x454e_434f_4445_5253);
    random.random().bytes(data[0..8192]);
    @memcpy(data[8192..16384], data[0..8192]);
    @memcpy(data[16384..], data[0..619]);
    for ([_]writer.Compression{ .stored, .lz4, .lzma, .deflate, .zstandard }) |compression| {
        for ([_]writer.Options{
            .{},
            .{ .compression_extent_size = 32768 },
            .{ .compression_extent_size = 32768, .max_pcluster_size = 8192 },
            .{ .tail_packing = .fragments },
            .{ .tail_packing = .compressed_inline },
            .{ .metabox = true },
            .{ .metabox = true, .compress_directories = true, .compression_extent_size = 32768, .max_pcluster_size = 8192 },
        }, 0..) |variant, index| {
            if (compression == .stored and index != 0 and index != 5) continue;
            var options = variant;
            options.compression = compression;
            options.force_48bit = true;
            options.inode_version = .automatic;
            options.shared_xattrs = true;
            options.xattr_prefixes = &.{"user."};
            const attrs = [_]writer.Xattr{.{ .name = "user.test", .value = "shared attr" }};
            const entries = [_]writer.Entry{
                .{ .path = "dir/data", .data = &data, .uid = 70_000, .xattrs = &attrs },
                .{ .path = "tiny", .data = "T", .xattrs = &attrs },
                .{ .path = "empty" },
                .{ .path = "link", .kind = .symlink, .target = "dir/data" },
            };
            const expected = try reference.encodeAlloc(allocator, &entries, options);
            defer allocator.free(expected);
            var input = source_module.SliceSource{ .bytes = &data };
            var sources = entries;
            sources[0].data = &.{};
            sources[0].source = input.source();
            sources[0].source.?.max_read_size = 127;
            var encoder: writer.Encoder = undefined;
            try encoder.init(allocator, &sources, options, .{});
            defer encoder.deinit();
            try std.testing.expect(encoder.result() == null);
            var image = sink_module.BufferSink.init(allocator);
            defer image.deinit();
            var device = sink_module.BufferSink.init(allocator);
            defer device.deinit();
            try collect(&encoder, &image, &device);
            try std.testing.expectEqualSlices(u8, expected, image.bytes.items);
            try std.testing.expectEqual(@as(usize, 0), device.bytes.items.len);
        }
    }
}

test "EROFS resumable encoder preserves local external chunk padding holes and deduplication" {
    const allocator = std.testing.allocator;
    const data = "chunk cursor bytes\n" ** 1200;
    const entries = [_]writer.Entry{
        .{ .path = "data", .data = data },
        .{ .path = "copy", .data = data },
        .{ .path = "hole", .data = &([_]u8{0} ** 8192) },
        .{ .path = "tiny", .data = "X" },
    };
    const options = writer.Options{ .chunk_size = 8192, .force_48bit = true, .inode_version = .extended };
    for ([_]bool{ false, true }) |external| {
        var expected_external = if (external) try reference.encodeExternalChunksAlloc(allocator, &entries, options) else null;
        defer if (expected_external) |*expected| expected.deinit(allocator);
        const expected = if (expected_external) |output| output.image else try reference.encodeAlloc(allocator, &entries, options);
        defer if (!external) allocator.free(expected);
        var encoder: writer.Encoder = undefined;
        if (external) try encoder.initExternalChunks(allocator, &entries, options, .{}) else try encoder.init(allocator, &entries, options, .{});
        defer encoder.deinit();
        var image = sink_module.BufferSink.init(allocator);
        defer image.deinit();
        var device = sink_module.BufferSink.init(allocator);
        defer device.deinit();
        try collect(&encoder, &image, &device);
        try std.testing.expectEqualSlices(u8, expected, image.bytes.items);
        if (expected_external) |output| try std.testing.expectEqualSlices(u8, output.device, device.bytes.items);
    }
}
