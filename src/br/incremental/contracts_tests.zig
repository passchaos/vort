const std = @import("std");
const br = @import("../../br.zig");
const core = @import("../../core.zig");

fn drain(decoder: anytype, wire: []const u8, output: []u8, input_chunk: usize, output_chunk: usize) !void {
    var read: usize = 0;
    var written: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const step = try decoder.step(wire[read..@min(wire.len, read + input_chunk)], output[written..@min(output.len, written + output_chunk)]);
        try std.testing.expectEqualDeep(step.progress, decoder.snapshot().last_step_progress);
        read += step.progress.input_read;
        written += step.progress.output_written;
        try std.testing.expect(step.status == .done or step.progress.input_read != 0 or step.progress.output_written != 0);
    }
    try decoder.finish();
    try std.testing.expectEqual(wire.len, read);
    try std.testing.expectEqual(output.len, written);
}

fn expectFailedProgress(decoder: anytype, read: br.Counter, written: usize) !void {
    const snap = decoder.snapshot();
    // These fixtures compare one failed call's bounded input prefix with a
    // cumulative counter. Only that local expected progress is narrowed.
    const local_read = try core.stream_count.toLocal(read);
    try std.testing.expectEqualDeep(core.Progress{ .input_read = local_read, .output_written = written }, snap.last_step_progress);
    try std.testing.expectEqual(@as(?br.Counter, snap.total_compressed), snap.error_input_offset);
    try std.testing.expectEqual(@as(?br.Counter, snap.total_output), snap.error_output_offset);
    const diagnostic = decoder.diagnostics();
    try std.testing.expectEqualDeep(snap.last_step_progress, diagnostic.last_step_progress.?);
    try std.testing.expectEqual(snap.error_input_offset, diagnostic.error_input_offset);
    try std.testing.expectEqual(snap.error_output_offset, diagnostic.error_output_offset);
}

test "Brotli stream contracts known unknown bounds zero output and tiny chunks" {
    inline for (.{ "", "x", "small Brotli streaming contracts" }) |payload| {
        const wire = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, payload);
        defer std.testing.allocator.free(wire);
        inline for (.{ false, true }) |known| {
            var decoder = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{
                .expected_compressed_len = if (known) wire.len else null,
                .expected_output_len = payload.len,
                .max_total_output_len = payload.len,
                .max_working_memory = payload.len,
            });
            defer decoder.deinit();
            try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
            const first = try decoder.step(&.{}, &.{});
            try std.testing.expectEqualDeep(core.Progress{}, first.progress);
            var output: [payload.len]u8 = undefined;
            try drain(&decoder, wire, &output, 1, 1);
            try std.testing.expectEqualSlices(u8, payload, &output);
            try std.testing.expectEqual(payload.len, decoder.snapshot().total_output);
            try std.testing.expect(decoder.peakWorkingMemoryBytes() <= payload.len);
        }
    }
    const wire = try br.IncrementalTestSupport.encodeCompressedHello(std.testing.allocator);
    defer std.testing.allocator.free(wire);
    var decoder = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = 5, .max_working_memory = 5 });
    defer decoder.deinit();
    const waiting = try decoder.step(wire, &.{});
    try std.testing.expectEqual(.need_output, waiting.status);
    var output: [5]u8 = undefined;
    try drain(&decoder, wire[waiting.progress.input_read..], &output, 1, 1);
    try std.testing.expectEqualSlices(u8, "hello", &output);
}

