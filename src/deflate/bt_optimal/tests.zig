const std = @import("std");
const bt = @import("../bt_optimal.zig");
const lz77 = @import("../../lz77.zig");
const Match = lz77.Token.Match;
const none = std.math.maxInt(usize);
const Reference = @import("reference.zig").Reference;
const compareEvidence = @import("reference.zig").compareEvidence;
const oracleCost = @import("reference.zig").oracleCost;
const validatePlan = @import("reference.zig").validatePlan;
const fill = @import("reference.zig").fill;
test "bt frontier independent recursive matcher and exhaustive suffix cost oracle" {
    var input: [4096]u8 = undefined;
    fill(&input, 0x714f5a03);
    var literals: [256]u16 = undefined;
    for (&literals, 0..) |*cost, byte| cost.* = @intCast(5 + byte % 19);
    var lengths: [259]u16 = @splat(1);
    for (3..259) |length| lengths[length] = @intCast(1 + (length * 13) % 23);
    lengths[258] = 1; // nonmonotonic special final length
    var distances: [32769]u16 = @splat(1);
    var start: usize = 1;
    for (bt.class_ends, 0..) |end, cls| {
        @memset(distances[start .. end + 1], @intCast(31 - cls));
        start = end + 1;
    }
    const model = lz77.OptimalCostModel{ .literal = &literals, .length = &lengths, .distance = &distances };
    for ([_]lz77.GreedyOptions{
        .{ .max_chain = 512, .max_candidates = 256 },
        .{ .max_chain = 3, .max_candidates = 2, .window_len = 511, .max_match = 29 },
        .{ .max_chain = 384, .max_candidates = 1, .min_match = 4 },
        .{ .max_chain = 0, .max_candidates = 0 },
    }) |options| {
        var prepared = try bt.Prepared.init(std.testing.allocator, &input, options);
        defer prepared.deinit(std.testing.allocator);
        var reference = try Reference.init(&input, options);
        defer reference.deinit();
        try compareEvidence(&prepared, &reference);
        const fixed = try prepared.planFixedAlloc(std.testing.allocator);
        defer fixed.deinit(std.testing.allocator);
        try validatePlan(&input, fixed);
        try std.testing.expectEqual(try oracleCost(&reference, false, undefined), @as(usize, prepared.costs[0]));
        const fixed_again = try prepared.planFixedAlloc(std.testing.allocator);
        defer fixed_again.deinit(std.testing.allocator);
        try std.testing.expectEqualSlices(lz77.Token, fixed.tokens, fixed_again.tokens);
        const modeled = try prepared.planModeledAlloc(std.testing.allocator, model);
        defer modeled.deinit(std.testing.allocator);
        try validatePlan(&input, modeled);
        try std.testing.expectEqual(try oracleCost(&reference, true, model), @as(usize, prepared.costs[0]));
        const repeat = try prepared.planModeledAlloc(std.testing.allocator, model);
        defer repeat.deinit(std.testing.allocator);
        try std.testing.expectEqualSlices(lz77.Token, modeled.tokens, repeat.tokens);
    }
}

test "bt frontier RFC classes and packed evidence full boundaries" {
    var start: usize = 1;
    for (bt.class_ends, 0..) |end, cls| {
        for (start..end + 1) |distance| try std.testing.expectEqual(cls, bt.distanceClass(distance));
        start = end + 1;
    }
    for ([_]u16{ 3, 4, 127, 128, 257, 258 }) |length| {
        for ([_]u16{ 1, 4, 5, 32767, 32768 }) |distance| {
            try std.testing.expectEqualDeep(Match{ .length = length, .distance = distance }, bt.unpack(bt.pack(length, distance)));
        }
    }
    try std.testing.expectEqual(@as(u32, 0x7fffff), (@as(u32, bt.pack(258, 32768)[0]) | (@as(u32, bt.pack(258, 32768)[1]) << 8) | (@as(u32, bt.pack(258, 32768)[2]) << 16)));
}

