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
    const archive = try vort.parseVhdx(bytes, .{});
    try stdout.print(
        "virtual_bytes={d} block_bytes={d} logical_sector={d} physical_sector={d} fixed={any} bat_entries={d} sequence={d}\n",
        .{
            archive.metadata.virtual_disk_size,
            archive.metadata.block_size,
            archive.metadata.logical_sector_size,
            archive.metadata.physical_sector_size,
            archive.metadata.leave_blocks_allocated,
            archive.metadata.bat_entry_count,
            archive.header.sequence_number,
        },
    );
}

pub fn decode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseVhdx(input, .{});
    const decoded = try archive.decodeAllocLimited(init.gpa, limit);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded,
    });
    try stdout.print("decoded_bytes={d} path={s}\n", .{ decoded.len, output_path });
}

pub fn decodeRange(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const offset = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    const length = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseVhdx(input, .{});
    const decoded = try archive.readRangeAllocLimited(
        init.gpa,
        offset,
        length,
        length,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded,
    });
    try stdout.print("offset={d} decoded_bytes={d} path={s}\n", .{
        offset,
        decoded.len,
        output_path,
    });
}

pub fn encode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const image_type = try parseImageType(
        args.next() orelse return error.MissingCorpusPath,
    );
    const block_size = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 10)
    else
        8 * 1024 * 1024;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeVhdxAlloc(init.gpa, input, .{
        .image_type = image_type,
        .block_size = block_size,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "type={s} input_bytes={d} virtual_bytes={d} block_bytes={d} vhdx_bytes={d} path={s}\n",
        .{
            @tagName(image_type),
            input.len,
            std.mem.alignForward(usize, input.len, 512),
            block_size,
            encoded.len,
            output_path,
        },
    );
}

fn parseImageType(text: []const u8) !vort.VhdxImageType {
    inline for (std.enums.values(vort.VhdxImageType)) |image_type|
        if (std.mem.eql(u8, text, @tagName(image_type))) return image_type;
    return error.InvalidVhdx;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_file_size),
    );
}
