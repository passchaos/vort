const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");

const Case = struct {
    name: []const u8,
    payload: []const u8,
    level: c_int = 1,
};

const Row = struct {
    case_name: []const u8,
    reference_version: []const u8,
    input_bytes: usize,
    encoded_bytes: usize,
    iterations: usize,
    vort_ns: u64,
    reference_ns: u64,
    vort_mib_s: f64,
    reference_mib_s: f64,
    vort_over_reference: f64,
    checksum: u64,
    block_count: usize,
    raw_blocks: usize,
    rle_blocks: usize,
    compressed_blocks: usize,
    first_block_type: []const u8,
    literals_kind: []const u8,
    sequence_count: usize,
    ll_mode: []const u8,
    of_mode: []const u8,
    ml_mode: []const u8,
    header_inspect_ns: u64,
    block_inspect_ns: u64,
    sequence_inspect_ns: u64,
    alloc_ns: u64,
    alloc_mib_s: f64,
    into_over_alloc: f64,
};

const Options = struct {
    iterations: usize = 5000,
    csv_path: ?[]const u8 = null,
    only_case: ?[]const u8 = null,
};

const Sample = struct { elapsed_ns: u64, mix: u64 };
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
    var runtime = try libzstd.Runtime.open();
    defer runtime.deinit();
    const raw_large_payload = try init.gpa.alloc(u8, 256 * 1024);
    defer init.gpa.free(raw_large_payload);
    fillIncompressible(raw_large_payload, 0x9e37_79b9);
    var numbered_json: std.ArrayList(u8) = .empty;
    defer numbered_json.deinit(init.gpa);
    for (0..20) |index| {
        var line: [96]u8 = undefined;
        const formatted = try std.fmt.bufPrint(
            &line,
            "{{\"k\":\"{d:0>4}\",\"n\":{d},\"txt\":\"abcdefghijklmnopqrstuvwxyz0123456789\"}}\n",
            .{ index, index },
        );
        try numbered_json.appendSlice(init.gpa, formatted);
    }
    const huffman_payload = try init.gpa.alloc(u8, 80_000);
    defer init.gpa.free(huffman_payload);
    const huffman_alphabet = "ACGTN";
    for (huffman_payload, 0..) |*byte, index| {
        byte.* = huffman_alphabet[(index * 17 + index / 7 + index / 31) % huffman_alphabet.len];
    }
    const ascii_payload = try init.gpa.alloc(u8, 64 * 1024);
    defer init.gpa.free(ascii_payload);
    var ascii_state: u32 = 31;
    for (ascii_payload) |*byte| {
        ascii_state = ascii_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast(32 + ((ascii_state >> 16) % 95));
    }

    const cases = [_]Case{
        .{ .name = "tiny", .payload = "hello zstd" },
        .{
            .name = "text",
            .payload = "Zstandard benchmark text payload. " ** 1024,
        },
        .{
            .name = "structured",
            .payload = "{\"service\":\"vort\",\"codec\":\"zstd\",\"value\":12345}\n" ** 768,
        },
        .{
            .name = "repetitive",
            .payload = ("abcdefghijklmnopqrstuvwxyz012345" ** 4) ** 256,
        },
        .{ .name = "incompressible", .payload = &incompressible_payload },
        .{ .name = "rle64k", .payload = &rle_payload },
        .{ .name = "raw256k", .payload = raw_large_payload },
        .{ .name = "numbered_json", .payload = numbered_json.items },
        .{ .name = "huffman80k", .payload = huffman_payload },
        .{ .name = "ascii64k", .payload = ascii_payload, .level = 9 },
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
    try writeCsv(&csv.writer, rows.items);
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(
            init.io,
            .{ .sub_path = path, .data = csv.written() },
        );
    } else {
        var buffer: [1024]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
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
            options.csv_path = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--case")) {
            options.only_case = args.next() orelse return error.MissingCorpusPath;
        } else return error.UnknownArgument;
    }
    if (options.iterations == 0) return error.InvalidBlockPlan;
    return options;
}

