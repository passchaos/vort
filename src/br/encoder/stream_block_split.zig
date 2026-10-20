const std = @import("std");
const histogram_model = @import("histogram_model.zig");

pub const full_block_len: usize = 64 * 1024;
pub const half_block_len: usize = full_block_len / 2;
pub const quarter_block_len: usize = full_block_len / 4;
pub const grid_block_len: usize = 4 * 1024;
pub const conservative_bound_block_len: usize = grid_block_len;
const grid_block_count = full_block_len / grid_block_len;
const max_segments = 4;
const max_boundaries = max_segments - 1;
const ranked_plans_per_depth = 2;
const max_grid_plans = (max_segments - 1) * ranked_plans_per_depth;

// One extra meta-block needs its own header and entropy descriptions. Require
// a conservative raw-literal entropy gain before materializing the split
// candidate; the shared writer still compares exact single/split bit counts.
const min_split_savings_bits: u64 = 2048;
const min_split_savings_q8 = min_split_savings_bits * histogram_model.cost_scale;

pub const BoundaryPlan = struct {
    boundaries: [max_boundaries]u16 = @splat(0),
    boundary_count: u2 = 0,

    pub fn slice(self: *const BoundaryPlan) []const u16 {
        return self.boundaries[0..self.boundary_count];
    }

    pub fn isHalves(self: *const BoundaryPlan) bool {
        return self.boundary_count == 1 and
            self.boundaries[0] == half_block_len;
    }

    pub fn isQuarters(self: *const BoundaryPlan) bool {
        return self.boundary_count == 3 and
            self.boundaries[0] == quarter_block_len and
            self.boundaries[1] == half_block_len and
            self.boundaries[2] == 3 * quarter_block_len;
    }
};

pub const Plan = struct {
    halves: bool = false,
    grid_plans: [max_grid_plans]BoundaryPlan = @splat(.{}),
    grid_plan_count: u3 = 0,

    pub fn any(self: Plan) bool {
        return self.halves or self.grid_plan_count != 0;
    }

    pub fn gridPlans(self: *const Plan) []const BoundaryPlan {
        return self.grid_plans[0..self.grid_plan_count];
    }
};

/// Screen whether a complete 64 KiB planning window has strong distribution
/// changes on a 4 KiB grid. The caller performs final exact-wire arbitration
/// across the shapes selected by `Plan`. The integer Q8 model is deterministic
/// on every target and searches all 575 layouts with at most four segments.
pub fn shouldSplit64(input: []const u8) bool {
    return plan64(input).any();
}

pub fn plan64(input: []const u8) Plan {
    if (input.len != full_block_len) return .{};
    const Histogram = histogram_model.Histogram(256);
    const invalid_cost = std.math.maxInt(u64);
    var grid: [grid_block_count]Histogram = @splat(.{});
    for (input, 0..) |byte, index|
        grid[index / grid_block_len].add(byte) catch unreachable;

    var segment_costs: [grid_block_count][grid_block_count + 1]u64 =
        @splat(@splat(invalid_cost));
    for (0..grid_block_count) |start| {
        var histogram: Histogram = .{};
        for (start..grid_block_count) |end| {
            histogram.addHistogram(&grid[end]) catch unreachable;
            segment_costs[start][end + 1] = histogram.entropyCostQ8();
        }
    }

    var result: Plan = .{};
    var frontier_cost = segment_costs[0][grid_block_count];
    for (2..max_segments + 1) |segment_count| {
        const ranked = rankBoundaryPlans(&segment_costs, segment_count);
        const previous_frontier = frontier_cost;
        if (ranked[0].cost >= previous_frontier) continue;
        frontier_cost = ranked[0].cost;
        for (ranked) |candidate| {
            if (candidate.cost >= previous_frontier) continue;
            if (candidate.plan.isHalves()) {
                result.halves = true;
            } else {
                result.grid_plans[result.grid_plan_count] = candidate.plan;
                result.grid_plan_count += 1;
            }
        }
    }
    return result;
}

const RankedPlan = struct {
    cost: u64 = std.math.maxInt(u64),
    plan: BoundaryPlan = .{},
};

fn rankBoundaryPlans(
    segment_costs: *const [grid_block_count][grid_block_count + 1]u64,
    segment_count: usize,
) [ranked_plans_per_depth]RankedPlan {
    var ranked: [ranked_plans_per_depth]RankedPlan = @splat(.{});
    var boundary_cells: [max_boundaries]u8 = undefined;
    enumerateBoundaryPlans(
        segment_costs,
        segment_count,
        &boundary_cells,
        0,
        1,
        &ranked,
    );
    return ranked;
}

fn enumerateBoundaryPlans(
    segment_costs: *const [grid_block_count][grid_block_count + 1]u64,
    segment_count: usize,
    boundary_cells: *[max_boundaries]u8,
    depth: usize,
    next_cell: usize,
    ranked: *[ranked_plans_per_depth]RankedPlan,
) void {
    const boundary_count = segment_count - 1;
    if (depth == boundary_count) {
        const candidate = rankedPlan(segment_costs, boundary_cells, boundary_count) orelse
            return;
        retainRankedPlan(ranked, candidate);
        return;
    }
    const remaining_boundaries = boundary_count - depth;
    const last_cell = grid_block_count - remaining_boundaries;
    for (next_cell..last_cell + 1) |cell| {
        boundary_cells[depth] = @intCast(cell);
        enumerateBoundaryPlans(
            segment_costs,
            segment_count,
            boundary_cells,
            depth + 1,
            cell + 1,
            ranked,
        );
    }
}

