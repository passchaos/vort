const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;

    const entries = [_]vort.SevenZipEncodeEntry{
        .{ .name = "plain.txt", .data = "Vort 7z payload\n" },
        .{ .name = "empty.txt" },
        .{ .name = "folder", .kind = .directory },
        .{ .name = "utf8-目录/数据.txt", .data = "Vort 7z UTF-8\n" },
    };
    const bytes = try vort.encodeSevenZipStoredAlloc(init.gpa, &entries, .{});
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
}
