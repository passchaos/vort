const std = @import("std");

pub const min_hash_log: u8 = 8;
pub const max_hash_log: u8 = 20;
pub const default_max_corpus_size: usize = 256 * 1024 * 1024;

/// Parameters for the deterministic COVER-class history selector.
///
/// This implements the central COVER/FastCover selection heuristic, but does
/// not promise byte-identical output with any particular libzstd release. In
/// particular, candidates never cross a caller-provided sample boundary.
pub const TrainOptions = struct {
    /// Maximum number of history bytes returned to the caller.
    target_size: usize,
    /// Candidate segment size (`k` in COVER literature). When omitted, the
    /// selector uses `min(target_size, 64)`.
    segment_size: ?usize = null,
    /// D-mer width (`d`), restricted to the widths used by Zstandard COVER.
    dmer_size: u8 = 8,
    /// Base-two frequency-table size. The two working tables contain
    /// `2 ** hash_log` `u32` entries each.
    hash_log: u8 = 16,
    /// Reject larger corpora before allocating the frequency tables.
    max_corpus_size: usize = default_max_corpus_size,
};

const Epochs = struct {
    count: usize,
    size: usize,
};

const Segment = struct {
    sample_index: usize = 0,
    begin: usize = 0,
    end: usize = 0,
    score: u64 = 0,
};

/// Select dictionary history with a deterministic COVER-class heuristic.
///
/// The score of a candidate is the sum of corpus frequencies for the distinct
/// d-mer hashes it contains. Selecting a segment zeros those frequencies, and
/// epochs are visited cyclically until the output is full or no useful segment
/// remains. Strict-greater comparisons make equal-score ties stable and favor
/// the earliest sample and offset.
pub fn trainAlloc(
    allocator: std.mem.Allocator,
    samples: []const []const u8,
    options: TrainOptions,
) ![]u8 {
    if (options.target_size == 0) return allocator.alloc(u8, 0);

    const parameters = try validateOptions(samples, options);
    const table_len = @as(usize, 1) << @intCast(options.hash_log);

    const offset_count = std.math.add(usize, samples.len, 1) catch return error.InvalidDictionaryTraining;
    const dmer_offsets = try allocator.alloc(usize, offset_count);
    defer allocator.free(dmer_offsets);
    dmer_offsets[0] = 0;
    for (samples, 0..) |sample, index| {
        const count = dmerCount(sample.len, parameters.dmer_size);
        dmer_offsets[index + 1] = std.math.add(usize, dmer_offsets[index], count) catch
            return error.InvalidDictionaryTraining;
    }
    const total_dmers = dmer_offsets[samples.len];
    if (total_dmers == 0) return error.InvalidDictionaryTraining;

    const frequencies = try allocator.alloc(u32, table_len);
    defer allocator.free(frequencies);
    @memset(frequencies, 0);
    collectFrequencies(samples, parameters.dmer_size, options.hash_log, frequencies);

    const active_counts = try allocator.alloc(u32, table_len);
    defer allocator.free(active_counts);
    @memset(active_counts, 0);

    return buildDictionaryAlloc(
        allocator,
        samples,
        dmer_offsets,
        options.target_size,
        parameters.segment_size,
        parameters.dmer_size,
        options.hash_log,
        frequencies,
        active_counts,
    );
}

