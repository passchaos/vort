//! Independent wire-bit and legal-path oracle. No production parser prices,
//! match finder, state transition helper, or dynamic-programming recurrence.
const std = @import("std");
const encoder = @import("encoder.zig");

pub const Decision = struct { length: usize = 1, distance: usize = 0 };

/// One-based repeat distances deliberately differ from the encoder's offsets.
pub const State = struct {
    code: u8 = 0,
    distances: [4]usize = @splat(1),

    pub fn fromModel(model: *const encoder.Model) State {
        var result = State{ .code = @intCast(model.state) };
        for (model.reps, &result.distances) |offset, *distance| distance.* = offset + 1;
        return result;
    }

    pub fn repeat(self: State, distance: usize) ?usize {
        for (self.distances, 0..) |known, rank| if (known == distance) return rank;
        return null;
    }

    pub fn after(self: State, decision: Decision) State {
        const literal_next = [_]u8{ 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 4, 5 };
        const match_next = [_]u8{ 7, 7, 7, 7, 7, 7, 7, 10, 10, 10, 10, 10 };
        const repeat_next = [_]u8{ 8, 8, 8, 8, 8, 8, 8, 11, 11, 11, 11, 11 };
        const short_next = [_]u8{ 9, 9, 9, 9, 9, 9, 9, 11, 11, 11, 11, 11 };
        var result = self;
        if (decision.distance == 0) {
            result.code = literal_next[self.code];
        } else if (decision.length == 1) {
            std.debug.assert(decision.distance == self.distances[0]);
            result.code = short_next[self.code];
        } else if (self.repeat(decision.distance)) |rank| {
            const old = self.distances;
            result.distances = switch (rank) {
                0 => old,
                1 => .{ old[1], old[0], old[2], old[3] },
                2 => .{ old[2], old[0], old[1], old[3] },
                3 => .{ old[3], old[0], old[1], old[2] },
                else => unreachable,
            };
            result.code = repeat_next[self.code];
        } else {
            result.distances = .{ decision.distance, self.distances[0], self.distances[1], self.distances[2] };
            result.code = match_next[self.code];
        }
        return result;
    }
};

pub const Counter = struct {
    cost: u32 = 0,

    /// Rounded 1/64-bit logarithms calculated from P=1/2,1/4,3/4,1/8,7/8.
    /// Non-power-of-two values are fixed hand expectations: log2(4/3)*64=27,
    /// log2(8/7)*64=12. Unsupported probabilities make a fixture fail.
    pub fn bit(self: *Counter, probability: u16, value: bool) !void {
        self.cost += switch (probability) {
            1024 => @as(u32, 64),
            512 => @as(u32, if (value) 27 else 128),
            1536 => @as(u32, if (value) 128 else 27),
            256 => @as(u32, if (value) 12 else 192),
            1792 => @as(u32, if (value) 192 else 12),
            else => return error.UnsupportedOracleProbability,
        };
    }

    /// Prefix-tree node addresses are derived from the already-written symbol
    /// prefix instead of following the production tree walker.
    pub fn msb(self: *Counter, probabilities: []const u16, symbol: usize, width: usize) !void {
        for (0..width) |written| {
            const node = (@as(usize, 1) << @intCast(written)) + (symbol >> @intCast(width - written));
            try self.bit(probabilities[node], symbol & (@as(usize, 1) << @intCast(width - written - 1)) != 0);
        }
    }

    pub fn lsb(self: *Counter, probabilities: []const u16, origin: usize, symbol: usize, width: usize) !void {
        for (0..width) |written| {
            var prefix: usize = 0;
            for (0..written) |prior| prefix = prefix * 2 + ((symbol >> @intCast(prior)) & 1);
            const node = (@as(usize, 1) << @intCast(written)) + prefix;
            try self.bit(probabilities[origin + node], symbol & (@as(usize, 1) << @intCast(written)) != 0);
        }
    }

    fn length(self: *Counter, lengths: anytype, size: usize, position_state: usize) !void {
        if (size <= 9) {
            try self.bit(lengths.choice, false);
            try self.msb(&lengths.low[position_state], size - 2, 3);
        } else {
            try self.bit(lengths.choice, true);
            if (size <= 17) {
                try self.bit(lengths.choice2, false);
                try self.msb(&lengths.mid[position_state], size - 10, 3);
            } else {
                try self.bit(lengths.choice2, true);
                try self.msb(&lengths.high, size - 18, 8);
            }
        }
    }

    fn writeDistance(self: *Counter, model: *const encoder.Model, size: usize, distance: usize) !void {
        const offset = distance - 1;
        var slot: usize = 0;
        var base: usize = 0;
        var suffix_width: usize = 0;
        // Enumerate wire slot intervals, independently of CLZ/bit extraction.
        while (slot < 64) : (slot += 1) {
            suffix_width = if (slot < 4) 0 else slot / 2 - 1;
            base = if (slot < 4) slot else (2 + slot % 2) * (@as(usize, 1) << @intCast(suffix_width));
            const span = @as(usize, 1) << @intCast(suffix_width);
            if (offset >= base and offset - base < span) break;
        }
        if (slot == 64) return error.InvalidOracleDistance;
        try self.msb(&model.position_slots[@min(size - 2, 3)], slot, 6);
        if (slot >= 4 and slot <= 13) {
            try self.lsb(&model.positions, base - slot, offset - base, suffix_width);
        } else if (slot >= 14) {
            self.cost += @as(u32, @intCast(suffix_width - 4)) * 64;
            try self.lsb(&model.alignment, 0, (offset - base) % 16, 4);
        }
    }
};

