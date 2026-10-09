const std = @import("std");
const checksum = @import("checksum.zig");
const archive = @import("seven_zip/archive.zig");
const writer = @import("seven_zip/writer.zig");

pub const Error = archive.Error || writer.Error;
pub const Kind = @import("seven_zip/types.zig").Kind;
pub const Entry = archive.Entry;
pub const Archive = archive.Archive;
pub const DecodeOptions = archive.DecodeOptions;
pub const ParseOptions = archive.ParseOptions;
pub const EncodeEntry = writer.EncodeEntry;
pub const Compression = writer.Compression;
pub const Filter = writer.Filter;
pub const EncryptionOptions = writer.EncryptionOptions;
pub const EncodeOptions = writer.EncodeOptions;
pub const parseAlloc = archive.parseAlloc;
pub const parseAllocWithOptions = archive.parseAllocWithOptions;
pub fn extractByNameAlloc(allocator: std.mem.Allocator, input: []const u8, name: []const u8) ![]u8 {
    const parsed = try archive.parseAlloc(allocator, input);
    defer parsed.deinit();
    return parsed.extractByNameAlloc(allocator, name);
}

pub fn extractByNameAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    name: []const u8,
    max_output_len: usize,
) ![]u8 {
    const parsed = try archive.parseAlloc(allocator, input);
    defer parsed.deinit();
    return parsed.extractByNameAllocLimited(allocator, name, max_output_len);
}
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;
pub const encodeStoredAlloc = writer.encodeStoredAlloc;
pub const encodeStoredAppend = writer.encodeStoredAppend;
pub const encodeStoredInto = writer.encodeStoredInto;

test {
    _ = archive;
    _ = @import("seven_zip/aes.zig");
    _ = @import("seven_zip/bcj2.zig");
    _ = @import("seven_zip/number.zig");
    _ = writer;
}

test "7z stored writer round trips files directories and UTF-8 names" {
    const entries = [_]EncodeEntry{
        .{ .name = "hello.txt", .data = "hello seven zip\n" },
        .{ .name = "empty.txt" },
        .{ .name = "folder", .kind = .directory },
        .{ .name = "utf8-数据.txt", .data = "payload" },
    };
    const encoded = try encodeStoredAlloc(std.testing.allocator, &entries, .{});
    defer std.testing.allocator.free(encoded);
    const parsed = try parseAlloc(std.testing.allocator, encoded);
    defer parsed.deinit();
    try std.testing.expectEqual(entries.len, parsed.entries.len);
    for (entries, parsed.entries) |expected, actual| {
        try std.testing.expectEqualStrings(expected.name, actual.name);
        try std.testing.expectEqual(expected.kind, actual.kind);
        if (actual.folder_index) |_| {
            const decoded = try parsed.extractEntryAlloc(std.testing.allocator, actual);
            defer std.testing.allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, expected.data, decoded);
        } else {
            try std.testing.expectEqual(@as(usize, 0), expected.data.len);
        }
    }

    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.extractEntryAllocLimited(std.testing.allocator, parsed.entries[0], entries[0].data.len - 1),
    );
    try std.testing.expectError(
        error.EntryHasNoStream,
        parsed.extractEntryAlloc(std.testing.allocator, parsed.entries[2]),
    );

    var bad_start_crc = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_start_crc);
    bad_start_crc[8] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, parseAlloc(std.testing.allocator, bad_start_crc));

    var bad_header_crc = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_header_crc);
    bad_header_crc[28] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, parseAlloc(std.testing.allocator, bad_header_crc));
}

