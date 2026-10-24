const std = @import("std");
const controls = @import("../encode/controls.zig");
const source_mod = @import("controlled_source.zig");
const history_limit = @import("history_limit.zig");

pub const Record = source_mod.Record;
pub const Source = source_mod.Source;
pub const Parameters = source_mod.Parameters;

const hash_bits = 16;
const hash_size = 1 << hash_bits;
const invalid = std.math.maxInt(u32);
const minimum_match = 4;
const max_block_len = 128 * 1024;
const max_window_len = history_limit.max_history_len;
const recent_seed_span = max_block_len;
const seed_slots = hash_size;
const Match = struct { position: usize = 0, length: usize = 0, distance: usize = 0 };

/// Opt-in single-hash fast and dual 4/8-byte dfast engines. Tables have fixed
/// size; the virtual prefix is sampled in place and never copied or allocated.
/// Acceleration applies to prefix insertion and the growing miss stride.
pub fn planReuse(records: *std.ArrayList(Record), allocator: std.mem.Allocator, source: Source, parameters: Parameters) !void {
    if ((parameters.strategy != .fast and parameters.strategy != .double_fast) or
        parameters.acceleration == 0 or parameters.acceleration > controls.max_acceleration or
        parameters.search_budget != controls.legacy_search_budget or
        source.block.len > max_block_len or source.window_len == 0 or source.window_len > max_window_len or
        source.dictionary.len > source.window_len or source.history.len > source.window_len - source.dictionary.len)
        return error.InvalidBlockPlan;
    try source.validate();
    records.clearRetainingCapacity();
    if (parameters.profile) |profile| {
        profile.available = true;
        profile.controls_used = true;
        profile.resolved_strategy = parameters.strategy;
        profile.fast_acceleration = parameters.acceleration;
    }
    if (source.block.len < minimum_match) return;
    if (parameters.strategy == .double_fast) return planDouble(records, allocator, source, parameters);
    return planSingle(records, allocator, source, parameters);
}

fn planSingle(records: *std.ArrayList(Record), allocator: std.mem.Allocator, source: Source, parameters: Parameters) !void {
    var tables: Tables(false) = .{};
    tables.seed(source, parameters);
    var reps = parameters.initial_repeated_offsets;
    var anchor: usize = 0;
    var position: usize = 0;
    var misses: usize = 0;
    const end = source.block.len - minimum_match + 1;
    while (position < end) {
        notePosition(parameters.profile);
        var best = probeReps(source, position, anchor, reps, parameters.profile);
        const candidate = tables.lookupShort(source, position, parameters.profile);
        const found = candidateMatch(source, position, candidate, minimum_match);
        if (prefer(found, best, reps, anchor)) best = found;

        // A one-byte-literal rep0 probe is a legal Zstd repcode even when the
        // current anchor has zero literals and its rep0 mapping is unavailable.
        var ahead_tested = false;
        if (best.length == 0 and position + 1 < end) {
            const next = probeRepAhead(source, position + 1, reps[0], parameters.profile);
            ahead_tested = next.tested;
            if (next.found.length != 0) best = next.found;
        }
        if (best.length == 0) {
            const step = missStep(parameters.acceleration, misses, end - position);
            noteSkipped(parameters.profile, step, ahead_tested);
            position += step;
            misses += 1;
            continue;
        }
        extendBackwards(source, anchor, &best);
        try append(records, allocator, &reps, anchor, best, parameters.profile);
        tables.seedMatch(source, best, parameters.acceleration);
        anchor = best.position + best.length;
        position = anchor;
        misses = 0;
    }
}

