const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const mode_name = args.next() orelse "gzip";
    const mode: vort.SquashfsEncodeMode = if (std.mem.eql(u8, mode_name, "stored"))
        .stored
    else if (std.mem.eql(u8, mode_name, "gzip"))
        .gzip
    else if (std.mem.eql(u8, mode_name, "zstd"))
        .zstandard
    else
        return error.InvalidBlockPlan;
    const large = "SquashFS writer probe multi-block payload 0123456789\n" ** 4096;
    const entries = [_]vort.SquashfsEncodeEntry{
        .{ .path = "etc/config", .data = "writer probe configuration\n" },
        .{ .path = "large.bin", .data = large },
        .{ .path = "small", .data = "fragment payload" },
        .{ .path = "link", .kind = .symlink, .target = "etc/config" },
        .{ .path = "empty", .kind = .directory },
    };
    const encoded = try vort.encodeSquashfsAlloc(init.gpa, &entries, .{
        .mode = mode,
        .block_size = 16 * 1024,
        .modification_time = 0,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
}
