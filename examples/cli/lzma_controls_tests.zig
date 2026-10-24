const std = @import("std");
const vort = @import("vort");
const controls = @import("lzma_controls.zig");

const SliceArgs = struct {
    values: []const []const u8,
    index: usize = 0,
    pub fn next(self: *SliceArgs) ?[]const u8 {
        if (self.index == self.values.len) return null;
        defer self.index += 1;
        return self.values[self.index];
    }
};

fn parse(values: []const []const u8, maximum: usize) !controls.Parsed {
    var args = SliceArgs{ .values = values };
    return controls.parse(&args, maximum);
}

const Options = struct {
    properties: @FieldType(vort.LzmaCompressionPreset, "properties") = .{},
    dictionary_size: u32 = 32 * 1024,
    mode: @FieldType(vort.LzmaCompressionPreset, "mode") = .greedy,
    match_options: ?vort.LzmaMatchOptions = null,
    pub fn fromPreset(level: u32, extreme: bool) !Options {
        const preset = try vort.lzmaResolvePreset(level, extreme);
        return .{ .properties = preset.properties, .dictionary_size = preset.dictionary_size, .mode = preset.mode, .match_options = preset.match_options };
    }
};

test "LZMA CLI controls resolve all presets and keep unselected legacy defaults" {
    const empty = try parse(&.{}, 5);
    const legacy = try empty.controls.baseOptions(Options);
    try std.testing.expectEqual(@as(u32, 32768), legacy.dictionary_size);
    try std.testing.expectEqual(.greedy, legacy.mode);
    try std.testing.expect(legacy.match_options == null);
    for (0..10) |level| {
        for ([_]bool{ false, true }) |extreme| {
            const selected = controls.Controls{ .preset = @intCast(level), .extreme = extreme };
            const actual = try selected.baseOptions(Options);
            const expected = try vort.lzmaResolvePreset(@intCast(level), extreme);
            try std.testing.expectEqual(expected.dictionary_size, actual.dictionary_size);
            try std.testing.expectEqual(expected.mode, actual.mode);
            try std.testing.expectEqualDeep(expected.match_options, actual.match_options.?);
        }
    }
}

test "LZMA CLI controls flags override preset independently of their order" {
    const a = try parse(&.{ "known", "--preset=9", "--extreme", "--dict-size=4096", "--match-finder=bt2", "--nice-len=2", "--depth=17", "--mode=fast", "--lc=2", "--lp=1", "--pb=0", "--match-memory=1048576", "--profile" }, 1);
    const b = try parse(&.{ "known", "--profile", "--match-memory=1048576", "--pb=0", "--lp=1", "--lc=2", "--mode=fast", "--depth=17", "--nice-len=2", "--match-finder=bt2", "--dict-size=4096", "--extreme", "--preset=9" }, 1);
    try std.testing.expectEqualStrings("known", a.positionals[0].?);
    var first = try a.controls.baseOptions(Options);
    var second = try b.controls.baseOptions(Options);
    var profile: vort.LzmaEncodeWorkProfile = .{};
    try a.controls.apply(&first, "mode", &profile);
    try b.controls.apply(&second, "mode", &profile);
    try std.testing.expectEqualDeep(first, second);
    try std.testing.expectEqual(@as(u32, 4096), first.dictionary_size);
    try std.testing.expectEqual(.fast, first.mode);
    try std.testing.expectEqual(.bt2, first.match_options.?.finder);
    try std.testing.expectEqual(@as(u16, 2), first.match_options.?.nice_len);
    try std.testing.expectEqual(@as(u32, 17), first.match_options.?.depth);
    try std.testing.expectEqual(@as(usize, 1048576), first.match_options.?.max_working_memory);
    try std.testing.expect(first.match_options.?.profile == &profile);
}