/// Reusable d-mer corpus state for evaluating several segment sizes with the
/// same `(d, hash_log)`. The sample slices remain borrowed for this object's
/// lifetime. `trainAlloc` resets all mutable tables before every candidate, so
/// an allocation failure does not poison later calls.
pub const Prepared = struct {
    samples: []const []const u8,
    dmer_offsets: []usize,
    base_frequencies: []u32,
    frequencies: []u32,
    active_counts: []u32,
    dmer_size: usize,
    hash_log: u8,

    pub fn init(
        allocator: std.mem.Allocator,
        samples: []const []const u8,
        dmer_size_value: u8,
        hash_log: u8,
        max_corpus_size: usize,
    ) !Prepared {
        try validateCorpusParameters(samples, dmer_size_value, hash_log, max_corpus_size);
        const dmer_size: usize = dmer_size_value;
        const offset_count = std.math.add(usize, samples.len, 1) catch return error.InvalidDictionaryTraining;
        const dmer_offsets = try allocator.alloc(usize, offset_count);
        errdefer allocator.free(dmer_offsets);
        dmer_offsets[0] = 0;
        for (samples, 0..) |sample, index| {
            const count = dmerCount(sample.len, dmer_size);
            dmer_offsets[index + 1] = std.math.add(usize, dmer_offsets[index], count) catch
                return error.InvalidDictionaryTraining;
        }
        if (dmer_offsets[samples.len] == 0) return error.InvalidDictionaryTraining;

        const table_len = @as(usize, 1) << @intCast(hash_log);
        const base_frequencies = try allocator.alloc(u32, table_len);
        errdefer allocator.free(base_frequencies);
        @memset(base_frequencies, 0);
        collectFrequencies(samples, dmer_size, hash_log, base_frequencies);
        const frequencies = try allocator.alloc(u32, table_len);
        errdefer allocator.free(frequencies);
        const active_counts = try allocator.alloc(u32, table_len);
        errdefer allocator.free(active_counts);
        return .{
            .samples = samples,
            .dmer_offsets = dmer_offsets,
            .base_frequencies = base_frequencies,
            .frequencies = frequencies,
            .active_counts = active_counts,
            .dmer_size = dmer_size,
            .hash_log = hash_log,
        };
    }

    pub fn deinit(self: *Prepared, allocator: std.mem.Allocator) void {
        allocator.free(self.dmer_offsets);
        allocator.free(self.base_frequencies);
        allocator.free(self.frequencies);
        allocator.free(self.active_counts);
        self.* = undefined;
    }

    pub fn trainAlloc(
        self: *Prepared,
        allocator: std.mem.Allocator,
        target_size: usize,
        segment_size: usize,
    ) ![]u8 {
        if (target_size == 0) return allocator.alloc(u8, 0);
        if (segment_size < self.dmer_size or segment_size > target_size)
            return error.InvalidDictionaryTraining;
        @memcpy(self.frequencies, self.base_frequencies);
        @memset(self.active_counts, 0);
        return buildDictionaryAlloc(
            allocator,
            self.samples,
            self.dmer_offsets,
            target_size,
            segment_size,
            self.dmer_size,
            self.hash_log,
            self.frequencies,
            self.active_counts,
        );
    }
};

fn buildDictionaryAlloc(
    allocator: std.mem.Allocator,
    samples: []const []const u8,
    dmer_offsets: []const usize,
    target_size: usize,
    segment_size: usize,
    dmer_size: usize,
    hash_log: u8,
    frequencies: []u32,
    active_counts: []u32,
) ![]u8 {
    std.debug.assert(target_size != 0);
    std.debug.assert(dmer_offsets[samples.len] != 0);

    const output = try allocator.alloc(u8, target_size);
    errdefer allocator.free(output);
    var tail = output.len;
    const epochs = computeEpochs(target_size, dmer_offsets[samples.len], segment_size);
    var epoch_index: usize = 0;
    var zero_score_run: usize = 0;
    const max_zero_score_run: usize = 10;

    while (tail != 0) {
        const epoch_begin = epoch_index * epochs.size;
        const epoch_end = epoch_begin + epochs.size;
        const segment = selectEpoch(
            samples,
            dmer_offsets,
            epoch_begin,
            epoch_end,
            segment_size,
            dmer_size,
            hash_log,
            frequencies,
            active_counts,
        );
        epoch_index = (epoch_index + 1) % epochs.count;

        if (segment.score == 0) {
            zero_score_run += 1;
            if (zero_score_run >= max_zero_score_run) break;
            continue;
        }
        zero_score_run = 0;
        zeroSegmentFrequencies(
            samples[segment.sample_index],
            segment,
            dmer_size,
            hash_log,
            frequencies,
        );

        const selected_size = segment.end - segment.begin + dmer_size - 1;
        const copy_len = @min(selected_size, tail);
        // A trailing fragment shorter than one d-mer cannot contribute any of
        // the evidence used to select it.
        if (copy_len < dmer_size) break;
        tail -= copy_len;
        @memcpy(
            output[tail..][0..copy_len],
            samples[segment.sample_index][segment.begin..][0..copy_len],
        );
    }

    if (tail == 0) return output;
    const exact = try allocator.dupe(u8, output[tail..]);
    allocator.free(output);
    return exact;
}

