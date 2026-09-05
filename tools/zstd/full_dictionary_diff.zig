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

fn skewedBinary(comptime seed: u32, comptime len: usize) [len]u8 {
    @setEvalBranchQuota(10_000);
    var bytes: [len]u8 = undefined;
    var state = seed;
    for (&bytes) |*byte| {
        state = state *% 22_695_477 +% 1;
        const bucket: u8 = @truncate(state >> 24);
        byte.* = switch (bucket) {
            0...95 => 0,
            96...143 => 0xff,
            144...175 => 1,
            176...199 => 2,
            else => @truncate(state),
        };
    }
    return bytes;
}

const literal_training_a = skewedText(0x243f_6a88, 384);
const literal_training_b = skewedText(0x85a3_08d3, 384);
const literal_training_c = skewedText(0x1319_8a2e, 384);
const entropy_payload = skewedText(0x0370_7344, 1024);
const structured_training_a =
    "{\"kind\":\"event\",\"service\":\"vort\",\"region\":\"us-east-1\",\"status\":\"ok\",\"message\":\"alpha\"}\n" ** 6;
const structured_training_b =
    "{\"kind\":\"event\",\"service\":\"vort\",\"region\":\"eu-west-1\",\"status\":\"warn\",\"message\":\"beta\"}\n" ** 6;
const structured_training_c =
    "{\"kind\":\"metric\",\"service\":\"vort\",\"region\":\"ap-south-1\",\"status\":\"ok\",\"message\":\"gamma\"}\n" ** 6;
const structured_payload =
    "{\"kind\":\"event\",\"service\":\"vort\",\"region\":\"us-west-2\",\"status\":\"ok\",\"message\":\"delta\"}\n" ** 12;
const binary_training_a = skewedBinary(0xa409_3822, 384);
const binary_training_b = skewedBinary(0x299f_31d0, 384);
const binary_training_c = skewedBinary(0x082e_fa98, 384);
const binary_payload = skewedBinary(0xec4e_6c89, 1024);
const selector_training = [_][]const u8{
    "service=vort region=west status=ok message=alpha alpha alpha",
    "service=vort region=east status=ok message=beta beta beta",
    "service=vort region=north status=warn message=gamma gamma",
};
const selector_payload =
    "service=vort region=south status=ok message=alpha beta\n" ++
    "alpha alpha alpha beta gamma service=vort\n" ++
    "region=west status=warn message=gamma alpha\n" ++
    "message=beta beta beta status=ok\n";

const DictionaryCaseResult = struct {
    trained_size: usize,
    baseline_size: usize,
    sequence_entropy_len: usize,
};

const SelectorCaseResult = struct { baseline_size: usize, selected_size: usize };

fn nextDictionaryId(id: u32) u32 {
    return if (id == std.math.maxInt(u32)) 1 else id + 1;
}

fn verifyCustomRepcodes(
    allocator: std.mem.Allocator,
    runtime: libzstd.Runtime,
    source: vort.ZstdOwnedStandardDictionary,
    payload: []const u8,
) !void {
    const bytes = try allocator.dupe(u8, source.bytes);
    defer allocator.free(bytes);
    const repcodes = [3]u32{ 9, 5, 2 };
    const repcode_offset = source.view.content_offset - repcodes.len * @sizeOf(u32);
    for (repcodes, 0..) |repcode, i|
        std.mem.writeInt(u32, bytes[repcode_offset + i * 4 ..][0..4], repcode, .little);
    const parsed = try vort.ZstdNativeDictionary.initFromStandardDictionary(bytes);
    if (!std.meta.eql(parsed.view.repcodes, repcodes)) return error.InvalidDictionaryMetadata;

    const vort_encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(
        allocator,
        payload,
        .{ .content_checksum = false },
        parsed.dictionary,
    );
    defer allocator.free(vort_encoded.frame);
    const reference_output = try allocator.alloc(u8, payload.len);
    defer allocator.free(reference_output);
    try runtime.decodeUsingDict(vort_encoded.frame, reference_output, bytes);
    if (!std.mem.eql(u8, payload, reference_output)) return error.SizeMismatch;

    const reference_encoded = try runtime.encodeUsingDictAlloc(allocator, payload, bytes, 1);
    defer allocator.free(reference_encoded);
    const decoded = try vort.zstdDecodeFrameAllocWithDictionary(allocator, reference_encoded, parsed.dictionary);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.SizeMismatch;
}

fn compareValidatedHistorySelector(
    allocator: std.mem.Allocator,
    runtime: libzstd.Runtime,
    dictionary_id: u32,
) !SelectorCaseResult {
    const options: vort.ZstdDictionaryTrainOptions = .{ .target_size = 64, .max_phrases = 64 };
    const baseline = try vort.zstdTrainStandardDictionaryAlloc(allocator, &selector_training, options, dictionary_id);
    defer baseline.deinit(allocator);
    const selected = try vort.zstdTrainValidatedStandardDictionaryAlloc(
        allocator,
        &selector_training,
        &.{selector_payload},
        options,
        nextDictionaryId(dictionary_id),
    );
    defer selected.deinit(allocator);
    if (std.mem.eql(u8, baseline.view.content, selected.view.content)) return error.InvalidDictionaryTraining;
    const baseline_encoded = try runtime.encodeUsingDictAlloc(allocator, selector_payload, baseline.bytes, 1);
    defer allocator.free(baseline_encoded);
    const selected_encoded = try runtime.encodeUsingDictAlloc(allocator, selector_payload, selected.bytes, 1);
    defer allocator.free(selected_encoded);
    const decoded = try vort.zstdDecodeFrameAllocWithDictionary(allocator, selected_encoded, selected.asDictionary());
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, selector_payload, decoded)) return error.SizeMismatch;
    if (selected_encoded.len > baseline_encoded.len) return error.CompressionRegression;
    return .{ .baseline_size = baseline_encoded.len, .selected_size = selected_encoded.len };
}

