const std = @import("std");
const writer = @import("../../writer.zig");
const archive = @import("../../archive.zig");
const source_archive = @import("../../source_archive.zig");
const reference = @import("../reference.zig");
const sink_module = @import("../../../io/sink.zig");
const helpers = @import("../../reader/tests/helpers.zig");

pub const payload = "metabox combined payload 0123456789\n" ** 500;
pub const attrs = [_]writer.Xattr{.{ .name = "user.vort.combined", .value = "shared combination attribute" }};
pub const entries = [_]writer.Entry{
    .{ .path = "dir", .kind = .directory, .xattrs = &attrs },
    .{ .path = "dir/data", .data = payload, .xattrs = &attrs },
    .{ .path = "copy", .data = payload, .xattrs = &attrs },
    .{ .path = "tiny", .data = "small metabox tail", .xattrs = &attrs },
    .{ .path = "empty" },
    .{ .path = "link", .kind = .symlink, .target = "dir/data" },
};

pub fn collect(encoder: *writer.Encoder, image: *sink_module.BufferSink, device: *sink_module.BufferSink) !void {
    var buffer: [137]u8 = undefined;
    var call: usize = 0;
    while (true) : (call += 1) {
        const size = ([_]usize{ 0, 1, 7, 17, 137 })[call % 5];
        const progress = try encoder.read(buffer[0..size]);
        if (progress.output_written != 0) {
            const sink = if (progress.target == .image) image else device;
            sink.sink().writeExact(progress.offset, buffer[0..progress.output_written]) catch |err| {
                if (err == error.SinkWriteFailed and sink.allocation_failed) return error.OutOfMemory;
                return err;
            };
        }
        if (progress.status == .done) break;
    }
    try image.sink().finish(encoder.result().?.image_size);
    try device.sink().finish(encoder.result().?.device_size);
}

fn verify(image: []const u8, device: ?[]const u8, options: writer.Options) !void {
    const allocator = std.testing.allocator;
    const base = try archive.Archive.initWithDevices(image, if (device) |blob| &.{blob} else &.{});
    var loaded = try base.loadMetaboxAllocLimited(allocator, 2 * 1024 * 1024, 2 * 1024 * 1024);
    defer loaded.deinit();
    const parsed = loaded.archive;
    try std.testing.expect((try parsed.rootInode()).in_metabox);
    for (entries) |entry| {
        const value = try parsed.lookup(allocator, entry.path, payload.len, 65536);
        try std.testing.expect(value.in_metabox);
        if (entry.kind == .directory) continue;
        const expected = if (entry.kind == .symlink) entry.target else entry.data;
        const decoded = try parsed.readFlatAllocLimited(allocator, value, expected.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, expected, decoded);
        if (entry.xattrs.len != 0) {
            var attributes = try parsed.readXattrsAllocLimited(allocator, value, 1, 128);
            defer attributes.deinit();
            try std.testing.expectEqualStrings(attrs[0].value, attributes.find(attrs[0].name).?.value);
        }
    }
    const tiny = try parsed.lookup(allocator, "tiny", payload.len, 65536);
    if (options.tail_packing == .fragments) {
        try std.testing.expect(tiny.fragment_offset != null);
        try std.testing.expect(base.superblock.packed_nid != 0);
        try std.testing.expect(!(try base.inode(base.superblock.packed_nid)).in_metabox);
    }
    if (options.tail_packing == .compressed_inline) try std.testing.expect(tiny.compressed_inline_size != 0);
    var input = helpers.Input{ .bytes = image };
    var blob = helpers.Input{ .bytes = device orelse &.{} };
    var sources = [_]writer.Source{blob.source()};
    var source = try source_archive.SourceArchive.initWithDevices(allocator, input.source(), if (device != null) &sources else &.{}, .{});
    defer source.deinit();
    const decoded = try source.extractByPathAllocLimited(allocator, "dir/data", payload.len, 65536);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(payload, decoded);
    const value = try source.lookup("dir/data", payload.len, 65536);
    var range = sink_module.BufferSink.init(allocator);
    defer range.deinit();
    _ = try source.readRangeToSink(value, 4091, 8000, range.sink(), .{ .max_output_len = 8000 });
    try std.testing.expectEqualStrings(payload[4091..12091], range.bytes.items);
}

