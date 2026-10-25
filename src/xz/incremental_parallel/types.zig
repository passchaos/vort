//! Internal configuration and public observations for persistent XZ encoding.
const std = @import("std");
const core = @import("../../core.zig");
const writer = @import("../writer.zig");
const parallel = @import("../parallel/types.zig");

pub const Error = writer.Error || std.mem.Allocator.Error || error{WorkingMemoryLimitExceeded};
pub const Options = parallel.Options;
pub const Profile = parallel.Profile;

pub const Storage = struct {
    plain: std.ArrayList(u8) = .empty,
    pending: std.ArrayList(u8) = .empty,
    records: std.ArrayList(writer.BlockRecord) = .empty,

    pub fn retainedBytes(self: Storage) Error!usize {
        const record_bytes = std.math.mul(usize, self.records.capacity, @sizeOf(writer.BlockRecord)) catch return error.IntegerOverflow;
        const plain_and_pending = std.math.add(usize, self.plain.capacity, self.pending.capacity) catch return error.IntegerOverflow;
        return std.math.add(usize, plain_and_pending, record_bytes) catch error.IntegerOverflow;
    }
};

pub const Counters = struct {
    total_input: usize = 0,
    total_output: usize = 0,
    block_count: usize = 0,
    stream_count: usize = 0,
};

pub const Config = struct {
    writer_options: writer.EncodeOptions,
    payload_encoding: writer.PayloadEncoding = .compressed,
    max_input_len: usize = std.math.maxInt(usize),
    max_pending_output_len: usize = 16 * 1024 * 1024,
    max_block_count: usize = 1024 * 1024,
    expected_input_len: ?usize = null,
    parallel: Options,

    pub fn validate(self: Config) Error!void {
        try self.writer_options.validate();
        try self.parallel.validate();
        if (self.max_pending_output_len == 0 or self.max_block_count == 0)
            return error.OutputLimitExceeded;
        // A small explicit partial block may fit even when block_size exceeds
        // the byte cap. Queue admission handles that case without splitting.
    }
};

/// Locked observations. Heap values are requested storage, not RSS; logical
/// in-flight plaintext includes partial, queued and not fully delivered jobs.
pub const Snapshot = struct {
    enabled: bool = false,
    started: bool = false,
    serial_fallback: bool = false,
    workers_started: usize = 0,
    workers_live: usize = 0,
    peak_active_workers: usize = 0,
    queued_blocks: usize = 0,
    active_blocks: usize = 0,
    completed_waiting_blocks: usize = 0,
    delivering_block: bool = false,
    partial_input_bytes: usize = 0,
    owned_input_bytes: usize = 0,
    inflight_blocks: usize = 0,
    inflight_bytes: usize = 0,
    completed_output_bytes: usize = 0,
    delivering_output_bytes: usize = 0,
    retained_input_capacity: usize = 0,
    retained_job_output_capacity: usize = 0,
    retained_front_capacity: usize = 0,
    retained_index_capacity: usize = 0,
    live_requested_bytes: usize = 0,
    peak_requested_bytes: usize = 0,
    control_bytes: usize = 0,
    accepted_blocks: usize = 0,
    encoded_blocks: usize = 0,
    published_blocks: usize = 0,
    delivered_blocks: usize = 0,
    failed: bool = false,
    last_error: ?Error = null,
    last_step_progress: core.Progress = .{},
};

pub const StreamSnapshot = struct {
    counters: Counters = .{},
    current_input: usize = 0,
    current_output: usize = 0,
    buffered_input: usize = 0,
    pending_output: usize = 0,
    current_stream_blocks: usize = 0,
    stream_index: usize = 0,
    flush_requested: bool = false,
    finishing: bool = false,
    done: bool = false,
    retained_input_capacity: usize = 0,
    retained_output_capacity: usize = 0,
    retained_record_capacity: usize = 0,
    parallel: Snapshot = .{},
};
