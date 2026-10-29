const std = @import("std");
const vort = @import("vort");

const Wrapper = enum { raw, zlib, gzip };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingPath;
    const iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingIterations, 10);
    const level = try std.fmt.parseInt(u4, args.next() orelse return error.MissingLevel, 10);
    const wrapper = std.meta.stringToEnum(Wrapper, args.next() orelse "raw") orelse return error.InvalidWrapper;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(input);

    const warmup = try encode(init.gpa, input, level, wrapper);
    init.gpa.free(warmup);
    var mix: u64 = 0;
    var frame_bytes: usize = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const encoded = try encode(init.gpa, input, level, wrapper);
        defer init.gpa.free(encoded);
        frame_bytes = encoded.len;
        mix +%= encoded.len;
        if (encoded.len != 0) mix +%= encoded[0];
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    var buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout_writer.interface.print("elapsed_ns={d} frame_bytes={d} zlib_bytes={d} mix={d}\n", .{ elapsed_ns, frame_bytes, frame_bytes, mix });
    try stdout_writer.interface.flush();
}

fn encode(allocator: std.mem.Allocator, input: []const u8, level: u4, wrapper: Wrapper) ![]u8 {
    return switch (wrapper) {
        .raw => vort.encodeRawLevelAlloc(allocator, input, level),
        .zlib => vort.encodeZlibLevelAlloc(allocator, input, level),
        .gzip => vort.encodeGzipLevelAlloc(allocator, input, level),
    };
}
