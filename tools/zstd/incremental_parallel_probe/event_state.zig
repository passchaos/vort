//! Owned probe observations, reusable caller buffers and per-step checks.
const std = @import("std");
const zstd = @import("zstd");
const configuration = @import("config.zig");
const Config = configuration.Config;
const Count = configuration.Count;
const E = zstd.NativeIncrementalParallelFrameEncoder;
const ParallelProfile = @TypeOf(@as(E.Snapshot, undefined).parallel.profile);

const Progress = struct { input_read: usize = 0, output_written: usize = 0 };
pub const Status = enum { need_input, need_output, done };
pub const Result = struct { progress: Progress, status: ?Status = null, failure: ?anyerror = null };
const Event = struct {
    call: usize,
    operation: []const u8,
    offered: usize = 0,
    output_capacity: usize = 0,
    progress: Progress = .{},
    status: ?Status = null,
    failure: ?anyerror = null,
    failed_progress: ?Progress = null,
    before: E.Snapshot,
    after: E.Snapshot,
};
const Frame = struct {
    wire_start: usize,
    wire_bytes: usize,
    input_start: usize = 0,
    input_bytes: usize,
    pledged_input_len: ?Count,
    snapshot: E.Snapshot,
};
const Skip = struct { wire_start: usize, wire_bytes: usize, id: u4, payload_bytes: usize };
pub const ControlRun = struct {
    name: []const u8,
    failure: ?anyerror,
    wire_equal: bool,
    configured_workers: usize,
    output_bytes: usize,
    public_step_calls: usize,
    snapshot: ?E.Snapshot,
    control_profile: zstd.EncoderControlProfile,
};
const Invariants = struct {
    progress_accounting: bool = true,
    caller_guards: bool = true,
    accepted_prefix_poison: bool = true,
    profile_bounds: bool = true,
    header_gate: bool = true,
    full_job_wait: bool = false,
    invalid_offer_did_not_seal: bool = false,
    last_byte_credit: bool = false,
    partial_credit_recovery: bool = false,
    front_retry_no_reencode: bool = false,
    stream_limit_recovery: bool = false,
    active_move: bool = false,
    reset_reuse: bool = false,
    sticky_zero_progress: bool = false,
    flush_idempotent: bool = false,
};

