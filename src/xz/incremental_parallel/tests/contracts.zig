const std = @import("std");
const core = @import("../../../core.zig");
const h = @import("helpers.zig");
const xz = h.xz;
const a = std.testing.allocator;

test "XZ parallel incremental null and parallel retain header first zero output startup" {
    var serial_heap = std.testing.FailingAllocator.init(a, .{ .fail_index = 1 });
    var serial_opts = h.options();
    serial_opts.parallel = null;
    var serial = try xz.IncrementalEncoder.initWithOptions(serial_heap.allocator(), serial_opts);
    defer serial.deinit();
    try std.testing.expectEqual(@as(usize, 0), serial_heap.alloc_index);
    const first = try serial.step("payload", &.{});
    try std.testing.expectEqual(core.Progress{}, first.progress);
    try std.testing.expectEqual(.need_output, first.status);
    try std.testing.expectEqual(@as(usize, 12), serial.snapshot().pending_output);
    try std.testing.expectEqual(@as(usize, 1), serial_heap.alloc_index);
    try std.testing.expect(!serial.snapshot().parallel.enabled);
    var parallel = try xz.IncrementalEncoder.initWithOptions(a, h.options());
    defer parallel.deinit();
    const blocked = try h.checked(&parallel, "payload", &.{});
    try std.testing.expectEqual(core.Progress{}, blocked.progress);
    try std.testing.expectEqual(.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 12), parallel.snapshot().pending_output);
    try std.testing.expect(parallel.snapshot().parallel.enabled);
    try std.testing.expectEqual(@as(usize, 0), parallel.snapshot().parallel.workers_started);
}

test "XZ parallel incremental codec options sizes filters checks parsers and presets match one shot" {
    const input = try h.old.fixtureAlloc(a, 128, 4);
    defer a.free(input);
    const chain = [_]xz.Filter{ xz.Filter.x86(7), try xz.Filter.delta(4) };
    for ([_]bool{ false, true }) |sizes| for ([_]xz.Check{ .none, .crc32, .crc64, .sha256 }) |check| {
        var opts = h.options();
        opts.include_block_sizes = sizes;
        opts.check = check;
        opts.filters = &chain;
        try h.parity(input, opts);
    };
    for ([_]xz.Parser{ .literal_only, .greedy, .lazy, .fast, .normal }) |parser| {
        var opts = h.options();
        opts.parser = parser;
        opts.include_block_sizes = true;
        if (parser == .normal) opts.match_options.?.finder = .bt4;
        try h.parity(input, opts);
    }
    const filters = [_]xz.Filter{ try xz.Filter.delta(4), xz.Filter.x86(4), try xz.Filter.powerpc(4), try xz.Filter.ia64(16), try xz.Filter.arm(4), try xz.Filter.armThumb(2), try xz.Filter.sparc(4), try xz.Filter.arm64(4), try xz.Filter.riscv(2) };
    for (filters) |filter| {
        var opts = h.options();
        opts.filters = &.{filter};
        opts.payload_encoding = .stored;
        try h.parity(input, opts);
    }
    for (0..10) |level| for ([_]bool{ false, true }) |extreme| {
        var opts = try xz.IncrementalEncoder.Options.fromPreset(@intCast(level), extreme);
        opts.block_size = 128;
        opts.chunk_size = 128;
        opts.include_block_sizes = true;
        opts.parallel = .{ .io = std.testing.io, .max_inflight_blocks = 4, .max_inflight_bytes = 512 };
        try h.parity(input, opts);
    };
}

