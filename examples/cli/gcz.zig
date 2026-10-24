const std = @import("std");
const vort = @import("vort");

const max_file_size: u64 = 16 * 1024 * 1024 * 1024;
const max_local_file_size: usize = @intCast(@min(max_file_size, std.math.maxInt(usize)));

pub fn inspect(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const archive = try vort.parseGcz(bytes, .{});
    var raw_blocks: usize = 0;
    for (0..archive.header.block_count) |block_index|
        if ((try archive.block(block_index)).raw) {
            raw_blocks += 1;
        };
    try stdout.print(
        "sub_type={d} logical_bytes={d} stored_data_bytes={d} block_bytes={d} blocks={d} raw={d} zlib={d}\n",
        .{
            archive.header.sub_type,
            archive.header.logical_size,
            archive.header.compressed_data_size,
            archive.header.block_size,
            archive.header.block_count,
            raw_blocks,
            archive.header.block_count - raw_blocks,
        },
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
        max_local_file_size;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const archive = try vort.parseGcz(bytes, .{});
    const decoded = try archive.decodeAllocLimited(init.gpa, limit);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded,
    });
    try stdout.print("decoded_bytes={d} path={s}\n", .{
        decoded.len,
        output_path,
    });
}

pub fn decodeRange(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const offset = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    const length = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const archive = try vort.parseGcz(bytes, .{});
    const decoded = try archive.readRangeAllocLimited(
        init.gpa,
        offset,
        length,
        length,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded,
    });
    try stdout.print("offset={d} decoded_bytes={d} path={s}\n", .{
        offset,
        decoded.len,
        output_path,
    });
}

pub fn encode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const compression = try parseCompression(
        args.next() orelse return error.MissingCorpusPath,
    );
    const block_size = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 10)
    else
        128 * 1024;
    const level = if (args.next()) |text|
        try std.fmt.parseInt(u8, text, 10)
    else
        9;
    const sub_type = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 10)
    else
        0;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeGczAlloc(init.gpa, input, .{
        .compression = compression,
        .block_size = block_size,
        .compression_level = level,
        .sub_type = sub_type,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "compression={s} input_bytes={d} block_bytes={d} gcz_bytes={d} path={s}\n",
        .{
            @tagName(compression),
            input.len,
            block_size,
            encoded.len,
            output_path,
        },
    );
}

fn parseCompression(text: []const u8) !vort.GczCompression {
    inline for (std.enums.values(vort.GczCompression)) |compression|
        if (std.mem.eql(u8, text, @tagName(compression))) return compression;
    return error.InvalidGcz;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_local_file_size),
    );
}
