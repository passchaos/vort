const std = @import("std");
const snappy = @import("../../snappy.zig");
const core = @import("../../core.zig");
const support = @import("contracts_tests.zig");
const allocator = std.testing.allocator;
const Decoder = snappy.IncrementalFrameDecoder;
const identifier = [_]u8{ 0xff, 6, 0, 0, 's', 'N', 'a', 'P', 'p', 'Y' };

const Trace = struct {
    failure: ?anyerror = null,
    input: usize = 0,
    output: usize = 0,
    peak: usize = 0,
};

fn account(trace: *Trace, decoder: *const Decoder, before: Decoder.Snapshot, progress: core.Progress, offered: usize, output: []const u8, expected: []const u8) !void {
    const after = decoder.snapshot();
    try std.testing.expect(progress.input_read <= offered and progress.output_written <= output.len);
    try std.testing.expectEqual(after.total_input_read - before.total_input_read, progress.input_read);
    try std.testing.expectEqual(after.output_written - before.output_written, progress.output_written);
    try std.testing.expectEqualDeep(progress, after.last_step_progress);
    try std.testing.expectEqualSlices(u8, expected[trace.output..][0..progress.output_written], output[0..progress.output_written]);
    for (output[progress.output_written..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    trace.input += progress.input_read;
    trace.output += progress.output_written;
    trace.peak = @max(trace.peak, after.peak_working_bytes);
    try std.testing.expectEqual(after.retained_chunk_capacity + after.history_capacity, after.working_bytes);
    try std.testing.expectEqual(@as(usize, 0), after.retained_decoded_capacity);
    try std.testing.expect(after.working_bytes <= decoder.options.max_working_memory);
    try std.testing.expect(after.peak_working_bytes >= after.working_bytes);
}

fn pump(decoder: *Decoder, encoded: []const u8, expected: []const u8, input_chunk: usize, output_chunk: usize) !Trace {
    var trace: Trace = .{};
    var scratch: [511]u8 = undefined;
    var sealed = false;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < (encoded.len + expected.len + 1) * 8 + 256);
        if (trace.input == encoded.len and !sealed) {
            try decoder.finish();
            sealed = true;
        }
        const before = decoder.snapshot();
        if (before.phase == .done) return trace;
        @memset(&scratch, 0xa5);
        const out = scratch[0..if (calls % 7 == 0) 0 else output_chunk];
        const input = encoded[trace.input..@min(encoded.len, trace.input + input_chunk)];
        const step = decoder.step(input, out) catch |err| {
            try account(&trace, decoder, before, decoder.last_step_progress, input.len, out, expected);
            try std.testing.expectEqual(@as(?usize, decoder.total_input_read), decoder.error_input_offset);
            try std.testing.expectEqual(@as(?usize, decoder.total_output), decoder.error_output_offset);
            trace.failure = err;
            return trace;
        };
        try account(&trace, decoder, before, step.progress, input.len, out, expected);
        if (step.status == .done) return trace;
    }
}
fn success(trace: Trace, input_len: usize, output_len: usize) !void {
    try std.testing.expectEqual(@as(?anyerror, null), trace.failure);
    try std.testing.expectEqual(input_len, trace.input);
    try std.testing.expectEqual(output_len, trace.output);
}
fn sticky(decoder: *Decoder, err: anyerror) !void {
    const before = decoder.snapshot();
    var guard: [7]u8 = @splat(0xa5);
    try std.testing.expectError(err, decoder.step("unconsumed", &guard));
    const after = decoder.snapshot();
    try std.testing.expectEqual(before.total_input_read, after.total_input_read);
    try std.testing.expectEqual(before.total_output, after.total_output);
    try std.testing.expectEqualDeep(core.Progress{}, after.last_step_progress);
    for (guard) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}
