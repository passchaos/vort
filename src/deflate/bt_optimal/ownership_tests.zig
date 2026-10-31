const std = @import("std");
const bt = @import("../bt_optimal.zig");
const lz77 = @import("../../lz77.zig");
const Match = lz77.Token.Match;
const none = std.math.maxInt(usize);
const Reference = @import("reference.zig").Reference;
const compareEvidence = @import("reference.zig").compareEvidence;
const oracleCost = @import("reference.zig").oracleCost;
const validatePlan = @import("reference.zig").validatePlan;
const fill = @import("reference.zig").fill;
test "bt frontier owner releases tree before DP and cleans every allocation failure" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var input: [4096]u8 = undefined;
            fill(&input, 0x17379de2);
            var prepared = try bt.Prepared.init(allocator, &input, .{ .max_chain = 128, .max_candidates = 64 });
            defer prepared.deinit(allocator);
            const fixed = try prepared.planFixedAlloc(allocator);
            defer fixed.deinit(allocator);
            const literal: [256]u16 = @splat(9);
            const length: [259]u16 = @splat(7);
            const distance: [32769]u16 = @splat(5);
            const modeled = try prepared.planModeledAlloc(allocator, .{ .literal = &literal, .length = &length, .distance = &distance });
            defer modeled.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}

// Requested-byte accounting denies in-place growth so it also sees transient
// old/new ArrayList overlap. Fixture input is borrowed and excluded.
const TrackingAllocator = struct {
    live: usize = 0,
    peak: usize = 0,
    root_pointer: ?[*]u8 = null,
    child_pointer: ?[*]u8 = null,
    saw_roots: bool = false,
    saw_children: bool = false,
    dp_overlapped_tree: bool = false,

    fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const memory = std.testing.allocator.rawAlloc(len, alignment, ret) orelse return null;
        if (!self.saw_roots and len == bt.hash_size * @sizeOf(u16)) {
            self.saw_roots = true;
            self.root_pointer = memory;
        } else if (self.saw_roots and !self.saw_children and len == 4096 * @sizeOf([2]u16)) {
            self.saw_children = true;
            self.child_pointer = memory;
        }
        if (len == 4097 * @sizeOf(u32) and (self.root_pointer != null or self.child_pointer != null))
            self.dp_overlapped_tree = true;
        self.live += len;
        self.peak = @max(self.peak, self.live);
        return memory;
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (self.root_pointer == memory.ptr) self.root_pointer = null;
        if (self.child_pointer == memory.ptr) self.child_pointer = null;
        self.live -= memory.len;
        std.testing.allocator.rawFree(memory, alignment, ret);
    }
};

test "bt frontier measured owner lifetime and sparse density" {
    var input: [4096]u8 = undefined;
    fill(&input, 0x17379de2);
    var tracking: TrackingAllocator = .{};
    const allocator = tracking.allocator();
    var prepared = try bt.Prepared.init(allocator, &input, .{ .max_chain = 128, .max_candidates = 64 });
    const records = prepared.records.items.len;
    const capacity = prepared.records.capacity;
    const prepared_live = tracking.live;
    try std.testing.expect(tracking.saw_roots and tracking.saw_children);
    try std.testing.expect(tracking.root_pointer == null and tracking.child_pointer == null);
    try std.testing.expect(!tracking.dp_overlapped_tree);
    try std.testing.expectEqual(@as(usize, 4096) + capacity * 3 + 4097 * @sizeOf(u32) + 4096 * @sizeOf(lz77.Token), prepared_live);
    const plan = try prepared.planFixedAlloc(allocator);
    try validatePlan(&input, plan);
    plan.deinit(allocator);
    prepared.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), tracking.live);
    std.debug.print("bt frontier fixture n=4096 records={d} capacity={d} evidence_bytes={d} prepared_live={d} peak_requested={d} token_bytes={d}\n", .{ records, capacity, 4096 + capacity * 3, prepared_live, tracking.peak, @sizeOf(lz77.Token) });
}
