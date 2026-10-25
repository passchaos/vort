const std = @import("std");

pub const TreeScoreScope = enum(u2) { baseline, suffix, cluster };

pub const TreeCacheCounts = struct {
    requests: usize = 0,
    hits: usize = 0,
    misses: usize = 0,
    cold_misses: usize = 0,
    conflict_misses: usize = 0,
    cross_scope_hits: usize = 0,
    cross_mode_hits: usize = 0,

    pub fn addSample(self: *TreeCacheCounts, sample: TreeCacheCounts) void {
        inline for (.{ "requests", "hits", "misses", "cold_misses", "conflict_misses", "cross_scope_hits", "cross_mode_hits" }) |field|
            @field(self, field) +%= @field(sample, field);
    }
};

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
    /// True memo lookups; baseline and suffix use direct scoring instead.
    tree_score_scope_counts: [3]TreeCacheCounts = @splat(.{}),
    tree_score_mode_counts: [4][3]TreeCacheCounts = @splat(@splat(.{})),
    /// Completed direct scores, separate from cache lookups/misses. Baseline
    /// has no RFC mode, so its per-mode column remains zero.
    tree_score_uncached_calls: usize = 0,
    tree_score_uncached_scope_calls: [3]usize = @splat(0),
    tree_score_uncached_mode_calls: [4][3]usize = @splat(@splat(0)),
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
    complex_prefix_input_lengths: usize = 0,
    complex_prefix_zero_runs: usize = 0,
    complex_prefix_nonzero_runs: usize = 0,
    complex_prefix_zero_lengths: usize = 0,
    complex_prefix_nonzero_lengths: usize = 0,
    complex_prefix_literal_tokens: usize = 0,
    complex_prefix_repeat16_tokens: usize = 0,
    complex_prefix_repeat17_tokens: usize = 0,
    complex_prefix_repeat_chain_buckets: [4]usize = @splat(0),

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
    complex_prefix_shape_ns: u64 = 0,
    /// Inclusive mode search times; they are not added to stageNs().
    mode_ns: [4]u64 = @splat(0),
    total_ns: u64 = 0,

    pub fn recordTreeCache(self: *Profile, scope: TreeScoreScope, mode: ?u2, counts: TreeCacheCounts) void {
        self.tree_score_scope_counts[@intFromEnum(scope)].addSample(counts);
        if (mode) |value| self.tree_score_mode_counts[value][@intFromEnum(scope)].addSample(counts);
        self.tree_score_cache_hits += counts.hits;
        self.tree_score_cache_misses += counts.misses;
        self.tree_score_cache_cold_misses += counts.cold_misses;
        self.tree_score_cache_conflict_misses += counts.conflict_misses;
    }

    pub fn recordUncachedTree(self: *Profile, scope: TreeScoreScope, mode: ?u2) void {
        self.tree_score_uncached_calls += 1;
        self.tree_score_uncached_scope_calls[@intFromEnum(scope)] += 1;
        if (mode) |value| self.tree_score_uncached_mode_calls[value][@intFromEnum(scope)] += 1;
    }

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
            "tree_score_uncached_calls",
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
            "complex_prefix_input_lengths",
            "complex_prefix_zero_runs",
            "complex_prefix_nonzero_runs",
            "complex_prefix_zero_lengths",
            "complex_prefix_nonzero_lengths",
            "complex_prefix_literal_tokens",
            "complex_prefix_repeat16_tokens",
            "complex_prefix_repeat17_tokens",
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
            "complex_prefix_shape_ns",
            "total_ns",
        }) |field| @field(self, field) +%= @field(sample, field);
        for (&self.tree_active_buckets, sample.tree_active_buckets) |*total, count|
            total.* += count;
        for (&self.complex_prefix_repeat_chain_buckets, sample.complex_prefix_repeat_chain_buckets) |*total, count|
            total.* += count;
        for (&self.tree_score_scope_counts, sample.tree_score_scope_counts) |*total, counts|
            total.addSample(counts);
        for (&self.tree_score_mode_counts, sample.tree_score_mode_counts) |*totals, counts| {
            for (totals, counts) |*total, source_counts| total.addSample(source_counts);
        }
        for (&self.tree_score_uncached_scope_calls, sample.tree_score_uncached_scope_calls) |*total, calls|
            total.* +%= calls;
        for (&self.tree_score_uncached_mode_calls, sample.tree_score_uncached_mode_calls) |*totals, calls| {
            for (totals, calls) |*total, source_calls| total.* +%= source_calls;
        }
        for (&self.mode_ns, sample.mode_ns) |*total, ns| total.* +%= ns;
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
