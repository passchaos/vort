const std = @import("std");
const core = @import("../../core.zig");
const t = std.testing;

// Same RFC 1952 fixture as the direct gzip header-event tests.
const rich_header = "\x1f\x8b\x08\x1f\x04\x03\x02\x01\x02\x03" ++
    "\x06\x00VX\x02\x00\x00\xff" ++ "a.txt\x00hi\x00\xc3\xc9";
const rich = rich_header ++ "\x73\x04\x00\x8b\x9e\xd9\xd3\x01\x00\x00\x00"; // A
const plain_header = "\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\xff";
const plain = plain_header ++ "\x73\x02\x00\x31\xcf\xd0\x4a\x01\x00\x00\x00"; // B
const first_block = "\x00\x01\x00\xfe\xffA";
const last_block = "\x01\x01\x00\xfe\xffB";
const zlib_header = "\x78\x01";
const zlib_blocks = zlib_header ++ first_block ++ last_block ++ "\x00\xc6\x00\x84";
const sentinel: u8 = 0xa5;

pub fn contracts(comptime D: type) !void {
    const Auto = D.ZlibOrGzipIncrementalDecoder;
    const Gzip = D.GzipIncrementalDecoder;
    try t.expect(Auto.HeaderObserver == Gzip.HeaderObserver);
    try t.expect(Auto.HeaderEvent == Gzip.HeaderEvent);
    try t.expect(Auto.HeaderField == Gzip.HeaderField);
    try t.expect(Auto.MemberHeader == Gzip.MemberHeader);
    try fragmented(Auto);
    try concatenatedGzip(Auto);
    try rejected(Auto);
    try blockBoundaries(Auto);
    try dictionaryZlib(Auto);
    try cloneAndReset(Auto);
}

fn field(comptime Auto: type, name: Auto.HeaderField, offset: usize, bytes: []const u8) Auto.HeaderEvent {
    return .{ .field = .{ .member_index = 0, .field = name, .offset = offset, .bytes = bytes } };
}

fn richEvents(comptime Auto: type) [5]Auto.HeaderEvent {
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
        field(Auto, .extra, 0, "VX\x02\x00\x00\xff"),
        field(Auto, .filename, 0, "a.txt"),
        field(Auto, .comment, 0, "hi"),
        .{ .complete = .{ .member_index = 0, .header_end_offset = rich_header.len } },
    };
}

// Match logical fields, not the number of chunks, and inspect borrowed bytes
// synchronously rather than storing the event's slices beyond the callback.
fn Log(comptime Auto: type) type {
    return struct {
        const Self = @This();
        expected: []const Auto.HeaderEvent,
        unwritten: []const u8 = &.{},
        next: usize = 0,
        field_read: usize = 0,
        calls: usize = 0,
        failure: ?anyerror = null,

        fn observer(self: *Self) Auto.HeaderObserver {
            return .{ .context = self, .on_event = receive };
        }

        fn receive(context: ?*anyopaque, event: Auto.HeaderEvent) void {
            const self: *Self = @ptrCast(@alignCast(context.?));
            self.calls += 1;
            if (self.failure != null) return;
            self.match(event) catch |err| {
                self.failure = err;
            };
        }

        fn match(self: *Self, event: Auto.HeaderEvent) !void {
            try t.expect(self.next < self.expected.len);
            const expected = self.expected[self.next];
            try t.expectEqual(std.meta.activeTag(expected), std.meta.activeTag(event));
            switch (event) {
                .start => |header| try t.expectEqualDeep(expected.start, header),
                .field => |chunk| {
                    try t.expectEqual(expected.field.member_index, chunk.member_index);
                    try t.expectEqual(expected.field.field, chunk.field);
                    try t.expectEqual(expected.field.offset + self.field_read, chunk.offset);
                    const remaining = expected.field.bytes[self.field_read..];
                    try t.expect(chunk.bytes.len != 0 and chunk.bytes.len <= remaining.len);
                    try t.expectEqualSlices(u8, remaining[0..chunk.bytes.len], chunk.bytes);
                    self.field_read += chunk.bytes.len;
                    if (self.field_read != expected.field.bytes.len) return;
                    self.field_read = 0;
                },
                .complete => |complete| {
                    try t.expectEqualDeep(expected.complete, complete);
                    for (self.unwritten) |byte| try t.expectEqual(sentinel, byte);
                },
            }
            self.next += 1;
        }

        fn position(self: *const Self, next: usize, field_read: usize) !void {
            if (self.failure) |err| return err;
            try t.expectEqual(next, self.next);
            try t.expectEqual(field_read, self.field_read);
        }

        fn done(self: *const Self) !void {
            try self.position(self.expected.len, 0);
        }
    };
}

