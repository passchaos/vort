const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const ewf = @import("../ewf.zig");

const allocator = std.testing.allocator;

test "EWF decodes pinned libewf EnCase 6 mixed chunks" {
    const image = try decodeFixture(
        "testdata/libewf-encase6-mixed.E01.bz2.b64",
        20_000,
    );
    defer allocator.free(image);
    var archive = try ewf.parseOneAlloc(allocator, image, .{});
    defer archive.deinit();
    try std.testing.expectEqual(@as(usize, 4), archive.chunks.len);
    try std.testing.expect(archive.chunks[0].compressed);
    try std.testing.expect(!archive.chunks[1].compressed);
    try std.testing.expect(archive.chunks[2].compressed);
    try std.testing.expect(archive.chunks[3].compressed);
    const decoded = try archive.decodeAllocLimited(allocator, 32768);
    defer allocator.free(decoded);
    const expected = try makePinnedInput(allocator);
    defer allocator.free(expected);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "EWF decodes pinned explicit four-segment libewf set" {
    const paths = [_][]const u8{
        "testdata/libewf-multi-raw.E01.bz2.b64",
        "testdata/libewf-multi-raw.E02.bz2.b64",
        "testdata/libewf-multi-raw.E03.bz2.b64",
        "testdata/libewf-multi-raw.E04.bz2.b64",
    };
    var segments: [paths.len][]u8 = undefined;
    var initialized: usize = 0;
    defer for (segments[0..initialized]) |segment| allocator.free(segment);
    inline for (paths, 0..) |path, index| {
        segments[index] = try decodeFixture(path, 2 * 1024 * 1024);
        initialized += 1;
    }
    var archive = try ewf.parseSegmentsAlloc(allocator, &segments, .{});
    defer archive.deinit();
    try std.testing.expectEqual(@as(usize, 4), archive.segment_count);
    try std.testing.expectEqual(@as(usize, 96), archive.chunks.len);
    const decoded = try archive.decodeAllocLimited(allocator, 3 * 1024 * 1024);
    defer allocator.free(decoded);
    for (0..96) |chunk_index| {
        const expected: u8 = @truncate(chunk_index * 17 + 3);
        for (decoded[chunk_index * 32768 ..][0..32768]) |byte|
            try std.testing.expectEqual(expected, byte);
    }
}

test "EWF writer and reader round trip raw zlib and automatic chunks" {
    const input = try makeInput(allocator, 3 * 32768 + 137);
    defer allocator.free(input);
    inline for (.{ ewf.Compression.none, ewf.Compression.zlib, ewf.Compression.auto }) |compression| {
        const encoded = try ewf.encodeAlloc(allocator, input, .{
            .compression = compression,
            .sectors_per_chunk = 64,
        });
        defer allocator.free(encoded);
        var archive = try ewf.parseOneAlloc(allocator, encoded, .{});
        defer archive.deinit();
        const media_size = std.mem.alignForward(usize, input.len, 512);
        try std.testing.expectEqual(@as(u64, media_size), archive.geometry.media_size);
        try std.testing.expectEqual(@as(usize, 32768), archive.geometry.chunk_size);
        try std.testing.expectEqual(
            std.math.divCeil(usize, media_size, 32768) catch unreachable,
            archive.chunks.len,
        );
        const decoded = try archive.decodeAllocLimited(allocator, media_size);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded[0..input.len]);
        for (decoded[input.len..]) |byte|
            try std.testing.expectEqual(@as(u8, 0), byte);

        const range_offset = 32768 - 29;
        const range_len = 32768 + 73;
        const range = try archive.readRangeAllocLimited(
            allocator,
            range_offset,
            range_len,
            range_len,
        );
        defer allocator.free(range);
        try std.testing.expectEqualSlices(
            u8,
            decoded[range_offset..][0..range_len],
            range,
        );
    }
}

