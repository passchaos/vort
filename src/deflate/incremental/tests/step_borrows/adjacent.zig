const std = @import("std");
const h = @import("helpers.zig");

fn futureInput(comptime D: type, comptime Format: type, boundary: bool) !void {
    var history: [32768]u8 = @splat(0x5a);
    var decoder = try h.init(D, &history);
    const wire = h.wrap(Format, &h.stored, "abcdef");
    var backing = wire.bytes;
    const before = backing;
    try h.reject(&decoder, backing[0..wire.len], backing[wire.prefix + 13 ..][0..6], boundary);
    try std.testing.expectEqualSlices(u8, &before, &backing);
    var output: [6]u8 = undefined;
    try h.drain(&decoder, wire.slice(), &output);
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
    decoder.reset();
    if (D == h.Stored) {
        decoder.pause_requested = true;
        try h.reject(&decoder, backing[0..wire.len], backing[wire.prefix + 13 ..][0..6], true);
        try std.testing.expect(decoder.pause_requested);
    }
}

fn selfStorage(comptime D: type, comptime Format: type, boundary: bool) !void {
    var history: [32768]u8 = @splat(0x5a);
    var decoder = try h.init(D, &history);
    const wire = h.wrap(Format, &h.stored, "abcdef");
    var output: [6]u8 = @splat(0x81);
    if (D == h.Stored) {
        @memcpy(&decoder.header, &[_]u8{ 1, 0, 0, 0xff, 0xff });
        try h.reject(&decoder, &decoder.header, &output, boundary);
    } else {
        @memcpy(&decoder.prefix, wire.slice()[0..2]);
        try h.reject(&decoder, &decoder.prefix, &output, boundary);
    }
    try h.reject(&decoder, wire.slice(), std.mem.asBytes(&decoder)[0..6], boundary);
    try h.drain(&decoder, wire.slice(), &output);
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
}

fn autoHistory(comptime Format: type, boundary: bool) !void {
    var history: [32768]u8 = @splat(0x5a);
    var decoder = try h.init(h.Auto, &history);
    const wire = h.wrap(Format, &h.stored, "abcdef");
    @memcpy(history[0..wire.len], wire.slice());
    var output: [6]u8 = @splat(0x81);
    try h.reject(&decoder, history[0..wire.len], &output, boundary);
    try h.reject(&decoder, wire.slice(), history[64..70], boundary);
    try h.drain(&decoder, wire.slice(), &output);
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
}

fn autoActive(comptime Format: type, boundary: bool) !void {
    var history: [32768]u8 = @splat(0x5a);
    var decoder = try h.init(h.Auto, &history);
    const wire = h.wrap(Format, &h.fixed, "aaaaaa");
    var prefix: [3]u8 = undefined;
    const accepted = try decoder.step(wire.slice(), &prefix);
    try std.testing.expectEqual(.need_output, accepted.status);
    try std.testing.expectEqual(@as(usize, 3), accepted.progress.output_written);
    try std.testing.expectEqualSlices(u8, "aaa", &prefix);
    try std.testing.expect(decoder.selectedFormat() != null);
    const remaining = wire.slice()[accepted.progress.input_read..];
    var backing: [32]u8 = @splat(0x6a);
    @memcpy(backing[0..remaining.len], remaining);
    try h.reject(&decoder, backing[0..remaining.len], backing[0..3], boundary);
    try h.reject(&decoder, remaining, std.mem.asBytes(&decoder)[0..3], boundary);
    var suffix: [3]u8 = undefined;
    try h.drain(&decoder, remaining, &suffix);
    try std.testing.expectEqualSlices(u8, "aaa", &suffix);
}

test "stored incremental step borrows reject whole calls before header progress" {
    inline for (.{ false, true }) |boundary| {
        try futureInput(h.Stored, h.Stored, boundary);
        try selfStorage(h.Stored, h.Stored, boundary);
    }
    var decoder = h.Stored.init();
    const object = std.mem.asBytes(&decoder);
    const waiting = try decoder.step(object[0..0], object[0..0]);
    try std.testing.expectEqual(.need_input, waiting.status);
    try std.testing.expectEqual(@as(usize, 0), waiting.progress.input_read);
}

test "automatic wrapper incremental step borrows reject before detection and dispatch" {
    inline for (.{ h.Zlib, h.Gzip }) |Format| {
        inline for (.{ false, true }) |boundary| {
            try futureInput(h.Auto, Format, boundary);
            try selfStorage(h.Auto, Format, boundary);
            try autoHistory(Format, boundary);
            try autoActive(Format, boundary);
        }
    }
    var history: [32768]u8 = @splat(0x5a);
    var decoder = try h.init(h.Auto, &history);
    const object = std.mem.asBytes(&decoder);
    const waiting = try decoder.step(history[0..0], object[0..0]);
    try std.testing.expectEqual(.need_input, waiting.status);
    try std.testing.expectEqual(@as(usize, 0), waiting.progress.input_read);
}

test "deflate64 incremental step borrows reject stored input output and receiver overlap" {
    inline for (.{ false, true }) |boundary| {
        var history: [65536]u8 = @splat(0x5a);
        var decoder = try h.init(h.Raw64, &history);
        const wire = h.wrap(h.Raw64, &h.stored, "abcdef");
        var backing = wire.bytes;
        try h.reject(&decoder, backing[0..wire.len], backing[13..19], boundary);
        const table = std.mem.sliceAsBytes(decoder.dynamic_literal_lookup[0..]);
        @memcpy(table[0..wire.len], wire.slice());
        var output: [6]u8 = @splat(0x81);
        try h.reject(&decoder, table[0..wire.len], &output, boundary);
        try h.reject(&decoder, wire.slice(), table[0..6], boundary);
        try h.drain(&decoder, wire.slice(), &output);
        try std.testing.expectEqualSlices(u8, "abcdef", &output);
    }
}