fn expectStep(step: core.StepResult, status: core.StepResult.Status, read: usize, written: usize) !void {
    try t.expectEqual(status, step.status);
    try t.expectEqualDeep(core.Progress{ .input_read = read, .output_written = written }, step.progress);
}

fn expectFailedProgress(decoder: anytype, local: usize, total: core.StreamCount) !void {
    const snapshot = decoder.snapshot();
    const progress: core.Progress = .{ .input_read = local };
    try t.expectEqualDeep(progress, snapshot.last_step_progress);
    try t.expectEqualDeep(@as(?core.Progress, progress), decoder.diagnostics().last_step_progress);
    try t.expectEqual(total, snapshot.total_input);
    try t.expectEqual(@as(core.StreamCount, 0), snapshot.total_output);
    try t.expectEqual(@as(?core.StreamCount, total), snapshot.last_error_input_offset);
}

fn fragmented(comptime Auto: type) !void {
    const expected = richEvents(Auto);
    var history: [32 * 1024]u8 = undefined;
    for ([_]usize{ 1, 8 }) |chunk_size| {
        var decoder = try Auto.init(.{}, &history);
        var output = [_]u8{sentinel};
        var log: Log(Auto) = .{ .expected = &expected, .unwritten = &output };
        const observer = log.observer();
        try expectStep(try decoder.stepWithHeaderEvents(rich[0..1], &.{}, observer), .need_input, 1, 0);
        try t.expect(decoder.selectedFormat() == null);
        try log.position(0, 0);
        try expectStep(try decoder.stepWithHeaderEvents(rich[1..2], &.{}, observer), .need_input, 1, 0);
        try t.expectEqual(@as(?Auto.Format, .gzip), decoder.selectedFormat());
        try log.position(0, 0);

        // Hold the last FHCRC byte back even when all optional fields arrived.
        const unconfirmed = rich_header.len - 1;
        var read: usize = 2;
        while (read < unconfirmed) {
            const before_poll = log.calls;
            try expectStep(try decoder.stepWithHeaderEvents(&.{}, &.{}, observer), .need_input, 0, 0);
            try t.expectEqual(before_poll, log.calls);
            const n = @min(chunk_size, unconfirmed - read);
            try expectStep(try decoder.stepWithHeaderEvents(rich[read..][0..n], &.{}, observer), .need_input, n, 0);
            read += n;
            if (read < plain_header.len) try log.position(0, 0);
        }
        try log.position(expected.len - 1, 0);
        try expectStep(try decoder.stepWithHeaderEvents(rich[unconfirmed..rich_header.len], &output, observer), .need_input, 1, 0);
        try log.done();
        try expectStep(try decoder.stepWithHeaderEvents(rich[rich_header.len..], &output, observer), .done, rich.len - rich_header.len, 1);
        try log.done();
        try t.expectEqualStrings("A", &output);
        try t.expectEqual(@as(core.StreamCount, rich.len), decoder.snapshot().total_input);
        try decoder.finish();
    }
}

