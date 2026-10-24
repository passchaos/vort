const std = @import("std");
const xz = @import("../../xz.zig");
const allocator = std.testing.allocator;

fn complete(decoder: *xz.IncrementalDecoder, frame: []const u8, output: []u8, read_start: usize, written_start: usize) !void {
    var read = read_start;
    var written = written_start;
    while (true) {
        if (read == frame.len) decoder.finish();
        const end = @min(output.len, written + 37);
        const step = try decoder.step(frame[read..], output[written..end]);
        read += step.progress.input_read;
        written += step.progress.output_written;
        try std.testing.expectEqual(read, decoder.snapshot().input_read);
        try std.testing.expectEqual(written, decoder.snapshot().output_written);
        try std.testing.expect(decoder.peakWorkingMemoryBytes() >= decoder.workingMemoryBytes());
        if (step.status == .done) break;
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0 or read == frame.len);
    }
    try std.testing.expectEqual(frame.len, read);
    try std.testing.expectEqual(output.len, written);
}

test "XZ progressive active move rebinds raw guard and filtered scratch before continuing" {
    const payload = "\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff\x90moving-budget-state" ** 256;
    const chain = [_]xz.Filter{ xz.Filter.x86(0x1000), try xz.Filter.delta(256) };
    for ([_]bool{ false, true }) |filtered| {
        const frame = try xz.encodeAlloc(allocator, payload, .{
            .dictionary_size = 4096,
            .filters = if (filtered) &chain else &.{},
        });
        defer allocator.free(frame);
        const header_size = (@as(usize, frame[12]) + 1) * 4;
        try std.testing.expect(frame[12 + header_size] & 0x80 != 0);
        var tracking = std.testing.FailingAllocator.init(allocator, .{});
        var original = xz.IncrementalDecoder.initWithOptions(tracking.allocator(), .{ .max_working_memory = 512 * 1024 });
        var transferred = false;
        defer if (!transferred) original.deinit();
        const output = try allocator.alloc(u8, payload.len);
        defer allocator.free(output);
        const first = try original.step(frame, output[0..1]);
        try std.testing.expectEqual(@as(usize, 1), first.progress.output_written);
        try std.testing.expect(original.progressive.?.raw.snapshot().retained_compressed_capacity != 0);
        if (filtered) try std.testing.expect(original.decodedBufferCapacity() != 0);
        const before = original.snapshot();
        var moved = original;
        var move_released = false;
        defer if (!move_released) moved.deinit();
        transferred = true;
        original = undefined;
        try std.testing.expectEqual(before.working_bytes, moved.workingMemoryBytes());
        try std.testing.expectEqual(before.peak_working_bytes, moved.peakWorkingMemoryBytes());
        try complete(&moved, frame, output, first.progress.input_read, first.progress.output_written);
        try std.testing.expectEqualSlices(u8, payload, output);
        moved.deinit();
        move_released = true;
        try std.testing.expectEqual(tracking.allocated_bytes, tracking.freed_bytes);
    }
}

test "XZ progressive active move keeps prevalidated pending output in its child budget" {
    const payload = "\x90\xe8\x10\x00\x00\x00atomic-owned-pending" ** 2048;
    const chain = [_]xz.Filter{ xz.Filter.x86(0), try xz.Filter.delta(256) };
    const frame = try xz.encodeAlloc(allocator, payload, .{ .dictionary_size = 4096, .filters = &chain });
    defer allocator.free(frame);
    for ([_]bool{ false, true }) |continue_decode| {
        var tracking = std.testing.FailingAllocator.init(allocator, .{});
        var original = xz.IncrementalDecoder.initWithOptions(tracking.allocator(), .{
            .input_policy = .prevalidated_block,
            .max_working_memory = 512 * 1024,
        });
        var transferred = false;
        defer if (!transferred) original.deinit();
        const first = try original.step(frame, &.{});
        try std.testing.expectEqual(.need_output, first.status);
        try std.testing.expectEqual(@as(usize, 0), first.progress.output_written);
        try std.testing.expect(original.pending_output.len == payload.len);
        try std.testing.expect(original.decodedBufferCapacity() >= payload.len);
        const before = original.snapshot();
        var moved = original;
        var move_released = false;
        defer if (!move_released) moved.deinit();
        transferred = true;
        original = undefined;
        try std.testing.expectEqual(before.working_bytes, moved.workingMemoryBytes());
        if (continue_decode) {
            const output = try allocator.alloc(u8, payload.len);
            defer allocator.free(output);
            try complete(&moved, frame, output, first.progress.input_read, 0);
            try std.testing.expectEqualSlices(u8, payload, output);
        }
        moved.deinit();
        move_released = true;
        try std.testing.expectEqual(tracking.allocated_bytes, tracking.freed_bytes);
    }
}

test "XZ progressive active move directly deinitializes partially published filtered state" {
    const payload = "\x90\xe8\x10\x00\x00\x00moving-direct-teardown" ** 256;
    const chain = [_]xz.Filter{xz.Filter.x86(0)};
    const frame = try xz.encodeAlloc(allocator, payload, .{ .dictionary_size = 4096, .filters = &chain });
    defer allocator.free(frame);
    var tracking = std.testing.FailingAllocator.init(allocator, .{});
    var original = xz.IncrementalDecoder.init(tracking.allocator());
    var transferred = false;
    defer if (!transferred) original.deinit();
    var output: [1]u8 = undefined;
    _ = try original.step(frame, &output);
    try std.testing.expect(original.progressive.?.inverse != null);
    try std.testing.expect(original.decodedBufferCapacity() != 0);
    var moved = original;
    transferred = true;
    original = undefined;
    moved.deinit();
    try std.testing.expectEqual(tracking.allocated_bytes, tracking.freed_bytes);
}
