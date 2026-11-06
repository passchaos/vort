const std = @import("std");
const h = @import("helpers.zig");
const decode_h = @import("../wide_decode/helpers.zig");

fn provePrefix(comptime Encoder: type) !usize {
    var first = Encoder.initWithOptions(h.allocator, .{ .block_len = 64 });
    defer first.deinit();
    var first_wire: std.ArrayList(u8) = .empty;
    defer first_wire.deinit(h.allocator);
    try h.fullPrefix(&first, &first_wire);
    var actual = Encoder.initWithOptions(h.allocator, .{ .block_len = 64 });
    defer actual.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(h.allocator);
    for (0..19) |n| {
        const start = wire.items.len;
        try h.fullPrefix(&actual, &wire);
        try std.testing.expectEqualSlices(u8, first_wire.items, wire.items[start..]);
        try std.testing.expectEqual(@as(h.Count, (n + 1) * h.prefix.len), actual.total_input);
        try std.testing.expectEqual(@as(h.Count, (n + 1) * first_wire.items.len), actual.total_output);
        try std.testing.expectEqual(first.state.scratch, actual.state.scratch);
        try std.testing.expectEqual(first.state.bit_index, actual.state.bit_index);
        try std.testing.expectEqualSlices(u8, first.state.bytes.items, actual.state.bytes.items);
        if (@hasField(Encoder, "history"))
            try std.testing.expectEqual(first.flush_boundary, actual.flush_boundary);
    }
    return first_wire.items.len;
}

fn crossing(comptime D: type, comptime Encoder: type) !void {
    try h.commonTypes(Encoder);
    const prefix_len = try provePrefix(Encoder);
    const blocks = h.boundary / h.prefix.len - 1;
    const input_prefix = blocks * h.prefix.len;
    const suffix = "raw-wide-tail-xxxxxxxx";
    const expected = input_prefix + suffix.len;
    var encoder = Encoder.initExactSize(h.allocator, .{ .block_len = 64, .max_input_len = expected }, expected);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(h.allocator);
    try h.fullPrefix(&encoder, &wire);
    wire.clearRetainingCapacity();
    // Repeating a complete full-flush prefix preserves the empty history,
    // byte-aligned writer and all parser state. Only these totals grow.
    encoder.total_input = input_prefix;
    encoder.total_output = blocks * prefix_len;
    try h.feed(&encoder, suffix, &wire, 3, 1);
    encoder.partialFlush();
    try h.drain(&encoder, &wire, 2, false);
    encoder.flush();
    try h.drain(&encoder, &wire, 3, false);
    try h.finish(&encoder, &wire, 1);
    try std.testing.expectEqual(expected, encoder.total_input);
    try std.testing.expect(encoder.total_output > h.boundary);
    var decoded: [suffix.len]u8 = undefined;
    const result = try D.decodeRawAuto(wire.items, &decoded);
    try std.testing.expectEqual(suffix.len, result.output_written);
    try std.testing.expectEqualSlices(u8, suffix, &decoded);
    const history = try h.allocator.alloc(u8, 32 * 1024);
    defer h.allocator.free(history);
    var decoder = try D.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(.{}, history);
    decoder.total_input = blocks * prefix_len;
    decoder.total_output = input_prefix;
    try decode_h.drain(&decoder, wire.items, suffix, 1, 2);
    try std.testing.expectEqual(expected, decoder.total_output);
    encoder.reset();
    try std.testing.expectEqual(@as(h.Count, 0), encoder.total_input);
    try std.testing.expectEqual(@as(?h.Count, expected), encoder.expected_input_len);
}

const Periodic = struct { first_wire_len: usize, steady_wire_len: usize, indexed_per_block: h.Count };
const periodic = "abcd" ** 16;

fn periodicPrefix(encoder: anytype) !Periodic {
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(h.allocator);
    var steady: std.ArrayList(u8) = .empty;
    defer steady.deinit(h.allocator);
    var shape: Periodic = undefined;
    var indexed_before: h.Count = 0;
    for (0..1024) |n| {
        wire.clearRetainingCapacity();
        indexed_before = encoder.match_finder.indexed_positions;
        try h.feed(encoder, periodic, &wire, periodic.len, 128);
        encoder.flush();
        try h.drain(encoder, &wire, 128, false);
        if (n == 0) shape.first_wire_len = wire.items.len else if (n == 1) {
            try steady.appendSlice(h.allocator, wire.items);
            shape.steady_wire_len = wire.items.len;
        } else try std.testing.expectEqualSlices(u8, steady.items, wire.items);
    }
    shape.indexed_per_block = encoder.match_finder.indexed_positions - indexed_before;
    try std.testing.expectEqual(@as(usize, 32 * 1024), encoder.history.items.len);
    return shape;
}