fn byteAt(history: []const u8, input: []const u8, absolute: usize) u8 {
    return if (absolute < history.len) history[absolute] else input[absolute - history.len];
}

pub fn matchLength(history: []const u8, input: []const u8, position: usize, distance: usize, window: usize) usize {
    const absolute = history.len + position;
    if (distance == 0 or distance > absolute or distance > window) return 0;
    var size: usize = 0;
    while (size < @min(input.len - position, 273) and byteAt(history, input, absolute + size - distance) == input[position + size]) : (size += 1) {}
    return size;
}

pub fn tokenCost(model: *const encoder.Model, history: []const u8, input: []const u8, position: usize, stream_start: usize, state: State, decision: Decision) !u32 {
    var bits: Counter = .{};
    const alignment = @as(usize, 1) << model.properties.pb;
    const ps = (stream_start + position) % alignment;
    try bits.bit(model.is_match[@as(usize, state.code) * 16 + ps], decision.distance != 0);
    if (decision.distance == 0) {
        const absolute = history.len + position;
        const previous = if (absolute == 0) @as(usize, 0) else byteAt(history, input, absolute - 1);
        const context = ((stream_start + position) % (@as(usize, 1) << model.properties.lp)) * (@as(usize, 1) << model.properties.lc) + previous / (@as(usize, 1) << @intCast(8 - model.properties.lc));
        const value: usize = input[position];
        const matched = if (state.code < 7) @as(usize, 0) else blk: {
            if (state.distances[0] > absolute) return error.InvalidOracleHistory;
            break :blk byteAt(history, input, absolute - state.distances[0]);
        };
        var same_prefix = state.code >= 7;
        for (0..8) |written| {
            const node = (@as(usize, 1) << @intCast(written)) + (value >> @intCast(8 - written));
            const mask = @as(usize, 1) << @intCast(7 - written);
            const extra = if (same_prefix) @as(usize, if (matched & mask == 0) 256 else 512) else 0;
            try bits.bit(model.literal_probabilities[context][extra + node], value & mask != 0);
            same_prefix = same_prefix and ((value ^ matched) & mask == 0);
        }
    } else if (state.repeat(decision.distance)) |rank| {
        try bits.bit(model.is_rep[state.code], true);
        try bits.bit(model.is_rep_g0[state.code], rank != 0);
        if (rank == 0) {
            if (decision.length == 1 and decision.distance != state.distances[0]) return error.InvalidOracleShortRep;
            try bits.bit(model.is_rep_0long[@as(usize, state.code) * 16 + ps], decision.length != 1);
        } else {
            if (decision.length == 1) return error.InvalidOracleShortRep;
            try bits.bit(model.is_rep_g1[state.code], rank != 1);
            if (rank != 1) try bits.bit(model.is_rep_g2[state.code], rank == 3);
        }
        if (decision.length != 1) try bits.length(model.rep_length, decision.length, ps);
    } else {
        if (decision.length < 2) return error.InvalidOracleShortRep;
        try bits.bit(model.is_rep[state.code], false);
        try bits.length(model.length, decision.length, ps);
        try bits.writeDistance(model, decision.length, decision.distance);
    }
    return bits.cost;
}

