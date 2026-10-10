const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const mode = args.next();
    const zip64 = if (mode) |value|
        if (std.mem.eql(u8, value, "zip64"))
            vort.Zip64Mode.always
        else if (std.mem.eql(u8, value, "ppmd-cutoff"))
            vort.Zip64Mode.auto
        else
            return error.InvalidZipMode
    else
        vort.Zip64Mode.auto;
    const ppmd_cutoff = if (mode) |value| std.mem.eql(u8, value, "ppmd-cutoff") else false;

    const stored = [_]u8{ 0, 1, 2, 0xff } ++ "stored by Vort".*;
    const deflated = "Vort ZIP writer differential.\n" ** 128;
    const deflate64_payload = "Vort ZIP Deflate64 method 9.\n" ** 128;
    const bzip2_payload = "Vort ZIP Bzip2 method 12.\n" ** 96;
    const lzma_payload = "Vort ZIP LZMA method 14.\n" ** 96;
    const xz_payload = "Vort ZIP XZ method 95.\n" ** 96;
    const zstd_legacy_payload = "Vort ZIP legacy Zstandard method 20.\n" ** 96;
    const zstd_payload = "Vort ZIP Zstandard method 93.\n" ** 96;
    const ppmd_payload = "Vort ZIP PPMd method 98.\n" ** 128;
    const utf8_payload = "ZIP UTF-8 文件名\n" ** 17;
    const entries = [_]vort.ZipEncodeEntry{
        .{ .name = "stored.bin", .data = &stored, .method = .stored, .comment = "stored entry" },
        .{ .name = "folder/deflated.txt", .data = deflated, .method = .deflate, .comment = "deflated entry" },
        .{ .name = "folder/deflate64.txt", .data = deflate64_payload, .method = .deflate64, .comment = "deflate64 entry" },
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
    _ = try vort.zipEncodeAppend(init.gpa, &bytes, &entries, .{
        .archive_comment = "vort zip writer differential",
        .data_descriptor = true,
        .zip64 = zip64,
        .ppmd_options = if (ppmd_cutoff) .{
            .order = 12,
            .memory_size = 1024 * 1024,
            .restore_method = .cut_off,
        } else .{},
        .zstd_options = .{ .content_checksum = true },
    });
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes.items });
}
