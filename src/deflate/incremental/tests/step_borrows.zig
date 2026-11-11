//! Borrow admission at incremental raw/zlib/gzip step entry points.
const std = @import("std");
const h = @import("step_borrows/helpers.zig");
const dictionaries = @import("step_borrows/dictionaries.zig");
const adjacent = @import("step_borrows/adjacent.zig");

test {
    _ = dictionaries;
    _ = adjacent;
}

fn futureInput(comptime D: type, boundary: bool) !void {
    var history: [32768]u8 = @splat(0x5a);
    var decoder = try h.init(D, &history);
    const wire = h.wrap(D, &h.stored, "abcdef");
    var backing = wire.bytes;
    const before = backing;
    // The first stored payload would replace the second payload before it is
    // read. The boundary API must reject the entire borrow before pausing.
    try h.reject(&decoder, backing[0..wire.len], backing[wire.prefix + 13 ..][0..6], boundary);
    try std.testing.expectEqualSlices(u8, &before, &backing);
    var output: [6]u8 = undefined;
    try h.drain(&decoder, wire.slice(), &output);
    try std.testing.expectEqualSlices(u8, "abcdef", &output);

    decoder.reset();
    // A refusal preserves an already-set pause flag as well as the default.
    decoder.pause_requested = true;
    try h.reject(&decoder, backing[0..wire.len], backing[wire.prefix + 13 ..][0..6], true);
    try std.testing.expect(decoder.pause_requested);
}

fn activeHistoryInput(comptime D: type, boundary: bool) !void {
    var history: [32768]u8 = @splat(0x5a);
    var decoder = try h.init(D, &history);
    const wire = h.wrap(D, &h.stored, "abcdef");
    @memcpy(history[0..wire.len], wire.slice());
    var output: [6]u8 = @splat(0x81);
    try h.reject(&decoder, history[0..wire.len], &output, boundary);
    try h.drain(&decoder, wire.slice(), &output);
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
}

fn activeHistoryOutput(comptime D: type, boundary: bool) !void {
    var history: [32768]u8 = @splat(0x5a);
    var decoder = try h.init(D, &history);
    const wire = h.wrap(D, &h.stored, "abcdef");
    try h.reject(&decoder, wire.slice(), history[0..6], boundary);
    var output: [6]u8 = undefined;
    try h.drain(&decoder, wire.slice(), &output);
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
}

fn decoderStorage(comptime D: type, boundary: bool) !void {
    var history: [32768]u8 = @splat(0x5a);
    var decoder = try h.init(D, &history);
    const wire = h.wrap(D, &h.stored, "abcdef");
    // Stored blocks do not use this table; installing a valid fixture here
    // changes no parser state, while placing input within the decoder object.
    const table_bytes = std.mem.sliceAsBytes(h.raw(&decoder).dynamic_literal_lookup[0..]);
    @memcpy(table_bytes[0..wire.len], wire.slice());
    var output: [6]u8 = @splat(0x81);
    try h.reject(&decoder, table_bytes[0..wire.len], &output, boundary);
    try h.reject(&decoder, wire.slice(), table_bytes[0..6], boundary);
    try h.drain(&decoder, wire.slice(), &output);
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
}

fn pendingToken(comptime D: type, match: bool, boundary: bool) !void {
    var history: [32768]u8 = @splat(0x5a);
    var decoder = try h.init(D, &history);
    const wire = h.wrap(D, &h.fixed, "aaaaaa");
    var prefix: [3]u8 = @splat(0x81);
    const amount: usize = if (match) 3 else 0;
    const accepted = try decoder.step(wire.slice(), prefix[0..amount]);
    try std.testing.expectEqual(.need_output, accepted.status);
    try std.testing.expectEqual(amount, accepted.progress.output_written);
    if (match) {
        try std.testing.expectEqual(.match_copy, h.raw(&decoder).phase);
        try std.testing.expectEqual(@as(usize, 3), h.raw(&decoder).match_remaining);
    } else {
        try std.testing.expectEqual(.symbols, h.raw(&decoder).phase);
        try std.testing.expectEqual(@as(u4, 15), h.raw(&decoder).code_bits);
    }
    var backing: [32]u8 = @splat(0x6a);
    const remaining = wire.slice()[accepted.progress.input_read..];
    @memcpy(backing[0..remaining.len], remaining);
    // Wrappers first drain raw state with empty input. Admission must still
    // protect the complete supplied input before that drain writes output.
    try h.reject(&decoder, backing[0..remaining.len], backing[0 .. 6 - amount], boundary);
    var output: [6]u8 = undefined;
    @memcpy(output[0..amount], prefix[0..amount]);
    try h.drain(&decoder, remaining, output[amount..]);
    try std.testing.expectEqualSlices(u8, "aaaaaa", &output);
}

