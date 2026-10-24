const std = @import("std");
const archive_mod = @import("archive.zig");
const encrypted_esd = @import("encrypted_esd.zig");
const format = @import("format.zig");
const vail = @import("vail_archive_crypto");

const header_size = format.header_size;
const payload_offset = header_size;
const payload_len = 32;
const lookup_offset = payload_offset + payload_len;
const lookup_len = format.lookup_entry_size;
const xml_offset = lookup_offset + lookup_len;
const integrity_len = 12 + 3 * 20;

const test_key: [vail.esd.key_len]u8 = .{
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
    0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
};

const test_plaintext: [payload_len]u8 = .{
    0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96,
    0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
    0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c,
    0x9e, 0xb7, 0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
};

fn buildFixtureAlloc(allocator: std.mem.Allocator) ![]u8 {
    var wrapped: [256]u8 = @splat(0);
    wrapped[0] = 1;
    var wrapped_base64: [std.base64.standard.Encoder.calcSize(wrapped.len)]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&wrapped_base64, &wrapped);
    var total: usize = 0;
    var xml: []u8 = &.{};
    for (0..4) |_| {
        if (xml.len != 0) allocator.free(xml);
        xml = try buildXmlAlloc(allocator, total, &wrapped_base64);
        total = xml_offset + xml.len + integrity_len;
    }
    errdefer allocator.free(xml);
    const stable = try buildXmlAlloc(allocator, total, &wrapped_base64);
    allocator.free(xml);
    xml = stable;
    if (total != xml_offset + xml.len + integrity_len)
        return error.TestUnexpectedResult;

    const bytes = try allocator.alloc(u8, total);
    errdefer allocator.free(bytes);
    @memset(bytes, 0);
    @memcpy(bytes[0..8], &format.magic);
    std.mem.writeInt(u32, bytes[8..12], header_size, .little);
    std.mem.writeInt(u32, bytes[12..16], format.solid_version, .little);
    std.mem.writeInt(u32, bytes[16..20], 0x0008_0082, .little);
    std.mem.writeInt(u32, bytes[20..24], 32 * 1024, .little);
    @memset(bytes[24..40], 0x5a);
    std.mem.writeInt(u16, bytes[40..42], 1, .little);
    std.mem.writeInt(u16, bytes[42..44], 1, .little);
    writeResourceHeader(bytes, 48, lookup_len, 0x02, lookup_offset, lookup_len);
    writeResourceHeader(bytes, 72, xml.len, 0x02, xml_offset, xml.len);
    const integrity_offset = xml_offset + xml.len;
    writeResourceHeader(
        bytes,
        124,
        integrity_len,
        0,
        integrity_offset,
        integrity_len,
    );

    try vail.esd.encryptRange(
        &test_key,
        &test_plaintext,
        bytes[payload_offset..][0..payload_len],
    );
    var payload_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(&test_plaintext, &payload_hash, .{});
    writeResourceHeader(
        bytes,
        lookup_offset,
        payload_len,
        0,
        payload_offset,
        payload_len,
    );
    std.mem.writeInt(u16, bytes[lookup_offset + 24 ..][0..2], 1, .little);
    std.mem.writeInt(u32, bytes[lookup_offset + 26 ..][0..4], 1, .little);
    @memcpy(bytes[lookup_offset + 30 ..][0..20], &payload_hash);
    @memcpy(bytes[xml_offset..][0..xml.len], xml);
    allocator.free(xml);

    const integrity = bytes[integrity_offset..];
    std.mem.writeInt(u32, integrity[0..4], integrity_len, .little);
    std.mem.writeInt(u32, integrity[4..8], 3, .little);
    std.mem.writeInt(u32, integrity[8..12], 32, .little);
    const lookup_end = lookup_offset + lookup_len;
    for (0..3) |index| {
        const start = header_size + index * 32;
        const end = @min(lookup_end, start + 32);
        std.crypto.hash.Sha1.hash(
            bytes[start..end],
            integrity[12 + index * 20 ..][0..20],
            .{},
        );
    }
    return bytes;
}

fn buildXmlAlloc(
    allocator: std.mem.Allocator,
    total: usize,
    wrapped_base64: []const u8,
) ![]u8 {
    const ascii = try std.fmt.allocPrint(
        allocator,
        "<WIM><TOTALBYTES>{d}</TOTALBYTES><ESD><KEY>{s}</KEY>" ++
            "<ENCRYPTED Count=\"1\"><RANGE Offset=\"208\" Bytes=\"32\">" ++
            "</RANGE></ENCRYPTED></ESD></WIM>",
        .{ total, wrapped_base64 },
    );
    defer allocator.free(ascii);
    const xml = try allocator.alloc(u8, 2 + ascii.len * 2);
    xml[0] = 0xff;
    xml[1] = 0xfe;
    for (ascii, 0..) |char, index| {
        xml[2 + index * 2] = char;
        xml[2 + index * 2 + 1] = 0;
    }
    return xml;
}

