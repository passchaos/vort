const std = @import("std");
const writer = @import("../../writer.zig");
const archive_module = @import("../../archive.zig");
const source_archive = @import("../../source_archive.zig");
const sink_module = @import("../../../io/sink.zig");
const helpers = @import("helpers.zig");

test "EROFS Source failure paths preserve source sink and range errors" {
    const allocator = std.testing.allocator;
    const data = "D" ** 8192;
    const image = try writer.encodeAlloc(allocator, &.{.{ .path = "file", .data = data }}, .{});
    defer allocator.free(image);
    var input = helpers.Input{ .bytes = image };
    var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{});
    defer archive.deinit();
    const inode = try archive.lookup("file", data.len, 4096);
    var output = helpers.Counting{};
    input.fail_from_offset = 4096;
    try std.testing.expectError(error.SourceReadFailed, archive.readToSink(inode, output.sink(), .{ .max_output_len = data.len }));
    try std.testing.expect(!output.finished);
    input.fail_from_offset = null;
    input.bytes = image[0 .. image.len - 10];
    try std.testing.expectError(error.TruncatedFrame, archive.readToSink(inode, output.sink(), .{ .max_output_len = data.len }));
    try std.testing.expect(!output.finished);
    input.bytes = image;
    output = .{ .fail_after = 0 };
    try std.testing.expectError(error.SinkWriteFailed, archive.readToSink(inode, output.sink(), .{ .max_output_len = data.len }));
    try std.testing.expect(!output.finished);
    output = .{ .fail_finish = true };
    try std.testing.expectError(error.SinkWriteFailed, archive.readToSink(inode, output.sink(), .{ .max_output_len = data.len }));
    try std.testing.expect(!output.finished and output.calls != 0);
    output = .{};
    try std.testing.expectError(error.InvalidErofs, archive.readRangeToSink(inode, 8191, 2, output.sink(), .{ .max_output_len = data.len }));
    try std.testing.expectError(error.IntegerOverflow, archive.readRangeToSink(inode, std.math.maxInt(usize), 1, output.sink(), .{ .max_output_len = data.len }));
    try std.testing.expectError(error.OutputLimitExceeded, archive.extractByPathToSink("file", output.sink(), .{ .max_output_len = 1 }, 4096));
    try std.testing.expectError(error.ErofsEntryNotFound, archive.extractByPathToSink("missing", output.sink(), .{ .max_output_len = data.len }, 4096));
    try std.testing.expectError(error.ErofsNotRegularFile, archive.extractByPathToSink("", output.sink(), .{ .max_output_len = data.len }, 4096));
    var sink = output.sink();
    sink.max_write_size = 0;
    try std.testing.expectError(error.SinkWriteFailed, archive.extractByPathToSink("file", sink, .{ .max_output_len = data.len }, 4096));
    try std.testing.expect(!output.finished);
    try std.testing.expectEqual(@as(usize, 0), archive.working.live);
}

test "EROFS Source budget failure does not mask later caller-output allocator failure" {
    const allocator = std.testing.allocator;
    const image = try writer.encodeAlloc(allocator, &.{.{ .path = "file", .data = "D" ** 8192 }}, .{});
    defer allocator.free(image);
    const reference = try archive_module.Archive.init(image);
    const inode = try reference.lookup(allocator, "file", 8192, 4096);
    var input = helpers.Input{ .bytes = image };
    var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 1 });
    defer archive.deinit();
    var output = helpers.Counting{};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, archive.extractByPathToSink("file", output.sink(), .{ .max_output_len = 8192 }, 4096));
    try std.testing.expect(archive.working.last_failure_was_limit);
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, archive.readFlatAllocLimited(failing.allocator(), inode, 8192));
    try std.testing.expect(!archive.working.last_failure_was_limit);
}

test "EROFS Source metabox loading enforces size and working limits and can be deferred" {
    const allocator = std.testing.allocator;
    const image = try writer.encodeAlloc(allocator, &.{.{ .path = "file", .data = "metabox payload" }}, .{ .compression = .lz4, .metabox = true });
    defer allocator.free(image);
    var input = helpers.Input{ .bytes = image };
    try std.testing.expectError(error.OutputLimitExceeded, source_archive.SourceArchive.init(allocator, input.source(), .{ .max_metabox_size = 0 }));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 1 }));
    var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{ .load_metabox = false });
    defer archive.deinit();
    try std.testing.expectError(error.ErofsMissingMetabox, archive.rootInode());
    try archive.loadMetabox();
    try std.testing.expect((try archive.rootInode()).in_metabox);
    try std.testing.expect(archive.working.live != 0);
    try std.testing.expectError(error.InvalidErofs, archive.loadMetabox());
}

test "EROFS Source decoder rejects encoded and decoded extent limits" {
    const allocator = std.testing.allocator;
    const image = try writer.encodeAlloc(allocator, &.{.{ .path = "file", .data = "encoded source payload\n" ** 600 }}, .{ .compression = .lz4, .compression_extent_size = 32768 });
    defer allocator.free(image);
    for ([_]source_archive.Limits{ .{ .max_encoded_extent_size = 1 }, .{ .max_decoded_extent_size = 1 } }) |limits| {
        var input = helpers.Input{ .bytes = image };
        var archive = try source_archive.SourceArchive.init(allocator, input.source(), limits);
        defer archive.deinit();
        var output = helpers.Counting{};
        try std.testing.expectError(error.OutputLimitExceeded, archive.extractByPathToSink("file", output.sink(), .{ .max_output_len = 32768 }, 4096));
        try std.testing.expect(!output.finished);
    }
}

test "EROFS Source archive releases every initialization lookup decode and xattr allocation failure" {
    const allocator = std.testing.allocator;
    const data = "Source allocation-failure payload 0123456789\n" ** 400;
    const attributes = [_]writer.Xattr{.{ .name = "user.vort.test", .value = "attribute payload" }};
    const entries = [_]writer.Entry{.{ .path = "dir/file", .data = data, .xattrs = &attributes }};
    const Test = struct {
        fn run(work: std.mem.Allocator, image: []const u8, expected: []const u8) !void {
            var input = helpers.Input{ .bytes = image };
            var archive = try source_archive.SourceArchive.init(work, input.source(), .{});
            defer archive.deinit();
            const inode = try archive.lookup("dir/file", expected.len, 4096);
            var attrs = try archive.readXattrsAllocLimited(work, inode, 8, 4096);
            defer attrs.deinit();
            const decoded = try archive.extractByPathAllocLimited(work, "dir/file", expected.len, 4096);
            defer work.free(decoded);
            try std.testing.expectEqualSlices(u8, expected, decoded);
        }
    };
    for ([_]writer.Options{
        .{ .compression = .lzma, .compression_extent_size = 32768, .metabox = true, .compress_directories = true },
        .{ .chunk_size = 4096 },
    }) |base| {
        var options = base;
        options.xattr_prefixes = &.{"user.vort."};
        const image = try writer.encodeAlloc(allocator, &entries, options);
        defer allocator.free(image);
        try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ image, data });
    }
}
