const std = @import("std");
const checksum = @import("../../../checksum.zig");
const deflate = @import("../../../deflate.zig");

const WireFormat = enum { raw, zlib, gzip };
const sync_marker = "\x00\x00\xff\xff";

fn feed(encoder: anytype, input: []const u8, encoded: *std.ArrayList(u8), scratch: []u8) !void {
    var offset: usize = 0;
    while (offset < input.len) {
        const result = try encoder.step(input[offset..], scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        offset += result.progress.input_read;
        if (result.progress.input_read == 0 and result.progress.output_written == 0)
            return error.TestUnexpectedResult;
    }
}

fn drainBoundary(encoder: anytype, encoded: *std.ArrayList(u8), scratch: []u8) !void {
    while (true) {
        const result = try encoder.step("", scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        switch (result.status) {
            .need_input => return,
            .need_output => {},
            .done => return error.TestUnexpectedResult,
        }
    }
}

fn drainDone(encoder: anytype, encoded: *std.ArrayList(u8), scratch: []u8) !void {
    while (true) {
        const result = try encoder.step("", scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        switch (result.status) {
            .done => return,
            .need_output => {},
            .need_input => return error.TestUnexpectedResult,
        }
    }
}

fn finish(encoder: anytype, encoded: *std.ArrayList(u8), scratch: []u8) !void {
    encoder.finish();
    try drainDone(encoder, encoded, scratch);
}

fn expectFixedFixture(
    comptime Encoder: type,
    comptime format: WireFormat,
    expected_boundary_len: usize,
    expected_wire: []const u8,
) !void {
    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [16]u8 = undefined;

    try feed(&encoder, "abc", &encoded, &scratch);
    encoder.blockFlush();
    try drainBoundary(&encoder, &encoded, &scratch);

    try std.testing.expectEqual(expected_boundary_len, encoded.items.len);
    try std.testing.expectEqualSlices(u8, expected_wire[0..expected_boundary_len], encoded.items);
    try std.testing.expect(std.mem.indexOf(u8, encoded.items, sync_marker) == null);

    try feed(&encoder, "XYZ", &encoded, &scratch);
    try finish(&encoder, &encoded, &scratch);
    try std.testing.expectEqualSlices(u8, expected_wire, encoded.items);

    const decoded = switch (format) {
        .raw => try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items),
        .zlib => try deflate.decodeZlibAlloc(std.testing.allocator, encoded.items),
        .gzip => try deflate.decodeGzipAlloc(std.testing.allocator, encoded.items),
    };
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abcXYZ", decoded);
}

test "fixed block flush matches audited libz raw zlib and gzip fixtures" {
    const raw = "\x4a\x4c\x4a\x06\x2c\x22\x32\x0a\x00";
    const zlib = "\x78\x01\x4a\x4c\x4a\x06\x2c\x22\x32\x0a\x00\x07\xd6\x02\x32";
    const gzip = "\x1f\x8b\x08\x00\x00\x00\x00\x00\x04\x03\x4a\x4c\x4a\x06\x2c\x22\x32\x0a\x00\x63\x20\x63\x3a\x06\x00\x00\x00";

    try expectFixedFixture(deflate.RawDeflateIncrementalFixedEncoder, .raw, 4, raw);
    try expectFixedFixture(deflate.ZlibIncrementalFixedEncoder, .zlib, 6, zlib);
    try expectFixedFixture(deflate.GzipIncrementalFixedEncoder, .gzip, 14, gzip);
}

test "best block flush retains history while full flush resets it" {
    const first = "retained block history alpha beta gamma delta 0123456789\n" ** 32;
    const second = "retained block history alpha beta gamma delta 0123456789\n" ** 24;
    const options: deflate.RawDeflateIncrementalBestEncoder.Options = .{
        .block_len = 4096,
        .compression = deflate.optionsForLevel(.default),
    };
    var scratch: [17]u8 = undefined;

    var retained = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, options);
    defer retained.deinit();
    var retained_wire: std.ArrayList(u8) = .empty;
    defer retained_wire.deinit(std.testing.allocator);
    try feed(&retained, first, &retained_wire, &scratch);
    retained.blockFlush();
    try drainBoundary(&retained, &retained_wire, &scratch);
    const retained_snapshot = retained.matchFinderSnapshot();
    try std.testing.expect(retained_snapshot.initialized);
    try std.testing.expectEqual(first.len, retained_snapshot.absolute_position);
    try feed(&retained, second, &retained_wire, &scratch);
    try finish(&retained, &retained_wire, &scratch);
    const retained_decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, retained_wire.items);
    defer std.testing.allocator.free(retained_decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, retained_decoded);

    var reset = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, options);
    defer reset.deinit();
    var reset_wire: std.ArrayList(u8) = .empty;
    defer reset_wire.deinit(std.testing.allocator);
    try feed(&reset, first, &reset_wire, &scratch);
    reset.fullFlush();
    try drainBoundary(&reset, &reset_wire, &scratch);
    const reset_snapshot = reset.matchFinderSnapshot();
    try std.testing.expect(!reset_snapshot.initialized);
    try std.testing.expectEqual(@as(usize, 0), reset_snapshot.absolute_position);
    try feed(&reset, second, &reset_wire, &scratch);
    try finish(&reset, &reset_wire, &scratch);
    const reset_decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, reset_wire.items);
    defer std.testing.allocator.free(reset_decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, reset_decoded);
}

