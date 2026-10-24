const std = @import("std");

pub const min_hash_log: u8 = 1;
pub const max_hash_log: u8 = 31;
pub const max_acceleration: u8 = 10;
pub const default_max_corpus_size: usize = 256 * 1024 * 1024;
pub const default_max_working_memory: usize = 128 * 1024 * 1024;
pub const default_max_dictionary_size: usize = 64 * 1024 * 1024;

pub const TrainOptions = struct {
    target_size: usize,
    segment_size: ?usize = null,
    dmer_size: u8 = 8,
    hash_log: u8 = 20,
    acceleration: u8 = 1,
    max_corpus_size: usize = default_max_corpus_size,
    /// Includes retained preparation, selection scratch, allocation growth and
    /// the owned result while it coexists with that scratch. A caller's outer
    /// allocator can additionally bound an entire optimizer/finalizer operation.
    max_working_memory: usize = default_max_working_memory,
    max_dictionary_size: usize = default_max_dictionary_size,
    profile: ?*Profile = null,
};

const counters = .{
    "frequency_passes",          "frequency_positions", "frequency_hashes",        "frequency_skipped_positions",
    "selection_hashes",          "segment_windows",     "active_adds",             "active_removes",
    "epoch_visits",              "zero_score_epochs",   "selected_segments",       "selected_bytes",
    "frequency_clear_positions", "frequency_clears",    "frequency_restore_bytes", "table_clear_bytes",
    "training_runs",             "prepared_reuses",     "prepared_forks",          "frequency_copy_bytes",
};

/// Optional caller-owned instrumentation. Work counters saturate and accumulate;
/// metadata describes the latest operation, and byte high-water marks take max.
/// No clock or allocator callback is retained by a prepared context.
pub const Profile = struct {
    available: bool = false,
    dmer_size: u8 = 8,
    hash_log: u8 = 20,
    acceleration: u8 = 1,
    finalize_percent: u8 = 100,
    samples: usize = 0,
    corpus_bytes: usize = 0,
    dmer_positions: usize = 0,
    prepared_bytes: usize = 0,
    peak_working_memory: usize = 0,
    result_bytes: usize = 0,
    frequency_passes: u64 = 0,
    frequency_positions: u64 = 0,
    frequency_hashes: u64 = 0,
    frequency_skipped_positions: u64 = 0,
    selection_hashes: u64 = 0,
    segment_windows: u64 = 0,
    active_adds: u64 = 0,
    active_removes: u64 = 0,
    epoch_visits: u64 = 0,
    zero_score_epochs: u64 = 0,
    selected_segments: u64 = 0,
    selected_bytes: u64 = 0,
    frequency_clear_positions: u64 = 0,
    frequency_clears: u64 = 0,
    frequency_restore_bytes: u64 = 0,
    table_clear_bytes: u64 = 0,
    training_runs: u64 = 0,
    prepared_reuses: u64 = 0,
    prepared_forks: u64 = 0,
    frequency_copy_bytes: u64 = 0,

    pub fn reset(self: *Profile) void {
        self.* = .{};
    }

    pub fn add(self: *Profile, comptime field: []const u8, value: usize) void {
        @field(self, field) +|= @as(u64, @intCast(value));
    }

    pub fn merge(self: *Profile, other: Profile) void {
        if (other.available) {
            self.available = true;
            self.dmer_size = other.dmer_size;
            self.hash_log = other.hash_log;
            self.acceleration = other.acceleration;
            self.finalize_percent = other.finalize_percent;
            self.samples = other.samples;
            self.corpus_bytes = other.corpus_bytes;
            self.dmer_positions = other.dmer_positions;
        }
        self.prepared_bytes = @max(self.prepared_bytes, other.prepared_bytes);
        self.peak_working_memory = @max(self.peak_working_memory, other.peak_working_memory);
        self.result_bytes = @max(self.result_bytes, other.result_bytes);
        inline for (counters) |field| @field(self, field) +|= @field(other, field);
    }
};

pub const OwnedResult = struct {
    bytes: []u8,
    profile: Profile,

    pub fn deinit(self: OwnedResult, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

const finalize_percentages = [_]u8{ 100, 50, 34, 25, 20, 17, 14, 13, 11, 10 };

pub fn standardFinalizePercent(acceleration: u8) !u8 {
    if (acceleration == 0 or acceleration > max_acceleration) return error.InvalidDictionaryTraining;
    return finalize_percentages[acceleration - 1];
}

pub fn standardFinalizeFraction(acceleration: u8) !f64 {
    return @as(f64, @floatFromInt(try standardFinalizePercent(acceleration))) / 100.0;
}

/// Exact reference floor. A small nonempty corpus can yield zero samples. A
/// standard-dictionary wrapper must explicitly reject or clamp that case; this
/// helper never substitutes all samples and thereby disables acceleration.
pub fn standardFinalizeSampleCount(sample_count: usize, acceleration: u8) !usize {
    const percent = try standardFinalizePercent(acceleration);
    // Split the multiplication so even maxInt(usize) sample counts are safe.
    return sample_count / 100 * percent + sample_count % 100 * percent / 100;
}
