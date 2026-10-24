const std = @import("std");
const vort = @import("vort");

const max_file_size: u64 = 16 * 1024 * 1024 * 1024;
// Complete-input CLI buffers stay addressable on narrow targets while the
// format and the native-target limit retain the established 16 GiB ceiling.
const max_local_file_size: usize = @intCast(@min(max_file_size, std.math.maxInt(usize)));

pub fn inspect(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const archive = try vort.parseCso(bytes, .{});
    var raw_blocks: usize = 0;
    var deflate_blocks: usize = 0;
    var lz4_blocks: usize = 0;
    for (0..archive.header.block_count) |block_index| {
        switch ((try archive.block(block_index)).codec) {
            .raw => raw_blocks += 1,
            .deflate => deflate_blocks += 1,
            .lz4 => lz4_blocks += 1,
        }
    }
    try stdout.print(
        "format={s} logical_bytes={d} block_bytes={d} blocks={d} index_shift={d} raw={d} deflate={d} lz4={d}\n",
        .{
            @tagName(archive.header.format),
            archive.header.uncompressed_size,
            archive.header.block_size,
            archive.header.block_count,
            archive.header.index_shift,
            raw_blocks,
            deflate_blocks,
            lz4_blocks,
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
    const archive = try vort.parseCso(bytes, .{});
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
    const archive = try vort.parseCso(bytes, .{});
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
    const image_format = try parseEnum(
        vort.CsoFormat,
        args.next() orelse return error.MissingCorpusPath,
    );
    const compression = if (args.next()) |text|
        try parseEnum(vort.CsoCompression, text)
    else
        .auto;
    const block_size = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 10)
    else
        2048;
    const level = if (args.next()) |text|
        try std.fmt.parseInt(u8, text, 10)
    else
        6;
    const index_shift = if (args.next()) |text|
        try std.fmt.parseInt(u8, text, 10)
    else
        null;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeCsoAlloc(init.gpa, input, .{
        .format = image_format,
        .compression = compression,
        .block_size = block_size,
        .compression_level = level,
        .index_shift = index_shift,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "format={s} compression={s} input_bytes={d} block_bytes={d} cso_bytes={d} path={s}\n",
        .{
            @tagName(image_format),
            @tagName(compression),
            input.len,
            block_size,
            encoded.len,
            output_path,
        },
    );
}

fn parseEnum(comptime T: type, text: []const u8) !T {
    inline for (std.enums.values(T)) |value|
        if (std.mem.eql(u8, text, @tagName(value))) return value;
    return error.InvalidCso;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_local_file_size),
    );
}
