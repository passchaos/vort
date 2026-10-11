const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;

pub fn encode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const marker_name = args.next() orelse "no-marker";
    const end_marker = if (std.mem.eql(u8, marker_name, "marker"))
        true
    else if (std.mem.eql(u8, marker_name, "no-marker"))
        false
    else
        return error.InvalidBlockPlan;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeLznt1Alloc(init.gpa, input, .{ .end_marker = end_marker });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print(
        "input_bytes={d} lznt1_bytes={d} end_marker={} path={s}\n",
        .{ input.len, encoded.len, end_marker, output_path },
    );
}

pub fn decode(
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
    const decoded = try vort.decodeLznt1AllocLimited(init.gpa, input, limit);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("lznt1_bytes={d} decoded_bytes={d} path={s}\n", .{
        input.len,
        decoded.len,
        output_path,
    });
}

pub fn inspect(
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
    const summary = try vort.lznt1SummarizeLimited(input, limit);
    try stdout.print(
        "lznt1_bytes={d} decoded_bytes={d} chunks={d} compressed={d} stored={d} terminated={}\n",
        .{
            summary.encoded_size,
            summary.decoded_size,
            summary.chunk_count,
            summary.compressed_chunks,
            summary.stored_chunks,
            summary.terminated,
        },
    );
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
