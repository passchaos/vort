//! Standalone injected fixtures plus an oracle hook for the root's actual
//! ordinary modeled parser. No reverse import of the lz77 facade is needed.
const std = @import("std");
const pair = @import("modeled_pair.zig");
const t = std.testing;

/// Root tests can pass their real adapter and independent scalar parser here.
pub fn expectSame(comptime Api: type, allocator: std.mem.Allocator, input: []const u8, options: Api.Options, models: [2]Api.Model, comptime scalarPlan: anytype) !void {
    const actual = try pair.planAlloc(Api, allocator, input, options, models);
    defer for (actual) |plan| allocator.free(plan.tokens);
    for (0..2) |side| {
        const expected = try scalarPlan(allocator, input, options, models[side]);
        defer allocator.free(expected.tokens);
        try t.expectEqualDeep(expected.stats, actual[side].stats);
        try t.expectEqual(expected.tokens.len, actual[side].tokens.len);
        for (expected.tokens, actual[side].tokens) |first, second| try t.expect(std.meta.eql(first, second));
    }
}

const FixtureApi = struct {
    pub const Token = union(enum) {
        literal: u8,
        match: Match,
        pub const Match = struct {
            length: u16,
            distance: u16,
            dictionary: u32 = 0,

            pub fn initDictionary(output_len: u16, copy_len: u16, address: u32) Match {
                std.debug.assert(output_len >= 4 and output_len <= 63 and copy_len >= 4 and copy_len <= 24 and address < (1 << 18));
                return .{ .length = output_len, .distance = 0, .dictionary = (address << 12) | (@as(u32, copy_len - 4) << 6) | output_len };
            }
        };
    };
    pub const Plan = struct {
        tokens: []Token,
        stats: struct { literals: usize = 0, matches: usize = 0, matched_bytes: usize = 0 },
    };
    const DictionaryMatch = struct { output_len: u16, copy_len: u16, address: u32 };
    pub const Options = struct {
        window_len: usize = 32,
        max_chain: usize = 128,
        nice_len: usize = 64,
        max_candidates: usize = 8,
        min_match: usize = 4,
        max_match: usize = 258,
        dictionary: ?struct { context: *anyopaque, find: *const fn (*anyopaque, usize) ?DictionaryMatch } = null,
        dictionary_cost: u16 = 0,
    };
    pub const Model = struct {
        literal: *const [256]u16,
        literal_context: ?[]const u16 = null,
        length: *const [259]u16,
        distance: []const u16,
    };
    pub const Index = struct { previous: []isize, head: ?[]isize };
    var match_calls: usize = 0;
    var index_builds: usize = 0;
    var bound_rejections: usize = 0;

    pub fn boundRejected() void {
        bound_rejections += 1;
    }

    pub fn validateModel(model: Model, window: usize, input_len: usize) !void {
        _ = input_len;
        if (window > 65535 or model.distance.len <= window) return error.InvalidBlockPlan;
        for (model.literal) |price| if (price == 0) return error.InvalidBlockPlan;
        for (model.length[3..]) |price| if (price == 0) return error.InvalidBlockPlan;
        for (model.distance[1 .. window + 1]) |price| if (price == 0) return error.InvalidBlockPlan;
        if (model.literal_context) |prices| {
            if (prices.len < 1024) return error.InvalidBlockPlan;
            for (prices[0..1024]) |price| if (price == 0) return error.InvalidBlockPlan;
        }
    }

    // Deliberately place every complete four-byte anchor in one bucket. This
    // legal collision-heavy fixture makes prefix rejection consume budgets.
    // Root differential tests supply their actual four-anchor HashIndex.
    pub fn buildIndex(allocator: std.mem.Allocator, input: []const u8) !Index {
        const previous = try allocator.alloc(isize, input.len);
        errdefer allocator.free(previous);
        const head = try allocator.alloc(isize, 1);
        head[0] = -1;
        for (previous, 0..) |*value, position|
            value.* = if (position != 0 and position + 4 <= input.len) @intCast(position - 1) else -1;
        index_builds += 1;
        return .{ .previous = previous, .head = head };
    }

    pub fn releaseHead(index: *Index, allocator: std.mem.Allocator) void {
        if (index.head) |head| allocator.free(head);
        index.head = null;
    }
    pub fn prev(index: *Index) []const isize {
        return index.previous;
    }
    pub fn deinitIndex(index: *Index, allocator: std.mem.Allocator) void {
        releaseHead(index, allocator);
        allocator.free(index.previous);
    }
    pub fn minimum(options: Options) usize {
        return @max(3, @min(options.min_match, maximum(options)));
    }
    pub fn maximum(options: Options) usize {
        return @max(3, @min(options.max_match, 258));
    }
    pub fn candidateLimit(options: Options) usize {
        return @max(1, @min(options.max_candidates, 512));
    }
    pub fn matchLength(input: []const u8, candidate: usize, position: usize, max_len: usize) usize {
        match_calls += 1;
        var length: usize = 0;
        while (length < max_len and input[candidate + length] == input[position + length]) : (length += 1) {}
        return length;
    }
    pub fn literalCost(model: Model, position: usize, input: []const u8) usize {
        const context = model.literal_context orelse return model.literal[input[position]];
        const previous: u8 = if (position == 0) 0 else input[position - 1];
        const class: usize = if (std.ascii.isAlphabetic(previous)) 0 else if (std.ascii.isDigit(previous)) 1 else if (previous == ' ' or previous == '\t' or previous == '\n' or previous == '\r') 2 else 3;
        return context[class * 256 + input[position]];
    }
    pub fn appendToken(tokens: *std.ArrayList(Token), allocator: std.mem.Allocator, token: Token) !void {
        try tokens.append(allocator, token);
    }

    // Independent oracle: full u64 costs and Token steps, exhaustive ascending
    // length scoring for every candidate, no packed/extended choice cache.
    pub fn scalarPlan(allocator: std.mem.Allocator, input: []const u8, options: Options, model: Model) !Plan {
        try validateModel(model, options.window_len, input.len);
        var index = try buildIndex(allocator, input);
        defer deinitIndex(&index, allocator);
        const costs = try allocator.alloc(u64, input.len + 1);
        defer allocator.free(costs);
        const steps = try allocator.alloc(Token, input.len);
        defer allocator.free(steps);
        costs[input.len] = 0;
        var position = input.len;
        while (position != 0) {
            position -= 1;
            costs[position] = costs[position + 1] + literalCost(model, position, input);
            steps[position] = .{ .literal = input[position] };
            if (input.len - position < minimum(options)) continue;
            const max_len = @min(maximum(options), input.len - position);
            var chain = index.previous[position];
            var checked: usize = 0;
            var candidates: usize = 0;
            while (chain >= 0 and checked < options.max_chain) : (checked += 1) {
                const candidate: usize = @intCast(chain);
                const distance = position - candidate;
                if (distance == 0 or distance > options.window_len) break;
                if (!std.mem.eql(u8, input[candidate..][0..4], input[position..][0..4])) {
                    chain = index.previous[candidate];
                    continue;
                }
                const length = matchLength(input, candidate, position, max_len);
                if (length >= minimum(options)) {
                    var best: u64 = std.math.maxInt(u64);
                    var best_length: usize = 0;
                    for (minimum(options)..length + 1) |choice_length| {
                        const cost = costs[position + choice_length] + model.length[choice_length];
                        if (cost < best or (cost == best and choice_length > best_length)) {
                            best = cost;
                            best_length = choice_length;
                        }
                    }
                    const cost = best + model.distance[distance];
                    if (cost < costs[position]) {
                        costs[position] = cost;
                        steps[position] = .{ .match = .{ .length = @intCast(best_length), .distance = @intCast(distance) } };
                    }
                    candidates += 1;
                    if (length == max_len) break;
                    if (length >= options.nice_len and candidates >= candidateLimit(options)) break;
                    if (candidates >= candidateLimit(options)) break;
                }
                chain = index.previous[candidate];
            }
            if (options.dictionary) |provider| if (options.dictionary_cost != 0) {
                if (provider.find(provider.context, position)) |match| {
                    const target = position + match.output_len;
                    if (match.output_len != 0 and match.copy_len != 0 and target <= input.len) {
                        const cost = costs[target] + options.dictionary_cost;
                        if (cost < costs[position]) {
                            costs[position] = cost;
                            steps[position] = .{ .match = .initDictionary(match.output_len, match.copy_len, match.address) };
                        }
                    }
                }
            };
        }
        var tokens: std.ArrayList(Token) = .empty;
        errdefer tokens.deinit(allocator);
        var stats: @FieldType(Plan, "stats") = .{};
        position = 0;
        while (position < input.len) {
            const token = steps[position];
            try tokens.append(allocator, token);
            switch (token) {
                .literal => {
                    stats.literals += 1;
                    position += 1;
                },
                .match => |match| {
                    stats.matches += 1;
                    stats.matched_bytes += match.length;
                    position += match.length;
                },
            }
        }
        return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
    }
};

