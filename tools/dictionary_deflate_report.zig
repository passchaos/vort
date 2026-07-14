const std = @import("std");
const vort = @import("vort");

const Case = struct {
    name: []const u8,
    owned_name: bool = false,
    dictionary: []const u8,
    shared_dictionary: bool = false,
    payload: []const u8,
    owned: bool = false,
};

const ReportStats = struct {
    input_bytes: usize = 0,
    dict_bytes: usize = 0,
    raw_plain_bytes: usize = 0,
    raw_dict_bytes: usize = 0,
    zlib_plain_bytes: usize = 0,
    zlib_dict_bytes: usize = 0,

    fn add(self: *ReportStats, other: ReportStats) void {
        self.input_bytes += other.input_bytes;
        self.dict_bytes += other.dict_bytes;
        self.raw_plain_bytes += other.raw_plain_bytes;
        self.raw_dict_bytes += other.raw_dict_bytes;
        self.zlib_plain_bytes += other.zlib_plain_bytes;
        self.zlib_dict_bytes += other.zlib_dict_bytes;
    }
};

const builtins = [_]Case{
    .{
        .name = "hello-repeat",
        .dictionary = "hello ",
        .payload = "hello hello hello hello hello ",
    },
    .{
        .name = "json-prefix",
        .dictionary = "{\"service\":\"vort\",\"level\":\"",
        .payload = "{\"service\":\"vort\",\"level\":\"default\",\"message\":\"dictionary deflate smoke\"}\n" ** 8,
    },
    .{
        .name = "log-prefix",
        .dictionary = "2026-07-14T00:00:00Z INFO vort request_id=",
        .payload = "2026-07-14T00:00:00Z INFO vort request_id=alpha path=/deflate\n" ** 8,
    },
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    var markdown_path: ?[]const u8 = null;
    var shared_dictionary: ?[]u8 = null;
    var file_cases: std.ArrayList(Case) = .empty;
    defer {
        for (file_cases.items) |case| {
            if (case.owned) {
                if (case.owned_name) init.gpa.free(case.name);
                if (!case.shared_dictionary) init.gpa.free(case.dictionary);
                init.gpa.free(case.payload);
            }
        }
        if (shared_dictionary) |dictionary| init.gpa.free(dictionary);
        file_cases.deinit(init.gpa);
    }

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--markdown")) {
            markdown_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--dict")) {
            const dict_path = args.next() orelse return error.MissingCorpusPath;
            if (shared_dictionary != null) return error.InvalidDictionaryTraining;
            shared_dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dict_path, init.gpa, .limited(128 * 1024 * 1024));
            continue;
        }
        if (shared_dictionary) |dictionary| {
            try appendSharedDictionaryPath(init, &file_cases, dictionary, arg);
            continue;
        }
        const dict_path = arg;
        const payload_path = args.next() orelse return error.MissingCorpusPath;
        const dictionary = try std.Io.Dir.cwd().readFileAlloc(init.io, dict_path, init.gpa, .limited(128 * 1024 * 1024));
        errdefer init.gpa.free(dictionary);
        const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, payload_path, init.gpa, .limited(128 * 1024 * 1024));
        errdefer init.gpa.free(payload);
        try file_cases.append(init.gpa, .{ .name = payload_path, .dictionary = dictionary, .payload = payload, .owned = true });
    }
    if (shared_dictionary != null and file_cases.items.len == 0) return error.MissingCorpusPath;

    var output = std.Io.Writer.Allocating.init(init.gpa);
    defer output.deinit();
    const writer = &output.writer;
    try writer.writeAll("case,input_bytes,dict_bytes,raw_plain_bytes,raw_dict_bytes,zlib_plain_bytes,zlib_dict_bytes,raw_dict_delta,zlib_dict_delta,raw_dict_ratio,zlib_dict_ratio\n");

    const cases = if (file_cases.items.len == 0) builtins[0..] else file_cases.items;
    var totals = ReportStats{};
    var rows: std.ArrayList(ReportRow) = .empty;
    defer rows.deinit(init.gpa);
    for (cases) |case| {
        const stats = try reportCase(init.gpa, writer, case);
        totals.add(stats);
        try rows.append(init.gpa, .{ .name = case.name, .stats = stats });
    }
    if (cases.len > 1) {
        try writeStatsRow(writer, "TOTAL", totals);
        try rows.append(init.gpa, .{ .name = "TOTAL", .stats = totals });
    }

    const bytes = output.written();
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(bytes);
    try stdout.flush();

    if (csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = bytes });
    }
    if (markdown_path) |path| {
        var markdown = std.Io.Writer.Allocating.init(init.gpa);
        defer markdown.deinit();
        try writeMarkdown(&markdown.writer, rows.items);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = markdown.written() });
    }
}

const ReportRow = struct {
    name: []const u8,
    stats: ReportStats,
};

