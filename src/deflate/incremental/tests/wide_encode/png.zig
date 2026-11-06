const std = @import("std");
const h = @import("helpers.zig");
const wire_oracle = @import("png_wire.zig");

fn lift(encoder: anytype, length: h.Count) void {
    encoder.total_input = length;
    encoder.zero_run = length;
    const digest = h.repeatedAdler(0, length);
    encoder.adler = .{ .a = digest & 0xffff, .b = digest >> 16 };
}

fn prove(comptime Encoder: type) !void {
    const zeros: [152]u8 = @splat(0);
    for ([_]usize{ 8, 16, 152 }) |length| {
        var actual = Encoder.init(std.testing.failing_allocator);
        defer actual.deinit();
        var model = Encoder.init(std.testing.failing_allocator);
        defer model.deinit();
        var actual_wire: std.ArrayList(u8) = .empty;
        defer actual_wire.deinit(h.allocator);
        var model_wire: std.ArrayList(u8) = .empty;
        defer model_wire.deinit(h.allocator);
        try h.feed(&actual, zeros[0..length], &actual_wire, 8, 128);
        try h.feed(&model, zeros[0..8], &model_wire, 8, 128);
        lift(&model, length);
        try std.testing.expectEqualDeep(actual.snapshot(), model.snapshot());
        try std.testing.expectEqual(actual.adler.digest(), model.adler.digest());
        try std.testing.expectEqual(actual.bits, model.bits);
        try std.testing.expectEqual(actual.stage, model.stage);
        try h.finish(&actual, &actual_wire, 7);
        try h.finish(&model, &model_wire, 1);
        try std.testing.expectEqualSlices(u8, actual_wire.items, model_wire.items);
        try wire_oracle.zeros(actual_wire.items, length);
    }
}

fn largeRun(comptime D: type, comptime Encoder: type) !void {
    try prove(Encoder);
    const prefix = h.boundary - 8;
    const expected = h.boundary + 16;
    var encoder = Encoder.initExactSize(std.testing.failing_allocator, .{ .max_input_len = expected }, expected);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(h.allocator);
    const first: [8]u8 = @splat(0);
    try h.feed(&encoder, &first, &wire, 8, 128);
    // Whole zero words change no writer bits or parser state. The small
    // proof above checks this model against actual input and actual wire.
    lift(&encoder, prefix);
    const suffix: [24]u8 = @splat(0);
    try h.feed(&encoder, &suffix, &wire, 7, 128);
    try std.testing.expectEqual(expected, encoder.zero_run);
    try std.testing.expectEqual(expected, encoder.snapshot().zero_run);
    try h.finish(&encoder, &wire, 4096);
    try std.testing.expectEqual(expected, encoder.total_input);
    try std.testing.expectEqual(@as(h.Count, wire.items.len), encoder.total_output);
    try std.testing.expectEqual(@as(h.Count, 0), encoder.zero_run);
    try std.testing.expectEqual(@as(h.Count, 0), encoder.closing_run);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
    try wire_oracle.zeros(wire.items, expected);
    // An ordinary small stream also checks the independent token validator
    // against the public decoder's actual output.
    encoder.reset();
    try std.testing.expectEqual(@as(?h.Count, expected), encoder.expected_input_len);
    try std.testing.expectEqual(@as(h.Count, 0), encoder.total_input);
    var small = Encoder.init(std.testing.failing_allocator);
    defer small.deinit();
    wire.clearRetainingCapacity();
    try h.feed(&small, &suffix, &wire, 1, 7);
    try h.finish(&small, &wire, 1);
    var output: [suffix.len]u8 = undefined;
    try std.testing.expectEqual(suffix.len, try D.decodeZlib(wire.items, &output));
    try std.testing.expectEqualSlices(u8, &suffix, &output);
    try wire_oracle.zeros(wire.items, suffix.len);
}

