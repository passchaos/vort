const std = @import("std");
const volume_set = @import("volume_set.zig");
const writer = @import("writer.zig");

const paths = [_][]const u8{
    "testdata/unarc-rs-multi-test_file.arj.b64",
    "testdata/unarc-rs-multi-test_file.a01.b64",
    "testdata/unarc-rs-multi-test_file.a02.b64",
};

const fixture_payload_sha256 = "be8a087b4563b116bd79d2f8b1f0544c2709a70c4787e05a57b7e11ec33a7f74";

fn fixtureAlloc(allocator: std.mem.Allocator, comptime path: []const u8) ![]u8 {
    const text = @embedFile(path);
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(u8, decoder.calcSizeUpperBound(text.len));
    errdefer allocator.free(bytes);
    const len = try decoder.decode(bytes, text);
    return allocator.realloc(bytes, len);
}

test "ARJ VolumeSet decodes the independent three-volume fixture" {
    const allocator = std.testing.allocator;
    var volumes: [paths.len][]u8 = undefined;
    var initialized: usize = 0;
    defer for (volumes[0..initialized]) |bytes| allocator.free(bytes);
    inline for (paths, 0..) |path, index| {
        volumes[index] = try fixtureAlloc(allocator, path);
        initialized += 1;
    }
    var set = try volume_set.VolumeSet.parseAlloc(allocator, &volumes);
    defer set.deinit();
    try std.testing.expectEqual(@as(usize, 3), set.archives.len);
    try std.testing.expectEqual(@as(usize, 1), set.entries.len);
    const entry = set.entries[0];
    try std.testing.expect(entry.name.eql("TEST.ICY"));
    try std.testing.expectEqual(@as(usize, 3), entry.fragment_count);
    try std.testing.expectEqual(@as(usize, 29813), entry.uncompressed_size);
    try std.testing.expectEqual(@as(usize, 21765), entry.compressed_size);
    const decoded = try set.extractAllocLimited(
        allocator,
        entry,
        entry.uncompressed_size,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqual(entry.uncompressed_size, decoded.len);
    var expected_sha256: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected_sha256, fixture_payload_sha256);
    var actual_sha256: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(decoded, &actual_sha256, .{});
    try std.testing.expectEqualSlices(u8, &expected_sha256, &actual_sha256);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        set.extractAllocLimited(
            allocator,
            entry,
            entry.uncompressed_size - 1,
        ),
    );
    var forged = entry;
    forged.fragment_count -= 1;
    try std.testing.expectError(
        error.InvalidArjVolumeSet,
        set.extractAllocLimited(allocator, forged, entry.uncompressed_size),
    );
}

test "ARJ VolumeSet rejects missing and reordered continuation volumes" {
    const allocator = std.testing.allocator;
    var volumes: [paths.len][]u8 = undefined;
    var initialized: usize = 0;
    defer for (volumes[0..initialized]) |bytes| allocator.free(bytes);
    inline for (paths, 0..) |path, index| {
        volumes[index] = try fixtureAlloc(allocator, path);
        initialized += 1;
    }
    try std.testing.expectError(
        error.InvalidArjVolumeSet,
        volume_set.VolumeSet.parseAlloc(allocator, volumes[0..2]),
    );
    const reordered = [_][]const u8{ volumes[0], volumes[2], volumes[1] };
    try std.testing.expectError(
        error.InvalidArjVolumeSet,
        volume_set.VolumeSet.parseAlloc(allocator, &reordered),
    );
    const missing_middle = [_][]const u8{ volumes[0], volumes[2] };
    try std.testing.expectError(
        error.InvalidArjVolumeSet,
        volume_set.VolumeSet.parseAlloc(allocator, &missing_middle),
    );
}

