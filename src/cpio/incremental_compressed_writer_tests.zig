const std = @import("std");
const archive = @import("archive.zig");
const compressed = @import("compressed.zig");
const compressed_writer = @import("incremental_compressed_writer.zig");
const incremental = @import("incremental_writer.zig");
const writer = @import("writer.zig");

const TestEntry = struct {
    options: incremental.EntryOptions,
    data: []const u8,
};

fn encode(
    comptime WriterType: type,
    allocator: std.mem.Allocator,
    entries: []const TestEntry,
    format: archive.Format,
    input_chunk: usize,
    output_chunk: usize,
    raw_bridge_size: usize,
) ![]u8 {
    var stream = try WriterType.initWithOptions(allocator, .{
        .cpio = .{ .format = format },
        .raw_bridge_size = raw_bridge_size,
    });
    defer stream.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    const output = try allocator.alloc(u8, output_chunk);
    defer allocator.free(output);

    for (entries) |entry| {
        var options = entry.options;
        options.checksum = if (format == .crc) archive.byteSum(entry.data) else null;
        try stream.beginEntry(options);
        var input_offset: usize = 0;
        while (input_offset != entry.data.len) {
            const input_end = @min(entry.data.len, input_offset + input_chunk);
            while (input_offset != input_end) {
                const stepped = try stream.step(entry.data[input_offset..input_end], output);
                input_offset += stepped.input_read;
                try encoded.appendSlice(allocator, output[0..stepped.output_written]);
                if (stepped.input_read == 0 and stepped.output_written == 0)
                    return error.TestUnexpectedResult;
            }
        }
        try stream.finishEntry();
        while (true) {
            const stepped = try stream.step("", output);
            try encoded.appendSlice(allocator, output[0..stepped.output_written]);
            if (stepped.status == .entry_done) {
                const snapshot = stream.snapshot();
                try std.testing.expectEqual(@as(usize, 0), snapshot.pending_raw_bytes);
                try std.testing.expect(!snapshot.pending_entry_done);
                break;
            }
            if (stepped.input_read == 0 and stepped.output_written == 0)
                return error.TestUnexpectedResult;
        }
    }

    try stream.finishArchive();
    while (true) {
        const stepped = try stream.step("", output);
        try encoded.appendSlice(allocator, output[0..stepped.output_written]);
        if (stepped.status == .done) break;
        if (stepped.input_read == 0 and stepped.output_written == 0)
            return error.TestUnexpectedResult;
    }
    return encoded.toOwnedSlice(allocator);
}

test "compressed CPIO incremental writers compose every streaming wrapper" {
    const allocator = std.testing.allocator;
    const payload = "compressed CPIO writer payload\n" ** 41;
    const entries = [_]TestEntry{
        .{ .options = .{ .name = "folder", .kind = .directory }, .data = "" },
        .{
            .options = .{
                .name = "folder/data.txt",
                .size = payload.len,
                .permissions = 0o640,
            },
            .data = payload,
        },
        .{
            .options = .{ .name = "link", .kind = .symlink, .size = "folder/data.txt".len },
            .data = "folder/data.txt",
        },
    };
    const raw_entries = [_]writer.EncodeEntry{
        .{ .name = "folder", .kind = .directory },
        .{ .name = "folder/data.txt", .data = payload, .permissions = 0o640 },
        .{ .name = "link", .kind = .symlink, .data = "folder/data.txt" },
    };
    const expected_raw = try writer.encodeAlloc(allocator, &raw_entries, .{});
    defer allocator.free(expected_raw);

    inline for (.{
        .{ compressed_writer.GzipWriter, compressed.Compression.gzip },
        .{ compressed_writer.Bzip2Writer, compressed.Compression.bzip2 },
        .{ compressed_writer.BrotliWriter, compressed.Compression.brotli },
        .{ compressed_writer.CompressZWriter, compressed.Compression.compress_z },
        .{ compressed_writer.LzmaWriter, compressed.Compression.lzma },
        .{ compressed_writer.XzWriter, compressed.Compression.xz },
        .{ compressed_writer.Lz4Writer, compressed.Compression.lz4 },
        .{ compressed_writer.Lz4LegacyWriter, compressed.Compression.lz4 },
        .{ compressed_writer.LzfWriter, compressed.Compression.lzf },
        .{ compressed_writer.LzipWriter, compressed.Compression.lzip },
        .{ compressed_writer.ZstandardWriter, compressed.Compression.zstandard },
        .{ compressed_writer.LzopWriter, compressed.Compression.lzop },
    }) |case| {
        const one = try encode(case[0], allocator, &entries, .newc, 1, 1, 1);
        defer allocator.free(one);
        const micro = try encode(case[0], allocator, &entries, .newc, 7, 13, 31);
        defer allocator.free(micro);
        try std.testing.expectEqualSlices(u8, one, micro);
        const decoded = try compressed.decodeAlloc(
            allocator,
            one,
            case[1],
            expected_raw.len,
        );
        defer decoded.deinit(allocator);
        try std.testing.expectEqualSlices(u8, expected_raw, decoded.bytes);
    }
}

test "gzip CPIO incremental writer preserves every raw header format" {
    const allocator = std.testing.allocator;
    const data = "all CPIO header families";
    const entries = [_]TestEntry{.{
        .options = .{ .name = "payload", .size = data.len },
        .data = data,
    }};
    const raw_entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = data }};
    inline for (std.meta.tags(archive.Format)) |format| {
        const encoded = try encode(
            compressed_writer.GzipWriter,
            allocator,
            &entries,
            format,
            3,
            5,
            7,
        );
        defer allocator.free(encoded);
        const expected = try writer.encodeAlloc(
            allocator,
            &raw_entries,
            .{ .format = format },
        );
        defer allocator.free(expected);
        const decoded = try compressed.decodeAlloc(
            allocator,
            encoded,
            .gzip,
            expected.len,
        );
        defer decoded.deinit(allocator);
        try std.testing.expectEqualSlices(u8, expected, decoded.bytes);
    }
}

test "compressed CPIO incremental writer enforces backpressure limits and OOM" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidCompressedCpioWriterState,
        compressed_writer.GzipWriter.initWithOptions(allocator, .{ .raw_bridge_size = 0 }),
    );

    var blocked = try compressed_writer.GzipWriter.initWithOptions(
        allocator,
        .{ .raw_bridge_size = 7 },
    );
    defer blocked.deinit();
    try blocked.beginEntry(.{ .name = "payload", .size = 3 });
    const initial = try blocked.step("abc", &.{});
    try std.testing.expectEqual(incremental.Status.need_output, initial.status);
    try std.testing.expectEqual(@as(usize, 0), initial.output_written);

    var limited = try compressed_writer.GzipWriter.initWithOptions(allocator, .{
        .raw_bridge_size = 17,
        .max_compressed_size = 1,
    });
    defer limited.deinit();
    try limited.beginEntry(.{ .name = "payload", .size = 1 });
    var output: [64]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, limited.step("x", &output));
    try std.testing.expectError(
        error.CompressedCpioWriterPoisoned,
        limited.step("", &output),
    );

    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator) !void {
            const entries = [_]TestEntry{.{
                .options = .{ .name = "long/" ++ "component-" ** 20, .size = 7 },
                .data = "payload",
            }};
            const encoded = try encode(
                compressed_writer.GzipWriter,
                failing_allocator,
                &entries,
                .crc,
                3,
                5,
                17,
            );
            defer failing_allocator.free(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}
