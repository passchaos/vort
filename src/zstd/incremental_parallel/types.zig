//! Persistent single-frame worker policy and wide stream observations.
const std = @import("std");
const core = @import("../../core.zig");
const one_shot = @import("../parallel/types.zig");

pub const Count = core.StreamCount;
pub const Error = one_shot.Error;
pub const worker_stack_bytes = one_shot.worker_stack_bytes;
pub const target_supports_parallel = one_shot.target_supports_parallel;

pub const ParallelOptions = struct {
    io: std.Io,
    worker_count: usize = 2,
    job_size: usize = 1024 * 1024,
    max_inflight_jobs: usize = 4,
    max_inflight_bytes: usize = 4 * 1024 * 1024,
    max_working_memory: usize = 256 * 1024 * 1024,
    profile: ?*Profile = null,

    pub fn validate(self: ParallelOptions) Error!void {
        if (self.worker_count == 0 or self.worker_count > 64 or self.job_size == 0 or
            self.max_inflight_jobs == 0 or self.max_inflight_bytes == 0)
            return error.InvalidBlockPlan;
    }
};

pub fn EncoderOptions(comptime FrameOptions: type) type {
    return struct {
        frame: FrameOptions = .{ .include_content_size = false },
        parallel: ParallelOptions,
        /// Cumulative caller-owned plaintext accepted across data frames.
        max_input_len: Count = std.math.maxInt(Count),
        /// Cumulative bytes delivered across data and skippable frames.
        max_output_len: Count = std.math.maxInt(Count),
        /// Entire Header, coordinated Job, or final/skippable publication unit.
        max_pending_output_len: usize = 16 * 1024 * 1024,
        /// Current-frame Job admissions, including partial and empty final Jobs.
        max_job_count: Count = std.math.maxInt(Count),
    };
}

pub const Geometry = struct {
    block_size: usize,
    job_size: usize,
    slot_count: usize,
    worker_count: usize,

    pub fn init(block_size: usize, parallel: ParallelOptions, max_jobs: Count) Error!Geometry {
        try parallel.validate();
        if (block_size == 0) return error.InvalidBlockPlan;
        if (max_jobs == 0) return error.OutputLimitExceeded;
        const remainder = parallel.job_size % block_size;
        const job_size = if (remainder == 0) parallel.job_size else std.math.add(usize, parallel.job_size, block_size - remainder) catch return error.IntegerOverflow;
        // A partial Job may be explicitly flushed below the full Job size.
        // Admission always checks actual accepted plaintext bytes separately.
        const byte_slots = 1 + (parallel.max_inflight_bytes - 1) / job_size;
        const requested = @min(parallel.max_inflight_jobs, byte_slots);
        const slots: usize = @intCast(@min(core.stream_count.fromLocal(requested), max_jobs));
        const available_workers = @min(parallel.worker_count, slots);
        return .{
            .block_size = block_size,
            .job_size = job_size,
            .slot_count = slots,
            .worker_count = if (target_supports_parallel and available_workers > 1 and
                parallel.io.vtable != std.Io.failing.vtable) available_workers else 0,
        };
    }
};

pub fn Config(comptime Codec: type) type {
    return struct {
        frame_options: Codec.Options,
        parallel: ParallelOptions,
        geometry: Geometry,
        history_window_len: usize,
        expected_input_len: ?Count = null,
        dictionary_id: ?u32 = null,
        dictionary: ?Codec.Dictionary = null,
        max_job_count: Count = std.math.maxInt(Count),
    };
}

/// Counters apply to the current data frame. Worker activity is observed at
/// public touchpoints; only the owner writes caller profile destinations.
pub const Profile = struct {
    enabled: bool = false,
    started: bool = false,
    serial_fallback: bool = false,
    configured_workers: usize = 0,
    effective_workers: usize = 0,
    workers_started: usize = 0,
    workers_live: usize = 0,
    peak_active_workers: usize = 0,
    effective_job_size: usize = 0,
    accepted_jobs: Count = 0,
    encoded_jobs: Count = 0,
    published_jobs: Count = 0,
    delivered_jobs: Count = 0,
    encoded_blocks: Count = 0,
    published_blocks: Count = 0,
    /// Blocks belonging to Jobs whose final output byte has been delivered.
    delivered_blocks: Count = 0,
    accepted_input_bytes: Count = 0,
    peak_inflight_jobs: usize = 0,
    peak_inflight_bytes: usize = 0,
    live_requested_bytes: usize = 0,
    peak_requested_bytes: usize = 0,
};

pub const Snapshot = struct {
    profile: Profile = .{},
    queued_jobs: usize = 0,
    active_jobs: usize = 0,
    completed_waiting_jobs: usize = 0,
    delivering_job: bool = false,
    partial_input_bytes: usize = 0,
    owned_input_bytes: usize = 0,
    inflight_jobs: usize = 0,
    inflight_bytes: usize = 0,
    completed_output_bytes: usize = 0,
    delivering_output_bytes: usize = 0,
    retained_input_capacity: usize = 0,
    retained_job_output_capacity: usize = 0,
    retained_history_capacity: usize = 0,
    logical_history_bytes: usize = 0,
    logical_history_end: Count = 0,
    history_window_len: usize = 0,
    retained_front_capacity: usize = 0,
    control_bytes: usize = 0,
    failed: bool = false,
    last_error: ?anyerror = null,
    last_step_progress: core.Progress = .{},
};
