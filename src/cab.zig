const std = @import("std");
const archive = @import("cab/archive.zig");
const checksum = @import("cab/checksum.zig");
const decoder = @import("cab/decoder.zig");
const deflate = @import("deflate.zig");
const types = @import("cab/types.zig");

pub const Error = archive.Error || decoder.Error;
pub const Compression = types.Compression;
pub const Entry = types.Entry;
pub const Folder = types.Folder;
pub const DataBlock = types.DataBlock;
pub const Archive = archive.Archive;
pub const Iterator = archive.Iterator;
pub const DataBlockIterator = archive.DataBlockIterator;
pub const ExtractOptions = decoder.ExtractOptions;
pub const parse = archive.parse;
pub const decodeFolderAllocLimited = decoder.decodeFolderAllocLimited;
pub const extractAlloc = decoder.extractAlloc;
pub const extractAllocLimited = decoder.extractAllocLimited;
pub const extractAllocWithOptions = decoder.extractAllocWithOptions;
pub const extractInto = decoder.extractInto;
pub const extractByNameAlloc = decoder.extractByNameAlloc;
pub const extractByNameAllocLimited = decoder.extractByNameAllocLimited;

test {
    _ = archive;
    _ = checksum;
    _ = decoder;
    _ = types;
}

test "CAB extracts Microsoft specification stored fixture" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(allocator, @embedFile("cab/testdata/libmspack-simple.cab.hex"));
    defer allocator.free(bytes);
    const parsed = try parse(bytes);
    try std.testing.expectEqual(@as(usize, 1), parsed.folder_count);
    try std.testing.expectEqual(@as(usize, 2), parsed.file_count);
    try std.testing.expectEqual(Compression.none, (try parsed.folderAt(0)).compression);

    const hello = try extractByNameAlloc(allocator, parsed, "hello.c");
    defer allocator.free(hello);
    try std.testing.expectEqualStrings(
        "#include <stdio.h>\r\n\r\nvoid main(void)\r\n{\r\n    printf(\"Hello, world!\\n\");\r\n}\r\n",
        hello,
    );
    const welcome = try extractByNameAlloc(allocator, parsed, "welcome.c");
    defer allocator.free(welcome);
    try std.testing.expectEqualStrings(
        "#include <stdio.h>\r\n\r\nvoid main(void)\r\n{\r\n    printf(\"Welcome!\\n\");\r\n}\r\n\r\n",
        welcome,
    );
}

test "CAB extracts libmspack MSZIP folder and rejects unsupported folders" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(allocator, @embedFile("cab/testdata/libmspack-mixed.cab.hex"));
    defer allocator.free(bytes);
    const parsed = try parse(bytes);
    try std.testing.expectEqual(@as(usize, 3), parsed.folder_count);
    try std.testing.expectEqual(@as(usize, 3), parsed.file_count);
    try std.testing.expectEqual(Compression.mszip, (try parsed.folderAt(0)).compression);
    try std.testing.expectEqual(Compression.lzx, (try parsed.folderAt(1)).compression);
    try std.testing.expectEqual(Compression.quantum, (try parsed.folderAt(2)).compression);

    const mszip = try extractByNameAlloc(allocator, parsed, "mszip.txt");
    defer allocator.free(mszip);
    try std.testing.expectEqualStrings(
        "If you can read this, the MSZIP decompressor is working!\n",
        mszip,
    );
    const lzx = (try parsed.find("lzx.txt")).?;
    try std.testing.expectError(
        error.UnsupportedCabinetCompression,
        extractAlloc(allocator, parsed, lzx),
    );
    const quantum = (try parsed.find("qtm.txt")).?;
    try std.testing.expectError(
        error.UnsupportedCabinetCompression,
        extractAlloc(allocator, parsed, quantum),
    );
}

