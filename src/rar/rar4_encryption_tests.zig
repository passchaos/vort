const std = @import("std");
const archive_mod = @import("archive.zig");
const writer = @import("writer.zig");

const data_archive_hex =
    "526172211a0700cf907300000d000000000000009cc67424943700300000002c0000000376354b8e593c515d1d300a00b48100007365637265742e74787461b5" ++
    "b2f3aaf9905a00f06ac172eebf22196e74abddb1dc10081e09e516fbc339b7d73fd49d791ada55a777b15c1f98466fa76c43b1b44f2f774b266716c43d7b0040" ++
    "0700";

const header_archive_hex =
    "526172211a0700ce997380000d000000000000009c5c742c710cf4268b219049fc4bf32a1f09891363f022e223cf8b706d5300906e5af95fb9851116ed22d153" ++
    "3722222a608b898cc7c75e4c257f4ef517c4544f9947e2ed2ade3bb5236748ad4aeb8948c558abc8e4d2beb3c270a7eec87c58250ffa288256ec453b6004751c" ++
    "6ebc4b2a01f9181423f39c659c5c742c710cf426a8e0267f3a7e0a380ef5ab84eabfe82f";

fn dataArchiveBytes() [data_archive_hex.len / 2]u8 {
    var bytes: [data_archive_hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, data_archive_hex) catch unreachable;
    return bytes;
}

fn headerArchiveBytes() [header_archive_hex.len / 2]u8 {
    var bytes: [header_archive_hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, header_archive_hex) catch unreachable;
    return bytes;
}

