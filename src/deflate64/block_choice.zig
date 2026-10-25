//! Exact block arbitration. Equal costs preserve stored, then fixed, then
//! dynamic emission; only a strict improvement changes the selected format.
const blocks = @import("stream_blocks.zig");

pub const Kind = enum { stored, fixed, dynamic };

pub fn compressed(fixed_bits: usize, dynamic_bits: usize) Kind {
    return if (dynamic_bits < fixed_bits) .dynamic else .fixed;
}

pub fn adaptive(state: blocks.State, stored_bits: usize, fixed_bits: usize, dynamic_bits: usize, final: bool) Kind {
    const stored_cost = cost(state, stored_bits, final);
    const fixed_cost = cost(state, fixed_bits, final);
    const dynamic_cost = cost(state, dynamic_bits, final);
    var result: Kind = .stored;
    var best = stored_cost;
    if (fixed_cost < best) {
        result = .fixed;
        best = fixed_cost;
    }
    if (dynamic_cost < best) result = .dynamic;
    return result;
}

fn cost(state: blocks.State, bits: usize, final: bool) usize {
    return if (final) blocks.pendingBytes(state, bits, true) else bits;
}

test "Deflate64 block ties preserve format order including final padding" {
    const testing = @import("std").testing;
    try testing.expectEqual(Kind.fixed, compressed(20, 20));
    try testing.expectEqual(Kind.dynamic, compressed(20, 19));
    try testing.expectEqual(Kind.stored, adaptive(.{}, 40, 40, 40, false));
    try testing.expectEqual(Kind.fixed, adaptive(.{}, 41, 40, 40, false));
    try testing.expectEqual(Kind.dynamic, adaptive(.{}, 41, 40, 39, false));
    for (0..8) |offset| {
        const state: blocks.State = .{ .bit_index = @intCast(offset) };
        // All three candidates occupy the same final byte count.
        try testing.expectEqual(Kind.stored, adaptive(state, 16 - offset, 15 - offset, 14 - offset, true));
        try testing.expectEqual(Kind.fixed, adaptive(state, 24 - offset, 16 - offset, 15 - offset, true));
        try testing.expectEqual(Kind.dynamic, adaptive(state, 24 - offset, 17 - offset, 16 - offset, true));
    }
}