test "CAB MSZIP retains history across reserved CFDATA blocks" {
    const allocator = std.testing.allocator;
    const fixture = try buildMultiBlockMszipFixture(allocator);
    defer allocator.free(fixture.bytes);
    defer allocator.free(fixture.expected);

    const parsed = try parse(fixture.bytes);
    try std.testing.expectEqual(@as(usize, 43), parsed.folder_table_offset);
    try std.testing.expectEqual(@as(usize, 2), parsed.folder_reserve_size);
    try std.testing.expectEqual(@as(usize, 3), parsed.data_reserve_size);
    const folder = try parsed.folderAt(0);
    try std.testing.expectEqual(@as(usize, 2), folder.data_block_count);
    try std.testing.expectEqual(fixture.expected.len, folder.decoded_size);

    const cross_entry = (try parsed.find("dir\\cross.bin")).?;
    try std.testing.expect(cross_entry.isUtf8());
    try std.testing.expect(cross_entry.isSafeRelative());
    const cross = try extractAlloc(allocator, parsed, cross_entry);
    defer allocator.free(cross);
    try std.testing.expectEqualSlices(u8, fixture.expected[0..33_000], cross);

    const tail_entry = (try parsed.find("tail.bin")).?;
    const tail = try extractAlloc(allocator, parsed, tail_entry);
    defer allocator.free(tail);
    try std.testing.expectEqualSlices(u8, fixture.expected[33_000..], tail);

    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeFolderAllocLimited(allocator, parsed, 0, fixture.expected.len - 1),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        extractAllocWithOptions(allocator, parsed, cross_entry, .{
            .max_file_size = cross_entry.size - 1,
            .max_folder_size = fixture.expected.len,
        }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        extractAllocWithOptions(allocator, parsed, cross_entry, .{
            .max_file_size = cross_entry.size,
            .max_folder_size = fixture.expected.len - 1,
        }),
    );
    var forged = cross_entry;
    forged.size -= 1;
    try std.testing.expectError(error.InvalidCabinet, extractAlloc(allocator, parsed, forged));

    var blocks = parsed.dataBlockIterator(folder);
    _ = (try blocks.next()).?;
    const second = (try blocks.next()).?;
    var corrupt_checksum = try allocator.dupe(u8, fixture.bytes);
    defer allocator.free(corrupt_checksum);
    corrupt_checksum[second.next_offset - 1] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, parse(corrupt_checksum));

    var corrupt_signature = try allocator.dupe(u8, fixture.bytes);
    defer allocator.free(corrupt_signature);
    std.mem.writeInt(u32, corrupt_signature[second.record_offset..][0..4], 0, .little);
    corrupt_signature[second.record_offset + 8 + parsed.data_reserve_size] = 'X';
    const corrupt_parsed = try parse(corrupt_signature);
    const corrupt_entry = (try corrupt_parsed.find("tail.bin")).?;
    try std.testing.expectError(
        error.InvalidCabinet,
        extractAlloc(allocator, corrupt_parsed, corrupt_entry),
    );
}

test "CAB rejects linked cabinets and unsafe paths" {
    const allocator = std.testing.allocator;
    const fixture = try buildMultiBlockMszipFixture(allocator);
    defer allocator.free(fixture.bytes);
    defer allocator.free(fixture.expected);

    var linked = try allocator.dupe(u8, fixture.bytes);
    defer allocator.free(linked);
    std.mem.writeInt(u16, linked[30..32], 1, .little);
    try std.testing.expectError(error.UnsupportedCabinetFeature, parse(linked));

    const parsed = try parse(fixture.bytes);
    var unsafe = (try parsed.find("tail.bin")).?;
    unsafe.name = "../tail.bin";
    try std.testing.expect(!unsafe.isSafeRelative());
    unsafe.name = "C:\\tail.bin";
    try std.testing.expect(!unsafe.isSafeRelative());
    unsafe.name = "/tail.bin";
    try std.testing.expect(!unsafe.isSafeRelative());
}

test "CAB parser rejects malformed headers tables names and split blocks" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(allocator, @embedFile("cab/testdata/libmspack-simple.cab.hex"));
    defer allocator.free(bytes);
    const valid = try parse(bytes);
    const first_entry = try valid.entryAt(0);
    const folder = try valid.folderAt(0);

    var bad_reserved = try allocator.dupe(u8, bytes);
    defer allocator.free(bad_reserved);
    bad_reserved[4] = 1;
    try std.testing.expectError(error.InvalidCabinet, parse(bad_reserved));

    var bad_size = try allocator.dupe(u8, bytes);
    defer allocator.free(bad_size);
    std.mem.writeInt(u32, bad_size[8..12], @intCast(bytes.len - 1), .little);
    try std.testing.expectError(error.SizeMismatch, parse(bad_size));

    var bad_version = try allocator.dupe(u8, bytes);
    defer allocator.free(bad_version);
    bad_version[24] = 2;
    try std.testing.expectError(error.UnsupportedVersion, parse(bad_version));

    var bad_folder_offset = try allocator.dupe(u8, bytes);
    defer allocator.free(bad_folder_offset);
    std.mem.writeInt(u32, bad_folder_offset[valid.folder_table_offset..][0..4], 0, .little);
    try std.testing.expectError(error.InvalidCabinet, parse(bad_folder_offset));

    var bad_file_range = try allocator.dupe(u8, bytes);
    defer allocator.free(bad_file_range);
    std.mem.writeInt(u32, bad_file_range[first_entry.record_offset..][0..4], std.math.maxInt(u32), .little);
    try std.testing.expectError(error.InvalidCabinet, parse(bad_file_range));

    var continued_file = try allocator.dupe(u8, bytes);
    defer allocator.free(continued_file);
    std.mem.writeInt(u16, continued_file[first_entry.record_offset + 8 ..][0..2], 0xfffe, .little);
    try std.testing.expectError(error.UnsupportedCabinetFeature, parse(continued_file));

    var bad_utf8 = try allocator.dupe(u8, bytes);
    defer allocator.free(bad_utf8);
    bad_utf8[first_entry.record_offset + 16] = 0xff;
    std.mem.writeInt(u16, bad_utf8[first_entry.record_offset + 14 ..][0..2], 0x0080, .little);
    try std.testing.expectError(error.InvalidCabinet, parse(bad_utf8));

    var split_block = try allocator.dupe(u8, bytes);
    defer allocator.free(split_block);
    std.mem.writeInt(u16, split_block[folder.data_offset + 6 ..][0..2], 0, .little);
    try std.testing.expectError(error.UnsupportedCabinetFeature, parse(split_block));
}

