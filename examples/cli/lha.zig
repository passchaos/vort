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
    const method = try parseMethod(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const entries = [_]vort.LhaEncodeEntry{.{
        .name = entry_name,
        .data = input,
        .method = method,
    }};
    const encoded = try vort.encodeLhaAlloc(init.gpa, &entries);
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("lha_entries=1 method={s} input_bytes={d} archive_bytes={d} path={s}\n", .{
        @tagName(method),
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
    const archive = try vort.parseLhaArchive(bytes);
    try stdout.print("lha_entries={d}\n", .{archive.entry_count});
    var iterator = archive.iterator();
    var index: usize = 0;
    while (try iterator.next()) |entry| : (index += 1) {
        const name = try entry.name.alloc(init.gpa);
        defer init.gpa.free(name);
        try stdout.print("index={d} method={s} level={d} compressed={d} uncompressed={d} crc16={d} directory={} name={s}\n", .{
            index,
            @tagName(entry.method),
            entry.header_level,
            entry.compressed_size,
            entry.uncompressed_size,
            entry.crc16,
            entry.isDirectory(),
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
    const archive = try vort.parseLhaArchive(bytes);
    const decoded = try archive.extractByNameAllocLimited(
        init.gpa,
        entry_name,
        max_output_len,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("lha_bytes={d} decoded_bytes={d} entry={s} path={s}\n", .{
        bytes.len,
        decoded.len,
        entry_name,
        output_path,
    });
}

fn parseMethod(value: ?[]const u8) !vort.LhaMethod {
    const name = value orelse return .lh5;
    if (std.mem.eql(u8, name, "stored") or std.mem.eql(u8, name, "lh0")) return .stored;
    if (std.mem.eql(u8, name, "lh5")) return .lh5;
    if (std.mem.eql(u8, name, "lh6")) return .lh6;
    if (std.mem.eql(u8, name, "lh7")) return .lh7;
    return error.UnsupportedLhaMethod;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
