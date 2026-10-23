const std = @import("std");
const writer = @import("../../writer.zig");
const archive_module = @import("../../archive.zig");
const source_archive = @import("../../source_archive.zig");
const sink_module = @import("../../../io/sink.zig");
const reference = @import("../reference.zig");
const plan_module = @import("../plan.zig");
const helpers = @import("../../reader/tests/helpers.zig");

const payload = "metadata-zone file payload 0123456789\n" ** 400;
const attributes = [_]writer.Xattr{.{ .name = "user.vort.zone", .value = "directory attribute" }};

fn prepare(entries: []writer.Entry, names: [][96]u8) !void {
    for (entries[0 .. entries.len - 3], 0..) |*entry, index| entry.* = .{
        .path = try std.fmt.bufPrint(&names[index], "dir/item-{d:03}-with-a-long-deterministic-name-for-directory-blocks", .{index}),
        .data = "",
    };
    entries[entries.len - 3] = .{ .path = "dir", .kind = .directory, .xattrs = &attributes };
    entries[entries.len - 2] = .{ .path = "file", .data = payload, .xattrs = &attributes };
    entries[entries.len - 1] = .{ .path = "empty", .kind = .directory };
}

fn pump(encoder: *writer.Encoder, output: *sink_module.BufferSink) !void {
    var buffer: [137]u8 = undefined;
    var call: usize = 0;
    while (true) : (call += 1) {
        const size = ([_]usize{ 0, 1, 17, 137, 31 })[call % 5];
        const result = try encoder.read(buffer[0..size]);
        if (result.output_written != 0) {
            try std.testing.expectEqual(.image, result.target);
            output.sink().writeExact(result.offset, buffer[0..result.output_written]) catch |err| {
                if (err == error.SinkWriteFailed and output.allocation_failed) return error.OutOfMemory;
                return err;
            };
        }
        if (result.status == .done) break;
    }
    try output.sink().finish(encoder.result().?.image_size);
}

test "EROFS directory metadata zone preserves every codec metabox and encoder surface" {
    const allocator = std.testing.allocator;
    var entries: [163]writer.Entry = undefined;
    var names: [160][96]u8 = undefined;
    try prepare(&entries, &names);
    for ([_]writer.Compression{ .stored, .lz4, .lzma, .deflate, .zstandard }) |compression| {
        for ([_]bool{ false, true }) |metabox| {
            const options = writer.Options{
                .compression = compression,
                .metabox = metabox,
                .directory_metadata_zone = true,
                .compression_extent_size = if (compression == .stored) 4096 else 32768,
                .max_pcluster_size = if (compression == .stored) null else 8192,
                .shared_xattrs = true,
                .xattr_prefixes = &.{"user.vort."},
                .root_xattrs = &attributes,
                .inode_version = .extended,
            };
            const image = try writer.encodeAlloc(allocator, &entries, options);
            defer allocator.free(image);
            const independent = try reference.encodeAlloc(allocator, &entries, options);
            defer allocator.free(independent);
            try std.testing.expectEqualSlices(u8, independent, image);
            var encoder: writer.Encoder = undefined;
            try encoder.init(allocator, &entries, options, .{});
            defer encoder.deinit();
            var streamed = sink_module.BufferSink.init(allocator);
            defer streamed.deinit();
            try pump(&encoder, &streamed);
            try std.testing.expectEqualSlices(u8, image, streamed.bytes.items);
            const base = try archive_module.Archive.init(image);
            var loaded = if (metabox) try base.loadMetaboxAllocLimited(allocator, 2 * 1024 * 1024, 2 * 1024 * 1024) else null;
            defer if (loaded) |*owner| owner.deinit();
            const archive = if (loaded) |owner| owner.archive else base;
            const dir = try archive.lookup(allocator, "dir", payload.len, 65536);
            try std.testing.expect(dir.file_size > 8192);
            try std.testing.expect(dir.layout == .flat_plain or dir.layout == .flat_inline);
            const file = try archive.lookup(allocator, "file", payload.len, 65536);
            var listing = try archive.readDirectoryAlloc(allocator, dir, 65536);
            defer listing.deinit();
            try std.testing.expectEqual(@as(usize, 160), listing.entries.len);
            var attrs = try archive.readXattrsAllocLimited(allocator, dir, 1, 128);
            defer attrs.deinit();
            try std.testing.expectEqualStrings(attributes[0].value, attrs.find(attributes[0].name).?.value);
            const directory_blocks = if (dir.layout == .flat_inline) dir.file_size / 4096 else (dir.file_size + 4095) / 4096;
            const metadata = if (file.in_metabox) loaded.?.bytes else image;
            const file_block = if (compression == .stored) file.data_block else @import("../../format.zig").readU32(metadata, file.compressed_index_start + 4);
            try std.testing.expect(dir.data_block + directory_blocks <= file_block);
            var input = helpers.Input{ .bytes = image };
            var source = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 2 * 1024 * 1024 });
            defer source.deinit();
            const decoded = try source.extractByPathAllocLimited(allocator, "file", payload.len, 65536);
            defer allocator.free(decoded);
            try std.testing.expectEqualStrings(payload, decoded);
            var iterator = try source.initDirectoryIterator(try source.lookup("dir", payload.len, 65536), 65536);
            defer iterator.deinit();
            var count: usize = 0;
            while (try iterator.next()) |_| count += 1;
            try std.testing.expectEqual(@as(usize, 160), count);
        }
    }
}