const BuiltFixture = struct {
    bytes: []u8,
    expected: []u8,
};

fn buildMultiBlockMszipFixture(allocator: std.mem.Allocator) !BuiltFixture {
    const first_len = 32 * 1024;
    const second_len = 8 * 1024;
    const expected = try allocator.alloc(u8, first_len + second_len);
    errdefer allocator.free(expected);
    var state: u32 = 0xcab0_5eed;
    for (expected[0..first_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(expected[first_len..], expected[first_len - second_len .. first_len]);

    const first_deflate = try deflate.encodeRawStoredAlloc(allocator, expected[0..first_len]);
    defer allocator.free(first_deflate);
    const second_deflate = try deflate.encodeRawFixedWithDictionaryAlloc(
        allocator,
        expected[first_len..],
        expected[0..first_len],
        deflate.optionsForLevel(.default),
    );
    defer allocator.free(second_deflate);
    if (second_deflate.len >= second_len / 4) return error.InvalidBlockPlan;

    var first_payload: std.ArrayList(u8) = .empty;
    defer first_payload.deinit(allocator);
    try first_payload.appendSlice(allocator, "CK");
    try first_payload.appendSlice(allocator, first_deflate);
    var second_payload: std.ArrayList(u8) = .empty;
    defer second_payload.deinit(allocator);
    try second_payload.appendSlice(allocator, "CK");
    try second_payload.appendSlice(allocator, second_deflate);

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendNTimes(allocator, 0, 36);
    try appendU16(allocator, &out, 3); // CFHEADER reserve bytes.
    try out.appendSlice(allocator, &.{ 2, 3 }); // CFFOLDER / CFDATA reserve bytes.
    try out.appendSlice(allocator, &.{ 0xa1, 0xb2, 0xc3 });

    const folder_record_offset = out.items.len;
    try appendU32(allocator, &out, 0); // Patched after file table.
    try appendU16(allocator, &out, 2);
    try appendU16(allocator, &out, 1);
    try out.appendSlice(allocator, &.{ 0xd4, 0xe5 });

    const files_offset = out.items.len;
    try appendTestFile(allocator, &out, 33_000, 0, "dir\\cross.bin");
    try appendTestFile(allocator, &out, expected.len - 33_000, 33_000, "tail.bin");
    const data_offset = out.items.len;
    try appendTestDataBlock(allocator, &out, first_payload.items, first_len, &.{ 1, 2, 3 });
    try appendTestDataBlock(allocator, &out, second_payload.items, second_len, &.{ 4, 5, 6 });

    @memcpy(out.items[0..4], "MSCF");
    std.mem.writeInt(u32, out.items[8..12], @intCast(out.items.len), .little);
    std.mem.writeInt(u32, out.items[16..20], @intCast(files_offset), .little);
    out.items[24] = 3;
    out.items[25] = 1;
    std.mem.writeInt(u16, out.items[26..28], 1, .little);
    std.mem.writeInt(u16, out.items[28..30], 2, .little);
    std.mem.writeInt(u16, out.items[30..32], 4, .little);
    std.mem.writeInt(u16, out.items[32..34], 0x5eed, .little);
    std.mem.writeInt(u32, out.items[folder_record_offset..][0..4], @intCast(data_offset), .little);
    return .{ .bytes = try out.toOwnedSlice(allocator), .expected = expected };
}

fn appendTestFile(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    size: usize,
    offset: usize,
    name: []const u8,
) !void {
    try appendU32(allocator, out, @intCast(size));
    try appendU32(allocator, out, @intCast(offset));
    try appendU16(allocator, out, 0);
    try appendU16(allocator, out, 0x5821);
    try appendU16(allocator, out, 0x6000);
    try appendU16(allocator, out, 0x00a0);
    try out.appendSlice(allocator, name);
    try out.append(allocator, 0);
}

fn appendTestDataBlock(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    payload: []const u8,
    decoded_len: usize,
    reserve: []const u8,
) !void {
    const start = out.items.len;
    try appendU32(allocator, out, 0);
    try appendU16(allocator, out, @intCast(payload.len));
    try appendU16(allocator, out, @intCast(decoded_len));
    try out.appendSlice(allocator, reserve);
    try out.appendSlice(allocator, payload);
    std.mem.writeInt(u32, out.items[start..][0..4], checksum.compute(out.items[start + 4 ..]), .little);
}

fn appendU16(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

fn appendU32(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

fn fixtureAlloc(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    const hex = std.mem.trim(u8, text, " \t\r\n");
    if (hex.len % 2 != 0) return error.InvalidCabinet;
    const bytes = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(bytes);
    _ = std.fmt.hexToBytes(bytes, hex) catch return error.InvalidCabinet;
    return bytes;
}
