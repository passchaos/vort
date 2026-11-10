//! Whole-operation heap accounting for the reusable sync-flush arena facade.
const std = @import("std");
const shared = @import("../../io/requested_heap_budget.zig");
pub const Lease = shared.Lease;
pub const isTracked = shared.isTracked;
pub const Error = @import("total_budget.zig").Error;
pub const Physical = @import("arena_budget/physical.zig").Physical;
pub const adoptAllocated = @import("arena_budget/physical.zig").adoptAllocated;
pub const Operation = @import("arena_budget/operation.zig").Operation;

const Arena = std.heap.ArenaAllocator;
const NodePointer = @typeInfo(@FieldType(Arena.State, "used_list")).optional.child;
const Node = @typeInfo(NodePointer).pointer.child;
pub const node_header_bytes = @sizeOf(Node);

/// Std Arena.queryCapacity excludes Node headers. Its public State exposes the
/// used/free node lists; each size is the exact backing request, including its
/// header and allocation padding. Inspect only while this facade owns the arena.
pub fn retainedBytes(arena: Arena) Error!usize {
    var total: usize = 0;
    for ([_]?*Node{ arena.state.used_list, arena.state.free_list }) |first| {
        var it = first;
        while (it) |node| : (it = node.next) {
            var size = node.size;
            size.resizing = false;
            const bytes: usize = @bitCast(size);
            total = std.math.add(usize, total, bytes) catch return error.IntegerOverflow;
        }
    }
    return total;
}
