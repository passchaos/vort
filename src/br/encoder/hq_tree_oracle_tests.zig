const std = @import("std");
const tree = @import("hq_tree.zig");
const scalar = @import("hq_tree_oracle_tests/oracle.zig");
const allocator = std.testing.allocator;

test {
    _ = @import("hq_tree_oracle_tests/resources_tests.zig");
}

fn checkBest(data: scalar.Data, position: usize, actual: tree.Matches) !void {
    try data.validateFrontier(position, actual.slice());
    const expected = data.best(position);
    try std.testing.expectEqual(expected.length, actual.best().length);
    if (expected.length >= 2) try std.testing.expectEqual(expected.distance, actual.best().distance);
    var iterator = actual.iterator();
    for (actual.slice()) |match| try std.testing.expectEqualDeep(match, iterator.next().?);
    try std.testing.expect(iterator.next() == null);
}

test "Brotli HQ BT oracle tiny random repetitive best prefixes and two three byte anchors" {
    var random: [192]u8 = undefined;
    scalar.random(&random, 0x762890ab, 8);
    const fixtures = [_]struct { history: []const u8, input: []const u8 }{
        .{ .history = "", .input = "" },
        .{ .history = "", .input = "x" },
        .{ .history = "abX", .input = "abY" },
        .{ .history = "abcX", .input = "abcY" },
        .{ .history = "", .input = "abcdabcdXabcdY" },
        .{ .history = "a", .input = "a" ** 96 },
        .{ .history = random[0..32], .input = random[32..] },
    };
    for (fixtures) |fixture| {
        const source = try tree.Source.init(fixture.history, fixture.input, 10, fixture.history.len);
        const options: tree.HqOptions = .{ .search_depth = 4096, .nice_len = @intCast(@max(2, fixture.input.len + 1)) };
        var matcher = try tree.Matcher.init(allocator, source, options, null);
        defer matcher.deinit(allocator);
        const data: scalar.Data = .{ .history = fixture.history, .input = fixture.input, .window = 1008, .frame_offset = fixture.history.len };
        for (0..fixture.input.len) |position| {
            const actual = try matcher.getMatches();
            try checkBest(data, position, actual);
            if (position == 0 and fixture.history.len == 3) try std.testing.expectEqual(@as(usize, 2), actual.best().length);
            if (position == 0 and fixture.history.len == 4) try std.testing.expectEqual(@as(usize, 3), actual.best().length);
        }
        try std.testing.expectEqual(fixture.input.len, matcher.position());
    }
}

test "Brotli HQ BT oracle tree key is 128 but full copy exceeds nice and key lengths" {
    const input = "abcd" ++ "A" ** 596;
    const history = input ++ "abcZ" ** 32;
    const source = try tree.Source.init(history, input, 10, history.len);
    var profile: tree.HqProfile = .{};
    // The nearest two-/three-byte anchor only matches abc. Its chain depth is
    // one, so the older abcd root must provide the 600-byte BT match itself.
    var matcher = try tree.Matcher.init(allocator, source, tree.HqOptions{ .search_depth = 1, .nice_len = 16 }, &profile);
    defer matcher.deinit(allocator);
    const previous_nodes = profile.tree_nodes;
    const actual = try matcher.getMatches();
    const data: scalar.Data = .{ .history = history, .input = input, .window = 1008, .frame_offset = history.len };
    try checkBest(data, 0, actual);
    try std.testing.expectEqual(@as(usize, 600), actual.best().length);
    try std.testing.expect(actual.best().length > tree.store_lookahead and actual.best().length > 16);
    try std.testing.expect(profile.tree_nodes > previous_nodes);
}

test "Brotli HQ BT oracle complete seventy thousand history and frontier beyond 256 records" {
    {
        const history = try allocator.alloc(u8, 70_000);
        defer allocator.free(history);
        @memset(history, 255);
        for (history[0..64], 0..) |*byte, i| byte.* = @intCast(i);
        var input: [65]u8 = undefined;
        @memcpy(input[0..64], history[0..64]);
        input[64] = 200;
        var profile: tree.HqProfile = .{};
        var matcher = try tree.Matcher.init(allocator, try tree.Source.init(history, &input, 17, history.len), tree.HqOptions{ .search_depth = 4096, .nice_len = 66 }, &profile);
        defer matcher.deinit(allocator);
        const actual = try matcher.getMatches();
        try checkBest(.{ .history = history, .input = &input, .window = 131056, .frame_offset = history.len }, 0, actual);
        try std.testing.expectEqual(@as(usize, 70_000), actual.best().distance);
        try std.testing.expectEqual(@as(u64, 70_000), profile.history_seed_positions);
    }
    {
        var input: [301]u8 = undefined;
        @memcpy(input[0..3], &[_]u8{ 1, 2, 3 });
        scalar.random(input[3..300], 0x734581, 200);
        for (input[3..300]) |*byte| byte.* += 4;
        input[300] = 254;
        const history = try scalar.increasingPrefixes(allocator, input[0..300]);
        defer allocator.free(history);
        var matcher = try tree.Matcher.init(allocator, try tree.Source.init(history, &input, 16, history.len), tree.HqOptions{ .search_depth = 65536, .nice_len = 301 }, null);
        defer matcher.deinit(allocator);
        const actual = try matcher.getMatches();
        try checkBest(.{ .history = history, .input = &input, .window = 65520, .frame_offset = history.len }, 0, actual);
        try std.testing.expectEqual(@as(usize, 298), actual.slice().len);
        for (actual.slice(), 3..) |match, length| try std.testing.expectEqual(length, match.length);
    }
}

