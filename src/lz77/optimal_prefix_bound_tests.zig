//! Bound-enabled old/new comparison, independent token replay and resource
//! contracts. The root proxy injects the prototype; this file imports no LZ77.
const std = @import("std");

const Coverage = struct {
    cases: usize = 0,
    bound_rejections: usize = 0,
    prefix_rejections: usize = 0,
    matches: usize = 0,
    allocation_failures: usize = 0,
    warm_reuses: usize = 0,
    safety_neighbors: usize = 0,
    checked_slacks: usize = 0,
    targeted_bounds: usize = 0,
};

fn Snapshot(comptime Codec: type) type {
    return struct {
        costs: []usize,
        steps: []Codec.Token,
        tokens: []Codec.Token,

        fn capture(scratch: *const Codec.OptimalScratch) !@This() {
            const costs = try std.testing.allocator.dupe(usize, scratch.costs.items);
            errdefer std.testing.allocator.free(costs);
            const steps = try std.testing.allocator.dupe(Codec.Token, scratch.steps.items);
            errdefer std.testing.allocator.free(steps);
            const tokens = try std.testing.allocator.dupe(Codec.Token, scratch.tokens.items);
            return .{ .costs = costs, .steps = steps, .tokens = tokens };
        }

        fn deinit(self: @This()) void {
            std.testing.allocator.free(self.costs);
            std.testing.allocator.free(self.steps);
            std.testing.allocator.free(self.tokens);
        }

        fn expectEqual(self: @This(), scratch: *const Codec.OptimalScratch) !void {
            try std.testing.expectEqualSlices(usize, self.costs, scratch.costs.items);
            try std.testing.expectEqualSlices(Codec.Token, self.steps, scratch.steps.items);
            try std.testing.expectEqualSlices(Codec.Token, self.tokens, scratch.tokens.items);
        }
    };
}

fn expectScratch(comptime Codec: type, expected: *const Codec.OptimalScratch, actual: *const Codec.OptimalScratch) !void {
    try std.testing.expectEqualSlices(Codec.Token, expected.tokens.items, actual.tokens.items);
    try std.testing.expectEqualSlices(Codec.Token, expected.steps.items, actual.steps.items);
    try std.testing.expectEqualSlices(usize, expected.costs.items, actual.costs.items);
}

fn expectProfile(expected: anytype, actual: @TypeOf(expected)) !void {
    inline for (@typeInfo(@TypeOf(expected)).@"struct".fields) |field| {
        if (comptime !std.mem.endsWith(u8, field.name, "_ns")) {
            try std.testing.expectEqualDeep(@field(expected, field.name), @field(actual, field.name));
        }
    }
}

fn replay(comptime Codec: type, input: []const u8, options: Codec.GreedyOptions, stats: Codec.PlanStats, tokens: []const Codec.Token) !void {
    const output = try std.testing.allocator.alloc(u8, input.len);
    defer std.testing.allocator.free(output);
    @memset(output, 0xd3);
    var position: usize = 0;
    var literals: usize = 0;
    var matches: usize = 0;
    var matched_bytes: usize = 0;
    const maximum = @max(@as(usize, 3), @min(options.max_match, 258));
    const minimum = @max(@as(usize, 3), @min(options.min_match, maximum));
    for (tokens) |token| {
        switch (token) {
            .literal => |byte| {
                try std.testing.expect(position < input.len);
                output[position] = byte;
                position += 1;
                literals += 1;
            },
            .match => |match| {
                try std.testing.expect(match.length >= minimum and match.length <= maximum);
                try std.testing.expect(match.distance > 0 and match.distance <= options.window_len);
                try std.testing.expect(match.distance <= position);
                try std.testing.expect(match.length <= input.len - position);
                for (0..match.length) |_| {
                    output[position] = output[position - match.distance];
                    position += 1;
                }
                matches += 1;
                matched_bytes += match.length;
            },
        }
    }
    try std.testing.expectEqual(input.len, position);
    try std.testing.expectEqualSlices(u8, input, output);
    try std.testing.expectEqual(literals, stats.literals);
    try std.testing.expectEqual(matches, stats.matches);
    try std.testing.expectEqual(matched_bytes, stats.matched_bytes);
}

