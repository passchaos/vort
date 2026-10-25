const std = @import("std");
const xz = @import("../../xz.zig");
const container = @import("../container.zig");
const h = @import("test_helpers.zig");
const a = std.testing.allocator;

pub fn rejectAcrossRoutes(wire: []const u8, expected: anyerror, plain_len: usize) !void {
    try std.testing.expectError(expected, xz.inspect(a, wire));
    try std.testing.expectError(expected, xz.decodedSize(a, wire));
    try std.testing.expectError(expected, xz.decodeAlloc(a, wire));
    const output = try a.alloc(u8, plain_len + 17);
    defer a.free(output);
    @memset(output, 0xa5);
    try std.testing.expectError(expected, xz.decodeInto(a, wire, output));
    try h.untouched(output);
    const alias = try a.alloc(u8, wire.len + plain_len + 33);
    defer a.free(alias);
    @memset(alias, 0xa5);
    @memcpy(alias[16..][0..wire.len], wire);
    const original = try a.dupe(u8, alias);
    defer a.free(original);
    try std.testing.expectError(expected, xz.decodeInto(a, alias[16..][0..wire.len], alias[0..plain_len]));
    try std.testing.expectEqualSlices(u8, original, alias);
    for ([_]xz.IncrementalDecoder.InputPolicy{ .progressive_block, .prevalidated_block }) |policy| {
        var decoder = xz.IncrementalDecoder.initWithOptions(a, .{ .input_policy = policy, .expected_output_len = plain_len });
        defer decoder.deinit();
        var offset: usize = 0;
        var finished = false;
        var failed = false;
        for (0..(wire.len + plain_len) * 8 + 4096) |_| {
            if (offset == wire.len and !finished) {
                decoder.finish();
                finished = true;
            }
            var chunk: [17]u8 = @splat(0xa5);
            const before = decoder.snapshot();
            const step = decoder.step(wire[offset..@min(wire.len, offset + 3)], &chunk) catch |err| {
                try std.testing.expectEqual(expected, err);
                const after = decoder.snapshot();
                try std.testing.expectEqual(decoder.last_step_progress.input_read, after.input_read - before.input_read);
                try std.testing.expectEqual(decoder.last_step_progress.output_written, after.output_written - before.output_written);
                try h.untouched(chunk[decoder.last_step_progress.output_written..]);
                failed = true;
                break;
            };
            offset += step.progress.input_read;
            try h.untouched(chunk[step.progress.output_written..]);
            try std.testing.expect(step.status != .done);
        }
        try std.testing.expect(failed);
    }
}

test "XZ block sizes CRC valid wrong declarations reject body routes while header remains structural" {
    const input = h.plain[0..37];
    var opts = h.options();
    opts.check = .crc32;
    const wire = try xz.encodeStoredAlloc(a, input, opts);
    defer a.free(wire);
    const layout = try h.parse(wire);
    defer layout.deinit();
    const entry = layout.blocks[0];
    for ([_]bool{ false, true }) |unpacked| {
        const corrupt = try a.dupe(u8, wire);
        defer a.free(corrupt);
        const field = if (unpacked) entry.header.unpacked.? else entry.header.packed_size.?;
        try std.testing.expectEqual(@as(usize, 1), field.width);
        corrupt[field.start] += 1;
        h.resignHeader(corrupt, entry.header);
        const structural = try container.parseBlockHeader(corrupt, entry.header.start);
        try std.testing.expectEqual(@as(?u64, field.value + 1), if (unpacked) structural.unpacked_size else structural.packed_size);
        try rejectAcrossRoutes(corrupt, error.SizeMismatch, input.len);
    }
    const reserved = try a.dupe(u8, wire);
    defer a.free(reserved);
    reserved[entry.header.start + 1] |= 4;
    h.resignHeader(reserved, entry.header);
    try std.testing.expectError(error.InvalidXzHeader, container.parseBlockHeader(reserved, 12));
    try rejectAcrossRoutes(reserved, error.InvalidXzHeader, input.len);
    var false_opts = opts;
    false_opts.include_block_sizes = false;
    const false_wire = try xz.encodeStoredAlloc(a, input, false_opts);
    defer a.free(false_wire);
    const false_layout = try h.parse(false_wire);
    defer false_layout.deinit();
    const wrong_index = try a.dupe(u8, false_wire);
    defer a.free(wrong_index);
    wrong_index[false_layout.blocks[0].index_plain.?.start] += 1;
    std.mem.writeInt(u32, wrong_index[false_layout.index_crc..][0..4], std.hash.Crc32.hash(wrong_index[false_layout.index_start..false_layout.index_crc]), .little);
    try rejectAcrossRoutes(wrong_index, error.InvalidXzStream, input.len);
}

