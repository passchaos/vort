const std = @import("std");
const vort = @import("vort");
const filters_cli = @import("filters.zig");

const max_archive_size = 512 * 1024 * 1024;

pub fn createFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const compression = try parseCompression(args.next());
    var filter_storage: [3]vort.SevenZipFilter = undefined;
    const filters = try filters_cli.parse(args.next(), &filter_storage);
    const solid = try parseSolid(args.next());
    const header_compression = try parseHeaderCompression(args.next());
    const bcj2 = try parseBcj2(args.next());
    const bcj2_start_ip = try parseStartIp(args.next());
    const external_names = try parseExternalNames(args.next());
    const external_metadata = try parseExternalMetadata(args.next());
    const creation_time = try parseOptionalU64(args.next());
    const access_time = try parseOptionalU64(args.next());
    const modification_time = try parseOptionalU64(args.next());
    const attributes = try parseOptionalU32(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const entries = [_]vort.SevenZipEncodeEntry{.{
        .name = entry_name,
        .data = input,
        .creation_time = creation_time,
        .access_time = access_time,
        .modification_time = modification_time,
        .attributes = attributes,
    }};
    const encoded = try vort.encodeSevenZipAlloc(init.gpa, &entries, .{
        .compression = compression,
        .solid = solid,
        .header_compression = header_compression,
        .external_names = external_names,
        .external_metadata = external_metadata,
        .bcj2 = bcj2,
        .bcj2_start_ip = bcj2_start_ip,
        .filters = filters,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("seven_zip_entries=1 compression={s} solid={} header={s} external_names={s} external_metadata={s} bcj2={} filters={d} input_bytes={d} archive_bytes={d} path={s}\n", .{
        @tagName(compression),
        solid,
        if (header_compression) |method| @tagName(method) else "plain",
        if (external_names) |method| @tagName(method) else "inline",
        if (external_metadata) |method| @tagName(method) else "inline",
        bcj2,
        filters.len,
        input.len,
        encoded.len,
        output_path,
    });
}

fn parseSolid(text: ?[]const u8) !bool {
    const value = text orelse return false;
    if (std.mem.eql(u8, value, "solid") or std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "non-solid") or
        std.mem.eql(u8, value, "nonsolid") or
        std.mem.eql(u8, value, "false")) return false;
    return error.Invalid7zOptions;
}

fn parseHeaderCompression(text: ?[]const u8) !?vort.SevenZipCompression {
    const value = text orelse return null;
    if (std.mem.eql(u8, value, "plain") or std.mem.eql(u8, value, "none")) return null;
    return try parseCompression(value);
}

fn parseBcj2(text: ?[]const u8) !bool {
    const value = text orelse return false;
    if (std.mem.eql(u8, value, "bcj2") or std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "classic") or std.mem.eql(u8, value, "false")) return false;
    return error.Invalid7zOptions;
}

fn parseStartIp(text: ?[]const u8) !u32 {
    return if (text) |value| try std.fmt.parseInt(u32, value, 10) else 0;
}

fn parseExternalNames(text: ?[]const u8) !?vort.SevenZipCompression {
    const value = text orelse return null;
    if (std.mem.eql(u8, value, "external-names") or std.mem.eql(u8, value, "external"))
        return .copy;
    if (std.mem.eql(u8, value, "inline-names") or std.mem.eql(u8, value, "inline"))
        return null;
    const prefix = "external-";
    if (std.mem.startsWith(u8, value, prefix))
        return try parseCompression(value[prefix.len..]);
    return error.Invalid7zOptions;
}

fn parseExternalMetadata(text: ?[]const u8) !?vort.SevenZipCompression {
    const value = text orelse return null;
    if (std.mem.eql(u8, value, "external-metadata")) return .copy;
    if (std.mem.eql(u8, value, "inline-metadata")) return null;
    const prefix = "external-metadata-";
    if (std.mem.startsWith(u8, value, prefix))
        return try parseCompression(value[prefix.len..]);
    return error.Invalid7zOptions;
}

fn parseOptionalU64(text: ?[]const u8) !?u64 {
    const value = text orelse return null;
    if (std.mem.eql(u8, value, "-") or std.mem.eql(u8, value, "none")) return null;
    return try std.fmt.parseInt(u64, value, 10);
}

fn parseOptionalU32(text: ?[]const u8) !?u32 {
    const value = text orelse return null;
    if (std.mem.eql(u8, value, "-") or std.mem.eql(u8, value, "none")) return null;
    return try std.fmt.parseInt(u32, value, 10);
}

pub fn listFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const archive = try vort.parseSevenZipArchiveAlloc(init.gpa, bytes);
    defer archive.deinit();
    try stdout.print("seven_zip_entries={d}\n", .{archive.entries.len});
    for (archive.entries, 0..) |entry, index|
        try stdout.print("index={d} kind={s} method={s} size={d} creation_defined={} creation={d} access_defined={} access={d} modification_defined={} modification={d} attributes_defined={} attributes={d} name={s}\n", .{
            index,
            @tagName(entry.kind),
            if (entry.method) |method| @tagName(method) else "none",
            entry.size,
            entry.creation_time != null,
            entry.creation_time orelse 0,
            entry.access_time != null,
            entry.access_time orelse 0,
            entry.modification_time != null,
            entry.modification_time orelse 0,
            entry.attributes != null,
            entry.attributes orelse 0,
            entry.name,
        });
}

pub fn extractFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output_len = try parseLimit(args.next(), std.math.maxInt(usize));
    const max_dictionary_size = try parseLimit(args.next(), 512 * 1024 * 1024);
    const max_folder_output_len = try parseLimit(args.next(), 512 * 1024 * 1024);
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const archive = try vort.parseSevenZipArchiveAllocWithOptions(init.gpa, bytes, .{
        .max_dictionary_size = max_dictionary_size,
    });
    defer archive.deinit();
    const entry = archive.find(entry_name) orelse return error.EntryNotFound;
    const decoded = try archive.decodeEntryAllocWithOptions(init.gpa, entry, .{
        .max_output_len = max_output_len,
        .max_dictionary_size = max_dictionary_size,
        .max_folder_output_len = max_folder_output_len,
    });
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("seven_zip_bytes={d} decoded_bytes={d} entry={s} path={s}\n", .{
        bytes.len,
        decoded.len,
        entry_name,
        output_path,
    });
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_archive_size));
}

fn parseLimit(value: ?[]const u8, default: usize) !usize {
    return if (value) |text| try std.fmt.parseInt(usize, text, 10) else default;
}

fn parseCompression(text: ?[]const u8) !vort.SevenZipCompression {
    const value = text orelse return .copy;
    if (std.mem.eql(u8, value, "copy")) return .copy;
    if (std.mem.eql(u8, value, "deflate")) return .deflate;
    if (std.mem.eql(u8, value, "bzip2")) return .bzip2;
    if (std.mem.eql(u8, value, "lzma")) return .lzma;
    if (std.mem.eql(u8, value, "lzma2")) return .lzma2;
    if (std.mem.eql(u8, value, "lzma2-stored")) return .lzma2_stored;
    return error.Unsupported7zFeature;
}
