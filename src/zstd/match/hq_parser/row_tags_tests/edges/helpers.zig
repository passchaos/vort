const std = @import("std");
pub const state = @import("../../state.zig");
pub const prices = @import("../../prices.zig");
pub const controls = @import("../../../../encode/controls.zig");
const Frozen = @import("../../search_edges_row_tags_reference.zig");
const PriceBudget = @import("../../price_budget.zig").PriceBudget;
const a = std.testing.allocator;

pub const Case = struct {
    strategy: controls.Strategy = .btopt,
    minimum: u8 = 3,
    maximum: usize = 100,
    position: usize = 4,
    literal_len: u32 = 1,
    repeats: [3]usize = .{ 1, 4, 8 },
    distance: usize = 7,
    cost: u64 = 100,
    limit: ?u64 = null,
    admitted: u64 = 0,
    goal: ?usize = null,
    base: usize = 3,
    prefix_unit: u64 = prices.scale,
    prefix_tail: ?u64 = null,
    pricing: enum { predefined, varied, zero } = .varied,
    entropy: ?*const prices.EntropyModel = null,
    seed_rows: bool = true,
    full_cost: ?u64 = null,
    repetitions: usize = 1,
    instrument: bool = true,
    tagged: bool = false,
    alias_origin: bool = false,
    alias_slot: usize = 0,
    profile: controls.Profile = .{
        .positions_tested = 17,
        .price_evaluations = 9,
        .optimal_transitions = 11,
        .price_limit_refusals = 5,
        .max_plan_price_evaluations = 7,
        .compressed_blocks = 23,
    },
};

pub const Report = struct {
    failure: ?anyerror,
    admitted: u64,
    profile: controls.Profile,
    lowest_written_match: ?u32,
    spill_node: state.Node,
    spill_end: usize,
    continuation_cost: u64,
};

// These probes select storage to initialize and compare, not candidate costs
// or admission order. The actual oracle below is the untouched bdae5ce7 file.
// Large sparse cases include every ML lower/upper endpoint, the short prefix,
// maximum, and adjacent guard rows; small cases compare every table row.
const Probes = struct {
    rows: [512]usize = undefined,
    len: usize = 0,

    fn add(self: *Probes, row: usize, goal: usize) void {
        if (row > goal or std.mem.indexOfScalar(usize, self.rows[0..self.len], row) != null) return;
        std.debug.assert(self.len < self.rows.len);
        self.rows[self.len] = row;
        self.len += 1;
    }
    fn around(self: *Probes, row: usize, goal: usize) void {
        self.add(row -| 1, goal);
        self.add(row, goal);
        self.add(row + 1, goal);
    }
    fn init(case: Case, goal: usize) Probes {
        var self: Probes = .{};
        self.around(0, goal);
        self.around(case.position, goal);
        self.around(case.position + case.maximum, goal);
        self.around(goal, goal);
        for (0..@min(case.maximum, 65) + 1) |length|
            self.around(case.position + length, goal);
        for (prices.ml_bases, prices.ml_bits) |base, bits| {
            const lower: usize = base;
            const upper = lower + (@as(usize, 1) << @intCast(bits)) - 1;
            if (lower <= case.maximum) self.around(case.position + lower, goal);
            if (upper <= case.maximum) self.around(case.position + upper, goal);
        }
        return self;
    }
};

fn initializeRow(comptime Node: type, row: []Node, index: usize, case: Case) void {
    @memset(row, .{});
    if (!case.seed_rows) return;
    if (case.full_cost) |cost| {
        for (row, 0..) |*node, slot| node.* = .{ .cost = cost +| @as(u64, @intCast(slot)), .repeats = .{ 99, 101, 103 }, .previous_slot = @intCast(slot) };
        return;
    }
    row[0] = .{
        .cost = 47 + (index % 13) * prices.scale,
        .repeats = case.repeats,
        .match_len = @intCast(index -| case.position),
        .distance = 7,
        .offset_value = 10,
        .previous_position = 0,
        .previous_slot = 19,
    };
    if (row.len > 1) row[1] = .{ .cost = 70000, .literal_len = 1, .repeats = .{ 99, 101, 103 } };
}

