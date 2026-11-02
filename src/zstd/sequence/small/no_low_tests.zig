const std = @import("std");
const kernel = @import("compact_no_low.zig");

const Mapped = struct {
    base: u32,
    additional_bits: u8,
    next_state: u16,
    state_bits: u8,
};

fn expectMatches(comptime Scalar: type, values: []const u16, entries: anytype) !void {
    var raw: [128]Scalar.Entry = undefined;
    try Scalar.build(values, raw[0..entries.len]);

    // Absent symbols must not read mappings or stale template scratch. A
    // narrowing cast of their bases would fail in safety-enabled builds.
    var bases: [53]usize = undefined;
    var additional_bits: [53]u8 = undefined;
    for (&bases, &additional_bits, 0..) |*base, *bit_count, symbol| {
        base.* = 0xf103_070b + symbol * 0x0001_0101;
        bit_count.* = @intCast(symbol % 32);
    }
    for (values, 0..) |value, symbol| {
        if (value == 1) bases[symbol] = std.math.maxInt(usize);
    }
    kernel.buildAssumeValid(values, entries, bases[0..values.len], additional_bits[0..values.len]);
    for (raw[0..entries.len], entries) |expected, actual| {
        try std.testing.expectEqual(@as(u32, @intCast(bases[expected.symbol])), actual.base);
        try std.testing.expectEqual(additional_bits[expected.symbol], actual.additional_bits);
        try std.testing.expectEqual(expected.baseline, actual.next_state);
        try std.testing.expectEqual(expected.bits, actual.state_bits);
    }
}

fn expectGuarded(comptime Scalar: type, comptime table_size: usize, values: []const u16) !void {
    var guarded: [table_size + 2]Mapped = undefined;
    @memset(std.mem.asBytes(&guarded), 0xa5);
    try expectMatches(Scalar, values, guarded[1 .. table_size + 1]);
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** @sizeOf(Mapped)), std.mem.asBytes(&guarded[0]));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** @sizeOf(Mapped)), std.mem.asBytes(&guarded[table_size + 1]));
}

pub fn checkTransitions(comptime Scalar: type) !void {
    inline for (.{ 64, 128 }) |table_size| {
        // Every probability, including immediately before/after each power
        // of two, sees the oracle's ascending-state transition ordering.
        for (1..table_size) |probability| {
            const values = [_]u16{ @intCast(probability + 1), @intCast(table_size - probability + 1) };
            try expectGuarded(Scalar, table_size, &values);
        }
        // Three symbols interleave both baseline phases with absent gaps.
        for (1..table_size - 1) |probability| {
            const remaining = table_size - probability;
            const values = [_]u16{
                1,
                @intCast(probability + 1),
                1,
                @intCast(remaining / 2 + 1),
                1,
                @intCast(remaining - remaining / 2 + 1),
                1,
            };
            try expectGuarded(Scalar, table_size, &values);
        }
    }
}

pub fn checkSparse(comptime Scalar: type) !void {
    inline for (.{ 64, 128 }) |table_size| {
        // The entire probability range includes singleton tables at every
        // admitted symbol index, with poisoned absent mappings around it.
        for (0..53) |symbol| {
            var values = [_]u16{1} ** 53;
            values[symbol] = table_size + 1;
            try expectGuarded(Scalar, table_size, &values);
            try expectGuarded(Scalar, table_size, values[0 .. symbol + 1]);
        }
        inline for (.{ 1, 2, 3, 7, 15, 16, 17, 30 }) |probability| {
            var values = [_]u16{1} ** 53;
            values[0] = probability + 1;
            values[26] = table_size - probability;
            values[52] = 2;
            try expectGuarded(Scalar, table_size, &values);
        }
    }
}

pub fn checkUnitProbabilities(comptime Scalar: type) !void {
    inline for (.{ 64, 128 }) |table_size| {
        // An all-p=1 table would need 64/128 symbols and is outside the
        // <=53-symbol API. Exercise the maximum 52 unit probabilities, with
        // the remaining states owned by each possible residual symbol.
        for (0..53) |residual_symbol| {
            var values = [_]u16{2} ** 53;
            values[residual_symbol] = table_size - 52 + 1;
            try expectGuarded(Scalar, table_size, &values);
        }
        const uniform = [_]u16{table_size / 32 + 1} ** 32;
        try expectGuarded(Scalar, table_size, &uniform);
    }
}

pub fn checkRandomAndReuse(comptime Scalar: type) !void {
    var prng = std.Random.DefaultPrng.init(0x4653_4536_3431_3238);
    const random = prng.random();
    var guarded: [130]Mapped = undefined;
    @memset(std.mem.asBytes(&guarded), 0xdb);
    var values: [53]u16 = undefined;
    // Together with the fixed fixtures, retain 3,484 scalar table comparisons.
    for (0..2766) |iteration| {
        const table_size: usize = if (iteration & 1 == 0) 64 else 128;
        const symbol_count = random.intRangeAtMost(usize, 1, 53);
        @memset(&values, 1);
        var remaining = table_size;
        while (remaining != 0) {
            const symbol = random.uintLessThan(usize, symbol_count);
            // Alternate many unit allocations and sparse random chunks.
            const probability = if (iteration & 2 == 0) 1 else random.intRangeAtMost(usize, 1, remaining);
            values[symbol] += @intCast(probability);
            remaining -= probability;
        }
        const before = guarded;
        try expectMatches(Scalar, values[0..symbol_count], guarded[1 .. table_size + 1]);
        try std.testing.expectEqualSlices(u8, std.mem.asBytes(&before[0]), std.mem.asBytes(&guarded[0]));
        try std.testing.expectEqualSlices(
            u8,
            std.mem.sliceAsBytes(before[table_size + 1 ..]),
            std.mem.sliceAsBytes(guarded[table_size + 1 ..]),
        );
    }
}

pub fn checkLayouts(comptime Scalar: type) !void {
    const AutoReordered = struct {
        state_bits: u8,
        next_state: u16,
        additional_bits: u8,
        base: u32,
    };
    const ExternReordered = extern struct {
        base: u32,
        additional_bits: u8,
        state_bits: u8,
        next_state: u16,
    };
    inline for (.{ AutoReordered, ExternReordered }) |Layout| {
        var entries: [128]Layout = undefined;
        @memset(std.mem.asBytes(&entries), 0x97);
        try expectMatches(Scalar, &.{ 31, 18, 9, 6, 5 }, entries[0..64]);
        try expectMatches(Scalar, &.{ 30, 28, 26, 24, 19, 7 }, &entries);
    }
}
