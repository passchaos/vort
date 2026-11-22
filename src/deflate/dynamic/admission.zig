//! RFC 1951/zlib validity for dynamic Huffman alphabets. The generic Huffman
//! builder also serves codecs and kernel oracles that permit incomplete trees;
//! only Deflate wire parsers apply this admission policy.
pub const Alphabet = enum { code_lengths, literal_lengths, distances };
pub const Error = error{InvalidHuffmanCode};

pub fn validate(comptime alphabet: Alphabet, lengths: []const u4) Error!void {
    const maximum: usize = if (alphabet == .code_lengths) 7 else 15;
    var counts: [16]u16 = @splat(0);
    var active: usize = 0;
    for (lengths) |width| {
        if (width > maximum) return error.InvalidHuffmanCode;
        if (width != 0) {
            counts[width] += 1;
            active += 1;
        }
    }
    // An empty distance alphabet is legal in literal-only dynamic blocks.
    // Its generic error-marker table rejects any later distance-symbol use.
    if (active == 0) {
        if (alphabet == .distances) return;
        return error.InvalidHuffmanCode;
    }
    var available: i32 = 1;
    for (1..maximum + 1) |width| {
        available = available * 2 - counts[width];
        if (available < 0) return error.InvalidHuffmanCode;
    }
    // zlib permits an incomplete LENS/DISTS set only for one one-bit code.
    // CODES must always occupy the complete canonical code space.
    if (available != 0 and
        (alphabet == .code_lengths or active != 1 or counts[1] != 1))
        return error.InvalidHuffmanCode;
}

pub fn isValid(comptime alphabet: Alphabet, lengths: []const u4) bool {
    validate(alphabet, lengths) catch return false;
    return true;
}
