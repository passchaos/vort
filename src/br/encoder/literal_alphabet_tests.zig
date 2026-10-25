//! Independent literal alphabet oracle. Selection scans every eligible symbol
//! for maximum frequency/minimum byte value; no packed sort keys are shared.
const std = @import("std");

const Oracle = struct {
    ordered: [256]u16 = undefined,
    ascending: [256]u8 = undefined,
    len: usize = 0,
};

fn selectOracle(frequencies: *const [256]u32, support: []const u8) Oracle {
    var included: [256]bool = @splat(false);
    for (support) |symbol| included[symbol] = true;
    var result: Oracle = .{};
    for (0..256) |symbol| {
        if (included[symbol] and frequencies[symbol] != 0) {
            result.ascending[result.len] = @intCast(symbol);
            result.len += 1;
        }
    }
    var emitted: [256]bool = @splat(false);
    for (result.ordered[0..result.len]) |*value| {
        var best: ?usize = null;
        for (0..256) |symbol| {
            if (!included[symbol] or emitted[symbol] or frequencies[symbol] == 0) continue;
            if (best == null or frequencies[symbol] > frequencies[best.?] or
                (frequencies[symbol] == frequencies[best.?] and symbol < best.?)) best = symbol;
        }
        value.* = @intCast(best.?);
        emitted[best.?] = true;
    }
    return result;
}

fn allSymbols() [256]u8 {
    var result: [256]u8 = undefined;
    for (&result, 0..) |*symbol, value| symbol.* = @intCast(value);
    return result;
}

const Alphabet = struct { symbols: [256]u16 = @splat(0xbeef), len: usize = 251 };
const TreeSymbols = struct { symbols: [256]u8 = @splat(0xa5), len: u16 = 251 };
const GuardedAlphabet = struct {
    before: u64 = 0x0123_4567_89ab_cdef,
    value: Alphabet = .{},
    after: u64 = 0xfedc_ba98_7654_3210,
};
const GuardedTrees = struct {
    before: u64 = 0x0123_4567_89ab_cdef,
    value: TreeSymbols = .{},
    after: u64 = 0xfedc_ba98_7654_3210,
};

fn compare(comptime Codec: type, frequencies: *const [256]u32, support: []const u8, comptime fully_initialized: bool) !void {
    var supported_before: [256]u32 = undefined;
    for (support, 0..) |symbol, index| supported_before[index] = frequencies[symbol];
    // Entries outside support may be undefined in the production contract.
    // Copy or compare the complete array only for fully initialized fixtures.
    const all_before = if (fully_initialized) frequencies.* else {};
    const expected = selectOracle(frequencies, support);
    var ordered: GuardedAlphabet = .{};
    var trees: GuardedTrees = .{};
    var reference_ordered: Alphabet = .{};
    var reference_trees: TreeSymbols = .{};
    const actual = Codec.build(frequencies, support, &ordered.value, &trees.value);
    const reference = Codec.reference(frequencies, support, &reference_ordered, &reference_trees);
    if (expected.len == 0) {
        try std.testing.expectError(error.InvalidBlockPlan, actual);
        try std.testing.expectError(error.InvalidBlockPlan, reference);
    } else {
        try actual;
        try reference;
    }
    try std.testing.expectEqual(expected.len, ordered.value.len);
    try std.testing.expectEqual(@as(u16, @intCast(expected.len)), trees.value.len);
    try std.testing.expectEqual(reference_ordered.len, ordered.value.len);
    try std.testing.expectEqual(reference_trees.len, trees.value.len);
    try std.testing.expectEqualSlices(u16, expected.ordered[0..expected.len], ordered.value.symbols[0..expected.len]);
    try std.testing.expectEqualSlices(u8, expected.ascending[0..expected.len], trees.value.symbols[0..expected.len]);
    try std.testing.expectEqualSlices(u16, reference_ordered.symbols[0..expected.len], ordered.value.symbols[0..expected.len]);
    try std.testing.expectEqualSlices(u8, reference_trees.symbols[0..expected.len], trees.value.symbols[0..expected.len]);
    for (ordered.value.symbols[expected.len..]) |symbol| try std.testing.expectEqual(@as(u16, 0xbeef), symbol);
    for (trees.value.symbols[expected.len..]) |symbol| try std.testing.expectEqual(@as(u8, 0xa5), symbol);
    try std.testing.expectEqual(@as(u64, 0x0123_4567_89ab_cdef), ordered.before);
    try std.testing.expectEqual(@as(u64, 0xfedc_ba98_7654_3210), ordered.after);
    try std.testing.expectEqual(@as(u64, 0x0123_4567_89ab_cdef), trees.before);
    try std.testing.expectEqual(@as(u64, 0xfedc_ba98_7654_3210), trees.after);
    for (support, 0..) |symbol, index| try std.testing.expectEqual(supported_before[index], frequencies[symbol]);
    if (fully_initialized) try std.testing.expectEqualSlices(u32, &all_before, frequencies);
}