pub const Exhaustive = struct {
    rows: [17][256]State = undefined,
    counts: [17]usize = @splat(0),
    paths: usize = 0,
    minimum: u32 = std.math.maxInt(u32),

    pub fn run(self: *Exhaustive, model: *const encoder.Model, history: []const u8, input: []const u8, stream_start: usize) !void {
        if (input.len >= self.rows.len) return error.OracleFixtureTooLarge;
        try self.visit(model, history, input, stream_start, 0, State.fromModel(model), 0);
    }

    pub fn maximumStates(self: *const Exhaustive) usize {
        var maximum: usize = 0;
        for (self.counts) |count| maximum = @max(maximum, count);
        return maximum;
    }

    fn visit(self: *Exhaustive, model: *const encoder.Model, history: []const u8, input: []const u8, stream_start: usize, position: usize, state: State, cost: u32) anyerror!void {
        var known = false;
        for (self.rows[position][0..self.counts[position]]) |prior| if (std.meta.eql(prior, state)) {
            known = true;
        };
        if (!known) {
            if (self.counts[position] == self.rows[position].len) return error.OracleStateCapacityExceeded;
            self.rows[position][self.counts[position]] = state;
            self.counts[position] += 1;
        }
        if (position == input.len) {
            self.paths += 1;
            self.minimum = @min(self.minimum, cost);
            return;
        }
        try self.edge(model, history, input, stream_start, position, state, cost, .{});
        const short_distance = state.distances[0];
        if (matchLength(history, input, position, short_distance, model.dictionary_size) >= 1)
            try self.edge(model, history, input, stream_start, position, state, cost, .{ .distance = short_distance });
        // Enumerate every legal ordinary/repeated match and every possible
        // length. No matcher frontier, beam, row relaxation, or memoization.
        for (1..@min(history.len + position, model.dictionary_size) + 1) |distance| {
            const longest = matchLength(history, input, position, distance, model.dictionary_size);
            if (longest < 2) continue;
            for (2..longest + 1) |size| try self.edge(model, history, input, stream_start, position, state, cost, .{ .length = size, .distance = distance });
        }
    }

    fn edge(self: *Exhaustive, model: *const encoder.Model, history: []const u8, input: []const u8, stream_start: usize, position: usize, state: State, cost: u32, decision: Decision) !void {
        const added = try tokenCost(model, history, input, position, stream_start, state, decision);
        try self.visit(model, history, input, stream_start, position + decision.length, state.after(decision), cost + added);
    }
};

pub const Walk = struct { cost: u32, state: State, literals: usize, matches: usize, short_reps: usize };

pub fn walk(model: *const encoder.Model, history: []const u8, input: []const u8, stream_start: usize, tokens: []const encoder.AdvancedToken) !Walk {
    var result = Walk{ .cost = 0, .state = State.fromModel(model), .literals = 0, .matches = 0, .short_reps = 0 };
    var position: usize = 0;
    for (tokens) |token| {
        const decision: Decision = switch (token) {
            .literal => |value| blk: {
                try std.testing.expectEqual(input[position], value);
                result.literals += 1;
                break :blk .{};
            },
            .match => |match| blk: {
                try std.testing.expect(match.length >= 1 and match.length <= 273);
                try std.testing.expect(matchLength(history, input, position, match.distance, model.dictionary_size) >= match.length);
                if (match.length == 1) {
                    try std.testing.expectEqual(result.state.distances[0], match.distance);
                    result.short_reps += 1;
                }
                result.matches += 1;
                break :blk .{ .length = match.length, .distance = match.distance };
            },
        };
        result.cost += try tokenCost(model, history, input, position, stream_start, result.state, decision);
        result.state = result.state.after(decision);
        position += decision.length;
    }
    try std.testing.expectEqual(input.len, position);
    return result;
}
