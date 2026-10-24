const std = @import("std");
const options = @import("../hq_options.zig");
const distance = @import("../distance.zig");
const Mode = @import("../quality_schedule.zig").Mode;

test "Brotli copy-length options preserve sampled defaults and independent resolved settings" {
    const defaults: options.HqOptions = .{};
    try std.testing.expectEqual(options.CopyLengthPolicy.sampled, defaults.copy_lengths);
    try std.testing.expect(defaults.max_price_evaluations == null);
    for ([_]u8{ 10, 11 }) |quality| for ([_]Mode{ .generic, .text, .font }) |mode| for ([_]distance.Format{ .standard, .large_window }) |format| for ([_]options.ParseMode{ .bounded, .whole_block }) |parse_mode| {
        const raw: options.HqOptions = .{ .parse_mode = parse_mode };
        const sampled = try raw.resolveForFormat(quality, mode, format);
        var complete_options = raw;
        complete_options.copy_lengths = .complete;
        const complete = try complete_options.resolveForFormat(quality, mode, format);
        try std.testing.expectEqual(options.CopyLengthPolicy.complete, complete.copy_lengths);
        var normalized = complete;
        normalized.copy_lengths = .sampled;
        try std.testing.expectEqualDeep(sampled, normalized);
        try std.testing.expectEqual(parse_mode, complete.parse_mode);
        try std.testing.expectEqual(format, complete.format);
        try std.testing.expectEqual(@as(u8, if (quality == 10) 8 else 16), complete.beam_width);
        try std.testing.expectEqual(@as(u8, if (quality == 10) 1 else 2), complete.iterations);
    };
    const old_literal: options.Resolved = .{ .quality = 10, .search_depth = 64, .nice_len = 128, .beam_width = 8, .iterations = 1, .max_working_memory = 0, .block_len = 1, .distance_parameters = .init(0, 0) };
    try std.testing.expectEqual(options.CopyLengthPolicy.sampled, old_literal.copy_lengths);
    try std.testing.expect(old_literal.max_price_evaluations == null);
}

test "Brotli copy-length options forward zero and finite per-plan evaluation limits without changing quality validation" {
    for ([_]options.CopyLengthPolicy{ .sampled, .complete }) |policy| for ([_]?u64{ null, 0, 1, 1234567, std.math.maxInt(u64) }) |limit| {
        const raw: options.HqOptions = .{ .copy_lengths = policy, .max_price_evaluations = limit, .parse_mode = .whole_block, .max_working_memory = 0, .block_len = 1 << 24 };
        try raw.validate(10);
        try raw.validate(11);
        const resolved = try raw.resolveForFormat(11, Mode.font, .large_window);
        try std.testing.expectEqual(limit, resolved.max_price_evaluations);
        try std.testing.expectEqual(policy, resolved.copy_lengths);
        try std.testing.expectEqual(options.ParseMode.whole_block, resolved.parse_mode);
        try std.testing.expectEqual(@as(usize, 0), resolved.max_working_memory);
        try std.testing.expectEqual(@as(usize, 1 << 24), resolved.block_len);
        try std.testing.expectEqualDeep(distance.Parameters.init(1, 6), resolved.distance_parameters);
    };
    for ([_]u8{ 0, 9, 12, 255 }) |quality|
        try std.testing.expectError(error.InvalidBlockPlan, (options.HqOptions{ .copy_lengths = .complete, .max_price_evaluations = 0 }).validate(quality));
    const budget_error: options.Error = error.SearchLimitExceeded;
    try std.testing.expectEqual(error.SearchLimitExceeded, budget_error);
}

test "Brotli copy-length options profile counts actual passes and measured maxima independently of limits" {
    var profile: options.HqProfile = .{ .passes = 7, .max_copy_length_considered = 3, .price_evaluations = 900, .emitted_commands = 2 };
    const before_empty = profile;
    profile.recordCopyLengthPolicy(.sampled, 0);
    profile.recordCopyLengthPolicy(.complete, 0);
    try std.testing.expectEqualDeep(before_empty, profile);
    profile.recordCopyLengthPolicy(.sampled, 4096);
    profile.recordCopyLengthPolicy(.complete, 1 << 24);
    try std.testing.expectEqual(@as(u64, 1), profile.sampled_length_passes);
    try std.testing.expectEqual(@as(u64, 1), profile.complete_length_passes);
    try std.testing.expectEqual(@as(u64, 7), profile.passes);
    // Input span and configured limits never become a considered copy length.
    try std.testing.expectEqual(@as(usize, 3), profile.max_copy_length_considered);
    profile.recordCopyLengthConsidered(1024);
    profile.recordCopyLengthConsidered(8);
    profile.recordMaxPlanPrice(42);
    profile.recordMaxPlanPrice(1);
    try std.testing.expectEqual(@as(usize, 1024), profile.max_copy_length_considered);
    try std.testing.expectEqual(@as(u64, 42), profile.max_plan_price_evaluations);
    const effective = try (options.HqOptions{ .copy_lengths = .complete, .max_price_evaluations = 999999 }).resolve(11, Mode.generic);
    profile.recordEffective(effective);
    try std.testing.expectEqual(@as(u64, 42), profile.max_plan_price_evaluations);
    const emitted = profile.emitted();
    profile.add("emitted_commands", 9);
    profile.restoreEmitted(emitted);
    try std.testing.expectEqual(@as(u64, 2), profile.emitted_commands);
    try std.testing.expectEqual(@as(u64, 42), profile.max_plan_price_evaluations);
    profile.mergeWork(.{ .sampled_length_passes = 2, .complete_length_passes = 3, .max_copy_length_considered = 2048, .max_plan_price_evaluations = 100, .price_evaluations = 800 });
    profile.mergeWork(.{ .max_copy_length_considered = 4, .max_plan_price_evaluations = 2 });
    try std.testing.expectEqual(@as(u64, 3), profile.sampled_length_passes);
    try std.testing.expectEqual(@as(u64, 4), profile.complete_length_passes);
    try std.testing.expectEqual(@as(usize, 2048), profile.max_copy_length_considered);
    try std.testing.expectEqual(@as(u64, 100), profile.max_plan_price_evaluations);
    try std.testing.expectEqual(@as(u64, 1700), profile.price_evaluations);
    profile.sampled_length_passes = std.math.maxInt(u64) - 1;
    profile.complete_length_passes = std.math.maxInt(u64) - 1;
    profile.recordCopyLengthPolicy(.sampled, 1);
    profile.recordCopyLengthPolicy(.complete, 1);
    profile.mergeWork(.{ .sampled_length_passes = 1, .complete_length_passes = 1 });
    try std.testing.expectEqual(std.math.maxInt(u64), profile.sampled_length_passes);
    try std.testing.expectEqual(std.math.maxInt(u64), profile.complete_length_passes);
    profile.reset();
    try std.testing.expectEqualDeep(options.HqProfile{}, profile);
}