fn measureCase(
    init: std.process.Init,
    runtime: libzstd.Runtime,
    case: Case,
    iterations: usize,
) !Row {
    const encoded = try runtime.encodeAlloc(init.gpa, case.payload, case.level);
    defer init.gpa.free(encoded);
    const summary = try vort.zstdSummarizeNativeFrameBlocks(encoded);
    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded);
    const sequence_summary =
        try vort.zstdInspectNativeFrameBlockSequenceModes(
            encoded,
            first_block,
        );
    const vort_output = try init.gpa.alloc(u8, case.payload.len);
    defer init.gpa.free(vort_output);
    const reference_output = try init.gpa.alloc(u8, case.payload.len);
    defer init.gpa.free(reference_output);

    const written = try vort.zstdDecodeFrameInto(encoded, vort_output);
    if (written != case.payload.len) return error.SizeMismatch;
    try runtime.decode(encoded, reference_output);
    if (!std.mem.eql(u8, case.payload, vort_output) or
        !std.mem.eql(u8, case.payload, reference_output))
    {
        return error.SizeMismatch;
    }
    const alloc_output = try vort.zstdDecodeFrameAlloc(init.gpa, encoded);
    defer init.gpa.free(alloc_output);
    if (!std.mem.eql(u8, case.payload, alloc_output)) return error.SizeMismatch;

    const vort_sample = try measureRepeated(
        init.io,
        .vort,
        runtime,
        encoded,
        vort_output,
        iterations,
    );
    const alloc_sample = try measureAllocRepeated(
        init.io,
        init.gpa,
        encoded,
        case.payload.len,
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
    const header_inspect = try measureInspect(
        init.io,
        .header,
        encoded,
        iterations,
    );
    const block_inspect = try measureInspect(
        init.io,
        .block,
        encoded,
        iterations,
    );
    const sequence_inspect = try measureInspect(
        init.io,
        .sequence,
        encoded,
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
        .encoded_bytes = encoded.len,
        .iterations = iterations,
        .vort_ns = vort_sample.elapsed_ns,
        .reference_ns = reference_sample.elapsed_ns,
        .vort_mib_s = vort_mib_s,
        .reference_mib_s = reference_mib_s,
        .vort_over_reference = vort_mib_s / reference_mib_s,
        .checksum = vort_sample.mix +% reference_sample.mix,
        .block_count = summary.block_count,
        .raw_blocks = summary.raw_block_count,
        .rle_blocks = summary.rle_block_count,
        .compressed_blocks = summary.compressed_block_count,
        .first_block_type = @tagName(first_block.block_type),
        .literals_kind = @tagName(sequence_summary.literals_kind),
        .sequence_count = sequence_summary.sequence_count,
        .ll_mode = @tagName(sequence_summary.literal_length_mode),
        .of_mode = @tagName(sequence_summary.offset_mode),
        .ml_mode = @tagName(sequence_summary.match_length_mode),
        .header_inspect_ns = header_inspect.elapsed_ns,
        .block_inspect_ns = block_inspect.elapsed_ns,
        .sequence_inspect_ns = sequence_inspect.elapsed_ns,
        .alloc_ns = alloc_sample.elapsed_ns,
        .alloc_mib_s = mibPerSecond(case.payload.len * iterations, alloc_sample.elapsed_ns),
        .into_over_alloc = @as(f64, @floatFromInt(alloc_sample.elapsed_ns)) /
            @as(f64, @floatFromInt(vort_sample.elapsed_ns)),
    };
}

const Codec = enum { vort, reference };
const InspectStage = enum { header, block, sequence };

fn measureRepeated(
    io: std.Io,
    codec: Codec,
    runtime: libzstd.Runtime,
    encoded: []const u8,
    output: []u8,
    iterations: usize,
) !Sample {
    var best = Sample{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            switch (codec) {
                .vort => mix +%= try vort.zstdDecodeFrameInto(encoded, output),
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

fn measureAllocRepeated(
    io: std.Io,
    allocator: std.mem.Allocator,
    encoded: []const u8,
    expected_len: usize,
    iterations: usize,
) !Sample {
    var best = Sample{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            const decoded = try vort.zstdDecodeFrameAlloc(allocator, encoded);
            defer allocator.free(decoded);
            if (decoded.len != expected_len) return error.SizeMismatch;
            mix +%= decoded.len;
            if (decoded.len != 0) mix +%= decoded[0];
        }
        const elapsed_ns = elapsedNs(io, start);
        if (elapsed_ns < best.elapsed_ns) {
            best = .{ .elapsed_ns = elapsed_ns, .mix = mix };
        }
    }
    return best;
}

fn measureInspect(
    io: std.Io,
    stage: InspectStage,
    encoded: []const u8,
    iterations: usize,
) !Sample {
    var best = Sample{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            switch (stage) {
                .header => {
                    const header = try vort.zstdInspectNativeFrameHeader(encoded);
                    mix +%= header.payload_offset + header.block_size_max;
                },
                .block => {
                    const block = try vort.zstdInspectNativeFrameFirstBlock(encoded);
                    mix +%= block.payload_offset + block.payload_len;
                },
                .sequence => {
                    const block = try vort.zstdInspectNativeFrameFirstBlock(encoded);
                    const summary = try vort.zstdInspectNativeFrameBlockSequenceModes(
                        encoded,
                        block,
                    );
                    mix +%= summary.regenerated_literals_size + summary.sequence_count;
                },
            }
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

fn writeCsv(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll(
        "case,reference_version,input_bytes,encoded_bytes,iterations,vort_ns,reference_ns,vort_mib_s,reference_mib_s,vort_over_reference,checksum,block_count,raw_blocks,rle_blocks,compressed_blocks,first_block_type,literals_kind,sequence_count,ll_mode,of_mode,ml_mode,header_inspect_ns,block_inspect_ns,sequence_inspect_ns,alloc_ns,alloc_mib_s,into_over_alloc\n",
    );
    for (rows) |row| {
        try writer.print(
            "{s},{s},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.4},{d},{d},{d},{d},{d},{s},{s},{d},{s},{s},{s},{d},{d},{d},{d},{d:.2},{d:.4}\n",
            .{
                row.case_name,
                row.reference_version,
                row.input_bytes,
                row.encoded_bytes,
                row.iterations,
                row.vort_ns,
                row.reference_ns,
                row.vort_mib_s,
                row.reference_mib_s,
                row.vort_over_reference,
                row.checksum,
                row.block_count,
                row.raw_blocks,
                row.rle_blocks,
                row.compressed_blocks,
                row.first_block_type,
                row.literals_kind,
                row.sequence_count,
                row.ll_mode,
                row.of_mode,
                row.ml_mode,
                row.header_inspect_ns,
                row.block_inspect_ns,
                row.sequence_inspect_ns,
                row.alloc_ns,
                row.alloc_mib_s,
                row.into_over_alloc,
            },
        );
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

fn fillIncompressible(out: []u8, seed: u32) void {
    var state = seed;
    for (out) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 16);
    }
}
