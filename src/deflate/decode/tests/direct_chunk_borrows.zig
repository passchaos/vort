//! Borrow admission on scratch-free chunk decode and receiver reset.
const std = @import("std");
const t = std.testing;
const zlib = [_]u8{ 0x78, 1, 0, 3, 0, 0xfc, 0xff, 'a', 'b', 'c', 1, 3, 0, 0xfc, 0xff, 'd', 'e', 'f', 8, 0x1e, 2, 0x56 };
const gzip = [_]u8{ 0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 3, 0, 3, 0, 0xfc, 0xff, 'a', 'b', 'c', 1, 3, 0, 0xfc, 0xff, 'd', 'e', 'f', 0xef, 0x39, 0x8e, 0x4b, 6, 0, 0, 0 };
const Kind = enum { zlib, gzip };
fn invoke(comptime D: type, comptime kind: Kind, comptime api: usize, chunks: []const []const u8, output: []u8, dictionary: []const u8) !usize {
    if (kind == .gzip) return if (api == 0) D.decodeGzipChunksInto(chunks, output) else D.decodeGzipChunksIntoWithOptions(chunks, output, .{ .ignore_crc32 = true, .allow_trailing_data = true });
    return switch (api) {
        0 => D.decodeZlibChunksInto(chunks, output),
        1 => D.decodeZlibChunksIntoWithOptions(chunks, output, .{ .ignore_adler = true, .allow_trailing_data = true }),
        2 => D.decodeZlibChunksIntoWithDictionary(chunks, output, dictionary),
        3 => D.decodeZlibChunksIntoWithDictionaryAndOptions(chunks, output, dictionary, .{ .ignore_adler = true, .allow_trailing_data = true }),
        else => unreachable,
    };
}
fn descriptorsEqual(before: anytype, after: anytype) !void {
    for (before, after) |old, current| {
        try t.expectEqual(old.ptr, current.ptr);
        try t.expectEqual(old.len, current.len);
    }
}
fn noSnapshot(comptime D: type, comptime kind: Kind, comptime api: usize) !void {
    const wire: []const u8 = if (kind == .zlib) &zlib else &gzip;
    const split: usize = if (kind == .zlib) 15 else 23;
    inline for (0..8) |site| {
        if (comptime (site == 4 or site == 5) and !(kind == .zlib and api >= 2)) continue;
        errdefer std.debug.print("direct kind={s} api={d} site={d}\n", .{ @tagName(kind), api, site });
        var backing: [256]u8 = @splat(0xa5);
        @memcpy(backing[64..][0..wire.len], wire);
        @memcpy(backing[64 + wire.len ..][0..4], "TAIL");
        var chunks = [_][]const u8{ backing[64 .. 64 + split], backing[64 + split .. 64 + wire.len], "", "" };
        var output: []u8 = backing[64 + split ..][0..6];
        var dictionary: []const u8 = "";
        switch (site) {
            0 => {}, // Actual before bug: overwrite the later Stored payload.
            1 => output = backing[64..][0..wire.len],
            2 => output = backing[57..65], // Only unused output tail intersects input.
            3 => output = std.mem.asBytes(&chunks)[@sizeOf([]const u8)..][0..6],
            4 => {
                dictionary = backing[128..132];
                output = backing[128..136];
            },
            5 => {
                dictionary = backing[128..132];
                output = backing[121..129];
            },
            6 => {
                chunks[1] = backing[64 + split .. 64 + wire.len + 4];
                output = backing[64 + wire.len ..][0..6];
            },
            7 => output = backing[64 + wire.len - 1 ..][0..6],
            else => unreachable,
        }
        const before = backing;
        const descriptors_before = chunks;
        try t.expectError(error.InvalidBlockPlan, invoke(D, kind, api, &chunks, output, dictionary));
        try t.expectEqualSlices(u8, &before, &backing);
        try descriptorsEqual(descriptors_before, chunks);
        var retry: [6]u8 = undefined;
        if (site == 6 and api % 2 == 0) {
            try t.expectError(error.TrailingData, invoke(D, kind, api, &chunks, &retry, dictionary));
        } else {
            try t.expectEqual(@as(usize, 6), try invoke(D, kind, api, &chunks, &retry, dictionary));
            try t.expectEqualSlices(u8, "abcdef", &retry);
        }
        try t.expectEqualSlices(u8, &before, &backing);
        try descriptorsEqual(descriptors_before, chunks);
    }
    for ([_]usize{ 58, 64 + wire.len }) |start| {
        var backing: [128]u8 = @splat(0xa5);
        @memcpy(backing[64..][0..wire.len], wire);
        const chunks = [_][]const u8{ backing[64 .. 64 + split], backing[64 + split .. 64 + wire.len] };
        const output = backing[start..][0..6];
        try t.expectEqual(@as(usize, 6), try invoke(D, kind, api, &chunks, output, if (kind == .zlib and api >= 2) chunks[0] else ""));
        try t.expectEqualSlices(u8, "abcdef", output);
        try t.expectEqualSlices(u8, wire, backing[64..][0..wire.len]);
    }
    const chunks = [_][]const u8{ wire[0..split], wire[split..] };
    var output: [6]u8 = undefined;
    try t.expectError(error.OutputTooSmall, invoke(D, kind, api, &chunks, output[0..0], ""));
    const empty = [_][]const u8{ "", "" };
    try t.expectError(error.TruncatedFrame, invoke(D, kind, api, &empty, &output, ""));
    const huge = @as([*]const u8, @ptrCast(&zlib))[0..std.math.maxInt(usize)];
    const overflow = [_][]const u8{ huge, "x" };
    try t.expectError(error.IntegerOverflow, invoke(D, kind, api, &overflow, &output, ""));
}

