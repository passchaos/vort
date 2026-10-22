const std = @import("std");
const writer = @import("../../writer.zig");
const archive_module = @import("../../archive.zig");
const source_archive = @import("../../source_archive.zig");
const source_module = @import("../../../io/source.zig");
const sink_module = @import("../../../io/sink.zig");
const format = @import("../../format.zig");

const Input = struct {
    bytes: []const u8,
    max_request: usize = 0,
    fn source(self: *@This()) source_module.Source {
        return .{ .context = self, .len = self.bytes.len, .read_at = readAt, .max_read_size = 31 };
    }
    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.max_request = @max(self.max_request, output.len);
        const start: usize = @intCast(offset);
        const size = @min(7, @min(output.len, self.bytes.len - start));
        @memcpy(output[0..size], self.bytes[start..][0..size]);
        return size;
    }
};

fn payload() [16384 + 619]u8 {
    var bytes: [16384 + 619]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x5245_4144_534f_5552);
    prng.random().bytes(bytes[0..8192]);
    @memcpy(bytes[8192..16384], bytes[0..8192]);
    @memcpy(bytes[16384..], bytes[0..619]);
    return bytes;
}

test "EROFS Source archive extracts every codec and layout directly to Sink" {
    const allocator = std.testing.allocator;
    const data = payload();
    const attributes = [_]writer.Xattr{.{ .name = "user.vort.shared", .value = "source attribute" }};
    const entries = [_]writer.Entry{
        .{ .path = "dir/data", .data = &data, .uid = 70_000, .xattrs = &attributes },
        .{ .path = "tiny", .data = "T", .xattrs = &attributes },
        .{ .path = "empty" },
        .{ .path = "link", .kind = .symlink, .target = "dir/data" },
    };
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
            options.root_xattrs = &attributes;
            options.shared_xattrs = true;
            options.xattr_prefixes = &.{"user.vort."};
            const image = try writer.encodeAlloc(allocator, &entries, options);
            defer allocator.free(image);
            var input = Input{ .bytes = image };
            var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{});
            defer archive.deinit();
            var listing = try archive.readDirectoryAlloc(allocator, try archive.rootInode(), 4096);
            defer listing.deinit();
            try std.testing.expect(listing.find("dir") != null and listing.find("link") != null);
            for (entries) |entry| {
                var output = sink_module.BufferSink.init(allocator);
                defer output.deinit();
                var sink = output.sink();
                sink.max_write_size = 127;
                const expected = if (entry.kind == .symlink) entry.target else entry.data;
                const result = try archive.extractByPathToSink(entry.path, sink, .{ .max_output_len = data.len }, 4096);
                try std.testing.expectEqual(expected.len, result.decoded_size);
                try std.testing.expectEqualSlices(u8, expected, output.bytes.items);
                if (entry.kind == .file and entry.xattrs.len != 0) {
                    const inode = try archive.lookup(entry.path, data.len, 4096);
                    var attrs = try archive.readXattrsAllocLimited(allocator, inode, 8, 4096);
                    defer attrs.deinit();
                    try std.testing.expectEqualStrings("source attribute", attrs.find("user.vort.shared").?.value);
                }
            }
            const inode = try archive.lookup("dir/data", data.len, 4096);
            var range = sink_module.BufferSink.init(allocator);
            defer range.deinit();
            _ = try archive.readRangeToSink(inode, 4091, 8000, range.sink(), .{ .max_output_len = data.len });
            try std.testing.expectEqualSlices(u8, data[4091..12091], range.bytes.items);
            try std.testing.expect(input.max_request <= 31);
        }
    }
}

