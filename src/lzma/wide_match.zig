const std = @import("std");
const core = @import("../core.zig");
const lz77 = @import("../lz77.zig");

pub const max_window_len: usize = 256 * 1024;
pub const max_match_len: usize = 273;
const min_match_len: usize = 3;
const hash_table_size: usize = 1 << 16;

pub const Token = union(enum) {
    literal: u8,
    match: Match,

    pub const Match = struct {
        length: u16,
        distance: u32,
    };
};

pub const Plan = struct {
    tokens: []Token,
    stats: lz77.PlanStats,

    pub fn deinit(self: *Plan, allocator: std.mem.Allocator) void {
        allocator.free(self.tokens);
        self.* = undefined;
    }
};

pub const Options = struct {
    window_len: usize,
    max_chain: usize = 64,
    nice_len: usize = 64,
};

const Candidate = struct {
    length: usize = 0,
    distance: usize = 0,
};

/// Greedy dictionary planner for LZMA distances wider than the repository's
/// shared u16 LZ77 token. The complete `dictionary ++ input` index is bounded
/// by the caller-selected window plus one 64 KiB LZMA2 chunk.
pub fn planAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    dictionary: []const u8,
    options: Options,
) !Plan {
    if (options.window_len <= std.math.maxInt(u16) or
        options.window_len > max_window_len or
        dictionary.len > options.window_len or
        dictionary.len > std.math.maxInt(i32) or
        input.len > std.math.maxInt(i32) - dictionary.len)
        return error.InvalidBlockPlan;

    const head = try allocator.alloc(i32, hash_table_size);
    defer allocator.free(head);
    @memset(head, -1);
    const total_len = dictionary.len + input.len;
    const previous = try allocator.alloc(i32, total_len);
    defer allocator.free(previous);
    @memset(previous, -1);

    var position: usize = 0;
    while (position < dictionary.len) : (position += 1)
        insert(dictionary, input, position, head, previous);

    var tokens: std.ArrayList(Token) = .empty;
    errdefer tokens.deinit(allocator);
    try tokens.ensureTotalCapacity(allocator, input.len);
    var stats: lz77.PlanStats = .{};
    var input_position: usize = 0;
    while (input_position < input.len) {
        const current = dictionary.len + input_position;
        const best = findBest(
            dictionary,
            input,
            current,
            options,
            head,
            previous,
        );
        if (accept(best)) {
            tokens.appendAssumeCapacity(.{ .match = .{
                .length = @intCast(best.length),
                .distance = @intCast(best.distance),
            } });
            stats.matches += 1;
            stats.matched_bytes += best.length;
            const end = input_position + best.length;
            while (input_position < end) : (input_position += 1)
                insert(dictionary, input, dictionary.len + input_position, head, previous);
            continue;
        }
        tokens.appendAssumeCapacity(.{ .literal = input[input_position] });
        stats.literals += 1;
        insert(dictionary, input, current, head, previous);
        input_position += 1;
    }
    return .{
        .tokens = try tokens.toOwnedSlice(allocator),
        .stats = stats,
    };
}

fn findBest(
    dictionary: []const u8,
    input: []const u8,
    current: usize,
    options: Options,
    head: []const i32,
    previous: []const i32,
) Candidate {
    const input_position = current - dictionary.len;
    if (input.len - input_position < min_match_len) return .{};
    const maximum = @min(max_match_len, input.len - input_position);
    const bucket = hashAt(dictionary, input, current) orelse return .{};
    const earliest = current -| options.window_len;
    var candidate_i = head[bucket];
    var checked: usize = 0;
    var best: Candidate = .{};
    while (candidate_i >= 0 and checked < options.max_chain) {
        if (best.length == maximum) break;
        const candidate: usize = @intCast(candidate_i);
        if (candidate < earliest or candidate >= current) break;
        const required_prefix = @max(best.length, min_match_len - 1);
        if (byteAt(dictionary, input, candidate + required_prefix) !=
            input[input_position + required_prefix])
        {
            candidate_i = previous[candidate];
            continue;
        }
        checked += 1;
        const length = matchLength(dictionary, input, candidate, current, maximum);
        if (length >= min_match_len and length > best.length) {
            best = .{ .length = length, .distance = current - candidate };
            if (length >= options.nice_len) break;
        }
        candidate_i = previous[candidate];
    }
    return best;
}

