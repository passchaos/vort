const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");
const benchmark_provenance = @import("benchmark_provenance");

const Case = struct {
    name: []const u8,
    payload: []const u8,
    level: c_int = 1,
};

const Row = struct {
    case_name: []const u8,
    reference_version: []const u8,
    vort_api: []const u8,
    reference_api: []const u8,
    input_bytes: usize,
    input_sha256: [std.crypto.hash.sha2.Sha256.digest_length * 2]u8,
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
    regenerated_literals_size: usize,
    sequence_count: usize,
    total_sequence_count: usize,
    total_literal_bytes: usize,
    total_match_bytes: usize,
    ll_mode: []const u8,
    of_mode: []const u8,
    ml_mode: []const u8,
    header_inspect_ns: u64,
    block_inspect_ns: u64,
    sequence_inspect_ns: u64,
    alloc_ns: u64,
    alloc_mib_s: f64,
    into_over_alloc: f64,
    input_mod128: usize,
    output_mod128: usize,
    reference_output_mod128: usize,
};

const AddressLayout = struct {
    input_offset: ?usize = null,
    output_offset: ?usize = null,
};

const Options = struct {
    iterations: usize = 5000,
    csv_path: ?[]const u8 = null,
    only_case: ?[]const u8 = null,
    input_path: ?[]const u8 = null,
    encoded_input_path: ?[]const u8 = null,
    input_name: ?[]const u8 = null,
    input_level: c_int = 1,
    reusable: bool = false,
    reference_library_path: ?[]const u8 = null,
    layout: AddressLayout = .{},
};

const Sample = struct { elapsed_ns: u64, mix: u64 };
const max_file_input_size = 256 * 1024 * 1024;
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
    const provenance = try benchmark_provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer provenance.deinit(init.gpa);
    var runtime = if (options.reference_library_path) |path|
        try libzstd.Runtime.openPath(path)
    else
        try libzstd.Runtime.open();
    defer runtime.deinit();

    if (options.input_path) |path| {
        if (options.only_case != null) return error.InvalidCaseSelection;
        const payload = try std.Io.Dir.cwd().readFileAlloc(
            init.io,
            path,
            init.gpa,
            .limited(max_file_input_size),
        );
        defer init.gpa.free(payload);
        if (payload.len == 0) return error.InputTooSmall;
        const encoded_input = if (options.encoded_input_path) |encoded_path|
            try std.Io.Dir.cwd().readFileAlloc(
                init.io,
                encoded_path,
                init.gpa,
                .limited(max_file_input_size),
            )
        else
            null;
        defer if (encoded_input) |encoded| init.gpa.free(encoded);
        if (encoded_input) |encoded| if (encoded.len == 0) return error.InputTooSmall;
        const name = options.input_name orelse std.fs.path.basename(path);
        if (name.len == 0 or std.mem.indexOfAny(u8, name, ",\r\n") != null)
            return error.InvalidCaseName;
        const row = try measureCase(init, runtime, .{
            .name = name,
            .payload = payload,
            .level = options.input_level,
        }, options.iterations, options.reusable, encoded_input, options.layout);
        return try writeOutput(init, options.csv_path, &.{row}, provenance);
    }
    if (options.input_name != null or options.encoded_input_path != null or options.input_level != 1)
        return error.MissingCorpusPath;

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
    const large_text = try init.gpa.alloc(u8, 512 * 1024);
    defer init.gpa.free(large_text);
    const text_unit = "Vort large Zstandard corpus line with words, punctuation, and repeated structure.\n";
    for (large_text, 0..) |*byte, index| byte.* = text_unit[index % text_unit.len];
    var large_json: std.ArrayList(u8) = .empty;
    defer large_json.deinit(init.gpa);
    while (large_json.items.len < 512 * 1024) {
        var line: [128]u8 = undefined;
        const index = large_json.items.len / 64;
        const formatted = try std.fmt.bufPrint(&line, "{{\"id\":{d},\"service\":\"vort\",\"message\":\"structured zstd corpus payload\"}}\n", .{index});
        try large_json.appendSlice(init.gpa, formatted);
    }
    const binary_mixed = try init.gpa.alloc(u8, 512 * 1024);
    defer init.gpa.free(binary_mixed);
    var binary_state: u32 = 0xfeed_beef;
    for (binary_mixed, 0..) |*byte, index| {
        binary_state = binary_state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(binary_state >> 16);
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
        .{ .name = "large_text", .payload = large_text },
        .{ .name = "large_json", .payload = large_json.items },
        .{ .name = "binary_mixed", .payload = binary_mixed },
    };

    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(init.gpa);
    for (&cases) |case| {
        if (options.only_case) |wanted| {
            if (!std.mem.eql(u8, wanted, case.name)) continue;
        }
        try rows.append(
            init.gpa,
            try measureCase(init, runtime, case, options.iterations, options.reusable, null, options.layout),
        );
    }

    try writeOutput(init, options.csv_path, rows.items, provenance);
}

