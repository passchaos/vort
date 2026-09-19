const std = @import("std");
const lz77 = @import("../../lz77.zig");
const sequence_plan = @import("double_fast/sequence_plan.zig");
const sequence_parser = @import("double_fast/sequence_parser.zig");

// Upstream dfast gives both tables enough index bits to avoid letting common
// four-byte JSON/source prefixes continuously evict useful candidates. These
// bounds still fit comfortably in caller stack space for Vort's 128 KiB block.
const short_hash_bits = 8;
const long_hash_bits = 11;
const short_hash_size = 1 << short_hash_bits;
const long_hash_size = 1 << long_hash_bits;
const invalid_position = std.math.maxInt(u32);
const wide_input_threshold = 64 * 1024;
const initial_token_capacity = 64;
pub const max_input_len = 128 * 1024;
pub const sequence_plan_input_min = sequence_parser.input_len_min;
// Long recent offsets are still available through the hash tables. Restrict
// eager rep0 probing to the range where it measured as a reliable win: farther
// rep0 matches displaced cheaper local structure on JSON and binary blocks.
const max_long_rep_probe_distance = 512;

const Match = struct {
    position: usize = 0,
    length: usize = 0,
    distance: usize = 0,
};

/// Experimental Zstd double-fast parser. The control flow follows upstream
/// zstd's `zstd_double_fast.c`: a four-byte table supplies cheap nearby
/// matches, an eight-byte table protects longer matches from short-prefix
/// collisions, rep0 is tested one byte ahead, and rep1 is tested immediately
/// after every stored match.
///
/// The parser is exposed through Zstd's diagnostic stage and used as the cheap
/// half of a production consensus probe. Its recent-offset updates mirror
/// Zstd's literal-length-sensitive repcode rules, while its output remains
/// ordinary LZ77 distances so the production sequence writer is still the
/// wire-format authority. Level-aware production accepts it early only when the independent
/// repeat-beam parser emits the same complete token stream and statistics.
pub fn planReuse(
    tokens: *std.ArrayList(lz77.Token),
    allocator: std.mem.Allocator,
    input: []const u8,
    options: lz77.GreedyOptions,
) !lz77.PlanStats {
    if (input.len > max_input_len or options.min_match < 4 or options.max_match < 4)
        return error.InvalidBlockPlan;

    tokens.clearRetainingCapacity();
    if (input.len > wide_input_threshold)
        try tokens.ensureTotalCapacityPrecise(allocator, initial_token_capacity);
    var short_table: [short_hash_size]u32 = @splat(invalid_position);
    var long_table: [long_hash_size]u32 = @splat(invalid_position);
    var reps = [3]usize{ 1, 4, 8 };
    var stats: lz77.PlanStats = .{};
    var anchor: usize = 0;
    var position: usize = 0;

    while (position + 4 <= input.len) {
        // After an exact max-length chunk the same distance usually continues
        // at the current anchor. Prefer that direct continuation. Otherwise,
        // upstream's position+1 probe avoids the special zero-literal repcode
        // mapping and cheaply captures a match after one pending literal.
        const rep_position = if (position == anchor and
            matchAtDistance(input, position, reps[0], options).length == options.max_match)
            position
        else
            position + 1;
        if (rep_position + 4 <= input.len and reps[0] <= max_long_rep_probe_distance) {
            const rep_match = matchAtDistance(input, rep_position, reps[0], options);
            if (rep_match.length != 0) {
                try storeMatch(tokens, allocator, input, &stats, &reps, anchor, rep_match);
                anchor = rep_match.position + rep_match.length;
                position = anchor;
                try consumeImmediateReps(tokens, allocator, input, options, &short_table, &long_table, &stats, &reps, &anchor, &position);
                continue;
            }
        }

        const short_candidate = short_table[shortHash(input, position)];
        const long_candidate = if (position + 8 <= input.len) long_table[longHash(input, position)] else invalid_position;
        insertPosition(input, position, &short_table, &long_table);

        var best = candidateMatch(input, position, long_candidate, options, 8);
        const short_match = candidateMatch(input, position, short_candidate, options, 4);
        if (preferMatch(short_match, best, reps, position - anchor)) best = short_match;

        // A four-byte hit may be a short prefix collision. Upstream probes the
        // long table one byte ahead before committing; this recovers a longer
        // sequence while charging only the skipped byte as a literal.
        if (best.length != 0 and best.length < 8 and position + 9 <= input.len) {
            const next_long_candidate = long_table[longHash(input, position + 1)];
            const next_long = candidateMatch(input, position + 1, next_long_candidate, options, 8);
            if (next_long.length > best.length + 1 or
                (next_long.length == best.length + 1 and
                    repeatRank(next_long.distance, reps, position + 1 - anchor) <
                        repeatRank(best.distance, reps, position - anchor)))
            {
                best = next_long;
            }
        }

        if (best.length == 0) {
            position += 1;
            continue;
        }
        if (reps[0] <= position) {
            const current_rep = matchAtDistance(input, position, reps[0], options);
            if (current_rep.length + 1 >= best.length and
                repeatRank(current_rep.distance, reps, position - anchor) <
                    repeatRank(best.distance, reps, position - anchor))
            {
                best = current_rep;
            }
        }
        if (repeatRank(best.distance, reps, position - anchor) == 3) {
            // A direct hash match changes the recent-offset queue and can make
            // a long structured run expensive. Only on that path, check the
            // two other existing repcodes and tolerate at most a one-byte
            // length deficit. This is narrower than probing all three offsets
            // at every position and mirrors upstream's preference for
            // repcodes around hash hits.
            for (reps[1..]) |distance| {
                if (distance > position) continue;
                const recent = matchAtDistance(input, position, distance, options);
                if (recent.length + 1 >= best.length) {
                    best = recent;
                    break;
                }
            }
        }

        // Complete a match backwards through pending literals. Apart from
        // improving length this also preserves upstream's invariant that a
        // hash hit can pull the anchor back, but never across the prior match.
        while (best.position > anchor and best.position > best.distance and
            input[best.position - 1] == input[best.position - best.distance - 1])
        {
            best.position -= 1;
            best.length += 1;
        }
        best.length = @min(best.length, options.max_match);
        try storeMatch(tokens, allocator, input, &stats, &reps, anchor, best);
        anchor = best.position + best.length;

        // Populate only the first two and final two positions of a match. The
        // second long-hash anchor mirrors upstream's `curr + 2` insertion and
        // protects useful eight-byte candidates from the skipped match body,
        // without turning a fast parser into a full-span indexing pass.
        if (best.position + 1 < anchor) insertPosition(input, best.position + 1, &short_table, &long_table);
        if (best.position + 2 < anchor and best.position + 10 <= input.len)
            long_table[longHash(input, best.position + 2)] = @intCast(best.position + 2);
        if (anchor >= 2) insertPosition(input, anchor - 2, &short_table, &long_table);
        if (anchor >= 1) insertPosition(input, anchor - 1, &short_table, &long_table);
        position = anchor;
        try consumeImmediateReps(tokens, allocator, input, options, &short_table, &long_table, &stats, &reps, &anchor, &position);
    }

    try appendLiterals(tokens, allocator, input[anchor..], &stats);
    return stats;
}

