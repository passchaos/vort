//! Admission limits for incremental gzip members and zlib streams.
const std = @import("std");
const core = @import("../../../core.zig");
const Count = core.StreamCount;
const t = std.testing;

const Format = enum { gzip, zlib };
const sentinel: u8 = 0xa5;

// Final fixed DEFLATE blocks for the empty string and "A".
const gzip_header = "\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\xff";
const zlib_header = "\x78\x01";
const gzip_empty = gzip_header ++ "\x03\x00" ++ "\x00" ** 8;
const zlib_empty = zlib_header ++ "\x03\x00\x00\x00\x00\x01";
const gzip_one = gzip_header ++ "\x73\x04\x00\x8b\x9e\xd9\xd3\x01\x00\x00\x00";
const zlib_one = zlib_header ++ "\x73\x04\x00\x00\x42\x00\x42";

pub fn contracts(comptime D: type) !void {
    const Auto = D.ZlibOrGzipIncrementalDecoder;
    try wrapperContracts(D.GzipIncrementalDecoder, .gzip);
    try wrapperContracts(D.ZlibIncrementalDecoder, .zlib);
    try wrapperContracts(Auto, .gzip);
    try wrapperContracts(Auto, .zlib);
    try dictionary(D.ZlibIncrementalDecoder);
    try dictionary(Auto);
    try observer(D.GzipIncrementalDecoder);
    try observer(Auto);
}

fn wrapperContracts(comptime Decoder: type, comptime format: Format) !void {
    const empty = if (format == .gzip) gzip_empty else zlib_empty;
    const one = if (format == .gzip) gzip_one else zlib_one;
    const header_len = if (format == .gzip) gzip_header.len else zlib_header.len;
    try zeroCap(Decoder, format, empty, header_len);
    try exactAndExtra(Decoder, empty, one, header_len);
    try headerPrecedence(Decoder, format, empty, header_len);
    try trailing(Decoder, empty);
    try trailingPledge(Decoder, one);
}

fn zeroCap(comptime Decoder: type, comptime format: Format, wire: []const u8, header_len: usize) !void {
    var history: [32 * 1024]u8 = undefined;
    var decoder = try Decoder.init(.{ .max_members = 0 }, &history);
    for (0..header_len) |split| {
        var output = [_]u8{sentinel};
        if (split != 0) {
            try expectStep(try decoder.step(wire[0..split], &output), .need_input, split, 0);
            if (@hasDecl(Decoder, "selectedFormat")) {
                if (split == 1) try t.expectEqual(@as(?Decoder.Format, null), decoder.selectedFormat());
            }
        }
        try t.expectError(error.OutputLimitExceeded, decoder.step(wire[split..], &output));
        try expectRefused(&decoder, 0, null, 0, header_len, header_len - split, 0);
        try t.expectEqual(sentinel, output[0]);
        if (@hasDecl(Decoder, "selectedFormat")) {
            const selected: Decoder.Format = if (format == .gzip) .gzip else .zlib;
            try t.expectEqual(@as(?Decoder.Format, selected), decoder.selectedFormat());
        }
        decoder.reset();
    }
}

fn exactAndExtra(comptime Decoder: type, comptime empty: []const u8, comptime one: []const u8, header_len: usize) !void {
    var history: [32 * 1024]u8 = undefined;
    // A writable destination catches leaked plaintext from a refused member;
    // an all-empty stream with no destination proves counting is not byte-based.
    inline for ([_]bool{ false, true }) |populated| {
        const first = if (populated) one else empty;
        const admitted = first[0..first.len].* ++ empty[0..empty.len].*;
        const wire = admitted ++ first[0..first.len].*;
        const written: usize = if (populated) 1 else 0;
        for ([_]bool{ false, true }) |allow_trailing_data| {
            var decoder = try Decoder.init(.{
                .max_members = 2,
                .expected_output_len = if (populated) null else 0,
                .allow_concatenated = true,
                .allow_trailing_data = allow_trailing_data,
            }, &history);
            for (0..header_len) |split| {
                var output: [2]u8 = @splat(sentinel);
                const destination: []u8 = if (populated) &output else &.{};
                // At split zero the failing call must commit both good members
                // and their output, not roll back to the start of the call.
                const offset = if (split == 0) 0 else admitted.len + split;
                const prior_written = if (split == 0) 0 else written;
                if (offset != 0) {
                    try expectStep(try decoder.step(wire[0..offset], destination), .need_input, offset, prior_written);
                }
                try t.expectError(error.OutputLimitExceeded, decoder.step(wire[offset..], destination[prior_written..]));
                try expectRefused(&decoder, 2, admitted.len, written, admitted.len + header_len, admitted.len + header_len - offset, written - prior_written);
                try t.expectEqual(if (populated) @as(u8, 'A') else sentinel, output[0]);
                try t.expectEqual(sentinel, output[1]);
                decoder.reset();
            }

            // After reset the same cap admits exactly two members, including
            // a second fixed header split at its first byte, then accepts EOF.
            const split = first.len + 1;
            var output: [written]u8 = undefined;
            try expectStep(try decoder.step(wire[0..split], &output), .need_input, split, written);
            try expectStep(try decoder.step(wire[split..admitted.len], &.{}), .need_input, admitted.len - split, 0);
            try decoder.finish();
            try t.expectEqualStrings(if (populated) "A" else "", &output);
            try t.expectEqual(@as(Count, 2), completed(decoder.snapshot()));
            try t.expectEqual(@as(?Count, admitted.len), decoder.memberEndOffset());
            try t.expectEqualStrings("", decoder.snapshot().last_error_name);
        }
    }
}