const Parameters = struct {
    segment_size: usize,
    dmer_size: usize,
};

fn validateOptions(samples: []const []const u8, options: TrainOptions) !Parameters {
    try validateCorpusParameters(samples, options.dmer_size, options.hash_log, options.max_corpus_size);

    const dmer_size: usize = options.dmer_size;
    const segment_size = options.segment_size orelse @min(options.target_size, 64);
    if (segment_size < dmer_size or segment_size > options.target_size) return error.InvalidDictionaryTraining;

    return .{ .segment_size = segment_size, .dmer_size = dmer_size };
}

fn validateCorpusParameters(
    samples: []const []const u8,
    dmer_size: u8,
    hash_log: u8,
    max_corpus_size: usize,
) !void {
    if (samples.len < 5) return error.InvalidDictionaryTraining;
    if (dmer_size != 6 and dmer_size != 8) return error.InvalidDictionaryTraining;
    if (hash_log < min_hash_log or hash_log > max_hash_log) return error.InvalidDictionaryTraining;
    if (max_corpus_size == 0) return error.InvalidDictionaryTraining;
    var total_size: usize = 0;
    for (samples) |sample| {
        total_size = std.math.add(usize, total_size, sample.len) catch
            return error.InvalidDictionaryTraining;
    }
    if (total_size > max_corpus_size or total_size > std.math.maxInt(u32))
        return error.InvalidDictionaryTraining;
}

fn dmerCount(sample_len: usize, dmer_size: usize) usize {
    return if (sample_len < dmer_size) 0 else sample_len - dmer_size + 1;
}

fn collectFrequencies(
    samples: []const []const u8,
    dmer_size: usize,
    hash_log: u8,
    frequencies: []u32,
) void {
    for (samples) |sample| {
        for (0..dmerCount(sample.len, dmer_size)) |offset| {
            const index = dmerHash(sample, offset, dmer_size, hash_log);
            frequencies[index] += 1;
        }
    }
}

fn dmerHash(sample: []const u8, offset: usize, dmer_size: usize, hash_log: u8) usize {
    const value: u64 = switch (dmer_size) {
        6 => @as(u64, std.mem.readInt(u48, sample[offset..][0..6], .little)),
        8 => std.mem.readInt(u64, sample[offset..][0..8], .little),
        else => unreachable,
    };
    const mixed = switch (dmer_size) {
        6 => (value << 16) *% 227_718_039_650_203,
        8 => value *% 0xcf1b_bcdc_b7a5_6463,
        else => unreachable,
    };
    return @intCast(mixed >> @intCast(64 - hash_log));
}

fn computeEpochs(target_size: usize, total_dmers: usize, segment_size: usize) Epochs {
    std.debug.assert(target_size >= segment_size);
    std.debug.assert(total_dmers != 0);
    var count = @max(@as(usize, 1), target_size / segment_size);
    var size = total_dmers / count;
    const minimum_size = if (segment_size > std.math.maxInt(usize) / 10)
        std.math.maxInt(usize)
    else
        segment_size * 10;
    if (size < minimum_size) {
        size = @min(minimum_size, total_dmers);
        count = total_dmers / size;
    }
    std.debug.assert(count != 0 and size != 0);
    std.debug.assert(size * count <= total_dmers);
    return .{ .count = count, .size = size };
}