pub const SequenceRecord = sequence_plan.Record;

pub fn planSequencesReuse(
    records: *std.ArrayList(SequenceRecord),
    allocator: std.mem.Allocator,
    input: []const u8,
    options: lz77.GreedyOptions,
) !lz77.PlanStats {
    return sequence_parser.planReuse(records, allocator, input, options);
}

fn consumeImmediateReps(
    tokens: *std.ArrayList(lz77.Token),
    allocator: std.mem.Allocator,
    input: []const u8,
    options: lz77.GreedyOptions,
    short_table: *[short_hash_size]u32,
    long_table: *[long_hash_size]u32,
    stats: *lz77.PlanStats,
    reps: *[3]usize,
    anchor: *usize,
    position: *usize,
) !void {
    while (position.* + 4 <= input.len) {
        // With zero literals Zstd's repcode 0 names rep1, not rep0. This swap
        // is therefore both a parser shortcut and the exact history transition
        // the sequence writer will select for the requested distance.
        const immediate = matchAtDistance(input, position.*, reps[1], options);
        if (immediate.length == 0) return;
        insertPosition(input, position.*, short_table, long_table);
        try storeMatch(tokens, allocator, input, stats, reps, anchor.*, immediate);
        anchor.* = immediate.position + immediate.length;
        position.* = anchor.*;
    }
}

