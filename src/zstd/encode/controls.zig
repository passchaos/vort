const std = @import("std");
pub const HqOptions = @import("hq_options.zig").HqOptions;

pub const min_level: c_int = -131072;
pub const max_level: c_int = 22;
pub const max_acceleration: u32 = 131072;
pub const legacy_search_budget: usize = 512;
pub const Error = error{InvalidBlockPlan};

/// Only engines with implemented local, preset and frame-history matching are
/// exposed. Legacy auto retains its established positive-level arbitration.
pub const Strategy = enum { auto, fast, double_fast, greedy, lazy, optimal, lazy2, btlazy2, btopt, btultra, btultra2 };
pub const optimal_block_limit: usize = 32 * 1024;

/// Caller-owned, optional instrumentation. Counters saturate and accumulate
/// across encoder calls and independently framed seekable entries; reset when
/// starting a new measurement. Search work includes rejected candidates and
/// failed attempts; emitted counters only describe successfully published wire.
pub const Profile = struct {
    available: bool = false,
    controls_used: bool = false,
    resolved_strategy: Strategy = .auto,
    fast_acceleration: u32 = 1,
    /// Explicit window configuration, separate from a single-segment header.
    requested_window_size: ?u64 = null,
    /// Policy intersection, not the number of history bytes already retained.
    effective_match_history_len: usize = 0,
    positions_tested: u64 = 0,
    short_hash_probes: u64 = 0,
    long_hash_probes: u64 = 0,
    rep_probes: u64 = 0,
    skipped_positions: u64 = 0,
    dictionary_seed_positions: u64 = 0,
    history_seed_positions: u64 = 0,
    parser_matches: u64 = 0,
    parser_matched_bytes: u64 = 0,
    candidate_checks: u64 = 0,
    lazy_deferrals: u64 = 0,
    optimal_transitions: u64 = 0,
    /// Nodes actually visited by the tree search, not allocated capacity.
    tree_nodes: u64 = 0,
    byte_comparisons: u64 = 0,
    depth_stops: u64 = 0,
    nice_stops: u64 = 0,
    price_evaluations: u64 = 0,
    hq_passes: u64 = 0,
    refinement_passes: u64 = 0,
    shared_seed_reuses: u64 = 0,
    peak_working_memory: usize = 0,
    hq_used: bool = false,
    effective_hq_search_depth: u32 = 0,
    effective_hq_nice_len: u32 = 0,
    effective_hq_min_match: u8 = 0,
    effective_hq_max_working_memory: usize = 0,
    raw_blocks: u64 = 0,
    rle_blocks: u64 = 0,
    compressed_blocks: u64 = 0,
    dictionary_sequences: u64 = 0,
    history_sequences: u64 = 0,
    max_distance: usize = 0,

    pub const Emitted = struct {
        raw_blocks: u64 = 0,
        rle_blocks: u64 = 0,
        compressed_blocks: u64 = 0,
        dictionary_sequences: u64 = 0,
        history_sequences: u64 = 0,
        max_distance: usize = 0,
    };

    pub fn emitted(self: *const Profile) Emitted {
        var result: Emitted = .{};
        inline for (comptime std.meta.fieldNames(Emitted)) |field| @field(result, field) = @field(self, field);
        return result;
    }
    pub fn restoreEmitted(self: *Profile, previous: Emitted) void {
        inline for (comptime std.meta.fieldNames(Emitted)) |field| @field(self, field) = @field(previous, field);
    }
    pub fn mergeEmitted(self: *Profile, other: Emitted) void {
        inline for (.{ "raw_blocks", "rle_blocks", "compressed_blocks", "dictionary_sequences", "history_sequences" }) |field|
            @field(self, field) = std.math.add(u64, @field(self, field), @field(other, field)) catch std.math.maxInt(u64);
        self.max_distance = @max(self.max_distance, other.max_distance);
    }
    pub fn mergeWork(self: *Profile, other: Profile) void {
        var work = other;
        work.restoreEmitted(.{});
        self.merge(work);
    }
    pub fn reset(self: *Profile) void {
        self.* = .{};
    }
    pub fn add(self: *Profile, comptime field: []const u8, value: usize) void {
        @field(self, field) = std.math.add(u64, @field(self, field), @as(u64, @intCast(value))) catch std.math.maxInt(u64);
    }
    /// Metadata only; use after scalar validation even for empty/stored work.
    pub fn recordEffectiveHq(self: *Profile, options: ?HqOptions) void {
        self.hq_used = options != null;
        self.effective_hq_search_depth = if (options) |hq| hq.search_depth else 0;
        self.effective_hq_nice_len = if (options) |hq| hq.nice_len else 0;
        self.effective_hq_min_match = if (options) |hq| hq.min_match else 0;
        self.effective_hq_max_working_memory = if (options) |hq| hq.max_working_memory else 0;
    }
    pub fn recordPeakWorkingMemory(self: *Profile, bytes: usize) void {
        self.peak_working_memory = @max(self.peak_working_memory, bytes);
    }
    pub fn recordWindowPolicy(self: *Profile, requested: ?u64, effective: usize) void {
        self.requested_window_size = requested;
        self.effective_match_history_len = effective;
    }
    pub fn merge(self: *Profile, other: Profile) void {
        self.available = self.available or other.available;
        self.controls_used = self.controls_used or other.controls_used;
        if (other.effective_match_history_len != 0)
            self.recordWindowPolicy(other.requested_window_size, other.effective_match_history_len);
        if (other.controls_used) {
            self.resolved_strategy = other.resolved_strategy;
            self.fast_acceleration = other.fast_acceleration;
            inline for (.{ "hq_used", "effective_hq_search_depth", "effective_hq_nice_len", "effective_hq_min_match", "effective_hq_max_working_memory" }) |field|
                @field(self, field) = @field(other, field);
        }
        inline for (.{ "positions_tested", "short_hash_probes", "long_hash_probes", "rep_probes", "skipped_positions", "dictionary_seed_positions", "history_seed_positions", "parser_matches", "parser_matched_bytes", "candidate_checks", "lazy_deferrals", "optimal_transitions", "tree_nodes", "byte_comparisons", "depth_stops", "nice_stops", "price_evaluations", "hq_passes", "refinement_passes", "shared_seed_reuses", "raw_blocks", "rle_blocks", "compressed_blocks", "dictionary_sequences", "history_sequences" }) |field|
            @field(self, field) = std.math.add(u64, @field(self, field), @field(other, field)) catch std.math.maxInt(u64);
        self.max_distance = @max(self.max_distance, other.max_distance);
        self.peak_working_memory = @max(self.peak_working_memory, other.peak_working_memory);
    }
};

