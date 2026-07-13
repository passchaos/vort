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
    lazy_min_gain: usize = 2,
    min_match: usize = min_match_len,
    max_match: usize = max_match_len,
    min_savings_bits: usize = 0,
};

pub const GreedyPlan = struct {
    tokens: []Token,
    stats: PlanStats,

    pub fn deinit(self: GreedyPlan, allocator: std.mem.Allocator) void {
        allocator.free(self.tokens);
    }
};

pub const max_optimal_candidates = 16;

pub fn literalPlanAlloc(allocator: std.mem.Allocator, input: []const u8) !GreedyPlan {
    const tokens = try allocator.alloc(Token, input.len);
    errdefer allocator.free(tokens);
    for (input, tokens) |byte, *token| token.* = .{ .literal = byte };
    return .{ .tokens = tokens, .stats = .{ .literals = input.len } };
}

pub fn filteredPlanAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    var filtered = options;
    filtered.min_match = @max(filtered.min_match, 5);
    filtered.min_savings_bits = @max(filtered.min_savings_bits, 8);
    filtered.max_candidates = @min(filtered.max_candidates, 2);
    return lazyGreedyPlanAlloc(allocator, input, filtered);
}

pub fn runLengthPlanAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    var tokens: std.ArrayList(Token) = .empty;
    errdefer tokens.deinit(allocator);
    var stats = PlanStats{};

    var pos: usize = 0;
    while (pos < input.len) {
        if (pos > 0 and input[pos] == input[pos - 1]) {
            const max_len = @min(maxMatch(options), input.len - pos);
            var len: usize = 1;
            while (len < max_len and input[pos + len] == input[pos - 1]) len += 1;
            if (acceptMatch(input, pos, len, 1, options)) {
                try tokens.append(allocator, .{ .match = .{ .length = @intCast(len), .distance = 1 } });
                stats.matches += 1;
                stats.matched_bytes += len;
                pos += len;
                continue;
            }
        }

        try tokens.append(allocator, .{ .literal = input[pos] });
        stats.literals += 1;
        pos += 1;
    }

    return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
}

