const std = @import("std");
const core = @import("../../core.zig");
const deflate = @import("../../deflate.zig");

test "raw deflate incremental stored encoder splits flushes and resumes" {
    const first = "first raw deflate stored segment";
    const second = "second segment after flush";
    var encoder = deflate.RawDeflateIncrementalStoredEncoder.initWithOptions(std.testing.allocator, .{ .block_len = 17 });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [7]u8 = undefined;
    var result: core.StepResult = undefined;

    var offset: usize = 0;
    while (offset < first.len) {
        result = try encoder.step(first[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.flush();
    while (true) {
        result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
    }
    const flushed_len = encoded.items.len;
    encoder.flush();
    result = try encoder.step("", &scratch);
    try std.testing.expectEqual(.need_input, result.status);
    try std.testing.expectEqual(flushed_len, encoded.items.len);

    offset = 0;
    while (offset < second.len) {
        result = try encoder.step(second[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try deflate.decodeRawStoredAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
    encoder.reset();
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().input_read);
}

test "raw deflate incremental stored encoder enforces sizes and plan" {
    var limited = deflate.RawDeflateIncrementalStoredEncoder.initWithOptions(std.testing.allocator, .{ .max_input_len = 3 });
    defer limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, limited.step("four", &.{}));

    var exact = deflate.RawDeflateIncrementalStoredEncoder.initExactSize(std.testing.allocator, .{}, 4);
    defer exact.deinit();
    var scratch: [8]u8 = undefined;
    _ = try exact.step("abc", &scratch);
    exact.finish();
    try std.testing.expectError(error.SizeMismatch, exact.step("", &scratch));

    var invalid = deflate.RawDeflateIncrementalStoredEncoder.initWithOptions(std.testing.allocator, .{ .block_len = 0 });
    defer invalid.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, invalid.step("", &.{}));
}

test "raw deflate incremental fixed encoder retains history and sync flushes" {
    const first = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const second = "prefix-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-tail";
    var encoder = deflate.RawDeflateIncrementalFixedEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = first.len,
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [9]u8 = undefined;
    var result: core.StepResult = undefined;

    var offset: usize = 0;
    while (offset < first.len) {
        result = try encoder.step(first[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.flush();
    while (true) {
        result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
    }
    offset = 0;
    while (offset < second.len) {
        result = try encoder.step(second[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);

    const stored = try deflate.encodeRawStoredAlloc(std.testing.allocator, first ++ second);
    defer std.testing.allocator.free(stored);
    try std.testing.expect(encoded.items.len < stored.len);
}

test "raw deflate incremental fixed encoder handles empty and exact streams" {
    var empty = deflate.RawDeflateIncrementalFixedEncoder.init(std.testing.allocator);
    defer empty.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [3]u8 = undefined;
    empty.finish();
    while (true) {
        const result = try empty.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), decoded.len);

    var exact = deflate.RawDeflateIncrementalFixedEncoder.initExactSize(std.testing.allocator, .{}, 4);
    defer exact.deinit();
    _ = try exact.step("abc", &scratch);
    exact.finish();
    try std.testing.expectError(error.SizeMismatch, exact.step("", &scratch));
}
