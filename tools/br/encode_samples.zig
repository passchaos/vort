//! Raw primary encoding rounds and their reproducibility metadata. All file
//! hashing, validation and JSON work remains outside measured clock intervals.
const std = @import("std");
const libbrotli = @import("libbrotli_runtime.zig");

pub const round_count = 5;
pub const Sample = struct { ns: u64, mix: usize };
pub const Round = struct {
    index: usize,
    vort_first: bool,
    vort_ns: u64,
    reference_ns: u64,
    vort_mix: usize,
    reference_mix: usize,
};
pub const Summary = struct {
    vort_min_ns: u64,
    reference_min_ns: u64,
    vort_median_ns: u64,
    reference_median_ns: u64,
};
pub const Interleaved = struct {
    vort: Sample,
    reference: Sample,
    rounds: [round_count]Round,

    pub fn fromRounds(rounds: [round_count]Round) Interleaved {
        var best_vort = Sample{ .ns = std.math.maxInt(u64), .mix = 0 };
        var best_reference = best_vort;
        for (rounds) |round| {
            // The existing CSV uses the first minimum, including its mix.
            if (round.vort_ns < best_vort.ns) best_vort = .{ .ns = round.vort_ns, .mix = round.vort_mix };
            if (round.reference_ns < best_reference.ns) best_reference = .{ .ns = round.reference_ns, .mix = round.reference_mix };
        }
        return .{ .vort = best_vort, .reference = best_reference, .rounds = rounds };
    }

    pub fn summary(self: Interleaved) Summary {
        var vort_ns: [round_count]u64 = undefined;
        var reference_ns: [round_count]u64 = undefined;
        for (self.rounds, 0..) |round, index| {
            vort_ns[index] = round.vort_ns;
            reference_ns[index] = round.reference_ns;
        }
        return .{
            .vort_min_ns = self.vort.ns,
            .reference_min_ns = self.reference.ns,
            .vort_median_ns = median(&vort_ns),
            .reference_median_ns = median(&reference_ns),
        };
    }

    pub fn validate(self: Interleaved, iterations: usize, vort_bytes: usize, reference_bytes: usize) !void {
        for (self.rounds, 0..) |round, index| {
            if (round.index != index or round.vort_first != (index & 1 == 0)) return error.InvalidSampleOrder;
            if (round.vort_mix != vort_bytes *% iterations or round.reference_mix != reference_bytes *% iterations)
                return error.SampleWireMismatch;
        }
    }
};

/// Sort a local copy, retaining chronological raw rounds. Even medians use the
/// floor of the two central values' average without adding them directly.
pub fn median(values: []u64) u64 {
    std.debug.assert(values.len != 0);
    std.mem.sort(u64, values, {}, std.sort.asc(u64));
    const high = values[values.len / 2];
    if (values.len & 1 != 0) return high;
    const low = values[values.len / 2 - 1];
    return low + (high - low) / 2;
}

pub const Wires = struct {
    vort_bytes: usize,
    reference_bytes: usize,
    vort_sha256: [64]u8,
    reference_sha256: [64]u8,
};
pub const Settings = struct {
    vort_api: []const u8,
    vort_level: []const u8 = "fast",
    /// Null means the actual legacy fast policy, not a numeric quality preset.
    planned_quality: ?u4,
    vort_mode: []const u8,
    vort_command_state_max_input_kib: u8,
    vort_command_state_override_requested: ?u8,
    vort_window_bits: ?u5 = null,
    vort_default_window_bits: u5,
    vort_large_window: bool = false,
    vort_metadata_bytes: usize = 0,
    vort_max_total_working_memory: ?usize = null,
    vort_memory_profile_enabled: bool = false,
    vort_hq_enabled: bool = false,
    reference_quality: c_int,
    reference_quality_override_requested: ?c_int,
    reference_case_quality: ?c_int,
    reference_lgwin: c_int = 22,
    reference_mode: c_int = 0,
    auxiliary_lazy_level: []const u8 = "balanced",
    auxiliary_ratio_level: []const u8 = "ratio",
    auxiliary_ratio_extended_dictionary_probes_requested: u16,
    auxiliary_ratio_extended_dictionary_probes_effective: u16,
    auxiliary_ratio_adaptive_command_split: bool,
    auxiliary_ratio_adaptive_literal_split: bool,
    auxiliary_ratio_adaptive_distance_split: ?bool,
    auxiliary_ratio_distance_parameter_search: ?bool,
};
pub const Row = struct {
    case: []const u8,
    input_bytes: usize,
    input_sha256: [64]u8,
    iterations: usize,
    rounds: [round_count]Round,
    summary: Summary,
    wires: Wires,
    settings: Settings,
};