fn headerPrecedence(comptime Decoder: type, comptime format: Format, empty: []const u8, header_len: usize) !void {
    // Gzip magic commits to validating the next header even with trailing data
    // enabled. An invalid zlib CMF/FLG is a header error only in strict mode.
    const bad = if (format == .gzip) "\x1f\x8b\x08\x20\x00\x00\x00\x00\x00\xff" else "\x78\xff";
    var history: [32 * 1024]u8 = undefined;
    var decoder = try Decoder.init(.{
        .max_members = 1,
        .allow_concatenated = true,
        .allow_trailing_data = format == .gzip,
    }, &history);
    try expectStep(try decoder.step(empty, &.{}), .need_input, empty.len, 0);
    try expectStep(try decoder.step(bad[0..1], &.{}), .need_input, 1, 0);
    try t.expectError(if (format == .gzip) error.BadGzipHeader else error.BadZlibHeader, decoder.step(bad[1..], &.{}));
    try t.expectEqual(@as(Count, 1), completed(decoder.snapshot()));
    try t.expectEqual(@as(?Count, empty.len), decoder.memberEndOffset());

    decoder.reset();
    try expectStep(try decoder.step(empty, &.{}), .need_input, empty.len, 0);
    try expectStep(try decoder.step(empty[0 .. header_len - 1], &.{}), .need_input, header_len - 1, 0);
    try t.expectError(error.TruncatedFrame, decoder.finish());
    try t.expectEqual(@as(Count, 1), completed(decoder.snapshot()));
    try t.expectEqual(@as(?Count, empty.len), decoder.memberEndOffset());
}

fn trailing(comptime Decoder: type, comptime empty: []const u8) !void {
    const tail = empty[0..1] ++ "\xffsuffix";
    var history: [32 * 1024]u8 = undefined;
    var decoder = try Decoder.init(.{
        .max_members = 1,
        .allow_concatenated = true,
        .allow_trailing_data = true,
    }, &history);
    try expectStep(try decoder.step(empty, &.{}), .need_input, empty.len, 0);
    try expectStep(try decoder.step(tail[0..1], &.{}), .need_input, 1, 0);
    const done = try decoder.step(tail[1..], &.{});
    try expectStep(done, .done, 0, 0);
    try decoder.finish();
    try t.expectEqualStrings(tail[0..1], decoder.trailingPrefix());
    try t.expectEqualStrings(tail[1..], tail[1 + done.progress.input_read ..]);
    try t.expectEqual(@as(Count, 1), completed(decoder.snapshot()));
    try t.expectEqual(@as(?Count, empty.len), decoder.memberEndOffset());
}

fn trailingPledge(comptime Decoder: type, comptime one: []const u8) !void {
    const tail = one[0..1] ++ "\x00";
    const wire = one ++ tail;
    var history: [32 * 1024]u8 = undefined;
    for ([_]bool{ false, true }) |split| {
        for ([_]Count{ 1, 2 }) |expected| {
            var decoder = try Decoder.init(.{
                .expected_output_len = expected,
                .max_members = 1,
                .allow_concatenated = true,
                .allow_trailing_data = true,
            }, &history);
            var output: [2]u8 = @splat(sentinel);
            const offset = if (split) one.len + 1 else 0;
            if (split)
                try expectStep(try decoder.step(wire[0..offset], &output), .need_input, offset, 1);
            const destination: []u8 = if (split) output[1..] else &output;
            const read = if (split) 0 else one.len;
            const written: usize = if (split) 0 else 1;
            if (expected == 1) {
                try expectStep(try decoder.step(wire[offset..], destination), .done, read, written);
                try decoder.finish();
                try t.expectEqualStrings(if (split) tail[0..1] else "", decoder.trailingPrefix());
            } else {
                try t.expectError(error.SizeMismatch, decoder.step(wire[offset..], destination));
                const snapshot = decoder.snapshot();
                try t.expect(!snapshot.done);
                try t.expectEqual(core.Progress{ .input_read = read, .output_written = written }, snapshot.last_step_progress);
            }
            try t.expectEqual(@as(Count, 1), completed(decoder.snapshot()));
            try t.expectEqual(@as(?Count, one.len), decoder.memberEndOffset());
            try t.expectEqualSlices(u8, &.{ 'A', sentinel }, &output);
        }
    }
}

