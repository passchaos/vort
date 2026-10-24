const std = @import("std");
const fast = @import("../fast_cover.zig");

const default_dmers = [_]u8{ 6, 8 };
const default_hashes = [_]u8{ 12, 16 };
const default_accelerations = [_]u8{1};

pub const maximum_candidates: usize = 256;
pub const maximum_threads: usize = 16;
pub const maximum_variants: usize = 34;

/// Integer held-out partition. A ratio of one explicitly reuses the complete
/// corpus for training and validation, matching upstream splitPoint=1 policy.
pub const SplitPoint = struct { numerator: usize = 3, denominator: usize = 4 };
pub const Partitions = struct { training: []const []const u8, validation: []const []const u8 };

pub const OptimizeOptions = struct {
    target_size: usize,
    segment_sizes: []const usize = &.{},
    dmer_sizes: []const u8 = &default_dmers,
    hash_logs: []const u8 = &default_hashes,
    accelerations: []const u8 = &default_accelerations,
    /// Automatic k ladder uses exactly this many evenly spaced endpoints before
    /// duplicate folding. Explicit segment_sizes takes precedence.
    steps: usize = 4,
    segment_min: ?usize = null,
    segment_max: ?usize = null,
    min_match_len: usize = 4,
    max_corpus_size: usize = fast.default_max_corpus_size,
    max_samples: usize = 1024 * 1024,
    /// Optimizer allocator-owned heap plus requested native worker stacks.
    /// Fixed caller execution state and OS/bootstrap overhead are excluded;
    /// this is a requested working budget, not a process RSS limit.
    max_working_memory: usize = fast.default_max_working_memory,
    max_dictionary_size: usize = fast.default_max_dictionary_size,
    max_candidates: usize = 64,
    max_scoring_calls: usize = 8192,
    threads: usize = 1,
    max_threads: usize = maximum_threads,
    shrink_dictionary: bool = false,
    shrink_min_size: usize = 256,
    /// Charged validation cost may regress by at most this many basis points
    /// against the best full candidate. Zero permits no cost regression.
    regression_tolerance_bps: u16 = 0,
    profile: ?*Profile = null,
};

/// estimated_bits includes dictionary distribution cost exactly once. Stateful
/// codec scorers can report serialized dictionary size separately from content.
pub const Score = struct {
    estimated_bits: usize = 0,
    covered_bytes: usize = 0,
    matches: usize = 0,
    distance_bits: usize = 0,
    dictionary_bytes: ?usize = null,
};

pub const Profile = struct {
    available: bool = false,
    training: fast.Profile = .{},
    training_samples: usize = 0,
    validation_samples: usize = 0,
    corpus_bytes: usize = 0,
    threads_used: usize = 1,
    peak_working_memory: usize = 0,
    peak_allocator_owned_bytes: usize = 0,
    thread_stack_reservation_peak: usize = 0,
    result_bytes: usize = 0,
    charged_dictionary_bytes: usize = 0,
    candidate_grid_points: u64 = 0,
    prepared_groups: u64 = 0,
    candidates_evaluated: u64 = 0,
    scoring_calls: u64 = 0,
    shrink_evaluations: u64 = 0,
    shrink_selected: u64 = 0,
    thread_spawn_fallbacks: u64 = 0,

    pub fn reset(self: *Profile) void {
        self.* = .{};
    }
    pub fn add(self: *Profile, comptime field: []const u8, value: usize) void {
        @field(self, field) +|= @as(u64, @intCast(value));
    }
    pub fn merge(self: *Profile, other: Profile) void {
        self.available = self.available or other.available;
        self.training.merge(other.training);
        self.training_samples = other.training_samples;
        self.validation_samples = other.validation_samples;
        self.corpus_bytes = other.corpus_bytes;
        self.threads_used = @max(self.threads_used, other.threads_used);
        self.peak_working_memory = @max(self.peak_working_memory, other.peak_working_memory);
        self.peak_allocator_owned_bytes = @max(self.peak_allocator_owned_bytes, other.peak_allocator_owned_bytes);
        self.thread_stack_reservation_peak = @max(self.thread_stack_reservation_peak, other.thread_stack_reservation_peak);
        self.result_bytes = other.result_bytes;
        self.charged_dictionary_bytes = other.charged_dictionary_bytes;
        inline for (.{ "candidate_grid_points", "prepared_groups", "candidates_evaluated", "scoring_calls", "shrink_evaluations", "shrink_selected", "thread_spawn_fallbacks" }) |field|
            @field(self, field) +|= @field(other, field);
    }
};

pub const OwnedResult = struct {
    bytes: []u8,
    selected_options: fast.TrainOptions,
    validation_score: Score,
    candidates_evaluated: usize,
    profile: Profile,
    original_dictionary_size: usize,

    pub fn deinit(self: OwnedResult, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};
