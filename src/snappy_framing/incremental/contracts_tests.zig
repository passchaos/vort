const std = @import("std");
const framing = @import("../../snappy_framing.zig");
const snappy = @import("../../snappy.zig");
const core = @import("../../core.zig");
const Format = @import("../incremental_decoder.zig").Format;
const allocator = std.testing.allocator;

pub const Trace = struct { failure: ?anyerror = null, input_read: usize = 0, output_written: usize = 0, peak: usize = 0 };

pub fn drive(decoder: anytype, encoded: []const u8, expected: []const u8, input_chunk: usize, output_chunk: usize) !Trace {
    var trace = Trace{};
    var scratch: [257]u8 = undefined;
    var finished = decoder.input_finished;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < (encoded.len + expected.len + 1) * 8 + 64);
        if (trace.input_read == encoded.len and !finished) {
            decoder.finish() catch |err| {
                trace.failure = err;
                return trace;
            };
            finished = true;
        }
        const offered = encoded[trace.input_read..][0..@min(input_chunk, encoded.len - trace.input_read)];
        @memset(&scratch, 0xa5);
        const output = scratch[0..if (calls % 5 == 0) 0 else output_chunk];
        const before = decoder.snapshot();
        const stepped = decoder.step(offered, output) catch |err| {
            const after = decoder.snapshot();
            try record(&trace, decoder, before, after.last_step_progress, offered.len, output, expected);
            try std.testing.expectEqual(@as(?usize, after.input_read), after.error_input_offset);
            try std.testing.expectEqual(@as(?usize, after.output_written), after.error_output_offset);
            trace.failure = err;
            return trace;
        };
        try record(&trace, decoder, before, stepped.progress, offered.len, output, expected);
        if (stepped.status == .done) return trace;
    }
}

fn record(trace: *Trace, decoder: anytype, before: @TypeOf(decoder.snapshot()), progress: core.Progress, offered: usize, output: []const u8, expected: []const u8) !void {
    const after = decoder.snapshot();
    try std.testing.expect(progress.input_read <= offered and progress.output_written <= output.len);
    try std.testing.expectEqual(after.input_read - before.input_read, progress.input_read);
    try std.testing.expectEqual(after.output_written - before.output_written, progress.output_written);
    try std.testing.expectEqualDeep(progress, after.last_step_progress);
    try std.testing.expectEqualDeep(progress, decoder.diagnostics().last_step_progress.?);
    try std.testing.expect(progress.output_written <= expected.len - trace.output_written);
    try std.testing.expectEqualSlices(u8, expected[trace.output_written..][0..progress.output_written], output[0..progress.output_written]);
    for (output[progress.output_written..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    trace.input_read += progress.input_read;
    trace.output_written += progress.output_written;
    trace.peak = @max(trace.peak, after.peak_working_bytes);
    try std.testing.expectEqual(@as(usize, 0), after.retained_decoded_capacity);
    try std.testing.expect(after.working_bytes <= decoder.options.max_working_memory);
    try std.testing.expect(after.peak_working_bytes <= decoder.options.max_working_memory);
    try std.testing.expectEqual(after.working_bytes, decoder.workingMemoryBytes());
    try std.testing.expectEqual(after.peak_working_bytes, decoder.peakWorkingMemoryBytes());
    try std.testing.expectEqual(core.stream_count.fromOptionalLocal(after.error_input_offset), decoder.diagnostics().error_input_offset);
    try std.testing.expectEqual(core.stream_count.fromOptionalLocal(after.error_output_offset), decoder.diagnostics().error_output_offset);
}

pub fn expectComplete(trace: Trace, input: usize, output: usize) !void {
    try std.testing.expectEqual(@as(?anyerror, null), trace.failure);
    try std.testing.expectEqual(input, trace.input_read);
    try std.testing.expectEqual(output, trace.output_written);
}

pub fn sticky(decoder: anytype, err: anyerror) !void {
    const before = decoder.snapshot();
    var output: [17]u8 = @splat(0xa5);
    try std.testing.expectError(err, decoder.step("unaccepted", &output));
    const after = decoder.snapshot();
    try std.testing.expectEqual(before.input_read, after.input_read);
    try std.testing.expectEqual(before.output_written, after.output_written);
    try std.testing.expectEqualDeep(core.Progress{}, after.last_step_progress);
    try std.testing.expectEqual(@as([17]u8, @splat(0xa5)), output);
}

pub fn appendU32(out: *std.ArrayList(u8), value: usize) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, @intCast(value), .big);
    try out.appendSlice(allocator, &bytes);
}

