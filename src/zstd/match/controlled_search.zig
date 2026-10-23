const std = @import("std");
const controls = @import("../encode/controls.zig");
const source_mod = @import("controlled_source.zig");
pub const Record = source_mod.Record;
pub const Source = source_mod.Source;
pub const Parameters = source_mod.Parameters;
const Match = source_mod.Match;
const minimum_match = 3;
const hash_size = 1 << 15;
const prefix_sample_limit = 65536;
const invalid = std.math.maxInt(u32);
const beam_width = 4;
const candidate_limit = 16;

/// Three opt-in parsers over borrowed dictionary/history/block spans. Optimal
/// minimizes a fixed bit-price approximation within a four-state beam, not the
/// final adaptive FSE payload size. The frame writer owns wire offset codes.
/// Prefix storage is capped independently of the advertised window size.
pub fn planReuse(records: *std.ArrayList(Record), gpa: std.mem.Allocator, source: Source, parameters: Parameters) !void {
    if ((parameters.strategy != .greedy and parameters.strategy != .lazy and parameters.strategy != .optimal) or
        parameters.acceleration == 0 or parameters.acceleration > controls.max_acceleration or
        parameters.search_budget > controls.legacy_search_budget or source.window_len == 0 or
        source.block.len > 128 * 1024 or
        (parameters.strategy == .optimal and source.block.len > controls.optimal_block_limit))
        return error.InvalidBlockPlan;
    records.clearRetainingCapacity();
    errdefer records.clearRetainingCapacity();
    if (parameters.profile) |profile| {
        profile.available = true;
        profile.controls_used = true;
        profile.resolved_strategy = parameters.strategy;
        profile.fast_acceleration = parameters.acceleration;
    }
    if (parameters.search_budget == 0 or source.block.len < minimum_match) return;
    var index = try Index.init(gpa, source, parameters);
    defer index.deinit(gpa);
    if (parameters.strategy == .optimal)
        return planOptimal(records, gpa, source, parameters, index);
    return planLinear(records, gpa, source, parameters, index);
}

const PrefixNode = struct { position: usize, previous: u32 };
const Index = struct {
    prefix_head: []u32,
    prefix_nodes: []PrefixNode,
    block_previous: []u32,

    fn init(gpa: std.mem.Allocator, source: Source, parameters: Parameters) !Index {
        const prefix_head = try gpa.alloc(u32, hash_size);
        errdefer gpa.free(prefix_head);
        @memset(prefix_head, invalid);
        const prefix_capacity = @min(source.prefixLen(), prefix_sample_limit);
        const prefix_nodes = try gpa.alloc(PrefixNode, prefix_capacity);
        errdefer gpa.free(prefix_nodes);
        const block_previous = try gpa.alloc(u32, source.block.len);
        errdefer gpa.free(block_previous);
        @memset(block_previous, invalid);
        const block_head = try gpa.alloc(u32, hash_size);
        defer gpa.free(block_head);
        @memset(block_head, invalid);

        var index: Index = .{ .prefix_head = prefix_head, .prefix_nodes = prefix_nodes, .block_previous = block_previous };
        var seeded: usize = 0;
        // Leave room for segment boundaries and the last three prefix anchors.
        const regular_limit = prefix_sample_limit - 8;
        const base_stride = @max(@as(usize, 1), std.math.divCeil(usize, source.prefixLen(), regular_limit) catch 1);
        const sample_stride = std.math.mul(usize, base_stride, parameters.acceleration) catch std.math.maxInt(usize);
        var position: usize = 0;
        while (position < source.prefixLen() and seeded < prefix_capacity) {
            index.seed(source, position, &seeded, parameters.profile);
            position += @min(sample_stride, source.prefixLen() - position);
        }
        if (sample_stride > 1) {
            for ([_]usize{ 0, source.dictionary.len, source.prefixLen() -| 3, source.prefixLen() -| 2, source.prefixLen() -| 1 }) |edge| {
                if (edge < source.prefixLen() and edge % sample_stride != 0 and seeded < prefix_capacity)
                    index.seed(source, edge, &seeded, parameters.profile);
            }
        }
        // Current-block links use compact indices; source offsets and distances
        // stay usize. No allocation or chain entry is proportional to a window.
        for (0..source.block.len) |block_position| {
            if (block_position + minimum_match > source.block.len or block_position % parameters.acceleration != 0) continue;
            const key = hash(source, source.prefixLen() + block_position);
            block_previous[block_position] = block_head[key];
            block_head[key] = @intCast(block_position);
        }
        return index;
    }

    fn seed(self: Index, source: Source, position: usize, seeded: *usize, profile: ?*controls.Profile) void {
        if (source.totalLen() - position < minimum_match) return;
        const key = hash(source, position);
        self.prefix_nodes[seeded.*] = .{ .position = position, .previous = self.prefix_head[key] };
        self.prefix_head[key] = @intCast(seeded.*);
        seeded.* += 1;
        if (profile) |p| {
            if (source.origin(position) == .dictionary)
                p.add("dictionary_seed_positions", 1)
            else
                p.add("history_seed_positions", 1);
        }
    }

    fn deinit(self: Index, gpa: std.mem.Allocator) void {
        gpa.free(self.block_previous);
        gpa.free(self.prefix_nodes);
        gpa.free(self.prefix_head);
    }
};

