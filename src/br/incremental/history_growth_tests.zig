const std = @import("std");
const br = @import("../../br.zig");
const TrackingAllocator = @import("../../tests/br_total_memory_helpers.zig").TrackingAllocator;
const Decoder = br.IncrementalStreamDecoder;
const a = std.testing.allocator;

// Standard WBITS=16, a stored `abcd` block, then a final compressed block
// whose only command inserts zero bytes and copies four at distance four.
// The second block has no literal fallback. Checked with libbrotlidec 1.0.9.
const cross_wire = [_]u8{
    0x30, 0x00, 0x10, 'a',  'b',  'c',  'd',
    0x31, 0x00, 0x00, 0x08, 0x02, 0x2f, 0x04,
    0x89, 0x09,
};
const first_block_end = 7;
const cross_plain = "abcdabcd";

fn drain(decoder: anytype, wire: []const u8, output: []u8) !void {
    var read: usize = 0;
    var written: usize = 0;
    for (0..wire.len + output.len + 1) |_| {
        const step = try decoder.step(wire[read..@min(wire.len, read + 1)], output[written..@min(output.len, written + 2)]);
        read += step.progress.input_read;
        written += step.progress.output_written;
        if (step.status == .done) break;
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0);
    }
    try std.testing.expectEqual(.done, decoder.snapshot().phase);
    try decoder.finish();
    try std.testing.expectEqual(wire.len, read);
    try std.testing.expectEqual(output.len, written);
}

fn expectFailure(decoder: *Decoder, wire: []const u8, err: br.Error, already_read: usize, already_written: usize) !void {
    var output: [16]u8 = @splat(0xa5);
    try std.testing.expectError(err, decoder.step(wire, &output));
    const failed = decoder.snapshot();
    const progress = failed.last_step_progress;
    try std.testing.expect(progress.input_read != 0 and progress.input_read <= wire.len);
    try std.testing.expectEqual(@as(usize, 0), progress.output_written);
    try std.testing.expectEqual(@as(br.Counter, already_read + progress.input_read), failed.total_compressed);
    try std.testing.expectEqual(@as(br.Counter, already_written), failed.total_output);
    try std.testing.expectEqual(@as(?br.Counter, failed.total_compressed), failed.error_input_offset);
    try std.testing.expectEqual(@as(?br.Counter, failed.total_output), failed.error_output_offset);
    try std.testing.expectEqualSlices(u8, &(@as([16]u8, @splat(0xa5))), &output);
    try std.testing.expectError(err, decoder.finish());
}

fn decodeFirstBlock(decoder: *Decoder, output: []u8) !void {
    const step = try decoder.step(cross_wire[0..first_block_end], output);
    try std.testing.expectEqual(.need_input, step.status);
    try std.testing.expectEqual(@as(usize, first_block_end), step.progress.input_read);
    try std.testing.expectEqual(@as(usize, 4), step.progress.output_written);
    try std.testing.expectEqualSlices(u8, "abcd", output[0..4]);
}

test "Brotli owned history growth leaves empty and metadata-only streams allocation-free" {
    for ([_]bool{ false, true }) |large| {
        for ([_][]const u8{ "", "metadata only" }) |metadata| {
            const wire = try br.encodeStoredStreamWithOptionsAlloc(a, "", .{
                .window_bits = if (large) 30 else 16,
                .large_window = large,
                .metadata = metadata,
            });
            defer a.free(wire);
            var ledger = TrackingAllocator.init(a);
            var captured: [13]u8 = @splat(0xa5);
            var lengths: [1]usize = @splat(99);
            var decoder = Decoder.initWithOptions(ledger.allocator(), .{
                .max_history_len = 0,
                .max_working_memory = 0,
                .decode = .{ .allow_large_window = large },
                .metadata_output = captured[0..metadata.len],
                .metadata_block_lengths = &lengths,
            });
            defer decoder.deinit();
            try drain(&decoder, wire, &.{});
            try std.testing.expectEqualSlices(u8, metadata, captured[0..metadata.len]);
            try std.testing.expectEqual(if (metadata.len == 0) @as(usize, 99) else metadata.len, lengths[0]);
            try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().history_capacity);
            try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
            try std.testing.expectEqual(@as(usize, 0), ledger.alloc_attempts);
        }
    }
}

