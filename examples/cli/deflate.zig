const std = @import("std");
const vort = @import("vort");
const stream_files = @import("stream_files.zig");
const decode_stdio = @import("decode_stdio.zig");

pub fn isGzipDecodeFileCommand(command: []const u8) bool {
    return std.mem.eql(u8, command, "decode-gzip-file") or std.mem.eql(u8, command, "decode-gzip-concat-file");
}

pub fn decodeGzipFile(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = args.next();
    if (decode_stdio.isStdio(input_path) or decode_stdio.isStdio(output_path)) {
        var history: [vort.lz77.default_window_len]u8 = undefined;
        var decoder = try vort.GzipIncrementalDecoder.init(.{
            .allow_concatenated = true,
            .max_output_len = if (limit) |value| try std.fmt.parseInt(vort.StreamCount, value, 10) else std.math.maxInt(vort.StreamCount),
        }, &history);
        return decode_stdio.decode(init.io, input_path, output_path, &decoder);
    }

    const max_output_len = if (limit) |value| try std.fmt.parseInt(usize, value, 10) else null;
    const dir = std.Io.Dir.cwd();
    const compressed = try dir.readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(compressed);
    const decoded = if (max_output_len) |max|
        try vort.decodeGzipConcatenatedAllocLimited(init.gpa, compressed, max)
    else
        try vort.decodeGzipConcatenatedAlloc(init.gpa, compressed);
    defer init.gpa.free(decoded);
    try dir.writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
}

pub fn encodeGzipBestFile(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    var level: ?[]const u8 = null;
    var rsyncable = false;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--rsyncable")) {
            if (rsyncable) return error.DuplicateGzipOption;
            rsyncable = true;
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownGzipOption;
        } else {
            if (level != null) return error.UnexpectedArgument;
            level = arg;
        }
    }
    const options = parseCompressionOptions(level);
    const dir = std.Io.Dir.cwd();
    if (rsyncable) {
        const totals = try encodeGzipRsyncable(init, dir, input_path, output_path, options);
        try stdout.print("input_bytes={d} output_bytes={d} path={s}\n", .{ totals.input_read, totals.output_written, output_path });
    } else {
        const data = try dir.readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const encoded = try vort.encodeGzipBestAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try dir.writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} output_bytes={d} path={s}\n", .{ data.len, encoded.len, output_path });
    }
}

fn encodeGzipRsyncable(init: std.process.Init, dir: std.Io.Dir, input_path: []const u8, output_path: []const u8, options: vort.CompressionOptions) !stream_files.Totals {
    const input_file = try dir.openFile(init.io, input_path, .{});
    var input_open = true;
    defer if (input_open) input_file.close(init.io);
    var atomic = try dir.createFileAtomic(init.io, output_path, .{ .replace = true });
    defer atomic.deinit(init.io);
    var buffer: [32 * 1024]u8 = undefined;
    var writer = atomic.file.writerStreaming(init.io, &buffer);
    var encoder = vort.GzipIncrementalBestEncoder.initWithOptions(init.gpa, .{ .raw = .{
        .compression = options,
        .rsyncable = true,
    } });
    defer encoder.deinit();
    const totals = try stream_files.pump(init, input_file, &writer.interface, &encoder, null, null);
    input_file.close(init.io);
    input_open = false;
    try writer.interface.flush();
    try atomic.replace(init.io);
    return totals;
}

pub fn parseCompressionOptions(text: ?[]const u8) vort.CompressionOptions {
    const value = text orelse return vort.optionsForCompressionLevel(.default);
    if (std.mem.eql(u8, value, "fastest")) return vort.optionsForCompressionLevel(.fastest);
    if (std.mem.eql(u8, value, "fast")) return vort.optionsForCompressionLevel(.fast);
    if (std.mem.eql(u8, value, "hash")) return .{ .parser = .hash };
    if (std.mem.eql(u8, value, "default")) return vort.optionsForCompressionLevel(.default);
    if (std.mem.eql(u8, value, "best")) return vort.optionsForCompressionLevel(.best);
    if (std.mem.eql(u8, value, "filtered")) return .{ .strategy = .filtered };
    if (std.mem.eql(u8, value, "huffman") or std.mem.eql(u8, value, "huffman-only")) return .{ .strategy = .huffman_only };
    if (std.mem.eql(u8, value, "rle")) return .{ .strategy = .rle };
    if (std.mem.eql(u8, value, "greedy")) return .{ .parser = .greedy };
    if (std.mem.eql(u8, value, "lazy")) return .{ .parser = .lazy };
    if (std.mem.eql(u8, value, "optimal")) return .{ .parser = .optimal };
    return vort.optionsForCompressionLevel(.default);
}
