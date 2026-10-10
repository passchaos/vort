const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const entries = [_]vort.ArEncodeEntry{
        .{ .name = "short.txt", .data = "short ar payload\n", .mode = 0o100600 },
        .{ .name = "very-long-member-name-for-vort.txt", .data = "long ar payload\n" },
        .{ .name = "odd.bin", .data = &.{ 0, 1, 2, 3, 4 } },
    };
    const encoded = try vort.encodeArAlloc(init.gpa, &entries);
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
}