test "Brotli owned history growth admits the first stored body only after its header" {
    const plain = "small body";
    for ([_]bool{ false, true }) |large| {
        const wire = try br.encodeStoredStreamWithOptionsAlloc(a, plain, .{
            .window_bits = if (large) 30 else 16,
            .large_window = large,
        });
        defer a.free(wire);
        var decoder = Decoder.initWithOptions(a, .{
            .max_working_memory = plain.len,
            .decode = .{ .allow_large_window = large },
        });
        defer decoder.deinit();
        // WBITS occupies 1 (standard) or 14 (large) bits; neither prefix
        // contains the full data meta-block header.
        const prefix_end: usize = if (large) 2 else 1;
        const prefix = try decoder.step(wire[0..prefix_end], &.{});
        try std.testing.expectEqual(.need_input, prefix.status);
        try std.testing.expectEqual(prefix_end, prefix.progress.input_read);
        try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
        const body_start = wire.len - plain.len - 1; // byte-aligned body, then final-empty marker
        const header = try decoder.step(wire[prefix_end..body_start], &.{});
        try std.testing.expectEqual(body_start - prefix_end, header.progress.input_read);
        try std.testing.expectEqual(@as(usize, 0), header.progress.output_written);
        try std.testing.expectEqual(plain.len, decoder.snapshot().history_capacity);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().history_bytes);
        var output: [plain.len]u8 = undefined;
        try drain(&decoder, wire[body_start..], &output);
        try std.testing.expectEqualSlices(u8, plain, &output);
        try std.testing.expectEqual(plain.len, decoder.peakWorkingMemoryBytes());
        try decoder.resetWithOptions(.{ .max_working_memory = 0, .decode = .{ .allow_large_window = large } });
        try expectFailure(&decoder, wire, error.WorkingMemoryLimitExceeded, 0, 0);
        try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
        try decoder.resetWithOptions(.{ .max_history_len = 0, .decode = .{ .allow_large_window = large } });
        try expectFailure(&decoder, wire, error.OutputLimitExceeded, 0, 0);
    }
}