fn storeMatch(
    tokens: *std.ArrayList(lz77.Token),
    allocator: std.mem.Allocator,
    input: []const u8,
    stats: *lz77.PlanStats,
    reps: *[3]usize,
    anchor: usize,
    match: Match,
) !void {
    std.debug.assert(match.position >= anchor);
    try appendLiterals(tokens, allocator, input[anchor..match.position], stats);
    try tokens.append(allocator, .{ .match = .{
        .length = @intCast(match.length),
        .distance = @intCast(match.distance),
    } });
    stats.matches += 1;
    stats.matched_bytes += match.length;
    updateReps(reps, match.distance, match.position - anchor);
}

fn appendLiterals(
    tokens: *std.ArrayList(lz77.Token),
    allocator: std.mem.Allocator,
    literals: []const u8,
    stats: *lz77.PlanStats,
) !void {
    const appended = try tokens.addManyAsSlice(allocator, literals.len);
    for (literals, appended) |literal, *token| token.* = .{ .literal = literal };
    stats.literals += literals.len;
}

fn updateReps(reps: *[3]usize, distance: usize, literal_len: usize) void {
    if (literal_len != 0) {
        if (distance == reps[0]) return;
        if (distance == reps[1]) {
            std.mem.swap(usize, &reps[0], &reps[1]);
            return;
        }
        if (distance == reps[2]) {
            const old0 = reps[0];
            const old1 = reps[1];
            reps.* = .{ reps[2], old0, old1 };
            return;
        }
    } else {
        if (distance == reps[1]) {
            std.mem.swap(usize, &reps[0], &reps[1]);
            return;
        }
        if (distance == reps[2]) {
            // Capture the old queue before assigning. Aggregate assignment is
            // not a parallel swap in Zig: reading `reps` again after writing
            // element zero would otherwise collapse all entries to old rep2.
            const old0 = reps[0];
            const old1 = reps[1];
            reps.* = .{ reps[2], old0, old1 };
            return;
        }
        if (reps[0] > 1 and distance == reps[0] - 1) {
            const old0 = reps[0];
            const old1 = reps[1];
            reps.* = .{ distance, old0, old1 };
            return;
        }
    }
    const old0 = reps[0];
    const old1 = reps[1];
    reps.* = .{ distance, old0, old1 };
}

test "double-fast zero-literal rep2 rotates the previous offset queue" {
    var reps = [3]usize{ 1, 4, 8 };
    updateReps(&reps, 8, 0);
    try std.testing.expectEqual([3]usize{ 8, 1, 4 }, reps);
}

test "double-fast equal matches prefer repcodes then shorter distance" {
    const reps = [3]usize{ 8, 4, 16 };
    try std.testing.expect(preferEqualLengthDistance(8, 32, reps, 1));
    try std.testing.expect(!preferEqualLengthDistance(4, 8, reps, 1));
    try std.testing.expect(preferEqualLengthDistance(32, 64, reps, 1));
    try std.testing.expect(!preferEqualLengthDistance(64, 32, reps, 1));
}

test "double-fast wide token reservation reports initial allocation failure" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const allocator = failing.allocator();
    {
        var tokens: std.ArrayList(lz77.Token) = .empty;
        defer tokens.deinit(allocator);
        try tokens.append(allocator, .{ .literal = 0xa5 });
        const successful_allocations = failing.allocations;
        failing.fail_index = failing.alloc_index;
        failing.resize_fail_index = failing.resize_index;

        try std.testing.expectError(
            error.OutOfMemory,
            planReuse(
                &tokens,
                allocator,
                "x" ** (wide_input_threshold + 1),
                .{ .window_len = 32 * 1024, .min_match = 4, .max_match = 258 },
            ),
        );
        try std.testing.expectEqual(@as(usize, 0), tokens.items.len);
        try std.testing.expect(failing.has_induced_failure);
        try std.testing.expectEqual(successful_allocations, failing.allocations);
    }
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