const Witness = struct {
    position: usize,
    near_distance: usize,
    near_length: usize,
    far_distance: usize,
    far_length: usize,
    kind: enum { plateau_tie, losing_frontier },
};

fn runCase(comptime Codec: type, input: []const u8, options: Codec.GreedyOptions, coverage: *Coverage) !void {
    return runWitnessCase(Codec, input, options, null, coverage);
}

fn runWitnessCase(comptime Codec: type, input: []const u8, options: Codec.GreedyOptions, witness: ?Witness, coverage: *Coverage) !void {
    const before = try std.testing.allocator.dupe(u8, input);
    defer std.testing.allocator.free(before);
    const options_before = options;
    var original_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var optimized_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var original: Codec.OptimalScratch = .{};
    var optimized: Codec.OptimalScratch = .{};
    var deinitialized = false;
    defer if (!deinitialized) {
        original.deinit(original_heap.allocator());
        optimized.deinit(optimized_heap.allocator());
    };
    const old_stats = try Codec.original(&original, original_heap.allocator(), input, options);
    const new_stats = try Codec.optimized(&optimized, optimized_heap.allocator(), input, options);
    try std.testing.expectEqualDeep(old_stats, new_stats);
    try expectScratch(Codec, &original, &optimized);
    const snapshot = try Snapshot(Codec).capture(&optimized);
    defer snapshot.deinit();
    try replay(Codec, input, options, new_stats, optimized.tokens.items);
    try std.testing.expectEqual(input.len + 1, optimized.costs.items.len);
    try std.testing.expectEqual(input.len, optimized.steps.items.len);
    try std.testing.expectEqual(@as(usize, 0), optimized.costs.items[input.len]);
    try std.testing.expect(@as(u128, optimized.costs.items[0]) <= @as(u128, input.len) * 9);

    // A fully warmed rerun must need no allocator traffic. Poison caller DP
    // outputs before rebuilding, then compare all initialized slots and tokens.
    original_heap.fail_index = original_heap.alloc_index;
    original_heap.resize_fail_index = original_heap.resize_index;
    optimized_heap.fail_index = optimized_heap.alloc_index;
    optimized_heap.resize_fail_index = optimized_heap.resize_index;
    @memset(original.costs.items, std.math.maxInt(usize));
    @memset(optimized.costs.items, std.math.maxInt(usize));
    @memset(original.steps.items, .{ .literal = 0xd3 });
    @memset(optimized.steps.items, .{ .literal = 0xd3 });
    var old_profile: Codec.OptimalSearchProfile = .{};
    var new_profile: Codec.OptimalSearchProfile = .{};
    const old_profiled_stats = try Codec.originalProfiled(&original, original_heap.allocator(), input, options, std.testing.io, &old_profile);
    const new_profiled_stats = try Codec.optimizedProfiled(&optimized, optimized_heap.allocator(), input, options, std.testing.io, &new_profile);
    try std.testing.expectEqualDeep(old_stats, old_profiled_stats);
    try std.testing.expectEqualDeep(old_stats, new_profiled_stats);
    try snapshot.expectEqual(&original);
    try snapshot.expectEqual(&optimized);
    try expectProfile(old_profile, new_profile);
    try std.testing.expectEqual(input.len, new_profile.input_bytes);
    try std.testing.expectEqual(input.len, new_profile.positions);
    if (witness) |target| {
        const step = optimized.steps.items[target.position];
        try std.testing.expect(step == .match);
        try std.testing.expectEqual(target.near_distance, @as(usize, step.match.distance));
        try std.testing.expectEqual(target.near_length, @as(usize, step.match.length));
        try std.testing.expect(new_profile.bound_rejections != 0);
        // Both fixture lengths fall in RFC fixed-Huffman symbols 260..265,
        // whose seven-bit price lets us verify two concrete output edges
        // directly without reconstructing the parser's length-choice DP.
        const near_distance_bits: usize = switch (target.near_distance) {
            // RFC distance code 7 covers 13..16: five code bits + two extras.
            16 => 7,
            33 => 9,
            else => unreachable,
        };
        const far_distance_bits: usize = switch (target.far_distance) {
            49 => 9,
            16385 => 18,
            else => unreachable,
        };
        const near_edge = 7 + near_distance_bits + optimized.costs.items[target.position + target.near_length];
        const far_edge = 7 + far_distance_bits + optimized.costs.items[target.position + target.far_length];
        try std.testing.expectEqual(near_edge, optimized.costs.items[target.position]);
        switch (target.kind) {
            .plateau_tie => try std.testing.expectEqual(near_edge, far_edge),
            .losing_frontier => {
                try std.testing.expect(target.far_length > target.near_length);
                try std.testing.expectEqual(@as(usize, 32), near_edge);
                try std.testing.expectEqual(@as(usize, 34), far_edge);
                try std.testing.expect(far_edge > near_edge);
            },
        }
        coverage.targeted_bounds += new_profile.bound_rejections;
    }
    try std.testing.expect(!original_heap.has_induced_failure and !optimized_heap.has_induced_failure);
    try std.testing.expectEqualSlices(u8, before, input);
    try std.testing.expectEqualDeep(options_before, options);

    // An external absolute ceiling catches runaway allocation while allowing
    // ordinary growth policy choices; it does not reproduce scratch formulas.
    try std.testing.expect(original_heap.allocated_bytes < 4 * 1024 * 1024);
    try std.testing.expect(optimized_heap.allocated_bytes < 4 * 1024 * 1024);
    original.deinit(original_heap.allocator());
    optimized.deinit(optimized_heap.allocator());
    deinitialized = true;
    try std.testing.expectEqual(original_heap.allocated_bytes, original_heap.freed_bytes);
    try std.testing.expectEqual(optimized_heap.allocated_bytes, optimized_heap.freed_bytes);
    coverage.cases += 1;
    coverage.bound_rejections += new_profile.bound_rejections;
    coverage.prefix_rejections += new_profile.prefix_rejections;
    coverage.matches += new_stats.matches;
    coverage.warm_reuses += 2;
}

