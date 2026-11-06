const std = @import("std");
const allocator = std.testing.allocator;

pub fn deflateContracts(comptime V: type) !void {
    const prefix = "a shared stream prefix";
    var source = V.RawDeflateIncrementalStoredEncoder.init(allocator);
    defer source.deinit();
    var common: [128]u8 = undefined;
    const first = try source.step(prefix, &common);
    try std.testing.expectEqual(prefix.len, first.progress.input_read);
    var fork = try source.clone(allocator);
    defer fork.deinit();
    var left: [128]u8 = undefined;
    var right: [128]u8 = undefined;
    @memcpy(left[0..first.progress.output_written], common[0..first.progress.output_written]);
    @memcpy(right[0..first.progress.output_written], common[0..first.progress.output_written]);
    const a = try finishStored(@TypeOf(source), &source, "A", &left, first.progress.output_written);
    const b = try finishStored(@TypeOf(fork), &fork, "B", &right, first.progress.output_written);
    const decoded_a = try V.decodeRawDeflateAlloc(allocator, a);
    defer allocator.free(decoded_a);
    const decoded_b = try V.decodeRawDeflateAlloc(allocator, b);
    defer allocator.free(decoded_b);
    try std.testing.expectEqualStrings(prefix ++ "A", decoded_a);
    try std.testing.expectEqualStrings(prefix ++ "B", decoded_b);

    var history: [32768]u8 = undefined;
    var independent_history: [history.len]u8 = undefined;
    var decoder = try V.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(.{}, &history);
    var copied: @TypeOf(decoder) = undefined;
    try decoder.cloneInto(&copied, .{ .history = &independent_history });
    const expected: V.DeflateCloneError = error.OverlappingCloneStorage;
    try std.testing.expectError(expected, decoder.cloneInto(&decoder, .{ .history = &independent_history }));
    var out: [128]u8 = undefined;
    const result = try copied.step(a, &out);
    try copied.finish();
    try std.testing.expectEqualSlices(u8, decoded_a, out[0..result.progress.output_written]);
}

fn finishStored(comptime E: type, encoder: *E, suffix: []const u8, output: []u8, shared: usize) ![]const u8 {
    const fed = try encoder.step(suffix, output[shared..]);
    try std.testing.expectEqual(suffix.len, fed.progress.input_read);
    var written = shared + fed.progress.output_written;
    encoder.finish();
    while (!encoder.snapshot().done) {
        const next = try encoder.step("", output[written..]);
        written += next.progress.output_written;
        if (next.status != .done and next.progress.output_written == 0) return error.NoCloneOutputProgress;
    }
    return output[0..written];
}

pub fn brotliContracts(comptime V: type) !void {
    const input = "context controls remain public across native codecs " ** 16;
    const options: V.BrotliPlannedEncodeOptions = .{ .quality = 6, .disable_literal_context_modeling = true };
    const encoded = try V.brEncodePlannedStreamWithOptionsAlloc(allocator, input, options);
    defer allocator.free(encoded);
    const decoded = try V.brDecodeStreamAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(input, decoded);
    const hq: V.BrotliHqOptions = .{ .disable_literal_context_modeling = true };
    try std.testing.expect(hq.disable_literal_context_modeling);
}

pub fn zstdContracts(comptime V: type) !void {
    const input = "dictionary identifiers are separate from dictionary contents";
    const options: V.ZstdNativeFrameOptions = .{ .dictionary_id = 123, .include_dictionary_id = false };
    const encoded = try V.zstdEncodeRawOrRleFrameWithOptionsAlloc(allocator, input, options);
    defer allocator.free(encoded);
    try std.testing.expectEqual(@as(u8, 0), encoded[4] & 3);
    const decoded = try V.zstdDecodeFrameAllocWithOptions(allocator, encoded, .{});
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(input, decoded);
    const facade: V.ZstdFrameOptions = .{ .include_dictionary_id = false };
    try std.testing.expect(!facade.include_dictionary_id);
}
