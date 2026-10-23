const std = @import("std");
const vort = @import("vort");

fn extract(init: std.process.Init, reader: anytype, path: []const u8) !void {
    var output = try std.Io.Dir.cwd().createFileAtomic(init.io, path, .{ .replace = true });
    defer output.deinit(init.io);
    var sink = vort.FileByteSink.init(init.io, output.file);
    var buffer: [17]u8 = undefined;
    while (true) {
        const progress = try reader.read(&buffer);
        if (progress.output_written != 0)
            try sink.sink().writeExact(progress.position - progress.output_written, buffer[0..progress.output_written]);
        if (progress.status == .done) break;
    }
    try sink.sink().finish(reader.position());
    try output.replace(init.io);
}

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingCorpusPath;
    const nid = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
    const start = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const size = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    if (size > 1024 * 1024) return error.OutputLimitExceeded;
    const output = args.next() orelse return error.MissingOutputPath;
    const mode = args.next() orelse "source";
    const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
    defer file.close(init.io);
    var adapter = try vort.FileByteSource.init(init.io, file);
    if (std.mem.eql(u8, mode, "slice")) {
        if (adapter.source().len > 32 * 1024 * 1024) return error.OutputLimitExceeded;
        const bytes = try init.gpa.alloc(u8, @intCast(adapter.source().len));
        defer init.gpa.free(bytes);
        try adapter.source().readExact(0, bytes);
        const archive = try vort.ErofsArchive.init(bytes);
        var reader = try archive.initRangeExtractor(init.gpa, try archive.inode(nid), start, size, .{ .max_output_len = size });
        defer reader.deinit();
        try extract(init, &reader, output);
    } else if (std.mem.eql(u8, mode, "source")) {
        var archive = try vort.ErofsSourceArchive.init(init.gpa, adapter.source(), .{});
        defer archive.deinit();
        var reader = try archive.initRangeExtractor(try archive.inode(nid), start, size, .{ .max_output_len = size });
        defer reader.deinit();
        try extract(init, &reader, output);
    } else return error.InvalidBlockPlan;
}
