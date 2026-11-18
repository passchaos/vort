const std = @import("std");

/// A stateful forward parser for the Brotli q10/q11 frontier. The state is
/// `(position, insert_bucket)`, so a match/dictionary command is priced with
/// the literal run that precedes it instead of a flat proxy. The first slice
/// keeps the exact insert length bucketed (0, 1, 2, 3, 4-7, 8-15, 16-31,
/// 32-63, 64+); callers can refine the bucket representative later.
pub const Match = struct { length: usize, distance: usize };
pub const DictionaryMatch = struct { output_len: usize, copy_len: usize, address: usize };
pub const CandidateList = struct { matches: []const Match, dictionary: ?DictionaryMatch };
pub const Kind = enum { literal, lz77, dictionary };
pub const Provider = struct {
    context: *anyopaque,
    candidates: *const fn (context: *anyopaque, position: usize) CandidateList,
};
/// `position` is the source position of the transition so literal prices can
/// use the actual byte and match prices can see the remaining input.
pub const PriceFn = *const fn (context: *const anyopaque, position: usize, insert_len: usize, kind: Kind, copy_len: usize, distance: usize) u32;

pub const Options = struct {
    min_match: usize = 4,
    max_match: usize = 258,
};

pub const Token = union(enum) {
    literal: u8,
    lz77: Match,
    dictionary: DictionaryMatch,
};

pub const bucket_count = 9;
const bucket_starts = [bucket_count]usize{ 0, 1, 2, 3, 4, 8, 16, 32, 64 };

pub fn bucketFor(insert_len: usize) usize {
    var bucket: usize = 0;
    while (bucket + 1 < bucket_count and insert_len >= bucket_starts[bucket + 1]) : (bucket += 1) {}
    return bucket;
}

fn representative(bucket: usize) usize {
    return bucket_starts[bucket];
}

const Prev = struct {
    position: u32 = 0,
    bucket: u8 = 0,
    kind: Kind = .literal,
    copy_len: u16 = 0,
    distance: u32 = 0,
};

pub fn plan(
    allocator: std.mem.Allocator,
    input: []const u8,
    provider: Provider,
    price_context: *const anyopaque,
    price: PriceFn,
    options: Options,
) ![]Token {
    const n = input.len;
    const states = std.math.mul(usize, n + 1, bucket_count) catch return error.IntegerOverflow;
    const costs = try allocator.alloc(u32, states);
    defer allocator.free(costs);
    const prev = try allocator.alloc(Prev, states);
    defer allocator.free(prev);
    @memset(costs, std.math.maxInt(u32));
    costs[0] = 0;

    for (0..n) |position| {
        for (0..bucket_count) |bucket| {
            const cost = costs[position * bucket_count + bucket];
            if (cost == std.math.maxInt(u32)) continue;
            const insert_len = representative(bucket);

            {
                const next_bucket = bucketFor(insert_len + 1);
                const next_index = (position + 1) * bucket_count + next_bucket;
                const next_cost = try addCost(cost, price(price_context, position, insert_len, .literal, 1, 0));
                if (next_cost < costs[next_index]) {
                    costs[next_index] = next_cost;
                    prev[next_index] = .{ .position = @intCast(position), .bucket = @intCast(bucket), .kind = .literal };
                }
            }

            const candidates = provider.candidates(provider.context, position);
            for (candidates.matches) |match| {
                if (match.length < options.min_match or match.length > options.max_match or
                    match.length > n - position or match.distance == 0 or match.distance > position)
                    continue;
                const next_index = (position + match.length) * bucket_count;
                const next_cost = try addCost(cost, price(price_context, position, insert_len, .lz77, match.length, match.distance));
                if (next_cost < costs[next_index]) {
                    costs[next_index] = next_cost;
                    prev[next_index] = .{
                        .position = @intCast(position),
                        .bucket = @intCast(bucket),
                        .kind = .lz77,
                        .copy_len = @intCast(match.length),
                        .distance = @intCast(match.distance),
                    };
                }
            }

            if (candidates.dictionary) |dictionary| {
                if (dictionary.output_len == 0 or dictionary.copy_len == 0 or
                    dictionary.output_len > n - position)
                    continue;
                const next_index = (position + dictionary.output_len) * bucket_count;
                const next_cost = try addCost(cost, price(price_context, position, insert_len, .dictionary, dictionary.copy_len, dictionary.address));
                if (next_cost < costs[next_index]) {
                    costs[next_index] = next_cost;
                    prev[next_index] = .{
                        .position = @intCast(position),
                        .bucket = @intCast(bucket),
                        .kind = .dictionary,
                        .copy_len = @intCast(dictionary.copy_len),
                        .distance = @intCast(dictionary.address),
                    };
                }
            }
        }
    }

    var best_bucket: usize = 0;
    var best_cost: u32 = std.math.maxInt(u32);
    for (0..bucket_count) |bucket| {
        const cost = costs[n * bucket_count + bucket];
        if (cost < best_cost) {
            best_cost = cost;
            best_bucket = bucket;
        }
    }
    if (best_cost == std.math.maxInt(u32)) return error.InvalidBlockPlan;

    var reversed: std.ArrayList(Token) = .empty;
    errdefer reversed.deinit(allocator);
    var position = n;
    var bucket = best_bucket;
    while (position > 0) {
        const step = prev[position * bucket_count + bucket];
        switch (step.kind) {
            .literal => {
                try reversed.append(allocator, .{ .literal = input[position - 1] });
                position -= 1;
            },
            .lz77 => {
                try reversed.append(allocator, .{ .lz77 = .{ .length = step.copy_len, .distance = step.distance } });
                position = step.position;
            },
            .dictionary => {
                try reversed.append(allocator, .{ .dictionary = .{
                    .output_len = position - step.position,
                    .copy_len = step.copy_len,
                    .address = step.distance,
                } });
                position = step.position;
            },
        }
        bucket = step.bucket;
    }
    std.mem.reverse(Token, reversed.items);
    return reversed.toOwnedSlice(allocator);
}

