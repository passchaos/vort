const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const compression_name = args.next() orelse "xpress";
    const compression = parseCompression(compression_name) orelse
        return error.InvalidBlockPlan;

    const large = "Vort WIM writer multichunk payload 0123456789\n" ** 4096;
    var random: [70_000]u8 = undefined;
    fillPseudoRandom(&random);
    const entries = [_]vort.WimEncodeEntry{
        .{ .path = "nested/config.txt", .data = "Vort WIM writer interop\n" },
        .{ .path = "large.bin", .data = large },
        .{ .path = "random.bin", .data = &random },
        .{ .path = "empty.bin" },
        .{ .path = "unicode/文件.txt", .data = "UTF-8 WIM path\n" },
    };
    const encoded = try vort.encodeWimAlloc(init.gpa, &entries, .{
        .compression = compression,
        .image_name = "Vort writer & interoperability",
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
}

fn parseCompression(name: []const u8) ?vort.WimEncodeCompression {
    if (std.mem.eql(u8, name, "stored")) return .stored;
    if (std.mem.eql(u8, name, "xpress")) return .xpress;
    return null;
}

fn fillPseudoRandom(output: []u8) void {
    var state: u32 = 0x5749_4d31;
    for (output) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
}
