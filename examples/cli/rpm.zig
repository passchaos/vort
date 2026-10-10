const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;

pub fn listFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const package = try vort.parseRpmPackage(bytes);
    const payload = try package.decodePayloadAlloc(init.gpa, max_file_size);
    defer payload.deinit(init.gpa);
    try stdout.print(
        "rpm_name={s} version={s} release={s} arch={s} os={s} payload_compression={s} payload_entries={d} package_bytes={d}\n",
        .{
            try package.name(),
            try package.version(),
            try package.release(),
            try package.architecture(),
            try package.operatingSystem(),
            @tagName(package.payload_compression),
            payload.archive.entry_count,
            bytes.len,
        },
    );
    var iterator_value = payload.archive.iterator();
    var index: usize = 0;
    while (try iterator_value.next()) |entry| : (index += 1) {
        try stdout.print("index={d} kind={s} size={d} mode={o} safe_path={} name={s}\n", .{
            index,
            @tagName(entry.kind),
            entry.stored_size,
            entry.mode,
            entry.safe_path,
            entry.name,
        });
    }
}

pub fn extractFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output_len = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const package = try vort.parseRpmPackage(bytes);
    const decoded = try package.extractByNameAllocLimited(
        init.gpa,
        entry_name,
        max_file_size,
        max_output_len,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("rpm_bytes={d} decoded_bytes={d} entry={s} path={s}\n", .{
        bytes.len,
        decoded.len,
        entry_name,
        output_path,
    });
}

pub fn extractPayload(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output_len = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const package = try vort.parseRpmPackage(bytes);
    const payload = try package.decodePayloadAlloc(init.gpa, max_output_len);
    defer payload.deinit(init.gpa);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = payload.bytes,
    });
    try stdout.print("rpm_bytes={d} cpio_bytes={d} compression={s} path={s}\n", .{
        bytes.len,
        payload.bytes.len,
        @tagName(package.payload_compression),
        output_path,
    });
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
