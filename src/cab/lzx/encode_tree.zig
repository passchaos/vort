const std = @import("std");
const shared = @import("../../huffman.zig");
const writer_mod = @import("word_writer.zig");

pub fn Code(comptime capacity: usize) type {
    return struct {
        lengths: [capacity]u5 = @splat(0),
        codes: [capacity]u16 = @splat(0),

        const Self = @This();
        pub fn init(frequencies: [capacity]u32, max_bits: u4) Self {
            var freqs = frequencies;
            var active: usize = 0;
            var only: usize = 0;
            for (freqs, 0..) |freq, symbol| if (freq != 0) {
                active += 1;
                only = symbol;
            };
            if (active == 0) return .{};
            // LZX requires a complete tree even for a one-symbol alphabet.
            if (active == 1) freqs[if (only == 0) 1 else 0] = 1;
            const lengths = shared.treeCodeLengths(capacity, &freqs, max_bits);
            var result: Self = .{};
            var counts: [16]u32 = @splat(0);
            for (lengths, 0..) |bits, symbol| {
                result.lengths[symbol] = bits;
                if (bits != 0) counts[bits] += 1;
            }
            var next: [16]u32 = @splat(0);
            for (1..16) |bits| next[bits] = (next[bits - 1] + counts[bits - 1]) << 1;
            for (lengths, 0..) |bits, symbol| if (bits != 0) {
                result.codes[symbol] = @intCast(next[bits]);
                next[bits] += 1;
            };
            return result;
        }

        pub fn write(self: *const Self, allocator: std.mem.Allocator, writer: *writer_mod.Writer, symbol: usize) !void {
            if (symbol >= capacity or self.lengths[symbol] == 0) return error.InvalidBlockPlan;
            try writer.writeBits(allocator, self.codes[symbol], self.lengths[symbol]);
        }
    };
}

const Token = struct { symbol: u5, value: u5 = 0, bits: u3 = 0, delta: u5 = 0 };

/// Write the LZX modulo-17 length deltas and zero/equal-length run symbols.
pub fn writeLengths(allocator: std.mem.Allocator, writer: *writer_mod.Writer, previous: []const u5, lengths: []const u5) !void {
    if (previous.len != lengths.len or lengths.len > 656) return error.InvalidBlockPlan;
    var tokens: [656]Token = undefined;
    var token_count: usize = 0;
    var frequencies: [20]u32 = @splat(0);
    var index: usize = 0;
    while (index < lengths.len) {
        const length = lengths[index];
        if (length > 16 or previous[index] > 16) return error.InvalidBlockPlan;
        var run: usize = 1;
        while (index + run < lengths.len and lengths[index + run] == length) : (run += 1) {}
        var token: Token = undefined;
        var consumed: usize = 1;
        if (length == 0 and run >= 20) {
            consumed = @min(run, 51);
            token = .{ .symbol = 18, .value = @intCast(consumed - 20), .bits = 5 };
        } else if (length == 0 and run >= 4) {
            consumed = @min(run, 19);
            token = .{ .symbol = 17, .value = @intCast(consumed - 4), .bits = 4 };
        } else {
            const delta: u5 = @intCast((@as(usize, previous[index]) + 17 - length) % 17);
            if (length != 0 and run >= 4) {
                consumed = @min(run, 5);
                token = .{ .symbol = 19, .value = @intCast(consumed - 4), .bits = 1, .delta = delta };
                frequencies[delta] += 1;
            } else token = .{ .symbol = delta };
        }
        tokens[token_count] = token;
        token_count += 1;
        frequencies[token.symbol] += 1;
        index += consumed;
    }
    const precode = Code(20).init(frequencies, 7);
    for (precode.lengths) |bits| try writer.writeBits(allocator, bits, 4);
    for (tokens[0..token_count]) |token| {
        try precode.write(allocator, writer, token.symbol);
        try writer.writeBits(allocator, token.value, token.bits);
        if (token.symbol == 19) try precode.write(allocator, writer, token.delta);
    }
}
