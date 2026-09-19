const std = @import("std");
const builtin = @import("builtin");
const lz77 = @import("../../../lz77.zig");
const sequence_plan = @import("sequence_plan.zig");

const text_section = switch (builtin.object_format) {
    .elf => ".vort_zstd_fast_records",
    .macho => "__TEXT,__vort_zstd_rec",
    .coff => ".text$vort_zstd_fast_records",
    else => ".text",
};

const short_hash_bits = 8;
const long_hash_bits = 11;
const short_hash_size = 1 << short_hash_bits;
const long_hash_size = 1 << long_hash_bits;
const invalid_position = std.math.maxInt(u32);
const record_capacity_divisor = 64;
const max_long_rep_probe_distance = 512;

pub const input_len_min = 64 * 1024 + 1;
pub const input_len_max = 128 * 1024;

const Match = struct {
    position: usize = 0,
    length: usize = 0,
    distance: usize = 0,
};

/// Wide-block double-fast parser that records only match metadata. The token
/// parser remains independent so compact-record code generation cannot perturb
/// its established small-block hot path. Differential tests in the parent
/// module keep both state machines behavior-exact.
pub fn planReuse(
    records: *std.ArrayList(sequence_plan.Record),
    allocator: std.mem.Allocator,
    input: []const u8,
    options: lz77.GreedyOptions,
) !lz77.PlanStats {
    if (input.len < input_len_min or input.len > input_len_max or options.min_match < 4 or options.max_match < 4)
        return error.InvalidBlockPlan;

    records.clearRetainingCapacity();
    // A 128 KiB fast block in the measured mixed workload emits almost exactly
    // one sequence per 64 input bytes. Reserve that compact 8-byte record
    // density once instead of repeatedly moving a growing record buffer. This
    // remains far below zstd's block_len / min_match worst-case allocation and
    // caller-owned capacity is retained for subsequent blocks.
    try records.ensureTotalCapacityPrecise(allocator, input.len / record_capacity_divisor);
    var short_table: [short_hash_size]u32 = @splat(invalid_position);
    var long_table: [long_hash_size]u32 = @splat(invalid_position);
    var reps = [3]usize{ 1, 4, 8 };
    var stats: lz77.PlanStats = .{};
    var anchor: usize = 0;
    var position: usize = 0;

    while (position + 4 <= input.len) {
        const rep_position = if (position == anchor and
            matchAtDistance(input, position, reps[0], options).length == options.max_match)
            position
        else
            position + 1;
        if (rep_position + 4 <= input.len and reps[0] <= max_long_rep_probe_distance) {
            const rep_match = matchAtDistance(input, rep_position, reps[0], options);
            if (rep_match.length != 0) {
                try storeMatch(records, allocator, &stats, &reps, anchor, rep_match);
                anchor = rep_match.position + rep_match.length;
                position = anchor;
                try consumeImmediateReps(records, allocator, input, options, &short_table, &long_table, &stats, &reps, &anchor, &position);
                continue;
            }
        }

        const short_hash = shortHash(input, position);
        const short_candidate = short_table[short_hash];
        short_table[short_hash] = @intCast(position);
        const long_candidate = if (position + 8 <= input.len) candidate: {
            const long_hash = longHash(input, position);
            const previous = long_table[long_hash];
            long_table[long_hash] = @intCast(position);
            break :candidate previous;
        } else invalid_position;

        var best = candidateMatch(input, position, long_candidate, options, 8);
        const short_match = candidateMatch(input, position, short_candidate, options, 4);
        if (preferMatch(short_match, best, reps, position - anchor)) best = short_match;

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
            for (reps[1..]) |distance| {
                if (distance > position) continue;
                const recent = matchAtDistance(input, position, distance, options);
                if (recent.length + 1 >= best.length) {
                    best = recent;
                    break;
                }
            }
        }

        while (best.position > anchor and best.position > best.distance and
            input[best.position - 1] == input[best.position - best.distance - 1])
        {
            best.position -= 1;
            best.length += 1;
        }
        best.length = @min(best.length, options.max_match);
        try storeMatch(records, allocator, &stats, &reps, anchor, best);
        anchor = best.position + best.length;

        if (best.position + 1 < anchor) insertPosition(input, best.position + 1, &short_table, &long_table);
        if (best.position + 2 < anchor and best.position + 10 <= input.len)
            long_table[longHash(input, best.position + 2)] = @intCast(best.position + 2);
        if (anchor >= 2) insertPosition(input, anchor - 2, &short_table, &long_table);
        if (anchor >= 1) insertPosition(input, anchor - 1, &short_table, &long_table);
        position = anchor;
        try consumeImmediateReps(records, allocator, input, options, &short_table, &long_table, &stats, &reps, &anchor, &position);
    }

    stats.literals += input.len - anchor;
    return stats;
}

noinline fn consumeImmediateReps(
    records: *std.ArrayList(sequence_plan.Record),
    allocator: std.mem.Allocator,
    input: []const u8,
    options: lz77.GreedyOptions,
    short_table: *[short_hash_size]u32,
    long_table: *[long_hash_size]u32,
    stats: *lz77.PlanStats,
    reps: *[3]usize,
    anchor: *usize,
    position: *usize,
) linksection(text_section) !void {
    while (position.* + 4 <= input.len) {
        const immediate = matchAtDistance(input, position.*, reps[1], options);
        if (immediate.length == 0) return;
        insertPosition(input, position.*, short_table, long_table);
        try storeMatch(records, allocator, stats, reps, anchor.*, immediate);
        anchor.* = immediate.position + immediate.length;
        position.* = anchor.*;
    }
}

noinline fn storeMatch(
    records: *std.ArrayList(sequence_plan.Record),
    allocator: std.mem.Allocator,
    stats: *lz77.PlanStats,
    reps: *[3]usize,
    anchor: usize,
    match: Match,
) linksection(text_section) !void {
    std.debug.assert(match.position >= anchor);
    const literal_len = match.position - anchor;
    try sequence_plan.appendTrusted(
        records,
        allocator,
        literal_len,
        match.distance,
        match.length,
        match.position + match.length,
    );
    stats.literals += literal_len;
    stats.matches += 1;
    stats.matched_bytes += match.length;
    updateReps(reps, match.distance, literal_len);
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

fn preferMatch(candidate: Match, current: Match, reps: [3]usize, literal_len: usize) bool {
    if (candidate.length != current.length) return candidate.length > current.length;
    if (candidate.length == 0) return false;
    const candidate_rank = repeatRank(candidate.distance, reps, literal_len);
    const current_rank = repeatRank(current.distance, reps, literal_len);
    if (candidate_rank != current_rank) return candidate_rank < current_rank;
    return candidate.distance < current.distance;
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
    return .{ .position = position, .length = matchLength(input, position - distance, position, maximum), .distance = distance };
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
