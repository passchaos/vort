//! Public raw Deflate and Deflate64 history augmentation contracts.
const std = @import("std");
const h = @import("dictionary_borrows/helpers.zig");

// Nonfinal stored ABC, then a final fixed block with length 3, distance 4.
// zlib 1.2.11 decodes the fixed suffix to ABC with dictionary ABCX and
// rejects the suffix with replacement dictionary X (distance too far back).
const stored = [_]u8{ 0x00, 0x03, 0x00, 0xfc, 0xff, 'A', 'B', 'C' };
const match = [_]u8{ 0x03, 0x62, 0x00 };
const wire = stored ++ match;
const untouched = "\xa5\xa5\xa5\xa5\xa5\xa5";

fn appendWithoutProgress(decoder: anytype, source: []const u8, expected_error: ?anyerror) !void {
    const diagnostics = decoder.diagnostics();
    const position = decoder.blockBoundaryPosition();
    if (expected_error) |err| {
        try std.testing.expectError(err, decoder.appendDictionary(source));
    } else {
        try decoder.appendDictionary(source);
    }
    try std.testing.expectEqualDeep(diagnostics, decoder.diagnostics());
    try std.testing.expectEqual(position, decoder.blockBoundaryPosition());
}

fn storedCheckpoint(decoder: anytype, output: []u8) !void {
    const first = try decoder.stepToBlockBoundary(&wire, output);
    try std.testing.expect(first.block_boundary);
    try std.testing.expectEqual(.need_input, first.status);
    try std.testing.expectEqual(stored.len, first.progress.input_read);
    try std.testing.expectEqual(@as(usize, 3), first.progress.output_written);
    const position: h.deflate.BlockBoundaryPosition = .{
        .compressed_byte_offset = stored.len,
        .compressed_bit_offset = 0,
        .decoded_offset = 3,
    };
    try std.testing.expectEqual(@as(?h.deflate.BlockBoundaryPosition, position), decoder.blockBoundaryPosition());
}

fn preservesDecodedHistory(comptime Decoder: type) !void {
    var history: [Decoder.required_history_len]u8 = @splat(0xa5);
    var decoder = try Decoder.initWithHistory(.{ .expected_output_len = 6, .max_output_len = 6 }, &history);
    var output = untouched.*;
    try storedCheckpoint(&decoder, &output);
    try appendWithoutProgress(&decoder, "X", null);
    try std.testing.expectEqualSlices(u8, "ABC\xa5\xa5\xa5", &output);

    var saved: [4]u8 = undefined;
    const point = try decoder.captureBlockRestart(&saved);
    try std.testing.expectEqualSlices(u8, "ABCX", point.history);
    try h.drain(&decoder, &match, output[3..]);
    try std.testing.expectEqualSlices(u8, "ABCABC", &output);
    try decoder.finish();

    decoder.reset();
    output = untouched.*;
    try storedCheckpoint(&decoder, &output);
    try decoder.seedDictionary("X");
    try std.testing.expectError(error.InvalidMatch, decoder.step(&match, output[3..]));
    try std.testing.expectEqualSlices(u8, "ABC\xa5\xa5\xa5", &output);
}

test "Deflate dictionary append preserves decoded history unlike seedDictionary" {
    inline for (.{ h.Raw, h.Raw64 }) |Decoder| try preservesDecodedHistory(Decoder);
}

