const std = @import("std");
const archive_mod = @import("archive.zig");
const checksum = @import("../checksum.zig");
const legacy_crypto = @import("vail_archive_crypto").rar_legacy;

test "RAR15 encrypted member decodes a RAR 1.54 archive" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(allocator, @embedFile("testdata/rar15-encrypted.rar.b64"));
    defer allocator.free(bytes);
    const archive = try archive_mod.parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expectEqual(archive_mod.Method.rar15, entry.method);
    try std.testing.expect(entry.encrypted);
    try std.testing.expectEqual(.rar15, entry.rar4_encryption.?.method);
    try std.testing.expect(entry.rar4_encryption.?.salt == null);
    try std.testing.expectError(
        error.RarPasswordRequired,
        archive.extractAlloc(allocator, entry),
    );

    const output = try archive.extractByNameAllocWithOptions(
        allocator,
        "README.md",
        .{ .max_output_len = 4198, .password = "password" },
    );
    defer allocator.free(output);
    try std.testing.expectEqual(@as(usize, 4198), output.len);
    try expectSha256(output, "f3d51f2d627fdb20b876e61f9e7772d7b8bf869ca03aeea49d8a9b3153de6eff");
    try std.testing.expectError(
        error.InvalidRar15Stream,
        archive.extractByNameAllocWithOptions(
            allocator,
            "README.md",
            .{ .max_output_len = 4198, .password = "wrong" },
        ),
    );
}

test "RAR20 encrypted members decode a WinRAR 2.02 archive" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(allocator, @embedFile("testdata/rar20-encrypted.rar.b64"));
    defer allocator.free(bytes);
    const archive = try archive_mod.parse(bytes);
    try std.testing.expectEqual(@as(usize, 2), archive.entry_count);
    const first = try archive.entryAt(0);
    const second = try archive.entryAt(1);
    for ([_]archive_mod.Entry{ first, second }) |entry| {
        try std.testing.expectEqual(archive_mod.Method.rar20, entry.method);
        try std.testing.expect(entry.encrypted);
        try std.testing.expectEqual(.rar20, entry.rar4_encryption.?.method);
        try std.testing.expect(entry.rar4_encryption.?.salt == null);
    }

    const first_output = try archive.extractByNameAllocWithOptions(
        allocator,
        "FILE1.TXT",
        .{ .max_output_len = 7, .password = "password" },
    );
    defer allocator.free(first_output);
    try std.testing.expectEqualStrings("file1\r\n", first_output);
    const second_output = try archive.extractByNameAllocWithOptions(
        allocator,
        "FILE2.TXT",
        .{ .max_output_len = 7, .password = "password" },
    );
    defer allocator.free(second_output);
    try std.testing.expectEqualStrings("file2\r\n", second_output);
    try std.testing.expectError(
        error.InvalidRar20Stream,
        archive.extractByNameAllocWithOptions(
            allocator,
            "FILE1.TXT",
            .{ .max_output_len = 7, .password = "wrong" },
        ),
    );
}

test "legacy RAR encrypted extraction releases every allocation failure path" {
    const AllocationTest = struct {
        fn run(allocator: std.mem.Allocator, rar15_bytes: []const u8, rar20_bytes: []const u8) !void {
            const rar15_archive = try archive_mod.parse(rar15_bytes);
            const rar15_output = try rar15_archive.extractByNameAllocWithOptions(
                allocator,
                "README.md",
                .{ .max_output_len = 4198, .password = "password" },
            );
            defer allocator.free(rar15_output);
            try expectSha256(rar15_output, "f3d51f2d627fdb20b876e61f9e7772d7b8bf869ca03aeea49d8a9b3153de6eff");

            const rar20_archive = try archive_mod.parse(rar20_bytes);
            const rar20_output = try rar20_archive.extractByNameAllocWithOptions(
                allocator,
                "FILE2.TXT",
                .{ .max_output_len = 7, .password = "password" },
            );
            defer allocator.free(rar20_output);
            try std.testing.expectEqualStrings("file2\r\n", rar20_output);
        }
    };
    const rar15_bytes = try fixtureAlloc(
        std.testing.allocator,
        @embedFile("testdata/rar15-encrypted.rar.b64"),
    );
    defer std.testing.allocator.free(rar15_bytes);
    const rar20_bytes = try fixtureAlloc(
        std.testing.allocator,
        @embedFile("testdata/rar20-encrypted.rar.b64"),
    );
    defer std.testing.allocator.free(rar20_bytes);
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        AllocationTest.run,
        .{ rar15_bytes, rar20_bytes },
    );
}

