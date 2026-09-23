const std = @import("std");

// libzstd 1.5.7, level 3; payload generated below (6,000 short assignments).
pub fn run(comptime zstd: type, disable_split: *bool, grouped_hits: *usize) !void {
    defer {
        disable_split.* = false;
        grouped_hits.* = 0;
    }
    const allocator = std.testing.allocator;
    const hex = std.mem.trim(u8, @embedFile("../testdata/libzstd-dense-sparse-literals.frame.hex"), " \r\n\t");
    const frame = try allocator.alloc(u8, hex.len / 2);
    defer allocator.free(frame);
    _ = try std.fmt.hexToBytes(frame, hex);
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(allocator);
    var random_state: u32 = 31;
    for (0..6000) |index| {
        random_state = random_state *% 1664525 +% 1013904223;
        var line: [32]u8 = undefined;
        const text = try std.fmt.bufPrint(&line, "field_{d:0>2} += {d};", .{ (random_state >> 16) % 31, index % 5 });
        try payload.appendSlice(allocator, text);
    }
    const block = try zstd.inspectNativeFrameFirstBlock(frame);
    const shape = try zstd.inspectNativeFrameBlockSequenceModes(frame, block);
    try std.testing.expectEqual(@as(usize, 5820), shape.sequence_count);
    try std.testing.expectEqual(@as(usize, 2076), shape.regenerated_literals_size);
    const output = try allocator.alloc(u8, payload.items.len + 32);
    defer allocator.free(output);
    const reference = try allocator.alloc(u8, output.len);
    defer allocator.free(reference);
    @memset(output, 0xa5);
    @memset(reference, 0xa5);
    disable_split.* = false;
    grouped_hits.* = 0;
    try std.testing.expectEqual(payload.items.len, try zstd.decodeFrameInto(frame, output));
    try std.testing.expect(grouped_hits.* > 5000);
    try std.testing.expectEqualSlices(u8, payload.items, output[0..payload.items.len]);
    disable_split.* = true;
    try std.testing.expectEqual(payload.items.len, try zstd.decodeFrameInto(frame, reference));
    try std.testing.expectEqualSlices(u8, reference, output);
    disable_split.* = false;
    var reusable = zstd.NativeFrameDecoder.init(allocator);
    defer reusable.deinit();
    for (0..2) |_| {
        @memset(output, 0xa5);
        grouped_hits.* = 0;
        try std.testing.expectEqual(payload.items.len, try reusable.decodeIntoSlice(frame, output));
        try std.testing.expect(grouped_hits.* > 5000);
        try std.testing.expectEqualSlices(u8, reference, output);
    }
    try std.testing.expect(reusable.reusableSequenceTableHitCount() > 0);
    @memset(output, 0xa5);
    try std.testing.expectError(error.OutputTooSmall, zstd.decodeFrameInto(frame, output[0 .. payload.items.len - 1]));
    for (output[payload.items.len - 1 ..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    for ([_]usize{ 1, 5, frame.len / 2, frame.len - 1 }) |end| {
        disable_split.* = true;
        const expected_error = if (zstd.decodeFrameInto(frame[0..end], reference)) |_| return error.ExpectedTruncation else |err| err;
        disable_split.* = false;
        try std.testing.expectError(expected_error, zstd.decodeFrameInto(frame[0..end], output));
    }
    // The last third lies in the sequence payload. Compare accepted mutations
    // as well as errors against the scalar route on the same complete frame.
    for (0..32) |index| {
        const byte_index = frame.len * 2 / 3 + index * (frame.len / 3 - 1) / 32;
        const bit: u8 = @as(u8, 1) << @intCast(index % 8);
        frame[byte_index] ^= bit;
        defer frame[byte_index] ^= bit;
        @memset(output, 0xa5);
        @memset(reference, 0xa5);
        disable_split.* = true;
        const expected = zstd.decodeFrameInto(frame, reference);
        disable_split.* = false;
        const actual = zstd.decodeFrameInto(frame, output);
        if (expected) |expected_len| {
            const actual_len = try actual;
            try std.testing.expectEqual(expected_len, actual_len);
            try std.testing.expectEqualSlices(u8, reference[0..expected_len], output[0..actual_len]);
        } else |err| try std.testing.expectError(err, actual);
        for (output[payload.items.len..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    }
    var incremental = zstd.NativeIncrementalFrameDecoder.init(allocator);
    defer incremental.deinit();
    @memset(output, 0xa5);
    var read: usize = 0;
    var written: usize = 0;
    while (true) {
        const result = try incremental.step(frame[read..@min(frame.len, read + 47)], output[written..@min(payload.items.len, written + 113)]);
        read += result.progress.input_read;
        written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expectEqual(frame.len, read);
    try std.testing.expectEqual(payload.items.len, written);
    try std.testing.expectEqualSlices(u8, payload.items, output[0..written]);
    for (output[written..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    var stage = try zstd.prepareNativeSequenceDecodeStage(allocator, frame);
    defer stage.deinit();
    try std.testing.expectEqual(@as(usize, 1), stage.shape().wide_all_fse_block_count);
    try std.testing.expectEqual(@as(usize, 0), stage.shape().bounded_all_fse_block_count);
    try std.testing.expectEqual(shape.sequence_count, (try stage.decode()).sequence_count);
}
