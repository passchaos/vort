const std = @import("std");
const writer = @import("../../writer.zig");
const source_module = @import("../../../io/source.zig");
const working_module = @import("../../../io/working_allocator.zig");

const Source = struct {
    calls: usize = 0,
    max_request: usize = 0,
    fail: bool = false,
    fn read(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.calls += 1;
        self.max_request = @max(self.max_request, output.len);
        if (self.fail) return error.SourceReadFailed;
        for (output, 0..) |*byte, index| byte.* = @truncate((offset + index) *% 17);
        return output.len;
    }
};

test "EROFS resumable encoder bounds working heap while emitting a large source" {
    const size = 4 * 1024 * 1024;
    var context = Source{};
    const source = source_module.Source{ .context = &context, .len = size, .read_at = Source.read };
    var encoder: writer.Encoder = undefined;
    try encoder.init(std.testing.allocator, &.{.{ .path = "large", .source = source }}, .{}, .{ .max_working_memory = 64 * 1024 });
    defer encoder.deinit();
    const calls = context.calls;
    var buffer: [4093]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 0), (try encoder.read(buffer[0..0])).output_written);
    try std.testing.expectEqual(calls, context.calls);
    var total: usize = 0;
    var metadata: [4096]u8 = @splat(0);
    while (true) {
        const progress = try encoder.read(&buffer);
        try std.testing.expect(progress.target == .image);
        if (progress.offset < metadata.len) {
            @memcpy(metadata[@intCast(progress.offset)..][0..progress.output_written], buffer[0..progress.output_written]);
        } else {
            for (buffer[0..progress.output_written], 0..) |byte, index| {
                const expected: u8 = @truncate((progress.offset - 4096 + index) *% 17);
                try std.testing.expectEqual(expected, byte);
            }
        }
        total += progress.output_written;
        if (progress.status == .done) break;
    }
    const result = encoder.result().?;
    try std.testing.expectEqual(@as(u64, size + 4096), result.image_size);
    try std.testing.expectEqual(result.image_size, total);
    try std.testing.expect(result.peak_working_bytes < 64 * 1024);
    try std.testing.expect(context.max_request <= 64 * 1024);
    const superblock = try @import("../../format.zig").parseSuperblockWithLength(&metadata, result.image_size);
    try std.testing.expectEqual(result.image_size, try superblock.imageSize64());
}

test "EROFS resumable encoder source failures are sticky and leave output unchanged" {
    var context = Source{ .fail = true };
    const source = source_module.Source{ .context = &context, .len = 8192, .read_at = Source.read };
    var encoder: writer.Encoder = undefined;
    try encoder.init(std.testing.allocator, &.{.{ .path = "data", .source = source }}, .{}, .{});
    defer encoder.deinit();
    var buffer: [31]u8 = @splat(0xaa);
    try std.testing.expectError(error.SourceReadFailed, encoder.read(&buffer));
    for (buffer) |byte| try std.testing.expectEqual(@as(u8, 0xaa), byte);
    const calls = context.calls;
    context.fail = false;
    try std.testing.expectError(error.SourceReadFailed, encoder.read(&buffer));
    try std.testing.expectEqual(calls, context.calls);
    try std.testing.expect(encoder.result() == null);
}

test "EROFS resumable encoder handles startup budgets and every allocation failure" {
    var limited: writer.Encoder = undefined;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, limited.init(std.testing.allocator, &.{}, .{}, .{ .max_working_memory = 1 }));
    const allocator = std.testing.allocator;
    const Test = struct {
        fn run(work: std.mem.Allocator, options: writer.Options) !void {
            var encoder: writer.Encoder = undefined;
            try encoder.init(work, &.{.{ .path = "dir/data", .data = "encoder allocation failure payload\n" ** 600 }}, options, .{});
            defer encoder.deinit();
            var buffer: [137]u8 = undefined;
            while (true) if ((try encoder.read(&buffer)).status == .done) break;
        }
    };
    for ([_]writer.Options{
        .{ .compression = .lzma, .compression_extent_size = 32768, .metabox = true, .compress_directories = true },
        .{ .chunk_size = 4096 },
    }) |options| try std.testing.checkAllAllocationFailures(allocator, Test.run, .{options});
}

test "EROFS resumable encoder keeps the selected window across tiny output and releases cancellation" {
    var tracked = working_module.WorkingAllocator.init(std.testing.allocator, std.math.maxInt(usize));
    var context = Source{};
    const source = source_module.Source{ .context = &context, .len = 32768, .read_at = Source.read };
    var encoder: writer.Encoder = undefined;
    try encoder.init(tracked.allocator(), &.{.{ .path = "data", .source = source }}, .{ .compression = .lz4, .compression_extent_size = 32768 }, .{ .max_working_memory = 1024 * 1024 });
    errdefer encoder.deinit();
    const calls = context.calls;
    var buffer: [17]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 0), (try encoder.read(buffer[0..0])).output_written);
    try std.testing.expectEqual(calls, context.calls);
    _ = try encoder.read(buffer[0..1]);
    const selected_calls = context.calls;
    const live = tracked.live;
    _ = try encoder.read(&buffer);
    try std.testing.expectEqual(selected_calls, context.calls);
    try std.testing.expectEqual(live, tracked.live);
    encoder.deinit();
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
}