fn rankedPlan(
    segment_costs: *const [grid_block_count][grid_block_count + 1]u64,
    boundary_cells: *const [max_boundaries]u8,
    boundary_count: usize,
) ?RankedPlan {
    var cost: u64 = 0;
    var start: usize = 0;
    var plan: BoundaryPlan = .{ .boundary_count = @intCast(boundary_count) };
    for (boundary_cells[0..boundary_count], 0..) |cell_u8, index| {
        const cell: usize = cell_u8;
        cost = std.math.add(u64, cost, segment_costs[start][cell]) catch
            return null;
        plan.boundaries[index] = @intCast(cell * grid_block_len);
        start = cell;
    }
    cost = std.math.add(
        u64,
        cost,
        segment_costs[start][grid_block_count],
    ) catch return null;
    const header_allowance = std.math.mul(
        u64,
        min_split_savings_q8,
        boundary_count,
    ) catch return null;
    cost = std.math.add(u64, cost, header_allowance) catch return null;
    return .{ .cost = cost, .plan = plan };
}

fn retainRankedPlan(
    ranked: *[ranked_plans_per_depth]RankedPlan,
    candidate: RankedPlan,
) void {
    if (rankedPlanLess(candidate, ranked[0])) {
        ranked[1] = ranked[0];
        ranked[0] = candidate;
    } else if (rankedPlanLess(candidate, ranked[1])) {
        ranked[1] = candidate;
    }
}

fn rankedPlanLess(left: RankedPlan, right: RankedPlan) bool {
    if (left.cost != right.cost) return left.cost < right.cost;
    const left_boundaries = left.plan.slice();
    const right_boundaries = right.plan.slice();
    for (left_boundaries, right_boundaries) |left_boundary, right_boundary| {
        if (left_boundary != right_boundary)
            return left_boundary < right_boundary;
    }
    return left_boundaries.len < right_boundaries.len;
}

test "stream block split keeps homogeneous distributions together" {
    var uniform: [full_block_len]u8 = @splat('x');
    try std.testing.expect(!shouldSplit64(&uniform));
    for (&uniform, 0..) |*byte, index| byte.* = "homogeneous payload\n"[index % 20];
    try std.testing.expect(!shouldSplit64(&uniform));
}

test "stream block split detects a strong midpoint distribution change" {
    var changed: [full_block_len]u8 = undefined;
    @memset(changed[0..half_block_len], 'a');
    @memset(changed[half_block_len..], 'z');
    const plan = plan64(&changed);
    try std.testing.expect(plan.halves);
    try std.testing.expect(!shouldSplit64(changed[0 .. full_block_len - 1]));
}

test "stream block split detects alternating quarter distributions" {
    var changed: [full_block_len]u8 = undefined;
    for (&changed, 0..) |*byte, index| {
        const quarter = index / quarter_block_len;
        byte.* = if (quarter & 1 == 0)
            @intCast(index & 15)
        else
            @intCast(240 + (index & 15));
    }
    const plan = plan64(&changed);
    try std.testing.expect(plan.gridPlans().len >= 1);
    var found_quarters = false;
    for (plan.gridPlans()) |*candidate|
        found_quarters = found_quarters or candidate.isQuarters();
    try std.testing.expect(found_quarters);
}

test "stream block split detects a non-quarter grid boundary" {
    var changed: [full_block_len]u8 = undefined;
    const boundary = 24 * 1024;
    for (&changed, 0..) |*byte, index|
        byte.* = if (index < boundary)
            @intCast(index & 15)
        else
            @intCast(240 + (index & 15));
    const plan = plan64(&changed);
    try std.testing.expect(plan.gridPlans().len >= 1);
    try std.testing.expectEqualSlices(
        u16,
        &.{@as(u16, @intCast(boundary))},
        plan.gridPlans()[0].slice(),
    );
    try std.testing.expect(
        plan.gridPlans().len + @intFromBool(plan.halves) >= 2,
    );
}

test "stream block split detects a boundary outside the 8 KiB grid" {
    var changed: [full_block_len]u8 = undefined;
    const boundary = 5 * grid_block_len;
    for (&changed, 0..) |*byte, index|
        byte.* = if (index < boundary)
            @intCast(index & 15)
        else
            @intCast(240 + (index & 15));
    const plan = plan64(&changed);
    try std.testing.expect(plan.gridPlans().len >= 1);
    try std.testing.expectEqualSlices(
        u16,
        &.{@as(u16, @intCast(boundary))},
        plan.gridPlans()[0].slice(),
    );
}

test "stream block split retains a multi-depth proxy frontier" {
    var changed: [full_block_len]u8 = undefined;
    for (&changed, 0..) |*byte, index| {
        byte.* = if (index < 16 * 1024)
            @intCast(index & 15)
        else if (index < 40 * 1024)
            @intCast(96 + (index & 15))
        else
            @intCast(240 + (index & 15));
    }
    const plan = plan64(&changed);
    try std.testing.expect(plan.gridPlans().len >= 4);
    try std.testing.expectEqual(@as(usize, 1), plan.gridPlans()[0].slice().len);
    var found_three_regions = false;
    for (plan.gridPlans()) |*candidate| {
        found_three_regions = found_three_regions or std.mem.eql(
            u16,
            &.{ @as(u16, 16 * 1024), @as(u16, 40 * 1024) },
            candidate.slice(),
        );
    }
    try std.testing.expect(found_three_regions);
}
