const std = @import("std");
const h = @import("helpers.zig");
const f = @import("fixtures.zig");

pub fn contracts(comptime Z: type) !void {
    const raw_plain = h.memory.plain;
    const rle_plain = "R" ** 4096;
    const compressed = try h.memory.compressedAlloc();
    defer h.a.free(compressed);
    const compressed_plain = try h.memory.compressedPlainAlloc();
    defer h.a.free(compressed_plain);
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        const magicless = format == .magicless;
        inline for (.{ false, true }) |known| {
            const raw = try f.rawBlocks(raw_plain, known, magicless, 37);
            defer h.a.free(raw);
            const rle = try f.rleBlocks(rle_plain, known, magicless, 512);
            defer h.a.free(rle);
            const base = if (magicless) compressed[4..] else compressed;
            const changed: ?[]u8 = if (!known) try f.unknownCompressed(base, magicless) else null;
            defer if (changed) |bytes| h.a.free(bytes);
            const sequence_frame = changed orelse base;
            const mixed = try f.mixed(known, magicless);
            defer h.a.free(mixed);
            for ([_]struct { frame: []const u8, plain: []const u8 }{
                .{ .frame = raw, .plain = raw_plain }, .{ .frame = rle, .plain = rle_plain }, .{ .frame = sequence_frame, .plain = compressed_plain }, .{ .frame = mixed, .plain = f.mixed_plain },
            }) |sample| {
                try checkSample(Z, sample.frame, sample.plain, .{ .format = format, .expected_output_len = if (known) sample.plain.len else null }, null);
            }
            inline for (.{ .block_stream, .prevalidated_frame }) |policy| {
                var live_buffer: [f.mixed_plain.len]u8 = undefined;
                var live = Z.NativeIncrementalFrameDecoder.initWithOptions(h.a, .{ .format = format, .input_policy = policy });
                defer live.deinit();
                try live.bindStableOutput(&live_buffer);
                var published: usize = 0;
                const result = try h.step(&live, mixed, &live_buffer, &published, f.mixed_plain);
                try std.testing.expectEqual(f.mixed_plain.len, result.progress.output_written);
                try std.testing.expectEqual(mixed.len, result.progress.input_read);
                try live.finish();
            }
            const crossing = try f.crossing(known, magicless, true, 0);
            defer h.a.free(crossing);
            const dictionary = Z.NativeDictionary.initRawContent(f.crossing_dictionary);
            const reference = try Z.decodeFrameAllocWithOptions(h.a, crossing, .{ .format = format, .dictionary = dictionary });
            defer h.a.free(reference);
            try std.testing.expectEqualSlices(u8, f.crossing_plain, reference);
            try checkSample(Z, crossing, f.crossing_plain, .{ .format = format, .expected_output_len = if (known) f.crossing_plain.len else null }, dictionary);
        }
    }
    try fullDictionary(Z);
    try partialOutput(Z);
}

fn partialOutput(comptime Z: type) !void {
    if (!@hasDecl(Z.NativeIncrementalFrameDecoder, "stepStableLimited")) return;
    const frame = try f.crossing(false, false, true, 0);
    defer h.a.free(frame);
    inline for (.{ .block_stream, .prevalidated_frame }) |policy| {
        var buffer: [f.crossing_plain.len + 17]u8 = @splat(0xa5);
        var decoder = Z.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(h.a, Z.NativeDictionary.initRawContent(f.crossing_dictionary), .{ .input_policy = policy });
        defer decoder.deinit();
        try decoder.bindStableOutput(&buffer);
        var read: usize = 0;
        var count: usize = 0;
        var calls: usize = 0;
        while (decoder.snapshot().phase != .done) : (calls += 1) {
            try std.testing.expect(calls < 256);
            const maximum: usize = if (calls % 5 == 0) 0 else 1;
            const result = try h.stepLimited(&decoder, frame[read..], &buffer, &count, f.crossing_plain, maximum);
            read += result.progress.input_read;
        }
        try decoder.finish();
        try std.testing.expectEqual(frame.len, read);
        try std.testing.expectEqual(f.crossing_plain.len, count);
        try h.memory.untouched(buffer[f.crossing_plain.len..]);
    }
}

fn checkSample(comptime Z: type, frame: []const u8, plain: []const u8, base: Z.NativeIncrementalFrameDecoder.Options, dictionary: ?Z.NativeDictionary) !void {
    inline for (.{ .block_stream, .prevalidated_frame }) |policy| {
        for ([_]usize{ 1, 7, frame.len }) |chunk| {
            errdefer std.debug.print("stable output sample policy={s} format={s} wire={d} plain={d} chunk={d}\n", .{ @tagName(policy), @tagName(base.format), frame.len, plain.len, chunk });
            const buffer = try h.a.alloc(u8, plain.len + 17);
            defer h.a.free(buffer);
            @memset(buffer, 0xa5);
            var options = base;
            options.input_policy = policy;
            options.max_output_len = plain.len;
            options.max_decoded_buffer_len = plain.len;
            var decoder = if (dictionary) |value|
                Z.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(h.a, value, options)
            else
                Z.NativeIncrementalFrameDecoder.initWithOptions(h.a, options);
            defer decoder.deinit();
            try decoder.bindStableOutput(buffer);
            var count: usize = 0;
            try h.published(&decoder, buffer, 0);
            try std.testing.expectEqual(frame.len, try h.drive(&decoder, frame, buffer, &count, plain, chunk));
            try std.testing.expectEqual(plain.len, count);
            try h.memory.untouched(buffer[plain.len..]);
        }
    }
}

fn fullDictionary(comptime Z: type) !void {
    const bytes = try h.memory.hexAlloc(@embedFile("../../zstd/testdata/libzstd-trained-repeat.dict.hex"));
    defer h.a.free(bytes);
    const frame = try h.memory.hexAlloc(@embedFile("../../zstd/testdata/libzstd-trained-repeat.frame.hex"));
    defer h.a.free(frame);
    const parsed = try Z.NativeDictionary.initFromStandardDictionary(bytes);
    var prepared = try Z.PreparedDecodeDictionary.init(parsed.dictionary);
    const plain = try Z.decodeFrameAllocWithOptions(h.a, frame, .{ .dictionary = parsed.dictionary });
    defer h.a.free(plain);
    for ([_]Z.NativeDictionary{ parsed.dictionary, prepared.handle() }) |dictionary| {
        try checkSample(Z, frame, plain, .{}, dictionary);
        try checkSample(Z, frame[4..], plain, .{ .format = .magicless }, dictionary);
        const catalog_entries = [_]Z.NativeDictionary{dictionary};
        const catalog = Z.NativeDictionarySet.init(&catalog_entries);
        const buffer = try h.a.alloc(u8, plain.len);
        defer h.a.free(buffer);
        var decoder = Z.NativeIncrementalFrameDecoder.initWithDictionarySet(h.a, catalog);
        defer decoder.deinit();
        try decoder.bindStableOutput(buffer);
        var count: usize = 0;
        try std.testing.expectEqual(frame.len, try h.drive(&decoder, frame, buffer, &count, plain, 3));
    }
}
