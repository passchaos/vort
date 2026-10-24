const std = @import("std");
const bzip2 = @import("../../bzip2.zig");
const core = @import("../../core.zig");
const fixtures = @import("../incremental_tests.zig");

// Python 3 bz2.compress(b"R" * (8 * 1024 * 1024), compresslevel=9).
// Python bz2.decompress verified the complete output; compressed SHA-256:
// 45f0027f968e827d1eb0362e720aa76a9d378eb4d8739a0384b2739402504cc0.
const large_rle_hex = "425a683931415926535927a313680040400280900000040008200030cc0529a60100d8808078bb9229c284813d189b40";
const large_rle_len = 8 * 1024 * 1024;
const empty_hex = "425a683117724538509000000000";
// A legal single-symbol entropy block reconstructs four 'A' bytes by RUNB,
// RUNA, EOB. It deliberately omits RLE1's fifth count byte. Python bz2 rejects
// this fixed stream with OSError("Invalid data stream").
const missing_count_hex = "425a68313141592653590000000000000004002000200020a02898bb9229c2848000000000";

fn wireFromHex(comptime encoded: []const u8) [encoded.len / 2]u8 {
    var bytes: [encoded.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, encoded) catch unreachable;
    return bytes;
}

const Expected = union(enum) {
    bytes: []const u8,
    repeated: struct { byte: u8, len: usize },
    independent_pattern: usize,
    prefixed_pattern: struct { prefix: []const u8, len: usize },

    fn check(self: Expected, offset: usize, bytes: []const u8) !void {
        switch (self) {
            .bytes => |expected| {
                try std.testing.expect(offset <= expected.len and bytes.len <= expected.len - offset);
                try std.testing.expectEqualSlices(u8, expected[offset..][0..bytes.len], bytes);
            },
            .repeated => |expected| {
                try std.testing.expect(offset <= expected.len and bytes.len <= expected.len - offset);
                for (bytes) |byte| try std.testing.expectEqual(expected.byte, byte);
            },
            .independent_pattern => |len| {
                try std.testing.expect(offset <= len and bytes.len <= len - offset);
                for (bytes, offset..) |byte, index| try std.testing.expectEqual(@as(u8, @truncate(index *% 73 +% index / 251)), byte);
            },
            .prefixed_pattern => |expected| {
                const len = expected.prefix.len + expected.len;
                try std.testing.expect(offset <= len and bytes.len <= len - offset);
                for (bytes, offset..) |byte, index| {
                    const actual = if (index < expected.prefix.len) expected.prefix[index] else blk: {
                        const pattern_index = index - expected.prefix.len;
                        break :blk @as(u8, @truncate(pattern_index *% 73 +% pattern_index / 251));
                    };
                    try std.testing.expectEqual(actual, byte);
                }
            },
        }
    }
};

fn expectMemory(decoder: *const bzip2.IncrementalDecoder) !void {
    const snap = decoder.snapshot();
    const owned = snap.retained_compressed_capacity + snap.retained_transformed_capacity + snap.retained_links_capacity;
    try std.testing.expectEqual(@as(usize, 0), snap.retained_decoded_capacity);
    try std.testing.expectEqual(owned, snap.working_bytes);
    try std.testing.expectEqual(snap.working_bytes, decoder.workingMemoryBytes());
    try std.testing.expectEqual(snap.peak_working_bytes, decoder.peakWorkingMemoryBytes());
    try std.testing.expect(snap.peak_working_bytes >= snap.working_bytes);
    try std.testing.expect(snap.peak_working_bytes <= decoder.options.max_working_memory);
}

