const std = @import("std");
const w = @import("wire.zig");
const real = @import("real_samples.zig");
const t = std.testing;

fn guard(bytes: []const u8) !void {
    for (bytes) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
}

pub fn reject(decoder: anytype, wire: []const u8, comptime fragmented: bool) !void {
    var caller: [32768 + 32]u8 = @splat(0xa5);
    const output = caller[16..][0..32768];
    var consumed: usize = 0;
    for (0..wire.len + 4) |_| {
        const offered = wire[consumed..if (fragmented) @min(wire.len, consumed + 1) else wire.len];
        const input_before = decoder.total_input;
        const output_before = decoder.total_output;
        if (decoder.step(offered, output)) |result| {
            try t.expectEqual(@as(@TypeOf(input_before), @intCast(result.progress.input_read)), decoder.total_input - input_before);
            try t.expectEqual(@as(@TypeOf(output_before), @intCast(result.progress.output_written)), decoder.total_output - output_before);
            consumed += result.progress.input_read;
            try t.expectEqual(@as(usize, 0), result.progress.output_written);
            try t.expect(result.progress.input_read != 0);
            try t.expect(result.status != .done);
        } else |err| {
            // Existing incremental shape errors retain their header-error
            // category while all one-shot table errors use InvalidHuffmanCode.
            try t.expectEqual(error.InvalidDynamicBlockHeader, err);
            const advanced = decoder.total_input - input_before;
            try t.expect(advanced <= offered.len);
            consumed += @intCast(advanced);
            try t.expectEqual(@as(@TypeOf(output_before), 0), decoder.total_output);
            if (@hasField(@TypeOf(decoder.*), "last_step_progress")) {
                try t.expectEqual(advanced, decoder.last_step_progress.input_read);
                try t.expectEqual(@as(usize, 0), decoder.last_step_progress.output_written);
            }
            const error_input = decoder.total_input;
            const diagnostics = decoder.diagnostics();
            const phase = diagnostics.last_error_phase_name;
            const name = diagnostics.last_error_name;
            try t.expectError(error.InvalidDynamicBlockHeader, decoder.step(wire[consumed..], output));
            try t.expectEqual(error_input, decoder.total_input);
            try t.expectEqual(@as(@TypeOf(output_before), 0), decoder.total_output);
            try t.expectEqualStrings(phase, decoder.diagnostics().last_error_phase_name);
            try t.expectEqualStrings(name, decoder.diagnostics().last_error_name);
            if (@hasField(@TypeOf(decoder.*), "last_step_progress")) {
                try t.expectEqual(@as(usize, 0), decoder.last_step_progress.input_read);
                try t.expectEqual(@as(usize, 0), decoder.last_step_progress.output_written);
            }
            try guard(&caller);
            return;
        }
    }
    return error.TestUnexpectedResult;
}

fn rawReject(comptime D: type, raw: []const u8) !void {
    const Raw = D.RawDeflateIncrementalFixedLiteralDecoder;
    inline for (.{ false, true }) |fragmented| {
        var history: [32768]u8 = @splat(0xa5);
        var decoder = try Raw.initWithHistory(.{}, &history);
        try reject(&decoder, raw, fragmented);
        try guard(&history);
    }
    // A long input and an attached caller workspace exercise admission before
    // any semantic/rolling kernel can run or write to caller output/history.
    const padded = try t.allocator.alloc(u8, raw.len + 8192);
    defer t.allocator.free(padded);
    @memcpy(padded[0..raw.len], raw);
    @memset(padded[raw.len..], 0);
    var history: [Raw.recommended_history_len]u8 = @splat(0xa5);
    var decoder = try Raw.initWithHistory(.{ .allow_trailing_data = true }, &history);
    var workspace: Raw.SemanticWorkspace = undefined;
    try decoder.attachSemanticWorkspace(&workspace);
    try reject(&decoder, padded, false);
    try guard(&history);
}

