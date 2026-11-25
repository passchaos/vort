const std = @import("std");
const Workspace = @import("workspace.zig").Workspace;

// Reduced geometry keeps exhaustive element comparisons small while using the
// same inline-u32-array ownership and exact lookup contract as codec Analysis.
const Analysis = struct {
    literal_count: usize,
    total: [3]u32,
    by_mode: [2][3][4]u32,
    unrelated: u8 = undefined,
};
const Proposal = struct { mode: u2, tree_count: u7, context_map: [64]u8, savings_bits: u64 };
const Proposals = struct { suffix: ?Proposal = null, up_to_16: ?Proposal = null, full: ?Proposal = null };
const Owner = Workspace(Analysis, Proposals);

fn analysis() Analysis {
    var value: Analysis = .{ .literal_count = 67, .total = .{ 17, 23, 27 }, .by_mode = undefined };
    for (&value.by_mode, 0..) |*mode, m| for (mode, 0..) |*context, c| for (context, 0..) |*count, s| {
        count.* = @intCast(m * 100 + c * 10 + s);
    };
    return value;
}

fn proposal(mode: u2, trees: u7, savings: u64) Proposal {
    var map: [64]u8 = undefined;
    for (&map, 0..) |*tree, context| tree.* = @intCast(context % trees);
    return .{ .mode = mode, .tree_count = trees, .context_map = map, .savings_bits = savings };
}

fn proposals() Proposals {
    return .{ .suffix = proposal(2, 2, 101), .up_to_16 = proposal(0, 16, 202), .full = proposal(3, 64, 303) };
}

fn expectProposals(expected: Proposals, actual: Proposals) !void {
    inline for (.{ "suffix", "up_to_16", "full" }) |field| {
        if (@field(expected, field)) |value| {
            const actual_value = @field(actual, field) orelse return error.TestUnexpectedResult;
            try std.testing.expectEqual(value.mode, actual_value.mode);
            try std.testing.expectEqual(value.tree_count, actual_value.tree_count);
            try std.testing.expectEqual(value.savings_bits, actual_value.savings_bits);
            try std.testing.expectEqualSlices(u8, &value.context_map, &actual_value.context_map);
        } else try std.testing.expect(@field(actual, field) == null);
    }
}

test "context proposal workspace empty initialization and deinit allocate nothing" {
    var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var owner = Owner.init();
    const candidate = analysis();
    try std.testing.expect(owner.retained == null and owner.cached == null);
    try std.testing.expect(owner.lookup(&candidate) == null);
    owner.deinit(heap.allocator());
    try std.testing.expectEqual(@as(usize, 0), heap.alloc_index);
    try std.testing.expectEqual(@as(usize, 0), heap.freed_bytes);
    try std.testing.expect(!heap.has_induced_failure);
}

test "context proposal workspace compares every count field without struct padding" {
    const allocator = std.testing.allocator;
    var owner = Owner.init();
    defer owner.deinit(allocator);
    var base = analysis();
    base.unrelated = 1;
    const owned = try allocator.create(Analysis);
    owned.* = base;
    owner.publish(allocator, owned, proposals());
    var equal = base;
    equal.unrelated = 2;
    try expectProposals(proposals(), owner.lookup(&equal).?);
    var different_count = base;
    different_count.literal_count += 1;
    try std.testing.expect(owner.lookup(&different_count) == null);
    for (0..base.total.len) |symbol| {
        var changed = base;
        changed.total[symbol] += 1;
        try std.testing.expect(owner.lookup(&changed) == null);
    }
    for (0..base.by_mode.len) |mode| for (0..base.by_mode[mode].len) |context| for (0..base.by_mode[mode][context].len) |symbol| {
        var changed = base;
        changed.by_mode[mode][context][symbol] += 1;
        try std.testing.expect(owner.lookup(&changed) == null);
    };
    try expectProposals(proposals(), owner.lookup(&base).?);
}