fn accept(candidate: Candidate) bool {
    if (candidate.length < min_match_len or candidate.distance == 0) return false;
    // A three-byte match at a wide distance can cost more than its literals in
    // LZMA's direct-distance tail. Keep those marginal cases literal while
    // admitting all four-byte-or-longer wide matches.
    return candidate.length >= 4 or candidate.distance <= 4096;
}

fn insert(
    dictionary: []const u8,
    input: []const u8,
    position: usize,
    head: []i32,
    previous: []i32,
) void {
    const bucket = hashAt(dictionary, input, position) orelse return;
    previous[position] = head[bucket];
    head[bucket] = @intCast(position);
}

fn hashAt(dictionary: []const u8, input: []const u8, position: usize) ?usize {
    if (dictionary.len + input.len - position < min_match_len) return null;
    const value = (@as(usize, byteAt(dictionary, input, position)) << 16) |
        (@as(usize, byteAt(dictionary, input, position + 1)) << 8) |
        byteAt(dictionary, input, position + 2);
    return (value *% 2654435761) >> 16 & (hash_table_size - 1);
}

fn matchLength(
    dictionary: []const u8,
    input: []const u8,
    candidate: usize,
    current: usize,
    maximum: usize,
) usize {
    var length: usize = 0;
    while (length < maximum and
        byteAt(dictionary, input, candidate + length) == input[current - dictionary.len + length])
        length += 1;
    return length;
}

fn byteAt(dictionary: []const u8, input: []const u8, position: usize) u8 {
    return if (position < dictionary.len)
        dictionary[position]
    else
        input[position - dictionary.len];
}

test "LZMA wide dictionary planner emits and replays u32 distances" {
    const dictionary_len = 128 * 1024;
    const dictionary = try std.testing.allocator.alloc(u8, dictionary_len);
    defer std.testing.allocator.free(dictionary);
    var state: u32 = 0x243f_6a88;
    for (dictionary) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    const input = dictionary[0..8192];
    var plan = try planAlloc(std.testing.allocator, input, dictionary, .{
        .window_len = dictionary_len,
    });
    defer plan.deinit(std.testing.allocator);

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);
    var saw_wide = false;
    for (plan.tokens) |token| switch (token) {
        .literal => |byte| try output.append(std.testing.allocator, byte),
        .match => |match| {
            saw_wide = saw_wide or match.distance > std.math.maxInt(u16);
            for (0..match.length) |_| {
                const logical = dictionary.len + output.items.len;
                const source = logical - match.distance;
                const byte = if (source < dictionary.len)
                    dictionary[source]
                else
                    output.items[source - dictionary.len];
                try output.append(std.testing.allocator, byte);
            }
        },
    };
    try std.testing.expect(saw_wide);
    try std.testing.expectEqualSlices(u8, input, output.items);
    try std.testing.expectEqual(input.len, plan.stats.matched_bytes + plan.stats.literals);
    try std.testing.expect(plan.stats.matched_bytes >= input.len - 2);
}

test "LZMA wide dictionary planner releases every allocation failure" {
    const dictionary = try std.testing.allocator.alloc(u8, 128 * 1024);
    defer std.testing.allocator.free(dictionary);
    for (dictionary, 0..) |*byte, index| byte.* = @truncate(index * 37 + index / 11);
    const input = dictionary[0..1024];
    const Test = struct {
        fn run(allocator: std.mem.Allocator, history: []const u8, plain: []const u8) !void {
            var plan = try planAlloc(allocator, plain, history, .{ .window_len = history.len });
            defer plan.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{ dictionary, input },
    );
}
