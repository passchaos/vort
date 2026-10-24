const std = @import("std");
const h = @import("br_stream_counter_helpers.zig");
const br = h.br;

test "Brotli stream counters independent dacd500a decoder wire and local progress" {
    inline for (h.goldens) |golden| {
        const wire = try h.goldenAlloc(golden);
        defer h.allocator.free(wire);
        var scratch: [257]u8 = undefined;
        var general = try br.StreamDecoder.init(wire, &scratch);
        var output: [257]u8 = undefined;
        var offset: usize = 0;
        while (true) {
            const result = try general.step(output[offset..@min(output.len, offset + 3)]);
            offset += result.progress.output_written;
            if (result.status == .done) break;
        }
        try std.testing.expectEqualSlices(u8, golden.payload, output[0..offset]);
        try std.testing.expectEqual(usize, @TypeOf(general.snapshot().output_written));
        try std.testing.expectEqual(usize, @TypeOf(general.offset));
        try std.testing.expectEqual(usize, @FieldType(h.core.Progress, "input_read"));
        try std.testing.expectEqual(usize, @FieldType(h.core.Progress, "output_written"));
        var history: [64]u8 = undefined;
        var copy = br.IncrementalCopyStreamDecoder.init(&history);
        try h.decodeSplit(&copy, wire, golden.payload);
        var owned = br.IncrementalStreamDecoder.init(h.allocator);
        defer owned.deinit();
        try h.decodeSplit(&owned, wire, golden.payload);
    }
}

test "Brotli stream counters independent dacd500a stored literal and RLE subsets" {
    const stored_wire = try h.goldenAlloc(h.goldens[0]);
    defer h.allocator.free(stored_wire);
    var stored = br.IncrementalStoredStreamDecoder.init();
    try h.decodeSplit(&stored, stored_wire, h.goldens[0].payload);
    stored.reset();
    try std.testing.expectEqual(@as(@TypeOf(stored.snapshot().input_read), 0), stored.snapshot().input_read);
    const literal_wire = try h.goldenAlloc(h.goldens[1]);
    defer h.allocator.free(literal_wire);
    var literal = br.IncrementalLiteralStreamDecoder.init();
    try h.decodeSplit(&literal, literal_wire, h.goldens[1].payload);
    literal.reset();
    try std.testing.expectEqual(@as(@TypeOf(literal.snapshot().output_written), 0), literal.snapshot().output_written);
    const rle_wire = try h.goldenAlloc(h.goldens[3]);
    defer h.allocator.free(rle_wire);
    var rle = br.IncrementalRleStreamDecoder.init();
    try h.decodeSplit(&rle, rle_wire, h.goldens[3].payload);
    rle.reset();
    try std.testing.expectEqual(@as(@TypeOf(rle.snapshot().output_written), 0), rle.snapshot().output_written);
}

test "Brotli stream counters three incremental encoder wires preserve dacd500a" {
    inline for (.{ br.IncrementalStoredStreamEncoder, br.IncrementalPlannedStreamEncoder, br.IncrementalStaticDictionaryStreamEncoder }, 4..) |Encoder, index| {
        var encoder = Encoder.initWithOptions(h.allocator, .{ .block_len = 16 });
        defer encoder.deinit();
        const wire = try h.encode(&encoder, h.goldens[index].payload);
        defer h.allocator.free(wire);
        const expected = try h.goldenAlloc(h.goldens[index]);
        defer h.allocator.free(expected);
        try std.testing.expectEqualSlices(u8, expected, wire);
        try std.testing.expectEqual(if (@bitSizeOf(usize) < 64) u64 else usize, Encoder.Counter);
        try std.testing.expectEqual(usize, @TypeOf(encoder.pending_offset));
        try std.testing.expectEqual(usize, @TypeOf(encoder.snapshot().buffered_input));
        try std.testing.expectEqual(usize, @TypeOf(encoder.snapshot().pending_output));
    }
}

