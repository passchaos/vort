const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");
const benchmark_provenance = @import("benchmark_provenance");

const Case = struct {
    name: []const u8,
    payload: []const u8,
    quality: c_int = 0,
    iteration_divisor: usize = 1,
    size_requires_alloc: bool = false,
};
const Sample = struct { elapsed_ns: u64, mix: u64 };
const Options = struct {
    iterations: usize = 1000,
    csv_path: ?[]const u8 = null,
    only_case: ?[]const u8 = null,
    input_path: ?[]const u8 = null,
    input_name: ?[]const u8 = null,
    quality_override: ?c_int = null,
    print_encoded_hex: bool = false,
    vort_only: bool = false,
};
const max_file_input_size = 256 * 1024 * 1024;

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
    var runtime = try libbrotli.Runtime.open();
    defer runtime.deinit();
    const dictionary_cases = if (options.vort_only) 0 else try checkDictionaryTransforms(runtime);
    var random: [4096]u8 = undefined;
    var state: u32 = 0x1234_5678;
    for (&random) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 16);
    }
    const clustered = try makeClusteredPayload(init.io, init.gpa);
    defer init.gpa.free(clustered);
    const cases = [_]Case{
        .{ .name = "tiny", .payload = "hello brotli" },
        .{ .name = "text", .payload = "Brotli benchmark text payload. " ** 1024 },
        .{ .name = "structured", .payload = "{\"service\":\"vort\",\"codec\":\"brotli\",\"value\":12345}\n" ** 512 },
        .{ .name = "repetitive", .payload = ("abcdefghijklmnopqrstuvwxyz012345" ** 4) ** 256 },
        .{ .name = "random4k", .payload = &random },
        .{ .name = "text_q3", .payload = "Brotli benchmark text payload. " ** 1024, .quality = 3 },
        .{ .name = "structured_q3", .payload = "{\"service\":\"vort\",\"codec\":\"brotli\",\"value\":12345}\n" ** 512, .quality = 3 },
        .{ .name = "repetitive_q3", .payload = ("abcdefghijklmnopqrstuvwxyz012345" ** 4) ** 256, .quality = 3 },
        .{ .name = "structured_q4", .payload = "{\"service\":\"vort\",\"codec\":\"brotli\",\"value\":12345}\n" ** 512, .quality = 4 },
        .{ .name = "text_q11", .payload = "Brotli benchmark text payload. " ** 1024, .quality = 11 },
        .{ .name = "structured_q11", .payload = "{\"service\":\"vort\",\"codec\":\"brotli\",\"value\":12345}\n" ** 512, .quality = 11 },
        .{ .name = "repetitive_q11", .payload = ("abcdefghijklmnopqrstuvwxyz012345" ** 4) ** 256, .quality = 11 },
        // This synthetic but deterministic source shape forces libbrotli's
        // clustering path to retain dozens of literal and distance trees. It
        // keeps compressed-header optimizations honest without making the
        // regular gate run 1 MiB payloads at the full small-case iteration count.
        .{ .name = "clustered_q8", .payload = clustered, .quality = 8, .iteration_divisor = 10, .size_requires_alloc = true },
    };

    var file_payload: ?[]u8 = null;
    defer if (file_payload) |payload| init.gpa.free(payload);
    var file_case: [1]Case = undefined;
    const selected_cases: []const Case = if (options.input_path) |path| blk: {
        if (options.only_case != null) return error.InvalidCaseSelection;
        const payload = try std.Io.Dir.cwd().readFileAlloc(
            init.io,
            path,
            init.gpa,
            .limited(max_file_input_size),
        );
        file_payload = payload;
        if (payload.len == 0) return error.InputTooSmall;
        const name = options.input_name orelse std.fs.path.basename(path);
        if (name.len == 0 or std.mem.indexOfAny(u8, name, ",\r\n") != null)
            return error.InvalidCaseName;
        file_case[0] = .{
            .name = name,
            .payload = payload,
            .quality = options.quality_override orelse 0,
            .size_requires_alloc = true,
        };
        break :blk &file_case;
    } else blk: {
        if (options.input_name != null) return error.MissingCorpusPath;
        break :blk &cases;
    };

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    const writer = &csv.writer;
    if (options.vort_only) {
        try writer.writeAll("case,input_bytes,encoded_bytes,iterations,vort_ns,vort_mib_s,checksum\n");
    } else try writer.print("case,reference_version,input_bytes,input_sha256,encoded_bytes,iterations,vort_ns,reference_ns,vort_mib_s,reference_mib_s,vort_over_reference,checksum,size_ns,alloc_ns,exact_alloc_ns,dictionary_cases,static_dictionary_copies,static_dictionary_bytes,lz77_copies,lz77_bytes,non_overlapping_lz77_copies,non_overlapping_lz77_bytes,short_non_overlapping_lz77_copies,short_non_overlapping_lz77_bytes,literal_lsb6_bytes,literal_msb6_bytes,literal_utf8_bytes,literal_signed_bytes,max_literal_context_trees,max_command_block_types,max_distance_context_trees,{s}\n", .{benchmark_provenance.csv_columns});
    for (selected_cases) |case| {
        if (options.only_case) |wanted| {
            if (!std.mem.eql(u8, wanted, case.name)) continue;
        }
        const encoded = try runtime.encodeAlloc(init.gpa, case.payload, options.quality_override orelse case.quality);
        defer init.gpa.free(encoded);
        const iterations = @max(1, options.iterations / case.iteration_divisor);
        if (options.print_encoded_hex) {
            var stderr_buffer: [4096]u8 = undefined;
            var stderr = std.Io.File.stderr().writerStreaming(init.io, &stderr_buffer);
            for (encoded) |byte| try stderr.interface.print("{x:0>2}", .{byte});
            try stderr.interface.writeByte('\n');
            try stderr.interface.flush();
        }
        const vort_output = try init.gpa.alloc(u8, case.payload.len);
        defer init.gpa.free(vort_output);
        const reference_output = try init.gpa.alloc(u8, case.payload.len);
        defer init.gpa.free(reference_output);
        const written = try vort.brDecodeStreamInto(encoded, vort_output);
        if (written != case.payload.len or !std.mem.eql(u8, case.payload, vort_output)) return error.SizeMismatch;
        try runtime.decode(encoded, reference_output);
        if (!std.mem.eql(u8, case.payload, reference_output)) return error.SizeMismatch;
        if (options.vort_only) {
            const sample = try measure(init.io, .vort, runtime, encoded, vort_output, iterations);
            try writer.print("{s},{d},{d},{d},{d},{d:.2},{d}\n", .{ case.name, case.payload.len, encoded.len, iterations, sample.elapsed_ns, mibPerSecond(case.payload.len * iterations, sample.elapsed_ns), sample.mix });
            continue;
        }
        const summary = try vort.brSummarizeStreamAlloc(init.gpa, encoded);
        const vort_sample = try measure(init.io, .vort, runtime, encoded, vort_output, iterations);
        const reference_sample = try measure(init.io, .reference, runtime, encoded, reference_output, iterations);
        const size_sample = if (case.size_requires_alloc)
            try measureSizeAlloc(init.io, init.gpa, encoded, iterations)
        else
            try measureSize(init.io, encoded, iterations);
        const alloc_sample = try measureAlloc(init.io, init.gpa, encoded, iterations);
        const exact_sample = try measureExactAlloc(init.io, init.gpa, encoded, case.payload.len, iterations);
        const vort_mib_s = mibPerSecond(case.payload.len * iterations, vort_sample.elapsed_ns);
        const reference_mib_s = mibPerSecond(case.payload.len * iterations, reference_sample.elapsed_ns);
        const input_sha256 = benchmark_provenance.sha256Hex(case.payload);
        try writer.print(
            "{s},{x},{d},{s},{d},{d},{d},{d},{d:.2},{d:.2},{d:.4},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}",
            .{ case.name, runtime.version(), case.payload.len, &input_sha256, encoded.len, iterations, vort_sample.elapsed_ns, reference_sample.elapsed_ns, vort_mib_s, reference_mib_s, vort_mib_s / reference_mib_s, vort_sample.mix +% reference_sample.mix, size_sample.elapsed_ns, alloc_sample.elapsed_ns, exact_sample.elapsed_ns, dictionary_cases, summary.static_dictionary_copy_count, summary.static_dictionary_bytes, summary.lz77_copy_count, summary.lz77_copy_bytes, summary.non_overlapping_lz77_copy_count, summary.non_overlapping_lz77_copy_bytes, summary.short_non_overlapping_lz77_copy_count, summary.short_non_overlapping_lz77_copy_bytes, summary.literal_context_mode_bytes[0], summary.literal_context_mode_bytes[1], summary.literal_context_mode_bytes[2], summary.literal_context_mode_bytes[3], summary.max_literal_context_trees, summary.max_command_block_types, summary.max_distance_context_trees },
        );
        try provenance.writeCsvFields(writer);
        try writer.writeByte('\n');
    }
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var stdout_buffer: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn makeClusteredPayload(io: std.Io, allocator: std.mem.Allocator) ![]u8 {
    const dictionary = try std.Io.Dir.cwd().readFileAlloc(io, "src/br/dictionary.bin", allocator, .limited(128 * 1024));
    defer allocator.free(dictionary);
    const payload = try allocator.alloc(u8, 1024 * 1024);
    for (payload, 0..) |*byte, i| {
        const segment = i / 1024;
        const base = (segment * 3571) % dictionary.len;
        byte.* = dictionary[(base + i % 1024) % dictionary.len];
    }
    return payload;
}

