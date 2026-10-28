//! Deterministic, block-bounded adaptive Huffman group planning.
const std = @import("std");
const bounded = @import("huffman_lengths.zig");

pub const group_size: usize = 50;
pub const max_groups: usize = 6;
pub const max_symbols: usize = 258;
const Lengths = [max_groups][max_symbols]u5;
const Frequencies = [max_groups][max_symbols]u32;

pub const Plan = struct {
    group_count: u3,
    alpha_size: usize,
    lengths: Lengths,
    codes: [max_groups][max_symbols]u32,
    selectors: []u8,
    /// Complete group-count, selector-count, selector, table and data bit cost.
    bit_len: u64,

    pub fn deinit(self: Plan, allocator: std.mem.Allocator) void {
        allocator.free(self.selectors);
    }
};

pub fn planAlloc(allocator: std.mem.Allocator, symbols: []const u16, alpha_size: usize) !Plan {
    if (alpha_size < 3 or alpha_size > max_symbols or symbols.len == 0 or symbols.len > 900_001)
        return error.InvalidBzip2Stream;
    var totals: [max_symbols]u32 = @splat(0);
    for (symbols) |symbol| {
        if (symbol >= alpha_size) return error.InvalidBzip2Stream;
        totals[symbol] += 1;
    }
    const selector_count = (symbols.len + group_size - 1) / group_size;
    const selectors = try allocator.alloc(u8, selector_count);
    errdefer allocator.free(selectors);
    @memset(selectors, 0);
    const trial_selectors = try allocator.alloc(u8, selector_count);
    defer allocator.free(trial_selectors);

    var best: Plan = .{
        .group_count = 2,
        .alpha_size = alpha_size,
        .lengths = @splat(@splat(0)),
        .codes = undefined,
        .selectors = selectors,
        .bit_len = 0,
    };
    const width = fixedWidth(alpha_size);
    @memset(best.lengths[0][0..alpha_size], width);
    best.lengths[1] = best.lengths[0];
    best.bit_len = 18 + selector_count + 2 * (5 + alpha_size) + @as(u64, symbols.len) * width;

    // A global adaptive model is cheap and remains competitive on stationary
    // and small blocks. Two identical tables are required by the wire format.
    var lengths: Lengths = @splat(@splat(0));
    try buildLengths(totals[0..alpha_size], lengths[0][0..alpha_size]);
    lengths[1] = lengths[0];
    @memset(trial_selectors, 0);
    var global_bits: u64 = 0;
    for (totals[0..alpha_size], lengths[0][0..alpha_size]) |count, length|
        global_bits += @as(u64, count) * length;
    consider(&best, &lengths, 2, trial_selectors, global_bits);

    const limit = @min(max_groups, @min(alpha_size, @max(2, selector_count)));
    for (2..limit + 1) |group_count| {
        seedAlphabet(&lengths, &totals, alpha_size, group_count, symbols.len);
        var frequencies: Frequencies = undefined;
        for (0..5) |round| {
            const data_bits = assign(false, symbols, &lengths, alpha_size, group_count, trial_selectors, &frequencies);
            // Initial partition prices are not Huffman tables. All subsequent
            // rounds have bounded positive code lengths and can be emitted.
            if (round != 0) consider(&best, &lengths, group_count, trial_selectors, data_bits);
            if (round == 4) break;
            var next: Lengths = @splat(@splat(0));
            for (0..group_count) |group|
                try buildLengths(frequencies[group][0..alpha_size], next[group][0..alpha_size]);
            if (round != 0 and sameLengths(&lengths, &next, alpha_size, group_count)) {
                // Assignments and prices are now stable; a further round is
                // identical, including the deterministic lowest-group tie.
                break;
            }
            lengths = next;
        }
    }
    refineSelectors(&best, symbols, trial_selectors);
    return best;
}

fn buildLengths(frequencies: []const u32, lengths: []u5) error{InvalidBzip2Stream}!void {
    // Shape was checked before any allocation; keep internal builder errors
    // within the encoder's existing error contract.
    bounded.build(frequencies, lengths) catch return error.InvalidBzip2Stream;
}

