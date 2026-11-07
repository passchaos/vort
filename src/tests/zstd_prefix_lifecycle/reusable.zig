const std = @import("std");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    const frame = try h.frame(Z, .standard);
    defer a.free(frame);
    try decoder(Z, frame);
    try encoder(Z, false);
    try encoder(Z, true);
    try fullDecoder(Z);
}

fn decoder(comptime Z: type, frame: []const u8) !void {
    var decoder_state = Z.NativeFrameDecoder.init(a);
    defer decoder_state.deinit();
    // The caller owns these bytes and may free them after call completion.
    const owned_prefix = try a.dupe(u8, h.prefix);
    var prefix_live = true;
    defer if (prefix_live) a.free(owned_prefix);
    try decoder_state.setDictionary(Z.NativeDictionary.initRawContent("old persistent history"));
    try decoder_state.setPrefix(owned_prefix);
    try h.pending(decoder_state.prefixSnapshot(), 0, false);
    decoder_state.resetSession();
    try h.pending(decoder_state.prefixSnapshot(), 0, false);
    const decoded = try decoder_state.decodeAlloc(frame);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, h.payload, decoded);
    try h.cleared(decoder_state.prefixSnapshot());
    try std.testing.expect(decoder_state.prefixSnapshot().setter_eligible);
    a.free(owned_prefix);
    prefix_live = false;
    decoder_state.resetSession();
    try h.cleared(decoder_state.prefixSnapshot());
    try h.missingAlloc(decoder_state.decodeAlloc(frame));

    try decoder_state.setPrefix(h.prefix);
    const twice = try h.joined(frame, frame);
    defer a.free(twice);
    try std.testing.expectEqualSlices(u8, h.payload ** 2, try decoder_state.decodeScratch(twice));
    try h.cleared(decoder_state.prefixSnapshot());
    const skip = try Z.encodeSkippableFrameAlloc(a, 1, "meta");
    defer a.free(skip);
    const skip_then_frame = try h.joined(skip, frame);
    defer a.free(skip_then_frame);
    try decoder_state.setPrefix(h.prefix);
    try std.testing.expectEqualSlices(u8, h.payload, try decoder_state.decodeScratch(skip_then_frame));
    try h.cleared(decoder_state.prefixSnapshot());
    try decoder_state.setPrefix(h.prefix);
    if (decoder_state.decodeAlloc(&.{})) |empty| {
        a.free(empty);
    } else |err| try std.testing.expect(err == error.TruncatedFrame);
    try h.cleared(decoder_state.prefixSnapshot());
    try decoder_state.setPrefix(h.prefix);
    try std.testing.expectError(error.InvalidMagic, decoder_state.decodeAlloc("junk"));
    try h.cleared(decoder_state.prefixSnapshot());
    try decoder_state.setPrefix(h.prefix);
    try decoder_state.resetParameters();
    try h.cleared(decoder_state.prefixSnapshot());
    try decoder_state.setPrefix(h.prefix);
    decoder_state.resetAll();
    try h.cleared(decoder_state.prefixSnapshot());
    try decoder_state.setDictionary(Z.NativeDictionary.initRawContent(h.prefix));
    try decoder_state.setPrefix(&.{});
    try h.cleared(decoder_state.prefixSnapshot());
    try h.missingAlloc(decoder_state.decodeAlloc(frame));
}

fn encode(comptime level: bool, state: anytype, input: []const u8) ![]u8 {
    if (level) return state.encodeWithOptionsAlloc(input, -3, .{ .content_checksum = true });
    return (try state.encodeWithOptionsAlloc(input, .{ .selection = .literal_only })).frame;
}

fn encoder(comptime Z: type, comptime level: bool) !void {
    const E = if (level) Z.LevelFrameEncoder else Z.NativeFrameEncoder;
    var state = E.init(a);
    defer state.deinit();
    try state.setDictionary(Z.NativeDictionary.init(42, "old persistent history"));
    try state.setPrefix(h.prefix);
    try h.pending(state.prefixSnapshot(), 0, false);
    state.resetSession();
    try h.pending(state.prefixSnapshot(), 0, false);
    const first = try encode(level, &state, h.payload);
    defer a.free(first);
    try h.check(Z, first, h.payload, .{ .dictionary = Z.NativeDictionary.initRawContent(h.prefix) });
    try h.cleared(state.prefixSnapshot());
    const independent = try encode(level, &state, h.payload);
    defer a.free(independent);
    try h.check(Z, independent, h.payload, .{});
    try std.testing.expectEqual(@as(u32, 0), (try h.wire.header(independent, false)).dictionary_id);
    try state.setDictionary(Z.NativeDictionary.init(42, h.prefix));
    const persistent = try encode(level, &state, h.payload);
    defer a.free(persistent);
    try std.testing.expectEqual(@as(u32, 42), (try h.wire.header(persistent, false)).dictionary_id);
    try state.setPrefix(&.{});
    const empty_prefix = try encode(level, &state, "tiny");
    defer a.free(empty_prefix);
    try std.testing.expectEqual(@as(u32, 0), (try h.wire.header(empty_prefix, false)).dictionary_id);
    try state.setPrefix(h.prefix);
    try state.resetParameters();
    try h.cleared(state.prefixSnapshot());
    try state.setPrefix(h.prefix);
    state.resetAll();
    try h.cleared(state.prefixSnapshot());
    try state.clearDictionary();
}

fn fullDecoder(comptime Z: type) !void {
    const bytes = try h.memory.hexAlloc(@embedFile("../../zstd/testdata/libzstd-trained-repeat.dict.hex"));
    defer a.free(bytes);
    const frame = try h.memory.hexAlloc(@embedFile("../../zstd/testdata/libzstd-trained-repeat.frame.hex"));
    defer a.free(frame);
    const dictionary = (try Z.NativeDictionary.initFromStandardDictionary(bytes)).dictionary;
    var prepared = try Z.PreparedDecodeDictionary.init(dictionary);
    const expected = try Z.decodeFrameAllocWithOptions(a, frame, .{ .dictionary = dictionary });
    defer a.free(expected);
    var state = Z.NativeFrameDecoder.init(a);
    defer state.deinit();
    try state.setPrefixWithDictionary(prepared.handle());
    try h.pending(state.prefixSnapshot(), dictionary.id, true);
    try std.testing.expectEqualSlices(u8, expected, try state.decodeScratch(frame));
    try h.cleared(state.prefixSnapshot());
    try std.testing.expectError(error.NeedDictionary, state.decodeAlloc(frame));
}