fn writeResourceHeader(
    bytes: []u8,
    offset: usize,
    stored_size: usize,
    flags: u8,
    resource_offset: usize,
    decoded_size: usize,
) void {
    const value: u64 = stored_size;
    for (0..7) |index| bytes[offset + index] = @truncate(value >> @intCast(index * 8));
    bytes[offset + 7] = flags;
    std.mem.writeInt(u64, bytes[offset + 8 ..][0..8], resource_offset, .little);
    std.mem.writeInt(u64, bytes[offset + 16 ..][0..8], decoded_size, .little);
}

test "WIM encrypted ESD parses ranges and reconstructs a verified image" {
    const allocator = std.testing.allocator;
    const bytes = try buildFixtureAlloc(allocator);
    defer allocator.free(bytes);
    const archive = try archive_mod.Archive.init(bytes);
    var info = try archive.readEncryptedEsdInfoAlloc(allocator, .{});
    defer info.deinit();
    try std.testing.expectEqual(@as(usize, 256), info.wrapped_key.len);
    try std.testing.expectEqual(@as(usize, 1), info.ranges.len);
    try std.testing.expectEqual(@as(u64, payload_offset), info.ranges[0].offset);
    try std.testing.expectEqual(@as(u64, payload_len), info.ranges[0].length);

    const decrypted = try archive.decryptEncryptedEsdWithAesKeyAllocLimited(
        allocator,
        &test_key,
        bytes.len,
        .{},
    );
    defer allocator.free(decrypted);
    try std.testing.expectEqualSlices(
        u8,
        &test_plaintext,
        decrypted[payload_offset..][0..payload_len],
    );
    const decoded_archive = try archive_mod.Archive.init(decrypted);
    const xml = try decoded_archive.readXmlAllocLimited(allocator, 4096);
    defer allocator.free(xml);
    try std.testing.expectError(
        error.WimNotEncryptedEsd,
        encrypted_esd.parseXmlAlloc(allocator, xml, .{}),
    );
    var payload_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(&test_plaintext, &payload_hash, .{});
    const payload = try decoded_archive.extractBySha1AllocLimited(
        allocator,
        &payload_hash,
        payload_len,
        4,
        1024,
    );
    defer allocator.free(payload);
    try std.testing.expectEqualSlices(u8, &test_plaintext, payload);
    try validateIntegrity(decrypted, decoded_archive.header);
}

fn validateIntegrity(bytes: []const u8, header: format.Header) !void {
    const start: usize = @intCast(header.integrity_table.offset_in_wim);
    const table = bytes[start..];
    try std.testing.expectEqual(@as(u32, @intCast(table.len)), format.readU32(table, 0));
    const count: usize = format.readU32(table, 4);
    const chunk_size: usize = format.readU32(table, 8);
    const lookup_end: usize = @intCast(
        header.lookup_table.offset_in_wim + header.lookup_table.size_in_wim,
    );
    for (0..count) |index| {
        const chunk_start = header_size + index * chunk_size;
        const chunk_end = @min(lookup_end, chunk_start + chunk_size);
        var actual: [20]u8 = undefined;
        std.crypto.hash.Sha1.hash(bytes[chunk_start..chunk_end], &actual, .{});
        try std.testing.expectEqualSlices(
            u8,
            &actual,
            table[12 + index * 20 ..][0..20],
        );
    }
}

test "WIM encrypted ESD enforces limits malformed ranges and OOM cleanup" {
    const allocator = std.testing.allocator;
    const bytes = try buildFixtureAlloc(allocator);
    defer allocator.free(bytes);
    const archive = try archive_mod.Archive.init(bytes);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive.readEncryptedEsdInfoAlloc(allocator, .{ .max_ranges = 0 }),
    );
    const complete = try archive.decryptEncryptedEsdWithAesKeyAllocLimited(
        allocator,
        &test_key,
        bytes.len,
        .{},
    );
    defer allocator.free(complete);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive.decryptEncryptedEsdWithAesKeyAllocLimited(
            allocator,
            &test_key,
            complete.len - 1,
            .{},
        ),
    );
    const FailureTest = struct {
        fn run(failure_allocator: std.mem.Allocator, fixture: []const u8) !void {
            const test_archive = try archive_mod.Archive.init(fixture);
            const output = try test_archive.decryptEncryptedEsdWithAesKeyAllocLimited(
                failure_allocator,
                &test_key,
                fixture.len,
                .{},
            );
            defer failure_allocator.free(output);
        }
    };
    try std.testing.checkAllAllocationFailures(
        allocator,
        FailureTest.run,
        .{bytes},
    );

    const xml = try archive.readXmlAllocLimited(allocator, 4096);
    defer allocator.free(xml);
    const marker = findUtf16(xml, "Bytes=\"32\"") orelse
        return error.TestUnexpectedResult;
    var malformed = try allocator.dupe(u8, xml);
    defer allocator.free(malformed);
    malformed[marker + "Bytes=\"".len * 2] = '3';
    malformed[marker + ("Bytes=\"".len + 1) * 2] = '1';
    try std.testing.expectError(
        error.InvalidEncryptedEsd,
        encrypted_esd.parseXmlAlloc(allocator, malformed, .{}),
    );
}

