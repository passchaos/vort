const std = @import("std");
const vort = @import("vort");
const liblz4 = @import("liblz4_runtime.zig");
const benchmark_provenance = @import("benchmark_provenance");

const Case = struct {
    name: []const u8,
    payload: []const u8,
};

const Row = struct {
    case_name: []const u8,
    reference_version: []const u8,
    input_bytes: usize,
    input_sha256: [std.crypto.hash.sha2.Sha256.digest_length * 2]u8,
    encoded_bytes: usize,
    vort_encoded_bytes: usize,
    iterations: usize,
    vort_ns: u64,
    reference_ns: u64,
    vort_mib_s: f64,
    reference_mib_s: f64,
    vort_over_reference: f64,
    checksum: u64,
    literal_count: usize,
    literal_bytes: usize,
    match_count: usize,
    match_bytes: usize,
    vort_literal_count: usize,
    vort_literal_bytes: usize,
    vort_match_count: usize,
    vort_match_bytes: usize,
};

const Options = struct {
    iterations: usize = 5000,
    csv_path: ?[]const u8 = null,
    only_case: ?[]const u8 = null,
};

const Sample = struct {
    elapsed_ns: u64,
    mix: u64,
};

const incompressible_payload = incompressiblePayload();
const rle_payload = [_]u8{0} ** (64 * 1024);

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(
        init.minimal.args,
        init.gpa,
    );
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
    var runtime = try liblz4.Runtime.open();
    defer runtime.deinit();
    const incompressible_large = try init.gpa.alloc(u8, 256 * 1024);
    defer init.gpa.free(incompressible_large);
    var large_state: u32 = 0x6d2b_79f5;
    for (incompressible_large) |*byte| {
        large_state = large_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(large_state >> 16);
    }

    const cases = [_]Case{
        .{ .name = "tiny", .payload = "hello lz4" },
        .{
            .name = "text",
            .payload = "LZ4 benchmark text payload. " ** 1024,
        },
        .{
            .name = "structured",
            .payload = "{\"service\":\"vort\",\"codec\":\"lz4\",\"value\":12345}\n" ** 768,
        },
        .{
            .name = "repetitive",
            .payload = ("abcdefghijklmnopqrstuvwxyz012345" ** 4) ** 256,
        },
        .{ .name = "incompressible", .payload = &incompressible_payload },
        .{ .name = "incompressible256k", .payload = incompressible_large },
        .{ .name = "rle64k", .payload = &rle_payload },
    };

    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(init.gpa);
    for (&cases) |case| {
        if (options.only_case) |wanted| {
            if (!std.mem.eql(u8, wanted, case.name)) continue;
        }
        try rows.append(
            init.gpa,
            try measureCase(init, runtime, case, options.iterations),
        );
    }

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try writeCsv(&csv.writer, rows.items, provenance);
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(
            init.io,
            .{ .sub_path = path, .data = csv.written() },
        );
    } else {
        var buffer: [1024]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(
            init.io,
            &buffer,
        );
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            options.iterations = try std.fmt.parseInt(
                usize,
                args.next() orelse return error.MissingLimit,
                10,
            );
        } else if (std.mem.eql(u8, arg, "--csv")) {
            options.csv_path =
                args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--case")) {
            options.only_case =
                args.next() orelse return error.MissingCorpusPath;
        } else {
            return error.UnknownArgument;
        }
    }
    if (options.iterations == 0) return error.InvalidBlockPlan;
    return options;
}

