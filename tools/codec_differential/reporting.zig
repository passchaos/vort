//! Classification and bounded evidence storage; never consumes generator RNG.
const std = @import("std");
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const Counts = struct {
    external_valid_checks: u64 = 0,
    external_valid_ok: u64 = 0,
    vort_only_valid_contracts: u64 = 0,
    truncation_external_checks: u64 = 0,
    truncation_external_both_reject: u64 = 0,
    truncation_external_both_accept: u64 = 0,
    truncation_external_one_sided: u64 = 0,
    truncation_no_reference_checks: u64 = 0,
    truncation_no_reference_accept: u64 = 0,
    truncation_no_reference_reject: u64 = 0,
    mutation_external_checks: u64 = 0,
    mutation_external_both_accept: u64 = 0,
    mutation_external_both_reject: u64 = 0,
    mutation_external_reference_only: u64 = 0,
    mutation_external_vort_only: u64 = 0,
    mutation_external_output_mismatch: u64 = 0,
    mutation_no_reference_checks: u64 = 0,
    mutation_no_reference_reject: u64 = 0,
    mutation_no_reference_unchanged: u64 = 0,
    mutation_no_reference_content_changed_same_length: u64 = 0,
    mutation_no_reference_length_changed: u64 = 0,
};

pub const Stats = struct {
    wires: u64 = 0,
    variant_wires: u64 = 0,
    vort_roundtrip_ok: u64 = 0,
    exact_size_ok: u64 = 0,
    reference_ok: u64 = 0,
    reference_rejected_valid: u64 = 0,
    truncation_cuts: u64 = 0,
    truncation_both_rejected: u64 = 0,
    truncation_agreed: u64 = 0,
    mutations_xor: u64 = 0,
    mutations_bitflip: u64 = 0,
    mutations_overwrite: u64 = 0,
    mutations_double_overwrite: u64 = 0,
    mutations_insert: u64 = 0,
    mutations_delete: u64 = 0,
    mutation_rejected: u64 = 0,
    one_sided_divergence: u64 = 0,
    by_codec: [5]Counts = @splat(.{}),

    pub fn classified(self: Stats) Counts {
        var total: Counts = .{};
        for (self.by_codec) |row| inline for (std.meta.fields(Counts)) |field| {
            @field(total, field.name) += @field(row, field.name);
        };
        return total;
    }
};