test "stored block flush exposes one explicit non-final stored boundary" {
    const first = "stored block boundary";
    const second = " and final stored data";
    var encoder = deflate.RawDeflateIncrementalStoredEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = 128,
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [7]u8 = undefined;

    try feed(&encoder, first, &encoded, &scratch);
    encoder.blockFlush();
    try drainBoundary(&encoder, &encoded, &scratch);

    try std.testing.expectEqual(first.len + 5, encoded.items.len);
    try std.testing.expectEqual(@as(u8, 0), encoded.items[0]);
    try std.testing.expectEqual(@as(u16, @intCast(first.len)), std.mem.readInt(u16, encoded.items[1..][0..2], .little));
    try std.testing.expectEqual(~@as(u16, @intCast(first.len)), std.mem.readInt(u16, encoded.items[3..][0..2], .little));
    try std.testing.expectEqualSlices(u8, first, encoded.items[5..]);

    try feed(&encoder, second, &encoded, &scratch);
    try finish(&encoder, &encoded, &scratch);
    const decoded = try deflate.decodeRawStoredAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
}

fn expectEmptyBlockFlushIdempotent(comptime Encoder: type) !void {
    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [2]u8 = undefined;

    for (0..3) |_| {
        encoder.blockFlush();
        const result = try encoder.step("", &scratch);
        try std.testing.expectEqual(.need_input, result.status);
        try std.testing.expectEqual(@as(usize, 0), result.progress.input_read);
        try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);
    }
    try std.testing.expectEqual(@as(usize, 0), encoded.items.len);

    try finish(&encoder, &encoded, &scratch);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), decoded.len);
}

test "empty repeated block flush requests are idempotent" {
    try expectEmptyBlockFlushIdempotent(deflate.RawDeflateIncrementalStoredEncoder);
    try expectEmptyBlockFlushIdempotent(deflate.RawDeflateIncrementalFixedEncoder);
    try expectEmptyBlockFlushIdempotent(deflate.RawDeflateIncrementalBestEncoder);
}

test "block flush survives zero-output and one-byte backpressure" {
    const expected = "\x4a\x4c\x4a\x06\x2c\x22\x32\x0a\x00";
    var encoder = deflate.RawDeflateIncrementalFixedEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var feed_scratch: [1]u8 = undefined;

    try feed(&encoder, "abc", &encoded, &feed_scratch);
    encoder.blockFlush();

    var result = try encoder.step("", &.{});
    try std.testing.expectEqual(.need_output, result.status);
    try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);
    try std.testing.expectEqual(@as(usize, 4), encoder.snapshot().pending_output);
    try std.testing.expect(encoder.snapshot().pending_bits != 0);

    result = try encoder.step("", &.{});
    try std.testing.expectEqual(.need_output, result.status);
    try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);
    try std.testing.expectEqual(@as(usize, 4), encoder.snapshot().pending_output);

    var one: [1]u8 = undefined;
    try drainBoundary(&encoder, &encoded, &one);
    try std.testing.expectEqualSlices(u8, expected[0..4], encoded.items);
    try std.testing.expect(encoder.snapshot().pending_bits != 0);

    try feed(&encoder, "XYZ", &encoded, &one);
    try finish(&encoder, &encoded, &one);
    try std.testing.expectEqualSlices(u8, expected, encoded.items);
}

test "pending block flush upgrades to sync flush without duplicate markers" {
    const expected_boundary = "\x4a\x4c\x4a\x06\x00\x00\x00\xff\xff";
    var encoder = deflate.RawDeflateIncrementalFixedEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [8]u8 = undefined;

    try feed(&encoder, "abc", &encoded, &scratch);
    encoder.blockFlush();
    var one: [1]u8 = undefined;
    const first = try encoder.step("", &one);
    try encoded.appendSlice(std.testing.allocator, one[0..first.progress.output_written]);
    try std.testing.expectEqual(.need_output, first.status);
    encoder.flush();
    try drainBoundary(&encoder, &encoded, &one);

    try std.testing.expectEqualSlices(u8, expected_boundary, encoded.items);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, encoded.items, sync_marker));
    try finish(&encoder, &encoded, &one);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abc", decoded);
}