fn measureCase(
    init: std.process.Init,
    runtime: liblz4.Runtime,
    case: Case,
    iterations: usize,
) !Row {
    const encoded = try runtime.encodeAlloc(init.gpa, case.payload);
    defer init.gpa.free(encoded);
    const vort_encoded = try vort.lz4EncodeBlockAlloc(
        init.gpa,
        case.payload,
    );
    defer init.gpa.free(vort_encoded);
    const summary = try vort.lz4SummarizeBlock(encoded);
    const vort_summary = try vort.lz4SummarizeBlock(vort_encoded);
    const vort_output = try init.gpa.alloc(u8, case.payload.len);
    defer init.gpa.free(vort_output);
    const reference_output = try init.gpa.alloc(u8, case.payload.len);
    defer init.gpa.free(reference_output);

    const vort_written = try vort.lz4DecodeBlockIntoSlice(
        encoded,
        vort_output,
        case.payload.len,
    );
    if (vort_written != case.payload.len) return error.SizeMismatch;
    try runtime.decode(encoded, reference_output);
    if (!std.mem.eql(u8, case.payload, vort_output) or
        !std.mem.eql(u8, case.payload, reference_output))
    {
        return error.SizeMismatch;
    }
    // Differentially require the production Vort encoder to emit blocks that
    // the reference safe decoder accepts, not merely blocks that Vort's more
    // permissive decoder can round-trip.
    try runtime.decode(vort_encoded, reference_output);
    if (!std.mem.eql(u8, case.payload, reference_output)) {
        return error.SizeMismatch;
    }

    const vort_sample = try measureRepeated(
        init.io,
        .vort,
        runtime,
        encoded,
        vort_output,
        iterations,
    );
    const reference_sample = try measureRepeated(
        init.io,
        .reference,
        runtime,
        encoded,
        reference_output,
        iterations,
    );
    const vort_mib_s = mibPerSecond(
        case.payload.len * iterations,
        vort_sample.elapsed_ns,
    );
    const reference_mib_s = mibPerSecond(
        case.payload.len * iterations,
        reference_sample.elapsed_ns,
    );
    return .{
        .case_name = case.name,
        .reference_version = runtime.version(),
        .input_bytes = case.payload.len,
        .input_sha256 = benchmark_provenance.sha256Hex(case.payload),
        .encoded_bytes = encoded.len,
        .vort_encoded_bytes = vort_encoded.len,
        .iterations = iterations,
        .vort_ns = vort_sample.elapsed_ns,
        .reference_ns = reference_sample.elapsed_ns,
        .vort_mib_s = vort_mib_s,
        .reference_mib_s = reference_mib_s,
        .vort_over_reference = vort_mib_s / reference_mib_s,
        .checksum = vort_sample.mix +% reference_sample.mix,
        .literal_count = summary.literal_count,
        .literal_bytes = summary.literal_bytes,
        .match_count = summary.match_count,
        .match_bytes = summary.match_bytes,
        .vort_literal_count = vort_summary.literal_count,
        .vort_literal_bytes = vort_summary.literal_bytes,
        .vort_match_count = vort_summary.match_count,
        .vort_match_bytes = vort_summary.match_bytes,
    };
}

const Codec = enum { vort, reference };

fn measureRepeated(
    io: std.Io,
    codec: Codec,
    runtime: liblz4.Runtime,
    encoded: []const u8,
    output: []u8,
    iterations: usize,
) !Sample {
    var best = Sample{
        .elapsed_ns = std.math.maxInt(u64),
        .mix = 0,
    };
    for (0..5) |_| {
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            switch (codec) {
                .vort => {
                    const written = try vort.lz4DecodeBlockIntoSlice(
                        encoded,
                        output,
                        output.len,
                    );
                    mix +%= written;
                },
                .reference => {
                    try runtime.decode(encoded, output);
                    mix +%= output.len;
                },
            }
            if (output.len != 0) mix +%= output[0];
        }
        const elapsed_ns = elapsedNs(io, start);
        if (elapsed_ns < best.elapsed_ns) {
            best = .{ .elapsed_ns = elapsed_ns, .mix = mix };
        }
    }
    return best;
}

fn elapsedNs(io: std.Io, start: std.Io.Timestamp) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0;
    const mib = @as(f64, @floatFromInt(bytes)) / (1024 * 1024);
    return mib / (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}

fn writeCsv(
    writer: *std.Io.Writer,
    rows: []const Row,
    provenance: benchmark_provenance.Info,
) !void {
    try writer.print(
        "case,reference_version,input_bytes,input_sha256,encoded_bytes,vort_encoded_bytes,iterations,vort_ns,reference_ns,vort_mib_s,reference_mib_s,vort_over_reference,checksum,literal_count,literal_bytes,match_count,match_bytes,vort_literal_count,vort_literal_bytes,vort_match_count,vort_match_bytes,{s}\n",
        .{benchmark_provenance.csv_columns},
    );
    for (rows) |row| {
        try writer.print(
            "{s},{s},{d},{s},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.4},{d},{d},{d},{d},{d},{d},{d},{d},{d}",
            .{
                row.case_name,
                row.reference_version,
                row.input_bytes,
                &row.input_sha256,
                row.encoded_bytes,
                row.vort_encoded_bytes,
                row.iterations,
                row.vort_ns,
                row.reference_ns,
                row.vort_mib_s,
                row.reference_mib_s,
                row.vort_over_reference,
                row.checksum,
                row.literal_count,
                row.literal_bytes,
                row.match_count,
                row.match_bytes,
                row.vort_literal_count,
                row.vort_literal_bytes,
                row.vort_match_count,
                row.vort_match_bytes,
            },
        );
        try provenance.writeCsvFields(writer);
        try writer.writeByte('\n');
    }
}

fn incompressiblePayload() [1024]u8 {
    @setEvalBranchQuota(4096);
    var out: [1024]u8 = undefined;
    var state: u32 = 0x1234_5678;
    for (&out) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 16);
    }
    return out;
}
