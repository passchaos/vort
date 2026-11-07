const std = @import("std");
const core = @import("../../core.zig");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    try std.testing.expectEqual(.persistent, (Z.NativeIncrementalFrameDecoder.Options{}).dictionary_usage);
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        const frame = try h.frame(Z, format);
        defer a.free(frame);
        for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
            try session(Z, frame, format, policy);
            try completion(Z, frame, format, policy);
        }
    }
    try skippable(Z);
    try dictionaryRecovery(Z);
}

fn dictionaryRecovery(comptime Z: type) !void {
    const dictionary = Z.NativeDictionary.init(42, h.prefix);
    const encoded = try Z.encodeNativeFrameWithDictionaryAlloc(a, h.payload, .{ .selection = .literal_only }, dictionary);
    defer a.free(encoded.frame);
    var state = Z.NativeIncrementalFrameDecoder.initWithPrefix(a, h.prefix);
    defer state.deinit();
    try std.testing.expectError(error.NeedDictionary, state.step(encoded.frame, &.{}));
    const accepted = state.last_step_progress.input_read;
    try std.testing.expectEqual(@as(?u32, dictionary.id), state.requiredDictionaryId());
    try h.active(state.prefixSnapshot(), .frame);
    try std.testing.expectError(error.InvalidStreamState, state.setPrefix("replacement"));
    try state.provideDictionary(dictionary);
    const decoded = try h.wire.drive(a, &state, encoded.frame[accepted..], h.payload.len, 1, 3);
    defer a.free(decoded.output);
    try state.finish();
    try std.testing.expectEqualSlices(u8, h.payload, decoded.output);
    try std.testing.expectEqual(encoded.frame.len, state.snapshot().input_received);
    try h.cleared(state.prefixSnapshot());
}

fn session(comptime Z: type, frame: []const u8, format: Z.FrameFormat, policy: core.CompressedInputPolicy) !void {
    const options: Z.NativeIncrementalFrameDecoder.Options = .{ .format = format, .input_policy = policy };
    var state = Z.NativeIncrementalFrameDecoder.initWithPrefixAndOptions(a, h.prefix, options);
    defer state.deinit();
    try h.pending(state.prefixSnapshot(), 0, false);
    const partial = try state.step(frame[0..1], &.{});
    try std.testing.expectEqual(@as(usize, 1), partial.progress.input_read);
    try h.pending(state.prefixSnapshot(), 0, false);
    try std.testing.expectError(error.InvalidStreamState, state.setPrefix("replacement"));
    state.resetSession();
    try h.pending(state.prefixSnapshot(), 0, false);
    if (format == .standard) {
        try std.testing.expectError(error.InvalidMagic, state.step("junk", &.{}));
        try h.pending(state.prefixSnapshot(), 0, false);
        state.resetSession();
        try h.pending(state.prefixSnapshot(), 0, false);
    }
    const header = try h.wire.header(frame, format == .magicless);
    const started = try state.step(frame[0..header.payload_offset], &.{});
    try std.testing.expectEqual(header.payload_offset, started.progress.input_read);
    try h.active(state.prefixSnapshot(), .frame);
    try std.testing.expectError(error.InvalidStreamState, state.clearDictionary());
    try std.testing.expectError(error.InvalidStreamState, state.resetParameters());
    state.resetSession();
    try h.cleared(state.prefixSnapshot());
    try state.setPrefix(h.prefix);
    try state.resetWithOptions(options);
    try h.cleared(state.prefixSnapshot());
    try state.setPrefix(h.prefix);
    try state.resetParameters();
    try h.cleared(state.prefixSnapshot());
    try state.setPrefix(h.prefix);
    state.resetAll();
    try h.cleared(state.prefixSnapshot());
}

fn completion(comptime Z: type, frame: []const u8, format: Z.FrameFormat, policy: core.CompressedInputPolicy) !void {
    var state = Z.NativeIncrementalFrameDecoder.initWithPrefixAndOptions(a, h.prefix, .{ .format = format, .input_policy = policy });
    defer state.deinit();
    const decoded = try h.wire.drive(a, &state, frame, h.payload.len, 1, 1);
    defer a.free(decoded.output);
    try state.finish();
    try std.testing.expectEqualSlices(u8, h.payload, decoded.output);
    try std.testing.expectEqual(frame.len, decoded.consumed);
    try h.cleared(state.prefixSnapshot());
    try std.testing.expect(state.prefixSnapshot().setter_eligible);
    state.resetSession();
    const twice = try h.joined(frame, frame);
    defer a.free(twice);
    try state.setPrefix(h.prefix);
    try h.missingDriven(h.wire.drive(a, &state, twice, h.payload.len * 2, 1, 7));
    try std.testing.expectEqual(@as(core.StreamCount, 1), state.snapshot().data_frame_count);
    try h.cleared(state.prefixSnapshot());
}

fn skippable(comptime Z: type) !void {
    const skip = try Z.encodeSkippableFrameAlloc(a, 7, "metadata");
    defer a.free(skip);
    const dependent = try h.frame(Z, .standard);
    defer a.free(dependent);
    var state = Z.NativeIncrementalFrameDecoder.initWithPrefix(a, h.prefix);
    defer state.deinit();
    const header = try state.step(skip[0..8], &.{});
    try std.testing.expectEqual(@as(usize, 8), header.progress.input_read);
    try h.active(state.prefixSnapshot(), .skippable);
    _ = try state.step(skip[8..], &.{});
    try h.cleared(state.prefixSnapshot());
    try std.testing.expectEqual(.skippable, state.prefixSnapshot().used_for);
    try state.finish();
    try h.missingDriven(h.wire.drive(a, &state, dependent, h.payload.len, 1, 7));
    try h.cleared(state.prefixSnapshot());
}