fn planDouble(records: *std.ArrayList(Record), allocator: std.mem.Allocator, source: Source, parameters: Parameters) !void {
    var tables: Tables(true) = .{};
    tables.seed(source, parameters);
    var reps = parameters.initial_repeated_offsets;
    var anchor: usize = 0;
    var position: usize = 0;
    var misses: usize = 0;
    const end = source.block.len - minimum_match + 1;
    while (position < end) {
        notePosition(parameters.profile);
        var best = probeReps(source, position, anchor, reps, parameters.profile);
        const long_candidate = tables.lookupLong(source, position, parameters.profile);
        const long_match = candidateMatch(source, position, long_candidate, 8);
        if (prefer(long_match, best, reps, anchor)) best = long_match;
        const short_candidate = tables.lookupShort(source, position, parameters.profile);
        const short_match = candidateMatch(source, position, short_candidate, minimum_match);
        if (prefer(short_match, best, reps, anchor)) best = short_match;

        // The long table has a distinct collision domain. When the current
        // short prefix is weak, pay one literal only for a longer next match.
        var ahead_tested = false;
        if (best.length < 8 and position + 1 < end) {
            const next_position = position + 1;
            const repeated = probeRepAhead(source, next_position, reps[0], parameters.profile);
            ahead_tested = repeated.tested;
            var next = repeated.found;
            if (source.block.len - next_position >= 8) {
                if (!ahead_tested) notePosition(parameters.profile);
                ahead_tested = true;
                const next_candidate = tables.lookupLong(source, next_position, parameters.profile);
                const next_long = candidateMatch(source, next_position, next_candidate, 8);
                if (prefer(next_long, next, reps, anchor)) next = next_long;
            }
            if (next.length != 0 and (best.length == 0 or next.length > best.length + 1 or
                (next.length == best.length + 1 and repeatRank(next.distance, reps, next.position - anchor) < repeatRank(best.distance, reps, best.position - anchor))))
                best = next;
        }
        if (best.length == 0) {
            const step = missStep(parameters.acceleration, misses, end - position);
            noteSkipped(parameters.profile, step, ahead_tested);
            position += step;
            misses += 1;
            continue;
        }
        extendBackwards(source, anchor, &best);
        try append(records, allocator, &reps, anchor, best, parameters.profile);
        tables.seedMatch(source, best, parameters.acceleration);
        anchor = best.position + best.length;
        position = anchor;
        misses = 0;
    }
}

fn Tables(comptime dual: bool) type {
    return struct {
        short: [hash_size]u32 = @splat(invalid),
        long: if (dual) [hash_size]u32 else [0]u32 = if (dual) @splat(invalid) else .{},

        const Self = @This();
        fn insert(self: *Self, source: Source, absolute: usize) void {
            if (absolute > source.totalLen() or source.totalLen() - absolute < 4) return;
            self.short[hash4(source, absolute)] = @intCast(absolute);
            if (dual and source.totalLen() - absolute >= 8)
                self.long[hash8(source, absolute)] = @intCast(absolute);
        }
        fn seedRange(self: *Self, source: Source, start: usize, end: usize, step: usize, profile: ?*controls.Profile) void {
            var position = start;
            while (position < end) {
                if (source.totalLen() - position >= 4) {
                    self.insert(source, position);
                    noteSeed(profile, source.origin(position));
                }
                position += @min(step, end - position);
            }
        }
        fn seed(self: *Self, source: Source, parameters: Parameters) void {
            const prefix = source.prefixLen();
            const stride: usize = parameters.acceleration;
            if (prefix <= recent_seed_span) {
                self.seedRange(source, 0, prefix, stride, parameters.profile);
            } else {
                const recent = prefix - recent_seed_span;
                // A bounded scan across the older window, followed by a denser
                // recent scan. The full retained dictionary still needs no heap.
                const sparse_step = std.math.mul(usize, ceilDiv(recent, seed_slots), stride) catch recent;
                self.seedRange(source, 0, recent, @min(recent, sparse_step), parameters.profile);
                self.seedRange(source, recent, prefix, 2 * stride, parameters.profile);
            }
            // Preserve slice boundaries and the last short/long anchors. These
            // hashes may span dictionary/history or history/current-block bytes.
            for ([_]usize{ source.dictionary.len, prefix }) |boundary| {
                for ([_]usize{ 8, 4, 3, 2, 1 }) |back| {
                    if (boundary >= back) {
                        const position = boundary - back;
                        if (position < prefix and source.totalLen() - position >= 4) {
                            self.insert(source, position);
                            noteSeed(parameters.profile, source.origin(position));
                        }
                    }
                }
            }
        }
        fn lookupShort(self: *Self, source: Source, position: usize, profile: ?*controls.Profile) u32 {
            const absolute = source.prefixLen() + position;
            const key = hash4(source, absolute);
            const previous = self.short[key];
            self.short[key] = @intCast(absolute);
            if (profile) |p| p.add("short_hash_probes", 1);
            return previous;
        }
        fn lookupLong(self: *Self, source: Source, position: usize, profile: ?*controls.Profile) u32 {
            if (source.block.len - position < 8) return invalid;
            const absolute = source.prefixLen() + position;
            const key = hash8(source, absolute);
            const previous = self.long[key];
            self.long[key] = @intCast(absolute);
            if (profile) |p| p.add("long_hash_probes", 1);
            return previous;
        }
        fn seedMatch(self: *Self, source: Source, found: Match, acceleration: u32) void {
            const end = found.position + found.length;
            const stride = @min(@as(usize, acceleration), found.length);
            self.insert(source, source.prefixLen() + found.position);
            if (stride < found.length) self.insert(source, source.prefixLen() + found.position + stride);
            self.insert(source, source.prefixLen() + end - stride);
            self.insert(source, source.prefixLen() + end - 1);
        }
    };
}