fn addCost(a: u32, b: u32) !u32 {
    return std.math.add(u32, a, b) catch error.IntegerOverflow;
}

const TestProvider = struct {
    matches: []const Match,
    dictionary: ?DictionaryMatch,

    fn candidates(context: *anyopaque, position: usize) CandidateList {
        _ = position;
        const self: *const TestProvider = @ptrCast(@alignCast(context));
        return .{ .matches = self.matches, .dictionary = self.dictionary };
    }
};

fn testPrice(context: *const anyopaque, position: usize, insert_len: usize, kind: Kind, copy_len: usize, distance: usize) u32 {
    _ = context;
    _ = position;
    _ = distance;
    return switch (kind) {
        .literal => 8,
        .lz77 => @intCast(16 + insert_len / 4 + copy_len),
        .dictionary => @intCast(16 + insert_len / 4 + copy_len),
    };
}

test "stateful plan emits literals when no candidates exist" {
    var provider: TestProvider = .{ .matches = &.{}, .dictionary = null };
    const tokens = try plan(std.testing.allocator, "abcdef", .{
        .context = &provider,
        .candidates = TestProvider.candidates,
    }, undefined, testPrice, .{});
    defer std.testing.allocator.free(tokens);
    try std.testing.expectEqual(@as(usize, 6), tokens.len);
    for (tokens, 0..) |token, index| switch (token) {
        .literal => |byte| try std.testing.expectEqual("abcdef"[index], byte),
        else => return error.TestUnexpectedResult,
    };
}

test "stateful plan prefers a cheaper LZ77 match" {
    const matches = [_]Match{.{ .length = 6, .distance = 3 }};
    var provider: TestProvider = .{ .matches = &matches, .dictionary = null };
    const tokens = try plan(std.testing.allocator, "abcabcabc", .{
        .context = &provider,
        .candidates = TestProvider.candidates,
    }, undefined, testPrice, .{});
    defer std.testing.allocator.free(tokens);
    try std.testing.expectEqual(@as(usize, 4), tokens.len);
    try std.testing.expectEqualSlices(u8, "abc", &.{ tokens[0].literal, tokens[1].literal, tokens[2].literal });
    try std.testing.expectEqual(@as(usize, 6), tokens[3].lz77.length);
    try std.testing.expectEqual(@as(usize, 3), tokens[3].lz77.distance);
}

test "stateful plan prefers a cheaper dictionary copy" {
    const dictionary: DictionaryMatch = .{ .output_len = 4, .copy_len = 4, .address = 7 };
    var provider: TestProvider = .{ .matches = &.{}, .dictionary = dictionary };
    const tokens = try plan(std.testing.allocator, "word", .{
        .context = &provider,
        .candidates = TestProvider.candidates,
    }, undefined, testPrice, .{});
    defer std.testing.allocator.free(tokens);
    try std.testing.expectEqual(@as(usize, 1), tokens.len);
    try std.testing.expectEqual(@as(usize, 4), tokens[0].dictionary.output_len);
    try std.testing.expectEqual(@as(usize, 4), tokens[0].dictionary.copy_len);
    try std.testing.expectEqual(@as(usize, 7), tokens[0].dictionary.address);
}

test "stateful insert buckets cover the documented boundaries" {
    try std.testing.expectEqual(@as(usize, 0), bucketFor(0));
    try std.testing.expectEqual(@as(usize, 1), bucketFor(1));
    try std.testing.expectEqual(@as(usize, 2), bucketFor(2));
    try std.testing.expectEqual(@as(usize, 3), bucketFor(3));
    try std.testing.expectEqual(@as(usize, 4), bucketFor(4));
    try std.testing.expectEqual(@as(usize, 4), bucketFor(7));
    try std.testing.expectEqual(@as(usize, 5), bucketFor(8));
    try std.testing.expectEqual(@as(usize, 8), bucketFor(64));
    try std.testing.expectEqual(@as(usize, 8), bucketFor(1_000));
}

test "stateful plan returns an empty plan for empty input" {
    var provider: TestProvider = .{ .matches = &.{}, .dictionary = null };
    const tokens = try plan(std.testing.allocator, "", .{
        .context = &provider,
        .candidates = TestProvider.candidates,
    }, undefined, testPrice, .{});
    defer std.testing.allocator.free(tokens);
    try std.testing.expectEqual(@as(usize, 0), tokens.len);
}
