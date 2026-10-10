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
    const block_size = if (args.next()) |value|
        try std.fmt.parseInt(usize, value, 10)
    else
        65_535;
    const eof_marker = try parseEofMarker(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeLzfAlloc(init.gpa, input, .{
        .block_size = block_size,
        .eof_marker = eof_marker,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    const info = try vort.inspectLzf(encoded);
    try stdout.print("lzf_input_bytes={d} encoded_bytes={d} block_size={d} blocks={d} stored_blocks={d} compressed_blocks={d} eof_marker={} path={s}\n", .{
        input.len,
        encoded.len,
        block_size,
        info.block_count,
        info.stored_block_count,
        info.compressed_block_count,
        info.eof_marker,
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
    const max_output_len = (try parseOptionalLimit(args.next())) orelse max_file_size;
    const compressed = try readFile(init, input_path);
    defer init.gpa.free(compressed);
    const decoded = try vort.decodeLzfAllocLimited(init.gpa, compressed, max_output_len);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("lzf_bytes={d} decoded_bytes={d} path={s}\n", .{
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
    const max_output_len = (try parseOptionalLimit(args.next())) orelse max_file_size;
    const compressed = try readFile(init, input_path);
    defer init.gpa.free(compressed);
    const decoded_len = try vort.lzfDecodedSizeLimited(compressed, max_output_len);
    try stdout.print("lzf_bytes={d} decoded_bytes={d}\n", .{ compressed.len, decoded_len });
}

pub fn inspectFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const compressed = try readFile(init, input_path);
    defer init.gpa.free(compressed);
    const info = try vort.inspectLzf(compressed);
    try stdout.print("lzf_blocks={d} stored_blocks={d} compressed_blocks={d} compressed_bytes={d} decoded_bytes={d} max_block={d} eof_marker={}\n", .{
        info.block_count,
        info.stored_block_count,
        info.compressed_block_count,
        info.encoded_size,
        info.uncompressed_size,
        info.max_uncompressed_block_size,
        info.eof_marker,
    });
}

fn parseEofMarker(value: ?[]const u8) !bool {
    const name = value orelse return false;
    if (std.mem.eql(u8, name, "eof")) return true;
    if (std.mem.eql(u8, name, "no-eof")) return false;
    return error.InvalidLzfEofMode;
}

fn parseOptionalLimit(value: ?[]const u8) !?usize {
    return if (value) |text| try std.fmt.parseInt(usize, text, 10) else null;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