test "EROFS metadata zone reserves directory blocks before callbacks read file data" {
    const allocator = std.testing.allocator;
    var entries: [163]writer.Entry = undefined;
    var names: [160][96]u8 = undefined;
    try prepare(&entries, &names);
    var input = helpers.Input{ .bytes = payload };
    entries[161].source = input.source();
    entries[161].data = &.{};
    var encoder: writer.Encoder = undefined;
    try encoder.init(allocator, &entries, .{ .directory_metadata_zone = true, .compression = .lz4, .compression_extent_size = 32768 }, .{ .max_working_memory = 2 * 1024 * 1024 });
    defer encoder.deinit();
    try std.testing.expectEqual(@as(usize, 0), input.calls);
    for (encoder.plan.?.filesystem.nodes) |node| if (node.kind == .directory) {
        try std.testing.expect(node.directory_in_metadata_zone);
        if (node.start_block != std.math.maxInt(u32)) try std.testing.expect(node.start_block * @as(u64, 4096) < encoder.metadata.len);
    };
    var output = sink_module.BufferSink.init(allocator);
    defer output.deinit();
    try pump(&encoder, &output);
    try std.testing.expect(input.calls != 0);
    const archive = try archive_module.Archive.init(output.bytes.items);
    const decoded = try archive.extractByPathAllocLimited(allocator, "file", payload.len, 65536);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(payload, decoded);
    try std.testing.expect(encoder.result().?.peak_working_bytes <= 2 * 1024 * 1024);
}

test "EROFS metadata zone options reject contradictory directory modes before allocation" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.InvalidErofs, plan_module.validate(.{ .compression = .lz4, .directory_metadata_zone = true, .compress_directories = true }, false));
    try std.testing.expectError(error.InvalidErofs, writer.encodeAlloc(allocator, &.{}, .{ .compression = .lz4, .directory_metadata_zone = true, .compress_directories = true }));
    _ = try plan_module.validate(.{ .directory_metadata_zone = true, .chunk_size = 4096 }, true);
    _ = try plan_module.validate(.{ .compression = .lz4, .directory_metadata_zone = true, .tail_packing = .fragments }, false);
}

test "EROFS metadata zone combines ordinary file tails and local external chunks" {
    const allocator = std.testing.allocator;
    var entries: [83]writer.Entry = undefined;
    var names: [80][96]u8 = undefined;
    try prepare(&entries, &names);
    for ([_]writer.Options{
        .{ .compression = .lz4 },
        .{ .compression = .lzma },
        .{ .compression = .deflate },
        .{ .compression = .zstandard },
        .{ .compression = .lz4, .tail_packing = .fragments },
        .{ .compression = .lz4, .tail_packing = .compressed_inline },
        .{ .chunk_size = 4096 },
    }) |base| {
        var options = base;
        options.directory_metadata_zone = true;
        options.force_48bit = true;
        options.inode_version = .automatic;
        const image = try writer.encodeAlloc(allocator, &entries, options);
        defer allocator.free(image);
        const expected = try reference.encodeAlloc(allocator, &entries, options);
        defer allocator.free(expected);
        try std.testing.expectEqualSlices(u8, expected, image);
        const archive = try archive_module.Archive.init(image);
        const decoded = try archive.extractByPathAllocLimited(allocator, "file", payload.len, 65536);
        defer allocator.free(decoded);
        try std.testing.expectEqualStrings(payload, decoded);
        const directory = try archive.lookup(allocator, "dir", payload.len, 65536);
        try std.testing.expect(directory.data_block * 4096 < image.len);
        if (options.chunk_size != null) {
            var output = try writer.encodeExternalChunksAlloc(allocator, &entries, options);
            defer output.deinit(allocator);
            var independent = try reference.encodeExternalChunksAlloc(allocator, &entries, options);
            defer independent.deinit(allocator);
            try std.testing.expectEqualSlices(u8, independent.image, output.image);
            try std.testing.expectEqualSlices(u8, independent.device, output.device);
            const local = try archive_module.Archive.initWithDevices(output.image, &.{output.device});
            var listing = try local.readDirectoryAlloc(allocator, try local.lookup(allocator, "dir", payload.len, 65536), 65536);
            defer listing.deinit();
            try std.testing.expectEqual(@as(usize, 80), listing.entries.len);
            const actual = try local.extractByPathAllocLimited(allocator, "file", payload.len, 65536);
            defer allocator.free(actual);
            try std.testing.expectEqualStrings(payload, actual);
        }
    }
}

test "EROFS metadata zone releases every allocation failure and work limit rejection" {
    const allocator = std.testing.allocator;
    var entries: [83]writer.Entry = undefined;
    var names: [80][96]u8 = undefined;
    try prepare(&entries, &names);
    const Test = struct {
        fn run(work: std.mem.Allocator, values: []const writer.Entry, metabox: bool) !void {
            var output = sink_module.BufferSink.init(work);
            defer output.deinit();
            var encoder: writer.Encoder = undefined;
            try encoder.init(work, values, .{ .compression = .lz4, .metabox = metabox, .directory_metadata_zone = true, .compression_extent_size = 32768, .shared_xattrs = true }, .{});
            defer encoder.deinit();
            try pump(&encoder, &output);
            const archive = try archive_module.Archive.init(output.bytes.items);
            var loaded = if (metabox) try archive.loadMetaboxAllocLimited(work, 2 * 1024 * 1024, 2 * 1024 * 1024) else null;
            defer if (loaded) |*owner| owner.deinit();
            const ready = if (loaded) |owner| owner.archive else archive;
            const decoded = try ready.extractByPathAllocLimited(work, "file", payload.len, 65536);
            defer work.free(decoded);
            try std.testing.expectEqualStrings(payload, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ &entries, false });
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ &entries, true });
    var encoder: writer.Encoder = undefined;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.init(allocator, &entries, .{ .directory_metadata_zone = true }, .{ .max_working_memory = 1 }));
}