/// Checks actual accepted/published deltas on success and failure. Large output
/// is verified in a fixed 16 KiB caller buffer, without plaintext allocation.
const Driver = struct {
    read: usize = 0,
    written: usize = 0,

    fn step(self: *Driver, decoder: *bzip2.IncrementalDecoder, input: []const u8, expected: Expected, output_len: usize) !core.StepResult {
        var guarded: [16 * 1024 + 2]u8 = @splat(0xa5);
        const before = decoder.snapshot();
        const stepped = decoder.step(input, guarded[1..][0..output_len]) catch |err| {
            const snap = decoder.snapshot();
            const progress = snap.last_step_progress;
            try self.accept(decoder, input.len, expected, guarded[1..][0..output_len], before, progress);
            try std.testing.expectEqual(@as(?usize, snap.input_read), snap.error_input_offset);
            try std.testing.expectEqual(@as(?usize, snap.output_written), snap.error_output_offset);
            const diagnostic = decoder.diagnostics();
            try std.testing.expectEqualDeep(progress, diagnostic.last_step_progress.?);
            try std.testing.expectEqual(core.stream_count.fromOptionalLocal(snap.error_input_offset), diagnostic.error_input_offset);
            try std.testing.expectEqual(core.stream_count.fromOptionalLocal(snap.error_output_offset), diagnostic.error_output_offset);
            try std.testing.expectEqual(@as(u8, 0xa5), guarded[0]);
            try std.testing.expectEqual(@as(u8, 0xa5), guarded[output_len + 1]);
            return err;
        };
        try std.testing.expectEqualDeep(stepped.progress, decoder.snapshot().last_step_progress);
        try self.accept(decoder, input.len, expected, guarded[1..][0..output_len], before, stepped.progress);
        try std.testing.expectEqual(@as(u8, 0xa5), guarded[0]);
        try std.testing.expectEqual(@as(u8, 0xa5), guarded[output_len + 1]);
        return stepped;
    }

    fn accept(self: *Driver, decoder: *const bzip2.IncrementalDecoder, offered: usize, expected: Expected, output: []const u8, before: bzip2.IncrementalDecoder.Snapshot, progress: core.Progress) !void {
        const after = decoder.snapshot();
        try std.testing.expect(progress.input_read <= offered and progress.output_written <= output.len);
        try std.testing.expectEqual(after.input_read - before.input_read, progress.input_read);
        try std.testing.expectEqual(after.output_written - before.output_written, progress.output_written);
        try expected.check(self.written, output[0..progress.output_written]);
        self.read += progress.input_read;
        self.written += progress.output_written;
        try std.testing.expectEqual(self.read, after.input_read);
        try std.testing.expectEqual(self.written, after.output_written);
        try expectMemory(decoder);
    }

    fn drain(self: *Driver, decoder: *bzip2.IncrementalDecoder, source: []const u8, expected: Expected, input_chunk: usize, output_chunk: usize) !void {
        var idle: usize = 0;
        while (decoder.snapshot().phase != .done) {
            if (self.read == source.len) decoder.finish();
            const end = @min(source.len, self.read + input_chunk);
            const result = try self.step(decoder, source[self.read..end], expected, output_chunk);
            if (result.progress.input_read == 0 and result.progress.output_written == 0) idle += 1 else idle = 0;
            try std.testing.expect(idle <= 2);
        }
    }
};

fn expectSticky(decoder: *bzip2.IncrementalDecoder, err: anyerror) !void {
    const before = decoder.snapshot();
    var output: [8]u8 = @splat(0xa5);
    try std.testing.expectError(err, decoder.step("new input", &output));
    const after = decoder.snapshot();
    try std.testing.expectEqualDeep(core.Progress{}, after.last_step_progress);
    try std.testing.expectEqual(before.input_read, after.input_read);
    try std.testing.expectEqual(before.output_written, after.output_written);
    try std.testing.expectEqual(before.error_input_offset, after.error_input_offset);
    try std.testing.expectEqual(before.error_output_offset, after.error_output_offset);
    try std.testing.expectEqualSlices(u8, &(@as([8]u8, @splat(0xa5))), &output);
    decoder.finish();
    try std.testing.expectError(err, decoder.step(&.{}, &output));
}

