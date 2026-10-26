//! Requested heap, owned publication, aliases, and failure cleanup contracts.
const std = @import("std");
const h = @import("helpers.zig");
const a = h.a;

pub fn run(comptime Z: type) type {
    return struct {
        test "Zstd parallel frame Into and Append publish exact bytes and short output stays untouched" {
            const input = h.structured();
            const options = h.native(Z);
            var profile: Z.ParallelProfile = .{};
            const limits = h.parallel(Z, &profile, 2);
            const expected = try Z.encodeNativeParallelFrameAlloc(a, &input, options, limits);
            defer a.free(expected);
            const output = try a.alloc(u8, expected.len + 16);
            defer a.free(output);
            @memset(output, 0xa5);
            const written = try Z.encodeNativeParallelFrameIntoSlice(a, &input, options, output, limits);
            try std.testing.expectEqual(expected.len, written);
            try std.testing.expectEqualSlices(u8, expected, output[0..written]);
            try h.untouched(output[written..]);
            @memset(output, 0xa5);
            try std.testing.expectError(error.OutputTooSmall, Z.encodeNativeParallelFrameIntoSlice(a, &input, options, output[0 .. expected.len - 1], limits));
            try h.untouched(output);
            var out: std.ArrayList(u8) = .fromOwnedSlice(try a.dupe(u8, "prefix|"));
            defer out.deinit(a);
            const appended = try Z.encodeNativeParallelFrameAppend(a, &out, &input, options, limits);
            try std.testing.expectEqual(expected.len, appended);
            try std.testing.expectEqualStrings("prefix|", out.items[0..7]);
            try std.testing.expectEqualSlices(u8, expected, out.items[7..]);
            const summary = try h.envelope(Z, expected, &input, options, 0);
            try h.complete(Z, profile, input.len, options, limits, summary.blocks);
        }

        test "Zstd parallel frame exact requested quota and native minimum reject one below atomically" {
            const input = h.structured();
            var options = h.native(Z);
            options.selection = .raw_or_rle;
            var profile: Z.ParallelProfile = .{};
            var limits = h.parallel(Z, &profile, 1);
            var output: [4096]u8 = undefined;
            const written = try Z.encodeNativeParallelFrameIntoSlice(a, &input, options, &output, limits);
            const expected = try a.dupe(u8, output[0..written]);
            defer a.free(expected);
            const required = profile.peak_requested_bytes;
            limits.max_working_memory = required;
            try std.testing.expectEqual(written, try Z.encodeNativeParallelFrameIntoSlice(a, &input, options, &output, limits));
            try std.testing.expectEqualSlices(u8, expected, output[0..written]);
            limits.max_working_memory = required - 1;
            @memset(&output, 0xa5);
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, Z.encodeNativeParallelFrameIntoSlice(a, &input, options, &output, limits));
            try h.untouched(&output);
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
            limits.max_working_memory = 64 * 1024 * 1024;
            options.max_total_working_memory = required - 1;
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, Z.encodeNativeParallelFrameIntoSlice(a, &input, options, &output, limits));
            try h.untouched(&output);
        }

        test "Zstd parallel frame Append replacement quota includes new capacity and preserves old ownership" {
            const input = h.structured();
            var options = h.native(Z);
            options.selection = .raw_or_rle;
            var profile: Z.ParallelProfile = .{};
            var limits = h.parallel(Z, &profile, 1);
            var reference: std.ArrayList(u8) = .fromOwnedSlice(try a.dupe(u8, "prefix|"));
            defer reference.deinit(a);
            _ = try Z.encodeNativeParallelFrameAppend(a, &reference, &input, options, limits);
            const required = profile.peak_requested_bytes;
            var out: std.ArrayList(u8) = .fromOwnedSlice(try a.dupe(u8, "prefix|"));
            defer out.deinit(a);
            const pointer = out.items.ptr;
            const capacity = out.capacity;
            limits.max_working_memory = required - 1;
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, Z.encodeNativeParallelFrameAppend(a, &out, &input, options, limits));
            try std.testing.expectEqualStrings("prefix|", out.items);
            try std.testing.expectEqual(pointer, out.items.ptr);
            try std.testing.expectEqual(capacity, out.capacity);
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
            limits.max_working_memory = required;
            try std.testing.expectEqual(reference.items.len - 7, try Z.encodeNativeParallelFrameAppend(a, &out, &input, options, limits));
            try std.testing.expectEqualSlices(u8, reference.items, out.items);
        }

        test "Zstd parallel frame invalid geometry refuses before backing allocation without changing job size" {
            const input = h.structured();
            const options = h.native(Z);
            var profile: Z.ParallelProfile = .{};
            var limits = h.parallel(Z, &profile, 2);
            var backing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
            var output: [64]u8 = @splat(0xa5);
            limits.max_inflight_bytes = 255; // Configured 129 rounds to 256, never to a smaller job.
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, Z.encodeNativeParallelFrameIntoSlice(backing.allocator(), &input, options, &output, limits));
            try std.testing.expect(!backing.has_induced_failure);
            limits.max_inflight_bytes = 512;
            limits.job_size = std.math.maxInt(usize);
            try std.testing.expectError(error.IntegerOverflow, Z.encodedNativeParallelFrameBound(input.len, options, limits));
            limits.job_size = 129;
            limits.worker_count = 0;
            try std.testing.expectError(error.InvalidBlockPlan, Z.encodeNativeParallelFrameIntoSlice(backing.allocator(), &input, options, &output, limits));
            try h.untouched(&output);
            try std.testing.expectEqual(@as(usize, 0), backing.allocated_bytes);
            limits.worker_count = 2;
            limits.max_inflight_bytes = 17;
            const tiny = try Z.encodeNativeParallelFrameAlloc(a, "abcdefghijklmnopq", options, limits);
            defer a.free(tiny);
            try std.testing.expectEqual(@as(usize, 256), profile.effective_job_size);
            try std.testing.expectEqual(@as(usize, 17), profile.peak_inflight_bytes);
            _ = try h.verify(Z, tiny, "abcdefghijklmnopq", options, null);
        }

        test "Zstd parallel frame worker memory and price limits remain errors and roll back emitted profiles" {
            const input = "abcdefghabcdefghXbcdefghYabcdefgh" ** 16;
            for ([_]bool{ false, true }) |prices| {
                var backing = std.testing.FailingAllocator.init(a, .{});
                var profile: Z.ParallelProfile = .{};
                var work: Z.EncoderControlProfile = .{};
                const emitted = work.emitted();
                var options = h.native(Z);
                options.strategy = .btultra2;
                options.control_profile = &work;
                options.hq = if (prices) .{ .max_price_evaluations = 0 } else .{ .max_working_memory = 0 };
                const limits = h.parallel(Z, &profile, 2);
                var out: std.ArrayList(u8) = .fromOwnedSlice(try a.dupe(u8, "prefix|"));
                defer out.deinit(a);
                const pointer = out.items.ptr;
                const capacity = out.capacity;
                try std.testing.expectError(if (prices) error.SearchLimitExceeded else error.WorkingMemoryLimitExceeded, Z.encodeNativeParallelFrameAppend(backing.allocator(), &out, input, options, limits));
                try std.testing.expectEqualStrings("prefix|", out.items);
                try std.testing.expectEqual(pointer, out.items.ptr);
                try std.testing.expectEqual(capacity, out.capacity);
                try std.testing.expectEqualDeep(emitted, work.emitted());
                try std.testing.expectEqual(@as(usize, 0), profile.workers_live);
                try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
                try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
            }
        }

        const AllocationGraph = struct {
            fn check(backing: std.mem.Allocator) !void {
                const input = h.structured();
                var options = h.native(Z);
                options.selection = .raw_or_rle;
                var profile: Z.ParallelProfile = .{};
                const limits = h.parallel(Z, &profile, 1);
                const frame = Z.encodeNativeParallelFrameAlloc(backing, &input, options, limits) catch |err| {
                    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
                    return err;
                };
                defer backing.free(frame);
                const summary = try h.verify(Z, frame, &input, options, null);
                try h.complete(Z, profile, input.len, options, limits, summary.blocks);
            }
        };

        test "Zstd parallel frame exhaustive allocation failures release every staged and owned allocation" {
            try std.testing.checkAllAllocationFailures(a, AllocationGraph.check, .{});
        }

        test "Zstd parallel frame unsafe backing is serialized and caller frees the only surviving frame" {
            var heap = h.Heap.init(a);
            const input = h.structured();
            var options = h.native(Z);
            options.strategy = .greedy;
            var profile: Z.ParallelProfile = .{};
            const limits = h.parallel(Z, &profile, 2);
            const frame = try Z.encodeNativeParallelFrameAlloc(heap.allocator(), &input, options, limits);
            var owned = true;
            defer if (owned) heap.allocator().free(frame);
            try std.testing.expectEqual(frame.len, heap.live);
            try std.testing.expectEqual(@as(usize, 0), heap.reentries.load(.monotonic));
            try std.testing.expect(heap.calls > 10);
            const summary = try h.verify(Z, frame, &input, options, null);
            try h.complete(Z, profile, input.len, options, limits, summary.blocks);
            heap.allocator().free(frame);
            owned = false;
            try std.testing.expectEqual(@as(usize, 0), heap.live);
        }

        test "Zstd parallel frame input and dictionary aliases survive moving Append and overlapping Into" {
            const input = h.structured();
            var profile: Z.ParallelProfile = .{};
            const limits = h.parallel(Z, &profile, 2);
            const options = h.native(Z);
            var out: std.ArrayList(u8) = .fromOwnedSlice(try a.dupe(u8, &input));
            defer out.deinit(a);
            const original_len = out.items.len;
            const appended = try Z.encodeNativeParallelFrameAppend(a, &out, out.items, options, limits);
            try std.testing.expectEqualSlices(u8, &input, out.items[0..original_len]);
            _ = try h.verify(Z, out.items[original_len..][0..appended], &input, options, null);
            var dictionary_bytes: [256]u8 = undefined;
            h.noise(&dictionary_bytes, 0x27154);
            var plain: [512]u8 = undefined;
            @memcpy(plain[0..256], &dictionary_bytes);
            @memcpy(plain[256..], &dictionary_bytes);
            const immutable = Z.NativeDictionary.init(0x4521, &dictionary_bytes);
            const original = try a.alloc(u8, dictionary_bytes.len + plain.len);
            @memcpy(original[0..dictionary_bytes.len], &dictionary_bytes);
            @memcpy(original[dictionary_bytes.len..], &plain);
            var aliased: std.ArrayList(u8) = .fromOwnedSlice(original);
            defer aliased.deinit(a);
            const dictionary = Z.NativeDictionary.init(immutable.id, aliased.items[0..256]);
            const set = Z.NativeDictionarySet.init(&.{dictionary});
            const before = aliased.items.len;
            const size = try Z.encodeNativeParallelFrameAppendWithDictionarySet(a, &aliased, aliased.items[256..], options, set, dictionary.id, limits);
            _ = try h.verify(Z, aliased.items[before..][0..size], &plain, options, immutable);
            var holder: [4096]u8 = @splat(0xa5);
            @memcpy(holder[0..256], &dictionary_bytes);
            @memcpy(holder[256..768], &plain);
            const old_holder = holder;
            const overlapping = Z.NativeDictionary.init(immutable.id, holder[0..256]);
            const written = try Z.encodeNativeParallelFrameIntoSliceWithDictionary(a, holder[256..768], options, overlapping, &holder, limits);
            _ = try h.verify(Z, holder[0..written], &plain, options, immutable);
            try std.testing.expectEqualSlices(u8, old_holder[written..], holder[written..]);
            const ordinary = try Z.encodeNativeParallelFrameWithDictionaryAlloc(a, &plain, options, immutable, limits);
            defer a.free(ordinary);
            var direct: std.ArrayList(u8) = .empty;
            defer direct.deinit(a);
            const direct_size = try Z.encodeNativeParallelFrameAppendWithDictionary(a, &direct, &plain, options, immutable, limits);
            try std.testing.expectEqual(ordinary.len, direct_size);
            try std.testing.expectEqualSlices(u8, ordinary, direct.items);
            var target: [4096]u8 = undefined;
            const catalog = Z.NativeDictionarySet.init(&.{immutable});
            const selected = try Z.encodeNativeParallelFrameIntoSliceWithDictionarySet(a, &plain, options, catalog, immutable.id, &target, limits);
            try std.testing.expectEqualSlices(u8, ordinary, target[0..selected]);
            try std.testing.expectError(error.NeedDictionary, Z.encodedNativeParallelFrameBoundWithDictionarySet(plain.len, options, catalog, 0xffff, limits));
        }
    };
}
