const builtin = @import("builtin");
const core = @import("../../core.zig");
const bitstream = @import("../../bitstream.zig");
const semantic = @import("decoder.zig");

// WASM has no code-address alignment. Keep native alignment and choose an
// ordinary function entry for portable one-shot callers on WASI.
pub const decodeBuffered = if (builtin.object_format == .wasm) portable else aligned;

noinline fn portable(
    noalias reader: *bitstream.BufferedBitReader,
    noalias output: []u8,
    initial_out_offset: usize,
    noalias decoder: *const semantic.SemanticDynamicDecoder,
) core.Error!usize {
    return decode(reader, output, initial_out_offset, decoder);
}

noinline fn aligned(
    noalias reader: *bitstream.BufferedBitReader,
    noalias output: []u8,
    initial_out_offset: usize,
    noalias decoder: *const semantic.SemanticDynamicDecoder,
) align(64) core.Error!usize {
    return decode(reader, output, initial_out_offset, decoder);
}

inline fn decode(
    noalias reader: *bitstream.BufferedBitReader,
    noalias output: []u8,
    initial_out_offset: usize,
    noalias decoder: *const semantic.SemanticDynamicDecoder,
) core.Error!usize {
    return semantic.decodeDynamicBlockIntoLinearMode(
        false,
        false,
        false,
        false,
        false,
        reader,
        output,
        initial_out_offset,
        decoder,
    );
}
