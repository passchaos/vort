const std = @import("std");
const decoder = @import("../fse.zig");
const bit_writer = @import("bit_writer.zig");

pub const Entry = struct {
    frequency: u16 = 0,
    split: u16 = 0,
    width: u8 = 0,
    delta0: i32 = 0,
    delta1: i32 = 0,
};

/// Integer normalization preserves every used symbol and distributes any
/// rounding remainder deterministically. Empty histograms use symbol zero.
pub fn normalize(state_count: usize, counts: []const u32, frequencies: []u16) !void {
    try validateDimensions(state_count, counts.len);
    if (counts.len != frequencies.len) return error.InvalidLzfseStream;
    var total: u64 = 0;
    var used: usize = 0;
    var dominant: usize = 0;
    for (counts, 0..) |count, symbol| {
        total += count;
        if (count != 0) used += 1;
        if (count > counts[dominant]) dominant = symbol;
    }
    if (used > state_count) return error.InvalidLzfseStream;
    @memset(frequencies, 0);
    if (total == 0) {
        frequencies[0] = @intCast(state_count);
        return;
    }
    var assigned: usize = 0;
    for (counts, frequencies) |count, *frequency| {
        frequency.* = if (count == 0) 0 else @intCast(@max(1, @as(u64, count) * state_count / total));
        assigned += frequency.*;
    }
    while (assigned > state_count) {
        var largest: usize = 0;
        for (frequencies, 0..) |frequency, symbol|
            if (frequency > frequencies[largest]) {
                largest = symbol;
            };
        if (frequencies[largest] <= 1) return error.InvalidLzfseStream;
        frequencies[largest] -= 1;
        assigned -= 1;
    }
    frequencies[dominant] += @intCast(state_count - assigned);
    try decoder.validateFrequencies(frequencies, state_count);
}

pub const Table = struct {
    state_count: usize,
    entries: []const Entry,

    pub fn encodeSymbol(self: Table, allocator: std.mem.Allocator, state: *u16, writer: *bit_writer.Writer, symbol: usize) !void {
        const step = try self.transition(state.*, symbol);
        try writer.push(allocator, step.bits, step.width);
        state.* = step.state;
    }

    /// The low bits carry the extra value and the high bits carry the state
    /// transition, exactly as two pushes of extra followed by state bits.
    pub fn encodeValue(self: Table, allocator: std.mem.Allocator, state: *u16, writer: *bit_writer.Writer, value: u32, bases: []const i32, widths: []const u8) !void {
        if (bases.len != self.entries.len) return error.InvalidLzfseStream;
        const symbol = try valueSlot(value, bases, widths);
        const step = try self.transition(state.*, symbol);
        const extra_width = widths[symbol];
        if (extra_width > 31 or step.width > 31 - extra_width) return error.InvalidLzfseStream;
        const extra = value - @as(u32, @intCast(bases[symbol]));
        const bits = extra | (step.bits << @intCast(extra_width));
        try writer.push(allocator, bits, extra_width + step.width);
        state.* = step.state;
    }

    fn transition(self: Table, state: u16, symbol: usize) !struct { state: u16, bits: u32, width: u8 } {
        if (state >= self.state_count or symbol >= self.entries.len) return error.InvalidLzfseStream;
        const entry = self.entries[symbol];
        if (entry.frequency == 0 or entry.width > 10) return error.InvalidLzfseStream;
        const high = state >= entry.split;
        if (!high and entry.width == 0) return error.InvalidLzfseStream;
        const width = entry.width - @as(u8, if (high) 0 else 1);
        const delta = if (high) entry.delta0 else entry.delta1;
        const next = @as(i64, delta) + @as(i64, state >> @intCast(width));
        if (next < 0 or next >= self.state_count) return error.InvalidLzfseStream;
        return .{ .state = @intCast(next), .bits = state & ((@as(u32, 1) << @intCast(width)) - 1), .width = width };
    }
};

/// The existing decoder places each symbol in a contiguous range of states.
/// These thresholds invert that mapping without a Zstd-style spread table.
pub fn initTable(state_count: usize, frequencies: []const u16, entries: []Entry) !Table {
    try validateDimensions(state_count, frequencies.len);
    if (entries.len != frequencies.len) return error.InvalidLzfseStream;
    try decoder.validateFrequencies(frequencies, state_count);
    const state_log = std.math.log2_int(usize, state_count);
    var offset: i32 = 0;
    for (frequencies, entries) |frequency, *entry| {
        entry.* = .{};
        if (frequency == 0) continue;
        const width = state_log - std.math.log2_int(usize, frequency);
        entry.* = .{
            .frequency = frequency,
            .split = @intCast((@as(usize, frequency) << @intCast(width)) - state_count),
            .width = @intCast(width),
            .delta0 = offset - @as(i32, frequency) + @as(i32, @intCast(state_count >> @intCast(width))),
            // A full-frequency symbol uses no bits and never this branch.
            .delta1 = if (width == 0) 0 else offset - @as(i32, frequency) + @as(i32, @intCast(state_count >> @intCast(width - 1))),
        };
        offset += frequency;
    }
    return .{ .state_count = state_count, .entries = entries };
}

pub fn valueSlot(value: u32, bases: []const i32, widths: []const u8) !usize {
    if (bases.len == 0 or bases.len != widths.len or bases.len > 256) return error.InvalidLzfseStream;
    for (bases, widths, 0..) |base_signed, width, symbol| {
        if (base_signed < 0 or width > 31) return error.InvalidLzfseStream;
        const base: u32 = @intCast(base_signed);
        if (value >= base and value - base < @as(u64, 1) << @intCast(width)) return symbol;
    }
    return error.InvalidLzfseStream;
}

fn validateDimensions(state_count: usize, symbol_count: usize) !void {
    if (state_count == 0 or state_count > 1024 or !std.math.isPowerOfTwo(state_count) or
        symbol_count == 0 or symbol_count > 256) return error.InvalidLzfseStream;
}

test {
    _ = @import("kernel_tests.zig");
}
