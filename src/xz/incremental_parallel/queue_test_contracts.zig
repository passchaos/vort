//! Real partial-spawn cleanup through a per-test spawner, with no global hook.
const std = @import("std");
const old_parallel = @import("../parallel/types.zig");
const settings = @import("../../lzma/encode_options.zig");
const memory = @import("memory.zig");
const types = @import("types.zig");
const Error = types.Error;

pub fn partialSpawn(comptime Queue: type, comptime startWithSpawner: anytype) !void {
    if (comptime !old_parallel.target_supports_parallel) return error.SkipZigTest;
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
    const control = try memory.Control.create(std.testing.allocator, 4 * 1024 * 1024, 0);
    defer control.destroy();
    const config: types.Config = .{
        .writer_options = .{ .block_size = 1024 },
        .payload_encoding = .stored,
        .parallel = .{ .io = std.testing.io, .worker_count = 3, .max_inflight_blocks = 4, .max_inflight_bytes = 4096 },
    };
    const queue = try Queue.create(control, config);
    var queue_live = true;
    defer if (queue_live) queue.deinit();
    var spawner: PartialSpawner = .{};
    try std.testing.expectError(error.ThreadQuotaExceeded, startWithSpawner(queue, &spawner));
    try std.testing.expectEqual(@as(usize, 3), spawner.calls);
    try std.testing.expectEqual(@as(usize, 2), spawner.entered.load(.acquire));
    try std.testing.expectEqual(@as(usize, 2), spawner.exited.load(.acquire));
    const failed = queue.snapshot();
    try std.testing.expect(failed.started and failed.failed);
    try std.testing.expectEqual(@as(?Error, error.ThreadQuotaExceeded), failed.last_error);
    try std.testing.expectEqual(@as(usize, 2), failed.workers_started);
    try std.testing.expectEqual(@as(usize, 0), failed.workers_live);
    try std.testing.expectEqual(@as(usize, 0), failed.inflight_blocks);
    try std.testing.expectEqual(@as(usize, 0), failed.inflight_bytes);
    try std.testing.expectEqual(@as(usize, 0), failed.accepted_blocks);
    try std.testing.expectEqual(@as(usize, 0), failed.encoded_blocks);
    try std.testing.expectEqual(@as(usize, 0), failed.delivered_blocks);
    try std.testing.expectError(error.ThreadQuotaExceeded, queue.start());
    try std.testing.expectError(error.ThreadQuotaExceeded, queue.accept("abc", 3));
    queue.collectCompletedWork();
    try std.testing.expectEqualDeep(settings.EncodeWorkProfile{}, queue.workSnapshot());

    // A joined poisoned queue can reset without losing its retained storage.
    // Use the real synchronous fallback to demonstrate recovery with failing Io.
    var synchronous = config;
    synchronous.parallel.worker_count = 1;
    synchronous.parallel.io = .failing;
    try queue.resetRetainingCapacity(synchronous);
    try std.testing.expectEqual(@as(usize, 3), try queue.accept("abc", 3));
    try std.testing.expect(try queue.submitPartial());
    const job = (try queue.peekOldest(false)).?;
    job.output_offset = job.output.items.len;
    try queue.releaseDelivered();
    const recovered = queue.snapshot();
    try std.testing.expect(!recovered.failed and recovered.serial_fallback);
    try std.testing.expectEqual(@as(usize, 0), recovered.inflight_bytes);
    try std.testing.expectEqual(@as(usize, 1), recovered.delivered_blocks);
    queue.deinit();
    queue_live = false;
    try std.testing.expectEqual(memory.control_bytes, control.snapshot().live_requested_bytes);
}
