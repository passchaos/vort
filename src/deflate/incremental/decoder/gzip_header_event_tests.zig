const std = @import("std");
const core = @import("../../../core.zig");
const t = std.testing;

// RFC 1952 reference member: FTEXT, XLEN=6, FNAME, FCOMMENT and FHCRC.
const rich_header = "\x1f\x8b\x08\x1f\x04\x03\x02\x01\x02\x03" ++
    "\x06\x00VX\x02\x00\x00\xff" ++ "a.txt\x00hi\x00\xc3\xc9";
const rich = rich_header ++ "\x73\x04\x00\x8b\x9e\xd9\xd3\x01\x00\x00\x00"; // A
const plain_header = "\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\xff";
const b_body = "\x73\x02\x00\x31\xcf\xd0\x4a\x01\x00\x00\x00";
const plain = plain_header ++ b_body; // B
const sentinel = 0xa5;

pub fn contracts(comptime Decoder: type) !void {
    try fragmented(Decoder);
    try concatenated(Decoder);
    try emptyFields(Decoder);
    try blockBoundary(Decoder);
    try rejected(Decoder);
    try cloneAndChangeObserver(Decoder);
    try resetAndBorrowAdmission(Decoder);
}

fn richEvents(comptime Decoder: type) [5]Decoder.HeaderEvent {
    return .{
        .{ .start = .{
            .member_index = 0,
            .member_offset = 0,
            .text = true,
            .mtime = 0x01020304,
            .extra_flags = 2,
            .os = 3,
            .has_extra = true,
            .has_filename = true,
            .has_comment = true,
            .has_header_crc = true,
        } },
        field(Decoder, .extra, 0, "VX\x02\x00\x00\xff"),
        field(Decoder, .filename, 0, "a.txt"),
        field(Decoder, .comment, 0, "hi"),
        .{ .complete = .{ .member_index = 0, .header_end_offset = 29 } },
    };
}

fn field(comptime Decoder: type, name: Decoder.HeaderField, offset: usize, bytes: []const u8) Decoder.HeaderEvent {
    return .{ .field = .{ .member_index = 0, .field = name, .offset = offset, .bytes = bytes } };
}

/// Compare each borrowed slice inside the callback. Match logical fields rather
/// than requiring a particular chunk size or coalescing across input calls.
fn ObserverLog(comptime Decoder: type) type {
    return struct {
        const Self = @This();
        expected: []const Decoder.HeaderEvent,
        unwritten: []const u8 = &.{},
        next: usize = 0,
        field_read: usize = 0,
        callbacks: usize = 0,
        failure: ?anyerror = null,

        fn observer(self: *Self) Decoder.HeaderObserver {
            return .{ .context = self, .on_event = onEvent };
        }

        fn onEvent(context: ?*anyopaque, event: Decoder.HeaderEvent) void {
            const self: *Self = @ptrCast(@alignCast(context.?));
            self.callbacks += 1;
            if (self.failure != null) return;
            self.match(event) catch |err| {
                self.failure = err;
            };
        }

        fn match(self: *Self, event: Decoder.HeaderEvent) !void {
            try t.expect(self.next < self.expected.len);
            const expected = self.expected[self.next];
            try t.expectEqual(std.meta.activeTag(expected), std.meta.activeTag(event));
            switch (event) {
                .start => |header| try t.expectEqualDeep(expected.start, header),
                .field => |chunk| {
                    try t.expectEqual(expected.field.member_index, chunk.member_index);
                    try t.expectEqual(expected.field.field, chunk.field);
                    try t.expectEqual(expected.field.offset + self.field_read, chunk.offset);
                    const rest = expected.field.bytes[self.field_read..];
                    try t.expect(chunk.bytes.len != 0 and chunk.bytes.len <= rest.len);
                    try t.expectEqualSlices(u8, rest[0..chunk.bytes.len], chunk.bytes);
                    self.field_read += chunk.bytes.len;
                    if (self.field_read != expected.field.bytes.len) return;
                    self.field_read = 0;
                },
                .complete => |complete| {
                    try t.expectEqualDeep(expected.complete, complete);
                    for (self.unwritten) |byte| try t.expectEqual(@as(u8, sentinel), byte);
                },
            }
            self.next += 1;
        }

        fn expectPosition(self: *const Self, next: usize, field_read: usize) !void {
            if (self.failure) |err| return err;
            try t.expectEqual(next, self.next);
            try t.expectEqual(field_read, self.field_read);
        }

        fn expectDone(self: *const Self) !void {
            try self.expectPosition(self.expected.len, 0);
        }
    };
}

