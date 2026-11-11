const std = @import("std");
const h = @import("helpers.zig");

fn shortLayouts(comptime Decoder: type, initialize: bool) !void {
    const window = Decoder.required_history_len;
    // Destination begins at 16. Sources lie before it, at the same address,
    // inside it, or immediately after its ten-byte range.
    for ([_]usize{ 11, 16, 21, 26 }) |source_start| {
        var backing: [window + 32]u8 = undefined;
        h.fill(&backing);
        const source = backing[source_start..][0..10];
        const snapshot = source[0..10].*;
        var expected = backing;
        @memcpy(expected[16..26], &snapshot);
        const history = backing[16..][0..window];
        var decoder = if (initialize)
            try Decoder.initWithDictionary(.{}, history, source)
        else seeded: {
            var current = try Decoder.initWithHistory(.{}, history);
            try h.seed(&current, source);
            break :seeded current;
        };
        try std.testing.expectEqualSlices(u8, &expected, &backing);
        try std.testing.expectEqual(@as(usize, 10), decoder.history_len);
        try std.testing.expectEqual(@as(usize, 10), decoder.history_pos);
        var output: [10]u8 = undefined;
        try h.drain(&decoder, &h.fixtures.tail_match, &output);
        try std.testing.expectEqualSlices(u8, &snapshot, &output);
    }
}

fn longLayouts(comptime Decoder: type, initialize: bool) !void {
    const window = Decoder.required_history_len;
    for ([_]usize{ 0, 16, 48 }) |source_start| {
        var backing: [2 * window + 64]u8 = undefined;
        h.fill(&backing);
        const dictionary = backing[source_start..][0 .. window + 16];
        const tail = dictionary[dictionary.len - 10 ..][0..10].*;
        var expected = backing;
        // Build the expected destination from the unchanged original backing,
        // independently of the implementation's overlap-copy direction.
        for (0..window) |index| expected[32 + index] = dictionary[16 + index];
        const history = backing[32..][0..window];
        var decoder = if (initialize)
            try Decoder.initWithDictionary(.{}, history, dictionary)
        else seeded: {
            var current = try Decoder.initWithHistory(.{}, history);
            try h.seed(&current, dictionary);
            break :seeded current;
        };
        try std.testing.expectEqualSlices(u8, &expected, &backing);
        try std.testing.expectEqual(window, decoder.history_len);
        try std.testing.expectEqual(@as(usize, 0), decoder.history_pos);
        var output: [10]u8 = undefined;
        try h.drain(&decoder, &h.fixtures.tail_match, &output);
        try std.testing.expectEqualSlices(u8, &tail, &output);
    }
}

fn emptyAndReceiver(comptime Decoder: type) !void {
    var history: [Decoder.required_history_len]u8 = @splat(0xa5);
    var decoder = try Decoder.initWithDictionary(.{}, &history, history[7..7]);
    try std.testing.expectEqual(@as(usize, 0), decoder.history_len);
    try std.testing.expectEqual(@as(usize, 0), decoder.history_pos);
    const table = std.mem.sliceAsBytes(decoder.dynamic_literal_lookup[0..]);
    @memcpy(table[0..10], h.fixtures.dictionary);
    // These receiver bytes are read completely before the history metadata
    // changes, and seeding does not write this inactive lookup table.
    try h.seed(&decoder, table[0..10]);
    try std.testing.expectEqualSlices(u8, h.fixtures.dictionary, history[0..10]);
    try std.testing.expectEqualSlices(u8, h.fixtures.dictionary, table[0..10]);
    var output: [10]u8 = undefined;
    try h.drain(&decoder, &h.fixtures.tail_match, &output);
    try std.testing.expectEqualSlices(u8, h.fixtures.dictionary, &output);

    decoder.reset();
    decoder.history_len = 7;
    decoder.history_pos = 7;
    const metadata = std.mem.asBytes(&decoder.history_len);
    const metadata_before = metadata[0..@sizeOf(usize)].*;
    // The old metadata bytes themselves are a valid short-lived dictionary:
    // the source is consumed before seedDictionary publishes the new length.
    try h.seed(&decoder, metadata);
    try std.testing.expectEqualSlices(u8, &metadata_before, history[0..metadata_before.len]);
    try std.testing.expectEqual(metadata_before.len, decoder.history_len);
    try std.testing.expectEqual(metadata_before.len, decoder.history_pos);

    const history_before = history;
    try h.seed(&decoder, history[7..7]);
    try std.testing.expectEqualSlices(u8, &history_before, &history);
    try std.testing.expectEqual(@as(usize, 0), decoder.history_len);
    try std.testing.expectEqual(@as(usize, 0), decoder.history_pos);
    try h.drain(&decoder, &h.fixtures.empty_raw, &.{});
    decoder.reset();
    try h.seed(&decoder, "");
    try std.testing.expectError(error.InvalidMatch, decoder.step(&h.fixtures.tail_match, &output));
}