const Work = struct {
    remaining: usize,
    profile: ?*controls.Profile,

    fn probe(self: *Work, comptime repeat: bool) bool {
        if (self.remaining == 0) return false;
        self.remaining -= 1;
        if (self.profile) |profile| {
            profile.add("candidate_checks", 1);
            profile.add(if (repeat) "rep_probes" else "short_hash_probes", 1);
        }
        return true;
    }

    fn transition(self: *Work) bool {
        if (self.remaining == 0) return false;
        self.remaining -= 1;
        if (self.profile) |profile| profile.add("optimal_transitions", 1);
        return true;
    }
};

const Cursor = struct {
    block: u32,
    prefix: u32,

    fn init(index: Index, source: Source, position: usize) Cursor {
        return .{ .block = index.block_previous[position], .prefix = index.prefix_head[hash(source, source.prefixLen() + position)] };
    }

    fn next(self: *Cursor, index: Index, source: Source) ?usize {
        if (self.block != invalid) {
            const position = self.block;
            self.block = index.block_previous[position];
            return source.prefixLen() + position;
        }
        if (self.prefix != invalid) {
            const node = index.prefix_nodes[self.prefix];
            self.prefix = node.previous;
            return node.position;
        }
        return null;
    }
};

fn findBest(index: Index, source: Source, position: usize, literal_len: usize, reps: [3]usize, parameters: Parameters) Match {
    if (parameters.profile) |profile| profile.add("positions_tested", 1);
    var work: Work = .{ .remaining = parameters.search_budget, .profile = parameters.profile };
    var best: Match = .{};
    const absolute = source.prefixLen() + position;
    for (repeatDistances(reps, literal_len)) |distance| {
        if (distance == 0 or distance > absolute or distance > source.window_len) continue;
        if (!work.probe(true)) break;
        const candidate = matchAt(source, position, absolute - distance);
        if (better(candidate, best, literal_len, reps)) best = candidate;
    }
    var cursor = Cursor.init(index, source, position);
    while (work.remaining > 0) {
        const candidate_position = cursor.next(index, source) orelse break;
        _ = work.probe(false);
        if (absolute - candidate_position > source.window_len) continue;
        const candidate = matchAt(source, position, candidate_position);
        if (better(candidate, best, literal_len, reps)) best = candidate;
    }
    return best;
}

fn planLinear(records: *std.ArrayList(Record), gpa: std.mem.Allocator, source: Source, parameters: Parameters, index: Index) !void {
    var position: usize = 0;
    var anchor: usize = 0;
    var reps = parameters.initial_repeated_offsets;
    var cached: ?Match = null;
    while (position + minimum_match <= source.block.len) {
        const literal_len = position - anchor;
        const best = cached orelse findBest(index, source, position, literal_len, reps, parameters);
        cached = null;
        if (best.length == 0) {
            const step = @min(@as(usize, parameters.acceleration), source.block.len - position);
            if (parameters.profile) |profile| profile.add("skipped_positions", step - 1);
            position += step;
            continue;
        }
        const lookahead: usize = 1;
        if (parameters.strategy == .lazy and lookahead <= source.block.len - position - minimum_match) {
            const next = findBest(index, source, position + lookahead, literal_len + lookahead, reps, parameters);
            if (gain(next, literal_len + lookahead, reps) > gain(best, literal_len, reps) + @as(i64, @intCast(lookahead * 8))) {
                cached = next;
                position += lookahead;
                if (parameters.profile) |profile| {
                    profile.add("lazy_deferrals", 1);
                    profile.add("skipped_positions", lookahead - 1);
                }
                continue;
            }
        }
        try records.append(gpa, .{ .literal_len = literal_len, .distance = best.distance, .match_len = best.length, .match_end = position + best.length });
        accountMatch(parameters.profile, best.length);
        reps = offsetPrice(literal_len, best.distance, reps).reps;
        position += best.length;
        anchor = position;
    }
}

