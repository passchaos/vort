const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");
const benchmark_provenance = @import("benchmark_provenance");

const Case = struct { name: []const u8, payload: []const u8, level: c_int = 1 };
const max_file_input_size = 256 * 1024 * 1024;
const Options = struct {
    iterations: usize = 1000,
    only_case: ?[]const u8 = null,
    csv_path: ?[]const u8 = null,
    input_path: ?[]const u8 = null,
    encoded_input_path: ?[]const u8 = null,
    input_name: ?[]const u8 = null,
    input_level: c_int = 1,
    reusable: bool = false,
    reference_library_path: ?[]const u8 = null,
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
        return try runCases(
            init,
            runtime,
            &.{.{ .name = name, .payload = payload, .level = options.input_level }},
            options,
            provenance,
            encoded_input,
        );
    }
    if (options.input_name != null or options.encoded_input_path != null or options.input_level != 1)
        return error.MissingCorpusPath;

    var numbered_json: std.ArrayList(u8) = .empty;
    defer numbered_json.deinit(init.gpa);
    for (0..20) |index| {
        var line: [96]u8 = undefined;
        const formatted = try std.fmt.bufPrint(&line, "{{\"k\":\"{d:0>4}\",\"n\":{d},\"txt\":\"abcdefghijklmnopqrstuvwxyz0123456789\"}}\n", .{ index, index });
        try numbered_json.appendSlice(init.gpa, formatted);
    }
    const huffman_payload = try init.gpa.alloc(u8, 80_000);
    defer init.gpa.free(huffman_payload);
    const huffman_alphabet = "ACGTN";
    for (huffman_payload, 0..) |*byte, index| byte.* = huffman_alphabet[(index * 17 + index / 7 + index / 31) % huffman_alphabet.len];
    const ascii_payload = try init.gpa.alloc(u8, 64 * 1024);
    defer init.gpa.free(ascii_payload);
    var ascii_state: u32 = 31;
    for (ascii_payload) |*byte| {
        ascii_state = ascii_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast(32 + ((ascii_state >> 16) % 95));
    }
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
        .{ .name = "numbered_json", .payload = numbered_json.items },
        .{ .name = "huffman80k", .payload = huffman_payload },
        .{ .name = "ascii64k", .payload = ascii_payload, .level = 9 },
        .{ .name = "large_json", .payload = large_json.items },
        .{ .name = "binary_mixed", .payload = binary_mixed },
    };

    try runCases(init, runtime, &cases, options, provenance, null);
}

