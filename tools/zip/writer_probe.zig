const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const zip64 = if (args.next()) |mode|
        if (std.mem.eql(u8, mode, "zip64")) vort.Zip64Mode.always else return error.InvalidZipMode
    else
        vort.Zip64Mode.auto;

    const stored = [_]u8{ 0, 1, 2, 0xff } ++ "stored by Vort".*;
    const deflated = "Vort ZIP writer differential.\n" ** 128;
    const utf8_payload = "ZIP UTF-8 文件名\n" ** 17;
    const entries = [_]vort.ZipEncodeEntry{
        .{ .name = "stored.bin", .data = &stored, .method = .stored, .comment = "stored entry" },
        .{ .name = "folder/deflated.txt", .data = deflated, .method = .deflate, .comment = "deflated entry" },
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
    });
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes.items });
}
