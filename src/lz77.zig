const std = @import("std");
const core = @import("core.zig");

pub const Error = core.Error;

pub const min_match_len: usize = 3;
pub const max_match_len: usize = 258;
pub const default_window_len: usize = 32 * 1024;
pub const max_window_len: usize = std.math.maxInt(u16);
const hash_head_table_size: usize = 1 << 15;
const hash_head_init_words: usize = hash_head_table_size / 64;
const tiny_hash_head_table_size: usize = 4096;
const tiny_hash_head_init_words: usize = tiny_hash_head_table_size / 64;
const packed_optimal_length_choices = @bitSizeOf(usize) >= 64;
const HashAnchor = enum { three, four };
// Keep inputs through 64 KiB on the full predecessor table so common binary
// and image blocks retain their established allocation/cache behavior. Larger
// one-shot inputs can bound the table to the active power-of-two history
// window without changing any reachable match.
const min_hash_prev_ring_input_len: usize = 64 * 1024 + 1;
const fixed_distance_costs = blk: {
    @setEvalBranchQuota(1_000_000);
    break :blk fixedDistanceCostTable(default_window_len);
};

pub inline fn fixedDistanceCost(distance: usize) usize {
    std.debug.assert(distance > 0 and distance <= default_window_len);
    return fixed_distance_costs[distance];
}

pub inline fn fixedLengthCost(length: usize) usize {
    std.debug.assert(length >= min_match_len and length <= max_match_len);
    return fixed_length_costs[length];
}

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