fn stackSnapshots(comptime D: type) !void {
    const fixed = try D.encodeZlibFixedAlloc(t.allocator, "abcdef");
    defer t.allocator.free(fixed);
    inline for (0..4) |api| {
        var backing: [128]u8 = @splat(0xa5);
        @memcpy(backing[0..fixed.len], fixed);
        var chunks = [_][]const u8{ backing[0..2], backing[2..fixed.len] };
        try t.expectEqual(@as(usize, 6), try invoke(D, .zlib, api, &chunks, backing[2..8], ""));
        try t.expectEqualSlices(u8, "abcdef", backing[2..8]);
        @memcpy(backing[0..fixed.len], fixed);
        // The bounded join also finishes reading descriptors before output emission.
        try t.expectEqual(@as(usize, 6), try invoke(D, .zlib, api, &chunks, std.mem.asBytes(&chunks)[0..6], ""));
        try t.expectEqualSlices(u8, "abcdef", std.mem.asBytes(&chunks)[0..6]);
        @memcpy(backing[0..zlib.len], &zlib);
        var fragmented: [513][]const u8 = @splat("");
        fragmented[0] = backing[0..15];
        fragmented[1] = backing[15..22];
        try t.expectEqual(@as(usize, 6), try invoke(D, .zlib, api, &fragmented, backing[15..21], ""));
        try t.expectEqualSlices(u8, "abcdef", backing[15..21]);
    }
}

fn presetDictionary(comptime D: type) !void {
    const wire = try D.encodeZlibFixedWithDictionaryAlloc(t.allocator, "Xabcdefghijklmnop", "abcdefghijklmnop", .{});
    defer t.allocator.free(wire);
    const chunks = [_][]const u8{ wire[0..6], wire[6..] };
    inline for (.{ 2, 3 }) |api| {
        var backing: [64]u8 = @splat(0xa5);
        @memcpy(backing[32..48], "abcdefghijklmnop");
        const before = backing;
        // Stack snapshot owns compressed bytes, while preset history remains a read borrow.
        try t.expectError(error.InvalidBlockPlan, invoke(D, .zlib, api, &chunks, backing[32..49], backing[32..48]));
        try t.expectEqualSlices(u8, &before, &backing);
        var retry: [17]u8 = undefined;
        try t.expectEqual(retry.len, try invoke(D, .zlib, api, &chunks, &retry, backing[32..48]));
        try t.expectEqualSlices(u8, "Xabcdefghijklmnop", &retry);
    }
}

