//! Shared requested-byte accounting, worker-local errors, and backing safety.
const std = @import("std");
const builtin = @import("builtin");
const memory = @import("memory.zig");
const a = std.testing.allocator;

test "XZ parallel heap quota admits exact requests and rejects one below without publication" {
    for ([_]usize{ 64, 63 }) |maximum| {
        var budget = memory.Budget.init(a, maximum);
        var coordinator: memory.Slot = .{ .budget = &budget };
        var worker: memory.Slot = .{ .budget = &budget };
        const control = try coordinator.allocator().alloc(u8, 16);
        if (maximum == 64) {
            const bytes = try worker.allocator().alloc(u8, 48);
            try std.testing.expectEqual(@as(usize, 64), budget.liveRequestedBytes());
            try std.testing.expectEqual(@as(usize, 64), budget.peakRequestedBytes());
            // Worker allocation is released by the joined coordinator slot.
            coordinator.allocator().free(bytes);
        } else {
            try std.testing.expectError(error.OutOfMemory, worker.allocator().alloc(u8, 48));
            try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, worker.mapError(error.OutOfMemory));
            try std.testing.expectEqual(@as(usize, 16), budget.liveRequestedBytes());
            try std.testing.expectEqual(@as(usize, 16), budget.peakRequestedBytes());
        }
        worker.allocator().free(control);
        try std.testing.expectEqual(@as(usize, 0), budget.liveRequestedBytes());
    }
    var zero = memory.Budget.init(a, 0);
    var slot: memory.Slot = .{ .budget = &zero };
    try std.testing.expectError(error.OutOfMemory, slot.allocator().alloc(u8, 1));
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, slot.mapError(error.OutOfMemory));
    try std.testing.expectEqual(@as(usize, 0), zero.peakRequestedBytes());
}

test "XZ parallel resize and remap account successful deltas and reset only their slot" {
    var storage: [128]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var budget = memory.Budget.init(fixed.allocator(), 48);
    var worker: memory.Slot = .{ .budget = &budget };
    var sibling: memory.Slot = .{ .budget = &budget };
    const allocator = worker.allocator();
    var bytes = try allocator.alloc(u8, 16);
    try std.testing.expect(!allocator.resize(bytes, 49));
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, worker.mapError(error.OutOfMemory));
    const other = try sibling.allocator().alloc(u8, 8);
    sibling.allocator().free(other);
    try std.testing.expect(worker.last_failure_was_limit);
    try std.testing.expect(!sibling.last_failure_was_limit);
    try std.testing.expectEqual(@as(usize, 16), budget.liveRequestedBytes());
    try std.testing.expect(allocator.resize(bytes, 32));
    bytes = bytes.ptr[0..32];
    try std.testing.expect(!worker.last_failure_was_limit);
    try std.testing.expectEqual(@as(usize, 32), budget.liveRequestedBytes());
    try std.testing.expect(allocator.remap(bytes, 49) == null);
    try std.testing.expect(worker.last_failure_was_limit);
    bytes = allocator.remap(bytes, 48) orelse return error.TestUnexpectedResult;
    try std.testing.expect(!worker.last_failure_was_limit);
    try std.testing.expectEqual(@as(usize, 48), budget.liveRequestedBytes());
    bytes = allocator.remap(bytes, 8) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 8), budget.liveRequestedBytes());
    try std.testing.expectError(error.OutOfMemory, allocator.alloc(u8, 41));
    allocator.free(bytes);
    try std.testing.expect(worker.last_failure_was_limit); // free does not clear it.
    try std.testing.expectEqual(@as(usize, 0), budget.liveRequestedBytes());
    try std.testing.expectEqual(@as(usize, 48), budget.peakRequestedBytes());
    worker.clearFailure();
    try std.testing.expectEqual(error.OutOfMemory, worker.mapError(error.OutOfMemory));
    try std.testing.expectEqual(error.InvalidBlockPlan, worker.mapError(error.InvalidBlockPlan));
    const spawn_error: std.Thread.SpawnError = error.OutOfMemory;
    try std.testing.expectEqual(error.OutOfMemory, worker.mapError(spawn_error));
}

