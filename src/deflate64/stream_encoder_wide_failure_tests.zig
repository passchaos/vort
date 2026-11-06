//! CounterMax injection and real allocation failure contracts.
//! These boundary injections are distinct from the lawful prefix model.
const std = @import("std");
const h = @import("stream_encoder_wide_test_helpers.zig");
const Flush = h.Flush;
const requestFlush = h.requestFlush;
const oracleDelta = h.oracleDelta;

fn realPending(encoder: anytype) !void {
    const result = try h.step(encoder, h.prefix ++ "x", &.{});
    try std.testing.expectEqual(@as(usize, h.prefix.len), result.progress.input_read);
    try std.testing.expectEqual(h.core.StepResult.Status.need_output, result.status);
    try std.testing.expect(encoder.snapshot().pending_output > 2);
}

fn countMaxProtection(comptime Encoder: type) !void {
    // These injected CounterMax fields are boundary protection tests. Their
    // values do not purport to be produced by the lawful repeat-prefix model.
    var input = Encoder.initWithOptions(h.allocator, .{ .block_len = h.prefix.len, .compression = .stored });
    defer input.deinit();
    try realPending(&input);
    input.total_input = h.max_count - 1;
    try h.atomicFailure(&input, error.IntegerOverflow, "ab");

    var output = Encoder.initWithOptions(h.allocator, .{ .block_len = h.prefix.len, .compression = .stored });
    defer output.deinit();
    try realPending(&output);
    const offset = output.pending_offset;
    const expected = output.pending.items[offset..][0..2].*;
    output.total_output = h.max_count - 2;
    var guard: [128]u8 = @splat(0xa5);
    const legal = try h.step(&output, "", &guard);
    try std.testing.expectEqual(h.core.StepResult.Status.need_output, legal.status);
    try std.testing.expectEqualDeep(h.core.Progress{ .output_written = 2 }, legal.progress);
    try std.testing.expectEqualSlices(u8, &expected, guard[0..2]);
    try h.guard(guard[2..]);
    try std.testing.expectEqual(offset + 2, output.pending_offset);
    try std.testing.expectEqual(h.max_count, output.total_output);
    try h.atomicFailure(&output, error.IntegerOverflow, "");

    // Verify the global budget across two emission events in one call. A real
    // local encoder supplies both emitted blocks and their independent oracle.
    // The CounterMax value itself remains an explicit protection injection.
    var local = Encoder.initWithOptions(h.allocator, .{ .block_len = h.prefix.len, .compression = .stored });
    defer local.deinit();
    try realPending(&local);
    const drain_limit = local.snapshot().pending_output + 2;
    var local_output: [128]u8 = @splat(0xa5);
    const reference = try h.step(&local, h.prefix ++ "x", &local_output);
    try std.testing.expect(reference.progress.output_written > drain_limit);
    var combined_wire: std.ArrayList(u8) = .empty;
    defer combined_wire.deinit(h.allocator);
    try combined_wire.appendSlice(h.allocator, local_output[0..reference.progress.output_written]);
    try h.finish(&local, &combined_wire, 1);
    try oracleDelta(combined_wire.items, h.prefix ++ h.prefix ++ "x", h.ledger(local));

    var multiple = Encoder.initWithOptions(h.allocator, .{ .block_len = h.prefix.len, .compression = .stored });
    defer multiple.deinit();
    try realPending(&multiple);
    multiple.total_output = h.max_count - drain_limit;
    guard = @splat(0xa5);
    const bounded = try h.step(&multiple, h.prefix ++ "x", &guard);
    try std.testing.expectEqual(h.core.StepResult.Status.need_output, bounded.status);
    try std.testing.expectEqualDeep(h.core.Progress{ .input_read = h.prefix.len, .output_written = drain_limit }, bounded.progress);
    try std.testing.expectEqualSlices(u8, local_output[0..drain_limit], guard[0..drain_limit]);
    try h.guard(guard[drain_limit..]);
    try std.testing.expectEqual(@as(usize, 2), multiple.pending_offset);
    try std.testing.expectEqual(h.max_count, multiple.total_output);
    try h.atomicFailure(&multiple, error.IntegerOverflow, "");

    // At zero remaining count, reject a fresh publication before allocating
    // its wire or clearing full-flush history, as well as before caller writes.
    for (std.enums.values(Flush)) |mode| {
        var flush = Encoder.initWithOptions(h.allocator, .{ .block_len = h.prefix.len, .compression = .stored });
        defer flush.deinit();
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(h.allocator);
        try h.feed(&flush, h.prefix, &wire, 3, 5);
        flush.total_output = h.max_count;
        requestFlush(&flush, mode);
        try h.atomicFailure(&flush, error.IntegerOverflow, "");
    }
    var finish = Encoder.init(h.allocator);
    defer finish.deinit();
    finish.total_output = h.max_count;
    finish.finish();
    try h.atomicFailure(&finish, error.IntegerOverflow, "");
}