test "Brotli stream contracts fatal errors publish consumed output prefix and stay sticky" {
    const payload = "actual output prefix";
    const wire = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, payload);
    defer std.testing.allocator.free(wire);
    const malformed = try std.testing.allocator.alloc(u8, wire.len + 1);
    defer std.testing.allocator.free(malformed);
    @memcpy(malformed[0..wire.len], wire);
    malformed[wire.len] = 0xff;
    inline for (.{ false, true }) |owned| {
        var history: [payload.len]u8 = undefined;
        var decoder = if (owned)
            br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = payload.len })
        else
            br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .expected_output_len = payload.len });
        defer if (owned) decoder.deinit();
        var output: [payload.len + 2]u8 = @splat(0xa5);
        try std.testing.expectError(error.TrailingData, decoder.step(malformed, output[1 .. output.len - 1]));
        try expectFailedProgress(&decoder, wire.len, payload.len);
        try std.testing.expectEqualSlices(u8, payload, output[1 .. output.len - 1]);
        try std.testing.expectEqual(@as(u8, 0xa5), output[0]);
        try std.testing.expectEqual(@as(u8, 0xa5), output[output.len - 1]);
        const failed = decoder.snapshot();
        try std.testing.expectError(error.TrailingData, decoder.step(wire, &output));
        try std.testing.expectEqualDeep(core.Progress{}, decoder.snapshot().last_step_progress);
        try std.testing.expectEqual(failed.total_compressed, decoder.snapshot().total_compressed);
        try std.testing.expectEqual(failed.total_output, decoder.snapshot().total_output);
        try std.testing.expectError(error.TrailingData, decoder.finish());
        decoder.reset();
        try std.testing.expectEqual(@as(?br.Counter, null), decoder.snapshot().error_input_offset);
        try drain(&decoder, wire, output[1 .. output.len - 1], 1, 3);
    }
}

test "Brotli stream contracts payload errors after compressed copies report the same prefix" {
    const wire = try br.IncrementalTestSupport.encodeCompressedAlternatingThenStored(std.testing.allocator, 'x', 'y', 257, " tail");
    defer std.testing.allocator.free(wire);
    inline for (.{ false, true }) |owned| {
        var history: [32]u8 = undefined;
        var decoder = if (owned)
            br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .max_output_len = 257, .max_history_len = 32 })
        else
            br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .max_output_len = 257 });
        defer if (owned) decoder.deinit();
        var output: [263]u8 = @splat(0xa5);
        try std.testing.expectError(error.OutputLimitExceeded, decoder.step(wire, &output));
        const snap = decoder.snapshot();
        try std.testing.expectEqual(@as(usize, 257), snap.total_output);
        try std.testing.expect(snap.total_compressed > 1 and snap.total_compressed < wire.len);
        try expectFailedProgress(&decoder, snap.total_compressed, 257);
        for (output[0..257], 0..) |byte, index| try std.testing.expectEqual("xy"[index & 1], byte);
        for (output[257..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    }
}

test "Brotli stream contracts total output cap survives nextFrame and reset starts independently" {
    const wire = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, "hello");
    defer std.testing.allocator.free(wire);
    inline for (.{ false, true }) |owned| {
        var history: [5]u8 = undefined;
        var decoder = if (owned)
            br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = 5, .max_total_output_len = 9 })
        else
            br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .expected_output_len = 5, .max_total_output_len = 9 });
        defer if (owned) decoder.deinit();
        var output: [5]u8 = undefined;
        try drain(&decoder, wire, &output, 1, 1);
        try decoder.nextFrame(.{ .expected_output_len = 5 });
        try std.testing.expectEqual(@as(usize, 9), decoder.options.max_total_output_len);
        try std.testing.expectError(error.OutputLimitExceeded, decoder.step(wire, &output));
        try std.testing.expectEqual(@as(usize, 5), decoder.snapshot().total_output);
        try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().frame_count);
        decoder.reset();
        try drain(&decoder, wire, &output, 2, 2);
        try std.testing.expectEqual(@as(usize, 5), decoder.snapshot().total_output);
        try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().frame_count);
    }
}

test "Brotli stream contracts memory retained across frames and explicit reconfiguration frees it" {
    const wire = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, "history!");
    defer std.testing.allocator.free(wire);
    var decoder = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = 8, .max_working_memory = 8 });
    defer decoder.deinit();
    var output: [8]u8 = undefined;
    try drain(&decoder, wire, &output, 1, 1);
    try std.testing.expectEqual(@as(usize, 8), decoder.workingMemoryBytes());
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.nextFrame(.{ .max_working_memory = 7 }));
    try std.testing.expectEqual(.done, decoder.snapshot().phase);
    try decoder.nextFrame(.{ .expected_output_len = 16 });
    try std.testing.expectEqual(@as(usize, 8), decoder.options.max_working_memory);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.step(wire, &output));
    try std.testing.expectEqual(@as(usize, 8), decoder.workingMemoryBytes());
    decoder.reset();
    try std.testing.expectEqual(@as(usize, 8), decoder.peakWorkingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().total_output);
    try decoder.resetWithOptions(.{ .max_working_memory = 0 });
    try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.step(wire, &output));
    try expectFailedProgress(&decoder, 1, 0);
    try decoder.resetWithOptions(.{ .expected_output_len = 8, .max_working_memory = 8 });
    try drain(&decoder, wire, &output, 2, 3);
}

