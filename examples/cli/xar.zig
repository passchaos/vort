const std = @import("std");
const vort = @import("vort");

const max_file_size = 1024 * 1024 * 1024;

pub fn inspect(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try readFile(init, path);
    defer init.gpa.free(bytes);
    var archive = try vort.parseXarAlloc(init.gpa, bytes, .{
        .max_entry_decoded_bytes = max_file_size,
    });
    defer archive.deinit();
    try stdout.print(
        "toc_packed={d} toc_bytes={d} checksum={s} heap_offset={d} entries={d}\n",
        .{
            archive.header.toc_packed_size,
            archive.header.toc_size,
            @tagName(archive.header.checksum_algorithm),
            archive.heap_offset,
            archive.entries.len,
        },
    );
    for (archive.entries, 0..) |entry, index| {
        if (entry.data) |data| {
            try stdout.print(
                "entry={d}\ttype={s}\tpath={s}\tsize={d}\tpacked={d}\tencoding={s}\n",
                .{
                    index,
                    @tagName(entry.kind),
                    entry.path,
                    data.size,
                    data.packed_size,
                    @tagName(data.encoding),
                },
            );
        } else {
            try stdout.print("entry={d}\ttype={s}\tpath={s}\n", .{
                index,
                @tagName(entry.kind),
                entry.path,
            });
        }
    }
}

pub fn extract(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const archive_path = args.next() orelse return error.MissingCorpusPath;
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    var archive = try vort.parseXarAlloc(init.gpa, bytes, .{
        .max_entry_decoded_bytes = limit,
    });
    defer archive.deinit();
    const decoded = try archive.extractByPathAllocLimited(
        init.gpa,
        archive_path,
        limit,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded,
    });
    try stdout.print("path={s} decoded_bytes={d} output={s}\n", .{
        archive_path,
        decoded.len,
        output_path,
    });
}

pub fn encodeFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const archive_path = args.next() orelse return error.MissingCorpusPath;
    const compression = try parseCompression(
        args.next() orelse return error.MissingCorpusPath,
    );
    const checksum = if (args.next()) |text|
        try parseChecksum(text)
    else
        vort.XarChecksumAlgorithm.sha1;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeXarAlloc(init.gpa, &.{.{
        .path = archive_path,
        .data = input,
    }}, .{
        .compression = compression,
        .checksum = checksum,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "compression={s} checksum={s} input_bytes={d} xar_bytes={d} path={s}\n",
        .{
            @tagName(compression),
            @tagName(checksum),
            input.len,
            encoded.len,
            output_path,
        },
    );
}

fn parseCompression(text: []const u8) !vort.XarCompression {
    inline for (std.enums.values(vort.XarCompression)) |compression|
        if (std.mem.eql(u8, text, @tagName(compression))) return compression;
    return error.InvalidCompressionMode;
}

fn parseChecksum(text: []const u8) !vort.XarChecksumAlgorithm {
    inline for (std.enums.values(vort.XarChecksumAlgorithm)) |algorithm|
        if (std.mem.eql(u8, text, @tagName(algorithm))) return algorithm;
    return error.InvalidChecksumMode;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_file_size),
    );
}
