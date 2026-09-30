const std = @import("std");
const builtin = @import("builtin");
const large_fse_table = if (builtin.is_test) @import("large/fse_table.zig") else struct {};

const mapped_build_text_section = switch (builtin.object_format) {
    .elf => ".vort_zstd_zz_fse_mapped",
    .macho => "__TEXT,__vort_zstd_zz",
    .coff => ".text$zz_vort_zstd_fse_mapped",
    else => ".text",
};

pub const Error = error{CorruptFrame};

pub const Entry = struct {
    symbol: u8,
    baseline: u16,
    bits: u8,
};

/// Build an FSE decode table from Zstd's normalized-count representation.
/// Values above one encode `count + 1`, one means an absent symbol, and zero
/// encodes the special -1 count placed at the high end of the state table.
///
/// State spreading is followed by one ascending state pass. For a symbol with
/// probability `p`, the nth encountered state uses `next_state = p + n`; this
/// is equivalent to sorting every symbol's spread positions, but avoids the
/// previous per-symbol sort and temporary 512-state array.
pub noinline fn build(values: []const u16, entries: []Entry) Error!void {
    if (entries.len == 0 or !std.math.isPowerOfTwo(entries.len)) {
        return error.CorruptFrame;
    }
    if (entries.len > std.math.maxInt(u16) or values.len > 256) {
        return error.CorruptFrame;
    }

    var normalized_total: usize = 0;
    var low_probability_count: usize = 0;
    for (values) |value| {
        if (value == 0) {
            normalized_total += 1;
            low_probability_count += 1;
        } else if (value > 1) {
            normalized_total += value - 1;
        }
    }
    if (normalized_total != entries.len) return error.CorruptFrame;

    const table_size: u16 = @intCast(entries.len);
    const accuracy_log = std.math.log2_int(u16, table_size);
    const spread_step = (entries.len >> 1) + (entries.len >> 3) + 3;
    const normal_end = entries.len - low_probability_count;

    var low_index: usize = 0;
    for (values, 0..) |value, symbol| {
        if (value != 0) continue;
        entries[entries.len - 1 - low_index] = .{
            .symbol = @intCast(symbol),
            .baseline = 0,
            .bits = accuracy_log,
        };
        low_index += 1;
    }

    var position: usize = 0;
    for (values, 0..) |value, symbol| {
        if (value <= 1) continue;
        const probability = value - 1;
        for (0..probability) |_| {
            entries[position].symbol = @intCast(symbol);
            position = (position + spread_step) & (entries.len - 1);
            while (position >= normal_end) {
                position = (position + spread_step) & (entries.len - 1);
            }
        }
    }
    if (position != 0) return error.CorruptFrame;

    var symbol_next: [256]u16 = @splat(0);
    for (values, 0..) |value, symbol| {
        if (value > 1) symbol_next[symbol] = value - 1;
    }
    for (entries[0..normal_end]) |*entry| {
        const next_state = symbol_next[entry.symbol];
        if (next_state == 0) return error.CorruptFrame;
        symbol_next[entry.symbol] += 1;
        const state_bits = accuracy_log - std.math.log2_int(u16, next_state);
        const baseline = (@as(u32, next_state) << @intCast(state_bits)) - table_size;
        entry.bits = state_bits;
        entry.baseline = @intCast(baseline);
    }
}

/// Build the final sequence-symbol table directly. Only one byte per spread
/// state is retained until the ascending state pass assigns transitions; this
/// avoids materializing an intermediate Entry table and converting it later.
pub noinline fn buildMapped(
    values: []const u16,
    entries: anytype,
    bases: []const usize,
    additional_bits: []const u8,
) linksection(mapped_build_text_section) Error!void {
    return buildMappedBounded(256, 512, values, entries, bases, additional_bits);
}

pub noinline fn buildMappedSmall32(
    values: []const u16,
    entries: anytype,
    bases: []const usize,
    additional_bits: []const u8,
) linksection(mapped_build_text_section) Error!void {
    return buildMappedBounded(32, 32, values, entries, bases, additional_bits);
}

