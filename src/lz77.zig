const std = @import("std");
const core = @import("core.zig");

pub const Error = core.Error;

pub const min_match_len: usize = 3;
pub const max_match_len: usize = 258;
pub const default_window_len: usize = 32 * 1024;

pub const Token = union(enum) {
    literal: u8,
    match: Match,

    pub const Match = struct {
        length: u16,
        distance: u16,
    };
};

pub const PlanStats = struct {
    literals: usize = 0,
    matches: usize = 0,
    matched_bytes: usize = 0,

    pub fn tokenCount(self: PlanStats) usize {
        return self.literals + self.matches;
    }
};

pub const GreedyOptions = struct {
    window_len: usize = default_window_len,
    max_chain: usize = 128,
    nice_len: usize = 64,
    max_candidates: usize = 1,
};

pub const GreedyPlan = struct {
    tokens: []Token,
    stats: PlanStats,

    pub fn deinit(self: GreedyPlan, allocator: std.mem.Allocator) void {
        allocator.free(self.tokens);
    }
};

pub const max_optimal_candidates = 16;

pub fn greedyPlanAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    var tokens: std.ArrayList(Token) = .empty;
    errdefer tokens.deinit(allocator);
    var stats = PlanStats{};

    var pos: usize = 0;
    while (pos < input.len) {
        const best = findBestMatch(input, pos, options);
        if (best.length >= min_match_len) {
            try tokens.append(allocator, .{ .match = .{ .length = @intCast(best.length), .distance = @intCast(best.distance) } });
            stats.matches += 1;
            stats.matched_bytes += best.length;
            pos += best.length;
        } else {
            try tokens.append(allocator, .{ .literal = input[pos] });
            stats.literals += 1;
            pos += 1;
        }
    }

    return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
}

pub fn lazyGreedyPlanAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    var tokens: std.ArrayList(Token) = .empty;
    errdefer tokens.deinit(allocator);
    var stats = PlanStats{};

    var pos: usize = 0;
    while (pos < input.len) {
        const best = findBestMatch(input, pos, options);
        if (best.length < min_match_len) {
            try tokens.append(allocator, .{ .literal = input[pos] });
            stats.literals += 1;
            pos += 1;
            continue;
        }

        if (pos + 1 < input.len) {
            const next = findBestMatch(input, pos + 1, options);
            if (next.length > best.length + 1) {
                try tokens.append(allocator, .{ .literal = input[pos] });
                stats.literals += 1;
                pos += 1;
                continue;
            }
        }

        try tokens.append(allocator, .{ .match = .{ .length = @intCast(best.length), .distance = @intCast(best.distance) } });
        stats.matches += 1;
        stats.matched_bytes += best.length;
        pos += best.length;
    }

    return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
}

pub fn optimalPlanAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    const n = input.len;
    const costs = try allocator.alloc(usize, n + 1);
    defer allocator.free(costs);
    const steps = try allocator.alloc(Token, n);
    defer allocator.free(steps);
    costs[n] = 0;
    var rev_i: usize = n;
    while (rev_i > 0) {
        rev_i -= 1;
        costs[rev_i] = fixedLiteralCost(input[rev_i]) + costs[rev_i + 1];
        steps[rev_i] = .{ .literal = input[rev_i] };
        const candidates = findMatchCandidates(input, rev_i, options);
        for (candidates.items[0..candidates.len]) |best| {
            var len = min_match_len;
            while (len <= best.length) : (len += 1) {
                const cost = fixedMatchCost(len, best.distance) + costs[rev_i + len];
                if (cost < costs[rev_i]) {
                    costs[rev_i] = cost;
                    steps[rev_i] = .{ .match = .{ .length = @intCast(len), .distance = @intCast(best.distance) } };
                }
            }
        }
    }

    var tokens: std.ArrayList(Token) = .empty;
    errdefer tokens.deinit(allocator);
    var stats = PlanStats{};
    var pos: usize = 0;
    while (pos < n) {
        const token = steps[pos];
        try tokens.append(allocator, token);
        switch (token) {
            .literal => {
                stats.literals += 1;
                pos += 1;
            },
            .match => |m| {
                stats.matches += 1;
                stats.matched_bytes += m.length;
                pos += m.length;
            },
        }
    }
    return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
}