test "dictionary borrows raw and Deflate64 initialization snapshots overlapping sources" {
    inline for (.{ h.Raw, h.Raw64 }) |Decoder| try shortLayouts(Decoder, true);
}

test "dictionary borrows raw and Deflate64 reseeding snapshots overlapping sources" {
    inline for (.{ h.Raw, h.Raw64 }) |Decoder| try shortLayouts(Decoder, false);
}

test "dictionary borrows raw and Deflate64 clip long overlapping dictionaries to each window" {
    inline for (.{ h.Raw, h.Raw64 }) |Decoder| {
        try longLayouts(Decoder, true);
        try longLayouts(Decoder, false);
    }
}

test "dictionary borrows raw and Deflate64 accept consumed receiver bytes and empty dictionaries" {
    inline for (.{ h.Raw, h.Raw64 }) |Decoder| try emptyAndReceiver(Decoder);
}

fn pendingMatch(comptime Decoder: type) !void {
    var history: [Decoder.required_history_len]u8 = @splat(0xa5);
    var decoder = try Decoder.initWithDictionary(.{
        .max_output_len = 10,
        .expected_output_len = 10,
    }, &history, h.fixtures.dictionary);
    const first = try decoder.step(&h.fixtures.tail_match, &.{});
    try std.testing.expectEqual(.need_output, first.status);
    try std.testing.expectEqual(Decoder.Phase.match_copy, decoder.phase);
    try std.testing.expectEqual(@as(usize, 10), decoder.match_distance);
    try std.testing.expectEqual(@as(usize, 10), decoder.match_remaining);
    try std.testing.expectEqual(@as(usize, 0), first.progress.output_written);
    const state_before = try std.testing.allocator.dupe(u8, std.mem.asBytes(&decoder));
    defer std.testing.allocator.free(state_before);
    const history_before = history;
    for ([_][]const u8{ history[5..10], history[7..7] }) |short| {
        try std.testing.expectError(error.InvalidStreamState, decoder.seedDictionary(short));
        try std.testing.expectEqualSlices(u8, state_before, std.mem.asBytes(&decoder));
        try std.testing.expectEqualSlices(u8, &history_before, &history);
    }
    // Enough history may still be replaced while the compact match is pending.
    // An exact overlap remains legal and leaves the buffered token resumable.
    try h.seed(&decoder, history[0..10]);
    var output: [10]u8 = undefined;
    try h.drain(&decoder, h.fixtures.tail_match[first.progress.input_read..], &output);
    try std.testing.expectEqualSlices(u8, h.fixtures.dictionary, &output);
    try decoder.finish();
    // A completed member can be reseeded, including with an empty dictionary.
    try h.seed(&decoder, "");
    try std.testing.expectEqual(@as(usize, 0), decoder.history_len);

    decoder.reset();
    try h.seed(&decoder, h.fixtures.dictionary);
    const second = try decoder.step(&h.fixtures.tail_match, &.{});
    try std.testing.expectEqual(Decoder.Phase.match_copy, decoder.phase);
    // Shift a longer replacement through an overlapping history range. The
    // pending distance-ten match must now observe the replacement's new tail.
    @memcpy(history[5..20], "klmnopqrstuvwxy");
    const replacement = history[5..20].*;
    const total_input = decoder.total_input;
    const total_output = decoder.total_output;
    try h.seed(&decoder, history[5..20]);
    try std.testing.expectEqualSlices(u8, &replacement, history[0..15]);
    try std.testing.expectEqual(@as(usize, 15), decoder.history_len);
    try std.testing.expectEqual(@as(usize, 15), decoder.history_pos);
    try std.testing.expectEqual(total_input, decoder.total_input);
    try std.testing.expectEqual(total_output, decoder.total_output);
    try std.testing.expectEqual(@as(usize, 10), decoder.match_remaining);
    const copied = try decoder.step(h.fixtures.tail_match[second.progress.input_read..], &output);
    try std.testing.expectEqualSlices(u8, replacement[5..15], &output);
    try std.testing.expectEqual(.need_output, copied.status);
    // Public returns normalize an exhausted match to symbols immediately.
    // This natural stopped state can drop history before draining its EOB.
    try std.testing.expectEqual(Decoder.Phase.symbols, decoder.phase);
    try std.testing.expectEqual(@as(usize, 0), decoder.match_remaining);
    try h.seed(&decoder, "");
    try h.drain(&decoder, h.fixtures.tail_match[second.progress.input_read + copied.progress.input_read ..], &.{});
    try decoder.finish();
}

