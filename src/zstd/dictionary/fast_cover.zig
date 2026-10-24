const std = @import("std");
const fast_cover = @import("../../dictionary/fast_cover.zig");
const optimize = @import("../../dictionary/fast_cover_optimize.zig");
const dictionary = @import("../../dictionary.zig");
const working = @import("../../io/working_allocator.zig");

pub const TrainOptions = fast_cover.TrainOptions;
pub const OptimizeOptions = optimize.OptimizeOptions;
const default_codec_levels = [_]c_int{ 1, 3, 9 };

/// The target and dictionary-size limit apply to selected history. Corpus
/// entropy tables and repcodes add a variable standard dictionary header.
pub const CodecOptimizeOptions = struct {
    fast_cover: OptimizeOptions,
    levels: []const c_int = &default_codec_levels,
    /// Apply the same repcode retraining policy to candidates and the winner
    /// so codec scores charge the dictionary representation that is returned.
    candidate_repcodes: bool = false,
};

pub fn Trainer(comptime Codec: type) type {
    return struct {
        const Self = @This();
        pub const OwnedOptimizedDictionary = struct {
            bytes: []u8,
            view: Codec.DictionaryView,
            selected_options: TrainOptions,
            validation_score: optimize.Score,
            candidates_evaluated: usize,
            /// Selected history length before optional suffix shrinking.
            original_dictionary_size: usize,

            pub fn asDictionary(self: @This()) Codec.NativeDictionary {
                return .{ .id = self.view.id, .content = self.view.content, .standard_bytes = self.bytes };
            }
            pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
                allocator.free(self.bytes);
            }
        };

        /// Caller-owned, accumulating counters and stage times. The generic
        /// profile records actual frequency and segment work; the finalizer
        /// profile records the existing Huffman/FSE/repcodes implementation.
        pub const TrainingProfile = struct {
            training: fast_cover.Profile = .{},
            finalizer: Codec.FinalizerProfile = .{},
            total_ns: u64 = 0,
            frequency_ns: u64 = 0,
            segment_ns: u64 = 0,
            finalization_ns: u64 = 0,
            finalizations: u64 = 0,
            finalization_samples: u64 = 0,
            finalization_sample_bytes: u64 = 0,
            peak_working_memory: usize = 0,
            peak_allocator_owned_bytes: usize = 0,
            thread_stack_reservation_peak: usize = 0,

            pub fn reset(self: *@This()) void {
                self.* = .{};
            }
        };

        pub const CodecSearchProfile = struct {
            search: optimize.Profile = .{},
            candidate_finalizer: Codec.FinalizerProfile = .{},
            winner_finalizer: Codec.FinalizerProfile = .{},
            total_ns: u64 = 0,
            candidate_search_ns: u64 = 0,
            selector_encoding_ns: u64 = 0,
            winner_finalization_ns: u64 = 0,
            candidate_finalizations: u64 = 0,
            candidate_finalization_samples: u64 = 0,
            candidate_finalization_sample_bytes: u64 = 0,
            winner_finalizations: u64 = 0,
            winner_finalization_samples: u64 = 0,
            winner_finalization_sample_bytes: u64 = 0,
            candidate_encode_attempts: u64 = 0,
            candidate_frames: u64 = 0,
            selector_encoded_bytes: u64 = 0,
            peak_working_memory: usize = 0,
            peak_allocator_owned_bytes: usize = 0,
            thread_stack_reservation_peak: usize = 0,

            pub fn reset(self: *@This()) void {
                self.* = .{};
            }
        };

        /// Validate scalar options before applications load a training corpus.
        pub fn validateTrainOptions(options: TrainOptions, dictionary_id: u32) Codec.Error!void {
            try validateMetadata(options.target_size, dictionary_id);
            try fast_cover.validateParameters(options);
        }
        pub fn validateOptimizeOptions(options: OptimizeOptions, dictionary_id: u32) Codec.Error!void {
            try validateMetadata(options.target_size, dictionary_id);
            try optimize.validateParameters(options);
        }
        pub fn validateCodecOptimizeOptions(options: CodecOptimizeOptions, dictionary_id: u32) Codec.Error!void {
            try validateOptimizeOptions(options.fast_cover, dictionary_id);
            if (options.levels.len == 0 or options.levels.len > 8) return error.InvalidBlockPlan;
            for (options.levels) |level| try Codec.validateLevel(level);
        }
        pub fn trainAlloc(allocator: std.mem.Allocator, samples: []const []const u8, options: TrainOptions, dictionary_id: u32) Codec.Error!Codec.OwnedDictionary {
            return trainInternal(allocator, samples, options, dictionary_id, null, null);
        }
        pub fn profileTrainAlloc(allocator: std.mem.Allocator, io: std.Io, samples: []const []const u8, options: TrainOptions, dictionary_id: u32, profile: *TrainingProfile) Codec.Error!Codec.OwnedDictionary {
            return trainInternal(allocator, samples, options, dictionary_id, io, profile);
        }
        fn trainInternal(allocator: std.mem.Allocator, samples: []const []const u8, options: TrainOptions, dictionary_id: u32, io: ?std.Io, profile: ?*TrainingProfile) Codec.Error!Codec.OwnedDictionary {
            try validateTrainOptions(options, dictionary_id);
            var budget = working.WorkingAllocator.init(allocator, options.max_working_memory);
            defer {
                if (profile) |p| {
                    p.peak_working_memory = @max(p.peak_working_memory, budget.peak);
                    p.peak_allocator_owned_bytes = @max(p.peak_allocator_owned_bytes, budget.peak);
                }
            }
            const total_start = begin(io);
            defer if (profile) |p| end(io, total_start, &p.total_ns);
            return trainBounded(budget.allocator(), samples, options, dictionary_id, io, profile) catch |err| return budgetError(&budget, err);
        }
        fn trainBounded(allocator: std.mem.Allocator, samples: []const []const u8, options: TrainOptions, dictionary_id: u32, io: ?std.Io, profile: ?*TrainingProfile) Codec.Error!Codec.OwnedDictionary {
            var selected_options = options;
            var training_delta: fast_cover.Profile = .{};
            if (profile != null) selected_options.profile = &training_delta;
            defer if (profile) |p| {
                p.training.merge(training_delta);
                if (options.profile) |caller| {
                    if (caller != &p.training) caller.merge(training_delta);
                }
            };
            const content = blk: {
                const frequency_start = begin(io);
                var prepared = fast_cover.Prepared.init(allocator, samples, selected_options) catch |err| {
                    if (profile) |p| end(io, frequency_start, &p.frequency_ns);
                    return err;
                };
                if (profile) |p| end(io, frequency_start, &p.frequency_ns);
                defer prepared.deinit(allocator);
                const segment_start = begin(io);
                const selected = prepared.trainAlloc(allocator, selected_options) catch |err| {
                    if (profile) |p| end(io, segment_start, &p.segment_ns);
                    return err;
                };
                if (profile) |p| end(io, segment_start, &p.segment_ns);
                break :blk selected;
            };
            defer allocator.free(content);
            if (content.len < 8) return error.InvalidDictionaryTraining;
            const final_samples = try finalizationSamples(samples, options.acceleration);
            if (profile) |p| {
                p.finalizations +|= 1;
                add(&p.finalization_samples, final_samples.len);
                add(&p.finalization_sample_bytes, try sampleBytes(final_samples));
            }
            const final_start = begin(io);
            defer if (profile) |p| end(io, final_start, &p.finalization_ns);
            return Codec.finalize(allocator, content, final_samples, dictionary_id, io, if (profile) |p| &p.finalizer else null, true);
        }

        pub fn trainOptimizedAlloc(allocator: std.mem.Allocator, training_samples: []const []const u8, validation_samples: []const []const u8, options: OptimizeOptions, dictionary_id: u32) Codec.Error!OwnedOptimizedDictionary {
            return optimizeInternal(false, allocator, training_samples, validation_samples, .{ .fast_cover = options }, dictionary_id, null, null);
        }
        pub fn profileOptimizedAlloc(allocator: std.mem.Allocator, io: std.Io, training_samples: []const []const u8, validation_samples: []const []const u8, options: OptimizeOptions, dictionary_id: u32, profile: *CodecSearchProfile) Codec.Error!OwnedOptimizedDictionary {
            return optimizeInternal(false, allocator, training_samples, validation_samples, .{ .fast_cover = options }, dictionary_id, io, profile);
        }
        pub fn trainCodecOptimizedAlloc(allocator: std.mem.Allocator, training_samples: []const []const u8, validation_samples: []const []const u8, options: CodecOptimizeOptions, dictionary_id: u32) Codec.Error!OwnedOptimizedDictionary {
            return optimizeInternal(true, allocator, training_samples, validation_samples, options, dictionary_id, null, null);
        }
        pub fn profileCodecOptimizedAlloc(allocator: std.mem.Allocator, io: std.Io, training_samples: []const []const u8, validation_samples: []const []const u8, options: CodecOptimizeOptions, dictionary_id: u32, profile: *CodecSearchProfile) Codec.Error!OwnedOptimizedDictionary {
            return optimizeInternal(true, allocator, training_samples, validation_samples, options, dictionary_id, io, profile);
        }
        fn optimizeInternal(comptime codec_aware: bool, allocator: std.mem.Allocator, training_samples: []const []const u8, validation_samples: []const []const u8, options: CodecOptimizeOptions, dictionary_id: u32, io: ?std.Io, profile: ?*CodecSearchProfile) Codec.Error!OwnedOptimizedDictionary {
            if (codec_aware)
                try validateCodecOptimizeOptions(options, dictionary_id)
            else
                try validateOptimizeOptions(options.fast_cover, dictionary_id);
            var budget = working.WorkingAllocator.init(allocator, options.fast_cover.max_working_memory);
            defer {
                if (profile) |p| {
                    p.peak_working_memory = @max(p.peak_working_memory, @max(budget.peak, p.search.peak_working_memory));
                    p.peak_allocator_owned_bytes = @max(p.peak_allocator_owned_bytes, budget.peak);
                    p.thread_stack_reservation_peak = @max(p.thread_stack_reservation_peak, p.search.thread_stack_reservation_peak);
                }
            }
            const total_start = begin(io);
            defer if (profile) |p| end(io, total_start, &p.total_ns);
            return optimizeBounded(codec_aware, budget.allocator(), training_samples, validation_samples, options, dictionary_id, io, profile) catch |err| return budgetError(&budget, err);
        }
        fn optimizeBounded(comptime codec_aware: bool, allocator: std.mem.Allocator, training_samples: []const []const u8, validation_samples: []const []const u8, options: CodecOptimizeOptions, dictionary_id: u32, io: ?std.Io, profile: ?*CodecSearchProfile) Codec.Error!OwnedOptimizedDictionary {
            var search_options = options.fast_cover;
            var search_delta: optimize.Profile = .{};
            if (profile != null) search_options.profile = &search_delta;
            defer if (profile) |p| {
                p.search.merge(search_delta);
                if (options.fast_cover.profile) |caller| {
                    if (caller != &p.search) caller.merge(search_delta);
                }
            };
            const search_start = begin(io);
            const scorer_context: ScorerContext = .{ .levels = options.levels, .dictionary_id = dictionary_id, .candidate_repcodes = options.candidate_repcodes, .io = io, .profile = profile };
            var optimized = (if (codec_aware)
                optimize.trainAllocWithScorerFactory(allocator, training_samples, validation_samples, search_options, &scorer_context, Scorer)
            else
                optimize.trainAllocWithScorerFactory(allocator, training_samples, validation_samples, search_options, &scorer_context, RawScorer)) catch |err| {
                if (profile) |p| end(io, search_start, &p.candidate_search_ns);
                return err;
            };
            if (profile) |p| end(io, search_start, &p.candidate_search_ns);
            defer optimized.deinit(allocator);
            const final_samples = try finalizationSamples(training_samples, optimized.selected_options.acceleration);
            if (profile) |p| {
                p.winner_finalizations +|= 1;
                add(&p.winner_finalization_samples, final_samples.len);
                add(&p.winner_finalization_sample_bytes, try sampleBytes(final_samples));
            }
            const winner_start = begin(io);
            defer if (profile) |p| end(io, winner_start, &p.winner_finalization_ns);
            const standard = try Codec.finalize(allocator, optimized.bytes, final_samples, dictionary_id, io, if (profile) |p| &p.winner_finalizer else null, if (codec_aware) options.candidate_repcodes else true);
            return .{ .bytes = standard.bytes, .view = standard.view, .selected_options = optimized.selected_options, .validation_score = optimized.validation_score, .candidates_evaluated = optimized.candidates_evaluated, .original_dictionary_size = optimized.original_dictionary_size };
        }

        const ScorerContext = struct {
            levels: []const c_int,
            dictionary_id: u32,
            candidate_repcodes: bool,
            io: ?std.Io,
            profile: ?*CodecSearchProfile,
        };
        // Raw validation prices remain codec independent, but unusably short
        // histories must not win a standard-dictionary parameter search.
        const RawScorer = struct {
            allocator: std.mem.Allocator,
            pub fn init(allocator: std.mem.Allocator, _: *const ScorerContext, _: []const []const u8, _: []const []const u8, _: OptimizeOptions) Codec.Error!@This() {
                return .{ .allocator = allocator };
            }
            pub fn accepts(_: *const @This(), content: []const u8) bool {
                return content.len >= 8;
            }
            pub fn score(self: *@This(), content: []const u8, samples: []const []const u8, minimum: usize, _: TrainOptions) Codec.Error!optimize.Score {
                const value = if (content.len < 256)
                    try dictionary.validationScore(content, samples, minimum)
                else
                    try dictionary.validationScoreAlloc(self.allocator, content, samples, minimum);
                return .{ .estimated_bits = value.estimated_bits, .covered_bytes = value.covered_bytes, .matches = value.matches, .distance_bits = value.distance_bits, .dictionary_bytes = content.len };
            }
            pub fn deinit(_: *@This()) void {}
        };
        const Scorer = struct {
            pub const worker_stack_size: usize = 8 * 1024 * 1024;
            allocator: std.mem.Allocator,
            encoder: Codec.FrameEncoder,
            training_samples: []const []const u8,
            levels: []const c_int,
            dictionary_id: u32,
            candidate_repcodes: bool,
            io: ?std.Io,
            profile_enabled: bool,
            private_profile: CodecSearchProfile = .{},

            pub fn init(allocator: std.mem.Allocator, context: *const ScorerContext, training_samples: []const []const u8, _: []const []const u8, _: OptimizeOptions) Codec.Error!@This() {
                return .{ .allocator = allocator, .encoder = Codec.initFrameEncoder(allocator), .training_samples = training_samples, .levels = context.levels, .dictionary_id = context.dictionary_id, .candidate_repcodes = context.candidate_repcodes, .io = context.io, .profile_enabled = context.profile != null };
            }
            pub fn deinit(self: *@This()) void {
                self.encoder.deinit();
            }
            pub fn accepts(_: *const @This(), content: []const u8) bool {
                return content.len >= 8;
            }
            /// The optimizer calls this on the coordinator after worker joins.
            /// Each scorer uses private counters while training and scoring.
            pub fn mergeProfile(self: *const @This(), context: *const ScorerContext) void {
                const profile = context.profile orelse return;
                inline for (.{ "selector_encoding_ns", "candidate_finalizations", "candidate_finalization_samples", "candidate_finalization_sample_bytes", "candidate_encode_attempts", "candidate_frames", "selector_encoded_bytes" }) |field|
                    @field(profile, field) +|= @field(self.private_profile, field);
                inline for (comptime std.meta.fieldNames(Codec.FinalizerProfile)) |field|
                    @field(profile.candidate_finalizer, field) +|= @field(self.private_profile.candidate_finalizer, field);
            }
            pub fn score(self: *@This(), content: []const u8, validation_samples: []const []const u8, _: usize, candidate_options: TrainOptions) Codec.Error!optimize.Score {
                const profile: ?*CodecSearchProfile = if (self.profile_enabled) &self.private_profile else null;
                const final_samples = try finalizationSamples(self.training_samples, candidate_options.acceleration);
                if (profile) |p| {
                    p.candidate_finalizations +|= 1;
                    add(&p.candidate_finalization_samples, final_samples.len);
                    add(&p.candidate_finalization_sample_bytes, try sampleBytes(final_samples));
                }
                const standard = try Codec.finalize(self.allocator, content, final_samples, self.dictionary_id, self.io, if (profile) |p| &p.candidate_finalizer else null, self.candidate_repcodes);
                defer standard.deinit(self.allocator);
                var encoded_size = standard.bytes.len;
                for (validation_samples) |sample| {
                    for (self.levels) |level| {
                        if (profile) |p| p.candidate_encode_attempts +|= 1;
                        const encode_start = begin(self.io);
                        const frame_size = Codec.frameSize(&self.encoder, sample, standard.asDictionary(), level) catch |err| {
                            if (profile) |p| end(self.io, encode_start, &p.selector_encoding_ns);
                            return err;
                        };
                        if (profile) |p| {
                            end(self.io, encode_start, &p.selector_encoding_ns);
                            p.candidate_frames +|= 1;
                            add(&p.selector_encoded_bytes, frame_size);
                        }
                        encoded_size = std.math.add(usize, encoded_size, frame_size) catch return error.InvalidDictionaryTraining;
                    }
                }
                return .{ .estimated_bits = std.math.mul(usize, encoded_size, 8) catch return error.InvalidDictionaryTraining, .dictionary_bytes = standard.bytes.len };
            }
        };

        fn validateMetadata(target_size: usize, dictionary_id: u32) Codec.Error!void {
            if (dictionary_id == 0) return error.InvalidDictionaryMetadata;
            if (target_size < 8) return error.InvalidDictionaryTraining;
        }
        fn finalizationSamples(samples: []const []const u8, acceleration: u8) Codec.Error![]const []const u8 {
            return samples[0..try fast_cover.standardFinalizeSampleCount(samples.len, acceleration)];
        }
        fn sampleBytes(samples: []const []const u8) Codec.Error!usize {
            var bytes: usize = 0;
            for (samples) |sample| bytes = std.math.add(usize, bytes, sample.len) catch return error.InvalidDictionaryTraining;
            return bytes;
        }
        fn add(counter: *u64, amount: usize) void {
            counter.* +|= @intCast(amount);
        }
        fn budgetError(budget: *const working.WorkingAllocator, err: Codec.Error) Codec.Error {
            return if (err == error.OutOfMemory and budget.last_failure_was_limit) error.WorkingMemoryLimitExceeded else err;
        }
        fn begin(io: ?std.Io) ?std.Io.Timestamp {
            return if (io) |value| std.Io.Clock.awake.now(value) else null;
        }
        fn end(io: ?std.Io, started: ?std.Io.Timestamp, field: *u64) void {
            const value = io orelse return;
            const start = started orelse return;
            const ns = start.durationTo(std.Io.Clock.awake.now(value)).nanoseconds;
            if (ns > 0) field.* +|= @intCast(ns);
        }
    };
}
