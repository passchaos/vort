const std = @import("std");
const archive_module = @import("../../archive.zig");
const source_archive = @import("../../source_archive.zig");
const source_module = @import("../../../io/source.zig");
const format = @import("../../format.zig");
const helpers = @import("helpers.zig");
const fixture = @import("device_helpers.zig");
const partial = @import("partial_helpers.zig");

test "EROFS ranges avoid missing devices outside their requested data" {
    const allocator = std.testing.allocator;
    const original = try partial.build(allocator, 0, 16, .holes, 17);
    defer allocator.free(original);
    const base = try archive_module.Archive.init(original);
    var owner = try fixture.offload(allocator, original, try base.inode(96), 3);
    defer owner.deinit(allocator);
    const slice = try archive_module.Archive.init(owner.image);
    const inode = try slice.inode(96);
    var input = helpers.Input{ .bytes = owner.image };
    var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 0 });
    defer archive.deinit();
    for ([_]usize{ 0, 22 }) |start| {
        var output = helpers.Counting{};
        const size: usize = if (start == 0) 5 else 7;
        _ = try archive.readRangeToSink(inode, start, size, output.sink(), .{ .max_output_len = size });
        try std.testing.expect(output.finished and output.length == size);
    }
    try std.testing.expectEqual(@as(usize, 0), archive.peakWorkingBytes());
    var output = helpers.Counting{};
    try std.testing.expectError(error.ErofsMissingDevice, archive.readRangeToSink(inode, 5, 1, output.sink(), .{ .max_output_len = 1 }));
    try std.testing.expect(!output.finished);
    try std.testing.expectError(error.ErofsMissingDevice, slice.readFlatAllocLimited(allocator, inode, 29));
}

test "EROFS device Source failures preserve caller output and decoder cache progress" {
    const allocator = std.testing.allocator;
    for (partial.algorithms, 0..) |_, index| {
        var owner = try fixture.modern(allocator, index, 16, 3);
        defer owner.deinit(allocator);
        const slice = try archive_module.Archive.initWithDevices(owner.image, &.{owner.blob});
        const inode = try slice.inode(96);
        var primary = helpers.Input{ .bytes = owner.image };
        var device = helpers.Input{ .bytes = owner.blob };
        const sources = [_]source_module.Source{device.source()};
        var archive = try source_archive.SourceArchive.initWithDevices(allocator, primary.source(), &sources, .{});
        defer archive.deinit();
        var failed = try archive.initExtractor(inode, .{ .max_output_len = 17 });
        defer failed.deinit();
        device.fail_from_offset = 0;
        var output: [17]u8 = @splat(0xa5);
        try std.testing.expectError(error.SourceReadFailed, failed.read(&output));
        device.fail_from_offset = null;
        try std.testing.expectError(error.SourceReadFailed, failed.read(&output));
        for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        try std.testing.expectEqual(@as(usize, 0), archive.working.live);
        var reader = try archive.initExtractor(inode, .{ .max_output_len = 17 });
        defer reader.deinit();
        try std.testing.expectEqual(@as(usize, 1), (try reader.read(output[0..1])).output_written);
        const reads = device.calls;
        device.fail_from_offset = 0;
        var position: usize = 1;
        while (true) {
            const progress = try reader.read(output[position..]);
            position += progress.output_written;
            if (progress.status == .done) break;
        }
        try std.testing.expectEqual(@as(usize, 17), position);
        try std.testing.expectEqual(reads, device.calls);
        const expected = try partial.fullPrefixAlloc(allocator, index);
        defer allocator.free(expected);
        try std.testing.expectEqualSlices(u8, expected[0..17], &output);
        device.fail_from_offset = null;
        device.bytes = owner.blob[0..4098];
        var truncated = try archive.initExtractor(inode, .{ .max_output_len = 17 });
        defer truncated.deinit();
        @memset(&output, 0xa5);
        try std.testing.expectError(error.TruncatedFrame, truncated.read(&output));
        for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        try std.testing.expectEqual(@as(usize, 0), archive.working.live);
    }
}

test "EROFS mapped byte extent bounds distinguish device truncation and integer overflow" {
    const allocator = std.testing.allocator;
    var owner = try fixture.modern(allocator, 0, 16, 3);
    defer owner.deinit(allocator);
    const base = try archive_module.Archive.init(owner.image);
    const inode = try base.inode(96);
    try std.testing.expectError(error.TruncatedFrame, archive_module.Archive.initWithDevices(owner.image, &.{owner.blob[0 .. owner.blob.len - 1]}));
    const table = @as(usize, base.superblock.device_slot_offset) * 128;
    std.mem.writeInt(u32, owner.image[table + 64 ..][0..4], 1, .little);
    fixture.refresh(owner.image);
    const short_region = try archive_module.Archive.initWithDevices(owner.image, &.{owner.blob});
    try std.testing.expectError(error.InvalidErofs, short_region.readFlatAllocLimited(allocator, inode, 17));
    std.mem.writeInt(u32, owner.image[table + 64 ..][0..4], @intCast(owner.blob.len / 4096), .little);
    @memset(owner.image[inode.compressed_extent_start + 4 ..][0..8], 255);
    fixture.refresh(owner.image);
    const overflow = try archive_module.Archive.initWithDevices(owner.image, &.{owner.blob});
    try std.testing.expectError(error.IntegerOverflow, overflow.readFlatAllocLimited(allocator, inode, 17));
}

test "EROFS external extent extraction releases every allocation failure" {
    const allocator = std.testing.allocator;
    const Test = struct {
        fn run(work: std.mem.Allocator, image: []const u8, blob: []const u8, expected: []const u8, source_mode: bool) !void {
            if (source_mode) {
                var primary = helpers.Input{ .bytes = image };
                var device = helpers.Input{ .bytes = blob };
                const sources = [_]source_module.Source{device.source()};
                var archive = try source_archive.SourceArchive.initWithDevices(work, primary.source(), &sources, .{});
                defer archive.deinit();
                const result = try archive.extractByPathAllocLimited(work, "file", 17, 4096);
                defer work.free(result);
                try std.testing.expectEqualSlices(u8, expected, result);
            } else {
                const archive = try archive_module.Archive.initWithDevices(image, &.{blob});
                const result = try archive.extractByPathAllocLimited(work, "file", 17, 4096);
                defer work.free(result);
                try std.testing.expectEqualSlices(u8, expected, result);
            }
        }
    };
    for (partial.algorithms, 0..) |_, index| {
        var owner = try fixture.modern(allocator, index, 16, 3);
        defer owner.deinit(allocator);
        const expected = try partial.fullPrefixAlloc(allocator, index);
        defer allocator.free(expected);
        try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ owner.image, owner.blob, expected[0..17], true });
        try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ owner.image, owner.blob, expected[0..17], false });
    }
}
