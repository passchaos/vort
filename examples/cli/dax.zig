const std = @import("std");
const vort = @import("vort");

const max_file_size: u64 = 5 * 1024 * 1024 * 1024;
const max_local_file_size: usize = @intCast(@min(max_file_size, std.math.maxInt(usize)));

pub fn inspect(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const archive = try vort.parseDax(bytes, .{});
    var raw_frames: usize = 0;
    for (0..archive.header.frame_count) |frame_index|
        if ((try archive.frame(frame_index)).raw) {
            raw_frames += 1;
        };
    try stdout.print(
        "version={d} logical_bytes={d} frame_bytes=8192 frames={d} nc_areas={d} raw={d} zlib={d}\n",
        .{
            archive.header.version,
            archive.header.uncompressed_size,
            archive.header.frame_count,
            archive.header.nc_area_count,
            raw_frames,
            archive.header.frame_count - raw_frames,
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
    const archive = try vort.parseDax(bytes, .{});
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
    const archive = try vort.parseDax(bytes, .{});
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
    const compression = if (args.next()) |text|
        try parseCompression(text)
    else
        .auto;
    const level = if (args.next()) |text|
        try std.fmt.parseInt(u8, text, 10)
    else
        6;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeDaxAlloc(init.gpa, input, .{
        .compression = compression,
        .compression_level = level,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "compression={s} input_bytes={d} frame_bytes=8192 dax_bytes={d} path={s}\n",
        .{
            @tagName(compression),
            input.len,
            encoded.len,
            output_path,
        },
    );
}

fn parseCompression(text: []const u8) !vort.DaxCompression {
    inline for (std.enums.values(vort.DaxCompression)) |compression|
        if (std.mem.eql(u8, text, @tagName(compression))) return compression;
    return error.InvalidDax;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_local_file_size),
    );
}
