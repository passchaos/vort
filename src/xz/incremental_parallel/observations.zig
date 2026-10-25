//! Queue observations require its coordinator lock. Active codec output is
//! owned by a worker local; all requested heap remains in the shared ledger.
const types = @import("types.zig");

pub fn snapshot(queue: anytype) types.Snapshot {
    const heap = queue.control.snapshot();
    var result: types.Snapshot = .{
        .enabled = true,
        .started = queue.started,
        .serial_fallback = queue.worker_count == 0,
        .workers_started = queue.private_profile.workers_started,
        .workers_live = queue.workers_live,
        .peak_active_workers = queue.private_profile.peak_active_workers,
        .inflight_blocks = queue.inflight_blocks,
        .inflight_bytes = queue.inflight_bytes,
        .accepted_blocks = queue.accepted,
        .encoded_blocks = queue.encoded,
        .published_blocks = queue.delivered,
        .delivered_blocks = queue.delivered,
        .failed = queue.first_error != null,
        .last_error = queue.first_error,
        .live_requested_bytes = heap.live_requested_bytes,
        .peak_requested_bytes = heap.peak_requested_bytes,
        .control_bytes = heap.control_bytes,
    };
    for (queue.jobs) |*job| {
        result.retained_input_capacity += job.plain.capacity;
        result.retained_job_output_capacity += job.output.capacity;
        result.owned_input_bytes += job.plain.items.len;
        switch (job.state) {
            .filling => result.partial_input_bytes += job.plain.items.len,
            .queued => result.queued_blocks += 1,
            .active => result.active_blocks += 1,
            .complete => {
                result.completed_waiting_blocks += 1;
                result.completed_output_bytes += job.output.items.len;
            },
            .delivering => {
                result.delivering_block = true;
                result.delivering_output_bytes += job.output.items.len - job.output_offset;
            },
            .free => {},
        }
    }
    return result;
}

pub fn frontOutputBytes(queue: anytype) usize {
    if (queue.delivered == queue.submitted) return 0;
    const job = &queue.jobs[queue.delivered % queue.job_count];
    return if (job.state == .complete or job.state == .delivering)
        job.output.items.len - job.output_offset
    else
        0;
}
