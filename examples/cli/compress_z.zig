const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;

pub fn encodeFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_code_bits: u5 = if (args.next()) |value|
        try std.fmt.parseInt(u5, value, 10)
    else
        16;
    const mode = args.next() orelse "block";
    const block_mode = if (std.mem.eql(u8, mode, "block"))
        true
    else if (std.mem.eql(u8, mode, "nonblock"))
        false
    else
        return error.InvalidCompressMode;

    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(max_file_size));
    defer init.gpa.free(input);
    const encoded = try vort.encodeCompressZAlloc(init.gpa, input, .{
        .max_code_bits = max_code_bits,
        .block_mode = block_mode,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("compress_z_input_bytes={d} compressed_bytes={d} max_bits={d} block_mode={} path={s}\n", .{
        input.len,
        encoded.len,
        max_code_bits,
        block_mode,
        output_path,
    });
}

pub fn decodeFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output_len = try parseOptionalLimit(args.next());
    const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(max_file_size));
    defer init.gpa.free(compressed);
    const decoded = if (max_output_len) |limit|
        try vort.decodeCompressZAllocLimited(init.gpa, compressed, limit)
    else
        try vort.decodeCompressZAlloc(init.gpa, compressed);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("compress_z_bytes={d} decoded_bytes={d} path={s}\n", .{
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
    const max_output_len = try parseOptionalLimit(args.next());
    const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(max_file_size));
    defer init.gpa.free(compressed);
    const decoded_len = if (max_output_len) |limit|
        try vort.compressZDecodedSizeLimited(init.gpa, compressed, limit)
    else
        try vort.compressZDecodedSize(init.gpa, compressed);
    try stdout.print("compress_z_bytes={d} decoded_bytes={d}\n", .{ compressed.len, decoded_len });
}

fn parseOptionalLimit(value: ?[]const u8) !?usize {
    return if (value) |text| try std.fmt.parseInt(usize, text, 10) else null;
}
