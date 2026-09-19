//! Compile-time transition ranges for large predefined sequence planning.
const std = @import("std");
const builtin = @import("builtin");
const predefined = @import("../predefined.zig");

pub const Kind = enum { literal, offset, match };

const text_section = switch (builtin.object_format) {
    .elf => ".vort_zstd_fast_plan",
    .macho => "__TEXT,__vort_zstd_fp",
    .coff => ".text$vort_zstd_fast_plan",
    else => ".text",
};

const max_sequence_count = std.compress.zstd.block_size_max / 3;

pub noinline fn plan(
    codes: []const u8,
    code_state_masks: []const u64,
    kind: Kind,
    states: []u8,
    viable_masks: []u64,
) linksection(text_section) bool {
    return planWithMask(u64, codes, code_state_masks, kind, states, viable_masks);
}

pub noinline fn planOffset(
    codes: []const u8,
    code_state_masks: []const u64,
    states: []u8,
    viable_masks: []u32,
) linksection(text_section) bool {
    return planWithMask(u32, codes, code_state_masks, .offset, states, viable_masks);
}

fn planWithMask(
    comptime Mask: type,
    codes: []const u8,
    code_state_masks: []const u64,
    kind: Kind,
    states: []u8,
    viable_masks: []Mask,
) bool {
    if (codes.len == 0 or codes.len > max_sequence_count or
        states.len != codes.len or viable_masks.len != codes.len) return false;
    const successor_masks = successorMasks(kind);
    const valid_state_mask: u64 = if (@bitSizeOf(Mask) == 64)
        std.math.maxInt(u64)
    else
        (@as(u64, 1) << @bitSizeOf(Mask)) - 1;
    var viable_next: Mask = 0;
    var pos = codes.len;
    while (pos > 0) {
        pos -= 1;
        const code = codes[pos];
        if (code >= code_state_masks.len) {
            viable_masks[pos] = 0;
            viable_next = 0;
            continue;
        }
        var viable_current: Mask = 0;
        if (@bitSizeOf(Mask) < 64)
            std.debug.assert(code_state_masks[code] & ~valid_state_mask == 0);
        var encodable_states: Mask = @intCast(code_state_masks[code] & valid_state_mask);
        std.debug.assert(successor_masks.len <= @bitSizeOf(Mask));
        while (encodable_states != 0) {
            const state: usize = @ctz(encodable_states);
            encodable_states &= encodable_states - 1;
            const successor_mask: Mask = @intCast(successor_masks[state] & valid_state_mask);
            if (pos == codes.len - 1 or viable_next & successor_mask != 0)
                viable_current |= @as(Mask, 1) << @intCast(state);
        }
        viable_next = viable_current;
        viable_masks[pos] = viable_current;
    }
    if (viable_next == 0) return false;
    states[0] = @intCast(@ctz(viable_next));
    for (0..codes.len - 1) |i| {
        const successor_mask: Mask = @intCast(successor_masks[states[i]] & valid_state_mask);
        const possible = viable_masks[i + 1] & successor_mask;
        if (possible == 0) return false;
        states[i + 1] = @intCast(@ctz(possible));
    }
    return true;
}

pub fn successorMasks(kind: Kind) []const u64 {
    return switch (kind) {
        .literal => &literal_successor_masks,
        .offset => &offset_successor_masks,
        .match => &match_successor_masks,
    };
}

fn buildSuccessorMasks(comptime symbols: []const predefined.Symbol) [symbols.len]u64 {
    var masks: [symbols.len]u64 = undefined;
    for (symbols, 0..) |symbol, state| {
        const first: usize = symbol.next_state;
        const count: usize = @as(usize, 1) << @intCast(symbol.state_bits);
        const end = @min(symbols.len, first + count);
        const width = end - first;
        const low = if (width == 64) std.math.maxInt(u64) else (@as(u64, 1) << @intCast(width)) - 1;
        masks[state] = low << @intCast(first);
    }
    return masks;
}

const literal_successor_masks = buildSuccessorMasks(&predefined.literal_symbols);
const offset_successor_masks = buildSuccessorMasks(&predefined.offset_symbols);
const match_successor_masks = buildSuccessorMasks(&predefined.match_symbols);

test "large predefined successor masks match scalar ranges" {
    inline for ([_]Kind{ .literal, .offset, .match }) |kind| {
        const symbols = switch (kind) {
            .literal => &predefined.literal_symbols,
            .offset => &predefined.offset_symbols,
            .match => &predefined.match_symbols,
        };
        const masks = successorMasks(kind);
        try std.testing.expectEqual(symbols.len, masks.len);
        for (symbols, masks) |symbol, mask| {
            var expected: u64 = 0;
            const first: usize = symbol.next_state;
            const end = @min(symbols.len, first + (@as(usize, 1) << @intCast(symbol.state_bits)));
            for (first..end) |next| expected |= @as(u64, 1) << @intCast(next);
            try std.testing.expectEqual(expected, mask);
        }
    }
}

test "large predefined planner rejects malformed shapes and invalid codes" {
    var state: [2]u8 = undefined;
    var masks: [2]u64 = undefined;
    var compact_masks: [2]u32 = undefined;
    try std.testing.expect(!plan(&.{}, &.{1}, .literal, state[0..0], masks[0..0]));
    try std.testing.expect(!plan(&.{ 0, 0 }, &.{1}, .literal, state[0..1], &masks));
    try std.testing.expect(!plan(&.{1}, &.{1}, .literal, state[0..1], masks[0..1]));

    try std.testing.expect(plan(&.{0}, &.{1}, .literal, state[0..1], masks[0..1]));
    try std.testing.expectEqual(@as(u8, 0), state[0]);
    try std.testing.expectEqual(@as(u64, 1), masks[0]);

    try std.testing.expect(plan(&.{ 0, 0 }, &.{1}, .literal, &state, &masks));
    try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, &state);
    try std.testing.expectEqualSlices(u64, &.{ 1, 1 }, &masks);

    try std.testing.expect(!planOffset(&.{}, &.{1}, state[0..0], compact_masks[0..0]));
    try std.testing.expect(!planOffset(&.{1}, &.{1}, state[0..1], compact_masks[0..1]));
    try std.testing.expect(planOffset(&.{ 0, 0 }, &.{1}, &state, &compact_masks));
    try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, &state);
    try std.testing.expectEqualSlices(u32, &.{ 1, 1 }, &compact_masks);
}