test "XZ block sizes incremental pending exact below and allocation refusal keep accepted bytes retryable" {
    const input = try h.fixture(128);
    defer a.free(input);
    var opts = h.options();
    opts.check = .crc32;
    const expected = try xz.encodeStoredAlloc(a, input, opts);
    defer a.free(expected);
    const layout = try h.parse(expected);
    defer layout.deinit();
    const pending = layout.blocks[0].end - layout.blocks[0].header.start;
    try std.testing.expect(pending > 12);
    var exact_opts = h.streamOptions(opts, .stored);
    exact_opts.max_pending_output_len = pending;
    var exact = try xz.IncrementalEncoder.initExactSize(a, exact_opts, input.len);
    defer exact.deinit();
    const exact_wire = try h.drive(&exact, input);
    defer a.free(exact_wire);
    try std.testing.expectEqualSlices(u8, expected, exact_wire);
    for ([_]bool{ false, true }) |allocation_failure| {
        var heap = std.testing.FailingAllocator.init(a, .{ .resize_fail_index = 0 });
        var failure_opts = exact_opts;
        if (!allocation_failure) failure_opts.max_pending_output_len = pending - 1;
        var encoder = try xz.IncrementalEncoder.initExactSize(heap.allocator(), failure_opts, input.len);
        defer encoder.deinit();
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(a);
        try h.feed(&encoder, &wire, "");
        try encoder.plain.ensureTotalCapacity(heap.allocator(), input.len);
        try encoder.records.ensureTotalCapacity(heap.allocator(), 1);
        if (allocation_failure) heap.fail_index = heap.alloc_index;
        var output: [257]u8 = @splat(0xa5);
        const before = encoder.snapshot();
        const result = encoder.step(input, &output);
        if (allocation_failure) try std.testing.expectError(error.OutOfMemory, result) else try std.testing.expectError(error.OutputLimitExceeded, result);
        try h.untouched(&output);
        try std.testing.expectEqual(input.len, encoder.snapshot().input_read);
        try std.testing.expectEqual(input.len, encoder.snapshot().buffered_input);
        try std.testing.expectEqual(before.output_written, encoder.snapshot().output_written);
        try std.testing.expectEqual(@as(usize, 0), encoder.records.items.len);
        try std.testing.expectEqual(@as(usize, 0), encoder.pending.items.len);
        heap.fail_index = std.math.maxInt(usize);
        encoder.options.max_pending_output_len = pending;
        const ending = try h.drive(&encoder, "");
        defer a.free(ending);
        try wire.appendSlice(a, ending);
        try std.testing.expectEqualSlices(u8, expected, wire.items);
    }
}

test "XZ block sizes flush nextStream validation and reset preserve size option lifecycle" {
    const input = h.plain[0..64];
    var opts = h.options();
    opts.check = .crc32;
    var encoder = try xz.IncrementalEncoder.initExactSize(a, h.streamOptions(opts, .stored), input.len);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try h.feed(&encoder, &wire, input[0..37]);
    encoder.flush();
    try h.drain(&encoder, &wire, .need_input);
    const flushed_len = wire.items.len;
    encoder.flush();
    try h.drain(&encoder, &wire, .need_input);
    try std.testing.expectEqual(flushed_len, wire.items.len);
    try h.feed(&encoder, &wire, input[37..]);
    encoder.finish();
    try h.drain(&encoder, &wire, .done);
    const parsed = try h.parse(wire.items);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 2), parsed.blocks.len);
    try std.testing.expectEqual(@as(usize, 37), parsed.blocks[0].plain);
    try std.testing.expectEqual(@as(usize, 27), parsed.blocks[1].plain);
    const before = encoder.snapshot();
    var invalid = encoder.options;
    invalid.block_size = 0;
    try std.testing.expectError(error.InvalidBlockPlan, encoder.nextStreamExactSize(invalid, input.len));
    try std.testing.expectEqual(before, encoder.snapshot());
    var next = h.streamOptions(opts, .stored);
    next.include_block_sizes = false;
    try encoder.nextStreamExactSize(next, input.len);
    const false_wire = try h.drive(&encoder, input);
    defer a.free(false_wire);
    try h.checkWire(false_wire, input, false);
    next.include_block_sizes = true;
    try encoder.nextStreamExactSize(next, input.len);
    const true_wire = try h.drive(&encoder, input);
    defer a.free(true_wire);
    try h.checkWire(true_wire, input, true);
    encoder.reset();
    const reset = try h.drive(&encoder, input);
    defer a.free(reset);
    try std.testing.expectEqualSlices(u8, true_wire, reset);
}
