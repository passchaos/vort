//! Persistent bounded Block workers. The Queue and every allocator Slot are
//! heap-stable even when the public encoder value moves between calls.
const std = @import("std");
const old_parallel = @import("../parallel/types.zig");
const settings = @import("../../lzma/encode_options.zig");
const memory = @import("memory.zig");
const types = @import("types.zig");
const job_mod = @import("job.zig");
const worker_mod = @import("worker.zig");
const observations = @import("observations.zig");
const configuration = @import("configuration.zig");

pub const Error = types.Error;
pub const Job = job_mod.Job;
pub const Snapshot = types.Snapshot;

const NativeSpawner = worker_mod.NativeSpawner;
const Worker = worker_mod.Worker;

pub const Queue = struct {
    control: *memory.Control,
    config: types.Config,
    jobs: []Job,
    job_count: usize,
    workers: []Worker,
    worker_count: usize,
    synchronous_slot: memory.Slot,
    track_work: bool,
    mutex: std.Io.Mutex = .init,
    jobs_available: std.Io.Condition = .init,
    result_available: std.Io.Condition = .init,
    started: bool = false,
    stopped: bool = false,
    joined: bool = true,
    first_error: ?Error = null,
    filling: ?usize = null,
    submitted: usize = 0,
    claimed: usize = 0,
    delivered: usize = 0,
    accepted: usize = 0,
    encoded: usize = 0,
    inflight_blocks: usize = 0,
    inflight_bytes: usize = 0,
    active: usize = 0,
    workers_live: usize = 0,
    private_profile: old_parallel.Profile = .{},
    aggregate_work: settings.EncodeWorkProfile = .{},

    pub fn create(control: *memory.Control, config: types.Config) Error!*Queue {
        const geometry = try configuration.Geometry.fromConfig(config);
        control.coordinator.clearFailure();
        const allocator = control.allocator();
        const self = allocator.create(Queue) catch |err| return control.coordinator.mapError(err);
        errdefer allocator.destroy(self);
        const jobs = allocator.alloc(Job, geometry.jobs) catch |err| return control.coordinator.mapError(err);
        @memset(jobs, Job{});
        errdefer allocator.free(jobs);
        const workers = allocator.alloc(Worker, geometry.workers) catch |err| return control.coordinator.mapError(err);
        for (workers) |*worker| worker.* = .{ .slot = control.workerSlot() };
        self.* = .{
            .control = control,
            .config = configuration.capture(config),
            .jobs = jobs,
            .job_count = geometry.jobs,
            .workers = workers,
            .worker_count = geometry.workers,
            .synchronous_slot = control.workerSlot(),
            .track_work = configuration.tracksWork(config),
            .private_profile = .{ .serial_fallback = geometry.workers == 0 },
        };
        return self;
    }

    fn lock(self: *Queue) void {
        if (self.worker_count != 0) self.mutex.lockUncancelable(self.config.parallel.io);
    }

    fn unlock(self: *Queue) void {
        if (self.worker_count != 0) self.mutex.unlock(self.config.parallel.io);
    }

    /// Start once, after the owner has drained the complete Stream Header.
    /// The synchronous route does not call any Io primitive, allowing failing
    /// Io implementations on platforms or policies that cannot run workers.
    pub fn start(self: *Queue) Error!void {
        var spawner: NativeSpawner = .{};
        return self.startWithSpawner(&spawner);
    }

    fn startWithSpawner(self: *Queue, spawner: anytype) Error!void {
        self.lock();
        if (self.first_error) |err| {
            self.unlock();
            return err;
        }
        if (self.started) {
            self.unlock();
            return;
        }
        if (self.stopped) {
            self.unlock();
            return error.InvalidStreamState;
        }
        self.started = true;
        self.joined = self.worker_count == 0;
        self.unlock();
        if (comptime !old_parallel.target_supports_parallel) return;
        for (self.workers[0..self.worker_count]) |*worker| {
            self.control.coordinator.clearFailure();
            worker.thread = spawner.spawn(.{
                .stack_size = old_parallel.worker_stack_bytes,
                .allocator = self.control.allocator(),
            }, workerMain, .{ self, worker }) catch |err| {
                const failure: Error = self.control.coordinator.mapError(err);
                self.lock();
                self.failLocked(failure);
                self.unlock();
                self.stopJoin();
                return failure;
            };
            self.lock();
            self.private_profile.workers_started += 1;
            self.unlock();
        }
    }

    fn failLocked(self: *Queue, err: Error) void {
        if (self.first_error == null) self.first_error = err;
        self.stopped = true;
        if (self.worker_count != 0) {
            self.jobs_available.broadcast(self.config.parallel.io);
            self.result_available.broadcast(self.config.parallel.io);
        }
    }

    fn workerMain(self: *Queue, worker: *Worker) void {
        self.lock();
        self.workers_live += 1;
        self.unlock();
        defer {
            self.lock();
            self.workers_live -= 1;
            self.result_available.broadcast(self.config.parallel.io);
            self.unlock();
        }
        while (true) {
            self.lock();
            while (!self.stopped and self.claimed == self.submitted)
                self.jobs_available.waitUncancelable(self.config.parallel.io, &self.mutex);
            if (self.stopped) {
                self.unlock();
                return;
            }
            const job = &self.jobs[self.claimed % self.job_count];
            std.debug.assert(job.state == .queued);
            self.claimed += 1;
            self.beginJobLocked(job);
            var output = job.output;
            job.output = .empty;
            self.unlock();

            const result = worker_mod.encode(&worker.slot, job.plain.items, &output, self.config.writer_options, self.config.payload_encoding, self.track_work);

            self.lock();
            self.completeJobLocked(job, output, result);
            self.unlock();
        }
    }

    fn beginJobLocked(self: *Queue, job: *Job) void {
        job.state = .active;
        self.active += 1;
        self.private_profile.peak_active_workers = @max(self.private_profile.peak_active_workers, self.active);
    }

    fn completeJobLocked(self: *Queue, job: *Job, output: std.ArrayList(u8), result: worker_mod.Result) void {
        self.active -= 1;
        job.output = output;
        job.record = result.record;
        job.work = result.work;
        job.first_error = result.failure;
        job.state = .complete;
        if (result.failure) |err| {
            self.failLocked(err);
        } else {
            self.encoded += 1;
            self.private_profile.completed_blocks += 1;
        }
        if (self.worker_count != 0) self.result_available.broadcast(self.config.parallel.io);
    }

    /// At most one current filling Job is extended. Full blocks are submitted
    /// automatically; the caller loops to accept later Blocks in the same step.
    pub fn accept(self: *Queue, input: []const u8, max_take: usize) Error!usize {
        try self.start();
        self.lock();
        if (self.first_error) |err| {
            self.unlock();
            return err;
        }
        if (self.stopped) {
            self.unlock();
            return error.InvalidStreamState;
        }
        const room = self.admissionRoomLocked();
        const taken = @min(input.len, @min(max_take, room));
        if (taken == 0) {
            self.unlock();
            return 0;
        }
        const ordinal = self.filling orelse self.submitted;
        const job = &self.jobs[ordinal % self.job_count];
        self.control.coordinator.clearFailure();
        job.plain.ensureUnusedCapacity(self.control.allocator(), taken) catch |err| {
            const failure: Error = self.control.coordinator.mapError(err);
            self.failLocked(failure);
            self.unlock();
            return failure;
        };
        if (self.filling == null) {
            std.debug.assert(job.state == .free);
            job.clear();
            job.ordinal = ordinal;
            job.state = .filling;
            self.filling = ordinal;
            self.accepted += 1;
            self.inflight_blocks += 1;
        }
        job.plain.appendSliceAssumeCapacity(input[0..taken]);
        self.inflight_bytes += taken;
        self.private_profile.peak_inflight_blocks = @max(self.private_profile.peak_inflight_blocks, self.inflight_blocks);
        self.private_profile.peak_inflight_bytes = @max(self.private_profile.peak_inflight_bytes, self.inflight_bytes);
        const full = job.plain.items.len == self.config.writer_options.block_size;
        if (full) self.submitLocked(job);
        self.unlock();
        // Input ownership and credit are already committed. Preserve exact
        // accepted-byte progress; the owner observes the sticky codec error
        // before doing any subsequent admission or publication.
        if (full and self.worker_count == 0) self.runSynchronous(job) catch {};
        return taken;
    }

    fn admissionRoomLocked(self: *Queue) usize {
        if (self.stopped or self.first_error != null) return 0;
        if (self.filling == null and (self.inflight_blocks == self.job_count or self.accepted == self.config.max_block_count))
            return 0;
        const partial_len = if (self.filling) |ordinal| self.jobs[ordinal % self.job_count].plain.items.len else 0;
        return @min(self.config.writer_options.block_size - partial_len, self.config.parallel.max_inflight_bytes - self.inflight_bytes);
    }

    pub fn admissionRoom(self: *Queue) usize {
        self.lock();
        defer self.unlock();
        return self.admissionRoomLocked();
    }

    pub fn fillingLen(self: *Queue) usize {
        self.lock();
        defer self.unlock();
        return if (self.filling) |ordinal| self.jobs[ordinal % self.job_count].plain.items.len else 0;
    }

    /// Only the coordinator changes this resumable admission cap. Existing
    /// ring geometry and every captured codec/worker option remain unchanged.
    pub fn setAdmissionLimit(self: *Queue, max_block_count: usize) void {
        self.lock();
        defer self.unlock();
        self.config.max_block_count = max_block_count;
    }

    fn submitLocked(self: *Queue, job: *Job) void {
        std.debug.assert(job.state == .filling and job.plain.items.len != 0);
        job.state = .queued;
        self.submitted += 1;
        self.filling = null;
        if (self.worker_count != 0) self.jobs_available.signal(self.config.parallel.io);
    }

    pub fn submitPartial(self: *Queue) Error!bool {
        try self.start();
        self.lock();
        if (self.first_error) |err| {
            self.unlock();
            return err;
        }
        if (self.filling == null) {
            self.unlock();
            return false;
        }
        const job = &self.jobs[self.filling.? % self.job_count];
        self.submitLocked(job);
        self.unlock();
        if (self.worker_count == 0) try self.runSynchronous(job);
        return true;
    }

    fn runSynchronous(self: *Queue, job: *Job) Error!void {
        std.debug.assert(self.worker_count == 0 and job.state == .queued);
        self.claimed += 1;
        self.beginJobLocked(job);
        var output = job.output;
        job.output = .empty;
        const result = worker_mod.encode(&self.synchronous_slot, job.plain.items, &output, self.config.writer_options, self.config.payload_encoding, self.track_work);
        self.completeJobLocked(job, output, result);
        if (result.failure) |err| return err;
    }

    /// The returned Job has immutable encoded bytes and exclusive coordinator
    /// delivery fields. No active worker storage is returned to the owner.
    pub fn peekOldest(self: *Queue, wait: bool) Error!?*Job {
        self.lock();
        defer self.unlock();
        if (self.first_error) |err| return err;
        if (self.delivered == self.submitted) return null;
        const job = &self.jobs[self.delivered % self.job_count];
        while (job.state != .complete and job.state != .delivering) {
            if (!wait or self.worker_count == 0) return null;
            if (self.stopped) return error.InvalidStreamState;
            self.result_available.waitUncancelable(self.config.parallel.io, &self.mutex);
            if (self.first_error) |err| return err;
        }
        job.state = .delivering;
        return job;
    }

    pub fn releaseDelivered(self: *Queue) Error!void {
        self.lock();
        defer self.unlock();
        if (self.delivered == self.submitted) return error.InvalidStreamState;
        const job = &self.jobs[self.delivered % self.job_count];
        if (job.state != .delivering or job.output_offset != job.output.items.len)
            return error.InvalidStreamState;
        self.inflight_blocks -= 1;
        self.inflight_bytes -= job.plain.items.len;
        if (!job.merged) {
            job_mod.mergeWork(&self.aggregate_work, job.work);
            job.merged = true;
        }
        self.delivered += 1;
        self.private_profile.published_blocks += 1;
        job.clear();
    }

    /// After joining, include every executed Job in ordinal order, including
    /// failed work and successful jobs that were never delivered.
    pub fn collectCompletedWork(self: *Queue) void {
        std.debug.assert(self.joined);
        var ordinal = self.delivered;
        while (ordinal < self.submitted) : (ordinal += 1) {
            const job = &self.jobs[ordinal % self.job_count];
            if ((job.state == .complete or job.state == .delivering) and !job.merged) {
                job_mod.mergeWork(&self.aggregate_work, job.work);
                job.merged = true;
            }
        }
    }

    pub fn workSnapshot(self: *Queue) settings.EncodeWorkProfile {
        self.lock();
        defer self.unlock();
        return self.aggregate_work;
    }

    pub fn copyProfile(self: *Queue) old_parallel.Profile {
        self.lock();
        defer self.unlock();
        return self.private_profile;
    }

    pub fn snapshot(self: *Queue) Snapshot {
        self.lock();
        defer self.unlock();
        return observations.snapshot(self);
    }

    pub fn pendingOutputBytes(self: *Queue) usize {
        const observed = self.snapshot();
        return observed.completed_output_bytes + observed.delivering_output_bytes;
    }

    /// Observe only the ordered front without acquiring delivery ownership.
    pub fn frontOutputBytes(self: *Queue) usize {
        self.lock();
        defer self.unlock();
        return observations.frontOutputBytes(self);
    }

    /// Stop dispatch, wake sleepers and join all actual threads. Active codec
    /// work completes and becomes observable before the Queue can be reset.
    pub fn stopJoin(self: *Queue) void {
        self.lock();
        self.stopped = true;
        if (self.worker_count != 0) {
            self.jobs_available.broadcast(self.config.parallel.io);
            self.result_available.broadcast(self.config.parallel.io);
        }
        self.unlock();
        if (comptime old_parallel.target_supports_parallel) {
            for (self.workers) |*worker| if (worker.thread) |thread| {
                thread.join();
                worker.thread = null;
            };
        }
        self.joined = true;
    }

    pub fn checkConfig(_: *Queue, config: types.Config) Error!void {
        _ = try configuration.Geometry.fromConfig(config);
    }

    /// Reserve replacement metadata before changing the previous stream. A
    /// rejected configuration or allocation leaves its Jobs and poison intact.
    /// Same-geometry reset only clears logical state and retains all buffers.
    pub fn resetRetainingCapacity(self: *Queue, config: types.Config) Error!void {
        const geometry = try configuration.Geometry.fromConfig(config);
        self.control.coordinator.clearFailure();
        const allocator = self.control.allocator();
        var new_jobs: ?[]Job = null;
        errdefer if (new_jobs) |jobs| allocator.free(jobs);
        if (geometry.jobs > self.jobs.len) {
            const jobs = allocator.alloc(Job, geometry.jobs) catch |err| return self.control.coordinator.mapError(err);
            @memset(jobs, Job{});
            new_jobs = jobs;
        }
        var new_workers: ?[]Worker = null;
        errdefer if (new_workers) |workers| allocator.free(workers);
        if (geometry.workers > self.workers.len) {
            const workers = allocator.alloc(Worker, geometry.workers) catch |err| return self.control.coordinator.mapError(err);
            for (workers) |*worker| worker.* = .{ .slot = self.control.workerSlot() };
            new_workers = workers;
        }
        self.stopJoin();
        if (new_jobs) |jobs| {
            for (self.jobs, 0..) |*job, index| jobs[index] = job.*;
            allocator.free(self.jobs);
            self.jobs = jobs;
        }
        if (new_workers) |workers| {
            allocator.free(self.workers);
            self.workers = workers;
        }
        for (self.jobs) |*job| job.clear();
        self.config = configuration.capture(config);
        self.job_count = geometry.jobs;
        self.worker_count = geometry.workers;
        self.track_work = configuration.tracksWork(config);
        self.started = false;
        self.stopped = false;
        self.joined = true;
        self.first_error = null;
        self.filling = null;
        self.submitted = 0;
        self.claimed = 0;
        self.delivered = 0;
        self.accepted = 0;
        self.encoded = 0;
        self.inflight_blocks = 0;
        self.inflight_bytes = 0;
        self.active = 0;
        self.workers_live = 0;
        self.private_profile = .{ .serial_fallback = geometry.workers == 0 };
        self.aggregate_work = .{};
    }

    pub fn takeReusablePlain(self: *Queue) std.ArrayList(u8) {
        std.debug.assert(self.joined);
        var largest: usize = 0;
        for (self.jobs, 0..) |job, index| if (job.plain.capacity > self.jobs[largest].plain.capacity) {
            largest = index;
        };
        const plain = self.jobs[largest].plain;
        self.jobs[largest].plain = .empty;
        var result = plain;
        result.clearRetainingCapacity();
        return result;
    }

    /// Commit a caller-owned retained buffer only after Queue creation and
    /// ledger adoption succeeded. Its requested bytes are already accounted.
    pub fn adoptReusablePlain(self: *Queue, plain: *std.ArrayList(u8)) void {
        std.debug.assert(self.joined and !self.started and self.accepted == 0);
        std.debug.assert(self.jobs[0].plain.capacity == 0);
        self.jobs[0].plain = plain.*;
        self.jobs[0].plain.clearRetainingCapacity();
        plain.* = .empty;
    }

    pub fn deinit(self: *Queue) void {
        self.stopJoin();
        const allocator = self.control.allocator();
        for (self.jobs) |*job| job.deinit(allocator);
        allocator.free(self.jobs);
        allocator.free(self.workers);
        allocator.destroy(self);
    }
};

test "XZ parallel incremental queue partial spawn failure stops and joins all started workers" {
    try @import("queue_test_contracts.zig").partialSpawn(Queue, Queue.startWithSpawner);
}
