//! Heap-stable persistent Jobs. The owner supplies framing and delivery; workers
//! only see immutable owned JobViews and their own requested-memory Slot.
const std = @import("std");
const core = @import("../../core.zig");
const count = core.stream_count;
const memory = @import("../../io/threaded_working_memory.zig");
const types = @import("types.zig");
const jobs_mod = @import("job.zig");
const workers_mod = @import("worker.zig");
const history_mod = @import("history.zig");
const configuration = @import("configuration.zig");
const observations = @import("observations.zig");

pub const SealReason = enum { more_input, flush, finish };

pub fn Queue(comptime Codec: type) type {
    return struct {
        const Self = @This();
        pub const Error = Codec.Error;
        pub const Job = jobs_mod.Job(Codec);
        pub const Config = types.Config(Codec);

        control: *memory.Control,
        config: Config,
        jobs: []Job,
        workers: []workers_mod.Worker,
        history: history_mod.Rolling = .{},
        mutex: std.Io.Mutex = .init,
        jobs_available: std.Io.Condition = .init,
        results_available: std.Io.Condition = .init,
        started: bool = false,
        stopped: bool = false,
        joined: bool = true,
        first_error: ?Error = null,
        filling: ?types.Count = null,
        submitted: types.Count = 0,
        claimed: types.Count = 0,
        delivered: types.Count = 0,
        active: usize = 0,
        inflight_jobs: usize = 0,
        inflight_bytes: usize = 0,
        final_submitted: bool = false,
        private_profile: types.Profile,
        aggregate_work: Codec.Profile = .{},

        /// Exact fixed requested heap, excluding Control/Owner and lazily
        /// allocated input, history, codec scratch and output buffers.
        pub fn metadataBytes(config: Config) Error!usize {
            try configuration.validate(Codec, config);
            const jobs = std.math.mul(usize, config.geometry.slot_count, @sizeOf(Job)) catch return error.IntegerOverflow;
            const workers = std.math.mul(usize, config.geometry.worker_count, @sizeOf(workers_mod.Worker)) catch return error.IntegerOverflow;
            const arrays = std.math.add(usize, jobs, workers) catch return error.IntegerOverflow;
            return std.math.add(usize, @sizeOf(Self), arrays) catch error.IntegerOverflow;
        }

        pub fn create(control: *memory.Control, config: Config) Error!*Self {
            try configuration.validate(Codec, config);
            control.coordinator.clearFailure();
            const allocator = control.allocator();
            const self = allocator.create(Self) catch |err| return control.coordinator.mapError(err);
            errdefer allocator.destroy(self);
            const jobs = allocator.alloc(Job, config.geometry.slot_count) catch |err| return control.coordinator.mapError(err);
            @memset(jobs, Job{});
            errdefer allocator.free(jobs);
            const workers = allocator.alloc(workers_mod.Worker, config.geometry.worker_count) catch |err| return control.coordinator.mapError(err);
            for (workers) |*worker| worker.* = .{ .slot = control.workerSlot() };
            self.* = .{ .control = control, .config = configuration.capture(Codec, config), .jobs = jobs, .workers = workers, .private_profile = initialProfile(config) };
            return self;
        }

        fn initialProfile(config: Config) types.Profile {
            return .{ .enabled = true, .serial_fallback = config.geometry.worker_count == 0, .configured_workers = config.parallel.worker_count, .effective_workers = if (config.geometry.worker_count == 0) 1 else config.geometry.worker_count, .effective_job_size = config.geometry.job_size };
        }

        fn lock(self: *Self) void {
            if (self.config.geometry.worker_count != 0) self.mutex.lockUncancelable(self.config.parallel.io);
        }
        fn unlock(self: *Self) void {
            if (self.config.geometry.worker_count != 0) self.mutex.unlock(self.config.parallel.io);
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
            self.private_profile.started = true;
            self.joined = self.config.geometry.worker_count == 0;
            self.unlock();
            if (comptime !types.target_supports_parallel) return;
            for (self.workers[0..self.config.geometry.worker_count]) |*worker| {
                self.control.coordinator.clearFailure();
                worker.thread = spawner.spawn(.{ .stack_size = types.worker_stack_bytes, .allocator = self.control.allocator() }, workerMain, .{ self, worker }) catch |err| {
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
            if (self.config.geometry.worker_count != 0) {
                self.jobs_available.broadcast(self.config.parallel.io);
                self.results_available.broadcast(self.config.parallel.io);
            }
        }
        fn at(self: *Self, ordinal: types.Count) *Job {
            return &self.jobs[count.ringIndex(ordinal, self.config.geometry.slot_count)];
        }
        fn workerMain(self: *Self, worker: *workers_mod.Worker) void {
            self.lock();
            self.private_profile.workers_live += 1;
            self.unlock();
            defer {
                self.lock();
                self.private_profile.workers_live -= 1;
                self.results_available.broadcast(self.config.parallel.io);
                self.unlock();
            }
            while (true) {
                self.lock();
                while (!self.stopped and self.claimed == self.submitted) self.jobs_available.waitUncancelable(self.config.parallel.io, &self.mutex);
                if (self.stopped) {
                    self.unlock();
                    return;
                }
                const job = self.at(self.claimed);
                self.claimed = count.addLocal(self.claimed, 1) catch unreachable;
                self.beginLocked(job);
                var output = job.output;
                job.output = .empty;
                self.unlock();
                const result = workers_mod.encode(Codec, &worker.slot, &output, job.view(self.config.history_window_len), self.config.frame_options, self.config.dictionary);
                self.lock();
                self.completeLocked(job, output, result);
                self.unlock();
            }
        }
        fn beginLocked(self: *Self, job: *Job) void {
            std.debug.assert(job.state == .queued);
            job.state = .active;
            self.active += 1;
            if (self.config.geometry.worker_count != 0) self.private_profile.peak_active_workers = @max(self.private_profile.peak_active_workers, self.active);
        }
        fn completeLocked(self: *Self, job: *Job, output: std.ArrayList(u8), result: workers_mod.Result(Codec)) void {
            self.active -= 1;
            job.output = output;
            job.block_count = result.block_count;
            job.work = result.work;
            job.first_error = result.first_error;
            job.state = .complete;
            if (result.first_error) |err| return self.failLocked(err);
            const next_jobs = count.addLocal(self.private_profile.encoded_jobs, 1) catch |err| {
                job.first_error = err;
                return self.failLocked(err);
            };
            const next_blocks = count.addLocal(self.private_profile.encoded_blocks, job.block_count) catch |err| {
                job.first_error = err;
                return self.failLocked(err);
            };
            self.private_profile.encoded_jobs = next_jobs;
            self.private_profile.encoded_blocks = next_blocks;
            if (self.config.geometry.worker_count != 0) self.results_available.broadcast(self.config.parallel.io);
        }

        pub fn admissionRoom(self: *Self) usize {
            self.lock();
            defer self.unlock();
            if (self.stopped or self.final_submitted) return 0;
            if (self.filling == null and (self.inflight_jobs == self.config.geometry.slot_count or self.private_profile.accepted_jobs >= self.config.max_job_count)) return 0;
            const plain_len = if (self.filling) |ordinal| self.at(ordinal).plain().len else 0;
            return @min(self.config.geometry.job_size - plain_len, self.config.parallel.max_inflight_bytes - self.inflight_bytes);
        }
        pub fn fillingLen(self: *Self) usize {
            self.lock();
            defer self.unlock();
            return if (self.filling) |ordinal| self.at(ordinal).plain().len else 0;
        }
        pub fn setAdmissionLimit(self: *Self, maximum: types.Count) void {
            self.lock();
            defer self.unlock();
            self.config.max_job_count = maximum;
        }
        pub fn accept(self: *Self, input: []const u8, max_take: usize) Error!usize {
            try self.start();
            self.lock();
            defer self.unlock();
            if (self.first_error) |err| return err;
            if (self.stopped or self.final_submitted) return error.InvalidStreamState;
            const fresh = self.filling == null;
            if (fresh and (self.inflight_jobs == self.config.geometry.slot_count or self.private_profile.accepted_jobs >= self.config.max_job_count)) return 0;
            const job = self.at(self.filling orelse self.submitted);
            const prefix_len = if (fresh) self.history.bytes.items.len else job.prefix_len;
            const plain_len = if (fresh) 0 else job.plain().len;
            const taken = @min(input.len, @min(max_take, @min(self.config.geometry.job_size - plain_len, self.config.parallel.max_inflight_bytes - self.inflight_bytes)));
            if (taken == 0) return 0;
            const next_input = try count.addLocal(self.private_profile.accepted_input_bytes, taken);
            const next_jobs = if (fresh) try count.addLocal(self.private_profile.accepted_jobs, 1) else self.private_profile.accepted_jobs;
            const needed = std.math.add(usize, prefix_len, plain_len + taken) catch return error.IntegerOverflow;
            self.control.coordinator.clearFailure();
            job.bytes.ensureTotalCapacityPrecise(self.control.allocator(), needed) catch |err| {
                const failure: Error = self.control.coordinator.mapError(err);
                self.failLocked(failure);
                return failure;
            };
            self.history.prepare(self.control.allocator(), taken, self.config.history_window_len) catch |err| {
                const failure: Error = self.control.coordinator.mapError(err);
                self.failLocked(failure);
                return failure;
            };
            if (fresh) {
                std.debug.assert(job.state == .free);
                job.clear();
                job.ordinal = self.submitted;
                job.prefix_len = prefix_len;
                job.frame_offset = self.private_profile.accepted_input_bytes;
                job.bytes.appendSliceAssumeCapacity(self.history.bytes.items);
                job.state = .filling;
                self.filling = self.submitted;
                self.inflight_jobs += 1;
            }
            job.bytes.appendSliceAssumeCapacity(input[0..taken]);
            self.history.appendPrepared(input[0..taken], self.config.history_window_len);
            self.inflight_bytes += taken;
            self.private_profile.accepted_input_bytes = next_input;
            self.private_profile.accepted_jobs = next_jobs;
            self.private_profile.peak_inflight_jobs = @max(self.private_profile.peak_inflight_jobs, self.inflight_jobs);
            self.private_profile.peak_inflight_bytes = @max(self.private_profile.peak_inflight_bytes, self.inflight_bytes);
            return taken;
        }

        pub fn seal(self: *Self, reason: SealReason) Error!bool {
            try self.start();
            self.lock();
            if (self.first_error) |err| {
                self.unlock();
                return err;
            }
            if (self.final_submitted or self.stopped) {
                self.unlock();
                return false;
            }
            if (self.filling == null) {
                if (reason != .finish or self.inflight_jobs == self.config.geometry.slot_count or self.private_profile.accepted_jobs >= self.config.max_job_count) {
                    self.unlock();
                    return false;
                }
                const next_jobs = count.addLocal(self.private_profile.accepted_jobs, 1) catch |err| {
                    self.unlock();
                    return err;
                };
                const job = self.at(self.submitted);
                self.control.coordinator.clearFailure();
                job.bytes.ensureTotalCapacityPrecise(self.control.allocator(), self.history.bytes.items.len) catch |err| {
                    const failure: Error = self.control.coordinator.mapError(err);
                    self.failLocked(failure);
                    self.unlock();
                    return failure;
                };
                job.clear();
                job.ordinal = self.submitted;
                job.frame_offset = self.private_profile.accepted_input_bytes;
                job.prefix_len = self.history.bytes.items.len;
                job.bytes.appendSliceAssumeCapacity(self.history.bytes.items);
                job.state = .filling;
                self.filling = self.submitted;
                self.inflight_jobs += 1;
                self.private_profile.accepted_jobs = next_jobs;
                self.private_profile.peak_inflight_jobs = @max(self.private_profile.peak_inflight_jobs, self.inflight_jobs);
            }
            const job = self.at(self.filling.?);
            if (reason == .more_input and job.plain().len != self.config.geometry.job_size) {
                self.unlock();
                return error.InvalidBlockPlan;
            }
            self.submitted = count.addLocal(self.submitted, 1) catch unreachable;
            job.final = reason == .finish;
            self.final_submitted = job.final;
            job.state = .queued;
            self.filling = null;
            if (self.config.geometry.worker_count != 0) self.jobs_available.signal(self.config.parallel.io);
            self.unlock();
            if (self.config.geometry.worker_count == 0) {
                self.claimed = count.addLocal(self.claimed, 1) catch unreachable;
                self.beginLocked(job);
                var output = job.output;
                job.output = .empty;
                const result = workers_mod.encode(Codec, &self.control.coordinator, &output, job.view(self.config.history_window_len), self.config.frame_options, self.config.dictionary);
                self.completeLocked(job, output, result);
            }
            return true;
        }

        pub fn peekOldest(self: *Self, wait: bool) Error!?*Job {
            self.lock();
            defer self.unlock();
            if (self.first_error) |err| return err;
            if (self.delivered == self.submitted) return null;
            const job = self.at(self.delivered);
            while (job.state != .complete and job.state != .delivering) {
                if (!wait or self.config.geometry.worker_count == 0) return null;
                if (self.stopped) return error.InvalidStreamState;
                self.results_available.waitUncancelable(self.config.parallel.io, &self.mutex);
                if (self.first_error) |err| return err;
            }
            return job;
        }
        pub fn markPublished(self: *Self, ordinal: types.Count, blocks: usize, wire_len: usize) Error!void {
            self.lock();
            defer self.unlock();
            if (ordinal != self.delivered or self.delivered == self.submitted) return error.InvalidStreamState;
            const job = self.at(ordinal);
            if (job.state != .complete or blocks == 0 or wire_len == 0) return error.InvalidStreamState;
            const next_jobs = try count.addLocal(self.private_profile.published_jobs, 1);
            const next_blocks = try count.addLocal(self.private_profile.published_blocks, blocks);
            job.publication_size = wire_len;
            job.published_block_count = blocks;
            job.output_offset = 0;
            job.state = .delivering;
            self.private_profile.published_jobs = next_jobs;
            self.private_profile.published_blocks = next_blocks;
        }
        pub fn releaseDelivered(self: *Self, ordinal: types.Count) Error!void {
            self.lock();
            defer self.unlock();
            if (ordinal != self.delivered or self.delivered == self.submitted) return error.InvalidStreamState;
            const job = self.at(ordinal);
            if (job.state != .delivering or job.output_offset != job.publication_size) return error.InvalidStreamState;
            const next_jobs = try count.addLocal(self.private_profile.delivered_jobs, 1);
            const next_blocks = try count.addLocal(self.private_profile.delivered_blocks, job.published_block_count);
            self.mergeLocked(job);
            self.inflight_jobs -= 1;
            self.inflight_bytes -= job.plain().len;
            self.delivered = next_jobs;
            self.private_profile.delivered_jobs = next_jobs;
            self.private_profile.delivered_blocks = next_blocks;
            job.clear();
        }
        fn mergeLocked(self: *Self, job: *Job) void {
            if (!job.merged) {
                self.aggregate_work.mergeWork(job.work);
                job.merged = true;
            }
        }
        pub fn collectCompletedWork(self: *Self) void {
            std.debug.assert(self.joined);
            var ordinal = self.delivered;
            while (ordinal != self.submitted) : (ordinal = count.addLocal(ordinal, 1) catch unreachable) {
                const job = self.at(ordinal);
                if (job.state == .complete or job.state == .delivering) self.mergeLocked(job);
            }
        }
        pub fn workSnapshot(self: *Self) Codec.Profile {
            self.lock();
            defer self.unlock();
            return observations.workSnapshot(self);
        }
        pub fn copyProfile(self: *Self) types.Profile {
            self.lock();
            defer self.unlock();
            return self.private_profile;
        }
        pub fn snapshot(self: *Self) types.Snapshot {
            self.lock();
            defer self.unlock();
            return observations.snapshot(self);
        }
        pub fn frontOutputBytes(self: *Self) usize {
            self.lock();
            defer self.unlock();
            return observations.frontOutputBytes(self);
        }

        pub fn stopJoin(self: *Self) void {
            self.lock();
            self.stopped = true;
            if (self.config.geometry.worker_count != 0) {
                self.jobs_available.broadcast(self.config.parallel.io);
                self.results_available.broadcast(self.config.parallel.io);
            }
            self.unlock();
            if (comptime types.target_supports_parallel) for (self.workers) |*worker| if (worker.thread) |thread| {
                thread.join();
                worker.thread = null;
            };
            self.joined = true;
        }
        pub fn checkConfig(_: *Self, config: Config) Error!void {
            try configuration.validate(Codec, config);
        }
        pub fn resetRetainingCapacity(self: *Self, config: Config) Error!void {
            try configuration.validate(Codec, config);
            self.control.coordinator.clearFailure();
            const allocator = self.control.allocator();
            var jobs: ?[]Job = null;
            errdefer if (jobs) |value| allocator.free(value);
            if (config.geometry.slot_count > self.jobs.len) {
                jobs = allocator.alloc(Job, config.geometry.slot_count) catch |err| return self.control.coordinator.mapError(err);
                @memset(jobs.?, Job{});
            }
            var workers: ?[]workers_mod.Worker = null;
            errdefer if (workers) |value| allocator.free(value);
            if (config.geometry.worker_count > self.workers.len) {
                workers = allocator.alloc(workers_mod.Worker, config.geometry.worker_count) catch |err| return self.control.coordinator.mapError(err);
                for (workers.?) |*worker| worker.* = .{ .slot = self.control.workerSlot() };
            }
            self.stopJoin();
            if (jobs) |value| {
                for (self.jobs, 0..) |job, index| value[index] = job;
                allocator.free(self.jobs);
                self.jobs = value;
            }
            if (workers) |value| {
                allocator.free(self.workers);
                self.workers = value;
            }
            for (self.jobs) |*job| job.clear();
            self.history.clear();
            self.config = configuration.capture(Codec, config);
            self.started = false;
            self.stopped = false;
            self.joined = true;
            self.first_error = null;
            self.filling = null;
            self.submitted = 0;
            self.claimed = 0;
            self.delivered = 0;
            self.active = 0;
            self.inflight_jobs = 0;
            self.inflight_bytes = 0;
            self.final_submitted = false;
            self.private_profile = initialProfile(config);
            self.aggregate_work = .{};
        }
        pub fn deinit(self: *Self) void {
            self.stopJoin();
            const allocator = self.control.allocator();
            for (self.jobs) |*job| job.deinit(allocator);
            self.history.deinit(allocator);
            allocator.free(self.jobs);
            allocator.free(self.workers);
            allocator.destroy(self);
        }
    };
}

test "Zstd parallel incremental queue owns input prefixes and holds credit through the last actual output byte" {
    const tests = @import("queue_contract_tests.zig");
    try tests.ownedCredit(Queue(tests.Codec));
}
test "Zstd parallel incremental queue partial credit requires explicit flush and an empty final Job" {
    const tests = @import("queue_contract_tests.zig");
    try tests.partialFlush(Queue(tests.Codec));
}
test "Zstd parallel incremental queue preserves wide frame positions and Job ordinals" {
    const tests = @import("queue_contract_tests.zig");
    try tests.widePosition(Queue(tests.Codec));
}
test "Zstd parallel incremental queue rejected reconfiguration preserves retained state" {
    const tests = @import("queue_contract_tests.zig");
    try tests.rejectedReset(Queue(tests.Codec));
}
test "Zstd parallel incremental queue partial spawn failure joins actual threads without a global hook" {
    const tests = @import("queue_contract_tests.zig");
    const TestQueue = Queue(tests.Codec);
    try tests.partialSpawn(TestQueue, TestQueue.startWithSpawner);
}
test "Zstd parallel incremental queue failing Io preserves configured workers while executing synchronously" {
    const tests = @import("queue_contract_tests.zig");
    try tests.ioFailingFallback(Queue(tests.Codec));
}
