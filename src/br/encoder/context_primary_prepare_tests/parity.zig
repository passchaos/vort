const std = @import("std");
const context = @import("../literal_context_split.zig");
const bit_count = @import("../../../io/bit_count.zig");
const fixtures = @import("fixtures.zig");
const S = @import("support.zig");

fn compare(comptime Codec: type, data: fixtures.Fixture, command_symbols: ?usize, distance_symbols: ?usize, complex_commands: bool) !void {
    var stage: []const u8 = "canonical writer";
    var current_variant: usize = 0;
    errdefer |err| std.debug.print("context primary parity failed input={d} commands={d} expected_command={any} expected_distance={any} complex={any} stage={s} variant={d} error={s}\n", .{ data.input.len, data.commands.len, command_symbols, distance_symbols, complex_commands, stage, current_variant, @errorName(err) });
    const allocator = std.testing.allocator;
    const saved_input = try allocator.dupe(u8, data.input);
    defer allocator.free(saved_input);
    const saved_commands = try allocator.dupe(Codec.Command, data.commands);
    defer allocator.free(saved_commands);
    const base: Codec.Options = .{ .use_recent_distances = true };
    var expected_stats = S.initialStats(Codec.Stats, data.input, data.commands);
    const expected = try Codec.encode(allocator, data.input, data.commands, &expected_stats, base);
    defer allocator.free(expected);

    var reference = Codec.Prepared.init(base, data.commands);
    var ordinary_options = base;
    ordinary_options.prepared_common = &reference;
    var ordinary_stats = S.initialStats(Codec.Stats, data.input, data.commands);
    const ordinary = try Codec.encode(allocator, data.input, data.commands, &ordinary_stats, ordinary_options);
    defer allocator.free(ordinary);
    try std.testing.expectEqualSlices(u8, expected, ordinary);
    try std.testing.expectEqualDeep(expected_stats, ordinary_stats);

    var common = Codec.Prepared.init(base, data.commands);
    S.poison(&common);
    var options = base;
    options.prepared_common = &common;
    var state: Codec.State = .{};
    try std.testing.expect(!common.ready and !state.ready);
    var counted_stats = S.initialStats(Codec.Stats, data.input, data.commands);
    stage = "cold count";
    try Codec.prepare(allocator, data.input, data.commands, &counted_stats, options, &state);
    stage = "cold readiness and common fields";
    try std.testing.expect(common.matches(options, data.commands));
    try std.testing.expect(state.matches(data.input, options));
    try std.testing.expectEqual(expected.len, state.wire_len);
    try std.testing.expectEqual(expected.len, try bit_count.ceilBytes(state.header_bits + state.payload_bits));
    try std.testing.expectEqualDeep(expected_stats, counted_stats);
    try S.sameCommon(&reference, &common, data.commands.len);
    try S.absentCleared(&common);
    std.debug.print("context primary fixture input={d} commands={d} command_alphabet={d} distance_alphabet={d}\n", .{ data.input.len, data.commands.len, common.command_alphabet.len, common.distance_alphabet.len });
    if (command_symbols) |n| try std.testing.expectEqual(n, common.command_alphabet.len);
    if (distance_symbols) |n| try std.testing.expectEqual(n, common.distance_alphabet.len);
    if (complex_commands) try std.testing.expect(common.command_alphabet.len > 4);
    if (data.commands.len > 128) {
        for (common.command_symbols) |symbol| try std.testing.expectEqual(@as(u16, 0xffff), symbol);
    }
    var emitted_stats = counted_stats;
    stage = "cold emission";
    const emitted = try Codec.emit(allocator, data.input, data.commands, &emitted_stats, options, &state);
    defer allocator.free(emitted);
    try std.testing.expectEqualSlices(u8, expected, emitted);
    try std.testing.expectEqualDeep(expected_stats, emitted_stats);
    const decoded = try Codec.decode(allocator, emitted, data.input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, data.input, decoded);

    // The common descriptor is already published. Literal contexts and tree
    // policy may alternate while all command/distance preparation stays fixed.
    for (0..8) |variant| {
        current_variant = variant;
        stage = "warm canonical writer";
        options.literal_context_candidate = if (variant < 4) context.Candidate.suffix(@intCast(variant), @intCast(16 + variant * 12), 0) else null;
        options.use_utf8_text_contexts = variant == 5 or variant == 7;
        options.optimize_literal_tree_wire = variant == 6 or variant == 7;
        options.literal_context_mode = @intCast(variant % 4);
        var plain_options = options;
        plain_options.prepared_common = null;
        plain_options.prepared_literal = null;
        var plain_stats = S.initialStats(Codec.Stats, data.input, data.commands);
        const plain = try Codec.encode(allocator, data.input, data.commands, &plain_stats, plain_options);
        defer allocator.free(plain);
        counted_stats = S.initialStats(Codec.Stats, data.input, data.commands);
        stage = "warm count";
        try Codec.prepare(allocator, data.input, data.commands, &counted_stats, options, &state);
        try std.testing.expect(state.matches(data.input, options));
        try std.testing.expectEqual(plain.len, state.wire_len);
        try std.testing.expectEqualDeep(plain_stats, counted_stats);
        emitted_stats = counted_stats;
        stage = "warm emission";
        const alternate = try Codec.emit(allocator, data.input, data.commands, &emitted_stats, options, &state);
        defer allocator.free(alternate);
        try std.testing.expectEqualSlices(u8, plain, alternate);
        try std.testing.expectEqualDeep(plain_stats, emitted_stats);
        try S.sameCommon(&reference, &common, data.commands.len);
        try S.immutable(saved_input, data.input, saved_commands, data.commands);
    }
}

pub fn check(comptime Codec: type) !void {
    const allocator = std.testing.allocator;
    for (1..6) |len| {
        const data = try fixtures.tiny(allocator, len);
        defer data.deinit(allocator);
        try compare(Codec, data, 1, 1, false);
    }
    for (1..5) |symbols| {
        const commands = try fixtures.ordinary(allocator, symbols, true);
        defer commands.deinit(allocator);
        try compare(Codec, commands, symbols, 1, false);
        const distances = try fixtures.distanceCodes(allocator, symbols);
        defer distances.deinit(allocator);
        try compare(Codec, distances, 1, symbols, false);
    }
    const complex = try fixtures.ordinary(allocator, 16, false);
    defer complex.deinit(allocator);
    try compare(Codec, complex, null, 1, true);
    const distance_complex = try fixtures.distanceCodes(allocator, 8);
    defer distance_complex.deinit(allocator);
    try compare(Codec, distance_complex, 1, 8, false);
    const large = try fixtures.ordinary(allocator, 160, false);
    defer large.deinit(allocator);
    try std.testing.expect(large.commands.len > 128);
    try compare(Codec, large, null, 1, true);
    for ([_]usize{ 32, 160 }) |count| {
        const exact = try fixtures.exact(allocator, count);
        defer exact.deinit(allocator);
        try compare(Codec, exact, null, null, true);
    }
}
