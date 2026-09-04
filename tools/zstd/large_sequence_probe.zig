const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");

pub fn main(init: std.process.Init) !void {
    var runtime = libzstd.Runtime.open() catch {
        {
            var buffer: [256]u8 = undefined;
            var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
            try stdout.interface.writeAll("zstd_large_sequence_probe=skipped reason=libzstd_unavailable\n");
            try stdout.interface.flush();
            return;
        }
    };
    defer runtime.deinit();

    const payload = try init.gpa.alloc(u8, std.compress.zstd.block_size_max);
    defer init.gpa.free(payload);
    var state: u32 = 0xfeed_beef;
    for (payload, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(state >> 16);
    }

    var stage_scratch: vort.zstd.NativeMatchStageScratch = .{};
    defer stage_scratch.deinit(init.gpa);
    const stage = try vort.zstd.benchmarkNativeMatchStage(
        init.gpa,
        payload,
        true,
        96,
        .double_fast,
        &stage_scratch,
    );
    if (!stage.available or stage.sequence_count <= 512 or stage.encoded_len >= payload.len)
        return error.LargeSequenceProbeMismatch;

    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, payload, .{
        .selection = .literal_only,
        .content_checksum = true,
        .match_search_budget = 96,
    });
    defer init.gpa.free(encoded.frame);
    const summary = try vort.zstdSummarizeNativeFrameBlocks(encoded.frame);
    if (summary.block_count != 1 or summary.compressed_block_count != 1)
        return error.LargeSequenceProbeMismatch;
    const block = try vort.zstdInspectNativeFrameFirstBlock(encoded.frame);
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(encoded.frame, block);
    if (encoded.frame.len > 35_046 or
        modes.sequence_count <= 512 or
        modes.literal_length_mode != .compressed or
        modes.offset_mode != .compressed or
        modes.match_length_mode != .rle) return error.LargeSequenceProbeMismatch;

    const native_decoded = try vort.zstdDecodeNativeFrameAlloc(init.gpa, encoded.frame);
    defer init.gpa.free(native_decoded);
    if (!std.mem.eql(u8, payload, native_decoded)) return error.LargeSequenceProbeMismatch;
    const reference_decoded = try init.gpa.alloc(u8, payload.len);
    defer init.gpa.free(reference_decoded);
    try runtime.decode(encoded.frame, reference_decoded);
    if (!std.mem.eql(u8, payload, reference_decoded)) return error.LargeSequenceProbeMismatch;

    const multi_payload = try init.gpa.alloc(u8, 129 * 1024);
    defer init.gpa.free(multi_payload);
    state = @truncate(0x9e37_79b9 +% 129 *% 0x10001 +% 16 *% 0x101 +% 23);
    for (multi_payload, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(state >> 16);
    }
    const copy_len = multi_payload.len / 4;
    @memcpy(multi_payload[multi_payload.len - copy_len ..], multi_payload[multi_payload.len / 4 ..][0..copy_len]);
    const multi = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, multi_payload, .{
        .selection = .literal_only,
        .content_checksum = true,
        .block_size_max = 2 * 1024,
        .match_search_budget = 64,
    });
    defer init.gpa.free(multi.frame);
    var repeat_blocks: usize = 0;
    var blocks = try vort.zstdIterateNativeFrameBlocks(multi.frame);
    while (try blocks.next()) |multi_block| {
        if (multi_block.block_type != .compressed) continue;
        const multi_modes = try vort.zstdInspectNativeFrameBlockSequenceModes(multi.frame, multi_block);
        if (multi_modes.sequence_count != 0 and
            (multi_modes.literal_length_mode == .repeat or multi_modes.offset_mode == .repeat or multi_modes.match_length_mode == .repeat))
            repeat_blocks += 1;
    }
    if (repeat_blocks == 0 or multi.frame.len > 27_867) return error.LargeSequenceProbeMismatch;
    const multi_reference_decoded = try init.gpa.alloc(u8, multi_payload.len);
    defer init.gpa.free(multi_reference_decoded);
    try runtime.decode(multi.frame, multi_reference_decoded);
    if (!std.mem.eql(u8, multi_payload, multi_reference_decoded)) return error.LargeSequenceProbeMismatch;
    const multi_native_decoded = try vort.zstdDecodeNativeFrameAlloc(init.gpa, multi.frame);
    defer init.gpa.free(multi_native_decoded);
    if (!std.mem.eql(u8, multi_payload, multi_native_decoded)) return error.LargeSequenceProbeMismatch;

    const dictionary_hex = try std.Io.Dir.cwd().readFileAlloc(init.io, "src/zstd/testdata/libzstd-trained-repeat.dict.hex", init.gpa, .limited(64 * 1024));
    defer init.gpa.free(dictionary_hex);
    const source_frame_hex = try std.Io.Dir.cwd().readFileAlloc(init.io, "src/zstd/testdata/libzstd-trained-repeat.frame.hex", init.gpa, .limited(64 * 1024));
    defer init.gpa.free(source_frame_hex);
    const trimmed_dictionary_hex = std.mem.trim(u8, dictionary_hex, " \r\n\t");
    const trimmed_source_frame_hex = std.mem.trim(u8, source_frame_hex, " \r\n\t");
    const dictionary_bytes = try init.gpa.alloc(u8, trimmed_dictionary_hex.len / 2);
    defer init.gpa.free(dictionary_bytes);
    _ = try std.fmt.hexToBytes(dictionary_bytes, trimmed_dictionary_hex);
    const source_frame = try init.gpa.alloc(u8, trimmed_source_frame_hex.len / 2);
    defer init.gpa.free(source_frame);
    _ = try std.fmt.hexToBytes(source_frame, trimmed_source_frame_hex);
    const standard = try vort.ZstdNativeDictionary.initFromStandardDictionary(dictionary_bytes);
    const dictionary_payload = try vort.zstdDecodeNativeFrameAllocWithDictionary(init.gpa, source_frame, standard.dictionary);
    defer init.gpa.free(dictionary_payload);
    const dictionary_encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(init.gpa, dictionary_payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    }, standard.dictionary);
    defer init.gpa.free(dictionary_encoded.frame);
    const dictionary_block = try vort.zstdInspectNativeFrameFirstBlock(dictionary_encoded.frame);
    const dictionary_modes = try vort.zstdInspectNativeFrameBlockSequenceModesWithDictionary(dictionary_encoded.frame, dictionary_block, standard.dictionary);
    if (dictionary_modes.literal_length_mode != .repeat) return error.LargeSequenceProbeMismatch;
    const dictionary_reference_decoded = try init.gpa.alloc(u8, dictionary_payload.len);
    defer init.gpa.free(dictionary_reference_decoded);
    try runtime.decodeUsingDict(dictionary_encoded.frame, dictionary_reference_decoded, dictionary_bytes);
    if (!std.mem.eql(u8, dictionary_payload, dictionary_reference_decoded)) return error.LargeSequenceProbeMismatch;

    var buffer: [512]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print(
        "zstd_large_sequence_probe=ok input_bytes={d} sequences={d} stage_bytes={d} frame_bytes={d} ll={s} of={s} ml={s} repeat_blocks={d} multiblock_bytes={d} dictionary_repeat={s} version={s}\n",
        .{ payload.len, modes.sequence_count, stage.encoded_len, encoded.frame.len, @tagName(modes.literal_length_mode), @tagName(modes.offset_mode), @tagName(modes.match_length_mode), repeat_blocks, multi.frame.len, @tagName(dictionary_modes.literal_length_mode), runtime.version() },
    );
    try stdout.interface.flush();
}