fn appendVarint(out: *std.ArrayList(u8), value_arg: usize) !void {
    var value = value_arg;
    while (value >= 128) : (value >>= 7) try out.append(allocator, @as(u8, @truncate(value)) | 128);
    try out.append(allocator, @intCast(value));
}

pub fn envelope(comptime format: Format, raw: []const u8, expected: usize) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    if (format == .xerial) try result.appendSlice(allocator, &framing.xerial_header) else try appendU32(&result, expected);
    try appendU32(&result, raw.len);
    try result.appendSlice(allocator, raw);
    return result.toOwnedSlice(allocator);
}

pub fn repeatedRaw(length: usize) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try appendVarint(&result, length);
    try result.appendSlice(allocator, &.{ 0, 'A' });
    var remaining = length - 1;
    while (remaining != 0) {
        const count: usize = @min(remaining, 64);
        const tag: u8 = @intCast((count - 1) * 4 + 2);
        try result.appendSlice(allocator, &.{ tag, 1, 0 });
        remaining -= count;
    }
    return result.toOwnedSlice(allocator);
}

pub fn farRaw(distance: usize) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try appendVarint(&result, distance + 64);
    try result.append(allocator, 0xf8); // Three-byte literal length.
    for (0..3) |index| try result.append(allocator, @truncate((distance - 1) >> @intCast(index * 8)));
    for (0..distance) |index| try result.append(allocator, @intCast(index % 251));
    try result.append(allocator, 0xff); // COPY4 length 64.
    for (0..4) |index| try result.append(allocator, @truncate(distance >> @intCast(index * 8)));
    return result.toOwnedSlice(allocator);
}

const decoders = .{ .{ framing.XerialIncrementalDecoder, Format.xerial }, .{ framing.HadoopIncrementalDecoder, Format.hadoop } };

test "Snappy framing contracts value initialization allocates no decoder buffers" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var decoder = framing.XerialIncrementalDecoder.init(failing.allocator());
    defer decoder.deinit();
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
}

test "Snappy framing contracts high ratio blocks decode with only compressed and one byte history storage" {
    const length = 2 * 1024 * 1024;
    const raw = try repeatedRaw(length);
    defer allocator.free(raw);
    try std.testing.expectEqual(@as(usize, length), try snappy.decodedBlockSize(raw));
    const expected = try allocator.alloc(u8, length);
    defer allocator.free(expected);
    @memset(expected, 'A');
    inline for (decoders) |case| {
        const encoded = try envelope(case[1], raw, expected.len);
        defer allocator.free(encoded);
        var decoder = case[0].initWithOptions(allocator, .{ .max_working_memory = 128 * 1024, .max_output_len = expected.len });
        defer decoder.deinit();
        const trace = try drive(&decoder, encoded, expected, 31, 257);
        try expectComplete(trace, encoded.len, expected.len);
        try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().retained_history_capacity);
        try std.testing.expect(trace.peak < expected.len / 8);
    }
}

test "Snappy framing contracts COPY4 distances exceed 64 KiB and match independent raw decode" {
    const distance = 70000;
    const raw = try farRaw(distance);
    defer allocator.free(raw);
    const expected = try snappy.decodeBlockAlloc(allocator, raw);
    defer allocator.free(expected);
    try std.testing.expectEqual(@as(usize, distance + 64), expected.len);
    try std.testing.expectEqualSlices(u8, expected[0..64], expected[distance..]);
    inline for (decoders) |case| {
        const encoded = try envelope(case[1], raw, expected.len);
        defer allocator.free(encoded);
        var decoder = case[0].initWithOptions(allocator, .{ .max_working_memory = 192 * 1024 });
        defer decoder.deinit();
        try expectComplete(try drive(&decoder, encoded, expected, 17, 7), encoded.len, expected.len);
        try std.testing.expectEqual(@as(usize, distance), decoder.snapshot().retained_history_capacity);
    }
}

test "Snappy framing contracts malformed raw body remains atomic before literals are published" {
    const raw = [_]u8{ 5, 8, 'A', 'B', 'C', 6, 0, 0 }; // COPY2 D=0 after three valid literals.
    inline for (decoders) |case| {
        const encoded = try envelope(case[1], &raw, 5);
        defer allocator.free(encoded);
        var decoder = case[0].init(allocator);
        defer decoder.deinit();
        var guard: [5]u8 = @splat(0xa5);
        try std.testing.expectError(error.InvalidMatch, decoder.step(encoded, &guard));
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().retained_history_capacity);
        try std.testing.expectEqual(@as([5]u8, @splat(0xa5)), guard);
        try std.testing.expectEqual(encoded.len, decoder.snapshot().last_step_progress.input_read);
        try sticky(&decoder, error.InvalidMatch);
    }
}

