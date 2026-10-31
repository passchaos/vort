const std = @import("std");
const Codec = @import("repeated_pattern.zig");
const a = std.testing.allocator;

// Independent scalar reference retains modulo-to-original-anchor comparison.
// It has neither target-cost bounds, shifted comparisons nor a period cache.
fn moduloReference(block: []const u8, start_min: usize, end: usize) ?Codec.Segment {
    if (end > block.len or block.len < 8 or start_min >= end or end - start_min < 8) return null;
    var best: ?Codec.Segment = null;
    var start = start_min;
    var examined: usize = 0;
    while (start < end and examined <= 48) : ({
        start += 1;
        examined += 1;
    }) {
        if (end - start < 8) break;
        const largest_period = @min((end - start) / 2, @as(usize, 64));
        var period: usize = 2;
        while (period <= largest_period) : (period += 1) {
            var index = start + period;
            while (index < end and block[index] == block[start + (index - start) % period]) : (index += 1) {}
            const match_len = index - start - period;
            if (match_len < 3) continue;
            if (best == null or match_len > best.?.match_len) best = .{ .start = start, .period = period, .match_len = match_len, .tail_len = end - index };
        }
    }
    return best;
}

fn compare(block: []const u8, start_min: usize, end: usize) !void {
    const before = try a.dupe(u8, block);
    defer a.free(before);
    const expected = moduloReference(block, start_min, end);
    const actual = Codec.findIn(block, start_min, end);
    try std.testing.expectEqualDeep(expected, actual);
    try std.testing.expectEqualSlices(u8, before, block);
    if (actual) |segment| {
        try std.testing.expect(segment.start >= start_min);
        try std.testing.expect(segment.period >= 2 and segment.period <= 64);
        try std.testing.expectEqual(end, segment.start + segment.period + segment.match_len + segment.tail_len);
        try std.testing.expect(segment.match_len >= 3);
    }
}

test "Zstd repeated pattern cached detector equals modulo oracle for all tiny ranges" {
    var payload: [14]u8 = undefined;
    var cases: usize = 0;
    for (0..@as(usize, 1) << 14) |pattern| {
        for (&payload, 0..) |*byte, index| byte.* = @intCast((pattern >> @intCast(index)) & 1);
        for ([_]usize{ 0, 1, 3, 6, 14 }) |start| for ([_]usize{ 0, 7, 8, 9, 11, 14 }) |end| {
            try compare(&payload, start, end);
            cases += 1;
        };
    }
    for (0..15) |length| for (0..length + 1) |start| for (0..length + 1) |end| {
        @memset(&payload, 'a');
        try compare(payload[0..length], start, end);
        cases += 1;
    };
    try std.testing.expectEqual(@as(?Codec.Segment, null), Codec.findIn("abcdefgh", std.math.maxInt(usize), 8));
    try std.testing.expectEqual(@as(?Codec.Segment, null), Codec.findIn("abcdefgh", 0, std.math.maxInt(usize)));
    std.debug.print("repeated_pattern_tiny_range_cases={d} all_segment_fields+immutable=equal\n", .{cases});
}

test "Zstd repeated pattern periods two through sixty four prefixes tails and interrupted runs" {
    var payload: [1024]u8 = undefined;
    var cases: usize = 0;
    for (2..65) |period| for ([_]usize{ 0, 1, 7, 47, 48, 49, 64 }) |prefix| {
        for (&payload, 0..) |*byte, index| byte.* = @truncate((index * 73 + 19) % 251);
        const end = prefix + period * 7 + 11;
        for (prefix..end - 11) |index| payload[index] = @intCast(1 + (index - prefix) % period);
        for ([_]usize{ prefix + period + 2, prefix + period + 3, prefix + period * 3, end - 12, end - 11 }) |interrupt| {
            const old = payload[interrupt];
            payload[interrupt] = 255;
            for ([_]usize{ 0, prefix, @min(prefix + 1, end) }) |start| for ([_]usize{ end - 11, end - 3, end }) |limit| {
                try compare(&payload, start, limit);
                cases += 1;
            };
            payload[interrupt] = old;
        }
    };
    std.debug.print("repeated_pattern_period_prefix_tail_cases={d} period2..64+scan48boundary+firstmismatch=equal\n", .{cases});
}

test "Zstd repeated pattern long runs overlap cache and strict ties preserve first winner" {
    var payload: [8192]u8 = undefined;
    var cases: usize = 0;
    for ([_]usize{ 2, 3, 7, 16, 31, 64 }) |period| for ([_]usize{ 0, 17, 48 }) |prefix| {
        for (&payload, 0..) |*byte, index| byte.* = if (index < prefix) 255 else @intCast((index - prefix) % period);
        for ([_]usize{ 1024, 4096, 8192 }) |end| {
            try compare(&payload, 0, end);
            try compare(&payload, prefix, end);
            payload[end - 1] = 254;
            try compare(&payload, 0, end);
            payload[end - 1] = @intCast((end - 1 - prefix) % period);
            cases += 3;
        }
    };
    @memset(&payload, 'a');
    const all_same = Codec.findIn(&payload, 0, payload.len).?;
    try std.testing.expectEqual(@as(usize, 0), all_same.start);
    try std.testing.expectEqual(@as(usize, 2), all_same.period);
    try std.testing.expectEqual(payload.len - 2, all_same.match_len);
    const shifted_same = Codec.findIn(&payload, 48, payload.len).?;
    try std.testing.expectEqual(@as(usize, 48), shifted_same.start);
    try std.testing.expectEqual(@as(usize, 2), shifted_same.period);
    // Two separated runs with equal lengths must keep the first start/period.
    @memset(&payload, 255);
    @memcpy(payload[0..8], "abababab");
    @memcpy(payload[12..20], "cdcdcdcd");
    try compare(&payload, 0, 24);
    const tied = Codec.findIn(&payload, 0, 24).?;
    try std.testing.expectEqual(@as(usize, 0), tied.start);
    try std.testing.expectEqual(@as(usize, 2), tied.period);
    try std.testing.expectEqual(@as(usize, 6), tied.match_len);
    std.debug.print("repeated_pattern_long_cache_cases={d} overlap_and_first_start_period_ties=pass\n", .{cases});
}

test "Zstd repeated pattern random all subranges preserve exact segment" {
    var payload: [192]u8 = undefined;
    var random: u32 = 0xa8b95e37;
    var cases: usize = 0;
    for (0..24) |seed| {
        for (&payload) |*byte| {
            random = random *% 1664525 +% 1013904223;
            byte.* = @truncate(random >> (if (seed % 2 == 0) @as(u5, 24) else 30));
        }
        if (seed % 3 == 0) {
            for (53..139) |index| payload[index] = payload[index - 7];
        }
        for ([_]usize{ 0, 1, 17, 48, 49, 64, 129, 184, 192 }) |start| for (0..193) |end| {
            try compare(&payload, start, end);
            cases += 1;
        };
    }
    std.debug.print("repeated_pattern_random_subrange_cases={d} no_cache_false_extension=pass\n", .{cases});
}