fn compactPauses(comptime Decoder: type) !void {
    var history: [Decoder.required_history_len]u8 = @splat(0xa5);
    var decoder = try Decoder.initWithHistory(.{}, &history);
    var output = untouched.*;
    const partial = try decoder.step(&wire, output[0..1]);
    try std.testing.expectEqual(.need_output, partial.status);
    try std.testing.expectEqualStrings("stored_payload", decoder.diagnostics().phase_name);
    try std.testing.expectEqual(@as(usize, 6), partial.progress.input_read);
    try std.testing.expectEqual(@as(usize, 1), partial.progress.output_written);
    try appendWithoutProgress(&decoder, "X", null);
    try std.testing.expectEqualSlices(u8, "A\xa5\xa5\xa5\xa5\xa5", &output);
    // The match sees AXBC, i.e. the injected byte precedes the later stored bytes.
    try h.drain(&decoder, wire[partial.progress.input_read..], output[1..]);
    try std.testing.expectEqualSlices(u8, "ABCAXB", &output);

    decoder.reset();
    output = untouched.*;
    try storedCheckpoint(&decoder, &output);
    try decoder.appendDictionary("X");
    const pending = try decoder.step(&match, &.{});
    try std.testing.expectEqual(.need_output, pending.status);
    try std.testing.expectEqualStrings("match_copy", decoder.diagnostics().phase_name);
    try std.testing.expectEqual(@as(usize, 0), pending.progress.output_written);
    try appendWithoutProgress(&decoder, "Y", null);
    // The already parsed distance-four match now starts at B in ABCXY.
    try h.drain(&decoder, match[pending.progress.input_read..], output[3..]);
    try std.testing.expectEqualSlices(u8, "ABCBCX", &output);

    decoder.reset();
    const fixture = h.fixtures.partial_header;
    var fixed_output: [h.fixtures.partial_header_output.len]u8 = undefined;
    const boundary = try decoder.stepToBlockBoundary(fixture[0..7], &fixed_output);
    try std.testing.expect(boundary.block_boundary);
    const at = decoder.blockBoundaryPosition() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u3, 7), at.compressed_bit_offset);
    try appendWithoutProgress(&decoder, "X", null);
    try h.drain(&decoder, fixture[boundary.progress.input_read..], fixed_output[boundary.progress.output_written..]);
    try std.testing.expectEqualSlices(u8, &h.fixtures.partial_header_output, &fixed_output);
}

test "Deflate dictionary append resumes stored payload pending match and unaligned block states" {
    inline for (.{ h.Raw, h.Raw64 }) |Decoder| try compactPauses(Decoder);
}

fn wrapAndOverlap(comptime Decoder: type) !void {
    const window = Decoder.required_history_len;
    var seed: [window - 2]u8 = undefined;
    h.fill(&seed);
    var history: [window]u8 = @splat(0xa5);
    var decoder = try Decoder.initWithDictionary(.{}, &history, &seed);
    const history_before = history;
    // The five-byte append writes the last two bytes, then the first three.
    // Check rejection for a collision with either piece, including a collision
    // with only the later write, before any physical bytes can be committed.
    for ([_][]const u8{ history[window - 5 ..], history[2..7] }) |overlap| {
        try appendWithoutProgress(&decoder, overlap, error.InvalidBlockPlan);
        try std.testing.expectEqualSlices(u8, &history_before, &history);
    }
    var snapshot: [window]u8 = undefined;
    const before = try decoder.captureBlockRestart(&snapshot);
    try std.testing.expectEqualSlices(u8, &seed, before.history);

    // This source borrows live history but is adjacent to (not in) the writes.
    const injected = seed[3..8].*;
    try appendWithoutProgress(&decoder, history[3..8], null);
    const after = try decoder.captureBlockRestart(&snapshot);
    try std.testing.expectEqual(window, after.history.len);
    try std.testing.expectEqualSlices(u8, seed[3..], after.history[0 .. window - injected.len]);
    try std.testing.expectEqualSlices(u8, &injected, after.history[window - injected.len ..]);

    var expected: [10]u8 = undefined;
    @memcpy(expected[0..5], seed[seed.len - 5 ..]);
    @memcpy(expected[5..], &injected);
    var output: [10]u8 = undefined;
    try h.drain(&decoder, &h.fixtures.tail_match, &output);
    try std.testing.expectEqualSlices(u8, &expected, &output);
}

test "Deflate dictionary append clips wrapped history and refuses only actual write overlap" {
    inline for (.{ h.Raw, h.Raw64 }) |Decoder| try wrapAndOverlap(Decoder);
}