fn better(candidate: Match, current: Match, literal_len: usize, reps: [3]usize) bool {
    if (candidate.length != current.length) return candidate.length > current.length;
    if (candidate.length == 0) return false;
    const candidate_price = sequencePrice(literal_len, candidate.length, candidate.distance, reps);
    const current_price = sequencePrice(literal_len, current.length, current.distance, reps);
    return candidate_price < current_price or (candidate_price == current_price and candidate.distance < current.distance);
}

fn gain(candidate: Match, literal_len: usize, reps: [3]usize) i64 {
    if (candidate.length == 0) return 0;
    return @as(i64, @intCast(candidate.length * 8)) - @as(i64, sequencePrice(literal_len, candidate.length, candidate.distance, reps));
}

const State = struct {
    cost: u32 = std.math.maxInt(u32),
    reps: [3]usize = .{ 1, 4, 8 },
    literal_len: u32 = 0,
    previous_position: u32 = 0,
    previous_slot: u8 = 0,
    match_len: u32 = 0,
    distance: usize = 0,
};
const Row = [beam_width]State;

fn planOptimal(records: *std.ArrayList(Record), gpa: std.mem.Allocator, source: Source, parameters: Parameters, index: Index) !void {
    const rows = try gpa.alloc(Row, source.block.len + 1);
    defer gpa.free(rows);
    for (rows) |*row| row.* = @splat(.{});
    rows[0][0] = .{ .cost = 0, .reps = parameters.initial_repeated_offsets };
    for (0..source.block.len) |position| {
        const row = rows[position];
        var count: usize = 0;
        for (row, 0..) |state, slot| {
            if (state.cost == std.math.maxInt(u32)) break;
            count += 1;
            insertState(&rows[position + 1], .{
                .cost = state.cost + 8,
                .reps = state.reps,
                .literal_len = state.literal_len + 1,
                .previous_position = @intCast(position),
                .previous_slot = @intCast(slot),
            });
        }
        if (position + minimum_match > source.block.len) continue;
        if (position % parameters.acceleration != 0) {
            if (parameters.profile) |profile| profile.add("skipped_positions", 1);
            continue;
        }
        if (parameters.profile) |profile| profile.add("positions_tested", 1);
        var work: Work = .{ .remaining = parameters.search_budget, .profile = parameters.profile };
        var indexed: [candidate_limit]Match = undefined;
        var indexed_count: usize = 0;
        var cursor = Cursor.init(index, source, position);
        const index_budget = if (work.remaining >= 2) @max(@as(usize, 1), work.remaining / 4) else 0;
        var checked: usize = 0;
        while (checked < index_budget and indexed_count < indexed.len) {
            const candidate_position = cursor.next(index, source) orelse break;
            _ = work.probe(false);
            checked += 1;
            if (source.prefixLen() + position - candidate_position > source.window_len) continue;
            const candidate = matchAt(source, position, candidate_position);
            if (candidate.length == 0) continue;
            var duplicate = false;
            for (indexed[0..indexed_count]) |other| duplicate = duplicate or other.distance == candidate.distance;
            if (!duplicate) {
                indexed[indexed_count] = candidate;
                indexed_count += 1;
            }
        }
        // The per-position allowance is shared by all states and includes both
        // exact candidate probes and match-length transitions. Literal edges
        // are mandatory progress edges and never consume search work.
        for (row[0..count], 0..) |state, slot| {
            var local: Work = .{ .remaining = work.remaining / (count - slot), .profile = work.profile };
            const before = local.remaining;
            var candidates: [candidate_limit + 3]Match = undefined;
            var candidate_count: usize = 0;
            const absolute = source.prefixLen() + position;
            for (repeatDistances(state.reps, state.literal_len)) |distance| {
                if (local.remaining < 2) break;
                if (distance == 0 or distance > absolute or distance > source.window_len) continue;
                var duplicate = false;
                for (candidates[0..candidate_count]) |other| duplicate = duplicate or other.distance == distance;
                if (duplicate) continue;
                _ = local.probe(true);
                const candidate = matchAt(source, position, absolute - distance);
                if (candidate.length > 0) {
                    candidates[candidate_count] = candidate;
                    candidate_count += 1;
                }
            }
            for (indexed[0..indexed_count]) |candidate| {
                var duplicate = false;
                for (candidates[0..candidate_count]) |other| duplicate = duplicate or other.distance == candidate.distance;
                if (!duplicate) {
                    candidates[candidate_count] = candidate;
                    candidate_count += 1;
                }
            }
            // Give every candidate its longest edge before considering shorter
            // alternatives; otherwise a tiny budget could lose long matches.
            for (candidates[0..candidate_count]) |candidate| {
                if (!local.transition()) break;
                extend(rows, position, slot, state, candidate.distance, candidate.length);
            }
            var length: usize = minimum_match;
            var maximum: usize = 0;
            for (candidates[0..candidate_count]) |candidate| maximum = @max(maximum, candidate.length);
            while (length < maximum and local.remaining > 0) : (length = nextLength(length, maximum)) {
                for (candidates[0..candidate_count]) |candidate| {
                    if (length >= candidate.length) continue;
                    if (!local.transition()) break;
                    extend(rows, position, slot, state, candidate.distance, length);
                }
                if (candidate_count == 0) break;
            }
            work.remaining -= before - local.remaining;
        }
    }
    var position = source.block.len;
    var slot: usize = 0;
    while (position > 0) {
        const state = rows[position][slot];
        if (state.match_len > 0) {
            const previous = rows[state.previous_position][state.previous_slot];
            try records.append(gpa, .{ .literal_len = previous.literal_len, .distance = state.distance, .match_len = state.match_len, .match_end = position });
            accountMatch(parameters.profile, state.match_len);
        }
        position = state.previous_position;
        slot = state.previous_slot;
    }
    std.mem.reverse(Record, records.items);
}

