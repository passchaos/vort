const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(1 << 20));
    defer init.gpa.free(bytes);
    const parsed = try vort.ZstdNativeDictionary.initFromStandardDictionary(bytes);
    const payload = "standard dictionary sample alpha standard dictionary sample beta";
    var runtime = try libzstd.Runtime.open();
    defer runtime.deinit();

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

    var buffer: [256]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print("zstd_full_dictionary_diff=ok version={s} id={d} vort={d} reference={d}\n", .{ runtime.version(), parsed.view.id, vort_encoded.frame.len, reference_encoded.len });
    try stdout.interface.flush();
}