/// Missing components are rejected before loading or timing, including runs
/// that request explicit libraries without a samples file.
pub const PathOptions = struct {
    encoder: ?[]const u8 = null,
    decoder: ?[]const u8 = null,
    common: ?[]const u8 = null,

    pub fn complete(self: PathOptions) !?libbrotli.Paths {
        const count = @as(u2, @intFromBool(self.encoder != null)) + @as(u2, @intFromBool(self.decoder != null)) + @as(u2, @intFromBool(self.common != null));
        if (count == 0) return null;
        if (count != 3) return error.IncompleteReferencePaths;
        const paths = libbrotli.Paths{ .encoder = self.encoder.?, .decoder = self.decoder.?, .common = self.common.? };
        try paths.validate();
        return paths;
    }
};

/// Resolve explicit FILE arguments before Runtime.openPaths. Bare filenames
/// therefore refer to files in cwd instead of requesting SONAME lookup.
pub const ResolvedPaths = struct {
    encoder: [:0]u8,
    decoder: [:0]u8,
    common: [:0]u8,

    pub fn init(io: std.Io, allocator: std.mem.Allocator, requested: libbrotli.Paths) !ResolvedPaths {
        try requested.validate();
        const encoder = try std.Io.Dir.cwd().realPathFileAlloc(io, requested.encoder, allocator);
        errdefer allocator.free(encoder);
        const decoder = try std.Io.Dir.cwd().realPathFileAlloc(io, requested.decoder, allocator);
        errdefer allocator.free(decoder);
        return .{ .encoder = encoder, .decoder = decoder, .common = try std.Io.Dir.cwd().realPathFileAlloc(io, requested.common, allocator) };
    }

    pub fn paths(self: ResolvedPaths) libbrotli.Paths {
        return .{ .encoder = self.encoder, .decoder = self.decoder, .common = self.common };
    }

    pub fn deinit(self: ResolvedPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.encoder);
        allocator.free(self.decoder);
        allocator.free(self.common);
    }
};

pub const Library = struct {
    role: []const u8,
    requested_path: ?[]const u8,
    successful_open_argument: []const u8,
    /// Identity of the file that was requested/opened and hashed. The loader's
    /// actual dependency graph and symbol-object provenance remain unverified.
    canonical_file_path: ?[:0]u8 = null,
    file_sha256: ?[64]u8 = null,
    file_bytes: ?usize = null,
    version: ?u32,
    loaded_identity: ?[]const u8 = null,
    dependencies_verified: bool = false,
    identity_status: []const u8 = "unknown",
};
pub const References = struct {
    libraries: [3]Library,
    encoder_version: u32,
    decoder_version: u32,

    pub fn capture(io: std.Io, allocator: std.mem.Allocator, runtime: libbrotli.Runtime, requested: ?libbrotli.Paths) !References {
        const encoder_version = runtime.encoder_version();
        const decoder_version = runtime.decoder_version();
        const encoder = try identify(io, allocator, "brotli_encoder", if (requested) |paths| paths.encoder else null, runtime.opened_names.encoder, encoder_version);
        errdefer if (encoder.canonical_file_path) |path| allocator.free(path);
        const decoder = try identify(io, allocator, "brotli_decoder", if (requested) |paths| paths.decoder else null, runtime.opened_names.decoder, decoder_version);
        errdefer if (decoder.canonical_file_path) |path| allocator.free(path);
        return .{
            .libraries = .{ encoder, decoder, try identify(io, allocator, "brotli_common", if (requested) |paths| paths.common else null, runtime.opened_names.common, null) },
            .encoder_version = encoder_version,
            .decoder_version = decoder_version,
        };
    }

    pub fn deinit(self: References, allocator: std.mem.Allocator) void {
        for (self.libraries) |library| if (library.canonical_file_path) |path| allocator.free(path);
    }
};

