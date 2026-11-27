const std = @import("std");
const reuse = @import("split_plan_reuse.zig");
const block = @import("block_split_plan.zig");
const joint = @import("literal_entropy_plan.zig");
const command = @import("command_plan.zig");
const a = std.testing.allocator;
const Wire = struct { large_window: bool = false, window_bits: u5 = 16, initial_output_pos: usize = 0, starting_last_distances: [4]usize = .{ 4, 11, 15, 16 } };
const Cache = reuse.Owner(Wire);
const input = "abcdef";
const group = [_]command.Command{.{ .insert_start = 0, .insert_len = input.len }};

fn key() Cache.Key {
    return .{ .use_recent_distances = true, .try_command_split = true, .try_adaptive_command_split = true, .try_distance_split = true, .try_adaptive_distance_split = true, .distance_split_min_commands = 0, .wire_context = .{} };
}

fn plan(gpa: std.mem.Allocator) !block.Plan {
    return block.Plan.initCopy(gpa, &.{ 2, 3, 1 }, &.{ 0, 1, 0 }, 2, input.len, 91);
}

fn jointPlan(gpa: std.mem.Allocator, source: block.Plan) !joint.Plan {
    var mapping: [128]u8 = undefined;
    for (&mapping, 0..) |*tree, index| tree.* = @intCast(index % 2);
    return joint.Plan.initCopy(gpa, source, &.{ 0, 2 }, &mapping, 2, input.len);
}

const Moving = struct {
    backing: std.mem.Allocator,
    allocations: usize = 0,
    live: usize = 0,
    fn allocator(self: *Moving) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }
    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *Moving = @ptrCast(@alignCast(ctx));
        const memory = self.backing.rawAlloc(len, alignment, ra) orelse return null;
        self.allocations += 1;
        self.live += len;
        return memory;
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *Moving = @ptrCast(@alignCast(ctx));
        self.backing.rawFree(memory, alignment, ra);
        self.live -= memory.len;
    }
};

test "split plan reuse searched null differs from unsearched and retires idempotently" {
    var owner = Cache.init(input, &group, reuse.budget_bytes);
    try std.testing.expect(owner.getLiteral(input, &group) == null);
    try std.testing.expect(owner.publishLiteral(input, &group, null));
    try std.testing.expect(owner.getLiteral(input, &group).?.plan == null);
    try std.testing.expect(!owner.publishLiteral(input, &group, null));
    try std.testing.expect(owner.publishSymbols(input, &group, key(), .{}));
    const symbols = owner.getSymbols(input, &group, key()).?;
    try std.testing.expect(symbols.adaptive_command == null and symbols.adaptive_distance == null);
    try std.testing.expectEqual(@as(usize, 1), owner.counters.literal_null_hits);
    try std.testing.expectEqual(@as(usize, 1), owner.counters.symbol_empty_hits);
    try std.testing.expectEqual(@sizeOf(Cache), owner.retainedRequestedBytes());
    owner.deinit(a);
    owner.deinit(a);
    try std.testing.expect(!owner.active and !owner.matches(input, &group));
    try std.testing.expectEqual(@as(usize, 0), owner.retainedRequestedBytes());
    try std.testing.expectEqual(@as(usize, 1), owner.counters.literal_captures);
    try std.testing.expect(owner.getLiteral(input, &group) == null);
}

test "split plan reuse binds exact input and nonempty original command group" {
    var same_input = [_]u8{ 'a', 'b', 'c', 'd', 'e', 'f' };
    const other = [_]command.Command{.{ .insert_start = 1, .insert_len = 5 }};
    var owner = Cache.init(input, &group, reuse.budget_bytes);
    defer owner.deinit(a);
    try std.testing.expect(!owner.matches(&same_input, &group));
    try std.testing.expect(!owner.matches(input, &other));
    try std.testing.expect(!owner.matches(input[0..5], &group));
    try std.testing.expect(!owner.publishLiteral(input, &other, null));
    try std.testing.expect(owner.getLiteral(input, &group) == null);
    var empty = Cache.init(input, group[0..0], reuse.budget_bytes);
    try std.testing.expect(!empty.active and !empty.publishSymbols(input, group[0..0], key(), .{}));
}

