const std = @import("std");
const checksum = @import("../checksum.zig");
const deflate = @import("../deflate.zig");
const zip = @import("../zip.zig");
const incremental = @import("incremental_entry_decoder.zig");
const zstd = @import("../zstd.zig");

const DecodeResult = struct {
    bytes: []u8,
    input_read: usize,
};

fn testEntry(
    name: []const u8,
    method: zip.CompressionMethod,
    compressed_size: usize,
    payload: []const u8,
) zip.Entry {
    return .{
        .name = name,
        .method = method,
        .flags = 0,
        .crc32 = checksum.Crc32Best.hash(payload),
        .compressed_size = compressed_size,
        .uncompressed_size = payload.len,
        .local_header_offset = 0,
        .central_header_offset = 0,
        .zip64 = false,
    };
}

fn decodeFragmented(
    allocator: std.mem.Allocator,
    decoder: anytype,
    input: []const u8,
    input_chunk_len: usize,
    output_chunk_len: usize,
) !DecodeResult {
    std.debug.assert(input_chunk_len != 0);
    std.debug.assert(output_chunk_len != 0 and output_chunk_len <= 31);
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(allocator);
    var input_offset: usize = 0;
    var calls: usize = 0;
    const max_calls = input.len * 8 + decoder.snapshot().expected_output_len * 2 + 1024;
    while (true) {
        calls += 1;
        if (calls > max_calls) return error.TestUnexpectedResult;
        const input_end = @min(input.len, input_offset + input_chunk_len);
        var output: [31]u8 = undefined;
        const result = try decoder.step(
            input[input_offset..input_end],
            output[0..output_chunk_len],
        );
        input_offset += result.progress.input_read;
        try decoded.appendSlice(allocator, output[0..result.progress.output_written]);
        if (result.status == .done) break;
        if (result.progress.input_read == 0 and result.progress.output_written == 0) {
            if (result.status == .need_input and input_end != input.len)
                return error.TestUnexpectedResult;
            if (result.status == .need_input and input_end == input.len)
                return error.TruncatedFrame;
            return error.TestUnexpectedResult;
        }
    }
    return .{ .bytes = try decoded.toOwnedSlice(allocator), .input_read = input_offset };
}

test "ZIP incremental entry decoder streams Stored data and leaves suffix unconsumed" {
    const allocator = std.testing.allocator;
    const payload = "stored PK\x07\x08 payload with a descriptor signature";
    const suffix = "next-local-header";
    const input = payload ++ suffix;
    const entry = testEntry("stored.bin", .stored, payload.len, payload);
    var decoder = try incremental.Decoder.init(entry, &.{});

    const blocked = try decoder.step(input, &.{});
    try std.testing.expectEqual(.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.input_read);

    const decoded = try decodeFragmented(allocator, &decoder, input, 3, 2);
    defer allocator.free(decoded.bytes);
    try std.testing.expectEqualSlices(u8, payload, decoded.bytes);
    try std.testing.expectEqual(payload.len, decoded.input_read);
    try std.testing.expectEqual(.done, decoder.snapshot().phase);
    try decoder.finish();
}

test "ZIP incremental entry decoder streams Zstandard preset dictionaries" {
    const allocator = std.testing.allocator;
    const dictionary_content = "random-access ZIP Zstandard dictionary alpha beta\n" ** 8;
    const dictionary = zstd.NativeDictionary.init(0x5241_4e44, dictionary_content);
    const payload = "random-access ZIP Zstandard dictionary alpha gamma\n" ** 29;
    const compressed = try zstd.encodeFrameWithDictionaryAlloc(
        allocator,
        payload,
        dictionary,
    );
    defer allocator.free(compressed);
    const entry = testEntry(
        "dictionary.zst",
        .zstandard,
        compressed.len,
        payload,
    );

    var missing = try incremental.OwnedDecoder.init(allocator, entry);
    defer missing.deinit();
    var scratch: [31]u8 = undefined;
    try std.testing.expectError(
        error.NeedDictionary,
        missing.step(compressed, &scratch),
    );

    var wrong = try incremental.OwnedDecoder.initWithOptions(allocator, entry, .{
        .codec_limits = .{ .zstd_dictionary = zstd.NativeDictionary.init(
            dictionary.id + 1,
            dictionary.content,
        ) },
    });
    defer wrong.deinit();
    try std.testing.expectError(
        error.NeedDictionary,
        wrong.step(compressed, &scratch),
    );

    var decoder = try incremental.OwnedDecoder.initWithOptions(allocator, entry, .{
        .codec_limits = .{ .zstd_dictionary = dictionary },
    });
    defer decoder.deinit();
    const decoded = try decodeFragmented(
        allocator,
        &decoder,
        compressed,
        3,
        2,
    );
    defer allocator.free(decoded.bytes);
    try std.testing.expectEqualSlices(u8, payload, decoded.bytes);
    try std.testing.expectEqual(compressed.len, decoded.input_read);
}

