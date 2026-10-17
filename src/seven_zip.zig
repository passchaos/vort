const std = @import("std");
const checksum = @import("checksum.zig");
const core = @import("core.zig");
const archive = @import("seven_zip/archive.zig");
const source_archive = @import("seven_zip/source_archive.zig");
const source_entry_decoder = @import("seven_zip/source_entry_decoder.zig");
const split_source = @import("seven_zip/split_source.zig");
const writer = @import("seven_zip/writer.zig");
const incremental_writer = @import("seven_zip/incremental_writer.zig");

pub const Error = archive.Error || source_archive.Error || writer.Error;
pub const Kind = @import("seven_zip/types.zig").Kind;
pub const Entry = archive.Entry;
pub const Archive = archive.Archive;
pub const Source = source_archive.Source;
pub const SourceArchive = source_archive.Archive;
pub const SourceEntryDecoder = source_entry_decoder.Decoder;
pub const SplitSourceOptions = split_source.Options;
pub const SplitPartSource = split_source.PartSource;
pub const SplitSliceSource = split_source.SliceStream;
pub const SplitCallbackSource = split_source.SourceStream;
pub const DecodeOptions = archive.DecodeOptions;
pub const ParseOptions = archive.ParseOptions;
pub const EncodeEntry = writer.EncodeEntry;
pub const Compression = writer.Compression;
pub const Filter = writer.Filter;
pub const EncryptionOptions = writer.EncryptionOptions;
pub const EncodeOptions = writer.EncodeOptions;
pub const IncrementalWriter = incremental_writer.Writer;
pub const IncrementalWriterOptions = incremental_writer.Options;
pub const IncrementalEntryOptions = incremental_writer.EntryOptions;
pub const IncrementalWriterPhase = incremental_writer.Phase;
pub const IncrementalWriterSnapshot = incremental_writer.Snapshot;
pub const IncrementalWriterError = incremental_writer.Error;
pub const parseAlloc = archive.parseAlloc;
pub const parseAllocWithOptions = archive.parseAllocWithOptions;
pub const parseSourceAlloc = source_archive.parseAlloc;
pub const parseSourceAllocWithOptions = source_archive.parseAllocWithOptions;
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
    _ = @import("seven_zip/ppmd7.zig");
    _ = source_archive;
    _ = source_entry_decoder;
    _ = split_source;
    _ = writer;
    _ = incremental_writer;
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
    inline for (.{ Compression.copy, Compression.deflate, Compression.bzip2, Compression.lzma, Compression.lzma2, Compression.lzma2_stored, Compression.ppmd7 }) |compression| {
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
            compression == .lzma or compression == .lzma2 or compression == .ppmd7)
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
        Compression.ppmd7,
        Compression.ppmd7,
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
        Compression.ppmd7,
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
        Compression.ppmd7,
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
        Compression.ppmd7,
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

test "7z reader decodes a real PPMd7 folder with bounded model memory" {
    const allocator = std.testing.allocator;
    const encoded_hex = std.mem.trim(
        u8,
        @embedFile("seven_zip/testdata/7zip-ppmd7.7z.hex"),
        "\r\n \t",
    );
    const encoded = try allocator.alloc(u8, encoded_hex.len / 2);
    defer allocator.free(encoded);
    _ = try std.fmt.hexToBytes(encoded, encoded_hex);

    const parsed = try parseAlloc(allocator, encoded);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.entries.len);
    try std.testing.expectEqualStrings(".gitattributes", parsed.entries[0].name);
    try std.testing.expectEqual(@import("seven_zip/types.zig").Method.ppmd7, parsed.entries[0].method.?);
    const decoded = try parsed.extractEntryAlloc(allocator, parsed.entries[0]);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "src/br/dictionary.bin binary\n", decoded);

    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.decodeEntryAllocWithOptions(allocator, parsed.entries[0], .{
            .max_dictionary_size = 64 * 1024 - 1,
        }),
    );
    var corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    corrupt[32] ^= 1;
    const corrupt_archive = try parseAlloc(allocator, corrupt);
    defer corrupt_archive.deinit();
    try std.testing.expectError(
        error.InvalidPpmdData,
        corrupt_archive.extractEntryAlloc(allocator, corrupt_archive.entries[0]),
    );
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

