//! zlib-compatible tolerance of distances beyond the advertised CINFO window.
const std = @import("std");
const core = @import("../../core.zig");
const checksum = @import("../../checksum.zig");
const Count = core.StreamCount;
const wire = @embedFile("fixtures/small-cinfo-distance-257.zlib");
const guard_byte: u8 = 0xcc;
const History = [32768 + 2]u8;
const Output = [514 + 2]u8;

const plaintext = blk: {
    var bytes: [514]u8 = undefined;
    for (0..256) |i| bytes[i] = @intCast(i);
    bytes[256] = 0xa5;
    @memcpy(bytes[257..], bytes[0..257]);
    break :blk bytes;
};

pub fn contracts(comptime D: type) !void {
    // This manually assembled fixed block has a length-257, distance-257
    // match despite CMF=0x08 advertising only 256 bytes. Python zlib 1.2.11
    // independently validated the fixture; keep it independent of our encoder.
    try std.testing.expectEqual(@as(u8, 0x08), wire[0]);
    try std.testing.expectEqual(@as(u16, 0), std.mem.readInt(u16, wire[0..2], .big) % 31);
    try std.testing.expectEqual(checksum.adler32(&plaintext), std.mem.readInt(u32, wire[wire.len - 4 ..][0..4], .big));
    const one_shot = try D.decodeZlibAlloc(std.testing.allocator, wire);
    defer std.testing.allocator.free(one_shot);
    try std.testing.expectEqualSlices(u8, &plaintext, one_shot);

    inline for (.{ D.ZlibIncrementalDecoder, D.ZlibOrGzipIncrementalDecoder }) |Decoder| {
        try completeAndReset(Decoder);
        try truncatedFinish(Decoder);
        try corruptAdler(Decoder);
        try trailingPolicy(Decoder);
    }
}

fn expectFill(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(guard_byte, byte);
}

fn expectGuards(bytes: []const u8) !void {
    try std.testing.expectEqual(guard_byte, bytes[0]);
    try std.testing.expectEqual(guard_byte, bytes[bytes.len - 1]);
}

fn expectProgress(decoder: anytype, before: anytype, progress: core.Progress, offered: usize, capacity: usize) !void {
    const after = decoder.snapshot();
    try std.testing.expect(progress.input_read <= offered);
    try std.testing.expect(progress.output_written <= capacity);
    try std.testing.expectEqual(@as(Count, progress.input_read), after.total_input - before.total_input);
    try std.testing.expectEqual(@as(Count, progress.output_written), after.total_output - before.total_output);
    try std.testing.expectEqualDeep(progress, after.last_step_progress);
    try std.testing.expectEqualDeep(@as(?core.Progress, progress), decoder.diagnostics().last_step_progress);
    try std.testing.expectEqual(after.total_input, decoder.diagnostics().input_read);
    try std.testing.expectEqual(after.total_output, decoder.diagnostics().output_written);
}

fn expectCounts(decoder: anytype, read: usize, written: usize) !void {
    const observed = decoder.snapshot();
    try std.testing.expectEqual(@as(Count, @intCast(read)), observed.total_input);
    try std.testing.expectEqual(@as(Count, @intCast(written)), observed.total_output);
}

fn expectReset(decoder: anytype) !void {
    try expectCounts(decoder, 0, 0);
    const observed = decoder.snapshot();
    try std.testing.expect(!observed.done);
    try std.testing.expectEqual(@as(?Count, null), decoder.memberEndOffset());
    try std.testing.expectEqual(@as(?Count, null), observed.member_end_offset);
    try std.testing.expectEqualDeep(core.Progress{}, observed.last_step_progress);
    try std.testing.expectEqualStrings("", observed.last_error_name);
    try std.testing.expectEqual(@as(?Count, null), observed.last_error_input_offset);
    try std.testing.expectEqual(@as(?Count, null), observed.last_error_output_offset);
    try std.testing.expectEqual(@as(usize, 0), decoder.trailingPrefix().len);
    if (@hasDecl(@TypeOf(decoder.*), "selectedFormat"))
        try std.testing.expectEqual(@as(?@TypeOf(decoder.*).Format, null), decoder.selectedFormat());
}