pub const Direction = enum { reference_only, vort_only, output_mismatch, no_reference_content_changed, no_reference_length_changed };
pub const Bounds = struct {
    max_samples: usize = 32,
    max_samples_per_codec_direction: usize = 2,
    max_total_bytes: usize = 8 * 1024 * 1024,
    max_sample_blob_bytes: usize = 1024 * 1024,
    max_manifest_bytes: usize = 512 * 1024,
};
pub const ArtifactCounts = struct {
    eligible: u64 = 0,
    saved: usize = 0,
    blob_files: usize = 0,
    blob_bytes: usize = 0,
    skipped_disabled: u64 = 0,
    skipped_direction_quota: u64 = 0,
    skipped_total_quota: u64 = 0,
    skipped_source_stratum: u64 = 0,
    skipped_sample_bytes: u64 = 0,
    skipped_total_bytes: u64 = 0,
};
pub const Info = struct {
    codec_index: usize,
    codec: []const u8,
    pattern: []const u8,
    variant: []const u8,
    level: u4,
};
pub const Flags = struct {
    brotli_large_window: bool,
    zstd_stream_reference: bool,
    gzip_multi_member: bool,
    brotli_shared_dictionary: bool,
    zstd_magicless: bool,
    brotli_serialized_dictionary: bool,

    fn from(case: anytype) Flags {
        return .{
            .brotli_large_window = case.brotli_large_window,
            .zstd_stream_reference = case.zstd_stream_reference,
            .gzip_multi_member = case.gzip_multi_member,
            .brotli_shared_dictionary = case.brotli_shared_dictionary,
            .zstd_magicless = case.zstd_magicless,
            .brotli_serialized_dictionary = case.brotli_serialized_dictionary,
        };
    }
};
pub const File = struct { path: []const u8, bytes: usize, sha256: []const u8 };
pub const ReferenceObservation = struct {
    output_capacity: ?usize = null,
    input_consumed: ?usize = null,
    input_remaining: ?usize = null,
    result_code: ?i32 = null,
};
pub const Sample = struct {
    info: Info,
    direction: Direction,
    operator: []const u8,
    wire_ordinal: u64,
    mutation_ordinal: u64,
    reference_available: bool,
    vort_accepted: bool,
    reference_accepted: bool,
    reference_output_capacity: ?usize = null,
    reference_full_input_policy: []const u8 = "not-recorded",
    reference_observation: ReferenceObservation = .{},
    vort_decoded_bytes: ?usize = null,
    reference_decoded_bytes: ?usize = null,
    first_difference: usize,
    flags: Flags,
    original_wire: File,
    mutated_wire: File,
    source: File,
    dictionary_raw: ?File = null,
    dictionary_standard: ?File = null,
    dictionary_brotli_serialized: ?File = null,
    vort_output: ?File = null,
    reference_output: ?File = null,
};
pub const References = struct { zlib: []const u8, zstd: []const u8, brotli_decoder_version_encoded: u32 };
pub const Manifest = struct {
    schema: []const u8 = "vort.codec-differential.classification.v1",
    seed: u64,
    deep: bool,
    only: []const u8,
    reference_versions: References,
    codec_order: []const []const u8 = &.{ "raw", "zlib", "gzip", "zstd", "br" },
    stats: Stats,
    classified: Counts,
    generated_wire_digest_sha256: []const u8,
    mutation_sequence_digest_sha256: []const u8,
    bounds: Bounds,
    artifacts: ArtifactCounts,
    samples: []const Sample,
    counter_scope: []const u8 = "Legacy reference_ok includes Vort-only contracts. External counts require an actual reference decoder call. Mutation one-sided acceptance is a protocol observation, not proof of incompatible valid wire.",
    reference_capacity_scope: []const u8 = "Reference destination request is min(max(source.len *% 4,4096),1048576)+1. Vort one-shot routes are mostly unbounded. zlib inflate single-stream routes require Z_STREAM_END but do not require avail_in==0; consumed/remaining observations never change that verdict.",
    artifact_scope: []const u8 = "First empty-source and first non-empty-source representative per codec/direction in unchanged traversal order. All accepting outputs are complete. Budget reserves max_manifest_bytes from max_total_bytes; no blob is truncated.",
};

pub fn hasReference(case: anytype) bool {
    return !case.brotli_shared_dictionary and !case.brotli_serialized_dictionary and !case.zstd_magicless;
}

pub fn referenceCapacity(source_len: usize) usize {
    return @min(@max(source_len *% 4, 4096), 1 << 20) + 1;
}

fn referencePolicy(info: Info, case: anytype) []const u8 {
    if (!hasReference(case)) return "not-called";
    if (std.mem.eql(u8, info.codec, "raw") or std.mem.eql(u8, info.codec, "zlib") or (std.mem.eql(u8, info.codec, "gzip") and !case.gzip_multi_member)) return "zlib-inflate: Z_STREAM_END required; remaining input allowed";
    if (case.gzip_multi_member) return "gzip-per-member-inflate: full input required";
    if (case.zstd_stream_reference) return "ZSTD_decompressStream: full input and final zero hint required";
    if (case.brotli_large_window) return "BrotliDecoderDecompressStream: full input required; Large Window enabled";
    return "one-shot-library-policy: caller has no consumed-input check";
}

