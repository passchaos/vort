const std = @import("std");
const vort = @import("vort");

const Wrapper = enum { raw, zlib, gzip };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingPath;
    const output_path = args.next() orelse return error.MissingPath;
    const level = try std.fmt.parseInt(u4, args.next() orelse return error.MissingLevel, 10);
    const wrapper = std.meta.stringToEnum(Wrapper, args.next() orelse return error.MissingWrapper) orelse return error.InvalidWrapper;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(input);
    const encoded = switch (wrapper) {
        .raw => try vort.encodeRawLevelAlloc(init.gpa, input, level),
        .zlib => try vort.encodeZlibLevelAlloc(init.gpa, input, level),
        .gzip => try vort.encodeGzipLevelAlloc(init.gpa, input, level),
    };
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
}