fn reset(comptime kind: Kind, comptime variant: usize, decoder: anytype, chunks: []const []const u8, output: []u8, dictionary: []const u8) !void {
    if (kind == .gzip) return switch (variant) {
        0 => decoder.resetFromChunksDirect(chunks, output),
        1 => decoder.resetFromChunksWithOptionsDirect(chunks, output, .{ .ignore_crc32 = true }),
        2 => decoder.resetFromChunksExactSizeDirect(chunks, output, 6),
        3 => decoder.resetFromChunksWithOptionsExactSizeDirect(chunks, output, .{ .ignore_crc32 = true }, 6),
        else => unreachable,
    };
    return switch (variant) {
        0 => decoder.resetFromChunksDirect(chunks, output),
        1 => decoder.resetFromChunksWithOptionsDirect(chunks, output, .{ .ignore_adler = true }),
        2 => decoder.resetFromChunksExactSizeDirect(chunks, output, 6),
        3 => decoder.resetFromChunksWithOptionsExactSizeDirect(chunks, output, .{ .ignore_adler = true }, 6),
        4 => decoder.resetFromChunksWithDictionaryDirect(chunks, dictionary, output),
        5 => decoder.resetFromChunksWithDictionaryAndOptionsDirect(chunks, dictionary, output, .{ .ignore_adler = true }),
        6 => decoder.resetFromChunksWithDictionaryExactSizeDirect(chunks, dictionary, output, 6),
        7 => decoder.resetFromChunksWithDictionaryAndOptionsExactSizeDirect(chunks, dictionary, output, .{ .ignore_adler = true }, 6),
        else => unreachable,
    };
}
fn stateEqual(before: anytype, after: anytype) !void {
    try t.expectEqual(before.decoded.ptr, after.decoded.ptr);
    try t.expectEqual(before.decoded.len, after.decoded.len);
    try t.expectEqual(before.frame_len, after.frame_len);
    try t.expectEqual(before.offset, after.offset);
    try t.expectEqual(before.done, after.done);
    try t.expectEqualSlices(u8, before.last_error_name, after.last_error_name);
    try t.expectEqual(before.last_recoverability_hint, after.last_recoverability_hint);
}
fn receivers(comptime D: type, comptime kind: Kind) !void {
    const Decoder = if (kind == .zlib) D.ZlibDecoder else D.GzipDecoder;
    const wire: []const u8 = if (kind == .zlib) &zlib else &gzip;
    const split: usize = if (kind == .zlib) 15 else 23;
    inline for (0..(if (kind == .zlib) 8 else 4)) |variant| {
        inline for (0..8) |site| {
            if (comptime (site == 3 or site == 7) and !(kind == .zlib and variant >= 4)) continue;
            errdefer std.debug.print("direct reset kind={s} variant={d} site={d}\n", .{ @tagName(kind), variant, site });
            var old_output: [64]u8 = @splat(0xa5);
            var decoder: Decoder = .{};
            const original = [_][]const u8{ wire[0..split], wire[split..] };
            try reset(kind, variant, &decoder, &original, &old_output, "");
            decoder.offset = 2;
            const state_before = decoder;
            const old_before = old_output;
            var backing: [128]u8 = @splat(0xa5);
            @memcpy(backing[64..][0..wire.len], wire);
            var table = [_][]const u8{ backing[64 .. 64 + split], backing[64 + split .. 64 + wire.len], "", "" };
            var chunks: []const []const u8 = &table;
            var output_storage: [64]u8 = @splat(0xa5);
            var output: []u8 = &output_storage;
            var dictionary: []const u8 = "";
            switch (site) {
                0 => output = std.mem.asBytes(&decoder),
                1 => table[0] = std.mem.asBytes(&decoder)[0..1],
                2 => chunks = @as([*]const []const u8, @ptrCast(&decoder.decoded))[0..1],
                3 => dictionary = std.mem.asBytes(&decoder),
                4 => output = backing[64 + split ..][0..6],
                5 => output = std.mem.asBytes(&table)[@sizeOf([]const u8)..][0..6],
                6 => output = backing[57..65],
                7 => {
                    dictionary = backing[112..116];
                    output = backing[105..113];
                },
                else => unreachable,
            }
            const before = backing;
            const table_before = table;
            const output_before = output_storage;
            try t.expectError(error.InvalidBlockPlan, reset(kind, variant, &decoder, chunks, output, dictionary));
            try stateEqual(state_before, decoder);
            try descriptorsEqual(table_before, table);
            try t.expectEqualSlices(u8, &before, &backing);
            try t.expectEqualSlices(u8, &old_before, &old_output);
            try t.expectEqualSlices(u8, &output_before, &output_storage);
            try reset(kind, variant, &decoder, &original, &old_output, "");
            try t.expectEqualSlices(u8, "abcdef", decoder.decoded);
            try t.expectEqual(@as(usize, 0), decoder.offset);
            const empty = [_][]const u8{ "", "" };
            try t.expectError(error.TruncatedFrame, reset(kind, variant, &decoder, &empty, &output_storage, ""));
            try t.expectEqualSlices(u8, &output_before, &output_storage);
        }
    }
    if (comptime kind == .zlib) {
        const fixed = try D.encodeZlibFixedAlloc(t.allocator, "abcdef");
        defer t.allocator.free(fixed);
        inline for (0..8) |variant| {
            var old_output: [64]u8 = @splat(0xa5);
            var decoder: Decoder = .{};
            const original = [_][]const u8{ wire[0..split], wire[split..] };
            try reset(kind, variant, &decoder, &original, &old_output, "");
            decoder.offset = 2;
            var backing: [128]u8 = @splat(0xa5);
            @memcpy(backing[0..fixed.len], fixed);
            const before = backing;
            const chunks = [_][]const u8{ backing[0..2], backing[2..fixed.len] };
            // A separate receiver can install output after the stack snapshot consumes input.
            try reset(kind, variant, &decoder, &chunks, backing[2..8], "");
            try t.expectEqualSlices(u8, "abcdef", decoder.decoded);
            try t.expectEqualSlices(u8, before[0..2], backing[0..2]);
            try t.expectEqualSlices(u8, before[8..], backing[8..]);
            @memcpy(backing[0..fixed.len], fixed);
            try reset(kind, variant, &decoder, &chunks, &old_output, "");
            try t.expectEqualSlices(u8, "abcdef", decoder.decoded);
        }
        const previous_wire = try D.encodeZlibStoredAlloc(t.allocator, fixed);
        defer t.allocator.free(previous_wire);
        inline for (0..8) |variant| {
            var old_output: [64]u8 = @splat(0xa5);
            var output: [64]u8 = @splat(0xa5);
            var decoder: Decoder = .{};
            const previous_chunks = [_][]const u8{ previous_wire[0..2], previous_wire[2..] };
            try decoder.resetFromChunksDirect(&previous_chunks, &old_output);
            const before = decoder;
            const bytes_before = old_output;
            const output_before = output;
            // Previous decoded bytes form a valid small fixed stream, and its descriptor
            // table aliases the receiver's actual slice field. Geometry must win first.
            const self_descriptors = @as([*]const []const u8, @ptrCast(&decoder.decoded))[0..1];
            try t.expectError(error.InvalidBlockPlan, reset(kind, variant, &decoder, self_descriptors, &output, ""));
            try stateEqual(before, decoder);
            try t.expectEqualSlices(u8, &bytes_before, &old_output);
            try t.expectEqualSlices(u8, &output_before, &output);
            const independent = [_][]const u8{decoder.decoded};
            try reset(kind, variant, &decoder, &independent, &output, "");
            try t.expectEqualSlices(u8, "abcdef", decoder.decoded);
        }
    }
}

