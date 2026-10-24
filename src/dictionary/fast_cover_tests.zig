const std = @import("std");
const fast = @import("fast_cover.zig");
const cover = @import("cover.zig");
const fixtures = @import("fast_cover_test_helpers.zig");
const allocator = fixtures.allocator;

test "FastCover contracts hashed frequencies and chosen segments match an independent slow oracle" {
    const storage = fixtures.randomCorpus();
    const samples = fixtures.views(&storage);
    inline for (.{ @as(u8, 6), @as(u8, 8) }) |d| {
        inline for (.{ @as(u8, 1), @as(u8, 8) }) |f| {
            for ([_]u8{ 1, 3 }) |acceleration| {
                var profile: fast.Profile = .{};
                const options: fast.TrainOptions = .{ .target_size = 37, .segment_size = 12, .dmer_size = d, .hash_log = f, .acceleration = acceleration, .profile = &profile };
                var expected = try fixtures.slow(&samples, options);
                defer expected.deinit();
                var prepared = try fast.Prepared.init(allocator, &samples, options);
                defer prepared.deinit(allocator);
                try std.testing.expectEqualSlices(u32, expected.base_frequencies, prepared.baseFrequencies());
                try std.testing.expectEqual(@as(u64, @intCast(expected.frequency_observations)), profile.frequency_hashes);
                const actual = try prepared.trainAlloc(allocator, options);
                defer allocator.free(actual);
                try std.testing.expectEqualSlices(u8, expected.bytes, actual);
                try std.testing.expectEqual(@as(u64, @intCast(expected.segments.items.len)), profile.selected_segments);
                try std.testing.expectEqual(@as(u64, @intCast(actual.len)), profile.selected_bytes);
                var cleared: usize = 0;
                for (expected.base_frequencies, expected.remaining_frequencies) |before, after| cleared += @intFromBool(before != 0 and after == 0);
                try std.testing.expectEqual(@as(u64, @intCast(cleared)), profile.frequency_clears);
                var copied_positions: usize = 0;
                for (expected.segments.items) |segment| {
                    try std.testing.expect(segment.begin + segment.length <= samples[segment.sample_index].len);
                    copied_positions += segment.length - d + 1;
                }
                try std.testing.expectEqual(@as(u64, @intCast(copied_positions)), profile.frequency_clear_positions);
            }
        }
    }
}

test "FastCover contracts acceleration changes observed frequency work and exact finalizer sample fractions" {
    const storage = fixtures.randomCorpus();
    const samples = fixtures.views(&storage);
    const percentages = [_]u8{ 100, 50, 34, 25, 20, 17, 14, 13, 11, 10 };
    var previous: u64 = std.math.maxInt(u64);
    for (1..11) |raw_acceleration| {
        const acceleration: u8 = @intCast(raw_acceleration);
        var profile: fast.Profile = .{};
        const options: fast.TrainOptions = .{ .target_size = 32, .segment_size = 12, .dmer_size = 6, .hash_log = 8, .acceleration = acceleration, .profile = &profile };
        var prepared = try fast.Prepared.init(allocator, &samples, options);
        defer prepared.deinit(allocator);
        var expected = try fixtures.slow(&samples, options);
        defer expected.deinit();
        try std.testing.expectEqualSlices(u32, expected.base_frequencies, prepared.baseFrequencies());
        try std.testing.expectEqual(@as(u64, 300), profile.frequency_positions);
        try std.testing.expectEqual(@as(u64, @intCast(expected.frequency_observations)), profile.frequency_hashes);
        try std.testing.expect(profile.frequency_hashes < previous);
        previous = profile.frequency_hashes;
        try std.testing.expectEqual(@as(u64, 300) - profile.frequency_hashes, profile.frequency_skipped_positions);
        for ([_]usize{ 0, 5, 13, std.math.maxInt(usize) }) |count| {
            const floor: usize = @intCast(@as(u128, count) * percentages[raw_acceleration - 1] / 100);
            try std.testing.expectEqual(floor, try fast.standardFinalizeSampleCount(count, acceleration));
        }
    }
    try std.testing.expectEqual(@as(usize, 0), try fast.standardFinalizeSampleCount(5, 10));
}