fn selectEpoch(
    samples: []const []const u8,
    dmer_offsets: []const usize,
    epoch_begin: usize,
    epoch_end: usize,
    segment_size: usize,
    dmer_size: usize,
    hash_log: u8,
    frequencies: []const u32,
    active_counts: []u32,
) Segment {
    std.debug.assert(epoch_begin < epoch_end);
    var best: Segment = .{};
    var sample_index = firstSampleForDmer(dmer_offsets, epoch_begin);
    while (sample_index < samples.len and dmer_offsets[sample_index] < epoch_end) : (sample_index += 1) {
        const logical_begin = @max(epoch_begin, dmer_offsets[sample_index]);
        const logical_end = @min(epoch_end, dmer_offsets[sample_index + 1]);
        if (logical_begin == logical_end) continue;
        const candidate = selectRange(
            samples[sample_index],
            sample_index,
            logical_begin - dmer_offsets[sample_index],
            logical_end - dmer_offsets[sample_index],
            segment_size,
            dmer_size,
            hash_log,
            frequencies,
            active_counts,
        );
        if (candidate.score > best.score) best = candidate;
    }
    return best;
}

fn firstSampleForDmer(dmer_offsets: []const usize, logical_offset: usize) usize {
    var low: usize = 0;
    var high = dmer_offsets.len - 1;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (dmer_offsets[middle + 1] <= logical_offset)
            low = middle + 1
        else
            high = middle;
    }
    return low;
}

fn selectRange(
    sample: []const u8,
    sample_index: usize,
    begin: usize,
    end: usize,
    segment_size: usize,
    dmer_size: usize,
    hash_log: u8,
    frequencies: []const u32,
    active_counts: []u32,
) Segment {
    const dmers_per_segment = segment_size - dmer_size + 1;
    var active: Segment = .{ .sample_index = sample_index, .begin = begin, .end = begin };
    var best: Segment = .{};

    while (active.end < end) {
        const added = dmerHash(sample, active.end, dmer_size, hash_log);
        if (active_counts[added] == 0) active.score += frequencies[added];
        active_counts[added] += 1;
        active.end += 1;

        if (active.end - active.begin == dmers_per_segment + 1) {
            const removed = dmerHash(sample, active.begin, dmer_size, hash_log);
            active_counts[removed] -= 1;
            if (active_counts[removed] == 0) active.score -= frequencies[removed];
            active.begin += 1;
        }
        if (active.score > best.score) best = active;
    }

    var clear_offset = active.begin;
    while (clear_offset < active.end) : (clear_offset += 1) {
        const index = dmerHash(sample, clear_offset, dmer_size, hash_log);
        std.debug.assert(active_counts[index] != 0);
        active_counts[index] -= 1;
    }
    return best;
}

fn zeroSegmentFrequencies(
    sample: []const u8,
    segment: Segment,
    dmer_size: usize,
    hash_log: u8,
    frequencies: []u32,
) void {
    for (segment.begin..segment.end) |offset|
        frequencies[dmerHash(sample, offset, dmer_size, hash_log)] = 0;
}

fn bruteForceSelectEpoch(
    samples: []const []const u8,
    dmer_offsets: []const usize,
    epoch_begin: usize,
    epoch_end: usize,
    segment_size: usize,
    dmer_size: usize,
    hash_log: u8,
    frequencies: []const u32,
) Segment {
    var best: Segment = .{};
    var sample_index = firstSampleForDmer(dmer_offsets, epoch_begin);
    while (sample_index < samples.len and dmer_offsets[sample_index] < epoch_end) : (sample_index += 1) {
        const logical_begin = @max(epoch_begin, dmer_offsets[sample_index]);
        const logical_end = @min(epoch_end, dmer_offsets[sample_index + 1]);
        const begin = logical_begin - dmer_offsets[sample_index];
        const end = logical_end - dmer_offsets[sample_index];
        for (begin..end) |candidate_begin| {
            const candidate_end = @min(end, candidate_begin + segment_size - dmer_size + 1);
            var seen: [1 << min_hash_log]bool = @splat(false);
            var score: u64 = 0;
            for (candidate_begin..candidate_end) |offset| {
                const index = dmerHash(samples[sample_index], offset, dmer_size, hash_log);
                if (!seen[index]) {
                    seen[index] = true;
                    score += frequencies[index];
                }
            }
            if (score > best.score) best = .{
                .sample_index = sample_index,
                .begin = candidate_begin,
                .end = candidate_end,
                .score = score,
            };
        }
    }
    return best;
}

