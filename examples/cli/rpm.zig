const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;

pub fn createFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const package_name = args.next() orelse return error.MissingCorpusPath;
    const version = args.next() orelse return error.MissingCorpusPath;
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const compression = try parseCompression(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const entries = [_]vort.RpmEncodeEntry{.{ .name = entry_name, .data = input }};
    const encoded = try vort.encodeRpmAlloc(init.gpa, &entries, .{
        .name = package_name,
        .version = version,
        .payload_compression = compression,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print(
        "rpm_name={s} version={s} payload_compression={s} input_bytes={d} package_bytes={d} path={s}\n",
        .{ package_name, version, @tagName(compression), input.len, encoded.len, output_path },
    );
}

pub fn listFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const package = try vort.parseRpmPackage(bytes);
    const digests = try package.verifyDigests();
    const payload = try package.decodePayloadAlloc(init.gpa, max_file_size);
    defer payload.deinit(init.gpa);
    try stdout.print(
        "rpm_name={s} version={s} release={s} arch={s} os={s} payload_compression={s} payload_entries={d} md5={} sha1={} sha256={} package_bytes={d}\n",
        .{
            try package.name(),
            try package.version(),
            try package.release(),
            try package.architecture(),
            try package.operatingSystem(),
            @tagName(package.payload_compression),
            payload.archive.entry_count,
            digests.md5,
            digests.sha1,
            digests.sha256,
            bytes.len,
        },
    );
    var iterator_value = payload.archive.iterator();
    var index: usize = 0;
    while (try iterator_value.next()) |entry| : (index += 1) {
        try stdout.print("index={d} kind={s} size={d} mode={o} safe_path={} name={s}\n", .{
            index,
            @tagName(entry.kind),
            entry.stored_size,
            entry.mode,
            entry.safe_path,
            entry.name,
        });
    }
}

pub fn extractFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output_len = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const package = try vort.parseRpmPackage(bytes);
    const decoded = try package.extractByNameAllocLimited(
        init.gpa,
        entry_name,
        max_file_size,
        max_output_len,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("rpm_bytes={d} decoded_bytes={d} entry={s} path={s}\n", .{
        bytes.len,
        decoded.len,
        entry_name,
        output_path,
    });
}

pub fn extractPayload(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output_len = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const package = try vort.parseRpmPackage(bytes);
    const payload = try package.decodePayloadAlloc(init.gpa, max_output_len);
    defer payload.deinit(init.gpa);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = payload.bytes,
    });
    try stdout.print("rpm_bytes={d} cpio_bytes={d} compression={s} path={s}\n", .{
        bytes.len,
        payload.bytes.len,
        @tagName(package.payload_compression),
        output_path,
    });
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}

fn parseCompression(value: ?[]const u8) !vort.RpmPayloadCompression {
    const name = value orelse return .xz;
    if (std.mem.eql(u8, name, "none")) return .none;
    if (std.mem.eql(u8, name, "gzip") or std.mem.eql(u8, name, "gz")) return .gzip;
    if (std.mem.eql(u8, name, "bzip2") or std.mem.eql(u8, name, "bz2")) return .bzip2;
    if (std.mem.eql(u8, name, "lzma")) return .lzma;
    if (std.mem.eql(u8, name, "xz")) return .xz;
    if (std.mem.eql(u8, name, "zstd") or std.mem.eql(u8, name, "zst")) return .zstandard;
    return error.UnsupportedRpmPayload;
}
