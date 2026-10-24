const std = @import("std");
const cover = @import("cover.zig");

const default_dmer_sizes = [_]u8{ 6, 8 };
const default_hash_logs = [_]u8{ 12, 16 };
const maximum_candidate_limit: usize = 256;

const Candidate = struct {
    options: cover.TrainOptions,
    serial: usize,
};

/// Parameter grid and resource limits for held-out COVER-class selection.
/// Empty `segment_sizes` selects the bounded automatic ladder
/// `min(target_size, 32/64/128/256)` with duplicate values collapsed.
pub const OptimizeOptions = struct {
    target_size: usize,
    segment_sizes: []const usize = &.{},
    dmer_sizes: []const u8 = &default_dmer_sizes,
    hash_logs: []const u8 = &default_hash_logs,
    min_match_len: usize = 4,
    /// Bounds the training and validation partitions independently.
    max_corpus_size: usize = cover.default_max_corpus_size,
    max_candidates: usize = 32,
};

pub const Score = struct {
    estimated_bits: usize = 0,
    covered_bytes: usize = 0,
    matches: usize = 0,
    distance_bits: usize = 0,
};

pub const OwnedResult = struct {
    bytes: []u8,
    selected_options: cover.TrainOptions,
    validation_score: Score,
    candidates_evaluated: usize,

    pub fn deinit(self: OwnedResult, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

/// Train every unique compatible grid point and retain the best held-out
/// score. `scoreFn` is supplied by the parent dictionary module so this module
/// remains independent of its concrete match-cost implementation.
pub fn trainAllocWithScorer(
    allocator: std.mem.Allocator,
    training_samples: []const []const u8,
    validation_samples: []const []const u8,
    options: OptimizeOptions,
    comptime scoreFn: anytype,
) !OwnedResult {
    const Adapter = struct {
        fn score(_: void, dictionary: []const u8, samples: []const []const u8, min_match_len: usize) !Score {
            return scoreFn(dictionary, samples, min_match_len);
        }
    };
    return trainAllocWithScorerContext(
        allocator,
        training_samples,
        validation_samples,
        options,
        {},
        Adapter.score,
    );
}

/// Stateful scorer variant used when candidate evaluation has reusable scratch.
/// `scorerContext` is passed to `scoreFn` before the dictionary arguments.
pub fn trainAllocWithScorerContext(
    allocator: std.mem.Allocator,
    training_samples: []const []const u8,
    validation_samples: []const []const u8,
    options: OptimizeOptions,
    scorer_context: anytype,
    comptime scoreFn: anytype,
) !OwnedResult {
    const auto_segments = [_]usize{
        @min(options.target_size, 32),
        @min(options.target_size, 64),
        @min(options.target_size, 128),
        @min(options.target_size, 256),
    };
    const segment_sizes = if (options.segment_sizes.len == 0) auto_segments[0..] else options.segment_sizes;
    try validateOptions(training_samples, validation_samples, segment_sizes, options);

    var candidates: [maximum_candidate_limit]Candidate = undefined;
    var candidate_count: usize = 0;
    for (options.dmer_sizes, 0..) |dmer_size, dmer_index| {
        if (hasEarlier(u8, options.dmer_sizes, dmer_index)) continue;
        if (!corpusHasDmer(training_samples, dmer_size)) continue;
        for (segment_sizes, 0..) |segment_size, segment_index| {
            if (hasEarlier(usize, segment_sizes, segment_index) or segment_size < dmer_size) continue;
            for (options.hash_logs, 0..) |_, hash_index| {
                if (hasEarlier(u8, options.hash_logs, hash_index)) continue;
                if (candidate_count == options.max_candidates) return error.InvalidDictionaryTraining;
                const hash_log = options.hash_logs[hash_index];
                candidates[candidate_count] = .{
                    .options = .{
                        .target_size = options.target_size,
                        .segment_size = segment_size,
                        .dmer_size = dmer_size,
                        .hash_log = hash_log,
                        .max_corpus_size = options.max_corpus_size,
                    },
                    .serial = candidate_count,
                };
                candidate_count += 1;
            }
        }
    }
    if (candidate_count == 0) return error.InvalidDictionaryTraining;

    var best_bytes: ?[]u8 = null;
    errdefer if (best_bytes) |bytes| allocator.free(bytes);
    var best_score: Score = .{};
    var best_options: cover.TrainOptions = undefined;
    var best_serial: usize = std.math.maxInt(usize);
    var candidates_evaluated: usize = 0;

    for (candidates[0..candidate_count], 0..) |group, group_index| {
        if (hasEarlierGroup(candidates[0..candidate_count], group_index)) continue;
        var prepared = try cover.Prepared.init(
            allocator,
            training_samples,
            group.options.dmer_size,
            group.options.hash_log,
            options.max_corpus_size,
        );
        defer prepared.deinit(allocator);
        for (candidates[0..candidate_count]) |candidate_spec| {
            if (candidate_spec.options.dmer_size != group.options.dmer_size or
                candidate_spec.options.hash_log != group.options.hash_log) continue;
            const candidate = try prepared.trainAlloc(
                allocator,
                candidate_spec.options.target_size,
                candidate_spec.options.segment_size.?,
            );
            const raw_score = scoreFn(scorer_context, candidate, validation_samples, options.min_match_len) catch |err| {
                allocator.free(candidate);
                return err;
            };
            const score: Score = .{
                .estimated_bits = raw_score.estimated_bits,
                .covered_bytes = raw_score.covered_bytes,
                .matches = raw_score.matches,
                .distance_bits = raw_score.distance_bits,
            };
            candidates_evaluated += 1;
            if (best_bytes == null or scoreBetter(score, best_score) or
                (std.meta.eql(score, best_score) and candidate_spec.serial < best_serial))
            {
                if (best_bytes) |bytes| allocator.free(bytes);
                best_bytes = candidate;
                best_score = score;
                best_options = candidate_spec.options;
                best_serial = candidate_spec.serial;
            } else allocator.free(candidate);
        }
    }

    return .{
        .bytes = best_bytes.?,
        .selected_options = best_options,
        .validation_score = best_score,
        .candidates_evaluated = candidates_evaluated,
    };
}

fn validateOptions(
    training_samples: []const []const u8,
    validation_samples: []const []const u8,
    segment_sizes: []const usize,
    options: OptimizeOptions,
) !void {
    if (training_samples.len < 5 or validation_samples.len == 0) return error.InvalidDictionaryTraining;
    if (options.target_size == 0 or options.min_match_len == 0) return error.InvalidDictionaryTraining;
    if (options.max_corpus_size == 0) return error.InvalidDictionaryTraining;
    if (options.max_candidates == 0 or options.max_candidates > maximum_candidate_limit)
        return error.InvalidDictionaryTraining;
    if (segment_sizes.len == 0 or options.dmer_sizes.len == 0 or options.hash_logs.len == 0)
        return error.InvalidDictionaryTraining;
    if (segment_sizes.len > maximum_candidate_limit or
        options.dmer_sizes.len > maximum_candidate_limit or
        options.hash_logs.len > maximum_candidate_limit)
        return error.InvalidDictionaryTraining;

    for (segment_sizes) |segment_size| {
        if (segment_size == 0 or segment_size > options.target_size) return error.InvalidDictionaryTraining;
    }
    for (options.dmer_sizes) |dmer_size| {
        if (dmer_size != 6 and dmer_size != 8) return error.InvalidDictionaryTraining;
    }
    for (options.hash_logs) |hash_log| {
        if (hash_log < cover.min_hash_log or hash_log > cover.max_hash_log)
            return error.InvalidDictionaryTraining;
    }

    try validateCorpusSize(training_samples, options.max_corpus_size);
    try validateCorpusSize(validation_samples, options.max_corpus_size);
}

fn validateCorpusSize(samples: []const []const u8, maximum: usize) !void {
    var total_size: usize = 0;
    for (samples) |sample|
        total_size = std.math.add(usize, total_size, sample.len) catch return error.InvalidDictionaryTraining;
    if (total_size > maximum or total_size > std.math.maxInt(u32))
        return error.InvalidDictionaryTraining;
}

fn hasEarlier(comptime T: type, values: []const T, index: usize) bool {
    for (values[0..index]) |value| if (value == values[index]) return true;
    return false;
}

fn hasEarlierGroup(candidates: []const Candidate, index: usize) bool {
    const current = candidates[index].options;
    for (candidates[0..index]) |candidate| {
        if (candidate.options.dmer_size == current.dmer_size and
            candidate.options.hash_log == current.hash_log) return true;
    }
    return false;
}

fn corpusHasDmer(samples: []const []const u8, dmer_size: usize) bool {
    for (samples) |sample| if (sample.len >= dmer_size) return true;
    return false;
}

fn scoreBetter(candidate: Score, best: Score) bool {
    return candidate.estimated_bits < best.estimated_bits or
        (candidate.estimated_bits == best.estimated_bits and candidate.covered_bytes > best.covered_bytes) or
        (candidate.estimated_bits == best.estimated_bits and candidate.covered_bytes == best.covered_bytes and candidate.matches < best.matches) or
        (candidate.estimated_bits == best.estimated_bits and candidate.covered_bytes == best.covered_bytes and candidate.matches == best.matches and candidate.distance_bits < best.distance_bits);
}

fn testScore(dictionary: []const u8, samples: []const []const u8, min_match_len: usize) !Score {
    var score: Score = .{ .estimated_bits = dictionary.len * 8 };
    for (samples) |sample| {
        var offset: usize = 0;
        var sample_covered: usize = 0;
        while (offset + min_match_len <= sample.len) {
            var best_len: usize = 0;
            for (0..dictionary.len) |dictionary_offset| {
                var len: usize = 0;
                while (dictionary_offset + len < dictionary.len and offset + len < sample.len and
                    dictionary[dictionary_offset + len] == sample[offset + len]) : (len += 1)
                {}
                best_len = @max(best_len, len);
            }
            if (best_len >= min_match_len) {
                score.covered_bytes += best_len;
                sample_covered += best_len;
                score.matches += 1;
                offset += best_len;
            } else offset += 1;
        }
        score.estimated_bits += (sample.len - sample_covered) * 8;
    }
    return score;
}

fn trainSeparateForTest(
    allocator: std.mem.Allocator,
    training_samples: []const []const u8,
    validation_samples: []const []const u8,
    options: OptimizeOptions,
) !OwnedResult {
    var best_bytes: ?[]u8 = null;
    errdefer if (best_bytes) |bytes| allocator.free(bytes);
    var best_options: cover.TrainOptions = undefined;
    var best_score: Score = .{};
    var count: usize = 0;
    for (options.dmer_sizes) |dmer_size| {
        for (options.segment_sizes) |segment_size| {
            if (segment_size < dmer_size) continue;
            for (options.hash_logs) |hash_log| {
                const candidate_options: cover.TrainOptions = .{
                    .target_size = options.target_size,
                    .segment_size = segment_size,
                    .dmer_size = dmer_size,
                    .hash_log = hash_log,
                    .max_corpus_size = options.max_corpus_size,
                };
                const candidate = try cover.trainAlloc(allocator, training_samples, candidate_options);
                const score = testScore(candidate, validation_samples, options.min_match_len) catch |err| {
                    allocator.free(candidate);
                    return err;
                };
                count += 1;
                if (best_bytes == null or scoreBetter(score, best_score)) {
                    if (best_bytes) |bytes| allocator.free(bytes);
                    best_bytes = candidate;
                    best_options = candidate_options;
                    best_score = score;
                } else allocator.free(candidate);
            }
        }
    }
    return .{
        .bytes = best_bytes.?,
        .selected_options = best_options,
        .validation_score = best_score,
        .candidates_evaluated = count,
    };
}

test "COVER-class optimizer collapses duplicate grid points and preserves first ties" {
    const training = [_][]const u8{ "abcdefgh", "abcdefgh", "abcdefgh", "abcdefgh", "abcdefgh" };
    const validation = [_][]const u8{"abcdefgh"};
    var optimized = try trainAllocWithScorer(
        std.testing.allocator,
        &training,
        &validation,
        .{
            .target_size = 8,
            .segment_sizes = &.{ 8, 8 },
            .dmer_sizes = &.{ 6, 8, 6 },
            .hash_logs = &.{ 8, 9, 8 },
        },
        testScore,
    );
    defer optimized.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 4), optimized.candidates_evaluated);
    try std.testing.expectEqual(@as(u8, 6), optimized.selected_options.dmer_size);
    try std.testing.expectEqual(@as(u8, 8), optimized.selected_options.hash_log);
    try std.testing.expectEqual(@as(?usize, 8), optimized.selected_options.segment_size);
    try std.testing.expectEqualSlices(u8, "abcdefgh", optimized.bytes);
}

