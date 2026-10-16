const std = @import("std");
const compressed_writer = @import("incremental_compressed_writer.zig");
const compressed = @import("compressed.zig");
const incremental = @import("incremental_writer.zig");
const tar = @import("../tar.zig");

const TestEntry = struct {
    options: incremental.EntryOptions,
    data: []const u8,
};

fn encode(
    comptime WriterType: type,
    allocator: std.mem.Allocator,
    entries: []const TestEntry,
    input_chunk: usize,
    output_chunk: usize,
    raw_bridge_size: usize,
) ![]u8 {
    var writer = try WriterType.initWithOptions(allocator, .{
        .raw_bridge_size = raw_bridge_size,
    });
    defer writer.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    const output = try allocator.alloc(u8, output_chunk);
    defer allocator.free(output);
    for (entries) |entry| {
        try writer.beginEntry(entry.options);
        var input_offset: usize = 0;
        while (input_offset < entry.data.len) {
            const input_end = @min(entry.data.len, input_offset + input_chunk);
            while (input_offset < input_end) {
                const stepped = try writer.step(entry.data[input_offset..input_end], output);
                input_offset += stepped.input_read;
                try encoded.appendSlice(allocator, output[0..stepped.output_written]);
                if (stepped.input_read == 0 and stepped.output_written == 0)
                    return error.TestUnexpectedResult;
            }
        }
        try writer.finishEntry();
        while (true) {
            const stepped = try writer.step("", output);
            try encoded.appendSlice(allocator, output[0..stepped.output_written]);
            if (stepped.status == .entry_done) {
                const snapshot = writer.snapshot();
                try std.testing.expectEqual(@as(usize, 0), snapshot.pending_raw_bytes);
                try std.testing.expect(!snapshot.pending_entry_done);
                break;
            }
            if (stepped.input_read == 0 and stepped.output_written == 0)
                return error.TestUnexpectedResult;
        }
    }
    try writer.finishArchive();
    while (true) {
        const stepped = try writer.step("", output);
        try encoded.appendSlice(allocator, output[0..stepped.output_written]);
        if (stepped.status == .done) break;
        if (stepped.input_read == 0 and stepped.output_written == 0)
            return error.TestUnexpectedResult;
    }
    return encoded.toOwnedSlice(allocator);
}

test "compressed TAR incremental writers compose eight streaming wrappers" {
    const allocator = std.testing.allocator;
    const long_name = "nested/" ++ "long-component-" ** 12 ++ "file.txt";
    var sparse: [4096]u8 = @splat(0);
    @memcpy(sparse[0..4], "HEAD");
    @memcpy(sparse[4092..], "TAIL");
    const sparse_layout = [_]incremental.SparseExtent{
        .{ .offset = 0, .len = 4 },
        .{ .offset = 4092, .len = 4 },
    };
    const entries = [_]TestEntry{
        .{ .options = .{ .name = "plain.txt", .size = 5 }, .data = "plain" },
        .{ .options = .{ .name = long_name, .size = 9 }, .data = "long path" },
        .{ .options = .{ .name = "folder/", .kind = .directory }, .data = "" },
        .{
            .options = .{
                .name = "sparse.bin",
                .sparse = .{ .logical_size = sparse.len, .extents = &sparse_layout },
            },
            .data = &sparse,
        },
    };
    const raw_sparse = [_]tar.SparseDataExtent{
        .{ .offset = 0, .data = sparse[0..4] },
        .{ .offset = 4092, .data = sparse[4092..] },
    };
    const expected_raw = try tar.encodeAlloc(allocator, &.{
        .{ .name = "plain.txt", .data = "plain" },
        .{ .name = long_name, .data = "long path" },
        .{ .name = "folder/", .kind = .directory },
        .{
            .name = "sparse.bin",
            .sparse = .{ .logical_size = sparse.len, .extents = &raw_sparse },
        },
    });
    defer allocator.free(expected_raw);

    inline for (.{
        .{ compressed_writer.GzipWriter, compressed.Compression.gzip },
        .{ compressed_writer.Bzip2Writer, compressed.Compression.bzip2 },
        .{ compressed_writer.BrotliWriter, compressed.Compression.brotli },
        .{ compressed_writer.LzmaWriter, compressed.Compression.lzma },
        .{ compressed_writer.XzWriter, compressed.Compression.xz },
        .{ compressed_writer.Lz4Writer, compressed.Compression.lz4 },
        .{ compressed_writer.ZstandardWriter, compressed.Compression.zstandard },
        .{ compressed_writer.LzopWriter, compressed.Compression.lzop },
    }) |case| {
        const one = try encode(case[0], allocator, &entries, 1, 1, 1);
        defer allocator.free(one);
        const micro = try encode(case[0], allocator, &entries, 7, 13, 31);
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

test "compressed TAR incremental writers compose LZF and legacy LZ4" {
    const allocator = std.testing.allocator;
    const data = "LZF and legacy LZ4 TAR payload\n" ** 32;
    const entries = [_]TestEntry{.{
        .options = .{ .name = "payload.bin", .size = data.len },
        .data = data,
    }};
    inline for (.{
        .{ compressed_writer.LzfWriter, compressed.Compression.lzf },
        .{ compressed_writer.Lz4LegacyWriter, compressed.Compression.lz4 },
    }) |case| {
        const one = try encode(case[0], allocator, &entries, 1, 1, 1);
        defer allocator.free(one);
        const micro = try encode(case[0], allocator, &entries, 17, 31, 29);
        defer allocator.free(micro);
        try std.testing.expectEqualSlices(u8, one, micro);
        const raw = switch (case[1]) {
            .lzf => try @import("../lzf.zig").decodeAlloc(allocator, one),
            .lz4 => try @import("../lz4_legacy.zig").decodeAlloc(allocator, one),
            else => unreachable,
        };
        defer allocator.free(raw);
        const parsed = try tar.parse(raw);
        const decoded = try parsed.extractByNameAlloc(allocator, "payload.bin");
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, entries[0].data, decoded);
    }
}

test "compressed TAR incremental writer enforces backpressure limits and poison" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidCompressedTarWriterState,
        compressed_writer.GzipWriter.initWithOptions(allocator, .{
            .raw_bridge_size = 0,
        }),
    );

    var blocked = try compressed_writer.GzipWriter.initWithOptions(allocator, .{
        .raw_bridge_size = 7,
    });
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
        error.CompressedTarWriterPoisoned,
        limited.step("", &output),
    );

    var sparse_writer = try compressed_writer.GzipWriter.init(allocator);
    defer sparse_writer.deinit();
    const layout = [_]incremental.SparseExtent{.{ .offset = 0, .len = 1 }};
    try sparse_writer.beginEntry(.{
        .name = "sparse",
        .sparse = .{ .logical_size = 1024, .extents = &layout },
    });
    var sparse_data: [1024]u8 = @splat(0);
    sparse_data[0] = 'A';
    sparse_data[700] = 'X';
    var sparse_offset: usize = 0;
    while (true) {
        const stepped = sparse_writer.step(sparse_data[sparse_offset..], &output) catch |err| {
            try std.testing.expectEqual(error.NonZeroSparseHole, err);
            break;
        };
        sparse_offset += stepped.input_read;
        if (sparse_offset == sparse_data.len)
            return error.TestUnexpectedResult;
    }
    try std.testing.expectError(
        error.CompressedTarWriterPoisoned,
        sparse_writer.step("", &output),
    );
}

test "compressed TAR incremental writer releases full allocation failure paths" {
    const allocator = std.testing.allocator;
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
                3,
                5,
                17,
            );
            defer failing_allocator.free(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}
