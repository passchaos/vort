const std = @import("std");
const archive = @import("archive.zig");
const compressed = @import("compressed.zig");
const compressed_reader = @import("incremental_compressed_reader.zig");
const deflate = @import("../deflate.zig");
const lz4_legacy = @import("../lz4_legacy.zig");
const writer = @import("writer.zig");

const payload = "compressed CPIO reader payload\n" ** 37;

fn exerciseBytes(
    comptime ReaderType: type,
    allocator: std.mem.Allocator,
    encoded: []const u8,
    raw: []const u8,
    input_chunk: usize,
    output_chunk: usize,
) !void {
    var reader = try ReaderType.initWithOptions(allocator, .{
        .decoded_bridge_size = 1,
        .max_decoded_size = raw.len,
        .cpio = .{
            .max_entry_size = 16 * 1024,
            .max_total_output_size = 16 * 1024,
            .max_archive_size = raw.len,
        },
    });
    defer reader.deinit();
    const output = try allocator.alloc(u8, output_chunk);
    defer allocator.free(output);
    var current: std.ArrayList(u8) = .empty;
    defer current.deinit(allocator);
    var input_offset: usize = 0;
    var entry_index: usize = 0;
    var finish_sent = false;
    var iterations: usize = 0;
    while (true) {
        iterations += 1;
        if (iterations > encoded.len * 64 + raw.len * 8 + 4096)
            return error.TestUnexpectedResult;
        const input_end = @min(encoded.len, input_offset + input_chunk);
        const stepped = try reader.step(encoded[input_offset..input_end], output);
        input_offset += stepped.input_read;
        try current.appendSlice(allocator, output[0..stepped.output_written]);
        switch (stepped.status) {
            .entry_header => {
                const info = reader.currentEntry() orelse return error.TestUnexpectedResult;
                switch (entry_index) {
                    0 => {
                        try std.testing.expectEqualStrings("folder", info.name);
                        try std.testing.expectEqual(archive.Kind.directory, info.kind);
                    },
                    1 => try std.testing.expectEqualStrings("folder/data.txt", info.name),
                    2 => {
                        try std.testing.expectEqualStrings("link", info.name);
                        try std.testing.expectEqual(archive.Kind.symlink, info.kind);
                    },
                    else => return error.TestUnexpectedResult,
                }
                current.clearRetainingCapacity();
            },
            .entry_done => {
                switch (entry_index) {
                    0 => try std.testing.expectEqual(@as(usize, 0), current.items.len),
                    1 => try std.testing.expectEqualSlices(u8, payload, current.items),
                    2 => try std.testing.expectEqualSlices(u8, "folder/data.txt", current.items),
                    else => return error.TestUnexpectedResult,
                }
                entry_index += 1;
            },
            .done => break,
            .need_input, .need_output => {},
        }
        if (!finish_sent and input_offset == encoded.len) {
            try reader.finish();
            finish_sent = true;
        }
        if (stepped.input_read == 0 and stepped.output_written == 0 and
            stepped.status != .entry_header and stepped.status != .entry_done and
            !(stepped.status == .need_input and !finish_sent))
        {
            return error.TestUnexpectedResult;
        }
    }
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(@as(usize, 3), entry_index);
    const snapshot = reader.snapshot();
    try std.testing.expectEqual(@as(u64, raw.len), snapshot.decoded_bytes);
    try std.testing.expect(snapshot.decoder_done);
    try std.testing.expect(snapshot.cpio_done);
}

fn exercise(
    comptime ReaderType: type,
    compression: compressed.Compression,
    input_chunk: usize,
    output_chunk: usize,
) !void {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{
        .{ .name = "folder", .kind = .directory },
        .{ .name = "folder/data.txt", .data = payload },
        .{ .name = "link", .kind = .symlink, .data = "folder/data.txt" },
    };
    const raw = try writer.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(raw);
    const encoded = try compressed.encodeAlloc(allocator, &entries, .{
        .compression = compression,
    });
    defer allocator.free(encoded);
    try exerciseBytes(ReaderType, allocator, encoded, raw, input_chunk, output_chunk);
}