fn nextLength(length: usize, maximum: usize) usize {
    // Exhaust every short length. Larger blocks use deterministic logarithmic
    // endpoints plus each candidate's exact maximum, bounding transition work.
    if (length < 64) return length + 1;
    return @min(maximum, length + @max(@as(usize, 1), length / 4));
}

fn extend(rows: []Row, position: usize, slot: usize, state: State, distance: usize, length: usize) void {
    insertState(&rows[position + length], .{
        .cost = state.cost + sequencePrice(state.literal_len, length, distance, state.reps),
        .reps = offsetPrice(state.literal_len, distance, state.reps).reps,
        .previous_position = @intCast(position),
        .previous_slot = @intCast(slot),
        .match_len = @intCast(length),
        .distance = distance,
    });
}

fn insertState(row: *Row, candidate: State) void {
    var replace: usize = beam_width;
    for (row, 0..) |state, slot| {
        if (state.cost != std.math.maxInt(u32) and state.literal_len == candidate.literal_len and std.mem.eql(usize, &state.reps, &candidate.reps)) {
            if (!stateLess(candidate, state)) return;
            replace = slot;
            break;
        }
    }
    if (replace == beam_width) {
        if (!stateLess(candidate, row[beam_width - 1])) return;
        replace = beam_width - 1;
    }
    row[replace] = candidate;
    while (replace > 0 and stateLess(row[replace], row[replace - 1])) : (replace -= 1)
        std.mem.swap(State, &row[replace], &row[replace - 1]);
}

fn stateLess(a: State, b: State) bool {
    if (a.cost != b.cost) return a.cost < b.cost;
    if (a.literal_len != b.literal_len) return a.literal_len < b.literal_len;
    for (a.reps, b.reps) |left, right| if (left != right) return left < right;
    if (a.match_len != b.match_len) return a.match_len > b.match_len;
    if (a.distance != b.distance) return a.distance < b.distance;
    if (a.previous_position != b.previous_position) return a.previous_position < b.previous_position;
    return a.previous_slot < b.previous_slot;
}

