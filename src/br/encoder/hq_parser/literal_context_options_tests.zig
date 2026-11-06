const std = @import("std");
const options = @import("../hq_options.zig");
const distance = @import("../distance.zig");
const Mode = @import("../quality_schedule.zig").Mode;
const Parameters = @import("state.zig").Parameters;
const WireContext = @import("../hq_codec/wire.zig").Context;
const parser = @import("../hq_parser.zig");

test "Brotli HQ literal context policy preserves defaults and independent resolved settings" {
    const defaults: options.HqOptions = .{};
    try std.testing.expect(!defaults.disable_literal_context_modeling);
    const legacy: options.Resolved = .{ .quality = 10, .search_depth = 64, .nice_len = 128, .beam_width = 8, .iterations = 1, .max_working_memory = 0, .block_len = 1, .distance_parameters = .init(0, 0) };
    try std.testing.expect(!legacy.disable_literal_context_modeling);
    for ([_]u8{ 10, 11 }) |quality| for ([_]Mode{ .generic, .text, .font }) |mode| for ([_]distance.Format{ .standard, .large_window }) |format| for ([_]options.ParseMode{ .bounded, .whole_block }) |parse_mode| for ([_]options.CopyLengthPolicy{ .sampled, .complete }) |copy_lengths| {
        const raw: options.HqOptions = .{ .parse_mode = parse_mode, .copy_lengths = copy_lengths, .max_price_evaluations = 42 };
        const modeled = try raw.resolveForFormat(quality, mode, format);
        try std.testing.expect(!modeled.disable_literal_context_modeling);
        var selected = raw;
        selected.disable_literal_context_modeling = true;
        const flat = try selected.resolveForFormat(quality, mode, format);
        try std.testing.expect(flat.disable_literal_context_modeling);
        var normalized = flat;
        normalized.disable_literal_context_modeling = false;
        try std.testing.expectEqualDeep(modeled, normalized);
        const parameters = try Parameters.initWithFormat(selected, quality, mode, format);
        try std.testing.expectEqualDeep(flat, parameters.resolved);
    };
}

test "Brotli HQ literal context policy profile preserves effective selection through work merges" {
    const resolved = try (options.HqOptions{ .disable_literal_context_modeling = true }).resolve(11, Mode.generic);
    var profile: options.HqProfile = .{ .passes = 2, .emitted_commands = 3 };
    profile.recordEffective(resolved);
    try std.testing.expect(profile.effective.?.disable_literal_context_modeling);
    const before = profile;
    const emitted = profile.emitted();
    profile.add("emitted_commands", 5);
    profile.restoreEmitted(emitted);
    try std.testing.expectEqualDeep(before, profile);
    var merged: options.HqProfile = .{};
    merged.mergeWork(profile);
    try std.testing.expectEqualDeep(resolved, merged.effective.?);
    try std.testing.expectEqual(@as(u64, 2), merged.passes);
    try std.testing.expectEqual(@as(u64, 0), merged.emitted_commands);
    merged.reset();
    try std.testing.expectEqualDeep(options.HqProfile{}, merged);
}

test "Brotli HQ wire literal context policy defaults to modeled literals" {
    const context: WireContext = .{ .window_bits = 16, .literal_mode = 2, .distance_parameters = .init(0, 0) };
    try std.testing.expect(!context.disable_literal_context_modeling);
    var selected = context;
    selected.disable_literal_context_modeling = true;
    try std.testing.expect(selected.disable_literal_context_modeling);
    selected.disable_literal_context_modeling = false;
    try std.testing.expectEqualDeep(context, selected);
}

test "Brotli HQ literal context policy preserves parser work and requested heap" {
    const allocator = std.testing.allocator;
    const source = try parser.Source.init("", "abcabcabc012abcabc", 16, 0);
    const model = parser.Model.init(.init(0, 0), 2);
    for ([_]options.ParseMode{ .bounded, .whole_block }) |parse_mode| for ([_]options.CopyLengthPolicy{ .sampled, .complete }) |copy_lengths| {
        var baseline_profile: options.HqProfile = .{};
        var selected_profile: options.HqProfile = .{};
        const raw: options.HqOptions = .{ .beam_width = 2, .iterations = 1, .parse_mode = parse_mode, .copy_lengths = copy_lengths, .profile = &baseline_profile };
        var selected = raw;
        selected.disable_literal_context_modeling = true;
        selected.profile = &selected_profile;
        const baseline = try parser.planAlloc(allocator, source, try Parameters.init(raw, 10, Mode.generic), &model, null);
        defer baseline.deinit(allocator);
        const planned = try parser.planAlloc(allocator, source, try Parameters.init(selected, 10, Mode.generic), &model, null);
        defer planned.deinit(allocator);
        try std.testing.expectEqualDeep(baseline.commands, planned.commands);
        try std.testing.expectEqual(baseline.estimated_cost, planned.estimated_cost);
        try std.testing.expectEqual(baseline.peak_working_memory, planned.peak_working_memory);
        try std.testing.expect(selected_profile.effective.?.disable_literal_context_modeling);
        selected_profile.effective.?.disable_literal_context_modeling = false;
        try std.testing.expectEqualDeep(baseline_profile, selected_profile);
    };
}
