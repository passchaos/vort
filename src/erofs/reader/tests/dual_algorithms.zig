const std = @import("std");
const archive_module = @import("../../archive.zig");
const source_archive = @import("../../source_archive.zig");
const sink_module = @import("../../../io/sink.zig");
const helpers = @import("helpers.zig");
const fixture = @import("dual_algorithm_helpers.zig");

fn verify(image: []const u8, expected: []const u8, primary: @import("../../format.zig").Compression, secondary: @import("../../format.zig").Compression) !void {
    const allocator = std.testing.allocator;
    const slice = try archive_module.Archive.init(image);
    const inode = try slice.lookup(allocator, "file", expected.len, 4096);
    try std.testing.expectEqual(primary, inode.compressed_algorithms[0].?);
    try std.testing.expectEqual(secondary, inode.compressed_algorithms[1].?);
    const decoded = try slice.readFlatAllocLimited(allocator, inode, expected.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    var input = helpers.Input{ .bytes = image };
    var source = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 2 * 1024 * 1024 });
    defer source.deinit();
    var reader = try source.initExtractor(inode, .{ .max_output_len = expected.len });
    defer reader.deinit();
    var buffer: [137]u8 = undefined;
    var position: usize = 0;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        const progress = try reader.read(buffer[0..([_]usize{ 0, 1, 17, 137 })[calls % 4]]);
        try std.testing.expectEqualSlices(u8, expected[position..][0..progress.output_written], buffer[0..progress.output_written]);
        position += progress.output_written;
        if (progress.status == .done) break;
    }
    try std.testing.expectEqual(expected.len, position);
    for ([_]usize{ 0, expected.len / 2, @min(expected.len - 1, 4091) }) |start| {
        const size = @min(expected.len - start, 31);
        var output = sink_module.BufferSink.init(allocator);
        defer output.deinit();
        _ = try source.readRangeToSink(inode, start, size, output.sink(), .{ .max_output_len = size });
        try std.testing.expectEqualSlices(u8, expected[start..][0..size], output.bytes.items);
        var range = sink_module.BufferSink.init(allocator);
        defer range.deinit();
        _ = try slice.readRangeToSink(allocator, inode, start, size, range.sink(), .{ .max_output_len = size });
        try std.testing.expectEqualSlices(u8, output.bytes.items, range.bytes.items);
    }
    try std.testing.expectEqual(@as(usize, 0), source.working.live);
    try std.testing.expect(input.max_request <= 31);
}

test "EROFS dual algorithm full compact partial and inline paths honor every codec ID pair" {
    const allocator = std.testing.allocator;
    for (fixture.algorithms) |primary| for (fixture.algorithms) |secondary| {
        for ([_]fixture.Layout{ .full, .compact, .inline_full, .inline_compact, .partial_full }) |layout| {
            const image = try fixture.build(allocator, primary, secondary, layout);
            defer allocator.free(image);
            const expected = try fixture.expectedAlloc(allocator, layout);
            defer allocator.free(expected);
            try verify(image, expected, primary, secondary);
        }
    };
}

test "EROFS secondary LZ4 rejects invalid IDs and preserves late Source failure progress" {
    const allocator = std.testing.allocator;
    const image = try fixture.build(allocator, .deflate, .lz4, .full);
    defer allocator.free(image);
    const slice = try archive_module.Archive.init(image);
    image[fixture.header_start + 6] = 0xf2;
    try std.testing.expectError(error.UnsupportedErofsCompression, slice.inode(fixture.file_nid));
    image[fixture.header_start + 6] = 0x0f;
    try std.testing.expectError(error.UnsupportedErofsCompression, slice.inode(fixture.file_nid));
    image[fixture.header_start + 6] = 2;
    fixture.refresh(image);
    var input = helpers.Input{ .bytes = image };
    var source = try source_archive.SourceArchive.init(allocator, input.source(), .{});
    defer source.deinit();
    var reader = try source.initExtractor(try source.inode(fixture.file_nid), .{ .max_output_len = 8192 });
    defer reader.deinit();
    var buffer: [4096]u8 = undefined;
    const first = try reader.read(&buffer);
    try std.testing.expectEqual(@as(usize, 4096), first.output_written);
    try std.testing.expectEqualStrings(fixture.first[0..4096], &buffer);
    input.fail_from_offset = 8192;
    @memset(&buffer, 0xa5);
    try std.testing.expectError(error.SourceReadFailed, reader.read(&buffer));
    input.fail_from_offset = null;
    try std.testing.expectError(error.SourceReadFailed, reader.read(&buffer));
    for (buffer) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectEqual(@as(usize, 4096), reader.position());
    try std.testing.expectEqual(@as(usize, 0), source.working.live);
}

