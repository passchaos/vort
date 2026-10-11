const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;

pub fn encodePlain(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeXpressPlainAlloc(init.gpa, input, .{});
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("input_bytes={d} xpress_plain_bytes={d} path={s}\n", .{
        input.len,
        encoded.len,
        output_path,
    });
}

pub fn decodePlain(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const decoded = try vort.decodeXpressPlainAllocLimited(init.gpa, input, limit);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("xpress_plain_bytes={d} decoded_bytes={d} path={s}\n", .{
        input.len,
        decoded.len,
        output_path,
    });
}

pub fn inspectPlain(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const summary = try vort.xpressSummarizePlainLimited(input, limit);
    try stdout.print(
        "xpress_plain_bytes={d} decoded_bytes={d} literals={d} matches={d} matched_bytes={d}\n",
        .{
            summary.encoded_size,
            summary.decoded_size,
            summary.literals,
            summary.matches,
            summary.matched_bytes,
        },
    );
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