fn identify(io: std.Io, allocator: std.mem.Allocator, role: []const u8, requested: ?[]const u8, opened: []const u8, version: ?u32) !Library {
    var library: Library = .{ .role = role, .requested_path = requested, .successful_open_argument = opened, .version = version };
    // A successful SONAME lookup does not identify a physical file. Never fill
    // in a guessed /lib or /usr/lib path for this default path.
    if (!hasFilePath(opened)) return library;
    const path = std.Io.Dir.cwd().realPathFileAlloc(io, opened, allocator) catch |err| {
        if (requested != null) return err;
        return library;
    };
    errdefer allocator.free(path);
    const digest = hashFile(io, path) catch |err| {
        if (requested != null) return err;
        allocator.free(path);
        return library;
    };
    library.canonical_file_path = path;
    library.file_sha256 = digest.hex;
    library.file_bytes = digest.bytes;
    library.identity_status = "requested_file_hashed_actual_object_unverified";
    return library;
}

fn hasFilePath(path: []const u8) bool {
    return std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, '/') != null or std.mem.indexOfScalar(u8, path, '\\') != null;
}

fn hashFile(io: std.Io, path: []const u8) !struct { hex: [64]u8, bytes: usize } {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var reader_buffer: [16 * 1024]u8 = undefined;
    var reader = file.readerStreaming(io, &reader_buffer);
    var hash_buffer: [16 * 1024]u8 = undefined;
    var hashing: std.Io.Writer.Hashing(std.crypto.hash.sha2.Sha256) = .init(&hash_buffer);
    const bytes = try reader.interface.streamRemaining(&hashing.writer);
    try hashing.writer.flush();
    var digest: [32]u8 = undefined;
    hashing.hasher.final(&digest);
    return .{ .hex = std.fmt.bytesToHex(digest, .lower), .bytes = bytes };
}

pub fn jsonAlloc(allocator: std.mem.Allocator, rows: []const Row, references: References, provenance: anytype) ![]u8 {
    return std.json.Stringify.valueAlloc(allocator, .{
        .schema = "vort.codec_encode_samples",
        .version = @as(u8, 1),
        .codec = "brotli",
        .round_count = round_count,
        .timing = .{
            .clock = "awake",
            .unit = "nanoseconds",
            .round_order = "vort_first_on_even_zero_based_rounds",
            .csv_statistic = "minimum",
            .median_statistic = "integer_floor",
            .mix = "sum_of_encoded_lengths_wrapping_target_usize",
            .vort_warmup = "one_untimed_encode_before_each_primary_vort_round",
            .reference_warmup = "none",
            .timed_work = "encoding_allocation_and_free",
            .metadata_outside_timing = true,
        },
        .reference_version = references.encoder_version,
        .reference_decoder_version = references.decoder_version,
        .references = references.libraries,
        .provenance = provenance,
        .rows = rows,
    }, .{ .whitespace = .indent_2 });
}

pub fn write(io: std.Io, allocator: std.mem.Allocator, path: []const u8, rows: []const Row, references: References, provenance: anytype) !void {
    const json = try jsonAlloc(allocator, rows, references, provenance);
    defer allocator.free(json);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = json });
}

