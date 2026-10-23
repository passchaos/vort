const std = @import("std");
const vort = @import("vort");
const file_devices = @import("erofs/file_devices.zig");

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
    var compression: vort.ErofsWriterCompression = .lz4;
    var index_format: vort.ErofsWriterIndexFormat = .full;
    var extent_size: usize = 4096;
    var max_pcluster_size: ?usize = null;
    var working_limit: usize = 64 * 1024 * 1024;
    var output_chunk_size: usize = 64 * 1024;
    var positional: usize = 0;
    while (args.next()) |argument| {
        const chunk_option = "--output-chunk-size=";
        const working_option = "--working-memory-limit=";
        const index_option = "--compressed-index-format=";
        if (std.mem.startsWith(u8, argument, index_option)) {
            index_format = parseIndexFormat(argument[index_option.len..]) orelse return error.InvalidBlockPlan;
            continue;
        }
        if (std.mem.startsWith(u8, argument, chunk_option)) {
            output_chunk_size = try std.fmt.parseInt(usize, argument[chunk_option.len..], 10);
            if (output_chunk_size == 0) return error.OutputTooSmall;
            if (output_chunk_size > 1024 * 1024) return error.OutputLimitExceeded;
            continue;
        }
        if (std.mem.startsWith(u8, argument, working_option)) {
            working_limit = try std.fmt.parseInt(usize, argument[working_option.len..], 10);
            continue;
        }
        switch (positional) {
            0 => compression = parseCompression(argument) orelse return error.InvalidBlockPlan,
            1 => extent_size = try std.fmt.parseInt(usize, argument, 10),
            2 => max_pcluster_size = try std.fmt.parseInt(usize, argument, 10),
            3 => working_limit = try std.fmt.parseInt(usize, argument, 10),
            else => return error.InvalidBlockPlan,
        }
        positional += 1;
    }
    const input_file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    defer input_file.close(init.io);
    var input_adapter = try vort.FileByteSource.init(init.io, input_file);
    const input = input_adapter.source();
    var output_file = try std.Io.Dir.cwd().createFileAtomic(init.io, output_path, .{ .replace = true });
    defer output_file.deinit(init.io);
    var output_adapter = vort.FileByteSink.init(init.io, output_file.file);
    var encoder: vort.ErofsEncoder = undefined;
    try encoder.init(init.gpa, &.{.{
        .path = entry_name,
        .source = input,
    }}, .{ .compression = compression, .compressed_index_format = index_format, .compression_extent_size = extent_size, .max_pcluster_size = max_pcluster_size, .inode_version = .automatic }, .{ .max_working_memory = working_limit });
    defer encoder.deinit();
    const buffer = try init.gpa.alloc(u8, output_chunk_size);
    defer init.gpa.free(buffer);
    const sink = output_adapter.sink();
    while (true) {
        const progress = try encoder.read(buffer);
        if (progress.output_written != 0) {
            if (progress.target != .image) return error.InvalidErofs;
            try sink.writeExact(progress.offset, buffer[0..progress.output_written]);
        }
        if (progress.status == .done) break;
    }
    const result = encoder.result().?;
    try sink.finish(result.image_size);
    try output_file.replace(init.io);
    try stdout.print(
        "entry={s} input_bytes={d} erofs_bytes={d} compression={s} extent_size={d} max_pcluster_size={?d} peak_working_bytes={d} path={s}\n",
        .{ entry_name, input.len, result.image_size, @tagName(compression), extent_size, max_pcluster_size, result.peak_working_bytes, output_path },
    );
}

fn parseIndexFormat(name: []const u8) ?vort.ErofsWriterIndexFormat {
    if (std.mem.eql(u8, name, "full")) return .full;
    if (std.mem.eql(u8, name, "compact-4byte")) return .compact_4byte;
    if (std.mem.eql(u8, name, "compact")) return .compact;
    return null;
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
    var working_limit: usize = 64 * 1024 * 1024;
    var directory_limit: usize = max_directory_size;
    var devices = file_devices.Set.init(init.gpa, init.io);
    defer devices.deinit();
    while (args.next()) |argument| {
        const work_option = "--working-memory-limit=";
        const dir_option = "--max-directory-bytes=";
        if (std.mem.startsWith(u8, argument, work_option)) working_limit = try std.fmt.parseInt(usize, argument[work_option.len..], 10) else if (std.mem.startsWith(u8, argument, dir_option)) directory_limit = try std.fmt.parseInt(usize, argument[dir_option.len..], 10) else try devices.add(argument);
    }
    const input_file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    defer input_file.close(init.io);
    var input_adapter = try vort.FileByteSource.init(init.io, input_file);
    var archive = try vort.ErofsSourceArchive.initWithDevices(init.gpa, input_adapter.source(), try devices.view(), .{ .max_metabox_size = max_metabox_size, .max_working_memory = working_limit });
    defer archive.deinit();
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
    try listDirectory(init, &archive, root, "", 0, directory_limit, stdout);
}

