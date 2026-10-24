const std = @import("std");
const block_split_plan = @import("block_split_plan.zig");

pub const contexts_per_type: usize = 64;
pub const max_tree_count: usize = 256;

pub const Error = block_split_plan.Error || error{InvalidLiteralEntropyPlan};

/// An allocator-owned literal entropy plan combining temporal block types,
/// the literal context mode for each type, and the complete type/context to
/// entropy-tree mapping.
pub const Plan = struct {
    block_plan: block_split_plan.Plan,
    context_modes: []u2,
    context_map: []u8,
    tree_count: u16,

    /// Deep-copies all four owned slices. The source block plan and mapping
    /// slices remain owned by the caller.
    pub fn initCopy(
        allocator: std.mem.Allocator,
        source_block_plan: block_split_plan.Plan,
        context_modes: []const u2,
        context_map: []const u8,
        tree_count: u16,
        symbol_count: usize,
    ) (std.mem.Allocator.Error || Error)!Plan {
        try validateParts(
            source_block_plan,
            context_modes,
            context_map,
            tree_count,
            symbol_count,
        );

        const owned_block_plan = try source_block_plan.clone(allocator, symbol_count);
        errdefer owned_block_plan.deinit(allocator);
        const owned_context_modes = try allocator.dupe(u2, context_modes);
        errdefer allocator.free(owned_context_modes);
        const owned_context_map = try allocator.dupe(u8, context_map);
        errdefer allocator.free(owned_context_map);

        return .{
            .block_plan = owned_block_plan,
            .context_modes = owned_context_modes,
            .context_map = owned_context_map,
            .tree_count = tree_count,
        };
    }

    pub fn clone(
        self: Plan,
        allocator: std.mem.Allocator,
        symbol_count: usize,
    ) (std.mem.Allocator.Error || Error)!Plan {
        return initCopy(
            allocator,
            self.block_plan,
            self.context_modes,
            self.context_map,
            self.tree_count,
            symbol_count,
        );
    }

    pub fn deinit(self: Plan, allocator: std.mem.Allocator) void {
        self.block_plan.deinit(allocator);
        allocator.free(self.context_modes);
        allocator.free(self.context_map);
    }

    pub fn validate(self: Plan, symbol_count: usize) Error!void {
        return validateParts(
            self.block_plan,
            self.context_modes,
            self.context_map,
            self.tree_count,
            symbol_count,
        );
    }

    /// Returns the entropy tree selected by one literal block type and its
    /// format-defined six-bit context value.
    pub fn treeFor(self: Plan, block_type: usize, context: usize) Error!u8 {
        if (block_type >= self.block_plan.type_count or context >= contexts_per_type)
            return error.InvalidLiteralEntropyPlan;
        const row_start = std.math.mul(usize, block_type, contexts_per_type) catch
            return error.IntegerOverflow;
        const index = std.math.add(usize, row_start, context) catch
            return error.IntegerOverflow;
        if (index >= self.context_map.len) return error.InvalidLiteralEntropyPlan;
        const tree = self.context_map[index];
        if (@as(u16, tree) >= self.tree_count) return error.InvalidLiteralEntropyPlan;
        return tree;
    }
};

fn validateParts(
    block_plan: block_split_plan.Plan,
    context_modes: []const u2,
    context_map: []const u8,
    tree_count: u16,
    symbol_count: usize,
) Error!void {
    try block_plan.validate(symbol_count);
    const type_count: usize = block_plan.type_count;
    if (context_modes.len != type_count) return error.InvalidLiteralEntropyPlan;
    const expected_map_len = try contextMapLength(type_count);
    if (context_map.len != expected_map_len) return error.InvalidLiteralEntropyPlan;
    if (tree_count == 0 or tree_count > max_tree_count)
        return error.InvalidLiteralEntropyPlan;

    // The stored u2 representation enforces this invariant by construction.
    // Keep the explicit widened check alongside the wire-format validation so
    // the condition remains visible if the storage type changes later.
    for (context_modes) |mode| {
        const widened_mode: u8 = mode;
        if (widened_mode > 3) return error.InvalidLiteralEntropyPlan;
    }

    var used_trees: [max_tree_count]bool = @splat(false);
    for (context_map) |tree| {
        if (@as(u16, tree) >= tree_count) return error.InvalidLiteralEntropyPlan;
        used_trees[tree] = true;
    }
    for (used_trees[0..tree_count]) |used|
        if (!used) return error.InvalidLiteralEntropyPlan;
}

