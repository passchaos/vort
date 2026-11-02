const std = @import("std");
const fixtures = @import("fixtures.zig");
const oracle = @import("oracle.zig");

pub fn compare(comptime Codec: type, data: *const fixtures.Fixture) !void {
    const allocator = std.testing.allocator;
    errdefer |err| std.debug.print("adaptive literal parity input={d} commands={d} types={d} alphabet0={d}: {s}\n", .{ data.input.len, data.commands.len, data.plan.type_count, data.active[0], @errorName(err) });
    const saved_input = try allocator.dupe(u8, data.input);
    defer allocator.free(saved_input);
    const saved_commands = try allocator.dupe(Codec.Command, data.commands);
    defer allocator.free(saved_commands);
    const saved_lengths = try allocator.dupe(u32, data.plan.lengths);
    defer allocator.free(saved_lengths);
    const saved_types = try allocator.dupe(u8, data.plan.types);
    defer allocator.free(saved_types);
    const options: Codec.Options = .{ .use_recent_distances = true, .adaptive_literal_split = &data.plan };
    try std.testing.expect(Codec.supported(data.input, data.commands, options));
    var expected_stats = fixtures.stats(Codec.Stats, data.*);
    const expected = try Codec.encode(allocator, data.input, data.commands, &expected_stats, options);
    defer allocator.free(expected);
    var prepared = try Codec.prepare(allocator, data.input, data.commands, options);
    defer prepared.deinit(allocator);
    try std.testing.expect(prepared.common.ready);
    try std.testing.expect(prepared.key.matches(data.input, data.commands, options));
    try std.testing.expectEqual(data.literal_count, prepared.literal_count);
    try std.testing.expectEqual(expected.len, prepared.wire_len);
    try std.testing.expectEqual(try oracle.payload(data.input, data.commands, options, &prepared), prepared.payload_bits);
    try std.testing.expectEqual(prepared.header_bits, try Codec.headerBits(allocator, data.input, options, &prepared));
    const header = try Codec.headerWire(allocator, data.input, options, &prepared);
    defer allocator.free(header.wire);
    try std.testing.expectEqual(prepared.header_bits, header.bits);
    const complete: usize = @intCast(header.bits / 8);
    try std.testing.expectEqualSlices(u8, expected[0..complete], header.wire[0..complete]);
    if (header.bits % 8 != 0) {
        const mask = @as(u8, 0xff) >> @intCast(8 - header.bits % 8);
        try std.testing.expectEqual(expected[complete] & mask, header.wire[complete] & mask);
    }
    for (prepared.alphabets[0..data.plan.type_count], prepared.lengths[0..data.plan.type_count], 0..) |*alphabet, *lengths, tree| {
        try std.testing.expectEqual(data.active[tree], alphabet.len);
        if (alphabet.len >= 2 and alphabet.len <= 4) {
            for (alphabet.symbols[0..alphabet.len], 0..) |symbol, index| {
                const wanted: u4 = if (alphabet.len == 2) 1 else if (alphabet.len == 3) (if (index == 0) @as(u4, 1) else 2) else 2;
                try std.testing.expectEqual(wanted, lengths[symbol]);
            }
        }
    }
    var actual_stats = fixtures.stats(Codec.Stats, data.*);
    const actual = try Codec.emit(allocator, data.input, data.commands, &actual_stats, options, &prepared);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
    try std.testing.expectEqualDeep(expected_stats, actual_stats);
    const decoded = try Codec.decode(allocator, actual, data.input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, data.input, decoded);
    try std.testing.expectEqualSlices(u8, saved_input, data.input);
    try std.testing.expectEqualSlices(u32, saved_lengths, data.plan.lengths);
    try std.testing.expectEqualSlices(u8, saved_types, data.plan.types);
    for (saved_commands, data.commands) |before, after| try std.testing.expectEqualDeep(before, after);
}

pub fn check(comptime Codec: type) !void {
    const allocator = std.testing.allocator;
    for ([_]usize{ 1, 2, 3, 4, 5, 64, 65, 256 }) |alphabet| {
        const data = try fixtures.palette(allocator, 2, alphabet);
        defer data.deinit(allocator);
        try compare(Codec, &data);
    }
    const sizes = [_]usize{ 2, 3, 4, 5, 64, 65 };
    for (3..9) |types| {
        const data = try fixtures.palette(allocator, types, sizes[types - 3]);
        defer data.deinit(allocator);
        try compare(Codec, &data);
    }
    const tiny = try fixtures.tiny(allocator);
    defer tiny.deinit(allocator);
    try compare(Codec, &tiny);
    for ([_]usize{ 24, 160 }) |count| {
        const rich = try fixtures.rich(allocator, count);
        defer rich.deinit(allocator);
        if (count > 128) try std.testing.expect(rich.commands.len > 128);
        try compare(Codec, &rich);
    }
}
