//! Independent ownership, credit, wide-position and cleanup contracts.
const std = @import("std");
const core = @import("../../core.zig");
const count = core.stream_count;
const memory = @import("../../io/threaded_working_memory.zig");
const types = @import("types.zig");
const views = @import("../parallel/job_view.zig");

pub const Codec = struct {
    pub const Error = types.Error;
    pub const Options = struct {};
    pub const Dictionary = struct {};
    pub const Profile = struct {
        bytes: types.Count = 0,
        last_position: types.Count = 0,
        pub fn mergeWork(self: *@This(), other: @This()) void {
            self.bytes +|= other.bytes;
            self.last_position = @max(self.last_position, other.last_position);
        }
    };
    pub fn encodeOwnedJob(allocator: std.mem.Allocator, output: *std.ArrayList(u8), view: views.View, _: Options, _: ?Dictionary, work: *Profile) Error!void {
        try view.validatePrefix(view.window_limit.?);
        const plain = view.plain();
        var header: [3]u8 = undefined;
        std.mem.writeInt(u24, &header, @as(u24, @intCast(plain.len)) << 3 | @intFromBool(view.final), .little);
        try output.appendSlice(allocator, &header);
        try output.appendSlice(allocator, plain);
        work.bytes = try count.addLocal(work.bytes, plain.len);
        work.last_position = try view.globalPosition(plain.len);
    }
    pub fn blockCount(bytes: []const u8) Error!usize {
        if (bytes.len < 3) return error.TruncatedFrame;
        const size: usize = @intCast(std.mem.readInt(u24, bytes[0..3], .little) >> 3);
        if (size != bytes.len - 3) return error.CorruptFrame;
        return 1;
    }
};

fn config(job_size: usize, credit: usize) types.Config(Codec) {
    const parallel: types.ParallelOptions = .{ .io = .failing, .worker_count = 1, .job_size = job_size, .max_inflight_jobs = 4, .max_inflight_bytes = credit };
    return .{ .frame_options = .{}, .parallel = parallel, .geometry = types.Geometry.init(4, parallel, std.math.maxInt(types.Count)) catch unreachable, .history_window_len = 8 };
}

pub fn ownedCredit(comptime Queue: type) !void {
    const control = try memory.Control.create(std.testing.allocator, 1024 * 1024, 0);
    defer control.destroy();
    const queue = try Queue.create(control, config(4, 8));
    defer queue.deinit();
    var first = [_]u8{ 'a', 'b', 'c', 'd' };
    try std.testing.expectEqual(@as(usize, 4), try queue.accept(&first, 4));
    @memset(&first, 'z');
    try std.testing.expectEqual(@as(usize, 4), queue.fillingLen());
    try std.testing.expectEqual(@as(types.Count, 0), queue.snapshot().profile.encoded_jobs);
    try std.testing.expect(try queue.seal(.more_input));
    const front = (try queue.peekOldest(false)).?;
    try std.testing.expectEqualSlices(u8, "abcd", front.plain());
    var second = [_]u8{ 'e', 'f', 'g', 'h' };
    try std.testing.expectEqual(@as(usize, 4), try queue.accept(&second, 4));
    @memset(&second, 'z');
    try std.testing.expect(try queue.seal(.finish));
    try std.testing.expectEqual(@as(types.Count, 8), queue.workSnapshot().bytes);
    try std.testing.expectEqual(@as(types.Count, 8), queue.workSnapshot().bytes);
    try queue.markPublished(front.ordinal, 1, 9);
    front.output_offset = 8;
    try std.testing.expectError(error.InvalidStreamState, queue.releaseDelivered(front.ordinal));
    try std.testing.expectEqual(@as(usize, 8), queue.snapshot().inflight_bytes);
    try std.testing.expectEqual(@as(usize, 1), queue.frontOutputBytes());
    front.output_offset = 9;
    try queue.releaseDelivered(front.ordinal);
    try std.testing.expectEqual(@as(types.Count, 8), queue.workSnapshot().bytes);
    const tail = (try queue.peekOldest(false)).?;
    try std.testing.expectEqualSlices(u8, "abcd", tail.view(8).prefix());
    try std.testing.expectEqualSlices(u8, "efgh", tail.plain());
    try std.testing.expectEqual(@as(types.Count, 4), tail.frame_offset);
    try std.testing.expect(tail.final);
    try std.testing.expectEqual(@as(usize, 4), queue.snapshot().inflight_bytes);
    try queue.markPublished(tail.ordinal, 1, tail.output.items.len);
    tail.output_offset = tail.publication_size;
    try queue.releaseDelivered(tail.ordinal);
    try std.testing.expectEqual(@as(usize, 0), queue.snapshot().inflight_bytes);
    try std.testing.expectEqual(@as(types.Count, 8), queue.workSnapshot().bytes);
}

