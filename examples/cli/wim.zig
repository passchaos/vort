const std = @import("std");
const vort = @import("vort");

const max_file_size = 1024 * 1024 * 1024;
const max_lookup_entries = 4 * 1024 * 1024;
const max_lookup_bytes = 256 * 1024 * 1024;
const max_metadata_bytes = 256 * 1024 * 1024;
const max_directory_entries = 1024 * 1024;
const max_path_depth = 256;

const path_limits = vort.WimPathLimits{
    .max_metadata_bytes = max_metadata_bytes,
    .max_lookup_entries = max_lookup_entries,
    .max_lookup_bytes = max_lookup_bytes,
    .max_directory_entries = max_directory_entries,
    .max_path_depth = max_path_depth,
};

pub fn list(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseWim(input);
    try stdout.print(
        "wim_version=0x{x} compression={s} chunk_size={d} images={d} part={d}/{d}\n",
        .{
            archive.header.version,
            @tagName(archive.header.compression),
            archive.header.chunk_size,
            archive.header.image_count,
            archive.header.part_number,
            archive.header.total_parts,
        },
    );
    var lookup = try archive.readLookupTableAlloc(
        init.gpa,
        max_lookup_entries,
        max_lookup_bytes,
    );
    defer lookup.deinit();
    for (lookup.entries) |entry| {
        const hash = std.fmt.bytesToHex(entry.sha1, .lower);
        try stdout.print(
            "{s}\tpart={d}\trefs={d}\tstored={d}\tsize={d}\tflags=0x{x}\n",
            .{
                &hash,
                entry.part_number,
                entry.reference_count,
                entry.resource.size_in_wim,
                entry.resource.uncompressed_size,
                entry.resource.flags,
            },
        );
    }
}

pub fn extractResource(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const hash_text = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    if (hash_text.len != 40) return error.InvalidCorpusHex;
    var hash: [20]u8 = undefined;
    _ = try std.fmt.hexToBytes(&hash, hash_text);
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseWim(input);
    const decoded = try archive.extractBySha1AllocLimited(
        init.gpa,
        &hash,
        limit,
        max_lookup_entries,
        max_lookup_bytes,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("sha1={s} decoded_bytes={d} path={s}\n", .{
        hash_text,
        decoded.len,
        output_path,
    });
}

pub fn extractXml(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        64 * 1024 * 1024;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseWim(input);
    const xml = try archive.readXmlAllocLimited(init.gpa, limit);
    defer init.gpa.free(xml);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = xml });
    try stdout.print("xml_bytes={d} path={s}\n", .{ xml.len, output_path });
}

pub fn listImage(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const image_index = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 10)
    else
        1;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseWim(input);
    var image = try archive.readImageMetadataAlloc(init.gpa, image_index, path_limits);
    defer image.deinit();
    try stdout.print("image={d} security_descriptors={d}\n", .{
        image_index,
        image.security.descriptor_count,
    });
    try listImageDirectory(init, image, image.root, "", 0, stdout);
}

fn listImageDirectory(
    init: std.process.Init,
    image: vort.WimImageMetadata,
    parent: vort.WimDentry,
    prefix: []const u8,
    depth: usize,
    stdout: *std.Io.Writer,
) !void {
    if (depth >= max_path_depth) return error.OutputLimitExceeded;
    var directory = try image.readDirectoryAlloc(
        init.gpa,
        parent,
        max_directory_entries,
    );
    defer directory.deinit();
    for (directory.entries) |entry| {
        const name = try entry.nameUtf8Alloc(init.gpa);
        defer init.gpa.free(name);
        const path = if (prefix.len == 0)
            try std.fmt.allocPrint(init.gpa, "/{s}", .{name})
        else
            try std.fmt.allocPrint(init.gpa, "{s}/{s}", .{ prefix, name });
        defer init.gpa.free(path);
        if (entry.isDirectory()) {
            try stdout.print("directory\t{s}\tattributes=0x{x}\n", .{
                path,
                entry.attributes,
            });
            try listImageDirectory(init, image, entry, path, depth + 1, stdout);
        } else if (entry.isEncrypted()) {
            try stdout.print("encrypted\t{s}\tattributes=0x{x}\n", .{
                path,
                entry.attributes,
            });
        } else if (entry.isReparsePoint()) {
            const hash = try entry.reparseDataSha1();
            const hash_text = std.fmt.bytesToHex(hash, .lower);
            try stdout.print("reparse\t{s}\ttag=0x{x}\tsha1={s}\tattributes=0x{x}\n", .{
                path,
                entry.reparseTag().?,
                &hash_text,
                entry.attributes,
            });
        } else {
            const hash = (try entry.defaultDataSha1()) orelse @as([20]u8, @splat(0));
            const hash_text = std.fmt.bytesToHex(hash, .lower);
            try stdout.print("file\t{s}\tsha1={s}\tattributes=0x{x}\n", .{
                path,
                &hash_text,
                entry.attributes,
            });
        }
        var streams = entry.extraStreams();
        while (try streams.next()) |stream| {
            if (!stream.isNamed()) continue;
            const stream_name = try stream.nameUtf8Alloc(init.gpa);
            defer init.gpa.free(stream_name);
            const hash_text = std.fmt.bytesToHex(stream.hash, .lower);
            try stdout.print("stream\t{s}:{s}\tsha1={s}\n", .{
                path,
                stream_name,
                &hash_text,
            });
        }
    }
}

pub fn extractPath(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const image_index_text = args.next() orelse return error.MissingCorpusPath;
    const image_index = try std.fmt.parseInt(u32, image_index_text, 10);
    const entry_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseWim(input);
    const decoded = try archive.extractByPathAllocLimited(
        init.gpa,
        image_index,
        entry_path,
        limit,
        path_limits,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("image={d} entry={s} decoded_bytes={d} path={s}\n", .{
        image_index,
        entry_path,
        decoded.len,
        output_path,
    });
}

pub fn extractNamedStream(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const image_index = try std.fmt.parseInt(
        u32,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    const entry_path = args.next() orelse return error.MissingCorpusPath;
    const stream_name = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseWim(input);
    const decoded = try archive.extractNamedStreamByPathAllocLimited(
        init.gpa,
        image_index,
        entry_path,
        stream_name,
        limit,
        path_limits,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("image={d} entry={s} stream={s} decoded_bytes={d} path={s}\n", .{
        image_index,
        entry_path,
        stream_name,
        decoded.len,
        output_path,
    });
}

pub fn extractReparseData(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const image_index = try std.fmt.parseInt(
        u32,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    const entry_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseWim(input);
    const decoded = try archive.extractReparseDataByPathAllocLimited(
        init.gpa,
        image_index,
        entry_path,
        limit,
        path_limits,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("image={d} entry={s} reparse_bytes={d} path={s}\n", .{
        image_index,
        entry_path,
        decoded.len,
        output_path,
    });
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
