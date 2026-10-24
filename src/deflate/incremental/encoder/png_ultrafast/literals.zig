const syntax = @import("../../../../png_ultrafast.zig").incremental_syntax;

/// Pack the same trained literal codes into at most two four-literal writes.
/// No pair lookup table or additional mutable encoder storage is needed.
pub inline fn prefix(writer: anytype, initial_word: u64, initial_count: u4) void {
    var word = initial_word;
    var count = initial_count;
    if (count >= 4) {
        quad(writer, @truncate(word));
        word >>= 32;
        count -= 4;
    }
    if (count >= 4) {
        quad(writer, @truncate(word));
        return;
    }
    if (count >= 2) {
        const first: u8 = @truncate(word);
        const second: u8 = @truncate(word >> 8);
        const n0: u6 = syntax.lengths[first];
        const n1: u6 = syntax.lengths[second];
        writer.writeBitsBulk(@as(u64, syntax.codes[first]) | (@as(u64, syntax.codes[second]) << n0), n0 + n1);
        word >>= 16;
        count -= 2;
    }
    if (count != 0) {
        const last: u8 = @truncate(word);
        writer.writeBitsBulk(syntax.codes[last], syntax.lengths[last]);
    }
}

inline fn quad(writer: anytype, word: u32) void {
    const b0: u8 = @truncate(word);
    const b1: u8 = @truncate(word >> 8);
    const b2: u8 = @truncate(word >> 16);
    const b3: u8 = @truncate(word >> 24);
    const n0: u6 = syntax.lengths[b0];
    const n1: u6 = syntax.lengths[b1];
    const n2: u6 = syntax.lengths[b2];
    const n3: u6 = syntax.lengths[b3];
    const bits = @as(u64, syntax.codes[b0]) |
        (@as(u64, syntax.codes[b1]) << n0) |
        (@as(u64, syntax.codes[b2]) << (n0 + n1)) |
        (@as(u64, syntax.codes[b3]) << (n0 + n1 + n2));
    writer.writeBitsBulk(bits, n0 + n1 + n2 + n3);
}
