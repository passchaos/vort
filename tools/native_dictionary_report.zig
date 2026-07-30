const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(init.gpa, &args);
    defer options.deinit(init.gpa);

    var rows: std.ArrayList(ReportRow) = .empty;
    defer rows.deinit(init.gpa);
    try reportBuiltIns(init.io, init.gpa, &rows);
    try reportFileCases(init.io, init.gpa, &rows, options);

    try writeCsv(stdout, rows.items);
    try stdout.flush();
    if (options.json_path) |path| try writeJsonFile(init, path, rows.items);
    if (options.markdown_path) |path| try writeMarkdownFile(init, path, rows.items);
}

const Options = struct {
    paths: std.ArrayList([]const u8) = .empty,
    dirs: std.ArrayList([]const u8) = .empty,
    limit: usize = 64 * 1024,
    max_files: usize = 8,
    dictionary_len: usize = 512,
    json_path: ?[]const u8 = null,
    markdown_path: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        for (self.paths.items) |path| allocator.free(path);
        for (self.dirs.items) |dir| allocator.free(dir);
        if (self.json_path) |path| allocator.free(path);
        if (self.markdown_path) |path| allocator.free(path);
        var paths = self.paths;
        paths.deinit(allocator);
        var dirs = self.dirs;
        dirs.deinit(allocator);
    }
};

fn parseOptions(allocator: std.mem.Allocator, args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    errdefer options.deinit(allocator);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--path")) {
            const path = args.next() orelse return error.MissingPath;
            try options.paths.append(allocator, try allocator.dupe(u8, path));
        } else if (std.mem.eql(u8, arg, "--dir")) {
            const dir = args.next() orelse return error.MissingPath;
            try options.dirs.append(allocator, try allocator.dupe(u8, dir));
        } else if (std.mem.eql(u8, arg, "--limit")) {
            const value = args.next() orelse return error.MissingLimit;
            options.limit = try std.fmt.parseInt(usize, value, 10);
        } else if (std.mem.eql(u8, arg, "--max-files")) {
            const value = args.next() orelse return error.MissingLimit;
            options.max_files = try std.fmt.parseInt(usize, value, 10);
        } else if (std.mem.eql(u8, arg, "--dict-len")) {
            const value = args.next() orelse return error.MissingLimit;
            options.dictionary_len = try std.fmt.parseInt(usize, value, 10);
        } else if (std.mem.eql(u8, arg, "--json")) {
            const path = args.next() orelse return error.MissingReportPath;
            options.json_path = try allocator.dupe(u8, path);
        } else if (std.mem.eql(u8, arg, "--markdown")) {
            const path = args.next() orelse return error.MissingReportPath;
            options.markdown_path = try allocator.dupe(u8, path);
        } else {
            return error.UnknownArgument;
        }
    }
    return options;
}

fn reportBuiltIns(io: std.Io, allocator: std.mem.Allocator, rows: *std.ArrayList(ReportRow)) !void {
    const lz4_dict = vort.Lz4NativeDictionary.init(0x4c5a_4449, "abcdefghijklmnop");
    const lz4_payload = "pfx-abcdefghijklmnop-mid-abcdefghijklmnop-tail";
    const lz4_row = try lz4Row(io, allocator, "builtin-lz4", lz4_payload, lz4_dict);
    if (lz4_row.savings() <= 0) return error.NativeDictionaryReportNoSavings;
    try rows.append(allocator, lz4_row);

    const dictionary_payload = "abcdefghijklmnopqrstuvwxyz0123456789" ** 8;
    const zstd_dict = vort.ZstdNativeDictionary.init(0x5a57_4449, dictionary_payload);
    const zstd_payload = "pfx-" ++ dictionary_payload ++ "-mid-" ++ dictionary_payload ++ "-tail";
    const zstd_row = try zstdRow(io, allocator, "builtin-zstd", zstd_payload, zstd_dict);
    if (zstd_row.savings() <= 0) return error.NativeDictionaryReportNoSavings;
    try rows.append(allocator, zstd_row);
}

