const std = @import("std");
const h = @import("helpers.zig");
const f = @import("fixtures.zig");
const storage = @import("decoder_storage.zig");

fn encoder(comptime E: type, allocator: std.mem.Allocator) !void {
    const Count = @FieldType(E, "total_input");
    const prefix_count: Count = (@as(Count, 1) << 32) - 8;
    var source = E.init(allocator);
    defer source.deinit();
    var first_wire: std.ArrayList(u8) = .empty;
    defer first_wire.deinit(allocator);
    try h.feed(allocator, &source, "xxxxxxxx", &first_wire, 17);
    source.fullFlush();
    try h.drain(allocator, &source, &first_wire, 17, false);
    const raw = h.rawOf(&source);
    try std.testing.expectEqual(@as(usize, 0), raw.plain.items.len);
    try std.testing.expectEqual(@as(u3, 0), raw.state.bit_index);
    const raw_stride = raw.total_output;
    const header_len = source.total_output - raw_stride;
    // Each real full-flush prefix has identical wire and empty retained match
    // history. Summarize copies of that verified byte-aligned prefix.
    var replay = E.init(allocator);
    defer replay.deinit();
    var replay_wire: std.ArrayList(u8) = .empty;
    defer replay_wire.deinit(allocator);
    for (0..3) |index| {
        const start = replay_wire.items.len;
        try h.feed(allocator, &replay, "xxxxxxxx", &replay_wire, 13);
        replay.fullFlush();
        try h.drain(allocator, &replay, &replay_wire, 13, false);
        try std.testing.expectEqualSlices(u8, first_wire.items[if (index == 0) 0 else @intCast(header_len)..], replay_wire.items[start..]);
    }
    raw.total_input = prefix_count;
    raw.total_output = raw_stride * (prefix_count / 8);
    raw.expected_input_len = prefix_count + 17;
    if (@hasField(E, "raw")) {
        source.total_input = prefix_count;
        source.stream_input = prefix_count;
        source.total_output = header_len + raw.total_output;
        source.stream_output = source.total_output;
        if (@hasField(E, "crc")) source.crc.value = ~f.repeatedCrc(prefix_count) else {
            const digest = f.repeatedAdler(prefix_count);
            source.adler = .{ .a = digest & 0xffff, .b = digest >> 16 };
        }
    }
    var copy = try source.clone(allocator);
    defer copy.deinit();
    try h.expectEncoder(&source, &copy, true);
    const old_output = source.total_output;
    h.rawOf(&copy).expected_input_len = prefix_count + 19;
    var left_wire: std.ArrayList(u8) = .empty;
    defer left_wire.deinit(allocator);
    var right_wire: std.ArrayList(u8) = .empty;
    defer right_wire.deinit(allocator);
    try h.feed(allocator, &source, "x" ** 17, &left_wire, 1);
    try h.finish(allocator, &source, &left_wire, 1);
    try h.feed(allocator, &copy, "x" ** 19, &right_wire, 7);
    copy.partialFlush();
    try h.drain(allocator, &copy, &right_wire, 3, false);
    try h.finish(allocator, &copy, &right_wire, 7);
    try std.testing.expectEqual(prefix_count + 17, h.rawOf(&source).total_input);
    try std.testing.expectEqual(prefix_count + 19, h.rawOf(&copy).total_input);
    try std.testing.expectEqual(old_output + left_wire.items.len, source.total_output);
    try std.testing.expectEqual(old_output + right_wire.items.len, copy.total_output);
    if (@hasField(E, "raw")) {
        try std.testing.expectEqual(prefix_count + 17, source.stream_input);
        try std.testing.expectEqual(prefix_count + 19, copy.stream_input);
        const source_digest = if (@hasField(E, "crc")) source.crc.digest() else source.adler.digest();
        const copy_digest = if (@hasField(E, "crc")) copy.crc.digest() else copy.adler.digest();
        const expected_source = if (@hasField(E, "crc")) f.repeatedCrc(prefix_count + 17) else f.repeatedAdler(prefix_count + 17);
        const expected_copy = if (@hasField(E, "crc")) f.repeatedCrc(prefix_count + 19) else f.repeatedAdler(prefix_count + 19);
        try std.testing.expectEqual(expected_source, source_digest);
        try std.testing.expectEqual(expected_copy, copy_digest);
        const footer_len: usize = if (@hasField(E, "crc")) 8 else 4;
        const left_footer = left_wire.items[left_wire.items.len - footer_len ..];
        const right_footer = right_wire.items[right_wire.items.len - footer_len ..];
        try std.testing.expectEqual(expected_source, std.mem.readInt(u32, left_footer[0..4], if (@hasField(E, "crc")) .little else .big));
        try std.testing.expectEqual(expected_copy, std.mem.readInt(u32, right_footer[0..4], if (@hasField(E, "crc")) .little else .big));
        if (@hasField(E, "crc")) {
            try std.testing.expectEqual(@as(u32, @truncate(prefix_count + 17)), std.mem.readInt(u32, left_footer[4..8], .little));
            try std.testing.expectEqual(@as(u32, @truncate(prefix_count + 19)), std.mem.readInt(u32, right_footer[4..8], .little));
        }
    }
}

