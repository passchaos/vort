const std = @import("std");
const writer = @import("../../writer.zig");
const archive_module = @import("../../archive.zig");
const format = @import("../../format.zig");
const reference = @import("../reference.zig");
const sources = @import("../../../io/source.zig");
const sinks = @import("../../../io/sink.zig");
const helpers = @import("../../reader/tests/helpers.zig");
const tree_module = @import("../tree.zig");
const layout_module = @import("../layout.zig");
const codec_module = @import("../codec.zig");
const metadata_module = @import("../compression_metadata.zig");

fn collect(encoder: *writer.Encoder, output: *sinks.BufferSink) !void {
    var buffer: [257]u8 = undefined;
    var step: usize = 0;
    while (true) {
        const size = ([_]usize{ 0, 1, 17, 257 })[step % 4];
        const progress = try encoder.read(buffer[0..size]);
        try std.testing.expect(progress.output_written <= size);
        if (progress.output_written != 0) try output.sink().writeExact(progress.offset, buffer[0..progress.output_written]);
        if (progress.status == .done) break;
        step += 1;
    }
    try output.sink().finish(encoder.result().?.image_size);
}

test "EROFS compact formats round trip every codec Source streaming tails and metabox" {
    const allocator = std.testing.allocator;
    var payload: [33 * 4096 + 123]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x434f_4d50_4143_5445);
    random.random().bytes(payload[0..8192]);
    for (payload[8192..], 8192..) |*byte, index| byte.* = if (index / 32768 % 2 == 0) payload[index % 8192] else @truncate(index *% 29);
    for ([_]writer.IndexFormat{ .compact_4byte, .compact }) |index_format| {
        for ([_]writer.Compression{ .lz4, .lzma, .deflate, .zstandard }) |compression| {
            for ([_]writer.Options{
                .{},
                .{ .compression_extent_size = 32768 },
                .{ .compression_extent_size = 65536, .max_pcluster_size = 8192 },
                .{ .compression_extent_size = 32768, .tail_packing = .fragments },
                .{ .compression_extent_size = 32768, .tail_packing = .compressed_inline },
                .{ .compression_extent_size = 32768, .metabox = true, .compress_directories = true },
            }) |variant| {
                var options = variant;
                options.compression = compression;
                options.compressed_index_format = index_format;
                options.inode_version = .extended;
                options.force_48bit = true;
                const attrs = [_]writer.Xattr{.{ .name = "user.compact", .value = "compact index xattr" }};
                const entries = [_]writer.Entry{ .{ .path = "dir/file", .data = &payload, .xattrs = &attrs }, .{ .path = "tiny", .data = "tiny compact tail" }, .{ .path = "empty" } };
                const expected = try reference.encodeAlloc(allocator, &entries, options);
                defer allocator.free(expected);
                const ordinary = try writer.encodeAlloc(allocator, &entries, options);
                defer allocator.free(ordinary);
                try std.testing.expectEqualSlices(u8, expected, ordinary);
                var input = sources.SliceSource{ .bytes = &payload };
                var source_entries = entries;
                source_entries[0].data = &.{};
                source_entries[0].source = input.source();
                source_entries[0].source.?.max_read_size = 127;
                var encoder: writer.Encoder = undefined;
                try encoder.init(allocator, &source_entries, options, .{});
                defer encoder.deinit();
                var output = sinks.BufferSink.init(allocator);
                defer output.deinit();
                try collect(&encoder, &output);
                try std.testing.expectEqualSlices(u8, expected, output.bytes.items);
                const base = try archive_module.Archive.init(expected);
                var loaded = if (options.metabox) try base.loadMetaboxAllocLimited(allocator, 1024 * 1024, 1024 * 1024) else null;
                defer if (loaded) |*owner| owner.deinit();
                const archive = if (loaded) |owner| owner.archive else base;
                const inode = try archive.lookup(allocator, "dir/file", payload.len, 4096);
                try std.testing.expectEqual(format.Layout.compressed_compact, inode.layout);
                try std.testing.expectEqual(index_format == .compact, inode.compressed_advise & 1 != 0);
                try std.testing.expectEqual(inode.compressed_advise & 2 != 0, inode.compressed_advise & 4 != 0);
                const decoded = try archive.readFlatAllocLimited(allocator, inode, payload.len);
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, &payload, decoded);
                for ([_]usize{ 4093, 15 * 4096 - 3, 16 * 4096, 32 * 4096 }) |start| {
                    var sink = helpers.Counting{ .expected = payload[start..][0..31] };
                    _ = try archive.readRangeToSink(allocator, inode, start, 31, sink.sink(), .{ .max_output_len = 31 });
                    try std.testing.expect(sink.finished);
                }
                const tiny = try archive.lookup(allocator, "tiny", 100, 4096);
                try std.testing.expectEqual(if (options.tail_packing == .fragments) format.Layout.compressed_full else .compressed_compact, tiny.layout);
            }
        }
    }
}