fn repeatDistances(reps: [3]usize, literal_len: usize) [3]usize {
    return if (literal_len > 0) reps else .{ reps[1], reps[2], reps[0] -| 1 };
}

const OffsetPrice = struct { bits: u32, reps: [3]usize };
fn offsetPrice(literal_len: usize, distance: usize, reps: [3]usize) OffsetPrice {
    if (literal_len > 0) {
        if (distance == reps[0]) return .{ .bits = 0, .reps = reps };
        if (distance == reps[1]) return .{ .bits = 1, .reps = .{ reps[1], reps[0], reps[2] } };
        if (distance == reps[2]) return .{ .bits = 1, .reps = .{ reps[2], reps[0], reps[1] } };
    } else {
        if (distance == reps[1]) return .{ .bits = 0, .reps = .{ reps[1], reps[0], reps[2] } };
        if (distance == reps[2]) return .{ .bits = 1, .reps = .{ reps[2], reps[0], reps[1] } };
        if (reps[0] > 1 and distance == reps[0] - 1) return .{ .bits = 1, .reps = .{ distance, reps[0], reps[1] } };
    }
    return .{ .bits = @intCast(std.math.log2_int(usize, distance + 3)), .reps = .{ distance, reps[0], reps[1] } };
}

/// Fixed symbol prices: LL 5, ML 6, OF 5 bits, plus the exact format extra-bit
/// widths and literal-sensitive repeat selector. Literal bytes cost eight bits.
/// This intentionally omits adaptive tables and literal entropy coding.
pub fn sequencePrice(literal_len: usize, match_len: usize, distance: usize, reps: [3]usize) u32 {
    return 16 + literalExtraBits(literal_len) + matchExtraBits(match_len) + offsetPrice(literal_len, distance, reps).bits;
}

fn literalExtraBits(length: usize) u32 {
    if (length < 16) return 0;
    if (length < 24) return 1;
    if (length < 32) return 2;
    if (length < 48) return 3;
    if (length < 64) return 4;
    return @intCast(std.math.log2_int(usize, length));
}

fn matchExtraBits(length: usize) u32 {
    if (length < 35) return 0;
    if (length < 43) return 1;
    if (length < 51) return 2;
    if (length < 67) return 3;
    if (length < 99) return 4;
    if (length < 131) return 5;
    return @intCast(std.math.log2_int(usize, length - 3));
}

fn hash(source: Source, position: usize) usize {
    const word = @as(u32, source.byteAt(position)) | (@as(u32, source.byteAt(position + 1)) << 8) | (@as(u32, source.byteAt(position + 2)) << 16);
    return (word *% 2654435761) >> 17;
}

/// Exact vector extension across virtual span boundaries. Immutable lookahead
/// verifies overlapping copies by the same recurrence as Source.match's oracle.
fn matchAt(source: Source, position: usize, candidate: usize) Match {
    const absolute = source.prefixLen() + position;
    if (candidate >= absolute or absolute - candidate > source.window_len or source.block.len - position < minimum_match) return .{};
    var length: usize = 0;
    const maximum = source.block.len - position;
    while (length < maximum) {
        const at = candidate + length;
        const span = if (at < source.dictionary.len) source.dictionary[at..] else if (at < source.prefixLen()) source.history[at - source.dictionary.len ..] else source.block[at - source.prefixLen() ..];
        const limit = @min(span.len, maximum - length);
        var offset: usize = 0;
        while (offset + 32 <= limit) : (offset += 32) {
            const left: @Vector(32, u8) = span[offset..][0..32].*;
            const right: @Vector(32, u8) = source.block[position + length + offset ..][0..32].*;
            const different: u32 = ~@as(u32, @bitCast(left == right));
            if (different != 0) return finishMatch(length + offset + @ctz(different), absolute - candidate);
        }
        while (offset < limit) : (offset += 1)
            if (span[offset] != source.block[position + length + offset]) return finishMatch(length + offset, absolute - candidate);
        length += limit;
    }
    return finishMatch(length, absolute - candidate);
}

fn finishMatch(length: usize, distance: usize) Match {
    return if (length >= minimum_match) .{ .length = length, .distance = distance } else .{};
}

fn accountMatch(profile: ?*controls.Profile, length: usize) void {
    if (profile) |p| {
        p.add("parser_matches", 1);
        p.add("parser_matched_bytes", length);
    }
}