test "RAR4 encrypted Stored data decodes a RAR 6.21 archive" {
    const allocator = std.testing.allocator;
    const bytes = dataArchiveBytes();
    const archive = try archive_mod.parse(&bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expect(entry.encrypted);
    try std.testing.expect(entry.rar4_encryption != null);
    try std.testing.expectEqualSlices(
        u8,
        &.{ 0x61, 0xb5, 0xb2, 0xf3, 0xaa, 0xf9, 0x90, 0x5a },
        &entry.rar4_encryption.?.salt.?,
    );
    try std.testing.expectError(
        error.RarPasswordRequired,
        archive.extractAllocWithOptions(allocator, entry, .{}),
    );
    try std.testing.expectError(
        error.ChecksumMismatch,
        archive.extractAllocWithOptions(allocator, entry, .{
            .password = "wrong password",
        }),
    );
    const decoded = try archive.extractAllocWithOptions(allocator, entry, .{
        .password = "RAR4-password",
    });
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(
        u8,
        "RAR4 encrypted payload reference 0123456789\n",
        decoded,
    );
}

test "RAR4 encrypted headers decode a RAR 6.21 archive" {
    const allocator = std.testing.allocator;
    const bytes = headerArchiveBytes();
    try std.testing.expectError(error.EncryptedRarHeaders, archive_mod.parse(&bytes));
    try std.testing.expectError(
        error.RarPasswordRequired,
        archive_mod.parseOwnedHeadersAllocWithOptions(allocator, &bytes, .{}),
    );
    var owned = try archive_mod.parseOwnedHeadersAllocWithOptions(
        allocator,
        &bytes,
        .{ .password = "RAR4-password" },
    );
    defer owned.deinit();
    try std.testing.expect(owned.archive.rar4_encrypted_headers);
    const entry = try owned.archive.entryAt(0);
    try std.testing.expect(entry.name.eql("secret.txt"));
    try std.testing.expect(entry.encrypted);
    try std.testing.expectEqualSlices(
        u8,
        &.{ 0x9c, 0x5c, 0x74, 0x2c, 0x71, 0x0c, 0xf4, 0x26 },
        &entry.rar4_encryption.?.salt.?,
    );
    const decoded = try owned.archive.extractByNameAllocWithOptions(
        allocator,
        "secret.txt",
        .{ .password = "RAR4-password" },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(
        u8,
        "RAR4 encrypted payload reference 0123456789\n",
        decoded,
    );
}

test "RAR4 encrypted headers reject wrong passwords corruption and truncation" {
    const allocator = std.testing.allocator;
    const bytes = headerArchiveBytes();
    try std.testing.expectError(
        error.TruncatedFrame,
        archive_mod.parseOwnedHeadersAllocWithOptions(allocator, &bytes, .{
            .password = "wrong password",
        }),
    );
    var corrupt = bytes;
    corrupt[20 + 8 + 16] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        archive_mod.parseOwnedHeadersAllocWithOptions(allocator, &corrupt, .{
            .password = "RAR4-password",
        }),
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        archive_mod.parseOwnedHeadersAllocWithOptions(
            allocator,
            bytes[0 .. bytes.len - 1],
            .{ .password = "RAR4-password" },
        ),
    );
}

test "RAR4 encrypted Stored RAR29 and PPMd writers round trip" {
    const allocator = std.testing.allocator;
    const payload = "RAR4 encrypted writer payload alpha beta gamma\n" ** 57;
    const entries = [_]writer.EncodeEntry{.{
        .name = "secret.bin",
        .data = payload,
        .rar4_encryption = .{
            .password = "RAR4 writer 密码",
            .salt = .{ 0, 1, 2, 3, 4, 5, 6, 7 },
        },
    }};
    inline for (.{
        writer.Compression.stored,
        writer.Compression.rar29,
        writer.Compression.rar29_ppmd,
    }) |compression| {
        const encoded = try writer.encodeAlloc(allocator, &entries, .{
            .version = .rar4,
            .compression = compression,
            .ppmd_memory_size = 1024 * 1024,
        });
        defer allocator.free(encoded);
        const archive = try archive_mod.parse(encoded);
        const entry = try archive.entryAt(0);
        try std.testing.expect(entry.encrypted);
        try std.testing.expectEqual(@as(usize, 0), entry.compressed_size % 16);
        const decoded = try archive.extractAllocWithOptions(allocator, entry, .{
            .password = "RAR4 writer 密码",
        });
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}

test "RAR4 encrypted header writer composes with encrypted data" {
    const allocator = std.testing.allocator;
    const payload = "RAR4 encrypted header writer payload\n" ** 43;
    const salt = [_]u8{ 7, 6, 5, 4, 3, 2, 1, 0 };
    const entries = [_]writer.EncodeEntry{.{
        .name = "hidden/secret.bin",
        .data = payload,
        .rar4_encryption = .{
            .password = "RAR4 hidden 密码",
            .salt = salt,
        },
    }};
    inline for (.{ writer.Compression.stored, writer.Compression.rar29 }) |compression| {
        const encoded = try writer.encodeAlloc(allocator, &entries, .{
            .version = .rar4,
            .compression = compression,
            .rar4_header_encryption = .{
                .password = "RAR4 hidden 密码",
                .salt = salt,
            },
        });
        defer allocator.free(encoded);
        try std.testing.expect(std.mem.indexOf(u8, encoded, entries[0].name) == null);
        try std.testing.expectError(error.EncryptedRarHeaders, archive_mod.parse(encoded));
        var owned = try archive_mod.parseOwnedHeadersAllocWithOptions(
            allocator,
            encoded,
            .{ .password = "RAR4 hidden 密码" },
        );
        defer owned.deinit();
        try std.testing.expect(owned.archive.rar4_encrypted_headers);
        const decoded = try owned.archive.extractByNameAllocWithOptions(
            allocator,
            entries[0].name,
            .{ .password = "RAR4 hidden 密码" },
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}

test "RAR4 encrypted headers and solid data compose across volumes" {
    const volume_set = @import("volume_set.zig");
    const allocator = std.testing.allocator;
    var payload: [2048]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x7261_7234_766f_6c73);
    random.fill(&payload);
    const salt = [_]u8{0x5a} ** 8;
    const entries = [_]writer.EncodeEntry{
        .{
            .name = "first.bin",
            .data = &payload,
            .rar4_encryption = .{ .password = "RAR4 volumes", .salt = salt },
        },
        .{
            .name = "second.bin",
            .data = &payload,
            .rar4_encryption = .{ .password = "RAR4 volumes", .salt = salt },
        },
    };
    var volumes = try writer.encodeVolumesAlloc(allocator, &entries, .{
        .version = .rar4,
        .compression = .rar29,
        .solid = true,
        .rar4_header_encryption = .{
            .password = "RAR4 volumes",
            .salt = salt,
        },
    }, 512);
    defer volumes.deinit();
    try std.testing.expect(volumes.volumes.len > 1);
    var set = try volume_set.VolumeSet.parseAllocWithOptions(
        allocator,
        volumes.volumes,
        .{ .password = "RAR4 volumes" },
    );
    defer set.deinit();
    const decoded = try set.extractByNameAllocWithOptions(
        allocator,
        "second.bin",
        .{ .password = "RAR4 volumes" },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
}

test "RAR4 unsalted encryption round trips and releases all allocation failures" {
    const allocator = std.testing.allocator;
    const unsalted_entries = [_]writer.EncodeEntry{.{
        .name = "unsalted.bin",
        .data = "legacy unsalted RAR4 encryption",
        .rar4_encryption = .{ .password = "unsalted", .salt = null },
    }};
    const unsalted = try writer.encodeAlloc(allocator, &unsalted_entries, .{
        .version = .rar4,
    });
    defer allocator.free(unsalted);
    const unsalted_archive = try archive_mod.parse(unsalted);
    const unsalted_entry = try unsalted_archive.entryAt(0);
    try std.testing.expect(unsalted_entry.rar4_encryption.?.salt == null);
    const unsalted_decoded = try unsalted_archive.extractAllocWithOptions(
        allocator,
        unsalted_entry,
        .{ .password = "unsalted" },
    );
    defer allocator.free(unsalted_decoded);
    try std.testing.expectEqualSlices(u8, unsalted_entries[0].data, unsalted_decoded);

    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator) !void {
            const volume_set = @import("volume_set.zig");
            const salt = [_]u8{0x77} ** 8;
            const entries = [_]writer.EncodeEntry{.{
                .name = "secret.bin",
                .data = "allocation-safe RAR4 secret",
                .rar4_encryption = .{ .password = "password", .salt = salt },
            }};
            const options = writer.EncodeOptions{
                .version = .rar4,
                .rar4_header_encryption = .{ .password = "password", .salt = salt },
            };
            const encoded = try writer.encodeAlloc(failing_allocator, &entries, options);
            defer failing_allocator.free(encoded);
            var owned = try archive_mod.parseOwnedHeadersAllocWithOptions(
                failing_allocator,
                encoded,
                .{ .password = "password" },
            );
            defer owned.deinit();
            const decoded = try owned.archive.extractByNameAllocWithOptions(
                failing_allocator,
                entries[0].name,
                .{ .password = "password" },
            );
            defer failing_allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, entries[0].data, decoded);

            var volumes = try writer.encodeVolumesAlloc(
                failing_allocator,
                &entries,
                options,
                8,
            );
            defer volumes.deinit();
            var set = try volume_set.VolumeSet.parseAllocWithOptions(
                failing_allocator,
                volumes.volumes,
                .{ .password = "password" },
            );
            defer set.deinit();
            const volume_decoded = try set.extractByNameAllocWithOptions(
                failing_allocator,
                entries[0].name,
                .{ .password = "password" },
            );
            defer failing_allocator.free(volume_decoded);
            try std.testing.expectEqualSlices(u8, entries[0].data, volume_decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}
