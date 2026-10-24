const std = @import("std");
const h = @import("br_stream_counter_helpers.zig");
const br = h.br;
const Counter = h.Counter;

test "Brotli stream counters cumulative API types preserve physical usize storage" {
    try std.testing.expectEqual(if (@bitSizeOf(usize) < 64) u64 else usize, Counter);
    inline for (.{ br.IncrementalCopyStreamDecoder, br.IncrementalStreamDecoder, br.IncrementalStoredStreamDecoder, br.IncrementalLiteralStreamDecoder, br.IncrementalRleStreamDecoder }) |Decoder| {
        try std.testing.expectEqual(Counter, Decoder.Counter);
        try std.testing.expectEqual(Counter, @FieldType(Decoder.Options, "max_output_len"));
    }
    try std.testing.expectEqual(usize, @FieldType(br.IncrementalCopyStreamDecoder, "copy_distance"));
    try std.testing.expectEqual(usize, @FieldType(br.IncrementalCopyStreamDecoder, "stored_remaining"));
    try std.testing.expectEqual(usize, @FieldType(br.IncrementalCopyStreamDecoder, "metadata_written"));
    try std.testing.expectEqual(usize, @FieldType(br.IncrementalLiteralStreamDecoder, "output_remaining"));
    try std.testing.expectEqual(usize, @FieldType(br.IncrementalRleStreamDecoder, "output_remaining"));
    try std.testing.expectEqual(?Counter, @FieldType(h.core.StreamingDiagnostics, "error_input_offset"));
    try std.testing.expectEqual(?usize, @FieldType(h.core.StreamingDiagnostics, "payload_remaining"));
}

test "Brotli stream counters coded bit cursor wraps while checkpoint retains real bytes" {
    const Reader = @import("../br/incremental/bit_reader.zig").Reader;
    const input = [_]u8{ 0xa5, 0x7a };
    var read: usize = 0;
    var staged: u128 = 0;
    var staged_count: u8 = 0;
    var phase: usize = 0;
    var reader = Reader.init(&input, &read, &staged, &staged_count, &phase);
    try std.testing.expectEqual(@as(u8, 5), try reader.readBits(u8, 3));
    // The omitted prefix contains whole coded bytes. A decoded three-bit
    // suffix leaves the exact real reservoir and mod-8 position seen here.
    const prefix_bits: u128 = (@as(u128, 1) << @bitSizeOf(usize)) - 8 + 3;
    phase = @truncate(prefix_bits);
    const saved = reader.checkpoint();
    try std.testing.expectEqual(@as(u8, 0x54), try reader.readBits(u8, 7));
    try std.testing.expectEqual(@as(usize, 2), phase);
    try std.testing.expectEqual(@as(usize, 2), read);
    try reader.restoreKeepingInput(saved);
    try std.testing.expectEqual(@as(usize, @truncate(prefix_bits)), phase);
    try std.testing.expectEqual(@as(u8, 13), staged_count);
    try std.testing.expectEqual(@as(u8, 0x54), try reader.readBits(u8, 7));
    try std.testing.expectEqual(@as(usize, 2), read);
    try std.testing.expectEqual(@as(u8, 0x1e), try reader.readBits(u8, 6));
    try std.testing.expectEqual(@as(usize, 8), phase);
    try std.testing.expectEqual(@as(u8, 0), staged_count);
    reader.restore(saved);
    try std.testing.expectEqual(@as(usize, 1), read);
    try std.testing.expectEqual(@as(u8, 5), staged_count);
    try std.testing.expectEqual(@as(u8, 0x54), try reader.readBits(u8, 7));
}

test "Brotli stream counters metadata input crosses 4 GiB without output or capture growth" {
    inline for (.{ false, true }) |copy| {
        var capture: [3]u8 = undefined;
        var lengths: [2]usize = undefined;
        var history: [3]u8 = undefined;
        var decoder = if (copy)
            br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .max_output_len = 0, .metadata_output = &capture, .metadata_block_lengths = &lengths })
        else
            br.IncrementalStoredStreamDecoder.initWithOptions(.{ .max_output_len = 0, .metadata_output = &capture, .metadata_block_lengths = &lengths });
        const boundary: Counter = @as(Counter, 1) << 32;
        const blocks = (boundary - 1) / h.first_metadata.len;
        const model = try h.metadataPrefix(&decoder, blocks);
        var output = [_]u8{0xa7} ** 7;
        const result = try decoder.step(&h.next_metadata, &output);
        try std.testing.expectEqual(h.next_metadata.len, result.progress.input_read);
        try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);
        try std.testing.expectEqual(@as(Counter, @intCast(model.input_bytes + h.next_metadata.len)), decoder.snapshot().input_read);
        try std.testing.expect(decoder.snapshot().input_read > boundary);
        try std.testing.expectEqual(@as(Counter, @intCast(model.metadata_bytes + h.pattern.len)), decoder.snapshot().metadata_total);
        try std.testing.expectEqual(blocks + 1, decoder.snapshot().metadata_block_count);
        try std.testing.expectEqualSlices(u8, h.pattern[0..capture.len], &capture);
        try std.testing.expectEqualSlices(usize, &.{ h.pattern.len, h.pattern.len }, &lengths);
        try std.testing.expect(decoder.snapshot().metadata_truncated);
        try std.testing.expect(decoder.snapshot().metadata_blocks_truncated);
        try std.testing.expectEqualSlices(u8, &([_]u8{0xa7} ** 7), &output);
    }
}

test "Brotli stream counters metadata totals pass 4 GiB with bounded owned state" {
    var capture: [3]u8 = undefined;
    var decoder = br.IncrementalStreamDecoder.initWithOptions(h.allocator, .{ .max_output_len = 0, .max_history_len = 3, .metadata_output = &capture });
    defer decoder.deinit();
    const boundary: Counter = @as(Counter, 1) << 32;
    const blocks = boundary / h.pattern.len - 1;
    const model = try h.ownedMetadataPrefix(&decoder, blocks);
    const retained = decoder.workingMemoryBytes();
    const first = try decoder.step(&h.next_metadata, &.{});
    try std.testing.expectEqual(h.next_metadata.len, first.progress.input_read);
    const second = try decoder.step(&h.next_metadata, &.{});
    try std.testing.expectEqual(h.next_metadata.len, second.progress.input_read);
    const inner = decoder.progressive.?.snapshot();
    try std.testing.expectEqual(boundary + h.pattern.len, inner.metadata_total);
    try std.testing.expectEqual(@as(Counter, @intCast(model.input_bytes + h.next_metadata.len * 2)), decoder.snapshot().compressed_bytes);
    try std.testing.expectEqual(@as(Counter, 0), decoder.snapshot().output_written);
    try std.testing.expectEqual(retained, decoder.workingMemoryBytes());
    try std.testing.expectEqualSlices(u8, h.pattern[0..capture.len], &capture);
}
