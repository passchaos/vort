pub const input_len = 32 * 1024;

/// Deterministic fixed-width records with stable fields and eight mutations
/// per row. This exposes Brotli q8's recent-distance advantage without relying
/// on an external corpus file.
pub fn fill(payload: []u8) void {
    std.debug.assert(payload.len == input_len);
    var row: [128]u8 = undefined;
    var row_state: u32 = 0x243f_6a88;
    for (&row, 0..) |*byte, index| {
        row_state = row_state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index + 1 == row.len) '\n' else 32 + @as(u8, @truncate((row_state >> 16) % 95));
    }
    var state: u32 = 0x9e37_79b9;
    var position: usize = 0;
    while (position < payload.len) {
        const length = @min(row.len, payload.len - position);
        @memcpy(payload[position..][0..length], row[0..length]);
        for (0..8) |mutation| {
            state = state *% 1_664_525 +% 1_013_904_223;
            const column = (mutation * 11 + 4) % length;
            payload[position + column] = 32 + @as(u8, @truncate((state >> 16) % 95));
        }
        position += length;
    }
}

const std = @import("std");