test "context proposal workspace all-null proposals are hits and result maps are values" {
    const allocator = std.testing.allocator;
    var owner = Owner.init();
    defer owner.deinit(allocator);
    const candidate = analysis();
    const owned = try allocator.create(Analysis);
    owned.* = candidate;
    owner.publish(allocator, owned, .{});
    try std.testing.expect(owner.lookup(&candidate) != null);
    try expectProposals(.{}, owner.lookup(&candidate).?);
    owner.publish(allocator, owned, proposals());
    var returned = owner.lookup(&candidate).?;
    returned.full.?.context_map = @splat(0);
    returned.suffix.?.savings_bits = 0;
    try expectProposals(proposals(), owner.lookup(&candidate).?);
}

test "context proposal workspace owns immutable parsed counts and never retains lookup candidates" {
    var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const allocator = heap.allocator();
    var owner = Owner.init();
    defer owner.deinit(allocator);
    var parsed = analysis();
    const original = parsed;
    const owned = try allocator.create(Analysis);
    owned.* = parsed;
    owner.publish(allocator, owned, proposals());
    parsed.total[2] += 1;
    parsed.by_mode[1][2][3] += 1;
    try std.testing.expect(owner.lookup(&parsed) == null);
    try expectProposals(proposals(), owner.lookup(&original).?);
    const fresh = try allocator.create(Analysis);
    fresh.* = original;
    try expectProposals(proposals(), owner.lookup(fresh).?);
    fresh.literal_count += 1;
    allocator.destroy(fresh);
    try std.testing.expectEqual(@as(usize, @sizeOf(Analysis)), heap.freed_bytes);
    try std.testing.expect(owner.retained == owned);
    try expectProposals(proposals(), owner.lookup(&original).?);
}

test "context proposal workspace replacement and same-pointer publication free exactly once" {
    var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const allocator = heap.allocator();
    var owner = Owner.init();
    const first = try allocator.create(Analysis);
    const second = try allocator.create(Analysis);
    first.* = analysis();
    second.* = analysis();
    second.literal_count += 1;
    const first_key = first.*;
    const second_key = second.*;
    const allocations = heap.alloc_index;
    heap.fail_index = allocations;
    owner.publish(allocator, first, proposals());
    try std.testing.expectEqual(@as(usize, 0), heap.freed_bytes);
    try expectProposals(proposals(), owner.lookup(&first_key).?);
    owner.publish(allocator, second, .{});
    try std.testing.expectEqual(@as(usize, @sizeOf(Analysis)), heap.freed_bytes);
    try std.testing.expect(owner.lookup(&first_key) == null);
    try expectProposals(.{}, owner.lookup(&second_key).?);
    owner.publish(allocator, second, proposals());
    try std.testing.expectEqual(@as(usize, @sizeOf(Analysis)), heap.freed_bytes);
    try expectProposals(proposals(), owner.lookup(&second_key).?);
    owner.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2 * @sizeOf(Analysis)), heap.freed_bytes);
    try std.testing.expect(owner.retained == null and owner.cached == null);
    owner.deinit(allocator);
    try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
    try std.testing.expectEqual(allocations, heap.alloc_index);
    try std.testing.expect(!heap.has_induced_failure);
}

fn failedChoice(allocator: std.mem.Allocator) !Proposals {
    const scratch = try allocator.alloc(u8, 32);
    defer allocator.free(scratch);
    return proposals();
}

test "context proposal workspace failed miss leaves prior cached proposals usable" {
    var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const allocator = heap.allocator();
    var owner = Owner.init();
    const retained = try allocator.create(Analysis);
    retained.* = analysis();
    const old_key = retained.*;
    owner.publish(allocator, retained, proposals());
    const fresh = try allocator.create(Analysis);
    fresh.* = old_key;
    fresh.by_mode[1][2][3] += 1;
    const failed_key = fresh.*;
    try std.testing.expect(owner.lookup(fresh) == null);
    heap.fail_index = heap.alloc_index;
    try std.testing.expectError(error.OutOfMemory, failedChoice(allocator));
    // The caller destroys its untransferred miss Analysis on failure.
    allocator.destroy(fresh);
    try std.testing.expectEqual(@as(usize, @sizeOf(Analysis)), heap.freed_bytes);
    try std.testing.expect(owner.retained == retained);
    try std.testing.expect(owner.lookup(&failed_key) == null);
    try expectProposals(proposals(), owner.lookup(&old_key).?);
    owner.deinit(allocator);
    try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
    try std.testing.expect(heap.has_induced_failure);
}
