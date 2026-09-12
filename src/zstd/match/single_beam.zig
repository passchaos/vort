const std = @import("std");
const builtin = @import("builtin");
const lz77 = @import("../../lz77.zig");

const text_section = switch (builtin.object_format) {
    .elf => ".vort_zstd_single_beam",
    .macho => "__TEXT,__vort_zstd_sb",
    .coff => ".text$vort_zstd_single_beam",
    else => ".text",
};

const max_input_len = std.math.maxInt(u16);
const min_match = 4;
const head_size = 4096;
const empty = std.math.maxInt(u16);
const max_chain = 16;

const State = struct {
    cost: u32 = std.math.maxInt(u32),
    rep0: u16 = 1,
    previous_position: u16 = 0,
    token: lz77.Token = .{ .literal = 0 },
};

pub const Scratch = struct {
    head: [head_size]u16 = @splat(empty),
    prev: std.ArrayList(u16) = .empty,
    states: std.ArrayList(State) = .empty,
    occupied: std.ArrayList(u8) = .empty,
    reversed: std.ArrayList(lz77.Token) = .empty,

    pub fn deinit(self: *Scratch, allocator: std.mem.Allocator) void {
        self.reversed.deinit(allocator);
        self.occupied.deinit(allocator);
        self.states.deinit(allocator);
        self.prev.deinit(allocator);
        self.* = .{};
    }
};

pub noinline fn planReuse(scratch: *Scratch, allocator: std.mem.Allocator, input: []const u8) linksection(text_section) !lz77.PlanStats {
    return planReuseWithChainLimit(scratch, allocator, input, max_chain);
}

pub fn planDeepReferenceReuse(scratch: *Scratch, allocator: std.mem.Allocator, input: []const u8) !lz77.PlanStats {
    return planReuseWithChainLimit(scratch, allocator, input, 128);
}

fn planReuseWithChainLimit(
    scratch: *Scratch,
    allocator: std.mem.Allocator,
    input: []const u8,
    comptime chain_limit: usize,
) !lz77.PlanStats {
    if (input.len == 0 or input.len > max_input_len) return error.InvalidBlockPlan;
    try scratch.prev.resize(allocator, input.len);
    @memset(&scratch.head, empty);
    try scratch.states.resize(allocator, input.len + 1);
    try scratch.occupied.resize(allocator, input.len + 1);
    const states = scratch.states.items;
    const occupied = scratch.occupied.items;
    @memset(occupied, 0);
    states[0] = .{ .cost = 0 };
    occupied[0] = 1;

    for (0..input.len) |position| {
        std.debug.assert(occupied[position] != 0);
        const state = states[position];
        insertState(states, occupied, position + 1, .{
            .cost = state.cost + literalCost(input[position]),
            .rep0 = state.rep0,
            .previous_position = @intCast(position),
            .token = .{ .literal = input[position] },
        });

        if (position + min_match > input.len) {
            scratch.prev.items[position] = empty;
            continue;
        }
        const anchor = std.mem.readInt(u32, input[position..][0..4], .little);
        const hash = hashWord(anchor);
        const first_candidate = scratch.head[hash];
        scratch.prev.items[position] = first_candidate;
        scratch.head[hash] = @intCast(position);
        const indexed_match = firstIndexedMatch(scratch, input, position, first_candidate, anchor, chain_limit);
        if (indexed_match) |match|
            extendMatch(states, occupied, position, state, match);
        const indexed_rep0 = if (indexed_match) |match| match.distance == state.rep0 else false;
        if (state.rep0 <= position and !indexed_rep0) {
            const length = matchAtDistance(input, position, state.rep0, anchor);
            if (length != 0) extendMatch(states, occupied, position, state, .{
                .length = @intCast(length),
                .distance = state.rep0,
            });
        }
    }

    scratch.reversed.clearRetainingCapacity();
    try scratch.reversed.ensureTotalCapacity(allocator, @min(input.len, 4096));
    var position = input.len;
    while (position != 0) {
        const state = states[position];
        try scratch.reversed.append(allocator, state.token);
        position = state.previous_position;
    }
    std.mem.reverse(lz77.Token, scratch.reversed.items);

    var stats: lz77.PlanStats = .{};
    for (scratch.reversed.items) |token| switch (token) {
        .literal => stats.literals += 1,
        .match => |match| {
            stats.matches += 1;
            stats.matched_bytes += match.length;
        },
    };
    return stats;
}

