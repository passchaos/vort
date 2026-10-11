const std = @import("std");
const vort = @import("vort");

const max_file_size = 1024 * 1024 * 1024;

pub fn inspect(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const algorithm = try parseAlgorithm(
        args.next() orelse return error.MissingCorpusPath,
    );
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    if (algorithm == .zstd) {
        const metadata = try vort.parseZfsZstdMetadata(input);
        try stdout.print(
            "algorithm=zstd packed_bytes={d} payload_bytes={d} level={d} version={d}\n",
            .{ input.len, metadata.compressed_size, metadata.level, metadata.version },
        );
    } else {
        try stdout.print("algorithm={s} packed_bytes={d}\n", .{
            @tagName(algorithm),
            input.len,
        });
    }
}

pub fn decode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const algorithm = try parseAlgorithm(
        args.next() orelse return error.MissingCorpusPath,
    );
    const decoded_size = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    if (decoded_size > max_file_size) return error.OutputLimitExceeded;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const decoded = try vort.decodeZfsBlockAllocExactSize(
        init.gpa,
        algorithm,
        input,
        decoded_size,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded,
    });
    try stdout.print("algorithm={s} decoded_bytes={d} path={s}\n", .{
        @tagName(algorithm),
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
    const algorithm = try parseAlgorithm(
        args.next() orelse return error.MissingCorpusPath,
    );
    const zstd_level = if (args.next()) |text|
        try std.fmt.parseInt(u8, text, 10)
    else
        3;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeZfsBlockAlloc(init.gpa, algorithm, input, .{
        .zstd_level = zstd_level,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print("algorithm={s} input_bytes={d} packed_bytes={d} path={s}\n", .{
        @tagName(algorithm),
        input.len,
        encoded.len,
        output_path,
    });
}

fn parseAlgorithm(text: []const u8) !vort.ZfsCompressionAlgorithm {
    inline for (std.enums.values(vort.ZfsCompressionAlgorithm)) |algorithm|
        if (std.mem.eql(u8, text, @tagName(algorithm))) return algorithm;
    return error.InvalidCompressionMode;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_file_size),
    );
}
