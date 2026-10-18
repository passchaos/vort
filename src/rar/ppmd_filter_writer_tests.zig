const std = @import("std");
const archive_mod = @import("archive.zig");
const ppmd_h = @import("ppmd_h.zig");
const rar29 = @import("rar29.zig");
const volume_set = @import("volume_set.zig");
const writer = @import("writer.zig");

test "RAR29 PPMd writer emits all six VM filters across blocks" {
    const allocator = std.testing.allocator;
    var payload: [8192]u8 = undefined;
    for (&payload, 0..) |*byte, index| byte.* = @truncate(index *% 53 +% index / 7);
    payload[16] = 0xe8;
    std.mem.writeInt(u32, payload[17..21], 0x1000, .little);
    payload[32] = 0xe9;
    std.mem.writeInt(u32, payload[33..37], 0x2000, .little);
    const entries = [_]writer.EncodeEntry{.{ .name = "filtered.bin", .data = &payload }};
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
            .compression = .rar29_ppmd,
            .block_size = 1024,
            .filter = filter,
            .ppmd_memory_size = 1024 * 1024,
        };
        const encoded = try writer.encodeAlloc(allocator, &entries, options);
        defer allocator.free(encoded);
        if (index == 0) {
            const duplicate = try writer.encodeAlloc(allocator, &entries, options);
            defer allocator.free(duplicate);
            try std.testing.expectEqualSlices(u8, encoded, duplicate);
        }
        const archive = try archive_mod.parse(encoded);
        const entry = try archive.entryAt(0);
        try std.testing.expectEqual(archive_mod.Method.rar29, entry.method);
        try std.testing.expect(encoded[entry.data_offset] & 0x80 != 0);
        const decoded = try archive.extractAlloc(allocator, entry);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &payload, decoded);
    }

    const raw_input = payload[0..513];
    const raw = try ppmd_h.encodeFilteredAlloc(
        allocator,
        raw_input,
        .{ .delta = 4 },
        127,
        .{ .memory_size = 1024 * 1024 },
    );
    defer allocator.free(raw);
    var raw_decoded: [raw_input.len]u8 = undefined;
    try rar29.decodeIntoWithOptions(allocator, raw, &raw_decoded, .{});
    try std.testing.expectEqualSlices(u8, raw_input, &raw_decoded);

    try std.testing.expectError(
        error.UnsupportedRarEncodeOptions,
        writer.encodeAlloc(allocator, &entries, .{
            .version = .rar4,
            .compression = .rar29_ppmd,
            .filter = .arm,
            .ppmd_memory_size = 1024 * 1024,
        }),
    );
    try std.testing.expectError(
        error.InvalidRar29FilterOptions,
        writer.encodeAlloc(allocator, &entries, .{
            .version = .rar4,
            .compression = .rar29_ppmd,
            .filter = .{ .delta = 0 },
            .ppmd_memory_size = 1024 * 1024,
        }),
    );
    try std.testing.expectError(
        error.InvalidRar29FilterOptions,
        writer.encodeAlloc(allocator, &entries, .{
            .version = .rar4,
            .compression = .rar29_ppmd,
            .block_size = 8,
            .filter = .{ .rgb = .{ .width = 12 } },
            .ppmd_memory_size = 1024 * 1024,
        }),
    );
    try std.testing.expectError(
        error.InvalidRar29FilterOptions,
        writer.encodeAlloc(allocator, &entries, .{
            .version = .rar4,
            .compression = .rar29_ppmd,
            .block_size = 0,
            .filter = .e8,
            .ppmd_memory_size = 1024 * 1024,
        }),
    );
    const empty = [_]writer.EncodeEntry{.{ .name = "empty.bin" }};
    try std.testing.expectError(
        error.InvalidRar29FilterOptions,
        writer.encodeAlloc(allocator, &empty, .{
            .version = .rar4,
            .compression = .rar29_ppmd,
            .filter = .e8,
            .ppmd_memory_size = 1024 * 1024,
        }),
    );
}

test "RAR29 PPMd filters compose with solid AES members" {
    const allocator = std.testing.allocator;
    const first = "filtered solid PPMd shared context alpha beta gamma\n" ** 96;
    const second = "filtered solid PPMd shared context alpha beta delta\n" ** 48;
    const encryption = writer.Rar4EncryptionOptions{
        .password = "filtered-secret",
        .salt = [_]u8{0x5a} ** 8,
    };
    const entries = [_]writer.EncodeEntry{
        .{ .name = "first.txt", .data = first, .rar4_encryption = encryption },
        .{ .name = "second.txt", .data = second, .rar4_encryption = encryption },
    };
    const encoded = try writer.encodeAlloc(allocator, &entries, .{
        .version = .rar4,
        .compression = .rar29_ppmd,
        .block_size = 257,
        .filter = .{ .delta = 2 },
        .solid = true,
        .ppmd_memory_size = 1024 * 1024,
    });
    defer allocator.free(encoded);
    const archive = try archive_mod.parse(encoded);
    const continuation = try archive.entryAt(1);
    try std.testing.expect(continuation.solid);
    try std.testing.expect(continuation.encrypted);
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

test "RAR29 PPMd filtered members survive arbitrary volume cuts" {
    const allocator = std.testing.allocator;
    var payload: [4096]u8 = undefined;
    for (&payload, 0..) |*byte, index| byte.* = @truncate(index *% 37 +% index / 5);
    payload[128] = 0xe8;
    std.mem.writeInt(u32, payload[129..133], 0x1234, .little);
    const entries = [_]writer.EncodeEntry{.{ .name = "filtered.bin", .data = &payload }};
    var volumes = try writer.encodeVolumesAlloc(allocator, &entries, .{
        .version = .rar4,
        .compression = .rar29_ppmd,
        .block_size = 193,
        .filter = .e8,
        .ppmd_memory_size = 1024 * 1024,
    }, 211);
    defer volumes.deinit();
    try std.testing.expect(volumes.volumes.len > 1);
    var set = try volume_set.VolumeSet.parseAlloc(allocator, volumes.volumes);
    defer set.deinit();
    const decoded = try set.extractByNameAllocLimited(
        allocator,
        "filtered.bin",
        payload.len,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
}

test "RAR29 PPMd filtered writer releases every allocation failure path" {
    const AllocationTest = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const payload = "allocation-safe PPMd filter payload\n" ** 4;
            const entries = [_]writer.EncodeEntry{.{
                .name = "filtered.txt",
                .data = payload,
            }};
            const encoded = try writer.encodeAlloc(allocator, &entries, .{
                .version = .rar4,
                .compression = .rar29_ppmd,
                .block_size = 37,
                .filter = .{ .delta = 1 },
                .ppmd_memory_size = 1024 * 1024,
            });
            defer allocator.free(encoded);
            const archive = try archive_mod.parse(encoded);
            const entry = try archive.entryAt(0);
            const decoded = try archive.extractAlloc(allocator, entry);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, payload, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        AllocationTest.run,
        .{},
    );
}
