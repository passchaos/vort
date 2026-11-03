//! Publish only caller-visible input progress after a semantic transaction.
const std = @import("std");
const bitstream = @import("../../../bitstream.zig");

pub inline fn rewindLookahead(reader: *bitstream.BufferedBitReader) void {
    const rewind = @min(reader.bit_count / 8, reader.byte_index);
    if (rewind == 0) {
        // A wide refill can leave shadow bits after every declared bit retires.
        // They belong to input which the caller still owns, not to this state.
        if (reader.bit_count == 0) reader.bit_buffer = 0;
        return;
    }
    reader.bit_count -= rewind * 8;
    reader.bit_buffer &= (@as(u64, 1) << @intCast(reader.bit_count)) - 1;
    reader.byte_index -= rewind;
}

test "semantic window rewind clears empty shadow bits and preserves the next stream bits" {
    for (0..57) |consumed| {
        var input: [32]u8 = undefined;
        for (&input, 0..) |*byte, index| byte.* = @truncate(index * 71 + 19);
        input[7] = 0x2b;
        var reader = bitstream.BufferedBitReader.init(&input);
        reader.bit_buffer = std.mem.readInt(u64, input[0..8], .little) >> @intCast(consumed);
        reader.bit_count = 56 - consumed;
        reader.byte_index = 7;
        reader.consumed_bits = @intCast(consumed);
        // No bit of this byte was consumed; it may be replaced before resume.
        if (consumed == 56) input[7] = 0xd4;
        rewindLookahead(&reader);
        try std.testing.expectEqual(consumed, reader.byte_index * 8 - reader.bit_count);
        try std.testing.expectEqual(consumed, reader.consumed_bits);
        if (reader.bit_count == 0) try std.testing.expectEqual(@as(u64, 0), reader.bit_buffer);
        var expected: u32 = 0;
        for (0..32) |bit| {
            const source = consumed + bit;
            const value = (input[source / 8] >> @as(u3, @intCast(source % 8))) & 1;
            expected |= @as(u32, value) << @intCast(bit);
        }
        try std.testing.expectEqual(expected, try reader.readBits(u32, 32));
        try std.testing.expectEqual(consumed + 32, reader.consumed_bits);
    }
}