test "XZ parallel backing refusal and sibling quota denial keep independent error classes" {
    var backing = std.testing.FailingAllocator.init(a, .{ .fail_index = 1, .resize_fail_index = 0 });
    var budget = memory.Budget.init(backing.allocator(), 32);
    var limit_slot: memory.Slot = .{ .budget = &budget };
    var backing_slot: memory.Slot = .{ .budget = &budget };
    var coordinator: memory.Slot = .{ .budget = &budget };
    const bytes = try coordinator.allocator().alloc(u8, 16);
    try std.testing.expectError(error.OutOfMemory, limit_slot.allocator().alloc(u8, 17));
    try std.testing.expectError(error.OutOfMemory, backing_slot.allocator().alloc(u8, 8));
    try std.testing.expect(backing.has_induced_failure);
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, limit_slot.mapError(error.OutOfMemory));
    try std.testing.expectEqual(error.OutOfMemory, backing_slot.mapError(error.OutOfMemory));
    try std.testing.expect(!backing_slot.allocator().resize(bytes, 24));
    try std.testing.expectEqual(error.OutOfMemory, backing_slot.mapError(error.OutOfMemory));
    try std.testing.expect(backing_slot.allocator().remap(bytes, 24) == null);
    try std.testing.expectEqual(error.OutOfMemory, backing_slot.mapError(error.OutOfMemory));
    try std.testing.expectEqual(@as(usize, 16), budget.liveRequestedBytes());
    backing.fail_index = std.math.maxInt(usize);
    const success = try backing_slot.allocator().alloc(u8, 8);
    try std.testing.expect(!backing_slot.last_failure_was_limit);
    try std.testing.expect(limit_slot.last_failure_was_limit);
    coordinator.allocator().free(success);
    coordinator.allocator().free(bytes);
    try std.testing.expect(limit_slot.last_failure_was_limit);
    try std.testing.expectEqual(@as(usize, 0), budget.liveRequestedBytes());
    try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
}

/// FixedBufferAllocator is deliberately used through its non-thread-safe API.
/// An atomic reentry detector prevents an erroneous implementation from racing
/// its bookkeeping, while recording that the public budget failed to serialize.
const SerialBacking = struct {
    fixed: std.heap.FixedBufferAllocator,
    active: std.atomic.Value(bool) = .init(false),
    reentries: std.atomic.Value(usize) = .init(0),
    calls: usize = 0,

    fn allocator(self: *SerialBacking) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn enter(self: *SerialBacking) bool {
        if (self.active.swap(true, .acquire)) {
            _ = self.reentries.fetchAdd(1, .monotonic);
            return false;
        }
        self.calls += 1;
        for (0..256) |_| std.atomic.spinLoopHint();
        return true;
    }
    fn leave(self: *SerialBacking) void {
        self.active.store(false, .release);
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *SerialBacking = @ptrCast(@alignCast(raw));
        if (!self.enter()) return null;
        defer self.leave();
        return self.fixed.allocator().rawAlloc(len, alignment, address);
    }
    fn resize(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, address: usize) bool {
        const self: *SerialBacking = @ptrCast(@alignCast(raw));
        if (!self.enter()) return false;
        defer self.leave();
        return self.fixed.allocator().rawResize(bytes, alignment, len, address);
    }
    fn remap(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, address: usize) ?[*]u8 {
        const self: *SerialBacking = @ptrCast(@alignCast(raw));
        if (!self.enter()) return null;
        defer self.leave();
        return self.fixed.allocator().rawRemap(bytes, alignment, len, address);
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *SerialBacking = @ptrCast(@alignCast(raw));
        if (!self.enter()) return;
        defer self.leave();
        self.fixed.allocator().rawFree(bytes, alignment, address);
    }
};

const Job = struct {
    slot: memory.Slot,
    start: *std.atomic.Value(bool),
    output: ?[]u8 = null,
    failed: bool = false,

    fn run(self: *Job) void {
        while (!self.start.load(.acquire)) std.atomic.spinLoopHint();
        const allocator = self.slot.allocator();
        for (0..64) |_| {
            var bytes = allocator.alloc(u8, 16) catch {
                self.failed = true;
                return;
            };
            @memset(bytes, 0x5a);
            if (allocator.resize(bytes, 24)) bytes = bytes.ptr[0..24];
            if (allocator.remap(bytes, 32)) |updated| bytes = updated;
            allocator.free(bytes);
            _ = self.slot.budget.liveRequestedBytes();
            _ = self.slot.budget.peakRequestedBytes();
        }
        self.output = allocator.alloc(u8, 8) catch {
            self.failed = true;
            return;
        };
        @memset(self.output.?, 0x37);
    }
};

