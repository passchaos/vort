const std = @import("std");

pub const min_level: c_int = -131072;
pub const max_level: c_int = 22;
pub const max_acceleration: u32 = 131072;
pub const legacy_search_budget: usize = 512;
pub const Error = error{InvalidBlockPlan};

/// Only engines with implemented local, preset and frame-history matching are
/// exposed. Legacy auto retains its established positive-level arbitration.
pub const Strategy = enum { auto, fast, double_fast, greedy, lazy, optimal };
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
    pub fn merge(self: *Profile, other: Profile) void {
        self.available = self.available or other.available;
        self.controls_used = self.controls_used or other.controls_used;
        if (other.controls_used) {
            self.resolved_strategy = other.resolved_strategy;
            self.fast_acceleration = other.fast_acceleration;
        }
        inline for (.{ "positions_tested", "short_hash_probes", "long_hash_probes", "rep_probes", "skipped_positions", "dictionary_seed_positions", "history_seed_positions", "parser_matches", "parser_matched_bytes", "candidate_checks", "lazy_deferrals", "optimal_transitions", "raw_blocks", "rle_blocks", "compressed_blocks", "dictionary_sequences", "history_sequences" }) |field|
            @field(self, field) = std.math.add(u64, @field(self, field), @field(other, field)) catch std.math.maxInt(u64);
        self.max_distance = @max(self.max_distance, other.max_distance);
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
    return options.strategy != .auto or options.fast_acceleration != null;
}
pub fn strategy(options: anytype) Strategy {
    return if (options.strategy == .auto and options.fast_acceleration != null) .fast else options.strategy;
}
pub fn validateNative(options: anytype) Error!void {
    if (options.fast_acceleration) |acceleration|
        if (acceleration == 0 or acceleration > max_acceleration) return error.InvalidBlockPlan;
    if (!active(options)) return;
    if (options.selection != .auto and options.selection != .fast_compressed) return error.InvalidBlockPlan;
    if (options.rep_beam_search) return error.InvalidBlockPlan;
    const selected = strategy(options);
    if (selected == .fast or selected == .double_fast) {
        if (options.match_search_budget != legacy_search_budget) return error.InvalidBlockPlan;
    } else if (options.fast_acceleration != null or options.match_search_budget > legacy_search_budget) return error.InvalidBlockPlan;
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
        native.rep_beam_search = false;
    }
    try validateNative(native);
    return native;
}