fn contextMapLength(type_count: usize) error{IntegerOverflow}!usize {
    return std.math.mul(usize, type_count, contexts_per_type) catch
        return error.IntegerOverflow;
}

test "literal entropy plan owns a single-type mapping" {
    var lengths = [_]u32{8};
    var types = [_]u8{0};
    const source_block_plan: block_split_plan.Plan = .{
        .lengths = &lengths,
        .types = &types,
        .type_count = 1,
        .estimated_bits = 41,
    };
    var context_modes = [_]u2{2};
    var context_map: [contexts_per_type]u8 = @splat(0);

    const plan = try Plan.initCopy(
        std.testing.allocator,
        source_block_plan,
        &context_modes,
        &context_map,
        1,
        8,
    );
    defer plan.deinit(std.testing.allocator);

    lengths[0] = 1;
    context_modes[0] = 3;
    context_map[63] = 7;
    try plan.validate(8);
    try std.testing.expectEqualSlices(u32, &.{8}, plan.block_plan.lengths);
    try std.testing.expectEqualSlices(u2, &.{2}, plan.context_modes);
    try std.testing.expectEqual(@as(u8, 0), try plan.treeFor(0, 0));
    try std.testing.expectEqual(@as(u8, 0), try plan.treeFor(0, 63));
}

test "literal entropy plan supports multiple block types and cloning" {
    var lengths = [_]u32{ 3, 2, 4 };
    var types = [_]u8{ 0, 1, 0 };
    const source_block_plan: block_split_plan.Plan = .{
        .lengths = &lengths,
        .types = &types,
        .type_count = 2,
        .estimated_bits = 117,
    };
    const context_modes = [_]u2{ 0, 3 };
    var context_map: [2 * contexts_per_type]u8 = undefined;
    for (&context_map, 0..) |*tree, index| tree.* = @intCast(index % 4);

    const original = try Plan.initCopy(
        std.testing.allocator,
        source_block_plan,
        &context_modes,
        &context_map,
        4,
        9,
    );
    defer original.deinit(std.testing.allocator);
    const copy = try original.clone(std.testing.allocator, 9);
    defer copy.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u8, 3), try original.treeFor(1, 63));
    try std.testing.expectEqualDeep(original.block_plan, copy.block_plan);
    try std.testing.expectEqualSlices(u2, original.context_modes, copy.context_modes);
    try std.testing.expectEqualSlices(u8, original.context_map, copy.context_map);
    try std.testing.expect(original.block_plan.lengths.ptr != copy.block_plan.lengths.ptr);
    try std.testing.expect(original.block_plan.types.ptr != copy.block_plan.types.ptr);
    try std.testing.expect(original.context_modes.ptr != copy.context_modes.ptr);
    try std.testing.expect(original.context_map.ptr != copy.context_map.ptr);

    copy.block_plan.lengths[0] = 1;
    copy.context_modes[0] = 2;
    copy.context_map[0] = 3;
    try std.testing.expectEqual(@as(u32, 3), original.block_plan.lengths[0]);
    try std.testing.expectEqual(@as(u2, 0), original.context_modes[0]);
    try std.testing.expectEqual(@as(u8, 0), original.context_map[0]);
}

test "literal entropy plan covers 256 block and tree values" {
    var lengths: [256]u32 = @splat(1);
    var types: [256]u8 = undefined;
    var context_modes: [256]u2 = undefined;
    var context_map: [256 * contexts_per_type]u8 = undefined;
    for (&types, &context_modes, 0..) |*block_type, *mode, index| {
        block_type.* = @intCast(index);
        mode.* = @intCast(index % 4);
    }
    for (0..256) |block_type| {
        @memset(
            context_map[block_type * contexts_per_type ..][0..contexts_per_type],
            @as(u8, @intCast(block_type)),
        );
    }
    const source_block_plan: block_split_plan.Plan = .{
        .lengths = &lengths,
        .types = &types,
        .type_count = 256,
        .estimated_bits = 0,
    };

    const plan = try Plan.initCopy(
        std.testing.allocator,
        source_block_plan,
        &context_modes,
        &context_map,
        256,
        256,
    );
    defer plan.deinit(std.testing.allocator);
    try plan.validate(256);
    try std.testing.expectEqual(@as(usize, 256 * 64), plan.context_map.len);
    try std.testing.expectEqual(@as(u8, 0), try plan.treeFor(0, 63));
    try std.testing.expectEqual(@as(u8, 255), try plan.treeFor(255, 63));
}

