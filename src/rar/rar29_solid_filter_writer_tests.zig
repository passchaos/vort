const std = @import("std");
const archive_mod = @import("archive.zig");
const volume_set = @import("volume_set.zig");
const writer = @import("writer.zig");

test "RAR29 LZ writer carries all six VM filters across solid members" {
    const allocator = std.testing.allocator;
    var first: [8192]u8 = undefined;
    var second: [4096]u8 = undefined;
    for (&first, 0..) |*byte, index| byte.* = @truncate(index *% 53 +% index / 7);
    for (&second, 0..) |*byte, index| byte.* = first[2048 + index] ^ @as(u8, @truncate(index / 257));
    first[16] = 0xe8;
    std.mem.writeInt(u32, first[17..21], 0x1000, .little);
    second[32] = 0xe9;
    std.mem.writeInt(u32, second[33..37], 0x2000, .little);
    const entries = [_]writer.EncodeEntry{
        .{ .name = "first.bin", .data = &first },
        .{ .name = "second.bin", .data = &second },
    };
    const filters = [_]writer.Filter{
        .{ .delta = 4 },
        .e8,
        .e8e9,
        .itanium,
        .{ .rgb = .{ .width = 12, .red_position = 1 } },
        .{ .audio = 2 },
    };
    for (filters, 0..) |filter, index| {
        const options = writer.EncodeOptions{
            .version = .rar4,
            .compression = .rar29,
            .dictionary_size = 128 * 1024,
            .block_size = 1024,
            .filter = filter,
            .solid = true,
        };
        const encoded = try writer.encodeAlloc(allocator, &entries, options);
        defer allocator.free(encoded);
        if (index == 0) {
            const duplicate = try writer.encodeAlloc(allocator, &entries, options);
            defer allocator.free(duplicate);
            try std.testing.expectEqualSlices(u8, encoded, duplicate);
        }
        const archive = try archive_mod.parse(encoded);
        const continuation = try archive.entryAt(1);
        try std.testing.expect(continuation.solid);
        try std.testing.expectError(
            error.UnsupportedRarFeature,
            archive.extractAlloc(allocator, continuation),
        );
        const decoded = try archive.extractByNameAllocLimited(
            allocator,
            "second.bin",
            first.len,
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &second, decoded);
    }
}

test "RAR29 filtered solid members compose with RAR4 AES" {
    const allocator = std.testing.allocator;
    const first = "RAR29 filtered encrypted solid phrase alpha beta gamma\n" ** 96;
    const second = "RAR29 filtered encrypted solid phrase alpha beta delta\n" ** 48;
    const encryption = writer.Rar4EncryptionOptions{
        .password = "filtered-solid-secret",
        .salt = [_]u8{0x6b} ** 8,
    };
    const entries = [_]writer.EncodeEntry{
        .{ .name = "first.txt", .data = first, .rar4_encryption = encryption },
        .{ .name = "second.txt", .data = second, .rar4_encryption = encryption },
    };
    const encoded = try writer.encodeAlloc(allocator, &entries, .{
        .version = .rar4,
        .compression = .rar29,
        .block_size = 257,
        .filter = .{ .delta = 2 },
        .solid = true,
    });
    defer allocator.free(encoded);
    const archive = try archive_mod.parse(encoded);
    try std.testing.expectError(
        error.RarPasswordRequired,
        archive.extractByNameAllocLimited(allocator, "second.txt", first.len),
    );
    const decoded = try archive.extractByNameAllocWithOptions(
        allocator,
        "second.txt",
        .{ .max_output_len = first.len, .password = encryption.password },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, second, decoded);
}

test "RAR29 filtered solid history survives volume boundaries" {
    const allocator = std.testing.allocator;
    var first: [4096]u8 = undefined;
    for (&first, 0..) |*byte, index| byte.* = @truncate(index *% 37 +% index / 5);
    first[128] = 0xe8;
    std.mem.writeInt(u32, first[129..133], 0x1234, .little);
    var second = first[1024..3072].*;
    second[64] = 0xe8;
    std.mem.writeInt(u32, second[65..69], 0x4321, .little);
    const entries = [_]writer.EncodeEntry{
        .{ .name = "first.bin", .data = &first },
        .{ .name = "second.bin", .data = &second },
    };
    var volumes = try writer.encodeVolumesAlloc(allocator, &entries, .{
        .version = .rar4,
        .compression = .rar29,
        .block_size = 193,
        .filter = .e8,
        .solid = true,
    }, 211);
    defer volumes.deinit();
    try std.testing.expect(volumes.volumes.len > 2);
    var set = try volume_set.VolumeSet.parseAlloc(allocator, volumes.volumes);
    defer set.deinit();
    try std.testing.expectEqual(@as(usize, 2), set.entries.len);
    try std.testing.expect(set.entries[1].solid);
    const decoded = try set.extractByNameAllocLimited(
        allocator,
        "second.bin",
        first.len,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &second, decoded);
}

test "RAR29 filtered solid writer releases every allocation failure path" {
    const AllocationTest = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const first = "allocation-safe filtered solid first\n" ** 8;
            const second = "allocation-safe filtered solid second\n" ** 4;
            const entries = [_]writer.EncodeEntry{
                .{ .name = "first.txt", .data = first },
                .{ .name = "second.txt", .data = second },
            };
            const encoded = try writer.encodeAlloc(allocator, &entries, .{
                .version = .rar4,
                .compression = .rar29,
                .block_size = 37,
                .filter = .{ .delta = 1 },
                .solid = true,
            });
            defer allocator.free(encoded);
            const archive = try archive_mod.parse(encoded);
            const decoded = try archive.extractByNameAllocLimited(
                allocator,
                "second.txt",
                first.len,
            );
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, second, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        AllocationTest.run,
        .{},
    );
}
