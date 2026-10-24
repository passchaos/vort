const std = @import("std");
const records = @import("records.zig");
const strong_wire = @import("pkware_strong.zig");
const strong_crypto = @import("vail_archive_crypto").pkware_strong;
const wire = @import("wire.zig");
const zip = @import("../zip.zig");

const password = "PKWARE strong ZIP password";
const iv128 = [_]u8{0x11} ** 16;
const iv192 = [_]u8{0x22} ** 16;
const iv256 = [_]u8{0x33} ** 16;
const random128 = [_]u8{0x41} ** 16;
const random192 = [_]u8{0x42} ** 16;
const random256 = [_]u8{0x43} ** 32;
const validation128 = [_]u8{0x51} ** 12;
const validation192 = [_]u8{0x52} ** 12;
const validation256 = [_]u8{0x53} ** 12;

test "ZIP PKWARE Strong Encryption round trips AES strengths and wire layouts" {
    const allocator = std.testing.allocator;
    const stored_payload = "PKWARE AES-128 stored payload";
    const deflate_payload = "PKWARE AES-192 Deflate payload\n" ** 83;
    const bzip2_payload = "PKWARE AES-256 Bzip2 payload\n" ** 71;
    const entries = [_]zip.EncodeEntry{
        .{
            .name = "strong/aes128-stored.bin",
            .data = stored_payload,
            .method = .stored,
            .pkware_strong_encryption = .{
                .password = password,
                .strength = .aes128,
                .iv = iv128,
                .random_data = &random128,
                .validation_data = &validation128,
            },
        },
        .{
            .name = "strong/aes192-deflate.txt",
            .data = deflate_payload,
            .method = .deflate,
            .pkware_strong_encryption = .{
                .password = password,
                .strength = .aes192,
                .iv = iv192,
                .random_data = &random192,
                .validation_data = &validation192,
            },
        },
        .{
            .name = "strong/aes256-bzip2.txt",
            .data = bzip2_payload,
            .method = .bzip2,
            .pkware_strong_encryption = .{
                .password = password,
                .strength = .aes256,
                .iv = iv256,
                .random_data = &random256,
                .validation_data = &validation256,
            },
        },
    };

    inline for (.{ false, true }) |descriptor| {
        inline for (.{ zip.Zip64Mode.never, .always }) |zip64_mode| {
            const bytes = try zip.encodeAlloc(allocator, &entries, .{
                .data_descriptor = descriptor,
                .zip64 = zip64_mode,
            });
            defer allocator.free(bytes);
            const repeated = try zip.encodeAlloc(allocator, &entries, .{
                .data_descriptor = descriptor,
                .zip64 = zip64_mode,
            });
            defer allocator.free(repeated);
            try std.testing.expectEqualSlices(u8, bytes, repeated);

            const archive = try zip.parse(bytes);
            for (entries, 0..) |expected, index| {
                const entry = try archive.entryAt(index);
                try std.testing.expect(entry.isEncrypted());
                try std.testing.expect(entry.isPkwareStrongEncrypted());
                try std.testing.expect(!entry.isWinZipAes());
                try std.testing.expectEqual(expected.method, entry.method);
                try std.testing.expectEqual(
                    expected.pkware_strong_encryption.?.strength,
                    entry.pkware_strong_encryption.?.strength,
                );
                try std.testing.expectEqual(
                    wire.encrypted_flag | wire.strong_encryption_flag,
                    entry.flags & (wire.encrypted_flag | wire.strong_encryption_flag),
                );
                try std.testing.expectEqual(
                    @intFromEnum(expected.method),
                    try readU16(bytes, entry.local_header_offset + 8),
                );
                try std.testing.expect((try readU16(bytes, entry.local_header_offset + 4)) >= wire.version_51);

                const local_extra = try localExtra(bytes, entry);
                try std.testing.expect((try records.findExtra(local_extra, wire.pkware_strong_extra_id)) == null);
                const central_extra = try centralExtra(bytes, entry);
                const strong_extra = (try records.findExtra(
                    central_extra,
                    wire.pkware_strong_extra_id,
                )).?;
                try std.testing.expectEqual(@as(usize, 8), strong_extra.len);
                try std.testing.expectEqual(@as(u16, 2), std.mem.readInt(u16, strong_extra[0..2], .little));

                const payload_offset = try localPayloadOffset(bytes, entry);
                try std.testing.expectEqual(@as(u16, 16), try readU16(bytes, payload_offset));
                try std.testing.expectEqual(@as(u16, 3), try readU16(bytes, payload_offset + 22));
                try std.testing.expectEqual(
                    @as(u16, 1),
                    try readU16(bytes, payload_offset + 28),
                );
                try std.testing.expectError(error.EncryptedZipEntry, archive.compressedData(entry));
                try std.testing.expectError(
                    error.PasswordRequired,
                    archive.extractAllocWithOptions(allocator, entry, .{}),
                );
                try std.testing.expectError(
                    error.InvalidPasswordValidation,
                    archive.extractAllocWithOptions(allocator, entry, .{ .password = "wrong" }),
                );
                const decoded = try archive.extractAllocWithOptions(
                    allocator,
                    entry,
                    .{ .password = password },
                );
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, expected.data, decoded);
            }
        }
    }
}

