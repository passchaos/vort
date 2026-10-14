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
    tree_score_cache_cold_misses: usize = 0,
    tree_score_cache_conflict_misses: usize = 0,
    tree_score_calls: usize = 0,
    tree_simple_scores: usize = 0,
    tree_complex_scores: usize = 0,
    tree_active_entries: usize = 0,
    tree_active_buckets: [6]usize = @splat(0),
    small_huffman_calls: usize = 0,
    small_huffman_failures: usize = 0,
    package_merge_calls: usize = 0,
    complex_prefix_calls: usize = 0,
    complex_prefix_rle_tokens: usize = 0,
    complex_prefix_code_length_active: usize = 0,

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
    tree_alphabet_ns: u64 = 0,
    tree_lengths_ns: u64 = 0,
    tree_weighted_ns: u64 = 0,
    tree_prefix_ns: u64 = 0,
    small_huffman_leaf_order_ns: u64 = 0,
    small_huffman_merge_ns: u64 = 0,
    small_huffman_depth_ns: u64 = 0,
    small_huffman_output_ns: u64 = 0,
    complex_prefix_rle_ns: u64 = 0,
    complex_prefix_code_length_tree_ns: u64 = 0,
    complex_prefix_header_ns: u64 = 0,
    complex_prefix_encoder_ns: u64 = 0,
    complex_prefix_payload_ns: u64 = 0,
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

    pub fn treeScoreStageNs(self: Profile) u64 {
        return self.tree_alphabet_ns + self.tree_lengths_ns +
            self.tree_weighted_ns + self.tree_prefix_ns;
    }

    pub fn smallHuffmanStageNs(self: Profile) u64 {
        return self.small_huffman_leaf_order_ns + self.small_huffman_merge_ns +
            self.small_huffman_depth_ns + self.small_huffman_output_ns;
    }

    pub fn complexPrefixStageNs(self: Profile) u64 {
        return self.complex_prefix_rle_ns + self.complex_prefix_code_length_tree_ns +
            self.complex_prefix_header_ns + self.complex_prefix_encoder_ns +
            self.complex_prefix_payload_ns;
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
            "tree_score_cache_cold_misses",
            "tree_score_cache_conflict_misses",
            "tree_score_calls",
            "tree_simple_scores",
            "tree_complex_scores",
            "tree_active_entries",
            "small_huffman_calls",
            "small_huffman_failures",
            "package_merge_calls",
            "complex_prefix_calls",
            "complex_prefix_rle_tokens",
            "complex_prefix_code_length_active",
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
            "tree_alphabet_ns",
            "tree_lengths_ns",
            "tree_weighted_ns",
            "tree_prefix_ns",
            "small_huffman_leaf_order_ns",
            "small_huffman_merge_ns",
            "small_huffman_depth_ns",
            "small_huffman_output_ns",
            "complex_prefix_rle_ns",
            "complex_prefix_code_length_tree_ns",
            "complex_prefix_header_ns",
            "complex_prefix_encoder_ns",
            "complex_prefix_payload_ns",
            "total_ns",
        }) |field| @field(self, field) +%= @field(sample, field);
        for (&self.tree_active_buckets, sample.tree_active_buckets) |*total, count|
            total.* += count;
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
