const std = @import("std");

const allocator = std.testing.allocator;

pub fn contracts(comptime D: type) !void {
    try oneShotFamilies(D);
    try incrementalDetection(D);
    try dictionaryRecovery(D);
    try concatenationAndTail(D);
    try commitmentAndLimits(D);
    try cloneContracts(D);
}

fn oneShotFamilies(comptime D: type) !void {
    const plain = "auto wrapper one-shot payload" ** 4;
    const zlib = try D.encodeZlibFixedAlloc(allocator, plain);
    defer allocator.free(zlib);
    const gzip = try D.encodeGzipFixedAlloc(allocator, plain);
    defer allocator.free(gzip);
    var output: [plain.len]u8 = undefined;
    try std.testing.expectEqual(D.ZlibOrGzipFormat.zlib, try D.detectZlibOrGzip(zlib));
    try std.testing.expectEqual(D.ZlibOrGzipFormat.gzip, try D.detectZlibOrGzip(gzip));
    try std.testing.expectEqual(plain.len, try D.decodeZlibOrGzip(zlib, &output));
    try std.testing.expectEqualSlices(u8, plain, &output);
    try std.testing.expectEqual(plain.len, try D.decodeZlibOrGzip(gzip, &output));

    inline for (.{ .zlib, .gzip }) |format| {
        const wire = if (format == .zlib) zlib else gzip;
        const joined = try std.mem.concat(allocator, u8, &.{ wire, "tail" });
        defer allocator.free(joined);
        const prefix = try D.decodeZlibOrGzipPrefix(joined, &output);
        try std.testing.expectEqual(format, prefix.format);
        try std.testing.expectEqual(wire.len, prefix.input_read);
        try std.testing.expectEqual(plain.len, prefix.output_written);
        try std.testing.expectError(error.TrailingData, D.decodeZlibOrGzip(joined, &output));

        const owned = try D.decodeZlibOrGzipPrefixAllocLimited(allocator, joined, plain.len);
        defer owned.deinit(allocator);
        try std.testing.expectEqual(format, owned.format);
        try std.testing.expectEqualSlices(u8, plain, owned.bytes);
        const exact = try D.decodeZlibOrGzipPrefixAllocExactSize(allocator, joined, plain.len);
        defer exact.deinit(allocator);
        try std.testing.expectEqual(wire.len, exact.input_read);
        try std.testing.expectError(error.OutputLimitExceeded, D.decodeZlibOrGzipPrefixAllocLimited(allocator, joined, plain.len - 1));
        try std.testing.expectError(error.SizeMismatch, D.decodeZlibOrGzipPrefixAllocExactSize(allocator, joined, plain.len + 1));
    }

    try std.testing.expectError(error.TruncatedFrame, D.detectZlibOrGzip(&.{}));
    try std.testing.expectError(error.TruncatedFrame, D.detectZlibOrGzip(&.{0x78}));
    try std.testing.expectError(error.InvalidMagic, D.detectZlibOrGzip(&.{ 0x00, 0x00 }));
}

fn incrementalDetection(comptime D: type) !void {
    const plain = "incremental auto wrapper payload" ** 8;
    const zlib = try D.encodeZlibDynamicWithOptionsAlloc(allocator, plain, D.optionsForLevel(.default));
    defer allocator.free(zlib);
    const gzip = try D.encodeGzipDynamicWithOptionsAlloc(allocator, plain, D.optionsForLevel(.default));
    defer allocator.free(gzip);
    inline for (.{ .zlib, .gzip }) |format| {
        const wire = if (format == .zlib) zlib else gzip;
        var history: [65_536]u8 = undefined;
        var decoder = try D.ZlibOrGzipIncrementalDecoder.init(.{ .expected_output_len = plain.len }, &history);
        var output: [plain.len]u8 = undefined;
        var input_offset: usize = 0;
        var output_offset: usize = 0;
        while (true) {
            const input_end = @min(wire.len, input_offset + 1);
            const output_end = @min(output.len, output_offset + 7);
            const result = try decoder.step(wire[input_offset..input_end], output[output_offset..output_end]);
            input_offset += result.progress.input_read;
            output_offset += result.progress.output_written;
            if (decoder.snapshot().done) break;
            if (result.status == .need_input) try std.testing.expect(input_offset < wire.len);
        }
        try decoder.finish();
        try std.testing.expectEqual(format, decoder.selectedFormat().?);
        try std.testing.expectEqual(wire.len, input_offset);
        try std.testing.expectEqualSlices(u8, plain, &output);
        decoder.reset();
        try std.testing.expect(decoder.selectedFormat() == null);
    }
}

