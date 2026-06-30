const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("path,input_bytes,raw_fixed_bytes,raw_ratio\n", .{});

    var any = false;
    while (args.next()) |path| {
        any = true;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const encoded = try vort.encodeRawFixedDeflateAlloc(init.gpa, data);
        defer init.gpa.free(encoded);
        const ratio = if (data.len == 0) 0.0 else @as(f64, @floatFromInt(encoded.len)) / @as(f64, @floatFromInt(data.len));
        try stdout.print("{s},{d},{d},{d:.4}\n", .{ path, data.len, encoded.len, ratio });
    }
    if (!any) return error.MissingCorpusPath;
    try stdout.flush();
}
