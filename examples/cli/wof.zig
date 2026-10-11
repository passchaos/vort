const std = @import("std");
const vort = @import("vort");

const max_file_size = 1024 * 1024 * 1024;

pub fn encode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const algorithm = parseAlgorithm(args.next() orelse return error.MissingCorpusPath) orelse
        return error.InvalidBlockPlan;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeWofAlloc(init.gpa, input, algorithm);
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("algorithm={s} input_bytes={d} wof_bytes={d} path={s}\n", .{
        @tagName(algorithm),
        input.len,
        encoded.len,
        output_path,
    });
}

pub fn decode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const algorithm = parseAlgorithm(args.next() orelse return error.MissingCorpusPath) orelse
        return error.InvalidBlockPlan;
    const size = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const backing = try vort.parseWofBacking(input, algorithm, size);
    const decoded = try vort.decodeWofAllocLimited(init.gpa, backing, limit);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("algorithm={s} wof_bytes={d} decoded_bytes={d} path={s}\n", .{
        @tagName(algorithm),
        input.len,
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
    const algorithm = parseAlgorithm(args.next() orelse return error.MissingCorpusPath) orelse
        return error.InvalidBlockPlan;
    const size = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
    const offset = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const length = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const backing = try vort.parseWofBacking(input, algorithm, size);
    const decoded = try vort.decodeWofRangeAllocLimited(
        init.gpa,
        backing,
        offset,
        length,
        length,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("offset={d} decoded_bytes={d} path={s}\n", .{
        offset,
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
    const algorithm = parseAlgorithm(args.next() orelse return error.MissingCorpusPath) orelse
        return error.InvalidBlockPlan;
    const size = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const backing = try vort.parseWofBacking(input, algorithm, size);
    try stdout.print(
        "algorithm={s} decoded_bytes={d} stored_bytes={d} chunk_size={d} chunks={d} entry_size={d}\n",
        .{
            @tagName(algorithm),
            backing.uncompressed_size,
            input.len,
            backing.chunk_size,
            backing.chunk_count,
            backing.entry_size,
        },
    );
    for (0..backing.chunk_count) |index| {
        const chunk = try backing.chunk(index);
        try stdout.print("chunk={d}\tstored={d}\tdecoded={d}\traw={any}\n", .{
            index,
            chunk.encoded.len,
            chunk.decoded_size,
            chunk.isStored(),
        });
    }
}

fn parseAlgorithm(text: []const u8) ?vort.WofAlgorithm {
    if (std.mem.eql(u8, text, "xpress4k")) return .xpress4k;
    if (std.mem.eql(u8, text, "xpress8k")) return .xpress8k;
    if (std.mem.eql(u8, text, "xpress16k")) return .xpress16k;
    if (std.mem.eql(u8, text, "lzx")) return .lzx;
    return null;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