test "7z writer round trips compression methods" {
    const payload = "Vort common 7z writer payload\n" ** 128;
    const entries = [_]EncodeEntry{.{ .name = "payload.txt", .data = payload }};
    inline for (.{ Compression.copy, Compression.deflate, Compression.bzip2, Compression.lzma, Compression.lzma2, Compression.lzma2_stored }) |compression| {
        const encoded = try encodeAlloc(std.testing.allocator, &entries, .{ .compression = compression });
        defer std.testing.allocator.free(encoded);
        const repeated = try encodeAlloc(std.testing.allocator, &entries, .{ .compression = compression });
        defer std.testing.allocator.free(repeated);
        try std.testing.expectEqualSlices(u8, encoded, repeated);
        const parsed = try parseAlloc(std.testing.allocator, encoded);
        defer parsed.deinit();
        const decoded = try parsed.extractByNameAlloc(std.testing.allocator, entries[0].name);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
        if (compression == .deflate or compression == .bzip2 or
            compression == .lzma or compression == .lzma2)
            try std.testing.expect(encoded.len < payload.len);
    }
}

test "7z solid writer shares one folder across files" {
    const entries = [_]EncodeEntry{
        .{ .name = "first.txt", .data = "first solid payload\n" ** 64 },
        .{ .name = "empty.txt" },
        .{ .name = "folder", .kind = .directory },
        .{ .name = "folder/second.txt", .data = "second solid payload\n" ** 97 },
        .{ .name = "third.bin", .data = "\x90\xe8\x10\x00\x00\x00tail" ** 128 },
    };
    var total_size: usize = 0;
    for (entries) |entry| total_size += entry.data.len;

    inline for (.{
        Compression.copy,
        Compression.deflate,
        Compression.bzip2,
        Compression.lzma,
        Compression.lzma2,
        Compression.lzma2_stored,
    }) |compression| {
        const options = EncodeOptions{ .compression = compression, .solid = true };
        const encoded = try encodeAlloc(std.testing.allocator, &entries, options);
        defer std.testing.allocator.free(encoded);
        const repeated = try encodeAlloc(std.testing.allocator, &entries, options);
        defer std.testing.allocator.free(repeated);
        try std.testing.expectEqualSlices(u8, encoded, repeated);

        const parsed = try parseAlloc(std.testing.allocator, encoded);
        defer parsed.deinit();
        try std.testing.expectEqual(@as(usize, 1), parsed.streams.folders.len);
        try std.testing.expectEqual(@as(usize, 3), parsed.streams.substream_sizes.len);
        try std.testing.expectEqual(@as(usize, 3), parsed.streams.folders[0].substream_count);
        var expected_offset: u64 = 0;
        for (entries, parsed.entries) |expected, actual| {
            if (expected.data.len == 0) {
                try std.testing.expectEqual(@as(?usize, null), actual.folder_index);
                continue;
            }
            try std.testing.expectEqual(@as(?usize, 0), actual.folder_index);
            try std.testing.expectEqual(expected_offset, actual.offset_in_folder);
            expected_offset += expected.data.len;
            const decoded = try parsed.extractEntryAlloc(std.testing.allocator, actual);
            defer std.testing.allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, expected.data, decoded);
        }
        try std.testing.expectEqual(@as(u64, @intCast(total_size)), expected_offset);
        try std.testing.expectError(
            error.OutputLimitExceeded,
            parsed.decodeEntryAllocWithOptions(
                std.testing.allocator,
                parsed.entries[0],
                .{
                    .max_output_len = entries[0].data.len,
                    .max_folder_output_len = total_size - 1,
                },
            ),
        );
    }
}

test "7z solid writer preserves filters across substream boundaries" {
    const entries = [_]EncodeEntry{
        .{ .name = "first.bin", .data = "\x90\xe8\x10\x00\x00\x00" ** 128 },
        .{ .name = "second.bin", .data = "\xe9\xf0\xff\xff\xff\x90" ** 129 },
    };
    const filters = [_]Filter{ Filter.x86(0), try Filter.delta(4) };
    const encoded = try encodeAlloc(std.testing.allocator, &entries, .{
        .compression = .lzma2,
        .solid = true,
        .filters = &filters,
    });
    defer std.testing.allocator.free(encoded);
    const parsed = try parseAlloc(std.testing.allocator, encoded);
    defer parsed.deinit();
    for (entries) |entry| {
        const decoded = try parsed.extractByNameAlloc(std.testing.allocator, entry.name);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, entry.data, decoded);
    }
}

