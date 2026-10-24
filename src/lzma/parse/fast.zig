const std = @import("std");
const mf = @import("../match_finder.zig");
const settings = @import("../encode_options.zig");
const working = @import("../../io/working_allocator.zig");
const types = @import("types.zig");
const prices = @import("prices.zig");

const Probe = struct {
    matches: mf.Matches,
    repeats: [4]types.Decision = undefined,
    repeat_count: usize = 0,
    short_repeat: types.Decision = .{},

    fn longestRepeat(self: *const Probe) types.Decision {
        var best: types.Decision = .{ .length = 0 };
        for (self.repeats[0..self.repeat_count]) |candidate|
            if (candidate.length > best.length) {
                best = candidate;
            };
        return best;
    }
};

/// Greedy is strictly local. Fast uses distance-sensitive main/rep choices and
/// one-byte main/rep arbitration. Lazy compares frozen range-model prices at a
/// common coverage endpoint. Only path state/reps change here; probabilities,
/// the range coder and emission statistics remain the transaction's authority.
pub fn plan(allocator: std.mem.Allocator, budget: *working.WorkingAllocator, model: anytype, source: mf.Source, stream_start: usize, goal: usize, options: settings.MatchOptions, mode: settings.Mode) !types.Plan {
    try options.validate();
    if (mode != .greedy and mode != .lazy and mode != .fast) return error.InvalidLzmaOptions;
    if (goal > source.input.len or goal > types.window_len) return error.InvalidBlockPlan;
    _ = std.math.add(usize, stream_start, source.input.len) catch return error.IntegerOverflow;
    if (goal == 0) return .{ .tokens = try allocator.alloc(types.Token, 0), .consumed = 0, .final_state = types.State.fromModel(model) };
    var tokens: std.ArrayList(types.Token) = .empty;
    errdefer tokens.deinit(allocator);
    try tokens.ensureTotalCapacityPrecise(allocator, goal + 1);
    var remaining = options;
    if (budget.live > options.max_working_memory) return error.WorkingMemoryLimitExceeded;
    remaining.max_working_memory = options.max_working_memory - budget.live;
    var matcher = try mf.Matcher.init(allocator, source, remaining);
    defer matcher.deinit(allocator);
    const length_prices: prices.Lengths = if (mode == .lazy) prices.Lengths.init(model) else undefined;
    var state = types.State.fromModel(model);
    var position: usize = 0;
    var pending: ?Probe = null;
    while (position < goal) {
        const maximum = @min(mf.max_match_len, source.input.len - position);
        const current = if (pending) |saved| saved else probe(source, position, state, try matcher.find(), maximum, options.profile);
        pending = null;
        var selected = choose(model, &length_prices, source, position, stream_start, state, &current, maximum, options, mode);
        const lookahead = selected.length >= 2 and position + 1 < goal and
            (mode == .lazy or (mode == .fast and selected.length < options.effectiveNiceLen()));
        if (lookahead) {
            const after_literal = state.after(.{});
            const next_maximum = @min(mf.max_match_len, source.input.len - position - 1);
            const next_probe = probe(source, position + 1, after_literal, try matcher.find(), next_maximum, options.profile);
            const next = choose(model, &length_prices, source, position + 1, stream_start, after_literal, &next_probe, next_maximum, options, mode);
            const delay = if (mode == .fast)
                fastDelay(selected, next, &next_probe, state)
            else
                lazyDelay(model, &length_prices, source, position, stream_start, state, selected, next, options.profile);
            if (delay) {
                selected = .{};
                pending = next_probe;
            }
        }
        tokens.appendAssumeCapacity(if (selected.distance == 0)
            .{ .literal = source.input[position] }
        else
            .{ .match = .{ .length = selected.length, .distance = selected.distance } });
        state = state.after(selected);
        position += selected.length;
        if (pending == null) try matcher.advanceTo(position);
    }
    return .{ .tokens = try tokens.toOwnedSlice(allocator), .consumed = position, .final_state = state };
}

