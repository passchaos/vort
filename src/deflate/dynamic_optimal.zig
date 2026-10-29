//! One-round DEFLATE entropy model for the generic bounded optimal parser.
//! Complete block arbitration remains in the format owner; this module only
//! translates a prepared dynamic tree into literal/length/distance edge costs.
const std = @import("std");
const lz77 = @import("../lz77.zig");

pub const Code = struct {
    symbol: u16,
    extra_bits: u5,
};

pub const Model = struct {
    literal: [256]u16,
    length: [lz77.max_match_len + 1]u16,
    distance: []u16,

    pub fn init(
        comptime S: type,
        allocator: std.mem.Allocator,
        literal_lengths: *const [286]u4,
        distance_lengths: *const [30]u4,
        window_len: usize,
    ) (std.mem.Allocator.Error || error{ InvalidBlockPlan, IntegerOverflow })!Model {
        if (window_len == 0 or window_len > lz77.default_window_len)
            return error.InvalidBlockPlan;
        var result: Model = .{
            .literal = undefined,
            .length = @splat(1),
            .distance = try allocator.alloc(u16, window_len + 1),
        };
        errdefer allocator.free(result.distance);
        for (&result.literal, 0..) |*cost, symbol|
            cost.* = symbolCost(
                literal_lengths[symbol],
                S.fixedLiteralBits(symbol),
                0,
            );
        for (lz77.min_match_len..lz77.max_match_len + 1) |match_len| {
            const code = S.lengthCode(match_len);
            result.length[match_len] = symbolCost(
                literal_lengths[code.symbol],
                S.fixedLiteralBits(code.symbol),
                code.extra_bits,
            );
        }
        result.distance[0] = 1;
        for (1..result.distance.len) |match_distance| {
            const code = S.distanceCode(match_distance);
            result.distance[match_distance] = symbolCost(
                distance_lengths[code.symbol],
                S.fixedDistanceBits(code.symbol),
                code.extra_bits,
            );
        }
        return result;
    }

    pub fn deinit(self: *Model, allocator: std.mem.Allocator) void {
        allocator.free(self.distance);
        self.* = undefined;
    }

    pub fn lz77Model(self: *const Model) lz77.OptimalCostModel {
        return .{
            .literal = &self.literal,
            .length = &self.length,
            .distance = self.distance,
        };
    }
};

pub fn tokenCost(model: *const Model, tokens: []const lz77.Token) error{ InvalidBlockPlan, IntegerOverflow }!usize {
    var total: usize = 0;
    for (tokens) |token| {
        const cost: u16 = switch (token) {
            .literal => |literal| model.literal[literal],
            .match => |match| blk: {
                if (match.length < lz77.min_match_len or
                    match.length > lz77.max_match_len or
                    match.distance == 0 or
                    match.distance >= model.distance.len)
                    return error.InvalidBlockPlan;
                break :blk std.math.add(
                    u16,
                    model.length[match.length],
                    model.distance[match.distance],
                ) catch return error.IntegerOverflow;
            },
        };
        total = std.math.add(usize, total, cost) catch return error.IntegerOverflow;
    }
    return total;
}

fn symbolCost(dynamic_bits: u4, fixed_bits: u4, extra_bits: u5) u16 {
    // An unseen symbol has no code in the provisional dynamic tree. Its fixed
    // wire width is a bounded nonzero prior; exact candidate trees remain the
    // authority after the modeled parse.
    const prefix: u16 = if (dynamic_bits == 0) fixed_bits else dynamic_bits;
    return prefix + extra_bits;
}

test "dynamic optimal symbol cost uses dynamic widths and fixed unseen priors" {
    try std.testing.expectEqual(@as(u16, 7), symbolCost(7, 9, 0));
    try std.testing.expectEqual(@as(u16, 9), symbolCost(0, 9, 0));
    try std.testing.expectEqual(@as(u16, 18), symbolCost(0, 5, 13));
}