test "compressed CPIO incremental readers compose every streaming wrapper" {
    inline for (.{
        .{ compressed_reader.GzipReader, compressed.Compression.gzip },
        .{ compressed_reader.Bzip2Reader, compressed.Compression.bzip2 },
        .{ compressed_reader.BrotliReader, compressed.Compression.brotli },
        .{ compressed_reader.CompressZReader, compressed.Compression.compress_z },
        .{ compressed_reader.LzmaReader, compressed.Compression.lzma },
        .{ compressed_reader.XzReader, compressed.Compression.xz },
        .{ compressed_reader.Lz4Reader, compressed.Compression.lz4 },
        .{ compressed_reader.LzfReader, compressed.Compression.lzf },
        .{ compressed_reader.LzipReader, compressed.Compression.lzip },
        .{ compressed_reader.ZstandardReader, compressed.Compression.zstandard },
        .{ compressed_reader.LzopReader, compressed.Compression.lzop },
    }) |case| {
        try exercise(case[0], case[1], 1, 1);
        try exercise(case[0], case[1], 13, 17);
    }

    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{
        .{ .name = "folder", .kind = .directory },
        .{ .name = "folder/data.txt", .data = payload },
        .{ .name = "link", .kind = .symlink, .data = "folder/data.txt" },
    };
    const raw = try writer.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(raw);
    const legacy = try lz4_legacy.encodeAlloc(allocator, raw, .{ .block_size = 1024 });
    defer allocator.free(legacy);
    try exerciseBytes(compressed_reader.Lz4LegacyReader, allocator, legacy, raw, 1, 1);
    try exerciseBytes(compressed_reader.Lz4LegacyReader, allocator, legacy, raw, 13, 17);
}

test "gzip CPIO incremental reader accepts every raw header format" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = payload }};
    inline for (std.meta.tags(archive.Format)) |format| {
        const raw = try writer.encodeAlloc(allocator, &entries, .{ .format = format });
        defer allocator.free(raw);
        const encoded = try deflate.encodeGzipBestAlloc(
            allocator,
            raw,
            deflate.optionsForLevel(.default),
        );
        defer allocator.free(encoded);

        var reader = try compressed_reader.GzipReader.initWithOptions(allocator, .{
            .decoded_bridge_size = 7,
            .max_decoded_size = raw.len,
        });
        defer reader.deinit();
        var output: [31]u8 = undefined;
        var actual: std.ArrayList(u8) = .empty;
        defer actual.deinit(allocator);
        var input_offset: usize = 0;
        var finish_sent = false;
        while (true) {
            const stepped = try reader.step(encoded[input_offset..], &output);
            input_offset += stepped.input_read;
            try actual.appendSlice(allocator, output[0..stepped.output_written]);
            if (stepped.status == .entry_header) actual.clearRetainingCapacity();
            if (stepped.status == .entry_done)
                try std.testing.expectEqualSlices(u8, payload, actual.items);
            if (stepped.status == .done) break;
            if (!finish_sent and input_offset == encoded.len) {
                try reader.finish();
                finish_sent = true;
            }
        }
        try std.testing.expectEqual(format, reader.snapshot().cpio.format.?);
    }
}

test "gzip CPIO incremental reader accepts concatenated members" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{
        .{ .name = "folder", .kind = .directory },
        .{ .name = "folder/data.txt", .data = payload },
        .{ .name = "link", .kind = .symlink, .data = "folder/data.txt" },
    };
    const raw = try writer.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(raw);
    const split = raw.len / 3;
    const first = try deflate.encodeGzipBestAlloc(
        allocator,
        raw[0..split],
        deflate.optionsForLevel(.default),
    );
    defer allocator.free(first);
    const second = try deflate.encodeGzipBestAlloc(
        allocator,
        raw[split..],
        deflate.optionsForLevel(.default),
    );
    defer allocator.free(second);
    const encoded = try allocator.alloc(u8, first.len + second.len);
    defer allocator.free(encoded);
    @memcpy(encoded[0..first.len], first);
    @memcpy(encoded[first.len..], second);
    try exerciseBytes(
        compressed_reader.GzipReader,
        allocator,
        encoded,
        raw,
        7,
        23,
    );
}

