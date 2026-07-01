const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var markdown_path: ?[]const u8 = null;
    var paths: std.ArrayList([]const u8) = .empty;
    defer paths.deinit(init.gpa);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--markdown")) {
            markdown_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        try paths.append(init.gpa, arg);
    }
    if (paths.items.len == 0) return error.MissingCorpusPath;

    var rows: std.ArrayList(ReportRow) = .empty;
    defer rows.deinit(init.gpa);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("path,input_bytes,best_deflate_bytes,best_ratio,encode_mib_s,decode_mib_s\n", .{});

    for (paths.items) |path| {
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);

        const encode_start = std.Io.Clock.awake.now(init.io);
        const encoded = try vort.encodeRawBestAlloc(init.gpa, data, vort.optionsForCompressionLevel(.fastest));
        const encode_elapsed = encode_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        defer init.gpa.free(encoded);

        const decode_start = std.Io.Clock.awake.now(init.io);
        const decoded = try vort.decodeRawDeflateAlloc(init.gpa, encoded);
        const decode_elapsed = decode_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, data, decoded)) return error.RoundTripMismatch;

        const ratio = if (data.len == 0) 0.0 else @as(f64, @floatFromInt(encoded.len)) / @as(f64, @floatFromInt(data.len));
        const mib = @as(f64, @floatFromInt(data.len)) / (1024.0 * 1024.0);
        const encode_s = @as(f64, @floatFromInt(encode_elapsed)) / @as(f64, std.time.ns_per_s);
        const decode_s = @as(f64, @floatFromInt(decode_elapsed)) / @as(f64, std.time.ns_per_s);
        const encode_mib_s = if (encode_s == 0) 0 else mib / encode_s;
        const decode_mib_s = if (decode_s == 0) 0 else mib / decode_s;
        try rows.append(init.gpa, .{ .path = path, .input_bytes = data.len, .encoded_bytes = encoded.len, .ratio = ratio, .encode_mib_s = encode_mib_s, .decode_mib_s = decode_mib_s });
        try stdout.print("{s},{d},{d},{d:.4},{d:.2},{d:.2}\n", .{ path, data.len, encoded.len, ratio, encode_mib_s, decode_mib_s });
    }
    try stdout.flush();
    if (markdown_path) |path| try writeMarkdown(init, path, rows.items);
}

const ReportRow = struct {
    path: []const u8,
    input_bytes: usize,
    encoded_bytes: usize,
    ratio: f64,
    encode_mib_s: f64,
    decode_mib_s: f64,
};

fn writeMarkdown(init: std.process.Init, path: []const u8, rows: []const ReportRow) !void {
    var writer = std.Io.Writer.Allocating.init(init.gpa);
    defer writer.deinit();
    const w = &writer.writer;
    var total_input: usize = 0;
    var total_encoded: usize = 0;
    for (rows) |row| {
        total_input += row.input_bytes;
        total_encoded += row.encoded_bytes;
    }
    const total_ratio = if (total_input == 0) 0.0 else @as(f64, @floatFromInt(total_encoded)) / @as(f64, @floatFromInt(total_input));
    try w.print("# File corpus report\n\n", .{});
    try w.print("- rows: {d}\n- total input bytes: {d}\n- total encoded bytes: {d}\n- total ratio: {d:.4}\n\n", .{ rows.len, total_input, total_encoded, total_ratio });
    try w.print("| path | input bytes | best deflate bytes | ratio | encode MiB/s | decode MiB/s |\n", .{});
    try w.print("| --- | ---: | ---: | ---: | ---: | ---: |\n", .{});
    for (rows) |row| {
        try w.print("| {s} | {d} | {d} | {d:.4} | {d:.2} | {d:.2} |\n", .{ row.path, row.input_bytes, row.encoded_bytes, row.ratio, row.encode_mib_s, row.decode_mib_s });
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
}
