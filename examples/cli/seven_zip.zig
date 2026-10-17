const std = @import("std");
const vort = @import("vort");
const filters_cli = @import("filters.zig");

const max_archive_size = 512 * 1024 * 1024;

const FileSource = struct {
    file: std.Io.File,
    io: std.Io,
    read_calls: usize = 0,
    bytes_read: usize = 0,

    fn readAt(
        context: *anyopaque,
        offset: u64,
        output: []u8,
    ) error{SourceReadFailed}!usize {
        const self: *FileSource = @ptrCast(@alignCast(context));
        const amount = self.file.readPositional(self.io, &.{output}, offset) catch
            return error.SourceReadFailed;
        self.read_calls = std.math.add(usize, self.read_calls, 1) catch
            return error.SourceReadFailed;
        self.bytes_read = std.math.add(usize, self.bytes_read, amount) catch
            return error.SourceReadFailed;
        return amount;
    }
};

const FileVolumeSource = struct {
    init: std.process.Init,
    files: []std.Io.File,
    lengths: []u64,
    read_calls: usize = 0,
    bytes_read: usize = 0,

    fn open(init: std.process.Init, args: *std.process.Args.Iterator) !FileVolumeSource {
        var files: std.ArrayList(std.Io.File) = .empty;
        errdefer {
            for (files.items) |file| file.close(init.io);
            files.deinit(init.gpa);
        }
        var lengths: std.ArrayList(u64) = .empty;
        errdefer lengths.deinit(init.gpa);
        while (args.next()) |path| {
            const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
            errdefer file.close(init.io);
            const stat = try file.stat(init.io);
            try lengths.append(init.gpa, stat.size);
            try files.append(init.gpa, file);
        }
        if (files.items.len < 2) return error.MissingCorpusPath;
        const owned_files = try files.toOwnedSlice(init.gpa);
        errdefer {
            for (owned_files) |file| file.close(init.io);
            init.gpa.free(owned_files);
        }
        const owned_lengths = try lengths.toOwnedSlice(init.gpa);
        return .{ .init = init, .files = owned_files, .lengths = owned_lengths };
    }

    fn deinit(self: *FileVolumeSource) void {
        for (self.files) |file| file.close(self.init.io);
        self.init.gpa.free(self.files);
        self.init.gpa.free(self.lengths);
        self.* = undefined;
    }

    fn readAt(
        raw_context: *anyopaque,
        part_index: usize,
        offset: u64,
        output: []u8,
    ) error{PartSourceReadFailed}!usize {
        const self: *FileVolumeSource = @ptrCast(@alignCast(raw_context));
        if (part_index >= self.files.len) return error.PartSourceReadFailed;
        const amount = self.files[part_index].readPositional(
            self.init.io,
            &.{output},
            offset,
        ) catch return error.PartSourceReadFailed;
        self.read_calls = std.math.add(usize, self.read_calls, 1) catch
            return error.PartSourceReadFailed;
        self.bytes_read = std.math.add(usize, self.bytes_read, amount) catch
            return error.PartSourceReadFailed;
        return amount;
    }
};