const MatchCandidates = struct {
    items: [max_optimal_candidates]MatchCandidate = undefined,
    len: usize = 0,

    fn add(self: *MatchCandidates, candidate: MatchCandidate, limit: usize) void {
        if (candidate.length < min_match_len) return;
        for (self.items[0..self.len]) |existing| {
            if (existing.distance == candidate.distance) return;
        }
        const capped_limit = @max(1, @min(limit, self.items.len));
        if (self.len < capped_limit) {
            self.items[self.len] = candidate;
            self.len += 1;
            return;
        }
        var worst_i: usize = 0;
        for (self.items[1..], 1..) |existing, i| {
            if (candidateBetter(self.items[worst_i], existing)) worst_i = i;
        }
        if (candidateBetter(candidate, self.items[worst_i])) self.items[worst_i] = candidate;
    }
};

fn candidateBetter(lhs: MatchCandidate, rhs: MatchCandidate) bool {
    if (lhs.length != rhs.length) return lhs.length > rhs.length;
    return lhs.distance < rhs.distance;
}

fn findMatchCandidates(input: []const u8, pos: usize, options: GreedyOptions) MatchCandidates {
    var out = MatchCandidates{};
    if (input.len - pos < min_match_len) return out;
    const window_len = @min(options.window_len, default_window_len);
    const start = pos -| window_len;
    const max_len = @min(max_match_len, input.len - pos);
    const candidate_limit = normalizedMaxCandidates(options);
    var checked: usize = 0;
    var candidate = pos;
    while (candidate > start and checked < options.max_chain) {
        candidate -= 1;
        if (input[candidate] != input[pos]) continue;
        checked += 1;
        var length: usize = 1;
        while (length < max_len and input[candidate + length] == input[pos + length]) {
            length += 1;
        }
        if (length >= min_match_len) {
            out.add(.{ .length = length, .distance = pos - candidate }, candidate_limit);
            if (length >= options.nice_len and out.len >= candidate_limit) break;
        }
    }
    return out;
}

fn normalizedMaxCandidates(options: GreedyOptions) usize {
    return @max(1, @min(options.max_candidates, max_optimal_candidates));
}

pub fn fixedBitCost(tokens: []const Token) usize {
    var cost: usize = 3;
    for (tokens) |token| {
        cost += switch (token) {
            .literal => |byte| fixedLiteralCost(byte),
            .match => |m| fixedMatchCost(m.length, m.distance),
        };
    }
    cost += 7; // fixed-Huffman end-of-block symbol 256.
    return cost;
}

fn fixedLiteralCost(byte: u8) usize {
    return if (byte <= 143) 8 else 9;
}

fn fixedMatchCost(length: usize, distance: usize) usize {
    return fixedLengthSymbolCost(length) + fixedDistanceSymbolCost(distance);
}

fn fixedLengthSymbolCost(length: usize) usize {
    std.debug.assert(length >= min_match_len and length <= max_match_len);
    return if (length == max_match_len) 8 else 7 + lengthExtraBits(length);
}

fn fixedDistanceSymbolCost(distance: usize) usize {
    std.debug.assert(distance >= 1 and distance <= default_window_len);
    return 5 + distanceExtraBits(distance);
}

fn lengthExtraBits(length: usize) usize {
    const bases = [_]usize{ 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 };
    const extras = [_]usize{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 };
    for (bases, 0..) |base, i| {
        const span: usize = if (extras[i] == 0) 1 else @as(usize, 1) << @intCast(extras[i]);
        if (length >= base and length < base + span) return extras[i];
    }
    unreachable;
}

fn distanceExtraBits(distance: usize) usize {
    const bases = [_]usize{ 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 };
    const extras = [_]usize{ 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 };
    for (bases, 0..) |base, i| {
        const span: usize = if (extras[i] == 0) 1 else @as(usize, 1) << @intCast(extras[i]);
        if (distance >= base and distance < base + span) return extras[i];
    }
    unreachable;
}

