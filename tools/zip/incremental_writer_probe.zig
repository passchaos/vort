const std = @import("std");
const vort = @import("vort");

const Entry = struct {
    name: []const u8,
    data: []const u8,
    method: vort.ZipCompressionMethod,
    expected_size: ?u64,
    comment: []const u8 = "",
    unicode_name: ?[]const u8 = null,
    unicode_comment: ?[]const u8 = null,
    modified: vort.ZipDosTimestamp = .deterministic,
    extended_timestamp: ?vort.ZipExtendedTimestamp = null,
    ntfs_timestamp: ?vort.ZipNtfsTimestamp = null,
    creator_system: vort.ZipCreatorSystem = .fat,
    internal_attributes: u16 = 0,
    external_attributes: ?u32 = null,
    traditional_encryption: ?vort.ZipTraditionalEncryptionOptions = null,
    winzip_aes: ?vort.ZipWinZipAesOptions = null,
    pkware_strong_encryption: ?vort.ZipPkwareStrongEncryptionOptions = null,
};

const OutputPattern = enum {
    one,
    micro,
};

const input_chunks = [_]usize{ 1, 2, 3, 5, 7 };
const micro_output_chunks = [_]usize{ 2, 3, 5, 7 };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const mode_name = args.next() orelse return error.MissingZipMode;
    const pattern_name = args.next() orelse return error.MissingOutputPattern;
    const entry_mode = args.next();
    if (args.next() != null) return error.UnexpectedArgument;

    const zip64: vort.Zip64Mode = if (std.mem.eql(u8, mode_name, "zip32"))
        .never
    else if (std.mem.eql(u8, mode_name, "zip64"))
        .always
    else
        return error.InvalidZipMode;
    const output_pattern: OutputPattern = if (std.mem.eql(u8, pattern_name, "one"))
        .one
    else if (std.mem.eql(u8, pattern_name, "micro"))
        .micro
    else
        return error.InvalidOutputPattern;
    const split_mode = if (entry_mode) |value|
        std.mem.eql(u8, value, "split")
    else
        false;

    const known_stored = "\x00known-stored-PK\x07\x08-payload\xff";
    const unknown_stored = "PK\x07\x08unknown-stored-PK\x07\x08tail";
    const known_deflate = "known deflate stream crosses block boundaries.\n" ** 900;
    const unknown_deflate = "unknown deflate UTF-8 path payload.\n" ** 61;
    const known_bzip2 = "known Bzip2 incremental ZIP payload.\n" ** 96;
    const unknown_bzip2 = "unknown Bzip2 incremental ZIP payload.\n" ** 73;
    const known_zstd = "known Zstandard incremental ZIP payload.\n" ** 103;
    const unknown_zstd = "unknown legacy Zstandard incremental ZIP payload.\n" ** 67;
    const known_lzma = "known LZMA incremental ZIP payload.\n" ** 89;
    const unknown_lzma = "unknown LZMA incremental ZIP payload.\n" ** 71;
    const known_xz = "known XZ incremental ZIP payload.\n" ** 97;
    const unknown_xz = "unknown XZ incremental ZIP payload.\n" ** 79;
    const known_deflate64 = "known Deflate64 incremental ZIP payload.\n" ** 101;
    const unknown_deflate64 = "unknown Deflate64 incremental ZIP payload.\n" ** 83;
    const known_ppmd = "known PPMd incremental ZIP payload.\n" ** 107;
    const unknown_ppmd = "unknown PPMd incremental ZIP payload.\n" ** 89;
    const known_shrink = "known Shrink incremental ZIP payload.\n" ** 109;
    const unknown_shrink = "unknown Shrink incremental ZIP payload.\n" ** 91;
    const known_dcl = "known DCL Implode incremental ZIP payload.\n" ** 113;
    const unknown_dcl = "unknown DCL Implode incremental ZIP payload.\n" ** 93;
    const known_reduce_1 = "known Reduce factor 1 incremental ZIP payload.\n" ** 67;
    const unknown_reduce_1 = "unknown Reduce factor 1 incremental ZIP payload.\n" ** 53;
    const known_reduce_2 = "known Reduce factor 2 incremental ZIP payload.\n" ** 71;
    const unknown_reduce_2 = "unknown Reduce factor 2 incremental ZIP payload.\n" ** 59;
    const known_reduce_3 = "known Reduce factor 3 incremental ZIP payload.\n" ** 73;
    const unknown_reduce_3 = "unknown Reduce factor 3 incremental ZIP payload.\n" ** 61;
    const known_reduce_4 = "known Reduce factor 4 incremental ZIP payload.\n" ** 79;
    const unknown_reduce_4 = "unknown Reduce factor 4 incremental ZIP payload.\n" ** 63;
    const known_implode = "known traditional Implode incremental ZIP payload.\n" ** 83;
    const unknown_implode = "unknown traditional Implode incremental ZIP payload.\n" ** 67;
    const metadata_time = try vort.ZipDosTimestamp.fromComponents(.{
        .year = 2023,
        .month = 7,
        .day = 8,
        .hour = 9,
        .minute = 10,
        .second = 11,
    });
    const entries = [_]Entry{
        .{
            .name = "known-stored.bin",
            .data = known_stored,
            .method = .stored,
            .expected_size = known_stored.len,
            .comment = "known size",
            .modified = metadata_time,
            .extended_timestamp = .{
                .modified = 1_700_000_001,
                .accessed = 1_700_000_002,
                .created = -1,
            },
            .ntfs_timestamp = .{
                .modified = try vort.zipFileTimeFromUnixSeconds(1_700_000_001),
                .accessed = try vort.zipFileTimeFromUnixSeconds(1_700_000_002),
                .created = try vort.zipFileTimeFromUnixSeconds(1_700_000_003),
            },
            .creator_system = .unix,
            .internal_attributes = 1,
            .external_attributes = vort.zipUnixExternalAttributes(0o100600),
        },
        .{
            .name = "unknown-stored.bin",
            .data = unknown_stored,
            .method = .stored,
            .expected_size = null,
            .comment = "descriptor signatures are payload data",
        },
        .{
            .name = "known-deflate.txt",
            .data = known_deflate,
            .method = .deflate,
            .expected_size = known_deflate.len,
        },
        .{
            .name = "utf8-目录/未知-deflate.txt",
            .data = unknown_deflate,
            .method = .deflate,
            .expected_size = null,
            .comment = "UTF-8 条目",
        },
        .{
            .name = "empty-stored.bin",
            .data = "",
            .method = .stored,
            .expected_size = 0,
        },
        .{
            .name = "empty-deflate.bin",
            .data = "",
            .method = .deflate,
            .expected_size = 0,
        },
        .{
            .name = "known-bzip2.txt",
            .data = known_bzip2,
            .method = .bzip2,
            .expected_size = known_bzip2.len,
        },
        .{
            .name = "unknown-bzip2.txt",
            .data = unknown_bzip2,
            .method = .bzip2,
            .expected_size = null,
        },
        .{
            .name = "empty-bzip2.bin",
            .data = "",
            .method = .bzip2,
            .expected_size = 0,
        },
        .{
            .name = "known-zstd.txt",
            .data = known_zstd,
            .method = .zstandard,
            .expected_size = known_zstd.len,
        },
        .{
            .name = "unknown-zstd-legacy.txt",
            .data = unknown_zstd,
            .method = .zstandard_legacy,
            .expected_size = null,
        },
        .{
            .name = "empty-zstd.bin",
            .data = "",
            .method = .zstandard,
            .expected_size = 0,
        },
        .{
            .name = "known-lzma.txt",
            .data = known_lzma,
            .method = .lzma,
            .expected_size = known_lzma.len,
        },
        .{
            .name = "unknown-lzma.txt",
            .data = unknown_lzma,
            .method = .lzma,
            .expected_size = null,
        },
        .{
            .name = "empty-lzma.bin",
            .data = "",
            .method = .lzma,
            .expected_size = 0,
        },
        .{
            .name = "known-xz.txt",
            .data = known_xz,
            .method = .xz,
            .expected_size = known_xz.len,
        },
        .{
            .name = "unknown-xz.txt",
            .data = unknown_xz,
            .method = .xz,
            .expected_size = null,
        },
        .{
            .name = "empty-xz.bin",
            .data = "",
            .method = .xz,
            .expected_size = 0,
        },
        .{
            .name = "known-deflate64.bin",
            .data = known_deflate64,
            .method = .deflate64,
            .expected_size = known_deflate64.len,
        },
        .{
            .name = "unknown-deflate64.bin",
            .data = unknown_deflate64,
            .method = .deflate64,
            .expected_size = null,
        },
        .{
            .name = "empty-deflate64.bin",
            .data = "",
            .method = .deflate64,
            .expected_size = 0,
        },
        .{
            .name = "known-ppmd.txt",
            .data = known_ppmd,
            .method = .ppmd,
            .expected_size = known_ppmd.len,
        },
        .{
            .name = "unknown-ppmd.txt",
            .data = unknown_ppmd,
            .method = .ppmd,
            .expected_size = null,
        },
        .{
            .name = "empty-ppmd.bin",
            .data = "",
            .method = .ppmd,
            .expected_size = 0,
        },
        .{
            .name = "known-shrink.txt",
            .data = known_shrink,
            .method = .shrink,
            .expected_size = known_shrink.len,
        },
        .{
            .name = "unknown-shrink.txt",
            .data = unknown_shrink,
            .method = .shrink,
            .expected_size = null,
        },
        .{
            .name = "empty-shrink.bin",
            .data = "",
            .method = .shrink,
            .expected_size = 0,
        },
        .{
            .name = "known-dcl-implode.txt",
            .data = known_dcl,
            .method = .dcl_implode,
            .expected_size = known_dcl.len,
        },
        .{
            .name = "unknown-dcl-implode.txt",
            .data = unknown_dcl,
            .method = .dcl_implode,
            .expected_size = null,
        },
        .{
            .name = "empty-dcl-implode.bin",
            .data = "",
            .method = .dcl_implode,
            .expected_size = 0,
        },
        .{
            .name = "known-reduce-1.txt",
            .data = known_reduce_1,
            .method = .reduce_1,
            .expected_size = known_reduce_1.len,
        },
        .{
            .name = "unknown-reduce-1.txt",
            .data = unknown_reduce_1,
            .method = .reduce_1,
            .expected_size = null,
        },
        .{
            .name = "empty-reduce-1.bin",
            .data = "",
            .method = .reduce_1,
            .expected_size = 0,
        },
        .{
            .name = "known-reduce-2.txt",
            .data = known_reduce_2,
            .method = .reduce_2,
            .expected_size = known_reduce_2.len,
        },
        .{
            .name = "unknown-reduce-2.txt",
            .data = unknown_reduce_2,
            .method = .reduce_2,
            .expected_size = null,
        },
        .{
            .name = "empty-reduce-2.bin",
            .data = "",
            .method = .reduce_2,
            .expected_size = 0,
        },
        .{
            .name = "known-reduce-3.txt",
            .data = known_reduce_3,
            .method = .reduce_3,
            .expected_size = known_reduce_3.len,
        },
        .{
            .name = "unknown-reduce-3.txt",
            .data = unknown_reduce_3,
            .method = .reduce_3,
            .expected_size = null,
        },
        .{
            .name = "empty-reduce-3.bin",
            .data = "",
            .method = .reduce_3,
            .expected_size = 0,
        },
        .{
            .name = "known-reduce-4.txt",
            .data = known_reduce_4,
            .method = .reduce_4,
            .expected_size = known_reduce_4.len,
        },
        .{
            .name = "unknown-reduce-4.txt",
            .data = unknown_reduce_4,
            .method = .reduce_4,
            .expected_size = null,
        },
        .{
            .name = "empty-reduce-4.bin",
            .data = "",
            .method = .reduce_4,
            .expected_size = 0,
        },
        .{
            .name = "known-implode.txt",
            .data = known_implode,
            .method = .implode,
            .expected_size = known_implode.len,
        },
        .{
            .name = "unknown-implode.txt",
            .data = unknown_implode,
            .method = .implode,
            .expected_size = null,
        },
        .{
            .name = "empty-implode.bin",
            .data = "",
            .method = .implode,
            .expected_size = 0,
        },
    };

    const encrypted_entries = [_]Entry{
        .{
            .name = "encrypted-known.bin",
            .data = "incremental ZipCrypto stored payload\n" ** 31,
            .method = .stored,
            .expected_size = ("incremental ZipCrypto stored payload\n" ** 31).len,
            .traditional_encryption = .{
                .password = "vort-zip-password",
                .header_random = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            },
        },
        .{
            .name = "encrypted-unknown.txt",
            .data = "incremental ZipCrypto Deflate payload\n" ** 89,
            .method = .deflate,
            .expected_size = null,
            .traditional_encryption = .{
                .password = "vort-zip-password",
                .header_random = .{ 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 },
            },
        },
        .{
            .name = "encrypted-empty.bin",
            .data = "",
            .method = .stored,
            .expected_size = 0,
            .traditional_encryption = .{
                .password = "vort-zip-password",
                .header_random = .{ 0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa },
            },
        },
    };
    const aes128_salt = [_]u8{0x71} ** 8;
    const aes192_salt = [_]u8{0x72} ** 12;
    const aes256_salt = [_]u8{0x73} ** 16;
    const winzip_aes_entries = [_]Entry{
        .{
            .name = "aes-known.bin",
            .data = "incremental WinZip AES stored payload\n" ** 31,
            .method = .stored,
            .expected_size = ("incremental WinZip AES stored payload\n" ** 31).len,
            .winzip_aes = .{
                .password = "vort-aes-password",
                .strength = .aes128,
                .salt = &aes128_salt,
                .version = .ae1,
            },
        },
        .{
            .name = "aes-unknown.txt",
            .data = "incremental WinZip AES Deflate payload\n" ** 89,
            .method = .deflate,
            .expected_size = null,
            .winzip_aes = .{
                .password = "vort-aes-password",
                .strength = .aes192,
                .salt = &aes192_salt,
                .version = .ae2,
            },
        },
        .{
            .name = "aes-empty.bin",
            .data = "",
            .method = .stored,
            .expected_size = 0,
            .winzip_aes = .{
                .password = "vort-aes-password",
                .strength = .aes256,
                .salt = &aes256_salt,
                .version = .ae2,
            },
        },
    };
    const strong_iv128 = [_]u8{0x91} ** 16;
    const strong_iv192 = [_]u8{0x92} ** 16;
    const strong_iv256 = [_]u8{0x93} ** 16;
    const strong_random128 = [_]u8{0xa1} ** 16;
    const strong_random192 = [_]u8{0xa2} ** 16;
    const strong_random256 = [_]u8{0xa3} ** 32;
    const strong_validation128 = [_]u8{0xb1} ** 12;
    const strong_validation192 = [_]u8{0xb2} ** 12;
    const strong_validation256 = [_]u8{0xb3} ** 12;
    const pkware_strong_entries = [_]Entry{
        .{
            .name = "strong-known.bin",
            .data = "incremental PKWARE Strong stored payload\n" ** 31,
            .method = .stored,
            .expected_size = ("incremental PKWARE Strong stored payload\n" ** 31).len,
            .pkware_strong_encryption = .{
                .password = "vort-strong-password",
                .strength = .aes128,
                .iv = strong_iv128,
                .random_data = &strong_random128,
                .validation_data = &strong_validation128,
            },
        },
        .{
            .name = "strong-unknown.txt",
            .data = "incremental PKWARE Strong Deflate payload\n" ** 89,
            .method = .deflate,
            .expected_size = null,
            .pkware_strong_encryption = .{
                .password = "vort-strong-password",
                .strength = .aes192,
                .iv = strong_iv192,
                .random_data = &strong_random192,
                .validation_data = &strong_validation192,
            },
        },
        .{
            .name = "strong-empty.bin",
            .data = "",
            .method = .stored,
            .expected_size = 0,
            .pkware_strong_encryption = .{
                .password = "vort-strong-password",
                .strength = .aes256,
                .iv = strong_iv256,
                .random_data = &strong_random256,
                .validation_data = &strong_validation256,
            },
        },
    };
    const unicode_entries = [_]Entry{
        .{
            .name = "\x82-stream-name.txt",
            .unicode_name = "流式/数据.txt",
            .data = "incremental Unicode path payload\n" ** 31,
            .method = .deflate,
            .expected_size = null,
            .comment = "\x82-stream-comment",
            .unicode_comment = "流式注释",
        },
        .{
            .name = "stream-directory/",
            .unicode_name = "流式目录/",
            .data = "",
            .method = .stored,
            .expected_size = 0,
        },
    };

    const selected_entries: []const Entry = if (entry_mode) |value|
        if (std.mem.eql(u8, value, "zipcrypto"))
            &encrypted_entries
        else if (std.mem.eql(u8, value, "winzip-aes"))
            &winzip_aes_entries
        else if (std.mem.eql(u8, value, "pkware-strong"))
            &pkware_strong_entries
        else if (std.mem.eql(u8, value, "unicode"))
            &unicode_entries
        else if (std.mem.eql(u8, value, "split"))
            entries[0..6]
        else
            return error.InvalidEntryMode
    else
        &entries;

    if (split_mode) {
        var encoded = try encodeSplitArchive(
            init.gpa,
            selected_entries,
            zip64,
            output_pattern,
        );
        defer encoded.deinit();
        for (encoded.parts, 0..) |part, index| {
            const path = if (index + 1 == encoded.parts.len)
                try std.fmt.allocPrint(init.gpa, "{s}.zip", .{output_path})
            else
                try std.fmt.allocPrint(init.gpa, "{s}.z{d:0>2}", .{
                    output_path,
                    index + 1,
                });
            defer init.gpa.free(path);
            try std.Io.Dir.cwd().writeFile(init.io, .{
                .sub_path = path,
                .data = part,
            });
        }
    } else {
        const encoded = try encodeArchive(init.gpa, selected_entries, zip64, output_pattern);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    }
}