pub fn createFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const compression = try parseCompression(args.next());
    var filter_storage: [3]vort.SevenZipFilter = undefined;
    const filters = try filters_cli.parse(args.next(), &filter_storage);
    const solid = try parseSolid(args.next());
    const header_compression = try parseHeaderCompression(args.next());
    const bcj2 = try parseBcj2(args.next());
    const bcj2_start_ip = try parseStartIp(args.next());
    const external_names = try parseExternalNames(args.next());
    const external_metadata = try parseExternalMetadata(args.next());
    const creation_time = try parseOptionalU64(args.next());
    const access_time = try parseOptionalU64(args.next());
    const modification_time = try parseOptionalU64(args.next());
    const attributes = try parseOptionalU32(args.next());
    const encryption = try parseEncryption(
        args.next(),
        args.next(),
        args.next(),
        args.next(),
    );
    const encrypt_header = try parseHeaderEncryption(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const entries = [_]vort.SevenZipEncodeEntry{.{
        .name = entry_name,
        .data = input,
        .creation_time = creation_time,
        .access_time = access_time,
        .modification_time = modification_time,
        .attributes = attributes,
    }};
    const encoded = try vort.encodeSevenZipAlloc(init.gpa, &entries, .{
        .compression = compression,
        .solid = solid,
        .header_compression = header_compression,
        .external_names = external_names,
        .external_metadata = external_metadata,
        .encryption = encryption,
        .encrypt_header = encrypt_header,
        .bcj2 = bcj2,
        .bcj2_start_ip = bcj2_start_ip,
        .filters = filters,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("seven_zip_entries=1 compression={s} solid={} header={s} external_names={s} external_metadata={s} encrypted={} encrypted_header={} bcj2={} filters={d} input_bytes={d} archive_bytes={d} path={s}\n", .{
        @tagName(compression),
        solid,
        if (header_compression) |method| @tagName(method) else "plain",
        if (external_names) |method| @tagName(method) else "inline",
        if (external_metadata) |method| @tagName(method) else "inline",
        encryption != null,
        encrypt_header,
        bcj2,
        filters.len,
        input.len,
        encoded.len,
        output_path,
    });
}

fn parseSolid(text: ?[]const u8) !bool {
    const value = text orelse return false;
    if (std.mem.eql(u8, value, "solid") or std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "non-solid") or
        std.mem.eql(u8, value, "nonsolid") or
        std.mem.eql(u8, value, "false")) return false;
    return error.Invalid7zOptions;
}

fn parseHeaderCompression(text: ?[]const u8) !?vort.SevenZipCompression {
    const value = text orelse return null;
    if (std.mem.eql(u8, value, "plain") or std.mem.eql(u8, value, "none")) return null;
    return try parseCompression(value);
}

fn parseBcj2(text: ?[]const u8) !bool {
    const value = text orelse return false;
    if (std.mem.eql(u8, value, "bcj2") or std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "classic") or std.mem.eql(u8, value, "false")) return false;
    return error.Invalid7zOptions;
}

fn parseStartIp(text: ?[]const u8) !u32 {
    return if (text) |value| try std.fmt.parseInt(u32, value, 10) else 0;
}

fn parseExternalNames(text: ?[]const u8) !?vort.SevenZipCompression {
    const value = text orelse return null;
    if (std.mem.eql(u8, value, "external-names") or std.mem.eql(u8, value, "external"))
        return .copy;
    if (std.mem.eql(u8, value, "inline-names") or std.mem.eql(u8, value, "inline"))
        return null;
    const prefix = "external-";
    if (std.mem.startsWith(u8, value, prefix))
        return try parseCompression(value[prefix.len..]);
    return error.Invalid7zOptions;
}

fn parseExternalMetadata(text: ?[]const u8) !?vort.SevenZipCompression {
    const value = text orelse return null;
    if (std.mem.eql(u8, value, "external-metadata")) return .copy;
    if (std.mem.eql(u8, value, "inline-metadata")) return null;
    const prefix = "external-metadata-";
    if (std.mem.startsWith(u8, value, prefix))
        return try parseCompression(value[prefix.len..]);
    return error.Invalid7zOptions;
}

fn parseOptionalU64(text: ?[]const u8) !?u64 {
    const value = text orelse return null;
    if (std.mem.eql(u8, value, "-") or std.mem.eql(u8, value, "none")) return null;
    return try std.fmt.parseInt(u64, value, 10);
}

fn parseOptionalU32(text: ?[]const u8) !?u32 {
    const value = text orelse return null;
    if (std.mem.eql(u8, value, "-") or std.mem.eql(u8, value, "none")) return null;
    return try std.fmt.parseInt(u32, value, 10);
}

