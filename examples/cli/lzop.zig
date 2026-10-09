const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;

pub fn encodeFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    return encodeFileWithMode(init, args, stdout, false);
}

pub fn encodeStoredFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    return encodeFileWithMode(init, args, stdout, true);
}

fn encodeFileWithMode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
    stored_only: bool,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const block_size = if (args.next()) |value|
        try std.fmt.parseInt(usize, value, 10)
    else
        256 * 1024;
    const checksum = try parseChecksum(args.next());
    const compressed_checksum = try parseCompressedChecksum(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const options = vort.LzopEncodeOptions{
        .block_size = block_size,
        .checksum = checksum,
        .compressed_checksum = compressed_checksum,
    };
    const encoded = if (stored_only)
        try vort.encodeLzopStoredAlloc(init.gpa, input, options)
    else
        try vort.encodeLzopAlloc(init.gpa, input, options);
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    const info = try vort.inspectLzop(encoded);
    try stdout.print("lzop_input_bytes={d} encoded_bytes={d} block_size={d} checksum={s} stored_blocks={d} compressed_blocks={d} path={s}\n", .{
        input.len,
        encoded.len,
        block_size,
        @tagName(checksum),
        info.stored_block_count,
        info.compressed_block_count,
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
    const options = try parseDecodeOptions(args);
    const compressed = try readFile(init, input_path);
    defer init.gpa.free(compressed);
    const decoded = try vort.decodeLzopAllocWithOptions(init.gpa, compressed, options);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("lzop_bytes={d} decoded_bytes={d} path={s}\n", .{
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
    const options = try parseDecodeOptions(args);
    const compressed = try readFile(init, input_path);
    defer init.gpa.free(compressed);
    const decoded_len = try vort.lzopDecodedSizeWithOptions(init.gpa, compressed, options);
    try stdout.print("lzop_bytes={d} decoded_bytes={d}\n", .{ compressed.len, decoded_len });
}

pub fn inspectFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const compressed = try readFile(init, input_path);
    defer init.gpa.free(compressed);
    const info = try vort.inspectLzop(compressed);
    try stdout.print("lzop_streams={d} blocks={d} stored_blocks={d} compressed_blocks={d} compressed_bytes={d} decoded_bytes={d} max_block={d}\n", .{
        info.stream_count,
        info.block_count,
        info.stored_block_count,
        info.compressed_block_count,
        info.compressed_size,
        info.uncompressed_size,
        info.max_block_size,
    });
}

fn parseChecksum(value: ?[]const u8) !vort.LzopChecksum {
    const name = value orelse return .adler32;
    if (std.mem.eql(u8, name, "adler32")) return .adler32;
    if (std.mem.eql(u8, name, "crc32")) return .crc32;
    return error.InvalidChecksum;
}

fn parseCompressedChecksum(value: ?[]const u8) !bool {
    const name = value orelse return false;
    if (std.mem.eql(u8, name, "compressed-checksum")) return true;
    if (std.mem.eql(u8, name, "no-compressed-checksum")) return false;
    return error.InvalidChecksum;
}

fn parseDecodeOptions(args: *std.process.Args.Iterator) !vort.LzopDecodeOptions {
    return .{
        .max_output_len = (try parseOptionalLimit(args.next())) orelse std.math.maxInt(usize),
        .max_block_size = (try parseOptionalLimit(args.next())) orelse 64 * 1024 * 1024,
    };
}

fn parseOptionalLimit(value: ?[]const u8) !?usize {
    return if (value) |text| try std.fmt.parseInt(usize, text, 10) else null;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