test "pending block flush upgrades to full flush and resets best history" {
    const first = "full upgrade keeps pending output until its marker drains 0123456789\n" ** 24;
    const second = "independent data after the upgraded full boundary\n" ** 16;
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = 4096,
        .compression = deflate.optionsForLevel(.default),
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [19]u8 = undefined;

    try feed(&encoder, first, &encoded, &scratch);
    encoder.blockFlush();
    var one: [1]u8 = undefined;
    const initial = try encoder.step("", &one);
    try encoded.appendSlice(std.testing.allocator, one[0..initial.progress.output_written]);
    try std.testing.expectEqual(.need_output, initial.status);
    try std.testing.expectEqual(first.len, encoder.matchFinderSnapshot().absolute_position);

    encoder.fullFlush();
    try drainBoundary(&encoder, &encoded, &one);
    try std.testing.expect(std.mem.endsWith(u8, encoded.items, sync_marker));
    try std.testing.expectEqual(@as(usize, 0), encoder.matchFinderSnapshot().absolute_position);

    try feed(&encoder, second, &encoded, &scratch);
    try finish(&encoder, &encoded, &scratch);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
}

test "finish honors an undrained block flush request" {
    const payload = "finish after a pending block flush must preserve its non-final boundary\n" ** 12;
    var scratch: [5]u8 = undefined;

    var pending = deflate.RawDeflateIncrementalFixedEncoder.init(std.testing.allocator);
    defer pending.deinit();
    var pending_wire: std.ArrayList(u8) = .empty;
    defer pending_wire.deinit(std.testing.allocator);
    try feed(&pending, payload, &pending_wire, &scratch);
    pending.blockFlush();
    pending.finish();
    try drainDone(&pending, &pending_wire, &scratch);

    var acknowledged = deflate.RawDeflateIncrementalFixedEncoder.init(std.testing.allocator);
    defer acknowledged.deinit();
    var acknowledged_wire: std.ArrayList(u8) = .empty;
    defer acknowledged_wire.deinit(std.testing.allocator);
    try feed(&acknowledged, payload, &acknowledged_wire, &scratch);
    acknowledged.blockFlush();
    try drainBoundary(&acknowledged, &acknowledged_wire, &scratch);
    try finish(&acknowledged, &acknowledged_wire, &scratch);

    try std.testing.expectEqualSlices(u8, acknowledged_wire.items, pending_wire.items);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, pending_wire.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "zlib and gzip best block flush preserve continuous wrapper checksums" {
    const first = "checksum state before block boundary 0123456789\n" ** 13;
    const second = "checksum state after block boundary abcdefghijklmnopqrstuvwxyz\n" ** 17;
    const payload = first ++ second;
    var scratch: [11]u8 = undefined;

    var zlib_encoder = deflate.ZlibIncrementalBestEncoder.initExactSize(std.testing.allocator, .{
        .raw = .{ .block_len = 4096 },
    }, payload.len);
    defer zlib_encoder.deinit();
    var zlib_wire: std.ArrayList(u8) = .empty;
    defer zlib_wire.deinit(std.testing.allocator);
    try feed(&zlib_encoder, first, &zlib_wire, &scratch);
    zlib_encoder.blockFlush();
    try drainBoundary(&zlib_encoder, &zlib_wire, &scratch);
    try feed(&zlib_encoder, second, &zlib_wire, &scratch);
    try finish(&zlib_encoder, &zlib_wire, &scratch);
    try std.testing.expectEqual(
        checksum.Adler32.hash(payload),
        std.mem.readInt(u32, zlib_wire.items[zlib_wire.items.len - 4 ..][0..4], .big),
    );
    const zlib_decoded = try deflate.decodeZlibAlloc(std.testing.allocator, zlib_wire.items);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, payload, zlib_decoded);

    var gzip_encoder = deflate.GzipIncrementalBestEncoder.initExactSize(std.testing.allocator, .{
        .raw = .{ .block_len = 4096 },
    }, payload.len);
    defer gzip_encoder.deinit();
    var gzip_wire: std.ArrayList(u8) = .empty;
    defer gzip_wire.deinit(std.testing.allocator);
    try feed(&gzip_encoder, first, &gzip_wire, &scratch);
    gzip_encoder.blockFlush();
    try drainBoundary(&gzip_encoder, &gzip_wire, &scratch);
    try feed(&gzip_encoder, second, &gzip_wire, &scratch);
    try finish(&gzip_encoder, &gzip_wire, &scratch);
    try std.testing.expectEqual(
        checksum.Crc32Best.hash(payload),
        std.mem.readInt(u32, gzip_wire.items[gzip_wire.items.len - 8 ..][0..4], .little),
    );
    try std.testing.expectEqual(
        @as(u32, @intCast(payload.len)),
        std.mem.readInt(u32, gzip_wire.items[gzip_wire.items.len - 4 ..][0..4], .little),
    );
    const gzip_decoded = try deflate.decodeGzipAlloc(std.testing.allocator, gzip_wire.items);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, payload, gzip_decoded);
}
