//! Exact retained-capacity ownership and stable, shared worker accounting.
const std = @import("std");
const memory = @import("memory.zig");
const target_supports_parallel = @import("../parallel/types.zig").target_supports_parallel;
const a = std.testing.allocator;
const base = memory.control_bytes;

fn ownerFactory(control: *memory.Control) memory.Error!void {
    const owner = control.allocator().create([16]u8) catch |err| return control.coordinator.mapError(err);
    control.allocator().destroy(owner);
}

test "XZ parallel incremental memory control preflights exact below and overflow before allocation" {
    var backing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, memory.Control.create(backing.allocator(), base - 1, 0));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, memory.Control.create(backing.allocator(), base + 15, 16));
    try std.testing.expectError(error.IntegerOverflow, memory.Control.create(backing.allocator(), std.math.maxInt(usize), std.math.maxInt(usize)));
    try std.testing.expect(!backing.has_induced_failure);
    try std.testing.expectEqual(@as(usize, 0), backing.allocated_bytes);
    try std.testing.expectError(error.OutOfMemory, memory.Control.create(backing.allocator(), base, 0));
    try std.testing.expect(backing.has_induced_failure);
    backing.fail_index = std.math.maxInt(usize);
    const control = try memory.Control.create(backing.allocator(), base, 0);
    const snapshot = control.snapshot();
    try std.testing.expectEqual(base, snapshot.control_bytes);
    try std.testing.expectEqual(base, snapshot.live_requested_bytes);
    try std.testing.expectEqual(base, snapshot.peak_requested_bytes);
    try std.testing.expectEqual(base, snapshot.limit);
    control.destroy();
    try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
}

test "XZ parallel incremental memory exact payload admission and sibling frees preserve quota error" {
    for ([_]usize{ 64, 63 }) |quota| {
        const control = try memory.Control.create(a, base + quota, 0);
        defer control.destroy();
        var worker = control.workerSlot();
        const metadata = try control.allocator().alloc(u8, 16);
        defer control.allocator().free(metadata);
        if (quota == 64) {
            const payload = try worker.allocator().alloc(u8, 48);
            try std.testing.expectEqual(base + 64, control.snapshot().live_requested_bytes);
            try std.testing.expectEqual(base + 64, control.snapshot().peak_requested_bytes);
            control.allocator().free(payload);
        } else {
            try std.testing.expectError(error.OutOfMemory, worker.allocator().alloc(u8, 48));
            const sibling = try control.allocator().alloc(u8, 1);
            control.allocator().free(sibling);
            try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, worker.mapError(error.OutOfMemory));
            try std.testing.expectEqual(base + 16, control.snapshot().live_requested_bytes);
            try std.testing.expectEqual(base + 17, control.snapshot().peak_requested_bytes);
        }
    }
}

test "XZ parallel incremental memory seed and failed owner factory rollback retain physical storage" {
    const original = try a.alloc(u8, 64);
    defer a.free(original);
    @memset(original, 0x5a);
    {
        const control = try memory.Control.create(a, base + original.len, 0);
        defer control.destroy();
        try control.budget.seedExisting(original.len);
        defer control.budget.releaseExisting(original.len);
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, control.budget.seedExisting(1));
        try std.testing.expectError(error.IntegerOverflow, control.budget.seedExisting(std.math.maxInt(usize)));
        try std.testing.expectEqual(base + original.len, control.snapshot().live_requested_bytes);
        try std.testing.expectEqual(base + original.len, control.snapshot().peak_requested_bytes);
    }
    for ([_]bool{ false, true }) |backing_failure| {
        var backing = std.testing.FailingAllocator.init(a, .{ .fail_index = 2 });
        const retained = try backing.allocator().alloc(u8, 32);
        @memset(retained, 0x37);
        {
            const quota: usize = base + retained.len + if (backing_failure) @as(usize, 16) else 0;
            const control = try memory.Control.create(backing.allocator(), quota, retained.len);
            defer control.destroy();
            defer control.budget.releaseExisting(retained.len);
            // A factory must map its coordinator error before rolling adoption back.
            try std.testing.expectError(if (backing_failure) error.OutOfMemory else error.WorkingMemoryLimitExceeded, ownerFactory(control));
            try std.testing.expectEqual(base + retained.len, control.snapshot().peak_requested_bytes);
        }
        for (retained) |byte| try std.testing.expectEqual(@as(u8, 0x37), byte);
        backing.allocator().free(retained);
        try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
    }
    const adopted = try a.alloc(u8, 16);
    const control = try memory.Control.create(a, base + adopted.len, adopted.len);
    control.allocator().free(adopted); // A committed adoption frees through its new authority.
    try std.testing.expectEqual(base, control.snapshot().live_requested_bytes);
    control.destroy();
    for (original) |byte| try std.testing.expectEqual(@as(u8, 0x5a), byte);
}

