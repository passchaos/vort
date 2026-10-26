//! Explicit one-shot Job geometry and observations for one Zstd frame.
const std = @import("std");
const builtin = @import("builtin");
const core = @import("../../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || std.Thread.SpawnError || error{WorkingMemoryLimitExceeded};
pub const worker_stack_bytes: usize = 2 * 1024 * 1024;
pub const target_supports_parallel = !builtin.single_threaded and
    (builtin.os.tag == .linux or builtin.os.tag == .windows or std.Thread.use_pthreads);

pub const Profile = struct {
    available: bool = false,
    serial_fallback: bool = false,
    configured_workers: usize = 0,
    effective_workers: usize = 0,
    workers_started: usize = 0,
    workers_live: usize = 0,
    /// Peak concurrently encoding OS workers; synchronous fallback is zero.
    peak_active_workers: usize = 0,
    effective_job_size: usize = 0,
    job_count: usize = 0,
    encoded_jobs: usize = 0,
    published_jobs: usize = 0,
    encoded_blocks: usize = 0,
    published_blocks: usize = 0,
    peak_inflight_jobs: usize = 0,
    peak_inflight_bytes: usize = 0,
    /// Live Job output capacity; zero after the one-shot queue is destroyed.
    retained_job_output_capacity: usize = 0,
    peak_job_output_capacity: usize = 0,
    peak_requested_bytes: usize = 0,
    live_requested_bytes: usize = 0,

    pub fn reset(self: *Profile) void {
        self.* = .{};
    }
};

pub const Options = struct {
    io: std.Io,
    worker_count: usize = 2,
    job_size: usize = 1024 * 1024,
    max_inflight_jobs: usize = 4,
    max_inflight_bytes: usize = 4 * 1024 * 1024,
    max_working_memory: usize = 256 * 1024 * 1024,
    profile: ?*Profile = null,

    pub fn validate(self: Options) Error!void {
        if (self.worker_count == 0 or self.worker_count > 64 or self.job_size == 0 or
            self.max_inflight_jobs == 0 or self.max_inflight_bytes == 0)
            return error.InvalidBlockPlan;
    }
};

pub const Geometry = struct {
    block_size: usize,
    job_size: usize,
    job_count: usize,
    slot_count: usize,
    worker_count: usize,

    pub fn init(input_len: usize, block_size: usize, options: Options) Error!Geometry {
        try options.validate();
        if (block_size == 0) return error.InvalidBlockPlan;
        const remainder = options.job_size % block_size;
        const job_size = if (remainder == 0) options.job_size else std.math.add(usize, options.job_size, block_size - remainder) catch return error.IntegerOverflow;
        if (@min(input_len, job_size) > options.max_inflight_bytes)
            return error.WorkingMemoryLimitExceeded;
        const job_count = if (input_len == 0) 1 else 1 + (input_len - 1) / job_size;
        const byte_slots = 1 + (options.max_inflight_bytes - 1) / job_size;
        const slots = @min(job_count, @min(options.max_inflight_jobs, byte_slots));
        const available_workers = @min(options.worker_count, slots);
        return .{
            .block_size = block_size,
            .job_size = job_size,
            .job_count = job_count,
            .slot_count = slots,
            .worker_count = if (target_supports_parallel and available_workers > 1) available_workers else 0,
        };
    }

    pub fn blockCount(self: Geometry, start: usize, end: usize) usize {
        return if (start == end) 1 else 1 + (end - start - 1) / self.block_size;
    }
};

test "Zstd parallel geometry admits a full Job and one-byte tail with exact credit" {
    const geometry = try Geometry.init(1025, 128, .{
        .io = .failing,
        .job_size = 1024,
        .max_inflight_bytes = 1025,
    });
    try std.testing.expectEqual(@as(usize, 1024), geometry.job_size);
    try std.testing.expectEqual(@as(usize, 2), geometry.job_count);
    try std.testing.expectEqual(@as(usize, 2), geometry.slot_count);
    try std.testing.expectEqual(if (target_supports_parallel) @as(usize, 2) else 0, geometry.worker_count);
}

test "Zstd parallel geometry one full Job of credit keeps one slot" {
    const geometry = try Geometry.init(1025, 128, .{
        .io = .failing,
        .job_size = 1024,
        .max_inflight_bytes = 1024,
    });
    try std.testing.expectEqual(@as(usize, 2), geometry.job_count);
    try std.testing.expectEqual(@as(usize, 1), geometry.slot_count);
    try std.testing.expectEqual(@as(usize, 0), geometry.worker_count);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, Geometry.init(1025, 128, .{
        .io = .failing,
        .job_size = 1024,
        .max_inflight_bytes = 1023,
    }));
}

test "Zstd parallel geometry checks rounding overflow and exact maximum ceiling" {
    const maximum: usize = std.math.maxInt(usize);
    try std.testing.expectError(error.IntegerOverflow, Geometry.init(1, 128, .{
        .io = .failing,
        .job_size = maximum,
        .max_inflight_bytes = maximum,
    }));
    const geometry = try Geometry.init(maximum, 1, .{
        .io = .failing,
        .job_size = 1,
        .max_inflight_bytes = maximum,
    });
    try std.testing.expectEqual(maximum, geometry.job_count);
    try std.testing.expectEqual(@as(usize, 4), geometry.slot_count);
}
