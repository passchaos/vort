const std = @import("std");
const archive_mod = @import("archive.zig");
const checksum = @import("../checksum.zig");
const writer = @import("writer.zig");

const reference_hex =
    "526172211a070100652e1f9f21040000010fcccd3f9cc3318255fb1d6c5623fc411f72331e6640dc0f804546413f8f55ff931149123ad29dc6a16ac7f40d3032" ++
    "17e1e9d5e88851d1170ba47a8453576e7082e3cab788dfde3420c5658ee22a50cc3b5bd52c1fbb0db7a962e2806a82fe2351ce52de89117a42f04ef2c79dc254" ++
    "d3fd88fbf867a26042af298868440f6d11ccc127d8195924874662ca20a589653c3b530e55f0bcdc5586d672dff5f58ab20843e09c9685830a54dec51450a768" ++
    "db0d3d6f6d8a6e539e63ad1780779bb9465c097f95ede443463629e5fa9a701dcd7c65a886589351d97c6abe3bca1b1c46b8426d898005654d4625dd7678ce99" ++
    "0df0d9ffc2ce3bd0297b892f6df230d56f7cbcd8455f66e148ee42a2679f";

fn referenceBytes() [reference_hex.len / 2]u8 {
    var bytes: [reference_hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, reference_hex) catch unreachable;
    return bytes;
}