fn reportFileCases(io: std.Io, allocator: std.mem.Allocator, rows: *std.ArrayList(ReportRow), options: Options) !void {
    for (options.paths.items) |path| try reportFileCase(io, allocator, rows, path, options.limit, options.dictionary_len);

    var discovered: usize = 0;
    for (options.dirs.items) |dir_path| {
        var dir = try std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
        defer dir.close(io);
        var iter = dir.iterate();
        while (try iter.next(io)) |entry| {
            if (entry.kind != .file) continue;
            if (options.max_files != 0 and discovered >= options.max_files) return;
            const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, entry.name });
            defer allocator.free(path);
            try reportFileCase(io, allocator, rows, path, options.limit, options.dictionary_len);
            discovered += 1;
        }
    }
}

fn reportFileCase(io: std.Io, allocator: std.mem.Allocator, rows: *std.ArrayList(ReportRow), path: []const u8, limit: usize, requested_dictionary_len: usize) !void {
    const full = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(128 * 1024 * 1024));
    defer allocator.free(full);
    const payload = if (limit != 0 and full.len > limit) full[0..limit] else full;
    if (payload.len == 0) return;
    const dictionary_len = @min(@max(@as(usize, 1), requested_dictionary_len), payload.len);
    const dictionary = payload[0..dictionary_len];
    const id = std.hash.Crc32.hash(dictionary) | 1;

    try rows.append(allocator, try lz4Row(io, allocator, path, payload, vort.Lz4NativeDictionary.init(id, dictionary)));
    try rows.append(allocator, try zstdRow(io, allocator, path, payload, vort.ZstdNativeDictionary.init(id, dictionary)));
}

const ReportRow = struct {
    codec: []const u8,
    case_name: []const u8,
    input_len: usize,
    dictionary_len: usize,
    native_len: usize,
    dictionary_frame_len: usize,
    dictionary_encode_ns: u64,
    dictionary_decode_ns: u64,

    fn savings(self: ReportRow) isize {
        return @as(isize, @intCast(self.native_len)) - @as(isize, @intCast(self.dictionary_frame_len));
    }

    fn savingsPercent(self: ReportRow) f64 {
        return (@as(f64, @floatFromInt(self.savings())) * 100.0) / @as(f64, @floatFromInt(self.native_len));
    }
};

fn lz4Row(io: std.Io, allocator: std.mem.Allocator, case_name: []const u8, payload: []const u8, dict: vort.Lz4NativeDictionary) !ReportRow {
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };
    const native = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
    defer allocator.free(native);
    const encode_start = std.Io.Clock.awake.now(io);
    const with_dict = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    const dictionary_encode_ns = elapsedNs(io, encode_start);
    defer allocator.free(with_dict);
    const decode_start = std.Io.Clock.awake.now(io);
    const decoded = try vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, with_dict, dict);
    const dictionary_decode_ns = elapsedNs(io, decode_start);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.NativeDictionaryReportMismatch;
    return .{
        .codec = "lz4",
        .case_name = case_name,
        .input_len = payload.len,
        .dictionary_len = dict.content.len,
        .native_len = native.len,
        .dictionary_frame_len = with_dict.len,
        .dictionary_encode_ns = dictionary_encode_ns,
        .dictionary_decode_ns = dictionary_decode_ns,
    };
}

fn zstdRow(io: std.Io, allocator: std.mem.Allocator, case_name: []const u8, payload: []const u8, dict: vort.ZstdNativeDictionary) !ReportRow {
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };
    const native = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
    defer allocator.free(native.frame);
    const encode_start = std.Io.Clock.awake.now(io);
    const with_dict = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    const dictionary_encode_ns = elapsedNs(io, encode_start);
    defer allocator.free(with_dict.frame);
    const decode_start = std.Io.Clock.awake.now(io);
    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, with_dict.frame, dict);
    const dictionary_decode_ns = elapsedNs(io, decode_start);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.NativeDictionaryReportMismatch;
    return .{
        .codec = "zstd",
        .case_name = case_name,
        .input_len = payload.len,
        .dictionary_len = dict.content.len,
        .native_len = native.frame.len,
        .dictionary_frame_len = with_dict.frame.len,
        .dictionary_encode_ns = dictionary_encode_ns,
        .dictionary_decode_ns = dictionary_decode_ns,
    };
}

fn writeCsv(stdout: *std.Io.Writer, rows: []const ReportRow) !void {
    try stdout.print("codec,case,input_bytes,dictionary_bytes,native_bytes,dictionary_bytes_out,savings_bytes,savings_percent,dictionary_encode_ns,dictionary_decode_ns,dictionary_encode_mib_s,dictionary_decode_mib_s\n", .{});
    for (rows) |row| try printCsvRow(stdout, row);
}

