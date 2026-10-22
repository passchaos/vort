const std = @import("std");
const writer = @import("../../writer.zig");
const source_archive = @import("../../source_archive.zig");
const helpers = @import("helpers.zig");

test "EROFS Source stored extraction bounds working memory without retaining input or output" {
    const size = 4 * 1024 * 1024;
    var frame = try helpers.virtualStored(std.testing.allocator, size);
    var archive = try source_archive.SourceArchive.init(std.testing.allocator, frame.source(), .{ .max_working_memory = 64 * 1024 });
    defer archive.deinit();
    var output = helpers.Counting{ .generated = true };
    const result = try archive.extractByPathToSink("large", output.sink(), .{ .max_output_len = size }, 4096);
    try std.testing.expectEqual(@as(u64, size), result.decoded_size);
    try std.testing.expectEqual(@as(u64, size), output.length);
    try std.testing.expect(output.finished and output.max_request <= 4096);
    try std.testing.expect(frame.max_read <= 64 * 1024);
    try std.testing.expect(result.peak_working_bytes < 64 * 1024);
    try std.testing.expectEqual(@as(usize, 0), archive.working.live);
}

test "EROFS Source compressed extraction retains only one decoded extent" {
    const allocator = std.testing.allocator;
    const size = 4 * 1024 * 1024;
    const data = try allocator.alloc(u8, size);
    defer allocator.free(data);
    for (data, 0..) |*byte, index| byte.* = helpers.pattern(index);
    for ([_]writer.Options{
        .{ .compression = .lz4 },
        .{ .compression = .lz4, .compression_extent_size = 65536 },
        .{ .compression = .lzma, .compression_extent_size = 65536 },
        .{ .compression = .deflate, .compression_extent_size = 65536 },
        .{ .compression = .zstandard, .compression_extent_size = 65536 },
    }) |options| {
        const image = try writer.encodeAlloc(allocator, &.{.{ .path = "large", .data = data }}, options);
        defer allocator.free(image);
        var input = helpers.Input{ .bytes = image };
        var archive = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 2 * 1024 * 1024 });
        defer archive.deinit();
        var output = helpers.Counting{ .expected = data };
        const result = try archive.extractByPathToSink("large", output.sink(), .{ .max_output_len = size }, 4096);
        try std.testing.expectEqual(@as(u64, size), result.decoded_size);
        try std.testing.expect(result.peak_working_bytes <= 2 * 1024 * 1024);
        try std.testing.expectEqual(@as(usize, 0), archive.working.live);
        try std.testing.expect(output.finished and input.max_request <= 31);
    }
}
