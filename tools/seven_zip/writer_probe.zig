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

    const entries = [_]vort.SevenZipEncodeEntry{
        .{ .name = "plain.txt", .data = "Vort 7z payload\n" },
        .{ .name = "empty.txt" },
        .{ .name = "folder", .kind = .directory },
        .{ .name = "utf8-目录/数据.txt", .data = "Vort 7z UTF-8\n" },
    };
    const bytes = try vort.encodeSevenZipAlloc(init.gpa, &entries, .{
        .compression = compression,
        .solid = solid,
        .header_compression = header_compression,
        .bcj2 = bcj2,
        .bcj2_start_ip = bcj2_start_ip,
    });
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
}
