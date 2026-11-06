//! Incremental RFC 1950 window caps, managed parameters and failed admission.
const std = @import("std");
const core = @import("../../core.zig");
const checksum = @import("../../checksum.zig");
const window = @import("window.zig");
const a = std.testing.allocator;

pub fn contracts(comptime D: type) !void {
    inline for (.{ D.ZlibIncrementalFixedEncoder, D.ZlibIncrementalBestEncoder }) |Encoder| {
        try invalidWindows(Encoder);
        try wrapperPreflight(Encoder);
        try lockedWindow(Encoder);
        try defaultWire(D, Encoder);
        try cappedDictionaryAndBlocks(D, Encoder);
        try resetAndNextStream(D, Encoder);
    }
    try managedParamsAndFlushes(D);
    inline for (.{ D.RawDeflateIncrementalFixedEncoder, D.RawDeflateIncrementalBestEncoder }) |Encoder|
        try rawWindowBinding(D, Encoder);
}

fn feed(encoder: anytype, input: []const u8, wire: *std.ArrayList(u8), chunk_len: usize, output_len: usize) !void {
    var scratch: [4096]u8 = undefined;
    var offset: usize = 0;
    var calls: usize = 0;
    while (offset != input.len) : (calls += 1) {
        try std.testing.expect(calls < 16 * (input.len + 1));
        const end = offset + @min(chunk_len, input.len - offset);
        const stepped = try encoder.step(input[offset..end], scratch[0..output_len]);
        offset += stepped.progress.input_read;
        try wire.appendSlice(a, scratch[0..stepped.progress.output_written]);
        try std.testing.expect(stepped.progress.input_read != 0 or stepped.progress.output_written != 0);
    }
}

fn drain(encoder: anytype, wire: *std.ArrayList(u8), finishing: bool, output_len: usize) !void {
    var scratch: [4096]u8 = undefined;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < 100000);
        const stepped = try encoder.step("", scratch[0..output_len]);
        try wire.appendSlice(a, scratch[0..stepped.progress.output_written]);
        if (stepped.status == .done) {
            try std.testing.expect(finishing);
            return;
        }
        if (stepped.status == .need_input) {
            try std.testing.expect(!finishing);
            return;
        }
        try std.testing.expect(stepped.progress.output_written != 0);
    }
}

fn finish(encoder: anytype, wire: *std.ArrayList(u8), output_len: usize) !void {
    encoder.finish();
    try drain(encoder, wire, true, output_len);
}

fn hashes(encoder: anytype) [6]u64 {
    return .{
        std.hash.Wyhash.hash(0, encoder.pending.items),
        std.hash.Wyhash.hash(0, encoder.raw.pending.items),
        std.hash.Wyhash.hash(0, encoder.raw.plain.items),
        std.hash.Wyhash.hash(0, encoder.raw.history.items),
        std.hash.Wyhash.hash(0, encoder.raw.state.bytes.items),
        @as(u64, encoder.adler.digest()),
    };
}