fn dictionaryRecovery(comptime D: type) !void {
    const dictionary = "auto wrapper preset dictionary " ** 4;
    const plain = dictionary ++ "payload payload";
    const wire = try D.encodeZlibFixedWithDictionaryAlloc(allocator, plain, dictionary, D.optionsForLevel(.default));
    defer allocator.free(wire);
    var history: [65_536]u8 = undefined;
    var decoder = try D.ZlibOrGzipIncrementalDecoder.init(.{ .expected_output_len = plain.len }, &history);
    var output: [plain.len]u8 = undefined;
    const first = decoder.step(wire, &output);
    if (first) |_| return error.ExpectedNeedDictionary else |err| try std.testing.expectEqual(error.NeedDictionary, err);
    const failed = decoder.snapshot().last_step_progress;
    try std.testing.expectEqual(D.ZlibOrGzipFormat.zlib, decoder.selectedFormat().?);
    try std.testing.expect(decoder.requiredDictionaryId() != null);
    try std.testing.expectError(error.DictionaryMismatch, decoder.provideDictionary("wrong"));
    try decoder.provideDictionary(dictionary);
    const resumed = try decoder.step(wire[failed.input_read..], &output);
    try std.testing.expectEqual(plain.len, resumed.progress.output_written);
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, plain, &output);

    const owned = try D.decodeZlibOrGzipPrefixAllocWithDictionaryExactSize(allocator, wire, dictionary, plain.len);
    defer owned.deinit(allocator);
    try std.testing.expectEqualSlices(u8, plain, owned.bytes);
}

fn concatenationAndTail(comptime D: type) !void {
    const one = "one ";
    const two = "two";
    const z1 = try D.encodeZlibFixedAlloc(allocator, one);
    defer allocator.free(z1);
    const z2 = try D.encodeZlibFixedAlloc(allocator, two);
    defer allocator.free(z2);
    const g1 = try D.encodeGzipFixedAlloc(allocator, one);
    defer allocator.free(g1);
    const g2 = try D.encodeGzipFixedAlloc(allocator, two);
    defer allocator.free(g2);
    inline for (.{ .zlib, .gzip }) |format| {
        const first = if (format == .zlib) z1 else g1;
        const second = if (format == .zlib) z2 else g2;
        const joined = try std.mem.concat(allocator, u8, &.{ first, second, "tail" });
        defer allocator.free(joined);
        var history: [65_536]u8 = undefined;
        var decoder = try D.ZlibOrGzipIncrementalDecoder.init(.{
            .expected_output_len = one.len + two.len,
            .allow_concatenated = true,
            .allow_trailing_data = true,
        }, &history);
        var output: [one.len + two.len]u8 = undefined;
        const result = try decoder.step(joined, &output);
        try std.testing.expect(result.progress.input_read < joined.len);
        try decoder.finish();
        try std.testing.expectEqualSlices(u8, one ++ two, &output);
        try std.testing.expectEqual(first.len + second.len, decoder.memberEndOffset().?);
    }

    const mixed = try std.mem.concat(allocator, u8, &.{ z1, g2 });
    defer allocator.free(mixed);
    var history: [65_536]u8 = undefined;
    var decoder = try D.ZlibOrGzipIncrementalDecoder.init(.{ .allow_concatenated = true, .allow_trailing_data = true }, &history);
    var output: [one.len + two.len]u8 = undefined;
    const mixed_step = try decoder.step(mixed, &output);
    try decoder.finish();
    try std.testing.expectEqual(z1.len, mixed_step.progress.input_read);
    try std.testing.expectEqual(one.len, mixed_step.progress.output_written);
}