test "legacy RAR encrypted members retain solid decoder state" {
    const allocator = std.testing.allocator;

    const rar15_clear = try fixtureAlloc(
        allocator,
        @embedFile("testdata/rar15-solid.rar.b64"),
    );
    defer allocator.free(rar15_clear);
    const rar15_encrypted = try encryptLegacyArchiveAlloc(allocator, rar15_clear, "password");
    defer allocator.free(rar15_encrypted);
    const rar15_archive = try archive_mod.parse(rar15_encrypted);
    const rar15_output = try rar15_archive.extractByNameAllocWithOptions(
        allocator,
        "b.txt",
        .{ .max_output_len = 4096, .password = "password" },
    );
    defer allocator.free(rar15_output);
    try expectSha256(rar15_output, "b67d4a6c25ae43db95a1113fb854eb30de44f6dcc4c735e35f0c321d668cdf57");

    const rar20_clear = try fixtureAlloc(
        allocator,
        @embedFile("testdata/rar20-solid.rar.b64"),
    );
    defer allocator.free(rar20_clear);
    const rar20_encrypted = try encryptLegacyArchiveAlloc(allocator, rar20_clear, "password");
    defer allocator.free(rar20_encrypted);
    const rar20_archive = try archive_mod.parse(rar20_encrypted);
    const rar20_output = try rar20_archive.extractByNameAllocWithOptions(
        allocator,
        "SOLID2.TXT",
        .{ .max_output_len = 32 * 1024, .password = "password" },
    );
    defer allocator.free(rar20_output);
    try expectSha256(rar20_output, "548a9e748a8a7ced5c4872a87a4e47e12902c9f1f634e21952a7424b0b67a209");
}

fn fixtureAlloc(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(u8, decoder.calcSizeUpperBound(encoded.len));
    errdefer allocator.free(bytes);
    const written = try decoder.decode(bytes, encoded);
    return allocator.realloc(bytes, written);
}

fn expectSha256(bytes: []const u8, expected_text: []const u8) !void {
    var actual: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &actual, .{});
    var expected: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, expected_text);
    try std.testing.expectEqual(expected, actual);
}

fn encryptLegacyArchiveAlloc(
    allocator: std.mem.Allocator,
    source: []const u8,
    password: []const u8,
) ![]u8 {
    const parsed = try archive_mod.parse(source);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var cursor: usize = 0;
    var iterator = parsed.iterator();
    while (try iterator.next()) |entry| {
        try output.appendSlice(allocator, source[cursor..entry.header_offset]);
        const header_start = output.items.len;
        try output.appendSlice(
            allocator,
            source[entry.header_offset..entry.data_offset],
        );

        var encrypted = try allocator.dupe(
            u8,
            source[entry.data_offset..][0..entry.compressed_size],
        );
        defer {
            std.crypto.secureZero(u8, encrypted);
            allocator.free(encrypted);
        }
        switch (entry.method) {
            .rar15 => {
                var cipher = legacy_crypto.Rar15.init(password);
                defer cipher.deinit();
                cipher.crypt(encrypted);
            },
            .rar20 => {
                const padded_len = std.mem.alignForward(
                    usize,
                    encrypted.len,
                    legacy_crypto.block_len,
                );
                encrypted = try allocator.realloc(encrypted, padded_len);
                @memset(encrypted[entry.compressed_size..], 0);
                var cipher = legacy_crypto.Rar20.init(password);
                defer cipher.deinit();
                try cipher.encryptBlocks(encrypted);
            },
            else => return error.UnsupportedRarCompression,
        }

        const header = output.items[header_start..];
        const flags = std.mem.readInt(u16, header[3..5], .little) | 0x0004;
        std.mem.writeInt(u16, header[3..5], flags, .little);
        std.mem.writeInt(u32, header[7..11], @intCast(encrypted.len), .little);
        const header_crc: u16 = @truncate(checksum.crc32(header[2..]));
        std.mem.writeInt(u16, header[0..2], header_crc, .little);
        try output.appendSlice(allocator, encrypted);
        cursor = entry.next_offset;
    }
    try output.appendSlice(allocator, source[cursor..]);
    return output.toOwnedSlice(allocator);
}