fn firstIndexedMatch(
    scratch: *const Scratch,
    input: []const u8,
    position: usize,
    first_candidate: u16,
    anchor: u32,
    comptime chain_limit: usize,
) ?lz77.Token.Match {
    var candidate_i = first_candidate;
    var checked: usize = 0;
    const maximum = @min(lz77.max_match_len, input.len - position);
    const window_len = @min(input.len, lz77.default_window_len);
    while (candidate_i != empty and checked < chain_limit) : (checked += 1) {
        const candidate: usize = candidate_i;
        const distance = position - candidate;
        if (distance == 0 or distance > window_len) break;
        if (std.mem.readInt(u32, input[candidate..][0..4], .little) == anchor)
            return .{
                .length = @intCast(matchLengthAfterPrefix(input, candidate, position, maximum, min_match)),
                .distance = @intCast(distance),
            };
        candidate_i = scratch.prev.items[candidate];
    }
    return null;
}

fn extendMatch(states: []State, occupied: []u8, position: usize, state: State, match: lz77.Token.Match) void {
    const distance_cost: u32 = if (match.distance == state.rep0) 1 else @intCast(distanceCost(match.distance) + 4);
    insertState(states, occupied, position + match.length, .{
        .cost = state.cost + lengthCost(match.length) + distance_cost,
        .rep0 = match.distance,
        .previous_position = @intCast(position),
        .token = .{ .match = match },
    });
}

fn insertState(states: []State, occupied: []u8, position: usize, candidate: State) void {
    if (occupied[position] == 0 or candidate.cost < states[position].cost) {
        states[position] = candidate;
        occupied[position] = 1;
    }
}

fn matchAtDistance(input: []const u8, position: usize, distance: usize, anchor: u32) usize {
    if (distance == 0 or distance > position) return 0;
    const candidate = position - distance;
    if (std.mem.readInt(u32, input[candidate..][0..4], .little) != anchor) return 0;
    return matchLengthAfterPrefix(input, candidate, position, @min(lz77.max_match_len, input.len - position), min_match);
}

fn matchLengthAfterPrefix(input: []const u8, a: usize, b: usize, maximum: usize, prefix_len: usize) usize {
    var len = prefix_len;
    while (len + 32 <= maximum) : (len += 32) {
        const left: @Vector(32, u8) = input[a + len ..][0..32].*;
        const right: @Vector(32, u8) = input[b + len ..][0..32].*;
        const differing: u32 = ~@as(u32, @bitCast(left == right));
        if (differing != 0) return len + @ctz(differing);
    }
    while (len + 8 <= maximum) : (len += 8) {
        const left = std.mem.readInt(u64, input[a + len ..][0..8], .little);
        const right = std.mem.readInt(u64, input[b + len ..][0..8], .little);
        if (left != right) return len + @ctz(left ^ right) / 8;
    }
    while (len < maximum and input[a + len] == input[b + len]) len += 1;
    return len;
}

fn hash4(input: []const u8, position: usize) usize {
    const word = std.mem.readInt(u32, input[position..][0..4], .little);
    return hashWord(word);
}

inline fn hashWord(word: u32) usize {
    return ((word *% 2654435761) >> 17) & (head_size - 1);
}

fn literalCost(byte: u8) u32 {
    return if (byte <= 143) 8 else 9;
}

fn lengthCost(length: usize) u32 {
    return if (length <= 10) 7 else if (length <= 18) 8 else if (length <= 34) 9 else if (length <= 66) 10 else if (length <= 130) 11 else if (length <= 257) 12 else 8;
}

fn distanceCost(distance: usize) usize {
    if (distance <= 4) return 5;
    return 4 + std.math.log2_int(usize, distance - 1);
}

test "single-state repeat beam replays bounded input" {
    const input = ("abcdefgh-abcdefgh-" ** 128) ++ ("0123456789abcdef" ** 64);
    var scratch: Scratch = .{};
    defer scratch.deinit(std.testing.allocator);
    const stats = try planReuse(&scratch, std.testing.allocator, input);
    const replayed = try lz77.replayAlloc(std.testing.allocator, scratch.reversed.items);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
    try std.testing.expectEqual(input.len, stats.literals + stats.matched_bytes);
}

test "single-state fused index matches prebuilt predecessor chains" {
    var input: [8192]u8 = undefined;
    var random_state: u32 = 0x243f_6a88;
    for (&input, 0..) |*byte, index| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 52)
            @intCast('a' + index % 23)
        else
            @truncate(random_state >> 24);
    }

    var expected_head: [head_size]u16 = @splat(empty);
    const expected_prev = try std.testing.allocator.alloc(u16, input.len);
    defer std.testing.allocator.free(expected_prev);
    for (&input, 0..) |_, position| {
        if (position + min_match > input.len) {
            expected_prev[position] = empty;
            continue;
        }
        const hash = hash4(&input, position);
        expected_prev[position] = expected_head[hash];
        expected_head[hash] = @intCast(position);
    }

    var scratch: Scratch = .{};
    defer scratch.deinit(std.testing.allocator);
    _ = try planReuse(&scratch, std.testing.allocator, &input);
    try std.testing.expectEqualSlices(u16, &expected_head, &scratch.head);
    try std.testing.expectEqualSlices(u16, expected_prev, scratch.prev.items);
}

