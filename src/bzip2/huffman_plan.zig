//! Deterministic, block-bounded adaptive Huffman group planning.
const std = @import("std");
const groups = @import("huffman_groups.zig");

pub const group_size = groups.group_size;
pub const max_groups = groups.max_groups;
pub const max_symbols = groups.max_symbols;
const Lengths = groups.Lengths;
const Frequencies = groups.Frequencies;

pub const Strategy = enum {
    /// Global adaptive/uniform trees and the fixed fallback, without training.
    fast,
    /// Four trained passes at the standard 2...6 group-count thresholds.
    balanced,
    /// Preserve the balanced result and also search every other group count.
    ratio,
};

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
    return planAllocWithStrategy(allocator, symbols, alpha_size, .balanced);
}

pub fn planAllocWithStrategy(allocator: std.mem.Allocator, symbols: []const u16, alpha_size: usize, strategy: Strategy) !Plan {
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
    try groups.buildLengths(totals[0..alpha_size], lengths[0][0..alpha_size]);
    lengths[1] = lengths[0];
    @memset(trial_selectors, 0);
    var global_bits: u64 = 0;
    for (totals[0..alpha_size], lengths[0][0..alpha_size]) |count, length|
        global_bits += @as(u64, count) * length;
    consider(&best, &lengths, 2, trial_selectors, global_bits);

    var all_singles = true;
    for (totals[0..alpha_size]) |count| if (count > 1) {
        all_singles = false;
        break;
    };
    // Uniform positive weights are a distinct cheap candidate when the
    // alphabet is not a power of two; evaluate its full table/data cost too.
    if (!all_singles) {
        const uniform: [max_symbols]u32 = @splat(0);
        try groups.buildLengths(uniform[0..alpha_size], lengths[0][0..alpha_size]);
        lengths[1] = lengths[0];
        global_bits = 0;
        for (totals[0..alpha_size], lengths[0][0..alpha_size]) |count, length|
            global_bits += @as(u64, count) * length;
        consider(&best, &lengths, 2, trial_selectors, global_bits);
    }
    refineSelectors(&best, symbols, trial_selectors);

    // One chunk assigns every symbol to one table: trained tables can only be
    // the global or uniform model, both already considered. If all counts are
    // 0/1, smoothing makes every possible trained table uniformly weighted.
    if (strategy == .fast or selector_count == 1 or all_singles) return best;
    const limit = @min(max_groups, @max(2, selector_count));
    const preferred = @min(preferredGroups(symbols.len), limit);
    try train(&best, symbols, &totals, preferred, trial_selectors);
    refineSelectors(&best, symbols, trial_selectors);
    if (strategy == .ratio) {
        // Start from the complete balanced result, including its selector
        // refinement. Later candidates only decrease its complete wire cost.
        for (2..limit + 1) |group_count| {
            if (group_count == preferred) continue;
            try train(&best, symbols, &totals, group_count, trial_selectors);
        }
        refineSelectors(&best, symbols, trial_selectors);
    }
    return best;
}

fn preferredGroups(symbol_count: usize) usize {
    return if (symbol_count < 200) 2 else if (symbol_count < 600) 3 else if (symbol_count < 1200) 4 else if (symbol_count < 2400) 5 else 6;
}

fn train(best: *Plan, symbols: []const u16, totals: *const [max_symbols]u32, group_count: usize, selectors: []u8) !void {
    var lengths: Lengths = undefined;
    const seeded_tables = try groups.seed(&lengths, totals, best.alpha_size, group_count, symbols);
    var frequencies: Frequencies = undefined;
    for (0..5) |round| {
        const data_bits = groups.assign(false, symbols, &lengths, best.alpha_size, group_count, selectors, &frequencies);
        if (round != 0 or seeded_tables) consider(best, &lengths, group_count, selectors, data_bits);
        if (round == 4) break;
        var next: Lengths = @splat(@splat(0));
        for (0..group_count) |group|
            try groups.buildLengths(frequencies[group][0..best.alpha_size], next[group][0..best.alpha_size]);
        if (round != 0 and groups.sameLengths(&lengths, &next, best.alpha_size, group_count)) break;
        lengths = next;
    }
}

fn fixedWidth(alpha_size: usize) u5 {
    var width: u5 = 1;
    var capacity: usize = 2;
    while (capacity < alpha_size) : (width += 1) capacity *= 2;
    return width;
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
        const data_bits = groups.assign(true, symbols, &plan.lengths, plan.alpha_size, plan.group_count, scratch, &frequencies);
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

pub const moveToFront = groups.moveToFront;

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