test "Brotli stream contracts budget denial and backing allocation failure are distinct" {
    const wire = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, "hello");
    defer std.testing.allocator.free(wire);
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var decoder = br.IncrementalStreamDecoder.initWithOptions(failing.allocator(), .{ .expected_output_len = 5, .max_working_memory = 4 });
    defer decoder.deinit();
    try std.testing.expectEqual(@as(usize, 0), failing.allocations);
    var output: [5]u8 = undefined;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.step(wire, &output));
    try expectFailedProgress(&decoder, 1, 0);
    try decoder.resetWithOptions(.{ .expected_output_len = 5, .max_working_memory = 5 });
    // A historical denial is diagnostic state, not the cause of this failure.
    decoder.budget.hit_limit = true;
    try std.testing.expectError(error.OutOfMemory, decoder.step(wire, &output));
    try expectFailedProgress(&decoder, 1, 0);
    try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
}

test "Brotli stream contracts metadata dictionaries history caps and moved state preserve behavior" {
    const metadata = "contract metadata";
    const wire = try br.IncrementalTestSupport.encodeMetadataThenCompressedHello(std.testing.allocator, metadata);
    defer std.testing.allocator.free(wire);
    var capture: [metadata.len]u8 = undefined;
    var lengths: [1]usize = undefined;
    var source = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = 5,
        .max_working_memory = 5,
        .metadata_output = &capture,
        .metadata_block_lengths = &lengths,
    });
    const first = try source.step(wire[0..1], &.{});
    var decoder = source;
    source = undefined;
    defer decoder.deinit();
    var output: [5]u8 = undefined;
    try drain(&decoder, wire[first.progress.input_read..], &output, 1, 1);
    try std.testing.expectEqualSlices(u8, "hello", &output);
    try std.testing.expectEqualSlices(u8, metadata, &capture);
    try std.testing.expectEqual(metadata.len, lengths[0]);

    const prefix = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const dictionary = br.SharedDictionary{ .raw_prefixes = &.{ prefix[0..21], prefix[21..] } };
    const dict_wire = try br.encodePlannedStreamWithOptionsAlloc(std.testing.allocator, prefix, .{ .shared_dictionary = dictionary });
    defer std.testing.allocator.free(dict_wire);
    const reference = try br.decodeStreamAllocExactSizeWithOptions(std.testing.allocator, dict_wire, prefix.len, .{ .shared_dictionary = dictionary });
    defer std.testing.allocator.free(reference);
    try decoder.resetWithOptions(.{ .expected_output_len = prefix.len, .max_working_memory = 1, .max_history_len = 1, .decode = .{ .shared_dictionary = dictionary } });
    var dict_output: [prefix.len]u8 = undefined;
    try drain(&decoder, dict_wire, &dict_output, 1, 1);
    try std.testing.expectEqualSlices(u8, reference, &dict_output);
    const copy_wire = try br.encodeRepeatedPrefixStreamAlloc(std.testing.allocator, "abcd", 32);
    defer std.testing.allocator.free(copy_wire);
    try decoder.resetWithOptions(.{ .expected_output_len = 128, .max_working_memory = 2, .max_history_len = 2 });
    var copy_output: [128]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, decoder.step(copy_wire, &copy_output));
    try std.testing.expect(decoder.snapshot().last_step_progress.output_written >= 4);
}

