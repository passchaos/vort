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

fn withoutDescriptorSignature(
    allocator: std.mem.Allocator,
    signed_archive: []const u8,
) ![]u8 {
    const archive = try zip.parse(signed_archive);
    try std.testing.expectEqual(@as(usize, 1), archive.entry_count);
    try std.testing.expect(!archive.zip64);
    const entry = try archive.entryAt(0);
    const compressed = try archive.compressedData(entry);
    const descriptor_offset = @intFromPtr(compressed.ptr) - @intFromPtr(signed_archive.ptr) + compressed.len;
    try std.testing.expectEqual(
        @as(u32, 0x0807_4b50),
        std.mem.readInt(u32, signed_archive[descriptor_offset..][0..4], .little),
    );
    const unsigned = try allocator.alloc(u8, signed_archive.len - 4);
    errdefer allocator.free(unsigned);
    @memcpy(unsigned[0..descriptor_offset], signed_archive[0..descriptor_offset]);
    @memcpy(unsigned[descriptor_offset..], signed_archive[descriptor_offset + 4 ..]);
    const eocd_offset = unsigned.len - 22 - archive.comment.len;
    std.mem.writeInt(
        u32,
        unsigned[eocd_offset + 16 ..][0..4],
        @intCast(archive.central_directory_offset - 4),
        .little,
    );
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
