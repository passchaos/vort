const std = @import("std");
const core = @import("../../../core.zig");
const deflate = @import("../../../deflate.zig");

const Decoder = deflate.RawDeflateIncrementalFixedLiteralDecoder;
const lookup_poison: u16 = 0xffff;
const poisoned_literal_lookup: [1 << 11]u16 = @splat(lookup_poison);
const poisoned_distance_lookup: [1 << 10]u16 = @splat(lookup_poison);

fn poisonCompactLookups(decoder: *Decoder) void {
    decoder.dynamic_literal_lookup = poisoned_literal_lookup;
    decoder.dynamic_distance_lookup = poisoned_distance_lookup;
}

fn expectPoisonedCompactLookups(decoder: *const Decoder) !void {
    try std.testing.expectEqualSlices(u16, &poisoned_literal_lookup, &decoder.dynamic_literal_lookup);
    try std.testing.expectEqualSlices(u16, &poisoned_distance_lookup, &decoder.dynamic_distance_lookup);
}

fn expectSameCompactLookups(expected: *const Decoder, actual: *const Decoder) !void {
    try std.testing.expectEqualSlices(u16, &expected.dynamic_literal_lookup, &actual.dynamic_literal_lookup);
    try std.testing.expectEqualSlices(u16, &expected.dynamic_distance_lookup, &actual.dynamic_distance_lookup);
}

fn expectCounts(decoder: *const Decoder, input_offset: usize, output_offset: usize) !void {
    try std.testing.expectEqual(@as(core.StreamCount, input_offset), decoder.diagnostics().frame_input_read);
    try std.testing.expectEqual(@as(core.StreamCount, output_offset), decoder.diagnostics().output_written);
}

fn drainRaw(
    decoder: *Decoder,
    encoded: []const u8,
    output: []u8,
    input_offset: *usize,
    output_offset: *usize,
    input_chunk_len: usize,
    output_chunk_len: usize,
) !void {
    while (true) {
        const phase = decoder.phase;
        const input_end = input_offset.* + @min(encoded.len - input_offset.*, input_chunk_len);
        const output_end = output_offset.* + @min(output.len - output_offset.*, output_chunk_len);
        const step = try decoder.step(encoded[input_offset.*..input_end], output[output_offset.*..output_end]);
        input_offset.* += step.progress.input_read;
        output_offset.* += step.progress.output_written;
        try expectCounts(decoder, input_offset.*, output_offset.*);
        if (step.status == .done) break;
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0 or phase != decoder.phase);
    }
    try decoder.finish();
    try std.testing.expectEqual(encoded.len, input_offset.*);
    try std.testing.expectEqual(output.len, output_offset.*);
}

fn fillSemanticWindowTestPayload(payload: []u8, seed: u64) void {
    var random = std.Random.DefaultPrng.init(seed);
    for (payload, 0..) |*byte, index| {
        const roll = random.random().int(u8);
        byte.* = if (index >= 32 * 1024 and roll & 3 == 0)
            payload[index - 32 * 1024]
        else
            ' ' + roll % 95;
    }
}

