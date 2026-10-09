const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const compression_name = args.next() orelse "copy";
    const solid = if (args.next()) |mode|
        std.mem.eql(u8, mode, "solid")
    else
        false;
    const header_name = args.next();
    const bcj2 = if (args.next()) |mode| std.mem.eql(u8, mode, "bcj2") else false;
    const bcj2_start_ip = if (args.next()) |value|
        try std.fmt.parseInt(u32, value, 10)
    else
        0;
    const external_names_name = args.next();
    const external_metadata_name = args.next();
    const compression: vort.SevenZipCompression = if (std.mem.eql(u8, compression_name, "copy"))
        .copy
    else if (std.mem.eql(u8, compression_name, "deflate"))
        .deflate
    else if (std.mem.eql(u8, compression_name, "bzip2"))
        .bzip2
    else if (std.mem.eql(u8, compression_name, "lzma"))
        .lzma
    else if (std.mem.eql(u8, compression_name, "lzma2"))
        .lzma2
    else if (std.mem.eql(u8, compression_name, "lzma2-stored"))
        .lzma2_stored
    else
        return error.UnsupportedCompression;
    const header_compression: ?vort.SevenZipCompression = if (header_name) |name|
        if (std.mem.eql(u8, name, "plain") or std.mem.eql(u8, name, "none"))
            null
        else if (std.mem.eql(u8, name, "copy"))
            .copy
        else if (std.mem.eql(u8, name, "deflate"))
            .deflate
        else if (std.mem.eql(u8, name, "bzip2"))
            .bzip2
        else if (std.mem.eql(u8, name, "lzma"))
            .lzma
        else if (std.mem.eql(u8, name, "lzma2"))
            .lzma2
        else if (std.mem.eql(u8, name, "lzma2-stored"))
            .lzma2_stored
        else
            return error.UnsupportedCompression
    else
        null;
    const external_names: ?vort.SevenZipCompression = if (external_names_name) |name|
        if (std.mem.eql(u8, name, "external-names") or std.mem.eql(u8, name, "external-copy"))
            .copy
        else if (std.mem.eql(u8, name, "external-deflate"))
            .deflate
        else if (std.mem.eql(u8, name, "external-bzip2"))
            .bzip2
        else if (std.mem.eql(u8, name, "external-lzma"))
            .lzma
        else if (std.mem.eql(u8, name, "external-lzma2"))
            .lzma2
        else if (std.mem.eql(u8, name, "external-lzma2-stored"))
            .lzma2_stored
        else if (std.mem.eql(u8, name, "inline-names"))
            null
        else
            return error.UnsupportedCompression
    else
        null;
    const external_metadata: ?vort.SevenZipCompression = if (external_metadata_name) |name|
        if (std.mem.eql(u8, name, "external-metadata") or std.mem.eql(u8, name, "external-metadata-copy"))
            .copy
        else if (std.mem.eql(u8, name, "external-metadata-deflate"))
            .deflate
        else if (std.mem.eql(u8, name, "external-metadata-bzip2"))
            .bzip2
        else if (std.mem.eql(u8, name, "external-metadata-lzma"))
            .lzma
        else if (std.mem.eql(u8, name, "external-metadata-lzma2"))
            .lzma2
        else if (std.mem.eql(u8, name, "external-metadata-lzma2-stored"))
            .lzma2_stored
        else if (std.mem.eql(u8, name, "inline-metadata"))
            null
        else
            return error.UnsupportedCompression
    else
        null;

    const filetime_epoch: u64 = 116_444_736_000_000_000;
    const entries = [_]vort.SevenZipEncodeEntry{
        .{
            .name = "plain.txt",
            .data = "Vort 7z payload\n",
            .creation_time = filetime_epoch + 10_000_000,
            .access_time = filetime_epoch + 20_000_000,
            .modification_time = filetime_epoch + 30_000_000,
            .attributes = 0x81a4_0020,
        },
        .{
            .name = "empty.txt",
            .modification_time = filetime_epoch + 40_000_000,
            .attributes = 0x81a4_0020,
        },
        .{
            .name = "folder",
            .kind = .directory,
            .creation_time = filetime_epoch + 50_000_000,
            .attributes = 0x41ed_0010,
        },
        .{
            .name = "utf8-目录/数据.txt",
            .data = "Vort 7z UTF-8\n",
            .access_time = filetime_epoch + 60_000_000,
            .modification_time = filetime_epoch + 70_000_000,
            .attributes = 0x81a4_0020,
        },
    };
    const bytes = try vort.encodeSevenZipAlloc(init.gpa, &entries, .{
        .compression = compression,
        .solid = solid,
        .header_compression = header_compression,
        .external_names = external_names,
        .external_metadata = external_metadata,
        .bcj2 = bcj2,
        .bcj2_start_ip = bcj2_start_ip,
    });
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
}