pub const State = struct {
    init: std.process.Init,
    c: Config,
    input: []const u8,
    dictionary: ?zstd.NativeDictionary,
    set: zstd.NativeDictionarySet,
    encoder: ?E = null,
    profile: ParallelProfile = .{},
    control: zstd.EncoderControlProfile = .{},
    wire: std.ArrayList(u8) = .empty,
    events: std.ArrayList(Event) = .empty,
    frames: std.ArrayList(Frame) = .empty,
    skippable: std.ArrayList(Skip) = .empty,
    flushes: std.ArrayList(Count) = .empty,
    recoveries: std.ArrayList([]const u8) = .empty,
    invariants: Invariants = .{},
    terminal: ?anyerror = null,
    initialized: bool = false,
    self_decode_verified: bool = false,
    calls: usize = 0,
    poisoned_bytes: Count = 0,
    zero_output_calls: usize = 0,
    observed_peak_active_workers: usize = 0,
    borrowed: []u8 = &.{},
    output: []u8 = &.{},
    controls: bool = false,

    pub fn deinit(self: *State) void {
        if (self.encoder) |*encoder| encoder.deinit();
        self.wire.deinit(self.init.gpa);
        self.events.deinit(self.init.gpa);
        self.frames.deinit(self.init.gpa);
        self.skippable.deinit(self.init.gpa);
        self.flushes.deinit(self.init.gpa);
        self.recoveries.deinit(self.init.gpa);
        self.init.gpa.free(self.borrowed);
        self.init.gpa.free(self.output);
    }
    fn checkBounds(self: *State, s: E.Snapshot) !void {
        const q = s.parallel;
        const p = q.profile;
        if (q.inflight_jobs > self.c.max_inflight_jobs or q.inflight_bytes > self.c.max_inflight_bytes or
            q.partial_input_bytes > q.inflight_bytes or p.delivered_jobs > p.published_jobs or
            p.published_jobs > p.encoded_jobs or p.encoded_jobs > p.accepted_jobs or
            p.delivered_blocks > p.published_blocks or p.published_blocks > p.encoded_blocks or
            p.live_requested_bytes > self.c.max_working_memory or p.peak_requested_bytes > self.c.max_working_memory)
        {
            self.invariants.profile_bounds = false;
            return error.PublicProfileBounds;
        }
        if (q.logical_history_bytes > q.history_window_len or q.retained_history_capacity < q.logical_history_bytes or
            q.logical_history_end > s.frame_input)
        {
            self.invariants.profile_bounds = false;
            return error.PublicLogicalHistoryBounds;
        }
        self.observed_peak_active_workers = @max(self.observed_peak_active_workers, p.peak_active_workers);
    }
    pub fn call(self: *State, offered: []const u8, quota: usize) !Result {
        if (offered.len > self.borrowed.len or quota + 16 > self.output.len) return error.ProbeBufferQuota;
        const encoder = &self.encoder.?;
        const before = encoder.snapshot();
        @memcpy(self.borrowed[0..offered.len], offered);
        @memset(self.output, 0xa5);
        self.calls += 1;
        self.zero_output_calls += @intFromBool(quota == 0);
        const raw = encoder.step(self.borrowed[0..offered.len], self.output[8..][0..quota]);
        var result: Result = undefined;
        if (raw) |step| {
            result = .{ .progress = .{ .input_read = step.progress.input_read, .output_written = step.progress.output_written }, .status = switch (step.status) {
                .need_input => .need_input,
                .need_output => .need_output,
                .done => .done,
            } };
            if (encoder.failedProgress() != null) return error.SuccessHasFailureProgress;
        } else |err| {
            const progress = encoder.failedProgress() orelse return error.MissingFailureProgress;
            result = .{ .progress = .{ .input_read = progress.input_read, .output_written = progress.output_written }, .failure = err };
        }
        const after = encoder.snapshot();
        const progress = result.progress;
        if (progress.input_read > offered.len or progress.output_written > quota or
            after.input_read - before.input_read != progress.input_read or after.output_written - before.output_written != progress.output_written or
            after.parallel.last_step_progress.input_read != progress.input_read or after.parallel.last_step_progress.output_written != progress.output_written)
        {
            self.invariants.progress_accounting = false;
            return error.PublicProgressAccounting;
        }
        for (self.output[0..8]) |byte| if (byte != 0xa5) {
            self.invariants.caller_guards = false;
            return error.OutputGuardChanged;
        };
        for (self.output[8 + progress.output_written ..]) |byte| if (byte != 0xa5) {
            self.invariants.caller_guards = false;
            return error.OutputGuardChanged;
        };
        if (!std.mem.eql(u8, self.borrowed[0..offered.len], offered)) {
            self.invariants.accepted_prefix_poison = false;
            return error.BorrowedInputMutated;
        }
        @memset(self.borrowed[0..progress.input_read], 0xdd);
        @memset(self.borrowed[progress.input_read..offered.len], 0xee);
        self.poisoned_bytes += progress.input_read;
        try self.wire.appendSlice(self.init.gpa, self.output[8..][0..progress.output_written]);
        const header = configuration.headerLen(self.c, self.dictionary, try configuration.pledge(self.c, self.input.len));
        if (after.frame_output < header and (progress.input_read != 0 or after.parallel.profile.workers_started != 0 or after.parallel.owned_input_bytes != 0)) {
            self.invariants.header_gate = false;
            return error.HeaderAcceptedOrStartedWorkers;
        }
        try self.checkBounds(after);
        if (!self.controls and (self.calls % self.c.record_every == 0 or result.failure != null or result.status == .done or
            before.parallel.delivering_job != after.parallel.delivering_job or before.parallel.profile.delivered_jobs != after.parallel.profile.delivered_jobs))
        {
            try self.events.append(self.init.gpa, .{ .call = self.calls, .operation = "step", .offered = offered.len, .output_capacity = quota, .progress = progress, .status = result.status, .failure = result.failure, .failed_progress = if (result.failure != null) progress else null, .before = before, .after = after });
        }
        return result;
    }
    pub fn touch(self: *State, operation: []const u8, before: E.Snapshot) !void {
        const after = self.encoder.?.snapshot();
        if (!self.controls) try self.events.append(self.init.gpa, .{ .call = self.calls, .operation = operation, .before = before, .after = after });
        try self.checkBounds(after);
    }
    pub fn sticky(self: *State, err: anyerror) !void {
        const before = self.encoder.?.snapshot();
        if (!before.parallel.failed) return;
        for (0..2) |_| {
            const result = try self.call("x", 1);
            const actual_error: anyerror = result.failure orelse return error.StickyFailureAdvanced;
            if (actual_error != err or result.progress.input_read != 0 or result.progress.output_written != 0) return error.StickyFailureAdvanced;
        }
        self.invariants.sticky_zero_progress = true;
    }
};
