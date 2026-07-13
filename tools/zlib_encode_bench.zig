const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    const input_path = args.next() orelse return error.MissingCorpusPath;
    const iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(input);

    const options = vort.optionsForCompressionLevel(.default);
    const warmup = try vort.encodeZlibBestAlloc(init.gpa, input, options);
    init.gpa.free(warmup);

    var mix: u64 = 0;
    var last_size: usize = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const encoded = try vort.encodeZlibBestAlloc(init.gpa, input, options);
        defer init.gpa.free(encoded);
        last_size = encoded.len;
        mix +%= encoded.len;
        if (encoded.len != 0) mix +%= encoded[0];
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("elapsed_ns={d} zlib_bytes={d} mix={d}\n", .{ elapsed_ns, last_size, mix });
    try stdout.flush();
}
