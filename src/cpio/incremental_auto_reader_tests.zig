const std = @import("std");
const auto = @import("incremental_auto_reader.zig");
const archive = @import("archive.zig");
const br = @import("../br.zig");
const compressed = @import("compressed.zig");
const deflate = @import("../deflate.zig");
const lz4_legacy = @import("../lz4_legacy.zig");
const zstd = @import("../zstd.zig");
const writer = @import("writer.zig");

const payload = "auto-detected CPIO payload\n" ** 31;

fn exercise(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    expected_format: auto.Format,
    input_chunk: usize,
    output_chunk: usize,
) !void {
    var reader = auto.Reader.initWithOptions(allocator, .{
        .decoded_bridge_size = 17,
        .max_decoded_size = 1024 * 1024,
        .max_input_size = encoded.len,
        .cpio = .{
            .max_entry_size = 1024 * 1024,
            .max_total_output_size = 1024 * 1024,
            .max_archive_size = 1024 * 1024,
        },
    });
    defer reader.deinit();
    const output = try allocator.alloc(u8, output_chunk);
    defer allocator.free(output);
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);
    var input_offset: usize = 0;
    var finish_sent = false;
    var found = false;
    var active = false;
    var iterations: usize = 0;
    while (true) {
        iterations += 1;
        if (iterations > encoded.len * 64 + 8192) return error.TestUnexpectedResult;
        const input_end = @min(encoded.len, input_offset + input_chunk);
        const stepped = try reader.step(encoded[input_offset..input_end], output);
        input_offset += stepped.input_read;
        if (active) try actual.appendSlice(allocator, output[0..stepped.output_written]);
        switch (stepped.status) {
            .entry_header => {
                const info = reader.currentEntry() orelse return error.TestUnexpectedResult;
                if (!std.mem.eql(u8, info.name, "payload")) return error.TestUnexpectedResult;
                try std.testing.expect(!found and !active);
                actual.clearRetainingCapacity();
                active = true;
            },
            .entry_done => {
                if (!active) return error.TestUnexpectedResult;
                try std.testing.expectEqualSlices(u8, payload, actual.items);
                active = false;
                found = true;
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
    try std.testing.expect(found);
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(expected_format, reader.detectedFormat().?);
}

test "CPIO incremental auto reader detects every raw and compressed format" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = payload }};

    inline for (std.meta.tags(archive.Format)) |format| {
        const raw = try writer.encodeAlloc(allocator, &entries, .{ .format = format });
        defer allocator.free(raw);
        try exercise(allocator, raw, .raw_cpio, 1, 1);
        try exercise(allocator, raw, .raw_cpio, 11, 13);
    }

    inline for (.{
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
    }) |case| {
        const encoded = try compressed.encodeAlloc(allocator, &entries, .{
            .compression = case[0],
        });
        defer allocator.free(encoded);
        try exercise(allocator, encoded, case[1], 1, 1);
        try exercise(allocator, encoded, case[1], 11, 13);
    }

    const raw = try writer.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(raw);
    const legacy = try lz4_legacy.encodeAlloc(allocator, raw, .{ .block_size = 1024 });
    defer allocator.free(legacy);
    try exercise(allocator, legacy, .lz4_legacy, 1, 1);
    try exercise(allocator, legacy, .lz4_legacy, 11, 13);
}

test "CPIO incremental auto reader skips shared skippable frames" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = payload }};
    const gzip = try compressed.encodeAlloc(allocator, &entries, .{ .compression = .gzip });
    defer allocator.free(gzip);
    const first = try zstd.encodeSkippableFrameAlloc(allocator, 3, "meta-a");
    defer allocator.free(first);
    const second = try zstd.encodeSkippableFrameAlloc(allocator, 11, "metadata-b" ** 5);
    defer allocator.free(second);
    const stream = try allocator.alloc(u8, first.len + second.len + gzip.len);
    defer allocator.free(stream);
    @memcpy(stream[0..first.len], first);
    @memcpy(stream[first.len..][0..second.len], second);
    @memcpy(stream[first.len + second.len ..], gzip);

    try exercise(allocator, stream, .gzip, 1, 1);
    try exercise(allocator, stream, .gzip, 11, 13);

    var limited = auto.Reader.initWithOptions(allocator, .{ .max_skippable_frames = 1 });
    defer limited.deinit();
    var output: [32]u8 = undefined;
    var offset: usize = 0;
    while (true) {
        const stepped = limited.step(stream[offset..], &output) catch |err| {
            try std.testing.expectEqual(error.TooManySkippableFrames, err);
            break;
        };
        offset += stepped.input_read;
    }

    var truncated_header: [8]u8 = undefined;
    std.mem.writeInt(u32, truncated_header[0..4], 0x184d_2a50, .little);
    std.mem.writeInt(u32, truncated_header[4..8], 100, .little);
    var truncated = auto.Reader.init(allocator);
    defer truncated.deinit();
    _ = try truncated.step(&truncated_header, &output);
    try truncated.finish();
    try std.testing.expectError(error.TruncatedFrame, truncated.step("", &output));
}

