const std = @import("std");
const common = @import("../prepared_command_distance.zig");

pub fn initialStats(comptime Stats: type, input: []const u8, commands: anytype) Stats {
    var stats: Stats = .{ .input_bytes = input.len, .command_count = commands.len };
    for (commands) |item| {
        stats.literal_bytes += item.insert_len;
        stats.matched_bytes += item.outputLen();
    }
    stats.token_count = stats.literal_bytes + commands.len;
    return stats;
}

pub fn poison(prepared: anytype) void {
    @memset(&prepared.command_frequencies, 0xa5a5_a5a5);
    @memset(&prepared.distance_frequencies, 0x5a5a_5a5a);
    @memset(&prepared.command_lengths, 15);
    @memset(&prepared.distance_lengths, 15);
    @memset(&prepared.command_symbols, 0xffff);
}

pub fn sameCommon(expected: anytype, actual: anytype, commands: usize) !void {
    try std.testing.expect(expected.ready and actual.ready);
    try std.testing.expectEqual(expected.payload_extra_bits, actual.payload_extra_bits);
    try std.testing.expectEqualSlices(u32, &expected.command_frequencies, &actual.command_frequencies);
    try std.testing.expectEqualSlices(u32, &expected.distance_frequencies, &actual.distance_frequencies);
    try std.testing.expectEqualSlices(u4, &expected.command_lengths, &actual.command_lengths);
    try std.testing.expectEqualSlices(u4, &expected.distance_lengths, &actual.distance_lengths);
    try std.testing.expectEqualSlices(u16, expected.command_alphabet.symbols[0..expected.command_alphabet.len], actual.command_alphabet.symbols[0..actual.command_alphabet.len]);
    try std.testing.expectEqualSlices(u16, expected.distance_alphabet.symbols[0..expected.distance_alphabet.len], actual.distance_alphabet.symbols[0..actual.distance_alphabet.len]);
    for (expected.command_alphabet.symbols[0..expected.command_alphabet.len]) |symbol| {
        try std.testing.expectEqual(expected.command_encoder.codes[symbol], actual.command_encoder.codes[symbol]);
        try std.testing.expectEqual(expected.command_encoder.bits[symbol], actual.command_encoder.bits[symbol]);
    }
    for (expected.distance_alphabet.symbols[0..expected.distance_alphabet.len]) |symbol| {
        try std.testing.expectEqual(expected.distance_encoder.codes[symbol], actual.distance_encoder.codes[symbol]);
        try std.testing.expectEqual(expected.distance_encoder.bits[symbol], actual.distance_encoder.bits[symbol]);
    }
    if (commands <= common.symbol_capacity)
        try std.testing.expectEqualSlices(u16, expected.command_symbols[0..commands], actual.command_symbols[0..commands]);
}

pub fn absentCleared(prepared: anytype) !void {
    var active_commands: [common.command_capacity]bool = @splat(false);
    var active_distances: [common.distance_capacity]bool = @splat(false);
    for (prepared.command_alphabet.symbols[0..prepared.command_alphabet.len]) |symbol| active_commands[symbol] = true;
    for (prepared.distance_alphabet.symbols[0..prepared.distance_alphabet.len]) |symbol| active_distances[symbol] = true;
    for (active_commands, prepared.command_frequencies) |active, value| {
        if (!active) try std.testing.expectEqual(@as(u32, 0), value);
    }
    for (active_distances, prepared.distance_frequencies) |active, value| {
        if (!active) try std.testing.expectEqual(@as(u32, 0), value);
    }
}

pub fn immutable(before_input: []const u8, input: []const u8, before_commands: anytype, commands: anytype) !void {
    try std.testing.expectEqualSlices(u8, before_input, input);
    try std.testing.expectEqual(before_commands.len, commands.len);
    for (before_commands, commands) |before, after| try std.testing.expectEqualDeep(before, after);
}
