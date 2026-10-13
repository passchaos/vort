const std = @import("std");
const vort = @import("vort");
const liblzma = @import("liblzma_runtime.zig");
const benchmark_provenance = @import("benchmark_provenance");

const Options = struct {
    iterations: usize = 1,
    rounds: usize = 3,
    only_case: ?[]const u8 = null,
    csv_path: ?[]const u8 = null,
    lazy_control: bool = false,
};

const Case = struct {
    name: []const u8,
    input: []const u8,
    dictionary_size: usize,
    parser: vort.XzEncodeParser = .greedy,
};

const Sample = struct { ns: u64, mix: usize };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);
    const provenance = try benchmark_provenance.capture(
        init.io,
        init.gpa,
        init.minimal.args,
        "single",
    );
    defer provenance.deinit(init.gpa);
    var runtime = try liblzma.Runtime.open();
    defer runtime.deinit();

    const text = try makeText(init.gpa, 256 * 1024);
    defer init.gpa.free(text);
    const json = try makeJson(init.gpa, 256 * 1024);
    defer init.gpa.free(json);
    const binary = try makeBinary(init.gpa, 256 * 1024);
    defer init.gpa.free(binary);
    const wide128 = try makeWide(init.gpa, 128 * 1024, 8192);
    defer init.gpa.free(wide128);
    const wide1m = try makeWide(init.gpa, 1024 * 1024, 8192);
    defer init.gpa.free(wide1m);
    const cases = [_]Case{
        .{ .name = "text256k", .input = text, .dictionary_size = 128 * 1024 },
        .{ .name = "text256k_lazy", .input = text, .dictionary_size = 128 * 1024, .parser = .lazy },
        .{ .name = "json256k", .input = json, .dictionary_size = 128 * 1024 },
        .{ .name = "json256k_lazy", .input = json, .dictionary_size = 128 * 1024, .parser = .lazy },
        .{ .name = "binary256k", .input = binary, .dictionary_size = 128 * 1024 },
        .{ .name = "binary256k_lazy", .input = binary, .dictionary_size = 128 * 1024, .parser = .lazy },
        .{ .name = "wide128k", .input = wide128, .dictionary_size = 128 * 1024 },
        .{ .name = "wide128k_lazy", .input = wide128, .dictionary_size = 128 * 1024, .parser = .lazy },
        .{ .name = "wide1m", .input = wide1m, .dictionary_size = 1024 * 1024 },
    };

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.print(
        "case,reference_version,preset,parser,lazy_control,dictionary_bytes,input_bytes,input_sha256,vort_bytes,reference_bytes,size_over_reference,iterations,rounds,vort_ns,reference_ns,vort_mib_s,reference_mib_s,vort_over_reference,checksum,{s}\n",
        .{benchmark_provenance.csv_columns},
    );
    var selected: usize = 0;
    for (cases) |case| {
        if (options.only_case) |wanted|
            if (!std.mem.eql(u8, wanted, case.name)) continue;
        selected += 1;
        const vort_encoded = try encodeVort(init.gpa, case, options.lazy_control);
        defer init.gpa.free(vort_encoded);
        const reference_encoded = try runtime.encodeAlloc(init.gpa, case.input, 1);
        defer init.gpa.free(reference_encoded);
        try verifyBoth(init.gpa, runtime, case.input, vort_encoded, reference_encoded);
        const sample = try measureInterleaved(
            init.io,
            init.gpa,
            runtime,
            case,
            options.iterations,
            options.rounds,
            options.lazy_control,
        );
        const bytes = case.input.len * options.iterations;
        const vort_rate = mibPerSecond(bytes, sample.vort.ns);
        const reference_rate = mibPerSecond(bytes, sample.reference.ns);
        try csv.writer.print(
            "{s},{s},1,{s},{},{d},{d},{s},{d},{d},{d:.6},{d},{d},{d},{d},{d:.3},{d:.3},{d:.6},{d}",
            .{
                case.name,
                runtime.version(),
                @tagName(case.parser),
                options.lazy_control,
                case.dictionary_size,
                case.input.len,
                &benchmark_provenance.sha256Hex(case.input),
                vort_encoded.len,
                reference_encoded.len,
                @as(f64, @floatFromInt(vort_encoded.len)) / @as(f64, @floatFromInt(reference_encoded.len)),
                options.iterations,
                options.rounds,
                sample.vort.ns,
                sample.reference.ns,
                vort_rate,
                reference_rate,
                vort_rate / reference_rate,
                sample.vort.mix +% sample.reference.mix,
            },
        );
        try provenance.writeCsvFields(&csv.writer);
        try csv.writer.writeByte('\n');
    }
    if (selected == 0) return error.InvalidBlockPlan;
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
        } else if (std.mem.eql(u8, arg, "--rounds")) {
            options.rounds = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
        } else if (std.mem.eql(u8, arg, "--case")) {
            options.only_case = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--csv")) {
            options.csv_path = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--lazy-control")) {
            options.lazy_control = true;
        } else return error.UnknownArgument;
    }
    if (options.iterations == 0 or options.rounds == 0) return error.InvalidBlockPlan;
    return options;
}

