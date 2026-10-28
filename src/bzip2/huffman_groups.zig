//! Pure Huffman group seeding and chunk assignments, without owned storage.
const std = @import("std");
const bounded = @import("huffman_lengths.zig");
pub const group_size: usize = 50;
pub const max_groups: usize = 6;
pub const max_symbols = bounded.max_symbols;
pub const Lengths = [max_groups][max_symbols]u5;
pub const Frequencies = [max_groups][max_symbols]u32;

pub fn buildLengths(frequencies: []const u32, lengths: []u5) error{InvalidBzip2Stream}!void {
    // Shape was checked before any allocation; keep internal builder errors
    // within the encoder's existing error contract.
    bounded.build(frequencies, lengths) catch return error.InvalidBzip2Stream;
}

pub fn sameLengths(left: *const Lengths, right: *const Lengths, alpha_size: usize, group_count: usize) bool {
    for (0..group_count) |group|
        if (!std.mem.eql(u5, left[group][0..alpha_size], right[group][0..alpha_size])) return false;
    return true;
}

pub fn seed(lengths: *Lengths, totals: *const [max_symbols]u32, alpha_size: usize, group_count: usize, symbols: []const u16) !bool {
    if (group_count <= alpha_size) {
        seedAlphabet(lengths, totals, alpha_size, group_count, symbols.len);
        return false;
    }
    // Narrow alphabets can still benefit from more Huffman groups than
    // symbols. Seed those groups from consecutive 50-symbol chunk regions.
    lengths.* = @splat(@splat(0));
    var frequencies: Frequencies = @splat(@splat(0));
    const chunks = (symbols.len + group_size - 1) / group_size;
    for (0..group_count) |group| {
        const first = (chunks * group / group_count) * group_size;
        const end = @min(symbols.len, (chunks * (group + 1) / group_count) * group_size);
        for (symbols[first..end]) |symbol| frequencies[group][symbol] += 1;
        try buildLengths(frequencies[group][0..alpha_size], lengths[group][0..alpha_size]);
    }
    return true;
}

fn seedAlphabet(lengths: *Lengths, totals: *const [max_symbols]u32, alpha_size: usize, group_count: usize, symbol_count: usize) void {
    lengths.* = @splat(@splat(0));
    var first: usize = 0;
    var remaining = symbol_count;
    for (0..group_count) |group| {
        @memset(lengths[group][0..alpha_size], bounded.max_bits);
        const target = remaining / (group_count - group);
        var weight: usize = 0;
        var end = first;
        const last_end = alpha_size - (group_count - group - 1);
        while (end < last_end and (end == first or weight < target)) : (end += 1)
            weight += totals[end];
        @memset(lengths[group][first..end], 0);
        first = end;
        remaining -= weight;
    }
}

pub fn assign(comptime price_selectors: bool, symbols: []const u16, lengths: *const Lengths, alpha_size: usize, group_count: usize, selectors: []u8, frequencies: *Frequencies) u64 {
    frequencies.* = @splat(@splat(0));
    // Identical tables have identical prices. Keep only their lowest-index
    // representative, preserving the ordinary cost tie without repeated work.
    var active_groups: [max_groups]u8 = undefined;
    var active_count: usize = 0;
    for (0..group_count) |group| {
        var duplicate = false;
        if (!price_selectors) for (active_groups[0..active_count]) |previous| {
            if (std.mem.eql(u5, lengths[group][0..alpha_size], lengths[previous][0..alpha_size])) {
                duplicate = true;
                break;
            }
        };
        if (!duplicate) {
            active_groups[active_count] = @intCast(group);
            active_count += 1;
        }
    }
    var data_bits: u64 = 0;
    var mtf: [max_groups]u8 = .{ 0, 1, 2, 3, 4, 5 };
    for (selectors, 0..) |*selector, chunk| {
        const start = chunk * group_size;
        const part = symbols[start..@min(symbols.len, start + group_size)];
        var counts: [max_symbols]u16 = @splat(0);
        var active_symbols: [group_size]u16 = undefined;
        var active_symbol_count: usize = 0;
        for (part) |symbol| {
            if (counts[symbol] == 0) {
                active_symbols[active_symbol_count] = symbol;
                active_symbol_count += 1;
            }
            counts[symbol] += 1;
        }
        var chosen: u8 = active_groups[0];
        var lowest: u32 = std.math.maxInt(u32);
        var chosen_payload: u32 = 0;
        var chosen_rank: usize = 0;
        for (active_groups[0..active_count]) |group| {
            var cost: u32 = 0;
            for (active_symbols[0..active_symbol_count]) |symbol|
                cost += @as(u32, counts[symbol]) * lengths[group][symbol];
            const rank = if (price_selectors) std.mem.indexOfScalar(u8, mtf[0..group_count], group).? else 0;
            const total_cost = cost + if (price_selectors) @as(u32, @intCast(rank + 1)) else 0;
            if (total_cost < lowest) {
                lowest = total_cost;
                chosen = group;
                chosen_payload = cost;
                chosen_rank = rank;
            }
        }
        selector.* = chosen;
        data_bits += chosen_payload;
        if (price_selectors) moveToFront(&mtf, chosen_rank);
        for (active_symbols[0..active_symbol_count]) |symbol|
            frequencies[chosen][symbol] += counts[symbol];
    }
    return data_bits;
}

pub fn moveToFront(mtf: *[max_groups]u8, position: usize) void {
    const group = mtf[position];
    var index = position;
    while (index != 0) : (index -= 1) mtf[index] = mtf[index - 1];
    mtf[0] = group;
}
