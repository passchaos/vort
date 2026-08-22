const std = @import("std");
const core = @import("core.zig");

pub const Error = core.Error;

pub const min_match_len: usize = 3;
pub const max_match_len: usize = 258;
pub const default_window_len: usize = 32 * 1024;
const hash_head_table_size: usize = 1 << 15;
const hash_head_init_words: usize = hash_head_table_size / 64;
const HashAnchor = enum { three, four };
// Below this size the full predecessor table is modest and avoids changing
// allocator reuse behavior for short one-shot streams. Large image-style
// payloads receive nearly all of the memory benefit from the bounded ring.
const min_hash_prev_ring_input_len: usize = 512 * 1024;
const fixed_distance_costs = blk: {
    @setEvalBranchQuota(1_000_000);
    break :blk fixedDistanceCostTable(default_window_len);
};

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

pub const OptimalScratch = struct {
    costs: std.ArrayList(usize) = .empty,
    steps: std.ArrayList(Token) = .empty,
    index: HashIndex = .{},
    tokens: std.ArrayList(Token) = .empty,

    pub fn deinit(self: *OptimalScratch, allocator: std.mem.Allocator) void {
        self.costs.deinit(allocator);
        self.steps.deinit(allocator);
        self.index.deinit(allocator);
        self.tokens.deinit(allocator);
        self.* = .{};
    }
};

pub const HashIndex = struct {
    head: std.ArrayList(isize) = .empty,
    prev: std.ArrayList(isize) = .empty,
    head_initialized: [hash_head_init_words]u64 = @splat(0),
    input_len: usize = 0,

    pub fn deinit(self: *HashIndex, allocator: std.mem.Allocator) void {
        self.head.deinit(allocator);
        self.prev.deinit(allocator);
        self.* = .{};
    }

    pub fn build(self: *HashIndex, allocator: std.mem.Allocator, input: []const u8) !void {
        try self.head.resize(allocator, hash_head_table_size);
        try self.prev.resize(allocator, input.len);
        @memset(&self.head_initialized, 0);
        self.input_len = input.len;
        for (0..input.len) |i| insertHashWithLayout(input, i, self.head.items, self.prev.items, false, true, &self.head_initialized, .three);
    }

    pub fn bestMatch(self: *const HashIndex, input: []const u8, pos: usize, options: GreedyOptions) Error!Token.Match {
        if (input.len != self.input_len or pos > input.len) return error.InvalidBlockPlan;
        if (pos + minMatch(options) > input.len) return .{ .length = 0, .distance = 0 };
        const max_len = @min(maxMatch(options), input.len - pos);
        var chain_i = self.prev.items[pos];
        var checked: usize = 0;
        var best = MatchCandidate{};
        while (chain_i >= 0 and checked < options.max_chain) : (checked += 1) {
            const candidate: usize = @intCast(chain_i);
            const distance = pos - candidate;
            if (distance == 0 or distance > options.window_len) break;
            const len = matchLength(input, candidate, pos, max_len);
            if (len >= minMatch(options) and len > best.length) {
                best = .{ .length = len, .distance = distance };
                if (len >= options.nice_len or len == max_len) break;
            }
            chain_i = self.prev.items[candidate];
        }
        return .{ .length = @intCast(best.length), .distance = @intCast(best.distance) };
    }
};

/// Production `.best` preset candidate budget for the ratio-oriented optimal
/// parser. The hard cap below is intentionally higher for experiments/custom
/// options, but the default stays at a measured middle ground: it recovers much
/// of the source/binary ratio left by the old 16-candidate search without
/// taking the larger encode-time cliff seen at the maximum cap.
pub const default_best_optimal_candidates = 256;

/// Hard upper bound for match candidates considered by the optimal parser.
/// Fast/default presets do not use this path, and `max_chain` still bounds
/// actual work; keeping the cap above the production preset lets advanced
/// callers spend more search budget on corpora where late same-hash candidates
/// yield a shorter dynamic Huffman stream.
pub const max_optimal_candidates = 512;

fn initTokenList(allocator: std.mem.Allocator, input_len: usize) !std.ArrayList(Token) {
    // Every input byte can become at most one token. A small eager reserve
    // removes the first few hot-path reallocations without over-allocating for
    // highly compressible blocks whose token stream is much smaller than the
    // source block.
    return std.ArrayList(Token).initCapacity(allocator, @min(input_len, 4096));
}

inline fn appendToken(
    tokens: *std.ArrayList(Token),
    allocator: std.mem.Allocator,
    token: Token,
) !void {
    // `ArrayList.append` is deliberately not inline and its call/capacity
    // handling showed up once per token in the fastest hash parser. Growth is
    // rare after the small initial reserve, so keep the common store in the
    // parser loop and retain the standard allocator path only at a boundary.
    if (tokens.items.len < tokens.capacity) {
        tokens.appendAssumeCapacity(token);
    } else {
        try tokens.append(allocator, token);
    }
}

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
    var tokens = try initTokenList(allocator, input.len);
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
    var tokens = try initTokenList(allocator, input.len);
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
    if (input.len <= 32 * 1024) return hashLazyGreedyPlanTinyAlloc(allocator, input, options);
    return hashLazyGreedyPlanAlloc(allocator, input, options);
}

pub fn hashGreedyPlanAllocWithDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: GreedyOptions) !GreedyPlan {
    const dict = activeDictionary(dictionary, options);
    if (dict.len == 0) return hashGreedyPlanAlloc(allocator, input, options);

    const table_size = 1 << 15;
    const head = try allocator.alloc(isize, table_size);
    defer allocator.free(head);
    @memset(head, -1);
    const total = dict.len + input.len;
    const prev = try allocator.alloc(isize, total);
    defer allocator.free(prev);
    seedDictionaryHashes(dict, input, head, prev);

    var tokens = try initTokenList(allocator, input.len);
    errdefer tokens.deinit(allocator);
    var stats = PlanStats{};

    var pos: usize = 0;
    while (pos < input.len) {
        const current = dict.len + pos;
        const best = findBestCombinedHashMatch(dict, input, current, options, head, prev);

        if (acceptMatch(input, pos, best.length, best.distance, options)) {
            try tokens.append(allocator, .{ .match = .{ .length = @intCast(best.length), .distance = @intCast(best.distance) } });
            stats.matches += 1;
            stats.matched_bytes += best.length;
            const end = @min(input.len, pos + best.length);
            insertCombinedHash(dict, input, current, head, prev);
            const tail_start = if (end > pos + 4) end - 4 else pos + 1;
            pos += 1;
            if (pos < tail_start) pos = tail_start;
            while (pos < end) : (pos += 1) insertCombinedHash(dict, input, dict.len + pos, head, prev);
        } else {
            try tokens.append(allocator, .{ .literal = input[pos] });
            stats.literals += 1;
            insertCombinedHash(dict, input, current, head, prev);
            pos += 1;
        }
    }
    return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
}

pub fn lazyGreedyPlanAllocWithDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: GreedyOptions) !GreedyPlan {
    const dict = activeDictionary(dictionary, options);
    if (dict.len == 0) return lazyGreedyPlanAlloc(allocator, input, options);

    const table_size = 1 << 15;
    const head = try allocator.alloc(isize, table_size);
    defer allocator.free(head);
    @memset(head, -1);
    const total = dict.len + input.len;
    const prev = try allocator.alloc(isize, total);
    defer allocator.free(prev);
    seedDictionaryHashes(dict, input, head, prev);

    var tokens = try initTokenList(allocator, input.len);
    errdefer tokens.deinit(allocator);
    var stats = PlanStats{};

    var pos: usize = 0;
    while (pos < input.len) {
        const current = dict.len + pos;
        const best = findBestCombinedHashMatch(dict, input, current, options, head, prev);
        if (!acceptMatch(input, pos, best.length, best.distance, options)) {
            try tokens.append(allocator, .{ .literal = input[pos] });
            stats.literals += 1;
            insertCombinedHash(dict, input, current, head, prev);
            pos += 1;
            continue;
        }

        var current_inserted = false;
        if (pos + 1 < input.len) {
            insertCombinedHash(dict, input, current, head, prev);
            current_inserted = true;
            const next = findBestCombinedHashMatch(dict, input, current + 1, options, head, prev);
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
        while (insert_pos < end) : (insert_pos += 1) insertCombinedHash(dict, input, dict.len + insert_pos, head, prev);
        pos += best.length;
    }

    return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
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
    if (unique > 48) return false;

    var trigrams: [256]bool = @splat(false);
    var trigram_count: usize = 0;
    if (sample_len >= 3) {
        const limit = sample_len - 2;
        var i: usize = 0;
        while (i < limit) : (i += 1) {
            const bucket: u8 = @truncate(hash3(input[i..][0..3]));
            if (!trigrams[bucket]) {
                trigrams[bucket] = true;
                trigram_count += 1;
                if (trigram_count > 96) return false;
            }
        }
    }
    // The backwards scanner wins on tiny and low-entropy inputs because it has
    // no table allocation/clear cost and quickly finds long repeated runs.
    // Byte diversity alone is a weak proxy: Markdown/source often has fewer
    // than 48 distinct bytes in the first KiB but hundreds of distinct 3-byte
    // anchors, so a blind backward scan burns time on non-candidates. Use a
    // small 256-bucket trigram sketch to keep RLE/repetitive text on the scan
    // path while routing natural text/source blocks to the hash-chain parser.
    return true;
}

fn scanLazyGreedyPlanAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    var tokens = try initTokenList(allocator, input.len);
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
    return hashLazyGreedyPlanWithTables(allocator, input, options, head, prev);
}

fn hashLazyGreedyPlanTinyAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    if (input.len > 32 * 1024) return hashLazyGreedyPlanAlloc(allocator, input, options);

    var head: [4096]isize = @splat(-1);
    var prev_stack: [32 * 1024]isize = undefined;
    return hashLazyGreedyPlanWithTables(allocator, input, options, &head, prev_stack[0..input.len]);
}

fn hashLazyGreedyPlanWithTables(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions, head: []isize, prev: []isize) !GreedyPlan {
    // `prev` is intentionally left uninitialized: every position reachable
    // through `head` is written by `insertHash` before it can be followed.
    // Avoiding a full-buffer clear removes one hot memory pass per block. The
    // stack-resident tiny path keeps the same invariant with a smaller head
    // table to avoid heap allocation and a full 32 Ki-slot clear on source/text
    // chunks below one deflate window.

    var tokens = try initTokenList(allocator, input.len);
    errdefer tokens.deinit(allocator);
    const stats = try hashLazyGreedyPlanWithTablesReuse(&tokens, allocator, input, options, head, prev);
    return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
}

pub fn hashLazyGreedyPlanTinyReuse(tokens: *std.ArrayList(Token), allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !PlanStats {
    if (input.len > 32 * 1024) return error.InvalidBlockPlan;
    tokens.clearRetainingCapacity();
    var head: [4096]isize = @splat(-1);
    var prev_stack: [32 * 1024]isize = undefined;
    return try hashLazyGreedyPlanWithTablesReuse(tokens, allocator, input, options, &head, prev_stack[0..input.len]);
}

fn hashLazyGreedyPlanWithTablesReuse(tokens: *std.ArrayList(Token), allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions, head: []isize, prev: []isize) !PlanStats {
    var stats = PlanStats{};

    var pos: usize = 0;
    while (pos < input.len) {
        const best = findBestHashMatch(input, pos, options, head, prev);
        if (!acceptMatch(input, pos, best.length, best.distance, options)) {
            try appendToken(tokens, allocator, .{ .literal = input[pos] });
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
                try appendToken(tokens, allocator, .{ .literal = input[pos] });
                stats.literals += 1;
                pos += 1;
                continue;
            }
        }

        try appendToken(tokens, allocator, .{ .match = .{ .length = @intCast(best.length), .distance = @intCast(best.distance) } });
        stats.matches += 1;
        stats.matched_bytes += best.length;
        var insert_pos = if (current_inserted) pos + 1 else pos;
        const end = @min(input.len, pos + best.length);
        while (insert_pos < end) : (insert_pos += 1) insertHash(input, insert_pos, head, prev);
        pos += best.length;
    }

    return stats;
}

pub fn optimalPlanAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    var scratch: OptimalScratch = .{};
    defer scratch.deinit(allocator);
    const stats = try optimalPlanReuse(&scratch, allocator, input, options);
    return .{ .tokens = try allocator.dupe(Token, scratch.tokens.items), .stats = stats };
}

