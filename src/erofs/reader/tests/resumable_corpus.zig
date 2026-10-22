const std = @import("std");
const archive_module = @import("../../archive.zig");
const source_archive = @import("../../source_archive.zig");
const helpers = @import("helpers.zig");
const source_module = @import("../../../io/source.zig");

fn fixture(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(u8, decoder.calcSizeUpperBound(encoded.len));
    errdefer allocator.free(bytes);
    return allocator.realloc(bytes, try decoder.decode(bytes, encoded));
}

fn compareDirectory(archive: *source_archive.SourceArchive, reference: archive_module.Archive, prefix: []const u8, depth: usize) !void {
    if (depth >= 8) return error.InvalidErofs;
    const allocator = std.testing.allocator;
    const inode = try reference.lookup(allocator, prefix, 8 * 1024 * 1024, 64 * 1024);
    var directory = try reference.readDirectoryAlloc(allocator, inode, 64 * 1024);
    defer directory.deinit();
    for (directory.entries) |entry| {
        const path = if (prefix.len == 0) try allocator.dupe(u8, entry.name) else try std.fmt.allocPrint(allocator, "{s}/{s}", .{ prefix, entry.name });
        defer allocator.free(path);
        const child = try reference.inode(entry.nid);
        if (try child.fileType() == .directory) {
            try compareDirectory(archive, reference, path, depth + 1);
            continue;
        }
        const expected = try reference.readFlatAllocLimited(allocator, child, 8 * 1024 * 1024);
        defer allocator.free(expected);
        var extractor = try archive.initPathExtractor(path, .{ .max_output_len = 8 * 1024 * 1024 }, 64 * 1024);
        defer extractor.deinit();
        var buffer: [257]u8 = undefined;
        var position: usize = 0;
        while (true) {
            const capacity: usize = if (position % 2 == 0) 13 else 257;
            const progress = try extractor.read(buffer[0..capacity]);
            try std.testing.expect(progress.output_written <= expected.len - position);
            try std.testing.expectEqualSlices(u8, expected[position..][0..progress.output_written], buffer[0..progress.output_written]);
            position += progress.output_written;
            if (progress.status == .done) break;
        }
        try std.testing.expectEqual(expected.len, position);
    }
}

test "EROFS resumable extraction matches the external compact modern metabox and fragment corpus" {
    const allocator = std.testing.allocator;
    for ([_][]const u8{
        @embedFile("../../testdata/lz4-compact-big.erofs.b64"),
        @embedFile("../../testdata/lz4-full-final-big.erofs.b64"),
        @embedFile("../../testdata/lz4-compact-final-big.erofs.b64"),
        @embedFile("../../testdata/zstd-48bit.erofs.b64"),
        @embedFile("../../testdata/metabox-id.erofs.b64"),
        @embedFile("../../testdata/metabox-xattr.erofs.b64"),
        @embedFile("../../testdata/fragments-packed.erofs.b64"),
        @embedFile("../../testdata/ztailpacking-lz4.erofs.b64"),
        @embedFile("../../testdata/chunk-local.erofs.b64"),
    }) |encoded| {
        const image = try fixture(allocator, encoded);
        defer allocator.free(image);
        const base = try archive_module.Archive.init(image);
        var metabox = if (base.superblock.metabox_nid != 0) try base.loadMetaboxAllocLimited(allocator, 8 * 1024 * 1024, 8 * 1024 * 1024) else null;
        defer if (metabox) |*loaded| loaded.deinit();
        const reference = if (metabox) |loaded| loaded.archive else base;
        var input = helpers.Input{ .bytes = image };
        var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{});
        defer archive.deinit();
        try compareDirectory(&archive, reference, "", 0);
    }
}

test "EROFS resumable external-device corpus retains explicit and unified chunk semantics" {
    const allocator = std.testing.allocator;
    const image = try fixture(allocator, @embedFile("../../testdata/chunk-external.erofs.b64"));
    defer allocator.free(image);
    const bytes = try fixture(allocator, @embedFile("../../testdata/chunk-external.blob.b64"));
    defer allocator.free(bytes);
    const reference = try archive_module.Archive.initWithDevices(image, &.{bytes});
    var input = helpers.Input{ .bytes = image };
    var device = helpers.Input{ .bytes = bytes };
    const devices = [_]source_module.Source{device.source()};
    var archive = try source_archive.SourceArchive.initWithDevices(allocator, input.source(), &devices, .{});
    defer archive.deinit();
    try compareDirectory(&archive, reference, "", 0);
}
