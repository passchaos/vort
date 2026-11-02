const std = @import("std");

/// Small no-low tables retain only symbols and their ascending next state.
/// The normalized-count parser owns admission and the total-probability check.
pub noinline fn buildAssumeValid(
    values: []const u16,
    entries: anytype,
    bases: []const usize,
    additional_bits: []const u8,
) void {
    std.debug.assert(entries.len == 64 or entries.len == 128);
    std.debug.assert(values.len != 0 and values.len <= 53);
    std.debug.assert(values.len <= bases.len and values.len <= additional_bits.len);
    const table_size: u16 = @intCast(entries.len);
    const table_log: u8 = 6 + @as(u8, @intFromBool(entries.len == 128));
    const spread_step = (entries.len >> 1) + (entries.len >> 3) + 3;
    const state_mask = entries.len - 1;
    var symbols: [128]u8 = undefined;
    var next: [53]u16 = undefined;
    var total: usize = 0;
    var position: usize = 0;
    for (values, 0..) |value, symbol| {
        std.debug.assert(value != 0);
        const probability = value - 1;
        std.debug.assert(probability <= entries.len - total);
        total += probability;
        if (probability == 0) continue;
        next[symbol] = probability;
        for (0..probability) |_| {
            symbols[position] = @intCast(symbol);
            position = (position + spread_step) & state_mask;
        }
    }
    std.debug.assert(total == entries.len and position == 0);
    for (entries, symbols[0..entries.len]) |*entry, symbol| {
        const next_state = next[symbol];
        next[symbol] += 1;
        const state_bits = table_log - std.math.log2_int(u16, next_state);
        entry.* = .{
            .base = @intCast(bases[symbol]),
            .additional_bits = additional_bits[symbol],
            .next_state = @intCast((@as(u32, next_state) << @intCast(state_bits)) - table_size),
            .state_bits = state_bits,
        };
    }
}