fn parseEncryption(
    password_text: ?[]const u8,
    iv_text: ?[]const u8,
    salt_text: ?[]const u8,
    cycles_text: ?[]const u8,
) !?vort.SevenZipEncryptionOptions {
    const password = parseOptionalPassword(password_text) orelse {
        if (iv_text != null or salt_text != null or cycles_text != null)
            return error.Invalid7zOptions;
        return null;
    };
    const iv_hex = iv_text orelse return error.Invalid7zOptions;
    if (iv_hex.len != 32) return error.Invalid7zOptions;
    var iv: [16]u8 = undefined;
    _ = std.fmt.hexToBytes(&iv, iv_hex) catch return error.Invalid7zOptions;

    var salt: [16]u8 = @splat(0);
    var salt_len: u5 = 0;
    if (salt_text) |salt_hex| if (!std.mem.eql(u8, salt_hex, "-") and
        !std.mem.eql(u8, salt_hex, "none"))
    {
        if (salt_hex.len > 32 or salt_hex.len & 1 != 0) return error.Invalid7zOptions;
        salt_len = @intCast(salt_hex.len / 2);
        _ = std.fmt.hexToBytes(salt[0..salt_len], salt_hex) catch
            return error.Invalid7zOptions;
    };
    const cycles = if (cycles_text) |text|
        try std.fmt.parseInt(u6, text, 10)
    else
        19;
    return .{
        .password = password,
        .iv = iv,
        .salt = salt,
        .salt_len = salt_len,
        .num_cycles_power = cycles,
    };
}

fn parseHeaderEncryption(text: ?[]const u8) !bool {
    const value = text orelse return false;
    if (std.mem.eql(u8, value, "encrypted-header") or std.mem.eql(u8, value, "true"))
        return true;
    if (std.mem.eql(u8, value, "plain-header") or std.mem.eql(u8, value, "false"))
        return false;
    return error.Invalid7zOptions;
}

pub fn listFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const password = parseOptionalPassword(args.next());
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const archive = try vort.parseSevenZipArchiveAllocWithOptions(init.gpa, bytes, .{
        .password = password,
    });
    defer archive.deinit();
    try writeListing(stdout, archive.entries);
}

pub fn listSourceFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const password = parseOptionalPassword(args.next());
    var file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    defer file.close(init.io);
    const stat = try file.stat(init.io);
    var context = FileSource{ .file = file, .io = init.io };
    const archive = try vort.parseSevenZipSourceArchiveAllocWithOptions(
        init.gpa,
        .{ .context = &context, .len = stat.size, .read_at = FileSource.readAt },
        .{ .password = password },
    );
    defer archive.deinit();
    try writeListing(stdout, archive.entries);
    try stdout.print("seven_zip_source_reads={d} bytes={d} archive_bytes={d}\n", .{
        context.read_calls,
        context.bytes_read,
        stat.size,
    });
}

fn writeListing(stdout: *std.Io.Writer, entries: []const vort.SevenZipEntry) !void {
    try stdout.print("seven_zip_entries={d}\n", .{entries.len});
    for (entries, 0..) |entry, index|
        try stdout.print("index={d} kind={s} method={s} size={d} creation_defined={} creation={d} access_defined={} access={d} modification_defined={} modification={d} attributes_defined={} attributes={d} name={s}\n", .{
            index,
            @tagName(entry.kind),
            if (entry.method) |method| @tagName(method) else "none",
            entry.size,
            entry.creation_time != null,
            entry.creation_time orelse 0,
            entry.access_time != null,
            entry.access_time orelse 0,
            entry.modification_time != null,
            entry.modification_time orelse 0,
            entry.attributes != null,
            entry.attributes orelse 0,
            entry.name,
        });
}

pub fn extractFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output_len = try parseLimit(args.next(), std.math.maxInt(usize));
    const max_dictionary_size = try parseLimit(args.next(), 512 * 1024 * 1024);
    const max_folder_output_len = try parseLimit(args.next(), 512 * 1024 * 1024);
    const password = parseOptionalPassword(args.next());
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const archive = try vort.parseSevenZipArchiveAllocWithOptions(init.gpa, bytes, .{
        .max_dictionary_size = max_dictionary_size,
        .password = password,
    });
    defer archive.deinit();
    const entry = archive.find(entry_name) orelse return error.EntryNotFound;
    const decoded = try archive.decodeEntryAllocWithOptions(init.gpa, entry, .{
        .max_output_len = max_output_len,
        .max_dictionary_size = max_dictionary_size,
        .max_folder_output_len = max_folder_output_len,
        .password = password,
    });
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("seven_zip_bytes={d} decoded_bytes={d} entry={s} path={s}\n", .{
        bytes.len,
        decoded.len,
        entry_name,
        output_path,
    });
}

