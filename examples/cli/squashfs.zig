const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;
const max_directory_size = 64 * 1024 * 1024;
const max_depth = 256;

pub fn list(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseSquashfs(input);
    try stdout.print(
        "squashfs_inodes={d} fragments={d} block_size={d} bytes_used={d} compression={s}\n",
        .{
            archive.superblock.inode_count,
            archive.superblock.fragment_count,
            archive.superblock.block_size,
            archive.superblock.bytes_used,
            @tagName(archive.superblock.compression),
        },
    );
    var root = try archive.rootInodeAlloc(init.gpa, max_file_size);
    defer root.deinit();
    try listDirectory(init, archive, root, "", 0, stdout);
}

fn listDirectory(
    init: std.process.Init,
    archive: vort.SquashfsArchive,
    inode: vort.SquashfsInode,
    prefix: []const u8,
    depth: usize,
    stdout: *std.Io.Writer,
) !void {
    if (depth >= max_depth) return error.OutputLimitExceeded;
    var directory = try archive.readDirectoryAlloc(
        init.gpa,
        inode,
        max_directory_size,
    );
    defer directory.deinit();
    for (directory.entries) |entry| {
        const path = if (prefix.len == 0)
            try init.gpa.dupe(u8, entry.name)
        else
            try std.fmt.allocPrint(init.gpa, "{s}/{s}", .{ prefix, entry.name });
        defer init.gpa.free(path);
        var child = try archive.readInodeAlloc(init.gpa, entry.inode_reference, max_file_size);
        defer child.deinit();
        try stdout.print("{s}\t{s}\t{d}\n", .{
            @tagName(child.kind),
            path,
            child.file_size,
        });
        if (child.kind == .directory or child.kind == .long_directory)
            try listDirectory(init, archive, child, path, depth + 1, stdout);
    }
}

pub fn extract(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const entry_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseSquashfs(input);
    const decoded = try archive.extractByPathAllocLimited(
        init.gpa,
        entry_path,
        limit,
        max_directory_size,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("entry={s} decoded_bytes={d} path={s}\n", .{
        entry_path,
        decoded.len,
        output_path,
    });
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