fn encodeVort(allocator: std.mem.Allocator, case: Case, lazy_control: bool) ![]u8 {
    const options = vort.XzEncodeOptions{
        .check = .crc64,
        .block_size = 2 * 1024 * 1024,
        .dictionary_size = case.dictionary_size,
    };
    return switch (if (lazy_control) vort.XzEncodeParser.greedy else case.parser) {
        .greedy => vort.encodeXzAlloc(allocator, case.input, options),
        .lazy => vort.encodeXzLazyAlloc(allocator, case.input, options),
    };
}

fn verifyBoth(
    allocator: std.mem.Allocator,
    runtime: liblzma.Runtime,
    input: []const u8,
    vort_encoded: []const u8,
    reference_encoded: []const u8,
) !void {
    const output = try allocator.alloc(u8, input.len);
    defer allocator.free(output);
    try runtime.decode(vort_encoded, output);
    if (!std.mem.eql(u8, input, output)) return error.SizeMismatch;
    const written = try vort.decodeXzInto(allocator, reference_encoded, output);
    if (written != input.len or !std.mem.eql(u8, input, output))
        return error.SizeMismatch;
}

fn measureInterleaved(
    io: std.Io,
    allocator: std.mem.Allocator,
    runtime: liblzma.Runtime,
    case: Case,
    iterations: usize,
    rounds: usize,
    lazy_control: bool,
) !struct { vort: Sample, reference: Sample } {
    var best_vort = Sample{ .ns = std.math.maxInt(u64), .mix = 0 };
    var best_reference = best_vort;
    for (0..rounds) |round| {
        const vort_first = round & 1 == 0;
        const first = if (vort_first)
            try measureVort(io, allocator, case, iterations, lazy_control)
        else
            try measureReference(io, allocator, runtime, case, iterations);
        const second = if (vort_first)
            try measureReference(io, allocator, runtime, case, iterations)
        else
            try measureVort(io, allocator, case, iterations, lazy_control);
        const vort_sample = if (vort_first) first else second;
        const reference_sample = if (vort_first) second else first;
        if (vort_sample.ns < best_vort.ns) best_vort = vort_sample;
        if (reference_sample.ns < best_reference.ns) best_reference = reference_sample;
    }
    return .{ .vort = best_vort, .reference = best_reference };
}

fn measureVort(
    io: std.Io,
    allocator: std.mem.Allocator,
    case: Case,
    iterations: usize,
    lazy_control: bool,
) !Sample {
    var mix: usize = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try encodeVort(allocator, case, lazy_control);
        mix +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .ns = elapsed(start, io), .mix = mix };
}

fn measureReference(
    io: std.Io,
    allocator: std.mem.Allocator,
    runtime: liblzma.Runtime,
    case: Case,
    iterations: usize,
) !Sample {
    var mix: usize = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try runtime.encodeAlloc(allocator, case.input, 1);
        mix +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .ns = elapsed(start, io), .mix = mix };
}

fn makeText(allocator: std.mem.Allocator, size: usize) ![]u8 {
    const phrase = "Vort XZ encode benchmark: repeated text, punctuation, and words.\n";
    const output = try allocator.alloc(u8, size);
    for (output, 0..) |*byte, index| byte.* = phrase[index % phrase.len];
    return output;
}

fn makeJson(allocator: std.mem.Allocator, size: usize) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.ensureTotalCapacity(allocator, size);
    var index: usize = 0;
    while (output.items.len < size) : (index += 1) {
        var line: [160]u8 = undefined;
        const formatted = try std.fmt.bufPrint(
            &line,
            "{{\"id\":{d},\"service\":\"vort\",\"status\":\"ok\",\"message\":\"structured xz benchmark\"}}\n",
            .{index},
        );
        const remaining = size - output.items.len;
        try output.appendSlice(allocator, formatted[0..@min(remaining, formatted.len)]);
    }
    return output.toOwnedSlice(allocator);
}

fn makeBinary(allocator: std.mem.Allocator, size: usize) ![]u8 {
    const output = try allocator.alloc(u8, size);
    var state: u32 = 0x9e37_79b9;
    for (output, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 48) @truncate(index * 17 + index / 31) else @truncate(state >> 24);
    }
    return output;
}

fn makeWide(
    allocator: std.mem.Allocator,
    distance: usize,
    repeated_len: usize,
) ![]u8 {
    const output = try allocator.alloc(u8, distance + repeated_len);
    var state: u32 = @truncate(0x243f_6a88 +% distance);
    for (output[0..distance]) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    @memcpy(output[distance..], output[0..repeated_len]);
    return output;
}

fn elapsed(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0;
    return (@as(f64, @floatFromInt(bytes)) / (1024 * 1024)) /
        (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}
