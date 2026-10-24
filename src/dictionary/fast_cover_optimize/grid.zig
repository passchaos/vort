const std = @import("std");
const fast = @import("../fast_cover.zig");
const types = @import("types.zig");

pub const Candidate = struct { options: fast.TrainOptions, serial: usize };
pub const Grid = struct {
    candidates: [types.maximum_candidates]Candidate = undefined,
    len: usize = 0,
};

pub fn splitSamples(samples: []const []const u8, split: types.SplitPoint) !types.Partitions {
    if (split.denominator == 0 or split.numerator == 0 or split.numerator > split.denominator)
        return error.InvalidDictionaryTraining;
    if (split.numerator == split.denominator) {
        if (samples.len < 5) return error.InvalidDictionaryTraining;
        return .{ .training = samples, .validation = samples };
    }
    const count: usize = @intCast(@as(u128, samples.len) * split.numerator / split.denominator);
    if (count < 5 or count == samples.len) return error.InvalidDictionaryTraining;
    return .{ .training = samples[0..count], .validation = samples[count..] };
}

pub fn validateParameters(options: types.OptimizeOptions) !void {
    _ = try build(options);
}

pub fn build(options: types.OptimizeOptions) !Grid {
    if (options.target_size == 0 or options.target_size > options.max_dictionary_size or options.target_size > std.math.maxInt(u32) or
        options.min_match_len == 0 or options.max_candidates == 0 or options.max_candidates > types.maximum_candidates or
        options.max_scoring_calls == 0 or options.max_samples == 0 or
        options.threads == 0 or options.max_threads == 0 or options.max_threads > types.maximum_threads or options.threads > options.max_threads or
        options.steps > types.maximum_candidates or options.regression_tolerance_bps > 10000 or options.shrink_min_size == 0 or
        options.dmer_sizes.len == 0 or options.dmer_sizes.len > types.maximum_candidates or options.hash_logs.len == 0 or options.hash_logs.len > types.maximum_candidates or
        options.accelerations.len == 0 or options.accelerations.len > types.maximum_candidates or options.segment_sizes.len > types.maximum_candidates)
        return error.InvalidDictionaryTraining;
    for (options.dmer_sizes) |d| if (d != 6 and d != 8) return error.InvalidDictionaryTraining;
    for (options.hash_logs) |f| if (f < fast.min_hash_log or f > fast.max_hash_log) return error.InvalidDictionaryTraining;
    for (options.accelerations) |acceleration| if (acceleration == 0 or acceleration > fast.max_acceleration) return error.InvalidDictionaryTraining;

    const low = options.segment_min orelse @min(options.target_size, 50);
    const high = options.segment_max orelse @min(options.target_size, 2000);
    if (low == 0 or high < low or high > options.target_size) return error.InvalidDictionaryTraining;
    var auto: [types.maximum_candidates]usize = undefined;
    const steps = if (options.steps == 0) 4 else options.steps;
    for (0..steps) |i| auto[i] = if (steps == 1) low else low + @as(usize, @intCast(@as(u128, high - low) * i / (steps - 1)));
    const segments = if (options.segment_sizes.len != 0) options.segment_sizes else auto[0..steps];
    for (segments) |k| if (k == 0 or k > options.target_size) return error.InvalidDictionaryTraining;

    var result = Grid{};
    for (options.dmer_sizes, 0..) |d, di| {
        if (earlier(u8, options.dmer_sizes, di)) continue;
        for (options.hash_logs, 0..) |f, fi| {
            if (earlier(u8, options.hash_logs, fi)) continue;
            for (options.accelerations, 0..) |acceleration, ai| {
                if (earlier(u8, options.accelerations, ai)) continue;
                for (segments, 0..) |k, ki| {
                    if (earlier(usize, segments, ki) or k < d) continue;
                    if (result.len == options.max_candidates) return error.InvalidDictionaryTraining;
                    result.candidates[result.len] = .{ .serial = result.len, .options = .{
                        .target_size = options.target_size,
                        .segment_size = k,
                        .dmer_size = d,
                        .hash_log = f,
                        .acceleration = acceleration,
                        .max_corpus_size = options.max_corpus_size,
                        .max_working_memory = options.max_working_memory,
                        .max_dictionary_size = options.max_dictionary_size,
                    } };
                    result.len += 1;
                }
            }
        }
    }
    if (result.len == 0) return error.InvalidDictionaryTraining;
    var sizes: [types.maximum_variants]usize = undefined;
    const variants = shrinkSizes(options.target_size, options, &sizes);
    const calls = std.math.mul(usize, result.len, variants + 1) catch return error.InvalidDictionaryTraining;
    if (calls > options.max_scoring_calls) return error.InvalidDictionaryTraining;
    return result;
}

pub fn validateCorpus(training: []const []const u8, validation: []const []const u8, options: types.OptimizeOptions) !usize {
    if (training.len < 5 or validation.len == 0) return error.InvalidDictionaryTraining;
    const same = training.ptr == validation.ptr and training.len == validation.len;
    const samples = if (same) training.len else std.math.add(usize, training.len, validation.len) catch return error.InvalidDictionaryTraining;
    if (samples > options.max_samples) return error.InvalidDictionaryTraining;
    var total: usize = 0;
    for (training) |sample| total = std.math.add(usize, total, sample.len) catch return error.InvalidDictionaryTraining;
    if (!same) for (validation) |sample| {
        total = std.math.add(usize, total, sample.len) catch return error.InvalidDictionaryTraining;
    };
    if (total > options.max_corpus_size or total > std.math.maxInt(u32)) return error.InvalidDictionaryTraining;
    var readable = false;
    for (training) |sample| if (sample.len >= 8) {
        readable = true;
    };
    if (!readable) return error.InvalidDictionaryTraining;
    return total;
}

pub fn sameGroup(a: Candidate, b: Candidate) bool {
    return a.options.dmer_size == b.options.dmer_size and a.options.hash_log == b.options.hash_log and a.options.acceleration == b.options.acceleration;
}

pub fn shrinkSizes(length: usize, options: types.OptimizeOptions, output: *[types.maximum_variants]usize) usize {
    if (!options.shrink_dictionary) return 0;
    var size = options.shrink_min_size;
    var count: usize = 0;
    while (size < length) {
        output[count] = size;
        count += 1;
        size = std.math.mul(usize, size, 2) catch break;
    }
    return count;
}

fn earlier(comptime T: type, values: []const T, index: usize) bool {
    for (values[0..index]) |value| if (value == values[index]) return true;
    return false;
}
