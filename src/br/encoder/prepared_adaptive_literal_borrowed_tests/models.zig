const std = @import("std");
const fixtures = @import("../prepared_adaptive_literal_tests/fixtures.zig");
const common_checks = @import("../context_primary_prepare_tests/support.zig");

pub fn same(comptime Codec: type, owned: *const Codec.Prepared, borrowed: *const Codec.Prepared) !void {
    try common_checks.sameCommon(owned.commonPlan(), borrowed.commonPlan(), owned.key.common.commands_len);
    try std.testing.expectEqualDeep(owned.key, borrowed.key);
    try std.testing.expectEqual(owned.header_bits, borrowed.header_bits);
    try std.testing.expectEqual(owned.payload_bits, borrowed.payload_bits);
    try std.testing.expectEqual(owned.wire_len, borrowed.wire_len);
    try std.testing.expectEqual(owned.literal_count, borrowed.literal_count);
    for (owned.alphabets[0..owned.key.type_count], borrowed.alphabets[0..borrowed.key.type_count], owned.lengths[0..owned.key.type_count], borrowed.lengths[0..borrowed.key.type_count]) |*a, *b, *al, *bl| {
        try std.testing.expectEqualSlices(u16, a.symbols[0..a.len], b.symbols[0..b.len]);
        try std.testing.expectEqualSlices(u4, al, bl);
    }
    try std.testing.expectEqualSlices(u16, owned.split_code.type_model.symbols, borrowed.split_code.type_model.symbols);
    try std.testing.expectEqualSlices(u32, &owned.split_code.type_model.frequencies, &borrowed.split_code.type_model.frequencies);
    for (owned.split_code.block_lengths, borrowed.split_code.block_lengths) |a, b| try std.testing.expectEqualDeep(a, b);
}

fn compare(comptime Codec: type, data: *const fixtures.Fixture) !void {
    const allocator = std.testing.allocator;
    errdefer |err| std.debug.print("borrowed adaptive literal input={d} commands={d} types={d}: {s}\n", .{ data.input.len, data.commands.len, data.plan.type_count, @errorName(err) });
    const saved_input = try allocator.dupe(u8, data.input);
    defer allocator.free(saved_input);
    const saved_commands = try allocator.dupe(Codec.Command, data.commands);
    defer allocator.free(saved_commands);
    const saved_lengths = try allocator.dupe(u32, data.plan.lengths);
    defer allocator.free(saved_lengths);
    const saved_types = try allocator.dupe(u8, data.plan.types);
    defer allocator.free(saved_types);
    const options: Codec.Options = .{ .use_recent_distances = true, .adaptive_literal_split = &data.plan };
    var shared = try Codec.buildCommon(allocator, data.input, data.commands, options);
    const original_shared = shared;
    var owned = try Codec.prepare(allocator, data.input, data.commands, options);
    defer owned.deinit(allocator);
    var borrowed = try Codec.prepareBorrowed(allocator, data.input, data.commands, options, &shared);
    var borrowed_live = true;
    defer if (borrowed_live) borrowed.deinit(allocator);
    try std.testing.expect(owned.borrowed_common == null and owned.commonPlan() == &owned.common);
    try std.testing.expect(borrowed.borrowed_common == &shared and borrowed.commonPlan() == &shared);
    try same(Codec, &owned, &borrowed);
    // The unused inline common is deliberately unusable. All header/payload
    // and statistics operations must select the borrowed pointer instead.
    borrowed.common = Codec.Common.init(options, data.commands);
    common_checks.poison(&borrowed.common);
    borrowed.common.command_alphabet = .{};
    borrowed.common.distance_alphabet = .{};
    var expected_stats = fixtures.stats(Codec.Stats, data.*);
    const expected = try Codec.encode(allocator, data.input, data.commands, &expected_stats, options);
    defer allocator.free(expected);
    var owned_stats = fixtures.stats(Codec.Stats, data.*);
    const owned_wire = try Codec.emit(allocator, data.input, data.commands, &owned_stats, options, &owned);
    defer allocator.free(owned_wire);
    var borrowed_stats = fixtures.stats(Codec.Stats, data.*);
    const borrowed_wire = try Codec.emit(allocator, data.input, data.commands, &borrowed_stats, options, &borrowed);
    defer allocator.free(borrowed_wire);
    try std.testing.expectEqualSlices(u8, expected, owned_wire);
    try std.testing.expectEqualSlices(u8, expected, borrowed_wire);
    try std.testing.expectEqualDeep(expected_stats, owned_stats);
    try std.testing.expectEqualDeep(expected_stats, borrowed_stats);
    const header = try Codec.headerWire(allocator, data.input, options, &borrowed);
    defer allocator.free(header.wire);
    try std.testing.expectEqual(owned.header_bits, header.bits);
    try std.testing.expectEqual(owned.header_bits, try Codec.headerBits(allocator, data.input, options, &borrowed));
    const decoded = try Codec.decode(allocator, borrowed_wire, data.input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, data.input, decoded);
    borrowed.deinit(allocator);
    borrowed_live = false;
    try common_checks.sameCommon(&original_shared, &shared, data.commands.len);
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
        const data = try fixtures.rich(allocator, count);
        defer data.deinit(allocator);
        try compare(Codec, &data);
    }
}