test "7z writer emits encoded Next Headers with every compression method" {
    const entries = [_]EncodeEntry{
        .{ .name = "first.txt", .data = "encoded header payload one\n" ** 32 },
        .{ .name = "empty.txt" },
        .{ .name = "second.txt", .data = "encoded header payload two\n" ** 47 },
    };
    inline for (.{
        Compression.copy,
        Compression.deflate,
        Compression.bzip2,
        Compression.lzma,
        Compression.lzma2,
        Compression.lzma2_stored,
    }) |header_compression| {
        const options = EncodeOptions{
            .compression = .lzma2,
            .solid = true,
            .header_compression = header_compression,
        };
        const encoded = try encodeAlloc(std.testing.allocator, &entries, options);
        defer std.testing.allocator.free(encoded);
        const repeated = try encodeAlloc(std.testing.allocator, &entries, options);
        defer std.testing.allocator.free(repeated);
        try std.testing.expectEqualSlices(u8, encoded, repeated);

        const next_offset = std.mem.readInt(u64, encoded[12..20], .little);
        const next_start = std.math.cast(usize, 32 + next_offset) orelse
            return error.IntegerOverflow;
        try std.testing.expectEqual(@as(u8, 0x17), encoded[next_start]);
        const parsed = try parseAlloc(std.testing.allocator, encoded);
        defer parsed.deinit();
        for (entries) |entry| {
            if (entry.data.len == 0) continue;
            const decoded = try parsed.extractByNameAlloc(std.testing.allocator, entry.name);
            defer std.testing.allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, entry.data, decoded);
        }
        try std.testing.expectError(
            error.OutputLimitExceeded,
            parseAllocWithOptions(std.testing.allocator, encoded, .{
                .max_encoded_header_size = 1,
            }),
        );
    }
}

test "7z writer and reader support external name streams" {
    const entries = [_]EncodeEntry{
        .{ .name = "first.txt", .data = "external metadata payload\n" ** 64 },
        .{ .name = "empty.txt" },
        .{ .name = "目录/数据.txt", .data = "UTF-8 external name\n" ** 31 },
    };
    const options = EncodeOptions{
        .compression = .lzma2,
        .solid = true,
        .header_compression = .lzma2,
        .external_names = .lzma2,
    };
    const encoded = try encodeAlloc(std.testing.allocator, &entries, options);
    defer std.testing.allocator.free(encoded);
    const repeated = try encodeAlloc(std.testing.allocator, &entries, options);
    defer std.testing.allocator.free(repeated);
    try std.testing.expectEqualSlices(u8, encoded, repeated);

    const parsed = try parseAlloc(std.testing.allocator, encoded);
    defer parsed.deinit();
    for (entries, parsed.entries) |expected, actual| {
        try std.testing.expectEqualStrings(expected.name, actual.name);
        if (expected.data.len == 0) continue;
        const decoded = try parsed.extractEntryAlloc(std.testing.allocator, actual);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, expected.data, decoded);
    }
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parseAllocWithOptions(std.testing.allocator, encoded, .{
            .max_external_metadata_size = 1,
        }),
    );

    const empty_entries = [_]EncodeEntry{.{ .name = "external.txt" }};
    const plain = try encodeAlloc(std.testing.allocator, &empty_entries, .{
        .external_names = .copy,
    });
    defer std.testing.allocator.free(plain);

    var corrupt_data = try std.testing.allocator.dupe(u8, plain);
    defer std.testing.allocator.free(corrupt_data);
    corrupt_data[32] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        parseAlloc(std.testing.allocator, corrupt_data),
    );

    var bad_index = try std.testing.allocator.dupe(u8, plain);
    defer std.testing.allocator.free(bad_index);
    const next_offset = std.math.cast(usize, std.mem.readInt(u64, bad_index[12..20], .little)) orelse
        return error.IntegerOverflow;
    const next_size = std.math.cast(usize, std.mem.readInt(u64, bad_index[20..28], .little)) orelse
        return error.IntegerOverflow;
    const next_start = std.math.add(usize, 32, next_offset) catch
        return error.IntegerOverflow;
    const next_end = std.math.add(usize, next_start, next_size) catch
        return error.IntegerOverflow;
    const property_offset = std.mem.lastIndexOf(
        u8,
        bad_index[next_start..next_end],
        &.{ 0x11, 2, 1, 0 },
    ) orelse return error.Invalid7zArchive;
    bad_index[next_start + property_offset + 3] = 1;
    std.mem.writeInt(u32, bad_index[28..32], checksum.crc32Best(bad_index[next_start..next_end]), .little);
    std.mem.writeInt(u32, bad_index[8..12], checksum.crc32Best(bad_index[12..32]), .little);
    try std.testing.expectError(
        error.Invalid7zArchive,
        parseAlloc(std.testing.allocator, bad_index),
    );
}