fn sameLengths(left: *const Lengths, right: *const Lengths, alpha_size: usize, group_count: usize) bool {
    for (0..group_count) |group|
        if (!std.mem.eql(u5, left[group][0..alpha_size], right[group][0..alpha_size])) return false;
    return true;
}

fn fixedWidth(alpha_size: usize) u5 {
    var width: u5 = 1;
    var capacity: usize = 2;
    while (capacity < alpha_size) : (width += 1) capacity *= 2;
    return width;
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

fn assign(comptime price_selectors: bool, symbols: []const u16, lengths: *const Lengths, alpha_size: usize, group_count: usize, selectors: []u8, frequencies: *Frequencies) u64 {
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

/// A final selector-aware greedy candidate on the winning compact tables.
/// Scratch must be distinct from the plan's owned selectors. Whole-wire cost
/// evaluation preserves the previous candidate when this local policy loses.
pub fn refineSelectors(plan: *Plan, symbols: []const u16, scratch: []u8) void {
    std.debug.assert(scratch.len == plan.selectors.len and scratch.ptr != plan.selectors.ptr);
    var distinct = false;
    for (1..plan.group_count) |group|
        if (!std.mem.eql(u5, plan.lengths[0][0..plan.alpha_size], plan.lengths[group][0..plan.alpha_size])) {
            distinct = true;
            break;
        };
    if (distinct) {
        var frequencies: Frequencies = undefined;
        const data_bits = assign(true, symbols, &plan.lengths, plan.alpha_size, plan.group_count, scratch, &frequencies);
        consider(plan, &plan.lengths, plan.group_count, scratch, data_bits);
    }
    buildCodes(plan);
}

fn consider(best: *Plan, lengths: *const Lengths, group_count: usize, selectors: []const u8, data_bits: u64) void {
    var used: [max_groups]bool = @splat(false);
    for (selectors) |group| used[group] = true;
    var mapping: [max_groups]u8 = @splat(0);
    var compact: Lengths = @splat(@splat(0));
    var count: usize = 0;
    for (0..group_count) |group| if (used[group]) {
        mapping[group] = @intCast(count);
        compact[count] = lengths[group];
        count += 1;
    };
    if (count == 1) {
        compact[1] = compact[0];
        count = 2;
    }
    var bits: u64 = 18 + data_bits;
    for (0..count) |group| bits += tableBits(compact[group][0..best.alpha_size]);
    var mtf: [max_groups]u8 = .{ 0, 1, 2, 3, 4, 5 };
    for (selectors) |old_group| {
        const group = mapping[old_group];
        var position: usize = 0;
        while (mtf[position] != group) : (position += 1) {}
        bits += position + 1;
        moveToFront(&mtf, position);
    }
    if (bits >= best.bit_len) return;
    best.bit_len = bits;
    best.group_count = @intCast(count);
    best.lengths = compact;
    for (selectors, best.selectors) |group, *selected| selected.* = mapping[group];
}

pub fn tableBits(lengths: []const u5) u64 {
    var bits: u64 = 5;
    var previous: i32 = lengths[0];
    for (lengths) |length| {
        const current: i32 = length;
        bits += 1 + 2 * @as(u32, @intCast(@abs(current - previous)));
        previous = current;
    }
    return bits;
}

pub fn moveToFront(mtf: *[max_groups]u8, position: usize) void {
    const group = mtf[position];
    var index = position;
    while (index != 0) : (index -= 1) mtf[index] = mtf[index - 1];
    mtf[0] = group;
}

fn buildCodes(plan: *Plan) void {
    for (0..plan.group_count) |group| {
        var counts: [21]u32 = @splat(0);
        for (plan.lengths[group][0..plan.alpha_size]) |length| counts[length] += 1;
        var next: [21]u32 = @splat(0);
        var code: u32 = 0;
        for (1..next.len) |bits| {
            code = (code + counts[bits - 1]) << 1;
            next[bits] = code;
        }
        for (plan.lengths[group][0..plan.alpha_size], plan.codes[group][0..plan.alpha_size]) |length, *value| {
            value.* = next[length];
            next[length] += 1;
        }
    }
}
