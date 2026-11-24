//! Wide coordinates for incremental Deflate checkpoints.
const Count = @import("../../core.zig").StreamCount;

pub const Position = struct {
    /// Absolute compressed byte offset since the decoder was reset.
    compressed_byte_offset: Count,
    /// Offset within that byte, in Deflate's least-significant-bit-first order.
    compressed_bit_offset: u3 = 0,
    /// Cumulative plaintext bytes already published by the decoder.
    decoded_offset: Count,
};

pub fn atByte(accepted: Count, decoded: Count) Position {
    return .{ .compressed_byte_offset = accepted, .decoded_offset = decoded };
}

pub fn fromReservoir(accepted: Count, retained_bits: u6, decoded: Count) Position {
    // Subtract the reservoir without flattening the wide byte count into bits.
    const retained_bytes = (@as(Count, retained_bits) + 7) / 8;
    const partial: u3 = @truncate(retained_bits);
    return .{
        .compressed_byte_offset = accepted - retained_bytes,
        .compressed_bit_offset = 0 -% partial,
        .decoded_offset = decoded,
    };
}

pub fn inWrapper(raw: Position, raw_accepted: Count, wrapper_accepted: Count, wrapper_decoded: Count) Position {
    return .{
        .compressed_byte_offset = wrapper_accepted - (raw_accepted - raw.compressed_byte_offset),
        .compressed_bit_offset = raw.compressed_bit_offset,
        .decoded_offset = wrapper_decoded,
    };
}

test "Deflate block boundary position keeps the full byte counter" {
    const t = @import("std").testing;
    const end = @import("std").math.maxInt(Count);
    try t.expectEqual(atByte(end, end), fromReservoir(end, 0, end));
    try t.expectEqual(Position{
        .compressed_byte_offset = end - 8,
        .compressed_bit_offset = 1,
        .decoded_offset = end,
    }, fromReservoir(end, 63, end));
    try t.expectEqual(Position{
        .compressed_byte_offset = end - 2,
        .compressed_bit_offset = 5,
        .decoded_offset = end,
    }, inWrapper(fromReservoir(9, 11, 6), 9, end, end));
}