test "7z writer and reader preserve inline and external file metadata" {
    const filetime_epoch: u64 = 116_444_736_000_000_000;
    const entries = [_]EncodeEntry{
        .{
            .name = "first.txt",
            .data = "metadata payload one\n" ** 32,
            .creation_time = filetime_epoch + 10_000_000,
            .access_time = filetime_epoch + 20_000_000,
            .modification_time = filetime_epoch + 30_000_000,
            .attributes = 0x81a4_0020,
        },
        .{
            .name = "empty.txt",
            .modification_time = filetime_epoch + 40_000_000,
        },
        .{
            .name = "目录",
            .kind = .directory,
            .creation_time = filetime_epoch + 50_000_000,
            .attributes = 0x41ed_0010,
        },
        .{
            .name = "目录/second.txt",
            .data = "metadata payload two\n" ** 47,
            .access_time = filetime_epoch + 60_000_000,
            .modification_time = filetime_epoch + 70_000_000,
            .attributes = 0x81a4_0020,
        },
    };

    const inline_encoded = try encodeAlloc(std.testing.allocator, &entries, .{
        .compression = .lzma2,
        .solid = true,
    });
    defer std.testing.allocator.free(inline_encoded);
    const inline_parsed = try parseAlloc(std.testing.allocator, inline_encoded);
    defer inline_parsed.deinit();
    for (entries, inline_parsed.entries) |expected, actual| {
        try std.testing.expectEqual(expected.creation_time, actual.creation_time);
        try std.testing.expectEqual(expected.access_time, actual.access_time);
        try std.testing.expectEqual(expected.modification_time, actual.modification_time);
        try std.testing.expectEqual(expected.attributes, actual.attributes);
    }

    inline for (.{
        Compression.copy,
        Compression.deflate,
        Compression.bzip2,
        Compression.lzma,
        Compression.lzma2,
        Compression.lzma2_stored,
    }) |metadata_compression| {
        const options = EncodeOptions{
            .compression = .lzma2,
            .solid = true,
            .header_compression = .lzma2,
            .external_names = .lzma2,
            .external_metadata = metadata_compression,
        };
        const encoded = try encodeAlloc(std.testing.allocator, &entries, options);
        defer std.testing.allocator.free(encoded);
        const repeated = try encodeAlloc(std.testing.allocator, &entries, options);
        defer std.testing.allocator.free(repeated);
        try std.testing.expectEqualSlices(u8, encoded, repeated);

        const parsed = try parseAlloc(std.testing.allocator, encoded);
        defer parsed.deinit();
        for (entries, parsed.entries) |expected, actual| {
            try std.testing.expectEqual(expected.creation_time, actual.creation_time);
            try std.testing.expectEqual(expected.access_time, actual.access_time);
            try std.testing.expectEqual(expected.modification_time, actual.modification_time);
            try std.testing.expectEqual(expected.attributes, actual.attributes);
        }
        try std.testing.expectError(
            error.OutputLimitExceeded,
            parseAllocWithOptions(std.testing.allocator, encoded, .{
                .max_streams = 4,
            }),
        );
    }

    const corrupt_entries = [_]EncodeEntry{.{
        .name = "metadata.txt",
        .modification_time = filetime_epoch + 80_000_000,
    }};
    const valid_external = try encodeAlloc(std.testing.allocator, &corrupt_entries, .{
        .external_metadata = .copy,
    });
    defer std.testing.allocator.free(valid_external);
    var corrupt_external = try std.testing.allocator.dupe(u8, valid_external);
    defer std.testing.allocator.free(corrupt_external);
    corrupt_external[32] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        parseAlloc(std.testing.allocator, corrupt_external),
    );
}