/// A complete periodic window is translation invariant. Rotate physical
/// predecessor slots and translate every live absolute chain position; retain
/// local history and code-writer state. The caller first proves one translation
/// against a real additional block before applying the large repeat count.
fn translatePeriodic(encoder: anytype, from_blocks: h.Count, to_blocks: h.Count, shape: Periodic) !void {
    const shift = (to_blocks - from_blocks) * periodic.len;
    const matcher = &encoder.match_finder;
    const translated = try h.allocator.alloc(h.Count, matcher.prev.items.len);
    defer h.allocator.free(translated);
    @memset(translated, h.max_count);
    const minimum = matcher.absolute_position - matcher.prev.items.len;
    for (matcher.head.items, matcher.head_epoch.items) |*head, epoch| {
        if (epoch != matcher.epoch or head.* == h.max_count) continue;
        var position = head.*;
        while (position >= minimum and position < matcher.absolute_position) {
            const previous = matcher.prev.items[h.counts.ringIndex(position, translated.len)];
            const valid = previous >= minimum and previous < position;
            translated[h.counts.ringIndex(position + shift, translated.len)] = if (valid) previous + shift else h.max_count;
            if (!valid) break;
            position = previous;
        }
        head.* += shift;
    }
    @memcpy(matcher.prev.items, translated);
    matcher.absolute_position += shift;
    matcher.indexed_positions += (to_blocks - from_blocks) * shape.indexed_per_block;
    encoder.total_input = to_blocks * periodic.len;
    encoder.total_output = shape.first_wire_len + (to_blocks - 1) * shape.steady_wire_len;
}

fn matcherCrossing(comptime D: type, comptime Encoder: type) !void {
    const dictionary = "abcd" ** (32 * 1024 / 4);
    const first = ("abcd" ** 15) ++ "abcX";
    const suffix = "abcd" ** 16;
    var options = Encoder.Options{ .block_len = 64, .compression = D.optionsForLevel(.fastest) };
    options.max_input_len = h.boundary + 256;
    var wide = Encoder.initWithOptions(h.allocator, options);
    defer wide.deinit();
    var local = Encoder.initWithOptions(h.allocator, options);
    defer local.deinit();
    if (Encoder.supports_runtime_params) {
        try wide.requestParams(.{ .level = 1 });
        try local.requestParams(.{ .level = 1 });
    }
    const shape = try periodicPrefix(&wide);
    try std.testing.expectEqualDeep(shape, try periodicPrefix(&local));
    var wide_wire: std.ArrayList(u8) = .empty;
    defer wide_wire.deinit(h.allocator);
    var local_wire: std.ArrayList(u8) = .empty;
    defer local_wire.deinit(h.allocator);
    try translatePeriodic(&wide, 1024, 1025, shape);
    try h.feed(&local, periodic, &local_wire, periodic.len, 128);
    local.flush();
    try h.drain(&local, &local_wire, 128, false);
    try std.testing.expectEqualDeep(local.matchFinderSnapshot(), wide.matchFinderSnapshot());
    try std.testing.expectEqualSlices(h.Count, local.match_finder.head.items, wide.match_finder.head.items);
    // Sparse prev slots that have never been inserted are undefined. Compare
    // every reachable recent chain instead of reading inactive ring storage.
    const minimum = local.match_finder.absolute_position - local.match_finder.prev.items.len;
    for (local.match_finder.head.items, local.match_finder.head_epoch.items) |head, epoch| {
        if (epoch != local.match_finder.epoch) continue;
        var position = head;
        while (position >= minimum and position < local.match_finder.absolute_position) {
            const slot = h.counts.ringIndex(position, local.match_finder.prev.items.len);
            const actual = local.match_finder.prev.items[slot];
            const model = wide.match_finder.prev.items[slot];
            const valid = actual >= minimum and actual < position;
            try std.testing.expectEqual(if (valid) actual else h.max_count, model);
            if (!valid) break;
            position = actual;
        }
    }
    try std.testing.expectEqual(local.total_input, wide.total_input);
    try std.testing.expectEqual(local.total_output, wide.total_output);
    try std.testing.expectEqualSlices(u8, local.history.items, wide.history.items);
    local_wire.clearRetainingCapacity();
    try translatePeriodic(&wide, 1025, h.boundary / periodic.len - 1, shape);
    if (Encoder.supports_runtime_params) {
        try wide.requestParams(.{ .level = 2 });
        try local.requestParams(.{ .level = 2 });
        try std.testing.expectEqual(@as(h.Count, 2), wide.snapshot().params_change_count);
    }
    inline for (.{ &wide, &local }) |encoder| {
        const wire = if (encoder == &wide) &wide_wire else &local_wire;
        try h.feed(encoder, first, wire, first.len, 128);
        encoder.flush();
        try h.drain(encoder, wire, 128, false);
        try std.testing.expect(encoder.matchFinderSnapshot().initialized);
        try h.feed(encoder, suffix, wire, suffix.len, 128);
        try h.finish(encoder, wire, 128);
    }
    try std.testing.expectEqualSlices(u8, local_wire.items, wide_wire.items);
    try std.testing.expect(wide.match_finder.absolute_position > h.boundary);
    try std.testing.expect(wide.total_input > h.boundary);
    try std.testing.expect(wide.plan_tokens.items[0] == .match);
    try std.testing.expect(wide.plan_tokens.items[0].match.length >= suffix.len - 1);
    try std.testing.expect(wide.plan_tokens.items[0].match.distance != 0);
    var decoded: [first.len + suffix.len]u8 = undefined;
    const result = try D.decodeRawAutoWithDictionary(wide_wire.items, dictionary, &decoded);
    try std.testing.expectEqual(decoded.len, result.output_written);
    try std.testing.expectEqualSlices(u8, first ++ suffix, &decoded);
}

pub fn contracts(comptime D: type) !void {
    inline for (.{ D.RawDeflateIncrementalStoredEncoder, D.RawDeflateIncrementalFixedEncoder, D.RawDeflateIncrementalBestEncoder }) |Encoder|
        try crossing(D, Encoder);
    inline for (.{ D.RawDeflateIncrementalFixedEncoder, D.RawDeflateIncrementalBestEncoder }) |Encoder|
        try matcherCrossing(D, Encoder);
}
