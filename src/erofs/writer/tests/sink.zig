const std = @import("std");
const writer = @import("../../writer.zig");
const archive = @import("../../archive.zig");
const io_sink = @import("../../../io/sink.zig");

fn payload() [16384 + 619]u8 {
    var data: [16384 + 619]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x5354_5245_414d_4552);
    prng.random().bytes(data[0..8192]);
    @memcpy(data[8192..16384], data[0..8192]);
    @memcpy(data[16384..], data[0..619]);
    return data;
}

test "EROFS sink output is byte identical for every compression and metadata layout" {
    const allocator = std.testing.allocator;
    const data = payload();
    const attributes = [_]writer.Xattr{.{ .name = "user.shared", .value = "same attribute" }};
    const entries = [_]writer.Entry{
        .{ .path = "dir/data", .data = &data, .uid = 70_000, .xattrs = &attributes },
        .{ .path = "tiny", .data = "T", .xattrs = &attributes },
        .{ .path = "empty" },
        .{ .path = "link", .kind = .symlink, .target = "dir/data" },
    };
    const variants = [_]writer.Options{
        .{},
        .{ .compression_extent_size = 32768 },
        .{ .compression_extent_size = 32768, .max_pcluster_size = 8192 },
        .{ .tail_packing = .fragments },
        .{ .tail_packing = .compressed_inline },
        .{ .metabox = true },
        .{ .metabox = true, .compress_directories = true },
        .{ .metabox = true, .compress_directories = true, .compression_extent_size = 32768, .max_pcluster_size = 8192 },
    };
    for ([_]writer.Compression{ .stored, .lz4, .lzma, .deflate, .zstandard }) |compression| {
        for (variants, 0..) |variant, index| {
            if (compression == .stored and index != 0 and index != 5) continue;
            var options = variant;
            options.compression = compression;
            options.inode_version = .automatic;
            options.shared_xattrs = true;
            options.xattr_prefixes = &.{"user."};
            options.root_xattrs = &attributes;
            options.force_48bit = true;
            const expected = try writer.encodeAlloc(allocator, &entries, options);
            defer allocator.free(expected);
            var output = io_sink.BufferSink.init(allocator);
            defer output.deinit();
            var sink = output.sink();
            sink.max_write_size = 127;
            const result = try writer.encodeToSink(allocator, &entries, options, sink, .{});
            try std.testing.expectEqual(expected.len, result.image_size);
            try std.testing.expect(result.peak_working_bytes <= 64 * 1024 * 1024);
            try std.testing.expectEqualSlices(u8, expected, output.bytes.items);
        }
    }
}

test "EROFS sink chunks preserve padding deduplication holes and external devices" {
    const allocator = std.testing.allocator;
    var padded: [4096]u8 = @splat(0);
    padded[0] = 'X';
    const data = payload();
    const entries = [_]writer.Entry{
        .{ .path = "partial", .data = "X" },
        .{ .path = "padded", .data = &padded },
        .{ .path = "data", .data = &data },
        .{ .path = "copy", .data = &data },
        .{ .path = "hole", .data = &([_]u8{0} ** 8192) },
    };
    const options = writer.Options{ .chunk_size = 4096, .inode_version = .extended, .force_48bit = true };
    const expected = try writer.encodeAlloc(allocator, &entries, options);
    defer allocator.free(expected);
    var output = io_sink.BufferSink.init(allocator);
    defer output.deinit();
    _ = try writer.encodeToSink(allocator, &entries, options, output.sink(), .{});
    try std.testing.expectEqualSlices(u8, expected, output.bytes.items);
    var external = try writer.encodeExternalChunksAlloc(allocator, &entries, options);
    defer external.deinit(allocator);
    var device = io_sink.BufferSink.init(allocator);
    defer device.deinit();
    const result = try writer.encodeExternalChunksToSinks(allocator, &entries, options, output.sink(), device.sink(), .{});
    try std.testing.expectEqual(external.device.len, result.device_size);
    try std.testing.expectEqualSlices(u8, external.image, output.bytes.items);
    try std.testing.expectEqualSlices(u8, external.device, device.bytes.items);
    const parsed = try archive.Archive.initWithDevices(output.bytes.items, &.{device.bytes.items});
    const decoded = try parsed.extractByPathAllocLimited(allocator, "data", data.len, 4096);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &data, decoded);
}

