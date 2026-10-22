const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const compression_name = args.next() orelse "lz4";
    const compression = parseCompression(compression_name) orelse return error.InvalidBlockPlan;

    var random: [8193]u8 = undefined;
    fillPseudoRandom(&random);
    const large = "EROFS writer probe multi-block payload 0123456789\n" ** 4096;
    const config_xattrs = [_]vort.ErofsXattr{
        .{ .name = "user.vort.config", .value = "config-xattr" },
    };
    const small_xattrs = [_]vort.ErofsXattr{
        .{ .name = "user.vort.small", .value = "small-xattr" },
    };
    const directory_xattrs = [_]vort.ErofsXattr{
        .{ .name = "user.vort.directory", .value = "directory-xattr" },
    };
    const root_xattrs = [_]vort.ErofsXattr{
        .{ .name = "user.vort.root", .value = "root-xattr" },
    };
    const entries = [_]vort.ErofsEntry{
        .{ .path = "etc/config", .data = "writer probe configuration\n", .xattrs = &config_xattrs },
        .{ .path = "large.bin", .data = large },
        .{ .path = "random.bin", .data = &random },
        .{ .path = "small", .data = "inline payload", .xattrs = &small_xattrs },
        .{ .path = "link", .kind = .symlink, .target = "etc/config" },
        .{ .path = "empty", .kind = .directory, .xattrs = &directory_xattrs },
    };
    const encoded = try vort.encodeErofsAlloc(init.gpa, &entries, .{
        .compression = compression,
        .volume_name = "vort-writer",
        .root_xattrs = &root_xattrs,
        .xattr_prefixes = &.{"user.vort."},
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
}

fn parseCompression(name: []const u8) ?vort.ErofsWriterCompression {
    if (std.mem.eql(u8, name, "stored")) return .stored;
    if (std.mem.eql(u8, name, "lz4")) return .lz4;
    if (std.mem.eql(u8, name, "deflate")) return .deflate;
    if (std.mem.eql(u8, name, "zstd")) return .zstandard;
    return null;
}

fn fillPseudoRandom(output: []u8) void {
    var state: u32 = 0x1234_5678;
    for (output) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
}