test "7z writer and reader round trip encrypted data and headers" {
    const entries = [_]EncodeEntry{
        .{ .name = "first.txt", .data = "encrypted payload one\n" ** 37 },
        .{ .name = "empty.txt" },
        .{ .name = "second.bin", .data = "\x00\xff encrypted payload two\n" ** 41 },
    };
    const encryption = EncryptionOptions{
        .password = "correct horse 密码",
        .iv = [_]u8{0x42} ** 16,
        .salt = [_]u8{0x24} ** 16,
        .salt_len = 8,
        .num_cycles_power = @import("seven_zip/aes.zig").direct_key_power,
    };
    inline for (.{
        Compression.copy,
        Compression.deflate,
        Compression.bzip2,
        Compression.lzma,
        Compression.lzma2,
        Compression.lzma2_stored,
    }) |compression| {
        const options = EncodeOptions{
            .compression = compression,
            .solid = true,
            .header_compression = .copy,
            .encryption = encryption,
            .encrypt_header = true,
        };
        const encoded = try encodeAlloc(std.testing.allocator, &entries, options);
        defer std.testing.allocator.free(encoded);
        const repeated = try encodeAlloc(std.testing.allocator, &entries, options);
        defer std.testing.allocator.free(repeated);
        try std.testing.expectEqualSlices(u8, encoded, repeated);

        const parsed = try parseAllocWithOptions(std.testing.allocator, encoded, .{
            .password = encryption.password,
        });
        defer parsed.deinit();
        for (entries) |entry| {
            if (entry.data.len == 0) continue;
            const actual = parsed.find(entry.name) orelse return error.EntryNotFound;
            const decoded = try parsed.decodeEntryAllocWithOptions(
                std.testing.allocator,
                actual,
                .{ .password = encryption.password },
            );
            defer std.testing.allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, entry.data, decoded);
        }
        try std.testing.expectError(
            error.PasswordRequired,
            parseAlloc(std.testing.allocator, encoded),
        );
        try std.testing.expectError(
            error.ChecksumMismatch,
            parseAllocWithOptions(std.testing.allocator, encoded, .{
                .password = "wrong password",
            }),
        );
    }

    const data_only = try encodeAlloc(std.testing.allocator, &entries, .{
        .compression = .lzma2,
        .solid = false,
        .encryption = encryption,
    });
    defer std.testing.allocator.free(data_only);
    const parsed_without_password = try parseAlloc(std.testing.allocator, data_only);
    defer parsed_without_password.deinit();
    try std.testing.expectError(
        error.PasswordRequired,
        parsed_without_password.decodeEntryAllocWithOptions(
            std.testing.allocator,
            parsed_without_password.entries[0],
            .{},
        ),
    );
    const first_aes = parsed_without_password.streams.folders[0].aes_coder_index.?;
    const second_aes = parsed_without_password.streams.folders[1].aes_coder_index.?;
    const aes_module = @import("seven_zip/aes.zig");
    const first_properties = try aes_module.parseProperties(
        parsed_without_password.streams.folders[0].coders[first_aes].propertyBytes(),
    );
    const second_properties = try aes_module.parseProperties(
        parsed_without_password.streams.folders[1].coders[second_aes].propertyBytes(),
    );
    try std.testing.expect(!std.mem.eql(u8, first_properties.ivBytes(), second_properties.ivBytes()));
}

