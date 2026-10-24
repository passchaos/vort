const std = @import("std");
const h = @import("br_stream_counter_helpers.zig");
const br = h.br;
const Counter = h.Counter;

test "Brotli stream counters metadata Counter upper bound refuses before caller writes" {
    const Kind = enum { stored, copy, owned };
    inline for ([_]Kind{ .stored, .copy, .owned }) |kind| {
        var capture: [3]u8 = undefined;
        var history: [3]u8 = undefined;
        var decoder = switch (kind) {
            .stored => br.IncrementalStoredStreamDecoder.initWithOptions(.{ .max_output_len = 0, .metadata_output = &capture }),
            .copy => br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .max_output_len = 0, .metadata_output = &capture }),
            .owned => br.IncrementalStreamDecoder.initWithOptions(h.allocator, .{ .max_output_len = 0, .max_history_len = 3, .metadata_output = &capture }),
        };
        defer if (kind == .owned) decoder.deinit();
        const maximum: Counter = std.math.maxInt(Counter);
        const blocks = maximum / h.first_metadata.len;
        const model = if (kind == .owned) try h.ownedMetadataPrefix(&decoder, blocks) else try h.metadataPrefix(&decoder, blocks);
        const remaining: usize = @intCast(maximum - model.input_bytes);
        try std.testing.expect(remaining >= 2 and remaining < h.next_metadata.len);
        var output = [_]u8{0xb9} ** 7;
        const accepted = try decoder.step(h.next_metadata[0..remaining], &output);
        try std.testing.expectEqual(remaining, accepted.progress.input_read);
        try std.testing.expectEqual(@as(usize, 0), accepted.progress.output_written);
        const captured = capture;
        try std.testing.expectError(error.IntegerOverflow, decoder.step(h.next_metadata[remaining..][0..1], &output));
        try std.testing.expectEqualSlices(u8, &captured, &capture);
        try std.testing.expectEqualSlices(u8, &([_]u8{0xb9} ** 7), &output);
        try h.expectErrorProgress(&decoder, 0, 0);
        const diag = decoder.diagnostics();
        try std.testing.expectEqual(@as(?Counter, maximum), diag.error_input_offset);
        try std.testing.expectEqual(@as(?Counter, 0), diag.error_output_offset);
        try std.testing.expectEqualStrings("IntegerOverflow", diag.last_error_name);
        decoder.reset();
        _ = try decoder.step(&h.first_metadata, &output);
        _ = try decoder.step(&.{0x03}, &output);
        try decoder.finish();
        try std.testing.expectEqual(@as(?Counter, null), decoder.diagnostics().error_input_offset);
    }
}

test "Brotli stream counters owned OOM and budget retain long cumulative diagnostics" {
    inline for (.{ false, true }) |quota| {
        var failing = std.testing.FailingAllocator.init(h.allocator, .{});
        var decoder = br.IncrementalStreamDecoder.initWithOptions(failing.allocator(), .{ .expected_output_len = 257 });
        defer decoder.deinit();
        const wire = try h.goldenAlloc(h.goldens[3]);
        defer h.allocator.free(wire);
        const frames = (@as(Counter, 1) << 32) / 257 + 1;
        try h.closedOwnedPrefix(&decoder, frames, wire, h.goldens[3].payload);
        const before = decoder.snapshot();
        const retained = decoder.workingMemoryBytes();
        try decoder.nextFrame(.{ .expected_output_len = 1024, .max_history_len = 1024, .max_working_memory = if (quota) retained else std.math.maxInt(usize) });
        if (!quota) failing.fail_index = failing.alloc_index;
        var output = [_]u8{0xcf} ** 7;
        try std.testing.expectError(if (quota) error.WorkingMemoryLimitExceeded else error.OutOfMemory, decoder.step(wire, &output));
        try h.expectErrorProgress(&decoder, 1, 0);
        try std.testing.expectEqualSlices(u8, &([_]u8{0xcf} ** 7), &output);
        try std.testing.expectEqual(retained, decoder.workingMemoryBytes());
        const diag = decoder.diagnostics();
        try std.testing.expectEqual(@as(?Counter, before.total_compressed + 1), diag.error_input_offset);
        try std.testing.expectEqual(@as(?Counter, before.total_output), diag.error_output_offset);
        try std.testing.expect(diag.error_output_offset.? > (@as(Counter, 1) << 32));
        decoder.reset();
        try std.testing.expectEqual(@as(Counter, 0), decoder.snapshot().total_output);
        failing.fail_index = std.math.maxInt(usize);
        try decoder.resetWithOptions(.{ .expected_output_len = 257 });
        try h.decodeSplit(&decoder, wire, h.goldens[3].payload);
        try std.testing.expectEqual(@as(Counter, 257), decoder.snapshot().total_output);
    }
}