test "raw deflate incremental semantic window drains bounded output and records hits" {
    const allocator = std.testing.allocator;
    const payload = try allocator.alloc(u8, 96 * 1024);
    defer allocator.free(payload);
    fillSemanticWindowTestPayload(payload, 0x51a7_7e57_f00d_cafe);
    const encoded = try deflate.encodeRawDynamicWithOptionsAlloc(
        allocator,
        payload,
        deflate.optionsForLevel(.default),
    );
    defer allocator.free(encoded);

    var history: [deflate.RawDeflateIncrementalFixedLiteralDecoder.recommended_history_len]u8 = undefined;
    var decoder = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(
        .{ .expected_output_len = payload.len },
        &history,
    );
    var semantic_workspace: deflate.RawDeflateIncrementalFixedLiteralDecoder.SemanticWorkspace = undefined;
    try decoder.attachSemanticWorkspace(&semantic_workspace);
    poisonCompactLookups(&decoder);
    const output = try allocator.alloc(u8, payload.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var step_index: usize = 0;
    while (true) {
        const output_end = @min(output.len, output_offset + 4096);
        const step = try decoder.step(
            encoded[input_offset..],
            output[output_offset..output_end],
        );
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
        if (step_index == 0) {
            try std.testing.expectEqual(Decoder.Phase.fast_dynamic_block, decoder.phase);
            try std.testing.expectEqual(@as(usize, 1), decoder.semanticBlocksStarted());
            try expectPoisonedCompactLookups(&decoder);
            try std.testing.expectEqual(
                @as(core.StreamCount, output_offset),
                decoder.diagnostics().output_written,
            );
            try std.testing.expectError(
                error.InvalidStreamState,
                decoder.detachSemanticWorkspace(),
            );
        }
        step_index += 1;
        if (step.status == .done) break;
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0);
    }
    try decoder.finish();
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(payload.len, output_offset);
    try std.testing.expectEqualSlices(u8, payload, output);
    try std.testing.expect(decoder.semanticBlocksStarted() != 0);
    try std.testing.expectEqual(
        decoder.semanticBlocksStarted(),
        decoder.semanticBlocksCompleted(),
    );
    try expectPoisonedCompactLookups(&decoder);
    try decoder.detachSemanticWorkspace();

    var short = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(
        .{ .expected_output_len = payload.len - 1 },
        &history,
    );
    try short.attachSemanticWorkspace(&semantic_workspace);
    try std.testing.expectError(error.SizeMismatch, short.step(encoded, output));
    var capped = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(
        .{
            .max_output_len = payload.len - 1,
            .expected_output_len = payload.len - 1,
        },
        &history,
    );
    try capped.attachSemanticWorkspace(&semantic_workspace);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        capped.step(encoded, output),
    );
    var distance_limited = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(
        .{
            .expected_output_len = payload.len,
            .max_distance = 0,
        },
        &history,
    );
    try distance_limited.attachSemanticWorkspace(&semantic_workspace);
    try std.testing.expectError(
        error.InvalidMatch,
        distance_limited.step(encoded, output),
    );
    try std.testing.expectEqual(
        @as(usize, 0),
        distance_limited.semanticBlocksStarted(),
    );
    const stopped_len = payload.len / 2 + 1;
    var stopped = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(
        .{
            .max_output_len = stopped_len,
            .stop_at_output_limit = true,
        },
        &history,
    );
    try stopped.attachSemanticWorkspace(&semantic_workspace);
    const stopped_step = try stopped.step(encoded, output[0..stopped_len]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, stopped_step.status);
    try std.testing.expectEqual(stopped_len, stopped_step.progress.output_written);
    try std.testing.expectEqual(@as(usize, 0), stopped.semanticBlocksStarted());
    var long = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(
        .{ .expected_output_len = payload.len + 1 },
        &history,
    );
    try long.attachSemanticWorkspace(&semantic_workspace);
    try std.testing.expectError(error.SizeMismatch, long.step(encoded, output));
}

