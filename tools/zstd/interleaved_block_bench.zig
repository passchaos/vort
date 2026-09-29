const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");
const benchmark_provenance = @import("benchmark_provenance");

const max_file_input_size = 256 * 1024 * 1024;

const Options = struct {
    input_path: ?[]const u8 = null,
    input_name: ?[]const u8 = null,
    input_level: c_int = 1,
    iterations: usize = 1000,
    rounds: usize = 7,
    csv_path: ?[]const u8 = null,
    reference_library_path: ?[]const u8 = null,
};

const Sample = struct {
    elapsed_ns: u64,
    checksum: u64,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);
    const input_path = options.input_path orelse return error.MissingCorpusPath;
    const name = options.input_name orelse std.fs.path.basename(input_path);
    if (name.len == 0 or std.mem.indexOfAny(u8, name, ",\r\n") != null)
        return error.InvalidCaseName;

    var runtime = if (options.reference_library_path) |path|
        try libzstd.Runtime.openPath(path)
    else
        try libzstd.Runtime.open();
    defer runtime.deinit();
    const provenance = try benchmark_provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer provenance.deinit(init.gpa);

    const input = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        input_path,
        init.gpa,
        .limited(max_file_input_size),
    );
    defer init.gpa.free(input);
    if (input.len == 0) return error.InputTooSmall;
    const encoded = try runtime.encodeAlloc(init.gpa, input, options.input_level);
    defer init.gpa.free(encoded);

    const decoded = try init.gpa.alloc(u8, input.len);
    defer init.gpa.free(decoded);
    const written = try vort.zstdDecodeFrameInto(encoded, decoded);
    if (written != input.len or !std.mem.eql(u8, input, decoded)) return error.SizeMismatch;

    var stage = try vort.zstd.prepareNativeInterleavedBlockDecodeStage(init.gpa, encoded, input);
    defer stage.deinit();
    const shape = stage.shape();
    const warmed = try stage.decode();
    if (warmed.decoded_bytes != shape.decoded_bytes) return error.SizeMismatch;
    const sample = try measureStage(init.io, &stage, options.iterations, options.rounds);
    const total_output_bytes = std.math.mul(usize, shape.decoded_bytes, options.iterations) catch
        return error.IntegerOverflow;

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.print(
        "case,input_bytes,input_sha256,encoded_bytes,reference_version,level,iterations,rounds,block_compressed_bytes,block_decoded_bytes,literal_bytes,sequence_count,match_wildcopy,best_ns,ns_per_iteration,ns_per_output_byte,checksum,{s}\n",
        .{benchmark_provenance.csv_columns},
    );
    const input_sha256 = benchmark_provenance.sha256Hex(input);
    try csv.writer.print(
        "{s},{d},{s},{d},{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d:.3},{d:.6},{d}",
        .{
            name,
            input.len,
            &input_sha256,
            encoded.len,
            runtime.version(),
            options.input_level,
            options.iterations,
            options.rounds,
            shape.compressed_bytes,
            shape.decoded_bytes,
            shape.literal_bytes,
            shape.sequence_count,
            @intFromBool(shape.match_wildcopy),
            sample.elapsed_ns,
            perUnit(sample.elapsed_ns, options.iterations),
            perUnit(sample.elapsed_ns, total_output_bytes),
            sample.checksum,
        },
    );
    try provenance.writeCsvFields(&csv.writer);
    try csv.writer.writeByte('\n');

    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [1024]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn measureStage(
    io: std.Io,
    stage: *vort.zstd.NativeInterleavedBlockDecodeStage,
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
        if (std.mem.eql(u8, arg, "--input"))
            options.input_path = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--name"))
            options.input_name = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--level"))
            options.input_level = try std.fmt.parseInt(c_int, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--iterations"))
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--rounds"))
            options.rounds = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--csv"))
            options.csv_path = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--libzstd"))
            options.reference_library_path = args.next() orelse return error.MissingCorpusPath
        else
            return error.UnknownArgument;
    }
    if (options.input_path == null) return error.MissingCorpusPath;
    if (options.iterations == 0 or options.rounds == 0) return error.InvalidBlockPlan;
    return options;
}

fn elapsedNs(io: std.Io, start: std.Io.Timestamp) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn perUnit(ns: u64, count: usize) f64 {
    if (count == 0) return 0;
    return @as(f64, @floatFromInt(ns)) / @as(f64, @floatFromInt(count));
}