pub const Reporter = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    directory: ?[]const u8,
    bounds: Bounds = .{},
    counts: ArtifactCounts = .{},
    samples: std.ArrayList(Sample) = .empty,
    quotas: [5][5]usize = @splat(@splat(0)),
    source_strata: [5][5][2]bool = @splat(@splat(@splat(false))),
    wire_hash: Sha256 = Sha256.init(.{}),
    mutation_hash: Sha256 = Sha256.init(.{}),

    pub fn init(a: std.mem.Allocator, io: std.Io, directory: ?[]const u8) !Reporter {
        // An existing directory is refused, so a bounded run cannot overwrite
        // earlier evidence or inherit uncounted files.
        if (directory) |path| try std.Io.Dir.cwd().createDir(io, path, .default_dir);
        return .{ .allocator = a, .io = io, .directory = directory };
    }

    pub fn deinit(self: *Reporter) void {
        for (self.samples.items) |sample| inline for (.{ "original_wire", "mutated_wire", "source", "dictionary_raw", "dictionary_standard", "dictionary_brotli_serialized", "vort_output", "reference_output" }) |field| {
            const value = @field(sample, field);
            if (comptime @TypeOf(value) == File) self.freeFile(value) else if (value) |file| self.freeFile(file);
        };
        self.samples.deinit(self.allocator);
    }

    fn freeFile(self: *Reporter, file: File) void {
        self.allocator.free(file.path);
        self.allocator.free(file.sha256);
    }

    fn hashBytes(hash: *Sha256, bytes: []const u8) void {
        var length: [8]u8 = undefined;
        std.mem.writeInt(u64, &length, @intCast(bytes.len), .little);
        hash.update(&length);
        hash.update(bytes);
    }

    fn hashInfo(hash: *Sha256, info: Info) void {
        hashBytes(hash, info.codec);
        hashBytes(hash, info.pattern);
        hashBytes(hash, info.variant);
        hash.update(&.{info.level});
    }

    pub fn observeWire(self: *Reporter, info: Info, case: anytype) void {
        hashInfo(&self.wire_hash, info);
        hashBytes(&self.wire_hash, case.wire);
        hashBytes(&self.wire_hash, case.source);
        inline for (.{ "dictionary", "standard_dictionary_bytes", "serialized_dictionary_bytes" }) |field| {
            const bytes = @field(case, field);
            self.wire_hash.update(&.{@intFromBool(bytes != null)});
            if (bytes) |body| hashBytes(&self.wire_hash, body);
        }
        const flags = Flags.from(case);
        inline for (std.meta.fields(Flags)) |field| self.wire_hash.update(&.{@intFromBool(@field(flags, field.name))});
    }

    pub fn mutation(self: *Reporter, stats: *Stats, info: Info, case: anytype, mutated: []const u8, operator: []const u8, vort_output: ?[]const u8, reference_output: ?[]const u8, observation: ReferenceObservation) !void {
        hashInfo(&self.mutation_hash, info);
        hashBytes(&self.mutation_hash, operator);
        hashBytes(&self.mutation_hash, mutated);
        const row = &stats.by_codec[info.codec_index];
        var direction: ?Direction = null;
        if (hasReference(case)) {
            row.mutation_external_checks += 1;
            if (vort_output != null and reference_output != null) {
                row.mutation_external_both_accept += 1;
                if (!std.mem.eql(u8, vort_output.?, reference_output.?)) {
                    row.mutation_external_output_mismatch += 1;
                    direction = .output_mismatch;
                }
            } else if (vort_output == null and reference_output == null) {
                row.mutation_external_both_reject += 1;
            } else if (reference_output != null) {
                row.mutation_external_reference_only += 1;
                direction = .reference_only;
            } else {
                row.mutation_external_vort_only += 1;
                direction = .vort_only;
            }
        } else {
            row.mutation_no_reference_checks += 1;
            if (vort_output) |decoded| {
                if (decoded.len != case.source.len) {
                    row.mutation_no_reference_length_changed += 1;
                    direction = .no_reference_length_changed;
                } else if (!std.mem.eql(u8, decoded, case.source)) {
                    row.mutation_no_reference_content_changed_same_length += 1;
                    direction = .no_reference_content_changed;
                } else row.mutation_no_reference_unchanged += 1;
            } else row.mutation_no_reference_reject += 1;
        }
        if (direction) |selected| try self.capture(stats, info, case, mutated, operator, selected, vort_output, reference_output, observation);
    }

    fn capture(self: *Reporter, stats: *const Stats, info: Info, case: anytype, mutated: []const u8, operator: []const u8, direction: Direction, vort_output: ?[]const u8, reference_output: ?[]const u8, observation: ReferenceObservation) !void {
        self.counts.eligible += 1;
        if (self.directory == null) {
            self.counts.skipped_disabled += 1;
            return;
        }
        const quota = &self.quotas[info.codec_index][@intFromEnum(direction)];
        const stratum = &self.source_strata[info.codec_index][@intFromEnum(direction)][@intFromBool(case.source.len != 0)];
        if (stratum.*) {
            self.counts.skipped_source_stratum += 1;
            return;
        }
        if (quota.* >= self.bounds.max_samples_per_codec_direction) {
            self.counts.skipped_direction_quota += 1;
            return;
        }
        if (self.samples.items.len >= self.bounds.max_samples) {
            self.counts.skipped_total_quota += 1;
            return;
        }
        var bytes: usize = case.wire.len + mutated.len + case.source.len;
        inline for (.{ "dictionary", "standard_dictionary_bytes", "serialized_dictionary_bytes" }) |field| if (@field(case, field)) |body| {
            bytes = std.math.add(usize, bytes, body.len) catch return error.ArtifactSizeOverflow;
        };
        if (vort_output) |body| bytes = std.math.add(usize, bytes, body.len) catch return error.ArtifactSizeOverflow;
        if (reference_output) |body| bytes = std.math.add(usize, bytes, body.len) catch return error.ArtifactSizeOverflow;
        if (bytes > self.bounds.max_sample_blob_bytes) {
            self.counts.skipped_sample_bytes += 1;
            return;
        }
        if (bytes > self.bounds.max_total_bytes - self.bounds.max_manifest_bytes - self.counts.blob_bytes) {
            self.counts.skipped_total_bytes += 1;
            return;
        }
        const sample_id = self.samples.items.len;
        var first: usize = 0;
        while (first < @min(case.wire.len, mutated.len) and case.wire[first] == mutated[first]) : (first += 1) {}
        var sample: Sample = .{
            .info = info,
            .direction = direction,
            .operator = operator,
            .wire_ordinal = stats.wires,
            .mutation_ordinal = stats.mutations_xor + stats.mutations_bitflip + stats.mutations_overwrite + stats.mutations_double_overwrite + stats.mutations_insert + stats.mutations_delete,
            .reference_available = hasReference(case),
            .vort_accepted = vort_output != null,
            .reference_accepted = reference_output != null,
            .reference_output_capacity = if (hasReference(case)) referenceCapacity(case.source.len) else null,
            .reference_full_input_policy = referencePolicy(info, case),
            .reference_observation = if (hasReference(case)) observation else .{},
            .vort_decoded_bytes = if (vort_output) |body| body.len else null,
            .reference_decoded_bytes = if (reference_output) |body| body.len else null,
            .first_difference = first,
            .flags = Flags.from(case),
            .original_wire = try self.writeBlob(sample_id, "original-wire", case.wire),
            .mutated_wire = try self.writeBlob(sample_id, "mutated-wire", mutated),
            .source = try self.writeBlob(sample_id, "source", case.source),
        };
        if (case.dictionary) |body| sample.dictionary_raw = try self.writeBlob(sample_id, "dictionary-raw", body);
        if (case.standard_dictionary_bytes) |body| sample.dictionary_standard = try self.writeBlob(sample_id, "dictionary-standard", body);
        if (case.serialized_dictionary_bytes) |body| sample.dictionary_brotli_serialized = try self.writeBlob(sample_id, "dictionary-brotli-serialized", body);
        if (vort_output) |body| sample.vort_output = try self.writeBlob(sample_id, "vort-output", body);
        if (reference_output) |body| sample.reference_output = try self.writeBlob(sample_id, "reference-output", body);
        try self.samples.append(self.allocator, sample);
        quota.* += 1;
        stratum.* = true;
        self.counts.saved += 1;
    }

    fn writeBlob(self: *Reporter, sample_id: usize, role: []const u8, bytes: []const u8) !File {
        const name = try std.fmt.allocPrint(self.allocator, "sample-{d:0>3}-{s}.bin", .{ sample_id, role });
        errdefer self.allocator.free(name);
        const path = try std.fs.path.join(self.allocator, &.{ self.directory.?, name });
        defer self.allocator.free(path);
        try std.Io.Dir.cwd().writeFile(self.io, .{ .sub_path = path, .data = bytes });
        var hash: [32]u8 = undefined;
        Sha256.hash(bytes, &hash, .{});
        const hex = std.fmt.bytesToHex(hash, .lower);
        self.counts.blob_files += 1;
        self.counts.blob_bytes += bytes.len;
        return .{ .path = name, .bytes = bytes.len, .sha256 = try self.allocator.dupe(u8, &hex) };
    }

    pub fn finish(self: *Reporter, writer: *std.Io.Writer, stats: Stats, seed: u64, deep: bool, only: []const u8, references: References) !void {
        var wires = self.wire_hash;
        var mutations = self.mutation_hash;
        var wire_digest: [32]u8 = undefined;
        var mutation_digest: [32]u8 = undefined;
        wires.final(&wire_digest);
        mutations.final(&mutation_digest);
        const wire_hex = std.fmt.bytesToHex(wire_digest, .lower);
        const mutation_hex = std.fmt.bytesToHex(mutation_digest, .lower);
        const manifest: Manifest = .{ .seed = seed, .deep = deep, .only = only, .reference_versions = references, .stats = stats, .classified = stats.classified(), .generated_wire_digest_sha256 = &wire_hex, .mutation_sequence_digest_sha256 = &mutation_hex, .bounds = self.bounds, .artifacts = self.counts, .samples = self.samples.items };
        const body = try std.json.Stringify.valueAlloc(self.allocator, manifest, .{});
        defer self.allocator.free(body);
        try printLegacy(writer, stats, seed, deep, only);
        try writer.print("  actual external-reference valid checks={d} ok={d}; Vort-only contracts={d}\nclassification_json: {s}\n", .{ manifest.classified.external_valid_checks, manifest.classified.external_valid_ok, manifest.classified.vort_only_valid_contracts, body });
        if (self.directory) |directory| {
            if (body.len > self.bounds.max_manifest_bytes) return error.ArtifactManifestLimitExceeded;
            const path = try std.fs.path.join(self.allocator, &.{ directory, "manifest.json" });
            defer self.allocator.free(path);
            try std.Io.Dir.cwd().writeFile(self.io, .{ .sub_path = path, .data = body });
        }
    }
};

