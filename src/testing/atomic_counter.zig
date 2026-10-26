//! Counter instrumentation without changing the stored integer or array type.
const std = @import("std");
const builtin = @import("builtin");

pub fn add(counter: anytype, amount: anytype) void {
    const T = @typeInfo(@TypeOf(counter)).pointer.child;
    const value: T = @intCast(amount);
    if (builtin.single_threaded) {
        counter.* = std.math.add(T, counter.*, value) catch unreachable;
    } else {
        _ = @atomicRmw(T, counter, .Add, value, .monotonic);
    }
}

test "atomic counter one thread preserves typed integers array elements and zero increments" {
    var scalar: usize = 11;
    var buckets = [_]u32{ 3, 5, 7 };
    add(&scalar, @as(u8, 4));
    add(&scalar, 0);
    add(&buckets[1], @as(u16, 9));
    add(&buckets[2], @intFromBool(true));
    try std.testing.expectEqual(@as(usize, 15), scalar);
    try std.testing.expectEqualSlices(u32, &.{ 3, 14, 8 }, &buckets);
    try std.testing.expect(@TypeOf(scalar) == usize);
    try std.testing.expect(@TypeOf(buckets) == [3]u32);
}

const CounterJob = struct {
    start: *std.atomic.Value(bool),
    counter: *usize,
    buckets: *[3]u32,
    bucket: usize,
    amount: u16,
    iterations: usize,

    fn run(job: CounterJob) void {
        while (!job.start.load(.acquire)) std.atomic.spinLoopHint();
        for (0..job.iterations) |_| {
            add(job.counter, 1);
            add(&job.buckets[job.bucket], job.amount);
        }
    }
};

test "atomic counter actual joined workers retain exact shared totals" {
    const supported = !builtin.single_threaded and
        (builtin.os.tag == .linux or builtin.os.tag == .windows or std.Thread.use_pthreads);
    if (comptime !supported) return error.SkipZigTest;
    var start: std.atomic.Value(bool) = .init(false);
    var counter: usize = 7;
    var buckets = [_]u32{ 11, 13, 17 };
    var threads: [4]std.Thread = undefined;
    var spawned: usize = 0;
    defer {
        // Also release already-created workers if a later spawn fails.
        start.store(true, .release);
        for (threads[0..spawned]) |thread| thread.join();
    }
    const iterations: usize = 8192;
    for (0..threads.len) |index| {
        threads[index] = try std.Thread.spawn(.{}, CounterJob.run, .{CounterJob{
            .start = &start,
            .counter = &counter,
            .buckets = &buckets,
            .bucket = index % buckets.len,
            .amount = @intCast(index + 1),
            .iterations = iterations,
        }});
        spawned += 1;
    }
    start.store(true, .release);
    for (threads[0..spawned]) |thread| thread.join();
    spawned = 0;
    try std.testing.expectEqual(@as(usize, 7 + 4 * iterations), counter);
    try std.testing.expectEqualSlices(u32, &.{ 11 + 5 * iterations, 13 + 2 * iterations, 17 + 3 * iterations }, &buckets);
}