const SplitArchive = struct {
    allocator: std.mem.Allocator,
    parts: [][]u8,

    fn deinit(self: *SplitArchive) void {
        for (self.parts) |part| self.allocator.free(part);
        self.allocator.free(self.parts);
        self.* = undefined;
    }
};

fn usesUnicodeExtra(entries: []const Entry) bool {
    for (entries) |entry|
        if (entry.unicode_name != null or entry.unicode_comment != null) return true;
    return false;
}

fn encodeSplitArchive(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    zip64: vort.Zip64Mode,
    output_pattern: OutputPattern,
) !SplitArchive {
    var writer = try vort.ZipSplitIncrementalWriter.initWithOptions(allocator, .{
        .writer_options = .{
            .archive_comment = "vort incremental split writer interop",
            .zip64 = zip64,
            .utf8 = !usesUnicodeExtra(entries),
            .max_deflate_buffer_size = 1024 * 1024,
        },
        .max_part_size = 160,
    });
    defer writer.deinit();
    var parts: std.ArrayList([]u8) = .empty;
    errdefer {
        for (parts.items) |part| allocator.free(part);
        parts.deinit(allocator);
    }
    var current: std.ArrayList(u8) = .empty;
    defer current.deinit(allocator);
    var output_storage: [7]u8 = undefined;
    var output_index: usize = 0;

    for (entries, 0..) |entry, entry_index| {
        try writer.beginEntry(.{
            .name = entry.name,
            .comment = entry.comment,
            .unicode_name = entry.unicode_name,
            .unicode_comment = entry.unicode_comment,
            .method = entry.method,
            .expected_size = entry.expected_size,
            .modified = entry.modified,
            .extended_timestamp = entry.extended_timestamp,
            .ntfs_timestamp = entry.ntfs_timestamp,
            .creator_system = entry.creator_system,
            .internal_attributes = entry.internal_attributes,
            .external_attributes = entry.external_attributes,
            .traditional_encryption = entry.traditional_encryption,
            .winzip_aes = entry.winzip_aes,
            .pkware_strong_encryption = entry.pkware_strong_encryption,
        });
        if (entry_index == 0) {
            const blocked = try writer.step(entry.data[0..1], &.{});
            if (blocked.status != .need_output or
                blocked.progress.input_read != 0 or
                blocked.progress.output_written != 0)
                return error.ZeroOutputBackpressureMismatch;
        }
        var input_offset: usize = 0;
        var input_index: usize = 0;
        while (input_offset < entry.data.len) {
            const input_end = @min(
                entry.data.len,
                input_offset + input_chunks[input_index % input_chunks.len],
            );
            input_index += 1;
            while (input_offset < input_end) {
                const output = nextOutput(&output_storage, output_pattern, &output_index);
                const stepped = try writer.step(entry.data[input_offset..input_end], output);
                input_offset += stepped.progress.input_read;
                try current.appendSlice(allocator, output[0..stepped.progress.output_written]);
                try finishSplitPart(allocator, &parts, &current, stepped.status);
                if (stepped.progress.input_read == 0 and
                    stepped.progress.output_written == 0 and
                    stepped.status != .part_done)
                    return error.WriterMadeNoProgress;
            }
        }
        try writer.finishEntry();
        while (writer.snapshot().phase != .ready) {
            const output = nextOutput(&output_storage, output_pattern, &output_index);
            const stepped = try writer.step("", output);
            try current.appendSlice(allocator, output[0..stepped.progress.output_written]);
            try finishSplitPart(allocator, &parts, &current, stepped.status);
            if (stepped.progress.output_written == 0 and stepped.status != .part_done)
                return error.WriterMadeNoProgress;
        }
    }
    try writer.finishArchive();
    while (true) {
        const output = nextOutput(&output_storage, output_pattern, &output_index);
        const stepped = try writer.step("", output);
        try current.appendSlice(allocator, output[0..stepped.progress.output_written]);
        try finishSplitPart(allocator, &parts, &current, stepped.status);
        if (stepped.status == .done) break;
        if (stepped.progress.output_written == 0 and stepped.status != .part_done)
            return error.WriterMadeNoProgress;
    }
    if (current.items.len == 0) return error.WriterMadeNoProgress;
    const final_part = try current.toOwnedSlice(allocator);
    parts.append(allocator, final_part) catch |err| {
        allocator.free(final_part);
        return err;
    };
    return .{
        .allocator = allocator,
        .parts = try parts.toOwnedSlice(allocator),
    };
}

