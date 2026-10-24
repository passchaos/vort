const std = @import("std");
const br = @import("../br.zig");
const h = @import("br_large_window_helpers.zig");
const a = std.testing.allocator;

test "Brotli large window default false and instrumentation preserve the frozen complete legacy wires" {
    const chunks = [_][]const u8{ h.plain[0..17], h.plain[17..57], h.plain[57..] };
    for (h.frozen_wires) |sample| {
        const expected = try h.frozenAlloc(a, sample);
        defer a.free(expected);
        for ([_]bool{ false, true }) |profiled| {
            var memory: br.EncodeMemoryProfile = .{};
            var one = h.options(br.PlannedEncodeOptions, sample.setting);
            var stream = h.options(br.PlannedStreamChunksOptions, sample.setting);
            one.large_window = false;
            stream.large_window = false;
            if (profiled) {
                one.memory_profile = &memory;
                stream.memory_profile = &memory;
            }
            const actual = switch (sample.api) {
                .one_shot => try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, one),
                .reusable => block: {
                    var encoder = br.PlannedStreamEncoder.init(a);
                    defer encoder.deinit();
                    break :block try encoder.encodeWithOptionsAlloc(a, h.plain, one);
                },
                .chunks => try br.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, stream),
                .incremental => block: {
                    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(a, .{ .stream = stream, .block_len = 0 });
                    defer encoder.deinit();
                    break :block try h.drive(a, &encoder, h.plain, 31, 17);
                },
            };
            defer a.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
        }
    }
}

fn decodeExtended(bytes: []const u8, expected: []const u8) !void {
    const decoded = try br.decodeStreamAllocWithOptions(a, bytes, .{ .allow_large_window = true });
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    try std.testing.expectError(error.CorruptFrame, br.decodeStreamAlloc(a, bytes));
}

test "Brotli large window all twenty one widths use extension identity and explicit decode consent" {
    for (10..31) |width| {
        errdefer std.debug.print("large-window failed-width={d}\n", .{width});
        for ([_]u4{ 10, 11 }) |quality| {
            var profile: br.HqProfile = .{};
            const bytes = try br.encodePlannedStreamWithOptionsAlloc(a, "window window tail!", .{
                .quality = quality,
                .window_bits = @intCast(width),
                .large_window = true,
                .hq = .{ .profile = &profile },
            });
            defer a.free(bytes);
            try std.testing.expectEqual(@as(u5, @intCast(width)), try h.extensionWindow(bytes));
            try decodeExtended(bytes, "window window tail!");
            try std.testing.expect(profile.effective != null);
            try std.testing.expectEqual(.large_window, profile.effective.?.format);
        }
    }
}

test "Brotli large window q11 complete wire cannot exceed q10 with matching window shape and metadata" {
    for ([_]u5{ 10, 16, 24, 25, 30 }) |width| {
        for ([_]br.PlannedMode{ .generic, .text, .font }) |mode| {
            var options: br.PlannedEncodeOptions = .{
                .quality = 10,
                .mode = mode,
                .window_bits = width,
                .large_window = true,
                .metadata = "large-window contract",
                .hq = .{},
            };
            const q10 = try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, options);
            defer a.free(q10);
            options.quality = 11;
            const q11 = try br.encodePlannedStreamWithOptionsAlloc(a, h.plain, options);
            defer a.free(q11);
            try std.testing.expect(q11.len <= q10.len);
            try std.testing.expectEqual(width, try h.extensionWindow(q10));
            try std.testing.expectEqual(width, try h.extensionWindow(q11));
            try decodeExtended(q10, h.plain);
            try decodeExtended(q11, h.plain);
        }
    }
}

test "Brotli large window empty and one two three byte tails retain explicit extension format" {
    for ([_][]const u8{ "", "x", "xy", "xyz", "abababab" }) |input| {
        const bytes = try br.encodePlannedStreamWithOptionsAlloc(a, input, .{ .quality = 11, .hq = .{}, .large_window = true, .window_bits = 30 });
        defer a.free(bytes);
        try std.testing.expectEqual(@as(u5, 30), try h.extensionWindow(bytes));
        try decodeExtended(bytes, input);
    }
}

test "Brotli large window chunks reusable and fragmented encoders preserve actual meta targets and format" {
    const chunks = [_][]const u8{ h.plain[0..17], h.plain[17..57], h.plain[57..] };
    for ([_]u5{ 16, 25, 30 }) |width| {
        const options: br.PlannedStreamChunksOptions = .{
            .quality = 10,
            .window_bits = width,
            .large_window = true,
            .hq = .{ .block_len = 32 },
        };
        const expected = try br.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, options);
        defer a.free(expected);
        var reusable = br.PlannedStreamEncoder.init(a);
        defer reusable.deinit();
        const owned = try reusable.encodeChunksWithOptionsAlloc(a, &chunks, options);
        defer a.free(owned);
        try std.testing.expectEqualSlices(u8, expected, owned);
        var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(a, .{ .stream = options, .block_len = 0 });
        defer encoder.deinit();
        const fragmented = try h.drive(a, &encoder, h.plain, 1, 1);
        defer a.free(fragmented);
        try std.testing.expectEqualSlices(u8, expected, fragmented);
        try std.testing.expectEqual(width, try h.extensionWindow(expected));
        try decodeExtended(expected, h.plain);
    }
}
