const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");
const benchmark_provenance = @import("benchmark_provenance");
const encode_samples = @import("encode_samples.zig");

const Case = struct {
    name: []const u8,
    payload: []const u8,
    owned: bool = false,

    fn deinit(case: Case, allocator: std.mem.Allocator) void {
        if (case.owned) {
            allocator.free(case.name);
            allocator.free(case.payload);
        }
    }
};
const Options = struct {
    iterations: usize = 1,
    rounds: usize = 3,
    csv_path: ?[]const u8 = null,
    samples_json_path: ?[]const u8 = null,
    only_case: ?[]const u8 = null,
    only_level: ?c_int = null,
    native_selection: ?vort.ZstdNativeFrameSelection = null,
    strategy: ?vort.zstd.Strategy = null,
    fast_acceleration: ?u32 = null,
    show_help: bool = false,
    reference_library_path: ?[]const u8 = null,
    path_limit: usize = std.compress.zstd.block_size_max,
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
    if (options.show_help) {
        var buffer: [2048]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(
            \\Usage: vort-zstd-encode-bench [options]
            \\  --level N                    Choose a level from -131072 through 22.
            \\  --strategy NAME              Choose one of the strategies listed below.
            \\  --fast-acceleration N        Choose acceleration from 1 through 131072.
            \\  --native-selection fast_compressed
            \\  --case NAME --path FILE --limit BYTES
            \\  --iterations N --rounds N --csv FILE --libzstd FILE
            \\  --samples-json FILE          Save raw alternating rounds and JSON provenance.
            \\  --level=N, --strategy=NAME and --fast-acceleration=N are also accepted.
            \\  Defaults: levels 1, 3, 9 and 22; one iteration; three rounds.
            \\  Negative level -N selects fast acceleration N.
            \\  Acceleration is supported by fast and double_fast strategies.
            \\
        );
        try stdout.interface.writeAll("  Strategies: ");
        inline for (std.meta.fields(vort.zstd.Strategy), 0..) |field, index| {
            if (index != 0) try stdout.interface.writeByte('|');
            try stdout.interface.writeAll(field.name);
        }
        try stdout.interface.writeByte('\n');
        try stdout.interface.flush();
        return;
    }
    try encode_samples.validateOutputPaths(init.io, init.gpa, options.csv_path, options.samples_json_path);
    const provenance = try benchmark_provenance.capture(init.io, init.gpa, init.minimal.args, "internal-auto");
    defer provenance.deinit(init.gpa);
    var runtime = if (options.reference_library_path) |path|
        try libzstd.Runtime.openPath(path)
    else
        try libzstd.Runtime.open();
    defer runtime.deinit();
    const sample_reference = if (options.samples_json_path != null)
        try encode_samples.Reference.capture(init.io, init.gpa, options.reference_library_path, runtime.version())
    else
        null;
    defer if (sample_reference) |reference| reference.deinit(init.gpa);
    var sample_report: encode_samples.Report = .{};
    defer sample_report.deinit(init.gpa);

    var numbered_json: std.ArrayList(u8) = .empty;
    defer numbered_json.deinit(init.gpa);
    while (numbered_json.items.len < 32 * 1024) {
        var line: [128]u8 = undefined;
        const index = numbered_json.items.len / 64;
        const formatted = try std.fmt.bufPrint(&line, "{{\"id\":{d},\"service\":\"vort\",\"message\":\"structured zstd encode corpus\"}}\n", .{index});
        try numbered_json.appendSlice(init.gpa, formatted);
    }
    const binary = try init.gpa.alloc(u8, 32 * 1024);
    defer init.gpa.free(binary);
    var state: u32 = 0xfeed_beef;
    for (binary, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(state >> 16);
    }
    const level3_tradeoff = try init.gpa.alloc(u8, 32 * 1024);
    defer init.gpa.free(level3_tradeoff);
    state = @truncate(0x9e37_79b9 +% 32 *% 0x10001 +% 4 *% 0x101 +% 17 +% 1 *% 0x0100_0193);
    for (level3_tradeoff, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 60) @truncate(index * 17 + 13) else @truncate(state >> 16);
    }
    const tradeoff_copy_len = level3_tradeoff.len / 4;
    @memcpy(level3_tradeoff[level3_tradeoff.len - tradeoff_copy_len ..], level3_tradeoff[level3_tradeoff.len / 4 ..][0..tradeoff_copy_len]);
    const multiblock = try init.gpa.alloc(u8, 129 * 1024);
    defer init.gpa.free(multiblock);
    state = @truncate(0x9e37_79b9 +% 129 *% 0x10001 +% 16 *% 0x101 +% 23);
    for (multiblock, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(state >> 16);
    }
    const multiblock_copy_len = multiblock.len / 4;
    @memcpy(multiblock[multiblock.len - multiblock_copy_len ..], multiblock[multiblock.len / 4 ..][0..multiblock_copy_len]);
    var cases: std.ArrayList(Case) = .empty;
    defer {
        for (cases.items) |case| case.deinit(init.gpa);
        cases.deinit(init.gpa);
    }
    if (options.paths.items.len == 0) {
        try cases.append(init.gpa, .{ .name = "text", .payload = "Zstandard encode benchmark text with repeated structure and punctuation.\n" ** 512 });
        try cases.append(init.gpa, .{ .name = "json", .payload = numbered_json.items });
        try cases.append(init.gpa, .{ .name = "binary", .payload = binary });
        try cases.append(init.gpa, .{ .name = "level3_tradeoff", .payload = level3_tradeoff });
        try cases.append(init.gpa, .{ .name = "multiblock", .payload = multiblock });
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
    const default_levels = [_]c_int{ 1, 3, 9, 22 };
    const selected_level = [_]c_int{options.only_level orelse 1};
    const levels: []const c_int = if (options.only_level != null) &selected_level else &default_levels;

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.print("case,reference_version,level,input_bytes,input_sha256,vort_bytes,reference_bytes,size_over_reference,iterations,rounds,vort_ns,reference_ns,vort_mib_s,reference_mib_s,vort_over_reference,checksum,{s}\n", .{benchmark_provenance.csv_columns});
    var selected_rows: usize = 0;
    for (cases.items) |case| for (levels) |level| {
        if (options.only_case) |wanted| if (!std.mem.eql(u8, wanted, case.name)) continue;
        selected_rows += 1;
        const native_options = try resolvedNativeOptions(options, level);
        const vort_encoded = try encodeVort(init.gpa, case.payload, level, native_options);
        defer init.gpa.free(vort_encoded);
        const reference_encoded = try runtime.encodeAlloc(init.gpa, case.payload, level);
        defer init.gpa.free(reference_encoded);
        try verifyBothDecoders(init.gpa, runtime, case.payload, vort_encoded, reference_encoded);
        const raw_rounds: ?[]encode_samples.Round = if (options.samples_json_path != null)
            try init.gpa.alloc(encode_samples.Round, options.rounds)
        else
            null;
        defer if (raw_rounds) |rounds| init.gpa.free(rounds);
        const samples = try measureInterleaved(init.io, init.gpa, runtime, case.payload, level, native_options, options.iterations, options.rounds, raw_rounds);
        const total_bytes = case.payload.len * options.iterations;
        const vort_rate = mibPerSecond(total_bytes, samples.vort.ns);
        const reference_rate = mibPerSecond(total_bytes, samples.reference.ns);
        const input_sha256 = benchmark_provenance.sha256Hex(case.payload);
        if (raw_rounds) |rounds| {
            const resolved_primary = native_options orelse try vort.zstd.resolveFrameOptionsForLevel(level, .{});
            const header = try vort.zstd.inspectNativeFrameHeader(vort_encoded);
            const reference_header = try vort.zstd.inspectNativeFrameHeader(reference_encoded);
            try sample_report.append(init.gpa, .{
                .case = case.name,
                .input_bytes = case.payload.len,
                .input_sha256 = input_sha256,
                .iterations = options.iterations,
                .rounds = rounds,
                .summary = undefined, // append computes it outside measured work.
                .settings = .{
                    .level = level,
                    .api = if (native_options != null) "native_frame" else "level_policy",
                    .requested_strategy = options.strategy,
                    .requested_fast_acceleration = options.fast_acceleration,
                    .requested_native_selection = options.native_selection,
                    .resolved_primary = try encode_samples.ResolvedOptions.capture(resolved_primary),
                    .internal_candidate_settings = if (native_options != null) "resolved_primary" else "public_auto_level_policy",
                    .wire_header = .{ .window_size = header.window_size, .content_size = header.content_size, .content_checksum = header.has_checksum, .dictionary_id = header.dictionary_id },
                    .reference = .{
                        .level = level,
                        .wire_header = .{ .window_size = reference_header.window_size, .content_size = reference_header.content_size, .content_checksum = reference_header.has_checksum, .dictionary_id = reference_header.dictionary_id },
                    },
                },
                .wires = .{
                    .vort_bytes = vort_encoded.len,
                    .reference_bytes = reference_encoded.len,
                    .vort_sha256 = benchmark_provenance.sha256Hex(vort_encoded),
                    .reference_sha256 = benchmark_provenance.sha256Hex(reference_encoded),
                },
            });
        }
        try csv.writer.print("{s},{s},{d},{d},{s},{d},{d},{d:.4},{d},{d},{d},{d},{d:.6},{d:.6},{d:.8},{d}", .{
            case.name,                                                                                  runtime.version(),                         level,          case.payload.len, &input_sha256,        vort_encoded.len, reference_encoded.len,
            @as(f64, @floatFromInt(vort_encoded.len)) / @as(f64, @floatFromInt(reference_encoded.len)), options.iterations,                        options.rounds, samples.vort.ns,  samples.reference.ns, vort_rate,        reference_rate,
            vort_rate / reference_rate,                                                                 samples.vort.mix +% samples.reference.mix,
        });
        try provenance.writeCsvFields(&csv.writer);
        try csv.writer.writeByte('\n');
    };
    if (selected_rows == 0) return error.InvalidBlockPlan;
    if (options.samples_json_path) |path| {
        var json = std.Io.Writer.Allocating.init(init.gpa);
        defer json.deinit();
        try sample_report.write(&json.writer, sample_reference.?, provenance);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = json.written() });
    }
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn verifyBothDecoders(allocator: std.mem.Allocator, runtime: libzstd.Runtime, payload: []const u8, vort_encoded: []const u8, reference_encoded: []const u8) !void {
    const output = try allocator.alloc(u8, payload.len);
    defer allocator.free(output);
    try runtime.decode(vort_encoded, output);
    if (!std.mem.eql(u8, payload, output)) return error.SizeMismatch;
    const written = try vort.zstdDecodeFrameInto(reference_encoded, output);
    if (written != payload.len or !std.mem.eql(u8, payload, output)) return error.SizeMismatch;
}

