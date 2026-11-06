//! Public ZIP bridge contracts. Wide pledges are metadata, while every supplied
//! plaintext slice and retained test archive remain physically bounded.
const std = @import("std");
const zip = @import("../../zip.zig");

const wide_size: u64 = (@as(u64, 1) << 32) + 17;
const name = "wide.bin";

fn options() zip.IncrementalWriterOptions {
    return .{
        .deflate_options = .{ .block_len = 64, .compression = .{ .parser = .hash } },
        .deflate64_options = .{ .block_len = 64 },
        .zstd_options = .{ .window_log = 10, .block_size_max = 64, .selection = .raw_or_rle },
    };
}

test "ZIP incremental writer wide input pledges publish ZIP64 headers and accept bounded prefixes" {
    inline for (.{ zip.CompressionMethod.deflate, .zstandard_legacy, .zstandard }) |method| {
        var settings = options();
        settings.deflate_options.max_input_len = wide_size;
        var writer = try zip.IncrementalWriter.initWithOptions(std.testing.allocator, settings);
        defer writer.deinit();
        try writer.beginEntry(.{ .name = name, .method = method, .expected_size = wide_size });
        var header: std.ArrayList(u8) = .empty;
        defer header.deinit(std.testing.allocator);
        try drainHeader(&writer, &header);
        try expectZip64Header(header.items, method);

        var scratch: [37]u8 = undefined;
        const prefix = "RRRRRRRRRRRRRRRRR";
        var accepted: usize = 0;
        while (accepted < prefix.len) {
            const stepped = try writer.step(prefix[accepted..], &scratch);
            accepted += stepped.progress.input_read;
            try std.testing.expect(stepped.progress.input_read != 0 or stepped.progress.output_written != 0);
        }
        const before = writer.snapshot();
        try std.testing.expectEqual(@as(u64, prefix.len), before.input_read);
        try std.testing.expectEqual(@as(u64, prefix.len), before.current_uncompressed_size);
        try std.testing.expectError(error.SizeMismatch, writer.finishEntry());
        try std.testing.expectEqualDeep(before, writer.snapshot());
    }
}

test "ZIP incremental writer wide input ZIP32 sentinel boundary is an entry metadata rule" {
    for ([_]u64{ std.math.maxInt(u32) - 1, std.math.maxInt(u32), wide_size }) |pledge| {
        var writer = try zip.IncrementalWriter.init(std.testing.allocator);
        defer writer.deinit();
        try writer.beginEntry(.{ .name = name, .method = .stored, .expected_size = pledge });
        var header: std.ArrayList(u8) = .empty;
        defer header.deinit(std.testing.allocator);
        try drainHeader(&writer, &header);
        if (pledge >= std.math.maxInt(u32)) {
            try expectZip64Header(header.items, .stored);
        } else {
            try std.testing.expectEqual(@as(u16, 0), read(u16, header.items, 28));
            try std.testing.expectEqual(@as(u32, 0), read(u32, header.items, 18));
            try std.testing.expectEqual(@as(u32, 0), read(u32, header.items, 22));
        }

        var zip32 = try zip.IncrementalWriter.initWithOptions(std.testing.allocator, .{ .zip64 = .never });
        defer zip32.deinit();
        const before = zip32.snapshot();
        if (pledge >= std.math.maxInt(u32)) {
            try std.testing.expectError(error.Zip32LimitExceeded, zip32.beginEntry(.{ .name = name, .method = .stored, .expected_size = pledge }));
            try std.testing.expectEqualDeep(before, zip32.snapshot());
        } else {
            try zip32.beginEntry(.{ .name = name, .method = .stored, .expected_size = pledge });
        }
    }
}

