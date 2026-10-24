const std = @import("std");
const distance = @import("distance.zig");

pub const Error = error{InvalidBlockPlan};
pub const max_block_len: usize = 1 << 24;

/// Concrete settings consumed by one HQ operation. Native beam width and
/// extra iterations are explicit Vort controls, not upstream preset parity.
pub const Resolved = struct {
    quality: u8,
    search_depth: u32,
    nice_len: u32,
    beam_width: u8,
    iterations: u8,
    max_working_memory: usize,
    block_len: usize,
    distance_parameters: distance.Parameters,
    format: distance.Format = .standard,
};

/// Caller-owned work and published-output instrumentation. Work survives a
/// rejected candidate; emitted fields are restored if its wire is not published.
pub const HqProfile = struct {
    tree_nodes: u64 = 0,
    byte_comparisons: u64 = 0,
    match_probes: u64 = 0,
    history_seed_positions: u64 = 0,
    short_hash_probes: u64 = 0,
    stitch_positions: u64 = 0,
    normalizations: u64 = 0,
    indexed_positions: u64 = 0,
    states: u64 = 0,
    transitions: u64 = 0,
    price_evaluations: u64 = 0,
    passes: u64 = 0,
    refinement_passes: u64 = 0,
    static_probes: u64 = 0,
    compound_probes: u64 = 0,
    static_candidates: u64 = 0,
    compound_candidates: u64 = 0,
    /// Requested HQ-managed heap peak; excludes generic I/O buffers, retained
    /// plaintext history, complete frame output and the whole-q10 wire guard.
    peak_working_memory: usize = 0,
    emitted_metablocks: u64 = 0,
    emitted_commands: u64 = 0,
    emitted_copy_bytes: u64 = 0,
    emitted_static_commands: u64 = 0,
    emitted_compound_commands: u64 = 0,
    emitted_max_distance: usize = 0,
    effective: ?Resolved = null,

    pub const Emitted = struct {
        emitted_metablocks: u64 = 0,
        emitted_commands: u64 = 0,
        emitted_copy_bytes: u64 = 0,
        emitted_static_commands: u64 = 0,
        emitted_compound_commands: u64 = 0,
        emitted_max_distance: usize = 0,
    };

    pub fn reset(self: *HqProfile) void {
        self.* = .{};
    }
    pub fn add(self: *HqProfile, comptime field: []const u8, amount: usize) void {
        @field(self, field) +|= @as(u64, @intCast(amount));
    }
    pub fn recordPeak(self: *HqProfile, bytes: usize) void {
        self.peak_working_memory = @max(self.peak_working_memory, bytes);
    }
    pub fn recordEffective(self: *HqProfile, resolved: Resolved) void {
        self.effective = resolved;
    }
    pub fn emitted(self: HqProfile) Emitted {
        var value: Emitted = .{};
        inline for (comptime std.meta.fieldNames(Emitted)) |field| @field(value, field) = @field(self, field);
        return value;
    }
    pub fn restoreEmitted(self: *HqProfile, previous: Emitted) void {
        inline for (comptime std.meta.fieldNames(Emitted)) |field| @field(self, field) = @field(previous, field);
    }
    pub fn mergeEmitted(self: *HqProfile, other: Emitted) void {
        inline for (.{ "emitted_metablocks", "emitted_commands", "emitted_copy_bytes", "emitted_static_commands", "emitted_compound_commands" }) |field|
            @field(self, field) +|= @field(other, field);
        self.emitted_max_distance = @max(self.emitted_max_distance, other.emitted_max_distance);
    }
    pub fn mergeWork(self: *HqProfile, other: HqProfile) void {
        inline for (.{ "tree_nodes", "byte_comparisons", "match_probes", "history_seed_positions", "short_hash_probes", "stitch_positions", "normalizations", "indexed_positions", "states", "transitions", "price_evaluations", "passes", "refinement_passes", "static_probes", "compound_probes", "static_candidates", "compound_candidates" }) |field|
            @field(self, field) +|= @field(other, field);
        self.recordPeak(other.peak_working_memory);
        if (other.effective) |effective| self.effective = effective;
    }
    pub fn merge(self: *HqProfile, other: HqProfile) void {
        self.mergeWork(other);
        self.mergeEmitted(other.emitted());
    }
};

pub const HqOptions = struct {
    search_depth: u32 = 64,
    nice_len: u32 = 128,
    beam_width: u8 = 0,
    iterations: u8 = 0,
    /// Limit for HQ-managed dictionaries, models, matchers, parser workspaces,
    /// plans, candidate artifacts and explicitly charged alias snapshots.
    /// Generic stream I/O/history and complete-frame comparison/output storage
    /// use the supplied backing allocator outside this limit.
    max_working_memory: usize = std.math.maxInt(usize),
    block_len: usize = 256 * 1024,
    distance_parameters: ?distance.Parameters = null,
    profile: ?*HqProfile = null,

    pub fn validate(self: HqOptions, quality: u8) Error!void {
        if ((quality != 10 and quality != 11) or self.search_depth == 0 or self.search_depth > 65536 or
            self.nice_len < 2 or self.nice_len > max_block_len or self.beam_width > 32 or self.iterations > 8 or
            self.block_len == 0 or self.block_len > max_block_len) return error.InvalidBlockPlan;
    }
    pub fn resolve(self: HqOptions, quality: u8, mode: anytype) Error!Resolved {
        return self.resolveForFormat(quality, mode, .standard);
    }
    pub fn resolveForFormat(self: HqOptions, quality: u8, mode: anytype, format: distance.Format) Error!Resolved {
        try self.validate(quality);
        return .{
            .quality = quality,
            .search_depth = self.search_depth,
            .nice_len = self.nice_len,
            .beam_width = if (self.beam_width != 0) self.beam_width else if (quality == 10) 8 else 16,
            .iterations = if (self.iterations != 0) self.iterations else if (quality == 10) 1 else 2,
            .max_working_memory = self.max_working_memory,
            .block_len = self.block_len,
            .distance_parameters = self.distance_parameters orelse if (mode == .font) distance.Parameters.init(1, 6) else distance.Parameters.init(0, 0),
            .format = format,
        };
    }
};
