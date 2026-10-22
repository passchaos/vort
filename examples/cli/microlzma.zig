const std = @import("std");
const vort = @import("vort");

pub fn encode(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const dictionary_size = try parseNumber(u32, args, 32 * 1024);
    const lc = try parseNumber(u4, args, 3);
    const lp = try parseNumber(u3, args, 0);
    const pb = try parseNumber(u3, args, 2);
    const mode: vort.LzmaEncodeMode = if (args.next()) |name|
        if (std.mem.eql(u8, name, "greedy")) .greedy else if (std.mem.eql(u8, name, "lazy")) .lazy else if (std.mem.eql(u8, name, "literal-only")) .literal_only else return error.InvalidLzmaOptions
    else
        .greedy;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
    defer init.gpa.free(input);
    const encoded = try vort.encodeMicroLzmaAlloc(init.gpa, input, .{
        .dictionary_size = dictionary_size,
        .properties = .{ .lc = lc, .lp = lp, .pb = pb },
        .mode = mode,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("input_bytes={d} microlzma_bytes={d} dictionary={d} path={s}\n", .{
        input.len, encoded.len, dictionary_size, output_path,
    });
}

pub fn decode(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const expected_size_text = args.next() orelse return error.MissingCorpusPath;
    const expected_size = try std.fmt.parseInt(usize, expected_size_text, 10);
    const dictionary_size = try parseNumber(u32, args, 8 * 1024 * 1024);
    const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(8 * 1024 * 1024));
    defer init.gpa.free(compressed);
    const decoded = try vort.decodeMicroLzmaAllocLimited(init.gpa, compressed, expected_size, dictionary_size, 12 * 1024 * 1024);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("microlzma_compressed_bytes={d} decoded_bytes={d} dictionary={d} path={s}\n", .{
        compressed.len, decoded.len, dictionary_size, output_path,
    });
}

fn parseNumber(comptime T: type, args: *std.process.Args.Iterator, default: T) !T {
    return if (args.next()) |value| try std.fmt.parseInt(T, value, 10) else default;
}