test "ARJ VolumeSet releases every allocation failure" {
    const allocator = std.testing.allocator;
    var volumes: [paths.len][]u8 = undefined;
    var initialized: usize = 0;
    defer for (volumes[0..initialized]) |bytes| allocator.free(bytes);
    inline for (paths, 0..) |path, index| {
        volumes[index] = try fixtureAlloc(allocator, path);
        initialized += 1;
    }
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, input: []const []const u8) !void {
            var set = try volume_set.VolumeSet.parseAlloc(failing_allocator, input);
            defer set.deinit();
            const decoded = try set.extractAllocLimited(
                failing_allocator,
                set.entries[0],
                set.entries[0].uncompressed_size,
            );
            defer failing_allocator.free(decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{volumes[0..]});
}

test "ARJ multi-volume writer round trips compressed Garble fragments" {
    const allocator = std.testing.allocator;
    const password = "volume-secret";
    const payload = "ARJ encrypted volume payload alpha beta gamma\n" ** 96;
    const entries = [_]writer.EncodeEntry{.{
        .name = "payload.txt",
        .data = payload,
        .method = .method_1,
        .encryption = .{ .password = password, .modifier = 0x40 },
    }};
    const budget = 700;
    var encoded = try writer.encodeVolumesAlloc(
        allocator,
        &entries,
        budget,
    );
    defer encoded.deinit();
    try std.testing.expect(encoded.volumes.len > 1);
    var repeated = try writer.encodeVolumesAlloc(
        allocator,
        &entries,
        budget,
    );
    defer repeated.deinit();
    try std.testing.expectEqual(encoded.volumes.len, repeated.volumes.len);
    for (encoded.volumes, repeated.volumes) |first, second|
        try std.testing.expectEqualSlices(u8, first, second);

    for (encoded.volumes) |bytes| {
        const parsed = try @import("archive.zig").parse(bytes);
        var payload_bytes: usize = 0;
        var iterator = parsed.iterator();
        while (try iterator.next()) |fragment|
            payload_bytes += fragment.compressed_size;
        try std.testing.expect(payload_bytes <= budget);
    }
    var set = try volume_set.VolumeSet.parseAlloc(allocator, encoded.volumes);
    defer set.deinit();
    try std.testing.expectEqual(@as(usize, 1), set.entries.len);
    try std.testing.expect(set.entries[0].fragment_count > 1);
    const decoded = try set.extractByNameAllocWithOptions(
        allocator,
        entries[0].name,
        .{ .password = password, .max_output_len = payload.len },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expectError(
        error.EncryptedArjEntry,
        set.extractByNameAllocWithOptions(
            allocator,
            entries[0].name,
            .{ .max_output_len = payload.len },
        ),
    );
}

test "ARJ multi-volume writer rejects zero budget and releases failures" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{
        .name = "payload.bin",
        .data = "0123456789" ** 20,
        .method = .stored,
    }};
    try std.testing.expectError(
        error.InvalidArjVolumeSize,
        writer.encodeVolumesAlloc(allocator, &entries, 0),
    );
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator) !void {
            const local_entries = [_]writer.EncodeEntry{.{
                .name = "payload.bin",
                .data = "0123456789" ** 20,
                .method = .stored,
            }};
            var encoded = try writer.encodeVolumesAlloc(
                failing_allocator,
                &local_entries,
                64,
            );
            defer encoded.deinit();
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}

test "ARJ VolumeSet checks each stored fragment CRC independently" {
    const allocator = std.testing.allocator;
    const payload = "independent fragment crc" ** 12;
    const entries = [_]writer.EncodeEntry{.{
        .name = "payload.bin",
        .data = payload,
        .method = .stored,
    }};
    var encoded = try writer.encodeVolumesAlloc(allocator, &entries, 64);
    defer encoded.deinit();
    try std.testing.expect(encoded.volumes.len > 1);
    const first_archive = try @import("archive.zig").parse(encoded.volumes[0]);
    const first_fragment = try first_archive.entryAt(0);
    encoded.volumes[0][first_fragment.data_offset] ^= 0x80;

    var set = try volume_set.VolumeSet.parseAlloc(allocator, encoded.volumes);
    defer set.deinit();
    try std.testing.expectError(
        error.ChecksumMismatch,
        set.extractAllocLimited(allocator, set.entries[0], payload.len),
    );
}
