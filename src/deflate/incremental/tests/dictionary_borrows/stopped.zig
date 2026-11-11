//! Positive reseeding controls for compact parser and optional-storage pauses.
const std = @import("std");
const h = @import("helpers.zig");

fn seedPaused(decoder: anytype) !void {
    const before = decoder.*;
    try h.seed(decoder, h.fixtures.dictionary);
    try std.testing.expectEqual(before.phase, decoder.phase);
    try std.testing.expectEqual(before.bit_buffer, decoder.bit_buffer);
    try std.testing.expectEqual(before.bit_count, decoder.bit_count);
    try std.testing.expectEqual(before.code, decoder.code);
    try std.testing.expectEqual(before.code_bits, decoder.code_bits);
    try std.testing.expectEqual(before.final_block, decoder.final_block);
    try std.testing.expectEqual(before.stored_length_received, decoder.stored_length_received);
    try std.testing.expectEqual(before.stored_remaining, decoder.stored_remaining);
    try std.testing.expectEqual(before.match_remaining, decoder.match_remaining);
    try std.testing.expectEqual(before.total_input, decoder.total_input);
    try std.testing.expectEqual(before.total_output, decoder.total_output);
    try std.testing.expectEqual(@as(usize, 10), decoder.history_len);
    try std.testing.expectEqual(@as(usize, 10), decoder.history_pos);
    try std.testing.expectEqualSlices(u8, h.fixtures.dictionary, decoder.history[0..10]);
}

fn compactPauses(comptime Decoder: type) !void {
    var history: [Decoder.required_history_len]u8 = @splat(0xa5);
    var decoder = try Decoder.initWithHistory(.{ .expected_output_len = 6 }, &history);
    var fixed_output: [6]u8 = undefined;
    const header = try decoder.step(h.fixtures.partial_header[0..7], &fixed_output);
    try std.testing.expectEqual(.need_input, header.status);
    try std.testing.expectEqual(@as(usize, 5), header.progress.output_written);
    try std.testing.expectEqual(Decoder.Phase.block_header, decoder.phase);
    try std.testing.expectEqual(@as(u6, 1), decoder.bit_count);
    try seedPaused(&decoder);
    try h.drain(&decoder, h.fixtures.partial_header[header.progress.input_read..], fixed_output[5..]);
    try std.testing.expectEqualSlices(u8, &h.fixtures.partial_header_output, &fixed_output);

    decoder = try Decoder.initWithHistory(.{ .expected_output_len = 3 }, &history);
    var stored_output: [3]u8 = undefined;
    const lengths = try decoder.step(h.fixtures.stored[0..2], &stored_output);
    try std.testing.expectEqual(.need_input, lengths.status);
    try std.testing.expectEqual(Decoder.Phase.stored_lengths, decoder.phase);
    try std.testing.expectEqual(@as(usize, 1), decoder.stored_length_received);
    try seedPaused(&decoder);
    try h.drain(&decoder, h.fixtures.stored[lengths.progress.input_read..], &stored_output);
    try std.testing.expectEqualSlices(u8, "abc", &stored_output);

    decoder.reset();
    const payload = try decoder.step(&h.fixtures.stored, stored_output[0..1]);
    try std.testing.expectEqual(.need_output, payload.status);
    try std.testing.expectEqual(Decoder.Phase.stored_payload, decoder.phase);
    try std.testing.expectEqual(@as(usize, 2), decoder.stored_remaining);
    try seedPaused(&decoder);
    try h.drain(&decoder, h.fixtures.stored[payload.progress.input_read..], stored_output[1..]);
    try std.testing.expectEqualSlices(u8, "abc", &stored_output);

    decoder = try Decoder.initWithHistory(.{ .expected_output_len = 1 }, &history);
    const symbol = try decoder.step(&h.fixtures.literal, &.{});
    try std.testing.expectEqual(.need_output, symbol.status);
    try std.testing.expectEqual(Decoder.Phase.symbols, decoder.phase);
    try seedPaused(&decoder);
    var literal_output: [1]u8 = undefined;
    try h.drain(&decoder, h.fixtures.literal[symbol.progress.input_read..], &literal_output);
    try std.testing.expectEqualSlices(u8, "A", &literal_output);
}

test "dictionary borrows raw and Deflate64 preserve partial headers stored payloads and pending symbols" {
    inline for (.{ h.Raw, h.Raw64 }) |Decoder| try compactPauses(Decoder);
}

fn optionalSource(comptime Decoder: type, in_workspace: bool) !void {
    var history: [65536]u8 = @splat(0xa5);
    var workspace: h.Raw.SemanticWorkspace = undefined;
    const workspace_bytes = std.mem.asBytes(&workspace);
    // These poison bytes are not initialized semantic table state. Seeding
    // only borrows its source, and the tiny fixed stream keeps it inactive.
    @memset(workspace_bytes, 0x6a);
    const source = if (in_workspace) workspace_bytes[13..23] else history[32773..32783];
    @memcpy(source, h.fixtures.dictionary);
    const workspace_before = try std.testing.allocator.dupe(u8, workspace_bytes);
    defer std.testing.allocator.free(workspace_before);
    const second_window_before = history[32768..65536].*;
    var decoder = if (Decoder == h.Raw)
        try Decoder.initWithHistory(.{}, &history)
    else
        try Decoder.init(.{}, &history);
    if (Decoder == h.Auto) {
        const frame = h.fixtures.frame(h.fixtures.dictionary, &h.fixtures.tail_match, h.fixtures.dictionary);
        try h.request(&decoder, frame.slice());
    }
    // Auto's raw child exists only after detection; acquire its pointer then.
    const active_raw = if (Decoder == h.Raw) &decoder else &h.zlib(&decoder).raw;
    try active_raw.attachSemanticWorkspace(&workspace);
    var output: [10]u8 = undefined;
    if (Decoder == h.Raw) {
        try h.seed(&decoder, source);
        try h.drain(&decoder, &h.fixtures.tail_match, &output);
    } else {
        const frame = h.fixtures.frame(h.fixtures.dictionary, &h.fixtures.tail_match, h.fixtures.dictionary);
        if (Decoder == h.Zlib) try h.request(&decoder, frame.slice());
        try decoder.provideDictionary(source);
        try h.drain(&decoder, frame.slice()[6..], &output);
    }
    try std.testing.expectEqualSlices(u8, h.fixtures.dictionary, &output);
    try std.testing.expectEqualSlices(u8, workspace_before, workspace_bytes);
    try std.testing.expectEqualSlices(u8, &second_window_before, history[32768..65536]);
    try std.testing.expect(active_raw.semantic_decoder == &workspace);
    try std.testing.expectEqual(@as(u64, 0), active_raw.semanticBlocksStarted());
}

test "dictionary borrows inactive attached workspaces and second history windows remain valid sources" {
    inline for (.{ h.Raw, h.Zlib, h.Auto }) |Decoder| {
        try optionalSource(Decoder, false);
        try optionalSource(Decoder, true);
    }
}
