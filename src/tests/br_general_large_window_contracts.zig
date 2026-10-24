const std = @import("std");
const br = @import("../br.zig");
const h = @import("br_general_large_window_helpers.zig");
const a = std.testing.allocator;

test "Brotli general large window false preserves archived q mode legacy and stored wires" {
    for (h.goldens) |golden| {
        const expected = try h.goldenAlloc(a, golden);
        defer a.free(expected);
        const actual = if (golden.stored_window) |width|
            try br.encodeStoredStreamWithOptionsAlloc(a, h.plain, .{ .window_bits = width })
        else
            try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, .{ .quality = golden.quality, .mode = golden.mode, .level = golden.level, .large_window = false });
        defer a.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
    }
}

test "Brotli general large window all non HQ qualities modes and legacy levels emit requested extension" {
    for ([_]u5{ 16, 24, 25, 30 }) |width| {
        for (0..12) |quality| {
            for ([_]br.PlannedMode{ .generic, .text, .font }) |mode| {
                errdefer std.debug.print("general LargeWindow width={d} quality={d} mode={s}\n", .{ width, quality, @tagName(mode) });
                const options: br.PlannedEncodeOptions = .{ .quality = @intCast(quality), .mode = mode, .window_bits = width, .large_window = true, .metadata = "general format" };
                const bytes = try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, options);
                defer a.free(bytes);
                try std.testing.expect(bytes.len <= try br.encodedPlannedStreamBoundWithOptions(h.plain.len, options));
                const summary = try h.checkExtended(a, bytes, h.plain, width, .{});
                try std.testing.expectEqual(@as(usize, 1), summary.metadata_meta_block_count);
            }
        }
        for ([_]br.PlannedCompressionLevel{ .fast, .balanced, .ratio }) |level| {
            const bytes = try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, .{ .level = level, .window_bits = width, .large_window = true });
            defer a.free(bytes);
            _ = try h.checkExtended(a, bytes, h.plain, width, .{});
        }
    }
}

test "Brotli general large window every quality shares valid chunks reusable append into and incremental routes" {
    const chunks = [_][]const u8{ h.plain[0..17], "", h.plain[17..57], h.plain[57..] };
    for (0..12) |quality| {
        errdefer std.debug.print("general route quality={d}\n", .{quality});
        const options: br.PlannedStreamChunksOptions = .{ .quality = @intCast(quality), .window_bits = 30, .large_window = true, .block_len = 32, .adaptive_blocks = false };
        const expected = try br.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, options);
        defer a.free(expected);
        _ = try h.checkExtended(a, expected, h.plain, 30, .{});
        var reusable = br.PlannedStreamEncoder.init(a);
        defer reusable.deinit();
        const reused = try reusable.encodeChunksWithOptionsAlloc(a, &chunks, options);
        defer a.free(reused);
        try std.testing.expectEqualSlices(u8, expected, reused);
        var appended: std.ArrayList(u8) = .empty;
        defer appended.deinit(a);
        try appended.appendSlice(a, "prefix");
        try reusable.encodeChunksWithOptionsAppend(&appended, &chunks, options);
        try std.testing.expectEqualSlices(u8, "prefix", appended.items[0..6]);
        try std.testing.expectEqualSlices(u8, expected, appended.items[6..]);
        var output: [512]u8 = @splat(0xa5);
        const written = try br.encodePlannedStreamChunksWithOptionsInto(&chunks, &output, options);
        try std.testing.expectEqualSlices(u8, expected, output[0..written]);
        try h.untouched(output[written..]);
        var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(a, .{ .stream = options, .block_len = 0 });
        defer encoder.deinit();
        const fragmented = try h.drive(a, &encoder, h.plain, 1, 1);
        defer a.free(fragmented);
        // Chunk boundaries may delimit legacy meta-blocks. Input quotas do
        // not; each public schedule must still decode the same source bytes.
        _ = try h.checkExtended(a, fragmented, h.plain, 30, .{});
    }
}

