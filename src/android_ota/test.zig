const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const br = @import("../br.zig");
const archive_mod = @import("archive.zig");
const source_archive = @import("source_archive.zig");
const source_mod = @import("source.zig");
const format = @import("format.zig");
const lz4diff = @import("lz4diff.zig");
const zucchini = @import("zucchini.zig");
const protobuf = @import("protobuf.zig");
const puffin_mod = @import("puffin.zig");
const writer = @import("writer.zig");

const allocator = std.testing.allocator;

const TestSource = struct {
    bytes: []const u8,
    max_chunk: usize,
    read_calls: usize = 0,
    bytes_read: usize = 0,
    fail: bool = false,

    fn source(self: *TestSource) source_mod.Source {
        return .{
            .context = self,
            .len = self.bytes.len,
            .read_at = readAt,
        };
    }

    fn readAt(
        raw_context: *anyopaque,
        offset: u64,
        output: []u8,
    ) error{SourceReadFailed}!usize {
        const self: *TestSource = @ptrCast(@alignCast(raw_context));
        if (self.fail) return error.SourceReadFailed;
        const start = std.math.cast(usize, offset) orelse
            return error.SourceReadFailed;
        if (start >= self.bytes.len) return 0;
        const amount = @min(
            output.len,
            @min(self.max_chunk, self.bytes.len - start),
        );
        @memcpy(output[0..amount], self.bytes[start..][0..amount]);
        self.read_calls += 1;
        self.bytes_read += amount;
        return amount;
    }
};

