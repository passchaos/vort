const std = @import("std");
const checksum = @import("../checksum.zig");
const ppmd8 = @import("../ppmd8.zig");
const zip = @import("../zip.zig");
const incremental = @import("incremental_reader.zig");
const descriptor = @import("incremental_reader/descriptor.zig");
const wire = @import("wire.zig");

const ExpectedEntry = struct {
    name: []const u8,
    data: []const u8,
};

fn decodeArchiveFragmented(
    allocator: std.mem.Allocator,
    archive: []const u8,
    expected: []const ExpectedEntry,
    options: incremental.Options,
    input_chunk_len: usize,
    output_chunk_len: usize,
) !void {
    var reader = try incremental.Reader.initWithOptions(allocator, options);
    defer reader.deinit();
    var input_offset: usize = 0;
    var entry_index: usize = 0;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    var calls: usize = 0;
    var expected_output_len: usize = 0;
    for (expected) |entry| expected_output_len += entry.data.len;
    const max_calls = archive.len * 16 + expected_output_len * 2 + 4096;
    while (true) {
        calls += 1;
        if (calls > max_calls) return error.TestUnexpectedResult;
        const input_end = @min(archive.len, input_offset + input_chunk_len);
        var scratch: [31]u8 = undefined;
        const stepped = try reader.step(
            archive[input_offset..input_end],
            scratch[0..output_chunk_len],
        );
        input_offset += stepped.progress.input_read;
        try output.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        switch (stepped.status) {
            .entry_header => {
                try std.testing.expect(entry_index < expected.len);
                try std.testing.expectEqualStrings(expected[entry_index].name, reader.currentEntry().?.name);
            },
            .entry_done => {
                try std.testing.expect(entry_index < expected.len);
                try std.testing.expectEqualSlices(u8, expected[entry_index].data, output.items);
                try std.testing.expect(reader.currentEntry().?.crc32 != null);
                output.clearRetainingCapacity();
                entry_index += 1;
            },
            .done => break,
            .need_input => if (input_end == archive.len and stepped.progress.input_read == 0)
                return error.TruncatedFrame,
            .need_output => {},
        }
        if (stepped.status != .done and
            stepped.progress.input_read == 0 and
            stepped.progress.output_written == 0 and
            stepped.status != .entry_header and
            stepped.status != .entry_done and
            !(stepped.status == .need_input and input_end != archive.len))
            return error.TestUnexpectedResult;
    }
    try std.testing.expectEqual(archive.len, input_offset);
    try std.testing.expectEqual(expected.len, entry_index);
    if (options.initial_offset == 0) {
        const parsed = try zip.parse(archive);
        const snapshot = reader.snapshot();
        try std.testing.expectEqual(parsed.central_directory_offset, snapshot.central_offset.?);
        try std.testing.expectEqual(parsed.central_directory_size, snapshot.central_size.?);
        try std.testing.expectEqualStrings(parsed.comment, reader.archiveComment());
    }
}

test "ZIP incremental reader retains entry comments timestamps and Unix attributes" {
    const allocator = std.testing.allocator;
    const modified = try zip.DosTimestamp.fromComponents(.{
        .year = 2024,
        .month = 2,
        .day = 29,
        .hour = 12,
        .minute = 34,
        .second = 57,
    });
    const entries = [_]zip.EncodeEntry{
        .{
            .name = "metadata.txt",
            .data = "incremental metadata payload",
            .method = .deflate,
            .comment = "central comment",
            .modified = modified,
            .creator_system = .unix,
            .internal_attributes = 1,
            .external_attributes = zip.unixExternalAttributes(0o100640),
        },
        .{
            .name = "link",
            .data = "metadata.txt",
            .method = .stored,
            .comment = "link comment",
            .modified = modified,
            .creator_system = .unix,
            .external_attributes = zip.unixExternalAttributes(0o120777),
        },
    };
    const bytes = try zip.encodeAlloc(allocator, &entries, .{
        .data_descriptor = true,
        .zip64 = .always,
    });
    defer allocator.free(bytes);

    const Test = struct {
        fn run(
            reader_allocator: std.mem.Allocator,
            archive_bytes: []const u8,
            expected_entries: []const zip.EncodeEntry,
            expected_modified: zip.DosTimestamp,
        ) !void {
            var reader = try incremental.Reader.init(reader_allocator);
            defer reader.deinit();
            var input_offset: usize = 0;
            var output: [3]u8 = undefined;
            var header_index: usize = 0;
            while (true) {
                const input_end = @min(archive_bytes.len, input_offset + 1);
                const stepped = try reader.step(
                    archive_bytes[input_offset..input_end],
                    &output,
                );
                input_offset += stepped.progress.input_read;
                if (stepped.status == .entry_header) {
                    const info = reader.currentEntry().?;
                    try std.testing.expect(info.comment == null);
                    try std.testing.expectEqual(expected_modified, info.modified);
                    header_index += 1;
                }
                if (stepped.status == .done) break;
            }
            try std.testing.expectEqual(archive_bytes.len, input_offset);
            try std.testing.expectEqual(expected_entries.len, header_index);
            for (expected_entries, 0..) |expected, index| {
                const info = reader.entryAt(index).?;
                try std.testing.expectEqualStrings(expected.comment, info.comment.?);
                try std.testing.expectEqual(expected_modified, info.modified);
                try std.testing.expectEqual(zip.CreatorSystem.unix, info.creatorSystem().?);
                try std.testing.expectEqual(expected.internal_attributes, info.internal_attributes.?);
                try std.testing.expectEqual(
                    @as(u16, @truncate(expected.external_attributes.? >> 16)),
                    info.unixMode().?,
                );
                try std.testing.expectEqual(index == 1, info.isSymbolicLink());
            }
            try std.testing.expect(reader.entryAt(expected_entries.len) == null);
        }
    };
    try Test.run(allocator, bytes, &entries, modified);
    try std.testing.checkAllAllocationFailures(
        allocator,
        Test.run,
        .{ bytes, &entries, modified },
    );

    const parsed = try zip.parse(bytes);
    var limited = try incremental.Reader.initWithOptions(allocator, .{
        .max_metadata_size = entries[0].name.len + entries[1].name.len,
    });
    defer limited.deinit();
    var input_offset: usize = 0;
    var output: [64]u8 = undefined;
    while (true) {
        const stepped = limited.step(bytes[input_offset..], &output) catch |err| {
            try std.testing.expectEqual(error.OutputLimitExceeded, err);
            break;
        };
        input_offset += stepped.progress.input_read;
    }
    try std.testing.expect(input_offset >= parsed.central_directory_offset);
}

fn withoutDescriptorSignature(
    allocator: std.mem.Allocator,
    signed_archive: []const u8,
) ![]u8 {
    const archive = try zip.parse(signed_archive);
    try std.testing.expectEqual(@as(usize, 1), archive.entry_count);
    const entry = try archive.entryAt(0);
    const local_offset = entry.local_header_offset;
    try std.testing.expectEqual(
        wire.local_file_signature,
        std.mem.readInt(u32, signed_archive[local_offset..][0..4], .little),
    );
    const name_len = std.mem.readInt(u16, signed_archive[local_offset + 26 ..][0..2], .little);
    const extra_len = std.mem.readInt(u16, signed_archive[local_offset + 28 ..][0..2], .little);
    const data_offset = local_offset + wire.local_file_header_len + name_len + extra_len;
    const descriptor_offset = data_offset + entry.compressed_size;
    try std.testing.expectEqual(
        @as(u32, 0x0807_4b50),
        std.mem.readInt(u32, signed_archive[descriptor_offset..][0..4], .little),
    );
    const unsigned = try allocator.alloc(u8, signed_archive.len - 4);
    errdefer allocator.free(unsigned);
    @memcpy(unsigned[0..descriptor_offset], signed_archive[0..descriptor_offset]);
    @memcpy(unsigned[descriptor_offset..], signed_archive[descriptor_offset + 4 ..]);
    const eocd_offset = unsigned.len - 22 - archive.comment.len;
    const central_offset = archive.central_directory_offset - 4;
    const legacy_central_offset = std.mem.readInt(u32, unsigned[eocd_offset + 16 ..][0..4], .little);
    if (legacy_central_offset != std.math.maxInt(u32))
        std.mem.writeInt(u32, unsigned[eocd_offset + 16 ..][0..4], @intCast(central_offset), .little);
    if (archive.zip64) {
        const locator_offset = eocd_offset - wire.zip64_end_of_central_locator_len;
        try std.testing.expectEqual(
            wire.zip64_end_of_central_locator_signature,
            std.mem.readInt(u32, unsigned[locator_offset..][0..4], .little),
        );
        const zip64_end_offset = std.mem.readInt(u64, unsigned[locator_offset + 8 ..][0..8], .little) - 4;
        std.mem.writeInt(u64, unsigned[locator_offset + 8 ..][0..8], zip64_end_offset, .little);
        const zip64_offset: usize = @intCast(zip64_end_offset);
        try std.testing.expectEqual(
            wire.zip64_end_of_central_signature,
            std.mem.readInt(u32, unsigned[zip64_offset..][0..4], .little),
        );
        std.mem.writeInt(u64, unsigned[zip64_offset + 48 ..][0..8], central_offset, .little);
    }
    return unsigned;
}