fn writeOutput(
    init: std.process.Init,
    csv_path: ?[]const u8,
    rows: []const Row,
    provenance: benchmark_provenance.Info,
) !void {
    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try writeCsv(&csv.writer, rows, provenance);
    if (csv_path) |path| {
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
        } else if (std.mem.eql(u8, arg, "--input")) {
            options.input_path = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--encoded-input")) {
            options.encoded_input_path = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--name")) {
            options.input_name = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--level")) {
            options.input_level = try std.fmt.parseInt(
                c_int,
                args.next() orelse return error.MissingLimit,
                10,
            );
        } else if (std.mem.eql(u8, arg, "--reusable")) {
            options.reusable = true;
        } else if (std.mem.eql(u8, arg, "--libzstd")) {
            options.reference_library_path = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--input-offset")) {
            options.layout.input_offset = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
        } else if (std.mem.eql(u8, arg, "--output-offset")) {
            options.layout.output_offset = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
        } else return error.UnknownArgument;
    }
    if (options.iterations == 0) return error.InvalidBlockPlan;
    if ((options.layout.input_offset orelse 0) >= 128 or
        (options.layout.output_offset orelse 0) >= 128) return error.InvalidAddressOffset;
    return options;
}

fn measureCase(
    init: std.process.Init,
    runtime: libzstd.Runtime,
    case: Case,
    iterations: usize,
    reusable: bool,
    encoded_input: ?[]const u8,
    layout: AddressLayout,
) !Row {
    const generated = if (encoded_input == null)
        try runtime.encodeAlloc(init.gpa, case.payload, case.level)
    else
        null;
    defer if (generated) |encoded| init.gpa.free(encoded);
    const original_encoded = encoded_input orelse generated.?;
    const shifted_input = if (layout.input_offset) |offset|
        try init.gpa.alignedAlloc(u8, .fromByteUnits(128), original_encoded.len + offset)
    else
        null;
    defer if (shifted_input) |allocation| init.gpa.free(allocation);
    const encoded = if (shifted_input) |allocation| shifted: {
        const bytes = allocation[layout.input_offset.?..];
        @memcpy(bytes, original_encoded);
        break :shifted bytes;
    } else original_encoded;
    const summary = try vort.zstdSummarizeNativeFrameBlocks(encoded);
    const first_block = try vort.zstdInspectNativeFrameFirstBlock(encoded);
    const sequence_summary =
        try vort.zstdInspectNativeFrameBlockSequenceModes(
            encoded,
            first_block,
        );
    const copy_profile = try vort.zstd.benchmarkNativeSequenceCopyProfile(encoded);
    const output_offset = layout.output_offset orelse 0;
    const vort_storage = if (layout.output_offset != null)
        try init.gpa.alignedAlloc(u8, .fromByteUnits(128), case.payload.len + output_offset)
    else
        try init.gpa.alloc(u8, case.payload.len);
    defer if (layout.output_offset != null)
        init.gpa.free(@as([]align(128) u8, @alignCast(vort_storage)))
    else
        init.gpa.free(vort_storage);
    const reference_storage = if (layout.output_offset != null)
        try init.gpa.alignedAlloc(u8, .fromByteUnits(128), case.payload.len + output_offset)
    else
        try init.gpa.alloc(u8, case.payload.len);
    defer if (layout.output_offset != null)
        init.gpa.free(@as([]align(128) u8, @alignCast(reference_storage)))
    else
        init.gpa.free(reference_storage);
    const vort_output = vort_storage[output_offset..];
    const reference_output = reference_storage[output_offset..];

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

    const paired = if (reusable) blk: {
        var decoder = vort.ZstdNativeFrameDecoder.init(init.gpa);
        defer decoder.deinit();
        const reference_context = runtime.create_dctx() orelse return error.ReferenceUnavailable;
        defer _ = runtime.free_dctx(reference_context);
        @memset(vort_output, 0xa5);
        @memset(reference_output, 0x5a);
        const warmed = try decoder.decodeIntoSlice(encoded, vort_output);
        if (warmed != case.payload.len) return error.SizeMismatch;
        try runtime.decodeWithContext(reference_context, encoded, reference_output);
        if (!std.mem.eql(u8, case.payload, vort_output) or
            !std.mem.eql(u8, case.payload, reference_output)) return error.SizeMismatch;
        break :blk try measurePairedRepeated(
            true,
            init.io,
            runtime,
            encoded,
            vort_output,
            reference_output,
            iterations,
            &decoder,
            reference_context,
        );
    } else try measurePairedRepeated(false, init.io, runtime, encoded, vort_output, reference_output, iterations, null, null);
    const vort_sample = paired.vort;
    const reference_sample = paired.reference;
    if (!std.mem.eql(u8, case.payload, vort_output) or
        !std.mem.eql(u8, case.payload, reference_output)) return error.SizeMismatch;
    const alloc_sample = try measureAllocRepeated(
        init.io,
        init.gpa,
        encoded,
        case.payload.len,
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
        .vort_api = if (reusable) "NativeFrameDecoder.decodeIntoSlice" else "decodeFrameInto",
        .reference_api = if (reusable) "ZSTD_decompressDCtx" else "ZSTD_decompress",
        .input_bytes = case.payload.len,
        .input_sha256 = benchmark_provenance.sha256Hex(case.payload),
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
        .regenerated_literals_size = sequence_summary.regenerated_literals_size,
        .sequence_count = sequence_summary.sequence_count,
        .total_sequence_count = copy_profile.sequence_count,
        .total_literal_bytes = copy_profile.literal_bytes,
        .total_match_bytes = copy_profile.match_bytes,
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
        .input_mod128 = @intFromPtr(encoded.ptr) % 128,
        .output_mod128 = @intFromPtr(vort_output.ptr) % 128,
        .reference_output_mod128 = @intFromPtr(reference_output.ptr) % 128,
    };
}