pub fn hashGreedyPlanAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    const table_size = 1 << 15;
    const head = try allocator.alloc(isize, table_size);
    defer allocator.free(head);
    @memset(head, -1);
    const prev = try allocator.alloc(isize, input.len);
    defer allocator.free(prev);
    @memset(prev, -1);

    var tokens: std.ArrayList(Token) = .empty;
    errdefer tokens.deinit(allocator);
    var stats = PlanStats{};

    var pos: usize = 0;
    while (pos < input.len) {
        var best = MatchCandidate{};
        if (pos + min_match_len <= input.len) {
            const h = hash3(input[pos..][0..3]) & (table_size - 1);
            var candidate_i = head[h];
            var checked: usize = 0;
            const max_len = @min(max_match_len, input.len - pos);
            while (candidate_i >= 0 and checked < options.max_chain) : (checked += 1) {
                const candidate: usize = @intCast(candidate_i);
                const distance = pos - candidate;
                if (distance == 0 or distance > options.window_len) break;
                const len = matchLength(input, candidate, pos, max_len);
                if (len >= min_match_len and len > best.length) {
                    best = .{ .length = len, .distance = distance };
                    if (len >= options.nice_len) break;
                }
                candidate_i = prev[candidate];
            }
        }

        if (best.length >= min_match_len) {
            try tokens.append(allocator, .{ .match = .{ .length = @intCast(best.length), .distance = @intCast(best.distance) } });
            stats.matches += 1;
            stats.matched_bytes += best.length;
            const end = @min(input.len, pos + best.length);
            while (pos < end) : (pos += 1) insertHash(input, pos, head, prev);
        } else {
            try tokens.append(allocator, .{ .literal = input[pos] });
            stats.literals += 1;
            insertHash(input, pos, head, prev);
            pos += 1;
        }
    }
    return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
}

fn matchLength(input: []const u8, a: usize, b: usize, max_len: usize) usize {
    var len: usize = 0;
    while (len + 8 <= max_len) : (len += 8) {
        const left = std.mem.readInt(u64, input[a + len ..][0..8], .little);
        const right = std.mem.readInt(u64, input[b + len ..][0..8], .little);
        if (left != right) {
            var inner: usize = 0;
            while (inner < 8 and input[a + len + inner] == input[b + len + inner]) inner += 1;
            return len + inner;
        }
    }
    while (len < max_len and input[a + len] == input[b + len]) len += 1;
    return len;
}

fn insertHash(input: []const u8, pos: usize, head: []isize, prev: []isize) void {
    if (pos + min_match_len > input.len) return;
    const h = hash3(input[pos..][0..3]) & (head.len - 1);
    prev[pos] = head[h];
    head[h] = @intCast(pos);
}

fn hash3(bytes: *const [3]u8) usize {
    const v: usize = (@as(usize, bytes[0]) << 16) | (@as(usize, bytes[1]) << 8) | bytes[2];
    return (v *% 2654435761) >> 16;
}

pub fn replayAlloc(allocator: std.mem.Allocator, tokens: []const Token) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    for (tokens) |token| {
        switch (token) {
            .literal => |byte| try out.append(allocator, byte),
            .match => |m| {
                if (m.distance == 0 or m.distance > out.items.len) return error.InvalidMatch;
                try out.ensureUnusedCapacity(allocator, m.length);
                var i: usize = 0;
                while (i < m.length) : (i += 1) {
                    const index = out.items.len - m.distance;
                    out.appendAssumeCapacity(out.items[index]);
                }
            },
        }
    }
    return out.toOwnedSlice(allocator);
}

const MatchCandidate = struct {
    length: usize = 0,
    distance: usize = 0,
};

fn findBestMatch(input: []const u8, pos: usize, options: GreedyOptions) MatchCandidate {
    if (input.len - pos < min_match_len) return .{};
    const window_len = @min(options.window_len, default_window_len);
    const start = pos -| window_len;
    const max_len = @min(max_match_len, input.len - pos);
    var best = MatchCandidate{};
    var checked: usize = 0;
    var candidate = pos;
    while (candidate > start and checked < options.max_chain) {
        candidate -= 1;
        if (input[candidate] != input[pos]) continue;
        checked += 1;
        var length: usize = 1;
        while (length < max_len and input[candidate + length] == input[pos + length]) {
            length += 1;
        }
        if (length >= min_match_len and length > best.length) {
            best = .{ .length = length, .distance = pos - candidate };
            if (length >= options.nice_len) break;
        }
    }
    return best;
}