test "EROFS compact writing releases every allocation failure across inline fragment and metabox" {
    const allocator = std.testing.allocator;
    const payload = "compact allocation failure payload\n" ** 160;
    const Test = struct {
        fn run(work: std.mem.Allocator, bytes: []const u8, options: writer.Options) !void {
            var input = sources.SliceSource{ .bytes = bytes };
            const image = try writer.encodeAlloc(work, &.{.{ .path = "file", .source = input.source() }}, options);
            defer work.free(image);
            const base = try archive_module.Archive.init(image);
            var loaded = if (options.metabox) try base.loadMetaboxAllocLimited(work, 1024 * 1024, 1024 * 1024) else null;
            defer if (loaded) |*owner| owner.deinit();
            const archive = if (loaded) |owner| owner.archive else base;
            const output = try archive.extractByPathAllocLimited(work, "file", bytes.len, 4096);
            defer work.free(output);
            try std.testing.expectEqualSlices(u8, bytes, output);
        }
    };
    for ([_]writer.Options{
        .{ .compression = .lz4, .compressed_index_format = .compact, .tail_packing = .compressed_inline },
        .{ .compression = .deflate, .compressed_index_format = .compact_4byte, .tail_packing = .fragments },
        .{ .compression = .lzma, .compressed_index_format = .compact, .metabox = true, .compression_extent_size = 32768 },
    }) |options| try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ payload, options });
}

test "EROFS compact indexes cover maximum logical groups and exact empty tiny boundary files" {
    const allocator = std.testing.allocator;
    const payload = try allocator.alloc(u8, 1024 * 1024 + 4097);
    defer allocator.free(payload);
    for (payload, 0..) |*byte, index| byte.* = @truncate(index *% 17);
    for ([_]writer.IndexFormat{ .compact_4byte, .compact }) |index_format| {
        for ([_]usize{ 0, 1, 4095, 4096, 4097, payload.len }) |size| {
            const image = try writer.encodeAlloc(allocator, &.{.{ .path = "file", .data = payload[0..size] }}, .{ .compression = .lz4, .compressed_index_format = index_format, .compression_extent_size = 1024 * 1024 });
            defer allocator.free(image);
            const archive = try archive_module.Archive.init(image);
            const decoded = try archive.extractByPathAllocLimited(allocator, "file", size, 4096);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, payload[0..size], decoded);
        }
    }
}

test "EROFS compact Source encoder errors remain sticky before committing metadata" {
    const allocator = std.testing.allocator;
    const payload = "compact Source failure payload\n" ** 500;
    var input = helpers.Input{ .bytes = payload };
    var encoder: writer.Encoder = undefined;
    try encoder.init(allocator, &.{.{ .path = "file", .source = input.source() }}, .{ .compression = .lz4, .compressed_index_format = .compact, .compression_extent_size = 32768 }, .{});
    defer encoder.deinit();
    input.fail_from_offset = 4096;
    var output: [257]u8 = undefined;
    while (true) {
        @memset(&output, 0xa5);
        _ = encoder.read(&output) catch |err| {
            try std.testing.expectEqual(error.SourceReadFailed, err);
            for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
            break;
        };
    }
    input.fail_from_offset = null;
    try std.testing.expectError(error.SourceReadFailed, encoder.read(&output));
    try std.testing.expect(encoder.result() == null);
}

test "EROFS compact preference preserves fragment offsets requiring full index representation" {
    const allocator = std.testing.allocator;
    const payload = [_]u8{0} ** 4099;
    for ([_]writer.IndexFormat{ .compact_4byte, .compact }) |index_format| {
        var filesystem = try tree_module.build(allocator, &.{.{ .path = "file", .data = &payload }}, &.{});
        defer filesystem.deinit();
        const node = &filesystem.nodes[1];
        node.fragment_size = 3;
        node.fragment_offset = (@as(u64, 1) << 32) | 17;
        var encoder = try codec_module.Encoder.init(allocator, .lz4);
        defer encoder.deinit();
        const end = try layout_module.planMetadata(allocator, &filesystem, .{ .compression = .lz4, .compressed_index_format = index_format }, &encoder, false, null);
        try std.testing.expectEqual(@as(u3, @intFromEnum(format.Layout.compressed_full)), node.layout);
        const metadata = try allocator.alloc(u8, end);
        defer allocator.free(metadata);
        @memset(metadata, 0);
        try metadata_module.write(metadata, node, .lz4);
        const header = std.mem.alignForward(usize, node.location + node.inode_size, 8);
        try std.testing.expectEqual(@as(u32, 17), format.readU32(metadata, header));
        try std.testing.expectEqual(@as(u32, 1), format.readU32(metadata, header + 16 + 8 + 4));
    }
}