test "bt frontier distance one overlap, final three/four bytes and u16 max input" {
    const input = try std.testing.allocator.alloc(u8, 65536);
    defer std.testing.allocator.free(input);
    @memset(input, 'a');
    var prepared = try bt.Prepared.init(std.testing.allocator, input, .{ .max_chain = 512, .max_candidates = 256 });
    defer prepared.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep(Match{ .length = 258, .distance = 1 }, bt.unpack(prepared.evidenceAt(1)[0]));
    for (2..259) |position| try std.testing.expectEqual(@as(usize, 0), prepared.evidenceAt(position).len);
    try std.testing.expect(prepared.evidenceAt(259).len > 0);
    try std.testing.expectEqual(@as(usize, 0), prepared.evidenceAt(65534).len);
    try std.testing.expectEqual(@as(usize, 0), prepared.evidenceAt(65535).len);
    const plan = try prepared.planFixedAlloc(std.testing.allocator);
    defer plan.deinit(std.testing.allocator);
    try validatePlan(input, plan);
}

test "bt frontier exact distance 32768 survives full input links and window cutoff" {
    const input = try std.testing.allocator.alloc(u8, 32771);
    defer std.testing.allocator.free(input);
    var rng: u64 = 0x872fc;
    for (input) |*byte| {
        rng = rng *% 6364136223846793005 +% 1;
        byte.* = @truncate(rng >> 32);
    }
    @memcpy(input[0..3], "abc");
    @memcpy(input[32768..32771], "abc");
    for ([_]usize{ 32767, 32768 }) |window| {
        var prepared = try bt.Prepared.init(std.testing.allocator, input, .{ .window_len = window, .max_chain = 512 });
        defer prepared.deinit(std.testing.allocator);
        const evidence = prepared.evidenceAt(32768);
        try std.testing.expectEqual(@as(usize, if (window == 32768) 1 else 0), evidence.len);
        if (evidence.len != 0) try std.testing.expectEqualDeep(Match{ .length = 3, .distance = 32768 }, bt.unpack(evidence[0]));
    }
}

test "bt frontier rejects ineligible ownership and arbitrary same class costs" {
    const input = "a" ** 4096;
    try std.testing.expectError(error.InvalidBlockPlan, bt.Prepared.init(std.testing.allocator, input[0..4095], .{}));
    try std.testing.expectError(error.InvalidBlockPlan, bt.Prepared.init(std.testing.allocator, "a" ** 65537, .{}));
    try std.testing.expectError(error.InvalidBlockPlan, bt.Prepared.init(std.testing.allocator, input, .{ .window_len = 0 }));
    try std.testing.expectError(error.InvalidBlockPlan, bt.Prepared.init(std.testing.allocator, input, .{ .window_len = 32769 }));
    var prepared = try bt.Prepared.init(std.testing.allocator, input, .{});
    defer prepared.deinit(std.testing.allocator);
    const literal: [256]u16 = @splat(65535);
    const length: [259]u16 = @splat(65535);
    var distance: [32769]u16 = @splat(65535);
    const model = lz77.OptimalCostModel{ .literal = &literal, .length = &length, .distance = &distance };
    const maximum_cost_plan = try prepared.planModeledAlloc(std.testing.allocator, model);
    defer maximum_cost_plan.deinit(std.testing.allocator);
    try validatePlan(input, maximum_cost_plan);
    distance[6] = 65534; // five and six share the same RFC symbol
    try std.testing.expectError(error.InvalidBlockPlan, prepared.planModeledAlloc(std.testing.allocator, model));
    distance[6] = 65535;
    distance[1] = 0;
    try std.testing.expectError(error.InvalidBlockPlan, prepared.planModeledAlloc(std.testing.allocator, model));
}

