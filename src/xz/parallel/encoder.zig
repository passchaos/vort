//! A fixed worker pool encodes independent XZ Blocks into bounded ring slots.
//! Workers sleep on an Io condition between jobs. Only the coordinator appends
//! completed blocks and Index records, always in original input order.
const std = @import("std");
const writer = @import("../writer.zig");
const settings = @import("../../lzma/encode_options.zig");
const memory = @import("memory.zig");
const types = @import("types.zig");

pub const Error = writer.Error || std.mem.Allocator.Error || std.Thread.SpawnError || error{WorkingMemoryLimitExceeded};

const NativeSpawner = struct {
    fn spawn(_: *NativeSpawner, config: std.Thread.SpawnConfig, comptime function: anytype, args: anytype) std.Thread.SpawnError!std.Thread {
        return std.Thread.spawn(config, function, args);
    }
};

const Job = struct {
    state: enum { free, queued, active, complete } = .free,
    plain: []const u8 = &.{},
    output: std.ArrayList(u8) = .empty,
    record: writer.BlockRecord = undefined,
    work: settings.EncodeWorkProfile = .{},
    failure: ?Error = null,
    merged: bool = false,
};

const Worker = struct {
    slot: memory.Slot,
    thread: ?std.Thread = null,
};

const Pool = struct {
    io: std.Io,
    jobs: []Job,
    options: writer.EncodeOptions,
    payload_encoding: writer.PayloadEncoding,
    profile: ?*types.Profile,
    mutex: std.Io.Mutex = .init,
    jobs_available: std.Io.Condition = .init,
    result_available: std.Io.Condition = .init,
    stopped: bool = false,
    failure: ?Error = null,
    dispatched: usize = 0,
    claimed: usize = 0,
    published: usize = 0,
    active: usize = 0,
    inflight_blocks: usize = 0,
    inflight_bytes: usize = 0,

    fn stop(self: *Pool) void {
        self.mutex.lockUncancelable(self.io);
        self.stopped = true;
        self.jobs_available.broadcast(self.io);
        self.result_available.broadcast(self.io);
        self.mutex.unlock(self.io);
    }

    fn run(self: *Pool, worker: *Worker) void {
        while (true) {
            self.mutex.lockUncancelable(self.io);
            while (!self.stopped and self.claimed == self.dispatched)
                self.jobs_available.waitUncancelable(self.io, &self.mutex);
            if (self.stopped) {
                self.mutex.unlock(self.io);
                return;
            }
            const job = &self.jobs[self.claimed % self.jobs.len];
            std.debug.assert(job.state == .queued);
            self.claimed += 1;
            job.state = .active;
            self.active += 1;
            if (self.profile) |profile| profile.peak_active_workers = @max(profile.peak_active_workers, self.active);
            self.mutex.unlock(self.io);

            encodeJob(&worker.slot, job, self.options, self.payload_encoding);

            self.mutex.lockUncancelable(self.io);
            self.active -= 1;
            job.state = .complete;
            if (job.failure) |err| {
                if (self.failure == null) self.failure = err;
                self.stopped = true;
                self.jobs_available.broadcast(self.io);
            } else if (self.profile) |profile| {
                profile.completed_blocks += 1;
            }
            self.result_available.signal(self.io);
            self.mutex.unlock(self.io);
        }
    }

    fn dispatch(self: *Pool, input: []const u8, input_offset: *usize, limits: types.Options) void {
        while (!self.stopped and input_offset.* < input.len and self.inflight_blocks < self.jobs.len) {
            const plain_len = @min(self.options.block_size, input.len - input_offset.*);
            if (plain_len > limits.max_inflight_bytes - self.inflight_bytes) break;
            const job = &self.jobs[self.dispatched % self.jobs.len];
            std.debug.assert(job.state == .free);
            job.* = .{ .plain = input[input_offset.*..][0..plain_len], .state = .queued };
            input_offset.* += plain_len;
            self.dispatched += 1;
            self.inflight_blocks += 1;
            self.inflight_bytes += plain_len;
            if (self.profile) |profile| {
                profile.peak_inflight_blocks = @max(profile.peak_inflight_blocks, self.inflight_blocks);
                profile.peak_inflight_bytes = @max(profile.peak_inflight_bytes, self.inflight_bytes);
            }
            self.jobs_available.signal(self.io);
        }
    }

    /// Called only after joining. Include successful or failed work from jobs
    /// that ran beyond the last ordered publication before a pool failure.
    fn mergeRemaining(self: *Pool, destination: ?*settings.EncodeWorkProfile) void {
        var ordinal = self.published;
        while (ordinal < self.dispatched) : (ordinal += 1) {
            const job = &self.jobs[ordinal % self.jobs.len];
            if (job.state == .complete and !job.merged) {
                mergeWork(destination, job.work);
                job.merged = true;
            }
        }
    }
};

fn encodeJob(slot: *memory.Slot, job: *Job, options: writer.EncodeOptions, payload_encoding: writer.PayloadEncoding) void {
    slot.clearFailure();
    var local_options = options;
    if (local_options.match_options) |*matching| {
        if (matching.profile != null) matching.profile = &job.work;
    }
    job.record = writer.appendBlock(slot.allocator(), &job.output, job.plain, local_options, payload_encoding) catch |err| {
        job.failure = slot.mapError(err);
        return;
    };
}