pub fn ioFailingFallback(comptime Queue: type) !void {
    const control = try memory.Control.create(std.testing.allocator, 1024 * 1024, 0);
    defer control.destroy();
    var configured = config(4, 8);
    configured.parallel.worker_count = 3;
    configured.geometry = try types.Geometry.init(4, configured.parallel, configured.max_job_count);
    try std.testing.expectEqual(@as(usize, 3), configured.parallel.worker_count);
    try std.testing.expectEqual(@as(usize, 2), configured.geometry.slot_count);
    try std.testing.expectEqual(@as(usize, 0), configured.geometry.worker_count);
    const queue = try Queue.create(control, configured);
    defer queue.deinit();
    try std.testing.expectEqual(@as(usize, 4), try queue.accept("abcd", 4));
    try std.testing.expect(try queue.seal(.more_input));
    try std.testing.expectEqual(@as(usize, 4), try queue.accept("efgh", 4));
    try std.testing.expect(try queue.seal(.finish));
    const observed = queue.snapshot();
    try std.testing.expect(observed.profile.serial_fallback);
    try std.testing.expectEqual(@as(usize, 3), observed.profile.configured_workers);
    try std.testing.expectEqual(@as(usize, 0), observed.profile.workers_started);
    try std.testing.expectEqual(@as(usize, 0), observed.profile.workers_live);
    try std.testing.expectEqual(@as(usize, 0), observed.profile.peak_active_workers);
    try std.testing.expectEqual(@as(types.Count, 2), observed.profile.encoded_jobs);
    try std.testing.expectEqual(@as(usize, 8), observed.logical_history_bytes);
    try std.testing.expectEqual(@as(types.Count, 8), observed.logical_history_end);
    try std.testing.expectEqual(@as(usize, 8), observed.history_window_len);
    try std.testing.expectEqual(@as(types.Count, 8), queue.workSnapshot().bytes);
}

pub fn partialFlush(comptime Queue: type) !void {
    const control = try memory.Control.create(std.testing.allocator, 1024 * 1024, 0);
    defer control.destroy();
    const queue = try Queue.create(control, config(8, 3));
    defer queue.deinit();
    try std.testing.expectEqual(@as(usize, 3), try queue.accept("abcd", 4));
    try std.testing.expectEqual(@as(usize, 0), try queue.accept("d", 1));
    try std.testing.expect(!queue.snapshot().failed);
    try std.testing.expectEqual(@as(usize, 3), queue.fillingLen());
    try std.testing.expectError(error.InvalidBlockPlan, queue.seal(.more_input));
    try std.testing.expect(!queue.snapshot().failed);
    try std.testing.expect(try queue.seal(.flush));
    const front = (try queue.peekOldest(false)).?;
    try std.testing.expect(!front.final);
    try std.testing.expectEqualSlices(u8, "abc", front.plain());
    try std.testing.expect(!try queue.seal(.finish));
    try queue.markPublished(front.ordinal, 1, front.output.items.len);
    front.output_offset = front.publication_size;
    try queue.releaseDelivered(front.ordinal);
    try std.testing.expect(try queue.seal(.finish));
    try std.testing.expect(!try queue.seal(.finish));
    const empty = (try queue.peekOldest(false)).?;
    try std.testing.expect(empty.final and empty.plain().len == 0);
    try std.testing.expectEqualSlices(u8, "abc", empty.view(8).prefix());
    try queue.markPublished(empty.ordinal, 1, empty.output.items.len);
    empty.output_offset = empty.publication_size;
    try queue.releaseDelivered(empty.ordinal);
    const observed = queue.snapshot();
    try std.testing.expectEqual(@as(types.Count, 2), observed.profile.accepted_jobs);
    try std.testing.expectEqual(@as(types.Count, 3), observed.profile.accepted_input_bytes);
    try std.testing.expectEqual(@as(types.Count, 2), observed.profile.delivered_jobs);
    try std.testing.expectEqual(@as(usize, 0), observed.profile.workers_started);
    try std.testing.expectEqual(@as(usize, 0), observed.profile.peak_active_workers);
}

pub fn widePosition(comptime Queue: type) !void {
    const control = try memory.Control.create(std.testing.allocator, 1024 * 1024, 0);
    defer control.destroy();
    const queue = try Queue.create(control, config(4, 8));
    defer queue.deinit();
    const boundary: types.Count = @as(types.Count, 1) << 32;
    try queue.history.bytes.appendSlice(control.allocator(), "01234567");
    queue.history.end = boundary;
    queue.private_profile.accepted_input_bytes = boundary;
    queue.private_profile.accepted_jobs = boundary;
    queue.private_profile.encoded_jobs = boundary;
    queue.private_profile.published_jobs = boundary;
    queue.private_profile.delivered_jobs = boundary;
    queue.submitted = boundary;
    queue.claimed = boundary;
    queue.delivered = boundary;
    try std.testing.expectEqual(@as(usize, 2), try queue.accept("ab", 2));
    try std.testing.expect(try queue.seal(.finish));
    const job = (try queue.peekOldest(false)).?;
    try std.testing.expectEqual(boundary, job.ordinal);
    try std.testing.expectEqual(boundary, job.frame_offset);
    try std.testing.expectEqualSlices(u8, "01234567", job.view(8).prefix());
    try std.testing.expectEqual(boundary + 2, try job.view(8).globalPosition(2));
    try queue.markPublished(job.ordinal, 1, job.output.items.len);
    job.output_offset = job.publication_size;
    try queue.releaseDelivered(job.ordinal);
    try std.testing.expectEqual(boundary + 1, queue.snapshot().profile.delivered_jobs);
    try std.testing.expectEqual(boundary + 2, queue.workSnapshot().last_position);
}

