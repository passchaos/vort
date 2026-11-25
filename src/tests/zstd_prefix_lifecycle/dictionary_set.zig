const std = @import("std");
const core = @import("../../core.zig");
const crossing = @import("../zstd_stable_output/fixtures.zig");
const h = @import("helpers.zig");
const a = h.a;
const first_id = 42;
const second_id = 43;

pub fn contracts(comptime Z: type) !void {
    const first_frame = try crossing.crossing(true, false, true, first_id);
    defer a.free(first_frame);
    const first = Z.NativeDictionary.init(first_id, crossing.crossing_dictionary);
    const second = Z.NativeDictionary.init(second_id, h.prefix);
    const encoded = try Z.encodeNativeFrameWithDictionaryAlloc(a, h.payload, .{ .selection = .literal_only, .content_checksum = true }, second);
    defer a.free(encoded.frame);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy|
        try lifecycle(Z, first_frame, first, encoded.frame, second, policy);
    try metadata(Z, first_frame, first);
    try workspaces(Z, first_frame, first, second);
    try stableAlias(Z, first_frame, first);
}

fn lifecycle(
    comptime Z: type,
    first_frame: []const u8,
    first: Z.NativeDictionary,
    second_frame: []const u8,
    second: Z.NativeDictionary,
    policy: core.CompressedInputPolicy,
) !void {
    const first_entries = [_]Z.NativeDictionary{ Z.NativeDictionary.init(1, "unrelated"), first };
    const second_entries = [_]Z.NativeDictionary{second};
    const first_set = Z.NativeDictionarySet.init(&first_entries);
    const second_set = Z.NativeDictionarySet.init(&second_entries);
    const empty = Z.NativeDictionarySet.init(&.{});
    var decoder = Z.NativeIncrementalFrameDecoder.initWithPrefixAndOptions(a, "old once-usage prefix", .{
        .input_policy = policy,
        .stop_after_first_frame = true,
    });
    defer decoder.deinit();
    try decoder.setDictionarySet(first_set);
    try h.cleared(decoder.prefixSnapshot());
    try std.testing.expectEqual(.persistent, decoder.prefixSnapshot().usage);

    const partial = try decoder.step(first_frame[0..1], &.{});
    try std.testing.expectEqual(@as(usize, 1), partial.progress.input_read);
    try rejectSet(&decoder, second_set, error.InvalidStreamState);
    try decodeMember(&decoder, first_frame[1..], crossing.crossing_plain);

    const boundary = decoder.snapshot();
    try std.testing.expectEqual(.done, boundary.phase);
    try decoder.setDictionarySet(second_set);
    try std.testing.expectEqualDeep(boundary, decoder.snapshot());
    try decoder.nextStream();
    try decodeMember(&decoder, second_frame, h.payload);
    const two = decoder.snapshot();
    try std.testing.expectEqual(@as(core.StreamCount, first_frame.len + second_frame.len), two.input_received);
    try std.testing.expectEqual(@as(core.StreamCount, crossing.crossing_plain.len + h.payload.len), two.output_written);
    try std.testing.expectEqual(@as(core.StreamCount, 2), two.data_frame_count);

    // A displaced ID now needs a per-frame override, not a catalog change.
    try decoder.nextStream();
    try std.testing.expectError(error.NeedDictionary, decoder.step(first_frame, &.{}));
    const accepted = decoder.snapshot().last_step_progress.input_read;
    try std.testing.expectEqual((try h.wire.header(first_frame, false)).payload_offset, accepted);
    try std.testing.expectEqual(@as(?u32, first.id), decoder.requiredDictionaryId());
    try rejectSet(&decoder, first_set, error.InvalidStreamState);
    try rejectSet(&decoder, empty, error.InvalidStreamState);
    try decoder.provideDictionary(first);
    try decodeMember(&decoder, first_frame[accepted..], crossing.crossing_plain);
    try decoder.nextStream();
    try decodeMember(&decoder, second_frame, h.payload);

    decoder.resetSession();
    try decodeMember(&decoder, second_frame, h.payload);
    try decoder.setDictionarySet(empty);
    try decoder.nextStream();
    try std.testing.expectError(error.NeedDictionary, decoder.step(second_frame, &.{}));
    try std.testing.expectEqual(@as(?u32, second.id), decoder.requiredDictionaryId());
}

