const std = @import("std");
const h = @import("helpers.zig");
const wire = @import("wire.zig");
const deflate64 = @import("../../../../deflate64.zig");

fn init(comptime Decoder: type, history: []u8) !Decoder {
    return if (@hasDecl(Decoder, "initWithHistory"))
        try Decoder.initWithHistory(.{}, history)
    else
        Decoder.init();
}

fn replayPrefix(decoder: anytype, completed: *usize, n: usize) !void {
    while (completed.* < n) : (completed.* += 1) {
        var output: [1]u8 = undefined;
        const result = try h.step(decoder, &h.prefix, &output);
        try std.testing.expectEqual(h.prefix.len, result.progress.input_read);
        try std.testing.expectEqualSlices(u8, "x", &output);
        try std.testing.expect(decoder.atBlockBoundary());
    }
}

fn proveHistoryPrefix(comptime Decoder: type) !void {
    const capacity = if (@hasDecl(Decoder, "required_history_len")) Decoder.required_history_len else 0;
    const actual_history = try h.allocator.alloc(u8, capacity);
    defer h.allocator.free(actual_history);
    const model_history = try h.allocator.alloc(u8, capacity);
    defer h.allocator.free(model_history);
    var actual = try init(Decoder, actual_history);
    var completed: usize = 0;
    for ([_]usize{ 1, 2, 17, capacity + 19 }) |n| {
        try replayPrefix(&actual, &completed, n);
        var model = try init(Decoder, model_history);
        try h.liftRaw(&model, @intCast(n));
        try h.expectSameRaw(&actual, &model);
    }
}

fn storedCrossings(comptime Decoder: type) !void {
    const capacity = if (@hasDecl(Decoder, "required_history_len")) Decoder.required_history_len else 0;
    const history = try h.allocator.alloc(u8, capacity);
    defer h.allocator.free(history);
    for ([_]h.Count{ h.boundary / h.prefix.len, h.boundary - 1 }) |blocks| {
        var decoder = try init(Decoder, history);
        try h.liftRaw(&decoder, blocks);
        decoder.options.expected_output_len = blocks + 2;
        // The default cap must admit the wide pledge on 32-bit targets.
        try std.testing.expectEqual(std.math.maxInt(h.Count), decoder.options.max_output_len);
        try h.drain(&decoder, &h.final_stored, "xx", 1, 1);
        try decoder.finish();
        try std.testing.expectEqual(blocks * 6 + h.final_stored.len, decoder.total_input);
        try std.testing.expectEqual(blocks + 2, decoder.total_output);
        const diagnostic = decoder.diagnostics();
        try std.testing.expectEqual(decoder.total_input, diagnostic.frame_input_read);
        try std.testing.expectEqual(decoder.total_output, diagnostic.output_written);
        try std.testing.expectEqual(@as(?h.Count, blocks + 2), diagnostic.expected_output_len);
        if (@hasDecl(Decoder, "Snapshot")) {
            try std.testing.expectEqual(decoder.total_input, decoder.snapshot().input_read);
            try std.testing.expectEqual(decoder.total_output, decoder.snapshot().output_written);
        }
    }
}