fn expectWindowFailure(encoder: anytype) !void {
    const before = encoder.snapshot();
    const buffers = hashes(encoder);
    const matcher = encoder.raw.matchFinderSnapshot();
    const bound = encoder.raw.window_limit;
    const retained_bound = encoder.raw.retained_window_limit;
    const header = encoder.published_window_bits;
    var guard: [9]u8 = @splat(0xa5);
    try std.testing.expectError(error.InvalidZlibWindow, encoder.step("offered", &guard));
    try std.testing.expectError(error.InvalidZlibWindow, encoder.requestParams(.{ .level = 1 }));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqualDeep(buffers, hashes(encoder));
    try std.testing.expectEqualDeep(matcher, encoder.raw.matchFinderSnapshot());
    try std.testing.expectEqual(bound, encoder.raw.window_limit);
    try std.testing.expectEqual(retained_bound, encoder.raw.retained_window_limit);
    try std.testing.expectEqual(header, encoder.published_window_bits);
    for (guard) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn invalidWindows(comptime Encoder: type) !void {
    for ([_]u8{ 0, 8, 16, 255 }) |bits| {
        inline for (0..4) |constructor| {
            const options: Encoder.Options = .{ .window_bits = bits };
            var encoder = switch (constructor) {
                0 => Encoder.initWithOptions(std.testing.failing_allocator, options),
                1 => Encoder.initExactSize(std.testing.failing_allocator, options, 7),
                2 => Encoder.initWithDictionary(std.testing.failing_allocator, options, "dictionary"),
                3 => Encoder.initExactSizeWithDictionary(std.testing.failing_allocator, options, 7, "dictionary"),
                else => unreachable,
            };
            defer encoder.deinit();
            try expectWindowFailure(&encoder);
            try std.testing.expect(!encoder.header_written);
            try std.testing.expectEqual(@as(usize, 0), encoder.pending.capacity);
            const before = encoder.snapshot();
            try std.testing.expectError(error.InvalidZlibWindow, encoder.nextStream(options, "changed"));
            try std.testing.expectError(error.InvalidZlibWindow, encoder.nextStreamExactSize(options, "changed", 3));
            try std.testing.expectEqualDeep(before, encoder.snapshot());
            try std.testing.expectEqualSlices(u8, if (constructor >= 2) "dictionary" else "", encoder.dictionary);
        }
    }
}

fn expectAdmissionError(expected: anyerror, encoder: anytype, input: []const u8) !void {
    const before = encoder.snapshot();
    const buffers = hashes(encoder);
    const matcher = encoder.raw.matchFinderSnapshot();
    const epoch = encoder.raw.match_finder.epoch;
    const bound = encoder.raw.window_limit;
    const retained_bound = encoder.raw.retained_window_limit;
    var guard: [9]u8 = @splat(0xa5);
    try std.testing.expectError(expected, encoder.step(input, &guard));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqualDeep(buffers, hashes(encoder));
    try std.testing.expectEqualDeep(matcher, encoder.raw.matchFinderSnapshot());
    try std.testing.expectEqual(epoch, encoder.raw.match_finder.epoch);
    try std.testing.expectEqual(bound, encoder.raw.window_limit);
    try std.testing.expectEqual(retained_bound, encoder.raw.retained_window_limit);
    for (guard) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn wrapperPreflight(comptime Encoder: type) !void {
    var encoder = Encoder.init(a);
    defer encoder.deinit();
    // Model retained raw state before an outer header is published. The new
    // valid declaration would shrink it, but rejected calls must preserve it.
    try encoder.raw.history.appendSlice(a, "x" ** 1024);
    encoder.raw.match_finder.absolute_position = 1024;
    encoder.raw.match_finder.initialized = true;
    encoder.options.window_bits = 9;
    encoder.raw.options.block_len = 0;
    try expectAdmissionError(error.InvalidBlockPlan, &encoder, "");
    encoder.raw.options.block_len = 1024;
    encoder.raw.total_input = std.math.maxInt(core.StreamCount) - 1;
    try expectAdmissionError(error.IntegerOverflow, &encoder, "ab");
    encoder.raw.total_input = 0;
    encoder.raw.total_output = std.math.maxInt(core.StreamCount);
    try expectAdmissionError(error.IntegerOverflow, &encoder, "a");
    encoder.raw.total_output = 0;
    encoder.stream_count = std.math.maxInt(core.StreamCount);
    try expectAdmissionError(error.IntegerOverflow, &encoder, "");
    encoder.stream_count = 0;
    if (Encoder.supports_runtime_params) {
        encoder.raw.params_change_count = std.math.maxInt(core.StreamCount);
        const before = encoder.snapshot();
        const buffers = hashes(&encoder);
        const bound = encoder.raw.window_limit;
        try std.testing.expectError(error.IntegerOverflow, encoder.requestParams(.{ .level = 6 }));
        try std.testing.expectError(error.InvalidCompressionLevel, encoder.requestParams(.{ .level = 10 }));
        try std.testing.expectEqualDeep(before, encoder.snapshot());
        try std.testing.expectEqualDeep(buffers, hashes(&encoder));
        try std.testing.expectEqual(bound, encoder.raw.window_limit);
    }
}

fn lockedWindow(comptime Encoder: type) !void {
    var encoder = Encoder.initWithOptions(a, .{ .window_bits = 9, .raw = .{ .block_len = 2048 } });
    defer encoder.deinit();
    if (Encoder.supports_runtime_params) try encoder.requestParams(.{ .level = 6 });
    // A complete header can be pending even though no caller output fits.
    const header_step = try encoder.step("", &.{});
    try std.testing.expectEqual(.need_output, header_step.status);
    try std.testing.expectEqual(@as(?u8, 9), encoder.published_window_bits);
    for ([_]u8{ 0, 8, 10, 15, 16, 255 }) |bits| {
        encoder.options.window_bits = bits;
        try expectWindowFailure(&encoder);
    }
    encoder.options.window_bits = 9;
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try feed(&encoder, "already accepted bytes before a queued parameter boundary", &wire, 5, 1);
    if (Encoder.supports_runtime_params) {
        try encoder.requestParams(.{ .level = 1 });
        try std.testing.expect(encoder.snapshot().params_boundary_pending);
        try std.testing.expect(encoder.snapshot().active_params != null);
        try std.testing.expect(encoder.snapshot().requested_params != null);
    }
    for ([_]u8{ 0, 8, 10, 16, 255 }) |bits| {
        encoder.options.window_bits = bits;
        try expectWindowFailure(&encoder);
    }
    encoder.options.window_bits = 9;
    try drain(&encoder, &wire, false, 1);
    try finish(&encoder, &wire, 1);
    encoder.options.window_bits = 10;
    try expectWindowFailure(&encoder);
}

fn decodeAtCap(comptime D: type, raw: []const u8, payload: []const u8, dictionary: []const u8, cap: usize) !void {
    var history: [32768]u8 = undefined;
    var decoder = try D.RawDeflateIncrementalFixedLiteralDecoder.initWithDictionary(.{
        .max_distance = cap,
        .expected_output_len = payload.len,
    }, &history, dictionary);
    const output = try a.alloc(u8, payload.len);
    defer a.free(output);
    var read: usize = 0;
    var written: usize = 0;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < 16 * (payload.len + raw.len + 1));
        const stepped = try decoder.step(
            raw[read..][0..@min(@as(usize, 11), raw.len - read)],
            output[written..][0..@min(@as(usize, 17), output.len - written)],
        );
        read += stepped.progress.input_read;
        written += stepped.progress.output_written;
        if (stepped.status == .done) break;
        try std.testing.expect(stepped.progress.input_read != 0 or stepped.progress.output_written != 0);
    }
    try decoder.finish();
    try std.testing.expectEqual(raw.len, read);
    try std.testing.expectEqualSlices(u8, payload, output);
}

