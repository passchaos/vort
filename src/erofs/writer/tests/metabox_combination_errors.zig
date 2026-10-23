const std = @import("std");
const writer = @import("../../writer.zig");
const archive = @import("../../archive.zig");
const sink_module = @import("../../../io/sink.zig");
const helpers = @import("../../reader/tests/helpers.zig");
const combinations = @import("metabox_combinations.zig");

test "EROFS metabox combined Sources distinguish planning and streaming failures" {
    const allocator = std.testing.allocator;
    for ([_]writer.Options{
        .{ .compression = .lz4, .metabox = true, .tail_packing = .fragments },
        .{ .compression = .lz4, .metabox = true, .tail_packing = .compressed_inline },
        .{ .metabox = true, .chunk_size = 4096 },
    }) |options| {
        var input = helpers.Input{ .bytes = combinations.payload, .fail_from_offset = 0 };
        var entries = combinations.entries;
        // Keep this Source unique: chunk deduplication can correctly emit an
        // equal earlier memory input without reading this Source again.
        entries[2].data = "distinct memory input";
        entries[1].data = &.{};
        entries[1].source = input.source();
        var failed: writer.Encoder = undefined;
        try std.testing.expectError(error.SourceReadFailed, failed.init(allocator, &entries, options, .{}));
        input.fail_from_offset = null;
        var encoder: writer.Encoder = undefined;
        try encoder.init(allocator, &entries, options, .{});
        defer encoder.deinit();
        input.fail_from_offset = 0;
        var output: [31]u8 = @splat(0xa5);
        var failed_stream = false;
        // Other file/metadata nodes can precede this Source; only the call
        // encountering its failing read must leave the current output intact.
        while (!failed_stream) {
            @memset(&output, 0xa5);
            const result = encoder.read(&output) catch |err| {
                try std.testing.expectEqual(error.SourceReadFailed, err);
                failed_stream = true;
                continue;
            };
            try std.testing.expect(result.status != .done);
        }
        for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        const calls = input.calls;
        input.fail_from_offset = null;
        try std.testing.expectError(error.SourceReadFailed, encoder.read(&output));
        try std.testing.expectEqual(calls, input.calls);
        try std.testing.expect(encoder.result() == null);
    }
}

test "EROFS metabox combined Sink failures never finish incomplete image or device lengths" {
    const allocator = std.testing.allocator;
    const options = writer.Options{ .metabox = true, .chunk_size = 4096 };
    var image = helpers.Counting{};
    var device = helpers.Counting{ .fail_after = 0 };
    try std.testing.expectError(error.SinkWriteFailed, writer.encodeExternalChunksToSinks(allocator, &combinations.entries, options, image.sink(), device.sink(), .{}));
    try std.testing.expect(!image.finished and !device.finished);
    image = .{};
    device = .{ .fail_finish = true };
    try std.testing.expectError(error.SinkWriteFailed, writer.encodeExternalChunksToSinks(allocator, &combinations.entries, options, image.sink(), device.sink(), .{}));
    try std.testing.expect(!image.finished and !device.finished);
    image = .{ .fail_finish = true };
    device = .{};
    try std.testing.expectError(error.SinkWriteFailed, writer.encodeExternalChunksToSinks(allocator, &combinations.entries, options, image.sink(), device.sink(), .{}));
    try std.testing.expect(!image.finished and device.finished);
}

test "EROFS metabox combined layouts clean exhaustive allocation and working budget failures" {
    const allocator = std.testing.allocator;
    const Test = struct {
        fn run(work: std.mem.Allocator, options: writer.Options, external: bool) !void {
            var input = helpers.Input{ .bytes = combinations.payload };
            var entries = combinations.entries;
            entries[1].data = &.{};
            entries[1].source = input.source();
            var encoder: writer.Encoder = undefined;
            if (external) try encoder.initExternalChunks(work, &entries, options, .{}) else try encoder.init(work, &entries, options, .{});
            defer encoder.deinit();
            var image = sink_module.BufferSink.init(work);
            defer image.deinit();
            var device = sink_module.BufferSink.init(work);
            defer device.deinit();
            try combinations.collect(&encoder, &image, &device);
            const base = try archive.Archive.initWithDevices(image.bytes.items, if (external) &.{device.bytes.items} else &.{});
            var loaded = try base.loadMetaboxAllocLimited(work, 2 * 1024 * 1024, 2 * 1024 * 1024);
            defer loaded.deinit();
            const decoded = try loaded.archive.extractByPathAllocLimited(work, "dir/data", combinations.payload.len, 65536);
            defer work.free(decoded);
            try std.testing.expectEqualStrings(combinations.payload, decoded);
        }
    };
    for ([_]writer.Options{
        .{ .compression = .lzma, .metabox = true, .tail_packing = .fragments, .compression_extent_size = 32768, .compress_directories = true },
        .{ .compression = .deflate, .metabox = true, .tail_packing = .compressed_inline, .compression_extent_size = 32768 },
        .{ .metabox = true, .chunk_size = 4096, .directory_metadata_zone = true },
    }) |options| try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ options, false });
    const external_options = writer.Options{ .metabox = true, .chunk_size = 4096, .directory_metadata_zone = true };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ external_options, true });
    var encoder: writer.Encoder = undefined;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.initExternalChunks(allocator, &combinations.entries, external_options, .{ .max_working_memory = 1 }));
}