fn wrapperDecoder(comptime T: type, comptime Raw: type, allocator: std.mem.Allocator, comptime gzip: bool) !void {
    const Count = @FieldType(T, "total_output");
    const count: Count = (@as(Count, 1) << 32) - 1;
    const source_history = try allocator.alloc(u8, Raw.required_history_len);
    defer allocator.free(source_history);
    const copy_history = try allocator.alloc(u8, Raw.required_history_len);
    defer allocator.free(copy_history);
    var source = try T.init(.{}, source_history);
    var copy = try T.init(.{}, copy_history);
    const header: []const u8 = if (gzip) &.{ 0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 3 } else &.{ 0x78, 0x01 };
    const raw_prefix = [_]u8{ 0, 1, 0, 0xfe, 0xff, 'x' };
    const prefix = try std.mem.concat(allocator, u8, &.{ header, &raw_prefix });
    defer allocator.free(prefix);
    var output: [1]u8 = undefined;
    const first = try source.step(prefix, &output);
    try std.testing.expectEqual(prefix.len, first.progress.input_read);
    try std.testing.expect(source.raw.atBlockBoundary());
    source.total_input = header.len + count * raw_prefix.len;
    source.raw.total_input = count * raw_prefix.len;
    source.total_output = count;
    source.raw.total_output = count;
    source.raw.history_len = source.raw.history.len;
    source.raw.history_pos = @intCast(count % source.raw.history.len);
    @memset(source.raw.history, 'x');
    if (gzip) {
        source.member_output = count;
        source.crc.value = ~f.repeatedCrc(count);
    } else {
        source.stream_output = count;
        const digest = f.repeatedAdler(count);
        source.adler = .{ .a = digest & 0xffff, .b = digest >> 16 };
    }
    try source.cloneInto(&copy, .{ .history = copy_history });
    try std.testing.expectEqualDeep(source.snapshot(), copy.snapshot());
    inline for (.{ .{ &source, @as(usize, 2) }, .{ &copy, @as(usize, 3) } }) |branch| {
        var suffix: [16]u8 = @splat(0);
        suffix[0] = 1;
        std.mem.writeInt(u16, suffix[1..3], branch[1], .little);
        std.mem.writeInt(u16, suffix[3..5], ~@as(u16, branch[1]), .little);
        @memset(suffix[5..][0..branch[1]], 'x');
        const footer = suffix[5 + branch[1] ..];
        const expected_digest = if (gzip) f.repeatedCrc(count + branch[1]) else f.repeatedAdler(count + branch[1]);
        std.mem.writeInt(u32, footer[0..4], expected_digest, if (gzip) .little else .big);
        if (gzip) std.mem.writeInt(u32, footer[4..8], @truncate(count + branch[1]), .little);
        const wire_len = 5 + branch[1] + (if (gzip) @as(usize, 8) else 4);
        try storage.continueDecoder(allocator, branch[0], suffix[0..wire_len], ("x" ** 3)[0..branch[1]], 1, 1);
        try std.testing.expectEqual(count + branch[1], branch[0].total_output);
        try std.testing.expectEqual(expected_digest, if (gzip) branch[0].crc.digest() else branch[0].adler.digest());
    }
}

pub fn contracts(comptime D: type, allocator: std.mem.Allocator) !void {
    var physical: [257]u8 = @splat('x');
    for (0..physical.len + 1) |length| {
        try std.testing.expectEqual(f.adler(physical[0..length]), f.repeatedAdler(length));
        try std.testing.expectEqual(f.crc(physical[0..length]), f.repeatedCrc(length));
    }
    inline for (.{ D.RawDeflateIncrementalStoredEncoder, D.RawDeflateIncrementalFixedEncoder, D.RawDeflateIncrementalBestEncoder, D.ZlibIncrementalFixedEncoder, D.ZlibIncrementalBestEncoder, D.GzipIncrementalFixedEncoder, D.GzipIncrementalBestEncoder }) |E|
        try encoder(E, allocator);
    try wrapperDecoder(D.ZlibIncrementalDecoder, D.RawDeflateIncrementalFixedLiteralDecoder, allocator, false);
    try wrapperDecoder(D.GzipIncrementalDecoder, D.RawDeflateIncrementalFixedLiteralDecoder, allocator, true);
}
