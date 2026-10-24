const std = @import("std");
const types = @import("fast_cover/types.zig");
const resources = @import("fast_cover/resources.zig");
const kernel = @import("fast_cover/kernel.zig");

pub const TrainOptions = types.TrainOptions;
pub const Profile = types.Profile;
pub const TrainProfile = Profile;
pub const OwnedResult = types.OwnedResult;
pub const min_hash_log = types.min_hash_log;
pub const max_hash_log = types.max_hash_log;
pub const max_acceleration = types.max_acceleration;
pub const default_max_corpus_size = types.default_max_corpus_size;
pub const default_max_working_memory = types.default_max_working_memory;
pub const default_max_dictionary_size = types.default_max_dictionary_size;
pub const standardFinalizePercent = types.standardFinalizePercent;
pub const standardFinalizeFraction = types.standardFinalizeFraction;
pub const standardFinalizeSampleCount = types.standardFinalizeSampleCount;

/// Scalar validation for command-line/front-end use before loading samples.
/// The minimum mandatory table/scratch live cost is also checked here. The
/// owned result is checked after selection determines its actual byte length.
pub fn validateParameters(options: TrainOptions) !void {
    _ = try resources.validateScalar(options);
    if (options.target_size == 0) return;
    const layout = try resources.Layout.init(5, options.hash_log);
    const minimum = try resources.add(layout.bytes(), options.target_size);
    try resources.check(minimum, options.max_working_memory);
}

/// Validate scalar parameters, independent sample bounds, and the mandatory
/// preparation/selection allocations. The owned result's size is known only
/// after selection and is then checked against the remaining live quota.
pub fn validateOptions(samples: []const []const u8, options: TrainOptions) !void {
    try validateParameters(options);
    try resources.check(try resources.requiredPeak(samples, options), options.max_working_memory);
}

pub fn trainAlloc(allocator: std.mem.Allocator, samples: []const []const u8, options: TrainOptions) ![]u8 {
    try validateOptions(samples, options);
    if (options.target_size == 0) {
        if (options.profile) |profile| profile.merge(.{
            .available = true,
            .dmer_size = options.dmer_size,
            .hash_log = options.hash_log,
            .acceleration = options.acceleration,
            .finalize_percent = try standardFinalizePercent(options.acceleration),
            .samples = samples.len,
            .corpus_bytes = (try resources.corpusInfo(samples, options)).bytes,
            .dmer_positions = (try resources.corpusInfo(samples, options)).dmers,
        });
        return allocator.alloc(u8, 0);
    }
    var prepared = try Prepared.init(allocator, samples, options);
    defer prepared.deinit(allocator);
    return prepared.trainAlloc(allocator, options);
}

pub fn trainAllocProfiled(allocator: std.mem.Allocator, samples: []const []const u8, options: TrainOptions) !OwnedResult {
    var profile: Profile = .{};
    defer if (options.profile) |caller| caller.merge(profile);
    var profiled = options;
    profiled.profile = &profile;
    const bytes = try trainAlloc(allocator, samples, profiled);
    return .{ .bytes = bytes, .profile = profile };
}