pub fn optimalPlanReuse(scratch: *OptimalScratch, allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !PlanStats {
    const n = input.len;
    try scratch.costs.resize(allocator, n + 1);
    try scratch.steps.resize(allocator, n);
    try scratch.index.build(allocator, input);
    scratch.tokens.clearRetainingCapacity();
    const costs = scratch.costs.items;
    const steps = scratch.steps.items;

    // Build hash chain for fast match discovery.
    const prev = scratch.index.prev.items;
    // `prev` entries are written by the pre-population pass below before the
    // reverse dynamic-programming search reads any insertable position.

    // Pre-populate hash chain for all positions.
    costs[n] = 0;
    var rev_i: usize = n;
    const minimum = minMatch(options);
    const candidate_limit = normalizedMaxCandidates(options);
    const distance_costs = &fixed_distance_costs;

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
            // The optimal chain uses a three-byte anchor while Zstd requests
            // min_match=4. Reject the common fourth-byte mismatch before the
            // wider matchLength loop without dropping valid 4-byte matches.
            if (minimum >= 4 and input[candidate + 3] != input[rev_i + 3]) {
                chain_i = prev[candidate];
                continue;
            }

            const length = matchLength(input, candidate, rev_i, max_len);
            if (length >= minimum) {
                const distance_cost = distance_costs[distance];
                var len = length;
                while (len >= minimum) : (len -= 1) {
                    const cost = fixedLengthSymbolCost(len) + distance_cost + costs[rev_i + len];
                    if (cost < costs[rev_i]) {
                        costs[rev_i] = cost;
                        steps[rev_i] = .{ .match = .{ .length = @intCast(len), .distance = @intCast(distance) } };
                    }
                }
                candidates_seen += 1;
                if (length == max_len) break;
                if (length >= options.nice_len and candidates_seen >= candidate_limit) break;
                if (candidates_seen >= candidate_limit) break;
            }
            chain_i = prev[candidate];
        }
    }

    var stats = PlanStats{};
    var pos: usize = 0;
    while (pos < n) {
        const token = steps[pos];
        try appendToken(&scratch.tokens, allocator, token);
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
    return stats;
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

fn acceptsEveryHashMatch(options: GreedyOptions) bool {
    // This is a sufficient condition, not a heuristic. A hash candidate never
    // exceeds `window_len`, fixed distance cost is nondecreasing, and every
    // literal costs at least eight bits. If that lower bound pays the
    // worst-distance match plus the requested savings for every permitted
    // length, `acceptMatch` cannot reject any match returned by the parser.
    if (options.window_len == 0 or options.window_len > default_window_len) {
        return false;
    }
    const distance_cost = fixedDistanceSymbolCost(options.window_len);
    const minimum = minMatch(options);
    const maximum = maxMatch(options);
    var length = minimum;
    while (length <= maximum) : (length += 1) {
        const literal_min_cost = length * 8;
        const match_cost = fixedLengthSymbolCost(length) + distance_cost;
        if (match_cost > literal_min_cost) return false;
        if (options.min_savings_bits > literal_min_cost - match_cost) {
            return false;
        }
    }
    return true;
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
    if (length <= 10) return 7;
    if (length <= 18) return 8;
    if (length <= 34) return 9;
    if (length <= 66) return 10;
    if (length <= 130) return 11;
    if (length <= 257) return 12;
    return 8; // 258 is the fixed-Huffman code 285 with no extra bits.
}

fn fixedDistanceSymbolCost(distance: usize) usize {
    std.debug.assert(distance >= 1 and distance <= default_window_len);
    return 5 + fixedDistanceExtraBitsFast(distance);
}

fn fixedDistanceExtraBitsFast(distance: usize) usize {
    if (distance <= 4) return 0;
    return std.math.log2_int(usize, distance - 1) - 1;
}

fn fixedDistanceCostTable(window_len: usize) [default_window_len + 1]u8 {
    var table: [default_window_len + 1]u8 = @splat(0);
    const limit = @min(window_len, default_window_len);
    var distance: usize = 1;
    while (distance <= limit) : (distance += 1) {
        table[distance] = @intCast(fixedDistanceSymbolCost(distance));
    }
    return table;
}

test "compile-time fixed distance costs match scalar range" {
    try std.testing.expectEqual(@as(u8, 0), fixed_distance_costs[0]);
    for (1..default_window_len + 1) |distance| {
        try std.testing.expectEqual(@as(u8, @intCast(fixedDistanceSymbolCost(distance))), fixed_distance_costs[distance]);
    }
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
    return hashGreedyPlanAllocWithAnchor(allocator, input, options, .three);
}

fn hashGreedyPlanFourAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    if (minMatch(options) < 4) return error.InvalidMatch;
    return hashGreedyPlanAllocWithAnchor(allocator, input, options, .four);
}

/// Selects a four-byte hash anchor when every accepted match is at least four
/// bytes, otherwise preserves the historical three-byte parser. The wider
/// anchor changes the bounded candidate set rather than merely accelerating the
/// same token stream, so callers that require the old parsing policy should use
/// `hashGreedyPlanAlloc` directly.
pub fn hashGreedyPlanAutoAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    return if (minMatch(options) >= 4)
        hashGreedyPlanAllocWithAnchor(allocator, input, options, .four)
    else
        hashGreedyPlanAllocWithAnchor(allocator, input, options, .three);
}

fn hashGreedyPlanAllocWithAnchor(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    comptime anchor: HashAnchor,
) !GreedyPlan {
    const head = try allocator.alloc(isize, hash_head_table_size);
    defer allocator.free(head);
    var initialized: [hash_head_init_words]u64 = @splat(0);
    const prev_len = hashPrevTableLen(input.len, options.window_len);
    const ring = prev_len < input.len;
    const prev = try allocator.alloc(isize, prev_len);
    defer allocator.free(prev);
    if (ring) {
        // Keep the ring-specialized planner out of encodeZlibBestAlloc's
        // caller body. Inlining both predecessor layouts enlarged the function
        // enough to regress the unrelated stored fast path on PNG RGB rows.
        return @call(
            .never_inline,
            hashGreedyPlanWithTables,
            .{ allocator, input, options, head, prev, true, true, &initialized, anchor },
        );
    }
    return hashGreedyPlanWithTables(
        allocator,
        input,
        options,
        head,
        prev,
        false,
        true,
        &initialized,
        anchor,
    );
}

pub fn hashGreedyPlanTinyAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    return hashGreedyPlanTinyAllocWithAnchor(allocator, input, options, .three);
}

fn hashGreedyPlanFourTinyAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    if (minMatch(options) < 4) return error.InvalidMatch;
    return hashGreedyPlanTinyAllocWithAnchor(allocator, input, options, .four);
}

/// Stack-table counterpart to `hashGreedyPlanAutoAlloc`.
pub fn hashGreedyPlanAutoTinyAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    const anchor: HashAnchor = if (minMatch(options) >= 4) .four else .three;
    return switch (anchor) {
        .three => hashGreedyPlanTinyAllocWithAnchor(allocator, input, options, .three),
        .four => hashGreedyPlanTinyAllocWithAnchor(allocator, input, options, .four),
    };
}

