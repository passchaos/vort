const std = @import("std");
const histogram_model = @import("histogram_model.zig");

pub const full_block_len: usize = 64 * 1024;
pub const half_block_len: usize = full_block_len / 2;
pub const quarter_block_len: usize = full_block_len / 4;

// One extra meta-block needs its own header and entropy descriptions. Require
// a conservative raw-literal entropy gain before materializing the split
// candidate; the shared writer still compares exact single/split bit counts.
const min_split_savings_bits: u64 = 2048;
const min_split_savings_q8 = min_split_savings_bits * histogram_model.cost_scale;

pub const Plan = struct {
    halves: bool = false,
    quarters: bool = false,

    pub fn any(self: Plan) bool {
        return self.halves or self.quarters;
    }
};

/// Screen whether a complete 64 KiB planning window has strong distribution
/// changes at its midpoint or quarter boundaries. The caller performs final
/// exact-wire arbitration across the shapes selected by `Plan`. The integer Q8
/// model is deterministic on every target and uses four fixed histograms.
pub fn shouldSplit64(input: []const u8) bool {
    return plan64(input).any();
}

pub fn plan64(input: []const u8) Plan {
    if (input.len != full_block_len) return .{};
    const Histogram = histogram_model.Histogram(256);
    var quarters: [4]Histogram = .{ .{}, .{}, .{}, .{} };
    for (input, 0..) |byte, index|
        quarters[index / quarter_block_len].add(byte) catch unreachable;
    var left = quarters[0];
    left.addHistogram(&quarters[1]) catch unreachable;
    var right = quarters[2];
    right.addHistogram(&quarters[3]) catch unreachable;
    var combined = left;
    combined.addHistogram(&right) catch unreachable;
    const halves_q8 = std.math.add(
        u64,
        left.entropyCostQ8(),
        right.entropyCostQ8(),
    ) catch return .{};
    const charged_halves_q8 = std.math.add(
        u64,
        halves_q8,
        min_split_savings_q8,
    ) catch return .{};
    const combined_q8 = combined.entropyCostQ8();
    const halves_profitable = charged_halves_q8 < combined_q8;

    var quarters_q8: u64 = 0;
    for (&quarters) |*quarter|
        quarters_q8 = std.math.add(u64, quarters_q8, quarter.entropyCostQ8()) catch
            return .{ .halves = halves_profitable };
    const quarter_header_allowance = std.math.mul(
        u64,
        min_split_savings_q8,
        3,
    ) catch return .{ .halves = halves_profitable };
    const charged_quarters_q8 = std.math.add(
        u64,
        quarters_q8,
        quarter_header_allowance,
    ) catch return .{ .halves = halves_profitable };
    const quarter_vs_halves_allowance = std.math.mul(
        u64,
        min_split_savings_q8,
        2,
    ) catch return .{ .halves = halves_profitable };
    const charged_quarters_vs_halves_q8 = std.math.add(
        u64,
        quarters_q8,
        quarter_vs_halves_allowance,
    ) catch return .{ .halves = halves_profitable };
    return .{
        .halves = halves_profitable,
        .quarters = charged_quarters_q8 < combined_q8 and
            charged_quarters_vs_halves_q8 < halves_q8,
    };
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
    try std.testing.expect(!plan.quarters);
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
    try std.testing.expect(plan.quarters);
}