fn plainAlloc(len: usize) ![]u8 {
    const plain = try allocator.alloc(u8, len);
    const pattern = "native-snappy-resource-window\n";
    for (plain, 0..) |*byte, index| byte.* = pattern[index % pattern.len];
    return plain;
}
const Fixture = struct {
    frame: []u8,
    plain: []u8,
    first_chunk_end: usize,
    first_plain_len: usize,
    max_offset: usize,

    fn deinit(self: Fixture) void {
        allocator.free(self.frame);
        allocator.free(self.plain);
    }
};
fn fixture() !Fixture {
    const sizes = [_]usize{ 8192, 24512 };
    var plain: std.ArrayList(u8) = .empty;
    errdefer plain.deinit(allocator);
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(allocator);
    try support.appendChunk(&frame, 0xff, "sNaPpY");
    var first_end: usize = 0;
    var first_plain_len: usize = 0;
    for (sizes, 0..) |len, index| {
        const seed = try allocator.alloc(u8, len);
        defer allocator.free(seed);
        var random = std.Random.DefaultPrng.init(0x582a_19f3 + index);
        random.random().bytes(seed);
        const block = try support.literalBlock(seed, true);
        defer allocator.free(block);
        const decoded = try std.mem.concat(allocator, u8, &.{ seed, seed[0..64] });
        defer allocator.free(decoded);
        try support.appendData(&frame, block, decoded, true);
        try plain.appendSlice(allocator, decoded);
        if (index == 0) {
            first_end = frame.items.len;
            first_plain_len = plain.items.len;
        }
    }
    const frame_bytes = try frame.toOwnedSlice(allocator);
    errdefer allocator.free(frame_bytes);
    return .{ .frame = frame_bytes, .plain = try plain.toOwnedSlice(allocator), .first_chunk_end = first_end, .first_plain_len = first_plain_len, .max_offset = sizes[1] };
}

test "Snappy stream contracts resources working budget matches chunk and true copy dependency peak" {
    const data = try fixture();
    defer data.deinit();
    var baseline = std.testing.FailingAllocator.init(allocator, .{ .resize_fail_index = 0 });
    var decoder = Decoder.init(baseline.allocator());
    const measured = try pump(&decoder, data.frame, data.plain, 13, 31);
    try success(measured, data.frame.len, data.plain.len);
    const retained = decoder.snapshot();
    try std.testing.expectEqual(data.max_offset, retained.history_capacity);
    try std.testing.expectEqual(retained.retained_chunk_capacity + data.max_offset, retained.working_bytes);
    try std.testing.expect(measured.peak >= retained.working_bytes);
    decoder.deinit();
    try std.testing.expectEqual(baseline.allocated_bytes, baseline.freed_bytes);
    for ([_]bool{ true, false }) |exact| {
        var backing = std.testing.FailingAllocator.init(allocator, .{ .resize_fail_index = 0 });
        var limited = Decoder.initWithOptions(backing.allocator(), .{ .max_working_memory = measured.peak - @intFromBool(!exact) });
        var live = true;
        defer if (live) limited.deinit();
        const result = try pump(&limited, data.frame, data.plain, 13, 31);
        if (exact) {
            try success(result, data.frame.len, data.plain.len);
            try std.testing.expectEqual(measured.peak, limited.peakWorkingMemoryBytes());
        } else {
            try std.testing.expectEqual(@as(?anyerror, error.WorkingMemoryLimitExceeded), result.failure);
            try std.testing.expect(limited.peakWorkingMemoryBytes() <= measured.peak - 1);
            try std.testing.expect(limited.budget.hit_limit);
            try std.testing.expect(!backing.has_induced_failure);
            try sticky(&limited, error.WorkingMemoryLimitExceeded);
        }
        limited.deinit();
        live = false;
        try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
    }
}

