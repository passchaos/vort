//! Public ZIP method-9 streaming contracts. The parent ZIP module supplies its
//! namespace so this test suite does not re-import the module being tested.
const std = @import("std");
const core = @import("../core.zig");
const incremental = @import("incremental_writer.zig");
const wire = @import("wire.zig");
const a = std.testing.allocator;
const payload = "Deflate64 streamed ZIP abcdefgh-" ** 64;
// Independently computed CRC-32/ISO-HDLC for the literal fixture above.
const payload_crc: u32 = 0xe7a4_b4db;

pub fn contracts(comptime Zip: type) type {
    return struct {
        test "ZIP Deflate64 stream known and unknown sizes preserve ZIP32 ZIP64 descriptors and fixed compression" {
            for ([_]Zip.Zip64Mode{ .never, .always }) |mode| {
                for ([_]bool{ false, true }) |known| {
                    const entry: incremental.EntryOptions = .{
                        .name = "method9.txt",
                        .comment = "Deflate64 stream metadata",
                        .method = .deflate64,
                        .expected_size = if (known) payload.len else null,
                        .modified = .{ .date = 0x5a3f, .time = 0xbf7d },
                        .extended_timestamp = .{ .modified = 1_700_000_001 },
                        .creator_system = .unix,
                        .internal_attributes = 1,
                        .external_attributes = Zip.unixExternalAttributes(0o100600),
                    };
                    const options: incremental.Options = .{ .zip64 = mode, .archive_comment = "streaming method 9" };
                    const tiny = try archiveBytes(entry, options, 1, 1);
                    defer a.free(tiny);
                    const coalesced = try archiveBytes(entry, options, payload.len, 4096);
                    defer a.free(coalesced);
                    try std.testing.expectEqualSlices(u8, coalesced, tiny);
                    const archive = try Zip.parse(tiny);
                    try std.testing.expectEqual(@as(usize, 1), archive.entry_count);
                    try std.testing.expectEqualStrings(options.archive_comment, archive.comment);
                    const actual = try archive.entryAt(0);
                    try std.testing.expectEqual(Zip.CompressionMethod.deflate64, actual.method);
                    try std.testing.expectEqual(mode == .always, actual.zip64);
                    try std.testing.expectEqualStrings(entry.name, actual.name);
                    try std.testing.expectEqualStrings(entry.comment, actual.comment);
                    try std.testing.expectEqual(entry.modified, actual.modified);
                    try std.testing.expectEqual(entry.extended_timestamp, actual.extended_timestamp);
                    try std.testing.expectEqual(Zip.CreatorSystem.unix, actual.creatorSystem());
                    try std.testing.expectEqual(@as(?u16, 0o100600), actual.unixMode());
                    try std.testing.expectEqual(@as(u16, 1), actual.internal_attributes);
                    try std.testing.expectEqual(payload_crc, actual.crc32);
                    try std.testing.expectEqual(payload.len, actual.uncompressed_size);
                    try std.testing.expect(actual.compressed_size < payload.len);
                    try std.testing.expect(actual.flags & wire.descriptor_flag != 0);
                    const compressed = try archive.compressedData(actual);
                    try std.testing.expectEqual(actual.compressed_size, compressed.len);
                    // RFC 1951 BTYPE bits also apply to method 9. This locked
                    // repetitive fixture must use actual fixed coding, not a
                    // method-9 local header around stored-only stream bytes.
                    try std.testing.expectEqual(@as(u8, 1), (compressed[0] >> 1) & 3);
                    try verifyDescriptor(tiny, actual, compressed);
                    const decoded = try archive.extractAlloc(a, actual);
                    defer a.free(decoded);
                    try std.testing.expectEqualSlices(u8, payload, decoded);
                }
            }
        }

        test "ZIP Deflate64 stream zero output consumes nothing before header data and finish" {
            var writer = try incremental.Writer.initWithOptions(a, .{ .zip64 = .never });
            defer writer.deinit();
            try writer.beginEntry(.{ .name = "zero.txt", .method = .deflate64, .expected_size = 4 });
            const header_before = writer.snapshot();
            const blocked_header = try writer.step("abcd", &.{});
            try std.testing.expectEqual(core.Progress{}, blocked_header.progress);
            try std.testing.expectEqual(.need_output, blocked_header.status);
            try std.testing.expectEqual(header_before, writer.snapshot());
            var header: [256]u8 = undefined;
            _ = try writer.step("", &header);
            try std.testing.expectEqual(.entry_data, writer.snapshot().phase);
            const data_before = writer.snapshot();
            const blocked_data = try writer.step("abcd", &.{});
            try std.testing.expectEqual(core.Progress{}, blocked_data.progress);
            try std.testing.expectEqual(.need_output, blocked_data.status);
            try std.testing.expectEqual(data_before, writer.snapshot());
            var output: [1]u8 = undefined;
            const accepted = try writer.step("abcd", &output);
            try std.testing.expectEqual(@as(usize, 4), accepted.progress.input_read);
            try std.testing.expectEqual(@as(usize, 0), accepted.progress.output_written);
            try writer.finishEntry();
            const finish_before = writer.snapshot();
            const blocked_finish = try writer.step("", &.{});
            try std.testing.expectEqual(.need_output, blocked_finish.status);
            try std.testing.expectEqual(core.Progress{}, blocked_finish.progress);
            try std.testing.expectEqual(finish_before, writer.snapshot());
        }

        test "ZIP Deflate64 stream pending cap records accepted input before sticky writer poison" {
            var writer = try incremental.Writer.initWithOptions(a, .{
                .zip64 = .never,
                .deflate64_options = .{ .block_len = 64, .max_pending_output_len = 1 },
            });
            defer writer.deinit();
            try writer.beginEntry(.{ .name = "capped.txt", .method = .deflate64 });
            var header: [256]u8 = undefined;
            _ = try writer.step("", &header);
            const before = writer.snapshot();
            try std.testing.expectEqual(.entry_data, before.phase);
            var output: [8]u8 = @splat(0xa5);
            // The first block is accepted; byte 65 proves it non-final and
            // triggers an encoded pending limit before any codec bytes drain.
            try std.testing.expectError(error.OutputLimitExceeded, writer.step(payload[0..65], &output));
            const failed = writer.snapshot();
            try std.testing.expectEqual(.poisoned, failed.phase);
            try std.testing.expectEqual(before.input_read + 64, failed.input_read);
            try std.testing.expectEqual(@as(u64, 64), failed.current_uncompressed_size);
            try std.testing.expectEqual(before.output_written, failed.output_written);
            try std.testing.expectEqual(@as(u64, 0), failed.current_compressed_size);
            try std.testing.expectEqual(before.central_metadata_size, failed.central_metadata_size);
            try std.testing.expectEqual(@as(u64, 0), failed.entry_count);
            try untouched(&output);
            try std.testing.expectError(error.ZipWriterPoisoned, writer.step(payload[64..65], &output));
            try std.testing.expectEqual(failed, writer.snapshot());
            try std.testing.expectError(error.ZipWriterPoisoned, writer.finishEntry());
            try std.testing.expectError(error.ZipWriterPoisoned, writer.finishArchive());
            try untouched(&output);
        }

        test "ZIP Deflate64 stream input cap rejects before consumption and output publication" {
            var writer = try incremental.Writer.initWithOptions(a, .{
                .zip64 = .never,
                .deflate64_options = .{ .max_input_len = 3 },
            });
            defer writer.deinit();
            try writer.beginEntry(.{ .name = "input-cap.txt", .method = .deflate64 });
            var header: [256]u8 = undefined;
            _ = try writer.step("", &header);
            const before = writer.snapshot();
            var output: [8]u8 = @splat(0xa5);
            try std.testing.expectError(error.OutputLimitExceeded, writer.step("abcd", &output));
            const failed = writer.snapshot();
            try std.testing.expectEqual(.poisoned, failed.phase);
            try std.testing.expectEqual(before.input_read, failed.input_read);
            try std.testing.expectEqual(before.output_written, failed.output_written);
            try std.testing.expectEqual(@as(u64, 0), failed.current_uncompressed_size);
            try std.testing.expectEqual(@as(u64, 0), failed.current_compressed_size);
            try untouched(&output);
        }

        test "ZIP Deflate64 stream ZipCrypto and WinZip AES retain method descriptor and encrypted sizes" {
            const salt = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7 };
            for ([_]bool{ false, true }) |aes| {
                const entry: incremental.EntryOptions = .{
                    .name = "encrypted-method9.txt",
                    .method = .deflate64,
                    .expected_size = null,
                    .traditional_encryption = if (!aes) .{ .password = "method9 password", .header_random = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 } } else null,
                    .winzip_aes = if (aes) .{ .password = "method9 password", .strength = .aes128, .salt = &salt, .version = .ae1 } else null,
                };
                const bytes = try archiveBytes(entry, .{ .zip64 = .never }, 1, 1);
                defer a.free(bytes);
                const archive = try Zip.parse(bytes);
                const actual = try archive.entryAt(0);
                try std.testing.expectEqual(Zip.CompressionMethod.deflate64, actual.method);
                try std.testing.expect(actual.flags & 1 != 0);
                try std.testing.expect(actual.flags & wire.descriptor_flag != 0);
                try std.testing.expectEqual(payload_crc, actual.crc32);
                try std.testing.expectEqual(payload.len, actual.uncompressed_size);
                try std.testing.expect(actual.compressed_size < payload.len);
                try std.testing.expectEqual(@as(u16, if (aes) 99 else 9), readU16(bytes, actual.local_header_offset + 8));
                if (aes) {
                    try std.testing.expectEqual(Zip.WinZipAesStrength.aes128, actual.winzip_aes.?.strength);
                    try std.testing.expectEqual(Zip.WinZipAesVendorVersion.ae1, actual.winzip_aes.?.version);
                } else try std.testing.expect(actual.winzip_aes == null);
                const encrypted = try archive.rawEntryData(actual);
                try std.testing.expectEqual(actual.compressed_size, encrypted.len);
                try verifyDescriptor(bytes, actual, encrypted);
                try std.testing.expectError(error.PasswordRequired, archive.extractAlloc(a, actual));
                const plain = try archive.extractAllocWithOptions(a, actual, .{ .password = "method9 password" });
                defer a.free(plain);
                try std.testing.expectEqualSlices(u8, payload, plain);
            }
        }

        test "ZIP Deflate64 stream encrypted pending failure accounts accepted input without unpublished ciphertext" {
            const salt = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7 };
            const iv = [_]u8{0x51} ** 16;
            const random_data = [_]u8{0x61} ** 16;
            const validation_data = [_]u8{0x71} ** 12;
            const Encryption = enum { zipcrypto, aes, pkware };
            for ([_]Encryption{ .zipcrypto, .aes, .pkware }) |encryption| {
                var writer = try incremental.Writer.initWithOptions(a, .{
                    .zip64 = .never,
                    .deflate64_options = .{ .block_len = 64, .max_pending_output_len = 1 },
                });
                defer writer.deinit();
                try writer.beginEntry(.{
                    .name = "encrypted-capped.txt",
                    .method = .deflate64,
                    .traditional_encryption = if (encryption == .zipcrypto) .{ .password = "method9 password", .header_random = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 } } else null,
                    .winzip_aes = if (encryption == .aes) .{ .password = "method9 password", .strength = .aes128, .salt = &salt, .version = .ae1 } else null,
                    .pkware_strong_encryption = if (encryption == .pkware) .{ .password = "method9 password", .strength = .aes128, .iv = iv, .random_data = &random_data, .validation_data = &validation_data } else null,
                });
                var header: [256]u8 = undefined;
                _ = try writer.step("", &header);
                const before = writer.snapshot();
                try std.testing.expectEqual(.entry_data, before.phase);
                try std.testing.expectEqual(@as(usize, 0), before.pending_output);
                const expected_encryption_header: u64 = switch (encryption) {
                    .zipcrypto => 12, // Eleven random bytes plus verifier byte.
                    .aes => salt.len + 2, // Salt followed by password verifier.
                    // APPNOTE explicit IV prefix, fixed fields, padded random
                    // material, and validation data with its four-byte CRC.
                    .pkware => 2 + iv.len + 4 + 16 + random_data.len + 16 + validation_data.len + 4,
                };
                try std.testing.expectEqual(expected_encryption_header, before.current_compressed_size);
                var output: [8]u8 = @splat(0xa5);
                try std.testing.expectError(error.OutputLimitExceeded, writer.step(payload[0..65], &output));
                const failed = writer.snapshot();
                try std.testing.expectEqual(.poisoned, failed.phase);
                try std.testing.expectEqual(before.input_read + 64, failed.input_read);
                try std.testing.expectEqual(@as(u64, 64), failed.current_uncompressed_size);
                // Independent CRC-32/ISO-HDLC of the accepted fixture prefix.
                try std.testing.expectEqual(@as(u32, 0x8fb9_ac85), writer.current.?.crc.digest());
                try std.testing.expectEqual(before.output_written, failed.output_written);
                try std.testing.expectEqual(expected_encryption_header, failed.current_compressed_size);
                try std.testing.expectEqual(before.central_metadata_size, failed.central_metadata_size);
                try std.testing.expectEqual(@as(u64, 0), failed.entry_count);
                try untouched(&output);
                try std.testing.expectError(error.ZipWriterPoisoned, writer.step(payload[64..65], &output));
                try std.testing.expectEqual(failed, writer.snapshot());
                try std.testing.expectError(error.ZipWriterPoisoned, writer.finishEntry());
                try std.testing.expectError(error.ZipWriterPoisoned, writer.finishArchive());
                try untouched(&output);
            }
        }

        test "ZIP Deflate64 stream PKWARE Strong encryption round trips matching compressed payload" {
            const iv = [_]u8{0x51} ** 16;
            const random_data = [_]u8{0x61} ** 16;
            const validation_data = [_]u8{0x71} ** 12;
            const entry: incremental.EntryOptions = .{
                .name = "strong-method9.txt",
                .method = .deflate64,
                .expected_size = payload.len,
                .pkware_strong_encryption = .{ .password = "method9 password", .strength = .aes128, .iv = iv, .random_data = &random_data, .validation_data = &validation_data },
            };
            const bytes = try archiveBytes(entry, .{ .zip64 = .never }, 1, 1);
            defer a.free(bytes);
            const archive = try Zip.parse(bytes);
            const actual = try archive.entryAt(0);
            try std.testing.expectEqual(Zip.CompressionMethod.deflate64, actual.method);
            try std.testing.expect(actual.isPkwareStrongEncrypted());
            try std.testing.expect(actual.flags & wire.descriptor_flag != 0);
            try std.testing.expectEqual(Zip.PkwareStrongEncryptionStrength.aes128, actual.pkware_strong_encryption.?.strength);
            try std.testing.expectEqual(payload_crc, actual.crc32);
            try std.testing.expectEqual(payload.len, actual.uncompressed_size);
            try std.testing.expect(actual.compressed_size < payload.len);
            const encrypted = try archive.rawEntryData(actual);
            try std.testing.expectEqual(actual.compressed_size, encrypted.len);
            try verifyDescriptor(bytes, actual, encrypted);
            const plain = try archive.extractAllocWithOptions(a, actual, .{ .password = "method9 password" });
            defer a.free(plain);
            try std.testing.expectEqualSlices(u8, payload, plain);
        }

        fn archiveBytes(entry: incremental.EntryOptions, options: incremental.Options, input_chunk: usize, output_chunk: usize) ![]u8 {
            var writer = try incremental.Writer.initWithOptions(a, options);
            defer writer.deinit();
            try writer.beginEntry(entry);
            var archive: std.ArrayList(u8) = .empty;
            errdefer archive.deinit(a);
            var output: [4096]u8 = undefined;
            var offset: usize = 0;
            var calls: usize = 0;
            while (offset < payload.len) {
                const end = @min(payload.len, offset + input_chunk);
                if (calls % 7 == 0) {
                    const before = writer.snapshot();
                    const blocked = try writer.step(payload[offset..end], &.{});
                    try std.testing.expectEqual(core.Progress{}, blocked.progress);
                    try std.testing.expectEqual(before, writer.snapshot());
                }
                @memset(&output, 0xa5);
                const before = writer.snapshot();
                const step = try writer.step(payload[offset..end], output[0..output_chunk]);
                try accountStep(&writer, before, step, &output, &archive);
                offset += step.progress.input_read;
                calls += 1;
                try std.testing.expect(calls < payload.len * 4 + 4096);
            }
            try writer.finishEntry();
            while (writer.snapshot().phase != .ready) {
                const before = writer.snapshot();
                @memset(&output, 0xa5);
                const step = try writer.step("", output[0..output_chunk]);
                try accountStep(&writer, before, step, &output, &archive);
                calls += 1;
                try std.testing.expect(calls < payload.len * 4 + 4096);
            }
            try writer.finishArchive();
            while (true) {
                const before = writer.snapshot();
                @memset(&output, 0xa5);
                const step = try writer.step("", output[0..output_chunk]);
                try accountStep(&writer, before, step, &output, &archive);
                calls += 1;
                try std.testing.expect(calls < payload.len * 4 + 4096);
                if (step.status == .done) break;
            }
            try std.testing.expectEqual(@as(u64, payload.len), writer.snapshot().input_read);
            try std.testing.expectEqual(@as(u64, 1), writer.snapshot().entry_count);
            return archive.toOwnedSlice(a);
        }

        fn accountStep(writer: *const incremental.Writer, before: incremental.Writer.Snapshot, step: core.StepResult, output: []const u8, archive: *std.ArrayList(u8)) !void {
            const after = writer.snapshot();
            try std.testing.expectEqual(@as(u64, step.progress.input_read), after.input_read - before.input_read);
            try std.testing.expectEqual(@as(u64, step.progress.output_written), after.output_written - before.output_written);
            try untouched(output[step.progress.output_written..]);
            try archive.appendSlice(a, output[0..step.progress.output_written]);
            try std.testing.expectEqual(@as(u64, archive.items.len), after.output_written);
        }

        fn verifyDescriptor(bytes: []const u8, entry: Zip.Entry, data: []const u8) !void {
            const start = @intFromPtr(data.ptr) - @intFromPtr(bytes.ptr) + data.len;
            try std.testing.expectEqual(@as(u32, 0x0807_4b50), readU32(bytes, start));
            try std.testing.expectEqual(payload_crc, readU32(bytes, start + 4));
            if (entry.zip64) {
                try std.testing.expectEqual(@as(u64, entry.compressed_size), readU64(bytes, start + 8));
                try std.testing.expectEqual(@as(u64, payload.len), readU64(bytes, start + 16));
                try std.testing.expectEqual(start + 24, entry.central_header_offset);
            } else {
                try std.testing.expectEqual(@as(u32, @intCast(entry.compressed_size)), readU32(bytes, start + 8));
                try std.testing.expectEqual(@as(u32, payload.len), readU32(bytes, start + 12));
                try std.testing.expectEqual(start + 16, entry.central_header_offset);
            }
            try std.testing.expectEqual(@as(u32, 0), readU32(bytes, entry.local_header_offset + 14));
            const placeholder: u32 = if (entry.zip64) std.math.maxInt(u32) else 0;
            try std.testing.expectEqual(@as(u32, placeholder), readU32(bytes, entry.local_header_offset + 18));
            try std.testing.expectEqual(@as(u32, placeholder), readU32(bytes, entry.local_header_offset + 22));
        }
    };
}

fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}
fn readU16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}
fn readU32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}
fn readU64(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .little);
}
