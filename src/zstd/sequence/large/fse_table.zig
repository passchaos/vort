const std = @import("std");
const builtin = @import("builtin");

pub const text_section = switch (builtin.object_format) {
    .elf => ".vort_zstd_fse_256",
    .macho => "__TEXT,__vort_zstd_f256",
    .coff => ".text$vort_zstd_fse_256",
    else => ".text",
};

pub const Error = error{CorruptFrame};
const max_sequence_symbol_count = 53;

/// Build a 256-state mapped FSE table after the wire parser has verified the
/// normalized-count sum and established that no `-1` probability is present.
/// Per-symbol state bitsets construct final mapped entries directly, removing
/// the symbol scratch and its following symbol-indexed transition pass. Dense
/// probabilities build the complement so their spread loop visits fewer states.
pub noinline fn buildNoLowProbability(
    values: []const u16,
    entries: anytype,
    bases: []const usize,
    additional_bits: []const u8,
) linksection(text_section) Error!void {
    if (entries.len != 256 or values.len > max_sequence_symbol_count or values.len > bases.len or values.len > additional_bits.len)
        return error.CorruptFrame;

    const table_size: usize = 256;
    var normalized_total: usize = 0;
    for (values) |value| {
        if (value == 0) return error.CorruptFrame;
        const probability: usize = value - 1;
        if (probability > table_size - normalized_total) return error.CorruptFrame;
        normalized_total += probability;
    }
    if (normalized_total != table_size) return error.CorruptFrame;

    buildNoLowProbabilityAssumeValid(values, entries, bases, additional_bits);
}

/// Build the same table when the normalized-count parser has already proved
/// the 256-state sum and the caller has established that no value is zero.
pub noinline fn buildNoLowProbabilityAssumeValid(
    values: []const u16,
    entries: anytype,
    bases: []const usize,
    additional_bits: []const u8,
) linksection(text_section) void {
    std.debug.assert(entries.len == 256);
    std.debug.assert(values.len <= max_sequence_symbol_count);
    std.debug.assert(values.len <= bases.len);
    std.debug.assert(values.len <= additional_bits.len);

    const table_size: usize = 256;
    const spread_step = (table_size >> 1) + (table_size >> 3) + 3;

    var position: usize = 0;
    for (values, 0..) |value, symbol| {
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
    std.debug.assert(position == 0);
}