test "7z source entry decoder streams a real converted BCJ2 folder" {
    const encoded_hex = @embedFile("seven_zip/testdata/7zip-bcj2.7z.hex");
    const encoded = try std.testing.allocator.alloc(u8, encoded_hex.len / 2);
    defer std.testing.allocator.free(encoded);
    _ = try std.fmt.hexToBytes(encoded, std.mem.trim(u8, encoded_hex, "\r\n \t"));
    var context = SourceTestContext{ .bytes = encoded, .max_chunk = 3 };
    const parsed = try parseSourceAlloc(std.testing.allocator, context.source());
    defer parsed.deinit();
    const decoded = try decodeSourceEntryFragmented(
        std.testing.allocator,
        &parsed,
        parsed.entries[0],
        .{
            .max_output_len = 9216,
            .max_folder_output_len = 9216,
            .input_buffer_size = 17,
            .decoded_buffer_size = 7,
        },
        5,
    );
    defer std.testing.allocator.free(decoded);
    const digest = std.crypto.hash.Md5.hashResult(decoded);
    var expected_digest: [16]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected_digest, "2f299cef81f2f837cbcd62726befc2e2");
    try std.testing.expectEqual(expected_digest, digest);
}

test "7z reader decodes a real four-branch AES BCJ2 folder" {
    const allocator = std.testing.allocator;
    const password = "seven-zip-password";
    const encoded_hex = std.mem.trim(
        u8,
        @embedFile("seven_zip/testdata/7zip-bcj2-aes.7z.hex"),
        "\r\n \t",
    );
    const encoded = try allocator.alloc(u8, encoded_hex.len / 2);
    defer allocator.free(encoded);
    _ = try std.fmt.hexToBytes(encoded, encoded_hex);

    const parsed = try parseAlloc(allocator, encoded);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.entries.len);
    try std.testing.expectEqualStrings("src/seven_zip/bcj2.zig", parsed.entries[0].name);
    const folder = parsed.streams.folders[0];
    try std.testing.expectEqual(@as(u3, 6), folder.coder_count);
    try std.testing.expectEqual(@as(u4, 4), folder.pack_stream_count);
    for (folder.bcj2_branches) |branch|
        try std.testing.expect(branch.aes_coder_index != null);

    try std.testing.expectError(
        error.PasswordRequired,
        parsed.extractEntryAlloc(allocator, parsed.entries[0]),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.decodeEntryAllocWithOptions(allocator, parsed.entries[0], .{
            .password = password,
            .max_kdf_cycles_power = 18,
        }),
    );
    const decoded = try parsed.decodeEntryAllocWithOptions(
        allocator,
        parsed.entries[0],
        .{ .password = password },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 7466), decoded.len);
    const digest = std.crypto.hash.Md5.hashResult(decoded);
    var expected_digest: [16]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected_digest, "54c1078f4d7495a609959a855a2945ac");
    try std.testing.expectEqual(expected_digest, digest);
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
        Compression.ppmd7,
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