fn pngReset(comptime variant: usize, decoder: anytype, chunks: []const []const u8, decoded: []u8, filtered: []u8, previous: []u8, info: anytype) !void {
    return switch (variant) {
        0 => decoder.resetFromChunksDirect(chunks, decoded, filtered, previous, 3, 1, 3),
        1 => decoder.resetFromChunksWithInfoDirect(chunks, decoded, filtered, previous, info),
        2 => decoder.resetFromChunksWithOptionsDirect(chunks, decoded, filtered, previous, 3, 1, 3, .{ .ignore_adler = true }),
        3 => decoder.resetFromChunksWithInfoAndOptionsDirect(chunks, decoded, filtered, previous, info, .{ .ignore_adler = true }),
        else => unreachable,
    };
}
fn pngStateEqual(before: anytype, after: anytype) !void {
    try stateEqual(before.zlib, after.zlib);
    try t.expectEqual(before.filtered_row_scratch.ptr, after.filtered_row_scratch.ptr);
    try t.expectEqual(before.filtered_row_scratch.len, after.filtered_row_scratch.len);
    try t.expectEqual(before.previous_row_scratch.ptr, after.previous_row_scratch.ptr);
    try t.expectEqual(before.previous_row_scratch.len, after.previous_row_scratch.len);
    try t.expectEqual(before.row_len, after.row_len);
    try t.expectEqual(before.row_count, after.row_count);
    try t.expectEqual(before.row_index, after.row_index);
    try t.expectEqual(before.bytes_per_pixel, after.bytes_per_pixel);
    try t.expectEqual(before.has_previous, after.has_previous);
}
fn pngReceiver(comptime D: type) !void {
    const wire = try D.encodeZlibStoredAlloc(t.allocator, "\x00abc");
    defer t.allocator.free(wire);
    const info = try D.pngImageInfo(1, 1, 8, .truecolor);
    inline for (0..4) |variant| {
        inline for (0..6) |site| {
            errdefer std.debug.print("PNG direct reset variant={d} site={d}\n", .{ variant, site });
            var decoded_storage: [64]u8 = @splat(0xa5);
            var filtered_storage: [8]u8 = @splat(0xa5);
            var previous_storage: [8]u8 = @splat(0xa5);
            var decoder: D.PngZlibScanlineDecoder = .{};
            const original = [_][]const u8{ wire[0..7], wire[7..] };
            try pngReset(variant, &decoder, &original, &decoded_storage, &filtered_storage, &previous_storage, info);
            decoder.row_index = 1;
            decoder.has_previous = true;
            const state_before = decoder;
            const decoded_before = decoded_storage;
            const filtered_before = filtered_storage;
            const previous_before = previous_storage;
            var backing: [128]u8 = @splat(0xa5);
            @memcpy(backing[0..wire.len], wire);
            var table = [_][]const u8{ backing[0..7], backing[7..wire.len] };
            var chunks: []const []const u8 = &table;
            var decoded: []u8 = &decoded_storage;
            var filtered: []u8 = &filtered_storage;
            var previous: []u8 = &previous_storage;
            switch (site) {
                0 => decoded = std.mem.asBytes(&decoder),
                1 => filtered = std.mem.asBytes(&decoder),
                2 => previous = std.mem.asBytes(&decoder),
                3 => table[0] = std.mem.asBytes(&decoder)[0..1],
                4 => chunks = @as([*]const []const u8, @ptrCast(&decoder.zlib.decoded))[0..1],
                5 => decoded = backing[0..wire.len],
                else => unreachable,
            }
            const before = backing;
            const table_before = table;
            try t.expectError(error.InvalidBlockPlan, pngReset(variant, &decoder, chunks, decoded, filtered, previous, info));
            try pngStateEqual(state_before, decoder);
            try descriptorsEqual(table_before, table);
            try t.expectEqualSlices(u8, &before, &backing);
            try t.expectEqualSlices(u8, &decoded_before, &decoded_storage);
            try t.expectEqualSlices(u8, &filtered_before, &filtered_storage);
            try t.expectEqualSlices(u8, &previous_before, &previous_storage);
            try pngReset(variant, &decoder, &original, &decoded_storage, &filtered_storage, &previous_storage, info);
            try t.expectEqualSlices(u8, "\x00abc", decoder.zlib.decoded);
            try t.expectEqual(@as(usize, 0), decoder.row_index);
        }
    }
}