fn printLegacy(stdout: *std.Io.Writer, stats: Stats, seed: u64, deep: bool, only: []const u8) !void {
    try stdout.print(
        \\codec differential fuzz: seed={d} deep={} only={s}
        \\  valid wires={d} (variants={d}) vort_roundtrip={d} exact_size={d} reference_interop={d}
        \\  truncation cuts={d} (both_rejected={d} agreed_accept={d})
        \\  mutations xor={d} bitflip={d} overwrite={d} double-overwrite={d} insert={d} delete={d} (rejected={d} one_sided_divergence={d})
        \\
    , .{ seed, deep, only, stats.wires, stats.variant_wires, stats.vort_roundtrip_ok, stats.exact_size_ok, stats.reference_ok, stats.truncation_cuts, stats.truncation_both_rejected, stats.truncation_agreed, stats.mutations_xor, stats.mutations_bitflip, stats.mutations_overwrite, stats.mutations_double_overwrite, stats.mutations_insert, stats.mutations_delete, stats.mutation_rejected, stats.one_sided_divergence });
}

fn loadFile(a: std.mem.Allocator, io: std.Io, directory: []const u8, file: File, max_bytes: usize) ![]u8 {
    if (file.bytes > max_bytes or std.mem.indexOfAny(u8, file.path, "/\\") != null or std.mem.indexOf(u8, file.path, "..") != null) return error.InvalidArtifactPathOrSize;
    const path = try std.fs.path.join(a, &.{ directory, file.path });
    defer a.free(path);
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, a, .limited(max_bytes));
    errdefer a.free(bytes);
    var hash: [32]u8 = undefined;
    Sha256.hash(bytes, &hash, .{});
    const hex = std.fmt.bytesToHex(hash, .lower);
    if (bytes.len != file.bytes or !std.mem.eql(u8, &hex, file.sha256)) return error.ArtifactDigestMismatch;
    return bytes;
}

