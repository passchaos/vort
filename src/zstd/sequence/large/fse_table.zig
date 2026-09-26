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
/// Fill symbols contiguously first, then spread them with one fixed-trip loop.
/// This mirrors libzstd's no-low-probability construction and avoids a
/// variable-trip spread loop for every symbol.
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

    // Eight spare bytes make the final vector store safe even when the last
    // symbol has fewer than eight states. Later symbols overwrite the excess.
    var symbols: [table_size + 8]u8 = undefined;
    var symbol_next: [max_sequence_symbol_count]u16 = undefined;
    var symbol_offset: usize = 0;
    for (values, 0..) |value, symbol| {
        const probability: usize = value - 1;
        symbol_next[symbol] = @intCast(probability);
        const repeated: @Vector(8, u8) = @splat(@intCast(symbol));
        symbols[symbol_offset..][0..8].* = repeated;
        var filled: usize = 8;
        while (filled < probability) : (filled += 8) {
            symbols[symbol_offset + filled ..][0..8].* = repeated;
        }
        symbol_offset += probability;
    }
    std.debug.assert(symbol_offset == table_size);

    const table_mask = table_size - 1;
    var position: usize = 0;
    var source_index: usize = 0;
    while (source_index < table_size) : (source_index += 2) {
        const second_position = (position + spread_step) & table_mask;
        entries[position].base = symbols[source_index];
        entries[second_position].base = symbols[source_index + 1];
        position = (position + 2 * spread_step) & table_mask;
    }
    std.debug.assert(position == 0);

    for (entries) |*entry| {
        const symbol: usize = @intCast(entry.base);
        const next_state = symbol_next[symbol];
        std.debug.assert(next_state != 0);
        symbol_next[symbol] += 1;
        const state_bits: u8 = 8 - std.math.log2_int(u16, next_state);
        entry.* = .{
            .base = @intCast(bases[symbol]),
            .additional_bits = additional_bits[symbol],
            .next_state = @intCast((@as(u32, next_state) << @intCast(state_bits)) - table_size),
            .state_bits = state_bits,
        };
    }
}
