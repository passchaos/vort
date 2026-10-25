const std = @import("std");
const core = @import("../../../core.zig");
const h = @import("helpers.zig");
const xz = h.xz;
const a = std.testing.allocator;

test "XZ parallel incremental partial byte cap stalls recoverably and flush preserves block size" {
    const input = h.plain[0..65];
    var opts = h.options();
    opts.block_size = 128;
    opts.payload_encoding = .stored;
    opts.include_block_sizes = true;
    opts.max_block_count = 1;
    opts.parallel.?.worker_count = 1;
    opts.parallel.?.max_inflight_bytes = 64;
    var encoder = try xz.IncrementalEncoder.initWithOptions(a, opts);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(a);
    try h.header(&encoder, &encoded);
    const accepted = try h.checked(&encoder, input[0..64], &.{});
    try std.testing.expectEqual(@as(usize, 64), accepted.progress.input_read);
    try std.testing.expectEqual(@as(usize, 64), encoder.snapshot().parallel.partial_input_bytes);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().parallel.accepted_blocks);
    var blocked: [1]u8 = undefined;
    try h.failStep(&encoder, input[64..], &blocked, error.WorkingMemoryLimitExceeded);
    try std.testing.expect(!encoder.snapshot().parallel.failed);
    try std.testing.expectEqual(@as(usize, 64), encoder.snapshot().parallel.inflight_bytes);
    try std.testing.expectEqual(@as(usize, 128), encoder.options.block_size);
    encoder.flush();
    try h.drain(&encoder, &encoded, .need_input, 3);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().parallel.inflight_bytes);
    try h.failStep(&encoder, input[64..], &blocked, error.OutputLimitExceeded);
    try std.testing.expect(!encoder.snapshot().parallel.failed);
    encoder.options.max_block_count = 2;
    try h.feed(&encoder, &encoded, input[64..], 1);
    try h.finish(&encoder, &encoded, input);
    const layout = try h.wire.parse(encoded.items);
    defer layout.deinit();
    try std.testing.expectEqual(@as(usize, 2), layout.blocks.len);
    try std.testing.expectEqual(@as(usize, 64), layout.blocks[0].plain);
    try std.testing.expectEqual(@as(usize, 1), layout.blocks[1].plain);
}

test "XZ parallel incremental input limit and pledge preadmission preserve error call progress" {
    const input = h.plain[0..32];
    for ([_]bool{ false, true }) |pledge| {
        var opts = h.options();
        opts.block_size = 32;
        opts.parallel.?.worker_count = 1;
        if (!pledge) opts.max_input_len = 31;
        var encoder = if (pledge) try xz.IncrementalEncoder.initExactSize(a, opts, 31) else try xz.IncrementalEncoder.initWithOptions(a, opts);
        defer encoder.deinit();
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(a);
        try h.header(&encoder, &encoded);
        var output: [3]u8 = undefined;
        try h.failStep(&encoder, input, &output, if (pledge) error.SizeMismatch else error.OutputLimitExceeded);
        try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().input_read);
        try std.testing.expectEqual(@as(usize, 12), encoder.snapshot().output_written);
        try std.testing.expectEqual(core.Progress{}, encoder.snapshot().parallel.last_step_progress);
        try std.testing.expect(!encoder.snapshot().parallel.failed);
    }
}

