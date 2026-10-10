const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;

pub fn createIndex(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const owned_output: ?[]u8 = if (args.next()) |path|
        try init.gpa.dupe(u8, path)
    else
        try std.fmt.allocPrint(init.gpa, "{s}.index", .{input_path});
    defer init.gpa.free(owned_output.?);
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const index = try vort.generateHadoopLzoIndexAlloc(init.gpa, input);
    defer init.gpa.free(index);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = owned_output.?, .data = index });
    try stdout.print("lzo_blocks={d} index_bytes={d} path={s}\n", .{
        index.len / 8,
        index.len,
        owned_output.?,
    });
}

pub fn inspectIndex(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const index_path = args.next() orelse return error.MissingCorpusPath;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const index_bytes = try readFile(init, index_path);
    defer init.gpa.free(index_bytes);
    const index = try vort.validateHadoopLzoIndex(input, index_bytes);
    try stdout.print("lzo_blocks={d} lzo_bytes={d} index_bytes={d}\n", .{
        index.block_count,
        input.len,
        index_bytes.len,
    });
    for (0..index.block_count) |block|
        try stdout.print("index={d} compressed_offset={d}\n", .{
            block,
            try index.offsetAt(block),
        });
}

pub fn extractBlocks(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const index_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const first = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const count = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const limit = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else max_file_size;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const index = try readFile(init, index_path);
    defer init.gpa.free(index);
    const decoded = try vort.decodeHadoopLzoBlockRangeAlloc(
        init.gpa,
        input,
        index,
        first,
        count,
        limit,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("first_block={d} block_count={d} decoded_bytes={d} path={s}\n", .{
        first,
        count,
        decoded.len,
        output_path,
    });
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
