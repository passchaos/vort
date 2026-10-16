const std = @import("std");
const compressed_reader = @import("incremental_compressed_reader.zig");
const compressed = @import("compressed.zig");
const deflate = @import("../deflate.zig");
const lz4_legacy = @import("../lz4_legacy.zig");
const lzip = @import("../lzip.zig");
const tar = @import("../tar.zig");

const regular_payload = "compressed TAR streaming payload\n" ** 37;

fn exercise(
    comptime ReaderType: type,
    compression: compressed.Compression,
    input_chunk: usize,
    output_chunk: usize,
) !void {
    const allocator = std.testing.allocator;
    const sparse_extents = [_]tar.SparseDataExtent{
        .{ .offset = 0, .data = "HEAD" },
        .{ .offset = 8188, .data = "TAIL" },
    };
    const entries = [_]tar.EncodeEntry{
        .{ .name = "folder/", .kind = .directory },
        .{ .name = "folder/data.txt", .data = regular_payload },
        .{
            .name = "folder/sparse.bin",
            .sparse = .{ .logical_size = 8192, .extents = &sparse_extents },
        },
    };
    const raw = try tar.encodeAlloc(allocator, &entries);
    defer allocator.free(raw);
    const encoded = try compressed.encodeAlloc(allocator, &entries, .{
        .compression = compression,
    });
    defer allocator.free(encoded);

    var reader = try ReaderType.initWithOptions(allocator, .{
        .decoded_bridge_size = 1,
        .max_decoded_size = raw.len,
        .tar = .{
            .max_archive_size = raw.len,
            .max_logical_entry_size = 16 * 1024,
            .max_total_output_size = 16 * 1024,
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
                        try std.testing.expectEqualStrings("folder/", info.name);
                        try std.testing.expectEqual(tar.Kind.directory, info.kind);
                    },
                    1 => try std.testing.expectEqualStrings("folder/data.txt", info.name),
                    2 => {
                        try std.testing.expectEqualStrings("folder/sparse.bin", info.name);
                        try std.testing.expectEqual(tar.SparseFormat.pax_1_0, info.sparse_format.?);
                    },
                    else => return error.TestUnexpectedResult,
                }
                current.clearRetainingCapacity();
            },
            .entry_done => {
                switch (entry_index) {
                    0 => try std.testing.expectEqual(@as(usize, 0), current.items.len),
                    1 => try std.testing.expectEqualSlices(u8, regular_payload, current.items),
                    2 => {
                        try std.testing.expectEqual(@as(usize, 8192), current.items.len);
                        try std.testing.expectEqualSlices(u8, "HEAD", current.items[0..4]);
                        try std.testing.expectEqualSlices(u8, "TAIL", current.items[8188..]);
                    },
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
            return error.TestUnexpectedResult;
    }
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(@as(usize, entries.len), entry_index);
    const snapshot = reader.snapshot();
    try std.testing.expectEqual(@as(u64, raw.len), snapshot.decoded_bytes);
    try std.testing.expect(snapshot.decoder_done);
    try std.testing.expect(snapshot.tar_done);
}

test "compressed TAR incremental readers compose eight streaming wrappers" {
    inline for (.{
        .{ compressed_reader.GzipReader, compressed.Compression.gzip },
        .{ compressed_reader.Bzip2Reader, compressed.Compression.bzip2 },
        .{ compressed_reader.BrotliReader, compressed.Compression.brotli },
        .{ compressed_reader.LzmaReader, compressed.Compression.lzma },
        .{ compressed_reader.XzReader, compressed.Compression.xz },
        .{ compressed_reader.Lz4Reader, compressed.Compression.lz4 },
        .{ compressed_reader.ZstandardReader, compressed.Compression.zstandard },
        .{ compressed_reader.LzopReader, compressed.Compression.lzop },
    }) |case| {
        try exercise(case[0], case[1], 1, 1);
        try exercise(case[0], case[1], 13, 17);
    }
}

test "compressed TAR incremental readers compose LZF and legacy LZ4" {
    try exercise(compressed_reader.LzfReader, .lzf, 1, 1);
    try exercise(compressed_reader.LzfReader, .lzf, 13, 17);

    const allocator = std.testing.allocator;
    const entries = [_]tar.EncodeEntry{.{ .name = "payload", .data = regular_payload }};
    const raw = try tar.encodeAlloc(allocator, &entries);
    defer allocator.free(raw);
    const encoded = try lz4_legacy.encodeAlloc(allocator, raw, .{ .block_size = 1024 });
    defer allocator.free(encoded);
    inline for (.{
        .{ @as(usize, 1), @as(usize, 1) },
        .{ @as(usize, 13), @as(usize, 17) },
    }) |schedule| {
        var reader = try compressed_reader.Lz4LegacyReader.initWithOptions(allocator, .{
            .decoded_bridge_size = 1,
            .max_decoded_size = raw.len,
        });
        defer reader.deinit();
        var actual: std.ArrayList(u8) = .empty;
        defer actual.deinit(allocator);
        const output = try allocator.alloc(u8, schedule[1]);
        defer allocator.free(output);
        var input_offset: usize = 0;
        var finish_sent = false;
        while (true) {
            const input_end = @min(encoded.len, input_offset + schedule[0]);
            const stepped = try reader.step(encoded[input_offset..input_end], output);
            input_offset += stepped.input_read;
            try actual.appendSlice(allocator, output[0..stepped.output_written]);
            if (stepped.status == .entry_header) actual.clearRetainingCapacity();
            if (stepped.status == .entry_done)
                try std.testing.expectEqualSlices(u8, regular_payload, actual.items);
            if (stepped.status == .done) break;
            if (!finish_sent and input_offset == encoded.len) {
                try reader.finish();
                finish_sent = true;
            }
        }
        try std.testing.expectEqual(encoded.len, input_offset);
    }
}

test "compressed TAR incremental reader composes lzip" {
    try exercise(compressed_reader.LzipReader, .lzip, 1, 1);
    try exercise(compressed_reader.LzipReader, .lzip, 13, 17);
}

test "compressed TAR incremental reader validates decoded limit and TAR trailer" {
    const allocator = std.testing.allocator;
    const entries = [_]tar.EncodeEntry{.{ .name = "payload", .data = "bounded" }};
    const raw = try tar.encodeAlloc(allocator, &entries);
    defer allocator.free(raw);
    const encoded = try deflate.encodeGzipBestAlloc(allocator, raw, deflate.optionsForLevel(.default));
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
        error.CompressedTarReaderPoisoned,
        limited.step("", &output),
    );

    var raw_with_trailer = try allocator.alloc(u8, raw.len + 1);
    defer allocator.free(raw_with_trailer);
    @memcpy(raw_with_trailer[0..raw.len], raw);
    raw_with_trailer[raw.len] = 'X';
    const bad = try deflate.encodeGzipBestAlloc(
        allocator,
        raw_with_trailer,
        deflate.optionsForLevel(.default),
    );
    defer allocator.free(bad);
    var trailer = try compressed_reader.GzipReader.initWithOptions(allocator, .{
        .decoded_bridge_size = 11,
    });
    defer trailer.deinit();
    offset = 0;
    while (true) {
        const stepped = trailer.step(bad[offset..], &output) catch |err| {
            try std.testing.expectEqual(error.NonZeroTarTrailer, err);
            break;
        };
        offset += stepped.input_read;
        if (offset == bad.len) try trailer.finish();
    }
}