const Counting = struct {
    calls: usize = 0,
    max_request: usize = 0,
    length: u64 = 0,
    finished: bool = false,
    fail_after: ?usize = null,
    fn writeAt(raw: *anyopaque, offset: u64, bytes: []const u8) error{SinkWriteFailed}!usize {
        const self: *Counting = @ptrCast(@alignCast(raw));
        if (self.fail_after) |limit| if (self.calls >= limit) return error.SinkWriteFailed;
        self.calls += 1;
        self.max_request = @max(self.max_request, bytes.len);
        self.length = @max(self.length, offset + bytes.len);
        return bytes.len;
    }
    fn setLen(raw: *anyopaque, length: u64) error{SinkWriteFailed}!void {
        const self: *Counting = @ptrCast(@alignCast(raw));
        self.length = length;
        self.finished = true;
    }
    fn sink(self: *Counting) writer.Sink {
        return .{ .context = self, .write_at = writeAt, .set_len = setLen, .max_write_size = 4096 };
    }
};

test "EROFS sink streams large sources under an explicit working memory limit" {
    const SourceContext = struct {
        fn readAt(raw: *anyopaque, offset: u64, bytes: []u8) error{SourceReadFailed}!usize {
            _ = raw;
            for (bytes, 0..) |*byte, index| byte.* = @truncate((offset + index) *% 17);
            return bytes.len;
        }
    };
    var output = Counting{};
    const source = writer.Source{ .context = &output, .len = 4 * 1024 * 1024, .read_at = SourceContext.readAt };
    const result = try writer.encodeToSink(std.testing.allocator, &.{.{ .path = "large", .source = source }}, .{}, output.sink(), .{ .max_working_memory = 64 * 1024 });
    try std.testing.expect(result.image_size > source.len);
    try std.testing.expect(result.peak_working_bytes < 64 * 1024);
    try std.testing.expectEqual(result.image_size, output.length);
    try std.testing.expect(output.finished and output.max_request <= 4096);
    var limited = Counting{};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, writer.encodeToSink(std.testing.allocator, &.{.{ .path = "large", .source = source }}, .{}, limited.sink(), .{ .max_working_memory = 1 }));
    try std.testing.expectEqual(@as(usize, 0), limited.calls);
}

test "EROFS compressed and chunk sinks bound payload memory for large sources" {
    const SourceContext = struct {
        fn readAt(raw: *anyopaque, offset: u64, bytes: []u8) error{SourceReadFailed}!usize {
            _ = raw;
            for (bytes, 0..) |*byte, index| byte.* = @truncate((offset + index) *% 17);
            return bytes.len;
        }
    };
    var context: u8 = 0;
    const source = writer.Source{ .context = &context, .len = 4 * 1024 * 1024, .read_at = SourceContext.readAt };
    for ([_]writer.Options{ .{ .compression = .lz4 }, .{ .compression = .lz4, .compression_extent_size = 65536 }, .{ .chunk_size = 4096 } }) |options| {
        var output = Counting{};
        const limit: usize = if (options.compression == .lz4) 1024 * 1024 else 64 * 1024;
        const result = try writer.encodeToSink(std.testing.allocator, &.{.{ .path = "large", .source = source }}, options, output.sink(), .{ .max_working_memory = limit });
        try std.testing.expect(result.peak_working_bytes <= limit);
        try std.testing.expectEqual(result.image_size, output.length);
        try std.testing.expect(output.finished);
    }
}