fn splitHeader(decoder: anytype) !void {
    var output: [2]u8 = @splat(guard_byte);
    for (0..2) |i| {
        const before = decoder.snapshot();
        const stepped = try decoder.step(wire[i..][0..1], output[1..1]);
        try expectProgress(decoder, before, stepped.progress, 1, 0);
        try std.testing.expectEqual(core.StepResult.Status.need_input, stepped.status);
        try std.testing.expectEqual(@as(usize, 1), stepped.progress.input_read);
        try std.testing.expectEqual(@as(usize, 0), stepped.progress.output_written);
        try expectCounts(decoder, i + 1, 0);
        try expectFill(&output);
        if (@hasDecl(@TypeOf(decoder.*), "selectedFormat")) {
            if (i == 0) {
                try std.testing.expectEqual(@as(?@TypeOf(decoder.*).Format, null), decoder.selectedFormat());
            } else {
                try std.testing.expectEqual(@as(?@TypeOf(decoder.*).Format, .zlib), decoder.selectedFormat());
            }
        }
    }
}

// Every successful and failing call must account for exactly the bytes it
// changed. After the exact output fills, a zero-capacity slice still drains EOB
// and all four footer bytes, including under the one-byte input schedule.
fn drain(decoder: anytype, input: []const u8, input_chunk: usize, output_chunk: usize, initial_read: usize) !usize {
    var output: Output = @splat(guard_byte);
    var read = initial_read;
    var written: usize = 0;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < 16 * (input.len + plaintext.len + 1));
        const source = input[read..][0..@min(input_chunk, input.len - read)];
        const destination = output[1 + written ..][0..@min(output_chunk, plaintext.len - written)];
        const before = decoder.snapshot();
        const stepped = decoder.step(source, destination) catch |err| {
            const observed = decoder.snapshot();
            try expectProgress(decoder, before, observed.last_step_progress, source.len, destination.len);
            read += observed.last_step_progress.input_read;
            written += observed.last_step_progress.output_written;
            try expectCounts(decoder, read, written);
            try expectGuards(&output);
            try expectFill(output[1 + written ..]);
            try std.testing.expectEqualSlices(u8, plaintext[0..written], output[1..][0..written]);
            try std.testing.expectEqual(@as(?Count, observed.total_input), observed.last_error_input_offset);
            try std.testing.expectEqual(@as(?Count, observed.total_output), observed.last_error_output_offset);
            return err;
        };
        try expectProgress(decoder, before, stepped.progress, source.len, destination.len);
        read += stepped.progress.input_read;
        written += stepped.progress.output_written;
        try expectCounts(decoder, read, written);
        try expectGuards(&output);
        try expectFill(output[1 + written ..]);
        if (stepped.status == .done) break;
        try std.testing.expect(stepped.progress.input_read != 0 or stepped.progress.output_written != 0);
    }
    try std.testing.expectEqual(plaintext.len, written);
    try std.testing.expectEqualSlices(u8, &plaintext, output[1..][0..written]);
    try std.testing.expect(decoder.snapshot().done);
    try std.testing.expectEqual(@as(?Count, @intCast(wire.len)), decoder.memberEndOffset());
    return read;
}

fn completeAndReset(comptime Decoder: type) !void {
    var history: History = @splat(guard_byte);
    var decoder = try Decoder.init(.{
        .expected_output_len = plaintext.len,
        .max_output_len = plaintext.len,
    }, history[1 .. history.len - 1]);
    try expectReset(&decoder);
    try std.testing.expectEqual(wire.len, try drain(&decoder, wire, wire.len, plaintext.len, 0));
    try decoder.finish();
    try decoder.finish();
    const before = decoder.snapshot();
    var output: [3]u8 = @splat(guard_byte);
    const done = try decoder.step("", output[1..2]);
    try expectProgress(&decoder, before, done.progress, 0, 1);
    try std.testing.expectEqual(core.StepResult.Status.done, done.status);
    try std.testing.expectEqualDeep(core.Progress{}, done.progress);
    try expectFill(&output);
    try expectGuards(&history);

    decoder.reset();
    try expectReset(&decoder);
    try splitHeader(&decoder);
    try std.testing.expectEqual(wire.len, try drain(&decoder, wire, 1, 1, 2));
    try decoder.finish();
    try expectCounts(&decoder, wire.len, plaintext.len);
    try expectGuards(&history);
}