test "Snappy stream contracts resources next member cumulative quota tightens transactionally" {
    // Reuses the producer's split resource draft and public drain helper.
    const first = try snappy.encodeFrameAlloc(allocator, "abc");
    defer allocator.free(first);
    const second = try snappy.encodeFrameAlloc(allocator, "de");
    defer allocator.free(second);
    const third = try snappy.encodeFrameAlloc(allocator, "f");
    defer allocator.free(third);
    var decoder = Decoder.initWithOptions(allocator, .{ .max_total_output_len = 5 });
    defer decoder.deinit();
    var first_output: [3]u8 = undefined;
    try support.drain(&decoder, first, &first_output, 0, 0);
    const before = decoder.snapshot();
    try std.testing.expectError(error.OutputLimitExceeded, decoder.nextStream(.{ .max_total_output_len = 2 }));
    try std.testing.expectEqualDeep(before, decoder.snapshot());
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.nextStream(.{ .max_working_memory = before.working_bytes - 1 }));
    try std.testing.expectEqualDeep(before, decoder.snapshot());
    try std.testing.expectError(error.InvalidBlockPlan, decoder.nextStream(.{ .max_output_len = 2, .expected_output_len = 3 }));
    try std.testing.expectEqualDeep(before, decoder.snapshot());
    try decoder.nextStream(.{ .max_output_len = 2, .expected_output_len = 2 });
    var second_output: [2]u8 = undefined;
    try support.drain(&decoder, second, &second_output, 0, 0);
    try std.testing.expectEqual(@as(usize, 5), decoder.snapshot().total_output);
    try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().output_written);
    try std.testing.expectEqual(first.len + second.len, decoder.snapshot().total_input_read);
    try decoder.nextStream(.{});
    try std.testing.expectEqual(@as(usize, 5), decoder.options.max_total_output_len);
    try std.testing.expectError(error.OutputLimitExceeded, decoder.step(third, &.{}));
    try std.testing.expectEqual(@as(usize, 5), decoder.snapshot().total_output);
    try sticky(&decoder, error.OutputLimitExceeded);
}

test "Snappy stream contracts resources zero init direct output reset and reconfiguration retain ownership" {
    var no_heap = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var empty = Decoder.initWithOptions(no_heap.allocator(), .{ .max_working_memory = 0, .max_output_len = 0 });
    defer empty.deinit();
    try std.testing.expectEqual(@as(usize, 0), no_heap.allocations);
    _ = try empty.step(&identifier, &.{});
    try empty.finish();
    try std.testing.expectEqual(@as(usize, 0), empty.workingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), no_heap.allocations);

    const plain = try plainAlloc(32768);
    defer allocator.free(plain);
    const direct_frame = try support.framed(plain, plain, false);
    defer allocator.free(direct_frame);
    var backing = std.testing.FailingAllocator.init(allocator, .{});
    var decoder = Decoder.init(backing.allocator());
    var live = true;
    defer if (live) decoder.deinit();
    try std.testing.expectEqual(@as(usize, 0), backing.allocations);
    const direct = try pump(&decoder, direct_frame, plain, 17, 37);
    try success(direct, direct_frame.len, plain.len);
    try std.testing.expectEqual(@as(usize, 0), decoder.cursor.historyCapacity());
    try std.testing.expectEqual(decoder.chunk.capacity, decoder.workingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().retained_decoded_capacity);
    const retained = decoder.workingMemoryBytes();
    decoder.reset();
    try std.testing.expectEqual(retained, decoder.workingMemoryBytes());
    try std.testing.expectEqual(retained, decoder.peakWorkingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().total_input_read);
    const invalid: Decoder.Options = .{ .max_output_len = 1, .expected_output_len = 2 };
    try std.testing.expectError(error.InvalidBlockPlan, invalid.validate());
    const before = decoder.snapshot();
    try std.testing.expectError(error.InvalidBlockPlan, decoder.resetWithOptions(invalid));
    try std.testing.expectEqualDeep(before, decoder.snapshot());
    try decoder.resetWithOptions(.{});
    try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
    // Transfer an active shared compressed cursor. Further chunks grow both
    // heap buffers, exercising allocator callbacks at the decoder's new address.
    const data = try fixture();
    defer data.deinit();
    var prefix: [3]u8 = undefined;
    const started = try decoder.step(data.frame, &prefix);
    try std.testing.expect(decoder.cursor.historyCapacity() != 0);
    var moved = decoder;
    decoder = undefined;
    live = false;
    defer moved.deinit();
    const output = try allocator.alloc(u8, data.plain.len);
    defer allocator.free(output);
    @memcpy(output[0..started.progress.output_written], prefix[0..started.progress.output_written]);
    try support.drain(&moved, data.frame, output, started.progress.input_read, started.progress.output_written);
    try std.testing.expectEqualSlices(u8, data.plain, output);
    try std.testing.expectEqual(data.max_offset, moved.cursor.historyCapacity());
}

