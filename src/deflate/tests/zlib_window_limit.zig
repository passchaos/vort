//! The zlib window cap admits each CMF/FLG declaration, not the raw payload.
const std = @import("std");
const core = @import("../../core.zig");
const Count = core.StreamCount;
const t = std.testing;

const plain = "abcabcabcabc";
// The same final fixed DEFLATE block (including a short match) and Adler-32
// are used for every window. Only the wrapper header varies.
const raw = "\x4b\x4c\x4a\x4e\x84\x21\x00";
const body = raw ++ "\x1d\xe0\x04\x99";
const narrow = member(8);
const wide = member(15);
const wide_dict_header = header(15, true);
const dict_member = wide_dict_header ++ "\x04\x2d\x01\xa2" ++ body;
const gzip = "\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03" ++ raw ++ "\x34\x2a\x6e\x5a\x0c\x00\x00\x00";
const sentinel: u8 = 0xa5;
const denied = error.OutputLimitExceeded;

pub fn contracts(comptime D: type) !void {
    try ordinary(D);
    try headerAndDictionary(D);
    try concatenated(D);
    inline for (.{ D.ZlibIncrementalDecoder, D.ZlibOrGzipIncrementalDecoder }) |Decoder| {
        try incrementalFirst(Decoder);
        try incrementalConcatenated(Decoder);
    }
    try incrementalGzip(D.ZlibOrGzipIncrementalDecoder);
}

fn member(bits: u4) [2 + body.len]u8 {
    var wire: [2 + body.len]u8 = undefined;
    wire[0..2].* = header(bits, false);
    @memcpy(wire[2..], body);
    return wire;
}

fn header(bits: u4, fdict: bool) [2]u8 {
    return checkedHeader((@as(u8, bits - 8) << 4) | 8, if (fdict) 0x20 else 0);
}

fn checkedHeader(cmf: u8, flags: u8) [2]u8 {
    const base = (@as(u16, cmf) << 8) | flags;
    return .{ cmf, flags | @as(u8, @intCast((31 - base % 31) % 31)) };
}

fn splitHeader(wire: []const u8) [4][]const u8 {
    return .{ wire[0..1], "", wire[1..2], wire[2..] };
}

fn ordinary(comptime D: type) !void {
    var output: [plain.len + 1]u8 = undefined;
    try t.expectEqual(plain.len, try D.decodeZlibWithOptions(&wide, &output, .{}));
    try t.expectEqualStrings(plain, output[0..plain.len]);

    for (8..16) |width| {
        const bits: u4 = @intCast(width);
        const wire = member(bits);
        const chunks = splitHeader(&wire);
        const exact: D.ZlibDecodeOptions = .{ .max_window_bits = bits };
        @memset(&output, sentinel);
        try t.expectEqual(plain.len, try D.decodeZlibWithOptions(&wire, &output, exact));
        try t.expectEqualStrings(plain ++ "\xa5", &output);
        @memset(&output, sentinel);
        try t.expectEqual(plain.len, try D.decodeZlibChunksIntoWithOptions(&chunks, &output, exact));
        try t.expectEqualStrings(plain ++ "\xa5", &output);
        @memset(&output, sentinel);
        const prefix = try D.decodeZlibOrGzipPrefixWithOptions(&wire, &output, .{ .zlib = exact });
        try t.expectEqual(.zlib, prefix.format);
        try t.expectEqual(wire.len, prefix.input_read);
        try t.expectEqual(plain.len, prefix.output_written);
        try t.expectEqualStrings(plain ++ "\xa5", &output);

        const lower: D.ZlibDecodeOptions = .{ .max_window_bits = bits - 1 };
        const expected = if (bits == 8) error.InvalidBlockPlan else denied;
        @memset(&output, sentinel);
        try t.expectError(expected, D.decodeZlibWithOptions(&wire, &output, lower));
        try t.expectError(expected, D.decodeZlibChunksIntoWithOptions(&chunks, &output, lower));
        try t.expectError(expected, D.decodeZlibOrGzipWithOptions(&wire, &output, .{ .zlib = lower }));
        try t.expectEqualSlices(u8, &([_]u8{sentinel} ** output.len), &output);
    }

    // Even an invalid zlib policy is irrelevant when auto selects gzip.
    try t.expectEqual(plain.len, try D.decodeZlibOrGzipWithOptions(gzip, &output, .{ .zlib = .{ .max_window_bits = 0 } }));
    try t.expectEqualStrings(plain ++ "\xa5", &output);
}