/// Caller-owned reusable frequency state for a fixed `(d, f, acceleration)`.
/// Both the sample descriptor slice and sample bytes remain borrowed and must
/// stay unchanged throughout this object's prepared lifetime. Heap
/// slices make moves safe; no self pointer or allocator callback is stored.
/// reset() retains capacity, and every training call restores mutable tables,
/// including after failure. Outputs are separately owned exact-size slices.
pub const Prepared = struct {
    samples: []const []const u8 = &.{},
    dmer_size: u8 = 8,
    hash_log: u8 = 20,
    acceleration: u8 = 1,
    profile: Profile = .{},
    workspace: []usize = &.{},
    ring: []u32 = &.{},
    output_scratch: []u8 = &.{},
    info: resources.CorpusInfo = .{},
    ready: bool = false,
    has_frequencies: bool = false,

    pub fn init(allocator: std.mem.Allocator, samples: []const []const u8, options: TrainOptions) !Prepared {
        var result: Prepared = .{};
        errdefer result.deinit(allocator);
        try result.prepare(allocator, samples, options);
        return result;
    }

    pub fn prepare(self: *Prepared, allocator: std.mem.Allocator, samples: []const []const u8, options: TrainOptions) !void {
        try validateOptions(samples, options);
        const info = try resources.corpusInfo(samples, options);
        if (options.target_size == 0) {
            try resources.check(self.workingBytes(), options.max_working_memory);
            self.samples = samples;
            self.dmer_size = options.dmer_size;
            self.hash_log = options.hash_log;
            self.acceleration = options.acceleration;
            self.info = info;
            self.ready = true;
            self.has_frequencies = false;
            self.profile = self.metadata();
            self.profile.prepared_bytes = self.workingBytes();
            self.profile.peak_working_memory = self.workingBytes();
            if (options.profile) |caller| if (caller != &self.profile) caller.merge(self.profile);
            return;
        }
        const layout = try resources.Layout.init(samples.len, options.hash_log);
        const resident = self.workingBytes();
        const growth_peak = if (layout.words > self.workspace.len) try resources.add(resident, layout.bytes()) else resident;
        try resources.check(growth_peak, options.max_working_memory);
        const segment = try resources.validateScalar(options);
        const selection_peak = try resources.selectionPeak(@max(layout.bytes(), self.workspace.len * @sizeOf(usize)), self.ring.len, self.output_scratch.len, resources.ringCount(info, segment, options.dmer_size), options.target_size);
        try resources.check(selection_peak, options.max_working_memory);
        // Allocation is the last fallible operation before replacing prepared
        // content. Failed growth leaves the previous corpus usable.
        if (layout.words > self.workspace.len) {
            const replacement = try allocator.alloc(usize, layout.words);
            allocator.free(self.workspace);
            self.workspace = replacement;
        }
        self.samples = samples;
        self.dmer_size = options.dmer_size;
        self.hash_log = options.hash_log;
        self.acceleration = options.acceleration;
        self.info = info;
        self.ready = true;
        self.has_frequencies = true;
        var delta = self.metadata();
        delta.peak_working_memory = growth_peak;
        delta.prepared_bytes = self.workingBytes();
        kernel.collectFrequencies(samples, options, self.tables(), &delta);
        self.profile = delta;
        if (options.profile) |caller| if (caller != &self.profile) caller.merge(delta);
    }

    pub fn trainAlloc(self: *Prepared, allocator: std.mem.Allocator, options: TrainOptions) ![]u8 {
        const segment = try resources.validateScalar(options);
        if (!self.ready or options.dmer_size != self.dmer_size or options.hash_log != self.hash_log or options.acceleration != self.acceleration or
            self.info.bytes > options.max_corpus_size or (options.target_size != 0 and !self.has_frequencies))
            return error.InvalidDictionaryTraining;
        const ring_needed = resources.ringCount(self.info, segment, self.dmer_size);
        // Include retained capacities and temporary coexistence during growth.
        const maximum = try resources.selectionPeak(self.workspace.len * @sizeOf(usize), self.ring.len, self.output_scratch.len, ring_needed, options.target_size);
        try resources.check(maximum, options.max_working_memory);
        var delta = self.metadata();
        delta.peak_working_memory = self.workingBytes();
        defer {
            delta.prepared_bytes = self.workingBytes();
            self.profile.merge(delta);
            if (options.profile) |caller| if (caller != &self.profile) caller.merge(delta);
        }
        if (ring_needed > self.ring.len) {
            const replacement = try allocator.alloc(u32, ring_needed);
            delta.peak_working_memory = @max(delta.peak_working_memory, self.workingBytes() + replacement.len * @sizeOf(u32));
            allocator.free(self.ring);
            self.ring = replacement;
        }
        if (options.target_size > self.output_scratch.len) {
            const replacement = try allocator.alloc(u8, options.target_size);
            delta.peak_working_memory = @max(delta.peak_working_memory, self.workingBytes() + replacement.len);
            allocator.free(self.output_scratch);
            self.output_scratch = replacement;
        }
        delta.add("training_runs", 1);
        if (self.profile.training_runs > 0) delta.add("prepared_reuses", 1);
        if (options.target_size == 0) return allocator.alloc(u8, 0);
        const content = kernel.buildDictionary(self.samples, self.tables(), self.ring[0..ring_needed], self.output_scratch[0..options.target_size], segment, self.dmer_size, self.hash_log, &delta);
        const result_peak = try resources.add(self.workingBytes(), content.len);
        try resources.check(result_peak, options.max_working_memory);
        const result = try allocator.dupe(u8, content);
        delta.result_bytes = result.len;
        delta.peak_working_memory = @max(delta.peak_working_memory, result_peak);
        return result;
    }

    /// Independent mutable worker state without another corpus-frequency pass.
    /// The source stays borrowed/read-only and remains usable after clone OOM.
    pub fn fork(self: *const Prepared, allocator: std.mem.Allocator, max_working_memory: usize) !Prepared {
        if (!self.ready) return error.InvalidDictionaryTraining;
        if (!self.has_frequencies) {
            try resources.check(self.workingBytes(), max_working_memory);
            var empty: Prepared = .{
                .samples = self.samples,
                .dmer_size = self.dmer_size,
                .hash_log = self.hash_log,
                .acceleration = self.acceleration,
                .info = self.info,
                .ready = true,
            };
            empty.profile = empty.metadata();
            empty.profile.peak_working_memory = self.workingBytes();
            empty.profile.add("prepared_forks", 1);
            return empty;
        }
        const layout = try resources.Layout.init(self.samples.len, self.hash_log);
        const peak = try resources.add(self.workingBytes(), layout.bytes());
        try resources.check(peak, max_working_memory);
        const workspace = try allocator.alloc(usize, layout.words);
        var result: Prepared = .{
            .samples = self.samples,
            .dmer_size = self.dmer_size,
            .hash_log = self.hash_log,
            .acceleration = self.acceleration,
            .workspace = workspace,
            .info = self.info,
            .ready = true,
            .has_frequencies = true,
        };
        const source = self.tables();
        const target = result.tables();
        @memcpy(target.offsets, source.offsets);
        @memcpy(target.base, source.base);
        result.profile = result.metadata();
        result.profile.prepared_bytes = result.workingBytes();
        result.profile.peak_working_memory = peak;
        result.profile.add("prepared_forks", 1);
        result.profile.add("frequency_copy_bytes", source.base.len * @sizeOf(u32));
        return result;
    }

    pub fn baseFrequencies(self: *const Prepared) []const u32 {
        if (!self.ready or !self.has_frequencies) return &.{};
        return self.tables().base;
    }

    pub fn workingBytes(self: *const Prepared) usize {
        return self.workspace.len * @sizeOf(usize) + self.ring.len * @sizeOf(u32) + self.output_scratch.len;
    }

    pub fn reset(self: *Prepared) void {
        self.samples = &.{};
        self.info = .{};
        self.profile.reset();
        self.ready = false;
        self.has_frequencies = false;
    }

    pub fn deinit(self: *Prepared, allocator: std.mem.Allocator) void {
        allocator.free(self.output_scratch);
        allocator.free(self.ring);
        allocator.free(self.workspace);
        self.* = .{};
    }

    fn metadata(self: *const Prepared) Profile {
        return .{
            .available = true,
            .dmer_size = self.dmer_size,
            .hash_log = self.hash_log,
            .acceleration = self.acceleration,
            .finalize_percent = standardFinalizePercent(self.acceleration) catch unreachable,
            .samples = self.samples.len,
            .corpus_bytes = self.info.bytes,
            .dmer_positions = self.info.dmers,
        };
    }

    fn tables(self: *const Prepared) kernel.Tables {
        const layout = resources.Layout.init(self.samples.len, self.hash_log) catch unreachable;
        const offsets = self.workspace[0..layout.offset_words];
        const bytes = std.mem.sliceAsBytes(self.workspace[layout.offset_words..]);
        const entries: []u32 = @alignCast(std.mem.bytesAsSlice(u32, bytes[0 .. layout.table_len * 3 * @sizeOf(u32)]));
        return .{
            .offsets = offsets,
            .base = entries[0..layout.table_len],
            .frequencies = entries[layout.table_len .. 2 * layout.table_len],
            .active = entries[2 * layout.table_len .. 3 * layout.table_len],
        };
    }
};