test "Snappy framing contracts partial finish is rejected without sealing recoverable input" {
    const raw = [_]u8{ 5, 16, 'h', 'e', 'l', 'l', 'o' };
    inline for (decoders) |case| {
        const encoded = try envelope(case[1], &raw, 5);
        defer allocator.free(encoded);
        var decoder = case[0].init(allocator);
        defer decoder.deinit();
        _ = try decoder.step(encoded[0 .. encoded.len - 1], &.{});
        try std.testing.expectError(error.TruncatedFrame, decoder.finish());
        try std.testing.expect(!decoder.input_finished);
        try expectComplete(try drive(&decoder, encoded[encoded.len - 1 ..], "hello", 1, 1), 1, 5);
    }
}

test "Snappy framing contracts Hadoop parsed outer size permits finish while final cursor output is pending" {
    const raw = [_]u8{ 5, 16, 'h', 'e', 'l', 'l', 'o' };
    const encoded = try envelope(.hadoop, &raw, 5);
    defer allocator.free(encoded);
    var decoder = framing.HadoopIncrementalDecoder.init(allocator);
    defer decoder.deinit();
    const blocked = try decoder.step(encoded, &.{});
    try std.testing.expectEqual(encoded.len, blocked.progress.input_read);
    try std.testing.expectEqual(@as(usize, 5), decoder.snapshot().hadoop_block_decoded);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
    try decoder.finish();
    try expectComplete(try drive(&decoder, "", "hello", 1, 2), 0, 5);
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().block_count);
}

test "Snappy framing contracts zero raw chunks empty streams and permissive raw widths preserve compatibility" {
    inline for (decoders) |case| {
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(allocator);
        if (case[1] == .xerial) try encoded.appendSlice(allocator, &framing.xerial_header) else try appendU32(&encoded, 1);
        const zero = [_]u8{ 0x80, 0 }; // Non-minimal varint, decoded zero.
        try appendU32(&encoded, zero.len);
        try encoded.appendSlice(allocator, &zero);
        const one = [_]u8{ 0x81, 0, 0xf0, 0, 'A' }; // Non-minimal size and literal width.
        try appendU32(&encoded, one.len);
        try encoded.appendSlice(allocator, &one);
        var decoder = case[0].init(allocator);
        defer decoder.deinit();
        try expectComplete(try drive(&decoder, encoded.items, "A", 1, 1), encoded.items.len, 1);
        try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().chunk_count);
        decoder.reset();
        const empty = if (case[1] == .xerial) framing.xerial_header[0..] else "";
        try expectComplete(try drive(&decoder, empty, "", 1, 1), empty.len, 0);
    }
}

test "Snappy framing contracts later chunk errors include earlier output in the failing call" {
    const valid = [_]u8{ 3, 8, 'A', 'B', 'C' };
    const invalid = [_]u8{ 2, 5, 0 }; // COPY1 with no decoded prefix.
    inline for (decoders) |case| {
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(allocator);
        if (case[1] == .xerial) try encoded.appendSlice(allocator, &framing.xerial_header) else try appendU32(&encoded, 5);
        try appendU32(&encoded, valid.len);
        try encoded.appendSlice(allocator, &valid);
        try appendU32(&encoded, invalid.len);
        try encoded.appendSlice(allocator, &invalid);
        var decoder = case[0].init(allocator);
        defer decoder.deinit();
        var output: [8]u8 = @splat(0xa5);
        try std.testing.expectError(error.InvalidMatch, decoder.step(encoded.items, &output));
        try std.testing.expectEqualStrings("ABC", output[0..3]);
        try std.testing.expectEqual(@as(usize, 3), decoder.snapshot().last_step_progress.output_written);
        try std.testing.expectEqual(encoded.items.len, decoder.snapshot().last_step_progress.input_read);
        try std.testing.expectEqual(@as(?core.StreamCount, 3), decoder.diagnostics().error_output_offset);
        try sticky(&decoder, error.InvalidMatch);
    }
}

