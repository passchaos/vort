const std = @import("std");
const Harness = @import("fixture.zig").Harness;

const Counts = struct { pairs: usize = 0, different: usize = 0 };
const sample_offsets = [_]usize{ 0, 9, 18, 27, 36, 45, 54, 63 };

fn samplePosition(position: usize) bool {
    for (sample_offsets) |offset| {
        if (position % 64 == offset) return true;
    }
    return false;
}

fn usefulOracle(input_len: usize, different: usize) bool {
    if (input_len < 4) return false;
    return @as(u128, different) * 4 > @as(u128, input_len) - 3;
}

fn usefulSampledOracle(input_len: usize, different: usize) bool {
    if (input_len < 4) return false;
    const positions = @as(u128, input_len) - 3;
    var samples = (positions / 64) * 8;
    const tail = positions % 64;
    for (sample_offsets) |offset| {
        if (@as(u128, offset) < tail) samples += 1;
    }
    return @as(u128, different) * 4 > samples;
}

// Count eligible old predecessors over the completed prefix of an insertion
// pass. The oracle uses byte-slice equality and never calls Admission.record.
fn scan(input: []const u8, three_prev: []const u32, seen: usize, window: usize) Counts {
    var result: Counts = .{};
    const stop = @min(input.len -| 3, @min(three_prev.len, seen));
    for (0..stop) |position| {
        const previous = three_prev[position];
        if (previous == std.math.maxInt(u32)) continue;
        if (position - previous > window) continue;
        result.pairs += 1;
        if (!std.mem.eql(u8, input[position..][0..4], input[previous..][0..4]))
            result.different += 1;
    }
    return result;
}

fn scanSampled(input: []const u8, three_prev: []const u32, seen: usize, window: usize) Counts {
    var result: Counts = .{};
    const stop = @min(input.len -| 3, @min(three_prev.len, seen));
    for (0..stop) |position| {
        if (!samplePosition(position)) continue;
        const previous = three_prev[position];
        if (previous == std.math.maxInt(u32)) continue;
        if (position - previous > window) continue;
        result.pairs += 1;
        if (!std.mem.eql(u8, input[position..][0..4], input[previous..][0..4]))
            result.different += 1;
    }
    return result;
}

fn recordEdges(comptime Codec: type) !void {
    const short = "AAAAA";
    for (0..5) |len| {
        var stats: Codec.Admission = .{ .pairs = 7, .different = 3 };
        stats.record(short[0..len], 0, Codec.empty, 0);
        stats.record(short[0..len], 1, 0, 1);
        try std.testing.expectEqual(@as(usize, 7), stats.pairs);
        try std.testing.expectEqual(@as(usize, 3), stats.different);
    }
    for ([_]usize{ 0, 1, 2 }) |window| {
        var stats: Codec.Admission = .{};
        stats.record(short, 1, 0, window);
        try std.testing.expectEqual(@as(usize, @intFromBool(window >= 1)), stats.pairs);
        try std.testing.expectEqual(@as(usize, 0), stats.different);
    }
    for (0..5) |changed_byte| {
        var input = [_]u8{ 'A', 'B', 'C', 'D', 0xcc, 0xcc, 0xcc, 0xcc, 'A', 'B', 'C', 'D' };
        if (changed_byte < 4) input[8 + changed_byte] ^= 0x20;
        const saved = input;
        for ([_]usize{ 7, 8, 9 }) |window| {
            var stats: Codec.Admission = .{};
            stats.record(&input, 8, 0, window);
            stats.record(&input, 8, Codec.empty, window);
            stats.record(&input, 9, 0, window);
            try std.testing.expectEqual(@as(usize, @intFromBool(window >= 8)), stats.pairs);
            try std.testing.expectEqual(@as(usize, @intFromBool(window >= 8 and changed_byte < 4)), stats.different);
            try std.testing.expectEqualSlices(u8, &saved, &input);
        }
    }
}

