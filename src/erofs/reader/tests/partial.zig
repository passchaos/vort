const std = @import("std");
const archive_module = @import("../../archive.zig");
const source_archive = @import("../../source_archive.zig");
const sink_module = @import("../../../io/sink.zig");
const helpers = @import("helpers.zig");
const partial = @import("partial_helpers.zig");

fn streamSlice(allocator: std.mem.Allocator, archive: archive_module.Archive, inode: archive_module.Inode, expected: []const u8) !void {
    var reader = try archive.initExtractor(allocator, inode, .{ .max_output_len = expected.len });
    defer reader.deinit();
    var buffer: [137]u8 = undefined;
    const schedule = [_]usize{ 0, 1, 7, 31, 137 };
    var calls: usize = 0;
    var position: usize = 0;
    while (true) : (calls += 1) {
        const progress = try reader.read(buffer[0..schedule[calls % schedule.len]]);
        try std.testing.expectEqualSlices(u8, expected[position..][0..progress.output_written], buffer[0..progress.output_written]);
        position += progress.output_written;
        try std.testing.expectEqual(position, reader.position());
        if (progress.status == .done) break;
    }
    try std.testing.expectEqual(expected.len, position);
}

test "EROFS partial extents holes fragments and legacy heads stream every codec and record size" {
    const allocator = std.testing.allocator;
    for (partial.algorithms, 0..) |_, index| {
        const full = try partial.fullPrefixAlloc(allocator, index);
        defer allocator.free(full);
        for ([_]u8{ 0, 4, 8, 16, 32 }) |record_size| {
            for ([_]partial.Kind{ .partial, .whole_fragment, .mixed, .holes }) |kind| {
                if (record_size == 0 and kind != .partial) continue;
                const image = try partial.build(allocator, index, record_size, kind, 17);
                defer allocator.free(image);
                const expected = try partial.expectedAlloc(allocator, full, record_size, kind, 17);
                defer allocator.free(expected);
                const slice = try archive_module.Archive.init(image);
                const inode = try slice.lookup(allocator, "file", expected.len, 4096);
                try streamSlice(allocator, slice, inode, expected);
                const decoded = try slice.readFlatAllocLimited(allocator, inode, expected.len);
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, expected, decoded);
                var input = helpers.Input{ .bytes = image };
                var source = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 2 * 1024 * 1024 });
                defer source.deinit();
                var reader = try source.initExtractor(inode, .{ .max_output_len = expected.len });
                defer reader.deinit();
                var buffer: [31]u8 = undefined;
                var position: usize = 0;
                while (true) {
                    const progress = try reader.read(&buffer);
                    try std.testing.expectEqualSlices(u8, expected[position..][0..progress.output_written], buffer[0..progress.output_written]);
                    position += progress.output_written;
                    if (progress.status == .done) break;
                }
                try std.testing.expectEqual(expected.len, position);
                for ([_]usize{ 0, expected.len / 2, expected.len - 1, expected.len }) |start| {
                    const size = @min(expected.len - start, 11);
                    var output = sink_module.BufferSink.init(allocator);
                    defer output.deinit();
                    _ = try source.readRangeToSink(inode, start, size, output.sink(), .{ .max_output_len = size });
                    try std.testing.expectEqualSlices(u8, expected[start..][0..size], output.bytes.items);
                    var slice_output = sink_module.BufferSink.init(allocator);
                    defer slice_output.deinit();
                    _ = try slice.readRangeToSink(allocator, inode, start, size, slice_output.sink(), .{ .max_output_len = size });
                    try std.testing.expectEqualSlices(u8, expected[start..][0..size], slice_output.bytes.items);
                }
                try std.testing.expectEqual(@as(usize, 0), source.working.live);
                try std.testing.expect(input.max_request <= 31);
            }
        }
    }
}