fn fillStructured(input: []u8, seed: u32) void {
    var random = seed;
    for (input, 0..) |*byte, position| {
        random = random *% 1_664_525 +% 1_013_904_223;
        byte.* = if (position >= 769 and position % 17 < 13)
            input[position - 769]
        else
            @truncate(random >> 24);
    }
}

fn tinyCases(comptime Codec: type, coverage: *Coverage) !void {
    var random = std.Random.DefaultPrng.init(0x7072_6566_6978_0101);
    for ([_]usize{ 0, 1, 2, 3, 4, 7, 17, 33, 63 }) |length| {
        const input = try std.testing.allocator.alloc(u8, length);
        defer std.testing.allocator.free(input);
        for (0..3) |pattern| {
            for (input, 0..) |*byte, index| byte.* = switch (pattern) {
                0 => random.random().int(u8),
                1 => 'a',
                else => @intCast((index / 3) % 5 + 'a'),
            };
            try runCase(Codec, input, .{
                .window_len = length,
                .min_match = 3 + pattern % 2,
                .max_candidates = ([_]usize{ 1, 2, 8 })[pattern],
                .max_chain = ([_]usize{ 1, 8, 128 })[pattern],
            }, coverage);
        }
    }
}

fn wordCases(comptime Codec: type, coverage: *Coverage) !void {
    for ([_]usize{ 4, 5, 7, 8, 9, 10, 15, 16, 17, 23, 31, 32, 33, 47, 63, 64, 65, 95, 127, 128, 129, 191, 255, 257, 258 }) |length| {
        const input = try std.testing.allocator.alloc(u8, 12 * (length + 1));
        defer std.testing.allocator.free(input);
        for (input, 0..) |*byte, index| {
            const record = index / (length + 1);
            const offset = index % (length + 1);
            byte.* = if (offset == length) @intCast(200 + record % 4) else @intCast(33 + (offset * 19) % 127);
            if (record % 3 == 1 and offset == @max(@as(usize, 4), length / 2)) byte.* ^= 0x80;
        }
        try runCase(Codec, input, .{ .window_len = input.len, .min_match = 4, .max_chain = 128, .max_candidates = 8, .nice_len = 258, .max_match = length }, coverage);
    }
}