fn densityArithmetic(comptime Codec: type) !void {
    for (0..5) |input_len| {
        for (0..5) |different| {
            const stats: Codec.Admission = .{ .pairs = different + 3, .different = different };
            try std.testing.expectEqual(usefulOracle(input_len, different), stats.useful(input_len));
        }
    }
    // Exercise every remainder around the n-3 divisibility boundary, with
    // different one below, exactly at, and one above the integer threshold.
    for (0..65) |whole| {
        for (0..4) |remainder| {
            const input_len = 3 + whole * 4 + remainder;
            for ([_]usize{ whole -| 1, whole, whole + 1 }) |different| {
                const stats: Codec.Admission = .{ .pairs = different + 3, .different = different };
                try std.testing.expectEqual(usefulOracle(input_len, different), stats.useful(input_len));
            }
        }
    }
    const limit = std.math.maxInt(usize);
    for ([_]usize{ 65534, 65535, 65536, 65537, limit - 1, limit }) |input_len| {
        for ([_]usize{ 0, 1, input_len / 4 - 1, input_len / 4, input_len / 4 + 1, limit }) |different| {
            const stats: Codec.Admission = .{ .pairs = limit, .different = different };
            try std.testing.expectEqual(usefulOracle(input_len, different), stats.useful(input_len));
        }
    }
}

fn sampledDensityArithmetic(comptime Codec: type) !void {
    for (0..5) |input_len| {
        for (0..5) |different| {
            const stats: Codec.Admission = .{ .pairs = different + 3, .different = different };
            try std.testing.expectEqual(usefulSampledOracle(input_len, different), stats.usefulSampled(input_len));
        }
    }
    for (0..65) |blocks| {
        for (sample_offsets, 0..) |offset, offset_index| {
            const first_len = blocks * 64 + offset + 4;
            const samples = blocks * 8 + offset_index + 1;
            for ([_]usize{ first_len - 1, first_len, first_len + 1 }) |input_len| {
                for ([_]usize{ samples / 4 -| 1, samples / 4, samples / 4 + 1 }) |different| {
                    const stats: Codec.Admission = .{ .pairs = different + 3, .different = different };
                    try std.testing.expectEqual(usefulSampledOracle(input_len, different), stats.usefulSampled(input_len));
                }
            }
        }
    }
    const limit = std.math.maxInt(usize);
    for ([_]usize{ 8191, 8192, 8193, 65534, 65535, 65536, 65537, limit - 1, limit }) |input_len| {
        for ([_]usize{ 0, 1, input_len / 32 - 1, input_len / 32, input_len / 32 + 1, limit }) |different| {
            const stats: Codec.Admission = .{ .pairs = limit, .different = different };
            try std.testing.expectEqual(usefulSampledOracle(input_len, different), stats.usefulSampled(input_len));
        }
    }
}

fn smallThreeHash(input: []const u8, position: usize, head_size: usize) ?usize {
    _ = head_size;
    if (input.len - position < 3) return null;
    const value = @as(u32, input[position]) |
        (@as(u32, input[position + 1]) << 8) |
        (@as(u32, input[position + 2]) << 16);
    return value % 7;
}

fn builderStats(comptime Codec: type, input: []const u8, reference: []const u32, window: usize) !void {
    const allocator = std.testing.allocator;
    var head: std.ArrayList(u32) = .empty;
    defer head.deinit(allocator);
    var prev: std.ArrayList(u32) = .empty;
    defer prev.deinit(allocator);
    try head.resize(allocator, 64);
    try prev.resize(allocator, input.len);
    @memset(head.items, 0xfedc_ba98);
    @memset(prev.items, 0xfedc_ba98);
    var initialized: [1]u64 = @splat(std.math.maxInt(u64));
    const observed = try Codec.buildThree(true, 64, allocator, input, &head, &prev, &initialized, window, smallThreeHash);
    const expected = scanSampled(input, reference, reference.len, window);
    try std.testing.expectEqual(expected.pairs, observed.pairs);
    try std.testing.expectEqual(expected.different, observed.different);
    try std.testing.expectEqual(usefulSampledOracle(input.len, expected.different), observed.usefulSampled(input.len));
    try std.testing.expectEqualSlices(u32, reference[0..input.len -| 2], prev.items[0..input.len -| 2]);
    for (prev.items[input.len -| 2..]) |tail|
        try std.testing.expectEqual(@as(u32, 0xfedc_ba98), tail);
    const unobserved = try Codec.buildThree(false, 64, allocator, input, &head, &prev, &initialized, window, smallThreeHash);
    try std.testing.expectEqual(@as(usize, 0), unobserved.pairs);
    try std.testing.expectEqual(@as(usize, 0), unobserved.different);
    try std.testing.expectEqualSlices(u32, reference[0..input.len -| 2], prev.items[0..input.len -| 2]);
}

