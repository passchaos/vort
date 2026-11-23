const std = @import("std");
const core = @import("../../../core.zig");
const h = @import("step_borrow_helpers.zig");

const header_len = 8;
const sentinel = 0xa5;
const prefix = "one-use prefix for a skippable frame";

pub fn contracts(comptime Z: type) !void {
    inline for (.{ false, true }) |parallel| {
        try eligibility(Z, parallel);
        try wireAndMemory(Z, parallel);
        try maxLengthAndReset(Z, parallel);
    }
    try parallelLimits(Z);
    if (@import("../../incremental_parallel/types.zig").target_supports_parallel)
        try parallelWorkerBoundary(Z);
}

fn Encoder(comptime Z: type, comptime parallel: bool) type {
    return if (parallel) Z.NativeIncrementalParallelFrameEncoder else Z.NativeIncrementalFrameEncoder;
}

fn options(comptime Z: type, comptime parallel: bool) if (parallel) Z.NativeIncrementalParallelFrameEncoder.Options else Z.NativeFrameOptions {
    return if (parallel) .{
        .frame = h.options(Z),
        .parallel = .{ .io = std.Io.failing, .worker_count = 2, .job_size = 128, .max_inflight_jobs = 2, .max_inflight_bytes = 256 },
    } else h.options(Z);
}

fn expectState(encoder: anytype, before: anytype, output: usize, pending: usize, remaining: u32) !void {
    const after = encoder.snapshot();
    const active = pending != 0 or remaining != 0;
    try std.testing.expectEqual(active, after.skippable_streaming);
    try std.testing.expectEqual(!active, after.done);
    try std.testing.expectEqual(remaining, after.skippable_remaining);
    try std.testing.expectEqual(pending, after.pending_output);
    try std.testing.expectEqual(before.output_written + core.stream_count.fromLocal(output), after.output_written);
    try std.testing.expectEqual(before.frame_output + core.stream_count.fromLocal(output), after.frame_output);
    try std.testing.expectEqual(before.input_read, after.input_read);
    try std.testing.expectEqual(before.frame_input, after.frame_input);
    try std.testing.expectEqual(before.buffered_input, after.buffered_input);
    try std.testing.expectEqual(before.frame_count, after.frame_count);
    if (comptime @hasField(@TypeOf(after), "parallel")) {
        try std.testing.expectEqual(before.parallel.profile.accepted_jobs, after.parallel.profile.accepted_jobs);
        try std.testing.expectEqual(before.parallel.profile.delivered_jobs, after.parallel.profile.delivered_jobs);
    }
}

fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, sentinel), byte);
}

fn eligibility(comptime Z: type, comptime parallel: bool) !void {
    const E = Encoder(Z, parallel);
    const opts = options(Z, parallel);
    var encoder = try E.init(h.a, opts);
    defer encoder.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, encoder.beginSkippable(0, 0));
    try encoder.setPrefix(prefix);
    _ = try encoder.step("", &.{});
    try std.testing.expectError(error.InvalidBlockPlan, encoder.beginSkippable(0, 0));

    var magicless = opts;
    if (parallel) magicless.frame.format = .magicless else magicless.format = .magicless;
    var other = try E.initWithPrefix(h.a, magicless, prefix);
    defer other.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, other.beginSkippable(15, 0));
    try std.testing.expectEqual(.pending, other.prefixSnapshot().phase);
    try std.testing.expect(!other.snapshot().skippable_streaming);
}

