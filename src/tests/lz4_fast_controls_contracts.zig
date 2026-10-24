const std = @import("std");
const lz4 = @import("../lz4.zig");
const h = @import("lz4_fast_controls_helpers.zig");
const a = std.testing.allocator;

test {
    _ = h;
}

test "LZ4 fast controls default one and profile preserve independently frozen raw prefix and frame wires" {
    const dictionary: lz4.NativeDictionary = .{ .id = 42, .content = h.prefix };
    for (h.frozen_wires) |sample| {
        const expected = try h.frozenAlloc(a, sample);
        defer a.free(expected);
        for ([_]bool{ false, true }) |profiled| {
            var profile: lz4.FastEncodeProfile = .{};
            const raw_options: lz4.BlockEncodeOptions = .{ .acceleration = 1, .profile = if (profiled) &profile else null };
            const frame_options: lz4.NativeFrameOptions = .{ .acceleration = 1, .profile = if (profiled) &profile else null };
            const actual = switch (sample.api) {
                .raw => try lz4.encodeBlockWithOptionsAlloc(a, h.plain, raw_options),
                .prefix => try lz4.encodeBlockWithPrefixAndOptionsAlloc(a, h.plain, h.prefix, raw_options),
                .frame => try lz4.encodePureFrameWithOptionsAlloc(a, h.plain, frame_options),
                .frame_linked => block: {
                    var linked = frame_options;
                    linked.block_mode = .linked;
                    linked.block_size_id = .max64kb;
                    break :block try lz4.encodePureFrameWithOptionsAlloc(a, h.plain, linked);
                },
                .dictionary => try lz4.encodeNativeFrameWithDictionaryAlloc(a, h.plain, frame_options, dictionary),
                .reusable_raw => block: {
                    var encoder = try lz4.BlockEncoder.init(a);
                    defer encoder.deinit();
                    break :block try encoder.encodeWithOptionsAlloc(h.plain, raw_options);
                },
                .reusable_prefix => block: {
                    var encoder = try lz4.BlockEncoder.init(a);
                    defer encoder.deinit();
                    break :block try encoder.encodeWithPrefixAndOptionsAlloc(h.plain, h.prefix, raw_options);
                },
                .reusable_frame => block: {
                    var encoder = try lz4.NativeFrameEncoder.init(a);
                    defer encoder.deinit();
                    break :block try encoder.encodeWithOptionsAlloc(h.plain, frame_options);
                },
                .incremental_chunks => block: {
                    var encoder = try lz4.NativeIncrementalFrameEncoder.initExactSize(a, frame_options, h.plain.len);
                    defer encoder.deinit();
                    break :block try h.drive(a, &encoder, h.plain, 31, 17);
                },
                .incremental_dictionary => block: {
                    var options = frame_options;
                    options.dictionary_id = 42;
                    var encoder = try lz4.NativeIncrementalFrameEncoder.initExactSizeWithDictionary(a, options, h.plain.len, 42, h.prefix);
                    defer encoder.deinit();
                    break :block try h.drive(a, &encoder, h.plain, 1, 1);
                },
            };
            defer a.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
            if (profiled) try std.testing.expect(profile.blocks_attempted > 0);
        }
    }
}

test "LZ4 fast controls signed acceleration normalization reaches actual block and frame parsers" {
    const one = try lz4.encodeBlockWithOptionsAlloc(a, h.plain, .{});
    defer a.free(one);
    const max = try lz4.encodeBlockWithOptionsAlloc(a, h.plain, .{ .acceleration = 65537 });
    defer a.free(max);
    for ([_]struct { raw: i32, resolved: u32 }{
        .{ .raw = std.math.minInt(i32), .resolved = 1 }, .{ .raw = -1, .resolved = 1 },        .{ .raw = 0, .resolved = 1 },                        .{ .raw = 1, .resolved = 1 },
        .{ .raw = 65537, .resolved = 65537 },            .{ .raw = 65538, .resolved = 65537 }, .{ .raw = std.math.maxInt(i32), .resolved = 65537 },
    }) |sample| {
        var profile: lz4.FastEncodeProfile = .{};
        const encoded = try lz4.encodeBlockWithOptionsAlloc(a, h.plain, .{ .acceleration = sample.raw, .profile = &profile });
        defer a.free(encoded);
        try std.testing.expectEqual(sample.resolved, profile.resolved_acceleration);
        try std.testing.expectEqualSlices(u8, if (sample.resolved == 1) one else max, encoded);
        const frame = try lz4.encodePureFrameWithOptionsAlloc(a, h.plain, .{ .acceleration = sample.raw, .profile = &profile });
        defer a.free(frame);
        try std.testing.expectEqual(sample.resolved, profile.resolved_acceleration);
        const decoded = try lz4.decodeFrameAlloc(a, frame);
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, h.plain, decoded);
    }
}

