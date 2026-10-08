const std = @import("std");
const vort = @import("vort");

const max_archive_size = 512 * 1024 * 1024;

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
    const entries = [_]vort.SevenZipEncodeEntry{.{ .name = entry_name, .data = input }};
    const encoded = try vort.encodeSevenZipStoredAlloc(init.gpa, &entries, .{});
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("seven_zip_entries=1 input_bytes={d} archive_bytes={d} path={s}\n", .{
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
    const archive = try vort.parseSevenZipArchiveAlloc(init.gpa, bytes);
    defer archive.deinit();
    try stdout.print("seven_zip_entries={d}\n", .{archive.entries.len});
    for (archive.entries, 0..) |entry, index|
        try stdout.print("index={d} kind={s} method={s} size={d} name={s}\n", .{
            index,
            @tagName(entry.kind),
            if (entry.method) |method| @tagName(method) else "none",
            entry.size,
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
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const archive = try vort.parseSevenZipArchiveAllocWithOptions(init.gpa, bytes, .{
        .max_dictionary_size = max_dictionary_size,
    });
    defer archive.deinit();
    const entry = archive.find(entry_name) orelse return error.EntryNotFound;
    const decoded = try archive.decodeEntryAllocWithOptions(init.gpa, entry, .{
        .max_output_len = max_output_len,
        .max_dictionary_size = max_dictionary_size,
        .max_folder_output_len = max_folder_output_len,
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

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_archive_size));
}

fn parseLimit(value: ?[]const u8, default: usize) !usize {
    return if (value) |text| try std.fmt.parseInt(usize, text, 10) else default;
}