const Prices = struct {
    literal: *[256]u16,
    length: *[259]u16,
    context: []u16,
    distances: []u16,

    fn init(allocator: std.mem.Allocator, window: usize) !Prices {
        const literal = try allocator.create([256]u16);
        errdefer allocator.destroy(literal);
        const length = try allocator.create([259]u16);
        errdefer allocator.destroy(length);
        const context = try allocator.alloc(u16, 1024);
        errdefer allocator.free(context);
        const distances = try allocator.alloc(u16, window + 1);
        @memset(literal, 8);
        @memset(length, 1);
        @memset(context, 9);
        @memset(distances, 2);
        distances[0] = 0;
        return .{ .literal = literal, .length = length, .context = context, .distances = distances };
    }
    fn deinit(self: Prices, allocator: std.mem.Allocator) void {
        allocator.destroy(self.literal);
        allocator.destroy(self.length);
        allocator.free(self.context);
        allocator.free(self.distances);
    }
    fn model(self: Prices, contextual: bool) FixtureApi.Model {
        return .{ .literal = self.literal, .length = self.length, .literal_context = if (contextual) self.context else null, .distance = self.distances };
    }
};

fn containsMatch(plan: FixtureApi.Plan, length: u16, distance: u16) bool {
    for (plan.tokens) |token| switch (token) {
        .literal => {},
        .match => |match| if (match.length == length and match.distance == distance and match.dictionary == 0) return true,
    };
    return false;
}

