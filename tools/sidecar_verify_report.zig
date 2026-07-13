const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var markdown_path: ?[]const u8 = null;
    var json_path: ?[]const u8 = null;
    var case_limit: ?usize = null;
    var validation_mode: vort.SidecarValidationMode = .full;
    var keep_going = false;
    var pairs: std.ArrayList(Pair) = .empty;
    defer {
        for (pairs.items) |pair| pair.deinit(init.gpa);
        pairs.deinit(init.gpa);
    }
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--markdown")) {
            markdown_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--json")) {
            json_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--limit")) {
            case_limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
            continue;
        }
        if (std.mem.eql(u8, arg, "--mode")) {
            validation_mode = try parseValidationMode(args.next() orelse return error.MissingCorpusPath);
            continue;
        }
        if (std.mem.eql(u8, arg, "--metadata-only")) {
            validation_mode = .metadata;
            continue;
        }
        if (std.mem.eql(u8, arg, "--full")) {
            validation_mode = .full;
            continue;
        }
        if (std.mem.eql(u8, arg, "--keep-going")) {
            keep_going = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--dir")) {
            try appendDirectoryPairs(init, &pairs, args.next() orelse return error.MissingCorpusPath);
            continue;
        }
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        try pairs.append(init.gpa, .{ .stream = arg, .sidecar = sidecar_path });
    }
    if (pairs.items.len == 0) return error.MissingCorpusPath;

    var rows: std.ArrayList(ReportRow) = .empty;
    defer rows.deinit(init.gpa);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("stream,sidecar,mode,status,error,stream_bytes,sidecar_bytes,entries,total_uncompressed,crc32\n", .{});
    for (pairs.items, 0..) |pair, i| {
        if (case_limit) |limit| if (i >= limit) break;
        const row = verifyPair(init, pair.stream, pair.sidecar, validation_mode) catch |err| row: {
            if (!keep_going) return err;
            break :row ReportRow{ .stream = pair.stream, .sidecar = pair.sidecar, .validation_mode = @tagName(validation_mode), .status = "error", .error_name = @errorName(err) };
        };
        try rows.append(init.gpa, row);
        try printCsvRow(stdout, row);
    }
    try stdout.flush();
    if (markdown_path) |path| try writeMarkdown(init, path, rows.items);
    if (json_path) |path| try writeJson(init, path, rows.items);
}

const Pair = struct {
    stream: []const u8,
    sidecar: []const u8,
    owned: bool = false,

    fn deinit(self: Pair, allocator: std.mem.Allocator) void {
        if (self.owned) {
            allocator.free(self.stream);
            allocator.free(self.sidecar);
        }
    }
};

const ReportRow = struct {
    stream: []const u8,
    sidecar: []const u8,
    validation_mode: []const u8,
    stream_bytes: usize = 0,
    sidecar_bytes: usize = 0,
    entries: usize = 0,
    total_uncompressed: u64 = 0,
    crc32: u32 = 0,
    status: []const u8 = "ok",
    error_name: []const u8 = "",
};

fn parseValidationMode(text: []const u8) !vort.SidecarValidationMode {
    if (std.mem.eql(u8, text, "metadata") or std.mem.eql(u8, text, "fast")) return .metadata;
    if (std.mem.eql(u8, text, "full")) return .full;
    return error.InvalidSidecarValidationMode;
}

fn appendDirectoryPairs(init: std.process.Init, pairs: *std.ArrayList(Pair), dir_path: []const u8) !void {
    var dir = try std.Io.Dir.cwd().openDir(init.io, dir_path, .{ .iterate = true });
    defer dir.close(init.io);
    var walker = try dir.walk(init.gpa);
    defer walker.deinit();
    while (try walker.next(init.io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".vort")) continue;
        const relative_sidecar = try replaceExtension(init.gpa, entry.path, ".vidx");
        defer init.gpa.free(relative_sidecar);
        const sidecar = try std.fs.path.join(init.gpa, &.{ dir_path, relative_sidecar });
        errdefer init.gpa.free(sidecar);
        _ = std.Io.Dir.cwd().statFile(init.io, sidecar, .{}) catch {
            init.gpa.free(sidecar);
            continue;
        };
        const stream = try std.fs.path.join(init.gpa, &.{ dir_path, entry.path });
        errdefer init.gpa.free(stream);
        try pairs.append(init.gpa, .{ .stream = stream, .sidecar = sidecar, .owned = true });
    }
}

fn replaceExtension(allocator: std.mem.Allocator, path: []const u8, extension: []const u8) ![]u8 {
    const dot = std.mem.lastIndexOfScalar(u8, path, '.') orelse path.len;
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ path[0..dot], extension });
}