fn inactiveSecondWindow(comptime D: type) !void {
    var history: [65536]u8 = @splat(0x5a);
    var decoder = try h.init(D, &history);
    const wire = h.wrap(D, &h.fixed, "aaaaaa");
    const input = history[32768..][0..wire.len];
    @memcpy(input, wire.slice());
    const output = history[32864..32865];
    var decoded: [6]u8 = undefined;
    var consumed: usize = 0;
    var written: usize = 0;
    for (0..16) |_| {
        // Reusing this caller output across steps is legal; the active compact
        // history remains the first window and owns every retained byte.
        const result = try decoder.step(input[consumed..], output);
        consumed += result.progress.input_read;
        if (result.progress.output_written != 0) {
            try std.testing.expectEqual(@as(usize, 1), result.progress.output_written);
            decoded[written] = output[0];
            written += 1;
        }
        try std.testing.expectEqualSlices(u8, wire.slice(), input);
        if (result.status == .done) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expectEqual(wire.len, consumed);
    try std.testing.expectEqual(@as(usize, 6), written);
    try std.testing.expectEqualSlices(u8, "aaaaaa", &decoded);
    try std.testing.expectEqual(@as(u64, 0), h.raw(&decoder).semanticBlocksStarted());
}

fn emptyBorrows(comptime D: type) !void {
    var history: [32768]u8 = @splat(0x5a);
    var decoder = try h.init(D, &history);
    const object_bytes = std.mem.asBytes(&decoder);
    const waiting = try decoder.step(history[0..0], object_bytes[0..0]);
    try std.testing.expectEqual(.need_input, waiting.status);
    try std.testing.expectEqual(@as(usize, 0), waiting.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), waiting.progress.output_written);
    const wire = h.wrap(D, &h.stored, "abcdef");
    var backing = wire.bytes;
    // An empty output at a pointer within input carries no mutable bytes.
    const accepted = try decoder.step(backing[0..wire.len], backing[wire.prefix + 13 ..][0..0]);
    try std.testing.expectEqual(.need_output, accepted.status);
    try std.testing.expectEqual(@as(usize, 0), accepted.progress.output_written);
    try std.testing.expect(accepted.progress.input_read != 0);
    try std.testing.expectEqualSlices(u8, wire.slice(), backing[0..wire.len]);
    var output: [6]u8 = undefined;
    try h.drain(&decoder, backing[accepted.progress.input_read..wire.len], &output);
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
}

fn contracts(comptime D: type) !void {
    inline for (.{ false, true }) |boundary| {
        try futureInput(D, boundary);
        try activeHistoryInput(D, boundary);
        try activeHistoryOutput(D, boundary);
        try decoderStorage(D, boundary);
        try pendingToken(D, false, boundary);
        try pendingToken(D, true, boundary);
    }
    try inactiveSecondWindow(D);
    try emptyBorrows(D);
}

test "raw deflate incremental step borrows reject transactionally and retry" {
    try contracts(h.Raw);
}

test "zlib incremental step borrows reject before raw empty-input drain" {
    try contracts(h.Zlib);
}

test "gzip incremental step borrows reject before raw empty-input drain" {
    try contracts(h.Gzip);
}

test "raw deflate incremental step borrows clip an unused output tail at the limit" {
    var history: [32768]u8 = @splat(0x5a);
    var decoder = try h.Raw.initWithHistory(.{ .max_output_len = 3, .stop_at_output_limit = true }, &history);
    var backing: [48]u8 = @splat(0x6a);
    @memcpy(backing[16..32], &h.stored);
    const result = try decoder.step(backing[16..32], backing[0..32]);
    try std.testing.expectEqual(.need_output, result.status);
    try std.testing.expectEqual(@as(usize, 8), result.progress.input_read);
    try std.testing.expectEqual(@as(usize, 3), result.progress.output_written);
    try std.testing.expectEqualSlices(u8, "abc", backing[0..3]);
    try std.testing.expectEqualSlices(u8, &h.stored, backing[16..32]);
    decoder.options.max_output_len = 7;
    var suffix: [3]u8 = undefined;
    try h.drain(&decoder, backing[24..32], &suffix);
    try std.testing.expectEqualSlices(u8, "def", &suffix);
}

