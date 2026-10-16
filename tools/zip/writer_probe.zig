const std = @import("std");
const vort = @import("vort");

fn makeLegacyPayload(allocator: std.mem.Allocator, prefix_len: usize, seed: u32) ![]u8 {
    const payload = try allocator.alloc(u8, prefix_len * 2 + 1);
    var state = seed;
    for (payload[0..prefix_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    payload[prefix_len] = 0x42;
    @memcpy(payload[prefix_len + 1 ..], payload[0..prefix_len]);
    return payload;
}

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const mode = args.next();
    var zip64: vort.Zip64Mode = .auto;
    var ppmd_cutoff = false;
    var implode_large = true;
    var implode_literal_tree = true;
    var implode_mode = false;
    var implode_descriptor_mode = false;
    var dcl_dictionary_bits: u3 = 6;
    var dcl_literal_coded = true;
    var dcl_mode = false;
    var reduce_mode = false;
    var reduce_descriptor_mode = false;
    var zipcrypto_mode = false;
    var zipcrypto_descriptor_mode = false;
    var winzip_aes_mode = false;
    var winzip_aes_descriptor_mode = false;
    var pkware_strong_mode = false;
    var pkware_strong_descriptor_mode = false;
    var split_mode = false;
    var unicode_mode = false;
    if (mode) |value| {
        if (std.mem.eql(u8, value, "zip64")) {
            zip64 = .always;
        } else if (std.mem.eql(u8, value, "split")) {
            split_mode = true;
        } else if (std.mem.eql(u8, value, "split-zip64")) {
            split_mode = true;
            zip64 = .always;
        } else if (std.mem.eql(u8, value, "ppmd-cutoff")) {
            ppmd_cutoff = true;
        } else if (std.mem.startsWith(u8, value, "implode-")) {
            implode_mode = true;
            var specification: []const u8 = value["implode-".len..];
            if (std.mem.endsWith(u8, specification, "-descriptor")) {
                implode_descriptor_mode = true;
                specification = specification[0 .. specification.len - "-descriptor".len];
            }
            if (std.mem.startsWith(u8, specification, "4k-"))
                implode_large = false
            else if (!std.mem.startsWith(u8, specification, "8k-"))
                return error.InvalidZipMode;
            if (std.mem.endsWith(u8, specification, "tree"))
                implode_literal_tree = true
            else if (std.mem.endsWith(u8, specification, "raw"))
                implode_literal_tree = false
            else
                return error.InvalidZipMode;
        } else if (std.mem.eql(u8, value, "reduce")) {
            reduce_mode = true;
        } else if (std.mem.eql(u8, value, "reduce-descriptor")) {
            reduce_descriptor_mode = true;
        } else if (std.mem.eql(u8, value, "zipcrypto")) {
            zipcrypto_mode = true;
        } else if (std.mem.eql(u8, value, "zipcrypto-descriptor")) {
            zipcrypto_mode = true;
            zipcrypto_descriptor_mode = true;
        } else if (std.mem.eql(u8, value, "winzip-aes")) {
            winzip_aes_mode = true;
        } else if (std.mem.eql(u8, value, "winzip-aes-descriptor")) {
            winzip_aes_mode = true;
            winzip_aes_descriptor_mode = true;
        } else if (std.mem.eql(u8, value, "pkware-strong")) {
            pkware_strong_mode = true;
        } else if (std.mem.eql(u8, value, "pkware-strong-descriptor")) {
            pkware_strong_mode = true;
            pkware_strong_descriptor_mode = true;
        } else if (std.mem.eql(u8, value, "unicode")) {
            unicode_mode = true;
        } else if (std.mem.startsWith(u8, value, "dcl-")) {
            dcl_mode = true;
            const specification = value["dcl-".len..];
            if (std.mem.startsWith(u8, specification, "1k-"))
                dcl_dictionary_bits = 4
            else if (std.mem.startsWith(u8, specification, "2k-"))
                dcl_dictionary_bits = 5
            else if (!std.mem.startsWith(u8, specification, "4k-"))
                return error.InvalidZipMode;
            if (std.mem.endsWith(u8, specification, "coded"))
                dcl_literal_coded = true
            else if (std.mem.endsWith(u8, specification, "raw"))
                dcl_literal_coded = false
            else
                return error.InvalidZipMode;
        } else {
            return error.InvalidZipMode;
        }
    }

    const stored = [_]u8{ 0, 1, 2, 0xff } ++ "stored by Vort".*;
    const shrink_payload = try init.gpa.alloc(u8, 32 * 1024);
    defer init.gpa.free(shrink_payload);
    var shrink_state: u32 = 0x5a17_c9e3;
    for (shrink_payload) |*byte| {
        shrink_state = shrink_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(shrink_state >> 24);
    }
    const implode_payload = try init.gpa.alloc(u8, 10_001);
    defer init.gpa.free(implode_payload);
    var implode_state: u32 = 0x193a_72d5;
    for (implode_payload[0..5000]) |*byte| {
        implode_state = implode_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(implode_state >> 24);
    }
    implode_payload[5000] = 0x42;
    @memcpy(implode_payload[5001..], implode_payload[0..5000]);
    const reduce1_payload = try makeLegacyPayload(init.gpa, 400, 0x1020_3041);
    defer init.gpa.free(reduce1_payload);
    const reduce2_payload = try makeLegacyPayload(init.gpa, 800, 0x2030_4052);
    defer init.gpa.free(reduce2_payload);
    const reduce3_payload = try makeLegacyPayload(init.gpa, 1500, 0x3040_5063);
    defer init.gpa.free(reduce3_payload);
    const reduce4_payload = try makeLegacyPayload(init.gpa, 3000, 0x4050_6074);
    defer init.gpa.free(reduce4_payload);
    const deflated = "Vort ZIP writer differential.\n" ** 128;
    const deflate64_payload = "Vort ZIP Deflate64 method 9.\n" ** 128;
    const dcl_implode_payload = try makeLegacyPayload(init.gpa, 3000, 0xdca1_0010);
    defer init.gpa.free(dcl_implode_payload);
    const bzip2_payload = "Vort ZIP Bzip2 method 12.\n" ** 96;
    const lzma_payload = "Vort ZIP LZMA method 14.\n" ** 96;
    const xz_payload = "Vort ZIP XZ method 95.\n" ** 96;
    const zstd_legacy_payload = "Vort ZIP legacy Zstandard method 20.\n" ** 96;
    const zstd_payload = "Vort ZIP Zstandard method 93.\n" ** 96;
    const ppmd_payload = "Vort ZIP PPMd method 98.\n" ** 128;
    const utf8_payload = "ZIP UTF-8 文件名\n" ** 17;
    const split_payload = try init.gpa.alloc(u8, 384 * 1024);
    defer init.gpa.free(split_payload);
    var split_state: u32 = 0x51a7_2026;
    for (0..split_payload.len / 128) |block| {
        for (0..64) |index| {
            split_state = split_state *% 1_664_525 +% 1_013_904_223;
            const value: u8 = @truncate(split_state >> 24);
            split_payload[block * 128 + index] = value;
            split_payload[block * 128 + 64 + index] = value;
        }
    }
    const metadata_time = try vort.ZipDosTimestamp.fromComponents(.{
        .year = 2026,
        .month = 10,
        .day = 17,
        .hour = 1,
        .minute = 23,
        .second = 45,
    });
    const extended_timestamp: vort.ZipExtendedTimestamp = .{
        .modified = 1_700_000_001,
        .accessed = 1_700_000_002,
        .created = -1,
    };
    const ntfs_timestamp: vort.ZipNtfsTimestamp = .{
        .modified = try vort.zipFileTimeFromUnixSeconds(1_700_000_001),
        .accessed = try vort.zipFileTimeFromUnixSeconds(1_700_000_002),
        .created = try vort.zipFileTimeFromUnixSeconds(1_700_000_003),
    };
    const entries = [_]vort.ZipEncodeEntry{
        .{
            .name = "stored.bin",
            .data = &stored,
            .method = .stored,
            .comment = "stored entry",
            .modified = metadata_time,
            .extended_timestamp = extended_timestamp,
            .ntfs_timestamp = ntfs_timestamp,
            .creator_system = .unix,
            .internal_attributes = 1,
            .external_attributes = vort.zipUnixExternalAttributes(0o100640),
        },
        .{ .name = "folder/shrink.txt", .data = shrink_payload, .method = .shrink, .comment = "shrink entry" },
        .{ .name = "folder/implode.txt", .data = implode_payload, .method = .implode, .comment = "implode entry" },
        .{ .name = "folder/reduce1.txt", .data = reduce1_payload, .method = .reduce_1, .comment = "reduce1 entry" },
        .{ .name = "folder/reduce2.txt", .data = reduce2_payload, .method = .reduce_2, .comment = "reduce2 entry" },
        .{ .name = "folder/reduce3.txt", .data = reduce3_payload, .method = .reduce_3, .comment = "reduce3 entry" },
        .{ .name = "folder/reduce4.txt", .data = reduce4_payload, .method = .reduce_4, .comment = "reduce4 entry" },
        .{ .name = "folder/deflated.txt", .data = deflated, .method = .deflate, .comment = "deflated entry" },
        .{ .name = "folder/deflate64.txt", .data = deflate64_payload, .method = .deflate64, .comment = "deflate64 entry" },
        .{ .name = "folder/dcl-implode.txt", .data = dcl_implode_payload, .method = .dcl_implode, .comment = "dcl implode entry" },
        .{ .name = "folder/bzip2.txt", .data = bzip2_payload, .method = .bzip2, .comment = "bzip2 entry" },
        .{ .name = "folder/lzma.txt", .data = lzma_payload, .method = .lzma, .comment = "lzma entry" },
        .{ .name = "folder/xz.txt", .data = xz_payload, .method = .xz, .comment = "xz entry" },
        .{ .name = "folder/zstd-legacy.txt", .data = zstd_legacy_payload, .method = .zstandard_legacy, .comment = "legacy zstd entry" },
        .{ .name = "folder/zstd.txt", .data = zstd_payload, .method = .zstandard, .comment = "zstd entry" },
        .{ .name = "folder/ppmd.txt", .data = ppmd_payload, .method = .ppmd, .comment = "ppmd entry" },
        .{ .name = "utf8-目录/数据.txt", .data = utf8_payload, .method = .deflate },
        .{ .name = "empty/", .data = "", .method = .stored },
    };
    const zipcrypto_entries = [_]vort.ZipEncodeEntry{
        .{
            .name = "encrypted/stored.bin",
            .data = "Vort Traditional ZipCrypto stored payload.\n" ** 17,
            .method = .stored,
            .traditional_encryption = .{
                .password = "vort-zip-password",
                .header_random = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            },
        },
        .{
            .name = "encrypted/deflate.txt",
            .data = "Vort Traditional ZipCrypto Deflate payload.\n" ** 97,
            .method = .deflate,
            .traditional_encryption = .{
                .password = "vort-zip-password",
                .header_random = .{ 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 },
            },
        },
    };
    const aes128_salt = [_]u8{0x61} ** 8;
    const aes192_salt = [_]u8{0x62} ** 12;
    const aes256_salt = [_]u8{0x63} ** 16;
    const winzip_aes_entries = [_]vort.ZipEncodeEntry{
        .{
            .name = "aes/stored-128.bin",
            .data = "Vort WinZip AES-128 stored payload longer than twenty bytes.",
            .method = .stored,
            .winzip_aes = .{
                .password = "vort-aes-password",
                .strength = .aes128,
                .salt = &aes128_salt,
                .version = .ae1,
            },
        },
        .{
            .name = "aes/deflate-192.txt",
            .data = "Vort WinZip AES-192 Deflate payload.\n" ** 67,
            .method = .deflate,
            .winzip_aes = .{
                .password = "vort-aes-password",
                .strength = .aes192,
                .salt = &aes192_salt,
                .version = .ae2,
            },
        },
        .{
            .name = "aes/small-256.bin",
            .data = "small",
            .method = .stored,
            .winzip_aes = .{
                .password = "vort-aes-password",
                .strength = .aes256,
                .salt = &aes256_salt,
                .version = .ae2,
            },
        },
    };
    const strong_iv128 = [_]u8{0x71} ** 16;
    const strong_iv192 = [_]u8{0x72} ** 16;
    const strong_iv256 = [_]u8{0x73} ** 16;
    const strong_random128 = [_]u8{0x81} ** 16;
    const strong_random192 = [_]u8{0x82} ** 16;
    const strong_random256 = [_]u8{0x83} ** 32;
    const strong_validation128 = [_]u8{0x91} ** 12;
    const strong_validation192 = [_]u8{0x92} ** 12;
    const strong_validation256 = [_]u8{0x93} ** 12;
    const pkware_strong_entries = [_]vort.ZipEncodeEntry{
        .{
            .name = "strong/stored-128.bin",
            .data = "Vort PKWARE Strong AES-128 stored payload.",
            .method = .stored,
            .pkware_strong_encryption = .{
                .password = "vort-strong-password",
                .strength = .aes128,
                .iv = strong_iv128,
                .random_data = &strong_random128,
                .validation_data = &strong_validation128,
            },
        },
        .{
            .name = "strong/deflate-192.txt",
            .data = "Vort PKWARE Strong AES-192 Deflate payload.\n" ** 67,
            .method = .deflate,
            .pkware_strong_encryption = .{
                .password = "vort-strong-password",
                .strength = .aes192,
                .iv = strong_iv192,
                .random_data = &strong_random192,
                .validation_data = &strong_validation192,
            },
        },
        .{
            .name = "strong/bzip2-256.txt",
            .data = "Vort PKWARE Strong AES-256 Bzip2 payload.\n" ** 53,
            .method = .bzip2,
            .pkware_strong_encryption = .{
                .password = "vort-strong-password",
                .strength = .aes256,
                .iv = strong_iv256,
                .random_data = &strong_random256,
                .validation_data = &strong_validation256,
            },
        },
    };
    const split_entries = [_]vort.ZipEncodeEntry{
        .{
            .name = "split/crossing.bin",
            .data = split_payload,
            .method = .deflate,
            .comment = "cross-volume Deflate",
        },
        .{
            .name = "split/tail.bin",
            .data = "Vort split writer stored tail.\n" ** 97,
            .method = .stored,
            .comment = "final stored entry",
        },
    };
    const unicode_entries = [_]vort.ZipEncodeEntry{
        .{
            .name = "\x82-legacy-name.txt",
            .unicode_name = "目录/数据.txt",
            .data = "Vort Unicode path payload.\n" ** 17,
            .method = .deflate,
            .comment = "\x82-legacy-comment",
            .unicode_comment = "条目注释",
        },
        .{
            .name = "legacy-directory/",
            .unicode_name = "目录/",
            .data = "",
            .method = .stored,
        },
    };

    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(init.gpa);
    try bytes.appendSlice(init.gpa, "MZ-VORT-ZIP-PREFIX\n");
    const selected_entries: []const vort.ZipEncodeEntry = if (split_mode)
        &split_entries
    else if (unicode_mode)
        &unicode_entries
    else if (winzip_aes_mode)
        &winzip_aes_entries
    else if (pkware_strong_mode)
        &pkware_strong_entries
    else if (zipcrypto_mode)
        &zipcrypto_entries
    else if (reduce_mode or reduce_descriptor_mode)
        entries[3..7]
    else if (implode_mode)
        entries[2..3]
    else
        &entries;
    const encode_options: vort.ZipEncodeOptions = .{
        .archive_comment = "vort zip writer differential",
        .utf8 = !unicode_mode,
        .data_descriptor = split_mode or implode_descriptor_mode or reduce_descriptor_mode or
            zipcrypto_descriptor_mode or winzip_aes_descriptor_mode or pkware_strong_descriptor_mode or
            !(implode_mode or reduce_mode or dcl_mode or zipcrypto_mode or winzip_aes_mode or pkware_strong_mode),
        .zip64 = zip64,
        .implode_options = .{
            .dictionary = if (implode_large) .large_8k else .small_4k,
            .literal_tree = implode_literal_tree,
        },
        .dcl_implode_options = .{
            .literal_coded = dcl_literal_coded,
            .dictionary = switch (dcl_dictionary_bits) {
                4 => .size_1k,
                5 => .size_2k,
                6 => .size_4k,
                else => unreachable,
            },
        },
        .ppmd_options = if (ppmd_cutoff) .{
            .order = 12,
            .memory_size = 1024 * 1024,
            .restore_method = .cut_off,
        } else .{},
        .zstd_options = .{ .content_checksum = true },
    };
    if (split_mode) {
        bytes.clearRetainingCapacity();
        var encoded = try vort.zipEncodeSplitAlloc(init.gpa, selected_entries, .{
            .zip_options = encode_options,
            .max_part_size = 64 * 1024,
        });
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
        return;
    }
    _ = try vort.zipEncodeAppend(init.gpa, &bytes, selected_entries, encode_options);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes.items });
}