fn forgeCrc32Suffix(prefix: []const u8, target: u32) [4]u8 {
    var zeros: [4]u8 = @splat(0);
    var state = checksum.Crc32Best.init();
    state.update(prefix);
    state.update(&zeros);
    const base = state.digest();
    var basis_value: [32]u32 = @splat(0);
    var basis_mask: [32]u32 = @splat(0);
    for (0..32) |bit| {
        var candidate: [4]u8 = @splat(0);
        candidate[bit / 8] = @as(u8, 1) << @intCast(bit % 8);
        var candidate_state = checksum.Crc32Best.init();
        candidate_state.update(prefix);
        candidate_state.update(&candidate);
        var value = candidate_state.digest() ^ base;
        var mask: u32 = @as(u32, 1) << @intCast(bit);
        while (value != 0) {
            const pivot: u5 = @intCast(@ctz(value));
            if (basis_value[pivot] == 0) {
                basis_value[pivot] = value;
                basis_mask[pivot] = mask;
                break;
            }
            value ^= basis_value[pivot];
            mask ^= basis_mask[pivot];
        }
    }
    var remaining = target ^ base;
    var solution: u32 = 0;
    while (remaining != 0) {
        const pivot: u5 = @intCast(@ctz(remaining));
        std.debug.assert(basis_value[pivot] != 0);
        remaining ^= basis_value[pivot];
        solution ^= basis_mask[pivot];
    }
    std.mem.writeInt(u32, &zeros, solution, .little);
    var verification = checksum.Crc32Best.init();
    verification.update(prefix);
    verification.update(&zeros);
    std.debug.assert(verification.digest() == target);
    return zeros;
}

fn expectReaderError(
    allocator: std.mem.Allocator,
    archive: []const u8,
    options: incremental.Options,
    expected_error: anyerror,
) !void {
    var reader = try incremental.Reader.initWithOptions(allocator, options);
    defer reader.deinit();
    var input_offset: usize = 0;
    var scratch: [97]u8 = undefined;
    while (input_offset < archive.len) {
        const stepped = reader.step(archive[input_offset..], &scratch) catch |err| {
            try std.testing.expectEqual(expected_error, err);
            try std.testing.expectEqual(incremental.Phase.failed, reader.snapshot().phase);
            try std.testing.expectError(error.ZipReaderFailed, reader.step("", &scratch));
            return;
        };
        input_offset += stepped.progress.input_read;
        if (stepped.status == .done) return error.TestExpectedError;
        if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0 and
            stepped.status != .entry_header and stepped.status != .entry_done)
            return error.TestUnexpectedResult;
    }
    reader.finish() catch |err| {
        try std.testing.expectEqual(expected_error, err);
        try std.testing.expectEqual(incremental.Phase.failed, reader.snapshot().phase);
        try std.testing.expectError(error.ZipReaderFailed, reader.step("", &scratch));
        return;
    };
    return error.TestExpectedError;
}

fn reverseTwoCentralRecords(
    allocator: std.mem.Allocator,
    source: []const u8,
) ![]u8 {
    const archive = try zip.parse(source);
    try std.testing.expectEqual(@as(usize, 2), archive.entry_count);
    const first = try archive.entryAt(0);
    const second = try archive.entryAt(1);
    const central_end = archive.central_directory_offset + archive.central_directory_size;
    const first_bytes = source[first.central_header_offset..second.central_header_offset];
    const second_bytes = source[second.central_header_offset..central_end];
    const reordered = try allocator.dupe(u8, source);
    @memcpy(reordered[archive.central_directory_offset..][0..second_bytes.len], second_bytes);
    @memcpy(reordered[archive.central_directory_offset + second_bytes.len ..][0..first_bytes.len], first_bytes);
    return reordered;
}

fn withCentralDigitalSignature(
    allocator: std.mem.Allocator,
    source: []const u8,
    signature_payload: []const u8,
) ![]u8 {
    const archive = try zip.parse(source);
    const insertion = archive.central_directory_offset + archive.central_directory_size;
    const record_len = wire.central_directory_digital_signature_len + signature_payload.len;
    const result = try allocator.alloc(u8, source.len + record_len);
    errdefer allocator.free(result);
    @memcpy(result[0..insertion], source[0..insertion]);
    std.mem.writeInt(
        u32,
        result[insertion..][0..4],
        wire.central_directory_digital_signature,
        .little,
    );
    std.mem.writeInt(u16, result[insertion + 4 ..][0..2], @intCast(signature_payload.len), .little);
    @memcpy(result[insertion + wire.central_directory_digital_signature_len ..][0..signature_payload.len], signature_payload);
    @memcpy(result[insertion + record_len ..], source[insertion..]);
    return result;
}

test "ZIP incremental reader streams signed descriptor ZIP32 and ZIP64 archives" {
    const allocator = std.testing.allocator;
    const stored = "stored payload containing PK\x07\x08 marker bytes";
    const deflated = "incremental whole archive deflate payload\n" ** 128;
    const entries = [_]zip.EncodeEntry{
        .{ .name = "stored.bin", .data = stored, .method = .stored },
        .{ .name = "folder/deflated.txt", .data = deflated, .method = .deflate },
    };
    const expected = [_]ExpectedEntry{
        .{ .name = entries[0].name, .data = stored },
        .{ .name = entries[1].name, .data = deflated },
    };
    inline for (.{ zip.Zip64Mode.never, zip.Zip64Mode.always }) |mode| {
        const bytes = try zip.encodeAlloc(allocator, &entries, .{
            .data_descriptor = true,
            .zip64 = mode,
            .archive_comment = "streamed",
        });
        defer allocator.free(bytes);
        for ([_]usize{ 1, 2, 3, 5, 17 }) |input_chunk_len| {
            for ([_]usize{ 1, 2, 7, 31 }) |output_chunk_len|
                try decodeArchiveFragmented(
                    allocator,
                    bytes,
                    &expected,
                    .{},
                    input_chunk_len,
                    output_chunk_len,
                );
        }
    }
}

test "ZIP incremental reader streams Bzip2 and Zstandard known and descriptor members" {
    const allocator = std.testing.allocator;
    const bzip2_payload = "incremental ZIP Bzip2 member\n" ** 173;
    const zstd_legacy_payload = "incremental ZIP legacy Zstandard member\n" ** 149;
    const zstd_payload = "incremental ZIP current Zstandard member\n" ** 181;
    const entries = [_]zip.EncodeEntry{
        .{ .name = "codec/bzip2.txt", .data = bzip2_payload, .method = .bzip2 },
        .{ .name = "codec/zstd-legacy.txt", .data = zstd_legacy_payload, .method = .zstandard_legacy },
        .{ .name = "codec/zstd.txt", .data = zstd_payload, .method = .zstandard },
    };
    const expected = [_]ExpectedEntry{
        .{ .name = entries[0].name, .data = bzip2_payload },
        .{ .name = entries[1].name, .data = zstd_legacy_payload },
        .{ .name = entries[2].name, .data = zstd_payload },
    };
    inline for (.{ false, true }) |uses_descriptor| {
        inline for (.{ zip.Zip64Mode.never, zip.Zip64Mode.always }) |zip64_mode| {
            const bytes = try zip.encodeAlloc(allocator, &entries, .{
                .data_descriptor = uses_descriptor,
                .zip64 = zip64_mode,
            });
            defer allocator.free(bytes);
            try decodeArchiveFragmented(allocator, bytes, &expected, .{}, 1, 1);
            try decodeArchiveFragmented(allocator, bytes, &expected, .{}, 7, 13);
        }
    }

    const bzip2_only = [_]zip.EncodeEntry{entries[0]};
    const bzip2_bytes = try zip.encodeAlloc(allocator, &bzip2_only, .{});
    defer allocator.free(bzip2_bytes);
    try expectReaderError(allocator, bzip2_bytes, .{
        .max_bzip2_compressed_block_len = 8,
    }, error.OutputLimitExceeded);

    const zstd_only = [_]zip.EncodeEntry{entries[2]};
    const zstd_bytes = try zip.encodeAlloc(allocator, &zstd_only, .{});
    defer allocator.free(zstd_bytes);
    try expectReaderError(allocator, zstd_bytes, .{
        .max_zstd_compressed_buffer_len = 4,
    }, error.OutputLimitExceeded);
}

