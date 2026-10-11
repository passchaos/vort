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
    const archive = try vort.parseQcow2(bytes, .{});
    const header = archive.header;
    try stdout.print(
        "version={d} virtual_bytes={d} cluster_bytes={d} l1_entries={d} compression={s} extended_l2={any} backing={s}\n",
        .{
            header.version,
            header.virtual_size,
            header.cluster_size,
            header.l1_size,
            @tagName(header.compression_type),
            header.hasExtendedL2(),
            header.backing_file_name,
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
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const backing = try readOptionalFile(init, args.next());
    defer if (backing) |bytes| init.gpa.free(bytes);
    const data_file = try readOptionalFile(init, args.next());
    defer if (data_file) |bytes| init.gpa.free(bytes);
    const archive = try vort.parseQcow2(input, .{
        .backing_file = backing,
        .external_data_file = data_file,
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
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const backing = try readOptionalFile(init, args.next());
    defer if (backing) |bytes| init.gpa.free(bytes);
    const data_file = try readOptionalFile(init, args.next());
    defer if (data_file) |bytes| init.gpa.free(bytes);
    const archive = try vort.parseQcow2(input, .{
        .backing_file = backing,
        .external_data_file = data_file,
    });
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
    const cluster_bits = if (args.next()) |text|
        try std.fmt.parseInt(u5, text, 10)
    else
        16;
    const version = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 10)
    else
        3;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeQcow2Alloc(init.gpa, input, .{
        .version = version,
        .cluster_bits = cluster_bits,
        .compression = compression,
    });
    defer init.gpa.free(encoded);
    const header = try vort.parseQcow2Header(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "version={d} compression={s} input_bytes={d} virtual_bytes={d} qcow2_bytes={d} path={s}\n",
        .{
            version,
            @tagName(compression),
            input.len,
            header.virtual_size,
            encoded.len,
            output_path,
        },
    );
}

fn parseCompression(text: []const u8) !vort.Qcow2Compression {
    inline for (std.enums.values(vort.Qcow2Compression)) |compression|
        if (std.mem.eql(u8, text, @tagName(compression))) return compression;
    return error.InvalidCompressionMode;
}

fn readOptionalFile(init: std.process.Init, path: ?[]const u8) !?[]u8 {
    const value = path orelse return null;
    if (std.mem.eql(u8, value, "-")) return null;
    return try readFile(init, value);
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_file_size),
    );
}
