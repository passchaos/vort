const std = @import("std");
const core = @import("../core.zig");
const adaptive = @import("adaptive_huffman.zig");
const probability = @import("probability.zig");
const tables = @import("tables.zig");
const streams = @import("stream_encoder.zig");

pub const Error = core.Error || adaptive.Error || std.mem.Allocator.Error || error{InvalidLzms};
pub const Lz = struct { offset: u32, length: u32 };
pub const Delta = struct { power: u8, raw_offset: u32, length: u32 };
pub const Item = union(enum) { literal: u8, lz: Lz, delta: Delta };
pub const Summary = struct {
    literals: usize = 0,
    lz_matches: usize = 0,
    lz_repeats: usize = 0,
    delta_matches: usize = 0,
    delta_repeats: usize = 0,
    matched_bytes: usize = 0,
    max_lz_offset: u32 = 0,
    max_delta_offset: usize = 0,
    delta_power_mask: u8 = 0,
};

const State = struct {
    literal: adaptive.AdaptiveEncoder(256),
    lz_offset: adaptive.AdaptiveEncoder(tables.max_offset_symbols),
    delta_offset: adaptive.AdaptiveEncoder(tables.max_offset_symbols),
    length: adaptive.AdaptiveEncoder(54),
    delta_power: adaptive.AdaptiveEncoder(8),
    main_prob: [16]probability.Entry = @splat(.{}),
    match_prob: [32]probability.Entry = @splat(.{}),
    lz_prob: [64]probability.Entry = @splat(.{}),
    delta_prob: [64]probability.Entry = @splat(.{}),
    lz_rep_prob: [2][64]probability.Entry = @splat(@splat(.{})),
    delta_rep_prob: [2][64]probability.Entry = @splat(@splat(.{})),
    main_state: u32 = 0,
    match_state: u32 = 0,
    lz_state: u32 = 0,
    delta_state: u32 = 0,
    lz_rep_state: [2]u32 = .{ 0, 0 },
    delta_rep_state: [2]u32 = .{ 0, 0 },
    recent_lz: [4]u32 = .{ 1, 2, 3, 4 },
    recent_delta: [4]u64 = .{ 1, 2, 3, 4 },
    previous: u2 = 0,
};