fn measureInterleaved(io: std.Io, allocator: std.mem.Allocator, runtime: libzstd.Runtime, payload: []const u8, level: c_int, native_options: ?vort.ZstdNativeFrameOptions, iterations: usize, rounds: usize, raw_rounds: ?[]encode_samples.Round) !struct { vort: Sample, reference: Sample } {
    var best_vort = Sample{ .ns = std.math.maxInt(u64), .mix = 0 };
    var best_reference = best_vort;
    for (0..rounds) |round| {
        const vort_first = round & 1 == 0;
        const first = if (vort_first) try measureVort(io, allocator, payload, level, native_options, iterations) else try measureReference(io, allocator, runtime, payload, level, iterations);
        const second = if (vort_first) try measureReference(io, allocator, runtime, payload, level, iterations) else try measureVort(io, allocator, payload, level, native_options, iterations);
        const vort_sample = if (vort_first) first else second;
        const reference_sample = if (vort_first) second else first;
        if (raw_rounds) |raw| raw[round] = .{
            .index = round,
            .vort_first = vort_first,
            .vort_ns = vort_sample.ns,
            .reference_ns = reference_sample.ns,
            .vort_mix = vort_sample.mix,
            .reference_mix = reference_sample.mix,
        };
        if (vort_sample.ns < best_vort.ns) best_vort = vort_sample;
        if (reference_sample.ns < best_reference.ns) best_reference = reference_sample;
    }
    return .{ .vort = best_vort, .reference = best_reference };
}

