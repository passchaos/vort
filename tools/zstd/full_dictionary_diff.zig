const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");

fn skewedText(comptime seed: u32, comptime len: usize) [len]u8 {
    @setEvalBranchQuota(10_000);
    var bytes: [len]u8 = undefined;
    var state = seed;
    for (&bytes) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        const bucket: u8 = @truncate(state >> 24);
        byte.* = switch (bucket) {
            0...71 => ' ',
            72...115 => 'e',
            116...147 => 't',
            148...173 => 'a',
            174...195 => 'o',
            196...211 => 'i',
            212...224 => 'n',
            else => 'a' + @as(u8, @truncate(state % 26)),
        };
    }
    return bytes;
}

const literal_training_a = skewedText(0x243f_6a88, 384);
const literal_training_b = skewedText(0x85a3_08d3, 384);
const literal_training_c = skewedText(0x1319_8a2e, 384);
const entropy_payload = skewedText(0x0370_7344, 1024);

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingCorpusPath;
    const generated_path = args.next();
    if (args.next() != null) return error.InvalidBlockPlan;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(1 << 20));
    defer init.gpa.free(bytes);
    const parsed = try vort.ZstdNativeDictionary.initFromStandardDictionary(bytes);
    const training_samples = [_][]const u8{ &literal_training_a, &literal_training_b, &literal_training_c };
    const payload = &entropy_payload;
    var runtime = try libzstd.Runtime.open();
    defer runtime.deinit();
    var trained_size: usize = 0;
    var baseline_size: usize = 0;
    var trained_sequence_entropy_len: usize = 0;

    if (generated_path) |output_path| {
        const generated_id = if (parsed.view.id == std.math.maxInt(u32)) 1 else parsed.view.id + 1;
        const trained_id = if (generated_id == std.math.maxInt(u32)) 1 else generated_id + 1;
        const generated = try vort.zstdStandardDictionaryFromContentAlloc(
            init.gpa,
            parsed.view.content,
            generated_id,
        );
        defer generated.deinit(init.gpa);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = generated.bytes });
        const generated_dictionary = generated.asDictionary();
        const generated_encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(init.gpa, payload, .{ .content_checksum = false }, generated_dictionary);
        defer init.gpa.free(generated_encoded.frame);
        var generated_output: [payload.len]u8 = undefined;
        try runtime.decodeUsingDict(generated_encoded.frame, &generated_output, generated.bytes);
        if (!std.mem.eql(u8, payload, &generated_output)) return error.SizeMismatch;
        const generated_reference = try runtime.encodeUsingDictAlloc(init.gpa, payload, generated.bytes, 1);
        defer init.gpa.free(generated_reference);
        const generated_decoded = try vort.zstdDecodeFrameAllocWithDictionary(init.gpa, generated_reference, generated_dictionary);
        defer init.gpa.free(generated_decoded);
        if (!std.mem.eql(u8, payload, generated_decoded)) return error.SizeMismatch;

        const trained = try vort.zstdTrainStandardDictionaryAlloc(
            init.gpa,
            &training_samples,
            .{ .target_size = 8 },
            trained_id,
        );
        defer trained.deinit(init.gpa);
        const trained_baseline = try vort.zstdStandardDictionaryFromContentAlloc(
            init.gpa,
            trained.view.content,
            trained.view.id,
        );
        defer trained_baseline.deinit(init.gpa);
        const trained_summary = try vort.zstdSummarizeStandardDictionary(trained.bytes);
        if (trained_summary.huffman_symbol_count != 256) return error.InvalidDictionaryMetadata;
        if (trained_summary.offset_accuracy_log != 8 or
            trained_summary.match_accuracy_log != 9 or
            trained_summary.literal_accuracy_log != 9) return error.InvalidDictionaryMetadata;
        trained_sequence_entropy_len = trained_summary.sequence_entropy_len;
        const trained_dictionary = trained.asDictionary();
        const trained_vort = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(init.gpa, payload, .{ .content_checksum = false }, trained_dictionary);
        defer init.gpa.free(trained_vort.frame);
        var trained_output: [payload.len]u8 = undefined;
        try runtime.decodeUsingDict(trained_vort.frame, &trained_output, trained.bytes);
        if (!std.mem.eql(u8, payload, &trained_output)) return error.SizeMismatch;
        const trained_reference = try runtime.encodeUsingDictAlloc(init.gpa, payload, trained.bytes, 1);
        defer init.gpa.free(trained_reference);
        const trained_baseline_reference = try runtime.encodeUsingDictAlloc(init.gpa, payload, trained_baseline.bytes, 1);
        defer init.gpa.free(trained_baseline_reference);
        const trained_decoded = try vort.zstdDecodeFrameAllocWithDictionary(init.gpa, trained_reference, trained_dictionary);
        defer init.gpa.free(trained_decoded);
        if (!std.mem.eql(u8, payload, trained_decoded)) return error.SizeMismatch;
        if (trained_reference.len >= trained_baseline_reference.len) return error.CompressionRegression;
        trained_size = trained_reference.len;
        baseline_size = trained_baseline_reference.len;
    }

    const vort_encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(init.gpa, payload, .{ .content_checksum = false }, parsed.dictionary);
    defer init.gpa.free(vort_encoded.frame);
    var output: [payload.len]u8 = undefined;
    try runtime.decodeUsingDict(vort_encoded.frame, &output, bytes);
    if (!std.mem.eql(u8, payload, &output)) return error.SizeMismatch;
    const reference_encoded = try runtime.encodeUsingDictAlloc(init.gpa, payload, bytes, 1);
    defer init.gpa.free(reference_encoded);
    const decoded = try vort.zstdDecodeFrameAllocWithDictionary(init.gpa, reference_encoded, parsed.dictionary);
    defer init.gpa.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.SizeMismatch;
    const other = vort.ZstdNativeDictionary.init(parsed.dictionary.id + 1, "other dictionary");
    const dictionary_set = vort.ZstdNativeDictionarySet.init(&.{ other, parsed.dictionary });
    const stream_summary = try vort.zstdSummarizeNativeStreamWithDictionarySet(reference_encoded, dictionary_set);
    if (stream_summary.resolved_dictionary_frame_count != 1 or stream_summary.standard_dictionary_frame_count != 1) return error.InvalidDictionaryMetadata;
    const single_summary = try vort.zstdSummarizeNativeStreamWithDictionary(reference_encoded, parsed.dictionary);
    if (single_summary.standard_dictionary_frame_count != 1) return error.InvalidDictionaryMetadata;
    const set_decoded = try vort.zstdDecodeFrameAllocWithDictionarySet(init.gpa, reference_encoded, dictionary_set);
    defer init.gpa.free(set_decoded);
    if (!std.mem.eql(u8, payload, set_decoded)) return error.SizeMismatch;
    const split = reference_encoded.len / 2;
    const chunks = [_][]const u8{ reference_encoded[0..split], reference_encoded[split..] };
    const compressed_scratch = try init.gpa.alloc(u8, reference_encoded.len);
    defer init.gpa.free(compressed_scratch);
    const chunked = try vort.zstdDecodeFrameChunksAllocWithDictionarySet(init.gpa, &chunks, compressed_scratch, dictionary_set);
    defer init.gpa.free(chunked);
    if (!std.mem.eql(u8, payload, chunked)) return error.SizeMismatch;
    var incremental = vort.ZstdNativeIncrementalFrameDecoder.initWithDictionaryAndOptions(init.gpa, parsed.dictionary, .{ .expected_output_len = payload.len });
    defer incremental.deinit();
    var incremental_output: [payload.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (output_offset < payload.len) {
        const input_end = @min(reference_encoded.len, input_offset + 3);
        const output_end = @min(payload.len, output_offset + 5);
        const result = try incremental.step(reference_encoded[input_offset..input_end], incremental_output[output_offset..output_end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        if (result.status == .done) break;
    }
    try incremental.finish();
    if (!std.mem.eql(u8, payload, &incremental_output)) return error.SizeMismatch;
    var set_incremental = vort.ZstdNativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(init.gpa, dictionary_set, .{ .expected_output_len = payload.len });
    defer set_incremental.deinit();
    var set_output: [payload.len]u8 = undefined;
    const set_step = try set_incremental.step(reference_encoded, &set_output);
    if (set_step.progress.output_written != payload.len) return error.SizeMismatch;
    try set_incremental.finish();
    if (!std.mem.eql(u8, payload, &set_output)) return error.SizeMismatch;

    var buffer: [384]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print(
        "zstd_full_dictionary_diff=ok version={s} id={d} vort={d} reference={d} generated={s} trained={d} baseline={d} sequence_entropy={d}\n",
        .{ runtime.version(), parsed.view.id, vort_encoded.frame.len, reference_encoded.len, if (generated_path == null) "no" else "yes", trained_size, baseline_size, trained_sequence_entropy_len },
    );
    try stdout.interface.flush();
}
