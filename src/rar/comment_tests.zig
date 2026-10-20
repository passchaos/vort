const std = @import("std");
const archive = @import("archive.zig");
const rar5_service = @import("rar5_service.zig");
const writer = @import("writer.zig");

const official_plain_hex =
    "526172211a0701003392b5e50a0105060005010180800052462e6213030298000498000046bd739180000103434d546f6666696369616c2d636f6d6d656e742de4b896e7958c0ab49daacc3702030b9c00049c00b483022ee6290780000119636f6d6d656e745f666978747572655f696e7075742e7478740a031332f4d76aabf5d42152415220636f6d6d656e742066697874757265207061796c6f61640a1d77565103050400";

const official_encrypted_hex =
    "526172211a070100409fb0d421040000010f79a393c94b1db04d0f2e4e8f750accc3b1cdaa5afc2d3b79db642828b0749ddf40f859c9dc4eb003011823de92478edff2ebb14f7b798d25bb90fb801c6873b2238525cebac0b7f0f63e6c327e0071f46d03f008216938f68f791c713eb27fb96301827859ccdaefed7a7b9411c777e447c7ee264ea1e5210fe5f1bd4e262b28d583aea0877c37810942bda0930df12e10fa65e7beb0291908c2af587e61dcafde7b0be17fdfc7332e490c6b7765604307614c157d73d57e8dc2e0add5e38a9fcd2b5314e95c21931f37d8ec17cdba01c5aef7c2c93727b03b0c56bfb7f8b88a47ff41052c00bdc373b1e7e1b3578b3c66c39b17e27757e479b359a1d9f09249d962f23bf1ccb6b2adda867a8a168b19dd6a580fe3388afd770f6b2e346a2455fa5251a7d6a788bae781ecb966bbc1c9f1d87c5c429878812a6518d5b8e69063ffdde3fa3c28445220aa510b5a360fea37f8593e2e4e595842d7aff6116636dd534fbc44d88ca9c395ab8cc33c74ad517d028f33e43f6ec148879999";

fn referenceBytes(comptime hex: []const u8) [hex.len / 2]u8 {
    var bytes: [hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, hex) catch unreachable;
    return bytes;
}

test "RAR5 reads RAR 7.12 archive comments with plain and encrypted headers" {
    const allocator = std.testing.allocator;
    const plain = referenceBytes(official_plain_hex);
    const parsed = try archive.parse(&plain);
    try std.testing.expect(parsed.hasComment());
    try std.testing.expect(!parsed.comment_encrypted);
    try std.testing.expectEqualSlices(u8, "official-comment-世界\n", parsed.comment.?);
    try std.testing.expectEqual(@as(usize, 1), parsed.entry_count);

    const encrypted = referenceBytes(official_encrypted_hex);
    try std.testing.expectError(error.EncryptedRarHeaders, archive.parse(&encrypted));
    try std.testing.expectError(
        error.InvalidRarPassword,
        archive.parseOwnedHeadersAllocWithOptions(allocator, &encrypted, .{
            .password = "wrong",
        }),
    );
    var owned = try archive.parseOwnedHeadersAllocWithOptions(
        allocator,
        &encrypted,
        .{ .password = "comment-password" },
    );
    defer owned.deinit();
    try std.testing.expect(owned.archive.hasComment());
    try std.testing.expect(owned.archive.comment_encrypted);
    try std.testing.expectEqualSlices(
        u8,
        "Reference comment 世界",
        owned.archive.comment.?,
    );
    try std.testing.expect(
        (try owned.archive.entryAt(0)).name.eql("comment_fixture_input.txt"),
    );
}

test "RAR5 comment writer round trips plain and data-encrypted CMT blocks" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{
        .name = "payload.txt",
        .data = "comment payload",
    }};
    const comment = "Vort archive comment 世界";

    const plain = try writer.encodeAlloc(allocator, &entries, .{ .comment = comment });
    defer allocator.free(plain);
    const second = try writer.encodeAlloc(allocator, &entries, .{ .comment = comment });
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, plain, second);
    const parsed = try archive.parse(plain);
    try std.testing.expectEqualSlices(u8, comment, parsed.comment.?);
    try std.testing.expect(!parsed.comment_encrypted);
    var copied = try archive.parseOwnedHeadersAllocWithOptions(allocator, plain, .{});
    defer copied.deinit();
    try std.testing.expectEqualSlices(u8, comment, copied.comment.?);
    try std.testing.expectEqualSlices(u8, comment, copied.archive.comment.?);
    try std.testing.expectError(
        error.RarMetadataLimitExceeded,
        archive.parseOwnedHeadersAllocWithOptions(allocator, plain, .{
            .max_metadata_size = comment.len - 1,
        }),
    );

    const encrypted_options = writer.EncodeOptions{
        .comment = comment,
        .comment_encryption = .{
            .password = "comment password",
            .salt = [_]u8{0x31} ** 16,
            .iv = [_]u8{0x41} ** 16,
            .kdf_count = 0,
        },
    };
    const encrypted = try writer.encodeAlloc(allocator, &entries, encrypted_options);
    defer allocator.free(encrypted);
    const encrypted_view = try archive.parse(encrypted);
    try std.testing.expect(encrypted_view.comment == null);
    try std.testing.expect(encrypted_view.comment_encrypted);
    try std.testing.expectError(
        error.RarPasswordRequired,
        archive.parseOwnedHeadersAllocWithOptions(allocator, encrypted, .{}),
    );
    var decrypted = try archive.parseOwnedHeadersAllocWithOptions(
        allocator,
        encrypted,
        .{ .password = "comment password", .max_rar5_kdf_count = 0 },
    );
    defer decrypted.deinit();
    try std.testing.expect(decrypted.archive.comment_encrypted);
    try std.testing.expectEqualSlices(u8, comment, decrypted.archive.comment.?);
}