fn headerAndDictionary(comptime D: type) !void {
    var output: [plain.len]u8 = @splat(sentinel);
    for ([_][2]u8{ .{ 0x78, 0x00 }, checkedHeader(0x79, 0), checkedHeader(0x88, 0) }) |bad| {
        const chunks = splitHeader(&bad);
        const invalid_cap: D.ZlibDecodeOptions = .{ .max_window_bits = 0 };
        try t.expectError(error.BadZlibHeader, D.decodeZlibWithOptions(&bad, &output, invalid_cap));
        try t.expectError(error.BadZlibHeader, D.decodeZlibChunksIntoWithOptions(&chunks, &output, invalid_cap));
        try t.expectError(error.InvalidMagic, D.decodeZlibOrGzipWithOptions(&bad, &output, .{ .zlib = invalid_cap }));
    }
    try t.expectError(error.TruncatedFrame, D.decodeZlibWithOptions(wide[0..1], &output, .{ .max_window_bits = 8 }));

    const limit: D.ZlibDecodeOptions = .{ .max_window_bits = 14 };
    for ([_][]const u8{ &wide_dict_header, dict_member }) |wire| {
        const chunks = splitHeader(wire);
        try t.expectError(denied, D.decodeZlibWithOptions(wire, &output, limit));
        try t.expectError(denied, D.decodeZlibChunksIntoWithDictionaryAndOptions(&chunks, &output, "wrong", limit));
        try t.expectError(denied, D.decodeZlibOrGzipWithOptions(wire, &output, .{ .zlib = limit }));
    }
    try t.expectEqualSlices(u8, &([_]u8{sentinel} ** plain.len), &output);
    try t.expectError(error.TruncatedFrame, D.decodeZlibWithOptions(&wide_dict_header, &output, .{}));
    try t.expectError(error.NeedDictionary, D.decodeZlibWithOptions(dict_member, &output, .{}));
    try t.expectError(error.ChecksumMismatch, D.decodeZlibWithDictionaryAndOptions(dict_member, &output, "wrong", .{}));
    try t.expectEqual(plain.len, try D.decodeZlibWithDictionaryAndOptions(dict_member, &output, "seed", .{}));
    try t.expectEqualStrings(plain, &output);
}

fn concatenated(comptime D: type) !void {
    const both = narrow ++ wide;
    const dict_suffix = narrow ++ wide_dict_header;
    const invalid_suffix = narrow ++ "\x78\x00tail";
    var output: [plain.len * 2]u8 = undefined;
    var joined: [both.len]u8 = undefined;
    const chunks = [_][]const u8{ both[0 .. narrow.len + 1], "", both[narrow.len + 1 ..] };

    for ([_]bool{ false, true }) |allow_trailing_data| {
        const cap: D.ZlibDecodeOptions = .{ .max_window_bits = 8, .allow_trailing_data = allow_trailing_data };
        @memset(&output, sentinel);
        try t.expectError(denied, D.decodeZlibConcatenatedWithOptions(&both, &output, cap));
        try t.expectEqualStrings(plain ++ "\xa5" ** plain.len, &output);
        try t.expectError(denied, D.decodeZlibConcatenatedWithDictionarySetAndOptions(
            &dict_suffix,
            &output,
            D.ZlibDictionarySet.fromEntries(&.{}),
            cap,
        ));
        try t.expectError(denied, D.ZlibDecoder.initConcatenatedFromChunksWithOptions(&chunks, &joined, &output, cap));
    }
    try t.expectEqual(plain.len, try D.decodeZlibConcatenatedWithOptions(invalid_suffix, &output, .{
        .max_window_bits = 8,
        .allow_trailing_data = true,
    }));
    try t.expectEqual(plain.len * 2, try D.decodeZlibConcatenatedWithOptions(&both, &output, .{ .max_window_bits = 15 }));
    try t.expectEqualStrings(plain ++ plain, &output);
}

fn incrementalOptions(comptime Decoder: type, cap: u4, concatenate: bool, trailing: bool) Decoder.Options {
    var options: Decoder.Options = .{ .allow_concatenated = concatenate, .allow_trailing_data = trailing };
    if (@hasDecl(Decoder, "selectedFormat")) {
        options.max_zlib_window_bits = cap;
    } else {
        options.max_window_bits = cap;
    }
    return options;
}