test "FastCover contracts frequency reads never cross tiny sample boundaries and old COVER remains distinct" {
    const short = [_][]const u8{ "abcdef", "1234567", "", "ABCDEFG", "987654" };
    try std.testing.expectError(error.InvalidDictionaryTraining, fast.trainAlloc(allocator, &short, .{ .target_size = 16, .segment_size = 8, .dmer_size = 6, .hash_log = 8 }));
    const samples = [_][]const u8{ "abcdef", "1234567", "", "ABCDEFGH", "987654" };
    var profile: fast.Profile = .{};
    const options: fast.TrainOptions = .{ .target_size = 16, .segment_size = 8, .dmer_size = 6, .hash_log = 8, .profile = &profile };
    var expected = try fixtures.slow(&samples, options);
    defer expected.deinit();
    const trained = try fast.trainAlloc(allocator, &samples, options);
    defer allocator.free(trained);
    try std.testing.expectEqualSlices(u8, expected.bytes, trained);
    try std.testing.expectEqual(@as(u64, 1), profile.frequency_hashes);
    const repeated = [_][]const u8{ "abcdefgh", "abcdefgh", "abcdefgh", "abcdefgh", "abcdefgh" };
    const old = try cover.trainAlloc(allocator, &repeated, .{ .target_size = 8, .segment_size = 8, .dmer_size = 6, .hash_log = 8 });
    defer allocator.free(old);
    try std.testing.expectEqualStrings("abcdefgh", old);
    const actual = try fast.trainAlloc(allocator, &repeated, .{ .target_size = 8, .segment_size = 8, .dmer_size = 6, .hash_log = 8 });
    defer allocator.free(actual);
    try std.testing.expectEqualStrings("abcdef", actual);
}

test "FastCover contracts all invalid scalar corpus and arithmetic bounds reject before allocation" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    const invalid = [_]fast.TrainOptions{
        .{ .target_size = 16, .dmer_size = 7 },
        .{ .target_size = 16, .hash_log = 0 },
        .{ .target_size = 16, .hash_log = 32 },
        .{ .target_size = 16, .acceleration = 0 },
        .{ .target_size = 16, .acceleration = 11 },
        .{ .target_size = 16, .segment_size = 5, .dmer_size = 6 },
        .{ .target_size = 16, .segment_size = 17 },
        .{ .target_size = 16, .max_dictionary_size = 15 },
        .{ .target_size = 16, .max_corpus_size = 0 },
        .{ .target_size = 0, .hash_log = 32 },
    };
    for (invalid) |options| try std.testing.expectError(error.InvalidDictionaryTraining, fast.trainAlloc(failing.allocator(), &fixtures.training, options));
    try std.testing.expectError(error.InvalidDictionaryTraining, fast.trainAlloc(failing.allocator(), fixtures.training[0..4], .{ .target_size = 16, .hash_log = 8 }));
    const fake = fixtures.training[0].ptr[0..std.math.maxInt(usize)];
    const overflow = [_][]const u8{ fake, "abcdefgh", "abcdefgh", "abcdefgh", "abcdefgh" };
    try std.testing.expectError(error.InvalidDictionaryTraining, fast.trainAlloc(failing.allocator(), &overflow, .{ .target_size = 16, .hash_log = 8, .max_corpus_size = std.math.maxInt(usize) }));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, fast.trainAlloc(failing.allocator(), &fixtures.training, .{ .target_size = 16, .hash_log = 31, .max_working_memory = 1024 * 1024 }));
    const empty = try fast.trainAlloc(failing.allocator(), &.{}, .{ .target_size = 0, .segment_size = 0, .max_working_memory = 0, .max_dictionary_size = 0, .max_corpus_size = 0 });
    defer failing.allocator().free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, fast.trainAlloc(failing.allocator(), &fixtures.training, .{ .target_size = 16, .hash_log = 8, .max_working_memory = 0 }));
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
}