fn flipBit(bytes: []u8, bit: usize) void {
    bytes[bit / 8] ^= @as(u8, 1) << @as(u3, @intCast(7 - bit % 8));
}

test "Bzip2 stream contracts eight MiB RLE block replays within two MiB heap" {
    const wire = wireFromHex(large_rle_hex);
    var decoder = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = large_rle_len,
        .max_output_len = large_rle_len,
        .max_decoded_block_len = large_rle_len,
        .max_working_memory = 2 * 1024 * 1024,
    });
    defer decoder.deinit();
    try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
    var driver: Driver = .{};
    _ = try driver.step(&decoder, &wire, .{ .repeated = .{ .byte = 'R', .len = large_rle_len } }, 0);
    decoder.finish();
    const blocked = try driver.step(&decoder, &.{}, .{ .repeated = .{ .byte = 'R', .len = large_rle_len } }, 0);
    try std.testing.expectEqual(.need_output, blocked.status);
    try std.testing.expectEqual(large_rle_len, decoder.snapshot().pending_output);
    try std.testing.expectEqual(large_rle_len, decoder.snapshot().validated_output);
    try std.testing.expect(decoder.snapshot().retained_transformed_capacity <= 900_000);
    try std.testing.expect(decoder.snapshot().retained_links_capacity < 900_000);
    try driver.drain(&decoder, &wire, .{ .repeated = .{ .byte = 'R', .len = large_rle_len } }, wire.len, 16 * 1024);
    try std.testing.expectEqual(large_rle_len, driver.written);
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().block_count);
    try std.testing.expect(decoder.peakWorkingMemoryBytes() < large_rle_len / 4);
}

test "Bzip2 stream contracts known independent patterns randomized and empty streams" {
    const multi = fixtures.independentMultiFrame();
    const randomized = fixtures.randomizedFrame();
    const empty = wireFromHex(empty_hex);
    const cases = [_]struct { wire: []const u8, expected: Expected, output_len: usize }{
        .{ .wire = &multi, .expected = .{ .independent_pattern = 100_321 }, .output_len = 100_321 },
        .{ .wire = &randomized, .expected = .{ .bytes = fixtures.randomized_payload }, .output_len = fixtures.randomized_payload.len },
        .{ .wire = &empty, .expected = .{ .bytes = "" }, .output_len = 0 },
    };
    for (cases) |case| {
        var decoder = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = case.output_len, .max_working_memory = 2 * 1024 * 1024 });
        defer decoder.deinit();
        var driver: Driver = .{};
        try driver.drain(&decoder, case.wire, case.expected, 11, 17);
        try std.testing.expectEqual(case.output_len, driver.written);
        try std.testing.expectEqual(case.wire.len, driver.read);
        try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().stream_count);
    }
}

test "Bzip2 stream contracts block CRC rejects current output and preserves earlier block prefix" {
    const good = fixtures.independentMultiFrame();
    // Marker/CRC offsets were located independently in Python's bitstream.
    // Python BZ2Decompressor publishes 99,981 bytes before block 2 CRC fails.
    for ([_]struct { bit: usize, prefix: usize }{ .{ .bit = 32 + 48, .prefix = 0 }, .{ .bit = 8662 + 48, .prefix = 99_981 } }) |case| {
        var bad = good;
        flipBit(&bad, case.bit);
        var decoder = bzip2.IncrementalDecoder.init(std.testing.allocator);
        defer decoder.deinit();
        var driver: Driver = .{};
        try std.testing.expectError(error.ChecksumMismatch, driver.drain(&decoder, &bad, .{ .independent_pattern = 100_321 }, bad.len, 16 * 1024));
        try std.testing.expectEqual(case.prefix, driver.written);
        try std.testing.expectEqual(case.prefix, decoder.snapshot().validated_output);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().pending_output);
        try expectSticky(&decoder, error.ChecksumMismatch);
    }
}

