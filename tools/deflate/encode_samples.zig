//! Chronological three-encoder samples. Summaries and JSON serialization run
//! outside measured intervals; warmup samples never enter measured medians.
const std = @import("std");

pub const schema = "vort.codec_encode_samples";
pub const version: u8 = 1;
pub const permutation_count = 6;
pub const default_rounds = 6;
pub const default_warmup = 6;
pub const Encoder = enum { vort, zlib, libdeflate };
pub const Sample = struct { elapsed_ns: u64, mix: u64 };

/// Each encoder occupies every position twice over a complete cycle, and each
/// ordered pair appears in both directions. Counts must cover complete cycles.
pub fn orderForRound(index: usize) [3]Encoder {
    const permutations = [permutation_count][3]Encoder{
        .{ .vort, .zlib, .libdeflate },
        .{ .zlib, .libdeflate, .vort },
        .{ .libdeflate, .vort, .zlib },
        .{ .vort, .libdeflate, .zlib },
        .{ .libdeflate, .zlib, .vort },
        .{ .zlib, .vort, .libdeflate },
    };
    return permutations[index % permutation_count];
}

pub fn validateCounts(iterations: usize, rounds: usize, warmup: usize) !void {
    if (iterations == 0 or rounds == 0 or rounds % permutation_count != 0 or warmup % permutation_count != 0)
        return error.InvalidOptions;
}

pub const Round = struct {
    index: usize,
    order: [3]Encoder,
    vort_ns: u64 = 0,
    zlib_ns: u64 = 0,
    libdeflate_ns: u64 = 0,
    vort_mix: u64 = 0,
    zlib_mix: u64 = 0,
    libdeflate_mix: u64 = 0,

    pub fn init(index: usize) Round {
        return .{ .index = index, .order = orderForRound(index) };
    }

    pub fn record(self: *Round, encoder: Encoder, sample: Sample) void {
        switch (encoder) {
            .vort => {
                self.vort_ns = sample.elapsed_ns;
                self.vort_mix = sample.mix;
            },
            .zlib => {
                self.zlib_ns = sample.elapsed_ns;
                self.zlib_mix = sample.mix;
            },
            .libdeflate => {
                self.libdeflate_ns = sample.elapsed_ns;
                self.libdeflate_mix = sample.mix;
            },
        }
    }
};

pub const Summary = struct {
    vort_min_ns: u64,
    zlib_min_ns: u64,
    libdeflate_min_ns: u64,
    vort_median_ns: u64,
    zlib_median_ns: u64,
    libdeflate_median_ns: u64,
};

pub const WireLengths = struct {
    vort_bytes: usize,
    zlib_bytes: usize,
    libdeflate_bytes: usize,
};
pub const Wires = struct {
    vort_bytes: usize,
    zlib_bytes: usize,
    libdeflate_bytes: usize,
    vort_sha256: [64]u8,
    zlib_sha256: [64]u8,
    libdeflate_sha256: [64]u8,
};

pub fn validateRounds(rounds: []const Round, iterations: usize, wires: WireLengths) !void {
    for (rounds, 0..) |round, index| {
        if (round.index != index or !std.meta.eql(round.order, orderForRound(index)))
            return error.InvalidSampleOrder;
        if (round.vort_mix != expectedMix(wires.vort_bytes, iterations) or
            round.zlib_mix != expectedMix(wires.zlib_bytes, iterations) or
            round.libdeflate_mix != expectedMix(wires.libdeflate_bytes, iterations))
            return error.SampleWireMismatch;
    }
}

pub fn expectedMix(wire_bytes: usize, iterations: usize) u64 {
    return @as(u64, @intCast(wire_bytes)) *% @as(u64, @intCast(iterations));
}

/// Sort scratch storage, retaining every original chronological round. Even
/// medians use the floor of the central mean without overflowing their sum.
pub fn summarize(allocator: std.mem.Allocator, rounds: []const Round) !Summary {
    if (rounds.len == 0) return error.InvalidOptions;
    const count = std.math.mul(usize, rounds.len, 3) catch return error.IntegerOverflow;
    const scratch = try allocator.alloc(u64, count);
    defer allocator.free(scratch);
    const vort = scratch[0..rounds.len];
    const zlib = scratch[rounds.len .. rounds.len * 2];
    const libdeflate = scratch[rounds.len * 2 ..];
    for (rounds, 0..) |round, index| {
        vort[index] = round.vort_ns;
        zlib[index] = round.zlib_ns;
        libdeflate[index] = round.libdeflate_ns;
    }
    std.mem.sort(u64, vort, {}, std.sort.asc(u64));
    std.mem.sort(u64, zlib, {}, std.sort.asc(u64));
    std.mem.sort(u64, libdeflate, {}, std.sort.asc(u64));
    return .{
        .vort_min_ns = vort[0],
        .zlib_min_ns = zlib[0],
        .libdeflate_min_ns = libdeflate[0],
        .vort_median_ns = median(vort),
        .zlib_median_ns = median(zlib),
        .libdeflate_median_ns = median(libdeflate),
    };
}

