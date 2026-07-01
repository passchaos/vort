const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("stream,sidecar,stream_bytes,sidecar_bytes,entries,total_uncompressed,crc32\n", .{});

    var pairs: std.ArrayList(Pair) = .empty;
    defer {
        for (pairs.items) |pair| pair.deinit(init.gpa);
        pairs.deinit(init.gpa);
    }
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--dir")) {
            try appendDirectoryPairs(init, &pairs, args.next() orelse return error.MissingCorpusPath);
            continue;
        }
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        try pairs.append(init.gpa, .{ .stream = arg, .sidecar = sidecar_path });
    }
    if (pairs.items.len == 0) return error.MissingCorpusPath;
    for (pairs.items) |pair| try reportPair(init, stdout, pair.stream, pair.sidecar);
    try stdout.flush();
}

const Pair = struct {
    stream: []const u8,
    sidecar: []const u8,
    owned: bool = false,

    fn deinit(self: Pair, allocator: std.mem.Allocator) void {
        if (self.owned) {
            allocator.free(self.stream);
            allocator.free(self.sidecar);
        }
    }
};

fn appendDirectoryPairs(init: std.process.Init, pairs: *std.ArrayList(Pair), dir_path: []const u8) !void {
    var dir = try std.Io.Dir.cwd().openDir(init.io, dir_path, .{ .iterate = true });
    defer dir.close(init.io);
    var walker = try dir.walk(init.gpa);
    defer walker.deinit();
    while (try walker.next(init.io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".vort")) continue;
        const relative_sidecar = try replaceExtension(init.gpa, entry.path, ".vidx");
        defer init.gpa.free(relative_sidecar);
        const sidecar = try std.fs.path.join(init.gpa, &.{ dir_path, relative_sidecar });
        errdefer init.gpa.free(sidecar);
        _ = std.Io.Dir.cwd().statFile(init.io, sidecar, .{}) catch {
            init.gpa.free(sidecar);
            continue;
        };
        const stream = try std.fs.path.join(init.gpa, &.{ dir_path, entry.path });
        errdefer init.gpa.free(stream);
        try pairs.append(init.gpa, .{ .stream = stream, .sidecar = sidecar, .owned = true });
    }
}

fn replaceExtension(allocator: std.mem.Allocator, path: []const u8, extension: []const u8) ![]u8 {
    const dot = std.mem.lastIndexOfScalar(u8, path, '.') orelse path.len;
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ path[0..dot], extension });
}

fn reportPair(init: std.process.Init, stdout: *std.Io.Writer, stream_path: []const u8, sidecar_path: []const u8) !void {
    const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(stream);
    const sidecar = try std.Io.Dir.cwd().readFileAlloc(init.io, sidecar_path, init.gpa, .limited(16 * 1024 * 1024));
    defer init.gpa.free(sidecar);
    try vort.storeValidateSidecarIndexAlloc(init.gpa, stream, sidecar);
    const entries = try vort.storeDecodeFrameIndexAlloc(init.gpa, sidecar);
    defer init.gpa.free(entries);
    var total_uncompressed: u64 = 0;
    for (entries) |entry| total_uncompressed += entry.uncompressed_len;
    try stdout.print("{s},{s},{d},{d},{d},{d},{d}\n", .{
        stream_path,
        sidecar_path,
        stream.len,
        sidecar.len,
        entries.len,
        total_uncompressed,
        vort.crc32(sidecar),
    });
}