test "EWF writer emits bounded deterministic multi-segment images" {
    const input = try allocator.alloc(u8, 6 * 32768 + 137);
    defer allocator.free(input);
    var random = std.Random.DefaultPrng.init(0x4557_465f_5345_474d);
    random.fill(input);
    const max_segment_size = 72 * 1024;
    inline for (.{ ewf.Compression.none, ewf.Compression.zlib, ewf.Compression.auto }) |compression| {
        var encoded = try ewf.encodeSegmentsAlloc(
            allocator,
            input,
            .{ .compression = compression, .sectors_per_chunk = 64 },
            max_segment_size,
        );
        defer encoded.deinit();
        try std.testing.expect(encoded.segments.len > 1);
        for (encoded.segments, 1..) |segment, number| {
            try std.testing.expect(segment.len <= max_segment_size);
            try std.testing.expectEqual(
                std.math.cast(u16, number).?,
                (try ewf.parseFileHeader(segment)).segment_number,
            );
        }
        var archive = try ewf.parseSegmentsAlloc(
            allocator,
            encoded.segments,
            .{},
        );
        defer archive.deinit();
        try std.testing.expectEqual(encoded.segments.len, archive.segment_count);
        const decoded = try archive.decodeAllocLimited(
            allocator,
            std.mem.alignForward(usize, input.len, 512),
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded[0..input.len]);
        for (decoded[input.len..]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);

        var second = try ewf.encodeSegmentsAlloc(
            allocator,
            input,
            .{ .compression = compression, .sectors_per_chunk = 64 },
            max_segment_size,
        );
        defer second.deinit();
        try std.testing.expectEqual(encoded.segments.len, second.segments.len);
        for (encoded.segments, second.segments) |first, repeated|
            try std.testing.expectEqualSlices(u8, first, repeated);
    }
}

test "EWF segmented writer preserves single-segment wire and enforces limits" {
    const input = try makeInput(allocator, 2 * 32768 + 91);
    defer allocator.free(input);
    const one = try ewf.encodeAlloc(allocator, input, .{ .compression = .auto });
    defer allocator.free(one);
    var segmented = try ewf.encodeSegmentsAlloc(
        allocator,
        input,
        .{ .compression = .auto },
        std.math.maxInt(usize),
    );
    defer segmented.deinit();
    try std.testing.expectEqual(@as(usize, 1), segmented.segments.len);
    try std.testing.expectEqualSlices(u8, one, segmented.segments[0]);

    try std.testing.expectError(
        error.InvalidEwfSegmentSize,
        ewf.encodeSegmentsAlloc(
            allocator,
            input,
            .{ .compression = .none },
            2048,
        ),
    );
    try std.testing.expectError(
        error.InvalidEwfSegmentSize,
        ewf.encodeSegmentsAlloc(allocator, "", .{}, 2048),
    );
}

test "EWF segmented writer releases every allocation failure" {
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator) !void {
            const input = [_]u8{'E'} ** (3 * 32768);
            var encoded = try ewf.encodeSegmentsAlloc(
                failing_allocator,
                &input,
                .{ .compression = .none },
                40 * 1024,
            );
            defer encoded.deinit();
            var archive = try ewf.parseSegmentsAlloc(
                failing_allocator,
                encoded.segments,
                .{},
            );
            defer archive.deinit();
            const decoded = try archive.decodeAllocLimited(
                failing_allocator,
                input.len,
            );
            defer failing_allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, &input, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}

test "EWF verifies section table raw chunk and media MD5 checksums" {
    const input = [_]u8{'R'} ** 32768;
    const encoded = try ewf.encodeAlloc(allocator, &input, .{
        .compression = .none,
    });
    defer allocator.free(encoded);

    var patched = try allocator.dupe(u8, encoded);
    defer allocator.free(patched);
    patched[13 + 72] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        ewf.parseOneAlloc(allocator, patched, .{}),
    );

    @memcpy(patched, encoded);
    var archive = try ewf.parseOneAlloc(allocator, patched, .{});
    const chunk_offset = @intFromPtr(archive.chunks[0].encoded.ptr) -
        @intFromPtr(patched.ptr);
    archive.deinit();
    patched[chunk_offset] ^= 1;
    archive = try ewf.parseOneAlloc(allocator, patched, .{});
    defer archive.deinit();
    try std.testing.expectError(
        error.ChecksumMismatch,
        archive.decodeAllocLimited(allocator, input.len),
    );
}