/// Reusable-token counterpart to `hashGreedyPlanAutoTinyAlloc`. Existing
/// capacity is preserved and overwritten; callers own the ArrayList and can
/// reuse it across independent inputs without a token allocation per plan.
pub fn hashGreedyPlanAutoTinyReuse(tokens: *std.ArrayList(Token), allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !PlanStats {
    const anchor: HashAnchor = if (minMatch(options) >= 4) .four else .three;
    if (input.len > 32 * 1024) return error.InvalidBlockPlan;
    tokens.clearRetainingCapacity();
    var head: [4096]isize = @splat(-1);
    var prev_stack: [32 * 1024]isize = undefined;
    return switch (anchor) {
        .three => hashGreedyPlanWithTablesReuse(tokens, allocator, input, options, &head, prev_stack[0..input.len], .three),
        .four => hashGreedyPlanWithTablesReuse(tokens, allocator, input, options, &head, prev_stack[0..input.len], .four),
    };
}

fn hashGreedyPlanWithTablesReuse(
    tokens: *std.ArrayList(Token),
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    head: []isize,
    prev: []isize,
    comptime anchor: HashAnchor,
) !PlanStats {
    var stats = PlanStats{};
    const accept_all_matches = acceptsEveryHashMatch(options);
    var pos: usize = 0;
    while (pos < input.len) {
        const search = findBestHashMatchWithLayoutAndHash(input, pos, options, head, prev, false, false, {}, anchor);
        const best = search.best;
        const accepted = if (accept_all_matches) best.length != 0 else acceptMatch(input, pos, best.length, best.distance, options);
        if (accepted) {
            try appendToken(tokens, allocator, .{ .match = .{ .length = @intCast(best.length), .distance = @intCast(best.distance) } });
            stats.matches += 1;
            stats.matched_bytes += best.length;
            const end = @min(input.len, pos + best.length);
            insertKnownHashWithLayout(pos, search.hash.?, head, prev, false, false, {});
            const tail_start = if (end > pos + 4) end - 4 else pos + 1;
            pos += 1;
            if (pos < tail_start) pos = tail_start;
            while (pos < end) : (pos += 1) insertHashWithLayout(input, pos, head, prev, false, false, {}, anchor);
        } else {
            try appendToken(tokens, allocator, .{ .literal = input[pos] });
            stats.literals += 1;
            if (search.hash) |hash| insertKnownHashWithLayout(pos, hash, head, prev, false, false, {});
            pos += 1;
        }
    }
    return stats;
}

fn hashGreedyPlanTinyAllocWithAnchor(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    comptime anchor: HashAnchor,
) !GreedyPlan {
    if (input.len > 32 * 1024) return hashGreedyPlanAllocWithAnchor(allocator, input, options, anchor);

    var head: [4096]isize = @splat(-1);
    var prev_stack: [32 * 1024]isize = undefined;
    return hashGreedyPlanWithTables(
        allocator,
        input,
        options,
        &head,
        prev_stack[0..input.len],
        false,
        false,
        {},
        anchor,
    );
}

fn hashPrevTableLen(input_len: usize, window_len: usize) usize {
    // Power-of-two windows can address the live predecessor chain with one
    // mask. A position is queried before its slot is reused, so the entry
    // exactly `window_len` bytes behind remains visible; after insertion it is
    // too old for every subsequent query. Preserve the full table for custom
    // non-power-of-two windows rather than adding a modulo operation to the hot
    // chain walk.
    if (input_len >= min_hash_prev_ring_input_len and
        window_len != 0 and
        window_len <= default_window_len and
        input_len > window_len and
        std.math.isPowerOfTwo(window_len))
    {
        return window_len;
    }
    return input_len;
}

fn hashPrevIndex(position: usize, prev: []const isize, comptime ring: bool) usize {
    return if (ring) position & (prev.len - 1) else position;
}

fn HashHeadInit(comptime lazy_head: bool) type {
    // Keep this mode as an explicit comptime parameter on the hot parser
    // rather than wrapping entries/state in a generic object. Both designs are
    // semantically equivalent, but the wrapper increased register pressure and
    // regressed the measured RGB/RGBA adaptive paths by about 2.5%. The direct
    // form still shares one parser state machine and compiles the full-clear
    // reference path without any bitmap branches.
    return if (lazy_head) *[hash_head_init_words]u64 else void;
}

fn hashGreedyPlanWithTables(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    head: []isize,
    prev: []isize,
    comptime ring: bool,
    comptime lazy_head: bool,
    initialized: HashHeadInit(lazy_head),
    comptime anchor: HashAnchor,
) !GreedyPlan {
    // The heap-backed and stack-backed hash parsers share exactly the same
    // state machine. Keeping the loop in one place protects token/stat
    // accounting and hash seeding from drifting as fast-level heuristics evolve.
    // `prev` starts uninitialized by design: only positions previously inserted
    // into `head` are reachable through a hash chain, and `insertHash` writes the
    // corresponding `prev` slot before that position can be followed. The
    // production heap path uses a power-of-two ring bounded by the active
    // history window. A slot is overwritten only after its previous absolute
    // position is too old to be a valid match for any later lookup.

    var tokens = try initTokenList(allocator, input.len);
    errdefer tokens.deinit(allocator);
    var stats = PlanStats{};
    const accept_all_matches = acceptsEveryHashMatch(options);

    var pos: usize = 0;
    while (pos < input.len) {
        const search = findBestHashMatchWithLayoutAndHash(
            input,
            pos,
            options,
            head,
            prev,
            ring,
            lazy_head,
            initialized,
            anchor,
        );
        const best = search.best;

        const accepted = if (accept_all_matches)
            best.length != 0
        else
            acceptMatch(input, pos, best.length, best.distance, options);
        if (accepted) {
            try appendToken(&tokens, allocator, .{ .match = .{ .length = @intCast(best.length), .distance = @intCast(best.distance) } });
            stats.matches += 1;
            stats.matched_bytes += best.length;
            const end = @min(input.len, pos + best.length);
            insertKnownHashWithLayout(
                pos,
                search.hash.?,
                head,
                prev,
                ring,
                lazy_head,
                initialized,
            );
            // fdeflate-style fast parsers do not seed every byte inside a
            // consumed match. Keeping just the first and final few positions
            // preserves useful future anchors while avoiding long insertion
            // runs on repetitive data, which dominates fast/fastest levels.
            const tail_start = if (end > pos + 4) end - 4 else pos + 1;
            pos += 1;
            if (pos < tail_start) pos = tail_start;
            while (pos < end) : (pos += 1) {
                insertHashWithLayout(
                    input,
                    pos,
                    head,
                    prev,
                    ring,
                    lazy_head,
                    initialized,
                    anchor,
                );
            }
        } else {
            try appendToken(&tokens, allocator, .{ .literal = input[pos] });
            stats.literals += 1;
            if (search.hash) |hash| {
                insertKnownHashWithLayout(
                    pos,
                    hash,
                    head,
                    prev,
                    ring,
                    lazy_head,
                    initialized,
                );
            }
            pos += 1;
        }
    }
    return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
}

fn findBestHashMatch(input: []const u8, pos: usize, options: GreedyOptions, head: []isize, prev: []const isize) MatchCandidate {
    return findBestHashMatchWithLayout(
        input,
        pos,
        options,
        head,
        prev,
        false,
        false,
        {},
        .three,
    );
}

fn findBestHashMatchWithLayout(
    input: []const u8,
    pos: usize,
    options: GreedyOptions,
    head: []const isize,
    prev: []const isize,
    comptime ring: bool,
    comptime lazy_head: bool,
    initialized: HashHeadInit(lazy_head),
    comptime anchor: HashAnchor,
) MatchCandidate {
    return findBestHashMatchWithLayoutAndHash(
        input,
        pos,
        options,
        head,
        prev,
        ring,
        lazy_head,
        initialized,
        anchor,
    ).best;
}

fn findBestHashMatchWithLayoutAndHash(
    input: []const u8,
    pos: usize,
    options: GreedyOptions,
    head: []const isize,
    prev: []const isize,
    comptime ring: bool,
    comptime lazy_head: bool,
    initialized: HashHeadInit(lazy_head),
    comptime anchor: HashAnchor,
) HashMatchSearch {
    const hash = hashAtInput(input, pos, head.len, anchor) orelse return .{};
    const minimum = minMatch(options);
    if (pos + minimum > input.len) return .{ .hash = hash };

    var candidate_i = hashHeadGet(head, hash, lazy_head, initialized);
    var checked: usize = 0;
    var walked: usize = 0;
    const max_walks = maxHashChainWalks(options, minimum);
    const max_len = @min(maxMatch(options), input.len - pos);
    var best = MatchCandidate{};
    while (candidate_i >= 0 and checked < options.max_chain and walked < max_walks) : (walked += 1) {
        const candidate: usize = @intCast(candidate_i);
        const distance = pos - candidate;
        if (distance == 0 or distance > options.window_len) break;
        if (best.length == max_len) break;
        const required_prefix = @max(best.length, minimum - 1);
        if (input[candidate + required_prefix] != input[pos + required_prefix]) {
            candidate_i = prev[hashPrevIndex(candidate, prev, ring)];
            continue;
        }
        checked += 1;
        const len = matchLength(input, candidate, pos, max_len);
        if (len >= minimum and len > best.length) {
            best = .{ .length = len, .distance = distance };
            if (len >= options.nice_len) break;
        }
        candidate_i = prev[hashPrevIndex(candidate, prev, ring)];
    }
    return .{ .best = best, .hash = hash };
}

fn maxHashChainWalks(options: GreedyOptions, minimum: usize) usize {
    if (minimum <= min_match_len or options.max_chain > 8) return options.max_chain;
    return options.max_chain * 4;
}

fn findBestCombinedHashMatch(dict: []const u8, input: []const u8, current: usize, options: GreedyOptions, head: []const isize, prev: []const isize) MatchCandidate {
    const minimum = minMatch(options);
    const dict_len = dict.len;
    const pos = current - dict_len;
    if (pos + minimum > input.len) return .{};

    const h = hash3At(dict, input, current) & (head.len - 1);
    var candidate_i = head[h];
    var checked: usize = 0;
    var walked: usize = 0;
    const max_walks = maxHashChainWalks(options, minimum);
    const max_len = @min(maxMatch(options), input.len - pos);
    var best = MatchCandidate{};
    while (candidate_i >= 0 and checked < options.max_chain and walked < max_walks) : (walked += 1) {
        const candidate: usize = @intCast(candidate_i);
        const distance = current - candidate;
        if (distance == 0 or distance > options.window_len) break;
        if (best.length == max_len) break;
        const required_prefix = @max(best.length, minimum - 1);
        if (byteAt(dict, input, candidate + required_prefix) != input[pos + required_prefix]) {
            candidate_i = prev[candidate];
            continue;
        }
        checked += 1;
        const len = combinedMatchLength(dict, input, candidate, current, max_len);
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
            return len + @ctz(left ^ right) / 8;
        }
    }
    while (len < max_len and input[a + len] == input[b + len]) len += 1;
    return len;
}

