const std = @import("std");

const frame_magic: u32 = 0xfd2f_b528;

pub const Plan = struct {
    content_size: usize,
};

/// Return the declared output size when a stream contains exactly one
/// dictionary-free Zstandard data frame and no concatenated/skippable suffix.
///
/// This is deliberately a shape recognizer, not a validator. The production
/// decoder still validates every block, checksum, and declared-size invariant;
/// callers use this plan only to reserve the final output slot once and avoid a
/// second full compressed-block parse before allocator-backed decode.
pub fn plan(frame: []const u8) ?Plan {
    if (frame.len < 6 or std.mem.readInt(u32, frame[0..4], .little) != frame_magic) {
        return null;
    }
    const descriptor = frame[4];
    if ((descriptor & 0x08) != 0 or (descriptor & 0x03) != 0) return null;
    const single_segment = (descriptor & 0x20) != 0;
    const content_size_flag = descriptor >> 6;
    if (!single_segment and content_size_flag == 0) return null;

    var offset: usize = 5;
    if (!single_segment) {
        if (offset == frame.len) return null;
        offset += 1; // Window descriptor.
    }
    const field_size: usize = @as(usize, 1) << @intCast(content_size_flag);
    if (frame.len - offset < field_size) return null;
    var content_size_u64: u64 = 0;
    for (frame[offset..][0..field_size], 0..) |byte, index| {
        content_size_u64 |= @as(u64, byte) << @intCast(index * 8);
    }
    if (field_size == 2) content_size_u64 += 256;
    const content_size = std.math.cast(usize, content_size_u64) orelse return null;

    // Lock the fast path to a single block whose stored payload and optional
    // checksum end exactly at the input boundary. This excludes concatenation
    // in O(1), without scanning a large raw payload for coincidental magic.
    offset += field_size;
    if (frame.len - offset < 3) return null;
    const block_header = std.mem.readInt(u24, frame[offset..][0..3], .little);
    if ((block_header & 1) == 0) return null;
    const block_type = (block_header >> 1) & 0x03;
    if (block_type == 3) return null;
    const block_len: usize = @intCast(block_header >> 3);
    const stored_len: usize = if (block_type == 1) 1 else block_len;
    const checksum_len: usize = if ((descriptor & 0x04) != 0) 4 else 0;
    const expected_len = std.math.add(usize, offset + 3, stored_len) catch return null;
    const final_len = std.math.add(usize, expected_len, checksum_len) catch return null;
    if (final_len != frame.len) return null;
    return .{ .content_size = content_size };
}

test "known-size plan recognizes one dictionary-free frame" {
    const frame = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd, 0x20, 3,
        0x19, 0x00, 0x00, 'a',  'b',  'c',
    };
    try std.testing.expectEqual(@as(usize, 3), plan(&frame).?.content_size);

    var dictionary = frame;
    dictionary[4] |= 1;
    try std.testing.expectEqual(@as(?Plan, null), plan(&dictionary));
}
