const std = @import("std");
const checksum = @import("../../../checksum.zig");
const deflate = @import("../../../deflate.zig");

const WireFormat = enum { raw, zlib, gzip };

fn feed(encoder: anytype, input: []const u8, wire: *std.ArrayList(u8), scratch: []u8) !void {
    var offset: usize = 0;
    while (offset < input.len) {
        const result = try encoder.step(input[offset..], scratch);
        try wire.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        offset += result.progress.input_read;
        if (result.progress.input_read == 0 and result.progress.output_written == 0)
            return error.TestUnexpectedResult;
    }
}

fn drainBoundary(encoder: anytype, wire: *std.ArrayList(u8), scratch: []u8) !void {
    while (true) {
        const result = try encoder.step("", scratch);
        try wire.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        switch (result.status) {
            .need_input => return,
            .need_output => {},
            .done => return error.TestUnexpectedResult,
        }
    }
}

fn finish(encoder: anytype, wire: *std.ArrayList(u8), scratch: []u8) !void {
    encoder.finish();
    while (true) {
        const result = try encoder.step("", scratch);
        try wire.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        switch (result.status) {
            .done => return,
            .need_output => {},
            .need_input => return error.TestUnexpectedResult,
        }
    }
}

fn expectFixedFixture(
    comptime Encoder: type,
    comptime format: WireFormat,
    boundary_len: usize,
    expected: []const u8,
) !void {
    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    var scratch: [3]u8 = undefined;

    try feed(&encoder, "abc", &wire, &scratch);
    encoder.partialFlush();
    try drainBoundary(&encoder, &wire, &scratch);
    try std.testing.expectEqual(boundary_len, wire.items.len);
    try std.testing.expectEqualSlices(u8, expected[0..boundary_len], wire.items);
    try std.testing.expect(encoder.snapshot().pending_bits != 0);

    try feed(&encoder, "XYZ", &wire, &scratch);
    try finish(&encoder, &wire, &scratch);
    try std.testing.expectEqualSlices(u8, expected, wire.items);
    const decoded = switch (format) {
        .raw => try deflate.decodeRawAutoAlloc(std.testing.allocator, wire.items),
        .zlib => try deflate.decodeZlibAlloc(std.testing.allocator, wire.items),
        .gzip => try deflate.decodeGzipAlloc(std.testing.allocator, wire.items),
    };
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abcXYZ", decoded);
}

test "fixed partial flush matches audited libz raw zlib and gzip fixtures" {
    const raw = "\x4a\x4c\x4a\x06\x08\xb0\x88\xc8\x28\x00";
    const zlib = "\x78\x01\x4a\x4c\x4a\x06\x08\xb0\x88\xc8\x28\x00\x07\xd6\x02\x32";
    const gzip = "\x1f\x8b\x08\x00\x00\x00\x00\x00\x04\x03" ++ raw ++
        "\x63\x20\x63\x3a\x06\x00\x00\x00";
    try expectFixedFixture(deflate.RawDeflateIncrementalFixedEncoder, .raw, 5, raw);
    try expectFixedFixture(deflate.ZlibIncrementalFixedEncoder, .zlib, 7, zlib);
    try expectFixedFixture(deflate.GzipIncrementalFixedEncoder, .gzip, 15, gzip);
}

test "stored partial flush continues from the non-byte-aligned fixed marker" {
    const expected = "\x00\x03\x00\xfc\xffabc\x02\x04\x03\x00\xfc\xffXYZ";
    var encoder = deflate.RawDeflateIncrementalStoredEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    var scratch: [2]u8 = undefined;
    try feed(&encoder, "abc", &wire, &scratch);
    encoder.partialFlush();
    try drainBoundary(&encoder, &wire, &scratch);
    try std.testing.expectEqualSlices(u8, expected[0..9], wire.items);
    try std.testing.expectEqual(@as(u3, 2), encoder.snapshot().pending_bits);
    try feed(&encoder, "XYZ", &wire, &scratch);
    try finish(&encoder, &wire, &scratch);
    try std.testing.expectEqualSlices(u8, expected, wire.items);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, wire.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abcXYZ", decoded);
}

test "empty partial flush is idempotent and upgrades to sync flush" {
    var encoder = deflate.RawDeflateIncrementalFixedEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    var one: [1]u8 = undefined;

    encoder.partialFlush();
    try drainBoundary(&encoder, &wire, &one);
    try std.testing.expectEqualSlices(u8, "\x02", wire.items);
    try std.testing.expectEqual(@as(u3, 2), encoder.snapshot().pending_bits);
    encoder.partialFlush();
    try drainBoundary(&encoder, &wire, &one);
    try std.testing.expectEqualSlices(u8, "\x02", wire.items);

    encoder.flush();
    try drainBoundary(&encoder, &wire, &one);
    try std.testing.expectEqualSlices(u8, "\x02\x00\x00\x00\xff\xff", wire.items);
    try std.testing.expectEqual(@as(u3, 0), encoder.snapshot().pending_bits);
    try finish(&encoder, &wire, &one);
    try std.testing.expectEqualSlices(u8, "\x02\x00\x00\x00\xff\xff\x03\x00", wire.items);
}

