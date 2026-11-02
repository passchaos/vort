//! Compact primary lookups and canonical-code helpers for the resumable
//! Deflate decoder, including its dynamic code-length alphabet.

const huffman = @import("../../../huffman.zig");

/// Expand already validated canonical entries into a primary lookup. The
/// resumable decoder also retains these entries for long-code misses, so
/// recounting lengths and reversing the same canonical codes is unnecessary.
pub fn buildLookupFromTable(
    comptime lookup_bits: u4,
    comptime max_symbols: usize,
    lookup: *[@as(usize, 1) << lookup_bits]u16,
    table: *const huffman.HuffmanTable(max_symbols),
) void {
    @memset(lookup, 0);
    for (table.entries[0..table.len]) |entry| {
        if (entry.bits > lookup_bits) continue;
        const lookup_entry: u16 = ((entry.symbol + 1) << 4) | entry.bits;
        const fill = @as(usize, 1) << @intCast(lookup_bits - entry.bits);
        for (0..fill) |suffix|
            lookup[entry.code | (suffix << entry.bits)] = lookup_entry;
    }
}

pub fn buildCanonicalLookup(
    comptime lookup_bits: u4,
    lookup: *[@as(usize, 1) << lookup_bits]u16,
    lengths: []const u4,
) void {
    @memset(lookup, 0);
    var counts: [16]u16 = @splat(0);
    for (lengths) |bits| if (bits != 0) {
        counts[bits] += 1;
    };
    var next: [16]u16 = @splat(0);
    var code: u16 = 0;
    for (1..16) |bits| {
        code = (code + counts[bits - 1]) << 1;
        next[bits] = code;
    }
    for (lengths, 0..) |bits, symbol| {
        if (bits == 0) continue;
        const canonical = next[bits];
        next[bits] += 1;
        if (bits > lookup_bits) continue;
        const shift: u4 = @intCast(@as(u5, 16) - @as(u5, bits));
        const reversed = @bitReverse(canonical) >> shift;
        const lookup_entry: u16 = ((@as(u16, @intCast(symbol)) + 1) << 4) | bits;
        const fill = @as(usize, 1) << @intCast(lookup_bits - bits);
        for (0..fill) |suffix|
            lookup[reversed | (suffix << bits)] = lookup_entry;
    }
}

pub fn validCodeLengthAlphabet(lengths: [19]u4) bool {
    var counts: [8]usize = @splat(0);
    var active: usize = 0;
    for (lengths) |length| {
        if (length > 7) return false;
        if (length != 0) {
            counts[length] += 1;
            active += 1;
        }
    }
    if (active == 0) return false;
    var available: isize = 1;
    for (1..8) |bits| {
        available = available * 2 - @as(isize, @intCast(counts[bits]));
        if (available < 0) return false;
    }
    return true;
}

pub fn validDynamicAlphabet(lengths: []const u4) bool {
    var counts: [16]usize = @splat(0);
    var active: usize = 0;
    for (lengths) |length| {
        if (length > 15) return false;
        if (length != 0) {
            counts[length] += 1;
            active += 1;
        }
    }
    if (active == 0) return false;
    if (active == 1) return true; // RFC permits one-bit incomplete singleton.
    var available: isize = 1;
    for (1..16) |bits| {
        available = available * 2 - @as(isize, @intCast(counts[bits]));
        if (available < 0) return false;
    }
    return available == 0;
}

/// Entries are grouped by code width, so long-code lookup only scans the
/// symbols whose width can match the staged code.
pub inline fn tableSymbol(
    comptime max_symbols: usize,
    table: *const huffman.HuffmanTable(max_symbols),
    wanted_code: u16,
    wanted_bits: u4,
) ?u16 {
    const first = table.first_by_bits[wanted_bits];
    const end = first + table.count_by_bits[wanted_bits];
    var index: usize = first;
    while (index < end) : (index += 1) {
        const entry = table.entries[index];
        if (entry.code == wanted_code) return entry.symbol;
    }
    return null;
}

pub fn canonicalSymbol(lengths: []const u4, wanted_code: u16, wanted_bits: u4) ?u16 {
    var counts: [16]u16 = @splat(0);
    for (lengths) |length| if (length != 0) {
        counts[length] += 1;
    };
    var next: [16]u16 = @splat(0);
    var code: u16 = 0;
    for (1..16) |bits| {
        code = (code + counts[bits - 1]) << 1;
        next[bits] = code;
    }
    for (lengths, 0..) |bits, symbol| {
        if (bits == 0) continue;
        const shift: u4 = @intCast(@as(u5, 16) - @as(u5, bits));
        const reversed = @bitReverse(next[bits]) >> shift;
        next[bits] += 1;
        if (bits == wanted_bits and reversed == wanted_code) return @intCast(symbol);
    }
    return null;
}