test "modeled pair preserves equal and shorter lengths at nonmonotone distance prices" {
    const left = try Prices.init(t.allocator, 32);
    defer left.deinit(t.allocator);
    const right = try Prices.init(t.allocator, 32);
    defer right.deinit(t.allocator);
    left.distances[5] = 100;
    left.distances[10] = 1;
    right.distances[5] = 1;
    right.distances[10] = 100;
    const models = [2]FixtureApi.Model{ left.model(false), right.model(false) };
    const options: FixtureApi.Options = .{ .nice_len = 4, .max_candidates = 2 };
    const input = "abcd!abcd?abcd#";
    const plans = try pair.planAlloc(FixtureApi, t.allocator, input, options, models);
    defer for (plans) |plan| t.allocator.free(plan.tokens);
    try t.expect(containsMatch(plans[0], 4, 10));
    try t.expect(containsMatch(plans[1], 4, 5));
    try expectSame(FixtureApi, t.allocator, input, options, models, FixtureApi.scalarPlan);

    left.distances[6] = 100;
    left.distances[11] = 1;
    right.distances[6] = 1;
    right.distances[11] = 100;
    const shorter_models = [2]FixtureApi.Model{ left.model(false), right.model(false) };
    const shorter = try pair.planAlloc(FixtureApi, t.allocator, "abcdYabcdXXabcdXYz", options, shorter_models);
    defer for (shorter) |plan| t.allocator.free(plan.tokens);
    try t.expect(containsMatch(shorter[0], 4, 11));
    try expectSame(FixtureApi, t.allocator, "abcdYabcdXXabcdXYz", options, shorter_models, FixtureApi.scalarPlan);
}

