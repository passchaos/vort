const std = @import("std");
const observer = @import("observer.zig");
const f = @import("fixtures.zig");
const existing = @import("../br_total_memory_helpers.zig");
const a = std.testing.allocator;
const prefix = "caller prefix";

pub fn streamOptions(comptime D: type, options: D.PlannedEncodeOptions, block_len: usize) D.PlannedStreamChunksOptions {
    return .{
        .quality = options.quality,
        .level = options.level,
        .mode = options.mode,
        .hq = options.hq,
        .disable_literal_context_modeling = options.disable_literal_context_modeling,
        .large_window = options.large_window,
        .window_bits = options.window_bits orelse 16,
        .block_len = block_len,
        .adaptive_blocks = false,
        .metadata = options.metadata,
        .shared_dictionary = options.shared_dictionary,
    };
}

pub fn decodeOptions(comptime D: type, options: anytype) D.DecodeOptions {
    return .{ .allow_large_window = options.large_window, .shared_dictionary = options.shared_dictionary };
}

pub fn effective(options: anytype) bool {
    return options.disable_literal_context_modeling or
        (options.hq != null and options.hq.?.disable_literal_context_modeling);
}

pub fn contracts(comptime D: type, stats: *observer.Stats) !void {
    try defaultFrozen(D, stats);
    for (existing.settings[0..15]) |setting| {
        var options = existing.options(D.PlannedEncodeOptions, setting);
        options.window_bits = 16;
        for ([_]bool{ false, true }) |disabled| {
            options.disable_literal_context_modeling = disabled;
            errdefer std.debug.print("literal context setting={s} disabled={}\n", .{ @tagName(setting), disabled });
            const wire = try D.encodePlannedStreamWithOptionsAlloc(a, f.repeated, options);
            defer a.free(wire);
            const checked = try observer.check(D, wire, f.repeated, disabled, decodeOptions(D, options));
            try std.testing.expect(checked.compressed_blocks != 0);
            if (setting != .q0) try std.testing.expect(checked.lz77_copies != 0);
            stats.add(checked);
            const stream = streamOptions(D, options, 1024);
            const chunks = [_][]const u8{ "", f.repeated[0..17], f.repeated[17..1000], "", f.repeated[1000..] };
            const chunked = try D.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, stream);
            defer a.free(chunked);
            stats.add(try observer.check(D, chunked, f.repeated, disabled, decodeOptions(D, stream)));
            var incremental = D.IncrementalPlannedStreamEncoder.initWithOptions(a, .{ .stream = stream, .block_len = 0 });
            defer incremental.deinit();
            const fragmented = try existing.drive(a, &incremental, f.repeated, 37, 13);
            defer a.free(fragmented);
            stats.add(try observer.check(D, fragmented, f.repeated, disabled, decodeOptions(D, stream)));
            try std.testing.expectEqual(@as(D.IncrementalPlannedStreamEncoder.Counter, f.repeated.len), incremental.snapshot().input_read);
            try std.testing.expectEqual(@as(D.IncrementalPlannedStreamEncoder.Counter, @intCast(fragmented.len)), incremental.snapshot().output_written);
        }
    }
    for ([_]D.PlannedEncodeOptions{
        .{ .quality = 2, .disable_literal_context_modeling = true },
        .{ .quality = 8, .mode = .text, .disable_literal_context_modeling = true },
        .{ .quality = 10, .mode = .font, .large_window = true, .window_bits = 25, .disable_literal_context_modeling = true, .hq = .{ .beam_width = 2, .iterations = 1, .block_len = 1024, .distance_parameters = D.HqDistanceParameters.init(1, 6) } },
    }) |options| {
        try oneForms(D, f.repeated, options, stats);
        try chunkForms(D, f.repeated, streamOptions(D, options, 1024), stats);
    }
    const heterogeneous = try f.heterogeneous(a);
    defer a.free(heterogeneous);
    for ([_]bool{ false, true }) |disabled| {
        const options: D.PlannedEncodeOptions = .{ .quality = 8, .disable_literal_context_modeling = disabled };
        const wire = try D.encodePlannedStreamWithOptionsAlloc(a, heterogeneous, options);
        defer a.free(wire);
        stats.add(try observer.check(D, wire, heterogeneous, disabled, .{}));
    }
}

fn defaultFrozen(comptime D: type, stats: *observer.Stats) !void {
    // Reuse archived wires instead of recapturing the current implementation.
    for (existing.frozen_wires) |sample| {
        if (sample.api != .one_shot) continue;
        const options = existing.options(D.PlannedEncodeOptions, sample.setting);
        const implicit = try D.encodePlannedStreamWithOptionsAlloc(a, existing.plain, options);
        defer a.free(implicit);
        var explicit = options;
        explicit.disable_literal_context_modeling = false;
        if (explicit.hq != null) explicit.hq.?.disable_literal_context_modeling = false;
        const false_wire = try D.encodePlannedStreamWithOptionsAlloc(a, existing.plain, explicit);
        defer a.free(false_wire);
        const frozen = try existing.frozenAlloc(a, sample);
        defer a.free(frozen);
        try std.testing.expectEqualSlices(u8, frozen, implicit);
        try std.testing.expectEqualSlices(u8, frozen, false_wire);
        stats.add(try observer.check(D, implicit, existing.plain, false, .{}));
        stats.add(try observer.check(D, false_wire, existing.plain, false, .{}));
    }
}

