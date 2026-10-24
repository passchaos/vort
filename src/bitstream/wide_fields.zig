const std = @import("std");

/// A byte-filled u64 reservoir cannot always stage 57...63 bits at once from
/// an unaligned source. Split only those wide fields into bounded pieces;
/// ordinary Huffman fields retain their existing reservoir path.
pub fn peekPadded(reader: anytype, comptime T: type, count: u6) T {
    std.debug.assert(count > 56 and count <= @bitSizeOf(T));
    var copy = reader;
    const low = copy.peekBitsPadded(u32, 32);
    if (!copy.hasBits(32)) return @intCast(low);
    copy.advanceBitsStagedAssumeAvailable(32);
    const high = copy.peekBitsPadded(u32, count - 32);
    return @intCast(@as(u64, low) | (@as(u64, high) << 32));
}

pub fn advance(reader: anytype, count: u6) void {
    std.debug.assert(count > 56);
    reader.advanceBitsAssumeAvailable(32);
    reader.advanceBitsAssumeAvailable(count - 32);
}