fn compressedCrossing(comptime Decoder: type, suffix: []const u8, expected: []const u8, semantic_workspace: bool) !void {
    const capacity = if (semantic_workspace) Decoder.recommended_history_len else Decoder.required_history_len;
    const history = try h.allocator.alloc(u8, capacity);
    defer h.allocator.free(history);
    var decoder = try Decoder.initWithHistory(.{}, history);
    var workspace: ?*Decoder.SemanticWorkspace = null;
    defer if (workspace) |storage| h.allocator.destroy(storage);
    if (semantic_workspace) {
        workspace = try h.allocator.create(Decoder.SemanticWorkspace);
        try decoder.attachSemanticWorkspace(workspace.?);
    }
    const blocks = h.boundary - 1;
    try h.liftRaw(&decoder, blocks);
    decoder.options.expected_output_len = blocks + expected.len;
    try h.drain(&decoder, suffix, expected, if (semantic_workspace) suffix.len else 1, if (semantic_workspace) expected.len else 3);
    try decoder.finish();
    try std.testing.expectEqual(blocks * 6 + suffix.len, decoder.total_input);
    try std.testing.expectEqual(blocks + expected.len, decoder.total_output);
    if (!semantic_workspace)
        try std.testing.expectEqual(h.counts.ringIndex(decoder.total_output, decoder.history.len), decoder.history_pos);
    // Semantic generations may rebase physical slots. Validate the retained
    // logical suffix through the current ring cursor, including non-'x' bytes.
    try std.testing.expectEqual(decoder.history.len, decoder.history_len);
    for (1..decoder.history.len + 1) |distance| {
        const index = (decoder.history_pos + decoder.history.len - distance) % decoder.history.len;
        const byte: u8 = if (distance <= expected.len) expected[expected.len - distance] else 'x';
        try std.testing.expectEqual(byte, decoder.history[index]);
    }
    if (semantic_workspace) try std.testing.expect(decoder.semanticBlocksStarted() != 0);
    const storage = decoder.history.ptr;
    const attached = decoder.semantic_decoder;
    decoder.reset();
    try std.testing.expectEqual(@as(h.Count, 0), decoder.total_input);
    try std.testing.expectEqual(@as(h.Count, 0), decoder.total_output);
    try std.testing.expectEqual(@as(usize, 0), decoder.history_len);
    try std.testing.expectEqual(storage, decoder.history.ptr);
    try std.testing.expectEqual(attached, decoder.semantic_decoder);
}

fn zeroOutputAndSync(comptime Decoder: type) !void {
    const history = try h.allocator.alloc(u8, Decoder.recommended_history_len);
    defer h.allocator.free(history);
    const workspace = try h.allocator.create(Decoder.SemanticWorkspace);
    defer h.allocator.destroy(workspace);
    var decoder = try Decoder.initWithHistory(.{}, history);
    try decoder.attachSemanticWorkspace(workspace);
    try h.liftRaw(&decoder, h.boundary);
    decoder.options.expected_output_len = h.boundary;
    const empty = try wire.fixedEmpty();
    defer h.allocator.free(empty);
    const result = try h.step(&decoder, empty, &.{});
    try std.testing.expectEqual(.done, result.status);
    try std.testing.expectEqual(empty.len, result.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);
    try decoder.finish();
    const before_input = decoder.total_input;
    const before_output = decoder.total_output;
    const storage = decoder.history.ptr;
    try decoder.resumeAfterSync(5);
    try std.testing.expectEqual(before_input + 5, decoder.total_input);
    try std.testing.expectEqual(before_output, decoder.total_output);
    try std.testing.expectEqual(storage, decoder.history.ptr);
    try std.testing.expectEqual(@as(usize, 0), decoder.history_len);
    try std.testing.expectEqual(@as(usize, 0), decoder.history_pos);
    try std.testing.expectEqual(@as(?*Decoder.SemanticWorkspace, workspace), decoder.semantic_decoder);
    decoder.options.expected_output_len = before_output + 2;
    try h.drain(&decoder, &h.final_stored, "xx", 2, 1);
    try decoder.finish();
    try std.testing.expectEqual(before_input + 5 + h.final_stored.len, decoder.total_input);
    try std.testing.expectEqual(before_output + 2, decoder.total_output);
}

fn dictionaryCrossing(comptime Decoder: type) !void {
    const history = try h.allocator.alloc(u8, Decoder.required_history_len);
    defer h.allocator.free(history);
    var decoder = try Decoder.initWithDictionary(.{}, history, "seed dictionary");
    try h.liftRaw(&decoder, h.boundary - 1);
    decoder.options.expected_output_len = h.boundary + 2;
    const suffix = try wire.fixedMatch();
    defer h.allocator.free(suffix);
    try h.drain(&decoder, suffix, "xxx", 1, 1);
    try decoder.finish();
    try std.testing.expectEqual(h.boundary + 2, decoder.total_output);
}

fn semanticCounterTypes(comptime Decoder: type) !void {
    try std.testing.expectEqual(h.Count, @FieldType(Decoder, "semantic_blocks_started"));
    try std.testing.expectEqual(h.Count, @FieldType(Decoder, "semantic_blocks_completed"));
    try std.testing.expectEqual(h.Count, @typeInfo(@TypeOf(Decoder.semanticBlocksStarted)).@"fn".return_type.?);
    try std.testing.expectEqual(h.Count, @typeInfo(@TypeOf(Decoder.semanticBlocksCompleted)).@"fn".return_type.?);
}

