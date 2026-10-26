const std = @import("std");
const core = @import("../../../core.zig");
const types = @import("../types.zig");
const h = @import("helpers.zig");

pub fn run(comptime Z: type) type {
    return struct {
        const E = Z.NativeIncrementalParallelFrameEncoder;

        fn allocationPath(allocator: std.mem.Allocator) !void {
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            opts.parallel.worker_count = 1;
            opts.parallel.max_inflight_jobs = 1;
            opts.parallel.max_inflight_bytes = 256;
            var encoder = try E.init(allocator, opts);
            var alive = true;
            defer if (alive) encoder.deinit();
            const input = h.fixture(273);
            const bytes = try h.drive(Z, &encoder, opts, &input, 257, 3);
            defer h.a.free(bytes);
            _ = try h.verify(Z, bytes, &input, opts.frame, null);
            var moved = encoder;
            alive = false;
            @memset(std.mem.asBytes(&encoder), 0xa5);
            defer moved.deinit();
            moved.reset();
            const reused = try h.drive(Z, &moved, opts, &input, 19, 1);
            defer h.a.free(reused);
            try std.testing.expectEqualSlices(u8, bytes, reused);
        }

        fn quotaPath(allocator: std.mem.Allocator, opts: @TypeOf(h.options(Z)), input: []const u8) !void {
            var encoder = try E.init(allocator, opts);
            defer encoder.deinit();
            const bytes = try h.drive(Z, &encoder, opts, input, 257, 3);
            defer h.a.free(bytes);
            _ = try h.verify(Z, bytes, input, opts.frame, null);
        }

        test "Zstd parallel incremental scalar admission rejects before allocating or publishing profiles" {
            var heap = h.Heap.init(h.a);
            var profile: types.Profile = .{ .accepted_jobs = 17 };
            var opts = h.options(Z);
            opts.parallel.profile = &profile;
            opts.parallel.worker_count = 0;
            try std.testing.expectError(error.InvalidBlockPlan, E.init(heap.allocator(), opts));
            try std.testing.expectEqual(@as(usize, 0), heap.calls);
            try std.testing.expectEqual(@as(h.Count, 17), profile.accepted_jobs);
            opts.parallel.worker_count = 2;
            opts.max_job_count = 0;
            try std.testing.expectError(error.OutputLimitExceeded, E.init(heap.allocator(), opts));
            try std.testing.expectEqual(@as(usize, 0), heap.calls);
            opts.max_job_count = 1;
            opts.parallel.job_size = std.math.maxInt(usize);
            try std.testing.expectError(error.IntegerOverflow, E.init(heap.allocator(), opts));
            try std.testing.expectEqual(@as(usize, 0), heap.calls);
            try std.testing.expectEqual(@as(h.Count, 17), profile.accepted_jobs);
            opts = h.options(Z);
            opts.frame.include_content_size = true;
            try std.testing.expectError(error.InvalidBlockPlan, E.init(heap.allocator(), opts));
            try std.testing.expectEqual(@as(usize, 0), heap.calls);
        }

        test "Zstd parallel incremental exact shared requested heap quota and one below retain safety" {
            const input = h.fixture(273);
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            opts.parallel.worker_count = 1;
            opts.parallel.max_inflight_jobs = 1;
            opts.parallel.max_inflight_bytes = 256;
            var reference = h.Heap.init(h.a);
            try quotaPath(reference.allocator(), opts, &input);
            try std.testing.expectEqual(@as(usize, 0), reference.live);
            const required = reference.peak;
            try std.testing.expect(required > 1);
            var exact = h.Heap.init(h.a);
            opts.parallel.max_working_memory = required;
            try quotaPath(exact.allocator(), opts, &input);
            try std.testing.expectEqual(@as(usize, 0), exact.live);
            try std.testing.expectEqual(required, exact.peak);
            var below = h.Heap.init(h.a);
            opts.parallel.max_working_memory = required - 1;
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, quotaPath(below.allocator(), opts, &input));
            try std.testing.expectEqual(@as(usize, 0), below.live);
            var native_minimum = h.Heap.init(h.a);
            opts.parallel.max_working_memory = required + 1024;
            opts.frame.max_total_working_memory = required - 1;
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, quotaPath(native_minimum.allocator(), opts, &input));
            try std.testing.expectEqual(@as(usize, 0), native_minimum.live);
        }

        test "Zstd parallel incremental complete header unit limit rejects before ownership and recovers" {
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            opts.max_pending_output_len = 5;
            var encoder = try E.init(h.a, opts);
            defer encoder.deinit();
            var output: [32]u8 = undefined;
            const rejected = try h.failed(Z, &encoder, "abc", &output, error.OutputLimitExceeded);
            try std.testing.expectEqual(core.Progress{}, rejected);
            try std.testing.expect(!encoder.snapshot().parallel.failed);
            try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().parallel.owned_input_bytes);
            try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().parallel.profile.workers_started);
            encoder.options.max_pending_output_len = 6;
            opts.max_pending_output_len = 6;
            const bytes = try h.drive(Z, &encoder, opts, "abc", 3, 1);
            defer h.a.free(bytes);
            _ = try h.verify(Z, bytes, "abc", opts.frame, null);
        }

        test "Zstd parallel incremental serial allocation failure graph cleans move reset and deinit" {
            try std.testing.checkAllAllocationFailures(h.a, allocationPath, .{});
        }

        test "Zstd parallel incremental all worker allocations serialize an unsafe backing and remain charged" {
            const input = h.fixture(4097);
            var heap = h.Heap.init(h.a);
            var opts = h.options(Z);
            opts.parallel.worker_count = 4;
            opts.frame.strategy = .greedy;
            opts.frame.selection = .auto;
            var encoder = try E.init(heap.allocator(), opts);
            var alive = true;
            defer if (alive) encoder.deinit();
            const bytes = try h.drive(Z, &encoder, opts, &input, 257, 3);
            defer h.a.free(bytes);
            const wire = try h.verify(Z, bytes, &input, opts.frame, null);
            const observed = encoder.snapshot();
            try h.complete(observed, opts, input.len, wire.blocks);
            try std.testing.expectEqual(@as(usize, 0), heap.reentries.load(.monotonic));
            try std.testing.expectEqual(heap.live, encoder.memorySnapshot().live_requested_bytes);
            try std.testing.expectEqual(heap.peak, encoder.memorySnapshot().peak_requested_bytes);
            try std.testing.expect(observed.parallel.retained_input_capacity <= heap.live);
            try std.testing.expect(observed.parallel.retained_history_capacity <= heap.live);
            try std.testing.expect(observed.parallel.retained_job_output_capacity <= heap.live);
            if (types.target_supports_parallel) {
                try std.testing.expect(observed.parallel.profile.workers_started != 0);
                try std.testing.expect(observed.parallel.profile.peak_active_workers != 0);
            }
            encoder.deinit();
            alive = false;
            try std.testing.expectEqual(@as(usize, 0), heap.live);
        }

        test "Zstd parallel incremental partial byte credit is not silently shrunk and explicit flush recovers" {
            var input: [38]u8 = undefined;
            h.noise(&input, 0x34125);
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            opts.parallel.max_inflight_bytes = 37;
            var encoder = try E.init(h.a, opts);
            defer encoder.deinit();
            var bytes: std.ArrayList(u8) = .empty;
            defer bytes.deinit(h.a);
            try h.header(Z, &encoder, opts, null, &bytes);
            var output: [32]u8 = undefined;
            const progress = try h.failed(Z, &encoder, &input, &output, error.WorkingMemoryLimitExceeded);
            try std.testing.expectEqual(@as(usize, 37), progress.input_read);
            try std.testing.expectEqual(@as(usize, 0), progress.output_written);
            const partial = encoder.snapshot();
            try std.testing.expect(!partial.parallel.failed);
            try std.testing.expectEqual(@as(usize, 37), partial.parallel.partial_input_bytes);
            try std.testing.expectEqual(@as(h.Count, 0), partial.parallel.profile.encoded_jobs);
            try std.testing.expectEqual(@as(usize, 256), partial.parallel.profile.effective_job_size);
            encoder.flush();
            try h.drain(Z, &encoder, opts, &bytes, .need_input, 1);
            try h.feed(Z, &encoder, opts, &bytes, input[37..], 1, 1);
            encoder.finish();
            try h.drain(Z, &encoder, opts, &bytes, .done, 3);
            const wire = try h.verify(Z, bytes.items, &input, opts.frame, null);
            try std.testing.expectEqual(@as(usize, 2), wire.blocks);
            try std.testing.expectEqual(@as(h.Count, 2), encoder.snapshot().parallel.profile.delivered_jobs);
        }

        test "Zstd parallel incremental a partial job below full byte credit can finish directly" {
            var opts = h.options(Z);
            opts.parallel.max_inflight_bytes = 37;
            opts.frame.selection = .raw_or_rle;
            const input = h.fixture(37);
            var encoder = try E.init(h.a, opts);
            defer encoder.deinit();
            const bytes = try h.drive(Z, &encoder, opts, &input, 37, 1);
            defer h.a.free(bytes);
            const wire = try h.verify(Z, bytes, &input, opts.frame, null);
            try std.testing.expectEqual(@as(usize, 1), wire.blocks);
            try std.testing.expectEqual(@as(h.Count, 1), encoder.snapshot().parallel.profile.delivered_jobs);
        }

        test "Zstd parallel incremental whole publication unit limit survives tiny suffix without reencoding" {
            var input: [257]u8 = undefined;
            h.noise(&input, 0x71532);
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            opts.parallel.worker_count = 1;
            opts.parallel.max_inflight_jobs = 1;
            opts.parallel.max_inflight_bytes = 256;
            var encoder = try E.init(h.a, opts);
            defer encoder.deinit();
            var bytes: std.ArrayList(u8) = .empty;
            defer bytes.deinit(h.a);
            try h.header(Z, &encoder, opts, null, &bytes);
            const queued = try h.checked(Z, &encoder, opts, &input, &.{});
            try std.testing.expectEqual(@as(usize, 256), queued.progress.input_read);
            var first: [8]u8 = undefined;
            const delivered = try h.checked(Z, &encoder, opts, input[256..], &first);
            try std.testing.expectEqual(@as(usize, 0), delivered.progress.input_read);
            try std.testing.expectEqual(first.len, delivered.progress.output_written);
            try bytes.appendSlice(h.a, &first);
            const before = encoder.snapshot();
            try std.testing.expect(before.parallel.delivering_job);
            try std.testing.expectEqual(@as(h.Count, 1), before.parallel.profile.published_jobs);
            encoder.options.max_pending_output_len = 261; // Whole raw Job is 2 * (3 + 128), not its remaining suffix.
            var output: [32]u8 = undefined;
            const progress = try h.failed(Z, &encoder, input[256..], &output, error.OutputLimitExceeded);
            try std.testing.expectEqual(core.Progress{}, progress);
            const rejected = encoder.snapshot();
            try std.testing.expect(!rejected.parallel.failed);
            try std.testing.expectEqual(before.parallel.profile.encoded_jobs, rejected.parallel.profile.encoded_jobs);
            try std.testing.expectEqual(before.parallel.profile.published_jobs, rejected.parallel.profile.published_jobs);
            try std.testing.expectEqual(before.parallel.delivering_output_bytes, rejected.parallel.delivering_output_bytes);
            encoder.options.max_pending_output_len = 262;
            opts.max_pending_output_len = 262;
            try h.feed(Z, &encoder, opts, &bytes, input[256..], 1, 3);
            encoder.finish();
            try h.drain(Z, &encoder, opts, &bytes, .done, 1);
            const wire = try h.verify(Z, bytes.items, &input, opts.frame, null);
            try h.complete(encoder.snapshot(), opts, input.len, wire.blocks);
        }

        test "Zstd parallel incremental last byte releases full job credit and caller emitted counts" {
            var input: [257]u8 = undefined;
            h.noise(&input, 0xa4314);
            var work: Z.EncoderControlProfile = .{};
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            opts.frame.control_profile = &work;
            opts.parallel.worker_count = 1;
            opts.parallel.max_inflight_jobs = 1;
            opts.parallel.max_inflight_bytes = 256;
            var encoder = try E.init(h.a, opts);
            defer encoder.deinit();
            var bytes: std.ArrayList(u8) = .empty;
            defer bytes.deinit(h.a);
            try h.header(Z, &encoder, opts, null, &bytes);
            const queued = try h.checked(Z, &encoder, opts, &input, &.{});
            try std.testing.expectEqual(@as(usize, 256), queued.progress.input_read);
            var almost: [261]u8 = undefined;
            const first = try h.checked(Z, &encoder, opts, input[256..], &almost);
            try std.testing.expectEqual(almost.len, first.progress.output_written);
            try std.testing.expectEqual(@as(usize, 0), first.progress.input_read);
            try bytes.appendSlice(h.a, &almost);
            const waiting = encoder.snapshot();
            try std.testing.expectEqual(@as(h.Count, 1), waiting.parallel.profile.published_jobs);
            try std.testing.expectEqual(@as(h.Count, 0), waiting.parallel.profile.delivered_jobs);
            try std.testing.expectEqual(@as(usize, 256), waiting.parallel.inflight_bytes);
            try std.testing.expectEqualDeep(Z.EncoderControlProfile.Emitted{}, work.emitted());
            var last: [1]u8 = undefined;
            const final_byte = try h.checked(Z, &encoder, opts, input[256..], &last);
            try std.testing.expectEqual(@as(usize, 1), final_byte.progress.output_written);
            try bytes.appendSlice(h.a, &last);
            try std.testing.expectEqual(@as(h.Count, 1), encoder.snapshot().parallel.profile.delivered_jobs);
            try std.testing.expectEqual(@as(u64, 2), work.raw_blocks);
            try h.feed(Z, &encoder, opts, &bytes, input[256 + final_byte.progress.input_read ..], 1, 1);
            encoder.finish();
            try h.drain(Z, &encoder, opts, &bytes, .done, 1);
            _ = try h.verify(Z, bytes.items, &input, opts.frame, null);
        }

        test "Zstd parallel incremental scalar pledge refusal cannot seal a full tentative job" {
            const input = h.fixture(256);
            var opts = h.options(Z);
            opts.frame.include_content_size = true;
            var encoder = try E.initExactSize(h.a, opts, input.len);
            defer encoder.deinit();
            var bytes: std.ArrayList(u8) = .empty;
            defer bytes.deinit(h.a);
            try h.header(Z, &encoder, opts, input.len, &bytes);
            _ = try h.checked(Z, &encoder, opts, &input, &.{});
            var output: [64]u8 = undefined;
            const progress = try h.failed(Z, &encoder, "x", &output, error.SizeMismatch);
            try std.testing.expectEqual(core.Progress{}, progress);
            try std.testing.expect(!encoder.snapshot().parallel.failed);
            try std.testing.expectEqual(@as(h.Count, 0), encoder.snapshot().parallel.profile.encoded_jobs);
            encoder.finish();
            try h.drain(Z, &encoder, opts, &bytes, .done, 1);
            _ = try h.verify(Z, bytes.items, &input, opts.frame, null);
        }

        test "Zstd parallel incremental late HQ resource failures report committed header and accepted bytes" {
            const input = h.fixture(257);
            for ([_]bool{ false, true }) |prices| {
                var opts = h.options(Z);
                opts.frame.strategy = .btopt;
                opts.frame.selection = .auto;
                opts.frame.hq = if (prices) .{ .max_price_evaluations = 0, .match_lengths = .complete } else .{ .max_working_memory = 0 };
                opts.parallel.worker_count = 1;
                opts.parallel.max_inflight_jobs = 1;
                opts.parallel.max_inflight_bytes = 256;
                var encoder = try E.init(h.a, opts);
                defer encoder.deinit();
                var output: [512]u8 = undefined;
                const expected = if (prices) error.SearchLimitExceeded else error.WorkingMemoryLimitExceeded;
                const progress = try h.failed(Z, &encoder, &input, &output, expected);
                try std.testing.expectEqual(@as(usize, 256), progress.input_read);
                try std.testing.expectEqual(h.headerLen(opts.frame, null, 0), progress.output_written);
                try h.sticky(Z, &encoder, expected);
            }
        }

        test "Zstd parallel incremental cumulative input output and skippable limits recover across frames" {
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            opts.max_input_len = 3;
            var encoder = try E.init(h.a, opts);
            defer encoder.deinit();
            const first = try h.drive(Z, &encoder, opts, "abc", 3, 1);
            defer h.a.free(first);
            try encoder.nextFrame(opts);
            var output: [32]u8 = undefined;
            const rejected = try h.failed(Z, &encoder, "x", &output, error.OutputLimitExceeded);
            try std.testing.expectEqual(core.Progress{}, rejected);
            try std.testing.expect(!encoder.snapshot().parallel.failed);
            encoder.options.max_input_len = 4;
            opts.max_input_len = 4;
            const second = try h.drive(Z, &encoder, opts, "x", 1, 1);
            defer h.a.free(second);
            try std.testing.expectEqual(@as(h.Count, 4), encoder.snapshot().input_read);
            try std.testing.expectEqual(@as(h.Count, 2), encoder.snapshot().frame_count);
            const before = encoder.snapshot();
            try encoder.writeSkippable(3, "meta");
            encoder.options.max_output_len = before.output_written + 11;
            var almost: [11]u8 = undefined;
            const partial = try h.checked(Z, &encoder, opts, "", &almost);
            try std.testing.expectEqual(@as(usize, 11), partial.progress.output_written);
            var last: [1]u8 = undefined;
            const limited = try h.failed(Z, &encoder, "", &last, error.OutputLimitExceeded);
            try std.testing.expectEqual(core.Progress{}, limited);
            encoder.options.max_output_len = before.output_written + 12;
            const done = try h.checked(Z, &encoder, opts, "", &last);
            try std.testing.expectEqual(@as(usize, 1), done.progress.output_written);
            // A one-byte output buffer may need the following zero-output call
            // to acknowledge done after delivering its final byte.
            if (done.status != .done) _ = try h.checked(Z, &encoder, opts, "", &.{});
            try std.testing.expectEqual(before.input_read, encoder.snapshot().input_read);
            try std.testing.expectEqual(before.frame_count, encoder.snapshot().frame_count);
            try std.testing.expectEqual(before.output_written + 12, encoder.snapshot().output_written);
            try std.testing.expectEqual(@as(u8, 0x53), almost[0]);
            try std.testing.expectEqualSlices(u8, "met", almost[8..11]);
            try std.testing.expectEqual(@as(u8, 'a'), last[0]);
        }

        test "Zstd parallel incremental cumulative output cap includes the next data frame header" {
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            var encoder = try E.init(h.a, opts);
            defer encoder.deinit();
            const first = try h.drive(Z, &encoder, opts, "one", 3, 1);
            defer h.a.free(first);
            const before = encoder.snapshot();
            opts.max_output_len = before.output_written;
            try encoder.nextFrame(opts);
            var output: [32]u8 = undefined;
            const progress = try h.failed(Z, &encoder, "", &output, error.OutputLimitExceeded);
            try std.testing.expectEqual(core.Progress{}, progress);
            try std.testing.expect(!encoder.snapshot().parallel.failed);
            encoder.options.max_output_len = before.output_written + 128;
            opts.max_output_len = before.output_written + 128;
            const second = try h.drive(Z, &encoder, opts, "two", 3, 1);
            defer h.a.free(second);
            _ = try h.verify(Z, second, "two", opts.frame, null);
            try std.testing.expectEqual(core.stream_count.fromLocal(first.len + second.len), encoder.snapshot().output_written);
            try std.testing.expectEqual(@as(h.Count, 2), encoder.snapshot().frame_count);
        }

        test "Zstd parallel incremental job limit includes accepted partial and mandatory empty final" {
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            opts.max_job_count = 1;
            var encoder = try E.init(h.a, opts);
            defer encoder.deinit();
            var bytes: std.ArrayList(u8) = .empty;
            defer bytes.deinit(h.a);
            try h.feed(Z, &encoder, opts, &bytes, "partial", 7, 1);
            try std.testing.expectEqual(@as(h.Count, 1), encoder.snapshot().parallel.profile.accepted_jobs);
            encoder.flush();
            try h.drain(Z, &encoder, opts, &bytes, .need_input, 1);
            encoder.finish();
            var output: [16]u8 = undefined;
            const progress = try h.failed(Z, &encoder, "", &output, error.OutputLimitExceeded);
            try std.testing.expectEqual(core.Progress{}, progress);
            try std.testing.expect(!encoder.snapshot().parallel.failed);
            encoder.options.max_job_count = 2;
            opts.max_job_count = 2;
            try h.drain(Z, &encoder, opts, &bytes, .done, 1);
            _ = try h.verify(Z, bytes.items, "partial", opts.frame, null);
            try std.testing.expectEqual(@as(h.Count, 2), encoder.snapshot().parallel.profile.accepted_jobs);
        }
    };
}
