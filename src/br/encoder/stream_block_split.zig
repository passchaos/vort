const std = @import("std");
const histogram_model = @import("histogram_model.zig");

pub const full_block_len: usize = 64 * 1024;
pub const half_block_len: usize = full_block_len / 2;
pub const quarter_block_len: usize = full_block_len / 4;
pub const grid_block_len: usize = 8 * 1024;
pub const conservative_bound_block_len: usize = grid_block_len;
const grid_block_count = full_block_len / grid_block_len;
const max_segments = 4;
const max_boundaries = max_segments - 1;
const max_grid_plans = max_segments - 1;

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
    grid_plan_count: u2 = 0,

    pub fn any(self: Plan) bool {
        return self.halves or self.grid_plan_count != 0;
    }

    pub fn gridPlans(self: *const Plan) []const BoundaryPlan {
        return self.grid_plans[0..self.grid_plan_count];
    }
};

/// Screen whether a complete 64 KiB planning window has strong distribution
/// changes on an 8 KiB grid. The caller performs final exact-wire arbitration
/// across the shapes selected by `Plan`. The integer Q8 model is deterministic
/// on every target and uses eight fixed histograms plus a four-segment DP.
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

    var costs: [max_segments + 1][grid_block_count + 1]u64 =
        @splat(@splat(invalid_cost));
    var previous: [max_segments + 1][grid_block_count + 1]u8 =
        @splat(@splat(std.math.maxInt(u8)));
    costs[0][0] = 0;
    for (1..max_segments + 1) |segment_count| {
        for (segment_count..grid_block_count + 1) |end| {
            for (segment_count - 1..end) |start| {
                const prior = costs[segment_count - 1][start];
                if (prior == invalid_cost) continue;
                var candidate = std.math.add(
                    u64,
                    prior,
                    segment_costs[start][end],
                ) catch continue;
                if (segment_count > 1) {
                    candidate = std.math.add(
                        u64,
                        candidate,
                        min_split_savings_q8,
                    ) catch continue;
                }
                if (candidate < costs[segment_count][end]) {
                    costs[segment_count][end] = candidate;
                    previous[segment_count][end] = @intCast(start);
                }
            }
        }
    }

    var result: Plan = .{};
    var frontier_cost = costs[1][grid_block_count];
    for (2..max_segments + 1) |segment_count| {
        const candidate_cost = costs[segment_count][grid_block_count];
        if (candidate_cost >= frontier_cost) continue;
        frontier_cost = candidate_cost;
        const candidate = reconstructBoundaryPlan(
            &previous,
            segment_count,
        ) orelse return .{};
        if (candidate.isHalves()) {
            result.halves = true;
        } else {
            result.grid_plans[result.grid_plan_count] = candidate;
            result.grid_plan_count += 1;
        }
    }
    return result;
}

fn reconstructBoundaryPlan(
    previous: *const [max_segments + 1][grid_block_count + 1]u8,
    selected_segment_count: usize,
) ?BoundaryPlan {
    var reversed: [max_boundaries]u16 = undefined;
    var reversed_count: usize = 0;
    var end = grid_block_count;
    var segment_count = selected_segment_count;
    while (segment_count > 1) : (segment_count -= 1) {
        const start = previous[segment_count][end];
        if (start == std.math.maxInt(u8) or start == 0) return null;
        reversed[reversed_count] = @intCast(@as(usize, start) * grid_block_len);
        reversed_count += 1;
        end = start;
    }
    var result: BoundaryPlan = .{ .boundary_count = @intCast(reversed_count) };
    for (0..reversed_count) |index|
        result.boundaries[index] = reversed[reversed_count - index - 1];
    return result;
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
    try std.testing.expectEqual(@as(usize, 0), plan.gridPlans().len);
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
    try std.testing.expect(!plan.halves);
    try std.testing.expect(plan.gridPlans().len >= 1);
    try std.testing.expect(
        plan.gridPlans()[plan.gridPlans().len - 1].isQuarters(),
    );
}

test "stream block split detects a non-quarter grid boundary" {
    var changed: [full_block_len]u8 = undefined;
    const boundary = 3 * grid_block_len;
    for (&changed, 0..) |*byte, index|
        byte.* = if (index < boundary)
            @intCast(index & 15)
        else
            @intCast(240 + (index & 15));
    const plan = plan64(&changed);
    try std.testing.expect(!plan.halves);
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
    try std.testing.expect(!plan.halves);
    try std.testing.expectEqual(@as(usize, 2), plan.gridPlans().len);
    try std.testing.expectEqual(@as(usize, 1), plan.gridPlans()[0].slice().len);
    try std.testing.expectEqualSlices(
        u16,
        &.{ @as(u16, 16 * 1024), @as(u16, 40 * 1024) },
        plan.gridPlans()[1].slice(),
    );
}