fn dictionary(comptime Decoder: type) !void {
    // zlib.compressobj(zdict=b"abcdefghij0123456789") over the dictionary itself.
    const fdict = "\x78\xbb\x48\x2b\x06\x05\x4b\xc4\x22\x06\x00\x48\x2b\x06\x05";
    const wire = zlib_empty ++ fdict;
    const split = zlib_empty.len + 1;
    var history: [32 * 1024]u8 = undefined;
    {
        var uncapped = try Decoder.init(.{}, &history);
        try t.expectError(error.NeedDictionary, uncapped.step(fdict, &.{}));
        try t.expectEqual(@as(?u32, 0x482b0605), uncapped.requiredDictionaryId());
    }
    var decoder = try Decoder.init(.{ .max_members = 1, .allow_concatenated = true, .allow_trailing_data = true }, &history);
    try expectStep(try decoder.step(wire[0..split], &.{}), .need_input, split, 0);
    try t.expectError(error.OutputLimitExceeded, decoder.step(wire[split..], &.{}));
    try t.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
    try expectRefused(&decoder, 1, zlib_empty.len, 0, zlib_empty.len + zlib_header.len, 1, 0);
}

fn observer(comptime Decoder: type) !void {
    // A complete second member with FNAME. Its fixed header alone must cause
    // refusal, before even the provisional start event can reach the observer.
    const named = "\x1f\x8b\x08\x08\x00\x00\x00\x00\x00\xffname\x00" ++ gzip_one[gzip_header.len..];
    const wire = gzip_one ++ named;
    const Log = struct {
        fn onEvent(context: ?*anyopaque, _: Decoder.HeaderEvent) void {
            const calls: *usize = @ptrCast(@alignCast(context.?));
            calls.* += 1;
        }
    };
    var calls: usize = 0;
    var output: [2]u8 = @splat(sentinel);
    var history: [32 * 1024]u8 = undefined;
    var decoder = try Decoder.init(.{ .max_members = 1, .allow_concatenated = true }, &history);
    try t.expectError(error.OutputLimitExceeded, decoder.stepWithHeaderEvents(wire, &output, .{
        .context = &calls,
        .on_event = Log.onEvent,
    }));
    try t.expectEqual(@as(usize, 2), calls); // Start and complete for the first member only.
    try t.expectEqualSlices(u8, &.{ 'A', sentinel }, &output);
    try expectRefused(&decoder, 1, gzip_one.len, 1, gzip_one.len + gzip_header.len, gzip_one.len + gzip_header.len, 1);
}

fn expectStep(result: core.StepResult, status: core.StepResult.Status, read: usize, written: usize) !void {
    try t.expectEqual(status, result.status);
    try t.expectEqualDeep(core.Progress{ .input_read = read, .output_written = written }, result.progress);
}

fn completed(snapshot: anytype) Count {
    if (@hasField(@TypeOf(snapshot), "member_count")) {
        return snapshot.member_count;
    } else if (@hasField(@TypeOf(snapshot), "stream_count")) {
        return snapshot.stream_count;
    } else {
        return switch (snapshot.detail) {
            .gzip => |gzip| gzip.member_count,
            .zlib => |zlib| zlib.stream_count,
            .detecting => 0,
        };
    }
}

fn expectRefused(decoder: anytype, members: Count, member_end: ?Count, total_output: Count, total_input: Count, read: usize, written: usize) !void {
    const snapshot = decoder.snapshot();
    try t.expectEqual(members, completed(snapshot));
    try t.expectEqual(member_end, decoder.memberEndOffset());
    try t.expectEqual(total_input, snapshot.total_input);
    try t.expectEqual(total_output, snapshot.total_output);
    try t.expectEqualDeep(core.Progress{ .input_read = read, .output_written = written }, snapshot.last_step_progress);
    try t.expectEqual(@as(?Count, total_input), snapshot.last_error_input_offset);
    try t.expectEqual(@as(?Count, total_output), snapshot.last_error_output_offset);
    try t.expectEqualStrings("OutputLimitExceeded", snapshot.last_error_name);
    try t.expectEqualStrings("header", decoder.diagnostics().last_error_phase_name);
    try t.expectEqualStrings("", decoder.trailingPrefix());
}
