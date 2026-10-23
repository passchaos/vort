const std = @import("std");
const indexes = @import("../../compression_index.zig");
const archive_module = @import("../../archive.zig");
const source_archive = @import("../../source_archive.zig");
const helpers = @import("helpers.zig");
const fixture = @import("compact_width_helpers.zig");

test "EROFS compact item widths reject unsupported declarations before Source reads" {
    const data = [_]u8{0} ** 32;
    var input = helpers.Input{ .bytes = &data, .fail_from_offset = 0 };
    for ([_]u8{ 13, 14, 15, 255 }) |bits| {
        try std.testing.expectError(error.UnsupportedErofsFeature, indexes.readCompactInput(.{ .source = input.source() }, .{ .index_start = 0, .cluster_bits = bits, .advise = 1, .block_size = 4096 }, 0, 16));
    }
    try std.testing.expectEqual(@as(usize, 0), input.calls);
    try std.testing.expectError(error.SourceReadFailed, indexes.readCompactInput(.{ .source = input.source() }, .{ .index_start = 0, .cluster_bits = 12, .advise = 1, .block_size = 4096 }, 0, 16));
    try std.testing.expect(input.calls != 0);
}

test "EROFS unsupported wide two-byte packs preserve public range output position and zero budget" {
    const allocator = std.testing.allocator;
    for ([_]u8{ 13, 14 }) |bits| {
        const image = try fixture.build(allocator, bits, 22, true);
        defer allocator.free(image);
        const archive = try archive_module.Archive.init(image);
        const inode = try archive.inode(fixture.nid);
        const start = @as(usize, 6) << @intCast(bits);
        var slice = try archive.initRangeExtractor(allocator, inode, start, 31, .{ .max_output_len = 31 });
        defer slice.deinit();
        var output: [31]u8 = @splat(0xa5);
        try std.testing.expectError(error.UnsupportedErofsFeature, slice.read(&output));
        try std.testing.expectError(error.UnsupportedErofsFeature, slice.read(output[0..0]));
        try std.testing.expectEqual(@as(usize, 0), slice.position());
        var input = helpers.Input{ .bytes = image, .fail_from_offset = 4096 };
        var source = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 0 });
        defer source.deinit();
        var reader = try source.initRangeExtractor(try source.inode(fixture.nid), start, 31, .{ .max_output_len = 31 });
        defer reader.deinit();
        try std.testing.expectError(error.UnsupportedErofsFeature, reader.read(&output));
        try std.testing.expectError(error.UnsupportedErofsFeature, reader.read(&output));
        try std.testing.expectEqual(@as(usize, 0), reader.position());
        for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        var sink = helpers.Counting{};
        try std.testing.expectError(error.UnsupportedErofsFeature, source.readRangeToSink(inode, start, 31, sink.sink(), .{ .max_output_len = 31 }));
        try std.testing.expectEqual(@as(usize, 0), sink.calls);
        try std.testing.expect(!sink.finished);
        try std.testing.expectEqual(@as(usize, 0), source.peakWorkingBytes());
    }
}

test "EROFS wide four-byte packs and unused two-byte flags retain whole and boundary reads" {
    const allocator = std.testing.allocator;
    for ([_]u8{ 12, 13, 14 }) |bits| {
        for ([_]bool{ false, true }) |two_byte| {
            const count: usize = if (two_byte and bits > 12) 4 else 22;
            const image = try fixture.build(allocator, bits, count, two_byte);
            defer allocator.free(image);
            const archive = try archive_module.Archive.init(image);
            const inode = try archive.inode(fixture.nid);
            const decoded = try archive.readFlatAllocLimited(allocator, inode, inode.file_size);
            defer allocator.free(decoded);
            try std.testing.expectEqual(inode.file_size, decoded.len);
            for (decoded) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
            var input = helpers.Input{ .bytes = image };
            var source = try source_archive.SourceArchive.init(allocator, input.source(), .{});
            defer source.deinit();
            const cluster_size: usize = @as(usize, 1) << @intCast(bits);
            for ([_]usize{ 0, cluster_size - 3, cluster_size, inode.file_size - 31 }) |start| {
                var zeros: [31]u8 = @splat(0);
                var sink = helpers.Counting{ .expected = &zeros };
                _ = try source.readRangeToSink(inode, start, 31, sink.sink(), .{ .max_output_len = 31 });
                try std.testing.expect(sink.finished);
            }
        }
    }
}

test "EROFS whole-file compact width errors retain earlier output and remain sticky" {
    const allocator = std.testing.allocator;
    const image = try fixture.build(allocator, 13, 22, true);
    defer allocator.free(image);
    const archive = try archive_module.Archive.init(image);
    const inode = try archive.inode(fixture.nid);
    var input = helpers.Input{ .bytes = image };
    var source = try source_archive.SourceArchive.init(allocator, input.source(), .{});
    defer source.deinit();
    var reader = try source.initExtractor(inode, .{ .max_output_len = inode.file_size });
    defer reader.deinit();
    var output: [8192]u8 = undefined;
    // Planning looks ahead to the next head before releasing an extent.
    for (0..5) |_| {
        try std.testing.expectEqual(output.len, (try reader.read(&output)).output_written);
        for (output) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
    }
    @memset(&output, 0xa5);
    try std.testing.expectError(error.UnsupportedErofsFeature, reader.read(&output));
    try std.testing.expectError(error.UnsupportedErofsFeature, reader.read(&output));
    try std.testing.expectEqual(@as(usize, 5 * 8192), reader.position());
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectEqual(@as(usize, 0), source.working.live);
    var prefix = try source.initRangeExtractor(inode, 0, 31, .{ .max_output_len = 31 });
    defer prefix.deinit();
    try std.testing.expectEqual(@as(usize, 31), (try prefix.read(output[0..31])).output_written);
    try std.testing.expectError(error.UnsupportedErofsFeature, prefix.read(output[0..0]));
    try std.testing.expectEqual(@as(usize, 31), prefix.position());
    const zeros = [_]u8{0} ** 31;
    var sink = helpers.Counting{ .expected = &zeros };
    try std.testing.expectError(error.UnsupportedErofsFeature, source.readRangeToSink(inode, 0, 31, sink.sink(), .{ .max_output_len = 31 }));
    try std.testing.expectEqual(@as(u64, 31), sink.length);
    try std.testing.expect(!sink.finished);
}
