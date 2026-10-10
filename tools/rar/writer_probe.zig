const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const version_text = args.next() orelse "rar5";
    const version: vort.RarVersion = if (std.mem.eql(u8, version_text, "rar4")) .rar4 else .rar5;
    const mode = args.next() orelse "stored";
    if (std.mem.eql(u8, mode, "solid")) {
        if (version != .rar5) return error.UnsupportedRarVersion;
        const payload = "solid history payload alpha beta gamma\n" ** 128;
        const solid_entries = [_]vort.RarEncodeEntry{
            .{ .name = "first.txt", .data = payload },
            .{ .name = "second.txt", .data = payload },
        };
        const solid_bytes = try vort.encodeRarAlloc(init.gpa, &solid_entries, .{
            .version = .rar5,
            .compression = .rar50,
            .solid = true,
        });
        defer init.gpa.free(solid_bytes);
        try std.Io.Dir.cwd().writeFile(
            init.io,
            .{ .sub_path = output_path, .data = solid_bytes },
        );
        return;
    }
    const second_name: []const u8 = if (version == .rar5) "目录/数据.txt" else "folder/data.txt";
    const entries = [_]vort.RarEncodeEntry{
        .{ .name = "plain.txt", .data = "Vort RAR payload\n", .mode = 0o100640 },
        .{ .name = "folder", .kind = .directory },
        .{ .name = second_name, .data = &.{ 0, 1, 2, 0xff } },
    };
    const bytes = try vort.encodeRarAlloc(init.gpa, &entries, .{ .version = version });
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
}