test "RAR5 comment composes with encrypted headers and Vail file crypto" {
    const allocator = std.testing.allocator;
    const password = "hidden comment password";
    const comment = "hidden archive comment 世界";
    const header_ivs = [_][16]u8{
        [_]u8{0x11} ** 16,
        [_]u8{0x12} ** 16,
        [_]u8{0x13} ** 16,
        [_]u8{0x14} ** 16,
    };
    const entries = [_]writer.EncodeEntry{.{
        .name = "secret.txt",
        .data = "secret payload",
        .encryption = .{
            .password = password,
            .salt = [_]u8{0x21} ** 16,
            .iv = [_]u8{0x22} ** 16,
            .kdf_count = 0,
        },
    }};
    const encoded = try writer.encodeAlloc(allocator, &entries, .{
        .comment = comment,
        .comment_encryption = .{
            .password = password,
            .salt = [_]u8{0x31} ** 16,
            .iv = [_]u8{0x32} ** 16,
            .kdf_count = 0,
        },
        .header_encryption = .{
            .password = password,
            .salt = [_]u8{0x41} ** 16,
            .kdf_count = 0,
            .ivs = &header_ivs,
        },
    });
    defer allocator.free(encoded);
    try std.testing.expect(std.mem.indexOf(u8, encoded, comment) == null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, entries[0].name) == null);
    var owned = try archive.parseOwnedHeadersAllocWithOptions(
        allocator,
        encoded,
        .{ .password = password, .max_rar5_kdf_count = 0 },
    );
    defer owned.deinit();
    try std.testing.expect(owned.archive.comment_encrypted);
    try std.testing.expectEqualSlices(u8, comment, owned.archive.comment.?);
    const payload = try owned.archive.extractByNameAllocWithOptions(
        allocator,
        entries[0].name,
        .{ .password = password, .max_rar5_kdf_count = 0 },
    );
    defer allocator.free(payload);
    try std.testing.expectEqualSlices(u8, entries[0].data, payload);
}

test "RAR5 comment writer validates text size encryption and header IV policy" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{};
    try std.testing.expectError(
        error.InvalidRarComment,
        writer.encodeAlloc(allocator, &entries, .{ .comment = "bad\x00comment" }),
    );
    try std.testing.expectError(
        error.InvalidRarComment,
        writer.encodeAlloc(allocator, &entries, .{ .comment = "\xff" }),
    );
    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        writer.encodeAlloc(allocator, &entries, .{
            .version = .rar4,
            .comment = "RAR5 only",
        }),
    );
    const orphan_encryption = writer.EncryptionOptions{
        .password = "password",
        .salt = [_]u8{1} ** 16,
        .iv = [_]u8{2} ** 16,
        .kdf_count = 0,
    };
    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        writer.encodeAlloc(allocator, &entries, .{
            .comment_encryption = orphan_encryption,
        }),
    );
    const oversized = try allocator.alloc(u8, rar5_service.max_writer_comment_size + 1);
    defer allocator.free(oversized);
    @memset(oversized, 'x');
    try std.testing.expectError(
        error.RarCommentTooLarge,
        writer.encodeAlloc(allocator, &entries, .{ .comment = oversized }),
    );

    const short_ivs = [_][16]u8{
        [_]u8{3} ** 16,
        [_]u8{4} ** 16,
    };
    try std.testing.expectError(
        error.InvalidRarHeaderEncryption,
        writer.encodeAlloc(allocator, &entries, .{
            .comment = "hidden",
            .header_encryption = .{
                .password = "password",
                .salt = [_]u8{5} ** 16,
                .kdf_count = 0,
                .ivs = &short_ivs,
            },
        }),
    );
}

