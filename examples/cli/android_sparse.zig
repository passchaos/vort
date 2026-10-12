const std = @import("std");
const vort = @import("vort");

const max_file_size = 32 * 1024 * 1024 * 1024;

pub fn inspect(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    var archive = try vort.parseAndroidSparseAlloc(init.gpa, bytes, .{});
    defer archive.deinit();
    var raw_chunks: usize = 0;
    var fill_chunks: usize = 0;
    var hole_chunks: usize = 0;
    for (archive.chunks) |chunk| switch (chunk.kind) {
        .raw => raw_chunks += 1,
        .fill => fill_chunks += 1,
        .dont_care => hole_chunks += 1,
        .crc32 => unreachable,
    };
    try stdout.print(
        "format=android-sparse version={d}.{d} physical_bytes={d} logical_bytes={d} block_bytes={d} chunks={d} raw={d} fill={d} dont_care={d} crc32={d} image_checksum=0x{x:0>8}\n",
        .{
            archive.header.major,
            archive.header.minor,
            archive.header.physical_size,
            archive.header.logical_size,
            archive.header.block_size,
            archive.header.total_chunks,
            raw_chunks,
            fill_chunks,
            hole_chunks,
            archive.header.total_chunks - archive.chunks.len,
            archive.header.image_checksum,
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
    var archive = try vort.parseAndroidSparseAlloc(init.gpa, bytes, .{});
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
    var archive = try vort.parseAndroidSparseAlloc(init.gpa, bytes, .{});
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
    const block_size = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 0)
    else
        4096;
    const sparse_zero_blocks = try parseToggle(
        args.next() orelse "sparse",
        "sparse",
        "store-zero",
    );
    const use_fill_chunks = try parseToggle(
        args.next() orelse "fill",
        "fill",
        "raw-fill",
    );
    const emit_crc32_chunk = try parseToggle(
        args.next() orelse "no-crc",
        "crc",
        "no-crc",
    );
    const write_image_checksum = try parseToggle(
        args.next() orelse "no-checksum",
        "checksum",
        "no-checksum",
    );
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeAndroidSparseAlloc(init.gpa, input, .{
        .block_size = block_size,
        .sparse_zero_blocks = sparse_zero_blocks,
        .use_fill_chunks = use_fill_chunks,
        .emit_crc32_chunk = emit_crc32_chunk,
        .write_image_checksum = write_image_checksum,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "format=android-sparse input_bytes={d} block_bytes={d} sparse={} fill={} crc32={} image_checksum={} image_bytes={d} path={s}\n",
        .{
            input.len,
            block_size,
            sparse_zero_blocks,
            use_fill_chunks,
            emit_crc32_chunk,
            write_image_checksum,
            encoded.len,
            output_path,
        },
    );
}

fn parseToggle(text: []const u8, enabled: []const u8, disabled: []const u8) !bool {
    if (std.mem.eql(u8, text, enabled)) return true;
    if (std.mem.eql(u8, text, disabled)) return false;
    return error.InvalidAndroidSparse;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_file_size),
    );
}