fn expectStep(step: core.StepResult, status: core.StepResult.Status, input_read: usize, output_written: usize) !void {
    try t.expectEqualDeep(core.StepResult{
        .status = status,
        .progress = .{ .input_read = input_read, .output_written = output_written },
    }, step);
}

fn fragmented(comptime Decoder: type) !void {
    const expected = richEvents(Decoder);
    var history: [32 * 1024]u8 = undefined;
    for ([_]usize{ 1, 8 }) |fragment_size| {
        var decoder = try Decoder.init(.{}, &history);
        var output = [_]u8{sentinel};
        var log: ObserverLog(Decoder) = .{ .expected = &expected, .unwritten = &output };
        const observer = log.observer();
        var read: usize = 0;
        // Withhold the second FHCRC byte to distinguish provisional events
        // from a confirmed header, even when earlier fields are all present.
        const unconfirmed = rich_header.len - 1;
        while (read < unconfirmed) {
            const before_poll = log.callbacks;
            try expectStep(try decoder.stepWithHeaderEvents(&.{}, &.{}, observer), .need_input, 0, 0);
            try t.expectEqual(before_poll, log.callbacks);
            const n = @min(fragment_size, unconfirmed - read);
            try expectStep(try decoder.stepWithHeaderEvents(rich[read..][0..n], &.{}, observer), .need_input, n, 0);
            read += n;
        }
        try log.expectPosition(expected.len - 1, 0);
        const blocked = try decoder.stepWithHeaderEvents(rich[read..], &.{}, observer);
        try t.expectEqual(core.StepResult.Status.need_output, blocked.status);
        try t.expectEqual(@as(usize, 0), blocked.progress.output_written);
        try log.expectDone();
        read += blocked.progress.input_read;
        try expectStep(try decoder.stepWithHeaderEvents(rich[read..], &output, observer), .done, rich.len - read, 1);
        try t.expectEqualStrings("A", &output);
        try log.expectDone();
        try decoder.finish();
    }
}

fn concatenated(comptime Decoder: type) !void {
    const expected = richEvents(Decoder) ++ [_]Decoder.HeaderEvent{
        .{ .start = .{
            .member_index = 1,
            .member_offset = rich.len,
            .text = false,
            .mtime = 0,
            .extra_flags = 0,
            .os = 255,
            .has_extra = false,
            .has_filename = false,
            .has_comment = false,
            .has_header_crc = false,
        } },
        .{ .complete = .{ .member_index = 1, .header_end_offset = rich.len + plain_header.len } },
    };
    const members_end = rich.len + plain.len;
    const tail = "\x1ftrailing";
    const wire = rich ++ plain ++ tail;
    var history: [32 * 1024]u8 = undefined;
    var decoder = try Decoder.init(.{ .allow_concatenated = true, .allow_trailing_data = true }, &history);
    var output: [2]u8 = @splat(sentinel);
    var log: ObserverLog(Decoder) = .{ .expected = &expected, .unwritten = output[0..1] };
    const observer = log.observer();
    // Split the next member's magic, then split the rejected tail's magic too.
    try expectStep(try decoder.stepWithHeaderEvents(wire[0 .. rich.len + 1], output[0..1], observer), .need_input, rich.len + 1, 1);
    try log.expectPosition(expected.len - 2, 0);
    log.unwritten = output[1..];
    try expectStep(try decoder.stepWithHeaderEvents(wire[rich.len + 1 .. members_end + 1], output[1..], observer), .need_input, plain.len, 1);
    try log.expectDone();
    try expectStep(try decoder.stepWithHeaderEvents(wire[members_end + 1 ..], &.{}, observer), .done, 0, 0);
    try t.expectEqualStrings(tail[0..1], decoder.trailingPrefix());
    try t.expectEqual(@as(?core.StreamCount, members_end), decoder.memberEndOffset());
    try t.expectEqualStrings("AB", &output);
    try log.expectDone();
    try decoder.finish();
}