test "Android OTA full payload round trips raw Bzip2 XZ and automatic operations" {
    const block_size = 4096;
    const input = try allocator.alloc(u8, 5 * block_size);
    defer allocator.free(input);
    @memset(input, 0);
    for (input[0..block_size], 0..) |*byte, index|
        byte.* = @truncate(index * 17 + index / 31);
    const phrase = "Android OTA full payload compression ";
    for (input[2 * block_size .. 4 * block_size], 0..) |*byte, index|
        byte.* = phrase[index % phrase.len];

    inline for (.{
        writer.Compression.raw,
        writer.Compression.bzip2,
        writer.Compression.xz,
        writer.Compression.auto,
    }) |compression| {
        const encoded = try writer.encodeAlloc(
            allocator,
            &.{.{ .name = "system", .data = input }},
            .{
                .block_size = block_size,
                .operation_size = 2 * block_size,
                .compression = compression,
            },
        );
        defer allocator.free(encoded);
        var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
        defer archive.deinit();
        try std.testing.expectEqual(@as(usize, 1), archive.partitions.len);
        try std.testing.expectEqualStrings("system", archive.partitions[0].name);
        try std.testing.expectEqual(@as(u32, 0), archive.manifest.minor_version);
        var zero_operations: usize = 0;
        for (archive.partitionOperations(archive.partitions[0])) |operation| {
            if (operation.kind == .zero) {
                zero_operations += 1;
                continue;
            }
            switch (compression) {
                .raw => try std.testing.expectEqual(
                    format.OperationType.replace,
                    operation.kind,
                ),
                .bzip2 => try std.testing.expectEqual(
                    format.OperationType.replace_bz,
                    operation.kind,
                ),
                .xz => try std.testing.expectEqual(
                    format.OperationType.replace_xz,
                    operation.kind,
                ),
                .auto => {},
            }
        }
        try std.testing.expectEqual(@as(usize, 1), zero_operations);
        const decoded = try archive.decodePartitionAllocLimited(
            allocator,
            0,
            null,
            input.len,
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        const range_offset = block_size - 37;
        const range_length = 3 * block_size + 91;
        const range = try archive.readPartitionRangeAllocLimited(
            allocator,
            0,
            null,
            range_offset,
            range_length,
            range_length,
        );
        defer allocator.free(range);
        try std.testing.expectEqualSlices(
            u8,
            input[range_offset..][0..range_length],
            range,
        );
    }
}

test "Android OTA source archive reads full payload blobs through short callbacks" {
    const block_size = 4096;
    const input = try allocator.alloc(u8, 4 * block_size);
    defer allocator.free(input);
    for (input, 0..) |*byte, index| byte.* = @truncate(index * 37 + index / 13);
    @memset(input[3 * block_size ..], 0);

    inline for (.{
        writer.Compression.raw,
        writer.Compression.bzip2,
        writer.Compression.xz,
        writer.Compression.auto,
    }) |compression| {
        const encoded = try writer.encodeAlloc(
            allocator,
            &.{.{ .name = "system", .data = input }},
            .{
                .block_size = block_size,
                .operation_size = block_size,
                .compression = compression,
            },
        );
        defer allocator.free(encoded);
        var context = TestSource{ .bytes = encoded, .max_chunk = 3 };
        var ota = try source_archive.Archive.initAlloc(
            allocator,
            context.source(),
            .{},
        );
        defer ota.deinit();
        try std.testing.expectEqual(@as(?usize, 0), ota.findPartition("system"));
        const borrowed_name_offset = std.mem.indexOf(u8, encoded, "system") orelse
            unreachable;
        encoded[borrowed_name_offset] = 'X';
        try std.testing.expectEqual(@as(?usize, 0), ota.findPartition("system"));
        const decoded = try ota.decodePartitionAllocLimited(
            allocator,
            0,
            null,
            input.len,
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        var range: [257]u8 = undefined;
        try ota.readPartitionRangeInto(
            allocator,
            0,
            null,
            block_size - 31,
            &range,
            .{ .max_output_len = range.len, .verify_partition_hash = false },
        );
        try std.testing.expectEqualSlices(
            u8,
            input[block_size - 31 ..][0..range.len],
            &range,
        );
        try std.testing.expect(context.read_calls > 1);
        try std.testing.expect(context.bytes_read >= encoded.len);
        if (compression == .bzip2 or compression == .xz)
            try std.testing.expectError(
                error.OutputLimitExceeded,
                ota.readPartitionRangeInto(
                    allocator,
                    0,
                    null,
                    0,
                    range[0..1],
                    .{
                        .max_output_len = 1,
                        .max_operation_blob_len = 1,
                        .verify_partition_hash = false,
                    },
                ),
            );
    }
}

test "Android OTA source archive reads delta old-image extents on demand" {
    const old = [_]u8{0x5a} ** 4096;
    var old_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&old, &old_hash, .{});
    const payload = try sourceCopyPayloadAlloc(allocator, &old_hash);
    defer allocator.free(payload);
    var payload_context = TestSource{ .bytes = payload, .max_chunk = 5 };
    var old_context = TestSource{ .bytes = &old, .max_chunk = 7 };
    var ota = try source_archive.Archive.initAlloc(
        allocator,
        payload_context.source(),
        .{},
    );
    defer ota.deinit();
    const decoded = try ota.decodePartitionAllocLimited(
        allocator,
        0,
        old_context.source(),
        old.len,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &old, decoded);
    try std.testing.expect(old_context.read_calls > 1);
    try std.testing.expectError(
        error.MissingAndroidOtaSource,
        ota.decodePartitionAllocLimited(allocator, 0, null, old.len),
    );
    var corrupt = old;
    corrupt[0] ^= 1;
    var corrupt_context = TestSource{ .bytes = &corrupt, .max_chunk = 11 };
    try std.testing.expectError(
        error.ChecksumMismatch,
        ota.decodePartitionAllocLimited(
            allocator,
            0,
            corrupt_context.source(),
            old.len,
        ),
    );
}

test "Android OTA source archive releases every allocation failure" {
    const input = [_]u8{0x41} ** 8192;
    const encoded = try writer.encodeAlloc(
        allocator,
        &.{.{ .name = "system", .data = &input }},
        .{ .compression = .xz, .operation_size = 4096 },
    );
    defer allocator.free(encoded);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, bytes: []const u8) !void {
            var context = TestSource{ .bytes = bytes, .max_chunk = 17 };
            var ota = try source_archive.Archive.initAlloc(
                failing_allocator,
                context.source(),
                .{},
            );
            defer ota.deinit();
            var range: [97]u8 = undefined;
            try ota.readPartitionRangeInto(
                failing_allocator,
                0,
                null,
                31,
                &range,
                .{ .max_output_len = range.len, .verify_partition_hash = false },
            );
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{encoded});

    var failed_context = TestSource{
        .bytes = encoded,
        .max_chunk = 17,
        .fail = true,
    };
    try std.testing.expectError(
        error.SourceReadFailed,
        source_archive.Archive.initAlloc(
            allocator,
            failed_context.source(),
            .{},
        ),
    );
    var truncated_context = TestSource{ .bytes = encoded, .max_chunk = 17 };
    var truncated_source = truncated_context.source();
    truncated_source.len -= 1;
    try std.testing.expectError(
        error.TruncatedFrame,
        source_archive.Archive.initAlloc(allocator, truncated_source, .{}),
    );
}