const Codec = enum { vort, reference };
const InspectStage = enum { header, block, sequence };
const PairedSample = struct { vort: Sample, reference: Sample };

fn measurePairedRepeated(
    comptime reusable: bool,
    io: std.Io,
    runtime: libzstd.Runtime,
    encoded: []const u8,
    vort_output: []u8,
    reference_output: []u8,
    iterations: usize,
    decoder: ?*vort.ZstdNativeFrameDecoder,
    reference_context: ?*anyopaque,
) !PairedSample {
    var best = PairedSample{
        .vort = .{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 },
        .reference = .{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 },
    };
    for (0..5) |round| {
        const order = if (round & 1 == 0)
            [_]Codec{ .vort, .reference }
        else
            [_]Codec{ .reference, .vort };
        for (order) |codec| {
            const output = if (codec == .vort) vort_output else reference_output;
            const sample = try measureRepeatedOnce(reusable, io, codec, runtime, encoded, output, iterations, decoder, reference_context);
            const current = if (codec == .vort) &best.vort else &best.reference;
            if (sample.elapsed_ns < current.elapsed_ns) current.* = sample;
        }
    }
    return best;
}

fn measureRepeatedOnce(
    comptime reusable: bool,
    io: std.Io,
    codec: Codec,
    runtime: libzstd.Runtime,
    encoded: []const u8,
    output: []u8,
    iterations: usize,
    decoder: ?*vort.ZstdNativeFrameDecoder,
    reference_context: ?*anyopaque,
) !Sample {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        switch (codec) {
            .vort => mix +%= if (reusable)
                try decoder.?.decodeIntoSlice(encoded, output)
            else
                try vort.zstdDecodeFrameInto(encoded, output),
            .reference => {
                if (reusable)
                    try runtime.decodeWithContext(reference_context.?, encoded, output)
                else
                    try runtime.decode(encoded, output);
                mix +%= output.len;
            },
        }
        if (output.len != 0) mix +%= output[0];
    }
    const elapsed_ns = elapsedNs(io, start);
    return .{ .elapsed_ns = elapsed_ns, .mix = mix };
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

fn writeCsv(writer: *std.Io.Writer, rows: []const Row, provenance: benchmark_provenance.Info) !void {
    try writer.print(
        "case,reference_version,vort_api,reference_api,input_bytes,input_sha256,encoded_bytes,iterations,vort_ns,reference_ns,vort_mib_s,reference_mib_s,vort_over_reference,checksum,block_count,raw_blocks,rle_blocks,compressed_blocks,first_block_type,literals_kind,regenerated_literals_size,sequence_count,total_sequence_count,total_literal_bytes,total_match_bytes,ll_mode,of_mode,ml_mode,header_inspect_ns,block_inspect_ns,sequence_inspect_ns,alloc_ns,alloc_mib_s,into_over_alloc,input_mod128,output_mod128,reference_output_mod128,{s}\n",
        .{benchmark_provenance.csv_columns},
    );
    for (rows) |row| {
        try writer.print("{s},{s},{s},{s},", .{ row.case_name, row.reference_version, row.vort_api, row.reference_api });
        try writer.print(
            "{d},{s},{d},{d},{d},{d},{d:.2},{d:.2},{d:.4},{d},{d},{d},{d},{d},{s},{s},{d},{d},{d},{d},{d},{s},{s},{s},{d},{d},{d},{d},{d:.2},{d:.4}",
            .{
                row.input_bytes,
                &row.input_sha256,
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
                row.regenerated_literals_size,
                row.sequence_count,
                row.total_sequence_count,
                row.total_literal_bytes,
                row.total_match_bytes,
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
        try writer.print(",{d},{d},{d}", .{ row.input_mod128, row.output_mod128, row.reference_output_mod128 });
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

fn fillIncompressible(out: []u8, seed: u32) void {
    var state = seed;
    for (out) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 16);
    }
}