test "ZIP PKWARE Strong Encryption rejects corrupt validation padding and metadata" {
    const allocator = std.testing.allocator;
    const entries = [_]zip.EncodeEntry{.{
        .name = "strong.bin",
        .data = "PKWARE Strong corruption payload" ** 4,
        .method = .stored,
        .pkware_strong_encryption = .{
            .password = password,
            .iv = iv256,
            .random_data = &random256,
            .validation_data = &validation256,
        },
    }};
    const bytes = try zip.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(bytes);
    const archive = try zip.parse(bytes);
    const entry = try archive.entryAt(0);
    const payload_offset = try localPayloadOffset(bytes, entry);
    const random_size: usize = try readU16(bytes, payload_offset + 30);
    const validation_offset = payload_offset + 32 + random_size + 4 + 2;

    const bad_validation = try allocator.dupe(u8, bytes);
    defer allocator.free(bad_validation);
    bad_validation[validation_offset] ^= 1;
    const validation_archive = try zip.parse(bad_validation);
    try std.testing.expectError(
        error.InvalidPasswordValidation,
        validation_archive.extractAllocWithOptions(
            allocator,
            try validation_archive.entryAt(0),
            .{ .password = password },
        ),
    );

    const bad_padding = try allocator.dupe(u8, bytes);
    defer allocator.free(bad_padding);
    bad_padding[payload_offset + entry.compressed_size - 1] ^= 1;
    const padding_archive = try zip.parse(bad_padding);
    try std.testing.expectError(
        error.InvalidPadding,
        padding_archive.extractAllocWithOptions(
            allocator,
            try padding_archive.entryAt(0),
            .{ .password = password },
        ),
    );

    const bad_flags = try allocator.dupe(u8, bytes);
    defer allocator.free(bad_flags);
    const central_flags = entry.central_header_offset + 8;
    std.mem.writeInt(
        u16,
        bad_flags[central_flags..][0..2],
        entry.flags & ~wire.strong_encryption_flag,
        .little,
    );
    const flags_archive = try zip.parse(bad_flags);
    try std.testing.expectError(error.InvalidZipArchive, flags_archive.entryAt(0));

    const bad_version = try allocator.dupe(u8, bytes);
    defer allocator.free(bad_version);
    std.mem.writeInt(u16, bad_version[entry.central_header_offset + 6 ..][0..2], 50, .little);
    const version_archive = try zip.parse(bad_version);
    try std.testing.expectError(error.InvalidZipArchive, version_archive.entryAt(0));

    const bad_algorithm = try allocator.dupe(u8, bytes);
    defer allocator.free(bad_algorithm);
    const central_extra_offset = try centralExtraOffset(bytes, entry);
    std.mem.writeInt(u16, bad_algorithm[central_extra_offset + 6 ..][0..2], 0x660e, .little);
    const algorithm_archive = try zip.parse(bad_algorithm);
    try std.testing.expectError(error.InvalidZipArchive, algorithm_archive.entryAt(0));
}