test "EROFS sink retains unique chunk descriptors instead of all chunk payloads" {
    const SourceContext = struct {
        fn readAt(raw: *anyopaque, offset: u64, bytes: []u8) error{SourceReadFailed}!usize {
            _ = raw;
            for (bytes, 0..) |*byte, index| {
                const absolute = offset + index;
                const within = absolute % 65536;
                const chunk = absolute / 65536;
                byte.* = if (within < 4) @truncate(chunk >> @as(u6, @intCast(within * 8))) else @truncate(within *% 17);
            }
            return bytes.len;
        }
    };
    var output = Counting{};
    const source = writer.Source{ .context = &output, .len = 4 * 1024 * 1024, .read_at = SourceContext.readAt };
    const result = try writer.encodeToSink(std.testing.allocator, &.{.{ .path = "unique", .source = source }}, .{ .chunk_size = 65536 }, output.sink(), .{ .max_working_memory = 64 * 1024 });
    try std.testing.expect(result.image_size > source.len);
    try std.testing.expect(result.peak_working_bytes < 64 * 1024);
    try std.testing.expect(output.finished);
}

test "EROFS sink reports source and final-length failures without masking errors" {
    const FailedSource = struct {
        fn readAt(raw: *anyopaque, offset: u64, bytes: []u8) error{SourceReadFailed}!usize {
            _ = raw;
            _ = offset;
            _ = bytes;
            return error.SourceReadFailed;
        }
    };
    const FailedFinish = struct {
        fn setLen(raw: *anyopaque, length: u64) error{SinkWriteFailed}!void {
            _ = raw;
            _ = length;
            return error.SinkWriteFailed;
        }
    };
    var output = Counting{};
    const source = writer.Source{ .context = &output, .len = 8192, .read_at = FailedSource.readAt };
    try std.testing.expectError(error.SourceReadFailed, writer.encodeToSink(std.testing.allocator, &.{.{ .path = "file", .source = source }}, .{}, output.sink(), .{}));
    try std.testing.expect(!output.finished);
    var sink = output.sink();
    sink.set_len = FailedFinish.setLen;
    try std.testing.expectError(error.SinkWriteFailed, writer.encodeToSink(std.testing.allocator, &.{}, .{}, sink, .{}));
    try std.testing.expect(!output.finished);
}

test "EROFS sink write errors leave incomplete output uncommitted" {
    var output = Counting{ .fail_after = 1 };
    try std.testing.expectError(error.SinkWriteFailed, writer.encodeToSink(std.testing.allocator, &.{.{ .path = "file", .data = "D" ** 8192 }}, .{}, output.sink(), .{}));
    try std.testing.expect(!output.finished);
    var sink = output.sink();
    sink.max_write_size = 0;
    try std.testing.expectError(error.SinkWriteFailed, writer.encodeToSink(std.testing.allocator, &.{}, .{}, sink, .{}));
}

test "EROFS sink writer releases every allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator, options: writer.Options) !void {
            const data = payload();
            var output = Counting{};
            _ = try writer.encodeToSink(allocator, &.{.{ .path = "dir/data", .data = &data }}, options, output.sink(), .{});
        }
    };
    for ([_]writer.Options{ .{ .compression = .lzma, .compression_extent_size = 32768, .metabox = true, .compress_directories = true }, .{ .chunk_size = 4096 } }) |options|
        try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{options});
}

test "EROFS external sink handles empty devices and device write failures" {
    const allocator = std.testing.allocator;
    var output = Counting{};
    var device = Counting{};
    const empty = try writer.encodeExternalChunksToSinks(allocator, &.{}, .{ .chunk_size = 4096 }, output.sink(), device.sink(), .{});
    try std.testing.expectEqual(@as(u64, 0), empty.device_size);
    try std.testing.expect(output.finished and device.finished);
    output = .{};
    device = .{ .fail_after = 0 };
    try std.testing.expectError(error.SinkWriteFailed, writer.encodeExternalChunksToSinks(allocator, &.{.{ .path = "file", .data = "device payload" }}, .{ .chunk_size = 8192 }, output.sink(), device.sink(), .{}));
    try std.testing.expect(!output.finished and !device.finished);
    const Test = struct {
        fn run(backing: std.mem.Allocator) !void {
            var primary = Counting{};
            var external = Counting{};
            _ = try writer.encodeExternalChunksToSinks(backing, &.{.{ .path = "file", .data = "device payload" }}, .{ .chunk_size = 8192 }, primary.sink(), external.sink(), .{});
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}