fn pngImage(comptime D: type, comptime family: usize, comptime options: bool, chunks: []const []const u8, decoded: []u8, history: []u8, filtered: []u8, previous: []u8, info: D.PngImageInfo, output: []u8) !D.PngImageDecodeResult {
    return switch (family) {
        0 => if (options) D.decodePngStoredZlibImageFromChunksWithOptionsDirect(chunks, filtered, previous, info, .{ .ignore_adler = true }, output) else D.decodePngStoredZlibImageFromChunksDirect(chunks, filtered, previous, info, output),
        1 => if (options) D.decodePngStreamingZlibImageFromChunksWithOptionsDirect(chunks, history, filtered, previous, info, .{ .ignore_adler = true }, output) else D.decodePngStreamingZlibImageFromChunksDirect(chunks, history, filtered, previous, info, output),
        2 => if (options) D.decodePngZlibImageFromChunksWithOptionsDirect(chunks, decoded, filtered, previous, info, .{ .ignore_adler = true }, output) else D.decodePngZlibImageFromChunksDirect(chunks, decoded, filtered, previous, info, output),
        else => unreachable,
    };
}
fn pngImages(comptime D: type) !void {
    const wire = try D.encodeZlibStoredAlloc(t.allocator, "\x00abc");
    defer t.allocator.free(wire);
    const info = try D.pngImageInfo(1, 1, 8, .truecolor);
    var history: [32768]u8 = undefined;
    inline for (0..2) |family| {
        inline for (.{ false, true }) |options| {
            inline for (0..6) |site| {
                if (comptime family == 0 and site == 5) continue;
                errdefer std.debug.print("PNG direct image family={d} options={} site={d}\n", .{ family, options, site });
                @memset(&history, 0xa5);
                var decoded: [64]u8 = @splat(0xa5);
                var filtered: [8]u8 = @splat(0xa5);
                var previous: [8]u8 = @splat(0xa5);
                var pixels: [8]u8 = @splat(0xa5);
                var backing: [128]u8 = @splat(0xa5);
                @memcpy(backing[64..][0..wire.len], wire);
                var chunks = [_][]const u8{ backing[64..71], backing[71..][0 .. wire.len - 7], "", "" };
                var output: []u8 = &pixels;
                var filtered_output: []u8 = &filtered;
                var previous_output: []u8 = &previous;
                switch (site) {
                    0 => output = backing[64 + wire.len - 4 ..][0..8],
                    1 => output = std.mem.asBytes(&chunks)[@sizeOf([]const u8)..][0..8],
                    2 => filtered_output = backing[71..79],
                    3 => previous_output = backing[64 + wire.len - 4 ..][0..8],
                    4 => output = backing[58..66], // Only unused pixel-output tail overlaps.
                    5 => {
                        @memcpy(history[0..wire.len], wire);
                        chunks[0] = history[0..7];
                        chunks[1] = history[7..wire.len];
                    },
                    else => unreachable,
                }
                const before = backing;
                const chunks_before = chunks;
                if (comptime site == 4) {
                    // Image geometry clips this eight-byte argument to three
                    // actual pixel writes, all before the source at offset 64.
                    const result = try pngImage(D, family, options, &chunks, &decoded, &history, filtered_output, previous_output, info, output);
                    try t.expectEqual(@as(usize, 3), result.output_written);
                    try t.expectEqual(wire.len, result.zlib_input_read);
                    try t.expectEqualSlices(u8, "abc", output[0..3]);
                    for (backing, 0..) |byte, index| {
                        if (index < 58 or index >= 61) try t.expectEqual(before[index], byte);
                    }
                    try descriptorsEqual(chunks_before, chunks);
                    continue;
                }
                if (comptime family == 1 and (site == 2 or site == 3)) {
                    // Optimized Streaming whole-image drain uses image rows, not these args.
                    const result = try pngImage(D, family, options, &chunks, &decoded, &history, filtered_output, previous_output, info, output);
                    try t.expectEqual(@as(usize, 3), result.output_written);
                    try t.expectEqualSlices(u8, "abc", pixels[0..3]);
                    try t.expectEqualSlices(u8, &before, &backing);
                    try descriptorsEqual(chunks_before, chunks);
                    for (filtered) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
                    for (previous) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
                    continue;
                }
                try t.expectError(error.InvalidBlockPlan, pngImage(D, family, options, &chunks, &decoded, &history, filtered_output, previous_output, info, output));
                try descriptorsEqual(chunks_before, chunks);
                try t.expectEqualSlices(u8, &before, &backing);
                for (decoded) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
                for (filtered) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
                for (previous) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
                for (pixels) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
                if (site == 5) try t.expectEqualSlices(u8, wire, history[0..wire.len]);
                for (history[(if (site == 5) wire.len else 0)..]) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
                const independent = [_][]const u8{ wire[0..7], wire[7..] };
                const result = try pngImage(D, family, options, &independent, &decoded, &history, &filtered, &previous, info, &pixels);
                try t.expectEqual(@as(usize, 1), result.rows);
                try t.expectEqual(@as(usize, 3), result.output_written);
                try t.expectEqual(wire.len, result.zlib_input_read);
                try t.expectEqualSlices(u8, "abc", pixels[0..3]);
            }
        }
    }
    inline for (.{ false, true }) |options| {
        var backing: [128]u8 = @splat(0xa5);
        @memcpy(backing[0..wire.len], wire);
        const chunks = [_][]const u8{ backing[0..7], backing[7..wire.len] };
        var decoded: [64]u8 = undefined;
        var filtered: [8]u8 = undefined;
        var previous: [8]u8 = undefined;
        // This family owns the full decoded payload before it emits pixels.
        const result = try pngImage(D, 2, options, &chunks, &decoded, &history, &filtered, &previous, info, backing[wire.len - 4 ..][0..3]);
        try t.expectEqual(@as(usize, 3), result.output_written);
        try t.expectEqualSlices(u8, "abc", backing[wire.len - 4 ..][0..3]);
        @memcpy(backing[0..wire.len], wire);
        var descriptors = [_][]const u8{ backing[0..7], backing[7..wire.len], "", "" };
        const output = std.mem.asBytes(&descriptors)[@sizeOf([]const u8)..][0..3];
        const descriptor_result = try pngImage(D, 2, options, &descriptors, &decoded, &history, &filtered, &previous, info, output);
        try t.expectEqual(@as(usize, 3), descriptor_result.output_written);
        try t.expectEqualSlices(u8, "abc", output);
    }
}

