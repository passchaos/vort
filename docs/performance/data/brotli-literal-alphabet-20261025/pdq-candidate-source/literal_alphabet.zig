//! Exact literal alphabet ranking through a symbol-ascending parent support.
//! Only supported frequency entries are read; the rest of the array may be
//! uninitialized. Outputs own fixed symbol arrays and len fields, and only
//! their live prefixes are written. No scorer, allocator or input is retained.
const std = @import("std");

pub const Error = error{InvalidBlockPlan};
pub const sort_threshold: usize = 64;

/// Outputs must hold all 256 byte symbols and len must represent 256. Support
/// is strictly ascending and unique. The alphabet is frequency-descending with
/// symbol-ascending ties; tree_symbols is the filtered ascending support.
pub fn build(frequencies: *const [256]u32, support: []const u8, alphabet: anytype, tree_symbols: anytype) Error!void {
    if (support.len < sort_threshold) return reference(frequencies, support, alphabet, tree_symbols);
    return buildLargeSupport(frequencies, support, alphabet, tree_symbols);
}

/// Keep the key workspace out of the common small-support caller frame.
noinline fn buildLargeSupport(frequencies: *const [256]u32, support: []const u8, alphabet: anytype, tree_symbols: anytype) Error!void {
    alphabet.len = 0;
    tree_symbols.len = 0;
    var previous_symbol: ?u8 = null;
    var previous_frequency: u32 = std.math.maxInt(u32);
    var already_ordered = true;
    for (support) |symbol| {
        if (previous_symbol) |previous| std.debug.assert(previous < symbol);
        previous_symbol = symbol;
        const frequency = frequencies[symbol];
        if (frequency == 0) continue;
        tree_symbols.symbols[tree_symbols.len] = symbol;
        tree_symbols.len += 1;
        if (frequency > previous_frequency) already_ordered = false;
        previous_frequency = frequency;
    }
    const live: usize = tree_symbols.len;
    if (live == 0) return error.InvalidBlockPlan;
    if (already_ordered) {
        // Ascending support also resolves equal-frequency ties, so no keys or
        // sort are needed when the live frequencies already descend.
        for (tree_symbols.symbols[0..live], 0..) |symbol, index| alphabet.symbols[index] = symbol;
        alphabet.len = @intCast(live);
        return;
    }
    if (live < sort_threshold) {
        for (tree_symbols.symbols[0..live]) |symbol| {
            const frequency = frequencies[symbol];
            var index = alphabet.len;
            while (index != 0 and frequency > frequencies[alphabet.symbols[index - 1]]) : (index -= 1)
                alphabet.symbols[index] = alphabet.symbols[index - 1];
            alphabet.symbols[index] = symbol;
            alphabet.len += 1;
        }
        return;
    }

    var keys: [256]u64 = undefined;
    for (tree_symbols.symbols[0..live], 0..) |symbol, index| {
        // Widen the complemented complete u32 frequency before shifting.
        // The low eight bits uniquely identify the symbol, so all keys are
        // distinct and unstable sorting still has one deterministic result.
        keys[index] = (@as(u64, ~frequencies[symbol]) << 8) | @as(u64, symbol);
    }
    std.mem.sortUnstable(u64, keys[0..live], {}, std.sort.asc(u64));
    for (keys[0..live], 0..) |key, index| alphabet.symbols[index] = @as(u8, @truncate(key));
    alphabet.len = @intCast(live);
}

/// Original fused insertion policy, available for complete shape oracles and
/// benchmarks. Inactive output tails and unsupported frequencies are untouched.
pub fn reference(frequencies: *const [256]u32, support: []const u8, alphabet: anytype, tree_symbols: anytype) Error!void {
    alphabet.len = 0;
    tree_symbols.len = 0;
    var previous_symbol: ?u8 = null;
    for (support) |symbol| {
        if (previous_symbol) |previous| std.debug.assert(previous < symbol);
        previous_symbol = symbol;
        const frequency = frequencies[symbol];
        if (frequency == 0) continue;
        tree_symbols.symbols[tree_symbols.len] = symbol;
        tree_symbols.len += 1;

        if (alphabet.len == alphabet.symbols.len) return error.InvalidBlockPlan;
        var index = alphabet.len;
        while (index != 0 and frequency > frequencies[alphabet.symbols[index - 1]]) : (index -= 1)
            alphabet.symbols[index] = alphabet.symbols[index - 1];
        alphabet.symbols[index] = symbol;
        alphabet.len += 1;
    }
    if (alphabet.len == 0) return error.InvalidBlockPlan;
    std.debug.assert(alphabet.len == tree_symbols.len);
}

test "literal alphabet exact supported rank and output contracts" {
    try @import("literal_alphabet_tests.zig").contracts(@This());
}