test "Brotli stream counters owned next frame limits reject before resetting completed stream" {
    var decoder = br.IncrementalStreamDecoder.initWithOptions(h.allocator, .{ .expected_output_len = 257 });
    defer decoder.deinit();
    const wire = try h.goldenAlloc(h.goldens[3]);
    defer h.allocator.free(wire);
    const frames = (@as(Counter, 1) << 32) / 257 + 1;
    try h.closedOwnedPrefix(&decoder, frames, wire, h.goldens[3].payload);
    const before = decoder.snapshot();
    try std.testing.expectError(error.OutputLimitExceeded, decoder.nextFrame(.{ .max_total_output_len = before.total_output - 1 }));
    try std.testing.expectEqualDeep(before, decoder.snapshot());
    try decoder.nextFrame(.{ .expected_output_len = 257, .max_total_output_len = before.total_output + 257 });
    try h.decodeSplit(&decoder, wire, h.goldens[3].payload);
    try std.testing.expectEqual(before.total_output + 257, decoder.snapshot().total_output);
    try std.testing.expectEqual(before.frame_count + 1, decoder.snapshot().frame_count);
}

test "Brotli stream counters encoders reject cumulative output overflow before draining" {
    inline for (.{ br.IncrementalStoredStreamEncoder, br.IncrementalPlannedStreamEncoder, br.IncrementalStaticDictionaryStreamEncoder }) |Encoder| {
        var encoder = Encoder.initWithOptions(h.allocator, .{ .block_len = 16 });
        defer encoder.deinit();
        const wire = try h.encode(&encoder, "Q");
        defer h.allocator.free(wire);
        const maximum: Counter = std.math.maxInt(Counter);
        const frames = maximum / @as(Counter, @intCast(wire.len));
        try h.closedEncoderPrefix(&encoder, frames, wire.len, 1);
        const remaining: usize = @intCast(maximum - encoder.stream_output);
        var next = encoder.options;
        next.stream.metadata = "counter-meta";
        try encoder.nextStream(next);
        var prefix: [32]u8 = undefined;
        const accepted = try encoder.step("", prefix[0..remaining]);
        try std.testing.expectEqual(remaining, accepted.progress.output_written);
        try std.testing.expectEqual(maximum, encoder.snapshot().output_written);
        var output = [_]u8{0xde} ** 3;
        const before = encoder.snapshot();
        try std.testing.expectError(error.IntegerOverflow, encoder.step("", &output));
        try std.testing.expectEqualSlices(u8, &([_]u8{0xde} ** 3), &output);
        try std.testing.expectEqualDeep(before, encoder.snapshot());
    }
}

test "Brotli stream counters planned encoder cumulative input overflow precedes prefix" {
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(h.allocator, .{ .block_len = 16 });
    defer encoder.deinit();
    const payload = h.pattern ** 3;
    const wire = try h.encode(&encoder, payload);
    defer h.allocator.free(wire);
    try std.testing.expect(wire.len < payload.len);
    const maximum: Counter = std.math.maxInt(Counter);
    const frames = maximum / payload.len;
    try h.closedEncoderPrefix(&encoder, frames, wire.len, payload.len);
    const remaining: usize = @intCast(maximum - encoder.stream_input);
    try encoder.nextStream(encoder.options);
    const before = encoder.snapshot();
    var output = [_]u8{0xe7} ** 7;
    try std.testing.expectError(error.IntegerOverflow, encoder.step(payload[0 .. remaining + 1], &output));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqualSlices(u8, &([_]u8{0xe7} ** 7), &output);
    try std.testing.expect(!encoder.prefix_written);
    encoder.reset();
    try std.testing.expectEqual(@as(Counter, 0), encoder.snapshot().input_read);
}