fn checkDictionaryTransforms(runtime: libbrotli.Runtime) !usize {
    var native: [64]u8 = undefined;
    var reference: [64]u8 = undefined;
    var cases: usize = 0;
    for (4..25) |word_len| {
        const bits = vort.br.fullStaticDictionarySizeBits(word_len) orelse return error.SizeMismatch;
        const word_count = @as(usize, 1) << @intCast(bits);
        const indices = [_]usize{ 0, 1, word_count / 3, word_count / 2, word_count - 1 };
        for (indices) |word_index| {
            for (0..121) |transform_index| {
                const address = (transform_index << @intCast(bits)) | word_index;
                const actual = vort.br.transformStaticDictionaryWord(address, word_len, &native) orelse return error.SizeMismatch;
                const expected = try runtime.transformDictionary(address, word_len, &reference);
                if (!std.mem.eql(u8, actual, expected)) return error.SizeMismatch;
                cases += 1;
            }
        }
    }
    return cases;
}

fn measureAlloc(io: std.Io, allocator: std.mem.Allocator, encoded: []const u8, iterations: usize) !Sample {
    var best = Sample{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            const decoded = try vort.brDecodeStreamAlloc(allocator, encoded);
            defer allocator.free(decoded);
            mix +%= decoded.len;
        }
        const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
        const elapsed: u64 = if (ns <= 0) 0 else @intCast(ns);
        if (elapsed < best.elapsed_ns) best = .{ .elapsed_ns = elapsed, .mix = mix };
    }
    return best;
}