fn median(sorted: []const u64) u64 {
    const middle = sorted.len / 2;
    if (sorted.len & 1 != 0) return sorted[middle];
    const low = sorted[middle - 1];
    return low + (sorted[middle] - low) / 2;
}

pub const Measurements = struct {
    rounds: []Round,
    warmup_rounds: []Round,

    pub fn init(allocator: std.mem.Allocator, rounds: usize, warmup: usize) !Measurements {
        try validateCounts(1, rounds, warmup);
        const measured = try allocator.alloc(Round, rounds);
        errdefer allocator.free(measured);
        return .{ .rounds = measured, .warmup_rounds = try allocator.alloc(Round, warmup) };
    }

    pub fn deinit(self: Measurements, allocator: std.mem.Allocator) void {
        allocator.free(self.rounds);
        allocator.free(self.warmup_rounds);
    }

    pub fn summary(self: Measurements, allocator: std.mem.Allocator) !Summary {
        return summarize(allocator, self.rounds);
    }

    pub fn validate(self: Measurements, iterations: usize, wires: WireLengths) !void {
        try validateCounts(iterations, self.rounds.len, self.warmup_rounds.len);
        try validateRounds(self.warmup_rounds, iterations, wires);
        try validateRounds(self.rounds, iterations, wires);
    }

    pub fn checksum(self: Measurements) u64 {
        var mix: u64 = 0;
        for (self.rounds) |round|
            mix +%= round.vort_mix ^ round.zlib_mix ^ round.libdeflate_mix;
        return mix;
    }
};

pub const Row = struct {
    case: []const u8,
    input_bytes: usize,
    input_sha256: [64]u8,
    iterations: usize,
    measurements: Measurements,
    summary: Summary,
    level: u4,
    libdeflate_level: u4,
    wires: Wires,
};

pub const Reference = struct {
    role: []const u8,
    version: []const u8,
    version_scope: []const u8,
    link_mode: []const u8 = "build_linked",
    canonical_file_path: ?[]const u8 = null,
    file_sha256: ?[]const u8 = null,
    loaded_identity: ?[]const u8 = null,
    dependencies_verified: bool = false,
};

pub fn write(writer: *std.Io.Writer, row: Row, references: [2]Reference, provenance: anytype) !void {
    try std.json.Stringify.value(.{
        .schema = schema,
        .version = version,
        .codec = "deflate",
        .csv_aggregation = "median",
        .summary_scope = "all_measured_rounds_excluding_warmup",
        .round_order_policy = "six_permutations_repeated",
        .lifecycle = .{
            .state = "cold_per_call",
            .timed_scope = "state_init_output_allocate_encode_return_or_shrink_output_free_state_destroy",
            .libdeflate_compressor_alloc_free = "inside_each_timed_call",
            .warmup_scope = "cpu_and_allocator_only_no_encoder_state_reuse",
        },
        .validation = .{
            .wire_decode_scope = "initial_wire_only",
            .initial_wire_decoders = .{ "vort", "libdeflate_decompress_ex" },
            .initial_wire_full_input_consumed = true,
            .initial_wire_full_output_compared = true,
            .timed_wire_check = "each_iteration_length_equals_initial_wire_plus_round_mix",
            .timed_wire_full_decode = false,
            .input_sha256_rechecked_after_timing = true,
        },
        .rows = .{.{
            .case = row.case,
            .input_bytes = row.input_bytes,
            .input_sha256 = row.input_sha256[0..],
            .iterations = row.iterations,
            .rounds = row.measurements.rounds,
            .warmup_rounds = row.measurements.warmup_rounds,
            .summary = row.summary,
            .settings = .{
                .format = "raw_deflate",
                .comparison_mode = "numeric_level_presets",
                .equal_quality_claim = false,
                .vort_level = row.level,
                .zlib_level = row.level,
                .libdeflate_level = row.libdeflate_level,
                .vort_api = "encodeRawLevelAlloc",
                .zlib_api = "deflateInit2_deflate_Z_FINISH_deflateEnd",
                .libdeflate_api = "alloc_compressor_deflate_compress_free_compressor",
                .output_contract = "allocate_return_owned_exact_length_free_each_call",
                .zlib_window_bits = -15,
                .zlib_memory_level = 8,
                .zlib_strategy = "Z_DEFAULT_STRATEGY",
            },
            .wires = .{
                .scope = "initial_wire_only",
                .vort_bytes = row.wires.vort_bytes,
                .zlib_bytes = row.wires.zlib_bytes,
                .libdeflate_bytes = row.wires.libdeflate_bytes,
                .vort_sha256 = row.wires.vort_sha256[0..],
                .zlib_sha256 = row.wires.zlib_sha256[0..],
                .libdeflate_sha256 = row.wires.libdeflate_sha256[0..],
            },
        }},
        .references = references,
        .provenance = provenance,
    }, .{}, writer);
    try writer.writeByte('\n');
}
