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
        "wim_version=0x{x} layout={s} compression={s} chunk_size={d} images={d} part={d}/{d}\n",
        .{
            archive.header.version,
            if (archive.header.pipable) "pipable" else "standard",
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

pub fn extractEncryptedRawData(
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
    const raw = try archive.extractEncryptedRawByPathAllocLimited(
        init.gpa,
        image_index,
        entry_path,
        limit,
        path_limits,
    );
    defer init.gpa.free(raw);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = raw });
    try stdout.print("image={d} entry={s} efsrpc_raw_bytes={d} path={s}\n", .{
        image_index,
        entry_path,
        raw.len,
        output_path,
    });
}

pub fn extractPipablePathIncremental(
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
    const limit = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    const input_step = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        4096;
    const output_step = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        32 * 1024;
    const stream: vort.WimStreamSelector = if (args.next()) |text|
        if (std.mem.eql(u8, text, "default"))
            .default
        else if (std.mem.eql(u8, text, "reparse"))
            .reparse
        else if (std.mem.eql(u8, text, "encrypted-raw"))
            .encrypted_raw
        else if (std.mem.startsWith(u8, text, "stream:"))
            .{ .named = text["stream:".len..] }
        else
            return error.InvalidBlockPlan
    else
        .default;
    if (input_step == 0 or output_step == 0 or output_step > max_file_size)
        return error.InvalidBlockPlan;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const scratch = try init.gpa.alloc(u8, output_step);
    defer init.gpa.free(scratch);
    var decoded: std.ArrayList(u8) = .empty;
    defer decoded.deinit(init.gpa);
    var extractor = vort.WimPipableStreamPathExtractor.init(init.gpa, .{
        .image_index = image_index,
        .path = entry_path,
        .stream = stream,
        .max_output_len = limit,
        .limits = .{
            .max_metadata_bytes = max_metadata_bytes,
            .max_directory_entries = max_directory_entries,
            .max_path_depth = max_path_depth,
        },
    });
    defer extractor.deinit();
    var input_offset: usize = 0;
    while (true) {
        const input_end = @min(input.len, input_offset + input_step);
        const stepped = try extractor.step(input[input_offset..input_end], scratch);
        input_offset += stepped.progress.input_read;
        try decoded.appendSlice(init.gpa, scratch[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        if (stepped.status == .need_input and input_offset == input.len) {
            try extractor.finish();
            return error.SizeMismatch;
        }
        if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0)
            return error.InvalidBlockPlan;
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded.items,
    });
    try stdout.print(
        "image={d} entry={s} decoded_bytes={d} input_read={d} input_step={d} output_step={d} path={s}\n",
        .{
            image_index,
            entry_path,
            decoded.items.len,
            input_offset,
            input_step,
            output_step,
            output_path,
        },
    );
}

pub fn inspectEncryptedEsd(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const max_xml = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        16 * 1024 * 1024;
    const max_ranges = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        1024 * 1024;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseWim(input);
    var info = try archive.readEncryptedEsdInfoAlloc(init.gpa, .{
        .max_xml_bytes = max_xml,
        .max_ranges = max_ranges,
    });
    defer info.deinit();
    try stdout.print("wrapped_key_bytes={d} ranges={d}\n", .{
        info.wrapped_key.len,
        info.ranges.len,
    });
    for (info.ranges, 0..) |range, index|
        try stdout.print("range={d}\toffset={d}\tbytes={d}\n", .{
            index,
            range.offset,
            range.length,
        });
}

pub fn decryptEncryptedEsd(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const key_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const private_key = try readFile(init, key_path);
    defer {
        std.crypto.secureZero(u8, private_key);
        init.gpa.free(private_key);
    }
    const archive = try vort.parseWim(input);
    const decrypted = try archive.decryptEncryptedEsdAllocLimited(
        init.gpa,
        private_key,
        max_output,
        .{},
    );
    defer init.gpa.free(decrypted);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decrypted,
    });
    try stdout.print("encrypted_bytes={d} decrypted_bytes={d} path={s}\n", .{
        input.len,
        decrypted.len,
        output_path,
    });
}

pub fn decryptEncryptedEsdWithKey(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const key_hex = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    if (key_hex.len != 64) return error.InvalidCorpusHex;
    var key: [32]u8 = undefined;
    defer std.crypto.secureZero(u8, &key);
    _ = try std.fmt.hexToBytes(&key, key_hex);
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseWim(input);
    const decrypted = try archive.decryptEncryptedEsdWithAesKeyAllocLimited(
        init.gpa,
        &key,
        max_output,
        .{},
    );
    defer init.gpa.free(decrypted);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decrypted,
    });
    try stdout.print("encrypted_bytes={d} decrypted_bytes={d} path={s}\n", .{
        input.len,
        decrypted.len,
        output_path,
    });
}

pub fn listSetImage(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const image_index = try std.fmt.parseInt(
        u32,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    var loaded = try loadSet(init, args);
    defer loaded.deinit();
    const set = try vort.WimArchiveSet.init(loaded.archives);
    var image = try set.readImageMetadataAlloc(init.gpa, image_index, path_limits);
    defer image.deinit();
    try stdout.print("image={d} parts={d} security_descriptors={d}\n", .{
        image_index,
        loaded.archives.len,
        image.security.descriptor_count,
    });
    try listImageDirectory(init, image, image.root, "", 0, stdout);
}

pub fn extractSetPath(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const image_index = try std.fmt.parseInt(
        u32,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    const entry_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    var loaded = try loadSet(init, args);
    defer loaded.deinit();
    const set = try vort.WimArchiveSet.init(loaded.archives);
    const decoded = try set.extractByPathAllocLimited(
        init.gpa,
        image_index,
        entry_path,
        limit,
        path_limits,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("image={d} parts={d} entry={s} decoded_bytes={d} path={s}\n", .{
        image_index,
        loaded.archives.len,
        entry_path,
        decoded.len,
        output_path,
    });
}

const LoadedSet = struct {
    allocator: std.mem.Allocator,
    buffers: [][]u8,
    archives: []vort.WimArchive,

    fn deinit(self: *LoadedSet) void {
        for (self.buffers) |bytes| self.allocator.free(bytes);
        self.allocator.free(self.buffers);
        self.allocator.free(self.archives);
        self.* = undefined;
    }
};

fn loadSet(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
) !LoadedSet {
    var buffers: std.ArrayList([]u8) = .empty;
    defer buffers.deinit(init.gpa);
    var archives: std.ArrayList(vort.WimArchive) = .empty;
    defer archives.deinit(init.gpa);
    errdefer for (buffers.items) |bytes| init.gpa.free(bytes);
    while (args.next()) |path| {
        const bytes = try readFile(init, path);
        errdefer init.gpa.free(bytes);
        const archive = try vort.parseWim(bytes);
        try buffers.ensureUnusedCapacity(init.gpa, 1);
        try archives.ensureUnusedCapacity(init.gpa, 1);
        buffers.appendAssumeCapacity(bytes);
        archives.appendAssumeCapacity(archive);
    }
    if (archives.items.len == 0) return error.MissingCorpusPath;
    const owned_buffers = try buffers.toOwnedSlice(init.gpa);
    errdefer {
        for (owned_buffers) |bytes| init.gpa.free(bytes);
        init.gpa.free(owned_buffers);
    }
    return .{
        .allocator = init.gpa,
        .buffers = owned_buffers,
        .archives = try archives.toOwnedSlice(init.gpa),
    };
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