fn optionCases(comptime Codec: type, coverage: *Coverage) !void {
    var input: [4096]u8 = undefined;
    fillStructured(&input, 0x3c6e_f372);
    var index: usize = 0;
    for ([_]usize{ 3, 4 }) |minimum| {
        for ([_]usize{ 1, 2, 8, 64 }) |candidates| {
            for ([_]usize{ 1, 8, 128 }) |chain| {
                try runCase(Codec, &input, .{
                    .window_len = input.len,
                    .min_match = minimum,
                    .max_candidates = candidates,
                    .max_chain = chain,
                    .nice_len = ([_]usize{ 3, 4, 8, 16, 64, 257, 258 })[index % 7],
                    .max_match = ([_]usize{ 3, 4, 5, 16, 64, 257, 258, 259 })[index % 8],
                }, coverage);
                index += 1;
            }
        }
    }
    // Deep chains, high candidate quota, and nontrivial copied prefixes must
    // actually reach the bound branch rather than only compare empty profiles.
    for (0..8) |seed| {
        fillStructured(&input, @intCast(0x243f_6a88 + seed * 991));
        try runCase(Codec, &input, .{ .window_len = input.len, .min_match = 4, .max_candidates = 64, .max_chain = 128, .nice_len = 258, .max_match = 258 }, coverage);
    }
}

fn distanceCases(comptime Codec: type, coverage: *Coverage) !void {
    const distances = [_]usize{ 3, 4, 5, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 129, 255, 256, 257, 1024, 32767, 32768 };
    var random = std.Random.DefaultPrng.init(0x6469_7374_616e_6365);
    for (distances, 0..) |distance, index| {
        const input = try std.testing.allocator.alloc(u8, distance + 258);
        defer std.testing.allocator.free(input);
        for (input[0..distance]) |*byte| byte.* = random.random().int(u8);
        for (input[distance..], distance..) |*byte, position| byte.* = input[position - distance];
        const window = if (index % 3 == 0) distance - 1 else if (index % 3 == 1) distance else @min(@as(usize, 32768), distance + 1);
        try runCase(Codec, input, .{
            .window_len = window,
            .min_match = 3 + index % 2,
            .max_candidates = ([_]usize{ 1, 2, 8, 64 })[index % 4],
            .max_chain = 128,
            .nice_len = 258,
            .max_match = 258,
        }, coverage);
    }
}

fn safetyCases(comptime Codec: type, coverage: *Coverage) !void {
    inline for (.{ u32, u64 }) |Word| {
        const maximum = std.math.maxInt(Word);
        const boundary = maximum / 9;
        const values = [_]Word{ 0, 1, 8, 9, boundary - 2, boundary - 1, boundary, boundary + 1, boundary + 2, maximum - 1, maximum };
        for (values) |value| {
            const expected = @as(u128, value) * 9 <= @as(u128, maximum);
            try std.testing.expectEqual(expected, Codec.costsFitInputLength(Word, value));
            coverage.safety_neighbors += 1;
        }
        const compile_safe = comptime Codec.costsFitInputLength(Word, boundary);
        const compile_unsafe = comptime Codec.costsFitInputLength(Word, boundary + 1);
        try std.testing.expect(compile_safe and !compile_unsafe);
    }
}