test "raw deflate incremental semantic window falls back on fragmented input" {
    const allocator = std.testing.allocator;
    const payload = try allocator.alloc(u8, 96 * 1024);
    defer allocator.free(payload);
    fillSemanticWindowTestPayload(payload, 0xdec0_de42_1357_2468);
    const encoded = try deflate.encodeRawDynamicWithOptionsAlloc(
        allocator,
        payload,
        deflate.optionsForLevel(.default),
    );
    defer allocator.free(encoded);
    var history: [deflate.RawDeflateIncrementalFixedLiteralDecoder.recommended_history_len]u8 = undefined;
    var decoder = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(
        .{ .expected_output_len = payload.len },
        &history,
    );
    var semantic_workspace: deflate.RawDeflateIncrementalFixedLiteralDecoder.SemanticWorkspace = undefined;
    try decoder.attachSemanticWorkspace(&semantic_workspace);
    poisonCompactLookups(&decoder);
    const output = try allocator.alloc(u8, payload.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var first_step = true;
    while (true) {
        const input_end = @min(
            encoded.len,
            input_offset + @as(usize, if (input_offset == 0) 8 * 1024 else 1),
        );
        const output_end = @min(output.len, output_offset + 3);
        const step = try decoder.step(
            encoded[input_offset..input_end],
            output[output_offset..output_end],
        );
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
        try expectCounts(&decoder, input_offset, output_offset);
        if (first_step) {
            // This input can select the semantic path, but cannot complete its
            // first 32 KiB transaction. Both compact tables must be ready before
            // the next byte-progressive call resumes the unchanged token state.
            try std.testing.expectEqual(Decoder.Phase.symbols, decoder.phase);
            try std.testing.expectEqual(@as(usize, 1), decoder.semanticBlocksStarted());
            try std.testing.expectEqual(@as(usize, 0), output_offset);
            try std.testing.expectEqual(null, std.mem.indexOfScalar(u16, &decoder.dynamic_literal_lookup, lookup_poison));
            try std.testing.expectEqual(null, std.mem.indexOfScalar(u16, &decoder.dynamic_distance_lookup, lookup_poison));
            first_step = false;
        }
        if (step.status == .done) break;
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0);
    }
    try decoder.finish();
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqualSlices(u8, payload, output);
    try std.testing.expect(decoder.semanticBlocksStarted() != 0);
    try std.testing.expectEqual(@as(usize, 0), decoder.semanticBlocksCompleted());

    var scalar_history: [Decoder.required_history_len]u8 = undefined;
    var scalar = try Decoder.initWithHistory(.{ .expected_output_len = payload.len }, &scalar_history);
    const scalar_output = try allocator.alloc(u8, payload.len);
    defer allocator.free(scalar_output);
    var scalar_input_offset: usize = 0;
    var scalar_output_offset: usize = 0;
    try drainRaw(&scalar, encoded, scalar_output, &scalar_input_offset, &scalar_output_offset, encoded.len, scalar_output.len);
    try expectSameCompactLookups(&scalar, &decoder);
    try std.testing.expectEqualSlices(u8, scalar_output, output);
    try std.testing.expectEqual(scalar.diagnostics().frame_input_read, decoder.diagnostics().frame_input_read);
    try std.testing.expectEqual(scalar.diagnostics().output_written, decoder.diagnostics().output_written);
}

