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
    const control = try std.fmt.allocPrint(
        init.gpa,
        "Package: {s}\nVersion: {s}\nArchitecture: all\nMaintainer: Vort\nDescription: Vort generated package\n",
        .{ package_name, version },
    );
    defer init.gpa.free(control);
    const control_entries = [_]vort.TarEncodeEntry{.{ .name = "control", .data = control }};
    const data_entries = [_]vort.TarEncodeEntry{.{ .name = entry_name, .data = input }};
    const encoded = try vort.encodeDebAlloc(init.gpa, &control_entries, &data_entries, .{
        .control_compression = .gzip,
        .data_compression = compression,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print(
        "deb_package={s} version={s} data_compression={s} input_bytes={d} package_bytes={d} path={s}\n",
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
    const package = try vort.parseDebPackage(bytes);
    const control = try package.decodeControlAlloc(init.gpa, max_file_size);
    defer control.deinit(init.gpa);
    const data = try package.decodeDataAlloc(init.gpa, max_file_size);
    defer data.deinit(init.gpa);
    try stdout.print(
        "deb_control_compression={s} deb_data_compression={s} control_entries={d} data_entries={d} package_bytes={d}\n",
        .{
            @tagName(package.control_compression),
            @tagName(package.data_compression),
            control.archive.entry_count,
            data.archive.entry_count,
            bytes.len,
        },
    );
    var iterator_value = data.archive.iterator();
    var index: usize = 0;
    while (try iterator_value.next()) |entry| : (index += 1) {
        const name = try entry.path.alloc(init.gpa);
        defer init.gpa.free(name);
        try stdout.print("index={d} kind={s} size={d} safe_path={} name={s}\n", .{
            index,
            @tagName(entry.kind),
            entry.size,
            entry.path.isSafeRelative(),
            name,
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
    const package = try vort.parseDebPackage(bytes);
    const decoded = try package.extractDataByNameAllocLimited(
        init.gpa,
        entry_name,
        max_file_size,
        max_output_len,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("deb_bytes={d} decoded_bytes={d} entry={s} path={s}\n", .{
        bytes.len,
        decoded.len,
        entry_name,
        output_path,
    });
}

fn parseCompression(value: ?[]const u8) !vort.DebCompression {
    const name = value orelse return .xz;
    if (std.mem.eql(u8, name, "none")) return .none;
    if (std.mem.eql(u8, name, "gzip") or std.mem.eql(u8, name, "gz")) return .gzip;
    if (std.mem.eql(u8, name, "bzip2") or std.mem.eql(u8, name, "bz2")) return .bzip2;
    if (std.mem.eql(u8, name, "lzma")) return .lzma;
    if (std.mem.eql(u8, name, "xz")) return .xz;
    if (std.mem.eql(u8, name, "zstd") or std.mem.eql(u8, name, "zst")) return .zstandard;
    return error.UnsupportedDebCompression;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