fn semanticRepeatedBlock() ![]u8 {
    const dynamic = try wire.dynamicMatch(false);
    defer h.allocator.free(dynamic);
    const repeated = try std.mem.concat(h.allocator, u8, &.{ dynamic, &.{ 0, 0, 0xff, 0xff } });
    repeated[0] &= ~@as(u8, 1);
    // The independently constructed dynamic EOB ends at bit 3 of its byte.
    // Its five padding zeros now encode a nonfinal stored header plus byte
    // alignment; the four appended bytes are LEN=0, NLEN=~0. Every repeated
    // dynamic + empty stored pair ends at a lawful byte-aligned block boundary.
    return repeated;
}

fn completeSemanticPair(decoder: anytype, repeated: []const u8, output: []u8) !void {
    const result = try h.step(decoder, repeated, output);
    try std.testing.expectEqual(output.len, result.progress.output_written);
    // Semantic delivery ends the step at its compressed block boundary. The
    // following empty stored block needs a real continuation with zero output.
    var read = result.progress.input_read;
    while (read != repeated.len) {
        const continuation = try h.step(decoder, repeated[read..], &.{});
        try std.testing.expectEqual(@as(usize, 0), continuation.progress.output_written);
        try std.testing.expect(continuation.progress.input_read != 0);
        read += continuation.progress.input_read;
    }
    try std.testing.expect(decoder.atBlockBoundary());
    try std.testing.expectEqual(@as(u6, 0), decoder.bit_count);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 'x'), byte);
}

fn replaySemanticBlocks(decoder: anytype, repeated: []const u8, output: []u8, completed: *usize, target: usize) !void {
    while (completed.* < target) : (completed.* += 1) {
        try completeSemanticPair(decoder, repeated, output);
        try std.testing.expectEqual(@as(h.Count, completed.* + 1), decoder.semanticBlocksStarted());
        try std.testing.expectEqual(@as(h.Count, completed.* + 1), decoder.semanticBlocksCompleted());
    }
}

fn applySemanticBlocks(decoder: anytype, blocks: h.Count, repeated_len: usize) void {
    // Seven physically decoded repetitions already fill the history. At this
    // complete block boundary all retained bytes are 'x', the compact cursor
    // is rebased to zero, and generation indices describe the retained window.
    // Further identical pairs change only stream totals and block statistics.
    decoder.total_input = blocks * repeated_len;
    decoder.total_output = blocks * wire.dynamic_output_len;
    decoder.semantic_blocks_started = blocks;
    decoder.semantic_blocks_completed = blocks;
}

