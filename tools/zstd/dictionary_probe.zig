const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(1 << 20));
    defer init.gpa.free(bytes);
    const view = try vort.zstdInspectStandardDictionary(bytes);
    var buffer: [256]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print("id={d} content={d}\n", .{ view.id, view.content.len });
    try stdout.interface.flush();
}
