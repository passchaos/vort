const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");
const benchmark_provenance = @import("benchmark_provenance");
const q8_records_fixture = @import("q8_records_fixture.zig");

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
    case_filter: ?[]const u8 = null,
    quality_override: ?c_int = null,
    extended_dictionary_probes: u16 = 0,
    adaptive_command_split: bool = false,
    adaptive_literal_split: bool = false,
    adaptive_distance_split: ?bool = null,
    distance_parameter_search: ?bool = null,
    path_limit: usize = 128 * 1024,
    paths: std.ArrayList([]const u8) = .empty,

    fn deinit(options: *Options, allocator: std.mem.Allocator) void {
        for (options.paths.items) |path| allocator.free(path);
        options.paths.deinit(allocator);
    }
};
const Sample = struct { ns: u64, mix: usize };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var options = try parseOptions(init.gpa, &args);
    defer options.deinit(init.gpa);
    const provenance = try benchmark_provenance.capture(
        init.io,
        init.gpa,
        init.minimal.args,
        "single",
    );
    defer provenance.deinit(init.gpa);
    var reference = try libbrotli.Runtime.open();
    defer reference.deinit();
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
        const source = try std.Io.Dir.cwd().readFileAlloc(init.io, "src/br.zig", init.gpa, .limited(2 * 1024 * 1024));
        defer init.gpa.free(source);
        const source_file = try init.gpa.dupe(u8, source[0 .. 32 * 1024]);
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
    try csv.writer.print("case,reference_version,quality,input_bytes,input_sha256,extended_dictionary_probes,vort_bytes,lazy_bytes,ratio_bytes,ratio_dictionary_copies,ratio_dictionary_bytes,reference_bytes,iterations,vort_ns,lazy_ns,ratio_ns,reference_ns,vort_mib_s,lazy_mib_s,ratio_mib_s,reference_mib_s,vort_over_reference,lazy_over_reference,ratio_over_reference,vort_size_over_reference,lazy_size_over_reference,ratio_size_over_reference,checksum,{s}\n", .{benchmark_provenance.csv_columns});
    var selected_cases: usize = 0;
    for (cases.items) |case| {
        if (options.case_filter) |filter|
            if (!std.mem.eql(u8, filter, case.name)) continue;
        selected_cases += 1;
        const quality = options.quality_override orelse case.quality orelse 3;
        const vort_encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, case.payload, .{ .level = .fast });
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
        const samples = try measureInterleaved(init.io, init.gpa, reference, case.payload, options, quality);
        const lazy_sample = try measurePlanned(init.io, init.gpa, case.payload, options.iterations, .balanced, 0, false, false, null, null);
        const ratio_sample = try measurePlanned(init.io, init.gpa, case.payload, options.iterations, .ratio, extended_dictionary_probes, options.adaptive_command_split, options.adaptive_literal_split, options.adaptive_distance_split, options.distance_parameter_search);
        const total_bytes = case.payload.len * options.iterations;
        const vort_rate = mibPerSecond(total_bytes, samples.vort.ns);
        const reference_rate = mibPerSecond(total_bytes, samples.reference.ns);
        const lazy_rate = mibPerSecond(total_bytes, lazy_sample.ns);
        const ratio_rate = mibPerSecond(total_bytes, ratio_sample.ns);
        const input_sha256 = benchmark_provenance.sha256Hex(case.payload);
        try csv.writer.print("{s},{x},{d},{d},{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.2},{d:.2},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d}", .{
            case.name,
            reference.version(),
            quality,
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

fn measureInterleaved(io: std.Io, allocator: std.mem.Allocator, reference: libbrotli.Runtime, payload: []const u8, options: Options, quality: c_int) !struct { vort: Sample, reference: Sample } {
    var best_vort = Sample{ .ns = std.math.maxInt(u64), .mix = 0 };
    var best_reference = best_vort;
    for (0..5) |round| {
        const vort_first = round & 1 == 0;
        const first = if (vort_first) try measureVort(io, allocator, payload, options.iterations) else try measureReference(io, allocator, reference, payload, options.iterations, quality);
        const second = if (vort_first) try measureReference(io, allocator, reference, payload, options.iterations, quality) else try measureVort(io, allocator, payload, options.iterations);
        const vort_sample = if (vort_first) first else second;
        const reference_sample = if (vort_first) second else first;
        if (vort_sample.ns < best_vort.ns) best_vort = vort_sample;
        if (reference_sample.ns < best_reference.ns) best_reference = reference_sample;
    }
    return .{ .vort = best_vort, .reference = best_reference };
}

fn measureVort(io: std.Io, allocator: std.mem.Allocator, payload: []const u8, iterations: usize) !Sample {
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

fn parseOptions(allocator: std.mem.Allocator, args: *std.process.Args.Iterator) !Options {
    var options = Options{};
    errdefer options.deinit(allocator);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10) else if (std.mem.eql(u8, arg, "--case")) options.case_filter = args.next() orelse return error.MissingCorpusPath else if (std.mem.eql(u8, arg, "--quality")) options.quality_override = try std.fmt.parseInt(c_int, args.next() orelse return error.MissingLimit, 10) else if (std.mem.eql(u8, arg, "--extended-dictionary-probes")) options.extended_dictionary_probes = try std.fmt.parseInt(u16, args.next() orelse return error.MissingLimit, 10) else if (std.mem.eql(u8, arg, "--adaptive-command-split")) options.adaptive_command_split = true else if (std.mem.eql(u8, arg, "--adaptive-literal-split")) options.adaptive_literal_split = true else if (std.mem.eql(u8, arg, "--adaptive-distance-split")) options.adaptive_distance_split = true else if (std.mem.eql(u8, arg, "--no-adaptive-distance-split")) options.adaptive_distance_split = false else if (std.mem.eql(u8, arg, "--distance-parameter-search")) options.distance_parameter_search = true else if (std.mem.eql(u8, arg, "--no-distance-parameter-search")) options.distance_parameter_search = false else if (std.mem.eql(u8, arg, "--csv")) options.csv_path = args.next() orelse return error.MissingCorpusPath else if (std.mem.eql(u8, arg, "--limit")) options.path_limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10) else if (std.mem.eql(u8, arg, "--path")) try options.paths.append(allocator, try allocator.dupe(u8, args.next() orelse return error.MissingCorpusPath)) else return error.UnknownArgument;
    }
    if (options.iterations == 0 or options.path_limit == 0) return error.InvalidBlockPlan;
    if (options.quality_override) |quality| if (quality < 0 or quality > 11) return error.InvalidBlockPlan;
    if (options.extended_dictionary_probes > vort.brotliMaxExtendedDictionaryProbes) return error.InvalidBlockPlan;
    return options;
}