inline fn buildMappedBounded(
    comptime max_symbol_count: usize,
    comptime max_table_size: usize,
    values: []const u16,
    entries: anytype,
    bases: []const usize,
    additional_bits: []const u8,
) Error!void {
    if (entries.len == 0 or !std.math.isPowerOfTwo(entries.len)) return error.CorruptFrame;
    if (entries.len > max_table_size or values.len > max_symbol_count or
        values.len > bases.len or values.len > additional_bits.len)
        return error.CorruptFrame;

    var normalized_total: usize = 0;
    var low_probability_count: usize = 0;
    var symbol_next: [max_symbol_count]u16 = undefined;
    @memset(symbol_next[0..values.len], 0);
    for (values, 0..) |value, symbol| {
        if (value == 0) {
            normalized_total += 1;
            low_probability_count += 1;
        } else if (value > 1) {
            normalized_total += value - 1;
            symbol_next[symbol] = value - 1;
        }
    }
    if (normalized_total != entries.len) return error.CorruptFrame;

    const table_size: u16 = @intCast(entries.len);
    const accuracy_log = std.math.log2_int(u16, table_size);
    const spread_step = (entries.len >> 1) + (entries.len >> 3) + 3;
    const normal_end = entries.len - low_probability_count;
    var symbols: [max_table_size]u8 = undefined;

    var low_index: usize = 0;
    for (values, 0..) |value, symbol| {
        if (value != 0) continue;
        entries[entries.len - 1 - low_index] = .{
            .base = @intCast(bases[symbol]),
            .additional_bits = additional_bits[symbol],
            .next_state = 0,
            .state_bits = accuracy_log,
        };
        low_index += 1;
    }

    var position: usize = 0;
    for (values, 0..) |value, symbol| {
        if (value <= 1) continue;
        for (0..value - 1) |_| {
            symbols[position] = @intCast(symbol);
            position = (position + spread_step) & (entries.len - 1);
            while (position >= normal_end) position = (position + spread_step) & (entries.len - 1);
        }
    }
    if (position != 0) return error.CorruptFrame;

    for (entries[0..normal_end], symbols[0..normal_end]) |*entry, symbol| {
        const next_state = symbol_next[symbol];
        if (next_state == 0) return error.CorruptFrame;
        symbol_next[symbol] += 1;
        const state_bits = accuracy_log - std.math.log2_int(u16, next_state);
        entry.* = .{
            .base = @intCast(bases[symbol]),
            .additional_bits = additional_bits[symbol],
            .next_state = @intCast((@as(u32, next_state) << @intCast(state_bits)) - table_size),
            .state_bits = state_bits,
        };
    }
}

fn buildSortedReference(values: []const u16, entries: []Entry) Error!void {
    const total_probability: u16 = @intCast(entries.len);
    const accuracy_log = std.math.log2_int(u16, total_probability);
    var low_probability_count: usize = 0;
    for (values, 0..) |value, symbol| {
        if (value == 0) {
            entries[entries.len - 1 - low_probability_count] = .{
                .symbol = @intCast(symbol),
                .baseline = 0,
                .bits = accuracy_log,
            };
            low_probability_count += 1;
        }
    }

    var position: usize = 0;
    var states: [512]u16 = undefined;
    for (values, 0..) |value, symbol| {
        if (value <= 1) continue;
        const probability = value - 1;
        const state_share_dividend = std.math.ceilPowerOfTwo(u16, probability) catch return error.CorruptFrame;
        const share_size = @divExact(total_probability, state_share_dividend);
        const double_state_count = state_share_dividend - probability;
        const single_state_count = probability - double_state_count;
        const share_size_log = std.math.log2_int(u16, share_size);

        for (0..probability) |i| {
            states[i] = @intCast(position);
            position = (position + (entries.len >> 1) + (entries.len >> 3) + 3) &
                (entries.len - 1);
            while (position >= entries.len - low_probability_count) {
                position = (position + (entries.len >> 1) + (entries.len >> 3) + 3) &
                    (entries.len - 1);
            }
        }
        std.mem.sort(u16, states[0..probability], {}, std.sort.asc(u16));
        for (0..probability) |i| {
            entries[states[i]] = if (i < double_state_count) .{
                .symbol = @intCast(symbol),
                .bits = @intCast(share_size_log + 1),
                .baseline = @intCast(single_state_count * share_size + @as(u16, @intCast(i)) * 2 * share_size),
            } else .{
                .symbol = @intCast(symbol),
                .bits = @intCast(share_size_log),
                .baseline = @intCast((@as(u16, @intCast(i)) - double_state_count) * share_size),
            };
        }
    }
}

fn expectMatchesSorted(comptime table_size: usize, values: []const u16) !void {
    var expected: [table_size]Entry = undefined;
    var actual: [table_size]Entry = undefined;
    try buildSortedReference(values, &expected);
    try build(values, &actual);
    try std.testing.expectEqualSlices(Entry, &expected, &actual);
}

test "Zstd linear FSE builder matches sorted construction" {
    try expectMatchesSorted(32, &.{ 17, 9, 5, 3, 2, 0 });
    try expectMatchesSorted(32, &.{ 14, 8, 6, 5, 3, 0 });
    try expectMatchesSorted(32, &.{ 21, 8, 4, 0, 0, 1 });
    // Exercise the two table widths that select the production linear path.
    try expectMatchesSorted(256, &.{ 129, 65, 33, 17, 9, 5, 0, 0, 0, 0 });
    try expectMatchesSorted(512, &.{ 256, 129, 65, 33, 17, 9, 5, 3, 2, 0, 0 });
}