test "ZIP incremental entry decoder streams dynamic Deflate under tiny backpressure" {
    const allocator = std.testing.allocator;
    const payload = ("incremental ZIP member payload\n" ** 257) ++ ("abcdef0123456789" ** 83);
    const compressed = try deflate.encodeRawBestAlloc(allocator, payload, .{});
    defer allocator.free(compressed);
    const suffix = "central-directory";
    const input = try std.mem.concat(allocator, u8, &.{ compressed, suffix });
    defer allocator.free(input);
    const entry = testEntry("dynamic.txt", .deflate, compressed.len, payload);
    var decoder = try incremental.OwnedDecoder.init(allocator, entry);
    defer decoder.deinit();

    const blocked = try decoder.step(input, &.{});
    try std.testing.expectEqual(.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.output_written);

    const decoded = try decodeFragmented(
        allocator,
        &decoder,
        input[blocked.progress.input_read..],
        1,
        1,
    );
    defer allocator.free(decoded.bytes);
    try std.testing.expectEqualSlices(u8, payload, decoded.bytes);
    try std.testing.expectEqual(compressed.len, blocked.progress.input_read + decoded.input_read);
    const snapshot = decoder.snapshot();
    try std.testing.expectEqual(compressed.len, snapshot.input_read);
    try std.testing.expectEqual(payload.len, snapshot.output_written);
    try std.testing.expectEqual(snapshot.expected_crc32, snapshot.current_crc32);
}

test "ZIP incremental entry decoder rejects corruption sizes limits and truncation" {
    const allocator = std.testing.allocator;
    const payload = "checksum and size validation" ** 32;
    const compressed = try deflate.encodeRawFixedAlloc(allocator, payload);
    defer allocator.free(compressed);
    const entry = testEntry("checks.txt", .deflate, compressed.len, payload);

    var short_history: [1024]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, incremental.Decoder.init(entry, &short_history));
    var history: [incremental.Decoder.required_history_len]u8 = undefined;
    try std.testing.expectError(
        error.OutputLimitExceeded,
        incremental.Decoder.initWithOptions(entry, &history, .{
            .max_output_len = payload.len - 1,
        }),
    );

    var encrypted = entry;
    encrypted.flags |= 1;
    try std.testing.expectError(error.EncryptedZipEntry, incremental.Decoder.init(encrypted, &history));
    var unsupported = entry;
    unsupported.method = .bzip2;
    try std.testing.expectError(error.UnsupportedZipCompressionMethod, incremental.Decoder.init(unsupported, &history));
    const invalid_stored = testEntry("bad", .stored, payload.len + 1, payload);
    try std.testing.expectError(error.InvalidZipArchive, incremental.Decoder.init(invalid_stored, &.{}));

    var bad_crc = entry;
    bad_crc.crc32 ^= 1;
    var crc_decoder = try incremental.OwnedDecoder.init(allocator, bad_crc);
    defer crc_decoder.deinit();
    try std.testing.expectError(
        error.ChecksumMismatch,
        decodeFragmented(allocator, &crc_decoder, compressed, compressed.len, 31),
    );
    try std.testing.expectEqual(.failed, crc_decoder.snapshot().phase);
    try std.testing.expectError(error.ZipEntryDecoderFailed, crc_decoder.step("", &.{}));

    var truncated = try incremental.OwnedDecoder.init(allocator, entry);
    defer truncated.deinit();
    const truncated_output = try allocator.alloc(u8, payload.len + 1);
    defer allocator.free(truncated_output);
    const short = try truncated.step(compressed[0 .. compressed.len - 1], truncated_output);
    try std.testing.expectEqual(compressed.len - 1, short.progress.input_read);
    try std.testing.expectEqual(.need_input, short.status);
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());

    var oversized_output_entry = entry;
    oversized_output_entry.uncompressed_size += 1;
    var oversized_output = try incremental.OwnedDecoder.init(allocator, oversized_output_entry);
    defer oversized_output.deinit();
    try std.testing.expectError(
        error.SizeMismatch,
        decodeFragmented(allocator, &oversized_output, compressed, compressed.len, 31),
    );

    var oversized_wire_entry = entry;
    oversized_wire_entry.compressed_size += 1;
    var oversized_wire = try incremental.OwnedDecoder.init(allocator, oversized_wire_entry);
    defer oversized_wire.deinit();
    const with_extra = try std.mem.concat(allocator, u8, &.{ compressed, "x" });
    defer allocator.free(with_extra);
    try std.testing.expectError(
        error.InvalidZipArchive,
        decodeFragmented(allocator, &oversized_wire, with_extra, with_extra.len, 31),
    );
}

