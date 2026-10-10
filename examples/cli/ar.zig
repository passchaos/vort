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
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const entries = [_]vort.ArEncodeEntry{.{ .name = entry_name, .data = input }};
    const encoded = try vort.encodeArAlloc(init.gpa, &entries);
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("ar_entries=1 input_bytes={d} archive_bytes={d} path={s}\n", .{
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
    const archive = try vort.parseArArchive(bytes);
    try stdout.print("ar_entries={d} archive_bytes={d}\n", .{ archive.entry_count, bytes.len });
    var iterator_value = archive.iterator();
    var index: usize = 0;
    while (try iterator_value.next()) |entry| : (index += 1) {
        try stdout.print(
            "index={d} size={d} timestamp={d} owner={d} group={d} mode={o} safe_path={} name={s}\n",
            .{
                index,
                entry.size,
                entry.timestamp,
                entry.owner,
                entry.group,
                entry.mode,
                entry.safe_path,
                entry.name,
            },
        );
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
    const archive = try vort.parseArArchive(bytes);
    const decoded = try archive.extractByNameAllocLimited(
        init.gpa,
        entry_name,
        max_output_len,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("ar_bytes={d} decoded_bytes={d} entry={s} path={s}\n", .{
        bytes.len,
        decoded.len,
        entry_name,
        output_path,
    });
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
