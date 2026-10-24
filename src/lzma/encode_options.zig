//! Shared LZMA1/LZMA2 encoder settings. Presets select concrete parameters;
//! callers can then override them without implicit precedence rules.
const std = @import("std");

pub const Error = error{InvalidLzmaOptions};
pub const max_dictionary_size: usize = 64 * 1024 * 1024;
pub const max_match_len: u16 = 273;

pub const Properties = struct {
    lc: u4 = 3,
    lp: u3 = 0,
    pb: u3 = 2,
};

pub const Mode = enum {
    literal_only,
    greedy,
    lazy,
    fast,
    normal,
};

pub const MatchFinder = enum {
    hc3,
    hc4,
    bt2,
    bt3,
    bt4,

    pub fn hashBytes(self: MatchFinder) u16 {
        return switch (self) {
            .bt2 => 2,
            .hc3, .bt3 => 3,
            .hc4, .bt4 => 4,
        };
    }

    pub fn isBinaryTree(self: MatchFinder) bool {
        return switch (self) {
            .bt2, .bt3, .bt4 => true,
            .hc3, .hc4 => false,
        };
    }
};

/// Work counters accumulate across calls until reset. Effective settings refer
/// to the most recent call. Counters saturate rather than affecting encoding.
/// Memory records requested matcher/parser heap bytes, not process RSS,
/// dictionary/output ownership, caller buffers or fixed coding state.
pub const EncodeWorkProfile = struct {
    mf_positions: u64 = 0,
    mf_seed_positions: u64 = 0,
    mf_skipped_positions: u64 = 0,
    mf_hash_probes: u64 = 0,
    mf_candidate_probes: u64 = 0,
    mf_chain_steps: u64 = 0,
    mf_tree_steps: u64 = 0,
    mf_compared_bytes: u64 = 0,
    mf_matches: u64 = 0,
    mf_peak_working_memory: usize = 0,
    matches: u64 = 0,
    depth_stops: u64 = 0,
    nice_stops: u64 = 0,
    parser_windows: u64 = 0,
    price_evaluations: u64 = 0,
    rep_probes: u64 = 0,
    short_reps: u64 = 0,
    literals: u64 = 0,
    matched_bytes: u64 = 0,
    repeat_matches: u64 = 0,
    peak_working_memory: usize = 0,
    effective_nice_len: u16 = 0,
    effective_depth: u32 = 0,
    finder: MatchFinder = .hc4,

    pub fn reset(self: *EncodeWorkProfile) void {
        self.* = .{};
    }
};

pub const MatchOptions = struct {
    finder: MatchFinder = .hc4,
    nice_len: u16 = 64,
    depth: u32 = 0,
    max_working_memory: usize = std.math.maxInt(usize),
    profile: ?*EncodeWorkProfile = null,

    pub fn validate(self: MatchOptions) Error!void {
        if (self.nice_len < 2 or self.nice_len > max_match_len)
            return error.InvalidLzmaOptions;
    }

    pub fn effectiveNiceLen(self: MatchOptions) u16 {
        return @max(self.nice_len, self.finder.hashBytes());
    }

    pub fn effectiveDepth(self: MatchOptions) u32 {
        if (self.depth != 0) return self.depth;
        const nice: u32 = self.effectiveNiceLen();
        return if (self.finder.isBinaryTree()) 16 + nice / 2 else 4 + nice / 4;
    }
};

pub const Preset = struct {
    properties: Properties = .{},
    dictionary_size: u32,
    mode: Mode,
    match_options: MatchOptions,
};

/// Resolve the liblzma 5.8.4 preset parameter table. This is parameter parity,
/// not a promise of identical compressed bytes, ratio or throughput.
pub fn resolvePreset(level: u32, extreme: bool) Error!Preset {
    if (level > 9) return error.InvalidLzmaOptions;
    const dictionary_sizes = [_]u32{
        256 * 1024,       1024 * 1024,      2 * 1024 * 1024, 4 * 1024 * 1024,
        4 * 1024 * 1024,  8 * 1024 * 1024,  8 * 1024 * 1024, 16 * 1024 * 1024,
        32 * 1024 * 1024, 64 * 1024 * 1024,
    };
    var resolved = Preset{
        .dictionary_size = dictionary_sizes[level],
        .mode = if (level <= 3) .fast else .normal,
        .match_options = .{
            .finder = if (level == 0) .hc3 else if (level <= 3) .hc4 else .bt4,
            .nice_len = switch (level) {
                0, 1 => 128,
                2, 3 => 273,
                4 => 16,
                5 => 32,
                else => 64,
            },
            .depth = switch (level) {
                0 => 4,
                1 => 8,
                2 => 24,
                3 => 48,
                else => 0,
            },
        },
    };
    if (extreme) {
        resolved.mode = .normal;
        resolved.match_options.finder = .bt4;
        resolved.match_options.nice_len = if (level == 3 or level == 5) 192 else 273;
        resolved.match_options.depth = if (level == 3 or level == 5) 0 else 512;
    }
    return resolved;
}

test "LZMA preset validation and modern effective match limits" {
    try std.testing.expectError(error.InvalidLzmaOptions, resolvePreset(10, false));
    try std.testing.expectError(error.InvalidLzmaOptions, resolvePreset(std.math.maxInt(u32), true));
    try std.testing.expectError(error.InvalidLzmaOptions, (MatchOptions{ .nice_len = 1 }).validate());
    try std.testing.expectError(error.InvalidLzmaOptions, (MatchOptions{ .nice_len = 274 }).validate());
    const minimum = MatchOptions{ .finder = .bt4, .nice_len = 2 };
    try minimum.validate();
    try std.testing.expectEqual(@as(u16, 4), minimum.effectiveNiceLen());
    try std.testing.expectEqual(@as(u32, 18), minimum.effectiveDepth());
    try std.testing.expectEqual(@as(u32, 512), (try resolvePreset(9, true)).match_options.effectiveDepth());
}
