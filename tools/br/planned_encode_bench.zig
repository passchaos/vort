const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");
const benchmark_provenance = @import("benchmark_provenance");
const q8_records_fixture = @import("q8_records_fixture.zig");
const encode_samples = @import("encode_samples.zig");

const json_payload = "{\"kind\":\"event\",\"active\":true,\"values\":[1,2,3,5,8,13]}\n" ** 48;
const source_payload = "pub fn update(state: *State, value: u32) void { state.total += value; state.count += 1; }\n" ** 40;
const log_payload = "2026-08-21T02:00:00Z level=info service=vort request=compress status=ok bytes=4096\n" ** 40;
const dictionary_payload = "Information about compression performance and dictionary support.";
const mixed_payload = "abcdefghabcdefgh information follows abcdefghabcdefgh";
const uppercase_payload = "INFORMATION";
const incompressible_payload = "qzxwvbnm1234567890QZXWVBNM!@#$%^&*";
const Case = struct {
    name: []const u8,
    payload: []const u8,
    quality: ?c_int = null,
    owned: bool = false,

    fn deinit(case: Case, allocator: std.mem.Allocator) void {
        if (case.owned) {
            allocator.free(case.name);
            allocator.free(case.payload);
        }
    }
};
const Options = struct {
    iterations: usize = 1000,
    csv_path: ?[]const u8 = null,
    samples_json_path: ?[]const u8 = null,
    reference_paths: encode_samples.PathOptions = .{},
    case_filter: ?[]const u8 = null,
    quality_override: ?c_int = null,
    planned_quality: ?u4 = null,
    planned_mode: vort.BrotliPlannedMode = .generic,
    extended_dictionary_probes: u16 = 0,
    adaptive_command_split: bool = false,
    adaptive_literal_split: bool = false,
    adaptive_distance_split: ?bool = null,
    distance_parameter_search: ?bool = null,
    command_state_max_input_kib: ?u8 = null,
    path_limit: usize = 128 * 1024,
    paths: std.ArrayList([]const u8) = .empty,

    fn deinit(options: *Options, allocator: std.mem.Allocator) void {
        for (options.paths.items) |path| allocator.free(path);
        options.paths.deinit(allocator);
    }
};
const Sample = encode_samples.Sample;

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var options = try parseOptions(init.gpa, &args);
    defer options.deinit(init.gpa);
    try encode_samples.requireDistinctOutputs(init.io, init.gpa, options.samples_json_path, options.csv_path);
    const requested_paths = try options.reference_paths.complete();
    const resolved_paths: ?encode_samples.ResolvedPaths = if (requested_paths) |paths|
        try encode_samples.ResolvedPaths.init(init.io, init.gpa, paths)
    else
        null;
    defer if (resolved_paths) |paths| paths.deinit(init.gpa);
    const provenance = try benchmark_provenance.capture(
        init.io,
        init.gpa,
        init.minimal.args,
        "single",
    );
    defer provenance.deinit(init.gpa);
    var reference = if (resolved_paths) |paths|
        try libbrotli.Runtime.openPaths(paths.paths())
    else
        try libbrotli.Runtime.open();
    defer reference.deinit();
    const reference_metadata: ?encode_samples.References = if (options.samples_json_path != null)
        try encode_samples.References.capture(init.io, init.gpa, reference, requested_paths)
    else
        null;
    defer if (reference_metadata) |metadata| metadata.deinit(init.gpa);
    var sample_rows: std.ArrayList(encode_samples.Row) = .empty;
    defer sample_rows.deinit(init.gpa);
    var cases: std.ArrayList(Case) = .empty;
    var records_q8: [q8_records_fixture.input_len]u8 = undefined;
    defer {
        for (cases.items) |case| case.deinit(init.gpa);
        cases.deinit(init.gpa);
    }
    if (options.paths.items.len == 0) {
        q8_records_fixture.fill(&records_q8);
        try cases.append(init.gpa, .{ .name = "json", .payload = json_payload });
        try cases.append(init.gpa, .{ .name = "source", .payload = source_payload });
        try cases.append(init.gpa, .{ .name = "log", .payload = log_payload });
        try cases.append(init.gpa, .{ .name = "dictionary", .payload = dictionary_payload });
        try cases.append(init.gpa, .{ .name = "mixed", .payload = mixed_payload });
        try cases.append(init.gpa, .{ .name = "uppercase", .payload = uppercase_payload });
        try cases.append(init.gpa, .{ .name = "incompressible", .payload = incompressible_payload });
        try cases.append(init.gpa, .{ .name = "records_q8", .payload = &records_q8, .quality = 8 });
        const source_file = try readFilePrefixAlloc(
            init.io,
            init.gpa,
            "src/br.zig",
            32 * 1024,
        );
        errdefer init.gpa.free(source_file);
        const source_name = try init.gpa.dupe(u8, "source32k");
        errdefer init.gpa.free(source_name);
        try cases.append(init.gpa, .{ .name = source_name, .payload = source_file, .quality = 8, .owned = true });
    } else {
        for (options.paths.items, 0..) |path, index| {
            const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
            defer file.close(init.io);
            const stat = try file.stat(init.io);
            const read_len: usize = @intCast(@min(stat.size, options.path_limit));
            if (read_len == 0) continue;
            const payload = try init.gpa.alloc(u8, read_len);
            errdefer init.gpa.free(payload);
            var reader_buffer: [4096]u8 = undefined;
            var reader = file.reader(init.io, &reader_buffer);
            if (try reader.interface.readSliceShort(payload) != read_len) return error.InputTooSmall;
            const name = try caseNameForPath(init.gpa, path, index);
            errdefer init.gpa.free(name);
            try cases.append(init.gpa, .{ .name = name, .payload = payload, .owned = true });
        }
    }
    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.print("case,reference_version,quality,planned_quality,planned_mode,input_bytes,input_sha256,extended_dictionary_probes,vort_bytes,lazy_bytes,ratio_bytes,ratio_dictionary_copies,ratio_dictionary_bytes,reference_bytes,iterations,vort_ns,lazy_ns,ratio_ns,reference_ns,vort_mib_s,lazy_mib_s,ratio_mib_s,reference_mib_s,vort_over_reference,lazy_over_reference,ratio_over_reference,vort_size_over_reference,lazy_size_over_reference,ratio_size_over_reference,checksum,{s}\n", .{benchmark_provenance.csv_columns});
    var selected_cases: usize = 0;
    for (cases.items) |case| {
        if (options.case_filter) |filter|
            if (!std.mem.eql(u8, filter, case.name)) continue;
        selected_cases += 1;
        const quality = options.quality_override orelse case.quality orelse 3;
        const vort_encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, case.payload, .{
            .level = .fast,
            .quality = options.planned_quality,
            .mode = options.planned_mode,
            .command_state_max_input_kib = options.command_state_max_input_kib orelse std.math.maxInt(u8),
        });
        defer init.gpa.free(vort_encoded);
        const reference_encoded = try reference.encodeAlloc(init.gpa, case.payload, quality);
        defer init.gpa.free(reference_encoded);
        const lazy_encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, case.payload, .{ .level = .balanced });
        defer init.gpa.free(lazy_encoded);
        const extended_dictionary_probes: u16 = if (case.payload.len <= 4096) options.extended_dictionary_probes else 0;
        const ratio_encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, case.payload, .{
            .level = .ratio,
            .extended_dictionary_probes = extended_dictionary_probes,
            .adaptive_command_split = options.adaptive_command_split,
            .adaptive_literal_split = options.adaptive_literal_split,
            .adaptive_distance_split = options.adaptive_distance_split,
            .distance_parameter_search = options.distance_parameter_search,
        });
        defer init.gpa.free(ratio_encoded);
        // Record semantic dictionary use in addition to the encoded size so the
        // benchmark gate catches regressions that silently fall back to literals.
        const ratio_summary = try vort.brSummarizeStreamAlloc(init.gpa, ratio_encoded);
        const decoded = try init.gpa.alloc(u8, case.payload.len);
        defer init.gpa.free(decoded);
        for ([_][]const u8{ vort_encoded, lazy_encoded, ratio_encoded }) |encoded| {
            try reference.decode(encoded, decoded);
            if (!std.mem.eql(u8, case.payload, decoded)) return error.SizeMismatch;
        }
        const input_sha256 = benchmark_provenance.sha256Hex(case.payload);
        // These are the already constructed, validated wires. Recording their
        // identities never hashes a result inside the measured encode loop.
        const recorded_wires: ?encode_samples.Wires = if (options.samples_json_path != null) .{
            .vort_bytes = vort_encoded.len,
            .reference_bytes = reference_encoded.len,
            .vort_sha256 = benchmark_provenance.sha256Hex(vort_encoded),
            .reference_sha256 = benchmark_provenance.sha256Hex(reference_encoded),
        } else null;
        const samples = try measureInterleaved(init.io, init.gpa, reference, case.payload, options, quality);
        const lazy_sample = try measurePlanned(init.io, init.gpa, case.payload, options.iterations, .balanced, 0, false, false, null, null);
        const ratio_sample = try measurePlanned(init.io, init.gpa, case.payload, options.iterations, .ratio, extended_dictionary_probes, options.adaptive_command_split, options.adaptive_literal_split, options.adaptive_distance_split, options.distance_parameter_search);
        const total_bytes = case.payload.len * options.iterations;
        const vort_rate = mibPerSecond(total_bytes, samples.vort.ns);
        const reference_rate = mibPerSecond(total_bytes, samples.reference.ns);
        const lazy_rate = mibPerSecond(total_bytes, lazy_sample.ns);
        const ratio_rate = mibPerSecond(total_bytes, ratio_sample.ns);
        if (recorded_wires) |wires| {
            try samples.validate(options.iterations, wires.vort_bytes, wires.reference_bytes);
            const reference_settings = libbrotli.Runtime.OneShotOptions{ .quality = quality };
            try sample_rows.append(init.gpa, .{
                .case = case.name,
                .input_bytes = case.payload.len,
                .input_sha256 = input_sha256,
                .iterations = options.iterations,
                .rounds = samples.rounds,
                .summary = samples.summary(),
                .wires = wires,
                .settings = .{
                    .vort_api = if (options.planned_quality == null) "reusable_legacy_fast" else "one_shot_quality_preset",
                    .planned_quality = options.planned_quality,
                    .vort_mode = @tagName(options.planned_mode),
                    .vort_command_state_max_input_kib = options.command_state_max_input_kib orelse vort.brotliCommandStateDefaultMaxInputKiB,
                    .vort_command_state_override_requested = options.command_state_max_input_kib,
                    .vort_default_window_bits = vort.brotliDefaultWindowBits,
                    .reference_quality = quality,
                    .reference_quality_override_requested = options.quality_override,
                    .reference_case_quality = case.quality,
                    .reference_lgwin = reference_settings.lgwin,
                    .reference_mode = reference_settings.mode,
                    .auxiliary_ratio_extended_dictionary_probes_requested = options.extended_dictionary_probes,
                    .auxiliary_ratio_extended_dictionary_probes_effective = extended_dictionary_probes,
                    .auxiliary_ratio_adaptive_command_split = options.adaptive_command_split,
                    .auxiliary_ratio_adaptive_literal_split = options.adaptive_literal_split,
                    .auxiliary_ratio_adaptive_distance_split = options.adaptive_distance_split,
                    .auxiliary_ratio_distance_parameter_search = options.distance_parameter_search,
                },
            });
        }
        try csv.writer.print("{s},{x},{d},", .{
            case.name,
            reference.version(),
            quality,
        });
        if (options.planned_quality) |planned_quality|
            try csv.writer.print("{d}", .{planned_quality});
        try csv.writer.print(",{s},{d},{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.2},{d:.2},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d}", .{
            @tagName(options.planned_mode),
            case.payload.len,
            &input_sha256,
            extended_dictionary_probes,
            vort_encoded.len,
            lazy_encoded.len,
            ratio_encoded.len,
            ratio_summary.static_dictionary_copy_count,
            ratio_summary.static_dictionary_bytes,
            reference_encoded.len,
            options.iterations,
            samples.vort.ns,
            lazy_sample.ns,
            ratio_sample.ns,
            samples.reference.ns,
            vort_rate,
            lazy_rate,
            ratio_rate,
            reference_rate,
            vort_rate / reference_rate,
            lazy_rate / reference_rate,
            ratio_rate / reference_rate,
            @as(f64, @floatFromInt(vort_encoded.len)) / @as(f64, @floatFromInt(reference_encoded.len)),
            @as(f64, @floatFromInt(lazy_encoded.len)) / @as(f64, @floatFromInt(reference_encoded.len)),
            @as(f64, @floatFromInt(ratio_encoded.len)) / @as(f64, @floatFromInt(reference_encoded.len)),
            samples.vort.mix +% lazy_sample.mix +% ratio_sample.mix +% samples.reference.mix,
        });
        try provenance.writeCsvFields(&csv.writer);
        try csv.writer.writeByte('\n');
    }
    if (selected_cases == 0) return error.InvalidBlockPlan;
    if (options.samples_json_path) |path|
        try encode_samples.write(init.io, init.gpa, path, sample_rows.items, reference_metadata.?, provenance);
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn measurePlanned(io: std.Io, allocator: std.mem.Allocator, payload: []const u8, iterations: usize, level: vort.BrotliPlannedCompressionLevel, extended_dictionary_probes: u16, adaptive_command_split: bool, adaptive_literal_split: bool, adaptive_distance_split: ?bool, distance_parameter_search: ?bool) !Sample {
    var best = Sample{ .ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            const encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(allocator, payload, .{
                .level = level,
                .extended_dictionary_probes = extended_dictionary_probes,
                .adaptive_command_split = adaptive_command_split,
                .adaptive_literal_split = adaptive_literal_split,
                .adaptive_distance_split = adaptive_distance_split,
                .distance_parameter_search = distance_parameter_search,
            });
            mix +%= encoded.len;
            allocator.free(encoded);
        }
        const sample = Sample{ .ns = elapsed(start, io), .mix = mix };
        if (sample.ns < best.ns) best = sample;
    }
    return best;
}