fn combinedMatchLength(dict: []const u8, input: []const u8, candidate: usize, current: usize, max_len: usize) usize {
    const dict_len = dict.len;
    const input_pos = current - dict_len;
    if (candidate >= dict_len) return matchLength(input, candidate - dict_len, input_pos, max_len);

    var len: usize = 0;
    const dict_part_len = @min(max_len, dict_len - candidate);
    while (len + 8 <= dict_part_len) : (len += 8) {
        const left = std.mem.readInt(u64, dict[candidate + len ..][0..8], .little);
        const right = std.mem.readInt(u64, input[input_pos + len ..][0..8], .little);
        if (left != right) return len + @ctz(left ^ right) / 8;
    }
    while (len < dict_part_len and dict[candidate + len] == input[input_pos + len]) len += 1;
    if (len < dict_part_len or len == max_len) return len;

    const input_candidate = candidate + len - dict_len;
    return len + matchLength(input, input_candidate, input_pos + len, max_len - len);
}

test "combined dictionary/input match length uses word and tail paths" {
    const dict = "abcdefghijklmnop";
    const input = "abcdefghijklmnopABC";
    try std.testing.expectEqual(@as(usize, 16), combinedMatchLength(dict, input, 0, dict.len, 19));

    const crossing_dict = "prefix-abc";
    const crossing_input = "abcabcXYZ";
    try std.testing.expectEqual(@as(usize, 6), combinedMatchLength(crossing_dict, crossing_input, 7, crossing_dict.len, 6));

    const input_only = "zzzzabcabc";
    try std.testing.expectEqual(@as(usize, 3), combinedMatchLength(dict, input_only, dict.len + 4, dict.len + 7, 3));
}

test "lazy parser scan preference separates repetitive from source-like blocks" {
    try std.testing.expect(preferScanLazy("abcabcabcabc" ** 128));
    try std.testing.expect(preferScanLazy("0123456789abcdef" ** 128));

    const source_like =
        \\const std = @import("std");
        \\pub fn main() !void {
        \\    var checksum: usize = 0;
        \\    while (checksum < 1024) : (checksum += 1) {
        \\        checksum = checksum *% 33 + 17;
        \\    }
        \\}
        \\
    ** 8;
    try std.testing.expect(!preferScanLazy(source_like));
}

test "tiny lazy hash planner round trips source-like blocks" {
    const source_like =
        \\const std = @import("std");
        \\pub fn update(value: usize) usize {
        \\    var hash = value;
        \\    inline for (0..16) |i| {
        \\        hash = (hash ^ i) *% 0x9e3779b1;
        \\    }
        \\    return hash;
        \\}
        \\
    ** 8;
    const plan = try hashLazyGreedyPlanTinyAlloc(std.testing.allocator, source_like, .{});
    defer plan.deinit(std.testing.allocator);
    try std.testing.expect(plan.stats.tokenCount() <= source_like.len);
    const replayed = try replayAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, source_like, replayed);
}

fn insertHash(input: []const u8, pos: usize, head: []isize, prev: []isize) void {
    insertHashWithLayout(input, pos, head, prev, false, false, {}, .three);
}

fn hashHeadGet(
    head: []const isize,
    hash: usize,
    comptime lazy_head: bool,
    initialized: HashHeadInit(lazy_head),
) isize {
    if (lazy_head) {
        const mask = @as(u64, 1) << @intCast(hash & 63);
        if (initialized[hash / 64] & mask == 0) return -1;
    }
    return head[hash];
}

fn insertHashWithLayout(
    input: []const u8,
    pos: usize,
    head: []isize,
    prev: []isize,
    comptime ring: bool,
    comptime lazy_head: bool,
    initialized: HashHeadInit(lazy_head),
    comptime anchor: HashAnchor,
) void {
    const h = hashAtInput(input, pos, head.len, anchor) orelse return;
    insertKnownHashWithLayout(
        pos,
        h,
        head,
        prev,
        ring,
        lazy_head,
        initialized,
    );
}

