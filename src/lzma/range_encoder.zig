const std = @import("std");

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    low: u64 = 0,
    range: u32 = 0xffff_ffff,
    cache: u8 = 0,
    cache_size: usize = 1,
    /// Maximum total output length including the five-byte range flush.
    byte_limit: ?usize = null,
    finishing: bool = false,

    pub fn init(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) Encoder {
        return .{ .allocator = allocator, .output = output };
    }

    pub fn initWithLimit(allocator: std.mem.Allocator, output: *std.ArrayList(u8), byte_limit: usize) Encoder {
        return .{ .allocator = allocator, .output = output, .byte_limit = byte_limit };
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
        if (self.byte_limit) |limit| {
            if (try self.finishedSize() > limit) return error.CompressedPayloadLimitExceeded;
        }
        self.finishing = true;
        defer self.finishing = false;
        for (0..5) |_| try self.shiftLow();
    }

    /// Exact size after the five-byte range flush. Every cached byte is
    /// emitted; the fifth shift leaves exactly one new byte cached.
    pub fn finishedSize(self: *const Encoder) error{IntegerOverflow}!usize {
        const with_cache = std.math.add(usize, self.output.items.len, self.cache_size) catch
            return error.IntegerOverflow;
        return std.math.add(usize, with_cache, 4) catch error.IntegerOverflow;
    }

    /// Reserve staged output while keeping bounded candidates' allocation
    /// capacity within their payload limit as well as their emitted length.
    pub fn ensureOutputCapacity(self: *Encoder, additional: usize) !void {
        if (self.byte_limit) |limit| {
            const required = std.math.add(usize, self.output.items.len, additional) catch return error.IntegerOverflow;
            if (required > limit) return error.CompressedPayloadLimitExceeded;
            const grown_capacity = self.output.capacity +| (self.output.capacity / 2) +| 8;
            try self.output.ensureTotalCapacityPrecise(self.allocator, @min(limit, @max(required, grown_capacity)));
        } else try self.output.ensureUnusedCapacity(self.allocator, additional);
    }

    fn shiftLow(self: *Encoder) !void {
        const low_tail: u32 = @truncate(self.low);
        const carry: u8 = @intCast(self.low >> 32);
        const flush = low_tail < 0xff00_0000 or carry != 0;
        const next_cache_size = std.math.add(usize, if (flush) 0 else self.cache_size, 1) catch
            return error.IntegerOverflow;
        if (self.byte_limit) |limit| {
            const emitted_end = std.math.add(usize, self.output.items.len, if (flush) self.cache_size else 0) catch
                return error.IntegerOverflow;
            const required = if (self.finishing) emitted_end else blk: {
                const pending_end = std.math.add(usize, emitted_end, next_cache_size) catch return error.IntegerOverflow;
                break :blk std.math.add(usize, pending_end, 4) catch return error.IntegerOverflow;
            };
            if (required > limit) return error.CompressedPayloadLimitExceeded;
            if (flush) try self.ensureOutputCapacity(self.cache_size);
        }
        if (flush) {
            var byte = self.cache;
            while (self.cache_size != 0) : (self.cache_size -= 1) {
                if (self.byte_limit != null) {
                    self.output.appendAssumeCapacity(byte +% carry);
                } else try self.output.append(self.allocator, byte +% carry);
                byte = 0xff;
            }
            self.cache = @truncate(low_tail >> 24);
        }
        self.cache_size = next_cache_size;
        self.low = @as(u64, low_tail & 0x00ff_ffff) << 8;
    }
};