test "Snappy framing contracts quotas are cumulative across chunks and Hadoop outer blocks" {
    const first = [_]u8{ 3, 8, 'A', 'B', 'C' };
    const second = [_]u8{ 4, 12, 'D', 'E', 'F', 'G' };
    inline for (decoders) |case| {
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(allocator);
        if (case[1] == .xerial) try encoded.appendSlice(allocator, &framing.xerial_header) else try appendU32(&encoded, 3);
        try appendU32(&encoded, first.len);
        try encoded.appendSlice(allocator, &first);
        if (case[1] == .hadoop) try appendU32(&encoded, 4);
        try appendU32(&encoded, second.len);
        try encoded.appendSlice(allocator, &second);
        var exact = case[0].initWithOptions(allocator, .{ .max_output_len = 7, .expected_output_len = 7 });
        defer exact.deinit();
        try expectComplete(try drive(&exact, encoded.items, "ABCDEFG", 1, 1), encoded.items.len, 7);
        var limited = case[0].initWithOptions(allocator, .{ .max_output_len = 6 });
        defer limited.deinit();
        const quota = try drive(&limited, encoded.items, "ABCDEFG", encoded.items.len, 17);
        try std.testing.expectEqual(@as(?anyerror, error.OutputLimitExceeded), quota.failure);
        try std.testing.expectEqual(@as(usize, 3), quota.output_written);
        try sticky(&limited, error.OutputLimitExceeded);
        var pledged = case[0].initWithOptions(allocator, .{ .expected_output_len = 6 });
        defer pledged.deinit();
        const length = try drive(&pledged, encoded.items, "ABCDEFG", encoded.items.len, 17);
        try std.testing.expectEqual(@as(?anyerror, error.SizeMismatch), length.failure);
        try std.testing.expectEqual(@as(usize, 3), length.output_written);
    }
}

test "Snappy framing contracts Hadoop incomplete parsed outer block finish accepts a later subchunk" {
    const first = [_]u8{ 3, 8, 'A', 'B', 'C' };
    const second = [_]u8{ 4, 12, 'D', 'E', 'F', 'G' };
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendU32(&encoded, 7);
    try appendU32(&encoded, first.len);
    try encoded.appendSlice(allocator, &first);
    const boundary = encoded.items.len;
    try appendU32(&encoded, second.len);
    try encoded.appendSlice(allocator, &second);
    var decoder = framing.HadoopIncrementalDecoder.init(allocator);
    defer decoder.deinit();
    _ = try decoder.step(encoded.items[0..boundary], &.{});
    try std.testing.expectEqual(@as(usize, 3), decoder.snapshot().hadoop_block_decoded);
    try std.testing.expectError(error.TruncatedFrame, decoder.finish());
    try std.testing.expect(!decoder.input_finished);
    try expectComplete(try drive(&decoder, encoded.items[boundary..], "ABCDEFG", 1, 1), encoded.items.len - boundary, 7);
}

test "Snappy framing contracts chunk output limits precede history allocation and working denials precede publication" {
    const raw = try farRaw(70000);
    defer allocator.free(raw);
    const expected = try snappy.decodeBlockAlloc(allocator, raw);
    defer allocator.free(expected);
    inline for (decoders) |case| {
        const encoded = try envelope(case[1], raw, expected.len);
        defer allocator.free(encoded);
        var decoded_limited = case[0].initWithOptions(allocator, .{ .max_decoded_chunk_len = expected.len - 1 });
        defer decoded_limited.deinit();
        try std.testing.expectError(error.OutputLimitExceeded, decoded_limited.step(encoded, &.{}));
        try std.testing.expectEqual(@as(usize, 0), decoded_limited.snapshot().retained_history_capacity);
        var compressed_limited = case[0].initWithOptions(allocator, .{ .max_compressed_chunk_len = raw.len - 1 });
        defer compressed_limited.deinit();
        try std.testing.expectError(error.OutputLimitExceeded, compressed_limited.step(encoded, &.{}));
        try std.testing.expectEqual(@as(usize, 0), compressed_limited.snapshot().retained_compressed_capacity);
        var working_limited = case[0].initWithOptions(allocator, .{ .max_working_memory = raw.len });
        defer working_limited.deinit();
        const blocked = try working_limited.step(encoded, &.{});
        try std.testing.expectEqual(encoded.len, blocked.progress.input_read);
        try std.testing.expectEqual(raw.len, working_limited.workingMemoryBytes());
        try std.testing.expectEqual(@as(usize, 70000), working_limited.snapshot().required_history_len);
        var output: [1]u8 = @splat(0xa5);
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, working_limited.step("", &output));
        try std.testing.expectEqual(@as(u8, 0xa5), output[0]);
        try std.testing.expectEqual(@as(usize, 0), working_limited.snapshot().last_step_progress.output_written);
        try sticky(&working_limited, error.WorkingMemoryLimitExceeded);
    }
}