test "Brotli general large window stored APIs preserve window metadata and tiny input format" {
    for ([_]u5{ 10, 16, 24, 25, 30 }) |width| {
        for ([_][]const u8{ "", "x", "xy", "xyz", h.plain }) |input| {
            const options: br.StoredStreamOptions = .{ .window_bits = width, .large_window = true, .metadata = "stored extension" };
            const bytes = try br.encodeStoredStreamWithOptionsAlloc(a, input, options);
            defer a.free(bytes);
            const summary = try h.checkExtended(a, bytes, input, width, .{});
            try std.testing.expectEqual(@as(usize, 1), summary.metadata_meta_block_count);
            var stored = br.StoredStreamEncoder.init(a);
            defer stored.deinit();
            const reused = try stored.encodeWithOptionsAlloc(input, options);
            defer a.free(reused);
            try std.testing.expectEqualSlices(u8, bytes, reused);
            const cut = @min(input.len, 2);
            const chunks = [_][]const u8{ "", input[0..cut], input[cut..] };
            const chunked = try stored.encodeChunksWithOptionsAlloc(&chunks, options);
            defer a.free(chunked);
            _ = try h.checkExtended(a, chunked, input, width, .{});
            var appended: std.ArrayList(u8) = .empty;
            defer appended.deinit(a);
            try appended.appendSlice(a, "prefix");
            try stored.encodeChunksWithOptionsAppend(&appended, &chunks, options);
            try std.testing.expectEqualSlices(u8, "prefix", appended.items[0..6]);
            try std.testing.expectEqualSlices(u8, chunked, appended.items[6..]);
            var destination: [512]u8 = @splat(0xa5);
            const written = try stored.encodeChunksWithOptionsIntoSlice(&chunks, options, &destination);
            try std.testing.expectEqualSlices(u8, chunked, destination[0..written]);
            try h.untouched(destination[written..]);
            var streamed = br.IncrementalStoredStreamEncoder.initWithOptions(a, .{ .stream = options, .block_len = 16 });
            defer streamed.deinit();
            const fragmented = try h.drive(a, &streamed, input, 1, 1);
            defer a.free(fragmented);
            _ = try h.checkExtended(a, fragmented, input, width, .{});
        }
    }
}

test "Brotli general large window RAW serialized and custom static dictionaries stay valid on low and command paths" {
    const payload = "specialxspecialyspecialxspecialy" ** 4;
    var bits: [32]u8 = @splat(0);
    bits[8] = 1;
    const serialized = try br.serializeSharedDictionaryAlloc(a, .{
        .raw_prefix = payload,
        .word_lists = &.{.{ .size_bits_by_length = bits, .data = "specialxspecialy" }},
        .transform_lists = &.{.{ .prefix_suffix = &.{0}, .transforms = &.{ 0, 0, 0 } }},
        .dictionaries = &.{.{ .word_list_index = 0, .transform_list_index = 0 }},
    });
    defer a.free(serialized);
    const view = try br.parseSerializedSharedDictionary(serialized);
    const custom_static = try br.serializeSharedDictionaryAlloc(a, .{
        .word_lists = &.{.{ .size_bits_by_length = bits, .data = "specialxspecialy" }},
        .transform_lists = &.{.{ .prefix_suffix = &.{0}, .transforms = &.{ 0, 0, 0 } }},
        .dictionaries = &.{.{ .word_list_index = 0, .transform_list_index = 0 }},
    });
    defer a.free(custom_static);
    const static_view = try br.parseSerializedSharedDictionary(custom_static);
    for ([_]br.SharedDictionary{ .{ .raw_prefixes = &.{payload} }, .{ .serialized = &view }, .{ .serialized = &static_view } }) |shared| {
        for ([_]u4{ 0, 1, 4, 9, 10, 11 }) |quality| {
            const bytes = try br.encodePlannedStreamWithOptionsAlloc(a, payload, .{ .quality = quality, .window_bits = 25, .large_window = true, .shared_dictionary = shared });
            defer a.free(bytes);
            _ = try h.checkExtended(a, bytes, payload, 25, shared);
        }
    }
}

test "Brotli general large window q0 q1 64 KiB sources retain actual compressed fragment format" {
    const input = try a.alloc(u8, 64 * 1024 + 3);
    defer a.free(input);
    const pattern = "q0 q1 actual fragment source abcdefgh\n";
    for (input, 0..) |*byte, index| byte.* = pattern[index % pattern.len];
    for ([_]u4{ 0, 1 }) |quality| {
        const bytes = try br.encodePlannedStreamWithOptionsAlloc(a, input, .{ .quality = quality, .window_bits = 30, .large_window = true });
        defer a.free(bytes);
        const summary = try h.checkExtended(a, bytes, input, 30, .{});
        try std.testing.expect(summary.compressed_meta_block_count > 0);
        try std.testing.expect(summary.max_lz77_distance != 0);
    }
}

test "Brotli general large window q4 accepts actual adaptive entropy blocks" {
    const input = try a.alloc(u8, 64 * 1024);
    defer a.free(input);
    var random: u32 = 0x219f_10b5;
    for (input, 0..) |*byte, index| {
        random = random *% 1664525 +% 1013904223;
        const low: u8 = @truncate(random >> 28);
        byte.* = if (index < input.len / 2) low else 240 + low;
    }
    const options: br.PlannedStreamChunksOptions = .{ .quality = 4, .large_window = true, .window_bits = 30, .block_len = input.len, .adaptive_blocks = true };
    const bytes = try br.encodePlannedStreamChunksWithOptionsAlloc(a, &.{input}, options);
    defer a.free(bytes);
    const summary = try h.checkExtended(a, bytes, input, 30, .{});
    try std.testing.expect(summary.compressed_meta_block_count > 0);
    var incremental = br.IncrementalPlannedStreamEncoder.initWithOptions(a, .{ .stream = options, .block_len = 0 });
    defer incremental.deinit();
    const streamed = try h.drive(a, &incremental, input, 997, 17);
    defer a.free(streamed);
    try std.testing.expectEqualSlices(u8, bytes, streamed);
}