test "XZ parallel incremental memory limit transitions preserve live state and reset peak to retention" {
    const control = try memory.Control.create(a, base + 128, 0);
    defer control.destroy();
    const retained = try control.allocator().alloc(u8, 64);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, control.checkNewLimit(base + 63));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, control.changeLimit(base + 63));
    try std.testing.expectEqual(base + 128, control.snapshot().limit);
    try std.testing.expectEqual(base + 64, control.snapshot().live_requested_bytes);
    const temporary = try control.allocator().alloc(u8, 32);
    control.allocator().free(temporary);
    try std.testing.expectEqual(base + 96, control.snapshot().peak_requested_bytes);
    try control.checkNewLimit(base + 64);
    try std.testing.expectEqual(base + 128, control.snapshot().limit);
    try control.changeLimit(base + 64);
    try std.testing.expectError(error.OutOfMemory, control.allocator().alloc(u8, 1));
    control.resetPeak();
    try std.testing.expectEqual(base + 64, control.snapshot().peak_requested_bytes);
    control.allocator().free(retained);
    try std.testing.expectEqual(base, control.snapshot().live_requested_bytes);
    try std.testing.expectEqual(base + 64, control.snapshot().peak_requested_bytes);
    control.resetPeak();
    try std.testing.expectEqual(base, control.snapshot().peak_requested_bytes);
    try control.changeLimit(base);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, control.budget.seedExisting(1));
    try std.testing.expectEqual(base, control.snapshot().peak_requested_bytes);
}

test "XZ parallel incremental memory resize remap and shrink count only successful requested deltas" {
    var storage: [4096]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    const control = try memory.Control.create(fixed.allocator(), base + 48, 0);
    defer control.destroy();
    var worker = control.workerSlot();
    const allocator = worker.allocator();
    var bytes = try allocator.alloc(u8, 16);
    try std.testing.expect(!allocator.resize(bytes, 49));
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, worker.mapError(error.OutOfMemory));
    const sibling = try control.allocator().alloc(u8, 8);
    control.allocator().free(sibling);
    try std.testing.expect(worker.last_failure_was_limit);
    try std.testing.expect(allocator.resize(bytes, 32));
    bytes = bytes.ptr[0..32];
    try std.testing.expect(!worker.last_failure_was_limit);
    try std.testing.expect(allocator.remap(bytes, 49) == null);
    try std.testing.expect(worker.last_failure_was_limit);
    bytes = allocator.remap(bytes, 48) orelse return error.TestUnexpectedResult;
    try std.testing.expect(!worker.last_failure_was_limit);
    bytes = allocator.remap(bytes, 8) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(base + 8, control.snapshot().live_requested_bytes);
    try std.testing.expectEqual(base + 48, control.snapshot().peak_requested_bytes);
    try std.testing.expectError(error.OutOfMemory, allocator.alloc(u8, 41));
    allocator.free(bytes);
    try std.testing.expect(worker.last_failure_was_limit);
    try std.testing.expectEqual(base, control.snapshot().live_requested_bytes);
}

test "XZ parallel incremental memory quota backing and spawn failures keep independent slot classes" {
    var backing = std.testing.FailingAllocator.init(a, .{ .fail_index = 2, .resize_fail_index = 0 });
    const control = try memory.Control.create(backing.allocator(), base + 32, 0);
    var limited = control.workerSlot();
    var failing = control.workerSlot();
    const bytes = try control.allocator().alloc(u8, 16);
    try std.testing.expectError(error.OutOfMemory, limited.allocator().alloc(u8, 17));
    try std.testing.expectError(error.OutOfMemory, failing.allocator().alloc(u8, 8));
    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, limited.mapError(error.OutOfMemory));
    try std.testing.expectEqual(error.OutOfMemory, failing.mapError(error.OutOfMemory));
    try std.testing.expect(!failing.allocator().resize(bytes, 24));
    try std.testing.expect(failing.allocator().remap(bytes, 24) == null);
    try std.testing.expectEqual(error.OutOfMemory, failing.mapError(error.OutOfMemory));
    try std.testing.expectEqual(base + 16, control.snapshot().peak_requested_bytes);
    backing.fail_index = std.math.maxInt(usize);
    const success = try failing.allocator().alloc(u8, 8);
    control.allocator().free(success);
    control.allocator().free(bytes);
    try std.testing.expect(limited.last_failure_was_limit);
    try std.testing.expect(!failing.last_failure_was_limit);
    limited.clearFailure();
    const spawn_error: std.Thread.SpawnError = error.OutOfMemory;
    try std.testing.expectEqual(error.OutOfMemory, limited.mapError(spawn_error));
    const thread_quota: std.Thread.SpawnError = error.ThreadQuotaExceeded;
    try std.testing.expectEqual(error.ThreadQuotaExceeded, limited.mapError(thread_quota));
    try std.testing.expectEqual(error.IntegerOverflow, limited.mapError(error.IntegerOverflow));
    control.destroy();
    try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
}

