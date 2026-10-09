const std = @import("std");

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    low: u64 = 0,
    range: u32 = 0xffff_ffff,
    cache: u8 = 0,
    cache_size: usize = 1,

    pub fn init(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) Encoder {
        return .{ .allocator = allocator, .output = output };
    }

    pub fn encodeBit(self: *Encoder, probability: *u16, bit: bool) !void {
        const bound = (self.range >> 11) * probability.*;
        if (!bit) {
            self.range = bound;
            probability.* += (0x800 - probability.*) >> 5;
        } else {
            self.low += bound;
            self.range -= bound;
            probability.* -= probability.* >> 5;
        }
        if (self.range < 0x0100_0000) {
            self.range <<= 8;
            try self.shiftLow();
        }
    }

    pub fn encodeDirectBits(self: *Encoder, value: usize, bit_count: usize) !void {
        var remaining = bit_count;
        while (remaining != 0) {
            remaining -= 1;
            self.range >>= 1;
            if (value >> @intCast(remaining) & 1 != 0) self.low += self.range;
            if (self.range < 0x0100_0000) {
                self.range <<= 8;
                try self.shiftLow();
            }
        }
    }

    pub fn encodeBitTree(
        self: *Encoder,
        probabilities: []u16,
        symbol: usize,
        bit_count: usize,
    ) !void {
        var tree_index: usize = 1;
        var remaining = bit_count;
        while (remaining != 0) {
            remaining -= 1;
            const bit = symbol >> @intCast(remaining) & 1 != 0;
            try self.encodeBit(&probabilities[tree_index], bit);
            tree_index = (tree_index << 1) | @intFromBool(bit);
        }
    }

    pub fn encodeReverseBitTree(
        self: *Encoder,
        probabilities: []u16,
        offset: usize,
        symbol: usize,
        bit_count: usize,
    ) !void {
        var tree_index: usize = 1;
        for (0..bit_count) |bit_index| {
            const bit = symbol >> @intCast(bit_index) & 1 != 0;
            try self.encodeBit(&probabilities[offset + tree_index], bit);
            tree_index = (tree_index << 1) | @intFromBool(bit);
        }
    }

    pub fn finish(self: *Encoder) !void {
        for (0..5) |_| try self.shiftLow();
    }

    fn shiftLow(self: *Encoder) !void {
        const low_tail: u32 = @truncate(self.low);
        const carry: u8 = @intCast(self.low >> 32);
        if (low_tail < 0xff00_0000 or carry != 0) {
            var byte = self.cache;
            while (self.cache_size != 0) : (self.cache_size -= 1) {
                try self.output.append(self.allocator, byte +% carry);
                byte = 0xff;
            }
            self.cache = @truncate(low_tail >> 24);
        }
        self.cache_size += 1;
        self.low = @as(u64, low_tail & 0x00ff_ffff) << 8;
    }
};