test "CPIO incremental auto reader exposes ambiguous fallback policy" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = payload }};
    const raw = try writer.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(raw);
    const brotli = try br.encodeSimpleStreamAlloc(allocator, raw);
    defer allocator.free(brotli);
    try exercise(allocator, brotli, .brotli, 3, 5);

    var reject = auto.Reader.initWithOptions(allocator, .{ .ambiguous_fallback = .reject });
    defer reject.deinit();
    var output: [64]u8 = undefined;
    var offset: usize = 0;
    while (true) {
        const stepped = reject.step(brotli[offset..], &output) catch |err| {
            try std.testing.expectEqual(error.UnknownCpioCompression, err);
            break;
        };
        offset += stepped.input_read;
    }

    var raw_fallback = auto.Reader.initWithOptions(
        allocator,
        .{ .ambiguous_fallback = .raw_cpio },
    );
    defer raw_fallback.deinit();
    const junk = "\xffnot a CPIO archive";
    offset = 0;
    while (true) {
        const stepped = raw_fallback.step(junk[offset..], &output) catch |err| {
            try std.testing.expectEqual(error.InvalidMagic, err);
            break;
        };
        offset += stepped.input_read;
        if (offset == junk.len) try raw_fallback.finish();
    }

    var partial_raw = auto.Reader.init(allocator);
    defer partial_raw.deinit();
    _ = try partial_raw.step("0707", &output);
    try partial_raw.finish();
    try std.testing.expectError(error.TruncatedFrame, partial_raw.step("", &output));
}

test "CPIO incremental auto reader enforces input and decoded limits" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = payload }};
    const raw = try writer.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(raw);
    const gzip = try deflate.encodeGzipBestAlloc(
        allocator,
        raw,
        deflate.optionsForLevel(.default),
    );
    defer allocator.free(gzip);

    var input_limited = auto.Reader.initWithOptions(allocator, .{
        .max_input_size = gzip.len - 1,
    });
    defer input_limited.deinit();
    var output: [64]u8 = undefined;
    var offset: usize = 0;
    while (true) {
        const stepped = input_limited.step(gzip[offset..], &output) catch |err| {
            try std.testing.expectEqual(error.OutputLimitExceeded, err);
            break;
        };
        offset += stepped.input_read;
    }

    var decoded_limited = auto.Reader.initWithOptions(allocator, .{
        .max_decoded_size = raw.len - 1,
    });
    defer decoded_limited.deinit();
    offset = 0;
    while (true) {
        const stepped = decoded_limited.step(gzip[offset..], &output) catch |err| {
            try std.testing.expectEqual(error.OutputLimitExceeded, err);
            break;
        };
        offset += stepped.input_read;
        if (offset == gzip.len) try decoded_limited.finish();
    }
    try std.testing.expectError(error.CpioAutoReaderPoisoned, decoded_limited.step("", &output));
}

test "CPIO incremental auto reader preserves zero-output backpressure" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = "abc" }};
    const raw = try writer.encodeAlloc(allocator, &entries, .{ .block_size = 0 });
    defer allocator.free(raw);
    var reader = auto.Reader.init(allocator);
    defer reader.deinit();
    const header = try reader.step(raw, &.{});
    try std.testing.expectEqual(@import("incremental_reader.zig").Status.entry_header, header.status);
    try std.testing.expectEqual(auto.Format.raw_cpio, reader.detectedFormat().?);
    const blocked = try reader.step(raw[header.input_read..], &.{});
    try std.testing.expectEqual(@import("incremental_reader.zig").Status.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.input_read);
    try std.testing.expectEqual(@as(usize, 0), blocked.output_written);
}

test "CPIO incremental auto reader releases every allocation failure" {
    const allocator = std.testing.allocator;
    const long_name = "nested/" ++ "component-" ** 20 ++ "payload";
    const entries = [_]writer.EncodeEntry{.{ .name = long_name, .data = payload }};
    const encoded = try compressed.encodeAlloc(allocator, &entries, .{ .compression = .gzip });
    defer allocator.free(encoded);

    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, bytes: []const u8) !void {
            var reader = auto.Reader.initWithOptions(failing_allocator, .{
                .decoded_bridge_size = 17,
            });
            defer reader.deinit();
            var output: [31]u8 = undefined;
            var offset: usize = 0;
            var finish_sent = false;
            while (true) {
                const stepped = try reader.step(bytes[offset..], &output);
                offset += stepped.input_read;
                if (stepped.status == .done) break;
                if (!finish_sent and offset == bytes.len) {
                    try reader.finish();
                    finish_sent = true;
                }
            }
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{encoded});
}