test "Snappy framing contracts malformed boundaries EOF and counter overflow retain exact diagnostic progress" {
    inline for (decoders) |case| {
        var zero: std.ArrayList(u8) = .empty;
        defer zero.deinit(allocator);
        if (case[1] == .xerial) try zero.appendSlice(allocator, &framing.xerial_header) else try appendU32(&zero, 1);
        try appendU32(&zero, 0);
        var decoder = case[0].init(allocator);
        defer decoder.deinit();
        try std.testing.expectError(if (case[1] == .xerial) error.InvalidXerialSnappyStream else error.InvalidHadoopSnappyStream, decoder.step(zero.items, &.{}));
        try std.testing.expectEqual(zero.items.len, decoder.snapshot().last_step_progress.input_read);
        decoder.reset();
        decoder.input_read = std.math.maxInt(usize);
        try std.testing.expectError(error.IntegerOverflow, decoder.step(&.{0}, &.{}));
        try std.testing.expectEqualDeep(core.Progress{}, decoder.snapshot().last_step_progress);
        try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    }
    var outer = framing.HadoopIncrementalDecoder.init(allocator);
    defer outer.deinit();
    try std.testing.expectError(error.InvalidHadoopSnappyStream, outer.step(&.{ 0, 0, 0, 0 }, &.{}));
    try std.testing.expectEqual(@as(usize, 4), outer.snapshot().input_read);
}

test "Snappy framing contracts reset reconfiguration and active move own only compressed and raw history allocations" {
    const raw = try farRaw(70000);
    defer allocator.free(raw);
    const expected = try snappy.decodeBlockAlloc(allocator, raw);
    defer allocator.free(expected);
    inline for (decoders) |case| {
        const encoded = try envelope(case[1], raw, expected.len);
        defer allocator.free(encoded);
        var original = case[0].init(allocator);
        var output: [3]u8 = undefined;
        const step = try original.step(encoded, &output);
        try std.testing.expectEqual(@as(usize, 3), step.progress.output_written);
        try std.testing.expectEqualSlices(u8, expected[0..3], &output);
        var decoder = original;
        original = undefined;
        defer decoder.deinit();
        try expectComplete(try drive(&decoder, encoded[step.progress.input_read..], expected[3..], 1, 7), encoded.len - step.progress.input_read, expected.len - 3);
        const live = decoder.workingMemoryBytes();
        decoder.reset();
        try std.testing.expectEqual(live, decoder.workingMemoryBytes());
        try std.testing.expect(decoder.peakWorkingMemoryBytes() >= live);
        try expectComplete(try drive(&decoder, encoded, expected, 1, 17), encoded.len, expected.len);
        decoder.resetWithOptions(.{ .expected_output_len = 2, .max_output_len = 1 });
        try sticky(&decoder, error.InvalidBlockPlan);
        decoder.resetWithOptions(.{ .max_working_memory = 192 * 1024 });
        try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
        try expectComplete(try drive(&decoder, encoded, expected, 1, 17), encoded.len, expected.len);
    }
}

test "Snappy framing contracts every owned input and history allocation failure deinitializes after reset and move" {
    const raw = try farRaw(70000);
    defer allocator.free(raw);
    const expected = try snappy.decodeBlockAlloc(allocator, raw);
    defer allocator.free(expected);
    inline for (decoders) |case| {
        const encoded = try envelope(case[1], raw, expected.len);
        defer allocator.free(encoded);
        try std.testing.checkAllAllocationFailures(allocator, allocationGraph(case[0]).run, .{ encoded, expected });
    }
}

fn allocationGraph(comptime Decoder: type) type {
    return struct {
        fn run(active: std.mem.Allocator, encoded: []const u8, expected: []const u8) !void {
            var owner: ?Decoder = Decoder.init(active);
            defer if (owner) |*decoder| decoder.deinit();
            const decoder = &owner.?;
            var trace = try drive(decoder, encoded, expected, 17, 7);
            if (trace.failure) |err| {
                try sticky(decoder, err);
                return err;
            }
            try expectComplete(trace, encoded.len, expected.len);
            decoder.reset();
            trace = try drive(decoder, encoded, expected, 1, 17);
            if (trace.failure) |err| return err;
            decoder.resetWithOptions(.{});
            trace = try drive(decoder, encoded, expected, 17, 7);
            if (trace.failure) |err| return err;
            var moved = owner.?;
            owner = null;
            defer moved.deinit();
            const ledger: *std.testing.FailingAllocator = @ptrCast(@alignCast(active.ptr));
            try std.testing.expectEqual(ledger.allocated_bytes - ledger.freed_bytes, moved.workingMemoryBytes());
        }
    };
}
