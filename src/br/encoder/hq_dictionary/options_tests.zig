const std = @import("std");
const options = @import("../hq_options.zig");
const Mode = @import("../quality_schedule.zig").Mode;
const distance = @import("../distance.zig");

test "Brotli HQ options resolve native beam and reference pass defaults without profile mutation" {
    var profile: options.HqProfile = .{ .states = 7, .emitted_commands = 3 };
    const before = profile;
    const raw: options.HqOptions = .{ .profile = &profile };
    const q10 = try raw.resolve(10, Mode.generic);
    const q11 = try raw.resolve(11, Mode.text);
    try std.testing.expectEqual(@as(u32, 64), q10.search_depth);
    try std.testing.expectEqual(@as(u32, 128), q10.nice_len);
    try std.testing.expectEqual(@as(usize, 256 * 1024), q10.block_len);
    try std.testing.expectEqual(@as(u8, 8), q10.beam_width);
    try std.testing.expectEqual(@as(u8, 16), q11.beam_width);
    try std.testing.expectEqual(@as(u8, 1), q10.iterations);
    try std.testing.expectEqual(@as(u8, 2), q11.iterations);
    try std.testing.expectEqualDeep(distance.Parameters.init(0, 0), q10.distance_parameters);
    const font = try raw.resolve(10, Mode.font);
    try std.testing.expectEqualDeep(distance.Parameters.init(1, 6), font.distance_parameters);
    const explicit = try (options.HqOptions{ .search_depth = 65536, .nice_len = 1 << 24, .beam_width = 32, .iterations = 8, .block_len = 1 << 24, .max_working_memory = 0, .distance_parameters = distance.Parameters.init(3, 15) }).resolve(11, Mode.font);
    try std.testing.expectEqual(@as(u8, 8), explicit.iterations);
    try std.testing.expectEqual(@as(usize, 1 << 24), explicit.block_len);
    try std.testing.expectEqual(@as(usize, 0), explicit.max_working_memory);
    try std.testing.expectEqualDeep(distance.Parameters.init(3, 15), explicit.distance_parameters);
    for ([_]u8{ 0, 9, 12, 255 }) |quality| try std.testing.expectError(error.InvalidBlockPlan, raw.validate(quality));
    for ([_]options.HqOptions{
        .{ .search_depth = 0 },         .{ .search_depth = 65537 },      .{ .nice_len = 1 },
        .{ .nice_len = (1 << 24) + 1 }, .{ .beam_width = 33 },           .{ .iterations = 9 },
        .{ .block_len = 0 },            .{ .block_len = (1 << 24) + 1 },
    }) |invalid| try std.testing.expectError(error.InvalidBlockPlan, invalid.validate(10));
    try std.testing.expectEqualDeep(before, profile);
}

test "Brotli HQ profile accumulates real work with max peak and separate emitted rollback" {
    var profile: options.HqProfile = .{ .tree_nodes = std.math.maxInt(u64) - 1, .emitted_commands = 2, .emitted_copy_bytes = 3, .emitted_max_distance = 4, .peak_working_memory = 5 };
    const previous = profile.emitted();
    profile.add("tree_nodes", 10);
    profile.add("history_seed_positions", 7);
    profile.add("short_hash_probes", 8);
    profile.add("stitch_positions", 9);
    profile.add("normalizations", 10);
    profile.add("indexed_positions", 11);
    profile.add("emitted_commands", 20);
    profile.recordPeak(100);
    profile.restoreEmitted(previous);
    try std.testing.expectEqual(std.math.maxInt(u64), profile.tree_nodes);
    try std.testing.expectEqual(@as(u64, 2), profile.emitted_commands);
    const other: options.HqProfile = .{ .passes = 2, .refinement_passes = 1, .static_candidates = 4, .peak_working_memory = 200, .emitted_commands = 7, .emitted_max_distance = 50 };
    profile.mergeWork(other);
    try std.testing.expectEqual(@as(u64, 2), profile.passes);
    try std.testing.expectEqual(@as(u64, 1), profile.refinement_passes);
    try std.testing.expectEqual(@as(u64, 2), profile.emitted_commands);
    try std.testing.expectEqual(@as(usize, 200), profile.peak_working_memory);
    profile.mergeEmitted(other.emitted());
    try std.testing.expectEqual(@as(u64, 9), profile.emitted_commands);
    try std.testing.expectEqual(@as(usize, 50), profile.emitted_max_distance);
    profile.recordPeak(1);
    try std.testing.expectEqual(@as(usize, 200), profile.peak_working_memory);
    profile.reset();
    try std.testing.expectEqualDeep(options.HqProfile{}, profile);
}
