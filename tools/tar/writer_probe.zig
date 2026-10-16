const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;

    const long_name = "nested/" ++ "long-component-" ** 12 ++ "file.txt";
    const sparse_extents = [_]vort.TarSparseDataExtent{
        .{ .offset = 0, .data = "HEAD" },
        .{ .offset = 524_288, .data = "MIDDLE" },
        .{ .offset = 1_048_572, .data = "TAIL" },
    };
    const entries = [_]vort.TarEncodeEntry{
        .{ .name = "plain.txt", .data = "Vort TAR payload\n", .mode = 0o640 },
        .{ .name = "utf8-目录/数据.txt", .data = "Vort TAR UTF-8\n" },
        .{ .name = long_name, .data = "Vort TAR long path\n" },
        .{ .name = "empty/", .kind = .directory },
        .{ .name = "link", .kind = .symbolic_link, .link_name = long_name },
        .{
            .name = "images/sparse.bin",
            .mode = 0o640,
            .sparse = .{
                .logical_size = 1024 * 1024,
                .extents = &sparse_extents,
            },
        },
    };
    const bytes = try vort.encodeTarAlloc(init.gpa, &entries);
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
}
