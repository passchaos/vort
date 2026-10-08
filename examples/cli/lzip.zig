const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;

pub fn decodeFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const options = try parseOptions(args);
    const compressed = try readFile(init, input_path);
    defer init.gpa.free(compressed);
    const decoded = try vort.decodeLzipAllocWithOptions(init.gpa, compressed, options);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("lzip_bytes={d} decoded_bytes={d} path={s}\n", .{
        compressed.len,
        decoded.len,
        output_path,
    });
}

pub fn sizeFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const options = try parseOptions(args);
    const compressed = try readFile(init, input_path);
    defer init.gpa.free(compressed);
    const decoded_len = try vort.lzipDecodedSizeWithOptions(init.gpa, compressed, options);
    try stdout.print("lzip_bytes={d} decoded_bytes={d}\n", .{ compressed.len, decoded_len });
}

pub fn inspectFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const compressed = try readFile(init, input_path);
    defer init.gpa.free(compressed);
    const info = try vort.inspectLzip(init.gpa, compressed);
    try stdout.print("lzip_members={d} compressed_bytes={d} decoded_bytes={d} max_dictionary={d}\n", .{
        info.member_count,
        info.compressed_size,
        info.uncompressed_size,
        info.max_dictionary_size,
    });
}

fn parseOptions(args: *std.process.Args.Iterator) !vort.LzipDecodeOptions {
    return .{
        .max_output_len = (try parseOptionalLimit(args.next())) orelse std.math.maxInt(usize),
        .max_dictionary_size = (try parseOptionalLimit(args.next())) orelse 512 * 1024 * 1024,
    };
}

fn parseOptionalLimit(value: ?[]const u8) !?usize {
    return if (value) |text| try std.fmt.parseInt(usize, text, 10) else null;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