/// Resolve existing files and nonexisting files' parents before timing. This
/// catches spelling aliases, symlinked parents and existing hard links without
/// creating, truncating or hashing either output file.
pub fn requireDistinctOutputs(io: std.Io, allocator: std.mem.Allocator, samples_path: ?[]const u8, csv_path: ?[]const u8) !void {
    const samples = samples_path orelse return;
    const csv = csv_path orelse return;
    if (std.mem.eql(u8, samples, csv)) return error.OutputPathCollision;
    const samples_canonical = try outputPathAlloc(io, allocator, samples);
    defer allocator.free(samples_canonical);
    const csv_canonical = try outputPathAlloc(io, allocator, csv);
    defer allocator.free(csv_canonical);
    if (std.mem.eql(u8, samples_canonical, csv_canonical)) return error.OutputPathCollision;
    const samples_stat = try optionalStat(io, samples);
    const csv_stat = try optionalStat(io, csv);
    if (samples_stat) |left| if (csv_stat) |right| {
        // File.Stat does not expose a device id. Matching inode and change
        // timestamp identifies hard links conservatively using its public API.
        if (left.inode != 0 and left.inode == right.inode and left.kind == right.kind and left.size == right.size and left.ctime.nanoseconds == right.ctime.nanoseconds)
            return error.OutputPathCollision;
    };
}

fn optionalStat(io: std.Io, path: []const u8) !?std.Io.File.Stat {
    return std.Io.Dir.cwd().statFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
}

fn outputPathAlloc(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![:0]u8 {
    if (std.Io.Dir.cwd().realPathFileAlloc(io, path, allocator)) |existing| return existing else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }
    const parent = std.fs.path.dirname(path) orelse ".";
    const canonical_parent = try std.Io.Dir.cwd().realPathFileAlloc(io, parent, allocator);
    defer allocator.free(canonical_parent);
    const normalized = try std.fs.path.resolve(allocator, &.{ canonical_parent, std.fs.path.basename(path) });
    defer allocator.free(normalized);
    return allocator.dupeZ(u8, normalized);
}

test "Brotli encode samples retain alternating raw rounds and first tied CSV minima" {
    const rounds = [_]Round{
        .{ .index = 0, .vort_first = true, .vort_ns = 90, .reference_ns = 40, .vort_mix = 11, .reference_mix = 12 },
        .{ .index = 1, .vort_first = false, .vort_ns = 20, .reference_ns = 80, .vort_mix = 21, .reference_mix = 22 },
        .{ .index = 2, .vort_first = true, .vort_ns = 20, .reference_ns = 30, .vort_mix = 31, .reference_mix = 32 },
        .{ .index = 3, .vort_first = false, .vort_ns = 70, .reference_ns = 50, .vort_mix = 41, .reference_mix = 42 },
        .{ .index = 4, .vort_first = true, .vort_ns = 60, .reference_ns = 30, .vort_mix = 51, .reference_mix = 52 },
    };
    const measured = Interleaved.fromRounds(rounds);
    try std.testing.expectEqual(@as(usize, 21), measured.vort.mix);
    try std.testing.expectEqual(@as(usize, 32), measured.reference.mix);
    try std.testing.expectEqualDeep(Summary{ .vort_min_ns = 20, .reference_min_ns = 30, .vort_median_ns = 60, .reference_median_ns = 40 }, measured.summary());
    try std.testing.expectEqualDeep(rounds, measured.rounds);
}

test "Brotli encode samples validate target sized wrapping wire mixes and round order" {
    var rounds: [round_count]Round = undefined;
    for (&rounds, 0..) |*round, index| round.* = .{ .index = index, .vort_first = index & 1 == 0, .vort_ns = 1, .reference_ns = 2, .vort_mix = @as(usize, std.math.maxInt(usize)) *% 3, .reference_mix = 7 *% @as(usize, 3) };
    try Interleaved.fromRounds(rounds).validate(3, std.math.maxInt(usize), 7);
    rounds[4].reference_mix += 1;
    try std.testing.expectError(error.SampleWireMismatch, Interleaved.fromRounds(rounds).validate(3, std.math.maxInt(usize), 7));
    rounds[4].reference_mix -= 1;
    rounds[1].vort_first = true;
    try std.testing.expectError(error.InvalidSampleOrder, Interleaved.fromRounds(rounds).validate(3, std.math.maxInt(usize), 7));
}