test "Brotli HQ BT oracle persistent rebind stitches tail 127 and preserves generation across cycles" {
    var stream: [10 * 256]u8 = undefined;
    scalar.random(&stream, 0x791efa34, 8);
    const options: tree.HqOptions = .{ .search_depth = 4096, .nice_len = 257 };
    var profile: tree.HqProfile = .{};
    var matcher = try tree.Matcher.init(allocator, try tree.Source.init("", stream[0..256], 10, 0), options, &profile);
    defer matcher.deinit(allocator);
    for (0..10) |block| {
        const start = block * 256;
        const history = stream[start - @min(start, 1008) .. start];
        const input = stream[start .. start + 256];
        if (block != 0) {
            const previous_stitch = profile.stitch_positions;
            const previous_indexed = profile.indexed_positions;
            matcher.detachSource();
            try std.testing.expectError(error.InvalidBlockPlan, matcher.getMatches());
            try matcher.rebindSource(allocator, try tree.Source.init(history, input, 10, start), options, &profile);
            try std.testing.expectEqual(@as(u64, 127), profile.stitch_positions - previous_stitch);
            try std.testing.expectEqual(@as(u64, 127), profile.indexed_positions - previous_indexed);
        }
        const data: scalar.Data = .{ .history = history, .input = input, .window = 1008, .frame_offset = start };
        for (0..input.len) |position| try checkBest(data, position, try matcher.getMatches());
        try std.testing.expectEqual(@as(u64, 0), profile.history_seed_positions);
    }
}

fn shifted(reference: u32, delta: u32) u32 {
    return if (reference == std.math.maxInt(u32)) reference else std.math.add(u32, reference, delta) catch unreachable;
}

/// Test-only coordinate translation approved by the tree owner: actual bytes
/// and distances stay identical. Delta is a cycle multiple, preserving slots.
fn translateCheckpoint(matcher: *tree.Matcher, delta: u32) void {
    std.debug.assert(delta % matcher.cycle == 0);
    for (matcher.heads2) |*reference| reference.* = shifted(reference.*, delta);
    for (matcher.heads3) |*reference| reference.* = shifted(reference.*, delta);
    for (matcher.heads4) |*reference| reference.* = shifted(reference.*, delta);
    for (matcher.nodes[0..matcher.cycle]) |*node| {
        node.position = shifted(node.position, delta);
        node.left = shifted(node.left, delta);
        node.right = shifted(node.right, delta);
        node.short_previous = shifted(node.short_previous, delta);
    }
    matcher.metadata.begin += delta;
    matcher.metadata.input_begin += delta;
    matcher.metadata.end += delta;
    matcher.cursor += delta;
    matcher.next_main += delta;
    matcher.next_short2 += delta;
    matcher.next_short3 += delta;
    matcher.source.frame_offset += delta;
}

test "Brotli HQ BT oracle above four GiB positions and virtual normalization preserve real matcher results" {
    var bytes: [512]u8 = undefined;
    scalar.random(&bytes, 0x142a0345, 8);
    const frame_offset: u64 = (@as(u64, 1) << 32) + 9;
    const options: tree.HqOptions = .{ .search_depth = 4096, .nice_len = 257 };
    var profile: tree.HqProfile = .{};
    var matcher = try tree.Matcher.init(allocator, try tree.Source.init("", bytes[0..256], 10, frame_offset), options, &profile);
    defer matcher.deinit(allocator);
    for (0..256) |position| try checkBest(.{ .history = "", .input = bytes[0..256], .window = 1008, .frame_offset = frame_offset }, position, try matcher.getMatches());
    var baseline = try matcher.fork(allocator, 2 * matcher.workingBytes(), null);
    defer baseline.deinit(allocator);
    const threshold: u64 = @as(u64, std.math.maxInt(u32)) - (32 * 1024 * 1024);
    const delta: u32 = @intCast((threshold / matcher.cycle) * matcher.cycle);
    translateCheckpoint(&matcher, delta);
    try baseline.rebindSource(allocator, try tree.Source.init(bytes[0..256], bytes[256..], 10, frame_offset + 256), options, null);
    try matcher.rebindSource(allocator, try tree.Source.init(bytes[0..256], bytes[256..], 10, frame_offset + 256 + delta), options, &profile);
    try std.testing.expectEqual(@as(u64, 1), profile.normalizations);
    for (0..256) |position| {
        const actual = try matcher.getMatches();
        const unshifted = try baseline.getMatches();
        try std.testing.expectEqualDeep(unshifted.slice(), actual.slice());
        try checkBest(.{ .history = bytes[0..256], .input = bytes[256..], .window = 1008, .frame_offset = frame_offset + 256 + delta }, position, actual);
    }
}