fn adam7FirstClear(comptime D: type) !void {
    // A 1x1 RGB image has one active Adam7 pass and the same four filtered bytes.
    const wire = try D.encodeZlibStoredAlloc(t.allocator, "\x00abc");
    defer t.allocator.free(wire);
    const info = try D.pngAdam7Info(1, 1, 8, .truecolor);
    var history: [32768]u8 = undefined;
    inline for (.{ false, true }) |options| {
        @memset(&history, 0xa5);
        var filtered: [8]u8 = @splat(0xa5);
        var previous: [8]u8 = @splat(0xa5);
        var backing: [128]u8 = @splat(0xa5);
        @memcpy(backing[64..][0..wire.len], wire);
        const chunks = [_][]const u8{ backing[64..71], backing[71..][0 .. wire.len - 7] };
        const before = backing;
        const rejected = if (options) D.decodePngAdam7StreamingZlibImageFromChunksWithOptionsDirect(&chunks, &history, &filtered, &previous, info, .{ .ignore_adler = true }, backing[64..72]) else D.decodePngAdam7StreamingZlibImageFromChunksDirect(&chunks, &history, &filtered, &previous, info, backing[64..72]);
        try t.expectError(error.InvalidBlockPlan, rejected);
        try t.expectEqualSlices(u8, &before, &backing);
        for (history) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
        for (filtered) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
        for (previous) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
        var image: [3]u8 = undefined;
        const result = if (options) try D.decodePngAdam7StreamingZlibImageFromChunksWithOptionsDirect(&chunks, &history, &filtered, &previous, info, .{ .ignore_adler = true }, &image) else try D.decodePngAdam7StreamingZlibImageFromChunksDirect(&chunks, &history, &filtered, &previous, info, &image);
        try t.expectEqual(@as(usize, 3), result.output_written);
        try t.expectEqualSlices(u8, "abc", &image);
        var decoded: [64]u8 = undefined;
        const reused_source = backing[64 + wire.len - 4 ..][0..3];
        const snapshot = if (options) try D.decodePngAdam7ZlibImageFromChunksWithOptionsDirect(&chunks, &decoded, &filtered, &previous, info, .{ .ignore_adler = true }, reused_source) else try D.decodePngAdam7ZlibImageFromChunksDirect(&chunks, &decoded, &filtered, &previous, info, reused_source);
        try t.expectEqual(@as(usize, 3), snapshot.output_written);
        try t.expectEqualSlices(u8, "abc", reused_source);
        @memcpy(backing[64..][0..wire.len], wire);
        var descriptors = [_][]const u8{ backing[64..71], backing[71..][0 .. wire.len - 7], "", "" };
        const reused_descriptors = std.mem.asBytes(&descriptors)[@sizeOf(usize)..][0..3];
        const descriptor_snapshot = if (options) try D.decodePngAdam7ZlibImageFromChunksWithOptionsDirect(&descriptors, &decoded, &filtered, &previous, info, .{ .ignore_adler = true }, reused_descriptors) else try D.decodePngAdam7ZlibImageFromChunksDirect(&descriptors, &decoded, &filtered, &previous, info, reused_descriptors);
        try t.expectEqual(@as(usize, 3), descriptor_snapshot.output_written);
        try t.expectEqualSlices(u8, "abc", reused_descriptors);
    }
}

