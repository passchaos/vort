const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");
const train_rounds: usize = 3;

const Corpus = struct {
    slices: std.ArrayList([]const u8) = .empty,
    owned: std.ArrayList([]u8) = .empty,

    fn read(
        self: *Corpus,
        io: std.Io,
        allocator: std.mem.Allocator,
        args: *std.process.Args.Iterator,
        count: usize,
    ) !void {
        try self.slices.ensureUnusedCapacity(allocator, count);
        try self.owned.ensureUnusedCapacity(allocator, count);
        for (0..count) |_| {
            const path = args.next() orelse return error.MissingCorpusPath;
            const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1 << 20));
            self.owned.appendAssumeCapacity(bytes);
            self.slices.appendAssumeCapacity(bytes);
        }
    }

    fn deinit(self: *Corpus, allocator: std.mem.Allocator) void {
        for (self.owned.items) |bytes| allocator.free(bytes);
        self.owned.deinit(allocator);
        self.slices.deinit(allocator);
        self.* = .{};
    }
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const case_name = args.next() orelse return error.InvalidBlockPlan;
    const cover_path = args.next() orelse return error.MissingCorpusPath;
    const fastcover_path = args.next() orelse return error.MissingCorpusPath;
    const generated_path = args.next() orelse return error.MissingCorpusPath;
    const target_size = try parseCount(args.next() orelse return error.InvalidBlockPlan);
    const training_count = try parseCount(args.next() orelse return error.InvalidBlockPlan);
    const selector_count = try parseCount(args.next() orelse return error.InvalidBlockPlan);
    const heldout_count = try parseCount(args.next() orelse return error.InvalidBlockPlan);
    const reference_cover_ns = try parseCount(args.next() orelse return error.InvalidBlockPlan);
    const reference_fastcover_ns = try parseCount(args.next() orelse return error.InvalidBlockPlan);

    var training: Corpus = .{};
    defer training.deinit(init.gpa);
    var selector: Corpus = .{};
    defer selector.deinit(init.gpa);
    var heldout: Corpus = .{};
    defer heldout.deinit(init.gpa);
    try training.read(init.io, init.gpa, &args, training_count);
    try selector.read(init.io, init.gpa, &args, selector_count);
    try heldout.read(init.io, init.gpa, &args, heldout_count);
    if (args.next() != null or training_count < 5 or selector_count == 0 or heldout_count == 0)
        return error.InvalidBlockPlan;

    const cover_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, cover_path, init.gpa, .limited(1 << 20));
    defer init.gpa.free(cover_bytes);
    const fastcover_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, fastcover_path, init.gpa, .limited(1 << 20));
    defer init.gpa.free(fastcover_bytes);
    const cover_reference = try vort.ZstdNativeDictionary.initFromStandardDictionary(cover_bytes);
    const fastcover_reference = try vort.ZstdNativeDictionary.initFromStandardDictionary(fastcover_bytes);
    const dictionary_id = nextDictionaryId(fastcover_reference.view.id);
    var runtime = try libzstd.Runtime.open();
    defer runtime.deinit();

    const vort_training = try trainVortBest(
        init,
        training.slices.items,
        selector.slices.items,
        target_size,
        dictionary_id,
    );
    const trained = vort_training.dictionary;
    const vort_train_ns = vort_training.best_ns;
    defer trained.deinit(init.gpa);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = generated_path, .data = trained.bytes });
    const oracle = try trainCodecOracle(
        init,
        runtime,
        training.slices.items,
        selector.slices.items,
        target_size,
        nextDictionaryId(dictionary_id),
    );
    defer oracle.dictionary.deinit(init.gpa);
    defer oracle.native_dictionary.deinit(init.gpa);

    var vort_sizes: [3]usize = @splat(0);
    var oracle_sizes: [3]usize = @splat(0);
    var native_oracle_sizes: [3]usize = @splat(0);
    var cover_sizes: [3]usize = @splat(0);
    var fastcover_sizes: [3]usize = @splat(0);
    const levels = [_]c_int{ 1, 3, 9 };
    for (heldout.slices.items) |payload| {
        for (levels, 0..) |level, level_index| {
            const vort_encoded = try runtime.encodeUsingDictAlloc(init.gpa, payload, trained.bytes, level);
            defer init.gpa.free(vort_encoded);
            const cover_encoded = try runtime.encodeUsingDictAlloc(init.gpa, payload, cover_bytes, level);
            defer init.gpa.free(cover_encoded);
            const fastcover_encoded = try runtime.encodeUsingDictAlloc(init.gpa, payload, fastcover_bytes, level);
            defer init.gpa.free(fastcover_encoded);
            const oracle_encoded = try runtime.encodeUsingDictAlloc(init.gpa, payload, oracle.dictionary.bytes, level);
            defer init.gpa.free(oracle_encoded);
            const native_oracle_encoded = try runtime.encodeUsingDictAlloc(init.gpa, payload, oracle.native_dictionary.bytes, level);
            defer init.gpa.free(native_oracle_encoded);
            vort_sizes[level_index] += vort_encoded.len;
            oracle_sizes[level_index] += oracle_encoded.len;
            native_oracle_sizes[level_index] += native_oracle_encoded.len;
            cover_sizes[level_index] += cover_encoded.len;
            fastcover_sizes[level_index] += fastcover_encoded.len;

            try expectDecoded(init.gpa, payload, vort_encoded, trained.asDictionary());
            try expectDecoded(init.gpa, payload, oracle_encoded, oracle.dictionary.asDictionary());
            try expectDecoded(init.gpa, payload, native_oracle_encoded, oracle.native_dictionary.asDictionary());
            try expectDecoded(init.gpa, payload, cover_encoded, cover_reference.dictionary);
            try expectDecoded(init.gpa, payload, fastcover_encoded, fastcover_reference.dictionary);

            const reference_output = try init.gpa.alloc(u8, payload.len);
            defer init.gpa.free(reference_output);
            try runtime.decodeUsingDict(vort_encoded, reference_output, trained.bytes);
            if (!std.mem.eql(u8, payload, reference_output)) return error.SizeMismatch;
        }

        const native = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(
            init.gpa,
            payload,
            .{ .content_checksum = false },
            trained.asDictionary(),
        );
        defer init.gpa.free(native.frame);
        const reference_output = try init.gpa.alloc(u8, payload.len);
        defer init.gpa.free(reference_output);
        try runtime.decodeUsingDict(native.frame, reference_output, trained.bytes);
        if (!std.mem.eql(u8, payload, reference_output)) return error.SizeMismatch;
    }

    var buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print(
        "zstd_cover_trainer_compare=ok case={s} samples={d}/{d}/{d} target={d} candidates={d} selected={d}/{d}/{d} oracle_selected={d}/{d}/{d} oracle_rank={d} oracle_score={d} native_oracle_selected={d}/{d}/{d} native_oracle_rank={d} native_oracle_score={d} native_candidate_repcodes=0 content={d}/{d}/{d} dict={d}/{d}/{d} oracle_dict={d} native_oracle_dict={d}",
        .{
            case_name,
            training_count,
            selector_count,
            heldout_count,
            target_size,
            trained.candidates_evaluated,
            trained.selected_options.segment_size.?,
            trained.selected_options.dmer_size,
            trained.selected_options.hash_log,
            oracle.options.segment_size.?,
            oracle.options.dmer_size,
            oracle.options.hash_log,
            oracle.generic_rank,
            oracle.selection_size,
            oracle.native_options.segment_size.?,
            oracle.native_options.dmer_size,
            oracle.native_options.hash_log,
            oracle.native_generic_rank,
            oracle.native_selection_size,
            trained.view.content.len,
            cover_reference.view.content.len,
            fastcover_reference.view.content.len,
            trained.bytes.len,
            cover_bytes.len,
            fastcover_bytes.len,
            oracle.dictionary.bytes.len,
            oracle.native_dictionary.bytes.len,
        },
    );
    try stdout.interface.print(
        " level1={d}/{d}/{d} oracle_level1={d} native_oracle_level1={d} level3={d}/{d}/{d} oracle_level3={d} native_oracle_level3={d} level9={d}/{d}/{d} oracle_level9={d} native_oracle_level9={d} train_ns={d}/{d}/{d} oracle_train_ns={d} native_oracle_train_ns={d} rounds={d} version={s}",
        .{
            vort_sizes[0],
            cover_sizes[0],
            fastcover_sizes[0],
            oracle_sizes[0],
            native_oracle_sizes[0],
            vort_sizes[1],
            cover_sizes[1],
            fastcover_sizes[1],
            oracle_sizes[1],
            native_oracle_sizes[1],
            vort_sizes[2],
            cover_sizes[2],
            fastcover_sizes[2],
            oracle_sizes[2],
            native_oracle_sizes[2],
            vort_train_ns,
            reference_cover_ns,
            reference_fastcover_ns,
            oracle.train_ns,
            oracle.native_train_ns,
            train_rounds,
            runtime.version(),
        },
    );
    try stdout.interface.print(
        " finalizer_ns={d}/{d}/{d}/{d}/{d}/{d}/{d}/{d}/{d} finalizer_work={d}/{d}/{d}/{d}/{d}\n",
        .{
            oracle.profile.total_ns,
            oracle.profile.literal_entropy_ns,
            oracle.profile.sequence_collection_ns,
            oracle.profile.greedy_parse_ns,
            oracle.profile.lazy_parse_ns,
            oracle.profile.sequence_entropy_ns,
            oracle.profile.baseline_assembly_ns,
            oracle.profile.repcode_entropy_ns,
            oracle.profile.repcode_scoring_ns,
            oracle.profile.sample_bytes,
            oracle.profile.blocks,
            oracle.profile.greedy_tokens,
            oracle.profile.lazy_tokens,
            oracle.profile.offset_sequences,
        },
    );
    try stdout.interface.print(
        "codec_profile_ns={d}/{d}/{d}/{d}/{d} codec_finalizer_ns={d}/{d}/{d}/{d}/{d}/{d}/{d}/{d}/{d} codec_profile_work={d}/{d}/{d}/{d}/{d}/{d}/{d}\n",
        .{
            oracle.codec_profile.total_ns,
            oracle.codec_profile.candidate_search_ns,
            oracle.codec_profile.candidate_finalizer.total_ns,
            oracle.codec_profile.selector_encoding_ns,
            oracle.codec_profile.winner_finalization_ns,
            oracle.codec_profile.candidate_finalizer.total_ns,
            oracle.codec_profile.candidate_finalizer.literal_entropy_ns,
            oracle.codec_profile.candidate_finalizer.sequence_collection_ns,
            oracle.codec_profile.candidate_finalizer.greedy_parse_ns,
            oracle.codec_profile.candidate_finalizer.lazy_parse_ns,
            oracle.codec_profile.candidate_finalizer.sequence_entropy_ns,
            oracle.codec_profile.candidate_finalizer.baseline_assembly_ns,
            oracle.codec_profile.candidate_finalizer.repcode_entropy_ns,
            oracle.codec_profile.candidate_finalizer.repcode_scoring_ns,
            oracle.codec_profile.candidate_frames,
            oracle.codec_profile.selector_encoded_bytes,
            oracle.codec_profile.candidate_finalizer.sample_bytes,
            oracle.codec_profile.candidate_finalizer.blocks,
            oracle.codec_profile.candidate_finalizer.greedy_tokens,
            oracle.codec_profile.candidate_finalizer.lazy_tokens,
            oracle.codec_profile.candidate_finalizer.offset_sequences,
        },
    );
    try stdout.interface.flush();
}

