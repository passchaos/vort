const std = @import("std");
const auto = @import("incremental_auto_reader.zig");
const compressed = @import("compressed.zig");
const lz4_legacy = @import("../lz4_legacy.zig");
const tar = @import("../tar.zig");

const payload = "automatic incremental TAR payload\n" ** 19;

fn exercise(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    expected_format: auto.Format,
    input_chunk: usize,
    output_chunk: usize,
) !void {
    var reader = auto.Reader.initWithOptions(allocator, .{
        .decoded_bridge_size = 17,
        .max_decoded_size = 16 * 1024,
        .max_input_size = 16 * 1024 * 1024,
        .tar = .{
            .max_archive_size = 16 * 1024,
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
        if (iterations > encoded.len * 64 + 64 * 1024)
            return error.TestUnexpectedResult;
        const input_end = @min(encoded.len, input_offset + input_chunk);
        const stepped = try reader.step(encoded[input_offset..input_end], output);
        input_offset += stepped.input_read;
        try current.appendSlice(allocator, output[0..stepped.output_written]);
        switch (stepped.status) {
            .entry_header => {
                const info = reader.currentEntry() orelse return error.TestUnexpectedResult;
                switch (entry_index) {
                    0 => try std.testing.expectEqualStrings("folder/", info.name),
                    1 => try std.testing.expectEqualStrings("folder/payload.txt", info.name),
                    else => return error.TestUnexpectedResult,
                }
                current.clearRetainingCapacity();
            },
            .entry_done => {
                if (entry_index == 0) {
                    try std.testing.expectEqual(@as(usize, 0), current.items.len);
                } else {
                    try std.testing.expectEqualSlices(u8, payload, current.items);
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
    }
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(@as(usize, 2), entry_index);
    try std.testing.expectEqual(expected_format, reader.detectedFormat().?);
}

test "automatic incremental TAR reader dispatches raw and every wrapper" {
    const allocator = std.testing.allocator;
    const entries = [_]tar.EncodeEntry{
        .{ .name = "folder/", .kind = .directory },
        .{ .name = "folder/payload.txt", .data = payload },
    };
    const cases = .{
        .{ compressed.Compression.none, auto.Format.raw_tar },
        .{ compressed.Compression.gzip, auto.Format.gzip },
        .{ compressed.Compression.bzip2, auto.Format.bzip2 },
        .{ compressed.Compression.brotli, auto.Format.brotli },
        .{ compressed.Compression.compress_z, auto.Format.compress_z },
        .{ compressed.Compression.lzma, auto.Format.lzma },
        .{ compressed.Compression.xz, auto.Format.xz },
        .{ compressed.Compression.lz4, auto.Format.lz4 },
        .{ compressed.Compression.lzip, auto.Format.lzip },
        .{ compressed.Compression.lzf, auto.Format.lzf },
        .{ compressed.Compression.zstandard, auto.Format.zstandard },
        .{ compressed.Compression.lzop, auto.Format.lzop },
    };
    inline for (cases) |case| {
        const encoded = try compressed.encodeAlloc(allocator, &entries, .{
            .compression = case[0],
        });
        defer allocator.free(encoded);
        try exercise(allocator, encoded, case[1], 1, 1);
        try exercise(allocator, encoded, case[1], 29, 31);
    }

    const raw = try tar.encodeAlloc(allocator, &entries);
    defer allocator.free(raw);
    const legacy = try lz4_legacy.encodeAlloc(allocator, raw, .{ .block_size = 1024 });
    defer allocator.free(legacy);
    try exercise(allocator, legacy, .lz4_legacy, 1, 1);
}

test "automatic incremental TAR reader gives valid raw header priority over magic bytes" {
    const allocator = std.testing.allocator;
    const magic_name = "\x1f\x8b-raw-name";
    const raw = try tar.encodeAlloc(allocator, &.{.{
        .name = magic_name,
        .data = payload,
    }});
    defer allocator.free(raw);
    var reader = auto.Reader.init(allocator);
    defer reader.deinit();
    var output: [payload.len]u8 = undefined;
    var input_offset: usize = 0;
    while (true) {
        const stepped = try reader.step(raw[input_offset..], &output);
        input_offset += stepped.input_read;
        if (stepped.status == .done) break;
        if (input_offset == raw.len) try reader.finish();
    }
    try std.testing.expectEqual(auto.Format.raw_tar, reader.detectedFormat().?);
}

test "automatic incremental TAR reader skips shared skippable prefixes" {
    const allocator = std.testing.allocator;
    const entries = [_]tar.EncodeEntry{.{ .name = "folder/payload.txt", .data = payload }};
    inline for (.{
        .{ compressed.Compression.lz4, auto.Format.lz4 },
        .{ compressed.Compression.zstandard, auto.Format.zstandard },
    }) |case| {
        const encoded = try compressed.encodeAlloc(allocator, &entries, .{
            .compression = case[0],
        });
        defer allocator.free(encoded);
        var wrapped: std.ArrayList(u8) = .empty;
        defer wrapped.deinit(allocator);
        var header: [8]u8 = undefined;
        std.mem.writeInt(u32, header[0..4], 0x184d_2a50, .little);
        std.mem.writeInt(u32, header[4..8], 700, .little);
        try wrapped.appendSlice(allocator, &header);
        try wrapped.appendNTimes(allocator, 0xa5, 700);
        try wrapped.appendSlice(allocator, encoded);

        var reader = auto.Reader.initWithOptions(allocator, .{
            .decoded_bridge_size = 17,
        });
        defer reader.deinit();
        var output: [31]u8 = undefined;
        var input_offset: usize = 0;
        var finish_sent = false;
        while (true) {
            const input_end = @min(wrapped.items.len, input_offset + 13);
            const stepped = try reader.step(wrapped.items[input_offset..input_end], &output);
            input_offset += stepped.input_read;
            if (stepped.status == .done) break;
            if (!finish_sent and input_offset == wrapped.items.len) {
                try reader.finish();
                finish_sent = true;
            }
        }
        const snapshot = reader.snapshot();
        try std.testing.expectEqual(case[1], snapshot.format.?);
        try std.testing.expectEqual(@as(usize, 1), snapshot.skipped_frames);
        try std.testing.expectEqual(@as(u64, 708), snapshot.skipped_bytes);
    }
}

test "automatic incremental TAR reader enforces probe limits fallback and OOM" {
    const allocator = std.testing.allocator;
    var empty = auto.Reader.init(allocator);
    defer empty.deinit();
    try empty.finish();
    try std.testing.expectEqual(
        tar.incremental_reader.Status.done,
        (try empty.step("", &.{})).status,
    );
    try std.testing.expectEqual(auto.Format.raw_tar, empty.detectedFormat().?);

    var unknown: [512]u8 = @splat(0xa5);
    var reject = auto.Reader.initWithOptions(allocator, .{
        .ambiguous_fallback = .reject,
    });
    defer reject.deinit();
    var output: [64]u8 = undefined;
    try std.testing.expectError(
        error.UnknownTarCompression,
        reject.step(&unknown, &output),
    );
    try std.testing.expectError(error.TarAutoReaderPoisoned, reject.step("", &output));

    var limited = auto.Reader.initWithOptions(allocator, .{ .max_input_size = 511 });
    defer limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(&unknown, &output));

    var skippable = auto.Reader.initWithOptions(allocator, .{ .max_skippable_frames = 0 });
    defer skippable.deinit();
    std.mem.writeInt(u32, unknown[0..4], 0x184d_2a50, .little);
    std.mem.writeInt(u32, unknown[4..8], 0, .little);
    try std.testing.expectError(error.TooManySkippableFrames, skippable.step(&unknown, &output));

    const entries = [_]tar.EncodeEntry{.{ .name = "folder/payload.txt", .data = payload }};
    const gzip = try compressed.encodeAlloc(allocator, &entries, .{ .compression = .gzip });
    defer allocator.free(gzip);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, encoded: []const u8) !void {
            var reader = auto.Reader.initWithOptions(failing_allocator, .{
                .decoded_bridge_size = 17,
            });
            defer reader.deinit();
            var scratch: [31]u8 = undefined;
            var offset: usize = 0;
            var finish_sent = false;
            while (true) {
                const stepped = try reader.step(encoded[offset..], &scratch);
                offset += stepped.input_read;
                if (stepped.status == .done) break;
                if (!finish_sent and offset == encoded.len) {
                    try reader.finish();
                    finish_sent = true;
                }
            }
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{gzip});
}
