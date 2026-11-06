const std = @import("std");
const h = @import("helpers.zig");
const wire = @import("wire.zig");
const deflate64 = @import("../../../../deflate64.zig");

fn unchangedHistory(decoder: anytype, before: []const u8, position: usize, length: usize) !void {
    try std.testing.expectEqualSlices(u8, before, decoder.history);
    try std.testing.expectEqual(position, decoder.history_pos);
    try std.testing.expectEqual(length, decoder.history_len);
}

fn rawStored(comptime Decoder: type) !void {
    var decoder = Decoder.init();
    @memset(&decoder.header, 0xa5);
    decoder.total_input = std.math.maxInt(h.Count) - 2;
    const before_header = decoder.header;
    var guard = [_]u8{ 0x81, 0x82 };
    try std.testing.expectError(error.IntegerOverflow, decoder.step(&h.final_stored, &guard));
    try std.testing.expectEqualSlices(u8, &before_header, &decoder.header);
    try std.testing.expectEqual(std.math.maxInt(h.Count) - 2, decoder.total_input);
    try std.testing.expectEqual(@as(usize, 0), decoder.header_received);
    try std.testing.expectEqualSlices(u8, &.{ 0x81, 0x82 }, &guard);
    try std.testing.expectEqual(decoder.total_input, decoder.diagnostics().frame_input_read);

    decoder.reset();
    try h.liftRaw(&decoder, 1);
    // Explicitly synthetic Counter-resource boundary, distinct from the lawful
    // 4 GiB prefix models. The complete next stored token cannot fit.
    decoder.total_output = std.math.maxInt(h.Count) - 1;
    const before_input = decoder.total_input;
    try std.testing.expectError(error.IntegerOverflow, decoder.step(&h.final_stored, &guard));
    try std.testing.expectEqual(before_input + 5, decoder.total_input);
    try std.testing.expectEqual(std.math.maxInt(h.Count) - 1, decoder.total_output);
    try std.testing.expectEqualSlices(u8, &.{ 0x81, 0x82 }, &guard);

    decoder.reset();
    const accepted = try h.step(&decoder, h.final_stored[0..5], &.{});
    try std.testing.expectEqual(@as(usize, 5), accepted.progress.input_read);
    decoder.total_input = std.math.maxInt(h.Count) - 1;
    try std.testing.expectError(error.IntegerOverflow, decoder.step("xx", &guard));
    try std.testing.expectEqual(std.math.maxInt(h.Count) - 1, decoder.total_input);
    try std.testing.expectEqual(@as(h.Count, 0), decoder.total_output);
    try std.testing.expectEqual(@as(usize, 2), decoder.payload_remaining);
    try std.testing.expectEqualSlices(u8, &.{ 0x81, 0x82 }, &guard);
}

