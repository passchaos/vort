//! Stable coordinator for one persistent incremental XZ stream. Workers own
//! only Queue storage; public encoder values and caller profiles never escape
//! into their threads. Stream bytes and Index records publish in input order.
const std = @import("std");
const core = @import("../../core.zig");
const settings = @import("../../lzma/encode_options.zig");
const memory = @import("memory.zig");
const types = @import("types.zig");
const queue_mod = @import("queue.zig");
const stream = @import("stream.zig");

pub const Error = types.Error;
pub const Released = struct { storage: types.Storage, counters: types.Counters };

pub const Owner = struct {
    backing: std.mem.Allocator,
    control: *memory.Control,
    queue: *queue_mod.Queue,
    config: types.Config,
    state: stream.State,
    failure: ?Error = null,
    last_step_progress: core.Progress = .{},
    last_call_failed: bool = false,
    last_step_error: ?Error = null,
    work_baseline: settings.EncodeWorkProfile = .{},

    /// Existing backing allocations are adopted only after every fallible
    /// owner/queue allocation succeeds. Failed activation releases ledger seed
    /// while leaving all caller descriptors and physical buffers untouched.
    pub fn create(backing: std.mem.Allocator, config: types.Config, storage: types.Storage, initial_counters: types.Counters) Error!*Owner {
        try config.validate();
        const seed = try storage.retainedBytes();
        const control = try memory.Control.create(backing, config.parallel.max_working_memory, seed);
        errdefer {
            control.budget.releaseExisting(seed);
            control.destroy();
        }
        control.coordinator.clearFailure();
        const allocator = control.allocator();
        const self = allocator.create(Owner) catch |err| return control.coordinator.mapError(err);
        errdefer allocator.destroy(self);
        const queue = try queue_mod.Queue.create(control, config);
        self.* = .{
            .backing = backing,
            .control = control,
            .queue = queue,
            .config = config,
            .state = .{
                .plain = storage.plain,
                .pending = storage.pending,
                .records = storage.records,
                .expected_input_len = config.expected_input_len,
                .total_input = initial_counters.total_input,
                .total_output = initial_counters.total_output,
                .block_count = initial_counters.block_count,
                .stream_count = initial_counters.stream_count,
            },
        };
        self.state.reset(config.expected_input_len, false);
        queue.adoptReusablePlain(&self.state.plain);
        config.writer_options.recordEffectiveSettings();
        self.captureWorkBaseline();
        return self;
    }

    pub fn counters(self: *const Owner) types.Counters {
        return .{
            .total_input = self.state.total_input,
            .total_output = self.state.total_output,
            .block_count = self.state.block_count,
            .stream_count = self.state.stream_count,
        };
    }

    pub fn snapshot(self: *Owner) types.StreamSnapshot {
        self.publishProfiles();
        var observed = self.queue.snapshot();
        const heap = self.control.snapshot();
        observed.retained_front_capacity = self.state.pending.capacity;
        observed.retained_index_capacity = self.state.records.capacity * @sizeOf(@import("../writer.zig").BlockRecord);
        observed.retained_input_capacity += self.state.plain.capacity;
        observed.live_requested_bytes = heap.live_requested_bytes;
        observed.peak_requested_bytes = heap.peak_requested_bytes;
        observed.control_bytes = heap.control_bytes;
        observed.published_blocks = self.state.records.items.len;
        observed.failed = self.failure != null or observed.failed;
        if (self.failure) |err| observed.last_error = err;
        if (self.failure == null) {
            if (self.last_step_error) |err| observed.last_error = err;
        }
        observed.last_step_progress = self.last_step_progress;
        return .{
            .counters = self.counters(),
            .current_input = self.state.current_input,
            .current_output = self.state.current_output,
            .buffered_input = observed.owned_input_bytes,
            .pending_output = if (self.state.pendingLen() != 0) self.state.pendingLen() else self.queue.frontOutputBytes(),
            .current_stream_blocks = self.state.records.items.len,
            .stream_index = if (self.state.done and self.state.stream_count != 0) self.state.stream_count - 1 else self.state.stream_count,
            .flush_requested = self.state.flush_requested,
            .finishing = self.state.finishing,
            .done = self.state.done,
            .retained_input_capacity = observed.retained_input_capacity,
            .retained_output_capacity = self.state.pending.capacity + observed.retained_job_output_capacity,
            .retained_record_capacity = self.state.records.capacity,
            .parallel = observed,
        };
    }

    pub fn flush(self: *Owner) void {
        if (self.failure == null and !self.state.finishing and !self.state.done)
            self.state.flush_requested = true;
        self.publishProfiles();
    }

    pub fn finish(self: *Owner) void {
        if (self.failure == null and !self.state.done) {
            self.state.finishing = true;
            self.state.flush_requested = false;
        }
        self.publishProfiles();
    }

    pub fn step(self: *Owner, input: []const u8, output: []u8, max_input: usize, max_pending: usize, max_blocks: usize) Error!core.StepResult {
        var progress: core.Progress = .{};
        self.last_step_progress = .{};
        self.last_call_failed = false;
        self.last_step_error = null;
        defer {
            self.last_step_progress = progress;
            self.publishProfiles();
        }
        return self.stepInternal(input, output, max_input, max_pending, max_blocks, &progress) catch |err| {
            self.last_call_failed = true;
            self.last_step_error = err;
            return err;
        };
    }

    fn stepInternal(self: *Owner, input: []const u8, output: []u8, max_input: usize, max_pending: usize, max_blocks: usize, progress: *core.Progress) Error!core.StepResult {
        if (self.failure) |err| return err;
        try self.checkQueueFailure();
        if (self.state.done) {
            if (input.len != 0) return error.TrailingData;
            return result(progress.*, .done);
        }
        if ((self.state.flush_requested or self.state.finishing) and input.len != 0)
            return error.TrailingData;
        if (self.state.finishing) if (self.state.expected_input_len) |expected| {
            if (self.state.current_input != expected) return error.SizeMismatch;
        };
        self.queue.setAdmissionLimit(max_blocks);
        self.config.max_input_len = max_input;
        self.config.max_pending_output_len = max_pending;
        self.config.max_block_count = max_blocks;

        while (true) {
            // Startup preserves serial backpressure: no input is accepted
            // until the complete 12-byte Stream Header reaches the caller.
            if (self.state.pendingLen() != 0) {
                try self.state.drain(output, progress);
                if (self.state.pendingLen() != 0) return result(progress.*, .need_output);
            }
            if (!self.state.header_written) {
                self.control.coordinator.clearFailure();
                self.state.appendHeader(self.control.allocator(), self.config.writer_options.check, max_pending) catch |err|
                    return self.frontError(err);
                continue;
            }
            try self.checkQueueFailure();

            // Fill available credits before delivering the oldest completed
            // Block. An undrained front never serializes later input admission.
            if (progress.input_read < input.len) {
                const observed = self.queue.snapshot();
                const room = self.queue.admissionRoom();
                if (observed.partial_input_bytes == 0 and observed.accepted_blocks >= max_blocks)
                    return error.OutputLimitExceeded;
                if (room != 0) {
                    const take = @min(room, input.len - progress.input_read);
                    _ = try self.state.checkInput(take, max_input);
                    const accepted = self.queue.accept(input[progress.input_read..][0..take], take) catch |err|
                        return self.poison(err);
                    if (accepted != 0) {
                        // A synchronous fallback may have failed codec work
                        // after accepting bytes; Queue returns exact credit
                        // first and exposes its sticky error on observation.
                        self.state.commitInput(try self.state.checkInput(accepted, max_input));
                        progress.input_read += accepted;
                        continue;
                    }
                }
            }

            if (progress.input_read == input.len and (self.state.flush_requested or self.state.finishing) and self.queue.fillingLen() != 0) {
                _ = self.queue.submitPartial() catch |err| return self.poison(err);
                continue;
            }
            const observed = self.queue.snapshot();
            const submitted_jobs = observed.inflight_blocks - @intFromBool(observed.partial_input_bytes != 0);
            if (submitted_jobs != 0) {
                if (progress.output_written == output.len) return result(progress.*, .need_output);
                const job = (self.queue.peekOldest(true) catch |err| return self.poison(err)) orelse
                    return self.poison(error.InvalidStreamState);
                if (!job.indexed) {
                    if (job.output.items.len > max_pending) return error.OutputLimitExceeded;
                    self.control.coordinator.clearFailure();
                    self.state.markIndexed(job.record, self.control.allocator(), max_blocks) catch |err|
                        return self.frontError(err);
                    job.indexed = true;
                }
                try self.drainJob(job, output, progress);
                if (job.output_offset == job.output.items.len) {
                    self.queue.releaseDelivered() catch |err| return self.poison(err);
                    continue;
                }
                return result(progress.*, .need_output);
            }

            if (progress.input_read < input.len) {
                // A partial Block can exhaust a byte cap smaller than the
                // block size. Keep it intact for explicit flush/finish; never
                // silently split the user's format boundary to create credit.
                return error.WorkingMemoryLimitExceeded;
            }
            if (self.state.flush_requested) {
                self.state.flush_requested = false;
                return result(progress.*, .need_input);
            }
            if (self.state.finishing) {
                if (!self.state.footer_written) {
                    self.control.coordinator.clearFailure();
                    self.state.appendFooter(self.control.allocator(), self.config.writer_options.check, max_pending) catch |err|
                        return self.frontError(err);
                    continue;
                }
                try self.state.markDone();
                self.queue.stopJoin();
                self.queue.collectCompletedWork();
                return result(progress.*, .done);
            }
            return result(progress.*, .need_input);
        }
    }

    fn drainJob(self: *Owner, job: *queue_mod.Job, output: []u8, progress: *core.Progress) Error!void {
        const take = @min(output.len - progress.output_written, job.output.items.len - job.output_offset);
        const current = std.math.add(usize, self.state.current_output, take) catch return error.IntegerOverflow;
        const total = std.math.add(usize, self.state.total_output, take) catch return error.IntegerOverflow;
        @memcpy(output[progress.output_written..][0..take], job.output.items[job.output_offset..][0..take]);
        job.output_offset += take;
        progress.output_written += take;
        self.state.current_output = current;
        self.state.total_output = total;
    }

    pub fn failedProgress(self: *const Owner) ?core.Progress {
        return if (self.last_call_failed) self.last_step_progress else null;
    }

    fn checkQueueFailure(self: *Owner) Error!void {
        if (self.queue.snapshot().last_error) |err| return self.poison(err);
    }

    fn frontError(self: *Owner, err: Error) Error {
        if (err == error.OutputLimitExceeded) return err;
        return self.poison(self.control.coordinator.mapError(err));
    }

    fn poison(self: *Owner, err: Error) Error {
        if (self.failure == null) self.failure = err;
        self.queue.stopJoin();
        self.queue.collectCompletedWork();
        return self.failure.?;
    }

    /// New configuration admission accounts for every retained free-slot
    /// allocation. Queue metadata replacements commit only after both reserves
    /// succeed, while a failed attempt keeps the old state and policy intact.
    pub fn nextStream(self: *Owner, config: types.Config) Error!void {
        defer self.publishProfiles();
        if (self.failure != null or !self.state.done or self.state.pendingLen() != 0 or self.queue.snapshot().inflight_blocks != 0)
            return error.InvalidBlockPlan;
        try config.validate();
        try self.queue.checkConfig(config);
        try self.control.checkNewLimit(config.parallel.max_working_memory);
        const previous_limit = self.control.snapshot().limit;
        try self.control.changeLimit(config.parallel.max_working_memory);
        errdefer self.control.changeLimit(previous_limit) catch unreachable;
        self.publishProfiles();
        try self.queue.resetRetainingCapacity(config);
        self.config = config;
        self.state.reset(config.expected_input_len, false);
        self.last_step_progress = .{};
        self.last_call_failed = false;
        self.last_step_error = null;
        config.writer_options.recordEffectiveSettings();
        self.captureWorkBaseline();
    }

    /// Same-configuration reset performs no growth and can discard poisoned
    /// logical state only after every active worker has completed and joined.
    pub fn reset(self: *Owner, expected_input_len: ?usize) void {
        self.queue.stopJoin();
        self.queue.collectCompletedWork();
        self.publishProfiles();
        self.config.expected_input_len = expected_input_len;
        self.queue.resetRetainingCapacity(self.config) catch unreachable;
        self.state.reset(expected_input_len, true);
        self.failure = null;
        self.last_step_progress = .{};
        self.last_call_failed = false;
        self.last_step_error = null;
        self.control.resetPeak();
        self.captureWorkBaseline();
        self.publishProfiles();
    }

    pub fn releaseToSerial(self: *Owner) Error!Released {
        if (self.failure != null or !self.state.done or self.state.pendingLen() != 0 or self.queue.snapshot().inflight_blocks != 0)
            return error.InvalidBlockPlan;
        self.queue.stopJoin();
        self.queue.collectCompletedWork();
        self.publishProfiles();
        const allocator = self.control.allocator();
        var reusable = self.queue.takeReusablePlain();
        if (reusable.capacity > self.state.plain.capacity) {
            self.state.plain.deinit(allocator);
            self.state.plain = reusable;
        } else reusable.deinit(allocator);
        const result_value: Released = .{
            .storage = .{ .plain = self.state.plain, .pending = self.state.pending, .records = self.state.records },
            .counters = self.counters(),
        };
        const retained = try result_value.storage.retainedBytes();
        const control = self.control;
        const destination = self.config.parallel.profile;
        var final_profile = self.profileValue();
        self.queue.deinit();
        allocator.destroy(self);
        control.budget.releaseExisting(retained);
        control.destroy();
        final_profile.live_requested_bytes = 0;
        if (destination) |profile| profile.* = final_profile;
        return result_value;
    }

    pub fn deinit(self: *Owner) void {
        self.queue.stopJoin();
        self.queue.collectCompletedWork();
        self.publishProfiles();
        const control = self.control;
        const allocator = control.allocator();
        const destination = self.config.parallel.profile;
        var final_profile = self.profileValue();
        self.queue.deinit();
        self.state.deinit(allocator);
        allocator.destroy(self);
        control.destroy();
        final_profile.live_requested_bytes = 0;
        if (destination) |profile| profile.* = final_profile;
    }

    fn workDestination(self: *const Owner) ?*settings.EncodeWorkProfile {
        return if (self.config.writer_options.match_options) |matching| matching.profile else null;
    }

    fn captureWorkBaseline(self: *Owner) void {
        self.work_baseline = if (self.workDestination()) |profile| profile.* else .{};
    }

    fn profileValue(self: *Owner) types.Profile {
        var value = self.queue.copyProfile();
        const heap = self.control.snapshot();
        value.published_blocks = self.state.records.items.len;
        value.live_requested_bytes = heap.live_requested_bytes;
        value.peak_requested_bytes = heap.peak_requested_bytes;
        return value;
    }

    pub fn publishProfiles(self: *Owner) void {
        if (self.config.parallel.profile) |profile| profile.* = self.profileValue();
        const destination = self.workDestination() orelse return;
        const aggregate = self.queue.workSnapshot();
        var value = self.work_baseline;
        inline for (std.meta.fields(settings.EncodeWorkProfile)) |field| {
            if (comptime std.mem.eql(u8, field.name, "finder") or std.mem.startsWith(u8, field.name, "effective_")) {
                if (aggregate.effective_nice_len != 0) @field(value, field.name) = @field(aggregate, field.name);
            } else if (comptime std.mem.indexOf(u8, field.name, "peak_working_memory") != null) {
                @field(value, field.name) = @max(@field(value, field.name), @field(aggregate, field.name));
            } else {
                @field(value, field.name) +|= @field(aggregate, field.name);
            }
        }
        destination.* = value;
    }

    fn result(progress: core.Progress, status: core.StepResult.Status) core.StepResult {
        return .{ .progress = progress, .status = status };
    }
};
