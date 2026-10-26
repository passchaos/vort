//! A stable bounded ring of one-shot Jobs, served by one fixed thread set.
//! Input spans are borrowed; no descriptor list grows with the whole input.
const std = @import("std");
const memory = @import("../../io/threaded_working_memory.zig");
const types = @import("types.zig");
const jobs_mod = @import("job.zig");
const workers_mod = @import("worker.zig");

pub fn Queue(comptime Codec: type) type {
    return struct {
        const Self = @This();
        pub const Job = jobs_mod.Job(Codec);
        pub const Error = Codec.Error;

        control: *memory.Control,
        input: []const u8,
        options: Codec.Options,
        dictionary: ?Codec.Dictionary,
        parallel: types.Options,
        geometry: types.Geometry,
        jobs: []Job,
        workers: []workers_mod.Worker,
        mutex: std.Io.Mutex = .init,
        jobs_available: std.Io.Condition = .init,
        results_available: std.Io.Condition = .init,
        started: bool = false,
        stopped: bool = false,
        joined: bool = true,
        first_error: ?Error = null,
        submitted: usize = 0,
        claimed: usize = 0,
        published: usize = 0,
        active: usize = 0,
        inflight_jobs: usize = 0,
        inflight_bytes: usize = 0,
        private_profile: types.Profile,
        aggregate_work: Codec.Profile = .{},

        pub fn create(control: *memory.Control, input: []const u8, options: Codec.Options, parallel: types.Options, dictionary: ?Codec.Dictionary, geometry: types.Geometry) Error!*Self {
            control.coordinator.clearFailure();
            const allocator = control.allocator();
            const self = allocator.create(Self) catch |err| return control.coordinator.mapError(err);
            errdefer allocator.destroy(self);
            const jobs = allocator.alloc(Job, geometry.slot_count) catch |err| return control.coordinator.mapError(err);
            @memset(jobs, Job{});
            errdefer allocator.free(jobs);
            const workers = allocator.alloc(workers_mod.Worker, geometry.worker_count) catch |err| return control.coordinator.mapError(err);
            for (workers) |*worker| worker.* = .{ .slot = control.workerSlot() };
            var captured = options;
            if (comptime @hasField(Codec.Options, "control_profile")) captured.control_profile = null;
            if (comptime @hasField(Codec.Options, "memory_profile")) captured.memory_profile = null;
            if (comptime @hasField(Codec.Options, "parallel")) captured.parallel = null;
            var private_parallel = parallel;
            private_parallel.profile = null;
            self.* = .{
                .control = control,
                .input = input,
                .options = captured,
                .dictionary = dictionary,
                .parallel = private_parallel,
                .geometry = geometry,
                .jobs = jobs,
                .workers = workers,
                .private_profile = .{
                    .available = true,
                    .serial_fallback = geometry.worker_count == 0,
                    .configured_workers = parallel.worker_count,
                    .effective_workers = if (geometry.worker_count == 0) 1 else geometry.worker_count,
                    .effective_job_size = geometry.job_size,
                    .job_count = geometry.job_count,
                },
            };
            return self;
        }

        fn lock(self: *Self) void {
            if (self.workers.len != 0) self.mutex.lockUncancelable(self.parallel.io);
        }

        fn unlock(self: *Self) void {
            if (self.workers.len != 0) self.mutex.unlock(self.parallel.io);
        }

        pub fn start(self: *Self) Error!void {
            var spawner: workers_mod.NativeSpawner = .{};
            return self.startWithSpawner(&spawner);
        }

        fn startWithSpawner(self: *Self, spawner: anytype) Error!void {
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
            self.joined = self.workers.len == 0;
            self.unlock();
            if (comptime !types.target_supports_parallel) return;
            for (self.workers) |*worker| {
                self.control.coordinator.clearFailure();
                worker.thread = spawner.spawn(.{
                    .stack_size = types.worker_stack_bytes,
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

        fn failLocked(self: *Self, err: Error) void {
            if (self.first_error == null) self.first_error = err;
            self.stopped = true;
            if (self.workers.len != 0) {
                self.jobs_available.broadcast(self.parallel.io);
                self.results_available.broadcast(self.parallel.io);
            }
        }

        fn workerMain(self: *Self, worker: *workers_mod.Worker) void {
            self.lock();
            self.private_profile.workers_live += 1;
            self.unlock();
            defer {
                self.lock();
                self.private_profile.workers_live -= 1;
                self.results_available.broadcast(self.parallel.io);
                self.unlock();
            }
            while (true) {
                self.lock();
                while (!self.stopped and self.claimed == self.submitted)
                    self.jobs_available.waitUncancelable(self.parallel.io, &self.mutex);
                if (self.stopped) {
                    self.unlock();
                    return;
                }
                const job = &self.jobs[self.claimed % self.jobs.len];
                self.claimed += 1;
                self.beginJobLocked(job);
                var output = job.output;
                job.output = .empty;
                self.unlock();

                const result = workers_mod.encode(Codec, &worker.slot, &output, self.input, job.start, job.end, self.options, self.dictionary);

                self.lock();
                self.completeJobLocked(job, output, result);
                self.unlock();
            }
        }

        fn beginJobLocked(self: *Self, job: *Job) void {
            std.debug.assert(job.state == .queued);
            job.state = .active;
            self.active += 1;
            if (self.workers.len != 0)
                self.private_profile.peak_active_workers = @max(self.private_profile.peak_active_workers, self.active);
        }

        fn completeJobLocked(self: *Self, job: *Job, output: std.ArrayList(u8), result: workers_mod.Result(Codec)) void {
            self.active -= 1;
            job.output = output;
            job.block_count = result.block_count;
            job.work = result.work;
            job.first_error = result.first_error;
            job.state = .complete;
            self.updateOutputCapacityLocked();
            if (result.first_error) |err| {
                self.failLocked(err);
            } else {
                self.private_profile.encoded_jobs += 1;
                self.private_profile.encoded_blocks += job.block_count;
            }
            if (self.workers.len != 0) self.results_available.broadcast(self.parallel.io);
        }

        fn updateOutputCapacityLocked(self: *Self) void {
            var capacity: usize = 0;
            for (self.jobs) |job| capacity += job.output.capacity;
            self.private_profile.retained_job_output_capacity = capacity;
            self.private_profile.peak_job_output_capacity = @max(self.private_profile.peak_job_output_capacity, capacity);
        }

        /// Submit a bounded ordered input span. False means the coordinator
        /// must publish an older Job before it can reclaim the next credit.
        pub fn submit(self: *Self, span_start: usize, span_end: usize) Error!bool {
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
            if (span_start > span_end or span_end > self.input.len or self.submitted >= self.geometry.job_count) {
                self.unlock();
                return error.InvalidBlockPlan;
            }
            const expected_start = self.submitted * self.geometry.job_size;
            const expected_end = expected_start + @min(self.geometry.job_size, self.input.len - expected_start);
            if (span_start != expected_start or span_end != expected_end) {
                self.unlock();
                return error.InvalidBlockPlan;
            }
            const plain_len = span_end - span_start;
            if (self.inflight_jobs == self.jobs.len or plain_len > self.parallel.max_inflight_bytes - self.inflight_bytes) {
                self.unlock();
                return false;
            }
            const job = &self.jobs[self.submitted % self.jobs.len];
            std.debug.assert(job.state == .free);
            job.clear();
            job.start = span_start;
            job.end = span_end;
            job.state = .queued;
            self.submitted += 1;
            self.inflight_jobs += 1;
            self.inflight_bytes += plain_len;
            self.private_profile.peak_inflight_jobs = @max(self.private_profile.peak_inflight_jobs, self.inflight_jobs);
            self.private_profile.peak_inflight_bytes = @max(self.private_profile.peak_inflight_bytes, self.inflight_bytes);
            if (self.workers.len != 0) self.jobs_available.signal(self.parallel.io);
            self.unlock();
            if (self.workers.len == 0) {
                self.claimed += 1;
                self.beginJobLocked(job);
                var output = job.output;
                job.output = .empty;
                const result = workers_mod.encode(Codec, &self.control.coordinator, &output, self.input, span_start, span_end, self.options, self.dictionary);
                self.completeJobLocked(job, output, result);
                if (result.first_error) |err| return err;
            }
            return true;
        }

        pub fn peekOldest(self: *Self, wait: bool) Error!?*Job {
            self.lock();
            defer self.unlock();
            if (self.first_error) |err| return err;
            if (self.published == self.submitted) return null;
            const job = &self.jobs[self.published % self.jobs.len];
            while (job.state != .complete and job.state != .publishing) {
                if (!wait or self.workers.len == 0) return null;
                self.results_available.waitUncancelable(self.parallel.io, &self.mutex);
                if (self.first_error) |err| return err;
                if (self.stopped and job.state != .complete) return error.InvalidStreamState;
            }
            job.state = .publishing;
            return job;
        }

        /// Release input credit only after Codec.appendJob succeeded in order.
        pub fn releasePublished(self: *Self) Error!void {
            self.lock();
            defer self.unlock();
            if (self.published == self.submitted) return error.InvalidStreamState;
            const job = &self.jobs[self.published % self.jobs.len];
            if (job.state != .publishing) return error.InvalidStreamState;
            self.mergeJobLocked(job);
            self.inflight_jobs -= 1;
            self.inflight_bytes -= job.end - job.start;
            self.private_profile.published_jobs += 1;
            self.private_profile.published_blocks += job.block_count;
            self.published += 1;
            job.clear();
        }

        fn mergeJobLocked(self: *Self, job: *Job) void {
            if (!job.merged) {
                self.aggregate_work.mergeWork(job.work);
                job.merged = true;
            }
        }

        pub fn stopJoin(self: *Self) void {
            self.lock();
            self.stopped = true;
            if (self.workers.len != 0) {
                self.jobs_available.broadcast(self.parallel.io);
                self.results_available.broadcast(self.parallel.io);
            }
            self.unlock();
            if (comptime types.target_supports_parallel) {
                for (self.workers) |*worker| if (worker.thread) |thread| {
                    thread.join();
                    worker.thread = null;
                };
            }
            self.joined = true;
        }

        pub fn collectCompletedWork(self: *Self) void {
            std.debug.assert(self.joined);
            var ordinal = self.published;
            while (ordinal < self.submitted) : (ordinal += 1) {
                const job = &self.jobs[ordinal % self.jobs.len];
                if (job.state == .complete or job.state == .publishing) self.mergeJobLocked(job);
            }
        }

        pub fn workSnapshot(self: *Self) Codec.Profile {
            self.lock();
            defer self.unlock();
            return self.aggregate_work;
        }

        pub fn copyProfile(self: *Self) types.Profile {
            self.lock();
            defer self.unlock();
            return self.private_profile;
        }

        pub fn deinit(self: *Self) void {
            self.stopJoin();
            const allocator = self.control.allocator();
            for (self.jobs) |*job| job.output.deinit(allocator);
            allocator.free(self.jobs);
            allocator.free(self.workers);
            allocator.destroy(self);
        }
    };
}

test "Zstd parallel queue partial spawn failure joins every actual worker" {
    const contracts = @import("queue_contract_tests.zig");
    const TestQueue = Queue(contracts.Codec);
    try contracts.partialSpawn(TestQueue, TestQueue.startWithSpawner);
}

test "Zstd parallel queue synchronous fallback reports no OS worker activity" {
    const contracts = @import("queue_contract_tests.zig");
    try contracts.serialFallback(Queue(contracts.Codec));
}