fn storedImageProgress(comptime D: type) !void {
    const wire = try D.encodeZlibStoredAlloc(t.allocator, "\x00abc");
    defer t.allocator.free(wire);
    const chunks = [_][]const u8{ wire[0..7], wire[7..] };
    const info = try D.pngImageInfo(1, 1, 8, .truecolor);
    var filtered: [8]u8 = undefined;
    var previous: [8]u8 = undefined;
    var decoder = try D.PngStoredZlibChunkedScanlineDecoder.initWithInfoAndOptions(&chunks, &filtered, &previous, info, .{});
    const initial = decoder.snapshot().input_read;
    try t.expectEqual(@as(usize, 2), initial);
    var row: [3]u8 = undefined;
    const step = try decoder.step(&row);
    try t.expectEqual(@as(usize, 13), step.progress.input_read);
    try t.expectEqual(initial + step.progress.input_read, decoder.snapshot().input_read);
    try t.expectEqual(wire.len, decoder.snapshot().input_read);
    try t.expectEqualSlices(u8, "abc", &row);
}

pub fn contracts(comptime D: type) !void {
    inline for (std.enums.values(Kind)) |kind| {
        inline for (0..(if (kind == .zlib) 4 else 2)) |api| try noSnapshot(D, kind, api);
        try receivers(D, kind);
    }
    try stackSnapshots(D);
    try presetDictionary(D);
    try pngReceiver(D);
    try pngImages(D);
    try adam7FirstClear(D);
    try storedImageProgress(D);
}