test "compressed CPIO incremental reader validates limits corruption and OOM" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = "bounded" }};
    const raw = try writer.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(raw);
    const encoded = try deflate.encodeGzipBestAlloc(
        allocator,
        raw,
        deflate.optionsForLevel(.default),
    );
    defer allocator.free(encoded);

    var limited = try compressed_reader.GzipReader.initWithOptions(allocator, .{
        .decoded_bridge_size = 7,
        .max_decoded_size = raw.len - 1,
    });
    defer limited.deinit();
    var output: [32]u8 = undefined;
    var offset: usize = 0;
    while (true) {
        const stepped = limited.step(encoded[offset..], &output) catch |err| {
            try std.testing.expectEqual(error.OutputLimitExceeded, err);
            break;
        };
        offset += stepped.input_read;
        if (offset == encoded.len) try limited.finish();
    }
    try std.testing.expectError(
        error.CompressedCpioReaderPoisoned,
        limited.step("", &output),
    );

    var raw_with_trailer = try allocator.alloc(u8, raw.len + 1);
    defer allocator.free(raw_with_trailer);
    @memcpy(raw_with_trailer[0..raw.len], raw);
    raw_with_trailer[raw.len] = 'X';
    const corrupt = try deflate.encodeGzipBestAlloc(
        allocator,
        raw_with_trailer,
        deflate.optionsForLevel(.default),
    );
    defer allocator.free(corrupt);
    var bad = try compressed_reader.GzipReader.initWithOptions(
        allocator,
        .{ .decoded_bridge_size = 11 },
    );
    defer bad.deinit();
    offset = 0;
    while (true) {
        const stepped = bad.step(corrupt[offset..], &output) catch |err| {
            try std.testing.expectEqual(error.InvalidCpioArchive, err);
            break;
        };
        offset += stepped.input_read;
        if (offset == corrupt.len) try bad.finish();
    }

    var truncated = try compressed_reader.GzipReader.initWithOptions(
        allocator,
        .{ .decoded_bridge_size = 17 },
    );
    defer truncated.deinit();
    offset = 0;
    const short = encoded[0 .. encoded.len - 1];
    while (offset != short.len) {
        const stepped = try truncated.step(short[offset..], &output);
        offset += stepped.input_read;
    }
    try truncated.finish();
    try std.testing.expectError(error.TruncatedFrame, truncated.step("", &output));

    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, bytes: []const u8) !void {
            var reader = try compressed_reader.GzipReader.initWithOptions(
                failing_allocator,
                .{ .decoded_bridge_size = 17 },
            );
            defer reader.deinit();
            var output_storage: [31]u8 = undefined;
            var input_offset: usize = 0;
            var finish_sent = false;
            while (true) {
                const stepped = try reader.step(bytes[input_offset..], &output_storage);
                input_offset += stepped.input_read;
                if (stepped.status == .done) break;
                if (!finish_sent and input_offset == bytes.len) {
                    try reader.finish();
                    finish_sent = true;
                }
            }
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{encoded});
}

test "compressed CPIO incremental reader propagates zero-output backpressure" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = "abc" }};
    const encoded = try compressed.encodeAlloc(
        allocator,
        &entries,
        .{ .compression = .gzip },
    );
    defer allocator.free(encoded);
    var reader = try compressed_reader.GzipReader.initWithOptions(
        allocator,
        .{ .decoded_bridge_size = 5 },
    );
    defer reader.deinit();
    var output: [8]u8 = undefined;
    var input_offset: usize = 0;
    while (true) {
        const stepped = try reader.step(encoded[input_offset..], &output);
        input_offset += stepped.input_read;
        if (stepped.status != .entry_header) continue;
        const blocked = try reader.step("", &.{});
        try std.testing.expectEqual(@import("incremental_reader.zig").Status.need_output, blocked.status);
        try std.testing.expectEqual(@as(usize, 0), blocked.input_read);
        try std.testing.expectEqual(@as(usize, 0), blocked.output_written);
        break;
    }
}

test "compressed CPIO incremental reader validates decoded padding after trailer stop" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = "abc" }};
    const raw = try writer.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(raw);
    const encoded = try deflate.encodeGzipBestAlloc(
        allocator,
        raw,
        deflate.optionsForLevel(.default),
    );
    defer allocator.free(encoded);
    var reader = try compressed_reader.GzipReader.initWithOptions(allocator, .{
        .decoded_bridge_size = 7,
        .cpio = .{ .stop_after_trailer = true },
    });
    defer reader.deinit();
    var output: [8]u8 = undefined;
    var input_offset: usize = 0;
    var finish_sent = false;
    while (true) {
        const stepped = try reader.step(encoded[input_offset..], &output);
        input_offset += stepped.input_read;
        if (stepped.status == .done) break;
        if (!finish_sent and input_offset == encoded.len) {
            try reader.finish();
            finish_sent = true;
        }
    }
    try std.testing.expect(reader.snapshot().cpio_done);
}