pub const OptimalSearchProfile = struct {
    pub const prefix_mismatch_bucket_count = 4;
    pub const bound_length_bucket_count = 6;
    pub const distance_cost_bucket_count = 15;
    pub const bound_slack_bucket_count = 9;
    pub const length_extension_bucket_count = 9;

    input_bytes: usize = 0,
    index_bytes: usize = 0,
    positions: usize = 0,
    chain_nodes: usize = 0,
    prefix_rejections: usize = 0,
    prefix_mismatch_histogram: [prefix_mismatch_bucket_count]usize = @splat(0),
    bound_rejections: usize = 0,
    bound_length_histogram: [bound_length_bucket_count]usize = @splat(0),
    bound_distance_cost_histogram: [distance_cost_bucket_count]usize = @splat(0),
    bound_slack_histogram: [bound_slack_bucket_count]usize = @splat(0),
    match_length_calls: usize = 0,
    valid_match_candidates: usize = 0,
    length_choices_built: usize = 0,
    length_extension_histogram: [length_extension_bucket_count]usize = @splat(0),
    candidate_budget_stops: usize = 0,
    index_ns: u64 = 0,
    search_ns: u64 = 0,
    reconstruct_ns: u64 = 0,
    total_ns: u64 = 0,

    pub fn add(self: *OptimalSearchProfile, other: OptimalSearchProfile) void {
        inline for (.{
            "input_bytes",
            "index_bytes",
            "positions",
            "chain_nodes",
            "prefix_rejections",
            "bound_rejections",
            "match_length_calls",
            "valid_match_candidates",
            "length_choices_built",
            "candidate_budget_stops",
            "index_ns",
            "search_ns",
            "reconstruct_ns",
            "total_ns",
        }) |field| @field(self, field) += @field(other, field);
        for (&self.prefix_mismatch_histogram, other.prefix_mismatch_histogram) |*total, count| total.* += count;
        for (&self.bound_length_histogram, other.bound_length_histogram) |*total, count| total.* += count;
        for (&self.bound_distance_cost_histogram, other.bound_distance_cost_histogram) |*total, count| total.* += count;
        for (&self.bound_slack_histogram, other.bound_slack_histogram) |*total, count| total.* += count;
        for (&self.length_extension_histogram, other.length_extension_histogram) |*total, count| total.* += count;
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
    /// Extra model cost for introducing a new recent distance in parsers that
    /// track repeat offsets. Generic LZ77 callers retain the historical zero.
    new_distance_penalty_bits: u8 = 0,
};

pub const GreedyPlan = struct {
    tokens: []Token,
    stats: PlanStats,

    pub fn deinit(self: GreedyPlan, allocator: std.mem.Allocator) void {
        allocator.free(self.tokens);
    }
};

pub const TinyGreedyScratch = struct {
    // Only positions with a complete 3-byte hash anchor are stored. At the
    // 32 KiB input limit the largest stored position is 32765, so signed 16-bit
    // entries preserve the `-1` sentinel and every reachable predecessor.
    head: [tiny_hash_head_table_size]i16 = undefined,
    head_initialized: [tiny_hash_head_init_words]u64 = @splat(0),
    prev: std.ArrayList(i16) = .empty,

    pub fn retainedCapacity(self: *const TinyGreedyScratch) usize {
        return self.prev.capacity * @sizeOf(i16);
    }

    pub fn deinit(self: *TinyGreedyScratch, allocator: std.mem.Allocator) void {
        self.prev.deinit(allocator);
        self.* = .{};
    }
};

pub const DictionaryGreedyScratch = struct {
    head: std.ArrayList(i32) = .empty,
    prev: std.ArrayList(i32) = .empty,
    head_initialized: [hash_head_init_words]u64 = @splat(0),

    pub fn retainedCapacity(self: *const DictionaryGreedyScratch) usize {
        return (self.head.capacity + self.prev.capacity) * @sizeOf(i32) + @sizeOf(@FieldType(DictionaryGreedyScratch, "head_initialized"));
    }

    pub fn deinit(self: *DictionaryGreedyScratch, allocator: std.mem.Allocator) void {
        self.head.deinit(allocator);
        self.prev.deinit(allocator);
        self.* = .{};
    }
};

/// Persistent hash-chain state for callers that commit an input stream in
/// order while retaining at least `max_match_len` bytes of lookahead. Absolute
/// positions preserve the same insertion/search order as `hashGreedyPlanAlloc`;
/// the predecessor ring is safe because its period is at least the history
/// window, so a reachable candidate slot cannot be overwritten.
pub const StreamingHashGreedy = struct {
    head: std.ArrayList(i64) = .empty,
    prev: std.ArrayList(i64) = .empty,
    window_len: usize,

    pub const Result = struct {
        token: Token,
        consumed: usize,
    };

    pub fn init(allocator: std.mem.Allocator, window_len: usize) !StreamingHashGreedy {
        if (window_len == 0 or window_len > max_window_len) return error.InvalidBlockPlan;
        var state = StreamingHashGreedy{ .window_len = window_len };
        errdefer state.deinit(allocator);
        try state.head.resize(allocator, hash_head_table_size);
        @memset(state.head.items, -1);
        var prev_len: usize = 1;
        while (prev_len < window_len) prev_len *= 2;
        try state.prev.resize(allocator, prev_len);
        @memset(state.prev.items, -1);
        return state;
    }

    pub fn deinit(self: *StreamingHashGreedy, allocator: std.mem.Allocator) void {
        self.head.deinit(allocator);
        self.prev.deinit(allocator);
        self.* = undefined;
    }

    pub fn reset(self: *StreamingHashGreedy) void {
        @memset(self.head.items, -1);
        @memset(self.prev.items, -1);
    }

    pub fn next(
        self: *StreamingHashGreedy,
        dictionary: []const u8,
        input: []const u8,
        position: usize,
        stream_start: usize,
        options: GreedyOptions,
    ) Error!Result {
        if (options.window_len != self.window_len or position >= input.len)
            return error.InvalidBlockPlan;
        const absolute = std.math.add(usize, stream_start, position) catch
            return error.IntegerOverflow;
        const max_len = @min(maxMatch(options), input.len - position);
        var best = MatchCandidate{};
        const hash = streamingHash(input, position);
        if (hash) |bucket| {
            const earliest = absolute -| self.window_len;
            var candidate_i = self.head.items[bucket];
            var checked: usize = 0;
            var walked: usize = 0;
            const max_walks = maxHashChainWalks(options, minMatch(options));
            while (candidate_i >= 0 and walked < max_walks) : (walked += 1) {
                const candidate: usize = @intCast(candidate_i);
                if (candidate < earliest) break;
                if (candidate >= absolute) return error.InvalidMatch;
                if (best.length == max_len) break;
                const distance = absolute - candidate;
                const required_prefix = @max(best.length, minMatch(options) - 1);
                if (streamingByte(dictionary, input, stream_start, candidate + required_prefix) !=
                    input[position + required_prefix])
                {
                    candidate_i = self.prev.items[candidate % self.prev.items.len];
                    continue;
                }
                checked += 1;
                var length: usize = 0;
                while (length < max_len and
                    streamingByte(dictionary, input, stream_start, candidate + length) == input[position + length])
                {
                    length += 1;
                }
                if (length >= minMatch(options) and length > best.length) {
                    best = .{ .length = length, .distance = distance };
                    if (length >= options.nice_len) break;
                }
                if (checked == options.max_chain) break;
                candidate_i = self.prev.items[candidate % self.prev.items.len];
            }
        }

        const accepted = acceptMatch(input, position, best.length, best.distance, options);
        if (accepted) {
            const end = position + best.length;
            try self.insert(input, position, stream_start);
            const tail_start = if (end > position + 4) end - 4 else position + 1;
            var seed = @max(position + 1, tail_start);
            while (seed < end) : (seed += 1)
                try self.insert(input, seed, stream_start);
            return .{
                .token = .{ .match = .{
                    .length = @intCast(best.length),
                    .distance = @intCast(best.distance),
                } },
                .consumed = best.length,
            };
        }
        try self.insert(input, position, stream_start);
        return .{ .token = .{ .literal = input[position] }, .consumed = 1 };
    }

    fn insert(
        self: *StreamingHashGreedy,
        input: []const u8,
        position: usize,
        stream_start: usize,
    ) Error!void {
        const bucket = streamingHash(input, position) orelse return;
        const absolute = std.math.add(usize, stream_start, position) catch
            return error.IntegerOverflow;
        const stored_position = std.math.cast(i64, absolute) orelse
            return error.IntegerOverflow;
        self.prev.items[absolute % self.prev.items.len] = self.head.items[bucket];
        self.head.items[bucket] = stored_position;
    }
};

fn streamingHash(input: []const u8, position: usize) ?usize {
    if (input.len - position < min_match_len) return null;
    return hash3(input[position..][0..3]) & (hash_head_table_size - 1);
}

fn streamingByte(
    dictionary: []const u8,
    input: []const u8,
    stream_start: usize,
    absolute: usize,
) u8 {
    const history_start = stream_start - dictionary.len;
    return if (absolute < stream_start)
        dictionary[absolute - history_start]
    else
        input[absolute - stream_start];
}

pub const OptimalScratch = struct {
    costs: std.ArrayList(usize) = .empty,
    steps: std.ArrayList(Token) = .empty,
    index: HashIndex = .{},
    compact_head: std.ArrayList(u32) = .empty,
    compact_prev: std.ArrayList(u32) = .empty,
    tokens: std.ArrayList(Token) = .empty,

    pub fn deinit(self: *OptimalScratch, allocator: std.mem.Allocator) void {
        self.costs.deinit(allocator);
        self.steps.deinit(allocator);
        self.index.deinit(allocator);
        self.compact_head.deinit(allocator);
        self.compact_prev.deinit(allocator);
        self.tokens.deinit(allocator);
        self.* = .{};
    }
};

/// Caller-supplied token costs for the bounded optimal parser. Costs use an
/// arbitrary common fixed-point scale; only their relative values matter.
/// The Brotli encoder uses Q8 entropy estimates while the established generic
/// parser keeps its compile-time fixed-Huffman proxy.
pub const OptimalCostModel = struct {
    literal: *const [256]u16,
    length: *const [max_match_len + 1]u16,
    /// Entry zero is unused. The slice must cover every distance permitted by
    /// the matching window supplied to the parser.
    distance: []const u16,

    fn validate(self: OptimalCostModel, window_len: usize, input_len: usize) Error!void {
        if (self.distance.len <= window_len) return error.InvalidBlockPlan;
        for (self.literal) |cost| if (cost == 0) return error.InvalidBlockPlan;
        for (self.length[min_match_len..]) |cost| if (cost == 0) return error.InvalidBlockPlan;
        for (self.distance[1 .. window_len + 1]) |cost| if (cost == 0) return error.InvalidBlockPlan;

        const max_literal = std.mem.max(u16, self.literal);
        const max_length = std.mem.max(u16, self.length[min_match_len..]);
        const max_distance = std.mem.max(u16, self.distance[1 .. window_len + 1]);
        const literal_bound = std.math.mul(usize, input_len, max_literal) catch
            return error.InvalidBlockPlan;
        const match_edge_bound = @as(usize, max_length) + max_distance;
        const maximum_cost = std.math.add(usize, literal_bound, match_edge_bound) catch
            return error.InvalidBlockPlan;
        const representable = if (comptime packed_optimal_length_choices)
            std.math.maxInt(usize) >> optimal_length_bits
        else
            std.math.maxInt(usize);
        if (maximum_cost > representable) return error.InvalidBlockPlan;
    }
};

const optimal_compact_index_empty = std.math.maxInt(u32);

fn buildOptimalCompactHashIndex(
    allocator: std.mem.Allocator,
    input: []const u8,
    head: *std.ArrayList(u32),
    prev: *std.ArrayList(u32),
    head_initialized: *[hash_head_init_words]u64,
) !void {
    if (input.len > optimal_compact_index_empty) return error.InvalidBlockPlan;
    try head.resize(allocator, hash_head_table_size);
    try prev.resize(allocator, input.len);
    @memset(head_initialized, 0);
    for (0..input.len) |position| {
        const hash = hashAtInput(input, position, head.items.len, .three) orelse continue;
        const mask = @as(u64, 1) << @intCast(hash & 63);
        const word = &head_initialized[hash / 64];
        prev.items[position] = if (word.* & mask == 0) optimal_compact_index_empty else head.items[hash];
        head.items[hash] = @intCast(position);
        word.* |= mask;
    }
}

pub const RepBeamScratch = struct {
    states: std.ArrayList(RepBeamState) = .empty,
    lengths: std.ArrayList(u8) = .empty,
    index: RepBeamIndex = .{},
    reversed: std.ArrayList(Token) = .empty,

    pub fn deinit(self: *RepBeamScratch, allocator: std.mem.Allocator) void {
        self.reversed.deinit(allocator);
        self.index.deinit(allocator);
        self.lengths.deinit(allocator);
        self.states.deinit(allocator);
        self.* = .{};
    }
};

const rep_beam_index_empty = std.math.maxInt(u16);

const RepBeamIndex = struct {
    head: [4096]u16 = @splat(rep_beam_index_empty),
    prev: std.ArrayList(u16) = .empty,
    input_len: usize = 0,

    fn deinit(self: *RepBeamIndex, allocator: std.mem.Allocator) void {
        self.prev.deinit(allocator);
        self.* = .{};
    }

    fn build(self: *RepBeamIndex, allocator: std.mem.Allocator, input: []const u8) !void {
        if (input.len > rep_beam_input_max) return error.InvalidBlockPlan;
        try self.prev.resize(allocator, input.len);
        @memset(&self.head, rep_beam_index_empty);
        self.input_len = input.len;
        for (0..input.len) |position| {
            const hash = hashAtInput(input, position, self.head.len, .four) orelse {
                self.prev.items[position] = rep_beam_index_empty;
                continue;
            };
            self.prev.items[position] = self.head[hash];
            self.head[hash] = @intCast(position);
        }
    }

    fn matchesAt(self: *const RepBeamIndex, input: []const u8, position: usize, options: GreedyOptions, out: []Token.Match) Error!usize {
        if (input.len != self.input_len or position > input.len) return error.InvalidBlockPlan;
        if (position + minMatch(options) > input.len or out.len == 0) return 0;
        var candidate_i = self.prev.items[position];
        var checked: usize = 0;
        var count: usize = 0;
        const maximum = @min(maxMatch(options), input.len - position);
        while (candidate_i != rep_beam_index_empty and checked < options.max_chain and count < out.len) : (checked += 1) {
            const candidate: usize = candidate_i;
            const distance = position - candidate;
            if (distance == 0 or distance > options.window_len) break;
            if (input[candidate + 3] == input[position + 3]) {
                const length = matchLength(input, candidate, position, maximum);
                if (length >= minMatch(options)) {
                    out[count] = .{ .length = @intCast(length), .distance = @intCast(distance) };
                    count += 1;
                }
            }
            candidate_i = self.prev.items[candidate];
        }
        return count;
    }

    inline fn matchesAtZstd(self: *const RepBeamIndex, input: []const u8, position: usize, out: []Token.Match) usize {
        std.debug.assert(input.len == self.input_len and position + 4 <= input.len and out.len != 0);
        var candidate_i = self.prev.items[position];
        var checked: usize = 0;
        var count: usize = 0;
        const maximum = @min(max_match_len, input.len - position);
        const window_len = @min(input.len, default_window_len);
        const anchor = std.mem.readInt(u32, input[position..][0..4], .little);
        while (candidate_i != rep_beam_index_empty and checked < 128 and count < out.len) : (checked += 1) {
            const candidate: usize = candidate_i;
            const distance = position - candidate;
            if (distance == 0 or distance > window_len) break;
            // The index collides on twelve hash bits. Reject the remaining
            // prefix collisions in one load, then continue after the four
            // bytes already proven equal.
            if (std.mem.readInt(u32, input[candidate..][0..4], .little) == anchor) {
                const length = 4 + matchLength(input, candidate + 4, position + 4, maximum - 4);
                out[count] = .{ .length = @intCast(length), .distance = @intCast(distance) };
                count += 1;
            }
            candidate_i = self.prev.items[candidate];
        }
        return count;
    }
};

pub const HashIndex = struct {
    head: std.ArrayList(isize) = .empty,
    prev: std.ArrayList(isize) = .empty,
    head_initialized: [hash_head_init_words]u64 = @splat(0),
    best_length_choices: [max_match_len + 1]usize = undefined,
    // Retain this storage on 64-bit targets even though the packed choice holds
    // the length too. The stable shared-index layout avoids moving unrelated
    // encoder state; 32-bit targets use the array as the portable fallback.
    best_lengths: [max_match_len + 1]u16 = undefined,
    input_len: usize = 0,

    pub fn deinit(self: *HashIndex, allocator: std.mem.Allocator) void {
        self.head.deinit(allocator);
        self.prev.deinit(allocator);
        self.* = .{};
    }

    pub fn build(self: *HashIndex, allocator: std.mem.Allocator, input: []const u8) !void {
        return self.buildWithHeadLen(allocator, input, hash_head_table_size);
    }

    fn buildWithHeadLen(self: *HashIndex, allocator: std.mem.Allocator, input: []const u8, head_len: usize) !void {
        std.debug.assert(std.math.isPowerOfTwo(head_len));
        std.debug.assert(head_len <= hash_head_table_size);
        try self.head.resize(allocator, head_len);
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

    /// Enumerate bounded same-hash match candidates in nearest-first chain
    /// order. Format-specific optimal parsers may attach their own stateful
    /// entropy costs while reusing the validated shared match index.
    pub fn matchesAt(self: *const HashIndex, input: []const u8, pos: usize, options: GreedyOptions, out: []Token.Match) Error!usize {
        if (input.len != self.input_len or pos > input.len) return error.InvalidBlockPlan;
        if (pos + minMatch(options) > input.len or out.len == 0) return 0;
        const maximum = @min(maxMatch(options), input.len - pos);
        var chain_i = self.prev.items[pos];
        var checked: usize = 0;
        var count: usize = 0;
        while (chain_i >= 0 and checked < options.max_chain and count < out.len) : (checked += 1) {
            const candidate: usize = @intCast(chain_i);
            const distance = pos - candidate;
            if (distance == 0 or distance > options.window_len) break;
            if (minMatch(options) >= 4 and input[candidate + 3] != input[pos + 3]) {
                chain_i = self.prev.items[candidate];
                continue;
            }
            const length = matchLength(input, candidate, pos, maximum);
            if (length >= minMatch(options)) {
                out[count] = .{ .length = @intCast(length), .distance = @intCast(distance) };
                count += 1;
            }
            chain_i = self.prev.items[candidate];
        }
        return count;
    }

    /// Enumerate prefix-validated candidate distances without extending each
    /// match. Stateful format parsers can cheaply inspect a deeper hash chain,
    /// then spend full match-length work only on candidates favored by their
    /// own entropy or recent-distance model.
    pub fn candidateDistancesAt(
        self: *const HashIndex,
        input: []const u8,
        pos: usize,
        options: GreedyOptions,
        out: []u16,
    ) Error!usize {
        if (input.len != self.input_len or pos > input.len) return error.InvalidBlockPlan;
        if (options.window_len > max_window_len) return error.InvalidBlockPlan;
        const minimum = minMatch(options);
        if (pos + minimum > input.len or out.len == 0) return 0;
        var chain_i = self.prev.items[pos];
        var checked: usize = 0;
        var count: usize = 0;
        while (chain_i >= 0 and checked < options.max_chain and count < out.len) : (checked += 1) {
            const candidate: usize = @intCast(chain_i);
            const distance = pos - candidate;
            if (distance == 0 or distance > options.window_len) break;
            const prefix_matches = if (minimum >= 4)
                std.mem.readInt(u32, input[candidate..][0..4], .little) ==
                    std.mem.readInt(u32, input[pos..][0..4], .little)
            else
                std.mem.eql(u8, input[candidate..][0..minimum], input[pos..][0..minimum]);
            if (prefix_matches) {
                out[count] = @intCast(distance);
                count += 1;
            }
            chain_i = self.prev.items[candidate];
        }
        return count;
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

/// Reusable-token counterpart to `lazyGreedyPlanAlloc` for small blocks. It
/// preserves the production scan-vs-hash policy while retaining the caller's
/// token capacity across independent inputs.
pub fn lazyGreedyPlanTinyReuse(tokens: *std.ArrayList(Token), allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !PlanStats {
    if (input.len > 32 * 1024) return error.InvalidBlockPlan;
    if (preferScanLazy(input)) return scanLazyGreedyPlanReuse(tokens, allocator, input, options);
    return hashLazyGreedyPlanTinyReuse(tokens, allocator, input, options);
}

pub fn hashGreedyPlanAllocWithDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: GreedyOptions) !GreedyPlan {
    const dict = activeDictionary(dictionary, options);
    if (dict.len == 0) return hashGreedyPlanAlloc(allocator, input, options);
    var scratch: DictionaryGreedyScratch = .{};
    defer scratch.deinit(allocator);
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(allocator);
    const stats = try hashGreedyPlanWithDictionaryReuse(&tokens, &scratch, allocator, input, dict, options);
    return .{ .tokens = try allocator.dupe(Token, tokens.items), .stats = stats };
}

pub fn hashGreedyPlanWithDictionaryReuse(tokens: *std.ArrayList(Token), scratch: *DictionaryGreedyScratch, allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: GreedyOptions) !PlanStats {
    const dict = activeDictionary(dictionary, options);
    if (dict.len == 0) return hashGreedyPlanAutoTinyReuse(tokens, allocator, input, options);
    const table_size = 1 << 15;
    try scratch.head.resize(allocator, table_size);
    @memset(&scratch.head_initialized, 0);
    const total = dict.len + input.len;
    try scratch.prev.resize(allocator, total);
    seedDictionaryHashesLazy(dict, input, scratch.head.items, scratch.prev.items, &scratch.head_initialized);
    tokens.clearRetainingCapacity();
    var stats = PlanStats{};

    var pos: usize = 0;
    while (pos < input.len) {
        const current = dict.len + pos;
        const best = findBestCombinedHashMatchLazy(dict, input, current, options, scratch.head.items, scratch.prev.items, &scratch.head_initialized);

        if (acceptMatch(input, pos, best.length, best.distance, options)) {
            try appendToken(tokens, allocator, .{ .match = .{ .length = @intCast(best.length), .distance = @intCast(best.distance) } });
            stats.matches += 1;
            stats.matched_bytes += best.length;
            const end = @min(input.len, pos + best.length);
            insertCombinedHashLazy(dict, input, current, scratch.head.items, scratch.prev.items, &scratch.head_initialized);
            const tail_start = if (end > pos + 4) end - 4 else pos + 1;
            pos += 1;
            if (pos < tail_start) pos = tail_start;
            while (pos < end) : (pos += 1) insertCombinedHashLazy(dict, input, dict.len + pos, scratch.head.items, scratch.prev.items, &scratch.head_initialized);
        } else {
            try appendToken(tokens, allocator, .{ .literal = input[pos] });
            stats.literals += 1;
            insertCombinedHashLazy(dict, input, current, scratch.head.items, scratch.prev.items, &scratch.head_initialized);
            pos += 1;
        }
    }
    return stats;
}

test "dictionary greedy scratch ignores stale head entries" {
    var scratch: DictionaryGreedyScratch = .{};
    defer scratch.deinit(std.testing.allocator);
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(std.testing.allocator);
    const options: GreedyOptions = .{ .window_len = 32 * 1024, .max_chain = 64, .nice_len = 64, .max_candidates = 8 };

    const first_dictionary = "abcdefgh" ** 32;
    const first_input = "abcdefgh" ** 16;
    _ = try hashGreedyPlanWithDictionaryReuse(&tokens, &scratch, std.testing.allocator, first_input, first_dictionary, options);
    try expectDictionaryPlanReplays(first_dictionary, first_input, tokens.items);

    const second_dictionary = "qrstuvwx" ** 32;
    const second_input = "qrstuvwx" ** 16;
    _ = try hashGreedyPlanWithDictionaryReuse(&tokens, &scratch, std.testing.allocator, second_input, second_dictionary, options);
    try expectDictionaryPlanReplays(second_dictionary, second_input, tokens.items);
}

test "reusable dictionary lazy planner preserves allocating plans" {
    const dictionaries = [_][]const u8{
        "sensor=42;status=nominal;" ** 8,
        "abcdefgh01234567" ** 16,
        "",
    };
    const inputs = [_][]const u8{
        "sensor=42;status=nominal;sensor=43;status=nominal;" ** 3,
        "abcdXabcdefgh01234567abcdYabcdefgh01234567" ** 4,
        "abcabcXabcabcYabcabcZ" ** 5,
    };
    const options: GreedyOptions = .{
        .window_len = 32 * 1024,
        .max_chain = 64,
        .nice_len = 96,
        .max_candidates = 8,
        .min_match = 4,
        .max_match = 128,
        .lazy_min_gain = 2,
        .min_savings_bits = 4,
    };
    var scratch: DictionaryGreedyScratch = .{};
    defer scratch.deinit(std.testing.allocator);
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(std.testing.allocator);

    for (dictionaries, inputs) |dictionary, input| {
        const reference = try lazyGreedyPlanAllocWithDictionary(std.testing.allocator, input, dictionary, options);
        defer reference.deinit(std.testing.allocator);
        const stats = try lazyGreedyPlanWithDictionaryReuse(&tokens, &scratch, std.testing.allocator, input, dictionary, options);
        try expectEqualTokenSlices(reference.tokens, tokens.items);
        try std.testing.expectEqual(reference.stats, stats);
        try expectDictionaryPlanReplays(activeDictionary(dictionary, options), input, tokens.items);
    }
}

test "reusable dictionary lazy planner ignores stale head entries" {
    const options: GreedyOptions = .{ .window_len = 32 * 1024, .max_chain = 64, .nice_len = 64, .max_candidates = 8 };
    var scratch: DictionaryGreedyScratch = .{};
    defer scratch.deinit(std.testing.allocator);
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(std.testing.allocator);

    const first_dictionary = "abcdefgh" ** 32;
    const first_input = "abcdefghXabcdefghYabcdefgh" ** 4;
    _ = try lazyGreedyPlanWithDictionaryReuse(&tokens, &scratch, std.testing.allocator, first_input, first_dictionary, options);
    try expectDictionaryPlanReplays(first_dictionary, first_input, tokens.items);

    const second_dictionary = "qrstuvwx" ** 32;
    const second_input = "qrstuvwxXqrstuvwxYqrstuvwx" ** 4;
    const reference = try lazyGreedyPlanAllocWithDictionary(std.testing.allocator, second_input, second_dictionary, options);
    defer reference.deinit(std.testing.allocator);
    const stats = try lazyGreedyPlanWithDictionaryReuse(&tokens, &scratch, std.testing.allocator, second_input, second_dictionary, options);
    try expectEqualTokenSlices(reference.tokens, tokens.items);
    try std.testing.expectEqual(reference.stats, stats);
    try expectDictionaryPlanReplays(second_dictionary, second_input, tokens.items);
}

test "reusable dictionary lazy planner retains all capacity" {
    const dictionary = "common-prefix:sensor=42;status=nominal;" ** 64;
    const input = "common-prefix:sensor=42;status=nominal;reading=12345;" ** 32;
    const options: GreedyOptions = .{ .window_len = 32 * 1024, .max_chain = 64, .nice_len = 96, .max_candidates = 8 };
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    {
        const allocator = failing.allocator();
        var scratch: DictionaryGreedyScratch = .{};
        defer scratch.deinit(allocator);
        var tokens: std.ArrayList(Token) = .empty;
        defer tokens.deinit(allocator);

        const first_stats = try lazyGreedyPlanWithDictionaryReuse(&tokens, &scratch, allocator, input, dictionary, options);
        const capacities = .{ tokens.capacity, scratch.head.capacity, scratch.prev.capacity };
        const allocations = failing.allocations;
        const resizes = failing.resize_index;
        const allocated_bytes = failing.allocated_bytes;
        const second_stats = try lazyGreedyPlanWithDictionaryReuse(&tokens, &scratch, allocator, input, dictionary, options);
        try std.testing.expectEqual(first_stats, second_stats);
        try std.testing.expectEqual(capacities, .{ tokens.capacity, scratch.head.capacity, scratch.prev.capacity });
        try std.testing.expectEqual(allocations, failing.allocations);
        try std.testing.expectEqual(resizes, failing.resize_index);
        try std.testing.expectEqual(allocated_bytes, failing.allocated_bytes);
    }
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

test "reusable dictionary lazy planner recovers after allocation failure" {
    const dictionary = "dictionary-history-0123456789" ** 32;
    const input = "dictionary-history-0123456789-payload" ** 8;
    const options: GreedyOptions = .{ .window_len = 32 * 1024, .max_chain = 32, .nice_len = 64 };
    // Let both scratch tables allocate, then fail the first token growth after
    // the dictionary has already populated the lazy-initialized hash table.
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 2 });
    {
        const allocator = failing.allocator();
        var scratch: DictionaryGreedyScratch = .{};
        defer scratch.deinit(allocator);
        var tokens: std.ArrayList(Token) = .empty;
        defer tokens.deinit(allocator);

        try std.testing.expectError(
            error.OutOfMemory,
            lazyGreedyPlanWithDictionaryReuse(&tokens, &scratch, allocator, input, dictionary, options),
        );
        failing.fail_index = std.math.maxInt(usize);
        const stats = try lazyGreedyPlanWithDictionaryReuse(&tokens, &scratch, allocator, input, dictionary, options);
        try std.testing.expect(stats.matches > 0);
        try expectDictionaryPlanReplays(dictionary, input, tokens.items);
    }
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

fn expectDictionaryPlanReplays(dictionary: []const u8, expected: []const u8, tokens: []const Token) !void {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);
    for (tokens) |token| switch (token) {
        .literal => |byte| try output.append(std.testing.allocator, byte),
        .match => |match| for (0..match.length) |_| {
            const logical_len = dictionary.len + output.items.len;
            if (match.distance == 0 or match.distance > logical_len) return error.InvalidMatch;
            const source = logical_len - match.distance;
            const byte = if (source < dictionary.len) dictionary[source] else output.items[source - dictionary.len];
            try output.append(std.testing.allocator, byte);
        },
    };
    try std.testing.expectEqualSlices(u8, expected, output.items);
}

/// Scan-backed preset-history planner for small discontiguous blocks.
///
/// This avoids clearing the dictionary hash tables once per caller slice. It
/// deliberately targets bounded fast-parser inputs: `max_chain` caps the
/// number of matching first-byte candidates examined at every position.
pub fn greedyPlanAllocWithDictionary(
    allocator: std.mem.Allocator,
    input: []const u8,
    dictionary: []const u8,
    options: GreedyOptions,
) !GreedyPlan {
    const dict = activeDictionary(dictionary, options);
    if (dict.len == 0) return greedyPlanAlloc(allocator, input, options);

    var tokens = try initTokenList(allocator, input.len);
    errdefer tokens.deinit(allocator);
    var stats = PlanStats{};
    var pos: usize = 0;
    while (pos < input.len) {
        const best = findBestCombinedScanMatch(dict, input, pos, options);
        if (acceptMatch(input, pos, best.length, best.distance, options)) {
            try appendToken(&tokens, allocator, .{ .match = .{
                .length = @intCast(best.length),
                .distance = @intCast(best.distance),
            } });
            stats.matches += 1;
            stats.matched_bytes += best.length;
            pos += best.length;
        } else {
            try appendToken(&tokens, allocator, .{ .literal = input[pos] });
            stats.literals += 1;
            pos += 1;
        }
    }
    return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
}

pub fn lazyGreedyPlanAllocWithDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: GreedyOptions) !GreedyPlan {
    const dict = activeDictionary(dictionary, options);
    if (dict.len == 0) return lazyGreedyPlanAlloc(allocator, input, options);

    var scratch: DictionaryGreedyScratch = .{};
    defer scratch.deinit(allocator);
    var tokens = try initTokenList(allocator, input.len);
    errdefer tokens.deinit(allocator);
    const stats = try lazyGreedyPlanWithDictionaryReuse(&tokens, &scratch, allocator, input, dict, options);
    return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
}

/// Reusable-token and reusable-table counterpart to
/// `lazyGreedyPlanAllocWithDictionary`. Independent calls may use unrelated
/// inputs and dictionaries; the initialization bitmap prevents stale head
/// entries from entering the next hash chain.
pub fn lazyGreedyPlanWithDictionaryReuse(tokens: *std.ArrayList(Token), scratch: *DictionaryGreedyScratch, allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: GreedyOptions) !PlanStats {
    const dict = activeDictionary(dictionary, options);
    if (dict.len == 0) {
        if (preferScanLazy(input)) return scanLazyGreedyPlanReuse(tokens, allocator, input, options);
        if (input.len <= 32 * 1024) return hashLazyGreedyPlanTinyReuse(tokens, allocator, input, options);
    }

    try scratch.head.resize(allocator, hash_head_table_size);
    const total = dict.len + input.len;
    try scratch.prev.resize(allocator, total);
    @memset(&scratch.head_initialized, 0);
    seedDictionaryHashesLazy(dict, input, scratch.head.items, scratch.prev.items, &scratch.head_initialized);
    tokens.clearRetainingCapacity();
    var stats = PlanStats{};

    var pos: usize = 0;
    while (pos < input.len) {
        const current = dict.len + pos;
        const best = findBestCombinedHashMatchLazy(dict, input, current, options, scratch.head.items, scratch.prev.items, &scratch.head_initialized);
        if (!acceptMatch(input, pos, best.length, best.distance, options)) {
            try appendToken(tokens, allocator, .{ .literal = input[pos] });
            stats.literals += 1;
            insertCombinedHashLazy(dict, input, current, scratch.head.items, scratch.prev.items, &scratch.head_initialized);
            pos += 1;
            continue;
        }

        var current_inserted = false;
        if (pos + 1 < input.len) {
            insertCombinedHashLazy(dict, input, current, scratch.head.items, scratch.prev.items, &scratch.head_initialized);
            current_inserted = true;
            const next = findBestCombinedHashMatchLazy(dict, input, current + 1, options, scratch.head.items, scratch.prev.items, &scratch.head_initialized);
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
        while (insert_pos < end) : (insert_pos += 1)
            insertCombinedHashLazy(dict, input, dict.len + insert_pos, scratch.head.items, scratch.prev.items, &scratch.head_initialized);
        pos += best.length;
    }

    return stats;
}

fn preferScanLazy(input: []const u8) bool {
    const max_scan_trigram_buckets = 64;
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
                if (trigram_count > max_scan_trigram_buckets) return false;
            }
        }
    }
    // The backwards scanner wins on tiny and low-entropy inputs because it has
    // no table allocation/clear cost and quickly finds long repeated runs.
    // Byte diversity alone is a weak proxy: Markdown/source often has fewer
    // than 48 distinct bytes in the first KiB but many distinct 3-byte
    // anchors, so a blind backward scan burns time on non-candidates. The
    // 64-bucket cutoff routes numbered JSON (83 buckets in the first KiB) to
    // hashing while keeping the repeated-text benchmark (61) on the cheaper
    // scan path. Use this small sketch to distinguish structure without a full
    // trial parse.
    return true;
}

fn scanLazyGreedyPlanAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    var tokens = try initTokenList(allocator, input.len);
    errdefer tokens.deinit(allocator);
    const stats = try scanLazyGreedyPlanReuse(&tokens, allocator, input, options);
    return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
}

fn scanLazyGreedyPlanReuse(tokens: *std.ArrayList(Token), allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !PlanStats {
    tokens.clearRetainingCapacity();
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

    return stats;
}

fn hashLazyGreedyPlanAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    if (hashPositionFitsU32(input.len)) {
        return hashLazyGreedyPlanAllocWithPosition(u32, allocator, input, options);
    }
    return hashLazyGreedyPlanAllocWithPosition(isize, allocator, input, options);
}

fn hashLazyGreedyPlanAllocWithPosition(
    comptime Position: type,
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
) !GreedyPlan {
    const table_size = 1 << 15;
    const head = try allocator.alloc(Position, table_size);
    defer allocator.free(head);
    @memset(head, hashPositionEmpty(Position));
    const prev = try allocator.alloc(Position, input.len);
    defer allocator.free(prev);
    return hashLazyGreedyPlanWithTables(allocator, input, options, head, prev);
}

fn hashLazyGreedyPlanTinyAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    if (input.len > 32 * 1024) return hashLazyGreedyPlanAlloc(allocator, input, options);

    var head: [4096]isize = @splat(-1);
    var prev_stack: [32 * 1024]isize = undefined;
    return hashLazyGreedyPlanWithTables(allocator, input, options, &head, prev_stack[0..input.len]);
}