fn activeRefusals(encoder: anytype, observer: []u8, pending: usize, remaining: u32) !void {
    const before = encoder.snapshot();
    const before_prefix = encoder.prefixSnapshot();
    encoder.flush();
    encoder.finish();
    try std.testing.expectEqual(before.finishing, encoder.snapshot().finishing);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.beginSkippable(3, 1));
    try std.testing.expectError(error.InvalidBlockPlan, encoder.writeSkippable(3, "old API"));
    try std.testing.expectError(error.InvalidBlockPlan, encoder.nextFrame(encoder.options));
    try std.testing.expectError(error.InvalidBlockPlan, encoder.nextFrameExactSize(encoder.options, 0));
    try std.testing.expectError(error.InvalidStreamState, encoder.setPrefix("replacement"));
    try std.testing.expectError(error.InvalidStreamState, encoder.resetParameters());

    var guard: [24]u8 = @splat(sentinel);
    try std.testing.expectError(error.InvalidStreamState, encoder.step("", &guard));
    inline for (.{ .@"continue", .flush, .end }) |directive| {
        try std.testing.expectError(error.InvalidStreamState, encoder.stepWithDirective("", &guard, directive));
        try std.testing.expectError(error.InvalidStreamState, encoder.stepWithDirective("plain", &guard, directive));
    }
    try std.testing.expectError(error.SizeMismatch, encoder.stepSkippable("oversupply", &guard));
    if (comptime @hasDecl(@TypeOf(encoder.*), "failedProgress")) {
        try std.testing.expectEqual(@as(?core.Progress, .{}), encoder.failedProgress());
    }
    try std.testing.expectError(error.InvalidBlockPlan, encoder.stepSkippable(guard[0..2], guard[1..]));
    try std.testing.expectError(error.InvalidBlockPlan, encoder.stepSkippable(std.mem.asBytes(encoder)[0..1], &guard));
    try std.testing.expectError(error.InvalidBlockPlan, encoder.stepSkippable("x", std.mem.asBytes(encoder)[0..1]));
    if (comptime @hasField(@TypeOf(encoder.*), "owner")) {
        try std.testing.expectError(error.InvalidBlockPlan, encoder.stepSkippable("x", std.mem.asBytes(encoder.owner)[0..1]));
    }
    const observer_byte = observer[0];
    try std.testing.expectError(error.InvalidBlockPlan, encoder.stepSkippable("x", observer[0..1]));
    try std.testing.expectEqual(observer_byte, observer[0]);
    try untouched(&guard);
    try std.testing.expectEqual(before_prefix, encoder.prefixSnapshot());
    try expectState(encoder, before, 0, pending, remaining);
}

fn wireAndMemory(comptime Z: type, comptime parallel: bool) !void {
    const E = Encoder(Z, parallel);
    const opts = options(Z, parallel);
    var streaming_opts = opts;
    var profile: Z.EncodeMemoryProfile = .{};
    if (parallel) streaming_opts.frame.memory_profile = &profile else streaming_opts.memory_profile = &profile;
    var backing = std.testing.FailingAllocator.init(h.a, .{});
    var encoder = try E.initWithPrefix(backing.allocator(), streaming_opts, prefix);
    defer encoder.deinit();
    var legacy = try E.initWithPrefix(h.a, opts, prefix);
    defer legacy.deinit();

    var payload: [257]u8 = undefined;
    for (&payload, 0..) |*byte, i| byte.* = @truncate(i * 29 + 3);
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(h.a);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(h.a);

    backing.fail_index = backing.alloc_index;
    backing.resize_fail_index = backing.resize_index;
    const mem = encoder.memorySnapshot();
    const freed_bytes = backing.freed_bytes;
    try encoder.beginSkippable(15, 3);
    try std.testing.expectEqual(.active, encoder.prefixSnapshot().phase);
    try std.testing.expectEqual(.skippable, encoder.prefixSnapshot().used_for);
    try activeRefusals(&encoder, std.mem.asBytes(&profile), header_len, 3);
    try driveSkippable(&encoder, 15, "abc", 0, &actual);
    try std.testing.expectEqual(.none, encoder.prefixSnapshot().phase);
    try std.testing.expectEqual(.skippable, encoder.prefixSnapshot().used_for);

    try legacy.writeSkippable(15, "abc");
    try std.testing.expectError(error.InvalidBlockPlan, legacy.beginSkippable(0, 0));
    try drainFrame(&legacy, null, &expected);
    for (0..4) |partition| {
        try pairedSkippable(&encoder, &legacy, @intCast(partition), if (partition == 0) "" else &payload, partition, &actual, &expected);
    }
    try std.testing.expect(!backing.has_induced_failure);
    try std.testing.expectEqual(backing.fail_index, backing.alloc_index);
    try std.testing.expectEqual(backing.resize_fail_index, backing.resize_index);
    try std.testing.expectEqual(freed_bytes, backing.freed_bytes);
    try std.testing.expectEqual(mem, encoder.memorySnapshot());
    backing.fail_index = std.math.maxInt(usize);
    backing.resize_fail_index = std.math.maxInt(usize);

    const plain = "data following streamed skippables";
    try encoder.nextFrame(streaming_opts);
    try legacy.nextFrame(opts);
    try drainFrame(&encoder, plain, &actual);
    try drainFrame(&legacy, plain, &expected);
    try std.testing.expectEqual(@as(core.StreamCount, 1), encoder.snapshot().frame_count);
    // Appending to an already-finished data frame must not change its input or count.
    try pairedSkippable(&encoder, &legacy, 13, "trailing metadata", 0, &actual, &expected);
    try std.testing.expectEqualSlices(u8, expected.items, actual.items);
    const decoded = try Z.decodeConcatenatedFrameAlloc(h.a, actual.items);
    defer h.a.free(decoded);
    try std.testing.expectEqualSlices(u8, plain, decoded);
}

