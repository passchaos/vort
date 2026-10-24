const std = @import("std");
const archive_module = @import("../../archive.zig");
const writer = @import("../../writer.zig");
const metadata = @import("../inode.zig");
const superblock = @import("../superblock.zig");
const input_module = @import("../input.zig");
const format = @import("../../format.zig");
const devices_module = @import("../devices.zig");
const source_module = @import("../../../io/source.zig");

const Context = struct {
    bytes: []const u8,
    max_request: usize = 0,
    fn input(self: *@This()) input_module.Input {
        return .{ .source = .{ .context = self, .len = self.bytes.len, .read_at = readAt, .max_read_size = 7 } };
    }
    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.max_request = @max(self.max_request, output.len);
        const start: usize = @intCast(offset);
        const size = @min(3, @min(output.len, self.bytes.len - start));
        @memcpy(output[0..size], self.bytes[start..][0..size]);
        return size;
    }
};

fn compareInode(reader: metadata.Reader, archive: archive_module.Archive, nid: u64) !void {
    const expected = try archive.inode(nid);
    try std.testing.expectEqualDeep(expected, try reader.inode(nid));
}

test "EROFS source inode metadata matches slices across writer layouts" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.Entry{
        .{ .path = "dir/data", .data = "source inode metadata 0123456789\n" ** 600, .uid = 70_000, .xattrs = &.{.{ .name = "user.test", .value = "value" }} },
        .{ .path = "tiny", .data = "T" },
        .{ .path = "link", .kind = .symlink, .target = "dir/data" },
    };
    for ([_]writer.Options{
        .{},
        .{ .compression = .lz4 },
        .{ .compression = .lz4, .compression_extent_size = 65536, .max_pcluster_size = 8192 },
        .{ .compression = .lz4, .tail_packing = .fragments },
        .{ .compression = .lz4, .tail_packing = .compressed_inline },
        .{ .compression = .lz4, .metabox = true, .compress_directories = true },
        .{ .chunk_size = 8192 },
    }) |base| {
        var options = base;
        options.force_48bit = true;
        options.inode_version = .automatic;
        const image = try writer.encodeAlloc(allocator, &entries, options);
        defer allocator.free(image);
        const parsed = try archive_module.Archive.init(image);
        var loaded = if (options.metabox) try parsed.loadMetaboxAllocLimited(allocator, 1024 * 1024, 1024 * 1024) else null;
        defer if (loaded) |*owner| owner.deinit();
        const archive = if (loaded) |owner| owner.archive else parsed;
        var primary = Context{ .bytes = image };
        var metabox = Context{ .bytes = archive.metabox_bytes orelse &.{} };
        const header = try superblock.read(primary.input());
        try std.testing.expectEqualDeep(archive.superblock, header);
        const reader = metadata.Reader{ .primary = primary.input(), .superblock = header, .metabox = if (loaded != null) metabox.input() else null };
        try compareInode(reader, archive, archive.superblock.root_nid);
        for ([_][]const u8{ "dir", "dir/data", "tiny", "link" }) |path| {
            const inode = try archive.lookup(allocator, path, 1024 * 1024, 1024 * 1024);
            try compareInode(reader, archive, inode.nid);
        }
        try std.testing.expect(primary.max_request <= 7 and metabox.max_request <= 7);
    }
}

test "EROFS source metadata retains compact-pack and final physical-count interpretation" {
    const allocator = std.testing.allocator;
    for ([_][]const u8{
        @embedFile("../../testdata/lz4-compact-big.erofs.b64"),
        @embedFile("../../testdata/lz4-full-final-big.erofs.b64"),
        @embedFile("../../testdata/lz4-compact-final-big.erofs.b64"),
    }) |encoded| {
        const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
        const storage = try allocator.alloc(u8, decoder.calcSizeUpperBound(encoded.len));
        defer allocator.free(storage);
        const image = storage[0..try decoder.decode(storage, encoded)];
        const archive = try archive_module.Archive.init(image);
        var primary = Context{ .bytes = image };
        const reader = metadata.Reader{ .primary = primary.input(), .superblock = try superblock.read(primary.input()) };
        var directory = try archive.readDirectoryAlloc(allocator, try archive.rootInode(), 4096);
        defer directory.deinit();
        for (directory.entries) |entry| {
            const inode = try archive.inode(entry.nid);
            try compareInode(reader, archive, entry.nid);
            const reference = metadata.Reader{ .primary = .{ .slice = image }, .superblock = archive.superblock };
            const cluster_size: usize = @as(usize, 1) << @intCast(inode.compressed_cluster_bits);
            const count = (inode.file_size + cluster_size - 1) / cluster_size;
            for (0..count) |index| {
                const actual = if (inode.layout == .compressed_full) try reader.readFullIndex(inode, index) else try reader.readCompactIndex(inode, index, count);
                const expected = if (inode.layout == .compressed_full) try reference.readFullIndex(inode, index) else try reference.readCompactIndex(inode, index, count);
                try std.testing.expectEqualDeep(expected, actual);
            }
        }
        try std.testing.expect(primary.max_request <= 7);
    }
}

