const std = @import("std");
const h = @import("helpers.zig");
const xz = h.xz;
const a = std.testing.allocator;

test "XZ parallel incremental reused poisoned input survives many queued jobs and tiny output" {
    const input = try h.old.fixtureAlloc(a, 128, 13);
    defer a.free(input);
    var opts = h.options();
    opts.include_block_sizes = true;
    const expected = try h.baseline(input, opts);
    defer a.free(expected);
    var encoder = try xz.IncrementalEncoder.initExactSize(a, opts, input.len);
    defer encoder.deinit();
    const actual = try h.drive(&encoder, input, 1);
    defer a.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
    try std.testing.expectEqual(@as(usize, 14), encoder.snapshot().parallel.delivered_blocks);
    if (h.old.threadedTarget()) try std.testing.expectEqual(@as(usize, 2), encoder.snapshot().parallel.workers_started);
}

test "XZ parallel incremental active encoder value moves while original is overwritten" {
    const input = try h.old.fixtureAlloc(a, 128, 8);
    defer a.free(input);
    const opts = h.options();
    const expected = try h.baseline(input, opts);
    defer a.free(expected);
    var original = try xz.IncrementalEncoder.initExactSize(a, opts, input.len);
    var original_alive = true;
    defer if (original_alive) original.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(a);
    try h.header(&original, &encoded);
    const first = try h.checked(&original, input[0..256], &.{});
    try std.testing.expect(first.progress.input_read != 0);
    try std.testing.expect(original.snapshot().parallel.inflight_bytes != 0);
    var moved = original;
    original_alive = false;
    original = undefined;
    defer moved.deinit();
    try h.feed(&moved, &encoded, input[first.progress.input_read..], 3);
    try h.finish(&moved, &encoded, input);
    try std.testing.expectEqualSlices(u8, expected, encoded.items);
}

test "XZ parallel incremental active reset joins workers and keeps reusable capacities" {
    const input = try h.old.fixtureAlloc(a, 128, 5);
    defer a.free(input);
    var ledger = h.Tracker.init(a);
    const opts = h.options();
    var encoder = try xz.IncrementalEncoder.initExactSize(ledger.allocator(), opts, input.len);
    var alive = true;
    defer if (alive) encoder.deinit();
    var discarded: std.ArrayList(u8) = .empty;
    defer discarded.deinit(a);
    try h.header(&encoder, &discarded);
    _ = try h.checked(&encoder, input[0..256], &.{});
    const capacity = encoder.snapshot().parallel.retained_input_capacity;
    encoder.reset();
    const reset = encoder.snapshot();
    try std.testing.expectEqual(@as(usize, 0), reset.input_read);
    try std.testing.expectEqual(@as(usize, 0), reset.output_written);
    try std.testing.expectEqual(@as(usize, 0), reset.parallel.workers_live);
    try std.testing.expectEqual(@as(usize, 0), reset.parallel.inflight_bytes);
    try std.testing.expect(!reset.parallel.failed);
    try std.testing.expect(reset.parallel.retained_input_capacity >= capacity);
    const actual = try h.drive(&encoder, input, 3);
    defer a.free(actual);
    const expected = try h.baseline(input, opts);
    defer a.free(expected);
    try std.testing.expectEqualSlices(u8, expected, actual);
    encoder.deinit();
    alive = false;
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
}

test "XZ parallel incremental nextStream changes ownership modes and rejects low heap atomically" {
    const input = h.plain[0..96];
    var ledger = h.Tracker.init(a);
    var serial = h.options();
    serial.block_size = 32;
    serial.payload_encoding = .stored;
    serial.parallel = null;
    var encoder = try xz.IncrementalEncoder.initExactSize(ledger.allocator(), serial, input.len);
    var alive = true;
    defer if (alive) encoder.deinit();
    const first = try h.drive(&encoder, input, 3);
    defer a.free(first);
    const retained = encoder.snapshot();
    var parallel = serial;
    parallel.parallel = .{ .io = std.testing.io, .worker_count = 1, .max_inflight_bytes = 128 };
    try encoder.nextStreamExactSize(parallel, input.len);
    const second = try h.drive(&encoder, input, 1);
    defer a.free(second);
    try std.testing.expectEqualSlices(u8, first, second);
    const before = encoder.snapshot();
    var low = parallel;
    low.parallel.?.max_working_memory = before.parallel.live_requested_bytes - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.nextStreamExactSize(low, input.len));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try encoder.nextStreamExactSize(parallel, input.len);
    const third = try h.drive(&encoder, input, 3);
    defer a.free(third);
    try std.testing.expectEqualSlices(u8, first, third);
    try encoder.nextStreamExactSize(serial, input.len);
    const detached = encoder.snapshot();
    try std.testing.expect(!detached.parallel.enabled);
    try std.testing.expect(detached.retained_input_capacity >= retained.retained_input_capacity);
    try std.testing.expect(detached.retained_output_capacity >= retained.retained_output_capacity);
    try std.testing.expect(detached.retained_record_capacity >= retained.retained_record_capacity);
    const fourth = try h.drive(&encoder, input, 1);
    defer a.free(fourth);
    try std.testing.expectEqualSlices(u8, first, fourth);
    try std.testing.expectEqual(@as(usize, 4), encoder.snapshot().stream_count);
    try std.testing.expectEqual(4 * input.len, encoder.snapshot().input_read);
    encoder.deinit();
    alive = false;
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
}
