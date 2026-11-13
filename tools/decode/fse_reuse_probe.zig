//! One-off probe: walk every block of a Zstd frame and count sequence-table
//! symbol modes to quantify FSE table reuse opportunities. Uses only public
//! inspection APIs so production decode code is untouched.
const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const a = init.gpa;

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, a);
    defer args.deinit();
    _ = args.next();
    const wire_path = args.next() orelse return error.MissingWire;

    const frame = try std.Io.Dir.cwd().readFileAlloc(init.io, wire_path, a, .limited(1 << 30));
    defer a.free(frame);

    var counts = ModeCounts{};
    var block_index: usize = 0;
    var block = try vort.zstd.inspectNativeFrameFirstBlock(frame);
    while (true) : (block_index += 1) {
        counts.blocks += 1;
        switch (block.block_type) {
            .raw => counts.raw += 1,
            .rle => counts.rle += 1,
            .compressed => {
                counts.compressed += 1;
                const modes = try vort.zstd.inspectNativeFrameBlockSequenceModes(frame, block);
                if (modes.sequence_count == 0) {
                    counts.compressed_no_sequences += 1;
                } else {
                    counts.ll.add(modes.literal_length_mode);
                    counts.of.add(modes.offset_mode);
                    counts.ml.add(modes.match_length_mode);
                    counts.sequence_blocks += 1;
                }
            },
        }
        if (block.last) break;
        block = try vort.zstd.inspectNativeFrameBlockAt(frame, block.next_header_offset);
    }

    var stdout_buffer: [2048]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        \\blocks={d} raw={d} rle={d} compressed={d} (no_sequences={d} with_sequences={d})
        \\LL {s}
        \\OF {s}
        \\ML {s}
        \\
    , .{
        counts.blocks,
        counts.raw,
        counts.rle,
        counts.compressed,
        counts.compressed_no_sequences,
        counts.sequence_blocks,
        counts.ll.format(),
        counts.of.format(),
        counts.ml.format(),
    });
    try stdout.flush();
}

const ModeCounts = struct {
    blocks: usize = 0,
    raw: usize = 0,
    rle: usize = 0,
    compressed: usize = 0,
    compressed_no_sequences: usize = 0,
    sequence_blocks: usize = 0,
    ll: TableModeCounts = .{},
    of: TableModeCounts = .{},
    ml: TableModeCounts = .{},
};

const TableModeCounts = struct {
    predefined: usize = 0,
    rle: usize = 0,
    compressed: usize = 0,
    repeat: usize = 0,

    fn add(self: *TableModeCounts, mode: vort.zstd.NativeSequenceTableMode) void {
        switch (mode) {
            .predefined => self.predefined += 1,
            .rle => self.rle += 1,
            .compressed => self.compressed += 1,
            .repeat => self.repeat += 1,
        }
    }

    fn format(self: *const TableModeCounts) []const u8 {
        return std.fmt.bufPrint(&format_buffer, "predefined={d} rle={d} compressed={d} repeat={d}", .{
            self.predefined, self.rle, self.compressed, self.repeat,
        }) catch "format-error";
    }
};

var format_buffer: [128]u8 = undefined;
