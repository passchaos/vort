const std = @import("std");
const options = @import("../hq_options.zig");
const distance = @import("../distance.zig");
const Mode = @import("../quality_schedule.zig").Mode;

test "Brotli whole-block options preserve bounded defaults and every other resolved control" {
    const original: options.HqOptions = .{};
    try std.testing.expectEqual(options.ParseMode.bounded, original.parse_mode);
    for ([_]u8{ 10, 11 }) |quality| for ([_]Mode{ .generic, .text, .font }) |mode| for ([_]distance.Format{ .standard, .large_window }) |format| {
        const bounded = try original.resolveForFormat(quality, mode, format);
        var selected = original;
        selected.parse_mode = .whole_block;
        const whole = try selected.resolveForFormat(quality, mode, format);
        try std.testing.expectEqual(options.ParseMode.whole_block, whole.parse_mode);
        var normalized = whole;
        normalized.parse_mode = .bounded;
        try std.testing.expectEqualDeep(bounded, normalized);
        try std.testing.expectEqual(@as(u8, if (quality == 10) 8 else 16), whole.beam_width);
        try std.testing.expectEqual(@as(u8, if (quality == 10) 1 else 2), whole.iterations);
    };
    const legacy_literal: options.Resolved = .{ .quality = 10, .search_depth = 64, .nice_len = 128, .beam_width = 8, .iterations = 1, .max_working_memory = 0, .block_len = 1, .distance_parameters = .init(0, 0) };
    try std.testing.expectEqual(options.ParseMode.bounded, legacy_literal.parse_mode);
    try std.testing.expectEqual(distance.Format.standard, legacy_literal.format);
}

test "Brotli whole-block options accept complete meta-block bounds without implicit fallback" {
    for ([_]usize{ 1, 4096, 4097, 65536, 1 << 24 }) |block_len| {
        const raw: options.HqOptions = .{ .parse_mode = .whole_block, .block_len = block_len, .max_working_memory = 0, .beam_width = 1, .iterations = 8 };
        const resolved = try raw.resolveForFormat(11, Mode.font, .large_window);
        try std.testing.expectEqual(block_len, resolved.block_len);
        try std.testing.expectEqual(@as(usize, 0), resolved.max_working_memory);
        try std.testing.expectEqual(options.ParseMode.whole_block, resolved.parse_mode);
        try std.testing.expectEqual(@as(u8, 1), resolved.beam_width);
        try std.testing.expectEqual(@as(u8, 8), resolved.iterations);
        try std.testing.expectEqualDeep(distance.Parameters.init(1, 6), resolved.distance_parameters);
    }
    try std.testing.expectError(error.InvalidBlockPlan, (options.HqOptions{ .parse_mode = .whole_block, .block_len = 0 }).validate(10));
    try std.testing.expectError(error.InvalidBlockPlan, (options.HqOptions{ .parse_mode = .whole_block, .block_len = (1 << 24) + 1 }).validate(11));
    try std.testing.expectError(error.InvalidBlockPlan, (options.HqOptions{ .parse_mode = .whole_block }).validate(9));
}

test "Brotli whole-block options profile tracks actual mode passes with saturating counts and maximum span" {
    var profile: options.HqProfile = .{ .passes = 5, .bounded_passes = std.math.maxInt(u64) - 1, .whole_block_passes = std.math.maxInt(u64) - 1, .max_parse_positions = 4096, .emitted_commands = 7 };
    const before_empty = profile;
    profile.recordParseMode(.bounded, 0);
    profile.recordParseMode(.whole_block, 0);
    try std.testing.expectEqualDeep(before_empty, profile);
    profile.recordParseMode(.bounded, 4096);
    profile.recordParseMode(.whole_block, 1 << 24);
    profile.recordParseMode(.bounded, 3);
    profile.recordParseMode(.whole_block, 4);
    try std.testing.expectEqual(std.math.maxInt(u64), profile.bounded_passes);
    try std.testing.expectEqual(std.math.maxInt(u64), profile.whole_block_passes);
    try std.testing.expectEqual(@as(u64, 5), profile.passes);
    try std.testing.expectEqual(@as(usize, 1 << 24), profile.max_parse_positions);
    const emitted = profile.emitted();
    profile.add("emitted_commands", 9);
    profile.restoreEmitted(emitted);
    try std.testing.expectEqual(@as(u64, 7), profile.emitted_commands);
    try std.testing.expectEqual(@as(usize, 1 << 24), profile.max_parse_positions);
    const whole = try (options.HqOptions{ .parse_mode = .whole_block }).resolve(11, Mode.generic);
    var merged: options.HqProfile = .{ .bounded_passes = 1, .whole_block_passes = 2, .max_parse_positions = 4096 };
    merged.mergeWork(.{ .bounded_passes = 3, .whole_block_passes = 4, .max_parse_positions = 65536, .effective = whole });
    merged.mergeWork(.{ .max_parse_positions = 7 });
    try std.testing.expectEqual(@as(u64, 4), merged.bounded_passes);
    try std.testing.expectEqual(@as(u64, 6), merged.whole_block_passes);
    try std.testing.expectEqual(@as(usize, 65536), merged.max_parse_positions);
    try std.testing.expectEqual(options.ParseMode.whole_block, merged.effective.?.parse_mode);
    profile.mergeWork(.{ .bounded_passes = 1, .whole_block_passes = 1, .max_parse_positions = 8 });
    try std.testing.expectEqual(std.math.maxInt(u64), profile.bounded_passes);
    try std.testing.expectEqual(std.math.maxInt(u64), profile.whole_block_passes);
    try std.testing.expectEqual(@as(usize, 1 << 24), profile.max_parse_positions);
    profile.reset();
    try std.testing.expectEqualDeep(options.HqProfile{}, profile);
}