fn mergeWork(destination: ?*settings.EncodeWorkProfile, work: settings.EncodeWorkProfile) void {
    const output = destination orelse return;
    inline for (@typeInfo(settings.EncodeWorkProfile).@"struct".fields) |field| {
        if (comptime std.mem.eql(u8, field.name, "finder") or
            std.mem.startsWith(u8, field.name, "effective_"))
        {
            @field(output, field.name) = @field(work, field.name);
        } else if (comptime std.mem.indexOf(u8, field.name, "peak_working_memory") != null) {
            @field(output, field.name) = @max(@field(output, field.name), @field(work, field.name));
        } else {
            @field(output, field.name) +|= @field(work, field.name);
        }
    }
}

fn publish(slot: *memory.Slot, encoded: *std.ArrayList(u8), records: *std.ArrayList(writer.BlockRecord), job: *Job) Error!void {
    slot.clearFailure();
    try encoded.ensureUnusedCapacity(slot.allocator(), job.output.items.len);
    try records.ensureUnusedCapacity(slot.allocator(), 1);
    encoded.appendSliceAssumeCapacity(job.output.items);
    records.appendAssumeCapacity(job.record);
}

fn appendSerial(slot: *memory.Slot, encoded: *std.ArrayList(u8), records: *std.ArrayList(writer.BlockRecord), input: []const u8, options: writer.EncodeOptions, payload_encoding: writer.PayloadEncoding, limits: types.Options) Error!void {
    var offset: usize = 0;
    const work_destination = if (options.match_options) |matching| matching.profile else null;
    while (offset < input.len) {
        const plain_len = @min(options.block_size, input.len - offset);
        var job: Job = .{ .plain = input[offset..][0..plain_len] };
        defer job.output.deinit(slot.allocator());
        if (limits.profile) |profile| {
            profile.peak_active_workers = 1;
            profile.peak_inflight_blocks = 1;
            profile.peak_inflight_bytes = @max(profile.peak_inflight_bytes, plain_len);
        }
        encodeJob(slot, &job, options, payload_encoding);
        mergeWork(work_destination, job.work);
        if (job.failure) |err| return err;
        if (limits.profile) |profile| profile.completed_blocks += 1;
        publish(slot, encoded, records, &job) catch |err| return slot.mapError(err);
        if (limits.profile) |profile| profile.published_blocks += 1;
        offset += plain_len;
    }
}

/// Encode only independent XZ Blocks. The writer retains Stream Header/Index/
/// Footer and final caller-output publication inside the same budget lifetime.
/// On failure internal output and Index logical lengths both return to their
/// initial values; every started worker is joined before releasing its slots.
pub fn appendBlocks(coordinator: *memory.Slot, encoded: *std.ArrayList(u8), records: *std.ArrayList(writer.BlockRecord), input: []const u8, options: writer.EncodeOptions, payload_encoding: writer.PayloadEncoding, limits: types.Options) Error!void {
    var spawner: NativeSpawner = .{};
    return appendBlocksWithSpawner(coordinator, encoded, records, input, options, payload_encoding, limits, &spawner);
}