fn overflow(comptime Encoder: type) !void {
    var encoder = Encoder.init(std.testing.failing_allocator);
    defer encoder.deinit();
    var scratch: [256]u8 = @splat(0xa5);
    _ = try h.step(&encoder, "", &scratch);
    encoder.total_input = h.max_count - 1;
    const before = encoder.snapshot();
    const adler = encoder.adler;
    const bits = encoder.bits;
    scratch = @splat(0xa5);
    try std.testing.expectError(error.IntegerOverflow, encoder.step("ab", &scratch));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqualDeep(adler, encoder.adler);
    try std.testing.expectEqual(bits, encoder.bits);
    for (scratch) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);

    encoder.total_input = 0;
    encoder.zero_run = h.max_count - 7;
    const carry: [7]u8 = @splat(0);
    _ = try h.step(&encoder, &carry, &scratch);
    const carried = encoder.snapshot();
    const carried_adler = encoder.adler;
    try std.testing.expectError(error.IntegerOverflow, encoder.step(&.{0}, &scratch));
    try std.testing.expectEqualDeep(carried, encoder.snapshot());
    try std.testing.expectEqualDeep(carried_adler, encoder.adler);
    try std.testing.expectEqual(@as(usize, 7), encoder.carry_len);

    // Complete-word fast path preflights every zero-run extension before
    // writing either direct output or queued reservoir storage.
    encoder.reset();
    _ = try h.step(&encoder, "", &scratch);
    encoder.zero_run = h.max_count - 7;
    const direct_before = encoder.snapshot();
    const direct_adler = encoder.adler;
    const zeros: [16]u8 = @splat(0);
    scratch = @splat(0xa5);
    try std.testing.expectError(error.IntegerOverflow, encoder.step(&zeros, &scratch));
    try std.testing.expectEqualDeep(direct_before, encoder.snapshot());
    try std.testing.expectEqualDeep(direct_adler, encoder.adler);
    for (scratch) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);

    encoder.reset();
    encoder.total_output = h.max_count;
    const output_before = encoder.snapshot();
    try std.testing.expectError(error.IntegerOverflow, encoder.step("", &scratch));
    try std.testing.expectEqualDeep(output_before, encoder.snapshot());
    try std.testing.expectEqual(@as(usize, 0), encoder.pending_len);

    // Apply the common countable-prefix drain rule to a queued header. This
    // synthetic counter seed exceeds the normal pending-reservation invariant
    // but still must publish no uncountable caller bytes.
    encoder.reset();
    _ = try h.step(&encoder, "", &.{});
    try std.testing.expect(encoder.pending_len >= 2);
    const first = encoder.pending[0];
    encoder.total_output = h.max_count - 1;
    scratch = @splat(0xa5);
    const prefix = try h.step(&encoder, "", &scratch);
    try std.testing.expectEqual(h.core.StepResult.Status.need_output, prefix.status);
    try std.testing.expectEqual(@as(usize, 1), prefix.progress.output_written);
    try std.testing.expectEqual(first, scratch[0]);
    for (scratch[1..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    const pending_before = encoder.snapshot();
    const pending_offset = encoder.pending_offset;
    scratch = @splat(0xa5);
    try std.testing.expectError(error.IntegerOverflow, encoder.step("", &scratch));
    try std.testing.expectEqualDeep(pending_before, encoder.snapshot());
    try std.testing.expectEqual(pending_offset, encoder.pending_offset);
    for (scratch) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);

    encoder.reset();
    _ = try h.step(&encoder, "", &scratch);
    encoder.total_output = h.max_count;
    const direct_output_before = encoder.snapshot();
    const direct_output_adler = encoder.adler;
    scratch = @splat(0xa5);
    const literals: [8]u8 = @splat(0xa5);
    try std.testing.expectError(error.IntegerOverflow, encoder.step(&literals, &scratch));
    try std.testing.expectEqualDeep(direct_output_before, encoder.snapshot());
    try std.testing.expectEqualDeep(direct_output_adler, encoder.adler);
    for (scratch) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn directPrefix(comptime Encoder: type) !void {
    const input: [32]u8 = @splat(0xa5);
    var reference = Encoder.init(std.testing.failing_allocator);
    defer reference.deinit();
    var expected_wire: [256]u8 = undefined;
    const expected = try h.step(&reference, &input, &expected_wire);
    try std.testing.expectEqual(input.len, expected.progress.input_read);

    var encoder = Encoder.init(std.testing.failing_allocator);
    defer encoder.deinit();
    var guard: [256]u8 = @splat(0xa5);
    const header = try h.step(&encoder, "", &guard);
    const header_len = header.progress.output_written;
    try std.testing.expectEqualSlices(u8, expected_wire[0..header_len], guard[0..header_len]);
    encoder.total_output = h.max_count - 32;
    guard = @splat(0xa5);
    const prefix = try h.step(&encoder, &input, &guard);
    try std.testing.expectEqual(h.core.StepResult.Status.need_output, prefix.status);
    // Every 0xa5 literal has twelve code bits. With the existing five-bit
    // header carry, thirty-two bytes of count room fit exactly two full words.
    const syntax = @import("../../../../png_ultrafast.zig").incremental_syntax;
    const word_bits = @as(usize, syntax.lengths[0xa5]) * 8;
    const word_bytes = word_bits / 8;
    const encoded_words = 32 / word_bytes;
    try std.testing.expectEqual(encoded_words * word_bytes, prefix.progress.output_written);
    try std.testing.expectEqualSlices(u8, expected_wire[header_len..][0..prefix.progress.output_written], guard[0..prefix.progress.output_written]);
    for (guard[prefix.progress.output_written..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    // A valid implementation may retain one reported, unfinished source word.
    // All accepted bytes must be accounted for by wire or bounded carry.
    try std.testing.expectEqual(encoded_words * 8 + encoder.snapshot().buffered_input, prefix.progress.input_read);
    try std.testing.expect(encoder.snapshot().buffered_input <= 8);
    try std.testing.expectEqual(h.checksum.Adler32.hash(input[0..prefix.progress.input_read]), encoder.adler.digest());
    try std.testing.expectEqual(h.max_count - h.counts.fromLocal(32 - prefix.progress.output_written), encoder.total_output);
    const before = encoder.snapshot();
    const adler = encoder.adler;
    const bits = encoder.bits;
    guard = @splat(0xa5);
    try std.testing.expectError(error.IntegerOverflow, encoder.step(input[prefix.progress.input_read..], &guard));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqualDeep(adler, encoder.adler);
    try std.testing.expectEqual(bits, encoder.bits);
    for (guard) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

pub fn contracts(comptime D: type) !void {
    const Encoder = D.ZlibIncrementalPngUltraFastEncoder;
    try h.commonTypes(Encoder);
    inline for (.{ "zero_run", "closing_run" }) |field|
        try std.testing.expectEqual(h.Count, @FieldType(Encoder, field));
    try std.testing.expectEqual(h.Count, @FieldType(Encoder.Snapshot, "zero_run"));
    inline for (.{ "carry_len", "literal_offset", "literal_end", "suffix_run", "pending_len" }) |field|
        try std.testing.expectEqual(usize, @FieldType(Encoder, field));
    try largeRun(D, Encoder);
    try overflow(Encoder);
    try directPrefix(Encoder);
}