/// Search work survives an operation failure; selected-wire counts are
/// restored when that operation does not publish its encoded output.
pub const EmissionTransaction = struct {
    profile: ?*Profile,
    previous: Profile.Emitted,

    pub fn init(profile: ?*Profile) EmissionTransaction {
        return .{ .profile = profile, .previous = if (profile) |p| p.emitted() else .{} };
    }
    pub fn rollback(self: EmissionTransaction) void {
        if (self.profile) |p| p.restoreEmitted(self.previous);
    }
};

pub fn active(options: anytype) bool {
    return options.strategy != .auto or options.fast_acceleration != null or hqField(options) != null;
}
pub fn strategy(options: anytype) Strategy {
    return if (options.strategy == .auto and options.fast_acceleration != null) .fast else options.strategy;
}
pub fn validateNative(options: anytype) Error!void {
    if (options.fast_acceleration) |acceleration|
        if (acceleration == 0 or acceleration > max_acceleration) return error.InvalidBlockPlan;
    if (hqField(options)) |hq| {
        try hq.validate();
        if (!isHq(strategy(options))) return error.InvalidBlockPlan;
    }
    if (!active(options)) return;
    if (options.selection != .auto and options.selection != .fast_compressed) return error.InvalidBlockPlan;
    if (options.rep_beam_search) return error.InvalidBlockPlan;
    const selected = strategy(options);
    if (isHq(selected)) {
        if (options.fast_acceleration != null or options.match_search_budget != legacy_search_budget)
            return error.InvalidBlockPlan;
        return;
    }
    if (selected == .fast or selected == .double_fast) {
        if (options.match_search_budget != legacy_search_budget) return error.InvalidBlockPlan;
    } else if (options.fast_acceleration != null or options.match_search_budget > legacy_search_budget) return error.InvalidBlockPlan;
}

pub fn isHq(selected: Strategy) bool {
    return switch (selected) {
        .lazy2, .btlazy2, .btopt, .btultra, .btultra2 => true,
        else => false,
    };
}

