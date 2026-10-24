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
    var options = vort.LzfseOptions{};
    var positional: usize = 0;
    while (args.next()) |arg| {
        const hash = "--hash-log=";
        const distance = "--max-distance=";
        const memory = "--working-memory-limit=";
        const limit = "--output-limit=";
        const version = "--fse-version=";
        if (std.mem.startsWith(u8, arg, hash)) {
            options.hash_log = try std.fmt.parseInt(u8, arg[hash.len..], 10);
        } else if (std.mem.startsWith(u8, arg, distance)) {
            options.max_match_distance = try std.fmt.parseInt(usize, arg[distance.len..], 10);
        } else if (std.mem.startsWith(u8, arg, memory)) {
            options.max_working_memory = try std.fmt.parseInt(usize, arg[memory.len..], 10);
        } else if (std.mem.startsWith(u8, arg, limit)) {
            options.max_output_len = try std.fmt.parseInt(usize, arg[limit.len..], 10);
        } else if (std.mem.startsWith(u8, arg, version)) {
            const value = arg[version.len..];
            options.fse_version = if (std.mem.eql(u8, value, "v1")) .v1 else if (std.mem.eql(u8, value, "v2")) .v2 else return error.InvalidBlockPlan;
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.InvalidBlockPlan;
        } else {
            switch (positional) {
                0 => options.block_size = try std.fmt.parseInt(usize, arg, 10),
                1 => options.strategy = if (std.mem.eql(u8, arg, "auto")) .auto else if (std.mem.eql(u8, arg, "fse")) .fse else if (std.mem.eql(u8, arg, "lzvn")) .lzvn else if (std.mem.eql(u8, arg, "stored")) .stored else return error.InvalidBlockPlan,
                else => return error.InvalidBlockPlan,
            }
            positional += 1;
        }
    }
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    var encoded = try vort.encodeLzfseWithSummaryAlloc(init.gpa, input, options);
    defer encoded.deinit(init.gpa);
    var output = try std.Io.Dir.cwd().createFileAtomic(init.io, output_path, .{ .replace = true });
    defer output.deinit(init.io);
    var sink = vort.FileByteSink.init(init.io, output.file);
    try sink.sink().writeExact(0, encoded.bytes);
    try sink.sink().finish(encoded.bytes.len);
    try output.replace(init.io);
    try stdout.print(
        "lzfse_input_bytes={d} compressed_bytes={d} block_size={d} mode={s} v1={d} v2={d} peak_working_bytes={d} path={s}\n",
        .{ input.len, encoded.bytes.len, options.block_size, @tagName(options.effectiveStrategy()), encoded.summary.fse_v1_blocks, encoded.summary.fse_v2_blocks, encoded.peak_working_bytes, output_path },
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
