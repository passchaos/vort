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
    var archive = try vort.parseWbfsAlloc(init.gpa, bytes, .{});
    defer archive.deinit();
    var stored_clusters: usize = 0;
    for (archive.wlba_table) |mapping|
        stored_clusters += @intFromBool(mapping != 0);
    try stdout.print(
        "format=wbfs physical_bytes={d} logical_bytes={d} hd_sector_bytes={d} wbfs_sector_bytes={d} disc_slot={d} blocks={d} stored={d}\n",
        .{
            archive.physical_size,
            vort.wbfsLogicalSize,
            archive.header.hd_sector_size,
            archive.header.wbfs_sector_size,
            archive.header.disc_slot,
            archive.header.blocks_per_disc,
            stored_clusters,
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
        max_file_size;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    var archive = try vort.parseWbfsAlloc(init.gpa, bytes, .{});
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
    var archive = try vort.parseWbfsAlloc(init.gpa, bytes, .{});
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
    const sector_size: u32 = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 0)
    else
        2 * 1024 * 1024;
    if (sector_size < 0x8000 or !std.math.isPowerOfTwo(sector_size))
        return error.InvalidWbfs;
    const mode = args.next() orelse "sparse";
    const sparse = if (std.mem.eql(u8, mode, "sparse"))
        true
    else if (std.mem.eql(u8, mode, "full"))
        false
    else
        return error.InvalidWbfs;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeWbfsAlloc(init.gpa, input, .{
        .wbfs_sector_shift = @intCast(@ctz(sector_size)),
        .sparse_zero_clusters = sparse,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "format=wbfs input_bytes={d} sector_bytes={d} sparse={} image_bytes={d} path={s}\n",
        .{ input.len, sector_size, sparse, encoded.len, output_path },
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