pub fn oneForms(comptime D: type, input: []const u8, options: D.PlannedEncodeOptions, stats: *observer.Stats) !void {
    const disabled = effective(options);
    const decode = decodeOptions(D, options);
    const expected = try D.encodePlannedStreamWithOptionsAlloc(a, input, options);
    defer a.free(expected);
    stats.add(try observer.check(D, expected, input, disabled, decode));
    const buffer = try a.alloc(u8, @max(expected.len, try D.encodedPlannedStreamBoundWithOptions(input.len, options)) + 32);
    defer a.free(buffer);
    @memset(buffer, 0xa5);
    const written = try D.encodePlannedStreamWithOptionsInto(input, buffer[16 .. buffer.len - 16], options);
    try std.testing.expectEqualSlices(u8, expected, buffer[16..][0..written]);
    try f.guards(buffer[0..16]);
    try f.guards(buffer[16 + written ..]);
    stats.add(try observer.check(D, buffer[16..][0..written], input, disabled, decode));
    var reusable = D.PlannedStreamEncoder.init(a);
    defer reusable.deinit();
    const owned = try reusable.encodeWithOptionsAlloc(a, input, options);
    defer a.free(owned);
    try std.testing.expectEqualSlices(u8, expected, owned);
    stats.add(try observer.check(D, owned, input, disabled, decode));
    const scratch = try reusable.encodeScratchWithOptions(input, options);
    try std.testing.expectEqualSlices(u8, expected, scratch);
    stats.add(try observer.check(D, scratch, input, disabled, decode));
    @memset(buffer, 0xa5);
    const reused_written = try reusable.encodeIntoWithOptions(input, buffer[16 .. buffer.len - 16], options);
    try std.testing.expectEqualSlices(u8, expected, buffer[16..][0..reused_written]);
    try f.guards(buffer[0..16]);
    try f.guards(buffer[16 + reused_written ..]);
    stats.add(try observer.check(D, buffer[16..][0..reused_written], input, disabled, decode));
}

pub fn chunkForms(comptime D: type, input: []const u8, options: D.PlannedStreamChunksOptions, stats: *observer.Stats) !void {
    const chunks = [_][]const u8{ "", input[0 .. input.len / 3], "", input[input.len / 3 ..], "" };
    const disabled = effective(options);
    const decode = decodeOptions(D, options);
    const expected = try D.encodePlannedStreamChunksWithOptionsAlloc(a, &chunks, options);
    defer a.free(expected);
    stats.add(try observer.check(D, expected, input, disabled, decode));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, prefix);
    try D.encodePlannedStreamChunksWithOptionsAppend(a, &out, &chunks, options);
    try std.testing.expectEqualSlices(u8, prefix, out.items[0..prefix.len]);
    try std.testing.expectEqualSlices(u8, expected, out.items[prefix.len..]);
    stats.add(try observer.check(D, out.items[prefix.len..], input, disabled, decode));
    const buffer = try a.alloc(u8, @max(expected.len, try D.encodedPlannedStreamChunksBoundWithOptions(&chunks, options)) + 32);
    defer a.free(buffer);
    @memset(buffer, 0xa5);
    const written = try D.encodePlannedStreamChunksWithOptionsInto(&chunks, buffer[16 .. buffer.len - 16], options);
    try std.testing.expectEqualSlices(u8, expected, buffer[16..][0..written]);
    try f.guards(buffer[0..16]);
    try f.guards(buffer[16 + written ..]);
    stats.add(try observer.check(D, buffer[16..][0..written], input, disabled, decode));
    var reusable = D.PlannedStreamEncoder.init(a);
    defer reusable.deinit();
    const owned = try reusable.encodeChunksWithOptionsAlloc(a, &chunks, options);
    defer a.free(owned);
    try std.testing.expectEqualSlices(u8, expected, owned);
    stats.add(try observer.check(D, owned, input, disabled, decode));
    out.items.len = prefix.len;
    try reusable.encodeChunksWithOptionsAppend(&out, &chunks, options);
    try std.testing.expectEqualSlices(u8, prefix, out.items[0..prefix.len]);
    try std.testing.expectEqualSlices(u8, expected, out.items[prefix.len..]);
    stats.add(try observer.check(D, out.items[prefix.len..], input, disabled, decode));
    @memset(buffer, 0xa5);
    const reused_written = try reusable.encodeChunksWithOptionsInto(&chunks, buffer[16 .. buffer.len - 16], options);
    try std.testing.expectEqualSlices(u8, expected, buffer[16..][0..reused_written]);
    try f.guards(buffer[0..16]);
    try f.guards(buffer[16 + reused_written ..]);
    stats.add(try observer.check(D, buffer[16..][0..reused_written], input, disabled, decode));
    const scratch = try reusable.encodeChunksScratchWithOptions(&chunks, options);
    try std.testing.expectEqualSlices(u8, expected, scratch);
    stats.add(try observer.check(D, scratch, input, disabled, decode));
}