fn commitmentAndLimits(comptime D: type) !void {
    var history: [65_536]u8 = undefined;
    var invalid = try D.ZlibOrGzipIncrementalDecoder.init(.{}, &history);
    try std.testing.expectError(error.InvalidMagic, invalid.step(&.{ 0, 0 }, &.{}));
    try std.testing.expectEqual(@as(usize, 2), invalid.snapshot().last_step_progress.input_read);

    var bad_gzip = try D.ZlibOrGzipIncrementalDecoder.init(.{}, &history);
    try std.testing.expectError(error.BadGzipHeader, bad_gzip.step(&.{ 0x1f, 0x8b, 0, 0, 0, 0, 0, 0, 0, 0 }, &.{}));
    try std.testing.expectEqual(D.ZlibOrGzipFormat.gzip, bad_gzip.selectedFormat().?);

    const plain = "limit" ** 32;
    const wire = try D.encodeZlibFixedAlloc(allocator, plain);
    defer allocator.free(wire);
    var limited = try D.ZlibOrGzipIncrementalDecoder.init(.{ .max_output_len = plain.len - 1 }, &history);
    var output: [plain.len]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(wire, &output));
    try std.testing.expectEqualStrings("OutputLimitExceeded", limited.snapshot().last_error_name);
}

fn cloneContracts(comptime D: type) !void {
    const plain = "auto wrapper cloned state" ** 8;
    const zlib = try D.encodeZlibFixedAlloc(allocator, plain);
    defer allocator.free(zlib);
    const gzip = try D.encodeGzipFixedAlloc(allocator, plain);
    defer allocator.free(gzip);

    // Detecting-state copies retain a split first byte without selecting a
    // wrapper or treating cloned history as initialized decode history.
    var detecting_history: [65_536]u8 = undefined;
    var detecting_copy_history: [65_536]u8 = undefined;
    var detecting = try D.ZlibOrGzipIncrementalDecoder.init(.{}, &detecting_history);
    _ = try detecting.step(zlib[0..1], &.{});
    var detecting_copy: D.ZlibOrGzipIncrementalDecoder = undefined;
    try detecting.cloneInto(&detecting_copy, .{ .history = &detecting_copy_history });
    try std.testing.expect(detecting_copy.selectedFormat() == null);

    inline for (.{ .zlib, .gzip }) |format| {
        const wire = if (format == .zlib) zlib else gzip;
        var history_a: [65_536]u8 = undefined;
        var history_b: [65_536]u8 = undefined;
        var original = try D.ZlibOrGzipIncrementalDecoder.init(.{ .expected_output_len = plain.len }, &history_a);
        const selected = try original.step(wire[0..2], &.{});
        try std.testing.expectEqual(@as(usize, 2), selected.progress.input_read);
        var cloned: D.ZlibOrGzipIncrementalDecoder = undefined;
        try original.cloneInto(&cloned, .{ .history = &history_b });
        var output_a: [plain.len]u8 = undefined;
        var output_b: [plain.len]u8 = undefined;
        const a = try original.step(wire[2..], &output_a);
        const b = try cloned.step(wire[2..], &output_b);
        try original.finish();
        try cloned.finish();
        try std.testing.expectEqual(a, b);
        try std.testing.expectEqualSlices(u8, &output_a, &output_b);
        try std.testing.expectEqualSlices(u8, plain, &output_a);
        try std.testing.expectEqual(format, cloned.selectedFormat().?);
    }
}
