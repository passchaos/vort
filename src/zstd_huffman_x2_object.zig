const huffman_x2 = @import("zstd/literals/huffman_x2.zig");
const abi = @import("zstd/literals/huffman_x2_abi.zig");

export fn vortZstdHuffmanX2Decode(request: *const abi.Request) callconv(.c) c_int {
    return @intFromEnum(huffman_x2.decodeRequest(request));
}