const OracleTraining = struct {
    dictionary: vort.ZstdOwnedStandardDictionary,
    native_dictionary: vort.ZstdOwnedOptimizedCoverStandardDictionary,
    options: vort.ZstdCoverDictionaryTrainOptions,
    native_options: vort.ZstdCoverDictionaryTrainOptions,
    selection_size: usize,
    native_selection_size: usize,
    generic_rank: usize,
    native_generic_rank: usize,
    train_ns: usize,
    native_train_ns: usize,
    profile: vort.ZstdStandardDictionaryTrainingProfile,
    codec_profile: vort.ZstdCoverCodecSearchProfile,
};

const ScoredOptions = struct {
    options: vort.ZstdCoverDictionaryTrainOptions,
    score: vort.dictionary.ValidationScore,
};

fn trainCodecOracle(
    init: std.process.Init,
    runtime: libzstd.Runtime,
    training: []const []const u8,
    selector: []const []const u8,
    target_size: usize,
    dictionary_id: u32,
) !OracleTraining {
    const segment_sizes = [_]usize{ 32, 64, 128, 256, 352 };
    const dmer_sizes = [_]u8{ 6, 8 };
    const hash_logs = [_]u8{ 12, 16, 20 };
    const levels = [_]c_int{ 1, 3, 9 };
    const native_start = std.Io.Clock.awake.now(init.io);
    const native_profiled = try vort.zstdProfileCodecOptimizedCoverStandardDictionaryAlloc(
        init.gpa,
        init.io,
        training,
        selector,
        .{
            .cover = .{
                .target_size = target_size,
                .segment_sizes = &segment_sizes,
                .dmer_sizes = &dmer_sizes,
                .hash_logs = &hash_logs,
                .max_candidates = 32,
            },
            .levels = &levels,
        },
        nextDictionaryId(dictionary_id),
    );
    const native_dictionary = native_profiled.dictionary;
    const codec_profile = native_profiled.profile;
    errdefer native_dictionary.deinit(init.gpa);
    const native_train_ns = elapsed(native_start, init.io);

    const start = std.Io.Clock.awake.now(init.io);
    var best: ?vort.ZstdOwnedStandardDictionary = null;
    errdefer if (best) |dictionary| dictionary.deinit(init.gpa);
    var best_options: vort.ZstdCoverDictionaryTrainOptions = undefined;
    var best_size: usize = std.math.maxInt(usize);
    var best_generic_score: vort.dictionary.ValidationScore = undefined;
    var scored: [30]ScoredOptions = undefined;
    var scored_count: usize = 0;
    var aggregate_profile: vort.ZstdStandardDictionaryTrainingProfile = .{};

    for (dmer_sizes) |dmer_size| {
        for (segment_sizes) |segment_size| {
            for (hash_logs) |hash_log| {
                const options: vort.ZstdCoverDictionaryTrainOptions = .{
                    .target_size = target_size,
                    .segment_size = segment_size,
                    .dmer_size = dmer_size,
                    .hash_log = hash_log,
                };
                const content = try vort.dictionary.trainCoverAlloc(init.gpa, training, options);
                defer init.gpa.free(content);
                const profiled = try vort.zstdProfileStandardDictionaryFromContentAlloc(
                    init.gpa,
                    init.io,
                    content,
                    training,
                    dictionary_id,
                );
                addTrainingProfile(&aggregate_profile, profiled.profile);
                const candidate = profiled.dictionary;
                const generic_score = try vort.dictionary.validationScore(content, selector, 4);
                scored[scored_count] = .{ .options = options, .score = generic_score };
                scored_count += 1;
                var score = candidate.bytes.len;
                for (selector) |payload| {
                    for (levels) |level| {
                        const encoded = try runtime.encodeUsingDictAlloc(init.gpa, payload, candidate.bytes, level);
                        defer init.gpa.free(encoded);
                        score = std.math.add(usize, score, encoded.len) catch return error.InvalidDictionaryTraining;
                    }
                }
                if (best == null or score < best_size) {
                    if (best) |dictionary| dictionary.deinit(init.gpa);
                    best = candidate;
                    best_options = options;
                    best_size = score;
                    best_generic_score = generic_score;
                } else candidate.deinit(init.gpa);
            }
        }
    }

    const entropy_count = std.math.add(usize, training.len, selector.len) catch
        return error.InvalidDictionaryTraining;
    const entropy_samples = try init.gpa.alloc([]const u8, entropy_count);
    defer init.gpa.free(entropy_samples);
    @memcpy(entropy_samples[0..training.len], training);
    @memcpy(entropy_samples[training.len..], selector);
    const selected = best.?;
    const finalized = try vort.zstdTrainStandardDictionaryFromContentAlloc(
        init.gpa,
        selected.view.content,
        entropy_samples,
        dictionary_id,
    );
    errdefer finalized.deinit(init.gpa);
    selected.deinit(init.gpa);
    best = null;
    var native_generic_score: ?vort.dictionary.ValidationScore = null;
    var generic_rank: usize = 1;
    var native_generic_rank: usize = 1;
    for (scored[0..scored_count]) |entry| {
        generic_rank += @intFromBool(validationScoreBetter(entry.score, best_generic_score));
        if (std.meta.eql(entry.options, native_dictionary.selected_options))
            native_generic_score = entry.score;
    }
    for (scored[0..scored_count]) |entry| {
        native_generic_rank += @intFromBool(validationScoreBetter(entry.score, native_generic_score.?));
    }
    return .{
        .dictionary = finalized,
        .native_dictionary = native_dictionary,
        .options = best_options,
        .native_options = native_dictionary.selected_options,
        .selection_size = best_size,
        .native_selection_size = native_dictionary.validation_score.estimated_bits / 8,
        .generic_rank = generic_rank,
        .native_generic_rank = native_generic_rank,
        .train_ns = elapsed(start, init.io),
        .native_train_ns = native_train_ns,
        .profile = aggregate_profile,
        .codec_profile = codec_profile,
    };
}