test "bt frontier shorter farther cheap class survives against nearer long class" {
    const input = "a" ** 4096;
    var prepared = try bt.Prepared.init(std.testing.allocator, input, .{});
    defer prepared.deinit(std.testing.allocator);
    // Isolate the suffix solver with valid byte-checked evidence. Production
    // repetitive BT exits at its first full-length match, so this fixture must
    // explicitly supply two graph edges to exercise the class price tradeoff.
    prepared.records.clearRetainingCapacity();
    @memset(prepared.counts, 0);
    try prepared.records.append(std.testing.allocator, bt.pack(258, 1));
    try prepared.records.append(std.testing.allocator, bt.pack(257, 5));
    prepared.counts[5] = 2;
    const literals: [256]u16 = @splat(10);
    var lengths: [259]u16 = @splat(100);
    lengths[257] = 1;
    const distance: [32769]u16 = @splat(1);
    var distances = distance;
    distances[1] = 100;
    const plan = try prepared.planModeledAlloc(std.testing.allocator, .{ .literal = &literals, .length = &lengths, .distance = &distances });
    defer plan.deinit(std.testing.allocator);
    try validatePlan(input, plan);
    try std.testing.expectEqualDeep(lz77.Token{ .match = .{ .length = 257, .distance = 5 } }, prepared.steps[5]);
}

test "bt frontier word extension equals scalar from every proven prefix" {
    var input: [1024]u8 = undefined;
    fill(&input, 0x1763739a);
    for ([_]usize{ 0, 1, 7, 8, 9, 15, 16, 17, 127, 128, 129, 257, 258 }) |mismatch| {
        @memcpy(input[513..771], input[1..259]);
        if (mismatch < 258) input[513 + mismatch] ^= 1;
        for ([_]usize{ 3, 7, 8, 9, 15, 16, 17, 127, 128, 129, 257, 258 }) |maximum| {
            var expected: usize = 0;
            while (expected < maximum and input[1 + expected] == input[513 + expected]) : (expected += 1) {}
            for (0..expected + 1) |prefix| {
                try std.testing.expectEqual(expected, bt.extendPortable(&input, 1, 513, prefix, maximum));
            }
        }
    }
}

test "bt frontier maximum u16 modeled arithmetic at maximum eligible input" {
    const input = try std.testing.allocator.alloc(u8, 65536);
    defer std.testing.allocator.free(input);
    @memset(input, 'a');
    var prepared = try bt.Prepared.init(std.testing.allocator, input, .{});
    defer prepared.deinit(std.testing.allocator);
    const literal: [256]u16 = @splat(65535);
    const length: [259]u16 = @splat(65535);
    const distance: [32769]u16 = @splat(65535);
    const plan = try prepared.planModeledAlloc(std.testing.allocator, .{ .literal = &literal, .length = &length, .distance = &distance });
    defer plan.deinit(std.testing.allocator);
    try validatePlan(input, plan);
    const bound = try std.math.add(usize, try std.math.mul(usize, 65535, 65535), 131070);
    try std.testing.expectEqual(@as(u64, 4294967295), bound);
}

