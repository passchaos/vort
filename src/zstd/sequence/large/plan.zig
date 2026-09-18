//! Isolated cost kernel for fast large-sequence table-plan selection.
const std = @import("std");
const builtin = @import("builtin");
const predefined = @import("../predefined.zig");

const text_section = switch (builtin.object_format) {
    .elf => ".vort_zstd_fast_plan",
    .macho => "__TEXT,__vort_zstd_fp",
    .coff => ".text$vort_zstd_fast_plan",
    else => ".text",
};

pub const Error = error{ IntegerOverflow, CorruptFrame };

pub const Cost = struct {
    payload_len: usize,
    bit_count: usize,
};

pub const Selection = struct {
    literal_index: u8,
    offset_index: u8,
    match_index: u8,
    payload_len: usize,
};

pub noinline fn valueBits(
    codes: []const u8,
    bit_widths: []const u8,
) linksection(text_section) Error!usize {
    if (codes.len == 0) return error.CorruptFrame;
    var total: usize = 0;
    for (codes) |code| {
        if (code >= bit_widths.len) return error.CorruptFrame;
        total = std.math.add(usize, total, bit_widths[code]) catch return error.IntegerOverflow;
    }
    return total;
}

pub noinline fn rleCost(value_bits: usize) linksection(text_section) Cost {
    return .{ .payload_len = 1, .bit_count = value_bits };
}

pub noinline fn predefinedCost(
    states: []const u8,
    symbols: []const predefined.Symbol,
    initial_bits: u8,
    value_bits: usize,
) linksection(text_section) Error!Cost {
    if (states.len == 0) return error.CorruptFrame;
    var bit_count = std.math.add(usize, value_bits, initial_bits) catch return error.IntegerOverflow;
    for (states[0 .. states.len - 1]) |state| {
        if (state >= symbols.len) return error.CorruptFrame;
        bit_count = std.math.add(usize, bit_count, symbols[state].state_bits) catch return error.IntegerOverflow;
    }
    return .{ .payload_len = 0, .bit_count = bit_count };
}

pub noinline fn compressedCost(
    transition_bits: []const u8,
    accuracy_log: u8,
    table_payload_len: usize,
    value_bits: usize,
) linksection(text_section) Error!Cost {
    if (transition_bits.len == 0) return error.CorruptFrame;
    var bit_count = std.math.add(usize, value_bits, accuracy_log) catch return error.IntegerOverflow;
    for (transition_bits[0 .. transition_bits.len - 1]) |bits|
        bit_count = std.math.add(usize, bit_count, bits) catch return error.IntegerOverflow;
    return .{ .payload_len = table_payload_len, .bit_count = bit_count };
}

pub noinline fn repeatCost(
    states: []const u16,
    symbols: []const predefined.Symbol,
    source_is_rle: bool,
    initial_bits: u8,
    value_bits: usize,
) linksection(text_section) Error!Cost {
    if (states.len == 0) return error.CorruptFrame;
    var bit_count = std.math.add(usize, value_bits, initial_bits) catch return error.IntegerOverflow;
    if (!source_is_rle) for (states[0 .. states.len - 1]) |state| {
        if (state >= symbols.len) return error.CorruptFrame;
        bit_count = std.math.add(usize, bit_count, symbols[state].state_bits) catch return error.IntegerOverflow;
    };
    return .{ .payload_len = 0, .bit_count = bit_count };
}

