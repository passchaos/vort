const std = @import("std");
const huffman = @import("../../../huffman.zig");
const compact_tables = @import("../decoder/compact_tables.zig");

const poison: u16 = 0xffff;

fn completeAlphabet(comptime max_symbols: usize, comptime depth: u4) [max_symbols]u4 {
    var lengths: [max_symbols]u4 = @splat(0);
    // A complete tree with one leaf at each width below depth, then two
    // depth-bit leaves. Permute the symbols to exercise bucketed entry order,
    // retain absent symbols, and include the highest symbol in every fixture.
    for (0..@as(usize, depth) + 1) |index| {
        const symbol = max_symbols - 1 - (index * 7 % max_symbols);
        lengths[symbol] = @intCast(@min(index + 1, depth));
    }
    return lengths;
}

fn expectCanonicalLookup(
    comptime lookup_bits: u4,
    comptime max_symbols: usize,
    lengths: []const u4,
    lookup: *[@as(usize, 1) << lookup_bits]u16,
) !void {
    try std.testing.expect(compact_tables.validDynamicAlphabet(lengths));
    const table = try huffman.HuffmanTable(max_symbols).init(lengths);
    var reference: [@as(usize, 1) << lookup_bits]u16 = @splat(poison);
    compact_tables.buildCanonicalLookup(lookup_bits, &reference, lengths);
    compact_tables.buildLookupFromTable(lookup_bits, max_symbols, lookup, &table);
    try std.testing.expectEqualSlices(u16, &reference, lookup);
    try std.testing.expectEqual(null, std.mem.indexOfScalar(u16, lookup, poison));
    for (lookup) |entry| {
        if (entry == 0) continue;
        const symbol = (entry >> 4) - 1;
        const bits = entry & 15;
        try std.testing.expect(symbol < lengths.len);
        try std.testing.expect(bits != 0 and bits <= lookup_bits);
        try std.testing.expectEqual(@as(u16, lengths[symbol]), bits);
    }
}

test "compact lookup matches complete short canonical alphabets" {
    inline for (.{ 7, 10, 11 }) |lookup_bits| {
        inline for (.{ 19, 30, 32, 286 }) |max_symbols| {
            const lengths = completeAlphabet(max_symbols, lookup_bits);
            var lookup: [@as(usize, 1) << lookup_bits]u16 = @splat(poison);
            try expectCanonicalLookup(lookup_bits, max_symbols, &lengths, &lookup);
            // All short codes fit the primary, including those exactly as
            // wide as the lookup. Every primary slot must be populated.
            try std.testing.expectEqual(@as(usize, 0), std.mem.count(u16, &lookup, &.{0}));
            const highest_symbol_entry: u16 = (max_symbols << 4) | 1;
            try std.testing.expect(std.mem.indexOfScalar(u16, &lookup, highest_symbol_entry) != null);
        }
    }
}

test "compact lookup matches incomplete singleton canonical alphabets" {
    inline for (.{ 7, 10, 11 }) |lookup_bits| {
        inline for (.{ 19, 30, 32, 286 }) |max_symbols| {
            var lengths: [max_symbols]u4 = @splat(0);
            lengths[max_symbols - 1] = 1;
            var lookup: [@as(usize, 1) << lookup_bits]u16 = @splat(poison);
            try expectCanonicalLookup(lookup_bits, max_symbols, &lengths, &lookup);
            try std.testing.expectEqual(lookup.len / 2, std.mem.count(u16, &lookup, &.{0}));
            const singleton_entry: u16 = (max_symbols << 4) | 1;
            for (lookup, 0..) |entry, index| {
                try std.testing.expectEqual(@as(u16, if (index & 1 == 0) singleton_entry else 0), entry);
            }
        }
    }
}

test "compact lookup matches sparse canonical alphabets with 15-bit tails" {
    inline for (.{ 7, 10, 11 }) |lookup_bits| {
        inline for (.{ 19, 30, 32, 286 }) |max_symbols| {
            const lengths = completeAlphabet(max_symbols, 15);
            const table = try huffman.HuffmanTable(max_symbols).init(&lengths);
            try std.testing.expectEqual(@as(u4, 15), table.max_bits);
            try std.testing.expectEqual(@as(usize, 16), table.len);
            try std.testing.expectEqual(@as(u16, 2), table.count_by_bits[15]);
            var lookup: [@as(usize, 1) << lookup_bits]u16 = @splat(poison);
            try expectCanonicalLookup(lookup_bits, max_symbols, &lengths, &lookup);
            // The one uncovered prefix belongs to codes wider than the
            // primary and must remain a miss for the long-code fallback.
            try std.testing.expectEqual(@as(usize, 1), std.mem.count(u16, &lookup, &.{0}));
        }
    }
}

test "compact lookup reuse clears poisoned and previous alphabet slots" {
    inline for (.{ 7, 10, 11 }) |lookup_bits| {
        inline for (.{ 19, 30, 32, 286 }) |max_symbols| {
            var lookup: [@as(usize, 1) << lookup_bits]u16 = @splat(poison);
            const complete = completeAlphabet(max_symbols, lookup_bits);
            try expectCanonicalLookup(lookup_bits, max_symbols, &complete, &lookup);

            const long = completeAlphabet(max_symbols, 15);
            try expectCanonicalLookup(lookup_bits, max_symbols, &long, &lookup);
            try std.testing.expectEqual(@as(usize, 1), std.mem.count(u16, &lookup, &.{0}));

            var singleton: [max_symbols]u4 = @splat(0);
            singleton[max_symbols - 1] = 1;
            try expectCanonicalLookup(lookup_bits, max_symbols, &singleton, &lookup);
            try std.testing.expectEqual(lookup.len / 2, std.mem.count(u16, &lookup, &.{0}));

            // Reuse once more with a shorter lengths slice and another symbol.
            // The previous high symbol must disappear from every packed entry.
            try expectCanonicalLookup(lookup_bits, max_symbols, &.{1}, &lookup);
            const previous_entry: u16 = (max_symbols << 4) | 1;
            try std.testing.expectEqual(null, std.mem.indexOfScalar(u16, &lookup, previous_entry));
            try std.testing.expectEqual(lookup.len / 2, std.mem.count(u16, &lookup, &.{0}));
            try std.testing.expectEqual(lookup.len / 2, std.mem.count(u16, &lookup, &.{0x11}));
        }
    }
}