fn checkedSlackCases(comptime Codec: type, coverage: *Coverage) !void {
    inline for (.{ u32, u64 }) |Count| {
        const maximum = std.math.maxInt(Count);
        const boundary = maximum / 9;
        for ([_]Count{ boundary - 2, boundary - 1, boundary }) |n| {
            try std.testing.expect(Codec.costsFitInputLength(Count, n));
            const literal_bound: u128 = 9 * @as(u128, n);
            const b4_reference: u128 = 7 + 9 * (@as(u128, n) - 4);
            const bound_reference = b4_reference + 18;
            try std.testing.expect(bound_reference <= literal_bound - 11);
            try std.testing.expectEqual(literal_bound - 11, bound_reference);
            try std.testing.expect(bound_reference <= maximum);
            const b4: Count = @intCast(b4_reference);
            const bound = try std.math.add(Count, b4, 18);
            try std.testing.expectEqual(@as(Count, @intCast(bound_reference)), bound);
            // A prior nearest distance has price five. Test exact nonnegative
            // subtraction at a zero, positive and maximum representable slack.
            const near_edge = try std.math.add(Count, b4, 5);
            for ([_]Count{ 0, near_edge, bound }) |current| {
                const slack = try std.math.sub(Count, bound, current);
                try std.testing.expectEqual(@as(Count, @intCast(bound_reference - current)), slack);
                coverage.checked_slacks += 1;
            }
            try std.testing.expectEqual(@as(Count, 13), try std.math.sub(Count, bound, near_edge));
        }
    }
}

fn witnessMatch(input: []const u8, source: usize, position: usize, length: usize) !void {
    try std.testing.expectEqualSlices(u8, input[source..][0..length], input[position..][0..length]);
    try std.testing.expect(input[source + length] != input[position + length]);
}

fn targetedCandidateCases(comptime Codec: type, coverage: *Coverage) !void {
    const phrase = "12345678";
    // All three anchors match exactly eight bytes. The nearest two distances
    // 33 and 49 share a nine-bit price; their edge costs tie strictly, so the
    // farther request cannot replace the near winner after k=8 was built.
    var plateau: [169]u8 = @splat(0);
    for ([_]usize{ 95, 111, 127, 160 }) |position| {
        @memcpy(plateau[position..][0..phrase.len], phrase);
        plateau[position + phrase.len] = if (position == 160) 0xfa else 0xfb;
    }
    try witnessMatch(&plateau, 127, 160, 8);
    try witnessMatch(&plateau, 111, 160, 8);
    try witnessMatch(&plateau, 95, 160, 8);
    try runWitnessCase(Codec, &plateau, .{
        .window_len = plateau.len,
        .min_match = 4,
        .max_candidates = 64,
        .max_chain = 128,
        .nice_len = 258,
        .max_match = 258,
    }, .{
        .position = 160,
        .near_distance = 33,
        .near_length = 8,
        .far_distance = 49,
        .far_length = 8,
        .kind = .plateau_tie,
    }, coverage);

    // The near eight-byte edge costs 32. A farther nine-byte match costs 34:
    // it extends the frontier without improving the chosen DP step. The next
    // older nine-byte anchor differs at k=9 and exercises bound rejection.
    const position = 32768;
    const input = try std.testing.allocator.alloc(u8, position + 10);
    defer std.testing.allocator.free(input);
    @memset(input, 0);
    const near = position - 16;
    const far = position - 16385;
    const older = position - 24577;
    for ([_]usize{ older, far, near, position }) |anchor| {
        @memcpy(input[anchor..][0..phrase.len], phrase);
        input[anchor + 8] = if (anchor == near) 0xf8 else 0xfa;
        input[anchor + 9] = if (anchor == position) 0xf9 else 0xf8;
    }
    try witnessMatch(input, near, position, 8);
    try witnessMatch(input, far, position, 9);
    try witnessMatch(input, older, position, 9);
    try runWitnessCase(Codec, input, .{
        .window_len = 32768,
        .min_match = 4,
        .max_candidates = 64,
        .max_chain = 128,
        .nice_len = 258,
        .max_match = 258,
    }, .{
        .position = position,
        .near_distance = 16,
        .near_length = 8,
        .far_distance = 16385,
        .far_length = 9,
        .kind = .losing_frontier,
    }, coverage);
}

