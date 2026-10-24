//! HQ passes start from the same dictionary/history/cache checkpoint. Actual
//! serialized Huffman tables and command statistics train the following pass.
const std = @import("std");
const types = @import("../hq_types.zig");
const options = @import("../hq_options.zig");
const Model = @import("../hq_parser/prices.zig").Model;

pub fn candidate(comptime Codec: type, source: types.Source, resolved: options.Resolved, profile: ?*options.HqProfile, previous: [2]u8, state: anytype, context: Codec.Context) Codec.Error!Codec.Artifact {
    const budget = state.budget orelse return error.InvalidBlockPlan;
    const a = budget.allocator();
    defer if (profile) |p| p.recordPeak(budget.peak);
    return candidateInternal(Codec, a, source, resolved, profile, previous, state, context) catch |err| {
        if (err == error.OutOfMemory and budget.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
        return err;
    };
}

fn candidateInternal(comptime Codec: type, a: std.mem.Allocator, source: types.Source, resolved: options.Resolved, profile: ?*options.HqProfile, previous: [2]u8, state: anytype, context: Codec.Context) Codec.Error!Codec.Artifact {
    const working_model = try a.create(Model);
    defer a.destroy(working_model);
    working_model.* = (state.model orelse return error.InvalidBlockPlan).*;
    working_model.literal_position_prices = null;
    var best: ?Codec.Artifact = null;
    errdefer if (best) |*artifact| artifact.deinit(a);
    for (0..resolved.iterations) |pass| {
        if (pass != 0) if (profile) |p| p.add("refinement_passes", 1);
        const plan = try Codec.planAlloc(a, source, resolved, profile, previous, working_model, state);
        defer plan.deinit(a);
        var artifact = try encodePass(Codec, a, source, &plan, context);
        working_model.* = artifact.model.?.*;
        if (best == null or artifact.bit_count < best.?.bit_count) {
            if (best) |*old| old.deinit(a);
            best = artifact;
        } else artifact.deinit(a);
    }
    return best orelse error.InvalidBlockPlan;
}

fn encodePass(comptime Codec: type, a: std.mem.Allocator, source: types.Source, plan: anytype, context: Codec.Context) Codec.Error!Codec.Artifact {
    const actual_model = try a.create(Model);
    errdefer a.destroy(actual_model);
    var artifact = try Codec.writePlan(a, source, plan, context, actual_model);
    errdefer artifact.deinit(a);
    try Codec.checkPlanState(plan, &artifact);
    actual_model.* = try actual_model.refined(Codec.statistics(plan));
    actual_model.literal_position_prices = null;
    artifact.model = actual_model;
    return artifact;
}

/// The legacy serializer needs reachable history, rather than a truncated
/// cumulative position. Local command positions are then added with checks.
pub fn normalHistoryBase(frame_offset: u64, window_len: usize) usize {
    return @intCast(@min(frame_offset, @as(u64, window_len)));
}

test "Brotli HQ normal history base saturates long stream offsets without truncation" {
    const window_len: usize = (1 << 24) - 16;
    try std.testing.expectEqual(@as(usize, 23), normalHistoryBase(23, window_len));
    try std.testing.expectEqual(window_len, normalHistoryBase(@as(u64, 1) << 32, window_len));
    try std.testing.expectEqual(window_len, normalHistoryBase(std.math.maxInt(u64), window_len));
}
