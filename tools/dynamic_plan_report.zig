const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("path,input_bytes,token_count,literal_tokens,match_tokens,matched_bytes,stored_bytes,fixed_bytes,dynamic_bytes,hlit,hdist,hclen,code_length_ops,stats_ns,dynamic_encode_ns,best_encode_ns,dynamic_zlib_bytes,best_zlib_bytes\n", .{});

    var saw_path = false;
    while (args.next()) |path| {
        saw_path = true;
        try reportPath(init, stdout, path);
    }
    if (!saw_path) {
        try reportPath(init, stdout, "README.md");
        try reportPath(init, stdout, "docs/roadmap.md");
    }
    try stdout.flush();
}

fn reportPath(init: std.process.Init, stdout: *std.Io.Writer, path: []const u8) !void {
    const data = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(data);

    const options = vort.optionsForCompressionLevel(.default);
    const stats_start = std.Io.Clock.awake.now(init.io);
    const stats = try vort.dynamicDeflatePlanStatsAlloc(init.gpa, data, options);
    const stats_ns = stats_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    const dynamic_start = std.Io.Clock.awake.now(init.io);
    const dynamic_zlib = try vort.encodeZlibDynamicWithOptionsAlloc(init.gpa, data, options);
    defer init.gpa.free(dynamic_zlib);
    const dynamic_encode_ns = dynamic_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    const best_start = std.Io.Clock.awake.now(init.io);
    const best_zlib = try vort.encodeZlibBestAlloc(init.gpa, data, options);
    defer init.gpa.free(best_zlib);
    const best_encode_ns = best_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    try stdout.print("{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}\n", .{
        path,
        stats.input_bytes,
        stats.token_count,
        stats.literal_tokens,
        stats.match_tokens,
        stats.matched_bytes,
        stats.stored_bytes,
        stats.fixed_bytes,
        stats.dynamic_bytes,
        stats.hlit,
        stats.hdist,
        stats.hclen,
        stats.code_length_ops,
        stats_ns,
        dynamic_encode_ns,
        best_encode_ns,
        dynamic_zlib.len,
        best_zlib.len,
    });
}
