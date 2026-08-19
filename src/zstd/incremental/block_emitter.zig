const std = @import("std");

/// Adapt the one-shot Zstd block planners to the incremental encoder without
/// coupling its generic state machine to entropy-coding details. `writeEntropy`
/// owns candidate selection and persistent Huffman-tree state; this boundary
/// owns only the public raw/RLE versus entropy-capable policy.
pub fn Emitter(comptime Codec: type) type {
    return struct {
        pub fn write(
            allocator: std.mem.Allocator,
            out: *std.ArrayList(u8),
            block: []const u8,
            last: bool,
            options: Codec.Options,
            state: *Codec.State,
            dictionary: ?Codec.Dictionary,
            frame_offset: usize,
        ) Codec.Error!void {
            switch (options.selection) {
                .raw_or_rle => try Codec.writeRawOrRle(allocator, out, block, last),
                .literal_only, .auto => try Codec.writeEntropy(
                    allocator,
                    out,
                    block,
                    last,
                    state,
                    dictionary,
                    frame_offset,
                    options.match_search_budget,
                ),
            }
        }
    };
}