test "ZIP incremental writer wide input codec and archive caps reject pledges before header publication" {
    {
        var settings = options();
        settings.deflate_options.max_input_len = wide_size - 1;
        var writer = try zip.IncrementalWriter.initWithOptions(std.testing.allocator, settings);
        defer writer.deinit();
        const before = writer.snapshot();
        try std.testing.expectError(error.OutputLimitExceeded, writer.beginEntry(.{ .name = name, .method = .deflate, .expected_size = wide_size }));
        try std.testing.expectEqualDeep(before, writer.snapshot());
    }
    inline for (.{ zip.CompressionMethod.deflate, .zstandard_legacy, .zstandard }) |method| {
        var settings = options();
        settings.max_uncompressed_size = wide_size - 1;
        var writer = try zip.IncrementalWriter.initWithOptions(std.testing.allocator, settings);
        defer writer.deinit();
        const before = writer.snapshot();
        try std.testing.expectError(error.OutputLimitExceeded, writer.beginEntry(.{ .name = name, .method = method, .expected_size = wide_size }));
        try std.testing.expectEqualDeep(before, writer.snapshot());
    }
    // A codec whose limit is still local must retain that limit after the
    // common bridge comparison becomes wide.
    var narrow = try zip.IncrementalWriter.initWithOptions(std.testing.allocator, .{ .shrink_options = .{ .max_input_len = 7 } });
    defer narrow.deinit();
    const before = narrow.snapshot();
    try std.testing.expectError(error.OutputLimitExceeded, narrow.beginEntry(.{ .name = name, .method = .shrink, .expected_size = wide_size }));
    try std.testing.expectEqualDeep(before, narrow.snapshot());
    var deflate64 = try zip.IncrementalWriter.initWithOptions(std.testing.allocator, .{ .deflate64_options = .{ .max_input_len = 7 } });
    defer deflate64.deinit();
    const deflate64_before = deflate64.snapshot();
    try std.testing.expectError(error.OutputLimitExceeded, deflate64.beginEntry(.{ .name = name, .method = .deflate64, .expected_size = wide_size }));
    try std.testing.expectEqualDeep(deflate64_before, deflate64.snapshot());
}

test "ZIP incremental writer wide input actual cap and pledge failures preserve accepted prefix and caller guard" {
    inline for (.{ zip.CompressionMethod.deflate, .zstandard_legacy, .zstandard }) |method| {
        inline for (.{ false, true }) |pledged| {
            var settings = options();
            if (!pledged) {
                if (method == .deflate)
                    settings.deflate_options.max_input_len = 7
                else
                    settings.max_uncompressed_size = 7;
            }
            var writer = try zip.IncrementalWriter.initWithOptions(std.testing.allocator, settings);
            defer writer.deinit();
            try writer.beginEntry(.{ .name = name, .method = method, .expected_size = if (pledged) 7 else null });
            var header: std.ArrayList(u8) = .empty;
            defer header.deinit(std.testing.allocator);
            try drainHeader(&writer, &header);
            var scratch: [37]u8 = undefined;
            var accepted: usize = 0;
            while (accepted < 7) {
                const stepped = try writer.step("RRRRRRR"[accepted..], &scratch);
                accepted += stepped.progress.input_read;
            }
            const before = writer.snapshot();
            var guard: [37]u8 = @splat(0xa5);
            try std.testing.expectError(if (pledged) error.SizeMismatch else error.OutputLimitExceeded, writer.step("R", &guard));
            const after = writer.snapshot();
            try std.testing.expectEqual(.poisoned, after.phase);
            try std.testing.expectEqual(before.input_read, after.input_read);
            try std.testing.expectEqual(before.output_written, after.output_written);
            try std.testing.expectEqual(before.current_uncompressed_size, after.current_uncompressed_size);
            try std.testing.expectEqual(before.current_compressed_size, after.current_compressed_size);
            try std.testing.expectEqual(before.pending_output, after.pending_output);
            try std.testing.expectEqualSlices(u8, &@as([37]u8, @splat(0xa5)), &guard);
        }
    }
}