test "Snappy stream contracts resources allocation failures never publish an unverified chunk" {
    const data = try fixture();
    defer data.deinit();
    const corrupted = try allocator.dupe(u8, data.frame);
    defer allocator.free(corrupted);
    corrupted[data.first_chunk_end + 4] ^= 1; // Second chunk's masked CRC.
    var checksum_decoder = Decoder.init(allocator);
    defer checksum_decoder.deinit();
    const crc_failure = try pump(&checksum_decoder, corrupted, data.plain, 13, 31);
    try std.testing.expectEqual(@as(?anyerror, error.ChecksumMismatch), crc_failure.failure);
    try std.testing.expectEqual(data.first_plain_len, crc_failure.output);
    try sticky(&checksum_decoder, error.ChecksumMismatch);

    var baseline = std.testing.FailingAllocator.init(allocator, .{ .resize_fail_index = 0 });
    {
        var decoder = Decoder.init(baseline.allocator());
        defer decoder.deinit();
        try success(try pump(&decoder, data.frame, data.plain, 13, 31), data.frame.len, data.plain.len);
    }
    try std.testing.expectEqual(baseline.allocated_bytes, baseline.freed_bytes);
    try std.testing.expect(baseline.allocations > 2 and baseline.allocations < 32);
    var saw_empty = false;
    var saw_verified_prefix = false;
    for (0..baseline.allocations) |index| {
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = index, .resize_fail_index = 0 });
        var decoder = Decoder.init(failing.allocator());
        var live = true;
        defer if (live) decoder.deinit();
        const rejected = try pump(&decoder, data.frame, data.plain, 13, 31);
        try std.testing.expectEqual(@as(?anyerror, error.OutOfMemory), rejected.failure);
        saw_empty = saw_empty or rejected.output == 0;
        saw_verified_prefix = saw_verified_prefix or rejected.output == data.first_plain_len;
        try std.testing.expect(rejected.output == 0 or rejected.output == data.first_plain_len);
        try std.testing.expect(failing.has_induced_failure);
        try std.testing.expect(!decoder.budget.hit_limit);
        try sticky(&decoder, error.OutOfMemory);
        failing.fail_index = std.math.maxInt(usize);
        decoder.reset();
        try std.testing.expectEqual(decoder.workingMemoryBytes(), decoder.peakWorkingMemoryBytes());
        try success(try pump(&decoder, data.frame, data.plain, 13, 31), data.frame.len, data.plain.len);
        decoder.deinit();
        live = false;
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
    try std.testing.expect(saw_empty and saw_verified_prefix);
}

test "Snappy stream contracts resources output and input arithmetic reject without new publication" {
    const plain = try plainAlloc(32768);
    defer allocator.free(plain);
    const encoded = try snappy.encodeFrameAlloc(allocator, plain);
    defer allocator.free(encoded);
    var exact = Decoder.initWithOptions(allocator, .{ .max_output_len = plain.len, .max_total_output_len = plain.len });
    defer exact.deinit();
    try success(try pump(&exact, encoded, plain, 23, 41), encoded.len, plain.len);
    var below = Decoder.initWithOptions(allocator, .{ .max_output_len = plain.len - 1 });
    defer below.deinit();
    const denied = try pump(&below, encoded, plain, 23, 41);
    try std.testing.expectEqual(@as(?anyerror, error.OutputLimitExceeded), denied.failure);
    try std.testing.expectEqual(@as(usize, 0), denied.output);
    try sticky(&below, error.OutputLimitExceeded);
    var overflow = Decoder.init(allocator);
    defer overflow.deinit();
    overflow.total_input_read = std.math.maxInt(usize);
    var guard: [3]u8 = @splat(0xa5);
    try std.testing.expectError(error.IntegerOverflow, overflow.step("x", &guard));
    try std.testing.expectEqualDeep(core.Progress{}, overflow.last_step_progress);
    try std.testing.expectEqual(@as(usize, 0), overflow.workingMemoryBytes());
    try std.testing.expectEqual(@as([3]u8, @splat(0xa5)), guard);
}
