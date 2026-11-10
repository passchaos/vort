const std = @import("std");
const budget = @import("../arena_budget.zig");
const shared = @import("../../../io/requested_heap_budget.zig");
const identity = @import("../../../io/requested_heap_budget/identity.zig");

pub const Operation = struct {
    lease: shared.Lease,
    arena: budget.Physical,
    output: budget.Physical,

    pub fn init(arena: std.heap.ArenaAllocator, output: std.mem.Allocator, capacity: usize, options: anytype) budget.Error!Operation {
        const primary = if (shared.isTracked(output) or !shared.isTracked(arena.child_allocator)) output else arena.child_allocator;
        const inherited = shared.isTracked(primary);
        const arena_seed = if (inherited and identity.equal(primary, arena.child_allocator)) 0 else try budget.retainedBytes(arena);
        const output_seed = if (inherited and identity.equal(primary, output)) 0 else capacity;
        const existing = std.math.add(usize, arena_seed, output_seed) catch return error.IntegerOverflow;
        var lease = shared.Lease.init(primary, options.max_total_working_memory, options.memory_profile, if (inherited) 0 else existing) catch |err| {
            if (!inherited) if (options.memory_profile) |profile| profile.record(0, options.max_total_working_memory);
            return @errorCast(err);
        };
        errdefer lease.deinit();
        if (inherited) try lease.seedExisting(existing);
        return .{
            .lease = lease,
            .arena = .{ .base = arena.child_allocator, .lease = lease, .live = arena_seed },
            .output = .{ .base = output, .lease = lease, .live = output_seed },
        };
    }
    /// Bind only after this movable Operation has reached its final stack slot.
    pub fn bind(self: *Operation, arena: *std.heap.ArenaAllocator) void {
        arena.child_allocator = self.arena.allocator();
    }
    pub fn outputAllocator(self: *Operation) std.mem.Allocator {
        return self.output.allocator();
    }
    pub fn beforePublish(self: *Operation) budget.Error!void {
        if (self.lease.snapshot().hit_limit) return error.WorkingMemoryLimitExceeded;
        if (self.arena.failure) |err| return err;
        if (self.output.failure) |err| return err;
        // Distinct caller-tracked allocators keep their own inherited limits.
        // Never bypass that allocator merely to use the primary physical base.
        var arena_lease = (try shared.Lease.fromAllocator(self.arena.base));
        defer if (arena_lease) |*lease| lease.deinit();
        if (arena_lease) |lease| if (lease.snapshot().hit_limit) return error.WorkingMemoryLimitExceeded;
        var output_lease = (try shared.Lease.fromAllocator(self.output.base));
        defer if (output_lease) |*lease| lease.deinit();
        if (output_lease) |lease| if (lease.snapshot().hit_limit) return error.WorkingMemoryLimitExceeded;
    }
    pub fn mapError(self: *Operation, err: anyerror) budget.Error {
        if (err == error.OutOfMemory) {
            self.beforePublish() catch |mapped| return mapped;
            if (self.lease.snapshot().last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
        }
        return @errorCast(err);
    }
    /// Restore physical owners and hand back borrowed capacities before closing
    /// the only owning scope reference. No arena node keeps an adapter pointer.
    pub fn deinit(self: *Operation, arena: *std.heap.ArenaAllocator) void {
        arena.child_allocator = self.arena.base;
        self.arena.handoff();
        self.output.handoff();
        self.lease.deinit();
    }
};
