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
    if (mode) |value| {
        if (std.mem.eql(u8, value, "zip64")) {
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
    const entries = [_]vort.ZipEncodeEntry{
        .{ .name = "stored.bin", .data = &stored, .method = .stored, .comment = "stored entry" },
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

    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(init.gpa);
    try bytes.appendSlice(init.gpa, "MZ-VORT-ZIP-PREFIX\n");
    const selected_entries: []const vort.ZipEncodeEntry = if (reduce_mode or reduce_descriptor_mode)
        entries[3..7]
    else if (implode_mode)
        entries[2..3]
    else
        &entries;
    _ = try vort.zipEncodeAppend(init.gpa, &bytes, selected_entries, .{
        .archive_comment = "vort zip writer differential",
        .data_descriptor = implode_descriptor_mode or reduce_descriptor_mode or
            !(implode_mode or reduce_mode or dcl_mode),
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
    });
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes.items });
}