fn preferMatch(candidate: Match, current: Match, reps: [3]usize, literal_len: usize) bool {
    if (candidate.length != current.length) return candidate.length > current.length;
    if (candidate.length == 0) return false;
    return preferEqualLengthDistance(candidate.distance, current.distance, reps, literal_len);
}

fn preferEqualLengthDistance(candidate: usize, current: usize, reps: [3]usize, literal_len: usize) bool {
    const candidate_rank = repeatRank(candidate, reps, literal_len);
    const current_rank = repeatRank(current, reps, literal_len);
    if (candidate_rank != current_rank) return candidate_rank < current_rank;
    return candidate < current;
}

fn repeatRank(distance: usize, reps: [3]usize, literal_len: usize) u8 {
    if (literal_len != 0) {
        if (distance == reps[0]) return 0;
        if (distance == reps[1]) return 1;
        if (distance == reps[2]) return 2;
    } else {
        if (distance == reps[1]) return 0;
        if (distance == reps[2]) return 1;
        if (reps[0] > 1 and distance == reps[0] - 1) return 2;
    }
    return 3;
}

fn matchAtDistance(input: []const u8, position: usize, distance: usize, options: lz77.GreedyOptions) Match {
    if (distance == 0 or distance > position or distance > options.window_len) return .{};
    const maximum = @min(options.max_match, input.len - position);
    if (maximum < 4 or !equalPrefix(input, position - distance, position, 4)) return .{};
    return .{
        .position = position,
        .length = matchLength(input, position - distance, position, maximum),
        .distance = distance,
    };
}

fn candidateMatch(input: []const u8, position: usize, raw_candidate: u32, options: lz77.GreedyOptions, prefix_len: usize) Match {
    if (raw_candidate == invalid_position) return .{};
    const candidate: usize = raw_candidate;
    if (candidate >= position) return .{};
    const distance = position - candidate;
    if (distance > options.window_len) return .{};
    const maximum = @min(options.max_match, input.len - position);
    if (maximum < prefix_len or !equalPrefix(input, candidate, position, prefix_len)) return .{};
    return .{ .position = position, .length = matchLength(input, candidate, position, maximum), .distance = distance };
}

fn insertPosition(input: []const u8, position: usize, short_table: *[short_hash_size]u32, long_table: *[long_hash_size]u32) void {
    if (position + 4 <= input.len) short_table[shortHash(input, position)] = @intCast(position);
    if (position + 8 <= input.len) long_table[longHash(input, position)] = @intCast(position);
}

fn shortHash(input: []const u8, position: usize) usize {
    const word = std.mem.readInt(u32, input[position..][0..4], .little);
    return @intCast((word *% 0x9e37_79b1) >> (32 - short_hash_bits));
}

fn longHash(input: []const u8, position: usize) usize {
    const word = std.mem.readInt(u64, input[position..][0..8], .little);
    return @intCast((word *% 0x9e37_79b1_85eb_ca87) >> (64 - long_hash_bits));
}

fn equalPrefix(input: []const u8, a: usize, b: usize, len: usize) bool {
    return std.mem.eql(u8, input[a..][0..len], input[b..][0..len]);
}

fn matchLength(input: []const u8, a: usize, b: usize, maximum: usize) usize {
    var len: usize = 0;
    while (len + 8 <= maximum) : (len += 8) {
        const left = std.mem.readInt(u64, input[a + len ..][0..8], .little);
        const right = std.mem.readInt(u64, input[b + len ..][0..8], .little);
        if (left != right) return len + @ctz(left ^ right) / 8;
    }
    while (len < maximum and input[a + len] == input[b + len]) len += 1;
    return len;
}

