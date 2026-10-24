const std = @import("std");
const archive_module = @import("../../archive.zig");
const source_archive = @import("../../source_archive.zig");
const format = @import("../../format.zig");
const partial = @import("partial_helpers.zig");
const helpers = @import("helpers.zig");

fn expectReadError(image: []const u8, expected: anyerror) !void {
    const Test = struct {
        fn sliceRead(bytes: []const u8) !void {
            const archive = try archive_module.Archive.init(bytes);
            const value = try archive.inode(96);
            const output = try archive.readFlatAllocLimited(std.testing.allocator, value, 100000);
            defer std.testing.allocator.free(output);
        }
        fn sourceRead(bytes: []const u8) !void {
            var input = helpers.Input{ .bytes = bytes };
            var archive = try source_archive.SourceArchive.init(std.testing.allocator, input.source(), .{});
            defer archive.deinit();
            const value = try archive.inode(96);
            var output = helpers.Counting{};
            _ = try archive.readToSink(value, output.sink(), .{ .max_output_len = 100000 });
        }
    };
    try std.testing.expectError(expected, Test.sliceRead(image));
    try std.testing.expectError(expected, Test.sourceRead(image));
}

test "EROFS fragment extent offsets feature guards and recursion have exact errors" {
    const allocator = std.testing.allocator;
    const original = try partial.build(allocator, 0, 16, .whole_fragment, 17);
    defer allocator.free(original);
    const head = try partial.header(original);
    const record = std.mem.alignForward(usize, head + 8, 16);
    const Mutation = struct { offset: usize, bytes: []const u8, err: anyerror };
    for ([_]Mutation{
        .{ .offset = record, .bytes = &.{ 255, 255, 255, 255 }, .err = error.InvalidErofs },
        .{ .offset = record + 4, .bytes = &.{ 255, 255, 255, 255 }, .err = error.InvalidErofs },
        .{ .offset = 1120, .bytes = &.{ 96, 0, 0, 0, 0, 0, 0, 0 }, .err = error.InvalidErofs },
        .{ .offset = head + 4, .bytes = &.{ 0x2d, 0 }, .err = error.InvalidErofs },
    }) |mutation| {
        const image = try allocator.dupe(u8, original);
        defer allocator.free(image);
        @memcpy(image[mutation.offset..][0..mutation.bytes.len], mutation.bytes);
        partial.refresh(image);
        try expectReadError(image, mutation.err);
    }
    const overflow = try allocator.dupe(u8, original);
    defer allocator.free(overflow);
    @memset(overflow[record..][0..8], 255);
    partial.refresh(overflow);
    try expectReadError(overflow, error.IntegerOverflow);
    const missing = try allocator.dupe(u8, original);
    defer allocator.free(missing);
    std.mem.writeInt(u64, missing[1120..1128], 0, .little);
    missing[1115] = 0;
    std.mem.writeInt(u32, missing[1116..1120], 0, .little);
    std.mem.writeInt(u32, missing[1104..1108], format.readU32(missing, 1104) & ~format.feature_incompat_xattr_prefixes, .little);
    partial.refresh(missing);
    try expectReadError(missing, error.InvalidErofs);
}

test "EROFS fragment extents reject directory and chunk packed containers" {
    const allocator = std.testing.allocator;
    const original = try partial.build(allocator, 0, 16, .whole_fragment, 17);
    defer allocator.free(original);
    const archive = try archive_module.Archive.init(original);
    const packed_inode = try archive.inode(archive.superblock.packed_nid);
    const directory = try allocator.dupe(u8, original);
    defer allocator.free(directory);
    std.mem.writeInt(u16, directory[packed_inode.location + 4 ..][0..2], 0x4000, .little);
    partial.refresh(directory);
    try expectReadError(directory, error.InvalidErofs);
    const chunked = try allocator.dupe(u8, original);
    defer allocator.free(chunked);
    const version = format.readU16(chunked, packed_inode.location) & 1;
    std.mem.writeInt(u16, chunked[packed_inode.location..][0..2], version | 8, .little);
    std.mem.writeInt(u32, chunked[packed_inode.location + 16 ..][0..4], 0, .little);
    std.mem.writeInt(u32, chunked[1104..1108], format.readU32(chunked, 1104) | format.feature_incompat_chunked_file, .little);
    partial.refresh(chunked);
    try expectReadError(chunked, error.UnsupportedErofsLayout);
}

