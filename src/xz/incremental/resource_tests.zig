const std = @import("std");
const xz = @import("../../xz.zig");
const core = @import("../../core.zig");
const support = @import("progressive_tests.zig");
const allocator = std.testing.allocator;
const pump = support.pump;
const expectSuccess = support.expectSuccess;
const expectSticky = support.expectSticky;
const policies = [_]xz.IncrementalDecoder.InputPolicy{ .progressive_block, .prevalidated_block };

fn encodedAlloc(payload: []const u8, block_size: usize, filtered: bool) ![]u8 {
    const chain = [_]xz.Filter{ xz.Filter.x86(0), try xz.Filter.delta(4) };
    return xz.encodeAlloc(allocator, payload, .{ .block_size = block_size, .dictionary_size = 4096, .check = .crc64, .filters = if (filtered) &chain else &.{} });
}
fn indexStart(encoded: []const u8) usize {
    const backward = std.mem.readInt(u32, encoded[encoded.len - 8 ..][0..4], .little);
    return encoded.len - 12 - (@as(usize, backward) + 1) * 4;
}

// Observe the child allocator's peak while each filtered/prevalidated block is
// still alive; its temporary reallocations share the decoded-storage budget.
fn decodedPeak(decoder: *xz.IncrementalDecoder, encoded: []const u8, expected: []const u8) !usize {
    var read: usize = 0;
    var written: usize = 0;
    var peak: usize = 0;
    var scratch: [31]u8 = undefined;
    while (true) {
        if (read == encoded.len) decoder.finish();
        if (decoder.progressive) |*block| peak = @max(peak, block.staging_budget.peak);
        const before = decoder.snapshot();
        @memset(&scratch, 0xa5);
        const step = try decoder.step(encoded[read..@min(encoded.len, read + 13)], &scratch);
        read += step.progress.input_read;
        try std.testing.expectEqualSlices(u8, expected[written..][0..step.progress.output_written], scratch[0..step.progress.output_written]);
        written += step.progress.output_written;
        try std.testing.expectEqual(decoder.input_read - before.input_read, step.progress.input_read);
        try std.testing.expectEqual(decoder.output_written - before.output_written, step.progress.output_written);
        if (decoder.progressive) |*block| peak = @max(peak, block.staging_budget.peak);
        if (step.status == .done) break;
    }
    try std.testing.expectEqual(encoded.len, read);
    try std.testing.expectEqual(expected.len, written);
    return peak;
}

test "XZ progressive resources output body dictionary Index and record limits" {
    // Reuses the independently generated fixture and exact/below cases from
    // the split resource draft; coverage now exercises both input policies.
    const frame = support.systemFrame();
    const expected = try support.plainAlloc(65536);
    defer allocator.free(expected);
    const body_len = indexStart(&frame) - 24;
    const metadata_len = frame.len - indexStart(&frame);
    const accepted = [_]xz.IncrementalDecoder.Options{
        .{ .max_output_len = expected.len },
        .{ .max_decoded_block_len = expected.len },
        .{ .max_dictionary_size = 4096 },
        .{ .max_compressed_block_len = body_len },
        .{ .max_index_footer_len = metadata_len },
        .{ .max_block_count = 1 },
    };
    const rejected = [_]xz.IncrementalDecoder.Options{
        .{ .max_output_len = expected.len - 1 },
        .{ .max_decoded_block_len = expected.len - 1 },
        .{ .max_dictionary_size = 4095 },
        .{ .max_compressed_block_len = body_len - 1 },
        .{ .max_index_footer_len = metadata_len - 1 },
        .{ .max_block_count = 0 },
    };
    for (policies) |policy| {
        for (accepted, rejected) |exact_options, below_options| {
            var exact = exact_options;
            exact.input_policy = policy;
            var below = below_options;
            below.input_policy = policy;
            var valid = xz.IncrementalDecoder.initWithOptions(allocator, exact);
            defer valid.deinit();
            try expectSuccess(try pump(&valid, &frame, expected, 1, 17), frame.len, expected.len);
            var limited = xz.IncrementalDecoder.initWithOptions(allocator, below);
            defer limited.deinit();
            const trace = try pump(&limited, &frame, expected, 1, 17);
            try std.testing.expectEqual(@as(?anyerror, error.OutputLimitExceeded), trace.failure);
            try expectSticky(&limited, error.OutputLimitExceeded);
        }
    }
    const multiple = try encodedAlloc(expected[0..32768], 8192, false);
    defer allocator.free(multiple);
    for (policies) |policy| {
        var exact = xz.IncrementalDecoder.initWithOptions(allocator, .{ .input_policy = policy, .max_block_count = 4 });
        defer exact.deinit();
        try expectSuccess(try pump(&exact, multiple, expected[0..32768], 13, 31), multiple.len, 32768);
        var limited = xz.IncrementalDecoder.initWithOptions(allocator, .{ .input_policy = policy, .max_block_count = 3 });
        defer limited.deinit();
        const trace = try pump(&limited, multiple, expected[0..32768], 13, 31);
        try std.testing.expectEqual(@as(?anyerror, error.OutputLimitExceeded), trace.failure);
        try std.testing.expectEqual(@as(usize, 3), limited.block_count);
        try std.testing.expectEqual(@as(usize, 24576), trace.output_written);
    }
}

