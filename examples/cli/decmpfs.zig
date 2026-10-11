const std = @import("std");
const vort = @import("vort");

const max_file_size = 1024 * 1024 * 1024;

pub fn inspect(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const xattr_path = args.next() orelse return error.MissingCorpusPath;
    const resource_path = args.next();
    const xattr = try readFile(init, xattr_path);
    defer init.gpa.free(xattr);
    const resource = if (resource_path) |path|
        if (std.mem.eql(u8, path, "-")) null else try readFile(init, path)
    else
        null;
    defer if (resource) |bytes| init.gpa.free(bytes);
    const archive = try vort.parseDecmpfs(xattr, resource);
    try stdout.print("type={s} decoded_bytes={d} inline_bytes={d} resource={any}\n", .{
        @tagName(archive.header.compression_type),
        archive.header.uncompressed_size,
        archive.header.inline_payload.len,
        archive.resource != null,
    });
    if (archive.resource) |fork| {
        try stdout.print("layout={s} chunks={d} resource_bytes={d}\n", .{
            @tagName(fork.layout),
            fork.chunk_count,
            fork.bytes.len,
        });
        for (0..fork.chunk_count) |index| {
            const chunk = try fork.chunk(index);
            try stdout.print("chunk={d}\tstored={d}\tdecoded={d}\n", .{
                index,
                chunk.encoded.len,
                chunk.decoded_size,
            });
        }
    }
}

pub fn decode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const xattr_path = args.next() orelse return error.MissingCorpusPath;
    const resource_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const xattr = try readFile(init, xattr_path);
    defer init.gpa.free(xattr);
    const resource = if (std.mem.eql(u8, resource_path, "-"))
        null
    else
        try readFile(init, resource_path);
    defer if (resource) |bytes| init.gpa.free(bytes);
    const archive = try vort.parseDecmpfs(xattr, resource);
    const decoded = try archive.decodeAllocLimited(init.gpa, limit);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("type={s} decoded_bytes={d} path={s}\n", .{
        @tagName(archive.header.compression_type),
        decoded.len,
        output_path,
    });
}

pub fn decodeRange(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const xattr_path = args.next() orelse return error.MissingCorpusPath;
    const resource_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const offset = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const length = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const xattr = try readFile(init, xattr_path);
    defer init.gpa.free(xattr);
    const resource = if (std.mem.eql(u8, resource_path, "-"))
        null
    else
        try readFile(init, resource_path);
    defer if (resource) |bytes| init.gpa.free(bytes);
    const archive = try vort.parseDecmpfs(xattr, resource);
    const decoded = try archive.decodeRangeAllocLimited(
        init.gpa,
        offset,
        length,
        max_file_size,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("offset={d} decoded_bytes={d} path={s}\n", .{
        offset,
        decoded.len,
        output_path,
    });
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
