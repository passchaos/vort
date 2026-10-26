//! Real partial thread creation failure, injected by one local spawner.
const std = @import("std");
const types = @import("types.zig");
const memory = @import("../../io/threaded_working_memory.zig");

pub const Codec = struct {
    pub const Error = types.Error;
    pub const Options = struct {};
    pub const Dictionary = struct {};
    pub const Profile = struct {
        bytes: usize = 0,
        pub fn mergeWork(self: *@This(), other: @This()) void {
            self.bytes += other.bytes;
        }
    };

    pub fn encodeJob(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: []const u8, start: usize, end: usize, _: Options, _: ?Dictionary, work: *Profile) Error!void {
        try output.appendSlice(allocator, input[start..end]);
        work.bytes += end - start;
    }

    pub fn blockCount(_: []const u8) Error!usize {
        return 1;
    }
};

pub fn partialSpawn(comptime Queue: type, comptime startWithSpawner: anytype) !void {
    if (comptime !types.target_supports_parallel) return error.SkipZigTest;
    const PartialSpawner = struct {
        calls: usize = 0,
        entered: std.atomic.Value(usize) = .init(0),
        exited: std.atomic.Value(usize) = .init(0),

        pub fn spawn(self: *@This(), config: std.Thread.SpawnConfig, comptime function: anytype, args: anytype) std.Thread.SpawnError!std.Thread {
            self.calls += 1;
            if (self.calls == 3) return error.ThreadQuotaExceeded;
            const Observed = struct {
                fn run(entered: *std.atomic.Value(usize), exited: *std.atomic.Value(usize), worker_args: @TypeOf(args)) void {
                    _ = entered.fetchAdd(1, .monotonic);
                    @call(.auto, function, worker_args);
                    _ = exited.fetchAdd(1, .release);
                }
            };
            return std.Thread.spawn(config, Observed.run, .{ &self.entered, &self.exited, args });
        }
    };
    const control = try memory.Control.create(std.testing.allocator, 1024 * 1024, 0);
    defer control.destroy();
    const input = [_]u8{0x5a} ** 4096;
    const parallel: types.Options = .{ .io = std.testing.io, .worker_count = 3, .job_size = 1024, .max_inflight_jobs = 4, .max_inflight_bytes = input.len };
    const geometry = try types.Geometry.init(input.len, 1024, parallel);
    const queue = try Queue.create(control, &input, .{}, parallel, null, geometry);
    var queue_live = true;
    defer if (queue_live) queue.deinit();
    var spawner: PartialSpawner = .{};
    try std.testing.expectError(error.ThreadQuotaExceeded, startWithSpawner(queue, &spawner));
    try std.testing.expectEqual(@as(usize, 3), spawner.calls);
    try std.testing.expectEqual(@as(usize, 2), spawner.entered.load(.acquire));
    try std.testing.expectEqual(@as(usize, 2), spawner.exited.load(.acquire));
    const failed = queue.copyProfile();
    try std.testing.expectEqual(@as(usize, 2), failed.workers_started);
    try std.testing.expectEqual(@as(usize, 0), failed.workers_live);
    try std.testing.expectEqual(@as(usize, 0), failed.peak_active_workers);
    try std.testing.expectEqual(@as(usize, 0), failed.peak_inflight_jobs);
    try std.testing.expectEqual(@as(usize, 0), failed.peak_inflight_bytes);
    try std.testing.expectEqual(@as(usize, 0), failed.encoded_jobs);
    try std.testing.expectEqual(@as(usize, 0), failed.published_jobs);
    try std.testing.expectError(error.ThreadQuotaExceeded, queue.start());
    try std.testing.expectError(error.ThreadQuotaExceeded, queue.submit(0, 1024));
    queue.collectCompletedWork();
    try std.testing.expectEqual(@as(usize, 0), queue.workSnapshot().bytes);
    queue.deinit();
    queue_live = false;
    try std.testing.expectEqual(memory.control_bytes, control.snapshot().live_requested_bytes);
}

pub fn serialFallback(comptime Queue: type) !void {
    const control = try memory.Control.create(std.testing.allocator, 1024 * 1024, 0);
    defer control.destroy();
    const input = "abcdefgh";
    const parallel: types.Options = .{ .io = .failing, .worker_count = 1, .job_size = 4, .max_inflight_jobs = 2, .max_inflight_bytes = input.len };
    const geometry = try types.Geometry.init(input.len, 4, parallel);
    const queue = try Queue.create(control, input, .{}, parallel, null, geometry);
    var queue_live = true;
    defer if (queue_live) queue.deinit();
    try std.testing.expect(try queue.submit(0, 4));
    try std.testing.expect(try queue.submit(4, input.len));
    for ([_][]const u8{ "abcd", "efgh" }) |expected| {
        const job = (try queue.peekOldest(false)).?;
        try std.testing.expectEqualSlices(u8, expected, job.output.items);
        try queue.releasePublished();
    }
    queue.stopJoin();
    queue.collectCompletedWork();
    const profile = queue.copyProfile();
    try std.testing.expect(profile.serial_fallback);
    try std.testing.expectEqual(@as(usize, 0), profile.workers_started);
    try std.testing.expectEqual(@as(usize, 0), profile.workers_live);
    try std.testing.expectEqual(@as(usize, 0), profile.peak_active_workers);
    try std.testing.expectEqual(@as(usize, 2), profile.encoded_jobs);
    try std.testing.expectEqual(@as(usize, 2), profile.published_jobs);
    try std.testing.expectEqual(@as(usize, 2), profile.encoded_blocks);
    try std.testing.expectEqual(@as(usize, 2), profile.published_blocks);
    try std.testing.expectEqual(input.len, queue.workSnapshot().bytes);
    queue.deinit();
    queue_live = false;
    try std.testing.expectEqual(memory.control_bytes, control.snapshot().live_requested_bytes);
}