test "Brotli stream contracts large headers account replacement peak and retained storage" {
    const wire = try br.IncrementalTestSupport.encodeLargeCompressedHeader(std.testing.allocator);
    defer std.testing.allocator.free(wire);
    var baseline = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = 1 });
    defer baseline.deinit();
    // Model an owned capacity retained from a preceding stream with a tighter
    // header cap. Its replacement must count both old and new heap storage.
    const retained = br.default_incremental_compressed_header_bytes + 1;
    try baseline.compressed_header.ensureTotalCapacityPrecise(baseline.budget.allocator(), retained);
    baseline.compressed_header.items.len = retained;
    var output: [1]u8 = undefined;
    try drain(&baseline, wire, &output, 4096, 1);
    try std.testing.expectEqualSlices(u8, "x", &output);
    const live = baseline.workingMemoryBytes();
    const peak = baseline.peakWorkingMemoryBytes();
    try std.testing.expect(peak > live);
    try std.testing.expectEqual(peak, live + retained);
    var exact = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = 1, .max_working_memory = peak });
    defer exact.deinit();
    try exact.compressed_header.ensureTotalCapacityPrecise(exact.budget.allocator(), retained);
    exact.compressed_header.items.len = retained;
    try drain(&exact, wire, &output, 257, 1);
    try std.testing.expectEqual(peak, exact.peakWorkingMemoryBytes());
    var below = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = 1, .max_working_memory = peak - 1 });
    defer below.deinit();
    try below.compressed_header.ensureTotalCapacityPrecise(below.budget.allocator(), retained);
    below.compressed_header.items.len = retained;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, below.step(wire, &output));
    try std.testing.expect(below.peakWorkingMemoryBytes() < peak);
    try std.testing.expectEqual(@as(usize, 0), below.snapshot().total_output);
    const capacity = baseline.snapshot().owned_compressed_header_capacity;
    try baseline.nextFrame(.{ .expected_output_len = 1 });
    try drain(&baseline, wire, &output, 4096, 1);
    try std.testing.expectEqual(capacity, baseline.snapshot().owned_compressed_header_capacity);
    try std.testing.expectEqual(peak, baseline.peakWorkingMemoryBytes());
    baseline.reset();
    try std.testing.expectEqual(live, baseline.workingMemoryBytes());
    try std.testing.expectEqual(live, baseline.peakWorkingMemoryBytes());
    try baseline.resetWithOptions(.{ .expected_output_len = 1, .max_working_memory = 1, .compressed_header_scratch = try std.testing.allocator.alloc(u8, wire.len) });
    defer std.testing.allocator.free(baseline.options.compressed_header_scratch);
    try drain(&baseline, wire, &output, 4096, 1);
    try std.testing.expectEqual(@as(usize, 1), baseline.peakWorkingMemoryBytes());
}

test "Brotli stream contracts standard and large window resource bounds match reference output" {
    // libbrotli 1.1.0 quality=5 generic lgwin=25; only WBITS differs for 26...30.
    const fixture = [_]u8{
        0x11, 0x59, 0xfc, 0x34, 0x00, 0x10, 0x73, 0x1b, 0xf5, 0x95, 0x74, 0x21,
        0xee, 0xf1, 0x6d, 0x51, 0xb1, 0x08, 0x83, 0x81, 0xac, 0x08, 0x0e, 0x39,
        0x70, 0xf8, 0xbe, 0x25, 0x21, 0x86, 0xc0, 0x81, 0x87, 0x6c, 0x2f, 0xe5,
        0x2a, 0x19, 0xba, 0x2d, 0x35, 0xd8, 0x2f, 0xd2, 0x2f, 0x2e, 0x83, 0x35,
        0x27, 0x32, 0xe0, 0x17, 0x13, 0x00, 0x7c, 0x8f, 0x75, 0xc0, 0xa2, 0x56,
        0x6a, 0xeb, 0x63, 0x52, 0x10,
    };
    const expected = "large window brotli compatibility payload 0123456789\n" ** 64;
    for (25..31) |width| {
        var wire = fixture;
        wire[1] = 0x40 + @as(u8, @intCast(width));
        var decoder = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{
            .expected_output_len = expected.len,
            .max_working_memory = expected.len,
            .decode = .{ .allow_large_window = true },
        });
        defer decoder.deinit();
        var output: [expected.len]u8 = undefined;
        try drain(&decoder, &wire, &output, 1, 3);
        try std.testing.expectEqualSlices(u8, expected, &output);
        try std.testing.expectEqual(expected.len, decoder.peakWorkingMemoryBytes());
        try decoder.resetWithOptions(.{ .expected_output_len = expected.len, .max_working_memory = expected.len });
        try std.testing.expectError(error.CorruptFrame, decoder.step(&wire, &output));
        try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    }
}

