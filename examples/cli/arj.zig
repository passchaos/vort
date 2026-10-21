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
    const encryption: ?vort.ArjEncodeEncryptionOptions = if (args.next()) |password|
        .{
            .password = password,
            .modifier = try std.fmt.parseInt(
                u8,
                args.next() orelse return error.MissingCorpusPath,
                16,
            ),
        }
    else
        null;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const entries = [_]vort.ArjEncodeEntry{.{
        .name = entry_name,
        .data = input,
        .method = method,
        .encryption = encryption,
    }};
    const encoded = try vort.encodeArjAlloc(init.gpa, &entries);
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("arj_entries=1 method={s} input_bytes={d} archive_bytes={d} path={s}\n", .{
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
    const archive = try vort.parseArjArchive(bytes);
    try stdout.print("arj_entries={d} prefix_bytes={d} name={s} comment_bytes={d}\n", .{
        archive.entry_count,
        archive.prefix_size,
        archive.name,
        archive.comment.len,
    });
    var iterator = archive.iterator();
    var index: usize = 0;
    while (try iterator.next()) |entry| : (index += 1) {
        const name = try entry.name.alloc(init.gpa);
        defer init.gpa.free(name);
        try stdout.print("index={d} method={s} compressed={d} uncompressed={d} crc32={d} encryption={s} modifier={d} directory={} name={s}\n", .{
            index,
            @tagName(entry.method),
            entry.compressed_size,
            entry.uncompressed_size,
            entry.crc32,
            if (entry.encryption) |encryption| @tagName(encryption) else "none",
            entry.password_modifier,
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
    const password = args.next();
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const archive = try vort.parseArjArchive(bytes);
    const decoded = try archive.extractByNameAllocWithOptions(
        init.gpa,
        entry_name,
        .{ .max_output_len = max_output_len, .password = password },
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("arj_bytes={d} decoded_bytes={d} entry={s} path={s}\n", .{
        bytes.len,
        decoded.len,
        entry_name,
        output_path,
    });
}

fn parseMethod(value: ?[]const u8) !vort.ArjMethod {
    const name = value orelse return .method_1;
    if (std.mem.eql(u8, name, "stored") or std.mem.eql(u8, name, "method0")) return .stored;
    if (std.mem.eql(u8, name, "method1")) return .method_1;
    if (std.mem.eql(u8, name, "method2")) return .method_2;
    if (std.mem.eql(u8, name, "method3")) return .method_3;
    if (std.mem.eql(u8, name, "method4")) return .method_4;
    return error.UnsupportedArjMethod;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
