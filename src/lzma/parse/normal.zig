const std = @import("std");
const mf = @import("../match_finder.zig");
const settings = @import("../encode_options.zig");
const working = @import("../../io/working_allocator.zig");
const types = @import("types.zig");
const prices = @import("prices.zig");

const infinity = std.math.maxInt(u32);
const Node = struct {
    price: u32 = infinity,
    state: types.State = .{},
    previous_position: u16 = 0,
    previous_slot: u8 = 0,
    decision: types.Decision = .{},
};

/// Full 4096-position shortest-path search with a bounded state/repetition beam.
/// Probabilities are a snapshot of the real range model at this stable prefix;
/// every path has its own exact LZMA state and four repeat distances.
pub fn plan(allocator: std.mem.Allocator, budget: *working.WorkingAllocator, model: anytype, source: mf.Source, stream_start: usize, goal: usize, options: settings.MatchOptions) !types.Plan {
    const nodes = try allocator.alloc(Node, (goal + 1) * types.beam_width);
    defer allocator.free(nodes);
    @memset(nodes, .{});
    const offsets = try allocator.alloc(usize, goal + 1);
    defer allocator.free(offsets);
    var tokens: std.ArrayList(types.Token) = .empty;
    errdefer tokens.deinit(allocator);
    try tokens.ensureTotalCapacityPrecise(allocator, goal);
    var remaining = options;
    if (budget.live > options.max_working_memory) return error.WorkingMemoryLimitExceeded;
    remaining.max_working_memory = options.max_working_memory - budget.live;
    var matcher = try mf.Matcher.init(allocator, source, remaining);
    defer matcher.deinit(allocator);
    var matches: std.ArrayList(mf.Match) = .empty;
    defer matches.deinit(allocator);
    for (0..goal) |position| {
        offsets[position] = matches.items.len;
        var current: mf.Matches = .{};
        try matcher.getMatches(&current);
        var previous: usize = 1;
        for (current.slice()) |candidate| {
            const length = @min(candidate.length, goal - position);
            if (length < 2 or length <= previous) continue;
            try matches.append(allocator, .{ .length = @intCast(length), .distance = candidate.distance });
            previous = length;
        }
    }
    offsets[goal] = matches.items.len;
    const lengths = prices.Lengths.init(model);
    nodes[0] = .{ .price = 0, .state = types.State.fromModel(model) };
    for (0..goal) |position| {
        const maximum = @min(@as(usize, 273), goal - position);
        const absolute = source.prefixLen() + position;
        const position_state = (stream_start + position) & ((@as(usize, 1) << model.properties.pb) - 1);
        const candidates = matches.items[offsets[position]..offsets[position + 1]];
        for (0..types.beam_width) |slot| {
            const node = nodes[position * types.beam_width + slot];
            if (node.price == infinity) continue;
            const literal = types.Decision{};
            count(options.profile, "price_evaluations", 1);
            relax(nodes, position, slot, node, literal, prices.literal(model, source, position, stream_start, node.state));
            for (node.state.reps, 0..) |rep, ri| {
                const distance: usize = @as(usize, rep) + 1;
                if (distance > absolute or distance > source.window_len) continue;
                var duplicate = false;
                for (node.state.reps[0..ri]) |prior| if (prior == rep) {
                    duplicate = true;
                };
                if (duplicate) continue;
                count(options.profile, "rep_probes", 1);
                const length = source.matchLength(absolute - distance, absolute, maximum);
                if (ri == 0 and length >= 1) {
                    count(options.profile, "price_evaluations", 1);
                    relax(nodes, position, slot, node, .{ .length = 1, .distance = @intCast(distance) }, prices.repeatedBase(model, node.state, position_state, 0, true));
                }
                if (length < 2) continue;
                const base = prices.repeatedBase(model, node.state, position_state, ri, false);
                for (2..length + 1) |n| {
                    count(options.profile, "price_evaluations", 1);
                    relax(nodes, position, slot, node, .{ .length = @intCast(n), .distance = @intCast(distance) }, base + lengths.repeated[position_state][n - 2]);
                }
            }
            var previous: usize = 1;
            for (candidates) |candidate| {
                const length: usize = candidate.length;
                if (node.state.repIndex(candidate.distance) != null) {
                    previous = length;
                    continue;
                }
                const base = prices.normalBase(model, node.state, position_state);
                var distances: [4]u32 = undefined;
                for (0..4) |state| distances[state] = prices.distance(model, state, candidate.distance - 1);
                for (previous + 1..length + 1) |n| {
                    count(options.profile, "price_evaluations", 1);
                    relax(nodes, position, slot, node, .{ .length = @intCast(n), .distance = candidate.distance }, base + lengths.normal[position_state][n - 2] + distances[@min(n - 2, 3)]);
                }
                previous = length;
            }
        }
    }
    var slot: usize = 0;
    for (1..types.beam_width) |i| if (nodes[goal * types.beam_width + i].price < nodes[goal * types.beam_width + slot].price) {
        slot = i;
    };
    const final_state = nodes[goal * types.beam_width + slot].state;
    var position = goal;
    while (position != 0) {
        const node = nodes[position * types.beam_width + slot];
        if (node.price == infinity or node.previous_position >= position) return error.InvalidBlockPlan;
        const token: types.Token = if (node.decision.distance == 0) .{ .literal = source.input[node.previous_position] } else .{ .match = .{ .length = node.decision.length, .distance = node.decision.distance } };
        tokens.appendAssumeCapacity(token);
        position = node.previous_position;
        slot = node.previous_slot;
    }
    std.mem.reverse(types.Token, tokens.items);
    return .{ .tokens = try tokens.toOwnedSlice(allocator), .consumed = goal, .final_state = final_state };
}

fn relax(nodes: []Node, position: usize, slot: usize, node: Node, decision: types.Decision, cost: u32) void {
    const end = position + decision.length;
    const next = node.state.after(decision);
    const price = node.price + cost;
    const row = nodes[end * types.beam_width ..][0..types.beam_width];
    var target: usize = 0;
    for (row, 0..) |existing, i| {
        if (existing.price != infinity and std.meta.eql(existing.state, next)) {
            if (existing.price <= price) return;
            target = i;
            break;
        }
        if (existing.price > row[target].price) target = i;
    } else if (row[target].price <= price) return;
    row[target] = .{ .price = price, .state = next, .previous_position = @intCast(position), .previous_slot = @intCast(slot), .decision = decision };
}
fn count(profile: ?*settings.EncodeWorkProfile, comptime field: []const u8, amount: usize) void {
    if (profile) |p| @field(p, field) +|= @as(u64, @intCast(amount));
}
