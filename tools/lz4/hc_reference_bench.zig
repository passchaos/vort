const std = @import("std");
const vort = @import("vort");
const liblz4 = @import("liblz4_runtime.zig");
const benchmark_provenance = @import("benchmark_provenance");

const Options = struct {
    iterations: usize = 5,
    csv_path: ?[]const u8 = null,
};

const Case = struct {
    name: []const u8,
    input: []const u8,
    dictionary: ?vort.Lz4NativeDictionary,
    block_mode: vort.Lz4BlockMode,
    level: i32,
};

const Sample = struct { elapsed_ns: u64, checksum: u64 };
const PairedSample = struct { vort: Sample, reference: Sample };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);
    const provenance = try benchmark_provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer provenance.deinit(init.gpa);
    var runtime = try liblz4.Runtime.open();
    defer runtime.deinit();

    const linked = try makeLinkedPayload(init.gpa);
    defer init.gpa.free(linked);
    const dictionary_bytes = try init.gpa.alloc(u8, 64 * 1024);
    defer init.gpa.free(dictionary_bytes);
    fillRandomish(dictionary_bytes, 0x3141_5926);
    const dictionary = vort.Lz4NativeDictionary.init(0x3141_5926, dictionary_bytes);
    const dictionary_payload = try makeDictionaryPayload(init.gpa, dictionary_bytes);
    defer init.gpa.free(dictionary_payload);
    const cases = [_]Case{
        .{ .name = "independent_l9", .input = linked, .dictionary = null, .block_mode = .independent, .level = 9 },
        .{ .name = "linked_l9", .input = linked, .dictionary = null, .block_mode = .linked, .level = 9 },
        .{ .name = "linked_l12", .input = linked, .dictionary = null, .block_mode = .linked, .level = 12 },
        .{ .name = "dictionary_independent_l9", .input = dictionary_payload, .dictionary = dictionary, .block_mode = .independent, .level = 9 },
        .{ .name = "dictionary_linked_l9", .input = dictionary_payload, .dictionary = dictionary, .block_mode = .linked, .level = 9 },
        .{ .name = "dictionary_linked_l12", .input = dictionary_payload, .dictionary = dictionary, .block_mode = .linked, .level = 12 },
    };

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.print(
        "case,reference_version,block_mode,level,input_bytes,input_sha256,dictionary_bytes,encoded_bytes,iterations,vort_ns,reference_ns,vort_mib_s,reference_mib_s,vort_over_reference,compressed_ratio,checksum,{s}\n",
        .{benchmark_provenance.csv_columns},
    );
    for (cases) |case| {
        const reference = try encodeReference(runtime, init.gpa, case);
        defer init.gpa.free(reference);
        const encoded = try encodeVort(init.gpa, case);
        defer init.gpa.free(encoded);
        if (!std.mem.eql(u8, reference, encoded)) return error.Lz4ProbeMismatch;
        const samples = try measurePaired(init.io, init.gpa, runtime, case, options.iterations);
        const vort_mib_s = mibPerSecond(case.input.len * options.iterations, samples.vort.elapsed_ns);
        const reference_mib_s = mibPerSecond(case.input.len * options.iterations, samples.reference.elapsed_ns);
        try csv.writer.print(
            "{s},{s},{s},{d},{d},{s},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.4},{d:.6},{d}",
            .{
                case.name,
                runtime.version(),
                @tagName(case.block_mode),
                case.level,
                case.input.len,
                &benchmark_provenance.sha256Hex(case.input),
                if (case.dictionary) |dict| dict.content.len else 0,
                encoded.len,
                options.iterations,
                samples.vort.elapsed_ns,
                samples.reference.elapsed_ns,
                vort_mib_s,
                reference_mib_s,
                vort_mib_s / reference_mib_s,
                @as(f64, @floatFromInt(encoded.len)) / @as(f64, @floatFromInt(case.input.len)),
                samples.vort.checksum +% samples.reference.checksum,
            },
        );
        try provenance.writeCsvFields(&csv.writer);
        try csv.writer.writeByte('\n');
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

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
        } else if (std.mem.eql(u8, arg, "--csv")) {
            options.csv_path = args.next() orelse return error.MissingCorpusPath;
        } else return error.UnknownArgument;
    }
    if (options.iterations == 0) return error.InvalidBlockPlan;
    return options;
}