pub noinline fn select(
    sequence_count_len: usize,
    literals_section_len: usize,
    literal_costs: []const Cost,
    offset_costs: []const Cost,
    match_costs: []const Cost,
) linksection(text_section) Error!?Selection {
    if (literal_costs.len == 0 or offset_costs.len == 0 or match_costs.len == 0 or
        literal_costs.len > 4 or offset_costs.len > 4 or match_costs.len > 4) return null;
    var best: ?Selection = null;
    for (literal_costs, 0..) |literal, literal_index| {
        for (offset_costs, 0..) |offset, offset_index| {
            for (match_costs, 0..) |match, match_index| {
                var payload_len = std.math.add(usize, literals_section_len, sequence_count_len) catch return error.IntegerOverflow;
                payload_len = std.math.add(usize, payload_len, 1) catch return error.IntegerOverflow;
                const table_payload_len = std.math.add(usize, literal.payload_len, offset.payload_len) catch return error.IntegerOverflow;
                const all_table_payload_len = std.math.add(usize, table_payload_len, match.payload_len) catch return error.IntegerOverflow;
                payload_len = std.math.add(usize, payload_len, all_table_payload_len) catch return error.IntegerOverflow;
                const literal_and_offset_bits = std.math.add(usize, literal.bit_count, offset.bit_count) catch return error.IntegerOverflow;
                const table_bits = std.math.add(usize, literal_and_offset_bits, match.bit_count) catch return error.IntegerOverflow;
                const bit_count = std.math.add(usize, 1, table_bits) catch return error.IntegerOverflow;
                payload_len = std.math.add(usize, payload_len, (bit_count + 7) / 8) catch return error.IntegerOverflow;
                if (best == null or payload_len < best.?.payload_len) best = .{
                    .literal_index = @intCast(literal_index),
                    .offset_index = @intCast(offset_index),
                    .match_index = @intCast(match_index),
                    .payload_len = payload_len,
                };
            }
        }
    }
    return best;
}

test "fast large plan cost and selection reject malformed shapes" {
    try std.testing.expectError(error.CorruptFrame, predefinedCost(&.{}, &.{}, 0, 0));
    try std.testing.expectError(error.CorruptFrame, compressedCost(&.{}, 5, 1, 0));
    try std.testing.expectEqual(@as(?Selection, null), try select(1, 0, &.{}, &.{.{ .payload_len = 0, .bit_count = 0 }}, &.{.{ .payload_len = 0, .bit_count = 0 }}));
}

test "fast large selection matches scalar cartesian search" {
    var random_state: u32 = 0x082e_fa98;
    for (0..4096) |_| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        const literal_len: usize = 1 + (random_state & 3);
        const offset_len: usize = 1 + ((random_state >> 2) & 3);
        const match_len: usize = 1 + ((random_state >> 4) & 3);
        var literal_costs: [4]Cost = undefined;
        var offset_costs: [4]Cost = undefined;
        var match_costs: [4]Cost = undefined;
        for (&literal_costs, 0..) |*cost, i| {
            random_state = random_state *% 1_664_525 +% 1_013_904_223;
            cost.* = .{ .payload_len = (random_state >> 24) & 15, .bit_count = ((random_state >> 8) & 1023) + i };
        }
        for (&offset_costs, 0..) |*cost, i| {
            random_state = random_state *% 1_664_525 +% 1_013_904_223;
            cost.* = .{ .payload_len = (random_state >> 24) & 15, .bit_count = ((random_state >> 8) & 1023) + i };
        }
        for (&match_costs, 0..) |*cost, i| {
            random_state = random_state *% 1_664_525 +% 1_013_904_223;
            cost.* = .{ .payload_len = (random_state >> 24) & 15, .bit_count = ((random_state >> 8) & 1023) + i };
        }
        const sequence_count_len: usize = 1 + ((random_state >> 6) & 3);
        const literals_section_len: usize = (random_state >> 12) & 1023;
        const actual = (try select(
            sequence_count_len,
            literals_section_len,
            literal_costs[0..literal_len],
            offset_costs[0..offset_len],
            match_costs[0..match_len],
        )).?;
        var expected: ?Selection = null;
        for (literal_costs[0..literal_len], 0..) |literal, literal_index| {
            for (offset_costs[0..offset_len], 0..) |offset, offset_index| {
                for (match_costs[0..match_len], 0..) |match, match_index| {
                    const table_bytes = literal.payload_len + offset.payload_len + match.payload_len;
                    const bits = 1 + literal.bit_count + offset.bit_count + match.bit_count;
                    const payload_len = literals_section_len + sequence_count_len + 1 + table_bytes + (bits + 7) / 8;
                    if (expected == null or payload_len < expected.?.payload_len) expected = .{
                        .literal_index = @intCast(literal_index),
                        .offset_index = @intCast(offset_index),
                        .match_index = @intCast(match_index),
                        .payload_len = payload_len,
                    };
                }
            }
        }
        try std.testing.expectEqual(expected.?, actual);
    }
}
