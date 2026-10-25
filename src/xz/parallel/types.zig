const std = @import("std");
const builtin = @import("builtin");

/// Each operating-system worker reserves a fixed 2 MiB stack. Stack mappings,
/// OS thread bookkeeping and the caller's buffers are outside requested heap.
pub const worker_stack_bytes: usize = 2 * 1024 * 1024;
pub const target_supports_parallel = !builtin.single_threaded and
    (builtin.os.tag == .linux or builtin.os.tag == .windows or std.Thread.use_pthreads);

/// Per-operation evidence. Borrowed plain input counts against the logical
/// in-flight byte limit until its ordered block has been published. Requested
/// heap includes worker/slot metadata, codec scratch, staged output and Index.
pub const Profile = struct {
    workers_started: usize = 0,
    peak_active_workers: usize = 0,
    peak_inflight_blocks: usize = 0,
    peak_inflight_bytes: usize = 0,
    completed_blocks: usize = 0,
    published_blocks: usize = 0,
    peak_requested_bytes: usize = 0,
    live_requested_bytes: usize = 0,
    serial_fallback: bool = false,

    pub fn reset(self: *Profile) void {
        self.* = .{};
    }
};

pub const Options = struct {
    io: std.Io,
    worker_count: usize = 2,
    max_inflight_blocks: usize = 4,
    max_inflight_bytes: usize = 4 * 1024 * 1024,
    max_working_memory: usize = 256 * 1024 * 1024,
    profile: ?*Profile = null,

    pub fn validate(self: Options) error{InvalidBlockPlan}!void {
        if (self.worker_count == 0 or self.worker_count > 64 or
            self.max_inflight_blocks == 0 or self.max_inflight_bytes == 0) return error.InvalidBlockPlan;
    }

    /// Validation never changes XZ block boundaries to fit resource limits.
    pub fn validateBlockLength(self: Options, block_size: usize, input_len: usize) error{ InvalidBlockPlan, WorkingMemoryLimitExceeded }!void {
        try self.validate();
        if (block_size == 0) return error.InvalidBlockPlan;
        if (@min(block_size, input_len) > self.max_inflight_bytes)
            return error.WorkingMemoryLimitExceeded;
    }
};