fn expectZlib(comptime D: type, wire: []const u8, payload: []const u8, dictionary: []const u8, bits: u8) !void {
    try std.testing.expectEqual((bits - 8) << 4 | @as(u8, 8), wire[0]);
    try std.testing.expectEqual(@as(u16, 0), std.mem.readInt(u16, wire[0..2], .big) % 31);
    const has_dictionary = wire[1] & 0x20 != 0;
    try std.testing.expectEqual(dictionary.len != 0, has_dictionary);
    const offset: usize = if (has_dictionary) 6 else 2;
    if (has_dictionary)
        try std.testing.expectEqual(checksum.adler32(dictionary), std.mem.readInt(u32, wire[2..6], .big));
    try decodeAtCap(D, wire[offset .. wire.len - 4], payload, dictionary, try window.windowLen(bits));
    try std.testing.expectEqual(checksum.adler32(payload), std.mem.readInt(u32, wire[wire.len - 4 ..][0..4], .big));
    const decoded = if (has_dictionary)
        try D.decodeZlibAllocWithDictionary(a, wire, dictionary)
    else
        try D.decodeZlibAlloc(a, wire);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

fn defaultWire(comptime D: type, comptime Encoder: type) !void {
    var encoder = Encoder.init(a);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try feed(&encoder, "abc", &wire, 1, 1);
    try finish(&encoder, &wire, 1);
    try std.testing.expectEqualSlices(u8, &.{ 0x78, 0x01, 0x4b, 0x4c, 0x4a, 0x06, 0x00, 0x02, 0x4d, 0x01, 0x27 }, wire.items);
    try expectZlib(D, wire.items, "abc", "", 15);
    for (window.min_bits..window.max_bits + 1) |wide| {
        const bits: u8 = @intCast(wide);
        try encoder.nextStream(.{ .window_bits = bits }, "");
        wire.clearRetainingCapacity();
        try finish(&encoder, &wire, 1);
        try expectZlib(D, wire.items, "", "", bits);
        try std.testing.expectEqual(@as(usize, 8), wire.items.len);
    }
}

fn noise(output: []u8, seed: u32) void {
    var value = seed;
    for (output) |*byte| {
        value ^= value << 13;
        value ^= value >> 17;
        value ^= value << 5;
        byte.* = @truncate(value >> 16);
    }
}

fn cappedDictionaryAndBlocks(comptime D: type, comptime Encoder: type) !void {
    var dictionary: [2048]u8 = undefined;
    noise(&dictionary, 0x9e3779b9);
    var payload: [2560]u8 = undefined;
    @memcpy(payload[0..512], dictionary[256..768]);
    noise(payload[512..1536], 0x31415926);
    @memcpy(payload[1536..2048], payload[0..512]);
    @memcpy(payload[2048..], dictionary[dictionary.len - 512 ..]);
    inline for (.{ .hash, .greedy, .lazy, .optimal }) |parser| {
        const compression: D.CompressionOptions = .{ .parser = parser, .block_selection = .stored_fixed };
        for ([_]u8{ 9, 10, 15 }) |bits| {
            inline for (0..3) |planning| {
                var options: Encoder.Options = .{
                    .window_bits = bits,
                    .raw = .{ .block_len = 768, .compression = compression },
                };
                if (planning == 1) options.raw.lookahead_len = 19;
                if (planning == 2) {
                    options.raw.adaptive_blocks = true;
                    options.raw.compression.split_options = .{ .min_block_len = 256, .max_block_len = 768, .sample_len = 128, .search_step = 128 };
                }
                for ([_][]const u8{ &dictionary, "" }) |dict| {
                    var encoder = Encoder.initWithDictionary(a, options, dict);
                    defer encoder.deinit();
                    var wire: std.ArrayList(u8) = .empty;
                    defer wire.deinit(a);
                    try feed(&encoder, &payload, &wire, if (planning == 0) payload.len else 37, 17);
                    try finish(&encoder, &wire, 17);
                    try std.testing.expect(encoder.raw.history.items.len <= try window.windowLen(bits));
                    try std.testing.expectEqualDeep(options.raw.compression, encoder.raw.options.compression);
                    try expectZlib(D, wire.items, &payload, dict, bits);
                    if (bits == 15 and planning == 0) {
                        const offset: usize = if (dict.len == 0) 2 else 6;
                        try std.testing.expectError(error.InvalidMatch, decodeAtCap(D, wire.items[offset .. wire.items.len - 4], &payload, dict, 512));
                    }
                }
            }
        }
    }
}

fn resetAndNextStream(comptime D: type, comptime Encoder: type) !void {
    var dictionary: [2048]u8 = undefined;
    noise(&dictionary, 0x9e3779b9);
    const payload = dictionary[256..768];
    var encoder = Encoder.initWithDictionary(a, .{ .window_bits = 10, .raw = .{ .block_len = 256 } }, &dictionary);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try feed(&encoder, payload, &wire, 13, 7);
    encoder.options.window_bits = 9;
    encoder.reset();
    try std.testing.expectEqual(@as(?u8, null), encoder.published_window_bits);
    wire.clearRetainingCapacity();
    try feed(&encoder, payload, &wire, 13, 1);
    try finish(&encoder, &wire, 1);
    try expectZlib(D, wire.items, payload, &dictionary, 9);
    const completed = encoder.snapshot();
    const raw_options = encoder.raw.options;
    try std.testing.expectError(error.InvalidZlibWindow, encoder.nextStream(.{ .window_bits = 8 }, "other"));
    try std.testing.expectError(error.InvalidZlibWindow, encoder.nextStreamExactSize(.{ .window_bits = 16 }, "other", 3));
    try std.testing.expectError(error.InvalidBlockPlan, encoder.nextStream(.{ .window_bits = 10, .raw = .{ .block_len = 0 } }, "other"));
    try std.testing.expectError(error.InvalidBlockPlan, encoder.nextStreamExactSize(.{ .window_bits = 10, .raw = .{ .block_len = 0 } }, "other", 3));
    try std.testing.expectEqualDeep(completed, encoder.snapshot());
    try std.testing.expectEqualDeep(raw_options, encoder.raw.options);
    try std.testing.expectEqualSlices(u8, &dictionary, encoder.dictionary);
    try encoder.nextStreamExactSize(.{ .window_bits = 11, .raw = .{ .block_len = 257 } }, &dictionary, payload.len);
    wire.clearRetainingCapacity();
    try feed(&encoder, payload, &wire, 13, 1);
    try finish(&encoder, &wire, 1);
    try expectZlib(D, wire.items, payload, &dictionary, 11);
    try std.testing.expectEqual(@as(core.StreamCount, 2), encoder.stream_count);
}

fn expectParams(encoder: anytype, level: u4) !void {
    try std.testing.expectEqual(level, encoder.snapshot().active_params.?.level);
    try std.testing.expect(encoder.snapshot().requested_params == null);
    try std.testing.expectEqualDeep(encoder.raw.active_params.?.compression, encoder.raw.options.compression);
    try std.testing.expectEqual(@as(usize, 512), encoder.raw.window_limit);
}

fn managedParamsAndFlushes(comptime D: type) !void {
    var dictionary: [2048]u8 = undefined;
    noise(&dictionary, 0x9e3779b9);
    const first = dictionary[dictionary.len - 512 ..];
    var encoder = D.ZlibIncrementalBestEncoder.initWithDictionary(a, .{ .window_bits = 9, .raw = .{ .block_len = 1024 } }, &dictionary);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(a);
    try encoder.requestParams(.{ .level = 6 });
    try expectParams(&encoder, 6);
    try std.testing.expectEqual(@as(usize, 32768), encoder.raw.options.compression.lz77_options.window_len);
    for ([_]u4{ 1, 2, 0, 6 }) |level| {
        try feed(&encoder, first, &wire, 7, 3);
        try payload.appendSlice(a, first);
        try encoder.requestParams(.{ .level = level });
        if (encoder.snapshot().params_boundary_pending) {
            try std.testing.expectEqual(level, encoder.snapshot().requested_params.?.level);
            try drain(&encoder, &wire, false, 3);
        }
        try expectParams(&encoder, level);
    }
    inline for (.{ .block, .partial, .sync, .full }) |mode| {
        try feed(&encoder, first, &wire, 11, 1);
        try payload.appendSlice(a, first);
        switch (mode) {
            .block => encoder.blockFlush(),
            .partial => encoder.partialFlush(),
            .sync => encoder.flush(),
            .full => encoder.fullFlush(),
            else => unreachable,
        }
        try drain(&encoder, &wire, false, 1);
        try std.testing.expectEqual(@as(usize, 512), encoder.raw.window_limit);
        if (mode == .full) {
            try std.testing.expect(!encoder.raw.dictionary_available);
            try std.testing.expectEqual(@as(usize, 0), encoder.raw.history.items.len);
        } else try std.testing.expectEqual(@as(usize, 512), encoder.raw.history.items.len);
    }
    // Public raw options may choose a larger generic search window; the outer
    // declaration must still cap distances without introducing the dictionary
    // again after the completed full flush.
    const full_flush_offset = wire.items.len;
    var after_full_flush: [2048]u8 = undefined;
    @memcpy(after_full_flush[0..512], first);
    noise(after_full_flush[512..1536], 0x31415926);
    @memcpy(after_full_flush[1536..], first);
    encoder.raw.options.compression = .{ .parser = .lazy, .lz77_options = .{ .window_len = 65535 } };
    encoder.raw.options.block_len = 4096;
    encoder.raw.window_limit = 32768;
    try feed(&encoder, &after_full_flush, &wire, 13, 1);
    try payload.appendSlice(a, &after_full_flush);
    try finish(&encoder, &wire, 1);
    try std.testing.expectEqual(@as(usize, 512), encoder.raw.window_limit);
    try std.testing.expect(!encoder.raw.dictionary_available);
    try expectZlib(D, wire.items, payload.items, &dictionary, 9);
    try decodeAtCap(D, wire.items[full_flush_offset .. wire.items.len - 4], &after_full_flush, "", 512);
    encoder.options.window_bits = 10;
    encoder.reset();
    wire.clearRetainingCapacity();
    try encoder.requestParams(.{ .level = 6 });
    try std.testing.expectEqual(@as(usize, 1024), encoder.raw.window_limit);
    try std.testing.expectEqual(@as(u4, 6), encoder.snapshot().active_params.?.level);
    try feed(&encoder, first, &wire, 13, 1);
    try finish(&encoder, &wire, 1);
    try expectZlib(D, wire.items, first, &dictionary, 10);
}

fn rawWindowBinding(comptime D: type, comptime Encoder: type) !void {
    var payload: [32768 + 511]u8 = undefined;
    noise(&payload, 0x9e3779b9);
    var encoder = Encoder.initWithOptions(a, .{ .block_len = 1024, .compression = D.optionsForLevel(.fastest) });
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try feed(&encoder, &payload, &wire, 4093, 4096);
    encoder.blockFlush();
    try drain(&encoder, &wire, false, 4096);
    // The default format cap retains 32 KiB even with a 16 KiB preset search.
    try std.testing.expectEqual(@as(usize, 32768), encoder.history.items.len);
    const matcher = encoder.matchFinderSnapshot();
    const suffix = try a.dupe(u8, encoder.history.items[encoder.history.items.len - 512 ..]);
    defer a.free(suffix);
    encoder.window_limit = 512;
    encoder.options.block_len = 0;
    var guard: [9]u8 = @splat(0xa5);
    const invalid_before = encoder.snapshot();
    const history_hash = std.hash.Wyhash.hash(0, encoder.history.items);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.step("", &guard));
    try std.testing.expectEqualDeep(invalid_before, encoder.snapshot());
    try std.testing.expectEqualDeep(matcher, encoder.matchFinderSnapshot());
    try std.testing.expectEqual(history_hash, std.hash.Wyhash.hash(0, encoder.history.items));
    encoder.options.block_len = 1024;
    const saved_input = encoder.total_input;
    encoder.total_input = std.math.maxInt(core.StreamCount) - 1;
    const count_before = encoder.snapshot();
    try std.testing.expectError(error.IntegerOverflow, encoder.step("ab", &guard));
    try std.testing.expectEqualDeep(count_before, encoder.snapshot());
    try std.testing.expectEqualDeep(matcher, encoder.matchFinderSnapshot());
    try std.testing.expectEqual(history_hash, std.hash.Wyhash.hash(0, encoder.history.items));
    encoder.total_input = saved_input;
    _ = try encoder.step("", &guard);
    try std.testing.expectEqualSlices(u8, suffix, encoder.history.items);
    try std.testing.expectEqual(matcher.absolute_position, encoder.matchFinderSnapshot().absolute_position);
    try std.testing.expect(!encoder.matchFinderSnapshot().initialized);
    encoder.reset();
    try std.testing.expectEqual(@as(usize, 512), encoder.window_limit);
    encoder.options.compression.lz77_options.window_len = 65535;
    wire.clearRetainingCapacity();
    try feed(&encoder, payload[0..2048], &wire, 2048, 4096);
    try finish(&encoder, &wire, 4096);
    try std.testing.expectEqual(@as(usize, 512), encoder.history.items.len);
    try decodeAtCap(D, wire.items, payload[0..2048], "", 512);
    encoder.resetWithOptions(.{ .block_len = 1024, .compression = .{ .lz77_options = .{ .window_len = 1 } } });
    wire.clearRetainingCapacity();
    try feed(&encoder, "a" ** 2048, &wire, 2048, 4096);
    try finish(&encoder, &wire, 4096);
    try std.testing.expectEqual(@as(usize, 512), encoder.history.items.len);
    try decodeAtCap(D, wire.items, "a" ** 2048, "", 1);
}
