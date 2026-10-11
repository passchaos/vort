const std = @import("std");
const vort = @import("vort");

const max_file_size = 1024 * 1024 * 1024;

const Opened = struct {
    parent_bytes: ?[]u8 = null,
    parent: ?*vort.ChdArchive = null,
    child_bytes: []u8,
    child: vort.ChdArchive,

    fn deinit(self: *Opened, allocator: std.mem.Allocator) void {
        self.child.deinit();
        if (self.parent) |parent| {
            parent.deinit();
            allocator.destroy(parent);
        }
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
    const header = opened.child.header;
    const codec_name = if (header.isCompressed())
        (try header.codec(0)).name()
    else
        "none";
    try stdout.print(
        "version=5 logical_bytes={d} hunk_bytes={d} unit_bytes={d} hunks={d} codec={s} metadata={d} parent={any}\n",
        .{
            header.logical_bytes,
            header.hunk_bytes,
            header.unit_bytes,
            header.hunk_count,
            codec_name,
            opened.child.metadata.len,
            header.hasParent(),
        },
    );
    for (opened.child.metadata, 0..) |metadata, index| {
        const tag = metadata.tagBytes();
        try stdout.print(
            "metadata[{d}] tag={s} flags=0x{x:0>2} bytes={d}\n",
            .{ index, tag, metadata.flags, metadata.data.len },
        );
    }
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
    const compression = try parseCompression(
        args.next() orelse return error.MissingCorpusPath,
    );
    const hunk_bytes = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 10)
    else
        4096;
    const unit_bytes = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 10)
    else
        512;
    const level = if (args.next()) |text|
        try std.fmt.parseInt(u8, text, 10)
    else
        6;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeChdAlloc(init.gpa, input, .{
        .compression = compression,
        .hunk_bytes = hunk_bytes,
        .unit_bytes = unit_bytes,
        .compression_level = level,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "compression={s} input_bytes={d} hunk_bytes={d} unit_bytes={d} chd_bytes={d} path={s}\n",
        .{
            @tagName(compression),
            input.len,
            hunk_bytes,
            unit_bytes,
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
    var parent: ?*vort.ChdArchive = null;
    errdefer if (parent) |archive| {
        archive.deinit();
        init.gpa.destroy(archive);
    };
    if (parent_path) |path| {
        parent_bytes = try readFile(init, path);
        const allocated = try init.gpa.create(vort.ChdArchive);
        allocated.* = vort.parseChdAlloc(init.gpa, parent_bytes.?, .{}) catch |err| {
            init.gpa.destroy(allocated);
            return err;
        };
        parent = allocated;
    }
    const child = try vort.parseChdAlloc(init.gpa, child_bytes, .{
        .parent = parent,
    });
    return .{
        .parent_bytes = parent_bytes,
        .parent = parent,
        .child_bytes = child_bytes,
        .child = child,
    };
}

fn parseCompression(text: []const u8) !vort.ChdCompression {
    inline for (std.enums.values(vort.ChdCompression)) |compression|
        if (std.mem.eql(u8, text, @tagName(compression))) return compression;
    return error.InvalidCompressionMode;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_file_size),
    );
}