fn concatenatedGzip(comptime Auto: type) !void {
    const expected = richEvents(Auto) ++ [_]Auto.HeaderEvent{
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
    const wire = rich ++ plain ++ zlib_blocks;
    const gzip_end = rich.len + plain.len;
    var history: [32 * 1024]u8 = undefined;
    var decoder = try Auto.init(.{ .allow_concatenated = true, .allow_trailing_data = true }, &history);
    var output: [2]u8 = @splat(sentinel);
    var log: Log(Auto) = .{ .expected = &expected, .unwritten = output[0..1] };
    const observer = log.observer();
    const split = rich.len + 1; // The second member's magic spans calls too.
    try expectStep(try decoder.stepWithHeaderEvents(wire[0..split], output[0..1], observer), .need_input, split, 1);
    try log.position(expected.len - 2, 0);
    log.unwritten = output[1..];
    const last = try decoder.stepWithHeaderEvents(wire[split..], output[1..], observer);
    try expectStep(last, .done, gzip_end - split, 1);
    try log.done();
    try t.expectEqualStrings("AB", &output);
    try t.expectEqualStrings(zlib_blocks, wire[split + last.progress.input_read ..]);
    try t.expectEqualStrings("", decoder.trailingPrefix());
    try t.expectEqual(@as(?Auto.Format, .gzip), decoder.selectedFormat());
    try t.expectEqual(@as(?core.StreamCount, gzip_end), decoder.memberEndOffset());
    try decoder.finish();
}

fn rejected(comptime Auto: type) !void {
    var history: [32 * 1024]u8 = undefined;
    var decoder = try Auto.init(.{}, &history);
    var output = [_]u8{sentinel};

    var silent: Log(Auto) = .{ .expected = &.{} };
    var aliased = rich.*;
    const before = decoder.snapshot();
    try t.expectError(error.InvalidBlockPlan, decoder.stepWithHeaderEvents(&aliased, aliased[0..1], silent.observer()));
    try t.expectEqualDeep(before, decoder.snapshot());
    try t.expectEqualSlices(u8, rich, &aliased);
    try silent.done();

    const invalid = "\x1f\x8aunused";
    try expectStep(try decoder.stepWithHeaderEvents(invalid[0..1], &output, silent.observer()), .need_input, 1, 0);
    try t.expectError(error.InvalidMagic, decoder.stepWithHeaderEvents(invalid[1..], &output, silent.observer()));
    try expectFailedProgress(&decoder, 1, 2);
    try t.expect(decoder.selectedFormat() == null);
    try silent.done();

    var bad_crc = rich.*;
    bad_crc[rich_header.len - 1] ^= 1;
    const expected = richEvents(Auto);
    // Exercise failure immediately after selection, during split detection,
    // and with the second FHCRC byte arriving in a separate call.
    for ([_]usize{ 0, 1, rich_header.len - 1 }) |split| {
        decoder.reset();
        var log: Log(Auto) = .{ .expected = expected[0 .. expected.len - 1] };
        const observer = log.observer();
        if (split != 0) try expectStep(try decoder.stepWithHeaderEvents(bad_crc[0..split], &output, observer), .need_input, split, 0);
        try t.expectError(error.BadGzipHeader, decoder.stepWithHeaderEvents(bad_crc[split..], &output, observer));
        try expectFailedProgress(&decoder, rich_header.len - split, rich_header.len);
        try t.expectEqual(@as(?Auto.Format, .gzip), decoder.selectedFormat());
        try log.done();
    }
    try t.expectEqual(sentinel, output[0]);
}

fn blockBoundaries(comptime Auto: type) !void {
    const gzip_blocks = rich_header ++ first_block ++ last_block ++ "\x07\x4c\x69\x30\x02\x00\x00\x00";
    const expected = richEvents(Auto);
    var history: [32 * 1024]u8 = undefined;
    for ([_]Auto.Format{ .gzip, .zlib }) |format| {
        const wire: []const u8 = if (format == .gzip) gzip_blocks else zlib_blocks;
        const header_len = if (format == .gzip) rich_header.len else zlib_header.len;
        var decoder = try Auto.init(.{}, &history);
        var output: [2]u8 = @splat(sentinel);
        var log: Log(Auto) = .{ .expected = if (format == .gzip) &expected else &.{}, .unwritten = &output };
        const observer = log.observer();
        const paused = try decoder.stepToBlockBoundaryWithHeaderEvents(wire, &output, observer);
        try expectStep(paused, .need_input, header_len + first_block.len, 1);
        try t.expect(paused.block_boundary);
        try t.expect(decoder.atBlockBoundary());
        try t.expectEqual(@as(?Auto.Format, format), decoder.selectedFormat());
        try t.expectEqualSlices(u8, &.{ 'A', sentinel }, &output);
        try log.done();
        const rest = wire[paused.progress.input_read..];
        const last = try decoder.stepToBlockBoundaryWithHeaderEvents(rest, output[1..], observer);
        try expectStep(last, .done, rest.len, 1);
        try t.expect(!last.block_boundary);
        try log.done();
        try t.expectEqualStrings("AB", &output);
        try decoder.finish();
    }
}

fn dictionaryZlib(comptime Auto: type) !void {
    // Python zlib.compressobj(zdict=dictionary) over the dictionary itself.
    const dictionary = "abcdefghij0123456789";
    const fdict = "\x78\xbb\x48\x2b\x06\x05\x4b\xc4\x22\x06\x00\x48\x2b\x06\x05";
    const wire = fdict ++ zlib_blocks ++ rich;
    const zlib_end = fdict.len + zlib_blocks.len;
    const options: Auto.Options = .{ .allow_concatenated = true, .allow_trailing_data = true };
    var history: [32 * 1024]u8 = undefined;
    for ([_]bool{ false, true }) |configured| {
        var decoder = if (configured) try Auto.initWithDictionary(options, &history, dictionary) else try Auto.init(options, &history);
        var log: Log(Auto) = .{ .expected = &.{} };
        const observer = log.observer();
        var output: [dictionary.len + 2]u8 = @splat(sentinel);
        try expectStep(try decoder.stepWithHeaderEvents(wire[0..1], &output, observer), .need_input, 1, 0);
        var read: usize = 1;
        if (!configured) {
            try t.expectError(error.NeedDictionary, decoder.stepWithHeaderEvents(wire[read..], &output, observer));
            try expectFailedProgress(&decoder, 5, 6);
            try t.expectEqual(@as(?u32, 0x482b0605), decoder.requiredDictionaryId());
            try log.done();
            try decoder.provideDictionary(dictionary);
            read = 6;
        }
        const last = try decoder.stepWithHeaderEvents(wire[read..], &output, observer);
        try expectStep(last, .done, zlib_end - read, output.len);
        try log.done();
        try t.expectEqualStrings(dictionary ++ "AB", &output);
        try t.expectEqualStrings(rich, wire[read + last.progress.input_read ..]);
        try t.expectEqual(@as(?Auto.Format, .zlib), decoder.selectedFormat());
        try t.expectEqual(@as(?core.StreamCount, zlib_end), decoder.memberEndOffset());
        try decoder.finish();
    }
}

fn cloneAndReset(comptime Auto: type) !void {
    const split = 20; // The first two filename bytes, "a.", have been observed.
    const expected = richEvents(Auto);
    var source_history: [32 * 1024]u8 = undefined;
    var clone_history: [32 * 1024]u8 = undefined;
    var source = try Auto.init(.{}, &source_history);
    var clone: Auto = undefined;
    var original: Log(Auto) = .{ .expected = &expected };
    try expectStep(try source.stepWithHeaderEvents(rich[0..split], &.{}, original.observer()), .need_input, split, 0);
    try original.position(2, 2);
    const original_calls = original.calls;
    try source.cloneInto(&clone, .{ .history = &clone_history });
    source.reset();
    try t.expect(source.selectedFormat() == null);

    // Bytes consumed by an unobserved call are not replayed to a new observer.
    try expectStep(try clone.step(rich[split..][0..1], &.{}), .need_input, 1, 0);
    const clone_events = [_]Auto.HeaderEvent{ field(Auto, .filename, 3, "xt"), expected[3], expected[4] };
    var output = [_]u8{sentinel};
    var continued: Log(Auto) = .{ .expected = &clone_events, .unwritten = &output };
    try expectStep(try clone.stepWithHeaderEvents(rich[split + 1 ..], &output, continued.observer()), .done, rich.len - split - 1, 1);
    try continued.done();
    try t.expectEqualStrings("A", &output);
    try clone.finish();

    output[0] = sentinel;
    var fresh: Log(Auto) = .{ .expected = &expected, .unwritten = &output };
    try expectStep(try source.stepWithHeaderEvents(rich, &output, fresh.observer()), .done, rich.len, 1);
    try fresh.done();
    try t.expectEqualStrings("A", &output);
    try original.position(2, 2);
    try t.expectEqual(original_calls, original.calls);
    try source.finish();
}