fn findUtf16(bytes: []const u8, text: []const u8) ?usize {
    var offset: usize = 0;
    while (bytes.len -| offset >= text.len * 2) : (offset += 2) {
        var matches = true;
        for (text, 0..) |char, index| {
            if (bytes[offset + index * 2] != char or bytes[offset + index * 2 + 1] != 0) {
                matches = false;
                break;
            }
        }
        if (matches) return offset;
    }
    return null;
}

fn fixtureAlloc(allocator: std.mem.Allocator, encoded_base64: []const u8) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(
        u8,
        decoder.calcSizeUpperBound(encoded_base64.len),
    );
    errdefer allocator.free(bytes);
    const written = try decoder.decode(bytes, encoded_base64);
    return allocator.realloc(bytes, written);
}

test "WIM encrypted ESD unwraps a CryptoAPI OAEP session key" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/encrypted-esd-small.esd.b64"),
    );
    defer allocator.free(bytes);
    const private_key = try fixtureAlloc(
        allocator,
        @embedFile("testdata/encrypted-esd-test-private.blob.b64"),
    );
    defer allocator.free(private_key);
    const archive = try archive_mod.Archive.init(bytes);
    const decrypted = try archive.decryptEncryptedEsdAllocLimited(
        allocator,
        private_key,
        bytes.len,
        .{},
    );
    defer allocator.free(decrypted);
    try std.testing.expectEqualSlices(
        u8,
        &test_plaintext,
        decrypted[payload_offset..][0..payload_len],
    );
    private_key[8] ^= 1;
    try std.testing.expectError(
        error.InvalidPrivateKeyBlob,
        archive.decryptEncryptedEsdAllocLimited(
            allocator,
            private_key,
            bytes.len,
            .{},
        ),
    );
}

fn utf16AsciiAlloc(allocator: std.mem.Allocator, ascii: []const u8) ![]u8 {
    const output = try allocator.alloc(u8, 2 + ascii.len * 2);
    output[0] = 0xff;
    output[1] = 0xfe;
    for (ascii, 0..) |char, index| {
        output[2 + index * 2] = char;
        output[2 + index * 2 + 1] = 0;
    }
    return output;
}

test "WIM encrypted ESD parses multiple ordered ranges strictly" {
    const allocator = std.testing.allocator;
    const wrapped: [256]u8 = @splat(0x5a);
    var encoded: [std.base64.standard.Encoder.calcSize(wrapped.len)]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&encoded, &wrapped);
    const ascii = try std.fmt.allocPrint(
        allocator,
        "<WIM><ESD><KEY>{s}</KEY><ENCRYPTED Count=\"2\">" ++
            "<RANGE Offset=\"208\" Bytes=\"16\"></RANGE>" ++
            "<RANGE Offset=\"224\" Bytes=\"32\"></RANGE>" ++
            "</ENCRYPTED></ESD></WIM>",
        .{&encoded},
    );
    defer allocator.free(ascii);
    const xml = try utf16AsciiAlloc(allocator, ascii);
    defer allocator.free(xml);
    var info = try encrypted_esd.parseXmlAlloc(allocator, xml, .{});
    defer info.deinit();
    try std.testing.expectEqual(@as(usize, 2), info.ranges.len);
    try std.testing.expectEqual(@as(u64, 224), info.ranges[1].offset);
    try std.testing.expectEqual(@as(u64, 32), info.ranges[1].length);

    const overlap_ascii = try std.mem.replaceOwned(
        u8,
        allocator,
        ascii,
        "Offset=\"224\"",
        "Offset=\"216\"",
    );
    defer allocator.free(overlap_ascii);
    const overlap_xml = try utf16AsciiAlloc(allocator, overlap_ascii);
    defer allocator.free(overlap_xml);
    try std.testing.expectError(
        error.InvalidEncryptedEsd,
        encrypted_esd.parseXmlAlloc(allocator, overlap_xml, .{}),
    );

    const missing_ascii = try std.mem.replaceOwned(
        u8,
        allocator,
        ascii,
        "Count=\"2\"",
        "Count=\"3\"",
    );
    defer allocator.free(missing_ascii);
    const missing_xml = try utf16AsciiAlloc(allocator, missing_ascii);
    defer allocator.free(missing_xml);
    try std.testing.expectError(
        error.InvalidEncryptedEsd,
        encrypted_esd.parseXmlAlloc(allocator, missing_xml, .{}),
    );
}