test "FastCover contracts prepared reset fork and poisoned value move preserve selection" {
    const storage = fixtures.randomCorpus();
    const samples = fixtures.views(&storage);
    const options: fast.TrainOptions = .{ .target_size = 48, .segment_size = 12, .dmer_size = 6, .hash_log = 8 };
    var expected = try fixtures.slow(&samples, options);
    defer expected.deinit();
    var original = try fast.Prepared.init(allocator, &samples, options);
    const first = try original.trainAlloc(allocator, options);
    defer allocator.free(first);
    try std.testing.expectEqualSlices(u8, expected.bytes, first);
    const retained = original.workingBytes();
    var prepared = original;
    @memset(std.mem.asBytes(&original), 0xa5);
    defer prepared.deinit(allocator);
    const second = try prepared.trainAlloc(allocator, options);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);
    try std.testing.expectEqual(@as(u64, 1), prepared.profile.frequency_passes);
    try std.testing.expect(prepared.profile.prepared_reuses != 0);
    var fork = try prepared.fork(allocator, options.max_working_memory);
    defer fork.deinit(allocator);
    try std.testing.expectEqualSlices(u32, prepared.baseFrequencies(), fork.baseFrequencies());
    try std.testing.expectEqual(@as(u64, 0), fork.profile.frequency_passes);
    const from_fork = try fork.trainAlloc(allocator, options);
    defer allocator.free(from_fork);
    try std.testing.expectEqualSlices(u8, first, from_fork);
    prepared.reset();
    try std.testing.expectEqual(retained, prepared.workingBytes());
    try std.testing.expectError(error.InvalidDictionaryTraining, prepared.trainAlloc(allocator, options));
    try prepared.prepare(allocator, &samples, options);
    const reset = try prepared.trainAlloc(allocator, options);
    defer allocator.free(reset);
    try std.testing.expectEqualSlices(u8, first, reset);
}

test "FastCover contracts large same bucket windows use counters wider than sixteen bits" {
    const sample = try allocator.alloc(u8, 80_000);
    defer allocator.free(sample);
    @memset(sample, 'A');
    const samples = [_][]const u8{ sample, sample, sample, sample, sample };
    var profile: fast.Profile = .{};
    const trained = try fast.trainAlloc(allocator, &samples, .{ .target_size = 70_000, .segment_size = 70_000, .hash_log = 1, .dmer_size = 8, .profile = &profile });
    defer allocator.free(trained);
    try std.testing.expectEqualStrings("AAAAAAAA", trained);
    try std.testing.expect(profile.active_adds > 65535 and profile.active_removes > 65535);
    try std.testing.expectEqual(profile.active_adds, profile.active_removes);
}

const optimize = @import("fast_cover_optimize.zig");