test "XZ parallel incremental plaintext credit lasts through final serialized block byte" {
    const input = h.plain[0..32];
    var opts = h.options();
    opts.block_size = 32;
    opts.payload_encoding = .stored;
    opts.include_block_sizes = true;
    opts.check = .crc32;
    opts.parallel.?.worker_count = 1;
    opts.parallel.?.max_inflight_bytes = 32;
    const expected = try h.baseline(input, opts);
    defer a.free(expected);
    const layout = try h.wire.parse(expected);
    defer layout.deinit();
    const body_len = layout.blocks[0].end - layout.blocks[0].header.start;
    var encoder = try xz.IncrementalEncoder.initWithOptions(a, opts);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(a);
    try h.header(&encoder, &encoded);
    const accepted = try h.checked(&encoder, input, &.{});
    try std.testing.expectEqual(input.len, accepted.progress.input_read);
    const almost = try a.alloc(u8, body_len - 1);
    defer a.free(almost);
    const step = try h.checked(&encoder, "", almost);
    try encoded.appendSlice(a, almost[0..step.progress.output_written]);
    try std.testing.expectEqual(body_len - 1, step.progress.output_written);
    const before_last = encoder.snapshot().parallel;
    try std.testing.expectEqual(@as(usize, 1), before_last.inflight_blocks);
    try std.testing.expectEqual(input.len, before_last.inflight_bytes);
    try std.testing.expectEqual(@as(usize, 0), before_last.delivered_blocks);
    try std.testing.expectEqual(@as(usize, 1), before_last.delivering_output_bytes);
    var last: [1]u8 = undefined;
    const released = try h.checked(&encoder, "", &last);
    try encoded.appendSlice(a, last[0..released.progress.output_written]);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().parallel.inflight_bytes);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().parallel.delivered_blocks);
    try h.finish(&encoder, &encoded, input);
    try std.testing.expectEqualSlices(u8, expected, encoded.items);
}

test "XZ parallel incremental can accept later blocks while ordered front still needs output" {
    const input = h.plain[0..96];
    var opts = h.options();
    opts.block_size = 32;
    opts.payload_encoding = .stored;
    opts.parallel.?.worker_count = 1;
    opts.parallel.?.max_inflight_bytes = 128;
    var encoder = try xz.IncrementalEncoder.initWithOptions(a, opts);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(a);
    try h.header(&encoder, &encoded);
    const first = try h.checked(&encoder, input[0..32], &.{});
    const second = try h.checked(&encoder, input[32..64], &.{});
    try std.testing.expectEqual(@as(usize, 32), first.progress.input_read);
    try std.testing.expectEqual(@as(usize, 32), second.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().parallel.delivered_blocks);
    try std.testing.expectEqual(@as(usize, 64), encoder.snapshot().parallel.inflight_bytes);
    try h.feed(&encoder, &encoded, input[64..], 1);
    try h.finish(&encoder, &encoded, input);
    const expected = try h.baseline(input, opts);
    defer a.free(expected);
    try std.testing.expectEqualSlices(u8, expected, encoded.items);
}

test "XZ parallel incremental flush barrier orders prior jobs before new input and footer" {
    const input = h.plain[0..96];
    var opts = h.options();
    opts.block_size = 128;
    opts.payload_encoding = .stored;
    opts.include_block_sizes = true;
    var encoder = try xz.IncrementalEncoder.initExactSize(a, opts, input.len);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(a);
    try h.feed(&encoder, &encoded, input[0..37], 3);
    encoder.flush();
    var blocked: [3]u8 = undefined;
    try h.failStep(&encoder, input[37..], &blocked, error.TrailingData);
    try h.drain(&encoder, &encoded, .need_input, 1);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().parallel.inflight_bytes);
    const length = encoded.items.len;
    encoder.flush();
    try h.drain(&encoder, &encoded, .need_input, 3);
    try std.testing.expectEqual(length, encoded.items.len);
    try h.feed(&encoder, &encoded, input[37..], 3);
    try h.finish(&encoder, &encoded, input);
    const layout = try h.wire.parse(encoded.items);
    defer layout.deinit();
    try std.testing.expectEqual(@as(usize, 2), layout.blocks.len);
    try std.testing.expectEqual(@as(usize, 37), layout.blocks[0].plain);
    try std.testing.expectEqual(@as(usize, 59), layout.blocks[1].plain);
}