fn rawAll(comptime Decoder: type) !void {
    const history = try h.allocator.alloc(u8, Decoder.required_history_len);
    defer h.allocator.free(history);
    @memset(history, 0x5a);
    var decoder = try Decoder.initWithHistory(.{}, history);
    try h.liftRaw(&decoder, 1);
    const retained = try h.allocator.dupe(u8, history);
    defer h.allocator.free(retained);
    const position = decoder.history_pos;
    const length = decoder.history_len;
    var guard = [_]u8{ 0x81, 0x82, 0x83 };
    decoder.total_output = std.math.maxInt(h.Count) - 1;
    const before_input = decoder.total_input;
    try std.testing.expectError(error.IntegerOverflow, decoder.step(&h.final_stored, &guard));
    try std.testing.expectEqual(before_input + 5, decoder.total_input);
    try std.testing.expectEqual(std.math.maxInt(h.Count) - 1, decoder.total_output);
    try std.testing.expectEqualSlices(u8, &.{ 0x81, 0x82, 0x83 }, &guard);
    try unchangedHistory(&decoder, retained, position, length);
    try std.testing.expectEqual(decoder.total_input, decoder.diagnostics().frame_input_read);
    try std.testing.expectEqual(decoder.total_output, decoder.diagnostics().output_written);
    try std.testing.expectEqualStrings("IntegerOverflow", decoder.diagnostics().last_error_name);

    decoder.reset();
    try h.liftRaw(&decoder, 1);
    decoder.total_output = std.math.maxInt(h.Count) - 1;
    const fixed = try wire.fixedMatch();
    defer h.allocator.free(fixed);
    try std.testing.expectError(error.IntegerOverflow, decoder.step(fixed, &guard));
    try std.testing.expectEqual(std.math.maxInt(h.Count) - 1, decoder.total_output);
    try std.testing.expectEqualSlices(u8, &.{ 0x81, 0x82, 0x83 }, &guard);
    try unchangedHistory(&decoder, retained, position, length);

    decoder.reset();
    const lengths = decoder.stored_lengths;
    decoder.total_input = std.math.maxInt(h.Count);
    try std.testing.expectError(error.IntegerOverflow, decoder.step(&h.prefix, &guard));
    try std.testing.expectEqual(std.math.maxInt(h.Count), decoder.total_input);
    try std.testing.expectEqual(@as(h.Count, 0), decoder.total_output);
    try std.testing.expectEqual(@as(u6, 0), decoder.bit_count);
    try std.testing.expectEqualSlices(u8, &lengths, &decoder.stored_lengths);
    try std.testing.expectEqualSlices(u8, &.{ 0x81, 0x82, 0x83 }, &guard);

    decoder.reset();
    try h.liftRaw(&decoder, 1);
    decoder.total_input = std.math.maxInt(h.Count) - 1;
    const sync_phase = decoder.phase;
    const sync_position = decoder.history_pos;
    const sync_length = decoder.history_len;
    try std.testing.expectError(error.IntegerOverflow, decoder.resumeAfterSync(2));
    try std.testing.expectEqual(std.math.maxInt(h.Count) - 1, decoder.total_input);
    try std.testing.expectEqual(@as(h.Count, 1), decoder.total_output);
    try std.testing.expectEqual(sync_phase, decoder.phase);
    try unchangedHistory(&decoder, retained, sync_position, sync_length);
}

fn expectErrorStep(decoder: anytype, before_input: h.Count, before_output: h.Count) !void {
    const progress = decoder.diagnostics().last_step_progress orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(try h.counts.toLocal(decoder.total_input - before_input), progress.input_read);
    try std.testing.expectEqual(try h.counts.toLocal(decoder.total_output - before_output), progress.output_written);
    try std.testing.expectEqual(progress, decoder.snapshot().last_step_progress);
    try std.testing.expectEqual(@as(?h.Count, decoder.total_input), decoder.diagnostics().error_input_offset);
    try std.testing.expectEqual(@as(?h.Count, decoder.total_output), decoder.diagnostics().error_output_offset);
}