test "FastCover optimizer contracts chooses the best independently enumerated held out cost and folds duplicates" {
    const options: optimize.OptimizeOptions = .{
        .target_size = 64,
        .segment_sizes = &.{ 8, 16, 16, 32, 8 },
        .dmer_sizes = &.{ 6, 8, 6 },
        .hash_logs = &.{ 8, 8 },
        .accelerations = &.{ 1, 2, 1 },
    };
    var result = try optimize.trainAllocWithScorer(allocator, &fixtures.training, &fixtures.validation, options, fixtures.score);
    defer result.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 12), result.candidates_evaluated);
    try std.testing.expectEqual(@as(u64, 4), result.profile.prepared_groups);
    try std.testing.expectEqual(@as(u64, 4), result.profile.training.frequency_passes);
    var best: ?[]u8 = null;
    defer if (best) |bytes| allocator.free(bytes);
    var best_score: optimize.Score = .{};
    var best_serial: usize = 0;
    var serial: usize = 0;
    for ([_]u8{ 6, 8 }) |d| for ([_]u8{ 1, 2 }) |acceleration| for ([_]usize{ 8, 16, 32 }) |k| {
        var candidate = try fixtures.slow(&fixtures.training, .{ .target_size = 64, .segment_size = k, .dmer_size = d, .hash_log = 8, .acceleration = acceleration });
        defer candidate.deinit();
        const score = try fixtures.score(candidate.bytes, &fixtures.validation, 4);
        if (best == null or fixtures.better(score, candidate.bytes.len, serial, best_score, best.?.len, best_serial)) {
            if (best) |bytes| allocator.free(bytes);
            best = try allocator.dupe(u8, candidate.bytes);
            best_score = score;
            best_serial = serial;
        }
        serial += 1;
    };
    try std.testing.expectEqualSlices(u8, best.?, result.bytes);
    try std.testing.expectEqualDeep(best_score, result.validation_score);
    try std.testing.expectEqualDeep(try fixtures.score(result.bytes, &fixtures.validation, 4), result.validation_score);
    try std.testing.expect(result.selected_options.profile == null);
}

test "FastCover optimizer contracts automatic endpoints and serial parallel selection are deterministic" {
    const automatic: optimize.OptimizeOptions = .{ .target_size = 64, .segment_min = 8, .segment_max = 32, .steps = 3, .dmer_sizes = &.{8}, .hash_logs = &.{8} };
    var first = try optimize.trainAllocWithScorerFactory(allocator, &fixtures.training, &fixtures.validation, automatic, {}, fixtures.PlainScorer);
    defer first.deinit(allocator);
    var explicit = automatic;
    explicit.segment_sizes = &.{ 8, 20, 32 };
    var second = try optimize.trainAllocWithScorerFactory(allocator, &fixtures.training, &fixtures.validation, explicit, {}, fixtures.PlainScorer);
    defer second.deinit(allocator);
    try std.testing.expectEqualSlices(u8, first.bytes, second.bytes);
    try std.testing.expectEqualDeep(first.validation_score, second.validation_score);
    try std.testing.expectEqual(@as(usize, 3), first.candidates_evaluated);
    explicit.threads = 2;
    var parallel = try optimize.trainAllocWithScorerFactory(allocator, &fixtures.training, &fixtures.validation, explicit, {}, fixtures.PlainScorer);
    defer parallel.deinit(allocator);
    try std.testing.expectEqualSlices(u8, second.bytes, parallel.bytes);
    try std.testing.expectEqualDeep(second.validation_score, parallel.validation_score);
    try std.testing.expectEqualDeep(second.selected_options, parallel.selected_options);
    try std.testing.expectEqual(@as(u64, 1), parallel.profile.training.frequency_passes);
    try std.testing.expect(parallel.profile.training.prepared_forks != 0);
    try std.testing.expect(parallel.profile.peak_working_memory >= parallel.profile.peak_allocator_owned_bytes);
    if (parallel.profile.threads_used > 1) try std.testing.expect(parallel.profile.thread_stack_reservation_peak != 0);
    const corpus = fixtures.training ++ fixtures.validation;
    const split = try optimize.splitSamples(&corpus, .{ .numerator = 3, .denominator = 4 });
    try std.testing.expectEqual(@as(usize, 6), split.training.len);
    try std.testing.expectEqual(@as(usize, 2), split.validation.len);
    const shared = try optimize.splitSamples(&corpus, .{ .numerator = 1, .denominator = 1 });
    try std.testing.expect(shared.training.ptr == shared.validation.ptr and shared.training.len == shared.validation.len);
    try std.testing.expectError(error.InvalidDictionaryTraining, optimize.splitSamples(&corpus, .{ .numerator = 1, .denominator = 8 }));
}