fn measureInterleaved(io: std.Io, allocator: std.mem.Allocator, reference: libbrotli.Runtime, payload: []const u8, options: Options, quality: c_int) !encode_samples.Interleaved {
    var rounds: [encode_samples.round_count]encode_samples.Round = undefined;
    for (&rounds, 0..) |*record, round| {
        const vort_first = round & 1 == 0;
        const first = if (vort_first) try measureVort(io, allocator, payload, options) else try measureReference(io, allocator, reference, payload, options.iterations, quality);
        const second = if (vort_first) try measureReference(io, allocator, reference, payload, options.iterations, quality) else try measureVort(io, allocator, payload, options);
        const vort_sample = if (vort_first) first else second;
        const reference_sample = if (vort_first) second else first;
        record.* = .{
            .index = round,
            .vort_first = vort_first,
            .vort_ns = vort_sample.ns,
            .reference_ns = reference_sample.ns,
            .vort_mix = vort_sample.mix,
            .reference_mix = reference_sample.mix,
        };
    }
    return encode_samples.Interleaved.fromRounds(rounds);
}

fn measureVort(io: std.Io, allocator: std.mem.Allocator, payload: []const u8, options: Options) !Sample {
    if (options.planned_quality == null)
        return measureVortLegacy(io, allocator, payload, options.iterations);

    var mix: usize = 0;
    const encode_options: vort.BrotliPlannedEncodeOptions = .{
        .level = .fast,
        .quality = options.planned_quality,
        .mode = options.planned_mode,
        .command_state_max_input_kib = options.command_state_max_input_kib orelse std.math.maxInt(u8),
    };
    const warmup = try vort.brEncodePlannedStreamWithOptionsAlloc(allocator, payload, encode_options);
    allocator.free(warmup);
    const start = std.Io.Clock.awake.now(io);
    for (0..options.iterations) |_| {
        const encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(allocator, payload, encode_options);
        mix +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .ns = elapsed(start, io), .mix = mix };
}