fn probe(source: mf.Source, position: usize, state: types.State, matches: mf.Matches, maximum: usize, profile: ?*settings.EncodeWorkProfile) Probe {
    var result: Probe = .{ .matches = matches };
    const absolute = source.prefixLen() + position;
    for (state.reps, 0..) |offset, index| {
        // Check before offset+1 so an invalid maxInt(u32) rep is safe on 32-bit.
        if (offset >= source.window_len) continue;
        const distance: usize = @as(usize, offset) + 1;
        if (distance > absolute) continue;
        var duplicate = false;
        for (state.reps[0..index]) |prior| duplicate = duplicate or prior == offset;
        if (duplicate) continue;
        count(profile, "rep_probes", 1);
        const length = source.matchLength(absolute - distance, absolute, maximum);
        if (index == 0 and length >= 1) result.short_repeat = .{ .distance = @intCast(distance) };
        if (length < 2) continue;
        result.repeats[result.repeat_count] = .{ .length = @intCast(length), .distance = @intCast(distance) };
        result.repeat_count += 1;
    }
    return result;
}

fn choose(model: anytype, lengths: *const prices.Lengths, source: mf.Source, position: usize, stream_start: usize, state: types.State, candidates: *const Probe, maximum: usize, options: settings.MatchOptions, mode: settings.Mode) types.Decision {
    if (mode == .lazy) return chooseLazy(model, lengths, source, position, stream_start, state, candidates, maximum, options.profile);
    const found = candidates.matches.best();
    var main = clip(found, maximum);
    const repeated = candidates.longestRepeat();
    if (mode == .greedy) return if (repeated.length >= 2 and repeated.length >= main.length) repeated else main;

    // A one-byte extension at a dramatically larger distance can be slower and
    // dearer than the preceding MF candidate. This is a Fast parser tradeoff,
    // independent of the probability-based lazy selection below.
    var index = candidates.matches.len;
    while (index > 1) {
        const previous = clip(candidates.matches.items[index - 2], maximum);
        if ((main.length == previous.length and previous.distance < main.distance) or
            (main.length == previous.length + 1 and farPair(previous.distance, main.distance)))
        {
            main = previous;
            index -= 1;
        } else break;
    }
    if (repeated.length >= options.effectiveNiceLen()) return repeated;
    if (main.length >= options.effectiveNiceLen()) return main;
    if (main.length == 2 and main.distance > 128) main = .{};
    if (repeated.length >= 2 and
        (repeated.length + 1 >= main.length or
            (repeated.length + 2 >= main.length and main.distance > 512) or
            (repeated.length + 3 >= main.length and main.distance > 32768))) return repeated;
    if (main.distance == 0 and candidates.short_repeat.distance != 0) {
        count(options.profile, "price_evaluations", 2);
        const ps = (stream_start + position) & ((@as(usize, 1) << model.properties.pb) - 1);
        if (prices.repeatedBase(model, state, ps, 0, true) <= prices.literal(model, source, position, stream_start, state)) return candidates.short_repeat;
    }
    return main;
}

fn fastDelay(current: types.Decision, next: types.Decision, next_probe: *const Probe, state: types.State) bool {
    if (next.length >= 2) {
        if (next.length > current.length + 1) return true;
        if (next.length == current.length + 1 and !farPair(current.distance, next.distance)) return true;
        if (next.length >= current.length and next.distance < current.distance) return true;
        if (next.length + 1 >= current.length and current.length >= 3 and farPair(next.distance, current.distance)) return true;
    }
    // A next-position repeat can justify postponing a direct-distance match,
    // even when the bounded MF search didn't expose that repeat's full length.
    return state.repIndex(current.distance) == null and next_probe.longestRepeat().length >= @max(@as(u16, 2), current.length - 1);
}