test "Brotli encode samples even median cannot overflow at maximum nanoseconds" {
    var values = [_]u64{ std.math.maxInt(u64), std.math.maxInt(u64) - 2 };
    try std.testing.expectEqual(std.math.maxInt(u64) - 1, median(&values));
}

test "Brotli encode samples require three reference files and leave SONAME identity unknown" {
    try std.testing.expectEqual(@as(?libbrotli.Paths, null), try (PathOptions{}).complete());
    try std.testing.expectError(error.IncompleteReferencePaths, (PathOptions{ .encoder = "encoder.so" }).complete());
    try std.testing.expectError(error.IncompleteReferencePaths, (PathOptions{ .encoder = "encoder.so", .common = "common.so" }).complete());
    const paths = (try (PathOptions{ .encoder = "encoder.so", .decoder = "decoder.so", .common = "common.so" }).complete()).?;
    try std.testing.expectEqualStrings("decoder.so", paths.decoder);
    const library = try identify(std.testing.io, std.testing.allocator, "brotli_encoder", null, "libbrotlienc.so.1", 1);
    try std.testing.expectEqual(@as(?[:0]u8, null), library.canonical_file_path);
    try std.testing.expectEqual(@as(?[64]u8, null), library.file_sha256);
    try std.testing.expectEqualStrings("unknown", library.identity_status);
    try std.testing.expect(!library.dependencies_verified);
}

test "Brotli encode samples JSON preserves raw rounds hashes escaped cases and unknown references" {
    var rounds: [round_count]Round = undefined;
    for (&rounds, 0..) |*round, index| round.* = .{ .index = index, .vort_first = index & 1 == 0, .vort_ns = 10 + index, .reference_ns = 20 + index, .vort_mix = 30, .reference_mix = 40 };
    const sample = Interleaved.fromRounds(rounds);
    const rows = [_]Row{.{
        .case = "case \"with\" newline\n",
        .input_bytes = 3,
        .input_sha256 = ("a" ** 64).*,
        .iterations = 2,
        .rounds = rounds,
        .summary = sample.summary(),
        .wires = .{ .vort_bytes = 15, .reference_bytes = 20, .vort_sha256 = ("b" ** 64).*, .reference_sha256 = ("c" ** 64).* },
        .settings = .{
            .vort_api = "reusable_legacy_fast",
            .planned_quality = null,
            .vort_mode = "generic",
            .vort_command_state_max_input_kib = 255,
            .vort_command_state_override_requested = null,
            .vort_default_window_bits = 16,
            .reference_quality = 3,
            .reference_quality_override_requested = null,
            .reference_case_quality = null,
            .auxiliary_ratio_extended_dictionary_probes_requested = 0,
            .auxiliary_ratio_extended_dictionary_probes_effective = 0,
            .auxiliary_ratio_adaptive_command_split = false,
            .auxiliary_ratio_adaptive_literal_split = false,
            .auxiliary_ratio_adaptive_distance_split = null,
            .auxiliary_ratio_distance_parameter_search = null,
        },
    }};
    const refs: References = .{
        .libraries = .{
            .{ .role = "brotli_encoder", .requested_path = null, .successful_open_argument = "libbrotlienc.so.1", .version = 1 },
            .{ .role = "brotli_decoder", .requested_path = null, .successful_open_argument = "libbrotlidec.so.1", .version = 1 },
            .{ .role = "brotli_common", .requested_path = null, .successful_open_argument = "libbrotlicommon.so.1", .version = null },
        },
        .encoder_version = 1,
        .decoder_version = 1,
    };
    const json = try jsonAlloc(std.testing.allocator, &rows, refs, .{ .command = "bench --samples-json out.json" });
    defer std.testing.allocator.free(json);
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
    const object = parsed.value.object;
    try std.testing.expectEqualStrings("vort.codec_encode_samples", object.get("schema").?.string);
    const row = object.get("rows").?.array.items[0].object;
    try std.testing.expectEqualStrings(rows[0].case, row.get("case").?.string);
    try std.testing.expectEqualStrings(&rows[0].input_sha256, row.get("input_sha256").?.string);
    try std.testing.expectEqual(@as(usize, 5), row.get("rounds").?.array.items.len);
    try std.testing.expectEqual(@as(i64, 12), row.get("summary").?.object.get("vort_median_ns").?.integer);
    try std.testing.expect(std.meta.activeTag(row.get("settings").?.object.get("planned_quality").?) == .null);
    const library = object.get("references").?.array.items[0].object;
    try std.testing.expect(std.meta.activeTag(library.get("canonical_file_path").?) == .null);
    try std.testing.expect(std.meta.activeTag(library.get("file_sha256").?) == .null);
    try std.testing.expect(std.meta.activeTag(library.get("loaded_identity").?) == .null);
    try std.testing.expect(!library.get("dependencies_verified").?.bool);
}