fn encodeVort(allocator: std.mem.Allocator, case: Case) ![]u8 {
    const options = vort.Lz4HcFrameOptions{
        .include_content_size = false,
        .content_checksum = true,
        .block_checksum = true,
        .block_size_id = .max64kb,
        .block_mode = case.block_mode,
        .dictionary_id = if (case.dictionary) |dict| dict.id else null,
        .compression_level = case.level,
    };
    return if (case.dictionary) |dict|
        vort.lz4EncodeHcFrameWithDictionaryAlloc(allocator, case.input, options, dict)
    else
        vort.lz4EncodeHcFrameAlloc(allocator, case.input, options);
}

fn encodeReference(runtime: liblz4.Runtime, allocator: std.mem.Allocator, case: Case) ![]u8 {
    const options = liblz4.FrameOptions{
        .include_content_size = false,
        .content_checksum = true,
        .block_checksum = true,
        .block_size_id = 4,
        .block_independent = case.block_mode == .independent,
        .compression_level = case.level,
        .dictionary_id = if (case.dictionary) |dict| dict.id else 0,
    };
    return if (case.dictionary) |dict|
        runtime.encodeFrameWithDictionaryAlloc(allocator, case.input, dict.content, options)
    else
        runtime.encodeFrameAlloc(allocator, case.input, options);
}

fn measurePaired(io: std.Io, allocator: std.mem.Allocator, runtime: liblz4.Runtime, case: Case, iterations: usize) !PairedSample {
    var best: PairedSample = .{
        .vort = Sample{ .elapsed_ns = std.math.maxInt(u64), .checksum = 0 },
        .reference = Sample{ .elapsed_ns = std.math.maxInt(u64), .checksum = 0 },
    };
    for (0..3) |round| {
        const vort_first = round & 1 == 0;
        for (0..2) |position| {
            const use_vort = if (position == 0) vort_first else !vort_first;
            const sample = try measureOne(io, allocator, runtime, case, iterations, use_vort);
            const target = if (use_vort) &best.vort else &best.reference;
            if (sample.elapsed_ns < target.elapsed_ns) target.* = sample;
        }
    }
    return best;
}

fn measureOne(io: std.Io, allocator: std.mem.Allocator, runtime: liblz4.Runtime, case: Case, iterations: usize, use_vort: bool) !Sample {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = if (use_vort)
            try encodeVort(allocator, case)
        else
            try encodeReference(runtime, allocator, case);
        checksum +%= encoded.len;
        if (encoded.len != 0) checksum +%= encoded[0] + encoded[encoded.len - 1];
        allocator.free(encoded);
    }
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return .{ .elapsed_ns = if (ns <= 0) 0 else @intCast(ns), .checksum = checksum };
}

fn makeLinkedPayload(allocator: std.mem.Allocator) ![]u8 {
    const payload = try allocator.alloc(u8, 300 * 1024);
    fillRandomish(payload[0 .. 60 * 1024], 0x6d2b_79f5);
    for (60 * 1024..payload.len) |index| payload[index] = payload[index - 60 * 1024];
    return payload;
}

fn makeDictionaryPayload(allocator: std.mem.Allocator, dictionary: []const u8) ![]u8 {
    const payload = try allocator.alloc(u8, 192 * 1024);
    @memcpy(payload[0 .. dictionary.len - 1], dictionary[1..]);
    payload[dictionary.len - 1] = dictionary[0] ^ 0xa5;
    for (dictionary.len..payload.len) |index| payload[index] = payload[index - dictionary.len];
    return payload;
}

fn fillRandomish(output: []u8, seed: u32) void {
    var state = seed;
    for (output) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0;
    return (@as(f64, @floatFromInt(bytes)) / (1024 * 1024)) /
        (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}
