const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const mode_name = args.next() orelse "lz4";
    const address48_suffix = "-48bit";
    const fragment_suffix = "-fragments";
    const inline_suffix = "-ztailpacking";
    const metabox_suffix = "-metabox";
    const directory_suffix = "-dirs";
    const extended_suffix = "-extended";
    const metabox = std.mem.endsWith(u8, mode_name, metabox_suffix);
    const without_metabox = if (metabox)
        mode_name[0 .. mode_name.len - metabox_suffix.len]
    else
        mode_name;
    const extended = std.mem.endsWith(u8, without_metabox, extended_suffix);
    const without_extended = if (extended)
        without_metabox[0 .. without_metabox.len - extended_suffix.len]
    else
        without_metabox;
    const force_48bit = std.mem.endsWith(u8, without_extended, address48_suffix);
    const layout_mode = if (force_48bit)
        without_extended[0 .. without_extended.len - address48_suffix.len]
    else
        without_extended;
    const chunk_local = std.mem.eql(u8, layout_mode, "chunk-local");
    const chunk_external = std.mem.eql(u8, layout_mode, "chunk-external");
    const fragments = std.mem.endsWith(u8, layout_mode, fragment_suffix);
    const compressed_inline = std.mem.endsWith(u8, layout_mode, inline_suffix);
    const compress_directories = std.mem.endsWith(u8, layout_mode, directory_suffix);
    const compression_name = if (chunk_local or chunk_external)
        "stored"
    else if (fragments)
        layout_mode[0 .. layout_mode.len - fragment_suffix.len]
    else if (compressed_inline)
        layout_mode[0 .. layout_mode.len - inline_suffix.len]
    else if (compress_directories)
        layout_mode[0 .. layout_mode.len - directory_suffix.len]
    else
        layout_mode;
    const compression = parseCompression(compression_name) orelse return error.InvalidBlockPlan;

    var random: [8193]u8 = undefined;
    fillPseudoRandom(&random);
    const large = "EROFS writer probe multi-block payload 0123456789\n" ** 4096;
    const config_xattrs = [_]vort.ErofsXattr{
        .{ .name = "user.vort.config", .value = "config-xattr" },
        .{ .name = "user.vort.shared", .value = "shared-xattr" },
    };
    const small_xattrs = [_]vort.ErofsXattr{
        .{ .name = "user.vort.small", .value = "small-xattr" },
        .{ .name = "user.vort.shared", .value = "shared-xattr" },
    };
    const directory_xattrs = [_]vort.ErofsXattr{
        .{ .name = "user.vort.directory", .value = "directory-xattr" },
        .{ .name = "user.vort.shared", .value = "shared-xattr" },
    };
    const root_xattrs = [_]vort.ErofsXattr{
        .{ .name = "user.vort.root", .value = "root-xattr" },
        .{ .name = "user.vort.shared", .value = "shared-xattr" },
    };
    const entries = [_]vort.ErofsEntry{
        .{ .path = "etc/config", .data = "writer probe configuration\n", .xattrs = &config_xattrs },
        .{ .path = "large.bin", .data = large },
        .{ .path = "random.bin", .data = &random },
        .{ .path = "small", .data = "inline payload", .xattrs = &small_xattrs },
        .{ .path = "link", .kind = .symlink, .target = "etc/config" },
        .{ .path = "empty", .kind = .directory, .xattrs = &directory_xattrs },
    };
    const options = vort.ErofsWriterOptions{
        .compression = compression,
        .volume_name = "vort-writer",
        .root_xattrs = &root_xattrs,
        .xattr_prefixes = &.{"user.vort."},
        .tail_packing = if (fragments)
            .fragments
        else if (compressed_inline)
            .compressed_inline
        else
            .none,
        .chunk_size = if (chunk_local or chunk_external) 4096 else null,
        .force_48bit = force_48bit,
        .metabox = metabox,
        .shared_xattrs = true,
        .compress_directories = compress_directories,
        .inode_version = if (extended) .extended else .compact,
    };
    if (chunk_external) {
        const device_path = args.next() orelse return error.MissingOutputPath;
        var encoded = try vort.encodeErofsExternalChunksAlloc(init.gpa, &entries, options);
        defer encoded.deinit(init.gpa);
        try std.Io.Dir.cwd().writeFile(init.io, .{
            .sub_path = output_path,
            .data = encoded.image,
        });
        try std.Io.Dir.cwd().writeFile(init.io, .{
            .sub_path = device_path,
            .data = encoded.device,
        });
    } else {
        const encoded = try vort.encodeErofsAlloc(init.gpa, &entries, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    }
}

fn parseCompression(name: []const u8) ?vort.ErofsWriterCompression {
    if (std.mem.eql(u8, name, "stored")) return .stored;
    if (std.mem.eql(u8, name, "lz4")) return .lz4;
    if (std.mem.eql(u8, name, "lzma")) return .lzma;
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
