const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;

pub fn encodeXerial(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const block_size = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else 32 * 1024;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeXerialSnappyAlloc(init.gpa, input, .{ .block_size = block_size });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("xerial_input_bytes={d} xerial_bytes={d} block_size={d} path={s}\n", .{
        input.len,
        encoded.len,
        block_size,
        output_path,
    });
}

pub fn decodeXerial(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = try parseLimit(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const decoded = try vort.decodeXerialSnappyAllocLimited(init.gpa, input, limit);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("xerial_bytes={d} decoded_bytes={d} path={s}\n", .{
        input.len,
        decoded.len,
        output_path,
    });
}

pub fn inspectXerial(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseXerialSnappy(input);
    try stdout.print("xerial_chunks={d} decoded_bytes={d} compressed_bytes={d}\n", .{
        archive.chunk_count,
        archive.decoded_size,
        input.len,
    });
}

pub fn encodeHadoop(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const block_size = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else 256 * 1024;
    const chunk_size = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else 64 * 1024;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeHadoopSnappyAlloc(init.gpa, input, .{
        .block_size = block_size,
        .chunk_size = chunk_size,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print(
        "hadoop_snappy_input_bytes={d} compressed_bytes={d} block_size={d} chunk_size={d} path={s}\n",
        .{ input.len, encoded.len, block_size, chunk_size, output_path },
    );
}

pub fn decodeHadoop(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = try parseLimit(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const decoded = try vort.decodeHadoopSnappyAllocLimited(init.gpa, input, limit);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("hadoop_snappy_bytes={d} decoded_bytes={d} path={s}\n", .{
        input.len,
        decoded.len,
        output_path,
    });
}

pub fn inspectHadoop(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseHadoopSnappy(input);
    try stdout.print(
        "hadoop_snappy_blocks={d} chunks={d} decoded_bytes={d} compressed_bytes={d}\n",
        .{ archive.block_count, archive.chunk_count, archive.decoded_size, input.len },
    );
}

fn parseLimit(value: ?[]const u8) !usize {
    return if (value) |text| try std.fmt.parseInt(usize, text, 10) else max_file_size;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
