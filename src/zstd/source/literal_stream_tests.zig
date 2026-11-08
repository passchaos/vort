const raw = @import("literal_stream_tests/raw.zig");
const rle = @import("literal_stream_tests/rle.zig");
const huffman = @import("literal_stream_tests/huffman.zig");

pub fn contracts(comptime Support: type) !void {
    try raw.contracts();
    try rle.contracts();
    try huffman.contracts(Support);
}
