const std = @import("std");
const lzma = @import("../../lzma.zig");
const core = @import("../../core.zig");
const contracts = @import("contracts_tests.zig");
const allocator = std.testing.allocator;
const pythonFrame = contracts.pythonFrame;
const python_plain = contracts.python_plain;
const drive = contracts.drive;
const expectComplete = contracts.expectComplete;
const expectSticky = contracts.expectSticky;

test "LZMA stream contracts resources allocation free initialization fixed staging and input overflow" {
    {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
        var decoder = lzma.IncrementalDecoder.init(failing.allocator());
        defer decoder.deinit();
        try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().working_bytes);
        try std.testing.expectEqual(@as(usize, 273), decoder.snapshot().retained_output_capacity);
    }
    {
        var decoder = lzma.IncrementalDecoder.init(allocator);
        defer decoder.deinit();
        decoder.input_read = std.math.maxInt(usize);
        var output: [5]u8 = @splat(0xa5);
        try std.testing.expectError(error.IntegerOverflow, decoder.step(&.{0}, &output));
        try std.testing.expectEqualDeep(core.Progress{}, decoder.snapshot().last_step_progress);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().working_bytes);
        try std.testing.expectEqual(@as([5]u8, @splat(0xa5)), output);
    }
}

test "LZMA stream contracts resources sparse dictionary and exact deterministic working budget" {
    {
        var frame = pythonFrame();
        std.mem.writeInt(u32, frame[1..5], std.math.maxInt(u32), .little);
        var decoder = lzma.IncrementalDecoder.initWithOptions(allocator, .{ .max_working_memory = 64 * 1024 });
        defer decoder.deinit();
        const trace = try drive(&decoder, &frame, python_plain, 1, 7);
        try expectComplete(trace, frame.len, python_plain.len);
        try std.testing.expect(decoder.snapshot().retained_dictionary_capacity < 1024);
        try std.testing.expect(trace.peak < 64 * 1024);
    }
    for ([_]bool{ false, true }) |known_size| {
        var frame = pythonFrame();
        if (known_size) std.mem.writeInt(u64, frame[5..13], python_plain.len, .little);
        const reference = try lzma.decodeAlloc(allocator, &frame);
        defer allocator.free(reference);
        try std.testing.expectEqualSlices(u8, python_plain, reference);
        var storage: [128 * 1024]u8 = undefined;
        var backing = std.heap.FixedBufferAllocator.init(&storage);
        var baseline = lzma.IncrementalDecoder.init(backing.allocator());
        const normal = try drive(&baseline, &frame, python_plain, 1, 7);
        try expectComplete(normal, frame.len, python_plain.len);
        try expectHeapBytes(&baseline);
        baseline.deinit();
        for ([_]bool{ true, false }) |at_limit| {
            backing.reset();
            var decoder = lzma.IncrementalDecoder.initWithOptions(backing.allocator(), .{ .max_working_memory = normal.peak - @intFromBool(!at_limit) });
            defer decoder.deinit();
            const trace = try drive(&decoder, &frame, python_plain, 1, 7);
            if (at_limit) try expectComplete(trace, frame.len, python_plain.len) else try std.testing.expectEqual(@as(?anyerror, error.WorkingMemoryLimitExceeded), trace.failure);
            try expectHeapBytes(&decoder);
        }
    }
}

test "LZMA stream contracts resources budget denial backing OOM and corrupt prefix stay distinct" {
    {
        const frame = pythonFrame();
        var limited = lzma.IncrementalDecoder.initWithOptions(allocator, .{ .max_working_memory = 0 });
        defer limited.deinit();
        const denied = try drive(&limited, &frame, python_plain, frame.len, 17);
        try std.testing.expectEqual(@as(?anyerror, error.WorkingMemoryLimitExceeded), denied.failure);
        try expectSticky(&limited, error.WorkingMemoryLimitExceeded);
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
        var exhausted = lzma.IncrementalDecoder.init(failing.allocator());
        defer exhausted.deinit();
        const oom = try drive(&exhausted, &frame, python_plain, frame.len, 17);
        try std.testing.expectEqual(@as(?anyerror, error.OutOfMemory), oom.failure);
        try expectSticky(&exhausted, error.OutOfMemory);
        var corrupt = frame;
        corrupt[13] = 1;
        var invalid = lzma.IncrementalDecoder.init(allocator);
        defer invalid.deinit();
        const rejected = try drive(&invalid, &corrupt, python_plain, corrupt.len, 17);
        try std.testing.expectEqual(@as(?anyerror, error.InvalidLzmaStream), rejected.failure);
        try std.testing.expectEqual(@as(usize, 0), rejected.output_written);
        try expectSticky(&invalid, error.InvalidLzmaStream);
    }
}