test "Zstd linear FSE builder rejects invalid normalized totals" {
    var entries: [32]Entry = undefined;
    try std.testing.expectError(error.CorruptFrame, build(&.{ 17, 9 }, &entries));
    try std.testing.expectError(error.CorruptFrame, build(&.{2}, entries[0..31]));
}

fn expectMappedMatches(comptime table_size: usize, values: []const u16) !void {
    const Mapped = struct {
        base: u32,
        additional_bits: u8,
        next_state: u16,
        state_bits: u8,
    };
    var raw: [table_size]Entry = undefined;
    var mapped: [table_size]Mapped = undefined;
    var bases: [256]usize = undefined;
    var bits: [256]u8 = undefined;
    for (&bases, &bits, 0..) |*base, *bit_count, symbol| {
        base.* = symbol * 37;
        bit_count.* = @intCast(symbol % 9);
    }
    try build(values, &raw);
    try buildMapped(values, &mapped, bases[0..values.len], bits[0..values.len]);
    for (raw, mapped) |entry, actual| {
        try std.testing.expectEqual(@as(u32, @intCast(bases[entry.symbol])), actual.base);
        try std.testing.expectEqual(bits[entry.symbol], actual.additional_bits);
        try std.testing.expectEqual(entry.baseline, actual.next_state);
        try std.testing.expectEqual(entry.bits, actual.state_bits);
    }
    if (table_size == 32) {
        var small: [32]Mapped = undefined;
        try buildMappedSmall32(values, &small, bases[0..values.len], bits[0..values.len]);
        try std.testing.expectEqualSlices(Mapped, &mapped, &small);
    }
}

test "Zstd mapped FSE builder matches entry conversion" {
    try expectMappedMatches(32, &.{ 17, 9, 5, 3, 2, 0 });
    try expectMappedMatches(32, &.{ 14, 8, 6, 5, 3, 0 });
    try expectMappedMatches(32, &.{ 21, 8, 4, 0, 0, 1 });
    try expectMappedMatches(256, &.{ 129, 65, 33, 17, 9, 5, 0, 0, 0, 0 });
    try expectMappedMatches(512, &.{ 256, 129, 65, 33, 17, 9, 5, 3, 2, 0, 0 });
}

test "Zstd 256-state no-low mapped builder matches generic table" {
    const Mapped = struct {
        base: u32,
        additional_bits: u8,
        next_state: u16,
        state_bits: u8,
    };
    var bases: [256]usize = undefined;
    var bits: [256]u8 = undefined;
    for (&bases, &bits, 0..) |*base, *bit_count, symbol| {
        base.* = symbol * 37;
        bit_count.* = @intCast(symbol % 9);
    }
    var expected: [256]Mapped = undefined;
    var actual: [256]Mapped = undefined;
    var values: [256]u16 = undefined;
    var prng = std.Random.DefaultPrng.init(0x4653_4532_3536);
    const random = prng.random();
    for (0..256) |_| {
        const symbol_count = random.intRangeAtMost(usize, 2, 53);
        @memset(values[0..symbol_count], 1);
        var remaining: usize = 256;
        while (remaining != 0) {
            const symbol = random.uintLessThan(usize, symbol_count);
            values[symbol] += 1;
            remaining -= 1;
        }
        try buildMapped(values[0..symbol_count], &expected, bases[0..symbol_count], bits[0..symbol_count]);
        large_fse_table.buildNoLowProbabilityAssumeValid(values[0..symbol_count], &actual, bases[0..symbol_count], bits[0..symbol_count]);
        try std.testing.expectEqualSlices(Mapped, &expected, &actual);
    }
    inline for (.{
        &[_]u16{ 4, 227, 25, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2 },
        &[_]u16{ 209, 1, 1, 1, 1, 1, 2, 1, 1, 4, 2, 1, 19, 13, 2, 13 },
        &[_]u16{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 256 },
    }) |fixture| {
        try buildMapped(fixture, &expected, bases[0..fixture.len], bits[0..fixture.len]);
        large_fse_table.buildNoLowProbabilityAssumeValid(fixture, &actual, bases[0..fixture.len], bits[0..fixture.len]);
        try std.testing.expectEqualSlices(Mapped, &expected, &actual);
    }

    var invalid = [_]u16{ 128, 64, 32, 16, 8, 4, 3 };
    try std.testing.expectError(error.CorruptFrame, large_fse_table.buildNoLowProbability(&invalid, &actual, &bases, &bits));
    invalid[6] = 4;
    try std.testing.expectError(error.CorruptFrame, large_fse_table.buildNoLowProbability(&invalid, actual[0..128], &bases, &bits));
    invalid[6] = 0;
    try std.testing.expectError(error.CorruptFrame, large_fse_table.buildNoLowProbability(&invalid, &actual, &bases, &bits));

    const too_many_symbols = [_]u16{1} ** 54;
    try std.testing.expectError(error.CorruptFrame, large_fse_table.buildNoLowProbability(&too_many_symbols, &actual, &bases, &bits));
}