fn finishSplitPart(
    allocator: std.mem.Allocator,
    parts: *std.ArrayList([]u8),
    current: *std.ArrayList(u8),
    status: vort.ZipSplitIncrementalWriterStepResult.Status,
) !void {
    if (status != .part_done) return;
    if (current.items.len == 0) return error.WriterMadeNoProgress;
    const part = try current.toOwnedSlice(allocator);
    parts.append(allocator, part) catch |err| {
        allocator.free(part);
        return err;
    };
}

fn encodeArchive(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    zip64: vort.Zip64Mode,
    output_pattern: OutputPattern,
) ![]u8 {
    var writer = try vort.ZipIncrementalWriter.initWithOptions(allocator, .{
        .archive_comment = "vort incremental writer interop",
        .zip64 = zip64,
        .utf8 = !usesUnicodeExtra(entries),
        .bzip2_options = .{ .block_size_100k = 1 },
        .zstd_options = .{
            .content_checksum = true,
            .block_size_max = 4096,
            .selection = .raw_or_rle,
        },
        .lzma_options = .{
            .dictionary_size = 4096,
            .mode = .literal_only,
            .input_buffer_len = 4096,
        },
        .xz_options = .{
            .check = .crc64,
            .block_size = 1024,
            .dictionary_size = 4096,
        },
        .deflate64_options = .{ .block_len = 4096 },
        .ppmd_options = .{
            .properties = .{
                .order = 12,
                .memory_size = 1024 * 1024,
                .restore_method = .cut_off,
            },
        },
    });
    defer writer.deinit();

    var archive: std.ArrayList(u8) = .empty;
    errdefer archive.deinit(allocator);
    var output_storage: [7]u8 = undefined;
    var output_index: usize = 0;

    for (entries, 0..) |entry, entry_index| {
        try writer.beginEntry(.{
            .name = entry.name,
            .comment = entry.comment,
            .unicode_name = entry.unicode_name,
            .unicode_comment = entry.unicode_comment,
            .method = entry.method,
            .expected_size = entry.expected_size,
            .modified = entry.modified,
            .extended_timestamp = entry.extended_timestamp,
            .ntfs_timestamp = entry.ntfs_timestamp,
            .creator_system = entry.creator_system,
            .internal_attributes = entry.internal_attributes,
            .external_attributes = entry.external_attributes,
            .traditional_encryption = entry.traditional_encryption,
            .winzip_aes = entry.winzip_aes,
            .pkware_strong_encryption = entry.pkware_strong_encryption,
        });
        if (entry_index == 0) {
            const blocked = try writer.step(entry.data[0..1], &.{});
            if (blocked.status != .need_output or
                blocked.progress.input_read != 0 or
                blocked.progress.output_written != 0)
                return error.ZeroOutputBackpressureMismatch;
        }

        var input_offset: usize = 0;
        var input_index: usize = 0;
        while (input_offset < entry.data.len) {
            const input_end = @min(
                entry.data.len,
                input_offset + input_chunks[input_index % input_chunks.len],
            );
            input_index += 1;
            while (input_offset < input_end) {
                const output = nextOutput(&output_storage, output_pattern, &output_index);
                const stepped = try writer.step(entry.data[input_offset..input_end], output);
                input_offset += stepped.progress.input_read;
                try archive.appendSlice(allocator, output[0..stepped.progress.output_written]);
                if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0)
                    return error.WriterMadeNoProgress;
            }
        }

        try writer.finishEntry();
        while (writer.snapshot().phase != .ready) {
            const output = nextOutput(&output_storage, output_pattern, &output_index);
            const stepped = try writer.step("", output);
            try archive.appendSlice(allocator, output[0..stepped.progress.output_written]);
            if (stepped.progress.output_written == 0) return error.WriterMadeNoProgress;
        }
    }

    try writer.finishArchive();
    while (true) {
        const output = nextOutput(&output_storage, output_pattern, &output_index);
        const stepped = try writer.step("", output);
        try archive.appendSlice(allocator, output[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        if (stepped.progress.output_written == 0) return error.WriterMadeNoProgress;
    }
    return archive.toOwnedSlice(allocator);
}

fn nextOutput(storage: *[7]u8, pattern: OutputPattern, index: *usize) []u8 {
    const len = switch (pattern) {
        .one => 1,
        .micro => micro_output_chunks[index.* % micro_output_chunks.len],
    };
    index.* += 1;
    return storage[0..len];
}