test "Bzip2 stream contracts combined CRC failure retains all published plaintext" {
    var bad = fixtures.independentMultiFrame();
    flipBit(&bad, 12518 + 48);
    var decoder = bzip2.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    var driver: Driver = .{};
    try std.testing.expectError(error.ChecksumMismatch, driver.drain(&decoder, &bad, .{ .independent_pattern = 100_321 }, bad.len, 16 * 1024));
    try std.testing.expectEqual(@as(usize, 100_321), driver.written);
    try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().block_count);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().stream_count);
    try expectSticky(&decoder, error.ChecksumMismatch);
}

test "Bzip2 stream contracts missing terminal RLE count is malformed before output" {
    const bad = wireFromHex(missing_count_hex);
    var decoder = bzip2.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    var driver: Driver = .{};
    try std.testing.expectError(error.InvalidBzip2Stream, driver.drain(&decoder, &bad, .{ .bytes = "" }, bad.len, 17));
    try std.testing.expectEqual(@as(usize, 0), driver.written);
    try expectSticky(&decoder, error.InvalidBzip2Stream);
}

test "Bzip2 stream contracts output block and compressed quotas have exact boundaries" {
    const wire = fixtures.pythonFrame();
    for ([_]bzip2.IncrementalDecoder.Options{
        .{ .max_output_len = fixtures.python_payload.len },
        .{ .max_decoded_block_len = fixtures.python_payload.len },
        .{ .expected_output_len = fixtures.python_payload.len },
    }) |options| {
        var decoder = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, options);
        defer decoder.deinit();
        var driver: Driver = .{};
        try driver.drain(&decoder, &wire, .{ .bytes = fixtures.python_payload }, 7, 13);
    }
    for ([_]bzip2.IncrementalDecoder.Options{
        .{ .max_output_len = fixtures.python_payload.len - 1 },
        .{ .max_decoded_block_len = fixtures.python_payload.len - 1 },
    }) |options| {
        var decoder = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, options);
        defer decoder.deinit();
        var driver: Driver = .{};
        try std.testing.expectError(error.OutputLimitExceeded, driver.drain(&decoder, &wire, .{ .bytes = fixtures.python_payload }, wire.len, 13));
        try std.testing.expectEqual(@as(usize, 0), driver.written);
        try expectSticky(&decoder, error.OutputLimitExceeded);
    }
    const empty = wireFromHex(empty_hex);
    inline for (.{ 10, 9 }) |cap| {
        var decoder = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{ .max_compressed_block_len = cap });
        defer decoder.deinit();
        var driver: Driver = .{};
        if (cap == 10) try driver.drain(&decoder, &empty, .{ .bytes = "" }, empty.len, 1) else {
            try std.testing.expectError(error.OutputLimitExceeded, driver.drain(&decoder, &empty, .{ .bytes = "" }, empty.len, 1));
            try expectSticky(&decoder, error.OutputLimitExceeded);
        }
    }
}