fn loadOptional(a: std.mem.Allocator, io: std.Io, directory: []const u8, file: ?File, max_bytes: usize) !?[]u8 {
    return if (file) |value| try loadFile(a, io, directory, value, max_bytes) else null;
}

fn verifyOutput(a: std.mem.Allocator, io: std.Io, directory: []const u8, file: ?File, output: ?[]const u8, max_bytes: usize) !void {
    if ((file != null) != (output != null)) return error.ReplayAcceptanceChanged;
    if (file) |expected| {
        const bytes = try loadFile(a, io, directory, expected, max_bytes);
        defer a.free(bytes);
        if (!std.mem.eql(u8, bytes, output.?)) return error.ReplayOutputChanged;
    }
}

/// Replay exact saved wires through the unchanged Vort/reference routes. All
/// files and complete accepting outputs are checked against their SHA first.
pub fn replayAll(a: std.mem.Allocator, io: std.Io, directory: []const u8, harness: anytype, comptime Codec: type, comptime WireCase: type) !void {
    const path = try std.fs.path.join(a, &.{ directory, "manifest.json" });
    defer a.free(path);
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, a, .limited(512 * 1024));
    defer a.free(bytes);
    const parsed = try std.json.parseFromSlice(Manifest, a, bytes, .{});
    defer parsed.deinit();
    const manifest = parsed.value;
    if (!std.mem.eql(u8, manifest.schema, "vort.codec-differential.classification.v1") or manifest.samples.len > 32) return error.InvalidArtifactManifest;
    for (manifest.samples) |sample| {
        const codec = std.meta.stringToEnum(Codec, sample.info.codec) orelse return error.UnknownArtifactCodec;
        const original = try loadFile(a, io, directory, sample.original_wire, 1024 * 1024);
        defer a.free(original);
        const mutated = try loadFile(a, io, directory, sample.mutated_wire, 1024 * 1024);
        defer a.free(mutated);
        const source = try loadFile(a, io, directory, sample.source, 1024 * 1024);
        defer a.free(source);
        const raw = try loadOptional(a, io, directory, sample.dictionary_raw, 1024 * 1024);
        defer if (raw) |body| a.free(body);
        const standard = try loadOptional(a, io, directory, sample.dictionary_standard, 1024 * 1024);
        defer if (standard) |body| a.free(body);
        const serialized = try loadOptional(a, io, directory, sample.dictionary_brotli_serialized, 1024 * 1024);
        defer if (serialized) |body| a.free(body);
        const case: WireCase = .{
            .label = sample.info.variant,
            .wire = mutated,
            .source = source,
            .dictionary = raw,
            .standard_dictionary_bytes = standard,
            .serialized_dictionary_bytes = serialized,
            .brotli_large_window = sample.flags.brotli_large_window,
            .zstd_stream_reference = sample.flags.zstd_stream_reference,
            .gzip_multi_member = sample.flags.gzip_multi_member,
            .brotli_shared_dictionary = sample.flags.brotli_shared_dictionary,
            .zstd_magicless = sample.flags.zstd_magicless,
            .brotli_serialized_dictionary = sample.flags.brotli_serialized_dictionary,
        };
        if (hasReference(case) != sample.reference_available or sample.vort_accepted != (sample.vort_output != null) or sample.reference_accepted != (sample.reference_output != null)) return error.InvalidArtifactManifest;
        const vort_output = harness.vortDecode(codec, case);
        defer if (vort_output) |body| a.free(body);
        const reference_output = if (sample.reference_available) harness.referenceDecode(codec, case, source.len) else null;
        defer if (reference_output) |body| a.free(body);
        try verifyOutput(a, io, directory, sample.vort_output, vort_output, 1024 * 1024);
        try verifyOutput(a, io, directory, sample.reference_output, reference_output, 1024 * 1024);
    }
    var buffer: [512]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(io, &buffer);
    try writer.interface.print("replayed_samples={d} original/mutated/source/dictionaries/output SHA and complete acceptance/output verified\n", .{manifest.samples.len});
    try writer.interface.flush();
}