test "modeled pair shares one index and scan while preserving full nice and budget stops" {
    const left = try Prices.init(t.allocator, 32);
    defer left.deinit(t.allocator);
    const right = try Prices.init(t.allocator, 32);
    defer right.deinit(t.allocator);
    const models = [2]FixtureApi.Model{ left.model(false), right.model(false) };
    const input = "abcd!abcd?abcd#";
    FixtureApi.index_builds = 0;
    FixtureApi.match_calls = 0;
    FixtureApi.bound_rejections = 0;
    const plans = try pair.planAlloc(FixtureApi, t.allocator, input, .{}, models);
    defer for (plans) |plan| t.allocator.free(plan.tokens);
    try t.expectEqual(@as(usize, 1), FixtureApi.index_builds);
    const pair_calls = FixtureApi.match_calls;
    FixtureApi.match_calls = 0;
    for (models) |model| {
        const scalar = try FixtureApi.scalarPlan(t.allocator, input, .{}, model);
        t.allocator.free(scalar.tokens);
    }
    try t.expect(pair_calls != 0);
    try t.expect(pair_calls * 2 < FixtureApi.match_calls);
    try t.expect(FixtureApi.bound_rejections != 0);
    left.distances[5] = 100;
    left.distances[10] = 1;
    right.distances[5] = 1;
    right.distances[10] = 100;
    for ([_]FixtureApi.Options{
        .{ .max_chain = 0 },                     .{ .max_chain = 1 },      .{ .max_chain = 5 },
        .{ .max_chain = 6 },                     .{ .max_candidates = 0 }, .{ .max_candidates = 1 },
        .{ .max_candidates = 2, .nice_len = 4 }, .{ .max_match = 4 },      .{ .min_match = 5, .nice_len = 5 },
        .{ .window_len = 0 },
    }) |options| try expectSame(FixtureApi, t.allocator, input, options, models, FixtureApi.scalarPlan);
    const rejected_prefixes = try pair.planAlloc(FixtureApi, t.allocator, input, .{ .max_chain = 1 }, models);
    defer for (rejected_prefixes) |plan| t.allocator.free(plan.tokens);
    try t.expectEqual(@as(usize, 0), rejected_prefixes[0].stats.matches);
    const full_stop = try pair.planAlloc(FixtureApi, t.allocator, input, .{ .max_match = 4 }, models);
    defer for (full_stop) |plan| t.allocator.free(plan.tokens);
    // The nearest full-length candidate stops search even when it loses on
    // price and a farther equal-length candidate would have been cheaper.
    try t.expect(!containsMatch(full_stop[0], 4, 10));
}

test "modeled pair preserves longest length on equal modeled cost" {
    const prices = try Prices.init(t.allocator, 32);
    defer prices.deinit(t.allocator);
    prices.literal['a'] = 32;
    @memset(prices.length, 30);
    prices.length[4] = 20;
    prices.length[7] = 1;
    prices.length[8] = 9;
    const models = [2]FixtureApi.Model{ prices.model(false), prices.model(false) };
    const input = "abcdabcdabcdZ";
    const plans = try pair.planAlloc(FixtureApi, t.allocator, input, .{}, models);
    defer for (plans) |plan| t.allocator.free(plan.tokens);
    try t.expect(containsMatch(plans[0], 8, 4));
    try expectSame(FixtureApi, t.allocator, input, .{}, models, FixtureApi.scalarPlan);
}