test "Bzip2 stream contracts working heap exact below retained reset and explicit release" {
    const wire = fixtures.pythonFrame();
    var baseline = bzip2.IncrementalDecoder.init(std.testing.allocator);
    defer baseline.deinit();
    var driver: Driver = .{};
    try driver.drain(&baseline, &wire, .{ .bytes = fixtures.python_payload }, wire.len, 17);
    const peak = baseline.peakWorkingMemoryBytes();
    const live = baseline.workingMemoryBytes();
    try std.testing.expect(peak >= live and live >= fixtures.python_payload.len * @sizeOf(u32));
    inline for (.{ false, true }) |below| {
        var decoder = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{ .max_working_memory = peak - @intFromBool(below) });
        defer decoder.deinit();
        var current: Driver = .{};
        if (below) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, current.drain(&decoder, &wire, .{ .bytes = fixtures.python_payload }, wire.len, 17));
            try expectSticky(&decoder, error.WorkingMemoryLimitExceeded);
        } else {
            try current.drain(&decoder, &wire, .{ .bytes = fixtures.python_payload }, wire.len, 17);
            try std.testing.expectEqual(peak, decoder.peakWorkingMemoryBytes());
        }
    }
    baseline.reset();
    try std.testing.expectEqual(live, baseline.workingMemoryBytes());
    try std.testing.expectEqual(live, baseline.peakWorkingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), baseline.snapshot().input_read);
    try std.testing.expectEqual(@as(usize, 0), baseline.snapshot().output_written);
    driver = .{};
    try driver.drain(&baseline, &wire, .{ .bytes = fixtures.python_payload }, 1, 7);
    try std.testing.expectEqual(live, baseline.peakWorkingMemoryBytes());
    baseline.resetWithOptions(.{ .max_working_memory = 0 });
    try std.testing.expectEqual(@as(usize, 0), baseline.workingMemoryBytes());
    driver = .{};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, driver.drain(&baseline, &wire, .{ .bytes = fixtures.python_payload }, wire.len, 17));
    try std.testing.expectEqual(@as(usize, 4), driver.read);
    baseline.resetWithOptions(.{});
    driver = .{};
    try driver.drain(&baseline, &wire, .{ .bytes = fixtures.python_payload }, 1, 7);
}

test "Bzip2 stream contracts every baseline allocation failure releases heap and reset recovers" {
    const wire = fixtures.pythonFrame();
    const AllocationCase = struct {
        fn run(allocator: std.mem.Allocator, source: []const u8) !void {
            var decoder = bzip2.IncrementalDecoder.init(allocator);
            defer decoder.deinit();
            var driver: Driver = .{};
            try driver.drain(&decoder, source, .{ .bytes = fixtures.python_payload }, source.len, 17);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, AllocationCase.run, .{wire[0..]});
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    {
        var decoder = bzip2.IncrementalDecoder.init(failing.allocator());
        defer decoder.deinit();
        try std.testing.expectEqual(@as(usize, 0), failing.allocations);
        var driver: Driver = .{};
        try std.testing.expectError(error.OutOfMemory, driver.drain(&decoder, &wire, .{ .bytes = fixtures.python_payload }, wire.len, 17));
        try expectSticky(&decoder, error.OutOfMemory);
        const retained = decoder.workingMemoryBytes();
        failing.fail_index = std.math.maxInt(usize);
        decoder.reset();
        try std.testing.expectEqual(retained, decoder.workingMemoryBytes());
        try std.testing.expectEqual(retained, decoder.peakWorkingMemoryBytes());
        driver = .{};
        try driver.drain(&decoder, &wire, .{ .bytes = fixtures.python_payload }, 1, 7);
    }
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

test "Bzip2 stream contracts moving active randomized cursor preserves caller progress" {
    const wire = fixtures.randomizedFrame();
    var source = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = fixtures.randomized_payload.len });
    var driver: Driver = .{};
    _ = try driver.step(&source, &wire, .{ .bytes = fixtures.randomized_payload }, 0);
    source.finish();
    const first = try driver.step(&source, &.{}, .{ .bytes = fixtures.randomized_payload }, 1);
    try std.testing.expectEqual(.need_output, first.status);
    try std.testing.expectEqual(@as(usize, 1), driver.written);
    try std.testing.expectEqual(fixtures.randomized_payload.len - 1, source.snapshot().pending_output);
    var decoder = source;
    source = undefined;
    defer decoder.deinit();
    try driver.drain(&decoder, &wire, .{ .bytes = fixtures.randomized_payload }, 1, 7);
    try std.testing.expectEqual(fixtures.randomized_payload.len, driver.written);
}