fn measureVortLegacy(io: std.Io, allocator: std.mem.Allocator, payload: []const u8, iterations: usize) !Sample {
    var mix: usize = 0;
    var encoder = vort.BrotliPlannedStreamEncoder.init(allocator);
    defer encoder.deinit();
    const warmup = try encoder.encodeAlloc(allocator, payload);
    allocator.free(warmup);
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try encoder.encodeAlloc(allocator, payload);
        mix +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .ns = elapsed(start, io), .mix = mix };
}

fn measureReference(io: std.Io, allocator: std.mem.Allocator, reference: libbrotli.Runtime, payload: []const u8, iterations: usize, quality: c_int) !Sample {
    var mix: usize = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try reference.encodeAlloc(allocator, payload, quality);
        mix +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .ns = elapsed(start, io), .mix = mix };
}

fn elapsed(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0;
    return (@as(f64, @floatFromInt(bytes)) / (1024 * 1024)) / (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}

fn caseNameForPath(allocator: std.mem.Allocator, path: []const u8, index: usize) ![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    try out.writer.print("file{d}_", .{index});
    for (std.fs.path.basename(path)) |byte|
        try out.writer.writeByte(if (std.ascii.isAlphanumeric(byte)) byte else '_');
    return try out.toOwnedSlice();
}

fn readFilePrefixAlloc(
    io: std.Io,
    allocator: std.mem.Allocator,
    path: []const u8,
    limit: usize,
) ![]u8 {
    if (limit == 0) return error.MissingLimit;
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const stat = try file.stat(io);
    const read_len: usize = @intCast(@min(stat.size, limit));
    if (read_len == 0) return error.InputTooSmall;
    const bytes = try allocator.alloc(u8, read_len);
    errdefer allocator.free(bytes);
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &buffer);
    if (try reader.interface.readSliceShort(bytes) != read_len)
        return error.InputTooSmall;
    return bytes;
}