pub fn extractSourceFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output_len = try parseLimit(args.next(), std.math.maxInt(usize));
    const max_dictionary_size = try parseLimit(args.next(), 512 * 1024 * 1024);
    const max_folder_output_len = try parseLimit(args.next(), 512 * 1024 * 1024);
    const password = parseOptionalPassword(args.next());
    var file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    defer file.close(init.io);
    const stat = try file.stat(init.io);
    var context = FileSource{ .file = file, .io = init.io };
    const archive = try vort.parseSevenZipSourceArchiveAllocWithOptions(
        init.gpa,
        .{ .context = &context, .len = stat.size, .read_at = FileSource.readAt },
        .{ .max_dictionary_size = max_dictionary_size, .password = password },
    );
    defer archive.deinit();
    const entry = archive.find(entry_name) orelse return error.EntryNotFound;
    const decoded = try archive.decodeEntryAllocWithOptions(init.gpa, entry, .{
        .max_output_len = max_output_len,
        .max_dictionary_size = max_dictionary_size,
        .max_folder_output_len = max_folder_output_len,
        .password = password,
    });
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print(
        "seven_zip_source_reads={d} bytes={d} archive_bytes={d} decoded_bytes={d} entry={s} path={s}\n",
        .{
            context.read_calls,
            context.bytes_read,
            stat.size,
            decoded.len,
            entry_name,
            output_path,
        },
    );
}

pub fn extractSourceStreamFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output_len = try parseLimit(args.next(), std.math.maxInt(usize));
    const max_dictionary_size = try parseLimit(args.next(), 512 * 1024 * 1024);
    const max_folder_output_len = try parseLimit(args.next(), 512 * 1024 * 1024);
    const password = parseOptionalPassword(args.next());
    var file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    defer file.close(init.io);
    const stat = try file.stat(init.io);
    var context = FileSource{ .file = file, .io = init.io };
    const archive = try vort.parseSevenZipSourceArchiveAllocWithOptions(
        init.gpa,
        .{ .context = &context, .len = stat.size, .read_at = FileSource.readAt },
        .{ .max_dictionary_size = max_dictionary_size, .password = password },
    );
    defer archive.deinit();
    const entry = archive.find(entry_name) orelse return error.EntryNotFound;
    var decoder = try archive.entryDecoder(init.gpa, entry, .{
        .max_output_len = max_output_len,
        .max_dictionary_size = max_dictionary_size,
        .max_folder_output_len = max_folder_output_len,
        .password = password,
        .input_buffer_size = 4096,
        .decoded_buffer_size = 4096,
    });
    defer decoder.deinit();
    var decoded: std.ArrayList(u8) = .empty;
    defer decoded.deinit(init.gpa);
    var scratch: [4096]u8 = undefined;
    var calls: usize = 0;
    while (true) {
        calls = std.math.add(usize, calls, 1) catch return error.IntegerOverflow;
        const stepped = try decoder.step(&scratch);
        try decoded.appendSlice(init.gpa, scratch[0..stepped.progress.output_written]);
        if (decoded.items.len > max_output_len) return error.OutputLimitExceeded;
        if (stepped.status == .done) break;
        if (stepped.status == .need_input) return error.Invalid7zArchive;
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded.items });
    const snapshot = decoder.snapshot();
    try stdout.print(
        "seven_zip_source_stream_reads={d} bytes={d} archive_bytes={d} decoded_bytes={d} calls={d} codec={s} entry={s} path={s}\n",
        .{
            context.read_calls,
            context.bytes_read,
            stat.size,
            decoded.items.len,
            calls,
            snapshot.codec_name,
            entry_name,
            output_path,
        },
    );
}

