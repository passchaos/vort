const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");
const benchmark_provenance = @import("benchmark_provenance");

const Options = struct {
    iterations: usize = 1000,
    rounds: usize = 7,
    only_case: ?[]const u8 = null,
    input_path: ?[]const u8 = null,
    input_name: ?[]const u8 = null,
    input_level: c_int = 1,
    csv_path: ?[]const u8 = null,
    reference_library_path: ?[]const u8 = null,
};

const Case = struct {
    name: []const u8,
    path: []const u8,
};

const Sample = struct {
    elapsed_ns: u64,
    checksum: u64,
};

const builtin_cases = [_]Case{
    .{ .name = "README", .path = "README.md" },
    .{ .name = "build_zig", .path = "build.zig" },
    .{ .name = "roadmap", .path = "docs/roadmap.md" },
    .{ .name = "zstd_zig", .path = "src/zstd.zig" },
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);
    const provenance = try benchmark_provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer provenance.deinit(init.gpa);
    var runtime = if (options.reference_library_path) |path|
        try libzstd.Runtime.openPath(path)
    else
        try libzstd.Runtime.open();
    defer runtime.deinit();

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.print(
        "case,input_path,input_bytes,input_sha256,encoded_bytes,reference_version,level,iterations,rounds,sequence_count,sequence_block_count,generic_blocks,bounded_all_fse_blocks,wide_all_fse_blocks,best_ns,ns_per_iteration,ns_per_sequence,checksum,{s}\n",
        .{benchmark_provenance.csv_columns},
    );

    var selected: usize = 0;
    if (options.input_path) |path| {
        if (options.only_case != null) return error.InvalidCaseSelection;
        const name = options.input_name orelse std.fs.path.basename(path);
        try validateCaseName(name);
        try measureCase(init, runtime, &csv.writer, .{ .name = name, .path = path }, options, provenance);
        selected = 1;
    } else {
        if (options.input_name != null or options.input_level != 1) return error.MissingCorpusPath;
        for (builtin_cases) |case| {
            if (options.only_case) |wanted| if (!std.mem.eql(u8, wanted, case.name)) continue;
            try measureCase(init, runtime, &csv.writer, case, options, provenance);
            selected += 1;
        }
    }
    if (selected == 0) return error.InvalidCaseSelection;

    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [1024]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn measureCase(
    init: std.process.Init,
    runtime: libzstd.Runtime,
    writer: *std.Io.Writer,
    case: Case,
    options: Options,
    provenance: benchmark_provenance.Info,
) !void {
    const input = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        case.path,
        init.gpa,
        .limited(128 * 1024 * 1024),
    );
    defer init.gpa.free(input);
    if (input.len == 0) return error.InputTooSmall;
    const encoded = try runtime.encodeAlloc(init.gpa, input, options.input_level);
    defer init.gpa.free(encoded);

    const decoded = try init.gpa.alloc(u8, input.len);
    defer init.gpa.free(decoded);
    const written = try vort.zstdDecodeFrameInto(encoded, decoded);
    if (written != input.len or !std.mem.eql(u8, input, decoded)) return error.SizeMismatch;

    const sequence_profile = try vort.zstd.benchmarkNativeSequenceCopyProfile(encoded);
    var stage = try vort.zstd.prepareNativeSequenceDecodeStage(init.gpa, encoded);
    defer stage.deinit();
    const shape = stage.shape();
    const warmed = try stage.decode();

    if (warmed.sequence_count != shape.sequence_count or
        shape.sequence_count != sequence_profile.sequence_count) return error.SizeMismatch;
    const sample = try measureStage(init.io, &stage, options.iterations, options.rounds);
    const input_sha256 = benchmark_provenance.sha256Hex(input);
    const total_sequences = std.math.mul(usize, shape.sequence_count, options.iterations) catch return error.IntegerOverflow;
    try writer.print(
        "{s},{s},{d},{s},{d},{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d:.3},{d:.3},{d}",
        .{
            case.name,
            case.path,
            input.len,
            &input_sha256,
            encoded.len,
            runtime.version(),
            options.input_level,
            options.iterations,
            options.rounds,
            shape.sequence_count,
            shape.sequence_block_count,
            shape.generic_block_count,
            shape.bounded_all_fse_block_count,
            shape.wide_all_fse_block_count,
            sample.elapsed_ns,
            perUnit(sample.elapsed_ns, options.iterations),
            perUnit(sample.elapsed_ns, total_sequences),
            sample.checksum,
        },
    );
    try provenance.writeCsvFields(writer);
    try writer.writeByte('\n');
}

fn measureStage(
    io: std.Io,
    stage: *const vort.zstd.NativeSequenceDecodeStage,
    iterations: usize,
    rounds: usize,
) !Sample {
    var best: Sample = .{ .elapsed_ns = std.math.maxInt(u64), .checksum = 0 };
    for (0..rounds) |_| {
        var checksum: u64 = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            const result = try stage.decode();
            checksum +%= result.checksum;
            checksum +%= result.sequence_count;
        }
        const elapsed_ns = elapsedNs(io, start);
        std.mem.doNotOptimizeAway(checksum);
        if (elapsed_ns < best.elapsed_ns) best = .{ .elapsed_ns = elapsed_ns, .checksum = checksum };
    }
    return best;
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations"))
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--rounds"))
            options.rounds = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--case"))
            options.only_case = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--input"))
            options.input_path = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--name"))
            options.input_name = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--level"))
            options.input_level = try std.fmt.parseInt(c_int, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--csv"))
            options.csv_path = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--libzstd"))
            options.reference_library_path = args.next() orelse return error.MissingCorpusPath
        else
            return error.UnknownArgument;
    }
    if (options.iterations == 0 or options.rounds == 0) return error.InvalidBlockPlan;
    return options;
}

fn validateCaseName(name: []const u8) !void {
    if (name.len == 0 or std.mem.indexOfAny(u8, name, ",\r\n") != null) return error.InvalidCaseName;
}

fn elapsedNs(io: std.Io, start: std.Io.Timestamp) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn perUnit(ns: u64, count: usize) f64 {
    if (count == 0) return 0;
    return @as(f64, @floatFromInt(ns)) / @as(f64, @floatFromInt(count));
}