fn runCases(
    init: std.process.Init,
    runtime: libzstd.Runtime,
    cases: []const Case,
    options: Options,
    provenance: benchmark_provenance.Info,
    encoded_input: ?[]const u8,
) !void {
    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.print("case,api_mode,input_bytes,input_sha256,encoded_bytes,iterations,vort_ns,vort_mib_s,checksum,reusable_sequence_table_hits,reusable_huffman_tree_hits,block_count,compressed_blocks,literals_kind,sequence_count,ll_mode,of_mode,ml_mode,sequence_blocks,compressed_table_modes,no_low_probability_tables,low_probability_tables,repeat_table_modes,rle_table_modes,predefined_table_modes,fse_accuracy_log_histogram,no_low_fse_accuracy_log_histogram,total_sequences,literal_bytes,match_bytes,zero_literal_sequences,overlapping_matches,overlapping_match_bytes,non_overlapping_matches,non_overlapping_match_bytes,vector32_eligible_matches,vector32_eligible_bytes,match_length_histogram,offset_histogram,medium_length_histogram,{s}\n", .{benchmark_provenance.csv_columns});
    var selected: usize = 0;
    for (cases) |case| {
        if (options.only_case) |wanted| if (!std.mem.eql(u8, wanted, case.name)) continue;
        selected += 1;
        const generated = if (encoded_input == null)
            try runtime.encodeAlloc(init.gpa, case.payload, case.level)
        else
            null;
        defer if (generated) |encoded| init.gpa.free(encoded);
        const encoded = encoded_input orelse generated.?;
        const output = try init.gpa.alloc(u8, case.payload.len);
        defer init.gpa.free(output);
        const written = try vort.zstdDecodeFrameInto(encoded, output);
        if (written != case.payload.len or !std.mem.eql(u8, case.payload, output)) return error.SizeMismatch;
        var decoder = vort.ZstdNativeFrameDecoder.init(init.gpa);
        defer decoder.deinit();
        if (options.reusable) {
            const reused = try decoder.decodeIntoSlice(encoded, output);
            if (reused != case.payload.len or !std.mem.eql(u8, case.payload, output)) return error.SizeMismatch;
        }
        const sequence_hits_before = decoder.reusableSequenceTableHitCount();
        const huffman_hits_before = decoder.reusableHuffmanTreeHitCount();
        const block = try vort.zstdInspectNativeFrameFirstBlock(encoded);
        const shape = try vort.zstdInspectNativeFrameBlockSequenceModes(encoded, block);
        const summary = try vort.zstdSummarizeNativeFrameBlocks(encoded);
        const copy_profile = try vort.zstd.benchmarkNativeSequenceCopyProfile(encoded);
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(init.io);
        if (options.reusable) {
            for (0..options.iterations) |_| {
                mix +%= try decoder.decodeIntoSlice(encoded, output);
                if (output.len != 0) mix +%= output[0];
            }
        } else {
            for (0..options.iterations) |_| {
                mix +%= try vort.zstdDecodeFrameInto(encoded, output);
                if (output.len != 0) mix +%= output[0];
            }
        }
        const elapsed_ns = elapsedNs(init.io, start);
        const sequence_hits = decoder.reusableSequenceTableHitCount() - sequence_hits_before;
        const huffman_hits = decoder.reusableHuffmanTreeHitCount() - huffman_hits_before;
        const input_sha256 = benchmark_provenance.sha256Hex(case.payload);
        try csv.writer.print("{s},{s},{d},{s},{d},{d},{d},{d:.2},{d}", .{
            case.name,
            if (options.reusable) "reusable" else "one-shot",
            case.payload.len,
            &input_sha256,
            encoded.len,
            options.iterations,
            elapsed_ns,
            mibPerSecond(case.payload.len * options.iterations, elapsed_ns),
            mix,
        });
        try csv.writer.print(",{d},{d},{d},{d},{s},{d},{s},{s},{s}", .{
            sequence_hits,
            huffman_hits,
            summary.block_count,
            summary.compressed_block_count,
            @tagName(shape.literals_kind),
            shape.sequence_count,
            @tagName(shape.literal_length_mode),
            @tagName(shape.offset_mode),
            @tagName(shape.match_length_mode),
        });
        try csv.writer.print(",{d},{d},{d},{d},{d},{d},{d},", .{
            copy_profile.sequence_block_count,
            copy_profile.compressed_table_modes,
            copy_profile.no_low_probability_tables,
            copy_profile.low_probability_tables,
            copy_profile.repeat_table_modes,
            copy_profile.rle_table_modes,
            copy_profile.predefined_table_modes,
        });
        try writeHistogram(&csv.writer, &copy_profile.fse_accuracy_log_histogram);
        try csv.writer.writeByte(',');
        try writeHistogram(&csv.writer, &copy_profile.no_low_fse_accuracy_log_histogram);
        try csv.writer.print(",{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},", .{
            copy_profile.sequence_count,
            copy_profile.literal_bytes,
            copy_profile.match_bytes,
            copy_profile.zero_literal_sequences,
            copy_profile.overlapping_matches,
            copy_profile.overlapping_match_bytes,
            copy_profile.non_overlapping_matches,
            copy_profile.non_overlapping_match_bytes,
            copy_profile.vector32_eligible_matches,
            copy_profile.vector32_eligible_bytes,
        });
        try writeHistogram(&csv.writer, &copy_profile.match_length_histogram);
        try csv.writer.writeByte(',');
        try writeHistogram(&csv.writer, &copy_profile.offset_histogram);
        try csv.writer.writeByte(',');
        try writeHistogram(&csv.writer, &copy_profile.medium_length_histogram);
        try provenance.writeCsvFields(&csv.writer);
        try csv.writer.writeByte('\n');
    }
    if (selected == 0) return error.InvalidBlockPlan;
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [1024]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn writeHistogram(writer: *std.Io.Writer, histogram: []const usize) !void {
    for (histogram, 0..) |count, index| {
        if (index != 0) try writer.writeByte(';');
        try writer.print("{d}", .{count});
    }
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations"))
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--case"))
            options.only_case = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--csv"))
            options.csv_path = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--input"))
            options.input_path = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--encoded-input"))
            options.encoded_input_path = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--name"))
            options.input_name = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--level"))
            options.input_level = try std.fmt.parseInt(c_int, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--reusable"))
            options.reusable = true
        else if (std.mem.eql(u8, arg, "--libzstd"))
            options.reference_library_path = args.next() orelse return error.MissingCorpusPath
        else
            return error.UnknownArgument;
    }
    if (options.iterations == 0) return error.InvalidBlockPlan;
    return options;
}

fn elapsedNs(io: std.Io, start: std.Io.Timestamp) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0;
    return (@as(f64, @floatFromInt(bytes)) / (1024 * 1024)) / (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}