test "ZIP incremental reader streams LZMA and XZ known and descriptor members" {
    const allocator = std.testing.allocator;
    const lzma_payload = "incremental ZIP method-14 LZMA member\n" ** 137;
    const xz_payload = "incremental ZIP method-95 XZ member\n" ** 163;
    const entries = [_]zip.EncodeEntry{
        .{ .name = "codec/lzma.txt", .data = lzma_payload, .method = .lzma },
        .{ .name = "codec/xz.txt", .data = xz_payload, .method = .xz },
    };
    const expected = [_]ExpectedEntry{
        .{ .name = entries[0].name, .data = lzma_payload },
        .{ .name = entries[1].name, .data = xz_payload },
    };
    inline for (.{ false, true }) |uses_descriptor| {
        inline for (.{ zip.Zip64Mode.never, zip.Zip64Mode.always }) |zip64_mode| {
            const bytes = try zip.encodeAlloc(allocator, &entries, .{
                .data_descriptor = uses_descriptor,
                .zip64 = zip64_mode,
            });
            defer allocator.free(bytes);
            try decodeArchiveFragmented(allocator, bytes, &expected, .{}, 1, 1);
            try decodeArchiveFragmented(allocator, bytes, &expected, .{}, 7, 13);
        }
    }

    const lzma_only = [_]zip.EncodeEntry{entries[0]};
    const lzma_bytes = try zip.encodeAlloc(allocator, &lzma_only, .{});
    defer allocator.free(lzma_bytes);
    try expectReaderError(allocator, lzma_bytes, .{
        .max_lzma_dictionary_size = 1024,
    }, error.OutputLimitExceeded);

    const xz_only = [_]zip.EncodeEntry{entries[1]};
    const xz_bytes = try zip.encodeAlloc(allocator, &xz_only, .{});
    defer allocator.free(xz_bytes);
    try expectReaderError(allocator, xz_bytes, .{
        .max_xz_dictionary_size = 1024,
    }, error.OutputLimitExceeded);
}

test "ZIP incremental reader streams Deflate64 extended-window members" {
    const allocator = std.testing.allocator;
    const prefix_len = 40 * 1024;
    const payload = try allocator.alloc(u8, prefix_len * 2);
    defer allocator.free(payload);
    var random_state: u32 = 0x9def_64a1;
    for (payload[0..prefix_len]) |*byte| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(random_state >> 24);
    }
    @memcpy(payload[prefix_len..], payload[0..prefix_len]);
    const entries = [_]zip.EncodeEntry{.{
        .name = "codec/deflate64.bin",
        .data = payload,
        .method = .deflate64,
    }};
    const expected = [_]ExpectedEntry{.{ .name = entries[0].name, .data = payload }};
    inline for (.{ false, true }) |uses_descriptor| {
        inline for (.{ zip.Zip64Mode.never, zip.Zip64Mode.always }) |zip64_mode| {
            const bytes = try zip.encodeAlloc(allocator, &entries, .{
                .data_descriptor = uses_descriptor,
                .zip64 = zip64_mode,
            });
            defer allocator.free(bytes);
            try decodeArchiveFragmented(allocator, bytes, &expected, .{}, 3, 17);
        }
    }
}

test "ZIP incremental reader streams PPMd restart and cut-off members" {
    const allocator = std.testing.allocator;
    const payload = "incremental ZIP PPMd method-98 member\n" ** 61;
    const entries = [_]zip.EncodeEntry{.{
        .name = "codec/ppmd.txt",
        .data = payload,
        .method = .ppmd,
    }};
    const expected = [_]ExpectedEntry{.{ .name = entries[0].name, .data = payload }};
    inline for (.{ zip.Zip64Mode.never, zip.Zip64Mode.always }) |zip64_mode| {
        inline for (.{ false, true }) |uses_descriptor| {
            inline for (.{ ppmd8.RestoreMethod.restart, .cut_off }) |restore_method| {
                const bytes = try zip.encodeAlloc(allocator, &entries, .{
                    .data_descriptor = uses_descriptor,
                    .zip64 = zip64_mode,
                    .ppmd_options = .{
                        .memory_size = 1024 * 1024,
                        .restore_method = restore_method,
                    },
                });
                defer allocator.free(bytes);
                try decodeArchiveFragmented(allocator, bytes, &expected, .{}, 3, 7);
            }
        }
    }

    const limited = try zip.encodeAlloc(allocator, &entries, .{
        .ppmd_options = .{ .memory_size = 1024 * 1024 },
    });
    defer allocator.free(limited);
    try expectReaderError(allocator, limited, .{
        .max_ppmd_memory_size = 512 * 1024,
    }, error.OutputLimitExceeded);
}

test "ZIP incremental reader streams every DCL Implode mode" {
    const allocator = std.testing.allocator;
    const payload = "incremental ZIP DCL Implode method-10 member\n" ** 79;
    const entries = [_]zip.EncodeEntry{.{
        .name = "codec/dcl-implode.txt",
        .data = payload,
        .method = .dcl_implode,
    }};
    const expected = [_]ExpectedEntry{.{ .name = entries[0].name, .data = payload }};
    inline for (.{ false, true }) |literal_coded| {
        inline for (std.meta.tags(zip.DclImplodeDictionary)) |dictionary| {
            inline for (.{ false, true }) |uses_descriptor| {
                inline for (.{ zip.Zip64Mode.never, zip.Zip64Mode.always }) |zip64_mode| {
                    const bytes = try zip.encodeAlloc(allocator, &entries, .{
                        .data_descriptor = uses_descriptor,
                        .zip64 = zip64_mode,
                        .dcl_implode_options = .{
                            .literal_coded = literal_coded,
                            .dictionary = dictionary,
                        },
                    });
                    defer allocator.free(bytes);
                    try decodeArchiveFragmented(allocator, bytes, &expected, .{}, 3, 7);
                }
            }
        }
    }
}

test "ZIP incremental reader streams Shrink known descriptor and reference members" {
    const allocator = std.testing.allocator;
    const payload = try allocator.alloc(u8, 12 * 1024);
    defer allocator.free(payload);
    var random_state: u32 = 0x5a17_c9e3;
    for (payload) |*byte| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(random_state >> 24);
    }
    const entries = [_]zip.EncodeEntry{.{
        .name = "codec/shrink.bin",
        .data = payload,
        .method = .shrink,
    }};
    const expected = [_]ExpectedEntry{.{ .name = entries[0].name, .data = payload }};
    inline for (.{ false, true }) |uses_descriptor| {
        inline for (.{ zip.Zip64Mode.never, zip.Zip64Mode.always }) |zip64_mode| {
            const bytes = try zip.encodeAlloc(allocator, &entries, .{
                .data_descriptor = uses_descriptor,
                .zip64 = zip64_mode,
            });
            defer allocator.free(bytes);
            try decodeArchiveFragmented(allocator, bytes, &expected, .{}, 1, 1);
            try decodeArchiveFragmented(allocator, bytes, &expected, .{}, 7, 13);

            if (uses_descriptor and zip64_mode == .never) {
                const unsigned = try withoutDescriptorSignature(allocator, bytes);
                defer allocator.free(unsigned);
                try decodeArchiveFragmented(allocator, unsigned, &expected, .{}, 1, 3);
            }
        }
    }

    const empty_entries = [_]zip.EncodeEntry{.{
        .name = "codec/empty-shrink",
        .data = "",
        .method = .shrink,
    }};
    const empty_expected = [_]ExpectedEntry{.{ .name = empty_entries[0].name, .data = "" }};
    inline for (.{ false, true }) |uses_descriptor| {
        const bytes = try zip.encodeAlloc(allocator, &empty_entries, .{
            .data_descriptor = uses_descriptor,
        });
        defer allocator.free(bytes);
        try decodeArchiveFragmented(allocator, bytes, &empty_expected, .{}, 1, 1);
    }

    const limited_archive = try zip.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(limited_archive);
    try expectReaderError(allocator, limited_archive, .{
        .max_entry_output_len = payload.len - 1,
    }, error.OutputLimitExceeded);

    // Apache Commons Compress src/test/resources/SHRUNK.ZIP.
    const fixture_hex = std.mem.trim(
        u8,
        @embedFile("testdata/commons-compress-shrunk.zip.hex"),
        "\r\n \t",
    );
    const fixture = try allocator.alloc(u8, fixture_hex.len / 2);
    defer allocator.free(fixture);
    _ = try std.fmt.hexToBytes(fixture, fixture_hex);
    const fixture_expected = [_]ExpectedEntry{
        .{
            .name = "TEST1.XML",
            .data = "<?xml version = '1.0'?>\n<!DOCTYPE connections>\n<connections>\n</connections>\n",
        },
        .{
            .name = "TEST2.XML",
            .data = "<?xml version = '1.0'?>\n<!DOCTYPE connections>\n<meinxml>\n    <leer />\n</meinxml>\n",
        },
    };
    try decodeArchiveFragmented(allocator, fixture, &fixture_expected, .{}, 1, 1);
    try decodeArchiveFragmented(allocator, fixture, &fixture_expected, .{}, 5, 7);
}