test "greedy LZ77 planner round trips literals and matches" {
    const input = "abcabcabcabc xyz xyz xyz aaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const plan = try greedyPlanAlloc(std.testing.allocator, input, .{});
    defer plan.deinit(std.testing.allocator);
    try std.testing.expect(plan.stats.matches > 0);
    try std.testing.expect(plan.stats.literals > 0);
    const replayed = try replayAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
}

test "greedy LZ77 planner respects incompressible input" {
    const input = "abcdefghijklmnopqrstuvwxyz";
    const plan = try greedyPlanAlloc(std.testing.allocator, input, .{});
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(input.len, plan.stats.literals);
    try std.testing.expectEqual(@as(usize, 0), plan.stats.matches);
}

test "replay rejects invalid match distance" {
    const tokens = [_]Token{.{ .match = .{ .length = 3, .distance = 1 } }};
    try std.testing.expectError(error.InvalidMatch, replayAlloc(std.testing.allocator, &tokens));
}

test "lazy LZ77 planner round trips and keeps token count bounded" {
    const input = "abcabcxabcdabcabcxabcdabcabcx";
    const greedy = try greedyPlanAlloc(std.testing.allocator, input, .{});
    defer greedy.deinit(std.testing.allocator);
    const lazy = try lazyGreedyPlanAlloc(std.testing.allocator, input, .{});
    defer lazy.deinit(std.testing.allocator);
    const replayed = try replayAlloc(std.testing.allocator, lazy.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
    try std.testing.expect(lazy.stats.tokenCount() <= greedy.stats.tokenCount() + 1);
}

test "optimal LZ77 prototype round trips and is no worse by fixed bit cost" {
    const input = "abcabcxabcdabcabcxabcdabcabcx";
    const greedy = try greedyPlanAlloc(std.testing.allocator, input, .{});
    defer greedy.deinit(std.testing.allocator);
    const optimal = try optimalPlanAlloc(std.testing.allocator, input, .{});
    defer optimal.deinit(std.testing.allocator);
    const replayed = try replayAlloc(std.testing.allocator, optimal.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
    try std.testing.expect(fixedBitCost(optimal.tokens) <= fixedBitCost(greedy.tokens));
}

test "optimal LZ77 considers multiple match distances" {
    const input = "abcxxxxabcabcxxxxabcabc";
    const candidates = findMatchCandidates(input, 10, .{ .max_chain = 64, .nice_len = 258, .max_candidates = 4 });
    try std.testing.expect(candidates.len >= 2);
    const plan = try optimalPlanAlloc(std.testing.allocator, input, .{ .max_chain = 64, .nice_len = 258, .max_candidates = 4 });
    defer plan.deinit(std.testing.allocator);
    const replayed = try replayAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
}

test "match candidate enumeration honors configured limit" {
    const input = "abcxxxxabcabcxxxxabcabc";
    const one = findMatchCandidates(input, 10, .{ .max_chain = 64, .nice_len = 258, .max_candidates = 1 });
    const many = findMatchCandidates(input, 10, .{ .max_chain = 64, .nice_len = 258, .max_candidates = 4 });
    try std.testing.expectEqual(@as(usize, 1), one.len);
    try std.testing.expect(many.len > one.len);
}

test "fixed bit cost accounts for literals matches and end marker" {
    const tokens = [_]Token{
        .{ .literal = 'a' },
        .{ .literal = 200 },
        .{ .match = .{ .length = 3, .distance = 1 } },
    };
    try std.testing.expectEqual(@as(usize, 3 + 8 + 9 + 7 + 5 + 7), fixedBitCost(&tokens));
}

test "hash greedy planner round trips repeated data" {
    const input = "abcabcabcabc xyz xyz xyz aaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const plan = try hashGreedyPlanAlloc(std.testing.allocator, input, .{});
    defer plan.deinit(std.testing.allocator);
    try std.testing.expect(plan.stats.matches > 0);
    const replayed = try replayAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
}

test "matchLength compares word chunks and tails" {
    const input = "abcdefghijklmnopABCabcdefghijklmnopXYZ";
    try std.testing.expectEqual(@as(usize, 16), matchLength(input, 0, 19, 16));
    try std.testing.expectEqual(@as(usize, 3), matchLength(input, 0, 19, 3));
}