test "FastCover optimizer contracts suffix shrink is bounded by the global full dictionary baseline" {
    const full_options: optimize.OptimizeOptions = .{ .target_size = 64, .segment_sizes = &.{ 8, 16, 32 }, .dmer_sizes = &.{8}, .hash_logs = &.{8} };
    var full = try optimize.trainAllocWithScorer(allocator, &fixtures.training, &fixtures.validation, full_options, fixtures.score);
    defer full.deinit(allocator);
    var options = full_options;
    options.shrink_dictionary = true;
    options.shrink_min_size = 8;
    options.regression_tolerance_bps = 0;
    var shrunk = try optimize.trainAllocWithScorer(allocator, &fixtures.training, &fixtures.validation, options, fixtures.score);
    defer shrunk.deinit(allocator);
    try std.testing.expect(shrunk.bytes.len <= full.bytes.len);
    try std.testing.expect(shrunk.validation_score.estimated_bits <= full.validation_score.estimated_bits);
    try std.testing.expectEqualDeep(try fixtures.score(shrunk.bytes, &fixtures.validation, 4), shrunk.validation_score);
    try std.testing.expect(shrunk.original_dictionary_size >= shrunk.bytes.len);
    options.regression_tolerance_bps = 10000;
    var relaxed = try optimize.trainAllocWithScorer(allocator, &fixtures.training, &fixtures.validation, options, fixtures.score);
    defer relaxed.deinit(allocator);
    try std.testing.expect(relaxed.bytes.len <= shrunk.bytes.len);
    try std.testing.expect(@as(u128, relaxed.validation_score.estimated_bits) * 10000 <= @as(u128, full.validation_score.estimated_bits) * 20000);
    try std.testing.expect(relaxed.profile.shrink_evaluations != 0);
    try std.testing.expectEqualDeep(try fixtures.score(relaxed.bytes, &fixtures.validation, 4), relaxed.validation_score);
}

test "FastCover optimizer contracts invalid grids partitions and scoring errors are explicit" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    const bad = [_]optimize.OptimizeOptions{
        .{ .target_size = 0 },                           .{ .target_size = 64, .dmer_sizes = &.{7} },
        .{ .target_size = 64, .hash_logs = &.{0} },      .{ .target_size = 64, .accelerations = &.{0} },
        .{ .target_size = 64, .accelerations = &.{11} }, .{ .target_size = 64, .segment_sizes = &.{0} },
        .{ .target_size = 64, .segment_sizes = &.{65} }, .{ .target_size = 64, .max_candidates = 0 },
        .{ .target_size = 64, .max_candidates = 257 },   .{ .target_size = 64, .threads = 0 },
        .{ .target_size = 64, .threads = 17 },           .{ .target_size = 64, .steps = 257 },
        .{ .target_size = 64, .shrink_min_size = 0 },    .{ .target_size = 64, .regression_tolerance_bps = 10001 },
        .{ .target_size = 64, .max_samples = 1 },        .{ .target_size = 64, .max_scoring_calls = 1 },
    };
    for (bad) |options| try std.testing.expectError(error.InvalidDictionaryTraining, optimize.trainAllocWithScorerFactory(failing.allocator(), &fixtures.training, &fixtures.validation, options, {}, fixtures.PlainScorer));
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    const Broken = struct {
        pub fn init(_: std.mem.Allocator, _: void, _: []const []const u8, _: []const []const u8, _: optimize.OptimizeOptions) !@This() {
            return .{};
        }
        pub fn score(_: *@This(), _: []const u8, _: []const []const u8, _: usize, _: fast.TrainOptions) !optimize.Score {
            return error.TestScoringFailure;
        }
        pub fn deinit(_: *@This()) void {}
    };
    try std.testing.expectError(error.TestScoringFailure, optimize.trainAllocWithScorerFactory(allocator, &fixtures.training, &fixtures.validation, .{ .target_size = 64, .segment_sizes = &.{ 8, 16 }, .dmer_sizes = &.{8}, .hash_logs = &.{8}, .threads = 2 }, {}, Broken));
}
