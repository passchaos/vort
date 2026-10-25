//! Public one-shot and container consumers of bounded parallel XZ encoding.
//! The root is supplied by its named test hook, avoiding an import cycle.
const std = @import("std");
const target_supports_parallel = @import("../xz/parallel/types.zig").target_supports_parallel;
const a = std.testing.allocator;
const block_size: usize = 1024;

pub fn contracts(comptime V: type) !void {
    try publicInto(V);
    try zipConsumer(V);
    try tarConsumer(V);
    try cpioConsumer(V);
    try publicationFailures(V);
}

fn payload() [8192]u8 {
    const text = "parallel XZ public consumer data | abcdefghabcdefgh | metadata\n";
    var bytes: [8192]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = if (index % 97 == 0) @truncate(index / 97) else text[index % text.len];
    return bytes;
}

fn options(comptime V: type, profile: *V.XzParallelProfile) V.XzEncodeOptions {
    return .{
        .block_size = block_size,
        .dictionary_size = 4096,
        .chunk_size = block_size,
        .check = .crc64,
        .parallel = .{
            .io = std.testing.io,
            .worker_count = 3,
            .max_inflight_blocks = 3,
            .max_inflight_bytes = 3 * block_size,
            .max_working_memory = 64 * 1024 * 1024,
            .profile = profile,
        },
    };
}

fn checkProfile(comptime V: type, profile: V.XzParallelProfile, expected_blocks: usize) !void {
    try std.testing.expect(expected_blocks > 2);
    try std.testing.expectEqual(expected_blocks, profile.completed_blocks);
    try std.testing.expectEqual(expected_blocks, profile.published_blocks);
    try std.testing.expect(profile.peak_requested_bytes > 0);
    try std.testing.expect(profile.peak_requested_bytes <= 64 * 1024 * 1024);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expect(profile.peak_inflight_blocks <= 3);
    try std.testing.expect(profile.peak_inflight_bytes <= 3 * block_size);
    if (comptime target_supports_parallel) {
        try std.testing.expectEqual(@as(usize, 3), profile.workers_started);
        try std.testing.expect(!profile.serial_fallback);
        try std.testing.expect(profile.peak_active_workers > 0 and profile.peak_active_workers <= 3);
    } else {
        try std.testing.expectEqual(@as(usize, 0), profile.workers_started);
        try std.testing.expect(profile.serial_fallback);
    }
}

fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn publicInto(comptime V: type) !void {
    try std.testing.expect(V.XzParallelOptions == V.xz.ParallelOptions);
    try std.testing.expect(V.XzParallelProfile == V.xz.ParallelProfile);
    try std.testing.expect((@as(V.XzEncodeOptions, .{})).parallel == null);
    const input = payload();
    var profile: V.XzParallelProfile = .{};
    const parallel_options = options(V, &profile);
    var serial_options = parallel_options;
    serial_options.parallel = null;
    const expected = try V.encodeXzAlloc(a, &input, serial_options);
    defer a.free(expected);
    const output = try a.alloc(u8, expected.len + 16);
    defer a.free(output);
    @memset(output, 0xa5);
    const written = try V.encodeXzInto(a, &input, output, parallel_options);
    try std.testing.expectEqualSlices(u8, expected, output[0..written]);
    try untouched(output[written..]);
    const info = try V.xz.inspect(a, output[0..written]);
    try std.testing.expectEqual(input.len / block_size, info.block_count);
    try std.testing.expectEqual(input.len, info.uncompressed_size);
    try checkProfile(V, profile, info.block_count);
    const decoded = try V.xz.decodeAlloc(a, output[0..written]);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
    @memset(output, 0xa5);
    try std.testing.expectError(error.OutputTooSmall, V.encodeXzInto(a, &input, output[0 .. expected.len - 1], parallel_options));
    try untouched(output);
    try checkProfile(V, profile, info.block_count);
}

fn zipConsumer(comptime V: type) !void {
    const input = payload();
    const entries = [_]V.zip.EncodeEntry{.{
        .name = "parallel.bin",
        .data = &input,
        .method = .xz,
        .comment = "bounded parallel XZ",
        .modified = .{ .date = 0x5a3f, .time = 0xbf7d },
    }};
    var profile: V.XzParallelProfile = .{};
    var parallel_options: V.zip.EncodeOptions = .{ .xz_options = options(V, &profile), .archive_comment = "XZ container consumer" };
    const bytes = try V.zip.encodeAlloc(a, &entries, parallel_options);
    defer a.free(bytes);
    var serial_options = parallel_options;
    serial_options.xz_options.parallel = null;
    const expected = try V.zip.encodeAlloc(a, &entries, serial_options);
    defer a.free(expected);
    try std.testing.expectEqualSlices(u8, expected, bytes);
    const archive = try V.zip.parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expectEqual(V.zip.CompressionMethod.xz, entry.method);
    try std.testing.expectEqualStrings(entries[0].name, entry.name);
    try std.testing.expectEqualStrings(entries[0].comment, entry.comment);
    try std.testing.expectEqual(entries[0].modified, entry.modified);
    try std.testing.expectEqualStrings(parallel_options.archive_comment, archive.comment);
    const compressed = try archive.compressedData(entry);
    const info = try V.xz.inspect(a, compressed);
    try checkProfile(V, profile, info.block_count);
    const decoded = try archive.extractAlloc(a, entry);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
    parallel_options.xz_options.parallel.?.max_working_memory = 0;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, "zip-prefix|");
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, V.zip.encodeAppend(a, &out, &entries, parallel_options));
    try std.testing.expectEqualStrings("zip-prefix|", out.items);
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(capacity, out.capacity);
}