fn expectRecoverableSuffix(
    comptime ReaderType: type,
    compression: compressed.Compression,
    decoder_options: anytype,
) !void {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = payload }};
    var encode_options = compressed.EncodeOptions{ .compression = compression };
    if (compression == .lzf) encode_options.lzf_options.eof_marker = true;
    const encoded = try compressed.encodeAlloc(allocator, &entries, encode_options);
    defer allocator.free(encoded);
    const suffix = "NEXT-MEMBER";
    const joined = try allocator.alloc(u8, encoded.len + suffix.len);
    defer allocator.free(joined);
    @memcpy(joined[0..encoded.len], encoded);
    @memcpy(joined[encoded.len..], suffix);

    var reader = try ReaderType.initWithOptions(allocator, .{
        .decoded_bridge_size = 7,
        .cpio = .{ .stop_after_trailer = true },
        .decoder = decoder_options,
    });
    defer reader.deinit();
    var output: [5]u8 = undefined;
    var input_offset: usize = 0;
    while (true) {
        const stepped = try reader.step(joined[input_offset..], &output);
        input_offset += stepped.input_read;
        if (stepped.status == .done) break;
    }
    const trailing = reader.trailingInput();
    if (trailing.len > input_offset) return error.TestUnexpectedResult;
    const logical_consumed = input_offset - trailing.len;
    try std.testing.expectEqual(encoded.len, logical_consumed);
    try std.testing.expectEqualSlices(u8, joined[logical_consumed..input_offset], trailing);
    try std.testing.expectEqualSlices(u8, suffix[0..trailing.len], trailing);
    try std.testing.expectEqualSlices(u8, suffix[trailing.len..], joined[input_offset..]);
    try std.testing.expectEqual(trailing.len, reader.snapshot().trailing_input_bytes);
}

test "compressed CPIO readers expose recoverable first-stream suffixes" {
    try expectRecoverableSuffix(
        compressed_reader.GzipReader,
        .gzip,
        compressed_reader.codecs.Gzip.Options{
            .allow_concatenated = false,
            .allow_trailing_data = true,
        },
    );
    try expectRecoverableSuffix(
        compressed_reader.Bzip2Reader,
        .bzip2,
        compressed_reader.codecs.Bzip2.Options{
            .stop_after_first_stream = true,
            .first_stream_retry_granularity = 1,
        },
    );
    try expectRecoverableSuffix(
        compressed_reader.BrotliReader,
        .brotli,
        compressed_reader.codecs.Brotli.Options{ .allow_trailing_data = true },
    );
    try expectRecoverableSuffix(
        compressed_reader.LzmaReader,
        .lzma,
        compressed_reader.codecs.Lzma.Options{
            .stop_after_end_marker = true,
            .end_marker_input_guard = 16,
        },
    );
    try expectRecoverableSuffix(
        compressed_reader.XzReader,
        .xz,
        compressed_reader.codecs.Xz.Options{
            .stop_after_first_stream = true,
            .first_stream_footer_retry_granularity = 1,
        },
    );
    try expectRecoverableSuffix(
        compressed_reader.ZstandardReader,
        .zstandard,
        compressed_reader.codecs.Zstandard.Options{ .stop_after_first_frame = true },
    );
    try expectRecoverableSuffix(
        compressed_reader.Lz4Reader,
        .lz4,
        compressed_reader.codecs.Lz4.Options{ .stop_after_first_frame = true },
    );
    try expectRecoverableSuffix(
        compressed_reader.LzfReader,
        .lzf,
        compressed_reader.codecs.Lzf.Options{ .stop_after_eof_marker = true },
    );
    try expectRecoverableSuffix(
        compressed_reader.LzipReader,
        .lzip,
        compressed_reader.codecs.Lzip.Options{ .stop_after_first_member = true },
    );
    try expectRecoverableSuffix(
        compressed_reader.LzopReader,
        .lzop,
        compressed_reader.codecs.Lzop.Options{ .stop_after_first_stream = true },
    );
}