/// Serializes a validated item plan over already x86-transformed bytes.
/// Any failure is sticky; range/Huffman state is owned until deinit().
pub const Encoder = struct {
    allocator: std.mem.Allocator,
    state: *State,
    range: streams.RangeEncoder = .{},
    bits: streams.BackwardBitWriter,
    expected: usize,
    position: usize = 0,
    summary: Summary = .{},
    failed: ?Error = null,
    finished: bool = false,

    pub fn init(allocator: std.mem.Allocator, expected: usize) Error!Encoder {
        if (expected > tables.max_buffer_size) return error.OutputLimitExceeded;
        const state = try allocator.create(State);
        errdefer allocator.destroy(state);
        const slots = @max(@as(usize, 1), tables.numOffsetSlots(expected));
        state.* = .{
            .literal = try adaptive.AdaptiveEncoder(256).init(256, 1024),
            .lz_offset = try adaptive.AdaptiveEncoder(tables.max_offset_symbols).init(slots, 1024),
            .delta_offset = try adaptive.AdaptiveEncoder(tables.max_offset_symbols).init(slots, 1024),
            .length = try adaptive.AdaptiveEncoder(54).init(54, 512),
            .delta_power = try adaptive.AdaptiveEncoder(8).init(8, 512),
        };
        return .{ .allocator = allocator, .state = state, .bits = .{ .allocator = allocator }, .expected = expected };
    }

    pub fn deinit(self: *Encoder) void {
        self.range.bytes.deinit(self.allocator);
        self.bits.words.deinit(self.allocator);
        self.allocator.destroy(self.state);
        self.* = undefined;
    }

    fn decision(self: *Encoder, state: *u32, entries: []probability.Entry, bit: u1) Error!void {
        const entry = &entries[state.*];
        const predicted = entry.probability();
        state.* = ((state.* << 1) | bit) & @as(u32, @intCast(entries.len - 1));
        entry.update(bit);
        try self.range.encodeBit(self.allocator, bit, predicted);
    }

    pub fn push(self: *Encoder, item: Item) Error!void {
        if (self.failed) |err| return err;
        self.pushInternal(item) catch |err| {
            self.failed = err;
            return err;
        };
    }

    fn validate(self: *const Encoder, item: Item) Error!usize {
        if (self.finished) return error.InvalidLzms;
        const length: usize = switch (item) {
            .literal => 1,
            .lz => |v| v.length,
            .delta => |v| v.length,
        };
        if (self.position > self.expected or length > self.expected - self.position) return error.InvalidLzms;
        switch (item) {
            .literal => {},
            .lz => |v| {
                if (v.offset == 0 or v.offset > self.position) return error.InvalidLzms;
                _ = try tables.offsetSlot(v.offset);
                _ = try tables.lengthSlot(v.length);
            },
            .delta => |v| {
                if (v.power > 7 or v.raw_offset == 0) return error.InvalidLzms;
                const span: usize = @as(usize, 1) << @intCast(v.power);
                const offset = std.math.mul(usize, v.raw_offset, span) catch return error.InvalidLzms;
                const reach = std.math.add(usize, offset, span) catch return error.InvalidLzms;
                if (reach > self.position) return error.InvalidLzms;
                _ = try tables.offsetSlot(v.raw_offset);
                _ = try tables.lengthSlot(v.length);
            },
        }
        return length;
    }

    fn pushInternal(self: *Encoder, item: Item) Error!void {
        const length = try self.validate(item);
        const s = self.state;
        try self.decision(&s.main_state, &s.main_prob, @intFromBool(item != .literal));
        switch (item) {
            .literal => |value| {
                try s.literal.encode(&self.bits, value);
                s.previous = 0;
                self.summary.literals += 1;
            },
            .lz => |v| {
                try self.decision(&s.match_state, &s.match_prob, 0);
                const delayed: usize = s.previous & 1;
                const rank = repeatRank(u32, &s.recent_lz, delayed, v.offset);
                try self.decision(&s.lz_state, &s.lz_prob, @intFromBool(rank != null));
                if (rank) |r| {
                    try self.repeatBits(&s.lz_rep_state, &s.lz_rep_prob, r);
                    moveToFront(u32, &s.recent_lz, r + delayed);
                    self.summary.lz_repeats += 1;
                } else {
                    const slot = try tables.offsetSlot(v.offset);
                    try s.lz_offset.encode(&self.bits, slot);
                    try self.bits.writeBits(v.offset - tables.offset_slot_base[slot], @intCast(tables.extra_offset_bits[slot]));
                    insertRecent(u32, &s.recent_lz, v.offset);
                }
                try self.writeLength(v.length);
                s.previous = 1;
                self.summary.lz_matches += 1;
                self.summary.matched_bytes += length;
                self.summary.max_lz_offset = @max(self.summary.max_lz_offset, v.offset);
            },
            .delta => |v| {
                try self.decision(&s.match_state, &s.match_prob, 1);
                const pair = (@as(u64, v.power) << 32) | v.raw_offset;
                const delayed: usize = s.previous >> 1;
                const rank = repeatRank(u64, &s.recent_delta, delayed, pair);
                try self.decision(&s.delta_state, &s.delta_prob, @intFromBool(rank != null));
                if (rank) |r| {
                    try self.repeatBits(&s.delta_rep_state, &s.delta_rep_prob, r);
                    moveToFront(u64, &s.recent_delta, r + delayed);
                    self.summary.delta_repeats += 1;
                } else {
                    const slot = try tables.offsetSlot(v.raw_offset);
                    try s.delta_power.encode(&self.bits, v.power);
                    try s.delta_offset.encode(&self.bits, slot);
                    try self.bits.writeBits(v.raw_offset - tables.offset_slot_base[slot], @intCast(tables.extra_offset_bits[slot]));
                    insertRecent(u64, &s.recent_delta, pair);
                }
                try self.writeLength(v.length);
                s.previous = 2;
                self.summary.delta_matches += 1;
                self.summary.matched_bytes += length;
                self.summary.max_delta_offset = @max(self.summary.max_delta_offset, @as(usize, v.raw_offset) << @intCast(v.power));
                self.summary.delta_power_mask |= @as(u8, 1) << @intCast(v.power);
            },
        }
        self.position += length;
    }

    fn repeatBits(self: *Encoder, states: *[2]u32, probs: *[2][64]probability.Entry, rank: usize) Error!void {
        try self.decision(&states[0], &probs[0], @intFromBool(rank != 0));
        if (rank != 0) try self.decision(&states[1], &probs[1], @intFromBool(rank == 2));
    }

    fn writeLength(self: *Encoder, length: u32) Error!void {
        const slot = try tables.lengthSlot(length);
        try self.state.length.encode(&self.bits, slot);
        try self.bits.writeBits(length - tables.length_slot_base[slot], @intCast(tables.extra_length_bits[slot]));
    }

    pub fn finishAlloc(self: *Encoder) Error![]u8 {
        if (self.failed) |err| return err;
        return self.finishInternal() catch |err| {
            self.failed = err;
            return err;
        };
    }

    fn finishInternal(self: *Encoder) Error![]u8 {
        if (self.finished or self.position != self.expected) return error.InvalidLzms;
        if (self.expected == 0) {
            self.finished = true;
            return self.allocator.alloc(u8, 0);
        }
        try self.bits.finish();
        try self.range.finish(self.allocator);
        const total = std.math.add(usize, self.range.bytes.items.len, std.math.mul(usize, self.bits.words.items.len, 2) catch return error.IntegerOverflow) catch return error.IntegerOverflow;
        const output = try self.allocator.alloc(u8, total);
        @memcpy(output[0..self.range.bytes.items.len], self.range.bytes.items);
        for (0..self.bits.words.items.len) |index| {
            const word = self.bits.words.items[self.bits.words.items.len - index - 1];
            std.mem.writeInt(u16, output[self.range.bytes.items.len + index * 2 ..][0..2], word, .little);
        }
        self.finished = true;
        return output;
    }

    pub fn recentLz(self: *const Encoder) [4]u32 {
        return self.state.recent_lz;
    }
    pub fn recentDelta(self: *const Encoder) [4]u64 {
        return self.state.recent_delta;
    }

    pub fn literalCost(self: *const Encoder, value: u8) u16 {
        return self.state.literal.lengths[value] + @as(u16, @intCast(bitCost(self.state.main_prob[self.state.main_state], 0)));
    }

    /// Integer upper-bit estimate for greedy arbitration. Final encoded-wire
    /// selection also compares the complete literal reference stream.
    pub fn itemCost(self: *const Encoder, item: Item) Error!u32 {
        _ = try self.validate(item);
        const s = self.state;
        if (item == .literal) return self.literalCost(item.literal);
        var cost = bitCost(s.main_prob[s.main_state], 1);
        const length = switch (item) {
            .lz => |v| v.length,
            .delta => |v| v.length,
            else => unreachable,
        };
        const length_slot = try tables.lengthSlot(length);
        cost += @as(u32, s.length.lengths[length_slot]) + tables.extra_length_bits[length_slot];
        const is_delta = item == .delta;
        cost += bitCost(s.match_prob[s.match_state], @intFromBool(is_delta));
        if (item == .lz) {
            const value = item.lz.offset;
            const rank = repeatRank(u32, &s.recent_lz, s.previous & 1, value);
            cost += bitCost(s.lz_prob[s.lz_state], @intFromBool(rank != null));
            if (rank) |r| return cost + repeatCost(&s.lz_rep_state, &s.lz_rep_prob, r);
            const slot = try tables.offsetSlot(value);
            return cost + @as(u32, s.lz_offset.lengths[slot]) + tables.extra_offset_bits[slot];
        }
        const value = item.delta;
        const pair = (@as(u64, value.power) << 32) | value.raw_offset;
        const rank = repeatRank(u64, &s.recent_delta, s.previous >> 1, pair);
        cost += bitCost(s.delta_prob[s.delta_state], @intFromBool(rank != null));
        if (rank) |r| return cost + repeatCost(&s.delta_rep_state, &s.delta_rep_prob, r);
        const slot = try tables.offsetSlot(value.raw_offset);
        return cost + @as(u32, s.delta_power.lengths[value.power]) + s.delta_offset.lengths[slot] + tables.extra_offset_bits[slot];
    }
};

fn bitCost(entry: probability.Entry, bit: u1) u32 {
    const p = if (bit == 0) entry.probability() else probability.denominator - entry.probability();
    return probability.bits - (31 - @clz(p));
}

fn repeatCost(states: *const [2]u32, probs: *const [2][64]probability.Entry, rank: usize) u32 {
    var cost = bitCost(probs[0][states[0]], @intFromBool(rank != 0));
    if (rank != 0) cost += bitCost(probs[1][states[1]], @intFromBool(rank == 2));
    return cost;
}

fn repeatRank(comptime T: type, recent: *const [4]T, delayed: usize, value: T) ?usize {
    for (0..3) |rank| if (recent[rank + delayed] == value) return rank;
    return null;
}

fn moveToFront(comptime T: type, recent: *[4]T, index: usize) void {
    const value = recent[index];
    var cursor = index;
    while (cursor != 0) : (cursor -= 1) recent[cursor] = recent[cursor - 1];
    recent[0] = value;
}

fn insertRecent(comptime T: type, recent: *[4]T, value: T) void {
    for (0..3) |index| recent[3 - index] = recent[2 - index];
    recent[0] = value;
}
