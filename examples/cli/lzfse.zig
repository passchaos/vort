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
    const block_size = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        64 * 1024;
    const use_lzvn = if (args.next()) |mode|
        if (std.mem.eql(u8, mode, "lzvn")) true else if (std.mem.eql(u8, mode, "stored")) false else return error.InvalidBlockPlan
    else
        true;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeLzfseAlloc(init.gpa, input, .{
        .block_size = block_size,
        .use_lzvn = use_lzvn,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print(
        "lzfse_input_bytes={d} compressed_bytes={d} block_size={d} mode={s} path={s}\n",
        .{ input.len, encoded.len, block_size, if (use_lzvn) "lzvn" else "stored", output_path },
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
    const decoded = try vort.decodeLzfseAllocLimited(init.gpa, input, limit);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("lzfse_bytes={d} decoded_bytes={d} path={s}\n", .{
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
    const limit = try parseLimit(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseLzfseLimited(input, limit);
    var counts: [4]usize = @splat(0);
    var iterator = archive.iterator();
    while (try iterator.next()) |block| counts[@intFromEnum(block.kind)] += 1;
    try stdout.print(
        "lzfse_blocks={d} raw={d} lzvn={d} v1={d} v2={d} decoded_bytes={d} compressed_bytes={d}\n",
        .{
            archive.block_count,
            counts[@intFromEnum(vort.LzfseBlockKind.uncompressed)],
            counts[@intFromEnum(vort.LzfseBlockKind.lzvn)],
            counts[@intFromEnum(vort.LzfseBlockKind.compressed_v1)],
            counts[@intFromEnum(vort.LzfseBlockKind.compressed_v2)],
            archive.decoded_size,
            input.len,
        },
    );
}

fn parseLimit(value: ?[]const u8) !usize {
    return if (value) |text| try std.fmt.parseInt(usize, text, 10) else max_file_size;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