fn metadata(comptime Z: type, frame: []const u8, first: Z.NativeDictionary) !void {
    const bytes = try h.memory.hexAlloc(@embedFile("../../zstd/testdata/libzstd-trained-repeat.dict.hex"));
    defer a.free(bytes);
    const full = (try Z.NativeDictionary.initFromStandardDictionary(bytes)).dictionary;
    var bad_full = full;
    bad_full.id +%= 1;
    var prepared = try Z.PreparedDecodeDictionary.init(full);
    prepared.state.id +%= 1; // Only the prepared snapshot disagrees; serialized metadata still matches.
    const bad_prepared = prepared.handle();
    try std.testing.expect((try bad_prepared.standardView()) != null);

    const entries = [_]Z.NativeDictionary{first};
    var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .stop_after_first_frame = true });
    defer decoder.deinit();
    try decoder.setDictionarySet(Z.NativeDictionarySet.init(&entries));
    try rejectSet(&decoder, Z.NativeDictionarySet.init(&.{ first, Z.NativeDictionary.init(first.id, "duplicate") }), error.DuplicateDictionaryId);
    try rejectSet(&decoder, Z.NativeDictionarySet.init(&.{Z.NativeDictionary.initRawContent("zero ID")}), error.NeedDictionary);
    try rejectSet(&decoder, Z.NativeDictionarySet.init(&.{bad_full}), error.InvalidDictionaryMetadata);
    try rejectSet(&decoder, Z.NativeDictionarySet.init(&.{bad_prepared}), error.InvalidDictionaryMetadata);
    try decodeMember(&decoder, frame, crossing.crossing_plain);
}

fn workspaces(comptime Z: type, frame: []const u8, first: Z.NativeDictionary, larger: Z.NativeDictionary) !void {
    const window = 1024;
    var compressed: [Z.NativeIncrementalFrameDecoder.requiredCompressedBlockWorkspaceLenForWindow(window)]u8 = @splat(0xa5);
    var history: [window + crossing.crossing_dictionary.len]u8 = @splat(0xa5);
    const entries = [_]Z.NativeDictionary{first};
    var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{
        .max_window_size = window,
        .max_working_memory = 0,
        .stop_after_first_frame = true,
    });
    defer decoder.deinit();
    try decoder.bindCompressedBlockWorkspace(&compressed);
    try decoder.bindHistoryWorkspace(&history);
    try decoder.setDictionarySet(Z.NativeDictionarySet.init(&entries));
    try rejectSet(&decoder, Z.NativeDictionarySet.init(&.{ first, larger }), error.OutputTooSmall);
    for ([_][]u8{ &compressed, &history }) |storage| {
        // Short enough to fit the history limit; only the writable overlap is invalid.
        const alias = Z.NativeDictionary.init(first.id, storage[1..2]);
        try rejectSet(&decoder, Z.NativeDictionarySet.init(&.{alias}), error.InvalidBlockPlan);
    }
    try std.testing.expectEqual(compressed.len, decoder.compressedBlockWorkspaceCapacity());
    try std.testing.expectEqual(history.len, decoder.historyWorkspaceCapacity());
    try decodeMember(&decoder, frame, crossing.crossing_plain);
    try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
}

fn stableAlias(comptime Z: type, frame: []const u8, first: Z.NativeDictionary) !void {
    var content: [16]u8 = @splat(0xa5);
    var overlapping = [_]Z.NativeDictionary{Z.NativeDictionary.init(first.id, content[4..8])};
    const candidate = Z.NativeDictionarySet.init(&overlapping);
    const descriptors = std.mem.asBytes(&overlapping)[1..];
    const entries = [_]Z.NativeDictionary{first};
    var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .stop_after_first_frame = true });
    defer decoder.deinit();
    try decoder.setDictionarySet(Z.NativeDictionarySet.init(&entries));
    try decoder.bindStableOutput(descriptors);
    try rejectSet(&decoder, candidate, error.InvalidBlockPlan);
    try std.testing.expectEqual(descriptors.ptr, decoder.stableOutput().ptr);
    try decoder.clearStableOutput();
    try decodeMember(&decoder, frame, crossing.crossing_plain);

    try decoder.setDictionarySet(candidate);
    var disjoint: [16]u8 = @splat(0xa5);
    try decoder.bindStableOutput(&disjoint);
    const before = decoder.snapshot();
    try std.testing.expectError(error.InvalidBlockPlan, decoder.bindStableOutput(descriptors));
    try std.testing.expectEqualDeep(before, decoder.snapshot());
    try std.testing.expectEqual(disjoint[0..].ptr, decoder.stableOutput().ptr);

    // Unlike the descriptor array, an individual dictionary is checked only
    // when its ID is selected. Neither binding order may publish output then.
    try decoder.bindStableOutput(content[6..]);
    try decoder.setDictionarySet(candidate);
    try decoder.nextStream();
    try std.testing.expectError(error.InvalidBlockPlan, decoder.stepStable(frame));
    try std.testing.expectEqual(@as(usize, 0), decoder.stableOutput().len);
    for (content) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn rejectSet(decoder: anytype, dictionary_set: anytype, expected: anyerror) !void {
    const before = decoder.snapshot();
    const prefix = decoder.prefixSnapshot();
    try std.testing.expectError(expected, decoder.setDictionarySet(dictionary_set));
    try std.testing.expectEqualDeep(before, decoder.snapshot());
    try std.testing.expectEqualDeep(prefix, decoder.prefixSnapshot());
}

fn decodeMember(decoder: anytype, frame: []const u8, expected: []const u8) !void {
    const decoded = try h.wire.drive(a, decoder, frame, expected.len, 1, 3);
    defer a.free(decoded.output);
    try std.testing.expectEqual(frame.len, decoded.consumed);
    try std.testing.expectEqualSlices(u8, expected, decoded.output);
    try decoder.finish();
}
