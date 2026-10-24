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
    var options = vort.LzmsEncodeOptions{};
    while (args.next()) |arg| {
        const strategy = "--strategy=";
        const hash = "--hash-log=";
        const distance = "--max-distance=";
        const memory = "--working-memory-limit=";
        const limit = "--output-limit=";
        if (std.mem.startsWith(u8, arg, strategy)) {
            const value = arg[strategy.len..];
            options.strategy = if (std.mem.eql(u8, value, "greedy")) .greedy else if (std.mem.eql(u8, value, "literals")) .literals else return error.InvalidLzms;
        } else if (std.mem.eql(u8, arg, "--no-delta")) {
            options.enable_delta = false;
        } else if (std.mem.startsWith(u8, arg, hash)) {
            options.hash_log = try std.fmt.parseInt(u8, arg[hash.len..], 10);
        } else if (std.mem.startsWith(u8, arg, distance)) {
            options.max_match_distance = try std.fmt.parseInt(usize, arg[distance.len..], 10);
        } else if (std.mem.startsWith(u8, arg, memory)) {
            options.max_working_memory = try std.fmt.parseInt(usize, arg[memory.len..], 10);
        } else if (std.mem.startsWith(u8, arg, limit)) {
            options.max_output_len = try std.fmt.parseInt(usize, arg[limit.len..], 10);
        } else return error.InvalidLzms;
    }
    const input = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        input_path,
        init.gpa,
        .limited(max_file_size),
    );
    defer init.gpa.free(input);
    var encoded = try vort.encodeLzmsWithSummaryAlloc(init.gpa, input, options);
    defer encoded.deinit(init.gpa);
    var output = try std.Io.Dir.cwd().createFileAtomic(init.io, output_path, .{ .replace = true });
    defer output.deinit(init.io);
    var sink = vort.FileByteSink.init(init.io, output.file);
    try sink.sink().writeExact(0, encoded.bytes);
    try sink.sink().finish(encoded.bytes.len);
    try output.replace(init.io);
    try stdout.print("decoded_bytes={d} lzms_bytes={d} strategy={s} lz_matches={d} delta_matches={d} peak_working_bytes={d} path={s}\n", .{
        input.len,
        encoded.bytes.len,
        @tagName(options.strategy),
        encoded.summary.lz_matches,
        encoded.summary.delta_matches,
        encoded.peak_working_bytes,
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
    const decoded_size_text = args.next() orelse return error.MissingCorpusPath;
    const decoded_size = try std.fmt.parseInt(usize, decoded_size_text, 10);
    const input = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        input_path,
        init.gpa,
        .limited(max_file_size),
    );
    defer init.gpa.free(input);
    const decoded = try vort.decodeLzmsAllocLimited(
        init.gpa,
        input,
        decoded_size,
        max_file_size,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded,
    });
    try stdout.print("lzms_bytes={d} decoded_bytes={d} path={s}\n", .{
        input.len,
        decoded.len,
        output_path,
    });
}
