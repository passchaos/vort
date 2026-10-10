const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidLzfseStream,
};

pub const BitReader = struct {
    bytes: []const u8,
    bit_position: usize,

    pub fn init(bytes: []const u8, final_bits: i32) Error!BitReader {
        if (final_bits < -7 or final_bits > 0) return error.InvalidLzfseStream;
        const total_bits = std.math.mul(usize, bytes.len, 8) catch
            return error.IntegerOverflow;
        const padding: usize = @intCast(-final_bits);
        if (padding > total_bits) return error.InvalidLzfseStream;
        const valid_bits = total_bits - padding;
        var bit = valid_bits;
        while (bit < total_bits) : (bit += 1) {
            if ((bytes[bit / 8] >> @intCast(bit & 7)) & 1 != 0)
                return error.InvalidLzfseStream;
        }
        return .{ .bytes = bytes, .bit_position = valid_bits };
    }

    pub fn pull(self: *BitReader, bit_count: u8) Error!u32 {
        if (bit_count > 31 or bit_count > self.bit_position)
            return error.InvalidLzfseStream;
        self.bit_position -= bit_count;
        var value: u32 = 0;
        for (0..bit_count) |index| {
            const bit = self.bit_position + index;
            value |= @as(u32, (self.bytes[bit / 8] >> @intCast(bit & 7)) & 1) <<
                @intCast(index);
        }
        return value;
    }
};

pub const DecoderEntry = struct {
    bit_count: u8,
    symbol: u8,
    delta: i32,
};

pub const ValueDecoderEntry = struct {
    total_bits: u8,
    value_bits: u8,
    delta: i32,
    value_base: i32,
};

pub fn validateFrequencies(frequencies: []const u16, state_count: usize) Error!void {
    if (!std.math.isPowerOfTwo(state_count)) return error.InvalidLzfseStream;
    var total: usize = 0;
    for (frequencies) |frequency| {
        total = std.math.add(usize, total, frequency) catch return error.IntegerOverflow;
    }
    if (total != state_count) return error.InvalidLzfseStream;
}

pub fn initDecoderTable(
    state_count: usize,
    frequencies: []const u16,
    table: []DecoderEntry,
) Error!void {
    if (table.len != state_count or frequencies.len > 256)
        return error.InvalidLzfseStream;
    try validateFrequencies(frequencies, state_count);
    const state_log = std.math.log2_int(usize, state_count);
    var offset: usize = 0;
    for (frequencies, 0..) |frequency_u16, symbol| {
        const frequency: usize = frequency_u16;
        if (frequency == 0) continue;
        const bit_count: usize = state_log - std.math.log2_int(usize, frequency);
        const split = ((2 * state_count) >> @intCast(bit_count)) - frequency;
        for (0..frequency) |index| {
            const entry = if (index < split)
                DecoderEntry{
                    .bit_count = @intCast(bit_count),
                    .symbol = @intCast(symbol),
                    .delta = @intCast(((frequency + index) << @intCast(bit_count)) - state_count),
                }
            else
                DecoderEntry{
                    .bit_count = @intCast(bit_count - 1),
                    .symbol = @intCast(symbol),
                    .delta = @intCast((index - split) << @intCast(bit_count - 1)),
                };
            table[offset + index] = entry;
        }
        offset += frequency;
    }
}

pub fn initValueDecoderTable(
    state_count: usize,
    frequencies: []const u16,
    value_bits: []const u8,
    value_bases: []const i32,
    table: []ValueDecoderEntry,
) Error!void {
    if (table.len != state_count or frequencies.len != value_bits.len or
        frequencies.len != value_bases.len or frequencies.len > 256)
        return error.InvalidLzfseStream;
    try validateFrequencies(frequencies, state_count);
    const state_log = std.math.log2_int(usize, state_count);
    var offset: usize = 0;
    for (frequencies, 0..) |frequency_u16, symbol| {
        const frequency: usize = frequency_u16;
        if (frequency == 0) continue;
        const state_bits: usize = state_log - std.math.log2_int(usize, frequency);
        const split = ((2 * state_count) >> @intCast(state_bits)) - frequency;
        for (0..frequency) |index| {
            const transition_bits = if (index < split) state_bits else state_bits - 1;
            const delta: usize = if (index < split)
                ((frequency + index) << @intCast(state_bits)) - state_count
            else
                (index - split) << @intCast(state_bits - 1);
            table[offset + index] = .{
                .total_bits = std.math.cast(u8, transition_bits + value_bits[symbol]) orelse
                    return error.InvalidLzfseStream,
                .value_bits = value_bits[symbol],
                .delta = @intCast(delta),
                .value_base = value_bases[symbol],
            };
        }
        offset += frequency;
    }
}

pub fn decodeSymbol(
    state: *u16,
    table: []const DecoderEntry,
    reader: *BitReader,
) Error!u8 {
    if (state.* >= table.len) return error.InvalidLzfseStream;
    const entry = table[state.*];
    const bits = try reader.pull(entry.bit_count);
    const next = std.math.add(i64, entry.delta, @as(i64, bits)) catch
        return error.IntegerOverflow;
    if (next < 0 or next >= table.len) return error.InvalidLzfseStream;
    state.* = @intCast(next);
    return entry.symbol;
}

pub fn decodeValue(
    state: *u16,
    table: []const ValueDecoderEntry,
    reader: *BitReader,
) Error!i32 {
    if (state.* >= table.len) return error.InvalidLzfseStream;
    const entry = table[state.*];
    const bits = try reader.pull(entry.total_bits);
    const value_mask = if (entry.value_bits == 0)
        0
    else
        (@as(u32, 1) << @intCast(entry.value_bits)) - 1;
    const next = std.math.add(
        i64,
        entry.delta,
        @as(i64, bits >> @intCast(entry.value_bits)),
    ) catch
        return error.IntegerOverflow;
    if (next < 0 or next >= table.len) return error.InvalidLzfseStream;
    state.* = @intCast(next);
    return std.math.add(i32, entry.value_base, @intCast(bits & value_mask)) catch
        return error.IntegerOverflow;
}

test "LZFSE reverse bit reader honors final padding" {
    var reader = try BitReader.init(&.{ 0b1010_1100, 0b0000_0101 }, -5);
    try std.testing.expectEqual(@as(u32, 0b10), try reader.pull(2));
    try std.testing.expectEqual(@as(u32, 0b110), try reader.pull(3));
    try std.testing.expectEqual(@as(u32, 0b10110), try reader.pull(5));
    try std.testing.expectError(error.InvalidLzfseStream, reader.pull(2));
    try std.testing.expectError(error.InvalidLzfseStream, BitReader.init(&.{0xff}, -7));
}