test "Brotli stream counters literal cumulative pledge rejects before stored payload" {
    var decoder = br.IncrementalLiteralStreamDecoder.init();
    const boundary: Counter = @as(Counter, 1) << 32;
    const model = try h.literalStoredPrefix(&decoder, boundary / h.pattern.len);
    decoder.options.expected_output_len = @intCast(model.output_bytes + h.pattern.len - 1);
    const next = try h.nextStoredBlock();
    defer h.allocator.free(next);
    var output = [_]u8{0xf2} ** h.pattern.len;
    try std.testing.expectError(error.SizeMismatch, decoder.step(next, &output));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xf2} ** h.pattern.len), &output);
    try h.expectErrorProgress(&decoder, 3, 0);
    const diagnostic = decoder.diagnostics();
    try std.testing.expectEqual(@as(?Counter, @intCast(model.input_bytes + 3)), diagnostic.error_input_offset);
    try std.testing.expectEqual(@as(?Counter, @intCast(model.output_bytes)), diagnostic.error_output_offset);
    decoder.options.expected_output_len = null;
    decoder.reset();
    const wire = try h.goldenAlloc(h.goldens[1]);
    defer h.allocator.free(wire);
    try h.decodeSplit(&decoder, wire, h.goldens[1].payload);
}

test "Brotli stream counters RLE finite pledge and cap reject before output" {
    const wire = try h.goldenAlloc(h.goldens[3]);
    defer h.allocator.free(wire);
    inline for (.{ false, true }) |cap| {
        var decoder = br.IncrementalRleStreamDecoder.initWithOptions(if (cap)
            .{ .max_output_len = 256 }
        else
            .{ .expected_output_len = 258 });
        var output = [_]u8{0xf7} ** 7;
        try std.testing.expectError(if (cap) error.OutputLimitExceeded else error.SizeMismatch, decoder.step(wire, &output));
        try std.testing.expectEqualSlices(u8, &([_]u8{0xf7} ** 7), &output);
        const diagnostic = decoder.diagnostics();
        try std.testing.expectEqual(@as(Counter, 0), diagnostic.output_written);
        try std.testing.expectEqual(@as(?Counter, 0), diagnostic.error_output_offset);
        try h.expectErrorProgress(&decoder, wire.len, 0);
    }
}

test "Brotli stream counters partial stored output survives the following block cap failure" {
    inline for (.{ false, true }) |owned| {
        var history: [3]u8 = undefined;
        const boundary: Counter = @as(Counter, 1) << 32;
        var decoder = if (owned)
            br.IncrementalStreamDecoder.initWithOptions(h.allocator, .{ .max_output_len = boundary + h.pattern.len, .max_history_len = 3 })
        else
            br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .max_output_len = boundary + h.pattern.len });
        defer if (owned) decoder.deinit();
        const model = if (owned) try h.ownedStoredPrefix(&decoder, boundary / h.pattern.len) else try h.copyStoredPrefix(&decoder, boundary / h.pattern.len);
        const next = try h.nextStoredBlock();
        defer h.allocator.free(next);
        var input: [38]u8 = undefined;
        @memcpy(input[0..next.len], next);
        @memcpy(input[next.len..], next);
        var output = [_]u8{0xfa} ** 19;
        try std.testing.expectError(error.OutputLimitExceeded, decoder.step(&input, &output));
        try std.testing.expectEqualSlices(u8, h.pattern, output[0..h.pattern.len]);
        try std.testing.expectEqualSlices(u8, &.{ 0xfa, 0xfa, 0xfa }, output[h.pattern.len..]);
        try h.expectErrorProgress(&decoder, next.len + 3, h.pattern.len);
        const diagnostic = decoder.diagnostics();
        try std.testing.expectEqual(@as(?Counter, @intCast(model.input_bytes + next.len + 3)), diagnostic.error_input_offset);
        try std.testing.expectEqual(@as(?Counter, @intCast(model.output_bytes + h.pattern.len)), diagnostic.error_output_offset);
    }
}
