const std = @import("std");
const writer = @import("../../writer.zig");
const archive = @import("../../archive.zig");

const Context = struct {
    bytes: []const u8,
    calls: usize = 0,
    max_requested: usize = 0,
    short_read: usize = 7,

    fn input(self: *@This()) writer.Source {
        return .{ .context = self, .len = self.bytes.len, .read_at = readAt, .max_read_size = 127 };
    }

    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.calls += 1;
        self.max_requested = @max(self.max_requested, output.len);
        const start = std.math.cast(usize, offset) orelse return error.SourceReadFailed;
        if (start >= self.bytes.len) return 0;
        const count = @min(self.short_read, @min(output.len, self.bytes.len - start));
        @memcpy(output[0..count], self.bytes[start..][0..count]);
        return count;
    }
};

fn payload() [16384 + 619]u8 {
    var bytes: [16384 + 619]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x534f_5552_4345_4552);
    prng.random().bytes(bytes[0..8192]);
    @memcpy(bytes[8192..16384], bytes[0..8192]);
    @memcpy(bytes[16384..], bytes[0..619]);
    return bytes;
}

test "EROFS source input is byte identical across stored compressed and metadata layouts" {
    const allocator = std.testing.allocator;
    const data = payload();
    var input = Context{ .bytes = &data };
    var empty = Context{ .bytes = "" };
    const attributes = [_]writer.Xattr{.{ .name = "user.shared", .value = "shared" }};
    const memory_entries = [_]writer.Entry{
        .{ .path = "dir/data", .data = &data, .uid = 70_000, .xattrs = &attributes },
        .{ .path = "dir/tiny", .data = "tiny", .xattrs = &attributes },
        .{ .path = "empty" },
        .{ .path = "link", .kind = .symlink, .target = "dir/data" },
    };
    var source_entries = memory_entries;
    source_entries[0].data = &.{};
    source_entries[0].source = input.input();
    source_entries[2].source = empty.input();
    const variants = [_]writer.Options{
        .{},
        .{ .compression_extent_size = 65536 },
        .{ .compression_extent_size = 32768, .max_pcluster_size = 4096 },
        .{ .tail_packing = .fragments },
        .{ .tail_packing = .compressed_inline },
        .{ .metabox = true, .compression_extent_size = 65536 },
        .{ .compress_directories = true, .compression_extent_size = 32768 },
        .{ .metabox = true, .compress_directories = true, .compression_extent_size = 32768, .max_pcluster_size = 8192 },
    };
    for ([_]writer.Compression{ .stored, .lz4, .lzma, .deflate, .zstandard }) |compression| {
        for (variants, 0..) |variant, index| {
            if (compression == .stored and index != 0) continue;
            var options = variant;
            options.compression = compression;
            options.inode_version = .automatic;
            options.force_48bit = true;
            options.shared_xattrs = true;
            options.xattr_prefixes = &.{"user."};
            options.root_xattrs = &attributes;
            const expected = try writer.encodeAlloc(allocator, &memory_entries, options);
            defer allocator.free(expected);
            const actual = try writer.encodeAlloc(allocator, &source_entries, options);
            defer allocator.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
            const base = try archive.Archive.init(actual);
            var loaded = if (options.metabox) blk: {
                const inode = try base.inode(base.superblock.metabox_nid);
                break :blk try base.loadMetaboxAllocLimited(allocator, inode.file_size, 1024 * 1024);
            } else null;
            defer if (loaded) |*owner| owner.deinit();
            const parsed = if (loaded) |owner| owner.archive else base;
            const decoded = try parsed.extractByPathAllocLimited(allocator, "dir/data", data.len, 4096);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, &data, decoded);
        }
    }
    try std.testing.expect(input.calls > 0);
    try std.testing.expect(input.max_requested <= 127);
    try std.testing.expectEqual(@as(usize, 0), empty.calls);
}