fn measureExactAlloc(io: std.Io, allocator: std.mem.Allocator, encoded: []const u8, expected_len: usize, iterations: usize) !Sample {
    var best = Sample{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            const decoded = try vort.brDecodeStreamAllocExactSize(allocator, encoded, expected_len);
            defer allocator.free(decoded);
            mix +%= decoded.len;
        }
        const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
        const elapsed: u64 = if (ns <= 0) 0 else @intCast(ns);
        if (elapsed < best.elapsed_ns) best = .{ .elapsed_ns = elapsed, .mix = mix };
    }
    return best;
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
        } else if (std.mem.eql(u8, arg, "--csv")) {
            options.csv_path = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--case")) {
            options.only_case = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--input")) {
            options.input_path = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--name")) {
            options.input_name = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--quality")) {
            options.quality_override = try std.fmt.parseInt(c_int, args.next() orelse return error.MissingLimit, 10);
        } else if (std.mem.eql(u8, arg, "--print-encoded-hex")) {
            options.print_encoded_hex = true;
        } else if (std.mem.eql(u8, arg, "--vort-only")) {
            options.vort_only = true;
        } else return error.UnknownArgument;
    }
    if (options.iterations == 0) return error.InvalidBlockPlan;
    return options;
}

fn measureSize(io: std.Io, encoded: []const u8, iterations: usize) !Sample {
    var best = Sample{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| mix +%= try vort.brDecodedStreamSize(encoded);
        const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
        const elapsed: u64 = if (ns <= 0) 0 else @intCast(ns);
        if (elapsed < best.elapsed_ns) best = .{ .elapsed_ns = elapsed, .mix = mix };
    }
    return best;
}

fn measureSizeAlloc(io: std.Io, allocator: std.mem.Allocator, encoded: []const u8, iterations: usize) !Sample {
    var best = Sample{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| mix +%= (try vort.brSummarizeStreamAlloc(allocator, encoded)).decoded_bytes;
        const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
        const elapsed: u64 = if (ns <= 0) 0 else @intCast(ns);
        if (elapsed < best.elapsed_ns) best = .{ .elapsed_ns = elapsed, .mix = mix };
    }
    return best;
}

const Codec = enum { vort, reference };

fn measure(io: std.Io, codec: Codec, runtime: libbrotli.Runtime, encoded: []const u8, output: []u8, iterations: usize) !Sample {
    var best = Sample{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            switch (codec) {
                .vort => mix +%= try vort.brDecodeStreamInto(encoded, output),
                .reference => {
                    try runtime.decode(encoded, output);
                    mix +%= output.len;
                },
            }
            if (output.len != 0) mix +%= output[0];
        }
        const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
        const elapsed: u64 = if (ns <= 0) 0 else @intCast(ns);
        if (elapsed < best.elapsed_ns) best = .{ .elapsed_ns = elapsed, .mix = mix };
    }
    return best;
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0;
    return (@as(f64, @floatFromInt(bytes)) / (1024 * 1024)) /
        (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}
