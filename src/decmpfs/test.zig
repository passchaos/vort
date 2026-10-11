const std = @import("std");
const decmpfs = @import("../decmpfs.zig");
const deflate = @import("../deflate.zig");
const lzfse = @import("../lzfse.zig");

const allocator = std.testing.allocator;

test "decmpfs decodes inline compression types" {
    const plain = "Apple decmpfs inline payload " ** 24;

    try expectInline(.uncompressed_inline, plain, plain);

    const zlib = try deflate.encodeZlibFixedAlloc(allocator, plain);
    defer allocator.free(zlib);
    try expectInline(.zlib_inline, zlib, plain);
    try expectInline(.zlib_inline, "\xff" ++ plain, plain);

    const lzvn = try lzfse.encodeLzvnAlloc(allocator, plain);
    defer allocator.free(lzvn);
    try expectInline(.lzvn_inline, lzvn, plain);
    try expectInline(.lzvn_inline, "\x06" ++ plain, plain);

    try expectInline(.raw_inline, "\xcc" ++ plain, plain);

    const lzfse_stream = try lzfse.encodeAlloc(allocator, plain, .{});
    defer allocator.free(lzfse_stream);
    try expectInline(.lzfse_inline, lzfse_stream, plain);
}

test "decmpfs decodes zlib resource chunks and cross-block ranges" {
    const plain = try makePlain(allocator, decmpfs.blockSize + 1703);
    defer allocator.free(plain);
    const first = plain[0..decmpfs.blockSize];
    const second = plain[decmpfs.blockSize..];
    const encoded_first_base = try deflate.encodeZlibFixedAlloc(allocator, first);
    defer allocator.free(encoded_first_base);
    const encoded_first = try allocator.alloc(u8, encoded_first_base.len + 1);
    defer allocator.free(encoded_first);
    @memcpy(encoded_first[0..encoded_first_base.len], encoded_first_base);
    encoded_first[encoded_first_base.len] = 0xa5;
    const marked_second = try markedCopy(allocator, 0xff, second);
    defer allocator.free(marked_second);
    const resource = try buildZlibResource(allocator, &.{ encoded_first, marked_second });
    defer allocator.free(resource);

    try expectResource(.zlib_resource, resource, plain);
    try expectResourceRange(.zlib_resource, resource, plain, decmpfs.blockSize - 37, 143);

    var corrupt_map = try allocator.dupe(u8, resource);
    defer allocator.free(corrupt_map);
    corrupt_map[corrupt_map.len - 20] ^= 1;
    const xattr = makeHeader(.zlib_resource, plain.len);
    try std.testing.expectError(error.InvalidDecmpfs, decmpfs.parse(&xattr, corrupt_map));

    const without_adler = encoded_first_base[0 .. encoded_first_base.len - 4];
    const no_adler_resource = try buildZlibResource(allocator, &.{without_adler});
    defer allocator.free(no_adler_resource);
    try expectResource(.zlib_resource, no_adler_resource, first);
}

test "decmpfs decodes LZVN resource chunks and cross-block ranges" {
    const plain = try makePlain(allocator, decmpfs.blockSize + 2039);
    defer allocator.free(plain);
    const first = plain[0..decmpfs.blockSize];
    const second = plain[decmpfs.blockSize..];
    const encoded_first = try lzfse.encodeLzvnAlloc(allocator, first);
    defer allocator.free(encoded_first);
    const marked_second = try markedCopy(allocator, 0x06, second);
    defer allocator.free(marked_second);
    const resource = try buildOffsetResource(allocator, &.{ encoded_first, marked_second });
    defer allocator.free(resource);

    try expectResource(.lzvn_resource, resource, plain);
    try expectResourceRange(.lzvn_resource, resource, plain, decmpfs.blockSize - 23, 131);
}

