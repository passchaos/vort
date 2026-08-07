const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingCorpusPath;
        } else {
            return error.UnknownArgument;
        }
    }

    const entries = vort.br.minimalStaticDictionaryCoverage();
    try validateEntries(entries);

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try writeCsv(&csv.writer, entries);

    if (csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    }

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        "br_static_dictionary_report=ok entries={d} transforms={d} lengths={d}\n",
        .{ entries.len, transformCount(entries), lengthCount(entries) },
    );
    if (csv_path == null) try stdout.writeAll(csv.written());
    try stdout.flush();
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
