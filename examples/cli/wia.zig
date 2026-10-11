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
    var archive = try vort.parseWiaAlloc(init.gpa, bytes, .{});
    defer archive.deinit();
    var zero_groups: usize = 0;
    var compressed_groups: usize = 0;
    var packed_groups: usize = 0;
    for (archive.groups) |group| {
        if (group.stored_size == 0)
            zero_groups += 1
        else if (group.compressed)
            compressed_groups += 1;
        if (group.rvz_packed_size != 0) packed_groups += 1;
    }
    try stdout.print(
        "format={s} logical_bytes={d} compression={s} level={d} chunk_bytes={d} partitions={d} raw_entries={d} groups={d} compressed={d} packed={d} zero={d}\n",
        .{
            @tagName(archive.header1.container),
            archive.header1.logical_size,
            @tagName(archive.header2.compression),
            archive.header2.compression_level,
            archive.header2.chunk_size,
            archive.header2.partition_count,
            archive.raw_entries.len,
            archive.groups.len,
            compressed_groups,
            packed_groups,
            zero_groups,
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
    var archive = try vort.parseWiaAlloc(init.gpa, bytes, .{});
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
    var archive = try vort.parseWiaAlloc(init.gpa, bytes, .{});
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

pub fn encodeWia(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    return encode(init, args, stdout, .wia);
}

pub fn encodeRvz(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    return encode(init, args, stdout, .rvz);
}

pub fn encodeWiaPartition(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    return encodePartition(init, args, stdout, .wia);
}

pub fn encodeRvzPartition(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    return encodePartition(init, args, stdout, .rvz);
}

pub fn encodeWiaDisc(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    return encodeDisc(init, args, stdout, .wia);
}

pub fn encodeRvzDisc(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    return encodeDisc(init, args, stdout, .rvz);
}

fn encode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
    container: vort.WiaContainer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const compression = try parseCompression(
        args.next() orelse return error.MissingCorpusPath,
    );
    const chunk_size: u32 = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 10)
    else if (container == .wia)
        2 * 1024 * 1024
    else
        128 * 1024;
    const level: i32 = if (args.next()) |text|
        try std.fmt.parseInt(i32, text, 10)
    else if (compression == .zstd)
        5
    else
        6;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeWiaAlloc(init.gpa, input, .{
        .container = container,
        .compression = compression,
        .chunk_size = chunk_size,
        .compression_level = level,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "format={s} compression={s} input_bytes={d} chunk_bytes={d} image_bytes={d} path={s}\n",
        .{
            @tagName(container),
            @tagName(compression),
            input.len,
            chunk_size,
            encoded.len,
            output_path,
        },
    );
}

fn encodePartition(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
    container: vort.WiaContainer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const compression = try parseCompression(
        args.next() orelse return error.MissingCorpusPath,
    );
    const partition_offset = try std.fmt.parseInt(
        u64,
        args.next() orelse return error.MissingCorpusPath,
        0,
    );
    const partition_size = try std.fmt.parseInt(
        u64,
        args.next() orelse return error.MissingCorpusPath,
        0,
    );
    const key = try parseKey(
        args.next() orelse return error.MissingCorpusPath,
    );
    const chunk_size: u32 = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 10)
    else if (container == .wia)
        2 * 1024 * 1024
    else
        128 * 1024;
    const level: i32 = if (args.next()) |text|
        try std.fmt.parseInt(i32, text, 10)
    else if (compression == .zstd)
        5
    else
        6;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeWiaWithPartitionsAlloc(
        init.gpa,
        input,
        &.{.{
            .key = key,
            .data = .{
                .{ .offset = partition_offset, .size = partition_size },
                .{ .offset = 0, .size = 0 },
            },
        }},
        .{
            .container = container,
            .compression = compression,
            .chunk_size = chunk_size,
            .compression_level = level,
        },
    );
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "format={s} compression={s} partitions=1 input_bytes={d} chunk_bytes={d} image_bytes={d} path={s}\n",
        .{
            @tagName(container),
            @tagName(compression),
            input.len,
            chunk_size,
            encoded.len,
            output_path,
        },
    );
}

fn encodeDisc(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
    container: vort.WiaContainer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const compression = try parseCompression(
        args.next() orelse return error.MissingCorpusPath,
    );
    const common_key_index = try std.fmt.parseInt(
        u8,
        args.next() orelse return error.MissingCorpusPath,
        0,
    );
    const common_key = try parseKey(
        args.next() orelse return error.MissingCorpusPath,
    );
    const chunk_size: u32 = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 10)
    else if (container == .wia)
        2 * 1024 * 1024
    else
        128 * 1024;
    const level: i32 = if (args.next()) |text|
        try std.fmt.parseInt(i32, text, 10)
    else if (compression == .zstd)
        5
    else
        6;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeWiaDiscAlloc(
        init.gpa,
        input,
        &.{.{ .index = common_key_index, .key = common_key }},
        .{
            .container = container,
            .compression = compression,
            .chunk_size = chunk_size,
            .compression_level = level,
        },
    );
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "format={s} compression={s} partitions=auto input_bytes={d} chunk_bytes={d} image_bytes={d} path={s}\n",
        .{
            @tagName(container),
            @tagName(compression),
            input.len,
            chunk_size,
            encoded.len,
            output_path,
        },
    );
}

fn parseKey(text: []const u8) ![16]u8 {
    if (text.len != 32) return error.InvalidWia;
    var key: [16]u8 = undefined;
    _ = std.fmt.hexToBytes(&key, text) catch return error.InvalidWia;
    return key;
}

fn parseCompression(text: []const u8) !vort.WiaCompression {
    inline for (std.enums.values(vort.WiaCompression)) |compression|
        if (std.mem.eql(u8, text, @tagName(compression))) return compression;
    return error.UnsupportedWiaCodec;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_file_size),
    );
}