fn chooseLazy(model: anytype, lengths: *const prices.Lengths, source: mf.Source, position: usize, stream_start: usize, state: types.State, candidates: *const Probe, maximum: usize, profile: ?*settings.EncodeWorkProfile) types.Decision {
    var best: types.Decision = .{};
    var best_price = price(model, lengths, source, position, stream_start, state, best, profile);
    for (candidates.matches.slice()) |found| {
        const candidate = clip(found, maximum);
        const candidate_price = price(model, lengths, source, position, stream_start, state, candidate, profile);
        if (costRateBetter(candidate, candidate_price, best, best_price)) {
            best = candidate;
            best_price = candidate_price;
        }
    }
    for (candidates.repeats[0..candidates.repeat_count]) |candidate| {
        const candidate_price = price(model, lengths, source, position, stream_start, state, candidate, profile);
        if (costRateBetter(candidate, candidate_price, best, best_price)) {
            best = candidate;
            best_price = candidate_price;
        }
    }
    if (candidates.short_repeat.distance != 0) {
        const candidate = candidates.short_repeat;
        const candidate_price = price(model, lengths, source, position, stream_start, state, candidate, profile);
        if (costRateBetter(candidate, candidate_price, best, best_price)) best = candidate;
    }
    return best;
}

fn lazyDelay(model: anytype, lengths: *const prices.Lengths, source: mf.Source, position: usize, stream_start: usize, state: types.State, current: types.Decision, next: types.Decision, profile: ?*settings.EncodeWorkProfile) bool {
    const end = position + @max(@as(usize, current.length), @as(usize, next.length) + 1);
    const now = @as(u64, price(model, lengths, source, position, stream_start, state, current, profile)) +
        literalTail(model, source, position + current.length, end, stream_start, state.after(current), profile);
    const after_literal = state.after(.{});
    const delayed = @as(u64, price(model, lengths, source, position, stream_start, state, .{}, profile)) +
        price(model, lengths, source, position + 1, stream_start, after_literal, next, profile) +
        literalTail(model, source, position + 1 + next.length, end, stream_start, after_literal.after(next), profile);
    return delayed < now;
}

fn literalTail(model: anytype, source: mf.Source, begin: usize, end: usize, stream_start: usize, initial: types.State, profile: ?*settings.EncodeWorkProfile) u64 {
    var state = initial;
    var cost: u64 = 0;
    for (begin..end) |position| {
        count(profile, "price_evaluations", 1);
        cost += prices.literal(model, source, position, stream_start, state);
        state = state.after(.{});
    }
    return cost;
}

fn price(model: anytype, lengths: *const prices.Lengths, source: mf.Source, position: usize, stream_start: usize, state: types.State, selected: types.Decision, profile: ?*settings.EncodeWorkProfile) u32 {
    count(profile, "price_evaluations", 1);
    return prices.decision(model, lengths, source, position, stream_start, state, selected);
}

fn costRateBetter(candidate: types.Decision, candidate_price: u32, best: types.Decision, best_price: u32) bool {
    const left = @as(u64, candidate_price) * best.length;
    const right = @as(u64, best_price) * candidate.length;
    return left < right or (left == right and
        (candidate.length > best.length or (candidate.length == best.length and candidate.distance < best.distance)));
}

fn clip(found: mf.Match, maximum: usize) types.Decision {
    return if (found.length >= 2) .{ .length = @intCast(@min(found.length, maximum)), .distance = found.distance } else .{};
}

fn farPair(closer: u32, farther: u32) bool {
    if (closer == 0 or farther == 0) return false;
    return ((farther - 1) >> 7) > closer - 1;
}

fn count(profile: ?*settings.EncodeWorkProfile, comptime field: []const u8, amount: usize) void {
    if (profile) |p| @field(p, field) +|= @as(u64, @intCast(amount));
}

test {
    _ = @import("../fast_parse_tests.zig");
}
