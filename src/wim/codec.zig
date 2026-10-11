const std = @import("std");
const core = @import("../core.zig");
const xpress = @import("../xpress.zig");
const lzx = @import("../cab/lzx.zig");
const lzms = @import("../lzms.zig");
const format = @import("format.zig");

pub const Error = core.Error || xpress.Error || lzx.Error || lzms.Error || std.mem.Allocator.Error ||
    error{ UnsupportedWimCompression, InvalidWim };

pub fn decodeChunkInto(
    allocator: std.mem.Allocator,
    compression: format.Compression,
    input: []const u8,
    output: []u8,
    chunk_size: usize,
) Error!void {
    switch (compression) {
        .none => return error.InvalidWim,
        .xpress => {
            _ = try xpress.decodeHuffmanInto(input, output);
        },
        .lzx => {
            const window_bits: u5 = @intCast(std.math.log2_int(usize, chunk_size));
            const decoded = try lzx.decodeAllocWithFormat(
                allocator,
                input,
                output.len,
                window_bits,
                .wim,
            );
            defer allocator.free(decoded);
            @memcpy(output, decoded);
        },
        .lzms => try lzms.decodeInto(allocator, input, output),
    }
}