test "7z reader decodes real data-only and header-encrypted AES archives" {
    const allocator = std.testing.allocator;
    const password = "seven-zip-password";
    const expected = "Vort 7z AES fixture\n";

    const data_hex = std.mem.trim(
        u8,
        @embedFile("seven_zip/testdata/7zip-aes-data.7z.hex"),
        "\r\n \t",
    );
    const data_archive = try allocator.alloc(u8, data_hex.len / 2);
    defer allocator.free(data_archive);
    _ = try std.fmt.hexToBytes(data_archive, data_hex);
    const data_parsed = try parseAlloc(allocator, data_archive);
    defer data_parsed.deinit();
    try std.testing.expectEqualStrings("aes.txt", data_parsed.entries[0].name);
    try std.testing.expectError(
        error.PasswordRequired,
        data_parsed.extractEntryAlloc(allocator, data_parsed.entries[0]),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        data_parsed.decodeEntryAllocWithOptions(allocator, data_parsed.entries[0], .{
            .password = password,
            .max_kdf_cycles_power = 18,
        }),
    );
    const data_decoded = try data_parsed.decodeEntryAllocWithOptions(
        allocator,
        data_parsed.entries[0],
        .{ .password = password },
    );
    defer allocator.free(data_decoded);
    try std.testing.expectEqualSlices(u8, expected, data_decoded);

    var corrupt_data = try allocator.dupe(u8, data_archive);
    defer allocator.free(corrupt_data);
    corrupt_data[32] ^= 1;
    const corrupt_parsed = try parseAlloc(allocator, corrupt_data);
    defer corrupt_parsed.deinit();
    try std.testing.expectError(
        error.ChecksumMismatch,
        corrupt_parsed.decodeEntryAllocWithOptions(allocator, corrupt_parsed.entries[0], .{
            .password = password,
        }),
    );

    const header_hex = std.mem.trim(
        u8,
        @embedFile("seven_zip/testdata/7zip-aes-header.7z.hex"),
        "\r\n \t",
    );
    const header_archive = try allocator.alloc(u8, header_hex.len / 2);
    defer allocator.free(header_archive);
    _ = try std.fmt.hexToBytes(header_archive, header_hex);
    try std.testing.expectError(
        error.PasswordRequired,
        parseAlloc(allocator, header_archive),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parseAllocWithOptions(allocator, header_archive, .{
            .password = password,
            .max_kdf_cycles_power = 18,
        }),
    );
    const header_parsed = try parseAllocWithOptions(allocator, header_archive, .{
        .password = password,
    });
    defer header_parsed.deinit();
    const header_decoded = try header_parsed.decodeEntryAllocWithOptions(
        allocator,
        header_parsed.entries[0],
        .{ .password = password },
    );
    defer allocator.free(header_decoded);
    try std.testing.expectEqualSlices(u8, expected, header_decoded);
}