fn fullSupportCases(comptime Codec: type) !void {
    const support = allSymbols();
    var frequencies: [256]u32 = @splat(0);
    var random: u32 = 0x243f6a88;
    for ([_]usize{ 0, 1, 2, 7, 63, 64, 65, 127, 128, 129, 130, 255, 256 }) |active| {
        for (0..5) |pattern| {
            @memset(&frequencies, 0);
            for (0..active) |index| {
                // A permutation preserves holes and places high symbols among
                // short live prefixes while full support remains ascending.
                const symbol = (index * 149 + 41) % 256;
                random = random *% 1664525 +% 1013904223;
                frequencies[symbol] = switch (pattern) {
                    0 => 17,
                    1 => @intCast(1 + index % 7),
                    2 => @intCast(1 + index),
                    3 => std.math.maxInt(u32) - @as(u32, @intCast(index % 7)),
                    4 => @max(1, random),
                    else => unreachable,
                };
            }
            try compare(Codec, &frequencies, &support, true);
        }
    }
    // Full unsigned range is represented without narrowing into a 32-bit key.
    for (&frequencies, 0..) |*frequency, symbol| frequency.* = switch (symbol % 4) {
        0 => 1,
        1 => @as(u32, 1) << 31,
        2 => std.math.maxInt(u32) - 1,
        3 => std.math.maxInt(u32),
        else => unreachable,
    };
    try compare(Codec, &frequencies, &support, true);
    @memset(&frequencies, std.math.maxInt(u32));
    try compare(Codec, &frequencies, &support, true);
}

fn frequencyByteCases(comptime Codec: type) !void {
    const support = allSymbols();
    var frequencies: [256]u32 = undefined;
    // Vary one frequency byte at a time. The other bytes stay uniform,
    // including bytes above and below the varying byte. Repeated byte values
    // require exact symbol tie order after the skipped-digit paths.
    for (0..4) |byte| {
        const shift: u5 = @intCast(byte * 8);
        const mask = @as(u32, 0xff) << shift;
        const fixed = @as(u32, 0x8102_0301) & ~mask;
        for (&frequencies, 0..) |*frequency, symbol| {
            const varying: u32 = @intCast((symbol * 149 + 41) % 53);
            frequency.* = fixed | (varying << shift);
        }
        try compare(Codec, &frequencies, &support, true);
    }
    // Two, three and four varying bytes cover both final-buffer parities and
    // a uniform middle byte. The oracle still scans values directly.
    var random: u32 = 0x510e527f;
    for ([_]u32{ 0x00ff_00ff, 0xffff_00ff, 0xffff_ffff }) |mask| {
        for (&frequencies) |*frequency| {
            random = random *% 1664525 +% 1013904223;
            frequency.* = @max(1, (@as(u32, 0x8102_0301) & ~mask) | (random & mask));
        }
        try compare(Codec, &frequencies, &support, true);
    }
    for ([_]usize{ Codec.sort_threshold - 1, Codec.sort_threshold, Codec.sort_threshold + 1 }) |active| {
        @memset(&frequencies, 0);
        for (frequencies[0..active], 0..) |*frequency, symbol| frequency.* = @intCast(1 + (symbol * 31) % 67);
        try compare(Codec, &frequencies, support[0..active], true);
    }
}

fn filteredSupportCases(comptime Codec: type) !void {
    const all = allSymbols();
    var frequencies: [256]u32 = @splat(std.math.maxInt(u32));
    var selected: [256]bool = @splat(false);
    var support: [256]u8 = undefined;
    for ([_]usize{ 0, 1, 7, 63, 64, 65, 128, 129, 255, 256 }) |support_len| {
        @memset(&selected, false);
        for (0..support_len) |index| selected[(index * 149 + 255) % 256] = true;
        var write: usize = 0;
        for (0..256) |symbol| if (selected[symbol]) {
            support[write] = @intCast(symbol);
            write += 1;
        };
        try std.testing.expectEqual(support_len, write);
        @memset(&frequencies, std.math.maxInt(u32));
        for (support[0..support_len], 0..) |symbol, index| frequencies[symbol] = if (index % 3 == 0) 0 else @intCast(1 + index);
        // Unsupported entries are deliberately larger than every supported
        // one, but cannot enter either ordered or ascending output.
        try compare(Codec, &frequencies, support[0..support_len], true);
    }
    @memset(&frequencies, 0);
    frequencies[0] = 7;
    frequencies[255] = 7;
    try compare(Codec, &frequencies, &all, true);

    // Fully supported symbol-ascending input with inverse frequency ordering
    // exercises long movement in the legacy insertion-sort specialization.
    for (0..128) |symbol| frequencies[symbol] = @intCast(128 - symbol);
    try compare(Codec, &frequencies, all[0..128], true);

    // The caller's tree histogram can leave all non-support slots undefined.
    // The helper and its oracle must not inspect them merely to sort a key.
    var sparse: [256]u32 = undefined;
    const live = [_]u8{ 0, 17, 129, 255 };
    sparse[0] = 3;
    sparse[17] = 0;
    sparse[129] = std.math.maxInt(u32);
    sparse[255] = std.math.maxInt(u32);
    try compare(Codec, &sparse, &live, false);
    var dense_support: [129]u8 = undefined;
    for (&dense_support, 0..) |*symbol, index| {
        symbol.* = @intCast(index);
        sparse[index] = @intCast(1 + index % 5);
    }
    try compare(Codec, &sparse, &dense_support, false);
}

pub fn contracts(comptime Codec: type) !void {
    try fullSupportCases(Codec);
    try filteredSupportCases(Codec);
    try frequencyByteCases(Codec);
}
