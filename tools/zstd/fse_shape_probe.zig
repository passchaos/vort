const std = @import("std");
const zstd = @import("zstd");
pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingFrame;
    const frame = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(2 * 1024 * 1024));
    defer init.gpa.free(frame);
    const p = try zstd.benchmarkNativeSequenceCopyProfile(frame);
    const summary = try zstd.summarizeNativeFrameBlocks(frame);
    std.debug.print("encoded_bytes={d} blocks={d} raw_blocks={d} rle_blocks={d} compressed_blocks={d}\n", .{ frame.len, summary.block_count, summary.raw_block_count, summary.rle_block_count, summary.compressed_block_count });
    std.debug.print("sequence_blocks={d} sequences={d} compressed_tables={d} no_low_tables={d} low_tables={d} repeat_modes={d} rle_modes={d} predefined_modes={d}\n", .{ p.sequence_block_count, p.sequence_count, p.compressed_table_modes, p.no_low_probability_tables, p.low_probability_tables, p.repeat_table_modes, p.rle_table_modes, p.predefined_table_modes });
    std.debug.print("raw_literal_blocks={d} rle_literal_blocks={d} compressed_literal_blocks={d} treeless_literal_blocks={d}\n", .{ p.raw_literal_blocks, p.rle_literal_blocks, p.compressed_literal_blocks, p.treeless_literal_blocks });
    var generic: usize = 0;
    for (p.fse_accuracy_log_histogram, p.no_low_fse_accuracy_log_histogram, 0..) |total, no_low, log| {
        if (total == 0) continue;
        const specialized = if (log == 8) no_low else 0;
        generic += total - specialized;
        std.debug.print("table_log={d} states={d} total={d} no_low={d} low={d} route256={d} generic={d}\n", .{ log, @as(usize, 1) << @intCast(log), total, no_low, total - no_low, specialized, total - specialized });
    }
    std.debug.print("route256_total={d} generic_total={d}\n", .{ p.no_low_fse_accuracy_log_histogram[8], generic });
    var offset = (try zstd.inspectNativeFrameHeader(frame)).payload_offset;
    var index: usize = 0;
    while (true) : (index += 1) {
        const block = try zstd.inspectNativeFrameBlockAt(frame, offset);
        const shape = try zstd.inspectNativeFrameBlockSequenceModes(frame, block);
        std.debug.print("block={d} type={s} literals={s} sequences={d} modes={s}/{s}/{s}\n", .{ index, @tagName(block.block_type), @tagName(shape.literals_kind), shape.sequence_count, @tagName(shape.literal_length_mode), @tagName(shape.offset_mode), @tagName(shape.match_length_mode) });
        if (block.last) break;
        offset = block.next_header_offset;
    }
}
