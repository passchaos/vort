const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;

pub fn encodeFile(
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
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeBgzfAlloc(init.gpa, input, .{ .block_size = block_size });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("bgzf_input_bytes={d} bgzf_bytes={d} block_size={d} path={s}\n", .{
        input.len,
        encoded.len,
        block_size,
        output_path,
    });
}

pub fn decodeFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output_len = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const decoded = try vort.decodeBgzfAllocLimited(init.gpa, input, max_output_len);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("bgzf_bytes={d} decoded_bytes={d} path={s}\n", .{
        input.len,
        decoded.len,
        output_path,
    });
}

pub fn inspectFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseBgzf(input);
    try stdout.print("bgzf_blocks={d} decoded_bytes={d} eof={} compressed_bytes={d}\n", .{
        archive.block_count,
        archive.decoded_size,
        archive.has_eof,
        input.len,
    });
    var iterator_value = archive.iterator();
    var index: usize = 0;
    while (try iterator_value.next()) |block| : (index += 1) {
        const virtual = try (vort.BgzfVirtualOffset{
            .compressed_offset = block.offset,
            .uncompressed_offset = 0,
        }).pack();
        try stdout.print(
            "index={d} compressed_offset={d} compressed_size={d} uncompressed_size={d} virtual_offset={d} eof={}\n",
            .{
                index,
                block.offset,
                block.total_size,
                block.uncompressed_size,
                virtual,
                block.is_eof,
            },
        );
    }
}

pub fn decodeRange(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const start = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
    const end = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
    const max_output_len = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const decoded = try vort.decodeBgzfRangeAlloc(init.gpa, input, start, end, max_output_len);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("bgzf_range_start={d} end={d} decoded_bytes={d} path={s}\n", .{
        start,
        end,
        decoded.len,
        output_path,
    });
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