pub fn listVolumes(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const password = parseOptionalPassword(args.next());
    var files = try FileVolumeSource.open(init, args);
    defer files.deinit();
    var split = try vort.SevenZipSplitCallbackSource.initAlloc(init.gpa, .{
        .context = &files,
        .part_lengths = files.lengths,
        .read_at = FileVolumeSource.readAt,
    }, .{ .max_parts = 1_000_000 });
    defer split.deinit();
    const archive = try vort.parseSevenZipSourceArchiveAllocWithOptions(
        init.gpa,
        split.source(),
        .{ .password = password },
    );
    defer archive.deinit();
    try writeListing(stdout, archive.entries);
    try stdout.print(
        "seven_zip_volume_parts={d} reads={d} bytes={d} archive_bytes={d}\n",
        .{ files.files.len, files.read_calls, files.bytes_read, split.total_len },
    );
}

pub fn extractVolumes(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output_len = try parseLimit(args.next(), std.math.maxInt(usize));
    const max_dictionary_size = try parseLimit(args.next(), 512 * 1024 * 1024);
    const max_folder_output_len = try parseLimit(args.next(), 512 * 1024 * 1024);
    const password = parseOptionalPassword(args.next());
    var files = try FileVolumeSource.open(init, args);
    defer files.deinit();
    var split = try vort.SevenZipSplitCallbackSource.initAlloc(init.gpa, .{
        .context = &files,
        .part_lengths = files.lengths,
        .read_at = FileVolumeSource.readAt,
    }, .{ .max_parts = 1_000_000 });
    defer split.deinit();
    const archive = try vort.parseSevenZipSourceArchiveAllocWithOptions(
        init.gpa,
        split.source(),
        .{ .max_dictionary_size = max_dictionary_size, .password = password },
    );
    defer archive.deinit();
    const entry = archive.find(entry_name) orelse return error.EntryNotFound;
    var decoder = try archive.entryDecoder(init.gpa, entry, .{
        .max_output_len = max_output_len,
        .max_dictionary_size = max_dictionary_size,
        .max_folder_output_len = max_folder_output_len,
        .password = password,
        .input_buffer_size = 4096,
        .decoded_buffer_size = 4096,
    });
    defer decoder.deinit();
    var decoded: std.ArrayList(u8) = .empty;
    defer decoded.deinit(init.gpa);
    var scratch: [4096]u8 = undefined;
    var calls: usize = 0;
    while (true) {
        calls = std.math.add(usize, calls, 1) catch return error.IntegerOverflow;
        const stepped = try decoder.step(&scratch);
        try decoded.appendSlice(init.gpa, scratch[0..stepped.progress.output_written]);
        if (decoded.items.len > max_output_len) return error.OutputLimitExceeded;
        if (stepped.status == .done) break;
        if (stepped.status == .need_input) return error.Invalid7zArchive;
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded.items });
    try stdout.print(
        "seven_zip_volume_parts={d} reads={d} bytes={d} archive_bytes={d} decoded_bytes={d} calls={d} entry={s} path={s}\n",
        .{
            files.files.len,
            files.read_calls,
            files.bytes_read,
            split.total_len,
            decoded.items.len,
            calls,
            entry_name,
            output_path,
        },
    );
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_archive_size));
}

fn parseLimit(value: ?[]const u8, default: usize) !usize {
    return if (value) |text| try std.fmt.parseInt(usize, text, 10) else default;
}

fn parseOptionalPassword(value: ?[]const u8) ?[]const u8 {
    const password = value orelse return null;
    if (std.mem.eql(u8, password, "-") or std.mem.eql(u8, password, "none")) return null;
    return password;
}

fn parseCompression(text: ?[]const u8) !vort.SevenZipCompression {
    const value = text orelse return .copy;
    if (std.mem.eql(u8, value, "copy")) return .copy;
    if (std.mem.eql(u8, value, "deflate")) return .deflate;
    if (std.mem.eql(u8, value, "bzip2")) return .bzip2;
    if (std.mem.eql(u8, value, "lzma")) return .lzma;
    if (std.mem.eql(u8, value, "lzma2")) return .lzma2;
    if (std.mem.eql(u8, value, "lzma2-stored")) return .lzma2_stored;
    if (std.mem.eql(u8, value, "ppmd7") or std.mem.eql(u8, value, "ppmd")) return .ppmd7;
    return error.Unsupported7zFeature;
}
