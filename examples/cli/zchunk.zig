const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;

pub fn encode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const chunk_size = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        64 * 1024;
    const compression: vort.ZchunkCompression = if (args.next()) |name|
        if (std.mem.eql(u8, name, "zstd")) .zstandard else if (std.mem.eql(u8, name, "none")) .none else return error.InvalidBlockPlan
    else
        .zstandard;
    const source_hashes = if (args.next()) |mode|
        if (std.mem.eql(u8, mode, "source-hashes")) true else if (std.mem.eql(u8, mode, "normal")) false else return error.InvalidBlockPlan
    else
        false;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeZchunkAlloc(init.gpa, input, .{
        .compression = compression,
        .chunk_size = chunk_size,
        .chunk_hash_kind = if (source_hashes) .sha256 else .sha512_128,
        .uncompressed_source = source_hashes,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print(
        "zchunk_input_bytes={d} zchunk_bytes={d} chunk_size={d} compression={s} source_hashes={} path={s}\n",
        .{ input.len, encoded.len, chunk_size, @tagName(compression), source_hashes, output_path },
    );
}

pub fn decode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = try parseLimit(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const decoded = try vort.decodeZchunkAllocLimited(init.gpa, input, limit);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("zchunk_bytes={d} decoded_bytes={d} path={s}\n", .{
        input.len,
        decoded.len,
        output_path,
    });
}

pub fn inspect(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseZchunkHeader(input);
    try stdout.print(
        "zchunk_chunks={d} decoded_bytes={d} body_bytes={d} header_bytes={d} compression={s} full_hash={s} chunk_hash={s} detached={} body_present={}\n",
        .{
            archive.entry_count,
            archive.decoded_size,
            archive.body_size,
            archive.header_size,
            @tagName(archive.compression),
            @tagName(archive.full_hash_kind),
            @tagName(archive.chunk_hash_kind),
            archive.detached,
            archive.body_present,
        },
    );
    var iterator = try archive.iterator();
    while (try iterator.next()) |entry| {
        try stdout.print(
            "chunk={d} stream={d} offset={d} compressed={d} decoded={d} dictionary={} stored={}\n",
            .{
                entry.number,
                entry.stream_id,
                entry.body_offset,
                entry.compressed_size,
                entry.decoded_size,
                entry.dictionary,
                entry.stored,
            },
        );
    }
}

pub fn extractChunk(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const number = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = try parseLimit(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const decoded = try vort.decodeZchunkChunkAllocLimited(init.gpa, input, number, limit);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("chunk={d} decoded_bytes={d} path={s}\n", .{
        number,
        decoded.len,
        output_path,
    });
}

fn parseLimit(value: ?[]const u8) !usize {
    return if (value) |text| try std.fmt.parseInt(usize, text, 10) else max_file_size;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