test "EROFS explicit partial decoding crops to requested prefixes within independent budgets" {
    const allocator = std.testing.allocator;
    for (partial.algorithms, 0..) |_, index| {
        const image = try partial.build(allocator, index, 16, .mixed, 17);
        defer allocator.free(image);
        const slice = try archive_module.Archive.init(image);
        const inode = try slice.lookup(allocator, "file", 26, 4096);
        var input = helpers.Input{ .bytes = image };
        var source = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 128 * 1024, .max_decoded_extent_size = 1 });
        defer source.deinit();
        var one: [1]u8 = undefined;
        var reader = try source.initRangeExtractor(inode, 0, 1, .{ .max_output_len = 1, .max_packed_extent_len = 0 });
        defer reader.deinit();
        const progress = try reader.read(&one);
        try std.testing.expectEqual(@as(usize, 1), progress.output_written);
        try std.testing.expectEqual(@as(u8, 6), one[0]);
        try std.testing.expectEqual(.done, (try reader.read(one[0..0])).status);
        try std.testing.expect(source.peakWorkingBytes() < 128 * 1024);
        var larger = helpers.Counting{};
        try std.testing.expectError(error.OutputLimitExceeded, source.readRangeToSink(inode, 0, 2, larger.sink(), .{ .max_output_len = 2 }));
        try std.testing.expectError(error.OutputLimitExceeded, source.readRangeToSink(inode, 17, 9, larger.sink(), .{ .max_output_len = 9, .max_packed_extent_len = 1 }));
        try std.testing.expectEqual(@as(usize, 0), source.working.live);
        var storage: [128 * 1024]u8 = undefined;
        var fixed = std.heap.FixedBufferAllocator.init(&storage);
        var slice_reader = try slice.initRangeExtractor(fixed.allocator(), inode, 0, 1, .{ .max_output_len = 1, .max_packed_extent_len = 0 });
        defer slice_reader.deinit();
        try std.testing.expectEqual(@as(usize, 1), (try slice_reader.read(&one)).output_written);
        try std.testing.expectEqual(.done, (try slice_reader.read(one[0..0])).status);
    }
}

test "EROFS sparse extent holes do not read their unused physical addresses" {
    const allocator = std.testing.allocator;
    const image = try partial.build(allocator, 0, 32, .holes, 17);
    defer allocator.free(image);
    const slice = try archive_module.Archive.init(image);
    const inode = try slice.lookup(allocator, "file", 29, 4096);
    var input = helpers.Input{ .bytes = image, .fail_from_offset = 4096 };
    var source = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 0 });
    defer source.deinit();
    var result = helpers.Counting{};
    _ = try source.readRangeToSink(inode, 0, 5, result.sink(), .{ .max_output_len = 5 });
    try std.testing.expectEqual(@as(u64, 5), result.length);
    result = .{};
    _ = try source.readRangeToSink(inode, 22, 7, result.sink(), .{ .max_output_len = 7 });
    try std.testing.expectEqual(@as(u64, 7), result.length);
    try std.testing.expectEqual(@as(usize, 0), source.peakWorkingBytes());
}

test "EROFS legacy partial references honor one-block sizes across noncontiguous addresses" {
    const allocator = std.testing.allocator;
    for (partial.algorithms, 0..) |_, index| {
        const base = try partial.build(allocator, index, 0, .partial, 4096);
        defer allocator.free(base);
        const original = try archive_module.Archive.init(base);
        const value = try original.inode(96);
        const image = try allocator.alloc(u8, 1025 * 4096);
        defer allocator.free(image);
        @memset(image, 0);
        @memcpy(image[0..base.len], base);
        image[1024 * 4096] = 'B';
        if (value.inode_size == 32) std.mem.writeInt(u32, image[value.location + 8 ..][0..4], 4097, .little) else std.mem.writeInt(u64, image[value.location + 8 ..][0..8], 4097, .little);
        std.mem.writeInt(u16, image[value.compressed_index_start + 8 ..][0..2], 0, .little);
        std.mem.writeInt(u16, image[value.compressed_index_start + 10 ..][0..2], 0, .little);
        std.mem.writeInt(u32, image[value.compressed_index_start + 12 ..][0..4], 1024, .little);
        std.mem.writeInt(u32, image[1060..1064], 1025, .little);
        partial.refresh(image);
        const full = try partial.fullPrefixAlloc(allocator, index);
        defer allocator.free(full);
        const expected = try std.mem.concat(allocator, u8, &.{ full, "B" });
        defer allocator.free(expected);
        const slice = try archive_module.Archive.init(image);
        const inode = try slice.inode(96);
        var input = helpers.Input{ .bytes = image };
        var source = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 128 * 1024, .max_encoded_extent_size = 4096 });
        defer source.deinit();
        var output = helpers.Counting{ .expected = expected };
        _ = try source.readToSink(inode, output.sink(), .{ .max_output_len = 4097 });
        try std.testing.expect(output.finished and output.length == expected.len);
        try std.testing.expect(source.peakWorkingBytes() < 128 * 1024);
        const decoded = try slice.readFlatAllocLimited(allocator, inode, 4097);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, expected, decoded);
    }
}
