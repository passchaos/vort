const std = @import("std");
const vort = @import("vort");

const Options = struct {
    csv_path: ?[]const u8 = null,
    json_path: ?[]const u8 = null,
    markdown_path: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);

    const entries = vort.br.minimalStaticDictionaryCoverage();
    try validateEntries(entries);
    const transforms = transformCount(entries);
    const lengths = lengthCount(entries);
    const categories = categoryCounts(entries);

    var matrix_rows: std.ArrayList(MatrixRow) = .empty;
    defer matrix_rows.deinit(init.gpa);
    try collectMatrixRows(init.gpa, &matrix_rows, entries);

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try writeCsv(&csv.writer, entries);

    var json = std.Io.Writer.Allocating.init(init.gpa);
    defer json.deinit();
    try writeJson(&json.writer, entries, transforms, lengths, categories, matrix_rows.items);

    var markdown = std.Io.Writer.Allocating.init(init.gpa);
    defer markdown.deinit();
    try writeMarkdown(&markdown.writer, entries, transforms, lengths, categories, matrix_rows.items);

    if (options.csv_path) |path| try writeFileCreatingParents(init.io, path, csv.written());
    if (options.json_path) |path| try writeFileCreatingParents(init.io, path, json.written());
    if (options.markdown_path) |path| try writeFileCreatingParents(init.io, path, markdown.written());

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        "br_static_dictionary_report=ok entries={d} transforms={d} lengths={d}\n",
        .{ entries.len, transforms, lengths },
    );
    if (options.csv_path == null and options.json_path == null and options.markdown_path == null) try stdout.writeAll(csv.written());
    try stdout.flush();
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            options.csv_path = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--json")) {
            options.json_path = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--markdown")) {
            options.markdown_path = args.next() orelse return error.MissingCorpusPath;
        } else {
            return error.UnknownArgument;
        }
    }
    return options;
}

fn writeFileCreatingParents(io: std.Io, path: []const u8, data: []const u8) !void {
    if (std.fs.path.dirname(path)) |dirname| {
        try std.Io.Dir.cwd().createDirPath(io, dirname);
    }
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = data });
}

fn writeCsv(writer: *std.Io.Writer, entries: []const vort.br.StaticDictionaryEntry) !void {
    try writer.writeAll("transform,copy_len,word_index,word_bytes,word\n");
    for (entries) |entry| {
        try writer.print("{d},{d},{d},{d},", .{ entry.transform, entry.copy_len, entry.word_index, entry.word.len });
        try writeCsvField(writer, entry.word);
        try writer.writeByte('\n');
    }
}

fn writeCsvField(writer: *std.Io.Writer, value: []const u8) !void {
    try writer.writeByte('"');
    for (value) |byte| {
        if (byte == '"') try writer.writeByte('"');
        try writer.writeByte(byte);
    }
    try writer.writeByte('"');
}

fn writeJson(writer: *std.Io.Writer, entries: []const vort.br.StaticDictionaryEntry, transforms: usize, lengths: usize, categories: CategoryCounts, matrix_rows: []const MatrixRow) !void {
    try writer.print(
        "{{\"schema\":\"vort.br_static_dictionary_report\",\"schema_version\":1,\"entry_count\":{d},\"transform_count\":{d},\"length_count\":{d},\"category_counts\":{{\"identity\":{d},\"transform\":{d},\"phrase\":{d}}},\"matrix_rows\":[",
        .{ entries.len, transforms, lengths, categories.identity, categories.transform, categories.phrase },
    );
    for (matrix_rows, 0..) |row, i| {
        if (i != 0) try writer.writeByte(',');
        try writer.print(
            "{{\"transform\":{d},\"identity\":{d},\"transform_entries\":{d},\"phrase\":{d},\"total\":{d}}}",
            .{ row.transform, row.identity, row.transform_entries, row.phrase, row.total() },
        );
    }
    try writer.writeAll("],\"entries\":[");
    for (entries, 0..) |entry, i| {
        if (i != 0) try writer.writeByte(',');
        try writer.print(
            "{{\"transform\":{d},\"copy_len\":{d},\"word_index\":{d},\"word_bytes\":{d},\"word\":",
            .{ entry.transform, entry.copy_len, entry.word_index, entry.word.len },
        );
        try writeJsonString(writer, entry.word);
        try writer.writeByte('}');
    }
    try writer.writeAll("]}\n");
}

fn writeJsonString(writer: *std.Io.Writer, value: []const u8) !void {
    try writer.writeByte('"');
    for (value) |byte| {
        switch (byte) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            0...8, 11...12, 14...0x1f => try writer.print("\\u{x:0>4}", .{byte}),
            else => try writer.writeByte(byte),
        }
    }
    try writer.writeByte('"');
}