fn insertKnownHashWithLayout(
    pos: usize,
    h: usize,
    head: []isize,
    prev: []isize,
    comptime ring: bool,
    comptime lazy_head: bool,
    initialized: HashHeadInit(lazy_head),
) void {
    if (lazy_head) {
        const mask = @as(u64, 1) << @intCast(h & 63);
        const word = &initialized[h / 64];
        if (word.* & mask == 0) {
            word.* |= mask;
            prev[hashPrevIndex(pos, prev, ring)] = -1;
            head[h] = @intCast(pos);
            return;
        }
    }
    prev[hashPrevIndex(pos, prev, ring)] = head[h];
    head[h] = @intCast(pos);
}

fn hashAtInput(
    input: []const u8,
    pos: usize,
    head_len: usize,
    comptime anchor: HashAnchor,
) ?usize {
    return switch (anchor) {
        .three => {
            if (pos + 3 > input.len) return null;
            return hash3(input[pos..][0..3]) & (head_len - 1);
        },
        .four => {
            if (pos + 4 > input.len) return null;
            const word = std.mem.readInt(u32, input[pos..][0..4], .little);
            return ((word *% 2654435761) >> 17) & (head_len - 1);
        },
    };
}

fn seedDictionaryHashes(dict: []const u8, input: []const u8, head: []isize, prev: []isize) void {
    var pos: usize = 0;
    while (pos + min_match_len <= dict.len) : (pos += 1) insertCombinedHash(dict, input, pos, head, prev);
}

fn insertCombinedHash(dict: []const u8, input: []const u8, pos: usize, head: []isize, prev: []isize) void {
    if (pos + min_match_len > dict.len + input.len) return;
    const h = hash3At(dict, input, pos) & (head.len - 1);
    prev[pos] = head[h];
    head[h] = @intCast(pos);
}

fn hash3At(dict: []const u8, input: []const u8, pos: usize) usize {
    const bytes = [3]u8{
        byteAt(dict, input, pos),
        byteAt(dict, input, pos + 1),
        byteAt(dict, input, pos + 2),
    };
    return hash3(&bytes);
}

fn byteAt(dict: []const u8, input: []const u8, pos: usize) u8 {
    return if (pos < dict.len) dict[pos] else input[pos - dict.len];
}

