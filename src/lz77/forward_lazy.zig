//! Optional zlib-style one-position lazy-search policy.
const std = @import("std");

pub const Tuning = struct {
    good_length: usize = 32,
    max_lazy: usize = 258,
};

pub fn probeOptions(options: anytype, current_length: usize) ?@TypeOf(options) {
    const tuning = options.lazy_tuning orelse return options;
    if (current_length >= tuning.max_lazy) return null;
    const maximum = @max(@as(usize, 3), @min(options.max_match, 258));
    const required = std.math.add(usize, current_length, options.lazy_min_gain) catch return null;
    if (required > maximum) return null;
    var probe = options;
    // Only a strictly better lazy result is useful. The regular matcher still
    // supplies exact bounded lengths and its normal closest-on-tie ordering.
    probe.min_match = @max(options.min_match, required);
    if (current_length >= tuning.good_length and options.max_chain != 0)
        probe.max_chain = @max(@as(usize, 1), options.max_chain / 4);
    return probe;
}

test "forward lazy policy preserves legacy settings and level-eight search limits" {
    const Options = struct {
        lazy_tuning: ?Tuning = null,
        max_match: usize = 258,
        min_match: usize = 3,
        lazy_min_gain: usize = 1,
        max_chain: usize = 1024,
    };
    const legacy = Options{};
    try std.testing.expectEqualDeep(legacy, probeOptions(legacy, 258).?);
    var level8 = legacy;
    level8.lazy_tuning = .{ .good_length = 32, .max_lazy = 128 };
    try std.testing.expectEqual(@as(usize, 32), probeOptions(level8, 31).?.min_match);
    try std.testing.expectEqual(@as(usize, 1024), probeOptions(level8, 31).?.max_chain);
    try std.testing.expectEqual(@as(usize, 33), probeOptions(level8, 32).?.min_match);
    try std.testing.expectEqual(@as(usize, 256), probeOptions(level8, 32).?.max_chain);
    try std.testing.expect(probeOptions(level8, 128) == null);
    level8.lazy_min_gain = std.math.maxInt(usize);
    try std.testing.expect(probeOptions(level8, 3) == null);
}
