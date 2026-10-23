const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingOutputPath;
    const mode = args.next() orelse "stored";
    const metabox = std.mem.endsWith(u8, mode, "-metabox");
    const codec = if (metabox) mode[0 .. mode.len - "-metabox".len] else mode;
    const compression: vort.ErofsWriterCompression = if (std.mem.eql(u8, codec, "stored")) .stored else if (std.mem.eql(u8, codec, "lz4")) .lz4 else if (std.mem.eql(u8, codec, "lzma")) .lzma else if (std.mem.eql(u8, codec, "deflate")) .deflate else if (std.mem.eql(u8, codec, "zstd")) .zstandard else return error.InvalidBlockPlan;
    const entries = try init.gpa.alloc(vort.ErofsEntry, 203);
    defer init.gpa.free(entries);
    const names = try init.gpa.alloc([96]u8, 200);
    defer init.gpa.free(names);
    const attrs = [_]vort.ErofsXattr{.{ .name = "user.vort.zone", .value = "directory-zone-attribute" }};
    for (entries[0..200], 0..) |*entry, index| entry.* = .{ .path = try std.fmt.bufPrint(&names[index], "dir/item-{d:03}-with-long-metadata-zone-name", .{index}) };
    entries[200] = .{ .path = "dir", .kind = .directory, .xattrs = &attrs };
    entries[201] = .{ .path = "file", .data = "metadata-zone payload 0123456789\n" ** 500, .xattrs = &attrs };
    entries[202] = .{ .path = "empty", .kind = .directory };
    const file = try std.Io.Dir.cwd().createFile(init.io, path, .{});
    defer file.close(init.io);
    var sink = vort.FileByteSink.init(init.io, file);
    var encoder: vort.ErofsEncoder = undefined;
    try encoder.init(init.gpa, entries, .{
        .compression = compression,
        .directory_metadata_zone = true,
        .metabox = metabox,
        .root_xattrs = &attrs,
        .xattr_prefixes = &.{"user.vort."},
        .shared_xattrs = true,
        .inode_version = .extended,
        .compression_extent_size = if (compression == .stored) 4096 else 32768,
        .max_pcluster_size = if (compression == .stored) null else 8192,
    }, .{});
    defer encoder.deinit();
    var buffer: [17]u8 = undefined;
    while (true) {
        const progress = try encoder.read(&buffer);
        if (progress.output_written != 0) try sink.sink().writeExact(progress.offset, buffer[0..progress.output_written]);
        if (progress.status == .done) break;
    }
    try sink.sink().finish(encoder.result().?.image_size);
}