test "modeled pair exact bound consumes candidate budget and never rejects one winning side" {
    const left = try Prices.init(t.allocator, 32);
    defer left.deinit(t.allocator);
    const right = try Prices.init(t.allocator, 32);
    defer right.deinit(t.allocator);
    const input = "abcd!abcd?abcd#abcd$";
    for ([_]*const Prices{ &left, &right }) |prices| {
        prices.distances[5] = 2;
        prices.distances[10] = 3;
        prices.distances[15] = 1;
    }
    const models = [2]FixtureApi.Model{ left.model(false), right.model(false) };
    FixtureApi.bound_rejections = 0;
    const limited = try pair.planAlloc(FixtureApi, t.allocator, input, .{ .max_candidates = 2 }, models);
    defer for (limited) |plan| t.allocator.free(plan.tokens);
    try t.expect(FixtureApi.bound_rejections != 0);
    try t.expect(!containsMatch(limited[0], 4, 15));
    try expectSame(FixtureApi, t.allocator, input, .{ .max_candidates = 2 }, models, FixtureApi.scalarPlan);
    const expanded = try pair.planAlloc(FixtureApi, t.allocator, input, .{ .max_candidates = 3 }, models);
    defer for (expanded) |plan| t.allocator.free(plan.tokens);
    try t.expect(containsMatch(expanded[0], 4, 15));
    try expectSame(FixtureApi, t.allocator, input, .{ .max_candidates = 3 }, models, FixtureApi.scalarPlan);

    // The second candidate is dominated only for side zero. Side one must
    // reach its cheaper distance, so the shared match query cannot be pruned.
    left.distances[5] = 1;
    left.distances[10] = 50;
    right.distances[5] = 50;
    right.distances[10] = 1;
    const asymmetric = try pair.planAlloc(FixtureApi, t.allocator, "abcd!abcd?abcd#", .{ .max_candidates = 2 }, models);
    defer for (asymmetric) |plan| t.allocator.free(plan.tokens);
    try t.expect(containsMatch(asymmetric[0], 4, 5));
    try t.expect(containsMatch(asymmetric[1], 4, 10));
    try expectSame(FixtureApi, t.allocator, "abcd!abcd?abcd#", .{ .max_candidates = 2 }, models, FixtureApi.scalarPlan);
}

const Dictionary = struct {
    calls: usize = 0,
    fn find(context: *anyopaque, position: usize) ?FixtureApi.DictionaryMatch {
        const self: *Dictionary = @ptrCast(@alignCast(context));
        self.calls += 1;
        return switch (position) {
            0 => .{ .output_len = 8, .copy_len = 4, .address = (1 << 18) - 1 },
            8 => .{ .output_len = 6, .copy_len = 5, .address = 17 },
            else => null,
        };
    }
};

test "modeled pair queries immutable dictionary once and preserves packed payload and stats" {
    const prices = try Prices.init(t.allocator, 32);
    defer prices.deinit(t.allocator);
    var dictionary: Dictionary = .{};
    const options: FixtureApi.Options = .{ .dictionary = .{ .context = &dictionary, .find = Dictionary.find }, .dictionary_cost = 1 };
    const input = "abcdefghijklmn";
    const models = [2]FixtureApi.Model{ prices.model(false), prices.model(true) };
    const plans = try pair.planAlloc(FixtureApi, t.allocator, input, options, models);
    defer for (plans) |plan| t.allocator.free(plan.tokens);
    try t.expectEqual(input.len - 4 + 1, dictionary.calls);
    for (plans) |plan| {
        try t.expectEqual(@as(usize, 2), plan.stats.matches);
        try t.expectEqual(input.len, plan.stats.matched_bytes);
        try t.expectEqual(FixtureApi.Token.Match.initDictionary(8, 4, (1 << 18) - 1).dictionary, plan.tokens[0].match.dictionary);
        try t.expectEqual(@as(u16, 0), plan.tokens[0].match.distance);
        try t.expectEqual(@as(u16, 8), plan.tokens[0].match.length);
    }
    try expectSame(FixtureApi, t.allocator, input, options, models, FixtureApi.scalarPlan);
}