fn wrapper(comptime Decoder: type, comptime gzip: bool) !void {
    const history = try h.allocator.alloc(u8, 32 * 1024);
    defer h.allocator.free(history);
    @memset(history, 0x5a);
    var decoder = try Decoder.init(.{}, history);
    @memset(&decoder.header, 0xa5);
    decoder.total_input = std.math.maxInt(h.Count) - 1;
    const header_before = decoder.header;
    const header = if (gzip) &h.gzip_header else &h.zlib_header;
    const before_input = decoder.total_input;
    try std.testing.expectError(error.IntegerOverflow, decoder.step(header, &.{}));
    try std.testing.expectEqual(before_input, decoder.total_input);
    try std.testing.expectEqual(@as(usize, 0), decoder.header_received);
    try std.testing.expectEqualSlices(u8, &header_before, &decoder.header);
    try expectErrorStep(&decoder, before_input, 0);

    decoder.reset();
    try h.liftWrapper(&decoder, gzip, 1);
    var output: [2]u8 = undefined;
    _ = try h.step(&decoder, &h.final_stored, &output);
    try std.testing.expectEqualSlices(u8, "xx", &output);
    @memset(&decoder.footer, 0x6a);
    const footer_before = decoder.footer;
    const footer = h.footer(gzip, 1, "xx");
    // The first footer batch is accepted. The following two-byte batch cannot
    // fit, so it must preserve that exact earlier prefix and error progress.
    decoder.total_input = std.math.maxInt(h.Count) - 2;
    _ = try h.step(&decoder, footer[0..1], &.{});
    const accepted_footer = decoder.footer;
    try std.testing.expectEqual(@as(usize, 1), decoder.footer_received);
    const footer_input = decoder.total_input;
    const footer_output = decoder.total_output;
    try std.testing.expectError(error.IntegerOverflow, decoder.step(footer[1..3], &.{}));
    try std.testing.expectEqual(footer_input, decoder.total_input);
    try std.testing.expectEqual(footer_output, decoder.total_output);
    try std.testing.expectEqual(@as(usize, 1), decoder.footer_received);
    try std.testing.expectEqualSlices(u8, &accepted_footer, &decoder.footer);
    try std.testing.expectEqualSlices(u8, footer_before[1..], decoder.footer[1..]);
    try expectErrorStep(&decoder, footer_input, footer_output);

    decoder.reset();
    try h.liftWrapper(&decoder, gzip, 1);
    const retained = try h.allocator.dupe(u8, history);
    defer h.allocator.free(retained);
    const position = decoder.raw.history_pos;
    const length = decoder.raw.history_len;
    decoder.raw.total_output = std.math.maxInt(h.Count);
    decoder.total_output = std.math.maxInt(h.Count);
    if (gzip) decoder.member_output = std.math.maxInt(h.Count) else decoder.stream_output = std.math.maxInt(h.Count);
    const digest = if (gzip) decoder.crc.digest() else decoder.adler.digest();
    const raw_input = decoder.total_input;
    var guard = [_]u8{ 0x81, 0x82 };
    try std.testing.expectError(error.IntegerOverflow, decoder.step(&h.final_stored, &guard));
    try std.testing.expectEqual(raw_input + 5, decoder.total_input);
    try std.testing.expectEqual(std.math.maxInt(h.Count), decoder.total_output);
    try std.testing.expectEqualSlices(u8, &.{ 0x81, 0x82 }, &guard);
    try unchangedHistory(&decoder.raw, retained, position, length);
    try std.testing.expectEqual(digest, if (gzip) decoder.crc.digest() else decoder.adler.digest());
    try expectErrorStep(&decoder, raw_input, std.math.maxInt(h.Count));
}

fn wrapperPrefix(comptime Decoder: type, comptime gzip: bool) !void {
    const history = try h.allocator.alloc(u8, 32 * 1024);
    defer h.allocator.free(history);
    var decoder = try Decoder.init(.{ .allow_concatenated = true, .allow_trailing_data = true }, history);
    try h.liftWrapper(&decoder, gzip, 1);
    var output: [2]u8 = undefined;
    _ = try h.step(&decoder, &h.final_stored, &output);
    const footer = h.footer(gzip, 1, "xx");
    _ = try h.step(&decoder, &footer, &.{});
    const member_end = decoder.memberEndOffset();
    // Explicit Counter-resource boundary. A complete plausible magic can
    // commit its first byte, then reject the unrepresentable continuation.
    decoder.total_input = std.math.maxInt(h.Count) - 1;
    const before = decoder.total_input;
    const candidate = if (gzip) [_]u8{ 0x1f, 0x8b } else [_]u8{ 0x78, 0x01 };
    try std.testing.expectError(error.IntegerOverflow, decoder.step(&candidate, &.{}));
    try std.testing.expectEqual(std.math.maxInt(h.Count), decoder.total_input);
    try std.testing.expectEqual(member_end, decoder.memberEndOffset());
    try expectErrorStep(&decoder, before, 3);
    const saved = if (gzip) decoder.prefix else decoder.next_member_prefix;
    try std.testing.expectEqual(@as(u2, 1), saved.received);
    try std.testing.expectEqual(candidate[0], saved.bytes[0]);
    try std.testing.expectError(error.IntegerOverflow, decoder.step(candidate[1..], &.{}));
    const unchanged = if (gzip) decoder.prefix else decoder.next_member_prefix;
    try std.testing.expectEqualDeep(saved, unchanged);
    try expectErrorStep(&decoder, std.math.maxInt(h.Count), 3);
    const rejected = try h.step(&decoder, "!", &.{});
    try std.testing.expectEqual(.done, rejected.status);
    try std.testing.expectEqual(@as(usize, 0), rejected.progress.input_read);
    try std.testing.expectEqualSlices(u8, candidate[0..1], decoder.trailingPrefix());
    try std.testing.expectEqual(member_end, decoder.memberEndOffset());
    try decoder.finish();
}

