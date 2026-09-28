const std = @import("std");
const builtin = @import("builtin");

pub const text_section = switch (builtin.object_format) {
    .elf => ".vort_zstd_fse_256",
    .macho => "__TEXT,__vort_zstd_f256",
    .coff => ".text$vort_zstd_fse_256",
    else => ".text",
};

pub const Error = error{CorruptFrame};
const max_sequence_symbol_count = 53;

inline fn writePackedMappedPhase(
    entries: anytype,
    start: usize,
    count: usize,
    base: u32,
    additional_bits: u8,
    state_bits: u8,
    baseline: usize,
    baseline_step: usize,
) void {
    const Entry = @TypeOf(entries[0]);
    comptime {
        std.debug.assert(@sizeOf(Entry) == 8);
        std.debug.assert(@offsetOf(Entry, "base") == 0);
        std.debug.assert(@offsetOf(Entry, "next_state") == 4);
        std.debug.assert(@offsetOf(Entry, "additional_bits") == 6);
        std.debug.assert(@offsetOf(Entry, "state_bits") == 7);
    }
    const fixed_word = @as(u64, base) |
        (@as(u64, additional_bits) << 48) |
        (@as(u64, state_bits) << 56);
    var index: usize = 0;
    while (count - index >= 4) : (index += 4) {
        const next_words: @Vector(4, u64) = .{
            baseline + index * baseline_step,
            baseline + (index + 1) * baseline_step,
            baseline + (index + 2) * baseline_step,
            baseline + (index + 3) * baseline_step,
        };
        const packed_words = @as(@Vector(4, u64), @splat(fixed_word)) |
            (next_words << @as(@Vector(4, u6), @splat(32)));
        const destination: *align(1) @Vector(4, u64) = @ptrCast(&entries[start + index]);
        destination.* = packed_words;
    }
    while (index < count) : (index += 1) {
        entries[start + index] = .{
            .base = base,
            .additional_bits = additional_bits,
            .next_state = @intCast(baseline + index * baseline_step),
            .state_bits = state_bits,
        };
    }
}

inline fn writeDenseMappedRun(
    entries: anytype,
    start: usize,
    end: usize,
    base: u32,
    additional_bits: u8,
    double_state_count: usize,
    single_state_count: usize,
    share_size_log: u8,
    share_size: usize,
    ordinal: *usize,
) void {
    var state = start;
    if (ordinal.* < double_state_count) {
        const count = @min(end - state, double_state_count - ordinal.*);
        writePackedMappedPhase(
            entries,
            state,
            count,
            base,
            additional_bits,
            share_size_log + 1,
            (single_state_count + ordinal.* * 2) * share_size,
            2 * share_size,
        );
        state += count;
        ordinal.* += count;
    }
    if (state < end) {
        const count = end - state;
        writePackedMappedPhase(
            entries,
            state,
            count,
            base,
            additional_bits,
            share_size_log,
            (ordinal.* - double_state_count) * share_size,
            share_size,
        );
        ordinal.* += count;
    }
}

/// Build a 256-state mapped FSE table after the wire parser has verified the
/// normalized-count sum and established that no `-1` probability is present.
/// Per-symbol state bitsets construct final mapped entries directly, removing
/// the symbol scratch and its following symbol-indexed transition pass. Dense
/// probabilities build the complement so their spread loop visits fewer states.
pub noinline fn buildNoLowProbability(
    values: []const u16,
    entries: anytype,
    bases: []const usize,
    additional_bits: []const u8,
) linksection(text_section) Error!void {
    if (entries.len != 256 or values.len > max_sequence_symbol_count or values.len > bases.len or values.len > additional_bits.len)
        return error.CorruptFrame;

    const table_size: usize = 256;
    var normalized_total: usize = 0;
    for (values) |value| {
        if (value == 0) return error.CorruptFrame;
        const probability: usize = value - 1;
        if (probability > table_size - normalized_total) return error.CorruptFrame;
        normalized_total += probability;
    }
    if (normalized_total != table_size) return error.CorruptFrame;

    buildNoLowProbabilityAssumeValid(values, entries, bases, additional_bits);
}