test "EROFS source input preserves local external deduplication and holes" {
    const allocator = std.testing.allocator;
    const data = payload();
    const zeros = [_]u8{0} ** 8192;
    var input = Context{ .bytes = &data };
    var zero_input = Context{ .bytes = &zeros };
    const memory = [_]writer.Entry{
        .{ .path = "a", .data = &data },
        .{ .path = "copy", .data = &data },
        .{ .path = "zero", .data = &zeros },
    };
    var sourced = memory;
    sourced[0].data = &.{};
    sourced[0].source = input.input();
    sourced[2].data = &.{};
    sourced[2].source = zero_input.input();
    const options = writer.Options{ .chunk_size = 4096, .inode_version = .extended, .force_48bit = true };
    const expected = try writer.encodeAlloc(allocator, &memory, options);
    defer allocator.free(expected);
    const actual = try writer.encodeAlloc(allocator, &sourced, options);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
    var expected_external = try writer.encodeExternalChunksAlloc(allocator, &memory, options);
    defer expected_external.deinit(allocator);
    var actual_external = try writer.encodeExternalChunksAlloc(allocator, &sourced, options);
    defer actual_external.deinit(allocator);
    try std.testing.expectEqualSlices(u8, expected_external.image, actual_external.image);
    try std.testing.expectEqualSlices(u8, expected_external.device, actual_external.device);
    const parsed = try archive.Archive.initWithDevices(actual_external.image, &.{actual_external.device});
    const decoded = try parsed.extractByPathAllocLimited(allocator, "a", data.len, 4096);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &data, decoded);
}

test "EROFS source input reports callback errors truncation and invalid declarations" {
    const allocator = std.testing.allocator;
    var input = Context{ .bytes = "short source" };
    var truncated = input.input();
    truncated.len += 1;
    try std.testing.expectError(error.TruncatedFrame, writer.encodeAlloc(allocator, &.{.{ .path = "file", .source = truncated }}, .{}));
    const Failure = struct {
        fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
            _ = raw;
            _ = offset;
            _ = output;
            return error.SourceReadFailed;
        }
    };
    const failing = writer.Source{ .context = &input, .len = 17, .read_at = Failure.readAt };
    for ([_]writer.Options{ .{}, .{ .compression = .lz4 }, .{ .compression = .lzma, .tail_packing = .fragments }, .{ .compression = .deflate, .tail_packing = .compressed_inline }, .{ .compression = .zstandard, .compression_extent_size = 32768 } }) |options|
        try std.testing.expectError(error.SourceReadFailed, writer.encodeAlloc(allocator, &.{.{ .path = "file", .source = failing }}, options));
    try std.testing.expectError(error.InvalidErofs, writer.encodeAlloc(allocator, &.{.{ .path = "file", .data = "ambiguous", .source = input.input() }}, .{}));
    try std.testing.expectError(error.InvalidErofs, writer.encodeAlloc(allocator, &.{.{ .path = "dir", .kind = .directory, .source = input.input() }}, .{}));
    var invalid = input.input();
    invalid.max_read_size = 0;
    try std.testing.expectError(error.InvalidErofs, writer.encodeAlloc(allocator, &.{.{ .path = "file", .source = invalid }}, .{}));
    var oversized = input.input();
    oversized.len = std.math.maxInt(u64);
    input.calls = 0;
    try std.testing.expectError(error.IntegerOverflow, writer.encodeAlloc(allocator, &.{.{ .path = "file", .source = oversized }}, .{ .compression = .lz4, .inode_version = .extended }));
    try std.testing.expectEqual(@as(usize, 0), input.calls);
}

test "EROFS source writer releases every allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator, options: writer.Options) !void {
            const data = payload();
            var input = Context{ .bytes = &data };
            const encoded = try writer.encodeAlloc(allocator, &.{.{ .path = "dir/data", .source = input.input(), .uid = 70_000 }}, options);
            defer allocator.free(encoded);
        }
    };
    for ([_]writer.Options{
        .{ .chunk_size = 4096, .inode_version = .automatic },
        .{ .compression = .lz4, .compression_extent_size = 65536, .inode_version = .automatic },
        .{ .compression = .lzma, .compression_extent_size = 32768, .max_pcluster_size = 8192, .metabox = true, .compress_directories = true, .inode_version = .automatic },
    }) |options|
        try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{options});
}
