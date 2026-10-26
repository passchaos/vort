//! Heap-stable coordinator; workers only own immutable Queue JobViews.
const std = @import("std");
const core = @import("../../core.zig");
const count = core.stream_count;
const memory = @import("../../io/threaded_working_memory.zig");
const types = @import("types.zig");
const settings = @import("options.zig");
const profiles = @import("profiles.zig");
const stream = @import("stream.zig");
const queue_mod = @import("queue.zig");

pub fn Owner(comptime Codec: type) type {
    return struct {
        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = types.EncoderOptions(Codec.Options);
        pub const Limits = settings.Limits(Codec);
        pub const Queue = queue_mod.Queue(Codec);
        pub const Snapshot = struct {
            input_read: types.Count,
            output_written: types.Count,
            frame_input: types.Count,
            frame_output: types.Count,
            buffered_input: usize,
            pending_output: usize,
            frame_count: types.Count,
            frame_index: types.Count,
            finishing: bool,
            done: bool,
            parallel: types.Snapshot,
        };

        control: *memory.Control,
        queue: *Queue,
        options: Options,
        config: types.Config(Codec),
        state: stream.State = .{},
        hash: Codec.Hash = Codec.Hash.init(0),
        actual_state: Codec.State,
        front_job: ?*Queue.Job = null,
        front_emitted: Codec.Profile.Emitted = .{},
        delivered_emitted: Codec.Profile.Emitted = .{},
        work_baseline: Codec.Profile = .{},
        adapter_work: Codec.Profile = .{},
        failure: ?Error = null,
        last_call_error: ?Error = null,
        last_step_progress: core.Progress = .{},

        pub fn validate(options: Options, expected: ?types.Count, dictionary: ?Codec.Dictionary, metadata_id: ?u32) Error!void {
            const prepared = try settings.prepare(Codec, options, expected, dictionary, metadata_id);
            const control_and_owner = std.math.add(usize, memory.control_bytes, @sizeOf(Self)) catch return error.IntegerOverflow;
            const initial = std.math.add(usize, control_and_owner, try Queue.metadataBytes(prepared.config)) catch return error.IntegerOverflow;
            if (initial > settings.heapLimit(Codec, prepared.options)) return error.WorkingMemoryLimitExceeded;
        }

        pub fn create(backing: std.mem.Allocator, options: Options, expected: ?types.Count, dictionary: ?Codec.Dictionary, metadata_id: ?u32) Error!*Self {
            try validate(options, expected, dictionary, metadata_id);
            const prepared = try settings.prepare(Codec, options, expected, dictionary, metadata_id);
            const control = try memory.Control.create(backing, settings.heapLimit(Codec, prepared.options), 0);
            errdefer control.destroy();
            control.coordinator.clearFailure();
            const allocator = control.allocator();
            const self = allocator.create(Self) catch |err| return control.coordinator.mapError(err);
            errdefer allocator.destroy(self);
            self.* = .{ .control = control, .queue = undefined, .options = prepared.options, .config = prepared.config, .actual_state = undefined, .state = .{ .expected_input_len = expected } };
            self.actual_state = try Codec.initialState(dictionary);
            errdefer Codec.deinitState(allocator, &self.actual_state);
            self.queue = try Queue.create(control, prepared.config);
            profiles.capture(Codec, self);
            profiles.publish(Codec, self);
            return self;
        }

        pub fn snapshot(self: *const Self) Snapshot {
            const observed = profiles.snapshot(self);
            profiles.publishObserved(Codec, self, observed);
            return .{
                .input_read = self.state.total_input,
                .output_written = self.state.total_output,
                .frame_input = self.state.frame_input,
                .frame_output = self.state.frame_output,
                .buffered_input = observed.owned_input_bytes,
                .pending_output = self.state.pendingLen() + observed.completed_output_bytes,
                .frame_count = self.state.frame_count,
                .frame_index = if (self.state.done and self.state.frame_count != 0) self.state.frame_count - 1 else self.state.frame_count,
                .finishing = self.state.finishing,
                .done = self.state.done,
                .parallel = observed,
            };
        }

        pub fn memorySnapshot(self: *const Self) memory.Snapshot {
            const heap = self.control.snapshot();
            var observed = profiles.snapshot(self);
            observed.profile.live_requested_bytes = heap.live_requested_bytes;
            observed.profile.peak_requested_bytes = heap.peak_requested_bytes;
            profiles.publishObserved(Codec, self, observed);
            return heap;
        }

        pub fn failedProgress(self: *const Self) ?core.Progress {
            return if (self.last_call_error != null) self.last_step_progress else null;
        }

        pub fn flush(self: *Self) void {
            if (self.failure == null and !self.state.finishing and !self.state.done and !self.state.skippable_only) self.state.flushing = true;
            profiles.publish(Codec, self);
        }

        pub fn finish(self: *Self) void {
            if (self.failure == null and !self.state.done and !self.state.skippable_only) {
                self.state.finishing = true;
                self.state.flushing = false;
            }
            profiles.publish(Codec, self);
        }

        pub fn step(self: *Self, input: []const u8, output: []u8, current: Limits) Error!core.StepResult {
            var progress: core.Progress = .{};
            self.last_call_error = null;
            defer {
                self.last_step_progress = progress;
                profiles.publish(Codec, self);
            }
            if (current.max_job_count == 0) {
                self.last_call_error = error.InvalidBlockPlan;
                return error.InvalidBlockPlan;
            }
            settings.applyLimits(Codec, &self.options, current);
            return self.stepInner(input, output, current, &progress) catch |err| {
                self.last_call_error = err;
                return err;
            };
        }

        fn validateOffer(self: *Self, input_len: usize, current: Limits) Error!void {
            if (input_len == 0) return;
            _ = try self.state.checkInput(input_len, current.max_input_len);
            const filling = self.queue.fillingLen();
            const existing_room = if (filling == 0) 0 else self.config.geometry.job_size - filling;
            const extra = input_len - @min(input_len, existing_room);
            const jobs = if (extra == 0) 0 else 1 + (extra - 1) / self.config.geometry.job_size;
            const admitted = self.queue.copyProfile().accepted_jobs;
            if (try count.addLocal(admitted, jobs) > current.max_job_count) return error.OutputLimitExceeded;
        }

        fn stepInner(self: *Self, input: []const u8, output: []u8, current: Limits, progress: *core.Progress) Error!core.StepResult {
            if (self.failure) |err| return err;
            if (self.state.done) {
                if (input.len != 0) return error.TrailingData;
                return result(progress.*, .done);
            }
            if ((self.state.finishing or self.state.flushing or self.state.skippable_only) and input.len != 0) return error.TrailingData;
            try self.validateOffer(input.len, current);
            if (self.state.finishing) if (self.state.expected_input_len) |expected| {
                if (self.state.frame_input != expected) return self.poison(error.SizeMismatch);
            };
            self.queue.setAdmissionLimit(current.max_job_count);
            while (true) {
                try self.checkQueueError();
                if (self.state.unit != .none) {
                    try self.state.checkPending(current.max_pending_output_len);
                    if (self.state.unit == .footer or (self.front_job != null and self.front_job.?.final)) _ = try self.state.nextFrameCount();
                    const complete = self.state.drain(output, progress, current.max_output_len) catch |err| {
                        if (self.front_job) |job| job.output_offset = self.state.front_offset;
                        return err;
                    };
                    if (self.front_job) |job| job.output_offset = self.state.front_offset;
                    if (!complete) return result(progress.*, .need_output);
                    switch (self.state.unit) {
                        .header => {
                            self.state.clearFront();
                            self.state.header_written = true;
                        },
                        .job => {
                            const job = self.front_job orelse return self.poison(error.InvalidStreamState);
                            const ordinal = job.ordinal;
                            self.queue.releaseDelivered(ordinal) catch |err| return self.poison(err);
                            profiles.mergeDelivered(Codec, self);
                            self.front_job = null;
                            self.front_emitted = .{};
                            self.state.clearFront();
                        },
                        .footer => {
                            self.queue.stopJoin();
                            self.queue.collectCompletedWork();
                            try self.state.completeFrame();
                            return result(progress.*, .done);
                        },
                        .skippable => {
                            self.state.clearFront();
                            self.state.skippable_only = false;
                            self.state.done = true;
                            return result(progress.*, .done);
                        },
                        .none => unreachable,
                    }
                    continue;
                }
                if (!self.state.header_written) {
                    try self.prepareHeader();
                    continue;
                }
                if (progress.input_read < input.len) {
                    if (self.queue.fillingLen() == self.config.geometry.job_size) {
                        _ = self.queue.seal(.more_input) catch |err| return self.poison(err);
                        continue;
                    }
                    const room = self.queue.admissionRoom();
                    if (room != 0) {
                        const take = @min(room, input.len - progress.input_read);
                        _ = try self.state.checkInput(take, current.max_input_len);
                        const accepted = self.queue.accept(input[progress.input_read..][0..take], take) catch |err| return self.poison(err);
                        if (accepted != 0) {
                            self.state.commitInput(try self.state.checkInput(accepted, current.max_input_len));
                            self.hash.update(input[progress.input_read..][0..accepted]);
                            progress.input_read += accepted;
                            continue;
                        }
                    }
                }
                if (self.state.finishing and !self.state.final_job_sealed) {
                    const observed = self.queue.copyProfile();
                    if (self.queue.fillingLen() != 0 or observed.accepted_jobs < current.max_job_count) {
                        if (self.queue.seal(.finish) catch |err| return self.poison(err)) {
                            self.state.final_job_sealed = true;
                            continue;
                        }
                    }
                } else if (self.state.flushing and self.queue.fillingLen() != 0) {
                    _ = self.queue.seal(.flush) catch |err| return self.poison(err);
                    continue;
                }
                const observed = self.queue.snapshot();
                const submitted = observed.inflight_jobs - @as(usize, @intFromBool(observed.partial_input_bytes != 0));
                if (submitted != 0) {
                    if (progress.output_written == output.len) return result(progress.*, .need_output);
                    const job = (self.queue.peekOldest(true) catch |err| return self.poison(err)) orelse return self.poison(error.InvalidStreamState);
                    try self.prepareJob(job);
                    continue;
                }
                if (progress.input_read != input.len) return error.WorkingMemoryLimitExceeded;
                if (self.state.flushing) {
                    self.state.flushing = false;
                    return result(progress.*, .need_input);
                }
                if (self.state.finishing) {
                    if (!self.state.final_job_sealed) {
                        _ = try count.addLocal(observed.profile.accepted_jobs, 1);
                        return error.OutputLimitExceeded;
                    }
                    try self.prepareFooter();
                    continue;
                }
                return result(progress.*, .need_input);
            }
        }

        fn prepareHeader(self: *Self) Error!void {
            self.control.coordinator.clearFailure();
            const original = self.state.front.items.len;
            errdefer self.state.front.items.len = original;
            Codec.writeStreamHeader(self.control.allocator(), &self.state.front, self.config.frame_options, self.config.expected_input_len, self.config.dictionary_id) catch |err| return self.poison(self.control.coordinator.mapError(err));
            self.state.unit = .header;
        }

        fn prepareJob(self: *Self, job: *Queue.Job) Error!void {
            if (job.final) _ = try self.state.nextFrameCount();
            self.control.coordinator.clearFailure();
            const before = self.adapter_work.emitted();
            Codec.appendOwnedJob(self.control.allocator(), &self.state.front, job.output.items, job.view(self.config.history_window_len), self.config.frame_options, self.config.dictionary, &self.actual_state, &self.adapter_work) catch |err| return self.poison(self.control.coordinator.mapError(err));
            const blocks = Codec.blockCount(self.state.front.items) catch |err| return self.poison(err);
            self.queue.markPublished(job.ordinal, blocks, self.state.front.items.len) catch |err| return self.poison(err);
            self.front_emitted = profiles.emittedDelta(Codec, before, self.adapter_work.emitted());
            self.front_job = job;
            self.state.unit = .job;
        }

        fn prepareFooter(self: *Self) Error!void {
            _ = try self.state.nextFrameCount();
            self.control.coordinator.clearFailure();
            const original = self.state.front.items.len;
            errdefer self.state.front.items.len = original;
            Codec.writeStreamChecksum(self.control.allocator(), &self.state.front, &self.hash, self.config.frame_options) catch |err| return self.poison(self.control.coordinator.mapError(err));
            self.state.unit = .footer;
        }

        fn checkQueueError(self: *Self) Error!void {
            if (self.queue.snapshot().last_error) |err| return self.poison(@errorCast(err));
        }

        fn poison(self: *Self, err: Error) Error {
            if (self.failure == null) self.failure = err;
            self.queue.stopJoin();
            self.queue.collectCompletedWork();
            return self.failure.?;
        }

        pub fn reset(self: *Self, current: Limits) void {
            self.queue.stopJoin();
            self.queue.collectCompletedWork();
            profiles.publish(Codec, self);
            settings.applyLimits(Codec, &self.options, current);
            self.config.max_job_count = self.options.max_job_count;
            self.queue.resetRetainingCapacity(self.config) catch unreachable;
            Codec.resetStateRetainingCapacity(&self.actual_state, self.config.dictionary) catch unreachable;
            self.state.resetFrame(self.config.expected_input_len, true);
            self.hash = Codec.Hash.init(0);
            self.front_job = null;
            self.front_emitted = .{};
            self.delivered_emitted = .{};
            self.adapter_work = .{};
            self.failure = null;
            self.last_call_error = null;
            self.last_step_progress = .{};
            profiles.capture(Codec, self);
            self.control.resetPeak();
            profiles.publish(Codec, self);
        }

        pub fn nextFrame(self: *Self, options: Options, expected: ?types.Count, dictionary: ?Codec.Dictionary, metadata_id: ?u32) Error!void {
            defer profiles.publish(Codec, self);
            if (self.failure != null or !self.state.done or self.state.unit != .none or self.queue.snapshot().inflight_jobs != 0) return error.InvalidBlockPlan;
            try validate(options, expected, dictionary, metadata_id);
            const prepared = try settings.prepare(Codec, options, expected, dictionary, metadata_id);
            const previous_limit = self.control.snapshot().limit;
            const next_limit = settings.heapLimit(Codec, prepared.options);
            try self.control.checkNewLimit(next_limit);
            try self.control.changeLimit(next_limit);
            errdefer self.control.changeLimit(previous_limit) catch unreachable;
            profiles.publish(Codec, self);
            try self.queue.resetRetainingCapacity(prepared.config);
            Codec.resetStateRetainingCapacity(&self.actual_state, dictionary) catch unreachable;
            self.options = prepared.options;
            self.config = prepared.config;
            self.state.resetFrame(expected, false);
            self.hash = Codec.Hash.init(0);
            self.front_job = null;
            self.front_emitted = .{};
            self.delivered_emitted = .{};
            self.adapter_work = .{};
            self.last_call_error = null;
            self.last_step_progress = .{};
            profiles.capture(Codec, self);
            self.control.resetPeak();
        }

        pub fn writeSkippable(self: *Self, id: u4, payload: []const u8, current: Limits) Error!void {
            defer profiles.publish(Codec, self);
            if (self.failure) |err| return err;
            if (self.config.frame_options.format != .standard or !self.state.done or self.state.unit != .none) return error.InvalidBlockPlan;
            if (payload.len > std.math.maxInt(u32)) return error.IntegerOverflow;
            self.control.coordinator.clearFailure();
            const original = self.state.front.items.len;
            errdefer {
                if (self.state.unit == .none) self.state.front.items.len = original;
            }
            Codec.writeSkippable(self.control.allocator(), &self.state.front, id, payload) catch |err| return self.poison(self.control.coordinator.mapError(err));
            self.state.unit = .skippable;
            self.state.skippable_only = true;
            self.state.done = false;
            try self.state.checkPending(current.max_pending_output_len);
        }

        pub fn deinit(self: *Self) void {
            self.queue.stopJoin();
            self.queue.collectCompletedWork();
            profiles.publish(Codec, self);
            const destination = self.options.parallel.profile;
            const memory_destination = self.options.frame.memory_profile;
            const control = self.control;
            const limit = control.snapshot().limit;
            const allocator = control.allocator();
            self.queue.deinit();
            self.state.deinit(allocator);
            Codec.deinitState(allocator, &self.actual_state);
            allocator.destroy(self);
            control.destroy();
            if (destination) |profile| {
                profile.live_requested_bytes = 0;
                profile.workers_live = 0;
            }
            if (memory_destination) |profile| profile.record(0, limit);
        }

        fn result(progress: core.Progress, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = progress, .status = status };
        }
    };
}
