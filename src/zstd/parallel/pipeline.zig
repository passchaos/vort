//! One frame is built from bounded independent Jobs. Codec.appendJob owns the
//! safe handoff of entropy tables and recent offsets between published spans.
const std = @import("std");
const memory = @import("../../io/threaded_working_memory.zig");
const types = @import("types.zig");
const queues_mod = @import("queue.zig");

pub fn Pipeline(comptime Codec: type) type {
    return struct {
        pub fn append(control: *memory.Control, out: *std.ArrayList(u8), input: []const u8, frame_options: Codec.Options, parallel: types.Options, dictionary: ?Codec.Dictionary, work: *Codec.Profile, profile: *types.Profile) Codec.Error!void {
            const block_size = try Codec.blockSize(frame_options);
            const geometry = try types.Geometry.init(input.len, block_size, parallel);
            const original_len = out.items.len;
            errdefer out.items.len = original_len;
            profile.* = .{
                .available = true,
                .serial_fallback = geometry.worker_count == 0,
                .configured_workers = parallel.worker_count,
                .effective_workers = if (geometry.worker_count == 0) 1 else geometry.worker_count,
                .effective_job_size = geometry.job_size,
                .job_count = geometry.job_count,
            };
            var state = try Codec.initialState(dictionary);
            defer Codec.deinitState(control.allocator(), &state);
            control.coordinator.clearFailure();
            Codec.writeHeader(control.allocator(), out, input, frame_options) catch |err| return control.coordinator.mapError(err);

            const queue = try queues_mod.Queue(Codec).create(control, input, frame_options, parallel, dictionary, geometry);
            defer {
                queue.stopJoin();
                queue.collectCompletedWork();
                work.mergeWork(queue.workSnapshot());
                const previous_heap_peak = profile.peak_requested_bytes;
                const previous_heap_live = profile.live_requested_bytes;
                profile.* = queue.copyProfile();
                profile.peak_requested_bytes = previous_heap_peak;
                profile.live_requested_bytes = previous_heap_live;
                queue.deinit();
                profile.retained_job_output_capacity = 0;
            }
            try queue.start();
            var submitted: usize = 0;
            var published: usize = 0;
            var input_offset: usize = 0;
            while (published < geometry.job_count) {
                while (submitted < geometry.job_count) {
                    const plain_len = @min(geometry.job_size, input.len - input_offset);
                    const end = input_offset + plain_len;
                    if (!try queue.submit(input_offset, end)) break;
                    submitted += 1;
                    input_offset = end;
                }
                const job = (try queue.peekOldest(true)) orelse return error.InvalidStreamState;
                control.coordinator.clearFailure();
                Codec.appendJob(control.allocator(), out, job.output.items, input, job.start, job.end, frame_options, dictionary, &state, work, profile) catch |err| return control.coordinator.mapError(err);
                try queue.releasePublished();
                published += 1;
            }
            queue.stopJoin();
            control.coordinator.clearFailure();
            Codec.checksum(control.allocator(), out, input, frame_options) catch |err| return control.coordinator.mapError(err);
        }
    };
}