fn hqField(options: anytype) ?HqOptions {
    return if (@hasField(@TypeOf(options), "hq")) options.hq else null;
}

/// Local quality/effort defaults, not a claim of libzstd preset parity. Native
/// calls without a level use level 3; frame calls preserve their explicit level.
pub fn resolvedHqDefaults(selected: Strategy, requested_level: ?c_int) Error!HqOptions {
    const level = requested_level orelse 3;
    if (!isHq(selected) or level <= 0 or level > max_level) return error.InvalidBlockPlan;
    const depth: u32 = if (level <= 3) 16 else if (level <= 6) 32 else if (level <= 12) 64 else if (level <= 18) 128 else 256;
    const nice: u32 = if (level <= 3) 32 else if (level <= 6) 64 else if (level <= 12) 128 else if (level <= 18) 256 else 512;
    return switch (selected) {
        .lazy2 => .{ .search_depth = depth / 2, .nice_len = nice },
        .btlazy2 => .{ .search_depth = depth, .nice_len = @max(64, nice) },
        .btopt => .{ .search_depth = @max(64, depth), .nice_len = @max(128, nice) },
        .btultra => .{ .search_depth = @max(128, depth), .nice_len = @max(256, nice) },
        .btultra2 => .{ .search_depth = @max(256, depth), .nice_len = @max(512, nice) },
        else => unreachable,
    };
}

pub fn effectiveHq(options: anytype) Error!?HqOptions {
    if (!isHq(strategy(options))) {
        if (hqField(options) != null) return error.InvalidBlockPlan;
        return null;
    }
    if (hqField(options)) |hq| {
        try hq.validate();
        return hq;
    }
    return try resolvedHqDefaults(strategy(options), null);
}

pub fn resolve(comptime NativeOptions: type, level: c_int, options: anytype) Error!NativeOptions {
    if (level < min_level or level > max_level) return error.InvalidBlockPlan;
    var native: NativeOptions = .{
        .content_checksum = options.content_checksum,
        .include_content_size = options.include_content_size,
        .window_log = options.window_log,
        .max_match_history_len = options.max_match_history_len,
        .strategy = options.strategy,
        .fast_acceleration = options.fast_acceleration,
        .control_profile = options.control_profile,
    };
    if (@hasField(NativeOptions, "max_total_working_memory"))
        native.max_total_working_memory = if (@hasField(@TypeOf(options), "max_total_working_memory")) options.max_total_working_memory else null;
    if (@hasField(NativeOptions, "memory_profile"))
        native.memory_profile = if (@hasField(@TypeOf(options), "memory_profile")) options.memory_profile else null;
    if (@hasField(NativeOptions, "hq")) {
        native.hq = hqField(options);
    } else if (hqField(options) != null or isHq(native.strategy)) return error.InvalidBlockPlan;
    if (level < 0) {
        // Validate the signed range before negation so minInt(c_int) is safe.
        const magnitude: u32 = @intCast(-level);
        if (native.fast_acceleration) |explicit|
            if (explicit != magnitude) return error.InvalidBlockPlan;
        native.fast_acceleration = magnitude;
        if (native.strategy == .auto) native.strategy = .fast;
        if (native.strategy != .fast and native.strategy != .double_fast) return error.InvalidBlockPlan;
        native.selection = .fast_compressed;
    } else if (level == 0) {
        if (active(native)) return error.InvalidBlockPlan;
        native.selection = .raw_or_rle;
        native.match_search_budget = 0;
    } else {
        native.match_search_budget = switch (level) {
            1 => 16,
            2 => 32,
            3 => 64,
            4 => 96,
            5 => 128,
            else => 96,
        };
        native.rep_beam_search = (level >= 1 and level <= 3) or level >= 9;
    }
    if (active(native)) {
        native.strategy = strategy(native);
        native.selection = .fast_compressed;
        if (strategy(native) == .fast or strategy(native) == .double_fast)
            native.match_search_budget = legacy_search_budget;
        if (isHq(native.strategy)) {
            native.match_search_budget = legacy_search_budget;
            if (@hasField(NativeOptions, "hq"))
                native.hq = native.hq orelse try resolvedHqDefaults(native.strategy, level);
        }
        native.rep_beam_search = false;
    }
    try validateNative(native);
    return native;
}

test {
    _ = @import("controls_hq_tests.zig");
}