fn allocationFailures(comptime Codec: type, coverage: *Coverage) !void {
    const input = "abcabcXabcabcYabcabcZabcabcX" ** 8;
    const options: Codec.GreedyOptions = .{ .window_len = input.len, .min_match = 4, .max_chain = 128, .max_candidates = 8 };
    for (0..6) |failure_index| {
        var original_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure_index });
        var optimized_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure_index });
        var original: Codec.OptimalScratch = .{};
        var optimized: Codec.OptimalScratch = .{};
        var deinitialized = false;
        defer if (!deinitialized) {
            original.deinit(original_heap.allocator());
            optimized.deinit(optimized_heap.allocator());
        };
        const old = Codec.original(&original, original_heap.allocator(), input, options);
        const new = Codec.optimized(&optimized, optimized_heap.allocator(), input, options);
        if (old) |stats| {
            try std.testing.expectEqualDeep(stats, try new);
            try expectScratch(Codec, &original, &optimized);
        } else |err| {
            try std.testing.expectError(error.OutOfMemory, old);
            try std.testing.expectError(err, new);
            coverage.allocation_failures += 1;
        }
        // Lift the external fault and reuse partially initialized scratch.
        original_heap.fail_index = std.math.maxInt(usize);
        optimized_heap.fail_index = std.math.maxInt(usize);
        const old_retry = try Codec.original(&original, original_heap.allocator(), input, options);
        const new_retry = try Codec.optimized(&optimized, optimized_heap.allocator(), input, options);
        try std.testing.expectEqualDeep(old_retry, new_retry);
        try expectScratch(Codec, &original, &optimized);
        original.deinit(original_heap.allocator());
        optimized.deinit(optimized_heap.allocator());
        deinitialized = true;
        try std.testing.expectEqual(original_heap.allocated_bytes, original_heap.freed_bytes);
        try std.testing.expectEqual(optimized_heap.allocated_bytes, optimized_heap.freed_bytes);
    }
}

pub fn check(comptime Codec: type) !void {
    var coverage: Coverage = .{};
    try safetyCases(Codec, &coverage);
    try checkedSlackCases(Codec, &coverage);
    try tinyCases(Codec, &coverage);
    try wordCases(Codec, &coverage);
    try optionCases(Codec, &coverage);
    try distanceCases(Codec, &coverage);
    try targetedCandidateCases(Codec, &coverage);
    try allocationFailures(Codec, &coverage);
    try std.testing.expect(coverage.cases <= 128);
    try std.testing.expect(coverage.bound_rejections != 0);
    try std.testing.expect(coverage.matches != 0 and coverage.allocation_failures != 0);
    try std.testing.expect(coverage.targeted_bounds != 0 and coverage.checked_slacks == 18);
    std.debug.print("optimal_prefix cases={d} bound_rejections={d} prefix_rejections={d} matches={d} alloc_failures={d} warm_reuses={d} safety_neighbors={d} checked_slacks={d} targeted_bounds={d}\n", .{
        coverage.cases,               coverage.bound_rejections, coverage.prefix_rejections, coverage.matches,
        coverage.allocation_failures, coverage.warm_reuses,      coverage.safety_neighbors,  coverage.checked_slacks,
        coverage.targeted_bounds,
    });
}