test "ZIP incremental reader streams every Reduce factor and descriptor layout" {
    const allocator = std.testing.allocator;
    const payload = ("incremental ZIP Reduce follower payload \x90\n" ** 149) ++
        ([_]u8{ 0, 1, 2, 3, 4, 5, 0xfe, 0xff } ** 97);
    inline for (.{
        zip.CompressionMethod.reduce_1,
        .reduce_2,
        .reduce_3,
        .reduce_4,
    }) |method| {
        const entries = [_]zip.EncodeEntry{.{
            .name = "codec/reduce.bin",
            .data = payload,
            .method = method,
        }};
        const expected = [_]ExpectedEntry{.{ .name = entries[0].name, .data = payload }};
        inline for (.{ false, true }) |uses_descriptor| {
            inline for (.{ zip.Zip64Mode.never, zip.Zip64Mode.always }) |zip64_mode| {
                const bytes = try zip.encodeAlloc(allocator, &entries, .{
                    .data_descriptor = uses_descriptor,
                    .zip64 = zip64_mode,
                });
                defer allocator.free(bytes);
                try decodeArchiveFragmented(allocator, bytes, &expected, .{}, 1, 1);
                try decodeArchiveFragmented(allocator, bytes, &expected, .{}, 7, 13);

                if (uses_descriptor and zip64_mode == .never) {
                    const unsigned = try withoutDescriptorSignature(allocator, bytes);
                    defer allocator.free(unsigned);
                    try decodeArchiveFragmented(allocator, unsigned, &expected, .{}, 1, 3);
                }
            }
        }
    }

    const empty_entries = [_]zip.EncodeEntry{.{
        .name = "codec/empty-reduce",
        .data = "",
        .method = .reduce_4,
    }};
    const empty_expected = [_]ExpectedEntry{.{ .name = empty_entries[0].name, .data = "" }};
    inline for (.{ false, true }) |uses_descriptor| {
        const bytes = try zip.encodeAlloc(allocator, &empty_entries, .{
            .data_descriptor = uses_descriptor,
        });
        defer allocator.free(bytes);
        try decodeArchiveFragmented(allocator, bytes, &empty_expected, .{}, 1, 1);
    }

    // The six zero pad bits after two follower-coded 'A' symbols are also
    // valid one-bit follower selections. Descriptor output size must stop the
    // transactional final-byte decode before those pads become extra output.
    const ambiguous_entries = [_]zip.EncodeEntry{.{
        .name = "codec/reduce-padding.bin",
        .data = "AA",
        .method = .reduce_1,
    }};
    const ambiguous_expected = [_]ExpectedEntry{.{
        .name = ambiguous_entries[0].name,
        .data = ambiguous_entries[0].data,
    }};
    const ambiguous_archive = try zip.encodeAlloc(allocator, &ambiguous_entries, .{
        .data_descriptor = true,
    });
    defer allocator.free(ambiguous_archive);
    try decodeArchiveFragmented(allocator, ambiguous_archive, &ambiguous_expected, .{}, 1, 1);

    const limited_entries = [_]zip.EncodeEntry{.{
        .name = "codec/reduce-limit.bin",
        .data = payload,
        .method = .reduce_4,
    }};
    const limited_archive = try zip.encodeAlloc(allocator, &limited_entries, .{});
    defer allocator.free(limited_archive);
    try expectReaderError(allocator, limited_archive, .{
        .max_entry_output_len = payload.len - 1,
    }, error.OutputLimitExceeded);
}

test "ZIP incremental reader streams every traditional Implode mode" {
    const allocator = std.testing.allocator;
    const payload = ("incremental ZIP Implode Shannon-Fano payload\n" ** 173) ++
        ([_]u8{ 0, 1, 2, 3, 4, 5, 0xfe, 0xff } ** 131);
    inline for (.{ zip.ImplodeDictionary.small_4k, .large_8k }) |dictionary| {
        inline for (.{ false, true }) |literal_tree| {
            const entries = [_]zip.EncodeEntry{.{
                .name = "codec/implode.bin",
                .data = payload,
                .method = .implode,
            }};
            const expected = [_]ExpectedEntry{.{ .name = entries[0].name, .data = payload }};
            inline for (.{ false, true }) |uses_descriptor| {
                inline for (.{ zip.Zip64Mode.never, zip.Zip64Mode.always }) |zip64_mode| {
                    const bytes = try zip.encodeAlloc(allocator, &entries, .{
                        .data_descriptor = uses_descriptor,
                        .zip64 = zip64_mode,
                        .implode_options = .{
                            .dictionary = dictionary,
                            .literal_tree = literal_tree,
                        },
                    });
                    defer allocator.free(bytes);
                    try decodeArchiveFragmented(allocator, bytes, &expected, .{}, 1, 1);
                    try decodeArchiveFragmented(allocator, bytes, &expected, .{}, 7, 13);

                    if (uses_descriptor and zip64_mode == .never) {
                        const unsigned = try withoutDescriptorSignature(allocator, bytes);
                        defer allocator.free(unsigned);
                        try decodeArchiveFragmented(allocator, unsigned, &expected, .{}, 1, 3);
                    }
                }
            }
        }
    }

    const empty_entries = [_]zip.EncodeEntry{.{
        .name = "codec/empty-implode",
        .data = "",
        .method = .implode,
    }};
    const empty_expected = [_]ExpectedEntry{.{ .name = empty_entries[0].name, .data = "" }};
    inline for (.{ false, true }) |uses_descriptor| {
        const bytes = try zip.encodeAlloc(allocator, &empty_entries, .{
            .data_descriptor = uses_descriptor,
        });
        defer allocator.free(bytes);
        try decodeArchiveFragmented(allocator, bytes, &empty_expected, .{}, 1, 1);
    }

    const limited_entries = [_]zip.EncodeEntry{.{
        .name = "codec/implode-limit.bin",
        .data = payload,
        .method = .implode,
    }};
    const limited_archive = try zip.encodeAlloc(allocator, &limited_entries, .{});
    defer allocator.free(limited_archive);
    try expectReaderError(allocator, limited_archive, .{
        .max_entry_output_len = payload.len - 1,
    }, error.OutputLimitExceeded);

    const Fixture = struct { encoded: []const u8, name: []const u8 };
    const fixtures = [_]Fixture{
        .{
            .encoded = @embedFile("testdata/commons-compress-implode-4k-2trees.zip.b64"),
            .name = "HEADER.TXT",
        },
        .{
            .encoded = @embedFile("testdata/commons-compress-implode-8k-3trees.zip.b64"),
            .name = "LICENSE.TXT",
        },
    };
    const base64_decoder = std.base64.standard.decoderWithIgnore("\r\n \t");
    for (fixtures) |fixture| {
        const storage = try allocator.alloc(u8, base64_decoder.calcSizeUpperBound(fixture.encoded.len));
        defer allocator.free(storage);
        const archive_len = try base64_decoder.decode(storage, fixture.encoded);
        const archive_bytes = storage[0..archive_len];
        const parsed = try zip.parse(archive_bytes);
        const entry = (try parsed.find(fixture.name)).?;
        const expected_payload = try parsed.extractAlloc(allocator, entry);
        defer allocator.free(expected_payload);
        const expected = [_]ExpectedEntry{.{
            .name = fixture.name,
            .data = expected_payload,
        }};
        try decodeArchiveFragmented(allocator, archive_bytes, &expected, .{}, 1, 1);
        try decodeArchiveFragmented(allocator, archive_bytes, &expected, .{}, 5, 7);
    }
}

test "ZIP incremental reader accepts unsigned Stored and Deflate descriptors" {
    const allocator = std.testing.allocator;
    const cases = [_]struct {
        name: []const u8,
        data: []const u8,
        method: zip.CompressionMethod,
    }{
        .{
            .name = "unsigned-stored.bin",
            .data = "payload PK\x07\x08 false signed descriptor payload",
            .method = .stored,
        },
        .{
            .name = "unsigned-deflate.txt",
            .data = "unsigned deflate descriptor" ** 128,
            .method = .deflate,
        },
    };
    for (cases) |case| {
        const entries = [_]zip.EncodeEntry{.{
            .name = case.name,
            .data = case.data,
            .method = case.method,
        }};
        const signed = try zip.encodeAlloc(allocator, &entries, .{
            .data_descriptor = true,
            .zip64 = .never,
        });
        defer allocator.free(signed);
        const unsigned = try withoutDescriptorSignature(allocator, signed);
        defer allocator.free(unsigned);
        const expected = [_]ExpectedEntry{.{ .name = case.name, .data = case.data }};
        try decodeArchiveFragmented(allocator, unsigned, &expected, .{}, 1, 1);
        try decodeArchiveFragmented(allocator, unsigned, &expected, .{}, 5, 7);
    }

    const collision_prefix = "unsigned CRC equals the descriptor signature ".*;
    const collision_suffix = forgeCrc32Suffix(&collision_prefix, wire.data_descriptor_signature);
    const collision_payload = collision_prefix ++ collision_suffix;
    try std.testing.expectEqual(
        wire.data_descriptor_signature,
        checksum.Crc32Best.hash(&collision_payload),
    );
    const collision_entries = [_]zip.EncodeEntry{.{
        .name = "crc-signature.txt",
        .data = &collision_payload,
        .method = .deflate,
    }};
    const collision_signed = try zip.encodeAlloc(allocator, &collision_entries, .{
        .data_descriptor = true,
        .zip64 = .never,
    });
    defer allocator.free(collision_signed);
    const collision_unsigned = try withoutDescriptorSignature(allocator, collision_signed);
    defer allocator.free(collision_unsigned);
    const collision_expected = [_]ExpectedEntry{.{
        .name = collision_entries[0].name,
        .data = &collision_payload,
    }};
    try decodeArchiveFragmented(allocator, collision_unsigned, &collision_expected, .{}, 1, 1);
}