fn emptyFields(comptime Decoder: type) !void {
    // XLEN=0, two NUL terminators, and a valid FHCRC.
    const header = "\x1f\x8b\x08\x1e\x00\x00\x00\x00\x00\xff\x00\x00\x00\x00\x56\x35";
    var start = richEvents(Decoder)[0].start;
    start.text = false;
    start.mtime = 0;
    start.extra_flags = 0;
    start.os = 255;
    const expected = [_]Decoder.HeaderEvent{
        .{ .start = start },
        .{ .complete = .{ .member_index = 0, .header_end_offset = header.len } },
    };
    var log: ObserverLog(Decoder) = .{ .expected = &expected };
    var history: [32 * 1024]u8 = undefined;
    var decoder = try Decoder.init(.{}, &history);
    var output = [_]u8{sentinel};
    try expectStep(try decoder.stepWithHeaderEvents(header ++ b_body, &output, log.observer()), .done, header.len + b_body.len, 1);
    try t.expectEqualStrings("B", &output);
    try log.expectDone();
    try decoder.finish();
}

fn blockBoundary(comptime Decoder: type) !void {
    const first_block = "\x00\x01\x00\xfe\xff" ++ "A";
    const last_block = "\x01\x01\x00\xfe\xff" ++ "B";
    const footer = "\x07\x4c\x69\x30\x02\x00\x00\x00";
    const frame = rich_header ++ first_block ++ last_block ++ footer;
    const expected = richEvents(Decoder);
    var history: [32 * 1024]u8 = undefined;
    var decoder = try Decoder.init(.{}, &history);
    var output: [2]u8 = @splat(sentinel);
    var log: ObserverLog(Decoder) = .{ .expected = &expected, .unwritten = &output };
    const observer = log.observer();
    const paused = try decoder.stepToBlockBoundaryWithHeaderEvents(frame, &output, observer);
    try t.expect(paused.block_boundary);
    try t.expect(decoder.atBlockBoundary());
    try t.expectEqual(@as(usize, rich_header.len + first_block.len), paused.progress.input_read);
    try t.expectEqual(@as(usize, 1), paused.progress.output_written);
    try t.expectEqualSlices(u8, &.{ 'A', sentinel }, &output);
    try log.expectDone();
    const rest = frame[paused.progress.input_read..];
    try expectStep(try decoder.stepToBlockBoundaryWithHeaderEvents(rest, output[1..], observer), .done, rest.len, 1);
    try t.expectEqualStrings("AB", &output);
    try log.expectDone();
    try decoder.finish();
}

fn rejected(comptime Decoder: type) !void {
    var bad_crc = rich.*;
    bad_crc[rich_header.len - 1] ^= 1;
    const expected = richEvents(Decoder);
    const cases = [_]struct {
        frame: []const u8,
        options: Decoder.Options = .{},
        err: Decoder.Error,
        input_read: core.StreamCount,
        events: usize,
    }{
        .{ .frame = &bad_crc, .err = error.BadGzipHeader, .input_read = rich_header.len, .events = 4 },
        .{ .frame = rich[0 .. rich_header.len - 1], .err = error.TruncatedFrame, .input_read = rich_header.len - 1, .events = 4 },
        .{ .frame = rich, .options = .{ .max_header_metadata_len = 5 }, .err = error.OutputLimitExceeded, .input_read = 12, .events = 1 },
    };
    var history: [32 * 1024]u8 = undefined;
    for (cases) |case| {
        var decoder = try Decoder.init(case.options, &history);
        var output = [_]u8{sentinel};
        var log: ObserverLog(Decoder) = .{ .expected = expected[0..case.events] };
        if (case.err == error.TruncatedFrame) {
            try expectStep(try decoder.stepWithHeaderEvents(case.frame, &output, log.observer()), .need_input, case.frame.len, 0);
            try log.expectDone();
            try t.expectError(error.TruncatedFrame, decoder.finish());
        } else {
            try t.expectError(case.err, decoder.stepWithHeaderEvents(case.frame, &output, log.observer()));
        }
        try log.expectDone();
        const snapshot = decoder.snapshot();
        try t.expectEqual(case.input_read, snapshot.total_input);
        try t.expectEqual(@as(core.StreamCount, 0), snapshot.total_output);
        try t.expectEqual(@as(u8, sentinel), output[0]);
    }
}