/// Build the same table when the normalized-count parser has already proved
/// the 256-state sum and the caller has established that no value is zero.
pub noinline fn buildNoLowProbabilityAssumeValid(
    values: []const u16,
    entries: anytype,
    bases: []const usize,
    additional_bits: []const u8,
) linksection(text_section) void {
    std.debug.assert(entries.len == 256);
    std.debug.assert(values.len <= max_sequence_symbol_count);
    std.debug.assert(values.len <= bases.len);
    std.debug.assert(values.len <= additional_bits.len);

    const table_size: usize = 256;
    const spread_step = (table_size >> 1) + (table_size >> 3) + 3;

    var position: usize = 0;
    for (values, 0..) |value, symbol| {
        if (value == 1) continue;
        const probability: usize = value - 1;
        if (probability == table_size - 1) {
            const gap_state = (position + probability * spread_step) & (table_size - 1);
            const first_state: usize = if (gap_state == 0) 1 else 0;
            entries[first_state] = .{
                .base = @intCast(bases[symbol]),
                .additional_bits = additional_bits[symbol],
                .next_state = table_size - 2,
                .state_bits = 1,
            };
            var state = first_state + 1;
            var next_state: u16 = 0;
            while (state < gap_state) : (state += 1) {
                entries[state] = .{
                    .base = @intCast(bases[symbol]),
                    .additional_bits = additional_bits[symbol],
                    .next_state = next_state,
                    .state_bits = 0,
                };
                next_state += 1;
            }
            if (state == gap_state) state += 1;
            while (state < table_size) : (state += 1) {
                entries[state] = .{
                    .base = @intCast(bases[symbol]),
                    .additional_bits = additional_bits[symbol],
                    .next_state = next_state,
                    .state_bits = 0,
                };
                next_state += 1;
            }
            std.debug.assert(next_state == table_size - 2);
            position = gap_state;
            continue;
        }
        const state_share_dividend = std.math.ceilPowerOfTwo(usize, probability) catch unreachable;
        const share_size = table_size / state_share_dividend;
        const double_state_count = state_share_dividend - probability;
        const single_state_count = probability - double_state_count;
        const share_size_log: u8 = @intCast(std.math.log2_int(usize, share_size));
        var state_bits = share_size_log + @intFromBool(double_state_count != 0);
        var baseline = if (double_state_count != 0) single_state_count * share_size else 0;
        var baseline_step = if (double_state_count != 0) 2 * share_size else share_size;
        var states: [4]u64 = if (probability >= table_size / 2) @splat(std.math.maxInt(u64)) else @splat(0);
        if (probability >= table_size / 2) {
            const symbol_end = (position + probability * spread_step) & (table_size - 1);
            var gap_position = symbol_end;
            for (0..table_size - probability) |_| {
                states[gap_position >> 6] &= ~(@as(u64, 1) << @intCast(gap_position & 63));
                gap_position = (gap_position + spread_step) & (table_size - 1);
            }
            std.debug.assert(gap_position == position);
            position = symbol_end;
        } else {
            for (0..probability) |_| {
                states[position >> 6] |= @as(u64, 1) << @intCast(position & 63);
                position = (position + spread_step) & (table_size - 1);
            }
        }

        if (comptime builtin.cpu.arch == .aarch64) {
            if (probability >= 192) {
                const base: u32 = @intCast(bases[symbol]);
                var ordinal: usize = 0;
                var run_start: usize = 0;
                for (states, 0..) |word, word_index| {
                    var gaps = ~word;
                    while (gaps != 0) {
                        const gap = word_index * 64 + @ctz(gaps);
                        writeDenseMappedRun(
                            entries,
                            run_start,
                            gap,
                            base,
                            additional_bits[symbol],
                            double_state_count,
                            single_state_count,
                            share_size_log,
                            share_size,
                            &ordinal,
                        );
                        run_start = gap + 1;
                        gaps &= gaps - 1;
                    }
                }
                writeDenseMappedRun(
                    entries,
                    run_start,
                    table_size,
                    base,
                    additional_bits[symbol],
                    double_state_count,
                    single_state_count,
                    share_size_log,
                    share_size,
                    &ordinal,
                );
                std.debug.assert(ordinal == probability);
                continue;
            }
        }

        var ordinal: usize = 0;
        for (&states, 0..) |*word, word_index| {
            while (word.* != 0) {
                const state = word_index * 64 + @ctz(word.*);
                word.* &= word.* - 1;
                entries[state] = .{
                    .base = @intCast(bases[symbol]),
                    .additional_bits = additional_bits[symbol],
                    .next_state = @intCast(baseline),
                    .state_bits = state_bits,
                };
                ordinal += 1;
                if (ordinal == double_state_count) {
                    state_bits = share_size_log;
                    baseline = 0;
                    baseline_step = share_size;
                } else {
                    baseline += baseline_step;
                }
            }
        }
        std.debug.assert(ordinal == probability);
    }
    std.debug.assert(position == 0);
}