test "ZIP incremental reader ZIP64 unsigned Stored scanner retains following record" {
    const payload = "unsigned ZIP64 stored descriptor".*;
    var descriptor_bytes: [20]u8 = undefined;
    std.mem.writeInt(u32, descriptor_bytes[0..4], checksum.Crc32Best.hash(&payload), .little);
    std.mem.writeInt(u64, descriptor_bytes[4..12], payload.len, .little);
    std.mem.writeInt(u64, descriptor_bytes[12..20], payload.len, .little);
    var following: [4]u8 = undefined;
    std.mem.writeInt(u32, &following, wire.central_file_signature, .little);
    const input = payload ++ descriptor_bytes ++ following;
    var scanner = descriptor.StoredScanner.init(.zip64, payload.len);
    var decoded: [payload.len]u8 = undefined;
    const stepped = try scanner.step(&input, &decoded);
    try std.testing.expectEqual(descriptor.StepResult.Status.done, stepped.status);
    try std.testing.expectEqualSlices(u8, &payload, &decoded);
    try std.testing.expectEqualSlices(u8, &following, scanner.retainedRecordPrefix());
    try std.testing.expect(!scanner.descriptor().?.signed);
}

test "ZIP incremental reader handles known-size entries empty archives and reset" {
    const allocator = std.testing.allocator;
    const stored = "known stored";
    const deflated = "known deflate" ** 48;
    const entries = [_]zip.EncodeEntry{
        .{ .name = "known.bin", .data = stored, .method = .stored },
        .{ .name = "known.txt", .data = deflated, .method = .deflate },
    };
    const expected = [_]ExpectedEntry{
        .{ .name = entries[0].name, .data = stored },
        .{ .name = entries[1].name, .data = deflated },
    };
    const bytes = try zip.encodeAlloc(allocator, &entries, .{
        .data_descriptor = false,
        .archive_comment = "known sizes",
    });
    defer allocator.free(bytes);
    try decodeArchiveFragmented(allocator, bytes, &expected, .{}, 2, 3);
    const reordered = try reverseTwoCentralRecords(allocator, bytes);
    defer allocator.free(reordered);
    try decodeArchiveFragmented(allocator, reordered, &expected, .{}, 1, 2);
    const signed_central = try withCentralDigitalSignature(allocator, bytes, "signed central directory");
    defer allocator.free(signed_central);
    try decodeArchiveFragmented(allocator, signed_central, &expected, .{}, 1, 1);

    const empty_entries: [0]zip.EncodeEntry = .{};
    const empty = try zip.encodeAlloc(allocator, &empty_entries, .{
        .archive_comment = "empty archive",
    });
    defer allocator.free(empty);
    try decodeArchiveFragmented(allocator, empty, &.{}, .{}, 1, 1);

    var reader = try incremental.Reader.init(allocator);
    defer reader.deinit();
    var scratch: [4096]u8 = undefined;
    var first_offset: usize = 0;
    while (true) {
        const stepped = try reader.step(bytes[first_offset..], &scratch);
        first_offset += stepped.progress.input_read;
        if (stepped.status == .done) break;
    }
    try std.testing.expectEqual(@as(usize, 2), reader.snapshot().completed_entries);
    reader.reset();
    var empty_offset: usize = 0;
    while (true) {
        const stepped = try reader.step(empty[empty_offset..], &scratch);
        empty_offset += stepped.progress.input_read;
        if (stepped.status == .done) break;
    }
    try std.testing.expectEqual(@as(usize, 0), reader.snapshot().completed_entries);
    try std.testing.expectEqualStrings("empty archive", reader.archiveComment());

    const prefix = "MZ incremental reader prefix\n";
    var prefixed: std.ArrayList(u8) = .empty;
    defer prefixed.deinit(allocator);
    try prefixed.appendSlice(allocator, prefix);
    _ = try zip.encodeAppend(allocator, &prefixed, &entries, .{
        .data_descriptor = true,
    });
    try decodeArchiveFragmented(
        allocator,
        prefixed.items[prefix.len..],
        &expected,
        .{ .initial_offset = prefix.len },
        3,
        5,
    );
}

test "ZIP incremental reader streams known-size Traditional ZipCrypto entries" {
    const allocator = std.testing.allocator;
    const password = "sequential-reader-password";
    const stored = "known encrypted stored payload" ** 37;
    const deflated = "known encrypted Deflate payload\n" ** 83;
    const imploded = "known encrypted Implode payload\n" ** 79;
    const bzip2_data = "known encrypted Bzip2 payload\n" ** 73;
    const entries = [_]zip.EncodeEntry{
        .{
            .name = "encrypted/stored.bin",
            .data = stored,
            .method = .stored,
            .traditional_encryption = .{
                .password = password,
                .header_random = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            },
        },
        .{
            .name = "encrypted/deflate.txt",
            .data = deflated,
            .method = .deflate,
            .traditional_encryption = .{
                .password = password,
                .header_random = .{ 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 },
            },
        },
        .{
            .name = "encrypted/implode.txt",
            .data = imploded,
            .method = .implode,
            .traditional_encryption = .{
                .password = password,
                .header_random = .{ 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a },
            },
        },
        .{
            .name = "encrypted/bzip2.txt",
            .data = bzip2_data,
            .method = .bzip2,
            .traditional_encryption = .{
                .password = password,
                .header_random = .{ 0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa },
            },
        },
    };
    const expected = [_]ExpectedEntry{
        .{ .name = entries[0].name, .data = stored },
        .{ .name = entries[1].name, .data = deflated },
        .{ .name = entries[2].name, .data = imploded },
        .{ .name = entries[3].name, .data = bzip2_data },
    };
    const bytes = try zip.encodeAlloc(allocator, &entries, .{ .data_descriptor = false });
    defer allocator.free(bytes);
    try decodeArchiveFragmented(allocator, bytes, &expected, .{ .password = password }, 1, 1);
    try decodeArchiveFragmented(allocator, bytes, &expected, .{ .password = password }, 7, 13);
    try decodeArchiveFragmented(allocator, bytes, &expected, .{ .password = password }, 4096, 31);
    try std.testing.expectError(
        error.PasswordRequired,
        decodeArchiveFragmented(allocator, bytes, &expected, .{}, 3, 5),
    );
    try std.testing.expectError(
        error.InvalidZipPassword,
        decodeArchiveFragmented(allocator, bytes, &expected, .{ .password = "wrong" }, 3, 5),
    );

    const descriptor_bytes = try zip.encodeAlloc(allocator, &entries, .{
        .data_descriptor = true,
    });
    defer allocator.free(descriptor_bytes);
    try decodeArchiveFragmented(
        allocator,
        descriptor_bytes,
        &expected,
        .{ .password = password },
        1,
        1,
    );
    try decodeArchiveFragmented(allocator, descriptor_bytes, &expected, .{ .password = password }, 97, 31);
}