test "ZIP incremental entry decoder owned state resets across Stored and Deflate members" {
    const allocator = std.testing.allocator;
    const stored_payload = "first stored member";
    const deflated_payload = "second deflated member" ** 80;
    const compressed = try deflate.encodeRawBestAlloc(allocator, deflated_payload, .{});
    defer allocator.free(compressed);
    const stored_entry = testEntry("first", .stored, stored_payload.len, stored_payload);
    const deflated_entry = testEntry("second", .deflate, compressed.len, deflated_payload);
    var decoder = try incremental.OwnedDecoder.init(allocator, stored_entry);
    defer decoder.deinit();

    const first = try decodeFragmented(allocator, &decoder, stored_payload, 2, 3);
    defer allocator.free(first.bytes);
    try std.testing.expectEqualSlices(u8, stored_payload, first.bytes);

    try std.testing.expectError(
        error.OutputLimitExceeded,
        decoder.resetWithOptions(deflated_entry, .{
            .max_output_len = deflated_payload.len - 1,
        }),
    );
    try std.testing.expectEqual(.done, (try decoder.step(&.{}, &.{})).status);

    try decoder.reset(deflated_entry);
    const second = try decodeFragmented(allocator, &decoder, compressed, 2, 5);
    defer allocator.free(second.bytes);
    try std.testing.expectEqualSlices(u8, deflated_payload, second.bytes);

    try decoder.reset(stored_entry);
    const third = try decodeFragmented(allocator, &decoder, stored_payload, 1, 1);
    defer allocator.free(third.bytes);
    try std.testing.expectEqualSlices(u8, stored_payload, third.bytes);
}

test "ZIP incremental entry decoder uses archive-validated ZIP64 descriptor payloads" {
    const allocator = std.testing.allocator;
    const stored_payload = "ZIP64 stored payload";
    const deflated_payload = "ZIP64 descriptor-backed Deflate payload\n" ** 96;
    const entries = [_]zip.EncodeEntry{
        .{ .name = "stored.bin", .data = stored_payload, .method = .stored },
        .{ .name = "deflated.txt", .data = deflated_payload, .method = .deflate },
    };
    const archive_bytes = try zip.encodeAlloc(allocator, &entries, .{
        .data_descriptor = true,
        .zip64 = .always,
    });
    defer allocator.free(archive_bytes);
    const archive = try zip.parse(archive_bytes);
    const expected_payloads = [_][]const u8{ stored_payload, deflated_payload };

    var decoder: ?incremental.OwnedDecoder = null;
    defer if (decoder) |*active| active.deinit();
    for (expected_payloads, 0..) |expected, index| {
        const entry = try archive.entryAt(index);
        const compressed = try archive.compressedData(entry);
        var modified = entry;
        modified.crc32 ^= 1;
        try std.testing.expectError(error.InvalidZipArchive, archive.compressedData(modified));
        if (decoder) |*active|
            try active.reset(entry)
        else
            decoder = try incremental.OwnedDecoder.init(allocator, entry);
        const decoded = try decodeFragmented(allocator, &decoder.?, compressed, 5, 7);
        defer allocator.free(decoded.bytes);
        try std.testing.expectEqualSlices(u8, expected, decoded.bytes);
        try std.testing.expectEqual(compressed.len, decoded.input_read);
    }
}