test "raw deflate incremental step borrows permit zero limit with aliased unused output" {
    var history: [32768]u8 = @splat(0x5a);
    var decoder = try h.Raw.initWithHistory(.{ .max_output_len = 0, .stop_at_output_limit = true }, &history);
    var backing = h.stored;
    const before = backing;
    const state = try h.allocator.dupe(u8, std.mem.asBytes(&decoder));
    defer h.allocator.free(state);
    const result = try decoder.step(&backing, &backing);
    try std.testing.expectEqual(.need_output, result.status);
    try std.testing.expectEqual(@as(usize, 0), result.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);
    try std.testing.expectEqualSlices(u8, &before, &backing);
    try std.testing.expectEqualSlices(u8, state, std.mem.asBytes(&decoder));
}

fn loweredPendingLimit(comptime match: bool, expected: bool, boundary: bool) !void {
    var history: [32768]u8 = @splat(0x5a);
    var model_history: [32768]u8 = @splat(0x6a);
    var decoder = try h.init(h.Raw, &history);
    const final_stored = [_]u8{ 1, 6, 0, 0xf9, 0xff, 'a', 'b', 'c', 'd', 'e', 'f' };
    const wire: []const u8 = if (match) &h.fixed else &final_stored;
    var prefix: [3]u8 = undefined;
    const accepted = try decoder.step(wire, &prefix);
    try std.testing.expectEqual(.need_output, accepted.status);
    try std.testing.expectEqual(@as(usize, 3), accepted.progress.output_written);
    try std.testing.expectEqual(if (match) .match_copy else .stored_payload, decoder.phase);
    if (expected)
        decoder.options.expected_output_len = 4
    else
        decoder.options.max_output_len = 4;
    var model: h.Raw = undefined;
    try decoder.cloneInto(&model, .{ .history = &model_history });
    const remaining = wire[accepted.progress.input_read..];
    var backing: [16]u8 = @splat(0x81);
    @memcpy(backing[2..][0..remaining.len], remaining);
    // The logical remaining limit is one byte. Without stop_at_output_limit,
    // the already-admitted continuation can still write all three bytes, so
    // output[2] must protect the offered input starting at that address.
    try h.reject(&decoder, backing[2..][0..remaining.len], backing[0..3], boundary);
    var actual_output: [3]u8 = @splat(0x81);
    var model_output: [3]u8 = @splat(0x81);
    // Compare with the independent ordinary call rather than introducing a
    // new rule for the existing mutable options and continuation behavior.
    if (model.step(remaining, &model_output)) |result| {
        const retry = try decoder.step(remaining, &actual_output);
        try std.testing.expectEqualDeep(result, retry);
    } else |err| {
        try std.testing.expectError(err, decoder.step(remaining, &actual_output));
    }
    try std.testing.expectEqualSlices(u8, &model_output, &actual_output);
    try std.testing.expectEqualDeep(model.diagnostics(), decoder.diagnostics());
    try std.testing.expectEqualSlices(u8, &model_history, &history);
}

test "raw deflate incremental step borrows protect pending output after limits are lowered" {
    inline for (.{ false, true }) |match| {
        inline for (.{ false, true }) |expected| {
            inline for (.{ false, true }) |boundary| {
                try loweredPendingLimit(match, expected, boundary);
            }
        }
    }
}

test "incremental step borrows preserve ordinary malformed wrapper partial progress" {
    inline for (.{ h.Zlib, h.Gzip }) |D| {
        var history: [32768]u8 = @splat(0x5a);
        var decoder = try h.init(D, &history);
        const wire = h.wrap(D, &.{7}, "");
        var output: [1]u8 = @splat(0x81);
        try std.testing.expectError(error.InvalidDeflateBlockType, decoder.step(wire.slice()[0 .. wire.prefix + 1], &output));
        try std.testing.expectEqual(wire.prefix + 1, decoder.last_step_progress.input_read);
        try std.testing.expectEqual(@as(usize, 0), decoder.last_step_progress.output_written);
        try std.testing.expectEqualStrings("InvalidDeflateBlockType", decoder.diagnostics().last_error_name);
        try std.testing.expectEqual(@as(u8, 0x81), output[0]);
    }
}