test "raw deflate incremental semantic window rebuilds changed alphabets after backpressure and reuse" {
    const allocator = std.testing.allocator;
    const block_len = Decoder.required_history_len;
    const payload = try allocator.alloc(u8, 3 * block_len);
    defer allocator.free(payload);
    var random = std.Random.DefaultPrng.init(0x1a2b_3c4d_5e6f_7081);
    for (payload, 0..) |*byte, index| {
        const roll = random.random().int(u8);
        byte.* = switch (index / block_len) {
            0 => ' ' + roll % 95,
            1 => 128 + roll % 95,
            else => roll % 64,
        };
    }
    const encoded = try deflate.encodeRawDynamicSplitAlloc(
        allocator,
        payload,
        block_len,
        deflate.optionsForLevel(.default),
    );
    defer allocator.free(encoded);
    const output = try allocator.alloc(u8, payload.len);
    defer allocator.free(output);
    var history: [Decoder.recommended_history_len]u8 = undefined;
    var decoder = try Decoder.initWithHistory(.{ .expected_output_len = payload.len }, &history);
    var workspace: Decoder.SemanticWorkspace = undefined;
    try decoder.attachSemanticWorkspace(&workspace);

    // Keep the first block compact so its real alphabet remains in the lookup
    // storage while the next block uses a different semantic alphabet.
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (output_offset < block_len) {
        const input_end = @min(encoded.len, input_offset + 1024);
        const output_end = @min(block_len, output_offset + 4096);
        const step = try decoder.step(encoded[input_offset..input_end], output[output_offset..output_end]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
        try expectCounts(&decoder, input_offset, output_offset);
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0);
    }
    try std.testing.expectEqual(@as(usize, 0), decoder.semanticBlocksStarted());
    const first_literal_lengths = decoder.dynamic_literal_lengths;
    const first_literal_lookup = decoder.dynamic_literal_lookup;
    const first_distance_lookup = decoder.dynamic_distance_lookup;

    // A zero-output call can prepare a semantic window without publishing any
    // bytes. Draining it in small pieces must leave the first block's tables.
    const prepared = try decoder.step(encoded[input_offset..], &.{});
    input_offset += prepared.progress.input_read;
    try std.testing.expectEqual(core.StepResult.Status.need_output, prepared.status);
    try std.testing.expectEqual(@as(usize, 0), prepared.progress.output_written);
    try std.testing.expectEqual(Decoder.Phase.fast_dynamic_block, decoder.phase);
    try std.testing.expectEqual(@as(usize, 1), decoder.semanticBlocksStarted());
    try std.testing.expect(!std.mem.eql(u4, &first_literal_lengths, &decoder.dynamic_literal_lengths));
    try expectCounts(&decoder, input_offset, output_offset);
    while (decoder.phase != .block_header) {
        const phase = decoder.phase;
        const output_end = @min(2 * block_len, output_offset + 257);
        const step = try decoder.step(encoded[input_offset..], output[output_offset..output_end]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
        try expectCounts(&decoder, input_offset, output_offset);
        try std.testing.expectEqualSlices(u16, &first_literal_lookup, &decoder.dynamic_literal_lookup);
        try std.testing.expectEqualSlices(u16, &first_distance_lookup, &decoder.dynamic_distance_lookup);
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0 or phase != decoder.phase);
    }
    try std.testing.expectEqual(2 * block_len, output_offset);
    try std.testing.expectEqual(@as(usize, 1), decoder.semanticBlocksCompleted());

    // The final block has another alphabet. Its header has enough contiguous
    // input to select semantic decoding, but its 32 KiB transaction cannot fit
    // in this fragment. The rollback must rebuild the final block's tables.
    const input_end = @min(encoded.len, input_offset + 8 * 1024);
    const fallback = try decoder.step(encoded[input_offset..input_end], &.{});
    input_offset += fallback.progress.input_read;
    try std.testing.expectEqual(core.StepResult.Status.need_output, fallback.status);
    try std.testing.expect(fallback.progress.input_read != 0);
    try std.testing.expectEqual(@as(usize, 0), fallback.progress.output_written);
    try std.testing.expectEqual(Decoder.Phase.symbols, decoder.phase);
    try std.testing.expectEqual(@as(usize, 2), decoder.semanticBlocksStarted());
    try std.testing.expectEqual(@as(usize, 1), decoder.semanticBlocksCompleted());
    try std.testing.expect(!std.mem.eql(u4, &first_literal_lengths, &decoder.dynamic_literal_lengths));
    try std.testing.expect(!std.mem.eql(u16, &first_literal_lookup, &decoder.dynamic_literal_lookup));
    try expectCounts(&decoder, input_offset, output_offset);

    var scalar_history: [Decoder.required_history_len]u8 = undefined;
    var scalar = try Decoder.initWithHistory(.{ .expected_output_len = payload.len }, &scalar_history);
    const scalar_output = try allocator.alloc(u8, payload.len);
    defer allocator.free(scalar_output);
    const scalar_prefix = try scalar.step(encoded, scalar_output[0 .. 2 * block_len + 1]);
    var scalar_input_offset = scalar_prefix.progress.input_read;
    var scalar_output_offset = scalar_prefix.progress.output_written;
    try std.testing.expectEqual(core.StepResult.Status.need_output, scalar_prefix.status);
    try std.testing.expectEqual(2 * block_len + 1, scalar_output_offset);
    try expectCounts(&scalar, scalar_input_offset, scalar_output_offset);
    try std.testing.expectEqualSlices(u4, &scalar.dynamic_literal_lengths, &decoder.dynamic_literal_lengths);
    try std.testing.expectEqualSlices(u4, &scalar.dynamic_distance_lengths, &decoder.dynamic_distance_lengths);
    try expectSameCompactLookups(&scalar, &decoder);
    try std.testing.expectEqualSlices(u8, scalar_output[0..output_offset], output[0..output_offset]);

    try drainRaw(&decoder, encoded, output, &input_offset, &output_offset, 1, 17);
    try drainRaw(&scalar, encoded, scalar_output, &scalar_input_offset, &scalar_output_offset, encoded.len, 257);
    try std.testing.expectEqualSlices(u8, payload, output);
    try std.testing.expectEqualSlices(u8, scalar_output, output);
    try std.testing.expectEqual(scalar.diagnostics().frame_input_read, decoder.diagnostics().frame_input_read);
    try std.testing.expectEqual(scalar.diagnostics().output_written, decoder.diagnostics().output_written);

    // Reuse preserves the caller workspace and lookup storage. With complete
    // input every block is semantic, so even the previous stream's final-block
    // tables must remain untouched while counters start again from zero.
    const retained_literal_lookup = decoder.dynamic_literal_lookup;
    const retained_distance_lookup = decoder.dynamic_distance_lookup;
    decoder.reset();
    try std.testing.expect(decoder.semantic_decoder == &workspace);
    try std.testing.expectEqual(@as(usize, 0), decoder.semanticBlocksStarted());
    try std.testing.expectEqual(@as(usize, 0), decoder.semanticBlocksCompleted());
    try expectCounts(&decoder, 0, 0);
    input_offset = 0;
    output_offset = 0;
    try drainRaw(&decoder, encoded, output, &input_offset, &output_offset, encoded.len, 257);
    try std.testing.expectEqualSlices(u8, scalar_output, output);
    try std.testing.expectEqual(@as(usize, 3), decoder.semanticBlocksStarted());
    try std.testing.expectEqual(@as(usize, 3), decoder.semanticBlocksCompleted());
    try std.testing.expectEqualSlices(u16, &retained_literal_lookup, &decoder.dynamic_literal_lookup);
    try std.testing.expectEqualSlices(u16, &retained_distance_lookup, &decoder.dynamic_distance_lookup);
    try std.testing.expectEqual(scalar.diagnostics().frame_input_read, decoder.diagnostics().frame_input_read);
    try std.testing.expectEqual(scalar.diagnostics().output_written, decoder.diagnostics().output_written);
}

