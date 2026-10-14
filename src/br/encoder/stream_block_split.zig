const std = @import("std");
const histogram_model = @import("histogram_model.zig");

pub const full_block_len: usize = 64 * 1024;
pub const half_block_len: usize = full_block_len / 2;

// One extra meta-block needs its own header and entropy descriptions. Require
// a conservative raw-literal entropy gain before materializing the split
// candidate; the shared writer still compares exact single/split bit counts.
const min_split_savings_bits: u64 = 2048;
const min_split_savings_q8 = min_split_savings_bits * histogram_model.cost_scale;

/// Screen whether a complete 64 KiB planning window has a strong distribution
/// change at its midpoint. The caller performs final exact-wire arbitration.
/// The integer Q8 model is deterministic on every target and uses only two
/// fixed 256-entry histograms.
pub fn shouldSplit64(input: []const u8) bool {
    if (input.len != full_block_len) return false;
    const Histogram = histogram_model.Histogram(256);
    var left: Histogram = .{};
    var right: Histogram = .{};
    for (input[0..half_block_len]) |byte| left.add(byte) catch unreachable;
    for (input[half_block_len..]) |byte| right.add(byte) catch unreachable;
    var combined = left;
    combined.addHistogram(&right) catch unreachable;
    const separate_q8 = std.math.add(
        u64,
        left.entropyCostQ8(),
        right.entropyCostQ8(),
    ) catch return false;
    const charged_separate_q8 = std.math.add(
        u64,
        separate_q8,
        min_split_savings_q8,
    ) catch return false;
    return charged_separate_q8 < combined.entropyCostQ8();
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
    try std.testing.expect(shouldSplit64(&changed));
    try std.testing.expect(!shouldSplit64(changed[0 .. full_block_len - 1]));
}