test "partial flush survives zero and one-byte output backpressure" {
    var encoder = deflate.RawDeflateIncrementalFixedEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    var one: [1]u8 = undefined;
    try feed(&encoder, "abc", &wire, &one);
    encoder.partialFlush();
    var result = try encoder.step("", &.{});
    try std.testing.expectEqual(.need_output, result.status);
    try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);
    // The old data block drains before the empty fixed marker is generated.
    try std.testing.expectEqual(@as(usize, 4), encoder.snapshot().pending_output);
    result = try encoder.step("", &.{});
    try std.testing.expectEqual(.need_output, result.status);
    try drainBoundary(&encoder, &wire, &one);
    try std.testing.expectEqualSlices(u8, "\x4a\x4c\x4a\x06\x08", wire.items);
    try finish(&encoder, &wire, &one);
}

test "pending block flush upgrades to partial without duplicate boundaries" {
    var encoder = deflate.RawDeflateIncrementalFixedEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    var scratch: [8]u8 = undefined;
    try feed(&encoder, "abc", &wire, &scratch);
    encoder.blockFlush();
    var one: [1]u8 = undefined;
    const first = try encoder.step("", &one);
    try wire.appendSlice(std.testing.allocator, one[0..first.progress.output_written]);
    try std.testing.expectEqual(.need_output, first.status);
    encoder.partialFlush();
    try drainBoundary(&encoder, &wire, &one);
    try std.testing.expectEqualSlices(u8, "\x4a\x4c\x4a\x06\x08", wire.items);
    try finish(&encoder, &wire, &one);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, wire.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abc", decoded);
}

test "finish honors an undrained partial flush request" {
    const payload = "finish after partial flush keeps its empty fixed boundary\n" ** 9;
    var scratch: [5]u8 = undefined;
    var pending = deflate.RawDeflateIncrementalBestEncoder.init(std.testing.allocator);
    defer pending.deinit();
    var pending_wire: std.ArrayList(u8) = .empty;
    defer pending_wire.deinit(std.testing.allocator);
    try feed(&pending, payload, &pending_wire, &scratch);
    pending.partialFlush();
    pending.finish();
    while (true) {
        const result = try pending.step("", &scratch);
        try pending_wire.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
        try std.testing.expectEqual(.need_output, result.status);
    }

    var acknowledged = deflate.RawDeflateIncrementalBestEncoder.init(std.testing.allocator);
    defer acknowledged.deinit();
    var acknowledged_wire: std.ArrayList(u8) = .empty;
    defer acknowledged_wire.deinit(std.testing.allocator);
    try feed(&acknowledged, payload, &acknowledged_wire, &scratch);
    acknowledged.partialFlush();
    try drainBoundary(&acknowledged, &acknowledged_wire, &scratch);
    try finish(&acknowledged, &acknowledged_wire, &scratch);
    try std.testing.expectEqualSlices(u8, acknowledged_wire.items, pending_wire.items);
}

test "partial flush retains best history while full upgrade resets it" {
    const payload = "partial flush keeps rolling history 0123456789\n" ** 32;
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(
        std.testing.allocator,
        .{ .compression = deflate.optionsForLevel(.default) },
    );
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(std.testing.allocator);
    var scratch: [11]u8 = undefined;
    try feed(&encoder, payload, &wire, &scratch);
    encoder.partialFlush();
    try drainBoundary(&encoder, &wire, &scratch);
    try std.testing.expect(encoder.matchFinderSnapshot().initialized);
    try std.testing.expectEqual(payload.len, encoder.matchFinderSnapshot().absolute_position);
    encoder.fullFlush();
    try drainBoundary(&encoder, &wire, &scratch);
    try std.testing.expect(!encoder.matchFinderSnapshot().initialized);
    try std.testing.expectEqual(@as(usize, 0), encoder.matchFinderSnapshot().absolute_position);
    try finish(&encoder, &wire, &scratch);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, wire.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "zlib and gzip partial flush preserve wrapper checksums" {
    const first = "partial checksum prefix 0123456789\n" ** 13;
    const second = "partial checksum suffix abcdefghijklmnopqrstuvwxyz\n" ** 17;
    const payload = first ++ second;
    var scratch: [7]u8 = undefined;

    var zlib = deflate.ZlibIncrementalBestEncoder.init(std.testing.allocator);
    defer zlib.deinit();
    var zlib_wire: std.ArrayList(u8) = .empty;
    defer zlib_wire.deinit(std.testing.allocator);
    try feed(&zlib, first, &zlib_wire, &scratch);
    zlib.partialFlush();
    try drainBoundary(&zlib, &zlib_wire, &scratch);
    try feed(&zlib, second, &zlib_wire, &scratch);
    try finish(&zlib, &zlib_wire, &scratch);
    try std.testing.expectEqual(
        checksum.Adler32.hash(payload),
        std.mem.readInt(u32, zlib_wire.items[zlib_wire.items.len - 4 ..][0..4], .big),
    );
    const zlib_decoded = try deflate.decodeZlibAlloc(std.testing.allocator, zlib_wire.items);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, payload, zlib_decoded);

    var gzip = deflate.GzipIncrementalBestEncoder.init(std.testing.allocator);
    defer gzip.deinit();
    var gzip_wire: std.ArrayList(u8) = .empty;
    defer gzip_wire.deinit(std.testing.allocator);
    try feed(&gzip, first, &gzip_wire, &scratch);
    gzip.partialFlush();
    try drainBoundary(&gzip, &gzip_wire, &scratch);
    try feed(&gzip, second, &gzip_wire, &scratch);
    try finish(&gzip, &gzip_wire, &scratch);
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