fn ceilDiv(n: usize, d: usize) usize {
    return n / d + @intFromBool(n % d != 0);
}
fn missStep(acceleration: u32, misses: usize, remaining: usize) usize {
    return @min(remaining, @as(usize, acceleration) * (1 + misses / 64));
}
fn notePosition(profile: ?*controls.Profile) void {
    if (profile) |p| p.add("positions_tested", 1);
}
fn noteSkipped(profile: ?*controls.Profile, step: usize, ahead_tested: bool) void {
    if (profile) |p| p.add("skipped_positions", step - 1 - @intFromBool(ahead_tested and step > 1));
}
fn noteSeed(profile: ?*controls.Profile, origin: source_mod.Origin) void {
    if (profile) |p| switch (origin) {
        .dictionary => p.add("dictionary_seed_positions", 1),
        .history => p.add("history_seed_positions", 1),
        .block => unreachable,
    };
}
fn candidateMatch(source: Source, position: usize, candidate: u32, minimum: usize) Match {
    if (candidate == invalid) return .{};
    const found = source.match(position, candidate, minimum);
    return .{ .position = position, .length = found.length, .distance = found.distance };
}
fn probeReps(source: Source, position: usize, anchor: usize, reps: [3]usize, profile: ?*controls.Profile) Match {
    const distances = if (position != anchor) reps else [3]usize{ reps[1], reps[2], reps[0] -| 1 };
    const absolute = source.prefixLen() + position;
    var best = Match{};
    for (distances, 0..) |distance, i| {
        if (distance == 0 or distance > absolute or distance > source.window_len) continue;
        var duplicate = false;
        for (distances[0..i]) |prior| if (prior == distance) {
            duplicate = true;
        };
        if (duplicate) continue;
        if (profile) |p| p.add("rep_probes", 1);
        const found = source.match(position, absolute - distance, minimum_match);
        const candidate = Match{ .position = position, .length = found.length, .distance = found.distance };
        if (prefer(candidate, best, reps, anchor)) best = candidate;
    }
    return best;
}
fn probeRepAhead(source: Source, position: usize, distance: usize, profile: ?*controls.Profile) struct { found: Match, tested: bool } {
    const absolute = source.prefixLen() + position;
    if (distance == 0 or distance > absolute or distance > source.window_len) return .{ .found = .{}, .tested = false };
    notePosition(profile);
    if (profile) |p| p.add("rep_probes", 1);
    const found = source.match(position, absolute - distance, minimum_match);
    return .{ .found = .{ .position = position, .length = found.length, .distance = found.distance }, .tested = true };
}
fn prefer(candidate: Match, current: Match, reps: [3]usize, anchor: usize) bool {
    if (candidate.length != current.length) return candidate.length > current.length;
    if (candidate.length == 0) return false;
    const candidate_rank = repeatRank(candidate.distance, reps, candidate.position - anchor);
    const current_rank = repeatRank(current.distance, reps, current.position - anchor);
    return candidate_rank < current_rank or (candidate_rank == current_rank and candidate.distance < current.distance);
}
fn repeatRank(distance: usize, reps: [3]usize, literal_len: usize) u8 {
    const eligible = if (literal_len != 0) reps else [3]usize{ reps[1], reps[2], reps[0] -| 1 };
    for (eligible, 0..) |offset, i| if (offset != 0 and distance == offset) return @intCast(i);
    return 3;
}
fn updateReps(reps: *[3]usize, distance: usize, literal_len: usize) void {
    const old = reps.*;
    const rank = repeatRank(distance, old, literal_len);
    if (literal_len != 0 and rank == 0) return;
    if ((literal_len != 0 and rank == 1) or (literal_len == 0 and rank == 0)) {
        reps.* = .{ old[1], old[0], old[2] };
    } else if ((literal_len != 0 and rank == 2) or (literal_len == 0 and rank == 1)) {
        reps.* = .{ old[2], old[0], old[1] };
    } else {
        reps.* = .{ distance, old[0], old[1] };
    }
}
fn extendBackwards(source: Source, anchor: usize, found: *Match) void {
    while (found.position > anchor and source.prefixLen() + found.position > found.distance and
        source.block[found.position - 1] == source.byteAt(source.prefixLen() + found.position - found.distance - 1))
    {
        found.position -= 1;
        found.length += 1;
    }
}
fn append(records: *std.ArrayList(Record), allocator: std.mem.Allocator, reps: *[3]usize, anchor: usize, found: Match, profile: ?*controls.Profile) !void {
    const literal_len = found.position - anchor;
    try records.append(allocator, .{ .literal_len = literal_len, .distance = found.distance, .match_len = found.length, .match_end = found.position + found.length });
    updateReps(reps, found.distance, literal_len);
    if (profile) |p| {
        p.add("parser_matches", 1);
        p.add("parser_matched_bytes", found.length);
    }
}