fn listDirectory(
    init: std.process.Init,
    archive: *vort.ErofsSourceArchive,
    inode: vort.ErofsInode,
    prefix: []const u8,
    depth: usize,
    directory_limit: usize,
    stdout: *std.Io.Writer,
) !void {
    if (depth >= max_depth) return error.OutputLimitExceeded;
    var directory = try archive.initDirectoryIterator(inode, directory_limit);
    defer directory.deinit();
    while (try directory.next()) |entry| {
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
            try listDirectory(init, archive, child, path, depth + 1, directory_limit, stdout);
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
    const input_file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    defer input_file.close(init.io);
    var input_adapter = try vort.FileByteSource.init(init.io, input_file);
    var devices = file_devices.Set.init(init.gpa, init.io);
    defer devices.deinit();
    var working_limit: usize = 64 * 1024 * 1024;
    var output_chunk_size: usize = 64 * 1024;
    const working_option = "--working-memory-limit=";
    const chunk_option = "--output-chunk-size=";
    while (args.next()) |argument| {
        if (std.mem.startsWith(u8, argument, working_option)) {
            working_limit = try std.fmt.parseInt(usize, argument[working_option.len..], 10);
            continue;
        }
        if (std.mem.startsWith(u8, argument, chunk_option)) {
            output_chunk_size = try std.fmt.parseInt(usize, argument[chunk_option.len..], 10);
            if (output_chunk_size == 0) return error.OutputTooSmall;
            if (output_chunk_size > 1024 * 1024) return error.OutputLimitExceeded;
            continue;
        }
        try devices.add(argument);
    }
    var archive = try vort.ErofsSourceArchive.initWithDevices(init.gpa, input_adapter.source(), try devices.view(), .{
        .max_working_memory = working_limit,
        .max_metabox_size = max_metabox_size,
    });
    defer archive.deinit();
    var output_file = try std.Io.Dir.cwd().createFileAtomic(init.io, output_path, .{ .replace = true });
    defer output_file.deinit(init.io);
    var output_adapter = vort.FileByteSink.init(init.io, output_file.file);
    var extractor = try archive.initPathExtractor(entry_path, .{ .max_output_len = limit }, max_directory_size);
    defer extractor.deinit();
    const buffer = try init.gpa.alloc(u8, output_chunk_size);
    defer init.gpa.free(buffer);
    const sink = output_adapter.sink();
    while (true) {
        const progress = try extractor.read(buffer);
        if (progress.output_written != 0) try sink.writeExact(progress.position - progress.output_written, buffer[0..progress.output_written]);
        if (progress.status == .done) break;
    }
    try sink.finish(extractor.position());
    try output_file.replace(init.io);
    try stdout.print("entry={s} decoded_bytes={d} peak_working_bytes={d} path={s}\n", .{
        entry_path,
        extractor.position(),
        archive.peakWorkingBytes(),
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
    var devices = file_devices.Set.init(init.gpa, init.io);
    defer devices.deinit();
    var working_limit: usize = 64 * 1024 * 1024;
    while (args.next()) |argument| {
        const option = "--working-memory-limit=";
        if (std.mem.startsWith(u8, argument, option)) working_limit = try std.fmt.parseInt(usize, argument[option.len..], 10) else try devices.add(argument);
    }
    const input_file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    defer input_file.close(init.io);
    var input_adapter = try vort.FileByteSource.init(init.io, input_file);
    var archive = try vort.ErofsSourceArchive.initWithDevices(init.gpa, input_adapter.source(), try devices.view(), .{ .max_metabox_size = max_metabox_size, .max_working_memory = working_limit });
    defer archive.deinit();
    const inode = try archive.lookup(
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