fn semanticBlockCrossing(comptime Decoder: type) !void {
    const actual_history = try h.allocator.alloc(u8, Decoder.recommended_history_len);
    defer h.allocator.free(actual_history);
    const model_history = try h.allocator.alloc(u8, Decoder.recommended_history_len);
    defer h.allocator.free(model_history);
    const actual_workspace = try h.allocator.create(Decoder.SemanticWorkspace);
    defer h.allocator.destroy(actual_workspace);
    const model_workspace = try h.allocator.create(Decoder.SemanticWorkspace);
    defer h.allocator.destroy(model_workspace);
    var actual = try Decoder.initWithHistory(.{}, actual_history);
    try actual.attachSemanticWorkspace(actual_workspace);
    const repeated = try semanticRepeatedBlock();
    defer h.allocator.free(repeated);
    const output = try h.allocator.alloc(u8, wire.dynamic_output_len);
    defer h.allocator.free(output);
    var actual_completed: usize = 0;
    for ([_]usize{ 7, 8, 19 }) |blocks| {
        try replaySemanticBlocks(&actual, repeated, output, &actual_completed, blocks);
        var model = try Decoder.initWithHistory(.{}, model_history);
        try model.attachSemanticWorkspace(model_workspace);
        var seed_completed: usize = 0;
        try replaySemanticBlocks(&model, repeated, output, &seed_completed, 7);
        applySemanticBlocks(&model, @intCast(blocks), repeated.len);
        try h.expectSameRaw(&actual, &model);
        try std.testing.expectEqual(actual.semanticBlocksStarted(), model.semanticBlocksStarted());
        try std.testing.expectEqual(actual.semanticBlocksCompleted(), model.semanticBlocksCompleted());
        try std.testing.expectEqual(actual.semantic_prefix_start, model.semantic_prefix_start);
        try std.testing.expectEqual(actual.semantic_prefix_len, model.semantic_prefix_len);
        try std.testing.expectEqual(actual.semantic_generated_end, model.semantic_generated_end);
        try std.testing.expectEqual(actual.semantic_delivered, model.semantic_delivered);
    }
    const blocks = h.boundary - 1;
    applySemanticBlocks(&actual, blocks, repeated.len);
    actual.options.expected_output_len = h.boundary * wire.dynamic_output_len;
    try completeSemanticPair(&actual, repeated, output);
    try std.testing.expectEqual(h.boundary, actual.semanticBlocksStarted());
    try std.testing.expectEqual(h.boundary, actual.semanticBlocksCompleted());
    try std.testing.expectEqual(h.boundary * repeated.len, actual.total_input);
    try std.testing.expectEqual(h.boundary * wire.dynamic_output_len, actual.total_output);
    try std.testing.expect(actual.atBlockBoundary());
    const final = try h.step(&actual, &h.empty_final_stored, &.{});
    try std.testing.expectEqual(.done, final.status);
    try actual.finish();
    try std.testing.expectEqual(h.boundary, actual.semanticBlocksStarted());
    try std.testing.expectEqual(h.boundary, actual.semanticBlocksCompleted());
    actual.reset();
    try std.testing.expectEqual(@as(h.Count, 0), actual.semanticBlocksStarted());
    try std.testing.expectEqual(@as(h.Count, 0), actual.semanticBlocksCompleted());
}

pub fn contracts(comptime D: type) !void {
    try semanticCounterTypes(D.RawDeflateIncrementalFixedLiteralDecoder);
    try semanticCounterTypes(deflate64.IncrementalDecoder);
    try semanticBlockCrossing(D.RawDeflateIncrementalFixedLiteralDecoder);
    inline for (.{ D.RawDeflateIncrementalStoredDecoder, D.RawDeflateIncrementalFixedLiteralDecoder, deflate64.IncrementalDecoder }) |Decoder| {
        try h.localAndWideTypes(Decoder);
        try proveHistoryPrefix(Decoder);
        try storedCrossings(Decoder);
    }
    const fixed = try wire.fixedMatch();
    defer h.allocator.free(fixed);
    try compressedCrossing(D.RawDeflateIncrementalFixedLiteralDecoder, fixed, "xxx", false);
    const dynamic = try wire.dynamicMatch(false);
    defer h.allocator.free(dynamic);
    const output = try h.allocator.alloc(u8, wire.dynamic_output_len);
    defer h.allocator.free(output);
    @memset(output, 'x');
    try compressedCrossing(D.RawDeflateIncrementalFixedLiteralDecoder, dynamic, output, false);
    try compressedCrossing(D.RawDeflateIncrementalFixedLiteralDecoder, dynamic, output, true);
    const continuation = try wire.dynamicThenFixed();
    defer h.allocator.free(continuation);
    const continued_output = try std.mem.concat(h.allocator, u8, &.{ output, "yyyy" });
    defer h.allocator.free(continued_output);
    try compressedCrossing(D.RawDeflateIncrementalFixedLiteralDecoder, continuation, continued_output, false);
    try compressedCrossing(D.RawDeflateIncrementalFixedLiteralDecoder, continuation, continued_output, true);
    const dynamic64 = try wire.dynamicMatch(true);
    defer h.allocator.free(dynamic64);
    try compressedCrossing(deflate64.IncrementalDecoder, dynamic64, output, false);
    const extended = try wire.extended64();
    defer h.allocator.free(extended);
    try compressedCrossing(deflate64.IncrementalDecoder, extended, "x" ** 1030, false);
    try zeroOutputAndSync(D.RawDeflateIncrementalFixedLiteralDecoder);
    try dictionaryCrossing(D.RawDeflateIncrementalFixedLiteralDecoder);
}
