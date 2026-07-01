const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var markdown_path: ?[]const u8 = null;
    var case_limit: ?usize = null;
    var sources: std.ArrayList([]const u8) = .empty;
    defer sources.deinit(init.gpa);
    var path_entries: std.ArrayList(PathEntry) = .empty;
    defer {
        for (path_entries.items) |entry| if (entry.owned) init.gpa.free(entry.path);
        path_entries.deinit(init.gpa);
    }
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--standard-suite")) {
            try sources.append(init.gpa, "standard-suite");
            try appendStandardCorpora(init, &path_entries);
            continue;
        }
        if (std.mem.eql(u8, arg, "--markdown")) {
            markdown_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--limit")) {
            case_limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
            continue;
        }
        try sources.append(init.gpa, arg);
        try appendPathArg(init, &path_entries, arg);
    }
    if (path_entries.items.len == 0) return error.MissingCorpusPath;

    var rows: std.ArrayList(ReportRow) = .empty;
    defer rows.deinit(init.gpa);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("path,input_bytes,best_deflate_bytes,best_ratio,encode_mib_s,decode_mib_s\n", .{});

    for (path_entries.items, 0..) |entry, i| {
        if (case_limit) |limit| if (i >= limit) break;
        const path = entry.path;
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
    if (markdown_path) |path| try writeMarkdown(init, path, rows.items, sources.items);
}

fn appendStandardCorpora(init: std.process.Init, paths: *std.ArrayList(PathEntry)) !void {
    const candidates = [_][]const u8{
        "/home/passchaos/Work/zlib-rs/silesia-small.tar",
        "/home/passchaos/Work/corpora/calgary.tar",
        "/home/passchaos/Work/corpora/canterbury.tar",
        "/home/passchaos/Work/corpora/large-canterbury.tar",
        "/home/passchaos/Work/corpora/enwik8",
    };
    for (&candidates) |path| {
        _ = std.Io.Dir.cwd().statFile(init.io, path, .{}) catch continue;
        try appendPathArg(init, paths, path);
    }
}

fn appendPathArg(init: std.process.Init, paths: *std.ArrayList(PathEntry), path: []const u8) !void {
    if (std.mem.endsWith(u8, path, ".tar")) {
        try appendTarPathArg(init, paths, path);
        return;
    }
    const stat = std.Io.Dir.cwd().statFile(init.io, path, .{}) catch {
        try paths.append(init.gpa, .{ .path = path });
        return;
    };
    if (stat.kind != .directory) {
        try paths.append(init.gpa, .{ .path = path });
        return;
    }

    try appendDirectoryArg(init, paths, path);
}

fn appendDirectoryArg(init: std.process.Init, paths: *std.ArrayList(PathEntry), path: []const u8) !void {
    var dir = try std.Io.Dir.cwd().openDir(init.io, path, .{ .iterate = true });
    defer dir.close(init.io);
    var walker = try dir.walk(init.gpa);
    defer walker.deinit();
    while (try walker.next(init.io)) |entry| {
        if (entry.kind != .file) continue;
        const joined = try std.fs.path.join(init.gpa, &.{ path, entry.path });
        errdefer init.gpa.free(joined);
        try paths.append(init.gpa, .{ .path = joined, .owned = true });
    }
}

fn appendTarPathArg(init: std.process.Init, paths: *std.ArrayList(PathEntry), path: []const u8) !void {
    const out_dir = try std.fmt.allocPrint(init.gpa, "zig-out/vort-file-corpus-tar-{x}", .{vort.crc32(path)});
    defer init.gpa.free(out_dir);
    {
        var proc = try std.process.spawn(init.io, .{ .argv = &.{ "mkdir", "-p", out_dir } });
        const term = try proc.wait(init.io);
        switch (term) {
            .exited => |code| if (code != 0) return error.InvalidMagic,
            else => return error.InvalidMagic,
        }
    }
    var proc = try std.process.spawn(init.io, .{ .argv = &.{ "tar", "-xf", path, "-C", out_dir } });
    const term = try proc.wait(init.io);
    switch (term) {
        .exited => |code| if (code != 0) return error.InvalidMagic,
        else => return error.InvalidMagic,
    }
    try appendDirectoryArg(init, paths, out_dir);
}

const PathEntry = struct {
    path: []const u8,
    owned: bool = false,
};

const ReportRow = struct {
    path: []const u8,
    input_bytes: usize,
    encoded_bytes: usize,
    ratio: f64,
    encode_mib_s: f64,
    decode_mib_s: f64,
};

fn writeMarkdown(init: std.process.Init, path: []const u8, rows: []const ReportRow, sources: []const []const u8) !void {
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
    try w.print("- rows: {d}\n- total input bytes: {d}\n- total encoded bytes: {d}\n- total ratio: {d:.4}\n- sources: `", .{ rows.len, total_input, total_encoded, total_ratio });
    for (sources, 0..) |source, i| {
        if (i != 0) try w.print(", ", .{});
        try w.print("{s}", .{source});
    }
    try w.print("`\n\n", .{});
    try w.print("| path | input bytes | best deflate bytes | ratio | encode MiB/s | decode MiB/s |\n", .{});
    try w.print("| --- | ---: | ---: | ---: | ---: | ---: |\n", .{});
    for (rows) |row| {
        try w.print("| {s} | {d} | {d} | {d:.4} | {d:.2} | {d:.2} |\n", .{ row.path, row.input_bytes, row.encoded_bytes, row.ratio, row.encode_mib_s, row.decode_mib_s });
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
}