test "ZIP PKWARE writer rejects conflicting or non-interoperable strong encryption options" {
    const allocator = std.testing.allocator;
    const conflict = [_]zip.EncodeEntry{.{
        .name = "conflict.bin",
        .data = "conflict",
        .traditional_encryption = .{
            .password = password,
            .header_random = .{0} ** 11,
        },
        .pkware_strong_encryption = .{
            .password = password,
            .iv = iv256,
            .random_data = &random256,
            .validation_data = &validation256,
        },
    }};
    try std.testing.expectError(
        error.ConflictingZipEncryption,
        zip.encodeAlloc(allocator, &conflict, .{}),
    );

    const invalid_random = [_]zip.EncodeEntry{.{
        .name = "invalid.bin",
        .data = "invalid",
        .pkware_strong_encryption = .{
            .password = password,
            .iv = iv256,
            .random_data = "not block aligned",
            .validation_data = &validation256,
        },
    }};
    try std.testing.expectError(
        error.InvalidRandomDataLength,
        zip.encodeAlloc(allocator, &invalid_random, .{}),
    );
}

test "ZIP PKWARE Strong Encryption releases every allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const entries = [_]zip.EncodeEntry{.{
                .name = "allocation-safe.bin",
                .data = "allocation-safe PKWARE Strong payload",
                .pkware_strong_encryption = .{
                    .password = password,
                    .iv = iv256,
                    .random_data = &random256,
                    .validation_data = &validation256,
                },
            }};
            const bytes = try zip.encodeAlloc(allocator, &entries, .{});
            defer allocator.free(bytes);
            const archive = try zip.parse(bytes);
            const decoded = try archive.extractAllocWithOptions(
                allocator,
                try archive.entryAt(0),
                .{ .password = password },
            );
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, entries[0].data, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}

test "ZIP PKWARE Strong reader accepts the synthesized zero-length IV form" {
    const allocator = std.testing.allocator;
    const crc32: u32 = 0x89ab_cdef;
    const uncompressed_size: u64 = 0x0123_4567_89ab_cdef;
    var synthesized_iv: [strong_crypto.block_len]u8 = @splat(0);
    std.mem.writeInt(u32, synthesized_iv[0..4], crc32, .little);
    std.mem.writeInt(u64, synthesized_iv[4..12], uncompressed_size, .little);
    const random_data: [strong_crypto.block_len]u8 = @splat(0xa5);
    const validation_data: [strong_crypto.block_len - @sizeOf(u32)]u8 = @splat(0x5a);
    const compressed = "synthesized-IV compressed payload";
    var encrypted = try strong_crypto.encryptAlloc(allocator, compressed, .{
        .password = password,
        .strength = .aes256,
        .cbc_iv = synthesized_iv,
        .iv_material = synthesized_iv[0..strong_wire.synthesized_iv_material_len],
        .random_data = &random_data,
        .validation_data = &validation_data,
    });
    defer encrypted.deinit(allocator);

    const remaining_len = strong_wire.fixed_remaining_len +
        encrypted.encrypted_random_data.len + encrypted.validation_size;
    const file_len = encrypted.encrypted_payload.len - encrypted.validation_size;
    const encoded = try allocator.alloc(u8, 2 + 4 + remaining_len + file_len);
    defer allocator.free(encoded);
    var cursor: usize = 0;
    putU16(encoded, &cursor, 0);
    putU32(encoded, &cursor, @intCast(remaining_len));
    putU16(encoded, &cursor, strong_wire.format);
    putU16(encoded, &cursor, strong_wire.algorithmId(.aes256));
    putU16(encoded, &cursor, strong_wire.bitLength(.aes256));
    putU16(encoded, &cursor, strong_wire.password_flag);
    putU16(encoded, &cursor, @intCast(encrypted.encrypted_random_data.len));
    putBytes(encoded, &cursor, encrypted.encrypted_random_data);
    putU32(encoded, &cursor, 0);
    putU16(encoded, &cursor, @intCast(encrypted.validation_size));
    putBytes(encoded, &cursor, encrypted.encrypted_payload);
    try std.testing.expectEqual(encoded.len, cursor);

    const decoded = try strong_wire.decryptAlloc(
        allocator,
        encoded,
        password,
        .aes256,
        crc32,
        uncompressed_size,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, compressed, decoded);
    try std.testing.expectError(
        error.InvalidPasswordValidation,
        strong_wire.decryptAlloc(
            allocator,
            encoded,
            password,
            .aes256,
            crc32 ^ 1,
            uncompressed_size,
        ),
    );
}