test "bt frontier covered graph leaves exact full budget tree state unchanged" {
    var input: [4096]u8 = undefined;
    @memset(&input, 'a');
    @memcpy(input[777..][0..12], "abcdefghijk!");
    const options: lz77.GreedyOptions = .{ .max_chain = 31, .max_candidates = 7 };
    var raw = try Reference.init(&input, options);
    defer raw.deinit();
    var actual = try bt.Tree.init(std.testing.allocator, input.len);
    defer actual.deinit(std.testing.allocator);
    var covered_end: usize = 0;
    var suppressed: usize = 0;
    for (0..input.len - 2) |position| {
        var lengths: [30]u16 = @splat(0);
        var distances: [30]u16 = @splat(bt.empty);
        actual.advance(&input, position, @min(@as(usize, 258), input.len - position), 3, options.window_len, options.max_chain, options.max_candidates, &lengths, &distances);
        if (position < covered_end) {
            suppressed += 1;
            continue;
        }
        const best = std.mem.max(u16, &lengths);
        if (best >= bt.coverage_threshold) covered_end = position + best;
    }
    try std.testing.expect(suppressed > 0);
    for (actual.roots, raw.roots) |left, right| try std.testing.expectEqual(if (right == none) bt.empty else @as(u16, @intCast(right)), left);
    for (actual.children[0 .. input.len - 2], raw.children[0 .. input.len - 2]) |left, right| for (left, right) |child, ref| try std.testing.expectEqual(if (ref == none) bt.empty else @as(u16, @intCast(ref)), child);
    var prepared = try bt.Prepared.init(std.testing.allocator, &input, options);
    defer prepared.deinit(std.testing.allocator);
    try compareEvidence(&prepared, &raw);
    const original_counts = try std.testing.allocator.dupe(u8, prepared.counts);
    defer std.testing.allocator.free(original_counts);
    const original_records = try std.testing.allocator.dupe(bt.Record, prepared.records.items);
    defer std.testing.allocator.free(original_records);
    const fixed = try prepared.planFixedAlloc(std.testing.allocator);
    defer fixed.deinit(std.testing.allocator);
    try std.testing.expectEqual(try oracleCost(&raw, false, undefined), @as(usize, prepared.costs[0]));
    const literal: [256]u16 = @splat(1);
    const length: [259]u16 = @splat(65535);
    const distance: [32769]u16 = @splat(65535);
    const model = lz77.OptimalCostModel{ .literal = &literal, .length = &length, .distance = &distance };
    const expensive = try prepared.planModeledAlloc(std.testing.allocator, model);
    defer expensive.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), expensive.stats.matches);
    try std.testing.expectEqual(@as(usize, input.len), expensive.stats.literals);
    try std.testing.expectEqual(try oracleCost(&raw, true, model), @as(usize, prepared.costs[0]));
    try std.testing.expectEqualSlices(u8, original_counts, prepared.counts);
    try std.testing.expectEqualSlices(bt.Record, original_records, prepared.records.items);
    try validatePlan(&input, fixed);
    try validatePlan(&input, expensive);
}

test "bt frontier natural 65536 model maximum u16 costs retain finite literal path" {
    const input = try std.testing.allocator.alloc(u8, 65536);
    defer std.testing.allocator.free(input);
    @memset(input, 'a');
    var prepared = try bt.Prepared.init(std.testing.allocator, input, .{ .max_chain = 1, .max_candidates = 1 });
    defer prepared.deinit(std.testing.allocator);
    const literal: [256]u16 = @splat(65535);
    const length: [259]u16 = @splat(65535);
    const distance: [32769]u16 = @splat(65535);
    const plan = try prepared.planModeledAlloc(std.testing.allocator, .{ .literal = &literal, .length = &length, .distance = &distance });
    defer plan.deinit(std.testing.allocator);
    try validatePlan(input, plan);
    try std.testing.expect(prepared.costs[0] <= @as(usize, 65536) * 65535);
}

test "bt frontier threshold exact covered interval never extends from an omitted match" {
    const input = "a" ** 4096;
    for ([_]usize{ bt.coverage_threshold - 1, bt.coverage_threshold }) |maximum| {
        const options: lz77.GreedyOptions = .{ .max_match = maximum, .max_chain = 8, .max_candidates = 4 };
        var prepared = try bt.Prepared.init(std.testing.allocator, input, options);
        defer prepared.deinit(std.testing.allocator);
        var raw = try Reference.init(input, options);
        defer raw.deinit();
        try compareEvidence(&prepared, &raw);
        if (maximum == bt.coverage_threshold) {
            for (2..maximum + 1) |position| try std.testing.expectEqual(@as(usize, 0), prepared.evidenceAt(position).len);
            // Covered interior matches cannot restart or lengthen this range.
            try std.testing.expect(prepared.evidenceAt(maximum + 1).len > 0);
        } else try std.testing.expect(prepared.evidenceAt(2).len > 0);
        const fixed = try prepared.planFixedAlloc(std.testing.allocator);
        defer fixed.deinit(std.testing.allocator);
        try std.testing.expectEqual(try oracleCost(&raw, false, undefined), @as(usize, prepared.costs[0]));
        try validatePlan(input, fixed);
    }
}