test "XZ parallel incremental front limit retry preserves one already encoded job" {
    const input = h.plain[0..32];
    var opts = h.options();
    opts.block_size = 32;
    opts.payload_encoding = .stored;
    opts.include_block_sizes = true;
    opts.check = .crc32;
    opts.parallel.?.worker_count = 1;
    opts.max_pending_output_len = 12;
    const expected = try h.baseline(input, opts);
    defer a.free(expected);
    const layout = try h.wire.parse(expected);
    defer layout.deinit();
    const front_len = layout.blocks[0].end - layout.blocks[0].header.start;
    var encoder = try xz.IncrementalEncoder.initExactSize(a, opts, input.len);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(a);
    try h.header(&encoder, &encoded);
    var observed_error = false;
    if (encoder.step(input, &.{})) |accepted| {
        try std.testing.expectEqual(input.len, accepted.progress.input_read);
    } else |err| {
        try std.testing.expectEqual(error.OutputLimitExceeded, err);
        try std.testing.expectEqual(input.len, encoder.snapshot().parallel.last_step_progress.input_read);
        observed_error = true;
    }
    if (!observed_error) {
        var output: [1]u8 = undefined;
        try h.failStep(&encoder, "", &output, error.OutputLimitExceeded);
    }
    const ready = encoder.snapshot().parallel;
    try std.testing.expectEqual(@as(usize, 1), ready.encoded_blocks);
    try std.testing.expect(!ready.failed);
    try std.testing.expect(ready.completed_output_bytes + ready.delivering_output_bytes >= front_len);
    try std.testing.expectEqual(@as(usize, 0), ready.delivered_blocks);
    encoder.options.max_pending_output_len = front_len;
    const ending = try h.drive(&encoder, "", 1);
    defer a.free(ending);
    try encoded.appendSlice(a, ending);
    try std.testing.expectEqualSlices(u8, expected, encoded.items);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().parallel.encoded_blocks);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().parallel.delivered_blocks);
}

test "XZ parallel incremental worker codec and heap errors remain sticky with exact progress" {
    const input = h.plain[0..96];
    for ([_]bool{ false, true }) |heap_failure| {
        if (heap_failure and !h.old.threadedTarget()) continue;
        var ledger = h.Tracker.init(a);
        var opts = h.options();
        opts.block_size = 32;
        if (heap_failure) ledger.fail_worker = true else opts.match_options.?.max_working_memory = 0;
        var encoder = try xz.IncrementalEncoder.initExactSize(ledger.allocator(), opts, input.len);
        var alive = true;
        defer if (alive) encoder.deinit();
        try h.driveFailure(&encoder, input, if (heap_failure) error.OutOfMemory else error.WorkingMemoryLimitExceeded);
        if (heap_failure) try std.testing.expect(ledger.worker_refusals != 0);
        ledger.fail_worker = false;
        encoder.reset();
        try std.testing.expect(!encoder.snapshot().parallel.failed);
        try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().input_read);
        try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().output_written);
        if (heap_failure) {
            // The backing allocator is available again; reset keeps the same
            // captured, already-valid codec configuration.
            const recovered = try h.drive(&encoder, input, 3);
            defer a.free(recovered);
            const expected = try h.baseline(input, opts);
            defer a.free(expected);
            try std.testing.expectEqualSlices(u8, expected, recovered);
        } else {
            // Reset clears the old failure but does not replace stream codec
            // controls. A new attempt still reaches the original zero quota.
            try h.driveFailure(&encoder, input, error.WorkingMemoryLimitExceeded);
            try std.testing.expect(encoder.snapshot().input_read != 0);
            try std.testing.expect(encoder.snapshot().output_written >= 12);
            var valid_opts = opts;
            valid_opts.match_options.?.max_working_memory = std.math.maxInt(usize);
            var fresh = try xz.IncrementalEncoder.initExactSize(ledger.allocator(), valid_opts, input.len);
            defer fresh.deinit();
            const recovered = try h.drive(&fresh, input, 3);
            defer a.free(recovered);
            const expected = try h.baseline(input, valid_opts);
            defer a.free(expected);
            try std.testing.expectEqualSlices(u8, expected, recovered);
        }
        encoder.deinit();
        alive = false;
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
    }
}

