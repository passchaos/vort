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