test "Bzip2 stream contracts nextStream retains suffix and cumulative output quota" {
    const frame = fixtures.pythonFrame();
    const suffix = "outer footer and next format";
    const source = frame ++ frame ++ suffix.*;
    const expected = fixtures.python_payload ++ fixtures.python_payload;
    var decoder = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .stop_after_first_stream = true,
        .first_stream_retry_granularity = 12,
        .max_output_len = expected.len,
        .expected_output_len = expected.len,
    });
    defer decoder.deinit();
    var driver: Driver = .{};
    try std.testing.expectError(error.InvalidStreamState, decoder.nextStream());
    try driver.drain(&decoder, &source, .{ .bytes = expected }, source.len, 17);
    try std.testing.expectEqual(fixtures.python_payload.len, driver.written);
    const first = decoder.snapshot();
    const stopped = try driver.step(&decoder, source[driver.read..], .{ .bytes = expected }, 17);
    try std.testing.expectEqual(.done, stopped.status);
    try std.testing.expectEqualDeep(core.Progress{}, stopped.progress);
    decoder.finish();
    try std.testing.expectError(error.SizeMismatch, driver.step(&decoder, &.{}, .{ .bytes = expected }, 17));
    try std.testing.expectEqualStrings("continue_with_next_stream", decoder.diagnostics().recoverability_hint_name);
    try decoder.nextStream();
    try std.testing.expectEqual(first.input_read, decoder.snapshot().input_read);
    try std.testing.expectEqual(first.output_written, decoder.snapshot().output_written);
    try std.testing.expectEqual(first.peak_working_bytes, decoder.peakWorkingMemoryBytes());
    try driver.drain(&decoder, &source, .{ .bytes = expected }, source.len, 17);
    try std.testing.expectEqual(expected.len, driver.written);
    try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().stream_count);
    const retained = decoder.trailingInput();
    var recovered: [suffix.len]u8 = undefined;
    try std.testing.expectEqual(suffix.len, retained.len + source.len - driver.read);
    @memcpy(recovered[0..retained.len], retained);
    @memcpy(recovered[retained.len..], source[driver.read..]);
    try std.testing.expectEqualSlices(u8, suffix, &recovered);
    decoder.finish();
    _ = try driver.step(&decoder, &.{}, .{ .bytes = expected }, 0);

    const pair = frame ++ frame;
    decoder.resetWithOptions(.{ .stop_after_first_stream = true, .first_stream_retry_granularity = 12, .max_output_len = fixtures.python_payload.len });
    driver = .{};
    try driver.drain(&decoder, &pair, .{ .bytes = expected }, pair.len, 17);
    try decoder.nextStream();
    try std.testing.expectError(error.OutputLimitExceeded, driver.drain(&decoder, &pair, .{ .bytes = expected }, pair.len, 17));
    try std.testing.expectEqual(fixtures.python_payload.len, driver.written);
    try expectSticky(&decoder, error.OutputLimitExceeded);
}

test "Bzip2 stream contracts invalid reconfiguration preserves owned state until reset" {
    const wire = fixtures.pythonFrame();
    var decoder = bzip2.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    var driver: Driver = .{};
    try driver.drain(&decoder, &wire, .{ .bytes = fixtures.python_payload }, wire.len, 17);
    const before = decoder.snapshot();
    decoder.resetWithOptions(.{ .expected_output_len = 2, .max_output_len = 1 });
    const after = decoder.snapshot();
    try std.testing.expectEqual(before.input_read, after.input_read);
    try std.testing.expectEqual(before.output_written, after.output_written);
    try std.testing.expectEqual(before.working_bytes, after.working_bytes);
    try std.testing.expectEqual(before.retained_links_capacity, after.retained_links_capacity);
    try std.testing.expectEqual(before.retained_transformed_capacity, after.retained_transformed_capacity);
    try std.testing.expectEqual(before.retained_compressed_capacity, after.retained_compressed_capacity);
    try expectSticky(&decoder, error.InvalidBlockPlan);
    decoder.reset();
    driver = .{};
    try driver.drain(&decoder, &wire, .{ .bytes = fixtures.python_payload }, 1, 7);
}