fn writeMarkdown(writer: *std.Io.Writer, rows: []const ReportRow) !void {
    try writer.writeAll(
        \\# Dictionary deflate savings
        \\
        \\| case | input bytes | dict bytes | raw plain | raw dict | raw Δ | raw dict/plain | zlib plain | zlib dict | zlib Δ | zlib dict/plain |
        \\| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
        \\
    );
    for (rows) |row| {
        try writer.print("| {s} | {d} | {d} | {d} | {d} | {d} | {d:.3} | {d} | {d} | {d} | {d:.3} |\n", .{
            row.name,
            row.stats.input_bytes,
            row.stats.dict_bytes,
            row.stats.raw_plain_bytes,
            row.stats.raw_dict_bytes,
            signedDelta(row.stats.raw_plain_bytes, row.stats.raw_dict_bytes),
            ratio(row.stats.raw_dict_bytes, row.stats.raw_plain_bytes),
            row.stats.zlib_plain_bytes,
            row.stats.zlib_dict_bytes,
            signedDelta(row.stats.zlib_plain_bytes, row.stats.zlib_dict_bytes),
            ratio(row.stats.zlib_dict_bytes, row.stats.zlib_plain_bytes),
        });
    }
}

fn appendSharedDictionaryPath(init: std.process.Init, cases: *std.ArrayList(Case), dictionary: []const u8, path: []const u8) !void {
    const stat = std.Io.Dir.cwd().statFile(init.io, path, .{}) catch {
        try appendSharedDictionaryFile(init, cases, dictionary, path, false);
        return;
    };
    if (stat.kind == .directory) {
        try appendSharedDictionaryDirectory(init, cases, dictionary, path);
        return;
    }
    try appendSharedDictionaryFile(init, cases, dictionary, path, false);
}

fn appendSharedDictionaryDirectory(init: std.process.Init, cases: *std.ArrayList(Case), path_dictionary: []const u8, dir_path: []const u8) !void {
    var dir = try std.Io.Dir.cwd().openDir(init.io, dir_path, .{ .iterate = true });
    defer dir.close(init.io);
    var walker = try dir.walk(init.gpa);
    defer walker.deinit();
    while (try walker.next(init.io)) |entry| {
        if (entry.kind != .file) continue;
        const joined = try std.fs.path.join(init.gpa, &.{ dir_path, entry.path });
        errdefer init.gpa.free(joined);
        try appendSharedDictionaryFile(init, cases, path_dictionary, joined, true);
    }
}

fn appendSharedDictionaryFile(init: std.process.Init, cases: *std.ArrayList(Case), dictionary: []const u8, payload_path: []const u8, owned_name: bool) !void {
    const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, payload_path, init.gpa, .limited(128 * 1024 * 1024));
    errdefer init.gpa.free(payload);
    errdefer if (owned_name) init.gpa.free(payload_path);
    try cases.append(init.gpa, .{ .name = payload_path, .owned_name = owned_name, .dictionary = dictionary, .shared_dictionary = true, .payload = payload, .owned = true });
}

fn reportCase(allocator: std.mem.Allocator, writer: *std.Io.Writer, case: Case) !ReportStats {
    const options = vort.optionsForCompressionLevel(.default);

    const raw_plain = try vort.encodeRawBestAlloc(allocator, case.payload, options);
    defer allocator.free(raw_plain);
    const raw_dict = try vort.encodeRawBestWithDictionaryAlloc(allocator, case.payload, case.dictionary, options);
    defer allocator.free(raw_dict);
    const zlib_plain = try vort.encodeZlibBestAlloc(allocator, case.payload, options);
    defer allocator.free(zlib_plain);
    const zlib_dict = try vort.encodeZlibBestWithDictionaryAlloc(allocator, case.payload, case.dictionary, options);
    defer allocator.free(zlib_dict);

    const raw_decoded = try vort.decodeRawDeflateAllocWithDictionary(allocator, raw_dict, case.dictionary);
    defer allocator.free(raw_decoded);
    if (!std.mem.eql(u8, case.payload, raw_decoded)) return error.RoundTripMismatch;
    const zlib_decoded = try vort.decodeZlibAllocWithDictionary(allocator, zlib_dict, case.dictionary);
    defer allocator.free(zlib_decoded);
    if (!std.mem.eql(u8, case.payload, zlib_decoded)) return error.RoundTripMismatch;

    const stats = ReportStats{
        .input_bytes = case.payload.len,
        .dict_bytes = case.dictionary.len,
        .raw_plain_bytes = raw_plain.len,
        .raw_dict_bytes = raw_dict.len,
        .zlib_plain_bytes = zlib_plain.len,
        .zlib_dict_bytes = zlib_dict.len,
    };
    try writeStatsRow(writer, case.name, stats);
    return stats;
}

fn writeStatsRow(writer: *std.Io.Writer, name: []const u8, stats: ReportStats) !void {
    try writer.print("{s},{d},{d},{d},{d},{d},{d},{d},{d},{d:.4},{d:.4}\n", .{
        name,
        stats.input_bytes,
        stats.dict_bytes,
        stats.raw_plain_bytes,
        stats.raw_dict_bytes,
        stats.zlib_plain_bytes,
        stats.zlib_dict_bytes,
        signedDelta(stats.raw_plain_bytes, stats.raw_dict_bytes),
        signedDelta(stats.zlib_plain_bytes, stats.zlib_dict_bytes),
        ratio(stats.raw_dict_bytes, stats.raw_plain_bytes),
        ratio(stats.zlib_dict_bytes, stats.zlib_plain_bytes),
    });
}

fn signedDelta(lhs: usize, rhs: usize) isize {
    return @as(isize, @intCast(lhs)) - @as(isize, @intCast(rhs));
}

fn ratio(numerator: usize, denominator: usize) f64 {
    if (denominator == 0) return 0;
    return @as(f64, @floatFromInt(numerator)) / @as(f64, @floatFromInt(denominator));
}
