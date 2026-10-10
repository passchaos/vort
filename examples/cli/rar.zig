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
    const version = try parseVersion(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const entries = [_]vort.RarEncodeEntry{.{ .name = entry_name, .data = input }};
    const encoded = try vort.encodeRarAlloc(init.gpa, &entries, .{ .version = version });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("rar_entries=1 version={s} method=stored input_bytes={d} archive_bytes={d} path={s}\n", .{
        @tagName(version),
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
    const archive = try vort.parseRarArchive(bytes);
    try stdout.print("rar_entries={d} version={s} prefix_bytes={d} trailer_bytes={d} volume={} solid={} locked={}\n", .{
        archive.entry_count,
        @tagName(archive.version),
        archive.prefix_size,
        archive.trailer_size,
        archive.multi_volume,
        archive.solid,
        archive.locked,
    });
    var iterator = archive.iterator();
    var index: usize = 0;
    while (try iterator.next()) |entry| : (index += 1) {
        const name = try entry.name.alloc(init.gpa);
        defer init.gpa.free(name);
        try stdout.print("index={d} method={s} method_id={d} compression_version={d} compressed={d} uncompressed={d} crc32={?d} directory={} encrypted={} solid={} split_before={} split_after={} safe_path={} name={s}\n", .{
            index,
            @tagName(entry.method),
            entry.method_id,
            entry.compression_version,
            entry.compressed_size,
            entry.uncompressed_size,
            entry.crc32,
            entry.directory,
            entry.encrypted,
            entry.solid,
            entry.split_before,
            entry.split_after,
            entry.safe_path,
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
    const archive = try vort.parseRarArchive(bytes);
    const decoded = try archive.extractByNameAllocLimited(
        init.gpa,
        entry_name,
        max_output_len,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("rar_bytes={d} decoded_bytes={d} entry={s} path={s}\n", .{
        bytes.len,
        decoded.len,
        entry_name,
        output_path,
    });
}

fn parseVersion(value: ?[]const u8) !vort.RarVersion {
    const name = value orelse return .rar5;
    if (std.mem.eql(u8, name, "rar4") or std.mem.eql(u8, name, "4")) return .rar4;
    if (std.mem.eql(u8, name, "rar5") or std.mem.eql(u8, name, "5")) return .rar5;
    return error.UnsupportedRarVersion;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