test "decmpfs decodes LZFSE resource chunks and cross-block ranges" {
    const plain = try makePlain(allocator, decmpfs.blockSize + 3111);
    defer allocator.free(plain);
    const first = plain[0..decmpfs.blockSize];
    const second = plain[decmpfs.blockSize..];
    const encoded_first = try lzfse.encodeAlloc(allocator, first, .{});
    defer allocator.free(encoded_first);
    const encoded_second = try lzfse.encodeAlloc(allocator, second, .{});
    defer allocator.free(encoded_second);
    const resource = try buildOffsetResource(allocator, &.{ encoded_first, encoded_second });
    defer allocator.free(resource);

    try expectResource(.lzfse_resource, resource, plain);
    try expectResourceRange(.lzfse_resource, resource, plain, decmpfs.blockSize - 59, 241);
}

test "decmpfs accepts an empty Apple offset-table resource" {
    const xattr = makeHeader(.lzvn_resource, 0);
    const resource = [_]u8{ 4, 0, 0, 0 };
    const archive = try decmpfs.parse(&xattr, &resource);
    const decoded = try archive.decodeAllocLimited(allocator, 0);
    defer allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), decoded.len);
}

test "decmpfs accepts the legacy 0x100-prefixed LZVN resource layout" {
    const plain = "legacy decmpfs resource layout";
    const chunk = "\x06" ++ plain;
    const resource = try buildLegacyOffsetResource(allocator, &.{chunk});
    defer allocator.free(resource);
    try expectResource(.lzvn_resource, resource, plain);
}

test "decmpfs decodes a pinned ditto type-8 resource fork" {
    const encoded_text = @embedFile("testdata/ditto-type8-200k-a.rsrc.b64");
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const resource = try allocator.alloc(
        u8,
        base64.calcSizeUpperBound(encoded_text.len),
    );
    defer allocator.free(resource);
    const resource_len = try base64.decode(resource, encoded_text);
    const xattr = makeHeader(.lzvn_resource, 200_000);
    const archive = try decmpfs.parse(&xattr, resource[0..resource_len]);
    try std.testing.expectEqual(@as(usize, 4), archive.resource.?.chunk_count);
    const decoded = try archive.decodeAllocLimited(allocator, 200_000);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "A" ** 200_000, decoded);
}

test "decmpfs rejects malformed headers resource tables and limits" {
    try std.testing.expectError(error.TruncatedFrame, decmpfs.parseHeader("short"));

    var bad_magic = makeHeader(.raw_inline, 0);
    bad_magic[0] ^= 1;
    try std.testing.expectError(error.InvalidMagic, decmpfs.parseHeader(&bad_magic));

    var unknown_type = makeHeader(.raw_inline, 0);
    std.mem.writeInt(u32, unknown_type[4..8], 0xffff_ffff, .little);
    try std.testing.expectError(error.UnsupportedDecmpfsType, decmpfs.parseHeader(&unknown_type));

    const resource_header = makeHeader(.zlib_resource, 1);
    try std.testing.expectError(
        error.MissingDecmpfsResourceFork,
        decmpfs.parse(&resource_header, null),
    );

    var resource_header_with_body: [17]u8 = undefined;
    @memcpy(resource_header_with_body[0..16], &resource_header);
    resource_header_with_body[16] = 0;
    try std.testing.expectError(
        error.InvalidDecmpfs,
        decmpfs.parseHeader(&resource_header_with_body),
    );

    const dataless = makeHeader(.dataless, 0);
    const dataless_archive = try decmpfs.parse(&dataless, null);
    try std.testing.expectError(
        error.UnsupportedDecmpfsType,
        dataless_archive.decodeAllocLimited(allocator, 0),
    );

    const raw_resource = makeHeader(.raw_resource, 1);
    try std.testing.expectError(
        error.UnsupportedDecmpfsType,
        decmpfs.parse(&raw_resource, "x"),
    );

    const raw = try makeInline(allocator, .raw_inline, 4, "\xccdata");
    defer allocator.free(raw);
    const raw_archive = try decmpfs.parse(raw, null);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        raw_archive.decodeAllocLimited(allocator, 3),
    );
    try std.testing.expectError(
        error.RangeOutOfBounds,
        raw_archive.decodeRangeAllocLimited(allocator, 3, 2, 2),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        raw_archive.decodeRangeAllocLimited(allocator, 1, 2, 3),
    );
    const raw_range = try raw_archive.decodeRangeAllocLimited(allocator, 1, 2, 4);
    defer allocator.free(raw_range);
    try std.testing.expectEqualStrings("at", raw_range);
    const empty_range = try raw_archive.decodeRangeAllocLimited(allocator, 4, 0, 0);
    defer allocator.free(empty_range);
    try std.testing.expectEqual(@as(usize, 0), empty_range.len);

    var bad_offsets = [_]u8{ 8, 0, 0, 0, 8, 0, 0, 0 };
    const lzvn_resource = makeHeader(.lzvn_resource, 1);
    try std.testing.expectError(
        error.InvalidDecmpfs,
        decmpfs.parse(&lzvn_resource, &bad_offsets),
    );
    bad_offsets[4] = 9;
    try std.testing.expectError(
        error.InvalidDecmpfs,
        decmpfs.parse(&lzvn_resource, &bad_offsets),
    );
}