fn verifyPair(init: std.process.Init, stream_path: []const u8, sidecar_path: []const u8, validation_mode: vort.SidecarValidationMode) !ReportRow {
    const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(stream);
    const sidecar = try std.Io.Dir.cwd().readFileAlloc(init.io, sidecar_path, init.gpa, .limited(16 * 1024 * 1024));
    defer init.gpa.free(sidecar);
    try vort.storeValidateSidecarIndexWithOptionsAlloc(init.gpa, stream, sidecar, .{ .mode = validation_mode });
    const entries = try vort.storeDecodeFrameIndexAlloc(init.gpa, sidecar);
    defer init.gpa.free(entries);
    var total_uncompressed: u64 = 0;
    for (entries) |entry| total_uncompressed += entry.uncompressed_len;
    return .{
        .stream = stream_path,
        .sidecar = sidecar_path,
        .validation_mode = @tagName(validation_mode),
        .stream_bytes = stream.len,
        .sidecar_bytes = sidecar.len,
        .entries = entries.len,
        .total_uncompressed = total_uncompressed,
        .crc32 = vort.crc32(sidecar),
        .status = "ok",
    };
}

fn printCsvRow(stdout: *std.Io.Writer, row: ReportRow) !void {
    try stdout.print("{s},{s},{s},{s},{s},{d},{d},{d},{d},{d}\n", .{
        row.stream,
        row.sidecar,
        row.validation_mode,
        row.status,
        row.error_name,
        row.stream_bytes,
        row.sidecar_bytes,
        row.entries,
        row.total_uncompressed,
        row.crc32,
    });
}

fn writeMarkdown(init: std.process.Init, path: []const u8, rows: []const ReportRow) !void {
    var writer = std.Io.Writer.Allocating.init(init.gpa);
    defer writer.deinit();
    const w = &writer.writer;
    var total_stream: usize = 0;
    var total_sidecar: usize = 0;
    var total_entries: usize = 0;
    var total_uncompressed: u64 = 0;
    var ok_rows: usize = 0;
    var error_rows: usize = 0;
    for (rows) |row| {
        if (std.mem.eql(u8, row.status, "ok")) ok_rows += 1 else error_rows += 1;
        total_stream += row.stream_bytes;
        total_sidecar += row.sidecar_bytes;
        total_entries += row.entries;
        total_uncompressed += row.total_uncompressed;
    }
    try w.print("# Sidecar verification report\n\n", .{});
    try w.print("- rows: {d}\n- ok rows: {d}\n- error rows: {d}\n- total stream bytes: {d}\n- total sidecar bytes: {d}\n- total entries: {d}\n- total uncompressed bytes: {d}\n\n", .{ rows.len, ok_rows, error_rows, total_stream, total_sidecar, total_entries, total_uncompressed });
    try w.print("| stream | sidecar | mode | status | error | stream bytes | sidecar bytes | entries | total uncompressed | sidecar crc32 |\n", .{});
    try w.print("| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |\n", .{});
    for (rows) |row| {
        try w.print("| {s} | {s} | {s} | {s} | {s} | {d} | {d} | {d} | {d} | {d} |\n", .{ row.stream, row.sidecar, row.validation_mode, row.status, row.error_name, row.stream_bytes, row.sidecar_bytes, row.entries, row.total_uncompressed, row.crc32 });
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
}

fn writeJson(init: std.process.Init, path: []const u8, rows: []const ReportRow) !void {
    var writer = std.Io.Writer.Allocating.init(init.gpa);
    defer writer.deinit();
    const w = &writer.writer;
    var total_stream: usize = 0;
    var total_sidecar: usize = 0;
    var total_entries: usize = 0;
    var total_uncompressed: u64 = 0;
    var ok_rows: usize = 0;
    var error_rows: usize = 0;
    for (rows) |row| {
        if (std.mem.eql(u8, row.status, "ok")) ok_rows += 1 else error_rows += 1;
        total_stream += row.stream_bytes;
        total_sidecar += row.sidecar_bytes;
        total_entries += row.entries;
        total_uncompressed += row.total_uncompressed;
    }
    try w.print("{{\n  \"rows\": {d},\n  \"ok_rows\": {d},\n  \"error_rows\": {d},\n  \"total_stream_bytes\": {d},\n  \"total_sidecar_bytes\": {d},\n  \"total_entries\": {d},\n  \"total_uncompressed_bytes\": {d},\n  \"items\": [\n", .{ rows.len, ok_rows, error_rows, total_stream, total_sidecar, total_entries, total_uncompressed });
    for (rows, 0..) |row, i| {
        try w.print("    {{\"stream\": ", .{});
        try std.json.Stringify.value(row.stream, .{}, w);
        try w.print(", \"sidecar\": ", .{});
        try std.json.Stringify.value(row.sidecar, .{}, w);
        try w.print(", \"mode\": ", .{});
        try std.json.Stringify.value(row.validation_mode, .{}, w);
        try w.print(", \"status\": ", .{});
        try std.json.Stringify.value(row.status, .{}, w);
        try w.print(", \"error\": ", .{});
        try std.json.Stringify.value(row.error_name, .{}, w);
        try w.print(", \"stream_bytes\": {d}, \"sidecar_bytes\": {d}, \"entries\": {d}, \"total_uncompressed\": {d}, \"crc32\": {d}}}{s}\n", .{
            row.stream_bytes,
            row.sidecar_bytes,
            row.entries,
            row.total_uncompressed,
            row.crc32,
            if (i + 1 == rows.len) "" else ",",
        });
    }
    try w.print("  ]\n}}\n", .{});
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
}