pub fn compare(comptime Codec: type, comptime whole: bool, comptime complete: bool, width: usize, case: Case) !Report {
    const Reference = if (@hasDecl(Codec, "Reference")) Codec.Reference else Frozen;
    const tagged = case.tagged or (if (@hasDecl(Codec, "force_tags")) Codec.force_tags else false);
    const Node = state.NodeFor(whole);
    const goal = case.goal orelse case.position + case.maximum;
    const count = (goal + 1) * width;
    const actual = try a.alloc(Node, count);
    defer a.free(actual);
    const expected = try a.alloc(Node, count);
    defer a.free(expected);
    const dense = goal < 2048;
    const probes = Probes.init(case, goal);
    if (dense) {
        for (0..goal + 1) |row| initializeRow(Node, actual[row * width ..][0..width], row, case);
        @memcpy(expected, actual);
    } else {
        for (probes.rows[0..probes.len]) |row| {
            initializeRow(Node, actual[row * width ..][0..width], row, case);
            @memcpy(expected[row * width ..][0..width], actual[row * width ..][0..width]);
        }
    }
    const origin: Node = .{
        .cost = case.cost,
        .literal_len = case.literal_len,
        .repeats = case.repeats,
        .previous_position = @intCast(case.position),
        .previous_slot = 31,
        .match_len = 91,
        .distance = 13,
        .offset_value = 17,
    };
    const origin_slot = if (case.alias_origin) case.alias_slot else 0;
    const caller_slot = if (case.alias_origin) case.alias_slot else width - 1;
    actual[case.position * width + origin_slot] = origin;
    expected[case.position * width + origin_slot] = origin;
    var actual_profile = case.profile;
    var expected_profile = case.profile;
    var actual_budget = PriceBudget.init(case.limit, if (case.instrument) &actual_profile else null);
    var expected_budget = PriceBudget.init(case.limit, if (case.instrument) &expected_profile else null);
    actual_budget.admitted = case.admitted;
    expected_budget.admitted = case.admitted;
    var model: prices.EntropyModel = .{};
    if (case.pricing == .zero) {
        model.ll_prices = @splat(0);
        model.ml_prices = @splat(0);
        model.of_prices = @splat(0);
    } else if (case.pricing == .varied) {
        for (&model.ll_prices, 0..) |*price, index| price.* = @intCast((index * 53 + 17) % 997);
        for (&model.ml_prices, 0..) |*price, index| price.* = @intCast((index * 97 + 71) % 2017);
        for (&model.of_prices, 0..) |*price, index| price.* = @intCast((index * 31 + 11) % 521);
    }
    const actual_parameters: state.Parameters = .{
        .strategy = case.strategy,
        .hq_options = .{
            .min_match = case.minimum,
            .parse_mode = if (whole) .whole_block else .bounded,
            .match_lengths = if (complete) .complete else .sampled,
            .max_price_evaluations = case.limit,
        },
        .entropy = case.entropy orelse &model,
        .profile = if (case.instrument) &actual_profile else null,
    };
    var expected_parameters = actual_parameters;
    expected_parameters.profile = if (case.instrument) &expected_profile else null;
    var actual_spill: Codec.Spill = .{};
    var expected_spill: Reference.Spill = .{};
    const prefix = try a.alloc(u64, case.base + case.position + case.maximum + 3);
    defer a.free(prefix);
    for (prefix, 0..) |*price, index| price.* = @as(u64, @intCast(index)) * case.prefix_unit;
    if (case.prefix_tail) |tail| prefix[prefix.len - 1] = tail;
    var context: Codec.Context(whole, complete) = .{
        .nodes = actual,
        .width = width,
        .base = case.base,
        .goal = goal,
        .parameters = actual_parameters,
        .price_budget = &actual_budget,
        .literal_prefix = prefix,
        .spill = &actual_spill,
    };
    if (@hasDecl(Codec, "choice_pruning")) context.choice_pruning = Codec.choice_pruning;
    const tags = try a.alloc(@import("../../row_tags.zig").Tags, goal + 1);
    defer a.free(tags);
    const expected_tags = try a.alloc(@import("../../row_tags.zig").Tags, goal + 1);
    defer a.free(expected_tags);
    if (tagged) {
        for (0..goal + 1) |row| {
            if (!dense and std.mem.indexOfScalar(usize, probes.rows[0..probes.len], row) == null) continue;
            tags[row] = @import("../../row_tags.zig").init(actual[row * width ..][0..width]);
            expected_tags[row] = tags[row];
        }
        context.tag_rows = tags;
    }
    var reference: Reference.Context(whole, complete) = .{
        .nodes = expected,
        .width = width,
        .base = case.base,
        .goal = goal,
        .parameters = expected_parameters,
        .price_budget = &expected_budget,
        .literal_prefix = prefix,
        .spill = &expected_spill,
    };
    if (tagged and @hasField(@TypeOf(reference), "tag_rows")) reference.tag_rows = expected_tags;
    var actual_failure: ?anyerror = null;
    var expected_failure: ?anyerror = null;
    for (0..case.repetitions) |_| {
        if (context.candidate(case.position, caller_slot, if (case.alias_origin) actual[case.position * width + origin_slot] else origin, case.distance, case.maximum)) |_| {} else |err| {
            actual_failure = err;
            break;
        }
    }
    for (0..case.repetitions) |_| {
        if (reference.candidate(case.position, caller_slot, if (case.alias_origin) expected[case.position * width + origin_slot] else origin, case.distance, case.maximum)) |_| {} else |err| {
            expected_failure = err;
            break;
        }
    }
    actual_budget.finish();
    expected_budget.finish();
    try std.testing.expectEqual(expected_failure, actual_failure);
    try std.testing.expectEqual(expected_budget.limit, actual_budget.limit);
    if (@hasDecl(Codec, "allow_price_reduction") and Codec.allow_price_reduction) {
        try std.testing.expectEqual(expected_budget.admitted, actual_budget.admitted);
        var normalized = actual_profile;
        inline for (.{ "price_evaluations", "optimal_transitions" }) |field| {
            try std.testing.expect(@field(actual_profile, field) <= @field(expected_profile, field));
            @field(normalized, field) = @field(expected_profile, field);
        }
        try std.testing.expectEqualDeep(expected_profile, normalized);
    } else {
        try std.testing.expectEqual(expected_budget.admitted, actual_budget.admitted);
        try std.testing.expectEqualDeep(expected_profile, actual_profile);
    }
    try std.testing.expectEqualDeep(expected_spill.node, actual_spill.node);
    try std.testing.expectEqual(expected_spill.end_position, actual_spill.end_position);
    try std.testing.expectEqual(expected_spill.continuation_cost, actual_spill.continuation_cost);
    if (dense) {
        try std.testing.expectEqualDeep(expected, actual);
    } else for (probes.rows[0..probes.len]) |row|
        try std.testing.expectEqualDeep(expected[row * width ..][0..width], actual[row * width ..][0..width]);
    if (tagged) {
        for (probes.rows[0..probes.len]) |row| {
            for (actual[row * width ..][0..width], 0..) |node, slot|
                try std.testing.expectEqual(@import("../../row_tags.zig").key(node), tags[row][slot]);
            if (@hasField(@TypeOf(reference), "tag_rows")) try std.testing.expectEqualDeep(expected_tags[row], tags[row]);
        }
    }
    var lowest: ?u32 = null;
    for (probes.rows[0..probes.len]) |row| {
        if (row == case.position) continue;
        for (actual[row * width ..][0..width]) |node| {
            if (node.previous_position != case.position or node.previous_slot != caller_slot or node.match_len == 0) continue;
            lowest = @min(lowest orelse node.match_len, node.match_len);
        }
    }
    return .{
        .failure = actual_failure,
        .admitted = actual_budget.admitted,
        .profile = actual_profile,
        .lowest_written_match = lowest,
        .spill_node = actual_spill.node,
        .spill_end = actual_spill.end_position,
        .continuation_cost = actual_spill.continuation_cost,
    };
}
