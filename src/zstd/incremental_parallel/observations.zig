//! Read-only calculations made while the Queue coordinator lock is held.
const core = @import("../../core.zig");
const types = @import("types.zig");

pub fn snapshot(queue: anytype) types.Snapshot {
    const heap = queue.control.snapshot();
    var profile = queue.private_profile;
    profile.live_requested_bytes = heap.live_requested_bytes;
    profile.peak_requested_bytes = heap.peak_requested_bytes;
    var result: types.Snapshot = .{ .profile = profile, .inflight_jobs = queue.inflight_jobs, .inflight_bytes = queue.inflight_bytes, .retained_history_capacity = queue.history.bytes.capacity, .logical_history_bytes = queue.history.bytes.items.len, .logical_history_end = queue.history.end, .history_window_len = queue.config.history_window_len, .control_bytes = heap.control_bytes, .failed = queue.first_error != null, .last_error = queue.first_error };
    for (queue.jobs) |job| {
        result.retained_input_capacity += job.bytes.capacity;
        result.retained_job_output_capacity += job.output.capacity;
        result.owned_input_bytes += job.plain().len;
        switch (job.state) {
            .filling => result.partial_input_bytes += job.plain().len,
            .queued => result.queued_jobs += 1,
            .active => result.active_jobs += 1,
            .complete => {
                result.completed_waiting_jobs += 1;
                result.completed_output_bytes += job.output.items.len;
            },
            .delivering => {
                result.delivering_job = true;
                result.delivering_output_bytes += job.publication_size - job.output_offset;
            },
            .free => {},
        }
    }
    return result;
}

pub fn frontOutputBytes(queue: anytype) usize {
    if (queue.delivered == queue.submitted) return 0;
    const job = &queue.jobs[core.stream_count.ringIndex(queue.delivered, queue.config.geometry.slot_count)];
    return switch (job.state) {
        .complete => job.output.items.len,
        .delivering => job.publication_size - job.output_offset,
        else => 0,
    };
}

/// Completed work is observable before delivery without changing Job merge
/// markers. Later delivery or stopped collection still commits each Job once.
pub fn workSnapshot(queue: anytype) @TypeOf(queue.aggregate_work) {
    var work = queue.aggregate_work;
    var ordinal = queue.delivered;
    while (ordinal != queue.submitted) : (ordinal = core.stream_count.addLocal(ordinal, 1) catch unreachable) {
        const job = &queue.jobs[core.stream_count.ringIndex(ordinal, queue.config.geometry.slot_count)];
        if ((job.state == .complete or job.state == .delivering) and !job.merged)
            work.mergeWork(job.work);
    }
    return work;
}