test "LZMA stream contracts resources retained reset and validated void reconfiguration" {
    {
        const frame = pythonFrame();
        var decoder = lzma.IncrementalDecoder.init(allocator);
        defer decoder.deinit();
        try expectComplete(try drive(&decoder, &frame, python_plain, 1, 7), frame.len, python_plain.len);
        const live = decoder.snapshot().working_bytes;
        try expectHeapBytes(&decoder);
        const literal_pointer = decoder.decoder.?.literal_probs.data.ptr;
        decoder.reset();
        try std.testing.expectEqual(live, decoder.snapshot().working_bytes);
        try std.testing.expectEqual(literal_pointer, decoder.decoder.?.literal_probs.data.ptr);
        try std.testing.expect(decoder.snapshot().peak_working_bytes >= live);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().input_read);
        try expectComplete(try drive(&decoder, &frame, python_plain, 3, 13), frame.len, python_plain.len);
        const before_invalid = decoder.snapshot();
        decoder.resetWithOptions(.{ .max_output_len = 1, .expected_output_len = 2 });
        try std.testing.expectEqual(live, decoder.snapshot().working_bytes);
        try std.testing.expectEqual(before_invalid.phase, decoder.snapshot().phase);
        try std.testing.expectEqual(before_invalid.retained_compressed_capacity, decoder.snapshot().retained_compressed_capacity);
        try std.testing.expectEqual(before_invalid.retained_dictionary_capacity, decoder.snapshot().retained_dictionary_capacity);
        try std.testing.expectEqual(literal_pointer, decoder.decoder.?.literal_probs.data.ptr);
        try expectSticky(&decoder, error.InvalidBlockPlan);
        decoder.resetWithOptions(.{ .max_working_memory = 64 * 1024 });
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().working_bytes);
        try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
        try expectComplete(try drive(&decoder, &frame, python_plain, 1, 7), frame.len, python_plain.len);
    }
}

test "LZMA stream contracts resources active move owns pending fixed bytes and every heap" {
    const frame = pythonFrame();
    for ([_]bool{ false, true }) |continue_after_move| {
        var tracking = std.testing.FailingAllocator.init(allocator, .{});
        {
            var original = lzma.IncrementalDecoder.init(tracking.allocator());
            var transferred = false;
            defer if (!transferred) original.deinit();
            var offset: usize = 0;
            var published: usize = 0;
            var output: [1]u8 = undefined;
            var finished = false;
            while (original.snapshot().pending_output == 0) {
                if (offset == frame.len and !finished) {
                    original.finish();
                    finished = true;
                }
                const step = try original.step(frame[offset..], &output);
                offset += step.progress.input_read;
                if (step.progress.output_written != 0) try std.testing.expectEqual(python_plain[published], output[0]);
                published += step.progress.output_written;
            }
            const live = original.workingMemoryBytes();
            try expectHeapBytes(&original);
            try std.testing.expect(original.snapshot().retained_compressed_capacity != 0);
            try std.testing.expect(original.snapshot().retained_dictionary_capacity != 0);
            var moved = original;
            transferred = true;
            original = undefined;
            defer moved.deinit();
            try std.testing.expectEqual(live, moved.workingMemoryBytes());
            if (continue_after_move) try expectComplete(try drive(&moved, frame[offset..], python_plain[published..], 1, 7), frame.len - offset, python_plain.len - published);
            try checkAllocationLedger(&moved, tracking.allocator());
        }
        try std.testing.expectEqual(tracking.allocated_bytes, tracking.freed_bytes);
    }
}

test "LZMA stream contracts resources every allocation and probability replacement balances ownership" {
    {
        const frame = pythonFrame();
        const plain = "different probability dimensions with matched literals\n" ** 32;
        const alternate = try lzma.encodeAlloc(allocator, plain, .{ .properties = .{ .lc = 3, .lp = 1, .pb = 2 } });
        defer allocator.free(alternate);
        try std.testing.checkAllAllocationFailures(allocator, allocationGraph, .{ frame[0..], alternate, plain });
    }
    try exerciseResizeFailureSchedule();
}

fn allocationGraph(failing_allocator: std.mem.Allocator, first: []const u8, alternate: []const u8, alternate_plain: []const u8) !void {
    var owner: ?lzma.IncrementalDecoder = lzma.IncrementalDecoder.init(failing_allocator);
    defer if (owner) |*decoder| decoder.deinit();
    const decoder = &owner.?;
    var trace = try drive(decoder, first, python_plain, 3, 7);
    if (trace.failure) |err| {
        try expectSticky(decoder, err);
        return err;
    }
    try expectComplete(trace, first.len, python_plain.len);
    try checkAllocationLedger(decoder, failing_allocator);
    decoder.reset();
    trace = try drive(decoder, alternate, alternate_plain, 3, 7);
    if (trace.failure) |err| {
        try expectSticky(decoder, err);
        return err;
    }
    try expectComplete(trace, alternate.len, alternate_plain.len);
    try checkAllocationLedger(decoder, failing_allocator);
    decoder.resetWithOptions(.{ .max_working_memory = 1024 * 1024 });
    trace = try drive(decoder, first, python_plain, 1, 7);
    if (trace.failure) |err| {
        try expectSticky(decoder, err);
        return err;
    }
    try expectComplete(trace, first.len, python_plain.len);
    decoder.reset();
    var offset: usize = 0;
    var published: usize = 0;
    var output: [1]u8 = undefined;
    while (decoder.snapshot().pending_output == 0) {
        if (offset == first.len) decoder.finish();
        const stepped = decoder.step(first[offset..], &output) catch |err| {
            try expectSticky(decoder, err);
            return err;
        };
        offset += stepped.progress.input_read;
        if (stepped.progress.output_written != 0) try std.testing.expectEqual(python_plain[published], output[0]);
        published += stepped.progress.output_written;
    }
    var moved = owner.?;
    owner = null;
    defer moved.deinit();
    trace = try drive(&moved, first[offset..], python_plain[published..], 1, 7);
    if (trace.failure) |err| {
        try expectSticky(&moved, err);
        return err;
    }
    try expectComplete(trace, first.len - offset, python_plain.len - published);
    try checkAllocationLedger(&moved, failing_allocator);
}