test "Brotli owned history growth accounts for moving replacement and preserves cross-block copies" {
    const overlap = 4 + cross_plain.len;
    for ([_]usize{ overlap - 1, overlap }) |limit| {
        var ledger = TrackingAllocator.init(a);
        ledger.force_moving_growth = true;
        var decoder = Decoder.initWithOptions(ledger.allocator(), .{ .max_working_memory = limit });
        defer decoder.deinit();
        var output: [cross_plain.len]u8 = undefined;
        try decodeFirstBlock(&decoder, &output);
        try std.testing.expectEqual(@as(usize, 4), decoder.snapshot().history_capacity);
        if (limit < overlap) {
            try expectFailure(&decoder, cross_wire[first_block_end..], error.WorkingMemoryLimitExceeded, first_block_end, 4);
            try std.testing.expectEqual(@as(usize, 4), ledger.live);
            try std.testing.expectEqual(@as(usize, 4), decoder.peakWorkingMemoryBytes());
            continue;
        }
        try drain(&decoder, cross_wire[first_block_end..], output[4..]);
        try std.testing.expectEqualSlices(u8, cross_plain, &output);
        try std.testing.expectEqual(cross_plain.len, ledger.live);
        try std.testing.expectEqual(overlap, ledger.peak);
        try std.testing.expectEqual(ledger.peak, decoder.peakWorkingMemoryBytes());

        const retained = decoder.snapshot().history_capacity;
        const allocations = ledger.alloc_attempts;
        const before = decoder.snapshot();
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.nextFrame(.{ .max_working_memory = retained - 1 }));
        try std.testing.expectEqualDeep(before, decoder.snapshot());
        try decoder.nextFrame(.{ .max_history_len = 4, .max_working_memory = retained });
        try std.testing.expectEqual(retained, decoder.workingMemoryBytes());
        try drain(&decoder, &cross_wire, &output);
        try std.testing.expectEqualSlices(u8, cross_plain, &output);
        try std.testing.expectEqual(@as(usize, 4), decoder.snapshot().history_bytes);
        try std.testing.expectEqual(@as(br.Counter, 2), decoder.snapshot().frame_count);
        decoder.reset();
        try std.testing.expectEqual(retained, decoder.snapshot().history_capacity);
        try std.testing.expectEqual(retained, decoder.peakWorkingMemoryBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().history_bytes);
        try drain(&decoder, &cross_wire, &output);
        try std.testing.expectEqualSlices(u8, cross_plain, &output);
        try std.testing.expectEqual(allocations, ledger.alloc_attempts);
    }

    // A backing failure, unlike quota refusal, remains OutOfMemory and
    // leaves the first block's history allocated until normal cleanup.
    var ledger = TrackingAllocator.init(a);
    ledger.force_moving_growth = true;
    ledger.fail_alloc_after = 1;
    var decoder = Decoder.initWithOptions(ledger.allocator(), .{ .max_working_memory = overlap });
    defer decoder.deinit();
    var output: [cross_plain.len]u8 = undefined;
    try decodeFirstBlock(&decoder, &output);
    try expectFailure(&decoder, cross_wire[first_block_end..], error.OutOfMemory, first_block_end, 4);
    try std.testing.expectEqual(@as(usize, 4), decoder.workingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 1), ledger.forced_failures);
}

test "Brotli owned history growth respects the advertised window and a smaller caller cap" {
    const plain = "01234567" ** 128;
    const window = (1 << 10) - 16;
    const wire = try br.encodeStoredStreamWithOptionsAlloc(a, plain, .{ .window_bits = 10 });
    defer a.free(wire);
    var decoder = Decoder.initWithOptions(a, .{ .max_working_memory = window });
    defer decoder.deinit();
    var output: [plain.len]u8 = undefined;
    try drain(&decoder, wire, &output);
    try std.testing.expectEqualSlices(u8, plain, &output);
    try std.testing.expectEqual(@as(usize, window), decoder.snapshot().history_capacity);

    try decoder.resetWithOptions(.{ .max_history_len = 3, .max_working_memory = 3 });
    try decodeFirstBlock(&decoder, &output);
    // Distance four still refers to valid earlier stream bytes, but the
    // three-byte capped ring has already wrapped and cannot serve it.
    try expectFailure(&decoder, cross_wire[first_block_end..], error.OutputLimitExceeded, first_block_end, 4);
    try std.testing.expectEqual(@as(usize, 3), decoder.snapshot().history_capacity);
    try std.testing.expectEqual(@as(usize, 3), decoder.peakWorkingMemoryBytes());
}

test "Brotli owned history growth keeps pledged and caller-owned decoding unchanged" {
    var decoder = Decoder.initWithOptions(a, .{
        .expected_output_len = cross_plain.len,
        .max_working_memory = cross_plain.len,
    });
    defer decoder.deinit();
    const prefix = try decoder.step(cross_wire[0..1], &.{});
    try std.testing.expectEqual(.need_input, prefix.status);
    try std.testing.expectEqual(cross_plain.len, decoder.snapshot().history_capacity);
    var output: [cross_plain.len]u8 = undefined;
    try drain(&decoder, cross_wire[1..], &output);
    try std.testing.expectEqualSlices(u8, cross_plain, &output);

    var history: [4]u8 = undefined;
    var caller = br.IncrementalCopyStreamDecoder.init(&history);
    try drain(&caller, &cross_wire, &output);
    try std.testing.expectEqualSlices(u8, cross_plain, &output);
}
