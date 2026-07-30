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

    try stdout.print("codec,case,input_bytes,dictionary_bytes,native_bytes,dictionary_bytes_out,savings_bytes,savings_percent\n", .{});
    try reportBuiltIns(init.gpa, stdout);
    try reportFileCases(init.io, init.gpa, stdout, options);
    try stdout.flush();
}

const Options = struct {
    paths: std.ArrayList([]const u8) = .empty,
    dirs: std.ArrayList([]const u8) = .empty,
    limit: usize = 64 * 1024,
    max_files: usize = 8,
    dictionary_len: usize = 512,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        for (self.paths.items) |path| allocator.free(path);
        for (self.dirs.items) |dir| allocator.free(dir);
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
        } else {
            return error.UnknownArgument;
        }
    }
    return options;
}

fn reportBuiltIns(allocator: std.mem.Allocator, stdout: *std.Io.Writer) !void {
    const lz4_dict = vort.Lz4NativeDictionary.init(0x4c5a_4449, "abcdefghijklmnop");
    const lz4_payload = "pfx-abcdefghijklmnop-mid-abcdefghijklmnop-tail";
    const lz4_row = try lz4Row(allocator, "builtin-lz4", lz4_payload, lz4_dict);
    if (lz4_row.savings() <= 0) return error.NativeDictionaryReportNoSavings;
    try printRow(stdout, lz4_row);

    const dictionary_payload = "abcdefghijklmnopqrstuvwxyz0123456789" ** 8;
    const zstd_dict = vort.ZstdNativeDictionary.init(0x5a57_4449, dictionary_payload);
    const zstd_payload = "pfx-" ++ dictionary_payload ++ "-mid-" ++ dictionary_payload ++ "-tail";
    const zstd_row = try zstdRow(allocator, "builtin-zstd", zstd_payload, zstd_dict);
    if (zstd_row.savings() <= 0) return error.NativeDictionaryReportNoSavings;
    try printRow(stdout, zstd_row);
}

fn reportFileCases(io: std.Io, allocator: std.mem.Allocator, stdout: *std.Io.Writer, options: Options) !void {
    for (options.paths.items) |path| try reportFileCase(io, allocator, stdout, path, options.limit, options.dictionary_len);

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
            try reportFileCase(io, allocator, stdout, path, options.limit, options.dictionary_len);
            discovered += 1;
        }
    }
}

fn reportFileCase(io: std.Io, allocator: std.mem.Allocator, stdout: *std.Io.Writer, path: []const u8, limit: usize, requested_dictionary_len: usize) !void {
    const full = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(128 * 1024 * 1024));
    defer allocator.free(full);
    const payload = if (limit != 0 and full.len > limit) full[0..limit] else full;
    if (payload.len == 0) return;
    const dictionary_len = @min(@max(@as(usize, 1), requested_dictionary_len), payload.len);
    const dictionary = payload[0..dictionary_len];
    const id = std.hash.Crc32.hash(dictionary) | 1;

    const lz4_row_result = lz4Row(allocator, path, payload, vort.Lz4NativeDictionary.init(id, dictionary));
    if (lz4_row_result) |row| try printRow(stdout, row) else |err| switch (err) {
        error.NeedDictionary, error.InvalidMatch, error.OutputTooSmall, error.OutputLimitExceeded => return err,
        else => return err,
    }
    const zstd_row_result = zstdRow(allocator, path, payload, vort.ZstdNativeDictionary.init(id, dictionary));
    if (zstd_row_result) |row| try printRow(stdout, row) else |err| switch (err) {
        error.NeedDictionary, error.InvalidMatch, error.OutputTooSmall, error.OutputLimitExceeded => return err,
        else => return err,
    }
}

const ReportRow = struct {
    codec: []const u8,
    case_name: []const u8,
    input_len: usize,
    dictionary_len: usize,
    native_len: usize,
    dictionary_frame_len: usize,

    fn savings(self: ReportRow) isize {
        return @as(isize, @intCast(self.native_len)) - @as(isize, @intCast(self.dictionary_frame_len));
    }
};

fn lz4Row(allocator: std.mem.Allocator, case_name: []const u8, payload: []const u8, dict: vort.Lz4NativeDictionary) !ReportRow {
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };
    const native = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
    defer allocator.free(native);
    const with_dict = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(with_dict);
    const decoded = try vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, with_dict, dict);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.NativeDictionaryReportMismatch;
    return .{ .codec = "lz4", .case_name = case_name, .input_len = payload.len, .dictionary_len = dict.content.len, .native_len = native.len, .dictionary_frame_len = with_dict.len };
}

fn zstdRow(allocator: std.mem.Allocator, case_name: []const u8, payload: []const u8, dict: vort.ZstdNativeDictionary) !ReportRow {
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };
    const native = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
    defer allocator.free(native.frame);
    const with_dict = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(with_dict.frame);
    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, with_dict.frame, dict);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.NativeDictionaryReportMismatch;
    return .{ .codec = "zstd", .case_name = case_name, .input_len = payload.len, .dictionary_len = dict.content.len, .native_len = native.frame.len, .dictionary_frame_len = with_dict.frame.len };
}

fn printRow(stdout: *std.Io.Writer, row: ReportRow) !void {
    const savings = row.savings();
    const savings_percent = (@as(f64, @floatFromInt(savings)) * 100.0) / @as(f64, @floatFromInt(row.native_len));
    try stdout.print(
        "{s},{s},{d},{d},{d},{d},{d},{d:.2}\n",
        .{ row.codec, row.case_name, row.input_len, row.dictionary_len, row.native_len, row.dictionary_frame_len, savings, savings_percent },
    );
}