fn pairedSkippable(encoder: anytype, legacy: anytype, id: u4, payload: []const u8, partition: usize, actual: *std.ArrayList(u8), expected: *std.ArrayList(u8)) !void {
    try encoder.beginSkippable(id, @intCast(payload.len));
    try driveSkippable(encoder, id, payload, partition, actual);
    try legacy.writeSkippable(id, payload);
    try drainFrame(legacy, null, expected);
}

fn driveSkippable(encoder: anytype, id: u4, payload: []const u8, partition: usize, wire: *std.ArrayList(u8)) !void {
    const before = encoder.snapshot();
    const start = wire.items.len;
    var header: usize = header_len;
    var consumed: usize = 0;
    try expectState(encoder, before, 0, header, @intCast(payload.len));
    for (0..(payload.len + header_len) * 4 + 32) |turn| {
        var offer: [23]u8 = @splat(sentinel);
        const input_len = @min(payload.len - consumed, (turn * 11 + partition * 5 + 4) % (offer.len + 1));
        @memcpy(offer[0..input_len], payload[consumed..][0..input_len]);
        const saved = offer;
        var out: [13]u8 = @splat(sentinel);
        const output_len = if (partition == 0) @intFromBool(turn % 5 != 0) else (turn * 7 + partition) % (out.len + 1);
        const head = @min(header, output_len);
        const body = @min(input_len, output_len - head);
        header -= head;
        consumed += body;
        const status: core.StepResult.Status = if (header == 0 and consumed == payload.len)
            .done
        else if (header != 0 or body < input_len)
            .need_output
        else
            .need_input;
        const step = try encoder.stepSkippable(offer[0..input_len], out[0..output_len]);
        try std.testing.expectEqual(core.StepResult{ .progress = .{ .input_read = body, .output_written = head + body }, .status = status }, step);
        try std.testing.expectEqualSlices(u8, &saved, &offer);
        @memset(&offer, 0x3e); // No borrow may survive the call, even after backpressure.
        try untouched(out[head + body ..]);
        try wire.appendSlice(h.a, out[0 .. head + body]);
        try expectState(encoder, before, wire.items.len - start, header, @intCast(payload.len - consumed));
        if (step.status == .done) {
            const bytes = wire.items[start..];
            try std.testing.expectEqual(header_len + payload.len, bytes.len);
            try expectHeader(bytes[0..header_len], id, @intCast(payload.len));
            return std.testing.expectEqualSlices(u8, payload, bytes[header_len..]);
        }
    }
    return error.TestUnexpectedResult;
}

fn expectHeader(header: *const [header_len]u8, id: u4, len: u32) !void {
    try std.testing.expectEqual(@as(u32, 0x184d2a50) + id, std.mem.readInt(u32, header[0..4], .little));
    try std.testing.expectEqual(len, std.mem.readInt(u32, header[4..8], .little));
}

fn drainFrame(encoder: anytype, input: ?[]const u8, wire: *std.ArrayList(u8)) !void {
    var consumed: usize = 0;
    for (0..128) |_| {
        var out: [11]u8 = undefined;
        const step = if (input) |plain| try encoder.stepWithDirective(plain[consumed..], &out, .end) else try encoder.step("", &out);
        consumed += step.progress.input_read;
        try wire.appendSlice(h.a, out[0..step.progress.output_written]);
        if (step.status == .done) return std.testing.expectEqual(if (input) |plain| plain.len else 0, consumed);
    }
    return error.TestUnexpectedResult;
}

fn maxLengthAndReset(comptime Z: type, comptime parallel: bool) !void {
    const E = Encoder(Z, parallel);
    var backing = std.testing.FailingAllocator.init(h.a, .{});
    var encoder = try E.initWithPrefix(backing.allocator(), options(Z, parallel), prefix);
    defer encoder.deinit();
    // Refuse any accidental allocation of the pledged body before touching it.
    backing.fail_index = backing.alloc_index;
    backing.resize_fail_index = backing.resize_index;
    const max = std.math.maxInt(u32);
    const before = encoder.snapshot();
    try encoder.beginSkippable(15, max);
    var out: [header_len + 1]u8 = undefined;
    const step = try encoder.stepSkippable("xy", &out);
    try std.testing.expectEqual(core.StepResult{ .progress = .{ .input_read = 1, .output_written = out.len }, .status = .need_output }, step);
    try expectHeader(out[0..header_len], 15, max);
    try std.testing.expectEqual(@as(u8, 'x'), out[header_len]);
    try expectState(&encoder, before, out.len, 0, max - 1);
    try std.testing.expect(!backing.has_induced_failure);
    backing.fail_index = std.math.maxInt(usize);
    backing.resize_fail_index = std.math.maxInt(usize);

    encoder.reset();
    const reset = encoder.snapshot();
    try std.testing.expect(!reset.skippable_streaming and !reset.done);
    try std.testing.expectEqual(@as(u32, 0), reset.skippable_remaining);
    try std.testing.expectEqual(@as(usize, 0), reset.pending_output);
    try std.testing.expectEqual(@as(core.StreamCount, 0), reset.output_written);
    try std.testing.expectEqual(.none, encoder.prefixSnapshot().phase);
    try h.roundTrip(Z, &encoder, "normal data after discarding a partial skippable", null);
}

