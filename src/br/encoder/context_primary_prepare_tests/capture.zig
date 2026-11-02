const std = @import("std");
const fixtures = @import("fixtures.zig");
const S = @import("support.zig");

fn noPartial(before: anytype, after: anytype) !void {
    try std.testing.expect(!after.ready);
    try std.testing.expectEqual(before.payload_extra_bits, after.payload_extra_bits);
    try std.testing.expectEqualSlices(u32, &before.command_frequencies, &after.command_frequencies);
    try std.testing.expectEqualSlices(u32, &before.distance_frequencies, &after.distance_frequencies);
    try std.testing.expectEqualSlices(u4, &before.command_lengths, &after.command_lengths);
    try std.testing.expectEqualSlices(u4, &before.distance_lengths, &after.distance_lengths);
    try std.testing.expectEqual(before.command_alphabet.len, after.command_alphabet.len);
    try std.testing.expectEqual(before.distance_alphabet.len, after.distance_alphabet.len);
    try std.testing.expectEqualSlices(u16, &before.command_symbols, &after.command_symbols);
    try std.testing.expectEqualSlices(u16, &before.command_encoder.codes, &after.command_encoder.codes);
    try std.testing.expectEqualSlices(u4, &before.command_encoder.bits, &after.command_encoder.bits);
    try std.testing.expectEqualSlices(u16, &before.distance_encoder.codes, &after.distance_encoder.codes);
    try std.testing.expectEqualSlices(u4, &before.distance_encoder.bits, &after.distance_encoder.bits);
    try std.testing.expectEqualDeep(before.key, after.key);
}

pub fn check(comptime Codec: type) !void {
    const allocator = std.testing.allocator;
    const data = try fixtures.ordinary(allocator, 160, false);
    defer data.deinit(allocator);
    const distances = try fixtures.distanceCodes(allocator, 8);
    defer distances.deinit(allocator);
    var options: Codec.Options = .{ .use_recent_distances = true };
    var source = Codec.Prepared.init(options, data.commands);
    options.prepared_common = &source;
    var state: Codec.State = .{};
    var stats = S.initialStats(Codec.Stats, data.input, data.commands);
    try Codec.prepare(allocator, data.input, data.commands, &stats, options, &state);
    try std.testing.expect(source.command_alphabet.len > 4);
    var distance_source = Codec.Prepared.init(options, distances.commands);
    var distance_options = options;
    distance_options.prepared_common = &distance_source;
    var distance_state: Codec.State = .{};
    stats = S.initialStats(Codec.Stats, distances.input, distances.commands);
    try Codec.prepare(allocator, distances.input, distances.commands, &stats, distance_options, &distance_state);
    try std.testing.expect(distance_source.distance_alphabet.len > 4);

    var rebuilt = Codec.Prepared.init(options, data.commands);
    S.poison(&rebuilt);
    try rebuilt.captureCounted(&source.command_frequencies, &source.command_alphabet, &source.command_lengths, &source.distance_frequencies, &source.distance_alphabet, &source.distance_lengths, source.payload_extra_bits, null);
    try S.sameCommon(&source, &rebuilt, data.commands.len);
    try S.absentCleared(&rebuilt);
    for (0..2) |kind| {
        var target = Codec.Prepared.init(options, data.commands);
        S.poison(&target);
        target.payload_extra_bits = 0x1234;
        target.command_alphabet = .{};
        target.distance_alphabet = .{};
        target.command_encoder = .{};
        target.distance_encoder = .{};
        target.ready = true;
        const before = target;
        var command_lengths = source.command_lengths;
        var distance_lengths = distance_source.distance_lengths;
        if (kind == 0) {
            for (source.command_alphabet.symbols[0..source.command_alphabet.len]) |symbol| command_lengths[symbol] = 1;
        } else {
            for (distance_source.distance_alphabet.symbols[0..distance_source.distance_alphabet.len]) |symbol| distance_lengths[symbol] = 1;
        }
        try std.testing.expectError(error.InvalidHuffmanCode, target.captureCounted(&source.command_frequencies, &source.command_alphabet, &command_lengths, &distance_source.distance_frequencies, &distance_source.distance_alphabet, &distance_lengths, 0x8765, null));
        try noPartial(&before, &target);
    }
    // Literal publication is also transactional when bit-count arithmetic
    // fails, even if it replaces a previously valid state.
    var rejected: Codec.State = .{};
    rejected.copyFrom(&state);
    const previous_wire_len = rejected.wire_len;
    try std.testing.expectError(error.IntegerOverflow, rejected.capture(data.input, options, state.normalized_context, state.alphabets[0..state.tree_count], state.lengths[0..state.tree_count], std.math.maxInt(@TypeOf(state.header_bits)), 1));
    try std.testing.expect(!rejected.ready);
    try std.testing.expectEqual(previous_wire_len, rejected.wire_len);
}
