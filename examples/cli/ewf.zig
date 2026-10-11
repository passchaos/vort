const std = @import("std");
const vort = @import("vort");

const max_file_size = 1024 * 1024 * 1024;

pub fn inspect(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    var segments = try readSegments(init, args);
    defer freeSegments(init.gpa, &segments);
    var archive = try vort.parseEwfSegmentsAlloc(init.gpa, segments.items, .{});
    defer archive.deinit();
    try stdout.print(
        "segments={d} chunks={d} chunk_bytes={d} sector_bytes={d} media_bytes={d} md5={any}\n",
        .{
            archive.segment_count,
            archive.chunks.len,
            archive.geometry.chunk_size,
            archive.geometry.bytes_per_sector,
            archive.geometry.media_size,
            archive.expected_md5 != null,
        },
    );
}

pub fn decode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const first_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    var segments = try readSegmentsWithFirst(init, args, first_path);
    defer freeSegments(init.gpa, &segments);
    var archive = try vort.parseEwfSegmentsAlloc(init.gpa, segments.items, .{});
    defer archive.deinit();
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
    const first_path = args.next() orelse return error.MissingCorpusPath;
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
    var segments = try readSegmentsWithFirst(init, args, first_path);
    defer freeSegments(init.gpa, &segments);
    var archive = try vort.parseEwfSegmentsAlloc(init.gpa, segments.items, .{});
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
    const compression = try parseCompression(
        args.next() orelse return error.MissingCorpusPath,
    );
    const sectors_per_chunk = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 10)
    else
        64;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeEwfAlloc(init.gpa, input, .{
        .compression = compression,
        .sectors_per_chunk = sectors_per_chunk,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "compression={s} input_bytes={d} ewf_bytes={d} path={s}\n",
        .{ @tagName(compression), input.len, encoded.len, output_path },
    );
}

fn parseCompression(text: []const u8) !vort.EwfCompression {
    inline for (std.enums.values(vort.EwfCompression)) |compression|
        if (std.mem.eql(u8, text, @tagName(compression))) return compression;
    return error.InvalidCompressionMode;
}

fn readSegments(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
) !std.ArrayList([]u8) {
    const first = args.next() orelse return error.MissingCorpusPath;
    return readSegmentsWithFirst(init, args, first);
}

fn readSegmentsWithFirst(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    first: []const u8,
) !std.ArrayList([]u8) {
    var segments: std.ArrayList([]u8) = .empty;
    errdefer freeSegments(init.gpa, &segments);
    try segments.append(init.gpa, try readFile(init, first));
    while (args.next()) |path|
        try segments.append(init.gpa, try readFile(init, path));
    return segments;
}

fn freeSegments(allocator: std.mem.Allocator, segments: *std.ArrayList([]u8)) void {
    for (segments.items) |bytes| allocator.free(bytes);
    segments.deinit(allocator);
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_file_size),
    );
}