test "ZIP owned incremental entry decoder streams every supported method" {
    const allocator = std.testing.allocator;
    const payload = ("all-method random-access incremental ZIP payload\n" ** 97) ++
        ("0123456789abcdef" ** 31);
    const methods = [_]zip.CompressionMethod{
        .shrink,
        .reduce_1,
        .reduce_2,
        .reduce_3,
        .reduce_4,
        .implode,
        .deflate64,
        .dcl_implode,
        .bzip2,
        .lzma,
        .xz,
        .ppmd,
        .zstandard_legacy,
        .zstandard,
    };
    var entries: [methods.len]zip.EncodeEntry = undefined;
    var names: [methods.len][32]u8 = undefined;
    var name_lengths: [methods.len]usize = undefined;
    for (methods, 0..) |method, index| {
        const name = try std.fmt.bufPrint(&names[index], "method-{d}.bin", .{@intFromEnum(method)});
        name_lengths[index] = name.len;
        entries[index] = .{
            .name = names[index][0..name.len],
            .data = payload,
            .method = method,
        };
    }
    const encoded = try zip.encodeAlloc(allocator, &entries, .{ .data_descriptor = true });
    defer allocator.free(encoded);
    const archive = try zip.parse(encoded);

    var decoder: ?incremental.OwnedDecoder = null;
    defer if (decoder) |*active| active.deinit();
    for (methods, 0..) |method, index| {
        const entry = try archive.entryAt(index);
        try std.testing.expectEqual(method, entry.method);
        try std.testing.expectEqualStrings(names[index][0..name_lengths[index]], entry.name);
        const compressed = try archive.compressedData(entry);
        const with_suffix = try std.mem.concat(allocator, u8, &.{ compressed, "suffix" });
        defer allocator.free(with_suffix);
        if (decoder) |*active|
            try active.reset(entry)
        else
            decoder = try incremental.OwnedDecoder.init(allocator, entry);
        const decoded = try decodeFragmented(
            allocator,
            &decoder.?,
            with_suffix,
            3,
            2,
        );
        defer allocator.free(decoded.bytes);
        try std.testing.expectEqualSlices(u8, payload, decoded.bytes);
        try std.testing.expectEqual(compressed.len, decoded.input_read);

        var bad_crc = entry;
        bad_crc.crc32 ^= 1;
        try decoder.?.reset(bad_crc);
        try std.testing.expectError(
            error.ChecksumMismatch,
            decodeFragmented(allocator, &decoder.?, compressed, 11, 13),
        );

        try decoder.?.reset(entry);
        try std.testing.expectError(
            error.TruncatedFrame,
            decodeFragmented(
                allocator,
                &decoder.?,
                compressed[0 .. compressed.len - 1],
                7,
                5,
            ),
        );
    }
}