test "dictionary borrows raw and Deflate64 refuse short pending match seeds atomically and resume" {
    inline for (.{ h.Raw, h.Raw64 }) |Decoder| try pendingMatch(Decoder);
}

fn receiverDestination(comptime Decoder: type) !void {
    const window = Decoder.required_history_len;
    const offset = std.mem.alignForward(usize, 32, @alignOf(Decoder));
    const allocator = std.testing.allocator;
    const backing = try allocator.alignedAlloc(u8, .fromByteUnits(@alignOf(Decoder)), window + @sizeOf(Decoder) + offset);
    defer allocator.free(backing);
    @memset(backing, 0xa5);
    const collision: *Decoder = @ptrCast(backing.ptr);
    collision.* = try Decoder.initWithHistory(.{}, backing[0..window]);
    const before = try allocator.dupe(u8, backing);
    defer allocator.free(before);
    try std.testing.expectError(error.InvalidBlockPlan, collision.seedDictionary(h.fixtures.dictionary));
    try std.testing.expectEqualSlices(u8, before, backing);

    // The unused portion of a history slice may contain the receiver. Only
    // the ten bytes actually written by this seed must be independent.
    const inactive: *Decoder = @ptrCast(@alignCast(backing[offset..].ptr));
    inactive.* = try Decoder.initWithHistory(.{}, backing[0..window]);
    try h.seed(inactive, h.fixtures.dictionary);
    try std.testing.expectEqualSlices(u8, h.fixtures.dictionary, backing[0..10]);
    try std.testing.expectEqual(@as(usize, 10), inactive.history_len);
    try std.testing.expectEqual(@as(usize, 10), inactive.history_pos);
}

test "dictionary borrows raw and Deflate64 validate the actual receiver destination prefix" {
    inline for (.{ h.Raw, h.Raw64 }) |Decoder| try receiverDestination(Decoder);
}

test "dictionary borrows active semantic generations reject reseeding without changing state" {
    const allocator = std.testing.allocator;
    const fixtures = @import("../rolling_semantic/fixtures.zig");
    const fixture = try fixtures.capacityRegression(allocator);
    defer fixture.deinit(allocator);
    var history: [h.Raw.recommended_history_len]u8 = @splat(0xa5);
    var decoder = try h.Raw.initWithHistory(.{}, &history);
    var workspace: h.Raw.SemanticWorkspace = undefined;
    @memset(std.mem.asBytes(&workspace), 0x6a);
    try decoder.attachSemanticWorkspace(&workspace);
    const wire = fixture.encoded[0..fixture.body_len];
    const first = try decoder.step(wire, &.{});
    try std.testing.expectEqual(.need_output, first.status);
    try std.testing.expectEqual(h.Raw.Phase.fast_dynamic_block, decoder.phase);
    const state_before = try allocator.dupe(u8, std.mem.asBytes(&decoder));
    defer allocator.free(state_before);
    const history_before = history;
    const workspace_before = try allocator.dupe(u8, std.mem.asBytes(&workspace));
    defer allocator.free(workspace_before);
    for ([_][]const u8{ h.fixtures.dictionary, "", history[5..15], std.mem.asBytes(&workspace)[0..10] }) |source| {
        try std.testing.expectError(error.InvalidStreamState, decoder.seedDictionary(source));
        try std.testing.expectEqualSlices(u8, state_before, std.mem.asBytes(&decoder));
        try std.testing.expectEqualSlices(u8, &history_before, &history);
        try std.testing.expectEqualSlices(u8, workspace_before, std.mem.asBytes(&workspace));
    }
    const output = try allocator.alloc(u8, fixture.payload.len);
    defer allocator.free(output);
    try h.drain(&decoder, wire[first.progress.input_read..], output);
    try std.testing.expectEqualSlices(u8, fixture.payload, output);
    try decoder.finish();
}
