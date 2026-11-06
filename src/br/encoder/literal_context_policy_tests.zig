const std = @import("std");
const policy = @import("literal_context_policy.zig");
const blocks = @import("block_split_plan.zig");
const entropy = @import("literal_entropy_plan.zig");
const prepared = @import("prepared_literal.zig");

fn jointPlan() !entropy.Plan {
    const lengths = [_]u32{ 4, 4 };
    const types = [_]u8{ 0, 1 };
    const temporal: blocks.Plan = .{ .lengths = @constCast(&lengths), .types = @constCast(&types), .type_count = 2, .estimated_bits = 17 };
    var map: [128]u8 = undefined;
    for (&map, 0..) |*tree, index| tree.* = @intCast(index / 32);
    return entropy.Plan.initCopy(std.testing.allocator, temporal, &.{ 2, 0 }, &map, 4, 8);
}

test "literal context control projection preserves compatible block-plan identity" {
    const Options = struct {
        disable_literal_context_modeling: bool = false,
        literal_entropy_plan: ?*const entropy.Plan,
        adaptive_literal_split: ?*const blocks.Plan = null,
        literal_split: ?u8 = 7,
        literal_context_mode: u2 = 3,
        distance_context_trees: bool = true,
        use_recent_distances: bool = true,
    };
    var joint = try jointPlan();
    defer joint.deinit(std.testing.allocator);
    const original_map = try std.testing.allocator.dupe(u8, joint.context_map);
    defer std.testing.allocator.free(original_map);
    var requested: Options = .{ .literal_entropy_plan = &joint };
    try std.testing.expectEqualDeep(requested, policy.command(requested));
    requested.disable_literal_context_modeling = true;
    const projected = policy.command(requested);
    try std.testing.expectEqual(@as(?*const blocks.Plan, &joint.block_plan), projected.adaptive_literal_split);
    try std.testing.expect(projected.literal_entropy_plan == null and projected.literal_split == null);
    try std.testing.expectEqual(requested.literal_context_mode, projected.literal_context_mode);
    try std.testing.expect(projected.distance_context_trees and projected.use_recent_distances);
    try projected.adaptive_literal_split.?.validate(8);
    try std.testing.expectEqualSlices(u32, &.{ 4, 4 }, projected.adaptive_literal_split.?.lengths);
    try std.testing.expectEqualSlices(u8, original_map, joint.context_map);

    const Mutable = struct {
        disable_literal_context_modeling: bool = true,
        literal_entropy_plan: ?*entropy.Plan,
        adaptive_literal_split: ?*const blocks.Plan = null,
    };
    const borrowed = policy.command(Mutable{ .literal_entropy_plan = &joint });
    try std.testing.expectEqual(@as(?*const blocks.Plan, &joint.block_plan), borrowed.adaptive_literal_split);
}

test "literal context control capture accepts synthetic optional markers" {
    const Options = struct {
        disable_literal_context_modeling: bool = false,
        literal_entropy_plan: ?u8 = 2,
        adaptive_literal_split: ?u8 = 3,
        literal_split: ?u8 = 4,
        literal_context_candidate: ?@import("literal_context_split.zig").Candidate = null,
        use_utf8_text_contexts: bool = false,
        utf8_context_cutoff: u6 = 56,
        literal_context_mode: u2 = 2,
        initial_previous: [2]u8 = .{ 0, 0 },
        optimize_literal_tree_wire: bool = false,
        write_stream_prefix: bool = true,
        final_meta_block: bool = true,
        metadata: []const u8 = "",
    };
    var alphabet: prepared.Alphabet = .{};
    alphabet.len = 1;
    alphabet.symbols[0] = 'x';
    const lengths: [256]u4 = @splat(0);
    inline for (.{ false, true }) |disabled| {
        const requested: Options = .{ .disable_literal_context_modeling = disabled };
        var state: prepared.State = .{};
        try state.capture("x", requested, null, &.{alphabet}, &.{lengths}, 3, 0);
        try std.testing.expect(state.ready and state.matches("x", requested));
        const projected = policy.command(requested);
        try std.testing.expectEqual(requested.adaptive_literal_split, projected.adaptive_literal_split);
        try std.testing.expectEqual(requested.literal_split, projected.literal_split);
        try std.testing.expectEqual(requested.literal_context_mode, projected.literal_context_mode);
        if (disabled) try std.testing.expect(projected.literal_entropy_plan == null) else try std.testing.expectEqualDeep(requested, projected);
    }

    const PointerMarker = struct {
        disable_literal_context_modeling: bool = true,
        literal_entropy_plan: ?*const entropy.Plan,
        adaptive_literal_split: ?u8 = 5,
        literal_split: ?u8 = 6,
    };
    var joint = try jointPlan();
    defer joint.deinit(std.testing.allocator);
    const projected = policy.command(PointerMarker{ .literal_entropy_plan = &joint });
    try std.testing.expectEqual(@as(?u8, 5), projected.adaptive_literal_split);
    try std.testing.expectEqual(@as(?u8, 6), projected.literal_split);
    try std.testing.expect(projected.literal_entropy_plan == null);
}

test "literal context control projection preserves incompatible mutable destinations" {
    const Options = struct {
        disable_literal_context_modeling: bool = true,
        literal_entropy_plan: ?*const entropy.Plan,
        adaptive_literal_split: ?*blocks.Plan,
        literal_split: ?u8 = 9,
    };
    var joint = try jointPlan();
    defer joint.deinit(std.testing.allocator);
    var previous = joint.block_plan;
    const projected = policy.command(Options{ .literal_entropy_plan = &joint, .adaptive_literal_split = &previous });
    try std.testing.expectEqual(@as(?*blocks.Plan, &previous), projected.adaptive_literal_split);
    try std.testing.expectEqual(@as(?u8, 9), projected.literal_split);
    try std.testing.expect(projected.literal_entropy_plan == null);
}