fn parallelWorkerBoundary(comptime Z: type) !void {
    const helpers = @import("../../incremental_parallel/tests/helpers.zig");
    const input = helpers.fixture(1025);
    var opts = helpers.options(Z);
    opts.frame.strategy = .greedy;
    var encoder = try Z.NativeIncrementalParallelFrameEncoder.init(h.a, opts);
    defer encoder.deinit();
    try h.roundTrip(Z, &encoder, &input, null);
    const before = encoder.snapshot();
    try std.testing.expect(before.parallel.profile.workers_started != 0);
    const heap = encoder.memorySnapshot();

    const payload = "metadata between worker frames";
    try encoder.beginSkippable(9, payload.len);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(h.a);
    try driveSkippable(&encoder, 9, payload, 0, &wire);
    try std.testing.expectEqual(before.parallel.profile.workers_started, encoder.snapshot().parallel.profile.workers_started);
    try std.testing.expectEqual(heap, encoder.memorySnapshot());
    try encoder.nextFrame(opts);
    try h.roundTrip(Z, &encoder, &input, null);
}

fn parallelLimits(comptime Z: type) !void {
    const E = Encoder(Z, true);
    var opts = options(Z, true);
    opts.max_pending_output_len = header_len - 1;
    opts.max_input_len = 0;
    var encoder = try E.initWithPrefix(h.a, opts, prefix);
    defer encoder.deinit();
    const payload = "body bigger than the fixed pending-output cap";
    const before = encoder.snapshot();
    const before_prefix = encoder.prefixSnapshot();
    const mem = encoder.memorySnapshot();
    try std.testing.expectError(error.OutputLimitExceeded, encoder.beginSkippable(11, payload.len));
    try std.testing.expectEqual(before_prefix, encoder.prefixSnapshot());
    try std.testing.expect(!encoder.snapshot().skippable_streaming);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
    encoder.options.max_pending_output_len = header_len;
    try encoder.beginSkippable(11, payload.len);
    try expectState(&encoder, before, 0, header_len, payload.len);

    var out: [header_len + payload.len + 1]u8 = @splat(sentinel);
    encoder.options.max_output_len = 3;
    try std.testing.expectError(error.OutputLimitExceeded, encoder.stepSkippable(payload, &out));
    try std.testing.expectEqual(@as(?core.Progress, .{ .output_written = 3 }), encoder.failedProgress());
    try untouched(out[3..]);
    try expectState(&encoder, before, 3, 5, payload.len);

    // The fixed header has already been admitted; changing the pending cap
    // cannot retroactively charge it or the body for subsequent steps.
    encoder.options.max_pending_output_len = 0;
    encoder.options.max_output_len = header_len + 2;
    try std.testing.expectError(error.OutputLimitExceeded, encoder.stepSkippable(payload, out[3..]));
    try std.testing.expectEqual(@as(?core.Progress, .{ .input_read = 2, .output_written = 7 }), encoder.failedProgress());
    try expectHeader(out[0..header_len], 11, payload.len);
    try std.testing.expectEqualSlices(u8, payload[0..2], out[header_len..][0..2]);
    try untouched(out[header_len + 2 ..]);
    try expectState(&encoder, before, header_len + 2, 0, payload.len - 2);

    try std.testing.expectError(error.OutputLimitExceeded, encoder.stepSkippable(payload[2..], out[header_len + 2 ..]));
    try std.testing.expectEqual(@as(?core.Progress, .{}), encoder.failedProgress());
    try untouched(out[header_len + 2 ..]);
    try expectState(&encoder, before, header_len + 2, 0, payload.len - 2);
    try std.testing.expect(!encoder.snapshot().parallel.failed);

    encoder.options.max_output_len = header_len + payload.len;
    const step = try encoder.stepSkippable(payload[2..], out[header_len + 2 ..]);
    try std.testing.expectEqual(core.StepResult{ .progress = .{ .input_read = payload.len - 2, .output_written = payload.len - 2 }, .status = .done }, step);
    try std.testing.expectEqual(@as(?core.Progress, null), encoder.failedProgress());
    try expectState(&encoder, before, header_len + payload.len, 0, 0);
    try std.testing.expectEqualSlices(u8, payload, out[header_len..][0..payload.len]);
    try untouched(out[header_len + payload.len ..]);
    try std.testing.expectEqual(mem, encoder.memorySnapshot());
}