test "COVER-class epoch sizing follows the COVER invariant" {
    try std.testing.expectEqual(Epochs{ .count = 15, .size = 640 }, computeEpochs(1024, 10_000, 64));
    try std.testing.expectEqual(Epochs{ .count = 1, .size = 90 }, computeEpochs(1024, 90, 64));
    try std.testing.expectEqual(Epochs{ .count = 2, .size = 640 }, computeEpochs(128, 1280, 64));
}

test "COVER-class hashes match Zstandard 6-byte and 8-byte formulas" {
    try std.testing.expectEqual(@as(usize, 46_636), dmerHash("abcdef", 0, 6, 16));
    try std.testing.expectEqual(@as(usize, 20_219), dmerHash("abcdefgh", 0, 8, 16));
    try std.testing.expectEqual(@as(usize, 746_187), dmerHash("abcdef", 0, 6, 20));
    try std.testing.expectEqual(@as(usize, 323_515), dmerHash("abcdefgh", 0, 8, 20));
}

test "COVER-class rolling scorer matches brute-force distinct-hash oracle" {
    var storage: [5][47]u8 = undefined;
    var state: u32 = 0x6a09_e667;
    for (&storage, 0..) |*sample, sample_index| {
        for (sample, 0..) |*byte, offset| {
            state = state *% 1_664_525 +% 1_013_904_223;
            byte.* = @truncate((state >> 24) ^ (sample_index * 17 + offset / 5));
        }
    }
    const samples = [_][]const u8{ &storage[0], &storage[1], &storage[2], &storage[3], &storage[4] };

    inline for (.{ @as(usize, 6), @as(usize, 8) }) |dmer_size| {
        var offsets: [samples.len + 1]usize = undefined;
        offsets[0] = 0;
        for (samples, 0..) |sample, index|
            offsets[index + 1] = offsets[index] + dmerCount(sample.len, dmer_size);
        var frequencies: [1 << min_hash_log]u32 = @splat(0);
        collectFrequencies(&samples, dmer_size, min_hash_log, &frequencies);
        var active_counts: [1 << min_hash_log]u32 = @splat(0);
        const epochs = computeEpochs(36, offsets[samples.len], 12);
        for (0..epochs.count) |epoch_index| {
            const begin = epoch_index * epochs.size;
            const end = begin + epochs.size;
            const actual = selectEpoch(
                &samples,
                &offsets,
                begin,
                end,
                12,
                dmer_size,
                min_hash_log,
                &frequencies,
                &active_counts,
            );
            const expected = bruteForceSelectEpoch(
                &samples,
                &offsets,
                begin,
                end,
                12,
                dmer_size,
                min_hash_log,
                &frequencies,
            );
            try std.testing.expectEqual(expected, actual);
            for (active_counts) |count| try std.testing.expectEqual(@as(u32, 0), count);
        }
    }
}

test "COVER-class trainer is deterministic and preserves sample boundaries" {
    const samples = [_][]const u8{ "AAAAAA", "BBBBBB", "CCCCCC", "DDDDDD", "EEEEEE" };
    const options: TrainOptions = .{
        .target_size = 8,
        .segment_size = 8,
        .dmer_size = 6,
        .hash_log = min_hash_log,
    };
    const first = try trainAlloc(std.testing.allocator, &samples, options);
    defer std.testing.allocator.free(first);
    const second = try trainAlloc(std.testing.allocator, &samples, options);
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualSlices(u8, "AAAAAA", first);
    try std.testing.expectEqualSlices(u8, first, second);
}