test "ZIP incremental writer wide input bridge completes bounded ZIP64 deflate and Zstandard archives" {
    inline for (.{ zip.CompressionMethod.deflate, .zstandard_legacy, .zstandard }) |method| {
        var settings = options();
        settings.zip64 = .always;
        settings.deflate_options.max_input_len = wide_size;
        var writer = try zip.IncrementalWriter.initWithOptions(std.testing.allocator, settings);
        defer writer.deinit();
        const payload: [257]u8 = @splat('R');
        try writer.beginEntry(.{ .name = name, .method = method, .expected_size = payload.len });
        var bytes: std.ArrayList(u8) = .empty;
        defer bytes.deinit(std.testing.allocator);
        var scratch: [13]u8 = undefined;
        var accepted: usize = 0;
        while (accepted < payload.len) {
            const stepped = try writer.step(payload[accepted..@min(payload.len, accepted + 17)], &scratch);
            accepted += stepped.progress.input_read;
            try bytes.appendSlice(std.testing.allocator, scratch[0..stepped.progress.output_written]);
        }
        try writer.finishEntry();
        while (writer.snapshot().phase != .ready) {
            const stepped = try writer.step("", &scratch);
            try bytes.appendSlice(std.testing.allocator, scratch[0..stepped.progress.output_written]);
        }
        try writer.finishArchive();
        while (true) {
            const stepped = try writer.step("", &scratch);
            try bytes.appendSlice(std.testing.allocator, scratch[0..stepped.progress.output_written]);
            if (stepped.status == .done) break;
        }
        try expectZip64Header(bytes.items, method);
        const archive = try zip.parse(bytes.items);
        const entry = try archive.entryAt(0);
        try std.testing.expect(archive.zip64 and entry.zip64);
        try std.testing.expectEqual(@as(u64, payload.len), entry.uncompressed_size);
        const decoded = try archive.extractAlloc(std.testing.allocator, entry);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &payload, decoded);
        try std.testing.expectEqual(@as(u64, payload.len), writer.snapshot().input_read);
        try std.testing.expectEqual(@as(u64, bytes.items.len), writer.snapshot().output_written);
    }
}

fn drainHeader(writer: *zip.IncrementalWriter, bytes: *std.ArrayList(u8)) !void {
    var scratch: [7]u8 = undefined;
    while (writer.snapshot().phase == .entry_header) {
        const stepped = try writer.step("", &scratch);
        try bytes.appendSlice(std.testing.allocator, scratch[0..stepped.progress.output_written]);
    }
    try std.testing.expectEqual(.entry_data, writer.snapshot().phase);
}

fn expectZip64Header(bytes: []const u8, method: zip.CompressionMethod) !void {
    try std.testing.expectEqual(@as(u32, 0x04034b50), read(u32, bytes, 0));
    try std.testing.expect(read(u16, bytes, 4) >= 45);
    try std.testing.expect(read(u16, bytes, 6) & 8 != 0);
    try std.testing.expectEqual(@intFromEnum(method), read(u16, bytes, 8));
    try std.testing.expectEqual(std.math.maxInt(u32), read(u32, bytes, 18));
    try std.testing.expectEqual(std.math.maxInt(u32), read(u32, bytes, 22));
    try std.testing.expectEqual(@as(u16, 20), read(u16, bytes, 28));
    const extra = 30 + read(u16, bytes, 26);
    try std.testing.expectEqual(@as(u16, 1), read(u16, bytes, extra));
    try std.testing.expectEqual(@as(u16, 16), read(u16, bytes, extra + 2));
    try std.testing.expectEqual(@as(u64, 0), read(u64, bytes, extra + 4));
    try std.testing.expectEqual(@as(u64, 0), read(u64, bytes, extra + 12));
}

fn read(comptime T: type, bytes: []const u8, offset: usize) T {
    return std.mem.readInt(T, bytes[offset..][0..(@bitSizeOf(T) / 8)], .little);
}
