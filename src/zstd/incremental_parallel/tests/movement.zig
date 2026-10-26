const std = @import("std");
const core = @import("../../../core.zig");
const types = @import("../types.zig");
const h = @import("helpers.zig");

pub fn run(comptime Z: type) type {
    return struct {
        const E = Z.NativeIncrementalParallelFrameEncoder;

        test "Zstd parallel incremental public value moves with owned jobs and actual active workers" {
            var opts = h.options(Z);
            opts.frame.selection = .auto;
            opts.frame.strategy = .btultra2;
            opts.frame.window_log = 17;
            opts.frame.block_size_max = 32768;
            opts.parallel.job_size = 65536;
            opts.parallel.max_inflight_bytes = 4 * 65536;
            const input = try h.a.alloc(u8, 4 * 65536 + 1);
            defer h.a.free(input);
            const period = "{\"service\":\"vort\",\"message\":\"owned history survives moving the encoder\"}\n";
            for (input, 0..) |*byte, i| byte.* = if (i % 4093 == 0) @truncate(i / 4093) else period[i % period.len];
            var original = try E.init(h.a, opts);
            var original_alive = true;
            defer if (original_alive) original.deinit();
            var bytes: std.ArrayList(u8) = .empty;
            defer bytes.deinit(h.a);
            try h.header(Z, &original, opts, null, &bytes);
            const accepted = try h.checked(Z, &original, opts, input[0 .. 4 * 65536], &.{});
            try std.testing.expectEqual(@as(usize, 4 * 65536), accepted.progress.input_read);
            try std.testing.expect(original.snapshot().parallel.owned_input_bytes != 0);
            if (types.target_supports_parallel) {
                var saw_active = false;
                for (0..100000) |_| {
                    const observed = original.snapshot().parallel;
                    if (observed.active_jobs != 0) {
                        saw_active = true;
                        break;
                    }
                    if (observed.queued_jobs == 0) break;
                    std.Thread.yield() catch {};
                }
                try std.testing.expect(saw_active);
            }
            var moved = original;
            original_alive = false;
            @memset(std.mem.asBytes(&original), 0xa5);
            defer moved.deinit();
            try h.feed(Z, &moved, opts, &bytes, input[accepted.progress.input_read..], 1, 3);
            moved.finish();
            try h.drain(Z, &moved, opts, &bytes, .done, 3);
            const wire = try h.verify(Z, bytes.items, input, opts.frame, null);
            try h.complete(moved.snapshot(), opts, input.len, wire.blocks);
        }

        test "Zstd parallel incremental active reset joins workers and keeps bounded reusable storage" {
            var opts = h.options(Z);
            opts.frame.strategy = .greedy;
            opts.frame.selection = .auto;
            var heap = h.Heap.init(h.a);
            const input = h.fixture(4097);
            var encoder = try E.init(heap.allocator(), opts);
            var alive = true;
            defer if (alive) encoder.deinit();
            var discarded: std.ArrayList(u8) = .empty;
            defer discarded.deinit(h.a);
            try h.header(Z, &encoder, opts, null, &discarded);
            const accepted = try h.checked(Z, &encoder, opts, input[0..1024], &.{});
            try std.testing.expectEqual(@as(usize, 1024), accepted.progress.input_read);
            const before = encoder.snapshot();
            try std.testing.expect(before.parallel.inflight_jobs != 0);
            encoder.reset();
            const reset = encoder.snapshot();
            try std.testing.expectEqual(@as(h.Count, 0), reset.input_read);
            try std.testing.expectEqual(@as(h.Count, 0), reset.output_written);
            try std.testing.expectEqual(@as(h.Count, 0), reset.frame_count);
            try std.testing.expectEqual(@as(usize, 0), reset.parallel.profile.workers_live);
            try std.testing.expectEqual(@as(usize, 0), reset.parallel.inflight_jobs);
            try std.testing.expectEqual(@as(usize, 0), reset.parallel.owned_input_bytes);
            try std.testing.expect(!reset.parallel.failed);
            try std.testing.expect(reset.parallel.retained_input_capacity >= before.parallel.retained_input_capacity);
            try std.testing.expectEqual(heap.live, encoder.memorySnapshot().live_requested_bytes);
            const bytes = try h.drive(Z, &encoder, opts, &input, 17, 1);
            defer h.a.free(bytes);
            _ = try h.verify(Z, bytes, &input, opts.frame, null);
            encoder.deinit();
            alive = false;
            try std.testing.expectEqual(@as(usize, 0), heap.live);
            try std.testing.expectEqual(@as(usize, 0), heap.reentries.load(.monotonic));
        }

        test "Zstd parallel incremental warmed reset allocates nothing and restores captured codec policy" {
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            opts.parallel.worker_count = 1;
            opts.parallel.max_inflight_jobs = 1;
            opts.parallel.max_inflight_bytes = 256;
            var backing = std.testing.FailingAllocator.init(h.a, .{});
            var encoder = try E.init(backing.allocator(), opts);
            defer encoder.deinit();
            const input = h.fixture(273);
            const first = try h.drive(Z, &encoder, opts, &input, 257, 3);
            defer h.a.free(first);
            const allocations = backing.allocations;
            const retained = encoder.memorySnapshot().live_requested_bytes;
            try std.testing.expect(retained != 0);
            encoder.options.max_input_len = 4096;
            encoder.options.max_output_len = 4096;
            encoder.options.max_pending_output_len = 2048;
            encoder.options.max_job_count = 17;
            encoder.options.frame.selection = .literal_only;
            encoder.options.frame.strategy = .btultra2;
            encoder.options.parallel.job_size = 1;
            encoder.reset();
            try std.testing.expectEqual(allocations, backing.allocations);
            try std.testing.expectEqual(@as(h.Count, 4096), encoder.options.max_input_len);
            try std.testing.expectEqual(@as(h.Count, 4096), encoder.options.max_output_len);
            try std.testing.expectEqual(@as(usize, 2048), encoder.options.max_pending_output_len);
            try std.testing.expectEqual(@as(h.Count, 17), encoder.options.max_job_count);
            try std.testing.expectEqual(opts.frame.selection, encoder.options.frame.selection);
            try std.testing.expectEqual(opts.frame.strategy, encoder.options.frame.strategy);
            try std.testing.expectEqual(opts.parallel.job_size, encoder.options.parallel.job_size);
            try std.testing.expectEqual(backing.allocated_bytes - backing.freed_bytes, encoder.memorySnapshot().live_requested_bytes);
            encoder.options.max_job_count = 0;
            var rejected_output: [16]u8 = undefined;
            const rejected = try h.failed(Z, &encoder, "x", &rejected_output, error.InvalidBlockPlan);
            try std.testing.expectEqual(core.Progress{}, rejected);
            try std.testing.expect(!encoder.snapshot().parallel.failed);
            encoder.reset();
            try std.testing.expectEqual(@as(h.Count, 17), encoder.options.max_job_count);
            opts = encoder.options;
            const second = try h.drive(Z, &encoder, opts, &input, 19, 1);
            defer h.a.free(second);
            try std.testing.expectEqualSlices(u8, first, second);
            const before_second_reset = backing.allocations;
            encoder.reset();
            try std.testing.expectEqual(before_second_reset, backing.allocations);
        }

        test "Zstd parallel incremental undersized finish is sticky until allocation free reset" {
            var opts = h.options(Z);
            opts.frame.include_content_size = true;
            opts.frame.selection = .raw_or_rle;
            opts.parallel.worker_count = 1;
            var backing = std.testing.FailingAllocator.init(h.a, .{});
            var encoder = try E.initExactSize(backing.allocator(), opts, 10);
            defer encoder.deinit();
            var discarded: std.ArrayList(u8) = .empty;
            defer discarded.deinit(h.a);
            try h.feed(Z, &encoder, opts, &discarded, "123456789", 9, 3);
            encoder.finish();
            var output: [32]u8 = undefined;
            const failed = try h.failed(Z, &encoder, "", &output, error.SizeMismatch);
            try std.testing.expectEqual(core.Progress{}, failed);
            try h.sticky(Z, &encoder, error.SizeMismatch);
            const allocations = backing.allocations;
            encoder.reset();
            try std.testing.expectEqual(allocations, backing.allocations);
            try std.testing.expect(!encoder.snapshot().parallel.failed);
            try std.testing.expectEqual(@as(?core.Progress, null), encoder.failedProgress());
            const bytes = try h.drive(Z, &encoder, opts, "1234567890", 7, 1);
            defer h.a.free(bytes);
            _ = try h.verify(Z, bytes, "1234567890", opts.frame, null);
        }

        test "Zstd parallel incremental next frame preset and settings reject low retained heap atomically" {
            var opts = h.options(Z);
            opts.frame.include_content_size = true;
            opts.frame.selection = .raw_or_rle;
            const input = h.fixture(73);
            var encoder = try E.initExactSize(h.a, opts, input.len);
            defer encoder.deinit();
            const first = try h.drive(Z, &encoder, opts, &input, 17, 3);
            defer h.a.free(first);
            const dictionary = Z.NativeDictionary.init(0x2468, &input);
            var next = opts;
            next.frame.format = .magicless;
            next.frame.selection = .auto;
            next.frame.strategy = .greedy;
            next.frame.dictionary_id = dictionary.id;
            next.parallel.job_size = 128;
            var low = next;
            low.parallel.max_working_memory = encoder.memorySnapshot().live_requested_bytes - 1;
            const before = encoder.snapshot();
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.nextFrameExactSizeWithPresetDictionary(low, input.len, dictionary));
            try std.testing.expectEqualDeep(before, encoder.snapshot());
            try std.testing.expectEqual(opts.frame.format, encoder.options.frame.format);
            try std.testing.expectEqual(opts.frame.selection, encoder.options.frame.selection);
            try encoder.nextFrameExactSizeWithPresetDictionary(next, input.len, dictionary);
            const second = try h.drive(Z, &encoder, next, &input, 13, 1);
            defer h.a.free(second);
            _ = try h.verify(Z, second, &input, next.frame, dictionary);
            try std.testing.expectEqual(@as(h.Count, 2), encoder.snapshot().frame_count);
            try std.testing.expectEqual(@as(h.Count, 1), encoder.snapshot().frame_index);
            try std.testing.expectEqual(@as(h.Count, 2 * input.len), encoder.snapshot().input_read);
            try std.testing.expectEqual(core.stream_count.fromLocal(first.len + second.len), encoder.snapshot().output_written);
            try std.testing.expectError(error.InvalidBlockPlan, encoder.writeSkippable(0, "magicless"));
            const set = Z.NativeDictionarySet.init(&.{dictionary});
            next.frame.include_content_size = false;
            try encoder.nextFrameWithDictionarySet(next, set, dictionary.id);
            const third = try h.drive(Z, &encoder, next, &input, 19, 3);
            defer h.a.free(third);
            _ = try h.verify(Z, third, &input, next.frame, dictionary);
            try std.testing.expectEqual(@as(h.Count, 3), encoder.snapshot().frame_count);
        }

        test "Zstd parallel incremental metadata only dictionary route validates IDs and preserves raw content" {
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            opts.frame.dictionary_id = 0x7654;
            var encoder = try E.initWithDictionary(h.a, opts, opts.frame.dictionary_id);
            defer encoder.deinit();
            const input = h.fixture(273);
            const bytes = try h.drive(Z, &encoder, opts, &input, 19, 1);
            defer h.a.free(bytes);
            const dictionary = Z.NativeDictionary.init(opts.frame.dictionary_id, &.{});
            _ = try h.verify(Z, bytes, &input, opts.frame, dictionary);
            opts.frame.include_content_size = true;
            try encoder.nextFrameExactSizeWithDictionary(opts, input.len, opts.frame.dictionary_id);
            const exact = try h.drive(Z, &encoder, opts, &input, 17, 1);
            defer h.a.free(exact);
            _ = try h.verify(Z, exact, &input, opts.frame, dictionary);
            opts.frame.include_content_size = false;
            try encoder.nextFrameWithDictionary(opts, opts.frame.dictionary_id);
            const unknown = try h.drive(Z, &encoder, opts, &input, 23, 3);
            defer h.a.free(unknown);
            _ = try h.verify(Z, unknown, &input, opts.frame, dictionary);
            opts.frame.selection = .literal_only;
            try std.testing.expectError(error.InvalidBlockPlan, E.initWithDictionary(h.a, opts, opts.frame.dictionary_id));
            opts.frame.selection = .raw_or_rle;
            opts.frame.dictionary_id = 0;
            try std.testing.expectError(error.NeedDictionary, E.initWithDictionary(h.a, opts, 0));
            const set = Z.NativeDictionarySet.init(&.{});
            try std.testing.expectError(error.NeedDictionary, E.initWithDictionarySet(h.a, opts, set, 0x9876));
        }

        test "Zstd parallel incremental next frame and skippable routes require a drained data frame" {
            var opts = h.options(Z);
            opts.frame.selection = .raw_or_rle;
            var encoder = try E.init(h.a, opts);
            defer encoder.deinit();
            try std.testing.expectError(error.InvalidBlockPlan, encoder.nextFrame(opts));
            try std.testing.expectError(error.InvalidBlockPlan, encoder.writeSkippable(0, "early"));
            var bytes: std.ArrayList(u8) = .empty;
            defer bytes.deinit(h.a);
            try h.feed(Z, &encoder, opts, &bytes, "pending", 7, 1);
            encoder.finish();
            _ = try h.checked(Z, &encoder, opts, "", &.{});
            try std.testing.expect(!encoder.snapshot().done);
            try std.testing.expectError(error.InvalidBlockPlan, encoder.nextFrame(opts));
            try std.testing.expectError(error.InvalidBlockPlan, encoder.writeSkippable(0, "pending"));
            try h.drain(Z, &encoder, opts, &bytes, .done, 1);
            _ = try h.verify(Z, bytes.items, "pending", opts.frame, null);
            try encoder.nextFrame(opts);
        }

        test "Zstd parallel incremental caller profiles stay private between public touchpoints" {
            var work: Z.EncoderControlProfile = .{};
            var profile: types.Profile = .{};
            var opts = h.options(Z);
            opts.frame.strategy = .btopt;
            opts.frame.selection = .auto;
            opts.frame.control_profile = &work;
            opts.parallel.profile = &profile;
            const input = h.fixture(1025);
            var encoder = try E.init(h.a, opts);
            defer encoder.deinit();
            var bytes: std.ArrayList(u8) = .empty;
            defer bytes.deinit(h.a);
            try h.header(Z, &encoder, opts, null, &bytes);
            const accepted = try h.checked(Z, &encoder, opts, input[0..1024], &.{});
            try std.testing.expectEqual(@as(usize, 1024), accepted.progress.input_read);
            const saved_work = work;
            const saved_parallel = profile;
            try std.Io.sleep(std.testing.io, .fromMilliseconds(2), .awake);
            // No snapshots or encoder calls occur during this interval.
            try std.testing.expectEqualDeep(saved_work, work);
            try std.testing.expectEqualDeep(saved_parallel, profile);
            try std.testing.expectEqualDeep(Z.EncoderControlProfile.Emitted{}, work.emitted());
            try h.feed(Z, &encoder, opts, &bytes, input[1024..], 1, 1);
            encoder.finish();
            try h.drain(Z, &encoder, opts, &bytes, .done, 3);
            const wire = try h.verify(Z, bytes.items, &input, opts.frame, null);
            try std.testing.expectEqual(core.stream_count.fromLocal(wire.blocks), profile.delivered_blocks);
            try std.testing.expectEqual(@as(u64, wire.blocks), work.raw_blocks + work.rle_blocks + work.compressed_blocks);
        }
    };
}
