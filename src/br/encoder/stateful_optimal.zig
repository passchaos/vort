const std = @import("std");
const lz77 = @import("../../lz77.zig");
const stateful_plan = @import("stateful_plan.zig");
const entropy_feedback = @import("entropy_feedback.zig");
const command_encoding = @import("command_encoding.zig");
const command_plan = @import("command_plan.zig");

/// Bridge between the dense hash-chain candidates and the forward stateful
/// DP. The entropy model learned from a seed command plan prices literals,
/// command symbols (which is where the insert-length bucket finally matters),
/// and distances, so the DP can trade a longer match against a cheaper
/// command pair instead of using state-free per-token costs.
pub const Options = struct {
    window_len: usize,
    max_chain: u16,
    nice_len: u16,
    /// Per-position Pareto frontier width. One reproduces the single-best
    /// candidate set; larger values expose cheaper short/near copies.
    frontier_candidates: usize = 1,
};

pub const PlanStats = struct {
    matches: usize = 0,
    matched_bytes: usize = 0,
};

pub const Plan = struct {
    tokens: []lz77.Token,
    stats: PlanStats,

    pub fn deinit(self: Plan, allocator: std.mem.Allocator) void {
        allocator.free(self.tokens);
    }
};

/// A defensive price for edges the model cannot represent. It stays far
/// below `maxInt(u32)` so a single unavailable edge does not overflow the
/// accumulated path cost.
const unavailable_cost: u32 = std.math.maxInt(u32) / 4;

const PriceContext = struct {
    input: []const u8,
    model: *const entropy_feedback.Model,
    frontier: lz77.MatchFrontier,
    scratch: [lz77.max_frontier_candidates]stateful_plan.Match = undefined,

    fn candidates(context: *anyopaque, position: usize) stateful_plan.CandidateList {
        const self: *PriceContext = @ptrCast(@alignCast(context));
        const matches = self.frontier.at(position);
        if (matches.len == 0) return .{ .matches = &.{}, .dictionary = null };
        for (matches, 0..) |match, index| {
            self.scratch[index] = .{ .length = match.length, .distance = match.distance };
        }
        return .{ .matches = self.scratch[0..matches.len], .dictionary = null };
    }

    fn price(
        context: *const anyopaque,
        position: usize,
        insert_len: usize,
        kind: stateful_plan.Kind,
        copy_len: usize,
        distance: usize,
    ) u32 {
        const self: *const PriceContext = @ptrCast(@alignCast(context));
        switch (kind) {
            .literal => {
                const byte = self.input[position];
                const previous: u8 = if (position == 0) 0 else self.input[position - 1];
                return self.model.literal_context[
                    @as(usize, lz77.literalContextClass(previous)) * 256 + byte
                ];
            },
            .lz77 => {
                const encoding = command_encoding.forLengths(insert_len, copy_len, false) orelse
                    return unavailable_cost;
                if (distance >= self.model.distance.len) return unavailable_cost;
                const extra: u32 = @as(u32, encoding.command.insert_extra_bits) +
                    encoding.command.copy_extra_bits;
                return @as(u32, self.model.command[encoding.symbol]) +
                    extra * entropy_feedback.cost_scale +
                    self.model.distance[distance];
            },
            .dictionary => return unavailable_cost,
        }
    }
};

/// Runs the stateful DP over every input position and returns an LZ77 token
/// stream. Static-dictionary edges are intentionally absent from this first
/// slice; the existing dictionary selectors still run on the resulting
/// command plan.
pub fn planAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: Options,
    model: *const entropy_feedback.Model,
) !Plan {
    if (options.window_len == 0 or options.window_len > lz77.default_window_len)
        return error.InvalidBlockPlan;
    if (model.distance.len <= options.window_len) return error.InvalidBlockPlan;
    const frontier = try lz77.collectHashFrontierAlloc(allocator, input, .{
        .window_len = options.window_len,
        .max_chain = options.max_chain,
        .nice_len = options.nice_len,
        .min_match = 4,
        .max_match = lz77.max_match_len,
    }, options.frontier_candidates);
    defer frontier.deinit(allocator);
    var context: PriceContext = .{ .input = input, .model = model, .frontier = frontier };
    const dp_tokens = try stateful_plan.plan(
        allocator,
        input,
        .{ .context = &context, .candidates = PriceContext.candidates },
        &context,
        PriceContext.price,
        .{ .min_match = 4, .max_match = lz77.max_match_len },
    );
    defer allocator.free(dp_tokens);

    const tokens = try allocator.alloc(lz77.Token, dp_tokens.len);
    errdefer allocator.free(tokens);
    var stats = PlanStats{};
    for (dp_tokens, 0..) |token, index| {
        tokens[index] = switch (token) {
            .literal => |byte| .{ .literal = byte },
            .lz77 => |match| blk: {
                stats.matches += 1;
                stats.matched_bytes += match.length;
                break :blk .{ .match = .{
                    .length = @intCast(match.length),
                    .distance = @intCast(match.distance),
                } };
            },
            .dictionary => return error.InvalidBlockPlan,
        };
    }
    return .{ .tokens = tokens, .stats = stats };
}

test "stateful optimal plan round-trips a repetitive input" {
    const input = "abcabcabcabcabcabcabcabc";
    var seed = try lz77.hashGreedyPlanAutoAlloc(std.testing.allocator, input, .{ .min_match = 4 });
    defer seed.deinit(std.testing.allocator);
    const commands = try command_plan.buildAlloc(std.testing.allocator, input, seed.tokens);
    defer commands.deinit(std.testing.allocator);
    var model = try entropy_feedback.build(std.testing.allocator, input, commands.commands, input.len);
    defer model.deinit(std.testing.allocator);

    const plan = try planAlloc(std.testing.allocator, input, .{
        .window_len = input.len,
        .max_chain = 16,
        .nice_len = lz77.max_match_len,
        .frontier_candidates = 4,
    }, &model);
    defer plan.deinit(std.testing.allocator);
    const replayed = try lz77.replayAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
    try std.testing.expect(plan.stats.matches >= 1);
}

test "stateful optimal plan rejects a window the model cannot price" {
    var model: entropy_feedback.Model = undefined;
    const distance = [_]u16{ 256, 256, 256 };
    model.distance = @constCast(&distance);
    model.literal = @splat(256);
    model.literal_context = @splat(256);
    model.length = @splat(256);
    model.command = @splat(256);
    model.distance_symbol = @splat(256);
    try std.testing.expectError(error.InvalidBlockPlan, planAlloc(
        std.testing.allocator,
        "abcdef",
        .{ .window_len = 4, .max_chain = 4, .nice_len = 8 },
        &model,
    ));
}