test "XZ parallel incremental memory moved owner keeps coordinator allocator and worker budget stable" {
    const Owner = struct { control: *memory.Control };
    const Handle = struct { owner: *Owner, allocator: std.mem.Allocator, bytes: []u8 };
    const control = try memory.Control.create(a, base + 128, 0);
    const owner = try control.allocator().create(Owner);
    owner.* = .{ .control = control };
    var original: Handle = .{ .owner = owner, .allocator = control.allocator(), .bytes = try control.allocator().alloc(u8, 32) };
    @memset(original.bytes, 0x37);
    const moved = original;
    original = undefined;
    defer control.destroy();
    defer moved.allocator.destroy(moved.owner);
    defer moved.allocator.free(moved.bytes);
    try std.testing.expect(moved.allocator.ptr == @as(*anyopaque, @ptrCast(&moved.owner.control.coordinator)));
    var worker = moved.owner.control.workerSlot();
    try std.testing.expect(worker.budget == &moved.owner.control.budget);
    const scratch = try worker.allocator().alloc(u8, 16);
    defer moved.allocator.free(scratch);
    try std.testing.expectEqual(base + @sizeOf(Owner) + 48, moved.owner.control.snapshot().live_requested_bytes);
    for (moved.bytes) |byte| try std.testing.expectEqual(@as(u8, 0x37), byte);
}

/// The detector makes a broken wrapper fail without racing FBA bookkeeping.
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
        for (0..128) |_| std.atomic.spinLoopHint();
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
    iterations: usize,
    output: ?[]u8 = null,
    failure: ?anyerror = null,

    fn run(self: *Job) void {
        while (!self.start.load(.acquire)) std.atomic.spinLoopHint();
        const allocator = self.slot.allocator();
        for (0..self.iterations) |_| {
            var bytes = allocator.alloc(u8, 16) catch |err| {
                self.failure = self.slot.mapError(err);
                return;
            };
            if (allocator.resize(bytes, 24)) bytes = bytes.ptr[0..24];
            if (allocator.remap(bytes, 32)) |updated| bytes = updated;
            allocator.free(bytes);
            _ = self.slot.budget.snapshot();
        }
        self.output = allocator.alloc(u8, 8) catch |err| {
            self.failure = self.slot.mapError(err);
            return;
        };
        @memset(self.output.?, 0x37);
    }
};

fn runJobs(jobs: []Job, start: *std.atomic.Value(bool)) !void {
    if (comptime !target_supports_parallel) {
        start.store(true, .release);
        for (jobs) |*job| job.run();
    } else {
        var threads: [8]std.Thread = undefined;
        var count: usize = 0;
        defer {
            start.store(true, .release);
            for (threads[0..count]) |thread| thread.join();
        }
        for (jobs) |*job| {
            threads[count] = try std.Thread.spawn(.{}, Job.run, .{job});
            count += 1;
        }
        start.store(true, .release);
    }
}

test "XZ parallel incremental memory serializes unsafe backing and prevents concurrent over admission" {
    var storage: [64 * 1024]u8 = undefined;
    var backing: SerialBacking = .{ .fixed = std.heap.FixedBufferAllocator.init(&storage) };
    const control = try memory.Control.create(backing.allocator(), base + 512, 0);
    defer control.destroy();
    var start: std.atomic.Value(bool) = .init(false);
    var jobs: [8]Job = undefined;
    for (&jobs) |*job| job.* = .{ .slot = control.workerSlot(), .start = &start, .iterations = 64 };
    defer for (&jobs) |*job| if (job.output) |bytes| control.allocator().free(bytes);
    try runJobs(&jobs, &start);
    for (&jobs) |*job| {
        try std.testing.expect(job.failure == null);
        const bytes = job.output orelse return error.TestUnexpectedResult;
        for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0x37), byte);
        control.allocator().free(bytes);
        job.output = null;
    }
    try std.testing.expectEqual(@as(usize, 0), backing.reentries.load(.monotonic));
    try std.testing.expect(backing.calls >= jobs.len * 64 * 4);
    try std.testing.expect(control.snapshot().peak_requested_bytes <= base + 512);
    try std.testing.expectEqual(base, control.snapshot().live_requested_bytes);
    try control.changeLimit(base + 32);
    control.resetPeak();
    start.store(false, .release);
    for (&jobs) |*job| job.* = .{ .slot = control.workerSlot(), .start = &start, .iterations = 0 };
    try runJobs(&jobs, &start);
    var admitted: usize = 0;
    for (&jobs) |*job| {
        if (job.output != null) {
            admitted += 1;
            try std.testing.expect(job.failure == null);
        } else try std.testing.expectEqual(@as(?anyerror, error.WorkingMemoryLimitExceeded), job.failure);
    }
    try std.testing.expectEqual(@as(usize, 4), admitted);
    try std.testing.expectEqual(base + 32, control.snapshot().live_requested_bytes);
    try std.testing.expectEqual(base + 32, control.snapshot().peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), backing.reentries.load(.monotonic));
}
