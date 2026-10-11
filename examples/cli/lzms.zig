const std = @import("std");
const vort = @import("vort");

const max_file_size = 1024 * 1024 * 1024;

pub fn decode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const decoded_size_text = args.next() orelse return error.MissingCorpusPath;
    const decoded_size = try std.fmt.parseInt(usize, decoded_size_text, 10);
    const input = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        input_path,
        init.gpa,
        .limited(max_file_size),
    );
    defer init.gpa.free(input);
    const decoded = try vort.decodeLzmsAllocLimited(
        init.gpa,
        input,
        decoded_size,
        max_file_size,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded,
    });
    try stdout.print("lzms_bytes={d} decoded_bytes={d} path={s}\n", .{
        input.len,
        decoded.len,
        output_path,
    });
}