test "double-fast verified prefixes preserve complete match lengths" {
    var input: [674]u8 = undefined;
    var state: u32 = 0x510e_527f;
    for (&input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[337..][0..258], input[0..258]);
    const options: lz77.GreedyOptions = .{ .window_len = 512, .max_match = 258 };

    for (0..259) |mismatch| {
        var probe = input;
        if (mismatch < 258) probe[337 + mismatch] = probe[mismatch] ^ 0xff;
        const expected_length = matchLength(&probe, 0, 337, 258);
        const expected = Match{
            .position = 337,
            .length = expected_length,
            .distance = 337,
        };
        const distance_match = matchAtDistance(&probe, 337, 337, options);
        const short_match = candidateMatch(&probe, 337, 0, options, 4);
        const long_match = candidateMatch(&probe, 337, 0, options, 8);
        try std.testing.expectEqual(if (expected_length >= 4) expected else Match{}, distance_match);
        try std.testing.expectEqual(if (expected_length >= 4) expected else Match{}, short_match);
        try std.testing.expectEqual(if (expected_length >= 8) expected else Match{}, long_match);
    }
}

test "double-fast compact sequence plan matches token plan" {
    var input: [max_input_len]u8 = undefined;
    var random_state: u32 = 0x3c6e_f372;
    for (&input, 0..) |*byte, index| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(random_state >> 16);
    }
    const options: lz77.GreedyOptions = .{ .window_len = 32 * 1024, .min_match = 4, .max_match = 258 };
    var expected: std.ArrayList(lz77.Token) = .empty;
    defer expected.deinit(std.testing.allocator);
    const expected_stats = try planReuse(&expected, std.testing.allocator, &input, options);

    var records: std.ArrayList(SequenceRecord) = .empty;
    defer records.deinit(std.testing.allocator);
    const actual_stats = try planSequencesReuse(&records, std.testing.allocator, &input, options);
    try std.testing.expectEqual(expected_stats, actual_stats);
    try std.testing.expectEqual(expected_stats.matches, records.items.len);

    var actual: std.ArrayList(lz77.Token) = .empty;
    defer actual.deinit(std.testing.allocator);
    try std.testing.expect(try sequence_plan.materializeTokens(&actual, std.testing.allocator, &input, records.items));
    try std.testing.expectEqualSlices(lz77.Token, expected.items, actual.items);
}

test "double-fast compact sequence plan materializes sparse wide input" {
    const input = "abcdefghijklmnopqrstuvwxyz012345" ** 2049;
    const options: lz77.GreedyOptions = .{ .window_len = 32 * 1024, .min_match = 4, .max_match = 258 };
    var expected: std.ArrayList(lz77.Token) = .empty;
    defer expected.deinit(std.testing.allocator);
    const expected_stats = try planReuse(&expected, std.testing.allocator, input, options);
    try std.testing.expect(expected_stats.matches <= 512);

    var records: std.ArrayList(SequenceRecord) = .empty;
    defer records.deinit(std.testing.allocator);
    const actual_stats = try planSequencesReuse(&records, std.testing.allocator, input, options);
    try std.testing.expectEqual(expected_stats, actual_stats);
    var actual: std.ArrayList(lz77.Token) = .empty;
    defer actual.deinit(std.testing.allocator);
    try std.testing.expect(try sequence_plan.materializeTokens(&actual, std.testing.allocator, input, records.items));
    try std.testing.expectEqualSlices(lz77.Token, expected.items, actual.items);
}

test "double-fast compact sequence plan releases allocation failures" {
    var input: [sequence_plan_input_min]u8 = undefined;
    var random_state: u32 = 0xa54f_f53a;
    for (&input, 0..) |*byte, index| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(random_state >> 16);
    }
    const options: lz77.GreedyOptions = .{ .window_len = 32 * 1024, .min_match = 4, .max_match = 258 };
    const Test = struct {
        fn run(allocator: std.mem.Allocator, bytes: []const u8, parser_options: lz77.GreedyOptions) !void {
            var records: std.ArrayList(SequenceRecord) = .empty;
            defer records.deinit(allocator);
            const stats = try planSequencesReuse(&records, allocator, bytes, parser_options);
            try std.testing.expectEqual(stats.matches, records.items.len);
            try std.testing.expectEqual(bytes.len, stats.literals + stats.matched_bytes);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{ &input, options });
}
