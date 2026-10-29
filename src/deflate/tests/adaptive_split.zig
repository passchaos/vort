const std = @import("std");

pub fn contracts(comptime C: type) !void {
    try selection(C);
    try uniform(C);
    try arithmetic(C);
    try grid(C);
    try allocationFailures(C);
}

fn selection(comptime C: type) !void {
    const input = ("aaaaaaaaaaaaaaaa" ** 4) ++ "abcdefghijklmnopqrstuvwxyz" ++ ("abcabcabcabc" ** 8);
    const options = C.options(.default);
    const horizon: usize = 128;
    const chosen = try C.choose(std.testing.allocator, input, 16, horizon, 8, 16, options);
    const heuristic = C.heuristic(input, 16, horizon, 8);
    var expected_len = horizon;
    var expected_score = try C.scoreAt(std.testing.allocator, input, horizon, horizon, options);
    var candidate: usize = 16;
    while (candidate < horizon) : (candidate += 16) {
        const score = try C.scoreAt(std.testing.allocator, input, horizon, candidate, options);
        if (score < expected_score or (score == expected_score and candidate > expected_len)) {
            expected_len = candidate;
            expected_score = score;
        }
    }
    if (heuristic < horizon and (heuristic - 16) % 16 != 0) {
        const score = try C.scoreAt(std.testing.allocator, input, horizon, heuristic, options);
        if (score < expected_score or (score == expected_score and heuristic > expected_len))
            expected_len = heuristic;
    }
    try std.testing.expectEqual(expected_len, chosen);

    // The old incomparable-prefix objective selects the shortest candidate on
    // this same transition fixture; complete-horizon scoring must reject it.
    var prefix_best_len: usize = 16;
    var prefix_best_score = try C.score(std.testing.allocator, input, 16, options);
    candidate = 32;
    while (candidate <= horizon) : (candidate += 16) {
        const prefix_score = try C.score(std.testing.allocator, input, candidate, options);
        if (prefix_score < prefix_best_score) {
            prefix_best_score = prefix_score;
            prefix_best_len = candidate;
        }
    }
    try std.testing.expectEqual(@as(usize, 16), prefix_best_len);
    try std.testing.expect(chosen != 16);

    const encoded = try C.encode(std.testing.allocator, input, options, .{
        .min_block_len = 16,
        .max_block_len = 64,
        .sample_len = 8,
        .search_step = 16,
    });
    defer std.testing.allocator.free(encoded);
    const decoded = try C.decode(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

fn uniform(comptime C: type) !void {
    const input = "the quick brown fox jumps over the lazy dog\n" ** 256;
    const options = C.options(.default);
    const chosen = try C.choose(
        std.testing.allocator,
        input,
        1024,
        input.len,
        512,
        1024,
        options,
    );
    try std.testing.expectEqual(input.len, chosen);
    var incremental = options;
    incremental.split_options = .{
        .min_block_len = 1024,
        .max_block_len = input.len,
        .sample_len = 512,
        .search_step = 1024,
    };
    try std.testing.expectEqual(
        input.len,
        try C.chooseIncremental(std.testing.allocator, input, incremental),
    );
}

fn arithmetic(comptime C: type) !void {
    try std.testing.expectEqual(@as(usize, 24), try C.combine(11, 12));
    try std.testing.expect(C.prefer(9, 16, 10, 64));
    try std.testing.expect(!C.prefer(11, 128, 10, 64));
    try std.testing.expect(C.prefer(10, 128, 10, 64));
    try std.testing.expect(!C.prefer(10, 32, 10, 64));
    try std.testing.expectError(error.IntegerOverflow, C.combine(std.math.maxInt(usize), 1));
    try std.testing.expectError(error.IntegerOverflow, C.combine(std.math.maxInt(usize), 0));
    try std.testing.expectError(error.IntegerOverflow, C.combine(std.math.maxInt(usize) - 1, 1));
}

fn grid(comptime C: type) !void {
    const horizon: usize = 100;
    const minimum: usize = 16;
    const step = C.searchStep(horizon, minimum, 16);
    try std.testing.expectEqual(@as(usize, 16), step);
    try std.testing.expect(C.gridContains(16, minimum, horizon, step));
    try std.testing.expect(C.gridContains(96, minimum, horizon, step));
    try std.testing.expect(!C.gridContains(50, minimum, horizon, step));
    try std.testing.expect(!C.gridContains(horizon, minimum, horizon, step));

    var best_score: usize = 100;
    var best_len = horizon;
    C.retain(&best_score, &best_len, 90, 50);
    try std.testing.expectEqual(@as(usize, 90), best_score);
    try std.testing.expectEqual(@as(usize, 50), best_len);

    const single_step = C.searchStep(horizon, minimum, 1000);
    try std.testing.expectEqual(@as(usize, 1000), single_step);
    var single_count: usize = 0;
    var candidate = minimum;
    while (candidate < horizon) {
        single_count += 1;
        if (horizon - candidate <= single_step) break;
        candidate += single_step;
    }
    try std.testing.expectEqual(@as(usize, 1), single_count);

    const maximum_horizon: usize = 65_535;
    const bounded_step = C.searchStep(maximum_horizon, 1, 0);
    var bounded_count: usize = 0;
    candidate = 1;
    while (candidate < maximum_horizon) {
        bounded_count += 1;
        if (maximum_horizon - candidate <= bounded_step) break;
        candidate += bounded_step;
    }
    try std.testing.expect(bounded_count <= C.max_candidates);
}

fn allocationFailures(comptime C: type) !void {
    const input = ("aaaaaaaaaaaaaaaa" ** 4) ++ "abcdefghijklmnopqrstuvwxyz" ++ ("abcabcabcabc" ** 8);
    const Run = struct {
        fn run(allocator: std.mem.Allocator, payload: []const u8) !void {
            const encoded = try C.encode(allocator, payload, C.options(.default), .{
                .min_block_len = 16,
                .max_block_len = 128,
                .sample_len = 8,
                .search_step = 16,
            });
            allocator.free(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Run.run, .{input});
}