fn checkAllocationLedger(decoder: *const lzma.IncrementalDecoder, wrapped: std.mem.Allocator) !void {
    const ledger: *std.testing.FailingAllocator = @ptrCast(@alignCast(wrapped.ptr));
    try std.testing.expectEqual(ledger.allocated_bytes - ledger.freed_bytes, decoder.workingMemoryBytes());
    try expectHeapBytes(decoder);
}

fn expectHeapBytes(decoder: *const lzma.IncrementalDecoder) !void {
    const probabilities = if (decoder.decoder) |state| state.literal_probs.data.len * @sizeOf(u16) else @as(usize, 0);
    const bytes = probabilities + decoder.snapshot().retained_dictionary_capacity + decoder.snapshot().retained_compressed_capacity;
    try std.testing.expectEqual(bytes, decoder.workingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 273), decoder.snapshot().retained_output_capacity);
    try std.testing.expect(decoder.peakWorkingMemoryBytes() >= bytes);
}

fn exerciseResizeFailureSchedule() !void {
    const plain = try allocator.alloc(u8, 32 * 1024);
    defer allocator.free(plain);
    var random: u32 = 0x9473_2156;
    for (plain[0..1024]) |*byte| {
        random = random *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(random >> 24);
    }
    for (plain[1024..], 1024..) |*byte, i| byte.* = plain[i % 1024];
    for ([_]lzma.EncodeOptions{ .{ .dictionary_size = 4096, .size_mode = .known }, .{ .dictionary_size = 4096, .size_mode = .end_marker } }) |encode_options| {
        const frame = try lzma.encodeAlloc(allocator, plain, encode_options);
        defer allocator.free(frame);
        const reference = try lzma.decodeAlloc(allocator, frame);
        defer allocator.free(reference);
        try std.testing.expectEqualSlices(u8, plain, reference);
        var baseline_tracker = std.testing.FailingAllocator.init(allocator, .{ .resize_fail_index = 0 });
        var allocations: usize = 0;
        {
            var baseline = lzma.IncrementalDecoder.initWithOptions(baseline_tracker.allocator(), .{ .expected_output_len = plain.len });
            defer baseline.deinit();
            try expectComplete(try drive(&baseline, frame, plain, 23, 11), frame.len, plain.len);
            try checkAllocationLedger(&baseline, baseline_tracker.allocator());
            allocations = baseline_tracker.alloc_index;
        }
        try std.testing.expectEqual(baseline_tracker.allocated_bytes, baseline_tracker.freed_bytes);
        try std.testing.expect(allocations > 3);
        var saw_published_prefix = false;
        for (0..allocations) |fail_index| {
            var tracking = std.testing.FailingAllocator.init(allocator, .{ .fail_index = fail_index, .resize_fail_index = 0 });
            {
                var decoder = lzma.IncrementalDecoder.initWithOptions(tracking.allocator(), .{ .expected_output_len = plain.len });
                defer decoder.deinit();
                const failed = try drive(&decoder, frame, plain, 23, 11);
                try std.testing.expectEqual(@as(?anyerror, error.OutOfMemory), failed.failure);
                saw_published_prefix = saw_published_prefix or failed.output_written != 0;
                try checkAllocationLedger(&decoder, tracking.allocator());
                const attempts = tracking.alloc_index;
                try expectSticky(&decoder, error.OutOfMemory);
                try std.testing.expectEqual(attempts, tracking.alloc_index);
                tracking.fail_index = std.math.maxInt(usize);
                tracking.resize_fail_index = std.math.maxInt(usize);
                const retained_live = decoder.workingMemoryBytes();
                decoder.reset();
                try std.testing.expectEqual(retained_live, decoder.workingMemoryBytes());
                try std.testing.expectEqual(retained_live, decoder.peakWorkingMemoryBytes());
                try expectComplete(try drive(&decoder, frame, plain, 23, 11), frame.len, plain.len);
                try checkAllocationLedger(&decoder, tracking.allocator());
            }
            try std.testing.expectEqual(tracking.allocated_bytes, tracking.freed_bytes);
        }
        try std.testing.expect(saw_published_prefix);
    }
}