test "Android OTA writer supports multiple and empty partitions" {
    const boot = [_]u8{0xa5} ** 4096;
    const encoded = try writer.encodeAlloc(
        allocator,
        &.{
            .{ .name = "boot", .data = &boot },
            .{ .name = "vendor", .data = "" },
        },
        .{ .compression = .raw },
    );
    defer allocator.free(encoded);
    var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
    defer archive.deinit();
    try std.testing.expectEqual(@as(usize, 2), archive.partitions.len);
    try std.testing.expectEqual(@as(?usize, 1), archive.findPartition("vendor"));
    const empty = try archive.decodePartitionByNameAllocLimited(
        allocator,
        "vendor",
        null,
        0,
    );
    defer allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
}

test "Android OTA source copy verifies old image and operation hashes" {
    const source = [_]u8{0x5a} ** 4096;
    var source_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&source, &source_hash, .{});
    const payload = try sourceCopyPayloadAlloc(allocator, &source_hash);
    defer allocator.free(payload);
    var archive = try archive_mod.Archive.initAlloc(allocator, payload, .{});
    defer archive.deinit();
    const decoded = try archive.decodePartitionAllocLimited(
        allocator,
        0,
        &source,
        source.len,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &source, decoded);
    try std.testing.expectError(
        error.MissingAndroidOtaSource,
        archive.decodePartitionAllocLimited(allocator, 0, null, source.len),
    );
    var corrupt = source;
    corrupt[0] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        archive.decodePartitionAllocLimited(
            allocator,
            0,
            &corrupt,
            corrupt.len,
        ),
    );
}

test "Android OTA SOURCE_BSDIFF applies a legacy patch through extents" {
    const source = [_]u8{0x5a} ** 4096;
    const expected = [_]u8{0x5b} ** 4096;
    const diff = [_]u8{1} ** 4096;
    const patch = try legacyDiffPatchAlloc(allocator, expected.len, &diff);
    defer allocator.free(patch);
    const payload = try sourceDiffPayloadAlloc(
        allocator,
        &source,
        &expected,
        patch,
        .source_bsdiff,
    );
    defer allocator.free(payload);
    var archive = try archive_mod.Archive.initAlloc(allocator, payload, .{});
    defer archive.deinit();
    const decoded = try archive.decodePartitionAllocLimited(
        allocator,
        0,
        &source,
        expected.len,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &expected, decoded);
    const range = try archive.readPartitionRangeAllocLimited(
        allocator,
        0,
        &source,
        73,
        257,
        257,
    );
    defer allocator.free(range);
    try std.testing.expectEqualSlices(u8, expected[73..330], range);
}

test "Android OTA PUFFDIFF applies the pinned AOSP patch through extents" {
    var source = [_]u8{0} ** 4096;
    const source_prefix = [_]u8{
        0x11, 0x22, 0x63, 0x64, 0x62, 0x66, 0x61, 0x05, 0x00,
        0x33, 0x03, 0x00, 0x63, 0x04, 0x00, 0x44, 0x55,
    };
    @memcpy(source[0..source_prefix.len], &source_prefix);
    var expected = [_]u8{0} ** 4096;
    const expected_prefix = [_]u8{
        0x63, 0x64, 0x62, 0x66, 0x61, 0x05, 0x00, 0x33, 0x66,
        0x01, 0x05, 0x00, 0xfa, 0xff, 1,    2,    3,    4,
        5,    0x63, 0x04, 0x00,
    };
    @memcpy(expected[0..expected_prefix.len], &expected_prefix);
    const payload = try sourceDiffPayloadAlloc(
        allocator,
        &source,
        &expected,
        &puffin_mod.test_puffdiff_fixture,
        .puffdiff,
    );
    defer allocator.free(payload);
    var archive = try archive_mod.Archive.initAlloc(allocator, payload, .{});
    defer archive.deinit();
    const decoded = try archive.decodePartitionAllocLimited(
        allocator,
        0,
        &source,
        expected.len,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &expected, decoded);
}

