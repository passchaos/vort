const std = @import("std");
const vort = @import("vort");
const cli = @import("zstd_controls.zig");

const Args = struct {
    values: []const []const u8,
    index: usize = 0,
    pub fn next(self: *Args) ?[]const u8 {
        if (self.index == self.values.len) return null;
        defer self.index += 1;
        return self.values[self.index];
    }
};
fn parse(values: []const []const u8) !cli.Controls {
    var args = Args{ .values = values };
    return cli.parse(&args, null);
}

test "Zstd CLI controls preserve legacy defaults and profile-only configuration" {
    const parsed = try parse(&.{});
    const actual = try parsed.resolved();
    try std.testing.expectEqualDeep(vort.ZstdNativeFrameOptions{}, actual);
    var profile: vort.ZstdEncoderControlProfile = .{};
    const profiled = try parse(&.{"--profile"});
    var with = try profiled.resolvedWithProfile(&profile);
    try std.testing.expect(with.control_profile == &profile);
    with.control_profile = null;
    try std.testing.expectEqualDeep(actual, with);
    const positions = try parse(&.{ "literal-only", "false", "no" });
    try std.testing.expectEqual(.literal_only, positions.selection);
    try std.testing.expect(!positions.checksum and !positions.content_size);
    inline for (.{ "auto", "fast", "double_fast", "greedy", "lazy", "optimal" }) |strategy| {
        const before = try (try parse(&.{"--strategy=" ++ strategy})).resolved();
        const with_flags = try parse(&.{ "--strategy=" ++ strategy, "--profile" });
        var after = try with_flags.resolvedWithProfile(&profile);
        after.control_profile = null;
        try std.testing.expectEqualDeep(before, after);
    }
}

test "Zstd CLI HQ flags accept equal and value styles independent of order" {
    const first = try parse(&.{ "--strategy=btultra2", "--hq-depth=65536", "--hq-nice-len=131072", "--hq-min-match=7", "--hq-memory=0", "--profile" });
    const second = try parse(&.{ "--profile", "--hq-memory", "0", "--hq-min-match", "7", "--hq-nice-len", "131072", "--hq-depth", "65536", "--strategy", "btultra2" });
    try std.testing.expectEqualDeep(first, second);
    try std.testing.expectEqual(@as(u32, 65536), first.hq_depth.?);
    try std.testing.expectEqual(@as(u32, 131072), first.hq_nice_len.?);
    try std.testing.expectEqual(@as(u8, 7), first.hq_min_match.?);
    try std.testing.expectEqual(@as(usize, 0), first.hq_memory.?);
    inline for (.{ "lazy2", "btlazy2", "btopt", "btultra", "btultra2" }) |name| {
        const parsed = try parse(&.{"--strategy=" ++ name});
        try std.testing.expectEqualStrings(name, @tagName(parsed.strategy.?));
    }
    inline for (.{ "--hq-depth", "--hq-depth=1", "--hq-nice-len", "--hq-min-match=3", "--hq-memory=0", "--profile" }) |name|
        try std.testing.expect(cli.isControlArgument(name));
}

test "Zstd CLI HQ flags reject duplicate unknown and malformed arguments" {
    inline for (.{ "--level=3", "--strategy=btopt", "--fast-acceleration=1", "--hq-depth=64", "--hq-nice-len=128", "--hq-min-match=3", "--hq-memory=1024", "--profile" }) |flag|
        try std.testing.expectError(error.DuplicateZstdOption, parse(&.{ flag, flag }));
    try std.testing.expectError(error.UnknownZstdOption, parse(&.{"--hq-unknown=3"}));
    try std.testing.expectError(error.MissingZstdOptionValue, parse(&.{"--hq-depth"}));
    try std.testing.expectError(error.Overflow, parse(&.{"--hq-depth=-1"}));
    try std.testing.expectError(error.Overflow, parse(&.{"--hq-depth=4294967296"}));
    try std.testing.expectError(error.InvalidCharacter, parse(&.{"--hq-memory="}));
    try std.testing.expectError(error.UnexpectedZstdArgument, parse(&.{ "auto", "true", "true", "extra" }));
}