test "RAR5 encrypted headers decode a RAR 7.30 archive" {
    const allocator = std.testing.allocator;
    const bytes = referenceBytes();
    try std.testing.expectError(error.EncryptedRarHeaders, archive_mod.parse(&bytes));
    try std.testing.expectError(
        error.RarPasswordRequired,
        archive_mod.parseOwnedHeadersAllocWithOptions(allocator, &bytes, .{}),
    );
    try std.testing.expectError(
        error.InvalidRarPassword,
        archive_mod.parseOwnedHeadersAllocWithOptions(allocator, &bytes, .{
            .password = "wrong password",
        }),
    );
    try std.testing.expectError(
        error.Rar5KdfLimitExceeded,
        archive_mod.parseOwnedHeadersAllocWithOptions(allocator, &bytes, .{
            .password = "RAR5-header-password",
            .max_rar5_kdf_count = 14,
        }),
    );

    var owned = try archive_mod.parseOwnedHeadersAllocWithOptions(
        allocator,
        &bytes,
        .{ .password = "RAR5-header-password" },
    );
    defer owned.deinit();
    try std.testing.expectEqual(@as(usize, 1), owned.archive.entry_count);
    try std.testing.expectEqual(@as(u8, 15), owned.archive.header_encryption.?.kdf_count);
    const entry = try owned.archive.entryAt(0);
    try std.testing.expect(entry.name.eql("secret.txt"));
    try std.testing.expect(entry.encrypted);
    const decoded = try owned.archive.extractByNameAllocWithOptions(
        allocator,
        "secret.txt",
        .{ .password = "RAR5-header-password" },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(
        u8,
        "RAR5 encrypted headers reference payload\n",
        decoded,
    );
}

test "RAR5 encrypted header owned parser enforces metadata limits" {
    const bytes = referenceBytes();
    try std.testing.expectError(
        error.RarEntryLimitExceeded,
        archive_mod.parseOwnedHeadersAllocWithOptions(std.testing.allocator, &bytes, .{
            .password = "RAR5-header-password",
            .max_entries = 0,
        }),
    );
    try std.testing.expectError(
        error.RarMetadataLimitExceeded,
        archive_mod.parseOwnedHeadersAllocWithOptions(std.testing.allocator, &bytes, .{
            .password = "RAR5-header-password",
            .max_metadata_size = 1,
        }),
    );
}

test "RAR5 encrypted header writer composes with Stored and RAR50 data" {
    const allocator = std.testing.allocator;
    const payload = "Vort RAR5 encrypted header payload alpha beta gamma\n" ** 73;
    const header_ivs = [_][16]u8{
        [_]u8{0x81} ** 16,
        [_]u8{0x82} ** 16,
        [_]u8{0x83} ** 16,
        [_]u8{0x84} ** 16,
    };
    const entries = [_]writer.EncodeEntry{
        .{
            .name = "secret/payload.bin",
            .data = payload,
            .encryption = .{
                .password = "header secret",
                .salt = [_]u8{0x61} ** 16,
                .iv = [_]u8{0x71} ** 16,
                .kdf_count = 2,
            },
        },
        .{ .name = "empty-directory", .kind = .directory },
    };
    inline for (.{ writer.Compression.stored, writer.Compression.rar50 }) |compression| {
        const options = writer.EncodeOptions{
            .compression = compression,
            .block_size = 1024,
            .header_encryption = .{
                .password = "header secret",
                .salt = [_]u8{0x51} ** 16,
                .kdf_count = 2,
                .ivs = &header_ivs,
            },
        };
        const encoded = try writer.encodeAlloc(allocator, &entries, options);
        defer allocator.free(encoded);
        const second = try writer.encodeAlloc(allocator, &entries, options);
        defer allocator.free(second);
        try std.testing.expectEqualSlices(u8, encoded, second);
        try std.testing.expect(std.mem.indexOf(u8, encoded, entries[0].name) == null);
        try std.testing.expect(std.mem.indexOf(u8, encoded, entries[1].name) == null);
        try std.testing.expectError(error.EncryptedRarHeaders, archive_mod.parse(encoded));
        var owned = try archive_mod.parseOwnedHeadersAllocWithOptions(
            allocator,
            encoded,
            .{ .password = "header secret", .max_rar5_kdf_count = 2 },
        );
        defer owned.deinit();
        try std.testing.expectEqual(@as(usize, entries.len), owned.archive.entry_count);
        try std.testing.expectEqual(@as(u8, 2), owned.archive.header_encryption.?.kdf_count);
        const directory = try owned.archive.entryAt(1);
        try std.testing.expect(directory.directory);
        const decoded = try owned.archive.extractByNameAllocWithOptions(
            allocator,
            entries[0].name,
            .{ .password = "header secret", .max_rar5_kdf_count = 2 },
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
        if (compression == .stored) {
            var sfx: std.ArrayList(u8) = .empty;
            defer sfx.deinit(allocator);
            try sfx.appendSlice(allocator, "MZ encrypted-header prefix");
            try sfx.appendSlice(allocator, encoded);
            var prefixed = try archive_mod.parseOwnedHeadersAllocWithOptions(
                allocator,
                sfx.items,
                .{ .password = "header secret", .max_rar5_kdf_count = 2 },
            );
            defer prefixed.deinit();
            try std.testing.expectEqual(
                @as(usize, "MZ encrypted-header prefix".len),
                prefixed.archive.prefix_size,
            );
            const prefixed_data = try prefixed.archive.extractByNameAllocWithOptions(
                allocator,
                entries[0].name,
                .{ .password = "header secret", .max_rar5_kdf_count = 2 },
            );
            defer allocator.free(prefixed_data);
            try std.testing.expectEqualSlices(u8, payload, prefixed_data);
        }
    }
}

test "RAR5 encrypted header writer validates IV and password policy" {
    const allocator = std.testing.allocator;
    const unique_ivs = [_][16]u8{
        [_]u8{1} ** 16,
        [_]u8{2} ** 16,
        [_]u8{3} ** 16,
    };
    const duplicate_ivs = [_][16]u8{
        [_]u8{1} ** 16,
        [_]u8{1} ** 16,
        [_]u8{3} ** 16,
    };
    const encrypted = [_]writer.EncodeEntry{.{
        .name = "secret.bin",
        .data = "secret",
        .encryption = .{
            .password = "password",
            .salt = [_]u8{4} ** 16,
            .iv = [_]u8{5} ** 16,
            .kdf_count = 1,
        },
    }};
    const missing = [_]writer.EncodeEntry{.{ .name = "secret.bin", .data = "secret" }};
    try std.testing.expectError(
        error.InvalidRarHeaderEncryption,
        writer.encodeAlloc(allocator, &missing, .{ .header_encryption = .{
            .password = "password",
            .salt = [_]u8{6} ** 16,
            .kdf_count = 1,
            .ivs = &unique_ivs,
        } }),
    );
    try std.testing.expectError(
        error.InvalidRarHeaderEncryption,
        writer.encodeAlloc(allocator, &encrypted, .{ .header_encryption = .{
            .password = "different",
            .salt = [_]u8{6} ** 16,
            .kdf_count = 1,
            .ivs = &unique_ivs,
        } }),
    );
    try std.testing.expectError(
        error.InvalidRarHeaderEncryption,
        writer.encodeAlloc(allocator, &encrypted, .{ .header_encryption = .{
            .password = "password",
            .salt = [_]u8{6} ** 16,
            .kdf_count = 1,
            .ivs = &duplicate_ivs,
        } }),
    );
    try std.testing.expectError(
        error.InvalidRarHeaderEncryption,
        writer.encodeAlloc(allocator, &encrypted, .{ .header_encryption = .{
            .password = "password",
            .salt = [_]u8{6} ** 16,
            .kdf_count = 1,
            .ivs = unique_ivs[0..2],
        } }),
    );
    try std.testing.expectError(
        error.InvalidRarHeaderEncryption,
        writer.encodeVolumesAlloc(
            allocator,
            &encrypted,
            .{ .header_encryption = .{
                .password = "password",
                .salt = [_]u8{6} ** 16,
                .kdf_count = 1,
                .ivs = unique_ivs[0..2],
            } },
            1024,
        ),
    );
}

test "RAR5 encrypted headers retain solid RAR50 replay semantics" {
    const allocator = std.testing.allocator;
    var payload: [16 * 1024]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x6865_6164_736f_6c69);
    random.fill(&payload);
    const ivs = [_][16]u8{
        [_]u8{0xa1} ** 16,
        [_]u8{0xa2} ** 16,
        [_]u8{0xa3} ** 16,
        [_]u8{0xa4} ** 16,
    };
    const entries = [_]writer.EncodeEntry{
        .{
            .name = "first.bin",
            .data = &payload,
            .encryption = .{
                .password = "solid headers",
                .salt = [_]u8{0xb1} ** 16,
                .iv = [_]u8{0xc1} ** 16,
                .kdf_count = 1,
            },
        },
        .{
            .name = "second.bin",
            .data = &payload,
            .encryption = .{
                .password = "solid headers",
                .salt = [_]u8{0xb2} ** 16,
                .iv = [_]u8{0xc2} ** 16,
                .kdf_count = 1,
            },
        },
    };
    const encoded = try writer.encodeAlloc(allocator, &entries, .{
        .compression = .rar50,
        .solid = true,
        .header_encryption = .{
            .password = "solid headers",
            .salt = [_]u8{0xd1} ** 16,
            .kdf_count = 1,
            .ivs = &ivs,
        },
    });
    defer allocator.free(encoded);
    var owned = try archive_mod.parseOwnedHeadersAllocWithOptions(
        allocator,
        encoded,
        .{ .password = "solid headers", .max_rar5_kdf_count = 1 },
    );
    defer owned.deinit();
    const second = try owned.archive.entryAt(1);
    try std.testing.expect(second.solid);
    const decoded = try owned.archive.extractByNameAllocWithOptions(
        allocator,
        "second.bin",
        .{ .password = "solid headers", .max_rar5_kdf_count = 1 },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
}

test "RAR5 encrypted headers compose across solid encrypted volumes" {
    const volume_set = @import("volume_set.zig");
    const allocator = std.testing.allocator;
    var payload: [2048]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x766f_6c75_6d65_6870);
    random.fill(&payload);
    const entries = [_]writer.EncodeEntry{
        .{
            .name = "first.bin",
            .data = &payload,
            .encryption = .{
                .password = "volume headers",
                .salt = [_]u8{0x31} ** 16,
                .iv = [_]u8{0x41} ** 16,
                .kdf_count = 0,
            },
        },
        .{
            .name = "second.bin",
            .data = &payload,
            .encryption = .{
                .password = "volume headers",
                .salt = [_]u8{0x32} ** 16,
                .iv = [_]u8{0x42} ** 16,
                .kdf_count = 0,
            },
        },
    };
    const base_options = writer.EncodeOptions{
        .compression = .rar50,
        .solid = true,
    };
    var baseline = try writer.encodeVolumesAlloc(allocator, &entries, base_options, 512);
    defer baseline.deinit();
    var fragment_count: usize = 0;
    for (baseline.volumes) |volume| {
        const parsed = try archive_mod.parse(volume);
        fragment_count += parsed.entry_count;
    }
    const iv_count = 2 * baseline.volumes.len + fragment_count;
    const header_ivs = try allocator.alloc([16]u8, iv_count);
    defer allocator.free(header_ivs);
    for (header_ivs, 0..) |*iv, index| {
        iv.* = @splat(@intCast(index + 1));
        std.mem.writeInt(u64, iv[0..8], index, .little);
    }
    var options = base_options;
    options.header_encryption = .{
        .password = "volume headers",
        .salt = [_]u8{0x51} ** 16,
        .kdf_count = 0,
        .ivs = header_ivs,
    };
    var encoded = try writer.encodeVolumesAlloc(allocator, &entries, options, 512);
    defer encoded.deinit();
    try std.testing.expectEqual(baseline.volumes.len, encoded.volumes.len);
    for (encoded.volumes) |volume| {
        try std.testing.expect(std.mem.indexOf(u8, volume, "first.bin") == null);
        try std.testing.expect(std.mem.indexOf(u8, volume, "second.bin") == null);
    }
    try std.testing.expectError(
        error.RarPasswordRequired,
        volume_set.VolumeSet.parseAlloc(allocator, encoded.volumes),
    );
    try std.testing.expectError(
        error.InvalidRarPassword,
        volume_set.VolumeSet.parseAllocWithOptions(allocator, encoded.volumes, .{
            .password = "wrong",
            .max_rar5_kdf_count = 0,
        }),
    );
    try std.testing.expectError(
        error.RarEntryLimitExceeded,
        volume_set.VolumeSet.parseAllocWithOptions(allocator, encoded.volumes, .{
            .password = "volume headers",
            .max_rar5_kdf_count = 0,
            .max_entries = 0,
        }),
    );
    var set = try volume_set.VolumeSet.parseAllocWithOptions(
        allocator,
        encoded.volumes,
        .{ .password = "volume headers", .max_rar5_kdf_count = 0 },
    );
    defer set.deinit();
    const decoded = try set.extractByNameAllocWithOptions(
        allocator,
        "second.bin",
        .{ .password = "volume headers", .max_rar5_kdf_count = 0 },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
}

test "RAR5 encrypted header parser rejects corrupt checks and ciphertext" {
    const allocator = std.testing.allocator;
    const ivs = [_][16]u8{
        [_]u8{0xe1} ** 16,
        [_]u8{0xe2} ** 16,
        [_]u8{0xe3} ** 16,
    };
    const entries = [_]writer.EncodeEntry{.{
        .name = "secret.bin",
        .data = "corrupt encrypted header fixture",
        .encryption = .{
            .password = "password",
            .salt = [_]u8{0xe4} ** 16,
            .iv = [_]u8{0xe5} ** 16,
            .kdf_count = 1,
        },
    }};
    const encoded = try writer.encodeAlloc(allocator, &entries, .{
        .header_encryption = .{
            .password = "password",
            .salt = [_]u8{0xe6} ** 16,
            .kdf_count = 1,
            .ivs = &ivs,
        },
    });
    defer allocator.free(encoded);
    var parsed = try archive_mod.parseOwnedHeadersAllocWithOptions(
        allocator,
        encoded,
        .{ .password = "password", .max_rar5_kdf_count = 1 },
    );
    const file_header_offset = (try parsed.archive.entryAt(0)).header_offset;
    parsed.deinit();

    const bad_check = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_check);
    const crypt_body_size: usize = bad_check[12];
    const crypt_end = 13 + crypt_body_size;
    bad_check[crypt_end - 1] ^= 1;
    std.mem.writeInt(
        u32,
        bad_check[8..12],
        checksum.crc32(bad_check[12..crypt_end]),
        .little,
    );
    try std.testing.expectError(
        error.CorruptRar5PasswordCheck,
        archive_mod.parseOwnedHeadersAllocWithOptions(allocator, bad_check, .{
            .password = "password",
            .max_rar5_kdf_count = 1,
        }),
    );

    const bad_ciphertext = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_ciphertext);
    bad_ciphertext[file_header_offset + 16 + 16] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        archive_mod.parseOwnedHeadersAllocWithOptions(allocator, bad_ciphertext, .{
            .password = "password",
            .max_rar5_kdf_count = 1,
        }),
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        archive_mod.parseOwnedHeadersAllocWithOptions(
            allocator,
            encoded[0 .. encoded.len - 1],
            .{ .password = "password", .max_rar5_kdf_count = 1 },
        ),
    );
}