test "XZ parallel budget serializes backing and shared snapshots through worker completion" {
    var storage: [64 * 1024]u8 = undefined;
    var backing: SerialBacking = .{ .fixed = std.heap.FixedBufferAllocator.init(&storage) };
    var budget = memory.Budget.init(backing.allocator(), 1024);
    var start: std.atomic.Value(bool) = .init(false);
    var jobs: [4]Job = undefined;
    for (&jobs) |*job| job.* = .{ .slot = .{ .budget = &budget }, .start = &start };
    var coordinator: memory.Slot = .{ .budget = &budget };
    defer for (&jobs) |*job| {
        if (job.output) |output| coordinator.allocator().free(output);
    };
    if (comptime builtin.single_threaded) {
        start.store(true, .release);
        for (&jobs) |*job| job.run();
    } else {
        var threads: [jobs.len]std.Thread = undefined;
        var count: usize = 0;
        {
            defer {
                start.store(true, .release);
                for (threads[0..count]) |thread| thread.join();
            }
            for (&jobs) |*job| {
                threads[count] = try std.Thread.spawn(.{}, Job.run, .{job});
                count += 1;
            }
            start.store(true, .release);
        }
    }
    for (&jobs) |*job| {
        try std.testing.expect(!job.failed);
        const output = job.output orelse return error.TestUnexpectedResult;
        for (output) |byte| try std.testing.expectEqual(@as(u8, 0x37), byte);
        coordinator.allocator().free(output);
        job.output = null;
    }
    try std.testing.expectEqual(@as(usize, 0), backing.reentries.load(.monotonic));
    try std.testing.expect(backing.calls >= 4 * 64 * 4);
    try std.testing.expectEqual(@as(usize, 0), budget.liveRequestedBytes());
    try std.testing.expect(budget.peakRequestedBytes() >= 32);
    try std.testing.expect(budget.peakRequestedBytes() <= 1024);
}

const QuotaJob = struct {
    slot: memory.Slot,
    start: *std.atomic.Value(bool),
    bytes: ?[]u8 = null,
    failure: ?anyerror = null,

    fn run(self: *QuotaJob) void {
        while (!self.start.load(.acquire)) std.atomic.spinLoopHint();
        self.bytes = self.slot.allocator().alloc(u8, 8) catch |err| {
            self.failure = self.slot.mapError(err);
            return;
        };
    }
};

test "XZ parallel concurrent requests cannot over-admit shared remaining quota" {
    var budget = memory.Budget.init(a, 32);
    var start: std.atomic.Value(bool) = .init(false);
    var jobs: [8]QuotaJob = undefined;
    for (&jobs) |*job| job.* = .{ .slot = .{ .budget = &budget }, .start = &start };
    var coordinator: memory.Slot = .{ .budget = &budget };
    defer for (&jobs) |*job| {
        if (job.bytes) |bytes| coordinator.allocator().free(bytes);
    };
    if (comptime builtin.single_threaded) {
        start.store(true, .release);
        for (&jobs) |*job| job.run();
    } else {
        var threads: [jobs.len]std.Thread = undefined;
        var count: usize = 0;
        {
            defer {
                start.store(true, .release);
                for (threads[0..count]) |thread| thread.join();
            }
            for (&jobs) |*job| {
                threads[count] = try std.Thread.spawn(.{}, QuotaJob.run, .{job});
                count += 1;
            }
            start.store(true, .release);
        }
    }
    var admitted: usize = 0;
    var refused: usize = 0;
    for (&jobs) |*job| {
        if (job.bytes != null) {
            admitted += 1;
            try std.testing.expect(job.failure == null);
            try std.testing.expect(!job.slot.last_failure_was_limit);
        } else {
            refused += 1;
            try std.testing.expectEqual(@as(?anyerror, error.WorkingMemoryLimitExceeded), job.failure);
        }
    }
    try std.testing.expectEqual(@as(usize, 4), admitted);
    try std.testing.expectEqual(@as(usize, 4), refused);
    try std.testing.expectEqual(@as(usize, 32), budget.liveRequestedBytes());
    try std.testing.expectEqual(@as(usize, 32), budget.peakRequestedBytes());
    for (&jobs) |*job| {
        if (job.bytes) |bytes| {
            coordinator.allocator().free(bytes);
            job.bytes = null;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), budget.liveRequestedBytes());
    for (&jobs) |*job| if (job.failure != null) {
        try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, job.slot.mapError(error.OutOfMemory));
    };
}