fn incrementalFirst(comptime Decoder: type) !void {
    var history: [32 * 1024]u8 = undefined;
    var output: [plain.len + 1]u8 = @splat(sentinel);
    // DICTID is neither required to reject the header nor consumed when present.
    for ([_][]const u8{ &wide_dict_header, dict_member }) |wire| {
        for (0..2) |split| {
            var decoder = try Decoder.init(incrementalOptions(Decoder, 14, false, false), &history);
            if (split != 0) try expectStep(try decoder.step(wire[0..split], &output), .need_input, split, 0);
            try t.expectError(denied, decoder.step(wire[split..], &output));
            try expectRefused(&decoder, null, 2, 2 - split, 0, 0);
        }
    }
    try t.expectEqualSlices(u8, &([_]u8{sentinel} ** output.len), &output);

    var invalid = try Decoder.init(incrementalOptions(Decoder, 7, false, false), &history);
    try expectStep(try invalid.step(narrow[0..1], &output), .need_input, 1, 0);
    try t.expectError(error.InvalidBlockPlan, invalid.step(narrow[1..], &output));
    try t.expectEqual(core.Progress{ .input_read = 1 }, invalid.snapshot().last_step_progress);

    var accepted = try Decoder.init(incrementalOptions(Decoder, 8, false, false), &history);
    try expectStep(try accepted.step(narrow[0..1], &output), .need_input, 1, 0);
    try expectStep(try accepted.step(narrow[1..], &output), .done, narrow.len - 1, plain.len);
    try accepted.finish();
    try t.expectEqualStrings(plain ++ "\xa5", &output);
}

fn incrementalConcatenated(comptime Decoder: type) !void {
    const wire = narrow ++ wide;
    var history: [32 * 1024]u8 = undefined;
    for ([_]bool{ false, true }) |trailing| {
        for ([_]bool{ false, true }) |split| {
            var decoder = try Decoder.init(incrementalOptions(Decoder, 8, true, trailing), &history);
            var output: [plain.len * 2]u8 = @splat(sentinel);
            const offset = if (split) narrow.len + 1 else 0;
            const written = if (split) plain.len else 0;
            if (split) try expectStep(try decoder.step(wire[0..offset], &output), .need_input, offset, written);
            try t.expectError(denied, decoder.step(wire[offset..], output[written..]));
            try expectRefused(&decoder, narrow.len, narrow.len + 2, narrow.len + 2 - offset, plain.len, plain.len - written);
            try t.expectEqualStrings(plain ++ "\xa5" ** plain.len, &output);
        }
    }
}

fn incrementalGzip(comptime Decoder: type) !void {
    var history: [32 * 1024]u8 = undefined;
    var output: [plain.len + 1]u8 = @splat(sentinel);
    var decoder = try Decoder.init(incrementalOptions(Decoder, 0, false, false), &history);
    try expectStep(try decoder.step(gzip[0..1], &output), .need_input, 1, 0);
    try expectStep(try decoder.step(gzip[1..], &output), .done, gzip.len - 1, plain.len);
    try decoder.finish();
    try t.expectEqual(@as(?Decoder.Format, .gzip), decoder.selectedFormat());
    try t.expectEqualStrings(plain ++ "\xa5", &output);
}

fn expectStep(result: core.StepResult, status: core.StepResult.Status, read: usize, written: usize) !void {
    try t.expectEqual(status, result.status);
    try t.expectEqual(core.Progress{ .input_read = read, .output_written = written }, result.progress);
}

fn expectRefused(decoder: anytype, member_end: ?Count, total_input: Count, read: usize, total_output: Count, written: usize) !void {
    const snapshot = decoder.snapshot();
    try t.expectEqual(member_end, decoder.memberEndOffset());
    try t.expectEqual(total_input, snapshot.total_input);
    try t.expectEqual(total_output, snapshot.total_output);
    try t.expectEqual(core.Progress{ .input_read = read, .output_written = written }, snapshot.last_step_progress);
    try t.expectEqual(@as(?Count, total_input), snapshot.last_error_input_offset);
    try t.expectEqual(@as(?Count, total_output), snapshot.last_error_output_offset);
    try t.expectEqualStrings("OutputLimitExceeded", snapshot.last_error_name);
    try t.expectEqualStrings("header", decoder.diagnostics().last_error_phase_name);
    try t.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
    try t.expectEqualStrings("", decoder.trailingPrefix());
    if (@hasDecl(@TypeOf(decoder.*), "selectedFormat")) {
        try t.expectEqual(@as(?@TypeOf(snapshot.format.?), .zlib), decoder.selectedFormat());
    }
}