test "EWF parser rejects malformed headers terminal sections and limits" {
    try std.testing.expectError(error.TruncatedFrame, ewf.parseFileHeader("EVF"));
    var header = [_]u8{0} ** 13;
    @memcpy(header[0..8], ewf.signature);
    header[8] = 1;
    try std.testing.expectError(error.InvalidEwf, ewf.parseFileHeader(&header));

    const input = [_]u8{'E'} ** 32768;
    const encoded = try ewf.encodeAlloc(allocator, &input, .{});
    defer allocator.free(encoded);
    var patched = try allocator.dupe(u8, encoded);
    defer allocator.free(patched);
    std.mem.writeInt(u64, patched[13 + 16 ..][0..8], 12, .little);
    var descriptor = patched[13..][0..76];
    std.mem.writeInt(
        u32,
        descriptor[72..76],
        @import("../checksum.zig").adler32(descriptor[0..72]),
        .little,
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        ewf.parseOneAlloc(allocator, patched, .{}),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        ewf.parseOneAlloc(allocator, encoded, .{ .max_chunks = 0 }),
    );
}

test "EWF writer supports empty media and multiple table groups" {
    const empty = try ewf.encodeAlloc(allocator, "", .{});
    defer allocator.free(empty);
    var empty_archive = try ewf.parseOneAlloc(allocator, empty, .{});
    defer empty_archive.deinit();
    try std.testing.expectEqual(@as(u64, 0), empty_archive.geometry.media_size);
    try std.testing.expectEqual(@as(usize, 0), empty_archive.chunks.len);
    const empty_decoded = try empty_archive.decodeAllocLimited(allocator, 0);
    defer allocator.free(empty_decoded);
    try std.testing.expectEqual(@as(usize, 0), empty_decoded.len);

    const input = try makeInput(allocator, 4 * 32768);
    defer allocator.free(input);
    const encoded = try ewf.encodeAlloc(allocator, input, .{
        .compression = .auto,
        .max_table_entries = 2,
    });
    defer allocator.free(encoded);
    var archive = try ewf.parseOneAlloc(allocator, encoded, .{});
    defer archive.deinit();
    const decoded = try archive.decodeAllocLimited(allocator, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

fn makeInput(alloc: std.mem.Allocator, size: usize) ![]u8 {
    const output = try alloc.alloc(u8, size);
    for (output[0..32768], 0..) |*byte, index|
        byte.* = "EWF-compressed-chunk\n"[index % 21];
    var state: u32 = 0x4557_4631;
    for (output[32768..65536]) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    @memset(output[65536..], 0);
    return output;
}

fn decodeFixture(comptime path: []const u8, max_output: usize) ![]u8 {
    const text = @embedFile(path);
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const encoded = try allocator.alloc(u8, base64.calcSizeUpperBound(text.len));
    defer allocator.free(encoded);
    const encoded_len = try base64.decode(encoded, text);
    return bzip2.decodeAllocLimited(
        allocator,
        encoded[0..encoded_len],
        max_output,
    );
}

fn makePinnedInput(alloc: std.mem.Allocator) ![]u8 {
    const output = try alloc.alloc(u8, 32768);
    const first = ("EWF pinned libewf payload\\n" ** 512)[0..8192];
    @memcpy(output[0..8192], first);
    var state: u32 = 0x4557_4631;
    for (output[8192..16384]) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    @memset(output[16384..24576], 0);
    const tail = ("libewf tail\\n" ** 1024)[0..8192];
    @memcpy(output[24576..32768], tail);
    return output;
}
