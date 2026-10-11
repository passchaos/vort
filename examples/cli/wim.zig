const std = @import("std");
const vort = @import("vort");

const max_file_size = 1024 * 1024 * 1024;
const max_lookup_entries = 4 * 1024 * 1024;
const max_lookup_bytes = 256 * 1024 * 1024;

pub fn list(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseWim(input);
    try stdout.print(
        "wim_version=0x{x} compression={s} chunk_size={d} images={d} part={d}/{d}\n",
        .{
            archive.header.version,
            @tagName(archive.header.compression),
            archive.header.chunk_size,
            archive.header.image_count,
            archive.header.part_number,
            archive.header.total_parts,
        },
    );
    var lookup = try archive.readLookupTableAlloc(
        init.gpa,
        max_lookup_entries,
        max_lookup_bytes,
    );
    defer lookup.deinit();
    for (lookup.entries) |entry| {
        const hash = std.fmt.bytesToHex(entry.sha1, .lower);
        try stdout.print(
            "{s}\tpart={d}\trefs={d}\tstored={d}\tsize={d}\tflags=0x{x}\n",
            .{
                &hash,
                entry.part_number,
                entry.reference_count,
                entry.resource.size_in_wim,
                entry.resource.uncompressed_size,
                entry.resource.flags,
            },
        );
    }
}

pub fn extractResource(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const hash_text = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    if (hash_text.len != 40) return error.InvalidCorpusHex;
    var hash: [20]u8 = undefined;
    _ = try std.fmt.hexToBytes(&hash, hash_text);
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseWim(input);
    const decoded = try archive.extractBySha1AllocLimited(
        init.gpa,
        &hash,
        limit,
        max_lookup_entries,
        max_lookup_bytes,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("sha1={s} decoded_bytes={d} path={s}\n", .{
        hash_text,
        decoded.len,
        output_path,
    });
}

pub fn extractXml(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        64 * 1024 * 1024;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseWim(input);
    const xml = try archive.readXmlAllocLimited(init.gpa, limit);
    defer init.gpa.free(xml);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = xml });
    try stdout.print("xml_bytes={d} path={s}\n", .{ xml.len, output_path });
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