test "COVER-class optimizer automatic segment ladder is bounded and deterministic" {
    const sample = "abcdefgh-01234567-ABCDEFGH-76543210";
    const training = [_][]const u8{ sample, sample, sample, sample, sample };
    const validation = [_][]const u8{sample};
    var first = try trainAllocWithScorer(
        std.testing.allocator,
        &training,
        &validation,
        .{ .target_size = 64 },
        testScore,
    );
    defer first.deinit(std.testing.allocator);
    var second = try trainAllocWithScorer(
        std.testing.allocator,
        &training,
        &validation,
        .{ .target_size = 64 },
        testScore,
    );
    defer second.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 8), first.candidates_evaluated);
    try std.testing.expectEqual(first.selected_options, second.selected_options);
    try std.testing.expectEqual(first.validation_score, second.validation_score);
    try std.testing.expectEqualSlices(u8, first.bytes, second.bytes);
}

test "COVER-class optimizer shared contexts match separate training oracle" {
    var storage: [7][80]u8 = undefined;
    var state: u32 = 0x243f_6a88;
    for (&storage, 0..) |*sample, sample_index| {
        for (sample, 0..) |*byte, offset| {
            state = state *% 1_664_525 +% 1_013_904_223;
            byte.* = if (offset % 17 < 12)
                "shared-cover-history"[(offset + sample_index * 3) % 20]
            else
                @truncate(state >> 24);
        }
    }
    const training = [_][]const u8{ &storage[0], &storage[1], &storage[2], &storage[3], &storage[4] };
    const validation = [_][]const u8{ &storage[5], &storage[6] };
    const options: OptimizeOptions = .{
        .target_size = 48,
        .segment_sizes = &.{ 12, 24 },
        .dmer_sizes = &.{ 6, 8 },
        .hash_logs = &.{ 8, 10 },
    };
    var expected = try trainSeparateForTest(std.testing.allocator, &training, &validation, options);
    defer expected.deinit(std.testing.allocator);
    var actual = try trainAllocWithScorer(
        std.testing.allocator,
        &training,
        &validation,
        options,
        testScore,
    );
    defer actual.deinit(std.testing.allocator);
    try std.testing.expectEqual(expected.selected_options, actual.selected_options);
    try std.testing.expectEqual(expected.validation_score, actual.validation_score);
    try std.testing.expectEqual(expected.candidates_evaluated, actual.candidates_evaluated);
    try std.testing.expectEqualSlices(u8, expected.bytes, actual.bytes);
}

