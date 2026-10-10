const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const format = try parseFormat(args.next());
    const entries = [_]vort.CpioEncodeEntry{
        .{ .name = "plain.txt", .data = "Vort CPIO payload\n", .permissions = 0o640 },
        .{ .name = "folder", .kind = .directory },
        .{ .name = "folder/data.bin", .data = &.{ 0, 1, 2, 0xff } },
        .{ .name = "link", .kind = .symlink, .data = "folder/data.bin" },
    };
    const bytes = try vort.encodeCpioAlloc(init.gpa, &entries, .{ .format = format });
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
}

fn parseFormat(value: ?[]const u8) !vort.CpioFormat {
    const name = value orelse return .newc;
    if (std.mem.eql(u8, name, "newc")) return .newc;
    if (std.mem.eql(u8, name, "crc")) return .crc;
    if (std.mem.eql(u8, name, "odc")) return .odc;
    if (std.mem.eql(u8, name, "bin")) return .binary_little;
    if (std.mem.eql(u8, name, "bin-be")) return .binary_big;
    return error.UnsupportedCpioFormat;
}