test "Brotli stream contracts nextFrame rejects caps below committed output transactionally" {
    const wire = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, "hello");
    defer std.testing.allocator.free(wire);
    inline for (.{ false, true }) |owned| {
        var history: [5]u8 = undefined;
        var decoder = if (owned)
            br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = 5, .max_total_output_len = 10 })
        else
            br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .expected_output_len = 5, .max_total_output_len = 10 });
        defer if (owned) decoder.deinit();
        var output: [5]u8 = undefined;
        try drain(&decoder, wire, &output, 1, 1);
        const before = decoder.snapshot();
        try std.testing.expectError(error.OutputLimitExceeded, decoder.nextFrame(.{ .max_total_output_len = 4 }));
        try std.testing.expectEqualDeep(before, decoder.snapshot());
        try decoder.nextFrame(.{ .expected_output_len = 5, .max_total_output_len = 10 });
        try drain(&decoder, wire, &output, 2, 2);
        try std.testing.expectEqual(@as(usize, 10), decoder.snapshot().total_output);
        try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().frame_count);
    }
}

test "Brotli stream contracts malformed dictionaries and compressed size preflight make no progress" {
    const wire = try br.IncrementalTestSupport.encodeCompressedHello(std.testing.allocator);
    defer std.testing.allocator.free(wire);
    const prefixes: [16][]const u8 = @splat("x");
    var decoder = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{
        .decode = .{ .shared_dictionary = .{ .raw_prefixes = &prefixes } },
    });
    defer decoder.deinit();
    var output: [5]u8 = @splat(0xa5);
    try std.testing.expectError(error.CorruptFrame, decoder.step(wire, &output));
    try expectFailedProgress(&decoder, 0, 0);
    try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    try decoder.resetWithOptions(.{ .expected_compressed_len = wire.len - 1, .expected_output_len = 5 });
    try std.testing.expectError(error.SizeMismatch, decoder.step(wire, &output));
    try expectFailedProgress(&decoder, 0, 0);
    try decoder.resetWithOptions(.{ .max_compressed_len = wire.len - 1, .expected_output_len = 5 });
    try std.testing.expectError(error.OutputLimitExceeded, decoder.step(wire, &output));
    try expectFailedProgress(&decoder, 0, 0);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

test "Brotli stream contracts caller header exhaustion can grow and retry without replay" {
    const wire = try br.IncrementalTestSupport.encodeLargeCompressedHeader(std.testing.allocator);
    defer std.testing.allocator.free(wire);
    var history: [1]u8 = undefined;
    var decoder = br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .expected_output_len = 1 });
    var output: [1]u8 = @splat(0xa5);
    try std.testing.expectError(error.UnsupportedBrotliFeature, decoder.step(wire, &output));
    const failed = decoder.snapshot();
    try std.testing.expectEqual(@as(usize, 0), failed.total_output);
    try std.testing.expectEqualStrings("grow_compressed_header", decoder.diagnostics().recoverability_hint_name);
    try expectFailedProgress(&decoder, failed.total_compressed, 0);
    const scratch = try std.testing.allocator.alloc(u8, wire.len);
    defer std.testing.allocator.free(scratch);
    try decoder.replaceCompressedHeaderScratch(scratch);
    try std.testing.expectEqualStrings("", decoder.snapshot().last_error_name);
    const local_consumed = try core.stream_count.toLocal(failed.total_compressed);
    try drain(&decoder, wire[local_consumed..], &output, 257, 1);
    try std.testing.expectEqualSlices(u8, "x", &output);
    try std.testing.expectEqual(wire.len, decoder.snapshot().total_compressed);
    decoder.resetWithOptions(.{ .expected_output_len = 1 });
    try std.testing.expectError(error.UnsupportedBrotliFeature, decoder.step(wire, &output));
    try std.testing.expectError(error.TruncatedFrame, decoder.finish());
    try std.testing.expectEqualStrings("truncated_input", decoder.diagnostics().recoverability_hint_name);
    try std.testing.expectError(error.TruncatedFrame, decoder.step(wire, &output));
    try std.testing.expectError(error.TruncatedFrame, decoder.replaceCompressedHeaderScratch(scratch));
}

test "Brotli stream contracts moving active parsed copy state keeps owned pointers stable" {
    const wire = try br.encodeRepeatedPrefixStreamAlloc(std.testing.allocator, "abcd", 64);
    defer std.testing.allocator.free(wire);
    inline for (.{ false, true }) |owned| {
        var history: [4]u8 = undefined;
        var source = if (owned)
            br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = 256, .max_history_len = 4, .max_working_memory = 4 })
        else
            br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .expected_output_len = 256 });
        var output: [256]u8 = undefined;
        const first = try source.step(wire, output[0..5]);
        try std.testing.expectEqual(.need_output, first.status);
        var decoder = source;
        source = undefined;
        defer if (owned) decoder.deinit();
        try drain(&decoder, wire[first.progress.input_read..], output[first.progress.output_written..], 1, 1);
        try std.testing.expectEqualSlices(u8, "abcd" ** 64, &output);
    }
}

