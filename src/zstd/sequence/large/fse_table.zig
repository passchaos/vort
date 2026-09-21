const std = @import("std");
const builtin = @import("builtin");

pub const text_section = switch (builtin.object_format) {
    .elf => ".vort_zstd_fse_256",
    .macho => "__TEXT,__vort_zstd_f256",
    .coff => ".text$vort_zstd_fse_256",
    else => ".text",
};

pub const Error = error{CorruptFrame};

/// Build a 256-state mapped FSE table after the wire parser has verified the
/// normalized-count sum and established that no `-1` probability is present.
/// Per-symbol state bitsets avoid the generic 512-byte symbol scratch and its
/// second random-access transition pass.
pub noinline fn buildNoLowProbability(
    values: []const u16,
    entries: anytype,
    bases: []const usize,
    additional_bits: []const u8,
) linksection(text_section) Error!void {
    if (entries.len != 256 or values.len > 256 or values.len > bases.len or values.len > additional_bits.len)
        return error.CorruptFrame;

    const table_size = 256;
    const spread_step = (table_size >> 1) + (table_size >> 3) + 3;
    var position: usize = 0;
    for (values, 0..) |value, symbol| {
        if (value == 0) return error.CorruptFrame;
        if (value == 1) continue;
        const probability: usize = value - 1;
        var states: [4]u64 = if (probability >= table_size / 2) @splat(std.math.maxInt(u64)) else @splat(0);
        if (probability >= table_size / 2) {
            const symbol_end = (position + probability * spread_step) & (table_size - 1);
            var gap_position = symbol_end;
            for (0..table_size - probability) |_| {
                states[gap_position >> 6] &= ~(@as(u64, 1) << @intCast(gap_position & 63));
                gap_position = (gap_position + spread_step) & (table_size - 1);
            }
            std.debug.assert(gap_position == position);
            position = symbol_end;
        } else {
            for (0..probability) |_| {
                states[position >> 6] |= @as(u64, 1) << @intCast(position & 63);
                position = (position + spread_step) & (table_size - 1);
            }
        }

        var ordinal: usize = 0;
        for (&states, 0..) |*word, word_index| {
            while (word.* != 0) {
                const state = word_index * 64 + @ctz(word.*);
                word.* &= word.* - 1;
                const next_state: u16 = @intCast(probability + ordinal);
                const state_bits: u8 = 8 - std.math.log2_int(u16, next_state);
                entries[state] = .{
                    .base = @intCast(bases[symbol]),
                    .additional_bits = additional_bits[symbol],
                    .next_state = @intCast((@as(u32, next_state) << @intCast(state_bits)) - table_size),
                    .state_bits = state_bits,
                };
                ordinal += 1;
            }
        }
        std.debug.assert(ordinal == probability);
    }
    if (position != 0) return error.CorruptFrame;
}