fn appendBlocksWithSpawner(coordinator: *memory.Slot, encoded: *std.ArrayList(u8), records: *std.ArrayList(writer.BlockRecord), input: []const u8, options: writer.EncodeOptions, payload_encoding: writer.PayloadEncoding, limits: types.Options, spawner: anytype) Error!void {
    try options.validate();
    try limits.validateBlockLength(options.block_size, input.len);
    const original_encoded_len = encoded.items.len;
    const original_records_len = records.items.len;
    errdefer {
        encoded.items.len = original_encoded_len;
        records.items.len = original_records_len;
    }
    if (input.len == 0) {
        if (limits.profile) |profile| profile.serial_fallback = true;
        return;
    }
    if (comptime !types.target_supports_parallel) {
        if (limits.profile) |profile| profile.serial_fallback = true;
        return appendSerial(coordinator, encoded, records, input, options, payload_encoding, limits);
    }

    const block_count = 1 + (input.len - 1) / options.block_size;
    const byte_capacity_blocks = if (block_count == 1) 1 else limits.max_inflight_bytes / options.block_size;
    const job_count = @min(block_count, @min(limits.max_inflight_blocks, byte_capacity_blocks));
    const worker_count = @min(limits.worker_count, job_count);
    if (worker_count == 1) {
        if (limits.profile) |profile| profile.serial_fallback = true;
        return appendSerial(coordinator, encoded, records, input, options, payload_encoding, limits);
    }
    if (limits.profile) |profile| profile.serial_fallback = false;
    coordinator.clearFailure();
    const allocator = coordinator.allocator();
    const jobs = allocator.alloc(Job, job_count) catch |err| return coordinator.mapError(err);
    @memset(jobs, Job{});
    defer {
        for (jobs) |*job| job.output.deinit(allocator);
        allocator.free(jobs);
    }
    const workers = allocator.alloc(Worker, worker_count) catch |err| return coordinator.mapError(err);
    for (workers) |*worker| worker.* = .{ .slot = .{ .budget = coordinator.budget } };
    defer allocator.free(workers);
    var pool: Pool = .{ .io = limits.io, .jobs = jobs, .options = options, .payload_encoding = payload_encoding, .profile = limits.profile };
    const work_destination = if (options.match_options) |matching| matching.profile else null;
    defer {
        pool.stop();
        for (workers) |*worker| if (worker.thread) |thread| thread.join();
        pool.mergeRemaining(work_destination);
    }
    for (workers) |*worker| {
        coordinator.clearFailure();
        worker.thread = spawner.spawn(.{ .stack_size = types.worker_stack_bytes, .allocator = allocator }, Pool.run, .{ &pool, worker }) catch |err| return coordinator.mapError(err);
        if (limits.profile) |profile| profile.workers_started += 1;
    }

    var input_offset: usize = 0;
    while (pool.published < block_count) {
        pool.mutex.lockUncancelable(pool.io);
        pool.dispatch(input, &input_offset, limits);
        const job = &jobs[pool.published % jobs.len];
        while (!pool.stopped and job.state != .complete)
            pool.result_available.waitUncancelable(pool.io, &pool.mutex);
        const failure = pool.failure;
        pool.mutex.unlock(pool.io);
        if (failure) |err| return err;
        std.debug.assert(job.state == .complete and job.failure == null);

        publish(coordinator, encoded, records, job) catch |err| return coordinator.mapError(err);
        mergeWork(work_destination, job.work);
        job.merged = true;
        job.output.deinit(allocator);
        job.output = .empty;

        pool.mutex.lockUncancelable(pool.io);
        pool.inflight_blocks -= 1;
        pool.inflight_bytes -= job.plain.len;
        pool.published += 1;
        job.state = .free;
        if (limits.profile) |profile| profile.published_blocks += 1;
        pool.mutex.unlock(pool.io);
    }
}

test "XZ parallel partial worker spawn failure joins every started thread" {
    if (comptime !types.target_supports_parallel) return error.SkipZigTest;
    const PartialSpawner = struct {
        calls: usize = 0,
        started: std.atomic.Value(usize) = .init(0),
        exited: std.atomic.Value(usize) = .init(0),

        fn spawn(self: *@This(), config: std.Thread.SpawnConfig, comptime function: anytype, args: anytype) std.Thread.SpawnError!std.Thread {
            self.calls += 1;
            if (self.calls == 3) return error.ThreadQuotaExceeded;
            const Observed = struct {
                fn run(started: *std.atomic.Value(usize), exited: *std.atomic.Value(usize), worker_args: @TypeOf(args)) void {
                    _ = started.fetchAdd(1, .monotonic);
                    @call(.auto, function, worker_args);
                    _ = exited.fetchAdd(1, .release);
                }
            };
            return std.Thread.spawn(config, Observed.run, .{ &self.started, &self.exited, args });
        }
    };
    var budget = memory.Budget.init(std.testing.allocator, 4 * 1024 * 1024);
    var coordinator: memory.Slot = .{ .budget = &budget };
    var spawner: PartialSpawner = .{};
    var profile: types.Profile = .{};
    var encoded_storage = [_]u8{ 9, 8, 7 };
    var encoded: std.ArrayList(u8) = .{ .items = &encoded_storage, .capacity = encoded_storage.len };
    var record_storage = [_]writer.BlockRecord{.{ .unpadded_size = 12, .uncompressed_size = 6 }};
    var records: std.ArrayList(writer.BlockRecord) = .{ .items = &record_storage, .capacity = record_storage.len };
    const plain = [_]u8{0x5a} ** 4096;
    try std.testing.expectError(error.ThreadQuotaExceeded, appendBlocksWithSpawner(
        &coordinator,
        &encoded,
        &records,
        &plain,
        .{ .block_size = 1024 },
        .stored,
        .{ .io = std.testing.io, .worker_count = 3, .max_inflight_blocks = 4, .max_inflight_bytes = plain.len, .profile = &profile },
        &spawner,
    ));
    try std.testing.expectEqual(@as(usize, 3), spawner.calls);
    try std.testing.expectEqual(@as(usize, 2), spawner.started.load(.acquire));
    try std.testing.expectEqual(@as(usize, 2), spawner.exited.load(.acquire));
    try std.testing.expectEqual(@as(usize, 2), profile.workers_started);
    try std.testing.expectEqual(@as(usize, 0), profile.completed_blocks);
    try std.testing.expectEqual(@as(usize, 0), profile.published_blocks);
    try std.testing.expectEqual(@as(usize, 0), budget.liveRequestedBytes());
    try std.testing.expect(budget.peakRequestedBytes() != 0);
    try std.testing.expectEqualSlices(u8, &.{ 9, 8, 7 }, encoded.items);
    try std.testing.expectEqual(@as(usize, 1), records.items.len);
    try std.testing.expectEqual(writer.BlockRecord{ .unpadded_size = 12, .uncompressed_size = 6 }, records.items[0]);
}