fn tarConsumer(comptime V: type) !void {
    const input = payload();
    const entries = [_]V.tar.EncodeEntry{.{ .name = "parallel.txt", .data = &input, .mode = 0o640, .mtime = 123456789 }};
    var profile: V.XzParallelProfile = .{};
    const parallel_options: V.tar.CompressedEncodeOptions = .{ .compression = .xz, .xz_options = options(V, &profile) };
    const bytes = try V.tar.encodeCompressedAlloc(a, &entries, parallel_options);
    defer a.free(bytes);
    const info = try V.xz.inspect(a, bytes);
    try checkProfile(V, profile, info.block_count);
    var serial_options = parallel_options;
    serial_options.xz_options.parallel = null;
    const expected = try V.tar.encodeCompressedAlloc(a, &entries, serial_options);
    defer a.free(expected);
    try std.testing.expectEqualSlices(u8, expected, bytes);
    const decoded = try V.tar.decodeCompressedAlloc(a, bytes, .xz, 32 * 1024);
    defer decoded.deinit(a);
    try std.testing.expectEqual(@as(usize, 1), decoded.archive.entry_count);
    const entry = try decoded.archive.entryAt(0);
    try std.testing.expect(entry.path.eql(entries[0].name));
    try std.testing.expectEqual(entries[0].mode, entry.mode);
    try std.testing.expectEqual(entries[0].mtime, entry.mtime);
    try std.testing.expectEqual(V.tar.Kind.file, entry.kind);
    try std.testing.expectEqualSlices(u8, &input, entry.data);
}

fn cpioConsumer(comptime V: type) !void {
    const input = payload();
    const entries = [_]V.cpio.EncodeEntry{.{ .name = "parallel.txt", .data = &input, .permissions = 0o640, .uid = 42, .gid = 43, .mtime = 123456789 }};
    var profile: V.XzParallelProfile = .{};
    const parallel_options: V.cpio.CompressedEncodeOptions = .{ .compression = .xz, .xz_options = options(V, &profile), .archive_options = .{ .format = .crc } };
    const bytes = try V.cpio.encodeCompressedAlloc(a, &entries, parallel_options);
    defer a.free(bytes);
    const info = try V.xz.inspect(a, bytes);
    try checkProfile(V, profile, info.block_count);
    var serial_options = parallel_options;
    serial_options.xz_options.parallel = null;
    const expected = try V.cpio.encodeCompressedAlloc(a, &entries, serial_options);
    defer a.free(expected);
    try std.testing.expectEqualSlices(u8, expected, bytes);
    const decoded = try V.cpio.decodeCompressedAlloc(a, bytes, .xz, 32 * 1024);
    defer decoded.deinit(a);
    try std.testing.expectEqual(@as(usize, 1), decoded.archive.entry_count);
    const entry = try decoded.archive.entryAt(0);
    try std.testing.expectEqualStrings(entries[0].name, entry.name);
    try std.testing.expectEqual(V.cpio.Kind.regular, entry.kind);
    try std.testing.expectEqual(@as(u32, 0o640), entry.mode & 0o7777);
    try std.testing.expectEqual(entries[0].uid, entry.uid);
    try std.testing.expectEqual(entries[0].gid, entry.gid);
    try std.testing.expectEqual(entries[0].mtime, entry.mtime);
    var checksum: u32 = 0;
    for (input) |byte| checksum +%= byte;
    try std.testing.expectEqual(@as(?u32, checksum), entry.checksum);
    const content = try decoded.archive.extractAlloc(a, entry);
    defer a.free(content);
    try std.testing.expectEqualSlices(u8, &input, content);
}

fn publicationFailures(comptime V: type) !void {
    const input = payload();
    var profile: V.XzParallelProfile = .{};
    for ([_]bool{ false, true }) |byte_limit| {
        var limited = options(V, &profile);
        if (byte_limit) limited.parallel.?.max_inflight_bytes = block_size - 1 else limited.parallel.?.max_working_memory = 0;
        var refusing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
        var output: [64]u8 = @splat(0xa5);
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, V.encodeXzInto(refusing.allocator(), &input, &output, limited));
        try untouched(&output);
        try std.testing.expectEqual(@as(usize, 0), refusing.alloc_index);
        try std.testing.expect(!refusing.has_induced_failure);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(a);
        try out.appendSlice(a, "archive-prefix|");
        const pointer = out.items.ptr;
        const capacity = out.capacity;
        const tar_entries = [_]V.tar.EncodeEntry{.{ .name = "data", .data = &input }};
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, V.tar.encodeCompressedAppend(a, &out, &tar_entries, .{ .compression = .xz, .xz_options = limited }));
        const cpio_entries = [_]V.cpio.EncodeEntry{.{ .name = "data", .data = &input }};
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, V.cpio.encodeCompressedAppend(a, &out, &cpio_entries, .{ .compression = .xz, .xz_options = limited }));
        try std.testing.expectEqualStrings("archive-prefix|", out.items);
        try std.testing.expectEqual(pointer, out.items.ptr);
        try std.testing.expectEqual(capacity, out.capacity);
    }
}