fn wrappedReject(comptime D: type, comptime wrapper: w.Wrapper, wire: []const u8) !void {
    inline for (.{ false, true }) |fragmented| {
        var history: [32768]u8 = @splat(0xa5);
        var decoder = if (wrapper == .zlib) try D.ZlibIncrementalDecoder.init(.{}, &history) else try D.GzipIncrementalDecoder.init(.{}, &history);
        try reject(&decoder, wire, fragmented);
        try guard(&history);
    }
}

pub fn drain(decoder: anytype, wire: []const u8, expected: []const u8) !void {
    var output: [32768]u8 = @splat(0xa5);
    var consumed: usize = 0;
    var produced: usize = 0;
    for (0..512) |_| {
        const limit = @min(wire.len, consumed + 1);
        const before_input = decoder.total_input;
        const before_output = decoder.total_output;
        const result = try decoder.step(wire[consumed..limit], output[produced..]);
        consumed += result.progress.input_read;
        produced += result.progress.output_written;
        try t.expectEqual(@as(@TypeOf(before_input), @intCast(result.progress.input_read)), decoder.total_input - before_input);
        try t.expectEqual(@as(@TypeOf(before_output), @intCast(result.progress.output_written)), decoder.total_output - before_output);
        if (result.status == .done) {
            try t.expectEqual(wire.len, consumed);
            try t.expectEqual(expected.len, produced);
            try t.expectEqualSlices(u8, expected, output[0..produced]);
            try guard(output[produced..]);
            return;
        }
        try t.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    return error.TestUnexpectedResult;
}

fn controls(comptime D: type) !void {
    inline for (.{ w.Kind.complete, w.Kind.empty_distance, w.Kind.singleton_distance, w.Kind.singleton_literal }) |kind| {
        const raw = try w.make(kind);
        defer t.allocator.free(raw);
        const expected: []const u8 = if (kind == .singleton_literal) "" else "A";
        var history: [32768]u8 = @splat(0xa5);
        var decoder = try D.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(.{}, &history);
        try drain(&decoder, raw, expected);
        inline for (.{ w.Wrapper.zlib, w.Wrapper.gzip }) |wrapper| {
            const frame = try w.wrap(wrapper, raw, expected, "");
            defer t.allocator.free(frame);
            var wrapped = if (wrapper == .zlib) try D.ZlibIncrementalDecoder.init(.{}, &history) else try D.GzipIncrementalDecoder.init(.{}, &history);
            try drain(&wrapped, frame, expected);
        }
    }
    const raw = try w.make(.dictionary_match);
    defer t.allocator.free(raw);
    var history: [32768]u8 = @splat(0xa5);
    var decoder = try D.RawDeflateIncrementalFixedLiteralDecoder.initWithDictionary(.{}, &history, "A");
    try drain(&decoder, raw, "AAA");
    const zlib = try w.wrap(.zlib, raw, "AAA", "A");
    defer t.allocator.free(zlib);
    var wrapped = try D.ZlibIncrementalDecoder.initWithDictionary(.{}, &history, "A");
    try drain(&wrapped, zlib, "AAA");
}

pub fn contracts(comptime D: type) !void {
    try rawReject(D, &real.raw_bad);
    try wrappedReject(D, .gzip, &real.gzip_bad);
    inline for (.{
        w.Kind.incomplete_codes,       w.Kind.incomplete_literal,      w.Kind.long_literal_singleton,
        w.Kind.incomplete_distance,    w.Kind.long_distance_singleton, w.Kind.oversubscribed_codes,
        w.Kind.oversubscribed_literal, w.Kind.oversubscribed_distance, w.Kind.missing_eob,
    }) |kind| {
        const raw = try w.make(kind);
        defer t.allocator.free(raw);
        try rawReject(D, raw);
        inline for (.{ w.Wrapper.zlib, w.Wrapper.gzip }) |wrapper| {
            const frame = try w.wrap(wrapper, raw, "A", "");
            defer t.allocator.free(frame);
            try wrappedReject(D, wrapper, frame);
        }
    }
    try controls(D);
}