pub fn rejectedReset(comptime Queue: type) !void {
    const control = try memory.Control.create(std.testing.allocator, 1024 * 1024, 0);
    defer control.destroy();
    const original = config(4, 8);
    const queue = try Queue.create(control, original);
    defer queue.deinit();
    try std.testing.expectEqual(@as(usize, 3), try queue.accept("abc", 3));
    try std.testing.expect(try queue.seal(.finish));
    const job = (try queue.peekOldest(false)).?;
    try queue.markPublished(job.ordinal, 1, job.output.items.len);
    job.output_offset = job.publication_size;
    try queue.releaseDelivered(job.ordinal);
    try control.changeLimit(control.snapshot().live_requested_bytes);
    const before = queue.snapshot();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, queue.resetRetainingCapacity(config(4, 16)));
    try std.testing.expectEqualDeep(before, queue.snapshot());
    try queue.resetRetainingCapacity(original);
    try std.testing.expectEqual(@as(types.Count, 0), queue.snapshot().profile.accepted_jobs);
    try std.testing.expectEqual(@as(usize, 0), queue.fillingLen());
    try std.testing.expectEqual(before.retained_input_capacity, queue.snapshot().retained_input_capacity);
}

pub fn partialSpawn(comptime Queue: type, comptime startWithSpawner: anytype) !void {
    if (comptime !types.target_supports_parallel) return error.SkipZigTest;
    const PartialSpawner = struct {
        calls: usize = 0,
        entered: std.atomic.Value(usize) = .init(0),
        exited: std.atomic.Value(usize) = .init(0),
        pub fn spawn(self: *@This(), spawn_config: std.Thread.SpawnConfig, comptime function: anytype, args: anytype) std.Thread.SpawnError!std.Thread {
            self.calls += 1;
            if (self.calls == 3) return error.ThreadQuotaExceeded;
            const Observed = struct {
                fn run(entered: *std.atomic.Value(usize), exited: *std.atomic.Value(usize), worker_args: @TypeOf(args)) void {
                    _ = entered.fetchAdd(1, .monotonic);
                    @call(.auto, function, worker_args);
                    _ = exited.fetchAdd(1, .release);
                }
            };
            return std.Thread.spawn(spawn_config, Observed.run, .{ &self.entered, &self.exited, args });
        }
    };
    const control = try memory.Control.create(std.testing.allocator, 1024 * 1024, 0);
    defer control.destroy();
    var configured = config(4, 16);
    configured.parallel.io = std.testing.io;
    configured.parallel.worker_count = 3;
    configured.geometry = try types.Geometry.init(4, configured.parallel, configured.max_job_count);
    const queue = try Queue.create(control, configured);
    var queue_live = true;
    defer if (queue_live) queue.deinit();
    var spawner: PartialSpawner = .{};
    try std.testing.expectError(error.ThreadQuotaExceeded, startWithSpawner(queue, &spawner));
    try std.testing.expectEqual(@as(usize, 2), spawner.entered.load(.acquire));
    try std.testing.expectEqual(@as(usize, 2), spawner.exited.load(.acquire));
    const failed = queue.snapshot();
    try std.testing.expect(failed.failed);
    try std.testing.expectEqual(@as(?anyerror, error.ThreadQuotaExceeded), failed.last_error);
    try std.testing.expectEqual(@as(usize, 2), failed.profile.workers_started);
    try std.testing.expectEqual(@as(usize, 0), failed.profile.workers_live);
    try std.testing.expectEqual(@as(types.Count, 0), failed.profile.accepted_input_bytes);
    try std.testing.expectError(error.ThreadQuotaExceeded, queue.accept("abc", 3));
    queue.collectCompletedWork();
    try std.testing.expectEqual(@as(types.Count, 0), queue.workSnapshot().bytes);
    try queue.resetRetainingCapacity(config(4, 8));
    try std.testing.expectEqual(@as(usize, 3), try queue.accept("abc", 3));
    queue.deinit();
    queue_live = false;
    try std.testing.expectEqual(memory.control_bytes, control.snapshot().live_requested_bytes);
}