test "ZIP incremental reader streams descriptor Traditional ZipCrypto across every codec" {
    const allocator = std.testing.allocator;
    const password = "descriptor-encryption-password";
    const payload = "encrypted descriptor payload spanning every ZIP codec\n" ** 37;
    const encryption: zip.TraditionalEncryptionOptions = .{
        .password = password,
        .header_random = .{ 0x31, 0x41, 0x59, 0x26, 0x53, 0x58, 0x97, 0x93, 0x23, 0x84, 0x62 },
    };
    const methods = [_]zip.CompressionMethod{
        .stored,
        .shrink,
        .reduce_1,
        .implode,
        .deflate,
        .deflate64,
        .dcl_implode,
        .bzip2,
        .lzma,
        .zstandard_legacy,
        .zstandard,
        .xz,
        .ppmd,
    };
    const names = [_][]const u8{
        "encrypted/stored.bin",
        "encrypted/shrink.bin",
        "encrypted/reduce.bin",
        "encrypted/implode.bin",
        "encrypted/deflate.bin",
        "encrypted/deflate64.bin",
        "encrypted/dcl.bin",
        "encrypted/bzip2.bin",
        "encrypted/lzma.bin",
        "encrypted/zstd-legacy.bin",
        "encrypted/zstd.bin",
        "encrypted/xz.bin",
        "encrypted/ppmd.bin",
    };
    var entries: [methods.len]zip.EncodeEntry = undefined;
    var expected: [methods.len]ExpectedEntry = undefined;
    for (methods, names, 0..) |method, name, index| {
        entries[index] = .{
            .name = name,
            .data = payload,
            .method = method,
            .traditional_encryption = encryption,
        };
        expected[index] = .{ .name = name, .data = payload };
    }

    inline for (.{ zip.Zip64Mode.never, zip.Zip64Mode.always }) |zip64_mode| {
        const bytes = try zip.encodeAlloc(allocator, &entries, .{
            .data_descriptor = true,
            .zip64 = zip64_mode,
            .ppmd_options = .{ .memory_size = 1024 * 1024 },
        });
        defer allocator.free(bytes);
        try decodeArchiveFragmented(allocator, bytes, &expected, .{ .password = password }, 1, 1);
        try decodeArchiveFragmented(allocator, bytes, &expected, .{ .password = password }, 257, 31);
        try std.testing.expectError(
            error.PasswordRequired,
            decodeArchiveFragmented(allocator, bytes, &expected, .{}, 3, 5),
        );
        try std.testing.expectError(
            error.InvalidZipPassword,
            decodeArchiveFragmented(allocator, bytes, &expected, .{ .password = "wrong" }, 3, 5),
        );
        if (zip64_mode == .never) {
            const archive = try zip.parse(bytes);
            const first = try archive.entryAt(0);
            try std.testing.expect(first.crc32 >> 24 != 0);
            const local_offset = first.local_header_offset;
            const name_len = std.mem.readInt(u16, bytes[local_offset + 26 ..][0..2], .little);
            const extra_len = std.mem.readInt(u16, bytes[local_offset + 28 ..][0..2], .little);
            const data_offset = local_offset + wire.local_file_header_len + name_len + extra_len;

            const wrong_time = try allocator.dupe(u8, bytes);
            defer allocator.free(wrong_time);
            wrong_time[local_offset + 11] = 1;
            try expectReaderError(
                allocator,
                wrong_time,
                .{ .password = password },
                error.InvalidZipPassword,
            );

            const corrupt_header = try allocator.dupe(u8, bytes);
            defer allocator.free(corrupt_header);
            corrupt_header[data_offset + 11] ^= 1;
            try expectReaderError(
                allocator,
                corrupt_header,
                .{ .password = password },
                error.InvalidZipPassword,
            );

            const strong = try allocator.dupe(u8, bytes);
            defer allocator.free(strong);
            const strong_flags = std.mem.readInt(u16, strong[local_offset + 6 ..][0..2], .little) | (1 << 6);
            std.mem.writeInt(u16, strong[local_offset + 6 ..][0..2], strong_flags, .little);
            try expectReaderError(
                allocator,
                strong,
                .{ .password = password },
                error.UnsupportedZipFeature,
            );

            const corrupt_descriptor = try allocator.dupe(u8, bytes);
            defer allocator.free(corrupt_descriptor);
            const descriptor_offset = data_offset + first.compressed_size;
            try std.testing.expectEqual(
                wire.data_descriptor_signature,
                std.mem.readInt(u32, corrupt_descriptor[descriptor_offset..][0..4], .little),
            );
            corrupt_descriptor[descriptor_offset + 4] ^= 1;
            try expectReaderError(
                allocator,
                corrupt_descriptor,
                .{ .password = password },
                error.TruncatedFrame,
            );
        }
    }

    inline for (.{ zip.Zip64Mode.never, zip.Zip64Mode.always }) |zip64_mode| {
        inline for (.{
            zip.CompressionMethod.stored,
            zip.CompressionMethod.shrink,
            zip.CompressionMethod.reduce_1,
            zip.CompressionMethod.implode,
            zip.CompressionMethod.deflate,
            zip.CompressionMethod.dcl_implode,
            zip.CompressionMethod.bzip2,
        }) |method| {
            const single_entries = [_]zip.EncodeEntry{.{
                .name = "encrypted/unsigned.bin",
                .data = payload,
                .method = method,
                .traditional_encryption = encryption,
            }};
            const single_expected = [_]ExpectedEntry{.{
                .name = single_entries[0].name,
                .data = payload,
            }};
            const signed = try zip.encodeAlloc(allocator, &single_entries, .{
                .data_descriptor = true,
                .zip64 = zip64_mode,
            });
            defer allocator.free(signed);
            const unsigned = try withoutDescriptorSignature(allocator, signed);
            defer allocator.free(unsigned);
            try decodeArchiveFragmented(
                allocator,
                unsigned,
                &single_expected,
                .{ .password = password },
                1,
                1,
            );
        }
    }
}

test "ZIP incremental reader streams known-size WinZip AES entries" {
    const allocator = std.testing.allocator;
    const password = "sequential WinZip AES password";
    const stored = "known AES stored payload" ** 31;
    const deflated = "known AES Deflate payload\n" ** 79;
    const bzip2_data = "known AES Bzip2 payload\n" ** 67;
    const salt128 = [_]u8{0x51} ** 8;
    const salt192 = [_]u8{0x52} ** 12;
    const salt256 = [_]u8{0x53} ** 16;
    const entries = [_]zip.EncodeEntry{
        .{
            .name = "aes/stored.bin",
            .data = stored,
            .method = .stored,
            .winzip_aes = .{
                .password = password,
                .strength = .aes128,
                .salt = &salt128,
                .version = .ae1,
            },
        },
        .{
            .name = "aes/deflate.txt",
            .data = deflated,
            .method = .deflate,
            .winzip_aes = .{
                .password = password,
                .strength = .aes192,
                .salt = &salt192,
                .version = .ae2,
            },
        },
        .{
            .name = "aes/bzip2.txt",
            .data = bzip2_data,
            .method = .bzip2,
            .winzip_aes = .{
                .password = password,
                .strength = .aes256,
                .salt = &salt256,
                .version = .ae1,
            },
        },
    };
    const expected = [_]ExpectedEntry{
        .{ .name = entries[0].name, .data = stored },
        .{ .name = entries[1].name, .data = deflated },
        .{ .name = entries[2].name, .data = bzip2_data },
    };
    const bytes = try zip.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(bytes);
    try decodeArchiveFragmented(allocator, bytes, &expected, .{ .password = password }, 1, 1);
    try decodeArchiveFragmented(allocator, bytes, &expected, .{ .password = password }, 257, 31);
    try std.testing.expectError(
        error.PasswordRequired,
        decodeArchiveFragmented(allocator, bytes, &expected, .{}, 3, 5),
    );
    try std.testing.expectError(
        error.InvalidZipPassword,
        decodeArchiveFragmented(allocator, bytes, &expected, .{ .password = "wrong" }, 3, 5),
    );

    const archive = try zip.parse(bytes);
    const first = try archive.entryAt(0);
    const name_len = std.mem.readInt(u16, bytes[first.local_header_offset + 26 ..][0..2], .little);
    const extra_len = std.mem.readInt(u16, bytes[first.local_header_offset + 28 ..][0..2], .little);
    const data_offset = first.local_header_offset + wire.local_file_header_len + name_len + extra_len;
    const corrupt = try allocator.dupe(u8, bytes);
    defer allocator.free(corrupt);
    corrupt[data_offset + first.compressed_size - 1] ^= 1;
    try expectReaderError(
        allocator,
        corrupt,
        .{ .password = password },
        error.InvalidAuthenticationCode,
    );

    const descriptor_bytes = try zip.encodeAlloc(allocator, entries[0..1], .{ .data_descriptor = true });
    defer allocator.free(descriptor_bytes);
    try decodeArchiveFragmented(
        allocator,
        descriptor_bytes,
        expected[0..1],
        .{ .password = password },
        1,
        1,
    );
}