test "COVER-class optimizer validates grid and candidate limits" {
    const training = [_][]const u8{ "abcdefgh", "abcdefgh", "abcdefgh", "abcdefgh", "abcdefgh" };
    const validation = [_][]const u8{"abcdefgh"};
    try std.testing.expectError(error.InvalidDictionaryTraining, trainAllocWithScorer(
        std.testing.allocator,
        training[0..4],
        &validation,
        .{ .target_size = 8 },
        testScore,
    ));
    try std.testing.expectError(error.InvalidDictionaryTraining, trainAllocWithScorer(
        std.testing.allocator,
        &training,
        &.{},
        .{ .target_size = 8 },
        testScore,
    ));
    try std.testing.expectError(error.InvalidDictionaryTraining, trainAllocWithScorer(
        std.testing.allocator,
        &training,
        &validation,
        .{ .target_size = 8, .dmer_sizes = &.{7} },
        testScore,
    ));
    try std.testing.expectError(error.InvalidDictionaryTraining, trainAllocWithScorer(
        std.testing.allocator,
        &training,
        &validation,
        .{ .target_size = 8, .max_candidates = 1 },
        testScore,
    ));
    try std.testing.expectError(error.InvalidDictionaryTraining, trainAllocWithScorer(
        std.testing.allocator,
        &training,
        &validation,
        .{ .target_size = 8, .max_corpus_size = 7 },
        testScore,
    ));
}

test "COVER-class optimizer releases every allocation failure path" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const training = [_][]const u8{ "abcdefghijklmnop", "abcdefghijklmnop", "abcdefghijklmnop", "abcdefghijklmnop", "abcdefghijklmnop" };
            const validation = [_][]const u8{"abcdefghijklmnop"};
            var optimized = try trainAllocWithScorer(
                allocator,
                &training,
                &validation,
                .{
                    .target_size = 16,
                    .segment_sizes = &.{ 8, 16 },
                    .dmer_sizes = &.{6},
                    .hash_logs = &.{8},
                },
                testScore,
            );
            defer optimized.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}
