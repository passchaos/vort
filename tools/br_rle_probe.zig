const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const mode = args.next() orelse "rle";
    if (args.next() != null) return error.InvalidBlockPlan;
    const encoded = if (std.mem.eql(u8, mode, "rle"))
        try vort.brEncodeRleStreamAlloc(init.gpa, "a" ** 4096)
    else if (std.mem.eql(u8, mode, "ababa"))
        try vort.brEncodeAbabaStreamAlloc(init.gpa)
    else
        return error.InvalidBlockPlan;
    defer init.gpa.free(encoded);
    var stdout_buffer: [128]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout_writer.interface.writeAll(encoded);
    try stdout_writer.interface.flush();
}
