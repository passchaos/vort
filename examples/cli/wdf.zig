const std = @import("std");
const vort = @import("vort");

const max_file_size = 16 * 1024 * 1024 * 1024;

pub fn inspect(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    var archive = try vort.parseWdfAlloc(init.gpa, bytes, .{});
    defer archive.deinit();
    try stdout.print(
        "format=wdf version={d} physical_bytes={d} logical_bytes={d} data_bytes={d} chunks={d} alignment={d}\n",
        .{
            @intFromEnum(archive.header.version),
            archive.header.physical_size,
            archive.header.logical_size,
            archive.header.data_size,
            archive.header.chunk_count,
            archive.header.align_factor,
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
        try std.fmt.parseInt(usize, text, 0)
    else
        max_file_size;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    var archive = try vort.parseWdfAlloc(init.gpa, bytes, .{});
    defer archive.deinit();
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
        u64,
        args.next() orelse return error.MissingCorpusPath,
        0,
    );
    const length = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        0,
    );
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    var archive = try vort.parseWdfAlloc(init.gpa, bytes, .{});
    defer archive.deinit();
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
    const version_text = args.next() orelse "wdf2";
    const version: vort.WdfVersion = if (std.mem.eql(u8, version_text, "wdf1"))
        .v1
    else if (std.mem.eql(u8, version_text, "wdf2"))
        .v2
    else
        return error.UnsupportedVersion;
    const mode = args.next() orelse "sparse";
    const sparse = if (std.mem.eql(u8, mode, "sparse"))
        true
    else if (std.mem.eql(u8, mode, "full"))
        false
    else
        return error.InvalidWdf;
    const min_hole_size = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 0)
    else
        28;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeWdfAlloc(init.gpa, input, .{
        .version = version,
        .sparse_zeroes = sparse,
        .min_hole_size = min_hole_size,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "format=wdf version={d} input_bytes={d} sparse={} image_bytes={d} path={s}\n",
        .{
            @intFromEnum(version),
            input.len,
            sparse,
            encoded.len,
            output_path,
        },
    );
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_file_size),
    );
}