fn constructionStats(comptime Codec: type, input: []const u8, mode: Harness(Codec).Mode) !void {
    const H = Harness(Codec);
    var fixture = try H.Fixture.init(input, mode);
    defer fixture.deinit();
    for ([_]usize{ 0, 1, 7, input.len -| 1, input.len, input.len + 1 }) |window| {
        var stats: Codec.Admission = .{};
        var sampled: Codec.Admission = .{};
        for (0..input.len -| 2) |position| {
            stats.record(input, position, fixture.three_prev[position], window);
            if (samplePosition(position)) sampled.record(input, position, fixture.three_prev[position], window);
            const expected = scan(input, fixture.three_prev, position + 1, window);
            try std.testing.expectEqual(expected.pairs, stats.pairs);
            try std.testing.expectEqual(expected.different, stats.different);
            const expected_sampled = scanSampled(input, fixture.three_prev, position + 1, window);
            try std.testing.expectEqual(expected_sampled.pairs, sampled.pairs);
            try std.testing.expectEqual(expected_sampled.different, sampled.different);
        }
        const final = scan(input, fixture.three_prev, fixture.three_prev.len, window);
        try std.testing.expectEqual(final.pairs, stats.pairs);
        try std.testing.expectEqual(final.different, stats.different);
        try std.testing.expectEqual(usefulOracle(input.len, final.different), stats.useful(input.len));
        const final_sampled = scanSampled(input, fixture.three_prev, fixture.three_prev.len, window);
        try std.testing.expectEqual(final_sampled.pairs, sampled.pairs);
        try std.testing.expectEqual(final_sampled.different, sampled.different);
        try std.testing.expectEqual(usefulSampledOracle(input.len, final_sampled.different), sampled.usefulSampled(input.len));
        if (mode == .tiny) try builderStats(Codec, input, fixture.three_prev, window);
        try std.testing.expectEqualSlices(u8, fixture.input, input);
        try fixture.expectImmutable();
    }
}

pub fn check(comptime Codec: type) !void {
    try recordEdges(Codec);
    try densityArithmetic(Codec);
    try sampledDensityArithmetic(Codec);
    for ([_][]const u8{
        "",                 "a",         "ab",                                               "abc", "abcd", "aaaaa",
        "AAAQAAARAAAQAAAS", "AAAQ" ** 8, "source prefixes vary alpha beta gamma 0123456789",
    }) |input| {
        try constructionStats(Codec, input, .exact);
        try constructionStats(Codec, input, .tiny);
    }
    const repeated: [128]u8 = @splat('A');
    try constructionStats(Codec, &repeated, .exact);
    var prng = std.Random.DefaultPrng.init(0xada1_5510_0c0a_2026);
    const random = prng.random();
    for (0..64) |case_index| {
        var storage: [96]u8 = undefined;
        const input = storage[0..random.uintLessThan(usize, storage.len + 1)];
        random.bytes(input);
        if (case_index % 3 == 0) {
            for (input) |*byte| byte.* &= 1;
        }
        try constructionStats(Codec, input, if (case_index & 1 == 0) .exact else .tiny);
    }
}