test "EROFS Source archive preserves chunk holes padding deduplication and external devices" {
    const allocator = std.testing.allocator;
    const data = payload();
    const zeros = [_]u8{0} ** 8192;
    const entries = [_]writer.Entry{
        .{ .path = "data", .data = &data },
        .{ .path = "copy", .data = &data },
        .{ .path = "hole", .data = &zeros },
        .{ .path = "tiny", .data = "X" },
    };
    const options = writer.Options{ .chunk_size = 8192, .force_48bit = true, .inode_version = .extended };
    const local = try writer.encodeAlloc(allocator, &entries, options);
    defer allocator.free(local);
    var external = try writer.encodeExternalChunksAlloc(allocator, &entries, options);
    defer external.deinit(allocator);
    for ([_]bool{ false, true }) |external_mode| {
        var input = Input{ .bytes = if (external_mode) external.image else local };
        var device = Input{ .bytes = external.device };
        const devices = [_]source_module.Source{device.source()};
        var archive = try source_archive.SourceArchive.initWithDevices(allocator, input.source(), if (external_mode) &devices else &.{}, .{});
        defer archive.deinit();
        for (entries) |entry| {
            const decoded = try archive.extractByPathAllocLimited(allocator, entry.path, data.len, 4096);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, entry.data, decoded);
        }
        const inode = try archive.lookup("data", data.len, 4096);
        var output = sink_module.BufferSink.init(allocator);
        defer output.deinit();
        _ = try archive.readRangeToSink(inode, 8190, 1024, output.sink(), .{ .max_output_len = 1024 });
        try std.testing.expectEqualSlices(u8, data[8190..9214], output.bytes.items);
        try std.testing.expect(input.max_request <= 31 and device.max_request <= 31);
    }
}

test "EROFS Source archive matches compact and final-big external corpus extraction" {
    const allocator = std.testing.allocator;
    for ([_][]const u8{
        @embedFile("../../testdata/lz4-compact-big.erofs.b64"),
        @embedFile("../../testdata/lz4-full-final-big.erofs.b64"),
        @embedFile("../../testdata/lz4-compact-final-big.erofs.b64"),
    }) |encoded| {
        const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
        const bytes = try allocator.alloc(u8, decoder.calcSizeUpperBound(encoded.len));
        defer allocator.free(bytes);
        const image = bytes[0..try decoder.decode(bytes, encoded)];
        const reference = try archive_module.Archive.init(image);
        var input = Input{ .bytes = image };
        var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{});
        defer archive.deinit();
        var directory = try reference.readDirectoryAlloc(allocator, try reference.rootInode(), 4096);
        defer directory.deinit();
        for (directory.entries) |entry| {
            const inode = try reference.inode(entry.nid);
            const expected = try reference.readFlatAllocLimited(allocator, inode, 1024 * 1024);
            defer allocator.free(expected);
            const actual = try archive.extractByPathAllocLimited(allocator, entry.name, 1024 * 1024, 4096);
            defer allocator.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
        }
    }
}

test "EROFS Source archive routes packed fragments through modern extent records" {
    const allocator = std.testing.allocator;
    const expected = "packed modern fragment payload";
    const image = try writer.encodeAlloc(allocator, &.{.{ .path = "file", .data = expected }}, .{ .compression = .lz4, .tail_packing = .fragments, .force_48bit = true });
    defer allocator.free(image);
    const reference = try archive_module.Archive.init(image);
    const packed_inode = try reference.inode(reference.superblock.packed_nid);
    const physical_block = format.readU32(image, packed_inode.compressed_index_start + 4);
    try std.testing.expectEqual(@as(u16, 0), format.readU16(image, packed_inode.compressed_index_start) & 3);
    const header = packed_inode.compressed_header_start;
    const record = std.mem.alignForward(usize, header + 8, 16);
    std.mem.writeInt(u32, image[header..][0..4], 1, .little);
    std.mem.writeInt(u16, image[header + 4 ..][0..2], 5, .little);
    std.mem.writeInt(u16, image[header + 6 ..][0..2], 0, .little);
    std.mem.writeInt(u32, image[record..][0..4], @intCast(packed_inode.file_size), .little);
    std.mem.writeInt(u32, image[record + 4 ..][0..4], physical_block * @as(u32, @intCast(reference.superblock.block_size)), .little);
    std.mem.writeInt(u32, image[record + 8 ..][0..4], 0, .little);
    std.mem.writeInt(u32, image[record + 12 ..][0..4], 0, .little);
    std.mem.writeInt(u32, image[1028..1032], format.computeSuperblockChecksum(image[1024..reference.superblock.block_size]), .little);
    var input = Input{ .bytes = image };
    var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{});
    defer archive.deinit();
    const decoded = try archive.extractByPathAllocLimited(allocator, "file", 4096, 4096);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(expected, decoded);
    var extractor = try archive.initPathExtractor("file", .{ .max_output_len = 4096 }, 4096);
    defer extractor.deinit();
    var partial: [expected.len]u8 = undefined;
    var position: usize = 0;
    while (true) {
        const progress = try extractor.read(partial[position..@min(partial.len, position + 3)]);
        position += progress.output_written;
        if (progress.status == .done) break;
    }
    try std.testing.expectEqualStrings(expected, &partial);
}