test "XZ parallel incremental deterministic one worker heap exact and below include all retention" {
    const input = h.plain[0..96];
    var opts = h.options();
    opts.block_size = 32;
    opts.include_block_sizes = true;
    opts.payload_encoding = .stored;
    opts.parallel.?.worker_count = 1;
    opts.parallel.?.max_inflight_blocks = 2;
    opts.parallel.?.max_inflight_bytes = 64;
    var measured = h.Tracker.init(a);
    var encoder = try xz.IncrementalEncoder.initExactSize(measured.allocator(), opts, input.len);
    var alive = true;
    defer if (alive) encoder.deinit();
    const expected = try h.drive(&encoder, input, 3);
    defer a.free(expected);
    const peak = encoder.snapshot().parallel.peak_requested_bytes;
    try std.testing.expect(peak > 0);
    try std.testing.expectEqual(measured.peak, peak);
    try std.testing.expectEqual(measured.live, encoder.snapshot().parallel.live_requested_bytes);
    encoder.deinit();
    alive = false;
    try std.testing.expectEqual(@as(usize, 0), measured.live);
    for ([_]bool{ true, false }) |exact| {
        var ledger = h.Tracker.init(a);
        var bounded = opts;
        bounded.parallel.?.max_working_memory = if (exact) peak else peak - 1;
        var candidate = try xz.IncrementalEncoder.initExactSize(ledger.allocator(), bounded, input.len);
        var candidate_alive = true;
        defer if (candidate_alive) candidate.deinit();
        if (exact) {
            const actual = try h.drive(&candidate, input, 3);
            defer a.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
            try std.testing.expectEqual(peak, candidate.snapshot().parallel.peak_requested_bytes);
        } else try std.testing.expectError(error.WorkingMemoryLimitExceeded, h.drive(&candidate, input, 3));
        candidate.deinit();
        candidate_alive = false;
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
    }
}

fn allocationCampaign(workers: usize) !void {
    const input = h.plain[0..65];
    var opts = h.options();
    opts.block_size = 32;
    opts.payload_encoding = .stored;
    opts.parallel.?.worker_count = workers;
    opts.parallel.?.max_inflight_blocks = 2;
    opts.parallel.?.max_inflight_bytes = 64;
    var baseline = h.Tracker.init(a);
    var encoder = try xz.IncrementalEncoder.initExactSize(baseline.allocator(), opts, input.len);
    const expected = try h.drive(&encoder, input, 3);
    defer a.free(expected);
    encoder.deinit();
    const attempts = baseline.attempts;
    try std.testing.expectEqual(@as(usize, 0), baseline.live);
    for (0..attempts + 1) |fail_after| {
        var ledger = h.Tracker.init(a);
        ledger.fail_after = fail_after;
        var candidate = xz.IncrementalEncoder.initExactSize(ledger.allocator(), opts, input.len) catch |err| {
            try std.testing.expectEqual(error.OutOfMemory, err);
            try std.testing.expectEqual(@as(usize, 0), ledger.live);
            continue;
        };
        var candidate_alive = true;
        defer if (candidate_alive) candidate.deinit();
        if (h.drive(&candidate, input, 3)) |actual| {
            try std.testing.expectEqualSlices(u8, expected, actual);
            a.free(actual);
        } else |err| try std.testing.expectEqual(error.OutOfMemory, err);
        candidate.deinit();
        candidate_alive = false;
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
    }
}

test "XZ parallel incremental bounded all allocation graphs free owners plans jobs and workers" {
    try allocationCampaign(1);
    try allocationCampaign(2);
}

test "XZ parallel incremental synchronous fallback accepts failing Io without worker operations" {
    for ([_]usize{ 1, 2 }) |workers| {
        if (workers == 2 and h.old.threadedTarget()) continue;
        var opts = h.options();
        opts.parallel.?.worker_count = workers;
        opts.parallel.?.io = std.Io.failing;
        const expected = try h.baseline(h.plain, opts);
        defer a.free(expected);
        var encoder = try xz.IncrementalEncoder.initExactSize(a, opts, h.plain.len);
        defer encoder.deinit();
        const actual = try h.drive(&encoder, h.plain, 1);
        defer a.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
        try std.testing.expect(encoder.snapshot().parallel.serial_fallback);
        try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().parallel.workers_started);
    }
}