test "7z BCJ2 writer round trips four independently encrypted packed branches" {
    const payload = "\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff\x90" ** 256;
    const entries = [_]EncodeEntry{.{ .name = "encrypted-code.bin", .data = payload }};
    const encryption = EncryptionOptions{
        .password = "bcj2-password-密码",
        .iv = [_]u8{0x42} ** 16,
        .salt = [_]u8{0x24} ** 16,
        .salt_len = 8,
        .num_cycles_power = @import("seven_zip/aes.zig").direct_key_power,
    };
    const encoded = try encodeAlloc(std.testing.allocator, &entries, .{
        .compression = .lzma2,
        .encryption = encryption,
        .bcj2 = true,
    });
    defer std.testing.allocator.free(encoded);

    const parsed = try parseAlloc(std.testing.allocator, encoded);
    defer parsed.deinit();
    const folder = parsed.streams.folders[0];
    try std.testing.expectEqual(@as(u3, 6), folder.coder_count);
    try std.testing.expectEqual(@as(u4, 4), folder.pack_stream_count);
    for (folder.bcj2_branches, 0..) |branch, branch_index| {
        try std.testing.expect(branch.aes_coder_index != null);
        const aes_index = branch.aes_coder_index.?;
        const properties = try @import("seven_zip/aes.zig").parseProperties(
            folder.coders[aes_index].propertyBytes(),
        );
        for (folder.bcj2_branches[0..branch_index]) |previous_branch| {
            const previous_index = previous_branch.aes_coder_index.?;
            const previous = try @import("seven_zip/aes.zig").parseProperties(
                folder.coders[previous_index].propertyBytes(),
            );
            try std.testing.expect(!std.mem.eql(u8, properties.ivBytes(), previous.ivBytes()));
        }
    }
    try std.testing.expectError(
        error.PasswordRequired,
        parsed.extractByNameAlloc(std.testing.allocator, entries[0].name),
    );
    const decoded = try parsed.decodeEntryAllocWithOptions(
        std.testing.allocator,
        parsed.entries[0],
        .{ .password = encryption.password },
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "7z encrypted BCJ2 releases every allocation failure" {
    const payload = "\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff\x90" ** 8;
    const entries = [_]EncodeEntry{.{ .name = "oom-code.bin", .data = payload }};
    const encryption = EncryptionOptions{
        .password = "oom-password-密码",
        .iv = [_]u8{0x42} ** 16,
        .salt = [_]u8{0x24} ** 16,
        .salt_len = 8,
        .num_cycles_power = @import("seven_zip/aes.zig").direct_key_power,
    };
    const Options = struct {
        entries: []const EncodeEntry,
        encryption: EncryptionOptions,
    };
    const EncodeTest = struct {
        fn run(allocator: std.mem.Allocator, options: Options) !void {
            const encoded = try encodeAlloc(allocator, options.entries, .{
                .compression = .lzma2,
                .encryption = options.encryption,
                .bcj2 = true,
            });
            allocator.free(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, EncodeTest.run, .{Options{
        .entries = &entries,
        .encryption = encryption,
    }});

    const encoded = try encodeAlloc(std.testing.allocator, &entries, .{
        .compression = .lzma2,
        .encryption = encryption,
        .bcj2 = true,
    });
    defer std.testing.allocator.free(encoded);
    const DecodeFailureCase = struct {
        encoded: []const u8,
        password: []const u8,
    };
    const DecodeTest = struct {
        fn run(allocator: std.mem.Allocator, options: DecodeFailureCase) !void {
            const parsed = try parseAlloc(allocator, options.encoded);
            defer parsed.deinit();
            const decoded = try parsed.decodeEntryAllocWithOptions(
                allocator,
                parsed.entries[0],
                .{ .password = options.password },
            );
            allocator.free(decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, DecodeTest.run, .{
        DecodeFailureCase{ .encoded = encoded, .password = encryption.password },
    });
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

test "7z writer round trips ARM64 and RISC-V branch filters" {
    const cases = [_]struct {
        filter: Filter,
        payload: []const u8,
        method: @import("seven_zip/types.zig").Method,
    }{
        .{
            .filter = try Filter.arm64(4096),
            .payload = "\x00\x00\x00\x94\x00\x00\x00\x90" ** 1024,
            .method = .arm64,
        },
        .{
            .filter = try Filter.riscv(4096),
            .payload = "\xef\x00\x00\x00\x13\x00\x00\x00\x97\x01\x00\x00\xe7\x80\x01\x00" ** 512,
            .method = .riscv,
        },
    };
    for (cases) |case| {
        const entries = [_]EncodeEntry{.{ .name = "code.bin", .data = case.payload }};
        const encoded = try encodeAlloc(std.testing.allocator, &entries, .{
            .compression = .lzma2,
            .filters = &.{case.filter},
        });
        defer std.testing.allocator.free(encoded);
        const parsed = try parseAlloc(std.testing.allocator, encoded);
        defer parsed.deinit();
        const folder = parsed.streams.folders[0];
        try std.testing.expectEqual(case.method, folder.coders[folder.decode_order[1]].method);
        const decoded = try parsed.extractEntryAlloc(std.testing.allocator, parsed.entries[0]);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case.payload, decoded);
    }
}

const SourceTestContext = struct {
    bytes: []const u8,
    max_chunk: usize,

    fn readAt(
        raw_context: *anyopaque,
        offset: u64,
        output: []u8,
    ) error{SourceReadFailed}!usize {
        const self: *@This() = @ptrCast(@alignCast(raw_context));
        const start = std.math.cast(usize, offset) orelse return error.SourceReadFailed;
        if (start >= self.bytes.len) return 0;
        const count = @min(output.len, @min(self.max_chunk, self.bytes.len - start));
        @memcpy(output[0..count], self.bytes[start..][0..count]);
        return count;
    }

    fn source(self: *@This()) Source {
        return .{ .context = self, .len = self.bytes.len, .read_at = readAt };
    }
};

fn decodeSourceEntryFragmented(
    allocator: std.mem.Allocator,
    archive_value: *const SourceArchive,
    entry: Entry,
    options: SourceEntryDecoder.Options,
    output_chunk_size: usize,
) ![]u8 {
    var decoder = try archive_value.entryDecoder(allocator, entry, options);
    defer decoder.deinit();
    const expected_size = std.math.cast(usize, entry.size) orelse
        return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, expected_size);
    errdefer allocator.free(output);
    var output_offset: usize = 0;
    var calls: usize = 0;
    while (true) {
        calls += 1;
        if (calls > 1_000_000) return error.Invalid7zArchive;
        const output_end = @min(output.len, output_offset + output_chunk_size);
        const stepped = try decoder.step(output[output_offset..output_end]);
        output_offset += stepped.progress.output_written;
        if (stepped.status == .done) break;
        if (stepped.status == .need_input) return error.Invalid7zArchive;
        if (output_offset == output.len and stepped.status == .need_output)
            return error.Invalid7zArchive;
    }
    if (output_offset != output.len) return error.SizeMismatch;
    return output;
}

test "7z source entry decoder streams common codecs and solid substreams" {
    const first = "solid prefix that must be decoded and discarded\n" ** 257;
    const second = "selected source entry payload\n" ** 521;
    const entries = [_]EncodeEntry{
        .{ .name = "first.bin", .data = first },
        .{ .name = "second.bin", .data = second },
        .{ .name = "empty.bin" },
    };
    inline for (.{
        Compression.copy,
        Compression.deflate,
        Compression.bzip2,
        Compression.lzma,
        Compression.lzma2,
        Compression.lzma2_stored,
    }) |compression| {
        errdefer std.debug.print("source entry codec failed: {s}\n", .{@tagName(compression)});
        const encoded = try encodeAlloc(std.testing.allocator, &entries, .{
            .compression = compression,
            .solid = true,
        });
        defer std.testing.allocator.free(encoded);
        var context = SourceTestContext{ .bytes = encoded, .max_chunk = 7 };
        const parsed = try parseSourceAlloc(std.testing.allocator, context.source());
        defer parsed.deinit();
        const selected = parsed.find("second.bin") orelse return error.EntryNotFound;
        const decoded = try decodeSourceEntryFragmented(
            std.testing.allocator,
            &parsed,
            selected,
            .{
                .max_output_len = second.len,
                .max_folder_output_len = first.len + second.len,
                .input_buffer_size = 17,
                .decoded_buffer_size = 13,
            },
            5,
        );
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, second, decoded);

        const empty = parsed.find("empty.bin") orelse return error.EntryNotFound;
        const empty_decoded = try decodeSourceEntryFragmented(
            std.testing.allocator,
            &parsed,
            empty,
            .{},
            1,
        );
        defer std.testing.allocator.free(empty_decoded);
        try std.testing.expectEqual(@as(usize, 0), empty_decoded.len);
    }
}

test "7z source entry decoder streams AES filters and releases allocation failures" {
    const payload = "\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff\x90 encrypted\n" ** 257;
    const entries = [_]EncodeEntry{.{ .name = "encrypted.bin", .data = payload }};
    const encryption = EncryptionOptions{
        .password = "entry-password-密码",
        .iv = [_]u8{0x42} ** 16,
        .salt = [_]u8{0x24} ** 16,
        .salt_len = 8,
        .num_cycles_power = @import("seven_zip/aes.zig").direct_key_power,
    };
    const filters = [_]Filter{Filter.x86(0x1000)};
    const encoded = try encodeAlloc(std.testing.allocator, &entries, .{
        .compression = .lzma2,
        .encryption = encryption,
        .filters = &filters,
    });
    defer std.testing.allocator.free(encoded);
    var context = SourceTestContext{ .bytes = encoded, .max_chunk = 3 };
    const parsed = try parseSourceAlloc(std.testing.allocator, context.source());
    defer parsed.deinit();
    try std.testing.expectError(
        error.PasswordRequired,
        parsed.entryDecoder(std.testing.allocator, parsed.entries[0], .{}),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.entryDecoder(std.testing.allocator, parsed.entries[0], .{
            .password = encryption.password,
            .max_packed_stream_size = 1,
        }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.entryDecoder(std.testing.allocator, parsed.entries[0], .{
            .password = encryption.password,
            .max_dictionary_size = 4095,
        }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.entryDecoder(std.testing.allocator, parsed.entries[0], .{
            .password = encryption.password,
            .input_buffer_size = 15,
        }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.entryDecoder(std.testing.allocator, parsed.entries[0], .{
            .password = encryption.password,
            .max_packed_stream_size = 1,
        }),
    );
    var blocked = try parsed.entryDecoder(std.testing.allocator, parsed.entries[0], .{
        .password = encryption.password,
        .max_output_len = payload.len,
        .max_folder_output_len = payload.len,
        .input_buffer_size = 32,
        .decoded_buffer_size = 11,
    });
    defer blocked.deinit();
    try std.testing.expectEqual(
        core.StepResult.Status.need_output,
        (try blocked.step(&.{})).status,
    );
    const decoded = try decodeSourceEntryFragmented(
        std.testing.allocator,
        &parsed,
        parsed.entries[0],
        .{
            .password = encryption.password,
            .max_output_len = payload.len,
            .max_folder_output_len = payload.len,
            .input_buffer_size = 31,
            .decoded_buffer_size = 7,
        },
        3,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    var wrong = try parsed.entryDecoder(std.testing.allocator, parsed.entries[0], .{
        .password = "wrong-password",
        .max_output_len = payload.len,
        .max_folder_output_len = payload.len,
        .input_buffer_size = 32,
        .decoded_buffer_size = 11,
    });
    defer wrong.deinit();
    var wrong_scratch: [7]u8 = undefined;
    var wrong_rejected = false;
    for (0..100_000) |_| {
        if (wrong.step(&wrong_scratch)) |stepped| {
            if (stepped.status == .done) break;
        } else |_| {
            wrong_rejected = true;
            break;
        }
    }
    try std.testing.expect(wrong_rejected);

    const FailureTest = struct {
        fn run(
            allocator: std.mem.Allocator,
            archive_value: *const SourceArchive,
            password: []const u8,
            expected: []const u8,
        ) !void {
            const result = try decodeSourceEntryFragmented(
                allocator,
                archive_value,
                archive_value.entries[0],
                .{
                    .password = password,
                    .max_output_len = expected.len,
                    .max_folder_output_len = expected.len,
                    .input_buffer_size = 32,
                    .decoded_buffer_size = 11,
                },
                5,
            );
            defer allocator.free(result);
            try std.testing.expectEqualSlices(u8, expected, result);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        FailureTest.run,
        .{ &parsed, encryption.password, payload },
    );
}

test "7z source entry decoder streams compound filters" {
    const payload = "\x90\xe8\x10\x00\x00\x00branch" ** 32;
    const entries = [_]EncodeEntry{.{ .name = "filtered.bin", .data = payload }};
    const filters = [_]Filter{ Filter.x86(0), try Filter.delta(4) };
    const encoded = try encodeAlloc(std.testing.allocator, &entries, .{
        .compression = .lzma2,
        .filters = &filters,
    });
    defer std.testing.allocator.free(encoded);
    var context = SourceTestContext{ .bytes = encoded, .max_chunk = 17 };
    const parsed = try parseSourceAlloc(std.testing.allocator, context.source());
    defer parsed.deinit();
    const decoded = try decodeSourceEntryFragmented(
        std.testing.allocator,
        &parsed,
        parsed.entries[0],
        .{
            .max_output_len = payload.len,
            .max_folder_output_len = payload.len,
            .input_buffer_size = 19,
            .decoded_buffer_size = 9,
        },
        4,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "7z source entry decoder streams BCJ2 data plane" {
    const prefix = "BCJ2 solid prefix\n" ** 97;
    const payload = "remaining incremental graph payload\n" ** 64;
    const entries = [_]EncodeEntry{
        .{ .name = "prefix.bin", .data = prefix },
        .{ .name = "payload.bin", .data = payload },
    };
    const encoded = try encodeAlloc(std.testing.allocator, &entries, .{
        .compression = .lzma2,
        .bcj2 = true,
        .solid = true,
    });
    defer std.testing.allocator.free(encoded);
    var context = SourceTestContext{ .bytes = encoded, .max_chunk = 31 };
    const parsed = try parseSourceAlloc(std.testing.allocator, context.source());
    defer parsed.deinit();
    const decoded = try decodeSourceEntryFragmented(
        std.testing.allocator,
        &parsed,
        parsed.entries[1],
        .{
            .max_output_len = payload.len,
            .max_folder_output_len = prefix.len + payload.len,
            .input_buffer_size = 17,
            .decoded_buffer_size = 11,
        },
        5,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "7z source entry decoder streams encrypted BCJ2 and releases OOM" {
    const payload = "\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff\x90 encrypted BCJ2\n" ** 64;
    const entries = [_]EncodeEntry{.{ .name = "encrypted-bcj2.bin", .data = payload }};
    const encryption = EncryptionOptions{
        .password = "bcj2-entry-password-密码",
        .iv = [_]u8{0x42} ** 16,
        .salt = [_]u8{0x24} ** 16,
        .salt_len = 8,
        .num_cycles_power = @import("seven_zip/aes.zig").direct_key_power,
    };
    const encoded = try encodeAlloc(std.testing.allocator, &entries, .{
        .compression = .lzma2,
        .bcj2 = true,
        .encryption = encryption,
    });
    defer std.testing.allocator.free(encoded);
    var context = SourceTestContext{ .bytes = encoded, .max_chunk = 5 };
    const parsed = try parseSourceAlloc(std.testing.allocator, context.source());
    defer parsed.deinit();
    try std.testing.expectError(
        error.PasswordRequired,
        parsed.entryDecoder(std.testing.allocator, parsed.entries[0], .{}),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.entryDecoder(std.testing.allocator, parsed.entries[0], .{
            .password = encryption.password,
            .input_buffer_size = 15,
        }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.entryDecoder(std.testing.allocator, parsed.entries[0], .{
            .password = encryption.password,
            .max_packed_stream_size = 1,
        }),
    );
    var blocked = try parsed.entryDecoder(std.testing.allocator, parsed.entries[0], .{
        .password = encryption.password,
        .max_output_len = payload.len,
        .max_folder_output_len = payload.len,
        .input_buffer_size = 32,
        .decoded_buffer_size = 11,
    });
    defer blocked.deinit();
    try std.testing.expectEqual(
        core.StepResult.Status.need_output,
        (try blocked.step(&.{})).status,
    );
    const decoded = try decodeSourceEntryFragmented(
        std.testing.allocator,
        &parsed,
        parsed.entries[0],
        .{
            .password = encryption.password,
            .max_output_len = payload.len,
            .max_folder_output_len = payload.len,
            .input_buffer_size = 31,
            .decoded_buffer_size = 9,
        },
        3,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const FailureTest = struct {
        fn run(
            allocator: std.mem.Allocator,
            archive_value: *const SourceArchive,
            password: []const u8,
            expected: []const u8,
        ) !void {
            const result = try decodeSourceEntryFragmented(
                allocator,
                archive_value,
                archive_value.entries[0],
                .{
                    .password = password,
                    .max_output_len = expected.len,
                    .max_folder_output_len = expected.len,
                    .input_buffer_size = 32,
                    .decoded_buffer_size = 11,
                },
                5,
            );
            defer allocator.free(result);
            try std.testing.expectEqualSlices(u8, expected, result);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        FailureTest.run,
        .{ &parsed, encryption.password, payload },
    );
}

test "7z source entry decoder reports terminal folder CRC corruption" {
    const payload = "streamed bytes precede terminal CRC validation" ** 32;
    const entries = [_]EncodeEntry{.{ .name = "corrupt.bin", .data = payload }};
    const encoded = try encodeAlloc(std.testing.allocator, &entries, .{ .compression = .copy });
    defer std.testing.allocator.free(encoded);
    encoded[32] ^= 1;
    var context = SourceTestContext{ .bytes = encoded, .max_chunk = 23 };
    const parsed = try parseSourceAlloc(std.testing.allocator, context.source());
    defer parsed.deinit();
    var decoder = try parsed.entryDecoder(std.testing.allocator, parsed.entries[0], .{
        .max_output_len = payload.len,
        .max_folder_output_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.ChecksumMismatch, decoder.step(&output));
    try std.testing.expect(!std.mem.eql(u8, payload, &output));
}

test "7z split sources parse and stream encrypted solid entries" {
    const first = "\x90\xe8\x10\x00\x00\x00 split prefix\n" ** 97;
    const second = "selected split-volume payload\n" ** 257;
    const entries = [_]EncodeEntry{
        .{ .name = "first.bin", .data = first },
        .{ .name = "second.bin", .data = second },
    };
    const filters = [_]Filter{Filter.x86(0x1000)};
    const encryption = EncryptionOptions{
        .password = "split-password-密码",
        .iv = [_]u8{0x42} ** 16,
        .salt = [_]u8{0x24} ** 16,
        .salt_len = 8,
        .num_cycles_power = @import("seven_zip/aes.zig").direct_key_power,
    };
    const encoded = try encodeAlloc(std.testing.allocator, &entries, .{
        .compression = .lzma2,
        .solid = true,
        .header_compression = .copy,
        .filters = &filters,
        .encryption = encryption,
        .encrypt_header = true,
    });
    defer std.testing.allocator.free(encoded);
    const part_len: usize = 127;
    const part_count = (encoded.len + part_len - 1) / part_len;
    const parts = try std.testing.allocator.alloc([]const u8, part_count);
    defer std.testing.allocator.free(parts);
    const lengths = try std.testing.allocator.alloc(u64, part_count);
    defer std.testing.allocator.free(lengths);
    for (parts, lengths, 0..) |*part, *length, index| {
        const start = index * part_len;
        const end = @min(encoded.len, start + part_len);
        part.* = encoded[start..end];
        length.* = part.len;
    }

    var slices = try SplitSliceSource.initAlloc(std.testing.allocator, parts, .{});
    defer slices.deinit();
    const parsed_slices = try parseSourceAllocWithOptions(
        std.testing.allocator,
        slices.source(),
        .{ .password = encryption.password },
    );
    defer parsed_slices.deinit();
    const slice_decoded = try decodeSourceEntryFragmented(
        std.testing.allocator,
        &parsed_slices,
        parsed_slices.entries[1],
        .{
            .password = encryption.password,
            .max_output_len = second.len,
            .max_folder_output_len = first.len + second.len,
            .input_buffer_size = 64,
            .decoded_buffer_size = 17,
        },
        7,
    );
    defer std.testing.allocator.free(slice_decoded);
    try std.testing.expectEqualSlices(u8, second, slice_decoded);

    const PartContext = struct {
        parts: []const []const u8,

        fn readAt(
            raw_context: *anyopaque,
            part_index: usize,
            offset: u64,
            output: []u8,
        ) error{PartSourceReadFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(raw_context));
            if (part_index >= self.parts.len) return error.PartSourceReadFailed;
            const start = std.math.cast(usize, offset) orelse return error.PartSourceReadFailed;
            if (start >= self.parts[part_index].len) return 0;
            const count = @min(output.len, @min(@as(usize, 3), self.parts[part_index].len - start));
            @memcpy(output[0..count], self.parts[part_index][start..][0..count]);
            return count;
        }
    };
    var context = PartContext{ .parts = parts };
    var callback = try SplitCallbackSource.initAlloc(std.testing.allocator, .{
        .context = &context,
        .part_lengths = lengths,
        .read_at = PartContext.readAt,
    }, .{});
    defer callback.deinit();
    const parsed_callback = try parseSourceAllocWithOptions(
        std.testing.allocator,
        callback.source(),
        .{ .password = encryption.password },
    );
    defer parsed_callback.deinit();
    const callback_decoded = try decodeSourceEntryFragmented(
        std.testing.allocator,
        &parsed_callback,
        parsed_callback.entries[1],
        .{
            .password = encryption.password,
            .max_output_len = second.len,
            .max_folder_output_len = first.len + second.len,
            .input_buffer_size = 64,
            .decoded_buffer_size = 17,
        },
        7,
    );
    defer std.testing.allocator.free(callback_decoded);
    try std.testing.expectEqualSlices(u8, second, callback_decoded);
}
