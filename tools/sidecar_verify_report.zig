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

    var any = false;
    while (args.next()) |stream_path| {
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        any = true;
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
    if (!any) return error.MissingCorpusPath;
    try stdout.flush();
}
