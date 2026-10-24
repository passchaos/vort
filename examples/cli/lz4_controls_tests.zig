const std = @import("std");
const controls = @import("lz4_controls.zig");
const vort = @import("vort");
const Args = struct {
    values: []const []const u8,
    index: usize = 0,
    pub fn next(self: *Args) ?[]const u8 {
        if (self.index == self.values.len) return null;
        defer self.index += 1;
        return self.values[self.index];
    }
};
fn parse(values: []const []const u8) !controls.Controls {
    var args = Args{ .values = values };
    return controls.parse(&args);
}

test "LZ4 CLI controls preserve unselected defaults and independent profile" {
    try std.testing.expectEqualDeep(controls.Controls{}, try parse(&.{}));
    const profile = try parse(&.{"--profile"});
    try std.testing.expect(profile.profile);
    try std.testing.expect(profile.acceleration == null and profile.chain_depth == null);
}

test "LZ4 CLI controls parse signed acceleration and independent chain depth in either style" {
    const first = try parse(&.{ "--acceleration=7", "--chain-depth=3", "--profile" });
    const second = try parse(&.{ "--profile", "--chain-depth", "3", "--acceleration", "7" });
    try std.testing.expectEqualDeep(first, second);
    inline for (.{ "-2147483648", "-1", "0", "1", "65537", "2147483647" }) |text| {
        const actual = try parse(&.{"--acceleration=" ++ text});
        try std.testing.expectEqual(try std.fmt.parseInt(i32, text, 10), actual.acceleration.?);
        try std.testing.expect(actual.chain_depth == null);
    }
    try std.testing.expectEqual(@as(?u8, 0), (try parse(&.{"--chain-depth=0"})).chain_depth);
}

test "LZ4 CLI controls reject duplicates unknown and malformed values" {
    inline for (.{ "--acceleration=1", "--chain-depth=3", "--profile" }) |flag|
        try std.testing.expectError(error.DuplicateLz4Option, parse(&.{ flag, flag }));
    try std.testing.expectError(error.MissingLz4OptionValue, parse(&.{"--acceleration"}));
    try std.testing.expectError(error.MissingLz4OptionValue, parse(&.{"--chain-depth"}));
    try std.testing.expectError(error.InvalidCharacter, parse(&.{"--acceleration="}));
    try std.testing.expectError(error.Overflow, parse(&.{"--acceleration=2147483648"}));
    try std.testing.expectError(error.Overflow, parse(&.{"--chain-depth=-1"}));
    try std.testing.expectError(error.Overflow, parse(&.{"--chain-depth=256"}));
    try std.testing.expectError(error.UnknownLz4Option, parse(&.{"--level=3"}));
    try std.testing.expectError(error.UnexpectedLz4Argument, parse(&.{"extra"}));
}

test "LZ4 CLI controls use public normalization without coupling acceleration and chain depth" {
    const defaults = try (try parse(&.{})).blockOptions(null);
    try std.testing.expectEqualDeep(vort.Lz4BlockEncodeOptions{}, defaults);
    inline for (.{ "-2147483648", "-1", "0", "1", "8", "65537", "2147483647" }) |text| {
        const values = try parse(&.{ "--acceleration=" ++ text, "--chain-depth=0" });
        const actual = try (try values.blockOptions(null)).resolve();
        try std.testing.expectEqual(vort.lz4NormalizeFastAcceleration(try std.fmt.parseInt(i32, text, 10)), actual.acceleration);
        try std.testing.expectEqual(@as(u8, 0), actual.chain_depth);
    }
    try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{"--chain-depth=17"})).blockOptions(null));
    var profile: vort.Lz4FastEncodeProfile = .{};
    var profiled = try (try parse(&.{"--profile"})).blockOptions(&profile);
    try std.testing.expect(profiled.profile == &profile);
    profiled.profile = null;
    try std.testing.expectEqualDeep(defaults, profiled);
    try std.testing.expectEqualDeep(vort.Lz4FastEncodeProfile{}, profile);
}

test "LZ4 CLI native controls mirror raw options and validate before file access" {
    const values = try parse(&.{ "--acceleration=8", "--chain-depth=3", "--profile" });
    var profile: vort.Lz4FastEncodeProfile = .{};
    const raw = try values.blockOptions(&profile);
    const native = try values.nativeOptions(&profile);
    try std.testing.expectEqual(raw.acceleration, native.acceleration);
    try std.testing.expectEqual(raw.chain_depth, native.chain_depth);
    try std.testing.expect(native.profile == &profile);
    try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{"--chain-depth=17"})).nativeOptions(null));
    try std.testing.expectEqualDeep(vort.Lz4NativeFrameOptions{}, try (try parse(&.{})).nativeOptions(null));
}