test "EROFS source inode addresses reject overflow before unbounded reads" {
    const allocator = std.testing.allocator;
    const image = try writer.encodeAlloc(allocator, &.{}, .{});
    defer allocator.free(image);
    const ContextType = struct {
        record: [32]u8 = @splat(0),
        calls: usize = 0,
        fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
            _ = offset;
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            @memcpy(output, self.record[0..output.len]);
            return output.len;
        }
    };
    var context = ContextType{};
    var header = try format.parseSuperblock(image);
    header.meta_block = 0;
    header.feature_incompat |= format.feature_incompat_chunked_file;
    const reader = metadata.Reader{ .primary = .{ .source = .{ .context = &context, .len = std.math.maxInt(u64), .read_at = ContextType.readAt } }, .superblock = header };
    try std.testing.expectError(error.IntegerOverflow, reader.inode((@as(u64, 1) << 63) - 1));
    try std.testing.expectEqual(@as(usize, 0), context.calls);
    std.mem.writeInt(u16, context.record[0..2], 8, .little);
    std.mem.writeInt(u16, context.record[2..4], 65535, .little);
    std.mem.writeInt(u16, context.record[4..6], 0x8000, .little);
    std.mem.writeInt(u32, context.record[8..12], 1, .little);
    const location = std.mem.alignBackward(usize, std.math.maxInt(usize) - 64, 32);
    try std.testing.expectError(error.IntegerOverflow, reader.inode(location / 32));
    try std.testing.expectEqual(@as(usize, 1), context.calls);
}

test "EROFS source devices resolve explicit unified and missing addresses" {
    const allocator = std.testing.allocator;
    const payload = "external source device payload";
    var encoded = try writer.encodeExternalChunksAlloc(allocator, &.{.{ .path = "file", .data = payload }}, .{ .chunk_size = 4096 });
    defer encoded.deinit(allocator);
    var primary = Context{ .bytes = encoded.image };
    var device = Context{ .bytes = encoded.device };
    const sources = [_]source_module.Source{device.input().source};
    const header = try superblock.read(primary.input());
    const devices = devices_module.Devices(source_module.Source){ .primary = primary.input(), .devices = &sources, .superblock = header };
    try devices.validate();
    const info = try devices.info(0);
    var bytes: [payload.len]u8 = undefined;
    try devices.read(1, 0, &bytes);
    try std.testing.expectEqualStrings(payload, &bytes);
    try devices.read(0, info.unified_start, &bytes);
    try std.testing.expectEqualStrings(payload, &bytes);
    var missing = devices;
    missing.devices = &.{};
    try missing.validate();
    try std.testing.expectError(error.ErofsMissingDevice, missing.read(1, 0, &bytes));
    try std.testing.expectError(error.InvalidErofs, devices.read(2, 0, &bytes));
    try std.testing.expectError(error.InvalidErofs, devices.read(1, info.blocks, &bytes));
    try std.testing.expect(primary.max_request <= 7 and device.max_request <= 7);
}

test "EROFS source devices preserve u64 physical offsets without materializing blobs" {
    const allocator = std.testing.allocator;
    var encoded = try writer.encodeExternalChunksAlloc(allocator, &.{.{ .path = "file", .data = "data" }}, .{ .chunk_size = 4096, .force_48bit = true });
    defer encoded.deinit(allocator);
    const header = try format.parseSuperblock(encoded.image);
    const slot = @as(usize, header.device_slot_offset) * 128;
    std.mem.writeInt(u32, encoded.image[slot + 64 ..][0..4], 0, .little);
    std.mem.writeInt(u16, encoded.image[slot + 72 ..][0..2], 4, .little);
    const Virtual = struct {
        offset: u64 = 0,
        fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.offset = offset;
            @memset(output, 'V');
            return output.len;
        }
    };
    var virtual = Virtual{};
    const blocks: u64 = @as(u64, 1) << 34;
    var source = source_module.Source{ .context = &virtual, .len = blocks * header.block_size, .read_at = Virtual.readAt };
    const devices = devices_module.Devices(source_module.Source){ .primary = .{ .slice = encoded.image }, .devices = (&source)[0..1], .superblock = header };
    try devices.validate();
    var output: [8]u8 = undefined;
    try devices.read(1, @as(u64, 1) << 33, &output);
    try std.testing.expectEqualStrings("VVVVVVVV", &output);
    try std.testing.expectEqual((@as(u64, 1) << 33) * header.block_size, virtual.offset);
    source.len -= 1;
    try std.testing.expectError(error.TruncatedFrame, devices.validate());
}