test "literal entropy plan rejects malformed combinations" {
    var lengths = [_]u32{ 1, 1 };
    var types = [_]u8{ 0, 1 };
    var modes = [_]u2{ 0, 1 };
    var context_map: [2 * contexts_per_type]u8 = @splat(0);
    const block_plan: block_split_plan.Plan = .{
        .lengths = &lengths,
        .types = &types,
        .type_count = 2,
        .estimated_bits = 0,
    };

    try std.testing.expectError(
        error.InvalidLiteralEntropyPlan,
        Plan.initCopy(std.testing.allocator, block_plan, modes[0..1], &context_map, 1, 2),
    );
    try std.testing.expectError(
        error.InvalidLiteralEntropyPlan,
        Plan.initCopy(std.testing.allocator, block_plan, &modes, context_map[0..64], 1, 2),
    );
    try std.testing.expectError(
        error.InvalidLiteralEntropyPlan,
        Plan.initCopy(std.testing.allocator, block_plan, &modes, &context_map, 0, 2),
    );
    try std.testing.expectError(
        error.InvalidLiteralEntropyPlan,
        Plan.initCopy(std.testing.allocator, block_plan, &modes, &context_map, 257, 2),
    );

    context_map[17] = 1;
    try std.testing.expectError(
        error.InvalidLiteralEntropyPlan,
        Plan.initCopy(std.testing.allocator, block_plan, &modes, &context_map, 1, 2),
    );
    context_map[17] = 0;
    try std.testing.expectError(
        error.InvalidLiteralEntropyPlan,
        Plan.initCopy(std.testing.allocator, block_plan, &modes, &context_map, 2, 2),
    );

    var bad_types = [_]u8{ 1, 0 };
    const bad_block_plan: block_split_plan.Plan = .{
        .lengths = &lengths,
        .types = &bad_types,
        .type_count = 2,
        .estimated_bits = 0,
    };
    try std.testing.expectError(
        error.InvalidBlockPlan,
        Plan.initCopy(std.testing.allocator, bad_block_plan, &modes, &context_map, 1, 2),
    );
    try std.testing.expectError(error.IntegerOverflow, contextMapLength(std.math.maxInt(usize)));
}

test "literal entropy plan accessor validates both dimensions" {
    var lengths = [_]u32{1};
    var types = [_]u8{0};
    var modes = [_]u2{0};
    var context_map: [contexts_per_type]u8 = @splat(0);
    const block_plan: block_split_plan.Plan = .{
        .lengths = &lengths,
        .types = &types,
        .type_count = 1,
        .estimated_bits = 0,
    };
    const plan: Plan = .{
        .block_plan = block_plan,
        .context_modes = &modes,
        .context_map = &context_map,
        .tree_count = 1,
    };
    try std.testing.expectError(error.InvalidLiteralEntropyPlan, plan.treeFor(1, 0));
    try std.testing.expectError(error.InvalidLiteralEntropyPlan, plan.treeFor(0, 64));

    plan.context_map[0] = 1;
    try std.testing.expectError(error.InvalidLiteralEntropyPlan, plan.treeFor(0, 0));
}

test "literal entropy plan releases every partial allocation failure" {
    var lengths = [_]u32{ 1, 1 };
    var types = [_]u8{ 0, 1 };
    const modes = [_]u2{ 0, 1 };
    var context_map: [2 * contexts_per_type]u8 = undefined;
    for (&context_map, 0..) |*tree, index| tree.* = @intCast(index % 2);
    const block_plan: block_split_plan.Plan = .{
        .lengths = &lengths,
        .types = &types,
        .type_count = 2,
        .estimated_bits = 0,
    };

    // The nested block plan owns two slices; modes and map add two more.
    for (0..4) |fail_index| {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{
            .fail_index = fail_index,
        });
        try std.testing.expectError(
            error.OutOfMemory,
            Plan.initCopy(
                failing.allocator(),
                block_plan,
                &modes,
                &context_map,
                2,
                2,
            ),
        );
        try std.testing.expect(failing.has_induced_failure);
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
}