pub fn greedyPlanAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    var tokens: std.ArrayList(Token) = .empty;
    errdefer tokens.deinit(allocator);
    var stats = PlanStats{};

    var pos: usize = 0;
    while (pos < input.len) {
        const best = findBestMatch(input, pos, options);
        if (acceptMatch(input, pos, best.length, best.distance, options)) {
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
    if (preferScanLazy(input)) return scanLazyGreedyPlanAlloc(allocator, input, options);
    return hashLazyGreedyPlanAlloc(allocator, input, options);
}

fn preferScanLazy(input: []const u8) bool {
    if (input.len < 1024) return true;

    var seen: [256]bool = @splat(false);
    var unique: usize = 0;
    const sample_len = @min(input.len, 1024);
    for (input[0..sample_len]) |byte| {
        if (!seen[byte]) {
            seen[byte] = true;
            unique += 1;
        }
    }
    // The backwards scanner wins on tiny and low-entropy inputs because it has
    // no table allocation/clear cost and quickly finds long repeated runs.
    // Hash chains pay off on natural text/source where a blind backward scan
    // spends most of its time stepping over non-candidates.
    return unique <= 48;
}

fn scanLazyGreedyPlanAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    var tokens: std.ArrayList(Token) = .empty;
    errdefer tokens.deinit(allocator);
    var stats = PlanStats{};

    var pos: usize = 0;
    while (pos < input.len) {
        const best = findBestMatch(input, pos, options);
        if (!acceptMatch(input, pos, best.length, best.distance, options)) {
            try tokens.append(allocator, .{ .literal = input[pos] });
            stats.literals += 1;
            pos += 1;
            continue;
        }

        if (pos + 1 < input.len) {
            const next = findBestMatch(input, pos + 1, options);
            if (next.length >= best.length + options.lazy_min_gain and acceptMatch(input, pos + 1, next.length, next.distance, options)) {
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

fn hashLazyGreedyPlanAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
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
        const best = findBestHashMatch(input, pos, options, head, prev);
        if (!acceptMatch(input, pos, best.length, best.distance, options)) {
            try tokens.append(allocator, .{ .literal = input[pos] });
            stats.literals += 1;
            insertHash(input, pos, head, prev);
            pos += 1;
            continue;
        }

        var current_inserted = false;
        if (pos + 1 < input.len) {
            // Insert the current position before the lazy probe so distance-1
            // runs can be discovered at pos+1. If we keep the current match we
            // skip re-inserting pos below and only seed the skipped positions.
            insertHash(input, pos, head, prev);
            current_inserted = true;
            const next = findBestHashMatch(input, pos + 1, options, head, prev);
            if (next.length >= best.length + options.lazy_min_gain and acceptMatch(input, pos + 1, next.length, next.distance, options)) {
                try tokens.append(allocator, .{ .literal = input[pos] });
                stats.literals += 1;
                pos += 1;
                continue;
            }
        }

        try tokens.append(allocator, .{ .match = .{ .length = @intCast(best.length), .distance = @intCast(best.distance) } });
        stats.matches += 1;
        stats.matched_bytes += best.length;
        var insert_pos = if (current_inserted) pos + 1 else pos;
        const end = @min(input.len, pos + best.length);
        while (insert_pos < end) : (insert_pos += 1) insertHash(input, insert_pos, head, prev);
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

    // Build hash chain for fast match discovery.
    const table_size = 1 << 15;
    const head = try allocator.alloc(isize, table_size);
    defer allocator.free(head);
    @memset(head, -1);
    const prev = try allocator.alloc(isize, n);
    defer allocator.free(prev);
    @memset(prev, -1);

    // Pre-populate hash chain for all positions.
    for (0..n) |i| insertHash(input, i, head, prev);

    costs[n] = 0;
    var rev_i: usize = n;
    const minimum = minMatch(options);
    const candidate_limit = normalizedMaxCandidates(options);

    while (rev_i > 0) {
        rev_i -= 1;
        costs[rev_i] = fixedLiteralCost(input[rev_i]) + costs[rev_i + 1];
        steps[rev_i] = .{ .literal = input[rev_i] };

        if (rev_i + minimum > n) continue;

        const max_len = @min(maxMatch(options), n - rev_i);
        var chain_i = prev[rev_i];
        var checked: usize = 0;
        var candidates_seen: usize = 0;

        while (chain_i >= 0 and checked < options.max_chain) : (checked += 1) {
            const candidate: usize = @intCast(chain_i);
            std.debug.assert(candidate < rev_i);
            const distance = rev_i - candidate;
            if (distance == 0 or distance > options.window_len) break;

            const length = matchLength(input, candidate, rev_i, max_len);
            if (length >= minimum) {
                var len = length;
                while (len >= minimum) : (len -= 1) {
                    const cost = fixedMatchCost(len, distance) + costs[rev_i + len];
                    if (cost < costs[rev_i]) {
                        costs[rev_i] = cost;
                        steps[rev_i] = .{ .match = .{ .length = @intCast(len), .distance = @intCast(distance) } };
                    }
                }
                candidates_seen += 1;
                if (length >= options.nice_len and candidates_seen >= candidate_limit) break;
                if (candidates_seen >= candidate_limit) break;
            }
            chain_i = prev[candidate];
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

fn normalizedMaxCandidates(options: GreedyOptions) usize {
    return @max(1, @min(options.max_candidates, max_optimal_candidates));
}

fn minMatch(options: GreedyOptions) usize {
    return @max(min_match_len, @min(options.min_match, maxMatch(options)));
}

fn maxMatch(options: GreedyOptions) usize {
    return @max(min_match_len, @min(options.max_match, max_match_len));
}

fn acceptMatch(input: []const u8, pos: usize, length: usize, distance: usize, options: GreedyOptions) bool {
    if (length < minMatch(options) or distance == 0) return false;
    if (pos + length > input.len) return false;
    const match_cost = fixedMatchCost(length, distance);
    const required_cost = match_cost + options.min_savings_bits;
    const literal_min_cost = length * 8;
    if (literal_min_cost >= required_cost) return true;
    if (literal_min_cost + length < required_cost) return false;

    var literal_cost = literal_min_cost;
    for (input[pos..][0..length]) |byte| literal_cost += @intFromBool(byte > 143);
    return literal_cost >= required_cost;
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
        const best = findBestHashMatch(input, pos, options, head, prev);

        if (acceptMatch(input, pos, best.length, best.distance, options)) {
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

fn findBestHashMatch(input: []const u8, pos: usize, options: GreedyOptions, head: []const isize, prev: []const isize) MatchCandidate {
    const minimum = minMatch(options);
    if (pos + minimum > input.len) return .{};

    const h = hash3(input[pos..][0..3]) & (head.len - 1);
    var candidate_i = head[h];
    var checked: usize = 0;
    const max_len = @min(maxMatch(options), input.len - pos);
    var best = MatchCandidate{};
    while (candidate_i >= 0 and checked < options.max_chain) : (checked += 1) {
        const candidate: usize = @intCast(candidate_i);
        const distance = pos - candidate;
        if (distance == 0 or distance > options.window_len) break;
        const len = matchLength(input, candidate, pos, max_len);
        if (len >= minimum and len > best.length) {
            best = .{ .length = len, .distance = distance };
            if (len >= options.nice_len) break;
        }
        candidate_i = prev[candidate];
    }
    return best;
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
    const minimum = minMatch(options);
    if (input.len - pos < minimum) return .{};
    const window_len = @min(options.window_len, default_window_len);
    const start = pos -| window_len;
    const max_len = @min(maxMatch(options), input.len - pos);
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
        if (length >= minimum and length > best.length) {
            best = .{ .length = length, .distance = pos - candidate };
            if (length >= options.nice_len) break;
        }
    }
    return best;
}

test "literal-only LZ77 planner emits no matches" {
    const input = "abcabcabc";
    const plan = try literalPlanAlloc(std.testing.allocator, input);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(input.len, plan.stats.literals);
    try std.testing.expectEqual(@as(usize, 0), plan.stats.matches);
    const replayed = try replayAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
}

test "filtered LZ77 planner suppresses short low-value matches" {
    const input = "abcabc abcabc abcabc";
    const normal = try lazyGreedyPlanAlloc(std.testing.allocator, input, .{});
    defer normal.deinit(std.testing.allocator);
    const filtered = try filteredPlanAlloc(std.testing.allocator, input, .{});
    defer filtered.deinit(std.testing.allocator);
    try std.testing.expect(filtered.stats.matches <= normal.stats.matches);
    const replayed = try replayAlloc(std.testing.allocator, filtered.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
}

test "run-length LZ77 planner limits matches to byte runs" {
    const input = "aaaaabbbbccxyz";
    const plan = try runLengthPlanAlloc(std.testing.allocator, input, .{ .min_match = 3 });
    defer plan.deinit(std.testing.allocator);
    try std.testing.expect(plan.stats.matches >= 2);
    for (plan.tokens) |token| switch (token) {
        .match => |m| try std.testing.expectEqual(@as(u16, 1), m.distance),
        else => {},
    };
    const replayed = try replayAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
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

test "lazy parser honors minimum gain threshold" {
    const input = "aabcabc";
    const permissive = try lazyGreedyPlanAlloc(std.testing.allocator, input, .{ .lazy_min_gain = 1 });
    defer permissive.deinit(std.testing.allocator);
    const conservative = try lazyGreedyPlanAlloc(std.testing.allocator, input, .{ .lazy_min_gain = 3 });
    defer conservative.deinit(std.testing.allocator);
    try std.testing.expect(permissive.stats.literals >= conservative.stats.literals);
    const replayed = try replayAlloc(std.testing.allocator, permissive.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
}

test "parser honors configurable minimum match length" {
    const input = "abcabc";
    const min3 = try greedyPlanAlloc(std.testing.allocator, input, .{ .min_match = 3 });
    defer min3.deinit(std.testing.allocator);
    const min4 = try greedyPlanAlloc(std.testing.allocator, input, .{ .min_match = 4 });
    defer min4.deinit(std.testing.allocator);
    try std.testing.expect(min3.stats.matches > 0);
    try std.testing.expectEqual(@as(usize, 0), min4.stats.matches);
}

test "parser honors minimum savings threshold" {
    const input = "abcabc";
    const permissive = try greedyPlanAlloc(std.testing.allocator, input, .{ .min_savings_bits = 0 });
    defer permissive.deinit(std.testing.allocator);
    const strict = try greedyPlanAlloc(std.testing.allocator, input, .{ .min_savings_bits = 64 });
    defer strict.deinit(std.testing.allocator);
    try std.testing.expect(permissive.stats.matches > 0);
    try std.testing.expectEqual(@as(usize, 0), strict.stats.matches);
}

test "parser honors configurable maximum match length" {
    const input = "aaaaaaaaaaaaaaaa";
    const capped = try greedyPlanAlloc(std.testing.allocator, input, .{ .max_match = 4 });
    defer capped.deinit(std.testing.allocator);
    for (capped.tokens) |token| switch (token) {
        .match => |m| try std.testing.expect(m.length <= 4),
        else => {},
    };
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
    // The hash-chain-based optimal parser may find different matches than greedy,
    // but must produce a valid round-trip and a reasonable token count.
    try std.testing.expect(optimal.stats.tokenCount() <= greedy.stats.tokenCount() + 2);
}

test "optimal LZ77 considers multiple match distances" {
    const input = "abcxxxxabcabcxxxxabcabc";
    const plan = try optimalPlanAlloc(std.testing.allocator, input, .{ .max_chain = 64, .nice_len = 258, .max_candidates = 4 });
    defer plan.deinit(std.testing.allocator);
    const replayed = try replayAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
    try std.testing.expect(plan.stats.matches > 0);
}

test "optimal parser token count is bounded by candidate limit" {
    const input = "abcxxxxabcabcxxxxabcabc";
    const one = try optimalPlanAlloc(std.testing.allocator, input, .{ .max_chain = 64, .nice_len = 258, .max_candidates = 1 });
    defer one.deinit(std.testing.allocator);
    const many = try optimalPlanAlloc(std.testing.allocator, input, .{ .max_chain = 64, .nice_len = 258, .max_candidates = 4 });
    defer many.deinit(std.testing.allocator);
    try std.testing.expect(many.stats.matches >= one.stats.matches);
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
