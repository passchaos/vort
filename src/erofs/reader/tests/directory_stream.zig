const std = @import("std");
const writer = @import("../../writer.zig");
const archive_module = @import("../../archive.zig");
const source_archive = @import("../../source_archive.zig");
const helpers = @import("helpers.zig");
const format = @import("../../format.zig");

test "EROFS directory stream matches allocated listings across compression and metabox" {
    const allocator = std.testing.allocator;
    var entries: [300]writer.Entry = undefined;
    var names: [entries.len][24]u8 = undefined;
    for (&entries, 0..) |*entry, index| entry.* = .{ .path = try std.fmt.bufPrint(&names[index], "dir/entry-{d:0>5}", .{index}) };
    for ([_]writer.Options{
        .{},
        .{ .compression = .lz4, .compress_directories = true, .compression_extent_size = 32768 },
        .{ .compression = .lzma, .compress_directories = true, .compression_extent_size = 32768 },
        .{ .compression = .deflate, .compress_directories = true, .compression_extent_size = 32768 },
        .{ .compression = .zstandard, .compress_directories = true, .compression_extent_size = 32768 },
        .{ .compression = .lz4, .metabox = true, .compress_directories = true, .force_48bit = true },
    }) |options| {
        const image = try writer.encodeAlloc(allocator, &entries, options);
        defer allocator.free(image);
        var input = helpers.Input{ .bytes = image };
        var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{});
        defer archive.deinit();
        const inode = try archive.lookup("dir", 0, 64 * 1024);
        var expected = try archive.readDirectoryAlloc(allocator, inode, 64 * 1024);
        defer expected.deinit();
        var iterator = try archive.initDirectoryIterator(inode, 64 * 1024);
        defer iterator.deinit();
        var index: usize = 0;
        while (try iterator.next()) |entry| {
            try std.testing.expect(index < expected.entries.len);
            try std.testing.expectEqual(expected.entries[index].nid, entry.nid);
            try std.testing.expectEqual(expected.entries[index].file_type, entry.file_type);
            try std.testing.expectEqualSlices(u8, expected.entries[index].name, entry.name);
            index += 1;
        }
        try std.testing.expectEqual(expected.entries.len, index);
        try std.testing.expectEqual(inode.file_size, iterator.diagnostics().bytes_read);
        try std.testing.expectEqual(index, iterator.diagnostics().entries_yielded);
        try std.testing.expect(try iterator.next() == null);
    }
}

test "EROFS directory stream and lookup keep large directories within bounded working heap" {
    const allocator = std.testing.allocator;
    const count = 10_000;
    const entries = try allocator.alloc(writer.Entry, count);
    defer allocator.free(entries);
    const names = try allocator.alloc([12]u8, count);
    defer allocator.free(names);
    for (entries, 0..) |*entry, index| entry.* = .{ .path = try std.fmt.bufPrint(&names[index], "f{d:0>5}", .{index}) };
    for ([_]writer.Options{ .{}, .{ .compression = .lz4, .compress_directories = true, .compression_extent_size = 65536 } }) |options| {
        const image = try writer.encodeAlloc(allocator, entries, options);
        defer allocator.free(image);
        var input = helpers.Input{ .bytes = image };
        const limit: usize = if (options.compression == .stored) 32768 else 128 * 1024;
        var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = limit });
        defer archive.deinit();
        const root = try archive.rootInode();
        try std.testing.expect(root.file_size > limit);
        if (options.compression == .stored) {
            var storage: [16 * 1024]u8 = undefined;
            var fixed = std.heap.FixedBufferAllocator.init(&storage);
            const slice = try archive_module.Archive.init(image);
            var iterator = try slice.initDirectoryIterator(fixed.allocator(), try slice.rootInode(), 1024 * 1024);
            defer iterator.deinit();
            var index: usize = 0;
            while (try iterator.next()) |_| index += 1;
            try std.testing.expectEqual(@as(usize, count), index);
        }
        {
            var iterator = try archive.initDirectoryIterator(root, 1024 * 1024);
            defer iterator.deinit();
            var index: usize = 0;
            while (try iterator.next()) |entry| {
                try std.testing.expectEqualSlices(u8, entries[index].path, entry.name);
                index += 1;
            }
            try std.testing.expectEqual(@as(usize, count), index);
        }
        const last = try archive.lookup(entries[count - 1].path, 0, 1024 * 1024);
        try std.testing.expectEqual(@as(usize, 0), last.file_size);
        try std.testing.expect(archive.peakWorkingBytes() <= limit);
        try std.testing.expectEqual(@as(usize, 0), archive.working.live);
    }
}