test "RAR5 parser rejects duplicate late and corrupt archive comments" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = "data" }};
    const comment = "placement-check";
    const commented = try writer.encodeAlloc(allocator, &entries, .{ .comment = comment });
    defer allocator.free(commented);
    const parsed_commented = try archive.parse(commented);
    const commented_entry = try parsed_commented.entryAt(0);
    const comment_start = parsed_commented.entries_offset;
    const comment_end = commented_entry.header_offset;

    var duplicate: std.ArrayList(u8) = .empty;
    defer duplicate.deinit(allocator);
    try duplicate.appendSlice(allocator, commented[0..comment_end]);
    try duplicate.appendSlice(allocator, commented[comment_start..comment_end]);
    try duplicate.appendSlice(allocator, commented[comment_end..]);
    try std.testing.expectError(error.InvalidRarArchive, archive.parse(duplicate.items));

    const plain = try writer.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(plain);
    const parsed_plain = try archive.parse(plain);
    const plain_entry = try parsed_plain.entryAt(0);
    var late: std.ArrayList(u8) = .empty;
    defer late.deinit(allocator);
    try late.appendSlice(allocator, plain[0..plain_entry.next_offset]);
    try late.appendSlice(allocator, commented[comment_start..comment_end]);
    try late.appendSlice(allocator, plain[plain_entry.next_offset..]);
    try std.testing.expectError(error.InvalidRarArchive, archive.parse(late.items));

    const corrupt = try allocator.dupe(u8, commented);
    defer allocator.free(corrupt);
    const comment_offset = std.mem.indexOf(u8, corrupt, comment) orelse unreachable;
    corrupt[comment_offset] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, archive.parse(corrupt));
}

test "RAR5 comments preserve empty values and encrypted multi-volume metadata" {
    const allocator = std.testing.allocator;
    const no_entries = [_]writer.EncodeEntry{};
    const empty = try writer.encodeAlloc(allocator, &no_entries, .{ .comment = "" });
    defer allocator.free(empty);
    const empty_archive = try archive.parse(empty);
    try std.testing.expect(empty_archive.hasComment());
    try std.testing.expectEqual(@as(usize, 0), empty_archive.comment.?.len);

    const oversized_comment = "comment-outside-file-payload-budget\n" ** 4;
    var comment_only_volumes = try writer.encodeVolumesAlloc(
        allocator,
        &no_entries,
        .{ .comment = oversized_comment },
        16,
    );
    defer comment_only_volumes.deinit();
    try std.testing.expectEqual(@as(usize, 1), comment_only_volumes.volumes.len);
    const comment_only = try archive.parse(comment_only_volumes.volumes[0]);
    try std.testing.expectEqualSlices(u8, oversized_comment, comment_only.comment.?);

    const volume_set = @import("volume_set.zig");
    const password = "volume comment password";
    const comment = "volume comment 世界" ** 8;
    const payload = "0123456789abcdef" ** 12;
    const entries = [_]writer.EncodeEntry{.{
        .name = "split.bin",
        .data = payload,
        .encryption = .{
            .password = password,
            .salt = [_]u8{0x51} ** 16,
            .iv = [_]u8{0x52} ** 16,
            .kdf_count = 0,
        },
    }};
    var options = writer.EncodeOptions{
        .comment = comment,
        .comment_encryption = .{
            .password = password,
            .salt = [_]u8{0x61} ** 16,
            .iv = [_]u8{0x62} ** 16,
            .kdf_count = 0,
        },
    };
    const budget = 64;
    var baseline = try writer.encodeVolumesAlloc(allocator, &entries, options, budget);
    defer baseline.deinit();
    const baseline_first = try archive.parse(baseline.volumes[0]);
    try std.testing.expectEqual(budget, (try baseline_first.entryAt(0)).compressed_size);
    var fragment_count: usize = 0;
    for (baseline.volumes) |volume|
        fragment_count += (try archive.parse(volume)).entry_count;
    const iv_count = 2 * baseline.volumes.len + fragment_count + 1;
    const header_ivs = try allocator.alloc([16]u8, iv_count);
    defer allocator.free(header_ivs);
    for (header_ivs, 0..) |*iv, index| {
        iv.* = @splat(@intCast(index + 1));
        std.mem.writeInt(u64, iv[0..8], index, .little);
    }
    options.header_encryption = .{
        .password = password,
        .salt = [_]u8{0x71} ** 16,
        .kdf_count = 0,
        .ivs = header_ivs,
    };
    var volumes = try writer.encodeVolumesAlloc(allocator, &entries, options, budget);
    defer volumes.deinit();
    var set = try volume_set.VolumeSet.parseAllocWithOptions(
        allocator,
        volumes.volumes,
        .{ .password = password, .max_rar5_kdf_count = 0 },
    );
    defer set.deinit();
    try std.testing.expectEqualSlices(u8, comment, set.archives[0].archive.comment.?);
    try std.testing.expect(set.archives[0].archive.comment_encrypted);
    try std.testing.expectEqual(
        budget,
        (try set.archives[0].archive.entryAt(0)).compressed_size,
    );
    for (set.archives[1..]) |owned|
        try std.testing.expect(!owned.archive.hasComment());
    const decoded = try set.extractByNameAllocWithOptions(
        allocator,
        entries[0].name,
        .{ .password = password, .max_rar5_kdf_count = 0 },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}