test "modeled pair supports empty repetitive binary and contextual fixtures with independent owners" {
    const left = try Prices.init(t.allocator, 64);
    defer left.deinit(t.allocator);
    const right = try Prices.init(t.allocator, 64);
    defer right.deinit(t.allocator);
    right.literal['a'] = 19;
    right.context['a'] = 3;
    const models = [2]FixtureApi.Model{ left.model(false), right.model(true) };
    const binary = [_]u8{ 0, 255, 128, 7, 9, 0, 255, 128, 7, 9, 0, 255, 128, 7, 8, 0, 255, 128, 7, 9 };
    for ([_][]const u8{ "", "a", "abc", "abcd", "a" ** 128, "abc 123\tabc 123\nabc 123!", &binary }) |input|
        try expectSame(FixtureApi, t.allocator, input, .{ .window_len = 64 }, models, FixtureApi.scalarPlan);
    const input = "abcdabcdabcdxyz";
    const first = try pair.planAlloc(FixtureApi, t.allocator, input, .{}, models);
    defer for (first) |plan| t.allocator.free(plan.tokens);
    const saved = try t.allocator.dupe(FixtureApi.Token, first[0].tokens);
    defer t.allocator.free(saved);
    const second = try pair.planAlloc(FixtureApi, t.allocator, input, .{}, models);
    defer for (second) |plan| t.allocator.free(plan.tokens);
    try t.expect(first[0].tokens.ptr != first[1].tokens.ptr);
    try t.expect(first[0].tokens.ptr != second[0].tokens.ptr);
    try t.expectEqual(saved.len, first[0].tokens.len);
    for (saved, first[0].tokens) |expected, actual| try t.expect(std.meta.eql(expected, actual));
}

test "modeled pair rejects unsupported geometry invalid prices and overflowing raw u32 edges" {
    const prices = try Prices.init(t.allocator, 65535);
    defer prices.deinit(t.allocator);
    const input = try t.allocator.alloc(u8, 65537);
    defer t.allocator.free(input);
    @memset(input, 'a');
    const models = [2]FixtureApi.Model{ prices.model(false), prices.model(false) };
    try t.expect(!pair.supported(FixtureApi, input, .{}, models));
    try t.expect(!pair.supported(FixtureApi, input[0..16], .{ .min_match = 3 }, models));
    try t.expect(!pair.supported(FixtureApi, input[0..16], .{ .window_len = 65536 }, models));
    @memset(prices.literal, 65535);
    @memset(prices.length, 65535);
    @memset(prices.distances[1..], 65535);
    try t.expect(!pair.supported(FixtureApi, input[0..65536], .{ .window_len = 65535 }, models));
    const builds = FixtureApi.index_builds;
    try t.expectError(error.InvalidBlockPlan, pair.planAlloc(FixtureApi, t.allocator, input[0..65536], .{ .window_len = 65535 }, models));
    try t.expectEqual(builds, FixtureApi.index_builds);
    @memset(prices.literal, 65534);
    try t.expect(pair.supported(FixtureApi, input[0..65536], .{ .window_len = 65535 }, models));
    @memset(prices.context, 65535);
    const high_context = [2]FixtureApi.Model{ prices.model(true), prices.model(false) };
    try t.expect(!pair.supported(FixtureApi, input[0..65536], .{ .window_len = 65535 }, high_context));
    var invalid = models;
    invalid[1].distance = &.{};
    try t.expect(!pair.supported(FixtureApi, input[0..16], .{}, invalid));
    invalid = models;
    invalid[1].literal_context = prices.context[0..1023];
    try t.expect(!pair.supported(FixtureApi, input[0..16], .{}, invalid));
    prices.literal[0] = 0;
    try t.expect(!pair.supported(FixtureApi, input[0..16], .{}, models));
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    const prices = try Prices.init(t.allocator, 32);
    defer prices.deinit(t.allocator);
    const models = [2]FixtureApi.Model{ prices.model(false), prices.model(true) };
    const plans = try pair.planAlloc(FixtureApi, allocator, "abcdabcdabcdabcduvwxyz", .{}, models);
    defer for (plans) |plan| allocator.free(plan.tokens);
    try t.expect(plans[0].tokens.len != 0 and plans[1].tokens.len != 0);
}

test "modeled pair allocation failure releases index workspace and either completed output" {
    try t.checkAllAllocationFailures(t.allocator, allocationCase, .{});
}
