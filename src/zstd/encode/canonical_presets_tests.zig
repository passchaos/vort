//! Expected cells were frozen from ZSTD_getCParams() through the local
//! full-feature Zstd 1.6.0 ABI, independently of the production table.
//! Reference clevels.h SHA256: d764daa89b7a636d26fe96ff3536c5075e9867fb5dddbf8c9d57023a8ff4a155
//! Reference library SHA256: c76f4c4457df67a5e0c7bb6bb4f58b9857cf4f2cdd7925bfb9345daac4e6b83e
//! Anchors: source hints 0 (unknown), 262144, 131072, 16384; levels 0...22.
//! ABI tuple order: window, chain, hash, search, minMatch, targetLength, strategy.
//! Reference strategy IDs are 1...9; they are not Vort enum ordinals.
const std = @import("std");
const canonical = @import("canonical_presets.zig");
const controls = @import("controls.zig");

fn expectParameters(expected: [7]u32, actual: canonical.Parameters) !void {
    try std.testing.expectEqual(expected[0], actual.window_log);
    try std.testing.expectEqual(expected[1], actual.chain_log);
    try std.testing.expectEqual(expected[2], actual.hash_log);
    try std.testing.expectEqual(expected[3], actual.search_log);
    try std.testing.expectEqual(expected[4], actual.min_match);
    try std.testing.expectEqual(expected[5], actual.target_length);
    const strategy: controls.Strategy = switch (expected[6]) {
        1 => .fast,
        2 => .double_fast,
        3 => .greedy,
        4 => .lazy,
        5 => .lazy2,
        6 => .btlazy2,
        7 => .btopt,
        8 => .btultra,
        9 => .btultra2,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expectEqual(strategy, actual.strategy);
}

const anchors = [_]u64{ 0, 262144, 131072, 16384 };
const cells = [4][23][7]u32{
    .{
        .{ 21, 16, 17, 1, 5, 0, 2 },
        .{ 19, 13, 14, 1, 7, 0, 1 },
        .{ 20, 15, 16, 1, 6, 0, 1 },
        .{ 21, 16, 17, 1, 5, 0, 2 },
        .{ 21, 18, 18, 1, 5, 0, 2 },
        .{ 21, 18, 19, 3, 5, 2, 3 },
        .{ 21, 18, 19, 3, 5, 4, 4 },
        .{ 21, 19, 20, 4, 5, 8, 4 },
        .{ 21, 19, 20, 4, 5, 16, 5 },
        .{ 22, 20, 21, 4, 5, 16, 5 },
        .{ 22, 21, 22, 5, 5, 16, 5 },
        .{ 22, 21, 22, 6, 5, 16, 5 },
        .{ 22, 22, 23, 6, 5, 32, 5 },
        .{ 22, 22, 22, 4, 5, 32, 6 },
        .{ 22, 22, 23, 5, 5, 32, 6 },
        .{ 22, 23, 23, 6, 5, 32, 6 },
        .{ 22, 22, 22, 5, 5, 48, 7 },
        .{ 23, 23, 22, 5, 4, 64, 7 },
        .{ 23, 23, 22, 6, 3, 64, 8 },
        .{ 23, 24, 22, 7, 3, 256, 9 },
        .{ 25, 25, 23, 7, 3, 256, 9 },
        .{ 26, 26, 24, 7, 3, 512, 9 },
        .{ 27, 27, 25, 9, 3, 999, 9 },
    },
    .{
        .{ 18, 16, 16, 1, 4, 0, 2 },
        .{ 18, 13, 14, 1, 6, 0, 1 },
        .{ 18, 14, 14, 1, 5, 0, 2 },
        .{ 18, 16, 16, 1, 4, 0, 2 },
        .{ 18, 16, 17, 3, 5, 2, 3 },
        .{ 18, 17, 18, 5, 5, 2, 3 },
        .{ 18, 18, 19, 3, 5, 4, 4 },
        .{ 18, 18, 19, 4, 4, 4, 4 },
        .{ 18, 18, 19, 4, 4, 8, 5 },
        .{ 18, 18, 19, 5, 4, 8, 5 },
        .{ 18, 18, 19, 6, 4, 8, 5 },
        .{ 18, 18, 19, 5, 4, 12, 6 },
        .{ 18, 19, 19, 7, 4, 12, 6 },
        .{ 18, 18, 19, 4, 4, 16, 7 },
        .{ 18, 18, 19, 4, 3, 32, 7 },
        .{ 18, 18, 19, 6, 3, 128, 7 },
        .{ 18, 19, 19, 6, 3, 128, 8 },
        .{ 18, 19, 19, 8, 3, 256, 8 },
        .{ 18, 19, 19, 6, 3, 128, 9 },
        .{ 18, 19, 19, 8, 3, 256, 9 },
        .{ 18, 19, 19, 10, 3, 512, 9 },
        .{ 18, 19, 19, 12, 3, 512, 9 },
        .{ 18, 19, 19, 13, 3, 999, 9 },
    },
    .{
        .{ 17, 15, 16, 2, 5, 0, 2 },
        .{ 17, 12, 13, 1, 6, 0, 1 },
        .{ 17, 13, 15, 1, 5, 0, 1 },
        .{ 17, 15, 16, 2, 5, 0, 2 },
        .{ 17, 17, 17, 2, 4, 0, 2 },
        .{ 17, 16, 17, 3, 4, 2, 3 },
        .{ 17, 16, 17, 3, 4, 4, 4 },
        .{ 17, 16, 17, 3, 4, 8, 5 },
        .{ 17, 16, 17, 4, 4, 8, 5 },
        .{ 17, 16, 17, 5, 4, 8, 5 },
        .{ 17, 16, 17, 6, 4, 8, 5 },
        .{ 17, 17, 17, 5, 4, 8, 6 },
        .{ 17, 18, 17, 7, 4, 12, 6 },
        .{ 17, 18, 17, 3, 4, 12, 7 },
        .{ 17, 18, 17, 4, 3, 32, 7 },
        .{ 17, 18, 17, 6, 3, 256, 7 },
        .{ 17, 18, 17, 6, 3, 128, 8 },
        .{ 17, 18, 17, 8, 3, 256, 8 },
        .{ 17, 18, 17, 10, 3, 512, 8 },
        .{ 17, 18, 17, 5, 3, 256, 9 },
        .{ 17, 18, 17, 7, 3, 512, 9 },
        .{ 17, 18, 17, 9, 3, 512, 9 },
        .{ 17, 18, 17, 11, 3, 999, 9 },
    },
    .{
        .{ 14, 14, 15, 2, 4, 0, 2 },
        .{ 14, 14, 15, 1, 5, 0, 1 },
        .{ 14, 14, 15, 1, 4, 0, 1 },
        .{ 14, 14, 15, 2, 4, 0, 2 },
        .{ 14, 14, 14, 4, 4, 2, 3 },
        .{ 14, 14, 14, 3, 4, 4, 4 },
        .{ 14, 14, 14, 4, 4, 8, 5 },
        .{ 14, 14, 14, 6, 4, 8, 5 },
        .{ 14, 14, 14, 8, 4, 8, 5 },
        .{ 14, 15, 14, 5, 4, 8, 6 },
        .{ 14, 15, 14, 9, 4, 8, 6 },
        .{ 14, 15, 14, 3, 4, 12, 7 },
        .{ 14, 15, 14, 4, 3, 24, 7 },
        .{ 14, 15, 14, 5, 3, 32, 8 },
        .{ 14, 15, 15, 6, 3, 64, 8 },
        .{ 14, 15, 15, 7, 3, 256, 8 },
        .{ 14, 15, 15, 5, 3, 48, 9 },
        .{ 14, 15, 15, 6, 3, 128, 9 },
        .{ 14, 15, 15, 7, 3, 256, 9 },
        .{ 14, 15, 15, 8, 3, 256, 9 },
        .{ 14, 15, 15, 8, 3, 512, 9 },
        .{ 14, 15, 15, 9, 3, 512, 9 },
        .{ 14, 15, 15, 10, 3, 999, 9 },
    },
};

const Boundary = struct { level: c_int, size: u64, dictionary: u64, expected: [7]u32 };
const boundaries = [_]Boundary{
    .{ .level = 0, .size = 4096, .dictionary = 0, .expected = .{ 12, 12, 13, 2, 4, 0, 2 } },
    .{ .level = 13, .size = 0, .dictionary = 0, .expected = .{ 22, 22, 22, 4, 5, 32, 6 } },
    .{ .level = 13, .size = 1, .dictionary = 0, .expected = .{ 10, 7, 7, 5, 3, 32, 8 } },
    .{ .level = 13, .size = 63, .dictionary = 0, .expected = .{ 10, 7, 7, 5, 3, 32, 8 } },
    .{ .level = 13, .size = 64, .dictionary = 0, .expected = .{ 10, 7, 7, 5, 3, 32, 8 } },
    .{ .level = 13, .size = 65, .dictionary = 0, .expected = .{ 10, 8, 8, 5, 3, 32, 8 } },
    .{ .level = 13, .size = 512, .dictionary = 0, .expected = .{ 10, 10, 10, 5, 3, 32, 8 } },
    .{ .level = 13, .size = 513, .dictionary = 0, .expected = .{ 10, 11, 11, 5, 3, 32, 8 } },
    .{ .level = 9, .size = 16383, .dictionary = 0, .expected = .{ 14, 15, 14, 5, 4, 8, 6 } },
    .{ .level = 9, .size = 16384, .dictionary = 0, .expected = .{ 14, 15, 14, 5, 4, 8, 6 } },
    .{ .level = 9, .size = 16385, .dictionary = 0, .expected = .{ 15, 15, 16, 5, 4, 8, 5 } },
    .{ .level = 18, .size = 131071, .dictionary = 0, .expected = .{ 17, 18, 17, 10, 3, 512, 8 } },
    .{ .level = 18, .size = 131072, .dictionary = 0, .expected = .{ 17, 18, 17, 10, 3, 512, 8 } },
    .{ .level = 18, .size = 131073, .dictionary = 0, .expected = .{ 18, 19, 19, 6, 3, 128, 9 } },
    .{ .level = 13, .size = 262143, .dictionary = 0, .expected = .{ 18, 18, 19, 4, 4, 16, 7 } },
    .{ .level = 13, .size = 262144, .dictionary = 0, .expected = .{ 18, 18, 19, 4, 4, 16, 7 } },
    .{ .level = 13, .size = 262145, .dictionary = 0, .expected = .{ 19, 20, 20, 4, 5, 32, 6 } },
    .{ .level = 13, .size = 0, .dictionary = 15885, .expected = .{ 14, 15, 14, 5, 3, 32, 8 } },
    .{ .level = 13, .size = 0, .dictionary = 15886, .expected = .{ 17, 18, 17, 3, 4, 12, 7 } },
    .{ .level = 13, .size = 1000, .dictionary = 15000, .expected = .{ 14, 15, 14, 5, 3, 32, 8 } },
    .{ .level = 13, .size = 1000, .dictionary = 16000, .expected = .{ 15, 16, 16, 3, 4, 12, 7 } },
    .{ .level = 22, .size = 1, .dictionary = 1000, .expected = .{ 10, 11, 11, 10, 3, 999, 9 } },
    .{ .level = 22, .size = 1024, .dictionary = 1024, .expected = .{ 11, 12, 12, 10, 3, 999, 9 } },
    .{ .level = 22, .size = 1048576, .dictionary = 2097152, .expected = .{ 22, 23, 23, 9, 3, 999, 9 } },
    .{ .level = 22, .size = 0, .dictionary = 1, .expected = .{ 14, 15, 15, 10, 3, 999, 9 } },
    .{ .level = 22, .size = 0, .dictionary = 16384, .expected = .{ 17, 18, 17, 11, 3, 999, 9 } },
    .{ .level = 22, .size = 0, .dictionary = 131072, .expected = .{ 18, 19, 19, 13, 3, 999, 9 } },
    .{ .level = 22, .size = 0, .dictionary = 262144, .expected = .{ 27, 27, 25, 9, 3, 999, 9 } },
    .{ .level = 22, .size = 1073741824, .dictionary = 0, .expected = .{ 27, 27, 25, 9, 3, 999, 9 } },
    .{ .level = 22, .size = 1073741825, .dictionary = 0, .expected = .{ 27, 27, 25, 9, 3, 999, 9 } },
    .{ .level = 22, .size = 2147483648, .dictionary = 0, .expected = .{ 27, 27, 25, 9, 3, 999, 9 } },
    .{ .level = 22, .size = 0, .dictionary = 1073741824, .expected = .{ 27, 27, 25, 9, 3, 999, 9 } },
    .{ .level = 22, .size = 0, .dictionary = 2147483648, .expected = .{ 27, 27, 25, 9, 3, 999, 9 } },
    .{ .level = 22, .size = 0, .dictionary = 4294967295, .expected = .{ 27, 27, 25, 9, 3, 999, 9 } },
    .{ .level = -1, .size = 1, .dictionary = 0, .expected = .{ 10, 6, 7, 1, 5, 1, 1 } },
    .{ .level = -13, .size = 65536, .dictionary = 0, .expected = .{ 16, 12, 12, 1, 5, 13, 1 } },
    .{ .level = -131072, .size = 0, .dictionary = 0, .expected = .{ 19, 12, 13, 1, 6, 131072, 1 } },
    .{ .level = -131072, .size = 16384, .dictionary = 0, .expected = .{ 14, 12, 13, 1, 5, 131072, 1 } },
    .{ .level = -131072, .size = 131072, .dictionary = 0, .expected = .{ 17, 12, 12, 1, 5, 131072, 1 } },
    .{ .level = -131072, .size = 262144, .dictionary = 0, .expected = .{ 18, 12, 13, 1, 5, 131072, 1 } },
};

test "Zstd canonical presets all ninety two independent ABI cells" {
    for (anchors, cells) |size, levels| {
        for (levels, 0..) |expected, level| {
            const actual = try canonical.resolveCanonicalCompressionParameters(@intCast(level), size, 0);
            try expectParameters(expected, actual);
            try std.testing.expect(actual.window_log >= 10 and actual.window_log <= canonical.window_log_max);
            try std.testing.expect(actual.hash_log >= 6 and actual.hash_log <= canonical.hash_log_max);
            try std.testing.expect(actual.chain_log >= 6 and actual.chain_log <= canonical.chain_log_max);
        }
    }
}

test "Zstd canonical presets independent size dictionary and negative boundary queries" {
    for (boundaries) |query| {
        const dictionary = std.math.cast(usize, query.dictionary) orelse continue;
        const actual = try canonical.resolve(.{ .level = query.level, .source_size_hint = query.size, .dictionary_size = dictionary });
        try expectParameters(query.expected, actual);
    }
}

test "Zstd canonical presets default zero and unknown hints remain explicit" {
    const default = try canonical.resolve(.{});
    try expectParameters(cells[0][3], default);
    try std.testing.expectEqualDeep(default, try canonical.resolve(.{ .level = 0 }));
    try std.testing.expectEqualDeep(default, try canonical.resolve(.{ .source_size_hint = std.math.maxInt(u64) }));
    for ([_]usize{ 1, 15885, 15886, 131072 }) |dictionary| {
        const zero = try canonical.resolve(.{ .level = 13, .dictionary_size = dictionary });
        const sentinel = try canonical.resolve(.{ .level = 13, .dictionary_size = dictionary, .source_size_hint = std.math.maxInt(u64) });
        try std.testing.expectEqualDeep(zero, sentinel);
    }
    try std.testing.expectEqual(@as(u32, 10), (try canonical.resolve(.{ .level = 13, .source_size_hint = 1 })).window_log);
    try std.testing.expectEqual(@as(u32, 7), (try canonical.resolve(.{ .level = 13, .source_size_hint = 1 })).hash_log);
}

test "Zstd canonical presets reject Vort level range and overflowing logical hints" {
    for ([_]c_int{ -131073, 23, std.math.minInt(c_int), std.math.maxInt(c_int) }) |level|
        try std.testing.expectError(error.InvalidBlockPlan, canonical.resolve(.{ .level = level }));
    try std.testing.expectError(error.IntegerOverflow, canonical.resolve(.{ .source_size_hint = std.math.maxInt(u64) - 1, .dictionary_size = 2 }));
    if (comptime @bitSizeOf(usize) >= 64) {
        try std.testing.expectError(error.IntegerOverflow, canonical.resolve(.{ .dictionary_size = std.math.maxInt(usize) }));
        try std.testing.expectError(error.IntegerOverflow, canonical.resolve(.{ .source_size_hint = 1, .dictionary_size = std.math.maxInt(usize) - 2 }));
    }
}

test "Zstd canonical presets negative targets are Fast acceleration" {
    for ([_]c_int{ -1, -13, -131072 }) |level| {
        const actual = try canonical.resolve(.{ .level = level });
        try std.testing.expectEqual(controls.Strategy.fast, actual.strategy);
        try std.testing.expectEqual(@as(u32, @intCast(-level)), actual.target_length);
        try std.testing.expectEqual(@as(?u32, @intCast(-level)), actual.fastAcceleration());
        try std.testing.expectEqual(@as(?controls.HqOptions, null), try actual.hqOptions());
    }
    const ordinary = try canonical.resolve(.{ .level = 1 });
    try std.testing.expectEqual(@as(?u32, null), ordinary.fastAcceleration());
}

test "Zstd canonical presets HQ conversion transfers only supported controls" {
    for (anchors, cells) |size, levels| {
        for (levels, 0..) |expected, level| {
            const parameters = try canonical.resolve(.{ .level = @intCast(level), .source_size_hint = size });
            const snapshot = parameters;
            const converted = try parameters.hqOptions();
            if (expected[6] >= 5) {
                const hq = converted orelse return error.TestUnexpectedResult;
                try std.testing.expectEqual(@as(u32, 1) << @intCast(expected[3]), hq.search_depth);
                try std.testing.expectEqual(expected[5], hq.nice_len);
                try std.testing.expectEqual(@as(u8, @intCast(expected[4])), hq.min_match);
                try std.testing.expectEqual(std.math.maxInt(usize), hq.max_working_memory);
                try hq.validate();
            } else try std.testing.expectEqual(@as(?controls.HqOptions, null), converted);
            try std.testing.expectEqualDeep(snapshot, parameters);
        }
    }
    var manual = try canonical.resolve(.{ .level = 22 });
    manual.target_length = 0;
    try std.testing.expectEqual(@as(u32, 128), (try manual.hqOptions()).?.nice_len);
    manual.search_log = 17;
    try std.testing.expectError(error.InvalidBlockPlan, manual.hqOptions());
    manual.search_log = 16;
    try std.testing.expectEqual(@as(u32, 65536), (try manual.hqOptions()).?.search_depth);
    manual.target_length = 2;
    try std.testing.expectError(error.InvalidBlockPlan, manual.hqOptions());
}

test "Zstd canonical presets primary hash hints differ from reference match minima" {
    const fast = try canonical.resolve(.{ .level = 1 });
    try std.testing.expectEqual(@as(u32, 7), fast.min_match);
    try std.testing.expectEqual(@as(u32, 4), fast.referenceMinimumMatch());
    const optimized = try canonical.resolve(.{ .level = 16 });
    try std.testing.expectEqual(@as(u32, 5), optimized.min_match);
    try std.testing.expectEqual(@as(u32, 4), optimized.referenceMinimumMatch());
    const ultra = try canonical.resolve(.{ .level = 18 });
    try std.testing.expectEqual(@as(u32, 3), ultra.referenceMinimumMatch());
}
