const std = @import("std");
const vort = @import("vort");

const max_file_size = 1024 * 1024 * 1024;

const Opened = struct {
    parent_bytes: ?[]u8 = null,
    parent: ?*vort.VhdxArchive = null,
    child_bytes: []u8,
    child: vort.VhdxArchive,

    fn deinit(self: *Opened, allocator: std.mem.Allocator) void {
        if (self.parent) |parent| allocator.destroy(parent);
        allocator.free(self.child_bytes);
        if (self.parent_bytes) |bytes| allocator.free(bytes);
        self.* = undefined;
    }
};

pub fn inspect(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const path = args.next() orelse return error.MissingCorpusPath;
    var opened = try openArchive(init, path, args.next());
    defer opened.deinit(init.gpa);
    const archive = opened.child;
    try stdout.print(
        "virtual_bytes={d} block_bytes={d} logical_sector={d} physical_sector={d} fixed={any} parent={any} bat_entries={d} sequence={d}\n",
        .{
            archive.metadata.virtual_disk_size,
            archive.metadata.block_size,
            archive.metadata.logical_sector_size,
            archive.metadata.physical_sector_size,
            archive.metadata.leave_blocks_allocated,
            archive.metadata.has_parent,
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
    var opened = try openArchive(init, input_path, args.next());
    defer opened.deinit(init.gpa);
    const decoded = try opened.child.decodeAllocLimited(init.gpa, limit);
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
    var opened = try openArchive(init, input_path, args.next());
    defer opened.deinit(init.gpa);
    const decoded = try opened.child.readRangeAllocLimited(
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
    const parent_path = args.next();
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const parent_bytes = if (parent_path) |path| try readFile(init, path) else null;
    defer if (parent_bytes) |bytes| init.gpa.free(bytes);
    var parent: ?vort.VhdxArchive = if (parent_bytes) |bytes|
        try vort.parseVhdx(bytes, .{})
    else
        null;
    const parent_ptr = if (parent) |*archive| archive else null;
    const encoded = try vort.encodeVhdxAlloc(init.gpa, input, .{
        .image_type = image_type,
        .block_size = block_size,
        .parent = parent_ptr,
        .parent_path = if (parent_path) |path| baseName(path) else "parent.vhdx",
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "type={s} input_bytes={d} virtual_bytes={d} block_bytes={d} parent={any} vhdx_bytes={d} path={s}\n",
        .{
            @tagName(image_type),
            input.len,
            std.mem.alignForward(usize, input.len, 512),
            block_size,
            parent != null,
            encoded.len,
            output_path,
        },
    );
}

fn baseName(path: []const u8) []const u8 {
    var start: usize = 0;
    for (path, 0..) |byte, index| {
        if (byte == '/' or byte == '\\') start = index + 1;
    }
    return path[start..];
}

fn openArchive(
    init: std.process.Init,
    child_path: []const u8,
    parent_path: ?[]const u8,
) !Opened {
    const child_bytes = try readFile(init, child_path);
    errdefer init.gpa.free(child_bytes);
    var parent_bytes: ?[]u8 = null;
    errdefer if (parent_bytes) |bytes| init.gpa.free(bytes);
    var parent: ?*vort.VhdxArchive = null;
    errdefer if (parent) |archive| init.gpa.destroy(archive);
    if (parent_path) |path| {
        parent_bytes = try readFile(init, path);
        const allocated = try init.gpa.create(vort.VhdxArchive);
        allocated.* = vort.parseVhdx(parent_bytes.?, .{}) catch |err| {
            init.gpa.destroy(allocated);
            return err;
        };
        parent = allocated;
    }
    const child = try vort.parseVhdx(child_bytes, .{ .parent = parent });
    return .{
        .parent_bytes = parent_bytes,
        .parent = parent,
        .child_bytes = child_bytes,
        .child = child,
    };
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