fn wordScalar(comptime width: usize, source: Source, position: usize) std.meta.Int(.unsigned, width * 8) {
    const Word = std.meta.Int(.unsigned, width * 8);
    var value: Word = 0;
    inline for (0..width) |i| value |= @as(Word, source.byteAt(position + i)) << (i * 8);
    return value;
}
fn word(comptime width: usize, source: Source, position: usize) std.meta.Int(.unsigned, width * 8) {
    const Word = std.meta.Int(.unsigned, width * 8);
    if (position < source.dictionary.len) {
        if (source.dictionary.len - position >= width) return std.mem.readInt(Word, source.dictionary[position..][0..width], .little);
    } else if (position < source.prefixLen()) {
        const offset = position - source.dictionary.len;
        if (source.history.len - offset >= width) return std.mem.readInt(Word, source.history[offset..][0..width], .little);
    } else {
        return std.mem.readInt(Word, source.block[position - source.prefixLen() ..][0..width], .little);
    }
    return wordScalar(width, source, position);
}
fn hash4(source: Source, position: usize) usize {
    return (word(4, source, position) *% @as(u32, 0x9e3779b1)) >> (32 - hash_bits);
}
fn hash8(source: Source, position: usize) usize {
    return @intCast((word(8, source, position) *% @as(u64, 0x9e3779b185ebca87)) >> (64 - hash_bits));
}

test "Zstd controlled fast word loads match scalar across all virtual boundaries" {
    const text = "dictionary segment/history segment/block segment 0123456789";
    for (0..text.len + 1) |first| {
        for (first..text.len + 1) |second| {
            const source = Source.init(text[0..first], text[first..second], text[second..], max_window_len);
            for (0..text.len - 3) |position| try std.testing.expectEqual(wordScalar(4, source, position), word(4, source, position));
            for (0..text.len - 7) |position| try std.testing.expectEqual(wordScalar(8, source, position), word(8, source, position));
        }
    }
}
test "Zstd controlled fast repeat queues follow literal-sensitive standard repcodes" {
    var reps = [3]usize{ 8, 4, 16 };
    updateReps(&reps, 4, 0);
    try std.testing.expectEqual([3]usize{ 4, 8, 16 }, reps);
    updateReps(&reps, 16, 0);
    try std.testing.expectEqual([3]usize{ 16, 4, 8 }, reps);
    updateReps(&reps, 15, 0);
    try std.testing.expectEqual([3]usize{ 15, 16, 4 }, reps);
    updateReps(&reps, 15, 1);
    try std.testing.expectEqual([3]usize{ 15, 16, 4 }, reps);
}
test {
    _ = @import("controlled_fast_tests.zig");
}