test "decmpfs reports corrupt inline codec streams" {
    const cases = .{
        .{ decmpfs.CompressionType.zlib_inline, error.BadZlibHeader },
        .{ decmpfs.CompressionType.lzvn_inline, error.InvalidLzvnStream },
        .{ decmpfs.CompressionType.lzfse_inline, error.InvalidMagic },
    };
    inline for (cases) |case| {
        const compression_type = case[0];
        const xattr = try makeInline(allocator, compression_type, 64, "not a codec stream");
        defer allocator.free(xattr);
        const archive = try decmpfs.parse(xattr, null);
        try std.testing.expectError(
            case[1],
            archive.decodeAllocLimited(allocator, 64),
        );
    }
}

fn expectInline(
    compression_type: decmpfs.CompressionType,
    encoded: []const u8,
    expected: []const u8,
) !void {
    const xattr = try makeInline(allocator, compression_type, expected.len, encoded);
    defer allocator.free(xattr);
    const archive = try decmpfs.parse(xattr, null);
    const decoded = try archive.decodeAllocLimited(allocator, expected.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

fn expectResource(
    compression_type: decmpfs.CompressionType,
    resource: []const u8,
    expected: []const u8,
) !void {
    const xattr = makeHeader(compression_type, expected.len);
    const archive = try decmpfs.parse(&xattr, resource);
    const decoded = try archive.decodeAllocLimited(allocator, expected.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

fn expectResourceRange(
    compression_type: decmpfs.CompressionType,
    resource: []const u8,
    expected: []const u8,
    offset: usize,
    length: usize,
) !void {
    const xattr = makeHeader(compression_type, expected.len);
    const archive = try decmpfs.parse(&xattr, resource);
    const decoded = try archive.decodeRangeAllocLimited(
        allocator,
        offset,
        length,
        length,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected[offset..][0..length], decoded);
}

fn makeHeader(compression_type: decmpfs.CompressionType, size: u64) [16]u8 {
    var header: [16]u8 = undefined;
    std.mem.writeInt(u32, header[0..4], decmpfs.magic, .little);
    std.mem.writeInt(u32, header[4..8], @intFromEnum(compression_type), .little);
    std.mem.writeInt(u64, header[8..16], size, .little);
    return header;
}

fn makeInline(
    alloc: std.mem.Allocator,
    compression_type: decmpfs.CompressionType,
    size: u64,
    payload: []const u8,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(alloc);
    try output.appendSlice(alloc, &makeHeader(compression_type, size));
    try output.appendSlice(alloc, payload);
    return output.toOwnedSlice(alloc);
}

fn markedCopy(alloc: std.mem.Allocator, marker: u8, bytes: []const u8) ![]u8 {
    const output = try alloc.alloc(u8, bytes.len + 1);
    output[0] = marker;
    @memcpy(output[1..], bytes);
    return output;
}

fn buildZlibResource(alloc: std.mem.Allocator, chunks: []const []const u8) ![]u8 {
    const data_offset: usize = 0x100;
    const map_size: usize = 50;
    const table_size = chunks.len * 8;
    var payload_size: usize = 4 + table_size;
    for (chunks) |chunk| payload_size += chunk.len;
    const data_size = 4 + payload_size;
    const map_offset = data_offset + data_size;
    const output = try alloc.alloc(u8, map_offset + map_size);
    @memset(output, 0);
    std.mem.writeInt(u32, output[0..4], @intCast(data_offset), .big);
    std.mem.writeInt(u32, output[4..8], @intCast(map_offset), .big);
    std.mem.writeInt(u32, output[8..12], @intCast(data_size), .big);
    std.mem.writeInt(u32, output[12..16], @intCast(map_size), .big);
    std.mem.writeInt(u32, output[data_offset..][0..4], @intCast(payload_size), .big);
    std.mem.writeInt(u32, output[data_offset + 4 ..][0..4], @intCast(chunks.len), .little);
    var relative = 4 + table_size;
    var data_position = data_offset + 4 + relative;
    for (chunks, 0..) |chunk, index| {
        const descriptor = data_offset + 8 + index * 8;
        std.mem.writeInt(u32, output[descriptor..][0..4], @intCast(relative), .little);
        std.mem.writeInt(u32, output[descriptor + 4 ..][0..4], @intCast(chunk.len), .little);
        @memcpy(output[data_position..][0..chunk.len], chunk);
        relative += chunk.len;
        data_position += chunk.len;
    }
    const resource_map = output[map_offset..];
    std.mem.writeInt(u16, resource_map[24..26], 28, .big);
    std.mem.writeInt(u16, resource_map[26..28], 50, .big);
    std.mem.writeInt(u16, resource_map[28..30], 0, .big);
    std.mem.writeInt(u32, resource_map[30..34], 0x636d_7066, .big);
    std.mem.writeInt(u16, resource_map[34..36], 0, .big);
    std.mem.writeInt(u16, resource_map[36..38], 10, .big);
    std.mem.writeInt(u16, resource_map[38..40], 1, .big);
    std.mem.writeInt(u16, resource_map[40..42], 0xffff, .big);
    std.mem.writeInt(u32, resource_map[42..46], 0, .big);
    return output;
}

fn buildOffsetResource(alloc: std.mem.Allocator, chunks: []const []const u8) ![]u8 {
    const table_size = (chunks.len + 1) * 4;
    var total_size = table_size;
    for (chunks) |chunk| total_size += chunk.len;
    const output = try alloc.alloc(u8, total_size);
    var position = table_size;
    for (chunks, 0..) |chunk, index| {
        std.mem.writeInt(u32, output[index * 4 ..][0..4], @intCast(position), .little);
        @memcpy(output[position..][0..chunk.len], chunk);
        position += chunk.len;
    }
    std.mem.writeInt(u32, output[chunks.len * 4 ..][0..4], @intCast(position), .little);
    return output;
}

fn buildLegacyOffsetResource(alloc: std.mem.Allocator, chunks: []const []const u8) ![]u8 {
    const data_offset: usize = 0x100;
    const table_size = (chunks.len + 1) * 4;
    var data_size = 4 + table_size;
    for (chunks) |chunk| data_size += chunk.len;
    const output = try alloc.alloc(u8, data_offset + data_size);
    @memset(output, 0);
    std.mem.writeInt(u32, output[0..4], @intCast(data_offset), .big);
    std.mem.writeInt(u32, output[4..8], @intCast(output.len), .big);
    std.mem.writeInt(u32, output[8..12], @intCast(data_size), .big);
    std.mem.writeInt(u32, output[12..16], 0, .big);
    std.mem.writeInt(u32, output[data_offset..][0..4], @intCast(chunks.len), .little);
    var position = 4 + table_size;
    for (chunks, 0..) |chunk, index| {
        std.mem.writeInt(
            u32,
            output[data_offset + 4 + index * 4 ..][0..4],
            @intCast(position),
            .little,
        );
        @memcpy(output[data_offset + position ..][0..chunk.len], chunk);
        position += chunk.len;
    }
    std.mem.writeInt(
        u32,
        output[data_offset + 4 + chunks.len * 4 ..][0..4],
        @intCast(position),
        .little,
    );
    return output;
}

fn makePlain(alloc: std.mem.Allocator, size: usize) ![]u8 {
    const output = try alloc.alloc(u8, size);
    for (output, 0..) |*byte, index|
        byte.* = "decmpfs-resource-pattern-0123456789\n"[index % 36];
    return output;
}