test "XZ progressive resources combined compressed and working budgets match actual scheduled peaks" {
    const frame = support.systemFrame();
    const expected = try support.plainAlloc(65536);
    defer allocator.free(expected);
    var storage: [512 * 1024]u8 = undefined;
    var backing = std.heap.FixedBufferAllocator.init(&storage);
    for (policies) |policy| {
        backing.reset();
        var baseline = xz.IncrementalDecoder.initWithOptions(backing.allocator(), .{ .input_policy = policy });
        const trace = try pump(&baseline, &frame, expected, 1, 17);
        try expectSuccess(trace, frame.len, expected.len);
        baseline.deinit();
        for ([_]bool{ true, false }) |at_limit| {
            backing.reset();
            var decoder = xz.IncrementalDecoder.initWithOptions(backing.allocator(), .{ .input_policy = policy, .max_working_memory = trace.peak_working_bytes - @intFromBool(!at_limit) });
            defer decoder.deinit();
            const attempted = try pump(&decoder, &frame, expected, 1, 17);
            if (at_limit) try expectSuccess(attempted, frame.len, expected.len) else {
                try std.testing.expectEqual(@as(?anyerror, error.WorkingMemoryLimitExceeded), attempted.failure);
                try expectSticky(&decoder, error.WorkingMemoryLimitExceeded);
            }
        }
        for ([_]bool{ true, false }) |at_limit| {
            var decoder = xz.IncrementalDecoder.initWithOptions(allocator, .{ .input_policy = policy, .max_compressed_buffer_len = trace.max_compressed_capacity - @intFromBool(!at_limit) });
            defer decoder.deinit();
            const attempted = try pump(&decoder, &frame, expected, 1, 17);
            if (at_limit) try expectSuccess(attempted, frame.len, expected.len) else {
                try std.testing.expectEqual(@as(?anyerror, error.OutputLimitExceeded), attempted.failure);
                try expectSticky(&decoder, error.OutputLimitExceeded);
            }
        }
    }
}

test "XZ progressive resources decoded storage includes every child filter and plaintext allocation" {
    const expected = try support.plainAlloc(32768);
    defer allocator.free(expected);
    const encoded = try encodedAlloc(expected, expected.len, true);
    defer allocator.free(encoded);
    for (policies) |policy| {
        var baseline = xz.IncrementalDecoder.initWithOptions(allocator, .{ .input_policy = policy });
        defer baseline.deinit();
        const peak = try decodedPeak(&baseline, encoded, expected);
        try std.testing.expect(peak != 0);
        var exact = xz.IncrementalDecoder.initWithOptions(allocator, .{ .input_policy = policy, .max_decoded_buffer_len = peak });
        defer exact.deinit();
        _ = try decodedPeak(&exact, encoded, expected);
        var below = xz.IncrementalDecoder.initWithOptions(allocator, .{ .input_policy = policy, .max_decoded_buffer_len = peak - 1 });
        defer below.deinit();
        try std.testing.expectError(error.OutputLimitExceeded, decodedPeak(&below, encoded, expected));
        try expectSticky(&below, error.OutputLimitExceeded);
        // A decoded child allocation denial is a storage cap error, even when
        // the independent parent working-memory budget has ample room.
        try std.testing.expectEqualStrings("OutputLimitExceeded", below.snapshot().last_error_name);
        try std.testing.expect(!below.budget.hit_limit);
    }
}

