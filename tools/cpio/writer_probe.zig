const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const format = try parseFormat(args.next());
    const mode = args.next() orelse "oneshot";
    const entries = [_]vort.CpioEncodeEntry{
        .{ .name = "plain.txt", .data = "Vort CPIO payload\n", .permissions = 0o640 },
        .{ .name = "folder", .kind = .directory },
        .{ .name = "folder/data.bin", .data = &.{ 0, 1, 2, 0xff } },
        .{ .name = "link", .kind = .symlink, .data = "folder/data.bin" },
    };
    const bytes = if (std.mem.eql(u8, mode, "oneshot"))
        try vort.encodeCpioAlloc(init.gpa, &entries, .{ .format = format })
    else if (std.mem.eql(u8, mode, "incremental-one"))
        try encodeIncremental(init.gpa, &entries, format, 1, 1)
    else if (std.mem.eql(u8, mode, "incremental-micro"))
        try encodeIncremental(init.gpa, &entries, format, 3, 5)
    else
        return error.UnsupportedCpioWriterMode;
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
}

fn encodeIncremental(
    allocator: std.mem.Allocator,
    entries: []const vort.CpioEncodeEntry,
    format: vort.CpioFormat,
    input_chunk: usize,
    output_chunk: usize,
) ![]u8 {
    var writer = try vort.CpioIncrementalWriter.initWithOptions(
        allocator,
        .{ .format = format },
    );
    defer writer.deinit();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    for (entries) |entry| {
        try writer.beginEntry(.{
            .name = entry.name,
            .size = entry.data.len,
            .kind = entry.kind,
            .permissions = entry.permissions,
            .uid = entry.uid,
            .gid = entry.gid,
            .mtime = entry.mtime,
            .device_major = entry.device_major,
            .device_minor = entry.device_minor,
            .rdevice_major = entry.rdevice_major,
            .rdevice_minor = entry.rdevice_minor,
            .checksum = if (format == .crc) vort.cpioByteSum(entry.data) else null,
        });
        var input_offset: usize = 0;
        while (input_offset != entry.data.len) {
            var scratch: [31]u8 = undefined;
            const offered = entry.data[input_offset..][0..@min(
                input_chunk,
                entry.data.len - input_offset,
            )];
            const stepped = try writer.step(
                offered,
                scratch[0..@min(output_chunk, scratch.len)],
            );
            input_offset += stepped.input_read;
            try output.appendSlice(allocator, scratch[0..stepped.output_written]);
        }
        try writer.finishEntry();
        while (true) {
            var scratch: [31]u8 = undefined;
            const stepped = try writer.step(
                "",
                scratch[0..@min(output_chunk, scratch.len)],
            );
            try output.appendSlice(allocator, scratch[0..stepped.output_written]);
            if (stepped.status == .entry_done) break;
        }
    }

    try writer.finishArchive();
    while (true) {
        var scratch: [31]u8 = undefined;
        const stepped = try writer.step(
            "",
            scratch[0..@min(output_chunk, scratch.len)],
        );
        try output.appendSlice(allocator, scratch[0..stepped.output_written]);
        if (stepped.status == .done) break;
    }
    return output.toOwnedSlice(allocator);
}

fn parseFormat(value: ?[]const u8) !vort.CpioFormat {
    const name = value orelse return .newc;
    if (std.mem.eql(u8, name, "newc")) return .newc;
    if (std.mem.eql(u8, name, "crc")) return .crc;
    if (std.mem.eql(u8, name, "odc")) return .odc;
    if (std.mem.eql(u8, name, "bin")) return .binary_little;
    if (std.mem.eql(u8, name, "bin-be")) return .binary_big;
    return error.UnsupportedCpioFormat;
}
