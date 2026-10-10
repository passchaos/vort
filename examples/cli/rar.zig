const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;

pub fn createFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const version = try parseVersion(args.next());
    const compression = try parseCompression(args.next());
    const filter = try parseFilter(args.next());
    const solid = try parseSolid(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const entries = [_]vort.RarEncodeEntry{.{ .name = entry_name, .data = input }};
    const encoded = try vort.encodeRarAlloc(init.gpa, &entries, .{
        .version = version,
        .compression = compression,
        .filter = filter,
        .solid = solid,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("rar_entries=1 version={s} method={s} filter={s} solid={} input_bytes={d} archive_bytes={d} path={s}\n", .{
        @tagName(version),
        @tagName(compression),
        if (filter) |value| @tagName(value) else "none",
        solid,
        input.len,
        encoded.len,
        output_path,
    });
}

pub fn createVolumes(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const output_prefix = args.next() orelse return error.MissingCorpusPath;
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const max_payload = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    const compression = try parseCompression(args.next());
    const filter = try parseFilter(args.next());
    const solid = try parseSolid(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const entries = [_]vort.RarEncodeEntry{.{ .name = entry_name, .data = input }};
    var encoded = try vort.encodeRarVolumesAlloc(
        init.gpa,
        &entries,
        .{
            .version = .rar5,
            .compression = compression,
            .filter = filter,
            .solid = solid,
        },
        max_payload,
    );
    defer encoded.deinit();
    var archive_bytes: usize = 0;
    for (encoded.volumes, 1..) |volume, number| {
        const path = try std.fmt.allocPrint(init.gpa, "{s}.part{d}.rar", .{
            output_prefix,
            number,
        });
        defer init.gpa.free(path);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = volume });
        archive_bytes = std.math.add(usize, archive_bytes, volume.len) catch
            return error.IntegerOverflow;
    }
    try stdout.print(
        "rar_volumes={d} method={s} input_bytes={d} archive_bytes={d} prefix={s}\n",
        .{ encoded.volumes.len, @tagName(compression), input.len, archive_bytes, output_prefix },
    );
}

pub fn listFile(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const archive = try vort.parseRarArchive(bytes);
    try stdout.print("rar_entries={d} version={s} prefix_bytes={d} trailer_bytes={d} volume={} volume_number={?d} next_volume={} solid={} locked={}\n", .{
        archive.entry_count,
        @tagName(archive.version),
        archive.prefix_size,
        archive.trailer_size,
        archive.multi_volume,
        archive.volume_number,
        archive.has_next_volume,
        archive.solid,
        archive.locked,
    });
    var iterator = archive.iterator();
    var index: usize = 0;
    while (try iterator.next()) |entry| : (index += 1) {
        const name = try entry.name.alloc(init.gpa);
        defer init.gpa.free(name);
        try stdout.print("index={d} method={s} method_id={d} compression_version={d} dictionary={?d} compressed={d} uncompressed={d} crc32={?d} directory={} encrypted={} solid={} split_before={} split_after={} safe_path={} name={s}\n", .{
            index,
            @tagName(entry.method),
            entry.method_id,
            entry.compression_version,
            entry.dictionary_size,
            entry.compressed_size,
            entry.uncompressed_size,
            entry.crc32,
            entry.directory,
            entry.encrypted,
            entry.solid,
            entry.split_before,
            entry.split_after,
            entry.safe_path,
            name,
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
    const archive = try vort.parseRarArchive(bytes);
    const decoded = try archive.extractByNameAllocLimited(
        init.gpa,
        entry_name,
        max_output_len,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("rar_bytes={d} decoded_bytes={d} entry={s} path={s}\n", .{
        bytes.len,
        decoded.len,
        entry_name,
        output_path,
    });
}

pub fn extractVolumes(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output_len = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    var volume_bytes: std.ArrayList([]const u8) = .empty;
    defer {
        for (volume_bytes.items) |bytes| init.gpa.free(bytes);
        volume_bytes.deinit(init.gpa);
    }
    var archive_bytes: usize = 0;
    while (args.next()) |path| {
        const bytes = try readFile(init, path);
        archive_bytes = std.math.add(usize, archive_bytes, bytes.len) catch
            return error.IntegerOverflow;
        try volume_bytes.append(init.gpa, bytes);
    }
    if (volume_bytes.items.len == 0) return error.MissingCorpusPath;
    var set = try vort.parseRarVolumeSetAlloc(init.gpa, volume_bytes.items);
    defer set.deinit();
    const decoded = try set.extractByNameAllocLimited(
        init.gpa,
        entry_name,
        max_output_len,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print(
        "rar_volumes={d} archive_bytes={d} decoded_bytes={d} entry={s} path={s}\n",
        .{ volume_bytes.items.len, archive_bytes, decoded.len, entry_name, output_path },
    );
}

fn parseVersion(value: ?[]const u8) !vort.RarVersion {
    const name = value orelse return .rar5;
    if (std.mem.eql(u8, name, "rar4") or std.mem.eql(u8, name, "4")) return .rar4;
    if (std.mem.eql(u8, name, "rar5") or std.mem.eql(u8, name, "5")) return .rar5;
    return error.UnsupportedRarVersion;
}

fn parseCompression(value: ?[]const u8) !vort.RarEncodeCompression {
    const name = value orelse return .stored;
    if (std.mem.eql(u8, name, "stored") or std.mem.eql(u8, name, "store")) return .stored;
    if (std.mem.eql(u8, name, "rar29")) return .rar29;
    if (std.mem.eql(u8, name, "rar29-ppmd") or std.mem.eql(u8, name, "ppmd"))
        return .rar29_ppmd;
    if (std.mem.eql(u8, name, "rar50") or std.mem.eql(u8, name, "compress")) return .rar50;
    return error.UnsupportedRarCompression;
}

fn parseFilter(value: ?[]const u8) !?vort.RarEncodeFilter {
    const name = value orelse return null;
    if (std.mem.eql(u8, name, "none")) return null;
    if (std.mem.eql(u8, name, "e8")) return .e8;
    if (std.mem.eql(u8, name, "e8e9")) return .e8e9;
    if (std.mem.eql(u8, name, "arm")) return .arm;
    const prefix = "delta:";
    if (std.mem.startsWith(u8, name, prefix))
        return .{ .delta = try std.fmt.parseInt(u8, name[prefix.len..], 10) };
    return error.UnsupportedRarFilter;
}

fn parseSolid(value: ?[]const u8) !bool {
    const name = value orelse return false;
    if (std.mem.eql(u8, name, "solid")) return true;
    if (std.mem.eql(u8, name, "non-solid") or std.mem.eql(u8, name, "nonsolid")) return false;
    return error.UnsupportedRarSolidMode;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