test "split plan reuse symbol keys cover flags threshold and complete wire arrays" {
    var owner = Cache.init(input, &group, reuse.budget_bytes);
    defer owner.deinit(a);
    const original = key();
    var proposals: reuse.SymbolPlans = .{};
    proposals.command.two = .{ .split = 2, .savings_bits = 17 };
    proposals.distance.three = .{ .split = 1, .second_split = 3, .savings_bits = 19 };
    try std.testing.expect(owner.publishSymbols(input, &group, original, proposals));
    try std.testing.expectEqualDeep(proposals, owner.getSymbols(input, &group, original).?);
    inline for (.{ "use_recent_distances", "try_command_split", "try_adaptive_command_split", "try_distance_split", "try_adaptive_distance_split" }) |field| {
        var changed = original;
        @field(changed, field) = !@field(changed, field);
        try std.testing.expect(owner.getSymbols(input, &group, changed) == null);
    }
    var changed = original;
    changed.distance_split_min_commands = 1;
    try std.testing.expect(owner.getSymbols(input, &group, changed) == null);
    for (0..4) |index| {
        changed = original;
        changed.wire_context.starting_last_distances[index] += 1;
        try std.testing.expect(owner.getSymbols(input, &group, changed) == null);
    }
    changed = original;
    changed.wire_context.initial_output_pos = 1;
    try std.testing.expect(owner.getSymbols(input, &group, changed) == null);
    changed = original;
    changed.wire_context.window_bits = 17;
    try std.testing.expect(owner.getSymbols(input, &group, changed) == null);
    changed = original;
    changed.wire_context.large_window = true;
    try std.testing.expect(owner.getSymbols(input, &group, changed) == null);
    try std.testing.expect(owner.publishSymbols(input, &group, changed, .{}));
    changed.try_distance_split = false;
    try std.testing.expect(!owner.publishSymbols(input, &group, changed, .{}));
    try std.testing.expectEqual(@as(usize, 1), owner.counters.symbol_capacity_refusals);
    var rejected: reuse.SymbolPlans = .{ .adaptive_command = try plan(a) };
    defer rejected.deinit(a);
    try std.testing.expect(!owner.publishSymbols(input, &group, changed, rejected));
    try std.testing.expectEqualSlices(u32, &.{ 2, 3, 1 }, rejected.adaptive_command.?.lengths);
    try std.testing.expectEqualDeep(proposals, owner.getSymbols(input, &group, original).?);
}

test "split plan reuse transfers real payload without allocation and releases all four joint slices" {
    var moving: Moving = .{ .backing = a };
    const gpa = moving.allocator();
    var owner = Cache.init(input, &group, reuse.budget_bytes);
    defer owner.deinit(gpa);
    const literal_plan = try plan(gpa);
    var literal_owned = true;
    defer if (literal_owned) literal_plan.deinit(gpa);
    const requests = moving.allocations;
    try std.testing.expect(owner.publishLiteral(input, &group, literal_plan));
    literal_owned = false;
    const joint_plan = try jointPlan(gpa, literal_plan);
    var joint_owned = true;
    defer if (joint_owned) joint_plan.deinit(gpa);
    try std.testing.expect(owner.publishJoint(input, &group, literal_plan, joint_plan));
    joint_owned = false;
    var symbols: reuse.SymbolPlans = .{ .adaptive_command = try plan(gpa) };
    var symbols_owned = true;
    defer if (symbols_owned) symbols.deinit(gpa);
    symbols.adaptive_distance = try plan(gpa);
    const all_requests = moving.allocations;
    try std.testing.expect(owner.publishSymbols(input, &group, key(), symbols));
    symbols_owned = false;
    const borrowed = owner.getLiteral(input, &group).?.plan.?;
    try std.testing.expect(reuse.sameLiteral(literal_plan, borrowed));
    try std.testing.expectEqual(joint_plan.context_map.ptr, owner.getJoint(input, &group, borrowed).?.plan.?.context_map.ptr);
    try std.testing.expectEqual(symbols.adaptive_distance.?.types.ptr, owner.getSymbols(input, &group, key()).?.adaptive_distance.?.types.ptr);
    try std.testing.expectEqual(@as(usize, 0), owner.counters.literal_null_hits);
    try std.testing.expectEqual(@as(usize, 0), owner.counters.joint_null_hits);
    try std.testing.expectEqual(@as(usize, 0), owner.counters.symbol_empty_hits);
    try std.testing.expectEqual(all_requests, moving.allocations);
    try std.testing.expectEqual(@as(usize, 2), requests);
    try std.testing.expectEqual(@sizeOf(Cache) + moving.live, owner.retainedRequestedBytes());
    try std.testing.expectEqual(moving.live, owner.counters.retained_payload_bytes);
    owner.deinit(gpa);
    owner.deinit(gpa);
    try std.testing.expectEqual(@as(usize, 0), moving.live);
    try std.testing.expectEqual(@as(usize, 0), owner.counters.retained_payload_bytes);
}