test "RAR5 encrypted headers release every allocation failure path" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const ivs = [_][16]u8{
                [_]u8{0x91} ** 16,
                [_]u8{0x92} ** 16,
                [_]u8{0x93} ** 16,
            };
            const entries = [_]writer.EncodeEntry{.{
                .name = "secret.bin",
                .data = "allocation-safe encrypted headers",
                .encryption = .{
                    .password = "password",
                    .salt = [_]u8{0x94} ** 16,
                    .iv = [_]u8{0x95} ** 16,
                    .kdf_count = 0,
                },
            }};
            const encoded = try writer.encodeAlloc(allocator, &entries, .{
                .header_encryption = .{
                    .password = "password",
                    .salt = [_]u8{0x96} ** 16,
                    .kdf_count = 0,
                    .ivs = &ivs,
                },
            });
            defer allocator.free(encoded);
            var owned = try archive_mod.parseOwnedHeadersAllocWithOptions(
                allocator,
                encoded,
                .{ .password = "password", .max_rar5_kdf_count = 0 },
            );
            defer owned.deinit();
            const decoded = try owned.archive.extractByNameAllocWithOptions(
                allocator,
                entries[0].name,
                .{ .password = "password", .max_rar5_kdf_count = 0 },
            );
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, entries[0].data, decoded);

            var volume_ivs: [18][16]u8 = undefined;
            for (&volume_ivs, 0..) |*iv, index| {
                iv.* = @splat(@intCast(index + 1));
                std.mem.writeInt(u64, iv[0..8], index, .little);
            }
            var volumes = try writer.encodeVolumesAlloc(
                allocator,
                &entries,
                .{ .header_encryption = .{
                    .password = "password",
                    .salt = [_]u8{0x97} ** 16,
                    .kdf_count = 0,
                    .ivs = &volume_ivs,
                } },
                8,
            );
            defer volumes.deinit();
            const volume_set = @import("volume_set.zig");
            var set = try volume_set.VolumeSet.parseAllocWithOptions(
                allocator,
                volumes.volumes,
                .{ .password = "password", .max_rar5_kdf_count = 0 },
            );
            defer set.deinit();
            const volume_decoded = try set.extractByNameAllocWithOptions(
                allocator,
                entries[0].name,
                .{ .password = "password", .max_rar5_kdf_count = 0 },
            );
            defer allocator.free(volume_decoded);
            try std.testing.expectEqualSlices(u8, entries[0].data, volume_decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}
