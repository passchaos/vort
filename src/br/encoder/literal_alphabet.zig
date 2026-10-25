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
        // Symbols begin in ascending order. Stable frequency-byte passes keep
        // that tie order without an extra pass over the low symbol byte.
        keys[index] = (@as(u64, ~frequencies[symbol]) << 8) | @as(u64, symbol);
    }
    radixSortKeys(keys[0..live]);
    for (keys[0..live], 0..) |key, index| alphabet.symbols[index] = @as(u8, @truncate(key));
    alphabet.len = @intCast(live);
}

fn radixSortKeys(keys: []u64) void {
    std.debug.assert(keys.len != 0 and keys.len <= 256);
    var variation: u64 = 0;
    for (keys[1..]) |key| variation |= key ^ keys[0];

    var temporary: [256]u64 = undefined;
    var counts: [256]u16 = undefined;
    var positions: [256]u16 = undefined;
    var in_keys = true;
    for ([_]u6{ 8, 16, 24, 32 }) |shift| {
        if (variation & (@as(u64, 0xff) << shift) == 0) continue;
        const source = if (in_keys) keys else temporary[0..keys.len];
        const destination = if (in_keys) temporary[0..keys.len] else keys;
        @memset(&counts, 0);
        for (source) |key| {
            const digit: u8 = @truncate(key >> shift);
            counts[digit] += 1;
        }
        var next: u16 = 0;
        for (counts, 0..) |count, digit| {
            positions[digit] = next;
            next += count;
        }
        std.debug.assert(next == keys.len);
        // Ascending source traversal is stable within each digit. Every used
        // destination element is written before the next pass can read it.
        for (source) |key| {
            const digit: u8 = @truncate(key >> shift);
            destination[positions[digit]] = key;
            positions[digit] += 1;
        }
        in_keys = !in_keys;
    }
    if (!in_keys) @memcpy(keys, temporary[0..keys.len]);
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