test "Zstd CLI HQ partial flags preserve strategy and level defaults" {
    if (@hasField(vort.ZstdNativeFrameOptions, "hq")) {
        var profile: vort.ZstdEncoderControlProfile = .{};
        inline for (.{ "lazy2", "btlazy2", "btopt", "btultra", "btultra2" }) |name| {
            const defaults = try (try parse(&.{ "--strategy=" ++ name, "--level=20" })).resolved();
            const parsed = try parse(&.{ "--hq-depth=23", "--level=20", "--strategy=" ++ name, "--profile" });
            var actual = try parsed.resolvedWithProfile(&profile);
            try std.testing.expectEqual(defaults.hq.?.nice_len, actual.hq.?.nice_len);
            try std.testing.expectEqual(defaults.hq.?.min_match, actual.hq.?.min_match);
            try std.testing.expectEqual(@as(u32, 23), actual.hq.?.search_depth);
            try std.testing.expect(actual.control_profile == &profile);
            actual.control_profile = null;
            var expected = defaults;
            expected.hq.?.search_depth = 23;
            try std.testing.expectEqualDeep(expected, actual);
        }
    } else return error.SkipZigTest;
}

test "Zstd CLI HQ conflicts are rejected by public validation" {
    if (@hasField(vort.ZstdNativeFrameOptions, "hq")) {
        inline for (.{ "auto", "fast", "double_fast", "greedy", "lazy", "optimal" }) |name|
            try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{ "--strategy=" ++ name, "--hq-depth=16" })).resolved());
        inline for (.{ "lazy2", "btlazy2", "btopt", "btultra", "btultra2" }) |name| {
            inline for (.{ "0", "-1", "-131072" }) |level|
                try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{ "--strategy=" ++ name, "--level=" ++ level })).resolved());
            try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{ "--strategy=" ++ name, "--fast-acceleration=2" })).resolved());
        }
        inline for (.{ "--hq-depth=0", "--hq-depth=65537", "--hq-nice-len=2", "--hq-nice-len=131073", "--hq-min-match=2", "--hq-min-match=8" }) |flag|
            try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{ "--strategy=btopt", flag })).resolved());
        try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{ "--strategy=btopt", "--hq-nice-len=3", "--hq-min-match=7" })).resolved());
    } else return error.SkipZigTest;
}

test "Zstd CLI level helper rejects native-only selection arguments" {
    const parsed = try parse(&.{"literal_only"});
    try std.testing.expectError(error.InvalidBlockPlan, parsed.frameOptionsWithProfile(null));
}

test "Zstd CLI window and total-memory arguments parse independently of strategies" {
    const a = try parse(&.{ "--window-log=41", "--max-match-history-len=1024", "--max-total-memory=0", "--memory-profile" });
    const b = try parse(&.{ "--memory-profile", "--max-total-memory", "0", "--max-match-history-len", "1024", "--window-log", "41" });
    try std.testing.expectEqualDeep(a, b);
    try std.testing.expectEqual(@as(?u6, 41), a.window_log);
    try std.testing.expectEqual(@as(?usize, 1024), a.max_match_history_len);
    try std.testing.expectEqual(@as(?usize, 0), a.max_total_memory);
    try std.testing.expect(a.memory_profile and a.strategy == null and !a.hasHqOverrides());
    inline for (.{ "--window-log", "--max-match-history-len=1024", "--max-total-memory=0", "--memory-profile" }) |flag|
        try std.testing.expect(cli.isControlArgument(flag));
}

test "Zstd CLI window and total-memory parsing rejects duplicate and malformed flags" {
    inline for (.{ "--window-log=10", "--max-match-history-len=1024", "--max-total-memory=10", "--memory-profile" }) |flag|
        try std.testing.expectError(error.DuplicateZstdOption, parse(&.{ flag, flag }));
    try std.testing.expectError(error.MissingZstdOptionValue, parse(&.{"--window-log"}));
    try std.testing.expectError(error.MissingZstdOptionValue, parse(&.{"--max-total-memory"}));
    try std.testing.expectError(error.InvalidCharacter, parse(&.{"--max-total-memory="}));
    try std.testing.expectError(error.Overflow, parse(&.{"--max-match-history-len=-1"}));
    try std.testing.expectError(error.Overflow, parse(&.{"--window-log=64"}));
}

