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
    const entries = [_]vort.ArcEncodeEntry{.{
        .name = entry_name,
        .data = input,
        .method = method,
    }};
    const encoded = try vort.encodeArcAlloc(init.gpa, &entries);
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("arc_entries=1 method={s} input_bytes={d} archive_bytes={d} path={s}\n", .{
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
    const archive = try vort.parseArcArchive(bytes);
    try stdout.print("arc_entries={d} prefix_bytes={d} trailer_bytes={d}\n", .{
        archive.entry_count,
        archive.prefix_size,
        archive.trailer_size,
    });
    var iterator = archive.iterator();
    var index: usize = 0;
    while (try iterator.next()) |entry| : (index += 1) {
        try stdout.print("index={d} method={s} compressed={d} uncompressed={d} crc16={d} name={s}\n", .{
            index,
            @tagName(entry.method),
            entry.compressed_size,
            entry.uncompressed_size,
            entry.crc16,
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
    const archive = try vort.parseArcArchive(bytes);
    const decoded = try archive.extractByNameAllocLimited(
        init.gpa,
        entry_name,
        max_output_len,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("arc_bytes={d} decoded_bytes={d} entry={s} path={s}\n", .{
        bytes.len,
        decoded.len,
        entry_name,
        output_path,
    });
}

fn parseMethod(value: ?[]const u8) !vort.ArcMethod {
    const name = value orelse return .crunched_8;
    if (std.mem.eql(u8, name, "stored1")) return .stored_1;
    if (std.mem.eql(u8, name, "stored") or std.mem.eql(u8, name, "stored2")) return .stored_2;
    if (std.mem.eql(u8, name, "packed")) return .packed_rle;
    if (std.mem.eql(u8, name, "squeezed")) return .squeezed;
    if (std.mem.eql(u8, name, "crunched5")) return .crunched_5;
    if (std.mem.eql(u8, name, "crunched6")) return .crunched_6;
    if (std.mem.eql(u8, name, "crunched7")) return .crunched_7;
    if (std.mem.eql(u8, name, "crunched") or std.mem.eql(u8, name, "crunched8")) return .crunched_8;
    if (std.mem.eql(u8, name, "squashed")) return .squashed;
    return error.UnsupportedArcMethod;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