fn measureVort(io: std.Io, allocator: std.mem.Allocator, payload: []const u8, level: c_int, native_options: ?vort.ZstdNativeFrameOptions, iterations: usize) !Sample {
    var mix: usize = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try encodeVort(allocator, payload, level, native_options);
        mix +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .ns = elapsed(start, io), .mix = mix };
}

fn encodeVort(allocator: std.mem.Allocator, payload: []const u8, level: c_int, native_options: ?vort.ZstdNativeFrameOptions) ![]u8 {
    if (native_options) |options| return (try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, options)).frame;
    return vort.zstdEncodeFrameWithLevelAlloc(allocator, payload, level);
}

fn resolvedNativeOptions(options: Options, level: c_int) !?vort.ZstdNativeFrameOptions {
    var resolved = try vort.zstd.resolveFrameOptionsForLevel(level, .{
        .strategy = options.strategy orelse .auto,
        .fast_acceleration = options.fast_acceleration,
    });
    // Retain the existing positive-level selection gate. New engine controls
    // and negative magnitudes always use the shared library level resolver.
    if (level > 0 and (options.strategy orelse .auto) == .auto and options.fast_acceleration == null) {
        if (options.native_selection) |selection| return .{ .selection = selection, .content_checksum = false };
        return null;
    }
    if (options.native_selection) |selection| {
        if (resolved.selection != .auto and resolved.selection != selection) return error.InvalidBlockPlan;
        resolved.selection = selection;
    }
    try resolved.validate();
    return resolved;
}