test "EROFS cross-codec decoding releases every Source and slice allocation failure" {
    const allocator = std.testing.allocator;
    const Test = struct {
        fn run(work: std.mem.Allocator, image: []const u8, expected: []const u8, source_mode: bool) !void {
            if (source_mode) {
                var input = helpers.Input{ .bytes = image };
                var source = try source_archive.SourceArchive.init(work, input.source(), .{});
                defer source.deinit();
                const output = try source.extractByPathAllocLimited(work, "file", expected.len, 4096);
                defer work.free(output);
                try std.testing.expectEqualSlices(u8, expected, output);
            } else {
                const slice = try archive_module.Archive.init(image);
                const output = try slice.extractByPathAllocLimited(work, "file", expected.len, 4096);
                defer work.free(output);
                try std.testing.expectEqualSlices(u8, expected, output);
            }
        }
    };
    for (fixture.algorithms) |primary| {
        const image = try fixture.build(allocator, primary, .lz4, .inline_full);
        defer allocator.free(image);
        const expected = try fixture.expectedAlloc(allocator, .inline_full);
        defer allocator.free(expected);
        try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ image, expected, false });
        try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ image, expected, true });
    }
}

test "EROFS secondary LZ4 retains inline metabox and external-device address spaces" {
    const allocator = std.testing.allocator;
    const external = @import("device_helpers.zig");
    const high = @as(u64, 1) << 63;
    for (fixture.algorithms) |primary| {
        for ([_]fixture.Layout{ .inline_full, .inline_compact }) |layout| {
            const original = try fixture.build(allocator, primary, .lz4, layout);
            defer allocator.free(original);
            const image = try fixture.wrapMetabox(allocator, original);
            defer allocator.free(image);
            const base = try archive_module.Archive.init(image);
            var loaded = try base.loadMetaboxAllocLimited(allocator, 4096, 4096);
            defer loaded.deinit();
            const inode = try loaded.archive.inode(fixture.file_nid | high);
            try std.testing.expectEqual(@import("../../format.zig").Compression.lz4, inode.compressed_algorithms[1].?);
            const expected = try fixture.expectedAlloc(allocator, layout);
            defer allocator.free(expected);
            const decoded = try loaded.archive.readFlatAllocLimited(allocator, inode, expected.len);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, expected, decoded);
            var input = helpers.Input{ .bytes = image };
            var source = try source_archive.SourceArchive.init(allocator, input.source(), .{});
            defer source.deinit();
            const actual = try source.extractByPathAllocLimited(allocator, "file", expected.len, 4096);
            defer allocator.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
        }
        const original = try fixture.build(allocator, primary, .lz4, .full);
        defer allocator.free(original);
        const base = try archive_module.Archive.init(original);
        var owner = try external.offload(allocator, original, try base.inode(fixture.file_nid), 0);
        defer owner.deinit(allocator);
        const expected = try fixture.expectedAlloc(allocator, .full);
        defer allocator.free(expected);
        const slice = try archive_module.Archive.initWithDevices(owner.image, &.{owner.blob});
        const decoded = try slice.extractByPathAllocLimited(allocator, "file", expected.len, 4096);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, expected, decoded);
        var primary_input = helpers.Input{ .bytes = owner.image };
        var device = helpers.Input{ .bytes = owner.blob };
        const sources = [_]@import("../../../io/source.zig").Source{device.source()};
        var source = try source_archive.SourceArchive.initWithDevices(allocator, primary_input.source(), &sources, .{});
        defer source.deinit();
        const actual = try source.extractByPathAllocLimited(allocator, "file", expected.len, 4096);
        defer allocator.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
    }
}