fn explicitLimits(comptime D: type) !void {
    inline for (.{ D.RawDeflateIncrementalStoredDecoder, D.RawDeflateIncrementalFixedLiteralDecoder }) |Decoder| {
        const history = try h.allocator.alloc(u8, 32 * 1024);
        defer h.allocator.free(history);
        var decoder = if (@hasDecl(Decoder, "initWithHistory"))
            try Decoder.initWithHistory(.{}, history)
        else
            Decoder.init();
        try h.liftRaw(&decoder, h.boundary - 1);
        decoder.options.max_output_len = h.boundary;
        var guard = [_]u8{ 0x81, 0x82 };
        try std.testing.expectError(error.OutputLimitExceeded, decoder.step(&h.final_stored, &guard));
        try std.testing.expectEqualSlices(u8, &.{ 0x81, 0x82 }, &guard);
        decoder.reset();
        decoder.options.max_output_len = std.math.maxInt(h.Count);
        try h.liftRaw(&decoder, h.boundary - 1);
        decoder.options.expected_output_len = h.boundary;
        try std.testing.expectError(error.SizeMismatch, decoder.step(&h.final_stored, &guard));
        try std.testing.expectEqualSlices(u8, &.{ 0x81, 0x82 }, &guard);
    }
    const Decoder = D.RawDeflateIncrementalFixedLiteralDecoder;
    const history = try h.allocator.alloc(u8, Decoder.required_history_len);
    defer h.allocator.free(history);
    var decoder = try Decoder.initWithHistory(.{ .stop_at_output_limit = true, .max_output_len = h.boundary }, history);
    try h.liftRaw(&decoder, h.boundary - 1);
    var output = [_]u8{ 0x81, 0x82 };
    const limited = try h.step(&decoder, &h.final_stored, &output);
    try std.testing.expectEqual(.need_output, limited.status);
    try std.testing.expectEqual(@as(usize, 1), limited.progress.output_written);
    try std.testing.expectEqualSlices(u8, &.{ 'x', 0x82 }, &output);
    try std.testing.expectEqual(h.boundary, decoder.total_output);
    // Raise the cap beyond the final byte so stop-at-cap can return done.
    decoder.options.max_output_len += 2;
    const completed = try h.step(&decoder, h.final_stored[limited.progress.input_read..], output[1..]);
    try std.testing.expectEqual(.done, completed.status);
    try std.testing.expectEqualSlices(u8, "xx", &output);
}