test "ZIP owned incremental entry decoder releases all-method allocation failures" {
    const payload = "allocation-safe universal ZIP entry decoder\n" ** 23;
    const methods = [_]zip.CompressionMethod{
        .shrink,
        .reduce_4,
        .implode,
        .deflate64,
        .dcl_implode,
        .bzip2,
        .lzma,
        .xz,
        .ppmd,
        .zstandard,
    };
    var entries: [methods.len]zip.EncodeEntry = undefined;
    var names: [methods.len][24]u8 = undefined;
    for (methods, 0..) |method, index| {
        const name = try std.fmt.bufPrint(&names[index], "oom-{d}", .{@intFromEnum(method)});
        entries[index] = .{ .name = name, .data = payload, .method = method };
    }
    const encoded = try zip.encodeAlloc(std.testing.allocator, &entries, .{});
    defer std.testing.allocator.free(encoded);

    const FailureTest = struct {
        fn run(
            allocator: std.mem.Allocator,
            archive_bytes: []const u8,
            expected: []const u8,
            count: usize,
        ) !void {
            const archive = try zip.parse(archive_bytes);
            for (0..count) |index| {
                const entry = try archive.entryAt(index);
                const compressed = try archive.compressedData(entry);
                var decoder = try incremental.OwnedDecoder.init(allocator, entry);
                defer decoder.deinit();
                const decoded = try decodeFragmented(allocator, &decoder, compressed, 7, 11);
                defer allocator.free(decoded.bytes);
                try std.testing.expectEqualSlices(u8, expected, decoded.bytes);
            }
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        FailureTest.run,
        .{ encoded, payload, methods.len },
    );
}

test "ZIP owned incremental entry decoder streams ZipCrypto and WinZip AES" {
    const allocator = std.testing.allocator;
    const zipcrypto_password = "entry ZipCrypto 密码";
    const aes_password = "entry WinZip AES 密码";
    const payload = "encrypted random-access incremental ZIP payload\n" ** 71;
    const salt128 = [_]u8{0x18} ** 8;
    const salt192 = [_]u8{0x29} ** 12;
    const salt256 = [_]u8{0x3a} ** 16;
    const entries = [_]zip.EncodeEntry{
        .{
            .name = "zipcrypto-bzip2.bin",
            .data = payload,
            .method = .bzip2,
            .traditional_encryption = .{
                .password = zipcrypto_password,
                .header_random = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            },
        },
        .{
            .name = "zipcrypto-lzma.bin",
            .data = payload,
            .method = .lzma,
            .traditional_encryption = .{
                .password = zipcrypto_password,
                .header_random = .{ 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 },
            },
        },
        .{
            .name = "aes-bzip2.bin",
            .data = payload,
            .method = .bzip2,
            .winzip_aes = .{
                .password = aes_password,
                .strength = .aes128,
                .salt = &salt128,
                .version = .ae1,
            },
        },
        .{
            .name = "aes-lzma.bin",
            .data = payload,
            .method = .lzma,
            .winzip_aes = .{
                .password = aes_password,
                .strength = .aes192,
                .salt = &salt192,
                .version = .ae2,
            },
        },
        .{
            .name = "aes-ppmd.bin",
            .data = payload,
            .method = .ppmd,
            .winzip_aes = .{
                .password = aes_password,
                .strength = .aes256,
                .salt = &salt256,
                .version = .ae1,
            },
        },
    };
    const encoded = try zip.encodeAlloc(allocator, &entries, .{ .data_descriptor = true });
    defer allocator.free(encoded);
    const archive = try zip.parse(encoded);
    var decoder: ?incremental.OwnedDecoder = null;
    defer if (decoder) |*active| active.deinit();
    for (entries, 0..) |expected, index| {
        const entry = try archive.entryAt(index);
        const raw = try archive.rawEntryData(entry);
        const options = incremental.Options{
            .max_output_len = payload.len,
            .password = if (entry.winzip_aes != null) aes_password else zipcrypto_password,
        };
        if (decoder) |*active|
            try active.resetWithOptions(entry, options)
        else
            decoder = try incremental.OwnedDecoder.initWithOptions(allocator, entry, options);
        const decoded = try decodeFragmented(allocator, &decoder.?, raw, 3, 2);
        defer allocator.free(decoded.bytes);
        try std.testing.expectEqualSlices(u8, expected.data, decoded.bytes);
        try std.testing.expectEqual(raw.len, decoded.input_read);
    }

    const first = try archive.entryAt(0);
    var wrong = try incremental.OwnedDecoder.initWithOptions(allocator, first, .{
        .password = "wrong password",
    });
    defer wrong.deinit();
    try std.testing.expectError(
        error.InvalidZipPassword,
        decodeFragmented(allocator, &wrong, try archive.rawEntryData(first), 5, 7),
    );

    const aes_entry = try archive.entryAt(2);
    var wrong_aes = try incremental.OwnedDecoder.initWithOptions(allocator, aes_entry, .{
        .password = "wrong password",
    });
    defer wrong_aes.deinit();
    try std.testing.expectError(
        error.InvalidZipPassword,
        decodeFragmented(allocator, &wrong_aes, try archive.rawEntryData(aes_entry), 5, 7),
    );

    const aes_raw = try archive.rawEntryData(aes_entry);
    const aes_offset = @intFromPtr(aes_raw.ptr) - @intFromPtr(encoded.ptr);
    var corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    corrupt[aes_offset + aes_raw.len - 1] ^= 1;
    const corrupt_archive = try zip.parse(corrupt);
    const corrupt_entry = try corrupt_archive.entryAt(2);
    var corrupt_decoder = try incremental.OwnedDecoder.initWithOptions(
        allocator,
        corrupt_entry,
        .{ .password = aes_password },
    );
    defer corrupt_decoder.deinit();
    try std.testing.expectError(
        error.InvalidAuthenticationCode,
        decodeFragmented(
            allocator,
            &corrupt_decoder,
            try corrupt_archive.rawEntryData(corrupt_entry),
            5,
            7,
        ),
    );
}

test "ZIP owned incremental entry decoder streams PKWARE Strong Encryption" {
    const allocator = std.testing.allocator;
    const password = "PKWARE strong entry 密码";
    const payload = "PKWARE Strong random-access incremental payload\n" ** 59;
    const iv128 = [_]u8{0x11} ** 16;
    const iv192 = [_]u8{0x22} ** 16;
    const iv256 = [_]u8{0x33} ** 16;
    const random128 = [_]u8{0x41} ** 16;
    const random192 = [_]u8{0x42} ** 16;
    const random256 = [_]u8{0x43} ** 32;
    const validation = [_]u8{0x51} ** 12;
    const entries = [_]zip.EncodeEntry{
        .{
            .name = "strong-stored.bin",
            .data = payload,
            .method = .stored,
            .pkware_strong_encryption = .{
                .password = password,
                .strength = .aes128,
                .iv = iv128,
                .random_data = &random128,
                .validation_data = &validation,
            },
        },
        .{
            .name = "strong-deflate.bin",
            .data = payload,
            .method = .deflate,
            .pkware_strong_encryption = .{
                .password = password,
                .strength = .aes192,
                .iv = iv192,
                .random_data = &random192,
                .validation_data = &validation,
            },
        },
        .{
            .name = "strong-bzip2.bin",
            .data = payload,
            .method = .bzip2,
            .pkware_strong_encryption = .{
                .password = password,
                .strength = .aes256,
                .iv = iv256,
                .random_data = &random256,
                .validation_data = &validation,
            },
        },
    };
    const encoded = try zip.encodeAlloc(allocator, &entries, .{ .data_descriptor = true });
    defer allocator.free(encoded);
    const archive = try zip.parse(encoded);
    var decoder: ?incremental.OwnedDecoder = null;
    defer if (decoder) |*active| active.deinit();
    for (entries, 0..) |expected, index| {
        const entry = try archive.entryAt(index);
        const raw = try archive.rawEntryData(entry);
        const options = incremental.Options{
            .max_output_len = payload.len,
            .password = password,
        };
        if (decoder) |*active|
            try active.resetWithOptions(entry, options)
        else
            decoder = try incremental.OwnedDecoder.initWithOptions(allocator, entry, options);
        const decoded = try decodeFragmented(allocator, &decoder.?, raw, 5, 3);
        defer allocator.free(decoded.bytes);
        try std.testing.expectEqualSlices(u8, expected.data, decoded.bytes);
        try std.testing.expectEqual(raw.len, decoded.input_read);
    }

    const first = try archive.entryAt(0);
    var wrong = try incremental.OwnedDecoder.initWithOptions(allocator, first, .{
        .password = "wrong password",
    });
    defer wrong.deinit();
    try std.testing.expectError(
        error.InvalidPasswordValidation,
        decodeFragmented(allocator, &wrong, try archive.rawEntryData(first), 5, 7),
    );
}

test "ZIP owned incremental PKWARE Strong composes every compression method" {
    const allocator = std.testing.allocator;
    const password = "all-method strong password";
    const payload = "all-method PKWARE Strong payload\n" ** 31;
    const iv = [_]u8{0x45} ** 16;
    const random_data = [_]u8{0x56} ** 32;
    const validation = [_]u8{0x67} ** 12;
    const methods = [_]zip.CompressionMethod{
        .stored,
        .shrink,
        .reduce_1,
        .reduce_2,
        .reduce_3,
        .reduce_4,
        .implode,
        .deflate,
        .deflate64,
        .dcl_implode,
        .bzip2,
        .lzma,
        .xz,
        .ppmd,
        .zstandard_legacy,
        .zstandard,
    };
    var entries: [methods.len]zip.EncodeEntry = undefined;
    var names: [methods.len][24]u8 = undefined;
    for (methods, 0..) |method, index| {
        const name = try std.fmt.bufPrint(&names[index], "strong-{d}", .{@intFromEnum(method)});
        entries[index] = .{
            .name = name,
            .data = payload,
            .method = method,
            .pkware_strong_encryption = .{
                .password = password,
                .strength = .aes256,
                .iv = iv,
                .random_data = &random_data,
                .validation_data = &validation,
            },
        };
    }
    const encoded = try zip.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(encoded);
    const archive = try zip.parse(encoded);
    var decoder: ?incremental.OwnedDecoder = null;
    defer if (decoder) |*active| active.deinit();
    for (methods, 0..) |method, index| {
        const entry = try archive.entryAt(index);
        try std.testing.expectEqual(method, entry.method);
        const raw = try archive.rawEntryData(entry);
        const options = incremental.Options{ .password = password };
        if (decoder) |*active|
            try active.resetWithOptions(entry, options)
        else
            decoder = try incremental.OwnedDecoder.initWithOptions(allocator, entry, options);
        const decoded = try decodeFragmented(allocator, &decoder.?, raw, 7, 5);
        defer allocator.free(decoded.bytes);
        try std.testing.expectEqualSlices(u8, payload, decoded.bytes);
    }
}

test "ZIP owned incremental encrypted decoder releases allocation failures" {
    const password = "allocation-safe encrypted decoder";
    const payload = "encrypted allocation failure payload\n" ** 19;
    const iv = [_]u8{0x61} ** 16;
    const random_data = [_]u8{0x72} ** 32;
    const validation = [_]u8{0x83} ** 12;
    const entries = [_]zip.EncodeEntry{.{
        .name = "strong-oom.bin",
        .data = payload,
        .method = .bzip2,
        .pkware_strong_encryption = .{
            .password = password,
            .strength = .aes256,
            .iv = iv,
            .random_data = &random_data,
            .validation_data = &validation,
        },
    }};
    const encoded = try zip.encodeAlloc(std.testing.allocator, &entries, .{});
    defer std.testing.allocator.free(encoded);
    const archive = try zip.parse(encoded);
    const entry = try archive.entryAt(0);
    const raw = try archive.rawEntryData(entry);

    const FailureTest = struct {
        fn run(
            allocator: std.mem.Allocator,
            canonical: zip.Entry,
            encrypted: []const u8,
            expected: []const u8,
            secret: []const u8,
        ) !void {
            var decoder = try incremental.OwnedDecoder.initWithOptions(
                allocator,
                canonical,
                .{ .password = secret },
            );
            defer decoder.deinit();
            const decoded = try decodeFragmented(allocator, &decoder, encrypted, 7, 5);
            defer allocator.free(decoded.bytes);
            try std.testing.expectEqualSlices(u8, expected, decoded.bytes);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        FailureTest.run,
        .{ entry, raw, payload, password },
    );
}