test "7z reader decodes a real LZMA2 BCJ2 folder" {
    const allocator = std.testing.allocator;
    const encoded_hex = @embedFile("seven_zip/testdata/7zip-bcj2.7z.hex");
    const encoded = try allocator.alloc(u8, encoded_hex.len / 2);
    defer allocator.free(encoded);
    _ = try std.fmt.hexToBytes(encoded, std.mem.trim(u8, encoded_hex, "\r\n \t"));

    const parsed = try parseAlloc(allocator, encoded);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.entries.len);
    try std.testing.expectEqualStrings("code.bin", parsed.entries[0].name);
    try std.testing.expectEqual(@as(u64, 9216), parsed.entries[0].size);
    try std.testing.expect(parsed.streams.folders[0].bcj2_coder_index != null);
    try std.testing.expectEqual(@as(u4, 4), parsed.streams.folders[0].pack_stream_count);
    const decoded = try parsed.extractEntryAlloc(allocator, parsed.entries[0]);
    defer allocator.free(decoded);
    const digest = std.crypto.hash.Md5.hashResult(decoded);
    var expected_digest: [16]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected_digest, "2f299cef81f2f837cbcd62726befc2e2");
    try std.testing.expectEqual(expected_digest, digest);

    try std.testing.expectError(
        error.OutputLimitExceeded,
        parseAllocWithOptions(allocator, encoded, .{ .max_streams = 3 }),
    );

    var corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    const streams = parsed.streams;
    var range_start: usize = 32 + @as(usize, @intCast(streams.pack_position));
    for (streams.pack_sizes[0..3]) |size| range_start += @intCast(size);
    corrupt[range_start] = 1;
    const corrupt_archive = try parseAlloc(allocator, corrupt);
    defer corrupt_archive.deinit();
    try std.testing.expectError(
        error.Invalid7zArchive,
        corrupt_archive.extractEntryAlloc(allocator, corrupt_archive.entries[0]),
    );
}

test "7z BCJ2 writer round trips every primary compression method" {
    const entries = [_]EncodeEntry{
        .{ .name = "code.bin", .data = "\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff\x90" ** 256 },
        .{ .name = "conditional.bin", .data = "\x0f\x85\x08\x00\x00\x00tail" ** 193 },
    };
    inline for (.{
        Compression.copy,
        Compression.deflate,
        Compression.bzip2,
        Compression.lzma,
        Compression.lzma2,
        Compression.lzma2_stored,
    }) |compression| {
        const encoded = try encodeAlloc(std.testing.allocator, &entries, .{
            .compression = compression,
            .solid = true,
            .bcj2 = true,
            .bcj2_start_ip = 0x1000,
        });
        defer std.testing.allocator.free(encoded);
        const repeated = try encodeAlloc(std.testing.allocator, &entries, .{
            .compression = compression,
            .solid = true,
            .bcj2 = true,
            .bcj2_start_ip = 0x1000,
        });
        defer std.testing.allocator.free(repeated);
        try std.testing.expectEqualSlices(u8, encoded, repeated);

        const parsed = try parseAlloc(std.testing.allocator, encoded);
        defer parsed.deinit();
        try std.testing.expectEqual(@as(usize, 1), parsed.streams.folders.len);
        try std.testing.expectEqual(@as(u4, 4), parsed.streams.folders[0].pack_stream_count);
        try std.testing.expect(parsed.streams.folders[0].bcj2_coder_index != null);
        for (entries) |entry| {
            const decoded = try parsed.extractByNameAlloc(std.testing.allocator, entry.name);
            defer std.testing.allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, entry.data, decoded);
        }
    }
}

test "7z writer round trips an LZMA2 Delta and BCJ chain" {
    const branch_bytes = "\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff\x90" ** 256;
    const entries = [_]EncodeEntry{.{ .name = "code.bin", .data = branch_bytes }};
    const filter_chain = [_]Filter{ Filter.x86(0), try Filter.delta(4) };
    const encoded = try encodeAlloc(std.testing.allocator, &entries, .{
        .compression = .lzma2,
        .filters = &filter_chain,
    });
    defer std.testing.allocator.free(encoded);
    const parsed = try parseAlloc(std.testing.allocator, encoded);
    defer parsed.deinit();
    try std.testing.expectEqual(@import("seven_zip/types.zig").Method.lzma2, parsed.entries[0].method.?);
    const decoded = try parsed.extractByNameAlloc(std.testing.allocator, entries[0].name);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, branch_bytes, decoded);
}