test "ZIP PKWARE Strong composes with owned split normalization" {
    const allocator = std.testing.allocator;
    const payload = "split PKWARE Strong payload crosses volumes\n" ** 31;
    const entries = [_]zip.EncodeEntry{.{
        .name = "strong/split.txt",
        .data = payload,
        .method = .deflate,
        .pkware_strong_encryption = .{
            .password = password,
            .iv = iv256,
            .random_data = &random256,
            .validation_data = &validation256,
        },
    }};
    var split_archive = try zip.encodeSplitAlloc(allocator, &entries, .{
        .zip_options = .{ .data_descriptor = true, .zip64 = .always },
        .max_part_size = 128,
    });
    defer split_archive.deinit();
    try std.testing.expect(split_archive.parts.len > 1);
    var normalized = try zip.parseSplitArchiveAlloc(
        allocator,
        split_archive.parts,
        .{},
    );
    defer normalized.deinit();
    const decoded = try normalized.archive.extractAllocWithOptions(
        allocator,
        try normalized.archive.entryAt(0),
        .{ .password = password },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

fn localPayloadOffset(bytes: []const u8, entry: zip.Entry) !usize {
    const name_len: usize = try readU16(bytes, entry.local_header_offset + 26);
    const extra_len: usize = try readU16(bytes, entry.local_header_offset + 28);
    return entry.local_header_offset + wire.local_file_header_len + name_len + extra_len;
}

fn localExtra(bytes: []const u8, entry: zip.Entry) ![]const u8 {
    const name_len: usize = try readU16(bytes, entry.local_header_offset + 26);
    const extra_len: usize = try readU16(bytes, entry.local_header_offset + 28);
    const start = entry.local_header_offset + wire.local_file_header_len + name_len;
    return bytes[start..][0..extra_len];
}

fn centralExtraOffset(bytes: []const u8, entry: zip.Entry) !usize {
    const name_len: usize = try readU16(bytes, entry.central_header_offset + 28);
    return entry.central_header_offset + wire.central_file_header_len + name_len;
}

fn centralExtra(bytes: []const u8, entry: zip.Entry) ![]const u8 {
    const start = try centralExtraOffset(bytes, entry);
    const extra_len: usize = try readU16(bytes, entry.central_header_offset + 30);
    return bytes[start..][0..extra_len];
}

fn readU16(bytes: []const u8, offset: usize) !u16 {
    if (offset > bytes.len or bytes.len - offset < 2) return error.InvalidZipArchive;
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn putBytes(output: []u8, cursor: *usize, bytes: []const u8) void {
    @memcpy(output[cursor.*..][0..bytes.len], bytes);
    cursor.* += bytes.len;
}

fn putU16(output: []u8, cursor: *usize, value: u16) void {
    std.mem.writeInt(u16, output[cursor.*..][0..2], value, .little);
    cursor.* += 2;
}

fn putU32(output: []u8, cursor: *usize, value: u32) void {
    std.mem.writeInt(u32, output[cursor.*..][0..4], value, .little);
    cursor.* += 4;
}