test "Brotli stream contracts caller header capacity boundaries do not retain payload across retry" {
    const wire = try br.IncrementalTestSupport.encodeLargeCompressedHeader(std.testing.allocator);
    defer std.testing.allocator.free(wire);
    const wide = try std.testing.allocator.alloc(u8, wire.len + 8192);
    defer std.testing.allocator.free(wide);
    @memcpy(wide[0..wire.len], wire);
    @memset(wide[wire.len..], 0xa5);
    const replacement = try std.testing.allocator.alloc(u8, wide.len);
    defer std.testing.allocator.free(replacement);
    var history: [1]u8 = undefined;
    var reference = br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{
        .expected_output_len = 1,
        .compressed_header_scratch = replacement,
        .allow_trailing_data = true,
    });
    const reference_wait = try reference.step(wide, &.{});
    try std.testing.expectEqual(.need_output, reference_wait.status);
    // This fixture has a 21-bit window/meta-block prefix and an eight-bit
    // command with no extra fields. The remaining consumed bits are its header.
    const header_capacity = (reference.stream_bits - 21 - 8 + 7) / 8;
    var output: [1]u8 = undefined;
    const reference_done = try reference.step(wide[reference_wait.progress.input_read..], &output);
    try std.testing.expectEqual(.done, reference_done.status);
    try std.testing.expectEqual(wire.len, reference.snapshot().total_compressed);
    try std.testing.expectEqualSlices(u8, "x", &output);
    var soft_cases: usize = 0;
    var ready_cases: usize = 0;
    for ([_]usize{ header_capacity - 2, header_capacity - 1, header_capacity, header_capacity + 1, header_capacity + 2, header_capacity + 8 }) |capacity| {
        try std.testing.expect(capacity > br.default_incremental_compressed_header_bytes);
        const scratch = try std.testing.allocator.alloc(u8, capacity);
        defer std.testing.allocator.free(scratch);
        var decoder = br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{
            .expected_output_len = 1,
            .compressed_header_scratch = scratch,
            .allow_trailing_data = true,
        });
        output[0] = 0xa5;
        var consumed: usize = 0;
        var grew = false;
        const waiting = decoder.step(wide, &.{}) catch |err| blk: {
            try std.testing.expectEqual(error.UnsupportedBrotliFeature, err);
            try std.testing.expectEqualStrings("grow_compressed_header", decoder.diagnostics().recoverability_hint_name);
            soft_cases += 1;
            grew = true;
            consumed = decoder.snapshot().last_step_progress.input_read;
            try std.testing.expectEqual(consumed, decoder.snapshot().total_compressed);
            try expectFailedProgress(&decoder, consumed, 0);
            try decoder.replaceCompressedHeaderScratch(replacement);
            const empty = try decoder.step(&.{}, &output);
            try std.testing.expectEqual(.need_input, empty.status);
            try std.testing.expectEqualDeep(core.Progress{}, empty.progress);
            try std.testing.expectEqual(consumed, decoder.snapshot().total_compressed);
            break :blk try decoder.step(wide[consumed..], &.{});
        };
        consumed += waiting.progress.input_read;
        ready_cases += @intFromBool(!grew);
        try std.testing.expectEqual(.need_output, waiting.status);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().total_output);
        try std.testing.expectEqual(@as(u8, 0xa5), output[0]);
        // A parsed header can resume through an empty-input output wait, then
        // consume only its actual suffix even when offered a wide trailing span.
        const empty_wait = try decoder.step(&.{}, &.{});
        try std.testing.expectEqual(.need_output, empty_wait.status);
        try std.testing.expectEqualDeep(core.Progress{}, empty_wait.progress);
        const done = try decoder.step(wide[consumed..], &output);
        consumed += done.progress.input_read;
        try std.testing.expectEqual(.done, done.status);
        try std.testing.expectEqualSlices(u8, "x", &output);
        try std.testing.expectEqual(wire.len, consumed);
        try std.testing.expectEqual(consumed, decoder.snapshot().total_compressed);
        try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().total_output);
        try decoder.finish();
    }
    try std.testing.expect(soft_cases != 0 and ready_cases != 0);
}