test "ZIP incremental reader streams known-size PKWARE Strong AES entries" {
    const allocator = std.testing.allocator;
    const password = "sequential PKWARE Strong password";
    const stored = "known PKWARE Strong stored payload" ** 31;
    const deflated = "known PKWARE Strong Deflate payload\n" ** 79;
    const bzip2_data = "known PKWARE Strong Bzip2 payload\n" ** 67;
    const iv128 = [_]u8{0x61} ** 16;
    const iv192 = [_]u8{0x62} ** 16;
    const iv256 = [_]u8{0x63} ** 16;
    const random128 = [_]u8{0x71} ** 16;
    const random192 = [_]u8{0x72} ** 16;
    const random256 = [_]u8{0x73} ** 32;
    const validation128 = [_]u8{0x81} ** 12;
    const validation192 = [_]u8{0x82} ** 12;
    const validation256 = [_]u8{0x83} ** 12;
    const entries = [_]zip.EncodeEntry{
        .{
            .name = "strong/stored.bin",
            .data = stored,
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
            .name = "strong/deflate.txt",
            .data = deflated,
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
            .name = "strong/bzip2.txt",
            .data = bzip2_data,
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
    const expected = [_]ExpectedEntry{
        .{ .name = entries[0].name, .data = stored },
        .{ .name = entries[1].name, .data = deflated },
        .{ .name = entries[2].name, .data = bzip2_data },
    };
    const bytes = try zip.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(bytes);
    try decodeArchiveFragmented(allocator, bytes, &expected, .{ .password = password }, 1, 1);
    try decodeArchiveFragmented(allocator, bytes, &expected, .{ .password = password }, 257, 31);
    try std.testing.expectError(
        error.PasswordRequired,
        decodeArchiveFragmented(allocator, bytes, &expected, .{}, 3, 5),
    );
    try std.testing.expectError(
        error.InvalidPasswordValidation,
        decodeArchiveFragmented(allocator, bytes, &expected, .{ .password = "wrong" }, 3, 5),
    );

    const archive = try zip.parse(bytes);
    const first = try archive.entryAt(0);
    const name_len: usize = std.mem.readInt(
        u16,
        bytes[first.local_header_offset + 26 ..][0..2],
        .little,
    );
    const extra_len: usize = std.mem.readInt(
        u16,
        bytes[first.local_header_offset + 28 ..][0..2],
        .little,
    );
    const data_offset = first.local_header_offset + wire.local_file_header_len + name_len + extra_len;
    const random_size: usize = std.mem.readInt(u16, bytes[data_offset + 30 ..][0..2], .little);
    const validation_offset = data_offset + 32 + random_size + 4 + 2;
    const bad_validation = try allocator.dupe(u8, bytes);
    defer allocator.free(bad_validation);
    bad_validation[validation_offset] ^= 1;
    try expectReaderError(
        allocator,
        bad_validation,
        .{ .password = password },
        error.InvalidPasswordValidation,
    );
    const bad_padding = try allocator.dupe(u8, bytes);
    defer allocator.free(bad_padding);
    bad_padding[data_offset + first.compressed_size - 1] ^= 1;
    try expectReaderError(
        allocator,
        bad_padding,
        .{ .password = password },
        error.InvalidPadding,
    );
    try expectReaderError(
        allocator,
        bytes,
        .{ .password = password, .max_control_record_size = 64 },
        error.OutputLimitExceeded,
    );

    const descriptor_bytes = try zip.encodeAlloc(allocator, entries[0..1], .{
        .data_descriptor = true,
    });
    defer allocator.free(descriptor_bytes);
    try decodeArchiveFragmented(
        allocator,
        descriptor_bytes,
        expected[0..1],
        .{ .password = password },
        1,
        1,
    );
    try std.testing.expectError(
        error.InvalidPasswordValidation,
        decodeArchiveFragmented(
            allocator,
            descriptor_bytes,
            expected[0..1],
            .{ .password = "wrong" },
            3,
            5,
        ),
    );
    const descriptor_archive = try zip.parse(descriptor_bytes);
    const descriptor_entry = try descriptor_archive.entryAt(0);
    const descriptor_name_len: usize = std.mem.readInt(
        u16,
        descriptor_bytes[descriptor_entry.local_header_offset + 26 ..][0..2],
        .little,
    );
    const descriptor_extra_len: usize = std.mem.readInt(
        u16,
        descriptor_bytes[descriptor_entry.local_header_offset + 28 ..][0..2],
        .little,
    );
    const descriptor_data_offset = descriptor_entry.local_header_offset +
        wire.local_file_header_len + descriptor_name_len + descriptor_extra_len;
    const descriptor_offset = descriptor_data_offset + descriptor_entry.compressed_size;
    const bad_descriptor = try allocator.dupe(u8, descriptor_bytes);
    defer allocator.free(bad_descriptor);
    bad_descriptor[descriptor_offset + 4] ^= 1;
    try expectReaderError(
        allocator,
        bad_descriptor,
        .{ .password = password },
        error.InvalidZipArchive,
    );
}

test "ZIP incremental reader PKWARE Strong path releases allocation failures" {
    const allocator = std.testing.allocator;
    const payload = "allocation-safe sequential strong payload";
    const iv = [_]u8{0xb1} ** 16;
    const random_data = [_]u8{0xb2} ** 16;
    const validation_data = [_]u8{0xb3} ** 12;
    const entries = [_]zip.EncodeEntry{.{
        .name = "strong/oom.bin",
        .data = payload,
        .method = .stored,
        .pkware_strong_encryption = .{
            .password = "password",
            .iv = iv,
            .random_data = &random_data,
            .validation_data = &validation_data,
        },
    }};
    const bytes = try zip.encodeAlloc(allocator, &entries, .{ .data_descriptor = true });
    defer allocator.free(bytes);
    const Test = struct {
        fn run(
            failing_allocator: std.mem.Allocator,
            archive: []const u8,
            plain: []const u8,
        ) !void {
            const expected = [_]ExpectedEntry{.{
                .name = "strong/oom.bin",
                .data = plain,
            }};
            try decodeArchiveFragmented(
                failing_allocator,
                archive,
                &expected,
                .{ .password = "password" },
                3,
                5,
            );
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{ bytes, payload },
    );
}

test "ZIP incremental reader streams known-size PKWARE Strong across every codec" {
    const allocator = std.testing.allocator;
    const password = "all-codec PKWARE Strong password";
    const payload = "known PKWARE Strong payload spanning every ZIP codec\n" ** 37;
    const iv = [_]u8{0x91} ** 16;
    const random_data = [_]u8{0x92} ** 32;
    const validation_data = [_]u8{0x93} ** 12;
    const methods = [_]zip.CompressionMethod{
        .stored,
        .shrink,
        .reduce_1,
        .implode,
        .deflate,
        .deflate64,
        .dcl_implode,
        .bzip2,
        .lzma,
        .zstandard_legacy,
        .zstandard,
        .xz,
        .ppmd,
    };
    var entries: [methods.len]zip.EncodeEntry = undefined;
    var expected: [methods.len]ExpectedEntry = undefined;
    var names: [methods.len][32]u8 = undefined;
    var name_lengths: [methods.len]usize = undefined;
    for (methods, 0..) |method, index| {
        const name = try std.fmt.bufPrint(&names[index], "strong/codec-{d}.bin", .{index});
        name_lengths[index] = name.len;
        entries[index] = .{
            .name = names[index][0..name_lengths[index]],
            .data = payload,
            .method = method,
            .pkware_strong_encryption = .{
                .password = password,
                .strength = .aes256,
                .iv = iv,
                .random_data = &random_data,
                .validation_data = &validation_data,
            },
        };
        expected[index] = .{ .name = entries[index].name, .data = payload };
    }
    inline for (.{ zip.Zip64Mode.never, .always }) |zip64_mode| {
        const bytes = try zip.encodeAlloc(allocator, &entries, .{
            .zip64 = zip64_mode,
            .ppmd_options = .{ .memory_size = 1024 * 1024 },
        });
        defer allocator.free(bytes);
        try decodeArchiveFragmented(
            allocator,
            bytes,
            &expected,
            .{ .password = password },
            1,
            1,
        );
        try decodeArchiveFragmented(
            allocator,
            bytes,
            &expected,
            .{ .password = password },
            257,
            31,
        );
        const descriptor_bytes = try zip.encodeAlloc(allocator, &entries, .{
            .data_descriptor = true,
            .zip64 = zip64_mode,
            .ppmd_options = .{ .memory_size = 1024 * 1024 },
        });
        defer allocator.free(descriptor_bytes);
        try decodeArchiveFragmented(
            allocator,
            descriptor_bytes,
            &expected,
            .{ .password = password },
            1,
            1,
        );
        try decodeArchiveFragmented(
            allocator,
            descriptor_bytes,
            &expected,
            .{ .password = password },
            257,
            31,
        );
    }
}

test "ZIP incremental reader accepts unsigned PKWARE Strong descriptors" {
    const allocator = std.testing.allocator;
    const password = "unsigned PKWARE Strong password";
    const payload = "unsigned PKWARE Strong descriptor payload\n" ** 41;
    const iv = [_]u8{0xa1} ** 16;
    const random_data = [_]u8{0xa2} ** 16;
    const validation_data = [_]u8{0xa3} ** 12;
    inline for (.{ zip.Zip64Mode.never, .always }) |zip64_mode| {
        inline for (.{
            zip.CompressionMethod.stored,
            zip.CompressionMethod.shrink,
            zip.CompressionMethod.reduce_1,
            zip.CompressionMethod.implode,
            zip.CompressionMethod.deflate,
            zip.CompressionMethod.bzip2,
        }) |method| {
            const entries = [_]zip.EncodeEntry{.{
                .name = "strong/unsigned.bin",
                .data = payload,
                .method = method,
                .pkware_strong_encryption = .{
                    .password = password,
                    .iv = iv,
                    .random_data = &random_data,
                    .validation_data = &validation_data,
                },
            }};
            const expected = [_]ExpectedEntry{.{
                .name = entries[0].name,
                .data = payload,
            }};
            const signed = try zip.encodeAlloc(allocator, &entries, .{
                .data_descriptor = true,
                .zip64 = zip64_mode,
            });
            defer allocator.free(signed);
            const unsigned = try withoutDescriptorSignature(allocator, signed);
            defer allocator.free(unsigned);
            try decodeArchiveFragmented(
                allocator,
                unsigned,
                &expected,
                .{ .password = password },
                1,
                1,
            );
        }
    }
}

test "ZIP incremental reader streams descriptor WinZip AES across every codec" {
    const allocator = std.testing.allocator;
    const password = "descriptor WinZip AES password";
    const payload = "authenticated descriptor payload spanning every ZIP codec\n" ** 37;
    const salt = [_]u8{0x6a} ** 16;
    const methods = [_]zip.CompressionMethod{
        .stored,
        .shrink,
        .reduce_1,
        .implode,
        .deflate,
        .deflate64,
        .dcl_implode,
        .bzip2,
        .lzma,
        .zstandard_legacy,
        .zstandard,
        .xz,
        .ppmd,
    };
    const names = [_][]const u8{
        "aes-descriptor/stored.bin",
        "aes-descriptor/shrink.bin",
        "aes-descriptor/reduce.bin",
        "aes-descriptor/implode.bin",
        "aes-descriptor/deflate.bin",
        "aes-descriptor/deflate64.bin",
        "aes-descriptor/dcl.bin",
        "aes-descriptor/bzip2.bin",
        "aes-descriptor/lzma.bin",
        "aes-descriptor/zstd-legacy.bin",
        "aes-descriptor/zstd.bin",
        "aes-descriptor/xz.bin",
        "aes-descriptor/ppmd.bin",
    };
    var entries: [methods.len]zip.EncodeEntry = undefined;
    var expected: [methods.len]ExpectedEntry = undefined;

    inline for (.{ zip.WinZipAesVendorVersion.ae1, .ae2 }) |version| {
        for (methods, names, 0..) |method, name, index| {
            entries[index] = .{
                .name = name,
                .data = payload,
                .method = method,
                .winzip_aes = .{
                    .password = password,
                    .strength = .aes256,
                    .salt = &salt,
                    .version = version,
                },
            };
            expected[index] = .{ .name = name, .data = payload };
        }
        inline for (.{ zip.Zip64Mode.never, .always }) |zip64_mode| {
            const bytes = try zip.encodeAlloc(allocator, &entries, .{
                .data_descriptor = true,
                .zip64 = zip64_mode,
                .ppmd_options = .{ .memory_size = 1024 * 1024 },
            });
            defer allocator.free(bytes);
            try decodeArchiveFragmented(
                allocator,
                bytes,
                &expected,
                .{ .password = password },
                1,
                1,
            );
            try decodeArchiveFragmented(
                allocator,
                bytes,
                &expected,
                .{ .password = password },
                257,
                31,
            );
            try std.testing.expectError(
                error.InvalidZipPassword,
                decodeArchiveFragmented(
                    allocator,
                    bytes,
                    &expected,
                    .{ .password = "wrong" },
                    3,
                    5,
                ),
            );

            if (version == .ae1 and zip64_mode == .never) {
                const archive = try zip.parse(bytes);
                const first = try archive.entryAt(0);
                const name_len = std.mem.readInt(
                    u16,
                    bytes[first.local_header_offset + 26 ..][0..2],
                    .little,
                );
                const extra_len = std.mem.readInt(
                    u16,
                    bytes[first.local_header_offset + 28 ..][0..2],
                    .little,
                );
                const data_offset = first.local_header_offset + wire.local_file_header_len +
                    name_len + extra_len;
                const corrupt = try allocator.dupe(u8, bytes);
                defer allocator.free(corrupt);
                corrupt[data_offset + first.compressed_size - 1] ^= 1;
                try expectReaderError(
                    allocator,
                    corrupt,
                    .{ .password = password },
                    error.InvalidAuthenticationCode,
                );
            }
        }
    }

    inline for (.{ zip.Zip64Mode.never, .always }) |zip64_mode| {
        inline for (.{
            zip.CompressionMethod.stored,
            zip.CompressionMethod.shrink,
            zip.CompressionMethod.reduce_1,
            zip.CompressionMethod.implode,
            zip.CompressionMethod.deflate,
            zip.CompressionMethod.dcl_implode,
            zip.CompressionMethod.bzip2,
        }) |method| {
            const single_entries = [_]zip.EncodeEntry{.{
                .name = "aes-descriptor/unsigned.bin",
                .data = payload,
                .method = method,
                .winzip_aes = .{
                    .password = password,
                    .strength = .aes256,
                    .salt = &salt,
                    .version = .ae2,
                },
            }};
            const single_expected = [_]ExpectedEntry{.{
                .name = single_entries[0].name,
                .data = payload,
            }};
            const signed = try zip.encodeAlloc(allocator, &single_entries, .{
                .data_descriptor = true,
                .zip64 = zip64_mode,
            });
            defer allocator.free(signed);
            const unsigned = try withoutDescriptorSignature(allocator, signed);
            defer allocator.free(unsigned);
            try decodeArchiveFragmented(
                allocator,
                unsigned,
                &single_expected,
                .{ .password = password },
                1,
                1,
            );
        }
    }

    const nonzero_crc_entries = [_]zip.EncodeEntry{.{
        .name = "aes-descriptor/ae2-nonzero-crc.bin",
        .data = payload,
        .method = .deflate,
        .winzip_aes = .{
            .password = password,
            .strength = .aes256,
            .salt = &salt,
            .version = .ae2,
        },
    }};
    const nonzero_crc_expected = [_]ExpectedEntry{.{
        .name = nonzero_crc_entries[0].name,
        .data = payload,
    }};
    const canonical = try zip.encodeAlloc(allocator, &nonzero_crc_entries, .{
        .data_descriptor = true,
        .zip64 = .never,
    });
    defer allocator.free(canonical);
    const canonical_archive = try zip.parse(canonical);
    const canonical_entry = try canonical_archive.entryAt(0);
    const local_name_len = std.mem.readInt(
        u16,
        canonical[canonical_entry.local_header_offset + 26 ..][0..2],
        .little,
    );
    const local_extra_len = std.mem.readInt(
        u16,
        canonical[canonical_entry.local_header_offset + 28 ..][0..2],
        .little,
    );
    const data_offset = canonical_entry.local_header_offset + wire.local_file_header_len +
        local_name_len + local_extra_len;
    const descriptor_offset = data_offset + canonical_entry.compressed_size;
    const nonzero_crc = try allocator.dupe(u8, canonical);
    defer allocator.free(nonzero_crc);
    const ignored_crc: u32 = 0xa5c3_19e7;
    std.mem.writeInt(u32, nonzero_crc[descriptor_offset + 4 ..][0..4], ignored_crc, .little);
    std.mem.writeInt(
        u32,
        nonzero_crc[canonical_entry.central_header_offset + 16 ..][0..4],
        ignored_crc,
        .little,
    );
    try decodeArchiveFragmented(
        allocator,
        nonzero_crc,
        &nonzero_crc_expected,
        .{ .password = password },
        3,
        7,
    );
}

test "ZIP incremental reader enforces backpressure limits central validation and truncation" {
    const allocator = std.testing.allocator;
    const payload = "bounded archive payload" ** 32;
    const entries = [_]zip.EncodeEntry{
        .{ .name = "bounded.bin", .data = payload, .method = .stored },
    };
    const bytes = try zip.encodeAlloc(allocator, &entries, .{
        .data_descriptor = true,
    });
    defer allocator.free(bytes);

    var blocked = try incremental.Reader.init(allocator);
    defer blocked.deinit();
    var input_offset: usize = 0;
    while (true) {
        const stepped = try blocked.step(bytes[input_offset..], &.{});
        input_offset += stepped.progress.input_read;
        try std.testing.expectEqual(@as(usize, 0), stepped.progress.output_written);
        if (stepped.status == .need_output) break;
        try std.testing.expect(stepped.status == .entry_header or stepped.status == .need_input);
    }
    try std.testing.expect(input_offset < bytes.len);

    try expectReaderError(allocator, bytes, .{
        .max_entry_output_len = payload.len - 1,
    }, error.OutputLimitExceeded);
    try expectReaderError(allocator, bytes, .{
        .max_total_output_len = payload.len - 1,
    }, error.OutputLimitExceeded);
    try expectReaderError(allocator, bytes, .{
        .max_entries = 0,
    }, error.OutputLimitExceeded);
    try expectReaderError(allocator, bytes, .{
        .max_metadata_size = 0,
    }, error.OutputLimitExceeded);
    try expectReaderError(allocator, bytes, .{
        .max_central_directory_size = 1,
    }, error.OutputLimitExceeded);

    const parsed = try zip.parse(bytes);
    const entry = try parsed.entryAt(0);
    const corrupt = try allocator.dupe(u8, bytes);
    defer allocator.free(corrupt);
    corrupt[entry.central_header_offset + 16] ^= 1;
    try expectReaderError(allocator, corrupt, .{}, error.InvalidZipArchive);

    const zip64 = try zip.encodeAlloc(allocator, &entries, .{
        .data_descriptor = true,
        .zip64 = .always,
    });
    defer allocator.free(zip64);
    const corrupt_locator = try allocator.dupe(u8, zip64);
    defer allocator.free(corrupt_locator);
    const eocd_offset = zip64.len - wire.end_of_central_len;
    const locator_offset = eocd_offset - wire.zip64_end_of_central_locator_len;
    corrupt_locator[locator_offset + 8] ^= 1;
    try expectReaderError(allocator, corrupt_locator, .{}, error.UnsupportedZipFeature);

    var truncated = try incremental.Reader.init(allocator);
    defer truncated.deinit();
    var scratch: [4096]u8 = undefined;
    var truncated_offset: usize = 0;
    const short = bytes[0 .. bytes.len - 1];
    while (truncated_offset < short.len) {
        const stepped = try truncated.step(short[truncated_offset..], &scratch);
        truncated_offset += stepped.progress.input_read;
        if (stepped.status == .done) return error.TestUnexpectedResult;
        if (stepped.status == .need_input and truncated_offset == short.len) break;
    }
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());

    const with_suffix = try std.mem.concat(allocator, u8, &.{ bytes, "suffix" });
    defer allocator.free(with_suffix);
    try expectReaderError(allocator, with_suffix, .{}, error.TrailingData);
    var trailing = try incremental.Reader.initWithOptions(allocator, .{
        .allow_trailing_data = true,
    });
    defer trailing.deinit();
    var trailing_offset: usize = 0;
    while (true) {
        const stepped = try trailing.step(with_suffix[trailing_offset..], &scratch);
        trailing_offset += stepped.progress.input_read;
        if (stepped.status == .done) break;
    }
    try std.testing.expectEqual(bytes.len, trailing_offset);
}