fn parseOptions(allocator: std.mem.Allocator, args: *std.process.Args.Iterator) !Options {
    var options = Options{};
    errdefer options.deinit(allocator);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--samples-json")) {
            options.samples_json_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--samples-json=")) {
            options.samples_json_path = arg["--samples-json=".len..];
            continue;
        }
        if (std.mem.eql(u8, arg, "--libbrotli-encoder")) {
            options.reference_paths.encoder = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--libbrotli-encoder=")) {
            options.reference_paths.encoder = arg["--libbrotli-encoder=".len..];
            continue;
        }
        if (std.mem.eql(u8, arg, "--libbrotli-decoder")) {
            options.reference_paths.decoder = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--libbrotli-decoder=")) {
            options.reference_paths.decoder = arg["--libbrotli-decoder=".len..];
            continue;
        }
        if (std.mem.eql(u8, arg, "--libbrotli-common")) {
            options.reference_paths.common = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--libbrotli-common=")) {
            options.reference_paths.common = arg["--libbrotli-common=".len..];
            continue;
        }
        if (std.mem.eql(u8, arg, "--planned-quality")) {
            options.planned_quality = try parsePlannedQuality(args.next() orelse return error.MissingLimit);
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--planned-quality=")) {
            options.planned_quality = try parsePlannedQuality(arg["--planned-quality=".len..]);
            continue;
        }
        if (std.mem.eql(u8, arg, "--planned-mode")) {
            options.planned_mode = try parsePlannedMode(args.next() orelse return error.MissingLimit);
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--planned-mode=")) {
            options.planned_mode = try parsePlannedMode(arg["--planned-mode=".len..]);
            continue;
        }
        if (std.mem.eql(u8, arg, "--command-state-max-input-kib")) {
            options.command_state_max_input_kib = try std.fmt.parseInt(
                u8,
                args.next() orelse return error.MissingLimit,
                10,
            );
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--command-state-max-input-kib=")) {
            options.command_state_max_input_kib = try std.fmt.parseInt(
                u8,
                arg["--command-state-max-input-kib=".len..],
                10,
            );
            continue;
        }
        if (std.mem.eql(u8, arg, "--iterations")) options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10) else if (std.mem.eql(u8, arg, "--case")) options.case_filter = args.next() orelse return error.MissingCorpusPath else if (std.mem.eql(u8, arg, "--quality")) options.quality_override = try std.fmt.parseInt(c_int, args.next() orelse return error.MissingLimit, 10) else if (std.mem.eql(u8, arg, "--extended-dictionary-probes")) options.extended_dictionary_probes = try std.fmt.parseInt(u16, args.next() orelse return error.MissingLimit, 10) else if (std.mem.eql(u8, arg, "--adaptive-command-split")) options.adaptive_command_split = true else if (std.mem.eql(u8, arg, "--adaptive-literal-split")) options.adaptive_literal_split = true else if (std.mem.eql(u8, arg, "--adaptive-distance-split")) options.adaptive_distance_split = true else if (std.mem.eql(u8, arg, "--no-adaptive-distance-split")) options.adaptive_distance_split = false else if (std.mem.eql(u8, arg, "--distance-parameter-search")) options.distance_parameter_search = true else if (std.mem.eql(u8, arg, "--no-distance-parameter-search")) options.distance_parameter_search = false else if (std.mem.eql(u8, arg, "--csv")) options.csv_path = args.next() orelse return error.MissingCorpusPath else if (std.mem.eql(u8, arg, "--limit")) options.path_limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10) else if (std.mem.eql(u8, arg, "--path")) try options.paths.append(allocator, try allocator.dupe(u8, args.next() orelse return error.MissingCorpusPath)) else return error.UnknownArgument;
    }
    if (options.iterations == 0 or options.path_limit == 0) return error.InvalidBlockPlan;
    _ = try options.reference_paths.complete();
    if (options.samples_json_path) |path| {
        if (path.len == 0 or std.mem.indexOfScalar(u8, path, 0) != null) return error.MissingCorpusPath;
        if (options.csv_path) |csv_path| if (std.mem.eql(u8, path, csv_path)) return error.OutputPathCollision;
    }
    if (options.quality_override) |quality| if (quality < 0 or quality > 11) return error.InvalidBlockPlan;
    if (options.planned_quality == null and options.planned_mode != .generic) return error.InvalidBlockPlan;
    if (options.command_state_max_input_kib != null and
        (options.planned_quality == null or options.planned_quality.? < 10))
    {
        return error.InvalidBlockPlan;
    }
    if (options.extended_dictionary_probes > vort.brotliMaxExtendedDictionaryProbes) return error.InvalidBlockPlan;
    return options;
}

