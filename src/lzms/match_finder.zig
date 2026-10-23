const std = @import("std");
const options_module = @import("encode_options.zig");
const items = @import("item_encoder.zig");
const tables = @import("tables.zig");

pub const Error = items.Error;

/// Portable bounded greedy reference matcher. Difference signatures include
/// their stride phase so delta sources use integral raw offsets. Tables hold
/// positions only; each bucket retains an in-window anchor and the latest
/// position, so a later collision does not immediately erase older matches.
pub const Finder = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
    options: options_module.Options,
    heads: []u32,
    entries: usize,

    pub fn init(allocator: std.mem.Allocator, input: []const u8, options: options_module.Options) Error!Finder {
        try options.validate();
        const entries: usize = @as(usize, 1) << @intCast(options.hash_log);
        const families: usize = 1 + (if (options.enable_delta) @as(usize, options.max_delta_power) + 1 else 0);
        const count = if (input.len >= 4) entries * families * 2 else 0;
        const heads = try allocator.alloc(u32, count);
        @memset(heads, std.math.maxInt(u32));
        return .{ .allocator = allocator, .input = input, .options = options, .heads = heads, .entries = entries };
    }

    pub fn deinit(self: *Finder) void {
        self.allocator.free(self.heads);
        self.* = undefined;
    }

    fn hash(self: *const Finder, position: usize, power: ?u3) usize {
        var value: u32 = 0;
        if (power) |p| {
            const span: usize = @as(usize, 1) << p;
            for (0..4) |index| value |= @as(u32, self.input[position + index] -% self.input[position + index - span]) << @intCast(index * 8);
            value ^= @as(u32, @intCast(position & (span - 1))) *% 0x85eb_ca6b;
        } else {
            value = std.mem.readInt(u32, self.input[position..][0..4], .little);
        }
        return @intCast((value *% 0x9e37_79b1) >> @intCast(32 - self.options.hash_log));
    }

    pub fn advance(self: *Finder, start: usize, length: usize) void {
        for (start..start + length) |position| {
            if (self.input.len - position < 4) continue;
            self.seed(self.hash(position, null) * 2, position);
            if (!self.options.enable_delta) continue;
            for (0..@as(usize, self.options.max_delta_power) + 1) |power| {
                const span: usize = @as(usize, 1) << @intCast(power);
                if (position < span) continue;
                self.seed(((power + 1) * self.entries + self.hash(position, @intCast(power))) * 2, position);
            }
        }
    }

    fn seed(self: *Finder, index: usize, position: usize) void {
        const anchor = self.heads[index];
        if (anchor == std.math.maxInt(u32) or position - anchor > self.options.max_match_distance)
            self.heads[index] = @intCast(position);
        self.heads[index + 1] = @intCast(position);
    }

    const Winner = struct { item: ?items.Item = null, gain: u64 = 0 };

    pub fn find(self: *const Finder, encoder: *const items.Encoder) Error!?items.Item {
        const position = encoder.position;
        var winner = Winner{};
        for (encoder.recentLz()) |offset| try self.lzCandidate(encoder, offset, &winner);
        if (self.input.len - position >= 4) {
            const index = self.hash(position, null) * 2;
            for (self.heads[index..][0..2]) |previous| {
                if (previous != std.math.maxInt(u32) and previous < position)
                    try self.lzCandidate(encoder, @intCast(position - previous), &winner);
            }
        }
        if (self.options.enable_delta) {
            for (encoder.recentDelta()) |pair| {
                const power = pair >> 32;
                if (power <= self.options.max_delta_power)
                    try self.deltaCandidate(encoder, @intCast(power), @truncate(pair), &winner);
            }
            if (self.input.len - position >= 4) for (0..@as(usize, self.options.max_delta_power) + 1) |power| {
                const span: usize = @as(usize, 1) << @intCast(power);
                if (position < span) continue;
                const index = ((power + 1) * self.entries + self.hash(position, @intCast(power))) * 2;
                for (self.heads[index..][0..2]) |previous| {
                    if (previous == std.math.maxInt(u32) or previous >= position or previous < span) continue;
                    const distance = position - previous;
                    if (distance % span != 0) continue;
                    try self.deltaCandidate(encoder, @intCast(power), @intCast(distance / span), &winner);
                }
            };
        }
        return winner.item;
    }

    fn lzCandidate(self: *const Finder, encoder: *const items.Encoder, offset: u32, winner: *Winner) Error!void {
        const position = encoder.position;
        if (offset == 0 or offset > position or offset > self.options.max_match_distance) return;
        const source = position - offset;
        const limit = @min(self.input.len - position, tables.max_match_length);
        var length: usize = 0;
        while (length < limit and self.input[position + length] == self.input[source + length]) : (length += 1) {}
        if (length < 2) return;
        try self.consider(encoder, .{ .lz = .{ .offset = offset, .length = @intCast(length) } }, length, winner);
    }

    fn deltaCandidate(self: *const Finder, encoder: *const items.Encoder, power: u3, raw_offset: u32, winner: *Winner) Error!void {
        const position = encoder.position;
        if (raw_offset == 0) return;
        const span: usize = @as(usize, 1) << power;
        const offset = std.math.mul(usize, raw_offset, span) catch return;
        const reach = std.math.add(usize, offset, span) catch return;
        if (reach > position or offset > self.options.max_match_distance) return;
        const source = position - offset;
        const limit = @min(self.input.len - position, tables.max_match_length);
        var length: usize = 0;
        while (length < limit) : (length += 1) {
            const value = self.input[source + length] +% self.input[position + length - span] -% self.input[source + length - span];
            if (self.input[position + length] != value) break;
        }
        if (length < 2) return;
        try self.consider(encoder, .{ .delta = .{ .power = power, .raw_offset = raw_offset, .length = @intCast(length) } }, length, winner);
    }

    fn consider(self: *const Finder, encoder: *const items.Encoder, item: items.Item, length: usize, winner: *Winner) Error!void {
        var literal_cost: u64 = 0;
        for (self.input[encoder.position..][0..length]) |byte| literal_cost += encoder.literalCost(byte);
        const cost = try encoder.itemCost(item);
        if (literal_cost <= cost) return;
        const gain = literal_cost - cost;
        if (gain > winner.gain) winner.* = .{ .item = item, .gain = gain };
    }
};
