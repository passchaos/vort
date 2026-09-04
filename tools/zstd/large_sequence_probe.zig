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

    var buffer: [512]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print(
        "zstd_large_sequence_probe=ok input_bytes={d} sequences={d} stage_bytes={d} frame_bytes={d} ll={s} of={s} ml={s} version={s}\n",
        .{ payload.len, modes.sequence_count, stage.encoded_len, encoded.frame.len, @tagName(modes.literal_length_mode), @tagName(modes.offset_mode), @tagName(modes.match_length_mode), runtime.version() },
    );
    try stdout.interface.flush();
}
