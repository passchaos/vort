const builtin = @import("builtin");
const huffman = @import("../../huffman.zig");

/// Dedicated executable section for the PNG-oriented RLE258 semantic loop and
/// its block-level canonical-table policy. Keeping both behind the same section
/// boundary prevents their code size from reordering ordinary DEFLATE loops.
pub const text_section = switch (builtin.object_format) {
    .elf => ".vort_png_rle258",
    .macho => "__TEXT,__vort_png_rle",
    .coff => ".text$vort_png_rle258",
    else => ".text",
};

/// Select the PNG table shape where the two-bit RLE258 pair is both frequent
/// and profitable. Other final dynamic blocks keep the existing semantic loop
/// without entering this module's canonical-table policy boundary.
pub inline fn isCandidate(parsed: huffman.DynamicLengths) bool {
    return parsed.literal_max_bits == 12 and
        parsed.distance_max_bits == 9;
}

/// Prove the exact canonical two-bit pair consumed by the RLE258 loop.
///
/// Canonical Huffman entries are stored by bit width and then symbol order. The
/// first entry in a non-empty one-bit bucket owns code zero, so this check is
/// O(1) and does not require changing semantic-decoder object layout.
pub noinline fn shouldUse(
    literal_table: *const huffman.HuffmanTable(286),
    distance_table: *const huffman.HuffmanTable(30),
) linksection(text_section) bool {
    return hasOneBitZeroCode(literal_table, 285) and
        hasOneBitZeroCode(distance_table, 0);
}

pub fn hasOneBitZeroCode(table: anytype, wanted_symbol: u16) bool {
    return table.count_by_bits[1] != 0 and
        table.entries[table.first_by_bits[1]].symbol == wanted_symbol and
        table.entries[table.first_by_bits[1]].code == 0;
}