test "Bzip2 stream contracts theoretical RLE bound and input overflow allocate no plaintext" {
    // WBITS9 permits 900,000 transformed bytes. Five RLE1 bytes can produce
    // 259 plaintext bytes; this exact legal format bound is 46,620,000 bytes.
    const maximum = 900_000 / 5 * 259 + 900_000 % 5;
    try std.testing.expectEqual(@as(usize, 46_620_000), maximum);
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var decoder = bzip2.IncrementalDecoder.initWithOptions(failing.allocator(), .{
        .expected_output_len = maximum,
        .max_output_len = maximum,
        .max_decoded_block_len = maximum,
        .max_working_memory = 0,
    });
    defer decoder.deinit();
    var driver: Driver = .{};
    const header = try driver.step(&decoder, "BZh9", .{ .bytes = "" }, 0);
    try std.testing.expectEqual(.need_input, header.status);
    try std.testing.expectEqual(@as(usize, 900_000), decoder.snapshot().block_size_limit);
    try std.testing.expectEqual(@as(usize, 0), failing.allocations);
    try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    decoder.resetWithOptions(.{});
    decoder.input_read = std.math.maxInt(usize);
    var output: [1]u8 = .{0xa5};
    try std.testing.expectError(error.IntegerOverflow, decoder.step("x", &output));
    try std.testing.expectEqualDeep(core.Progress{}, decoder.snapshot().last_step_progress);
    try std.testing.expectEqual(@as(u8, 0xa5), output[0]);
    try std.testing.expectEqual(@as(usize, 0), failing.allocations);
    try expectSticky(&decoder, error.IntegerOverflow);
}

/// Force public allocator growth to allocate a replacement before releasing
/// its previous backing, so the simultaneous peak is reproducible everywhere.
const NoRemap = struct {
    backing: std.mem.Allocator,

    fn allocator(self: *NoRemap) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *NoRemap = @ptrCast(@alignCast(raw));
        return self.backing.rawAlloc(len, alignment, ret);
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *NoRemap = @ptrCast(@alignCast(raw));
        self.backing.rawFree(bytes, alignment, ret);
    }
};

test "Bzip2 stream contracts link replacement peak counts old and new backing together" {
    const first = fixtures.pythonFrame();
    const second = fixtures.independentMultiFrame();
    const source = first ++ second;
    const expected: Expected = .{ .prefixed_pattern = .{ .prefix = fixtures.python_payload, .len = 100_321 } };
    var backing: NoRemap = .{ .backing = std.testing.allocator };
    var baseline = bzip2.IncrementalDecoder.initWithOptions(backing.allocator(), .{ .stop_after_first_stream = true });
    defer baseline.deinit();
    var driver: Driver = .{};
    try driver.drain(&baseline, &source, expected, source.len, 16 * 1024);
    const old_links = baseline.snapshot().retained_links_capacity;
    try std.testing.expect(old_links != 0);
    try baseline.nextStream();
    try driver.drain(&baseline, &source, expected, source.len, 16 * 1024);
    const peak = baseline.peakWorkingMemoryBytes();
    try std.testing.expect(peak >= baseline.workingMemoryBytes() + old_links);
    try std.testing.expectEqual(fixtures.python_payload.len + 100_321, driver.written);
    inline for (.{ false, true }) |below| {
        var decoder = bzip2.IncrementalDecoder.initWithOptions(backing.allocator(), .{
            .stop_after_first_stream = true,
            .max_working_memory = peak - @intFromBool(below),
        });
        defer decoder.deinit();
        var current: Driver = .{};
        try current.drain(&decoder, &source, expected, source.len, 16 * 1024);
        try decoder.nextStream();
        if (below) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, current.drain(&decoder, &source, expected, source.len, 16 * 1024));
            try std.testing.expectEqual(fixtures.python_payload.len, current.written);
            try expectSticky(&decoder, error.WorkingMemoryLimitExceeded);
        } else {
            try current.drain(&decoder, &source, expected, source.len, 16 * 1024);
            try std.testing.expectEqual(peak, decoder.peakWorkingMemoryBytes());
        }
    }
}
