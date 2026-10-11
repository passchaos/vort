const std = @import("std");
const vort = @import("vort");

const max_file_size = 1024 * 1024 * 1024;

pub fn inspect(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try readFile(init, path);
    defer init.gpa.free(bytes);
    const archive = try vort.parsePbzxWithOptions(bytes, .{
        .max_output_len = max_file_size,
    });
    try stdout.print("chunk_size={d} chunks={d} decoded_bytes={d}\n", .{
        archive.chunk_size,
        archive.chunk_count,
        archive.decoded_size,
    });
    var iterator = archive.iterator();
    while (try iterator.next()) |chunk| {
        try stdout.print(
            "chunk={d}\toffset={d}\tdecoded={d}\tpacked={d}\tstored={any}\n",
            .{
                chunk.index,
                chunk.decoded_offset,
                chunk.decoded_size,
                chunk.packed_size,
                chunk.isStored(),
            },
        );
    }
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
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const archive = try vort.parsePbzxWithOptions(bytes, .{
        .max_output_len = limit,
    });
    const decoded = try archive.decodeAllocLimited(init.gpa, limit);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded,
    });
    try stdout.print("decoded_bytes={d} path={s}\n", .{ decoded.len, output_path });
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
    const archive = try vort.parsePbzxWithOptions(bytes, .{
        .max_output_len = max_file_size,
    });
    const decoded = try archive.decodeRangeAllocLimited(
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
    const chunk_size = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        16 * 1024 * 1024;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodePbzxAlloc(init.gpa, input, .{
        .chunk_size = chunk_size,
        .compression = compression,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print("compression={s} input_bytes={d} pbzx_bytes={d} path={s}\n", .{
        @tagName(compression),
        input.len,
        encoded.len,
        output_path,
    });
}

fn parseCompression(text: []const u8) !vort.PbzxCompression {
    inline for (std.enums.values(vort.PbzxCompression)) |compression|
        if (std.mem.eql(u8, text, @tagName(compression))) return compression;
    return error.InvalidCompressionMode;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_file_size),
    );
}