fn writeMarkdown(writer: *std.Io.Writer, entries: []const vort.br.StaticDictionaryEntry, transforms: usize, lengths: usize, categories: CategoryCounts, matrix_rows: []const MatrixRow) !void {
    try writer.writeAll("# Brotli static dictionary subset\n\n");
    try writer.print("- Entries: {d}\n- Distinct transforms: {d}\n- Distinct lengths: {d}\n- Identity entries: {d}\n- Transform entries: {d}\n- Phrase entries: {d}\n\n", .{ entries.len, transforms, lengths, categories.identity, categories.transform, categories.phrase });
    try writer.writeAll("| Transform | Identity | Transform entries | Phrase | Total |\n");
    try writer.writeAll("| ---: | ---: | ---: | ---: | ---: |\n");
    for (matrix_rows) |row| {
        try writer.print("| {d} | {d} | {d} | {d} | {d} |\n", .{ row.transform, row.identity, row.transform_entries, row.phrase, row.total() });
    }
    try writer.writeByte('\n');

    try writer.writeAll("| Transform | Copy length | Word index | Bytes | Word |\n");
    try writer.writeAll("| ---: | ---: | ---: | ---: | --- |\n");
    for (entries) |entry| {
        try writer.print("| {d} | {d} | {d} | {d} | `", .{ entry.transform, entry.copy_len, entry.word_index, entry.word.len });
        try writeMarkdownCode(writer, entry.word);
        try writer.writeAll("` |\n");
    }
}

fn writeMarkdownCode(writer: *std.Io.Writer, value: []const u8) !void {
    for (value) |byte| {
        if (byte == '`' or byte == '\\') try writer.writeByte('\\');
        try writer.writeByte(byte);
    }
}

fn validateEntries(entries: []const vort.br.StaticDictionaryEntry) !void {
    if (entries.len == 0) return error.InvalidBlockPlan;
    for (entries, 0..) |entry, i| {
        if (entry.word.len == 0) return error.InvalidBlockPlan;
        if (vort.br.minimalStaticDictionarySizeBits(entry.copy_len) == null) return error.InvalidBlockPlan;
        var j: usize = i + 1;
        while (j < entries.len) : (j += 1) {
            const other = entries[j];
            if (entry.transform == other.transform and entry.copy_len == other.copy_len and entry.word_index == other.word_index) {
                return error.InvalidBlockPlan;
            }
        }
    }
}

const MatrixRow = struct {
    transform: u16,
    identity: usize = 0,
    transform_entries: usize = 0,
    phrase: usize = 0,

    fn total(self: MatrixRow) usize {
        return self.identity + self.transform_entries + self.phrase;
    }
};

fn collectMatrixRows(allocator: std.mem.Allocator, rows: *std.ArrayList(MatrixRow), entries: []const vort.br.StaticDictionaryEntry) !void {
    for (entries) |entry| {
        var index: ?usize = null;
        for (rows.items, 0..) |row, i| {
            if (row.transform == entry.transform) {
                index = i;
                break;
            }
        }
        if (index == null) {
            try rows.append(allocator, .{ .transform = entry.transform });
            index = rows.items.len - 1;
        }
        const i = index.?;
        if (std.mem.indexOfScalar(u8, entry.word, ' ') != null) {
            rows.items[i].phrase += 1;
        } else if (entry.transform == 0) {
            rows.items[i].identity += 1;
        } else {
            rows.items[i].transform_entries += 1;
        }
    }
}

const CategoryCounts = struct {
    identity: usize = 0,
    transform: usize = 0,
    phrase: usize = 0,
};

fn categoryCounts(entries: []const vort.br.StaticDictionaryEntry) CategoryCounts {
    var counts: CategoryCounts = .{};
    for (entries) |entry| {
        if (std.mem.indexOfScalar(u8, entry.word, ' ') != null) {
            counts.phrase += 1;
        } else if (entry.transform == 0) {
            counts.identity += 1;
        } else {
            counts.transform += 1;
        }
    }
    return counts;
}

fn transformCount(entries: []const vort.br.StaticDictionaryEntry) usize {
    var count: usize = 0;
    for (entries, 0..) |entry, i| {
        var seen = false;
        for (entries[0..i]) |previous| {
            if (previous.transform == entry.transform) {
                seen = true;
                break;
            }
        }
        if (!seen) count += 1;
    }
    return count;
}

fn lengthCount(entries: []const vort.br.StaticDictionaryEntry) usize {
    var count: usize = 0;
    for (entries, 0..) |entry, i| {
        var seen = false;
        for (entries[0..i]) |previous| {
            if (previous.copy_len == entry.copy_len) {
                seen = true;
                break;
            }
        }
        if (!seen) count += 1;
    }
    return count;
}