test "Brotli encode samples reject normalized output aliases without creating files" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    const root = try temp.dir.realPathFileAlloc(std.testing.io, ".", std.testing.allocator);
    defer std.testing.allocator.free(root);
    const first = try std.fs.path.join(std.testing.allocator, &.{ root, "samples.json" });
    defer std.testing.allocator.free(first);
    const alias = try std.fs.path.join(std.testing.allocator, &.{ root, ".", "samples.json" });
    defer std.testing.allocator.free(alias);
    try std.testing.expectError(error.OutputPathCollision, requireDistinctOutputs(std.testing.io, std.testing.allocator, first, alias));
    try temp.dir.createDir(std.testing.io, "nested", .default_dir);
    const parent_alias = try std.fs.path.join(std.testing.allocator, &.{ root, "nested", "..", "samples.json" });
    defer std.testing.allocator.free(parent_alias);
    try std.testing.expectError(error.OutputPathCollision, requireDistinctOutputs(std.testing.io, std.testing.allocator, first, parent_alias));
    const distinct = try std.fs.path.join(std.testing.allocator, &.{ root, "rows.csv" });
    defer std.testing.allocator.free(distinct);
    try requireDistinctOutputs(std.testing.io, std.testing.allocator, first, distinct);
    try std.testing.expectEqual(@as(?std.Io.File.Stat, null), try optionalStat(std.testing.io, first));
    try std.testing.expectEqual(@as(?std.Io.File.Stat, null), try optionalStat(std.testing.io, distinct));
}

test "Brotli encode samples reject existing hard linked outputs before truncation" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    try temp.dir.writeFile(std.testing.io, .{ .sub_path = "samples.json", .data = "preserved" });
    try std.Io.Dir.hardLink(temp.dir, "samples.json", temp.dir, "rows.csv", std.testing.io, .{});
    const first = try temp.dir.realPathFileAlloc(std.testing.io, "samples.json", std.testing.allocator);
    defer std.testing.allocator.free(first);
    const second = try temp.dir.realPathFileAlloc(std.testing.io, "rows.csv", std.testing.allocator);
    defer std.testing.allocator.free(second);
    try std.testing.expectError(error.OutputPathCollision, requireDistinctOutputs(std.testing.io, std.testing.allocator, first, second));
    const retained = try temp.dir.readFileAlloc(std.testing.io, "samples.json", std.testing.allocator, .limited(32));
    defer std.testing.allocator.free(retained);
    try std.testing.expectEqualStrings("preserved", retained);
}
