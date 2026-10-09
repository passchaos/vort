const std = @import("std");
const bit_reader = @import("bit_reader.zig");

const max_code_bits: usize = 16;
const pretree_symbol_count: usize = 20;

pub fn readLengths(reader: *bit_reader.Reader, lengths: []u5) !void {
    var pretree_lengths: [pretree_symbol_count]u5 = undefined;
    for (&pretree_lengths) |*length|
        length.* = @intCast(try reader.readBits(4));
    const pretree = try Canonical(pretree_symbol_count).init(
        &pretree_lengths,
        false,
    );

    var index: usize = 0;
    while (index < lengths.len) {
        var symbol = try pretree.decode(reader);
        switch (symbol) {
            17 => {
                const count = @as(usize, try reader.readBits(4)) + 4;
                if (count > lengths.len - index) return error.InvalidLzxStream;
                @memset(lengths[index..][0..count], 0);
                index += count;
            },
            18 => {
                const count = @as(usize, try reader.readBits(5)) + 20;
                if (count > lengths.len - index) return error.InvalidLzxStream;
                @memset(lengths[index..][0..count], 0);
                index += count;
            },
            19 => {
                const count = @as(usize, try reader.readBits(1)) + 4;
                if (count > lengths.len - index) return error.InvalidLzxStream;
                symbol = try pretree.decode(reader);
                const value: u5 = @intCast((@as(usize, lengths[index]) + 34 - symbol) % 17);
                @memset(lengths[index..][0..count], value);
                index += count;
            },
            0...16 => {
                lengths[index] = @intCast((@as(usize, lengths[index]) + 34 - symbol) % 17);
                index += 1;
            },
            else => return error.InvalidLzxStream,
        }
    }
}

pub fn Canonical(comptime capacity: usize) type {
    return struct {
        counts: [max_code_bits + 1]u16 = @splat(0),
        first_code: [max_code_bits + 1]u32 = @splat(0),
        first_symbol: [max_code_bits + 1]u16 = @splat(0),
        symbols: [capacity]u16 = undefined,
        symbol_count: usize = 0,

        const Self = @This();

        pub fn init(lengths: []const u5, allow_empty: bool) !Self {
            if (lengths.len > capacity) return error.InvalidLzxStream;
            var result: Self = .{};
            for (lengths) |length| {
                if (length > max_code_bits) return error.InvalidLzxStream;
                if (length != 0) {
                    result.counts[length] += 1;
                    result.symbol_count += 1;
                }
            }
            if (result.symbol_count == 0) {
                if (!allow_empty) return error.InvalidLzxStream;
                return result;
            }

            var code: u32 = 0;
            var symbol_base: usize = 0;
            var available: i32 = 1;
            for (1..max_code_bits + 1) |bits| {
                available = available * 2 - result.counts[bits];
                if (available < 0) return error.InvalidLzxStream;
                code = (code + result.counts[bits - 1]) << 1;
                result.first_code[bits] = code;
                result.first_symbol[bits] = @intCast(symbol_base);
                symbol_base += result.counts[bits];
            }
            if (available != 0) return error.InvalidLzxStream;

            var next = result.first_symbol;
            for (lengths, 0..) |length, symbol| {
                if (length == 0) continue;
                result.symbols[next[length]] = @intCast(symbol);
                next[length] += 1;
            }
            return result;
        }

        pub fn decode(self: *const Self, reader: *bit_reader.Reader) !usize {
            if (self.symbol_count == 0) return error.InvalidLzxStream;
            var code: u32 = 0;
            for (1..max_code_bits + 1) |bits| {
                code = (code << 1) | try reader.readBits(1);
                const first = self.first_code[bits];
                if (code < first) continue;
                const offset = code - first;
                if (offset < self.counts[bits])
                    return self.symbols[self.first_symbol[bits] + offset];
            }
            return error.InvalidLzxStream;
        }
    };
}

test "LZX canonical Huffman rejects incomplete and oversubscribed trees" {
    try std.testing.expectError(
        error.InvalidLzxStream,
        Canonical(4).init(&.{ 1, 0, 0, 0 }, false),
    );
    try std.testing.expectError(
        error.InvalidLzxStream,
        Canonical(4).init(&.{ 1, 1, 1, 0 }, false),
    );
    const empty = try Canonical(4).init(&.{ 0, 0, 0, 0 }, true);
    try std.testing.expectEqual(@as(usize, 0), empty.symbol_count);
}