test "Brotli stream counters legal stored prefix crosses output 4 GiB and nonpower ring" {
    var history: [3]u8 = undefined;
    var decoder = br.IncrementalCopyStreamDecoder.init(&history);
    const boundary: h.Counter = @as(h.Counter, 1) << 32;
    const model = try h.copyStoredPrefix(&decoder, boundary / h.pattern.len - 1);
    decoder.options.expected_output_len = boundary;
    const next = try h.nextStoredBlock();
    defer h.allocator.free(next);
    var output: [h.pattern.len]u8 = undefined;
    var read: usize = 0;
    var written: usize = 0;
    while (read != next.len) {
        const result = try decoder.step(next[read..@min(next.len, read + 2)], output[written..@min(output.len, written + 3)]);
        read += result.progress.input_read;
        written += result.progress.output_written;
    }
    try std.testing.expectEqualSlices(u8, h.pattern, &output);
    try std.testing.expectEqual(boundary, decoder.snapshot().output_written);
    try std.testing.expectEqual(@as(h.Counter, @intCast(model.input_bytes + next.len)), decoder.snapshot().input_read);
    var expected_ring: [history.len]u8 = undefined;
    h.fillRing(&expected_ring, boundary, h.pattern);
    try std.testing.expectEqualSlices(u8, &expected_ring, &history);
    try std.testing.expectEqualSlices(u8, h.pattern[h.pattern.len - 2 ..], &decoder.previous);
    const final = try decoder.step(&.{0x03}, &.{});
    try std.testing.expectEqual(.done, final.status);
    try decoder.finish();
    const snap = decoder.snapshot();
    try decoder.nextFrame(.{});
    try std.testing.expectEqual(snap.total_compressed, decoder.snapshot().total_compressed);
    try std.testing.expectEqual(boundary, decoder.snapshot().total_output);
    decoder.reset();
    try std.testing.expectEqual(@as(h.Counter, 0), decoder.snapshot().total_output);
}

test "Brotli stream counters stored header phase survives coded bit 32-bit wrap" {
    var history: [3]u8 = undefined;
    var decoder = br.IncrementalCopyStreamDecoder.init(&history);
    const bit_boundary: u128 = @as(u128, 1) << 32;
    const model = try h.copyStoredPrefix(&decoder, @intCast(bit_boundary / 24));
    const next = try h.nextStoredBlock();
    defer h.allocator.free(next);
    var output: [h.pattern.len]u8 = undefined;
    const result = try decoder.step(next, &output);
    try std.testing.expectEqual(next.len, result.progress.input_read);
    try std.testing.expectEqual(output.len, result.progress.output_written);
    try std.testing.expectEqualSlices(u8, h.pattern, &output);
    try std.testing.expectEqual(@as(usize, @truncate(model.consumed_header_bits + 24)), decoder.stream_bits);
    try std.testing.expectEqual(@as(usize, 0), decoder.stream_bits % 8);
    try std.testing.expectEqual(.trailer, decoder.phase);
}

test "Brotli stream counters literal stored continuation crosses 4 GiB with metadata intact" {
    var capture: [3]u8 = undefined;
    var decoder = br.IncrementalLiteralStreamDecoder.initWithOptions(.{ .metadata_output = &capture });
    const boundary: h.Counter = @as(h.Counter, 1) << 32;
    const model = try h.literalStoredPrefix(&decoder, (boundary - 5) / h.pattern.len);
    const next = try h.nextStoredBlock();
    defer h.allocator.free(next);
    var output: [h.pattern.len]u8 = undefined;
    const result = try decoder.step(next, &output);
    try std.testing.expectEqual(next.len, result.progress.input_read);
    try std.testing.expectEqualSlices(u8, h.pattern, &output);
    try std.testing.expectEqual(@as(h.Counter, @intCast(model.output_bytes + h.pattern.len)), decoder.snapshot().output_written);
    try std.testing.expect(decoder.snapshot().output_written > boundary);
    try std.testing.expectEqual(@as(h.Counter, 12), decoder.snapshot().metadata_total);
    try std.testing.expectEqualSlices(u8, "cou", &capture);
    const final = try decoder.step(&.{0x03}, &.{});
    try std.testing.expectEqual(.done, final.status);
    try decoder.finish();
    decoder.reset();
    try std.testing.expectEqual(@as(h.Counter, 0), decoder.snapshot().output_written);
    try std.testing.expectEqual(@as(h.Counter, 0), decoder.snapshot().metadata_total);
}