test "EROFS directory stream errors are sticky and initialization bounds are explicit" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.Entry{.{ .path = "dir/file", .data = "payload" }};
    const image = try writer.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(image);
    var input = helpers.Input{ .bytes = image };
    var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{});
    defer archive.deinit();
    const root = try archive.rootInode();
    try std.testing.expectError(error.OutputLimitExceeded, archive.initDirectoryIterator(root, 0));
    const file = try archive.lookup("dir/file", 32, 4096);
    try std.testing.expectError(error.ErofsNotDirectory, archive.initDirectoryIterator(file, 4096));
    var iterator = try archive.initDirectoryIterator(root, 4096);
    defer iterator.deinit();
    input.fail_from_offset = 0;
    try std.testing.expectError(error.SourceReadFailed, iterator.next());
    const calls = input.calls;
    input.fail_from_offset = null;
    try std.testing.expectError(error.SourceReadFailed, iterator.next());
    try std.testing.expectEqual(calls, input.calls);
}

test "EROFS directory stream initialization and decoder allocation failures release all state" {
    const allocator = std.testing.allocator;
    var entries: [300]writer.Entry = undefined;
    var names: [entries.len][24]u8 = undefined;
    for (&entries, 0..) |*entry, index| entry.* = .{ .path = try std.fmt.bufPrint(&names[index], "entry-{d:0>5}", .{index}) };
    const image = try writer.encodeAlloc(allocator, &entries, .{ .compression = .lzma, .compress_directories = true, .compression_extent_size = 32768 });
    defer allocator.free(image);
    const Test = struct {
        fn run(work: std.mem.Allocator, bytes: []const u8) !void {
            var input = helpers.Input{ .bytes = bytes };
            var archive = try source_archive.SourceArchive.init(work, input.source(), .{});
            defer archive.deinit();
            var iterator = try archive.initDirectoryIterator(try archive.rootInode(), 64 * 1024);
            defer iterator.deinit();
            while (try iterator.next()) |_| {}
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{image});
}

test "EROFS streaming lookup validates directory suffixes after finding a name" {
    const allocator = std.testing.allocator;
    const image = try writer.encodeAlloc(allocator, &.{ .{ .path = "a" }, .{ .path = "b" } }, .{});
    defer allocator.free(image);
    const original = try archive_module.Archive.init(image);
    const root = try original.rootInode();
    const start = root.location + root.inode_size + root.xattr_size;
    const count = format.readU16(image, start + 8) / 12;
    const last = @as(usize, count - 1) * 12;
    const name = format.readU16(image, start + last + 8);
    image[start + name] = 'a';
    std.mem.writeInt(u32, image[1028..1032], format.computeSuperblockChecksum(image[1024..original.superblock.block_size]), .little);
    const slice = try archive_module.Archive.init(image);
    try std.testing.expectError(error.InvalidErofs, slice.lookup(allocator, "a", 0, 4096));
    var input = helpers.Input{ .bytes = image };
    var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{});
    defer archive.deinit();
    try std.testing.expectError(error.InvalidErofs, archive.lookup("a", 0, 4096));
    var iterator = try archive.initDirectoryIterator(try archive.rootInode(), 4096);
    defer iterator.deinit();
    try std.testing.expectEqualStrings("a", (try iterator.next()).?.name);
    try std.testing.expectError(error.InvalidErofs, iterator.next());
    try std.testing.expectEqual(last, iterator.diagnostics().entry_offset);
    try std.testing.expectEqual(@as(usize, 1), iterator.diagnostics().entries_yielded);
    try std.testing.expectError(error.InvalidErofs, iterator.next());
}