fn measureReference(io: std.Io, allocator: std.mem.Allocator, runtime: libzstd.Runtime, payload: []const u8, level: c_int, iterations: usize) !Sample {
    var mix: usize = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try runtime.encodeAlloc(allocator, payload, level);
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
    var options: Options = .{};
    errdefer options.deinit(allocator);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help")) {
            options.show_help = true;
            return options;
        } else if (std.mem.eql(u8, arg, "--iterations"))
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--rounds"))
            options.rounds = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--case"))
            options.only_case = args.next() orelse return error.MissingCorpusPath
        else if (try optionValue("--level", arg, args)) |value| {
            if (options.only_level != null) return error.DuplicateZstdOption;
            options.only_level = try std.fmt.parseInt(c_int, value, 10);
        } else if (try optionValue("--strategy", arg, args)) |value| {
            if (options.strategy != null) return error.DuplicateZstdOption;
            options.strategy = if (std.mem.eql(u8, value, "double-fast")) .double_fast else std.meta.stringToEnum(vort.zstd.Strategy, value) orelse return error.InvalidZstdStrategy;
        } else if (try optionValue("--fast-acceleration", arg, args)) |value| {
            if (options.fast_acceleration != null) return error.DuplicateZstdOption;
            options.fast_acceleration = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, arg, "--native-selection")) {
            const selection = args.next() orelse return error.MissingLimit;
            options.native_selection = if (std.mem.eql(u8, selection, "fast_compressed") or std.mem.eql(u8, selection, "fast-compressed"))
                .fast_compressed
            else
                return error.UnknownArgument;
        } else if (std.mem.eql(u8, arg, "--libzstd"))
            options.reference_library_path = args.next() orelse return error.MissingCorpusPath
        else if (try optionValue("--samples-json", arg, args)) |value| {
            if (options.samples_json_path != null) return error.DuplicateZstdOption;
            options.samples_json_path = value;
        } else if (std.mem.eql(u8, arg, "--csv"))
            options.csv_path = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--limit"))
            options.path_limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--path"))
            try options.paths.append(allocator, try allocator.dupe(u8, args.next() orelse return error.MissingCorpusPath))
        else
            return error.UnknownArgument;
    }
    if (options.iterations == 0 or options.rounds == 0 or options.path_limit == 0) return error.InvalidBlockPlan;
    if (options.only_level) |level| {
        _ = try resolvedNativeOptions(options, level);
    } else {
        for ([_]c_int{ 1, 3, 9, 22 }) |level| _ = try resolvedNativeOptions(options, level);
    }
    return options;
}

fn optionValue(comptime name: []const u8, arg: []const u8, args: *std.process.Args.Iterator) !?[]const u8 {
    if (std.mem.eql(u8, arg, name)) return args.next() orelse error.MissingLimit;
    if (std.mem.startsWith(u8, arg, name ++ "=")) return arg[name.len + 1 ..];
    return null;
}
