const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;

pub fn createFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const format = try parseFormat(args.next());
    const compression = try parseCompression(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const entries = [_]vort.CpioEncodeEntry{.{ .name = entry_name, .data = input }};
    const encoded = try vort.encodeCompressedCpioAlloc(init.gpa, &entries, .{
        .archive_options = .{ .format = format },
        .compression = compression,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("cpio_entries=1 format={s} compression={s} input_bytes={d} archive_bytes={d} path={s}\n", .{
        @tagName(format),
        @tagName(compression),
        input.len,
        encoded.len,
        output_path,
    });
}

pub fn listFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const owned = try vort.decodeAutoCpioAlloc(init.gpa, bytes, max_file_size);
    defer owned.deinit(init.gpa);
    const archive = owned.archive;
    try stdout.print("cpio_entries={d} format={s} compression={s} archive_end={d} trailer_padding={d}\n", .{
        archive.entry_count,
        @tagName(archive.format),
        @tagName(owned.compression),
        archive.archive_end,
        archive.trailer_padding,
    });
    var iterator = archive.iterator();
    var index: usize = 0;
    while (try iterator.next()) |entry| : (index += 1) {
        try stdout.print("index={d} kind={s} mode={o} size={d} uid={d} gid={d} links={d} mtime={d} safe_path={} checksum={?d} name={s}\n", .{
            index,
            @tagName(entry.kind),
            entry.mode,
            entry.stored_size,
            entry.uid,
            entry.gid,
            entry.link_count,
            entry.mtime,
            entry.safe_path,
            entry.checksum,
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
    const owned = try vort.decodeAutoCpioAlloc(init.gpa, bytes, max_file_size);
    defer owned.deinit(init.gpa);
    const archive = owned.archive;
    const decoded = try archive.extractByNameAllocLimited(
        init.gpa,
        entry_name,
        max_output_len,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("cpio_bytes={d} decoded_bytes={d} entry={s} path={s}\n", .{
        bytes.len,
        decoded.len,
        entry_name,
        output_path,
    });
}

fn parseFormat(value: ?[]const u8) !vort.CpioFormat {
    const name = value orelse return .newc;
    if (std.mem.eql(u8, name, "newc")) return .newc;
    if (std.mem.eql(u8, name, "crc")) return .crc;
    if (std.mem.eql(u8, name, "odc")) return .odc;
    if (std.mem.eql(u8, name, "bin") or std.mem.eql(u8, name, "bin-le")) return .binary_little;
    if (std.mem.eql(u8, name, "bin-be")) return .binary_big;
    return error.UnsupportedCpioFormat;
}

fn parseCompression(value: ?[]const u8) !vort.CpioCompression {
    const name = value orelse return .none;
    if (std.mem.eql(u8, name, "none")) return .none;
    if (std.mem.eql(u8, name, "gzip") or std.mem.eql(u8, name, "gz")) return .gzip;
    if (std.mem.eql(u8, name, "bzip2") or std.mem.eql(u8, name, "bz2")) return .bzip2;
    if (std.mem.eql(u8, name, "brotli") or std.mem.eql(u8, name, "br")) return .brotli;
    if (std.mem.eql(u8, name, "compress-z") or std.mem.eql(u8, name, "Z")) return .compress_z;
    if (std.mem.eql(u8, name, "lzma")) return .lzma;
    if (std.mem.eql(u8, name, "xz")) return .xz;
    if (std.mem.eql(u8, name, "lz4")) return .lz4;
    if (std.mem.eql(u8, name, "lzip")) return .lzip;
    if (std.mem.eql(u8, name, "lzf")) return .lzf;
    if (std.mem.eql(u8, name, "zstandard") or std.mem.eql(u8, name, "zstd")) return .zstandard;
    if (std.mem.eql(u8, name, "lzop")) return .lzop;
    return error.UnknownCpioCompression;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
