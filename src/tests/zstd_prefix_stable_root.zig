const std = @import("std");
const stable_frames = @import("zstd_stable_output/fixtures.zig");
const allocator = std.testing.allocator;

pub fn prefixContracts(comptime V: type) !void {
    const prefix = "vort package prefix history stays borrowed until its one call ends\n" ** 4;
    const native_options: V.ZstdNativeFrameOptions = .{ .selection = .literal_only };
    const encoded = try V.zstdEncodeNativeFrameWithPrefixAlloc(allocator, prefix, native_options, prefix);
    defer allocator.free(encoded.frame);

    const decoded = try V.zstdDecodeFrameAllocWithPrefix(allocator, encoded.frame, .{}, prefix);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(prefix, decoded);
    const size = try V.zstdDecodedFrameSizeWithPrefix(encoded.frame, .{}, prefix);
    try std.testing.expectEqual(@as(@TypeOf(size), prefix.len), size);
    var into: [prefix.len]u8 = undefined;
    try std.testing.expectEqual(prefix.len, try V.zstdDecodeFrameIntoWithPrefix(allocator, encoded.frame, &into, .{}, prefix));
    try std.testing.expectEqualStrings(prefix, &into);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "saved:");
    try std.testing.expectEqual(prefix.len, try V.zstdDecodeFrameAppendWithPrefix(allocator, &appended, encoded.frame, .{}, prefix));
    try std.testing.expectEqualStrings("saved:" ++ prefix, appended.items);

    const options: V.ZstdFrameOptions = .{ .content_checksum = true };
    const facade = try V.zstdEncodeFrameWithLevelAndOptionsAndPrefixAlloc(allocator, prefix, -3, options, prefix);
    defer allocator.free(facade);
    const facade_decoded = try V.zstdDecodeFrameAllocWithPrefix(allocator, facade, .{}, prefix);
    defer allocator.free(facade_decoded);
    try std.testing.expectEqualStrings(prefix, facade_decoded);

    const owned_prefix = try allocator.dupe(u8, prefix);
    var prefix_live = true;
    defer if (prefix_live) allocator.free(owned_prefix);
    var reusable = V.ZstdNativeFrameDecoder.init(allocator);
    defer reusable.deinit();
    try reusable.setPrefix(owned_prefix);
    try std.testing.expectEqual(V.ZstdPrefixPhase.pending, reusable.prefixSnapshot().phase);
    try std.testing.expectEqual(V.ZstdDictionaryUsage.prefix, reusable.prefixSnapshot().usage);
    try std.testing.expectEqual(@as(?V.ZstdPrefixContentType, .raw), reusable.prefixSnapshot().content_type);
    try std.testing.expectEqual(V.ZstdPrefixPurpose.none, reusable.prefixSnapshot().used_for);
    reusable.resetSession();
    try std.testing.expectEqual(V.ZstdPrefixPhase.pending, reusable.prefixSnapshot().phase);
    const once = try reusable.decodeAlloc(encoded.frame);
    defer allocator.free(once);
    try std.testing.expectEqualStrings(prefix, once);
    try std.testing.expectEqual(V.ZstdPrefixPhase.none, reusable.prefixSnapshot().phase);
    try std.testing.expectEqual(V.ZstdDictionaryUsage.persistent, reusable.prefixSnapshot().usage);
    allocator.free(owned_prefix);
    prefix_live = false;
    reusable.resetSession();
    try std.testing.expectError(error.InvalidMatch, reusable.decodeAlloc(encoded.frame));
    std.debug.print("Zstd root prefix lifecycle audit: once_bytes={d}, facade_bytes={d}, consumed_usage={s}\n", .{ once.len, facade_decoded.len, @tagName(reusable.prefixSnapshot().usage) });
}

pub fn stableContracts(comptime V: type) !void {
    // This compressed sequence crosses RAW dictionary bytes into newly
    // produced caller output, then expands an overlapping match.
    const crossing = try stable_frames.crossing(false, false, true, 0);
    defer allocator.free(crossing);
    const payload = "R" ** 16384;
    const multiblock = try stable_frames.rleBlocks(payload, false, false, 1024);
    defer allocator.free(multiblock);
    var first: [stable_frames.crossing_plain.len + 1]u8 = @splat(0xa5);
    const second = try allocator.alloc(u8, payload.len + 1);
    defer allocator.free(second);
    @memset(second, 0xa5);

    const heap_limit = 16 * 1024;
    var decoder = V.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .stop_after_first_frame = true,
        .max_output_len = stable_frames.crossing_plain.len + payload.len,
        .max_decoded_buffer_len = payload.len,
        .max_compressed_buffer_len = 256,
        .max_working_memory = heap_limit,
    });
    defer decoder.deinit();
    try decoder.setPrefix(stable_frames.crossing_dictionary);
    try decoder.bindStableOutput(&first);
    try driveStable(&decoder, crossing, stable_frames.crossing_plain, &first, 2);
    try std.testing.expectEqual(V.ZstdPrefixPhase.none, decoder.prefixSnapshot().phase);
    try std.testing.expectEqual(@as(u8, 0xa5), first[first.len - 1]);

    try decoder.nextStreamWithStableOutput(second);
    try std.testing.expectEqual(@as(usize, 0), decoder.stableOutput().len);
    try driveStable(&decoder, multiblock, payload, second, null);
    const snapshot = decoder.snapshot();
    try std.testing.expectEqual(@as(@TypeOf(snapshot.data_frame_count), 2), snapshot.data_frame_count);
    try std.testing.expect(snapshot.peak_working_bytes <= heap_limit);
    try std.testing.expectEqualStrings(stable_frames.crossing_plain, first[0 .. first.len - 1]);
    try std.testing.expectEqual(@as(u8, 0xa5), second[second.len - 1]);
    try decoder.clearStableOutput();
    try std.testing.expectEqual(@as(usize, 0), decoder.stableOutput().len);
    std.debug.print("Zstd root stable output audit: frames={d}, total_bytes={d}, peak_heap={d}, heap_limit={d}\n", .{ snapshot.data_frame_count, snapshot.output_written, snapshot.peak_working_bytes, heap_limit });
}

fn driveStable(decoder: anytype, frame: []const u8, expected: []const u8, buffer: []u8, max_write: ?usize) !void {
    var read: usize = 0;
    var written: usize = 0;
    var calls: usize = 0;
    while (decoder.snapshot().phase != .done) : (calls += 1) {
        try std.testing.expect(calls < frame.len + expected.len + 64);
        const input = frame[read..@min(frame.len, read + 3)];
        const result = if (max_write) |limit| try decoder.stepStableLimited(input, limit) else try decoder.stepStable(input);
        read += result.progress.input_read;
        written += result.progress.output_written;
        try std.testing.expect(written <= expected.len);
        try std.testing.expectEqual(written, decoder.stableOutput().len);
        try std.testing.expectEqual(buffer.ptr, decoder.stableOutput().ptr);
        try std.testing.expectEqualSlices(u8, expected[0..written], decoder.stableOutput());
        if (result.status == .need_input and read == frame.len) return error.TruncatedFrame;
    }
    try decoder.finish();
    try std.testing.expectEqual(frame.len, read);
    try std.testing.expectEqual(expected.len, written);
}