test "XZ progressive resources initialization retained reset and validated void reconfiguration" {
    const expected = try support.plainAlloc(32768);
    defer allocator.free(expected);
    const encoded = try encodedAlloc(expected, expected.len, false);
    defer allocator.free(encoded);
    const empty = try xz.encodeAlloc(allocator, "", .{});
    defer allocator.free(empty);
    for (policies) |policy| {
        var counting = std.testing.FailingAllocator.init(allocator, .{});
        var decoder = xz.IncrementalDecoder.initWithOptions(counting.allocator(), .{ .input_policy = policy });
        var live_decoder = true;
        defer if (live_decoder) decoder.deinit();
        try std.testing.expectEqual(@as(usize, 0), counting.allocations);
        try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
        try expectSuccess(try pump(&decoder, encoded, expected, 13, 31), encoded.len, expected.len);
        const retained = decoder.workingMemoryBytes();
        try std.testing.expect(retained != 0);
        decoder.reset();
        try std.testing.expectEqual(retained, decoder.workingMemoryBytes());
        try std.testing.expectEqual(retained, decoder.peakWorkingMemoryBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.input_read);
        try std.testing.expectEqual(@as(usize, 0), decoder.output_written);
        const old_options = decoder.options;
        const before_invalid = decoder.snapshot();
        const invalid: xz.IncrementalDecoder.Options = .{ .max_output_len = 1, .expected_output_len = 2 };
        try std.testing.expectError(error.InvalidBlockPlan, invalid.validate());
        const allocations_before = counting.allocations;
        decoder.resetWithOptions(invalid);
        try std.testing.expectEqualDeep(old_options, decoder.options);
        try std.testing.expectEqual(before_invalid.phase, decoder.phase);
        try std.testing.expectEqual(before_invalid.input_read, decoder.input_read);
        try std.testing.expectEqual(before_invalid.output_written, decoder.output_written);
        try std.testing.expectEqual(before_invalid.working_bytes, decoder.workingMemoryBytes());
        try std.testing.expectEqual(before_invalid.peak_working_bytes, decoder.peakWorkingMemoryBytes());
        try std.testing.expectEqual(allocations_before, counting.allocations);
        try expectSticky(&decoder, error.InvalidBlockPlan);
        decoder.resetWithOptions(.{ .input_policy = policy, .max_output_len = 0, .max_decoded_buffer_len = 0 });
        try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
        try expectSuccess(try pump(&decoder, empty, "", 1, 17), empty.len, 0);
        decoder.resetWithOptions(.{ .input_policy = policy, .max_decoded_buffer_len = 0 });
        const direct = try pump(&decoder, encoded, expected, 13, 31);
        if (policy == .progressive_block) try expectSuccess(direct, encoded.len, expected.len) else try std.testing.expectEqual(@as(?anyerror, error.OutputLimitExceeded), direct.failure);
        decoder.resetWithOptions(.{ .input_policy = policy });
        decoder.input_read = std.math.maxInt(usize);
        var guard: [7]u8 = @splat(0xa5);
        try std.testing.expectError(error.IntegerOverflow, decoder.step(&.{0}, &guard));
        try std.testing.expectEqualDeep(core.Progress{}, decoder.last_step_progress);
        try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
        try std.testing.expectEqual(@as([7]u8, @splat(0xa5)), guard);
        decoder.deinit();
        live_decoder = false;
        try std.testing.expectEqual(counting.allocated_bytes, counting.freed_bytes);
    }
}

test "XZ progressive resources allocation failures preserve filtered multi block published prefixes and retries" {
    const expected = try support.plainAlloc(32768);
    defer allocator.free(expected);
    const encoded = try encodedAlloc(expected, 8192, true);
    defer allocator.free(encoded);
    for (policies) |policy| {
        var baseline = std.testing.FailingAllocator.init(allocator, .{ .resize_fail_index = 0 });
        {
            var decoder = xz.IncrementalDecoder.initWithOptions(baseline.allocator(), .{ .input_policy = policy });
            defer decoder.deinit();
            try expectSuccess(try pump(&decoder, encoded, expected, 13, 31), encoded.len, expected.len);
        }
        try std.testing.expectEqual(baseline.allocated_bytes, baseline.freed_bytes);
        try std.testing.expect(baseline.allocations > 4 and baseline.allocations < 256);
        var saw_published_prefix = false;
        var saw_prevalidated_hold = false;
        for (0..baseline.allocations) |fail_index| {
            var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = fail_index, .resize_fail_index = 0 });
            var decoder = xz.IncrementalDecoder.initWithOptions(failing.allocator(), .{ .input_policy = policy });
            var live_decoder = true;
            defer if (live_decoder) decoder.deinit();
            try std.testing.expectEqual(@as(usize, 0), failing.allocations);
            const failed = try pump(&decoder, encoded, expected, 13, 31);
            try std.testing.expectEqual(@as(?anyerror, error.OutOfMemory), failed.failure);
            saw_published_prefix = saw_published_prefix or failed.output_written != 0;
            saw_prevalidated_hold = saw_prevalidated_hold or decoder.prevalidated.items.len != 0;
            try std.testing.expect(failing.has_induced_failure);
            const attempts = failing.allocations;
            try expectSticky(&decoder, error.OutOfMemory);
            try std.testing.expectEqual(attempts, failing.allocations);
            failing.fail_index = std.math.maxInt(usize);
            decoder.reset();
            try std.testing.expectEqual(decoder.workingMemoryBytes(), decoder.peakWorkingMemoryBytes());
            try expectSuccess(try pump(&decoder, encoded, expected, 13, 31), encoded.len, expected.len);
            decoder.deinit();
            live_decoder = false;
            try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
        }
        try std.testing.expect(saw_published_prefix);
        if (policy == .prevalidated_block) try std.testing.expect(saw_prevalidated_hold);
    }
}