fn compareTrainedDictionaryCase(
    allocator: std.mem.Allocator,
    runtime: libzstd.Runtime,
    samples: []const []const u8,
    payload: []const u8,
    dictionary_id: u32,
) !DictionaryCaseResult {
    const trained = try vort.zstdTrainValidatedStandardDictionaryAlloc(
        allocator,
        samples,
        &.{payload},
        .{ .target_size = 8 },
        dictionary_id,
    );
    defer trained.deinit(allocator);
    const baseline = try vort.zstdStandardDictionaryFromContentAlloc(
        allocator,
        trained.view.content,
        trained.view.id,
    );
    defer baseline.deinit(allocator);
    const summary = try vort.zstdSummarizeStandardDictionary(trained.bytes);
    if (summary.huffman_symbol_count != 256 or
        summary.offset_accuracy_log != 8 or
        summary.match_accuracy_log != 9 or
        summary.literal_accuracy_log != 9 or
        summary.sequence_entropy_len == 0) return error.InvalidDictionaryMetadata;

    const dictionary = trained.asDictionary();
    const vort_encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, .{ .content_checksum = false }, dictionary);
    defer allocator.free(vort_encoded.frame);
    const reference_output = try allocator.alloc(u8, payload.len);
    defer allocator.free(reference_output);
    try runtime.decodeUsingDict(vort_encoded.frame, reference_output, trained.bytes);
    if (!std.mem.eql(u8, payload, reference_output)) return error.SizeMismatch;

    const reference_encoded = try runtime.encodeUsingDictAlloc(allocator, payload, trained.bytes, 1);
    defer allocator.free(reference_encoded);
    const baseline_encoded = try runtime.encodeUsingDictAlloc(allocator, payload, baseline.bytes, 1);
    defer allocator.free(baseline_encoded);
    const decoded = try vort.zstdDecodeFrameAllocWithDictionary(allocator, reference_encoded, dictionary);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.SizeMismatch;
    return .{
        .trained_size = reference_encoded.len,
        .baseline_size = baseline_encoded.len,
        .sequence_entropy_len = summary.sequence_entropy_len,
    };
}

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
    const text_training = [_][]const u8{ &literal_training_a, &literal_training_b, &literal_training_c };
    const structured_training = [_][]const u8{ structured_training_a, structured_training_b, structured_training_c };
    const binary_training = [_][]const u8{ &binary_training_a, &binary_training_b, &binary_training_c };
    const payload = &entropy_payload;
    var runtime = try libzstd.Runtime.open();
    defer runtime.deinit();
    var text_sizes: DictionaryCaseResult = .{ .trained_size = 0, .baseline_size = 0, .sequence_entropy_len = 0 };
    var structured_sizes: DictionaryCaseResult = .{ .trained_size = 0, .baseline_size = 0, .sequence_entropy_len = 0 };
    var binary_sizes: DictionaryCaseResult = .{ .trained_size = 0, .baseline_size = 0, .sequence_entropy_len = 0 };
    var trained_total: usize = 0;
    var baseline_total: usize = 0;
    var trained_sequence_entropy_len: usize = 0;
    var selector_sizes: SelectorCaseResult = .{ .baseline_size = 0, .selected_size = 0 };

    if (generated_path) |output_path| {
        const generated_id = nextDictionaryId(parsed.view.id);
        const text_id = nextDictionaryId(generated_id);
        const structured_id = nextDictionaryId(text_id);
        const binary_id = nextDictionaryId(structured_id);
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
        try verifyCustomRepcodes(init.gpa, runtime, generated, payload);

        text_sizes = try compareTrainedDictionaryCase(init.gpa, runtime, &text_training, payload, text_id);
        structured_sizes = try compareTrainedDictionaryCase(init.gpa, runtime, &structured_training, structured_payload, structured_id);
        binary_sizes = try compareTrainedDictionaryCase(init.gpa, runtime, &binary_training, &binary_payload, binary_id);
        selector_sizes = try compareValidatedHistorySelector(init.gpa, runtime, nextDictionaryId(binary_id));
        trained_total = text_sizes.trained_size + structured_sizes.trained_size + binary_sizes.trained_size;
        baseline_total = text_sizes.baseline_size + structured_sizes.baseline_size + binary_sizes.baseline_size;
        if (trained_total >= baseline_total) return error.CompressionRegression;
        trained_sequence_entropy_len = text_sizes.sequence_entropy_len;
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
        "zstd_full_dictionary_diff=ok version={s} id={d} vort={d} reference={d} generated={s} custom_repcodes={s} text={d}/{d} structured={d}/{d} binary={d}/{d} total={d}/{d} selector={d}/{d} sequence_entropy={d}\n",
        .{ runtime.version(), parsed.view.id, vort_encoded.frame.len, reference_encoded.len, if (generated_path == null) "no" else "yes", if (generated_path == null) "no" else "yes", text_sizes.trained_size, text_sizes.baseline_size, structured_sizes.trained_size, structured_sizes.baseline_size, binary_sizes.trained_size, binary_sizes.baseline_size, trained_total, baseline_total, selector_sizes.selected_size, selector_sizes.baseline_size, trained_sequence_entropy_len },
    );
    try stdout.interface.flush();
}
