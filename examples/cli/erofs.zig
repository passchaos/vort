const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;
const max_directory_size = 64 * 1024 * 1024;
const max_xattr_count = 4096;
const max_xattr_bytes = 16 * 1024 * 1024;
const max_metabox_size = 64 * 1024 * 1024;
const max_depth = 256;

pub fn create(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const compression: vort.ErofsWriterCompression = if (args.next()) |name|
        parseCompression(name) orelse return error.InvalidBlockPlan
    else
        .lz4;
    const extent_size = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else 4096;
    const max_pcluster_size = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else null;
    const working_limit = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else 64 * 1024 * 1024;
    const input_file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    defer input_file.close(init.io);
    var input_adapter = try vort.FileByteSource.init(init.io, input_file);
    const input = input_adapter.source();
    if (input.len > max_file_size) return error.OutputLimitExceeded;
    var output_file = try std.Io.Dir.cwd().createFileAtomic(init.io, output_path, .{ .replace = true });
    defer output_file.deinit(init.io);
    var output_adapter = vort.FileByteSink.init(init.io, output_file.file);
    const result = try vort.encodeErofsToSink(init.gpa, &.{.{
        .path = entry_name,
        .source = input,
    }}, .{ .compression = compression, .compression_extent_size = extent_size, .max_pcluster_size = max_pcluster_size }, output_adapter.sink(), .{ .max_working_memory = working_limit });
    try output_file.replace(init.io);
    try stdout.print(
        "entry={s} input_bytes={d} erofs_bytes={d} compression={s} extent_size={d} max_pcluster_size={?d} peak_working_bytes={d} path={s}\n",
        .{ entry_name, input.len, result.image_size, @tagName(compression), extent_size, max_pcluster_size, result.peak_working_bytes, output_path },
    );
}

fn parseCompression(name: []const u8) ?vort.ErofsWriterCompression {
    if (std.mem.eql(u8, name, "stored")) return .stored;
    if (std.mem.eql(u8, name, "lz4")) return .lz4;
    if (std.mem.eql(u8, name, "lzma")) return .lzma;
    if (std.mem.eql(u8, name, "deflate")) return .deflate;
    if (std.mem.eql(u8, name, "zstd")) return .zstandard;
    return null;
}

pub fn list(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const base_archive = try vort.parseErofs(input);
    var loaded = if (base_archive.superblock.metabox_nid != 0)
        try base_archive.loadMetaboxAllocLimited(
            init.gpa,
            max_metabox_size,
            vort.erofsDefaultPackedExtentLimit,
        )
    else
        null;
    defer if (loaded) |*owner| owner.deinit();
    const archive = if (loaded) |owner| owner.archive else base_archive;
    try stdout.print(
        "erofs_inodes={d} blocks={d} block_size={d} root_nid={d} compression_mask={d}\n",
        .{
            archive.superblock.inode_count,
            archive.superblock.block_count,
            archive.superblock.block_size,
            archive.superblock.root_nid,
            archive.superblock.available_compression_algorithms,
        },
    );
    const root = try archive.rootInode();
    try listDirectory(init, archive, root, "", 0, stdout);
}

fn listDirectory(
    init: std.process.Init,
    archive: vort.ErofsArchive,
    inode: vort.ErofsInode,
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
        const child = try archive.inode(entry.nid);
        try stdout.print("{s}\t{s}\t{d}\t{s}\n", .{
            @tagName(try child.fileType()),
            path,
            child.file_size,
            @tagName(child.layout),
        });
        if (try child.fileType() == .directory)
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
    var devices: std.ArrayList([]const u8) = .empty;
    defer {
        for (devices.items) |device| init.gpa.free(device);
        devices.deinit(init.gpa);
    }
    while (args.next()) |device_path| {
        const device = try readFile(init, device_path);
        devices.append(init.gpa, device) catch |err| {
            init.gpa.free(device);
            return err;
        };
    }
    const base_archive = try vort.parseErofsWithDevices(input, devices.items);
    var loaded = if (base_archive.superblock.metabox_nid != 0)
        try base_archive.loadMetaboxAllocLimited(
            init.gpa,
            max_metabox_size,
            vort.erofsDefaultPackedExtentLimit,
        )
    else
        null;
    defer if (loaded) |*owner| owner.deinit();
    const archive = if (loaded) |owner| owner.archive else base_archive;
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

pub fn listXattrs(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const entry_path = args.next() orelse return error.MissingCorpusPath;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const base_archive = try vort.parseErofs(input);
    var loaded = if (base_archive.superblock.metabox_nid != 0)
        try base_archive.loadMetaboxAllocLimited(
            init.gpa,
            max_metabox_size,
            vort.erofsDefaultPackedExtentLimit,
        )
    else
        null;
    defer if (loaded) |*owner| owner.deinit();
    const archive = if (loaded) |owner| owner.archive else base_archive;
    const inode = try archive.lookup(
        init.gpa,
        entry_path,
        std.math.maxInt(usize),
        max_directory_size,
    );
    var attributes = try archive.readXattrsAllocLimited(
        init.gpa,
        inode,
        max_xattr_count,
        max_xattr_bytes,
    );
    defer attributes.deinit();
    try stdout.print("xattrs={d} entry={s}\n", .{ attributes.entries.len, entry_path });
    for (attributes.entries) |attribute|
        try stdout.print("xattr\t{s}\t{x}\n", .{ attribute.name, attribute.value });
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