fn cloneAndChangeObserver(comptime Decoder: type) !void {
    const split = 20; // After the shared "a." filename prefix.
    const clone_tail = "bin\x00yo\x00\xeb\x50" ++ b_body; // Independent valid FHCRC and body.
    var source_history: [32 * 1024]u8 = undefined;
    var clone_history: [32 * 1024]u8 = undefined;
    var source = try Decoder.init(.{}, &source_history);
    var clone: Decoder = undefined;
    const expected = richEvents(Decoder);
    var prefix: ObserverLog(Decoder) = .{ .expected = &expected };
    try expectStep(try source.stepWithHeaderEvents(rich[0..split], &.{}, prefix.observer()), .need_input, split, 0);
    try prefix.expectPosition(2, 2);
    const prefix_callbacks = prefix.callbacks;
    try source.cloneInto(&clone, .{ .history = &clone_history });

    // Skip the `b` without an observer. A new observer must start at offset 3,
    // not receive the omitted byte or replay any earlier events from the clone.
    try expectStep(try clone.step(clone_tail[0..1], &.{}), .need_input, 1, 0);
    const clone_expected = [_]Decoder.HeaderEvent{
        field(Decoder, .filename, 3, "in"),
        field(Decoder, .comment, 0, "yo"),
        expected[4],
    };
    var clone_log: ObserverLog(Decoder) = .{ .expected = &clone_expected };
    var clone_output = [_]u8{sentinel};
    try expectStep(try clone.stepWithHeaderEvents(clone_tail[1..], &clone_output, clone_log.observer()), .done, clone_tail.len - 1, 1);
    try t.expectEqualStrings("B", &clone_output);
    try clone_log.expectDone();
    try clone.finish();

    const source_expected = [_]Decoder.HeaderEvent{ field(Decoder, .filename, 2, "txt"), expected[3], expected[4] };
    var source_log: ObserverLog(Decoder) = .{ .expected = &source_expected };
    var source_output = [_]u8{sentinel};
    try expectStep(try source.stepWithHeaderEvents(rich[split..], &source_output, source_log.observer()), .done, rich.len - split, 1);
    try t.expectEqualStrings("A", &source_output);
    try source_log.expectDone();
    try source.finish();
    try prefix.expectPosition(2, 2);
    try t.expectEqual(prefix_callbacks, prefix.callbacks);
}

fn resetAndBorrowAdmission(comptime Decoder: type) !void {
    const expected = richEvents(Decoder);
    var history: [32 * 1024]u8 = undefined;
    var decoder = try Decoder.init(.{}, &history);
    var abandoned: ObserverLog(Decoder) = .{ .expected = &expected };
    var aliased = rich.*;
    const before = decoder.snapshot();
    try t.expectError(error.InvalidBlockPlan, decoder.stepWithHeaderEvents(&aliased, aliased[29..30], abandoned.observer()));
    try t.expectEqualDeep(before, decoder.snapshot());
    try t.expectEqualSlices(u8, rich, &aliased);
    try t.expectEqual(@as(usize, 0), abandoned.callbacks);

    try expectStep(try decoder.stepWithHeaderEvents(rich[0..20], &.{}, abandoned.observer()), .need_input, 20, 0);
    try abandoned.expectPosition(2, 2);
    const callbacks = abandoned.callbacks;
    decoder.reset();

    var restarted: ObserverLog(Decoder) = .{ .expected = &expected };
    var output = [_]u8{sentinel};
    try expectStep(try decoder.stepWithHeaderEvents(rich, &output, restarted.observer()), .done, rich.len, 1);
    try t.expectEqualStrings("A", &output);
    try restarted.expectDone();
    try t.expectEqual(callbacks, abandoned.callbacks);
    try decoder.finish();
}