test "single-state prefixed match extension preserves every boundary" {
    var input: [768]u8 = undefined;
    var random_state: u32 = 0x9e37_79b9;
    for (&input) |*byte| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(random_state >> 24);
    }
    const candidate: usize = 17;
    const position: usize = 320;
    for (min_match..259) |expected| {
        @memcpy(input[position..][0..expected], input[candidate..][0..expected]);
        if (position + expected < input.len)
            input[position + expected] = input[candidate + expected] ^ 1;
        const maximum = @min(expected + 1, input.len - position);
        try std.testing.expectEqual(expected, matchLengthAfterPrefix(&input, candidate, position, maximum, min_match));
    }
}

test "single-state bounded chain preserves generated plan cost" {
    var fast: Scratch = .{};
    defer fast.deinit(std.testing.allocator);
    var deep: Scratch = .{};
    defer deep.deinit(std.testing.allocator);
    var changed: usize = 0;
    var higher_cost: usize = 0;
    var total_fast_cost: usize = 0;
    var total_deep_cost: usize = 0;
    var worst_extra: usize = 0;

    for (0..128) |seed| {
        const length = 4 * 1024 + (seed % 8) * 4 * 1024;
        const input = try std.testing.allocator.alloc(u8, length);
        defer std.testing.allocator.free(input);
        var random_state: u32 = @truncate(0x6a09_e667 +% seed *% 0x0100_0193);
        for (input, 0..) |*byte, index| {
            random_state = random_state *% 1_664_525 +% 1_013_904_223;
            byte.* = switch (seed & 3) {
                0 => @truncate(random_state >> 24),
                1 => @intCast('a' + (index + seed) % 23),
                2 => if (index % 64 < 52) @intCast('a' + (index / 7 + seed) % 19) else @truncate(random_state >> 24),
                else => @truncate((index * 37 + (index / 11) * 17 + seed) & 0xff),
            };
        }
        if (seed % 3 == 0) {
            const copy_len = input.len / 4;
            @memcpy(input[input.len - copy_len ..], input[input.len / 4 ..][0..copy_len]);
        }

        const fast_stats = try planReuseWithChainLimit(&fast, std.testing.allocator, input, max_chain);
        const deep_stats = try planReuseWithChainLimit(&deep, std.testing.allocator, input, 128);
        try std.testing.expectEqual(input.len, fast_stats.literals + fast_stats.matched_bytes);
        try std.testing.expectEqual(input.len, deep_stats.literals + deep_stats.matched_bytes);
        const fast_cost = planCost(fast.reversed.items);
        const deep_cost = planCost(deep.reversed.items);
        changed += @intFromBool(!tokenSlicesEqual(fast.reversed.items, deep.reversed.items));
        higher_cost += @intFromBool(fast_cost > deep_cost);
        total_fast_cost += fast_cost;
        total_deep_cost += deep_cost;
        worst_extra = @max(worst_extra, fast_cost -| deep_cost);
    }
    try std.testing.expectEqual(@as(usize, 1), changed);
    try std.testing.expectEqual(@as(usize, 1), higher_cost);
    try std.testing.expectEqual(@as(usize, 4_593_896), total_fast_cost);
    try std.testing.expectEqual(@as(usize, 4_593_884), total_deep_cost);
    try std.testing.expectEqual(@as(usize, 12), worst_extra);
}

fn planCost(tokens: []const lz77.Token) usize {
    var total: usize = 0;
    var rep0: usize = 1;
    for (tokens) |token| switch (token) {
        .literal => |byte| total += literalCost(byte),
        .match => |match| {
            total += lengthCost(match.length);
            total += if (match.distance == rep0) 1 else distanceCost(match.distance) + 4;
            rep0 = match.distance;
        },
    };
    return total;
}

fn tokenSlicesEqual(a: []const lz77.Token, b: []const lz77.Token) bool {
    if (a.len != b.len) return false;
    for (a, b) |left, right| switch (left) {
        .literal => |byte| switch (right) {
            .literal => |other| if (byte != other) return false,
            .match => return false,
        },
        .match => |match| switch (right) {
            .literal => return false,
            .match => |other| if (match.length != other.length or match.distance != other.distance) return false,
        },
    };
    return true;
}

test "single-state repeat beam releases every allocation failure" {
    const input = ("abcdefgh-abcdefgh-" ** 128) ++ ("0123456789abcdef" ** 64);
    const Test = struct {
        fn run(allocator: std.mem.Allocator, bytes: []const u8) !void {
            var scratch: Scratch = .{};
            defer scratch.deinit(allocator);
            const stats = try planReuse(&scratch, allocator, bytes);
            try std.testing.expectEqual(bytes.len, stats.literals + stats.matched_bytes);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{input});
}