fn addTrainingProfile(
    total: *vort.ZstdStandardDictionaryTrainingProfile,
    sample: vort.ZstdStandardDictionaryTrainingProfile,
) void {
    inline for (std.meta.fields(vort.ZstdStandardDictionaryTrainingProfile)) |field| {
        @field(total, field.name) +|= @field(sample, field.name);
    }
}

fn validationScoreBetter(
    candidate: vort.dictionary.ValidationScore,
    best: vort.dictionary.ValidationScore,
) bool {
    return candidate.estimated_bits < best.estimated_bits or
        (candidate.estimated_bits == best.estimated_bits and candidate.covered_bytes > best.covered_bytes) or
        (candidate.estimated_bits == best.estimated_bits and candidate.covered_bytes == best.covered_bytes and candidate.matches < best.matches) or
        (candidate.estimated_bits == best.estimated_bits and candidate.covered_bytes == best.covered_bytes and candidate.matches == best.matches and candidate.distance_bits < best.distance_bits);
}

const VortTraining = struct {
    dictionary: vort.ZstdOwnedOptimizedCoverStandardDictionary,
    best_ns: usize,
};

fn trainVortBest(
    init: std.process.Init,
    training: []const []const u8,
    selector: []const []const u8,
    target_size: usize,
    dictionary_id: u32,
) !VortTraining {
    var retained: ?vort.ZstdOwnedOptimizedCoverStandardDictionary = null;
    errdefer if (retained) |dictionary| dictionary.deinit(init.gpa);
    var best_ns: usize = std.math.maxInt(usize);
    for (0..train_rounds) |_| {
        const start = std.Io.Clock.awake.now(init.io);
        const candidate = try vort.zstdTrainOptimizedCoverStandardDictionaryAlloc(
            init.gpa,
            training,
            selector,
            .{
                .target_size = target_size,
                .segment_sizes = &.{ 32, 64, 128, 256, 352 },
                .dmer_sizes = &.{ 6, 8 },
                .hash_logs = &.{ 12, 16, 20 },
                .max_candidates = 32,
            },
            dictionary_id,
        );
        best_ns = @min(best_ns, elapsed(start, init.io));
        if (retained) |dictionary| {
            if (!std.mem.eql(u8, dictionary.bytes, candidate.bytes) or
                !std.meta.eql(dictionary.selected_options, candidate.selected_options) or
                !std.meta.eql(dictionary.validation_score, candidate.validation_score))
            {
                candidate.deinit(init.gpa);
                return error.InvalidDictionaryTraining;
            }
            candidate.deinit(init.gpa);
        } else retained = candidate;
    }
    return .{ .dictionary = retained.?, .best_ns = best_ns };
}

fn expectDecoded(
    allocator: std.mem.Allocator,
    expected: []const u8,
    encoded: []const u8,
    dictionary: vort.ZstdDictionary,
) !void {
    const decoded = try vort.zstdDecodeFrameAllocWithDictionary(allocator, encoded, dictionary);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, expected, decoded)) return error.SizeMismatch;
}

fn nextDictionaryId(id: u32) u32 {
    return if (id == std.math.maxInt(u32)) 1 else id + 1;
}

fn elapsed(start: std.Io.Timestamp, io: std.Io) usize {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 1 else @intCast(ns);
}

fn parseCount(bytes: []const u8) !usize {
    return std.fmt.parseUnsigned(usize, bytes, 10) catch return error.InvalidBlockPlan;
}