fn truncatedFinish(comptime Decoder: type) !void {
    var history: History = @splat(guard_byte);
    var decoder = try Decoder.init(.{ .expected_output_len = plaintext.len }, history[1 .. history.len - 1]);
    for ([_]usize{ 1, wire.len - 4, wire.len - 1 }) |end| {
        var output: Output = @splat(guard_byte);
        const before = decoder.snapshot();
        const stepped = try decoder.step(wire[0..end], output[1 .. output.len - 1]);
        try expectProgress(&decoder, before, stepped.progress, end, plaintext.len);
        try std.testing.expectEqual(core.StepResult.Status.need_input, stepped.status);
        const written: usize = if (end == 1) 0 else plaintext.len;
        try expectCounts(&decoder, end, written);
        try std.testing.expectEqualSlices(u8, plaintext[0..written], output[1..][0..written]);
        try expectFill(output[1 + written ..]);
        try expectGuards(&output);
        try std.testing.expectEqual(@as(?Count, null), decoder.memberEndOffset());
        try std.testing.expectError(error.TruncatedFrame, decoder.finish());
        try expectCounts(&decoder, end, written);
        decoder.reset();
        try expectReset(&decoder);
        try expectGuards(&history);
    }
    try std.testing.expectEqual(wire.len, try drain(&decoder, wire, 1, 1, 0));
    try decoder.finish();
    try expectGuards(&history);
}

fn corruptAdler(comptime Decoder: type) !void {
    var corrupt: [wire.len]u8 = wire.*;
    corrupt[corrupt.len - 1] ^= 1;
    for ([_]bool{ false, true }) |allow_trailing| {
        inline for (.{ false, true }) |tiny| {
            var history: History = @splat(guard_byte);
            var decoder = try Decoder.init(.{
                .expected_output_len = plaintext.len,
                .allow_trailing_data = allow_trailing,
            }, history[1 .. history.len - 1]);
            try std.testing.expectError(error.ChecksumMismatch, drain(&decoder, &corrupt, if (tiny) 1 else wire.len, if (tiny) 1 else plaintext.len, 0));
            try expectCounts(&decoder, wire.len, plaintext.len);
            try std.testing.expectEqualStrings("ChecksumMismatch", decoder.snapshot().last_error_name);
            try std.testing.expectEqual(@as(?Count, null), decoder.memberEndOffset());
            try std.testing.expect(!decoder.snapshot().done);
            try expectGuards(&history);
            decoder.reset();
            try expectReset(&decoder);
            try std.testing.expectEqual(wire.len, try drain(&decoder, wire, wire.len, plaintext.len, 0));
            try decoder.finish();
        }
    }
}

fn trailingPolicy(comptime Decoder: type) !void {
    const tail = "tail";
    const joined = wire.* ++ tail.*;
    for ([_]bool{ false, true }) |allow_trailing| {
        var history: History = @splat(guard_byte);
        var decoder = try Decoder.init(.{
            .expected_output_len = plaintext.len,
            .allow_trailing_data = allow_trailing,
        }, history[1 .. history.len - 1]);
        if (allow_trailing) {
            const read = try drain(&decoder, &joined, joined.len, plaintext.len, 0);
            try std.testing.expectEqual(wire.len, read);
            try std.testing.expectEqualStrings(tail, joined[read..]);
        } else {
            try std.testing.expectError(error.TrailingData, drain(&decoder, &joined, joined.len, plaintext.len, 0));
        }
        try expectCounts(&decoder, wire.len, plaintext.len);
        try std.testing.expectEqual(@as(?Count, @intCast(wire.len)), decoder.memberEndOffset());
        try std.testing.expectEqual(@as(usize, 0), decoder.trailingPrefix().len);
        decoder.reset();
        try expectReset(&decoder);
        try std.testing.expectEqual(wire.len, try drain(&decoder, wire, 1, 1, 0));

        var output: [3]u8 = @splat(guard_byte);
        const before = decoder.snapshot();
        if (allow_trailing) {
            const done = try decoder.step(tail, output[1..2]);
            try std.testing.expectEqual(core.StepResult.Status.done, done.status);
            try expectProgress(&decoder, before, done.progress, tail.len, 1);
            try std.testing.expectEqualDeep(core.Progress{}, done.progress);
        } else {
            try std.testing.expectError(error.TrailingData, decoder.step(tail, output[1..2]));
            try expectProgress(&decoder, before, decoder.snapshot().last_step_progress, tail.len, 1);
            try std.testing.expectEqualDeep(core.Progress{}, decoder.snapshot().last_step_progress);
        }
        try decoder.finish();
        // Once EOF is declared, further nonempty input is trailing data even
        // when the live decoder was configured to leave suffixes unconsumed.
        try std.testing.expectError(error.TrailingData, decoder.step(tail, output[1..2]));
        try expectCounts(&decoder, wire.len, plaintext.len);
        try std.testing.expectEqualDeep(core.Progress{}, decoder.snapshot().last_step_progress);
        try expectFill(&output);
        try expectGuards(&history);
    }
}
