//! Isolated direct FSE transition kernel for large fast-compressed blocks.
const std = @import("std");
const builtin = @import("builtin");

const text_section = switch (builtin.object_format) {
    .elf => ".vort_zstd_fast_large",
    .macho => "__TEXT,__vort_zstd_fl",
    .coff => ".text$vort_zstd_fast_large",
    else => ".text",
};

pub const Transform = extern struct {
    delta_find_state: i32 = 0,
    delta_nb_bits: i32 = 0,
};

pub noinline fn fill(
    codes: []const u8,
    state_table: []const u16,
    transforms: []const Transform,
    max_symbol: u8,
    next_states: []u8,
    state_bits: []u8,
    transition_values: []u8,
    transition_bits: []u8,
) linksection(text_section) ?u8 {
    if (codes.len == 0 or state_table.len == 0 or
        next_states.len != codes.len or state_bits.len != codes.len or
        transition_values.len != codes.len or transition_bits.len != codes.len) return null;
    const table_size = state_table.len;
    var encoder_state = initialState(state_table, transforms, max_symbol, codes[codes.len - 1]) orelse return null;
    if (encoder_state < table_size or encoder_state - table_size >= table_size) return null;
    next_states[codes.len - 1] = 0;
    state_bits[codes.len - 1] = 0;

    var i = codes.len - 1;
    while (i > 0) {
        i -= 1;
        const code = codes[i];
        if (code > max_symbol or code >= transforms.len) return null;
        const transform = transforms[code];
        const bits: u8 = @intCast((@as(i32, @intCast(encoder_state)) + transform.delta_nb_bits) >> 16);
        const state_index_signed = @as(i32, @intCast(encoder_state >> @intCast(bits))) + transform.delta_find_state;
        if (state_index_signed < 0) return null;
        const state_index: usize = @intCast(state_index_signed);
        if (state_index >= table_size) return null;
        const transition_mask = (@as(usize, 1) << @intCast(bits)) - 1;
        const next_state = encoder_state - table_size;
        const transition = encoder_state & transition_mask;
        if (transition > next_state or next_state - transition > std.math.maxInt(u8)) return null;
        next_states[i] = @intCast(next_state - transition);
        state_bits[i] = bits;
        transition_values[i] = @intCast(transition);
        transition_bits[i] = bits;
        encoder_state = state_table[state_index];
        if (encoder_state < table_size or encoder_state - table_size >= table_size) return null;
    }
    return @intCast(encoder_state - table_size);
}

fn initialState(state_table: []const u16, transforms: []const Transform, max_symbol: u8, symbol: u8) ?usize {
    if (symbol > max_symbol or symbol >= transforms.len) return null;
    const transform = transforms[symbol];
    const bits: usize = @intCast(@divTrunc(transform.delta_nb_bits + (1 << 15), 1 << 16));
    const value: usize = @intCast((@as(i32, @intCast(bits)) << 16) - transform.delta_nb_bits);
    const shifted = value >> @intCast(bits);
    const index_signed = @as(i32, @intCast(shifted)) + transform.delta_find_state;
    if (index_signed < 0) return null;
    const index: usize = @intCast(index_signed);
    if (index >= state_table.len) return null;
    return state_table[index];
}

test "large transition kernel rejects inconsistent slices" {
    var transforms: [1]Transform = .{.{}};
    var states: [1]u16 = .{1};
    var output: [1]u8 = undefined;
    try std.testing.expectEqual(@as(?u8, null), fill(&.{}, &states, &transforms, 0, &output, &output, &output, &output));
    try std.testing.expectEqual(@as(?u8, null), fill(&.{0}, &states, &transforms, 0, output[0..0], &output, &output, &output));
}