test "Zstd CLI window options map through native and level APIs without selecting controls" {
    const requested = try parse(&.{ "--window-log=41", "--max-match-history-len=1024" });
    const native = try requested.resolved();
    const frame = try requested.frameOptionsWithProfile(null);
    try std.testing.expectEqual(@as(?u6, 41), native.window_log);
    try std.testing.expectEqual(@as(?usize, 1024), native.max_match_history_len);
    try std.testing.expectEqual(native.window_log, frame.window_log);
    try std.testing.expectEqual(native.max_match_history_len, frame.max_match_history_len);
    try std.testing.expect(native.strategy == .auto and native.hq == null);
    try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{"--max-match-history-len=1024"})).resolved());
    try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{ "--window-log=24", "--max-match-history-len=1023" })).resolved());
    try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{"--window-log=42"})).resolved());
}

test "Zstd CLI total budget and memory instrumentation do not select an encoding strategy" {
    var profile: vort.zstd.EncodeMemoryProfile = .{};
    const defaults = try (try parse(&.{})).resolvedWithProfiles(null, null);
    try std.testing.expectEqualDeep(vort.ZstdNativeFrameOptions{}, defaults);
    const tracked = try parse(&.{ "--max-total-memory=0", "--memory-profile" });
    const native = try tracked.resolvedWithProfiles(null, &profile);
    const frame = try tracked.frameOptionsWithProfiles(null, &profile);
    try std.testing.expectEqual(@as(?usize, 0), native.max_total_working_memory);
    try std.testing.expect(native.memory_profile == &profile and frame.memory_profile == &profile);
    try std.testing.expect(native.strategy == .auto and native.hq == null);
    try std.testing.expectEqualDeep(vort.zstd.EncodeMemoryProfile{}, profile);
}

test "Zstd CLI history range follows the public encoder limit" {
    const maximum = vort.zstd.native_explicit_window_match_len_max;
    const accepted = cli.Controls{ .window_log = 41, .max_match_history_len = maximum };
    const native = try accepted.resolved();
    try std.testing.expectEqual(@as(?usize, maximum), native.max_match_history_len);
    try std.testing.expectError(error.InvalidBlockPlan, (cli.Controls{ .window_log = 41, .max_match_history_len = maximum + 1 }).resolved());
}

test "Zstd CLI logical stream limits cross 2^32 without selecting an encoder mode" {
    const parsed = try parse(&.{ "--max-input-len=4294967313", "--max-output-len", "4294967333" });
    const boundary: vort.StreamCount = @as(vort.StreamCount, 1) << 32;
    try std.testing.expectEqual(@as(?vort.StreamCount, boundary + 17), parsed.max_input_len);
    try std.testing.expectEqual(@as(?vort.StreamCount, boundary + 37), parsed.max_output_len);
    try std.testing.expect(parsed.hasStreamLimits() and parsed.strategy == null and !parsed.hasHqOverrides());
    try std.testing.expectEqual(@as(?vort.StreamCount, boundary + 17), try cli.parseLogicalLimit("4294967313"));
    try std.testing.expectEqual(@as(?vort.StreamCount, null), try cli.parseLogicalLimit(null));
    try std.testing.expectEqual(@as(?vort.StreamCount, 19), vort.core.stream_count.fromOptionalLocal(@as(?usize, 19)));
    try std.testing.expectEqual(@as(?usize, 19), try cli.localLimit(19));
    if (@bitSizeOf(usize) < 64) try std.testing.expectError(error.IntegerOverflow, cli.localLimit(boundary));
    try std.testing.expectError(error.DuplicateZstdOption, parse(&.{ "--max-input-len=1", "--max-input-len=2" }));
    try std.testing.expectError(error.DuplicateZstdOption, parse(&.{ "--max-output-len=1", "--max-output-len=2" }));
}

test "Zstd CLI stream file count and output cap remain independent of local IO buffers" {
    const files = @import("stream_files.zig");
    const boundary: vort.StreamCount = @as(vort.StreamCount, 1) << 32;
    try std.testing.expectEqual(boundary + 19, try files.fileSizeCounter(4294967315));
    try std.testing.expectEqual(boundary + 7, try files.checkedAdvance(boundary - 3, 10, boundary + 7));
    try std.testing.expectError(error.OutputLimitExceeded, files.checkedAdvance(boundary - 3, 10, boundary + 6));
    try std.testing.expectError(error.IntegerOverflow, files.checkedAdvance(std.math.maxInt(vort.StreamCount), 1, null));
}