test "EROFS metabox tail combinations preserve reference Source Sink and tiny encoder bytes" {
    const allocator = std.testing.allocator;
    for ([_]writer.Compression{ .lz4, .lzma, .deflate, .zstandard }) |compression| {
        for ([_]writer.TailPacking{ .fragments, .compressed_inline }) |tails| {
            for ([_]u8{ 0, 1, 2, 3 }) |variant| {
                const options = writer.Options{
                    .compression = compression,
                    .tail_packing = tails,
                    .metabox = true,
                    .compression_extent_size = if (variant == 0) 4096 else 32768,
                    .max_pcluster_size = if (variant == 2) 4096 else null,
                    .compress_directories = variant == 3,
                    .shared_xattrs = true,
                    .xattr_prefixes = &.{"user.vort."},
                    .root_xattrs = &attrs,
                    .inode_version = .extended,
                };
                const image = try writer.encodeAlloc(allocator, &entries, options);
                defer allocator.free(image);
                const independent = try reference.encodeAlloc(allocator, &entries, options);
                defer allocator.free(independent);
                try std.testing.expectEqualSlices(u8, independent, image);
                var input = helpers.Input{ .bytes = payload };
                var source_entries = entries;
                source_entries[1].data = &.{};
                source_entries[1].source = input.source();
                var encoder: writer.Encoder = undefined;
                try encoder.init(allocator, &source_entries, options, .{});
                defer encoder.deinit();
                var output = sink_module.BufferSink.init(allocator);
                defer output.deinit();
                var device = sink_module.BufferSink.init(allocator);
                defer device.deinit();
                try collect(&encoder, &output, &device);
                try std.testing.expectEqualSlices(u8, image, output.bytes.items);
                try std.testing.expectEqual(@as(usize, 0), device.bytes.items.len);
                try verify(image, null, options);
            }
        }
    }
}

test "EROFS metabox chunks retain holes padding deduplication and external device IDs" {
    const allocator = std.testing.allocator;
    var values = entries ++ [_]writer.Entry{.{ .path = "hole", .data = &([_]u8{0} ** 8192) }};
    for ([_]bool{ false, true }) |external| {
        for ([_]bool{ false, true }) |zone| {
            const options = writer.Options{ .chunk_size = 8192, .metabox = true, .directory_metadata_zone = zone, .force_48bit = true, .shared_xattrs = true, .xattr_prefixes = &.{"user.vort."}, .root_xattrs = &attrs };
            var independent = if (external) try reference.encodeExternalChunksAlloc(allocator, &values, options) else null;
            defer if (independent) |*owner| owner.deinit(allocator);
            const expected = if (independent) |owner| owner.image else try reference.encodeAlloc(allocator, &values, options);
            defer if (!external) allocator.free(expected);
            var input = helpers.Input{ .bytes = payload };
            values[1].data = &.{};
            values[1].source = input.source();
            defer {
                values[1].source = null;
                values[1].data = payload;
            }
            var encoder: writer.Encoder = undefined;
            if (external) try encoder.initExternalChunks(allocator, &values, options, .{}) else try encoder.init(allocator, &values, options, .{});
            defer encoder.deinit();
            var image = sink_module.BufferSink.init(allocator);
            defer image.deinit();
            var device = sink_module.BufferSink.init(allocator);
            defer device.deinit();
            try collect(&encoder, &image, &device);
            try std.testing.expectEqualSlices(u8, expected, image.bytes.items);
            if (independent) |owner| try std.testing.expectEqualSlices(u8, owner.device, device.bytes.items);
            try verify(image.bytes.items, if (external) device.bytes.items else null, options);
            const base = try archive.Archive.initWithDevices(image.bytes.items, if (external) &.{device.bytes.items} else &.{});
            var loaded = try base.loadMetaboxAllocLimited(allocator, 2 * 1024 * 1024, 2 * 1024 * 1024);
            defer loaded.deinit();
            const first = try loaded.archive.lookup(allocator, "dir/data", payload.len, 65536);
            const copy = try loaded.archive.lookup(allocator, "copy", payload.len, 65536);
            const format = @import("../../format.zig");
            const block_offset: usize = if (external) 4 else 0;
            try std.testing.expectEqual(format.readU32(loaded.bytes, first.chunk_index_start + block_offset), format.readU32(loaded.bytes, copy.chunk_index_start + block_offset));
            const hole = try loaded.archive.extractByPathAllocLimited(allocator, "hole", 8192, 65536);
            defer allocator.free(hole);
            for (hole) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
        }
    }
}