fn replaceFullWindowWithAliasedTail(comptime Decoder: type) !void {
    const window = Decoder.required_history_len;
    var backing: [window + 8]u8 = undefined;
    const history = backing[4..][0..window];
    for ([_][]const u8{ backing[3..][0..window], backing[0 .. window + 6], history }) |source| {
        h.fill(&backing);
        var decoder = try Decoder.initWithDictionary(.{}, history, "old");
        const tail = source[source.len - window ..][0..window].*;
        const left_guard = backing[0..4].*;
        const right_guard = backing[window + 4 ..][0..4].*;
        try appendWithoutProgress(&decoder, source, null);
        try std.testing.expectEqualSlices(u8, &left_guard, backing[0..4]);
        try std.testing.expectEqualSlices(u8, &right_guard, backing[window + 4 ..]);
        var snapshot: [window]u8 = undefined;
        const point = try decoder.captureBlockRestart(&snapshot);
        try std.testing.expectEqualSlices(u8, &tail, point.history);
        var output: [10]u8 = undefined;
        try h.drain(&decoder, &h.fixtures.tail_match, &output);
        try std.testing.expectEqualSlices(u8, tail[window - output.len ..], &output);
    }
}

test "Deflate dictionary append accepts overlapping full-window dictionary tails" {
    inline for (.{ h.Raw, h.Raw64 }) |Decoder| try replaceFullWindowWithAliasedTail(Decoder);
}

fn expectStoppedAppend(decoder: anytype, history: []const u8) !void {
    const before = try std.testing.allocator.dupe(u8, history);
    defer std.testing.allocator.free(before);
    try appendWithoutProgress(decoder, "X", error.InvalidStreamState);
    try std.testing.expectEqualSlices(u8, before, history);
    try appendWithoutProgress(decoder, "", null);
    try std.testing.expectEqualSlices(u8, before, history);
}

fn missingAndTerminalStates(comptime Decoder: type) !void {
    var without_history = Decoder.init();
    try appendWithoutProgress(&without_history, "", null);
    try appendWithoutProgress(&without_history, "X", error.OutputTooSmall);
    try h.drain(&without_history, &h.fixtures.empty_raw, &.{});

    var history: [Decoder.required_history_len]u8 = @splat(0xa5);
    var decoder = try Decoder.initWithHistory(.{}, &history);
    try decoder.appendDictionary("ABC");
    const before = history;
    try appendWithoutProgress(&decoder, history[1..1], null);
    try std.testing.expectEqualSlices(u8, &before, &history);
    var saved: [3]u8 = undefined;
    const point = try decoder.captureBlockRestart(&saved);
    try std.testing.expectEqualSlices(u8, "ABC", point.history);

    try h.drain(&decoder, &h.fixtures.empty_raw, &.{});
    try expectStoppedAppend(&decoder, &history); // Done, before finish.
    try decoder.finish();
    try expectStoppedAppend(&decoder, &history);

    decoder.reset();
    var output = untouched.*;
    try storedCheckpoint(&decoder, &output);
    try std.testing.expectError(error.TruncatedFrame, decoder.finish());
    try expectStoppedAppend(&decoder, &history);

    decoder.reset();
    try storedCheckpoint(&decoder, &output);
    try std.testing.expectError(error.InvalidDeflateBlockType, decoder.step(&.{0x07}, &.{}));
    try expectStoppedAppend(&decoder, &history);
}

test "Deflate dictionary append validates missing history and terminal states but empty is a no-op" {
    inline for (.{ h.Raw, h.Raw64 }) |Decoder| try missingAndTerminalStates(Decoder);
}

test "Deflate dictionary append refuses an active semantic generation without losing progress" {
    const allocator = std.testing.allocator;
    const fixture = try @import("rolling_semantic/fixtures.zig").capacityRegression(allocator);
    defer fixture.deinit(allocator);
    var history: [h.Raw.recommended_history_len]u8 = @splat(0xa5);
    var decoder = try h.Raw.initWithHistory(.{}, &history);
    var workspace: h.Raw.SemanticWorkspace = undefined;
    try decoder.attachSemanticWorkspace(&workspace);
    const body = fixture.encoded[0..fixture.body_len];
    const first = try decoder.step(body, &.{});
    try std.testing.expectEqual(.need_output, first.status);
    try std.testing.expectEqualStrings("fast_dynamic_block", decoder.diagnostics().phase_name);
    try expectStoppedAppend(&decoder, &history);
    const output = try allocator.alloc(u8, fixture.payload.len);
    defer allocator.free(output);
    try h.drain(&decoder, body[first.progress.input_read..], output);
    try std.testing.expectEqualSlices(u8, fixture.payload, output);
    try decoder.finish();
}