test "zlib incremental semantic window preserves footer ownership" {
    const allocator = std.testing.allocator;
    const payload = try allocator.alloc(u8, 80 * 1024);
    defer allocator.free(payload);
    fillSemanticWindowTestPayload(payload, 0xa11c_e5e5_1357_2468);
    const encoded = try deflate.encodeZlibBestAlloc(
        allocator,
        payload,
        deflate.optionsForLevel(.default),
    );
    defer allocator.free(encoded);

    var history: [deflate.RawDeflateIncrementalFixedLiteralDecoder.recommended_history_len]u8 = undefined;
    var decoder = try deflate.ZlibIncrementalDecoder.init(
        .{ .expected_output_len = payload.len },
        &history,
    );
    var semantic_workspace: deflate.RawDeflateIncrementalFixedLiteralDecoder.SemanticWorkspace = undefined;
    try decoder.raw.attachSemanticWorkspace(&semantic_workspace);
    const output = try allocator.alloc(u8, payload.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (true) {
        const output_end = @min(output.len, output_offset + 4096);
        const step = try decoder.step(
            encoded[input_offset..],
            output[output_offset..output_end],
        );
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
        if (step.status == .done) break;
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0);
    }
    try decoder.finish();
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(payload.len, output_offset);
    try std.testing.expectEqualSlices(u8, payload, output);
    // The wrapper may force the final token tail through the exact-progress
    // fallback before the Adler footer, but the semantic path must have been
    // selected and the footer must still remain wrapper-owned.
    try std.testing.expect(decoder.raw.semanticBlocksStarted() != 0);
}