fn statisticProtection(comptime Encoder: type) !void {
    inline for (.{
        .{ .fixed, "block_count" },           .{ .fixed, "fixed_block_count" },
        .{ .dynamic, "dynamic_block_count" }, .{ .stored, "stored_block_count" },
        .{ .fixed, "match_count" },           .{ .dynamic, "match_count" },
    }) |case| {
        var encoder = Encoder.initWithOptions(h.allocator, .{ .block_len = h.prefix.len, .compression = case[0] });
        defer encoder.deinit();
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(h.allocator);
        try h.feed(&encoder, h.prefix, &wire, 3, 5);
        encoder.blockFlush();
        try h.drain(&encoder, &wire, 5, false);
        try std.testing.expect(encoder.snapshot().history_len != 0);
        try h.feed(&encoder, h.prefix, &wire, 3, 5);
        @field(encoder, case[1]) = h.max_count;
        encoder.options.max_pending_output_len = 0;
        encoder.finish();
        try h.atomicFailure(&encoder, error.IntegerOverflow, "");
        try std.testing.expectEqual(@as(usize, 0), encoder.matcher.history.len);
        try std.testing.expectEqual(@as(usize, 0), encoder.matcher.block.len);
    }
    inline for (.{ .{ Flush.partial, "block_count" }, .{ Flush.partial, "fixed_block_count" }, .{ Flush.sync, "stored_block_count" }, .{ Flush.full, "stored_block_count" } }) |case| {
        var encoder = Encoder.initWithOptions(h.allocator, .{ .block_len = h.prefix.len, .compression = .fixed });
        defer encoder.deinit();
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(h.allocator);
        try h.feed(&encoder, h.prefix, &wire, 3, 5);
        encoder.blockFlush();
        try h.drain(&encoder, &wire, 5, false);
        @field(encoder, case[1]) = h.max_count;
        encoder.options.max_pending_output_len = 0;
        requestFlush(&encoder, case[0]);
        try h.atomicFailure(&encoder, error.IntegerOverflow, "");
        try std.testing.expect(encoder.snapshot().history_len != 0);
    }
    inline for (.{ "block_count", "stored_block_count" }) |field| {
        const plain = "S" ** 65536;
        var encoder = Encoder.initWithOptions(h.allocator, .{ .block_len = plain.len, .compression = .stored });
        defer encoder.deinit();
        _ = try h.step(&encoder, plain, &.{});
        // A 65536-byte emission publishes two stored blocks, so max-1 must
        // already fail before publishing either one or retaining any history.
        @field(encoder, field) = h.max_count - 1;
        encoder.finish();
        try h.atomicFailure(&encoder, error.IntegerOverflow, "");
    }
}

fn allocationFailure(comptime Encoder: type) !void {
    var backing = std.testing.FailingAllocator.init(h.allocator, .{});
    var encoder = Encoder.initWithOptions(backing.allocator(), .{ .block_len = 64, .compression = .stored });
    errdefer encoder.deinit();
    // Warm only the actual plain allocation to 64, then create a genuine
    // 21-byte pending block at the smaller block size. No fake wire is seeded.
    _ = try h.step(&encoder, "warm", &.{});
    encoder.resetWithOptions(.{ .block_len = h.prefix.len, .compression = .stored });
    try realPending(&encoder);
    const pending = try h.allocator.dupe(u8, encoder.pending.items);
    defer h.allocator.free(pending);
    const history = try h.allocator.dupe(u8, encoder.history.items);
    defer h.allocator.free(history);
    const before = encoder.snapshot();
    encoder.options.block_len = 64;
    backing.fail_index = backing.alloc_index;
    backing.resize_fail_index = backing.resize_index;
    var output: [128]u8 = @splat(0xa5);
    // Draining the old block and accepting 64 real bytes succeed. The next
    // pending allocation really fails while planning the following emission.
    const offered = "N" ** 65;
    try std.testing.expectError(error.OutOfMemory, h.step(&encoder, offered, &output));
    try std.testing.expect(backing.has_induced_failure);
    const failure = h.core.Progress{ .input_read = 64, .output_written = pending.len };
    try std.testing.expectEqualDeep(@as(?h.core.Progress, failure), encoder.failedProgress());
    try std.testing.expectEqualSlices(u8, pending, output[0..pending.len]);
    try h.guard(output[pending.len..]);
    try std.testing.expectEqual(before.input_read + 64, encoder.snapshot().input_read);
    try std.testing.expectEqual(before.output_written + pending.len, encoder.snapshot().output_written);
    try std.testing.expectEqual(before.block_count, encoder.snapshot().block_count);
    try std.testing.expectEqualSlices(u8, offered[0..64], encoder.plain.items);
    try std.testing.expectEqualSlices(u8, history, encoder.history.items);
    try h.sticky(&encoder, error.OutOfMemory);
    backing.fail_index = std.math.maxInt(usize);
    backing.resize_fail_index = std.math.maxInt(usize);
    encoder.resetExactSize(h.boundary + 9);
    try std.testing.expectEqual(@as(?h.Count, h.boundary + 9), encoder.expected_input_len);
    encoder.reset();
    try std.testing.expect(encoder.failedProgress() == null);
    try std.testing.expectEqual(@as(?h.Count, h.boundary + 9), encoder.expected_input_len);
    encoder.resetExactSize(9);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(h.allocator);
    try h.feed(&encoder, "recovered", &wire, 1, 1);
    try h.finish(&encoder, &wire, 1);
    try oracleDelta(wire.items, "recovered", h.ledger(encoder));
    encoder.deinit();
    try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
}

pub fn contracts(comptime Encoder: type) !void {
    try countMaxProtection(Encoder);
    try statisticProtection(Encoder);
    try allocationFailure(Encoder);
}