test "EROFS partial extraction detects late metadata errors without decoding unrequested data" {
    const allocator = std.testing.allocator;
    const image = try partial.build(allocator, 0, 16, .holes, 17);
    defer allocator.free(image);
    const archive = try archive_module.Archive.init(image);
    const inode = try archive.inode(96);
    const record = inode.compressed_extent_start;
    std.mem.writeInt(u32, image[record + 2 * 16 + 12 ..][0..4], 5, .little);
    partial.refresh(image);
    var input = helpers.Input{ .bytes = image, .fail_from_offset = 4096 };
    var source = try source_archive.SourceArchive.init(allocator, input.source(), .{});
    defer source.deinit();
    var reader = try source.initRangeExtractor(inode, 0, 5, .{ .max_output_len = 5 });
    defer reader.deinit();
    var output: [5]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 5), (try reader.read(&output)).output_written);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0, 0 }, &output);
    try std.testing.expectError(error.InvalidErofs, reader.read(output[0..0]));
    @memset(&output, 0xa5);
    try std.testing.expectError(error.InvalidErofs, reader.read(&output));
    try std.testing.expectEqualSlices(u8, &.{ 0xa5, 0xa5, 0xa5, 0xa5, 0xa5 }, &output);
    try std.testing.expectEqual(@as(usize, 5), reader.position());
    var sink = helpers.Counting{};
    try std.testing.expectError(error.InvalidErofs, source.readRangeToSink(inode, 0, 5, sink.sink(), .{ .max_output_len = 5 }));
    try std.testing.expectEqual(@as(u64, 5), sink.length);
    try std.testing.expect(!sink.finished);
    try std.testing.expectEqual(@as(usize, 0), source.working.live);
}

test "EROFS partial decode Source and budget failures preserve output and remain sticky" {
    const allocator = std.testing.allocator;
    for (partial.algorithms, 0..) |_, index| {
        const image = try partial.build(allocator, index, 16, .partial, 17);
        defer allocator.free(image);
        const slice = try archive_module.Archive.init(image);
        const inode = try slice.inode(96);
        var input = helpers.Input{ .bytes = image };
        var source = try source_archive.SourceArchive.init(allocator, input.source(), .{});
        defer source.deinit();
        var reader = try source.initExtractor(inode, .{ .max_output_len = 17 });
        defer reader.deinit();
        input.fail_from_offset = 4096;
        var output: [17]u8 = @splat(0xa5);
        try std.testing.expectError(error.SourceReadFailed, reader.read(&output));
        input.fail_from_offset = null;
        try std.testing.expectError(error.SourceReadFailed, reader.read(&output));
        for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        try std.testing.expectEqual(@as(usize, 0), reader.position());
        try std.testing.expectEqual(@as(usize, 0), source.working.live);
        for ([_]source_archive.Limits{ .{ .max_working_memory = 1 }, .{ .max_encoded_extent_size = 1 }, .{ .max_decoded_extent_size = 1 } }, 0..) |limits, variant| {
            var limited = try source_archive.SourceArchive.init(allocator, input.source(), limits);
            defer limited.deinit();
            var state = try limited.initExtractor(inode, .{ .max_output_len = 17 });
            defer state.deinit();
            const err = if (variant == 0) error.WorkingMemoryLimitExceeded else error.OutputLimitExceeded;
            try std.testing.expectError(err, state.read(&output));
            try std.testing.expectError(err, state.read(&output));
            try std.testing.expectEqual(@as(usize, 0), limited.working.live);
        }
    }
}

test "EROFS partial extraction releases every Source and slice allocation failure" {
    const allocator = std.testing.allocator;
    const Test = struct {
        fn run(work: std.mem.Allocator, image: []const u8, expected: []const u8, source_mode: bool) !void {
            if (source_mode) {
                var input = helpers.Input{ .bytes = image };
                var archive = try source_archive.SourceArchive.init(work, input.source(), .{});
                defer archive.deinit();
                const result = try archive.extractByPathAllocLimited(work, "file", expected.len, 4096);
                defer work.free(result);
                try std.testing.expectEqualSlices(u8, expected, result);
            } else {
                const archive = try archive_module.Archive.init(image);
                const result = try archive.extractByPathAllocLimited(work, "file", expected.len, 4096);
                defer work.free(result);
                try std.testing.expectEqualSlices(u8, expected, result);
            }
        }
    };
    for (partial.algorithms, 0..) |_, index| {
        const full = try partial.fullPrefixAlloc(allocator, index);
        defer allocator.free(full);
        for ([_]partial.Kind{ .mixed, .holes }) |kind| {
            const image = try partial.build(allocator, index, 16, kind, 17);
            defer allocator.free(image);
            const expected = try partial.expectedAlloc(allocator, full, 16, kind, 17);
            defer allocator.free(expected);
            try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ image, expected, true });
            try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ image, expected, false });
        }
    }
}