fn activeDictionary(dictionary: []const u8, options: GreedyOptions) []const u8 {
    const max_len = @min(options.window_len, default_window_len);
    return dictionary[dictionary.len - @min(dictionary.len, max_len) ..];
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

const HashMatchSearch = struct {
    // LLVM scalarizes this aggregate more efficiently than computing an
    // optional hash in the caller and passing it back into a separate matcher.
    // A fixed-core head-to-head measured the seemingly simpler caller-owned
    // form at 0.982x adaptive, so keep lookup result and insertion bucket
    // coupled at this hot code-generation boundary.
    best: MatchCandidate = .{},
    hash: ?usize = null,
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
        const length = matchLength(input, candidate, pos, max_len);
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

test "reusable optimal parser preserves tokens and capacities" {
    const input = "abcabcXabcabcYabcabcZabcabcX" ** 8;
    const options = GreedyOptions{ .window_len = input.len, .max_chain = 64, .nice_len = 64, .max_candidates = 8, .min_match = 4 };
    const reference = try optimalPlanAlloc(std.testing.allocator, input, options);
    defer reference.deinit(std.testing.allocator);
    var scratch: OptimalScratch = .{};
    defer scratch.deinit(std.testing.allocator);
    const stats = try optimalPlanReuse(&scratch, std.testing.allocator, input, options);
    try expectEqualTokenSlices(reference.tokens, scratch.tokens.items);
    try std.testing.expectEqual(reference.stats, stats);
    const capacities = .{ scratch.costs.capacity, scratch.steps.capacity, scratch.index.head.capacity, scratch.index.prev.capacity, scratch.tokens.capacity };
    _ = try optimalPlanReuse(&scratch, std.testing.allocator, input, options);
    try std.testing.expectEqual(capacities, .{ scratch.costs.capacity, scratch.steps.capacity, scratch.index.head.capacity, scratch.index.prev.capacity, scratch.tokens.capacity });
}

test "optimal fourth-byte rejection preserves exact four-byte matches" {
    const input = "abcdXabcdYabcZ";
    const plan = try optimalPlanAlloc(std.testing.allocator, input, .{ .min_match = 4, .max_match = 32, .max_chain = 64, .max_candidates = 8 });
    defer plan.deinit(std.testing.allocator);
    var saw_exact_four = false;
    for (plan.tokens) |token| switch (token) {
        .match => |match| saw_exact_four = saw_exact_four or match.length == 4,
        else => {},
    };
    try std.testing.expect(saw_exact_four);
    const replayed = try replayAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
}

test "reusable hash index exposes deterministic position matches" {
    const input = "prefix-abcdefghijklmnop-middle-abcdefghijklmnop-tail";
    var index: HashIndex = .{};
    defer index.deinit(std.testing.allocator);
    try index.build(std.testing.allocator, input);
    const second = std.mem.indexOfPos(u8, input, 8, "abcdefghijklmnop") orelse return error.InvalidMatch;
    const match = try index.bestMatch(input, second, .{ .window_len = input.len, .max_chain = 64, .nice_len = 258, .min_match = 4 });
    try std.testing.expectEqual(@as(u16, 17), match.length);
    try std.testing.expectEqual(@as(u16, @intCast(second - "prefix-".len)), match.distance);
    try std.testing.expectError(error.InvalidBlockPlan, index.bestMatch(input[0 .. input.len - 1], second, .{}));
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

test "best optimal parser budget leaves room for custom deep searches" {
    try std.testing.expect(default_best_optimal_candidates > 16);
    try std.testing.expect(default_best_optimal_candidates <= max_optimal_candidates);

    const input = "abcd" ** 4096;
    const shallow = try optimalPlanAlloc(std.testing.allocator, input, .{ .max_chain = 512, .nice_len = 128, .max_candidates = default_best_optimal_candidates });
    defer shallow.deinit(std.testing.allocator);
    const deep = try optimalPlanAlloc(std.testing.allocator, input, .{ .max_chain = 512, .nice_len = 128, .max_candidates = max_optimal_candidates });
    defer deep.deinit(std.testing.allocator);

    // The custom deep cap may find different equivalent parses, but it must
    // remain bounded and valid relative to the production `.best` preset.
    try expectPlanStatsConsistent(shallow, input.len);
    try expectPlanStatsConsistent(deep, input.len);
    try std.testing.expect(deep.stats.tokenCount() <= shallow.stats.tokenCount() + 2);
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

test "hash planner skips non-viable prefixes before spending match budget" {
    const input = "abcdabceabcd";
    const options: GreedyOptions = .{
        .max_chain = 1,
        .nice_len = 16,
        .min_match = 4,
        .max_match = 16,
        .min_savings_bits = 0,
    };

    const plan = try hashGreedyPlanAlloc(std.testing.allocator, input, options);
    defer plan.deinit(std.testing.allocator);
    const replayed = try replayAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);

    var saw_deeper_match = false;
    for (plan.tokens) |token| switch (token) {
        .match => |m| {
            if (m.length >= 4 and m.distance == 8) saw_deeper_match = true;
        },
        else => {},
    };
    try std.testing.expect(saw_deeper_match);
}

test "tiny hash greedy planner round trips small repeated data" {
    const input = "abcabcabcabc" ** 16;
    const plan = try hashGreedyPlanTinyAlloc(std.testing.allocator, input, .{ .window_len = 8 * 1024, .max_chain = 4, .nice_len = 8, .max_candidates = 1, .min_match = 4, .max_match = 64, .min_savings_bits = 8 });
    defer plan.deinit(std.testing.allocator);
    try std.testing.expect(plan.stats.matches > 0);
    const replayed = try replayAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
}

test "automatic hash anchor preserves three-byte match configurations" {
    const input = "abcXabcYabcZ";
    const options = GreedyOptions{
        .window_len = 8 * 1024,
        .max_chain = 8,
        .nice_len = 16,
        .min_match = 3,
        .max_match = 16,
        .min_savings_bits = 0,
    };
    const reference = try hashGreedyPlanAlloc(std.testing.allocator, input, options);
    defer reference.deinit(std.testing.allocator);
    const automatic = try hashGreedyPlanAutoAlloc(std.testing.allocator, input, options);
    defer automatic.deinit(std.testing.allocator);
    try expectEqualTokenSlices(reference.tokens, automatic.tokens);
    try std.testing.expectEqual(reference.stats, automatic.stats);
    try std.testing.expectError(
        error.InvalidMatch,
        hashGreedyPlanFourAlloc(std.testing.allocator, input, options),
    );
}

test "reusable tiny hash planner preserves tokens and capacity" {
    const input = "abcabcXabcabcXabcabcX";
    const options = GreedyOptions{ .window_len = input.len, .max_chain = 64, .nice_len = 64, .max_candidates = 8 };
    const reference = try hashGreedyPlanAutoTinyAlloc(std.testing.allocator, input, options);
    defer reference.deinit(std.testing.allocator);
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(std.testing.allocator);
    const first_stats = try hashGreedyPlanAutoTinyReuse(&tokens, std.testing.allocator, input, options);
    try expectEqualTokenSlices(reference.tokens, tokens.items);
    try std.testing.expectEqual(reference.stats, first_stats);
    const capacity = tokens.capacity;
    _ = try hashGreedyPlanAutoTinyReuse(&tokens, std.testing.allocator, input, options);
    try std.testing.expectEqual(capacity, tokens.capacity);
}

test "reusable tiny lazy hash planner preserves tokens and capacity" {
    const input = "abcabcXabcabcYabcabcZabcabcX";
    const options = GreedyOptions{ .window_len = input.len, .max_chain = 64, .nice_len = 64, .max_candidates = 8, .lazy_min_gain = 1 };
    const reference = try hashLazyGreedyPlanTinyAlloc(std.testing.allocator, input, options);
    defer reference.deinit(std.testing.allocator);
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(std.testing.allocator);
    const first_stats = try hashLazyGreedyPlanTinyReuse(&tokens, std.testing.allocator, input, options);
    try expectEqualTokenSlices(reference.tokens, tokens.items);
    try std.testing.expectEqual(reference.stats, first_stats);
    const capacity = tokens.capacity;
    _ = try hashLazyGreedyPlanTinyReuse(&tokens, std.testing.allocator, input, options);
    try std.testing.expectEqual(capacity, tokens.capacity);
}

test "automatic hash anchor selects four-byte planner and round trips" {
    const input = ("abcdXabcdYabcdZ" ** 4096);
    const options = GreedyOptions{
        .window_len = 16 * 1024,
        .max_chain = 6,
        .nice_len = 16,
        .min_match = 4,
        .max_match = 96,
        .min_savings_bits = 6,
    };
    const explicit = try hashGreedyPlanFourAlloc(
        std.testing.allocator,
        input,
        options,
    );
    defer explicit.deinit(std.testing.allocator);
    const automatic = try hashGreedyPlanAutoAlloc(
        std.testing.allocator,
        input,
        options,
    );
    defer automatic.deinit(std.testing.allocator);
    try expectEqualTokenSlices(explicit.tokens, automatic.tokens);
    try std.testing.expectEqual(explicit.stats, automatic.stats);

    const replayed = try replayAlloc(std.testing.allocator, automatic.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
}

test "hash greedy table variants share token and stats accounting" {
    const input = "abcabcabcabc xyz xyz xyz aaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ** 4;
    const options: GreedyOptions = .{ .window_len = 8 * 1024, .max_chain = 32, .nice_len = 16, .max_candidates = 2, .min_match = 4, .max_match = 128, .min_savings_bits = 4 };

    const heap = try hashGreedyPlanAlloc(std.testing.allocator, input, options);
    defer heap.deinit(std.testing.allocator);
    try expectPlanStatsConsistent(heap, input.len);

    var heap_head: [1 << 15]isize = @splat(-1);
    var heap_prev: [input.len]isize = undefined;
    const heap_direct = try hashGreedyPlanWithTables(
        std.testing.allocator,
        input,
        options,
        &heap_head,
        &heap_prev,
        false,
        false,
        {},
        .three,
    );
    defer heap_direct.deinit(std.testing.allocator);
    try expectEqualTokenSlices(heap.tokens, heap_direct.tokens);
    try std.testing.expectEqual(heap.stats, heap_direct.stats);
    try expectPlanStatsConsistent(heap_direct, input.len);

    const tiny = try hashGreedyPlanTinyAlloc(std.testing.allocator, input, options);
    defer tiny.deinit(std.testing.allocator);
    try expectPlanStatsConsistent(tiny, input.len);

    var tiny_head: [4096]isize = @splat(-1);
    var tiny_prev: [input.len]isize = undefined;
    const tiny_direct = try hashGreedyPlanWithTables(
        std.testing.allocator,
        input,
        options,
        &tiny_head,
        &tiny_prev,
        false,
        false,
        {},
        .three,
    );
    defer tiny_direct.deinit(std.testing.allocator);
    try expectEqualTokenSlices(tiny.tokens, tiny_direct.tokens);
    try std.testing.expectEqual(tiny.stats, tiny_direct.stats);
    try expectPlanStatsConsistent(tiny_direct, input.len);
}

test "hash greedy predecessor ring matches full-table reference" {
    const windows = [_]usize{ 1, 8, 1024, 4096, 16 * 1024 };
    for (windows) |window_len| {
        const input_len = min_hash_prev_ring_input_len + window_len * 2 + 257;
        const input = try std.testing.allocator.alloc(u8, input_len);
        defer std.testing.allocator.free(input);
        for (input, 0..) |*byte, i| {
            // Mix short repeats, long-distance anchors, and hash collisions
            // while crossing each ring slot at least three times.
            byte.* = @truncate((i * 37 + (i / 7) * 13 + (i % 19) * 5) ^ (i >> 3));
            if (i >= window_len and i % 11 < 7) byte.* = input[i - window_len];
        }

        const options: GreedyOptions = .{
            .window_len = window_len,
            .max_chain = 32,
            .nice_len = 24,
            .max_candidates = 2,
            .min_match = 4,
            .max_match = 96,
            .min_savings_bits = 4,
        };

        var reference_head: [1 << 15]isize = @splat(-1);
        const reference_prev = try std.testing.allocator.alloc(isize, input.len);
        defer std.testing.allocator.free(reference_prev);
        const reference = try hashGreedyPlanWithTables(
            std.testing.allocator,
            input,
            options,
            &reference_head,
            reference_prev,
            false,
            false,
            {},
            .three,
        );
        defer reference.deinit(std.testing.allocator);

        const ring_len = hashPrevTableLen(input.len, window_len);
        try std.testing.expectEqual(window_len, ring_len);
        const ring = try hashGreedyPlanAlloc(std.testing.allocator, input, options);
        defer ring.deinit(std.testing.allocator);

        try expectEqualTokenSlices(reference.tokens, ring.tokens);
        try std.testing.expectEqual(reference.stats, ring.stats);
    }

    try std.testing.expectEqual(
        @as(usize, 70_000),
        hashPrevTableLen(70_000, 12_345),
    );
    try std.testing.expectEqual(
        @as(usize, 4096),
        hashPrevTableLen(4096, 16 * 1024),
    );
    try std.testing.expectEqual(
        min_hash_prev_ring_input_len - 1,
        hashPrevTableLen(min_hash_prev_ring_input_len - 1, 16 * 1024),
    );
    try std.testing.expectEqual(
        @as(usize, 70_000),
        hashPrevTableLen(70_000, 64 * 1024),
    );
}

fn expectPlanStatsConsistent(plan: GreedyPlan, input_len: usize) !void {
    var literals: usize = 0;
    var matches: usize = 0;
    var matched_bytes: usize = 0;
    for (plan.tokens) |token| switch (token) {
        .literal => literals += 1,
        .match => |m| {
            matches += 1;
            matched_bytes += m.length;
        },
    };
    try std.testing.expectEqual(literals, plan.stats.literals);
    try std.testing.expectEqual(matches, plan.stats.matches);
    try std.testing.expectEqual(matched_bytes, plan.stats.matched_bytes);
    try std.testing.expectEqual(plan.tokens.len, plan.stats.tokenCount());
    try std.testing.expectEqual(input_len, literals + matched_bytes);
}

fn expectEqualTokenSlices(expected: []const Token, actual: []const Token) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |lhs, rhs| switch (lhs) {
        .literal => |byte| try std.testing.expectEqual(byte, switch (rhs) {
            .literal => |rhs_byte| rhs_byte,
            .match => return error.TestExpectedEqual,
        }),
        .match => |m| {
            const rhs_match = switch (rhs) {
                .literal => return error.TestExpectedEqual,
                .match => |rhs_m| rhs_m,
            };
            try std.testing.expectEqual(m.length, rhs_match.length);
            try std.testing.expectEqual(m.distance, rhs_match.distance);
        },
    };
}

test "dictionary-backed hash and lazy planners can emit preset-history matches" {
    const dictionary = "hello ";
    const input = "hello hello hello";
    const options: GreedyOptions = .{ .min_savings_bits = 0, .nice_len = 258 };

    const hash_plan = try hashGreedyPlanAllocWithDictionary(std.testing.allocator, input, dictionary, options);
    defer hash_plan.deinit(std.testing.allocator);
    const lazy_plan = try lazyGreedyPlanAllocWithDictionary(std.testing.allocator, input, dictionary, options);
    defer lazy_plan.deinit(std.testing.allocator);

    for ([_]GreedyPlan{ hash_plan, lazy_plan }) |plan| {
        try std.testing.expect(plan.stats.matches > 0);
        switch (plan.tokens[0]) {
            .match => |m| {
                try std.testing.expect(m.distance <= dictionary.len);
                try std.testing.expect(m.length >= dictionary.len);
            },
            else => return error.TestExpectedEqual,
        }
    }
}

test "dictionary hash planner skips non-viable prefix collisions" {
    const dictionary = "abcdabce";
    const input = "abcd";
    const options: GreedyOptions = .{
        .max_chain = 1,
        .nice_len = 16,
        .min_match = 4,
        .max_match = 16,
        .min_savings_bits = 0,
    };

    const plan = try hashGreedyPlanAllocWithDictionary(std.testing.allocator, input, dictionary, options);
    defer plan.deinit(std.testing.allocator);
    try expectPlanStatsConsistent(plan, input.len);
    try std.testing.expectEqual(@as(usize, 1), plan.tokens.len);
    switch (plan.tokens[0]) {
        .match => |m| {
            try std.testing.expectEqual(@as(u16, 4), m.length);
            try std.testing.expectEqual(@as(u16, 8), m.distance);
        },
        else => return error.TestExpectedEqual,
    }
}

test "matchLength compares word chunks and tails" {
    const input = "abcdefghijklmnopABCabcdefghijklmnopXYZ";
    try std.testing.expectEqual(@as(usize, 16), matchLength(input, 0, 19, 16));
    try std.testing.expectEqual(@as(usize, 3), matchLength(input, 0, 19, 3));
}

test "hash search returns the insertion bucket" {
    const input = "abcabcxyz";
    var head: [4096]isize = @splat(-1);
    var prev: [input.len]isize = undefined;
    for (0..input.len) |pos| {
        const search = findBestHashMatchWithLayoutAndHash(
            input,
            pos,
            .{ .min_match = 4 },
            &head,
            &prev,
            false,
            false,
            {},
            .three,
        );
        const expected = if (pos + min_match_len <= input.len)
            hash3(input[pos..][0..3]) & (head.len - 1)
        else
            null;
        try std.testing.expectEqual(expected, search.hash);
    }
}

test "hash match fast acceptance is a sufficient condition" {
    const fastest = GreedyOptions{
        .window_len = 16 * 1024,
        .max_chain = 6,
        .nice_len = 16,
        .max_candidates = 1,
        .lazy_min_gain = 3,
        .min_match = 4,
        .max_match = 96,
        .min_savings_bits = 6,
    };
    try std.testing.expect(acceptsEveryHashMatch(fastest));

    // Use the cheapest possible literals so this exhaustive check exercises
    // exactly the lower bound used by `acceptsEveryHashMatch`.
    const input: [max_match_len]u8 = @splat(0);
    var length = minMatch(fastest);
    while (length <= maxMatch(fastest)) : (length += 1) {
        var distance: usize = 1;
        while (distance <= fastest.window_len) : (distance += 1) {
            try std.testing.expect(
                acceptMatch(&input, 0, length, distance, fastest),
            );
        }
    }

    var short = fastest;
    short.min_match = 3;
    try std.testing.expect(!acceptsEveryHashMatch(short));
    var expensive = fastest;
    expensive.min_savings_bits = 9;
    try std.testing.expect(!acceptsEveryHashMatch(expensive));
    var oversized_window = fastest;
    oversized_window.window_len = default_window_len + 1;
    try std.testing.expect(!acceptsEveryHashMatch(oversized_window));
}