test "LZ4 fast controls independent miss schedule counts inspected skipped and clipped steps exactly" {
    const input = try h.unmatched(a, 8192);
    defer a.free(input);
    for ([_]u32{ 1, 2, 8, 64, 65537 }) |acceleration| {
        const expected = h.misses(input.len, acceleration);
        var profile: lz4.FastEncodeProfile = .{};
        const bytes = try lz4.encodeBlockWithOptionsAlloc(a, input, .{ .acceleration = @intCast(acceleration), .chain_depth = 0, .profile = &profile });
        defer a.free(bytes);
        try std.testing.expectEqual(expected.inspected, profile.positions_inspected);
        try std.testing.expectEqual(expected.skipped, profile.positions_skipped);
        try std.testing.expectEqual(expected.maximum_step, profile.max_skip_step);
        try std.testing.expectEqual(@as(u64, 0), profile.chain_candidates);
        try std.testing.expectEqual(@as(u64, 0), profile.match_positions_seeded);
        try std.testing.expectEqual(@as(u8, 0), profile.resolved_chain_depth);
        const decoded = try lz4.decodeBlockAlloc(a, bytes, input.len);
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
    // With acceleration2, 140 bytes end exactly after the sixty-fifth
    // unsuccessful search; three additional bytes admit the first stride3.
    for ([_]struct { len: usize, count: u64, maximum_step: usize }{
        .{ .len = 140, .count = 65, .maximum_step = 2 },
        .{ .len = 143, .count = 66, .maximum_step = 3 },
    }) |boundary| {
        var profile: lz4.FastEncodeProfile = .{};
        const bytes = try lz4.encodeBlockWithOptionsAlloc(a, input[0..boundary.len], .{ .acceleration = 2, .chain_depth = 0, .profile = &profile });
        defer a.free(bytes);
        try std.testing.expectEqual(boundary.count, profile.positions_inspected);
        try std.testing.expectEqual(boundary.maximum_step, profile.max_skip_step);
    }
}

test "LZ4 fast controls acceleration changes real search work independently of chain depth" {
    const input = try h.unmatched(a, 8192);
    defer a.free(input);
    for ([_]u8{ 1, 16 }) |chain_depth| {
        var slow_profile: lz4.FastEncodeProfile = .{};
        var fast_profile: lz4.FastEncodeProfile = .{};
        const slow = try lz4.encodeBlockWithOptionsAlloc(a, input, .{ .chain_depth = chain_depth, .profile = &slow_profile });
        defer a.free(slow);
        const fast = try lz4.encodeBlockWithOptionsAlloc(a, input, .{ .acceleration = 8, .chain_depth = chain_depth, .profile = &fast_profile });
        defer a.free(fast);
        try std.testing.expect(fast_profile.positions_inspected < slow_profile.positions_inspected);
        try std.testing.expectEqual(@as(u64, 0), slow_profile.positions_skipped);
        try std.testing.expect(fast_profile.positions_skipped > 0);
        try std.testing.expectEqual(chain_depth, fast_profile.resolved_chain_depth);
        // These four-byte-unique inputs have no copy: differing search work
        // legitimately serializes the same one-literal sequence.
        try std.testing.expectEqualSlices(u8, slow, fast);
        try std.testing.expectEqual(@as(u64, 0), fast_profile.match_positions_seeded);
    }
}

test "LZ4 fast controls tiny random repetitive and structured blocks preserve prefix and reusable output" {
    const random = try h.unmatched(a, 1024);
    defer a.free(random);
    for ([_][]const u8{ "", "x", "abcd", random, h.plain, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }) |input| {
        for ([_]i32{ 1, 3, 65537 }) |acceleration| {
            const options: lz4.BlockEncodeOptions = .{ .acceleration = acceleration };
            const encoded = try lz4.encodeBlockWithOptionsAlloc(a, input, options);
            defer a.free(encoded);
            const decoded = try lz4.decodeBlockAlloc(a, encoded, input.len);
            defer a.free(decoded);
            try std.testing.expectEqualSlices(u8, input, decoded);
            var encoder = try lz4.BlockEncoder.init(a);
            defer encoder.deinit();
            const scratch = try encoder.encodeScratchWithOptions(input, options);
            try std.testing.expectEqualSlices(u8, encoded, scratch);
            const prefix = try lz4.encodeBlockWithPrefixAndOptionsAlloc(a, input, h.prefix, options);
            defer a.free(prefix);
            const prefix_decoded = try lz4.decodeBlockWithPrefixAlloc(a, prefix, input.len, h.prefix);
            defer a.free(prefix_decoded);
            try std.testing.expectEqualSlices(u8, input, prefix_decoded);
            const prefix_scratch = try encoder.encodeWithPrefixAndOptionsScratch(input, h.prefix, options);
            try std.testing.expectEqualSlices(u8, prefix, prefix_scratch);
        }
    }
}

test "LZ4 fast controls linked frames dictionaries and fragmented input keep identical active controls" {
    const input = try a.alloc(u8, 128 * 1024);
    defer a.free(input);
    for (input, 0..) |*byte, index| byte.* = h.plain[index % h.plain.len];
    const dictionary: lz4.NativeDictionary = .{ .id = 42, .content = h.prefix };
    const dictionary_set: lz4.NativeDictionarySet = .{ .dictionaries = &.{dictionary} };
    for ([_]i32{ 1, 8 }) |acceleration| {
        var profile: lz4.FastEncodeProfile = .{};
        const options: lz4.NativeFrameOptions = .{ .acceleration = acceleration, .block_size_id = .max64kb, .block_mode = .linked, .block_checksum = true, .profile = &profile };
        const expected = try lz4.encodePureFrameWithOptionsAlloc(a, input, options);
        defer a.free(expected);
        try std.testing.expectEqual(@as(u64, 2), profile.blocks_attempted);
        try std.testing.expect(profile.history_positions_seeded > 0);
        try std.testing.expectEqual(@as(u32, @intCast(acceleration)), profile.resolved_acceleration);
        var reusable = try lz4.NativeFrameEncoder.init(a);
        defer reusable.deinit();
        var unprofiled = options;
        unprofiled.profile = null;
        const owned = try reusable.encodeWithOptionsAlloc(input, unprofiled);
        defer a.free(owned);
        try std.testing.expectEqualSlices(u8, expected, owned);
        var incremental = try lz4.NativeIncrementalFrameEncoder.initExactSize(a, unprofiled, input.len);
        defer incremental.deinit();
        const fragmented = try h.drive(a, &incremental, input, 257, 17);
        defer a.free(fragmented);
        try std.testing.expectEqualSlices(u8, expected, fragmented);
        const decoded = try lz4.decodeFrameAlloc(a, expected);
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        const attached = try lz4.encodeNativeFrameWithDictionaryAlloc(a, h.plain, options, dictionary);
        defer a.free(attached);
        const attached_decoded = try lz4.decodeFrameAllocWithDictionary(a, attached, dictionary);
        defer a.free(attached_decoded);
        try std.testing.expectEqualSlices(u8, h.plain, attached_decoded);
        const set_wire = try lz4.encodeNativeFrameWithDictionarySetAlloc(a, h.plain, unprofiled, dictionary_set, 42);
        defer a.free(set_wire);
        try std.testing.expectEqualSlices(u8, attached, set_wire);
    }
}