test "compressed TAR incremental reader rejects truncated gzip and frees allocations" {
    const allocator = std.testing.allocator;
    const long_name = "nested/" ++ "long-component-" ** 12 ++ "payload.bin";
    const entries = [_]tar.EncodeEntry{.{ .name = long_name, .data = regular_payload }};
    const encoded = try compressed.encodeAlloc(allocator, &entries, .{ .compression = .gzip });
    defer allocator.free(encoded);

    var truncated = try compressed_reader.GzipReader.initWithOptions(allocator, .{
        .decoded_bridge_size = 17,
    });
    defer truncated.deinit();
    var output: [31]u8 = undefined;
    var offset: usize = 0;
    const short = encoded[0 .. encoded.len - 1];
    while (offset < short.len) {
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

test "compressed TAR incremental reader propagates zero-output backpressure" {
    const allocator = std.testing.allocator;
    const entries = [_]tar.EncodeEntry{.{ .name = "payload", .data = "abc" }};
    const encoded = try compressed.encodeAlloc(allocator, &entries, .{ .compression = .gzip });
    defer allocator.free(encoded);
    var reader = try compressed_reader.GzipReader.initWithOptions(allocator, .{
        .decoded_bridge_size = 5,
    });
    defer reader.deinit();
    var output: [8]u8 = undefined;
    var input_offset: usize = 0;
    while (true) {
        const stepped = try reader.step(encoded[input_offset..], &output);
        input_offset += stepped.input_read;
        if (stepped.status != .entry_header) continue;
        const blocked = try reader.step("", &.{});
        try std.testing.expectEqual(tar.incremental_reader.Status.need_output, blocked.status);
        try std.testing.expectEqual(@as(usize, 0), blocked.input_read);
        try std.testing.expectEqual(@as(usize, 0), blocked.output_written);
        break;
    }
}

test "gzip TAR incremental reader accepts concatenated members" {
    const allocator = std.testing.allocator;
    const entries = [_]tar.EncodeEntry{.{ .name = "payload", .data = regular_payload }};
    const raw = try tar.encodeAlloc(allocator, &entries);
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

    var reader = try compressed_reader.GzipReader.initWithOptions(allocator, .{
        .decoded_bridge_size = 19,
        .max_decoded_size = raw.len,
    });
    defer reader.deinit();
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);
    var output: [23]u8 = undefined;
    var input_offset: usize = 0;
    var finish_sent = false;
    while (true) {
        const input_end = @min(encoded.len, input_offset + 7);
        const stepped = try reader.step(encoded[input_offset..input_end], &output);
        input_offset += stepped.input_read;
        try actual.appendSlice(allocator, output[0..stepped.output_written]);
        if (stepped.status == .entry_header) actual.clearRetainingCapacity();
        if (stepped.status == .entry_done) {
            try std.testing.expectEqualSlices(u8, regular_payload, actual.items);
        }
        if (stepped.status == .done) break;
        if (!finish_sent and input_offset == encoded.len) {
            try reader.finish();
            finish_sent = true;
        }
    }
    try std.testing.expectEqual(encoded.len, input_offset);
}

test "lzip TAR incremental reader accepts concatenated members" {
    const allocator = std.testing.allocator;
    const entries = [_]tar.EncodeEntry{.{ .name = "payload", .data = regular_payload }};
    const raw = try tar.encodeAlloc(allocator, &entries);
    defer allocator.free(raw);
    const split = raw.len / 3;
    const encoded = try lzip.encodeMembersAlloc(allocator, &.{
        .{ .data = raw[0..split], .options = .{ .dictionary_size = 4096 } },
        .{ .data = raw[split..], .options = .{ .dictionary_size = 64 * 1024 } },
    });
    defer allocator.free(encoded);

    var reader = try compressed_reader.LzipReader.initWithOptions(allocator, .{
        .decoded_bridge_size = 19,
        .max_decoded_size = raw.len,
    });
    defer reader.deinit();
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);
    var output: [23]u8 = undefined;
    var input_offset: usize = 0;
    var finish_sent = false;
    while (true) {
        const input_end = @min(encoded.len, input_offset + 7);
        const stepped = try reader.step(encoded[input_offset..input_end], &output);
        input_offset += stepped.input_read;
        try actual.appendSlice(allocator, output[0..stepped.output_written]);
        if (stepped.status == .entry_header) actual.clearRetainingCapacity();
        if (stepped.status == .entry_done)
            try std.testing.expectEqualSlices(u8, regular_payload, actual.items);
        if (stepped.status == .done) break;
        if (!finish_sent and input_offset == encoded.len) {
            try reader.finish();
            finish_sent = true;
        }
    }
    try std.testing.expectEqual(encoded.len, input_offset);
}