test "split plan reuse joint requires the exact successfully cached literal view" {
    const original = try plan(a);
    var owned = true;
    defer if (owned) original.deinit(a);
    var owner = Cache.init(input, &group, reuse.budget_bytes);
    defer owner.deinit(a);
    try std.testing.expect(!owner.publishJoint(input, &group, original, null));
    try std.testing.expect(owner.publishLiteral(input, &group, original));
    owned = false;
    const other = try original.clone(a, input.len);
    defer other.deinit(a);
    try std.testing.expect(!owner.publishJoint(input, &group, other, null));
    var modified = original;
    modified.estimated_bits += 1;
    try std.testing.expect(!owner.publishJoint(input, &group, modified, null));
    modified = original;
    modified.type_count += 1;
    try std.testing.expect(!owner.publishJoint(input, &group, modified, null));
    modified = original;
    modified.lengths.len -= 1;
    try std.testing.expect(!owner.publishJoint(input, &group, modified, null));
    modified = original;
    modified.types.len -= 1;
    try std.testing.expect(!owner.publishJoint(input, &group, modified, null));
    try std.testing.expect(owner.publishJoint(input, &group, original, null));
    try std.testing.expect(owner.getJoint(input, &group, original).?.plan == null);
    try std.testing.expectEqual(@as(usize, 1), owner.counters.joint_null_hits);
    try std.testing.expect(owner.getJoint(input, &group, other) == null);
}

test "split plan reuse exact cap includes metadata and rejected result remains caller owned" {
    var moving: Moving = .{ .backing = a };
    const gpa = moving.allocator();
    const value = try plan(gpa);
    var owned = true;
    defer if (owned) value.deinit(gpa);
    const bytes = try reuse.planRequestedBytes(value);
    var below = Cache.init(input, &group, @sizeOf(Cache) + bytes - 1);
    defer below.deinit(gpa);
    try std.testing.expect(!below.publishLiteral(input, &group, value));
    try std.testing.expectEqual(@as(usize, 1), below.counters.cap_refusals);
    try std.testing.expect(below.getLiteral(input, &group) == null);
    try std.testing.expectEqualSlices(u32, &.{ 2, 3, 1 }, value.lengths);
    var exact = Cache.init(input, &group, @sizeOf(Cache) + bytes);
    defer exact.deinit(gpa);
    try std.testing.expect(exact.publishLiteral(input, &group, value));
    owned = false;
    const joint_plan = try jointPlan(gpa, value);
    defer joint_plan.deinit(gpa);
    try std.testing.expect(!exact.publishJoint(input, &group, value, joint_plan));
    try std.testing.expect(exact.getJoint(input, &group, value) == null);
    try std.testing.expect(exact.publishJoint(input, &group, value, null));
    try std.testing.expectEqual(@sizeOf(Cache) + bytes, exact.retainedRequestedBytes());
    const too_small = Cache.init(input, &group, @sizeOf(Cache) - 1);
    try std.testing.expect(!too_small.active);
    var maximum = Cache.init(input, &group, std.math.maxInt(usize));
    try std.testing.expectEqual(reuse.budget_bytes, maximum.cap_bytes);
    maximum.deinit(gpa);
}

test "split plan reuse checked overflow and failed producers never publish" {
    var lengths = [_]u32{1};
    var types = [_]u8{0};
    var synthetic: block.Plan = .{ .lengths = &lengths, .types = &types, .type_count = 1, .estimated_bits = 1 };
    synthetic.lengths.len = std.math.maxInt(usize);
    try std.testing.expectError(error.IntegerOverflow, reuse.planRequestedBytes(synthetic));
    var owner = Cache.init(input, &group, reuse.budget_bytes);
    try std.testing.expect(!owner.publishLiteral(input, &group, synthetic));
    try std.testing.expect(owner.getLiteral(input, &group) == null);
    owner.deinit(a);
    for (0..2) |ordinal| {
        var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = ordinal });
        var fresh = Cache.init(input, &group, reuse.budget_bytes);
        defer fresh.deinit(failing.allocator());
        try std.testing.expectError(error.OutOfMemory, plan(failing.allocator()));
        try std.testing.expect(fresh.getLiteral(input, &group) == null);
        try std.testing.expectEqual(@as(usize, 0), fresh.counters.literal_captures);
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
        failing.fail_index = std.math.maxInt(usize);
        const completed = try plan(failing.allocator());
        var caller_owned = true;
        defer if (caller_owned) completed.deinit(failing.allocator());
        try std.testing.expect(fresh.publishLiteral(input, &group, completed));
        caller_owned = false;
        fresh.deinit(failing.allocator());
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
}
