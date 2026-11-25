const std = @import("std");
const h = @import("helpers.zig");
const t = h.t;

fn mutual(comptime D: type, comptime E: type) !void {
    var encoder = try h.init(D, E);
    defer encoder.deinit();
    var caller: [256]u8 = @splat(0xa5);
    const start = 64;
    const end = start + h.suffix.len;
    @memcpy(caller[start..end], h.suffix);
    // Equal starts, partial overlap in both directions, containment, and a
    // single output byte touching only the end of the offered input.
    const outputs = [_][]u8{
        caller[start..],
        caller[start + 1 ..],
        caller[start - 1 ..],
        caller[start - 16 .. end + 16],
        caller[start .. start + 1],
        caller[end - 1 .. end],
    };
    for (outputs) |output| try h.reject(&encoder, caller[start..end], output, &caller);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(t.allocator);
    try h.retry(D, &encoder, caller[start..end], &wire, h.suffix, "");
}

fn pendingDrain(comptime D: type, comptime E: type) !void {
    var encoder = try h.init(D, E);
    defer encoder.deinit();
    // For wrappers this retains a real outer header; raw encoders retain a
    // real non-final block. Both must protect input before the first drain.
    const accepted = try encoder.step(h.prefix, &.{});
    try t.expectEqual(@as(usize, 0), accepted.progress.output_written);
    try t.expect(encoder.snapshot().pending_output != 0);
    try h.reserveAll(&encoder);
    var caller: [256]u8 = @splat(0xa5);
    @memcpy(caller[32..][0..h.suffix.len], h.suffix);
    try h.reject(&encoder, caller[32..][0..h.suffix.len], caller[32..], &caller);
    try h.reject(&encoder, caller[32..][0..h.suffix.len], caller[31..33], &caller);

    var remaining: [256]u8 = undefined;
    const prefix_left = h.prefix[accepted.progress.input_read..];
    @memcpy(remaining[0..prefix_left.len], prefix_left);
    @memcpy(remaining[prefix_left.len..][0..h.suffix.len], h.suffix);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(t.allocator);
    try h.retry(D, &encoder, remaining[0 .. prefix_left.len + h.suffix.len], &wire, h.prefix ++ h.suffix, "");
}

fn adjacent(comptime D: type, comptime E: type) !void {
    inline for (.{ false, true }) |output_first| {
        var encoder = try h.init(D, E);
        defer encoder.deinit();
        var caller: [512]u8 = @splat(0xa5);
        const start = 64;
        const end = start + h.suffix.len;
        @memcpy(caller[start..end], h.suffix);
        const output = if (output_first) caller[32..start] else caller[end..][0..256];
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(t.allocator);
        try h.feedWithOutput(&encoder, caller[start..end], output, &wire);
        try h.finish(&encoder, &wire);
        try h.verify(D, E, wire.items, h.suffix, "");
        try t.expectEqualSlices(u8, h.suffix, caller[start..end]);
        for (caller[0..32]) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
        for (caller[end + 256 ..]) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
    }
}

fn emptyOutput(comptime D: type, comptime E: type) !void {
    var encoder = try h.init(D, E);
    defer encoder.deinit();
    var caller: [128]u8 = @splat(0xa5);
    @memcpy(caller[16..][0..h.suffix.len], h.suffix);
    const before = caller;
    const input = caller[16..][0..h.suffix.len];
    const accepted = try encoder.step(input, input[0..0]);
    try t.expectEqual(@as(usize, 0), accepted.progress.output_written);
    try t.expectEqualSlices(u8, &before, &caller);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(t.allocator);
    try h.retry(D, &encoder, input[accepted.progress.input_read..], &wire, h.suffix, "");
}

fn emptyReceiverAndDone(comptime D: type, comptime E: type) !void {
    var encoder = try h.init(D, E);
    defer encoder.deinit();
    const receiver = std.mem.asBytes(&encoder);
    const empty = receiver[1..1];
    const accepted = try encoder.step(empty, empty);
    try t.expectEqual(@as(usize, 0), accepted.progress.input_read);
    try t.expectEqual(@as(usize, 0), accepted.progress.output_written);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(t.allocator);
    try h.finish(&encoder, &wire);
    try h.verify(D, E, wire.items, "", "");
    try h.reserveAll(&encoder);
    var saved = try h.Saved.init(&encoder);
    defer saved.deinit();
    // Done plus empty input writes nothing. Its output may point into the
    // receiver or any retained allocation without becoming a mutable borrow.
    const done = try encoder.step(empty, receiver);
    try t.expectEqual(.done, done.status);
    try t.expectEqual(@as(usize, 0), done.progress.output_written);
    const owned = h.Owned.collect(&encoder);
    for (owned.entries[0..owned.len]) |bytes| {
        const result = try encoder.step("", bytes);
        try t.expectEqual(.done, result.status);
        try t.expectEqual(@as(usize, 0), result.progress.input_read);
        try t.expectEqual(@as(usize, 0), result.progress.output_written);
    }
    try saved.expectUnchanged(&encoder);
}

pub fn contracts(comptime D: type, comptime E: type) !void {
    try mutual(D, E);
    try pendingDrain(D, E);
    try adjacent(D, E);
    try emptyOutput(D, E);
    try emptyReceiverAndDone(D, E);
}
