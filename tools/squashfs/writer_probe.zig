const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const mode_name = args.next() orelse "gzip";
    const mode = parseMode(mode_name) orelse return error.InvalidBlockPlan;
    var random: [32_769]u8 = undefined;
    fillPseudoRandom(&random);
    const large = "SquashFS writer probe multi-block payload 0123456789\n" ** 4096;
    const entries = [_]vort.SquashfsEncodeEntry{
        .{ .path = "etc/config", .data = "writer probe configuration\n" },
        .{ .path = "large.bin", .data = large },
        .{ .path = "random.bin", .data = &random },
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

fn parseMode(name: []const u8) ?vort.SquashfsEncodeMode {
    if (std.mem.eql(u8, name, "stored")) return .stored;
    if (std.mem.eql(u8, name, "gzip")) return .gzip;
    if (std.mem.eql(u8, name, "lzma")) return .lzma;
    if (std.mem.eql(u8, name, "lzo")) return .lzo;
    if (std.mem.eql(u8, name, "xz")) return .xz;
    if (std.mem.eql(u8, name, "lz4")) return .lz4;
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