fn parsePlannedQuality(value: []const u8) !u4 {
    const quality = try std.fmt.parseInt(u8, value, 10);
    if (quality > 11) return error.InvalidBlockPlan;
    return @intCast(quality);
}

fn parsePlannedMode(value: []const u8) !vort.BrotliPlannedMode {
    if (std.mem.eql(u8, value, "generic")) return .generic;
    if (std.mem.eql(u8, value, "text")) return .text;
    if (std.mem.eql(u8, value, "font")) return .font;
    return error.InvalidBlockPlan;
}

test "Brotli encode benchmark accepts explicit three library paths without samples" {
    const argv = [_][*:0]const u8{ "--libbrotli-encoder=enc.so", "--libbrotli-decoder", "dec.so", "--libbrotli-common=com.so" };
    var args = try std.process.Args.Iterator.initAllocator(.{ .vector = &argv }, std.testing.allocator);
    defer args.deinit();
    var options = try parseOptions(std.testing.allocator, &args);
    defer options.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(?[]const u8, null), options.samples_json_path);
    const paths = (try options.reference_paths.complete()).?;
    try std.testing.expectEqualStrings("enc.so", paths.encoder);
    try std.testing.expectEqualStrings("dec.so", paths.decoder);
    try std.testing.expectEqualStrings("com.so", paths.common);
}

test "Brotli encode benchmark validates sample output and incomplete paths before timing" {
    const partial = [_][*:0]const u8{ "--samples-json", "samples.json", "--libbrotli-decoder=dec.so" };
    var partial_args = try std.process.Args.Iterator.initAllocator(.{ .vector = &partial }, std.testing.allocator);
    defer partial_args.deinit();
    try std.testing.expectError(error.IncompleteReferencePaths, parseOptions(std.testing.allocator, &partial_args));
    const empty = [_][*:0]const u8{"--samples-json="};
    var empty_args = try std.process.Args.Iterator.initAllocator(.{ .vector = &empty }, std.testing.allocator);
    defer empty_args.deinit();
    try std.testing.expectError(error.MissingCorpusPath, parseOptions(std.testing.allocator, &empty_args));
    const same = [_][*:0]const u8{ "--samples-json=same.txt", "--csv", "same.txt" };
    var same_args = try std.process.Args.Iterator.initAllocator(.{ .vector = &same }, std.testing.allocator);
    defer same_args.deinit();
    try std.testing.expectError(error.OutputPathCollision, parseOptions(std.testing.allocator, &same_args));
}
