const std = @import("std");
const observer = @import("observer.zig");
const api = @import("api.zig");
const f = @import("fixtures.zig");
const existing = @import("../br_total_memory_helpers.zig");
const a = std.testing.allocator;

pub fn contracts(comptime D: type, stats: *observer.Stats) !void {
    const static_options: D.PlannedEncodeOptions = .{ .level = .ratio, .disable_literal_context_modeling = true };
    const static_wire = try D.encodePlannedStreamWithOptionsAlloc(a, f.dictionary_words, static_options);
    defer a.free(static_wire);
    const static_stats = try observer.check(D, static_wire, f.dictionary_words, true, .{});
    try std.testing.expect(static_stats.dictionary_copies != 0);
    stats.add(static_stats);
    try api.oneForms(D, f.dictionary_words, static_options, stats);

    var sizes: [32]u8 = @splat(0);
    sizes[4] = 1;
    var contexts: [64]u6 = undefined;
    for (&contexts, 0..) |*id, i| id.* = @intCast(i & 1);
    const encoded_dictionary = try D.serializeSharedDictionaryAlloc(a, .{
        .raw_prefix = f.text,
        .word_lists = &.{
            .{ .size_bits_by_length = sizes, .data = "cat!dog!" },
            .{ .size_bits_by_length = sizes, .data = "owl!fox!" },
        },
        .transform_lists = &.{.{ .prefix_suffix = &.{0}, .transforms = &.{ 0, 0, 0 } }},
        .dictionaries = &.{
            .{ .word_list_index = 0, .transform_list_index = 0 },
            .{ .word_list_index = 1, .transform_list_index = 0 },
        },
        .context_map = &contexts,
    });
    defer a.free(encoded_dictionary);
    const parsed = try D.parseSerializedSharedDictionary(encoded_dictionary);
    try std.testing.expect(parsed.context_based);
    try std.testing.expectEqualSlices(u6, &contexts, &parsed.context_map);
    const input = f.text ++ "cat! dog! owl! fox! cat! dog! owl! fox! " ++ f.text;
    const raw_prefixes = [_][]const u8{ "", f.text[0..40], f.text[40..] };
    for ([_]D.SharedDictionary{ .{ .raw_prefixes = &raw_prefixes }, .{ .serialized = &parsed } }, 0..) |dictionary, index| {
        const quality: u4 = if (index == 0) 10 else 11;
        var true_wire: ?[]u8 = null;
        defer if (true_wire) |wire| a.free(wire);
        for ([_][2]bool{ .{ false, false }, .{ true, false }, .{ false, true }, .{ true, true } }) |flags| {
            var profile: D.HqProfile = .{};
            const options: D.PlannedEncodeOptions = .{
                .quality = quality,
                .mode = if (index == 0) .generic else .font,
                .window_bits = if (index == 0) 16 else 25,
                .large_window = index != 0,
                .shared_dictionary = dictionary,
                .disable_literal_context_modeling = flags[0],
                .hq = .{
                    .beam_width = 2,
                    .iterations = 1,
                    .block_len = 512,
                    .profile = &profile,
                    .disable_literal_context_modeling = flags[1],
                },
            };
            const wire = try D.encodePlannedStreamWithOptionsAlloc(a, input, options);
            defer a.free(wire);
            const disabled = flags[0] or flags[1];
            const checked = try observer.check(D, wire, input, disabled, api.decodeOptions(D, options));
            try std.testing.expect(checked.compressed_blocks != 0);
            try std.testing.expect(checked.dictionary_copies != 0);
            try std.testing.expect(profile.passes != 0);
            try std.testing.expectEqual(disabled, profile.effective.?.disable_literal_context_modeling);
            stats.add(checked);
            if (disabled) {
                if (true_wire) |previous|
                    try std.testing.expectEqualSlices(u8, previous, wire)
                else
                    true_wire = try a.dupe(u8, wire);
            }
            if (flags[0] and !flags[1] and index == 0) try api.oneForms(D, input, options, stats);
            if (!flags[0] and flags[1] and index != 0)
                try api.chunkForms(D, input, api.streamOptions(D, options, 512), stats);
            if (!flags[0] and flags[1]) {
                var incremental = D.IncrementalPlannedStreamEncoder.initWithOptions(a, .{
                    .stream = api.streamOptions(D, options, 512),
                    .block_len = 0,
                });
                defer incremental.deinit();
                const fragmented = try existing.drive(a, &incremental, input, 17, 13);
                defer a.free(fragmented);
                const actual = try observer.check(D, fragmented, input, true, api.decodeOptions(D, options));
                try std.testing.expect(actual.dictionary_copies != 0);
                stats.add(actual);
            }
        }
    }
}