test "Android OTA LZ4DIFF BSDIFF and PUFFDIFF operations apply through extents" {
    const source = [_]u8{0x25} ** 4096;
    var expected = [_]u8{0x47} ** 4096;
    for (&expected, 0..) |*byte, index| {
        if (index % 97 == 0) byte.* = @truncate(index);
    }

    const bsdiff_inner = try legacyDiffPatchForSourceAlloc(
        allocator,
        &source,
        &expected,
    );
    defer allocator.free(bsdiff_inner);
    const bsdiff_patch = try rawLz4diffPatchAlloc(
        allocator,
        source.len,
        .bsdiff,
        bsdiff_inner,
    );
    defer allocator.free(bsdiff_patch);
    const puffdiff_inner = try noDeflatePuffdiffPatchAlloc(
        allocator,
        &source,
        &expected,
    );
    defer allocator.free(puffdiff_inner);
    const puffdiff_patch = try rawLz4diffPatchAlloc(
        allocator,
        source.len,
        .puffdiff,
        puffdiff_inner,
    );
    defer allocator.free(puffdiff_patch);

    for (
        [_]format.OperationType{ .lz4diff_bsdiff, .lz4diff_puffdiff },
        [_][]const u8{ bsdiff_patch, puffdiff_patch },
    ) |kind, patch| {
        const payload = try sourceDiffPayloadAlloc(
            allocator,
            &source,
            &expected,
            patch,
            kind,
        );
        defer allocator.free(payload);
        var archive = try archive_mod.Archive.initAlloc(allocator, payload, .{});
        defer archive.deinit();
        const decoded = try archive.decodePartitionAllocLimited(
            allocator,
            0,
            &source,
            expected.len,
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &expected, decoded);
        const range = try archive.readPartitionRangeAllocLimited(
            allocator,
            0,
            &source,
            301,
            911,
            911,
        );
        defer allocator.free(range);
        try std.testing.expectEqualSlices(u8, expected[301..1212], range);
    }
}

test "Android OTA ZUCCHINI applies Brotli wrapped NoOp patches through extents" {
    const source = [_]u8{0x25} ** 4096;
    var expected = [_]u8{0x47} ** 4096;
    for (&expected, 0..) |*byte, index| {
        if (index % 73 == 0) byte.* = @truncate(index * 11);
    }
    const raw_patch = try zucchini.testLiteralPatchAlloc(
        allocator,
        &source,
        &expected,
    );
    defer allocator.free(raw_patch);
    const compressed_patch = try br.encodeStoredStreamAlloc(
        allocator,
        raw_patch,
    );
    defer allocator.free(compressed_patch);
    const payload = try sourceDiffPayloadAlloc(
        allocator,
        &source,
        &expected,
        compressed_patch,
        .zucchini,
    );
    defer allocator.free(payload);
    var archive = try archive_mod.Archive.initAlloc(allocator, payload, .{});
    defer archive.deinit();
    const decoded = try archive.decodePartitionAllocLimited(
        allocator,
        0,
        &source,
        expected.len,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &expected, decoded);
    const range = try archive.readPartitionRangeAllocLimited(
        allocator,
        0,
        &source,
        257,
        733,
        733,
    );
    defer allocator.free(range);
    try std.testing.expectEqualSlices(u8, expected[257..990], range);
}