fn semanticStatisticsOverflow(comptime Decoder: type) !void {
    const history = try h.allocator.alloc(u8, Decoder.recommended_history_len);
    defer h.allocator.free(history);
    @memset(history, 0x5a);
    const workspace = try h.allocator.create(Decoder.SemanticWorkspace);
    defer h.allocator.destroy(workspace);
    var decoder = try Decoder.initWithHistory(.{}, history);
    try decoder.attachSemanticWorkspace(workspace);
    try h.liftRaw(&decoder, h.boundary - 1);
    const before_history = try h.allocator.dupe(u8, history);
    defer h.allocator.free(before_history);
    const position = decoder.history_pos;
    const length = decoder.history_len;
    const input_before = decoder.total_input;
    const output_before = decoder.total_output;
    const dynamic = try wire.dynamicMatch(false);
    defer h.allocator.free(dynamic);
    const guard = try h.allocator.alloc(u8, wire.dynamic_output_len + 1);
    defer h.allocator.free(guard);
    @memset(guard, 0xa5);
    // Explicit synthetic statistic-resource boundary. Header parsing may
    // complete, but an unrepresentable semantic start must precede bootstrap,
    // generated output, and any history or output-buffer mutation.
    decoder.semantic_blocks_started = std.math.maxInt(h.Count);
    decoder.semantic_blocks_completed = std.math.maxInt(h.Count);
    try std.testing.expectError(error.IntegerOverflow, decoder.step(dynamic, guard));
    try std.testing.expect(decoder.total_input > input_before);
    try std.testing.expect(decoder.total_input - input_before < dynamic.len);
    try std.testing.expectEqual(output_before, decoder.total_output);
    try std.testing.expectEqual(std.math.maxInt(h.Count), decoder.semanticBlocksStarted());
    try std.testing.expectEqual(std.math.maxInt(h.Count), decoder.semanticBlocksCompleted());
    try unchangedHistory(&decoder, before_history[0..decoder.history.len], position, length);
    try std.testing.expectEqualSlices(u8, before_history, history);
    for (guard) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);

    decoder.reset();
    var first_output: [1]u8 = undefined;
    const first = try h.step(&decoder, dynamic, &first_output);
    try std.testing.expectEqual(@as(usize, 1), first.progress.output_written);
    try std.testing.expectEqual(@as(u8, 'x'), first_output[0]);
    try std.testing.expectEqual(@as(h.Count, 1), decoder.semanticBlocksStarted());
    try std.testing.expectEqual(@as(h.Count, 0), decoder.semanticBlocksCompleted());
    try std.testing.expectEqual(.fast_dynamic_block, decoder.phase);
    // Completion overflow is unreachable while started/completed counts retain
    // their normal ordering. Inject this independent resource boundary into a
    // real active generation to test its checked completion transaction.
    decoder.semantic_blocks_completed = std.math.maxInt(h.Count);
    const completion_input = decoder.total_input;
    const completion_output = decoder.total_output;
    const prefix_start = decoder.semantic_prefix_start;
    const prefix_len = decoder.semantic_prefix_len;
    const generated_end = decoder.semantic_generated_end;
    const retained_position = decoder.history_pos;
    const retained_length = decoder.history_len;
    const remaining_output = wire.dynamic_output_len - first.progress.output_written;
    try std.testing.expectError(error.IntegerOverflow, decoder.step(dynamic[first.progress.input_read..], guard));
    try std.testing.expectEqual(@as(usize, remaining_output), try h.counts.toLocal(decoder.total_output - completion_output));
    try std.testing.expectEqual(@as(usize, dynamic.len - first.progress.input_read), try h.counts.toLocal(decoder.total_input - completion_input));
    for (guard[0..remaining_output]) |byte| try std.testing.expectEqual(@as(u8, 'x'), byte);
    for (guard[remaining_output..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectEqual(std.math.maxInt(h.Count), decoder.semanticBlocksCompleted());
    try std.testing.expectEqual(@as(h.Count, 1), decoder.semanticBlocksStarted());
    try std.testing.expectEqual(prefix_start, decoder.semantic_prefix_start);
    try std.testing.expectEqual(prefix_len, decoder.semantic_prefix_len);
    try std.testing.expectEqual(generated_end, decoder.semantic_generated_end);
    try std.testing.expectEqual(retained_position, decoder.history_pos);
    try std.testing.expectEqual(retained_length, decoder.history_len);
    try std.testing.expect(decoder.semantic_end_of_block);
    try std.testing.expectEqual(.fast_dynamic_block, decoder.phase);
    try std.testing.expectEqual(decoder.total_input, decoder.diagnostics().frame_input_read);
    try std.testing.expectEqual(decoder.total_output, decoder.diagnostics().output_written);
    const drained_history = try h.allocator.dupe(u8, history);
    defer h.allocator.free(drained_history);
    const drained_input = decoder.total_input;
    const drained_output = decoder.total_output;
    try std.testing.expectError(error.IntegerOverflow, decoder.step("", &.{}));
    try std.testing.expectEqual(drained_input, decoder.total_input);
    try std.testing.expectEqual(drained_output, decoder.total_output);
    try std.testing.expectEqualSlices(u8, drained_history, history);
    decoder.reset();
    try std.testing.expectEqual(@as(h.Count, 0), decoder.semanticBlocksStarted());
    try std.testing.expectEqual(@as(h.Count, 0), decoder.semanticBlocksCompleted());
}

pub fn contracts(comptime D: type) !void {
    try semanticStatisticsOverflow(D.RawDeflateIncrementalFixedLiteralDecoder);
    try rawStored(D.RawDeflateIncrementalStoredDecoder);
    try rawAll(D.RawDeflateIncrementalFixedLiteralDecoder);
    try rawAll(deflate64.IncrementalDecoder);
    try wrapper(D.ZlibIncrementalDecoder, false);
    try wrapper(D.GzipIncrementalDecoder, true);
    try wrapperPrefix(D.ZlibIncrementalDecoder, false);
    try wrapperPrefix(D.GzipIncrementalDecoder, true);
    try explicitLimits(D);
}
