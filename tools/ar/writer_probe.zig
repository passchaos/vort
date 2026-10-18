const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const mode = args.next() orelse "regular";
    if (std.mem.eql(u8, mode, "thin")) {
        const payloads = [_][]const u8{ "thin short payload\n", "thin long payload\n" };
        const names = [_][]const u8{
            "thin-short.txt",
            "thin/very-long-member-name-for-vort.txt",
        };
        const parent = std.fs.path.dirname(output_path) orelse ".";
        const subdir = try std.fs.path.join(init.gpa, &.{ parent, "thin" });
        defer init.gpa.free(subdir);
        std.Io.Dir.cwd().createDir(init.io, subdir, .default_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        for (names, payloads) |name, payload| {
            const path = try std.fs.path.join(init.gpa, &.{ parent, name });
            defer init.gpa.free(path);
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = payload });
        }
        const entries = [_]vort.ArThinEncodeEntry{
            .{ .name = names[0], .size = payloads[0].len, .mode = 0o100600 },
            .{ .name = names[1], .size = payloads[1].len },
        };
        const encoded = try vort.encodeThinArAlloc(init.gpa, &entries);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        return;
    }
    if (!std.mem.eql(u8, mode, "regular")) return error.UnsupportedArFeature;
    const entries = [_]vort.ArEncodeEntry{
        .{ .name = "short.txt", .data = "short ar payload\n", .mode = 0o100600 },
        .{ .name = "very-long-member-name-for-vort.txt", .data = "long ar payload\n" },
        .{ .name = "odd.bin", .data = &.{ 0, 1, 2, 3, 4 } },
    };
    const encoded = try vort.encodeArAlloc(init.gpa, &entries);
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
}