fn printCsvRow(stdout: *std.Io.Writer, row: ReportRow) !void {
    try stdout.print(
        "{s},{s},{d},{d},{d},{d},{d},{d:.2},{d},{d},{d:.2},{d:.2}\n",
        .{
            row.codec,
            row.case_name,
            row.input_len,
            row.dictionary_len,
            row.native_len,
            row.dictionary_frame_len,
            row.savings(),
            row.savingsPercent(),
            row.dictionary_encode_ns,
            row.dictionary_decode_ns,
            mibPerSecond(row.input_len, row.dictionary_encode_ns),
            mibPerSecond(row.input_len, row.dictionary_decode_ns),
        },
    );
}

fn writeJsonFile(init: std.process.Init, path: []const u8, rows: []const ReportRow) !void {
    var json = std.Io.Writer.Allocating.init(init.gpa);
    defer json.deinit();
    try writeJson(&json.writer, rows);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = json.written() });
}

fn writeJson(writer: *std.Io.Writer, rows: []const ReportRow) !void {
    try writer.writeAll("[\n");
    for (rows, 0..) |row, i| {
        if (i != 0) try writer.writeAll(",\n");
        try writer.writeAll("  {");
        try writer.writeAll("\"codec\":");
        try std.json.Stringify.value(row.codec, .{}, writer);
        try writer.print(",\"case\":", .{});
        try std.json.Stringify.value(row.case_name, .{}, writer);
        try writer.print(",\"input_bytes\":{d},\"dictionary_bytes\":{d},\"native_bytes\":{d},\"dictionary_bytes_out\":{d},\"savings_bytes\":{d},\"savings_percent\":{d:.2},\"dictionary_encode_ns\":{d},\"dictionary_decode_ns\":{d},\"dictionary_encode_mib_s\":{d:.2},\"dictionary_decode_mib_s\":{d:.2}", .{
            row.input_len,
            row.dictionary_len,
            row.native_len,
            row.dictionary_frame_len,
            row.savings(),
            row.savingsPercent(),
            row.dictionary_encode_ns,
            row.dictionary_decode_ns,
            mibPerSecond(row.input_len, row.dictionary_encode_ns),
            mibPerSecond(row.input_len, row.dictionary_decode_ns),
        });
        try writer.writeAll("}");
    }
    try writer.writeAll("\n]\n");
}

fn writeMarkdownFile(init: std.process.Init, path: []const u8, rows: []const ReportRow) !void {
    var markdown = std.Io.Writer.Allocating.init(init.gpa);
    defer markdown.deinit();
    try writeMarkdown(&markdown.writer, rows);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = markdown.written() });
}

fn writeMarkdown(writer: *std.Io.Writer, rows: []const ReportRow) !void {
    try writer.writeAll("# Native dictionary encoding report\n\n");
    try writer.writeAll("| codec | case | input bytes | dictionary bytes | native bytes | dictionary bytes out | savings bytes | savings % | encode MiB/s | decode MiB/s |\n");
    try writer.writeAll("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n");
    for (rows) |row| {
        try writer.print(
            "| {s} | {s} | {d} | {d} | {d} | {d} | {d} | {d:.2} | {d:.2} | {d:.2} |\n",
            .{
                row.codec,
                row.case_name,
                row.input_len,
                row.dictionary_len,
                row.native_len,
                row.dictionary_frame_len,
                row.savings(),
                row.savingsPercent(),
                mibPerSecond(row.input_len, row.dictionary_encode_ns),
                mibPerSecond(row.input_len, row.dictionary_decode_ns),
            },
        );
    }
}

fn mibPerSecond(input_len: usize, ns: u64) f64 {
    if (ns == 0) return 0.0;
    const mib = @as(f64, @floatFromInt(input_len)) / (1024.0 * 1024.0);
    const seconds = @as(f64, @floatFromInt(ns)) / 1_000_000_000.0;
    return mib / seconds;
}

fn elapsedNs(io: std.Io, start: std.Io.Timestamp) u64 {
    const end = std.Io.Clock.awake.now(io);
    const duration = start.durationTo(end).nanoseconds;
    return if (duration <= 0) 0 else @intCast(duration);
}