test "Android OTA rejects malformed headers blobs and hashes" {
    const input = [_]u8{0x33} ** 4096;
    const encoded = try writer.encodeAlloc(
        allocator,
        &.{.{ .name = "boot", .data = &input }},
        .{ .compression = .raw },
    );
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.TruncatedFrame,
        archive_mod.Archive.initAlloc(allocator, encoded[0..23], .{}),
    );
    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    corrupt[0] ^= 1;
    try std.testing.expectError(
        error.InvalidMagic,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    @memcpy(corrupt, encoded);
    std.mem.writeInt(u64, corrupt[4..12], 3, .big);
    try std.testing.expectError(
        error.UnsupportedVersion,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    @memcpy(corrupt, encoded);
    corrupt[corrupt.len - 1] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    try std.testing.expectError(
        error.InvalidAndroidOta,
        writer.encodeAlloc(
            allocator,
            &.{.{ .name = "unaligned", .data = input[0..4095] }},
            .{},
        ),
    );
}

test "Android OTA DISCARD requires explicit zero interpretation" {
    const expected = [_]u8{0} ** 4096;
    const payload = try noSourcePayloadAlloc(
        allocator,
        @intFromEnum(format.OperationType.discard),
        "",
        &expected,
    );
    defer allocator.free(payload);
    var archive = try archive_mod.Archive.initAlloc(allocator, payload, .{});
    defer archive.deinit();
    try std.testing.expectError(
        error.UnsupportedAndroidOtaOperation,
        archive.decodePartitionAllocLimited(
            allocator,
            0,
            null,
            expected.len,
        ),
    );
    const decoded = try archive.decodePartitionAllocWithOptions(
        allocator,
        0,
        null,
        .{
            .max_output_len = expected.len,
            .discard_as_zero = true,
        },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &expected, decoded);
}

test "Android OTA preserves future operations and rejects extraction explicitly" {
    const expected = [_]u8{0x7c} ** 4096;
    const payload = try noSourcePayloadAlloc(
        allocator,
        99,
        &expected,
        &expected,
    );
    defer allocator.free(payload);
    var archive = try archive_mod.Archive.initAlloc(allocator, payload, .{});
    defer archive.deinit();
    try std.testing.expectEqual(@as(u32, 99), @intFromEnum(archive.operations[0].kind));
    try std.testing.expectError(
        error.UnsupportedAndroidOtaOperation,
        archive.decodePartitionAllocLimited(
            allocator,
            0,
            null,
            expected.len,
        ),
    );
}

test "Android OTA enforces parser decode and deferred hash limits" {
    const input = [_]u8{0x33} ** 4096;
    const encoded = try writer.encodeAlloc(
        allocator,
        &.{.{ .name = "boot", .data = &input }},
        .{ .compression = .raw },
    );
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive_mod.Archive.initAlloc(allocator, encoded, .{
            .max_manifest_size = 1,
        }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive_mod.Archive.initAlloc(allocator, encoded, .{
            .max_partitions = 0,
        }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive_mod.Archive.initAlloc(allocator, encoded, .{
            .max_blob_size = 1,
        }),
    );
    var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
    defer archive.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive.decodePartitionAllocLimited(allocator, 0, null, input.len - 1),
    );

    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 1;
    var unchecked = try archive_mod.Archive.initAlloc(
        allocator,
        corrupt,
        .{ .verify_data_hashes = false },
    );
    defer unchecked.deinit();
    try std.testing.expectError(
        error.ChecksumMismatch,
        unchecked.decodePartitionAllocLimited(
            allocator,
            0,
            null,
            input.len,
        ),
    );
}

test "Android OTA exposes signed metadata and payload sections" {
    const input = [_]u8{0x41} ** 4096;
    const unsigned = try noSourcePayloadAlloc(
        allocator,
        @intFromEnum(format.OperationType.replace),
        &input,
        &input,
    );
    defer allocator.free(unsigned);
    const payload = try addSignatureSectionsAlloc(
        allocator,
        unsigned,
        "metadata signature protobuf",
        "payload signature protobuf",
    );
    defer allocator.free(payload);
    var archive = try archive_mod.Archive.initAlloc(allocator, payload, .{});
    defer archive.deinit();
    try std.testing.expectEqualSlices(
        u8,
        "metadata signature protobuf",
        archive.metadataSignature(),
    );
    try std.testing.expectEqualSlices(
        u8,
        "payload signature protobuf",
        archive.payloadSignature().?,
    );
    try std.testing.expectEqualSlices(
        u8,
        &input,
        archive.operationBlob(archive.operations[0]),
    );
    const decoded = try archive.decodePartitionAllocLimited(
        allocator,
        0,
        null,
        input.len,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

fn sourceCopyPayloadAlloc(
    alloc: std.mem.Allocator,
    source_hash: *const [32]u8,
) ![]u8 {
    var extent: std.ArrayList(u8) = .empty;
    defer extent.deinit(alloc);
    try protobuf.appendVarintField(alloc, &extent, 1, 0);
    try protobuf.appendVarintField(alloc, &extent, 2, 1);

    var operation: std.ArrayList(u8) = .empty;
    defer operation.deinit(alloc);
    try protobuf.appendVarintField(
        alloc,
        &operation,
        1,
        @intFromEnum(format.OperationType.source_copy),
    );
    try protobuf.appendMessageField(alloc, &operation, 4, extent.items);
    try protobuf.appendMessageField(alloc, &operation, 6, extent.items);
    try protobuf.appendBytesField(alloc, &operation, 9, source_hash);

    var info: std.ArrayList(u8) = .empty;
    defer info.deinit(alloc);
    try protobuf.appendVarintField(alloc, &info, 1, 4096);
    try protobuf.appendBytesField(alloc, &info, 2, source_hash);

    var partition: std.ArrayList(u8) = .empty;
    defer partition.deinit(alloc);
    try protobuf.appendBytesField(alloc, &partition, 1, "system");
    try protobuf.appendMessageField(alloc, &partition, 6, info.items);
    try protobuf.appendMessageField(alloc, &partition, 7, info.items);
    try protobuf.appendMessageField(alloc, &partition, 8, operation.items);

    var manifest: std.ArrayList(u8) = .empty;
    defer manifest.deinit(alloc);
    try protobuf.appendVarintField(alloc, &manifest, 3, 4096);
    try protobuf.appendVarintField(alloc, &manifest, 12, 2);
    try protobuf.appendMessageField(alloc, &manifest, 13, partition.items);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(alloc);
    try output.appendSlice(alloc, format.magic);
    try format.appendU64Be(alloc, &output, format.major_version);
    try format.appendU64Be(alloc, &output, manifest.items.len);
    try format.appendU32Be(alloc, &output, 0);
    try output.appendSlice(alloc, manifest.items);
    return output.toOwnedSlice(alloc);
}

fn sourceDiffPayloadAlloc(
    alloc: std.mem.Allocator,
    source: []const u8,
    expected: []const u8,
    patch: []const u8,
    kind: format.OperationType,
) ![]u8 {
    std.debug.assert(source.len == 4096 and expected.len == 4096);
    var source_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(source, &source_hash, .{});
    var expected_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(expected, &expected_hash, .{});
    var patch_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(patch, &patch_hash, .{});

    var extent_message: std.ArrayList(u8) = .empty;
    defer extent_message.deinit(alloc);
    try protobuf.appendVarintField(alloc, &extent_message, 1, 0);
    try protobuf.appendVarintField(alloc, &extent_message, 2, 1);
    var operation: std.ArrayList(u8) = .empty;
    defer operation.deinit(alloc);
    try protobuf.appendVarintField(alloc, &operation, 1, @intFromEnum(kind));
    try protobuf.appendVarintField(alloc, &operation, 2, 0);
    try protobuf.appendVarintField(alloc, &operation, 3, patch.len);
    try protobuf.appendMessageField(alloc, &operation, 4, extent_message.items);
    try protobuf.appendMessageField(alloc, &operation, 6, extent_message.items);
    try protobuf.appendBytesField(alloc, &operation, 8, &patch_hash);
    try protobuf.appendBytesField(alloc, &operation, 9, &source_hash);

    var old_info: std.ArrayList(u8) = .empty;
    defer old_info.deinit(alloc);
    try protobuf.appendVarintField(alloc, &old_info, 1, source.len);
    try protobuf.appendBytesField(alloc, &old_info, 2, &source_hash);
    var new_info: std.ArrayList(u8) = .empty;
    defer new_info.deinit(alloc);
    try protobuf.appendVarintField(alloc, &new_info, 1, expected.len);
    try protobuf.appendBytesField(alloc, &new_info, 2, &expected_hash);
    var partition: std.ArrayList(u8) = .empty;
    defer partition.deinit(alloc);
    try protobuf.appendBytesField(alloc, &partition, 1, "system");
    try protobuf.appendMessageField(alloc, &partition, 6, old_info.items);
    try protobuf.appendMessageField(alloc, &partition, 7, new_info.items);
    try protobuf.appendMessageField(alloc, &partition, 8, operation.items);
    var manifest: std.ArrayList(u8) = .empty;
    defer manifest.deinit(alloc);
    try protobuf.appendVarintField(alloc, &manifest, 3, 4096);
    try protobuf.appendVarintField(alloc, &manifest, 12, 4);
    try protobuf.appendMessageField(alloc, &manifest, 13, partition.items);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(alloc);
    try output.appendSlice(alloc, format.magic);
    try format.appendU64Be(alloc, &output, format.major_version);
    try format.appendU64Be(alloc, &output, manifest.items.len);
    try format.appendU32Be(alloc, &output, 0);
    try output.appendSlice(alloc, manifest.items);
    try output.appendSlice(alloc, patch);
    return output.toOwnedSlice(alloc);
}

fn legacyDiffPatchAlloc(
    alloc: std.mem.Allocator,
    output_len: usize,
    diff: []const u8,
) ![]u8 {
    var control: [24]u8 = @splat(0);
    std.mem.writeInt(u64, control[0..8], output_len, .little);
    const control_compressed = try bzip2.encodeAlloc(alloc, &control, .{});
    defer alloc.free(control_compressed);
    const diff_compressed = try bzip2.encodeAlloc(alloc, diff, .{});
    defer alloc.free(diff_compressed);
    const extra_compressed = try bzip2.encodeAlloc(alloc, "", .{});
    defer alloc.free(extra_compressed);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(alloc);
    try output.appendSlice(alloc, "BSDIFF40");
    var sizes: [24]u8 = @splat(0);
    std.mem.writeInt(u64, sizes[0..8], control_compressed.len, .little);
    std.mem.writeInt(u64, sizes[8..16], diff_compressed.len, .little);
    std.mem.writeInt(u64, sizes[16..24], output_len, .little);
    try output.appendSlice(alloc, &sizes);
    try output.appendSlice(alloc, control_compressed);
    try output.appendSlice(alloc, diff_compressed);
    try output.appendSlice(alloc, extra_compressed);
    return output.toOwnedSlice(alloc);
}

fn legacyDiffPatchForSourceAlloc(
    alloc: std.mem.Allocator,
    source: []const u8,
    expected: []const u8,
) ![]u8 {
    if (source.len != expected.len) return error.TestUnexpectedResult;
    const diff = try alloc.alloc(u8, expected.len);
    defer alloc.free(diff);
    for (diff, source, expected) |*byte, old, new|
        byte.* = new -% old;
    return legacyDiffPatchAlloc(alloc, expected.len, diff);
}

fn rawLz4diffPatchAlloc(
    alloc: std.mem.Allocator,
    length: usize,
    inner_type: lz4diff.InnerPatchType,
    inner_patch: []const u8,
) ![]u8 {
    var algorithm: std.ArrayList(u8) = .empty;
    defer algorithm.deinit(alloc);
    try protobuf.appendVarintField(alloc, &algorithm, 1, 0);
    var block: std.ArrayList(u8) = .empty;
    defer block.deinit(alloc);
    try protobuf.appendVarintField(alloc, &block, 2, length);
    try protobuf.appendVarintField(alloc, &block, 3, length);
    var info: std.ArrayList(u8) = .empty;
    defer info.deinit(alloc);
    try protobuf.appendMessageField(alloc, &info, 1, algorithm.items);
    try protobuf.appendMessageField(alloc, &info, 2, block.items);
    var header: std.ArrayList(u8) = .empty;
    defer header.deinit(alloc);
    try protobuf.appendMessageField(alloc, &header, 1, info.items);
    try protobuf.appendMessageField(alloc, &header, 2, info.items);
    try protobuf.appendVarintField(
        alloc,
        &header,
        3,
        @intFromEnum(inner_type),
    );
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(alloc);
    try output.appendSlice(alloc, lz4diff.magic);
    try format.appendU32Be(alloc, &output, lz4diff.version);
    try format.appendU32Be(alloc, &output, @intCast(header.items.len));
    try output.append(alloc, 0);
    try output.appendSlice(alloc, header.items);
    try output.appendSlice(alloc, inner_patch);
    return output.toOwnedSlice(alloc);
}

fn noDeflatePuffdiffPatchAlloc(
    alloc: std.mem.Allocator,
    source: []const u8,
    expected: []const u8,
) ![]u8 {
    const inner = try legacyDiffPatchForSourceAlloc(alloc, source, expected);
    defer alloc.free(inner);
    var source_info: std.ArrayList(u8) = .empty;
    defer source_info.deinit(alloc);
    try protobuf.appendVarintField(alloc, &source_info, 3, source.len);
    var destination_info: std.ArrayList(u8) = .empty;
    defer destination_info.deinit(alloc);
    try protobuf.appendVarintField(alloc, &destination_info, 3, expected.len);
    var header: std.ArrayList(u8) = .empty;
    defer header.deinit(alloc);
    try protobuf.appendVarintField(alloc, &header, 1, 1);
    try protobuf.appendMessageField(alloc, &header, 2, source_info.items);
    try protobuf.appendMessageField(alloc, &header, 3, destination_info.items);
    try protobuf.appendVarintField(alloc, &header, 4, 0);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(alloc);
    try output.appendSlice(alloc, "PUF1");
    try format.appendU32Be(alloc, &output, @intCast(header.items.len));
    try output.appendSlice(alloc, header.items);
    try output.appendSlice(alloc, inner);
    return output.toOwnedSlice(alloc);
}

fn noSourcePayloadAlloc(
    alloc: std.mem.Allocator,
    kind: u32,
    blob: []const u8,
    expected: []const u8,
) ![]u8 {
    std.debug.assert(expected.len == 4096);
    var extent_message: std.ArrayList(u8) = .empty;
    defer extent_message.deinit(alloc);
    try protobuf.appendVarintField(alloc, &extent_message, 1, 0);
    try protobuf.appendVarintField(alloc, &extent_message, 2, 1);

    var operation: std.ArrayList(u8) = .empty;
    defer operation.deinit(alloc);
    try protobuf.appendVarintField(alloc, &operation, 1, kind);
    if (blob.len != 0) {
        try protobuf.appendVarintField(alloc, &operation, 2, 0);
        try protobuf.appendVarintField(alloc, &operation, 3, blob.len);
    }
    try protobuf.appendMessageField(alloc, &operation, 6, extent_message.items);
    if (blob.len != 0) {
        var blob_hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(blob, &blob_hash, .{});
        try protobuf.appendBytesField(alloc, &operation, 8, &blob_hash);
    }

    var expected_hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(expected, &expected_hash, .{});
    var info: std.ArrayList(u8) = .empty;
    defer info.deinit(alloc);
    try protobuf.appendVarintField(alloc, &info, 1, expected.len);
    try protobuf.appendBytesField(alloc, &info, 2, &expected_hash);

    var partition: std.ArrayList(u8) = .empty;
    defer partition.deinit(alloc);
    try protobuf.appendBytesField(alloc, &partition, 1, "system");
    try protobuf.appendMessageField(alloc, &partition, 7, info.items);
    try protobuf.appendMessageField(alloc, &partition, 8, operation.items);

    var manifest: std.ArrayList(u8) = .empty;
    defer manifest.deinit(alloc);
    try protobuf.appendVarintField(alloc, &manifest, 3, 4096);
    try protobuf.appendVarintField(alloc, &manifest, 12, 0);
    try protobuf.appendMessageField(alloc, &manifest, 13, partition.items);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(alloc);
    try output.appendSlice(alloc, format.magic);
    try format.appendU64Be(alloc, &output, format.major_version);
    try format.appendU64Be(alloc, &output, manifest.items.len);
    try format.appendU32Be(alloc, &output, 0);
    try output.appendSlice(alloc, manifest.items);
    try output.appendSlice(alloc, blob);
    return output.toOwnedSlice(alloc);
}

fn addSignatureSectionsAlloc(
    alloc: std.mem.Allocator,
    unsigned: []const u8,
    metadata_signature: []const u8,
    payload_signature: []const u8,
) ![]u8 {
    const manifest_size: usize = @intCast(format.readU64Be(unsigned, 12));
    const old_manifest = unsigned[format.header_size..][0..manifest_size];
    const blobs = unsigned[format.header_size + manifest_size ..];
    var manifest: std.ArrayList(u8) = .empty;
    defer manifest.deinit(alloc);
    try manifest.appendSlice(alloc, old_manifest);
    try protobuf.appendVarintField(alloc, &manifest, 4, blobs.len);
    try protobuf.appendVarintField(alloc, &manifest, 5, payload_signature.len);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(alloc);
    try output.appendSlice(alloc, format.magic);
    try format.appendU64Be(alloc, &output, format.major_version);
    try format.appendU64Be(alloc, &output, manifest.items.len);
    try format.appendU32Be(alloc, &output, @intCast(metadata_signature.len));
    try output.appendSlice(alloc, manifest.items);
    try output.appendSlice(alloc, metadata_signature);
    try output.appendSlice(alloc, blobs);
    try output.appendSlice(alloc, payload_signature);
    return output.toOwnedSlice(alloc);
}
