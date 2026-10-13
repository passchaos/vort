const std = @import("std");

pub const Profile = struct {
    iterations: usize = 0,
    input_bytes: usize = 0,
    literal_count: usize = 0,
    active_symbols: usize = 0,

    suffix_tree_count: u7 = 0,
    suffix_mode: u2 = 0,
    suffix_savings_bits: u64 = 0,
    up_to_16_tree_count: u7 = 0,
    up_to_16_mode: u2 = 0,
    up_to_16_savings_bits: u64 = 0,
    full_tree_count: u7 = 0,
    full_mode: u2 = 0,
    full_savings_bits: u64 = 0,

    suffix_payload_scores: usize = 0,
    suffix_payload_reuses: usize = 0,
    cluster_trials: usize = 0,
    cluster_rounds: usize = 0,
    assignment_contexts: usize = 0,
    assignment_comparisons: usize = 0,
    score_cache_hits: usize = 0,
    score_cache_misses: usize = 0,
    tree_score_cache_hits: usize = 0,
    tree_score_cache_misses: usize = 0,

    analysis_ns: u64 = 0,
    baseline_ns: u64 = 0,
    suffix_ns: u64 = 0,
    sparse_ns: u64 = 0,
    cluster_ns: u64 = 0,
    cluster_init_ns: u64 = 0,
    cluster_prepare_ns: u64 = 0,
    cluster_assignment_ns: u64 = 0,
    cluster_finalize_ns: u64 = 0,
    cluster_score_ns: u64 = 0,
    total_ns: u64 = 0,

    pub fn stageNs(self: Profile) u64 {
        return self.analysis_ns + self.baseline_ns + self.suffix_ns +
            self.sparse_ns + self.cluster_ns;
    }

    pub fn clusterStageNs(self: Profile) u64 {
        return self.cluster_init_ns + self.cluster_prepare_ns +
            self.cluster_assignment_ns + self.cluster_finalize_ns +
            self.cluster_score_ns;
    }

    pub fn addSample(self: *Profile, sample: Profile) void {
        inline for (.{
            "suffix_payload_scores",
            "suffix_payload_reuses",
            "cluster_trials",
            "cluster_rounds",
            "assignment_contexts",
            "assignment_comparisons",
            "score_cache_hits",
            "score_cache_misses",
            "tree_score_cache_hits",
            "tree_score_cache_misses",
            "analysis_ns",
            "baseline_ns",
            "suffix_ns",
            "sparse_ns",
            "cluster_ns",
            "cluster_init_ns",
            "cluster_prepare_ns",
            "cluster_assignment_ns",
            "cluster_finalize_ns",
            "cluster_score_ns",
            "total_ns",
        }) |field| @field(self, field) +%= @field(sample, field);
    }
};

pub const Timer = struct {
    io: std.Io,
    profile: *Profile,

    pub fn now(self: Timer) std.Io.Timestamp {
        return std.Io.Clock.awake.now(self.io);
    }

    pub fn elapsedNs(self: Timer, start: std.Io.Timestamp) u64 {
        const ns = start.durationTo(self.now()).nanoseconds;
        return if (ns <= 0) 0 else @intCast(ns);
    }
};
