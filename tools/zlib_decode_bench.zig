const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    const frame_path = args.next() orelse return error.MissingCorpusPath;
    const iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const frame = try std.Io.Dir.cwd().readFileAlloc(init.io, frame_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(frame);

    const warmup = try vort.decodeZlibAlloc(init.gpa, frame);
    init.gpa.free(warmup);

    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const decoded = try vort.decodeZlibAlloc(init.gpa, frame);
        defer init.gpa.free(decoded);
        mix +%= decoded.len;
        if (decoded.len != 0) mix +%= decoded[0];
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("elapsed_ns={d} mix={d}\n", .{ elapsed_ns, mix });
    try stdout.flush();
}