fn hashLazyGreedyPlanWithTables(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions, head: anytype, prev: anytype) !GreedyPlan {
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

fn hashLazyGreedyPlanWithTablesReuse(tokens: *std.ArrayList(Token), allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions, head: anytype, prev: anytype) !PlanStats {
    var stats = PlanStats{};

    var pos: usize = 0;
    while (pos < input.len) {
        const best = findBestHashMatchWithLayout(input, pos, options, head, prev, false, false, {}, .three);
        if (!acceptMatch(input, pos, best.length, best.distance, options)) {
            try appendToken(tokens, allocator, .{ .literal = input[pos] });
            stats.literals += 1;
            insertHashWithLayout(input, pos, head, prev, false, false, {}, .three);
            pos += 1;
            continue;
        }

        var current_inserted = false;
        if (pos + 1 < input.len) {
            // Insert the current position before the lazy probe so distance-1
            // runs can be discovered at pos+1. If we keep the current match we
            // skip re-inserting pos below and only seed the skipped positions.
            insertHashWithLayout(input, pos, head, prev, false, false, {}, .three);
            current_inserted = true;
            const next = findBestHashMatchWithLayout(input, pos + 1, options, head, prev, false, false, {}, .three);
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
        while (insert_pos < end) : (insert_pos += 1)
            insertHashWithLayout(input, insert_pos, head, prev, false, false, {}, .three);
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

/// Run the same bounded hash-chain search as `optimalPlanAlloc`, but score its
/// literal, match-length, and match-distance choices with a caller model. This
/// is a proposal API: format encoders should still arbitrate the resulting
/// plan using their complete wire cost.
pub fn optimalPlanAllocWithCostModel(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    model: OptimalCostModel,
) !GreedyPlan {
    var scratch: OptimalScratch = .{};
    defer scratch.deinit(allocator);
    const stats = try optimalPlanReuseWithCostModel(&scratch, allocator, input, options, model);
    return .{ .tokens = try allocator.dupe(Token, scratch.tokens.items), .stats = stats };
}

const rep_beam_width = 2;
const rep_beam_match_candidates = 1;
const rep_beam_input_max = std.math.maxInt(u16);

const RepBeamState = struct {
    cost: u32 = std.math.maxInt(u32),
    rep0: u16 = 1,
    previous_position: u16 = 0,
    previous_slot: u8 = 0,
    token: Token = .{ .literal = 0 },
};

comptime {
    // `lengths[position]` is the sole initialized-slot count. Keeping this
    // invariant explicit lets the hot parser iterate that slice without a
    // redundant sentinel-cost branch on every state.
    std.debug.assert(rep_beam_width <= std.math.maxInt(u8));
}

/// Bounded forward parser that keeps several recent-offset histories at each
/// byte position. This lets Zstd callers pay once for a farther match when it
/// enables a long run of cheap repeat-offset sequences.
pub fn optimalRepBeamPlanAlloc(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !GreedyPlan {
    var scratch: RepBeamScratch = .{};
    defer scratch.deinit(allocator);
    const stats = try optimalRepBeamPlanReuse(&scratch, allocator, input, options);
    return .{ .tokens = try allocator.dupe(Token, scratch.reversed.items), .stats = stats };
}

pub fn optimalRepBeamPlanReuse(scratch: *RepBeamScratch, allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !PlanStats {
    if (input.len == 0 or input.len > rep_beam_input_max) return error.InvalidBlockPlan;
    try scratch.index.build(allocator, input);

    const state_count = std.math.mul(usize, input.len + 1, rep_beam_width) catch return error.IntegerOverflow;
    try scratch.states.resize(allocator, state_count);
    try scratch.lengths.resize(allocator, input.len + 1);
    const states = scratch.states.items;
    const lengths = scratch.lengths.items;
    @memset(lengths, 0);
    states[0] = .{ .cost = 0 };
    lengths[0] = 1;

    var matches: [rep_beam_match_candidates]Token.Match = undefined;
    for (0..input.len) |position| {
        const can_match = position + minMatch(options) <= input.len;
        const match_count = if (can_match) try scratch.index.matchesAt(input, position, options, &matches) else 0;
        const current = states[position * rep_beam_width ..][0..lengths[position]];
        for (current, 0..) |state, slot| {
            insertRepBeamState(states, lengths, position + 1, .{
                .cost = state.cost + @as(u32, @intCast(fixedLiteralCost(input[position]))),
                .rep0 = state.rep0,
                .previous_position = @intCast(position),
                .previous_slot = @intCast(slot),
                .token = .{ .literal = input[position] },
            });

            for (matches[0..match_count]) |match| {
                extendRepBeamMatchKnownValid(states, lengths, options, position, slot, state, match);
            }
            const indexed_rep0 = match_count != 0 and matches[0].distance == state.rep0;
            if (can_match and state.rep0 <= position and !indexed_rep0) {
                const candidate = position - state.rep0;
                const length = repBeamMatchLength(input, candidate, position, @min(maxMatch(options), input.len - position), minMatch(options));
                if (length != 0) {
                    extendRepBeamMatchKnownValid(states, lengths, options, position, slot, state, .{ .length = @intCast(length), .distance = state.rep0 });
                }
            }
        }
    }

    return finishRepBeamPlan(scratch, allocator, input.len, states, lengths);
}

fn finishRepBeamPlan(scratch: *RepBeamScratch, allocator: std.mem.Allocator, input_len: usize, states: []const RepBeamState, lengths: []const u8) !PlanStats {
    const final_states = states[input_len * rep_beam_width ..][0..lengths[input_len]];
    var best_slot: ?usize = null;
    for (final_states, 0..) |state, slot| {
        if (best_slot == null or state.cost < final_states[best_slot.?].cost) best_slot = slot;
    }
    scratch.reversed.clearRetainingCapacity();
    try scratch.reversed.ensureTotalCapacity(allocator, @min(input_len, 4096));
    var position = input_len;
    var slot = best_slot orelse return error.InvalidBlockPlan;
    while (position != 0) {
        const state = states[position * rep_beam_width + slot];
        try appendToken(&scratch.reversed, allocator, state.token);
        position = state.previous_position;
        slot = state.previous_slot;
    }
    std.mem.reverse(Token, scratch.reversed.items);

    var stats: PlanStats = .{};
    for (scratch.reversed.items) |token| switch (token) {
        .literal => stats.literals += 1,
        .match => |match| {
            stats.matches += 1;
            stats.matched_bytes += match.length;
        },
    };
    return stats;
}

/// Zstd's repeat-aware parser uses fixed match and cost limits. Keeping those
/// invariants inside one specialized loop lets the optimizer remove generic
/// option normalization without changing the reusable LZ77 API above.
pub fn optimalRepBeamPlanZstdReuse(scratch: *RepBeamScratch, allocator: std.mem.Allocator, input: []const u8) !PlanStats {
    if (input.len == 0 or input.len > rep_beam_input_max) return error.InvalidBlockPlan;
    try scratch.index.build(allocator, input);

    const state_count = std.math.mul(usize, input.len + 1, rep_beam_width) catch return error.IntegerOverflow;
    try scratch.states.resize(allocator, state_count);
    try scratch.lengths.resize(allocator, input.len + 1);
    const states = scratch.states.items;
    const lengths = scratch.lengths.items;
    @memset(lengths, 0);
    states[0] = .{ .cost = 0 };
    lengths[0] = 1;

    var matches: [rep_beam_match_candidates]Token.Match = undefined;
    for (0..input.len) |position| {
        const can_match = position + 4 <= input.len;
        const match_count = if (can_match) scratch.index.matchesAtZstd(input, position, &matches) else 0;
        const current = states[position * rep_beam_width ..][0..lengths[position]];
        for (current, 0..) |state, slot| {
            insertRepBeamState(states, lengths, position + 1, .{
                .cost = state.cost + @as(u32, @intCast(fixedLiteralCost(input[position]))),
                .rep0 = state.rep0,
                .previous_position = @intCast(position),
                .previous_slot = @intCast(slot),
                .token = .{ .literal = input[position] },
            });

            for (matches[0..match_count]) |match| {
                extendRepBeamMatchZstd(states, lengths, position, slot, state, match);
            }
            const indexed_rep0 = match_count != 0 and matches[0].distance == state.rep0;
            if (can_match and state.rep0 <= position and !indexed_rep0) {
                const candidate = position - state.rep0;
                const length = repBeamMatchLength(input, candidate, position, @min(max_match_len, input.len - position), 4);
                if (length != 0) {
                    extendRepBeamMatchZstd(states, lengths, position, slot, state, .{ .length = @intCast(length), .distance = state.rep0 });
                }
            }
        }
    }

    return finishRepBeamPlan(scratch, allocator, input.len, states, lengths);
}

inline fn extendRepBeamMatchZstd(states: []RepBeamState, lengths: []u8, position: usize, slot: usize, state: RepBeamState, match: Token.Match) void {
    std.debug.assert(match.length >= 4);
    std.debug.assert(match.distance != 0 and match.distance <= position);
    const distance_cost: u32 = @intCast(if (match.distance == state.rep0) 1 else fixedDistanceSymbolCost(match.distance) + 4);
    const cost = state.cost + @as(u32, fixed_length_costs[match.length]) + distance_cost;
    insertRepBeamState(states, lengths, position + match.length, .{
        .cost = cost,
        .rep0 = match.distance,
        .previous_position = @intCast(position),
        .previous_slot = @intCast(slot),
        .token = .{ .match = match },
    });
}

inline fn repBeamMatchLength(input: []const u8, candidate: usize, position: usize, maximum: usize, minimum: usize) usize {
    const length = if (minimum >= 4) blk: {
        if (std.mem.readInt(u32, input[candidate..][0..4], .little) !=
            std.mem.readInt(u32, input[position..][0..4], .little)) return 0;
        // Avoid comparing the accepted prefix again in the vector extender.
        break :blk 4 + matchLength(input, candidate + 4, position + 4, maximum - 4);
    } else matchLength(input, candidate, position, maximum);
    return if (length >= minimum) length else 0;
}

inline fn extendRepBeamMatchKnownValid(states: []RepBeamState, lengths: []u8, options: GreedyOptions, position: usize, slot: usize, state: RepBeamState, match: Token.Match) void {
    // Both callers have already established the match-length bound and a
    // non-zero distance no greater than position. Do not repeat those checks
    // for every active state in the beam.
    std.debug.assert(match.length >= minMatch(options));
    std.debug.assert(match.distance != 0 and match.distance <= position);
    const distance_cost: u32 = @intCast(if (match.distance == state.rep0) 1 else fixedDistanceSymbolCost(match.distance) + options.new_distance_penalty_bits);
    const match_cost: u32 = @as(u32, fixed_length_costs[match.length]) + distance_cost;
    const cost = state.cost + match_cost;
    insertRepBeamState(states, lengths, position + match.length, .{
        .cost = cost,
        .rep0 = match.distance,
        .previous_position = @intCast(position),
        .previous_slot = @intCast(slot),
        .token = .{ .match = match },
    });
}

inline fn insertRepBeamState(states: []RepBeamState, lengths: []u8, position: usize, candidate: RepBeamState) void {
    const slots = states[position * rep_beam_width ..][0..rep_beam_width];
    const len = lengths[position];
    if (len == 0) {
        slots[0] = candidate;
        lengths[position] = 1;
        return;
    }
    if (slots[0].rep0 == candidate.rep0) {
        if (candidate.cost < slots[0].cost) slots[0] = candidate;
        return;
    }
    if (len == 1) {
        slots[1] = candidate;
        lengths[position] = 2;
        return;
    }
    if (slots[1].rep0 == candidate.rep0) {
        if (candidate.cost < slots[1].cost) slots[1] = candidate;
        return;
    }
    const replacement: usize = @intFromBool(slots[1].cost > slots[0].cost);
    // Preserve a distinct recent-offset history when its modeled cost is
    // within two bits of the current beam boundary. Zstd's actual offset FSE
    // coding can recover that tiny proxy deficit across later repcode runs.
    const replacement_cost = slots[replacement].cost;
    if (candidate.cost <= replacement_cost or candidate.cost - replacement_cost <= 2)
        slots[replacement] = candidate;
}

pub fn optimalPlanReuse(scratch: *OptimalScratch, allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !PlanStats {
    return optimalPlanReuseInternalProfiled(scratch, allocator, input, options, true, false, false, undefined, undefined, undefined);
}

pub fn optimalPlanReuseWithCostModel(
    scratch: *OptimalScratch,
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    model: OptimalCostModel,
) !PlanStats {
    try model.validate(options.window_len, input.len);
    return optimalPlanReuseInternalProfiled(scratch, allocator, input, options, false, false, true, undefined, undefined, model);
}

fn optimalPlanReuseInternal(
    scratch: *OptimalScratch,
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    comptime enable_prefix_bound: bool,
) !PlanStats {
    return optimalPlanReuseInternalProfiled(scratch, allocator, input, options, enable_prefix_bound, false, false, undefined, undefined, undefined);
}

pub fn optimalPlanAllocProfiled(allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions, io: std.Io, profile: *OptimalSearchProfile) !GreedyPlan {
    profile.* = .{ .input_bytes = input.len };
    const total_start = std.Io.Clock.awake.now(io);
    var scratch: OptimalScratch = .{};
    defer scratch.deinit(allocator);
    const stats = try optimalPlanReuseInternalProfiled(&scratch, allocator, input, options, true, true, false, io, profile, undefined);
    const tokens = try allocator.dupe(Token, scratch.tokens.items);
    profile.total_ns = elapsedNs(total_start, io);
    return .{ .tokens = tokens, .stats = stats };
}

pub fn optimalPlanReuseProfiled(scratch: *OptimalScratch, allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions, io: std.Io, profile: *OptimalSearchProfile) !PlanStats {
    profile.* = .{ .input_bytes = input.len };
    const total_start = std.Io.Clock.awake.now(io);
    const stats = try optimalPlanReuseInternalProfiled(scratch, allocator, input, options, true, true, false, io, profile, undefined);
    profile.total_ns = elapsedNs(total_start, io);
    return stats;
}

fn optimalPlanReuseInternalProfiled(
    scratch: *OptimalScratch,
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    comptime enable_prefix_bound: bool,
    comptime collect_profile: bool,
    comptime modeled: bool,
    io: if (collect_profile) std.Io else void,
    profile: if (collect_profile) *OptimalSearchProfile else void,
    model: if (modeled) OptimalCostModel else void,
) !PlanStats {
    const n = input.len;
    // A literal-only path costs at most nine bits per byte. This bound is far
    // above any addressable allocation on supported targets and keeps the
    // packed length-choice key's shift defined.
    if (comptime packed_optimal_length_choices)
        if (n > (std.math.maxInt(usize) >> optimal_length_bits) / 9) return error.InvalidBlockPlan;
    try scratch.costs.resize(allocator, n + 1);
    try scratch.steps.resize(allocator, n);
    scratch.tokens.clearRetainingCapacity();
    if (enable_prefix_bound and input.len <= optimal_compact_index_empty) {
        const index_start = if (comptime collect_profile) std.Io.Clock.awake.now(io) else {};
        try buildOptimalCompactHashIndex(
            allocator,
            input,
            &scratch.compact_head,
            &scratch.compact_prev,
            &scratch.index.head_initialized,
        );
        if (comptime collect_profile) {
            profile.index_ns = elapsedNs(index_start, io);
            profile.index_bytes = (scratch.compact_head.items.len + scratch.compact_prev.items.len) * @sizeOf(u32) + @sizeOf(@FieldType(HashIndex, "head_initialized"));
        }
        return optimalPlanReuseWithIndex(scratch, allocator, input, options, scratch.compact_prev.items, optimal_compact_index_empty, enable_prefix_bound, collect_profile, modeled, io, profile, model);
    }
    const index_start = if (comptime collect_profile) std.Io.Clock.awake.now(io) else {};
    try scratch.index.build(allocator, input);
    if (comptime collect_profile) {
        profile.index_ns = elapsedNs(index_start, io);
        profile.index_bytes = (scratch.index.head.items.len + scratch.index.prev.items.len) * @sizeOf(isize) + @sizeOf(@FieldType(HashIndex, "head_initialized"));
    }
    return optimalPlanReuseWithIndex(scratch, allocator, input, options, scratch.index.prev.items, @as(isize, -1), enable_prefix_bound, collect_profile, modeled, io, profile, model);
}

inline fn optimalPlanReuseWithIndex(
    scratch: *OptimalScratch,
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    prev: anytype,
    comptime empty: @TypeOf(prev[0]),
    comptime enable_prefix_bound: bool,
    comptime collect_profile: bool,
    comptime modeled: bool,
    io: if (collect_profile) std.Io else void,
    profile: if (collect_profile) *OptimalSearchProfile else void,
    model: if (modeled) OptimalCostModel else void,
) !PlanStats {
    const n = input.len;
    const costs = scratch.costs.items;
    const steps = scratch.steps.items;

    costs[n] = 0;
    var rev_i: usize = n;
    const minimum = minMatch(options);
    const candidate_limit = normalizedMaxCandidates(options);
    const distance_costs = if (comptime modeled) model.distance else &fixed_distance_costs;
    const search_start = if (comptime collect_profile) std.Io.Clock.awake.now(io) else {};

    while (rev_i > 0) {
        rev_i -= 1;
        if (comptime collect_profile) profile.positions += 1;
        costs[rev_i] = (if (comptime modeled) model.literal[input[rev_i]] else fixedLiteralCost(input[rev_i])) + costs[rev_i + 1];
        steps[rev_i] = .{ .literal = input[rev_i] };

        if (rev_i + minimum > n) continue;

        const max_len = @min(maxMatch(options), n - rev_i);
        var choices_built_through = minimum - 1;
        var chain_i = prev[rev_i];
        var checked: usize = 0;
        var candidates_seen: usize = 0;

        while (chain_i != empty and checked < options.max_chain) : (checked += 1) {
            if (comptime collect_profile) profile.chain_nodes += 1;
            const candidate: usize = @intCast(chain_i);
            std.debug.assert(candidate < rev_i);
            const distance = rev_i - candidate;
            if (distance == 0 or distance > options.window_len) break;
            if (minimum >= 4 and
                std.mem.readInt(u32, input[candidate..][0..4], .little) !=
                    std.mem.readInt(u32, input[rev_i..][0..4], .little))
            {
                if (comptime collect_profile) {
                    profile.prefix_rejections += 1;
                    const candidate_prefix = std.mem.readInt(u32, input[candidate..][0..4], .little);
                    const current_prefix = std.mem.readInt(u32, input[rev_i..][0..4], .little);
                    profile.prefix_mismatch_histogram[@ctz(candidate_prefix ^ current_prefix) / 8] += 1;
                }
                chain_i = prev[candidate];
                continue;
            }

            const distance_cost = distance_costs[distance];
            if (enable_prefix_bound and
                minimum == 4 and
                choices_built_through >= minimum and
                choices_built_through < max_len and
                input[candidate + choices_built_through] != input[rev_i + choices_built_through] and
                optimalLengthChoiceCost(scratch.index.best_length_choices[choices_built_through]) + distance_cost >= costs[rev_i])
            {
                if (comptime collect_profile) {
                    profile.bound_rejections += 1;
                    profile.bound_length_histogram[optimalBoundLengthBucket(choices_built_through)] += 1;
                    profile.bound_distance_cost_histogram[distance_cost - 5] += 1;
                    const slack = optimalLengthChoiceCost(scratch.index.best_length_choices[choices_built_through]) + distance_cost - costs[rev_i];
                    profile.bound_slack_histogram[@min(slack, profile.bound_slack_histogram.len - 1)] += 1;
                }
                candidates_seen += 1;
                if (candidates_seen >= candidate_limit) {
                    if (comptime collect_profile) profile.candidate_budget_stops += 1;
                    break;
                }
                chain_i = prev[candidate];
                continue;
            }

            if (comptime collect_profile) profile.match_length_calls += 1;
            const length = matchLength(input, candidate, rev_i, max_len);
            if (length >= minimum) {
                if (comptime collect_profile) {
                    const added_choices = length -| choices_built_through;
                    profile.valid_match_candidates += 1;
                    profile.length_choices_built += added_choices;
                    profile.length_extension_histogram[optimalLengthExtensionBucket(added_choices)] += 1;
                }
                if (comptime modeled) {
                    extendModeledOptimalLengthChoices(
                        costs,
                        rev_i,
                        minimum,
                        choices_built_through,
                        length,
                        model.length,
                        &scratch.index.best_length_choices,
                        &scratch.index.best_lengths,
                    );
                } else {
                    extendOptimalLengthChoices(
                        costs,
                        rev_i,
                        minimum,
                        choices_built_through,
                        length,
                        &scratch.index.best_length_choices,
                        &scratch.index.best_lengths,
                    );
                }
                choices_built_through = @max(choices_built_through, length);
                const choice = scratch.index.best_length_choices[length];
                const cost = optimalLengthChoiceCost(choice) + distance_cost;
                if (cost < costs[rev_i]) {
                    costs[rev_i] = cost;
                    steps[rev_i] = .{ .match = .{ .length = optimalLengthChoiceLength(choice, &scratch.index.best_lengths, length), .distance = @intCast(distance) } };
                }
                candidates_seen += 1;
                if (length == max_len) break;
                if (length >= options.nice_len and candidates_seen >= candidate_limit) {
                    if (comptime collect_profile) profile.candidate_budget_stops += 1;
                    break;
                }
                if (candidates_seen >= candidate_limit) {
                    if (comptime collect_profile) profile.candidate_budget_stops += 1;
                    break;
                }
            }
            chain_i = prev[candidate];
        }
    }

    if (comptime collect_profile) profile.search_ns = elapsedNs(search_start, io);
    const reconstruct_start = if (comptime collect_profile) std.Io.Clock.awake.now(io) else {};
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
    if (comptime collect_profile) profile.reconstruct_ns = elapsedNs(reconstruct_start, io);
    return stats;
}

fn elapsedNs(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn optimalBoundLengthBucket(length: usize) usize {
    std.debug.assert(length >= 4 and length <= max_match_len);
    return if (length < 8) 0 else if (length < 16) 1 else if (length < 32) 2 else if (length < 64) 3 else if (length < 128) 4 else 5;
}

fn optimalLengthExtensionBucket(added_choices: usize) usize {
    return if (added_choices == 0) 0 else if (added_choices == 1) 1 else if (added_choices < 4) 2 else if (added_choices < 8) 3 else if (added_choices < 16) 4 else if (added_choices < 32) 5 else if (added_choices < 64) 6 else if (added_choices < 128) 7 else 8;
}

test "optimal length extension buckets cover exact boundaries" {
    const cases = [_][2]usize{
        .{ 0, 0 },
        .{ 1, 1 },
        .{ 2, 2 },
        .{ 3, 2 },
        .{ 4, 3 },
        .{ 7, 3 },
        .{ 8, 4 },
        .{ 15, 4 },
        .{ 16, 5 },
        .{ 31, 5 },
        .{ 32, 6 },
        .{ 63, 6 },
        .{ 64, 7 },
        .{ 127, 7 },
        .{ 128, 8 },
        .{ 256, 8 },
    };
    for (cases) |case| try std.testing.expectEqual(case[1], optimalLengthExtensionBucket(case[0]));
}

fn extendOptimalLengthChoices(
    costs: []const usize,
    position: usize,
    minimum: usize,
    built_through: usize,
    maximum: usize,
    best_choices: *[max_match_len + 1]usize,
    best_lengths: *[max_match_len + 1]u16,
) void {
    if (maximum <= built_through) return;
    var best_choice = if (built_through >= minimum) best_choices[built_through] else std.math.maxInt(usize);
    var best_length: u16 = if (comptime packed_optimal_length_choices) 0 else if (built_through >= minimum) best_lengths[built_through] else 0;
    var length = @max(minimum, built_through + 1);
    while (length <= maximum) : (length += 1) {
        const cost = fixed_length_costs[length] + costs[position + length];
        if (comptime packed_optimal_length_choices) {
            const choice = optimalLengthChoice(cost, length);
            // The low bits rank longer lengths first, so one unsigned
            // comparison preserves minimum-cost / longest-on-tie ordering.
            if (choice < best_choice) best_choice = choice;
        } else if (cost < best_choice or (cost == best_choice and length > best_length)) {
            best_choice = cost;
            best_length = @intCast(length);
        }
        best_choices[length] = best_choice;
        if (comptime !packed_optimal_length_choices) best_lengths[length] = best_length;
    }
}

fn extendModeledOptimalLengthChoices(
    costs: []const usize,
    position: usize,
    minimum: usize,
    built_through: usize,
    maximum: usize,
    length_costs: *const [max_match_len + 1]u16,
    best_choices: *[max_match_len + 1]usize,
    best_lengths: *[max_match_len + 1]u16,
) void {
    if (maximum <= built_through) return;
    var best_choice = if (built_through >= minimum) best_choices[built_through] else std.math.maxInt(usize);
    var best_length: u16 = if (comptime packed_optimal_length_choices) 0 else if (built_through >= minimum) best_lengths[built_through] else 0;
    var length = @max(minimum, built_through + 1);
    while (length <= maximum) : (length += 1) {
        const cost = @as(usize, length_costs[length]) + costs[position + length];
        if (comptime packed_optimal_length_choices) {
            const choice = optimalLengthChoice(cost, length);
            if (choice < best_choice) best_choice = choice;
        } else if (cost < best_choice or (cost == best_choice and length > best_length)) {
            best_choice = cost;
            best_length = @intCast(length);
        }
        best_choices[length] = best_choice;
        if (comptime !packed_optimal_length_choices) best_lengths[length] = best_length;
    }
}

const optimal_length_bits = 9;
const optimal_length_mask: usize = (@as(usize, 1) << optimal_length_bits) - 1;

inline fn optimalLengthChoice(cost: usize, length: usize) usize {
    comptime std.debug.assert(packed_optimal_length_choices);
    std.debug.assert(length <= max_match_len);
    std.debug.assert(cost <= std.math.maxInt(usize) >> optimal_length_bits);
    return (cost << optimal_length_bits) | (max_match_len - length);
}

inline fn optimalLengthChoiceCost(choice: usize) usize {
    return if (comptime packed_optimal_length_choices) choice >> optimal_length_bits else choice;
}

inline fn optimalLengthChoiceLength(choice: usize, best_lengths: *const [max_match_len + 1]u16, index: usize) u16 {
    return if (comptime packed_optimal_length_choices)
        @intCast(max_match_len - (choice & optimal_length_mask))
    else
        best_lengths[index];
}

test "optimal length prefix choices match descending reference" {
    var suffix_costs: [max_match_len + 17]usize = undefined;
    var state: u32 = 0x9e37_79b9;
    for (0..64) |case_index| {
        for (&suffix_costs) |*cost| {
            state = state *% 1_664_525 +% 1_013_904_223;
            cost.* = (state >> 16) % 257;
        }
        const position = case_index % 17;
        const minimum: usize = 3 + case_index % 2;
        var best_choices: [max_match_len + 1]usize = undefined;
        var best_lengths: [max_match_len + 1]u16 = undefined;
        extendOptimalLengthChoices(&suffix_costs, position, minimum, minimum - 1, 37, &best_choices, &best_lengths);
        extendOptimalLengthChoices(&suffix_costs, position, minimum, 37, 131, &best_choices, &best_lengths);
        extendOptimalLengthChoices(&suffix_costs, position, minimum, 131, max_match_len, &best_choices, &best_lengths);
        for (minimum..max_match_len + 1) |maximum| {
            var expected_cost: usize = std.math.maxInt(usize);
            var expected_length: usize = 0;
            var length = maximum;
            while (length >= minimum) : (length -= 1) {
                const cost = fixedLengthSymbolCost(length) + suffix_costs[position + length];
                if (cost < expected_cost) {
                    expected_cost = cost;
                    expected_length = length;
                }
            }
            try std.testing.expectEqual(expected_cost, optimalLengthChoiceCost(best_choices[maximum]));
            try std.testing.expectEqual(@as(u16, @intCast(expected_length)), optimalLengthChoiceLength(best_choices[maximum], &best_lengths, maximum));
        }
    }

    var tied_costs: [max_match_len + 1]usize = @splat(0);
    for (min_match_len..max_match_len + 1) |length|
        tied_costs[length] = 20 - fixed_length_costs[length];
    var tied_choices: [max_match_len + 1]usize = undefined;
    var tied_lengths: [max_match_len + 1]u16 = undefined;
    extendOptimalLengthChoices(&tied_costs, 0, min_match_len, min_match_len - 1, max_match_len, &tied_choices, &tied_lengths);
    for (min_match_len..max_match_len + 1) |maximum| {
        try std.testing.expectEqual(@as(usize, 20), optimalLengthChoiceCost(tied_choices[maximum]));
        try std.testing.expectEqual(@as(u16, @intCast(maximum)), optimalLengthChoiceLength(tied_choices[maximum], &tied_lengths, maximum));
    }
}

test "repeat beam keeps stable distance across local length gain" {
    var input: [32 * 1024]u8 = undefined;
    var random_state: u32 = 0xfeed_beef;
    for (&input, 0..) |*byte, index| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(random_state >> 16);
    }
    const plan = try optimalRepBeamPlanAlloc(std.testing.allocator, &input, .{
        .window_len = input.len,
        .max_chain = 128,
        .nice_len = 258,
        .max_candidates = 8,
        .min_match = 4,
        .max_match = max_match_len,
        .min_savings_bits = 0,
        .new_distance_penalty_bits = 4,
        .lazy_min_gain = 1,
    });
    defer plan.deinit(std.testing.allocator);

    var match_count: usize = 0;
    for (plan.tokens) |token| switch (token) {
        .literal => {},
        .match => |match| {
            try std.testing.expectEqual(@as(u16, 256), match.distance);
            match_count += 1;
        },
    };
    try std.testing.expectEqual(@as(usize, 508), match_count);
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
    const literal_min_cost = minimum * 8;
    const match_cost = fixedLengthSymbolCost(minimum) + distance_cost;
    // Across the legal match range, each additional byte adds eight literal
    // bits while the fixed length-symbol cost only changes by one at its
    // boundaries (and drops at length 258). Therefore the shortest permitted
    // match is the unique worst case for this lower-bound proof.
    return match_cost <= literal_min_cost and
        options.min_savings_bits <= literal_min_cost - match_cost;
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

fn fixedLengthCostTable() [max_match_len + 1]u8 {
    var table: [max_match_len + 1]u8 = @splat(0);
    for (min_match_len..max_match_len + 1) |length| {
        table[length] = @intCast(fixedLengthSymbolCost(length));
    }
    return table;
}

const fixed_length_costs = fixedLengthCostTable();

test "compile-time fixed length costs match scalar range" {
    for (min_match_len..max_match_len + 1) |length| {
        try std.testing.expectEqual(@as(u8, @intCast(fixedLengthSymbolCost(length))), fixed_length_costs[length]);
    }
}

test "rep beam keeps near-cost alternate recent-offset state" {
    var states: [6]RepBeamState = undefined;
    var lengths: [3]u8 = @splat(0);
    insertRepBeamState(&states, &lengths, 1, .{ .cost = 10, .rep0 = 4 });
    insertRepBeamState(&states, &lengths, 1, .{ .cost = 11, .rep0 = 8 });
    insertRepBeamState(&states, &lengths, 1, .{ .cost = 12, .rep0 = 16 });
    try std.testing.expectEqual(@as(u8, 2), lengths[1]);
    try std.testing.expectEqual(@as(u16, 16), states[rep_beam_width + 1].rep0);
    try std.testing.expectEqual(@as(u32, 12), states[rep_beam_width + 1].cost);
}

test "rep beam known-valid transition matches guarded reference" {
    const Reference = struct {
        fn extend(states: []RepBeamState, lengths: []u8, options: GreedyOptions, position: usize, slot: usize, state: RepBeamState, match: Token.Match) void {
            if (match.length < minMatch(options) or match.distance == 0 or match.distance > position) return;
            const distance_cost: u32 = @intCast(if (match.distance == state.rep0) 1 else fixedDistanceSymbolCost(match.distance) + options.new_distance_penalty_bits);
            insertRepBeamState(states, lengths, position + match.length, .{
                .cost = state.cost + @as(u32, fixed_length_costs[match.length]) + distance_cost,
                .rep0 = match.distance,
                .previous_position = @intCast(position),
                .previous_slot = @intCast(slot),
                .token = .{ .match = match },
            });
        }
    };

    for ([_]struct { minimum: usize, state_rep0: u16, match: Token.Match }{
        .{ .minimum = 3, .state_rep0 = 1, .match = .{ .length = 3, .distance = 1 } },
        .{ .minimum = 4, .state_rep0 = 4, .match = .{ .length = 4, .distance = 8 } },
    }) |case| {
        const options: GreedyOptions = .{ .min_match = case.minimum, .new_distance_penalty_bits = 4 };
        const state: RepBeamState = .{ .cost = 37, .rep0 = case.state_rep0 };
        var expected_states: [32]RepBeamState = @splat(.{});
        var expected_lengths: [16]u8 = @splat(0);
        Reference.extend(&expected_states, &expected_lengths, options, 8, 1, state, case.match);
        var actual_states: [32]RepBeamState = @splat(.{});
        var actual_lengths: [16]u8 = @splat(0);
        extendRepBeamMatchKnownValid(&actual_states, &actual_lengths, options, 8, 1, state, case.match);
        try std.testing.expectEqualSlices(u8, &expected_lengths, &actual_lengths);
        for (expected_states, actual_states) |expected, actual| try std.testing.expect(std.meta.eql(expected, actual));
    }
}

test "rep beam recent-offset prefix guard matches scalar acceptance" {
    var input: [674]u8 = undefined;
    var state: u32 = 0x510e_527f;
    for (&input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[337..][0..258], input[0..258]);
    for (0..259) |mismatch| {
        var probe = input;
        if (mismatch < 258) probe[337 + mismatch] = probe[mismatch] ^ 0xff;
        for ([_]usize{ 3, 4 }) |minimum| {
            const scalar = matchLength(&probe, 0, 337, 258);
            const expected = if (scalar >= minimum) scalar else 0;
            try std.testing.expectEqual(expected, repBeamMatchLength(&probe, 0, 337, 258, minimum));
        }
    }
}

test "rep beam materializes the initial recent offset" {
    const input = "aaaa";
    const plan = try optimalRepBeamPlanAlloc(std.testing.allocator, input, .{
        .max_chain = 0,
        .min_match = 3,
    });
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(Token, &.{
        .{ .literal = 'a' },
        .{ .match = .{ .length = 3, .distance = 1 } },
    }, plan.tokens);
}

test "rep beam reusable scratch preserves tokens and capacity" {
    const input = ("abcdefgh-abcdefgh-" ** 64) ++ ("0123456789abcdef" ** 32);
    const options: GreedyOptions = .{ .min_match = 4, .new_distance_penalty_bits = 4 };
    const reference = try optimalRepBeamPlanAlloc(std.testing.allocator, input, options);
    defer reference.deinit(std.testing.allocator);

    var scratch: RepBeamScratch = .{};
    defer scratch.deinit(std.testing.allocator);
    const first_stats = try optimalRepBeamPlanReuse(&scratch, std.testing.allocator, input, options);
    try std.testing.expectEqual(reference.stats, first_stats);
    try std.testing.expectEqualSlices(Token, reference.tokens, scratch.reversed.items);
    const states_capacity = scratch.states.capacity;
    const lengths_capacity = scratch.lengths.capacity;
    const tokens_capacity = scratch.reversed.capacity;

    const second_stats = try optimalRepBeamPlanReuse(&scratch, std.testing.allocator, input, options);
    try std.testing.expectEqual(first_stats, second_stats);
    try std.testing.expectEqualSlices(Token, reference.tokens, scratch.reversed.items);
    try std.testing.expectEqual(states_capacity, scratch.states.capacity);
    try std.testing.expectEqual(lengths_capacity, scratch.lengths.capacity);
    try std.testing.expectEqual(tokens_capacity, scratch.reversed.capacity);
}

test "Zstd-specialized rep beam matches generic plans" {
    for ([_][]const u8{ "a", "aa", "aaa", "aaaa", "abcabc", "aaaaaaaa" }) |input| {
        const options: GreedyOptions = .{
            .window_len = @min(input.len, default_window_len),
            .max_chain = 128,
            .nice_len = 258,
            .max_candidates = 8,
            .min_match = 4,
            .max_match = max_match_len,
            .new_distance_penalty_bits = 4,
            .lazy_min_gain = 1,
        };
        var generic: RepBeamScratch = .{};
        defer generic.deinit(std.testing.allocator);
        const generic_stats = try optimalRepBeamPlanReuse(&generic, std.testing.allocator, input, options);
        var specialized: RepBeamScratch = .{};
        defer specialized.deinit(std.testing.allocator);
        const specialized_stats = try optimalRepBeamPlanZstdReuse(&specialized, std.testing.allocator, input);
        try std.testing.expectEqual(generic_stats, specialized_stats);
        try std.testing.expectEqualSlices(Token, generic.reversed.items, specialized.reversed.items);
    }

    var payload: [8192]u8 = undefined;
    for (0..16) |seed| {
        var random_state: u32 = @truncate(0xa409_3822 +% seed *% 0x0100_0193);
        for (&payload, 0..) |*byte, position| {
            random_state = random_state *% 1_664_525 +% 1_013_904_223;
            byte.* = switch (seed & 3) {
                0 => @truncate(position * 17 + seed * 13),
                1 => if (position % 64 < 52) @intCast('a' + (position + seed) % 23) else @truncate(random_state >> 24),
                2 => @truncate((random_state >> 16) ^ (position / 31)),
                else => @truncate((position * 37 + (position / 7) * 13) ^ (position >> 3)),
            };
        }
        @memcpy(payload[4096..5120], payload[1024..2048]);
        @memcpy(payload[7168..7680], payload[2560..3072]);
        const options: GreedyOptions = .{
            .window_len = @min(payload.len, default_window_len),
            .max_chain = 128,
            .nice_len = 258,
            .max_candidates = 8,
            .min_match = 4,
            .max_match = max_match_len,
            .new_distance_penalty_bits = 4,
            .lazy_min_gain = 1,
        };

        var generic: RepBeamScratch = .{};
        defer generic.deinit(std.testing.allocator);
        const generic_stats = try optimalRepBeamPlanReuse(&generic, std.testing.allocator, &payload, options);
        var specialized: RepBeamScratch = .{};
        defer specialized.deinit(std.testing.allocator);
        const specialized_stats = try optimalRepBeamPlanZstdReuse(&specialized, std.testing.allocator, &payload);
        try std.testing.expectEqual(generic_stats, specialized_stats);
        try std.testing.expectEqualSlices(Token, generic.reversed.items, specialized.reversed.items);
    }
}

test "rep beam compact index matches reference beyond u16 positions" {
    var input: [rep_beam_input_max]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @truncate(i * 37 + i / 251);
    const options: GreedyOptions = .{ .window_len = default_window_len, .min_match = 4 };
    var reference: HashIndex = .{};
    defer reference.deinit(std.testing.allocator);
    try reference.buildWithHeadLen(std.testing.allocator, &input, 4096);
    var compact: RepBeamIndex = .{};
    defer compact.deinit(std.testing.allocator);
    try compact.build(std.testing.allocator, &input);
    var expected: [rep_beam_match_candidates]Token.Match = undefined;
    var actual: [rep_beam_match_candidates]Token.Match = undefined;
    for ([_]usize{ 1, 1024, 32 * 1024, input.len - 4 }) |position| {
        const expected_len = try reference.matchesAt(&input, position, options, &expected);
        const actual_len = try compact.matchesAt(&input, position, options, &actual);
        try std.testing.expectEqual(expected_len, actual_len);
        try std.testing.expectEqualSlices(Token.Match, expected[0..expected_len], actual[0..actual_len]);
    }
}

test "Zstd rep beam prefix filter preserves scalar compact-index matches" {
    const Reference = struct {
        fn matchesAt(
            index: *const RepBeamIndex,
            input: []const u8,
            position: usize,
            out: []Token.Match,
        ) usize {
            if (position + 4 > input.len or out.len == 0) return 0;
            var candidate_i = index.prev.items[position];
            var checked: usize = 0;
            var count: usize = 0;
            const maximum = @min(max_match_len, input.len - position);
            const window_len = @min(input.len, default_window_len);
            while (candidate_i != rep_beam_index_empty and checked < 128 and count < out.len) : (checked += 1) {
                const candidate: usize = candidate_i;
                const distance = position - candidate;
                if (distance == 0 or distance > window_len) break;
                const length = matchLength(input, candidate, position, maximum);
                if (length >= 4) {
                    out[count] = .{ .length = @intCast(length), .distance = @intCast(distance) };
                    count += 1;
                }
                candidate_i = index.prev.items[candidate];
            }
            return count;
        }
    };

    var input: [8192]u8 = undefined;
    for (0..8) |seed| {
        var random_state: u32 = @truncate(0x9e37_79b9 +% seed *% 0x0100_0193);
        for (&input, 0..) |*byte, position| {
            random_state = random_state *% 1_664_525 +% 1_013_904_223;
            byte.* = if (position % 64 < 48)
                @truncate(position * 17 + seed * 13)
            else
                @truncate(random_state >> 16);
        }
        if (seed & 1 == 0)
            @memcpy(input[input.len / 2 ..], input[0 .. input.len / 2]);

        var index: RepBeamIndex = .{};
        defer index.deinit(std.testing.allocator);
        try index.build(std.testing.allocator, &input);
        for (0..input.len - 3) |position| {
            var expected: [rep_beam_match_candidates]Token.Match = undefined;
            var actual: [rep_beam_match_candidates]Token.Match = undefined;
            const expected_len = Reference.matchesAt(&index, &input, position, &expected);
            const actual_len = index.matchesAtZstd(&input, position, &actual);
            try std.testing.expectEqual(expected_len, actual_len);
            try std.testing.expectEqualSlices(Token.Match, expected[0..expected_len], actual[0..actual_len]);
        }
    }
}

test "rep beam compact index initializes the four-byte tail" {
    var index: RepBeamIndex = .{};
    defer index.deinit(std.testing.allocator);
    try index.prev.resize(std.testing.allocator, 8);
    @memset(index.prev.items, 0);
    try index.build(std.testing.allocator, "abcabc");
    try std.testing.expectEqualSlices(u16, &.{
        rep_beam_index_empty,
        rep_beam_index_empty,
        rep_beam_index_empty,
    }, index.prev.items[3..]);
    var matches: [rep_beam_match_candidates]Token.Match = undefined;
    try std.testing.expectEqual(
        @as(usize, 0),
        try index.matchesAt("abcabc", 3, .{ .min_match = 3 }, &matches),
    );
}

test "rep beam emits literal tail shorter than minimum match" {
    const input = "abcdabcdxyz";
    const plan = try optimalRepBeamPlanAlloc(std.testing.allocator, input, .{ .min_match = 4 });
    defer plan.deinit(std.testing.allocator);
    const replayed = try replayAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
    try std.testing.expectEqual(@as(usize, 7), plan.stats.literals);
    try std.testing.expectEqual(@as(usize, 1), plan.stats.matches);
}

test "rep beam deduplicates indexed recent offset matches" {
    const input = "abcdefghabcdefghabcdefgh";
    var scratch: RepBeamScratch = .{};
    defer scratch.deinit(std.testing.allocator);
    const stats = try optimalRepBeamPlanReuse(&scratch, std.testing.allocator, input, .{ .min_match = 4 });
    try std.testing.expect(stats.matches >= 1);
    try std.testing.expect(stats.matched_bytes >= 8);
    const replayed = try replayAlloc(std.testing.allocator, scratch.reversed.items);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
}

fn fixedDistanceSymbolCost(distance: usize) usize {
    std.debug.assert(distance >= 1 and distance <= max_window_len);
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

/// Internal companion for format encoders that can derive metadata while the
/// hash parser emits tokens. The observer must provide `recordToken(Token)`;
/// it does not own the returned plan and is called only after a token append
/// succeeds.
pub fn hashGreedyPlanAutoAllocObserved(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    observer: anytype,
) !GreedyPlan {
    return if (minMatch(options) >= 4)
        hashGreedyPlanAllocWithAnchorObserved(allocator, input, options, .four, observer)
    else
        hashGreedyPlanAllocWithAnchorObserved(allocator, input, options, .three, observer);
}

pub fn hashGreedyPlanAutoLazyHeadAllocObserved(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    observer: anytype,
) !GreedyPlan {
    return if (minMatch(options) >= 4)
        hashGreedyPlanLazyHeadAllocWithAnchorObserved(allocator, input, options, .four, observer)
    else
        hashGreedyPlanLazyHeadAllocWithAnchorObserved(allocator, input, options, .three, observer);
}

fn hashGreedyPlanAllocWithAnchor(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    comptime anchor: HashAnchor,
) !GreedyPlan {
    // DEFLATE positions are normally far below 2 GiB. Compact indices halve
    // the hot head/ring footprint on 64-bit targets while retaining an isize
    // fallback for callers that hand the generic planner a larger slice.
    if (hashPositionFitsI32(input.len)) {
        return hashGreedyPlanAllocWithPosition(i32, allocator, input, options, anchor);
    }
    return hashGreedyPlanAllocWithPosition(isize, allocator, input, options, anchor);
}

fn hashGreedyPlanAllocWithAnchorObserved(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    comptime anchor: HashAnchor,
    observer: anytype,
) !GreedyPlan {
    if (hashPositionFitsI32(input.len)) {
        return hashGreedyPlanAllocWithPositionObserved(i32, allocator, input, options, anchor, observer);
    }
    return hashGreedyPlanAllocWithPositionObserved(isize, allocator, input, options, anchor, observer);
}

fn hashGreedyPlanLazyHeadAllocWithAnchorObserved(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    comptime anchor: HashAnchor,
    observer: anytype,
) !GreedyPlan {
    if (input.len > 64 * 1024) {
        return hashGreedyPlanAllocWithAnchorObserved(allocator, input, options, anchor, observer);
    }
    // With at least a three-byte anchor, a 64 KiB input can only insert
    // positions through 65533. Reserve maxInt(u16) as the empty-chain marker
    // and halve both one-shot hash tables without changing reachable matches.
    const head = try allocator.alloc(u16, hash_head_table_size);
    defer allocator.free(head);
    var initialized: [hash_head_init_words]u64 = @splat(0);
    const prev_len = compactLazyPrevTableLen(input.len, options.window_len);
    const prev = try allocator.alloc(u16, prev_len);
    defer allocator.free(prev);
    if (prev_len < input.len) {
        return @call(
            .never_inline,
            hashGreedyPlanWithTablesObserved,
            .{ allocator, input, options, head, prev, true, true, &initialized, anchor, observer },
        );
    }
    return hashGreedyPlanWithTablesObserved(
        allocator,
        input,
        options,
        head,
        prev,
        false,
        true,
        &initialized,
        anchor,
        observer,
    );
}

fn compactLazyPrevTableLen(input_len: usize, window_len: usize) usize {
    if (window_len != 0 and
        window_len <= default_window_len and
        input_len > window_len and
        std.math.isPowerOfTwo(window_len))
    {
        return window_len;
    }
    return input_len;
}

fn hashPositionFitsI32(input_len: usize) bool {
    return input_len <= std.math.maxInt(i32);
}

fn hashPositionFitsU32(input_len: usize) bool {
    return input_len <= std.math.maxInt(u32);
}

fn hashGreedyPlanAllocWithPosition(
    comptime Position: type,
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    comptime anchor: HashAnchor,
) !GreedyPlan {
    const head = try allocator.alloc(Position, hash_head_table_size);
    defer allocator.free(head);
    @memset(head, -1);
    const prev_len = hashPrevTableLen(input.len, options.window_len);
    const ring = prev_len < input.len;
    const prev = try allocator.alloc(Position, prev_len);
    defer allocator.free(prev);
    if (ring) {
        // Keep the ring-specialized planner out of encodeZlibBestAlloc's
        // caller body. Inlining both predecessor layouts enlarged the function
        // enough to regress the unrelated stored fast path on PNG RGB rows.
        return @call(
            .never_inline,
            hashGreedyPlanWithTables,
            .{ allocator, input, options, head, prev, true, false, {}, anchor },
        );
    }
    return hashGreedyPlanWithTables(
        allocator,
        input,
        options,
        head,
        prev,
        false,
        false,
        {},
        anchor,
    );
}

fn hashGreedyPlanAllocWithPositionObserved(
    comptime Position: type,
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    comptime anchor: HashAnchor,
    observer: anytype,
) !GreedyPlan {
    const head = try allocator.alloc(Position, hash_head_table_size);
    defer allocator.free(head);
    @memset(head, -1);
    const prev_len = hashPrevTableLen(input.len, options.window_len);
    const ring = prev_len < input.len;
    const prev = try allocator.alloc(Position, prev_len);
    defer allocator.free(prev);
    if (ring) {
        return @call(
            .never_inline,
            hashGreedyPlanWithTablesObserved,
            .{ allocator, input, options, head, prev, true, false, {}, anchor, observer },
        );
    }
    return hashGreedyPlanWithTablesObserved(
        allocator,
        input,
        options,
        head,
        prev,
        false,
        false,
        {},
        anchor,
        observer,
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
        .three => hashGreedyPlanWithTablesReuse(tokens, allocator, input, options, &head, prev_stack[0..input.len], false, {}, .three),
        .four => hashGreedyPlanWithTablesReuse(tokens, allocator, input, options, &head, prev_stack[0..input.len], false, {}, .four),
    };
}

/// Reusable-table counterpart for callers that repeatedly encode small blocks.
/// The head array stays allocated and uninitialized; a compact bitmap marks
/// buckets written during the current plan, avoiding a 32 KiB clear per call.
pub fn hashGreedyPlanAutoTinyScratchReuse(tokens: *std.ArrayList(Token), scratch: *TinyGreedyScratch, allocator: std.mem.Allocator, input: []const u8, options: GreedyOptions) !PlanStats {
    const anchor: HashAnchor = if (minMatch(options) >= 4) .four else .three;
    if (input.len > 32 * 1024) return error.InvalidBlockPlan;
    tokens.clearRetainingCapacity();
    try scratch.prev.resize(allocator, input.len);
    @memset(&scratch.head_initialized, 0);
    return switch (anchor) {
        .three => hashGreedyPlanWithTablesReuse(tokens, allocator, input, options, &scratch.head, scratch.prev.items, true, &scratch.head_initialized, .three),
        .four => hashGreedyPlanWithTablesReuse(tokens, allocator, input, options, &scratch.head, scratch.prev.items, true, &scratch.head_initialized, .four),
    };
}

fn hashGreedyPlanWithTablesReuse(
    tokens: *std.ArrayList(Token),
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    head: anytype,
    prev: anytype,
    comptime lazy_head: bool,
    initialized: HashHeadInit(lazy_head, @TypeOf(head)),
    comptime anchor: HashAnchor,
) !PlanStats {
    var stats = PlanStats{};
    const accept_all_matches = acceptsEveryHashMatch(options);
    const search_limits = hashSearchLimits(options);
    var pos: usize = 0;
    while (pos < input.len) {
        const search = findBestHashMatchWithLayoutAndHashLimits(input, pos, search_limits, head, prev, false, lazy_head, initialized, anchor);
        const best = search.best;
        const accepted = if (accept_all_matches) best.length != 0 else acceptMatch(input, pos, best.length, best.distance, options);
        if (accepted) {
            try appendToken(tokens, allocator, .{ .match = .{ .length = @intCast(best.length), .distance = @intCast(best.distance) } });
            stats.matches += 1;
            stats.matched_bytes += best.length;
            const end = @min(input.len, pos + best.length);
            insertKnownHashWithLayout(pos, search.hash.?, head, prev, false, lazy_head, initialized);
            const tail_start = if (end > pos + 4) end - 4 else pos + 1;
            pos += 1;
            if (pos < tail_start) pos = tail_start;
            while (pos < end) : (pos += 1) insertHashWithLayout(input, pos, head, prev, false, lazy_head, initialized, anchor);
        } else {
            try appendToken(tokens, allocator, .{ .literal = input[pos] });
            stats.literals += 1;
            if (search.hash) |hash| insertKnownHashWithLayout(pos, hash, head, prev, false, lazy_head, initialized);
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

    if (comptime anchor == .three) {
        // Brotli's three-byte tiny path shares the reusable parser's exact
        // 32 KiB position bound. Compact signed indices retain the -1 sentinel,
        // while lazy initialization avoids clearing the full head table. Keep
        // the four-byte Zstd path unchanged: its primary blocks were neutral
        // to slightly slower with the extra bitmap checks.
        var head: [tiny_hash_head_table_size]i16 = undefined;
        var initialized: [tiny_hash_head_init_words]u64 = @splat(0);
        var prev_stack: [32 * 1024]i16 = undefined;
        return hashGreedyPlanWithTables(
            allocator,
            input,
            options,
            &head,
            prev_stack[0..input.len],
            false,
            true,
            &initialized,
            anchor,
        );
    }
    var head: [4096]isize = @splat(-1);
    var prev_stack: [32 * 1024]isize = undefined;
    return hashGreedyPlanWithTables(allocator, input, options, &head, prev_stack[0..input.len], false, false, {}, anchor);
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

fn hashPrevIndex(position: usize, prev: anytype, comptime ring: bool) usize {
    return if (ring) position & (prev.len - 1) else position;
}

fn HashHeadInit(comptime lazy_head: bool, comptime Head: type) type {
    // Keep this mode as an explicit comptime parameter on the hot parser
    // rather than wrapping entries/state in a generic object. Both designs are
    // semantically equivalent, but the wrapper increased register pressure and
    // regressed the measured RGB/RGBA adaptive paths by about 2.5%. The direct
    // form still shares one parser state machine and compiles the full-clear
    // reference path without any bitmap branches.
    if (!lazy_head) return void;
    const pointer = @typeInfo(Head).pointer;
    const head_len = switch (pointer.size) {
        .one => @typeInfo(pointer.child).array.len,
        .slice => hash_head_table_size,
        else => unreachable,
    };
    return *[head_len / 64]u64;
}

fn hashGreedyPlanWithTables(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    head: anytype,
    prev: anytype,
    comptime ring: bool,
    comptime lazy_head: bool,
    initialized: HashHeadInit(lazy_head, @TypeOf(head)),
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
    const search_limits = hashSearchLimits(options);

    var pos: usize = 0;
    while (pos < input.len) {
        const search = findBestHashMatchWithLayoutAndHashLimits(
            input,
            pos,
            search_limits,
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

fn hashGreedyPlanWithTablesObserved(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: GreedyOptions,
    head: anytype,
    prev: anytype,
    comptime ring: bool,
    comptime lazy_head: bool,
    initialized: HashHeadInit(lazy_head, @TypeOf(head)),
    comptime anchor: HashAnchor,
    observer: anytype,
) !GreedyPlan {
    var tokens = try initTokenList(allocator, input.len);
    errdefer tokens.deinit(allocator);
    var stats = PlanStats{};
    const accept_all_matches = acceptsEveryHashMatch(options);
    const search_limits = hashSearchLimits(options);

    var pos: usize = 0;
    while (pos < input.len) {
        const search = findBestHashMatchWithLayoutAndHashLimits(
            input,
            pos,
            search_limits,
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
            const token: Token = .{ .match = .{ .length = @intCast(best.length), .distance = @intCast(best.distance) } };
            try appendToken(&tokens, allocator, token);
            observer.recordToken(token);
            stats.matches += 1;
            stats.matched_bytes += best.length;
            const end = @min(input.len, pos + best.length);
            insertKnownHashWithLayout(pos, search.hash.?, head, prev, ring, lazy_head, initialized);
            const tail_start = if (end > pos + 4) end - 4 else pos + 1;
            pos += 1;
            if (pos < tail_start) pos = tail_start;
            while (pos < end) : (pos += 1) {
                insertHashWithLayout(input, pos, head, prev, ring, lazy_head, initialized, anchor);
            }
        } else {
            const token: Token = .{ .literal = input[pos] };
            try appendToken(&tokens, allocator, token);
            observer.recordToken(token);
            stats.literals += 1;
            if (search.hash) |hash| {
                insertKnownHashWithLayout(pos, hash, head, prev, ring, lazy_head, initialized);
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
    head: anytype,
    prev: anytype,
    comptime ring: bool,
    comptime lazy_head: bool,
    initialized: HashHeadInit(lazy_head, @TypeOf(head)),
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
    head: anytype,
    prev: anytype,
    comptime ring: bool,
    comptime lazy_head: bool,
    initialized: HashHeadInit(lazy_head, @TypeOf(head)),
    comptime anchor: HashAnchor,
) HashMatchSearch {
    return findBestHashMatchWithLayoutAndHashLimits(
        input,
        pos,
        hashSearchLimits(options),
        head,
        prev,
        ring,
        lazy_head,
        initialized,
        anchor,
    );
}

const HashSearchLimits = struct {
    window_len: usize,
    max_chain: usize,
    nice_len: usize,
    minimum: usize,
    maximum: usize,
    max_walks: usize,
};

fn hashSearchLimits(options: GreedyOptions) HashSearchLimits {
    const minimum = minMatch(options);
    return .{
        .window_len = options.window_len,
        .max_chain = options.max_chain,
        .nice_len = options.nice_len,
        .minimum = minimum,
        .maximum = maxMatch(options),
        .max_walks = maxHashChainWalks(options, minimum),
    };
}

fn findBestHashMatchWithLayoutAndHashLimits(
    input: []const u8,
    pos: usize,
    limits: HashSearchLimits,
    head: anytype,
    prev: anytype,
    comptime ring: bool,
    comptime lazy_head: bool,
    initialized: HashHeadInit(lazy_head, @TypeOf(head)),
    comptime anchor: HashAnchor,
) HashMatchSearch {
    const hash = hashAtInput(input, pos, head.len, anchor) orelse return .{};
    const minimum = limits.minimum;
    if (pos + minimum > input.len) return .{ .hash = hash };
    if (limits.max_chain == 0) return .{ .hash = hash };

    var candidate_i = hashHeadGet(head, hash, lazy_head, initialized);
    const empty = hashPositionEmpty(@TypeOf(candidate_i));
    var checked: usize = 0;
    var walked: usize = 0;
    const max_len = @min(limits.maximum, input.len - pos);
    const earliest = if (comptime ring) pos -| limits.window_len else 0;
    var best = MatchCandidate{};
    while (candidate_i != empty and walked < limits.max_walks) : (walked += 1) {
        const candidate: usize = @intCast(candidate_i);
        if (comptime ring) {
            if (candidate < earliest) break;
        }
        const distance = pos - candidate;
        if (comptime !ring) {
            if (distance == 0 or distance > limits.window_len) break;
            if (best.length == max_len) break;
        }
        const required_prefix = @max(best.length, minimum - 1);
        if (input[candidate + required_prefix] != input[pos + required_prefix]) {
            candidate_i = prev[hashPrevIndex(candidate, prev, ring)];
            continue;
        }
        checked += 1;
        if (comptime @TypeOf(candidate_i) == u32) {
            // The compact lazy parser follows substantially deeper chains than
            // the speed presets. Mirror zlib-ng's longest-match front/back
            // screening after charging this candidate to the search budget:
            // a mismatch inside the already-known best prefix cannot improve
            // the result, while avoiding the full vector match scan. Keep the
            // existing required-prefix byte check above budget-free so token
            // selection remains identical to the isize reference path.
            const prefix_matches = if (best.length >= 8)
                std.mem.readInt(u64, input[candidate..][0..8], .little) ==
                    std.mem.readInt(u64, input[pos..][0..8], .little) and
                    std.mem.readInt(u64, input[candidate + best.length - 7 ..][0..8], .little) ==
                        std.mem.readInt(u64, input[pos + best.length - 7 ..][0..8], .little)
            else if (best.length >= 4)
                std.mem.readInt(u32, input[candidate..][0..4], .little) ==
                    std.mem.readInt(u32, input[pos..][0..4], .little) and
                    std.mem.readInt(u32, input[candidate + best.length - 3 ..][0..4], .little) ==
                        std.mem.readInt(u32, input[pos + best.length - 3 ..][0..4], .little)
            else
                std.mem.readInt(u16, input[candidate..][0..2], .little) ==
                    std.mem.readInt(u16, input[pos..][0..2], .little);
            if (!prefix_matches) {
                if (checked == limits.max_chain) break;
                candidate_i = prev[hashPrevIndex(candidate, prev, ring)];
                continue;
            }
        }
        const len = matchLength(input, candidate, pos, max_len);
        if (len >= minimum and len > best.length) {
            best = .{ .length = len, .distance = distance };
            if (len >= limits.nice_len) break;
            if (comptime ring) {
                if (len == max_len) break;
            }
        }
        if (checked == limits.max_chain) break;
        candidate_i = prev[hashPrevIndex(candidate, prev, ring)];
    }
    return .{ .best = best, .hash = hash };
}

fn maxHashChainWalks(options: GreedyOptions, minimum: usize) usize {
    if (minimum <= min_match_len or options.max_chain > 8) return options.max_chain;
    return options.max_chain * 4;
}

fn findBestCombinedHashMatch(dict: []const u8, input: []const u8, current: usize, options: GreedyOptions, head: anytype, prev: anytype) MatchCandidate {
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

fn findBestCombinedScanMatch(
    dict: []const u8,
    input: []const u8,
    pos: usize,
    options: GreedyOptions,
) MatchCandidate {
    const minimum = minMatch(options);
    if (input.len - pos < minimum or options.max_chain == 0) return .{};
    const current = dict.len + pos;
    const start = current -| @min(options.window_len, default_window_len);
    const max_len = @min(maxMatch(options), input.len - pos);
    var best = MatchCandidate{};
    var checked: usize = 0;
    var candidate = current;
    while (candidate > start and checked < options.max_chain) {
        candidate -= 1;
        if (byteAt(dict, input, candidate) != input[pos]) continue;
        checked += 1;
        const len = combinedMatchLength(
            dict,
            input,
            candidate,
            current,
            max_len,
        );
        if (len >= minimum and len > best.length) {
            best = .{ .length = len, .distance = current - candidate };
            if (len >= options.nice_len) break;
        }
    }
    return best;
}

fn findBestCombinedHashMatchLazy(dict: []const u8, input: []const u8, current: usize, options: GreedyOptions, head: anytype, prev: anytype, initialized: *const [hash_head_init_words]u64) MatchCandidate {
    const minimum = minMatch(options);
    const pos = current - dict.len;
    if (pos + minimum > input.len) return .{};
    const h = hash3At(dict, input, current) & (head.len - 1);
    const mask = @as(u64, 1) << @intCast(h & 63);
    if (initialized[h / 64] & mask == 0) return .{};
    return findBestCombinedHashMatch(dict, input, current, options, head, prev);
}

fn matchLength(input: []const u8, a: usize, b: usize, max_len: usize) usize {
    var len: usize = 0;
    // Long matches dominate the optimal and repeat-aware Zstd parsers. Compare
    // four words at once, then use the equality mask to preserve the exact
    // first-mismatch offset before falling through to the word/scalar tails.
    while (len + 32 <= max_len) : (len += 32) {
        const left: @Vector(32, u8) = input[a + len ..][0..32].*;
        const right: @Vector(32, u8) = input[b + len ..][0..32].*;
        const differing: u32 = ~@as(u32, @bitCast(left == right));
        if (differing != 0) return len + @ctz(differing);
    }
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

test "shared match length vector path matches byte reference" {
    var input: [674]u8 = undefined;
    for (input[0..337], 0..) |*byte, i| byte.* = @truncate(i * 37 + i / 11);
    @memcpy(input[337..674], input[0..337]);
    const maximum: usize = 321;

    for (0..maximum) |mismatch| {
        input[337 + mismatch] +%= 1;
        try std.testing.expectEqual(mismatch, matchLength(&input, 0, 337, maximum));
        input[337 + mismatch] = input[mismatch];
    }
    for (0..maximum + 1) |limit|
        try std.testing.expectEqual(limit, matchLength(&input, 0, 337, limit));
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

    var numbered_json: std.ArrayList(u8) = .empty;
    defer numbered_json.deinit(std.testing.allocator);
    while (numbered_json.items.len < 2048) {
        var line: [96]u8 = undefined;
        const formatted = try std.fmt.bufPrint(&line, "{{\"id\":{d},\"service\":\"vort\",\"message\":\"structured input\"}}\n", .{numbered_json.items.len / 64});
        try numbered_json.appendSlice(std.testing.allocator, formatted);
    }
    try std.testing.expect(!preferScanLazy(numbered_json.items));

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
    head: anytype,
    hash: usize,
    comptime lazy_head: bool,
    initialized: HashHeadInit(lazy_head, @TypeOf(head)),
) @TypeOf(head[0]) {
    if (lazy_head) {
        const mask = @as(u64, 1) << @intCast(hash & 63);
        if (initialized[hash / 64] & mask == 0) return hashPositionEmpty(@TypeOf(head[0]));
    }
    return head[hash];
}

fn insertHashWithLayout(
    input: []const u8,
    pos: usize,
    head: anytype,
    prev: anytype,
    comptime ring: bool,
    comptime lazy_head: bool,
    initialized: HashHeadInit(lazy_head, @TypeOf(head)),
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
    head: anytype,
    prev: anytype,
    comptime ring: bool,
    comptime lazy_head: bool,
    initialized: HashHeadInit(lazy_head, @TypeOf(head)),
) void {
    if (lazy_head) {
        const mask = @as(u64, 1) << @intCast(h & 63);
        const word = &initialized[h / 64];
        if (word.* & mask == 0) {
            word.* |= mask;
            prev[hashPrevIndex(pos, prev, ring)] = hashPositionEmpty(@TypeOf(prev[0]));
            head[h] = @intCast(pos);
            return;
        }
    }
    prev[hashPrevIndex(pos, prev, ring)] = head[h];
    head[h] = @intCast(pos);
}

fn hashPositionEmpty(comptime Position: type) Position {
    return switch (@typeInfo(Position).int.signedness) {
        .signed => -1,
        .unsigned => std.math.maxInt(Position),
    };
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

fn seedDictionaryHashesLazy(dict: []const u8, input: []const u8, head: anytype, prev: anytype, initialized: *[hash_head_init_words]u64) void {
    var pos: usize = 0;
    while (pos + min_match_len <= dict.len) : (pos += 1)
        insertCombinedHashLazy(dict, input, pos, head, prev, initialized);
}

fn insertCombinedHashLazy(dict: []const u8, input: []const u8, pos: usize, head: anytype, prev: anytype, initialized: *[hash_head_init_words]u64) void {
    if (pos + min_match_len > dict.len + input.len) return;
    const h = hash3At(dict, input, pos) & (head.len - 1);
    const mask = @as(u64, 1) << @intCast(h & 63);
    const word = &initialized[h / 64];
    prev[pos] = if (word.* & mask == 0) -1 else head[h];
    head[h] = @intCast(pos);
    word.* |= mask;
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

test "modeled optimal parser follows caller entropy costs" {
    const input = "abcabcabcabcabcabcabcabc";
    const options = GreedyOptions{
        .window_len = input.len,
        .max_chain = 64,
        .nice_len = max_match_len,
        .max_candidates = 32,
        .min_match = 3,
        .max_match = max_match_len,
    };
    var literal_costs: [256]u16 = @splat(1);
    var length_costs: [max_match_len + 1]u16 = @splat(1000);
    var distance_costs: [input.len + 1]u16 = @splat(1000);
    distance_costs[0] = 1;

    const literal_plan = try optimalPlanAllocWithCostModel(std.testing.allocator, input, options, .{
        .literal = &literal_costs,
        .length = &length_costs,
        .distance = &distance_costs,
    });
    defer literal_plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(input.len, literal_plan.stats.literals);
    try std.testing.expectEqual(@as(usize, 0), literal_plan.stats.matches);

    literal_costs = @splat(1000);
    length_costs = @splat(1);
    distance_costs = @splat(1);
    const match_plan = try optimalPlanAllocWithCostModel(std.testing.allocator, input, options, .{
        .literal = &literal_costs,
        .length = &length_costs,
        .distance = &distance_costs,
    });
    defer match_plan.deinit(std.testing.allocator);
    try std.testing.expect(match_plan.stats.matches != 0);
    try std.testing.expect(match_plan.stats.literals < literal_plan.stats.literals);

    const replayed = try replayAlloc(std.testing.allocator, match_plan.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
}

test "modeled optimal parser validates complete nonzero costs" {
    var literal_costs: [256]u16 = @splat(1);
    var length_costs: [max_match_len + 1]u16 = @splat(1);
    var distance_costs: [8]u16 = @splat(1);
    literal_costs['x'] = 0;
    try std.testing.expectError(error.InvalidBlockPlan, optimalPlanAllocWithCostModel(std.testing.allocator, "xxxxxxxx", .{
        .window_len = 7,
        .min_match = 3,
    }, .{
        .literal = &literal_costs,
        .length = &length_costs,
        .distance = &distance_costs,
    }));

    literal_costs['x'] = 1;
    length_costs[3] = 0;
    try std.testing.expectError(error.InvalidBlockPlan, optimalPlanAllocWithCostModel(std.testing.allocator, "xxxxxxxx", .{
        .window_len = 7,
        .min_match = 3,
    }, .{
        .literal = &literal_costs,
        .length = &length_costs,
        .distance = &distance_costs,
    }));
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
    const capacities = .{ scratch.costs.capacity, scratch.steps.capacity, scratch.index.head.capacity, scratch.index.prev.capacity, scratch.compact_head.capacity, scratch.compact_prev.capacity, scratch.tokens.capacity };
    _ = try optimalPlanReuse(&scratch, std.testing.allocator, input, options);
    try std.testing.expectEqual(capacities, .{ scratch.costs.capacity, scratch.steps.capacity, scratch.index.head.capacity, scratch.index.prev.capacity, scratch.compact_head.capacity, scratch.compact_prev.capacity, scratch.tokens.capacity });
}

test "optimal prefix bound preserves reference tokens" {
    var input: [4096]u8 = undefined;
    var state: u32 = 0x243f_6a88;
    for (0..64) |case_index| {
        const minimum: usize = 3 + case_index % 2;
        const seed = case_index / 2;
        for (&input, 0..) |*byte, i| {
            state = state *% 1_664_525 +% 1_013_904_223;
            byte.* = switch (seed % 4) {
                0 => @truncate(state >> 24),
                1 => @truncate(i * 17 + seed),
                2 => @truncate((i / (3 + seed)) % 23 + 'a'),
                else => @truncate((i / 31) + (state >> 29)),
            };
        }
        const options: GreedyOptions = .{
            .window_len = input.len,
            .max_chain = 128,
            .nice_len = max_match_len,
            .max_candidates = 8,
            .min_match = minimum,
            .max_match = max_match_len,
        };
        var reference: OptimalScratch = .{};
        defer reference.deinit(std.testing.allocator);
        const reference_stats = try optimalPlanReuseInternal(&reference, std.testing.allocator, &input, options, false);
        var bounded: OptimalScratch = .{};
        defer bounded.deinit(std.testing.allocator);
        const bounded_stats = try optimalPlanReuseInternal(&bounded, std.testing.allocator, &input, options, true);
        try std.testing.expectEqual(reference_stats, bounded_stats);
        try std.testing.expectEqualSlices(Token, reference.tokens.items, bounded.tokens.items);
    }
}

test "profiled optimal parser preserves tokens and search accounting" {
    var input: [4096]u8 = undefined;
    var state: u32 = 0x3c6e_f372;
    for (&input, 0..) |*byte, position| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (position >= 769 and position % 17 < 13)
            input[position - 769]
        else
            @truncate(state >> 24);
    }
    const options: GreedyOptions = .{
        .window_len = input.len,
        .max_chain = 128,
        .nice_len = max_match_len,
        .max_candidates = 32,
        .min_match = 4,
        .max_match = max_match_len,
    };
    const expected = try optimalPlanAlloc(std.testing.allocator, &input, options);
    defer expected.deinit(std.testing.allocator);
    var profile: OptimalSearchProfile = .{};
    const actual = try optimalPlanAllocProfiled(std.testing.allocator, &input, options, std.testing.io, &profile);
    defer actual.deinit(std.testing.allocator);

    try std.testing.expectEqual(expected.stats, actual.stats);
    try expectEqualTokenSlices(expected.tokens, actual.tokens);
    try std.testing.expectEqual(input.len, profile.input_bytes);
    try std.testing.expectEqual(input.len, profile.positions);
    try std.testing.expect(profile.index_bytes > 0);
    try std.testing.expectEqual(
        profile.chain_nodes,
        profile.prefix_rejections + profile.bound_rejections + profile.match_length_calls,
    );
    var prefix_mismatch_total: usize = 0;
    for (profile.prefix_mismatch_histogram) |count| prefix_mismatch_total += count;
    try std.testing.expectEqual(profile.prefix_rejections, prefix_mismatch_total);
    var extension_total: usize = 0;
    for (profile.length_extension_histogram) |count| extension_total += count;
    try std.testing.expectEqual(profile.valid_match_candidates, extension_total);
    try std.testing.expect(profile.match_length_calls >= profile.valid_match_candidates);
    try std.testing.expect(profile.index_ns + profile.search_ns + profile.reconstruct_ns <= profile.total_ns);
}

test "compact optimal hash index matches reference beyond u16 positions" {
    var input: [70 * 1024]u8 = undefined;
    var state: u32 = 0x517c_c1b7;
    for (&input, 0..) |*byte, position| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (position >= default_window_len and position % 19 < 13)
            input[position - default_window_len]
        else
            @truncate(state >> 24);
    }

    var reference: HashIndex = .{};
    defer reference.deinit(std.testing.allocator);
    try reference.build(std.testing.allocator, &input);
    var compact_head: std.ArrayList(u32) = .empty;
    defer compact_head.deinit(std.testing.allocator);
    var compact_prev: std.ArrayList(u32) = .empty;
    defer compact_prev.deinit(std.testing.allocator);
    var compact_initialized: [hash_head_init_words]u64 = @splat(0);
    try buildOptimalCompactHashIndex(std.testing.allocator, &input, &compact_head, &compact_prev, &compact_initialized);

    try std.testing.expectEqualSlices(u64, &reference.head_initialized, &compact_initialized);
    for (0..hash_head_table_size) |hash| {
        const mask = @as(u64, 1) << @intCast(hash & 63);
        if (reference.head_initialized[hash / 64] & mask != 0)
            try std.testing.expectEqual(@as(u32, @intCast(reference.head.items[hash])), compact_head.items[hash]);
    }
    for (0..input.len - 2) |position| {
        const expected = reference.prev.items[position];
        const actual = compact_prev.items[position];
        if (expected < 0) {
            try std.testing.expectEqual(optimal_compact_index_empty, actual);
        } else {
            try std.testing.expectEqual(@as(u32, @intCast(expected)), actual);
        }
    }
}

test "reusable optimal parser recovers after compact-index allocation failure" {
    const input = "abcabcXabcabcYabcabcZabcabcX" ** 16;
    const options: GreedyOptions = .{
        .window_len = input.len,
        .max_chain = 64,
        .nice_len = max_match_len,
        .max_candidates = 8,
        .min_match = 3,
    };
    var scratch: OptimalScratch = .{};
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 3 });
    {
        const allocator = failing.allocator();
        try std.testing.expectError(error.OutOfMemory, optimalPlanReuse(&scratch, allocator, input, options));
        failing.fail_index = std.math.maxInt(usize);
        _ = try optimalPlanReuse(&scratch, allocator, input, options);
        const replayed = try replayAlloc(allocator, scratch.tokens.items);
        defer allocator.free(replayed);
        try std.testing.expectEqualSlices(u8, input, replayed);
        try std.testing.expectEqual(@as(usize, hash_head_table_size), scratch.compact_head.items.len);
        try std.testing.expectEqual(input.len, scratch.compact_prev.items.len);
    }
    scratch.deinit(failing.allocator());
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
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

test "hash index candidate distances preserve validated match order" {
    const input = "abcd-abcX-abcd-abcdY-abcd-abcd";
    var index: HashIndex = .{};
    defer index.deinit(std.testing.allocator);
    try index.build(std.testing.allocator, input);
    const position = std.mem.lastIndexOf(u8, input, "abcd") orelse
        return error.InvalidMatch;
    const options = GreedyOptions{
        .window_len = input.len,
        .max_chain = 64,
        .nice_len = 258,
        .max_candidates = 8,
        .min_match = 4,
    };
    var matches: [8]Token.Match = undefined;
    var distances: [8]u16 = undefined;
    const match_count = try index.matchesAt(input, position, options, &matches);
    const distance_count = try index.candidateDistancesAt(input, position, options, &distances);
    try std.testing.expectEqual(match_count, distance_count);
    for (matches[0..match_count], distances[0..distance_count]) |match, distance_value|
        try std.testing.expectEqual(match.distance, distance_value);
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

test "hash planner with zero chain budget emits only literals" {
    const input = "abcabcabcabc";
    const plan = try hashGreedyPlanAlloc(std.testing.allocator, input, .{ .max_chain = 0 });
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(input.len, plan.stats.literals);
    try std.testing.expectEqual(@as(usize, 0), plan.stats.matches);
    try std.testing.expectEqual(@as(usize, 0), plan.stats.matched_bytes);
    try std.testing.expectEqual(input.len, plan.tokens.len);
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

test "reusable tiny hash scratch preserves tokens across inputs" {
    try std.testing.expectEqual(@as(usize, 8 * 1024), @sizeOf(@FieldType(TinyGreedyScratch, "head")));
    try std.testing.expectEqual(@as(usize, tiny_hash_head_table_size / 8), @sizeOf(@FieldType(TinyGreedyScratch, "head_initialized")));
    const options = GreedyOptions{ .window_len = 32 * 1024, .max_chain = 64, .nice_len = 64, .max_candidates = 8 };
    const inputs = [_][]const u8{
        "abcabcXabcabcXabcabcX",
        "different-different-different",
        "qzxwvbnm1234567890QZXWVBNM",
        "abcabcXabcabcXabcabcX",
    };
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(std.testing.allocator);
    var scratch: TinyGreedyScratch = .{};
    defer scratch.deinit(std.testing.allocator);
    var retained_capacity: ?usize = null;
    for (inputs) |input| {
        const reference = try hashGreedyPlanAutoTinyAlloc(std.testing.allocator, input, options);
        defer reference.deinit(std.testing.allocator);
        const stats = try hashGreedyPlanAutoTinyScratchReuse(&tokens, &scratch, std.testing.allocator, input, options);
        try expectEqualTokenSlices(reference.tokens, tokens.items);
        try std.testing.expectEqual(reference.stats, stats);
        if (retained_capacity) |capacity|
            try std.testing.expect(scratch.retainedCapacity() >= capacity)
        else
            retained_capacity = scratch.retainedCapacity();
    }
}

test "reusable tiny hash scratch covers maximum input position" {
    var input: [32 * 1024]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @truncate(i * 37 + i / 11);
    const options = GreedyOptions{ .window_len = input.len, .max_chain = 64, .nice_len = 64, .max_candidates = 8 };
    const reference = try hashGreedyPlanAutoTinyAlloc(std.testing.allocator, &input, options);
    defer reference.deinit(std.testing.allocator);
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(std.testing.allocator);
    var scratch: TinyGreedyScratch = .{};
    defer scratch.deinit(std.testing.allocator);
    const stats = try hashGreedyPlanAutoTinyScratchReuse(&tokens, &scratch, std.testing.allocator, &input, options);
    try expectEqualTokenSlices(reference.tokens, tokens.items);
    try std.testing.expectEqual(reference.stats, stats);
}

test "one-shot tiny hash planner covers maximum three-byte position" {
    var input: [32 * 1024]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @truncate(i * 43 + i / 13);
    const options = GreedyOptions{ .window_len = input.len, .max_chain = 64, .nice_len = 64, .max_candidates = 8 };
    const reference = try hashGreedyPlanAlloc(std.testing.allocator, &input, options);
    defer reference.deinit(std.testing.allocator);
    const tiny = try hashGreedyPlanAutoTinyAlloc(std.testing.allocator, &input, options);
    defer tiny.deinit(std.testing.allocator);
    try expectEqualTokenSlices(reference.tokens, tiny.tokens);
    try std.testing.expectEqual(reference.stats, tiny.stats);
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

test "reusable lazy planner preserves production scan and hash policies" {
    const options = GreedyOptions{ .window_len = 32 * 1024, .max_chain = 64, .nice_len = 64, .max_candidates = 1, .lazy_min_gain = 1, .min_match = 3, .max_match = max_match_len };
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(std.testing.allocator);
    for ([_][]const u8{
        "abcabcabcabc" ** 128,
        "pub fn update(state: *State, value: u32) void { state.total += value; }\n" ** 40,
    }) |input| {
        const reference = try lazyGreedyPlanAlloc(std.testing.allocator, input, options);
        defer reference.deinit(std.testing.allocator);
        const stats = try lazyGreedyPlanTinyReuse(&tokens, std.testing.allocator, input, options);
        try expectEqualTokenSlices(reference.tokens, tokens.items);
        try std.testing.expectEqual(reference.stats, stats);
    }
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

test "hash greedy compact position boundary" {
    try std.testing.expectEqual(@as(i32, -1), hashPositionEmpty(i32));
    try std.testing.expectEqual(std.math.maxInt(u16), hashPositionEmpty(u16));
    try std.testing.expect(@as(usize, std.math.maxInt(u16)) > 64 * 1024 - 3);
    try std.testing.expect(@as(usize, std.math.maxInt(u16)) > 64 * 1024 - 4);
    try std.testing.expect(hashPositionFitsI32(std.math.maxInt(i32)));
    if (@bitSizeOf(usize) > @bitSizeOf(i32)) {
        try std.testing.expect(!hashPositionFitsI32(@as(usize, std.math.maxInt(i32)) + 1));
    }
    try std.testing.expect(hashPositionFitsU32(std.math.maxInt(u32)));
    if (@bitSizeOf(usize) > @bitSizeOf(u32)) {
        try std.testing.expect(!hashPositionFitsU32(@as(usize, std.math.maxInt(u32)) + 1));
    }
}

test "64 KiB lazy hash u16 positions match i32 reference" {
    const Observer = struct {
        pub fn recordToken(_: @This(), _: Token) void {}
    };

    const input = try std.testing.allocator.alloc(u8, 64 * 1024);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x243f_6a88;
    for (input, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state ^ (state >> 11) ^ @as(u32, @truncate(index * 73)));
    }

    inline for (.{ HashAnchor.three, HashAnchor.four }) |anchor| {
        const minimum: usize = switch (anchor) {
            .three => 3,
            .four => 4,
        };
        const options: GreedyOptions = .{
            .window_len = 16 * 1024,
            .max_chain = 6,
            .nice_len = 16,
            .max_candidates = 1,
            .lazy_min_gain = 3,
            .min_match = minimum,
            .max_match = 96,
            .min_savings_bits = 6,
        };

        const reference_head = try std.testing.allocator.alloc(i32, hash_head_table_size);
        defer std.testing.allocator.free(reference_head);
        const reference_prev = try std.testing.allocator.alloc(i32, input.len);
        defer std.testing.allocator.free(reference_prev);
        var reference_initialized: [hash_head_init_words]u64 = @splat(0);
        const reference = try hashGreedyPlanWithTablesObserved(
            std.testing.allocator,
            input,
            options,
            reference_head,
            reference_prev,
            false,
            true,
            &reference_initialized,
            anchor,
            Observer{},
        );
        defer reference.deinit(std.testing.allocator);

        const compact_head = try std.testing.allocator.alloc(u16, hash_head_table_size);
        defer std.testing.allocator.free(compact_head);
        const compact_prev = try std.testing.allocator.alloc(u16, options.window_len);
        defer std.testing.allocator.free(compact_prev);
        var compact_initialized: [hash_head_init_words]u64 = @splat(0);
        const compact = try hashGreedyPlanWithTablesObserved(
            std.testing.allocator,
            input,
            options,
            compact_head,
            compact_prev,
            true,
            true,
            &compact_initialized,
            anchor,
            Observer{},
        );
        defer compact.deinit(std.testing.allocator);

        try expectEqualTokenSlices(reference.tokens, compact.tokens);
        try std.testing.expectEqual(reference.stats, compact.stats);
        const last_position = input.len - minimum;
        const last_hash = hashAtInput(input, last_position, compact_head.len, anchor).?;
        try std.testing.expectEqual(@as(u16, @intCast(last_position)), compact_head[last_hash]);
        const reference_link = reference_prev[last_position];
        const compact_link = compact_prev[hashPrevIndex(last_position, compact_prev, true)];
        try std.testing.expectEqual(
            if (reference_link < 0) std.math.maxInt(u16) else @as(u16, @intCast(reference_link)),
            compact_link,
        );
    }
}

test "lazy hash compact positions match isize reference" {
    const input = try std.testing.allocator.alloc(u8, 96 * 1024 + 37);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x9e37_79b9;
    for (input, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index >= 33 * 1024 and index % 11 < 8)
            input[index - 33 * 1024]
        else
            @truncate(state ^ (state >> 13) ^ @as(u32, @truncate(index * 29)));
    }

    const options: GreedyOptions = .{
        .window_len = default_window_len,
        .max_chain = 160,
        .nice_len = 80,
        .max_candidates = 6,
        .lazy_min_gain = 1,
        .min_match = 3,
        .max_match = max_match_len,
        .min_savings_bits = 1,
    };
    const reference_head = try std.testing.allocator.alloc(isize, hash_head_table_size);
    defer std.testing.allocator.free(reference_head);
    @memset(reference_head, -1);
    const reference_prev = try std.testing.allocator.alloc(isize, input.len);
    defer std.testing.allocator.free(reference_prev);
    const reference = try hashLazyGreedyPlanWithTables(
        std.testing.allocator,
        input,
        options,
        reference_head,
        reference_prev,
    );
    defer reference.deinit(std.testing.allocator);

    const compact_head = try std.testing.allocator.alloc(u32, hash_head_table_size);
    defer std.testing.allocator.free(compact_head);
    @memset(compact_head, hashPositionEmpty(u32));
    const compact_prev = try std.testing.allocator.alloc(u32, input.len);
    defer std.testing.allocator.free(compact_prev);
    const compact = try hashLazyGreedyPlanWithTables(
        std.testing.allocator,
        input,
        options,
        compact_head,
        compact_prev,
    );
    defer compact.deinit(std.testing.allocator);

    try expectEqualTokenSlices(reference.tokens, compact.tokens);
    try std.testing.expectEqual(reference.stats, compact.stats);
    for (reference_head, compact_head) |reference_position, compact_position| {
        try std.testing.expectEqual(
            if (reference_position < 0) hashPositionEmpty(u32) else @as(u32, @intCast(reference_position)),
            compact_position,
        );
    }
    for (reference_prev[0 .. input.len - min_match_len + 1], compact_prev[0 .. input.len - min_match_len + 1]) |reference_position, compact_position| {
        try std.testing.expectEqual(
            if (reference_position < 0) hashPositionEmpty(u32) else @as(u32, @intCast(reference_position)),
            compact_position,
        );
    }

    if (@sizeOf(isize) > @sizeOf(u32)) {
        var compact_alloc = std.testing.FailingAllocator.init(std.testing.allocator, .{});
        {
            const plan = try hashLazyGreedyPlanAlloc(compact_alloc.allocator(), input, options);
            defer plan.deinit(compact_alloc.allocator());
        }
        var reference_alloc = std.testing.FailingAllocator.init(std.testing.allocator, .{});
        {
            const allocator = reference_alloc.allocator();
            const head = try allocator.alloc(isize, hash_head_table_size);
            defer allocator.free(head);
            @memset(head, -1);
            const prev = try allocator.alloc(isize, input.len);
            defer allocator.free(prev);
            const plan = try hashLazyGreedyPlanWithTables(allocator, input, options, head, prev);
            defer plan.deinit(allocator);
        }
        const compact_index_bytes = (hash_head_table_size + input.len) * @sizeOf(u32);
        const reference_index_bytes = (hash_head_table_size + input.len) * @sizeOf(isize);
        try std.testing.expectEqual(
            reference_index_bytes - compact_index_bytes,
            reference_alloc.allocated_bytes - compact_alloc.allocated_bytes,
        );
    }
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
        @as(usize, 64 * 1024),
        hashPrevTableLen(64 * 1024, 16 * 1024),
    );
    try std.testing.expectEqual(
        @as(usize, 16 * 1024),
        hashPrevTableLen(64 * 1024 + 1, 16 * 1024),
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

test "scan dictionary planner emits preset-history matches" {
    const dictionary = "sensor=42;status=nominal;" ** 4;
    const input = "sensor=42;status=nominal;sensor=42";
    const plan = try greedyPlanAllocWithDictionary(
        std.testing.allocator,
        input,
        dictionary,
        .{ .window_len = 16 * 1024, .max_chain = 4, .nice_len = 32 },
    );
    defer plan.deinit(std.testing.allocator);
    try std.testing.expect(plan.stats.matches > 0);
    try std.testing.expect(plan.stats.matched_bytes >= 32);
    for (plan.tokens) |token| switch (token) {
        .match => |match| {
            try std.testing.expect(match.distance <= dictionary.len);
            break;
        },
        .literal => {},
    };
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

test "constant-time hash match acceptance matches exhaustive length scan" {
    for ([_]usize{ 0, 1, 4, 255, 4096, default_window_len, default_window_len + 1, max_window_len }) |window_len| {
        for ([_]usize{ 0, 3, 4, 5, 9, 10, 11, 18, 19, 66, 67, 130, 131, 257, 258, 300 }) |minimum| {
            for ([_]usize{ 3, 4, 10, 66, 130, 257, 258, 300 }) |maximum| {
                for ([_]usize{ 0, 1, 4, 8, 16, 64, std.math.maxInt(usize) }) |savings| {
                    const options = GreedyOptions{
                        .window_len = window_len,
                        .min_match = minimum,
                        .max_match = maximum,
                        .min_savings_bits = savings,
                    };
                    try std.testing.expectEqual(acceptsEveryHashMatchReference(options), acceptsEveryHashMatch(options));
                }
            }
        }
    }
}

fn acceptsEveryHashMatchReference(options: GreedyOptions) bool {
    if (options.window_len == 0 or options.window_len > default_window_len) return false;
    const distance_cost = fixedDistanceSymbolCost(options.window_len);
    var length = minMatch(options);
    while (length <= maxMatch(options)) : (length += 1) {
        const literal_min_cost = length * 8;
        const match_cost = fixedLengthSymbolCost(length) + distance_cost;
        if (match_cost > literal_min_cost or options.min_savings_bits > literal_min_cost - match_cost) return false;
    }
    return true;
}