test "LZMA CLI controls reject duplicates unknown values and misplaced positionals" {
    inline for (.{ "--preset=2", "--match-finder=hc3", "--nice-len=64", "--depth=0", "--dict-size=4096", "--mode=normal", "--lc=3", "--lp=0", "--pb=2", "--match-memory=100", "--profile" }) |flag| {
        try std.testing.expectError(error.DuplicateLzmaOption, parse(&.{ flag, flag }, 0));
    }
    try std.testing.expectError(error.DuplicateLzmaOption, parse(&.{ "--preset=1", "--extreme", "--extreme" }, 0));
    try std.testing.expectError(error.LzmaExtremeRequiresPreset, parse(&.{"--extreme"}, 0));
    try std.testing.expectError(error.InvalidLzmaOptions, parse(&.{"--preset=10"}, 0));
    try std.testing.expectError(error.InvalidLzmaOptions, parse(&.{"--nice-len=1"}, 0));
    try std.testing.expectError(error.InvalidLzmaOptions, parse(&.{"--nice-len=274"}, 0));
    try std.testing.expectError(error.InvalidLzmaOptions, parse(&.{"--mode=adaptive"}, 0));
    try std.testing.expectError(error.InvalidLzmaMatchFinder, parse(&.{"--match-finder=bt5"}, 0));
    try std.testing.expectError(error.MissingLzmaOptionValue, parse(&.{"--preset="}, 0));
    try std.testing.expectError(error.UnknownLzmaOption, parse(&.{"--unknown=1"}, 0));
    try std.testing.expectError(error.UnknownLzmaOption, parse(&.{"--preset"}, 0));
    try std.testing.expectError(error.UnexpectedLzmaArgument, parse(&.{ "--preset=2", "known" }, 1));
    try std.testing.expectError(error.UnexpectedLzmaArgument, parse(&.{ "known", "extra" }, 1));
}

test "LZMA CLI profile requires selected advanced controls and preserves their settings" {
    var profile: vort.LzmaEncodeWorkProfile = .{};
    const only_profile = try parse(&.{"--profile"}, 0);
    var legacy: Options = .{};
    try std.testing.expectError(error.LzmaProfileRequiresAdvancedControls, only_profile.controls.apply(&legacy, "mode", &profile));
    try std.testing.expect(legacy.match_options == null);
    try std.testing.expectEqual(.greedy, legacy.mode);

    inline for (.{
        &.{ "--preset=6", "--dict-size=4096" },
        &.{ "--mode=fast", "--match-finder=bt2", "--nice-len=2", "--depth=17" },
    }) |flags| {
        const parsed = try parse(flags, 0);
        var without = try parsed.controls.baseOptions(Options);
        try parsed.controls.apply(&without, "mode", null);
        var with = try parsed.controls.baseOptions(Options);
        var profiled_controls = parsed.controls;
        profiled_controls.profile = true;
        try profiled_controls.apply(&with, "mode", &profile);
        try std.testing.expect(with.match_options.?.profile == &profile);
        with.match_options.?.profile = null;
        try std.testing.expectEqualDeep(without, with);
    }
}

test "LZMA CLI mode-only controls use public fast and normal match defaults" {
    var profile: vort.LzmaEncodeWorkProfile = .{};
    inline for (.{ "fast", "normal" }) |name| {
        const parsed = try parse(&.{"--mode=" ++ name}, 0);
        var plain = try parsed.controls.baseOptions(Options);
        try parsed.controls.apply(&plain, "mode", null);
        const expected_finder: vort.LzmaMatchFinder = if (std.mem.eql(u8, name, "normal")) .bt4 else .hc4;
        try std.testing.expectEqual(expected_finder, plain.match_options.?.finder);
        try std.testing.expectEqual(@as(u16, 64), plain.match_options.?.nice_len);
        try std.testing.expectEqual(@as(u32, 0), plain.match_options.?.depth);
        try std.testing.expectEqual(@as(u32, if (std.mem.eql(u8, name, "normal")) 48 else 20), plain.match_options.?.effectiveDepth());
        const profiled = try parse(&.{ "--mode=" ++ name, "--profile" }, 0);
        var with = try profiled.controls.baseOptions(Options);
        try profiled.controls.apply(&with, "mode", &profile);
        try std.testing.expect(with.match_options.?.profile == &profile);
        with.match_options.?.profile = null;
        try std.testing.expectEqualDeep(plain, with);
    }

    const selected = try parse(&.{ "--preset=0", "--mode=normal" }, 0);
    var preset = try selected.controls.baseOptions(Options);
    try selected.controls.apply(&preset, "mode", null);
    try std.testing.expectEqual(.hc3, preset.match_options.?.finder);
    try std.testing.expectEqual(@as(u16, 128), preset.match_options.?.nice_len);
    try std.testing.expectEqual(@as(u32, 4), preset.match_options.?.depth);
    const overridden = try parse(&.{ "--mode=normal", "--match-finder=hc4" }, 0);
    var explicit = try overridden.controls.baseOptions(Options);
    try overridden.controls.apply(&explicit, "mode", null);
    try std.testing.expectEqual(.hc4, explicit.match_options.?.finder);
}
