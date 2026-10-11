const std = @import("std");
const vort = @import("vort");

const max_file_size = 1024 * 1024 * 1024;

const Opened = struct {
    parent_bytes: ?[]u8 = null,
    parent: ?*vort.VhdArchive = null,
    child_bytes: []u8,
    child: vort.VhdArchive,

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
    const input_path = args.next() orelse return error.MissingCorpusPath;
    var opened = try openArchive(init, input_path, args.next());
    defer opened.deinit(init.gpa);
    const footer = opened.child.footer;
    try stdout.print(
        "type={s} virtual_bytes={d} geometry={d}/{d}/{d} block_bytes={d} parent={any} saved={any}\n",
        .{
            @tagName(footer.disk_type),
            footer.current_size,
            footer.geometry.cylinders,
            footer.geometry.heads,
            footer.geometry.sectors_per_track,
            if (opened.child.dynamic_header) |header| header.block_size else 0,
            footer.disk_type == .differencing,
            footer.saved_state,
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
    const disk_type = try parseDiskType(
        args.next() orelse return error.MissingCorpusPath,
    );
    const block_size = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 10)
    else
        2 * 1024 * 1024;
    const parent_path = args.next();
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const parent_bytes = if (parent_path) |path| try readFile(init, path) else null;
    defer if (parent_bytes) |bytes| init.gpa.free(bytes);
    var parent: ?vort.VhdArchive = if (parent_bytes) |bytes|
        try vort.parseVhd(bytes, .{})
    else
        null;
    const parent_ptr = if (parent) |*archive| archive else null;
    const encoded = try vort.encodeVhdAlloc(init.gpa, input, .{
        .disk_type = disk_type,
        .block_size = block_size,
        .parent = parent_ptr,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "type={s} input_bytes={d} virtual_bytes={d} block_bytes={d} parent={any} vhd_bytes={d} path={s}\n",
        .{
            @tagName(disk_type),
            input.len,
            std.mem.alignForward(usize, input.len, 512),
            block_size,
            parent != null,
            encoded.len,
            output_path,
        },
    );
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
    var parent: ?*vort.VhdArchive = null;
    errdefer if (parent) |archive| init.gpa.destroy(archive);
    if (parent_path) |path| {
        parent_bytes = try readFile(init, path);
        const allocated = try init.gpa.create(vort.VhdArchive);
        allocated.* = vort.parseVhd(parent_bytes.?, .{}) catch |err| {
            init.gpa.destroy(allocated);
            return err;
        };
        parent = allocated;
    }
    const child = try vort.parseVhd(child_bytes, .{ .parent = parent });
    return .{
        .parent_bytes = parent_bytes,
        .parent = parent,
        .child_bytes = child_bytes,
        .child = child,
    };
}

fn parseDiskType(text: []const u8) !vort.VhdDiskType {
    inline for (std.enums.values(vort.VhdDiskType)) |disk_type|
        if (std.mem.eql(u8, text, @tagName(disk_type))) return disk_type;
    return error.InvalidVhd;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_file_size),
    );
}