test "COVER-class trainer validates bounded parameters" {
    const samples = [_][]const u8{ "abcdefgh", "ijklmnop", "qrstuvwx", "yz012345", "6789ABCD" };
    const empty = try trainAlloc(std.testing.allocator, &.{}, .{ .target_size = 0 });
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);

    try std.testing.expectError(error.InvalidDictionaryTraining, trainAlloc(
        std.testing.allocator,
        samples[0..4],
        .{ .target_size = 8 },
    ));
    try std.testing.expectError(error.InvalidDictionaryTraining, trainAlloc(
        std.testing.allocator,
        &samples,
        .{ .target_size = 8, .dmer_size = 7 },
    ));
    try std.testing.expectError(error.InvalidDictionaryTraining, trainAlloc(
        std.testing.allocator,
        &samples,
        .{ .target_size = 8, .segment_size = 5, .dmer_size = 6 },
    ));
    try std.testing.expectError(error.InvalidDictionaryTraining, trainAlloc(
        std.testing.allocator,
        &samples,
        .{ .target_size = 8, .segment_size = 9 },
    ));
    try std.testing.expectError(error.InvalidDictionaryTraining, trainAlloc(
        std.testing.allocator,
        &samples,
        .{ .target_size = 8, .hash_log = min_hash_log - 1 },
    ));
    try std.testing.expectError(error.InvalidDictionaryTraining, trainAlloc(
        std.testing.allocator,
        &samples,
        .{ .target_size = 8, .hash_log = max_hash_log + 1 },
    ));
    try std.testing.expectError(error.InvalidDictionaryTraining, trainAlloc(
        std.testing.allocator,
        &samples,
        .{ .target_size = 8, .max_corpus_size = 39 },
    ));
}

test "COVER-class trainer releases every allocation failure path" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const samples = [_][]const u8{ "AAAAAA", "BBBBBB", "CCCCCC", "DDDDDD", "EEEEEE" };
            const trained = try trainAlloc(allocator, &samples, .{
                .target_size = 17,
                .segment_size = 8,
                .dmer_size = 6,
                .hash_log = min_hash_log,
            });
            defer allocator.free(trained);
            try std.testing.expect(trained.len <= 17);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}

test "COVER-class prepared corpus matches independent segment training" {
    const samples = [_][]const u8{
        "service=vort region=west status=ok message=alpha alpha alpha",
        "service=vort region=east status=ok message=beta beta beta",
        "service=vort region=north status=warn message=gamma gamma",
        "service=vort region=south status=retry message=delta delta",
        "service=vort region=central status=ok message=alpha beta gamma",
    };
    inline for (.{ @as(u8, 6), @as(u8, 8) }) |dmer_size| {
        inline for (.{ @as(u8, 8), @as(u8, 10) }) |hash_log| {
            var prepared = try Prepared.init(
                std.testing.allocator,
                &samples,
                dmer_size,
                hash_log,
                default_max_corpus_size,
            );
            defer prepared.deinit(std.testing.allocator);
            inline for (.{ @as(usize, 12), @as(usize, 24) }) |segment_size| {
                const expected = try trainAlloc(std.testing.allocator, &samples, .{
                    .target_size = 48,
                    .segment_size = segment_size,
                    .dmer_size = dmer_size,
                    .hash_log = hash_log,
                });
                defer std.testing.allocator.free(expected);
                const actual = try prepared.trainAlloc(std.testing.allocator, 48, segment_size);
                defer std.testing.allocator.free(actual);
                try std.testing.expectEqualSlices(u8, expected, actual);
            }
        }
    }
}

test "COVER-class prepared corpus recovers from candidate allocation failure" {
    const samples = [_][]const u8{ "abcdefghijklmnop", "abcdefghijklmnop", "abcdefghijklmnop", "abcdefghijklmnop", "abcdefghijklmnop" };
    var prepared = try Prepared.init(std.testing.allocator, &samples, 6, min_hash_log, default_max_corpus_size);
    defer prepared.deinit(std.testing.allocator);
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, prepared.trainAlloc(failing.allocator(), 16, 8));
    const recovered = try prepared.trainAlloc(std.testing.allocator, 16, 8);
    defer std.testing.allocator.free(recovered);
    const expected = try trainAlloc(std.testing.allocator, &samples, .{
        .target_size = 16,
        .segment_size = 8,
        .dmer_size = 6,
        .hash_log = min_hash_log,
    });
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualSlices(u8, expected, recovered);
}

test "COVER-class prepared corpus releases every allocation failure path" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const samples = [_][]const u8{ "abcdefghijklmnop", "abcdefghijklmnop", "abcdefghijklmnop", "abcdefghijklmnop", "abcdefghijklmnop" };
            var prepared = try Prepared.init(allocator, &samples, 6, min_hash_log, default_max_corpus_size);
            defer prepared.deinit(allocator);
            const trained = try prepared.trainAlloc(allocator, 16, 8);
            defer allocator.free(trained);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}
