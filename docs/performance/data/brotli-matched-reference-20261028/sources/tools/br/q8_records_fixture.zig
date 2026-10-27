pub const input_len = 32 * 1024;

/// Deterministic fixed-width records with stable fields and eight mutations
/// per row. This exposes Brotli q8's recent-distance advantage without relying
/// on an external corpus file.
pub fn fill(payload: []u8) void {
    std.debug.assert(payload.len == input_len);
    fillVariant(payload, 128, 8, 0x243f_6a88, 0x9e37_79b9);
}

pub fn fillVariant(payload: []u8, row_len: usize, mutations: usize, row_seed: u32, mutation_seed: u32) void {
    std.debug.assert(row_len >= 2 and row_len <= 1024 and payload.len % row_len == 0 and mutations < row_len);
    var row_storage: [1024]u8 = undefined;
    const row = row_storage[0..row_len];
    var row_state = row_seed;
    for (row, 0..) |*byte, index| {
        row_state = row_state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index + 1 == row_len) '\n' else 32 + @as(u8, @truncate((row_state >> 16) % 95));
    }
    var state = mutation_seed;
    var position: usize = 0;
    while (position < payload.len) {
        @memcpy(payload[position..][0..row_len], row);
        for (0..mutations) |mutation| {
            state = state *% 1_664_525 +% 1_013_904_223;
            const column = (mutation * 11 + 4) % (row_len - 1);
            payload[position + column] = 32 + @as(u8, @truncate((state >> 16) % 95));
        }
        position += row_len;
    }
}

const std = @import("std");
